#!/bin/bash

set -uo pipefail

PKGS=(
  # --- repo ---
  adw-gtk-theme adwaita-icon-theme android-tools aria2 base-devel bluez-utils
  btrfs-assistant clonezilla distrobox dkms flatpak gdm ghostty git glib2-devel
  gnome-browser-connector gnome-control-center gnome-keyring gnome-session
  gnome-settings-daemon gnome-shell gnome-themes-extra gpaste gufw gvfs
  imagemagick imwheel iptables-nft jellyfin-server jellyfin-web keepass
  libinput-gestures libsecret mesa mission-center nautilus networkmanager
  noto-fonts-emoji pipewire pipewire-pulse plymouth podman procps-ng ptyxis
  python-setuptools qbittorrent rclone samba sushi syncthing systemdgenie
  tailscale toolbox ttf-jetbrains-mono-nerd ufw unzip wireplumber wl-clipboard
  wmctrl xclip xdotool xdg-desktop-portal-gnome zip zsh ananicy-cpp scx-scheds
  linux-cachyos linux-cachyos-headers cachyos-ananicy-rules
  # --- AUR ---
  brave-origin-beta-bin vscodium-insiders-bin gnome-rounded-blur grub-customizer
  xdg-terminal-exec jopdf rabbitvcs-nautilus nautilus-copy-path input-remapper-bin
)

# refresh databases so paru.sh can resolve the new repos
pacman -Sy

# paru is not in the blendOS base or the track - it only lands in the rootfs
# when system.yaml has aur-packages:, which this one doesn't. Pull it in for the
# build and drop it again afterwards, the same way the build user is torn down.
pacman -Qq paru &>/dev/null && had_paru=1 || had_paru=0
pacman -S --needed --noconfirm base-devel git sudo fakeroot paru

id builder &>/dev/null || useradd -m -G wheel -s /bin/bash builder
printf 'builder ALL=(ALL) NOPASSWD: ALL\n' > /etc/sudoers.d/00-builder
chmod 440 /etc/sudoers.d/00-builder

runparu() {
    sudo -u builder env HOME=/home/builder PARU_PAGER=cat \
        paru "$@" --noconfirm --skipreview --nokeepsrc --batchinstall --sudoloop
}

# migrate the base package set to its cachyos-v3 builds first, while it's still
# small. no --needed: cachyos-v3 shares Arch's pkgver, so only a plain reinstall
# swaps it. the PKGS install below then pulls new packages as v3 natively.
mapfile -t native < <(pacman -Qqn)
runparu -S "${native[@]}" || true

runparu -S --needed --removemake --cleanafter "${PKGS[@]}"
rc=$?

rm -f /etc/sudoers.d/00-builder
userdel -r builder 2>/dev/null || true
[ "$had_paru" -eq 1 ] || pacman -Rns --noconfirm paru || true

exit "$rc"
