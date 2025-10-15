# Terraform Commands

- `terraform init`: Initializes the Terraform working directory by downloading required providers and modules. Run this after cloning the repository.
- `terraform plan`: Creates an execution plan, showing what changes Terraform will make to the infrastructure without applying them.
- `terraform apply`: Applies the changes described in the plan file or configuration to the target infrastructure.
- `tflint`: Runs TFLint to lint and check the Terraform configuration files for potential errors, best practices violations, and style issues.
- `terraform fmt`: Formats the Terraform configuration files to ensure consistent style and formatting.
- `terraform validate`: Validates the Terraform configuration files to check for syntax errors and basic configuration issues.
- `terraform destroy`: Destroys all the managed infrastructure defined in the configuration.
- `terraform login`: Authenticates with the cloud provider (e.g., for Terraform Cloud or specific providers like AWS CLI login).
- `aws configure`: Configures AWS credentials for authentication (for AWS provider; adjust for other providers like `gcloud auth login` for GCP or `az login` for Azure).

## Note
Run `terraform init` after cloning the repository. Add new commands here as discovered.