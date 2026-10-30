# One passing and one failing fixture per rule, in the shape Conftest's hcl2 parser produces:
# input.resource.<type>.<name> is a list of blocks; nested blocks are lists; expressions are
# "${...}" strings. Run: conftest verify --policy infra/policy/terraform --namespace terraform
package terraform

import rego.v1

# ---- 1. S3 public access block ------------------------------------------------------------------

s3_ok := {"resource": {
	"aws_s3_bucket": {"state": [{"bucket": "${local.bucket_name}"}]},
	"aws_s3_bucket_public_access_block": {"state": [{
		"bucket": "${aws_s3_bucket.state.id}",
		"block_public_acls": true,
		"block_public_policy": true,
		"ignore_public_acls": true,
		"restrict_public_buckets": true,
	}]},
}}

test_s3_with_public_access_block_passes if {
	count(deny) == 0 with input as s3_ok
}

test_s3_without_public_access_block_fails if {
	some msg in deny with input as {"resource": {"aws_s3_bucket": {"state": [{"bucket": "x"}]}}}
	contains(msg, "aws_s3_bucket.state")
}

test_s3_with_one_flag_false_fails if {
	bad := json.patch(s3_ok, [{"op": "replace", "path": "/resource/aws_s3_bucket_public_access_block/state/0/restrict_public_buckets", "value": false}])
	some msg in deny with input as bad
	contains(msg, "aws_s3_bucket.state")
}

# ---- 2. GCS bucket ---------------------------------------------------------------------------------

gcs_ok := {"resource": {"google_storage_bucket": {"images": [{
	"name": "${var.project_id}-images",
	"public_access_prevention": "enforced",
	"uniform_bucket_level_access": true,
}]}}}

test_gcs_hardened_passes if {
	count(deny) == 0 with input as gcs_ok
}

test_gcs_inherited_prevention_fails if {
	bad := json.patch(gcs_ok, [{"op": "replace", "path": "/resource/google_storage_bucket/images/0/public_access_prevention", "value": "inherited"}])
	some msg in deny with input as bad
	contains(msg, "public_access_prevention")
}

test_gcs_without_uniform_access_fails if {
	bad := json.patch(gcs_ok, [{"op": "remove", "path": "/resource/google_storage_bucket/images/0/uniform_bucket_level_access"}])
	some msg in deny with input as bad
	contains(msg, "uniform_bucket_level_access")
}

# ---- 3. SSH to the world ---------------------------------------------------------------------------

test_ssh_from_security_group_reference_passes if {
	count(deny) == 0 with input as {"resource": {"aws_vpc_security_group_ingress_rule": {"lab_ssh": [{
		"from_port": 22, "to_port": 22, "ip_protocol": "tcp",
		"referenced_security_group_id": "${aws_security_group.endpoint.id}",
		"security_group_id": "${aws_security_group.lab.id}",
	}]}}}
}

test_web_from_world_on_80_passes if {
	count(deny) == 0 with input as {"resource": {"aws_vpc_security_group_ingress_rule": {"alb_http": [{
		"from_port": 80, "to_port": 80, "ip_protocol": "tcp", "cidr_ipv4": "0.0.0.0/0",
		"security_group_id": "${aws_security_group.alb.id}",
	}]}}}
}

test_ssh_from_world_rule_fails if {
	some msg in deny with input as {"resource": {"aws_vpc_security_group_ingress_rule": {"ssh": [{
		"from_port": 22, "to_port": 22, "ip_protocol": "tcp", "cidr_ipv4": "0.0.0.0/0",
		"security_group_id": "${aws_security_group.lab.id}",
	}]}}}
	contains(msg, "aws_vpc_security_group_ingress_rule.ssh")
}

test_ssh_in_wide_range_from_world_fails if {
	some msg in deny with input as {"resource": {"aws_vpc_security_group_ingress_rule": {"all": [{
		"from_port": 0, "to_port": 1024, "ip_protocol": "tcp", "cidr_ipv6": "::/0",
		"security_group_id": "${aws_security_group.lab.id}",
	}]}}}
	contains(msg, "aws_vpc_security_group_ingress_rule.all")
}

test_ssh_inline_ingress_from_world_fails if {
	some msg in deny with input as {"resource": {"aws_security_group": {"legacy": [{
		"name": "legacy", "vpc_id": "${aws_vpc.lab.id}",
		"ingress": [{"from_port": 22, "to_port": 22, "protocol": "tcp", "cidr_blocks": ["0.0.0.0/0"]}],
	}]}}}
	contains(msg, "aws_security_group.legacy")
}

