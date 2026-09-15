#!/usr/bin/env bash
# Check the VPN toggle is installed and the profile is safe to use.
# Never prints the gateway host, the username or the certificate digest.
#
#   ./verify.sh [profile]

set -uo pipefail

PROFILE="${1:-work}"
BIN="$HOME/.local/bin/vpn-toggle"
DESKTOP="$HOME/.local/share/applications/$PROFILE-vpn.desktop"
CONF="$HOME/.config/openfortivpn/$PROFILE.conf"

fail=0
ok()   { printf '  \033[32mok\033[0m  %s\n' "$*"; }
bad()  { printf '  \033[31mBAD\033[0m %s\n' "$*"; fail=$((fail+1)); }
warn() { printf '  \033[33m--\033[0m  %s\n' "$*"; }

echo "== package =="
command -v openfortivpn >/dev/null \
  && ok "openfortivpn $(pacman -Q openfortivpn 2>/dev/null | awk '{print $2}')" \
  || bad "openfortivpn not installed"

echo "== files =="
[ -x "$BIN" ] && ok "$BIN is executable" || bad "$BIN missing or not executable"
[ -f "$DESKTOP" ] && ok "launcher entry for '$PROFILE'" || bad "no $DESKTOP"

echo "== profile =="
if [ -f "$CONF" ]; then
  perms=$(stat -c %a "$CONF")
  [ "$perms" = "600" ] && ok "profile present, mode 600" \
                       || bad "profile is mode $perms — holds the gateway host and your username; chmod 600"

  # Presence only. Values are never echoed.
  for key in host port username trusted-cert; do
    grep -qE "^[[:space:]]*$key[[:space:]]*=" "$CONF" \
      && ok "$key is set" \
      || { [ "$key" = "trusted-cert" ] \
             && warn "no trusted-cert — fine if the gateway sends a complete chain, otherwise the connection will fail and print the digest" \
             || bad "$key is missing"; }
  done

  grep -qE "^[[:space:]]*password[[:space:]]*=" "$CONF" \
    && bad "profile contains a plaintext 'password =' line — remove it; 2FA prompts anyway" \
    || ok "no plaintext password in the profile"

  grep -qE "^[[:space:]]*trusted-cert[[:space:]]*=[[:space:]]*0{64}[[:space:]]*$" "$CONF" \
    && bad "trusted-cert is still the example's all-zero placeholder" \
    || true
else
  bad "no profile at $CONF — copy config/profile.conf.example and fill it in"
fi

echo "== state =="
if pgrep -x openfortivpn >/dev/null; then
  ok "tunnel is UP"
  ip -o link show 2>/dev/null | grep -q 'ppp0' && ok "ppp0 exists" || warn "no ppp0 interface"
else
  warn "tunnel is down (nothing wrong — this is the idle state)"
fi

echo
[ "$fail" -eq 0 ] && echo "All checks passed." || echo "$fail check(s) failed."
exit $(( fail > 0 ))
