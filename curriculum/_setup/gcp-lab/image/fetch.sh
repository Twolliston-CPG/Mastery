#!/usr/bin/env bash
# Downloads the newest official Arch Linux cloud image, verifies it, and converts it
# into the raw-disk tarball Compute Engine imports. Run from this directory, then
# `terraform apply` here uploads the tarball and creates the image.
#
#   bash fetch.sh                           # newest build from the mirror
#   BUILD=20261001.604814 bash fetch.sh     # a specific build (pin one during a gate week)
#   SKIP_GPG=1 bash fetch.sh                # checksum only; loud warning. Last resort
#
# What it checks:
#   SHA256    must match the mirror's .SHA256 file. Catches a corrupt download, nothing more:
#             the checksum came from the same place as the file.
#   Signature must be a valid PGP signature by the arch-boxes key, pinned by primary
#             fingerprint below and shipped as ./arch-boxes.asc. This is the provenance
#             check. Anything else -- no signature, wrong key, expired key -- stops the
#             script. See the header of arch-boxes.asc for where the key came from and
#             how to refresh it when its signing subkey expires (May 2027).
#
# Needs:  curl, shasum, tar, gpg + gpgv (brew install gnupg), qemu-img (brew install qemu).
#         gnu-tar (brew install gnu-tar) is used if present; bsdtar works without it.
# Writes: _build/   downloads, the dearmored key, disk.raw while converting, the tarball
#         build.auto.tfvars   the build number and tarball path Terraform reads
#         Both are ignored by git. Re-runs verify again but skip downloads and the
#         conversion when this build's files already exist.
set -euo pipefail
cd "$(dirname "$0")"

MIRROR="${MIRROR:-https://geo.mirror.pkgbuild.com/images}"
ARCH_BOXES_FPR="1B9A16984A4E8CB448712D2AE0B78BF4326C6F8F"   # arch-boxes <arch-boxes@archlinux.org>, primary key

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() { echo "error: $*" >&2; exit 1; }

# Prerequisites first, before a 600 MB download.
command -v qemu-img >/dev/null || die "qemu-img not found: brew install qemu"
if [[ "${SKIP_GPG:-}" != "1" ]]; then
  command -v gpg  >/dev/null || die "gpg not found: brew install gnupg   (or SKIP_GPG=1 to continue on checksum only)"
  command -v gpgv >/dev/null || die "gpgv not found: brew install gnupg  (or SKIP_GPG=1 to continue on checksum only)"
fi

# --- Which build -----------------------------------------------------------------
if [[ -z "${BUILD:-}" ]]; then
  # The "latest/" listing links the versioned file; take its build number.
  BUILD=$(curl -fsSL "$MIRROR/latest/" \
    | grep -o 'Arch-Linux-x86_64-cloudimg-[0-9]*\.[0-9]*\.qcow2' | head -1 \
    | sed -E 's/Arch-Linux-x86_64-cloudimg-([0-9.]+)\.qcow2/\1/')
  [[ -n "$BUILD" ]] || die "could not find a cloudimg build in $MIRROR/latest/"
fi
DATE="${BUILD%%.*}"                      # 20261001.604814 -> 20261001
QCOW="Arch-Linux-x86_64-cloudimg-${BUILD}.qcow2"
URL="$MIRROR/v${BUILD}/${QCOW}"
TARBALL="arch-${DATE}.tar.gz"
log "Build $BUILD -> image arch-$DATE"

mkdir -p _build && cd _build

# --- Download + verify -----------------------------------------------------------
for f in "$QCOW" "$QCOW.SHA256" "$QCOW.sig"; do
  [[ -s "$f" ]] || { log "Downloading $f"; curl -fL --progress-bar -o "$f" "$URL${f#"$QCOW"}"; }
done

log "SHA256"
# The .SHA256 file names the file it checks; -c needs that name to match.
shasum -a 256 -c "$QCOW.SHA256"

