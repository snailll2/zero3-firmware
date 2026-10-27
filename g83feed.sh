#!/bin/sh
# g83feed:外部硬看门狗 GPIO83 喂狗(500ms 翻转,复刻原厂 2Hz 语义)
while :; do
  if [ ! -d /sys/class/gpio/gpio83 ]; then
    echo 83 > /sys/class/gpio/export 2>/dev/null
    echo out > /sys/class/gpio/gpio83/direction 2>/dev/null
    sleep 1
  fi
  echo 1 > /sys/class/gpio/gpio83/value 2>/dev/null
  sleep 0.5 2>/dev/null || usleep 500000
  echo 0 > /sys/class/gpio/gpio83/value 2>/dev/null
  sleep 0.5 2>/dev/null || usleep 500000
done
#
