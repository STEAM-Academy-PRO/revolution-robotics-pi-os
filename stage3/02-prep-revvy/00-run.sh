#!/bin/bash -e

echo " Start installing things that are unique to revvy "

on_chroot << EOF
# remove unnecessary systemd generators
sudo unlink /lib/systemd/user-generators/systemd-xdg-autostart-generator

sudo unlink /lib/systemd/system-generators/systemd-debug-generator
sudo unlink /lib/systemd/system-generators/systemd-hibernate-resume-generator
sudo unlink /lib/systemd/system-generators/systemd-system-update-generator
sudo unlink /lib/systemd/system-generators/systemd-cryptsetup-generator
sudo unlink /lib/systemd/system-generators/systemd-gpt-auto-generator
sudo unlink /lib/systemd/system-generators/systemd-bless-boot-generator
sudo unlink /lib/systemd/system-generators/systemd-run-generator
sudo unlink /lib/systemd/system-generators/systemd-sysv-generator
sudo unlink /lib/systemd/system-generators/systemd-veritysetup-generator
sudo unlink /lib/systemd/system-generators/systemd-rc-local-generator

# disable services that are not needed
sudo systemctl disable systemd-update-utmp.service
sudo systemctl mask systemd-update-utmp.service
sudo systemctl disable apt-daily.service
sudo systemctl mask apt-daily.service
sudo systemctl disable apt-daily.timer
sudo systemctl disable apt-daily-upgrade.service
sudo systemctl mask apt-daily-upgrade.service
sudo systemctl disable apt-daily-upgrade.timer
sudo systemctl disable systemd-timesyncd.service
sudo systemctl disable wpa_supplicant.service
sudo systemctl disable keyboard-setup.service
sudo systemctl disable graphical.target
sudo systemctl disable sshswitch

sudo systemctl mask nfs-client
sudo systemctl mask nfs-config

# sudo rm /lib/systemd/system/modprobe@drm.service

sudo systemctl mask systemd-bless-boot.service
sudo systemctl mask systemd-journald
sudo systemctl mask systemd-journal-flush
sudo systemctl mask rc-local.service
sudo systemctl mask systemd-pstore.service
sudo systemctl mask modprobe@fuse.service
sudo systemctl mask modprobe@configfs.service
sudo systemctl mask modprobe@drm.service
sudo systemctl mask systemd-sysctl.service

sudo systemctl disable rpi-eeprom-update
sudo systemctl disable rpi-display-backlight.service

sudo rm -rf /etc/systemd/system/apply_noobs_os_config.service
sudo rm -rf /etc/systemd/system/apt-daily*
sudo rm -rf /etc/systemd/system/remote-fs.target.wants/
sudo rm -rf /etc/systemd/system/rescue.service
sudo rm -rf /etc/systemd/system/rc-local*
sudo rm -rf /etc/systemd/system/plymouth-start.service
sudo rm -rf /etc/systemd/system/nfs-*

sudo rm -rf /lib/systemd/system/smartcard.target
sudo rm -rf /lib/systemd/system/bthelper@.service
sudo rm -rf /lib/systemd/system/nfs*
sudo rm -rf /lib/systemd/system/emergency*
sudo rm -rf /lib/systemd/system/x11-common.service
sudo rm -rf /lib/systemd/system/systemd-hibernate*
sudo rm -rf /lib/systemd/system/regenerate_ssh_host_keys.service
sudo rm -rf /lib/systemd/system/apt-daily*
sudo rm -rf /lib/systemd/system/keyboard-setup.service
sudo rm -rf /lib/systemd/system/quotaon.service
sudo rm -rf /lib/systemd/system/rescue*
sudo rm -rf /lib/systemd/system/remote-fs*
sudo rm -rf /lib/systemd/system/system-update*
sudo rm -rf /lib/systemd/system/swap.target
sudo rm -rf /lib/systemd/system/systemd-initctl.*
sudo rm -rf /lib/systemd/system/halt.target
sudo rm -rf /lib/systemd/system/hybernate.target
sudo rm -rf /lib/systemd/system/hybrid-sleep.target
sudo rm -rf /lib/systemd/system/ctrl-alt-del.target
sudo rm -rf /lib/systemd/system/rc.service
sudo rm -rf /lib/systemd/system/rcS.service
sudo rm -rf /lib/systemd/system/sudo.service
sudo rm -rf /lib/systemd/system/rpi-display-backlight.service
sudo rm -rf /lib/systemd/system/rc-local*
sudo rm -rf /lib/systemd/system/rpc-svcgssd.service
sudo rm -rf /lib/systemd/system/initrd-root-device.target.wants
sudo rm -rf /lib/systemd/system/remote-cryptsetup.target


EOF

# Wiringpi

echo " Install wiringpi "

git clone https://github.com/WiringPi/WiringPi

cp -r WiringPi "${ROOTFS_DIR}/home/pi/WiringPi"

on_chroot << EOF
cd /home/pi/WiringPi
./build
cd ..
rm -rf WiringPi
EOF

rm -rf WiringPi

# Revvy service and launcher

echo "  Deploy python service "
install -m 644 files/revvy.service        "${ROOTFS_DIR}/etc/systemd/system/revvy.service"

echo "  Copying launcher to ${ROOTFS_DIR}/home/pi/RevvyFramework"
cp -r files/RevvyLauncher/src "${ROOTFS_DIR}/home/pi/RevvyFramework"

on_chroot << EOF
echo "  Setting permissions on data directory "
chmod 755 -R /home/pi/RevvyFramework/

mkdir -p /home/pi/RevvyFramework/user/ble
mkdir -p /home/pi/RevvyFramework/user/data
mkdir -p /home/pi/RevvyFramework/user/packages
EOF

mkdir tempRF
cd tempRF

echo " Downloading tester packages"
git clone git@github.com:STEAM-Academy-PRO/revolution-robotics-peripheral-tester.git .

echo "  Copying files to ${ROOTFS_DIR}/home/pi/RevvyFramework/default/packages/"

cp -r $TESTER_DIR "${ROOTFS_DIR}/home/pi/RevvyFramework/default/packages/${TESTER_DIR}"

echo " Deleting tempRF directory"
cd ..
rm -rf tempRF

on_chroot << EOF
echo "  Install requirements"
pip3 install -r /home/pi/RevvyFramework/default/packages/${TESTER_DIR}/install/requirements.txt
pip3 install -r /home/pi/RevvyFramework/default/packages/${TESTER_DIR}/install/requirements_pi_dev.txt

echo "  Set the data directory to be writeable by the framework"
chown pi:pi -R "/home/pi/RevvyFramework/user"
chmod 775 -R "/home/pi/RevvyFramework/user"

echo "  Enable Revvy service(s)"
systemctl enable revvy

echo "  Remove temporarily installed git"
sudo apt remove -y git
EOF

setcap 'cap_net_raw+eip' "${ROOTFS_DIR}/usr/bin/python3.9"
