using System.ComponentModel.DataAnnotations;

namespace ServerPanel.API.Validation;

/// <summary>
/// Validates that a password meets minimum complexity: at least <see cref="MinimumLength"/>
/// characters including an uppercase letter, a lowercase letter, a digit, and a special character.
/// </summary>
public sealed class PasswordComplexityAttribute : ValidationAttribute
{
    public int MinimumLength { get; init; } = 8;

    public override bool IsValid(object? value)
    {
        if (value is not string password || password.Length < MinimumLength)
        {
            return false;
        }

        bool hasUpper = false, hasLower = false, hasDigit = false, hasSpecial = false;
        foreach (var c in password)
        {
            if (char.IsUpper(c)) hasUpper = true;
            else if (char.IsLower(c)) hasLower = true;
            else if (char.IsDigit(c)) hasDigit = true;
            else hasSpecial = true;
        }

        return hasUpper && hasLower && hasDigit && hasSpecial;
    }

    public override string FormatErrorMessage(string name) =>
        $"{name} must be at least {MinimumLength} characters and include uppercase, " +
        "lowercase, a digit, and a special character.";
}
