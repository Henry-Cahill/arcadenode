using Docker.DotNet;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using ServerPanel.API.Data;
using ServerPanel.API.DTOs;
using ServerPanel.API.Models;

namespace ServerPanel.API.Services;

public class NodeService : INodeService
{
    private readonly PanelDbContext _context;
    private readonly ILogger<NodeService> _logger;

    public NodeService(PanelDbContext context, ILogger<NodeService> logger)
    {
        _context = context;
        _logger = logger;
    }

    public async Task<PagedResult<NodeDto>> GetAllNodesAsync(int page = 1, int pageSize = int.MaxValue)
    {
        var query = _context.Nodes
            .Include(n => n.Servers)
            .OrderByDescending(n => n.CreatedAt);

        var total = await query.CountAsync();
        var skip = pageSize == int.MaxValue ? 0 : (page - 1) * pageSize;
        var nodes = await query.Skip(skip).Take(pageSize).ToListAsync();

        return new PagedResult<NodeDto>(nodes.Select(MapToDto).ToList(), page, pageSize, total);
    }

    public async Task<NodeDto?> GetNodeByIdAsync(Guid id)
    {
        var node = await _context.Nodes
            .Include(n => n.Servers)
            .FirstOrDefaultAsync(n => n.Id == id);

        return node == null ? null : MapToDto(node);
    }

    public async Task<NodeDto?> CreateNodeAsync(CreateNodeRequest request)
    {
        _logger.LogInformation("Creating node with Name: {Name}, FQDN: {Fqdn}, DockerEndpoint: {DockerEndpoint}", 
            request.Name, request.Fqdn, request.DockerEndpoint);

        if (await _context.Nodes.AnyAsync(n => n.Fqdn == request.Fqdn))
        {
            _logger.LogWarning("Node with FQDN {Fqdn} already exists", request.Fqdn);
            return null;
        }

        var node = new Node
        {
            Name = request.Name,
            Description = request.Description ?? "",
            Fqdn = request.Fqdn,
            DaemonPort = request.DaemonPort ?? 8080,
            SftpPort = request.SftpPort ?? 2022,
            UseSsl = request.UseSsl ?? false,
            BehindProxy = request.BehindProxy ?? false,
            TotalMemory = request.TotalMemory ?? 0,
            TotalDisk = request.TotalDisk ?? 0,
            MemoryOverallocate = request.MemoryOverallocate ?? 0,
            DiskOverallocate = request.DiskOverallocate ?? 0,
            DockerEndpoint = request.DockerEndpoint ?? "tcp://node:2375",
            DaemonToken = Guid.NewGuid().ToString("N")
        };

        _context.Nodes.Add(node);
        await _context.SaveChangesAsync();
        
        _logger.LogInformation("Node created successfully with ID: {NodeId}", node.Id);

        return MapToDto(node);
    }

    public async Task<NodeDto?> UpdateNodeAsync(Guid id, UpdateNodeRequest request)
    {
        var node = await _context.Nodes
            .Include(n => n.Servers)
            .FirstOrDefaultAsync(n => n.Id == id);

        if (node == null) return null;

        if (!string.IsNullOrEmpty(request.Name)) node.Name = request.Name;
        if (request.Description != null) node.Description = request.Description;
        if (!string.IsNullOrEmpty(request.Fqdn))
        {
            if (await _context.Nodes.AnyAsync(n => n.Fqdn == request.Fqdn && n.Id != id))
            {
                return null;
            }
            node.Fqdn = request.Fqdn;
        }
        if (request.DaemonPort.HasValue) node.DaemonPort = request.DaemonPort.Value;
        if (request.SftpPort.HasValue) node.SftpPort = request.SftpPort.Value;
        if (request.UseSsl.HasValue) node.UseSsl = request.UseSsl.Value;
        if (request.TotalMemory.HasValue) node.TotalMemory = request.TotalMemory.Value;
        if (request.TotalDisk.HasValue) node.TotalDisk = request.TotalDisk.Value;
        if (request.MemoryOverallocate.HasValue) node.MemoryOverallocate = request.MemoryOverallocate.Value;
        if (request.DiskOverallocate.HasValue) node.DiskOverallocate = request.DiskOverallocate.Value;

        await _context.SaveChangesAsync();
        return MapToDto(node);
    }

    public async Task<bool> DeleteNodeAsync(Guid id)
    {
        var node = await _context.Nodes
            .Include(n => n.Servers)
            .FirstOrDefaultAsync(n => n.Id == id);

        if (node == null) return false;

        if (node.Servers.Any())
        {
            return false; // Can't delete node with servers
        }

        _context.Nodes.Remove(node);
        await _context.SaveChangesAsync();
        return true;
    }

    public async Task<bool> UpdateNodeStatusAsync(Guid id, bool isOnline)
    {
        var node = await _context.Nodes.FindAsync(id);
        if (node == null) return false;

        node.IsOnline = isOnline;
        node.LastCheckedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();
        return true;
    }

