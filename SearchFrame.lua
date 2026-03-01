local L   = LibStub("AceLocale-3.0"):GetLocale("Brannfred")
local MSQ = LibStub("Masque", true)

Brannfred.searchFrame = CreateFrame("Frame", "BrannfredSearchFrame", UIParent, "BackdropTemplate")

local main_font = "fonts/frizqt__.ttf"

local frame = Brannfred.searchFrame
frame:SetSize(420, 46)
frame:SetPoint("TOP", UIParent, "TOP", 0, -280)
frame:SetFrameStrata("HIGH")
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
frame:SetBackdrop({ edgeFile = "Interface/Buttons/WHITE8X8", edgeSize = 1 })
frame:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
-- Background as a separate BACKGROUND-layer texture so it never covers the border
local frameBg = frame:CreateTexture(nil, "BACKGROUND")
frameBg:SetColorTexture(0.07, 0.07, 0.07, 0.93)
frameBg:SetPoint("TOPLEFT",     frame, "TOPLEFT",     1, -1)
frameBg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
frame:Hide()

-- EditBox
Brannfred.searchEditBox = CreateFrame("EditBox", "BrannfredSearchEditBox", frame)
local editBox = Brannfred.searchEditBox
editBox:SetSize(390, 30)
editBox:SetPoint("CENTER", frame, "CENTER")
editBox:SetAutoFocus(false)
editBox:SetPropagateKeyboardInput(false)
editBox:SetFont(main_font, 15, "")
editBox:SetTextColor(0.95, 0.95, 0.95, 1)

-- Constants
local MAX_RESULTS    = 50
local VISIBLE_ROWS   = 10  -- may be updated by ApplyFrameSettings
local CONTENT_PAD    = 1   -- may be updated by ApplyFrameSettings
local ROW_HEIGHT     = 32

-- Type label lookup: reads the label field each provider declares
local function getTypeLabel(entryType)
    for _, provider in ipairs(Brannfred.providers) do
        if provider.type == entryType then
            return provider.label or ""
        end
    end
    return ""
end

-- State
local currentResults = {}
local selectedIndex  = 1
local masqueGroup    = nil

-- Forward declarations
local selectRow, showDescription, updateScrollBar

-- Shared backdrop helper — border only, background handled by a separate texture
local BACKDROP = { edgeFile = "Interface/Buttons/WHITE8X8", edgeSize = 1 }
local function applyBackdrop(f)
    f:SetBackdrop(BACKDROP)
    f:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
end

-- ── Results dropdown ──────────────────────────────────────────────────────────
local resultsFrame = CreateFrame("Frame", "BrannfredResultsFrame", frame, "BackdropTemplate")
resultsFrame:SetWidth(420)
resultsFrame:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -2)
resultsFrame:SetFrameStrata("HIGH")
applyBackdrop(resultsFrame)
local resultsBg = resultsFrame:CreateTexture(nil, "BACKGROUND")
resultsBg:SetColorTexture(0.07, 0.07, 0.07, 0.93)
resultsBg:SetPoint("TOPLEFT",     resultsFrame, "TOPLEFT",     1, -1)
resultsBg:SetPoint("BOTTOMRIGHT", resultsFrame, "BOTTOMRIGHT", -1, 1)
resultsFrame:Hide()

-- ScrollFrame (clips rows to the visible area)
local scrollFrame = CreateFrame("ScrollFrame", nil, resultsFrame)
scrollFrame:SetPoint("TOPLEFT", resultsFrame, "TOPLEFT", 1, -1)
scrollFrame:SetPoint("BOTTOMRIGHT", resultsFrame, "BOTTOMRIGHT", -5, 1)
scrollFrame:EnableMouseWheel(true)
scrollFrame:SetScript("OnMouseWheel", function(self, delta)
    local cur = self:GetVerticalScroll()
    local max = self:GetVerticalScrollRange()
    self:SetVerticalScroll(math.max(0, math.min(max, cur - delta * ROW_HEIGHT)))
    updateScrollBar()
end)

