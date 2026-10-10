# Mock Exam — Multiple Choice (90 min, 40 questions)

Record answers in a scratchpad. Don't scroll down to the answer key until you finish all 40.

---

**1.** Which command migrates state from a local backend to an S3 backend?
- a) `terraform state pull`
- b) `terraform init -migrate-state`
- c) `terraform state mv`
- d) `terraform workspace new s3`

**2.** What does `~> 5.2` mean as a version constraint?
- a) Exactly 5.2.0
- b) `>= 5.2, < 5.3`
- c) `>= 5.2, < 6.0`
- d) Any 5.x release

**3.** You need to rename a resource without destroying it. What's the *declarative* way?
- a) `terraform state mv`
- b) `moved {}` block
- c) `import {}` block
- d) `removed {}` block

**4.** A `removed {}` block with `lifecycle { destroy = false }` does what?
- a) Blocks destroys for all resources
- b) Removes the resource from state, keeps cloud object
- c) Prevents the resource from being added
- d) Marks the resource as imported

**5.** Which does NOT work inside a `backend "s3"` block?
- a) Hard-coded bucket name
- b) `-backend-config` at init
- c) `var.bucket_name`
- d) `terraform.workspace` (for key templating)

**6.** `for_each` accepts which types?
- a) `list(any)` only
- b) `set(string)` or `map(any)`
- c) `number` only
- d) Any type

**7.** `count` shifts indices when you insert in the middle. What's the exam-correct fix?
- a) Use a `moved` block
- b) Convert to `for_each` with stable keys
- c) Apply `-target` on each one
- d) It's not a problem

**8.** `check {}` blocks are:
- a) Hard failures at plan time
- b) Hard failures at apply time
- c) Warnings that don't block the run
- d) Only for modules

**9.** Which HCL function returns a boolean indicating whether an expression evaluates without error?
- a) `try`
- b) `can`
- c) `coalesce`
- d) `sensitive`

**10.** A CloudFront distribution requires its ACM cert in:
- a) The same region as the origin
- b) us-east-1 always
- c) eu-west-1 always
- d) Matches the viewer's region

**11.** You set `sensitive = true` on a variable. Its value is:
- a) Encrypted in state
- b) Redacted in plan output only
- c) Encrypted at rest, redacted in output
- d) Removed entirely from state

**12.** `terraform_remote_state` requires what on the *producer* workspace?
- a) Public access
- b) State-sharing enabled for the consumer
- c) Remote backend set to s3
- d) Nothing special

**13.** `cloud {}` block and `backend "remote" {}` can:
- a) Both exist, `cloud` wins
- b) Both exist, `backend` wins
- c) Not coexist
- d) Only one per project

**14.** Dynamic provider credentials for HCP → AWS require:
- a) Static `AWS_ACCESS_KEY_ID` in workspace
- b) `TFC_AWS_PROVIDER_AUTH = true` + a role ARN
- c) An IAM user per workspace
- d) SSM Parameter Store

**15.** A Sentinel policy at `soft-mandatory` enforcement level:
- a) Blocks the run, no override
- b) Warning only
- c) Blocks but workspace admins can override
- d) Applied but only logged

**16.** A private-registry module's Git repo must be named:
- a) Anything
- b) `terraform-<provider>-<name>`
- c) `<name>-terraform`
- d) `hashicorp-<name>`

**17.** `terraform plan -detailed-exitcode` returns 2 when:
- a) There's an error
- b) There's a diff
- c) There's no diff
- d) Apply succeeded

**18.** Which is NOT a valid run workflow in HCP?
- a) CLI-driven
- b) VCS-driven
- c) API-driven
- d) SSH-driven

**19.** Best way to run Terraform in a private network with no internet access on runners:
- a) VCS-driven with public runners
- b) Agent pool
- c) CLI-driven from a jumpbox
- d) Self-host TFE

**20.** `configuration_aliases` in a module is for:
- a) Listing providers that require explicit alias from caller
- b) Renaming the provider internally
- c) Required environment variables
- d) Backup provider selection

**21.** You can't reference `var.X` in a backend block because:
- a) Variables aren't supported in HCL
- b) Backend is resolved before variables
- c) Security
- d) Syntax limitation of 1.6

