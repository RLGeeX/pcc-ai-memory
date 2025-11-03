# Phase 3.1: Terraform Deploy

**Phase**: 3.1 (VPN Deployment)
**Duration**: 20-30 minutes
**Tool**: WARP (CLI commands only)

## Objective

Deploy WireGuard VPN infrastructure using Terraform.

## Steps

### 1. Navigate to Environment

```bash
cd /home/jfogarty/pcc/infra/pcc-devops-infra/terraform/environments/nonprod
```

### 2. Terraform Init

```bash
terraform init
```

### 3. Terraform Plan

```bash
terraform plan -out=vpn.tfplan
```

Review plan output for expected resources (7 modules + instance template).

### 4. Terraform Apply

```bash
terraform apply vpn.tfplan
```

Wait for completion (~10-15 minutes for MIG to stabilize).

### 5. Verify Resources

```bash
# Check MIG status
gcloud compute instance-groups managed describe wireguard-vpn-mig \
  --region=us-east4 \
  --project=pcc-prj-devops-nonprod

# Check static IP
terraform output wireguard_external_ip

# Check VM instance health
gcloud compute instance-groups managed list-instances wireguard-vpn-mig \
  --region=us-east4
```

## Completion Notes

**Status**: ✅ COMPLETE (2025-11-02)

### Deployment Results
- External IP: 35.212.69.2
- VPN Endpoint: 35.212.69.2:51820
- AlloyDB PSC IP: 10.24.128.3
- Instance: wireguard-vpn-mig-27jk (RUNNING, HEALTHY)
- Connectivity Test: SUCCESS (verified instance can reach AlloyDB)

### Issues Resolved During Deployment
1. Firewall rules: Changed project_id to var.network_project_id for cross-project VPC
2. MIG update policy: Set max_surge_fixed=0, max_unavailable_fixed=1, added distribution_policy_zones
3. Org policy: Added EXTERNAL_NETWORK_TCP_UDP exemption for devops projects
4. Load balancer: Changed backend service to EXTERNAL scheme
5. Health check: Changed from global to regional
6. Network tier: Added STANDARD tier to forwarding rule
7. Shared VPC: Added compute.networkUser permissions for both compute-system and cloudservices service accounts
8. Shielded VM: Added shielded_instance_config to instance template
9. External IP conflict: Removed nat_ip from instance template (load balancer uses IP instead)

**Next**: Phase 3.2 - Generate Client Configs
