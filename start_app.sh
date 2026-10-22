#!/bin/sh
# z3 接管脚本 v4(2026-10-22):
#  ① guardian/ult_dg 永久压制(每 10s;旧 40s 窗口有竞态——lingdong 偶尔晚起,guardian 漏网 → 83s 复位战)
#  ② 代管 aciga_broker(guardian 死后无人拉起;保持原厂生态完整)
#  ③ devinfo 保持自然(持有 gl_ioctrl 的正统持有者)
(
  while true; do
    killall -9 aciga_guardian aciga_ult_dg 2>/dev/null
    pidof aciga_broker >/dev/null 2>&1 || (cd /system/user/bin && setsid ./aciga_broker >/dev/null 2>&1 &)
    sleep 10
  done
) &
(
  # 等原厂 GUI(guardian 死前/其它路径拉起;最多 120s)
  i=0
  while [ $i -lt 24 ]; do
    VP=""
    for p in $(ps | grep aciga_lvgl | grep -v grep | awk '{print $1}'); do
      case "$(readlink /proc/$p/exe 2>/dev/null)" in /system/*) VP="$VP $p";; esac
    done
    [ -n "$VP" ] && break
    sleep 5
    i=$((i+1))
  done
  j=0
  while [ $j -lt 40 ]; do
    D=$(cat /sys/class/pwm/pwmchip0/pwm0/duty_cycle 2>/dev/null)
    case "$D" in ''|0) sleep 1; j=$((j+1));; *) break;; esac
  done
  sleep 5
  TRIES=0
  while [ $TRIES -lt 3 ]; do
    cd /data
    export PATH=$PATH:/system/bin:/system/user/bin
    export LD_LIBRARY_PATH=/system/user/lib:/system/lib
    nohup ./aciga_lvgl > /tmp/nx5gui.log 2>&1 &
    sleep 5
    k=0
    while [ $k -lt 4320 ]; do
      ALIVE=""
      for p in $(ps | grep aciga_lvgl | grep -v grep | awk '{print $1}'); do
        case "$(readlink /proc/$p/exe 2>/dev/null)" in /data/*) ALIVE=1;; esac
      done
      [ -z "$ALIVE" ] && break
      sleep 5
      k=$((k+1))
    done
    for p in $(ps | grep aciga_lvgl | grep -v grep | awk '{print $1}'); do
      kill -CONT $p 2>/dev/null
    done
    sleep 15
    for p in $(ps | grep aciga_lvgl | grep -v grep | awk '{print $1}'); do
      case "$(readlink /proc/$p/exe 2>/dev/null)" in /system/*) kill -STOP $p 2>/dev/null;; esac
    done
    TRIES=$((TRIES+1))
  done
) &
exit 0
