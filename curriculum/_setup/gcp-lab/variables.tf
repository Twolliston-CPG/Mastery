# Every setting of the lab root, with its default and the reason for it in the description.
# Only the decisions that interact with another variable, or that a learner should question,
# carry a comment here; the rest is the description. Values go in terraform.tfvars (gitignored).

variable "project_id" {
  description = "GCP project that holds the lab. Use a dedicated personal project so `terraform destroy` plus deleting the project removes everything"
  type        = string
}

variable "region" {
  description = "Region for the subnet and the auto-stop schedule"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Zone for the VM. Must be inside var.region"
  type        = string
  default     = "us-central1-a"

  validation {
    condition     = startswith(var.zone, "${var.region}-")
    error_message = "zone must be inside region, for example us-central1-a in us-central1."
  }
}

# The one choice that changes the shape of the VM. It selects the image family in main.tf, whether
# OS Login and Shielded VM are on (Ubuntu only), and whether ssh_public_key_file is read (Arch
# only). Changing it after the VM exists replaces the VM, because the boot image changes.
variable "distro" {
  description = "Which path from DISTRO.md: ubuntu or arch"
  type        = string
  default     = "ubuntu"

  validation {
    condition     = contains(["ubuntu", "arch"], var.distro)
    error_message = "distro must be \"ubuntu\" or \"arch\"."
  }
}

# Exists only so the lab can still be destroyed after image/ is gone; see the data source in
# main.tf for why a failing lookup would otherwise block even `terraform destroy`.
variable "lookup_image" {
  description = "Resolve the image family to report its current build in the `image` output. Set false when the family no longer exists -- for example to destroy the lab after `image/` was already destroyed -- because a failing data source blocks every plan, destroy included"
  type        = bool
  default     = true
}

# e2-medium is a shared-core shape: 2 vCPUs that may be throttled under sustained load, which is
# fine for a lab and roughly half the price of an e2-standard-2.
variable "machine_type" {
  description = "e2-medium matches the Week 1 lab VM: 2 vCPU, 4 GB"
  type        = string
  default     = "e2-medium"
}

variable "disk_size_gb" {
  description = "Boot disk size"
  type        = number
  default     = 20
}

# open_web and web_source_ranges work together: the first creates the 80/443 firewall rule at all,
# the second decides who it admits. Narrow the second before you set the first in week 3.
variable "open_web" {
  description = "Open 80/443 to the internet. Leave false until Week 3 asks for it"
  type        = bool
  default     = false
}

variable "web_source_ranges" {
  description = "Who may reach 80/443 when open_web is true. Let's Encrypt needs 0.0.0.0/0; for everything else, [\"YOUR.IP/32\"] is enough"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "flow_logs" {
  description = "Record VPC flow logs for the lab subnet. Useful evidence for the Week 3 packet-path work; log volume from one VM is small"
  type        = bool
  default     = true
}

# Only consulted when distro = "ubuntu"; main.tf forces OS Login off on Arch because the image has
# no guest agent to implement it. True is the better default: SSH becomes an IAM grant.
variable "os_login" {
  description = "Ubuntu only: govern SSH through OS Login (IAM roles, your Google identity as the Linux user) instead of keys in metadata. Ignored on Arch, whose image lacks the guest agent that implements it"
  type        = bool
  default     = true
}

# A second way into the VM that no firewall rule covers. Off by default and worth turning back off
# after the week that needs it.
variable "enable_serial_console" {
  description = "Allow interactive serial-console login: the way back in after an SSH lockout. Turn on before the Week 2 hardening lab, off afterwards"
  type        = bool
  default     = false
}

# null does more than skip the schedule: the custom role, the grant to the service agent and the
# resource policy are all behind `count = var.auto_stop_cron == null ? 0 : 1` in main.tf, so
# nothing of the auto-stop machinery exists at all.
variable "auto_stop_cron" {
  description = "When to stop the VM every day, as a cron expression in var.time_zone. Set to null to disable"
  type        = string
  default     = "0 0 * * *"
}

variable "time_zone" {
  description = "IANA time zone for auto_stop_cron"
  type        = string
  default     = "America/New_York"
}

# Arch only. The validation runs at plan time, which is the point: cloud-init reads this key once,
# at first boot, so a key that does not exist yet would mean a VM nobody can log in to.
variable "ssh_public_key_file" {
  description = "Arch only: public key placed in instance metadata for the `arch` user before first boot. The default is the key `gcloud compute ssh` uses; create it once with `ssh-keygen -t rsa -b 4096 -f ~/.ssh/google_compute_engine -N ''` if it does not exist"
  type        = string
  default     = "~/.ssh/google_compute_engine.pub"

  validation {
    condition     = var.distro != "arch" || fileexists(pathexpand(var.ssh_public_key_file))
    error_message = "distro = \"arch\" needs ssh_public_key_file to exist before apply; cloud-init reads it only at first boot. Create it: ssh-keygen -t rsa -b 4096 -f ~/.ssh/google_compute_engine -N ''"
  }
}

# --- Kubeadm nodes (weeks 27-30, the CKA module) --------------------------------

variable "kubeadm_nodes" {
  description = "How many kubeadm nodes to run beside the lab VM: 0 is off, 1 is a control plane only, 2 or 3 add workers. kind cannot teach kubeadm init, etcd restore or a cluster upgrade; these can"
  type        = number
  default     = 0

  validation {
    condition     = var.kubeadm_nodes >= 0 && var.kubeadm_nodes <= 3 && floor(var.kubeadm_nodes) == var.kubeadm_nodes
    error_message = "kubeadm_nodes must be a whole number from 0 to 3."
  }
}

# Read by kubeadm-node.sh through the metadata server, not baked into the script, so the same
# script serves every minor. It pins the apt repository the packages come from, nothing else.
variable "kubernetes_minor" {
  description = "Kubernetes minor the nodes are installed at, for example 1.34. Pick one minor BELOW the version the exam tracks, so week 27 Lab 4 can upgrade the cluster by hand; the pkgs.k8s.io repository keeps every minor. Changing it does not touch an existing node -- that is the upgrade lab"
  type        = string
  default     = "1.34"

  validation {
    condition     = can(regex("^1\\.[0-9]{2}$", var.kubernetes_minor))
    error_message = "kubernetes_minor must look like 1.34 (major.minor, no patch)."
  }
}

variable "kubeadm_machine_type" {
  description = "Shape of each kubeadm node. kubeadm's preflight wants 2 CPUs and 1.7 GB; e2-medium is the cheapest that passes. Use e2-standard-2 if the control plane feels tight under etcd plus a CNI"
  type        = string
  default     = "e2-medium"
}

# Interacts with auto_stop_cron: when true, kubeadm.tf attaches no resource policy to the nodes,
# so they run until you stop them. The lab VM keeps its schedule either way.
variable "kubeadm_keep" {
  description = "Exclude the kubeadm nodes from the nightly auto-stop so the cluster runs for months (the long-lived cluster in KUBERNETES-MASTERY.md). Budget it first: two e2-medium nodes around the clock cost roughly what the lab VM would, about $50 a month in most regions. The lab VM keeps its schedule either way"
  type        = bool
  default     = false
}

variable "kubeadm_disk_size_gb" {
  description = "Boot disk per kubeadm node. Images, etcd and container logs need more room than the week-1 VM"
  type        = number
  default     = 30
}
