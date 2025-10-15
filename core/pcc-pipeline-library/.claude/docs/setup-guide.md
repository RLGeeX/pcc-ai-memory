# Setup Guide for PCC Pipeline Library Project

This guide provides a comprehensive, step-by-step process for setting up and working with the "pcc-pipeline-library" project. This project serves as a shared library of YAML files for Google Cloud Build pipelines and supporting shell scripts, designed to standardize and reuse CI/CD workflows across teams. It focuses on Google Cloud Build (GCB) tools and best practices for development, testing, and deployment.

The guide assumes you have basic familiarity with Git, command-line interfaces, and Google Cloud Platform (GCP). Follow the sections in order for a smooth setup.

## 1. Prerequisites

Before setting up the project, ensure your environment meets these requirements. These steps prepare your local machine for interacting with GCP and Cloud Build.

### 1.1 Install the gcloud CLI
The Google Cloud CLI (gcloud) is essential for managing GCP resources, including Cloud Build triggers and submissions.

1. Download and install the gcloud CLI from the [official Google Cloud SDK page](https://cloud.google.com/sdk/docs/install). Choose the installer for your operating system (Linux, macOS, or Windows).
   
2. After installation, open a terminal and initialize the SDK:
   ```bash
   gcloud init
   ```
   This will prompt you to log in, select a project, and configure your default region.

3. Verify the installation:
   ```bash
   gcloud version
   ```
   Ensure the version is 400.0.0 or later for full Cloud Build support.

### 1.2 Authentication and Permissions
Proper authentication is required to submit builds, manage triggers, and access repositories.

1. Authenticate with your GCP account:
   ```bash
   gcloud auth login
   ```
   This opens a browser for OAuth consent. Use an account with at least Editor role on your project.

2. Set up Application Default Credentials (ADC) for local development:
   ```bash
   gcloud auth application-default login
   ```

3. Enable required APIs in your GCP project:
   - Go to the [Google Cloud Console APIs & Services page](https://console.cloud.google.com/apis).
   - Search for and enable:
     - Cloud Build API
     - Cloud Source Repositories API (if using GCP-hosted repos)
     - Artifact Registry API (for storing build artifacts, if needed)

4. Assign IAM roles:
   - In the Cloud Console, navigate to IAM & Admin > IAM.
   - Grant your user the following roles on the target project:
     - `roles/cloudbuild.builds.builder` (for submitting builds)
     - `roles/source.admin` (for repository management)
     - `roles/iam.serviceAccountUser` (for assuming service accounts)

### 1.4 Project Setup
1. Create or select a GCP project:
   ```bash
   gcloud projects create pcc-pipeline-library-project --name="PCC Pipeline Library"  # If creating new
   gcloud config set project pcc-pipeline-library-project
   ```

2. Enable billing if not already done (required for Cloud Build).

3. (Optional) Set up a Cloud Build service account with custom permissions:
   ```bash
   gcloud iam service-accounts create cloudbuild-sa --display-name="Cloud Build SA"
   gcloud projects add-iam-policy-binding pcc-pipeline-library-project \
     --member="serviceAccount:cloudbuild-sa@pcc-pipeline-library-project.iam.gserviceaccount.com" \
     --role="roles/cloudbuild.builds.builder"
   ```

## 2. Repository Setup and Cloning

The project uses Git for version control. We'll assume it's hosted on Google Cloud Source Repositories or GitHub (adapt for other providers).

### 2.1 Create the Repository (If New)
1. In the Cloud Console, go to Source Repositories > Create Repository.
2. Name it `pcc-pipeline-library` and initialize with a README if desired.

   Alternatively, for GitHub:
   - Create a new repository on GitHub named `pcc-pipeline-library`.
   - Enable Cloud Build integration via the [Cloud Build GitHub App](https://github.com/marketplace/google-cloud-build).

### 2.2 Clone the Repository
1. Install Git if not already (e.g., `brew install git` on macOS or `apt install git` on Ubuntu).

2. Clone the repo:
   ```bash
   gcloud source repos clone pcc-pipeline-library --project=pcc-pipeline-library-project  # For GCP Source Repos
   # Or for GitHub:
   git clone https://github.com/PORTCoCONNECT/pcc-pipeline-library.git
   ```

3. Navigate to the project directory:
   ```bash
   cd pcc-pipeline-library
   ```

4. (Initial setup) Add a basic structure:
   - Create directories: `mkdir -p pipelines scripts`
   - Add a sample YAML file, e.g., `pipelines/basic-build.yaml`:
     ```yaml
     steps:
     - name: 'gcr.io/cloud-builders/docker'
       args: ['build', '-t', 'gcr.io/$PROJECT_ID/hello', '.']
     images: ['gcr.io/$PROJECT_ID/hello']
     ```
   - Add a sample shell script, e.g., `scripts/deploy.sh`:
     ```bash
     #!/bin/bash
     echo "Deploying pipeline library..."
     gcloud builds submit --config=pipelines/basic-build.yaml .
     ```
   - Commit and push:
     ```bash
     git add .
     git commit -m "Initial project structure"
     git push origin main
     ```

## 3. Environment Configuration

Configure local and cloud environments for consistent development.

### 3.1 Local Environment Variables
1. Create a `.env` file in the project root (add to `.gitignore`):
   ```bash
   PROJECT_ID=pcc-pipeline-library-project
   REGION=us-central1
   BUCKET=gs://pcc-pipeline-artifacts
   ```

2. Source the environment in your shell (e.g., add to `~/.bashrc` or run manually):
   ```bash
   source .env
   export GOOGLE_CLOUD_PROJECT=$PROJECT_ID
   ```

### 3.2 Cloud Build Configuration
1. Create a `cloudbuild.yaml` in the root for the library itself (meta-build):
   ```yaml
   steps:
   - name: 'gcr.io/cloud-builders/gcloud'
     args: ['builds', 'submit', '--config=pipelines/$_PIPELINE.yaml', '.']
   substitutions:
     _PIPELINE: 'basic-build'
   ```

2. Set up Artifact Registry (optional, for storing Docker images or scripts):
   ```bash
   gcloud artifacts repositories create pipeline-artifacts --repository-format=docker --location=$REGION
   ```

3. Configure Cloud Build triggers (for CI on push):
   - In Cloud Console > Cloud Build > Triggers > Create Trigger.
   - Repository: Select your cloned repo.
   - Trigger type: Push to branch (e.g., main).
   - Build configuration: Cloud Build configuration file (e.g., `cloudbuild.yaml`).

## 4. Local Testing and Validation

Test pipelines locally before pushing to avoid cloud costs and errors.

### 4.1 Install Local Testing Tools
1. Install the Cloud Build emulator (part of gcloud, but enable components):
   ```bash
   gcloud components install cloud-build-local beta
   ```

2. (Optional) Install Docker for local image building:
   - Download from [Docker Hub](https://www.docker.com/products/docker-desktop).

### 4.2 Validate YAML Files
1. Use `gcloud` to lint YAML:
   ```bash
   gcloud builds submit --config=pipelines/basic-build.yaml --dry-run .  # Dry-run validation
   ```

2. Run local builds:
   ```bash
   cloud-build-local --config=pipelines/basic-build.yaml --project=$PROJECT_ID --dryrun=false .
   ```
   This simulates a Cloud Build without submitting to GCP.

3. Test shell scripts:
   ```bash
   chmod +x scripts/deploy.sh
   ./scripts/deploy.sh
   ```
   Check for syntax errors with `shellcheck scripts/*.sh` (install via `brew install shellcheck` or equivalent).

4. Validate overall project:
   - Run a full local build of the library:
     ```bash
     cloud-build-local --config=cloudbuild.yaml --project=$PROJECT_ID .
     ```
   - Review logs for issues like missing substitutions or invalid steps.

## 5. Pipeline Development Workflow

Follow this iterative workflow for developing and deploying pipelines.

### 5.1 Development Cycle
1. **Branch and Edit**:
   - Create a feature branch: `git checkout -b feature/new-pipeline`.
   - Edit YAML files in `pipelines/` (e.g., add steps for testing, deployment).
   - Update shell scripts in `scripts/` to reference new pipelines.

2. **Local Iteration**:
   - Validate changes: Run steps 4.1–4.4 above.
   - Use substitutions for testing: Edit `cloudbuild.yaml` to include `_TARGET=dev`.

3. **Commit and Push**:
   ```bash
   git add .
   git commit -m "Add new deployment pipeline"
   git push origin feature/new-pipeline
   ```

4. **Cloud Submission and Review**:
   - Submit manually: `gcloud builds submit --config=cloudbuild.yaml .`
   - Monitor in Cloud Console > Cloud Build > History.
   - If using triggers, push to main merges automatically.

5. **Integration and Reuse**:
   - Reference library pipelines in other projects via `--config` or shared repos.
   - Tag releases: `git tag v1.0.0 && git push --tags`.

## 6. Troubleshooting Common Issues

### 6.1 Authentication Issues
- **Problem**: "Permission denied" or "Unauthorized" errors.
- **Solution**: Re-run `gcloud auth login` and verify IAM roles. Check that the correct project is active with `gcloud config get-value project`.

### 6.2 Build Failures
- **Problem**: YAML syntax errors or missing steps.
- **Solution**: Use `--dry-run` flag first. Validate YAML with online tools or IDEs with YAML plugins.

### 6.3 Substitution Issues
- **Problem**: Variables like `$PROJECT_ID` not resolving.
- **Solution**: Ensure variables are defined in the `substitutions` section or as environment variables.

### 6.4 Quota and Billing
- **Problem**: "Quota exceeded" or billing disabled errors.
- **Solution**: Check GCP quotas in the console and ensure billing is enabled for your project.

Run `gcloud builds submit --config=cloudbuild.yaml .` after cloning the repository. Add new commands here as discovered.