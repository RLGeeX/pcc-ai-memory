# Setup Guide for 'pcc-app-argo-config' Argo CD Configuration Repository

This guide provides a comprehensive, step-by-step process to set up the 'pcc-app-argo-config' Argo CD configuration repository. It focuses on integrating Argo CD with Google Kubernetes Engine (GKE) clusters on Google Cloud Platform (GCP), ensuring YAML validation, and enabling GitOps workflows. The repository is assumed to contain Argo CD Application manifests, Kubernetes resources, and configuration files for deploying applications across multiple environments.

The guide assumes a Unix-like environment (Linux/macOS) and basic familiarity with command-line tools. All commands are executable in a terminal.

## 1. Prerequisites

Before starting, install and verify the required tools: Argo CD CLI, kubectl, and gcloud CLI. These are essential for managing Argo CD, Kubernetes clusters, and GCP resources.

### Install kubectl
kubectl is the Kubernetes command-line tool for interacting with clusters.

- **On macOS (using Homebrew):**
  ```
  brew install kubectl
  ```

- **On Linux (using curl):**
  ```
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
  ```

- **Verify installation:**
  ```
  kubectl version --client
  ```
  Expected output: Client version details (e.g., v1.28.x).

### Install Argo CD CLI
The Argo CD CLI manages Argo CD applications and clusters.

- **Download and install (latest stable version):**
  ```
  curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
  sudo install -o root -g root -m 0755 argocd /usr/local/bin/argocd
  chmod +x /usr/local/bin/argocd
  ```

- **On macOS (Homebrew):**
  ```
  brew install argocd
  ```

- **Verify installation:**
  ```
  argocd version --client
  ```
  Expected output: Argo CD Client version (e.g., v2.8.x).

### Install gcloud CLI
The Google Cloud CLI is required for GKE authentication and cluster management.

- **Install on Linux/macOS:**
  Download from the official site or use:
  ```
  curl https://sdk.cloud.google.com | bash
  exec -l $SHELL
  gcloud init
  ```

- **On macOS (Homebrew):**
  ```
  brew install google-cloud-sdk
  ```

- **Verify installation:**
  ```
  gcloud version
  ```
  Expected output: Google Cloud SDK version (e.g., 456.x).

Update components:
```
gcloud components update
```

## 2. GCP and GKE Authentication Setup

Authenticate with GCP and configure access to GKE clusters. This enables Argo CD to connect to your clusters.

### Authenticate with gcloud
- **Initialize gcloud (if not done):**
  ```
  gcloud init
  ```
  Follow prompts to log in via browser and select a project.

- **Authenticate with your account:**
  ```
  gcloud auth login
  ```
  This opens a browser for OAuth consent.

- **Set default project (replace `your-project-id` with your GCP project ID):**
  ```
  gcloud config set project your-project-id
  ```

### Configure GKE Access
- **Get credentials for a specific GKE cluster (replace placeholders):**
  ```
  gcloud container clusters get-credentials pcc-cluster --zone us-central1-a --project your-project-id
  ```
  This updates your kubeconfig file (`~/.kube/config`) with cluster credentials.

- **Verify cluster access:**
  ```
  kubectl get nodes
  ```
  Expected output: List of nodes in the cluster (e.g., gke-pcc-cluster-...).

- **For multiple clusters:** Repeat the `get-credentials` command for each cluster, specifying unique context names if needed:
  ```
  gcloud container clusters get-credentials staging-cluster --zone us-central1-a --project your-project-id --context staging
  gcloud container clusters get-credentials production-cluster --zone us-central1-b --project your-project-id --context production
  ```

- **List configured contexts:**
  ```
  kubectl config get-contexts
  ```
  Switch contexts with `kubectl config use-context <context-name>`.

Ensure your GCP service account (if using) has roles like `roles/container.admin` for GKE management.

## 3. Repository Cloning and Initial Setup

Clone the 'pcc-app-argo-config' repository and prepare the local environment.

- **Clone the repository (replace with your repo URL, e.g., GitHub):**
  ```
  git clone https://github.com/your-org/pcc-app-argo-config.git
  cd pcc-app-argo-config
  ```

