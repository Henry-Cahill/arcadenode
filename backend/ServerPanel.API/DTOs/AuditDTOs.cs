namespace ServerPanel.API.DTOs;

public record AuditLogDto(
    Guid Id,
    DateTime Timestamp,
    Guid? UserId,
    string? Username,
    string Method,
    string Path,
    int StatusCode,
    string? IpAddress,
    long DurationMs
);

public record PagedResult<T>(
    IReadOnlyList<T> Items,
    int Page,
    int PageSize,
    int TotalCount
);
