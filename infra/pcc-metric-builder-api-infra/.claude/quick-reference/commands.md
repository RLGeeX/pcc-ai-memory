# Terraform Commands

This section provides a list of essential CLI commands for managing the Terraform project in the `.claude` directory. These commands focus on initialization, planning, validation, formatting, linting, and cleanup tasks.

- **Initialize the project**:  
  `cd .claude && terraform init`  
  Initializes the Terraform working directory by downloading required providers and modules.

- **Plan changes**:  
  `cd .claude && terraform plan`  
  Creates an execution plan, showing what actions Terraform will take without applying them.

- **Apply configuration**:  
  `cd .claude && terraform apply`  
  Applies the planned changes to create or update resources (use with caution; review the plan first).

- **Validate configuration**:  
  `cd .claude && terraform validate`  
  Validates the Terraform configuration files for syntax errors and basic consistency.

- **Format code**:  
  `cd .claude && terraform fmt`  
  Rewrites all Terraform configuration files to a canonical format and style.

- **Lint with tflint**:  
  `cd .claude && tflint`  
  Runs TFLint to detect potential errors, best practices violations, and enforce custom rules in the configuration.

- **Destroy resources**:  
  `cd .claude && terraform destroy`  
  Destroys all managed infrastructure defined in the configuration.

- **Authenticate with cloud provider (AWS example)**:  
  `aws configure` (or equivalent for your provider, e.g., `gcloud auth login` for GCP)  
  Sets up credentials for the cloud provider; run this before planning or applying to ensure authentication.

## Notes
Run `terraform init` after cloning the repository. Add new commands here as discovered.