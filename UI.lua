--------------------------------------------------------------------------------
-- UI.lua
-- Builds and manages the main window. Supports a configurable grid layout:
--   columns = 1  → wide vertical rows (current look)
--   columns = N  → N-column card grid (compact square cards)
--
-- Exposes: CT:BuildUI(), CT:UpdateAllRows(), CT:RestorePosition(),
--          CT:LayoutRows()
--------------------------------------------------------------------------------

local AddonName, CT = ...

-- ---------------------------------------------------------------------------
-- Layout constants
-- ---------------------------------------------------------------------------
local TITLE_HEIGHT = 24
local BOTTOM_PAD   = 8
local ROW_PADDING  = 6

-- Wide-row mode (columns = 1)
local WIDE_ROW_H   = 36
local WIDE_W       = 300
local ICON_SIZE    = 28
-- Card mode (columns ≥ 2)
local CARD_W       = 100
local CARD_H       = 72
local CARD_PAD     = 6
local CARD_ICON    = 44

-- ---------------------------------------------------------------------------
-- Local helpers
-- ---------------------------------------------------------------------------
local function FormatTime(seconds)
    if seconds <= 0 then return "Ready" end
    local m = math.floor(seconds / 60)
    local s = math.floor(seconds % 60)
    if m > 0 then return string.format("%d:%02d", m, s)
    else           return string.format("0:%02d", s) end
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
-- Per-row internal layout: wide (1-col) vs card (multi-col)
-- These functions reanchor all child widgets inside an existing row frame.
-- ---------------------------------------------------------------------------
local function ApplyWideLayout(row)
    local cd = row.cd
    local rowW = WIDE_W - 16

    row:SetSize(rowW, WIDE_ROW_H)

    row.strip:Show()
    row.strip:ClearAllPoints()
    row.strip:SetSize(3, WIDE_ROW_H)
    row.strip:SetPoint("LEFT", row, "LEFT", 0, 0)

    row.iconTex:ClearAllPoints()
    row.iconTex:SetSize(ICON_SIZE, ICON_SIZE)
    row.iconTex:SetPoint("LEFT", row, "LEFT", 7, 0)

    row.nameLabel:Show()
    row.nameLabel:ClearAllPoints()
    row.nameLabel:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    row.nameLabel:SetPoint("LEFT", row.iconTex, "RIGHT", 6, 4)

    row.classLabel:Show()
    row.classLabel:ClearAllPoints()
    row.classLabel:SetPoint("LEFT", row.iconTex, "RIGHT", 6, -6)

    row.timerLabel:ClearAllPoints()
    row.timerLabel:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
    row.timerLabel:SetPoint("RIGHT", row, "RIGHT", -6, 0)

    row.bar:Show()
    row.bar:ClearAllPoints()
    row.bar:SetSize(math.max(4, rowW - ICON_SIZE - 60), 3)
    row.bar:SetPoint("BOTTOMLEFT", row.iconTex, "BOTTOMRIGHT", 6, 2)

    row.barFill:Show()
    row.barFill:ClearAllPoints()
    row.barFill:SetSize(row.bar:GetWidth(), 3)
    row.barFill:SetPoint("LEFT", row.bar, "LEFT", 0, 0)

    row.button:Hide()

    row.isWide = true
end

local function ApplyCardLayout(row, cW, cH)
    row:SetSize(cW, cH)

    -- Colour accent becomes a top strip
    row.strip:Show()
    row.strip:ClearAllPoints()
    row.strip:SetSize(cW, 3)
    row.strip:SetPoint("TOP", row, "TOP", 0, 0)

    row.nameLabel:Hide()
    row.classLabel:Hide()

    row.iconTex:ClearAllPoints()
    row.iconTex:SetSize(CARD_ICON, CARD_ICON)
    row.iconTex:SetPoint("CENTER", row, "CENTER", 0, 6)

    row.timerLabel:ClearAllPoints()
    row.timerLabel:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    row.timerLabel:SetPoint("BOTTOM", row, "BOTTOM", 0, 6)

    row.bar:Hide()
    row.barFill:Hide()

    row.button:Hide()

    row.isWide = false
end

