# Terraform Commands

This section provides a comprehensive list of CLI commands for managing the Terraform project in the `.claude` directory. These commands focus on initialization, planning, validation, formatting, linting, and cleanup operations. Ensure you are in the `.claude` directory when running these commands.

- **Initialize Terraform**:  
  Sets up the working directory by downloading required providers and modules.  
  ```
  terraform init
  ```

- **Plan Changes**:  
  Creates an execution plan to preview changes that will be made to the infrastructure without applying them.  
  ```
  terraform plan
  ```

- **Apply Configuration**:  
  Applies the changes described in the plan to create or update the infrastructure. (Use with caution in production.)  
  ```
  terraform apply
  ```

- **Lint with TFLint**:  
  Runs TFLint to check for potential errors, best practices violations, and enforce coding standards in Terraform files.  
  ```
  tflint
  ```

- **Format Code**:  
  Automatically formats Terraform configuration files to match the canonical style.  
  ```
  terraform fmt
  ```

- **Validate Configuration**:  
  Validates the Terraform configuration files for syntax errors and basic consistency.  
  ```
  terraform validate
  ```

- **Destroy Infrastructure**:  
  Destroys all managed infrastructure defined in the configuration.  
  ```
  terraform destroy
  ```

- **Authenticate with AWS Provider** (example for AWS; adjust for other providers):  
  Configures AWS credentials for Terraform to interact with AWS services. Requires AWS CLI installed.  
  ```
  aws configure
  ```

- **Authenticate with Azure Provider** (example for Azure):  
  Logs in to Azure using Azure CLI for Terraform authentication. Requires Azure CLI installed.  
  ```
  az login
  ```

- **Authenticate with Google Cloud Provider** (example for GCP):  
  Authenticates with Google Cloud using gcloud CLI for Terraform. Requires gcloud CLI installed.  
  ```
  gcloud auth application-default login
  ```

## Notes
Run `terraform init` after cloning the repository. Add new commands here as discovered.