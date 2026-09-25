using Microsoft.EntityFrameworkCore;
using ServerPanel.API.Data;
using ServerPanel.API.DTOs;
using ServerPanel.API.Models;
using System.Text.Json;

namespace ServerPanel.API.Services;

public class ServerService : IServerService
{
    private readonly PanelDbContext _context;
    private readonly IDockerService _dockerService;
    private readonly ICartridgeService _cartridgeService;
    private readonly ILogger<ServerService> _logger;

    public ServerService(
        PanelDbContext context, 
        IDockerService dockerService,
        ICartridgeService cartridgeService,
        ILogger<ServerService> logger)
    {
        _context = context;
        _dockerService = dockerService;
        _cartridgeService = cartridgeService;
        _logger = logger;
    }

    private static string GenerateServerIdentifier() => Guid.NewGuid().ToString("N")[..8];

    public async Task<PagedResult<ServerDto>> GetAllServersAsync(int page = 1, int pageSize = int.MaxValue)
    {
        var query = _context.Servers
            .Include(s => s.Owner)
            .Include(s => s.Node)
            .OrderByDescending(s => s.CreatedAt);

        var total = await query.CountAsync();
        var skip = pageSize == int.MaxValue ? 0 : (page - 1) * pageSize;
        var servers = await query.Skip(skip).Take(pageSize).ToListAsync();

        return new PagedResult<ServerDto>(servers.Select(MapToDto).ToList(), page, pageSize, total);
    }

    public async Task<PagedResult<ServerDto>> GetUserServersAsync(Guid userId, int page = 1, int pageSize = int.MaxValue)
    {
        var query = _context.Servers
            .Include(s => s.Owner)
            .Include(s => s.Node)
            .Where(s => s.OwnerId == userId)
            .OrderByDescending(s => s.CreatedAt);

        var total = await query.CountAsync();
        var skip = pageSize == int.MaxValue ? 0 : (page - 1) * pageSize;
        var servers = await query.Skip(skip).Take(pageSize).ToListAsync();

        return new PagedResult<ServerDto>(servers.Select(MapToDto).ToList(), page, pageSize, total);
    }

    public async Task<ServerDto?> GetServerByIdAsync(Guid id)
    {
        var server = await _context.Servers
            .Include(s => s.Owner)
            .Include(s => s.Node)
            .FirstOrDefaultAsync(s => s.Id == id);

        return server == null ? null : MapToDto(server);
    }

    public async Task<ServerDto?> GetServerByIdentifierAsync(string identifier)
    {
        var server = await _context.Servers
            .Include(s => s.Owner)
            .Include(s => s.Node)
            .FirstOrDefaultAsync(s => s.Identifier == identifier);

        return server == null ? null : MapToDto(server);
    }

