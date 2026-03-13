# CooldownTracker

A World of Warcraft **Midnight** addon for raid leaders to manually track healer cooldowns.

Because Midnight restricts addons from reading real-time combat data, this addon takes a manual approach: your healers call out on comms, you click a button, and the addon counts down the cooldown for you.

## Features

- One-click timer start/reset per ability
- Countdown display (`M:SS`) with colour-coded progress bar (green → yellow → red)
- Audible alert when a cooldown becomes available
- Draggable window with position saved between sessions
- Tooltips showing cooldown details on hover

## Installation

1. Copy the `CooldownTracker` folder into:
   ```
   World of Warcraft\_retail_\Interface\AddOns\CooldownTracker\
   ```
2. Launch WoW and enable **Healer Cooldown Tracker** in the AddOns list.

## Usage

| Command | Action |
|---|---|
| `/cdt` | Toggle the tracker window |
| `/cdt reset` | Reset all running timers |

- Click **Used** when a healer uses an ability → timer starts
- Click **Reset** to cancel a running timer early
- Drag the title bar to reposition; position saves on drag-stop

## Adding More Cooldowns

Open `Data.lua` and add a new entry to the `CT.COOLDOWNS` table:

```lua
{
    id       = "priest_divine_hymn",  -- unique key
    class    = "Priest",
    name     = "Divine Hymn",
    duration = 180,                   -- seconds
    icon     = "Interface\\Icons\\spell_holy_divinehymn",
    r        = 1.0, g = 0.8, b = 0.2, -- accent colour (RGB 0-1)
},
```

No other file needs to change.

## File Structure

```
CooldownTracker/
├── CooldownTracker.toc   — Addon manifest & metadata
├── Data.lua              — Cooldown definitions (edit this to add abilities)
├── UI.lua                — Frame, row widgets, timer rendering
├── Core.lua              — Init, events, slash commands
└── README.md             — This file
```

## Compatibility

Tested on **World of Warcraft: Midnight** (Interface 120001). Fully compliant with Midnight's addon restrictions — no combat log reading, no addon messaging.
