#!/bin/sh
# start_app.sh — NX5 开机接管脚本(v9:产测分叉直启,2026-10-26)
#
# ★v9 架构(用户发现的官方分叉点):/data/productionTest + /data/nand-1 存在时,
#   原厂 start_app.sh 走产测分支——lingdong_app.sh 整条链不跑:
#   linkdora_broker/devinfo/ult_dg/guardian 全不启动 → guardian 不存在 →
#   原厂 GUI(aciga_lvgl,由 guardian 复活)永不出现。文件在 /data 天然跨重启。
#   我们移植必要服务(broker+devinfo=WiFi/背光/gl_ioctrl),GUI 走 fymedia 直启。
#   回退 = rm /data/productionTest /data/nand-1 && reboot(回 v8 接管态)。
(
    # ---- 批次环境 ----
    [ -f /data/bin/nx5_env.sh ] && . /data/bin/nx5_env.sh

    if [ -n "$NX5_DIRECT_BOOT" ]; then
        # ============ 产测分叉直启(v9) ============
        echo "[start_app] direct-boot v9: production-fork mode"

        # 移植 lingdong_app.sh 的服务链(guardian 故意不启——它会复活原厂 GUI)
        export PATH=$PATH:/system/user/bin:/system/bin
        export LD_LIBRARY_PATH=/system/user/lib:/system/lib
        cd /system/user/bin
        if [ -x ./linkdora_broker ] && ! pidof linkdora_broker >/dev/null; then
            chmod 777 linkdora_broker
            nohup ./linkdora_broker >/dev/null 2>&1 &
            echo "[start_app] linkdora_broker started"
        fi
        sleep 1
        if [ -x ./aciga_devinfo ] && ! pidof aciga_devinfo >/dev/null; then
            chmod 777 aciga_devinfo
            nohup ./aciga_devinfo >/dev/null 2>&1 &
            echo "[start_app] aciga_devinfo started(WiFi+背光+gl_ioctrl)"
        fi
        # WiFi 凭据保护(2026-10-26):devinfo 开机会重建 wpa_supplicant.config
        # (rm+cp useretc 模板)→已存 WiFi 丢失。启它前备份,起来后若被清则回写+重连。
        WPACONF=/data/etc/wpa_supplicant.config
        WPABAK=/data/bin/wpa_conf_backup.conf
        [ -f "$WPACONF" ] && grep -q "network={" "$WPACONF" && cp -f "$WPACONF" "$WPABAK"

        sleep 6   # devinfo 订阅 /devInfo 主题需要时间;GUI 过早发布初始亮度会被丢(白斑界面根因)

        # devinfo 若清了凭据:回写并 reconfigure
        if [ -f "$WPABAK" ] && ! grep -q "network={" "$WPACONF" 2>/dev/null; then
            cp -f "$WPABAK" "$WPACONF"
            wpa_cli -i wlan0 reconfigure >/dev/null 2>&1 &
            echo "[start_app] wifi credentials restored"
        fi

        # GUI 直启(fymedia 全协议在 nx5gui 进程内)+ 常驻看护
        # 看护职责:GUI 死亡 → 立即把 PWM duty 从 ~0 拉回安全档(白斑=duty≈0 而 LCM
        # 仍亮时灯珠漏电不均,硬件特性;进程死后内核 fyfb 释放会归零 duty)→ 重启 GUI
        PWM="$(ls /sys/class/pwm/pwmchip*/pwm0/duty_cycle 2>/dev/null | head -1)"
        # 白斑防 = 两层:①emergency_bl(on_crash 内恢复 duty,信号可救的死亡)
        # ②下方 keeper 死亡检测恢复 duty(kill -9/OOM 等不可自救死亡,窗口 ≤5s)。
        # fb0 哨兵(第三层)已否决:短测通过但真实运行复现白斑+引擎损坏。
        # 日志轮转:live.log >5MB 时留尾 1MB(2026-10-26 95MB 日志塞爆 157MB /data → ENOSPC 部署截断)
        if [ -f /data/nx5gui_live.log ] && [ "$(wc -c < /data/nx5gui_live.log)" -gt 5000000 ]; then
            tail -c 1000000 /data/nx5gui_live.log > /data/nx5gui_live.tail && mv -f /data/nx5gui_live.tail /data/nx5gui_live.log
        fi
        # 堆检测(2026-10-26):163 反复静默死亡=主线程 r7(帧指针)被踩,
        # 内核 Oops(do_sys_open 垃圾指针)后喂狗断→硬件复位。MALLOC_CHECK
        # 让堆越界当场 abort 留日志指认;PERTURB 用垃圾填充 freed 块放大复现。
        export MALLOC_CHECK_=3
        export MALLOC_PERTURB_=165
        # fb0 哨兵方案 2026-10-27 实测否决:kill -9 短测 duty 恒定,但真实运行
        # 后白斑复现+显示引擎损坏(GUI 重启无法恢复)——多开 fyfb 的损坏是
        # 时序性/累积性的,短测无法暴露。白斑兜底=守护死亡检测恢复 duty(≤5s)。
        TRIES=0
        while [ $TRIES -lt 3 ]; do
            cd /data
            NX5TS_DBG=1 nohup ./nx5gui >> /data/nx5gui_live.log 2>&1 &
            # 蓝牙代理:开关标志 nx5_conf/bt_on
            [ -x /data/btproxy.sh ] && [ -f /data/nx5_conf/intercom/bt_on ] && (sleep 8; /data/btproxy.sh >/dev/null 2>&1 &)
            # Zigbee 网关
            [ -x /data/zbbridge.sh ] && [ -f /data/nx5_conf/intercom/zb_on ] && (sleep 20; setsid sh /data/zbbridge.sh reset >/data/zb_reset.log 2>&1 &)
            # 常驻看护:活着就一直等;死了→恢复背光→跳出重试
            while :; do
        # 检测间隔 0.3s(复刻原厂 guardian 接力):白斑=duty≈0 而 LCM 亮,
        # 守护 0.3s 内拉回 20%,可见白斑 ≤0.3s(此后为冻结帧非白斑);
        # fb0 哨兵方案已实测否决(状态污染),速度接力是正路
        if command -v usleep >/dev/null 2>&1; then KEP_TICK='usleep 300000'; else KEP_TICK='sleep 1'; fi
            $KEP_TICK
                OK=""
                for p in $(ps | grep nx5gui | grep -v grep | awk '{print $1}'); do
                    case "$(readlink /proc/$p/exe 2>/dev/null)" in /data/*) OK=1;; esac
                done
                [ -n "$OK" ] && continue
                [ -f /data/nx5blpub ] && cp -f /data/nx5blpub /data/bin/nx5blpub && chmod +x /data/bin/nx5blpub && rm -f /data/nx5blpub
        [ -x /data/bin/nx5blpub ] && /data/bin/nx5blpub 50 >/dev/null 2>&1   # LINKDORA 直发(163 新批次 sysfs 不接背光)
                [ -n "$PWM" ] && [ -f "$PWM" ] && echo 200000 > "$PWM" 2>/dev/null
                echo "[start_app] nx5gui died, backlight restored(20%), restarting"
                break
            done
            TRIES=$((TRIES+1))
        done
        echo "[start_app] direct boot keeper exited (gui tries=$TRIES)"
        exit 0
    fi

    # ============ 常规接管模式(v6 流程) ============
    # ---- 直启:垫片 bind mount(旧方案保留但不再默认) ----
    if [ -n "$NX5_KILL_TAKEOVER" ] || [ -f /data/productionTest ]; then :; fi

    # ---- 等原厂 aciga_lvgl 出现(最多 120s) ----
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

    # ---- 等面板点亮 ----
    j=0
    while [ $j -lt 40 ]; do
        D=$(cat /sys/class/pwm/pwmchip0/pwm0/duty_cycle 2>/dev/null)
        case "$D" in ''|0) sleep 1; j=$((j+1));; *) break;; esac
    done
    sleep 5

    # ---- kill-接管(原厂点亮使命完成,杀掉;GUI 重开 fb0 复点) ----
    if [ -n "$NX5_KILL_TAKEOVER" ]; then
        for p in $(ps | grep aciga_lvgl | grep -v grep | awk '{print $1}'); do
            case "$(readlink /proc/$p/exe 2>/dev/null)" in /system/*) kill -9 $p 2>/dev/null; echo "[start_app] kill-takeover: vendor $p killed";; esac
        done
        sleep 2
    fi

    # ---- 启动我们的 GUI + 崩溃自动重启(≤3 次) ----
    TRIES=0
    while [ $TRIES -lt 3 ]; do
        cd /data
        export PATH=$PATH:/system/bin:/system/user/bin
        export LD_LIBRARY_PATH=/system/user/lib:/system/lib
        NX5TS_DBG=1 nohup ./nx5gui >> /data/nx5gui_live.log 2>&1 &
        [ -x /data/btproxy.sh ] && [ -f /data/nx5_conf/intercom/bt_on ] && (sleep 8; /data/btproxy.sh >/dev/null 2>&1 &)
        [ -x /data/zbbridge.sh ] && [ -f /data/nx5_conf/intercom/zb_on ] && (sleep 20; setsid sh /data/zbbridge.sh reset >/data/zb_reset.log 2>&1 &)
        sleep 5
        STABLE=0
        k=0
        while [ $k -lt 4320 ]; do
            ALIVE=""
            for p in $(ps | grep nx5gui | grep -v grep | awk '{print $1}'); do
                case "$(readlink /proc/$p/exe 2>/dev/null)" in /data/*) ALIVE=1;; esac
            done
            [ -z "$ALIVE" ] && break
            if [ -n "$NX5_KILL_TAKEOVER" ] && [ $((k % 12)) -eq 0 ]; then
                for p in $(ps | grep aciga_lvgl | grep -v grep | awk '{print $1}'); do
                    case "$(readlink /proc/$p/exe 2>/dev/null)" in /system/*) kill -9 $p 2>/dev/null;; esac
                done
                grep -q "shim_lvgl" /proc/mounts 2>/dev/null || \
                    mount --bind /data/shim_lvgl /system/user/bin/aciga_lvgl 2>/dev/null
            fi
            sleep 5
            k=$((k+1))
        done
        if [ -n "$NX5_DIRECT_BOOT" ]; then
            TRIES=$((TRIES+1)); continue
        fi
        for p in $(ps | grep aciga_lvgl | grep -v grep | awk '{print $1}'); do
            kill -CONT $p 2>/dev/null
        done
        sleep 15
        for p in $(ps | grep aciga_lvgl | grep -v grep | awk '{print $1}'); do
            case "$(readlink /proc/$p/exe 2>/dev/null)" in /system/*) kill -STOP $p 2>/dev/null;; esac
        done
        TRIES=$((TRIES+1))
    done
    for p in $(ps | grep aciga_lvgl | grep -v grep | awk '{print $1}'); do
        kill -CONT $p 2>/dev/null
    done
) &
exit 0
