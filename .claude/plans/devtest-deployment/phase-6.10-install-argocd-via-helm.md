# Phase 6.10: Install ArgoCD via Helm

**Tool**: [WARP] Partner Execution
**Estimated Duration**: 20 minutes

## Purpose

Install ArgoCD on GKE Autopilot using Helm chart 9.0.5 with cluster-scoped mode, creating the argocd namespace and deploying all components.

## Prerequisites

- Phase 6.9 completed (validation passed)
- Helm repo argo added
- values-autopilot.yaml file ready
- kubectl context set to pcc-prj-devops-nonprod

## Detailed Steps

### Step 1: Verify Helm Repo

```bash
helm search repo argo/argo-cd --version 9.0.5
```

Expected output:
```
NAME            CHART VERSION   APP VERSION     DESCRIPTION
argo/argo-cd    9.0.5           v2.13.x         A Helm chart for Argo CD
```

### Step 2: Install ArgoCD

```bash
cd /home/jfogarty/pcc/infra/pcc-devops-infra/argocd-nonprod/devtest

helm install argocd argo/argo-cd \
  --version 9.0.5 \
  --namespace argocd \
  --create-namespace \
  -f values-autopilot.yaml
```

Expected output:
```
NAME: argocd
LAST DEPLOYED: <timestamp>
NAMESPACE: argocd
STATUS: deployed
REVISION: 1
```

### Step 3: Watch Pod Creation

```bash
kubectl get pods -n argocd --watch
```

Wait for all pods to reach Running status (~3-5 minutes).

Expected pods:
- argocd-application-controller-0 (StatefulSet)
- argocd-server-xxx (Deployment)
- argocd-repo-server-xxx (Deployment)
- argocd-redis-xxx (StatefulSet)
- argocd-dex-server-xxx (Deployment)
- argocd-applicationset-controller-xxx (Deployment)
- argocd-notifications-controller-xxx (Deployment)

Press `Ctrl+C` when all show Running/1/1.

### Step 4: Wait for All Pods Ready

```bash
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/part-of=argocd \
  -n argocd \
  --timeout=300s
```

Expected: All pods become ready within 5 minutes.

### Step 5: Verify Deployments

```bash
kubectl get deployments -n argocd
```

Expected: All deployments show READY 1/1 or 2/2.

### Step 6: Verify Services

```bash
kubectl get services -n argocd
```

Expected services:
- argocd-server (ClusterIP)
- argocd-server-metrics (ClusterIP)
- argocd-repo-server (ClusterIP)
- argocd-redis (ClusterIP)
- argocd-dex-server (ClusterIP)

### Step 7: Check Helm Release Status

```bash
helm list -n argocd
```

Expected:
```
NAME    NAMESPACE   REVISION    STATUS      CHART           APP VERSION
argocd  argocd      1           deployed    argo-cd-9.0.5   v2.13.x
```

## Success Criteria

- ✅ Helm install completes without errors
- ✅ argocd namespace created
- ✅ All pods reach Running state
- ✅ All pods pass readiness checks
- ✅ All deployments show READY
- ✅ argocd-server service created (ClusterIP)
- ✅ Helm release status = deployed

## HALT Conditions

**HALT if**:
- Helm install fails
- Pods stuck in Pending/Init/CrashLoopBackOff
- Pods fail readiness checks after 5 minutes
- ImagePullBackOff errors
- Resource quota exceeded

**Resolution**:
- Check pod logs: `kubectl logs -n argocd <pod-name>`
- Describe failing pods: `kubectl describe pod -n argocd <pod-name>`
- Verify Workload Identity annotations: `kubectl get sa -n argocd argocd-application-controller -o yaml`
- Check resource constraints: `kubectl describe nodes`
- Rollback if needed: `helm uninstall argocd -n argocd`

## Next Phase

Proceed to **Phase 6.11**: Validate Workload Identity

## Notes

- `--create-namespace` flag creates argocd namespace (no Terraform needed)
- Cluster-scoped mode allows ArgoCD to create namespaces for applications
- Initial admin password is auto-generated in secret `argocd-initial-admin-secret`
- Do NOT access ArgoCD UI yet - no Ingress configured
- Pods use Workload Identity annotations from values-autopilot.yaml
- If install fails, safe to uninstall and retry after fixing issues
