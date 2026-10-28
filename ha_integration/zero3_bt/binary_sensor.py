"""面板在线状态(心跳 30s 间隔,180s 超时判定离线)。"""
from __future__ import annotations

import time

from homeassistant.components.binary_sensor import BinarySensorEntity
from homeassistant.config_entries import ConfigEntry
from homeassistant.core import HomeAssistant
from homeassistant.helpers.device_registry import DeviceEntryType, DeviceInfo
from homeassistant.helpers.entity_platform import AddEntitiesCallback

from . import DOMAIN


async def async_setup_entry(
    hass: HomeAssistant, entry: ConfigEntry, async_add_entities: AddEntitiesCallback
) -> bool:
    async_add_entities([Zero3BtOnlineSensor(hass, entry)])
    return True


class Zero3BtOnlineSensor(BinarySensorEntity):
    _attr_name = "面板在线"
    _attr_icon = "mdi:bluetooth-connect"

    def __init__(self, hass: HomeAssistant, entry: ConfigEntry) -> None:
        self._entry = entry
        self._attr_unique_id = "zero3_bt_online"
        self._attr_device_info = DeviceInfo(
            identifiers={(DOMAIN, "gateway")},
            name="Zero3 面板蓝牙代理",
            manufacturer="Zero3",
            entry_type=DeviceEntryType.SERVICE,
        )

    @property
    def is_on(self) -> bool | None:
        stats = self.hass.data.get(DOMAIN, {}).get(self._entry.entry_id, {})
        last = stats.get("last_seen")
        return last is not None and (time.time() - last) < 180

    @property
    def extra_state_attributes(self):
        stats = self.hass.data.get(DOMAIN, {}).get(self._entry.entry_id, {})
        return {
            "messages": stats.get("msgs", 0),
            "forwarded": stats.get("ok", 0),
            "last_seen": stats.get("last_seen"),
        }
