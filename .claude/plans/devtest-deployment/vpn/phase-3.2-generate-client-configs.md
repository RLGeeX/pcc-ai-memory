# Phase 3.2: Generate Client Configurations

**Phase**: 3.2 (VPN Client Setup)
**Duration**: 15-20 minutes
**Tool**: WARP (CLI commands)

## Objective

Generate 3 WireGuard client configurations for developers.

## Steps

### 1. Navigate to Terraform Directory

```bash
cd /home/jfogarty/pcc/infra/pcc-devops-infra/terraform/environments/nonprod
```

### 2. Get Server Public IP and Store in Environment Variable

```bash
SERVER_IP=$(terraform output -raw vpn_external_ip)
SERVER_PUBLIC_KEY=$(gcloud secrets versions access latest \
  --secret="wireguard-server-public-key" \
  --project=pcc-prj-devops-nonprod)
```

### 3. Generate Client Configs (Using Environment Variables Only)

Generate each client config directly without storing keys on disk:

```bash
for i in 1 2 3; do
  # Get peer private key into environment variable (not disk)
  PEER_PRIVATE_KEY=$(gcloud secrets versions access latest \
    --secret="wireguard-peer-${i}-private-key" \
    --project=pcc-prj-devops-nonprod)

  # Create config using environment variables
  cat > /tmp/wg-peer-${i}.conf <<EOF
[Interface]
PrivateKey = $PEER_PRIVATE_KEY
Address = 10.66.0.${i}/24

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = ${SERVER_IP}:51820
AllowedIPs = 10.24.128.0/20, 10.66.0.0/24
PersistentKeepalive = 25
EOF

  chmod 600 /tmp/wg-peer-${i}.conf

  # Clear the private key from environment immediately after use
  unset PEER_PRIVATE_KEY
done

# Clear server public key from environment
unset SERVER_PUBLIC_KEY
```

**Security Note**: Keys are retrieved directly into environment variables and cleared immediately after config creation. No keys are stored on disk except in the final config files (which are properly protected with chmod 600).

### 4. Distribute Configs Securely

Upload to Secret Manager or share via secure channel.

**Status**: Ready for WARP
**Next**: Phase 3.3 - Test Connectivity
