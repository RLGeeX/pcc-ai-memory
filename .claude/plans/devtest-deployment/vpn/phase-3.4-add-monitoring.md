# Phase 3.4: Add Monitoring and Alerts

**Purpose**: Set up basic monitoring to detect VPN failures proactively
**Duration**: 20-30 minutes
**Tool**: CC (creates Terraform) + WARP (applies changes)
**When**: After successful VPN deployment and testing

---

## Monitoring Strategy

For a 3-person startup, we need minimal but effective monitoring:
- **One critical alert**: VPN completely down
- **One budget alert**: Cost exceeds expectations
- **Simple dashboard**: Basic health metrics (optional)

---

## Step 1: Add Monitoring Resources to Terraform (CC - 15 minutes)

Add to `infra/pcc-devops-infra/terraform/environments/nonprod/wireguard-vpn-monitoring.tf`:

```hcl
# Notification channel for alerts (email)
resource "google_monitoring_notification_channel" "vpn_email" {
  display_name = "VPN Alert Email"
  type         = "email"
  project      = var.project_id

  labels = {
    email_address = "devops@portcon.com"  # Update with your email
  }
}

# Alert if MIG has zero healthy instances for >5 minutes
resource "google_monitoring_alert_policy" "wireguard_zero_instances" {
  display_name = "WireGuard VPN - Zero Healthy Instances"
  project      = var.project_id
  combiner     = "OR"
  enabled      = true

  conditions {
    display_name = "No healthy VMs in MIG"

    condition_threshold {
      filter = <<-EOT
        metric.type="compute.googleapis.com/instance_group/size"
        resource.type="instance_group"
        resource.label.instance_group_name="wireguard-vpn-mig"
      EOT

      comparison      = "COMPARISON_LT"
      threshold_value = 1
      duration        = "300s"  # Alert after 5 minutes of failure

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.vpn_email.id]

  alert_strategy {
    auto_close = "86400s"  # Auto-close after 24 hours if resolved
  }

  documentation {
    content = <<-EOT
      The WireGuard VPN MIG has no healthy instances.

      **Impact**: Developers cannot access AlloyDB or GKE private resources.

      **Actions**:
      1. Check MIG status: `gcloud compute instance-groups managed describe wireguard-vpn-mig --region=us-east4`
      2. Check health check status: `gcloud compute health-checks describe wireguard-health-check`
      3. If auto-healing isn't working, manually recreate: `gcloud compute instance-groups managed recreate-instances wireguard-vpn-mig --instances=<instance-name> --region=us-east4`
      4. Check startup script logs if VM keeps failing
    EOT

    mime_type = "text/markdown"
  }
}

# Log-based metric for startup failures
resource "google_logging_metric" "wireguard_startup_failure" {
  name    = "wireguard-startup-failure"
  project = var.project_id

  filter = <<-EOT
    resource.type="gce_instance"
    jsonPayload.message=~"wireguard-bootstrap.*ERROR"
    OR jsonPayload.message=~"wireguard-bootstrap.*CRITICAL"
  EOT

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"

    labels {
      key         = "instance_name"
      value_type  = "STRING"
      description = "The name of the VM instance"
    }
  }

  label_extractors = {
    "instance_name" = "EXTRACT(resource.labels.instance_id)"
  }
}

# Alert on startup failures
resource "google_monitoring_alert_policy" "wireguard_startup_alert" {
  display_name = "WireGuard VPN - Startup Script Failure"
  project      = var.project_id
  combiner     = "OR"
  enabled      = true

  conditions {
    display_name = "Startup script errors detected"

    condition_threshold {
      filter = "metric.type=\"logging.googleapis.com/user/wireguard-startup-failure\""

      comparison      = "COMPARISON_GT"
      threshold_value = 0
      duration        = "60s"

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.vpn_email.id]

  documentation {
    content = <<-EOT
      The WireGuard startup script has encountered errors.

      **Actions**:
      1. View detailed logs: `gcloud logging read "jsonPayload.message=~'wireguard-bootstrap'" --limit=50`
      2. SSH to VM to debug: `gcloud compute ssh <instance-name> --zone=us-east4-a`
      3. Common issues: Secret Manager access, missing dependencies, iptables errors
    EOT

    mime_type = "text/markdown"
  }
}

# Budget alert for VPN infrastructure
resource "google_billing_budget" "wireguard_budget" {
  billing_account = var.billing_account_id
  display_name    = "WireGuard VPN Budget - NonProd"

  budget_filter {
    projects = ["projects/${var.project_id}"]

    # Filter by labels to track only VPN costs
    labels = {
      "terraform"   = "true"
      "component"   = "wireguard-vpn"
      "environment" = "nonprod"
    }
  }

  amount {
    specified_amount {
      currency_code = "USD"
      units         = "20"  # Alert if exceeds $20/month
    }
  }

  threshold_rules {
    threshold_percent = 0.5   # Alert at 50% ($10)
  }

  threshold_rules {
    threshold_percent = 0.8   # Alert at 80% ($16)
  }

  threshold_rules {
    threshold_percent = 1.0   # Alert at 100% ($20)
  }

  all_updates_rule {
    monitoring_notification_channels = [
      google_monitoring_notification_channel.vpn_email.id
    ]
    disable_default_iam_recipients = false
  }
}

# Optional: Uptime check from external location
resource "google_monitoring_uptime_check_config" "wireguard_external" {
  display_name = "WireGuard VPN - External Reachability"
  project      = var.project_id
  timeout      = "10s"
  period       = "300s"  # Check every 5 minutes

  # TCP check on WireGuard port (UDP not supported by uptime checks)
  tcp_check {
    port = 51820
  }

  monitored_resource {
    type = "uptime_url"

    labels = {
      project_id = var.project_id
      host       = google_compute_address.wireguard_vpn_ip.address
    }
  }

  selected_regions = [
    "USA_VIRGINIA",
    "USA_OREGON"
  ]
}
```

