# CLAUDE.md: Argo CD Configuration Repository for PCC Applications

This document provides guidance for Claude (Anthropic's AI assistant) when working with the `pcc-app-argo-config` repository. It outlines the project's purpose, technical context, best practices, and workflows tailored to Argo CD and GitOps principles. Use this as a reference to generate accurate, practical assistance for developers managing Kubernetes deployments via declarative YAML configurations.

## Project Overview

The `pcc-app-argo-config` repository serves as the central GitOps configuration hub for Argo CD deployments of PCC (Platform for Cloud Computing) application services. It stores declarative YAML manifests for Kubernetes resources, including ApplicationSets, Applications, Helm charts, Kustomize overlays, and custom sync policies. 

This setup enables continuous delivery by syncing Git changes to Kubernetes clusters automatically through Argo CD, ensuring infrastructure as code (IaC) for scalable, version-controlled deployments. The repository integrates with Google Cloud Platform (GCP) for hosting Kubernetes clusters (GKE) and leverages GitOps workflows to promote modularity, auditability, and zero-downtime updates across development, staging, and production environments. All configurations adhere to DevOps best practices, emphasizing security, observability, and reproducibility.

## Tech Stack

- **Argo CD**: Core GitOps continuous delivery tool for declarative Kubernetes management, handling syncs, rollouts, and application lifecycle.
- **Kubernetes**: Target orchestration platform (primarily GKE on GCP) for deploying pods, services, deployments, and custom resources.
- **YAML Manifests**: Primary format for all configurations, including Argo CD Applications, Kustomize bases/overlays, and Helm values files.
- **GitOps Tools**: Git as the single source of truth; integrated with Argo CD for pull-based deployments; supports tools like Kustomize for composition and Helm for templating.
- **GCP Integration**: GKE clusters for hosting; Google Cloud Build or Cloud Deploy for CI pipelines; IAM roles for secure access.
- **Supporting Tools**: `kubectl` for cluster interaction, `argocd` CLI for Argo CD management, `gcloud` for GCP operations, and linters like `yamllint` or `kubeval` for validation.

## Domain-Specific Guidance

When assisting with Argo CD configurations, focus on declarative GitOps patterns rather than imperative commands. Key concepts include:

- **Argo CD Applications**: Define resources using `Application` CRDs (e.g., specifying source repo, path, target cluster, and namespace). Use `ApplicationSet` for multi-cluster or multi-environment deployments to avoid duplication.
  
- **Sync Policies**: Implement automated syncs with options like `automated: { prune: true, selfHeal: true }` for self-healing drifts. For manual syncs, recommend `syncPolicy: { automated: {} }` with hooks (e.g., pre-sync Job for migrations). Always include retry policies and resource health checks.

- **Source Management**: Configurations pull from this repo (or submodules) using Helm, Kustomize, or raw YAML. For PCC services, structure paths like `/apps/{service-name}/base` for shared manifests and `/overlays/{env}` for environment-specific tweaks.

- **Kubernetes Resources**: Emphasize best practices for Deployments (replicas, rolling updates), Services (ClusterIP/LoadBalancer), Ingress (GCP-specific annotations for external traffic), and Secrets/ConfigMaps (integrated with GCP Secret Manager via External Secrets Operator).

- **GCP-Specific Patterns**: Use GKE autopilot for managed nodes; annotate resources for Workload Identity to bind to GCP service accounts; integrate with Cloud Monitoring/Logging for Argo CD health checks.

- **Common Pitfalls**: Avoid hardcoding secrets—use Sealed Secrets or external providers. Ensure RBAC for Argo CD service accounts. For multi-tenancy, scope Applications to namespaces with network policies.

Provide examples in YAML format, validated against Kubernetes schemas, and explain how changes trigger Argo CD sync waves for ordered rollouts.

## Code Style and Best Practices

Adhere to consistent, readable YAML for maintainability in GitOps workflows. Follow these guidelines:

- **YAML Formatting**:
  - Use 2-space indentation; align keys for readability.
  - Quote strings only when necessary (e.g., for booleans or numbers that might parse ambiguously).
  - Include `apiVersion`, `kind`, and `metadata` explicitly; use anchors (`&`) and aliases (`*`) for reusable snippets like labels.
  - Validate with tools: Run `yamllint` for style, `kubeval` or `kustomize build --validate` for schema compliance.

- **GitOps Workflows**:
  - Structure repo as: `/applications/` for Argo CD Apps, `/manifests/` for base Kustomize dirs, `/helm-charts/` for PCC service charts, and `/environments/` for overlays.
  - Use branching: `main` for prod, feature branches for changes, PRs with CI checks (e.g., `argocd app lint`).
  - Implement semantic versioning for manifests; tag releases to trigger Argo CD promotions.
  - Security: Scan YAML with `trivy` for vulnerabilities; use GitHub Actions or Cloud Build for pre-commit hooks enforcing style.

- **Argo CD Patterns**:
  - Prefer Kustomize over raw YAML for parameterization (e.g., `kustomization.yaml` with patches for env vars).
  - Define sync waves in `hooks` for dependencies (e.g., deploy DB before app).
  - Enable ignoreDifferences for non-drifting fields like node selectors in GKE.
  - Observability: Add resource labels (e.g., `app.kubernetes.io/managed-by: argocd`) and integrate with Prometheus for sync metrics.

Encourage modular designs: Break large manifests into composable pieces, ensuring idempotency for safe re-applies.

## Development Workflow

Follow this GitOps-centric workflow for local development and cluster interactions. Assume GCP project setup and authenticated tools.

### Prerequisites
- Install: `gcloud` CLI (for GCP), `kubectl` (Kubernetes), `argocd` CLI (Argo CD), `kustomize` (if not using `kubectl` built-in).
- Authenticate: Run `gcloud auth login` and `gcloud container clusters get-credentials {cluster-name} --zone {zone} --project {project-id}`.
- Clone: `git clone https://github.com/{org}/pcc-app-argo-config.git && cd pcc-app-argo-config`.

### Key Commands
- **GCP/GKE Setup**:
  - List clusters: `gcloud container clusters list --project {project-id}`.
  - Get credentials: `gcloud container clusters get-credentials {cluster-name} --zone {zone} --project {project-id}`.
  - Enable APIs: `gcloud services enable container.googleapis.com --project {project-id}`.

- **Argo CD Management**:
  - Login: `argocd login {argocd-server} --username {user} --password {pass} --insecure` (use certs in prod).
  - List apps: `argocd app list`.
  - Create/update app: `argocd app create {app-name} --repo https://github.com/{org}/pcc-app-argo-config.git --path {path} --dest-server https://kubernetes.default.svc --dest-namespace {ns}` or edit YAML and commit for GitOps sync.
  - Sync app: `argocd app sync {app-name} --prune --resources`.
  - Lint manifests: `argocd app lint {app-name}` or `argocd validate .` from repo root.
  - Get status: `argocd app get {app-name} --output yaml`.

- **Kubernetes Interactions**:
  - Apply local manifests (for testing): `kubectl apply -k {path/to/kustomize/dir}` or `kustomize build {dir} | kubectl apply -f -`.
  - Dry-run: `kubectl apply -k {dir} --dry-run=client -o yaml`.
  - Port-forward: `kubectl port-forward svc/{service} 8080:80 -n {ns}`.
  - Validate: `kubectl apply --dry-run=server -f {file.yaml}`.

- **Local Validation and Hooks**:
  - Format/lint: `yamllint **/*.yaml` and `pre-commit run --all-files` (install via `pip install pre-commit`).
  - Test sync: Use `argocd app create` with `--dry-run` before committing.
  - CI/CD: In PRs, run `kustomize build . | kubeval --strict` to catch errors early.

After cloning, run `argocd app sync` on updated branches to preview changes. For destructions, use `argocd app delete {app-name} --cascade` sparingly, favoring prune in sync policies.

**Note**: Always commit changes to Git to trigger Argo CD syncs. Add new commands (e.g., for Helm) as patterns evolve in PCC workflows.

## Claude Usage Context

When assisting with `pcc-app-argo-config`, Claude should act as an expert DevOps/GitOps consultant, generating YAML snippets, troubleshooting sync issues, and refining configurations for GCP-Kubernetes environments. Prioritize declarative examples over imperative steps—e.g., provide full `Application` YAML rather than CLI commands alone. 

Refine user requests for clarity: If asked for a new app config, suggest structures incorporating PCC service specifics like scaling replicas for traffic spikes. Encourage best practices like RBAC minimization and drift detection. For hypotheticals, simulate workflows (e.g., "If you update this YAML, Argo CD will...") without assuming real deployments. Avoid generating credentials or production overrides; focus on reusable, secure patterns to empower developers in building resilient GitOps pipelines. If unclear, ask for details on the target PCC service or environment.
