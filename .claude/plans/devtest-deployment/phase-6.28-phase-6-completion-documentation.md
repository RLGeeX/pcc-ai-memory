# Phase 6.28: Phase 6 Completion Documentation

**Tool**: [CC] Claude Code
**Estimated Duration**: 30 minutes

## Purpose

Create comprehensive documentation for the completed ArgoCD deployment, including architecture overview, operational runbook, troubleshooting guide, and handoff documentation for production deployment.

## Prerequisites

- Phase 6.27 completed (E2E validation passed)
- All 27 phases successfully executed
- Access to `pcc-app-argo-config` repository

## Detailed Steps

### Step 1: Create Documentation Directory

```bash
mkdir -p ~/pcc/core/pcc-app-argo-config/docs
cd ~/pcc/core/pcc-app-argo-config/docs
```

### Step 2: Create Architecture Overview Document

Create file: `argocd-nonprod-architecture.md`

```markdown
# ArgoCD NonProd Architecture - DevTest Cluster

## Overview

ArgoCD deployed on GKE Autopilot cluster `pcc-prj-devops-nonprod` for GitOps-based application deployment and testing ArgoCD/GKE upgrades before production rollout.

## Architecture Components

### Infrastructure Layer

- **GKE Cluster**: Autopilot mode (us-east4)
- **Compute**: Auto-provisioned by GKE Autopilot
- **Networking**: VPC-native, private nodes
- **Load Balancer**: GCP L7 HTTPS load balancer
- **SSL Certificate**: GCP-managed certificate (auto-renewal)
- **DNS**: Cloudflare DNS (automated via ExternalDNS)

### ArgoCD Deployment

- **Installation Method**: Helm chart 9.0.5 (argo/argo-cd)
- **Mode**: Cluster-scoped (can create namespaces, manage cluster resources)
- **Namespace**: `argocd`
- **Components**:
  - Application Controller: Reconciles Git state → cluster state
  - Server: API server and UI
  - Repo Server: Git repository operations
  - Dex: OAuth authentication (Google Workspace)
  - Redis: Cache for application state

### Authentication & Authorization

- **Primary Auth**: Google Workspace OIDC via Dex
- **Groups**:
  - `gcp-admins@pcconnect.ai`: Full admin access
  - `gcp-devops@pcconnect.ai`: App management (no settings)
  - `gcp-developers@pcconnect.ai`: Read-only
  - `gcp-read-only@pcconnect.ai`: Read-only
- **Emergency Access**: Admin password in Secret Manager

### GitOps Workflow

- **Repository**: `git@github.com:ORG/pcc-app-argo-config.git`
- **Pattern**: App-of-apps (root app manages child apps)
- **Sync Policy**: Automated with self-healing
- **Poll Interval**: 3 minutes (default)

### Service Accounts & Workload Identity

| Component | K8s SA | GCP SA | IAM Roles |
|-----------|--------|--------|-----------|
| Application Controller | argocd-application-controller | argocd-controller@PROJECT | container.viewer, compute.viewer, logging.logWriter |
| Server | argocd-server | argocd-server@PROJECT | secretmanager.admin |
| Dex | argocd-dex-server | argocd-dex@PROJECT | logging.logWriter |
| Redis | argocd-redis | argocd-redis@PROJECT | logging.logWriter |
| ExternalDNS | externaldns | externaldns@PROJECT | dns.admin |
| Velero | velero | velero@PROJECT | storage.objectAdmin |

### Backup & Restore

- **Tool**: Velero v1.14.0
- **Backend**: GCS bucket `pcc-argocd-backups-nonprod`
- **Schedule**: Daily at 2 AM UTC
- **Retention**: 3 days (nonprod)
- **Scope**: argocd and application namespaces

### Monitoring

- **Platform**: GCP Cloud Monitoring
- **Metrics**: Container readiness, CPU, memory
- **Alerts**: ArgoCD server down, sync failures
- **Logs**: GCP Cloud Logging (30-day retention)

### Network Security

- **NetworkPolicies**: Applied to all ArgoCD components
- **Ingress**: Allow from GCP LB and within namespace
- **Egress**: Wide-open (nonprod) - allows all outbound traffic
- **Production**: Tighten egress to specific destinations

## URL & Access

- **ArgoCD UI**: https://argocd.nonprod.pcconnect.ai
- **Authentication**: Google Workspace OIDC
- **CLI Access**: `argocd login argocd.nonprod.pcconnect.ai`

## Repository Structure

```
pcc-app-argo-config/
├── argocd-nonprod/
│   └── devtest/
│       ├── app-of-apps/           # App-of-apps pattern
│       │   ├── root-app.yaml      # Root application
│       │   └── apps/              # Child applications
│       ├── ingress/               # Ingress resources
│       └── network-policies/      # NetworkPolicy resources
├── hello-world-nonprod/           # Sample application
└── docs/                          # Documentation
```

## Deployment Summary

- **Phases Completed**: 27
- **Duration**: ~6 hours (with validation)
- **Terraform Resources**: 19 (6 SAs, 6 WI bindings, 1 cert, 1 bucket, IAM roles)
- **Helm Charts**: 2 (ArgoCD, ExternalDNS)
- **Velero**: 1 (CLI install)

## Key Design Decisions

1. **Cluster-Scoped Mode**: Allows namespace creation (NOT namespace-scoped)
2. **Wide-Open Egress**: Simplifies debugging (nonprod philosophy)
3. **3-Day Retention**: Cost optimization for nonprod
4. **Cloudflare DNS**: Faster propagation than GCP Cloud DNS
5. **GCP-Managed SSL**: Automatic renewal, no cert management
6. **Workload Identity**: No service account keys (more secure)

## Production Differences

| Feature | NonProd (DevTest) | Production |
|---------|-------------------|------------|
| Backup Retention | 3 days | 30 days |
| NetworkPolicy Egress | Wide-open | Restricted to required destinations |
| Monitoring Alerts | No notifications | Email/Slack/PagerDuty |
| High Availability | Single replica | Multi-replica with anti-affinity |
| Resource Requests | Autopilot minimums | Sized for production load |
| Default Deny Policy | Disabled | Enabled |

## Related Documentation

- Phase 6 Planning: `/home/jfogarty/pcc/.claude/plans/devtest-deployment/`
- Terraform Code: `infra/pcc-devops-infra/argocd-nonprod/devtest/`
- Helm Values: `infra/pcc-devops-infra/argocd-nonprod/devtest/values-autopilot.yaml`
```

