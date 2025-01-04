#!/bin/bash

# 512 + 2 (GPIO 2)
GPIO=514
GPIO_PATH="/sys/class/gpio/gpio${GPIO}"

echo "RETROPICO: Starting 5v module disable script" > /dev/ttyAMA0

# do not disable 5v module on reboot
if [ "$1" == "reboot" ]; then
    echo "RETROPICO: Skipping 5v module disable (rebooting)" > /dev/ttyAMA0
    exit 0
fi

# set up GPIO 2 and set to input
echo "${GPIO}" > /sys/class/gpio/unexport
echo "${GPIO}" > /sys/class/gpio/export
echo "out" > ${GPIO_PATH}/direction

# write to gpio output
echo "Writing to gpio..."

echo "0" > ${GPIO_PATH}/value
sleep 0.1
echo "1" > ${GPIO_PATH}/value

sleep 0.5

echo "0" > ${GPIO_PATH}/value
sleep 0.1
echo "1" > ${GPIO_PATH}/value

# clean up
echo "${GPIO}" > /sys/class/gpio/unexport

