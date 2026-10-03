# Changelog

## v3.0.0 — ThermalCore
* Renamed IFOKNR - Thermal Manager → **ThermalCore** (module id `thermalcore`).
* New: auto game mode. A game from the list in the foreground switches to its own profile (default Gaming, per-game override), and back when it closes.
* New: bundled game list (521 packages); installed games are detected at install time.
* New: thermal guard now covers Performance as well as Gaming; the limit is selectable (60–85 °C, default 75 °C) and also pauses the GPU boost.
* New: optional notifications.
* New WebUI: live status card with SoC temperature, Profiles / Games / Settings tabs, dropdown menus, collapsible sections, service log, English + Arabic (RTL).
* Settings moved to `/data/adb/thermalcore` so they survive module updates; v2.x settings are migrated.
* The old `thermal_mode_manager` module and the conflicting `LickingT` module are marked for removal on install.
* Removed unused files (template `update.json`, stray images, `md3.js`).
