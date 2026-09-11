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

aur_paru -Sy --noconfirm --noprogressbar --removemake --skipreview --cleanafter --ask=4 --needed "${AUR[@]}"
rc=$?

pacman -Rns --noconfirm linux-zen linux-zen-headers paru

exit "$rc"
