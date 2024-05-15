#!/bin/bash -e

echo "  Enable usb0 interface"
install -m 644 files/usb0        "${ROOTFS_DIR}/etc/network/interfaces.d/usb0"
