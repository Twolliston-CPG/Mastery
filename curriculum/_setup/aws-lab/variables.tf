variable "region" {
  description = "AWS region for everything in the lab"
  type        = string
  default     = "us-east-1"
}

variable "distro" {
  description = "Which path from DISTRO.md: ubuntu or arch. Choose once: changing it replaces the VM"
  type        = string
  default     = "ubuntu"

  validation {
    condition     = contains(["ubuntu", "arch"], var.distro)
    error_message = "distro must be \"ubuntu\" or \"arch\"."
  }
}

variable "arch_ami_id" {
  description = "Arch path only: the AMI to boot, copied from the community listing for your region (see README). Deliberately not looked up automatically -- you choose which third-party image to trust"
  type        = string
  default     = null

  validation {
    condition     = var.distro != "arch" || var.arch_ami_id != null
    error_message = "distro = \"arch\" needs arch_ami_id. Pick the x86_64 \"std\" AMI for your region from the listing in README.md."
  }
}

variable "instance_type" {
  description = "t3.medium matches the Week 1 lab VM: 2 vCPU, 4 GB. Must be x86_64"
  type        = string
  default     = "t3.medium"
}

variable "disk_size_gb" {
  description = "Root volume size"
  type        = number
  default     = 20
}

variable "ssh_public_key_path" {
  description = "Public half of the key pair you created for the lab. The private half never leaves your machine"
  type        = string
  default     = "~/.ssh/surge-lab.pub"
}

variable "open_web" {
  description = "Open 80/443. Leave false until Week 3 asks for it"
  type        = bool
  default     = false
}

variable "web_source_ranges" {
  description = "Who may reach 80/443 when open_web is true. Let's Encrypt needs 0.0.0.0/0; for everything else, [\"YOUR.IP/32\"] is enough"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "flow_logs" {
  description = "Record VPC flow logs to CloudWatch. Useful evidence for the Week 3 packet-path work; log volume from one VM is small"
  type        = bool
  default     = true
}

variable "auto_stop_cron" {
  description = "When to stop the VM every day, as an EventBridge Scheduler expression in var.time_zone. Set to null to disable"
  type        = string
  default     = "cron(0 0 * * ? *)"
}

variable "time_zone" {
  description = "IANA time zone for auto_stop_cron"
  type        = string
  default     = "America/New_York"
}
