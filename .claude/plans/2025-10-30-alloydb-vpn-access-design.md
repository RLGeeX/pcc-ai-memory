# AlloyDB & GKE Private Access Design - WireGuard VPN Solution

**Date**: 2025-10-30 (Initial), 2025-10-31 (Pivot)
**Status**: PLANNING - Architecture pivot from Tailscale/Headscale to native WireGuard with MIG
**Phase**: Phase 2 (AlloyDB Cluster) + Phase 3 (GKE Private Control Plane)
**Estimated Deployment Time**: 2 hours (initial deployment), 1 hour (MIG conversion)
**Updated**: 2025-10-31 11:30 - Pivoting to WireGuard with MIG for production-grade HA

---

## 🔄 ARCHITECTURE PIVOT (2025-10-31)

**Decision**: Moving from Tailscale/Headscale to **native WireGuard with Managed Instance Group (MIG)**

**Rationale**:
1. **GKE Hosting Complexity**: GKE cannot easily host WireGuard as a subnet router due to:
   - No `hostNetwork: true` in Autopilot (blocked by policy)
   - Complex CNI integration required for pod-to-VPC routing
   - Subnet routing from pods to AlloyDB/GKE control plane is non-trivial

2. **VM is the Right Approach**: For subnet routing to private GCP resources:
   - VM networking model is straightforward (host network namespace)
   - IP forwarding and iptables work as expected
   - Can advertise routes to both AlloyDB PSC subnet AND GKE control plane subnet

3. **Simplification**: Native WireGuard eliminates:
   - Headscale control plane overhead
   - Tailscale client dependencies
   - Mesh networking complexity (we only need star topology: clients → VM → GCP subnets)

4. **High Availability**: Managed Instance Group provides:
   - Auto-healing with health checks
   - ~99.5% uptime (automatic VM recreation on failure)
   - Reserved static IP that persists across VM replacements
   - Cost-effective (~$7/month, same as original plan)

**What Changes**:
- ~~Headscale control plane~~ → **Direct WireGuard server on VM**
- ~~Tailscale clients~~ → **Standard WireGuard clients** (built into most OSes)
- ~~Mesh network~~ → **Star topology** (simpler, sufficient for our use case)
- ~~Manual VM management~~ → **MIG with auto-healing**
- ~~GKE migration path~~ → **VM remains long-term** (MIG provides production-grade reliability)

**What Stays the Same**:
- ✅ WireGuard encryption (ChaCha20-Poly1305)
- ✅ Subnet routing to AlloyDB and GKE
- ✅ ~$7/month cost
- ✅ Simple client setup
- ✅ Access to private AlloyDB and private GKE control plane

---

## ORIGINAL PLAN (2025-10-30) - PRESERVED FOR HISTORY

~~**This section documents the Tailscale/Headscale approach attempted on 2025-10-30.**~~
~~**We are pivoting away from this architecture. See "New Architecture" section below.**~~

## Implementation Progress (2025-10-30)

### ✅ Completed Steps:
1. **Org Policy Updates** - Added project-level exceptions for `pcc-prj-devops-nonprod` and `pcc-prj-devops-prod`:
   - `compute.vmExternalIpAccess`: Allow external IPs
   - `compute.vmCanIpForward`: Allow IP forwarding  
   - Method: Project-level overrides for vmExternalIpAccess, `under:` prefix for vmCanIpForward

2. **API Enablement** - Added to both devops projects:
   - `compute.googleapis.com`
   - `secretmanager.googleapis.com`

3. **VM Deployment** - Created `headscale-vm` in `pcc-prj-devops-nonprod`:
   - Machine: `e2-small`
   - Zone: `us-east4-a`
   - Subnet: `pcc-prj-devops-nonprod` (10.24.128.0/20)
   - Internal IP: `10.24.128.2`
   - External IP: `35.245.145.211`
   - Shielded VM with OS Login enabled

4. **Firewall Rules** - Created `allow-wireguard-headscale`:
   - Protocol: UDP port 41641
   - Source: `0.0.0.0/0`
   - Target tags: `headscale-vm`

5. **Headscale Deployment** - Container running successfully:
   - Version: v0.27.0
   - Config format: Updated to latest (prefixes.v4/v6, dns.nameservers.global)
   - Server URL: `http://35.245.145.211:8080`
   - User created: `pcc-dev` (ID: 1)

6. **Pre-auth Keys** - Generated and stored:
   - 3 keys with 1-year expiration (8760h)
   - Stored in Secret Manager:
     - `headscale-preauth-key-dev1`
     - `headscale-preauth-key-dev2`
     - `headscale-preauth-key-dev3`
   - Replication: user-managed, us-east4

7. **IAM Updates**:
   - Added `gcp-admins@pcconnect.ai` to foundation terraform state bucket
   - Role: `roles/storage.objectAdmin`
   - Enabled developer terraform operations without service account impersonation

8. **External IP Access Fix**:
   - Initial external IP: `35.245.145.211` blocked by iptables
   - Created new VM with external IP: `35.226.250.229`
   - Added iptables rules to accept traffic on port 8080
   - Made iptables rules persistent via systemd service
   - External access to Headscale confirmed working

9. **Tailscale VM Client Deployment**:
   - Deployed Tailscale client container on Headscale VM
   - Connected to Headscale at `http://localhost:8080`
   - Advertised route: `10.24.128.0/20` (AlloyDB PSC subnet)
   - Approved routes on Headscale server
   - Verified PSC endpoint (`10.24.128.3:5432`) reachable from container

10. **iptables FORWARD Chain Fix**:
    - Initial FORWARD policy: DROP (blocking packets over tailscale0)
    - Added FORWARD chain ACCEPT rules for tailscale0 interface
    - ICMP blocked by PSC endpoint (expected behavior)
    - TCP connectivity on port 5432 confirmed working

11. **NAS Deployment Attempt (FAILED)**:
    - Target: Synology NAS at `syno1621.rlgeex.servers` (192.168.74.19)
    - Container deployed but crash-looping due to iptables errors:
      ```
      iptables v1.8.11 (nf_tables): Could not fetch rule set generation id: Invalid argument
      ```
    - Root cause: Synology DSM blocks iptables manipulation for security
    - IP forwarding enabled on NAS (value: 1)
    - Conclusion: **NAS cannot act as subnet router** due to Synology firewall restrictions
    - Container stopped and removed

### 🚧 Next Steps:
- ~~Configure subnet routing to AlloyDB (10.28.0.0/20)~~ ✅ COMPLETE
- ~~Install Tailscale on VM for route advertisement~~ ✅ COMPLETE
- ~~Enable IP forwarding on VM~~ ✅ COMPLETE
- Deploy Tailscale client on WSL instance as gateway for local routing
- Configure WSL instance to advertise local subnet routes
- Test connectivity from WSL to AlloyDB via Tailscale
- Distribute keys to developers
- Validate AlloyDB access from developer machines

## Problem Statement

AlloyDB Auth Proxy only handles authentication and cannot connect from outside the VPC. Development team (3 developers: 2 co-located, 1 remote) needs immediate access to run Flyway migrations and ongoing database access for development.

**Requirements:**
- Short-term: Immediate solution for Flyway migrations (hours, not days)
- Long-term: Sustainable developer access pattern
- Simple client setup for remote developer
- Clear migration path from short-term to GKE-hosted solution
- Cost-effective (~$7/month)

## Expert Consensus

**Consulted**: Gemini (GCP expert) + Codex (DevOps expert)

**Both experts recommend**: WireGuard-based overlay network (Tailscale/Headscale)
- Modern cryptography (ChaCha20-Poly1305)
- Simple one-click client experience
- Low operational overhead
- Clean migration path from VM to GKE
- Cost: ~$7/month (vs $50/month for traditional VPN)

## Architectural Overview

### Short-Term Solution (Phase 2 - Immediate)

**Components:**
- Headscale control plane (self-hosted Tailscale) in Docker container on GCP VM
- VM: `e2-small` (2 vCPU, 2GB RAM) in `us-east4-a`, same VPC as AlloyDB
- IP forwarding enabled with subnet routing to AlloyDB subnet
- Tailscale clients on all 3 developer machines
- WireGuard mesh network (all outbound, no inbound firewall holes)

**Authentication**: Non-expiring pre-shared keys (stored in Secret Manager)

**Cost**: ~$7/month (e2-small VM + minimal egress)

### Long-Term Solution (Phase 3 - GKE Migration)

**Components:**
- Migrate Headscale container to GKE Autopilot using Tailscale Kubernetes operator
- Userspace WireGuard networking (Autopilot compatible)
- Google Workspace SSO via Headscale OIDC integration
- ACLs restricting access to PostgreSQL port 5432 only
- Retire short-term VM

**Authentication**: Google Workspace SSO with MFA

**Cost**: Same ~$7/month (absorbed into GKE cluster costs)

## Detailed Implementation

### WSL Gateway Deployment (Alternative to NAS)

**Problem**: Synology NAS cannot act as subnet router due to iptables restrictions in DSM.

**Solution**: Deploy Tailscale client directly on WSL instance to act as local gateway.

#### WSL Tailscale Client Setup

**Connection Parameters:**
```bash
# Headscale Server Details
LOGIN_SERVER="https://35.226.250.229:8080"
AUTH_KEY="692d2968570d19887620da78ffcc937c09fd9b2626af18d4"
PSC_SUBNET="10.24.128.0/20"
ALLOYDB_ENDPOINT="10.24.128.3"

# Connect to Headscale and advertise local subnet routes
tailscale up \
  --login-server=$LOGIN_SERVER \
  --authkey=$AUTH_KEY \
  --advertise-routes=$PSC_SUBNET \
  --accept-routes
```

