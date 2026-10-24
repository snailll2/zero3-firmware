#!/bin/sh
# start_app.sh — NX5 开机接管脚本(v6,2026-10-23 定稿,1.0.131 随发)
#
# 与 v5 及更早的关键差异(全部经 163 批次实测):
#   1. 二进制定名 /data/nx5gui,不再借用 aciga_lvgl 名字——原厂守护链
#      (guardian)的 killall -9 aciga_lvgl 永远打不到我们。
#   2. 不做"先冻结再启动":预冻结会让 GUI 在主题加载阶段秒退(163 实测);
#      冻结改由 GUI 进程内 vendor_keeper 完成(启动后 ~5s,按 exe 精确匹配
#      /system/user/bin/aciga_lvgl)。
#   3. 批次环境变量统一放 /data/bin/nx5_env.sh(install.sh 按硬件批次生成):
#      NX5_GPIO83FEED=1  新批次(163 型):GPIO83 外部硬看门狗喂狗(sysfs 500ms 翻转)
#      NX5_NOWDT=1       新批次:不开 /dev/watchdog(该批次武装后行为未验证)
#      旧批次(149 型)两者皆空:GUI 正常开狗喂狗(崩溃→整机复位→原厂自恢复)。
#   4. 日志持久化 /data/nx5gui_live.log(追加;旧版 /tmp 重启即丢死亡现场)。
#
# 流程:Sinit 钩子(data_app.sh 存在即执行本脚本)→ 等原厂 GUI 出现并点亮面板
#   → 启动 nx5gui(冻结由 GUI 自己做)→ 看护:死了先解冻原厂 15s 再重冻重试,
#   ≤3 次;3 败后解冻原厂留在出厂界面退出(guardian 接手)。
# 彻底回退出厂:mv /data/bin /data/bin.off && reboot
(
    # ---- 批次环境(存在则加载) ----
    [ -f /data/bin/nx5_env.sh ] && . /data/bin/nx5_env.sh

    # ---- 等原厂 aciga_lvgl 出现(最多 120s;guardian 是它的正统拉起者) ----
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

    # ---- 等面板点亮(背光 PWM duty>0;最多 40s 再兜底 5s) ----
    j=0
    while [ $j -lt 40 ]; do
        D=$(cat /sys/class/pwm/pwmchip0/pwm0/duty_cycle 2>/dev/null)
        case "$D" in ''|0) sleep 1; j=$((j+1));; *) break;; esac
    done
    sleep 5

    # ---- 启动我们的 GUI + 崩溃自动重启(≤3 次,最终回原厂) ----
    TRIES=0
    while [ $TRIES -lt 3 ]; do
        cd /data
        export PATH=$PATH:/system/bin:/system/user/bin
        export LD_LIBRARY_PATH=/system/user/lib:/system/lib
        NX5TS_DBG=1 nohup ./nx5gui >> /data/nx5gui_live.log 2>&1 &
        # 蓝牙代理(2026-10-24):面板 mesh 空,停 mgw_bt 换 btproxy(冻结 guardian 由脚本处理)
        [ -x /data/btproxy.sh ] && [ -f /data/btproxy.conf ] && (sleep 8; /data/btproxy.sh >/dev/null 2>&1 &)
        sleep 5
        STABLE=0
        k=0
        while [ $k -lt 4320 ]; do
            ALIVE=""
            for p in $(ps | grep nx5gui | grep -v grep | awk '{print $1}'); do
                case "$(readlink /proc/$p/exe 2>/dev/null)" in /data/*) ALIVE=1;; esac
            done
            [ -z "$ALIVE" ] && break
            sleep 5
            k=$((k+1))
        done
        # 我们挂了:先解冻原厂 15s(恢复出厂显示/确认原厂活着),再重冻重试
        for p in $(ps | grep aciga_lvgl | grep -v grep | awk '{print $1}'); do
            kill -CONT $p 2>/dev/null
        done
        sleep 15
        for p in $(ps | grep aciga_lvgl | grep -v grep | awk '{print $1}'); do
            case "$(readlink /proc/$p/exe 2>/dev/null)" in /system/*) kill -STOP $p 2>/dev/null;; esac
        done
        TRIES=$((TRIES+1))
    done
    # ---- 3 次都失败:解冻原厂留在出厂界面 ----
    for p in $(ps | grep aciga_lvgl | grep -v grep | awk '{print $1}'); do
        kill -CONT $p 2>/dev/null
    done
) &
exit 0
