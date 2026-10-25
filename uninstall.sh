#!/bin/sh
# ==============================================================================
# 零洞 Zero3 智能中控 (NX5) - 卸载/清理脚本
#
# 用法(设备上): sh uninstall.sh           # 卸载 GUI+开机链,保留用户配置/主题/授权,重启回出厂
#               PURGE=1 sh uninstall.sh  # 彻底清除:连同 nx5_conf(含HA配置/授权!)、主题、备份一起删
#               REBOOT=0 sh uninstall.sh # 只清理不重启(面板会立即回原厂画面)
#
# 安全设计(按 2026-10-23 定案的硬件批次差异):
#   1. 先杀我们的进程、再 SIGCONT 解冻原厂 —— 顺序不能反:我们的 GUI 内置 keeper 每 5s
#      补冻结原厂,"先解冻后杀"存在竞态(实测 163 曾被回冻数分钟)。外部硬看门狗容忍
#      分钟级断喂,先杀后解冻的 ~2s 空窗无害;解冻后复查状态,仍 T 则再补 CONT。
#   2. 只按 exe 路径精确匹配杀进程(含 "(deleted)" 变体),绝不动 /system 原厂;
#      若解冻后原厂未在运行,直接进入重启(唯一安全出路)。
#   3. 默认保留 /data/nx5_conf(用户配置+授权+便携curl,便于重装)与 /data/theme;
#      PURGE=1 才删,删前二次提示。
#   4. 重装:按 README 跑 install.sh 即可(或 /data/nx5_conf/intercom/curl 直连)。
# ==============================================================================
echo "========================================================"
echo "   零洞 Zero3 智能中控固件 - 卸载器 (NX5)"
echo "========================================================"

# ---------------------------------------------------------------- 1. 停我们的进程(先杀,消除 keeper 回冻竞态)
echo "[1/5] 停止 nx5gui 及看护/观察进程..."
for p in $(ls /proc 2>/dev/null | grep -E '^[0-9]+$'); do
    e=$(readlink /proc/$p/exe 2>/dev/null)
    case "$e" in
        "/data/nx5gui"|"/data/nx5gui (deleted)"|\
        "/data/aciga_lvgl"|"/data/aciga_lvgl (deleted)") kill -9 $p 2>/dev/null ;;
    esac
done
for p in $(ps | grep -E 'start_app|dtw\.sh|pinw' | grep -v grep | awk '{print $1}'); do
    kill -9 $p 2>/dev/null
done
rm -f /tmp/nx5gui.lock
sleep 2

# ---------------------------------------------------------------- 2. 解冻原厂(喂狗接管)
THAWED=""
for p in $(ps | grep aciga_lvgl | grep -v grep | awk '{print $1}'); do
    case "$(readlink /proc/$p/exe 2>/dev/null)" in
        /system/*) kill -CONT $p 2>/dev/null && THAWED="$THAWED $p" ;;
    esac
done
if [ -n "$THAWED" ]; then
    sleep 2
    # 复查:仍被冻结(T)则再补 CONT(防残留 keeper 的最后一针)
    for p in $THAWED; do
        st=$(awk '{print $3}' /proc/$p/stat 2>/dev/null)
        [ "$st" = "T" ] && kill -CONT $p 2>/dev/null
    done
    echo "[2/5] 原厂 GUI 已解冻($THAWED),恢复出厂显示并接管外部看门狗喂狗"
else
    echo "[2/5] ⚠ 未发现运行中的原厂 GUI —— 直启模式(原厂本就未跑)或已被冻结方死亡;"
    echo "      外部看门狗无人喂,将在清理后立即重启(重启后原厂自动拉起);不重启必遭硬复位。"
fi

# ---------------------------------------------------------------- 3. 摘除开机链
echo "[3/5] 摘除开机自启链(Sinit 钩子不再拉起)..."
rm -f /data/bin/start_app.sh /data/bin/start_app.sh.bak \
      /data/bin/data_app.sh   /data/bin/nx5_env.sh \
      /data/bin/wpa_conf_backup.conf \
      /data/start_app.sh      /data/data_app.sh /data/install.sh 2>/dev/null
rmdir /data/bin 2>/dev/null || true   # 目录空则一并移除;有其它文件则保留
# 直启分叉文件(2026-10-26 v9 起):存在则原厂走产测分支、原厂 GUI 永不启动——必须删
if [ -f /data/productionTest ] || [ -d /data/nand-1 ]; then
    rm -f /data/productionTest
    rm -rf /data/nand-1
    rm -f /data/shim_lvgl /data/shim.log /data/dbt_arm.sh /data/dbt_guard.log 2>/dev/null
    umount /system/user/bin/aciga_lvgl 2>/dev/null
    echo "      已移除直启分叉文件(productionTest/nand-1),下次开机恢复原厂启动链"
fi

# ---------------------------------------------------------------- 4. 清理文件
echo "[4/5] 清理固件与调试残留..."
rm -f /data/nx5gui /data/aciga_lvgl /data/aciga_lvgl.removed 2>/dev/null
rm -f /data/nx5gui_live.log /data/nx5gui.out /data/nx5gui_crash.log 2>/dev/null
rm -f /data/fg.log /data/key_evt.log /data/dtail.log /data/pinw4.log \
      /data/dtw.sh /data/pinw4.sh /data/fg.sh /data/fg2.sh \
      /data/keeper_off /data/nx5_render_pause /data/uplog 2>/dev/null
rm -f /tmp/ota.img /tmp/ota.tar /tmp/ota_ver.json /tmp/inst_ref_ver.json \
      /tmp/nx5gui_latest.tar.gz 2>/dev/null
rm -rf /tmp/www/bg 2>/dev/null

if [ "$PURGE" = "1" ]; then
    echo "      PURGE=1:彻底清除用户配置/授权/HA 绑定/主题/备份(不可恢复!)..."
    rm -rf /data/nx5_conf /data/nx5_conf_backup_* /data/theme 2>/dev/null
else
    echo "      保留:/data/nx5_conf(配置+授权+curl)、/data/theme(主题)"
    echo "           /data/nx5_conf_backup_*(安装备份)——PURGE=1 可一并清除"
fi
sync

# ---------------------------------------------------------------- 5. 收尾
if [ -z "$THAWED" ]; then
    echo "[5/5] 原厂未在运行 → 立即重启恢复出厂..."
    sleep 2; sync; reboot; exit 0
fi
if [ "$REBOOT" = "0" ]; then
    echo "[5/5] 完成(未重启,面板应已显示原厂画面)。"
else
    echo "[5/5] 3 秒后重启彻底回出厂(REBOOT=0 可不重启)..."
    sleep 3; reboot
fi
