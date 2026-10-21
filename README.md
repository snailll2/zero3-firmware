# Zero3 智能中控 固件发布仓（NX5, 1024x600）

面向 **Zero3 智能中控（Anyka NX5, 1024×600 触屏）** 的定制固件：LVGL 8.2 多屏仪表 + Home Assistant 双向联动 + 8080 Web 控制台 + 在线更新。

> 本仓库为**发布仓**：只放运行时产物（nx5gui 二进制 / 版本清单 / 安装脚本）。设备端源码在本地工作区 `aciga_gui`（leelen_intercom_opensrc 移植层）。

## 在线更新（设备 Web 控制台）

Web 控制台 → **设置 → 固件更新**：

1. **检测更新**：设备优先直连 GitHub；不可用时自动走 **浏览器中转**（电脑拉取后分块传给设备）
2. **下载**：分块传输 + md5 强校验
3. **安装**：自动备份当前固件（`/data/aciga_lvgl.bak`）→ 原子替换 → 自动重启生效

## SSH/telnet 一键安装（新机/恢复用）

telnet/SSH 进面板后（root / 123456），**整段粘贴**以下引导脚本执行：

```sh
cd /tmp
C=""
for p in /data/nx5_conf/intercom/curl /data/scripts/curl /tmp/curl /usr/bin/curl; do
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
```


引导脚本自动完成：查找/获取 curl（优先上次安装持久化的便携 curl）→ 三镜像拉取主安装脚本 → 主脚本再完成 备份用户配置 → 下载 release 包 → 精确替换固件（原厂 GUI 冻结共存不受影响）→ 热启动 → 验证。

**离线环境**（设备不通 GitHub）：PC 从 [Release](https://github.com/snailll2/zero3-firmware/releases/latest) 下载 `nx5gui_latest.tar.gz`，推到设备 `/tmp/`（scp/浏览器均可），重跑上面引导脚本会自动检测本地包跳过下载。

## 版本清单格式（version.json，设备 OTA 检查用）

```json
{
  "version": "1.0.117+20261007",
  "file": "nx5gui",
  "size": 4855436,
  "md5": "…",
  "notes": ["更新说明1", "更新说明2"]
}
```

## 回退

- 设备上保留 `/data/aciga_lvgl.bak`（每次 OTA 自动备份），telnet 执行：
  `cp /data/aciga_lvgl.bak /data/aciga_lvgl && kill -9 $(pidof aciga_lvgl)`
- 彻底回退出厂：`mv /data/bin /data/bin.off && reboot`（开机链自动恢复原厂显示）

## 授权

固件内置 Ed25519 公钥验签：设置页显示机器码，凭厂商签发的授权凭证激活；未激活时 HA 配置与部分功能锁定（详见 Web 设置页授权卡片）。
