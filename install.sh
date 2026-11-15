#!/bin/sh
# Offline full application deployment on the stock NX5 / Zero3 Linux system.
# The packager replaces the archive digest; no network fetch is required.
set -eu
umask 077
BASE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ARCHIVE="$BASE/release/nx5gui_latest.tar.gz"
EXPECTED_SHA256='834043f8ebb763884b020c1eaa02f96b8f6f4bac11abd7d7ff743b3c6caed9ee'
ROOT=/data
CHECK=0
TEST_ROOT=0
while [ "$#" -gt 0 ]; do
    case "$1" in
        --check) CHECK=1; shift ;;
        --root) [ "$#" -ge 2 ] || exit 2; ROOT=$2; TEST_ROOT=1; shift 2 ;;
        *) echo "用法: sh install.sh [--check] [--root 测试目录]"; exit 2 ;;
    esac
done
case "$ROOT" in /*) ;; *) echo '安装目录必须是绝对路径'; exit 2;; esac
[ "$ROOT" != / ] || { echo '安装目录不能是 /'; exit 2; }
[ "$TEST_ROOT" = 0 ] || [ "$ROOT" != /data ] || { echo '--root 仅供隔离目录验证'; exit 2; }
if [ -n "${NX5_OTA_ARCHIVE:-}" ]; then
    ARCHIVE=$NX5_OTA_ARCHIVE
    [ -n "${NX5_OTA_MD5:-}" ] || exit 3
    echo "$NX5_OTA_MD5  $ARCHIVE" | md5sum -c - || exit 4
else
    if [ ! -f "$ARCHIVE" ]; then
        [ "$TEST_ROOT" = 0 ] || { echo '缺少完整部署负载'; exit 3; }
        case "$(uname -m)" in arm*) ;; *) echo '请使用完整离线目录'; exit 3;; esac
        C=''
        for c in /data/nx5_conf/intercom/curl /tmp/curl /usr/bin/curl /bin/curl; do [ ! -x "$c" ] || { C=$c; break; }; done
        [ -n "$C" ] || { echo '首次安装请下载并传入完整离线部署包'; exit 3; }
        mkdir -p "$ROOT/nx5_ota"
        ARCHIVE="$ROOT/nx5_ota/full-runtime.tar.gz"
        "$C" -fksSL --connect-timeout 10 --max-time 300 'https://raw.githubusercontent.com/snailll2/zero3-firmware/main/release/nx5gui_latest.tar.gz' -o "$ARCHIVE"
    fi
    [ "$EXPECTED_SHA256" != '@PAYLOAD_SHA256@' ] || { echo '请使用生成的完整部署包'; exit 3; }
    echo '[1/5] 校验完整包...'
    echo "$EXPECTED_SHA256  $ARCHIVE" | sha256sum -c - || exit 4
fi
# Reject unexpected paths/types before unpacking. The official package contains regular files only.
tar -tzf "$ARCHIVE" | awk '
 /^\// || /(^|\/)\.\.($|\/)/ {bad=1}
 END {exit bad}' || { echo '归档路径无效'; exit 4; }
STAGING=${TMPDIR:-/tmp}
if [ "$TEST_ROOT" = 0 ]; then STAGING=$ROOT; fi
WORK=$(mktemp -d "$STAGING/.nx5-full-install.XXXXXX")
APPLYING=0
BACK=''
rollback() {
    [ "$APPLYING" = 1 ] || return 0
    echo '安装失败，恢复本次替换的文件...'
    while IFS= read -r rel; do
        if [ -f "$BACK/files/$rel" ]; then
            cp -p "$BACK/files/$rel" "$ROOT/$rel.rollback" && mv -f "$ROOT/$rel.rollback" "$ROOT/$rel" || :
        else rm -f "$ROOT/$rel"; fi
    done < "$BACK/changed-files"
}
cleanup() {
 rc=$?; trap - EXIT
 if [ "$rc" != 0 ]; then
   rollback
   if [ -n "${NX5_OTA_JOB:-}" ]; then printf '{"job_id":"%s","version":"%s","phase":"failed","status":"FAILED","progress":0,"error":"安装失败，已恢复旧文件"}\n' "$NX5_OTA_JOB" "$NX5_OTA_VERSION" > "$ROOT/nx5_ota/result.json.new"; mv -f "$ROOT/nx5_ota/result.json.new" "$ROOT/nx5_ota/result.json"; fi
 fi
 rm -rf "$WORK"; exit "$rc"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
(umask 022; tar -xzf "$ARCHIVE" -C "$WORK")
(cd "$WORK" && sha256sum -c DEPLOY-SHA256SUMS >/dev/null)
for f in nx5gui nx5vo nx5_vdec_helper start_app.sh data_app.sh uninstall.sh \
 nx5_conf/intercom/curl nx5nss/libnss_dns.so.2 nx5nss/libnss_files.so.2 nx5nss/runtime/libc.so.6 \
 nx5nss/runtime/libresolv.so.2 nx5nss/runtime/ld-linux.so.3 specs/rules.json nx5_conf/intercom/web/index.html; do
    [ -s "$WORK/$f" ] || { echo "完整包缺少 $f"; exit 5; }
done
if [ "$CHECK" = 1 ]; then echo '完整包校验通过，未安装或启动任何程序。'; exit 0; fi
if [ "$TEST_ROOT" = 0 ]; then
    [ "$(id -u)" = 0 ] || { echo '请使用设备 root 账户安装'; exit 6; }
    case "$(uname -m)" in arm*) ;; *) echo '此包仅支持 ARM NX5 / Zero3 设备'; exit 6;; esac
    [ -c /dev/fb0 ] && [ -f /system/ko/ioctrl.ko ] || { echo '缺少 NX5 原厂显示驱动环境'; exit 6; }
fi
mkdir -p "$ROOT"
ROOT=$(CDPATH= cd -- "$ROOT" && pwd)
NEEDED=$(du -sk "$WORK" | awk '{print $1}')
AVAILABLE=$(df -k "$ROOT" | tail -1 | awk '{print $4}')
[ "$AVAILABLE" -gt 4096 ] || { echo '空间不足：暂存后至少需保留 4 MB'; exit 7; }
BACK="$ROOT/deployment-backups/$(date +%Y%m%d-%H%M%S)-$$"
mkdir -p "$BACK/files"; : > "$BACK/changed-files"
echo '[2/5] 备份旧程序和启动入口...'
APPLYING=1
install_file() {
    src=$1; rel=$2
    mkdir -p "$ROOT/$(dirname "$rel")"
    if [ -f "$ROOT/$rel" ]; then
        mkdir -p "$BACK/files/$(dirname "$rel")"; ln "$ROOT/$rel" "$BACK/files/$rel" 2>/dev/null || cp -p "$ROOT/$rel" "$BACK/files/$rel"
    fi
    printf '%s\n' "$rel" >> "$BACK/changed-files"
    case "$src" in
        "$WORK"/*) mv "$src" "$ROOT/$rel.installing" ;;
        *) cp -p "$src" "$ROOT/$rel.installing" ;;
    esac
    mv -f "$ROOT/$rel.installing" "$ROOT/$rel"
}
echo '[3/5] 安装依赖、规则、主题和页面...'
# All destinations come from the build-time allowlist, never from a household snapshot.
while IFS= read -r rel; do
    case "$rel" in nx5gui|defaults/*) continue;; esac
    install_file "$WORK/$rel" "$rel"
done < "$WORK/DEPLOY-FILES"
# Earlier full bundles put these libc files on the stock command search path.
# Retain a backup, then remove only those managed runtime names from that path.
for f in libc.so.6 libresolv.so.2 ld-linux.so.3; do
    rel="nx5nss/$f"
    if [ -f "$ROOT/$rel" ]; then
        mkdir -p "$BACK/files/nx5nss"
        ln "$ROOT/$rel" "$BACK/files/$rel" 2>/dev/null || cp -p "$ROOT/$rel" "$BACK/files/$rel"
        printf '%s\n' "$rel" >> "$BACK/changed-files"
        rm -f "$ROOT/$rel"
    fi
done
# Fresh-install defaults only; never overwrite existing user configuration.
for f in home_layout.json app.json; do
    [ -e "$ROOT/nx5_conf/intercom/$f" ] || install_file "$WORK/defaults/$f" "nx5_conf/intercom/$f"
done
echo '[4/5] 配置开机入口...'
install_file "$ROOT/start_app.sh" bin/start_app.sh
install_file "$ROOT/data_app.sh" bin/data_app.sh
ENV_NEW="$WORK/nx5_env.sh"
if [ -f "$ROOT/bin/nx5_env.sh" ]; then cp -p "$ROOT/bin/nx5_env.sh" "$ENV_NEW"; else
    printf '#!/bin/sh\n# Hardware-specific settings generated on the target device.\n' > "$ENV_NEW"
    IO_MD5=$(md5sum /system/ko/ioctrl.ko 2>/dev/null | cut -d' ' -f1 || :)
    case "$IO_MD5" in 432548a3*) printf 'export NX5_GPIO83FEED=1\nexport NX5_NOWDT=1\nexport NX5_BL_LINKDORA=1\n' >> "$ENV_NEW";; esac
fi
for setting in 'NX5_DIRECT_BOOT=1' 'NX5_FREE_CARD_DEFAULT_DIR=/data/share/nx5/free_cards/domains'; do
    key=${setting%%=*}
    grep -q "^[[:space:]]*export $key=" "$ENV_NEW" || printf 'export %s\n' "$setting" >> "$ENV_NEW"
done
chmod 755 "$ENV_NEW"; install_file "$ENV_NEW" bin/nx5_env.sh
# New payload is committed last; an active GUI keeps its old inode until reboot.
install_file "$WORK/nx5gui" nx5gui
# Activate the stock production branch on the next boot. No live VO/GUI restart here.
if [ ! -e "$ROOT/productionTest" ]; then : > "$WORK/productionTest"; install_file "$WORK/productionTest" productionTest; fi
mkdir -p "$ROOT/nand-1"
sync
echo '[5/5] 完整部署完成。已有账户、Wi-Fi 和布局已保留。'
echo "本次备份：$BACK"
if [ "$TEST_ROOT" = 1 ]; then echo '隔离目录验证完成，未访问显示或重启设备。'; else
    echo '请执行 reboot，重启后由唯一显示守护程序启动界面。'
fi

if [ -n "${NX5_OTA_JOB:-}" ]; then
    mkdir -p "$ROOT/nx5_ota"
    printf "JOB='%s'\nVERSION='%s'\nBACKUP='%s'\n" "$NX5_OTA_JOB" "$NX5_OTA_VERSION" "$BACK" > "$ROOT/nx5_ota/pending.new"
    mv -f "$ROOT/nx5_ota/pending.new" "$ROOT/nx5_ota/pending"
    printf '{"job_id":"%s","version":"%s","phase":"rebooting","status":"RUNNING","progress":90,"error":""}\n' "$NX5_OTA_JOB" "$NX5_OTA_VERSION" > "$ROOT/nx5_ota/result.json.new"
    mv -f "$ROOT/nx5_ota/result.json.new" "$ROOT/nx5_ota/result.json"
    sync
    APPLYING=0
    if [ "$TEST_ROOT" = 0 ]; then sleep 2; reboot; fi
fi

APPLYING=0
