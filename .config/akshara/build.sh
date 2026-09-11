#!/bin/bash

set -uo pipefail

ARCH=(
  adw-gtk-theme
  adwaita-icon-theme
  ananicy-cpp
  android-tools
  aria2
  base-devel
  bluez-utils
  btrfs-assistant
  cachyos-ananicy-rules
  clonezilla
  distrobox
  dkms
  flatpak
  gdm
  ghostty
  git
  glib2-devel
  gnome-browser-connector
  gnome-control-center
  gnome-keyring
  gnome-session
  gnome-settings-daemon
  gnome-shell
  gnome-themes-extra
  gpaste
  gufw
  gvfs
  imagemagick
  imwheel
  iptables-nft
  jellyfin-server
  jellyfin-web
  keepass
  libinput-gestures
  libsecret
  linux-cachyos
  linux-cachyos-headers
  linux-cachyos-lts-lto
  linux-cachyos-lts-lto-headers
  mesa
  mission-center
  nautilus
  networkmanager
  noto-fonts-emoji
  pipewire
  pipewire-pulse
  plymouth
  podman
  procps-ng
  ptyxis
  python-setuptools
  qbittorrent
  rclone
  samba
  scx-scheds
  sushi
  syncthing
  systemdgenie
  tailscale
  toolbox
  ttf-jetbrains-mono-nerd
  ufw
  unzip
  wireplumber
  wl-clipboard
  wmctrl
  xclip
  xdg-desktop-portal-gnome
  xdotool
  zip
  zsh
)

AUR=(
  brave-origin-beta-bin
  gnome-rounded-blur
  grub-customizer
  input-remapper-bin
  jopdf
  nautilus-copy-path
  rabbitvcs-nautilus
  vscodium-insiders-bin
  xdg-terminal-exec
)

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

pacman -Sy

prefer_v3 "${ARCH[@]}"

pacman -Rns --noconfirm linux-zen linux-zen-headers

mapfile -t base < <(pacman -Qqn)
prefer_v3 "${base[@]}"

pacman -Qq paru &>/dev/null && had_paru=1 || had_paru=0
pacman -S --needed --noconfirm base-devel git sudo fakeroot paru

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

aur_paru -Sy --noconfirm --noprogressbar --removemake --skipreview --cleanafter --ask=4 --needed "${AUR[@]}"
rc=$?

[ "$had_paru" -eq 1 ] || pacman -Rns --noconfirm paru || true

exit "$rc"