### Step 3: Create Operational Runbook

Create file: `argocd-nonprod-runbook.md`

```markdown
# ArgoCD NonProd Operational Runbook

## Daily Operations

### Check ArgoCD Health

```bash
# Via CLI
argocd app list

# Via UI
https://argocd.nonprod.pcconnect.ai
```

### Sync Application Manually

```bash
argocd app sync <app-name>
```

### View Application Details

```bash
argocd app get <app-name>
```

### Check Application Logs

```bash
kubectl logs -n <namespace> -l app=<app-name>
```

## Common Tasks

### Add New Application

1. Create application manifests in Git repository
2. Create ArgoCD Application manifest in `app-of-apps/apps/`
3. Add to `kustomization.yaml`
4. Commit and push to Git
5. Wait for ArgoCD to sync (or force sync)

### Update ArgoCD Configuration

1. Modify `values-autopilot.yaml`
2. Run `helm upgrade argocd argo/argo-cd --version 9.0.5 -f values-autopilot.yaml -n argocd`
3. Verify pods restart successfully

### Rotate OAuth Credentials

1. Create new OAuth credentials in Google Cloud Console
2. Update `argocd-secret`:
   ```bash
   kubectl patch secret argocd-secret -n argocd \
     --type='json' \
     -p="[{\"op\": \"replace\", \"path\": \"/data/dex.google.clientSecret\", \"value\": \"$(echo -n NEW_SECRET | base64 -w0)\"}]"
   ```
3. Restart Dex: `kubectl rollout restart deployment/argocd-dex-server -n argocd`

### Backup Manually

```bash
velero backup create manual-backup-$(date +%Y%m%d-%H%M%S) \
  --include-namespaces argocd,hello-world \
  --wait
```

### Restore from Backup

```bash
velero restore create restore-from-<backup-name> \
  --from-backup <backup-name> \
  --wait
```

### View Backup Status

```bash
velero backup get
velero backup describe <backup-name>
```

### Access Emergency Admin Account

```bash
# Get admin password from Secret Manager
ADMIN_PASSWORD=$(gcloud secrets versions access latest --secret=argocd-admin-password)

# Login
argocd login argocd.nonprod.pcconnect.ai --username admin --password "${ADMIN_PASSWORD}"
```

## Monitoring & Troubleshooting

### Check ArgoCD Component Health

```bash
kubectl get pods -n argocd
kubectl get deployments -n argocd
kubectl get statefulsets -n argocd
```

### View ArgoCD Logs

```bash
# Application Controller
kubectl logs -n argocd statefulset/argocd-application-controller -c application-controller --tail=100

