# Terraform Commands

This section provides a list of essential CLI commands for managing the Terraform project named '.claude'. These commands focus on initialization, planning, validation, formatting, linting, and cleanup tasks. They assume you have Terraform installed and configured for your environment.

- **Initialize the Terraform working directory**  
  `terraform init`  
  This command initializes the project by downloading required providers and modules. Run it after cloning the repository or when adding new providers.

- **Validate the Terraform configuration**  
  `terraform validate`  
  Checks the syntax and internal consistency of the configuration files without executing them.

- **Format the Terraform configuration files**  
  `terraform fmt`  
  Rewrites all Terraform configuration files to a canonical format and style. Use `-recursive` for subdirectories: `terraform fmt -recursive`.

- **Plan changes without applying them**  
  `terraform plan`  
  Creates an execution plan, showing what actions Terraform will take to achieve the desired state. Use `-out=plan.tfplan` to save the plan: `terraform plan -out=plan.tfplan`.

- **Apply the Terraform configuration** (non-deployment note: use for local testing only)  
  `terraform apply`  
  Executes the planned actions to create or modify infrastructure. For a saved plan: `terraform apply plan.tfplan`.

- **Lint the Terraform configuration with tflint**  
  `tflint`  
  Runs TFLint to detect potential errors, best practices violations, and enforce coding standards. Install TFLint first if needed. Use `--init` to initialize: `tflint --init`.

- **Destroy all managed infrastructure**  
  `terraform destroy`  
  Destroys all resources created by the configuration. Use `-auto-approve` to skip confirmation: `terraform destroy -auto-approve`. For a saved plan: `terraform destroy plan.tfplan`.

- **Authenticate with cloud provider (AWS example)**  
  `aws configure`  
  Sets up AWS credentials for Terraform to use. Replace with your provider's CLI (e.g., `gcloud auth login` for Google Cloud or `az login` for Azure).

- **Authenticate with cloud provider (Google Cloud example)**  
  `gcloud auth application-default login`  
  Authenticates for Google Cloud services.

- **Authenticate with cloud provider (Azure example)**  
  `az login`  
  Logs in to Azure for Terraform operations.

## Notes
Run `terraform init` after cloning the repository. Add new commands here as discovered.