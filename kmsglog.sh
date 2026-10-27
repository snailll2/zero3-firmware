#!/bin/sh
# kmsg 增量流式落盘(dmesg -c 读并清,1s 粒度,跨死亡保留)
: > /data/kmsg.log
while :; do
  dmesg -c >> /data/kmsg.log 2>/dev/null
  sleep 1
done
