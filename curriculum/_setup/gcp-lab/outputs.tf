# What the lab prints after apply. Each output is a command or a fact the learner needs at the
# terminal; `terraform output -raw <name>` gives the bare string, and `$(...)` runs it.

# The learner, every session: the right login form for the distro, through IAP. The README's
# "Every session" block and DISTRO.md both tell you to run this rather than remember the flags.
output "ssh_command" {
  description = "Connect through IAP. Arch: as the `arch` user, the only one cloud-init created; Ubuntu: as yourself, created on the fly by the guest agent"
  value       = "gcloud compute ssh ${var.distro == "arch" ? "arch@" : ""}${google_compute_instance.lab.name} --project=${var.project_id} --zone=${var.zone} --tunnel-through-iap"
}

# Informational. Nothing in the labs depends on it; week 3 reaches the VM on this address once
# open_web is set, and the address changes on every stop/start because it is ephemeral.
output "external_ip" {
  description = "Ephemeral -- changes on every stop/start"
  value       = google_compute_instance.lab.network_interface[0].access_config[0].nat_ip
}

# The build behind the image family at the last refresh. On Arch, a date many months old is the
# cue to re-run image/ before the next VM rebuild.
output "image" {
  description = "The build the image family pointed at when last refreshed, and when it was made. An Arch build many months old means a large first upgrade"
  value       = var.lookup_image ? "${one(data.google_compute_image.lab).name} (built ${one(data.google_compute_image.lab).creation_timestamp})" : "not looked up (lookup_image = false)"
}

# Arch only (null on Ubuntu): step 11 of the README. Copies arch-bootstrap.sh to the VM over the
# same IAP tunnel as ssh_command.
output "bootstrap_command" {
  description = "Arch only: copy arch-bootstrap.sh to the VM. Run from this directory, then `bash arch-bootstrap.sh` on the VM"
  value       = var.distro == "arch" ? "gcloud compute scp ../arch-bootstrap.sh arch@${google_compute_instance.lab.name}:~ --project=${var.project_id} --zone=${var.zone} --tunnel-through-iap" : null
}

# Weeks 27 to 30: one login line per node, keyed by node name, so
# `terraform output -json kubeadm_ssh_commands | jq -r '."k8s-cp"'` prints the control plane's.
output "kubeadm_ssh_commands" {
  description = "One IAP-tunnelled SSH line per kubeadm node. Empty when kubeadm_nodes = 0"
  value = {
    for name, vm in google_compute_instance.kubeadm :
    name => "gcloud compute ssh ${vm.name} --project=${var.project_id} --zone=${var.zone} --tunnel-through-iap"
  }
}

# Weeks 27 to 30: kubectl from the laptop. The tunnel needs the iap_k8s_api firewall rule in
# kubeadm.tf, which exists only while kubeadm_nodes > 0, which is also when this is non-null.
output "kubeadm_api_tunnel" {
  description = "Forward the API server to your laptop through IAP, then point kubectl at https://localhost:6443 with the admin.conf copied from the control plane. Null when kubeadm_nodes = 0"
  value       = var.kubeadm_nodes > 0 ? "gcloud compute start-iap-tunnel k8s-cp 6443 --local-host-port=localhost:6443 --project=${var.project_id} --zone=${var.zone}" : null
}
