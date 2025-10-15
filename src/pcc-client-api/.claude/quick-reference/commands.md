# .NET Commands

This section provides a comprehensive list of CLI commands for managing a .NET 10 project named '.claude'. These commands assume you have the .NET 10 SDK installed. All commands are executed from the project root directory unless specified otherwise.

- **Install .NET 10 SDK**: Download and install the .NET 10 SDK from the official Microsoft website. On Windows, use the installer; on macOS/Linux, use the provided script or package manager (e.g., `winget install Microsoft.DotNet.SDK.10` on Windows). Verify installation with `dotnet --version` (should output 10.x.x).
  
- **Restore Dependencies**: Restore NuGet packages and project dependencies.  
  ```
  dotnet restore
  ```

- **Build the Project**: Compile the project and its dependencies in the current configuration (default: Debug). Use `--configuration Release` for optimized builds.  
  ```
  dotnet build
  ```

- **Run the Application**: Build and execute the project. Specify `--project .claude.csproj` if needed for multi-project solutions.  
  ```
  dotnet run
  ```

- **Test the Project**: Discover, compile, and run unit tests using supported test frameworks (e.g., xUnit, NUnit). Include `--logger trx` for XML output or `--collect:"XPlat Code Coverage"` for coverage reports.  
  ```
  dotnet test
  ```

- **Format Code**: Apply code formatting rules using the .editorconfig file (if present). Use `--include` to target specific files or `--exclude` to skip directories.  
  ```
  dotnet format
  ```

## PostgreSQL-Specific Commands (Entity Framework Core with Npgsql)

These commands focus on database operations using Entity Framework Core (EF Core) with the Npgsql provider for PostgreSQL. Ensure the `Microsoft.EntityFrameworkCore.Tools` and `Npgsql.EntityFrameworkCore.PostgreSQL` packages are installed via `dotnet add package`.

- **Install EF Core Tools**: Add the EF Core CLI tools for database scaffolding and migrations (global installation).  
  ```
  dotnet tool install --global dotnet-ef
  ```

- **Add Npgsql EF Core Package**: Install the Npgsql provider for PostgreSQL in the project.  
  ```
  dotnet add package Npgsql.EntityFrameworkCore.PostgreSQL --version 10.0.0
  ```

- **Create a New Migration**: Generate a migration script based on model changes for the PostgreSQL database. Replace `MyDbContext` with your DbContext class name and `InitialCreate` with a descriptive name.  
  ```
  dotnet ef migrations add InitialCreate --context MyDbContext
  ```

- **Update the Database**: Apply pending migrations to the PostgreSQL database. Specify the connection string via `--connection "Host=localhost;Database=claude_db;Username=postgres;Password=secret"` or use a `ConnectionStrings` setting in `appsettings.json`.  
  ```
  dotnet ef database update --context MyDbContext
  ```

- **Generate SQL Script for Migrations**: Output SQL commands for migrations without applying them (useful for review).  
  ```
  dotnet ef migrations script --context MyDbContext
  ```

- **Scaffold from Existing PostgreSQL Database**: Reverse-engineer an existing database into EF Core model classes. Provide the connection string and specify the schema if needed.  
  ```
  dotnet ef dbcontext scaffold "Host=localhost;Database=claude_db;Username=postgres;Password=secret" Npgsql.EntityFrameworkCore.PostgreSQL --output-dir Models --context ClaudeDbContext --force
  ```

### Note
Run `dotnet restore` after cloning the repository. Add new commands here as discovered.