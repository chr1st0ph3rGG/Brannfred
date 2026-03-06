-- ── Inventory Provider ─────────────────────────────────────────────────────────
-- Searches bag and bank contents across all characters via Syndicator.

local L = LibStub("AceLocale-3.0"):GetLocale("Brannfred_Inventory")
local C = LibStub("C_Everywhere")
local useContainerItem = C.Container.UseContainerItem

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

-- ── Use / equip helpers ───────────────────────────────────────────────────────
-- Returns true for equippable items, consumables, and items with a use effect
-- (e.g. quest-starting items).
local function isUsableItem(itemID)
    if not itemID then return false end
    if C.Item.GetItemInfoInstant then
        local _, _, _, equipLoc, _, classID = C.Item.GetItemInfoInstant(itemID)
        if equipLoc and equipLoc ~= "" and equipLoc ~= "INVTYPE_NON_EQUIP" then
            return true                      -- equippable
        end
        if classID == 0 then return true end -- consumable
    else
        local _, _, _, _, _, itemType, _, _, equipLoc = C.Item.GetItemInfo(itemID)
        if equipLoc and equipLoc ~= "" and equipLoc ~= "INVTYPE_NON_EQUIP" then
            return true
        end
        if itemType == "Consumable" then return true end
    end
    -- Items with a use effect (e.g. quest starters, special items)
    return C.Item.GetItemSpell and C.Item.GetItemSpell(itemID) ~= nil
end

-- Equips or uses the item.
-- Equippable items use EquipItemByName so quest-start effects are bypassed.
-- Consumables and use-effect items are triggered via the bag slot.
-- Returns true if the action was triggered.
local function useItemFromBags(entry, itemID)
    -- Equippable: equip directly, bypassing any quest-start prompt
    if itemID then
        local equipLoc = C.Item.GetItemInfoInstant and select(4, C.Item.GetItemInfoInstant(itemID))
            or select(9, C.Item.GetItemInfo(itemID))
        if equipLoc and equipLoc ~= "" and equipLoc ~= "INVTYPE_NON_EQUIP" then
            _G.EquipItemByName(itemID)
            return true
        end
    end
    -- Consumable / use-effect: trigger from the bag slot
    local currentChar = UnitName("player")
    for _, loc in ipairs(entry._locations) do
        if loc.char == currentChar and loc.locType == "bag"
            and loc.bagIndex and loc.slotIndex then
            useContainerItem(loc.bagIndex, loc.slotIndex)
            return true
        end
    end
    return false
end

-- ── Quality colors ────────────────────────────────────────────────────────────
local QUALITY_COLORS = {
    [0] = { r = 0.62, g = 0.62, b = 0.62 }, -- Poor
    [1] = { r = 1.00, g = 1.00, b = 1.00 }, -- Common
    [2] = { r = 0.12, g = 1.00, b = 0.00 }, -- Uncommon
    [3] = { r = 0.00, g = 0.44, b = 0.87 }, -- Rare
    [4] = { r = 0.64, g = 0.21, b = 0.93 }, -- Epic
    [5] = { r = 1.00, g = 0.50, b = 0.00 }, -- Legendary
}

-- ── Provider ──────────────────────────────────────────────────────────────────
local InventoryProvider = {
    type         = "item",
    label        = L["Item"],
    aliases      = { "b", "bag", "inv" },
    providerIcon = "Interface/ICONS/inv_misc_bag_08",
    labelColor   = { r = 0.4, g = 0.8, b = 0.4 },
    entries      = {},
}

-- bagIndex: WoW container index (bagArrayIdx - 1); nil for bank slots
local function processSlot(entryMap, slot, charName, charKey, locType, locationLabel, bagIndex, slotIndex)
    if not (slot and slot.itemID and slot.itemID ~= 0) then return end

    local name = slot.itemLink and slot.itemLink:match("%[(.-)%]")
        or C.Item.GetItemInfo(slot.itemID)
    if not name then return end

    if not entryMap[slot.itemID] then
        local _, _, quality = C.Item.GetItemInfo(slot.itemID)
        local itemID = slot.itemID
        local entry = {
            name       = name,
            icon       = slot.iconTexture,
            type       = "item",
            color      = QUALITY_COLORS[quality] or QUALITY_COLORS[1],
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

        local function linkInChat()
            if not entry._itemLink then return end
            local link = entry._itemLink
            C.Timer.After(0, function()
                local chatEdit = ChatEdit_GetActiveWindow()
                if not (chatEdit and chatEdit:IsVisible()) then
                    ChatEdit_ActivateChat(DEFAULT_CHAT_FRAME.editBox)
                    chatEdit = DEFAULT_CHAT_FRAME.editBox
                end
                chatEdit:Insert(link)
            end)
        end

        entry.context_actions = {
            {
                name     = L["Show in Bags"],
                func     = function() showInBags(entry) end,
                modifier = "primary",
            },
            {
                name     = L["Use / Equip"],
                func     = function()
                    if isUsableItem(itemID) then
                        if not useItemFromBags(entry, itemID) then showInBags(entry) end
                    else
                        showInBags(entry)
                    end
                end,
                modifier = "ctrl",
            },
            {
                name     = L["Link in Chat"],
                func     = linkInChat,
                modifier = "shift",
            },
        }
        entry.onDrag = function()
            if entry._itemLink then
                PickupItem(entry._itemLink)
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
        char      = charName,
        charKey   = charKey,
        locType   = locType,
        location  = locationLabel,
        qty       = slot.itemCount or 1,
        bagIndex  = bagIndex,
        slotIndex = slotIndex,
    }
end

function InventoryProvider:OnEnable()
    if not (Syndicator and Syndicator.API.IsReady()) then return end

    self.entries = {}
    local entryMap = {}

    for _, key in ipairs(Syndicator.API.GetAllCharacters()) do
        local data     = Syndicator.API.GetByCharacterFullName(key)
        local charName = data.details.character

        for bagIdx, bag in ipairs(data.bags or {}) do
            for slotIdx, slot in ipairs(bag) do
                -- Syndicator bag array is 1-based; WoW container index is 0-based
                processSlot(entryMap, slot, charName, key, "bag", L["Bag"], bagIdx - 1, slotIdx)
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
local inventoryArgs = {
    closeOnDrag = {
        type  = "toggle",
        name  = L["Close frame on drag"],
        desc  = L["Close the search frame when dragging to the action bar"],
        order = 1,
        get   = function() return Brannfred.db.profile.closeOnDrag_item end,
        set   = function(_, val) Brannfred.db.profile.closeOnDrag_item = val end,
    },
}
for k, v in pairs(Brannfred.GetModifierBindingArgs("item", {
    L["Show in Bags"], L["Use / Equip"], L["Link in Chat"],
}, { primary = L["Show in Bags"], shift = L["Link in Chat"] })) do
    inventoryArgs[k] = v
end
Brannfred:RegisterProviderOptions("Inventory", L["Inventory"], inventoryArgs)

Brannfred:RegisterProvider(InventoryProvider)
