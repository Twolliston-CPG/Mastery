# Conftest policies for a Terraform plan JSON.
#
#   terraform plan -out=tf.plan
#   terraform show -json tf.plan > plan.json
#   conftest test --policy . plan.json
#
# `deny` fails the pipeline. `warn` is visible but does not block -- ship new
# policies as `warn` first, measure the noise, then promote to `deny`.

package main

import future.keywords.contains
import future.keywords.if
import future.keywords.in

# ---------------------------------------------------------------- helpers --
# Everything the plan will create or update. Deletions are ignored -- a policy
# should not block you from removing a non-compliant resource.
managed contains r if {
	r := input.resource_changes[_]
	r.change.actions[_] != "delete"
}

# ------------------------------------------------------------------- deny --

deny contains msg if {
	r := managed[_]
	r.type == "aws_s3_bucket_public_access_block"
	some field in ["block_public_acls", "block_public_policy", "ignore_public_acls", "restrict_public_buckets"]
	r.change.after[field] == false
	msg := sprintf("%s: %s must be true -- public S3 is a top breach cause (CIS AWS 2.1.5)", [r.address, field])
}

deny contains msg if {
	r := managed[_]
	r.type == "aws_db_instance"
	not r.change.after.storage_encrypted
	msg := sprintf("%s: storage_encrypted must be true (CIS AWS 2.3.1, SOC 2 CC6.1)", [r.address])
}

deny contains msg if {
	r := managed[_]
	r.type == "aws_ebs_volume"
	not r.change.after.encrypted
	msg := sprintf("%s: EBS volumes must be encrypted", [r.address])
}

deny contains msg if {
	r := managed[_]
	r.type == "aws_vpc_security_group_ingress_rule"
	r.change.after.cidr_ipv4 == "0.0.0.0/0"
	r.change.after.from_port in [22, 3389, 5432, 3306, 6379, 27017]
	msg := sprintf(
		"%s: port %d open to 0.0.0.0/0 -- admin and database ports must not be internet-facing",
		[r.address, r.change.after.from_port],
	)
}

deny contains msg if {
	r := managed[_]
	r.type == "aws_instance"
	r.change.after.metadata_options[_].http_tokens != "required"
	msg := sprintf("%s: IMDSv2 must be required -- IMDSv1 turns any SSRF into credential theft", [r.address])
}

deny contains msg if {
	r := managed[_]
	r.type == "aws_db_instance"
	r.change.after.publicly_accessible == true
	msg := sprintf("%s: databases must not be publicly accessible", [r.address])
}

# Organization-specific -- the kind of rule checkov could never know for you.
required_tags := ["Environment", "Owner", "Project"]

deny contains msg if {
	r := managed[_]
	r.type in ["aws_instance", "aws_db_instance", "aws_s3_bucket", "aws_vpc"]
	some tag in required_tags
	not r.change.after.tags[tag]
	msg := sprintf("%s: missing required tag %q -- untagged resources cannot be cost-attributed", [r.address, tag])
}

approved_regions := {"us-east-1", "us-west-2"}

deny contains msg if {
	r := managed[_]
	region := r.change.after.region
	region != null
	not region in approved_regions
	msg := sprintf("%s: region %q is not approved -- shadow resources in unmonitored regions", [r.address, region])
}

# ------------------------------------------------------------------- warn --

warn contains msg if {
	r := managed[_]
	r.type == "aws_db_instance"
	r.change.after.backup_retention_period < 7
	msg := sprintf("%s: backup retention is %d days; 7+ recommended for production", [r.address, r.change.after.backup_retention_period])
}

warn contains msg if {
	r := managed[_]
	r.type == "aws_cloudwatch_log_group"
	not r.change.after.retention_in_days
	msg := sprintf("%s: no log retention set -- logs will be kept forever and billed forever", [r.address])
}