-- ---------------------------------------------------------------------------
-- Row update   (called every OnUpdate tick)
-- ---------------------------------------------------------------------------
local function UpdateRow(row, now)
    local cd      = row.cd
    local endTime = CT.activeTimers[cd.id]

    if endTime then
        local remaining = endTime - now
        if remaining <= 0 then
            CT.activeTimers[cd.id] = nil
            row.timerLabel:SetText("|cff00ff00Ready|r")
            if row.isWide then
                row.barFill:SetWidth(row.bar:GetWidth())
                row.barFill:SetVertexColor(0.2, 0.9, 0.2)
            end
            row.iconTex:SetAlpha(1)
            if CooldownTrackerDB.playSoundOnReady ~= false then
                PlaySound(SOUNDKIT.ALARM_CLOCK_WARNING_3)
            end
        else
            local frac = remaining / cd.duration
            if row.isWide then
                local barW = math.max(2, row.bar:GetWidth() * frac)
                row.barFill:SetWidth(barW)
                if     frac < 0.25 then row.barFill:SetVertexColor(0.9, 0.2, 0.2)
                elseif frac < 0.5  then row.barFill:SetVertexColor(0.9, 0.7, 0.1)
                else                    row.barFill:SetVertexColor(cd.r, cd.g, cd.b) end
            end
            row.timerLabel:SetText("|cffff8040" .. FormatTime(remaining) .. "|r")
        end
    else
        row.timerLabel:SetText("|cff00ff00Ready|r")
        if row.isWide then
            row.barFill:SetWidth(row.bar:GetWidth())
            row.barFill:SetVertexColor(0.2, 0.9, 0.2)
        end
    end
end

