# Choosing a Distro — Ubuntu or Arch

> The labs are written for Ubuntu. This page is everything that changes if you run them on Arch
> instead. The concepts — systemd, iptables, namespaces, cgroups — are identical on both; only
> package names, a few paths, and the defaults differ.

**Status: draft, 2026-10-03.** The Arch column is written from documentation and has **not yet been
run end-to-end on an Arch VM**. Treat every Arch command as "expected to work" until the
*Last verified* line below carries a date.

**Last verified on Arch:** not yet

---

## Which path

| | Ubuntu path | Arch path |
|---|---|---|
| **VM** | Multipass on your machine, Ubuntu 24.04 (Week 1, Lab 1) — or a cloud VM, as for Arch | Cloud x86 VM: GCP (below) or [AWS](aws-lab/README.md) |
| **Cost** | Free | Roughly $25/month if left running; far less if you stop it between sessions |
| **Labs** | Run exactly as written | Same labs; each step that differs has an **Arch path** note |
| **Releases** | Fixed LTS — a lab that works today works in six months | Rolling — expect occasional drift from what is written |
| **Choose it if** | You want the documented path, or you are heading into a job search — production fleets are Debian- and RHEL-family | You already know one distro and want to learn what is convention and what is Linux |

The choice only matters for **weeks 1–4**. After Gate 1 the work moves into containers and cloud
services, and the host distro stops mattering. The `runs-on: ubuntu-latest` lines in weeks 12 and 18
are CI runners, and the Debian base images in week 18 are container bases — neither depends on
which path you chose.

**Gates are distro-neutral.** Gate 1 says "from a fresh VM"; either distro passes. If you are
job-hunting, do the gate itself on Ubuntu even if you studied on Arch.

`_setup/00-toolchain.sh` supports macOS and Debian/Ubuntu only — it has no Arch branch. Do not run
it inside the Arch VM; install what each lab needs with `pacman`, per the table below.

---

## The Arch VM on GCP

