# Phase 6.13: Configure Cloudflare API Token

**Tool**: [WARP] Partner Execution
**Estimated Duration**: 15 minutes

## Purpose

Create Cloudflare API token with DNS edit permissions, store in GCP Secret Manager via Workload Identity for ExternalDNS to consume.

## Prerequisites

- Phase 6.12 completed (OAuth credentials configured)
- Cloudflare account with domain `pcconnect.ai`
- argocd-server SA has `secretmanager.admin` role (Phase 6.4)

## Detailed Steps

### Step 1: Create Cloudflare API Token

Log in to Cloudflare dashboard:

1. Navigate to **My Profile → API Tokens**
2. Click **Create Token**
3. Use template: **Edit zone DNS**
4. Configure:
   - **Permissions**:
     - Zone → DNS → Edit
     - Zone → Zone → Read
   - **Zone Resources**:
     - Include → Specific zone → `pcconnect.ai`
   - **Client IP Address Filtering**: (leave empty for now)
   - **TTL**: No expiry
5. Click **Continue to summary**
6. Click **Create Token**
7. **CRITICAL**: Copy the token immediately (only shown once)

Example token format: `xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx` (40 chars)

### Step 2: Test Token Validity

```bash
# Replace YOUR_TOKEN with actual token
curl -X GET "https://api.cloudflare.com/client/v4/zones?name=pcconnect.ai" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json"
```

**Expected**: JSON response with zone ID for `pcconnect.ai`

**HALT if**: Error 9109 (Invalid access token) or 10000 (Authentication error)

### Step 3: Store Token in Secret Manager

```bash
# Store token temporarily
export CF_API_TOKEN="YOUR_TOKEN_HERE"

# Check if secret exists, create or add version accordingly
if gcloud secrets describe cloudflare-api-token --project=pcc-prj-devops-nonprod >/dev/null 2>&1; then
  # Secret exists, add new version
  echo -n "${CF_API_TOKEN}" | gcloud secrets versions add cloudflare-api-token \
    --data-file=-
else
  # Secret doesn't exist, create it
  echo -n "${CF_API_TOKEN}" | gcloud secrets create cloudflare-api-token \
    --data-file=- \
    --replication-policy=user-managed \
    --locations=us-east4 \
    --labels=environment=nonprod,managed-by=manual
fi
```

**Expected**: Either `Created secret [cloudflare-api-token]` or `Created version [1] of the secret [cloudflare-api-token]`

**Note**: Runs from workstation using your gcloud credentials (not Workload Identity). This makes the step idempotent for re-runs.

### Step 4: Verify Secret Created

```bash
gcloud secrets describe cloudflare-api-token --format=json
```

Expected output showing replication in us-east4.

### Step 5: Grant ExternalDNS SA Access to Secret

```bash
# Grant externaldns SA permission to read the secret
gcloud secrets add-iam-policy-binding cloudflare-api-token \
  --member="serviceAccount:externaldns@pcc-prj-devops-nonprod.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

**Expected**: Updated IAM policy for secret

### Step 6: Document Token Location

Create note in documentation:

```bash
cat > /tmp/cloudflare-token-location.txt <<EOF
Cloudflare API Token Location:
- GCP Secret Manager: cloudflare-api-token
- Project: pcc-prj-devops-nonprod
- Region: us-east4
- Access: externaldns SA (secretmanager.secretAccessor)
- Created: $(date -I)
- Purpose: ExternalDNS automation for argocd.nonprod.pcconnect.ai
EOF
```

### Step 7: Clear Token from Terminal

```bash
unset CF_API_TOKEN
history -c
```

## Success Criteria

- ✅ Cloudflare API token created with DNS edit permissions
- ✅ Token validated via API test
- ✅ Token stored in Secret Manager (us-east4)
- ✅ externaldns SA granted secretAccessor role
- ✅ Token cleared from terminal history

## HALT Conditions

**HALT if**:
- Cannot create Cloudflare token (insufficient permissions)
- Token validation fails
- Secret Manager creation fails (permission denied)
- IAM binding fails

**Resolution**:
- Verify Cloudflare account owner permissions
- Check token permissions match requirements
- Verify argocd-server SA IAM: `gcloud projects get-iam-policy pcc-prj-devops-nonprod --flatten="bindings[].members" --filter="bindings.members:argocd-server@"`
- Confirm externaldns SA exists from Phase 6.7

## Next Phase

Proceed to **Phase 6.14**: Install ExternalDNS via Helm

## Notes

- **CRITICAL**: Cloudflare API token only shown once - copy immediately
- Token stored in Secret Manager (not committed to Git)
- externaldns SA uses Workload Identity to read secret (no keys needed)
- Token scope limited to single zone (pcconnect.ai)
- No IP filtering for now (can add later if needed)
- Secret creation runs from workstation (uses your gcloud credentials, not Workload Identity)
- If Secret Manager creation fails, can retry (token still valid in Cloudflare)
- Token has no expiry - can rotate manually if compromised
- Document token location for future reference
- Clear token from terminal history for security