# Signature. Checked with gpgv -- the verify-only tool package managers use -- against a
# dearmored copy of the one shipped key. Nothing touches your own keyring and no gpg-agent
# is started: a plain `gpg --import` into a fresh keyring tries to launch the agent, which
# fails on macOS when the socket path is long, and exits 2. With `set -e` that was a
# silent stop on first run. gpgv has no agent.
if [[ "${SKIP_GPG:-}" == "1" ]]; then
  echo "    WARNING: SKIP_GPG=1 -- signature not checked. Checksum only." >&2
else
  log "GPG signature"
  gpg --batch --yes --quiet --dearmor -o arch-boxes.gpg ../arch-boxes.asc
  # --status-fd gives machine-readable lines. VALIDSIG ends with the PRIMARY key
  # fingerprint, which is what is pinned: signing subkeys rotate, the primary does not.
  status=$(gpgv --keyring "$PWD/arch-boxes.gpg" --status-fd 1 "$QCOW.sig" "$QCOW" 2>/dev/null || true)
  signer=$(awk '$2=="VALIDSIG"{print $NF}' <<<"$status")
  if [[ "$signer" == "$ARCH_BOXES_FPR" ]]; then
    echo "    Good signature by arch-boxes <arch-boxes@archlinux.org> ($ARCH_BOXES_FPR)"
  else
    grep -E "BADSIG|ERRSIG|EXPKEYSIG|NO_PUBKEY" <<<"$status" >&2 || true
    die "image is NOT signed by the pinned arch-boxes key (got: ${signer:-no valid signature}). Do not use it."
  fi
fi

# --- Convert ----------------------------------------------------------------------
# Same build, same tarball: reuse it. Rebuilding changes the gzip timestamp and nothing
# else, and Terraform would then re-upload 570 MB for an identical image.
if [[ -s "$TARBALL" ]]; then
  log "Reusing existing $TARBALL (delete it to rebuild)"
  cd ..
  cat > build.auto.tfvars <<TFV
# Written by fetch.sh. Do not edit; re-run the script for a newer build.
build   = "$DATE"
tarball = "_build/$TARBALL"
TFV
  log "Wrote build.auto.tfvars. Next: terraform init -backend-config=../backend.hcl && terraform apply -var project_id=\$PROJECT_ID"
  exit 0
fi

log "qemu-img check"
qemu-img check -q "$QCOW"

log "Converting to disk.raw"
rm -f disk.raw
qemu-img convert -f qcow2 -O raw "$QCOW" disk.raw

# Compute Engine requires the raw disk to be a whole number of GiB.
bytes=$(stat -f %z disk.raw 2>/dev/null || stat -c %s disk.raw)   # BSD stat, then GNU stat
gib=$(( (bytes + 1073741823) / 1073741824 ))
if (( bytes != gib * 1073741824 )); then
  log "Padding disk.raw to ${gib} GiB"
  qemu-img resize -f raw disk.raw "${gib}G"
fi

# --- Tar ------------------------------------------------------------------------
# Google documents GNU tar with --format=oldgnu and -S (sparse). macOS ships bsdtar,
# which cannot write sparse members; gzip handles the zeros well enough that it
# does not matter. The file inside MUST be named disk.raw.
log "Writing $TARBALL"
rm -f "$TARBALL"
if command -v gtar >/dev/null; then
  gtar --format=oldgnu -Sczf "$TARBALL" disk.raw
else
  tar --format=gnutar -czf "$TARBALL" disk.raw
fi
rm -f disk.raw
ls -lh "$TARBALL"

# --- Hand off to Terraform -------------------------------------------------------
cd ..
cat > build.auto.tfvars <<TFV
# Written by fetch.sh. Do not edit; re-run the script for a newer build.
build   = "$DATE"
tarball = "_build/$TARBALL"
TFV
log "Wrote build.auto.tfvars. Next: terraform init -backend-config=../backend.hcl && terraform apply -var project_id=\$PROJECT_ID"
