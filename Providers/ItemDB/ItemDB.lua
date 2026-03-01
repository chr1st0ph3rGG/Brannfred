-- ── ItemDB Provider ───────────────────────────────────────────────────────────
-- Searches for items you don't own. Requires the Ludwig addon.
--
-- Ludwig's pre-built database (~15 000+ items) is loaded on enable and indexed
-- into a flat array for fast fuzzy search.
--
-- Search with:  !idb <name>   or   !itemdb <name>
-- Shift+Enter  → post item link in chat
-- Ctrl+Enter   → open Dressing Room (equippable items)

local L = LibStub("AceLocale-3.0"):GetLocale("Brannfred_ItemDB")

-- Ludwig_Items is set in OnEnable after LoadAddOn("Ludwig_Data") is called.
-- Do NOT capture it at file-load time — Ludwig_Data is LoadOnDemand and not yet loaded.
local Ludwig_Items ---@type table?

-- ── Quality colors ────────────────────────────────────────────────────────────
local QUALITY_COLORS = {
    [0] = { r = 0.62, g = 0.62, b = 0.62 }, -- Poor
    [1] = { r = 1.00, g = 1.00, b = 1.00 }, -- Common
    [2] = { r = 0.12, g = 1.00, b = 0.00 }, -- Uncommon
    [3] = { r = 0.00, g = 0.44, b = 0.87 }, -- Rare
    [4] = { r = 0.64, g = 0.21, b = 0.93 }, -- Epic
    [5] = { r = 1.00, g = 0.50, b = 0.00 }, -- Legendary
}

-- ── State ─────────────────────────────────────────────────────────────────────
local ludwigIndex  -- flat array { {id, name}, … } built from Ludwig_Items

-- ── Fuzzy scoring (mirrors Brannfred/Search.lua) ──────────────────────────────
local function fuzzyScore(str, pattern)
    str     = str:lower()
    pattern = pattern:lower()
    if pattern == "" then return 0 end

    local pos = str:find(pattern, 1, true)
    if pos then return 500 - pos + (pos == 1 and 200 or 0) end

    local score, si, pi, last, run = 0, 1, 1, 0, 0
    while si <= #str and pi <= #pattern do
        if str:sub(si, si) == pattern:sub(pi, pi) then
            run   = (si == last + 1) and run + 1 or 1
            score = score + run * 3
            if si == 1 then score = score + 10 end
            last = si
            pi   = pi + 1
        end
        si = si + 1
    end
    if pi <= #pattern then return nil end
    return score
end