**Key Configuration:**
- **Login Server**: `https://35.226.250.229:8080` (Headscale external IP)
- **Auth Key**: `692d2968570d19887620da78ffcc937c09fd9b2626af18d4` (Developer 2 key)
- **Advertised Routes**: `10.24.128.0/20` (AlloyDB PSC subnet)
- **Accept Routes**: Enabled to receive routes from VM subnet router

**Network Flow:**
1. WSL Tailscale client connects to Headscale at `35.226.250.229:8080`
2. Receives route to `10.24.128.0/20` from GCP VM subnet router
3. Local applications on WSL can access `10.24.128.3:5432` (AlloyDB) directly
4. Router policy-based routing can forward traffic to WSL gateway if needed

**Verification Steps:**
```bash
# Check Tailscale connection status
tailscale status

# Verify routes received
tailscale status | grep 10.24.128

# Test connectivity to AlloyDB PSC endpoint
nc -zv 10.24.128.3 5432

# Test database connection (if psql installed)
psql -h 10.24.128.3 -U postgres -d client_api_db
```

### Short-Term Deployment Steps (1 hour)

#### Step 1: Create GCP VM (10 minutes)

```bash
# Run from workstation
gcloud compute instances create headscale-vm \
  --zone=us-east4-a \
  --machine-type=e2-small \
  --image-family=cos-stable \
  --image-project=cos-cloud \
  --can-ip-forward \
  --network=<vpc-name> \
  --subnet=<subnet-name> \
  --service-account=<sa-email> \
  --tags=headscale-vm

# Create VPC firewall rule for WireGuard
gcloud compute firewall-rules create allow-wireguard-headscale \
  --network=<vpc-name> \
  --allow=udp:41641 \
  --source-ranges=0.0.0.0/0 \
  --target-tags=headscale-vm \
  --description="Allow WireGuard for Headscale VPN"
```

#### Step 2: Deploy Headscale Container (15 minutes)

```bash
# SSH to VM
gcloud compute ssh headscale-vm --zone=us-east4-a

# Create persistent directory structure
sudo mkdir -p /var/lib/headscale
sudo mkdir -p /etc/headscale

# Create Headscale configuration file
sudo tee /etc/headscale/config.yaml > /dev/null <<EOF
server_url: http://<VM-PRIVATE-IP>:8080
listen_addr: 0.0.0.0:8080
metrics_listen_addr: 0.0.0.0:9090
grpc_listen_addr: 0.0.0.0:50443

private_key_path: /var/lib/headscale/private.key
noise:
  private_key_path: /var/lib/headscale/noise_private.key

ip_prefixes:
  - fd7a:115c:a1e0::/48
  - 100.64.0.0/10

derp:
  server:
    enabled: false
  urls:
    - https://controlplane.tailscale.com/derpmap/default

database:
  type: sqlite3
  sqlite:
    path: /var/lib/headscale/db.sqlite

acme_url: ""
acme_email: ""
tls_cert_path: ""
tls_key_path: ""

log:
  level: info
  format: text

dns_config:
  nameservers:
    - 8.8.8.8
  magic_dns: true
  base_domain: pcc.internal

unix_socket: /var/run/headscale/headscale.sock
unix_socket_permission: "0770"
EOF

# Create systemd service for auto-restart
sudo tee /etc/systemd/system/headscale.service > /dev/null <<EOF
[Unit]
Description=Headscale VPN Control Server
After=docker.service
Requires=docker.service

[Service]
Type=simple
Restart=always
RestartSec=10
ExecStartPre=-/usr/bin/docker stop headscale
ExecStartPre=-/usr/bin/docker rm headscale
ExecStart=/usr/bin/docker run --rm --name headscale \\
  --net=host \\
  -v /var/lib/headscale:/var/lib/headscale \\
  -v /etc/headscale:/etc/headscale \\
  ghcr.io/juanfont/headscale:latest \\
  serve
ExecStop=/usr/bin/docker stop headscale

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the service
sudo systemctl daemon-reload
sudo systemctl enable headscale
sudo systemctl start headscale

# Wait for container to initialize
sleep 10

# Create namespace for team
sudo docker exec headscale headscale namespaces create pcc-dev

# Generate non-expiring pre-shared auth keys (one per developer)
echo "Developer 1 key:"
sudo docker exec headscale headscale preauthkeys create \
  --namespace pcc-dev \
  --reusable

echo "Developer 2 key:"
sudo docker exec headscale headscale preauthkeys create \
  --namespace pcc-dev \
  --reusable

echo "Developer 3 (remote) key:"
sudo docker exec headscale headscale preauthkeys create \
  --namespace pcc-dev \
  --reusable

# Save these keys - format: "preauthkey:abc123def456..."
```

#### Step 3: Configure Subnet Routing (10 minutes)

```bash
# Still on VM via SSH

# Get AlloyDB subnet CIDR (replace with actual)
ALLOYDB_SUBNET="<your-alloydb-subnet-cidr>"  # Example: 10.128.0.0/20

# Enable IP forwarding
echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.conf
echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Install Tailscale on VM to act as subnet router
curl -fsSL https://tailscale.com/install.sh | sh

# Connect VM to Headscale as subnet router
sudo tailscale up \
  --login-server=http://localhost:8080 \
  --auth-key=<one-of-the-preauth-keys> \
  --advertise-routes=$ALLOYDB_SUBNET \
  --accept-routes=false

# List nodes to find router node ID
sudo docker exec headscale headscale nodes list

# Approve advertised routes (replace NODE_ID)
sudo docker exec headscale headscale routes enable \
  --route=$ALLOYDB_SUBNET \
  --node=<NODE_ID>

# Verify routes enabled
sudo docker exec headscale headscale routes list
# Expected: Route: <ALLOYDB_SUBNET> | Node: headscale-vm | Enabled: true
```

#### Step 4: Store Keys in Secret Manager (5 minutes)

```bash
# Exit SSH, run from workstation

# Store pre-shared keys for safekeeping and WARP access
gcloud secrets create headscale-preauth-key-dev1 \
  --project=<project-id> \
  --replication-policy=user-managed \
  --locations=us-east4 \
  --data-file=<(echo "<key1>")

gcloud secrets create headscale-preauth-key-dev2 \
  --project=<project-id> \
  --replication-policy=user-managed \
  --locations=us-east4 \
  --data-file=<(echo "<key2>")

gcloud secrets create headscale-preauth-key-dev3 \
  --project=<project-id> \
  --replication-policy=user-managed \
  --locations=us-east4 \
  --data-file=<(echo "<key3>")
```

#### Step 5: Developer Client Setup (15 minutes per dev, parallel)

**Install Tailscale Client:**
- macOS: https://tailscale.com/download/mac or `brew install tailscale`
- Windows: https://tailscale.com/download/windows
- Linux: `curl -fsSL https://tailscale.com/install.sh | sh`

**Connect to Headscale:**
```bash
# Get VM private IP and auth key
VM_PRIVATE_IP="<vm-private-ip>"
AUTH_KEY="<preauth-key-from-secret-manager>"

tailscale up \
  --login-server=http://$VM_PRIVATE_IP:8080 \
  --auth-key=$AUTH_KEY \
  --accept-routes
```

**Verify Connectivity:**
```bash
# Check Tailscale status
tailscale status

# Test ping to AlloyDB
ping <alloydb-private-ip>

# Test database connection
psql -h <alloydb-private-ip> -U postgres -d client_api_db
```

**Run Flyway Migrations:**
```bash
cd src/pcc-client-api/PortfolioConnect.Client.Api/Migrations/Scripts/v1
flyway migrate -configFiles=flyway.conf
# Expected: 15 tables created in client_api_db
```

### Long-Term Migration Steps (Phase 3 - 2 hours)

#### Step 1: Deploy Headscale to GKE Autopilot (45 minutes)

**Prerequisites:**
- GKE Autopilot cluster deployed (Phase 3)
- kubectl configured with Connect Gateway access

**Create Kubernetes Resources:**

```yaml
# headscale-namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: vpn-system
  labels:
    name: vpn-system
```

```yaml
# headscale-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: headscale-config
  namespace: vpn-system
data:
  config.yaml: |
    server_url: https://vpn.pcc.internal
    listen_addr: 0.0.0.0:8080
    metrics_listen_addr: 0.0.0.0:9090
    grpc_listen_addr: 0.0.0.0:50443

    private_key_path: /var/lib/headscale/private.key
    noise:
      private_key_path: /var/lib/headscale/noise_private.key

    ip_prefixes:
      - fd7a:115c:a1e0::/48
      - 100.64.0.0/10

    derp:
      server:
        enabled: false
      urls:
        - https://controlplane.tailscale.com/derpmap/default

    database:
      type: sqlite3
      sqlite:
        path: /var/lib/headscale/db.sqlite

    log:
      level: info
      format: json

    dns_config:
      nameservers:
        - 8.8.8.8
      magic_dns: true
      base_domain: pcc.internal

    oidc:
      issuer: "https://accounts.google.com"
      client_id: "<workspace-oauth-client-id>"
      client_secret: "<workspace-oauth-client-secret>"
```

```yaml
# headscale-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: headscale
  namespace: vpn-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: headscale
  template:
    metadata:
      labels:
        app: headscale
    spec:
      serviceAccountName: headscale-sa
      containers:
      - name: headscale
        image: ghcr.io/juanfont/headscale:latest
        args: ["serve"]
        ports:
        - containerPort: 8080
          name: http
        - containerPort: 50443
          name: grpc
        - containerPort: 41641
          name: wireguard
          protocol: UDP
        volumeMounts:
        - name: config
          mountPath: /etc/headscale
        - name: data
          mountPath: /var/lib/headscale
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
        securityContext:
          runAsNonRoot: true
          runAsUser: 1000
          capabilities:
            add:
            - NET_ADMIN  # Required for userspace WireGuard
      volumes:
      - name: config
        configMap:
          name: headscale-config
      - name: data
        persistentVolumeClaim:
          claimName: headscale-data
```

