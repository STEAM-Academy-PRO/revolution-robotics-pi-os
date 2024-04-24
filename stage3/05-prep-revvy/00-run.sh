#!/bin/bash -e

echo " Start installing things that are unique to revvy "

on_chroot << EOF
echo "  Enable raw sockets for python for BT "
#setcap 'cap_net_raw,cap_net_admin+eip' /usr/bin/python3.9

echo "  Enable i2c module "
echo "i2c-dev" >> /etc/modules

EOF

echo "  Deploy python service "
install -m 644 files/revvy.service        "${ROOTFS_DIR}/etc/systemd/system/revvy.service"

echo "  Copying launcher to ${ROOTFS_DIR}/home/pi/RevvyFramework"
cp -r files/RevvyLauncher/src "${ROOTFS_DIR}/home/pi/RevvyFramework"

echo "  Copying mjpg-streamer to ${ROOTFS_DIR}/home/pi/mjpg-streamer"
cp -r files/mjpg-streamer "${ROOTFS_DIR}/home/pi/mjpg-streamer"

on_chroot << EOF
echo "  Setting permissions on data directory "
chmod 755 -R /home/pi/RevvyFramework/

mkdir -p /home/pi/RevvyFramework/user/ble
mkdir -p /home/pi/RevvyFramework/user/data
mkdir -p /home/pi/RevvyFramework/user/packages
EOF

mkdir tempRF
cd tempRF

if [ -z ${FIRMWARE_RELEASE} ]; then
    echo " Downloading latest release "
    gh release download ${FIRMWARE_RELEASE} -R STEAM-Academy-PRO/revolution-robotics-robot-mind -p "pi-firmware.*"

    echo "  Copying install files to ${ROOTFS_DIR}/home/pi/RevvyFramework/user/ble/"

    cp pi-firmware.data "${ROOTFS_DIR}/home/pi/RevvyFramework/user/ble/2.data"
    cp pi-firmware.meta "${ROOTFS_DIR}/home/pi/RevvyFramework/user/ble/2.meta"

    tar -xvf pi-firmware.data
    cp install/requirements.txt "${ROOTFS_DIR}/home/pi/requirements.txt"
    cp install/requirements_dev.txt "${ROOTFS_DIR}/home/pi/requirements_dev.txt"

elif [ -z ${FIRMWARE_REV} ]; then
    echo " Downloading latest firmware source "
    echo " WARNING: currently this package will not include the mcu-firmware!! "

    git clone git@github.com:STEAM-Academy-PRO/revolution-robotics-robot-mind.git
    cd revolution-robotics-robot-mind/pi-firmware
    git checkout ${FIRMWARE_REV}

    echo " Creating install package "
    python3 -m dev_tools.create_package
    echo "  Copying install files to ${ROOTFS_DIR}/home/pi/RevvyFramework/user/ble/"

    cp install/pi-firmware.data "${ROOTFS_DIR}/home/pi/RevvyFramework/user/ble/2.data"
    cp install/pi-firmware.meta "${ROOTFS_DIR}/home/pi/RevvyFramework/user/ble/2.meta"

    cp install/requirements.txt "${ROOTFS_DIR}/home/pi/requirements.txt"
    cp install/requirements_dev.txt "${ROOTFS_DIR}/home/pi/requirements_dev.txt"

    echo "  Deleting pi-firmware sources "
    rm -rf revolution-robotics-robot-mind
    cd ../..
else
    echo " No firmware release or revision specified "
    exit 1
fi



echo " Deleting tempRF directory"
cd ..
rm -rf tempRF


on_chroot << EOF
echo "  Install requirements"
pip3 install -r /home/pi/requirements.txt
pip3 install -r /home/pi/requirements_dev.txt

rm /home/pi/requirements.txt
rm /home/pi/requirements_dev.txt

echo "  Install the included package to the read-only part"
python3 /home/pi/RevvyFramework/launch_revvy.py --install-only --install-default

echo "  Set the data directory to be writeable by the framework"
chown pi:pi -R "/home/pi/RevvyFramework/user"
chmod 775 -R "/home/pi/RevvyFramework/user"

echo "  Enable Revvy service "
systemctl enable revvy
EOF
