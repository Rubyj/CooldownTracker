--------------------------------------------------------------------------------
-- Core.lua
-- Addon bootstrap: initialises shared state, handles ADDON_LOADED to wire up
-- the UI, and registers slash commands.
--
-- Slash commands:
--   /cdt              — toggle the tracker window
--   /cdt reset        — reset all running timers
--   /cdt settings     — open the settings panel
--   /cdt columns N    — set grid columns (1-9)
--------------------------------------------------------------------------------

local AddonName, CT = ...

-- Shared runtime state (read by UI.lua's UpdateRow via CT.activeTimers)
CT.activeTimers = {}

-- ---------------------------------------------------------------------------
-- Event handling
-- ---------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == AddonName then
        -- Initialise saved variables
        CooldownTrackerDB = CooldownTrackerDB or {}
        CooldownTrackerDB.classCounts     = CooldownTrackerDB.classCounts or {}
        CooldownTrackerDB.disabledSpells  = CooldownTrackerDB.disabledSpells or {}
        CooldownTrackerDB.spellOrder      = CooldownTrackerDB.spellOrder or {}
        if CooldownTrackerDB.playSoundOnReady == nil then
            CooldownTrackerDB.playSoundOnReady = true
        end
        if CooldownTrackerDB.frameLocked == nil then
            CooldownTrackerDB.frameLocked = false
        end
        -- Register the settings panel (applies saved durations to COOLDOWNS)
        CT:InitSettings()
        -- Expand cooldowns before building UI (so copies inherit saved durations)
        CT:BuildExpandedCooldowns()
        -- Build the UI (defined in UI.lua) then restore the saved position
        CT:BuildUI()
        CT:RestorePosition()
    end
end)

-- ---------------------------------------------------------------------------
-- Slash commands
-- ---------------------------------------------------------------------------
SLASH_COOLDOWNTRACKER1 = "/cdt"
SLASH_COOLDOWNTRACKER2 = "/cooldowntracker"
SlashCmdList["COOLDOWNTRACKER"] = function(msg)
    local cmd = msg and msg:lower():match("^%s*(.-)%s*$") or ""
    if cmd == "reset" then
        for _, cd in ipairs(CT.expandedCooldowns) do
            CT.activeTimers[cd.id] = nil
        end
        CT.deadStates = {}
        CT:UpdateAllRows()
        print("|cffaaddff[CooldownTracker]|r All timers reset.")
    elseif cmd == "settings" then
        CT:OpenSettings()
    elseif cmd:match("^columns%s+(%d+)$") then
        local n = tonumber(cmd:match("^columns%s+(%d+)$"))
        if n and n >= 1 and n <= 9 then
            CooldownTrackerDB.columns = n
            CT:LayoutRows()
            print("|cffaaddff[CooldownTracker]|r Columns set to " .. n .. ".")
        else
            print("|cffaaddff[CooldownTracker]|r Usage: /cdt columns <1-9>")
        end
    else
        if CT.mainFrame:IsShown() then
            CT.mainFrame:Hide()
        else
            CT.mainFrame:Show()
        end
    end
end
