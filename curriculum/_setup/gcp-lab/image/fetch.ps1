#Requires -Version 5.1
<#
.SYNOPSIS
  Windows port of fetch.sh: downloads the newest official Arch Linux cloud image, verifies it,
  and converts it into the raw-disk tarball Compute Engine imports.

.DESCRIPTION
  Run from this directory, then `terraform apply` here uploads the tarball and creates the image.
  Same checks as fetch.sh, same outputs, same pinned signing key.

  Needs (choco install qemu gnupg -y, then open a NEW terminal so PATH is refreshed):
    qemu-img   from the qemu package. Its installer does not always add itself to PATH; this
               script also looks in C:\Program Files\qemu.
    gpg, gpgv  from the gnupg package (the command-line GnuPG, not gpg4win). Also looked for
               in C:\Program Files (x86)\GnuPG\bin.
    tar.exe, curl.exe  ship with Windows 10 1803 and later.

  Writes _build\ (downloads, the dearmored key, disk.raw while converting, the tarball) and
  build.auto.tfvars next to main.tf. Both are ignored by git. Re-runs verify again but skip
  downloads and the conversion when this build's files already exist.

  NOT YET RUN ON WINDOWS. Every stage was run under PowerShell 7.6.6 on macOS against the real
  image files, including a tampered-signature test; the Windows-specific parts (install paths,
  tar.exe) are untested, and so is Windows PowerShell 5.1 as opposed to PowerShell 7.

.EXAMPLE
  .\fetch.ps1                              # newest build from the mirror
  .\fetch.ps1 -Build 20261001.604814       # a specific build (pin one during a gate week)
  .\fetch.ps1 -SkipGpg                     # checksum only; loud warning. Last resort
