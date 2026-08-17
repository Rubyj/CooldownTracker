# Healer Cooldown Tracker

A lightweight, manual cooldown tracker designed for **raid leaders** in World of Warcraft: Midnight.

Midnight restricts addons from reading real-time combat data — so this addon takes a simple, manual approach: your healers call out on comms, you click a spell row, and the addon counts down the cooldown for you. No combat log automation, no addon messaging, no taint.

---

## Features

- **Click to track** — click anywhere on a spell row to start the timer; click again to reset
- **Dead/Alive toggle** — right-click to mark a player as dead (row goes grey); right-click again for battle rez
- **Countdown timer** — clean `M:SS` display with a colour-coded progress bar (green → yellow → red)
- **Sound alerts** — audible notification when a cooldown becomes ready (toggleable)
- **Flexible layout** — grid or vertical layout with configurable column count (1–9)
- **Reorderable spells** — drag spells into your preferred order via the settings panel
- **Per-class player counts** — set how many of each class are in your raid (1–5); abilities duplicate per player
- **Spell visibility** — hide abilities you're not tracking
- **Lockable window** — prevent accidental dragging mid-encounter
- **Persistent position** — window location saves between sessions
- **Tooltips** — hover over any row for cooldown details

## Tracked Cooldowns

| Class | Abilities |
|---|---|
| **Druid** | Convoke the Spirits, Tranquility, Innervate |
| **Paladin** | Avenging Wrath, Aura Mastery |
| **Shaman** | Ascendance, Spirit Link Totem |
| **Priest** | Apotheosis, Divine Hymn, Halo |
| **Evoker** | Zephyr, Spatial Paradox |
| **Warrior** | Rallying Cry |
| **Death Knight** | Anti-Magic Zone |
| **Demon Hunter** | Darkness |

## Usage

| Command | Action |
|---|---|
| `/cdt` | Toggle the tracker window |
| `/cdt reset` | Reset all running timers |
| `/cdt columns N` | Set grid columns (1–9) |

Open the settings panel via **Escape → Options → AddOns → Healer Cooldown Tracker** to configure columns, sound alerts, class roster, spell order, and custom cooldown durations.

## Adding More Cooldowns

Open `Data.lua` and add a new entry to the cooldowns table — no other file needs to change. See the [GitHub README](https://github.com/Rubyj/CooldownTracker) for details.

---

*Fully compatible with World of Warcraft: Midnight (Interface 120100). Zero automation — 100% Blizzard ToS compliant.*
