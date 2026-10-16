#!/usr/bin/env bash
set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mockbin="$tmp/bin"
mkdir -p "$mockbin"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
expect_failure() { "$@" >/dev/null 2>&1 && fail "command unexpectedly succeeded: $*" || true; }

for script in "$repo"/*.sh "$repo"/tests/*.sh; do bash -n "$script"; done
if command -v shellcheck >/dev/null; then shellcheck "$repo"/*.sh "$repo"/tests/*.sh; else echo 'SKIP: shellcheck is not installed locally'; fi

make_mock() {
  local name=$1 body=$2
  printf '#!/usr/bin/env bash\n%s\n' "$body" >"$mockbin/$name"
  chmod +x "$mockbin/$name"
}

# These single-quoted bodies are intentionally expanded by the generated mocks.
# shellcheck disable=SC2016
make_mock pacman '
if [[ ${1:-} == -Q ]]; then [[ ${MOCK_PACKAGE_INSTALLED:-0} == 1 ]]; else exit 0; fi'
# shellcheck disable=SC2016
make_mock systemctl '
case ${1:-} in is-enabled|is-active) [[ ${MOCK_SERVICE_OK:-0} == 1 ]];; *) exit 0;; esac'
make_mock sudo 'exec "$@"'
# shellcheck disable=SC2016
make_mock tailscale '
case ${1:-} in version) echo "1.0 test";; status) echo "100.64.0.1 test active; direct";; ip) echo "100.64.0.1";; netcheck) echo "UDP: true";; esac'
make_mock ssh 'echo "OpenSSH_test" >&2'
# shellcheck disable=SC2016
make_mock sshd '
if [[ " $* " == *" -T "* ]]; then
  if [[ ${MOCK_EFFECTIVE_BAD:-0} == 1 ]]; then
    printf "%s\n" "permitrootlogin no" "passwordauthentication yes" "kbdinteractiveauthentication no" "pubkeyauthentication yes"
  else
    printf "%s\n" "permitrootlogin no" "passwordauthentication no" "kbdinteractiveauthentication no" "pubkeyauthentication yes"
  fi
fi'

PATH="$mockbin:$PATH" MOCK_PACKAGE_INSTALLED=1 MOCK_SERVICE_OK=1 "$repo/install_tailscale.sh" --check >/dev/null
PATH="$mockbin:$PATH" MOCK_PACKAGE_INSTALLED=1 MOCK_SERVICE_OK=1 "$repo/setup_ssh.sh" --check >/dev/null

dry_output=$(PATH="$mockbin:$PATH" MOCK_PACKAGE_INSTALLED=0 "$repo/install_tailscale.sh" --dry-run)
grep -q 'pacman -S --needed --noconfirm tailscale' <<<"$dry_output" || fail 'Tailscale dry-run omitted install command'
[[ $dry_output != *'pacman -Syu'* ]] || fail 'default Tailscale install unexpectedly upgrades'

dry_output=$(PATH="$mockbin:$PATH" MOCK_PACKAGE_INSTALLED=0 "$repo/setup_ssh.sh" --dry-run)
grep -q 'pacman -S --needed --noconfirm openssh' <<<"$dry_output" || fail 'OpenSSH dry-run omitted install command'
[[ $dry_output != *'pacman -Syu'* ]] || fail 'default OpenSSH install unexpectedly upgrades'

expect_failure env PATH="$mockbin:$PATH" MOCK_PACKAGE_INSTALLED=0 "$repo/install_tailscale.sh" --check
expect_failure env PATH="$mockbin:$PATH" MOCK_PACKAGE_INSTALLED=0 "$repo/setup_ssh.sh" --check
expect_failure "$repo/install_tailscale.sh" --invalid
expect_failure "$repo/setup_ssh.sh" --invalid

config="$tmp/sshd_config"
dropin="$tmp/00-devops-ssh-lab.conf"
printf '%s\n' 'Include /etc/ssh/sshd_config.d/*.conf' >"$config"
printf '%s\n' 'PermitRootLogin no' 'PasswordAuthentication no' 'KbdInteractiveAuthentication no' 'PubkeyAuthentication yes' >"$dropin"
PATH="$mockbin:$PATH" SSHD_CONFIG="$config" SSHD_DROPIN="$dropin" "$repo/secure_ssh.sh" --check >/dev/null
PATH="$mockbin:$PATH" SSHD_CONFIG="$config" SSHD_DROPIN="$dropin" "$repo/secure_ssh.sh" --dry-run >/dev/null
expect_failure env PATH="$mockbin:$PATH" MOCK_EFFECTIVE_BAD=1 SSHD_CONFIG="$config" SSHD_DROPIN="$dropin" "$repo/secure_ssh.sh" --check
expect_failure env PATH="$mockbin:$PATH" SSHD_CONFIG="$config" SSHD_DROPIN="$dropin" "$repo/secure_ssh.sh" --apply --yes

printf '%s\n' 'PasswordAuthentication yes' 'Include /etc/ssh/sshd_config.d/*.conf' >"$config"
expect_failure env PATH="$mockbin:$PATH" SSHD_CONFIG="$config" SSHD_DROPIN="$dropin" "$repo/secure_ssh.sh" --dry-run

echo 'PASS: syntax, mocks, idempotent existing-state paths, dry-runs, and safe failures'
