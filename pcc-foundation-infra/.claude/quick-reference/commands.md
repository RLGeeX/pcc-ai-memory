# Terraform Commands

This section provides a list of essential CLI commands for managing the Terraform configuration in the `.claude` project. These commands focus on initialization, validation, formatting, linting, planning, applying, destroying, and cloud provider authentication. Ensure you have Terraform installed and configured for your environment.

- **Initialize the Terraform working directory**  
  `terraform init`  
  *Initializes the project, downloads required providers and modules, and sets up the backend. Run this after cloning the repository.*

- **Format Terraform configuration files**  
  `terraform fmt`  
  *Automatically formats `.tf` files to adhere to Terraform's style conventions. Use `-recursive` for subdirectories: `terraform fmt -recursive`.*

- **Validate Terraform configuration**  
  `terraform validate`  
  *Checks the syntax and internal consistency of the configuration files without performing a plan.*

- **Lint Terraform configuration with tflint**  
  `tflint`  
  *Runs TFLint to detect potential errors, best practices violations, and enforce coding standards. Install TFLint separately if not already available.*

- **Generate an execution plan**  
  `terraform plan`  
  *Creates a preview of changes that will be made to the infrastructure without applying them. Use `-out=plan.tfplan` to save the plan: `terraform plan -out=plan.tfplan`.*

- **Apply the Terraform configuration**  
  `terraform apply`  
  *Provisions or updates the infrastructure as defined in the configuration. Use with a saved plan: `terraform apply plan.tfplan`.*

- **Destroy all managed infrastructure**  
  `terraform destroy`  
  *Removes all resources managed by the configuration. Confirm with `-auto-approve` to skip interactive prompts: `terraform destroy -auto-approve`.*

- **Authenticate with cloud provider (AWS example)**  
  `aws configure`  
  *Sets up AWS credentials for Terraform to use the AWS provider. Replace with equivalent commands for other providers (e.g., `gcloud auth login` for GCP, `az login` for Azure).*

## Notes
Run `terraform init` after cloning the repository. Add new commands here as discovered.