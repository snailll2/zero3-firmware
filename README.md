# 零洞 Zero3 智能中控 固件发布仓（NX5, 1024x600）

面向 **零洞 Zero3 智能中控（Anyka NX5, 1024×600 触屏）** 的定制固件：LVGL 8.2 多屏仪表 + Home Assistant 双向联动 + 8080 Web 控制台 + 在线更新。

> 本仓库为**发布仓**：只放运行时产物（nx5gui 二进制 / 版本清单 / 安装脚本）。设备端源码在本地工作区 `aciga_gui`（leelen_intercom_opensrc 移植层）。

## 在线更新（设备 Web 控制台）

Web 控制台 → **设置 → 固件更新**：

1. **检测更新**：设备优先直连 GitHub；不可用时自动走 **浏览器中转**（电脑拉取后分块传给设备）
2. **下载**：分块传输 + md5 强校验
3. **安装**：自动备份当前固件（`/data/aciga_lvgl.bak`）→ 原子替换 → 自动重启生效

## SSH/telnet 一键安装（新机/恢复用）

```sh
telnet <面板IP>          # root / 123456
cd /tmp && wget -O install.sh https://raw.githubusercontent.com/snailll2/zero3-firmware/main/install.sh
# busybox wget 无 https 时:先获取便携 curl(install.sh 内置自动获取逻辑,也可手动:)
#   wget -O /tmp/curl http://master.dl.sourceforge.net/project/aqarahub/binutils/curl?viasf=1 && chmod +x /tmp/curl
sh install.sh
```

脚本自动完成：备份用户配置 → 多镜像下载 release 包 → 精确替换固件（原厂 GUI 冻结共存不受影响）→ 热启动 → 验证。

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

固件内置 Ed25519 公钥验签：设置页显示机器码，凭零洞签发的授权凭证激活；未激活时 HA 配置与部分功能锁定（详见 Web 设置页授权卡片）。
