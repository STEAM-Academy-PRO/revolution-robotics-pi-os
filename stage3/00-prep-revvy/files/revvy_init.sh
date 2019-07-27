#!/bin/bash
# Boot time init script for Revvy

# Setup the audio output on the GPIO
/usr/bin/amixer cset numid=3 1   # playback rounte: headphone jack
/usr/bin/amixer cset numid=1 0   # playback volume: 0 = 86%
/usr/bin/gpio -g mode 13 alt0    # PWM1
/usr/bin/gpio -g mode 18 alt5    # PWM0
/usr/bin/gpio -g mode 22 output  # AMP_EN
/usr/bin/gpio -g write 22 0      # disable by default, so wont hum
