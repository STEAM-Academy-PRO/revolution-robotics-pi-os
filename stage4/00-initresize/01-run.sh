#!/bin/bash -e

install -d				"${ROOTFS_DIR}/usr/lib/revvy-config"
install -m 755 files/init_resize.sh	"${ROOTFS_DIR}/usr/lib/revvy-config/"
