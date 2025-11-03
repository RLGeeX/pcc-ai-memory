# Terraform Environment Template

This directory contains starter template files for creating new terraform infrastructure deployments following the **Environment Folder Pattern** (ADR-008).

## Quick Start

1. Copy the entire `nonprod/` directory to your infrastructure repo
2. Rename to match your environments (e.g., `devtest/`, `dev/`, `staging/`, `prod/`)
3. Update placeholder values in each file (search for `<PLACEHOLDERS>`)
4. Initialize and deploy

```bash
# Example: Create devtest environment
cp -r terraform-environment-template/nonprod /path/to/your-infra-repo/environments/devtest
cd /path/to/your-infra-repo/environments/devtest

# Update placeholders
# Edit backend.tf, terraform.tfvars, etc.

# Deploy
terraform init
terraform plan
terraform apply
```

## Template Files

### `backend.tf.template`
- GCS backend configuration with unique state prefix
- **REQUIRED**: Update `prefix` to `<service-name>/<environment>`

### `providers.tf.template`
- Terraform and provider version constraints
- Google Cloud provider configuration
- **UPDATE**: Provider versions as needed

### `variables.tf.template`
- Standard variable declarations
- **CUSTOMIZE**: Add service-specific variables

### `terraform.tfvars.template`
- Environment-specific values
- **REQUIRED**: Update all values for target environment

### `main.tf.template`
- Example module reference
- **CUSTOMIZE**: Replace with your service resources

### `outputs.tf.template`
- Standard output declarations
- **CUSTOMIZE**: Add service-specific outputs

## Environment Naming

**Four-Environment Pattern** (most infrastructure):
- `devtest/` - Infrastructure testing
- `dev/` - Development
- `staging/` - Pre-production
- `prod/` - Production

**Two-Environment Pattern** (DevOps/shared services):
- `nonprod/` - All non-production
- `prod/` - Production only

## State Prefix Naming Convention

```
<service-name>/<environment>
```

**Examples**:
- `app-shared-infra/devtest`
- `app-shared-infra/prod`
- `devops-infra/nonprod`
- `user-api-infra/dev`

## Module References

Always reference modules from `pcc-tf-library` with Git source and version pinning:

```hcl
module "example" {
  source = "git::https://github.com/portco-connect/pcc-tf-library.git//modules/module-name?ref=main"

  # Module inputs
}
```

**Version Pinning Options**:
- `?ref=main` - Latest (for active development)
- `?ref=v1.2.3` - Specific version tag (for production)
- `?ref=feature-branch` - Feature branch (for testing)

## CI/CD Integration

Your deployment pipeline should:

```bash
# Set environment variable
export ENVIRONMENT=devtest  # or dev, staging, prod, nonprod

# Change to environment directory
cd environments/${ENVIRONMENT}

# Deploy
terraform init -backend-config="bucket=${STATE_BUCKET}"
terraform plan -out=tfplan
terraform apply tfplan
```

## Checklist for New Infrastructure Repo

- [ ] Copy template files to `environments/<env>/`
- [ ] Update `backend.tf` with unique state prefix
- [ ] Update `terraform.tfvars` with environment-specific values
- [ ] Customize `variables.tf` with service-specific variables
- [ ] Replace `main.tf` with actual resource configurations
- [ ] Update `outputs.tf` with relevant outputs
- [ ] Test with `terraform validate`
- [ ] Run `terraform plan` to verify
- [ ] Document deployment steps in repo README.md
- [ ] Reference ADR-008 in repo CLAUDE.md

## References

- **ADR-008**: Terraform Environment Folder Pattern
- **Pattern Documentation**: `@.claude/docs/terraform-patterns.md`
- **Module Library**: `core/pcc-tf-library/modules/`

## Support

For questions or issues:
1. Review ADR-008 for pattern rationale
2. Check `terraform-patterns.md` for examples
3. Reference Phase 2 (AlloyDB) or Phase 3 (GKE) implementations