#>
[CmdletBinding()]
param(
  [string]$Build,
  [switch]$SkipGpg,
  [string]$Mirror = 'https://geo.mirror.pkgbuild.com/images'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

# arch-boxes <arch-boxes@archlinux.org>, primary key. See the header of arch-boxes.asc.
$ArchBoxesFpr = '1B9A16984A4E8CB448712D2AE0B78BF4326C6F8F'

function Write-Step([string]$Message) { Write-Host "==> $Message" -ForegroundColor Blue }

# Writes build.auto.tfvars in the current directory (image/). LF line endings, no BOM.
function Write-TfVars {
  $tfvars = "# Written by fetch.ps1. Do not edit; re-run the script for a newer build.`n" +
            "build   = `"$Date`"`n" +
            "tarball = `"_build/$Tarball`"`n"
  [IO.File]::WriteAllText((Join-Path $PWD 'build.auto.tfvars'), $tfvars)
  Write-Step 'Wrote build.auto.tfvars. Next: terraform init -backend-config=../backend.hcl; terraform apply -var project_id=$env:PROJECT_ID'
}

# PATH first, then the installer's default folder. Returns the full path or $null.
function Find-Tool([string]$Name, [string[]]$Fallbacks = @()) {
  $cmd = Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue
  if ($cmd) { return @($cmd)[0].Source }
  foreach ($f in $Fallbacks) { if ($f -and (Test-Path $f)) { return $f } }
  return $null
}

# Runs a native command, returns its stdout+stderr lines as strings and sets $script:Exit.
# Native stderr is an error stream in PowerShell; with $ErrorActionPreference = 'Stop' it
# would throw, so it is relaxed for the duration of the call only.
function Invoke-Native([string]$Exe, [string[]]$Arguments) {
  $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
  try {
    $out = & $Exe @Arguments 2>&1 | ForEach-Object { "$_" }
    $script:Exit = $LASTEXITCODE
    return @($out)
  } finally { $ErrorActionPreference = $prev }
}

# --- Prerequisites first, before a 600 MB download -------------------------------
$pf86 = [Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
$qemuImg = Find-Tool 'qemu-img' @("$env:ProgramFiles\qemu\qemu-img.exe")
if (-not $qemuImg) { throw 'qemu-img not found: choco install qemu -y, then open a new terminal' }
if (-not $SkipGpg) {
  $gpg  = Find-Tool 'gpg'  @("$pf86\GnuPG\bin\gpg.exe",  "$env:ProgramFiles\GnuPG\bin\gpg.exe")
  $gpgv = Find-Tool 'gpgv' @("$pf86\GnuPG\bin\gpgv.exe", "$env:ProgramFiles\GnuPG\bin\gpgv.exe")
  if (-not $gpg -or -not $gpgv) { throw 'gpg/gpgv not found: choco install gnupg -y, then open a new terminal (or -SkipGpg to continue on checksum only)' }
}
# -CommandType Application in Find-Tool means these resolve to tar.exe / curl.exe, never to
# PowerShell's `curl` alias for Invoke-WebRequest.
$tar  = Find-Tool 'tar'  @("$env:SystemRoot\System32\tar.exe")
$curl = Find-Tool 'curl' @("$env:SystemRoot\System32\curl.exe")
if (-not $tar)  { throw 'tar.exe not found; it ships with Windows 10 1803 and later' }
if (-not $curl) { throw 'curl.exe not found; it ships with Windows 10 1803 and later' }

# --- Which build -----------------------------------------------------------------
if (-not $Build) {
  # The "latest/" listing links the versioned file; take its build number.
  $listing = (Invoke-WebRequest -UseBasicParsing -Uri "$Mirror/latest/").Content
  $m = [regex]::Match($listing, 'Arch-Linux-x86_64-cloudimg-(\d+\.\d+)\.qcow2')
  if (-not $m.Success) { throw "could not find a cloudimg build in $Mirror/latest/" }
  $Build = $m.Groups[1].Value
}
$Date    = $Build.Split('.')[0]                    # 20261001.604814 -> 20261001
$Qcow    = "Arch-Linux-x86_64-cloudimg-$Build.qcow2"
$Url     = "$Mirror/v$Build/$Qcow"
$Tarball = "arch-$Date.tar.gz"
Write-Step "Build $Build -> image arch-$Date"

New-Item -ItemType Directory -Force -Path _build | Out-Null
Set-Location _build

# --- Download + verify -----------------------------------------------------------
foreach ($f in @($Qcow, "$Qcow.SHA256", "$Qcow.sig")) {
  if ((Test-Path $f) -and (Get-Item $f).Length -gt 0) { continue }
  Write-Step "Downloading $f"
  $null = Invoke-Native $curl @('-fL', '--progress-bar', '-o', $f, ($Url + $f.Substring($Qcow.Length)))
  if ($script:Exit -ne 0) { throw "download failed: $f" }
}

Write-Step 'SHA256'
$expected = ((Get-Content "$Qcow.SHA256" -Raw) -split '\s+')[0].ToLower()
$actual   = (Get-FileHash -Algorithm SHA256 -Path $Qcow).Hash.ToLower()
if ($expected -ne $actual) { throw "SHA256 mismatch for $Qcow`n  expected $expected`n  actual   $actual" }
Write-Host "    ${Qcow}: OK"

# Signature. gpgv against a dearmored copy of the one shipped key: nothing touches your own
# keyring and no gpg-agent is involved. See fetch.sh for the longer explanation.
if ($SkipGpg) {
  Write-Warning 'SkipGpg: signature not checked. Checksum only.'
} else {
  Write-Step 'GPG signature'
  $keyAsc = Join-Path (Split-Path $PWD -Parent) 'arch-boxes.asc'
  $out = Invoke-Native $gpg @('--batch', '--yes', '--quiet', '--dearmor', '-o', 'arch-boxes.gpg', $keyAsc)
  if ($script:Exit -ne 0) { throw "could not dearmor ${keyAsc}: $($out -join ' ')" }
  # VALIDSIG ends with the PRIMARY key fingerprint, which is what is pinned.
  $status = Invoke-Native $gpgv @('--keyring', (Join-Path $PWD 'arch-boxes.gpg'), '--status-fd', '1', "$Qcow.sig", $Qcow)
  $signer = $status | Where-Object { $_ -match '^\[GNUPG:\] VALIDSIG ' } | ForEach-Object { ($_ -split ' ')[-1] } | Select-Object -First 1
  if ($signer -eq $ArchBoxesFpr) {
    Write-Host "    Good signature by arch-boxes <arch-boxes@archlinux.org> ($ArchBoxesFpr)"
  } else {
    $status | Where-Object { $_ -match 'BADSIG|ERRSIG|EXPKEYSIG|NO_PUBKEY' } | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
    $got = if ($signer) { $signer } else { 'no valid signature' }
    throw "image is NOT signed by the pinned arch-boxes key (got: $got). Do not use it."
  }
}

# --- Convert ----------------------------------------------------------------------
# Same build, same tarball: reuse it. Rebuilding changes the gzip timestamp and nothing
# else, and Terraform would then re-upload 570 MB for an identical image.
if ((Test-Path $Tarball) -and (Get-Item $Tarball).Length -gt 0) {
  Write-Step "Reusing existing $Tarball (delete it to rebuild)"
  Set-Location ..
  Write-TfVars
  exit 0
}

Write-Step 'qemu-img check'
$null = Invoke-Native $qemuImg @('check', '-q', $Qcow)
if ($script:Exit -ne 0) { throw "qemu-img check failed on $Qcow" }

Write-Step 'Converting to disk.raw'
Remove-Item disk.raw -ErrorAction SilentlyContinue
$null = Invoke-Native $qemuImg @('convert', '-f', 'qcow2', '-O', 'raw', $Qcow, 'disk.raw')
if ($script:Exit -ne 0) { throw 'qemu-img convert failed' }

# Compute Engine requires the raw disk to be a whole number of GiB.
$bytes = (Get-Item disk.raw).Length
$gib   = [int][math]::Ceiling($bytes / 1GB)
if ($bytes -ne $gib * 1GB) {
  Write-Step "Padding disk.raw to $gib GiB"
  $null = Invoke-Native $qemuImg @('resize', '-f', 'raw', 'disk.raw', "${gib}G")
  if ($script:Exit -ne 0) { throw 'qemu-img resize failed' }
}

# --- Tar ------------------------------------------------------------------------
# Windows ships bsdtar as tar.exe. It cannot write sparse members; gzip handles the zeros.
# The file inside MUST be named disk.raw.
Write-Step "Writing $Tarball"
Remove-Item $Tarball -ErrorAction SilentlyContinue
$null = Invoke-Native $tar @('--format=gnutar', '-czf', $Tarball, 'disk.raw')
if ($script:Exit -ne 0) { throw 'tar failed' }
Remove-Item disk.raw
$size = (Get-Item $Tarball).Length / 1MB
Write-Host ("    {0}  {1:N0} MB" -f $Tarball, $size)

# --- Hand off to Terraform -------------------------------------------------------
Set-Location ..
Write-TfVars
