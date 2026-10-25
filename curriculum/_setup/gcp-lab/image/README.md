# Building the Arch image — step by step

> Google publishes no Arch Linux image. This directory takes the official Arch cloud image that
> Arch itself builds every month, proves it is theirs, converts it into the one format Compute
> Engine imports, and creates a custom image **in your own project** under the family `arch`.
> From then on the lab VM references that family exactly as the Ubuntu path references Google's.
> Ubuntu users never come here.

**Status (2026-10-25):** this pipeline has been run end to end twice (builds `20261001` and
`20261015`, both in `_build/` on the machine that ran it) and the image was later destroyed with
the lab; the `image/` state object exists and is empty. Rebuilding is the steps below, in order.
The Windows path (`fetch.ps1`) has been run under PowerShell on macOS, not on Windows.

The design behind it is [Figure 5 in `../../ARCHITECTURE.md`](../../ARCHITECTURE.md#figure-5--gcp-state-and-image-supply-chain);
the lab runbook that calls this is [`../README.md` step 8](../README.md#8-arch-only--import-the-image).

---

## 1. What gets built, stage by stage

| Stage | Tool | What happens | Where it lands |
|---|---|---|---|
| Find | `fetch.sh` / `fetch.ps1` | Reads the mirror's `latest/` listing for the current build number, for example `20261015.611680`. The date part becomes the image name | stdout: `Build … -> image arch-20261015` |
| Download | `curl` | The qcow2 (about 570 MB), its `.SHA256`, and its `.sig`. Files already present are not fetched again | `_build/` |
| Verify | `shasum`, `gpgv` | The SHA256 must match the mirror's file, **and** the signature must be by the pinned arch-boxes key. Either failure stops the script before anything is converted. §4 explains what each check proves | stdout: `Good signature by arch-boxes …` |
| Convert | `qemu-img` | qcow2 → raw, padded to a whole GiB, because the image API requires it. About a minute | `_build/disk.raw`, deleted after packaging |
| Package | `tar` | A gzip tarball containing exactly one file named `disk.raw`, the only layout the API accepts. Same build, same tarball: a re-run reuses it rather than rewriting it, so Terraform never re-uploads an identical image | `_build/arch-<date>.tar.gz` |
| Hand off | `fetch.sh` | Two lines Terraform reads: the build date and the tarball path | `build.auto.tfvars` |
| Upload | Terraform | Into a staging bucket named `<project>-images`, separate from the state bucket | `gs://<project>-images/arch-<date>.tar.gz` |
| Create | Terraform | `google_compute_image` named `arch-<date>`, family `arch`, declared UEFI-, gVNIC- and multiqueue-SCSI-capable. Five to ten minutes | the image, in your project |

The image name contains the family name on purpose: the lab's VM references the family, and the
provider suppresses a needless VM rebuild only when the resolved image name contains it.

---

## 2. Prerequisites

Everything in `../README.md` up to and including **step 6**, the state bucket. In particular:

- `gcloud auth login` **and** `gcloud auth application-default login`, both done.
- `PROJECT_ID` set in your shell to the lab project.
- `../backend.hcl` written by `state/`. This configuration keeps its state in the same bucket
  under the prefix `image/`, so `terraform init` here needs that file too.
- The tools, by platform:

| Platform | Install | Provides |
|---|---|---|
| macOS | `brew install qemu gnupg` (`brew install gnu-tar` optional) | `qemu-img`; `gpg` and `gpgv`; GNU tar writes sparse members, bsdtar works without it |
| Linux | your package manager's `qemu-img` (often `qemu-utils`) and `gnupg` | the same |
| Windows | `choco install qemu gnupg -y` in an elevated PowerShell, then a **new** terminal | `qemu-img`, `gpg`, `gpgv`; `tar.exe` and `curl.exe` ship with Windows 10 1803 and later |

`fetch.sh` checks for its tools before it downloads anything, so a missing one costs seconds,
not a 570 MB download.

---

## 3. Build it

From this directory:

```bash
cd curriculum/_setup/gcp-lab/image

bash fetch.sh
#   ==> Build 20261015.611680 -> image arch-20261015
#   ==> Downloading Arch-Linux-x86_64-cloudimg-20261015.611680.qcow2        (about 570 MB)
#   ==> SHA256
#   ==> GPG signature
#       Good signature by arch-boxes <arch-boxes@archlinux.org> (1B9A1698…326C6F8F)
#   ==> qemu-img check
#   ==> Converting to disk.raw
#   ==> Padding disk.raw to 2 GiB
#   ==> Writing arch-20261015.tar.gz
#   ==> Wrote build.auto.tfvars. Next: terraform init ...

cat build.auto.tfvars
#   build   = "20261015"
#   tarball = "_build/arch-20261015.tar.gz"

terraform init -backend-config=../backend.hcl    # state in the lab's bucket, prefix "image"
terraform plan                                   # 2 API enablements, the staging bucket, the tarball object, the image
terraform apply -var project_id=$PROJECT_ID      # upload, then image creation: 5 to 10 minutes
terraform output image
#   arch-20261015 (2 GB, family arch)
```

**Windows**, PowerShell (not Git Bash):

```powershell
cd curriculum\_setup\gcp-lab\image
.\fetch.ps1                                      # same stages, same checks, same outputs
terraform init -backend-config=../backend.hcl
terraform plan
terraform apply -var project_id=$env:PROJECT_ID
terraform output image
```

If `qemu-img` or `gpgv` is not found after a new terminal, the installer did not add itself to
`PATH`; the script also looks in `C:\Program Files\qemu` and `C:\Program Files (x86)\GnuPG\bin`.

### What Terraform creates

| Resource | Why it is there |
|---|---|
| `google_project_service.compute`, `.storage` | The two APIs this needs, enabled and left enabled on destroy |
| `google_storage_bucket.images` | Staging only, `<project>-images`, uniform access, public access prevented, `force_destroy` so teardown is one command. Separate from the state bucket: audit-logged state storage should not have a 600 MB neighbour |
| `google_storage_bucket_object.tarball` | The tarball, kept rather than expired: a lifecycle rule that deleted it would make Terraform want to re-upload it on every plan after it was gone. About a cent a month |
| `google_compute_image.arch` | The image. `create_before_destroy`, so a newer build is created and the family moved before the old image is removed; a 30-minute create timeout, because the import is slow |

### Check it before you use it

```bash
gcloud compute images describe-from-family arch --project=$PROJECT_ID \
  --format='table(name,family,creationTimestamp.date(),diskSizeGb,status,labels.build)'
gcloud compute images describe arch-20261015 --project=$PROJECT_ID --format='value(guestOsFeatures[].type)'
#   UEFI_COMPATIBLE;GVNIC;VIRTIO_SCSI_MULTIQUEUE
```

The boot test is the lab itself: `terraform apply` in `..` with `distro = "arch"`, then
`$(terraform output -raw ssh_command)`. If the VM never answers, read its console before
guessing:

```bash
gcloud compute instances get-serial-port-output lab --zone=$ZONE --project=$PROJECT_ID | head -60
```

A hang before the kernel is the UEFI path; see §7. After login, `df -h /` should show the lab's
20 GB disk, not the image's 2 GB: cloud-init grows the root filesystem on first boot.

---

## 4. The two checks, and what each one proves

- **The SHA256** is downloaded from the same mirror as the image. A match proves the download is
  not corrupt. It proves nothing about who made the file, because an attacker who could change
  the image could change the checksum beside it.
- **The PGP signature** is the provenance check. Arch's CI signs every cloud image with the
  `arch-boxes <arch-boxes@archlinux.org>` key. That key's public half is in [`arch-boxes.asc`](arch-boxes.asc),
  and the script accepts an image only if `gpgv` reports a valid signature **and** the signing
  key's primary fingerprint is `1B9A 1698 4A4E 8CB4 4871 2D2A E0B7 8BF4 326C 6F8F`. A signature by
  any other key, an expired key, or no signature stops the script with
  `image is NOT signed by the pinned arch-boxes key`.

The check runs `gpgv`, the verify-only tool package managers use, against a dearmored copy of
that one key (`_build/arch-boxes.gpg`). Nothing is imported into `~/.gnupg`, no agent starts, and
nothing else you happen to trust can sway the result. That is also why it is `gpgv` and not
`gpg --verify`: a plain import into a fresh keyring tries to launch an agent, which fails on
macOS when the socket path is long, and the first version of this script stopped silently there.

**Where the key comes from.** It is copied from the arch-boxes project README, which embeds it
under "Every release is signed by our CI with the following key". It is **not** certified by
Arch's master keys and is not on the public keyservers, which is why a bare `gpg --verify` cannot
find it and why it ships here. The pinned value is the *primary* fingerprint: signing subkeys
rotate, the primary does not.

This is the lesson Figure 5 teaches, and the question to be able to answer: *"A checksum matched.
Is the image safe?"* No. Say which link in the chain the signature protects and which it does not.

---

## 5. Pinning, overriding, and the last resort

| Want | Do |
|---|---|
| A specific build, for example during a gate week so every rebuild is identical | `BUILD=20261001.604814 bash fetch.sh`, then `terraform apply`. The full build id with its suffix, because the mirror's directory is `v<build>/` |
| A different mirror | `MIRROR=https://<mirror>/images bash fetch.sh`. The checks are the same whichever mirror serves the file |
| Checksum only, no signature | `SKIP_GPG=1 bash fetch.sh`. It warns loudly. The only honest use is the rare case the project has rotated its key and you have confirmed the new one by hand (§6); never the normal path |
| Force a fresh conversion | `rm _build/arch-<date>.tar.gz` and re-run; the qcow2 is kept and re-verified |
| The disk space back | `rm -rf _build/` after a successful apply. Keep the current tarball if you may re-apply soon: without it, Terraform wants the file to upload |

---

## 6. Keeping it current, and rolling back

**Monthly.** Arch publishes a new build on the first of each month. Re-run:

```bash
bash fetch.sh && terraform apply -var project_id=$PROJECT_ID
```

Terraform creates `arch-<newdate>` first, points the family at it, then removes the old image and
the old tarball object. **The running VM is not touched**: its disk was copied from the old image
when it was created, and its next `pacman -Syu` is what brings it current. The new image is used
the next time the VM is rebuilt, so a Gate 1 "from a fresh VM" rebuild
(`terraform apply -replace=google_compute_instance.lab` in `..`) is the natural moment to refresh.
Monthly is plenty; the first upgrade on a VM built from a one-month-old image takes a minute.

**Rolling back** is the same command with the previous build pinned:

```bash
BUILD=20261001.604814 bash fetch.sh && terraform apply -var project_id=$PROJECT_ID
```

The name changes back to `arch-20261001`, so `create_before_destroy` builds it first and the
family follows. If `_build/` still holds that build's tarball, nothing is downloaded. If not,
`fetch.sh` fetches it from the mirror's `v<build>/` directory; mirrors keep recent builds, not
all of them, so keep the previous tarball until the new build has booted at least once.

**The key, in May 2027.** The signing subkey in `arch-boxes.asc` expires then, and the script
will stop with `EXPKEYSIG`. Refresh the file with the one-line command in its header, then
compare fingerprints **before** committing it:

```bash
gpg --show-keys --with-fingerprint arch-boxes.asc
```

The primary must still read `1B9A 1698 4A4E 8CB4 4871 2D2A E0B7 8BF4 326C 6F8F`. A changed primary
means a changed owner; read the project's announcements before trusting it, and update
`ARCH_BOXES_FPR` in both fetch scripts only when you have.

---

## 7. If something fails

| Symptom | Cause and fix |
|---|---|
| `qemu-img not found` or `gpgv not found` | §2. On Windows, a new terminal after `choco install`; the installers change `PATH` for new sessions only |
| `could not find a cloudimg build in …/latest/` | The mirror's listing changed shape or was unreachable. Try `MIRROR=`, or pin `BUILD=` from the mirror's `images/` directory in a browser |
| `shasum: … FAILED` | A corrupt or truncated download. `rm _build/Arch-Linux-x86_64-cloudimg-<build>.qcow2` and re-run |
| `image is NOT signed by the pinned arch-boxes key` | Either the mirror served a file that is not Arch's, or the project rotated its key. Do not use the image. §6 |
| `EXPKEYSIG` | The signing subkey expired (May 2027). Refresh `arch-boxes.asc` per its header, compare the primary fingerprint, re-run |
| `terraform init` asks for a bucket | `../backend.hcl` is missing: `state/` was not applied or its output not written. `../README.md` step 6 |
| `apply` fails creating the bucket: name taken | `<project>-images` is a global name. Another project of yours or someone else's holds it; set `location` or rename the bucket in `main.tf` for your copy |
| `apply` times out creating the image | The import is slow on a busy day; the timeout is 30 minutes. Run `apply` again: the operation resumes from the uploaded object |
| The lab's plan says `family … not found` | The image is not in this project: this directory was never applied, or was destroyed before the lab. Apply here first; to destroy the lab anyway, `terraform destroy -var lookup_image=false` in `..` |
| The VM never answers on SSH after a rebuild, console hangs before the kernel | The UEFI path. Remove `UEFI_COMPATIBLE` from `guest_os_features` in `main.tf`, `terraform apply` here, then `-replace` the VM in `..` so it boots through the BIOS/GPT hybrid path |
| `Permission denied (publickey)` as `arch@` | Not this directory. The key in the VM's metadata is read by cloud-init at first boot only; `../README.md` step 8 and the Arch table there |

---

## 8. Tearing it down

After the lab, never before it: the lab looks up the `arch` family to report its build, and a
data source that cannot be read blocks every plan, destroy included.

```bash
(cd .. && terraform destroy)                       # the lab first
terraform destroy -var project_id=$PROJECT_ID      # the image, the tarball object, the staging bucket
```

If the image is already gone and the lab refuses to plan: `terraform destroy -var lookup_image=false` in `..`.

Cost while it exists: the tarball in Standard storage is about a cent a month; a 2 GB custom image
is a few cents a month. `03-teardown.sh` skips this directory (`.teardown-skip`), because
destroying the image nightly would mean a 600 MB re-import every morning.

---

## 9. The alternative, and why it is not used

Google's own [compute-archlinux-image-builder](https://github.com/GoogleCloudPlatform/compute-archlinux-image-builder)
builds an Arch image from scratch in a chroot, installs Google's guest agent, and is how the
community `arch-linux-gce` images were made. It is the better image for OS Login, and its last
build is from September 2022. Rebuilding it today means maintaining a build host and a package
list that Arch's own CI already maintains for you. Importing the official monthly image trades the
guest agent for a current kernel, a current keyring, and a signature from the project that builds
Arch; the consequences of that trade are the Arch column in
[`../README.md`](../README.md#what-is-different-on-arch).

---

## Files

| File | Purpose |
|---|---|
| `fetch.sh` | macOS and Linux: find, download, verify, convert, package; writes `build.auto.tfvars` |
| `fetch.ps1` | The same stages in PowerShell 5.1+, for Windows. Not yet run on Windows |
| `main.tf` | Variables, the staging bucket, the tarball object, the image under family `arch` |
| `backend.tf` | State in the lab's bucket under the prefix `image/`; `terraform init -backend-config=../backend.hcl` |
| `arch-boxes.asc` | The public key Arch's CI signs cloud images with, and in its header the command to refresh it |
| `build.auto.tfvars` | Written by `fetch.sh`: the build date and the tarball path. Not committed |
| `_build/` | Downloads, the dearmored key, `disk.raw` while converting, the tarball. Not committed; about 3 GB per build |
| `.teardown-skip` | Keeps `03-teardown.sh` away from the image |
| `.gitignore` | Everything above that is large, reproducible, or project-specific |
