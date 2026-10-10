locals {
  private_key = trimsuffix(var.ssh_public_key_path, ".pub")
  tunnel      = "aws ec2-instance-connect open-tunnel --instance-id ${aws_instance.lab.id} --region ${var.region}"
}

output "instance_id" {
  description = "Needed by every aws ec2 command in the README"
  value       = aws_instance.lab.id
}

output "ssh_command" {
  description = "Connect through the Instance Connect Endpoint. Tunnels last at most one hour; reconnect and `tmux attach`"
  value       = "ssh -i ${local.private_key} -o ProxyCommand='${local.tunnel}' ${local.ssh_user}@${aws_instance.lab.id}"
}

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

output "bootstrap_command" {
  description = "Arch only: copy arch-bootstrap.sh to the VM. Run from this directory, then `bash arch-bootstrap.sh` on the VM"
  value       = var.distro == "arch" ? "scp -i ${local.private_key} -o ProxyCommand='${local.tunnel}' ../arch-bootstrap.sh ${local.ssh_user}@${aws_instance.lab.id}:~" : null
}

output "image" {
  description = "What the VM was built from: AMI name, the account that published it, and when"
  value       = "${data.aws_ami.lab.name} (owner ${data.aws_ami.lab.owner_id}, built ${data.aws_ami.lab.creation_date})"
}

output "public_ip" {
  description = "Changes on every stop/start"
  value       = aws_instance.lab.public_ip
}
