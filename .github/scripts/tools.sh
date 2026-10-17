#!/usr/bin/env bash
#
# Install the CLI tools CI uses, at the versions CI pins, into .tools/bin (gitignored), so a local
# run sees exactly what the runner sees. The checkov lesson of 2026-10-17: the Homebrew checkov
# ships none of the graph policies, reported 0 failures, and CI then failed 13 checks.
#
# Versions are read from the workflow env blocks, so there is one place to bump them. Archives
# are verified against the vendor's published checksums file; ShellCheck publishes none, so its
# hashes are recorded here and in security.yml.
#
#   bash .github/scripts/tools.sh        # or: make tools
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BIN="$ROOT/.tools/bin"
mkdir -p "$BIN"

# Read `  NAME: value` from a workflow's env block.
ver() { sed -nE "s/^[[:space:]]+$1:[[:space:]]+([^[:space:]#]+).*/\1/p" "$ROOT/.github/workflows/$2" | head -1; }

TRIVY_VERSION="$(ver TRIVY_VERSION security.yml)"
ACTIONLINT_VERSION="$(ver ACTIONLINT_VERSION security.yml)"
SHELLCHECK_VERSION="$(ver SHELLCHECK_VERSION security.yml)"
for v in TRIVY_VERSION ACTIONLINT_VERSION SHELLCHECK_VERSION; do
  [[ -n "${!v}" ]] || { echo "tools.sh: could not read $v from security.yml" >&2; exit 1; }
done

case "$(uname -s)/$(uname -m)" in
  Darwin/arm64)  trivy_os=macOS-ARM64; al_os=darwin_arm64; sc_os=darwin.aarch64
                 SHELLCHECK_SHA256=56affdd8de5527894dca6dc3d7e0a99a873b0f004d7aabc30ae407d3f48b0a79 ;;
  Linux/x86_64)  trivy_os=Linux-64bit; al_os=linux_amd64; sc_os=linux.x86_64
                 SHELLCHECK_SHA256="$(ver SHELLCHECK_SHA256_AMD64 security.yml)" ;;
  Linux/aarch64) trivy_os=Linux-ARM64; al_os=linux_arm64;  sc_os=linux.aarch64
                 SHELLCHECK_SHA256="$(ver SHELLCHECK_SHA256_ARM64 security.yml)" ;;
  *) echo "tools.sh: unsupported platform $(uname -s)/$(uname -m)" >&2; exit 1 ;;
esac

sha256() { if command -v sha256sum >/dev/null; then sha256sum "$1"; else shasum -a 256 "$1"; fi | cut -d' ' -f1; }

# fetch NAME VERSION URL MEMBER EXPECTED_SHA
# Skips the download when .tools/bin/NAME already reports VERSION.
fetch() {
  local name=$1 version=$2 url=$3 member=$4 expected=$5
  if [[ -x "$BIN/$name" ]] && "$BIN/$name" --version 2>&1 | grep -q "$version"; then
    echo "tools.sh: $name $version already installed"; return
  fi
  local work; work="$(mktemp -d)"
  local archive="${url##*/}"
  curl -fsSLo "$work/$archive" "$url"
  local actual; actual="$(sha256 "$work/$archive")"
  if [[ "$actual" != "$expected" ]]; then
    echo "tools.sh: checksum mismatch for $archive" >&2
    echo "  expected $expected" >&2
    echo "  actual   $actual" >&2
    exit 1
  fi
  case "$archive" in
    *.tar.gz|*.tgz) tar -xzf "$work/$archive" -C "$work" "$member" ;;
    *.tar.xz)       tar -xJf "$work/$archive" -C "$work" "$member" ;;
    *.zip)          unzip -oq "$work/$archive" "$member" -d "$work" ;;
    *) echo "tools.sh: unknown archive type $archive" >&2; exit 1 ;;
  esac
  install -m 0755 "$work/$member" "$BIN/$name"
  rm -rf "$work"
  echo "tools.sh: installed $name $version -> $BIN/$name"
}

# Expected hash for ARCHIVE from the vendor's checksums file at URL.
vendor_sha() { curl -fsSL "$1" | awk -v f="$2" '$2 == f || $2 == "*" f {print $1}'; }

trivy_archive="trivy_${TRIVY_VERSION}_${trivy_os}.tar.gz"
fetch trivy "$TRIVY_VERSION" \
  "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/${trivy_archive}" trivy \
  "$(vendor_sha "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_checksums.txt" "$trivy_archive")"

al_archive="actionlint_${ACTIONLINT_VERSION}_${al_os}.tar.gz"
fetch actionlint "$ACTIONLINT_VERSION" \
  "https://github.com/rhysd/actionlint/releases/download/v${ACTIONLINT_VERSION}/${al_archive}" actionlint \
  "$(vendor_sha "https://github.com/rhysd/actionlint/releases/download/v${ACTIONLINT_VERSION}/actionlint_${ACTIONLINT_VERSION}_checksums.txt" "$al_archive")"

fetch shellcheck "$SHELLCHECK_VERSION" \
  "https://github.com/koalaman/shellcheck/releases/download/v${SHELLCHECK_VERSION}/shellcheck-v${SHELLCHECK_VERSION}.${sc_os}.tar.xz" \
  "shellcheck-v${SHELLCHECK_VERSION}/shellcheck" "$SHELLCHECK_SHA256"

echo "tools.sh: done. Add to PATH or use the make targets: make scan, make lint-workflows, make shellcheck"