-- ---------------------------------------------------------------------------
-- Row construction (creates all child frames; layout applied separately)
-- ---------------------------------------------------------------------------
local function CreateRow(parent, cd)
    local row = CreateFrame("Button", nil, parent)
    row.cd = cd
    row:RegisterForClicks("LeftButtonUp")

    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(row)
    bg:SetColorTexture(0, 0, 0, 0.35)
    row.bg = bg

    local strip = row:CreateTexture(nil, "BACKGROUND")
    strip:SetColorTexture(cd.r, cd.g, cd.b, 0.9)
    row.strip = strip

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(cd.icon)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.iconTex = icon

    local nameLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameLabel:SetText(cd.name)
    nameLabel:SetTextColor(1, 1, 1)
    row.nameLabel = nameLabel

    local classLabel = row:CreateFontString(nil, "OVERLAY")
    classLabel:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    classLabel:SetText(cd.class)
    classLabel:SetTextColor(cd.r, cd.g, cd.b)
    row.classLabel = classLabel

    local timerLabel = row:CreateFontString(nil, "OVERLAY")
    timerLabel:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
    timerLabel:SetText("|cff00ff00Ready|r")
    row.timerLabel = timerLabel

    local bar = row:CreateTexture(nil, "BORDER")
    bar:SetColorTexture(0.15, 0.15, 0.15, 0.8)
    row.bar = bar

    local fill = row:CreateTexture(nil, "ARTWORK")
    fill:SetColorTexture(cd.r, cd.g, cd.b)
    row.barFill = fill

    -- Invisible placeholder kept so RebuildUI doesn't need changes (button ref still safe to hide)
    local btn = CreateFrame("Frame", nil, row)
    btn:Hide()
    row.button = btn

    row:SetScript("OnClick", function()
        local mycd = row.cd
        if CT.activeTimers[mycd.id] then
            CT.activeTimers[mycd.id] = nil
        else
            CT.activeTimers[mycd.id] = GetTime() + mycd.duration
        end
        UpdateRow(row, GetTime())
    end)

    row:SetScript("OnEnter", function()
        local mycd = row.cd
        bg:SetColorTexture(mycd.r * 0.15, mycd.g * 0.15, mycd.b * 0.15, 0.5)
        GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
        GameTooltip:SetText(mycd.name)
        GameTooltip:AddLine("Class: " .. mycd.class, 1, 1, 1)
        local m = math.floor(mycd.duration / 60)
        local s = mycd.duration % 60
        if m > 0 and s > 0 then
            GameTooltip:AddLine(string.format("Cooldown: %dm %ds", m, s), 0.8, 0.8, 0.8)
        elseif m > 0 then
            GameTooltip:AddLine(string.format("Cooldown: %d min", m), 0.8, 0.8, 0.8)
        else
            GameTooltip:AddLine(string.format("Cooldown: %ds", s), 0.8, 0.8, 0.8)
        end
        GameTooltip:AddLine(" ")
        if CT.activeTimers[mycd.id] then
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
-- Public: CT:BuildExpandedCooldowns()
-- Populates CT.expandedCooldowns from CT.COOLDOWNS + class counts.
--   count=1: original entry unchanged (no "#N" suffix)
--   count>1: N copies with unique IDs and "#N" appended to name
-- ---------------------------------------------------------------------------
function CT:BuildExpandedCooldowns()
    local counts   = CooldownTrackerDB.classCounts or {}
    local disabled = CooldownTrackerDB.disabledSpells or {}
    CT.expandedCooldowns = {}
    for _, cd in ipairs(CT.COOLDOWNS) do
        if not disabled[cd.id] then
            local count = math.max(1, math.min(5, counts[cd.class] or 1))
            if count == 1 then
                table.insert(CT.expandedCooldowns, cd)
            else
                for n = 1, count do
                    local copy = {}
                    for k, v in pairs(cd) do copy[k] = v end
                    copy.id   = cd.id .. "_" .. n
                    copy.name = cd.name .. " #" .. n
                    table.insert(CT.expandedCooldowns, copy)
                end
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Public: CT:RebuildUI()
-- Safe to call at any time (including from OnTextChanged).
-- Reconfigures the existing pre-allocated frame pool — no SetParent or
-- CreateFrame calls at runtime, which avoids WoW taint errors.
-- ---------------------------------------------------------------------------
function CT:RebuildUI()
    CT.activeTimers = {}
    CT:BuildExpandedCooldowns()

    -- Grow the pool if needed (only at first expansion — safe during ADDON_LOADED-like context)
    while #CT.pool < #CT.expandedCooldowns do
        local row = CreateRow(CT.mainFrame, CT.expandedCooldowns[#CT.pool + 1])
        row:Hide()
        CT.pool[#CT.pool + 1] = row
    end

    -- Reconfigure pool frames: update cd data and visuals (no SetScript!)
    for i, cd in ipairs(CT.expandedCooldowns) do
        local row = CT.pool[i]
        row:Show()
        row.cd = cd
        row.strip:SetColorTexture(cd.r, cd.g, cd.b, 0.9)
        row.iconTex:SetTexture(cd.icon)
        row.nameLabel:SetText(cd.name)
        row.nameLabel:SetTextColor(1, 1, 1)
        row.classLabel:SetText(cd.class)
        row.classLabel:SetTextColor(cd.r, cd.g, cd.b)
        row.timerLabel:SetText("|cff00ff00Ready|r")
        row.barFill:SetVertexColor(cd.r, cd.g, cd.b)
    end

    -- Hide unused pool frames
    for i = #CT.expandedCooldowns + 1, #CT.pool do
        CT.pool[i]:Hide()
    end

    -- Rebuild rows lookup
    CT.rows = {}
    for i, cd in ipairs(CT.expandedCooldowns) do
        CT.rows[cd.id] = CT.pool[i]
    end

    CT:LayoutRows()
end


-- ---------------------------------------------------------------------------
-- Public: CT:LayoutRows()
-- Repositions all row frames based on CooldownTrackerDB.columns.
-- Safe to call any time (e.g. from settings panel after columns change).
-- ---------------------------------------------------------------------------
function CT:LayoutRows()
    local cols = math.max(1, math.min(#CT.expandedCooldowns, CooldownTrackerDB.columns or 1))
    local n    = #CT.expandedCooldowns
    local f    = CT.mainFrame

    if cols == 1 then
        -- Fully vertical: wide rows
        local frameH = TITLE_HEIGHT + ROW_PADDING
                       + n * (WIDE_ROW_H + ROW_PADDING)
                       + BOTTOM_PAD
        f:SetSize(WIDE_W, frameH)

        for i, cd in ipairs(CT.expandedCooldowns) do
            local row = CT.rows[cd.id]
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", f, "TOPLEFT",
                8,
                -(TITLE_HEIGHT + ROW_PADDING + (i - 1) * (WIDE_ROW_H + ROW_PADDING)))
            ApplyWideLayout(row)
        end
    else
        -- Grid: compact cards
        local numRowsGrid = math.ceil(n / cols)
        local frameW      = cols * (CARD_W + CARD_PAD) + CARD_PAD
        local frameH      = TITLE_HEIGHT + CARD_PAD
                           + numRowsGrid * (CARD_H + CARD_PAD)
                           + BOTTOM_PAD
        f:SetSize(frameW, frameH)

        for i, cd in ipairs(CT.expandedCooldowns) do
            local col = (i - 1) % cols
            local row = math.floor((i - 1) / cols)
            local r   = CT.rows[cd.id]
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", f, "TOPLEFT",
                CARD_PAD + col * (CARD_W + CARD_PAD),
                -(TITLE_HEIGHT + CARD_PAD + row * (CARD_H + CARD_PAD)))
            ApplyCardLayout(r, CARD_W, CARD_H)
        end
    end
end

-- ---------------------------------------------------------------------------
-- Public: CT:UpdateAllRows()
-- ---------------------------------------------------------------------------
function CT:UpdateAllRows()
    local now = GetTime()
    for _, cd in ipairs(CT.expandedCooldowns) do
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
-- Public: CT:BuildUI()
-- ---------------------------------------------------------------------------
function CT:BuildUI()
    CT.rows = {}

    local f = CreateFrame("Frame", "CooldownTrackerFrame", UIParent, "BackdropTemplate")
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self)
        if not CooldownTrackerDB.frameLocked then self:StartMoving() end
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition(self)
    end)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)

    if f.SetBackdrop then
        f:SetBackdrop({
            bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile     = true, tileSize = 16, edgeSize = 16,
            insets   = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        f:SetBackdropColor(0.05, 0.05, 0.08, 0.55)
        f:SetBackdropBorderColor(0.3, 0.3, 0.4, 0.8)
    end

    -- Title bar background
    local titleBg = f:CreateTexture(nil, "BACKGROUND")
    titleBg:SetHeight(TITLE_HEIGHT)
    titleBg:SetPoint("TOPLEFT",  f, "TOPLEFT",  0, 0)
    titleBg:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    titleBg:SetColorTexture(0.08, 0.08, 0.15, 0.65)

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

    -- Lock button
    local lockBtn = CreateFrame("Button", nil, f)
    lockBtn:SetSize(32, 32)
    lockBtn:SetPoint("TOPRIGHT", closeBtn, "TOPLEFT", -2, 0)

    local lockTex = lockBtn:CreateTexture(nil, "ARTWORK")
    lockTex:SetAllPoints(lockBtn)
    lockBtn.lockTex = lockTex

    local function UpdateLockVisual()
        if CooldownTrackerDB.frameLocked then
            lockTex:SetTexture("Interface\\BUTTONS\\LockButton-Locked-Up")
            lockTex:SetVertexColor(0.9, 0.7, 0.2)
        else
            lockTex:SetTexture("Interface\\BUTTONS\\LockButton-Unlocked-Up")
            lockTex:SetVertexColor(0.6, 0.6, 0.6)
        end
    end

    lockBtn:SetScript("OnClick", function()
        CooldownTrackerDB.frameLocked = not CooldownTrackerDB.frameLocked
        f:SetMovable(not CooldownTrackerDB.frameLocked)
        UpdateLockVisual()
    end)
    lockBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(lockBtn, "ANCHOR_BOTTOMLEFT")
        if CooldownTrackerDB.frameLocked then
            GameTooltip:SetText("Frame Locked")
            GameTooltip:AddLine("Click to unlock and allow dragging.", 0.8, 0.8, 0.8)
        else
            GameTooltip:SetText("Frame Unlocked")
            GameTooltip:AddLine("Click to lock the frame in place.", 0.8, 0.8, 0.8)
        end
        GameTooltip:Show()
    end)
    lockBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Apply saved lock state
    f:SetMovable(not CooldownTrackerDB.frameLocked)
    UpdateLockVisual()

    -- Divider
    local divider = f:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT",  f, "TOPLEFT",  0, -TITLE_HEIGHT)
    divider:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -TITLE_HEIGHT)
    divider:SetColorTexture(0.3, 0.3, 0.5, 0.6)

    -- Create initial rows and pool
    CT.pool = {}
    for i, cd in ipairs(CT.expandedCooldowns) do
        local row = CreateRow(f, cd)
        CT.pool[i] = row
    end

    -- Build CT.rows from the initial expanded list
    CT.rows = {}
    for i, cd in ipairs(CT.expandedCooldowns) do
        CT.rows[cd.id] = CT.pool[i]
    end

    f:SetScript("OnUpdate", function() CT:UpdateAllRows() end)
    f:Hide()
    CT.mainFrame = f

    -- Apply layout (reads CooldownTrackerDB.columns, defaults to 1)
    CT:LayoutRows()
end

