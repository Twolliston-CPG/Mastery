# GCP Lab VM — Step by Step

> The Linux VM for weeks 1–4, on GCP, built with Terraform. Works for either distro; the steps
> marked **Arch** apply only to the Arch path. Background and the Ubuntu/Arch differences are in
> [`../DISTRO.md`](../DISTRO.md).

**Status: `state/` and `image/` applied (image `arch-20261001`); the lab plans cleanly and has
not yet been applied.** All three configurations pass `terraform validate`. Steps 10 onward have
not been run end-to-end; anything marked *untested* is exactly that.

## What you get

| Piece | Detail |
|---|---|
| VM | `lab`, e2-medium (2 vCPU, 4 GB), 20 GB disk — the same shape as the Multipass VM in Week 1 |
| Network | Its own VPC and subnet. All inbound traffic is denied unless a rule below allows it |
| SSH | Only through Identity-Aware Proxy. Port 22 is never open to the internet. Project-wide SSH keys are blocked; only keys added to this VM work |
| Web | Ports 80/443 closed until you set `open_web = true` (Week 3); `web_source_ranges` narrows who can reach them |
| Identity | No service account on the VM — nothing running on it can call GCP APIs |
| Image | Ubuntu 24.04 LTS from Google's image family. Arch: the official Arch cloud image, imported into your project by `image/` and kept current by re-running it |
| Boot integrity | Secure Boot, vTPM, and integrity monitoring on Ubuntu. Not on Arch — its kernel is not signed for Secure Boot |
| Flow logs | On for the lab subnet (`flow_logs`), so you can see accepted and denied connections in Logs Explorer |
| Auto-stop | Stops every night at midnight in `time_zone`. It does not start itself. The service agent that runs it gets a custom role with two permissions — start and stop — and nothing else |
| Serial console | Off until you set `enable_serial_console = true` |

### Deliberate exceptions

Scanners (checkov, trivy) flag three things that are left as they are, on purpose:

- **The VM has an external IP.** It needs outbound access for package installs, and Week 3 serves
  web traffic. The alternative, Cloud NAT, costs more than the VM. Inbound is default-deny.
- **Disks use Google-managed encryption keys**, not customer-managed ones. They are still
  encrypted at rest; managing your own key adds a way to lose the disk and nothing a lab needs.
- **OS Login is off.** It is the better practice — SSH access governed by IAM instead of keys in
  metadata — but it is implemented by Google's guest agent, which the Arch image does not have,
  and it changes your username on the VM. Worth turning on for the Ubuntu path once it has been
  run end-to-end; not available on Arch.

Rough cost: about $25/month if it ran continuously, a few dollars a month if it only runs while
you study. These are estimates, not quotes — check the pricing calculator for your region.

---

## One-time setup

### 1. Tools

```bash
brew install --cask gcloud-cli
brew install terraform
```

### 2. Log in — twice

```bash
gcloud auth login                         # for gcloud commands
gcloud auth application-default login     # for Terraform; a separate credential
```

### 3. A dedicated project

Use a personal project that holds nothing else. Deleting it at the end removes everything.
Project IDs are globally unique, so pick your own:

```bash
PROJECT_ID=surge-lab-CHANGEME

gcloud projects create $PROJECT_ID --name="Surge Lab"

# if project_id was created in the console before the lab
PROJECT_ID=thesurge
gcloud config set project $PROJECT_ID
gcloud auth application-default set-quota-project $PROJECT_ID

gcloud billing accounts list
gcloud billing projects link $PROJECT_ID --billing-account=YOUR_BILLING_ACCOUNT_ID
```

### 4. A budget alert — before anything is created

In the console: **Billing → Budgets & alerts → Create budget**. Scope it to this project, set a
monthly amount you would notice (for example $30), and keep the 50% and 90% email thresholds.
A budget only alerts; it does not stop spending. The nightly auto-stop is what limits the bill.

### 5. Enable the APIs Terraform needs to get started

