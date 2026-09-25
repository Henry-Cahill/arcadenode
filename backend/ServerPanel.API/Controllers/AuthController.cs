using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using ServerPanel.API.DTOs;
using ServerPanel.API.Services;

namespace ServerPanel.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController : ControllerBase
{
    private readonly IAuthService _authService;

    public AuthController(IAuthService authService)
    {
        _authService = authService;
    }

    /// <summary>
    /// Login with username/email and password
    /// </summary>
    [HttpPost("login")]
    [EnableRateLimiting("auth")]
    [ProducesResponseType(typeof(AuthResponse), 200)]
    [ProducesResponseType(401)]
    public async Task<IActionResult> Login([FromBody] LoginRequest request)
    {
        var response = await _authService.LoginAsync(request);
        if (response == null)
        {
            return Unauthorized(new { message = "Invalid credentials" });
        }
        return Ok(response);
    }

    /// <summary>
    /// Register a new user account (requires a valid invite code)
    /// </summary>
    [HttpPost("register")]
    [EnableRateLimiting("auth")]
    [ProducesResponseType(typeof(AuthResponse), 201)]
    [ProducesResponseType(400)]
    public async Task<IActionResult> Register([FromBody] RegisterRequest request)
    {
        var (response, error) = await _authService.RegisterAsync(request);
        if (response == null)
        {
            return BadRequest(new { message = error ?? "Registration failed" });
        }
        return CreatedAtAction(nameof(GetCurrentUser), response);
    }

    /// <summary>
    /// Get current authenticated user
    /// </summary>
    [HttpGet("me")]
    [Authorize]
    [ProducesResponseType(typeof(UserDto), 200)]
    [ProducesResponseType(401)]
    public async Task<IActionResult> GetCurrentUser()
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var user = await _authService.GetUserByIdAsync(userId.Value);
        if (user == null) return NotFound();

        return Ok(user);
    }

    /// <summary>
    /// Update current user profile
    /// </summary>
    [HttpPut("me")]
    [Authorize]
    [ProducesResponseType(200)]
    [ProducesResponseType(400)]
    public async Task<IActionResult> UpdateProfile([FromBody] UpdateProfileRequest request)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var success = await _authService.UpdateUserAsync(userId.Value, request.FirstName, request.LastName, request.Email);
        if (!success)
        {
            return BadRequest(new { message = "Failed to update profile" });
        }

        return Ok(new { message = "Profile updated successfully" });
    }

    /// <summary>
    /// Change password
    /// </summary>
    [HttpPost("change-password")]
    [Authorize]
    [ProducesResponseType(200)]
    [ProducesResponseType(400)]
    public async Task<IActionResult> ChangePassword([FromBody] ChangePasswordRequest request)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var success = await _authService.ChangePasswordAsync(userId.Value, request.CurrentPassword, request.NewPassword);
        if (!success)
        {
            return BadRequest(new { message = "Current password is incorrect" });
        }

        return Ok(new { message = "Password changed successfully" });
    }

    private Guid? GetUserId()
    {
        var userIdClaim = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
        return Guid.TryParse(userIdClaim, out var userId) ? userId : null;
    }
}