local scrollChild = CreateFrame("Frame")
scrollChild:SetWidth(414) -- 420 - 1 border - 5 right (scrollbar area)
scrollFrame:SetScrollChild(scrollChild)

-- Scrollbar track + thumb (4 px strip on the right edge of resultsFrame)
local sbTrack = resultsFrame:CreateTexture(nil, "OVERLAY")
sbTrack:SetWidth(4)
sbTrack:SetColorTexture(0.12, 0.12, 0.12, 0.9)
sbTrack:SetPoint("TOPRIGHT", resultsFrame, "TOPRIGHT", -1, -1)
sbTrack:SetPoint("BOTTOMRIGHT", resultsFrame, "BOTTOMRIGHT", -1, 1)
sbTrack:Hide()

local sbThumb = resultsFrame:CreateTexture(nil, "OVERLAY")
sbThumb:SetWidth(4)
sbThumb:SetColorTexture(0.55, 0.55, 0.55, 0.9)
sbThumb:Hide()

updateScrollBar = function()
    local total = #currentResults
    if total <= VISIBLE_ROWS then
        sbTrack:Hide()
        sbThumb:Hide()
        return
    end
    sbTrack:Show()
    sbThumb:Show()
    local trackH = VISIBLE_ROWS * ROW_HEIGHT
    local thumbH = math.max(16, trackH * VISIBLE_ROWS / total)
    sbThumb:SetHeight(thumbH)
    local range = scrollFrame:GetVerticalScrollRange()
    local frac  = (range > 0) and (scrollFrame:GetVerticalScroll() / range) or 0
    sbThumb:ClearAllPoints()
    sbThumb:SetPoint("TOPRIGHT", resultsFrame, "TOPRIGHT", -CONTENT_PAD, -CONTENT_PAD - frac * (trackH - thumbH))
end

-- ── Description panel ─────────────────────────────────────────────────────────
local descFrame = CreateFrame("Frame", "BrannfredDescFrame", frame, "BackdropTemplate")
descFrame:SetWidth(420)
descFrame:SetPoint("TOPLEFT", resultsFrame, "BOTTOMLEFT", 0, -2)
descFrame:SetFrameStrata("HIGH")
applyBackdrop(descFrame)
local descBg = descFrame:CreateTexture(nil, "BACKGROUND")
descBg:SetColorTexture(0.07, 0.07, 0.07, 0.93)
descBg:SetPoint("TOPLEFT",     descFrame, "TOPLEFT",     1, -1)
descBg:SetPoint("BOTTOMRIGHT", descFrame, "BOTTOMRIGHT", -1, 1)
descFrame:Hide()

local descIconBtn = CreateFrame("Button", nil, descFrame)
descIconBtn:SetSize(48, 48)
descIconBtn:SetPoint("TOPLEFT", descFrame, "TOPLEFT", 8, -8)
descIconBtn:EnableMouse(true)
local descIcon = descIconBtn:CreateTexture(nil, "ARTWORK")
descIcon:SetAllPoints()
descIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

local descEntry = nil
descIconBtn:SetScript("OnEnter", function(self)
    if descEntry and descEntry.onIconTooltip then
        descEntry.onIconTooltip(self)
    end
end)
descIconBtn:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

local descName = descFrame:CreateFontString(nil, "OVERLAY")
descName:SetFont(main_font, 14, "OUTLINE")
descName:SetTextColor(1, 0.82, 0, 1)
descName:SetPoint("TOPLEFT", descFrame, "TOPLEFT", 64, -10)
descName:SetPoint("TOPRIGHT", descFrame, "TOPRIGHT", -8, -10)
descName:SetJustifyH("LEFT")
descName:SetWordWrap(false)

