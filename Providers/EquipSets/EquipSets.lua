-- ── Equipment Sets Provider ────────────────────────────────────────────────────
-- Searchable entries for ItemRack equipment sets.
---@diagnostic disable: undefined-global  (ItemRack / ItemRackUser are runtime globals from the ItemRack addon)

local L = LibStub("AceLocale-3.0"):GetLocale("Brannfred_EquipSets")

local EquipSetsProvider = {
    type         = "equipset",
    label        = L["Equipment Sets"],
    aliases      = { "eq", "equip", "set", "gear" },
    providerIcon = "Interface/ICONS/INV_Misc_Bag_10_Blue",
    color        = { r = 0.4, g = 0.8, b = 1 },
    labelColor   = { r = 0.4, g = 0.8, b = 1 },
    entries      = {},
}

local function isItemRackAvailable()
    return ItemRackUser and ItemRackUser.Sets and ItemRack and ItemRack.EquipSet
end

function EquipSetsProvider:OnEnable()
    self.entries = {}
    if not isItemRackAvailable() then return end

    local names = {}
    for name in pairs(ItemRackUser.Sets) do
        -- Skip internal sets (prefixed with ~)
        if not name:match("^~") then
            names[#names + 1] = name
        end
    end
    table.sort(names)

    for _, name in ipairs(names) do
        local set = ItemRackUser.Sets[name]
        local setName = name  -- upvalue for closures

        local slotCount = 0
        if set.equip then
            for _ in pairs(set.equip) do slotCount = slotCount + 1 end
        end

        local entry = {
            name       = setName,
            icon       = set.icon,
            type       = "equipset",
            color      = self.color,
            labelColor = self.labelColor,
        }

        entry.getMeta = function()
            if ItemRackUser and ItemRackUser.CurrentSet == setName then
                return "|cff00ff00[active]|r"
            end
            return slotCount > 0 and (slotCount .. " slots") or ""
        end

        entry.onActivate = function()
            if not InCombatLockdown() and isItemRackAvailable() then
                ItemRack.EquipSet(setName)
            end
        end

        self.entries[#self.entries + 1] = entry
    end
end

Brannfred:RegisterProvider(EquipSetsProvider)

-- Refresh list when equipment changes (sets equipped) or addon loads late
local function onEquipmentChanged()
    if isItemRackAvailable() then
        EquipSetsProvider:OnEnable()
        Brannfred:RebuildHistory()
    end
end

Brannfred:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", onEquipmentChanged)