```yaml
# headscale-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: headscale-data
  namespace: vpn-system
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: standard-rwo
```

```yaml
# headscale-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: headscale
  namespace: vpn-system
spec:
  type: LoadBalancer
  selector:
    app: headscale
  ports:
  - name: http
    port: 8080
    targetPort: 8080
    protocol: TCP
  - name: wireguard
    port: 41641
    targetPort: 41641
    protocol: UDP
```

**Deploy to GKE:**
```bash
kubectl apply -f headscale-namespace.yaml
kubectl apply -f headscale-configmap.yaml
kubectl apply -f headscale-pvc.yaml
kubectl apply -f headscale-deployment.yaml
kubectl apply -f headscale-service.yaml

# Wait for LoadBalancer IP
kubectl get svc headscale -n vpn-system -w

# Migrate SQLite database from VM
kubectl cp headscale-vm:/var/lib/headscale/db.sqlite \
  vpn-system/headscale-<pod-id>:/var/lib/headscale/db.sqlite
```

#### Step 2: Enable Google Workspace SSO (30 minutes)

**Configure Google Workspace OAuth:**
1. Go to Google Cloud Console → APIs & Services → Credentials
2. Create OAuth 2.0 Client ID (Web application)
3. Authorized redirect URIs: `https://vpn.pcc.internal/oidc/callback`
4. Copy Client ID and Client Secret
5. Update Headscale ConfigMap with OIDC settings
6. Restart Headscale deployment

**Recreate User Accounts with SSO:**
```bash
# Delete old pre-auth-based users
kubectl exec -n vpn-system headscale-<pod-id> -- \
  headscale nodes delete --identifier <old-node-id>

# Users will re-authenticate via Google Workspace
# No pre-auth keys needed - Workspace SSO handles authentication
```

**Developer Re-Connection:**
```bash
# Developers reconnect with new login server
tailscale up --login-server=https://vpn.pcc.internal

# Browser opens for Google Workspace authentication
# MFA enforced automatically via Workspace settings
```

#### Step 3: Implement ACLs (30 minutes)

**Update Headscale ConfigMap with ACL Policy:**

```yaml
# Add to headscale-configmap.yaml
data:
  acl.yaml: |
    groups:
      group:developers:
        - "*@portcon.com"

    tagOwners:
      tag:database-access:
        - group:developers

    acls:
      # Allow developers to access AlloyDB PostgreSQL port only
      - action: accept
        src:
          - group:developers
        dst:
          - tag:alloydb-subnet:5432

      # Deny all other traffic
      - action: deny
        src:
          - "*"
        dst:
          - "*"

    hosts:
      alloydb-subnet: <alloydb-subnet-cidr>
```

**Apply ACL Configuration:**
```bash
kubectl apply -f headscale-configmap.yaml
kubectl rollout restart deployment/headscale -n vpn-system

# Test ACL enforcement
psql -h <alloydb-ip> -p 5432  # Should work
nc -zv <alloydb-ip> 22         # Should be blocked
```

#### Step 4: Decommission Short-Term VM (15 minutes)

**Pre-Flight Checks:**
```bash
# Verify all clients connected to GKE Headscale
kubectl exec -n vpn-system headscale-<pod-id> -- \
  headscale nodes list

# Ensure 3 nodes registered with Workspace SSO
# Verify routes still advertised and enabled
```

**Delete VM:**
```bash
# Create VM snapshot for rollback safety
gcloud compute disks snapshot headscale-vm \
  --snapshot-names=headscale-vm-final-backup \
  --zone=us-east4-a

# Delete VM
gcloud compute instances delete headscale-vm \
  --zone=us-east4-a

# Clean up firewall rule
gcloud compute firewall-rules delete allow-wireguard-headscale
```

**Update Documentation:**
- Update `.claude/status/current-progress.md` with Phase 3 completion
- Document new login server: `https://vpn.pcc.internal`
- Update Flyway runbook with Workspace SSO instructions

## Security & Operations

### Security Posture

**Short-Term (Phase 2):**
- **Authentication**: Non-expiring pre-shared keys (stored in Secret Manager)
- **Encryption**: WireGuard ChaCha20-Poly1305 (modern, audited crypto)
- **Network**: No inbound firewall rules to AlloyDB (WireGuard is outbound-only)
- **Access Control**: Wide-open ACLs (all tailnet members can reach AlloyDB subnet)
- **Audit Trail**: Headscale logs all node connections, Cloud Logging for VM

**Long-Term (Phase 3):**
- **Authentication**: Google Workspace SSO via OIDC (MFA enforced)
- **ACLs**: Tag-based policies restricting access to PostgreSQL port 5432 only
- **Key Rotation**: Automated via Workspace SSO (no more pre-shared keys)
- **Monitoring**: Tailscale metrics + Cloud Monitoring alerts
- **Compliance**: All access tied to Google identities (audit-ready)

### Operational Tasks

**Weekly:**
- Review Headscale logs for anomalies
- Verify all 3 developers still connected

**Monthly (Short-Term):**
- Update Headscale container image on VM
- Test VM snapshot restore procedure

**Monthly (Long-Term):**
- Update Headscale deployment image
- Review and update ACL policies
- Audit Workspace SSO access logs

### Cost Breakdown

**Short-Term:**
- e2-small VM: ~$14/month (preemptible: ~$4/month with free tier)
- Network egress: ~$1-2/month (minimal for 3 devs)
- **Total**: ~$7/month

**Long-Term:**
- Same cost absorbed into GKE Autopilot cluster
- No additional dedicated resources needed

### Rollback Plan

**If GKE Migration Fails:**
1. Revert client `--login-server` to VM IP: `http://<vm-ip>:8080`
2. Restore VM from snapshot if deleted
3. Clients automatically reconnect to VM Headscale
4. Zero downtime possible with parallel testing

## Daily Developer Usage

**Connection (Automatic):**
- Tailscale runs in background, auto-connects on startup
- No manual VPN toggle needed
- Works on any network (office, home, hotel Wi-Fi)

**Database Access:**
```bash
# Use AlloyDB private IP directly in any tool
psql -h <alloydb-private-ip> -U postgres -d client_api_db

# DBeaver, DataGrip, etc. - just use private IP
```

**Flyway Migrations:**
```bash
cd src/pcc-client-api/PortfolioConnect.Client.Api/Migrations/Scripts/v1
flyway migrate -configFiles=flyway.conf
```

**Troubleshooting:**
```bash
# Check connection status
tailscale status

# Test mesh connectivity
tailscale ping <peer>

# Diagnose network issues
tailscale netcheck

# View Headscale logs (VM)
sudo docker logs headscale

# View Headscale logs (GKE)
kubectl logs -n vpn-system deployment/headscale
```

## Success Criteria

**Short-Term (Phase 2):**
- [ ] Headscale VM deployed and running
- [ ] All 3 developers successfully connected to tailnet
- [ ] Developers can ping AlloyDB private IP
- [ ] Flyway migrations execute successfully (15 tables created)
- [ ] Pre-shared keys stored in Secret Manager

**Long-Term (Phase 3):**
- [ ] Headscale migrated to GKE Autopilot
- [ ] Google Workspace SSO enabled and tested
- [ ] ACLs restricting access to port 5432 only
- [ ] All developers re-authenticated via Workspace
- [ ] Short-term VM decommissioned
- [ ] Documentation updated

## Lessons Learned (2025-10-30)

### Synology NAS Limitations
**Issue**: Tailscale container on Synology NAS cannot function as subnet router.

**Root Cause**:
- Synology DSM blocks iptables manipulation for security
- Error: `iptables v1.8.11 (nf_tables): Could not fetch rule set generation id: Invalid argument`
- IP forwarding enabled but insufficient without iptables control

**Impact**: NAS cannot forward packets between local network and Tailscale VPN, making policy-based routing to NAS gateway ineffective.

**Solution**: Use WSL instance or dedicated Linux VM with full iptables control as subnet router gateway.

### iptables FORWARD Chain Critical for VPN Routing
**Issue**: Initial Tailscale deployment had working connection but couldn't route to PSC endpoints.

**Root Cause**:
- Default iptables FORWARD policy: DROP
- Tailscale0 interface packets were being dropped at FORWARD chain

**Fix**:
```bash
iptables -I FORWARD -i tailscale0 -j ACCEPT
iptables -I FORWARD -o tailscale0 -j ACCEPT
```

**Lesson**: Always verify FORWARD chain policy and rules when deploying VPN subnet routers.

### PSC Endpoints Block ICMP
**Issue**: Ping to AlloyDB PSC endpoint (`10.24.128.3`) failed even after routing fixed.

**Root Cause**: Private Service Connect endpoints block ICMP by design.

**Verification**: Use TCP connectivity tests instead:
```bash
nc -zv 10.24.128.3 5432  # Works
ping 10.24.128.3         # Fails (expected)
```

### External IP Access Requires iptables Rules
**Issue**: Headscale VM with external IP wasn't accessible from internet.

**Root Cause**: VM-level iptables dropping traffic on port 8080 before GCP firewall rules applied.

**Fix**:
```bash
iptables -I INPUT -p tcp --dport 8080 -j ACCEPT
```

**Persistence**: Created systemd service to restore rules on boot.

