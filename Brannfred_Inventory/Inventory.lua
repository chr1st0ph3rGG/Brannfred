-- ── Inventory Provider ─────────────────────────────────────────────────────────
-- Searches bag and bank contents across all characters via Syndicator.

local L = LibStub("AceLocale-3.0"):GetLocale("Brannfred_Inventory")

-- ── Baganator integration ─────────────────────────────────────────────────────
-- Opens the right Baganator frame and highlights the item.
-- Falls back to OpenAllBags() when Baganator is not loaded.
local function showInBags(entry)
    -- Pick the best location: current char bags > current char bank > any first
    local currentChar = UnitName("player")
    local target

    for _, loc in ipairs(entry._locations) do
        if loc.char == currentChar then
            target = loc
            if loc.locType == "bag" then break end -- bags preferred over bank
        end
    end
    target = target or entry._locations[1]
    if not target then return end

    if Baganator then
        if target.locType == "bag" then
            Baganator.CallbackRegistry:TriggerEvent("BagShow", target.charKey)
        else
            Baganator.CallbackRegistry:TriggerEvent("BankShow", target.charKey)
        end
        if entry._itemLink then
            Baganator.CallbackRegistry:TriggerEvent("HighlightIdenticalItems", entry._itemLink)
        end
    elseif target.locType == "bag" and target.char == currentChar then
        OpenAllBags()
    end
end

-- ── Provider ──────────────────────────────────────────────────────────────────
local InventoryProvider = {
    type         = "item",
    label        = L["Item"],
    aliases      = { "b", "bag", "inv" },
    providerIcon = "Interface/ICONS/inv_misc_bag_08",
    color        = { r = 1, g = 1, b = 1 },
    labelColor   = { r = 0.4, g = 0.8, b = 0.4 },
    entries      = {},
}

local function processSlot(entryMap, slot, charName, charKey, locType, locationLabel)
    if not (slot and slot.itemID and slot.itemID ~= 0) then return end

    local name = slot.itemLink and slot.itemLink:match("%[(.-)%]")
        or GetItemInfo(slot.itemID)
    if not name then return end

    if not entryMap[slot.itemID] then
        local entry = {
            name       = name,
            icon       = slot.iconTexture,
            type       = "item",
            color      = InventoryProvider.color,
            labelColor = InventoryProvider.labelColor,
            _locations = {},
            _itemLink  = slot.itemLink, -- stored for Baganator highlight
        }
        entry.getMeta = function()
            local total = 0
            for _, loc in ipairs(entry._locations) do total = total + loc.qty end
            return "×" .. total
        end
        entry.getStats = function()
            local total = 0
            for _, loc in ipairs(entry._locations) do total = total + loc.qty end
            return L["Total"] .. ": " .. total
        end
        entry.getDesc = function()
            local lines = {}
            for _, loc in ipairs(entry._locations) do
                lines[#lines + 1] = loc.char .. "  ·  " .. loc.location .. "  ·  ×" .. loc.qty
            end
            return table.concat(lines, "\n")
        end
        entry.onActivate = function()
            showInBags(entry)
        end
        entry.onShiftActivate = function()
            if not entry._itemLink then return end
            local link = entry._itemLink
            C_Timer.After(0, function()
                local chatEdit = ChatEdit_GetActiveWindow()
                if not (chatEdit and chatEdit:IsVisible()) then
                    ChatEdit_ActivateChat(DEFAULT_CHAT_FRAME.editBox)
                    chatEdit = DEFAULT_CHAT_FRAME.editBox
                end
                chatEdit:Insert(link)
            end)
        end
        entry.onDrag = function()
            if entry._itemLink then
                PickupItem(entry._itemLink)
            end
        end
        entry.ctrlKeepsOpen = function()
            local p = Brannfred.db and Brannfred.db.profile
            return p and p.ctrlKeepsOpen_item ~= false
        end
        entry.onCtrlActivate = function()
            if not entry._itemLink then return end
            local itemEquipLoc = select(9, GetItemInfo(entry._itemLink))
            if itemEquipLoc and itemEquipLoc ~= "" and itemEquipLoc ~= "INVTYPE_NON_EQUIP" then
                DressUpItemLink(entry._itemLink)
            end
        end
        entry.onIconTooltip = function(anchor)
            if not entry._itemLink then return end
            GameTooltip:SetOwner(anchor, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(entry._itemLink)
            GameTooltip:Show()
        end
        entryMap[slot.itemID] = entry
        InventoryProvider.entries[#InventoryProvider.entries + 1] = entry
    end

    local entry = entryMap[slot.itemID]
    entry._locations[#entry._locations + 1] = {
        char     = charName,
        charKey  = charKey,
        locType  = locType,
        location = locationLabel,
        qty      = slot.itemCount or 1,
    }
end

function InventoryProvider:OnEnable()
    if not (Syndicator and Syndicator.API.IsReady()) then return end

    self.entries = {}
    local entryMap = {}

    for _, key in ipairs(Syndicator.API.GetAllCharacters()) do
        local data     = Syndicator.API.GetByCharacterFullName(key)
        local charName = data.details.character

        for _, bag in ipairs(data.bags or {}) do
            for _, slot in ipairs(bag) do
                processSlot(entryMap, slot, charName, key, "bag", L["Bag"])
            end
        end

        for _, bag in ipairs(data.bank or {}) do
            for _, slot in ipairs(bag) do
                processSlot(entryMap, slot, charName, key, "bank", L["Bank"])
            end
        end
    end

    table.sort(self.entries, function(a, b) return a.name < b.name end)
end

-- ── Syndicator callbacks ───────────────────────────────────────────────────────
if Syndicator then
    local function refresh()
        InventoryProvider:OnEnable()
    end

    if not Syndicator.API.IsReady() then
        Syndicator.CallbackRegistry:RegisterCallback("Ready", refresh)
    end

    Syndicator.CallbackRegistry:RegisterCallback("BagCacheUpdate", refresh)
end

-- ── Options ───────────────────────────────────────────────────────────────────
Brannfred:RegisterProviderOptions("Inventory", L["Inventory"], {
    closeOnDrag = {
        type  = "toggle",
        name  = L["Close frame on drag"],
        desc  = L["Close the search frame when dragging to the action bar"],
        order = 1,
        get   = function() return Brannfred.db.profile.closeOnDrag_item end,
        set   = function(_, val) Brannfred.db.profile.closeOnDrag_item = val end,
    },
    ctrlKeepsOpen = {
        type  = "toggle",
        name  = L["Keep frame open on Ctrl+click"],
        desc  = L["Keep the search frame open when using Ctrl+click to try on items"],
        order = 2,
        get   = function() return Brannfred.db.profile.ctrlKeepsOpen_item ~= false end,
        set   = function(_, val) Brannfred.db.profile.ctrlKeepsOpen_item = val end,
    },
})

Brannfred:RegisterProvider(InventoryProvider)
