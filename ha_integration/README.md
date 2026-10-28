# 零洞 Zero3 蓝牙代理 · Home Assistant 集成(zero3_bt)

把 NX5 面板上的蓝牙代理(btproxy)接入 Home Assistant 原生蓝牙生态:面板持续扫描
周围 BLE 广播,经 MQTT 上报(`btproxy/adv/<网关MAC>`),本集成在 HA 中注册为
**远程蓝牙扫描器**,支持设备发现/跟踪,多个面板网关自动注册(心跳发现)。

## 前置条件

1. NX5 面板(1.0.162+)Web 控制台 → 系统设置 →「📶 蓝牙代理」已启用,并配置了
   与 HA 相同的 MQTT broker(地址/用户名/密码)。
2. HA 已配置 **MQTT 集成**并连接到该 broker。

## 安装

1. 下载本目录打包的 `zero3_bt_ha_integration.zip`(Release 资产附带);
2. 解压,把 `zero3_bt/` 放入 HA 配置目录 `custom_components/zero3_bt/`;
   ```
   config/
   └── custom_components/
       └── zero3_bt/
           ├── __init__.py
           ├── manifest.json
           └── ...
   ```
3. 重启 HA;
4. 设置 → 设备与服务 → 添加集成 → 搜索「零洞蓝牙代理 / Zero3 Bluetooth Proxy」;
5. 添加后每个在线网关会出现一个蓝牙扫描器实体 + 在线二进制传感器
   (实体 ID 前缀 `btproxy_<网关MAC>`)。

## 验证

- 集成卡片里网关显示在线(心跳 30s 超时判离线);
- HA 开发者工具 → 蓝牙 → 能看到来自面板网关的广播源;
- 手机蓝牙靠近面板,HA 蓝牙集成可发现新设备。

## 说明

- 面板端配置/状态查看:Web 控制台「📶 蓝牙代理」卡片(转发计数实时刷新);
- 蓝牙芯片固件由面板侧管理,无需人工干预;若长期无数据请在 Web 卡片重启代理。
