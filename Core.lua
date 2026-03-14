--------------------------------------------------------------------------------
-- Core.lua
-- Addon bootstrap: initialises shared state, handles ADDON_LOADED to wire up
-- the UI, and registers slash commands.
--
-- Slash commands:
--   /cdt              — toggle the tracker window
--   /cdt reset        — reset all running timers
--   /cdt settings     — open the settings panel
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
        -- Build the UI (defined in UI.lua) then restore the saved position
        CT:BuildUI()
        CT:RestorePosition()
        -- Register the settings panel (defined in Settings.lua)
        CT:InitSettings()
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
        for _, cd in ipairs(CT.COOLDOWNS) do
            CT.activeTimers[cd.id] = nil
        end
        print("|cffaaddff[CooldownTracker]|r All timers reset.")
    elseif cmd == "settings" then
        CT:OpenSettings()
    else
        if CT.mainFrame:IsShown() then
            CT.mainFrame:Hide()
        else
            CT.mainFrame:Show()
        end
    end
end
