#Requires -Version 5.1
<#
.SYNOPSIS
  Installs the full 26-week workstation toolchain on Windows with Chocolatey.

.DESCRIPTION
  Self-contained: the package list is in this file; nothing else needs to be present.
  Idempotent: packages already installed are skipped, not upgraded. One failed package
  does not stop the rest.

  Run from an elevated PowerShell (Run as administrator), signed in as the account you
  will study with - the pipx tools install into the current user's profile.

  NOT YET RUN ON WINDOWS. Package IDs were checked against the Chocolatey community
  repository on 2026-10-03; the script itself is untested.

  The labs for weeks 1-4 run on the Linux VM, not on Windows - see DISTRO.md.

.EXAMPLE
  .\windows-setup.ps1           # install whatever is missing
  .\windows-setup.ps1 -Check    # report what is missing, install nothing
#>
[CmdletBinding()]
param([switch]$Check)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Chocolatey package IDs, in the order the curriculum needs them.
$Packages = @(
  # Lab VM (week 1)
  'gcloudsdk', 'terraform'
  # Core CLI (week 1). git includes Git Bash, which runs the curriculum's .sh scripts
  'git', 'gh', 'jq', 'yq', 'wget', 'make', 'shellcheck'
  # Python (week 4)
  'python312', 'pipx'
  # Containers (week 4). docker-desktop needs WSL 2; its installer prompts for it
  'docker-desktop', 'hadolint', 'dive'
  # Cloud + IaC (weeks 5-11)
  'awscli', 'tflint', 'terraform-docs'
  # Kubernetes + GitOps (weeks 14-17)
  'kubernetes-cli', 'kind', 'kubernetes-helm', 'kustomize', 'k9s', 'kubectx', 'kubens', 'argocd-cli'
  # Security tooling (weeks 18-19)
  'trivy', 'syft', 'grype', 'cosign', 'gitleaks', 'age.portable'
  # Curriculum toolchain (diagrams, banner)
  'nodejs-lts', 'rsvg-convert'
)
# multipass is not listed: only the Ubuntu path uses it.  choco install multipass -y
# qemu and gnupg are not listed: only the Arch-on-GCP path uses them, to import the Arch cloud
# image (gcp-lab/README.md step 8, gcp-lab/image/fetch.ps1).  choco install qemu gnupg -y

# Not on Chocolatey; installed with pipx instead.
$PipxTools = @('pre-commit', 'checkov', 'semgrep')

# No usable Chocolatey package. Install inside WSL, or download the Windows binary from
# each project's GitHub releases page and put it on PATH. sentinel comes from
# https://releases.hashicorp.com/sentinel/ (a zip per platform, with SHA256SUMS); opa, regal
# and gator from their GitHub releases. The Chocolatey package named "sentinel" is unrelated.
$Manual = @('conftest', 'sentinel', 'opa', 'regal', 'gator', 'kubeseal', 'kyverno', 'hey')

function Write-Step([string]$Message) { Write-Host "==> $Message" -ForegroundColor Blue }

function Get-InstalledPackage {
  if (-not (Get-Command choco -ErrorAction SilentlyContinue)) { return @() }
  @(choco list --limit-output | ForEach-Object { ($_ -split '\|')[0] })
}

$installedBefore = Get-InstalledPackage
$missing = @($Packages | Where-Object { $_ -notin $installedBefore })

if ($Check) {
  $Packages | ForEach-Object {
    if ($_ -in $installedBefore) { Write-Host "  OK    $_" -ForegroundColor Green }
    else                         { Write-Host "  MISS  $_" -ForegroundColor Red }
  }
  Write-Host ''
  Write-Step "present: $($Packages.Count - $missing.Count)   missing: $($missing.Count)"
  Write-Host "Not checked (pipx):   $($PipxTools -join ', ')"
  Write-Host "Not checked (manual): $($Manual -join ', ')"
  if ($missing.Count -gt 0) { exit 1 } else { exit 0 }
}

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$isAdmin  = ([Security.Principal.WindowsPrincipal]$identity).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { throw 'Run this from an elevated PowerShell (Run as administrator).' }

if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
  Write-Step 'Installing Chocolatey'
  # Process scope only: the machine's execution policy is left as it was.
  Set-ExecutionPolicy Bypass -Scope Process -Force
  # Chocolatey's documented install command; forces TLS 1.2 on older Windows.
  [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
  # Downloaded to a file first so that what runs is what was fetched, and can be read
  # before it runs -- the same rule linux-setup.sh applies to the Homebrew installer.
  $installer = Join-Path ([System.IO.Path]::GetTempPath()) "chocolatey-install-$PID.ps1"
  Invoke-WebRequest -Uri 'https://community.chocolatey.org/install.ps1' -OutFile $installer -UseBasicParsing
  try { & $installer } finally { Remove-Item $installer -ErrorAction SilentlyContinue }
}

$chocoRoot = if ($env:ChocolateyInstall) { $env:ChocolateyInstall } else { Join-Path $env:ProgramData 'chocolatey' }

$failed = @()
$rebootNeeded = $false
Write-Step "Installing $($missing.Count) missing of $($Packages.Count) packages"
foreach ($package in $missing) {
  # Checksums stay enforced: never add --ignore-checksums or --allow-empty-checksums here.
  choco install $package --yes --no-progress
  switch ($LASTEXITCODE) {
    0       { }
    1641    { $rebootNeeded = $true }   # succeeded, reboot started
    3010    { $rebootNeeded = $true }   # succeeded, reboot required
    default { $failed += $package }
  }
}

Write-Step 'Refreshing PATH for this session'
Import-Module (Join-Path $chocoRoot 'helpers\chocolateyProfile.psm1')
Update-SessionEnvironment

Write-Step 'Python tools via pipx'
if (Get-Command pipx -ErrorAction SilentlyContinue) {
  foreach ($tool in $PipxTools) {
    pipx install $tool
    if ($LASTEXITCODE -ne 0) { $failed += "$tool (pipx)" }
  }
  pipx ensurepath | Out-Null
} else {
  $failed += $PipxTools | ForEach-Object { "$_ (pipx not found)" }
}

Write-Host ''
Write-Step "installed or attempted: $($missing.Count)   failed: $($failed.Count)"
if ($failed.Count -gt 0) { Write-Warning "Failed: $($failed -join ', '). Fix the cause and re-run; what succeeded is skipped next time." }
if ($rebootNeeded)       { Write-Warning 'A package asked for a reboot. Restart before continuing.' }

Write-Host @"

Not available on Chocolatey - install by hand or use WSL: $($Manual -join ', ')

Next:
  1. Open a NEW terminal so PATH changes apply. Start Docker Desktop once.
  2. gcloud auth login                             for gcloud commands
     gcloud auth application-default login         for Terraform
  3. Build the lab VM: gcp-lab/README.md
"@

if ($failed.Count -gt 0) { exit 1 }
