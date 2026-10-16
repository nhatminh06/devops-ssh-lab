#!/usr/bin/env bash
set -euo pipefail

# Safely manage an OpenSSH hardening drop-in on CachyOS/Arch.
MODE=check
KEY_VERIFIED=0
ASSUME_YES=0
SSHD_CONFIG=${SSHD_CONFIG:-/etc/ssh/sshd_config}
DROPIN=${SSHD_DROPIN:-/etc/ssh/sshd_config.d/00-devops-ssh-lab.conf}
CONTEXT=${SSHD_CONTEXT:-}

usage() {
  cat <<'EOF'
Usage: secure_ssh.sh [--check|--dry-run|--apply] [--key-login-verified] [--yes]
                     [--context user,client-address,local-address]

Apply requires --key-login-verified and interactive confirmation (or --yes).
Use --context when Match rules exist, for example: pnmynh,100.64.0.2,100.70.249.10
EOF
}
while (($#)); do
  case "$1" in
    --check|--dry-run|--apply) MODE=${1#--} ;;
    --key-login-verified) KEY_VERIFIED=1 ;;
    --yes) ASSUME_YES=1 ;;
    --context) shift; CONTEXT=${1:?--context requires user,client-address,local-address} ;;
    -h|--help) usage; exit 0 ;;
    *) echo "[ERROR] Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
  shift
done

log() { printf '[%s] %s\n' "$1" "$2"; }
desired=$'PermitRootLogin no\nPasswordAuthentication no\nKbdInteractiveAuthentication no\nPubkeyAuthentication yes\n'

command -v sshd >/dev/null || { log ERROR "sshd was not found; run setup_ssh.sh first." >&2; exit 1; }
[[ -r $SSHD_CONFIG ]] || { log ERROR "Cannot read $SSHD_CONFIG." >&2; exit 1; }
sudo sshd -t -f "$SSHD_CONFIG" || { log ERROR "Existing sshd configuration is invalid; refusing to continue." >&2; exit 1; }

# OpenSSH uses the first obtained value. Require an early global Include.
include_ok=$(awk '
  BEGIN { IGNORECASE=1; ok=0 }
  /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
  tolower($1)=="match" { exit }
  tolower($1)=="permitrootlogin" || tolower($1)=="passwordauthentication" ||
  tolower($1)=="kbdinteractiveauthentication" || tolower($1)=="pubkeyauthentication" { exit }
  tolower($1)=="include" {
    for (i=2; i<=NF; i++) if ($i=="/etc/ssh/sshd_config.d/*.conf") { ok=1; exit }
  }
  END { print ok }
' "$SSHD_CONFIG")
[[ $include_ok == 1 ]] || {
  log ERROR "No suitable early global 'Include /etc/ssh/sshd_config.d/*.conf' was found."
  log ERROR "A drop-in could be ineffective because OpenSSH uses the first value obtained; no files were changed."
  exit 1
}

effective_args=(-T -f "$SSHD_CONFIG")
if [[ -n $CONTEXT ]]; then
  IFS=, read -r ctx_user ctx_addr ctx_laddr <<<"$CONTEXT"
  [[ -n ${ctx_user:-} && -n ${ctx_addr:-} && -n ${ctx_laddr:-} ]] || { log ERROR "Context must be user,client-address,local-address." >&2; exit 2; }
  effective_args+=(-C "user=$ctx_user,addr=$ctx_addr,laddr=$ctx_laddr")
elif grep -Eqi '^[[:space:]]*Match[[:space:]]' "$SSHD_CONFIG" /etc/ssh/sshd_config.d/*.conf 2>/dev/null; then
  log ERROR "Match rules exist; rerun with --context user,client-address,local-address." >&2
  exit 1
fi

if [[ $MODE == check ]]; then
  if [[ ! -r $DROPIN ]] || ! cmp -s <(printf '%s' "$desired") "$DROPIN"; then
    log ERROR "The managed hardening drop-in is absent or differs." >&2; exit 1;
  fi
  effective=$(sudo sshd "${effective_args[@]}")
  for expected in 'permitrootlogin no' 'passwordauthentication no' 'kbdinteractiveauthentication no' 'pubkeyauthentication yes'; do
    grep -Fqx "$expected" <<<"$effective" || { log ERROR "Effective setting does not match: $expected" >&2; exit 1; }
  done
  grep -E '^(permitrootlogin|passwordauthentication|kbdinteractiveauthentication|pubkeyauthentication) ' <<<"$effective"
  log INFO "Managed drop-in, syntax, and effective settings are valid."
  exit 0
fi
if [[ $MODE == dry-run ]]; then
  printf '[DRY-RUN] Would install %s with:\n%s' "$DROPIN" "$desired"
  log INFO "Would back up configuration, validate sshd -t/-T, then reload."
  exit 0
fi

(( KEY_VERIFIED )) || { log ERROR "Refusing to disable passwords until a separate key-only login was verified. Test with 'ssh -o PasswordAuthentication=no ...', then pass --key-login-verified." >&2; exit 1; }
if (( ! ASSUME_YES )); then
  [[ -t 0 ]] || { log ERROR "Apply needs interactive confirmation; use --yes only with console/recovery access." >&2; exit 1; }
  read -r -p "Type APPLY after keeping a second key-authenticated session or console open: " answer
  [[ $answer == APPLY ]] || { log INFO "Cancelled; no files changed."; exit 1; }
fi

stamp=$(date +%Y%m%d%H%M%S)
backup_dir="/etc/ssh/devops-ssh-lab-backup-$stamp"
sudo install -d -m 0700 "$backup_dir"
sudo cp -a "$SSHD_CONFIG" "$backup_dir/sshd_config"
had_dropin=0
if sudo test -e "$DROPIN"; then sudo cp -a "$DROPIN" "$backup_dir/managed.conf"; had_dropin=1; fi
sudo install -d -m 0755 "$(dirname "$DROPIN")"
printf '%s' "$desired" | sudo install -m 0644 /dev/stdin "$DROPIN"

rollback() {
  log ERROR "Validation failed; restoring the previous managed drop-in."
  if (( had_dropin )); then sudo cp -a "$backup_dir/managed.conf" "$DROPIN"; else sudo rm -f "$DROPIN"; fi
  sudo sshd -t -f "$SSHD_CONFIG" || true
}
sudo sshd -t -f "$SSHD_CONFIG" || { rollback; exit 1; }
effective=$(sudo sshd "${effective_args[@]}") || { rollback; exit 1; }
for expected in 'permitrootlogin no' 'passwordauthentication no' 'kbdinteractiveauthentication no' 'pubkeyauthentication yes'; do
  grep -Fqx "$expected" <<<"$effective" || { log ERROR "Effective setting did not match: $expected"; rollback; exit 1; }
done
sudo systemctl reload sshd || { rollback; log ERROR "Reload failed. The prior file was restored; validate before retrying."; exit 1; }
systemctl is-active --quiet sshd || { log ERROR "sshd is not active after reload. Use local console and restore from $backup_dir." >&2; exit 1; }
log INFO "Hardening is effective and sshd reloaded successfully."
log INFO "Rollback files: $backup_dir (restore managed.conf, or remove the drop-in if it is absent; then run sshd -t and reload)."