### Headscale Route Approval Required
**Issue**: Advertised routes weren't propagating to clients.

**Root Cause**: Headscale requires explicit route approval for security.

**Fix**:
```bash
docker exec headscale headscale routes list
docker exec headscale headscale routes enable --route=10.24.128.0/20 --node=<node-id>
```

**Lesson**: Always check and approve routes after advertising them.

## References

**Expert Recommendations:**
- Gemini: Identity-Aware Proxy, Managed VPN, BeyondCorp analysis
- Codex: Tailscale/Headscale, HA Cloud VPN, strongSwan comparison
- **Consensus**: WireGuard-based overlay (Tailscale/Headscale) for optimal balance

**Documentation:**
- Headscale: https://github.com/juanfont/headscale
- Tailscale: https://tailscale.com/kb/
- WireGuard Protocol: https://www.wireguard.com/
- GKE Autopilot Networking: https://cloud.google.com/kubernetes-engine/docs/concepts/autopilot-networking

**Related Plans:**
- `.claude/plans/devtest-deployment/phase-2.*` - AlloyDB deployment
- `.claude/plans/devtest-deployment/phase-3.*` - GKE Autopilot deployment

**Key Configuration Values:**
- **Headscale External IP**: `35.226.250.229:8080`
- **Auth Key (Developer 2)**: `692d2968570d19887620da78ffcc937c09fd9b2626af18d4`
- **AlloyDB PSC Subnet**: `10.24.128.0/20`
- **AlloyDB PSC Endpoint**: `10.24.128.3:5432`

---

# NEW ARCHITECTURE - Native WireGuard with MIG (2025-10-31)

## Problem Statement (Updated)

Development team needs secure access to **two private GCP resources**:
1. **AlloyDB** - Private database cluster (PSC endpoint: `10.24.128.3:5432`)
2. **GKE Control Plane** - Private Autopilot cluster (control plane subnet TBD)

**Requirements:**
- Production-grade uptime (~99.5%+) for daily development work
- Simple client setup (3 developers: 2 co-located, 1 remote)
- Access from any network (office, home, travel)
- Cost-effective (~$7/month)
- No complex control plane management
- No dependency on GKE for VPN infrastructure

## Architecture Overview

### Network Topology

```
[Developer Laptops]                    [GCP VPC - us-east4]
       |                                      |
       | WireGuard Tunnel                     |
       | (UDP 51820)                          |
       |                                      |
       v                                      v
[WireGuard VM] <------ Subnet Routing -----> [AlloyDB PSC: 10.24.128.3]
   (MIG)                                      [GKE Control Plane: TBD]
   Static IP
   Auto-healing
```

**Flow**:
1. Developer WireGuard client connects to VM's static external IP (UDP 51820)
2. VM acts as subnet router, forwarding packets to:
   - AlloyDB PSC subnet: `10.24.128.0/20`
   - GKE control plane subnet: TBD (will be determined during Phase 3)
3. Return traffic routes back through VM to developer's WireGuard tunnel

### Components

#### 1. WireGuard Server VM (Managed Instance Group)
- **Machine Type**: `e2-small` (2 vCPU, 2GB RAM)
- **Location**: `us-east4-a` (same region as AlloyDB/GKE)
- **Image**: Ubuntu 22.04 LTS (or Container-Optimized OS with WireGuard container)
- **Networking**:
  - VPC: Same VPC as AlloyDB and GKE
  - Subnet: `pcc-prj-devops-nonprod` subnet (`10.24.128.0/20`)
  - External IP: **Reserved static IP** (survives VM replacement)
  - Internal IP: Ephemeral (auto-assigned)
  - IP Forwarding: **Enabled** (`--can-ip-forward`)
- **High Availability**:
  - Managed Instance Group (size: 1)
  - Health check: UDP port 51820 (WireGuard handshake)
  - Auto-healing: 2-5 minute recovery on failure
- **Storage**:
  - WireGuard private key stored in **Secret Manager**
  - Peer configs generated from Secret Manager at boot
  - No persistent disk needed (stateless)

#### 2. WireGuard Clients (Developer Machines)
- **Platforms**: macOS, Windows, Linux
- **Installation**: Native WireGuard client (no third-party dependencies)
- **Configuration**: Single `.conf` file per developer
- **Authentication**: Pre-shared keys (PSK) for each developer

#### 3. Firewall Rules
- **Ingress**: UDP 51820 from `0.0.0.0/0` to VM (tagged: `wireguard-server`)
- **Egress**: Allow VM to reach AlloyDB PSC subnet and GKE control plane subnet

#### 4. Secret Manager
- **Secrets Stored**:
  - `wireguard-server-private-key` - Server's WireGuard private key
  - `wireguard-peer-1-public-key` - Developer 1 public key
  - `wireguard-peer-2-public-key` - Developer 2 public key
  - `wireguard-peer-3-public-key` - Developer 3 (remote) public key
  - `wireguard-peer-1-psk` - Developer 1 pre-shared key
  - `wireguard-peer-2-psk` - Developer 2 pre-shared key
  - `wireguard-peer-3-psk` - Developer 3 pre-shared key
- **Replication**: `us-east4` (user-managed)

## Detailed Implementation Plan

### Phase 1: Initial Deployment (2 hours)

#### Step 1: Cleanup Existing Headscale VM (15 minutes)

**What to Remove**:
- Headscale VM at `35.226.250.229` (IP will be released)
- Headscale container and configurations
- Tailscale client on VM
- Firewall rule: `allow-wireguard-headscale` (UDP 41641)
- Secrets in Secret Manager:
  - `headscale-preauth-key-dev1`
  - `headscale-preauth-key-dev2`
  - `headscale-preauth-key-dev3`

**Commands**:
```bash
# Stop and remove Headscale/Tailscale services
gcloud compute ssh headscale-vm --zone=us-east4-a --command="
sudo systemctl stop headscale
sudo systemctl disable headscale
sudo docker stop headscale
sudo docker rm headscale
sudo tailscale down
"

# Delete the VM
gcloud compute instances delete headscale-vm \
  --zone=us-east4-a \
  --quiet

# Delete firewall rule
gcloud compute firewall-rules delete allow-wireguard-headscale --quiet

# Delete old secrets
gcloud secrets delete headscale-preauth-key-dev1 --quiet
gcloud secrets delete headscale-preauth-key-dev2 --quiet
gcloud secrets delete headscale-preauth-key-dev3 --quiet
```

**What to Keep**:
- Org policies (already configured for `compute.vmExternalIpAccess` and `compute.vmCanIpForward`)
- Enabled APIs (`compute.googleapis.com`, `secretmanager.googleapis.com`)
- VPC and subnets

#### Step 2: Reserve Static IP (5 minutes)

```bash
# Reserve external IP for WireGuard server
gcloud compute addresses create wireguard-vpn-ip \
  --region=us-east4 \
  --project=pcc-prj-devops-nonprod

# Get the reserved IP
WG_EXTERNAL_IP=$(gcloud compute addresses describe wireguard-vpn-ip \
  --region=us-east4 \
  --project=pcc-prj-devops-nonprod \
  --format="value(address)")

echo "Reserved IP: $WG_EXTERNAL_IP"
```

#### Step 3: Generate WireGuard Keys (10 minutes)

**On your workstation**:
```bash
# Install WireGuard tools (if not already installed)
sudo apt install wireguard-tools  # Ubuntu/Debian
brew install wireguard-tools      # macOS

# Generate server keypair
wg genkey | tee server_private.key | wg pubkey > server_public.key

# Generate peer keypairs (one per developer)
for i in {1..3}; do
  wg genkey | tee peer${i}_private.key | wg pubkey > peer${i}_public.key
  wg genpsk > peer${i}_psk.key
done

# Display server public key (needed for client configs)
cat server_public.key

# Store server private key in Secret Manager
gcloud secrets create wireguard-server-private-key \
  --project=pcc-prj-devops-nonprod \
  --replication-policy=user-managed \
  --locations=us-east4 \
  --data-file=server_private.key

# Store peer public keys and PSKs
for i in {1..3}; do
  gcloud secrets create wireguard-peer-${i}-public-key \
    --project=pcc-prj-devops-nonprod \
    --replication-policy=user-managed \
    --locations=us-east4 \
    --data-file=peer${i}_public.key
  
  gcloud secrets create wireguard-peer-${i}-psk \
    --project=pcc-prj-devops-nonprod \
    --replication-policy=user-managed \
    --locations=us-east4 \
    --data-file=peer${i}_psk.key
done

# Securely delete local key files after storing
shred -u server_private.key peer*_private.key peer*_public.key peer*_psk.key
```

#### Step 3a: Create Service Account with IAM Roles (5 minutes)

**Create service account with required permissions**:
```bash
# Create service account
gcloud iam service-accounts create wireguard-vpn-sa \
  --project=pcc-prj-devops-nonprod \
  --display-name="WireGuard VPN Server"

SA_EMAIL="wireguard-vpn-sa@pcc-prj-devops-nonprod.iam.gserviceaccount.com"

# Grant Secret Manager access (to fetch WireGuard keys)
gcloud projects add-iam-policy-binding pcc-prj-devops-nonprod \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/secretmanager.secretAccessor"

# Grant Cloud Logging write access (for structured logging)
gcloud projects add-iam-policy-binding pcc-prj-devops-nonprod \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/logging.logWriter"

# Grant Compute Instance Admin (for VPC route creation at boot)
gcloud projects add-iam-policy-binding pcc-prj-devops-nonprod \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/compute.instanceAdmin.v1"
```

