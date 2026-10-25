# Zero3 智能中控 固件发布仓（NX5, 1024x600）

面向 **Zero3 智能中控（Anyka NX5, 1024×600 触屏）** 的定制固件：LVGL 8.2 多屏仪表 + Home Assistant 双向联动 + 8080 Web 控制台 + 在线更新。

> 本仓库为**发布仓**：只放运行时产物（nx5gui 二进制 / 版本清单 / 安装·卸载脚本）。设备端源码在本地工作区 `aciga_gui`（leelen_intercom_opensrc 移植层）。

## 在线更新（设备 Web 控制台）

Web 控制台 → **设置 → 固件更新**：

1. **检测更新**：设备优先直连 GitHub；不可用时自动走 **浏览器中转**（电脑拉取后分块传给设备）
2. **下载**：分块传输 + md5 强校验
3. **安装**：全量 tar 更新（二进制+脚本+主题）→ md5 强校验 → 自动重启生效

## telnet 一键安装（新机/恢复用）

> 设备只有 **telnet**（无 SSH）：`telnet 192.168.50.x`，登录 root / 123456。

telnet 进面板后，**整段粘贴**以下引导脚本执行：

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
         "gh-proxy.org/https://raw.githubusercontent.com/$G/main" \
         "cdn.jsdelivr.net/gh/$G@main" \
         "raw.githubusercontent.com/$G/main"; do
    rm -f i.sh
    echo "[*] try: $h"
    "$C" -skfL -m 10 "https://$h/install.sh" -o i.sh 2>/dev/null
    if [ -s i.sh ]; then
        echo "[*] download success. start installing ..."
        sh i.sh
        break
    fi
    echo "[!] download failed. try next one ..."
done
```


引导脚本自动完成：查找/获取 curl（优先上次安装持久化的便携 curl）→ 依次尝试 4 个镜像（ghfast → gh-proxy.org → jsdelivr → raw）拉取主安装脚本 → 主脚本再完成 备份用户配置 → 下载 release 包 → 精确替换固件（原厂 GUI 冻结共存不受影响）→ 热启动 → 验证。

> **如果所有镜像都下载失败**（`i.sh` 为空或不存在，脚本无任何输出直接结束）：通常是设备当前网络不通 GitHub 镜像。请检查 WiFi/网线连接后重试；或改用**离线安装**（下方"离线环境"一节）。

**离线环境**（设备不通 GitHub）：PC 从 [Release](https://github.com/snailll2/zero3-firmware/releases/latest) 下载 `nx5gui_latest.tar.gz`，推到设备 `/tmp/`（scp/浏览器均可），重跑上面引导脚本会自动检测本地包跳过下载。

## 启动链（v9 纯直启,2026-10-26 起）

**双通道自启**，全程不动 `/system`（只读 squashfs）：

1. **官方分叉点**（产测模式）：`/data/productionTest`（文件）+ `/data/nand-1`（目录）存在时，原厂 `start_app.sh` 的 `user_app_init()` 走产测分支——**lingdong_app.sh 整链不执行**（linkdora_broker / aciga_devinfo / aciga_guardian 均不自启；guardian 不存在 → 原厂 GUI（aciga_lvgl）永不被拉起）。
2. **Sinit 钩子**：原厂 init 检查 `/data/bin/data_app.sh` 存在则执行 `/data/bin/start_app.sh`（原厂笔误，可利用）——我们的开机总入口。

开机时序（直启）：

```
上电 → 原厂 init → start_app.sh 检测到 /data/productionTest → 产测分支(原厂链跳过)
     → Sinit 钩子执行 /data/bin/start_app.sh (v9)
        ├─ 加载 /data/bin/nx5_env.sh(批次环境变量)
        ├─ 移植启动 linkdora_broker(消息总线) + aciga_devinfo(WiFi/背光/gl 硬件)
        │   (guardian 故意不启——它会复活原厂 GUI;WiFi 凭据自动保护回写)
        └─ /data/nx5gui
            ├─ fymedia 媒体栈全协议初始化(sys init → VO SetPubAttr → Enable)
            ├─ open fb0(fyfb 成功绑定 VO 图层)→ 原厂 logo 直接切换到我们的 UI
            ├─ GUI 进程内 GPIO83 外部硬看门狗喂狗(新批次)
            └─ 看护:GUI 退出重试 ≤3 次
