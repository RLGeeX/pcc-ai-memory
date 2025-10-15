# Argo CD and GitOps Commands

**Note:** Run initial Argo CD authentication and kubectl context setup after cloning the repository. Add new commands here as discovered.

This reference provides a comprehensive set of CLI commands for managing the 'pcc-app-argo-config' Argo CD configuration repository. It covers essential workflows for GitOps practices, including application deployment, Kubernetes resource management, validation, and troubleshooting. Examples assume a standard setup with Argo CD installed, kubectl configured, and access to a GKE cluster. Replace placeholders like `<argocd-server>`, `<namespace>`, `<app-name>`, and `<project-id>` with your specific values.

## 1. Argo CD CLI Commands

Argo CD CLI (`argocd`) is used for interacting with the Argo CD server, managing applications, performing syncs, and checking health/status.

### Login and Authentication
- **Login to Argo CD server:**
  ```
  argocd login <argocd-server> --username <admin> --password <password> --insecure
  ```
  *Example:* `argocd login argocd.example.com --username admin --password mypass --insecure`

- **Login with token:**
  ```
  argocd login <argocd-server> --token <token> --insecure
  ```

- **Logout:**
  ```
  argocd logout <argocd-server>
  ```

### Application Management
- **List all applications:**
  ```
  argocd app list
  ```

- **Get details of a specific application:**
  ```
  argocd app get <app-name>
  ```
  *Example:* `argocd app get pcc-app`

- **Create an application from YAML manifest:**
  ```
  argocd app create -f <path-to-app-yaml>
  ```
  *Example:* `argocd app create -f apps/pcc-app.yaml`

- **Update an application:**
  ```
  argocd app set <app-name> --repo <git-repo-url> --path <path-in-repo> --dest-server <k8s-api-server> --dest-namespace <namespace>
  ```
  *Example:* `argocd app set pcc-app --repo https://github.com/org/pcc-app-argo-config.git --path k8s/overlays/prod --dest-server https://kubernetes.default.svc --dest-namespace prod`

- **Delete an application:**
  ```
  argocd app delete <app-name> --cascade
  ```
  *Example:* `argocd app delete pcc-app --cascade`

### Sync Operations
- **Sync an application:**
  ```
  argocd app sync <app-name>
  ```
  *Example:* `argocd app sync pcc-app`

- **Sync with specific revision:**
  ```
  argocd app sync <app-name> --revision <git-revision>
  ```
  *Example:* `argocd app sync pcc-app --revision main`

- **Hard refresh and sync (prune resources):**
  ```
  argocd app sync <app-name> --prune --force --local <path-to-local-manifests>
  ```
  *Example:* `argocd app sync pcc-app --prune --force --local ./k8s`

- **Sync all applications:**
  ```
  argocd app sync <app-name> --selector app.kubernetes.io/part-of=pcc
  ```

### Health Checks
- **Check application health:**
  ```
  argocd app get <app-name> --health
  ```
  *Example:* `argocd app get pcc-app --health`

- **Check health of all applications:**
  ```
  argocd app list --health
  ```

## 2. kubectl Commands for Kubernetes Resource Management

kubectl is the primary tool for interacting with Kubernetes clusters, applying manifests, and managing resources in the 'pcc-app-argo-config' repo.

### Cluster and Context Setup
- **Switch to a specific context (e.g., GKE cluster):**
  ```
  kubectl config use-context <context-name>
  ```
  *Example:* `kubectl config use-context gke_org-prod-us-central1_pcc-cluster`

- **Set default namespace:**
  ```
  kubectl config set-context --current --namespace=<namespace>
  ```
  *Example:* `kubectl config set-context --current --namespace=prod`

### Resource Management
- **Apply manifests from directory or file:**
  ```
  kubectl apply -f <path-to-yaml-or-dir> -n <namespace>
  ```
  *Example:* `kubectl apply -f k8s/base -n prod`

- **Delete resources:**
  ```
  kubectl delete -f <path-to-yaml-or-dir> -n <namespace>
  ```
  *Example:* `kubectl delete -f k8s/overlays/staging/deployment.yaml -n staging`

- **Get resources (e.g., pods, deployments):**
  ```
  kubectl get pods -n <namespace> -l app=pcc-app
  ```
  *Example:* `kubectl get deployments -n prod`

- **Describe a resource:**
  ```
  kubectl describe deployment <deployment-name> -n <namespace>
  ```
  *Example:* `kubectl describe deployment pcc-app -n prod`

- **Port-forward for debugging:**
  ```
  kubectl port-forward deployment/<deployment-name> 8080:80 -n <namespace>
  ```
  *Example:* `kubectl port-forward deployment/pcc-app 8080:80 -n prod`

- **Scale a deployment:**
  ```
  kubectl scale deployment <deployment-name> --replicas=3 -n <namespace>
  ```
  *Example:* `kubectl scale deployment pcc-app --replicas=3 -n prod`

## 3. YAML Validation and Linting Commands

Use these tools to validate and lint YAML files in the 'pcc-app-argo-config' repository before committing or syncing.

### yamllint
- **Lint a single YAML file:**
  ```
  yamllint <file.yaml>
  ```
  *Example:* `yamllint k8s/base/deployment.yaml`

- **Lint all YAML files in a directory:**
  ```
  yamllint -d <config> <directory>
  ```
  *Example:* `yamllint -d .yamllint k8s/`

### kubeval
- **Validate YAML against Kubernetes schema:**
  ```
  kubeval <file.yaml>
  ```
  *Example:* `kubeval k8s/overlays/prod/configmap.yaml`