**Required IAM roles explained**:
- `roles/secretmanager.secretAccessor`: VM fetches private keys and PSKs from Secret Manager during bootstrap
- `roles/logging.logWriter`: Startup script sends structured logs to Cloud Logging via `logger` command
- `roles/compute.instanceAdmin.v1`: VM creates VPC routes for return traffic from AlloyDB/GKE subnets (see startup script lines 1304-1322)

**Note**: Using `--scopes=https://www.googleapis.com/auth/cloud-platform` in instance template (Step 6) grants these permissions to the VM.

#### Step 4: Create Startup Script (20 minutes)

**Create `wireguard-startup.sh`** (incorporating Gemini + Codex review fixes):
```bash
#!/bin/bash
set -euo pipefail

# Structured logging setup - redirect STDOUT to Cloud Logging
# STDERR stays separate for secret handling (not logged)
exec 1> >(logger -t wireguard-bootstrap -p info)

echo "Starting WireGuard VPN server bootstrap"

# Variables
PROJECT_ID="pcc-prj-devops-nonprod"
WG_INTERFACE="wg0"
WG_PORT="51820"
WG_SUBNET="10.100.0.0/24"  # WireGuard tunnel subnet
ALLOYDB_SUBNET="10.24.128.0/20"
GKE_SUBNET="TBD"  # Will be filled in during Phase 3

# Install gcloud CLI (required for Secret Manager access)
if ! command -v gcloud &> /dev/null; then
  echo "Installing gcloud CLI..."
  curl -sSL https://sdk.cloud.google.com | bash -s -- --disable-prompts --install-dir=/opt
  export PATH="/opt/google-cloud-sdk/bin:$PATH"
fi

# Install WireGuard
if ! command -v wg &> /dev/null; then
  echo "Installing WireGuard..."
  apt-get update
  apt-get install -y wireguard
fi

# Enable IP forwarding (idempotent)
if ! grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf; then
  echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
fi
if ! grep -q "^net.ipv6.conf.all.forwarding=1" /etc/sysctl.conf; then
  echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf
fi
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv6.conf.all.forwarding=1
echo "IP forwarding enabled: $(sysctl -n net.ipv4.ip_forward)"

# Secret Manager fetch with retry logic
# CRITICAL: Only output secret to STDOUT, send status to STDERR (not logged)
fetch_secret() {
  local secret_name=$1
  local max_attempts=5
  local attempt=1

  while [ $attempt -le $max_attempts ]; do
    if secret_value=$(gcloud secrets versions access latest \
         --secret="$secret_name" \
         --project="$PROJECT_ID" 2>/tmp/secret-error.log); then
      echo "Secret Manager fetch successful: $secret_name" >&2
      echo "$secret_value"  # Only output secret to STDOUT
      return 0
    fi

    echo "Secret Manager fetch failed for $secret_name (attempt $attempt/$max_attempts): $(cat /tmp/secret-error.log)" >&2

    attempt=$((attempt + 1))
    sleep $((2 ** attempt))  # Exponential backoff: 4s, 8s, 16s, 32s
  done

  echo "CRITICAL: Secret Manager fetch failed for $secret_name after $max_attempts attempts" >&2
  exit 1
}

# Fetch server private key from Secret Manager
echo "Fetching WireGuard server private key..."
SERVER_PRIVATE_KEY=$(fetch_secret "wireguard-server-private-key")

# Fetch peer public keys and PSKs
echo "Fetching peer configurations..."
PEER1_PUBLIC_KEY=$(fetch_secret "wireguard-peer-1-public-key")
PEER1_PSK=$(fetch_secret "wireguard-peer-1-psk")
PEER2_PUBLIC_KEY=$(fetch_secret "wireguard-peer-2-public-key")
PEER2_PSK=$(fetch_secret "wireguard-peer-2-psk")
PEER3_PUBLIC_KEY=$(fetch_secret "wireguard-peer-3-public-key")
PEER3_PSK=$(fetch_secret "wireguard-peer-3-psk")

# Create WireGuard configuration
echo "Creating WireGuard configuration..."
cat > /etc/wireguard/$WG_INTERFACE.conf <<EOF
[Interface]
PrivateKey = $SERVER_PRIVATE_KEY
Address = 10.100.0.1/24
ListenPort = $WG_PORT

# Peer 1 (Developer 1)
[Peer]
PublicKey = $PEER1_PUBLIC_KEY
PresharedKey = $PEER1_PSK
AllowedIPs = 10.100.0.10/32

# Peer 2 (Developer 2)
[Peer]
PublicKey = $PEER2_PUBLIC_KEY
PresharedKey = $PEER2_PSK
AllowedIPs = 10.100.0.11/32

# Peer 3 (Developer 3 - Remote)
[Peer]
PublicKey = $PEER3_PUBLIC_KEY
PresharedKey = $PEER3_PSK
AllowedIPs = 10.100.0.12/32
EOF

chmod 600 /etc/wireguard/$WG_INTERFACE.conf
echo "WireGuard configuration created"

# Install iptables-persistent (non-interactive)
echo "Installing iptables-persistent..."
DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent

# Rate limiting - block more than 30 new connections per minute from single IP
echo "Configuring rate limiting..."
if ! iptables -C INPUT -p udp --dport 51820 -m state --state NEW \
     -m recent --set --name wireguard_rate_limit 2>/dev/null; then
  iptables -A INPUT -p udp --dport 51820 -m state --state NEW \
    -m recent --set --name wireguard_rate_limit
fi
if ! iptables -C INPUT -p udp --dport 51820 -m state --state NEW \
     -m recent --update --seconds 60 --hitcount 30 \
     --name wireguard_rate_limit -j DROP 2>/dev/null; then
  iptables -A INPUT -p udp --dport 51820 -m state --state NEW \
    -m recent --update --seconds 60 --hitcount 30 \
    --name wireguard_rate_limit -j DROP
fi

# Start WireGuard (before adding forwarding rules to avoid exposure window)
echo "Starting WireGuard service..."
systemctl enable wg-quick@$WG_INTERFACE
systemctl start wg-quick@$WG_INTERFACE
echo "WireGuard interface created: $(ip link show wg0)"

# Configure iptables for NAT and forwarding (using SNAT instead of MASQUERADE)
echo "Configuring NAT and forwarding..."
VM_INTERNAL_IP=$(hostname -I | awk '{print $1}')
EGRESS_INTERFACE=$(ip route get 8.8.8.8 | grep -oP 'dev \K\S+')  # Dynamically detect egress interface

# Add SNAT rule if not already present
if ! iptables -t nat -C POSTROUTING -s $WG_SUBNET -o $EGRESS_INTERFACE -j SNAT --to-source $VM_INTERNAL_IP 2>/dev/null; then
  iptables -t nat -A POSTROUTING -s $WG_SUBNET -o $EGRESS_INTERFACE -j SNAT --to-source $VM_INTERNAL_IP
fi

# Scoped forwarding rules (only allow WireGuard subnet to AlloyDB/GKE)
if ! iptables -C FORWARD -i $WG_INTERFACE -s $WG_SUBNET -d $ALLOYDB_SUBNET -j ACCEPT 2>/dev/null; then
  iptables -A FORWARD -i $WG_INTERFACE -s $WG_SUBNET -d $ALLOYDB_SUBNET -j ACCEPT
fi
if ! iptables -C FORWARD -o $WG_INTERFACE -s $ALLOYDB_SUBNET -d $WG_SUBNET -j ACCEPT 2>/dev/null; then
  iptables -A FORWARD -o $WG_INTERFACE -s $ALLOYDB_SUBNET -d $WG_SUBNET -j ACCEPT
fi
# GKE rules will be added when GKE_SUBNET is known

# Make iptables rules persistent
netfilter-persistent save

# Create VPC route for return traffic (requires compute.networkAdmin role)
echo "Creating VPC route for return traffic..."
INSTANCE_NAME=$(hostname)
ZONE=$(curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/zone -s | cut -d'/' -f4)
NETWORK_NAME="pcc-network-nonprod"

# Delete old route if exists (from previous instance)
gcloud compute routes delete "route-to-vpn-from-${INSTANCE_NAME}" \
  --project="$PROJECT_ID" \
  --quiet || true

# Create new route
gcloud compute routes create "route-to-vpn-from-${INSTANCE_NAME}" \
  --project="$PROJECT_ID" \
  --network="$NETWORK_NAME" \
  --destination-range="10.100.0.0/24" \
  --next-hop-instance="$INSTANCE_NAME" \
  --next-hop-instance-zone="$ZONE" \
  --priority=1000

echo "WireGuard server setup complete - ready for client connections"
```

#### Step 5: Create Firewall Rule (5 minutes)

```bash
gcloud compute firewall-rules create allow-wireguard-vpn \
  --project=pcc-prj-devops-nonprod \
  --network=<vpc-name> \
  --allow=udp:51820 \
  --source-ranges=0.0.0.0/0 \
  --target-tags=wireguard-server \
  --description="Allow WireGuard VPN connections"
```

#### Step 6: Create Instance Template (15 minutes)

```bash
# Get the reserved IP address
WG_EXTERNAL_IP=$(gcloud compute addresses describe wireguard-vpn-ip \
  --region=us-east4 \
  --project=pcc-prj-devops-nonprod \
  --format="value(address)")

# Create instance template
gcloud compute instance-templates create wireguard-vpn-template \
  --project=pcc-prj-devops-nonprod \
  --machine-type=e2-small \
  --image-family=ubuntu-2204-lts \
  --image-project=ubuntu-os-cloud \
  --boot-disk-size=10GB \
  --boot-disk-type=pd-standard \
  --can-ip-forward \
  --network=<vpc-name> \
  --subnet=<subnet-name> \
  --region=us-east4 \
  --tags=wireguard-server \
  --service-account=<sa-email> \
  --scopes=https://www.googleapis.com/auth/cloud-platform \
  --metadata-from-file=startup-script=wireguard-startup.sh \
  --shielded-secure-boot \
  --shielded-vtpm \
  --shielded-integrity-monitoring
```