local descStats = descFrame:CreateFontString(nil, "OVERLAY")
descStats:SetFont(main_font, 11, "")
descStats:SetTextColor(0.7, 0.7, 0.7, 1)
descStats:SetPoint("TOPLEFT", descFrame, "TOPLEFT", 64, -32)
descStats:SetPoint("TOPRIGHT", descFrame, "TOPRIGHT", -8, -32)
descStats:SetJustifyH("LEFT")
descStats:SetWordWrap(true)
descStats:SetWidth(348)

local sep = descFrame:CreateTexture(nil, "BACKGROUND")
sep:SetHeight(1)
sep:SetColorTexture(0.25, 0.25, 0.25, 1)
sep:SetPoint("TOPLEFT", descFrame, "TOPLEFT", 8, -64)
sep:SetPoint("TOPRIGHT", descFrame, "TOPRIGHT", -8, -64)

local descText = descFrame:CreateFontString(nil, "OVERLAY")
descText:SetFont(main_font, 12, "")
descText:SetTextColor(0.85, 0.85, 0.85, 1)
descText:SetPoint("TOPLEFT", descFrame, "TOPLEFT", 8, -72)
descText:SetWidth(404)
descText:SetJustifyH("LEFT")
descText:SetJustifyV("TOP")
descText:SetWordWrap(true)
descText:SetNonSpaceWrap(false)

-- ── Rows ──────────────────────────────────────────────────────────────────────
local rows = {}
for i = 1, MAX_RESULTS do
    local row = CreateFrame("Button", nil, scrollChild)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
    row:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, -(i - 1) * ROW_HEIGHT)

    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.08)

    local sel = row:CreateTexture(nil, "BACKGROUND")
    sel:SetAllPoints()
    sel:SetColorTexture(0.2, 0.6, 1, 0.18)
    sel:Hide()
    row.selTex = sel

    -- Dedicated Button child so Masque can skin only the icon area
    local iconBtn = CreateFrame("Button", nil, row)
    iconBtn:SetSize(22, 22)
    iconBtn:SetPoint("LEFT", row, "LEFT", 6, 0)
    iconBtn:EnableMouse(true)
    local icon = iconBtn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.iconBtn = iconBtn
    row.icon    = icon
    iconBtn:SetScript("OnEnter", function(self)
        if row.entry then
            selectRow(i)
            if row.entry.onIconTooltip then
                row.entry.onIconTooltip(self)
            end
        end
    end)
    iconBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Type label (right-aligned, gray)
    local typeLabel = row:CreateFontString(nil, "OVERLAY")
    typeLabel:SetFont(main_font, 10, "")
    typeLabel:SetTextColor(0.45, 0.45, 0.45, 1)
    typeLabel:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    typeLabel:SetWidth(0)
    typeLabel:SetJustifyH("RIGHT")
    row.typeLabel = typeLabel

    -- Optional meta label (provider-defined short info, e.g. slot count)
    local metaLabel = row:CreateFontString(nil, "OVERLAY")
    metaLabel:SetFont(main_font, 11, "")
    metaLabel:SetTextColor(0.65, 0.65, 0.65, 1)
    metaLabel:SetPoint("RIGHT", typeLabel, "LEFT", -8, 0)
    metaLabel:SetWidth(70)
    metaLabel:SetJustifyH("RIGHT")
    row.metaLabel = metaLabel

    local text = row:CreateFontString(nil, "OVERLAY")
    text:SetFont(main_font, 13, "")
    text:SetTextColor(0.95, 0.95, 0.95, 1)
    text:SetPoint("LEFT", icon, "RIGHT", 7, 0)
    text:SetPoint("RIGHT", metaLabel, "LEFT", -4, 0)
    text:SetJustifyH("LEFT")
    row.text = text

    row.entry = nil

    local rowIndex = i
    row:SetScript("OnEnter", function(self)
        if self.entry then selectRow(rowIndex) end
    end)

    row:SetScript("OnClick", function(self)
        if self.entry then
            if self.entry._insertText then
                editBox:SetText(self.entry._insertText)
                editBox:SetFocus()
                return
            end
            if IsShiftKeyDown() and self.entry.onShiftActivate then
                frame:Hide()
                self.entry.onShiftActivate()
                return
            end
            if IsControlKeyDown() and self.entry.onCtrlActivate then
                local keepOpen = type(self.entry.ctrlKeepsOpen) == "function" and self.entry.ctrlKeepsOpen() or self.entry.ctrlKeepsOpen
                if not keepOpen then frame:Hide() end
                self.entry.onCtrlActivate()
                return
            end
            if IsAltKeyDown() and self.entry.onAltActivate then
                frame:Hide()
                self.entry.onAltActivate()
                return
            end
            Brannfred.AddToHistory(self.entry)
            if self.entry.onActivate then self.entry.onActivate() end
        end
        frame:Hide()
    end)

    row:RegisterForDrag("LeftButton")
    row:SetScript("OnDragStart", function(self)
        if self.entry and self.entry.onDrag then
            Brannfred.AddToHistory(self.entry)
            self.entry.onDrag()
            local p = Brannfred.db and Brannfred.db.profile
            local key = "closeOnDrag_" .. (self.entry.type or "")
            if not p or p[key] ~= false then
                frame:Hide()
            end
        end
    end)

    rows[i] = row
