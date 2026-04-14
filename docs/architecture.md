# Architecture

## Scope

This lab is focused on secure remote Linux administration over a private network path. It intentionally does **not** cover app deployment, Kubernetes, or cloud hosting.

## High-Level Flow

```text
[Laptop / SSH Client]
         |
         |  ssh user@100.x.y.z
         v
[Tailscale Private Network]
         |
         v
[Linux Server / SSH Daemon]
```

## Components

- **Laptop (client):** where SSH commands are run.
- **Linux server:** target machine running `openssh-server`.
- **Tailscale (`tailscaled`):** provides private overlay networking between client and server.
- **OpenSSH (`sshd`):** secure remote shell service.

## Access Model

- Primary access path: laptop -> Tailscale IP -> server SSH.
- Authentication: SSH key-based login.
- Hardening baseline:
  - `PermitRootLogin no`
  - `PasswordAuthentication no`
  - `PubkeyAuthentication yes`

## Why This Design

- Avoid exposing public SSH port for a beginner home lab.
- Keep setup reproducible with small scripts.
- Prioritize secure access and troubleshooting fundamentals over deployment complexity.
