#!/bin/sh
# Latest deployment: fetch current installer and its matching full payload.
set -eu
CHECK=0
case "${1:-}" in --check) CHECK=1;; '') ;; *) echo 'Usage: sh installer.sh [--check]'; exit 2;; esac
DIR=${NX5_BOOTSTRAP_DIR:-/data/zero3-install}
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
REF=main
SOURCES="https://ghfast.top/https://raw.githubusercontent.com/$G/$REF
https://gh-proxy.org/https://raw.githubusercontent.com/$G/$REF
https://cdn.jsdelivr.net/gh/$G@$REF
https://raw.githubusercontent.com/$G/$REF"
# Optional reverse-proxy prefix, e.g. https://proxy.example/https://github... .
# The prefix is joined to the canonical raw URL, never evaluated as shell code.
if [ -n "${NX5_GITHUB_PROXY:-}" ]; then
    case "$NX5_GITHUB_PROXY" in
        https://*|http://*) ;;
        *) echo 'NX5_GITHUB_PROXY must start with http:// or https://'; exit 2;;
    esac
    SOURCES="${NX5_GITHUB_PROXY%/}/https://raw.githubusercontent.com/$G/$REF
$SOURCES"
fi
fetch_verified() {
    rel=$1; dest=$2; expected=${3:-}
    for base in $SOURCES; do
        rm -f "$dest.part"
        echo "[*] Try $base/$rel"
        if [ -n "$C" ]; then
            rc=0
            "$C" -fL --connect-timeout 5 --max-time 120 "$base/$rel?t=$(date +%s)" -o "$dest.part" || rc=$?
            case "$rc" in
                60|77)
                    echo '[!] Device CA unavailable; retrying compatible download.'
                    rc=0
                    "$C" -fkL --connect-timeout 5 --max-time 120 "$base/$rel?t=$(date +%s)" -o "$dest.part" || rc=$?
                    ;;
            esac
            if [ "$rc" != 0 ]; then
                echo '[!] Download failed; trying next source.'; continue
            fi
        else
            if ! wget -T 120 -O "$dest.part" "$base/$rel?t=$(date +%s)"; then
                echo '[!] Download failed; trying next source.'; continue
            fi
        fi
        if [ -z "$expected" ]; then
            digest=$(sed -n "s/^EXPECTED_SHA256='\([0-9a-f]*\)'$/\1/p" "$dest.part")
            if [ "${#digest}" = 64 ] && sh -n "$dest.part"; then
                mv -f "$dest.part" "$dest"
                echo "[+] Current installer downloaded"
                return 0
            fi
        elif [ -s "$dest.part" ] && printf '%s  %s\n' "$expected" "$dest.part" | sha256sum -c -; then
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
fetch_verified install.sh install.sh
EXPECTED=$(sed -n "s/^EXPECTED_SHA256='\([0-9a-f]*\)'$/\1/p" install.sh)
fetch_verified release/nx5gui_latest.tar.gz release/nx5gui_latest.tar.gz "$EXPECTED"
sh install.sh --check
if [ "$CHECK" = 1 ]; then
    echo '[+] Check complete; no installation or reboot performed.'
    exit 0
fi
sh install.sh
sync
reboot
