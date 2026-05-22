#!/usr/bin/env bash
set -euo pipefail

# install_tailscale.sh
# Installs Tailscale on CachyOS/Arch and enables the tailscaled service.

echo "[INFO] Updating system packages..."
sudo pacman -Syu --noconfirm

echo "[INFO] Installing Tailscale..."
sudo pacman -S --noconfirm tailscale

echo "[INFO] Enabling tailscaled service at boot..."
sudo systemctl enable tailscaled

echo "[INFO] Starting tailscaled service..."
sudo systemctl start tailscaled

echo "[INFO] tailscaled service status:"
sudo systemctl status tailscaled --no-pager

echo
echo "[NEXT] Finish authentication manually with:"
echo "  sudo tailscale up"
echo
echo "[NEXT] To check this machine's Tailscale IP:"
echo "  tailscale ip -4"
