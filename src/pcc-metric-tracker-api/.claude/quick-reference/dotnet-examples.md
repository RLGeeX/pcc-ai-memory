
# .NET Examples

Quick reference examples for common .NET patterns and commands.

## Basic Console App Structure
```csharp
// src/Program.cs
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

class Program
{
    static async Task Main(string[] args)
    {
        var builder = Host.CreateApplicationBuilder(args);
        
        builder.Services.AddLogging();
        builder.Services.AddScoped<IUserService, UserService>();
        
        var host = builder.Build();
        var userService = host.Services.GetRequiredService<IUserService>();
        
        await userService.ProcessUsersAsync();
        
        await host.RunAsync();
    }
}

// src/Services/IUserService.cs
public interface IUserService
{
    Task ProcessUsersAsync();
}

// src/Services/UserService.cs
public class UserService : IUserService
{
    private readonly ILogger<UserService> _logger;
    
    public UserService(ILogger<UserService> logger)
    {
        _logger = logger;
    }
    
    public async Task ProcessUsersAsync()
    {
        _logger.LogInformation("Processing users...");
        // Implementation
        await Task.CompletedTask;
    }
}