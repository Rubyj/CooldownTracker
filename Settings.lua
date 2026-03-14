--------------------------------------------------------------------------------
-- Settings.lua
-- In-game configuration panel for CooldownTracker, registered with WoW's
-- modern Settings API (Escape -> Options -> AddOns -> Healer Cooldown Tracker).
--
-- Exposes:
--   CT:InitSettings()  - called once on ADDON_LOADED to apply saved values
--                        and register the panel
--   CT:OpenSettings()  - programmatically opens the panel (slash command)
--------------------------------------------------------------------------------

local AddonName, CT = ...

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

-- Returns the effective duration for a cooldown: saved custom value or default.
local function GetEffectiveDuration(cd)
    local custom = CooldownTrackerDB and CooldownTrackerDB.customDurations
    return (custom and custom[cd.id]) or cd.defaultDuration
end

-- Applies all saved custom durations to the live CT.COOLDOWNS table.
local function ApplyCustomDurations()
    local custom = CooldownTrackerDB.customDurations or {}
    for _, cd in ipairs(CT.COOLDOWNS) do
        cd.duration = custom[cd.id] or cd.defaultDuration
    end
end

-- ---------------------------------------------------------------------------
-- Panel construction
-- ---------------------------------------------------------------------------

local PANEL_ROW_HEIGHT = 42
local PANEL_ROW_PAD    = 2
local ICON_SIZE        = 28
local EDIT_WIDTH       = 64
local CONTENT_WIDTH    = 520  -- fixed width; the Settings canvas is ~550px

