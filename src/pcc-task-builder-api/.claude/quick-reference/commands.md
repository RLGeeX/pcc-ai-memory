# .NET Commands

This section provides a comprehensive list of CLI commands for managing a .NET 10 project named '.claude'. These commands focus on development workflows, including SDK installation, dependency management, building, testing, running, code formatting, and PostgreSQL integration using Entity Framework Core with Npgsql. All commands assume you have the .NET CLI installed and are executed from the project root directory (e.g., `./claude/`).

- **Install .NET 10 SDK**: Download and install the .NET 10 SDK from the official Microsoft website.  
  Command:  
  ```
  # On Windows (using winget)
  winget install Microsoft.DotNet.SDK.10

  # On macOS (using Homebrew)
  brew install --cask dotnet-sdk@10

  # On Linux (Ubuntu/Debian)
  wget https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
  sudo dpkg -i packages-microsoft-prod.deb
  rm packages-microsoft-prod.deb
  sudo apt update
  sudo apt install -y dotnet-sdk-10.0
  ```

- **Restore Dependencies**: Restore NuGet packages and project dependencies for the '.claude' project.  
  Command:  
  ```
  dotnet restore
  ```

- **Build the Project**: Compile the '.claude' project in Release configuration (use `--configuration Debug` for debugging).  
  Command:  
  ```
  dotnet build --configuration Release
  ```

- **Run Tests**: Execute unit and integration tests using the built-in test runner.  
  Command:  
  ```
  dotnet test --configuration Release --logger "console;verbosity=detailed"
  ```

- **Run the Application**: Start the '.claude' application in development mode.  
  Command:  
  ```
  dotnet run --configuration Debug
  ```

- **Format Code**: Apply code formatting standards to the entire solution using the .NET formatter.  
  Command:  
  ```
  dotnet format
  ```

- **Add Npgsql Entity Framework Core Package**: Install the Npgsql provider for Entity Framework Core to support PostgreSQL in the '.claude' project.  
  Command:  
  ```
  dotnet add package Npgsql.EntityFrameworkCore.PostgreSQL --version 10.0.0
  ```

- **Add Entity Framework Core Tools**: Install EF Core tools for database operations with PostgreSQL.  
  Command:  
  ```
  dotnet tool install --global dotnet-ef
  ```

- **Create DbContext Scaffold from PostgreSQL Database**: Generate Entity Framework Core model classes from an existing PostgreSQL database (replace connection string and schema as needed).  
  Command:  
  ```
  dotnet ef dbcontext scaffold "Host=localhost;Database=claude_db;Username=postgres;Password=your_password" Npgsql.EntityFrameworkCore.PostgreSQL -o Models -c ClaudeDbContext -f
  ```

- **Add New Migration for PostgreSQL**: Create a new Entity Framework Core migration for changes to the PostgreSQL database model.  
  Command:  
  ```
  dotnet ef migrations add InitialCreate --startup-project ./claude.csproj
  ```

- **Update PostgreSQL Database**: Apply pending migrations to the PostgreSQL database.  
  Command:  
  ```
  dotnet ef database update --startup-project ./claude.csproj
  ```

- **Remove Last Migration**: Revert the most recent Entity Framework Core migration (use before applying to database).  
  Command:  
  ```
  dotnet ef migrations remove --startup-project ./claude.csproj
  ```

## Notes
Run `dotnet restore` after cloning the repository. Add new commands here as discovered. Ensure PostgreSQL is running locally or accessible via the connection string for EF Core commands. For Npgsql-specific configurations, refer to the [Npgsql documentation](https://www.npgsql.org/efcore/index.html).