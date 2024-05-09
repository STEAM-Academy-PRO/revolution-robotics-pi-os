#!/bin/bash -e

echo "  Deploy prelogin-qr service "
install -m 644 files/prelogin-qr.service        "${ROOTFS_DIR}/etc/systemd/system/prelogin-qr.service"
install -m 755 files/serial.sh                  "${ROOTFS_DIR}/usr/bin/serial.sh"
install -m 755 files/qr.sh                      "${ROOTFS_DIR}/home/pi/qr.sh"
on_chroot << EOF
echo "  Enable prelogin-qr service "
systemctl enable prelogin-qr
EOF
