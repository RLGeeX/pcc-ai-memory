# Terraform Commands

This section provides a comprehensive list of CLI commands for managing the Terraform project in the `.claude` directory. These commands focus on initialization, planning, validation, formatting, linting, and resource management. Always navigate to the `.claude` directory before running these commands (e.g., `cd .claude`).

- **Initialize the Terraform project**:  
  `terraform init`  
  *Initializes the working directory, downloads required providers, and sets up the backend.*

- **Plan changes without applying**:  
  `terraform plan`  
  *Creates an execution plan showing what changes Terraform will make to the infrastructure.*

- **Apply the planned changes**:  
  `terraform apply`  
  *Applies the changes to the infrastructure based on the configuration files. Prompts for confirmation unless using `-auto-approve`.*

- **Lint the Terraform configuration**:  
  `tflint`  
  *Runs TFLint to detect and report potential errors, best practices violations, and suspicious constructs in the Terraform code.*

- **Format the Terraform configuration**:  
  `terraform fmt`  
  *Rewrites all Terraform configuration files to a canonical format and style. Use `-check` to validate formatting without changes.*

- **Validate the Terraform configuration**:  
  `terraform validate`  
  *Validates the configuration files in the directory for syntax errors and basic structural issues.*

- **Destroy all managed resources**:  
  `terraform destroy`  
  *Destroys all resources managed by the current configuration. Prompts for confirmation unless using `-auto-approve`.*

- **Authenticate with cloud provider (AWS example)**:  
  `aws configure`  
  *Configures AWS credentials for Terraform to use when interacting with AWS services. Replace 'aws' with the appropriate CLI for other providers (e.g., `az login` for Azure, `gcloud auth login` for GCP).*

## Notes
Run `terraform init` after cloning the repository. Add new commands here as discovered.