local function CreateSettingsPanel()
    local panel = CreateFrame("Frame")
    panel.name  = "Healer Cooldown Tracker"

    -- ----- Header -----------------------------------------------------------
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("|cffaaddffHealer Cooldown Tracker|r — Settings")

    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    desc:SetWidth(CONTENT_WIDTH)
    desc:SetText("Override cooldown durations to match your raiders' current talents.\nPress Enter in a duration box to confirm. Changes apply immediately.")
    desc:SetJustifyH("LEFT")

    -- Column header labels
    local hdrAbility = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    hdrAbility:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", ICON_SIZE + 12, -10)
    hdrAbility:SetText("Ability")
    hdrAbility:SetTextColor(0.7, 0.7, 0.7)

    local hdrDur = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    hdrDur:SetPoint("LEFT", hdrAbility, "LEFT", 260, 0)
    hdrDur:SetText("Cooldown (seconds)")
    hdrDur:SetTextColor(0.7, 0.7, 0.7)

    local divider = panel:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT",  hdrAbility, "BOTTOMLEFT", -ICON_SIZE - 12, -4)
    divider:SetWidth(CONTENT_WIDTH)
    divider:SetColorTexture(0.3, 0.3, 0.4, 0.6)

    -- ----- Scroll frame -----------------------------------------------------
    local scrollFrame = CreateFrame("ScrollFrame", "CTSettingsScrollFrame", panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", 0, -6)
    scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 50)

    local contentHeight = #CT.COOLDOWNS * (PANEL_ROW_HEIGHT + PANEL_ROW_PAD)
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(CONTENT_WIDTH, contentHeight)
    scrollFrame:SetScrollChild(content)

    -- Track edit boxes so Reset All can update them
    local editBoxes = {}

    -- Populates every edit box from the current effective duration.
    -- Called on creation and via OnShow.
    local function RefreshAllEditBoxes()
        for _, cd in ipairs(CT.COOLDOWNS) do
            if editBoxes[cd.id] then
                editBoxes[cd.id]:SetText(tostring(GetEffectiveDuration(cd)))
            end
        end
    end

    for i, cd in ipairs(CT.COOLDOWNS) do
        local yOff = -((i - 1) * (PANEL_ROW_HEIGHT + PANEL_ROW_PAD))

        local row = CreateFrame("Frame", nil, content)
        row:SetHeight(PANEL_ROW_HEIGHT)
        row:SetPoint("TOPLEFT",  content, "TOPLEFT",  0, yOff)
        row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, yOff)

        -- Alternating background
        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(row)
        if i % 2 == 0 then
            bg:SetColorTexture(0.12, 0.12, 0.14, 0.4)
        else
            bg:SetColorTexture(0.07, 0.07, 0.09, 0.25)
        end

        -- Accent left strip
        local strip = row:CreateTexture(nil, "BACKGROUND")
        strip:SetSize(3, PANEL_ROW_HEIGHT)
        strip:SetPoint("LEFT", row, "LEFT", 0, 0)
        strip:SetColorTexture(cd.r, cd.g, cd.b, 0.9)

        -- Icon
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(ICON_SIZE, ICON_SIZE)
        icon:SetPoint("LEFT", row, "LEFT", 8, 0)
        icon:SetTexture(cd.icon)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        -- Ability name
        local nameLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameLabel:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, -2)
        nameLabel:SetText(cd.name)
        nameLabel:SetTextColor(1, 1, 1)

        -- Class tag
        local classLabel = row:CreateFontString(nil, "OVERLAY")
        classLabel:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 8, 2)
        classLabel:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
        classLabel:SetText(cd.class)
        classLabel:SetTextColor(cd.r, cd.g, cd.b)

        -- Duration edit box — built manually (no template) to avoid
        -- InputBoxTemplate's OnShow clearing our text.
        local editBox = CreateFrame("EditBox", "CTSettingsEdit_" .. cd.id, row, "BackdropTemplate")
        editBox:SetSize(EDIT_WIDTH, 24)
        editBox:SetPoint("LEFT", row, "LEFT", 280, 0)
        editBox:SetAutoFocus(false)
        editBox:SetMaxLetters(4)
        editBox:SetFontObject("ChatFontNormal")
        editBox:SetJustifyH("CENTER")
        if editBox.SetBackdrop then
            editBox:SetBackdrop({
                bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile     = true, tileSize = 16, edgeSize = 12,
                insets   = { left = 3, right = 3, top = 3, bottom = 3 },
            })
            editBox:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
            editBox:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)
        end
        editBox:SetTextInsets(4, 4, 2, 2)
        editBox:SetText(tostring(GetEffectiveDuration(cd)))
        -- Re-populate after any inherited show handlers fire
        editBox:HookScript("OnShow", function(self)
            self:SetText(tostring(GetEffectiveDuration(cd)))
        end)

        local function CommitEdit()
            local val = tonumber(editBox:GetText())
            if val and val > 0 then
                CooldownTrackerDB.customDurations = CooldownTrackerDB.customDurations or {}
                CooldownTrackerDB.customDurations[cd.id] = (val ~= cd.defaultDuration) and val or nil
                cd.duration = val
            else
                editBox:SetText(tostring(GetEffectiveDuration(cd)))
            end
            editBox:ClearFocus()
        end
        editBox:SetScript("OnEnterPressed", CommitEdit)
        editBox:SetScript("OnEscapePressed", function()
            editBox:SetText(tostring(GetEffectiveDuration(cd)))
            editBox:ClearFocus()
        end)

        editBoxes[cd.id] = editBox

        -- "Default" reset button
        local resetBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        resetBtn:SetSize(70, 22)
        resetBtn:SetPoint("LEFT", editBox, "RIGHT", 10, 0)
        resetBtn:SetText("Default")
        resetBtn:SetScript("OnClick", function()
            CooldownTrackerDB.customDurations = CooldownTrackerDB.customDurations or {}
            CooldownTrackerDB.customDurations[cd.id] = nil
            cd.duration = cd.defaultDuration
            editBox:SetText(tostring(cd.defaultDuration))
        end)

        -- Tooltip on the edit box
        editBox:SetScript("OnEnter", function()
            GameTooltip:SetOwner(editBox, "ANCHOR_RIGHT")
            GameTooltip:SetText("Cooldown Duration")
            GameTooltip:AddLine("Enter the cooldown in seconds.", 1, 1, 1)
            GameTooltip:AddLine(string.format("Default: %d seconds", cd.defaultDuration), 0.8, 0.8, 0.8)
            GameTooltip:AddLine("Press Enter to confirm, Escape to cancel.", 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end)
        editBox:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    -- ----- Reset All button -------------------------------------------------
    local resetAllBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetAllBtn:SetSize(110, 26)
    resetAllBtn:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 16, 16)
    resetAllBtn:SetText("Reset All Defaults")
    resetAllBtn:SetScript("OnClick", function()
        CooldownTrackerDB.customDurations = {}
        for _, cd in ipairs(CT.COOLDOWNS) do
            cd.duration = cd.defaultDuration
            if editBoxes[cd.id] then
                editBoxes[cd.id]:SetText(tostring(cd.defaultDuration))
            end
        end
        print("|cffaaddff[CooldownTracker]|r All durations reset to defaults.")
    end)

    -- Refresh on show (belt-and-suspenders alongside the direct call below)
    panel:SetScript("OnShow", RefreshAllEditBoxes)

    -- Populate all boxes immediately at creation time
    RefreshAllEditBoxes()

    return panel
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

function CT:InitSettings()
    CooldownTrackerDB.customDurations = CooldownTrackerDB.customDurations or {}
    ApplyCustomDurations()

    local panel   = CreateSettingsPanel()
    local category = Settings.RegisterCanvasLayoutCategory(panel, "Healer Cooldown Tracker")
    Settings.RegisterAddOnCategory(category)
    CT.settingsCategory = category
end

function CT:OpenSettings()
    if CT.settingsCategory then
        Settings.OpenToCategory(CT.settingsCategory:GetID())
    end
end
