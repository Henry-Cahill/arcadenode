using ServerPanel.API.DTOs;

namespace ServerPanel.API.Common;

/// <summary>
/// Helpers for opt-in list pagination. When a client omits pageSize, the full
/// (unbounded) set is returned to preserve backwards-compatible behavior; when a
/// pageSize is supplied it is clamped to <see cref="MaxPageSize"/>.
/// </summary>
public static class Pagination
{
    public const int MaxPageSize = 200;

    /// <summary>
    /// Resolves the effective (page, pageSize). A null pageSize yields int.MaxValue,
    /// meaning "return everything".
    /// </summary>
    public static (int Page, int PageSize) Resolve(int? page, int? pageSize)
    {
        var resolvedPage = page.GetValueOrDefault(1);
        if (resolvedPage < 1) resolvedPage = 1;

        if (!pageSize.HasValue)
        {
            return (resolvedPage, int.MaxValue);
        }

        return (resolvedPage, Math.Clamp(pageSize.Value, 1, MaxPageSize));
    }

    /// <summary>Computes a safe OFFSET that never overflows when returning "all".</summary>
    public static int Skip(int page, int pageSize) =>
        pageSize == int.MaxValue ? 0 : (page - 1) * pageSize;
}

public static class PaginationHttpExtensions
{
    public static void ApplyPaginationHeaders<T>(this HttpResponse response, PagedResult<T> result)
    {
        response.Headers["X-Total-Count"] = result.TotalCount.ToString();
        response.Headers["X-Page"] = result.Page.ToString();
        response.Headers["X-Page-Size"] =
            (result.PageSize == int.MaxValue ? result.TotalCount : result.PageSize).ToString();
    }
}
