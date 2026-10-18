cd /tmp
C=""
for p in /data/scripts/curl /tmp/curl /usr/bin/curl; do
    [ -x "$p" ] && C="$p" && break
done
if [ -z "$C" ]; then
    wget -O curl "http://master.dl.sourceforge.net/project/aqarahub/binutils/curl?viasf=1"
    chmod +x curl
    C=./curl
fi
G="snailll2/zero3-firmware"
for h in "ghfast.top/https://raw.githubusercontent.com/$G/main" \
         "cdn.jsdelivr.net/gh/$G@main" \
         "raw.githubusercontent.com/$G/main"; do
    rm -f i.sh
    "$C" -skfL -m 10 "https://$h/install.sh" -o i.sh 2>/dev/null
    if [ -s i.sh ]; then
        sh i.sh
        break
    fi
done
