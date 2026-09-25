using Microsoft.AspNetCore.Antiforgery;

namespace ServerPanel.API.Middleware;

/// <summary>
/// Middleware that enforces CSRF protection using the double-submit cookie pattern.
/// On every response, it sets a non-HttpOnly XSRF-TOKEN cookie that JavaScript can read.
/// On mutating requests (POST, PUT, DELETE, PATCH), it validates the X-XSRF-TOKEN header
/// matches the cookie. GET/HEAD/OPTIONS requests are exempt.
/// </summary>
public class CsrfMiddleware
{
    private readonly RequestDelegate _next;
    private readonly IAntiforgery _antiforgery;

    public CsrfMiddleware(RequestDelegate next, IAntiforgery antiforgery)
    {
        _next = next;
        _antiforgery = antiforgery;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        // Always provide the CSRF token cookie on responses
        var tokens = _antiforgery.GetAndStoreTokens(context);
        if (tokens.RequestToken != null)
        {
            context.Response.Cookies.Append("XSRF-TOKEN", tokens.RequestToken, new CookieOptions
            {
                HttpOnly = false,   // JS must read this cookie
                Secure = !context.RequestServices
                    .GetRequiredService<IWebHostEnvironment>().IsDevelopment(),
                SameSite = SameSiteMode.Strict,
                Path = "/"
            });
        }

        // Validate on state-changing methods only
        var method = context.Request.Method;
        if (HttpMethods.IsPost(method) ||
            HttpMethods.IsPut(method) ||
            HttpMethods.IsDelete(method) ||
            HttpMethods.IsPatch(method))
        {
            // Skip validation for the login and register endpoints (no token yet)
            var path = context.Request.Path.Value?.ToLowerInvariant() ?? "";
            if (path.EndsWith("/auth/login") || path.EndsWith("/auth/register"))
            {
                await _next(context);
                return;
            }

            try
            {
                await _antiforgery.ValidateRequestAsync(context);
            }
            catch (AntiforgeryValidationException)
            {
                context.Response.StatusCode = StatusCodes.Status403Forbidden;
                await context.Response.WriteAsJsonAsync(new { message = "CSRF token validation failed" });
                return;
            }
        }

        await _next(context);
    }
}

/// <summary>
/// Extension method to register the CSRF middleware in the pipeline.
/// </summary>
public static class CsrfMiddlewareExtensions
{
    public static IApplicationBuilder UseCsrfProtection(this IApplicationBuilder builder)
    {
        return builder.UseMiddleware<CsrfMiddleware>();
    }
}
