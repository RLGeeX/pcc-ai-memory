# Setup Guide for the 'pcc-tf-library' Terraform Module Library Repository

This guide provides a comprehensive, step-by-step process for setting up the 'pcc-tf-library' Terraform module library repository. This repository serves as a centralized library of reusable Terraform modules for GCP infrastructure, designed to be referenced by other deployment repositories. The focus is on module development, local testing, validation, and publishing workflows to ensure high-quality, secure, and maintainable modules.

The guide assumes you have basic familiarity with Git, command-line tools, and Terraform concepts. All commands are intended for a Unix-like environment (e.g., macOS, Linux); adjust for Windows as needed.

## 1. Prerequisites

Before setting up the repository, install and configure the required tools. These ensure consistent Terraform versions, linting, security scanning, and testing.

### Install Terraform
Download and install Terraform from the official HashiCorp releases page. Use version 1.5.x or later for optimal compatibility with modern GCP providers.

- **macOS (using Homebrew):**
  ```
  brew tap hashicorp/tap
  brew install hashicorp/tap/terraform
  ```

- **Linux (manual download):**
  ```
  wget https://releases.hashicorp.com/terraform/1.5.7/terraform_1.5.7_linux_amd64.zip
  unzip terraform_1.5.7_linux_amd64.zip
  sudo mv terraform /usr/local/bin/
  ```

Verify installation:
```
terraform version
```

### Install Mise (Version Manager for Tools)
Mise manages tool versions (e.g., Terraform, Go for Terratest) via a `.mise.toml` or `.tool-versions` file in the repository. Install mise:

- **macOS (Homebrew):**
  ```
  brew install mise
  mise --version
  ```

