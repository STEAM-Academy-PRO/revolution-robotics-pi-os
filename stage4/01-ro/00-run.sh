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

echo "  Relocate dhcp related files"
mv /etc/resolv.conf /var/run/resolv.conf && ln -s /var/run/resolv.conf /etc/resolv.conf
sed -i 's#PIDFile=/run/dhcpcd.pid#PIDFile=/var/run/dhcpcd.pid#' /lib/systemd/system/dhcpcd.service
# Disable wait for dhcp
rm -f /etc/systemd/system/dhcpcd.service.d/wait.conf

echo "  Stop mask systemd timers/services"
systemctl disable systemd-tmpfiles-clean.timer systemd-tmpfiles-clean
systemctl mask systemd-update-utmp systemd-update-utmp-runlevel
systemctl mask systemd-rfkill systemd-rfkill.socket  # enable/disable wireless devices, bluetooth
systemctl disable systemd-fsck-root

echo "  ROize prelogin-qr"
rm -rf /etc/motd
ln -s /tmp/etc-motd /etc/motd

#FIXME: regenerate_ssh_host_keys.service wants to write to /etc/ssh so we disable it for now
/usr/bin/ssh-keygen -A -v
systemctl disable regenerate_ssh_host_keys

EOF
