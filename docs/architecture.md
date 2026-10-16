# Architecture

## Scope and trust boundaries

This lab provides private remote administration only: a macOS client reaches traditional OpenSSH on a CachyOS/Arch server through Tailscale. It does not cover public port forwarding, Tailscale SSH, containers, orchestration, or cloud deployment.

```text
[macOS: ssh / VS Code]
          |
          | tailnet ACL + encrypted Tailscale path (direct or DERP-relayed)
          v
[CachyOS: tailscaled] -> [TCP port 22: OpenSSH sshd] -> [Linux user session]
```

Tailscale supplies addressing, routing, and tailnet authorization. OpenSSH independently supplies host identity, user public-key authentication, PTY/SFTP, and TCP/stream-local forwarding. VS Code Remote SSH uses OpenSSH and starts VS Code Server as the remote user.

## Security baseline

After key login is proven from the real client, the managed global baseline is:

```text
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
```

Forwarding is deliberately left at the OpenSSH/default or administrator-selected value because VS Code Remote SSH needs a tunnel. Tailnet policy, host firewall policy, and SSH authentication remain separate controls.

OpenSSH uses the first obtained value for most settings and evaluates `Match` rules for a connection. Therefore the hardening script only uses the Arch-style early Include, checks an explicit connection context when Match blocks exist, and refuses to edit an incompatible layout.
