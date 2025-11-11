# WireGuard Client Provisioning Updates

**Date**: 2025-11-10  
**Status**: Planning complete, ready to implement  
**Goal**: Change WireGuard client provisioning to store configs in Secret Manager instead of displaying them

---

## Current State

### How It Works Now
1. Admin SSHs into WireGuard server instance
2. Runs `wireguard-add-client <name>` or `wireguard-add-peer <name> <pubkey>`
3. Script generates keys and config
4. **Script outputs complete `.conf` file to stdout**
5. Admin copies/pastes config and sends to user (via Slack, email, etc.)
6. User receives raw config with private keys in plaintext

### Problems
- Client configs transmitted in plaintext (Slack, email)
- No audit trail of who accesses configs
- No centralized storage for configs
- Security risk of configs in chat logs

### Infrastructure Details
- **Location**: `/home/jfogarty/pcc/infra/pcc-devops-infra/terraform/environments/nonprod/`
- **Files**:
  - `wireguard-vpn.tf` - Terraform configuration
  - `startup-script.sh` - Bash script with helper functions
- **Project**: `pcc-prj-devops-nonprod`
- **Region**: `us-east4`
- **Instance**: Managed Instance Group `wireguard-vpn-mig` (target_size=1)
- **Service Account**: `wireguard-vpn-sa` with roles:
  - `roles/secretmanager.secretAccessor`
  - `roles/secretmanager.admin`
  - `roles/compute.instanceAdmin.v1`
  - `roles/logging.logWriter`

### How Server Config Syncing Works
- **Server config** (`/etc/wireguard/wg0.conf`) contains:
  - Server private key
  - All peer public keys and allowed IPs
- **Stored in GCS**: `gs://{project-id}-wireguard-config/wireguard/wg0.conf`
- **Sync mechanism**:
  - When client added: Script updates local `wg0.conf` and uploads to GCS
  - Other MIG instances: Pull from GCS daily via `wireguard-sync.timer` systemd timer
  - Manual sync: `/usr/local/bin/wireguard-sync-config`
- **Server keys** stored in Secret Manager:
  - `wireguard-server-private-key`
  - `wireguard-server-public-key`

