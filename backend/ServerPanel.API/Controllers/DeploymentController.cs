using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using ServerPanel.API.DTOs;
using ServerPanel.API.Models;
using ServerPanel.API.Services;
using System.Security.Claims;
using System.Security.Cryptography;

namespace ServerPanel.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class DeploymentController : ControllerBase
{
    private readonly IGameTemplateService _templateService;
    private readonly IServerService _serverService;
    private readonly IDockerService _dockerService;
    private readonly INodeService _nodeService;

    public DeploymentController(
        IGameTemplateService templateService,
        IServerService serverService,
        IDockerService dockerService,
        INodeService nodeService)
    {
        _templateService = templateService;
        _serverService = serverService;
        _dockerService = dockerService;
        _nodeService = nodeService;
    }

    /// <summary>
    /// Get all available game templates
    /// </summary>
    [HttpGet("templates")]
    [ProducesResponseType(typeof(IEnumerable<GameTemplateDto>), 200)]
    public IActionResult GetTemplates()
    {
        var templates = _templateService.GetAllTemplates();
        return Ok(templates);
    }

    /// <summary>
    /// Get a specific game template by ID
    /// </summary>
    [HttpGet("templates/{id}")]
    [ProducesResponseType(typeof(GameTemplateDto), 200)]
    [ProducesResponseType(404)]
    public IActionResult GetTemplate(string id)
    {
        var template = _templateService.GetTemplateById(id);
        if (template == null) return NotFound();
        return Ok(template);
    }

    /// <summary>
    /// Get templates by category
    /// </summary>
    [HttpGet("templates/category/{category}")]
    [ProducesResponseType(typeof(IEnumerable<GameTemplateDto>), 200)]
    public IActionResult GetTemplatesByCategory(string category)
    {
        var templates = _templateService.GetTemplatesByCategory(category);
        return Ok(templates);
    }

    /// <summary>
    /// Deploy a new game server using a template
    /// </summary>
    [HttpPost("deploy")]
    [Authorize(Roles = "Admin,SuperAdmin")]
    [ProducesResponseType(typeof(ServerDto), 201)]
    [ProducesResponseType(400)]
    public async Task<IActionResult> DeployServer([FromBody] DeployServerRequest request)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        // Validate template
        var template = _templateService.GetTemplateById(request.GameTemplateId);
        if (template == null)
        {
            return BadRequest(new { message = $"Unknown game template: {request.GameTemplateId}" });
        }

        // Validate node
        var node = await _nodeService.GetNodeByIdAsync(request.NodeId);
        if (node == null)
        {
            return BadRequest(new { message = "Node not found" });
        }

        // Build environment variables from template defaults + overrides
        var envVars = new Dictionary<string, string>();
        foreach (var variable in template.Variables)
        {
            if (request.Variables.TryGetValue(variable.EnvVariable, out var value))
            {
                envVars[variable.EnvVariable] = value;
            }
            else if (!string.IsNullOrEmpty(variable.DefaultValue))
            {
                envVars[variable.EnvVariable] = variable.DefaultValue;
            }
            else if (variable.Required)
            {
                return BadRequest(new { message = $"Required variable missing: {variable.Name}" });
            }
        }

        // Determine ports
        var mainPort = template.Ports.FirstOrDefault(p => p.Required)?.DefaultPort ?? 25565;
        if (request.PortMappings != null && request.PortMappings.Count > 0)
        {
            mainPort = request.PortMappings.Values.First();
        }

        // Create server request
        var createRequest = new CreateServerRequest(
            Name: request.ServerName,
            Description: request.Description,
            NodeId: request.NodeId,
            EggId: null,
            DockerImage: template.DockerImage,
            StartupCommand: null,
            MemoryLimit: request.MemoryLimit ?? template.DefaultMemory,
            CpuLimit: request.CpuLimit ?? template.DefaultCpu,
            DiskLimit: request.DiskLimit ?? template.DefaultDisk,
            Port: mainPort,
            EnvironmentVariables: envVars
        );

        var server = await _serverService.CreateServerAsync(createRequest, userId.Value);
        if (server == null)
        {
            return BadRequest(new { message = "Failed to create server" });
        }

