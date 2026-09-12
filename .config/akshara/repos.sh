#!/bin/bash

set -uo pipefail

KEY='882DCFE48E2051D48E2562ABF3B607488DB35A47'
BASE='https://mirror.cachyos.org/repo/x86_64/cachyos'
CONF='https://raw.githubusercontent.com/stevensko/blendos/main/.config/akshara/cachyos.conf'

pick() {
    curl -fsSL "$BASE/" \
        | grep -oE "$1-[0-9][A-Za-z0-9._+-]*-any\.pkg\.tar\.zst" \
        | sort -V | tail -n1
}

pacman-key --recv-keys "$KEY" --keyserver hkps://keyserver.ubuntu.com \
  || pacman-key --recv-keys "$KEY" --keyserver hkps://keys.openpgp.org
pacman-key --lsign-key "$KEY"

pacman -U --noconfirm \
    "$BASE/$(pick cachyos-keyring)" \
    "$BASE/$(pick cachyos-mirrorlist)" \
    "$BASE/$(pick cachyos-v3-mirrorlist)"

rank_mirrorlist() {   # rank_mirrorlist <file> <repo> <archtoken> <archval>
    local file=$1 repo=$2 archtoken=$3 archval=$4
    local token="\$${archtoken}" url probe i=0 tmp
    local -a urls
    mapfile -t urls < <(sed -n 's/^Server = //p' "$file")
    [ "${#urls[@]}" -eq 0 ] && return 0

    tmp=$(mktemp -d)
    for url in "${urls[@]}"; do
        probe=${url//'$repo'/$repo}
        probe=${probe//$token/$archval}
        i=$((i + 1))
        ( t=$(curl -fsS -o /dev/null -w '%{time_total}' --max-time 5 "$probe/$repo.db" 2>/dev/null) \
              && printf '%s %s\n' "$t" "$url" > "$tmp/$i" ) &
    done
    wait

    cat "$tmp"/* 2>/dev/null | sort -n | awk '{ $1=""; sub(/^ /,""); print "Server = " $0 }' > "$tmp/sorted"
    [ -s "$tmp/sorted" ] && cat "$tmp/sorted" > "$file"
    rm -rf "$tmp"
}

rank_mirrorlist /etc/pacman.d/cachyos-mirrorlist    cachyos    arch    x86_64
rank_mirrorlist /etc/pacman.d/cachyos-v3-mirrorlist cachyos-v3 arch_v3 x86_64_v3

curl -fsSL "$CONF" -o /etc/pacman.d/cachyos.conf

[ -e /etc/pacman.conf.pacsave ] || cp -a /etc/pacman.conf /etc/pacman.conf.pacsave

sed -i 's/^Architecture[[:space:]]*=.*/Architecture = x86_64 x86_64_v3/' /etc/pacman.conf

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
