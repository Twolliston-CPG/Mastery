# ADR-0004: Separate directories per environment, not Terraform workspaces

- **Status:** Accepted
- **Date:** 2026-03-04

## Context

Terraform offers two ways to manage multiple environments: workspaces (one configuration, multiple
state files in one backend) or separate root-module directories.

## Options considered

**A. Workspaces.** One configuration, `terraform workspace select prod`. Less duplication. But: all
environments share one backend and one set of credentials, the differences hide inside conditionals
(`count = terraform.workspace == "prod" ? 1 : 0`), and it is genuinely easy to apply to the wrong
workspace — the current workspace is invisible in the command.

**B. Separate directories.** `environments/dev/` and `environments/prod/`, each with its own backend
block and its own state. Some duplication in the root modules, but the shared logic lives in the
modules where it belongs.

## Decision

**Option B.** Workspaces are good for ephemeral, genuinely identical copies — a per-PR preview
environment. They are a poor fit for environments that must differ and must have different blast
radii.

## Consequences

**Positive:** prod can have a different backend, different credentials, and different inputs without
conditionals. `cd environments/prod` makes it visually obvious what you are about to change. CI can
grant the prod role only to the prod job.

**Negative:** `main.tf` is duplicated between environments. Accepted: it is ~50 lines of module calls
and the duplication makes the differences **readable in a diff**, which is the point.
