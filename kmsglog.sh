#!/bin/sh
# kmsg 增量流式落盘 v2(取证):跨开机追加,绝不截断历史!
# (旧版 :> 截断=每次开机毁掉上一世的内核证据,追不了静默复位)
L=/data/kmsg.log
echo "===== BOOT $(date +%s) uptime=$(cut -d. -f1 /proc/uptime) =====" >> $L
while :; do
  dmesg -c >> $L 2>/dev/null
  if [ "$(wc -c < $L)" -gt 8388608 ]; then
    tail -c 4194304 $L > ${L}.t && mv -f ${L}.t $L
  fi
  sleep 1
done
#
