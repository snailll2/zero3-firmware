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

TARGET_BIN="/data/nx5gui"
LEGACY_BIN="/data/aciga_lvgl"   # ≤1.0.130 借用过原厂名;升级时须清掉避免双实例锁冲突
CONF_DIR="/data/nx5_conf/intercom"
mkdir -p "$CONF_DIR"
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
for p in "$CONF_DIR/curl" /data/curl /tmp/curl /usr/bin/curl; do
    [ -x "$p" ] && CURL_EXEC="$p" && break
done
[ -n "$CURL_EXEC" ] || { command -v curl >/dev/null 2>&1 && CURL_EXEC="curl"; }
if [ -z "$CURL_EXEC" ]; then
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
echo "[2/6] 检查 release 包..."
LOCAL_TAR="/tmp/$TAR_NAME"
DOWNLOAD_OK=0
# 离线口:PC 下载 tar.gz 推到设备 /tmp/$TAR_NAME 后再跑本脚本,直接跳过下载
if [ -s "$LOCAL_TAR" ] && tar -tzf "$LOCAL_TAR" >/dev/null 2>&1; then
    SZ=$(wc -c < "$LOCAL_TAR")
    if [ "$SZ" -gt 2000000 ]; then
        DOWNLOAD_OK=1
        echo "[+] 使用已存在的 /tmp/$TAR_NAME ($SZ bytes,离线模式)"
    fi
fi
[ "$DOWNLOAD_OK" -eq 1 ] || for U in $URL_LIST; do
    echo "[*] 尝试源: $U"
    rm -f "$LOCAL_TAR"
    if $CURL_EXEC -skfL --connect-timeout 10 -m 300 -o "$LOCAL_TAR" "$U" && [ -s "$LOCAL_TAR" ]; then
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

# ------------------------------------------------- 4.5 防镜像缓存旧包(2026-10-22 实测坑)
# ghfast/jsdelivr 会把 release 资产缓存数小时,曾把 1.0.118 旧包当 latest 发给设备。
# 解包读 tar 内 version.json,与 raw 源 version.json 比对;旧包一律中止(离线口可 FORCE=1 跳过)。
if [ "$DOWNLOAD_OK" -eq 1 ] && [ -z "$FORCE" ]; then
    "$CURL_EXEC" -skfL -m 10 "https://raw.githubusercontent.com/snailll2/zero3-firmware/main/release/version.json" -o /tmp/inst_ref_ver.json 2>/dev/null || true
    REF_VER=$(grep -o '"version"[^,]*' /tmp/inst_ref_ver.json 2>/dev/null | head -1 | cut -d'"' -f4)
    REF_SIZE=$(grep -o '"size"[^,]*' /tmp/inst_ref_ver.json 2>/dev/null | head -1 | grep -o '[0-9]*')
    TAR_SIZE_CK=$SZ
    echo "[*] 包版本: $TAR_VER / 官方最新: ${REF_VER:-未知}"
    if [ -n "$REF_SIZE" ] && [ -n "$TAR_SIZE_CK" ] && [ "$TAR_SIZE_CK" != "$REF_SIZE" ]; then
        echo "[-] 镜像缓存了旧包(大小 $TAR_SIZE_CK ≠ 官方 $REF_SIZE),已中止以防降级。"
        echo "    请稍后重试(缓存约 5-10 分钟过期),或 FORCE=1 强制安装 / 离线模式。"
        exit 1
    fi
fi

# ---------------------------------------------------------------- 3.7 批次检测 → 生成 nx5_env.sh
# 硬件批次判据:/system/ko/ioctrl.ko 的 md5(2026-10-23 逆向定案,两批驱动仅 PWM 量程差):
#   432548a3… = 新批次(163 型,固件 4.4.1):板上有外部硬看门狗(GPIO83 喂狗线),
#               原厂 GUI 被冻结后必须由我们喂 → NX5_GPIO83FEED=1;
#               /dev/watchdog 武装后行为未单独验证 → NX5_NOWDT=1(暂不开软件狗)。
#   ae647381…(及其它)= 旧批次(149 型,固件 2.3.2):无外部看门狗电路,
#               GUI 正常开狗喂狗(崩溃→整机复位→原厂自恢复语义保留)。
IO_MD5=$(md5sum /system/ko/ioctrl.ko 2>/dev/null | cut -d' ' -f1)
ENV_FILE="/data/bin/nx5_env.sh"
mkdir -p /data/bin
case "$IO_MD5" in
    432548a3*)
        printf '# 新批次(163 型):外部硬看门狗 GPIO83 喂狗 + 暂不开软件狗 + LINKDORA 背光(install 自动生成)\nexport NX5_GPIO83FEED=1\nexport NX5_NOWDT=1\nexport NX5_BL_LINKDORA=1\n' > "$ENV_FILE"
        BATCH="新批次(外部看门狗)"
        ;;
    *)
        printf '# 旧批次(149 型):无外部看门狗,GUI 自行开狗喂狗(install 自动生成)\n' > "$ENV_FILE"
        BATCH="旧批次(软件喂狗)"
        ;;
