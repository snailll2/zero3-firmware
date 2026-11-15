> 当前正式版：**2.0.6**。包含完整部署包、Web 在线升级和签名离线升级。升级步骤与测试记录见 [2.0.6 发布说明](docs/releases/2.0.6.md)。

# 零洞 Zero3 UI · 2.0

适用于 **NX5 / Zero3 · 1024 × 600 触屏面板**。基于 LVGL 9.6 与 Linux，将 Home Assistant、米家、可编排桌面、场景和 Web 管理整合到一块屏幕中，日常运行无需连接电脑。

当前正式版 **2.0.6+20261115-ota2** · 文档更新于 **2026-11-15**。

[下载正式版](https://github.com/snailll2/zero3-firmware/releases/latest) · [2.0 使用手册](USAGE.md) · [版本与升级验证](https://github.com/snailll2/zero3-firmware/blob/main/docs/releases/2.0.6.md)

## 2.0 能做什么

| 功能 | 说明 |
| --- | --- |
| 多屏桌面 | 独立屏幕名称、图标与网格，拖放卡片到指定位置；保存后应用到设备。 |
| 实体卡片 | 灯光、开关、空调、窗帘、风扇及传感器等；按实体能力显示电源、滑条、模式与详情控件。 |
| 场景执行 | 场景卡片可配置多步骤动作与延迟；也可绑定 HA 的场景、脚本或按钮实体。 |
| 四种主题 | 浅色、深色、暖色、薄荷，适配桌面、状态栏、设置与控件颜色；Web 顶部可直接预览选择。 |
| Home Assistant | 服务器与令牌配置、实体发现、状态同步及控制，设备列表可筛选并查看属性。 |
| 米家 | 小米账号授权、设备发现、MIoT 规则转换、云端与本地中枢控制；通道可用性取决于设备能力及授权。 |
| BLE / Zigbee 代理 | BLE 广播经 MQTT 转发至 HA；Zigbee 串口桥供 HA 侧 ZHA / Zigbee2MQTT 使用。 |
| 远程操作 | Web 实时投屏与触控、屏幕排版、接入与网络配置、文件管理、配置备份及黑匣子诊断。 |
| 网络与待机 | Wi-Fi 扫描和连接进度、有线网络配置、亮度、息屏、屏保与触摸唤醒。 |
| 完整升级 | 设备端更新入口、Web 在线升级及签名离线升级；显示下载、校验、安装、重启和启动检查进度。 |

卡片控件由实体实际能力决定；未同步或离线时显示对应提示。摄像头支持配置 RTSP / HA 源，兼容性与流畅度取决于视频编码和设备资源。

## 少量页面，看看实际效果

以下为 **2.0.6 实机 Web 新截图**。四主题截图中嵌入的画面来自设备实时投屏；排版设计器是浏览器预览，示例读数与样式不等于设备当前状态。数量、名称与连接状态仅为拍摄现场样本。

图片以两列缩略图展示，点击可查看原图。

<table>
<tr><th>浅色</th><th>深色</th></tr>
<tr><td><a href="docs/screenshots/2.0.5/web-light.jpg"><img src="docs/screenshots/2.0.5/web-light.jpg" alt="2.0.5 浅色首页与设备实时画面" width="340"></a></td><td><a href="docs/screenshots/2.0.5/web-dark.jpg"><img src="docs/screenshots/2.0.5/web-dark.jpg" alt="2.0.5 深色首页与设备实时画面" width="340"></a></td></tr>
<tr><th>暖色</th><th>薄荷</th></tr>
<tr><td><a href="docs/screenshots/2.0.5/web-warm.jpg"><img src="docs/screenshots/2.0.5/web-warm.jpg" alt="2.0.5 暖色首页与设备实时画面" width="340"></a></td><td><a href="docs/screenshots/2.0.5/web-mint.jpg"><img src="docs/screenshots/2.0.5/web-mint.jpg" alt="2.0.5 薄荷首页与设备实时画面" width="340"></a></td></tr>
<tr><th>屏幕排版</th><th>在线 / 离线升级</th></tr>
<tr><td><a href="docs/screenshots/2.0.5/web-layout.jpg"><img src="docs/screenshots/2.0.5/web-layout.jpg" alt="2.0.5 屏幕布局设计器" width="340"></a></td><td><a href="docs/screenshots/2.0.5/web-upgrade.jpg"><img src="docs/screenshots/2.0.5/web-upgrade.jpg" alt="2.0.5 Web 在线与签名离线升级" width="340"></a></td></tr>
</table>

## 安装与升级

在 [正式发布页](https://github.com/snailll2/zero3-firmware/releases/latest) 根据用途选择文件：

| 用途 | 文件与步骤 |
| --- | --- |
| 首次安装 / 完整重新部署 | 下载 `zero3-2.0.6-full-deploy.zip`，在电脑解压，将**整个目录**传入设备，按下方命令安装。 |
| Web 离线升级 | 下载 `zero3-2.0.6.signed.tar.gz`，打开「配置备份与升级」选择文件，校验后执行升级。 |
| 在线升级 | 支持新升级引擎的设备，在 Web「配置备份与升级」中检查更新 → 下载更新 → 立即升级。 |

### Telnet 一键安装（新机 / 重新部署）

在电脑终端运行 `telnet <面板IP>`，使用该设备的管理员账户登录。部分原厂设备为 `root / 123456`，以实际设备设置为准；这类设备通常没有 SSH，不要将下面的设备命令直接粘贴到电脑终端执行。

登录面板后，只需下载安装脚本并执行，自动安装最新版本：

```sh
(
G=snailll2/zero3-firmware
for S in "ghfast.top/https://raw.githubusercontent.com/$G/main" "gh-proxy.org/https://raw.githubusercontent.com/$G/main" "cdn.jsdelivr.net/gh/$G@main" "raw.githubusercontent.com/$G/main"; do
    echo "正在尝试下载源：https://$S"
    if curl -fkL --connect-timeout 5 --max-time 30 "https://$S/installer.sh" -o /tmp/installer.sh && [ -s /tmp/installer.sh ] && sh -n /tmp/installer.sh; then
        echo '下载成功，开始执行安装脚本。'
        sh /tmp/installer.sh
        exit $?
    fi
    echo '当前源下载或校验失败，自动切换下一个下载源……'
done
echo '所有下载源均失败，请检查网络或使用离线安装。'
exit 1
)
```

脚本内部自动查找下载工具、切换代理、获取最新完整包、校验、备份、安装并重启，保留已有配置。仅校验不安装时执行 `sh /tmp/installer.sh --check`。支持自定义 GitHub 反向代理：`NX5_GITHUB_PROXY=https://proxy.example sh /tmp/installer.sh`，优先尝试指定代理，失败自动回退 ghfast、gh-proxy.org、jsDelivr 和 GitHub。初次下载脚本失败时可从仓库下载 `installer.sh` 传入设备执行。 首次下载和包内下载均支持上述四源回退。多个自定义代理按顺序填写：`NX5_GITHUB_PROXIES="https://proxy-a.example https://proxy-b.example" sh /tmp/installer.sh`；全部失败后继续尝试内置源，单代理变量仍兼容。

### 设备无法联网下载：电脑中转完整包

1. 在电脑下载完整部署 ZIP 并解压，保留 `install.sh` 与 `release/` 的目录关系。
2. 设备有文件传输工具时，将整个解压目录传到 `/data/zero3-full`。没有 SSH / scp 时，可以用下方局域网 HTTP 方法。
3. 在电脑进入解压目录，运行：

```sh
python3 -m http.server 8000 --bind 0.0.0.0
```

4. 在设备 Telnet 中执行，先把占位 IP 换成电脑的局域网地址：

```sh
(
    set -eu
    PC_IP=192.168.1.10  # 改成电脑的实际局域网 IP
    mkdir -p /data/zero3-full/release
    cd /data/zero3-full
    wget -O install.sh.part "http://$PC_IP:8000/install.sh"
    wget -O release/nx5gui_latest.tar.gz.part "http://$PC_IP:8000/release/nx5gui_latest.tar.gz"
    mv install.sh.part install.sh
    mv release/nx5gui_latest.tar.gz.part release/nx5gui_latest.tar.gz
    sh install.sh --check
    sh install.sh
    sync
    reboot
)
```

两份文件就是完整安装所需的入口和全量负载，启动脚本、规则、依赖与资源已在负载内。电脑中转目录只放公开安装包，完成后在电脑按 `Ctrl+C` 关闭临时服务。

完整部署示例，假设文件传到 `/data/zero3-full`：

```sh
cd /data/zero3-full
sh install.sh --check
sh install.sh
reboot
```

完整包包含主程序、启动脚本、显示与视频守护、运行依赖、网络工具、公共 `rules.json`、主题和卡片资源。它是应用层完整部署包，需要原厂 Linux 系统仍完整，不包含引导器、内核或分区镜像。旧版尚无新升级接口时，先用完整包迁移。

升级保留已有账户、网络、布局、场景和自定义配置。在线与离线共用完整安装流程，检查签名、型号、版本和完整性；启动检查失败时恢复上一套运行文件。升级期间保持供电，等待设备重启后的最终结果。

2.0.6 已完成实机在线升级和正式签名包离线重装，配置保留与运行文件核验通过；损坏、错型号和降级包被拒绝。启动失败回退在隔离环境验证，未在实机故意制造断电。

### 版本清单与更新文件

根目录 `version.json` 与 `release/version.json` 供版本检查使用，包含 `version`、`file`、`size`、`md5`、`sig` 和 `notes`。其中 `sig` 是签名字段，不是可省略的说明文字；文件大小、摘要和签名必须与负载配套。`release/nx5gui_latest.tar.gz` 是安装器使用的完整运行负载，`.signed.tar.gz` 是 Web 离线上传使用的签名封装，两者不能互换上传。

```json
{
  "version": "2.0.6+20261115-ota2",
  "file": "release/nx5gui_latest.tar.gz",
  "size": 9263054,
  "md5": "119eeca6b9fba48b622f0eba7b1719a4",
  "sig": "<发布时生成的 Ed25519 签名，示例占位不可用于安装>",
  "notes": ["版本更新说明"]
}
```

普通使用者无需修改清单，更新发布以正式包为准。旧版只核对 MD5 或通过浏览器中转无签名包的步骤不用于 2.0.6 安装。

## 第一次使用

1. 在面板「设置」中查看 Web 地址，用同一局域网的浏览器打开 `http://<设备IP>:8080/`。
2. 在「智能家居集成」配置 HA 地址和长期令牌，或完成小米账号授权。
3. 在「设备与实体管理」核对来源、类型和属性，再到「首页与屏幕排版」添加卡片、选择实体并保存。
4. 在「实时投屏与触控」核对设备的真实效果；日常也可直接在面板操作。

更详细的主题、场景、Wi-Fi、更新与排错步骤见 [使用手册](USAGE.md)。Web 配置备份不是整机镜像；授权信息和备份请留在可信环境中。

## 设备文件、授权与回原厂

| 路径 | 用途 |
| --- | --- |
| `/data/nx5gui` | 设备主程序。 |
| `/data/nx5vo` | 显示守护，负责启动 GUI，避免重复实例抢占显示。 |
| `/data/bin/start_app.sh`、`data_app.sh` | 当前开机入口和配套脚本。 |
| `/data/bin/nx5_env.sh` | 安装时生成的硬件批次环境配置。 |
| `/data/nx5_conf/intercom/` | HA、米家、布局、显示和授权等用户配置；不要公开整个目录。 |
| `/data/specs/rules.json` | 米家公共转换规则；型号 spec / 翻译缓存也在此目录。 |
| `/data/theme/theme_default/` | 主题资源。 |
| `/data/nx5nss/` | DNS / 文件名解析模块；配套运行库隔离在 `runtime/`，不要拷到系统库目录。 |
| `/data/nx5_ota/` | 升级暂存、任务结果和启动检查信息。 |
| `/data/deployment-backups/` | 安装前的运行文件备份。 |
| `/data/nx5gui_live.log`、`nx5gui_crash.log` | 运行与崩溃排查线索，具体以设备实际生成文件为准。 |

授权按设备机器码验证，在「关于」或 Web 授权区域查看状态并提交匹配的授权凭证。HA / 米家模块未授权或过期时，相关入口或接口可能受限；安装固件不等于自动获得授权，也不要复制另一台设备的授权文件。

回到原厂启动链，可在设备执行完整包内的命令：

```sh
sh /data/zero3-full/uninstall.sh
reboot
```

若只通过引导安装、目录中没有卸载脚本，可在设备上下载本版脚本后执行：

```sh
curl -fL https://raw.githubusercontent.com/snailll2/zero3-firmware/main/uninstall.sh -o /tmp/zero3-uninstall.sh && sh /tmp/zero3-uninstall.sh && reboot
```

需要设备有可用的 curl；也可用电脑下载后传入设备。当前卸载脚本仅关闭开机接管，保留账户、网络、布局、程序与备份，重启后恢复原厂启动。旧版 `PURGE=1`、`REBOOT=0` 参数不适用于此版；不要把改名整个 `/data/bin` 当成标准卸载步骤。

## 当前边界

- 动态卡片设计器为 **Beta**；天气实时数据、部分高级领域和禁用的配置项以页面提示为准。
- 本地米家控制需要可用的中枢、证书与设备授权；发现网关 IP 不代表所有米家设备都支持本地控制。
- BLE 转发不等于任意 GATT 控制；Zigbee 配网与设备管理由 HA 侧完成。
- 不承诺所有布局、摄像头或设备组合稳定达到 30 FPS；预览画布不替代真机验证。

## 源码与开发

本目录是源码工作区，设备发布包见 [zero3-firmware](https://github.com/snailll2/zero3-firmware)。

## 视频与硬件能力

项目包含 RTSP 接收、H.264/H.265 解码接入、独立 `nx5_vdec_helper` 和共享内存帧交接，以及 JPEG 硬件编解码相关代码。已有设备探针验证 H.264/H.265 解码；实际 RTSP 的 H.265 解码、非对齐 stride 图像正确性和 JPEG 编解码结果见 [RTSP / JPEG 实测](docs/NX5_RTSP_JPEG_TEST.md)。

这些结果不能推导出“任意摄像头稳定满帧”：VPPU/VO 转色、缩放与直接显示的完整链路尚未全面验收，CPU 转色与帧复制仍可能成为瓶颈。该次 JPEG 实测源为灰阶画面，也不是彩色/零拷贝全覆盖验证；H.264/H.265 **视频编码**不在已验证能力内。

## 架构与目录

主 UI 与业务装配在 `nx5gui` 中；视频 helper、蓝牙/Zigbee 代理及看护脚本仍可能是独立进程，不能把整机描述为只有一个进程。

```text
Web / 触屏 / 实体按键
        ↓
LVGL 9.6 UI 与业务适配桥
        ↓
core：布局、动作、状态缓存、异步命令和设置队列
        ↓
HA / 米家 / 系统与网络 / 摄像头服务 / 板级驱动
```

UI 在自身线程处理显示，协议与系统操作通过后台服务执行；`core` 保持不依赖 LVGL。HTTP 使用 CivetWeb 统一承载 API 与 Web 资源；JSON 基础库使用完整 yyjson，仍有部分历史兼容扫描路径，不能据此宣称全部旧解析代码已经消除。MQTT / TLS 使用仓内 coreMQTT、mbedTLS 等依赖。

| 路径 | 用途 |
|---|---|
| `app/core/` | UI 无关布局协议、动作、状态、队列与刷新策略。 |
| `app/ui/lvgl9/` | 运行时网格、动态卡片、能力控件、详情、设置、主题与板级 UI 适配。 |
| `ui-editor-v11/` | 官方 LVGL Pro Editor XML 工程及导出的 C/H；当前校验清单为 90 个 NX5 组件、23 个屏幕。 |
| `app/services/` | HA、米家、实体、Web、系统、网络、摄像头、OTA 与兼容适配。 |
| `app/integration/target_linux/` | 程序入口、装配、待机、看护与目标板集成。 |
| `app/config/ui/free_cards/domains/` | 34 类领域的自由卡片默认定义；模板数量不等于已接通的控制协议数量。 |
| `third_party/` | LVGL、yyjson、coreMQTT、mbedTLS、CivetWeb 及板级依赖。 |
| `ha_integration/` / `ha_test/` | HA 蓝牙代理集成、米家实体对账工具。 |
| `tools/` / `app/tools/` | 工具链、导出校验、主题生成和开发工具。 |
| `docs/` | 设计规范、迁移、实测、问题记录和截图。 |

主要设备配置位于 `/data/nx5_conf/intercom/`，桌面真源为其中的 `home_layout.json`，供启动、Web 保存与热重载共用。自由卡片可按领域或实体覆盖，位于 `/data/nx5/free_cards/`；默认领域资源可安装在 `/usr/share/nx5/free_cards/domains/`。米家规则缓存位于 `/data/specs/`。

## 开发、构建与验证

### UI 修改流程

1. 修改 XML 源文件并同步对应镜像目录，参考 [卡片与自适应布局规范](docs/NX5GUI-3.5.2-Card-Design-and-Adaptive-Layout-Spec.md)。
2. 在 **LVGL Pro Editor** 中打开 `ui-editor-v11/`，使用官方构建/导出操作生成 C/H（Mac 快捷键 `⌘B`）。不要手改 `_gen.c` / `_gen.h`，也不要用自制 XML 编译器替代官方导出。
3. 检查导出清单；仅在确认是本次官方导出后更新封存记录，再检查 XML、镜像和生成物一致性。
4. 编译、运行适当的宿主测试，再通过设备实时画面验证实际布局、主题与能力控件。

```bash
python3 tools/ui_export/verify_official_export.py ui-editor-v11
python3 app/tools/editor_v50.py validate --project ui-editor-v11 --stage sealed
python3 app/tools/generate_theme_tokens.py --check
```

`editor_v50.py` 的封存只用于核对输入与生成物，不能替代官方 Editor 编译。历史 `tools/build_2.0.0_nx5gui.sh` 含生成物后处理/重新封存及本机目录假定，**不要直接把它当作当前官方导出流程的替代品**。

### 宿主构建与测试

在仓库根目录运行，需要 CMake、C 编译器、Python 3 和线程库；基础测试不要求显示设备：

```bash
cmake -S app -B build-host -DCMAKE_BUILD_TYPE=Debug -DNX5_BUILD_TESTS=ON
cmake --build build-host -j4
ctest --test-dir build-host --output-on-failure
```

上述默认构建不启用完整 LVGL UI，不会自动覆盖所有 UI 渲染测试。完整 UI 测试还需指定真实 LVGL 与官方 Editor 生成目录；最近一次完整配置的结果为 **104/104 通过、ARM 构建通过**，证据见 [Round 14 验证记录](docs/upgrades/3.5.2/style-parity/round14/README.md)。这不是本次文档修改重新执行了 104 项测试的声明。

### ARM 交叉编译

以下以已准备的 `zero3-glibc-cmake-py:latest` 工具链镜像为例，使用仓内 ARM glibc 工具链，静态链接，目标 Cortex-A7 / NEON / softfp。镜像准备不包含在该命令中；先完成上面的官方导出校验。

```bash
docker run --rm --platform linux/amd64 \
  -v "$PWD:/work" -w /work zero3-glibc-cmake-py:latest \
  cmake -S app -B build-arm \
    -DCMAKE_TOOLCHAIN_FILE=/work/tools/arm-glibc-toolchain.cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DNX5_IC_CFG_DIR=/data/nx5_conf/intercom \
    -DNX5_BUILD_TESTS=OFF -DNX5_WITH_THIRD_PARTY=ON \
    -DNX5_TP_ROOT=/work/third_party \
    -DNX5_BUILD_LVGL_UI=ON -DNX5_LVGL_SOURCE_DIR=/work/third_party/lvgl9 \
    -DNX5_EDITOR_GENERATED_DIR=/work/ui-editor-v11 \
    -DNX5_TEMPLATE_EXPORT_MODE=editor \
    -DNX5_BUILD_CAMERA=ON -DNX5_BUILD_VIDEO_HELPER=ON \
    -DNX5_BUILD_LEGACY_IC=ON -DNX5_TARGET_ORIGINAL_CIVET=ON \
    -DNX5_BUILD_NX5GUI=ON

docker run --rm --platform linux/amd64 \
  -v "$PWD:/work" -w /work zero3-glibc-cmake-py:latest \
  cmake --build build-arm -j6
```

版本字符串位于 `app/services/common/include/ic_version.h`。部署应先下载到临时文件、校验、原子替换并同步存储，再交给设备现有启动/看护链启动；不要直接覆盖运行中的程序或并行启动第二个 GUI。程序替换与 Web 资源更新是不同步骤，更新二进制不会自动更新全部浏览器资产。设备启动与看护说明见 [STARTUP_CHAIN](docs/STARTUP_CHAIN.md)，其中历史版本内容需结合当前装配核对。
