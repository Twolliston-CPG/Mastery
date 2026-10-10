# AWS Lab VM — Step by Step

> The Linux VM for weeks 1–4, on AWS, built with Terraform. The AWS counterpart of
> [`../gcp-lab/`](../gcp-lab/README.md) — same design, same two distros. Use one cloud or the
> other for the lab VM, not both. Steps marked **Arch** apply only to the Arch path; the
> Ubuntu/Arch differences are in [`../DISTRO.md`](../DISTRO.md).

**Status: validated, not yet applied.** The configuration passes `terraform validate` and a
checkov scan. The steps below have not been run end-to-end; anything marked *untested* is exactly
that.

**This is the one exception to "no AWS resources before week 5."** The rule in
[`START-HERE.md`](../../START-HERE.md) exists to prevent surprise bills, so the guardrails script
moves to day one — step 3 below, before anything is created.

## What you get

| Piece | Detail |
|---|---|
| VM | `lab`, t3.medium (2 vCPU, 4 GB), 20 GB encrypted disk — the same shape as the Multipass VM in Week 1 |
| Network | Its own VPC and subnet. Security groups deny all inbound traffic unless a rule allows it |
| SSH | Only through an EC2 Instance Connect Endpoint — the AWS counterpart of GCP's IAP. Port 22 is never open to the internet |
| Login | Your own key pair. User `ubuntu` on Ubuntu — exactly what the labs are written for — or `arch` on Arch |
| Web | Ports 80/443 closed until you set `open_web = true` (Week 3); `web_source_ranges` narrows who can reach them |
| Identity | No IAM role on the VM — nothing running on it can call AWS APIs. The metadata service requires IMDSv2 |
| Flow logs | On for the VPC (`flow_logs`), in CloudWatch log group `/lab/vpc-flow`, kept 14 days |
| Auto-stop | Stops every night at midnight in `time_zone`. It does not start itself. The scheduler's role can stop this one instance and nothing else |

Rough cost: about $30/month for the VM if it ran continuously, plus under $2/month for the disk
and a small hourly charge for the public IPv4 address while it runs. A few dollars a month if it
only runs while you study. These are estimates, not quotes.

### Deliberate exceptions

Scanners flag these; they are left as they are, on purpose:

- **The VM has a public IP.** It needs outbound access for package installs, and Week 3 serves web
  traffic. The alternative, a NAT gateway, costs more than the VM. Inbound is default-deny.
- **Outbound traffic is unrestricted.** Package mirrors and Let's Encrypt are too many addresses
  to list. Tightening egress is a good exercise once you reach the VPC weeks.
- **Logs and the schedule use AWS-managed encryption**, not customer-managed KMS keys, which cost
  money monthly and protect nothing extra here.
- **The Arch AMI has no fixed publisher check.** See step 5.

---

## One-time setup

### 1. Tools

`bash ../macos-setup.sh` installs everything. The two this needs are the AWS CLI and Terraform.

### 2. Credentials

Sign in as an IAM or Identity Center user with MFA — never the root user. Then confirm who
Terraform will act as:

```bash
aws sts get-caller-identity
```

### 3. Guardrails — before anything is created

```bash
EMAIL=you@example.com bash ../01-aws-guardrails.sh
```

It creates budget alarms at $25, $50 and $100 and exits non-zero if any of them could not be
created. Do the manual steps it prints as well. A budget only alerts; the nightly auto-stop is
what limits the bill.

### 4. A key pair for the lab

```bash
ssh-keygen -t ed25519 -f ~/.ssh/surge-lab -C surge-lab
```

Only the public half (`~/.ssh/surge-lab.pub`) is uploaded. Give the private key a passphrase.

### 5. Arch only — choose the image

Arch publishes no official AWS image. The community builds are listed, per region, at
<http://arch-ami-list.drzee.net/> — take the **x86_64 "std"** AMI ID for your region.

This is an image built by an individual, and you are about to run it. That is an acceptable risk
for a disposable VM that holds no credentials and has no AWS identity; it would not be for
anything else. Look at what you are trusting before you use it:

