#!/bin/bash -e

echo " Disabling/removing things that are not needed "

on_chroot << EOF

# disable swapping
sudo dphys-swapfile swapoff
sudo dphys-swapfile uninstall
sudo update-rc.d dphys-swapfile remove
sudo apt purge -y dphys-swapfile

# disable services that are not needed
sudo systemctl disable systemd-update-utmp.service
sudo systemctl mask systemd-update-utmp.service
sudo systemctl disable apt-daily.service
sudo systemctl mask apt-daily.service
sudo systemctl disable apt-daily.timer
sudo systemctl disable apt-daily-upgrade.service
sudo systemctl mask apt-daily-upgrade.service
sudo systemctl disable apt-daily-upgrade.timer
sudo systemctl disable man-db.service
sudo systemctl disable man-db.timer
sudo systemctl disable systemd-timesyncd.service
sudo systemctl disable wpa_supplicant.service
sudo systemctl disable keyboard-setup.service
sudo systemctl disable graphical.target
sudo systemctl disable sshswitch
sudo systemctl disable rpi-eeprom-update.service
sudo systemctl disable raspberrypi-net-mods.service
sudo systemctl disable raspi-config.service
sudo systemctl disable dhcpcd.service
sudo systemctl disable e2scrub_reap.service
sudo systemctl disable sys-kernel-debug.mount
sudo systemctl disable sys-kernel-tracing.mount
# sudo systemctl disable avahi-daemon.service # disabling breaks USB-ethernet

# anything remote-fs
sudo systemctl disable nfs-client.target
sudo systemctl disable remote-fs.target
sudo systemctl disable remote-fs-pre.target
sudo systemctl mask nfs-config.service

sudo systemctl disable busybox-klogd.service
sudo systemctl disable busybox-syslogd.service
sudo systemctl mask systemd-journald.service
sudo systemctl disable systemd-journal-flush.service
sudo chmod -x /etc/rc.local
sudo systemctl disable rng-tools-debian.service

# enable ssh by default
sudo systemctl enable ssh

sudo apt remove libx11* -y

sudo apt autoremove -y

EOF
