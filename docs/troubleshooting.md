# Troubleshooting Guide

This guide captures real issues encountered during setup and how to debug them systematically.

## 1) SSH Command Format Errors

### Symptom

- `ssh` fails immediately or asks for unexpected credentials.

### Checks

- Confirm format is `ssh username@target`.
- Verify username is a real Linux account on the server:

  ```bash
  whoami
  id
  ```

### Common mistake

- Mixing hostname and username in `ssh user@host`.

## 2) Wrong IP Address Type

### Symptom

- Timeout, no route, or hanging connection.

### Checks

- Local LAN IP (server): `hostname -I`
- Tailscale IP (server): `tailscale ip -4`
- Confirm which network you are on from the client.

### Rule of thumb

- Same LAN: local IP can work.
- Different network: use Tailscale IP if both devices are in same tailnet.

## 3) SSH Seems to Hang

### Symptom

- `ssh user@100.x.y.z` hangs with no immediate error.

### Checks

- Is Tailscale running on server?

  ```bash
  systemctl status tailscaled
  ```

- Is Tailscale running and connected on laptop/client?
- Can client ping server Tailscale IP?

  ```bash
  ping 100.x.y.z
  ```

### Likely cause

- One endpoint (often client laptop) is not connected to Tailscale.

## 4) Tailscale Install Problems (apt repo issues)

### Symptom

- `apt update` fails and blocks package install.

### Checks

- Review apt source files for invalid repos:

  ```bash
  ls /etc/apt/sources.list.d
  sudo apt update
  ```

### Fix pattern

- Remove or correct broken third-party repo entries, then rerun `apt update`.

## 5) Potential VPN/DNS Interference (Cloudflare WARP)

### Symptom

- Inconsistent routing or DNS behavior during SSH/Tailscale testing.

### Checks

- Confirm if WARP or another VPN is enabled on client.
- Temporarily disable and retest to isolate routing conflicts.

## 6) SSH Into Wrong Machine

### Symptom

- Command appears successful but you are on unexpected host.

### Checks

- On connected shell, run:

  ```bash
  hostname
  whoami
  ip a
  ```

### Common mistake

- Running SSH from server to itself while intending laptop -> server remote test.

## 7) Locked Out After Hardening

### Symptom

- Access fails after disabling password auth.

### Prevention

- Verify SSH key login works before running hardening script.
- Keep an active local console/session open while testing config changes.
- Always back up `/etc/ssh/sshd_config` before edits.

## Debugging Workflow I Followed

1. Validate service health (`systemctl status ssh`, `systemctl status tailscaled`).
2. Validate addressing (local vs Tailscale IP).
3. Validate client/server membership in same Tailscale network.
4. Validate auth path (key works first, then harden).
5. Apply one change at a time and retest.
