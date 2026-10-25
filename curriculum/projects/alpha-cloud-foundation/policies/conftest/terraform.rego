# Alpha's policy gate: the organization's rules, applied to a Terraform plan between `plan` and
# `apply`. checkov supplies the industry baseline; these are the rules only this organization can
# write. Week 19 Lab 1 is where they are taught; this file is what the pipeline runs.
#
#   terraform -chdir=environments/dev plan -out=tf.plan
#   terraform -chdir=environments/dev show -json tf.plan > plan.json
#   conftest test --policy policies/conftest plan.json
#   conftest verify --policy policies/conftest          # the policies' own tests
#
# `deny` fails the pipeline; `warn` is printed and ignored. Ship a new rule as `warn`, watch the
# noise for a week, then promote it. A policy nobody tested is a policy that may match nothing.

package main

import future.keywords.contains
import future.keywords.if
import future.keywords.in

# ---------------------------------------------------------------- helpers --
# Every resource the plan creates or updates. Deletions are skipped on purpose: a policy must never
# stop you removing the thing it objects to.
managed contains r if {
	r := input.resource_changes[_]
	r.change.actions[_] != "delete"
}

# ------------------------------------------------------ 1. no public S3 --
# The four settings of aws_s3_bucket_public_access_block are four separate doors; one open door is
# a public bucket. CIS AWS 2.1.5.
deny contains msg if {
	r := managed[_]
	r.type == "aws_s3_bucket_public_access_block"
	some field in ["block_public_acls", "block_public_policy", "ignore_public_acls", "restrict_public_buckets"]
	r.change.after[field] == false
	msg := sprintf("%s: %s must be true. Public S3 is a top breach cause (CIS AWS 2.1.5)", [r.address, field])
}

# --------------------------------------------------- 2. RDS encrypted --
# `not storage_encrypted` catches both false and absent: an omitted argument defaults to
# unencrypted, which is the case a reviewer misses.
deny contains msg if {
	r := managed[_]
	r.type == "aws_db_instance"
	not r.change.after.storage_encrypted
	msg := sprintf("%s: storage_encrypted must be true (CIS AWS 2.3.1, SOC 2 CC6.1)", [r.address])
}

# ------------------------------------------- 3. no admin ports from anywhere --
# Both rule shapes: the standalone aws_vpc_security_group_ingress_rule (what Alpha uses) and the
# legacy inline aws_security_group_rule. A CIDR of 0.0.0.0/0 on an admin or database port is the
# finding every scanner agrees on; the port list is the one this organization refuses to argue about.
admin_ports := {22, 3389, 5432, 3306, 6379, 27017}

deny contains msg if {
	r := managed[_]
	r.type == "aws_vpc_security_group_ingress_rule"
	r.change.after.cidr_ipv4 == "0.0.0.0/0"
	r.change.after.from_port in admin_ports
	msg := sprintf("%s: port %d open to 0.0.0.0/0. Admin and database ports are never internet-facing", [r.address, r.change.after.from_port])
}

deny contains msg if {
	r := managed[_]
	r.type == "aws_security_group_rule"
	r.change.after.type == "ingress"
	"0.0.0.0/0" in r.change.after.cidr_blocks
	r.change.after.from_port in admin_ports
	msg := sprintf("%s: port %d open to 0.0.0.0/0. Admin and database ports are never internet-facing", [r.address, r.change.after.from_port])
}

# ------------------------------------------------------- 4. required tags --
# The rule checkov can never know for you: these three tags are what Cost Explorer groups by and what
# the on-call rota is built from. Alpha sets them through provider default_tags, so `tags_all` carries
# them even when a resource's own `tags` block does not; check the merged view.
required_tags := {"Environment", "Owner", "Project"}

taggable := {"aws_instance", "aws_db_instance", "aws_s3_bucket", "aws_vpc", "aws_launch_template", "aws_lb"}

deny contains msg if {
	r := managed[_]
	r.type in taggable
	some tag in required_tags
	not effective_tags(r)[tag]
	msg := sprintf("%s: missing required tag %q. Untagged resources cannot be cost-attributed or paged", [r.address, tag])
}

effective_tags(r) := t if {
	t := r.change.after.tags_all
} else := t if {
	t := r.change.after.tags
} else := {}

# ---------------------------------------------------- 5. encrypted volumes --
# Standalone volumes, launch-template block devices, and instance root volumes are three places a
# disk is declared; an unencrypted one in any of them is the same exposure.
deny contains msg if {
	r := managed[_]
	r.type == "aws_ebs_volume"
	not r.change.after.encrypted
	msg := sprintf("%s: EBS volumes must be encrypted", [r.address])
}

deny contains msg if {
	r := managed[_]
	r.type == "aws_launch_template"
	bdm := r.change.after.block_device_mappings[_]
	ebs := bdm.ebs[_]
	not ebs.encrypted
	msg := sprintf("%s: block device %s must be encrypted", [r.address, bdm.device_name])
}

deny contains msg if {
	r := managed[_]
	r.type == "aws_instance"
	root := r.change.after.root_block_device[_]
	not root.encrypted
	msg := sprintf("%s: the root volume must be encrypted", [r.address])
}

# ------------------------------------------------------------------- warn --
# Visible, not blocking. Promote to deny once every environment complies.
warn contains msg if {
	r := managed[_]
	r.type == "aws_db_instance"
	r.change.after.backup_retention_period < 7
	msg := sprintf("%s: backup retention is %d days; 7 or more for anything you would miss", [r.address, r.change.after.backup_retention_period])
}

warn contains msg if {
	r := managed[_]
	r.type == "aws_instance"
	r.change.after.metadata_options[_].http_tokens != "required"
	msg := sprintf("%s: IMDSv2 should be required; IMDSv1 turns any SSRF into credential theft", [r.address])
}
