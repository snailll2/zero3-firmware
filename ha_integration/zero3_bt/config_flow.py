"""Zero3 面板蓝牙代理 — 配置流(零参数:点确认即完成)。"""
from __future__ import annotations

import voluptuous as vol
from homeassistant import config_entries
from homeassistant.data_entry_flow import FlowResult

from .const import DOMAIN, DEFAULT_TOPIC_ADV


class Zero3BtFlowHandler(config_entries.ConfigFlow, domain=DOMAIN):
    VERSION = 1

    async def async_step_user(self, user_input=None) -> FlowResult:
        """一步完成:无必填参数(高级用户可改主题)。"""
        if user_input is None:
            schema = vol.Schema(
                {
                    vol.Optional("topic_adv", default=DEFAULT_TOPIC_ADV): str,
                }
            )
            return self.async_show_form(
                step_id="user",
                data_schema=schema,
                description_placeholders={"topic_status": "btproxy/status"},
            )
        # 单实例:已存在条目则拒绝重复添加
        for e in self._async_current_entries():
            if e.domain == DOMAIN:
                return self.async_abort(reason="already_configured")
        return self.async_create_entry(
            title="Zero3 面板蓝牙代理",
            data={"topic_adv": user_input.get("topic_adv", DEFAULT_TOPIC_ADV)},
        )
