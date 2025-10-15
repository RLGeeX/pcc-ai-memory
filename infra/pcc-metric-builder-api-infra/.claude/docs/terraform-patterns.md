# Terraform Patterns and Examples

Detailed patterns and examples for Terraform projects.

## Modular Infrastructure
Use modules to organize resources logically and promote reuse across environments.

```hcl
# main.tf
module "web_server" {
  source        = "./modules/web_server"
  instance_type = var.instance_type
  ami           = var.ami
}

# modules/web_server/main.tf
resource "aws_instance" "web" {
  ami           = var.ami
  instance_type = var.instance_type
}

# variables.tf
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}
variable "ami" {
  description = "AMI ID for the EC2 instance"
  type        = string
}
```
- **Pattern**: Encapsulate related resources in modules; use variables for configuration.
- **Benefit**: Simplifies maintenance and supports multi-region deployments.

## State Management
```hcl
# backend.tf
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "state/terraform.tfstate"
    region         = "us-east-1"
  }
}
```
- **Pattern**: Use remote backends (e.g., S3) for state storage to enable team collaboration.
- **Pitfall to Avoid**: Don’t store state files in the repository; use `.gitignore`.

## Best Practices
- Pin provider versions in `versions.tf` (e.g., `aws ~> 4.0`).
- Use `terraform fmt` for consistent formatting.
- Validate configurations with `terraform validate` and `tflint`.
- Document resources in `@.claude/docs/architecture.md`.