    public async Task<IEnumerable<AllocationDto>> GetNodeAllocationsAsync(Guid nodeId)
    {
        var allocations = await _context.Allocations
            .Include(a => a.Server)
            .Where(a => a.NodeId == nodeId)
            .ToListAsync();

        return allocations.Select(a => new AllocationDto(
            a.Id,
            a.IpAddress,
            a.Port,
            a.Alias,
            a.IsAssigned,
            a.NodeId,
            a.ServerId,
            a.Server?.Name
        ));
    }

    public async Task<bool> CreateAllocationsAsync(CreateAllocationRequest request)
    {
        var node = await _context.Nodes.FindAsync(request.NodeId);
        if (node == null) return false;

        var endPort = request.EndPort ?? request.StartPort;

        for (int port = request.StartPort; port <= endPort; port++)
        {
            if (await _context.Allocations.AnyAsync(a => 
                a.NodeId == request.NodeId && 
                a.IpAddress == request.IpAddress && 
                a.Port == port))
            {
                continue; // Skip existing allocations
            }

            var allocation = new Allocation
            {
                NodeId = request.NodeId,
                IpAddress = request.IpAddress,
                Port = port,
                Alias = request.Alias
            };

            _context.Allocations.Add(allocation);
        }

        await _context.SaveChangesAsync();
        return true;
    }

    public async Task<bool> DeleteAllocationAsync(Guid id)
    {
        var allocation = await _context.Allocations.FindAsync(id);
        if (allocation == null) return false;

        if (allocation.IsAssigned)
        {
            return false; // Can't delete assigned allocation
        }

        _context.Allocations.Remove(allocation);
        await _context.SaveChangesAsync();
        return true;
    }

    public async Task<NodeConnectionTestResult> TestNodeConnectionAsync(string dockerEndpoint)
    {
        try
        {
            using var dockerClient = new DockerClientConfiguration(new Uri(dockerEndpoint)).CreateClient();
            
            // Get system info with a timeout
            using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(10));
            var systemInfo = await dockerClient.System.GetSystemInfoAsync(cts.Token);
            var versionInfo = await dockerClient.System.GetVersionAsync(cts.Token);
            
            // Get container count
            var containers = await dockerClient.Containers.ListContainersAsync(
                new Docker.DotNet.Models.ContainersListParameters { All = true }, 
                cts.Token);

            return new NodeConnectionTestResult(
                Success: true,
                Message: "Successfully connected to Docker daemon",
                DockerVersion: versionInfo.Version,
                OperatingSystem: systemInfo.OperatingSystem,
                ContainerCount: containers.Count,
                MemoryTotal: systemInfo.MemTotal,
                MemoryAvailable: systemInfo.MemTotal - (systemInfo.MemTotal / 10) // Approximate
            );
        }
        catch (TimeoutException)
        {
            return new NodeConnectionTestResult(
                Success: false,
                Message: "Connection timed out. Please check if the Docker daemon is running and accessible.",
                DockerVersion: null,
                OperatingSystem: null,
                ContainerCount: null,
                MemoryTotal: null,
                MemoryAvailable: null
            );
        }
        catch (Exception ex)
        {
            return new NodeConnectionTestResult(
                Success: false,
                Message: $"Failed to connect: {ex.Message}",
                DockerVersion: null,
                OperatingSystem: null,
                ContainerCount: null,
                MemoryTotal: null,
                MemoryAvailable: null
            );
        }
    }

    public async Task<NodeConnectionTestResult> TestNodeConnectionByIdAsync(Guid nodeId)
    {
        var node = await _context.Nodes.FindAsync(nodeId);
        if (node == null)
        {
            return new NodeConnectionTestResult(
                Success: false,
                Message: "Node not found",
                DockerVersion: null,
                OperatingSystem: null,
                ContainerCount: null,
                MemoryTotal: null,
                MemoryAvailable: null
            );
        }

        var result = await TestNodeConnectionAsync(node.DockerEndpoint);
        
        // Update node status based on connection test
        node.IsOnline = result.Success;
        node.LastCheckedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();
        
        return result;
    }

    public async Task<bool> RegenerateNodeTokenAsync(Guid nodeId)
    {
        var node = await _context.Nodes.FindAsync(nodeId);
        if (node == null) return false;

        node.DaemonToken = Guid.NewGuid().ToString("N");
        await _context.SaveChangesAsync();
        return true;
    }

    public async Task<string?> GetNodeTokenAsync(Guid nodeId)
    {
        var node = await _context.Nodes.FindAsync(nodeId);
        return node?.DaemonToken;
    }

    private static NodeDto MapToDto(Node node) => new(
        node.Id,
        node.Name,
        node.Description,
        node.Fqdn,
        node.DaemonPort,
        node.SftpPort,
        node.UseSsl,
        node.BehindProxy,
        node.DockerEndpoint,
        node.TotalMemory,
        node.TotalDisk,
        node.AllocatedMemory,
        node.AllocatedDisk,
        node.IsOnline,
        node.IsMaintenanceMode,
        node.ServerCount,
        node.CreatedAt,
        node.LastCheckedAt
    );
}
