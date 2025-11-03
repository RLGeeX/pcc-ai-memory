# Phase 3.3: Test Connectivity

**Phase**: 3.3 (VPN Testing)
**Duration**: 20-30 minutes
**Tool**: WARP (testing commands)

## Objective

Verify VPN connectivity and AlloyDB access.

## Steps

### 1. Connect VPN from Developer Laptop

```bash
# Copy config to WireGuard directory
sudo cp /tmp/wg-peer-1.conf /etc/wireguard/wg0.conf
sudo chmod 600 /etc/wireguard/wg0.conf

# Start WireGuard
sudo wg-quick up wg0

# Verify tunnel
sudo wg show
```

### 2. Test VPN Tunnel

```bash
# Check routing (AlloyDB PSC subnet should route via wg0)
ip route | grep 10.24.128.0

# Verify VPN tunnel status
sudo wg show
```

### 3. Test AlloyDB Connectivity

```bash
# Get PSC endpoint IP
PSC_IP=$(cd /home/jfogarty/pcc/infra/pcc-devops-infra/terraform/environments/nonprod && terraform output -raw alloydb_psc_endpoint_ip)

# Test TCP connectivity to AlloyDB PSC endpoint
nc -zv $PSC_IP 5432

# Test PostgreSQL connection
psql -h $PSC_IP -p 5432 -U postgres -d client_api_db -c "SELECT version();"
```

### 4. Verify Split-Tunnel

```bash
# Check that regular traffic doesn't go through VPN
curl -s ifconfig.me  # Should show laptop's public IP, not VPN IP

# Check that AlloyDB traffic goes through VPN
ip route get $PSC_IP  # Should show via wg0

# Verify general internet traffic bypasses VPN
ip route get 8.8.8.8  # Should NOT show via wg0
```

### 5. Cleanup Test Connection

```bash
sudo wg-quick down wg0
```

**Status**: Ready for WARP
**Completion**: VPN deployment complete!
