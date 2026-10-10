# Week 3 · Day 4 — Private Module Registry

**Exam domain:** 6.

## Learning goals

1. Publish a module to the HCP **private registry**.
2. Understand the registry **naming convention**: `org/<name>/<provider>`, e.g. `my-org/vpc/aws`.
3. Version modules with **Git tags** (`vX.Y.Z` — must be semver).
4. Consume a private-registry module with:
   ```hcl
   source  = "app.terraform.io/my-org/vpc/aws"
   version = "~> 1.0"
   ```
5. **No-code modules** — modules the HCP UI can launch without anyone writing HCL.
6. Module **deprecation** and **version pinning** strategies.

## Registry module repo conventions

Your Git repo must:
- Be named `terraform-<PROVIDER>-<NAME>` (e.g. `terraform-aws-vpc`).
- Have module code at the **root**, *not* in a subdirectory.
- Include `main.tf`, `variables.tf`, `outputs.tf`, `README.md`, `LICENSE`.
- Use Git tags `v1.0.0`, `v1.0.1`, etc. HCP reads versions from tags.

## Publishing flow

1. GitHub → new repo `terraform-aws-minivpc` (public or private).
2. Push the module code + initial `v0.1.0` tag.
3. HCP → Registry → Publish → Module → select the repo → HCP scans for tags.
4. Once published, the private registry URL is: `app.terraform.io/<org>/minivpc/aws`.

## Consuming

```hcl
module "net" {
  source  = "app.terraform.io/my-org/minivpc/aws"
  version = "~> 0.1"

  cidr_block = "10.0.0.0/16"
}
```

- HCP handles auth automatically inside its runners.
- Locally: you need `terraform login` to have ingested an API token.

## No-code modules

- In the registry UI, toggle **"Enable no-code provisioning"** on a module version.
- Consumers go to Registry → Module → "Provision workspace" — HCP scaffolds a workspace with the required variables.
- Great for self-service "spin up a sandbox" patterns. Often tested.

## Exercises

1. Take the `modules/network` from Week 1 Day 4 — copy into a fresh GitHub repo `terraform-aws-minivpc`.
2. Tag and push: `git tag v0.1.0 && git push --tags`.
3. Publish via HCP UI.
4. In a workspace, consume it with `source = "app.terraform.io/<org>/minivpc/aws"` and `version = "~> 0.1"`.
5. Bump the module — add an output, tag `v0.2.0`, push.
6. Change consumer to `version = "~> 0.2"`, run plan — it picks up the new output.

## Self-check

1. Why does HCP require the module repo to be named `terraform-<provider>-<name>`?
2. Can a workspace consume both `app.terraform.io/my-org/vpc/aws` and the public `terraform-aws-modules/vpc/aws` simultaneously?
3. Your tag `v0.2.0` appeared in Git but the HCP registry still shows `v0.1.0`. First thing to check?
4. No-code module publishes: who is allowed to provision workspaces from it?

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Registry module repo conventions
- Publishing flow
- Consuming
- No-code modules

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"Terraform manages your infrastructure."* |
| ✓ | *"`plan` is a three-way comparison: the configuration (desired), the state file (what Terraform believes it created), and a refresh against the real API (what exists). Almost every confusing result is one of those three drifting from the other two."* |

**Trace it:** `terraform apply` on one resource: config → plan → API call → state write. Then say what happens if the process dies between the API call and the state write.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** [the purpose of Terraform state](https://developer.hashicorp.com/terraform/language/state/purpose) — almost every confusing result is a three-way disagreement, spelled out there.
Full list per domain: [`SOURCES.md`](../../SOURCES.md#terraform)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../../MASTERY.md)

<!-- /feynman-check -->
