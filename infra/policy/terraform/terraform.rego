# The repository's own policy gate, evaluated against raw HCL with Conftest's hcl2 parser, so it
# runs with no plan and no credentials: `input` is one .tf file as JSON, resources under
# input.resource.<type>.<name> as a list of blocks, nested blocks (metadata_options, allow,
# ingress, service_account) as lists, expressions as "${...}" strings.
#
# Every rule here is one the repository already satisfies; the gate exists so a change that stops
# satisfying it is refused in CI, and so the curriculum eats its own cooking (week 19 Lab 1 teaches
# exactly this on Project Alpha). An exception is a rule change in a pull request, never a skip:
# there is no inline suppression for Conftest, on purpose.
#
#   conftest verify --policy infra/policy/terraform --namespace terraform
#   conftest test --parser hcl2 --policy infra/policy/terraform --namespace terraform <files>
package terraform

import rego.v1

# ---- helpers -----------------------------------------------------------------------------------

# Every block of each resource type in this file, with its name: blocks["aws_instance"] is a set of
# {"name": ..., "body": ...}. A type that does not appear in the file yields an empty set.
blocks[type] contains {"name": name, "body": body} if {
	some type, name
	some body in input.resource[type][name]
}

# A literal "everyone" CIDR. Expressions ("${var.x}") are unknown, not open: they are skipped.
world(cidr) if cidr == "0.0.0.0/0"

world(cidr) if cidr == "::/0"

# True when a numeric from/to pair covers port 22. Non-numeric (expression) ports are skipped:
# the rule cannot know, and a false positive would train people to ignore the gate.
covers_22(from, to) if {
	is_number(from)
	is_number(to)
	from <= 22
	to >= 22
}

# GCP `allow.ports` entries are strings: "22", "1-65535". Absent ports means every port.
gcp_port_covers_22(p) if p == "22"

gcp_port_covers_22(p) if {
	parts := split(p, "-")
	count(parts) == 2
	to_number(parts[0]) <= 22
	to_number(parts[1]) >= 22
}

gcp_allow_covers_22(allow) if not allow.ports

gcp_allow_covers_22(allow) if {
	some p in allow.ports
	gcp_port_covers_22(p)
}

# ---- 1. S3 buckets block public access, in the same file ---------------------------------------

pab_for(name) if {
	some r in blocks["aws_s3_bucket_public_access_block"]
	pab := r.body
	contains(pab.bucket, sprintf("aws_s3_bucket.%s.", [name]))
	pab.block_public_acls == true
	pab.block_public_policy == true
	pab.ignore_public_acls == true
	pab.restrict_public_buckets == true
}

deny contains msg if {
	some r in blocks["aws_s3_bucket"]
	name := r.name
	not pab_for(name)
	msg := sprintf(
		"aws_s3_bucket.%s: no aws_s3_bucket_public_access_block in this file references it with all four flags true. Add one with bucket = aws_s3_bucket.%s.id and block_public_acls, block_public_policy, ignore_public_acls, restrict_public_buckets = true",
		[name, name],
	)
}

# ---- 2. GCS buckets: public access prevented, IAM only -----------------------------------------

deny contains msg if {
	some r in blocks["google_storage_bucket"]
	name := r.name
	b := r.body
	not b.public_access_prevention == "enforced" # absent counts as not enforced
	msg := sprintf("google_storage_bucket.%s: set public_access_prevention = \"enforced\"; a bucket must not be publishable even by mistake", [name])
}

deny contains msg if {
	some r in blocks["google_storage_bucket"]
	name := r.name
	b := r.body
	not b.uniform_bucket_level_access == true # absent counts as false
	msg := sprintf("google_storage_bucket.%s: set uniform_bucket_level_access = true; IAM only, no per-object ACLs", [name])
}

# ---- 3. SSH is never open to the world -----------------------------------------------------------

deny contains msg if {
	some x in blocks["aws_vpc_security_group_ingress_rule"]
	name := x.name
	r := x.body
	world(r.cidr_ipv4)
	covers_22(r.from_port, r.to_port)
	msg := sprintf("aws_vpc_security_group_ingress_rule.%s: tcp/22 from 0.0.0.0/0. SSH reaches the lab only through an EC2 Instance Connect Endpoint: reference its security group with referenced_security_group_id instead of a CIDR", [name])
}

deny contains msg if {
	some x in blocks["aws_vpc_security_group_ingress_rule"]
	name := x.name
	r := x.body
	world(r.cidr_ipv6)
	covers_22(r.from_port, r.to_port)
	msg := sprintf("aws_vpc_security_group_ingress_rule.%s: tcp/22 from ::/0. Reference the Instance Connect Endpoint's security group instead of a CIDR", [name])
}

deny contains msg if {
	some x in blocks["aws_security_group"]
	name := x.name
	sg := x.body
	some ingress in sg.ingress
	some cidr in ingress.cidr_blocks
	world(cidr)
	covers_22(ingress.from_port, ingress.to_port)
	msg := sprintf("aws_security_group.%s: an inline ingress block opens tcp/22 to 0.0.0.0/0. Use aws_vpc_security_group_ingress_rule with referenced_security_group_id, never a world CIDR on 22", [name])
}

# ---- 4. IMDSv2 required on every instance and launch template ----------------------------------

imdsv2_required(body) if {
	some mo in body.metadata_options
	mo.http_tokens == "required"
}

deny contains msg if {
	some type in ["aws_instance", "aws_launch_template"]
	some r in blocks[type]
	name := r.name
	not imdsv2_required(r.body)
	msg := sprintf("%s.%s: metadata_options.http_tokens must be \"required\" (IMDSv2). Without it a request forged through any process on the box reads the instance credentials (week 5 Lab 5)", [type, name])
}

# ---- 5. GCP lab instances carry no service account -----------------------------------------------

deny contains msg if {
	some r in blocks["google_compute_instance"]
	name := r.name
	r.body.service_account
	msg := sprintf("google_compute_instance.%s: remove the service_account block. Lab VMs get no GCP identity, so nothing running on them, a break/fix pod included, can call a GCP API", [name])
}

# ---- 6. GCP firewall ingress: an explicit source, and never the world on 22 ---------------------

is_ingress(fw) if not fw.direction

is_ingress(fw) if fw.direction == "INGRESS"

deny contains msg if {
	some r in blocks["google_compute_firewall"]
	name := r.name
	fw := r.body
	is_ingress(fw)
	not fw.source_ranges
	not fw.source_tags
	not fw.source_service_accounts
	msg := sprintf("google_compute_firewall.%s: an INGRESS rule with no source_ranges admits every address. Name the source (the IAP range, the subnet CIDR, or a variable the README documents)", [name])
}

deny contains msg if {
	some r in blocks["google_compute_firewall"]
	name := r.name
	fw := r.body
	is_ingress(fw)
	some cidr in fw.source_ranges
	world(cidr)
	some allow in fw.allow
	allow.protocol == "tcp"
	gcp_allow_covers_22(allow)
	msg := sprintf("google_compute_firewall.%s: tcp/22 from 0.0.0.0/0. SSH reaches the lab only through IAP (35.235.240.0/20); never open 22 to the internet", [name])
}
