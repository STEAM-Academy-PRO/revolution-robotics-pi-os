#!/bin/sh

SERIAL=`cat /proc/cpuinfo | grep Serial`
SERIAL=`echo $SERIAL | sed "s/Serial : //"`

if [ -f "/boot/serial_number" ]; then
    STORED=`sudo cat /boot/serial_number`
else
    STORED=""
fi

if [ "${SERIAL}" != "${STORED}" ]; then
    echo "Updating serial number"
    echo "${SERIAL}" | sudo tee /boot/serial_number
fi
