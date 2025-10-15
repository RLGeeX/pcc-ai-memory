# CloudBuild Commands

This reference guide provides a comprehensive set of commands for working with the "pcc-pipeline-library" project, a pipeline library for Google Cloud Build. The library consists of YAML pipeline definitions and shell scripts designed for CI/CD workflows. Commands are organized by category and assume you have the Google Cloud SDK (`gcloud`) installed. Use these commands to manage authentication, validate pipelines, submit builds, and more.

## 1. Authentication and Project Setup

These commands handle initial setup, authentication, and project configuration for Google Cloud Build.

- **Authenticate with Google Cloud**:
  ```bash
  gcloud auth login
  ```
  Initiates OAuth2 authentication for your user account. Required for accessing Cloud Build resources.

- **Authenticate for service account (non-interactive)**:
  ```bash
  gcloud auth activate-service-account --key-file=PATH_TO_SERVICE_ACCOUNT_KEY.json
  ```
  Uses a service account key file for automated or CI environments. Replace `PATH_TO_SERVICE_ACCOUNT_KEY.json` with the actual path.

- **Set the default project**:
  ```bash
  gcloud config set project pcc-pipeline-library-project
  ```
  Configures the default Google Cloud project. Replace `pcc-pipeline-library-project` with your actual project ID.

- **Initialize Cloud Build API**:
  ```bash
  gcloud services enable cloudbuild.googleapis.com
  ```
  Enables the Cloud Build API in your project if not already active.

- **Clone the repository**:
  ```bash
  git clone https://github.com/PORTCoCONNECT/pcc-pipeline-library.git
  cd pcc-pipeline-library
  ```
  Clones the "pcc-pipeline-library" repository. Replace the URL with the actual repository location (e.g., GitHub, Cloud Source Repositories).

- **Configure Cloud Build triggers (initial setup)**:
  ```bash
  gcloud builds triggers create github --repo=PORTCoCONNECT/pcc-pipeline-library --branch-pattern=^main$ --build-config=cloudbuild.yaml
  ```
  Creates a Cloud Build trigger for GitHub repository events. Adjust `--repo`, `--branch-pattern`, and `--build-config` as needed for your YAML files.

## 2. Pipeline Validation and Testing

Validate YAML pipelines and test shell scripts before submission to ensure they are syntactically correct and functional.

- **Validate a Cloud Build YAML file**:
  ```bash
  gcloud builds submit --config=PATH_TO_YAML/cloudbuild.yaml --dry-run
  ```
  Performs a dry-run submission to validate the YAML syntax and substitutions without executing the build. Replace `PATH_TO_YAML/cloudbuild.yaml` with the path to your pipeline YAML.

- **Test a shell script locally**:
  ```bash
  bash -n scripts/your-script.sh
  ```
  Checks the syntax of a shell script without executing it. Replace `your-script.sh` with the script name from the library.

- **Run a shell script in a test environment**:
  ```bash
  docker run --rm -v $(pwd)/scripts:/scripts google/cloud-sdk:slim bash /scripts/your-script.sh
  ```
  Executes a shell script inside a Docker container mimicking Cloud Build's environment. Mounts the scripts directory for testing.

- **Validate all YAML files in the library**:
  ```bash
  find . -name "cloudbuild*.yaml" -exec gcloud builds submit --config={} --dry-run \; | grep -v "SUCCESS"
  ```
  Loops through all `cloudbuild*.yaml` files and runs dry-run validation. Errors are filtered and displayed.

## 3. Build Submission and Monitoring

Submit builds using the library's YAML files and monitor their progress.

- **Submit a build from a YAML file**:
  ```bash
  gcloud builds submit --config=PATH_TO_YAML/cloudbuild.yaml --substitutions=_PROJECT_ID=pcc-pipeline-library-project,_REPO_NAME=your-repo
  ```
  Submits a build using the specified YAML config. Use `--substitutions` to pass variables defined in the library's pipelines.

- **Submit a build from the current directory**:
  ```bash
  gcloud builds submit . --config=cloudbuild.yaml
  ```
  Submits a build from the repo root, using the default `cloudbuild.yaml`. Ideal for testing library pipelines in context.