# Server
kubectl logs -n argocd deployment/argocd-server --tail=100

# Repo Server
kubectl logs -n argocd deployment/argocd-repo-server --tail=100

# Dex
kubectl logs -n argocd deployment/argocd-dex-server --tail=100
```

### Check Sync Status

```bash
# All applications
argocd app list

# Specific application
argocd app sync-status <app-name>
```

### Force Reconciliation

```bash
# Sync all applications
argocd app sync --all

# Hard refresh (ignore cache)
argocd app sync <app-name> --force
```

### Verify NetworkPolicies

```bash
kubectl get networkpolicies -n argocd
kubectl describe networkpolicy <policy-name> -n argocd
```

### Test Connectivity

```bash
# From argocd-server to repo-server
kubectl exec -n argocd deployment/argocd-server -- curl http://argocd-repo-server.argocd.svc.cluster.local:8081

# From Dex to Google OAuth
kubectl exec -n argocd deployment/argocd-dex-server -- curl -I https://accounts.google.com
```

## Maintenance Windows

### Upgrade ArgoCD

1. Check for new chart version: `helm search repo argo/argo-cd --versions`
2. Review changelog and breaking changes
3. Update `values-autopilot.yaml` if needed
4. Backup current state: `velero backup create pre-upgrade-backup --include-namespaces argocd`
5. Upgrade:
   ```bash
   helm upgrade argocd argo/argo-cd --version <NEW_VERSION> -f values-autopilot.yaml -n argocd
   ```
6. Verify health: `kubectl get pods -n argocd`
7. Test functionality: Login to UI, sync test application

### Upgrade Velero

1. Download new Velero CLI
2. Run `velero install` with `--upgrade` flag
3. Verify backup storage location still available

### Update ExternalDNS

```bash
helm upgrade external-dns external-dns/external-dns \
  --version <NEW_VERSION> \
  -f values-externaldns.yaml \
  -n argocd
```

## Emergency Procedures

### ArgoCD Server Down

1. Check pod status: `kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server`
2. View logs: `kubectl logs -n argocd deployment/argocd-server --tail=100`
3. Restart if needed: `kubectl rollout restart deployment/argocd-server -n argocd`
4. If Redis issue, restart Redis: `kubectl rollout restart statefulset/argocd-redis -n argocd`

### Sync Failing

1. Check application status: `argocd app get <app-name>`
2. View sync errors: `argocd app sync <app-name> --dry-run`
3. Check repo access: `argocd repo list`
4. Force refresh: `argocd app sync <app-name> --force`

### OAuth Login Failing

1. Check Dex logs: `kubectl logs -n argocd deployment/argocd-dex-server`
2. Verify OAuth secret: `kubectl get secret argocd-secret -n argocd -o yaml`
3. Test OAuth endpoint: `curl https://accounts.google.com/.well-known/openid-configuration`
4. Restart Dex: `kubectl rollout restart deployment/argocd-dex-server -n argocd`

### Disaster Recovery

1. Provision new GKE cluster
2. Deploy ArgoCD (Phase 6.1-6.10)
3. Configure Git credentials (Phase 6.19)
4. Restore from Velero backup:
   ```bash
   velero restore create dr-restore --from-backup <backup-name>
   ```

## Contacts

- **Team**: DevOps
- **On-Call**: (TBD)
- **Documentation**: https://github.com/ORG/pcc-app-argo-config/tree/main/docs
```

### Step 4: Create Troubleshooting Guide

Create file: `argocd-nonprod-troubleshooting.md`

```markdown
# ArgoCD NonProd Troubleshooting Guide

## Application Sync Issues

### Application Stuck in "OutOfSync"

**Symptoms**: Application shows OutOfSync but does not sync automatically

**Diagnosis**:
```bash
argocd app get <app-name>
argocd app diff <app-name>
```

**Resolution**:
1. Force sync: `argocd app sync <app-name> --force`
2. If still stuck, check for invalid manifests
3. Check repo-server logs for Git access errors

### Application Sync Fails with "ComparisonError"

**Symptoms**: Sync operation fails with comparison error

**Diagnosis**:
```bash
kubectl logs -n argocd deployment/argocd-repo-server --tail=100
```