- **Linux (from GitHub releases):**
  Download the binary from [mise releases](https://github.com/jdxcode/mise/releases) and add to your PATH.

After installation, run `mise install` in the repository root to set up versions defined in `.tool-versions`.

### Install TFLint
TFLint is a Terraform linter for style and best practices. Install via:

- **Precompiled binary:**
  ```
  curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install.sh | sh -s v0.48.0
  ```

- **Homebrew (macOS):**
  ```
  brew install tflint
  ```

Verify:
```
tflint --version
```

## 2. GCP Authentication and Project Setup

Set up authentication for GCP to test modules locally. This repository will use a dedicated GCP project for testing (e.g., `pcc-tf-library-test`).

### Create a GCP Service Account
1. Go to the [GCP Console](https://console.cloud.google.com/) and create a new project: `pcc-tf-library-test`.
2. Enable required APIs: Compute Engine, Cloud Storage, IAM, and any module-specific ones (e.g., Cloud SQL for database modules).
3. Create a service account:
   ```
   gcloud iam service-accounts create tf-library-tester \
     --description="Service account for testing PCC TF modules" \
     --display-name="TF Library Tester"
   ```
4. Grant roles (adjust based on modules; start minimal):
   ```
   gcloud projects add-iam-policy-binding pcc-tf-library-test \
     --member="serviceAccount:tf-library-tester@pcc-tf-library-test.iam.gserviceaccount.com" \
     --role="roles/editor"
   ```
5. Generate a key:
   ```
   gcloud iam service-accounts keys create ~/.config/gcloud/tf-library-key.json \
     --iam-account=tf-library-tester@pcc-tf-library-test.iam.gserviceaccount.com
   ```

### Authenticate Locally
Set the environment variable for Terraform:
```
export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.config/gcloud/tf-library-key.json"
export GOOGLE_CLOUD_PROJECT="pcc-tf-library-test"
```

Install the `gcloud` CLI if not already:
```
curl https://sdk.cloud.google.com | bash
exec -l $SHELL
gcloud init
```

For production publishing, use workload identity federation instead of keys for security.

## 3. Repository Cloning and Initial Setup

Clone the repository and prepare the environment.

1. Clone the repo:
   ```
   git clone https://github.com/your-org/pcc-tf-library.git
   cd pcc-tf-library
   ```

2. Install dependencies with Mise:
   ```
   mise install  # Installs Terraform, Go, etc., from .tool-versions
   mise use      # Activates versions for the session
   ```

3. Set up Git (if not already):
   ```
   git config user.name "Your Name"
   git config user.email "your.email@company.com"
   ```

The repository structure should include directories like `modules/` (for individual modules, e.g., `modules/vpc/`, `modules/gcs-bucket/`), `examples/` (for testing each module), and root files like `README.md`, `.gitignore`, and `.pre-commit-config.yaml`.

## 4. Terraform Initialization and Backend Configuration

Configure Terraform for module development. Use remote backends for state management, even in a library repo, to enable CI/CD workflows.

1. In the repository root, create or edit `versions.tf` to pin providers:
   ```hcl
   terraform {
     required_version = ">= 1.5"
     required_providers {
       google = {
         source  = "hashicorp/google"
         version = "~> 5.0"
       }
     }
   }
   ```

2. Set up a remote backend (e.g., GCP Cloud Storage). Create `backend.tf`:
   ```hcl
   terraform {
     backend "gcs" {
       bucket = "pcc-tf-library-state"
       prefix = "terraform/state"
       project = "pcc-tf-library-test"
     }
   }
   ```

3. Initialize Terraform (run from root or module directories as needed):
   ```
   terraform init
   ```
   This downloads providers and configures the backend. For module-specific init (e.g., in `modules/vpc/`):
   ```
   cd modules/vpc
   terraform init
   ```

For module development, avoid applying in the library repo; use `examples/` for testing.

## 5. Module Validation Tools Setup

Install and configure tools for documenting and securing modules.

### Install terraform-docs
Generates documentation from module inputs/outputs.

- **Installation:**
  ```
  curl -sSLo terraform-docs.tar.gz https://github.com/terraform-docs/terraform-docs/releases/download/v0.16.0/terraform-docs-v0.16.0-$(uname -s)-$(uname -m).tar.gz
  tar -xzf terraform-docs.tar.gz
  sudo mv terraform-docs /usr/local/bin/
  ```

- **Usage in repo:** Add a Makefile target or script to run in each module:
  ```
  terraform-docs markdown table --output-file API.md modules/vpc/
  ```
  Integrate into pre-commit (see Step 7).

### Install tfsec (Now Checkov)
tfsec is deprecated; use Checkov for security scanning.

- **Installation:**
  ```
  pip install checkov
  ```

- **Usage:** Scan modules:
  ```
  checkov -d modules/ --framework terraform
  ```
  Configure `.checkov.yaml` in root for custom rules, e.g., enforce GCP-specific security (no public buckets).

Run these in CI/CD for validation before publishing.

## 6. Local Testing Procedures with Terratest

Terratest enables Go-based integration tests for modules. Focus on testing module outputs against real GCP resources (use a test project to avoid costs).

### Install Go and Terratest
Mise handles Go; ensure `go` is in `.tool-versions` (e.g., `go 1.21.0`).

1. Initialize Go modules in `test/` directory:
   ```
   cd test
   go mod init pcc-tf-library
   go get github.com/gruntwork-io/terratest/modules/terraform
   go get github.com/stretchr/testify/assert
   ```

2. Create a sample test (e.g., `test/vpc_test.go` for VPC module):
   ```go
   package test

   import (
     "testing"
     "github.com/gruntwork-io/terratest/modules/terraform"
     terraform_options "github.com/gruntwork-io/terratest/modules/test-structure"
   )

   func TestVpcModule(t *testing.T) {
     t.Parallel()

     opts := &terraform.Options{
       TerraformDir: "../modules/vpc/example",
       EnvVars: map[string]string{
         "GOOGLE_CREDENTIALS": os.Getenv("GOOGLE_APPLICATION_CREDENTIALS"),
         "TF_VAR_project_id": "pcc-tf-library-test",
       },
     }

     defer terraform.Destroy(t, opts)
     terraform.InitAndApply(t, opts)

     // Validate outputs
     subnetCount := terraform.OutputList(t, opts, "subnets")
     assert.Equal(t, 3, len(subnetCount))  // Example assertion
   }
   ```

3. Run tests:
   ```
   cd test
   go test -v -timeout 10m
   ```
   Use `-parallel` for speed. Clean up resources post-test with `defer terraform.Destroy`.

For publishing workflow: Run Terratest in CI before tagging releases. Use `examples/` directories in each module for test fixtures.

## 7. Pre-commit Hooks Configuration for Terraform Linting

Enforce code quality with pre-commit hooks.

1. Install pre-commit:
   ```
   pip install pre-commit
   ```

2. Create `.pre-commit-config.yaml` in root:
   ```yaml
   repos:
     - repo: https://github.com/pre-commit/pre-commit-hooks
       rev: v4.4.0
       hooks:
         - id: trailing-whitespace
         - id: end-of-file-fixer
     - repo: https://github.com/terraform-linters/tflint
       rev: v0.48.0
       hooks:
         - id: tflint
           args: [--init]  # Install plugins
     - repo: https://github.com/terraform-docs/terraform-docs
       rev: v0.16.0
       hooks:
         - id: terraform_docs
           args: [--markdown-table-of-contents, --output-file, API.md]
     - repo: https://github.com/bridgecrewio/checkov
       rev: 3.1.0
       hooks:
         - id: checkov
           args: [-d, .]
   ```

3. Install hooks:
   ```
   pre-commit install
   ```

4. Run on existing code:
   ```
   pre-commit run --all-files
   ```

This runs TFLint, generates docs, and scans for security issues on every commit. For module devs: Commit in module subdirs triggers hooks.

## 8. Environment Configuration for Multiple GCP Projects

Support multiple GCP projects for testing (e.g., dev, staging) without hardcoding.

1. Use Terraform workspaces:
   ```
   terraform workspace new dev
   terraform workspace new staging
   ```

2. Configure variables with `terraform.tfvars` per environment:
   - `dev.tfvars`:
     ```hcl
     project_id = "pcc-tf-library-dev"
     region     = "us-central1"
     ```
   - Load with: `terraform apply -var-file="dev.tfvars"`

3. For module consumers: Document input variables in `variables.tf` (e.g., `project_id`, `region`). Use defaults for testing.

4. In CI/CD (e.g., GitHub Actions), set secrets for credentials per environment. Example workflow snippet:
   ```yaml
   - name: Authenticate to GCP
     uses: google-github-actions/auth@v1
     with:
       credentials_json: ${{ secrets.GCP_SA_KEY_DEV }}
   ```

For publishing: Modules are environment-agnostic; tests validate across projects.

## 9. Troubleshooting Common Terraform Issues

- **Provider Authentication Errors:** Verify `GOOGLE_APPLICATION_CREDENTIALS` points to a valid JSON key. Run `gcloud auth application-default login` for user auth during dev.
  
- **Init Fails (Backend Issues):** Ensure the GCS bucket exists: `gsutil mb -p pcc-tf-library-test gs://pcc-tf-library-state`. Check IAM permissions.

- **Version Conflicts:** Use `mise` to lock versions. If mismatch: `rm -rf .terraform` and re-init.

- **Terratest Resource Leaks:** Always use `defer terraform.Destroy(t, opts)`. If stuck, manually destroy: `terraform destroy -auto-approve`.

- **TFLint/tfsec Failures:** Update rules in `.tflint.hcl` or skip with `--skip`. For Checkov, add `--skip-check` for false positives.

- **State Lock Errors:** Use `terraform force-unlock` with the lock ID from error message (rare in local dev).

- **Module Publishing:** To publish to Terraform Registry, tag releases (e.g., `git tag v1.0.0; git push --tags`). Ensure `main.tf` has proper module structure. Validate with `terraform get` in a consumer repo.

For ongoing maintenance, monitor GCP costs in the test project and automate cleanups. Refer to module READMEs for usage examples. If issues persist, check Terraform logs with `TF_LOG=DEBUG terraform apply`.
