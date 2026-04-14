#!/usr/bin/env bash
set -euo pipefail

# setup_ssh.sh
# Installs and starts OpenSSH server on Ubuntu/Debian.

echo "[INFO] Updating package index..."
sudo apt update

echo "[INFO] Installing OpenSSH server..."
sudo apt install -y openssh-server

echo "[INFO] Enabling SSH service at boot..."
sudo systemctl enable ssh

echo "[INFO] Starting SSH service..."
sudo systemctl start ssh

echo "[INFO] SSH service status:"
sudo systemctl status ssh --no-pager

echo "[DONE] OpenSSH is installed and running."
