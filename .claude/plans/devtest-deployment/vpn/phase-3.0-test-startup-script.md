# Phase 3.0: Test Startup Script Standalone

**Purpose**: Validate the WireGuard startup script works correctly before MIG deployment
**Duration**: 30-45 minutes
**Tool**: WARP (runs gcloud commands)
**Dependency**: Startup script must be finalized in Phase 2

---

## Why Test First?

Testing the startup script in a standalone VM before MIG deployment:
- Catches errors without the complexity of MIG auto-healing
- Allows direct SSH debugging if something fails
- Validates all dependencies are correctly installed
- Confirms Secret Manager access works
- Reduces risk of MIG boot-loop if script has errors

---

## Test Procedure

### Step 1: Create Test VM (5 minutes)

```bash
# Create a test VM with the startup script
gcloud compute instances create wireguard-test-vm \
  --zone=us-east4-a \
  --machine-type=e2-small \
  --image-family=ubuntu-2204-lts \
  --image-project=ubuntu-os-cloud \
  --boot-disk-size=10GB \
  --boot-disk-type=pd-standard \
  --can-ip-forward \
  --network=pcc-network-nonprod \
  --subnet=pcc-subnet-nonprod \
  --tags=wireguard-test \
  --service-account=wireguard-vpn-sa@pcc-prj-devops-nonprod.iam.gserviceaccount.com \
  --scopes=https://www.googleapis.com/auth/cloud-platform \
  --metadata-from-file=startup-script=wireguard-startup.sh

echo "Waiting for VM to boot and run startup script..."
sleep 120  # Give startup script 2 minutes to complete
```

### Step 2: Verify Startup Script Execution (10 minutes)

```bash
# SSH into the test VM
gcloud compute ssh wireguard-test-vm --zone=us-east4-a

# Once connected, run validation checks:

# 1. Check if WireGuard is installed and running
sudo wg show
# Expected output: interface: wg0, listening port: 51820

# 2. Verify IP forwarding is enabled
sysctl net.ipv4.ip_forward
# Expected output: net.ipv4.ip_forward = 1

# 3. Check if health check service is running
curl -s http://localhost:8080/health
# Expected output: OK

# 4. Verify iptables rules were applied
sudo iptables -L FORWARD -n | grep wg0
# Expected output: ACCEPT rules for wg0 interface

# 5. Check if VPC route was created
gcloud compute routes list --filter="name:route-to-vpn-from-wireguard-test-vm"
# Expected output: Route with destination 10.100.0.0/24

# 6. Review startup script logs
sudo journalctl -u google-startup-scripts.service | grep wireguard-bootstrap
# Look for any ERROR messages
```

### Step 3: Test Secret Manager Access (5 minutes)

```bash
# Verify the VM can fetch secrets (still SSH'd into test VM)
gcloud secrets versions access latest \
  --secret=wireguard-server-private-key \
  --project=pcc-prj-devops-nonprod

# If this fails, check IAM permissions:
gcloud projects get-iam-policy pcc-prj-devops-nonprod \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:wireguard-vpn-sa@*"
```

### Step 4: Test WireGuard Functionality (10 minutes)

```bash
# From your local machine (not the VM), test if WireGuard port is accessible
nc -zvu $(gcloud compute instances describe wireguard-test-vm \
  --zone=us-east4-a \
  --format="value(networkInterfaces[0].accessConfigs[0].natIP)") 51820

# Expected output: Connection to X.X.X.X 51820 port [udp/*] succeeded!
```

### Step 5: Review and Document Issues (5 minutes)

Common issues to check for:
- **gcloud not found**: Script needs to install gcloud CLI
- **Secret fetch fails**: Check IAM bindings for service account
- **iptables errors**: May need different rules for specific VPC setup
- **Route creation fails**: Service account needs compute.instanceAdmin role
- **Health check not running**: Python3 or systemd service issue

### Step 6: Clean Up Test VM (5 minutes)

```bash
# Delete the test VM after validation
gcloud compute instances delete wireguard-test-vm \
  --zone=us-east4-a \
  --quiet

# Delete the test route
gcloud compute routes delete route-to-vpn-from-wireguard-test-vm \
  --quiet
```

---

## Success Criteria

✅ **All checks pass**: Proceed to Phase 3.1 (MIG deployment)
⚠️ **Minor issues**: Fix in startup script, re-test
❌ **Major failures**: Debug thoroughly before MIG deployment

---

## Troubleshooting

### Startup Script Didn't Run
```bash
# Check if script was passed to VM
gcloud compute instances describe wireguard-test-vm \
  --zone=us-east4-a \
  --format="value(metadata.items[startup-script])"

# View detailed startup script logs
sudo journalctl -xe | grep startup
```

### WireGuard Not Running
```bash
# Check if WireGuard installed
which wg

# Check service status
sudo systemctl status wg-quick@wg0

# Review WireGuard logs
sudo journalctl -u wg-quick@wg0
```

### Health Check Not Accessible
```bash
# Check if Python service is running
ps aux | grep wg-health-check

# Check if port 8080 is listening
sudo netstat -tlnp | grep 8080

# Test health check locally
curl -v http://localhost:8080/health
```

---

## Notes

- This test phase adds 30-45 minutes but saves hours of debugging MIG issues
- Run this test after any significant changes to startup script
- Keep test VM running if you need to iterate on script fixes
- Document any environment-specific adjustments needed

---

**Next**: Phase 3.1 - Terraform Deploy (with confidence that startup script works!)