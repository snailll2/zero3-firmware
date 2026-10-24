#!/bin/sh
# btproxy.sh — NX5 蓝牙代理启动器(开机链/手动均可)
# 策略:面板 mesh 网络为空,mgw_bt 无用;冻结 guardian 防其重生 mgw_bt,
#       杀 mgw_bt 释放 /dev/ttyS2,启动 btproxy(配置 /data/btproxy.conf)
[ -f /data/btproxy.conf ] || { echo "btproxy.conf missing"; exit 1; }
GUARD=$(pidof aciga_guardian)
[ -n "$GUARD" ] && kill -STOP $GUARD 2>/dev/null
for p in $(pidof mgw_bt); do kill -9 $p 2>/dev/null; done
for p in $(pidof btproxy); do kill -9 $p 2>/dev/null; done
sleep 1
(setsid /data/btproxy >/dev/null 2>&1 &)
echo "btproxy started (guardian ${GUARD:-none} frozen)"
