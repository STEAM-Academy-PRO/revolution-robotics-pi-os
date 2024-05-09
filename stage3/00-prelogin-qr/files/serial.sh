#!/usr/bin/sh

SERIAL=`cat /proc/cpuinfo | sed -n 's/Serial[^0]*0*//p'`
QR=`/usr/bin/qrencode -t ANSI -m 2 "Revvy_${SERIAL}˙"`

echo "Serial number:\n${QR}" > /etc/motd
