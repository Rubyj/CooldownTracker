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

-- Ensures spellOrder is fully populated from the default CT.COOLDOWNS order,
-- then moves the spell with the given id by `delta` positions (-1 = up, +1 = down).
-- Refreshes the tracker and updates the provided order-indicator labels table.
local function MoveSpell(id, delta, labels)
    local order = CooldownTrackerDB.spellOrder
    if not order then return end

    -- Populate from defaults if empty.
    if #order == 0 then
        for _, cd in ipairs(CT.COOLDOWNS) do
            table.insert(order, cd.id)
        end
    end

    -- Ensure every known spell is represented (handles newly added spells).
    local inOrder = {}
    for _, sid in ipairs(order) do inOrder[sid] = true end
    for _, cd in ipairs(CT.COOLDOWNS) do
        if not inOrder[cd.id] then
            table.insert(order, cd.id)
        end
    end

    local pos = nil
    for i, sid in ipairs(order) do
        if sid == id then pos = i; break end
    end
    if not pos then return end

    local newPos = pos + delta
    if newPos < 1 or newPos > #order then return end
    order[pos], order[newPos] = order[newPos], order[pos]
    CooldownTrackerDB.spellOrder = order

    if CT.RebuildUI then CT:RebuildUI() end

    -- Refresh position indicators in the settings panel.
    if labels then
        local posMap = {}
        for i, sid in ipairs(order) do posMap[sid] = i end
        for spellId, lbl in pairs(labels) do
            lbl:SetText(tostring(posMap[spellId] or ""))
        end
    end
end

-- ---------------------------------------------------------------------------
-- Panel construction
-- ---------------------------------------------------------------------------