#### Step 7: Create Health Check (10 minutes)

**Note**: UDP health checks are tricky. We'll use a TCP health check on a lightweight HTTP server that validates WireGuard is running.

**Add to startup script** (`wireguard-startup.sh`):
```bash
# Install simple HTTP health check endpoint
apt-get install -y python3

# Create health check script
cat > /usr/local/bin/wg-health-check.py <<'EOF'
#!/usr/bin/env python3
from http.server import HTTPServer, BaseHTTPRequestHandler
import subprocess

class HealthCheckHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/health":
            try:
                # Check if WireGuard interface is up
                result = subprocess.run(['wg', 'show', 'wg0'], 
                                        capture_output=True, 
                                        timeout=2)
                if result.returncode == 0:
                    self.send_response(200)
                    self.end_headers()
                    self.wfile.write(b"OK")
                else:
                    self.send_response(503)
                    self.end_headers()
            except Exception:
                self.send_response(503)
                self.end_headers()
        else:
            self.send_response(404)
            self.end_headers()
    
    def log_message(self, format, *args):
        pass  # Suppress logs

if __name__ == "__main__":
    server = HTTPServer(('0.0.0.0', 8080), HealthCheckHandler)
    server.serve_forever()
EOF

chmod +x /usr/local/bin/wg-health-check.py

# Create systemd service for health check
cat > /etc/systemd/system/wg-health-check.service <<EOF
[Unit]
Description=WireGuard Health Check Server
After=wg-quick@wg0.service
Requires=wg-quick@wg0.service

[Service]
ExecStart=/usr/local/bin/wg-health-check.py
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl enable wg-health-check
systemctl start wg-health-check
```

**Create health check**:
```bash
gcloud compute health-checks create http wireguard-health-check \
  --project=pcc-prj-devops-nonprod \
  --port=8080 \
  --request-path=/health \
  --check-interval=30s \
  --timeout=10s \
  --unhealthy-threshold=3 \
  --healthy-threshold=2
```

**Update firewall** to allow health check traffic:
```bash
gcloud compute firewall-rules create allow-health-check-to-wireguard \
  --project=pcc-prj-devops-nonprod \
  --network=<vpc-name> \
  --allow=tcp:8080 \
  --source-ranges=35.191.0.0/16,130.211.0.0/22 \
  --target-tags=wireguard-server \
  --description="Allow Google Cloud health checks to WireGuard VMs"
```

#### Step 8: Create Managed Instance Group (15 minutes)

```bash
# Create MIG with size 1 and auto-healing
gcloud compute instance-groups managed create wireguard-vpn-mig \
  --project=pcc-prj-devops-nonprod \
  --base-instance-name=wireguard-vpn \
  --template=wireguard-vpn-template \
  --size=1 \
  --zone=us-east4-a \
  --health-check=wireguard-health-check \
  --initial-delay=300

# Wait for instance to be created
echo "Waiting for instance to be created and healthy..."
sleep 60

# Get the instance name
INSTANCE_NAME=$(gcloud compute instance-groups managed list-instances wireguard-vpn-mig \
  --zone=us-east4-a \
  --project=pcc-prj-devops-nonprod \
  --format="value(instance)")

echo "Instance created: $INSTANCE_NAME"

# Assign the reserved static IP to the instance
# Note: For MIG, we need to use access configs
gcloud compute instances delete-access-config $INSTANCE_NAME \
  --zone=us-east4-a \
  --project=pcc-prj-devops-nonprod \
  --access-config-name="external-nat"

gcloud compute instances add-access-config $INSTANCE_NAME \
  --zone=us-east4-a \
  --project=pcc-prj-devops-nonprod \
  --access-config-name="external-nat" \
  --address=$WG_EXTERNAL_IP

echo "Static IP $WG_EXTERNAL_IP assigned to instance"
```

**Important MIG Note**: Static IP assignment to MIG instances requires a different approach. Better solution:

**Alternative (Recommended)**: Use a **regional MIG with Network Load Balancer** that has the static IP:

```bash
# Create regional MIG
gcloud compute instance-groups managed create wireguard-vpn-mig \
  --project=pcc-prj-devops-nonprod \
  --base-instance-name=wireguard-vpn \
  --template=wireguard-vpn-template \
  --size=1 \
  --region=us-east4 \
  --health-check=wireguard-health-check \
  --initial-delay=300

# Create backend service for UDP load balancing
gcloud compute backend-services create wireguard-backend \
  --project=pcc-prj-devops-nonprod \
  --protocol=UDP \
  --health-checks=wireguard-health-check \
  --region=us-east4

# Add MIG to backend service
gcloud compute backend-services add-backend wireguard-backend \
  --project=pcc-prj-devops-nonprod \
  --instance-group=wireguard-vpn-mig \
  --instance-group-region=us-east4 \
  --region=us-east4

# Create forwarding rule with static IP
gcloud compute forwarding-rules create wireguard-forwarding-rule \
  --project=pcc-prj-devops-nonprod \
  --region=us-east4 \
  --address=wireguard-vpn-ip \
  --ip-protocol=UDP \
  --ports=51820 \
  --backend-service=wireguard-backend

echo "WireGuard VPN is now accessible at $WG_EXTERNAL_IP:51820"
```

#### Step 9: Generate Client Configurations (15 minutes)

**For each developer, create a `.conf` file**:

**Developer 1 - `wg-client-dev1.conf`**:
```ini
[Interface]
PrivateKey = <peer1_private_key from Step 3>
Address = 10.100.0.10/32
DNS = 8.8.8.8

[Peer]
PublicKey = <server_public_key from Step 3>
PresharedKey = <peer1_psk from Step 3>
Endpoint = <WG_EXTERNAL_IP>:51820
AllowedIPs = 10.24.128.0/20, 10.100.0.0/24
# Add GKE control plane subnet here in Phase 3
PersistentKeepalive = 25
```

**Developer 2 - `wg-client-dev2.conf`**:
```ini
[Interface]
PrivateKey = <peer2_private_key from Step 3>
Address = 10.100.0.11/32
DNS = 8.8.8.8

[Peer]
PublicKey = <server_public_key from Step 3>
PresharedKey = <peer2_psk from Step 3>
Endpoint = <WG_EXTERNAL_IP>:51820
AllowedIPs = 10.24.128.0/20, 10.100.0.0/24
PersistentKeepalive = 25
```

**Developer 3 - `wg-client-dev3.conf`**:
```ini
[Interface]
PrivateKey = <peer3_private_key from Step 3>
Address = 10.100.0.12/32
DNS = 8.8.8.8

[Peer]
PublicKey = <server_public_key from Step 3>
PresharedKey = <peer3_psk from Step 3>
Endpoint = <WG_EXTERNAL_IP>:51820
AllowedIPs = 10.24.128.0/20, 10.100.0.0/24
PersistentKeepalive = 25
```

**Distribute securely**:
```bash
# Option 1: Store in Secret Manager for WARP retrieval
for i in {1..3}; do
  gcloud secrets create wireguard-client-config-dev${i} \
    --project=pcc-prj-devops-nonprod \
    --replication-policy=user-managed \
    --locations=us-east4 \
    --data-file=wg-client-dev${i}.conf
done

# Option 2: Send via encrypted email/1Password/LastPass
# DO NOT send in plaintext!
```

#### Step 10: Developer Client Setup (10 minutes per dev)

**Install WireGuard Client**:
- **macOS**: `brew install wireguard-tools` or https://www.wireguard.com/install/
- **Windows**: https://www.wireguard.com/install/
- **Linux**: `sudo apt install wireguard` (Ubuntu/Debian)

**Import Configuration**:
1. Open WireGuard app
2. Import tunnel from file: `wg-client-dev1.conf`
3. Activate tunnel

**Verify Connectivity**:
```bash
# Check tunnel status
wg show

# Test connectivity to AlloyDB PSC endpoint
nc -zv 10.24.128.3 5432
# Expected: Connection to 10.24.128.3 5432 port [tcp/postgresql] succeeded!

# Test database connection
psql -h 10.24.128.3 -U postgres -d client_api_db
```

**Run Flyway Migrations**:
```bash
cd src/pcc-client-api/PortfolioConnect.Client.Api/Migrations/Scripts/v1
flyway migrate -configFiles=flyway.conf
# Expected: 15 tables created in client_api_db
```

### Phase 2: GKE Control Plane Access (During Phase 3 Deployment)

**When GKE Autopilot cluster is deployed**:

1. **Identify GKE control plane subnet**:
```bash
# Get cluster details
gcloud container clusters describe <cluster-name> \
  --region=us-east4 \
  --project=pcc-prj-devops-nonprod \
  --format="value(privateClusterConfig.masterIpv4CidrBlock)"

# Example output: 172.16.0.0/28
GKE_CONTROL_PLANE_SUBNET="172.16.0.0/28"
```

2. **Update WireGuard server to advertise GKE subnet**:
   - No changes needed on server (routing is automatic via VPC)
   - VM can already reach GKE control plane if in same VPC

3. **Update client configurations**:
   - Add GKE control plane subnet to `AllowedIPs`:
   ```ini
   AllowedIPs = 10.24.128.0/20, 172.16.0.0/28, 10.100.0.0/24
   ```

