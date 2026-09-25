using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using ServerPanel.API.Data;
using ServerPanel.API.DTOs;
using ServerPanel.API.Models;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;

namespace ServerPanel.API.Services;

public class AuthService : IAuthService
{
    private const int MaxFailedLoginAttempts = 5;
    private static readonly TimeSpan LockoutDuration = TimeSpan.FromMinutes(15);

    private readonly PanelDbContext _context;
    private readonly IConfiguration _configuration;
    private readonly ILogger<AuthService> _logger;

    public AuthService(PanelDbContext context, IConfiguration configuration, ILogger<AuthService> logger)
    {
        _context = context;
        _configuration = configuration;
        _logger = logger;
    }

    public async Task<AuthResponse?> LoginAsync(LoginRequest request)
    {
        var user = await _context.Users
            .FirstOrDefaultAsync(u => u.Username == request.Username || u.Email == request.Username);

        if (user == null)
        {
            return null;
        }

        // Reject while the account is inside an active lockout window.
        if (user.LockoutEnd.HasValue && user.LockoutEnd.Value > DateTime.UtcNow)
        {
            _logger.LogWarning("Login attempt for locked-out user {UserId} (until {LockoutEnd})",
                user.Id, user.LockoutEnd.Value);
            return null;
        }

        if (!BCrypt.Net.BCrypt.Verify(request.Password, user.PasswordHash))
        {
            user.FailedLoginAttempts++;
            if (user.FailedLoginAttempts >= MaxFailedLoginAttempts)
            {
                user.LockoutEnd = DateTime.UtcNow.Add(LockoutDuration);
                user.FailedLoginAttempts = 0;
                _logger.LogWarning("User {UserId} locked out until {LockoutEnd} after repeated failed logins",
                    user.Id, user.LockoutEnd.Value);
            }
            await _context.SaveChangesAsync();
            return null;
        }

        if (!user.IsActive)
        {
            return null;
        }

        // A successful login clears any prior failure / lockout state.
        if (user.FailedLoginAttempts != 0 || user.LockoutEnd != null)
        {
            user.FailedLoginAttempts = 0;
            user.LockoutEnd = null;
        }

        user.LastLoginAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();

        var token = GenerateJwtToken(user);
        var expiresAt = DateTime.UtcNow.AddMinutes(
            int.Parse(_configuration["Jwt:ExpireMinutes"] ?? "60"));

        return new AuthResponse(token, MapToDto(user), expiresAt);
    }

    public async Task<(AuthResponse? Response, string? Error)> RegisterAsync(RegisterRequest request)
    {
        // Validate invite code
        var invite = await _context.InviteCodes
            .FirstOrDefaultAsync(i => i.Code == request.InviteCode);

        if (invite == null || !invite.IsValid)
        {
            return (null, "Invalid or expired invite code");
        }

        // Check if username or email already exists
        if (await _context.Users.AnyAsync(u => u.Username == request.Username))
        {
            return (null, "Username already exists");
        }

        if (await _context.Users.AnyAsync(u => u.Email == request.Email))
        {
            return (null, "Email already exists");
        }

        var user = new User
        {
            Username = request.Username,
            Email = request.Email,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(request.Password),
            FirstName = request.FirstName ?? "",
            LastName = request.LastName ?? "",
            Role = UserRole.User,
            IsActive = true
        };

        _context.Users.Add(user);

        // Increment invite code usage
        invite.TimesUsed++;

        await _context.SaveChangesAsync();

        var token = GenerateJwtToken(user);
        var expiresAt = DateTime.UtcNow.AddMinutes(
            int.Parse(_configuration["Jwt:ExpireMinutes"] ?? "60"));

        return (new AuthResponse(token, MapToDto(user), expiresAt), null);
    }

    public async Task<UserDto?> GetUserByIdAsync(Guid id)
    {
        var user = await _context.Users.FindAsync(id);
        return user == null ? null : MapToDto(user);
    }

    public async Task<PagedResult<UserDto>> GetAllUsersAsync(int page = 1, int pageSize = int.MaxValue)
    {
        var query = _context.Users.OrderByDescending(u => u.CreatedAt);

        var total = await query.CountAsync();
        var skip = pageSize == int.MaxValue ? 0 : (page - 1) * pageSize;
        var users = await query.Skip(skip).Take(pageSize).ToListAsync();

        return new PagedResult<UserDto>(users.Select(MapToDto).ToList(), page, pageSize, total);
    }

    public async Task<bool> UpdateUserAsync(Guid id, string? firstName, string? lastName, string? email)
    {
        var user = await _context.Users.FindAsync(id);
        if (user == null) return false;

        if (!string.IsNullOrEmpty(firstName)) user.FirstName = firstName;
        if (!string.IsNullOrEmpty(lastName)) user.LastName = lastName;
        if (!string.IsNullOrEmpty(email))
        {
            if (await _context.Users.AnyAsync(u => u.Email == email && u.Id != id))
            {
                return false;
            }
            user.Email = email;
        }

        await _context.SaveChangesAsync();
        return true;
    }

    public async Task<bool> ChangePasswordAsync(Guid id, string currentPassword, string newPassword)
    {
        var user = await _context.Users.FindAsync(id);
        if (user == null) return false;

        if (!BCrypt.Net.BCrypt.Verify(currentPassword, user.PasswordHash))
        {
            return false;
        }

        user.PasswordHash = BCrypt.Net.BCrypt.HashPassword(newPassword);
        await _context.SaveChangesAsync();
        return true;
    }

    public async Task<bool> DeleteUserAsync(Guid id)
    {
        var user = await _context.Users.FindAsync(id);
        if (user == null) return false;

        _context.Users.Remove(user);
        await _context.SaveChangesAsync();
        return true;
    }

    private string GenerateJwtToken(User user)
    {
        var jwtKey = _configuration["Jwt:Key"]
            ?? throw new InvalidOperationException("JWT signing key is not configured.");
        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey));
        var credentials = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

        var claims = new[]
        {
            new Claim(ClaimTypes.NameIdentifier, user.Id.ToString()),
            new Claim(ClaimTypes.Name, user.Username),
            new Claim(ClaimTypes.Email, user.Email),
            new Claim(ClaimTypes.Role, user.Role.ToString()),
            new Claim("firstName", user.FirstName),
            new Claim("lastName", user.LastName)
        };

        var token = new JwtSecurityToken(
            issuer: _configuration["Jwt:Issuer"] ?? "ServerPanel",
            audience: _configuration["Jwt:Audience"] ?? "ServerPanelUsers",
            claims: claims,
            expires: DateTime.UtcNow.AddMinutes(
                int.Parse(_configuration["Jwt:ExpireMinutes"] ?? "60")),
            signingCredentials: credentials
        );

        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    private static UserDto MapToDto(User user) => new(
        user.Id,
        user.Username,
        user.Email,
        user.FirstName,
        user.LastName,
        user.Role,
        user.IsActive,
        user.CreatedAt,
        user.LastLoginAt
    );
}
