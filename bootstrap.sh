#!/bin/sh
# Fixed 2.0.5 deployment: proxy fallback + pinned installer/payload hashes.
set -eu
CHECK=0
case "${1:-}" in --check) CHECK=1;; '') ;; *) echo 'Usage: sh bootstrap.sh [--check]'; exit 2;; esac
DIR=${NX5_BOOTSTRAP_DIR:-/data/zero3-install-2.0.5}
mkdir -p "$DIR/release"
cd "$DIR"
C=''
for p in /data/nx5_conf/intercom/curl /data/scripts/curl /tmp/curl /usr/bin/curl /bin/curl; do
    if [ -x "$p" ]; then C=$p; break; fi
done
if [ -z "$C" ]; then
    command -v wget >/dev/null 2>&1 || { echo 'No curl/wget; use PC offline transfer.'; exit 3; }
fi
command -v sha256sum >/dev/null 2>&1 || { echo 'Missing sha256sum; stop.'; exit 3; }
G=snailll2/zero3-firmware
TAG=v2.0.5-20261115
SOURCES="https://ghfast.top/https://raw.githubusercontent.com/$G/$TAG
https://gh-proxy.org/https://raw.githubusercontent.com/$G/$TAG
https://cdn.jsdelivr.net/gh/$G@$TAG
https://raw.githubusercontent.com/$G/$TAG"
fetch_verified() {
    rel=$1; dest=$2; expected=$3
    for base in $SOURCES; do
        rm -f "$dest.part"
        echo "[*] Try $base/$rel"
        if [ -n "$C" ]; then
            rc=0
            "$C" -fL --connect-timeout 5 --max-time 120 "$base/$rel" -o "$dest.part" || rc=$?
            case "$rc" in
                60|77)
                    echo '[!] Device CA unavailable; retrying pinned SHA256 download.'
                    rc=0
                    "$C" -fkL --connect-timeout 5 --max-time 120 "$base/$rel" -o "$dest.part" || rc=$?
                    ;;
            esac
            if [ "$rc" != 0 ]; then
                echo '[!] Download failed; trying next source.'; continue
            fi
        else
            if ! wget -T 120 -O "$dest.part" "$base/$rel"; then
                echo '[!] Download failed; trying next source.'; continue
            fi
        fi
        if [ -s "$dest.part" ] && printf '%s  %s\n' "$expected" "$dest.part" | sha256sum -c -; then
            mv -f "$dest.part" "$dest"
            echo "[+] Verified $rel"
            return 0
        fi
        echo '[!] SHA256 mismatch or empty response; trying next source.'
    done
    rm -f "$dest.part"
    echo "[!] All sources failed: $rel. Use PC offline transfer."
    return 4
}
fetch_verified install.sh install.sh 2f0e34aa7accada872bb1003bac10ff030ec5f08cfac970aeac9d17f2a1b8125
fetch_verified release/nx5gui_latest.tar.gz release/nx5gui_latest.tar.gz 2ad6408823cd03d42d776609a9b302e4ed8de1fc798e95b0bb641ed6f3268761
sh install.sh --check
if [ "$CHECK" = 1 ]; then
    echo '[+] Check complete; no installation or reboot performed.'
    exit 0
fi
sh install.sh
sync
reboot