- **Install dependencies (if any, e.g., for scripts):**
  Assuming the repo uses Python for helpers, install via pip:
  ```
  pip install -r requirements.txt  # If requirements.txt exists
  ```

- **Review structure:** The repo should have directories like:
  - `apps/`: Argo CD Application YAMLs (e.g., `app-staging.yaml`).
  - `envs/`: Environment-specific configs (e.g., `staging/values.yaml`).
  - `k8s/`: Base Kubernetes manifests.
  - `.github/workflows/`: CI/CD pipelines (optional).

- **Initialize git (if starting fresh):**
  ```
  git checkout -b setup-branch
  ```

- **Set up local .env file for secrets (create if needed):**
  ```
  cp .env.example .env
  # Edit .env with values like ARGOCD_SERVER=argo-cd.example.com
  ```

## 4. Argo CD CLI Authentication and Configuration

Authenticate the Argo CD CLI to your Argo CD instance and configure it for the repository.

### Install and Access Argo CD (Assuming Argo CD is Running in GKE)
- If Argo CD is not installed, install it in your GKE cluster:
  ```
  kubectl create namespace argocd
  kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
  ```

- **Port-forward to access Argo CD UI (temporary):**
  ```
  kubectl port-forward svc/argocd-server -n argocd 8080:443
  ```
  Access UI at `https://localhost:8080` (ignore self-signed cert warning).

- **Get initial admin password:**
  ```
  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
  ```
  Username: `admin`. Use this to log in to the UI.

### Authenticate Argo CD CLI
- **Log in to Argo CD server (replace with your server URL):**
  ```
  argocd login argo-cd.your-domain.com:443 --username admin --password <admin-password> --insecure
  ```
  The `--insecure` flag skips TLS verification for self-signed certs.

- **Set default context:**
  ```
  argocd cluster add kubernetes --name pcc-cluster  # Adds current kubeconfig context
  ```

- **Verify login:**
  ```
  argocd account list
  ```
  Expected output: List of users (e.g., admin).

- **Configure repo access:** Add the 'pcc-app-argo-config' repo to Argo CD:
  ```
  argocd repo add https://github.com/your-org/pcc-app-argo-config.git --username <git-username> --password <git-token>
  ```

## 5. YAML Validation Tools Setup

Set up tools for validating YAML files in the repository to ensure Kubernetes compatibility.

### Install yamllint
yamllint checks YAML syntax and style.

- **Using pip:**
  ```
  pip install yamllint
  ```

- **Verify:**
  ```
  yamllint --version
  ```

### Install kubeval
kubeval validates Kubernetes YAML against the Kubernetes schema.

- **Download (Linux/macOS):**
  ```
  curl -s https://github.com/instrumenta/kubeval/releases/latest/download/kubeval-linux-amd64.tar.gz | tar xz kubeval-linux-amd64
  sudo mv kubeval-linux-amd64 /usr/local/bin/kubeval
  chmod +x /usr/local/bin/kubeval
  ```

- **On macOS (Homebrew):**
  ```
  brew install kubeval
  ```

- **Verify:**
  ```
  kubeval --version
  ```

- **Global config:** Create `~/.kubevalrc` for custom Kubernetes version:
  ```
  version: "1.28.0"
  ```

## 6. Local Testing Procedures with kubectl and argocd CLI

Test configurations locally before pushing to the repository.

### Test with kubectl
- **Dry-run apply for a YAML file (e.g., from apps/):**
  ```
  kubectl apply -f apps/app-staging.yaml --dry-run=client -o yaml
  ```
  This validates syntax without applying.

- **Validate specific resources:**
  ```
  kubectl get --raw=/api/v1 | jq .  # Test API access
  ```

### Test with argocd CLI
- **Generate app manifest:**
  ```
  argocd app create apps/app-staging.yaml --dry-run
  ```

- **Simulate sync:**
  ```
  argocd app sync apps/app-staging.yaml --dry-run
  ```

