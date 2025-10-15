# Terraform Examples

Sample code and best practices for Terraform projects.

## Sample Module Structure
```hcl
# main.tf
module "network" {
  source  = "./modules/network"
  vpc_cidr = var.vpc_cidr
}

# variables.tf
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

# modules/network/main.tf
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
}
```
- **Best Practice**: Use modules to encapsulate reusable infrastructure components.

## Provider Configuration
```hcl
provider "aws" {
  region = "us-east-1"
}
```
- **Best Practice**: Explicitly define providers with pinned versions (e.g., `aws ~> 4.0`) in a `versions.tf` file.

## Reference
See `@docs/terraform-patterns.md` for detailed patterns.