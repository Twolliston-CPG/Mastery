# Tests for the Terraform policies.
#
#   conftest verify --policy .
#
# Testing the guardrail is the part people skip. A policy with a typo in its
# condition matches nothing and silently allows everything -- and the pipeline
# stays green while you believe you are protected.

package main

import future.keywords.if

test_denies_unencrypted_rds if {
	count(deny) == 1 with input as {"resource_changes": [{
		"address": "aws_db_instance.main",
		"type": "aws_db_instance",
		"change": {"actions": ["create"], "after": {
			"storage_encrypted": false,
			"tags": {"Environment": "prod", "Owner": "team", "Project": "p"},
		}},
	}]}
}

test_allows_encrypted_rds if {
	count(deny) == 0 with input as {"resource_changes": [{
		"address": "aws_db_instance.main",
		"type": "aws_db_instance",
		"change": {"actions": ["create"], "after": {
			"storage_encrypted": true,
			"tags": {"Environment": "prod", "Owner": "team", "Project": "p"},
		}},
	}]}
}

test_denies_ssh_from_anywhere if {
	count(deny) == 1 with input as {"resource_changes": [{
		"address": "aws_vpc_security_group_ingress_rule.ssh",
		"type": "aws_vpc_security_group_ingress_rule",
		"change": {"actions": ["create"], "after": {
			"cidr_ipv4": "0.0.0.0/0",
			"from_port": 22,
		}},
	}]}
}

test_allows_ssh_from_internal if {
	count(deny) == 0 with input as {"resource_changes": [{
		"address": "aws_vpc_security_group_ingress_rule.ssh",
		"type": "aws_vpc_security_group_ingress_rule",
		"change": {"actions": ["create"], "after": {
			"cidr_ipv4": "10.0.0.0/8",
			"from_port": 22,
		}},
	}]}
}

test_denies_missing_owner_tag if {
	count(deny) == 1 with input as {"resource_changes": [{
		"address": "aws_instance.web",
		"type": "aws_instance",
		"change": {"actions": ["create"], "after": {
			"tags": {"Environment": "prod", "Project": "p"},
			"metadata_options": [{"http_tokens": "required"}],
		}},
	}]}
}

test_ignores_deletions if {
	count(deny) == 0 with input as {"resource_changes": [{
		"address": "aws_db_instance.old",
		"type": "aws_db_instance",
		"change": {"actions": ["delete"], "after": null},
	}]}
}
