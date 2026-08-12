# CooldownTracker

A World of Warcraft **Midnight** addon for raid leaders to manually track healer cooldowns.

Because Midnight restricts addons from reading real-time combat data, this addon takes a manual approach: your healers call out on comms, you click a spell row, and the addon counts down the cooldown for you.

## Features

- Click anywhere on a spell row to start or reset its timer
- Right-click a spell row to mark a player as dead (row goes grey); right-click again to restore (battle rez)
- Countdown display (`M:SS`) with colour-coded progress bar (green → yellow → red)
- Audible alert when a cooldown becomes ready (toggleable)
- Grid or vertical layout with configurable column count (1–9)
- Reorderable spells — use ▲/▼ arrows in the settings panel to set any display order
- Per-spell visibility toggles — hide abilities you're not tracking
- Lockable window — prevent accidental dragging mid-raid
- Draggable window with position saved between sessions
- In-game settings panel (Escape → Options → AddOns → Healer Cooldown Tracker)
- Tooltips showing cooldown details on hover
- Tracks Druid cooldowns: Convoke the Spirits, Tranquility, Innervate

## Installation

### Download a release

1. Go to the [Releases](../../releases) page and download the latest `CooldownTracker-*.zip`.
2. Unzip and copy the `CooldownTracker` folder into:
   ```
   World of Warcraft\_retail_\Interface\AddOns\CooldownTracker\
   ```
3. Launch WoW and enable **Healer Cooldown Tracker** in the AddOns list.

### From source

Clone the repo and symlink (or copy) the folder directly into your AddOns directory.

## Usage

| Command | Action |
|---|---|
| `/cdt` | Toggle the tracker window |
| `/cdt reset` | Reset all running timers |
| `/cdt columns N` | Set grid columns (1–9) |
| `/cdt settings` | Print reminder to open settings manually |

- Click any spell row to start the cooldown timer
- Click the same row again to reset a running timer
- Right-click any spell row to mark the player as **dead** (row goes grey, timer keeps running); right-click again to restore (battle rez)
- Drag the title bar to reposition; position saves on drag-stop
- Click the **lock icon** (top-right of title bar) to lock/unlock the window position

## Settings Panel

Open via **Escape → Options → AddOns → Healer Cooldown Tracker**:

- **Columns** — number of grid columns (1 = vertical stack)
- **Play sound when cooldown is ready** — toggle the audible alert
- **Class Roster** — set how many of each class are in the raid; abilities duplicate per player (up to 5)
- **Show checkboxes** — hide individual spells from the tracker
- **Spell order** — use ▲/▼ arrows next to each spell to reorder them; Reset Order restores the default sequence
- **Cooldown durations** — override any ability's cooldown in seconds; revert with the Default button

## Adding More Cooldowns

Open `Data.lua` and add a new entry to the `CT.COOLDOWNS` table:

```lua
{
    id              = "priest_divine_hymn",  -- unique key
    class           = "Priest",
    name            = "Divine Hymn",
    duration        = 180,                   -- seconds (overrideable in settings)
    defaultDuration = 180,                   -- used by the "Default" reset button
    icon            = "Interface\\Icons\\spell_holy_divinehymn",
    r               = 1.0, g = 1.0, b = 1.0, -- accent colour (RGB 0-1)
},
```

No other file needs to change.

## File Structure

```
CooldownTracker/
├── CooldownTracker.toc             — Addon manifest & metadata
├── Data.lua                        — Cooldown definitions (edit this to add abilities)
├── UI.lua                          — Frame, row widgets, timer rendering
├── Settings.lua                    — In-game options panel
├── Core.lua                        — Init, events, slash commands
├── .github/workflows/ci.yml        — Luacheck on push to main and all PRs
├── .github/workflows/release.yml   — Package and publish release on version tag
├── .github/pull_request_template.md — PR checklist template
├── .luacheckrc                     — Luacheck config (WoW globals whitelist)
├── .pkgmeta                        — BigWigs packager metadata
├── AGENTS.md                       — AI agent coding guidelines
└── README.md                       — This file
```

## Releases & CI

Releases are built automatically by GitHub Actions using the [BigWigs packager](https://github.com/BigWigsMods/packager).

- **Pull request or push to `main`** — runs [luacheck](https://github.com/mpeterv/luacheck) static analysis on all Lua files.
- **Push a version tag** — runs luacheck, packages the addon, and publishes a GitHub Release with a downloadable zip.

To ship a release:

```bash
git tag -a v1.2.0 -m "Version 1.2.0"
git push origin v1.2.0
```

The zip will appear on the [Releases](../../releases) page within a minute or two.

## Compatibility

Tested on **World of Warcraft: Midnight** (Interface 120100). Fully compliant with Midnight's addon restrictions — no combat log reading, no addon messaging.