    public async Task<ServerDto?> CreateServerAsync(CreateServerRequest request, Guid ownerId)
    {
        var node = await _context.Nodes
            .Include(n => n.Servers)
            .FirstOrDefaultAsync(n => n.Id == request.NodeId);
        if (node == null) return null;

        var owner = await _context.Users.FindAsync(ownerId);
        if (owner == null) return null;

        // Reject requests that would exceed the node's (over)allocatable capacity.
        if (node.TotalMemory > 0)
        {
            var memoryCapacity = node.TotalMemory + (node.TotalMemory * node.MemoryOverallocate / 100);
            if (node.AllocatedMemory + request.MemoryLimit > memoryCapacity)
            {
                _logger.LogWarning(
                    "Server creation rejected: node {NodeId} memory capacity exceeded (allocated {Allocated} + requested {Requested} > {Capacity})",
                    node.Id, node.AllocatedMemory, request.MemoryLimit, memoryCapacity);
                return null;
            }
        }

        if (node.TotalDisk > 0)
        {
            var diskCapacity = node.TotalDisk + (node.TotalDisk * node.DiskOverallocate / 100);
            if (node.AllocatedDisk + request.DiskLimit > diskCapacity)
            {
                _logger.LogWarning(
                    "Server creation rejected: node {NodeId} disk capacity exceeded (allocated {Allocated} + requested {Requested} > {Capacity})",
                    node.Id, node.AllocatedDisk, request.DiskLimit, diskCapacity);
                return null;
            }
        }

        var server = new GameServer
        {
            Identifier = GenerateServerIdentifier(),
            Name = request.Name,
            Description = request.Description ?? "",
            DockerImage = request.DockerImage,
            StartupCommand = request.StartupCommand,
            MemoryLimit = request.MemoryLimit,
            CpuLimit = request.CpuLimit,
            DiskLimit = request.DiskLimit,
            Port = request.Port,
            EnvironmentVariables = request.EnvironmentVariables != null 
                ? JsonSerializer.Serialize(request.EnvironmentVariables) 
                : null,
            OwnerId = ownerId,
            NodeId = request.NodeId,
            EggId = request.EggId,
            Status = ServerStatus.Installing
        };

        _context.Servers.Add(server);
        await _context.SaveChangesAsync();

        // Create container
        try
        {
            var containerId = await _dockerService.CreateContainerAsync(server);
            server.ContainerId = containerId;
            server.Status = ServerStatus.Stopped;
            await _context.SaveChangesAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to create container for server {ServerId}", server.Id);
            server.Status = ServerStatus.Error;
            await _context.SaveChangesAsync();
        }

        return await GetServerByIdAsync(server.Id);
    }

    public async Task<ServerDto?> CreateServerFromCartridgeAsync(CreateCartridgeServerRequest request, Guid ownerId)
    {
        // Validate cartridge exists
        var cartridge = _cartridgeService.GetCartridgeById(request.CartridgeId);
        if (cartridge == null)
        {
            _logger.LogWarning("Cartridge not found: {CartridgeId}", request.CartridgeId);
            return null;
        }

        // Validate node exists
        var node = await _context.Nodes.FindAsync(request.NodeId);
        if (node == null)
        {
            _logger.LogWarning("Node not found: {NodeId}", request.NodeId);
            return null;
        }

        // Validate owner exists
        var owner = await _context.Users.FindAsync(ownerId);
        if (owner == null)
        {
            _logger.LogWarning("Owner not found: {OwnerId}", ownerId);
            return null;
        }

        // Use empty dictionary if variables not provided
        var variables = request.Variables ?? new Dictionary<string, object>();
        
        // Validate variables
        var (isValid, errors) = _cartridgeService.ValidateVariables(cartridge, variables);
        if (!isValid)
        {
            _logger.LogWarning("Variable validation failed: {Errors}", string.Join(", ", errors));
            return null;
        }

        // Determine port (auto-assign if not specified)
        var port = request.Port ?? await GetNextAvailablePortAsync(request.NodeId, 
            cartridge.Ports.Values.FirstOrDefault()?.Default ?? 25565);

        // Build environment variables from cartridge and user values
        var environmentVars = _cartridgeService.BuildEnvironmentVariables(cartridge, variables, port);

        // Get startup command with variables substituted
        var startupCommand = _cartridgeService.GetStartupCommand(cartridge, environmentVars);

        // Create server entity
        var server = new GameServer
        {
            Identifier = GenerateServerIdentifier(),
            Name = request.Name,
            Description = request.Description ?? cartridge.Description,
            DockerImage = cartridge.Docker.Image,
            StartupCommand = startupCommand,
            MemoryLimit = request.MemoryLimit,
            CpuLimit = request.CpuLimit,
            DiskLimit = request.DiskLimit,
            Port = port,
            EnvironmentVariables = JsonSerializer.Serialize(environmentVars),
            OwnerId = ownerId,
            NodeId = request.NodeId,
            Status = ServerStatus.Installing
        };

        _context.Servers.Add(server);
        await _context.SaveChangesAsync();

        _logger.LogInformation("Created server {ServerId} from cartridge {CartridgeId}", server.Id, request.CartridgeId);

        // Create container
        try
        {
            var containerId = await _dockerService.CreateContainerAsync(server);
            server.ContainerId = containerId;
            server.Status = ServerStatus.Stopped;
            await _context.SaveChangesAsync();
            
            _logger.LogInformation("Container {ContainerId} created for server {ServerId}", containerId, server.Id);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to create container for server {ServerId}", server.Id);
            server.Status = ServerStatus.Error;
            await _context.SaveChangesAsync();
        }

        return await GetServerByIdAsync(server.Id);
    }

