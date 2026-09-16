#!/bin/bash

set -uo pipefail

source /var/tmp/manifest.sh
source /var/tmp/fallback.sh

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

priority_v3 "${ARCH[@]}"
arch_rc=$?

aur_paru -Sy --noconfirm --noprogressbar --removemake --skipreview --cleanafter --ask=4 --needed "${AUR[@]}"
rc=$?

missing=()
for p in "${ARCH[@]}" "${AUR[@]}"; do
    pacman -Qq -- "$p" &>/dev/null || missing+=("$p")
done

pacman -Rns --noconfirm linux-zen linux-zen-headers paru

[ "$arch_rc" -eq 0 ] || rc=$arch_rc

if [ "${#missing[@]}" -gt 0 ]; then
    printf 'install.sh: packages NOT installed: %s\n' "${missing[*]}"
    rc=1
else
    printf 'install.sh: all requested packages installed\n'
fi

exit "$rc"
