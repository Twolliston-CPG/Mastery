output "state_bucket" {
  description = "Name of the state bucket -- put this in each environment's backend block"
  value       = aws_s3_bucket.state.id
}

output "backend_config" {
  description = "Copy this into environments/<env>/backend.tf"
  value       = <<-EOT
    terraform {
      backend "s3" {
        bucket       = "${aws_s3_bucket.state.id}"
        key          = "alpha/<ENV>/terraform.tfstate"
        region       = "${var.region}"
        encrypt      = true
        use_lockfile = true
      }
    }
  EOT
}
