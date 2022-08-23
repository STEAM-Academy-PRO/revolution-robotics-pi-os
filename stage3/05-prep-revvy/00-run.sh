#!/bin/bash -e

echo " Start installing things that are unique to revvy "

on_chroot << EOF
echo "  Enable raw sockets for python for BT "
#setcap 'cap_net_raw,cap_net_admin+eip' /usr/bin/python3.9

echo "  Enable i2c module "
echo "i2c-dev" >> /etc/modules

# disable swapping
#sudo dphys-swapfile swapoff
#sudo dphys-swapfile uninstall
#sudo update-rc.d dphys-swapfile remove
#sudo apt purge -y dphys-swapfile

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

EOF

echo "  Deploy python service "
install -m 644 files/revvy.service        "${ROOTFS_DIR}/etc/systemd/system/revvy.service"

git clone https://github.com/RevolutionRobotics/RevvyLauncher.git
echo "  Copying launcher to ${ROOTFS_DIR}/home/pi/RevvyFramework"
cp -r RevvyLauncher/src "${ROOTFS_DIR}/home/pi/RevvyFramework"
echo "  Deleting launcher sources "
rm -rf RevvyLauncher

echo " Downloading latest framework source "
mkdir tempRF
cd tempRF
git clone https://github.com/RevolutionRobotics/RevvyFramework.git
cd RevvyFramework

echo " Creating install package "
python3 -m dev_tools.create_package
echo "  Copying install files to ${ROOTFS_DIR}/home/pi/RevvyFramework/user/ble/"

on_chroot << EOF
echo "  Setting permissions on data directory "
chmod 755 -R /home/pi/RevvyFramework/

mkdir -p /home/pi/RevvyFramework/user/ble
mkdir -p /home/pi/RevvyFramework/user/data
mkdir -p /home/pi/RevvyFramework/user/packages
EOF

cp install/framework.data "${ROOTFS_DIR}/home/pi/RevvyFramework/user/ble/2.data"
cp install/framework.meta "${ROOTFS_DIR}/home/pi/RevvyFramework/user/ble/2.meta"
cp install/*.gz "${ROOTFS_DIR}/home/pi/RevvyFramework/user/packages/"

cd ..

echo "  Deleting framework sources "
rm -rf RevvyFramework

echo " Deleting tempRF directory"
cd ..
rm -rf tempRF

on_chroot << EOF
echo "  Install the included package to the read-only part"
python3 /home/pi/RevvyFramework/launch_revvy.py --install-only --install-default

echo "  Set the data directory to be writeable by the framework"
chown pi:pi -R "/home/pi/RevvyFramework/user"
chmod 775 -R "/home/pi/RevvyFramework/user"

echo "  Enable Revvy service "
systemctl enable revvy
EOF