**22.** `terraform import` with a traditional CLI command will:
- a) Generate HCL for you
- b) Only update state — you still write HCL by hand
- c) Fail if HCL exists
- d) Work only for AWS resources

**23.** `import {}` block + `terraform plan -generate-config-out=gen.tf`:
- a) Requires Terraform 1.5+ and writes HCL
- b) Requires 1.0+
- c) Only available in HCP
- d) Generates Python

**24.** `lifecycle { create_before_destroy = true }` works best when:
- a) The resource has unique-name constraints, plus you use `name_prefix`
- b) Always
- c) Only for IAM
- d) Only inside modules

**25.** `ignore_changes = all` does what that `ignore_changes = [tags]` doesn't?
- a) Faster plans
- b) Drift detection disabled entirely for that resource
- c) Hides changes from humans
- d) Nothing different

**26.** `terraform workspace` (CLI workspaces) differ from HCP workspaces in:
- a) Nothing
- b) CLI workspaces are separate state keys under one config; HCP workspaces are fully isolated
- c) Only HCP supports them
- d) CLI workspaces don't lock

**27.** `dynamic` blocks use `iterator` when:
- a) Required always
- b) To rename the iterator variable inside `content`
- c) For nested dynamics
- d) Only with `for_each` on the parent

**28.** A `postcondition` fires:
- a) Before plan
- b) During plan
- c) During apply after the resource action
- d) After destroy

**29.** Where does Terraform look for providers in order?
- a) Local mirror → filesystem mirror → registry
- b) Registry → filesystem mirror → local
- c) Configured install methods; defaults are filesystem mirror then registry
- d) Lock file only

**30.** `.terraform.lock.hcl`:
- a) Ignored by default
- b) Should be committed — pins versions and records checksums
- c) Is a private secret
- d) Only for Terraform Cloud users

**31.** `terraform providers lock -platform=linux_amd64 -platform=darwin_arm64` does:
- a) Locks the backend
- b) Pre-computes checksums for multi-platform CI
- c) Prevents upgrades
- d) Rebuilds the provider cache

**32.** `mock_provider` in `.tftest.hcl` is for:
- a) Slowing tests down
- b) Running tests without real provider API calls
- c) Forced live testing
- d) Production use

**33.** `expect_failures = [var.X]` means:
- a) Run must fail with any error
- b) Validation on `var.X` must fail
- c) X must not be declared
- d) Test is expected to skip

**34.** Run triggers between workspaces:
- a) Kick off workspace B's plan/apply when workspace A applies
- b) Trigger Slack only
- c) Only work with VCS-driven workspaces
- d) Require paid tier

**35.** You want CI to detect whether a plan has changes. Use:
- a) `terraform apply -auto-approve`
- b) `terraform plan -detailed-exitcode`
- c) `terraform state list`
- d) `terraform show`

**36.** `provider "aws" { alias = "euw1" }` — how does a resource select it?
- a) `aws.euw1` in the `provider` meta-argument
- b) Automatically by region
- c) Via `depends_on`
- d) Via `for_each`

**37.** `terraform show -json > plan.json` outputs:
- a) Provider schemas
- b) State or plan as structured JSON (useful for policies)
- c) The lock file
- d) Graph DOT format

**38.** Which provider authentication method in AWS is preferred for long-running CI?
- a) Static access keys in env vars
- b) `assume_role` with OIDC web identity
- c) `~/.aws/credentials` file
- d) IAM user in the repo

**39.** An `aws_s3_bucket` you imported shows a diff for `force_destroy`. The fix is:
- a) `terraform destroy`
- b) Set `force_destroy = false` in HCL or add to `ignore_changes`
- c) Add `lifecycle { prevent_destroy = true }`
- d) Delete and recreate

**40.** You forgot `backend "s3"` had `key = "terraform.tfstate"` and just ran `init -migrate-state` with `key = "envs/dev/terraform.tfstate"`. What happened?
- a) Nothing changed
- b) State moved to the new key, old location empty
- c) State duplicated
- d) Init failed

---

When finished, open `answers/mcq-key.md`.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Mock Exam — Multiple Choice (90 min, 40 questions)

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
