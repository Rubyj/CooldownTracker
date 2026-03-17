# CooldownTracker - AI Agent Instructions

Welcome! This document outlines the standards, conventions, and preferences for developing the CooldownTracker World of Warcraft Addon. Please adhere to these guidelines when suggesting or writing code.

## 🎯 Project Purpose
CooldownTracker is a lightweight, manual tracking tool for Raid Leaders in World of Warcraft (Midnight 12.0+). It displays a customizable grid/column of major healer cooldowns. The raid leader manually clicks abilities to start and reset their timers. It does **not** automate tracking based on combat log events, keeping the addon fast, simple, and strictly within Blizzard's UI terms of service.

## 🏗️ Architecture & File Structure
The addon is split into modular components, sharing a single private namespace (`CT`).
- `CooldownTracker.toc`: The manifest. Controls load order (critical).
- `Data.lua`: Defines the base abilities (`CT.COOLDOWNS`), default durations, icons, and class colors.
- `UI.lua`: Handles rendering the main tracker window, row layouts (grid vs vertical), and the per-frame `OnUpdate` timer loop.
- `Settings.lua`: Implements the in-game options panel (Escape -> Options -> AddOns) using the modern `Settings` API. Handles SavedVariables overrides.
- `Core.lua`: The bootstrap file. Handles `ADDON_LOADED`, slash commands (`/cdt`), and initializes the UI and Settings.

## 📜 Coding Standards & Conventions
1. **Private Namespace:** Always use the addon's private namespace passed by the WoW client on load. Do not pollute the global environment.
   ```lua
   local AddonName, CT = ...
   -- CT is the shared table across all files
   ```
2. **SavedVariables:** Use `CooldownTrackerDB` for persistence. Initialize it in `ADDON_LOADED` in `Core.lua`. Current keys:
   | Key | Type | Default | Purpose |
   |---|---|---|---|
   | `columns` | number | `1` | Grid column count (1–9) |
   | `classCounts` | table | `{}` | Per-class player counts (1–5) |
   | `customDurations` | table | `{}` | Per-spell duration overrides (seconds) |
   | `disabledSpells` | table | `{}` | Set of spell IDs hidden from tracker |
   | `playSoundOnReady` | boolean | `true` | Play alert sound on cooldown expiry |
   | `frameLocked` | boolean | `false` | Lock window position (disable drag) |
   | `point`, `relPoint`, `x`, `y` | mixed | nil | Saved window position |
3. **Slash Commands:** Register slash commands via the `SlashCmdList` table. Handle arguments cleanly.
4. **No Third-Party Libraries:** The addon intentionally does not use Ace3 or other framework libraries to remain lightweight. Rely on the standard WoW API.

## ⚠️ Critical WoW API Anti-Patterns (Taint Avoidance)
World of Warcraft has a strict "taint" system for UI frames. Violating these rules will cause the addon to break the user's UI during combat.
1. **Dynamic Frame Creation:** Do NOT use `CreateFrame()` or `SetParent()` dynamically in response to user input (e.g., inside an `OnTextChanged` or `OnClick` handler). 
   - *Fix:* Pre-allocate a pool of frames at `ADDON_LOADED` time. Show/Hide and reconfigure existing frames.
2. **Rebinding Secure Scripts:** Do NOT call `SetScript("OnClick", ...)` on protected templates (like `UIPanelButtonTemplate`) at runtime after initial creation. 
   - *Fix:* Set the script once during creation. Have the script read data dynamically from the frame itself (e.g., `local cd = self:GetParent().cd`).
3. **Settings API:** The `Settings.OpenToCategory()` function is fully protected in The War Within/Midnight.
   - *Fix:* Do not attempt to programmatically open the Settings menu from slash commands. Instruct the user via chat text to open it manually.

## 🎨 UI & Layout Preferences
- **Grid vs Vertical:** The UI supports both a wide-row vertical layout (columns = 1) and a compact square-card grid layout (columns 2-9). Use `CT:LayoutRows()` to reflow.
- **Clickable Rows:** Each spell row is a `Button` frame (not a plain `Frame`). The entire row is the click target — there is no separate "Used"/"Reset" button. `OnClick` is set once at creation time and reads `row.cd` dynamically to avoid taint.
- **Font:** Use `Fonts\\FRIZQT__.TTF` with an `"OUTLINE"` flag for clear, readable text in the tracker.
- **Backdrops:** Use the `BackdropTemplate` mixin for frames requiring backgrounds/borders. Main frame backdrop alpha is `0.55` (translucent); title bar is `0.65`.
- **Title Bar Controls:** The title bar contains a close button (`UIPanelCloseButton`, 18px) and a lock toggle button (plain `Button`, 32px) anchored to its left. The lock button uses `Interface\\BUTTONS\\LockButton-Locked-Up` / `LockButton-Unlocked-Up` textures and toggles `CooldownTrackerDB.frameLocked`. Always guard `OnDragStart` with a `frameLocked` check to avoid a Lua error when the frame is not movable.
