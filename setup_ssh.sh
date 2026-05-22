#!/usr/bin/env bash
set -euo pipefail

# setup_ssh.sh
# Installs and starts OpenSSH server on CachyOS/Arch.

echo "[INFO] Updating system packages..."
sudo pacman -Syu --noconfirm

echo "[INFO] Installing OpenSSH server..."
sudo pacman -S --noconfirm openssh

echo "[INFO] Enabling sshd service at boot..."
sudo systemctl enable sshd

echo "[INFO] Starting sshd service..."
sudo systemctl start sshd

echo "[INFO] sshd service status:"
sudo systemctl status sshd --no-pager

echo "[DONE] OpenSSH is installed and running."
