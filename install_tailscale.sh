#!/usr/bin/env bash
set -euo pipefail

# install_tailscale.sh
# Installs Tailscale on Ubuntu/Debian and enables the tailscaled service.

echo "[INFO] Updating package index..."
sudo apt update

echo "[INFO] Installing curl..."
sudo apt install -y curl

echo "[INFO] Installing Tailscale via official install script..."
curl -fsSL https://tailscale.com/install.sh | sh

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
