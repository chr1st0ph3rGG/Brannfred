-- ── Friends Provider ───────────────────────────────────────────────────────────
-- Two providers share the !f alias:
--   BNetFriendsProvider  (type "bnet")   — Battle.net friends
--   InGameFriendsProvider (type "friend") — in-game character friends
-- Click → pre-fill /w <name> in the chat box.
-- Sort priority: online in-game > online BNet > offline (all alphabetical within group).

local L             = LibStub("AceLocale-3.0"):GetLocale("Brannfred_Friends")

local COLOR_ONLINE  = { r = 0.2, g = 1.0, b = 0.2 }
local COLOR_OFFLINE = { r = 0.45, g = 0.45, b = 0.45 }
local LABEL_BNET    = { r = 0.2, g = 0.7, b = 1.0 } -- blue
local LABEL_INGAME  = { r = 0.4, g = 1.0, b = 0.4 } -- green

-- Reverse-map localized class name → class icon path.
local classIconMap  = {}
local function buildClassIconMap()
    if not LOCALIZED_CLASS_NAMES_MALE then return end
    for key, locName in pairs(LOCALIZED_CLASS_NAMES_MALE) do
        classIconMap[locName] = "Interface/Icons/ClassIcon_"
            .. key:sub(1, 1):upper() .. key:sub(2):lower()
    end
end

local function getClassIcon(localizedClass)
    return classIconMap[localizedClass] or "Interface/ICONS/INV_Misc_GroupLooking"
end

local function openWhisper(target)
    C_Timer.After(0, function()
        local chatEdit = ChatEdit_GetActiveWindow()
        if not (chatEdit and chatEdit:IsVisible()) then
            ChatEdit_ActivateChat(DEFAULT_CHAT_FRAME.editBox)
            chatEdit = DEFAULT_CHAT_FRAME.editBox
        end
        chatEdit:SetText("/w " .. target .. " ")
        chatEdit:SetCursorPosition(chatEdit:GetNumLetters())
    end)
end

-- ── Battle.net Friends Provider ───────────────────────────────────────────────
local BNetFriendsProvider   = {
    type          = "bnet",
    label         = L["Battle.net"],
    aliases       = { "f", "bn", "bnet" },
    preserveOrder = true,
    providerIcon  = "Interface/ICONS/INV_Misc_GroupLooking",
    color         = COLOR_ONLINE,
    labelColor    = LABEL_BNET,
    entries       = {},
}

-- ── In-Game Friends Provider ──────────────────────────────────────────────────
local InGameFriendsProvider = {
    type                 = "friend",
    label                = L["In-Game"],
    aliases              = { "f", "fr", "friend" },
    hideFromAutocomplete = true,
    preserveOrder        = true,
    providerIcon         = "Interface/ICONS/INV_Misc_GroupLooking",
    color                = COLOR_ONLINE,
    labelColor           = LABEL_INGAME,
    entries              = {},
}

-- Module-level staging tables; rebuildAll() merges them.
local bnetEntries           = {}
local ingameEntries         = {}

