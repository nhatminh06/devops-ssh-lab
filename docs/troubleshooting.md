# Troubleshooting

Run diagnostics from the endpoint named in each block. Commands here are read-only unless explicitly labeled as recovery; none overwrite DNS, firewall, SSH, or Tailscale state.

## Layer 1: Tailscale path

On both endpoints:

```bash
tailscale version
tailscale status
tailscale ip -4
tailscale netcheck
```

From the macOS client:

```bash
tailscale ping 100.70.249.10
ping -c 20 100.70.249.10
```

`tailscale ping` reports `direct` with endpoint addresses when UDP NAT traversal succeeds; `via DERP(region)` means encrypted relay. DERP is valid but often adds latency. `netcheck` shows UDP availability, nearest DERP, and mapping behavior. `UDP: false`, changing mappings, or relay-only paths point toward restrictive NAT/firewall/VPN conditions. Do not infer application health merely from `direct`.

Compare the server's LAN address while on the same LAN with its Tailscale address, then retest the Tailscale address from a genuinely remote network. Loss or latency only on one path localizes the network layer. Record repeated ping loss and latency rather than relying on one sample.

## Layer 2: DNS

Bypass names first with the known Tailscale IP. If the IP works but a MagicDNS name fails, inspect rather than replacing resolver files.

Server (systemd-resolved/NetworkManager installations):

```bash
resolvectl status
resolvectl query server-name
systemctl status systemd-resolved NetworkManager --no-pager
readlink -f /etc/resolv.conf
sed -n '1,120p' /etc/resolv.conf
nmcli connection show --active
```

macOS client:

```bash
scutil --dns
dscacheutil -q host -a name server-name
```

An `/etc/resolv.conf` symlink should point to the resolver actually managing DNS. Simultaneously enabling NetworkManager DNS handling, systemd-resolved, another VPN, and Tailscale DNS can create split-DNS conflicts. A failed MagicDNS query with working IP connectivity is a resolver/control-plane issue, not an SSH authentication failure. Do not replace `/etc/resolv.conf` until its owner and intended mode are known.

## Layer 3: OpenSSH and freezes

Server health:

```bash
sudo sshd -t
sudo sshd -T | grep -E '^(passwordauthentication|kbdinteractiveauthentication|pubkeyauthentication|permitrootlogin|allowtcpforwarding|allowstreamlocalforwarding) '
systemctl status sshd --no-pager
journalctl -u sshd -b --no-pager -n 100
ss -lntp | grep ':22'
```

If Match rules exist, inspect the actual connection context:

```bash
sudo sshd -T -C user=pnmynh,addr=CLIENT_TAILSCALE_IP,laddr=100.70.249.10
```

Client isolation tests:

```bash
ssh -vvv pnmynh@100.70.249.10 true
ssh -T pnmynh@100.70.249.10 'printf "noninteractive-ok\n"'
ssh -tt pnmynh@100.70.249.10 'env -i HOME="$HOME" TERM=xterm-256color PATH=/usr/bin:/bin /bin/bash --noprofile --norc'
ssh -o ServerAliveInterval=15 -o ServerAliveCountMax=3 pnmynh@100.70.249.10
```

If authentication and noninteractive commands work but a clean Bash is the only usable interactive shell, inspect `.bash_profile`, `.bash_login`, `.profile`, `.bashrc`, `/etc/profile`, and `/etc/bash.bashrc` for commands that read from the terminal, emit protocol-breaking output, start nested shells, or depend on a missing/slow network service. Use `bash -x` from a console or clean shell to trace startup. Compare `ssh -T` (no PTY) and `ssh -tt` (forced PTY); `stty -a`, `tty`, and `echo "$TERM"` expose PTY/terminal differences.

Keepalives detect a dead path but do not repair it. To test bidirectional bulk data without writing remote files:

```bash
dd if=/dev/zero bs=1M count=32 2>/dev/null | ssh pnmynh@100.70.249.10 'cat >/dev/null'
ssh pnmynh@100.70.249.10 'dd if=/dev/zero bs=1M count=32 2>/dev/null' | cat >/dev/null
```