### Existing Client
- **UniFi peer** at `10.100.0.2` (john.fogarty's network)
- This is a peer (has own keys), not a full client config
- Needs to be migrated to Secret Manager as structured data

---

## Proposed Changes

### New Workflow
1. Admin runs `wireguard-add-client <name>` or `wireguard-add-peer <name> <pubkey>`
2. Script generates/configures as usual
3. **Script stores config in Secret Manager** as `wireguard-client-nonprod-useast4-{name}`
4. **Script outputs only the secret name/path** (not the config)
5. Admin shares secret name with user
6. User retrieves via `gcloud secrets versions access latest --secret=wireguard-client-nonprod-useast4-{name} > {name}.conf`
7. **Audit trail**: Secret Manager logs show who accessed which configs

### Benefits
- **Security**: Configs never transmitted in plaintext
- **Auditability**: Secret Manager tracks all access
- **Automation**: No manual copy/paste
- **Revocation**: Easy to rotate/revoke by updating secrets
- **IAM-based**: Users need proper GCP IAM permissions

---

## Implementation Plan

### 1. Update `wireguard-add-client` Script
**File**: `startup-script.sh` (lines 161-254)

**Changes**:
- Generate client config as normal (keys, IP assignment, etc.)
- Store complete `.conf` in Secret Manager: `wireguard-client-nonprod-useast4-{name}`
- Labels: `client={name},purpose=wireguard-client-config,environment=nonprod,region=useast4`
- Replication: `user-managed` in `us-east4,us-central1`
- Keep local copy in `/etc/wireguard/clients/` for server reference (optional)
- **Output format**:
  ```
  ✅ WireGuard client created successfully!
  
  Client Name: {name}
  Client IP:   10.100.0.X
  
  📦 Configuration stored in Secret Manager
  
  Secret Name: wireguard-client-nonprod-useast4-{name}
  Secret Path: projects/{project-id}/secrets/wireguard-client-nonprod-useast4-{name}
  
  📋 To retrieve the configuration:
  
    gcloud secrets versions access latest \
      --secret=wireguard-client-nonprod-useast4-{name} \
      --project={project-id} > {name}.conf
  ```

### 2. Update `wireguard-add-peer` Script  
**File**: `startup-script.sh` (lines 274-355)

**Changes**:
- Configure server-side peer as normal
- Create **YAML structure** with client connection details:
  ```yaml
  client_name: {name}
  client_ip: 10.100.0.X/32
  tunnel_address: 10.100.0.X/24
  dns: 10.100.0.1
  server_public_key: {server-pubkey}
  server_endpoint: {external-ip}:51820
  allowed_ips: 10.100.0.0/24, 10.24.128.0/20
  persistent_keepalive: 25
  notes: "Configure these settings in your client's WireGuard interface"
  ```
- Store YAML in Secret Manager: `wireguard-client-nonprod-useast4-{name}`
- Labels: `client={name},purpose=wireguard-peer-config,environment=nonprod,region=useast4`
- **Output format**:
  ```
  ✅ Peer added successfully!
  
  Client Name: {name}
  Client IP:   10.100.0.X/32
  
  📦 Configuration details stored in Secret Manager
  
  Secret Name: wireguard-client-nonprod-useast4-{name}
  
  📋 To retrieve connection details (YAML format):
  
    gcloud secrets versions access latest \
      --secret=wireguard-client-nonprod-useast4-{name} \
      --project={project-id}
  ```

### 3. Create Migration Script for Existing UniFi Peer
**New script**: `wireguard-migrate-existing-peer`

**Purpose**: Create Secret Manager entry for existing UniFi peer at 10.100.0.2

**Process**:
1. Extract current peer config from `wg0.conf`:
   - Find peer block for `10.100.0.2`
   - Extract public key, allowed IPs
2. Get server details:
   - Server public key from `/etc/wireguard/publickey`
   - External IP (static IP or from metadata)
3. Generate YAML structure
4. Store in Secret Manager: `wireguard-client-nonprod-useast4-unifi-fogarty`
5. Output confirmation with secret name

**Script location**: Add to startup-script.sh or create separate script in `/usr/local/bin/`

### 4. IAM Permissions
**Current state**: Service account already has `roles/secretmanager.admin` (includes create)  
**Project-level access**: Users with Secret Manager accessor role can read all secrets  
**No changes needed**: Existing IAM is sufficient

### 5. Update Startup Script Documentation
**File**: `startup-script.sh` (lines 427-440)

**Current end-of-setup message**:
```bash
echo "To add a client (server generates keys): wireguard-add-client <client-name>"
echo "To add a peer (client has own keys): wireguard-add-peer <client-name> <client-public-key>"
```

**Update to**:
```bash
echo "To add a client: wireguard-add-client <client-name>"
echo "  → Generates keys and stores config in Secret Manager"
echo ""
echo "To add a peer: wireguard-add-peer <client-name> <client-public-key>"
echo "  → Stores connection details in Secret Manager (YAML format)"
echo ""
echo "To migrate existing peer: wireguard-migrate-existing-peer <client-name> <client-ip>"
```

---

## Key Design Decisions

### 1. Secret Naming Convention
**Format**: `wireguard-client-nonprod-useast4-{name}`

**Rationale**:
- `wireguard-client`: Prefix for all client configs
- `nonprod`: Environment (future: also `prod`)
- `useast4`: Region identifier
- `{name}`: User-provided client name

**Examples**:
- `wireguard-client-nonprod-useast4-christine-laptop`
- `wireguard-client-nonprod-useast4-john-phone`
- `wireguard-client-nonprod-useast4-unifi-fogarty`

### 2. Client Configs vs Server Config Storage
**Question**: Do instances need client configs locally?

**Answer**: No!
- **Server config** (`wg0.conf`): Needed by all instances → Keep in GCS
- **Client configs** (user downloads): Only for distribution → Secret Manager only
- Local `/etc/wireguard/clients/` directory: Optional convenience, not synced

### 3. Format for Peer Configs
**Question**: YAML or JSON for peer connection details?

**Answer**: YAML (more human-readable for users)

**Alternative**: JSON would also work, but YAML is easier to read when users retrieve it

### 4. Replication Strategy
**Format**: `user-managed` in `us-east4,us-central1`

**Rationale**:
- Multi-region for redundancy
- Same pattern as existing server keys
- Regional replication faster than global automatic

---

## Testing Plan

### Before Implementation
1. ✅ Connect to existing WireGuard instance
2. ✅ Verify current `wg0.conf` structure
3. ✅ Check GCS bucket contents
4. ✅ Confirm UniFi peer at 10.100.0.2
5. ✅ Review existing helper scripts
6. ✅ Verify Secret Manager permissions

### After Implementation
1. **Test `wireguard-add-client`**:
   - Add test client
   - Verify secret created in Secret Manager
   - Retrieve config via gcloud
   - Verify config is valid WireGuard format
   - Test connection from client

2. **Test `wireguard-add-peer`**:
   - Add test peer with own public key
   - Verify YAML stored in Secret Manager
   - Retrieve and parse YAML
   - Verify all required fields present

3. **Test migration script**:
   - Run migration for UniFi peer
   - Verify `wireguard-client-nonprod-useast4-unifi-fogarty` created
   - Retrieve and verify YAML contents

4. **Test IAM access**:
   - Verify DevOps group can read secrets
   - Check audit logs for access events

5. **Test MIG sync**:
   - Verify server config still syncs via GCS
   - Client configs remain in Secret Manager only

---

## Prerequisites

### Connection Setup
**Status**: Blocked - need to create PCC gcloud config first

**Steps**:
1. Create gcloud configuration:
   ```bash
   gcloud config configurations create pcc
   gcloud config set project pcc-prj-devops-nonprod
   gcloud auth login --no-launch-browser
   ```

2. Connect to WireGuard instance:
   ```bash
   # List instances
   gcloud compute instances list \
     --project=pcc-prj-devops-nonprod \
     --filter="name~wireguard"
   
   # SSH via IAP (if direct SSH fails)
   gcloud compute ssh <instance-name> \
     --project=pcc-prj-devops-nonprod \
     --zone=us-east4-a \
     --tunnel-through-iap
   ```

3. Verify current state:
   ```bash
   # Check WireGuard status
   sudo wg show
   
   # Check current config
   sudo cat /etc/wireguard/wg0.conf
   
   # List clients
   sudo wireguard-list-clients
   
   # Check GCS bucket
   gsutil ls gs://pcc-prj-devops-nonprod-wireguard-config/wireguard/
   ```

---

## Files to Modify

### Primary File
`/home/jfogarty/pcc/infra/pcc-devops-infra/terraform/environments/nonprod/startup-script.sh`

**Sections to update**:
- Lines 161-254: `wireguard-add-client` function
- Lines 274-355: `wireguard-add-peer` function
- Lines 427-440: End-of-setup documentation
- Add new: `wireguard-migrate-existing-peer` function

### No Terraform Changes Needed
`wireguard-vpn.tf` already has correct IAM permissions (`roles/secretmanager.admin`)

---

## Questions Answered

### Q: IAM Permissions - per-secret or project-level?
**A**: Project-level is sufficient. Already managing Secret Manager access at project level.

### Q: Secret naming convention?
**A**: `wireguard-client-nonprod-useast4-{name}` (includes environment and region)

### Q: Output detailed instructions?
**A**: No, we'll create separate developer onboarding doc after this is complete.

### Q: Format for peer configs?
**A**: YAML (human-readable, both YAML/JSON work but YAML preferred)

### Q: Existing configs?
**A**: Only UniFi peer at 10.100.0.2 matters - needs migration script

### Q: Do instances need client configs?
**A**: No - only `wg0.conf` (server config) needs GCS sync. Client configs only in Secret Manager.

---

## Related Context

### Backup Script Issue
Discovered during this work: gcloud configurations weren't being backed up properly.

**Fix applied**: `/mnt/c/Users/jfogarty/OneDrive/Apps/linux/backup-home.sh`
- Removed conflicting `.config/*` exclude
- Separated `.config` subdirectories into own loop
- Needs testing downstairs

**Details**: See `/mnt/c/Users/jfogarty/OneDrive/Apps/linux/backup-findings.md`

---

## Next Session TODO

1. Test backup script fix (when downstairs)
2. Create PCC gcloud config and authenticate
3. Connect to WireGuard instance
4. Verify current state (wg0.conf, GCS bucket, existing peers)
5. Implement changes to startup-script.sh:
   - Update `wireguard-add-client`
   - Update `wireguard-add-peer`
   - Add migration script
   - Update documentation
6. Test all three scenarios (add-client, add-peer, migrate)
7. Create developer onboarding document with retrieval instructions

---

**Session Status**: Planning complete, blocked on prerequisites (gcloud auth)  
**Estimated Implementation**: 1-2 hours once connected to instance  
**Risk Level**: Low (changes only affect new client provisioning, existing setup unaffected)
