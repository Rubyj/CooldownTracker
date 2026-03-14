--------------------------------------------------------------------------------
-- Data.lua
-- Cooldown definitions. Add new healer abilities here — no other file needs
-- to change. Each entry requires:
--   id       - unique string key
--   class    - class name (display only)
--   name     - ability name (display only)
--   duration - cooldown length in seconds
--   icon     - WoW texture path (Interface\Icons\...)
--   r, g, b  - accent colour using WoW class colours (0-1 range)
--------------------------------------------------------------------------------

local AddonName, CT = ...

CT.COOLDOWNS = {
    -- -------------------------------------------------------------------------
    -- Druid (class colour: orange)
    -- -------------------------------------------------------------------------
    {
        id       = "druid_convoke",
        class    = "Druid",
        name     = "Convoke the Spirits",
        duration = 60,
        icon     = "Interface\\Icons\\ability_ardenweald_druid",
        r        = 1.0, g = 0.49, b = 0.04,
    },
    {
        id       = "druid_tranquility",
        class    = "Druid",
        name     = "Tranquility",
        duration = 180,
        icon     = "Interface\\Icons\\spell_nature_tranquility",
        r        = 1.0, g = 0.49, b = 0.04,
    },

    -- -------------------------------------------------------------------------
    -- Paladin (class colour: pink)
    -- -------------------------------------------------------------------------
    {
        id       = "paladin_avenging_wrath",
        class    = "Paladin",
        name     = "Avenging Wrath",
        duration = 120,
        icon     = "Interface\\Icons\\spell_holy_avenginewrath",
        r        = 0.96, g = 0.55, b = 0.73,
    },
    {
        id       = "paladin_aura_mastery",
        class    = "Paladin",
        name     = "Aura Mastery",
        duration = 120,
        icon     = "Interface\\Icons\\spell_holy_auramastery",
        r        = 0.96, g = 0.55, b = 0.73,
    },

    -- -------------------------------------------------------------------------
    -- Shaman (class colour: blue)
    -- -------------------------------------------------------------------------
    {
        id       = "shaman_ascendance",
        class    = "Shaman",
        name     = "Ascendance",
        duration = 180,
        icon     = "Interface\\Icons\\spell_fire_elementaldevastation",
        r        = 0.0, g = 0.44, b = 0.87,
    },
    {
        id       = "shaman_spirit_link",
        class    = "Shaman",
        name     = "Spirit Link Totem",
        duration = 180,
        icon     = "Interface\\Icons\\spell_shaman_spiritlink",
        r        = 0.0, g = 0.44, b = 0.87,
    },

    -- -------------------------------------------------------------------------
    -- Warrior (class colour: tan/gold)
    -- -------------------------------------------------------------------------
    {
        id       = "warrior_rallying_cry",
        class    = "Warrior",
        name     = "Rallying Cry",
        duration = 180,
        icon     = "Interface\\Icons\\ability_warrior_rallyingcry",
        r        = 0.78, g = 0.61, b = 0.23,
    },

    -- -------------------------------------------------------------------------
    -- Evoker (class colour: teal)
    -- -------------------------------------------------------------------------
    {
        id       = "evoker_zephyr",
        class    = "Evoker",
        name     = "Zephyr",
        duration = 120,
        icon     = "Interface\\Icons\\ability_evoker_hoverblack",
        r        = 0.2, g = 0.58, b = 0.5,
    },

    -- -------------------------------------------------------------------------
    -- Death Knight (class colour: red)
    -- -------------------------------------------------------------------------
    {
        id       = "dk_amz",
        class    = "Death Knight",
        name     = "Anti-Magic Zone",
        duration = 120,
        icon     = "Interface\\Icons\\spell_deathknight_antimagiczone",
        r        = 0.77, g = 0.12, b = 0.23,
    },
}
