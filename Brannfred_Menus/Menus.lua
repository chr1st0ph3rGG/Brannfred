-- ── Menus Provider ────────────────────────────────────────────────────────────
-- Searchable entries for in-game panels and UI frames.

local L = LibStub("AceLocale-3.0"):GetLocale("Brannfred_Menus")

-- FileDataIDs for class icons (UnitClass() returns uppercase classFile).
-- Fill in with: /dump GetFileIDFromPath("Interface/Icons/Classicon_warrior")
local CLASS_ICON = {
    WARRIOR = 626008,
    PALADIN = 626003,
    HUNTER  = 626000,
    ROGUE   = 626005,
    PRIEST  = 626004,
    SHAMAN  = 626006,
    MAGE    = 626001,
    WARLOCK = 626007,
    DRUID   = 625999,
}

local function characterIcon()
    local _, classFile = UnitClass("player")
    return CLASS_ICON[classFile] or 136235
end

local MENU_DEFINITIONS = {
    {
        name   = L["Character Info"],
        icon   = characterIcon, -- function → resolved in OnEnable when player data is ready
        action = function() ToggleCharacter("PaperDollFrame") end,
    },
    {
        name   = L["Skills"],
        icon   = "Interface/ICONS/INV_Misc_Book_09",
        action = function() ToggleCharacter("SkillFrame") end,
    },
    {
        name   = L["Reputation"],
        icon   = "Interface/ICONS/inv_jewelry_talisman_07",
        action = function() ToggleCharacter("ReputationFrame") end,
    },
    {
        name   = L["Talents"],
        icon   = "Interface/ICONS/ability_marksmanship",
        action = function() ToggleTalentFrame() end,
    },
    {
        name   = L["Spellbook & Abilities"],
        icon   = "Interface/ICONS/inv_misc_book_09",
        action = function() ToggleSpellBook(BOOKTYPE_SPELL) end,
    },
    {
        name   = L["Quest Log"],
        icon   = "Interface/ICONS/INV_Misc_Note_06",
        action = function() ToggleQuestLog() end,
    },
    {
        name   = L["World Map"],
        icon   = "Interface/ICONS/inv_misc_map_01",
        action = function() ToggleWorldMap() end,
    },
    {
        name   = L["Friends"],
        icon   = "Interface/ICONS/achievement_guildperk_everybodysfriend",
        action = function() ToggleFriendsFrame(1) end,
    },
    {
        name   = L["Guild & Community"],
        icon   = "Interface/ICONS/inv_shirt_guildtabard_01",
        action = function() ToggleFriendsFrame(3) end,
    },
    {
        name   = L["Inventory"],
        icon   = "Interface/ICONS/inv_misc_bag_08",
        action = function()
            CloseBackpack()
            OpenBackpack()
        end,
    },
    {
        name   = L["Combat Log"],
        icon   = "Interface/ICONS/racial_troll_berserk",
        action = function() ToggleCombatLog() end,
    },
    {
        name   = L["Help"],
        icon   = "Interface/ICONS/inv_misc_questionmark",
        action = function() ToggleHelpFrame() end,
    },
}

-- ── Provider ──────────────────────────────────────────────────────────────────
local MenusProvider = {
    type         = "menu",
    label        = L["Menu"],
    aliases      = { "m" },
    providerIcon = "Interface/ICONS/Inv_misc_note_01",
    color        = { r = 1, g = 0.82, b = 0 },
    labelColor   = { r = 0.3, g = 0.6, b = 1 },
    entries      = {},
}

function MenusProvider:OnEnable()
    self.entries = {}
    for _, def in ipairs(MENU_DEFINITIONS) do
        self.entries[#self.entries + 1] = {
            name       = def.name,
            icon       = type(def.icon) == "function" and def.icon() or def.icon,
            type       = "menu",
            color      = self.color,
            labelColor = self.labelColor,
            onActivate = def.action,
        }
    end
end

Brannfred:RegisterProvider(MenusProvider)
