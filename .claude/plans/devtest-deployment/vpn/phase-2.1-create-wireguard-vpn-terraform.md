# Phase 2.1: Create WireGuard VPN Terraform Configuration

**Phase**: 2.1 (VPN Environment Config)
**Duration**: 45-60 minutes
**Tool**: Claude Code (CC)

## Objective

Create `wireguard-vpn.tf` in `pcc-devops-infra/terraform/environments/nonprod/` that composes all 7 modules from Phase 1.

## File Location

`/home/jfogarty/pcc/infra/pcc-devops-infra/terraform/environments/nonprod/wireguard-vpn.tf`

## Module Composition

```hcl
# 1. Service Account
module "wireguard_sa" {
  source = "../../../../core/pcc-tf-library/modules/service-account"
  
  project_id   = var.project_id
  account_id   = "wireguard-vpn-sa"
  display_name = "WireGuard VPN Service Account"
  
  project_roles = [
    "roles/secretmanager.secretAccessor",
    "roles/compute.instanceAdmin.v1",
    "roles/logging.logWriter"
  ]
}

# 2. Static IP
module "wireguard_ip" {
  source = "../../../../core/pcc-tf-library/modules/static-ip"
  
  project_id   = var.project_id
  name         = "wireguard-vpn-external-ip"
  region       = var.region
  address_type = "EXTERNAL"
  network_tier = "STANDARD"
}

# 3. Firewall Rules
module "wireguard_firewall_udp" {
  source = "../../../../core/pcc-tf-library/modules/firewall-rule"
  
  project_id    = var.project_id
  name          = "allow-wireguard-udp"
  network       = var.vpc_network_name
  direction     = "INGRESS"
  source_ranges = ["0.0.0.0/0"]
  
  allow_rules = [{
    protocol = "udp"
    ports    = ["51820"]
  }]
}

# 4. Health Check
module "wireguard_health_check" {
  source = "../../../../core/pcc-tf-library/modules/health-check"

  project_id = var.project_id
  name       = "wireguard-vpn-health-check"
  type       = "tcp"
  port       = 22  # SSH port for VM health (WireGuard uses UDP)
}

# 4a. Egress Firewall Rule (VPN VM → AlloyDB PSC)
module "wireguard_egress_alloydb" {
  source = "../../../../core/pcc-tf-library/modules/firewall-rule"

  project_id         = var.project_id
  name               = "allow-wireguard-to-alloydb"
  network            = var.vpc_network_name
  direction          = "EGRESS"
  destination_ranges = ["10.24.128.0/20"]  # AlloyDB PSC subnet (nonprod)
  target_tags        = ["wireguard-vpn"]

  allow_rules = [{
    protocol = "tcp"
    ports    = ["5432"]
  }]
}

# 5. Instance Template
resource "google_compute_instance_template" "wireguard" {
  project      = var.project_id
  name         = "wireguard-vpn-template"
  machine_type = "e2-small"
  region       = var.region

  disk {
    source_image = "debian-cloud/debian-11"
    auto_delete  = true
    boot         = true
    disk_size_gb = 10
  }

  network_interface {
    network    = var.vpc_network_name
    subnetwork = var.subnet_name

    access_config {
      nat_ip       = module.wireguard_ip.address
      network_tier = "STANDARD"
    }
  }

  service_account {
    email  = module.wireguard_sa.email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  tags = ["wireguard-vpn"]

  metadata_startup_script = file("${path.module}/startup-script.sh")
}

module "wireguard_mig" {
  source = "../../../../core/pcc-tf-library/modules/mig"
  
  project_id        = var.project_id
  name              = "wireguard-vpn-mig"
  region            = var.region
  instance_template = google_compute_instance_template.wireguard.self_link
  target_size       = 1
  
  auto_healing_policies = {
    health_check      = module.wireguard_health_check.self_link
    initial_delay_sec = 300
  }
}

# 6. Load Balancer
module "wireguard_nlb" {
  source = "../../../../core/pcc-tf-library/modules/load-balancer"
  
  project_id             = var.project_id
  name                   = "wireguard-vpn-nlb"
  region                 = var.region
  protocol               = "UDP"
  port_range             = "51820"
  ip_address             = module.wireguard_ip.self_link
  backend_instance_group = module.wireguard_mig.instance_group
  health_check           = module.wireguard_health_check.self_link
}
```

## Outputs

```hcl
output "vpn_external_ip" {
  description = "External IP address of the WireGuard VPN"
  value       = module.wireguard_ip.address
}

output "psc_endpoint_ip" {
  description = "Private Service Connect endpoint IP for AlloyDB"
  value       = "10.24.128.2"  # Update from terraform outputs in nonprod after deployment
}

output "service_account_email" {
  description = "Service account email for WireGuard VM"
  value       = module.wireguard_sa.email
}
```

## Startup Script

Include the validated startup script from design document lines 1158-1287.

**Status**: Ready for CC
**Next**: Phase 3.1 - Terraform Deploy (WARP)