end

-- ── showDescription ───────────────────────────────────────────────────────────
showDescription = function(entry)
    if not entry or entry._noPreview then
        descFrame:Hide()
        descEntry = nil
        return
    end

    descEntry = entry
    descIcon:SetTexture(entry.icon)
    local dic = entry.iconColor
    descIcon:SetVertexColor(dic and dic.r or 1, dic and dic.g or 1, dic and dic.b or 1)
    descName:SetText(entry.name)
    local nc = entry.color
    descName:SetTextColor(nc and nc.r or 1, nc and nc.g or 0.82, nc and nc.b or 0, 1)

    local statsStr = entry.getStats and entry.getStats() or ""
    descStats:SetText(statsStr)
    descStats:SetShown(statsStr ~= "")

    local desc = entry.getDesc and entry.getDesc() or ""
    if desc ~= "" then
        descText:SetText(desc)
        local descH = descText:GetStringHeight()
        descFrame:SetHeight(CONTENT_PAD * 2 + 68 + descH)
        sep:Show()
        descText:Show()
    else
        descFrame:SetHeight(CONTENT_PAD * 2 + 60)
        sep:Hide()
        descText:Hide()
    end

    descFrame:Show()
end

-- ── selectRow ─────────────────────────────────────────────────────────────────
selectRow = function(index)
    selectedIndex = index
    for i = 1, MAX_RESULTS do
        rows[i].selTex:SetShown(i == index)
    end
    local rowTop    = (index - 1) * ROW_HEIGHT
    local rowBottom = index * ROW_HEIGHT
    local cur       = scrollFrame:GetVerticalScroll()
    local visH      = VISIBLE_ROWS * ROW_HEIGHT
    if rowTop < cur then
        scrollFrame:SetVerticalScroll(rowTop)
    elseif rowBottom > cur + visH then
        scrollFrame:SetVerticalScroll(rowBottom - visH)
    end
    updateScrollBar()
    if currentResults[index] then
        showDescription(currentResults[index].entry)
    else
        descFrame:Hide()
    end
end

