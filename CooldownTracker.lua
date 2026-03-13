--------------------------------------------------------------------------------
-- CooldownTracker.lua
-- Raid leader tool: manually mark when a healer uses a cooldown, then track
-- the remaining time until that cooldown is available again.
--
-- Usage: /cdt  or  /cooldowntracker  to toggle the window.
-- Click "Used" next to an ability to start its cooldown timer.
-- Click "Reset" to cancel a running timer early.
--------------------------------------------------------------------------------

local ADDON_NAME = "CooldownTracker"

-- ---------------------------------------------------------------------------
-- Cooldown definitions
-- Add new entries here to track more abilities. "duration" is in seconds.
-- ---------------------------------------------------------------------------
local COOLDOWNS = {
    {
        id       = "druid_convoke",
        class    = "Druid",
        name     = "Convoke the Spirits",
        duration = 60,
        icon     = "Interface\\Icons\\spell_ardenweald_druid",
        r        = 0.4, g = 0.8, b = 0.4,   -- green accent
    },
    {
        id       = "druid_tranquility",
        class    = "Druid",
        name     = "Tranquility",
        duration = 180,
        icon     = "Interface\\Icons\\spell_nature_tranquility",
        r        = 0.4, g = 0.6, b = 1.0,   -- blue accent
    },
}

-- ---------------------------------------------------------------------------
-- Runtime state
-- ---------------------------------------------------------------------------
local activeTimers = {}  -- [cd.id] = endTime (GetTime() + duration)

-- ---------------------------------------------------------------------------
-- Helpers
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

-- ---------------------------------------------------------------------------
-- Saved Variables / Position persistence
-- ---------------------------------------------------------------------------
local function SavePosition(frame)
    CooldownTrackerDB = CooldownTrackerDB or {}
    local point, _, relPoint, x, y = frame:GetPoint()
    CooldownTrackerDB.point    = point
    CooldownTrackerDB.relPoint = relPoint
    CooldownTrackerDB.x        = x
    CooldownTrackerDB.y        = y
end

local function RestorePosition(frame)
    local db = CooldownTrackerDB
    if db and db.point then
        frame:ClearAllPoints()
        frame:SetPoint(db.point, UIParent, db.relPoint, db.x, db.y)
    end
end

-- ---------------------------------------------------------------------------
-- Row widgets (one per cooldown entry)
-- Each row stores references at: row.cd, row.iconTex, row.nameLabel,
--   row.timerLabel, row.bar, row.barFill, row.button
-- ---------------------------------------------------------------------------
local rows = {}

local ROW_HEIGHT    = 36
local ROW_PADDING   = 6
local FRAME_WIDTH   = 300
local ICON_SIZE     = 28
local BUTTON_WIDTH  = 52
local TITLE_HEIGHT  = 24
local BOTTOM_PAD    = 8

