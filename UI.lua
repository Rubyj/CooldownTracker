--------------------------------------------------------------------------------
-- UI.lua
-- Builds and manages all UI widgets: the main draggable frame, per-cooldown
-- rows (icon, labels, progress bar, button), and the per-frame update loop.
-- Exposes: CT:BuildUI(), CT:UpdateAllRows(), CT:RestorePosition()
--------------------------------------------------------------------------------

local AddonName, CT = ...

-- ---------------------------------------------------------------------------
-- Layout constants
-- ---------------------------------------------------------------------------
local ROW_HEIGHT   = 36
local ROW_PADDING  = 6
local FRAME_WIDTH  = 300
local ICON_SIZE    = 28
local BUTTON_WIDTH = 52
local TITLE_HEIGHT = 24
local BOTTOM_PAD   = 8

-- ---------------------------------------------------------------------------
-- Local helpers
-- ---------------------------------------------------------------------------
local function FormatTime(seconds)
    if seconds <= 0 then return "Ready" end
    local m = math.floor(seconds / 60)
    local s = math.floor(seconds % 60)
    if m > 0 then
        return string.format("%d:%02d", m, s)
    else
        return string.format("0:%02d", s)
    end
end

local function SetBtnColor(btn, r, g, b)
    local tex = btn:GetNormalTexture()
    if tex then tex:SetVertexColor(r, g, b) end
end

local function SavePosition(frame)
    CooldownTrackerDB = CooldownTrackerDB or {}
    local point, _, relPoint, x, y = frame:GetPoint()
    CooldownTrackerDB.point    = point
    CooldownTrackerDB.relPoint = relPoint
    CooldownTrackerDB.x        = x
    CooldownTrackerDB.y        = y
end

-- ---------------------------------------------------------------------------
-- Row update (called every OnUpdate tick for active timers)
-- ---------------------------------------------------------------------------
local function UpdateRow(row, now)
    local cd      = row.cd
    local endTime = CT.activeTimers[cd.id]

    if endTime then
        local remaining = endTime - now
        if remaining <= 0 then
            -- Timer just expired
            CT.activeTimers[cd.id] = nil
            row.timerLabel:SetText("|cff00ff00Ready|r")
            row.barFill:SetWidth(row.bar:GetWidth())
            row.barFill:SetVertexColor(0.2, 0.9, 0.2)
            row.button:SetText("Used")
            SetBtnColor(row.button, 0.3, 0.85, 0.3)
            row.iconTex:SetAlpha(1)
            PlaySound(SOUNDKIT.ALARM_CLOCK_WARNING_3)
        else
            -- Counting down
            local frac = remaining / cd.duration
            local barW = math.max(2, row.bar:GetWidth() * frac)
            row.barFill:SetWidth(barW)
            if frac < 0.25 then
                row.barFill:SetVertexColor(0.9, 0.2, 0.2)
            elseif frac < 0.5 then
                row.barFill:SetVertexColor(0.9, 0.7, 0.1)
            else
                row.barFill:SetVertexColor(cd.r, cd.g, cd.b)
            end
            row.timerLabel:SetText("|cffff8040" .. FormatTime(remaining) .. "|r")
            row.button:SetText("Reset")
            SetBtnColor(row.button, 0.8, 0.3, 0.3)
        end
    else
        -- Ready state
        row.timerLabel:SetText("|cff00ff00Ready|r")
        row.barFill:SetWidth(row.bar:GetWidth())
        row.barFill:SetVertexColor(0.2, 0.9, 0.2)
        row.button:SetText("Used")
        SetBtnColor(row.button, 0.3, 0.85, 0.3)
    end
end