-- ── updateResults ─────────────────────────────────────────────────────────────
local function updateResults(query)
    for i = 1, MAX_RESULTS do rows[i]:Hide() end

    if query:match("^%s*$") then
        currentResults = {}
        resultsFrame:Hide()
        descFrame:Hide()
        return
    end

    currentResults = Brannfred.Search(query, MAX_RESULTS)
    local count = #currentResults

    if count == 0 then
        resultsFrame:Hide()
        descFrame:Hide()
        return
    end

    for i = 1, count do
        local entry = currentResults[i].entry
        local c = entry.color
        rows[i].entry = entry
        rows[i].icon:SetTexture(entry.icon)
        local ic = entry.iconColor
        rows[i].icon:SetVertexColor(ic and ic.r or 1, ic and ic.g or 1, ic and ic.b or 1)
        rows[i].text:SetText(entry.name)
        rows[i].text:SetTextColor(c and c.r or 0.95, c and c.g or 0.95, c and c.b or 0.95, 1)
        rows[i].typeLabel:SetText(getTypeLabel(entry._originalType or entry.type))
        rows[i].typeLabel:SetWidth(rows[i].typeLabel:GetStringWidth() + 4)
        local lc = entry.labelColor
        rows[i].typeLabel:SetTextColor(lc and lc.r or 0.45, lc and lc.g or 0.45, lc and lc.b or 0.45, 1)
        rows[i].metaLabel:SetText(entry.getMeta and entry.getMeta() or "")
        rows[i]:Show()
    end

    local vis = math.min(count, VISIBLE_ROWS)
    scrollChild:SetHeight(count * ROW_HEIGHT)
    scrollFrame:SetVerticalScroll(0)
    resultsFrame:SetHeight(vis * ROW_HEIGHT + 2)
    resultsFrame:Show()
    selectRow(1)
end

-- ── EditBox scripts ───────────────────────────────────────────────────────────
-- ── Placeholder ───────────────────────────────────────────────────────────────
local placeholder = frame:CreateFontString(nil, "OVERLAY")
placeholder:SetFont(main_font, 15, "")
placeholder:SetTextColor(0.45, 0.45, 0.45, 1)
placeholder:SetText(L["Search..."])
placeholder:SetPoint("LEFT", editBox, "LEFT", 0, 0)
placeholder:SetJustifyH("LEFT")

editBox:SetScript("OnTextChanged", function(self)
    placeholder:SetShown(self:GetText() == "")
    updateResults(self:GetText())
end)

