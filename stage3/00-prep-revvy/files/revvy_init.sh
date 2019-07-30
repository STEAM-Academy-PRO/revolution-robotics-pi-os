#!/bin/bash
# Boot time init script for Revvy

# Setup the audio output on the GPIO
/usr/bin/amixer cset numid=3 1   # playback rounte: headphone jack
/usr/bin/amixer cset numid=1 0   # playback volume: 0 = 86%
