#!/usr/bin/env bash
set -euo pipefail

# Install and verify Tailscale on CachyOS/Arch without changing node identity.
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
have_package() { command -v pacman >/dev/null && pacman -Q tailscale >/dev/null 2>&1; }

command -v pacman >/dev/null || { log ERROR "pacman was not found; this script supports CachyOS/Arch." >&2; exit 1; }
if [[ $MODE == check ]]; then
  have_package || { log ERROR "Tailscale is not installed (install with: sudo pacman -S tailscale)." >&2; exit 1; }
  command -v systemctl >/dev/null || { log ERROR "systemctl was not found." >&2; exit 1; }
  systemctl is-enabled --quiet tailscaled || { log ERROR "tailscaled is not enabled." >&2; exit 1; }
  systemctl is-active --quiet tailscaled || { log ERROR "tailscaled is not active." >&2; exit 1; }
elif ! have_package; then
  if (( UPGRADE )); then
    log INFO "Performing the explicitly requested full system upgrade before installation."
    run sudo pacman -Syu --noconfirm || { log ERROR "Full upgrade failed. Resolve pacman/mirror errors, then rerun." >&2; exit 1; }
  fi
  log INFO "Installing Tailscale without refreshing package databases (avoids a partial upgrade)."
  run sudo pacman -S --needed --noconfirm tailscale || {
    log ERROR "Installation failed. Run 'sudo pacman -Syu' deliberately, resolve all errors, then retry." >&2
    exit 1
  }
  run sudo systemctl enable --now tailscaled
else
  log INFO "Tailscale is already installed; preserving its configuration, state, and device identity."
  run sudo systemctl enable --now tailscaled
fi

if [[ $MODE == dry-run ]]; then log INFO "No changes were made."; exit 0; fi
systemctl is-enabled --quiet tailscaled || { log ERROR "tailscaled is not enabled." >&2; exit 1; }
systemctl is-active --quiet tailscaled || { log ERROR "tailscaled failed to start. Inspect: journalctl -u tailscaled -b" >&2; exit 1; }

tailscale version
status_ok=1
status_output=$(tailscale status 2>&1) || status_ok=0
printf '%s\n' "$status_output"
if grep -Eqi 'Logged out|NeedsLogin|not logged in' <<<"$status_output"; then
  log NEXT "This node is not authenticated. Run 'sudo tailscale up' and follow the login URL."
elif (( ! status_ok )); then
  log WARN "Tailscale status failed for a reason other than a recognized logged-out state; inspect the message above."
else
  log INFO "Tailscale appears authenticated; not running 'tailscale up' or changing preferences."
fi
log INFO "Connectivity verification (installation alone does not prove reachability):"
tailscale ip -4 || log WARN "No Tailscale IPv4 address is currently available."
tailscale netcheck || log WARN "netcheck failed; inspect daemon logs and network reachability."
