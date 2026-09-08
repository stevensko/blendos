#!/bin/bash

# Plymouth
magick -size 1x1 xc:transparent /usr/share/plymouth/themes/spinner/watermark.png

# GDM
mkdir -p /etc/gdm-shell
cp /usr/share/gnome-shell/gnome-shell-theme.gresource /etc/gdm-shell/gnome-shell-theme.gresource
chmod u=rw,go=r /etc/gdm-shell/gnome-shell-theme.gresource
cp /usr/share/gnome-shell/gnome-shell-theme.gresource /etc/gdm-shell/gnome-shell-theme.gresource.default
chmod u=rw,go=r /etc/gdm-shell/gnome-shell-theme.gresource.default
rm /usr/share/gnome-shell/gnome-shell-theme.gresource
ln -sf /etc/gdm-shell/gnome-shell-theme.gresource /usr/share/gnome-shell/gnome-shell-theme.gresource
ln -sf /etc/gdm-shell/gnome-shell-theme.gresource.default /usr/share/gnome-shell/gnome-shell-theme.gresource.default

# Symlinks
ln -sf /usr/bin/micro /usr/bin/nano
ln -sf /home/user/.local/share/KeePass/Plugins /usr/share/keepass/plugins