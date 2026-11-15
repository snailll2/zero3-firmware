#!/bin/sh
# Restore the factory boot branch on the next reboot, retaining all user data.
set -eu
[ "$(id -u)" = 0 ] || { echo '请使用设备 root 账户'; exit 1; }
for f in /data/bin/start_app.sh /data/bin/data_app.sh; do
    [ ! -f "$f" ] || mv -f "$f" "$f.zero3-disabled"
done
rm -f /data/productionTest
[ ! -d /data/nand-1 ] || rmdir /data/nand-1 2>/dev/null || :
sync
echo '已关闭 Zero3 开机接管，账户、Wi-Fi、布局及程序备份均保留。'
echo '当前显示继续运行；请执行 reboot，恢复原厂启动流程。'