        return CreatedAtAction(nameof(GetDeploymentStatus), new { serverId = server.Id }, server);
    }

    /// <summary>
    /// Quick deploy with minimal configuration
    /// </summary>
    [HttpPost("quick-deploy")]
    [Authorize(Roles = "Admin,SuperAdmin")]
    [ProducesResponseType(typeof(ServerDto), 201)]
    [ProducesResponseType(400)]
    public async Task<IActionResult> QuickDeploy([FromBody] QuickDeployRequest request)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var template = _templateService.GetTemplateById(request.GameTemplateId);
        if (template == null)
        {
            return BadRequest(new { message = $"Unknown game template: {request.GameTemplateId}" });
        }

        // Build variables with defaults
        var variables = new Dictionary<string, string>();
        foreach (var variable in template.Variables)
        {
            if (request.OverrideVariables != null && 
                request.OverrideVariables.TryGetValue(variable.EnvVariable, out var overrideValue))
            {
                variables[variable.EnvVariable] = overrideValue;
            }
            else if (!string.IsNullOrEmpty(variable.DefaultValue))
            {
                variables[variable.EnvVariable] = variable.DefaultValue;
            }
        }

        // Set server name in appropriate variable
        if (template.Variables.Any(v => v.EnvVariable == "SERVER_NAME"))
        {
            variables["SERVER_NAME"] = request.ServerName;
        }

        // Generate admin password if required and not provided
        var adminPassVar = template.Variables.FirstOrDefault(v => 
            v.EnvVariable.Contains("ADMIN") && v.EnvVariable.Contains("PASSWORD"));
        if (adminPassVar != null && !variables.ContainsKey(adminPassVar.EnvVariable))
        {
            variables[adminPassVar.EnvVariable] = GeneratePassword(12);
        }

        var deployRequest = new DeployServerRequest(
            GameTemplateId: request.GameTemplateId,
            ServerName: request.ServerName,
            Description: $"Quick deployed {template.Name} server",
            NodeId: request.NodeId,
            MemoryLimit: template.DefaultMemory,
            CpuLimit: template.DefaultCpu,
            DiskLimit: template.DefaultDisk,
            PortMappings: null,
            Variables: variables
        );

        return await DeployServer(deployRequest);
    }

    /// <summary>
    /// Get deployment status for a server
    /// </summary>
    [HttpGet("status/{serverId:guid}")]
    [Authorize]
    [ProducesResponseType(typeof(DeploymentProgressDto), 200)]
    [ProducesResponseType(404)]
    public async Task<IActionResult> GetDeploymentStatus(Guid serverId)
    {
        var server = await _serverService.GetServerByIdAsync(serverId);
        if (server == null) return NotFound();

        var progress = new DeploymentProgressDto(
            DeploymentId: serverId,
            Status: MapServerStatusToDeploymentStatus(server.Status),
            Progress: CalculateProgress(server.Status),
            CurrentStep: GetCurrentStep(server.Status),
            ErrorMessage: server.Status.ToString() == "Error" ? "Deployment failed" : null,
            ServerId: server.Id
        );

        return Ok(progress);
    }

    /// <summary>
    /// Get recommended settings for a template based on player count
    /// </summary>
    [HttpGet("templates/{id}/recommendations")]
    [ProducesResponseType(200)]
    public IActionResult GetRecommendations(string id, [FromQuery] int playerCount = 10)
    {
        var template = _templateService.GetTemplateById(id);
        if (template == null) return NotFound();

        // Calculate recommended resources based on game and player count
        var recommendations = new
        {
            Memory = CalculateRecommendedMemory(id, playerCount),
            Cpu = CalculateRecommendedCpu(id, playerCount),
            Disk = template.DefaultDisk,
            Notes = GetScalingNotes(id, playerCount)
        };

        return Ok(recommendations);
    }

    private Guid? GetUserId()
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        return Guid.TryParse(userIdClaim, out var userId) ? userId : null;
    }

    private static string GeneratePassword(int length)
    {
        const string chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*";
        return new string(Enumerable.Range(0, length)
            .Select(_ => chars[RandomNumberGenerator.GetInt32(chars.Length)])
            .ToArray());
    }

    private static string MapServerStatusToDeploymentStatus(ServerStatus status) => status switch
    {
        ServerStatus.Installing => "creating_container",
        ServerStatus.Starting => "starting",
        ServerStatus.Running => "complete",
        ServerStatus.Stopped => "complete",
        ServerStatus.Error => "failed",
        _ => "pending"
    };

    private static int CalculateProgress(ServerStatus status) => status switch
    {
        ServerStatus.Installing => 50,
        ServerStatus.Starting => 80,
        ServerStatus.Running => 100,
        ServerStatus.Stopped => 100,
        ServerStatus.Error => 0,
        _ => 10
    };

    private static string GetCurrentStep(ServerStatus status) => status switch
    {
        ServerStatus.Installing => "Creating container and downloading files...",
        ServerStatus.Starting => "Starting game server...",
        ServerStatus.Running => "Server is running",
        ServerStatus.Stopped => "Server is ready",
        ServerStatus.Error => "Deployment failed",
        _ => "Preparing deployment..."
    };

    private static int CalculateRecommendedMemory(string templateId, int playerCount) => templateId switch
    {
        "minecraft-java" => 1024 + (playerCount * 100), // 1GB base + 100MB per player
        "minecraft-bedrock" => 512 + (playerCount * 50), // 512MB base + 50MB per player
        "project-zomboid" => 2048 + (playerCount * 150), // 2GB base + 150MB per player
        "arma-reforger" => 4096 + (playerCount * 100), // 4GB base + 100MB per player
        _ => 1024 + (playerCount * 50)
    };

    private static int CalculateRecommendedCpu(string templateId, int playerCount) => templateId switch
    {
        "minecraft-java" => Math.Min(100 + (playerCount * 5), 400),
        "minecraft-bedrock" => Math.Min(50 + (playerCount * 3), 200),
        "project-zomboid" => Math.Min(100 + (playerCount * 10), 400),
        "arma-reforger" => Math.Min(150 + (playerCount * 5), 400),
        _ => Math.Min(100 + (playerCount * 5), 400)
    };

    private static string GetScalingNotes(string templateId, int playerCount) => templateId switch
    {
        "minecraft-java" when playerCount > 50 => "Consider using Paper server with async chunk loading for 50+ players",
        "project-zomboid" when playerCount > 32 => "Large player counts may require additional CPU allocation",
        "arma-reforger" when playerCount > 40 => "64-player servers require significant resources",
        _ => null
    } ?? "Resources scale automatically based on player count";
}
