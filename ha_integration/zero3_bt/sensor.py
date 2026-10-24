"""调试传感器:转发计数/最近设备。"""
from __future__ import annotations

from homeassistant.components.sensor import SensorEntity
from homeassistant.config_entries import ConfigEntry
from homeassistant.core import HomeAssistant
from homeassistant.helpers.device_registry import DeviceEntryType, DeviceInfo
from homeassistant.helpers.entity_platform import AddEntitiesCallback
from homeassistant.helpers.update_coordinator import CoordinatorEntity

from . import DOMAIN, CONNECTOR


async def async_setup_entry(
    hass: HomeAssistant, entry: ConfigEntry, async_add_entities: AddEntitiesCallback
) -> bool:
    mac = entry.data["gateway_mac"].upper()
    async_add_entities([Zero3BtStatsSensor(hass, entry, mac)])
    return True


class Zero3BtStatsSensor(SensorEntity):
    _attr_name = "转发广播计数"
    _attr_icon = "mdi:bluetooth-transfer"

    def __init__(self, hass, entry, mac):
        self._mac = mac
        self._attr_unique_id = f"zero3_bt_fwd_{mac.replace(':', '')}"
        self._attr_device_info = DeviceInfo(
            identifiers={("zero3_bt", f"scanner_{mac}")},
            entry_type=DeviceEntryType.SERVICE,
        )
        self._n = 0

    async def async_update(self):
        # 简化:计数保存在 hass.data,由 __init__ 维护(此处读最新)
        data = self.hass.data.get(DOMAIN, {})
        self._n = data.get("fwd_count", 0)

    @property
    def native_value(self):
        return self._n