-- ── Ludwig index builder ──────────────────────────────────────────────────────
-- Ludwig_Items stores items as concatenated strings at its leaf nodes.
-- Format: "IDIDName_IDIDName_…" where ID is 4 base-36 chars → tonumber(id, 36).
-- We walk the full table recursively and flatten everything into ludwigIndex.
local function walkLudwig(t, index, seen)
    if type(t) == "string" then
        for b36ID, name in t:gmatch("(%w%w%w%w)([^_]+)") do
            local id = tonumber(b36ID, 36)
            if id and id > 0 and not seen[id] then
                seen[id] = true
                index[#index + 1] = { id = id, name = name }
            end
        end
    elseif type(t) == "table" then
        for _, v in pairs(t) do
            walkLudwig(v, index, seen)
        end
    end
end

local function buildLudwigIndex()
    ludwigIndex = {}
    local seen = {}
    walkLudwig(Ludwig_Items, ludwigIndex, seen)
end

-- ── Provider ──────────────────────────────────────────────────────────────────
local ItemDBProvider = {
    type          = "itemdb",
    label         = L["Item Database"],
    aliases       = { "idb", "itemdb" },
    providerIcon  = "Interface/ICONS/INV_Misc_Book_08",
    labelColor    = { r = 0.4, g = 0.7, b = 1.0 },
    prefixOnly    = true,
    preserveOrder = true,  -- we sort ourselves in onQuery
    entries       = {},
}

local function makeEntry(itemID, name)
    -- Try to resolve icon & quality from client cache; may be nil for unknown items
    local _, _, quality, _, _, _, _, _, _, texture = GetItemInfo(itemID)

    local entry = {
        name       = name,
        icon       = texture or "Interface/ICONS/INV_Misc_QuestionMark",
        type       = "itemdb",
        color      = texture and (QUALITY_COLORS[quality] or QUALITY_COLORS[1])
            or { r = 0.7, g = 0.7, b = 0.7 },
        labelColor = ItemDBProvider.labelColor,
        _itemID    = itemID,
    }

    local function getLink()
        return select(2, GetItemInfo(itemID))
    end

    -- Shift+Enter: insert item link into the active chat editbox
    entry.onShiftActivate = function()
        local link = getLink()
        if not link then
            GetItemInfo(itemID)
            return
        end
        C_Timer.After(0, function()
            local chatEdit = ChatEdit_GetActiveWindow()
            if not (chatEdit and chatEdit:IsVisible()) then
                ChatEdit_ActivateChat(DEFAULT_CHAT_FRAME.editBox)
                chatEdit = DEFAULT_CHAT_FRAME.editBox
            end
            chatEdit:Insert(link)
        end)
    end

    -- Ctrl+Enter: open Dressing Room for equippable items
    entry.onCtrlActivate = function()
        local link = getLink()
        if not link then return end
        local equipLoc = select(9, GetItemInfo(itemID))
        if equipLoc and equipLoc ~= "" and equipLoc ~= "INVTYPE_NON_EQUIP" then
            DressUpItemLink(link)
        end
    end

    -- Icon hover: show item tooltip
    entry.onIconTooltip = function(anchor)
        GameTooltip:SetOwner(anchor, "ANCHOR_RIGHT")
        local link = getLink()
        if link then
            GameTooltip:SetHyperlink(link)
        else
            GameTooltip:AddLine(name)
            GameTooltip:AddLine(L["Loading item data…"], 1, 0.8, 0)
        end
        GameTooltip:Show()
    end

    -- Right meta column: item subtype (e.g. "Sword", "Cloth"), refreshed on each render
    entry.getMeta = function()
        local _, _, _, _, _, itemType, itemSubType = GetItemInfo(itemID)
        return itemSubType or itemType or ""
    end

    return entry
end

function ItemDBProvider:onQuery(query)
    self.entries = {}
    if not ludwigIndex or query == "" then return end

    local results = {}
    for _, item in ipairs(ludwigIndex) do
        local score = fuzzyScore(item.name, query)
        if score then
            results[#results + 1] = { id = item.id, name = item.name, score = score }
        end
    end

    table.sort(results, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        return a.name < b.name
    end)

    for i = 1, math.min(#results, 50) do
        local r = results[i]
        self.entries[#self.entries + 1] = makeEntry(r.id, r.name)
    end
end

function ItemDBProvider:OnEnable()
    -- Ludwig_Data is LoadOnDemand — trigger it now if Ludwig is present
    if _G["Ludwig"] then
        local loadAddOn = C_AddOns and C_AddOns.LoadAddOn or _G["LoadAddOn"]
        loadAddOn("Ludwig_Data")
        Ludwig_Items = _G["Ludwig_Items"]
    end

    if not Ludwig_Items then return end

    buildLudwigIndex()

    -- ── Icon refresh: re-render results when async item data arrives ──────────
    -- GetItemInfo returns nil at entry-build time for uncached items → question
    -- mark icons. When GET_ITEM_INFO_RECEIVED fires the data is ready, so we
    -- debounce a re-render of the current query to pick up icons & quality colors.
    local refreshPending = false
    local refreshFrame = CreateFrame("Frame")
    refreshFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    refreshFrame:SetScript("OnEvent", function(_, _, _, success)
        if not success or refreshPending then return end
        local box = Brannfred.searchEditBox
        if not (box and box:IsVisible()) then return end
        refreshPending = true
        C_Timer.After(0.2, function()
            refreshPending = false
            local b = Brannfred.searchEditBox
            if b and b:IsVisible() then
                local handler = b:GetScript("OnTextChanged")
                if handler then handler(b) end
            end
        end)
    end)
end

-- ── Options ───────────────────────────────────────────────────────────────────
Brannfred:RegisterProviderOptions("ItemDB", L["Item Database"], {
    status = {
        type     = "description",
        name     = function()
            if Ludwig_Items then
                return L["Source"] .. ": Ludwig  ·  "
                    .. (ludwigIndex and #ludwigIndex or 0) .. " " .. L["items"]
            else
                return L["Ludwig not found"]
            end
        end,
        order    = 1,
        fontSize = "medium",
    },
})

Brannfred:RegisterProvider(ItemDBProvider)
