#!/bin/sh
# zbbridge.sh — NX5 Zigbee 网关接管(方案 B,不刷固件)
# v2(2026-10-24):默认【不再】GPIO81 硬复位——实测该复位线同时清掉蓝牙芯片
#   EFR32BG21 的 RAM 固件(mgw_bt 经 UART DFU 加载),蓝牙会静默(12:18 事故根因)。
#   仅当 NCP 被原厂 z3gateway 污染(残留 customFrame 回调干扰 herdsman)时才需要:
#     sh /data/zbbridge.sh reset
#   reset 模式 = gpio81 复位 + mgw_bt 两段式恢复蓝牙(阶段1 检测 bootloader 则
#   DFU 烧录 ~2min 自动退出;阶段2 运行时初始化开扫 ~60s)+ btproxy 接管。
# 普通模式:冻结 guardian → 杀 z3gateway/mgw_bt → 起 zbbridge → 重启 btproxy。
GUARD=$(pidof aciga_guardian)
[ -n "$GUARD" ] && kill -STOP $GUARD 2>/dev/null
for p in $(pidof aciga_z3gateway); do kill -9 $p 2>/dev/null; done
for p in $(pidof zbbridge); do kill -9 $p 2>/dev/null; done
for p in $(pidof mgw_bt); do kill -9 $p 2>/dev/null; done
sleep 1

if [ "$1" = "reset" ]; then
    echo 0 > /sys/class/gpio/gpio81/value
    sleep 0.1
    echo 1 > /sys/class/gpio/gpio81/value
    sleep 2
    # ---- 蓝牙恢复阶段1:mgw_bt(芯片在 bootloader 则 DFU 烧录,finish 后自退) ----
    kill -9 $(pidof btproxy) 2>/dev/null
    cd /system/user/bin
    export LD_LIBRARY_PATH=/system/user/lib:/system/lib
    rm -f /tmp/mgw1.log /tmp/mgw2.log
    (setsid ./mgw_bt >/tmp/mgw1.log 2>&1 &)
    I=0; MODE=""
    while [ $I -lt 160 ]; do
        sleep 5; I=$((I+5))
        grep -q 'upload_dfu_file' /tmp/mgw1.log 2>/dev/null && MODE=dfu
        if [ "$MODE" = "dfu" ]; then
            grep -q 'upload_dfu_file: DEBUG: finish' /tmp/mgw1.log 2>/dev/null && break
        else
            grep -q 'Advertising' /tmp/mgw1.log 2>/dev/null && break
        fi
        pidof mgw_bt >/dev/null || break
    done
    for p in $(pidof mgw_bt); do kill -9 $p 2>/dev/null; done
    if [ "$MODE" = "dfu" ]; then
        # ---- 阶段2:固件刚烧好,再跑一次做运行时初始化(扫描随 mesh 起来) ----
        (setsid ./mgw_bt >/tmp/mgw2.log 2>&1 &)
        J=0
        while [ $J -lt 90 ]; do
            sleep 5; J=$((J+5))
            grep -q 'Advertising' /tmp/mgw2.log 2>/dev/null && break
            pidof mgw_bt >/dev/null || break
        done
        for p in $(pidof mgw_bt); do kill -9 $p 2>/dev/null; done
    fi
    cd /data
fi

(setsid /data/zbbridge >/data/zbbridge.log 2>&1 &)
sh /data/btproxy.sh
echo "zbbridge started (mode=${1:-plain}, guardian ${GUARD:-none} frozen)"