```bash
gcloud services enable \
  compute.googleapis.com iap.googleapis.com \
  cloudresourcemanager.googleapis.com serviceusage.googleapis.com
```

### 6. The state bucket

Terraform's state — its record of what it built — is kept in a Cloud Storage bucket, not on your
laptop. The bucket has to exist before the lab's first `terraform init`, so it is built by a
separate, independent configuration in `state/`: its own root module, its own provider block,
nothing shared with the lab. Apply it once, first:

```bash
cd state
terraform init
terraform plan
terraform apply -var project_id=$PROJECT_ID
terraform output -raw backend_config > ../backend.hcl    # one line: the bucket's name
cd ..
```

`state/` keeps its own state as a local file in that folder. That is the one place local state
is correct — a bucket cannot store the state that creates it — and it is a few hundred bytes
describing one bucket. If the file is ever lost, the import commands at the top of
`state/main.tf` re-adopt the bucket.

What the bucket gives you, and why each setting is there:

| Setting | Why |
|---|---|
| Uniform bucket-level access + public access prevention | IAM only, no per-object ACLs, and it cannot be made public even by mistake. State can hold secrets in plain text |
| Versioning, last ten versions kept | Every write keeps the previous state as a restorable version. The lock object is created and deleted on each apply, so the cap also stops lock debris piling up |
| Soft delete, 7 days | Anything deleted, by the lifecycle rule or by hand, is recoverable for a week |
| Data Access audit logs on Storage | Off by default in GCP. On, so Logs Explorer shows who read or wrote state, and when |
| `prevent_destroy` + `force_destroy = false` | `terraform destroy` in `state/` is refused. Deleting the project removes the bucket anyway |
| Locking | Native to the GCS backend: a `.tflock` object created with an only-if-absent precondition. No lock table to manage |
| `state_writers` (optional) | Grants `roles/storage.objectUser` on the bucket only — read, write, delete objects, nothing about the bucket or its IAM. For a CI service account or a second machine. You, as project owner, need nothing |

If you would rather keep state in a local file, delete `backend.tf` before the first
`terraform init` and skip this step.

### 7. Configure

```bash
cd curriculum/_setup/gcp-lab
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
project_id = "surge-lab-CHANGEME"
distro     = "arch"               # or "ubuntu"
time_zone  = "America/New_York"   # for the nightly auto-stop
```

Choose `distro` once. Changing it later replaces the VM and everything on it.

### 8. Arch only — import the image

Ubuntu users skip to step 9. Google maintains the Ubuntu image family; nobody maintains an Arch
one.

#### Why an imported image