Official Arch is x86_64 only, so on an Apple Silicon Mac a cloud x86 VM is simpler than emulating
one locally. You need a GCP project with billing enabled and the
[gcloud CLI](https://cloud.google.com/sdk/docs/install) installed and authenticated.

Google does not publish an Arch image. The community `arch-linux-gce` project does, built by
[compute-archlinux-image-builder](https://github.com/GoogleCloudPlatform/compute-archlinux-image-builder),
but its newest build is from September 2022:

```bash
gcloud compute images describe-from-family arch --project=arch-linux-gce \
  --format='value(name,creationTimestamp)'
```

Arch itself publishes a fresh [cloud image](https://geo.mirror.pkgbuild.com/images/latest/) every
month, with cloud-init. The Terraform lab imports that into your own project as a custom image
(`gcp-lab/image/`), so the VM starts from a current build and the first `pacman -Syu` is small.
The manual `gcloud` path below uses the 2022 community image; expect a long first upgrade.

### Create it

Same shape as the Multipass VM in Lab 1 — 2 vCPU, 4 GB, 20 GB:

```bash
ZONE=us-central1-a

gcloud compute instances create lab \
  --zone=$ZONE --machine-type=e2-medium \
  --image-project=arch-linux-gce --image-family=arch \
  --boot-disk-size=20GB --tags=lab
```

### Reach it without exposing SSH to the internet

SSH goes through Identity-Aware Proxy, so port 22 is open only to Google's IAP range
([how IAP TCP forwarding works](https://cloud.google.com/iap/docs/using-tcp-forwarding)):

```bash
gcloud compute firewall-rules create lab-allow-iap-ssh \
  --network=default --direction=INGRESS --allow=tcp:22 \
  --source-ranges=35.235.240.0/20 --target-tags=lab

gcloud compute ssh lab --zone=$ZONE --tunnel-through-iap
```

The `default` network ships with a `default-allow-ssh` rule open to `0.0.0.0/0`. Delete it, or
accept that your lab VM is being scanned within minutes of boot — which is its own lesson for
Week 3.

This VPC firewall sits **in front of** the host firewall you build in Week 3. A packet has to pass
both. That is the same arrangement as an AWS security group in front of an instance, and it belongs
in your Gate 1 packet-path explanation. Open ports 80 and 443 in the VPC firewall only when Week 3
asks for them.

### Or build it with Terraform

[`gcp-lab/`](gcp-lab/) creates the same VM — on either distro — in its own VPC instead of
`default`, with IAP-only SSH, no service account on the VM, and a schedule that stops it every
night:

```bash
cd curriculum/_setup/gcp-lab
gcloud auth application-default login          # Terraform's credentials, separate from `gcloud auth login`
cp terraform.tfvars.example terraform.tfvars   # set project_id, and distro = "arch" for the Arch path
(cd state && terraform init && terraform apply -var project_id=YOUR_PROJECT && terraform output -raw backend_config > ../backend.hcl)
(cd image && bash fetch.sh && terraform init -backend-config=../backend.hcl && terraform apply -var project_id=YOUR_PROJECT)   # Arch only
terraform init -backend-config=backend.hcl && terraform apply
terraform output image                         # which image build you got, and its age
terraform output -raw ssh_command
terraform output -raw bootstrap_command        # Arch path: copies arch-bootstrap.sh to the VM
```

Changing `distro` after the VM exists replaces the VM. Set it once, in `terraform.tfvars`.

**The full walkthrough — project, billing, budget, daily use, recovery, teardown — is in
[`gcp-lab/README.md`](gcp-lab/README.md).** Follow that one; the block above is the short form.

Set `open_web = true` and re-apply when Week 3 needs ports 80 and 443. For a fresh VM — Gate 1
practice — run `terraform apply -replace=google_compute_instance.lab`. `terraform destroy` removes
everything.

If you have not reached the Terraform weeks yet, create the VM by hand once first. The
configuration is short enough to read afterwards and recognise every resource.

### Or run the VM on AWS instead

[`aws-lab/`](aws-lab/README.md) is the same VM on AWS: its own VPC, SSH only through an EC2
Instance Connect Endpoint, no IAM role on the VM, nightly auto-stop. Pick one cloud for the lab
VM. Two things differ from GCP that matter for the labs:

- On the Ubuntu path the login user is `ubuntu`, so the Week 2 SSH lab runs exactly as written.
- Arch has no official AWS image either; you choose a community AMI yourself. The runbook covers
  how to inspect it first.

The rest of this page — the bootstrap script and the lab-by-lab differences — applies on either
cloud. Where it shows a `gcloud` command, the AWS runbook has the equivalent.

### First boot

A fresh Arch image is far barer than Ubuntu's — no `man`, no `which`, no `dig`, no cron, possibly
no Python. [`arch-bootstrap.sh`](arch-bootstrap.sh) closes that gap: it does a full upgrade, then
installs what Ubuntu ships by default and the labs assume. Copy it to the VM and run it once:

```bash
# on your workstation, from curriculum/_setup/
gcloud compute scp arch-bootstrap.sh arch@lab:~ --zone=$ZONE --tunnel-through-iap   # Terraform path: user is arch
gcloud compute scp arch-bootstrap.sh lab:~ --zone=$ZONE --tunnel-through-iap        # hand-made VM from the 2022 image: your own user

# on the VM
bash arch-bootstrap.sh
sudo reboot               # if the kernel was upgraded
```

The login user differs because the images differ. The imported official image has cloud-init
and one user, `arch`. The 2022 community image has Google's guest agent, which creates whatever
user you log in as. [`gcp-lab/README.md`](gcp-lab/README.md#what-is-different-on-arch) has the
full list of consequences.

Read the script before running it — it is 30 lines, and each `pacman` line is a list of things
Ubuntu was quietly doing for you. It leaves Nginx, certbot, and Docker alone; the labs install
those by hand.

If the upgrade fails on signature errors, the image's keyring is older than the packages:
`sudo pacman -Sy archlinux-keyring && sudo pacman -Su`, then re-run the script.

From here on, each lab step that differs carries an **Arch path** note pointing back to this page.

### Snapshot, stop, destroy

| Multipass (as written in the labs) | GCP equivalent |
|---|---|
| `multipass shell lab` | `gcloud compute ssh lab --zone=$ZONE --tunnel-through-iap` (`arch@lab` on the Terraform Arch path; `terraform output -raw ssh_command` prints the right one) |
| `multipass stop lab` | `gcloud compute instances stop lab --zone=$ZONE` |
| `multipass snapshot lab --name clean` | `gcloud compute disks snapshot lab --zone=$ZONE --snapshot-names=clean` |
| `multipass restore lab.clean` | No in-place restore. Delete the VM and recreate it from the snapshot: `gcloud compute instances create lab --zone=$ZONE --machine-type=e2-medium --source-snapshot=clean --tags=lab` |
| `multipass delete lab` | `gcloud compute instances delete lab --zone=$ZONE` |

**Stop the VM when you finish a session.** A stopped instance bills only for its disk. Set a
budget alert on the project before you create anything.

---

## Three defaults that differ everywhere

These explain most of the surprises; the table below is just their consequences.

1. **Arch never starts or enables a service for you.** On Ubuntu, `apt install nginx` leaves Nginx
   running and enabled at boot. On Arch, `pacman -S nginx` only puts files on disk — you run
   `systemctl enable --now nginx` yourself.
2. **Arch ships upstream's config layout, not Debian's.** Debian adds conventions on top of many
   packages (`sites-available/`, `www-data`, `adduser`). Arch gives you what the upstream project
   ships. When a lab path does not exist, this is usually why.
3. **Arch is rolling, so partial upgrades break things.** Always `pacman -Syu` before installing.
   Never run `pacman -Sy <package>` — it installs against a package database newer than the rest
   of your system. See [pacman](https://wiki.archlinux.org/title/Pacman).

---

## Differences, lab by lab

| Where | Ubuntu (as written) | Arch |
|---|---|---|
| Week 1, Lab 1 — VM | `multipass launch … 24.04` | The GCP VM above |
| Week 1, Lab 1 — tools | `sudo apt update && sudo apt install -y tree jq curl git vim htop net-tools` | Already installed by `arch-bootstrap.sh`. By hand: `sudo pacman -Syu --needed tree jq curl git vim htop net-tools` |
| Week 1, Lab 5 — pre-break/fix snapshot | `multipass snapshot` | Disk snapshot, per the table above |
| Week 2 — SSH client config | `HostName 192.168.64.10`, `User ubuntu` | Through IAP — see the `Host lab` block below |
| Week 2 — SSH user | `AllowUsers ubuntu` | `arch` on the Terraform path; otherwise your own login name — run `whoami` on the VM. See the warning below |
| Week 2 — SSH service unit | `ssh` | `sshd` |
| Week 2 — `ipcalc` | `apt install ipcalc` | Installed by the bootstrap script — a different implementation; the output is laid out differently, the math is the same. Skip `sipcalc` |
| Weeks 1–2 — cron | Running by default | `cronie`, installed and enabled by the bootstrap script |
| Week 3 — `ufw` | Preinstalled, inactive | Installed by the bootstrap script, inactive. Run `sudo systemctl enable --now ufw` before `ufw enable`. See [Uncomplicated Firewall](https://wiki.archlinux.org/title/Uncomplicated_Firewall) |
| Week 3 — install Nginx | `sudo apt install -y nginx` (starts automatically) | `sudo pacman -S nginx`, then set up the layout below, then `sudo systemctl enable --now nginx` |
| Week 3 — Nginx site layout | `/etc/nginx/sites-available/` + `sites-enabled/`, a `default` site to remove | Neither directory exists; one stock `server` block lives in `nginx.conf`. See below |
| Week 3 — Nginx worker user | `www-data` | `http` |
| Week 3 — certbot | `sudo apt install -y certbot python3-certbot-nginx` | `sudo pacman -S certbot certbot-nginx` |
| Week 4 — Docker | Installed by `00-toolchain.sh` (the `get.docker.com` script) | `sudo pacman -S docker docker-compose docker-buildx`, then `sudo systemctl enable --now docker` |
| Anywhere — admin group | `sudo` | `wheel` |
| Anywhere — creating users | `adduser` (interactive wrapper) | `useradd -m` only |
| Anywhere — text logs | `/var/log/syslog`, `/var/log/auth.log` | Journal only: `journalctl`, `journalctl -u sshd` |
| Anywhere — persistent network config | netplan | Check what the image uses with `networkctl` before editing anything |

### Week 2 — SSH to the GCP VM

The lab's `~/.ssh/config` points at a Multipass address. The GCP VM accepts SSH only through IAP,
so plain `ssh lab` needs a `ProxyCommand` that opens the tunnel. Use this block in place of the
lab's `Host lab`:

```
Host lab
    HostName lab
    User YOUR_VM_LOGIN
    IdentityFile ~/.ssh/google_compute_engine
    IdentitiesOnly yes
    ServerAliveInterval 60
    ProxyCommand gcloud compute start-iap-tunnel %h 22 --listen-on-stdin --project=YOUR_PROJECT --zone=YOUR_ZONE
```

`YOUR_VM_LOGIN` is `arch` on the Terraform Arch path, and otherwise what `whoami` prints on the
VM. `~/.ssh/google_compute_engine` is the key the Terraform path had you generate before the
first apply, or the one `gcloud compute ssh` generated on first connect. Once `ssh lab` works, do
the lab's own-key exercise on top of it: generate `lab_ed25519`, run
`ssh-copy-id -i ~/.ssh/lab_ed25519.pub lab`, then switch `IdentityFile` to the new key.

Who owns `~/.ssh/authorized_keys` differs by image, and it matters for that exercise. On the
imported Arch image, cloud-init wrote the file once at first boot and never touches it again, so
a hand-added key stays. On Ubuntu, and on the 2022 community Arch image, Google's guest agent
manages the file from instance metadata; whether it leaves a hand-added line alone is not yet
verified here. If `lab_ed25519` stops working after a reboot on those images, that is why — and
working out who rewrote the file is a fair exercise for this week.

The `bastion` / `ProxyJump` part of the lab is unchanged; IAP is the managed version of the same
idea.

### Week 2 warning — `AllowUsers` can lock you out

The lab hardens `sshd_config` with `AllowUsers ubuntu`. On the GCP VM your account is not
`ubuntu`: it is `arch` on the Terraform Arch path, and on the other images it is whatever
`gcloud compute ssh` created when you first logged in. Put the wrong name in `AllowUsers` and the
next login is refused.

Before reloading `sshd`: keep your current session open, test from a second terminal, and take a
disk snapshot first. If you do lock yourself out, that is a legitimate break/fix exercise — recover
through the serial console or by recreating the VM from the snapshot.

### Week 3 — making the Nginx lab work unchanged

The lab writes a site to `sites-available/` and symlinks it into `sites-enabled/`. Recreate that
convention once and every later command in the lab runs as written:

```bash
sudo mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled
sudoedit /etc/nginx/nginx.conf
```

In `nginx.conf`, inside the `http { }` block:

- add `include /etc/nginx/sites-enabled/*;`
- delete or comment out the stock `server { listen 80; … }` block — it plays the role of Ubuntu's
  `default` site

Then:

```bash
sudo nginx -t && sudo systemctl enable --now nginx
```

The lab's `rm -f /etc/nginx/sites-enabled/default` does nothing on Arch, harmlessly. Details:
[Nginx on the ArchWiki](https://wiki.archlinux.org/title/Nginx).

---

## When something on Arch does not match

1. Check the three defaults above — is the service enabled, does the path exist, is the system
   fully upgraded?
2. Search the [ArchWiki](https://wiki.archlinux.org/) for the package name. It documents the Arch
   layout and is the best systemd and networking reference on either path.
3. If a lab step fails on Arch and this page does not cover it, add a row to the table. That is how
   this page gets verified.
