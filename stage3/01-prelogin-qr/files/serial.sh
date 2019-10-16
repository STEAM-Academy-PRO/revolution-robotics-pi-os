#!/usr/bin/sh
/usr/bin/qrencode -t ANSI -m 2 "Revvy_`cat /proc/cpuinfo | sed -n 's/Serial[^0]*0*//p'`" -o /etc/issue

