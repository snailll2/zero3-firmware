#!/bin/sh
# ==============================================================================
# 零洞 Zero3 引导脚本 — 粘贴到 telnet/SSH 执行(自动补 HTTPS 能力 → 拉主安装脚本)
# 主安装脚本负责:备份配置 → 多镜像下载固件包 → 精确替换 → 热启动 → 验证
# ==============================================================================
cd /tmp
C=""
for p in /data/nx5_conf/intercom/curl /data/curl /tmp/curl /usr/bin/curl; do
    [ -x "$p" ] && C="$p" && break
done
if [ -z "$C" ]; then
    if command -v curl >/dev/null 2>&1; then
        C=$(command -v curl)
    else
        wget -O curl "http://master.dl.sourceforge.net/project/aqarahub/binutils/curl?viasf=1" 2>/dev/null
        chmod +x curl 2>/dev/null
        C=./curl
    fi
fi
echo "[+] curl: $C"

G="snailll2/zero3-firmware"
OK=0
for h in "ghfast.top/https://raw.githubusercontent.com/$G/main" \
         "cdn.jsdelivr.net/gh/$G@main" \
         "raw.githubusercontent.com/$G/main"; do
    rm -f i.sh
    "$C" -skfL -m 15 "https://$h/install.sh" -o i.sh 2>/dev/null
    if [ -s i.sh ] && head -3 i.sh | grep -q "Zero3"; then
        echo "[+] install.sh 拉取成功: $h"
        sh i.sh
        OK=1
        break
    fi
done
[ "$OK" -eq 1 ] || echo "[-] 所有镜像均拉取失败,检查网络后重试(或离线:PC 下载 nx5gui_latest.tar.gz 推到 /tmp 再跑主安装脚本)"
