using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using ServerPanel.API.DTOs;
using ServerPanel.API.Models;
using ServerPanel.API.Services;

namespace ServerPanel.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class CartridgesController : ControllerBase
{
    private readonly ICartridgeService _cartridgeService;
    private readonly ILogger<CartridgesController> _logger;

    public CartridgesController(ICartridgeService cartridgeService, ILogger<CartridgesController> logger)
    {
        _cartridgeService = cartridgeService;
        _logger = logger;
    }

    /// <summary>
    /// Get all available cartridges
    /// </summary>
    [HttpGet]
    public ActionResult<IEnumerable<CartridgeListDto>> GetAll()
    {
        var cartridges = _cartridgeService.GetAllCartridges()
            .Select(c => new CartridgeListDto(
                c.Id,
                c.Name,
                c.Description,
                c.Category,
                c.Tags,
                c.Icon,
                c.Docker.Image,
                c.Resources.Memory.Recommended,
                c.Resources.Cpu.Recommended,
                c.Ports.Values.FirstOrDefault()?.Default ?? 0
            ));

        return Ok(cartridges);
    }

    /// <summary>
    /// Get a specific cartridge by ID
    /// </summary>
    [HttpGet("{id}")]
    public ActionResult<CartridgeDetailDto> GetById(string id)
    {
        var cartridge = _cartridgeService.GetCartridgeById(id);
        
        if (cartridge == null)
        {
            return NotFound(new { message = $"Cartridge '{id}' not found" });
        }

        return Ok(MapToDetailDto(cartridge));
    }

    /// <summary>
    /// Get cartridges by category
    /// </summary>
    [HttpGet("category/{category}")]
    public ActionResult<IEnumerable<CartridgeListDto>> GetByCategory(string category)
    {
        var cartridges = _cartridgeService.GetCartridgesByCategory(category)
            .Select(c => new CartridgeListDto(
                c.Id,
                c.Name,
                c.Description,
                c.Category,
                c.Tags,
                c.Icon,
                c.Docker.Image,
                c.Resources.Memory.Recommended,
                c.Resources.Cpu.Recommended,
                c.Ports.Values.FirstOrDefault()?.Default ?? 0
            ));

        return Ok(cartridges);
    }

    /// <summary>
    /// Reload cartridges from disk (admin only)
    /// </summary>
    [HttpPost("reload")]
    [Authorize(Roles = "Admin")]
    public ActionResult Reload()
    {
        _cartridgeService.ReloadCartridges();
        return Ok(new { message = "Cartridges reloaded successfully" });
    }

    /// <summary>
    /// Validate variable values against cartridge definition
    /// </summary>
    [HttpPost("{id}/validate")]
    public ActionResult ValidateVariables(string id, [FromBody] Dictionary<string, object> values)
    {
        var cartridge = _cartridgeService.GetCartridgeById(id);
        
        if (cartridge == null)
        {
            return NotFound(new { message = $"Cartridge '{id}' not found" });
        }

        var (isValid, errors) = _cartridgeService.ValidateVariables(cartridge, values);

        return Ok(new
        {
            valid = isValid,
            errors = errors
        });
    }

    /// <summary>
    /// Get categories with cartridge counts
    /// </summary>
    [HttpGet("categories")]
    public ActionResult<IEnumerable<CategoryDto>> GetCategories()
    {
        var categories = _cartridgeService.GetAllCartridges()
            .GroupBy(c => c.Category)
            .Select(g => new CategoryDto(g.Key, g.Count()))
            .OrderBy(c => c.Name);

        return Ok(categories);
    }

    private CartridgeDetailDto MapToDetailDto(Cartridge cartridge)
    {
        return new CartridgeDetailDto
        {
            Id = cartridge.Id,
            Name = cartridge.Name,
            Author = cartridge.Author,
            Description = cartridge.Description,
            Category = cartridge.Category,
            Tags = cartridge.Tags,
            Website = cartridge.Website,
            Icon = cartridge.Icon,
            Docker = new DockerDto
            {
                Image = cartridge.Docker.Image,
                BaseImage = cartridge.Docker.BaseImage
            },
            Ports = cartridge.Ports.Select(p => new PortDto
            {
                Name = p.Key,
                Default = p.Value.Default,
                Protocol = p.Value.Protocol,
                Required = p.Value.Required,
                Description = p.Value.Description
            }).ToList(),
            Resources = new ResourcesDto
            {
                Memory = new ResourceLimitDto
                {
                    Minimum = cartridge.Resources.Memory.Minimum,
                    Recommended = cartridge.Resources.Memory.Recommended,
                    Maximum = cartridge.Resources.Memory.Maximum
                },
                Cpu = new ResourceLimitDto
                {
                    Minimum = cartridge.Resources.Cpu.Minimum,
                    Recommended = cartridge.Resources.Cpu.Recommended,
                    Maximum = cartridge.Resources.Cpu.Maximum
                }
            },
            Variables = cartridge.Variables.Select(v => new VariableDto
            {
                Id = v.Id,
                Name = v.Name,
                Description = v.Description,
                EnvVariable = v.EnvVariable,
                Type = v.Type,
                Default = v.Default,
                Required = v.Required,
                UserViewable = v.UserViewable,
                UserEditable = v.UserEditable,
                Validation = v.Validation != null ? new ValidationDto
                {
                    Min = v.Validation.Min,
                    Max = v.Validation.Max,
                    MinLength = v.Validation.MinLength,
                    MaxLength = v.Validation.MaxLength,
                    Pattern = v.Validation.Pattern
                } : null,
                UI = v.UI != null ? new UIDto
                {
                    Component = v.UI.Component,
                    Placeholder = v.UI.Placeholder,
                    Group = v.UI.Group,
                    Help = v.UI.Help,
                    Options = v.UI.Options?.Select(o => new SelectOptionDto
                    {
                        Value = o.Value,
                        Label = o.Label
                    }).ToList(),
                    Step = v.UI.Step,
                    Marks = v.UI.Marks,
                    Rows = v.UI.Rows,
                    Prefix = v.UI.Prefix,
                    Suffix = v.UI.Suffix,
                    OnLabel = v.UI.OnLabel,
                    OffLabel = v.UI.OffLabel
                } : null
            }).ToList(),
            VariableGroups = cartridge.VariableGroups?.Select(g => new VariableGroupDto
            {
                Id = g.Id,
                Name = g.Name,
                Description = g.Description,
                Order = g.Order,
                Collapsed = g.Collapsed,
                AdminOnly = g.AdminOnly
            }).ToList(),
            Console = cartridge.Console != null ? new ConsoleDto
            {
                Enabled = cartridge.Console.Enabled,
                Type = cartridge.Console.Type,
                Commands = cartridge.Console.Commands?.Select(c => new ConsoleCommandDto
                {
                    Name = c.Key,
                    Command = c.Value.Command,
                    Description = c.Value.Description,
                    Parameters = c.Value.Parameters?.Select(p => new CommandParameterDto
                    {
                        Name = p.Name,
                        Type = p.Type,
                        Required = p.Required,
                        Default = p.Default,
                        Options = p.Options
                    }).ToList()
                }).ToList()
            } : null,
            Startup = new StartupDto
            {
                Command = cartridge.Startup.Command,
                ReadyPattern = cartridge.Startup.ReadyPattern,
                ReadyTimeout = cartridge.Startup.ReadyTimeout
            },
            Process = new ProcessDto
            {
                StopCommand = cartridge.Process.StopCommand,
                StopTimeout = cartridge.Process.StopTimeout,
                RestartOnCrash = cartridge.Process.RestartOnCrash
            }
        };
    }
}