```

**接管模式**（备选，`NX5_DIRECT_BOOT` 未设时）：原厂 GUI 先点亮面板 → 我们 SIGSTOP 冻结它（fd 保留、vo 管线继续扫描）→ 写 fb0 上屏。批次环境（`nx5_env.sh`，install.sh 按 ioctrl.ko md5 判定）：新批次（163 型）`NX5_GPIO83FEED=1`+`NX5_NOWDT=1`；旧批次（149 型）GUI 自行开 `/dev/watchdog`。

## 设备端文件清单

| 路径 | 说明 |
|---|---|
| `/data/nx5gui` | GUI 二进制（定名，不借用原厂 aciga_lvgl，避开 guardian 的 killall 连坐） |
| `/data/bin/start_app.sh` | **开机接管脚本**（Sinit 钩子自动执行，见上节时序） |
| `/data/bin/data_app.sh` | 哑文件（Sinit 只检查它存在，真正执行的是 start_app.sh） |
| `/data/bin/nx5_env.sh` | 批次环境变量（install.sh 生成，可手工编辑后重启生效） |
| `/data/productionTest` | **直启分叉标志**（空文件；存在=原厂走产测分支，原厂 GUI 永不启动） |
| `/data/nand-1` | **直启分叉标志**（空目录；与上文件配合） |
| `/data/nx5gui_live.log` | GUI 运行日志（追加式，跨重启保留；排查死亡现场看这里） |
| `/data/nx5_conf/intercom/` | 用户配置：app/ha/home_layout/license .json + 便携 curl（OTA 直连用） |
| `/data/theme/theme_default/` | 主题资源（379 文件，Web 编辑器同源） |
| `/tmp/nx5gui.lock` | 单实例 flock 锁（重启自动清） |

调试开关（touch 生成、rm 移除）：`/data/keeper_off` 临时停冻结巡检；`/data/nx5_render_pause` 暂停渲染（喂狗/Web 照常）。

环境变量开关（写在 nx5_env.sh 或启动前 export）：`NX5_GPIO83FEED` GPIO83 外部狗喂狗；`NX5_NOWDT` 不开软件看门狗；`NX5_NOFREEZE` 不冻结原厂（调试用，面板会双写）；`NX5_BL_BROKER` 背光走 broker 通道（默认关=内建 sysfs PWM 真息屏）；`NX5_BL_KEEPALIVE` 背光服务保活脉冲（默认关）。

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

## 卸载 / 回退

**标准卸载(推荐,1.0.131 起)** —— 设备 telnet 一行:

```sh
curl -skfL -o /tmp/uninstall.sh https://ghfast.top/https://raw.githubusercontent.com/snailll2/zero3-firmware/main/uninstall.sh && sh /tmp/uninstall.sh
```

- 默认:停 GUI + 摘开机链 + **移除直启分叉文件(productionTest/nand-1,恢复原厂启动链)** + 清调试残留,**保留用户配置/授权/主题**,最后重启回出厂
- `PURGE=1 sh /tmp/uninstall.sh`:连同 nx5_conf(HA 配置+授权!)、主题、备份彻底清除
- `REBOOT=0 sh /tmp/uninstall.sh`:只清理不重启(面板立即回原厂画面)
- 安全顺序:先解冻原厂再停 nx5gui(新批次设备外部看门狗需要原厂接管喂狗)

手工应急回退:`mv /data/bin /data/bin.off && reboot`(仅摘开机链,文件保留)

## 授权

固件内置 Ed25519 公钥验签：设置页显示机器码，凭厂商签发的授权凭证激活；未激活时 HA 配置与部分功能锁定（详见 Web 设置页授权卡片）。
