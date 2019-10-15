#!/bin/bash -e

on_chroot << EOF
systemctl disable resize2fs_once
update-rc.d resize2fs_once remove
rm /etc/init.d/resize2fs_once
EOF