4. **Test kubectl access**:
```bash
# Configure kubectl to use private endpoint
gcloud container clusters get-credentials <cluster-name> \
  --region=us-east4 \
  --project=pcc-prj-devops-nonprod \
  --internal-ip

# Test cluster access
kubectl cluster-info
kubectl get nodes
```

## High Availability Details

### MIG Auto-Healing Behavior

**Health Check Failure Scenarios**:
1. VM crashes → Health check fails → MIG deletes and recreates VM (2-5 min)
2. WireGuard service stops → Health check fails → MIG recreates VM
3. Network partition → Health check fails → MIG recreates VM

**Static IP Persistence**:
- With Network Load Balancer approach: Static IP **always** points to healthy backend
- Clients reconnect automatically when new VM is healthy
- Max downtime: ~2-5 minutes (time to recreate VM + start WireGuard)

**Zero-Downtime Updates**:
- Update instance template with new startup script
- Rolling update: MIG creates new instance → waits for health check → deletes old instance

```bash
# Update template
gcloud compute instance-templates create wireguard-vpn-template-v2 \
  --source-instance-template=wireguard-vpn-template \
  --metadata-from-file=startup-script=wireguard-startup-v2.sh

# Rolling update
gcloud compute instance-groups managed rolling-action start-update wireguard-vpn-mig \
  --version=template=wireguard-vpn-template-v2 \
  --region=us-east4
```

### Monitoring & Alerts

**Cloud Monitoring Metrics**:
```bash
# Create alert for VM down
gcloud alpha monitoring policies create \
  --notification-channels=<channel-id> \
  --display-name="WireGuard VM Down" \
  --condition-display-name="Instance count = 0" \
  --condition-threshold-value=1 \
  --condition-threshold-duration=300s
```

**Log Queries** (Cloud Logging):
```sql
-- WireGuard connection logs
resource.type="gce_instance"
resource.labels.instance_id=~"wireguard-vpn-.*"
jsonPayload.message=~".*WireGuard.*"

-- Health check failures
resource.type="gce_instance"
jsonPayload.healthState="UNHEALTHY"
```

## Security Considerations

### Authentication & Encryption
- **Encryption**: WireGuard ChaCha20-Poly1305 (modern, post-quantum resistant)
- **Authentication**: Public key + Pre-shared key (defense in depth)
- **Key Storage**: Server private key in Secret Manager (encrypted at rest)
- **Key Rotation**: Manual process (regenerate keys, update Secret Manager, roll MIG)

### Network Segmentation
- WireGuard clients can ONLY access:
  - AlloyDB PSC subnet: `10.24.128.0/20`
  - GKE control plane subnet: `172.16.0.0/28`
  - WireGuard tunnel subnet: `10.100.0.0/24`
- No access to other VPC subnets (enforced by client `AllowedIPs`)

### Audit Trail
- WireGuard handshakes logged to Cloud Logging
- Database queries logged by AlloyDB
- kubectl commands logged by GKE Audit Logs
- All access tied to individual developer keys (non-repudiation)

### Firewall Defense
- Only UDP 51820 exposed to internet
- No SSH exposed (use IAP for admin access)
- AlloyDB has no public IP (only PSC)
- GKE control plane has no public IP (only private endpoint)

## Cost Breakdown

**Monthly Costs**:
- `e2-small` VM: ~$14/month (or ~$4/month preemptible)
- Static IP (in use): $0/month (no charge when attached)
- Network egress: ~$1-2/month (minimal for 3 devs, VPN traffic)
- Secret Manager: <$1/month (7 secrets × $0.06/month)
- Health checks: $0/month (included)
- **Total**: ~$7/month (with sustained use discount) or ~$15/month (no discount)

**Comparison to Alternatives**:
- Cloud VPN HA: ~$50/month (2 tunnels)
- Managed NAT + Bastion: ~$100/month
- Third-party VPN (Tailscale Teams): ~$20/month (3 users)

## Operations Runbook

### Daily Operations
**Developers**: No action needed - WireGuard auto-connects on startup

### Weekly Tasks
- Review Cloud Monitoring dashboard for health check failures
- Check WireGuard logs for connection anomalies

### Monthly Tasks
- Update VM image (if security patches available)
- Review Secret Manager access logs
- Test MIG auto-healing by manually stopping WireGuard service

### Quarterly Tasks
- Review and rotate developer keys (if policy requires)
- Update WireGuard to latest version
- Test disaster recovery (delete MIG, recreate from template)

### Emergency Procedures

**Scenario: WireGuard VM not responding**
1. Check MIG status: `gcloud compute instance-groups managed describe wireguard-vpn-mig`
2. Check health check status: `gcloud compute health-checks describe wireguard-health-check`
3. Manually recreate instance: `gcloud compute instance-groups managed recreate-instances wireguard-vpn-mig --instances=<instance-name>`

**Scenario: Need to add/remove developer**
1. Generate new keypair (or revoke existing)
2. Update `wireguard-startup.sh` with new peer config
3. Create new instance template with updated script
4. Rolling update MIG

**Scenario: Need to rotate server key**
1. Generate new server keypair
2. Update `wireguard-server-private-key` in Secret Manager
3. Update all client configs with new server public key
4. Rolling update MIG
5. Distribute new client configs to developers

## Success Criteria

### Phase 1 (AlloyDB Access)
- [ ] WireGuard MIG deployed and healthy
- [ ] Static IP assigned and load balancer configured
- [ ] All 3 developers successfully connected
- [ ] Developers can reach AlloyDB PSC endpoint (`10.24.128.3:5432`)
- [ ] Flyway migrations execute successfully (15 tables created)
- [ ] Health checks passing for 24 hours
- [ ] Auto-healing tested (manual VM termination)

### Phase 2 (GKE Access)
- [ ] GKE private control plane deployed
- [ ] WireGuard clients updated with GKE subnet
- [ ] `kubectl` commands work over VPN
- [ ] GKE Connect Gateway tested
- [ ] Developers can deploy to cluster via VPN

### Phase 3 (Production Readiness)
- [ ] Monitoring alerts configured
- [ ] Operations runbook tested
- [ ] Key rotation procedure documented and tested
- [ ] Backup/restore procedure documented
- [ ] 99.5% uptime achieved over 30 days

## Expert Review Findings & Recommended Improvements

**Review Date**: 2025-10-31
**Reviewers**: Security Engineer, DevOps Architect, DevOps Engineer (Network)

### Must Add Now (Startup-Appropriate)

#### 1. Rate Limiting on VPN Endpoint
**Finding**: No rate limiting on UDP 51820 - vulnerable to brute force attacks

**Solution**: iptables rate limiting (simple, zero-cost)
```bash
# Add to startup script before WireGuard starts:
iptables -A INPUT -p udp --dport 51820 -m state --state NEW \
  -m recent --set --name wireguard_rate_limit

iptables -A INPUT -p udp --dport 51820 -m state --state NEW \
  -m recent --update --seconds 60 --hitcount 30 \
  --name wireguard_rate_limit -j DROP
```
Blocks more than 30 new connections per minute from a single IP.

#### 2. Use SNAT Instead of MASQUERADE
**Finding**: Document ambiguous on SNAT vs MASQUERADE choice

**Decision**: Use SNAT (VM has static internal IP via Network LB)
```bash
# Replace MASQUERADE line in startup script with:
iptables -t nat -A POSTROUTING -s 10.100.0.0/24 -j SNAT --to-source $(hostname -I | awk '{print $1}')
```
Better performance - doesn't need to lookup interface IP on every packet.

#### 3. Secret Manager Retry Logic
**Finding**: No retry logic if Secret Manager fetch fails during VM startup

**Solution**: Add exponential backoff retry
```bash
# Add to startup script before creating WireGuard config:
fetch_secret() {
  local max_attempts=5
  local attempt=1

  while [ $attempt -le $max_attempts ]; do
    if gcloud secrets versions access latest \
         --secret="wireguard-server-private-key" \
         --project="pcc-prj-devops-nonprod" \
         > /tmp/server_key 2>/tmp/secret-error.log; then
      logger -t wireguard-bootstrap -p info "Secret Manager fetch successful"
      cat /tmp/server_key
      rm /tmp/server_key
      return 0
    fi

    logger -t wireguard-bootstrap -p warning \
      "Secret Manager fetch failed (attempt $attempt/$max_attempts): $(cat /tmp/secret-error.log)"

    attempt=$((attempt + 1))
    sleep $((2 ** attempt))  # Exponential backoff: 4s, 8s, 16s, 32s
  done

  logger -t wireguard-bootstrap -p err "Secret Manager fetch failed after $max_attempts attempts"
  exit 1
}

SERVER_PRIVATE_KEY=$(fetch_secret)
```

#### 4. Structured Logging
**Finding**: Startup script lacks structured logging for Cloud Logging

**Solution**: Redirect all output to logger with proper tags
```bash
# Add at top of startup script:
exec 1> >(logger -t wireguard-bootstrap -p info)
exec 2> >(logger -t wireguard-bootstrap -p err)

# Then use throughout:
echo "Starting WireGuard configuration"
echo "IP forwarding enabled: $(sysctl -n net.ipv4.ip_forward)"
echo "WireGuard interface created: $(ip link show wg0)"
```

#### 5. VPC Firewall Rules
**Finding**: Missing firewall rules for AlloyDB and GKE traffic