- **Validate with specific Kubernetes version:**
  ```
  kubeval --kubernetes-version 1.25 <file.yaml>
  ```
  *Example:* `kubeval --kubernetes-version 1.25 k8s/base/service.yaml`

- **Validate directory recursively:**
  ```
  find k8s/ -name "*.yaml" -exec kubeval {} \;
  ```

## 4. Kustomize Build and Validation Commands

Kustomize is used for customizing Kubernetes manifests in the repo (e.g., overlays for environments like prod/staging).

- **Build manifests from a kustomization directory:**
  ```
  kustomize build <kustomization-dir>
  ```
  *Example:* `kustomize build k8s/overlays/prod`

- **Build and output to file:**
  ```
  kustomize build <kustomization-dir> > generated-manifests.yaml
  ```
  *Example:* `kustomize build k8s/overlays/staging > staging-manifests.yaml`

- **Validate kustomization (dry-run):**
  ```
  kustomize build <kustomization-dir> --enable-helm --enable-exec
  ```
  *Example:* `kustomize build k8s/base --enable-helm`

- **Edit a kustomization (interactive):**
  ```
  kustomize edit set image <image-name> <new-tag>
  ```
  *Example:* `kustomize edit set image gcr.io/org/pcc-app:v1.2.3`

## 5. GCP/GKE Authentication and Cluster Management

Commands for authenticating with Google Cloud and managing GKE clusters where Argo CD deploys resources.

### Authentication
- **Authenticate with gcloud:**
  ```
  gcloud auth login
  ```

- **Set default project:**
  ```
  gcloud config set project <project-id>
  ```
  *Example:* `gcloud config set project pcc-prod-123`

- **Authenticate kubectl for GKE:**
  ```
  gcloud container clusters get-credentials <cluster-name> --zone <zone> --project <project-id>
  ```
  *Example:* `gcloud container clusters get-credentials pcc-cluster --zone us-central1 --project pcc-prod-123`

### Cluster Management
- **List GKE clusters:**
  ```
  gcloud container clusters list --project <project-id>
  ```
  *Example:* `gcloud container clusters list --project pcc-prod-123`

- **Get cluster details:**
  ```
  gcloud container clusters describe <cluster-name> --zone <zone> --project <project-id>
  ```
  *Example:* `gcloud container clusters describe pcc-cluster --zone us-central1 --project pcc-prod-123`

- **Update cluster (e.g., enable/disable features):**
  ```
  gcloud container clusters update <cluster-name> --enable-autopilot --zone <zone> --project <project-id>
  ```

## 6. Git Workflows and Repository Management

Standard Git commands for managing the 'pcc-app-argo-config' repository, including branching for environments and PR workflows.

- **Clone the repository:**
  ```
  git clone <repo-url>
  ```
  *Example:* `git clone https://github.com/org/pcc-app-argo-config.git`

- **Create and switch to a feature branch:**
  ```
  git checkout -b feature/new-config
  ```

- **Commit changes:**
  ```
  git add . && git commit -m "Add prod overlay for PCC app"
  ```

- **Push to remote:**
  ```
  git push origin feature/new-config
  ```

- **Merge main branch:**
  ```
  git checkout main && git pull origin main && git merge feature/new-config
  ```

- **Create a tag for release:**
  ```
  git tag v1.0.0 && git push origin v1.0.0
  ```

- **View Git history for a file:**
  ```
  git log --oneline -- k8s/overlays/prod/deployment.yaml
  ```

## 7. Troubleshooting and Debugging Commands

Commands to diagnose issues in Argo CD syncs, Kubernetes resources, and GitOps pipelines.

- **Argo CD: Check sync status and history:**
  ```
  argocd app history <app-name>
  ```
  *Example:* `argocd app history pcc-app`

- **Argo CD: View application events:**
  ```
  argocd app logs <app-name>
  ```

- **kubectl: View pod logs:**
  ```
  kubectl logs deployment/<deployment-name> -n <namespace> --follow
  ```
  *Example:* `kubectl logs deployment/pcc-app -n prod --follow`

- **kubectl: Exec into a pod:**
  ```
  kubectl exec -it pod/<pod-name> -n <namespace> -- /bin/sh
  ```
  *Example:* `kubectl exec -it pod/pcc-app-abc123 -n prod -- /bin/sh`

- **gcloud: Check GKE node status:**
  ```
  gcloud container clusters describe <cluster-name> --zone <zone> --project <project-id> | grep status
  ```

- **Validate Git diff for YAML changes:**
  ```
  git diff --name-only --diff-filter=AM | grep '\.yaml$'
  ```

## 8. Monitoring and Status Checking Commands

Commands for ongoing monitoring of Argo CD applications, Kubernetes resources, and cluster health.

- **Argo CD: List applications with status:**
  ```
  argocd app list -o wide
  ```

- **Argo CD: Watch application sync:**
  ```
  argocd app get <app-name> --watch
  ```
  *Example:* `argocd app get pcc-app --watch`

- **kubectl: Watch resources:**
  ```
  kubectl get pods -n <namespace> -w
  ```
  *Example:* `kubectl get pods -n prod -w`

- **kubectl: Check resource usage:**
  ```
  kubectl top pods -n <namespace>
  ```
  *Example:* `kubectl top pods -n prod`

- **gcloud: List GKE operations:**
  ```
  gcloud container operations list --zone <zone> --project <project-id>
  ```

- **Argo CD: Generate compliance report:**
  ```
  argocd app diff <app-name> --local <path>
  ```
  *Example:* `argocd app diff pcc-app --local ./k8s`
