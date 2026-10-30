# What `terraform output` prints after apply: how to reach the VM. Everything here is derived
# from resources in main.tf; nothing is created.

# The private key is the public key path without .pub, and the tunnel is the ProxyCommand every
# SSH-based output shares: `aws ec2-instance-connect open-tunnel` opens a local socket that the
# Instance Connect Endpoint forwards to the VM's port 22, authenticated with your AWS identity.
locals {
  private_key = trimsuffix(var.ssh_public_key_path, ".pub")
  tunnel      = "aws ec2-instance-connect open-tunnel --instance-id ${aws_instance.lab.id} --region ${var.region}"
}

# Consumed by the README's `aws ec2` commands, and by you when a step needs the ID.
output "instance_id" {
  description = "Needed by every aws ec2 command in the README"
  value       = aws_instance.lab.id
}

# Consumed by you: `$(terraform output -raw ssh_command)` opens the shell. The service caps a tunnel at one hour.
output "ssh_command" {
  description = "Connect through the Instance Connect Endpoint. Tunnels last at most one hour; reconnect and `tmux attach`"
  value       = "ssh -i ${local.private_key} -o ProxyCommand='${local.tunnel}' ${local.ssh_user}@${aws_instance.lab.id}"
}

# Consumed by ~/.ssh/config in the week-2 SSH lab, so `ssh lab` works like Multipass's shell did.
output "ssh_config" {
  description = "Paste into ~/.ssh/config so plain `ssh lab` works (Week 2)"
  value       = <<-EOT
    Host lab
        HostName ${aws_instance.lab.id}
        User ${local.ssh_user}
        IdentityFile ${local.private_key}
        IdentitiesOnly yes
        ServerAliveInterval 60
        ProxyCommand ${local.tunnel}
  EOT
}

# Consumed once on the Arch path, before Week 1 Lab 1: the bootstrap script through the same tunnel. null on Ubuntu.
output "bootstrap_command" {
  description = "Arch only: copy arch-bootstrap.sh to the VM. Run from this directory, then `bash arch-bootstrap.sh` on the VM"
  value       = var.distro == "arch" ? "scp -i ${local.private_key} -o ProxyCommand='${local.tunnel}' ../arch-bootstrap.sh ${local.ssh_user}@${aws_instance.lab.id}:~" : null
}

# Consumed by the Gate 1 write-up and by anyone asking what the VM boots: name, publisher, build date.
output "image" {
  description = "What the VM was built from: AMI name, the account that published it, and when"
  value       = "${data.aws_ami.lab.name} (owner ${data.aws_ami.lab.owner_id}, built ${data.aws_ami.lab.creation_date})"
}

# Consumed by the week-3 web labs. Nothing earlier depends on it, and it changes on every stop/start.
output "public_ip" {
  description = "Changes on every stop/start"
  value       = aws_instance.lab.public_ip
}
