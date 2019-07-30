#!/bin/bash -e

echo " Start installing things that are unique to revvy "

on_chroot << EOF
echo "  Enable raw sockets for python for BT "
setcap 'cap_net_raw,cap_net_admin+eip' \$(readlink -f \$(which python3))
EOF

install -m 644 files/revvy.service        "${ROOTFS_DIR}/etc/systemd/system/revvy.service"

echo "  Deploy python service "
mkdir -p "${ROOTFS_DIR}/home/pi/RevvyFramework"

git clone https://github.com/RevolutionRobotics/RevvyLauncher.git
cd RevvyLauncher
find src -type f -exec install -D "{}" "${ROOTFS_DIR}/home/pi/RevvyFramework" \;
cd ..
echo "  Deleting launcher sources "
rm -rf RevvyLauncher

echo " Downloading latest framework source "
git clone https://github.com/RevolutionRobotics/RevvyAlphaKit.git
cd RevvyAlphaKit

echo " Creating install package "
python3 -m tools.create_package
cp install/framework.data "${ROOTFS_DIR}/home/pi/RevvyFramework/data/ble/2.data"
cp install/framework.meta "${ROOTFS_DIR}/home/pi/RevvyFramework/data/ble/2.meta"

cd ..
echo "  Deleting framework sources "
rm -rf RevvyAlphaKit

on_chroot << EOF
echo "  Install the included package "
python3 /home/pi/RevvyFramework/launch_revvy.py --install-only
echo "  Enable Revvy service "
systemctl enable revvy
EOF
