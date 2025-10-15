# .NET Commands

This section provides a comprehensive list of CLI commands for managing a .NET 10 project named '.claude'. These commands focus on development workflows, including SDK installation, dependency management, building, testing, running, code formatting, and PostgreSQL integration using Entity Framework Core with Npgsql.

- **Install .NET 10 SDK**: Download and install the .NET 10 SDK from the official Microsoft website.  
  Command:  
  ```
  # On Windows (using winget)
  winget install Microsoft.DotNet.SDK.10

  # On macOS (using Homebrew)
  brew install --cask dotnet-sdk10

  # On Linux (Ubuntu/Debian)
  wget https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
  sudo dpkg -i packages-microsoft-prod.deb
  sudo apt-get update
  sudo apt-get install -y dotnet-sdk-10.0
  ```  
  Verify installation: `dotnet --version` (should output 10.0.x).

- **Restore Dependencies**: Restore NuGet packages and project dependencies for the '.claude' project.  
  Command:  
  ```
  dotnet restore
  ```  
  Run this after cloning the repository or modifying project files.

- **Build the Project**: Compile the '.claude' project and its dependencies in Release or Debug configuration.  
  Command:  
  ```
  dotnet build
  # Or with specific configuration
  dotnet build --configuration Release
  ```  
  Use `--no-restore` flag to skip restoration if already done.

- **Test the Project**: Run unit and integration tests using the testing framework (e.g., xUnit or NUnit).  
  Command:  
  ```
  dotnet test
  # Or with specific configuration and verbosity
  dotnet test --configuration Release --logger "console;verbosity=detailed"
  ```  
  Ensure tests are discoverable in the test projects within the solution.

- **Run the Application**: Execute the '.claude' application from the project directory.  
  Command:  
  ```
  dotnet run
  # Or with specific configuration and environment
  dotnet run --configuration Release --environment Development
  ```  
  Specify `--project .claude` if running from a solution root.

- **Format Code**: Apply code formatting standards using the .NET SDK's built-in formatter.  
  Command:  
  ```
  dotnet format
  # Or check without applying changes
  dotnet format --verify-no-changes
  # For specific files or directories
  dotnet format --include .claude/**/*.cs
  ```  
  Configure via `Directory.Build.props` or `.editorconfig` for custom rules.

### PostgreSQL-Specific Commands (Entity Framework Core with Npgsql)

These commands assume the '.claude' project uses Entity Framework Core (EF Core) with the Npgsql provider for PostgreSQL database operations. Ensure the `Npgsql.EntityFrameworkCore.PostgreSQL` package is added via `dotnet add package Npgsql.EntityFrameworkCore.PostgreSQL --version 10.0.0` (adjust version as needed for .NET 10 compatibility). A `DbContext` class (e.g., `ClaudeDbContext`) should be defined in the project.

- **Add EF Core Tools (if not installed)**: Install the EF Core CLI tools globally for database management.  
  Command:  
  ```
  dotnet tool install --global dotnet-ef
  # Or update existing
  dotnet tool update --global dotnet-ef
  ```

- **Create a New Migration**: Generate a migration script for model changes in the '.claude' DbContext.  
  Command:  
  ```
  dotnet ef migrations add InitialCreate --project .claude
  # Or for a specific migration name
  dotnet ef migrations add AddUserTable --project .claude
  ```  
  Specify `--context ClaudeDbContext` if multiple contexts exist. Use `--startup-project` if the DbContext is in a separate project.

- **Update the Database**: Apply pending migrations to the PostgreSQL database.  
  Command:  
  ```
  dotnet ef database update --project .claude
  # Or update to a specific migration
  dotnet ef database update AddUserTable --project .claude
  ```  
  Requires a valid connection string in `appsettings.json` (e.g., `"ConnectionStrings": { "DefaultConnection": "Host=localhost;Database=claude;Username=postgres;Password=secret" }`).

- **Remove the Latest Migration**: Revert the last migration (use before committing).  
  Command:  
  ```
  dotnet ef migrations remove --project .claude
  ```

- **Generate SQL Script**: Output SQL commands for migrations without applying them (useful for review).  
  Command:  
  ```
  dotnet ef migrations script --project .claude
  # From a specific migration
  dotnet ef migrations script InitialCreate AddUserTable --project .claude
  ```

**Note**: Run `dotnet restore` after cloning the repository. Add new commands here as discovered. Ensure PostgreSQL is installed and running locally (e.g., via Docker: `docker run --name claude-db -e POSTGRES_PASSWORD=secret -p 5432:5432 -d postgres`).