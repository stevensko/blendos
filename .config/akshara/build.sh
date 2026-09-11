#!/bin/bash

set -uo pipefail

source /var/tmp/manifest.sh

__names() {
    grep -oE "retrieving file '[^']+\.pkg\.tar\.zst(\.sig)?'" \
      | sed -E "s/.*'([^']+)'.*/\1/" \
      | while read -r f; do
            f=${f%.sig}; f=${f%.pkg.tar.zst}
            f=${f%-x86_64_v3}; f=${f%-x86_64}; f=${f%-any}
            f=${f%-*}; printf '%s\n' "${f%-*}"
        done | sort -u
}

prefer_v3() {
    local pkgs=("$@") try out m2 m3 keep p generic arch
    generic=$(mktemp); arch=$(mktemp)
    printf '[cachyos]\nInclude = /etc/pacman.d/cachyos-mirrorlist\n' > /etc/pacman.d/cachyos-generic.conf
    sed 's#cachyos\.conf#cachyos-generic.conf#' /etc/pacman.conf > "$generic"
    sed '/cachyos/d'                            /etc/pacman.conf > "$arch"

    for try in 1 2 3 4 5; do
        [ "${#pkgs[@]}" -eq 0 ] && break
        out=$(pacman -S --noconfirm --ask=4 "${pkgs[@]}" 2>&1) && { rm -f "$generic" "$arch"; return 0; }
        printf '%s\n' "$out"

        mapfile -t m2 < <(printf '%s\n' "$out" | __names)
        if [ "${#m2[@]}" -gt 0 ]; then
            printf 'prefer_v3: not in v3, trying cachyos generic: %s\n' "${m2[*]}"
            out=$(pacman -S --noconfirm --ask=4 --config "$generic" "${m2[@]}" 2>&1); printf '%s\n' "$out"
            mapfile -t m3 < <(printf '%s\n' "$out" | __names)
            if [ "${#m3[@]}" -gt 0 ]; then
                printf 'prefer_v3: not in cachyos generic either, taking from Arch: %s\n' "${m3[*]}"
                pacman -S --noconfirm --ask=4 --config "$arch" "${m3[@]}" || true
            fi
            keep=()
            for p in "${pkgs[@]}"; do
                printf '%s\n' "${m2[@]}" | grep -qxF -- "$p" || keep+=("$p")
            done
            pkgs=("${keep[@]}")
        fi
        sleep 20
    done

    rm -f "$generic" "$arch"
    [ "${#pkgs[@]}" -eq 0 ]
}

aur_paru() {
    local i rc=1
    for ((i = 1; i <= 30; i++)); do
        useradd -m -G wheel -s /bin/bash aur
        echo 'aur ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/aur
        runuser -u aur -- paru "$@"
        rc=$?
        userdel -r aur 2>/dev/null
        rm -f /etc/sudoers.d/aur
        [ "$rc" -eq 0 ] && return 0
    done
    return "$rc"
}

pacman -Sy

prefer_v3 "${ARCH[@]}"

aur_paru -Sy --noconfirm --noprogressbar --removemake --skipreview --cleanafter --ask=4 --needed "${AUR[@]}"
rc=$?

pacman -Rns --noconfirm linux-zen linux-zen-headers paru

mapfile -t base < <(pacman -Qqn)
prefer_v3 "${base[@]}"

exit "$rc"
