"""Zero3 面板蓝牙代理 — 自动发现版(2026-10-24)。

零配置:监听 btproxy/status 心跳(面板开机自报 MAC),
有心跳即自动注册远程蓝牙扫描器;用户在 UI 点"添加"即可,无需填任何参数。
广播经 BaseHaRemoteScanner._async_on_advertisement 进 HA 蓝牙原生管道。
"""
from __future__ import annotations

import asyncio
import binascii
import logging
import time

from bleak import BleakError

from homeassistant.core import HomeAssistant, callback as hass_callback
from homeassistant.config_entries import ConfigEntry
from homeassistant.const import EVENT_HOMEASSISTANT_STOP
from homeassistant.components import mqtt
from homeassistant.components.bluetooth import (
    BaseHaRemoteScanner,
    async_register_scanner,
)
from homeassistant.helpers.device_registry import DeviceEntryType, DeviceInfo

from .const import DOMAIN

_LOGGER = logging.getLogger(__name__)
PLATFORMS: list[str] = ["binary_sensor"]

DEFAULT_TOPIC_ADV = "btproxy/adv"
TOPIC_STATUS = "btproxy/status"


class Zero3BtScanner(BaseHaRemoteScanner):
    """面板远程扫描器:MQTT 侧回调喂 _async_on_advertisement。"""

    def __init__(self, gateway_mac: str) -> None:
        super().__init__(source=gateway_mac, adapter=gateway_mac,
                         connector=None, connectable=False)
        self._count = 0

    @property
    def forwarded(self) -> int:
        return self._count

    @hass_callback
    def on_mqtt_advertisement(self, payload: dict) -> bool:
        """btproxy JSON: {mac, rssi, name?, adv hex, ts} → 喂 HA。"""
        try:
            address = str(payload["mac"]).upper()
            rssi = int(payload["rssi"])
            raw = binascii.unhexlify(payload["adv"])
            ts = float(payload.get("ts") or time.time())
        except (KeyError, ValueError, binascii.Error):
            return False

        local_name: str | None = payload.get("name") or None
        service_uuids: list[str] = []
        service_data: dict[str, bytes] = {}
        manufacturer_data: dict[int, bytes] = {}
        tx_power = None
        i = 0
        while i + 1 < len(raw):
            ln = raw[i]
            if ln == 0 or i + 1 + ln > len(raw):
                break
            t = raw[i + 1]
            seg = raw[i + 2 : i + 1 + ln]
            if t in (0x08, 0x09) and seg and local_name is None:
                local_name = seg.decode("utf-8", "replace")
            elif t == 0xFF and len(seg) >= 2:
                manufacturer_data[int.from_bytes(seg[0:2], "little")] = seg[2:]
            elif t in (0x02, 0x03):
                for k in range(0, len(seg) - 1, 2):
                    service_uuids.append(f"{seg[k+1]:02x}{seg[k]:02x}")
            elif t == 0x16 and len(seg) >= 2:
                u = int.from_bytes(seg[0:2], "little")
                service_data[f"0000{u:04x}-0000-1000-8000-00805f9b34fb"] = seg[2:]
            elif t == 0x0A and len(seg) == 1:
                tx_power = seg[0] - 256 if seg[0] > 127 else seg[0]
            i += 1 + ln

        monotonic = time.monotonic() - (time.time() - ts)
        self._async_on_advertisement(
            address, rssi, local_name, service_uuids, service_data,
            manufacturer_data, tx_power, {"address_type": "public"}, monotonic,
        )
        self._count += 1
        return True