```bash
aws ec2 describe-images --image-ids ami-xxxxxxxxxxxxxxxxx \
  --query 'Images[0].[Name,OwnerId,CreationDate]' --output text
```

The login user is expected to be `arch` — *untested*. If login is refused, that is the first
thing to check.

### 6. Configure

```bash
cd curriculum/_setup/aws-lab
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
distro      = "arch"                    # or "ubuntu"
arch_ami_id = "ami-xxxxxxxxxxxxxxxxx"   # Arch only, from step 5
time_zone   = "America/New_York"        # for the nightly auto-stop
```

Choose `distro` once. Changing it later replaces the VM and everything on it.

### 7. Build

Terraform's state — its record of what it built — is kept in an S3 bucket, not on your laptop.
Create that bucket once. It has its own tiny configuration in `state/`:

```bash
cd state
terraform init
terraform apply
terraform output -raw backend_config > ../backend.hcl
cd ..
```

Then build the lab, pointing Terraform at the bucket:

```bash
terraform init -backend-config=backend.hcl
terraform plan        # read it before you apply
terraform apply       # the Instance Connect Endpoint takes a few minutes to create
terraform output image
```

The bucket is private, versioned (old state versions are kept 90 days), encrypted at rest,
refuses non-TLS requests, and is locked while an apply is running. If you would rather keep state
in a local file, delete `backend.tf` before the first `terraform init` and skip the `state/` step.

### 8. Connect

Add the lab to your SSH config once, then use plain `ssh`:

```bash
terraform output -raw ssh_config >> ~/.ssh/config
ssh lab
```

This is the `Host lab` block the Week 2 lab has you write, already pointed at the endpoint.

**A tunnel through the endpoint lasts at most one hour**, then the connection drops. Work inside
`tmux` on the VM so a drop costs you nothing: `tmux new -s lab` the first time, `tmux attach -t lab`
after reconnecting.

### 9. Arch only — bootstrap

```bash
scp ../arch-bootstrap.sh lab:~
ssh lab
less arch-bootstrap.sh     # read it first
bash arch-bootstrap.sh
sudo reboot                # if the kernel was upgraded
```

### 10. Take the `clean` snapshot

```bash
ID=$(terraform output -raw instance_id)
VOL=$(aws ec2 describe-instances --instance-ids "$ID" \
  --query 'Reservations[0].Instances[0].BlockDeviceMappings[0].Ebs.VolumeId' --output text)

aws ec2 create-snapshot --volume-id "$VOL" --description clean \
  --tag-specifications 'ResourceType=snapshot,Tags=[{Key=Name,Value=clean}]'
```

You now have what Week 1, Lab 1 asks for. Go back to the lab.

---

## Every session

```bash
ID=$(terraform -chdir=curriculum/_setup/aws-lab output -raw instance_id)

aws ec2 start-instances --instance-ids "$ID"     # the schedule stopped it overnight
aws ec2 wait instance-running --instance-ids "$ID"
ssh lab
```

When you finish, stop it yourself instead of waiting for midnight:

```bash
aws ec2 stop-instances --instance-ids "$ID"
```

The public IP changes on every start. `ssh lab` does not use it, so nothing in weeks 1–2 is
affected.

---

## What the labs say, and what to run here

| Lab says (Multipass) | On AWS |
|---|---|
| `multipass shell lab` | `ssh lab` |
| `multipass stop lab` | `aws ec2 stop-instances --instance-ids "$ID"` |
| `multipass snapshot lab --name pre-bf1` | The `create-snapshot` command from step 10, with `--description pre-bf1` and `Value=pre-bf1` |
| `multipass restore lab.clean` | Rebuild, or replace the root volume from the snapshot — see below |
| `multipass delete lab` | `terraform destroy` |
| Week 2 — `User ubuntu`, `AllowUsers ubuntu` | Correct as written on the Ubuntu path. On Arch, use `arch` |
| Week 2 — `Host lab` SSH config | Already done in step 8 |
| Week 3 — open web ports | Set `open_web = true` in `terraform.tfvars`, then `terraform apply` |
| Gate 1 — "from a fresh VM" | `terraform apply -replace=aws_instance.lab`, then fix the SSH config as below |