**Resolution**:
1. Verify Git repository accessible: `argocd repo list`
2. Check for YAML syntax errors in manifests
3. Validate manifests: `kubectl apply --dry-run=client -f <manifest>`

### Self-Healing Not Working

**Symptoms**: Manual kubectl changes are not reverted

**Diagnosis**:
```bash
argocd app get <app-name> -o yaml | grep selfHeal
```

**Resolution**:
1. Verify selfHeal is enabled in application spec
2. Check application controller logs for errors
3. Force reconciliation: `argocd app sync <app-name>`

## Authentication Issues

### Cannot Login via Google OAuth

**Symptoms**: "LOG IN VIA GOOGLE" button does not work or returns error

**Diagnosis**:
```bash
kubectl logs -n argocd deployment/argocd-dex-server --tail=50
```

**Resolution**:
1. Verify OAuth credentials in Secret Manager
2. Check redirect URI matches: `https://argocd.nonprod.pcconnect.ai/api/dex/callback`
3. Verify Google Workspace group memberships
4. Restart Dex: `kubectl rollout restart deployment/argocd-dex-server -n argocd`

### User Has Wrong Permissions

**Symptoms**: User can access UI but cannot perform expected actions

**Diagnosis**:
```bash
kubectl get configmap argocd-rbac-cm -n argocd -o yaml
```

**Resolution**:
1. Verify user's Google Workspace group membership
2. Check RBAC policy in argocd-rbac-cm ConfigMap
3. Verify group mapping in Phase 6.5 configuration

## Connectivity Issues

### ExternalDNS Not Creating DNS Records

**Symptoms**: Ingress deployed but DNS record not created

**Diagnosis**:
```bash
kubectl logs -n argocd -l app.kubernetes.io/name=external-dns --tail=100
```

**Resolution**:
1. Check Cloudflare API token validity (Phase 6.13 Step 2)
2. Verify Ingress has ExternalDNS annotation
3. Check ExternalDNS logs for authentication errors
4. Restart ExternalDNS: `kubectl rollout restart deployment/external-dns-external-dns -n argocd`

### ArgoCD UI Not Accessible

**Symptoms**: Cannot access https://argocd.nonprod.pcconnect.ai

**Diagnosis**:
```bash
dig argocd.nonprod.pcconnect.ai +short
gcloud compute ssl-certificates describe argocd-nonprod-cert
kubectl get ingress argocd-server -n argocd
```

**Resolution**:
1. Verify DNS resolves to load balancer IP
2. Check SSL certificate status (should be ACTIVE)
3. Verify Ingress has ADDRESS assigned
4. Check argocd-server pod is running

### NetworkPolicy Blocking Traffic

**Symptoms**: Pods cannot communicate with each other

**Diagnosis**:
```bash
kubectl get networkpolicies -n argocd
kubectl describe networkpolicy <policy-name> -n argocd
```

**Resolution**:
1. Verify NetworkPolicy pod selectors match pod labels
2. Check ingress/egress rules allow required traffic
3. Test connectivity: `kubectl exec -n argocd deployment/argocd-server -- curl <target-url>`
4. Temporarily delete NetworkPolicy for testing (NOT in production!)

## Backup/Restore Issues

### Velero Backup Fails

**Symptoms**: `velero backup create` fails or shows "PartiallyFailed"

**Diagnosis**:
```bash
velero backup describe <backup-name> --details
kubectl logs -n velero deployment/velero --tail=100
```

**Resolution**:
1. Verify Workload Identity working (Phase 6.11)
2. Check GCS bucket permissions
3. Verify BackupStorageLocation status: `kubectl get backupstoragelocation -n velero`
4. Check Velero logs for specific errors

### Restore Fails or Incomplete

**Symptoms**: `velero restore create` fails or resources not restored

**Diagnosis**:
```bash
velero restore describe <restore-name> --details
velero restore logs <restore-name>
```

**Resolution**:
1. Check for resource version conflicts
2. Verify namespace exists or CreateNamespace is enabled
3. Check for RBAC restrictions preventing resource creation
4. Review restore logs for specific errors

## Performance Issues

### ArgoCD UI Slow

**Symptoms**: UI takes long time to load or respond

**Diagnosis**:
```bash
kubectl top pods -n argocd
kubectl get pods -n argocd -o wide
```

**Resolution**:
1. Check Redis pod CPU/memory usage
2. Increase Redis resources in values-autopilot.yaml
3. Check application controller CPU/memory usage
4. Clear Redis cache: `kubectl delete pod -n argocd -l app.kubernetes.io/name=argocd-redis`