local function UpdateRow(row, now)
    local cd      = row.cd
    local endTime = activeTimers[cd.id]

    if endTime then
        local remaining = endTime - now
        if remaining <= 0 then
            -- Just finished
            activeTimers[cd.id] = nil
            row.timerLabel:SetText("|cff00ff00Ready|r")
            row.timerLabel:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
            row.barFill:SetWidth(row.bar:GetWidth())
            row.barFill:SetVertexColor(0.2, 0.9, 0.2)
            row.button:SetText("Used")
            SetBtnColor(row.button, 0.3, 0.85, 0.3)
            -- Flash the icon
            row.iconTex:SetAlpha(1)
            -- Play a subtle ready sound (built-in WoW sound)
            PlaySound(SOUNDKIT.ALARM_CLOCK_WARNING_3)
        else
            -- Counting down
            local frac = remaining / cd.duration
            local barW = math.max(2, row.bar:GetWidth() * frac)
            row.barFill:SetWidth(barW)
            -- Colour: red when <25% left, yellow <50%, accent colour otherwise
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

    -- Icon
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetPoint("LEFT", row, "LEFT", 7, 0)
    icon:SetTexture(cd.icon)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.iconTex = icon

    -- Name label
    local nameLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameLabel:SetPoint("LEFT", icon, "RIGHT", 6, 4)
    nameLabel:SetText(cd.name)
    nameLabel:SetTextColor(1, 1, 1)
    nameLabel:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")

    -- Class tag (small, below name)
    local classLabel = row:CreateFontString(nil, "OVERLAY")
    classLabel:SetPoint("LEFT", icon, "RIGHT", 6, -6)
    classLabel:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    classLabel:SetText(cd.class)
    classLabel:SetTextColor(cd.r, cd.g, cd.b)

    -- Timer label (right-aligned, left of button)
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

    -- Button
    local btn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    btn:SetSize(BUTTON_WIDTH, 22)
    btn:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    btn:SetText("Used")
    SetBtnColor(btn, 0.3, 0.85, 0.3)
    btn:SetScript("OnClick", function()
        if activeTimers[cd.id] then
            -- Reset
            activeTimers[cd.id] = nil
        else
            -- Start timer
            activeTimers[cd.id] = GetTime() + cd.duration
        end
        UpdateRow(row, GetTime())
    end)
    row.button = btn

    -- Hover highlight
    row:SetScript("OnEnter", function()
        bg:SetColorTexture(cd.r * 0.15, cd.g * 0.15, cd.b * 0.15, 0.5)
        GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
        GameTooltip:SetText(cd.name)
        GameTooltip:AddLine("Class: " .. cd.class, 1, 1, 1)
        local dur = cd.duration
        local m   = math.floor(dur / 60)
        local s   = dur % 60
        if m > 0 and s > 0 then
            GameTooltip:AddLine(string.format("Cooldown: %dm %ds", m, s), 0.8, 0.8, 0.8)
        elseif m > 0 then
            GameTooltip:AddLine(string.format("Cooldown: %d minute%s", m, m > 1 and "s" or ""), 0.8, 0.8, 0.8)
        else
            GameTooltip:AddLine(string.format("Cooldown: %ds", s), 0.8, 0.8, 0.8)
        end
        GameTooltip:AddLine(" ")
        if activeTimers[cd.id] then
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

    rows[cd.id] = row
    return row
end

-- ---------------------------------------------------------------------------
-- Main frame
-- ---------------------------------------------------------------------------
local totalRows   = #COOLDOWNS
local frameHeight = TITLE_HEIGHT + ROW_PADDING + totalRows * (ROW_HEIGHT + ROW_PADDING) + BOTTOM_PAD

local mainFrame = CreateFrame("Frame", "CooldownTrackerFrame", UIParent, "BackdropTemplate")
mainFrame:SetSize(FRAME_WIDTH, frameHeight)
mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
mainFrame:SetMovable(true)
mainFrame:EnableMouse(true)
mainFrame:RegisterForDrag("LeftButton")
mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
mainFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SavePosition(self)
end)
mainFrame:SetFrameStrata("MEDIUM")
mainFrame:SetClampedToScreen(true)

-- Backdrop (dark glass panel)
if mainFrame.SetBackdrop then
    mainFrame:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile     = true, tileSize = 16, edgeSize = 16,
        insets   = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    mainFrame:SetBackdropColor(0.05, 0.05, 0.08, 0.92)
    mainFrame:SetBackdropBorderColor(0.3, 0.3, 0.4, 0.8)
end

-- Title bar background
local titleBg = mainFrame:CreateTexture(nil, "BACKGROUND")
titleBg:SetHeight(TITLE_HEIGHT)
titleBg:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 0, 0)
titleBg:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", 0, 0)
titleBg:SetColorTexture(0.08, 0.08, 0.15, 0.95)

-- Title text
local titleText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
titleText:SetPoint("CENTER", titleBg, "CENTER", 0, 0)
titleText:SetText("|cff55ff55+|r |cffaaddffHealer Cooldowns|r")
titleText:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")

-- Close button
local closeBtn = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
closeBtn:SetSize(18, 18)
closeBtn:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -2, -3)
closeBtn:SetScript("OnClick", function() mainFrame:Hide() end)

-- Divider line under title
local divider = mainFrame:CreateTexture(nil, "ARTWORK")
divider:SetHeight(1)
divider:SetPoint("TOPLEFT",  mainFrame, "TOPLEFT",  0, -TITLE_HEIGHT)
divider:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", 0, -TITLE_HEIGHT)
divider:SetColorTexture(0.3, 0.3, 0.5, 0.6)

-- Create a row for each cooldown
for i, cd in ipairs(COOLDOWNS) do
    CreateRow(mainFrame, cd, i)
end

-- OnUpdate: refresh all rows every frame (cheap — just string/number math)
mainFrame:SetScript("OnUpdate", function()
    local now = GetTime()
    for _, cd in ipairs(COOLDOWNS) do
        local row = rows[cd.id]
        if row then
            UpdateRow(row, now)
        end
    end
end)

-- Hide by default; show on slash command
mainFrame:Hide()

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(_, event, addonName)
    if event == "ADDON_LOADED" and addonName == ADDON_NAME then
        CooldownTrackerDB = CooldownTrackerDB or {}
        RestorePosition(mainFrame)
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
        -- Reset all timers
        for _, cd in ipairs(COOLDOWNS) do
            activeTimers[cd.id] = nil
        end
        print("|cffaaddff[CooldownTracker]|r All timers reset.")
    else
        -- Toggle visibility
        if mainFrame:IsShown() then
            mainFrame:Hide()
        else
            mainFrame:Show()
        end
    end
end
