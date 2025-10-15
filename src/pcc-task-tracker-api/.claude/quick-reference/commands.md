# .NET Commands

This section provides a comprehensive list of CLI commands for managing a .NET 10 project named '.claude'. These commands focus on installation, dependency management, building, testing, running, formatting, and PostgreSQL integration using Entity Framework Core with Npgsql. Ensure the .NET 10 SDK is installed before proceeding.

- **Install .NET 10 SDK**  
  Download and install the .NET 10 SDK from the official Microsoft website:  
  ```
  # On Windows (using winget)
  winget install Microsoft.DotNet.SDK.10

  # On macOS (using Homebrew)
  brew install --cask dotnet-sdk@10

  # On Linux (Ubuntu/Debian)
  wget https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
  sudo dpkg -i packages-microsoft-prod.deb
  sudo apt-get update
  sudo apt-get install -y dotnet-sdk-10.0
  ```  
  Verify installation:  
  ```
  dotnet --version
  ```
  Expected output: `10.0.xxx` (or similar).

- **Restore Dependencies**  
  Restore NuGet packages and project dependencies for the '.claude' project:  
  ```
  dotnet restore
  ```  
  Run this in the root directory of the cloned repository.

- **Build the Project**  
  Compile the '.claude' project in Release configuration:  
  ```
  dotnet build --configuration Release
  ```  
  For Debug configuration:  
  ```
  dotnet build --configuration Debug
  ```

- **Test the Project**  
  Run unit and integration tests using the built-in test runner:  
  ```
  dotnet test --configuration Release --logger "console;verbosity=detailed"
  ```  
  Include coverage reporting (if configured):  
  ```
  dotnet test --collect:"XPlat Code Coverage"
  ```

- **Run the Application**  
  Execute the '.claude' application:  
  ```
  dotnet run --project .claude.csproj --configuration Release
  ```  
  Launch with specific arguments (e.g., environment):  
  ```
  dotnet run --project .claude.csproj --configuration Release --environment Development
  ```

- **Format Code**  
  Apply code formatting using the .NET analyzers:  
  ```
  dotnet format
  ```  
  Check for formatting issues without applying changes:  
  ```
  dotnet format --verify-no-changes
  ```

- **Add Npgsql Package (for PostgreSQL)**  
  Install the Npgsql provider for Entity Framework Core in PostgreSQL scenarios:  
  ```
  dotnet add package Npgsql.EntityFrameworkCore.PostgreSQL --version 10.0.0
  ```

- **Add Entity Framework Core Tools**  
  Install EF Core tools for database operations with PostgreSQL:  
  ```
  dotnet tool install --global dotnet-ef
  ```  
  Verify installation:  
  ```
  dotnet ef --version
  ```

- **Create DbContext (PostgreSQL)**  
  Scaffold a DbContext for an existing PostgreSQL database:  
  ```
  dotnet ef dbcontext scaffold "Host=localhost;Database=claude_db;Username=postgres;Password=your_password" Npgsql.EntityFrameworkCore.PostgreSQL -o Models -c ClaudeDbContext
  ```

- **Create Migration (Entity Framework Core with Npgsql)**  
  Add a new migration for PostgreSQL schema changes:  
  ```
  dotnet ef migrations add InitialCreate --project .claude.csproj
  ```

- **Update Database (PostgreSQL)**  
  Apply pending migrations to the PostgreSQL database:  
  ```
  dotnet ef database update --project .claude.csproj
  ```

## Notes
Run `dotnet restore` after cloning the repository. Add new commands here as discovered. Ensure PostgreSQL is running locally or accessible via connection string for EF Core commands. Use `--verbosity detailed` flag on any command for more output if troubleshooting.