### Sync Takes Long Time

**Symptoms**: Application sync operation takes > 5 minutes

**Diagnosis**:
```bash
kubectl logs -n argocd statefulset/argocd-application-controller -c application-controller --tail=100
```

**Resolution**:
1. Check repo-server resource usage
2. Increase repo-server resources if needed
3. Check Git repository size (large repos = slower sync)
4. Consider using shallow clones if repo is very large

## Emergency Recovery

### Complete Cluster Failure

1. Provision new GKE cluster (Phase 3)
2. Deploy Terraform infrastructure (Phase 6.7)
3. Install ArgoCD (Phase 6.10)
4. Configure Git credentials (Phase 6.19)
5. Restore from latest Velero backup
6. Verify all applications synced

### ArgoCD Installation Corrupted

1. Create backup if possible: `velero backup create emergency-backup --include-namespaces argocd`
2. Delete ArgoCD: `helm uninstall argocd -n argocd`
3. Reinstall ArgoCD (Phase 6.10)
4. Restore configuration or re-apply from Git

## Useful Commands

```bash
# Force refresh all applications
argocd app list -o name | xargs -n1 argocd app sync --force

# Get all ArgoCD resources
kubectl get all -n argocd

# Describe all pods (useful for debugging)
kubectl describe pods -n argocd

# Get events (recent issues)
kubectl get events -n argocd --sort-by='.lastTimestamp' | tail -20

# Check Workload Identity
kubectl exec -n argocd deployment/argocd-server -- curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email

# Test Git connectivity
kubectl exec -n argocd deployment/argocd-repo-server -- git ls-remote git@github.com:ORG/pcc-app-argo-config.git
```
```

### Step 5: Create Production Handoff Document

Create file: `production-deployment-guide.md`

```markdown
# ArgoCD Production Deployment Guide

This document outlines differences and additional steps for deploying ArgoCD to production based on lessons learned from nonprod deployment.

## Production Environment Specifications

- **Cluster**: `pcc-prj-devops-prod` (GKE Autopilot, us-east4)
- **Domain**: `argocd.prod.pcconnect.ai`
- **SSL Certificate**: GCP-managed
- **DNS Provider**: Cloudflare
- **Backup Retention**: 30 days (vs. 3 days in nonprod)

## Configuration Changes for Production

### 1. Resource Sizing

Increase resource requests/limits in `values-autopilot.yaml`:

```yaml
controller:
  resources:
    requests:
      cpu: 500m      # vs. 250m in nonprod
      memory: 1Gi    # vs. 512Mi in nonprod

server:
  replicas: 2        # vs. 1 in nonprod (HA)
  resources:
    requests:
      cpu: 250m
      memory: 512Mi

repo-server:
  replicas: 2        # vs. 1 in nonprod (HA)
```

### 2. NetworkPolicy - Restrict Egress

Replace wide-open egress with specific destinations:

```yaml
egress:
  # GitHub (Git repository)
  - to:
    - ipBlock:
        cidr: 140.82.112.0/20  # GitHub IP range
    ports:
    - protocol: TCP
      port: 443
  # Google OAuth
  - to:
    - ipBlock:
        cidr: 0.0.0.0/0  # Google IPs vary
    ports:
    - protocol: TCP
      port: 443
  # DNS
  - to:
    ports:
    - protocol: UDP
      port: 53
```

### 3. Enable Default Deny NetworkPolicy

Uncomment in `networkpolicy-default-deny.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: argocd
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
```

### 4. Monitoring Alerts with Notifications

Add notification channels to alert policies:

```bash
# Create notification channel first
gcloud alpha monitoring channels create \
  --type=email \
  --display-name="DevOps On-Call" \
  --channel-labels=email_address=devops-oncall@pcconnect.ai

# Get channel ID
CHANNEL_ID=$(gcloud alpha monitoring channels list --filter="displayName='DevOps On-Call'" --format="value(name)")

# Update alert policies to use channel
gcloud alpha monitoring policies update POLICY_ID \
  --notification-channels=$CHANNEL_ID
```

### 5. Velero Backup Retention

Update to 30-day retention:

```bash
velero schedule create daily-backup-prod \
  --schedule="0 2 * * *" \
  --ttl 720h \  # 30 days
  --include-namespaces argocd,production-apps \
  --exclude-resources='events,events.events.k8s.io' \
  --default-volumes-to-fs-backup
```

