# Consumed by you, once: the bucket name goes into each environment's backend block, which
# cannot read it from here because a backend block is evaluated before any expression.
output "state_bucket" {
  description = "Name of the state bucket -- put this in each environment's backend block"
  value       = aws_s3_bucket.state.id
}

# The block to paste, with <ENV> to fill in. use_lockfile is the S3-native lock; encrypt asks for
# server-side encryption on every write, which the bucket already enforces.
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