async def async_setup_entry(hass: HomeAssistant, entry: ConfigEntry) -> bool:
    """启动:订阅心跳等网关出现 → 注册 scanner;之后订阅广播。"""
    topic_adv = entry.data.get("topic_adv", DEFAULT_TOPIC_ADV)
    entry_id = entry.entry_id

    hass.data.setdefault(DOMAIN, {})[entry_id] = {}
    stats = {"msgs": 0, "ok": 0}
    hass.data[DOMAIN][entry_id] = stats

    unsub_status: list = []
    scanners: dict[str, Zero3BtScanner] = {}      # 多代理:mac → scanner

    def _register_scanner(gateway_mac: str) -> None:
        if gateway_mac in scanners:
            return
        scanner = Zero3BtScanner(gateway_mac)
        scanners[gateway_mac] = scanner
        entry.async_on_unload(
            async_register_scanner(
                hass, scanner,
                source_domain=DOMAIN,
                source_model="NX5 panel btproxy",
                source_config_entry_id=entry_id,
            )
        )
        scanner.async_setup()
        _LOGGER.info("zero3_bt: gateway %s discovered, scanner registered (%d total)",
                     gateway_mac, len(scanners))

    async def on_status(msg) -> None:
        """心跳:自动发现网关 MAC(首次收到即注册;已注册则刷新在线时间)。"""
        import json
        _LOGGER.debug("zero3_bt status topic msg: %s", msg.payload[:120])
        try:
            payload = json.loads(msg.payload)
            mac = str(payload["gateway_mac"]).upper()
        except (ValueError, KeyError):
            return
        _LOGGER.info("zero3_bt heartbeat from %s (known=%s)", mac, mac in scanners)
        stats["last_seen"] = time.time()
        _register_scanner(mac)          # 幂等:同 MAC 只注册一次;新面板自动加

    async def on_adv(msg) -> None:
        import json
        stats["msgs"] += 1
        try:
            payload = json.loads(msg.payload)
        except ValueError:
            return
        # 多代理:广播帧按 payload.mac 已是 BLE 设备地址,归属网关用"最后活跃的心跳"太粗;
        # 但 MQTT 消息本身不带网关标识——约定 btproxy 发布到 btproxy/adv/<网关MAC>,
        # 兼容旧单主题(单面板场景)。
        t = getattr(msg, "topic", "")
        gw = t.rsplit("/", 1)[-1] if t.count("adv/") else ""
        if gw and gw.count(":") == 5:
            scanner = scanners.get(gw.upper()) or scanners.get(gw)
            if scanner is None:
                # 广播先于该网关心跳:先占位注册,心跳到达时复用
                if gw.count(":") == 5:
                    _register_scanner(gw.upper())
                    scanner = scanners.get(gw.upper())
        else:
            scanner = next(iter(scanners.values())) if scanners else None
        if scanner is None:
            return
        try:
            scanner.on_mqtt_advertisement(payload)
            stats["ok"] += 1
            stats["last_seen"] = time.time()
        except (BleakError, ValueError) as ex:
            _LOGGER.debug("adv parse fail: %s", ex)
        if stats["ok"] % 50 == 1:
            _LOGGER.info("zero3_bt: %d advs forwarded (of %d msgs)",
                         stats["ok"], stats["msgs"])

    unsub_status.append(await mqtt.async_subscribe(hass, TOPIC_STATUS, on_status, 0))
    unsub_adv = await mqtt.async_subscribe(hass, topic_adv + "/#", on_adv, 0)   # 通配:多代理 per-gateway 主题

    async def _stop(_ev) -> None:
        for u in unsub_status:
            u()
    entry.async_on_unload(hass.bus.async_listen_once(EVENT_HOMEASSISTANT_STOP, _stop))
    entry.async_on_unload(unsub_adv)
    for u in unsub_status:
        entry.async_on_unload(u)

    await hass.config_entries.async_forward_entry_setups(entry, PLATFORMS)
    _LOGGER.info("zero3_bt ready: waiting for gateway heartbeat on %s", TOPIC_STATUS)
    return True


async def async_unload_entry(hass: HomeAssistant, entry: ConfigEntry) -> bool:
    return await hass.config_entries.async_unload_platforms(entry, PLATFORMS)
