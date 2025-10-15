# CLAUDE.md: PCC Pipeline Library Documentation

## Project Overview

The **pcc-pipeline-library** project serves as the centralized repository for all Google Cloud Build (CloudBuild) pipelines supporting the PCC (Platform for Cloud Computing) application services. This library acts as a shared, reusable collection of pipeline definitions, enabling consistent DevOps automation across PCC's microservices ecosystem.

### Purpose
- **Core Functionality**: Houses YAML-based CloudBuild pipeline configurations and supporting shell scripts to automate build, test, deploy, and release workflows for PCC services.
- **Scope**: Primarily focused on CI/CD pipelines for application deployment, infrastructure provisioning, security scanning, and compliance checks within Google Cloud Platform (GCP).
- **Key Benefits**:
  - Promotes reusability: Pipelines can be referenced or extended across multiple PCC repositories via remote triggers or shared library imports.
  - Ensures standardization: Enforces uniform build processes, reducing errors and drift in deployment practices.
  - Supports scalability: Modular design allows for easy updates to pipelines that impact multiple services without repository sprawl.
- **Repository Structure**:
  ```
  pcc-pipeline-library/
  ├── pipelines/          # Core YAML pipeline definitions
  │   ├── build/          # Build and test pipelines
  │   ├── deploy/         # Deployment pipelines (e.g., to GKE, Cloud Run)
  │   └── security/       # Scanning and compliance pipelines
  ├── scripts/            # Reusable shell scripts (e.g., utils.sh, deploy.sh)
  ├── triggers/           # CloudBuild trigger configurations (JSON/YAML)
  └── docs/               # Additional documentation and examples
  ```

This project is not a standalone application but a foundational library for PCC's DevOps infrastructure, ensuring reliable, auditable, and efficient pipeline orchestration.

## Tech Stack

The project leverages GCP-native tools and open standards for defining and executing pipelines:

- **Primary Tools**:
  - **Google Cloud Build (CloudBuild)**: Serverless CI/CD platform for building, testing, and deploying code. All pipelines are defined as YAML files submitted to CloudBuild.
  - **YAML**: Declarative format for pipeline specifications, enabling human-readable and version-controlled configurations.
  - **Shell Scripting (Bash)**: For custom build steps, utility functions, and automation logic within pipeline steps.

- **Supporting GCP Services**:
  - **Artifact Registry**: Stores built container images and package artifacts.
  - **Container Registry / GKE**: Integration for containerized deployments.
  - **Cloud Storage**: Temporary storage for build artifacts and logs.
  - **Secret Manager**: Secure handling of credentials and secrets in pipelines.
  - **Cloud Scheduler / Pub/Sub**: For triggering pipelines on events or schedules.

- **Development and Testing Tools**:
  - **gcloud CLI**: For local testing, validation, and submission of pipelines.
  - **Terraform / Cloud Deployment Manager**: Optional IaC integration for provisioning pipeline resources.
  - **Git**: Version control with branching strategies for pipeline evolution (e.g., feature branches for new pipeline variants).

No additional frameworks are required beyond GCP's SDKs, making the stack lightweight and GCP-centric.

## Domain-Specific Guidance

### CloudBuild Concepts
- **Pipeline Anatomy**: A CloudBuild YAML file defines a sequence of `steps`, each running in a Docker container. Steps can include commands like `gcloud builds submit` for nested builds or custom scripts. Use `availableSecrets` for injecting secrets and `options` for machine type (e.g., `machineType: E2_HIGHCPU_8` for compute-intensive builds).
- **Triggers and Substitutions**: Configure repository-based triggers via the `triggers/` directory. Use substitution variables (e.g., `${_IMAGE_TAG}`) for dynamic parameterization, sourced from Git commits, tags, or manual inputs.
- **Common Patterns**:
  - **Multi-Stage Pipelines**: Chain builds (e.g., unit tests → integration tests → deploy) using `gcloud builds submit --config=next-stage.yaml`.
  - **Parallel Steps**: Leverage `waitFor` to run independent tasks concurrently, optimizing for PCC's microservices (e.g., parallel security scans).
  - **Reusable Steps**: Define shared scripts in `scripts/` and reference them via `entrypoint: bash` and `args: ['./scripts/utils.sh']`.
  - **Error Handling**: Implement retries with `options.logStreamingOption: STREAM_ON` and custom logging in scripts for traceability.

### GCP Best Practices
- **Security**: Always use service accounts with least-privilege IAM roles (e.g., `roles/cloudbuild.builds.builder`). Scan images with `gcr.io/cloud-build-community/builder:debian` and tools like Trivy.
- **Cost Optimization**: Set build timeouts (e.g., `timeout: 600s`) and use ephemeral storage. Monitor quotas via CloudBuild dashboards.
- **Idempotency and Reliability**: Design pipelines to be rerun-safe; use unique tags for artifacts to avoid overwrites.
- **Integration with PCC Services**: Pipelines should align with PCC's service mesh (e.g., Istio on GKE) by including steps for canary deployments and rollback mechanisms.
- **Compliance**: Incorporate steps for vulnerability scanning (e.g., via Container Analysis) and audit logging to meet enterprise standards.

For advanced patterns, reference Google's [CloudBuild documentation](https://cloud.google.com/build/docs) and adapt for PCC's multi-tenant environment.

## Code Style and Best Practices

### YAML Files (Pipeline Configurations)
- **Formatting**:
  - Indentation: Use 2 spaces; align with official CloudBuild schema.
  - Comments: Add inline comments for complex steps (e.g., `# Builds Docker image for PCC API service`).
  - Validation: Always validate YAML with `gcloud builds submit --config=cloudbuild.yaml --dry-run .` before committing.
