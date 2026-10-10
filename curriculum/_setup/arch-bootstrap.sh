#!/usr/bin/env bash
# Brings a fresh Arch VM to parity with the Ubuntu 24.04 server image the labs assume:
# installs what Ubuntu ships by default and Arch does not. Run it ON the Arch VM, once.
# Idempotent: safe to re-run. Usage: bash arch-bootstrap.sh
#
# Deliberately NOT done here -- the labs do these by hand, see DISTRO.md:
#   Nginx (week 3), certbot (week 3), Docker (week 4)
set -euo pipefail

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }

[[ -f /etc/arch-release ]] || { echo "This is not Arch Linux. Ubuntu needs no bootstrap." >&2; exit 1; }

log "Full upgrade first (never install onto a partially upgraded system)"
sudo pacman -Syu --noconfirm

log "Base tools Ubuntu preinstalls"
sudo pacman -S --noconfirm --needed \
  base-devel git curl wget unzip vim which man-db man-pages \
  python python-pip

log "Week 1 lab tools"
sudo pacman -S --noconfirm --needed tree jq htop lsof strace shellcheck sysstat tmux

log "Networking tools (weeks 2-3)"
# bind = dig/host, openbsd-netcat = nc, net-tools = netstat/ifconfig
sudo pacman -S --noconfirm --needed bind tcpdump openbsd-netcat net-tools traceroute ipcalc

log "ufw: installed but inactive, as on Ubuntu"
sudo pacman -S --noconfirm --needed ufw

log "cron: Ubuntu runs one by default, Arch ships none"
sudo pacman -S --noconfirm --needed cronie
sudo systemctl enable --now cronie

log "Done. Reboot if the kernel was upgraded:  sudo reboot"
