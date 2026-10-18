#!/bin/sh
# ==============================================================================
# 零洞 Zero3 智能中控 (NX5, 1024x600) - Custom GUI Installer
# 参照 mopad_lite_custom_gui/install.sh 结构,适配 NX5 接管形态:
#   - 便携 curl 获取(设备 busybox wget 无 https)→ 多镜像下载 release 包
#   - 备份用户配置(/data/nx5_conf/intercom/*.json)
#   - 精确替换 /data/aciga_lvgl(按 exe 匹配杀进程,原厂 /system 冻结共存不动)
#   - 零重启热启动(keeper 保持接管;curl 持久化供后续 OTA 直连)
# 更新地址: 本仓库 snailll2/zero3-firmware
# ==============================================================================

TARGET_BIN="/data/aciga_lvgl"
CONF_DIR="/data/nx5_conf/intercom"
TAR_NAME="nx5gui_latest.tar.gz"
URL_LIST="
https://ghfast.top/https://raw.githubusercontent.com/snailll2/zero3-firmware/main/release/${TAR_NAME}
https://cdn.jsdelivr.net/gh/snailll2/zero3-firmware@main/release/${TAR_NAME}
https://raw.githubusercontent.com/snailll2/zero3-firmware/main/release/${TAR_NAME}
"

echo "========================================================"
echo "   零洞 Zero3 智能中控固件安装器 (NX5)"
echo "========================================================"

# ---------------------------------------------------------------- 1. HTTPS curl
CURL_EXEC=""
if [ -x /tmp/curl ]; then
    CURL_EXEC="/tmp/curl"
elif [ -x "$CONF_DIR/curl" ] || [ -x /data/curl ]; then
    [ -x "$CONF_DIR/curl" ] && CURL_EXEC="$CONF_DIR/curl" || CURL_EXEC="/data/curl"
elif command -v curl >/dev/null 2>&1; then
    CURL_EXEC="curl"
else
    echo "[*] 无 HTTPS 能力(busybox wget 不支持),经 HTTP 获取便携 curl..."
    wget -O /tmp/curl "http://master.dl.sourceforge.net/project/aqarahub/binutils/curl?viasf=1" 2>/dev/null || true
    chmod a+x /tmp/curl 2>/dev/null || true
    [ -x /tmp/curl ] && CURL_EXEC="/tmp/curl"
fi
if [ -z "$CURL_EXEC" ]; then
    echo "[-] 获取 curl 失败。手动执行:"
    echo "    wget -O /tmp/curl http://master.dl.sourceforge.net/project/aqarahub/binutils/curl?viasf=1 && chmod +x /tmp/curl"
    exit 1
fi
echo "[+] curl: $CURL_EXEC"

# ---------------------------------------------------------------- 2. /tmp 空间
AVAIL=$(df -m /tmp 2>/dev/null | awk '$NF=="/tmp"{print $4}')
case "$AVAIL" in ''|*[!0-9]*) AVAIL=16 ;; esac
if [ "$AVAIL" -lt 12 ]; then
    echo "[*] /tmp 剩余 ${AVAIL}M,清理残留..."
    rm -f /tmp/ota.img /tmp/ota.md5.actual /tmp/ota_ver.json /tmp/ota_flash.log 2>/dev/null
    AVAIL=$(df -m /tmp 2>/dev/null | awk '$NF=="/tmp"{print $4}')
fi
if [ -z "$AVAIL" ] || [ "$AVAIL" -lt 12 ]; then
    echo "[-] /tmp 空间不足(需 >=12M, 现 ${AVAIL}M),无法安全下载。"
    exit 1
fi
echo "[+] /tmp 可用 ${AVAIL}M"

