# The state bucket, and never being asked for it again

This directory creates the Cloud Storage bucket that holds the lab's Terraform state. It is
applied **once**, before the lab, and it keeps its own state as a local file here, because a
bucket cannot store the state that creates it. Everything about the bucket's hardening is in the
comments of [`main.tf`](main.tf); this file is about the one thing that trips people up afterwards:

```
Initializing the backend...
bucket
  The name of the Google Cloud Storage bucket

  Enter a value:
```

## Why Terraform asks

[`../backend.tf`](../backend.tf) declares the backend with only a `prefix`. The bucket name is
deliberately **not** in it:

- A `backend` block is read before anything else is evaluated, so it cannot use a variable, a
  local, or a data source. The name has to arrive from outside the configuration.
- The name embeds the project ID (`<project>-tfstate`), and the project ID stays out of this
  repository on purpose. Hard-coding it would leak it into every clone.

So the name lives in `../backend.hcl`, which is gitignored, and has to be handed to `init`
every time. Forget the flag and Terraform asks for it interactively. In CI, or with input
disabled, it fails instead.

## Set it up once

```bash
cd state
terraform init
terraform apply -var project_id=$PROJECT_ID
terraform output -raw backend_config > ../backend.hcl    # writes: bucket = "<project>-tfstate"
cd ..
```

Then pick **one** of the two ways below to make sure you are never prompted.

### Option A: always pass the file (zero setup, one flag to remember)

```bash
terraform init -backend-config=backend.hcl            # in the lab root
terraform init -backend-config=../backend.hcl         # in image/, which shares the bucket
```

### Option B: let the shell pass it for you (recommended)

Terraform reads extra arguments for a single subcommand from `TF_CLI_ARGS_<subcommand>`.
Export it once per directory with [direnv](https://direnv.net/) and every `terraform init` in
the lab root **and** in `image/` gets the flag automatically. `TF_INPUT=0` turns any remaining
prompt into an error with a clear message, which is what you want when something is wrong.

```bash
cp .envrc.example .envrc     # in the lab root; .envrc is gitignored
direnv allow
```

[`../.envrc.example`](../.envrc.example) contains:

```bash
export TF_CLI_ARGS_init="-backend-config=$PWD/backend.hcl"   # absolute: also right from image/
export TF_INPUT=0                                            # never prompt; fail with a message
```

Why an absolute path: direnv inherits the variable into `image/`, where a relative
`backend.hcl` would point at a file that does not exist. `$PWD` is evaluated once, where the
`.envrc` lives.

In **this** directory the variable is harmless but noisy: `state/` has no `backend` block, so
Terraform prints *"Warning: Missing backend configuration"* and carries on with local state.
To silence it, run `unset TF_CLI_ARGS_init` before `init` here, or add a one-line `.envrc` in this
folder with that command (`.envrc` files are gitignored, so it stays yours).

### What not to do

- **Do not write the bucket name into `backend.tf`.** It commits the project ID.
- **Do not answer the prompt by hand and move on.** The answer is not saved anywhere; you will be
  asked again after any backend change or a fresh clone.

## Second machine, or the local state here is gone

`terraform output -raw backend_config` needs this directory's local `terraform.tfstate`. Without
it, the bucket still exists and carries a label for exactly this moment:

```bash
gcloud config set project $PROJECT_ID
printf 'bucket = "%s"\n' \
  "$(gcloud storage buckets list --filter='labels.purpose=terraform-state' --format='value(name)')" \
  > ../backend.hcl
```

If you also want to manage the bucket from the new machine, re-adopt it with the three
`terraform import` commands at the top of [`main.tf`](main.tf). If you only want to run the lab,
`backend.hcl` is all you need.

## Changing the backend later

| You changed | Run |
|---|---|
| Nothing, but `init` says *Backend configuration changed* | `terraform init -backend-config=backend.hcl` (you forgot the flag; the saved config and the empty one differ) |
| The bucket name in `backend.hcl` (new bucket, same state) | `terraform init -backend-config=backend.hcl -migrate-state` |
| The bucket, and you want to start from the state already in the new one | `terraform init -backend-config=backend.hcl -reconfigure` |
| Your mind: local state instead | Delete `../backend.tf` before the first `init`, or `init -migrate-state` after deleting it to pull the state down |

## If something fails

| Symptom | Cause | Fix |
|---|---|---|
| `bucket` / `Enter a value:` prompt | `init` ran without the backend file | Option A or B above |
| `Failed to get existing workspaces: ... bucket doesn't exist ... 404` | Input is disabled and the backend file was not passed, so the bucket name was empty | Same |
| `storage: bucket doesn't exist` with the flag passed | `backend.hcl` names a bucket in another project, or step 6 was never applied | `gcloud storage buckets list`, compare, re-apply here if missing |
| `403` on the bucket | Logged in as the wrong account, or a second machine's identity is not a `state_writer` | `gcloud auth application-default login`, or add the principal to `state_writers` and re-apply here |
| `Warning: Missing backend configuration` in this directory | `TF_CLI_ARGS_init` inherited from the lab root | Harmless; `unset TF_CLI_ARGS_init` first if it bothers you |
