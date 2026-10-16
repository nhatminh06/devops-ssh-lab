# Operator notes

## Identity and addressing

In `ssh user@host`, `user` is a Linux account and `host` is an address or name. `hostname` is not the username. Confirm a session with `whoami`, `hostname`, and `printf '%s\n' "$SSH_CONNECTION"`.

- A LAN address usually works only while client and server share the LAN.
- A public address is intentionally unnecessary here.
- `tailscale ip -4` reports the server's stable private tailnet address.

Both endpoints must be online in the same tailnet and permitted by tailnet policy. A direct Tailscale path is desirable but does not prove loss-free TCP, healthy shell startup, or a working VS Code Server.

## Lifecycle

- **Initial setup:** install packages, start services, authenticate Tailscale once, install the user's public key, and test key-only login.
- **Re-run/reinstall:** use the idempotent scripts or `pacman -S --needed`; do not remove `/var/lib/tailscale`, log out, force reauthentication, or replace SSH keys.
- **Recovery:** keep console/working-session access, gather evidence, restore only the known change, validate `sshd -t`, then reload.

Arch does not support partial upgrades. Never use `pacman -Sy package`. A full `pacman -Syu` is a deliberate maintenance action, not an unattended side effect of an access script.

## Historical lessons retained

Earlier setup failures included broken package mirrors, confusion between username/hostname and LAN/Tailscale addresses, another VPN/DNS layer (Cloudflare WARP) complicating diagnosis, and testing from the server back into itself. These are useful hypotheses, not universal causes. Validate service, route, identity, authentication, shell startup, and application behavior in that order.

The current remote incident is documented as a case study in [docs/troubleshooting.md](docs/troubleshooting.md). Its strongest clue is that Bash without startup files remains interactive; that prioritizes shell initialization for testing but does not rule out MTU, loss, forwarding, or VS Code Server state.
