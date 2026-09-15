#!/usr/bin/env bash
# Install the openfortivpn one-key toggle and its launcher entry.
#
#   ./install.sh [profile]      profile defaults to "work"
#
# Installs:
#   ~/.local/bin/vpn-toggle
#   ~/.local/share/applications/<profile>-vpn.desktop
#
# Does NOT install a profile: that file names your gateway and account, so you
# write it yourself from config/profile.conf.example.

set -uo pipefail

PROFILE="${1:-work}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$HOME/.local/bin/vpn-toggle"
APPS="$HOME/.local/share/applications"
CONF="$HOME/.config/openfortivpn/$PROFILE.conf"

say() { printf '==> %s\n' "$*"; }
die() { printf '!! %s\n' "$*" >&2; exit 1; }

# ------------------------------------------------------------- 1. package
if ! command -v openfortivpn >/dev/null; then
  say "Installing openfortivpn"
  omarchy pkg add openfortivpn || die "could not install openfortivpn"
fi
say "openfortivpn $(openfortivpn --version 2>&1 | head -1)"

# ------------------------------------------------------------- 2. script
mkdir -p "$(dirname "$BIN")" "$APPS"
install -m 755 "$HERE/tools/vpn-toggle" "$BIN"
say "Installed $BIN"

# ------------------------------------------------------------- 3. launcher
sed -e "s|@NAME@|${PROFILE^} VPN (openfortivpn)|" \
    -e "s|@PROFILE@|$PROFILE|g" \
    -e "s|@BIN@|$BIN|" \
    "$HERE/config/vpn.desktop.template" > "$APPS/$PROFILE-vpn.desktop"
say "Installed $APPS/$PROFILE-vpn.desktop"
command -v update-desktop-database >/dev/null && update-desktop-database "$APPS" 2>/dev/null

# ------------------------------------------------------------- 4. profile
if [ -f "$CONF" ]; then
  perms=$(stat -c %a "$CONF")
  if [ "$perms" = "600" ]; then
    say "Profile $CONF present (mode 600)"
  else
    say "Profile $CONF present but mode $perms — tightening to 600"
    chmod 600 "$CONF"
  fi
else
  mkdir -p "$(dirname "$CONF")"
  cat <<EOF

==> No profile at $CONF

    Write it yourself — it names your gateway and your account, so it is not
    something this repo can ship:

      cp $HERE/config/profile.conf.example $CONF
      chmod 600 $CONF
      \$EDITOR $CONF

    The trusted-cert digest comes from running openfortivpn once WITHOUT that
    line. Read the comment in the example before pasting what it prints.

EOF
fi

say "Done. Verify with ./verify.sh $PROFILE"
