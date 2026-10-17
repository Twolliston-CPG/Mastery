# Lab VM for weeks 1-4 on GCP. See ../DISTRO.md.
#
# A dedicated VPC rather than `default`: the default network ships with SSH open to
# 0.0.0.0/0. Here the only way in is IAP, plus 80/443 when open_web is set.

locals {
  # Image families, so every rebuild gets the current image.
  images = {
    ubuntu = { project = "ubuntu-os-cloud", family = "ubuntu-2404-lts-amd64" }
    # Arch's official cloud image, imported into THIS project by ./image (the only
    # community-published Arch image on GCE is from 2022). Run ./image first.
    arch = { project = var.project_id, family = "arch" }
  }
  image = local.images[var.distro]

  iap_range = "35.235.240.0/20" # Google's IAP TCP-forwarding source range
}

data "google_project" "this" {}

# Looked up only to report which build the family currently points at (see outputs).
# The VM itself references the family, so a newer image never forces a rebuild.
#
# Behind a count because a data source that fails blocks every plan, `destroy`
# included: if image/ is destroyed before the lab, the `arch` family is gone and this
# lookup 404s. `terraform destroy -var lookup_image=false` skips it.
data "google_compute_image" "lab" {
  count   = var.lookup_image ? 1 : 0
  project = local.image.project
  family  = local.image.family
}

resource "google_project_service" "compute" {
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "iap" {
  service            = "iap.googleapis.com"
  disable_on_destroy = false
}

# --- Network -------------------------------------------------------------------

resource "google_compute_network" "lab" {
  name                    = "lab"
  auto_create_subnetworks = false

  depends_on = [google_project_service.compute]
}

resource "google_compute_subnetwork" "lab" {
  name          = "lab"
  network       = google_compute_network.lab.id
  region        = var.region
  ip_cidr_range = "10.10.0.0/24"

  private_ip_google_access = true

  dynamic "log_config" {
    for_each = var.flow_logs ? [1] : []
    content {
      aggregation_interval = "INTERVAL_5_SEC"
      flow_sampling        = 0.5
      metadata             = "INCLUDE_ALL_METADATA"
    }
  }
}

# A custom VPC starts with implied deny-all ingress and allow-all egress.
# Everything below is an explicit hole in that deny.

resource "google_compute_firewall" "iap_ssh" {
  name          = "lab-allow-iap-ssh"
  network       = google_compute_network.lab.id
  direction     = "INGRESS"
  source_ranges = [local.iap_range]
  target_tags   = ["lab"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "web" {
  count = var.open_web ? 1 : 0

  name          = "lab-allow-web"
  network       = google_compute_network.lab.id
  direction     = "INGRESS"
  source_ranges = var.web_source_ranges
  target_tags   = ["lab"]

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }
}

# --- Auto-stop -----------------------------------------------------------------

# The schedule is executed by the Compute Engine service agent, which cannot stop
# instances until it is granted the permission. A custom role with exactly the two
# permissions a schedule uses, rather than the predefined instanceAdmin role, which
# would also let the agent create, delete, and reconfigure instances.
resource "google_project_iam_custom_role" "instance_scheduler" {
  count = var.auto_stop_cron == null ? 0 : 1

  role_id     = "labInstanceScheduler"
  title       = "Lab instance scheduler"
  description = "Start and stop instances on a schedule. Nothing else."
  permissions = ["compute.instances.start", "compute.instances.stop"]
}

resource "google_project_iam_member" "schedule_agent" {
  count = var.auto_stop_cron == null ? 0 : 1

  project = var.project_id
  role    = google_project_iam_custom_role.instance_scheduler[0].id
  member  = "serviceAccount:service-${data.google_project.this.number}@compute-system.iam.gserviceaccount.com"

  depends_on = [google_project_service.compute]
}

resource "google_compute_resource_policy" "auto_stop" {
  count = var.auto_stop_cron == null ? 0 : 1

  name   = "lab-auto-stop"
  region = var.region

  instance_schedule_policy {
    time_zone = var.time_zone

    vm_stop_schedule {
      schedule = var.auto_stop_cron
    }
  }

  depends_on = [google_project_service.compute]
}

# --- VM ------------------------------------------------------------------------

# trivy: same decision as the CKV_GCP_40 skip inside (the external IP is deliberate).
#trivy:ignore:AVD-GCP-0031
resource "google_compute_instance" "lab" {
  # checkov:skip=CKV_GCP_40: The external IP is deliberate - outbound package installs without paying for Cloud NAT, and Week 3 serves 80/443. Inbound is default-deny; SSH is IAP-only.
  # checkov:skip=CKV_GCP_38: Disks are encrypted at rest with Google-managed keys. Customer-supplied keys add key-loss risk and nothing a lab needs.
  # checkov:skip=CKV_GCP_39: Shielded VM is enabled for Ubuntu below. The community Arch image is not known to boot with Secure Boot.
  # checkov:skip=CKV_GCP_32: False positive. block-project-ssh-keys is set to "true" inside the merge() below; the check only reads a literal map.
  name         = "lab"
  machine_type = var.machine_type
  zone         = var.zone
  tags         = ["lab"]

  labels = {
    purpose    = "lab"
    managed-by = "terraform"
  }

  boot_disk {
    initialize_params {
      # The full family path, not the "project/family" shorthand. The shorthand makes
      # the provider first probe for an image *named* that; arch-linux-gce shares
      # images individually, so that probe returns 403 instead of 404 and the
      # resolver gives up before trying the family. The family path skips the probe.
      image = "projects/${local.image.project}/global/images/family/${local.image.family}"
      size  = var.disk_size_gb
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.lab.id

    # Ephemeral external IP: needed for outbound package installs, and it changes
    # on every stop/start. Reserve a static address only if a lab needs a stable one.
    access_config {}
  }

  # No service_account block: the VM gets no GCP identity, so nothing running on it
  # -- including whatever a break/fix lab leaves behind -- can call GCP APIs.

  metadata = merge(
    {
      # Only keys added to THIS instance can log in; a key added project-wide cannot.
      block-project-ssh-keys = "true"
      serial-port-enable     = var.enable_serial_console ? "TRUE" : "FALSE"
      # OS Login: SSH access becomes an IAM grant (roles/compute.osAdminLogin, which the
      # project owner already holds) and the Linux username is derived from your Google
      # account. Needs the guest agent, so Ubuntu only; on Arch this stays FALSE.
      enable-oslogin = var.distro == "ubuntu" && var.os_login ? "TRUE" : "FALSE"
    },
    # Arch only. The imported image has cloud-init but not Google's guest agent, so
    # keys are read from metadata once, at first boot, and only for cloud-init's
    # default user ("arch"). Ubuntu's guest agent picks keys up at any time, for any
    # user, which is what `gcloud compute ssh` normally relies on.
    var.distro == "arch" ? {
      ssh-keys = "arch:${trimspace(file(pathexpand(var.ssh_public_key_file)))}"
    } : {}
  )

  # Secure Boot, vTPM, and integrity monitoring. Ubuntu's image is signed for it.
  dynamic "shielded_instance_config" {
    for_each = var.distro == "ubuntu" ? [1] : []
    content {
      enable_secure_boot          = true
      enable_vtpm                 = true
      enable_integrity_monitoring = true
    }
  }

  resource_policies = [for p in google_compute_resource_policy.auto_stop : p.id]

  allow_stopping_for_update = true

  lifecycle {
    # `gcloud compute ssh` writes your public key here; do not strip it on the next apply.
    ignore_changes = [metadata["ssh-keys"]]
  }

  depends_on = [google_project_iam_member.schedule_agent]
}
