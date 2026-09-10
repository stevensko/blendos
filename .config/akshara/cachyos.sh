#!/bin/bash
#
# Enable the signature-verified CachyOS x86-64-v3 repositories.
#
# Only does what's strictly required: trust the CachyOS key, install its
# keyring + mirrorlist packages, drop cachyos.conf and Include it above [core].
# Package installation / migration to the v3 builds is left to paru.sh.
#
# Runs as root inside the akshara update chroot.

set -uo pipefail

KEY='882DCFE48E2051D48E2562ABF3B607488DB35A47'
BASE='https://mirror.cachyos.org/repo/x86_64/cachyos'
CONF_URL='https://raw.githubusercontent.com/stevensko/blendos/main/.config/akshara/cachyos.conf'

pick() {   # newest <pkgname>-<ver>-any.pkg.tar.zst on the mirror
    curl -fsSL "$BASE/" \
        | grep -oE "$1-[0-9][A-Za-z0-9._+-]*-any\.pkg\.tar\.zst" \
        | sort -V | tail -n1
}

# --- trust the CachyOS signing key, install keyring + mirrorlists ---------
pacman-key --recv-keys "$KEY" --keyserver hkps://keyserver.ubuntu.com \
  || pacman-key --recv-keys "$KEY" --keyserver hkps://keys.openpgp.org
pacman-key --lsign-key "$KEY"

pacman -U --noconfirm \
    "$BASE/$(pick cachyos-keyring)" \
    "$BASE/$(pick cachyos-mirrorlist)" \
    "$BASE/$(pick cachyos-v3-mirrorlist)"

# --- drop the repo file and Include it ahead of [core] ------------------
curl -fsSL "$CONF_URL" -o /etc/pacman.d/cachyos.conf

if ! grep -qx 'Include = /etc/pacman.d/cachyos.conf' /etc/pacman.conf; then
    tmp=$(mktemp)
    awk '/^\[core\]/ && !done {
             print "Include = /etc/pacman.d/cachyos.conf"
             print ""
             done = 1
         }
         { print }' /etc/pacman.conf > "$tmp"
    cat "$tmp" > /etc/pacman.conf
    rm -f "$tmp"
fi

# refresh databases so paru.sh can resolve the new repos
pacman -Sy
