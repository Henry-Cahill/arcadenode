using ServerPanel.API.DTOs;
using ServerPanel.API.Models;

namespace ServerPanel.API.Services;

public interface IAuthService
{
    Task<AuthResponse?> LoginAsync(LoginRequest request);
    Task<(AuthResponse? Response, string? Error)> RegisterAsync(RegisterRequest request);
    Task<UserDto?> GetUserByIdAsync(Guid id);
    Task<PagedResult<UserDto>> GetAllUsersAsync(int page = 1, int pageSize = int.MaxValue);
    Task<bool> UpdateUserAsync(Guid id, string? firstName, string? lastName, string? email);
    Task<bool> ChangePasswordAsync(Guid id, string currentPassword, string newPassword);
    Task<bool> DeleteUserAsync(Guid id);
}
