#!/bin/sh
# Offline full application deployment on the stock NX5 / Zero3 Linux system.
# The packager replaces the archive digest; no network fetch is required.
set -eu
umask 077
BASE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ARCHIVE="$BASE/release/nx5gui_latest.tar.gz"
EXPECTED_SHA256='55eabeccd17f29a4953c0a08c47ca6a62ecdaac7368c6ab58b9d7e3fbc59b901'
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
STAGE_KB=$(gzip -dc "$ARCHIVE" | wc -c | awk '{print int(($1+1023)/1024)}')
STAGE_FREE=$(df -k "$STAGING" | tail -1 | awk '{print $4}')
[ "$STAGE_FREE" -ge "$((STAGE_KB+4096))" ] || { echo "空间不足：解压需 $STAGE_KB KB，另需 4096 KB 余量，可用 $STAGE_FREE KB"; exit 7; }
WORK=$(mktemp -d "$STAGING/.nx5-full-install.XXXXXX")
BOOT_ID=$(cat /proc/sys/kernel/random/boot_id 2>/dev/null || :)
[ -z "$BOOT_ID" ] || printf '%s %s\n' "$BOOT_ID" "$$" > "$WORK/.nx5-stage-owner"
APPLYING=0
BACK=''
PENDING_WRITTEN=0
rollback() {
    [ "$APPLYING" = 1 ] || return 0
    echo '安装失败，恢复本次替换的文件...'
    restored=1
    while IFS= read -r rel; do
        rm -f "$ROOT/$rel.installing" "$ROOT/$rel.rollback"
        if [ -f "$BACK/files/$rel" ]; then
            if [ "$LINK_MODE" = link ]; then
                ln "$BACK/files/$rel" "$ROOT/$rel.rollback" || { restored=0;continue; }
            else
                cp -p "$BACK/files/$rel" "$ROOT/$rel.rollback" || { restored=0;continue; }
            fi
            mv -f "$ROOT/$rel.rollback" "$ROOT/$rel" || restored=0
        else rm -f "$ROOT/$rel" || restored=0;fi
    done < "$BACK/changed-files"
    [ "$restored" = 1 ]
}
cleanup() {
 rc=$?; trap - EXIT
 restored=1
 if [ "$rc" != 0 ]; then
   rollback || restored=0
   message='安装失败，已恢复旧文件'
   if [ "$restored" != 1 ]; then message='安装失败且回退未完成，保留备份及暂存';: > "$WORK/.nx5-stage-recovery-needed";echo "$message";fi
   if [ -n "${NX5_OTA_JOB:-}" ]; then printf '{"job_id":"%s","version":"%s","phase":"failed","status":"FAILED","progress":0,"error":"%s"}\n' "$NX5_OTA_JOB" "$NX5_OTA_VERSION" "$message" > "$ROOT/nx5_ota/result.json.new"; mv -f "$ROOT/nx5_ota/result.json.new" "$ROOT/nx5_ota/result.json";fi
 fi
 if [ "$rc" != 0 ] && [ "$restored" = 1 ] && [ "$APPLYING" = 1 ]; then
   [ "$PENDING_WRITTEN" != 1 ] || rm -f "$ROOT/nx5_ota/pending"
   # This transaction was completely restored; its own duplicate snapshot is redundant.
   [ -z "$BACK" ] || rm -rf "$BACK"
 fi
 [ "$restored" != 1 ] || rm -rf "$WORK"
 exit "$rc"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
(umask 022; tar -xzf "$ARCHIVE" -C "$WORK")
(cd "$WORK" && sha256sum -c DEPLOY-SHA256SUMS >/dev/null)
for f in nx5gui nx5vo nx5_vdec_helper start_app.sh data_app.sh uninstall.sh \
 nx5_conf/intercom/mijia_ca.cert nx5_conf/intercom/mijia_cloud_ca.crt \
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
[ ! -f "$ROOT/nx5_ota/pending" ] || { echo '已有升级等待启动验证，请先重启完成检查'; exit 8; }
# Probe on the same filesystem; reserve full copy + largest restore if hardlinks are unavailable.
LINK_MODE=copy
: > "$ROOT/.nx5-link-probe.$$"
if ln "$ROOT/.nx5-link-probe.$$" "$WORK/.link-probe" 2>/dev/null; then LINK_MODE=link;fi
rm -f "$ROOT/.nx5-link-probe.$$" "$WORK/.link-probe"
RESERVE=4096
if [ "$LINK_MODE" = copy ]; then
 OLD_KB=0;MAX_KB=0
 for rel in $(cat "$WORK/DEPLOY-FILES") bin/start_app.sh bin/data_app.sh bin/nx5_env.sh nx5nss/libc.so.6 nx5nss/libresolv.so.2 nx5nss/ld-linux.so.3; do
  [ -f "$ROOT/$rel" ] || continue
  n=$(du -k "$ROOT/$rel" | awk '{print $1}');OLD_KB=$((OLD_KB+n));[ "$n" -le "$MAX_KB" ] || MAX_KB=$n
 done
 RESERVE=$((RESERVE+OLD_KB+MAX_KB))
fi
AVAILABLE=$(df -k "$ROOT" | tail -1 | awk '{print $4}')
[ "$AVAILABLE" -ge "$RESERVE" ] || { echo "空间不足：备份及回退需 $RESERVE KB，可用 $AVAILABLE KB (模式 $LINK_MODE)"; exit 7; }
BACK="$ROOT/deployment-backups/$(date +%Y%m%d-%H%M%S)-$$"
mkdir -p "$BACK/files"; : > "$BACK/changed-files"
: > "$BACK/managed-v1"
sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$WORK/DEPLOY-METADATA.json" > "$BACK/target-version"
if [ -f "$ROOT/DEPLOY-METADATA.json" ]; then sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$ROOT/DEPLOY-METADATA.json" > "$BACK/source-version"; else printf 'unknown\n' > "$BACK/source-version"; fi
echo '[2/5] 备份旧程序和启动入口...'
APPLYING=1
install_file() {
    src=$1; rel=$2
    if [ -f "$ROOT/$rel" ] && cmp -s "$src" "$ROOT/$rel"; then return 0;fi
    mkdir -p "$ROOT/$(dirname "$rel")"
    if [ -f "$ROOT/$rel" ]; then
        mkdir -p "$BACK/files/$(dirname "$rel")"; if [ "$LINK_MODE" = link ]; then ln "$ROOT/$rel" "$BACK/files/$rel"; else cp -p "$ROOT/$rel" "$BACK/files/$rel"; fi
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
        if [ "$LINK_MODE" = link ]; then ln "$ROOT/$rel" "$BACK/files/$rel"; else cp -p "$ROOT/$rel" "$BACK/files/$rel"; fi
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

if [ "$TEST_ROOT" = 0 ] || [ -n "${NX5_OTA_JOB:-}" ]; then
    AUTO_REBOOT=0
    [ -z "${NX5_OTA_JOB:-}" ] || AUTO_REBOOT=1
    NX5_OTA_JOB=${NX5_OTA_JOB:-manual-$(date +%Y%m%d%H%M%S)-$$}
    NX5_OTA_VERSION=${NX5_OTA_VERSION:-$(cat "$BACK/target-version")}
    mkdir -p "$ROOT/nx5_ota"
    printf "JOB='%s'\nVERSION='%s'\nBACKUP='%s'\n" "$NX5_OTA_JOB" "$NX5_OTA_VERSION" "$BACK" > "$ROOT/nx5_ota/pending.new"
    mv -f "$ROOT/nx5_ota/pending.new" "$ROOT/nx5_ota/pending"
    PENDING_WRITTEN=1
    printf '{"job_id":"%s","version":"%s","phase":"rebooting","status":"RUNNING","progress":90,"error":""}\n' "$NX5_OTA_JOB" "$NX5_OTA_VERSION" > "$ROOT/nx5_ota/result.json.new"
    mv -f "$ROOT/nx5_ota/result.json.new" "$ROOT/nx5_ota/result.json"
    sync
    APPLYING=0
    if [ "$TEST_ROOT" = 0 ] && [ "$AUTO_REBOOT" = 1 ]; then sleep 2; reboot; fi
fi

APPLYING=0