---

## Step 2: Apply Monitoring Configuration (WARP - 10 minutes)

```bash
# Navigate to environment directory
cd infra/pcc-devops-infra/terraform/environments/nonprod/

# Initialize if needed
terraform init

# Plan the monitoring additions
terraform plan -target=google_monitoring_notification_channel.vpn_email \
               -target=google_monitoring_alert_policy.wireguard_zero_instances \
               -target=google_logging_metric.wireguard_startup_failure \
               -target=google_monitoring_alert_policy.wireguard_startup_alert \
               -target=google_billing_budget.wireguard_budget

# Apply the changes
terraform apply -target=google_monitoring_notification_channel.vpn_email \
                -target=google_monitoring_alert_policy.wireguard_zero_instances \
                -target=google_logging_metric.wireguard_startup_failure \
                -target=google_monitoring_alert_policy.wireguard_startup_alert \
                -target=google_billing_budget.wireguard_budget
```

---

## Step 3: Test Alerts (WARP - 5 minutes)

### Test the "Zero Instances" Alert
```bash
# Temporarily stop the MIG to trigger alert
gcloud compute instance-groups managed resize wireguard-vpn-mig \
  --size=0 \
  --region=us-east4

# Wait 5-6 minutes for alert to fire
# Check email for alert notification

# Restore MIG
gcloud compute instance-groups managed resize wireguard-vpn-mig \
  --size=1 \
  --region=us-east4
```

### Verify Budget Alert Configuration
```bash
# List configured budgets
gcloud billing budgets list --billing-account=$(gcloud beta billing accounts list --format="value(name)")

# View budget details
gcloud billing budgets describe <budget-id> --billing-account=<billing-account-id>
```

---

## Step 4: (Optional) Create Simple Dashboard (10 minutes)

Create a basic Cloud Monitoring dashboard for at-a-glance health:

```bash
# Create dashboard via gcloud (or use Console UI)
cat > vpn-dashboard.json <<'EOF'
{
  "displayName": "WireGuard VPN Health",
  "dashboardFilters": [],
  "gridLayout": {
    "widgets": [
      {
        "title": "MIG Instance Count",
        "xyChart": {
          "dataSets": [{
            "timeSeriesQuery": {
              "timeSeriesFilter": {
                "filter": "metric.type=\"compute.googleapis.com/instance_group/size\" resource.label.instance_group_name=\"wireguard-vpn-mig\""
              }
            }
          }]
        }
      },
      {
        "title": "Health Check Success Rate",
        "xyChart": {
          "dataSets": [{
            "timeSeriesQuery": {
              "timeSeriesFilter": {
                "filter": "metric.type=\"monitoring.googleapis.com/uptime_check/check_passed\" resource.label.check_id=\"wireguard-external\""
              }
            }
          }]
        }
      },
      {
        "title": "Network Egress (VPN Traffic)",
        "xyChart": {
          "dataSets": [{
            "timeSeriesQuery": {
              "timeSeriesFilter": {
                "filter": "metric.type=\"compute.googleapis.com/instance/network/sent_bytes_count\" resource.label.instance_id=~\"wireguard-vpn-.*\""
              }
            }
          }]
        }
      }
    ]
  }
}
EOF

gcloud monitoring dashboards create --config-from-file=vpn-dashboard.json
```

---

## What You Get

After this phase, you'll have:
- ✅ **Email alert** when VPN is down for >5 minutes
- ✅ **Budget alert** at 50%, 80%, and 100% of $20/month
- ✅ **Startup failure alert** if script errors occur
- ✅ **Optional dashboard** for visual monitoring

This is appropriate monitoring for a 3-person startup - not too complex, but enough to catch failures before developers notice.

---

## Notes

- Alerts go to `devops@portcon.com` - update with your actual email
- Budget tracking requires labels on all VPN resources (add to Terraform modules)
- First month's budget alerts may be noisy until baseline established
- Consider adding PagerDuty integration when team grows

---

**Next**: Regular operations and maintenance