test_ssh_with_expression_ports_is_not_judged if {
	count(deny) == 0 with input as {"resource": {"aws_vpc_security_group_ingress_rule": {"web": [{
		"from_port": "${each.value.port}", "to_port": "${each.value.port}", "ip_protocol": "tcp",
		"cidr_ipv4": "0.0.0.0/0", "security_group_id": "${aws_security_group.lab.id}",
	}]}}}
}

# ---- 4. IMDSv2 ------------------------------------------------------------------------------------

test_instance_with_imdsv2_passes if {
	count(deny) == 0 with input as {"resource": {
		"aws_instance": {"lab": [{"ami": "${local.ami_id}", "metadata_options": [{"http_endpoint": "enabled", "http_tokens": "required", "http_put_response_hop_limit": 1}]}]},
		"aws_launch_template": {"this": [{"image_id": "${data.aws_ami.al2023.id}", "metadata_options": [{"http_tokens": "required"}]}]},
	}}
}

test_instance_without_metadata_options_fails if {
	some msg in deny with input as {"resource": {"aws_instance": {"lab": [{"ami": "ami-123"}]}}}
	contains(msg, "aws_instance.lab")
}

test_launch_template_with_optional_tokens_fails if {
	some msg in deny with input as {"resource": {"aws_launch_template": {"this": [{"metadata_options": [{"http_tokens": "optional"}]}]}}}
	contains(msg, "aws_launch_template.this")
}

# ---- 5. GCP instance service account -------------------------------------------------------------

test_gcp_instance_without_service_account_passes if {
	count(deny) == 0 with input as {"resource": {"google_compute_instance": {"lab": [{"name": "lab", "machine_type": "e2-medium", "metadata": {"enable-oslogin": "TRUE"}}]}}}
}

test_gcp_instance_with_service_account_fails if {
	some msg in deny with input as {"resource": {"google_compute_instance": {"lab": [{"name": "lab", "service_account": [{"email": "x@y.iam.gserviceaccount.com", "scopes": ["cloud-platform"]}]}]}}}
	contains(msg, "google_compute_instance.lab")
}

# ---- 6. GCP firewall ingress ---------------------------------------------------------------------

test_gcp_firewall_iap_ssh_passes if {
	count(deny) == 0 with input as {"resource": {"google_compute_firewall": {"iap_ssh": [{
		"direction": "INGRESS", "source_ranges": ["${local.iap_range}"], "target_tags": ["lab"],
		"allow": [{"protocol": "tcp", "ports": ["22"]}],
	}]}}}
}

test_gcp_firewall_world_on_web_passes if {
	count(deny) == 0 with input as {"resource": {"google_compute_firewall": {"web": [{
		"direction": "INGRESS", "source_ranges": ["0.0.0.0/0"], "target_tags": ["lab"],
		"allow": [{"protocol": "tcp", "ports": ["80", "443"]}],
	}]}}}
}

test_gcp_firewall_without_source_fails if {
	some msg in deny with input as {"resource": {"google_compute_firewall": {"open": [{
		"direction": "INGRESS", "target_tags": ["lab"], "allow": [{"protocol": "tcp", "ports": ["8080"]}],
	}]}}}
	contains(msg, "google_compute_firewall.open")
}

test_gcp_firewall_world_on_22_fails if {
	some msg in deny with input as {"resource": {"google_compute_firewall": {"ssh": [{
		"source_ranges": ["0.0.0.0/0"], "allow": [{"protocol": "tcp", "ports": ["22"]}],
	}]}}}
	contains(msg, "google_compute_firewall.ssh")
}

test_gcp_firewall_world_all_tcp_fails if {
	some msg in deny with input as {"resource": {"google_compute_firewall": {"everything": [{
		"direction": "INGRESS", "source_ranges": ["0.0.0.0/0"], "allow": [{"protocol": "tcp"}],
	}]}}}
	contains(msg, "google_compute_firewall.everything")
}

test_gcp_firewall_internal_range_on_all_ports_passes if {
	count(deny) == 0 with input as {"resource": {"google_compute_firewall": {"k8s_internal": [{
		"direction": "INGRESS", "source_ranges": ["${google_compute_subnetwork.lab.ip_cidr_range}"], "target_tags": ["k8s"],
		"allow": [{"protocol": "tcp", "ports": ["1-65535"]}, {"protocol": "udp", "ports": ["1-65535"]}, {"protocol": "icmp"}],
	}]}}}
}
