#!/bin/sh
# bx2 黑匣子:5s 一拍,跨开机追加(静默复位取证)
B=/data/bx2.log
echo "===== BOOT $(date +%s) =====" >> $B
while :; do
  G=$(pidof nx5gui); TH=0
  [ -n "$G" ] && TH=$(ls /proc/$G/task 2>/dev/null | wc -l)
  G84=$(cat /sys/class/gpio/gpio84/value 2>/dev/null)
  MA=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
  DUTY=$(cat /sys/class/pwm/pwmchip0/pwm0/duty_cycle 2>/dev/null)
  MC=$(grep -ac "mqtt. connected" /data/nx5gui_live.log)
  echo "$(date +%s) up=$(cut -d. -f1 /proc/uptime) gui=$G th=$TH g84=$G84 MA=$MA duty=$DUTY mqttc=$MC" >> $B
  if [ "$(wc -c < $B)" -gt 1048576 ]; then tail -c 524288 $B > ${B}.t && mv -f ${B}.t $B; fi
  sleep 5
done
#
