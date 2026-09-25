using Docker.DotNet;
using Docker.DotNet.Models;
using ServerPanel.API.DTOs;
using ServerPanel.API.Models;
using System.Text;
using System.Text.Json;

namespace ServerPanel.API.Services;

public class DockerService : IDockerService
{
    private readonly DockerClient _dockerClient;
    private readonly IConfiguration _configuration;
    private readonly ILogger<DockerService> _logger;
    private readonly string[] _allowedImagePrefixes;

    public DockerService(IDockerClientFactory clientFactory, IConfiguration configuration, ILogger<DockerService> logger)
    {
        _configuration = configuration;
        _logger = logger;
        _dockerClient = clientFactory.GetClient();
        _allowedImagePrefixes = configuration.GetSection("Docker:AllowedImagePrefixes").Get<string[]>()
            ?? Array.Empty<string>();
    }

    private void ValidateImageAllowed(string image)
    {
        if (_allowedImagePrefixes.Length == 0)
        {
            _logger.LogWarning(
                "Docker image allow-list is not configured; pulling '{Image}' without restriction. " +
                "Set Docker:AllowedImagePrefixes to enforce.", image);
            return;
        }

        if (!_allowedImagePrefixes.Any(prefix => image.StartsWith(prefix, StringComparison.OrdinalIgnoreCase)))
        {
            throw new InvalidOperationException($"Docker image '{image}' is not in the configured allow-list.");
        }
    }

    public async Task<string> CreateContainerAsync(GameServer server)
    {
        // Parse environment variables
        var envVars = new List<string>();
        if (!string.IsNullOrEmpty(server.EnvironmentVariables))
        {
            var vars = JsonSerializer.Deserialize<Dictionary<string, string>>(server.EnvironmentVariables);
            if (vars != null)
            {
                foreach (var (key, value) in vars)
                {
                    envVars.Add($"{key}={value}");
                }
            }
        }

        // Add default environment variables
        envVars.Add($"SERVER_MEMORY={server.MemoryLimit}");
        envVars.Add($"SERVER_PORT={server.Port}");

        var containerConfig = new CreateContainerParameters
        {
            Name = $"panel-server-{server.Identifier}",
            Image = server.DockerImage,
            Env = envVars,
            Tty = true,
            AttachStdin = true,
            AttachStdout = true,
            AttachStderr = true,
            OpenStdin = true,
            HostConfig = new HostConfig
            {
                Memory = server.MemoryLimit * 1024 * 1024, // Convert MB to bytes
                CPUPercent = server.CpuLimit,
                PortBindings = new Dictionary<string, IList<PortBinding>>
                {
                    {
                        $"{server.Port}/tcp",
                        new List<PortBinding>
                        {
                            new PortBinding { HostPort = server.Port.ToString() }
                        }
                    },
                    {
                        $"{server.Port}/udp",
                        new List<PortBinding>
                        {
                            new PortBinding { HostPort = server.Port.ToString() }
                        }
                    }
                },
                Binds = new List<string>
                {
                    $"panel-server-{server.Identifier}-data:/data"
                },
                RestartPolicy = new RestartPolicy
                {
                    Name = RestartPolicyKind.No
                }
            },
            // Let the image define its own user and working directory
            Labels = new Dictionary<string, string>
            {
                { "panel.server.id", server.Id.ToString() },
                { "panel.server.identifier", server.Identifier },
                { "panel.owner.id", server.OwnerId.ToString() }
            }
        };

        // Set startup command if provided
        if (!string.IsNullOrEmpty(server.StartupCommand))
        {
            containerConfig.Cmd = new List<string> { "/bin/sh", "-c", server.StartupCommand };
        }

        // Enforce the image allow-list (when configured) before pulling.
        ValidateImageAllowed(server.DockerImage);

        // Pull image first
        try
        {
            await _dockerClient.Images.CreateImageAsync(
                new ImagesCreateParameters { FromImage = server.DockerImage },
                null,
                new Progress<JSONMessage>());
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Image pull for {Image} did not complete (it may already exist locally)",
                server.DockerImage);
        }

