namespace ServerPanel.API.DTOs;

// DTOs for Cartridge API responses (consolidated from CartridgesController).
public record CartridgeListDto(
    string Id,
    string Name,
    string Description,
    string Category,
    List<string> Tags,
    string? Icon,
    string DockerImage,
    int RecommendedMemory,
    int RecommendedCpu,
    int DefaultPort
);

public record CategoryDto(string Name, int Count);

public class CartridgeDetailDto
{
    public string Id { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string Author { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public string Category { get; set; } = string.Empty;
    public List<string> Tags { get; set; } = new();
    public string? Website { get; set; }
    public string? Icon { get; set; }
    public DockerDto Docker { get; set; } = new();
    public List<PortDto> Ports { get; set; } = new();
    public ResourcesDto Resources { get; set; } = new();
    public List<VariableDto> Variables { get; set; } = new();
    public List<VariableGroupDto>? VariableGroups { get; set; }
    public ConsoleDto? Console { get; set; }
    public StartupDto Startup { get; set; } = new();
    public ProcessDto Process { get; set; } = new();
}

public class DockerDto
{
    public string Image { get; set; } = string.Empty;
    public string? BaseImage { get; set; }
}

public class PortDto
{
    public string Name { get; set; } = string.Empty;
    public int Default { get; set; }
    public string Protocol { get; set; } = "tcp";
    public bool Required { get; set; } = true;
    public string? Description { get; set; }
}

public class ResourcesDto
{
    public ResourceLimitDto Memory { get; set; } = new();
    public ResourceLimitDto Cpu { get; set; } = new();
}

public class ResourceLimitDto
{
    public int Minimum { get; set; }
    public int Recommended { get; set; }
    public int Maximum { get; set; }
}

public class VariableDto
{
    public string Id { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public string EnvVariable { get; set; } = string.Empty;
    public string Type { get; set; } = "string";
    public object? Default { get; set; }
    public bool Required { get; set; }
    public bool UserViewable { get; set; } = true;
    public bool UserEditable { get; set; } = true;
    public ValidationDto? Validation { get; set; }
    public UIDto? UI { get; set; }
}

public class ValidationDto
{
    public int? Min { get; set; }
    public int? Max { get; set; }
    public int? MinLength { get; set; }
    public int? MaxLength { get; set; }
    public string? Pattern { get; set; }
}

public class UIDto
{
    public string Component { get; set; } = "text";
    public string? Placeholder { get; set; }
    public string? Group { get; set; }
    public string? Help { get; set; }
    public List<SelectOptionDto>? Options { get; set; }
    public int? Step { get; set; }
    public List<int>? Marks { get; set; }
    public int? Rows { get; set; }
    public string? Prefix { get; set; }
    public string? Suffix { get; set; }
    public string? OnLabel { get; set; }
    public string? OffLabel { get; set; }
}

public class SelectOptionDto
{
    public string Value { get; set; } = string.Empty;
    public string Label { get; set; } = string.Empty;
}

public class VariableGroupDto
{
    public string Id { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public int Order { get; set; }
    public bool Collapsed { get; set; }
    public bool AdminOnly { get; set; }
}

public class ConsoleDto
{
    public bool Enabled { get; set; }
    public string Type { get; set; } = "stdin";
    public List<ConsoleCommandDto>? Commands { get; set; }
}

public class ConsoleCommandDto
{
    public string Name { get; set; } = string.Empty;
    public string Command { get; set; } = string.Empty;
    public string? Description { get; set; }
    public List<CommandParameterDto>? Parameters { get; set; }
}

public class CommandParameterDto
{
    public string Name { get; set; } = string.Empty;
    public string Type { get; set; } = "string";
    public bool Required { get; set; } = true;
    public object? Default { get; set; }
    public List<string>? Options { get; set; }
}

public class StartupDto
{
    public string Command { get; set; } = string.Empty;
    public string? ReadyPattern { get; set; }
    public int ReadyTimeout { get; set; } = 120;
}

public class ProcessDto
{
    public string StopCommand { get; set; } = "stop";
    public int StopTimeout { get; set; } = 30;
    public bool RestartOnCrash { get; set; } = true;
}