Google does not publish an Arch image. The one community project that does, `arch-linux-gce`,
last built one in **September 2022**. Starting from it means a multi-gigabyte first upgrade, a
pacman keyring too old to verify current packages, and a kernel four years behind the hardware
it boots on. Arch itself publishes a fresh [cloud image](https://geo.mirror.pkgbuild.com/images/latest/)
on the first of every month, signed, with cloud-init installed. Compute Engine cannot boot a
qcow2 file directly, so `image/` turns that file into a custom image **in your own project**,
under the image family `arch`. From then on the lab references the family exactly as the Ubuntu
path references Google's, and nothing outside your project can change what you boot.

What you trade for that: the official image has cloud-init but not Google's guest agent, which is
not in Arch's repositories. The differences that follow are listed under [what is different on
Arch](#what-is-different-on-arch) below. None of them block the labs.

#### What `image/` does

| Stage | Tool | What happens |
|---|---|---|
| Find | `fetch.sh` (macOS, Linux) or `fetch.ps1` (Windows) | Reads the mirror's `latest/` listing for the current build number. `BUILD=20261001.604814 bash fetch.sh` or `.\fetch.ps1 -Build 20261001.604814` pins one |
| Verify | `shasum`, `gpgv` | SHA256 must match, and the file must carry a valid signature from the pinned arch-boxes key shipped in `image/arch-boxes.asc`. Anything else stops the script. Details under [verifying what you download](#verifying-what-you-download) |
| Convert | `qemu-img` | qcow2 → raw, padded to a whole GiB as Compute Engine requires |
| Package | `tar` | A gzip tarball containing one file named `disk.raw`, the only format the image API imports |
| Upload | Terraform | Into a staging bucket, `<project>-images`, separate from the state bucket. The tarball stays there (about a cent a month) so Terraform never fights an expiry rule; a new build replaces it |
| Create | Terraform | `google_compute_image` named `arch-<date>`, family `arch`, declared UEFI-, gVNIC-, and multiqueue-SCSI-capable |

The image name contains the family name on purpose: the lab's VM references the family, and the
provider suppresses a needless rebuild only when the resolved image name contains it.

#### Instructions

**macOS / Linux**

```bash
brew install qemu gnupg                             # qemu-img converts; gpgv verifies. gnu-tar is optional
ssh-keygen -t rsa -b 4096 -f ~/.ssh/google_compute_engine -N ''   # if it does not exist; see step 10 for why

cd image
bash fetch.sh                                       # ~600 MB download, a minute to convert
terraform init -backend-config=../backend.hcl       # state in the same bucket, prefix "image"
terraform plan                                      # 2 API enablements, staging bucket, tarball object, image
terraform apply -var project_id=$PROJECT_ID         # upload plus image creation: 5-10 minutes
terraform output image                              # arch-20261001 (2 GB, family arch)
cd ..
```

**Windows** (PowerShell, not Git Bash — the script is a PowerShell port of `fetch.sh` with the
same checks and the same pinned key). *Untested on Windows*: the logic has been run under
PowerShell on macOS; the Windows-specific parts, install paths and `tar.exe`, have not.

```powershell
choco install qemu gnupg -y          # elevated PowerShell. gnupg is the command-line GnuPG, not gpg4win
# open a NEW terminal: the installers change PATH, and the current session does not see it
ssh-keygen -t rsa -b 4096 -f $HOME\.ssh\google_compute_engine -N '""'   # if it does not exist

cd image
.\fetch.ps1                                        # same stages as fetch.sh
terraform init -backend-config=../backend.hcl
terraform plan
terraform apply -var project_id=$env:PROJECT_ID
terraform output image
cd ..
```

If `qemu-img` or `gpgv` is still not found after a new terminal, the installer did not add
itself to PATH. The script also looks in `C:\Program Files\qemu` and
`C:\Program Files (x86)\GnuPG\bin`, which is where the two installers put things by default; if
you installed elsewhere, add that folder to PATH. `tar.exe` and `curl.exe` ship with Windows 10
1803 and later, so nothing else is needed. Everything from `terraform init` on is identical to
the macOS path, and the resulting tarball is byte-for-byte the same format.

`fetch.sh` checks for its tools before downloading anything, skips downloads it already has,
re-verifies, and reuses the tarball if this build's already exists, so a re-run is a few seconds and
changes nothing Terraform would re-upload. Delete the tarball to force a rebuild. Downloads, the dearmored key, and the tarball live in `image/_build/`;
`build.auto.tfvars`, the two lines Terraform reads, sits next to `main.tf`. Both are ignored by
git. Delete `_build/` after a successful apply if you want the 3 GB back.

#### Verifying what you download

Two checks run, and they prove different things:

- **The SHA256** is fetched from the same mirror as the image. A match proves the download is not
  corrupt. It proves nothing about who made the file.
- **The PGP signature** is the provenance check. Arch's CI signs every cloud image with the
  `arch-boxes <arch-boxes@archlinux.org>` key. That key's public half is in `image/arch-boxes.asc`,
  and the script accepts an image only if `gpgv` reports a valid signature **and** the signing
  key's primary fingerprint is `1B9A 1698 4A4E 8CB4 4871 2D2A E0B7 8BF4 326C 6F8F`. A signature by
  any other key, an expired key, or no signature stops the script with
  `image is NOT signed by the pinned arch-boxes key`.

Where the trust comes from: the key is copied from the arch-boxes project README, which embeds
it under "Every release is signed by our CI with the following key". It is **not** certified by
Arch's master keys and is not on keys.openpgp.org, so a bare `gpg --verify` cannot find it; that
is why it ships here. Its signing subkey expires in **May 2027**. When it does, or if the project
rotates keys, the header of `arch-boxes.asc` has the one-line command to pull the current key from
the README. Compare the primary fingerprint before committing the new file: a changed primary
means a changed owner, and deserves a look at the project's announcements.

The check uses `gpgv` with a dearmored copy of that one key, not your keyring. Nothing is
imported into `~/.gnupg`, no gpg-agent starts, and the result cannot be swayed by what else you
trust. `SKIP_GPG=1 bash fetch.sh` bypasses the signature for the rare case the key really has
rotated and you have confirmed the new one by hand; it warns loudly and should never be the
normal path.

#### Keeping it current

Re-run `bash fetch.sh && terraform apply` in `image/` when a new monthly build is out. Terraform
creates the new image first, points the family at it, then deletes the old one. The running VM
is not touched — its disk was copied from the old image when it was created — and its next
`pacman -Syu` is what brings it current. The new image is used the next time the VM is rebuilt,
so a Gate 1 "from a fresh VM" rebuild is the natural moment to refresh. Monthly is plenty; the
first upgrade on a VM built from a one-month-old image takes a minute.

#### What is different on Arch

| On Ubuntu | On Arch | Why |
|---|---|---|
| Log in as yourself; `gcloud compute ssh lab` creates your user on the fly | Log in as `arch`: `gcloud compute ssh arch@lab` | Google's guest agent creates users from metadata. Arch has only cloud-init, which created one user, `arch` |
| Add an SSH key at any time | The key must be in metadata **before first boot**. Terraform puts it there from `ssh_public_key_file` | cloud-init reads metadata keys once, at first boot, for its default user only. A key added later is ignored until the VM is rebuilt |
| OS Login possible | Not possible | OS Login is implemented by the guest agent |
| Secure Boot on | Off | Arch's kernel is not signed for Secure Boot |
| Serial console login works after `sudo passwd $USER` | Same, but the user is `arch` and starts with no password | cloud-init images ship the default user with key-only access |

`terraform output -raw ssh_command` prints the right login form for your distro, so you need not
remember any of this day to day.

### 9. Build

Point Terraform at the bucket, then build the lab:

```bash
terraform init -backend-config=backend.hcl
terraform plan        # read it: network, subnet, firewall rule, custom role + grant, schedule, VM, 2 API enablements
terraform apply
```

### 10. Connect

```bash
terraform output image                 # which image build you got, and when it was made
$(terraform output -raw ssh_command)   # opens a shell on the VM through IAP
```

**Ubuntu:** the first connection generates `~/.ssh/google_compute_engine` and creates your user
on the VM. Run `whoami` and note the name — Week 2 needs it.

**Arch:** you are `arch`, and the key you generated in step 8 is the one in the VM's metadata.
That is why it had to exist before `apply`; the reason is in the table above.

### 11. Arch only — bootstrap

A fresh Arch image lacks much of what Ubuntu ships by default. From this directory on your
workstation:

```bash
$(terraform output -raw bootstrap_command)   # copies arch-bootstrap.sh to the VM
```

Then on the VM:

```bash
less arch-bootstrap.sh     # read it first
bash arch-bootstrap.sh
sudo reboot                # if the kernel was upgraded
```

If the upgrade stops on signature errors, the image's keyring is stale:
`sudo pacman -Sy archlinux-keyring && sudo pacman -Su`, then re-run the script. With a current
monthly image this should not happen; it is the symptom of starting from an old build.

### 12. Take the `clean` snapshot

```bash
gcloud compute disks snapshot lab --zone=us-central1-a --snapshot-names=clean
```

You now have what Week 1, Lab 1 asks for. Go back to the lab.

---

## Every session

```bash
gcloud compute instances start lab --zone=us-central1-a     # the schedule stopped it overnight
$(terraform -chdir=curriculum/_setup/gcp-lab output -raw ssh_command)
```

When you finish, stop it yourself instead of waiting for midnight:

```bash
gcloud compute instances stop lab --zone=us-central1-a
```

The external IP changes on every start. Nothing in weeks 1–2 depends on it.

---

## When a lab asks for it

| Lab step | What to do |
|---|---|
| "Snapshot your VM first" (every break/fix lab) | `gcloud compute disks snapshot lab --zone=us-central1-a --snapshot-names=pre-bf1` |
| Week 2 — SSH config and hardening | Use the `Host lab` block and the `AllowUsers` warning in [`../DISTRO.md`](../DISTRO.md#week-2--ssh-to-the-gcp-vm) |
| Week 3 — open web ports | Set `open_web = true` in `terraform.tfvars`, then `terraform apply` |
| Week 3 — stop exposing web ports | Set it back to `false` and apply again |
| Gate 1 — "from a fresh VM" | `terraform apply -replace=google_compute_instance.lab`, then the bootstrap step again on Arch. Refresh the image first (step 8) if a newer monthly build is out |

---

## Recovering a broken VM

**Fastest, always works: rebuild.** You lose what was on the VM and get a clean one in about a
minute:

```bash
terraform apply -replace=google_compute_instance.lab
```

**Locked out of SSH but want to fix it in place** (the intended Week 2 failure): connect to the
serial console instead. Two things must be true *before* the hardening lab, because you cannot do
either once you are locked out of a broken VM: your user has a password (`sudo passwd $USER` on
the VM), and the serial console is enabled — set `enable_serial_console = true` in
`terraform.tfvars` and `terraform apply`. Then:

```bash
gcloud compute connect-to-serial-port lab --zone=us-central1-a
```

Set it back to `false` and apply when the week is done. An interactive serial console is a second
way into the VM that the firewall does not cover.

**Restoring a snapshot onto the Terraform-managed VM — untested.** There is no in-place restore on
GCP; you swap the boot disk for one created from the snapshot. Expect Terraform to notice the
changed disk on the next plan. Until this has been run once and written up here, prefer the
rebuild above and treat snapshots as a record of a known-good state rather than a quick undo.

---

## The nightly teardown script

[`../03-teardown.sh`](../03-teardown.sh) destroys every Terraform directory it finds. This one
contains a `.teardown-skip` file, so that script leaves the lab VM alone — it holds your work
between sessions and stops itself at night instead. Delete `.teardown-skip` if you would rather
the VM be destroyed nightly and rebuilt each session.

---

## Tearing it all down

```bash
terraform destroy                        # the lab FIRST; the state bucket is separate, stays, and refuses `destroy`
(cd image && terraform destroy)          # Arch only, AFTER the lab: the custom image and its staging bucket
gcloud compute snapshots list            # snapshots are not managed by Terraform
gcloud compute snapshots delete clean pre-bf1
gcloud projects delete $PROJECT_ID       # removes anything left, and stops all billing for it
```

Order matters on Arch: the lab looks up the `arch` image family to report its build, and a
data source that cannot be read blocks every plan, destroy included. If `image/` went first,
destroy the lab with `terraform destroy -var lookup_image=false`.

---

## If something fails

| Symptom | Cause and fix |
|---|---|
| `API … has not been used in project … or it is disabled` | Step 5 was skipped, or the API is still propagating. Run step 5, wait a minute, apply again |
| Apply fails attaching `lab-auto-stop` with a permissions error | The IAM grant to the Compute Engine service agent has not propagated. Run `terraform apply` again |
| `ZONE_RESOURCE_POOL_EXHAUSTED` | No capacity in that zone right now. Change `zone` in `terraform.tfvars` to another zone in the same region |
| SSH fails with `4003: failed to connect to backend` | The VM is stopped (start it), or `sshd` is not accepting connections — use the serial console or rebuild |
| SSH fails with a permission error on the tunnel | You are not logged in as the project owner. `gcloud auth list` |
| `Backend initialization required` or `bucket doesn't exist` | Step 6: create the bucket in `state/`, write `backend.hcl`, then `terraform init -backend-config=backend.hcl` |
| `Error acquiring the state lock` | Another apply is running, or one was killed and left its lock behind. Confirm nothing else is applying, then `terraform force-unlock <ID>` with the ID from the error |
| `terraform plan` wants to replace the VM unexpectedly | `distro` changed, or the boot disk was swapped outside Terraform. Do not apply until you know which |
| `fetch.sh` / `fetch.ps1`: `qemu-img not found` or `gpgv not found` | `brew install qemu gnupg`, or on Windows `choco install qemu gnupg -y` and then a new terminal. Both scripts check before downloading, so nothing was fetched yet |
| `fetch.sh`: `image is NOT signed by the pinned arch-boxes key` | Either the mirror served a file that is not Arch's, or the project rotated its key. Do not use the image. Pull the current key with the command in `image/arch-boxes.asc` and compare the primary fingerprint; if it changed, read the project's announcements before trusting it |
| `fetch.sh`: signature check fails with `EXPKEYSIG` | The signing subkey expired (May 2027). Refresh `image/arch-boxes.asc` per its header, then re-run |
| Arch: `error retrieving image information` or `family … not found` | The image is not in this project: not imported yet (step 8), or `image/` was destroyed before the lab. To destroy the lab anyway, `terraform destroy -var lookup_image=false` |
| Arch: VM never answers on SSH after a rebuild | Boot or cloud-init failed. `gcloud compute instances get-serial-port-output lab --zone=$ZONE` shows the console. If it hangs before the kernel, remove `UEFI_COMPATIBLE` from `guest_os_features` in `image/`, re-apply, and `-replace` the VM |
| Arch: `Permission denied (publickey)` as `arch@` | The key in metadata is not the one you are offering, or was added after first boot. Check `ssh_public_key_file` matches `~/.ssh/google_compute_engine`, then `terraform apply -replace=google_compute_instance.lab` |
| `Required 'compute.images.get' permission for 'projects/arch-linux-gce/global/images/arch'` | Not your IAM. The `project/family` shorthand makes the provider probe for an image *named* `arch` first, and that project answers 403 rather than 404. `main.tf` uses the full `projects/…/global/images/family/…` path for this reason; check it was not shortened |

## Files

| File | Purpose |
|---|---|
| `versions.tf` | Terraform and provider versions, provider config |
| `variables.tf` | Every setting, with defaults |
| `main.tf` | Network, firewall, auto-stop schedule, VM |
| `outputs.tf` | SSH command, IP, image build, Arch bootstrap command |
| `terraform.tfvars.example` | Copy to `terraform.tfvars` |
| `.teardown-skip` | Tells `03-teardown.sh` to leave this directory alone |
| `.gitignore` | Keeps state, variables, and the provider cache out of any repository |
| `backend.tf` | Tells Terraform to keep state in the Cloud Storage bucket |
| `backend.hcl` | Created in step 6: the bucket's name. Not committed |
| `image/` | Arch only, step 8. `fetch.sh` downloads and converts the newest Arch cloud image; `main.tf` uploads it and creates the custom image under family `arch`. Applied before the lab, re-applied for newer builds |
| `image/fetch.ps1` | Windows port of `fetch.sh`: same stages, checks, and outputs, in PowerShell 5.1+. Tools via `choco install qemu gnupg`. Not yet run on Windows |
| `image/arch-boxes.asc` | The public key Arch's CI signs cloud images with, copied from the arch-boxes project README. `fetch.sh` refuses an image not signed by it. The header says how to refresh it when the signing subkey expires (May 2027) |
| `state/` | Independent configuration that creates the state bucket. Applied once, before the lab. Its own state is a local file in that folder — keep it, or re-import per the comments in `state/main.tf` |
