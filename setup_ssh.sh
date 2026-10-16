#!/usr/bin/env bash
set -euo pipefail

# Install and verify traditional OpenSSH on CachyOS/Arch.
MODE=apply
UPGRADE=0
for arg in "$@"; do
  case "$arg" in
    --check|--dry-run) MODE=${arg#--} ;;
    --upgrade) UPGRADE=1 ;;
    -h|--help) echo "Usage: $0 [--check|--dry-run] [--upgrade]"; exit 0 ;;
    *) echo "[ERROR] Unknown argument: $arg" >&2; exit 2 ;;
  esac
done

log() { printf '[%s] %s\n' "$1" "$2"; }
run() {
  if [[ $MODE == dry-run ]]; then printf '[DRY-RUN]'; printf ' %q' "$@"; printf '\n';
  else "$@"; fi
}
have_package() { command -v pacman >/dev/null && pacman -Q openssh >/dev/null 2>&1; }

command -v pacman >/dev/null || { log ERROR "pacman was not found; this script supports CachyOS/Arch." >&2; exit 1; }
if [[ $MODE == check ]]; then
  have_package || { log ERROR "OpenSSH is not installed." >&2; exit 1; }
  sudo sshd -t || { log ERROR "sshd configuration validation failed." >&2; exit 1; }
  systemctl is-enabled --quiet sshd || { log ERROR "sshd is not enabled." >&2; exit 1; }
  systemctl is-active --quiet sshd || { log ERROR "sshd is not active." >&2; exit 1; }
  ssh -V
  log INFO "OpenSSH package, configuration, and service checks passed."
  exit 0
fi

if ! have_package; then
  if (( UPGRADE )); then
    log INFO "Performing the explicitly requested full system upgrade before installation."
    run sudo pacman -Syu --noconfirm || { log ERROR "Full upgrade failed; resolve pacman errors before continuing." >&2; exit 1; }
  fi
  log INFO "Installing OpenSSH without refreshing package databases (avoids a partial upgrade)."
  run sudo pacman -S --needed --noconfirm openssh || {
    log ERROR "Installation failed. Deliberately complete 'sudo pacman -Syu', resolve errors, then retry." >&2
    exit 1
  }
else
  log INFO "OpenSSH is already installed; existing host keys and configuration will not be overwritten."
fi

if [[ $MODE == dry-run ]]; then
  run sudo sshd -t
  run sudo systemctl enable --now sshd
  log INFO "No changes were made."
  exit 0
fi
sudo sshd -t || { log ERROR "Configuration is invalid; sshd was not started or changed." >&2; exit 1; }
sudo systemctl enable --now sshd || { log ERROR "Could not enable/start sshd. Inspect: journalctl -u sshd -b" >&2; exit 1; }
systemctl is-active --quiet sshd || { log ERROR "sshd is not active. Inspect: journalctl -u sshd -b" >&2; exit 1; }
ssh -V
log INFO "OpenSSH is installed, its configuration is valid, and sshd is active."