local function rebuildBNet()
    bnetEntries = {}

    ---@diagnostic disable-next-line: undefined-global
    local numBNet = BNGetNumFriends()
    for i = 1, numBNet do
        ---@diagnostic disable-next-line: undefined-global
        local presenceID, givenName, battleTag, _, toonName, _, isOnline, isAFK, isDND, noteText = BNGetFriendInfo(i)
        if presenceID then
            local online   = isOnline and true or false
            local friendId = (battleTag and battleTag ~= "") and battleTag
                or (givenName or "?")

            local charName, charClass, charZone, charLevel
            if online then
                ---@diagnostic disable-next-line: undefined-global
                for j = 1, BNGetNumFriendGameAccounts(i) do
                    ---@diagnostic disable-next-line: undefined-global
                    local _, characterName, _, _, _, _, _, className, _, zoneName, level = BNGetFriendGameAccountInfo(i,
                        j)
                    if characterName and characterName ~= "" then
                        charName  = characterName
                        charClass = className
                        charZone  = zoneName
                        charLevel = tonumber(level)
                        break
                    end
                end
                -- Fall back to toonName from BNGetFriendInfo if game-account API returns nothing
                if not charName and toonName and toonName ~= "" then
                    charName = toonName
                end
            end

            local hasChar    = charName and charName ~= "" and charName ~= friendId
            local displayName = hasChar
                and (charName .. " |cff88aaff(" .. friendId .. ")|r")
                or friendId
            local searchName  = hasChar and (charName .. " " .. friendId) or nil

            local entry                   = {
                name       = displayName,
                searchName = searchName,
                icon       = getClassIcon(charClass or ""),
                type       = "bnet",
                color      = online and COLOR_ONLINE or COLOR_OFFLINE,
                labelColor = LABEL_BNET,
                _online    = online,
                _level     = (charLevel and charLevel > 0) and tostring(charLevel) or "",
                _class     = charClass or "",
                _zone      = charZone or "",
                _friendId  = friendId,
                _charName  = charName or "",
                _note      = (noteText and noteText ~= "") and noteText or "",
                _isAFK     = isAFK,
                _isDND     = isDND,
            }

            entry.getMeta                 = function()
                if not entry._online then return L["Offline"] end
                if entry._isAFK then return "|cffff9900AFK|r" end
                if entry._isDND then return "|cffff4444DND|r" end
                return L["Online"]
            end

            entry.getStats                = function()
                local parts = {}
                if entry._level ~= "" then parts[#parts + 1] = "L" .. entry._level end
                if entry._class ~= "" then parts[#parts + 1] = entry._class end
                if entry._zone ~= "" then parts[#parts + 1] = entry._zone end
                return table.concat(parts, "   ·   ")
            end

            entry.getDesc                 = function() return entry._note end
            entry.onActivate              = function() openWhisper(entry._friendId) end
            entry.onShiftActivate         = function()
                if entry._charName == "" then return end -- not in WoW, can't invite
                ---@diagnostic disable-next-line: undefined-global
                C_PartyInfo.InviteUnit(entry._charName)
            end

            bnetEntries[#bnetEntries + 1] = entry
        end
    end
end

local function rebuildIngame()
    ingameEntries = {}

    local num = C_FriendList.GetNumFriends()
    for i = 1, num do
        local info = C_FriendList.GetFriendInfoByIndex(i)
        if info and info.name then
            local online                      = info.connected and true or false
            local entry                       = {
                name       = info.name,
                icon       = getClassIcon(info.className or ""),
                type       = "friend",
                color      = online and COLOR_ONLINE or COLOR_OFFLINE,
                labelColor = LABEL_INGAME,
                _online    = online,
                _level     = (info.level and info.level > 0) and tostring(info.level) or "",
                _class     = info.className or "",
                _zone      = info.area or "",
                _note      = (info.notes and info.notes ~= "") and info.notes or "",
            }

            entry.getMeta                     = function()
                if not entry._online then return L["Offline"] end
                return entry._level ~= "" and ("L" .. entry._level) or L["Online"]
            end

            entry.getStats                    = function()
                local parts = {}
                if entry._level ~= "" then parts[#parts + 1] = "L" .. entry._level end
                if entry._class ~= "" then parts[#parts + 1] = entry._class end
                if entry._zone ~= "" then parts[#parts + 1] = entry._zone end
                return table.concat(parts, "   ·   ")
            end

            entry.getDesc                     = function() return entry._note end
            entry.onActivate                  = function() openWhisper(info.name) end
            entry.onShiftActivate             = function()
                if not entry._online then return end
                ---@diagnostic disable-next-line: undefined-global
                InviteUnit(info.name)
            end

            ingameEntries[#ingameEntries + 1] = entry
        end
    end
end

-- ── Shared rebuild / merge ─────────────────────────────────────────────────────
-- Sort priority: 1 = online in-game, 2 = online BNet, 3 = offline (any).
-- Within the same group entries are alphabetical.
local function friendRank(e)
    if not e._online then return 3 end
    return e.type == "friend" and 1 or 2
end

local function rebuildAll()
    rebuildBNet()
    rebuildIngame()

    local merged = {}
    for _, e in ipairs(ingameEntries) do merged[#merged + 1] = e end
    for _, e in ipairs(bnetEntries) do merged[#merged + 1] = e end

    table.sort(merged, function(a, b)
        local ra, rb = friendRank(a), friendRank(b)
        if ra ~= rb then return ra < rb end
        return (a.searchName or a.name) < (b.searchName or b.name)
    end)

    BNetFriendsProvider.entries   = merged
    InGameFriendsProvider.entries = {}
end

function BNetFriendsProvider:OnEnable()
    buildClassIconMap()
    rebuildAll()
end

function InGameFriendsProvider:OnEnable()
    -- intentionally empty — BNetFriendsProvider.OnEnable handles both
end

-- ── Registration ───────────────────────────────────────────────────────────────
Brannfred:RegisterProvider(BNetFriendsProvider)
Brannfred:RegisterProvider(InGameFriendsProvider)

Brannfred:RegisterEvent("BN_FRIEND_LIST_SIZE_CHANGED", rebuildAll)
Brannfred:RegisterEvent("BN_FRIEND_INFO_CHANGED", rebuildAll)
Brannfred:RegisterEvent("FRIENDLIST_UPDATE", rebuildAll)
Brannfred:RegisterEvent("PLAYER_ENTERING_WORLD", function()
    C_FriendList.ShowFriends()
end)