editBox:SetScript("OnKeyDown", function(self, key)
    if key == "ENTER" then
        local selected = currentResults[selectedIndex]
        if selected then
            if selected.entry._insertText then
                editBox:SetText(selected.entry._insertText)
                editBox:SetFocus()
                self:SetPropagateKeyboardInput(false)
                return
            end
            if IsShiftKeyDown() and selected.entry.onShiftActivate then
                frame:Hide()
                selected.entry.onShiftActivate()
                self:SetPropagateKeyboardInput(false)
                return
            end
            if IsControlKeyDown() and selected.entry.onCtrlActivate then
                local keepOpen = type(selected.entry.ctrlKeepsOpen) == "function" and selected.entry.ctrlKeepsOpen() or selected.entry.ctrlKeepsOpen
                if not keepOpen then frame:Hide() end
                selected.entry.onCtrlActivate()
                self:SetPropagateKeyboardInput(false)
                return
            end
            if IsAltKeyDown() and selected.entry.onAltActivate then
                frame:Hide()
                selected.entry.onAltActivate()
                self:SetPropagateKeyboardInput(false)
                return
            end
            Brannfred.AddToHistory(selected.entry)
            if selected.entry.onActivate then selected.entry.onActivate() end
        end
        frame:Hide()
        self:SetPropagateKeyboardInput(false)
        return
    end
    if resultsFrame:IsShown() then
        if key == "UP" then
            local count = math.min(#currentResults, MAX_RESULTS)
            selectRow(selectedIndex > 1 and selectedIndex - 1 or count)
            self:SetPropagateKeyboardInput(false)
            return
        elseif key == "DOWN" then
            local count = math.min(#currentResults, MAX_RESULTS)
            selectRow(selectedIndex < count and selectedIndex + 1 or 1)
            self:SetPropagateKeyboardInput(false)
            return
        end
    end
    local mod = (IsShiftKeyDown() and "SHIFT-" or "")
        .. (IsControlKeyDown() and "CTRL-" or "")
        .. (IsAltKeyDown() and "ALT-" or "")
    local action = GetBindingAction(mod .. key)
    self:SetPropagateKeyboardInput(action == "CLICK BrannfredToggleButton:LeftButton")
end)

editBox:SetScript("OnEscapePressed", function()
    frame:Hide()
end)

editBox:EnableMouseWheel(true)
editBox:SetScript("OnMouseWheel", function(_, delta)
    if resultsFrame:IsShown() then
        local cur = scrollFrame:GetVerticalScroll()
        local max = scrollFrame:GetVerticalScrollRange()
        scrollFrame:SetVerticalScroll(math.max(0, math.min(max, cur - delta * ROW_HEIGHT)))
        updateScrollBar()
    end
end)


frame:SetScript("OnHide", function()
    resultsFrame:Hide()
    descFrame:Hide()
    scrollFrame:SetVerticalScroll(0)
    editBox:SetText("")
    editBox:ClearFocus()
end)

-- Visual inset ratio per border texture: fraction of edgeSize that is actually
-- opaque border pixels.  Used to position the bg texture so it meets the visible
-- inner edge of the border (and not the transparent inner area of the 9-slice).
local TEXTURE_INSET_RATIO = {
    ["Interface/Buttons/WHITE8X8"]                        = 1.0,   -- solid: full edgeSize
    ["Interface/Tooltips/UI-Tooltip-Border"]              = 5/16,  -- native inset=5, size=16
    ["Interface/DialogFrame/UI-DialogBox-Border"]         = 11/32, -- native inset=11, size=32
    ["Interface/DialogFrame/UI-DialogBox-Gold-Border"]    = 11/32,
    ["Interface/FriendsFrame/UI-Toast-Border"]            = 4/12,  -- native inset=4, size=12
}

local function bgInset(btex, bs)
    if bs == 0 or btex == "none" then return 0 end
    local r = TEXTURE_INSET_RATIO[btex] or (1/3)
    return (r == 1.0) and bs or math.max(1, math.ceil(bs * r))
end

-- ── ApplyFrameSettings ────────────────────────────────────────────────────────
-- Called from Core.lua:OnEnable and whenever appearance/position options change.
-- Has full closure access to all local frame variables.
function Brannfred.ApplyFrameSettings() ---@diagnostic disable-line: duplicate-set-field
    if not Brannfred.db then return end
    local p     = Brannfred.db.profile or {}
    local w     = p.frameWidth  or 420
    local fpath = p.fontPath    or "fonts/frizqt__.ttf"
    local fsize = p.fontSize    or 13

    -- Width (results/desc follow the main frame width)
    frame:SetWidth(w)
    resultsFrame:SetWidth(w)
    descFrame:SetWidth(w)
    editBox:SetWidth(w - 30)

    -- Fonts
    editBox:SetFont(fpath, fsize + 2, "")
    placeholder:SetFont(fpath, fsize + 2, "")
    for _, row in ipairs(rows) do
        row.text:SetFont(fpath, fsize, "")
        row.typeLabel:SetFont(fpath, math.max(6, fsize - 3), "")
        row.metaLabel:SetFont(fpath, math.max(6, fsize - 2), "")
    end
    descName:SetFont(fpath, fsize + 1, "OUTLINE")
    descStats:SetFont(fpath, math.max(6, fsize - 2), "")
    descText:SetFont(fpath, math.max(6, fsize - 1), "")

    -- Visible rows + content padding
    VISIBLE_ROWS = p.visibleRows    or 10
    CONTENT_PAD  = p.contentPadding or (p.borderSize or 1)
    local cp = CONTENT_PAD

    -- Border
    local bs   = p.borderSize    or 1
    local btex = p.borderTexture or "Interface/Buttons/WHITE8X8"
    local edgeFile = (btex == "none" or bs == 0) and "" or btex
    local bd       = { edgeFile = edgeFile, edgeSize = bs }

    local bgr, bgg, bgb, bga = p.bgR    or 0.07, p.bgG    or 0.07, p.bgB    or 0.07, p.bgA    or 0.93
    local bdr, bdg, bdb, bda = p.borderR or 0.25, p.borderG or 0.25, p.borderB or 0.25, p.borderA or 1.0

    -- Background textures: inset by the VISUAL border width (not full edgeSize)
    -- so the bg meets the visible inner edge of the border without a gap.
    local bgi = bgInset(btex, bs)
    for _, bg in ipairs({ frameBg, resultsBg, descBg }) do
        bg:ClearAllPoints()
        bg:SetPoint("TOPLEFT",     bg:GetParent(), "TOPLEFT",     bgi, -bgi)
        bg:SetPoint("BOTTOMRIGHT", bg:GetParent(), "BOTTOMRIGHT", -bgi, bgi)
        bg:SetColorTexture(bgr, bgg, bgb, bga)
    end

    for _, f in ipairs({ frame, resultsFrame, descFrame }) do
        f:SetBackdrop(bd)
        f:SetBackdropBorderColor(bdr, bdg, bdb, bda)
    end

    -- scrollFrame + scrollbar: inset by content padding
    scrollFrame:ClearAllPoints()
    scrollFrame:SetPoint("TOPLEFT",     resultsFrame, "TOPLEFT",     cp,      -cp)
    scrollFrame:SetPoint("BOTTOMRIGHT", resultsFrame, "BOTTOMRIGHT", -(cp+4),  cp)
    scrollChild:SetWidth(w - cp * 2 - 4)

    sbTrack:ClearAllPoints()
    sbTrack:SetPoint("TOPRIGHT",    resultsFrame, "TOPRIGHT",    -cp,  -cp)
    sbTrack:SetPoint("BOTTOMRIGHT", resultsFrame, "BOTTOMRIGHT", -cp,   cp)

    -- Description panel elements: reanchor to content padding
    -- Icon gets 6 px of extra inset on all sides for visual breathing room.
    local ii = 6  -- icon inset
    descIconBtn:ClearAllPoints()
    descIconBtn:SetPoint("TOPLEFT", descFrame, "TOPLEFT", cp + ii, -(cp + ii))

    descName:ClearAllPoints()
    descName:SetPoint("TOPLEFT",  descFrame, "TOPLEFT",  cp + ii + 48 + 8, -(cp + ii))
    descName:SetPoint("TOPRIGHT", descFrame, "TOPRIGHT", -cp,               -(cp + ii))

    descStats:ClearAllPoints()
    descStats:SetPoint("TOPLEFT",  descFrame, "TOPLEFT",  cp + ii + 48 + 8, -(cp + ii + 18))
    descStats:SetPoint("TOPRIGHT", descFrame, "TOPRIGHT", -cp,               -(cp + ii + 18))
    descStats:SetWidth(w - cp * 2 - ii - 48 - 8)

    sep:ClearAllPoints()
    sep:SetPoint("TOPLEFT",  descFrame, "TOPLEFT",  cp,  -(cp + ii + 48 + ii))
    sep:SetPoint("TOPRIGHT", descFrame, "TOPRIGHT", -cp, -(cp + ii + 48 + ii))

    descText:ClearAllPoints()
    descText:SetPoint("TOPLEFT", descFrame, "TOPLEFT", cp, -(cp + ii + 48 + ii + 8))
    descText:SetWidth(w - cp * 2)

    -- Masque icon skins (optional)
    if MSQ and p.useMasque then
        if not masqueGroup then
            masqueGroup = MSQ:Group("Brannfred", "Icons")
            masqueGroup:AddButton(descIconBtn, { Icon = descIcon })
            for _, row in ipairs(rows) do
                masqueGroup:AddButton(row.iconBtn, { Icon = row.icon })
            end
        end
        masqueGroup:ReSkin()
    else
        if masqueGroup then
            masqueGroup:Delete()
            masqueGroup = nil
            descIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            for _, row in ipairs(rows) do
                row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            end
        end
    end
end
