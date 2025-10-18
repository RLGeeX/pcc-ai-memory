# Terraform Commands

This section provides a list of essential CLI commands for managing the Terraform project in the `.claude` directory. These commands focus on initialization, validation, formatting, linting, planning, applying, and destroying infrastructure configurations. Ensure you are in the `.claude` directory when running these commands.

- **Initialize Terraform**: Sets up the working directory by downloading required providers and modules.  
  `terraform init`

- **Format Terraform Code**: Formats the Terraform configuration files to a canonical style and applies formatting conventions.  
  `terraform fmt`

- **Validate Terraform Configuration**: Checks whether the configuration is syntactically valid and internally consistent.  
  `terraform validate`

- **Lint with TFLint**: Runs TFLint to detect potential errors, enforce best practices, and identify violations in the Terraform code. (Install TFLint separately via `brew install tflint` or equivalent.)  
  `tflint`

- **Plan Changes**: Creates an execution plan, showing what actions Terraform will take without applying them.  
  `terraform plan`

- **Apply Configuration**: Applies the changes required to reach the desired state as defined in the configuration files.  
  `terraform apply`

- **Destroy Infrastructure**: Destroys all resources managed by the configuration. Use with caution.  
  `terraform destroy`

## Cloud Provider Authentication

Before running Terraform commands that interact with cloud providers (e.g., AWS, Azure, GCP), ensure proper authentication is set up. Common methods include:

- **AWS (using AWS CLI)**: Install and configure the AWS CLI, then run `aws configure` to set up credentials.  
  `aws configure`

- **Azure (using Azure CLI)**: Install and log in to Azure CLI.  
  `az login`

- **GCP (using gcloud CLI)**: Install and initialize the gcloud CLI, then authenticate.  
  `gcloud auth login`  
  `gcloud init`

Refer to the respective cloud provider's documentation for detailed authentication setup.

## Note
Run `terraform init` after cloning the repository. Add new commands here as discovered.