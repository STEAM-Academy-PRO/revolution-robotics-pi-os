#!/bin/bash -e

echo "Installing custom kernel(s)..."

install -m 644 files/raspberrypi-kernel_armhf.deb $ROOTFS_DIR/tmp/raspberrypi-kernel_armhf.deb

on_chroot << EOF
dpkg -i /tmp/raspberrypi-kernel_armhf.deb
EOF

rm -f $ROOTFS_DIR/tmp/raspberrypi-kernel_armhf.deb

echo "Custom kernel(s) installed."
