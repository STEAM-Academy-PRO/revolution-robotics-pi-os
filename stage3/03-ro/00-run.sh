#!/bin/bash -e

on_chroot << EOF

echo "  Remove unused packages"
sudo apt-get remove --purge -y triggerhappy logrotate cron
# update logging (from medium/swlh). should do? logread to see logs
# sudo apt-get install -y busybox-syslogd
sudo apt-get remove --purge -y rsyslog

# Some extras we remove to shrink the image
sudo apt remove -y rng-tools-debian
sudo apt remove -y libgraphite2-3
sudo apt remove -y fontconfig
sudo apt remove -y man-db

sudo apt-get autoremove --purge -y

echo "  Stop mask systemd timers/services"
systemctl disable systemd-tmpfiles-clean.timer systemd-tmpfiles-clean
systemctl mask systemd-update-utmp systemd-update-utmp-runlevel
systemctl mask systemd-rfkill systemd-rfkill.socket  # enable/disable wireless devices, bluetooth
systemctl disable systemd-fsck-root

echo "  ROize prelogin-qr"
rm -rf /etc/issue
ln -s /tmp/etc-issue /etc/issue

echo "  ROize NetworkManager"
mv /etc/NetworkManager/system-connections /boot/system-connections
ln -s /boot/system-connections /etc/NetworkManager/system-connections

#FIXME: regenerate_ssh_host_keys.service wants to write to /etc/ssh so we disable it for now
/usr/bin/ssh-keygen -A -v
systemctl disable regenerate_ssh_host_keys

EOF
