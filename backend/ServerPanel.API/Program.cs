using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using System.Text;
using System.Text.Json.Serialization;
using System.Security.Cryptography;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.AspNetCore.HttpOverrides;
using ServerPanel.API.Data;
using ServerPanel.API.Services;
using ServerPanel.API.Models;
using ServerPanel.API.Middleware;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container
builder.Services.AddControllers()
    .AddJsonOptions(options =>
    {
        options.JsonSerializerOptions.Converters.Add(new JsonStringEnumConverter());
    })
    .ConfigureApiBehaviorOptions(options =>
    {
        // Log model validation errors instead of returning automatic 400
        options.InvalidModelStateResponseFactory = context =>
        {
            var logger = context.HttpContext.RequestServices.GetRequiredService<ILoggerFactory>()
                .CreateLogger("ModelValidation");
            
            var errors = context.ModelState
                .Where(e => e.Value?.Errors.Count > 0)
                .Select(e => new { Field = e.Key, Errors = e.Value?.Errors.Select(x => x.ErrorMessage) })
                .ToList();
            
            logger.LogWarning("Model validation failed for {Path}: {@Errors}", 
                context.HttpContext.Request.Path, errors);
            
            return new Microsoft.AspNetCore.Mvc.BadRequestObjectResult(new { 
                message = "Validation failed", 
                errors = errors 
            });
        };
    });
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new() { Title = "Server Panel API", Version = "v1" });
    c.AddSecurityDefinition("Bearer", new Microsoft.OpenApi.Models.OpenApiSecurityScheme
    {
        Description = "JWT Authorization header using the Bearer scheme",
        Name = "Authorization",
        In = Microsoft.OpenApi.Models.ParameterLocation.Header,
        Type = Microsoft.OpenApi.Models.SecuritySchemeType.ApiKey,
        Scheme = "Bearer"
    });
    c.AddSecurityRequirement(new Microsoft.OpenApi.Models.OpenApiSecurityRequirement
    {
        {
            new Microsoft.OpenApi.Models.OpenApiSecurityScheme
            {
                Reference = new Microsoft.OpenApi.Models.OpenApiReference
                {
                    Type = Microsoft.OpenApi.Models.ReferenceType.SecurityScheme,
                    Id = "Bearer"
                }
            },
            Array.Empty<string>()
        }
    });
});

// Database Context
builder.Services.AddDbContext<PanelDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));

// JWT Authentication
var jwtKey = builder.Configuration["Jwt:Key"];
if (string.IsNullOrWhiteSpace(jwtKey))
{
    throw new InvalidOperationException(
        "JWT signing key is not configured. Set the 'Jwt:Key' value (e.g. the " +
        "Jwt__Key environment variable) before starting the application.");
}
if (jwtKey.Length < 32)
{
    throw new InvalidOperationException(
        "JWT signing key must be at least 32 characters for HMAC-SHA256 security.");
}
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = builder.Configuration["Jwt:Issuer"] ?? "ServerPanel",
            ValidAudience = builder.Configuration["Jwt:Audience"] ?? "ServerPanelUsers",
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey))
        };
    });

builder.Services.AddAuthorization();

// Rate limiting: throttle authentication endpoints to slow brute-force / abuse.
builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    options.AddFixedWindowLimiter("auth", limiterOptions =>
    {
        limiterOptions.Window = TimeSpan.FromMinutes(1);
        limiterOptions.PermitLimit = 10;
        limiterOptions.QueueLimit = 0;
        limiterOptions.QueueProcessingOrder = QueueProcessingOrder.OldestFirst;
    });
});

// Custom Services
builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.AddScoped<IServerService, ServerService>();
builder.Services.AddScoped<INodeService, NodeService>();
builder.Services.AddSingleton<IDockerClientFactory, DockerClientFactory>();
builder.Services.AddScoped<IDockerService, DockerService>();
builder.Services.AddSingleton<IGameTemplateService, GameTemplateService>();
builder.Services.AddSingleton<ICartridgeService, CartridgeService>();

// CSRF / Anti-Forgery (double-submit cookie pattern)
builder.Services.AddAntiforgery(options =>
{
    options.HeaderName = "X-XSRF-TOKEN";
    options.Cookie.Name = ".AspNetCore.Antiforgery";
    options.Cookie.SameSite = SameSiteMode.Strict;
});

// CORS
var corsOrigins = builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>()
    ?? new[] { "http://localhost:3000", "http://frontend:80" };
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowFrontend", policy =>
    {
        policy.WithOrigins(corsOrigins)
              .WithMethods("GET", "POST", "PUT", "DELETE")
              .WithHeaders("Content-Type", "Authorization", "X-XSRF-TOKEN")
              .WithExposedHeaders("X-Total-Count", "X-Page", "X-Page-Size")
              .AllowCredentials();
    });
});

var app = builder.Build();

// Configure the HTTP request pipeline
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}
else
{
    // Behind a TLS-terminating reverse proxy: honor the forwarded scheme, then
    // enforce HTTPS. Disabled in Development where the container serves plain HTTP.
    app.UseForwardedHeaders(new ForwardedHeadersOptions
    {
        ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto
    });
    app.UseHsts();
    app.UseHttpsRedirection();
}

app.UseCors("AllowFrontend");
app.UseRateLimiter();
app.UseAuthentication();
app.UseAuditLogging();
app.UseAuthorization();
app.UseCsrfProtection();
app.MapControllers();

// Auto-migrate database and seed admin user
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<PanelDbContext>();
    // Apply any pending EF Core migrations (creates the schema on a fresh database).
    db.Database.Migrate();

    // Seed default admin user if not exists
    if (!db.Users.Any(u => u.Username == "admin"))
    {
        var adminPassword = builder.Configuration["Seed:AdminPassword"];
        var passwordWasGenerated = false;
        if (string.IsNullOrWhiteSpace(adminPassword))
        {
            adminPassword = GenerateSecurePassword(20);
            passwordWasGenerated = true;
        }

        var adminUser = new User
        {
            Id = Guid.NewGuid(),
            Username = "admin",
            Email = "admin@panel.local",
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(adminPassword),
            FirstName = "Admin",
            LastName = "User",
            Role = UserRole.SuperAdmin,
            IsActive = true,
            CreatedAt = DateTime.UtcNow
        };
        db.Users.Add(adminUser);
        db.SaveChanges();

        if (passwordWasGenerated)
        {
            Console.WriteLine("=================================================================");
            Console.WriteLine("Initial admin account created (no Seed:AdminPassword configured).");
            Console.WriteLine("  Username: admin");
            Console.WriteLine($"  Password: {adminPassword}");
            Console.WriteLine("Store this now - it will not be shown again. Change it after login.");
            Console.WriteLine("=================================================================");
        }
        else
        {
            Console.WriteLine("Initial admin account 'admin' created using the configured Seed:AdminPassword.");
        }
    }
}

app.Run();

static string GenerateSecurePassword(int length)
{
    const string chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*";
    return new string(Enumerable.Range(0, length)
        .Select(_ => chars[RandomNumberGenerator.GetInt32(chars.Length)])
        .ToArray());
}
