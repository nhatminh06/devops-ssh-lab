# Notes from My SSH + Tailscale Setup

These are practical notes from building this lab. I kept them because most issues were not "hard," but they were easy to mix up when learning.

## Username vs Hostname (Easy to Confuse)

- In `ssh user@host`, `user` is the Linux account on the server (example: `minh`, `ubuntu`).
- `host` is how your laptop finds the server (local IP, Tailscale IP, or DNS name).
- I initially mixed these up and tried values in the wrong place.

Example:

```bash
ssh minh@100.101.102.103
```

## How I Found the Correct IP

On the server, useful commands:

```bash
hostname
hostname -I
ip a
tailscale ip -4
```

- `hostname` shows machine name, not login username.
- `hostname -I` usually shows local LAN addresses (like `192.168.x.x`).
- `tailscale ip -4` shows private overlay IP (usually `100.x.y.z`).

## Local IP vs Public IP vs Tailscale IP

- Local IP (`192.168.x.x`): works only on same LAN.
- Public IP: routable from internet, but exposing SSH publicly is higher risk.
- Tailscale IP (`100.x.y.z`): private access between devices in same tailnet.

For this project, I used Tailscale IP for remote access to avoid public SSH exposure.

## First SSH Fingerprint Prompt Is Normal

First connection usually asks:

```text
The authenticity of host '...' can't be established...
Are you sure you want to continue connecting (yes/no/[fingerprint])?
```

This is expected. SSH is asking whether to trust the server key and save it to `~/.ssh/known_hosts`.

## Password Typing Shows Nothing (Also Normal)

When entering a password in terminal, no characters or asterisks appear. That behavior is normal for Linux terminals.

## Common SSH Mistakes I Hit

- Running SSH command from the wrong machine
  - I once SSH-ed from server to itself instead of laptop to server.
- Using wrong username
  - Example: trying hostname instead of actual Linux account name.
- Using wrong target IP
  - Trying local IP while off-LAN, or trying public IP when project was designed for Tailscale.
- Hardening too early
  - Disabling password login before key login was confirmed would lock access out.

## What I Debugged During Setup

### 1) Tailscale install failed because package mirrors were broken

- `pacman -Syu` errors can block unrelated package installs.
- Fixing invalid/outdated mirror configuration was required before Tailscale setup could complete.

### 2) Possible Cloudflare WARP interference

- Another VPN/DNS layer can conflict with expected routing.
- I checked whether WARP was active when SSH/Tailscale behavior looked inconsistent.

### 3) SSH hang caused by client-side gap

- Server had Tailscale running, but laptop did not.
- Result: SSH appeared to hang because both endpoints were not on the same tailnet.

## Why Tailscale on Both Client and Server Matters

Tailscale private IP connectivity only works when both devices are authenticated and online in the same tailnet. If either side is disconnected, `ssh user@100.x.y.z` can fail or hang.

## DevOps Perspective: What I Learned

- Start with connectivity basics before security tuning.
- Validate each layer in order: service, network path, identity, then hardening.
- Keep scripts small and clear so setup is repeatable.
- Prefer private admin paths (Tailscale) over public exposure for lab systems.
- Good troubleshooting notes are part of engineering work, not an afterthought.
