using System.ComponentModel.DataAnnotations;
using ServerPanel.API.Validation;

namespace ServerPanel.API.DTOs;

public record UpdateProfileRequest(
    [MaxLength(50)] string? FirstName,
    [MaxLength(50)] string? LastName,
    [EmailAddress][MaxLength(255)] string? Email);

public record ChangePasswordRequest(
    [Required] string CurrentPassword,
    [Required][PasswordComplexity] string NewPassword);
