# Kubeadm nodes for the CKA module (weeks 27-30). Off by default: kubeadm_nodes = 0.
#
# Same VPC and subnet as the week-1 VM, same guardrails: IAP-only SSH, no service
# account, shielded VM, nightly stop. The startup script installs containerd, kubelet,
# kubeadm and kubectl at the requested minor and nothing more -- `kubeadm init` and
# `kubeadm join` are the lab, not the platform. kind cannot teach this part: its control
# plane is containers, so there is no kubelet to break, no etcd to restore from a
# snapshot, and no `kubeadm upgrade` to run. These nodes exist for exactly those labs.

locals {
  kubeadm_nodes = toset(slice(["k8s-cp", "k8s-w1", "k8s-w2"], 0, var.kubeadm_nodes))
}

# --- Firewall -------------------------------------------------------------------

# Node-to-node traffic inside the lab subnet: the API server (6443), etcd (2379-2380),
# kubelet (10250), the CNI overlay (VXLAN udp/4789 or IPIP), NodePorts and pod-to-pod.
# Everything the cluster needs is between these addresses; nothing here is reachable
# from outside the subnet.
resource "google_compute_firewall" "k8s_internal" {
  count = var.kubeadm_nodes > 0 ? 1 : 0

  name          = "lab-allow-k8s-internal"
  network       = google_compute_network.lab.id
  direction     = "INGRESS"
  source_ranges = [google_compute_subnetwork.lab.ip_cidr_range]
  target_tags   = ["k8s"]

  allow {
    protocol = "tcp"
    ports    = ["1-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["1-65535"]
  }

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "ipip"
  }
}

# The API server from your laptop, through IAP only:
#   gcloud compute start-iap-tunnel k8s-cp 6443 --local-host-port=localhost:6443 ...
# Port 6443 is never open to the internet, same as port 22.
resource "google_compute_firewall" "iap_k8s_api" {
  count = var.kubeadm_nodes > 0 ? 1 : 0

  name          = "lab-allow-iap-k8s-api"
  network       = google_compute_network.lab.id
  direction     = "INGRESS"
  source_ranges = [local.iap_range]
  target_tags   = ["k8s"]

  allow {
    protocol = "tcp"
    ports    = ["6443"]
  }
}

# --- Nodes ----------------------------------------------------------------------

# trivy: same decision as the CKV_GCP_40 skip inside (the external IP is deliberate).
#trivy:ignore:AVD-GCP-0031
resource "google_compute_instance" "kubeadm" {
  # checkov:skip=CKV_GCP_40: The external IP is deliberate - apt pulls containerd and the Kubernetes packages without paying for Cloud NAT. Inbound is default-deny; SSH and 6443 are IAP-only.
  # checkov:skip=CKV_GCP_38: Disks are encrypted at rest with Google-managed keys. Customer-supplied keys add key-loss risk and nothing a lab needs.
  for_each = local.kubeadm_nodes

  name         = each.key
  machine_type = var.kubeadm_machine_type
  zone         = var.zone
  tags         = ["lab", "k8s"]

  labels = {
    purpose    = "k8s"
    managed-by = "terraform"
  }

  boot_disk {
    initialize_params {
      image = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2404-lts-amd64"
      size  = var.kubeadm_disk_size_gb
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.lab.id

    # Ephemeral external IP for apt. It changes on every stop/start; the cluster only
    # ever uses the internal addresses, which do not.
    access_config {}
  }

  # No service_account block: a node gets no GCP identity, so nothing scheduled on it
  # -- a break/fix pod included -- can call GCP APIs.

  metadata = {
    block-project-ssh-keys = "true"
    serial-port-enable     = "FALSE"
    enable-oslogin         = "TRUE"
    # Read by kubeadm-node.sh from the metadata server, so the script carries no version.
    kubernetes-minor = var.kubernetes_minor
  }

  metadata_startup_script = file("${path.module}/kubeadm-node.sh")

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  # kubeadm_keep = true drops the nightly stop so the cluster lives for months: certificate
  # expiry, etcd growth and version skew are failures only time produces (KUBERNETES-MASTERY.md).
  resource_policies = var.kubeadm_keep ? [] : [for p in google_compute_resource_policy.auto_stop : p.id]

  allow_stopping_for_update = true

  lifecycle {
    # `gcloud compute ssh` writes your public key here; do not strip it on the next apply.
    ignore_changes = [metadata["ssh-keys"]]
  }

  depends_on = [google_project_iam_member.schedule_agent]
}
