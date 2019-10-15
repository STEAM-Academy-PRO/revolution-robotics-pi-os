#!/bin/bash -e

echo "  Deploy prelogin-qr service "
install -m 644 files/prelogin-qr.service        "${ROOTFS_DIR}/etc/systemd/system/prelogin-qr.service"

on_chroot << EOF
echo "  Enable prelogin-qr service "
systemctl enable prelogin-qr
EOF
