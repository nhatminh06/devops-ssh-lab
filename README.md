# devops-ssh-lab

A small, safety-focused lab for administering a CachyOS/Arch Linux server with traditional OpenSSH over a private Tailscale network. It does not expose SSH publicly or replace OpenSSH with Tailscale SSH.

## Architecture

```text
macOS laptop                 private tailnet                 CachyOS/Arch server
SSH + VS Code client  ──── Tailscale 100.x address ────>  tailscaled + sshd
```

The laptop initiates connections. `tailscaled` supplies the private route; the normal `sshd` daemon authenticates the Linux account and provides shells, SFTP, and forwarding used by VS Code Remote SSH. See [architecture](docs/architecture.md).

Address types are not interchangeable:

- `192.168.x.x`/`10.x.x.x`: LAN address, normally usable only on the same local network.
- Public IP: internet-routable; this lab does not require forwarding public port 22.
- `100.x.y.z`: Tailscale address, usable by authorized devices in the same tailnet.

## Initial setup

On the CachyOS/Arch server, review before running:

```bash
./setup_ssh.sh --dry-run
./install_tailscale.sh --dry-run
sudo ./setup_ssh.sh
sudo ./install_tailscale.sh
```

The scripts install with `pacman -S --needed`; they do not silently refresh databases or upgrade the system. Because Arch partial upgrades are unsupported, perform a deliberate full upgrade separately when needed (`sudo pacman -Syu`), or opt in with `--upgrade`.

If Tailscale is not authenticated, the installer prints the manual next step:

```bash
sudo tailscale up
```

It never runs `down`, `logout`, `reset`, or forced reauthentication. Re-running it preserves `/var/lib/tailscale`, preferences, and device identity.

On the macOS client, install the current Tailscale app from the App Store or Tailscale download page, sign into the same tailnet, and leave the app connected. Then test:

```bash
tailscale ping 100.70.249.10
ssh pnmynh@100.70.249.10
```

## Verification and maintenance

Read-only health checks:

```bash
./setup_ssh.sh --check
./install_tailscale.sh --check
tailscale version
tailscale status
tailscale ip -4
tailscale netcheck
sudo sshd -t
systemctl is-active sshd tailscaled
```

Package installation is not proof of end-to-end access. Confirm `tailscale ping`, key authentication, an interactive shell, and a data transfer from the actual remote client.

For reinstall/repair, keep Tailscale state intact and use `sudo pacman -S tailscale openssh`; package reinstalling does not require logging the node out. Never remove state, regenerate SSH host keys, or disable the current authentication method during remote-only maintenance.

## Safe SSH hardening

First install a user public key and verify it in a **new** session while the old session or a local console remains open:

```bash
ssh -o PreferredAuthentications=publickey -o PasswordAuthentication=no pnmynh@100.70.249.10
./secure_ssh.sh --dry-run
sudo ./secure_ssh.sh --apply --key-login-verified
```

The script requires confirmation, backs up configuration, manages `/etc/ssh/sshd_config.d/00-devops-ssh-lab.conf`, checks Include precedence and Match context, validates with `sshd -t` and `sshd -T`, and reloads instead of restarting. It preserves TCP and Unix-socket forwarding for VS Code. If Match rules exist, pass `--context user,client-address,local-address`. It refuses unsafe or ambiguous configurations.

## VS Code Remote SSH

Create a client entry in `~/.ssh/config`:

```sshconfig
Host cachyos-lab
    HostName 100.70.249.10
    User pnmynh
    IdentityFile ~/.ssh/id_ed25519
    ServerAliveInterval 30
    ServerAliveCountMax 3
```

Connect successfully with `ssh cachyos-lab` before choosing **Remote-SSH: Connect to Host**. See [troubleshooting](docs/troubleshooting.md) for shell startup, forwarding, VS Code Server, MTU, DNS, and recovery diagnostics.

## Recovery checklist

1. Keep or obtain local console access; do not close the last working SSH session.
2. Run `sudo sshd -t`, `systemctl status sshd tailscaled`, and inspect relevant journal entries.
3. Test the LAN and Tailscale paths separately.
4. If hardening caused the failure, follow the backup path printed by `secure_ssh.sh`, validate, then reload.
5. Do not delete keys, Tailscale state, DNS files, or VS Code Server data until diagnostics identify that component.

Automated checks live in `tests/run.sh` and `.github/workflows/ci.yml`.
