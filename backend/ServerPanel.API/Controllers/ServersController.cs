using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using ServerPanel.API.Common;
using ServerPanel.API.DTOs;
using ServerPanel.API.Models;
using ServerPanel.API.Services;
using System.Security.Claims;

namespace ServerPanel.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class ServersController : ControllerBase
{
    private readonly IServerService _serverService;
    private readonly IDockerService _dockerService;
    private readonly ILogger<ServersController> _logger;

    public ServersController(IServerService serverService, IDockerService dockerService, ILogger<ServersController> logger)
    {
        _serverService = serverService;
        _dockerService = dockerService;
        _logger = logger;
    }

    /// <summary>
    /// Get all servers (admin) or user's servers
    /// </summary>
    [HttpGet]
    [ProducesResponseType(typeof(IEnumerable<ServerDto>), 200)]
    public async Task<IActionResult> GetServers([FromQuery] int? page = null, [FromQuery] int? pageSize = null)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var (p, ps) = Pagination.Resolve(page, pageSize);

        var isAdmin = User.IsInRole("Admin") || User.IsInRole("SuperAdmin");
        var result = isAdmin
            ? await _serverService.GetAllServersAsync(p, ps)
            : await _serverService.GetUserServersAsync(userId.Value, p, ps);

        Response.ApplyPaginationHeaders(result);
        return Ok(result.Items);
    }

    /// <summary>
    /// Get server by ID
    /// </summary>
    [HttpGet("{id:guid}")]
    [ProducesResponseType(typeof(ServerDto), 200)]
    [ProducesResponseType(404)]
    public async Task<IActionResult> GetServer(Guid id)
    {
        var server = await _serverService.GetServerByIdAsync(id);
        if (server == null) return NotFound();

        // Check authorization
        if (!CanAccessServer(server)) return Forbid();

        return Ok(server);
    }

    /// <summary>
    /// Get server by identifier (short ID)
    /// </summary>
    [HttpGet("identifier/{identifier:length(8)}")]
    [ProducesResponseType(typeof(ServerDto), 200)]
    [ProducesResponseType(404)]
    public async Task<IActionResult> GetServerByIdentifier(string identifier)
    {
        var server = await _serverService.GetServerByIdentifierAsync(identifier);
        if (server == null) return NotFound();

        if (!CanAccessServer(server)) return Forbid();

        return Ok(server);
    }

    /// <summary>
    /// Create a new server
    /// </summary>
    [HttpPost]
    [Authorize(Roles = "Admin,SuperAdmin")]
    [ProducesResponseType(typeof(ServerDto), 201)]
    [ProducesResponseType(400)]
    public async Task<IActionResult> CreateServer([FromBody] CreateServerRequest request)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var server = await _serverService.CreateServerAsync(request, userId.Value);
        if (server == null)
        {
            return BadRequest(new { message = "Failed to create server" });
        }

        return CreatedAtAction(nameof(GetServer), new { id = server.Id }, server);
    }

    /// <summary>
    /// Create a new server from a cartridge definition
    /// </summary>
    [HttpPost("from-cartridge")]
    [Authorize(Roles = "Admin,SuperAdmin")]
    [ProducesResponseType(typeof(ServerDto), 201)]
    [ProducesResponseType(400)]
    public async Task<IActionResult> CreateServerFromCartridge([FromBody] CreateCartridgeServerRequest request)
    {
        _logger.LogInformation("CreateServerFromCartridge called with: Name={Name}, NodeId={NodeId}, CartridgeId={CartridgeId}, VariablesCount={VarCount}", 
            request?.Name, request?.NodeId, request?.CartridgeId, request?.Variables?.Count ?? 0);
        
        if (!ModelState.IsValid)
        {
            var errors = ModelState.Values.SelectMany(v => v.Errors).Select(e => e.ErrorMessage);
            _logger.LogWarning("Model validation failed: {Errors}", string.Join(", ", errors));
            return BadRequest(new { message = "Validation failed", errors = errors });
        }
        
        if (request is null)
        {
            return BadRequest(new { message = "Request body is required" });
        }

        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var server = await _serverService.CreateServerFromCartridgeAsync(request, userId.Value);
        if (server == null)
        {
            return BadRequest(new { message = "Failed to create server. Check cartridge ID, node ID, and variable values." });
        }

        return CreatedAtAction(nameof(GetServer), new { id = server.Id }, server);
    }

    /// <summary>
    /// Update server settings
    /// </summary>
    [HttpPut("{id:guid}")]
    [ProducesResponseType(typeof(ServerDto), 200)]
    [ProducesResponseType(404)]
    public async Task<IActionResult> UpdateServer(Guid id, [FromBody] UpdateServerRequest request)
    {
        var server = await _serverService.GetServerByIdAsync(id);
        if (server == null) return NotFound();

        if (!CanAccessServer(server)) return Forbid();

        var updated = await _serverService.UpdateServerAsync(id, request);
        return Ok(updated);
    }

    /// <summary>
    /// Delete a server
    /// </summary>
    [HttpDelete("{id:guid}")]
    [Authorize(Roles = "Admin,SuperAdmin")]
    [ProducesResponseType(204)]
    [ProducesResponseType(404)]
    public async Task<IActionResult> DeleteServer(Guid id)
    {
        var success = await _serverService.DeleteServerAsync(id);
        if (!success) return NotFound();

        return NoContent();
    }

    /// <summary>
    /// Send power action to server (start, stop, restart, kill)
    /// </summary>
    [HttpPost("{id:guid}/power")]
    [ProducesResponseType(200)]
    [ProducesResponseType(400)]
    public async Task<IActionResult> PowerAction(Guid id, [FromBody] PowerActionRequest request)
    {
        var server = await _serverService.GetServerByIdAsync(id);
        if (server == null) return NotFound();

        if (!CanAccessServer(server)) return Forbid();

        if (server.IsSuspended)
        {
            return BadRequest(new { message = "Server is suspended" });
        }

        if (string.IsNullOrEmpty(server.ContainerId))
        {
            return BadRequest(new { message = "Server container not found" });
        }

        bool success;
        ServerStatus newStatus;

        switch (request.Action.ToLower())
        {
            case "start":
                await _serverService.UpdateServerStatusAsync(id, ServerStatus.Starting);
                success = await _dockerService.StartContainerAsync(server.ContainerId);
                newStatus = success ? ServerStatus.Running : ServerStatus.Error;
                break;

            case "stop":
                await _serverService.UpdateServerStatusAsync(id, ServerStatus.Stopping);
                success = await _dockerService.StopContainerAsync(server.ContainerId);
                newStatus = success ? ServerStatus.Stopped : ServerStatus.Error;
                break;

            case "restart":
                await _serverService.UpdateServerStatusAsync(id, ServerStatus.Stopping);
                success = await _dockerService.RestartContainerAsync(server.ContainerId);
                newStatus = success ? ServerStatus.Running : ServerStatus.Error;
                break;

            case "kill":
                success = await _dockerService.StopContainerAsync(server.ContainerId);
                newStatus = ServerStatus.Stopped;
                break;

            default:
                return BadRequest(new { message = "Invalid power action" });
        }

        await _serverService.UpdateServerStatusAsync(id, newStatus);

        return Ok(new { message = $"Server {request.Action} command sent", success });
    }

    /// <summary>
    /// Get server console logs
    /// </summary>
    [HttpGet("{id:guid}/logs")]
    [ProducesResponseType(typeof(object), 200)]
    [ProducesResponseType(404)]
    public async Task<IActionResult> GetLogs(Guid id, [FromQuery] int tail = 100)
    {
        var server = await _serverService.GetServerByIdAsync(id);
        if (server == null) return NotFound();

        if (!CanAccessServer(server)) return Forbid();

        if (string.IsNullOrEmpty(server.ContainerId))
        {
            return Ok(new { logs = "" });
        }

        var logs = await _dockerService.GetContainerLogsAsync(server.ContainerId, tail);
        return Ok(new { logs });
    }

    /// <summary>
    /// Send command to server console
    /// </summary>
    [HttpPost("{id:guid}/command")]
    [ProducesResponseType(200)]
    [ProducesResponseType(400)]
    public async Task<IActionResult> SendCommand(Guid id, [FromBody] ConsoleCommandRequest request)
    {
        var server = await _serverService.GetServerByIdAsync(id);
        if (server == null) return NotFound();

        if (!CanAccessServer(server)) return Forbid();

        if (server.Status != ServerStatus.Running)
        {
            return BadRequest(new { message = "Server is not running" });
        }

        if (string.IsNullOrEmpty(server.ContainerId))
        {
            return BadRequest(new { message = "Server container not found" });
        }

        var success = await _dockerService.SendCommandAsync(server.ContainerId, request.Command);
        return Ok(new { success });
    }

    /// <summary>
    /// Get server resource usage stats
    /// </summary>
    [HttpGet("{id:guid}/stats")]
    [ProducesResponseType(typeof(ServerStatsDto), 200)]
    [ProducesResponseType(404)]
    public async Task<IActionResult> GetStats(Guid id)
    {
        var server = await _serverService.GetServerByIdAsync(id);
        if (server == null) return NotFound();

        if (!CanAccessServer(server)) return Forbid();

        if (string.IsNullOrEmpty(server.ContainerId))
        {
            return Ok(new ServerStatsDto(id, server.Status, 0, 0, 0, 0, 0, DateTime.UtcNow));
        }

        var stats = await _dockerService.GetContainerStatsAsync(id, server.ContainerId);
        return Ok(stats ?? new ServerStatsDto(id, server.Status, 0, 0, 0, 0, 0, DateTime.UtcNow));
    }

    /// <summary>
    /// Suspend or unsuspend a server
    /// </summary>
    [HttpPost("{id:guid}/suspend")]
    [Authorize(Roles = "Admin,SuperAdmin")]
    [ProducesResponseType(200)]
    public async Task<IActionResult> SuspendServer(Guid id, [FromQuery] bool suspended = true)
    {
        var success = await _serverService.SuspendServerAsync(id, suspended);
        if (!success) return NotFound();

        return Ok(new { message = suspended ? "Server suspended" : "Server unsuspended" });
    }

    private Guid? GetUserId()
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        return Guid.TryParse(userIdClaim, out var userId) ? userId : null;
    }

    private bool CanAccessServer(ServerDto server)
    {
        var userId = GetUserId();
        var isAdmin = User.IsInRole("Admin") || User.IsInRole("SuperAdmin");
        return isAdmin || server.OwnerId == userId;
    }
}
