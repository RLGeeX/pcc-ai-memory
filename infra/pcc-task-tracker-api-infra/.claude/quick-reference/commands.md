# Terraform Commands

This section provides a list of essential CLI commands for managing the Terraform project in the `.claude` directory. These commands focus on initialization, planning, validation, formatting, linting, and cleanup operations. Ensure you are in the `.claude` directory (or adjust paths accordingly) when running these commands.

- **Initialize the Terraform configuration**  
  `terraform init`  
  Initializes the working directory by downloading required providers and modules.

- **Plan changes without applying**  
  `terraform plan`  
  Creates an execution plan to preview what Terraform will do without making actual changes.

- **Apply configuration changes**  
  `terraform apply`  
  Applies the planned changes to create or modify infrastructure. Use `-auto-approve` to skip confirmation.

- **Validate configuration syntax**  
  `terraform validate`  
  Checks whether the configuration is syntactically valid and internally consistent.

- **Format configuration files**  
  `terraform fmt`  
  Rewrites all Terraform configuration files to a canonical format. Use `-write=false` to check formatting without changes.

- **Lint configuration with tflint**  
  `tflint`  
  Runs TFLint to detect potential errors, best practices violations, and enforce custom rules in Terraform code. Install TFLint separately if needed.

- **Destroy all managed resources**  
  `terraform destroy`  
  Destroys all infrastructure managed by the current configuration. Use `-auto-approve` to skip confirmation.

- **Authenticate with cloud provider (AWS example)**  
  `aws configure`  
  Sets up AWS credentials for Terraform to use AWS provider. Replace with equivalent for other providers (e.g., `gcloud auth login` for GCP, `az login` for Azure).

## Notes
Run `terraform init` after cloning the repository. Add new commands here as discovered.