- **Validate repo:**
  ```
  yamllint apps/*.yaml
  kubeval --filename apps/app-staging.yaml
  ```
  Expected: No errors for valid YAML.

- **Full local test script (create test.sh):**
  ```bash
  #!/bin/bash
  yamllint k8s/*.yaml
  kubeval k8s/*.yaml
  kubectl apply -f k8s/ --dry-run=server
  echo "All tests passed!"
  ```
  Run: `chmod +x test.sh && ./test.sh`.

## 7. Pre-commit Hooks Configuration for YAML Linting

Use pre-commit to enforce YAML linting on git commits.

- **Install pre-commit:**
  ```
  pip install pre-commit
  ```

- **Create .pre-commit-config.yaml in repo root:**
  ```yaml
  repos:
  - repo: https://github.com/adrienverge/yamllint
    rev: v1.32.0
    hooks:
    - id: yamllint
      args: [--config-file=.yamllint]
  - repo: https://github.com/instrumenta/kubeval
    rev: v0.16.1
    hooks:
    - id: kubeval
      args: [--version=1.28.0, --filename]
  ```

- **Create .yamllint config (optional, for custom rules):**
  ```yaml
  extends: default
  rules:
    line-length: disable
  ```

- **Install hooks:**
  ```
  pre-commit install
  ```

- **Test hooks:**
  ```
  pre-commit run --all-files
  ```
  This lints all files; fix any issues before committing.

Commits will now automatically run yamllint and kubeval.

## 8. Environment Configuration for Multiple GKE Clusters

Configure Argo CD for multi-cluster deployments (e.g., staging and production).

- **Define cluster contexts in kubeconfig:** As in Step 2, add multiple clusters.

- **Add clusters to Argo CD:**
  ```
  argocd cluster add kubernetes:staging --name staging
  argocd cluster add kubernetes:production --name production
  ```

- **Repository structure for envs:** Organize YAMLs like:
  - `apps/staging-app.yaml`: References `path: envs/staging`.
  - `apps/prod-app.yaml`: References `path: envs/production`.

  Example `apps/staging-app.yaml`:
  ```yaml
  apiVersion: argoproj.io/v1alpha1
  kind: Application
  metadata:
    name: pcc-app-staging
    namespace: argocd
  spec:
    project: default
    source:
      repoURL: https://github.com/your-org/pcc-app-argo-config.git
      targetRevision: HEAD
      path: envs/staging
    destination:
      server: https://kubernetes.default.svc (staging cluster server)
      namespace: default
    syncPolicy:
      automated:
        prune: true
        selfHeal: true
  ```

- **Apply apps:**
  ```
  kubectl apply -f apps/staging-app.yaml
  kubectl apply -f apps/prod-app.yaml
  ```

- **Monitor in Argo CD:**
  ```
  argocd app list
  argocd app sync pcc-app-staging
  ```

Use Helm values or Kustomize in `envs/` for cluster-specific overrides.

## 9. Troubleshooting Common Setup Issues

- **gcloud auth fails:** Run `gcloud auth application-default login`. Check project ID with `gcloud projects list`.

- **kubectl can't connect to GKE:** Verify credentials: `gcloud container clusters describe pcc-cluster`. Re-run `get-credentials`.

- **Argo CD login error (TLS/hostname):** Use `--insecure` or fix certs. Check server URL with `kubectl get svc -n argocd`.

- **YAML linting fails:** Update tools (`pip install --upgrade yamllint`). For kubeval schema errors, specify `--version` matching your cluster.

- **Repo add fails in Argo CD:** Ensure git credentials are correct; test with `git ls-remote <repo-url>`.

- **Pre-commit not running:** Run `pre-commit install --install-hooks`. Bypass temporarily with `git commit --no-verify`.

- **Multi-cluster sync issues:** Verify Argo CD has RBAC access: `kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/cluster-rbac/cluster-admin.yaml`.

- **General logs:** Check Argo CD pods: `kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server`.

If issues persist, enable debug logging: `argocd --loglevel debug`. For GCP-specific errors, consult `gcloud alpha container clusters describe`.
