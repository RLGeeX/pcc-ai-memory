# .NET Commands

This section provides a comprehensive list of CLI commands for managing a .NET 10 project named '.claude'. These commands assume you have a development environment set up and the project is cloned from a repository. All commands use the `dotnet` CLI tool.

- **Install .NET 10 SDK**  
  Download and install the .NET 10 SDK from the official Microsoft website or using a package manager. For example, on Windows via winget:  
  ```
  winget install Microsoft.DotNet.SDK.10
  ```  
  Verify the installation:  
  ```
  dotnet --version
  ```  
  This should output a version starting with `10.`.

- **Restore Dependencies**  
  Restore NuGet packages and project dependencies for the '.claude' project:  
  ```
  dotnet restore ./claude.sln
  ```  
  Or for a specific project:  
  ```
  dotnet restore ./src/claude/claude.csproj
  ```

- **Build the Project**  
  Build the '.claude' project in Release configuration:  
  ```
  dotnet build ./claude.sln --configuration Release
  ```  
  For a specific project with verbosity:  
  ```
  dotnet build ./src/claude/claude.csproj --configuration Debug -v detailed
  ```

- **Run the Application**  
  Run the '.claude' application from the project directory:  
  ```
  dotnet run --project ./src/claude/claude.csproj
  ```  
  Run with a specific configuration and environment:  
  ```
  dotnet run --project ./src/claude/claude.csproj --configuration Release --environment Development
  ```

- **Test the Project**  
  Run unit and integration tests for the '.claude' project:  
  ```
  dotnet test ./claude.sln --configuration Release --logger trx
  ```  
  Run tests with coverage:  
  ```
  dotnet test ./claude.sln --collect:"XPlat Code Coverage"
  ```

- **Format Code**  
  Apply code formatting using the .NET analyzers:  
  ```
  dotnet format ./claude.sln --verbosity detailed
  ```  
  Format a specific file or directory:  
  ```
  dotnet format ./src/claude/Program.cs --fix-whitespace
  ```

## PostgreSQL-Specific Commands (Entity Framework Core with Npgsql)

These commands are tailored for database operations using Entity Framework Core with the Npgsql provider in the '.claude' project. Ensure the Npgsql.EntityFrameworkCore.PostgreSQL package is added to your project via `dotnet add package Npgsql.EntityFrameworkCore.PostgreSQL --version 10.0.0` (adjust version as needed for .NET 10 compatibility).

- **Add Migration**  
  Create a new migration for database schema changes:  
  ```
  dotnet ef migrations add InitialCreate --project ./src/claude/claude.csproj --startup-project ./src/claude/claude.csproj
  ```  
  For a specific context:  
  ```
  dotnet ef migrations add UpdateUserModel --context ClaudeDbContext --project ./src/claude/claude.csproj
  ```

- **Update Database**  
  Apply pending migrations to the PostgreSQL database:  
  ```
  dotnet ef database update --project ./src/claude/claude.csproj --startup-project ./src/claude/claude.csproj
  ```  
  Update to a specific migration:  
  ```
  dotnet ef database update InitialCreate --project ./src/claude/claude.csproj
  ```

- **Generate SQL Script**  
  Generate a SQL script for migrations (useful for review before applying):  
  ```
  dotnet ef migrations script --project ./src/claude/claude.csproj --startup-project ./src/claude/claude.csproj > migrations.sql
  ```

- **Remove Last Migration**  
  Revert the last migration (use before updating the database):  
  ```
  dotnet ef migrations remove --project ./src/claude/claude.csproj
  ```

- **List Migrations**  
  View applied and pending migrations:  
  ```
  dotnet ef migrations list --project ./src/claude/claude.csproj
  ```

**Note:** Run `dotnet restore` after cloning the repository. Add new commands here as discovered. Ensure your `appsettings.json` or connection string is configured for PostgreSQL (e.g., `"ConnectionStrings": { "DefaultConnection": "Host=localhost;Database=claude;Username=postgres;Password=yourpassword" }`). Install the EF Core tools globally if needed: `dotnet tool install --global dotnet-ef`.