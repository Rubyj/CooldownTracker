--------------------------------------------------------------------------------
-- Data.lua
-- Cooldown definitions. Add new healer abilities here — no other file needs
-- to change. Each entry requires:
--   id       - unique string key
--   class    - class name (display only)
--   name     - ability name (display only)
--   duration - cooldown length in seconds
--   icon     - WoW texture path (Interface\Icons\...)
--   r, g, b  - accent colour (0-1 range)
--------------------------------------------------------------------------------

local AddonName, CT = ...

CT.COOLDOWNS = {
    -- -------------------------------------------------------------------------
    -- Druid
    -- -------------------------------------------------------------------------
    {
        id       = "druid_convoke",
        class    = "Druid",
        name     = "Convoke the Spirits",
        duration = 60,
        icon     = "Interface\\Icons\\ability_ardenweald_druid",
        r        = 0.4, g = 0.8, b = 0.4,
    },
    {
        id       = "druid_tranquility",
        class    = "Druid",
        name     = "Tranquility",
        duration = 180,
        icon     = "Interface\\Icons\\spell_nature_tranquility",
        r        = 0.4, g = 0.6, b = 1.0,
    },
}
