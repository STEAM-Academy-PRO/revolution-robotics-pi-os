#!/bin/bash -e

#Alacarte fixes
install -v -o 1000 -g 1000 -d "${ROOTFS_DIR}/home/${FIRST_USER_NAME}/.local"
install -v -o 1000 -g 1000 -d "${ROOTFS_DIR}/home/${FIRST_USER_NAME}/.local/share"
install -v -o 1000 -g 1000 -d "${ROOTFS_DIR}/home/${FIRST_USER_NAME}/.local/share/applications"
install -v -o 1000 -g 1000 -d "${ROOTFS_DIR}/home/${FIRST_USER_NAME}/.local/share/desktop-directories"


echo $ROOTFS_DIR 
echo $FIRST_USER_NAME


# setcap 'cap_net_raw+eip' /usr/bin/python3.9
setcap 'cap_net_raw+eip' "${ROOTFS_DIR}/usr/bin/python3.9"
#echo 'sudo systemctl restart revvy.service' >> "${ROOTFS_DIR}/home/pi/.bashrc"