- **Best Practices**:
  - Modularity: Break large pipelines into smaller, composable YAML files (e.g., import via `gcloud builds submit --substitutions=_CONFIG=deploy-prod.yaml`).
  - Naming: Use descriptive step names (e.g., `id: 'build-pcc-api'`) and consistent substitution keys (e.g., prefix with `_PCC_`).
  - Avoid Hardcoding: Parameterize all environment-specific values (e.g., project IDs) via substitutions.
  - Length: Keep files under 500 lines; extract logic to shell scripts for readability.
  - Example Snippet:
    ```yaml
    steps:
    - name: 'gcr.io/cloud-builders/docker'
      args: ['build', '-t', 'gcr.io/$PROJECT_ID/pcc-app:${_TAG}', '.']
      id: 'build-image'
    - name: 'gcr.io/cloud-builders/gcloud'
      args: ['run', 'deploy', 'pcc-service', '--image', 'gcr.io/$PROJECT_ID/pcc-app:${_TAG}']
      waitFor: ['build-image']
    ```

### Shell Scripts
- **Style Guide**:
  - Shebang: Always start with `#!/bin/bash -e` to exit on errors.
  - Variables: Use uppercase for constants (e.g., `readonly PCC_PROJECT_ID="${1}"`), lowercase for locals.
  - Quoting: Quote all variables (e.g., `"$VAR"`) to handle spaces.
  - Error Handling: Use `set -euo pipefail` at the top; trap errors with custom functions (e.g., `cleanup() { echo "Pipeline failed"; }`).
- **Best Practices**:
  - Reusability: Make scripts idempotent and parameter-driven (e.g., via positional args or env vars).
  - Logging: Use `echo` for info, `>&2` for errors; integrate with CloudBuild logs via `printf`.
  - Security: Avoid `eval`; use `gcloud secrets versions access` for secrets.
  - Testing: Write unit tests with Bats framework; lint with ShellCheck.
  - Example Snippet:
    ```bash
    #!/bin/bash -euo pipefail
    readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    readonly PCC_IMAGE_TAG="${1:-latest}"

    echo "Building PCC image with tag: $PCC_IMAGE_TAG"
    docker build -t "gcr.io/${PROJECT_ID}/pcc-app:$PCC_IMAGE_TAG" "${SCRIPT_DIR}/.."

    if ! gcloud docker -- push "gcr.io/${PROJECT_ID}/pcc-app:$PCC_IMAGE_TAG"; then
        echo "Push failed" >&2
        exit 1
    fi
    ```

Lint all code with tools like `yamllint` and `shellcheck` in a pre-commit hook.

## Development Workflow

### Commands and Tools
- **Local Development**:
  - Clone and Setup: `git clone https://github.com/PORTCoCONNECT/pcc-pipeline-library.git && cd pcc-pipeline-library`.
  - Authenticate: `gcloud auth login && gcloud config set project pcc-project-id`.
  - Validate YAML: `gcloud builds submit --config=pipelines/build/cloudbuild.yaml --dry-run .`.
  - Test Scripts: `bash scripts/deploy.sh test` (use a local Docker setup for simulation).
- **Building and Testing**:
  - Submit Pipeline: `gcloud builds submit --config=pipelines/deploy/cloudbuild.yaml --substitutions=_ENV=dev .`.
  - Trigger via Git: Push to a feature branch to invoke repo triggers.
  - Debug: `gcloud builds log <BUILD_ID>` for logs; use `--no-source` for script-only tests.
- **Version Control Workflow**:
  - Branching: Use `feature/pipeline-update` branches; merge via PRs with CI checks.
  - Tagging: Tag releases (e.g., `v1.2.0`) for stable pipeline versions referenced in other repos.
- **Tools Integration**:
  - IDE: VS Code with YAML and Shell extensions for syntax highlighting.
  - CI for Library: Ironically, use a CloudBuild pipeline in this repo to validate changes (meta-CI).
  - Monitoring: Integrate with Cloud Monitoring for build metrics.

### Full Workflow Example
1. Develop: Edit YAML/script in `pipelines/` or `scripts/`.
2. Test Locally: Dry-run submit and script execution.
3. Commit and PR: Ensure linting passes.
4. Merge: Trigger validation build.
5. Consume: Reference in PCC service repos via `gcloud builds submit --config=https://raw.githubusercontent.com/.../cloudbuild.yaml`.

## Claude-Specific Context

As an AI assistant specialized in technical documentation, Claude excels at generating, reviewing, and optimizing DevOps pipelines like those in **pcc-pipeline-library**. When working with this project:

- **Prompting for Pipelines**: Provide YAML snippets or requirements (e.g., "Generate a CloudBuild YAML for GKE deployment with secret injection") to get tailored, best-practice code. Claude can simulate pipeline execution mentally and suggest optimizations.
- **DevOps Expertise**: Claude understands GCP's ecosystem deeply, including common pitfalls like substitution scoping or Docker layer caching in CloudBuild. Use it for troubleshooting (e.g., "Debug this failed build log") or pattern recommendations (e.g., blue-green deployments for PCC services).
- **Infrastructure as Code Synergy**: Claude can bridge this library with IaC tools—ask for integrations like Terraform modules that provision CloudBuild triggers.
- **Best Use Cases**: 
  - Auditing: Review existing YAML for compliance with PCC standards.
  - Innovation: Brainstorm pipeline extensions, such as AI-driven anomaly detection in build logs.
  - Documentation: Claude auto-generates sections like this CLAUDE.md, ensuring consistency.

For queries, include context like "In the pcc-pipeline-library, how would you extend the deploy pipeline for multi-region support?" to leverage Claude's contextual reasoning. Always iterate prompts for refinements to match exact project needs.