**Add to Terraform** (in `pcc-devops-infra/terraform/environments/nonprod/`):
```hcl
# Allow VPN traffic inbound
resource "google_compute_firewall" "wireguard_ingress" {
  name    = "allow-wireguard-ingress"
  network = "pcc-network-nonprod"
  project = "pcc-prj-devops-nonprod"

  allow {
    protocol = "udp"
    ports    = ["51820"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["wireguard-server"]

  description = "Allow WireGuard VPN traffic from developers"
}

# Allow traffic to AlloyDB PSC
resource "google_compute_firewall" "wireguard_to_alloydb" {
  name    = "allow-wireguard-to-alloydb-psc"
  network = "pcc-network-nonprod"
  project = "pcc-prj-devops-nonprod"

  allow {
    protocol = "tcp"
    ports    = ["5432"]
  }

  source_tags        = ["wireguard-server"]
  destination_ranges = ["10.24.128.0/20"]

  description = "Allow WireGuard VM to reach AlloyDB via PSC"
}

# Allow traffic to GKE control plane (when subnet is known)
resource "google_compute_firewall" "wireguard_to_gke" {
  name    = "allow-wireguard-to-gke-control-plane"
  network = "pcc-network-nonprod"
  project = "pcc-prj-devops-nonprod"

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  source_tags        = ["wireguard-server"]
  destination_ranges = ["TBD_GKE_CONTROL_PLANE_CIDR"]  # Update in Phase 3

  description = "Allow WireGuard VM to reach GKE control plane"
}
```

#### 6. VPC Routes for Return Traffic
**Finding**: Missing routes from AlloyDB PSC and GKE subnets back to tunnel subnet

**Solution**: VM creates its own route at boot (Terraform cannot use MIG name as next_hop_instance)

The startup script now handles route creation dynamically (lines 1304-1322):
- VM extracts its own instance name from metadata
- Deletes stale routes from previous instances (during auto-healing)
- Creates route with current instance as next hop
- Requires `roles/compute.networkAdmin` on service account

#### 7. Minimal Monitoring (Not Overkill)
**Finding**: Zero observability into VPN health

**Add log-based metric + alert**:
```hcl
# Log-based metric for WireGuard startup failures
resource "google_logging_metric" "wireguard_startup_failure" {
  name    = "wireguard-startup-failure"
  project = "pcc-prj-devops-nonprod"

  filter = <<-EOT
    resource.type="gce_instance"
    logName="projects/pcc-prj-devops-nonprod/logs/wireguard-bootstrap"
    severity="ERROR"
  EOT

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
  }
}

# Simple alert: Email if startup fails
resource "google_monitoring_alert_policy" "wireguard_startup_alert" {
  display_name = "WireGuard Startup Failure"
  project      = "pcc-prj-devops-nonprod"

  conditions {
    display_name = "Startup errors detected"

    condition_threshold {
      filter          = "metric.type=\"logging.googleapis.com/user/wireguard-startup-failure\""
      duration        = "60s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]
}
```

### Add Later (Not Blocking)
- Multi-zone MIG distribution (when HA becomes critical)
- Enhanced health check with downstream connectivity tests (with multi-zone)
- Key rotation automation (when team grows beyond 3 people)
- Comprehensive monitoring dashboards (when operational overhead justifies)

### Wait for Phase 3
- GKE control plane firewall rule (need subnet CIDR first)
- GKE return route (need subnet CIDR first)
- kubectl over VPN testing (after GKE deployment)

### Clarifications from Review
1. **AlloyDB authentication**: Uses `alloydb_auth_proxy` for access control (not just VPN access = database access)
2. **Access revocation**: Manual disable for 3-person team (not enterprise-scale automation)
3. **Client key distribution**: Use one-time share password tools (1Password, LastPass)
4. **MTU/MSS**: Not critical for our use case (large packets not common)
5. **Health check scope**: Interface existence check sufficient (downstream tests overkill for single-zone)

---

## Second Review: Gemini + Codex Validation

### Gemini Findings (GCP Architecture Focus)

**Critical Issue - Invalid VPC Route Configuration**:
- Original Terraform tried to use `google_compute_instance_group_manager.wireguard_mig.name` as `next_hop_instance`
- **Impact**: Terraform would fail - routes require specific VM instance name, not MIG manager
- **Fix**: VM now creates its own route at boot using instance metadata (startup script lines 1304-1322)

**Warning - Overly Permissive Service Account**:
- Original used `--scopes=cloud-platform` (full GCP access)
- **Fix**: Changed to explicit scope URL and documented specific IAM roles needed (Step 3a):
  - `roles/secretmanager.secretAccessor`
  - `roles/logging.logWriter`
  - `roles/compute.instanceAdmin.v1`

### Codex Findings (DevOps/Script Robustness Focus)

**Critical Issue #1 - Secret Leakage in Cloud Logging**:
- Original redirected STDERR to `logger`, capturing all secret fetches in Cloud Logging
- **Impact**: Private keys and PSKs permanently stored in Cloud Logging (world-readable to project members)
- **Fix**: Only redirect STDOUT to logger, keep STDERR separate for secret handling (line 1197)

**Critical Issue #2 - fetch_secret() Corrupting Keys**:
- Function echoed status text before outputting secret: `echo "Success..." && cat /tmp/secret_data`
- **Impact**: `SERVER_PRIVATE_KEY=$(fetch_secret ...)` captured status + key = invalid WireGuard config
- **Fix**: Function now outputs only secret to STDOUT, sends status to STDERR using `>&2` (lines 1230-1252)

**Critical Issue #3 - Missing gcloud CLI**:
- Script assumed `gcloud` command exists, but Ubuntu/COS images don't ship it
- **Impact**: First secret fetch would fail with "command not found"
- **Fix**: Added gcloud CLI installation before secret fetching (lines 1211-1217)

**Critical Issue #4 - Hardcoded Network Interface**:
- Used hardcoded `ens4` for SNAT rule
- **Impact**: Could break if GCE renames NIC (multi-NIC templates)
- **Fix**: Dynamic egress interface detection: `EGRESS_INTERFACE=$(ip route get 8.8.8.8 | grep -oP 'dev \K\S+')` (line 1327)

**Critical Issue #5 - Non-Idempotent sysctl**:
- Appending to `/etc/sysctl.conf` on every boot accumulated duplicates
- **Fix**: Made changes idempotent with `grep -q` check before appending (lines 1227-1232)

**All Critical Issues Status**: ✅ **FIXED** in startup script (Step 4) and service account documentation (Step 3a)

---

## Migration from Headscale (Transition Plan)

**For developers currently using Headscale/Tailscale**:

1. **Parallel Testing** (1 week):
   - Deploy WireGuard MIG alongside existing Headscale VM
   - Have 1 developer test WireGuard while others stay on Headscale
   - Validate AlloyDB access via WireGuard

2. **Cutover** (1 day):
   - Distribute WireGuard client configs to all developers
   - Developers disconnect from Headscale/Tailscale
   - Developers connect to WireGuard
   - Validate AlloyDB access for all developers

3. **Decommission Headscale** (1 hour):
   - Monitor for 24 hours post-cutover
   - Delete Headscale VM
   - Delete Headscale secrets
   - Delete Headscale firewall rule

4. **Cleanup Local Machines**:
   - Uninstall Tailscale client (optional, doesn't conflict)
   - Remove old Headscale configs

## Lessons Learned from Headscale Attempt

### Why We Pivoted
1. **GKE Complexity**: Hosting Headscale in GKE for subnet routing proved non-trivial
2. **Overhead**: Headscale control plane adds complexity without significant benefit for 3 users
3. **Simplicity**: Native WireGuard is simpler, more transparent, easier to debug
4. **Reliability**: VM-based approach is more reliable than pod-based routing

### What We Learned
1. **iptables FORWARD chain is critical** for subnet routing
2. **PSC endpoints block ICMP** - use TCP health checks
3. **Static IPs + MIG requires Load Balancer** for seamless failover
4. **Secret Manager is ideal** for storing VPN keys

### What We Keep
1. **WireGuard protocol** - modern, fast, secure
2. **Org policies** - already configured for external IPs and IP forwarding
3. **VPC networking** - no changes needed
4. **Cost target** - still ~$7/month

## References

**WireGuard Documentation**:
- Official site: https://www.wireguard.com/
- Quickstart: https://www.wireguard.com/quickstart/
- Protocol whitepaper: https://www.wireguard.com/papers/wireguard.pdf

**GCP Documentation**:
- Managed Instance Groups: https://cloud.google.com/compute/docs/instance-groups
- Health Checks: https://cloud.google.com/load-balancing/docs/health-checks
- Network Load Balancing: https://cloud.google.com/load-balancing/docs/network
- Secret Manager: https://cloud.google.com/secret-manager/docs

**Related Plans**:
- `.claude/plans/devtest-deployment/phase-2.*` - AlloyDB deployment
- `.claude/plans/devtest-deployment/phase-3.*` - GKE Autopilot deployment

## Configuration Reference

**Key Values**:
- **WireGuard Port**: `51820` (UDP)
- **Health Check Port**: `8080` (TCP)
- **WireGuard Tunnel Subnet**: `10.100.0.0/24`
- **AlloyDB PSC Subnet**: `10.24.128.0/20`
- **AlloyDB PSC Endpoint**: `10.24.128.3:5432`
- **GKE Control Plane Subnet**: TBD (Phase 3)
- **Static IP**: Reserved as `wireguard-vpn-ip` in `us-east4`
- **VM Machine Type**: `e2-small` (2 vCPU, 2GB RAM)
- **VM Image**: Ubuntu 22.04 LTS
- **MIG Size**: 1 (single instance)
- **Health Check Interval**: 30 seconds
- **Auto-Healing Delay**: 5 minutes

**Client IP Assignments**:
- Server: `10.100.0.1/24`
- Developer 1: `10.100.0.10/32`
- Developer 2: `10.100.0.11/32`
- Developer 3: `10.100.0.12/32`
