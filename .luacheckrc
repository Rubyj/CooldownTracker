std = "lua51"
max_line_length = false

-- Globals set by this addon
globals = {
    "CooldownTrackerDB",
    "SLASH_COOLDOWNTRACKER1",
    "SLASH_COOLDOWNTRACKER2",
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
    "SlashCmdList",
    -- Namespaces
    "C_Timer",
    "Settings",
}
