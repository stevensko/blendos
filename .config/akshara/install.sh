#!/bin/bash

set -uo pipefail

PACMAN=(
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

pacman -Sy --needed --noconfirm --ask=4 "${PACMAN[@]}"

pacman -Qqn | pacman -S --noconfirm --ask=4 - || true

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

# drop paru again if we added it
[ "$had_paru" -eq 1 ] || pacman -Rns --noconfirm paru || true

exit "$rc"