-- ---------------------------------------------------------------------------
-- Row construction
-- ---------------------------------------------------------------------------
local function CreateRow(parent, cd, index)
    local yOffset = -(TITLE_HEIGHT + ROW_PADDING + (index - 1) * (ROW_HEIGHT + ROW_PADDING))

    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(FRAME_WIDTH - 16, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, yOffset)
    row.cd = cd

    -- Background
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(row)
    bg:SetColorTexture(0, 0, 0, 0.35)

    -- Accent left strip
    local strip = row:CreateTexture(nil, "BACKGROUND")
    strip:SetSize(3, ROW_HEIGHT)
    strip:SetPoint("LEFT", row, "LEFT", 0, 0)
    strip:SetColorTexture(cd.r, cd.g, cd.b, 0.9)

    -- Spell icon
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetPoint("LEFT", row, "LEFT", 7, 0)
    icon:SetTexture(cd.icon)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.iconTex = icon

    -- Ability name
    local nameLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameLabel:SetPoint("LEFT", icon, "RIGHT", 6, 4)
    nameLabel:SetText(cd.name)
    nameLabel:SetTextColor(1, 1, 1)
    nameLabel:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")

    -- Class tag
    local classLabel = row:CreateFontString(nil, "OVERLAY")
    classLabel:SetPoint("LEFT", icon, "RIGHT", 6, -6)
    classLabel:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    classLabel:SetText(cd.class)
    classLabel:SetTextColor(cd.r, cd.g, cd.b)

    -- Timer label
    local timerLabel = row:CreateFontString(nil, "OVERLAY")
    timerLabel:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
    timerLabel:SetPoint("RIGHT", row, "RIGHT", -(BUTTON_WIDTH + 8), 0)
    timerLabel:SetText("|cff00ff00Ready|r")
    row.timerLabel = timerLabel

    -- Progress bar background
    local bar = row:CreateTexture(nil, "BORDER")
    bar:SetSize(row:GetWidth() - ICON_SIZE - BUTTON_WIDTH - 26, 3)
    bar:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 6, 2)
    bar:SetColorTexture(0.15, 0.15, 0.15, 0.8)
    row.bar = bar

    -- Progress bar fill
    local fill = row:CreateTexture(nil, "ARTWORK")
    fill:SetSize(bar:GetWidth(), 3)
    fill:SetPoint("LEFT", bar, "LEFT", 0, 0)
    fill:SetColorTexture(cd.r, cd.g, cd.b)
    row.barFill = fill

    -- Used / Reset button
    local btn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    btn:SetSize(BUTTON_WIDTH, 22)
    btn:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    btn:SetText("Used")
    SetBtnColor(btn, 0.3, 0.85, 0.3)
    btn:SetScript("OnClick", function()
        if CT.activeTimers[cd.id] then
            CT.activeTimers[cd.id] = nil
        else
            CT.activeTimers[cd.id] = GetTime() + cd.duration
        end
        UpdateRow(row, GetTime())
    end)
    row.button = btn

    -- Hover highlight + tooltip
    row:SetScript("OnEnter", function()
        bg:SetColorTexture(cd.r * 0.15, cd.g * 0.15, cd.b * 0.15, 0.5)
        GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
        GameTooltip:SetText(cd.name)
        GameTooltip:AddLine("Class: " .. cd.class, 1, 1, 1)
        local m = math.floor(cd.duration / 60)
        local s = cd.duration % 60
        if m > 0 and s > 0 then
            GameTooltip:AddLine(string.format("Cooldown: %dm %ds", m, s), 0.8, 0.8, 0.8)
        elseif m > 0 then
            GameTooltip:AddLine(string.format("Cooldown: %d minute%s", m, m > 1 and "s" or ""), 0.8, 0.8, 0.8)
        else
            GameTooltip:AddLine(string.format("Cooldown: %ds", s), 0.8, 0.8, 0.8)
        end
        GameTooltip:AddLine(" ")
        if CT.activeTimers[cd.id] then
            GameTooltip:AddLine("Click to |cffff4040reset|r the timer.", 1, 0.8, 0)
        else
            GameTooltip:AddLine("Click to start the cooldown timer.", 1, 0.8, 0)
        end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function()
        bg:SetColorTexture(0, 0, 0, 0.35)
        GameTooltip:Hide()
    end)

    CT.rows[cd.id] = row
    return row
end

-- ---------------------------------------------------------------------------
-- Public: CT:UpdateAllRows() — called from OnUpdate
-- ---------------------------------------------------------------------------
function CT:UpdateAllRows()
    local now = GetTime()
    for _, cd in ipairs(CT.COOLDOWNS) do
        local row = CT.rows[cd.id]
        if row then UpdateRow(row, now) end
    end
end

-- ---------------------------------------------------------------------------
-- Public: CT:RestorePosition()
-- ---------------------------------------------------------------------------
function CT:RestorePosition()
    local db = CooldownTrackerDB
    if db and db.point then
        CT.mainFrame:ClearAllPoints()
        CT.mainFrame:SetPoint(db.point, UIParent, db.relPoint, db.x, db.y)
    end
end

-- ---------------------------------------------------------------------------
-- Public: CT:BuildUI() — called once from Core.lua on ADDON_LOADED
-- ---------------------------------------------------------------------------
function CT:BuildUI()
    CT.rows = {}

    local totalRows   = #CT.COOLDOWNS
    local frameHeight = TITLE_HEIGHT + ROW_PADDING + totalRows * (ROW_HEIGHT + ROW_PADDING) + BOTTOM_PAD

    -- Main frame
    local f = CreateFrame("Frame", "CooldownTrackerFrame", UIParent, "BackdropTemplate")
    f:SetSize(FRAME_WIDTH, frameHeight)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition(self)
    end)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)

    -- Backdrop
    if f.SetBackdrop then
        f:SetBackdrop({
            bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile     = true, tileSize = 16, edgeSize = 16,
            insets   = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        f:SetBackdropColor(0.05, 0.05, 0.08, 0.92)
        f:SetBackdropBorderColor(0.3, 0.3, 0.4, 0.8)
    end

    -- Title bar background
    local titleBg = f:CreateTexture(nil, "BACKGROUND")
    titleBg:SetHeight(TITLE_HEIGHT)
    titleBg:SetPoint("TOPLEFT",  f, "TOPLEFT",  0, 0)
    titleBg:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    titleBg:SetColorTexture(0.08, 0.08, 0.15, 0.95)

    -- Title text
    local titleText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    titleText:SetPoint("CENTER", titleBg, "CENTER", 0, 0)
    titleText:SetText("|cff55ff55+|r |cffaaddffHealer Cooldowns|r")
    titleText:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")

    -- Close button
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetSize(18, 18)
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -3)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- Divider
    local divider = f:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT",  f, "TOPLEFT",  0, -TITLE_HEIGHT)
    divider:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -TITLE_HEIGHT)
    divider:SetColorTexture(0.3, 0.3, 0.5, 0.6)

    -- Build one row per cooldown
    for i, cd in ipairs(CT.COOLDOWNS) do
        CreateRow(f, cd, i)
    end

    -- Per-frame update loop
    f:SetScript("OnUpdate", function() CT:UpdateAllRows() end)

    f:Hide()
    CT.mainFrame = f
end
