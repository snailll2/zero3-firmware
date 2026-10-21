#!/bin/sh
# 2026-10-21 复位循环根因修复:guardian/ult_dg 对 aciga_lvgl 的 killall 重启战会波及本 GUI 并升级为整机复位
killall -9 aciga_guardian aciga_ult_dg 2>/dev/null
# /data/bin/start_app.sh — NX5 开机接管脚本(Sinit 原厂钩子自动执行)
#
# 架构(2026-10-07 实测确定):面板的 VO 管线/背光由原厂 aciga_lvgl 初始化并持有,
# 内核在它的 /dev/vo 关闭时会自动给面板下电(kill 会触发 lcm_mipi_PowerOff)。
# 因此不能杀原厂,只能:
#   1. 等原厂 GUI 起来并把面板点亮(开机后亮屏可维持 2 分钟以上)
#   2. SIGSTOP 冻结它(fd 全保留,VO 持续上电,图层继续扫描)
#   3. 我们的 GUI(/data/aciga_lvgl,借用同名)往 /dev/fb0 画,面板即显示我们的 UI
#
# 看护:我们的 GUI 挂了(崩溃/主循环卡死自杀)→ 自动重启我们的 GUI,最多 3 次;
# 3 次仍挂 → 解冻原厂恢复出厂显示并退出(guardian 接手)。
# 彻底回退出厂:mv /data/bin /data/bin.off && reboot

(
    # ---- 等原厂 aciga_lvgl 出现(最多 120s) ----
    i=0
    VP=""
    while [ $i -lt 24 ]; do
        VP=""
        for p in $(ps | grep aciga_lvgl | grep -v grep | awk '{print $1}'); do
            case "$(readlink /proc/$p/exe)" in /system/*) VP="$VP $p";; esac
        done
        [ -n "$VP" ] && break
        sleep 5
        i=$((i+1))
    done
    # ---- 等面板完全点亮(原厂完成初始化+背光上电) ----
    sleep 30
    # ---- 冻结原厂(SIGSTOP;绝不能 kill -9,会触发内核面板下电) ----
    for p in $VP; do kill -STOP $p 2>/dev/null; done

    # ---- 启动我们的 GUI + 崩溃自动重启(≤3 次,最终回原厂) ----
    TRIES=0
    while [ $TRIES -lt 3 ]; do
        cd /data
        export PATH=$PATH:/system/bin:/system/user/bin
        export LD_LIBRARY_PATH=/system/user/lib:/system/lib
        NX5TS_DBG=1 nohup ./aciga_lvgl > /tmp/nx5gui.log 2>&1 &
        sleep 5
        # 等我们的进程退出(最多等 6 小时;进程活着就轮询)
        STABLE=0
        k=0
        while [ $k -lt 4320 ]; do
            ALIVE=""
            for p in $(ps | grep aciga_lvgl | grep -v grep | awk '{print $1}'); do
                case "$(readlink /proc/$p/exe)" in /data/*) ALIVE=1;; esac
            done
            [ -z "$ALIVE" ] && break
            sleep 5
            k=$((k+1))
        done
        # 我们挂了:先解冻原厂 15s(恢复出厂显示/背光,顺带确认原厂活着),再重新冻结
        for p in $(ps | grep aciga_lvgl | grep -v grep | awk '{print $1}'); do
            kill -CONT $p 2>/dev/null
        done
        sleep 15
        for p in $(ps | grep aciga_lvgl | grep -v grep | awk '{print $1}'); do
            case "$(readlink /proc/$p/exe)" in /system/*) kill -STOP $p 2>/dev/null;; esac
        done
        TRIES=$((TRIES+1))
    done
    # ---- 3 次都失败:留在原厂界面 ----
    for p in $(ps | grep aciga_lvgl | grep -v grep | awk '{print $1}'); do
        kill -CONT $p 2>/dev/null
    done
    exit 0
) &
exit 0
