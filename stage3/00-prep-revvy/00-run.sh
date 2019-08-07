#!/bin/bash -e

echo " Start installing things that are unique to revvy "

on_chroot << EOF
echo "  Enable raw sockets for python for BT "
setcap 'cap_net_raw,cap_net_admin+eip' \$(readlink -f \$(which python3))

echo "  Enable i2c module "
echo "i2c-dev" >> /etc/modules
EOF

install -m 644 files/revvy.service        "${ROOTFS_DIR}/etc/systemd/system/revvy.service"

echo "  Deploy python service "

git clone https://github.com/RevolutionRobotics/RevvyLauncher.git
echo "  Copying launcher to ${ROOTFS_DIR}/home/pi/RevvyFramework"
cp -r RevvyLauncher/src "${ROOTFS_DIR}/home/pi/RevvyFramework"
echo "  Deleting launcher sources "
rm -rf RevvyLauncher

echo " Downloading latest framework source "
git clone https://github.com/RevolutionRobotics/RevvyAlphaKit.git
cd RevvyAlphaKit

echo " Creating install package "
python3 -m tools.create_package
echo "  Copying install files to ${ROOTFS_DIR}/home/pi/RevvyFramework/data/ble/"
cp install/framework.data "${ROOTFS_DIR}/home/pi/RevvyFramework/data/ble/2.data"
cp install/framework.meta "${ROOTFS_DIR}/home/pi/RevvyFramework/data/ble/2.meta"

cd ..
echo "  Deleting framework sources "
rm -rf RevvyAlphaKit

on_chroot << EOF
echo "  Setting permissions on data directory "
chown pi:pi -R "/home/pi/RevvyFramework"
chmod 755 -R /home/pi/RevvyFramework/
echo "  Install the included package "
python3 /home/pi/RevvyFramework/launch_revvy.py --install-only
echo "  Enable Revvy service "
systemctl enable revvy
EOF
