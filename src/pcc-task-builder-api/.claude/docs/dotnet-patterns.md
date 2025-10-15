# .NET Patterns and Examples

Detailed patterns and examples for .NET projects.

## Dependency Injection with Services
```csharp
// src/Program.cs
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

var builder = Host.CreateApplicationBuilder(args);

builder.Services.AddScoped<IEmailService, EmailService>();
builder.Services.AddScoped<IUserRepository, UserRepository>();

var host = builder.Build();
await host.RunAsync();

// src/Services/IEmailService.cs
public interface IEmailService
{
    Task SendAsync(string to, string message);
}

// src/Services/EmailService.cs
public class EmailService : IEmailService
{
    public async Task SendAsync(string to, string message)
    {
        // Implementation
        await Task.CompletedTask;
    }
}