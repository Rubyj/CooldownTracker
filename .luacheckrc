std = "lua51"
max_line_length = false

ignore = {
    "211/AddonName", -- unused variable: idiomatic WoW pattern (local AddonName, CT = ...)
    "212/self",      -- unused argument: WoW callbacks always receive self; closures use it implicitly
    "432/self",      -- shadowing upvalue: nested WoW callbacks each receive their own self
}

-- Globals set by this addon
globals = {
    "CooldownTrackerDB",
    "SLASH_COOLDOWNTRACKER1",
    "SLASH_COOLDOWNTRACKER2",
    "SlashCmdList", -- addon writes SlashCmdList["COOLDOWNTRACKER"]
}

-- WoW API globals (read-only from this addon's perspective)
read_globals = {
    -- Core API
    "CreateFrame",
    "GetTime",
    "PlaySound",
    -- Constants & tables
    "SOUNDKIT",
    "UIParent",
    "GameTooltip",
    -- Namespaces
    "C_Timer",
    "Settings",
}
