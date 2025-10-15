# .NET Commands

This section provides a comprehensive list of CLI commands for managing a .NET 10 project named '.claude'. These commands focus on development workflows, including SDK installation, dependency management, building, testing, running, code formatting, and PostgreSQL integration using Entity Framework Core with Npgsql. All commands assume you have a basic .NET project structure set up.

- **Install .NET 10 SDK**: Download and install the .NET 10 SDK from the official Microsoft website or use a package manager. On Windows, use the installer from [dotnet.microsoft.com](https://dotnet.microsoft.com/download/dotnet/10.0). On macOS/Linux, use:  
  ```
  brew install --cask dotnet-sdk@10  # Homebrew (macOS)
  # Or for Linux (Ubuntu/Debian):
  wget https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
  sudo dpkg -i packages-microsoft-prod.deb
  sudo apt-get update
  sudo apt-get install -y dotnet-sdk-10.0
  ```
  Verify installation: `dotnet --version` (should output 10.0.x).

- **Restore Dependencies**: Restore NuGet packages and project dependencies for the '.claude' project.  
  ```
  dotnet restore ./claude.sln  # Or dotnet restore for a single project file
  ```

- **Build the Project**: Compile the '.claude' project in Release or Debug mode.  
  ```
  dotnet build ./claude.sln --configuration Release  # Builds all projects in the solution
  # Or for a specific project:
  dotnet build ./src/Claude.csproj --configuration Debug
  ```

- **Run Tests**: Execute unit and integration tests using the built-in test runner.  
  ```
  dotnet test ./claude.sln --configuration Release --logger "console;verbosity=detailed"  # Runs tests across the solution
  # Or for a specific test project:
  dotnet test ./tests/Claude.Tests.csproj --filter "FullyQualifiedName~IntegrationTest"
  ```

- **Run the Application**: Start the '.claude' application in development mode.  
  ```
  dotnet run --project ./src/Claude.csproj --configuration Debug  # Runs the main project
  # With environment variables (e.g., for local development):
  dotnet run --project ./src/Claude.csproj --launch-profile local
  ```

- **Format Code**: Apply code formatting and style rules using the .NET formatter.  
  ```
  dotnet format ./claude.sln --verbosity diagnostic  # Formats all files in the solution
  # Or for specific files:
  dotnet format whitespace ./src/**/*.cs  # Fixes whitespace only
  ```

## PostgreSQL-Specific Commands (Entity Framework Core with Npgsql)

These commands assume the '.claude' project uses Entity Framework Core (EF Core) with the Npgsql provider for PostgreSQL database operations. Ensure the `Microsoft.EntityFrameworkCore.Tools` and `Npgsql.EntityFrameworkCore.PostgreSQL` NuGet packages are installed via `dotnet add package`.

- **Add EF Core Tools (if not already installed)**: Install the EF Core CLI tools globally for database scaffolding and migrations.  
  ```
  dotnet tool install --global dotnet-ef --version 10.0.0  # Matches .NET 10
  ```

- **Add Npgsql Provider Package**: Add the PostgreSQL provider to your project.  
  ```
  dotnet add ./src/Claude.csproj package Npgsql.EntityFrameworkCore.PostgreSQL --version 10.0.0
  dotnet add ./src/Claude.csproj package Microsoft.EntityFrameworkCore.Design --version 10.0.0
  ```

- **Create Initial Migration**: Generate a new EF Core migration for your DbContext (e.g., after defining models).  
  ```
  dotnet ef migrations add InitialCreate --project ./src/Claude.csproj --startup-project ./src/Claude.csproj --output-dir Migrations
  ```

- **Update Database**: Apply pending migrations to the PostgreSQL database.  
  ```
  dotnet ef database update --project ./src/Claude.csproj --startup-project ./src/Claude.csproj
  ```

- **Generate SQL Script**: Create a SQL script for migrations (useful for review before applying).  
  ```
  dotnet ef migrations script --project ./src/Claude.csproj --startup-project ./src/Claude.csproj --idempotent
  ```

- **Remove Last Migration**: Revert the last migration (use with caution, before updating the database).  
  ```
  dotnet ef migrations remove --project ./src/Claude.csproj
  ```

- **Scaffold Database (Reverse Engineering)**: Generate EF Core models from an existing PostgreSQL database.  
  ```
  dotnet ef dbcontext scaffold "Host=localhost;Database=claude_db;Username=postgres;Password=yourpassword" Npgsql.EntityFrameworkCore.PostgreSQL -o Models -c ClaudeDbContext --project ./src/Claude.csproj
  ```

**Note**: Run `dotnet restore` after cloning the repository. Add new commands here as discovered. Ensure your `appsettings.json` or connection strings reference PostgreSQL (e.g., `"ConnectionStrings": { "DefaultConnection": "Host=localhost;Database=claude_db;Username=postgres;Password=yourpassword" }`). For production, use secure connection strings and environment variables.