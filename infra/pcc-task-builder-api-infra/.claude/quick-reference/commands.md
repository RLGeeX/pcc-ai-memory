# Terraform Commands

This section provides a list of essential CLI commands for managing the Terraform project in the `.claude` directory. These commands focus on initialization, planning, validation, formatting, linting, and cleanup tasks. Ensure you are in the `.claude` directory (or adjust paths accordingly) before running them. For cloud provider authentication, refer to the specific provider's documentation (e.g., AWS CLI for AWS, `gcloud auth` for Google Cloud).

- **Initialize the project**:  
  `terraform init`  
  *Initializes the Terraform working directory by downloading required providers and modules.*

- **Plan changes**:  
  `terraform plan`  
  *Creates an execution plan, showing what changes Terraform will make to reach the desired state without applying them.*

- **Apply changes**:  
  `terraform apply`  
  *Applies the changes required to reach the desired state in the configuration.*

- **Lint with tflint**:  
  `tflint`  
  *Runs TFLint to detect potential errors, best practices violations, and enforce custom rules in the Terraform code. Install TFLint via its official installer if not already present.*

- **Format code**:  
  `terraform fmt`  
  *Rewrites all Terraform configuration files to a canonical format and style.*

- **Validate configuration**:  
  `terraform validate`  
  *Validates the Terraform configuration files in the current directory to check for syntax errors and basic configuration issues.*

- **Destroy resources**:  
  `terraform destroy`  
  *Destroys all resources managed by the configuration, effectively tearing down the infrastructure.*

- **Authenticate with cloud provider (example for AWS)**:  
  `aws configure` (or use environment variables like `export AWS_ACCESS_KEY_ID=...`)  
  *Configures credentials for AWS. Replace with provider-specific commands, e.g., `az login` for Azure or `gcloud auth login` for Google Cloud.*

## Note
Run `terraform init` after cloning the repository. Add new commands here as discovered.