        var container = await _dockerClient.Containers.CreateContainerAsync(containerConfig);
        return container.ID;
    }

    public async Task<bool> StartContainerAsync(string containerId)
    {
        try
        {
            return await _dockerClient.Containers.StartContainerAsync(containerId, new ContainerStartParameters());
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to start container {ContainerId}", containerId);
            return false;
        }
    }

    public async Task<bool> StopContainerAsync(string containerId)
    {
        try
        {
            return await _dockerClient.Containers.StopContainerAsync(containerId, new ContainerStopParameters
            {
                WaitBeforeKillSeconds = 10
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to stop container {ContainerId}", containerId);
            return false;
        }
    }

    public async Task<bool> RestartContainerAsync(string containerId)
    {
        try
        {
            await _dockerClient.Containers.RestartContainerAsync(containerId, new ContainerRestartParameters
            {
                WaitBeforeKillSeconds = 10
            });
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to restart container {ContainerId}", containerId);
            return false;
        }
    }

    public async Task<bool> RemoveContainerAsync(string containerId)
    {
        try
        {
            // Stop container first
            await StopContainerAsync(containerId);

            await _dockerClient.Containers.RemoveContainerAsync(containerId, new ContainerRemoveParameters
            {
                Force = true,
                RemoveVolumes = false
            });
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to remove container {ContainerId}", containerId);
            return false;
        }
    }

    public async Task<ServerStatsDto?> GetContainerStatsAsync(Guid serverId, string containerId)
    {
        try
        {
            // Get container stats using progress-based API
            ContainerStatsResponse? statsResponse = null;
            var progress = new Progress<ContainerStatsResponse>(response => statsResponse = response);
            
            using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(5));
            await _dockerClient.Containers.GetContainerStatsAsync(
                containerId,
                new ContainerStatsParameters { Stream = false },
                progress,
                cts.Token);

            if (statsResponse == null)
            {
                return null;
            }

            // Calculate CPU percentage
            // CPU % = (container_cpu_delta / system_cpu_delta) * number_of_cpus * 100
            double cpuPercent = 0;
            if (statsResponse.CPUStats?.CPUUsage?.TotalUsage != null &&
                statsResponse.PreCPUStats?.CPUUsage?.TotalUsage != null &&
                statsResponse.CPUStats?.SystemUsage != null &&
                statsResponse.PreCPUStats?.SystemUsage != null)
            {
                var cpuDelta = (double)(statsResponse.CPUStats.CPUUsage.TotalUsage - statsResponse.PreCPUStats.CPUUsage.TotalUsage);
                var systemDelta = (double)(statsResponse.CPUStats.SystemUsage - statsResponse.PreCPUStats.SystemUsage);
                
                if (systemDelta > 0 && cpuDelta > 0)
                {
                    int cpuCount = statsResponse.CPUStats.CPUUsage.PercpuUsage?.Count 
                                   ?? (statsResponse.CPUStats.OnlineCPUs > 0 ? (int)statsResponse.CPUStats.OnlineCPUs : 1);
                    cpuPercent = (cpuDelta / systemDelta) * cpuCount * 100.0;
                }
            }

            // Get memory usage (already in bytes)
            long memoryUsage = (long)(statsResponse.MemoryStats?.Usage ?? 0);
            
            // Subtract cache from memory usage if available (for more accurate "used" memory)
            if (statsResponse.MemoryStats?.Stats?.TryGetValue("cache", out var cache) == true)
            {
                memoryUsage = Math.Max(0, memoryUsage - (long)cache);
            }

            // Get network stats - sum all interfaces
            long networkRx = 0;
            long networkTx = 0;
            if (statsResponse.Networks != null)
            {
                foreach (var network in statsResponse.Networks.Values)
                {
                    networkRx += (long)(network.RxBytes);
                    networkTx += (long)(network.TxBytes);
                }
            }

            // Get disk usage from BlkIO stats
            long diskUsage = 0;
            if (statsResponse.BlkioStats?.IoServiceBytesRecursive != null)
            {
                foreach (var io in statsResponse.BlkioStats.IoServiceBytesRecursive)
                {
                    if (io.Op?.ToLower() == "read" || io.Op?.ToLower() == "write")
                    {
                        diskUsage += (long)io.Value;
                    }
                }
            }

            return new ServerStatsDto(
                serverId,
                ServerStatus.Running,
                memoryUsage,
                Math.Round(cpuPercent, 2),
                diskUsage,
                networkRx,
                networkTx,
                DateTime.UtcNow
            );
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to get container stats for {ContainerId}", containerId);
            return null;
        }
    }

    public async Task<string> GetContainerLogsAsync(string containerId, int tail = 100)
    {
        try
        {
            _logger.LogDebug("Fetching logs for container {ContainerId}, tail={Tail}", containerId, tail);
            
            // First check if container exists and get its state
            var containerInfo = await _dockerClient.Containers.InspectContainerAsync(containerId);
            var isTty = containerInfo.Config?.Tty ?? false;
            
            _logger.LogDebug("Container {ContainerId} state: {State}, TTY: {TTY}", 
                containerId, containerInfo.State?.Status, isTty);

            // Get logs - pass true for tty param when container has TTY enabled
            using var logs = await _dockerClient.Containers.GetContainerLogsAsync(containerId, isTty, new ContainerLogsParameters
            {
                ShowStdout = true,
                ShowStderr = true,
                Tail = tail.ToString(),
                Timestamps = true
            });

            var buffer = new byte[81920];
            using var ms = new MemoryStream();
            
            using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(5));
            
            if (isTty)
            {
                // For TTY containers, CopyOutputToAsync is available
                await logs.CopyOutputToAsync(null, ms, ms, cts.Token);
            }
            else
            {
                // For non-TTY containers, use ReadOutputAsync for multiplexed stream
                var result = await logs.ReadOutputAsync(buffer, 0, buffer.Length, cts.Token);
                while (result.Count > 0)
                {
                    ms.Write(buffer, 0, result.Count);
                    result = await logs.ReadOutputAsync(buffer, 0, buffer.Length, cts.Token);
                }
            }
            
            var logContent = Encoding.UTF8.GetString(ms.ToArray());
            _logger.LogDebug("Got {Length} bytes of logs for container {ContainerId}", logContent.Length, containerId);
            return logContent;
        }
        catch (Docker.DotNet.DockerContainerNotFoundException)
        {
            _logger.LogWarning("Container {ContainerId} not found", containerId);
            return "[Container not found]";
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching logs for container {ContainerId}", containerId);
            return $"[Error fetching logs: {ex.Message}]";
        }
    }

    // Shell metacharacters that enable command chaining, substitution, or redirection.
    private static readonly char[] ShellMetacharacters =
        { ';', '&', '|', '$', '`', '\\', '>', '<', '(', ')', '{', '}', '\n', '\r', '"', '\'' };

    public async Task<bool> SendCommandAsync(string containerId, string command)
    {
        if (string.IsNullOrWhiteSpace(command))
        {
            _logger.LogWarning("Rejected empty command for container {ContainerId}", containerId);
            return false;
        }

        if (command.Length > 512)
        {
            _logger.LogWarning("Rejected command exceeding length limit for container {ContainerId}", containerId);
            return false;
        }

        if (command.IndexOfAny(ShellMetacharacters) >= 0)
        {
            _logger.LogWarning(
                "Rejected command containing shell metacharacters for container {ContainerId}", containerId);
            return false;
        }

        try
        {
            var exec = await _dockerClient.Exec.ExecCreateContainerAsync(containerId, new ContainerExecCreateParameters
            {
                AttachStdin = true,
                AttachStdout = true,
                AttachStderr = true,
                Cmd = new[] { "/bin/sh", "-c", command },
                Tty = true
            });

            await _dockerClient.Exec.StartContainerExecAsync(exec.ID);
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to send command to container {ContainerId}", containerId);
            return false;
        }
    }
}