esac
chmod +x "$ENV_FILE" 2>/dev/null
echo "[*] 批次判定: ioctrl.ko=$IO_MD5 → $BATCH → $ENV_FILE"

# ---------------------------------------------------------------- 5. 替换固件(精确 kill,原厂不动)
# ★2026-10-23 顺序修正(229 实测踩坑):旧批次(149 型)老 GUI 持软件看门狗,
# 旧顺序"先 kill → 再解包(3.6MB 数秒)→ 才热启动",kill 到新 GUI 接管喂狗的
# 空窗超看门狗阈值 → 整机复位,安装中途夭折(/tmp 全清)。新顺序:先完成解包/
# 校验/批次 env 等全部慢操作,最后一条命令链内 kill→mv→热启动(空窗 <1s)。
echo "[3/6] 预解包(不动运行中的 GUI)..."
tar -zxvf "$LOCAL_TAR" -C /data > /tmp/install_tar.log 2>&1
if [ ! -f /data/nx5gui ]; then
    echo "[-] 解包断言失败(nx5gui 缺失),中止(旧固件仍在)..."
    rm -f "$LOCAL_TAR"
    exit 1
fi
chmod +x /data/nx5gui
sync
# 还原用户配置(安装包内不带配置,避免覆盖)
if [ -d "$BACKUP_DIR" ]; then
    echo "[*] 还原用户配置..."
    cp -f "$BACKUP_DIR"/*.json "$CONF_DIR/" 2>/dev/null || true
    rm -rf "$BACKUP_DIR"
fi
# 接管脚本准备(落位 /data/bin 在 kill 之后同一链内执行,见下)
rm -f "$LOCAL_TAR"

echo "[3.6/6] 换血(亚秒空窗:kill→mv→落位→热启动)..."
for p in $(ps | grep start_app | grep -v grep | awk '{print $1}'); do
    kill -9 $p 2>/dev/null
done
for p in $(ls /proc 2>/dev/null | grep -E '^[0-9]+$'); do
    e=$(readlink /proc/$p/exe 2>/dev/null)
    case "$e" in
        "$TARGET_BIN"|"$TARGET_BIN (deleted)"|"$LEGACY_BIN"|"$LEGACY_BIN (deleted)") kill -9 $p 2>/dev/null ;;
    esac
done
# 清理 ≤1.0.130 的借用名旧二进制(防双实例 flock 冲突),留档 .removed
[ -f "$LEGACY_BIN" ] && mv -f "$LEGACY_BIN" "${LEGACY_BIN}.removed" 2>/dev/null
# 接管脚本落位(幂等;已有 start_app.sh.bak 时不覆盖用户备份)
[ -f /data/bin/start_app.sh ] && cp -f /data/bin/start_app.sh /data/bin/start_app.sh.bak 2>/dev/null
if [ -f /data/start_app.sh ]; then
    cp -f /data/start_app.sh /data/bin/start_app.sh && chmod +x /data/bin/start_app.sh
    [ -f /data/bin/data_app.sh ] || { printf '# dummy: Sinit 检查 data_app.sh 存在但运行 start_app.sh\n' > /data/bin/data_app.sh; chmod +x /data/bin/data_app.sh; }
    rm -f /data/start_app.sh
fi
# 立即热启动(最小化喂狗空窗)
(
    cd /data
    [ -f /data/bin/nx5_env.sh ] && . /data/bin/nx5_env.sh
    NX5TS_DBG=1 nohup ./nx5gui >> /data/nx5gui_live.log 2>&1 &
)
echo "[+] 新 GUI 已热启动"

# curl 持久化(后续 OTA 直连快速通道)
if [ -x /tmp/curl ] && [ ! -x "$CONF_DIR/curl" ]; then
    cp -f /tmp/curl "$CONF_DIR/curl" 2>/dev/null && chmod +x "$CONF_DIR/curl" 2>/dev/null
fi

# ---------------------------------------------------------------- 7. 验证
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
    echo "[-] GUI 未能立即拉起,查看 /data/nx5gui_live.log 尾部:"
    tail -n 8 /data/nx5gui_live.log 2>/dev/null
    echo "[*] /data/bin keeper 会自动重试拉起;5 秒后复查。"
    sleep 5
    for p in $(ls /proc 2>/dev/null | grep -E '^[0-9]+$'); do
        e=$(readlink /proc/$p/exe 2>/dev/null)
        [ "$e" = "$TARGET_BIN" ] && echo "[+] keeper 已拉起,安装完成。" && exit 0
    done
    exit 1
fi

