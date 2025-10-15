# Terraform Commands

- `terraform init`: Initializes a new or existing Terraform configuration in the current directory. This command downloads and installs provider plugins required by the configuration and sets up the backend for storing state.
- `terraform plan`: Creates an execution plan, showing what changes Terraform would make to match the desired state defined in the configuration files.
- `terraform apply`: Applies the changes required to reach the desired state as defined in the configuration files. Prompts for confirmation before making changes.
- `tflint`: Runs TFLint to lint the Terraform configuration files for potential errors, best practices violations, and style issues. Install TFLint separately if not already available.
- `terraform fmt`: Rewrites all Terraform configuration files to a canonical format and style. Use `-check` flag to validate formatting without rewriting.
- `terraform validate`: Validates the Terraform configuration files to ensure syntactically complete and unable to be evaluated as a partial configuration.
- `terraform destroy`: Destroys all resources managed by the Terraform configuration. Prompts for confirmation before destroying.
- `terraform login`: Authenticates with the Terraform Cloud or Enterprise backend for remote state and operations (for cloud provider integration).
- `gcloud auth login`: Authenticates with Google Cloud Platform (GCP) for Terraform providers using GCP. Required for GCP-based projects.
- `aws configure`: Sets up AWS credentials and configuration for the AWS CLI, which Terraform uses for AWS provider authentication.
- `az login`: Authenticates with Azure for the Azure CLI, enabling Terraform to interact with Azure resources via the Azure provider.

## Notes
Run `terraform init` after cloning the repository. Add new commands here as discovered.