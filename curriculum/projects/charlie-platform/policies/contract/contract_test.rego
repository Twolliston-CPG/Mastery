# conftest verify --policy policies/contract --data platform/teams
#
# Each rule, both directions. The teams list comes from the real teams.yaml through --data, so a
# test that passes here passes against the file the platform actually reads.

package main

import future.keywords.if

svc(meta, spec) := {"apiVersion": "platform.internal/v1", "kind": "Service", "metadata": meta, "spec": spec}

good_meta := {"name": "orders-api", "owner": "team-payments"}

test_denies_unknown_owner if {
	count(deny) == 1 with input as svc({"name": "x-api", "owner": "team-nobody"}, {"tier": "standard", "language": "go", "port": 8080})
}

test_allows_known_owner if {
	count(deny) == 0 with input as svc(good_meta, {"tier": "standard", "language": "go", "port": 8080})
}

test_denies_bad_name if {
	count(deny) == 1 with input as svc({"name": "Orders_API", "owner": "team-payments"}, {"tier": "standard", "language": "go", "port": 8080})
}

test_denies_critical_with_one_replica if {
	count(deny) == 1 with input as svc(good_meta, {"tier": "critical", "language": "go", "port": 8080, "resources": {"replicas": {"min": 1, "max": 3}}})
}

test_allows_critical_with_three_replicas if {
	count(deny) == 0 with input as svc(good_meta, {"tier": "critical", "language": "go", "port": 8080, "resources": {"replicas": {"min": 3, "max": 12}}})
}

test_denies_public_experimental if {
	count(deny) == 1 with input as svc(good_meta, {"tier": "experimental", "language": "python", "port": 8080, "routing": {"public": true}})
}

test_allows_public_standard if {
	count(deny) == 0 with input as svc(good_meta, {"tier": "standard", "language": "python", "port": 8080, "routing": {"public": true}})
}

test_denies_unoffered_dependency if {
	count(deny) == 1 with input as svc(good_meta, {"tier": "standard", "language": "go", "port": 8080, "dependencies": [{"type": "kafka"}]})
}

test_denies_duplicate_names_in_combine_mode if {
	count(deny) == 1 with input as [
		{"path": "services/a/service.yaml", "contents": svc({"name": "dup", "owner": "team-payments"}, {"tier": "standard"})},
		{"path": "services/b/service.yaml", "contents": svc({"name": "dup", "owner": "team-catalog"}, {"tier": "standard"})},
	]
}

test_allows_distinct_names_in_combine_mode if {
	count(deny) == 0 with input as [
		{"path": "services/a/service.yaml", "contents": svc({"name": "a", "owner": "team-payments"}, {"tier": "standard"})},
		{"path": "services/b/service.yaml", "contents": svc({"name": "b", "owner": "team-catalog"}, {"tier": "standard"})},
	]
}