local PANEL_ROW_HEIGHT = 42
local PANEL_ROW_PAD    = 2
local ICON_SIZE        = 28
local EDIT_WIDTH       = 80
local CONTENT_WIDTH    = 520

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
    desc:SetText("Configure the layout and cooldown durations.")
    desc:SetJustifyH("LEFT")

    -- ----- Layout section ---------------------------------------------------
    local layoutSection = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    layoutSection:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -12)
    layoutSection:SetText("|cffaaddffLayout|r")

    local colLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    colLabel:SetPoint("TOPLEFT", layoutSection, "BOTTOMLEFT", 0, -6)
    colLabel:SetText("Columns:")

    local colBox = CreateFrame("EditBox", "CTSettingsColBox", panel, "BackdropTemplate")
    colBox:SetSize(50, 24)
    colBox:SetPoint("LEFT", colLabel, "RIGHT", 8, 0)
    colBox:SetAutoFocus(false)
    colBox:SetFontObject("ChatFontNormal")
    colBox:SetJustifyH("CENTER")
    if colBox.SetBackdrop then
        colBox:SetBackdrop({
            bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        colBox:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
        colBox:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)
    end
    colBox:SetTextInsets(4, 4, 2, 2)

    local colHint = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    colHint:SetPoint("LEFT", colBox, "RIGHT", 10, 0)
    colHint:SetText("1 = vertical stack, 2-9 = grid layout")
    colHint:SetTextColor(0.6, 0.6, 0.6)

    colBox:SetScript("OnTextChanged", function(self, userInput)
        if not userInput then return end
        local val = tonumber(self:GetText())
        if val and val >= 1 and val <= 9 then
            CooldownTrackerDB.columns = val
            if CT.LayoutRows then CT:LayoutRows() end
        end
    end)
    colBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    colBox:SetScript("OnEscapePressed", function(self)
        self:SetText(tostring(CooldownTrackerDB.columns or 1))
        self:ClearFocus()
    end)
    colBox:SetScript("OnEnter", function()
        GameTooltip:SetOwner(colBox, "ANCHOR_RIGHT")
        GameTooltip:SetText("Grid Columns")
        GameTooltip:AddLine("1 = single vertical column (default)", 1, 1, 1)
        GameTooltip:AddLine("2-9 = compact card grid with that many columns", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Changes apply instantly to the tracker window.", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    colBox:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- ----- Sound toggle -----------------------------------------------------
    local soundCheck = CreateFrame("CheckButton", "CTSettingsSoundCheck", panel, "UICheckButtonTemplate")
    soundCheck:SetSize(24, 24)
    soundCheck:SetPoint("TOPLEFT", colLabel, "BOTTOMLEFT", 0, -14)
    soundCheck:SetChecked(CooldownTrackerDB.playSoundOnReady ~= false)
    soundCheck:SetScript("OnClick", function(self)
        CooldownTrackerDB.playSoundOnReady = self:GetChecked()
    end)

    local soundLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    soundLabel:SetPoint("LEFT", soundCheck, "RIGHT", 4, 0)
    soundLabel:SetText("Play sound when cooldown is ready")

    local layoutDivider = panel:CreateTexture(nil, "ARTWORK")
    layoutDivider:SetHeight(1)
    layoutDivider:SetPoint("TOPLEFT", soundCheck, "BOTTOMLEFT", 0, -10)
    layoutDivider:SetWidth(CONTENT_WIDTH)
    layoutDivider:SetColorTexture(0.3, 0.3, 0.4, 0.4)

    -- ----- Class Roster section ---------------------------------------------
    local rosterSection = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    rosterSection:SetPoint("TOPLEFT", layoutDivider, "BOTTOMLEFT", 0, -10)
    rosterSection:SetText("|cffaaddffClass Roster|r")

    local rosterDesc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    rosterDesc:SetPoint("TOPLEFT", rosterSection, "BOTTOMLEFT", 0, -4)
    rosterDesc:SetText("How many of each class are in your raid. Abilities duplicate per player.")
    rosterDesc:SetTextColor(0.6, 0.6, 0.6)
    rosterDesc:SetWidth(CONTENT_WIDTH)
    rosterDesc:SetJustifyH("LEFT")

    -- Derive unique classes in encounter order (preserving CT.COOLDOWNS order)
    local classCountBoxes = {}
    local seenClasses = {}
    local classList = {}
    for _, cd in ipairs(CT.COOLDOWNS) do
        if not seenClasses[cd.class] then
            seenClasses[cd.class] = true
            table.insert(classList, { class = cd.class, r = cd.r, g = cd.g, b = cd.b })
        end
    end

    local rosterAnchor = rosterDesc
    for _, cls in ipairs(classList) do
        local clsName = cls.class

        local clsLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        clsLabel:SetPoint("TOPLEFT", rosterAnchor, "BOTTOMLEFT", 0, -8)
        clsLabel:SetText(clsName)
        clsLabel:SetTextColor(cls.r, cls.g, cls.b)
        clsLabel:SetWidth(160)

        local countBox = CreateFrame("EditBox", "CTSettingsCount_" .. clsName:gsub(" ", ""), panel, "BackdropTemplate")
        countBox:SetSize(40, 22)
        countBox:SetPoint("LEFT", clsLabel, "RIGHT", 8, 0)
        countBox:SetAutoFocus(false)
        countBox:SetFontObject("ChatFontNormal")
        countBox:SetJustifyH("CENTER")
        if countBox.SetBackdrop then
            countBox:SetBackdrop({
                bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 16, edgeSize = 12,
                insets = { left = 3, right = 3, top = 3, bottom = 3 },
            })
            countBox:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
            countBox:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)
        end
        countBox:SetTextInsets(4, 4, 2, 2)

        local countHint = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        countHint:SetPoint("LEFT", countBox, "RIGHT", 8, 0)
        countHint:SetText("players (1-5)")
        countHint:SetTextColor(0.5, 0.5, 0.5)

        countBox:SetScript("OnTextChanged", function(self, userInput)
            if not userInput then return end
            local val = tonumber(self:GetText())
            if val and val >= 1 and val <= 5 then
                CooldownTrackerDB.classCounts = CooldownTrackerDB.classCounts or {}
                CooldownTrackerDB.classCounts[clsName] = val
                if CT.RebuildUI then CT:RebuildUI() end
            end
        end)
        countBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        countBox:SetScript("OnEscapePressed", function(self)
            self:SetText(tostring((CooldownTrackerDB.classCounts or {})[clsName] or 1))
            self:ClearFocus()
        end)
        countBox:SetScript("OnEnter", function()
            GameTooltip:SetOwner(countBox, "ANCHOR_RIGHT")
            GameTooltip:SetText(clsName .. " Count")
            GameTooltip:AddLine("Number of " .. clsName .. "s in the raid.", 1, 1, 1)
            GameTooltip:AddLine("Each ability for this class will appear N times.", 0.8, 0.8, 0.8)
            GameTooltip:Show()
        end)
        countBox:SetScript("OnLeave", function() GameTooltip:Hide() end)

        classCountBoxes[clsName] = countBox
        rosterAnchor = clsLabel
    end

    local rosterDivider = panel:CreateTexture(nil, "ARTWORK")
    rosterDivider:SetHeight(1)
    rosterDivider:SetPoint("TOPLEFT", rosterAnchor, "BOTTOMLEFT", 0, -10)
    rosterDivider:SetWidth(CONTENT_WIDTH)
    rosterDivider:SetColorTexture(0.3, 0.3, 0.4, 0.4)

    -- ----- Cooldown duration headers ----------------------------------------
    local hdrAbility = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    hdrAbility:SetPoint("TOPLEFT", rosterDivider, "BOTTOMLEFT", 28 + ICON_SIZE + 12, -8)
    hdrAbility:SetText("Ability")
    hdrAbility:SetTextColor(0.7, 0.7, 0.7)

    local hdrShow = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    hdrShow:SetPoint("LEFT", rosterDivider, "BOTTOMLEFT", 4, -8)
    hdrShow:SetText("Show")
    hdrShow:SetTextColor(0.7, 0.7, 0.7)

    local hdrDur = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    hdrDur:SetPoint("LEFT", hdrAbility, "LEFT", 248, 0)
    hdrDur:SetText("Cooldown (seconds)")
    hdrDur:SetTextColor(0.7, 0.7, 0.7)

    local divider = panel:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT",  hdrAbility, "BOTTOMLEFT", -ICON_SIZE - 12, -4)
    divider:SetWidth(CONTENT_WIDTH)
    divider:SetColorTexture(0.3, 0.3, 0.4, 0.6)

    -- editBoxes, spellCheckboxes, and orderLabels must be declared here so the
    -- OnShow closure below can reference them (Lua requires locals before use).
    local editBoxes = {}
    local spellCheckboxes = {}
    local orderLabels = {}

    local function GetEffectiveOrderPos()
        local order = CooldownTrackerDB.spellOrder or {}
        local posMap = {}
        if #order == 0 then
            for i, cd in ipairs(CT.COOLDOWNS) do posMap[cd.id] = i end
        else
            for i, sid in ipairs(order) do posMap[sid] = i end
        end
        return posMap
    end

    local function RefreshOrderIndicators()
        C_Timer.After(0, function()
            local posMap = GetEffectiveOrderPos()
            for spellId, lbl in pairs(orderLabels) do
                lbl:SetText(tostring(posMap[spellId] or ""))
            end
        end)
    end

    local function RefreshAllEditBoxes()
        C_Timer.After(0, function()
            for _, cd in ipairs(CT.COOLDOWNS) do
                local eb = editBoxes[cd.id]
                if eb then
                    eb:SetText(tostring(GetEffectiveDuration(cd)))
                    eb:SetCursorPosition(0)
                end
            end
        end)
    end

    -- refresh all boxes on panel show (deferred so Settings canvas doesn't wipe them)
    panel:SetScript("OnShow", function()
        C_Timer.After(0, function()
            colBox:SetText(tostring(CooldownTrackerDB.columns or 1))
            soundCheck:SetChecked(CooldownTrackerDB.playSoundOnReady ~= false)
            local counts    = CooldownTrackerDB.classCounts or {}
            local disabled  = CooldownTrackerDB.disabledSpells or {}
            for clsName, box in pairs(classCountBoxes) do
                box:SetText(tostring(counts[clsName] or 1))
            end
            for spellId, cb in pairs(spellCheckboxes) do
                cb:SetChecked(not disabled[spellId])
            end
            RefreshAllEditBoxes()
            RefreshOrderIndicators()
        end)
    end)

    -- ----- Scroll frame -----------------------------------------------------
    local scrollFrame = CreateFrame("ScrollFrame", "CTSettingsScrollFrame", panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", 0, -6)
    scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 50)

    local contentHeight = #CT.COOLDOWNS * (PANEL_ROW_HEIGHT + PANEL_ROW_PAD)
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(CONTENT_WIDTH, contentHeight)
    scrollFrame:SetScrollChild(content)

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

        -- Spell visibility checkbox
        local spellCB = CreateFrame("CheckButton", "CTSettingsSpell_" .. cd.id, row, "UICheckButtonTemplate")
        spellCB:SetSize(24, 24)
        spellCB:SetPoint("LEFT", row, "LEFT", 4, 0)
        spellCB:SetChecked(not (CooldownTrackerDB.disabledSpells or {})[cd.id])
        spellCB:SetScript("OnClick", function(self)
            CooldownTrackerDB.disabledSpells = CooldownTrackerDB.disabledSpells or {}
            if self:GetChecked() then
                CooldownTrackerDB.disabledSpells[cd.id] = nil
            else
                CooldownTrackerDB.disabledSpells[cd.id] = true
            end
            if CT.RebuildUI then CT:RebuildUI() end
        end)
        spellCheckboxes[cd.id] = spellCB

        -- Icon
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(ICON_SIZE, ICON_SIZE)
        icon:SetPoint("LEFT", row, "LEFT", 36, 0)
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

        -- Duration edit box — built manually to avoid template init issues
        local editBox = CreateFrame("EditBox", "CTSettingsEdit_" .. cd.id, row, "BackdropTemplate")
        editBox:SetSize(EDIT_WIDTH, 24)
        editBox:SetPoint("LEFT", row, "LEFT", 308, 0)
        editBox:SetAutoFocus(false)
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
        editBox:SetTextInsets(6, 6, 2, 2)

        -- Text is set by RefreshAllEditBoxes via C_Timer.After — not here,
        -- because anything set here gets wiped by the Settings canvas.

        local function CommitEdit()
            local val = tonumber(editBox:GetText())
            if val and val > 0 then
                CooldownTrackerDB.customDurations = CooldownTrackerDB.customDurations or {}
                CooldownTrackerDB.customDurations[cd.id] = (val ~= cd.defaultDuration) and val or nil
                cd.duration = val
                if CT.expandedCooldowns then
                    local prefix = cd.id .. "_"
                    for _, ecd in ipairs(CT.expandedCooldowns) do
                        if ecd.id == cd.id or ecd.id:sub(1, #prefix) == prefix then
                            ecd.duration = val
                        end
                    end
                end
            end
        end
        editBox:SetScript("OnTextChanged", function(self, userInput)
            -- Only commit on actual keystrokes, not programmatic SetText
            if userInput then CommitEdit() end
        end)
        editBox:SetScript("OnEnterPressed", function() editBox:ClearFocus() end)
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
            GameTooltip:AddLine("Type a duration in seconds and press Enter.", 1, 1, 1)
            GameTooltip:AddLine(string.format("Default: %d seconds", cd.defaultDuration), 0.8, 0.8, 0.8)
            GameTooltip:Show()
        end)
        editBox:SetScript("OnLeave", function() GameTooltip:Hide() end)

        -- ----- Reorder up/down buttons ----------------------------------------
        local orderLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        orderLabel:SetSize(20, 14)
        orderLabel:SetPoint("TOP", row, "TOPRIGHT", -24, -3)
        orderLabel:SetJustifyH("CENTER")
        orderLabel:SetTextColor(0.6, 0.6, 0.6)
        orderLabels[cd.id] = orderLabel

        local upBtn = CreateFrame("Button", nil, row)
        upBtn:SetSize(22, 15)
        upBtn:SetPoint("TOP", row, "TOPRIGHT", -24, -16)
        local upTex = upBtn:CreateTexture(nil, "ARTWORK")
        upTex:SetAllPoints(upBtn)
        upTex:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up")
        upTex:SetTexCoord(0.15, 0.85, 0.15, 0.85)
        upBtn:SetScript("OnClick", function()
            MoveSpell(cd.id, -1, orderLabels)
        end)
        upBtn:SetScript("OnEnter", function()
            GameTooltip:SetOwner(upBtn, "ANCHOR_RIGHT")
            GameTooltip:SetText("Move Up")
            GameTooltip:AddLine("Move this spell earlier in the tracker.", 0.8, 0.8, 0.8)
            GameTooltip:Show()
        end)
        upBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

        local downBtn = CreateFrame("Button", nil, row)
        downBtn:SetSize(22, 15)
        downBtn:SetPoint("BOTTOM", row, "BOTTOMRIGHT", -24, 16)
        local downTex = downBtn:CreateTexture(nil, "ARTWORK")
        downTex:SetAllPoints(downBtn)
        downTex:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
        downTex:SetTexCoord(0.15, 0.85, 0.15, 0.85)
        downBtn:SetScript("OnClick", function()
            MoveSpell(cd.id, 1, orderLabels)
        end)
        downBtn:SetScript("OnEnter", function()
            GameTooltip:SetOwner(downBtn, "ANCHOR_RIGHT")
            GameTooltip:SetText("Move Down")
            GameTooltip:AddLine("Move this spell later in the tracker.", 0.8, 0.8, 0.8)
            GameTooltip:Show()
        end)
        downBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
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

    -- ----- Reset Order button -----------------------------------------------
    local resetOrderBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetOrderBtn:SetSize(100, 26)
    resetOrderBtn:SetPoint("LEFT", resetAllBtn, "RIGHT", 8, 0)
    resetOrderBtn:SetText("Reset Order")
    resetOrderBtn:SetScript("OnClick", function()
        CooldownTrackerDB.spellOrder = {}
        if CT.RebuildUI then CT:RebuildUI() end
        RefreshOrderIndicators()
        print("|cffaaddff[CooldownTracker]|r Spell order reset to defaults.")
    end)
    resetOrderBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(resetOrderBtn, "ANCHOR_TOP")
        GameTooltip:SetText("Reset Spell Order")
        GameTooltip:AddLine("Restores the default display order for all spells.", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    resetOrderBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    return panel
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

function CT:InitSettings()
    CooldownTrackerDB.customDurations = CooldownTrackerDB.customDurations or {}
    CooldownTrackerDB.columns         = CooldownTrackerDB.columns or 1
    CooldownTrackerDB.classCounts     = CooldownTrackerDB.classCounts or {}
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
