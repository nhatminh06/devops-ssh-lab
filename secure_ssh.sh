#!/usr/bin/env bash
set -euo pipefail

# secure_ssh.sh
# Hardens SSH configuration for Ubuntu/Debian.
#
# WARNING:
# - Make sure SSH key authentication is already working before running this.
# - This script disables password authentication and root SSH login.

SSHD_CONFIG="/etc/ssh/sshd_config"
BACKUP_PATH="/etc/ssh/sshd_config.bak.$(date +%Y%m%d%H%M%S)"

echo "[INFO] Backing up SSH config to: ${BACKUP_PATH}"
sudo cp "${SSHD_CONFIG}" "${BACKUP_PATH}"

echo "[INFO] Disabling root SSH login..."
sudo sed -i -E 's/^[#[:space:]]*PermitRootLogin[[:space:]]+.*/PermitRootLogin no/' "${SSHD_CONFIG}"
if ! sudo grep -qE '^[[:space:]]*PermitRootLogin[[:space:]]+no' "${SSHD_CONFIG}"; then
  echo "PermitRootLogin no" | sudo tee -a "${SSHD_CONFIG}" >/dev/null
fi

echo "[INFO] Disabling password authentication..."
sudo sed -i -E 's/^[#[:space:]]*PasswordAuthentication[[:space:]]+.*/PasswordAuthentication no/' "${SSHD_CONFIG}"
if ! sudo grep -qE '^[[:space:]]*PasswordAuthentication[[:space:]]+no' "${SSHD_CONFIG}"; then
  echo "PasswordAuthentication no" | sudo tee -a "${SSHD_CONFIG}" >/dev/null
fi

echo "[INFO] Ensuring public key authentication is enabled..."
sudo sed -i -E 's/^[#[:space:]]*PubkeyAuthentication[[:space:]]+.*/PubkeyAuthentication yes/' "${SSHD_CONFIG}"
if ! sudo grep -qE '^[[:space:]]*PubkeyAuthentication[[:space:]]+yes' "${SSHD_CONFIG}"; then
  echo "PubkeyAuthentication yes" | sudo tee -a "${SSHD_CONFIG}" >/dev/null
fi

echo "[INFO] Validating SSH configuration syntax..."
sudo sshd -t

echo "[INFO] Restarting SSH service..."
sudo systemctl restart ssh

echo "[INFO] SSH service status:"
sudo systemctl status ssh --no-pager

echo "[DONE] SSH hardening applied successfully."