    private async Task<int> GetNextAvailablePortAsync(Guid nodeId, int startPort)
    {
        // Get all ports in use on this node
        var usedPorts = await _context.Servers
            .Where(s => s.NodeId == nodeId)
            .Select(s => s.Port)
            .ToListAsync();

        // Find next available port starting from startPort
        var port = startPort;
        while (usedPorts.Contains(port))
        {
            port++;
        }

        return port;
    }

    public async Task<ServerDto?> UpdateServerAsync(Guid id, UpdateServerRequest request)
    {
        var server = await _context.Servers.FindAsync(id);
        if (server == null) return null;

        if (!string.IsNullOrEmpty(request.Name)) server.Name = request.Name;
        if (request.Description != null) server.Description = request.Description;
        if (request.StartupCommand != null) server.StartupCommand = request.StartupCommand;
        if (request.MemoryLimit.HasValue) server.MemoryLimit = request.MemoryLimit.Value;
        if (request.CpuLimit.HasValue) server.CpuLimit = request.CpuLimit.Value;
        if (request.DiskLimit.HasValue) server.DiskLimit = request.DiskLimit.Value;
        if (request.EnvironmentVariables != null)
        {
            server.EnvironmentVariables = JsonSerializer.Serialize(request.EnvironmentVariables);
        }

        await _context.SaveChangesAsync();
        return await GetServerByIdAsync(id);
    }

    public async Task<bool> DeleteServerAsync(Guid id)
    {
        var server = await _context.Servers.FindAsync(id);
        if (server == null) return false;

        // Stop and remove container
        if (!string.IsNullOrEmpty(server.ContainerId))
        {
            await _dockerService.RemoveContainerAsync(server.ContainerId);
        }

        _context.Servers.Remove(server);
        await _context.SaveChangesAsync();
        return true;
    }

    public async Task<bool> UpdateServerStatusAsync(Guid id, ServerStatus status)
    {
        var server = await _context.Servers.FindAsync(id);
        if (server == null) return false;

        server.Status = status;
        if (status == ServerStatus.Running)
        {
            server.LastStartedAt = DateTime.UtcNow;
        }

        await _context.SaveChangesAsync();
        return true;
    }

    public async Task<bool> SuspendServerAsync(Guid id, bool suspended)
    {
        var server = await _context.Servers.FindAsync(id);
        if (server == null) return false;

        server.IsSuspended = suspended;
        if (suspended)
        {
            server.Status = ServerStatus.Suspended;
            if (!string.IsNullOrEmpty(server.ContainerId))
            {
                await _dockerService.StopContainerAsync(server.ContainerId);
            }
        }

        await _context.SaveChangesAsync();
        return true;
    }

    private static ServerDto MapToDto(GameServer server) => new(
        server.Id,
        server.Name,
        server.Description,
        server.Identifier,
        server.ContainerId,
        server.DockerImage,
        server.StartupCommand,
        server.MemoryLimit,
        server.CpuLimit,
        server.DiskLimit,
        server.Port,
        server.Node?.Fqdn ?? server.IpAddress, // Use node's public IP/FQDN instead of 0.0.0.0
        server.Status,
        server.IsSuspended,
        server.CreatedAt,
        server.LastStartedAt,
        server.OwnerId,
        server.Owner?.Username ?? "Unknown",
        server.NodeId,
        server.Node?.Name ?? "Unknown"
    );
}