---

## Recovering a broken VM

**Rebuild — always works.** You lose what was on the VM and get a clean one:

```bash
terraform apply -replace=aws_instance.lab
```

The new VM has a new instance ID, so the `Host lab` block in `~/.ssh/config` is stale. Delete the
old block and add the new one from `terraform output -raw ssh_config`. Then bootstrap again on Arch.

**Restore a snapshot in place — untested with this configuration.** Unlike GCP, AWS can swap a
running instance's root volume for one made from a snapshot, keeping the instance ID and your SSH
config:

```bash
aws ec2 create-replace-root-volume-task --instance-id "$ID" --snapshot-id snap-xxxxxxxxxxxxxxxxx
```

Run `terraform plan` afterwards and read it before applying anything.

**Locked out of SSH** (the intended Week 2 failure): the snapshot restore above is the way back.
Take a snapshot immediately before the hardening lab.

---

## The nightly teardown script

[`../03-teardown.sh`](../03-teardown.sh) destroys every Terraform directory it finds. This one
contains a `.teardown-skip` file, so that script leaves the lab VM alone — it holds your work
between sessions and stops itself at night instead.

---

## Tearing it all down

```bash
terraform destroy                        # the lab; the state bucket is separate and stays
aws ec2 describe-snapshots --owner-ids self --query 'Snapshots[].[SnapshotId,Description]' --output text
aws ec2 delete-snapshot --snapshot-id snap-xxxxxxxxxxxxxxxxx    # once per snapshot; Terraform does not manage them
```

To remove the state bucket as well, once the lab is destroyed: in `state/`, run
`terraform apply -var force_destroy=true`, then `terraform destroy`. Without that flag, destroy
refuses while the bucket still holds state versions — deliberately.

Remove the `Host lab` block from `~/.ssh/config`. The budgets from step 3 stay — you want them for
week 5 onward.

---

## If something fails

| Symptom | Cause and fix |
|---|---|
| `Unable to locate credentials` | Step 2. Terraform uses the same credentials as the AWS CLI |
| `no such file` on `surge-lab.pub` during plan | Step 4 was skipped, or the key is elsewhere — set `ssh_public_key_path` |
| `distro = "arch" needs arch_ami_id` | Step 5 |
| `ssh lab` hangs or is refused right after apply | The endpoint or the VM is still starting. Wait two minutes. If the VM is stopped, start it |
| `Permission denied (publickey)` | Wrong login user for the image, or the key in `~/.ssh/config` is not the one from step 4 |
| The session drops after an hour | Expected — the endpoint's tunnel limit. Reconnect and `tmux attach -t lab` |
| `ssh lab` fails after a rebuild | The instance ID changed. Refresh the `Host lab` block |
| `Backend initialization required` or `bucket does not exist` | Step 7: create the bucket in `state/`, write `backend.hcl`, then `terraform init -backend-config=backend.hcl` |
| `terraform plan` wants to replace the VM unexpectedly | `distro`, `arch_ami_id`, or the key pair changed. Do not apply until you know which |

## Files

| File | Purpose |
|---|---|
| `versions.tf` | Terraform and provider versions, provider config |
| `variables.tf` | Every setting, with defaults |
| `main.tf` | Network, security groups, endpoint, flow logs, VM, auto-stop schedule |
| `outputs.tf` | Instance ID, SSH command and config block, image details |
| `terraform.tfvars.example` | Copy to `terraform.tfvars` |
| `.teardown-skip` | Tells `03-teardown.sh` to leave this directory alone |
| `.gitignore` | Keeps state, variables, and the provider cache out of any repository |
| `backend.tf` | Tells Terraform to keep state in the S3 bucket |
| `backend.hcl` | Created in step 7: the bucket's name and region. Not committed |
| `state/` | Creates the state bucket. Its own state is a local file in that folder — keep it |
