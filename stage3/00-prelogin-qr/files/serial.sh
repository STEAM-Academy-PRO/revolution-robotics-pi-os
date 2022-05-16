#!/usr/bin/sh

SERIAL=`cat /proc/cpuinfo | sed -n 's/Serial[^0]*0*//p'`

/usr/bin/qrencode -t ANSI -m 2 "Revvy_${SERIAL}" -o /etc/issue

if [ -f "/boot/serial_number" ]; then
    STORED=`cat /boot/serial_number`
else
    STORED=""
fi

if [ "${SERIAL}" != "${STORED}" ]; then
    echo "Updating serial number in /boot/serial_number"
    mount -o remount,rw /boot
    echo "Revvy_${SERIAL}" | tee /boot/serial_number
    sync /boot/serial_number
    mount -o remount,ro /boot
fi
