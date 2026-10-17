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

variable "distro" {
  description = "Which path from DISTRO.md: ubuntu or arch"
  type        = string
  default     = "ubuntu"

  validation {
    condition     = contains(["ubuntu", "arch"], var.distro)
    error_message = "distro must be \"ubuntu\" or \"arch\"."
  }
}

variable "lookup_image" {
  description = "Resolve the image family to report its current build in the `image` output. Set false when the family no longer exists -- for example to destroy the lab after `image/` was already destroyed -- because a failing data source blocks every plan, destroy included"
  type        = bool
  default     = true
}

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

variable "os_login" {
  description = "Ubuntu only: govern SSH through OS Login (IAM roles, your Google identity as the Linux user) instead of keys in metadata. Ignored on Arch, whose image lacks the guest agent that implements it"
  type        = bool
  default     = true
}

variable "enable_serial_console" {
  description = "Allow interactive serial-console login: the way back in after an SSH lockout. Turn on before the Week 2 hardening lab, off afterwards"
  type        = bool
  default     = false
}

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

variable "ssh_public_key_file" {
  description = "Arch only: public key placed in instance metadata for the `arch` user before first boot. The default is the key `gcloud compute ssh` uses; create it once with `ssh-keygen -t rsa -b 4096 -f ~/.ssh/google_compute_engine -N ''` if it does not exist"
  type        = string
  default     = "~/.ssh/google_compute_engine.pub"

  validation {
    condition     = var.distro != "arch" || fileexists(pathexpand(var.ssh_public_key_file))
    error_message = "distro = \"arch\" needs ssh_public_key_file to exist before apply; cloud-init reads it only at first boot. Create it: ssh-keygen -t rsa -b 4096 -f ~/.ssh/google_compute_engine -N ''"
  }
}