- **List recent builds**:
  ```bash
  gcloud builds list --limit=10 --project=pcc-pipeline-library-project
  ```
  Displays the last 10 builds, including status, duration, and logs URL.

- **Monitor a specific build**:
  ```bash
  gcloud builds log BUILD_ID --project=pcc-pipeline-library-project
  ```
  Streams logs for a build by its ID (obtained from `gcloud builds list`). Replace `BUILD_ID` with the actual ID.

- **Cancel a running build**:
  ```bash
  gcloud builds cancel BUILD_ID --project=pcc-pipeline-library-project
  ```
  Stops an in-progress build if issues arise during testing.

## 4. YAML Linting and Shell Script Validation

Lint YAML files and validate shell scripts for best practices and errors.

- **Lint a YAML file with yamllint**:
  ```bash
  yamllint cloudbuild.yaml
  ```
  Install `yamllint` via `pip install yamllint` first. Checks for YAML syntax issues, indentation, and style in pipeline files.

- **Lint all YAML files in the project**:
  ```bash
  yamllint . --format parsable
  ```
  Lints all `.yaml` files recursively, outputting parseable results for CI integration.

- **Validate shell scripts with ShellCheck**:
  ```bash
  shellcheck scripts/*.sh
  ```
  Install `shellcheck` (e.g., via Homebrew: `brew install shellcheck`). Analyzes scripts for common bugs, portability issues, and style violations.

- **Batch validate all scripts**:
  ```bash
  find scripts/ -name "*.sh" -exec shellcheck {} \;
  ```
  Runs ShellCheck on all `.sh` files in the scripts directory.

## 5. Repository Management

Manage the Git repository for the "pcc-pipeline-library" project.

- **Create a new branch for pipeline updates**:
  ```bash
  git checkout -b feature/new-pipeline
  ```
  Starts a new feature branch for adding or modifying YAML files and scripts.

- **Commit and push changes**:
  ```bash
  git add . && git commit -m "Add new cloudbuild.yaml for deployment pipeline" && git push origin feature/new-pipeline
  ```
  Stages all changes (YAMLs and scripts), commits, and pushes to trigger Cloud Build if triggers are set up.

- **Tag a library release**:
  ```bash
  git tag v1.0.0 && git push origin v1.0.0
  ```
  Creates and pushes a version tag for stable library releases.

- **Sync with Cloud Source Repositories (if using GCP repo)**:
  ```bash
  gcloud source repos clone pcc-pipeline-library --project=pcc-pipeline-library-project
  ```
  Clones or mirrors the repo from Google Cloud Source Repositories for integrated builds.

## 6. Troubleshooting and Debugging

Commands for diagnosing issues in builds, YAMLs, and scripts.

- **Describe a build for details**:
  ```bash
  gcloud builds describe BUILD_ID --project=pcc-pipeline-library-project
  ```
  Shows detailed info on a build, including steps, substitutions, and failure reasons.

- **Enable debug logging in a build**:
  ```bash
  gcloud builds submit --config=cloudbuild.yaml --substitutions=_DEBUG=true
  ```
  Passes a debug flag to the YAML (assuming the library supports it) for verbose output in scripts.

- **Check Cloud Build quotas and limits**:
  ```bash
  gcloud alpha builds limits list --project=pcc-pipeline-library-project
  ```
  Displays concurrent build limits and usage to troubleshoot quota errors.

- **View build artifacts (if configured)**:
  ```bash
  gsutil ls gs://YOUR_BUCKET/artifacts/
  ```
  Lists output artifacts from successful builds, assuming the YAML uploads to a GCS bucket.

- **Debug YAML substitutions**:
  ```bash
  gcloud builds submit --config=cloudbuild.yaml --dry-run --substitutions=_VAR=debug-value
  ```
  Uses dry-run to inspect how substitutions expand in the pipeline without running it.

## Notes

Run initial gcloud setup and authentication after cloning the repository. Add new commands here as discovered.