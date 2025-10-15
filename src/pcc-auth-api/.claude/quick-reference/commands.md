# .NET Commands

This section provides a comprehensive list of CLI commands for managing a .NET 10 project named '.claude'. These commands assume you have the .NET 10 SDK installed and are working in the project root directory (containing the `.claude.csproj` file). Use the `dotnet` CLI tool for all operations.

- **Install .NET 10 SDK**: Download and install the .NET 10 SDK from the official Microsoft website (https://dotnet.microsoft.com/download/dotnet/10.0). After installation, verify with `dotnet --version` to ensure it outputs a version starting with `10.`.
  
- **Restore Dependencies**:  
  `dotnet restore`  
  Restores NuGet packages and project dependencies defined in the `.claude.csproj` file. Run this after cloning the repository or modifying dependencies.

- **Build the Project**:  
  `dotnet build`  
  Compiles the project and its dependencies into output binaries. Use `dotnet build --configuration Release` for an optimized release build.

- **Test the Project**:  
  `dotnet test`  
  Runs unit and integration tests using the configured test framework (e.g., xUnit or NUnit). Add `--logger "console;verbosity=detailed"` for more verbose output.

- **Run the Application**:  
  `dotnet run`  
  Builds and starts the application. Use `dotnet run --project .claude.csproj` to specify the project explicitly if needed.

- **Format Code**:  
  `dotnet format`  
  Applies code formatting rules based on the EditorConfig file. Use `dotnet format --verify-no-changes` to check for formatting issues without applying changes.

## PostgreSQL-Specific Commands (Entity Framework Core with Npgsql)

These commands are tailored for database operations using Entity Framework Core (EF Core) with the Npgsql provider for PostgreSQL. Ensure the project includes the `Npgsql.EntityFrameworkCore.PostgreSQL` NuGet package (added via `dotnet add package Npgsql.EntityFrameworkCore.PostgreSQL` during setup). Replace `YourDbContext` with your actual DbContext class name (e.g., `ClaudeDbContext`), and update the connection string as needed.

- **Add EF Core Tools (if not already installed)**:  
  `dotnet tool install --global dotnet-ef`  
  Installs the EF Core CLI tools globally for database scaffolding and migrations.

- **Install Npgsql EF Core Package**:  
  `dotnet add package Npgsql.EntityFrameworkCore.PostgreSQL --version 8.0.0`  
  Adds the Npgsql provider for PostgreSQL support in EF Core (version compatible with .NET 10).

- **Create a New Migration**:  
  `dotnet ef migrations add InitialCreate --context YourDbContext`  
  Generates a new migration script based on changes to your DbContext model.

- **Update the Database**:  
  `dotnet ef database update --context YourDbContext`  
  Applies pending migrations to the PostgreSQL database.

- **Generate SQL Script for Migrations**:  
  `dotnet ef migrations script --context YourDbContext`  
  Outputs a SQL script for applying migrations, useful for manual database updates.

- **Remove the Last Migration**:  
  `dotnet ef migrations remove --context YourDbContext`  
  Reverts the most recent migration if it hasn't been applied to the database yet.

**Note**: Run `dotnet restore` after cloning the repository. Add new commands here as discovered. For PostgreSQL commands, ensure your `appsettings.json` or connection string uses a PostgreSQL-compatible format (e.g., `Host=localhost;Database=claude;Username=postgres;Password=yourpassword`).