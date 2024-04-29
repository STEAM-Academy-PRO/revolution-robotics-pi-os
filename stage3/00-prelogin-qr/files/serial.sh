#!/usr/bin/sh

SERIAL=`cat /proc/cpuinfo | sed -n 's/Serial[^0]*0*//p'`

if [ -f "/home/pi/serial_number" ]; then
    STORED=`cat /home/pi/serial_number`
else
    STORED=""
fi

if [ "${SERIAL}" != "${STORED}" ]; then
    /usr/bin/qrencode -t ANSI -m 2 "Revvy_${SERIAL}" -o /etc/issue
fi
