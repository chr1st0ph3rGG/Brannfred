-- ── Spells Provider ───────────────────────────────────────────────────────────
-- Builds searchable entries from the player's spellbook.

local PROFESSION_ANCHOR_IDS = {
    -- Cooking
    [2550] = true,
    [3102] = true,
    [3413] = true,
    [18260] = true,
    -- Alchemy
    [2259] = true,
    [3101] = true,
    [3464] = true,
    [11611] = true,
    -- Blacksmithing
    [2018] = true,
    [3100] = true,
    [3538] = true,
    [9785] = true,
    -- Tailoring
    [3908] = true,
    [3909] = true,
    [3910] = true,
    [12180] = true,
    -- Leatherworking
    [2108] = true,
    [3811] = true,
    [3812] = true,
    [10662] = true,
    -- Engineering
    [4036] = true,
    [4037] = true,
    [4038] = true,
    [12656] = true,
    -- Enchanting
    [7411] = true,
    [7412] = true,
    [7413] = true,
    [13920] = true,
    -- First Aid
    [3273] = true,
    [3274] = true,
    [7924] = true,
    [10846] = true,
    -- Fishing
    [7620] = true,
    [7731] = true,
    [7732] = true,
    [18248] = true,
}

local POWER_NAMES = { [0] = "Mana", [1] = "Rage", [2] = "Focus", [3] = "Energy" }

local function buildStats(spellID)
    local _, _, _, castTime, minRange, maxRange = GetSpellInfo(spellID)
    local parts = {}

    if castTime == 0 then
        parts[#parts + 1] = "Instant"
    elseif castTime then
        parts[#parts + 1] = string.format("%.1f sec cast", castTime / 1000)
    end

    if maxRange and maxRange > 0 then
        parts[#parts + 1] = maxRange .. " yd range"
    elseif minRange == 0 and maxRange == 0 then
        parts[#parts + 1] = "Melee range"
    end

    if GetSpellPowerCost then
        local costs = GetSpellPowerCost(spellID)
        if costs and costs[1] and costs[1].cost > 0 then
            local powerName = POWER_NAMES[costs[1].type] or "Power"
            parts[#parts + 1] = costs[1].cost .. " " .. powerName
        end
    end

    local _, cd = GetSpellCooldown(spellID)
    if cd and cd > 1.5 then
        if cd >= 60 then
            parts[#parts + 1] = string.format("%d min cooldown", math.floor(cd / 60))
        else
            parts[#parts + 1] = string.format("%g sec cooldown", cd)
        end
    end

    return table.concat(parts, "   ·   ")
end

-- ── Provider ──────────────────────────────────────────────────────────────────
local L = LibStub("AceLocale-3.0"):GetLocale("Brannfred_Spells")

local SpellsProvider = {
    type         = "spell",
    label        = L["Spells"],
    aliases      = { "s", "skill", "spell" },
    providerIcon = "Interface/ICONS/INV_Misc_Book_09",
    color        = { r = 0.95, g = 0.95, b = 0.95 },
    labelColor   = { r = 1, g = 0.82, b = 0 },
    entries      = {},
}

function SpellsProvider:OnEnable()
    self.entries       = {}
    local showAllRanks = Brannfred.db and Brannfred.db.profile.showAllRanks
    local spellMap     = {}
    local numTabs      = GetNumSpellTabs()

    for tab = 1, numTabs do
        local _, _, offset, numEntries = GetSpellTabInfo(tab)

        -- Check if this tab is a profession tab
        local isProfTab = false
        for slot = offset + 1, offset + numEntries do
            local _, spellID = GetSpellBookItemInfo(slot, BOOKTYPE_SPELL)
            if PROFESSION_ANCHOR_IDS[spellID] then
                isProfTab = true
                break
            end
        end

        for slot = offset + 1, offset + numEntries do
            local spellType, spellID = GetSpellBookItemInfo(slot, BOOKTYPE_SPELL)
            if spellType == "SPELL" then
                local name, rank = GetSpellBookItemName(slot, BOOKTYPE_SPELL)
                if name then
                    local icon     = GetSpellBookItemTexture(slot, BOOKTYPE_SPELL)
                    local rankStr  = (rank and rank ~= "") and rank or nil
                    local existing = not showAllRanks and spellMap[name]

                    if not existing then
                        local entry = {
                            name       = name, -- display name (no rank)
                            searchName = rankStr and (name .. " " .. rankStr) or nil,
                            icon       = icon,
                            type       = "spell",
                            color      = self.color,
                            labelColor = self.labelColor,
                            -- mutable fields updated on rank upgrade:
                            _baseName  = name,
                            _rank      = rankStr,
                            _slot      = slot,
                            _spellID   = spellID,
                            _castable  = isProfTab,
                        }
                        -- Closures reference the entry table so rank upgrades are reflected
                        entry.getMeta = function()
                            return entry._rank or ""
                        end
                        entry.onActivate = function()
                            if entry._castable and not InCombatLockdown() then
                                CastSpellByName(entry._baseName)
                            end
                        end
                        entry.onDrag = function()
                            PickupSpellBookItem(entry._slot, BOOKTYPE_SPELL)
                        end
                        entry.getStats = function()
                            return buildStats(entry._spellID)
                        end
                        entry.getDesc = function()
                            return GetSpellDescription and GetSpellDescription(entry._spellID) or ""
                        end
                        entry.onIconTooltip = function(anchor)
                            GameTooltip:SetOwner(anchor, "ANCHOR_RIGHT")
                            GameTooltip:SetSpellByID(entry._spellID)
                            GameTooltip:Show()
                        end

                        if not showAllRanks then
                            spellMap[name] = entry
                        end
                        self.entries[#self.entries + 1] = entry
                    else
                        -- Higher rank of the same spell – update in place
                        existing._rank      = rankStr
                        existing.searchName = rankStr and (name .. " " .. rankStr) or nil
                        existing.icon       = icon
                        existing._slot      = slot
                        existing._spellID   = spellID
                        if isProfTab then existing._castable = true end
                    end
                end
            end
        end
    end

    table.sort(self.entries, function(a, b)
        if a._baseName ~= b._baseName then
            return a._baseName < b._baseName
        end
        -- Same spell, different ranks: sort numerically by rank number
        local ra = a._rank and tonumber(a._rank:match("(%d+)")) or 0
        local rb = b._rank and tonumber(b._rank:match("(%d+)")) or 0
        return ra < rb
    end)
end

-- ── Options ───────────────────────────────────────────────────────────────────
Brannfred:RegisterProviderOptions("Spells", L["Spells"], {
    showAllRanks = {
        type  = "toggle",
        name  = L["Show all spell ranks"],
        desc  = L["Show all skill ranks instead of only the highest"],
        order = 1,
        get   = function() return Brannfred.db.profile.showAllRanks end,
        set   = function(_, val)
            Brannfred.db.profile.showAllRanks = val
            SpellsProvider:OnEnable()
        end,
    },
    closeOnDrag = {
        type  = "toggle",
        name  = L["Close frame on drag"],
        desc  = L["Close the search frame when dragging to the action bar"],
        order = 2,
        get   = function() return Brannfred.db.profile.closeOnDrag_spell end,
        set   = function(_, val) Brannfred.db.profile.closeOnDrag_spell = val end,
    },
})

Brannfred:RegisterProvider(SpellsProvider)

local function onSpellsChanged()
    SpellsProvider:OnEnable()
    Brannfred:RebuildHistory()
end
Brannfred:RegisterEvent("LEARNED_SPELL_IN_TAB", onSpellsChanged)
Brannfred:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED", onSpellsChanged)
