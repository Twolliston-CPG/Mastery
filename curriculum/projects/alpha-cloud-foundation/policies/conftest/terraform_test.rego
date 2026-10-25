# Tests for the policy gate. `conftest verify --policy policies/conftest`.
#
# One test per rule in each direction: the rule fires on the bad shape and stays quiet on the good
# one. A rule with a typo in its condition matches nothing and the pipeline stays green while you
# believe you are protected; this file is the only thing that catches that.

package main

import future.keywords.if

tags := {"Environment": "dev", "Owner": "team-platform", "Project": "alpha"}

plan(resources) := {"resource_changes": resources}

res(address, type, after) := {"address": address, "type": type, "change": {"actions": ["create"], "after": after}}

# 1. public S3
test_denies_open_public_access_block if {
	count(deny) == 1 with input as plan([res("aws_s3_bucket_public_access_block.x", "aws_s3_bucket_public_access_block", {"block_public_acls": true, "block_public_policy": false, "ignore_public_acls": true, "restrict_public_buckets": true})])
}

test_allows_closed_public_access_block if {
	count(deny) == 0 with input as plan([res("aws_s3_bucket_public_access_block.x", "aws_s3_bucket_public_access_block", {"block_public_acls": true, "block_public_policy": true, "ignore_public_acls": true, "restrict_public_buckets": true})])
}

# 2. RDS encryption
test_denies_unencrypted_rds if {
	count(deny) == 1 with input as plan([res("aws_db_instance.main", "aws_db_instance", {"storage_encrypted": false, "tags_all": tags, "backup_retention_period": 14})])
}

test_denies_rds_with_encryption_omitted if {
	count(deny) == 1 with input as plan([res("aws_db_instance.main", "aws_db_instance", {"tags_all": tags, "backup_retention_period": 14})])
}

test_allows_encrypted_rds if {
	count(deny) == 0 with input as plan([res("aws_db_instance.main", "aws_db_instance", {"storage_encrypted": true, "tags_all": tags, "backup_retention_period": 14})])
}

# 3. admin ports
test_denies_ssh_from_anywhere if {
	count(deny) == 1 with input as plan([res("aws_vpc_security_group_ingress_rule.ssh", "aws_vpc_security_group_ingress_rule", {"cidr_ipv4": "0.0.0.0/0", "from_port": 22})])
}

test_allows_https_from_anywhere if {
	count(deny) == 0 with input as plan([res("aws_vpc_security_group_ingress_rule.web", "aws_vpc_security_group_ingress_rule", {"cidr_ipv4": "0.0.0.0/0", "from_port": 443})])
}

test_allows_ssh_from_internal if {
	count(deny) == 0 with input as plan([res("aws_vpc_security_group_ingress_rule.ssh", "aws_vpc_security_group_ingress_rule", {"cidr_ipv4": "10.0.0.0/8", "from_port": 22})])
}

test_denies_legacy_rule_postgres_from_anywhere if {
	count(deny) == 1 with input as plan([res("aws_security_group_rule.db", "aws_security_group_rule", {"type": "ingress", "cidr_blocks": ["0.0.0.0/0"], "from_port": 5432})])
}

# 4. required tags
test_denies_missing_owner_tag if {
	count(deny) == 1 with input as plan([res("aws_vpc.main", "aws_vpc", {"tags_all": {"Environment": "dev", "Project": "alpha"}})])
}

test_allows_tags_from_default_tags if {
	count(deny) == 0 with input as plan([res("aws_vpc.main", "aws_vpc", {"tags": {}, "tags_all": tags})])
}

test_denies_every_missing_tag_separately if {
	count(deny) == 3 with input as plan([res("aws_s3_bucket.logs", "aws_s3_bucket", {"tags_all": {}})])
}

# 5. encrypted volumes
test_denies_unencrypted_ebs_volume if {
	count(deny) == 1 with input as plan([res("aws_ebs_volume.data", "aws_ebs_volume", {"encrypted": false})])
}

test_denies_unencrypted_launch_template_disk if {
	count(deny) == 1 with input as plan([res("aws_launch_template.app", "aws_launch_template", {"tags_all": tags, "block_device_mappings": [{"device_name": "/dev/xvda", "ebs": [{"encrypted": false, "volume_size": 20}]}]})])
}

test_allows_encrypted_launch_template_disk if {
	count(deny) == 0 with input as plan([res("aws_launch_template.app", "aws_launch_template", {"tags_all": tags, "block_device_mappings": [{"device_name": "/dev/xvda", "ebs": [{"encrypted": true, "volume_size": 20}]}]})])
}

# deletions and warnings
test_ignores_deletions if {
	count(deny) == 0 with input as {"resource_changes": [{"address": "aws_db_instance.old", "type": "aws_db_instance", "change": {"actions": ["delete"], "after": null}}]}
}

test_warns_on_short_backup_retention if {
	count(warn) == 1 with input as plan([res("aws_db_instance.main", "aws_db_instance", {"storage_encrypted": true, "tags_all": tags, "backup_retention_period": 1})])
}
