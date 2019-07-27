#!/bin/bash -e

echo " Start installing things that are unique to revvy "

on_chroot << EOF
echo "  Enable ttyS0 "
systemctl mask serial-getty@ttyS0.service
usermod -a -G tty pi

echo "  Enable raw sockets for python for BT "
setcap 'cap_net_raw,cap_net_admin+eip' \$(readlink -f \$(which python3))
EOF

echo "  Deploy python service "
mkdir -p "${ROOTFS_DIR}/home/pi/revvy"
install -m 755 files/revvy.py		"${ROOTFS_DIR}/home/pi/revvy/"
install -m 644 files/revvy.service		"${ROOTFS_DIR}/etc/systemd/system/revvy.service"
install -m 644 files/requirements.txt		"${ROOTFS_DIR}/home/pi/revvy/"

on_chroot << EOF
echo "   Install python dependencies "
pip3 install -r /home/pi/revvy/requirements.txt
echo "   Enable python service "
systemctl enable revvy
EOF