### 6. High Availability Configuration

Enable pod anti-affinity for ArgoCD server and repo-server:

```yaml
server:
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchLabels:
            app.kubernetes.io/name: argocd-server
        topologyKey: kubernetes.io/hostname

repoServer:
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchLabels:
            app.kubernetes.io/name: argocd-repo-server
        topologyKey: kubernetes.io/hostname
```

### 7. Additional Security

- Implement PodSecurityStandards (restricted)
- Enable audit logging for ArgoCD API
- Rotate OAuth credentials every 90 days
- Enable GitHub commit signing verification
- Implement Gatekeeper/OPA policies for application manifests

## Testing Strategy

1. Deploy to staging cluster first
2. Run E2E validation (Phase 6.27)
3. Perform load testing on ArgoCD UI and API
4. Test disaster recovery (restore from backup)
5. Validate monitoring alerts trigger correctly
6. Verify RBAC permissions for all user groups
7. Test OAuth login for all groups
8. Canary deployment (deploy to single region first)

## Rollout Plan

1. **Pre-Deployment** (1 week before):
   - Create production infrastructure (Terraform)
   - Configure DNS (Cloudflare)
   - Set up OAuth credentials
   - Create monitoring dashboards
   - Document rollback procedures

2. **Deployment Day**:
   - Morning: Deploy ArgoCD to production
   - Afternoon: Configure Git credentials, deploy root app
   - Verify health checks pass
   - Enable monitoring alerts

3. **Post-Deployment** (first week):
   - Daily health checks
   - Monitor sync failures
   - Collect feedback from users
   - Optimize resource allocation if needed

## Rollback Procedures

If critical issue occurs:

1. Disable automated sync:
   ```bash
   argocd app set <app-name> --sync-policy none
   ```

2. Manual rollback via kubectl:
   ```bash
   kubectl rollout undo deployment/<deployment-name> -n <namespace>
   ```

3. Full ArgoCD rollback:
   ```bash
   helm rollback argocd <REVISION> -n argocd
   ```

4. Disaster recovery (if cluster corrupted):
   - Restore from latest Velero backup
   - Re-sync from Git

## Success Criteria

- ✅ All ArgoCD components healthy
- ✅ Google OAuth working for all user groups
- ✅ GitOps sync working (applications deploy automatically)
- ✅ Self-healing enabled and verified
- ✅ Backups running daily
- ✅ Monitoring alerts configured
- ✅ Zero downtime during deployment
- ✅ Load test passed (100+ concurrent users)
- ✅ Disaster recovery tested successfully

## Related Documentation

- NonProd Architecture: `argocd-nonprod-architecture.md`
- Operational Runbook: `argocd-nonprod-runbook.md`
- Troubleshooting Guide: `argocd-nonprod-troubleshooting.md`
```

### Step 6: Git Commit Documentation

```bash
cd ~/pcc/core/pcc-app-argo-config

git add docs/
git commit -m "docs(argocd): add comprehensive documentation for nonprod deployment

- Architecture overview with component diagram
- Operational runbook for daily tasks
- Troubleshooting guide for common issues
- Production deployment guide with recommended changes
- Covers all 27 phases of Phase 6 deployment"

git push origin main
```

## Success Criteria

- ✅ Architecture overview document created
- ✅ Operational runbook created
- ✅ Troubleshooting guide created
- ✅ Production deployment guide created
- ✅ Documentation committed to Git

## HALT Conditions

**HALT if**:
- Cannot create documentation files
- Git commit fails

**Resolution**:
- Check directory permissions
- Verify git repo is clean: `git status`
- Ensure on main branch: `git branch`

## Next Phase

Proceed to **Phase 6.29**: Phase 6 Completion Summary

## Notes

- **Comprehensive**: Covers all operational aspects of ArgoCD
- **Production-Ready**: Includes guidance for production deployment
- **Living Documents**: Should be updated as system evolves
- **Markdown Format**: Easy to read, version control, and search
- Documentation should be referenced during troubleshooting
- Runbook provides step-by-step instructions for common tasks
- Troubleshooting guide maps symptoms → diagnosis → resolution
- Production guide highlights key differences from nonprod
- All documentation stored in Git (version controlled)
- Can be rendered as web pages using Jekyll, MkDocs, or similar
- Consider creating diagrams (architecture, flow charts) using Mermaid or draw.io
- Documentation is as important as code - keep it up to date!
- Review and update documentation quarterly
- Add new sections as new use cases emerge
