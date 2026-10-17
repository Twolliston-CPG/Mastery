output "ssh_command" {
  description = "Connect through IAP. Arch: as the `arch` user, the only one cloud-init created; Ubuntu: as yourself, created on the fly by the guest agent"
  value       = "gcloud compute ssh ${var.distro == "arch" ? "arch@" : ""}${google_compute_instance.lab.name} --project=${var.project_id} --zone=${var.zone} --tunnel-through-iap"
}

output "external_ip" {
  description = "Ephemeral -- changes on every stop/start"
  value       = google_compute_instance.lab.network_interface[0].access_config[0].nat_ip
}

output "image" {
  description = "The build the image family pointed at when last refreshed, and when it was made. An Arch build many months old means a large first upgrade"
  value       = var.lookup_image ? "${one(data.google_compute_image.lab).name} (built ${one(data.google_compute_image.lab).creation_timestamp})" : "not looked up (lookup_image = false)"
}

output "bootstrap_command" {
  description = "Arch only: copy arch-bootstrap.sh to the VM. Run from this directory, then `bash arch-bootstrap.sh` on the VM"
  value       = var.distro == "arch" ? "gcloud compute scp ../arch-bootstrap.sh arch@${google_compute_instance.lab.name}:~ --project=${var.project_id} --zone=${var.zone} --tunnel-through-iap" : null
}
