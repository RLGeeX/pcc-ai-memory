# Terraform Commands

- **Initialize the project**: `terraform init`  
  Initializes the Terraform working directory by downloading required providers and modules.

- **Plan the changes**: `terraform plan`  
  Creates an execution plan, showing what actions Terraform will take without applying them.

- **Apply the configuration**: `terraform apply`  
  Applies the changes required to reach the desired state as defined in the configuration files.

- **Lint the code**: `tflint`  
  Runs TFLint to detect and report potential errors in the Terraform code.

- **Format the code**: `terraform fmt`  
  Rewrites all Terraform configuration files to a canonical format and style.

- **Validate the configuration**: `terraform validate`  
  Validates the Terraform configuration files for syntax and internal consistency.

- **Destroy resources**: `terraform destroy`  
  Destroys all resources managed by the configuration.

- **Authenticate with cloud provider (AWS example)**: `aws configure`  
  Configures AWS credentials for Terraform to use the AWS provider. Replace with equivalent commands for other providers (e.g., `gcloud auth login` for Google Cloud, `az login` for Azure).

## Notes
Run `terraform init` after cloning the repository. Add new commands here as discovered.