# ---------------------------------------------------------------- 3. 备份用户配置
BACKUP_DIR="/data/nx5_conf_backup_$(date +%s)"
HAS_CFG=0
for f in "$CONF_DIR"/*.json; do
    [ -f "$f" ] && HAS_CFG=1 && break
done
if [ "$HAS_CFG" -eq 1 ]; then
    echo "[1/6] 备份用户配置 -> $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
    cp -f "$CONF_DIR"/*.json "$BACKUP_DIR/" 2>/dev/null || true
else
    echo "[1/6] 无既有配置,跳过备份"
fi

# ---------------------------------------------------------------- 4. 下载 release 包(先验包再动系统)
echo "[2/6] 下载最新 release 包..."
LOCAL_TAR="/tmp/$TAR_NAME"
DOWNLOAD_OK=0
for U in $URL_LIST; do
    echo "[*] 尝试源: $U"
    rm -f "$LOCAL_TAR"
    if $CURL_EXEC -s -k -L --connect-timeout 10 -m 300 -o "$LOCAL_TAR" "$U" && [ -s "$LOCAL_TAR" ]; then
        SZ=$(wc -c < "$LOCAL_TAR")
        if [ "$SZ" -gt 2000000 ] && tar -tzf "$LOCAL_TAR" >/dev/null 2>&1; then
            DOWNLOAD_OK=1
            echo "[+] 下载并校验成功 ($SZ bytes)"
            break
        fi
    fi
done
if [ "$DOWNLOAD_OK" -ne 1 ]; then
    echo "[-] 所有镜像均无法取得有效 release 包。"
    exit 1
fi

# ---------------------------------------------------------------- 5. 替换固件(精确 kill,原厂不动)
echo "[3/6] 停止现有 GUI(按 exe 精确匹配,原厂冻结共存不受影响)..."
for p in $(ls /proc 2>/dev/null | grep -E '^[0-9]+$'); do
    e=$(readlink /proc/$p/exe 2>/dev/null)
    [ "$e" = "$TARGET_BIN" ] && kill -9 $p 2>/dev/null
done
sleep 2

echo "[4/6] 替换固件二进制..."
tar -zxvf "$LOCAL_TAR" -C /data > /tmp/install_tar.log 2>&1
if [ ! -x /data/nx5gui ]; then
    echo "[-] 解包断言失败(nx5gui 缺失),中止(旧固件仍在)..."
    rm -f "$LOCAL_TAR"
    exit 1
fi
# 还原用户配置(安装包内不带配置,避免覆盖)
if [ -d "$BACKUP_DIR" ]; then
    echo "[*] 还原用户配置..."
    cp -f "$BACKUP_DIR"/*.json "$CONF_DIR/" 2>/dev/null || true
    rm -rf "$BACKUP_DIR"
fi
mv -f /data/nx5gui "$TARGET_BIN" && chmod +x "$TARGET_BIN" && sync
rm -f "$LOCAL_TAR"

# curl 持久化(后续 OTA 直连快速通道)
if [ -x /tmp/curl ] && [ ! -x "$CONF_DIR/curl" ]; then
    cp -f /tmp/curl "$CONF_DIR/curl" 2>/dev/null && chmod +x "$CONF_DIR/curl" 2>/dev/null
fi

# ---------------------------------------------------------------- 6. 热启动 + 验证
echo "[5/6] 热启动 GUI..."
( cd /data && nohup /data/aciga_lvgl >/data/nx5gui.out 2>&1 & )
echo "[6/6] 验证..."
sleep 5
GUI_OK=0
for p in $(ls /proc 2>/dev/null | grep -E '^[0-9]+$'); do
    e=$(readlink /proc/$p/exe 2>/dev/null)
    [ "$e" = "$TARGET_BIN" ] && GUI_OK=1 && break
done

DEV_IP=$(ip -4 addr show eth0 2>/dev/null | grep -o 'inet [0-9.]*' | cut -d' ' -f2)
[ -z "$DEV_IP" ] && DEV_IP=$(ip -4 addr show wlan0 2>/dev/null | grep -o 'inet [0-9.]*' | cut -d' ' -f2)
[ -z "$DEV_IP" ] && DEV_IP=$(ifconfig eth0 2>/dev/null | awk '/inet addr/{print $2}' | cut -d: -f2)
[ -z "$DEV_IP" ] && DEV_IP="<面板IP>"

if [ "$GUI_OK" -eq 1 ]; then
    echo "========================================================"
    echo " [SUCCESS] 零洞 Zero3 固件安装成功并已运行!"
    echo " -> 屏幕已接管(原厂冻结共存,重启自动恢复)"
    echo " -> Web 控制台: http://${DEV_IP}:8080/"
    echo " -> 授权: 设置页查看机器码/激活状态"
    echo "========================================================"
else
    echo "[-] GUI 未能立即拉起,查看 /data/nx5gui.out 尾部:"
    tail -n 8 /data/nx5gui.out 2>/dev/null
    echo "[*] /data/bin keeper 会自动重试拉起;5 秒后复查。"
    sleep 5
    for p in $(ls /proc 2>/dev/null | grep -E '^[0-9]+$'); do
        e=$(readlink /proc/$p/exe 2>/dev/null)
        [ "$e" = "$TARGET_BIN" ] && echo "[+] keeper 已拉起,安装完成。" && exit 0
    done
    exit 1
fi