Small commands succeeding while bulk transfers repeatedly stall can indicate loss, MTU/MSS black holes, or middlebox TCP behavior. Compare LAN and remote/Tailscale results, inspect `ip link`, `ip route get 100.70.249.10`, `tailscale netcheck`, and packet counters (`ip -s link`). Do not change MTU or firewall rules until measurements support that hypothesis.

## Layer 4: VS Code Remote SSH

First prove plain SSH and forwarding from the same client configuration:

```bash
ssh -G cachyos-lab | grep -E '^(hostname|user|identityfile|proxycommand) '
ssh -vvv -D 55555 -N cachyos-lab
```

The second command intentionally waits while the dynamic tunnel is open; cancel with Ctrl-C. If it reports forwarding prohibited, inspect effective `AllowTcpForwarding`, tailnet policy, and intervening SSH configuration. This project does not disable TCP or stream-local forwarding.

In VS Code, set **Remote.SSH: Log Level** to Trace and inspect the Remote - SSH output. Useful controlled comparisons are `remote.SSH.useExecServer`, `remote.SSH.useLocalServer`, and `remote.SSH.enableDynamicForwarding`; change one at a time and revert after testing. “Failed to parse remote port” commonly means shell startup emitted unexpected output or the server bootstrap failed. A timeout after authentication shifts attention to shell startup, forwarding, transport stalls, or VS Code Server startup—not credentials.

On the server, from a clean shell:

```bash
df -h "$HOME"
df -i "$HOME"
find ~/.vscode-server -maxdepth 2 -type f -name '*.log' -print 2>/dev/null
ps -fu "$USER" | grep -E '[v]scode|[n]ode'
```

Full disks or exhausted inodes prevent extraction/startup. Read the logs before recovery. Safe recovery is to close all VS Code windows using that host, use **Remote-SSH: Kill VS Code Server on Host**, then reconnect. If manual cleanup is necessary, rename—not delete—the user's `~/.vscode-server` directory from a stable shell so it is recoverable; this affects only the user's downloaded server/extensions, not SSH or Tailscale identity.

## Case study: intermittent remote workspace access

### Confirmed observations

- Client: macOS ARM64; server: CachyOS/Arch; OpenSSH user `pnmynh`; target `100.70.249.10`.
- Same-LAN access works well and remote access worked previously; the remote problem appeared suddenly.
- Tailscale reported a direct path and SSH authentication completed.
- Normal interactive SSH sometimes froze, while noninteractive commands succeeded.
- Bash launched with `--noprofile --norc` accepted input.
- VS Code initially timed out starting its server. A later Exec Server fallback started and established a tunnel, but stable workspace access was not confirmed.

### Hypotheses, not conclusions

Shell startup is strongly implicated by the clean-Bash result. Packet loss/MTU can still explain interactive or transfer stalls; forwarding could break VS Code despite shell access; stale or resource-starved VS Code Server state could affect only VS Code. “Direct” Tailscale does not eliminate these possibilities. There is not yet enough evidence to name a root cause.

### Reproducible decision tree

```text
tailscale ping succeeds?
├─ no  -> compare status/netcheck, tailnet policy, LAN vs remote, competing VPN
└─ yes -> ssh host true succeeds?
         ├─ no  -> ssh -vvv; inspect sshd journal/effective Match config
         └─ yes -> clean forced-PTY Bash works?
                  ├─ no  -> compare bidirectional bulk tests and LAN path;
                  │        measure loss/MTU/PTY behavior
                  └─ yes -> trace shell startup files from clean shell
                           |
                           └─ plain shell stable but VS Code fails?
                              ├─ tunnel test fails -> effective forwarding/config
                              └─ tunnel works -> disk/inodes/logs/server recovery;
                                                compare Exec/Local Server modes
```

At each branch, capture command output and change only one variable. A fix is confirmed only when remote interactive SSH, bidirectional transfer, and repeated VS Code folder opens remain stable.

## Lockout recovery

Keep the last working session open. From local console or that session, restore the backup path printed by `secure_ssh.sh`, run `sudo sshd -t`, inspect `sudo sshd -T` (with `-C` when needed), and only then `sudo systemctl reload sshd`. Never regenerate host/user keys or delete Tailscale state as a first response.
