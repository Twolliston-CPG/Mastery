# The contract's business rules. The JSON Schema in platform/schemas/ says what a service.yaml may
# contain; it cannot say what a valid file means. These rules can: an owner must be a real team, a
# critical service must be able to survive a node drain, an experimental service must not be public,
# a dependency must be something the platform offers. Same error-message discipline as
# cli/validate.py: where, what, the valid options with their meaning, what to do next.
#
#   conftest test --policy policies/contract --data platform/teams services/orders-api/service.yaml
#   conftest test --policy policies/contract --data platform/teams --combine services/*/service.yaml   # cross-file rules
#   conftest verify --policy policies/contract --data platform/teams
#
# `--data platform/teams` loads teams.yaml, so `data.teams` is the authoritative team list.
# `--combine` hands every file in as one array, which is the only way to check uniqueness across
# services; the single-file rules stay quiet in that mode and the uniqueness rule stays quiet
# outside it.

package main

import future.keywords.contains
import future.keywords.if
import future.keywords.in

docs := "https://platform.internal/docs"

known_teams := {t.name | some t in data.teams}

# What each tier buys, so a message can say it rather than name it.
tier_meaning := {
	"critical": "3 replicas across AZs, PDB, 99.9% SLO, pages on-call 24/7, Multi-AZ database",
	"standard": "2 replicas, 99.5% SLO, tickets in business hours, single-AZ database",
	"experimental": "1 replica, no SLO, no paging, auto-expires after 30 days",
}

# What the platform can provision. The schema enum says the same; this is where the list would
# live if it came from a catalog file instead of being typed twice.
offered := {
	"postgres": "RDS instance + Secrets Manager secret + scoped security group rule",
	"s3": "bucket + an IAM policy scoped to exactly that bucket",
	"sqs": "queue + DLQ + scoped IAM policy",
	"redis": "ElastiCache node + scoped security group rule",
}

single_doc if is_object(input)

name := input.metadata.name

# ----------------------------------------------------- 1. a real owner --
deny contains msg if {
	single_doc
	owner := input.metadata.owner
	not owner in known_teams
	msg := sprintf(
		"metadata.owner: %q is not a known team.\n  Known teams: %s\n  An unowned service is nobody's problem at 3am and cannot be cost-attributed.\n  To add a team, open a PR against platform/teams/teams.yaml. Docs: %s/teams",
		[owner, concat(", ", sort(known_teams)), docs],
	)
}

# ------------------------------------------------- 2. a DNS-1123 name --
# The schema checks the pattern too; the policy says WHY the name is constrained, which the schema's
# error cannot.
deny contains msg if {
	single_doc
	not regex.match(`^[a-z]([-a-z0-9]{0,38}[a-z0-9])?$`, name)
	msg := sprintf(
		"metadata.name: %q becomes the namespace, DNS name, ECR repository and repo name.\n  It must be a DNS-1123 label: a letter, then lowercase letters, digits or hyphens, ending in a letter or digit, at most 40 characters.\n  Suggestion: %q",
		[name, substring(trim(regex.replace(lower(name), `[^a-z0-9-]`, "-"), "-"), 0, 40)],
	)
}

# ---------------------------------- 3. critical means at least two replicas --
# A cross-field rule, which is the thing a schema cannot express: the minimum depends on the tier.
deny contains msg if {
	single_doc
	input.spec.tier == "critical"
	min := input.spec.resources.replicas.min
	min < 2
	msg := sprintf(
		"spec.resources.replicas.min: %d is too low for tier \"critical\" (%s).\n  A node drain or one pod failure would take the service down. Raise it to 2 or more, or use tier \"standard\" (%s).",
		[min, tier_meaning.critical, tier_meaning.standard],
	)
}

# ------------------------------------ 4. experimental is never public --
# An auto-expiring service with no SLO and no paging must not be reachable from the internet: a
# public route on something nobody is paged for is an incident with no owner.
deny contains msg if {
	single_doc
	input.spec.tier == "experimental"
	input.spec.routing.public == true
	msg := sprintf(
		"spec.routing.public: true is not allowed for tier \"experimental\" (%s).\n  Either drop `routing.public` while you experiment, or promote the service to tier \"standard\" (%s) when it has users.\n  Docs: %s/tiers",
		[tier_meaning.experimental, tier_meaning.standard, docs],
	)
}

# ------------------------------- 5. dependencies the platform offers --
deny contains msg if {
	single_doc
	some i, dep in input.spec.dependencies
	not dep.type in object.keys(offered)
	msg := sprintf(
		"spec.dependencies[%d].type: %q is not something the platform provisions.\n  Offered:\n%s\n  Need something else? docs/escape-hatches.md says how to bring your own.",
		[i, dep.type, concat("\n", [sprintf("    %-9s %s", [k, v]) | some k, v in offered])],
	)
}

# ------------------------------------- 6. names unique across services --
# Only in `--combine` mode: input is then a list of {path, contents}.
deny contains msg if {
	is_array(input)
	some a in input
	some b in input
	a.path < b.path
	a.contents.metadata.name == b.contents.metadata.name
	msg := sprintf(
		"metadata.name: %q is already taken by %s.\n  Names are global: one namespace, one DNS name, one repository. Pick another, or talk to that service's owner (%s).",
		[a.contents.metadata.name, a.path, a.contents.metadata.owner],
	)
}
