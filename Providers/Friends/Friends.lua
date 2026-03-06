-- ── Friends Provider ───────────────────────────────────────────────────────────
-- Two providers, both visible under !f:
--   BNetFriendsProvider  (type "bnet")   — combined list (in-game + Battle.net, sorted)
--   InGameFriendsProvider (type "friend") — in-game friends only (!fr / !friend)
-- Click → pre-fill /w <name> in the chat box.
-- Sort priority in combined list: online in-game > online BNet > offline (all alphabetical within group).

local L             = LibStub("AceLocale-3.0"):GetLocale("Brannfred_Friends")
local C             = LibStub("C_Everywhere")

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

local function safeNumber(value)
    if type(value) == "number" then return value end
    if type(value) == "string" and value ~= "" then return tonumber(value) end
    return nil
end

local function openWhisper(target)
    C.Timer.After(0, function()
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
    type          = "friend",
    label         = L["In-Game"],
    aliases       = { "f", "fr", "friend" },
    preserveOrder = true,
    providerIcon  = "Interface/ICONS/INV_Misc_GroupLooking",
    color         = COLOR_ONLINE,
    labelColor    = LABEL_INGAME,
    entries       = {},
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
            local online   = isOnline == true
            local friendId = (battleTag and battleTag ~= "") and battleTag
                or (givenName or "?")
            local safeNote = (type(noteText) == "string" and noteText ~= "") and noteText or ""

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
                        charLevel = safeNumber(level)
                        break
                    end
                end
                -- Fall back to toonName from BNGetFriendInfo if game-account API returns nothing
                if not charName and toonName and toonName ~= "" then
                    charName = toonName
                end
            end

            local hasChar                 = charName and charName ~= "" and charName ~= friendId
            local displayName             = hasChar
                and (charName .. " |cff88aaff(" .. friendId .. ")|r")
                or friendId
            local searchName              = hasChar and (charName .. " " .. friendId) or nil

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
                _note      = safeNote,
                _isAFK     = isAFK == true,
                _isDND     = isDND == true,
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
            entry.context_actions         = {
                {
                    name     = L["Whisper"],
                    func     = function() openWhisper(entry._friendId) end,
                    modifier = "primary",
                },
                {
                    name     = L["Invite to Party"],
                    func     = function()
                        if entry._charName ~= "" then
                            C.PartyInfo.InviteUnit(entry._charName)
                        end
                    end,
                    modifier = "shift",
                },
            }

            bnetEntries[#bnetEntries + 1] = entry
        end
    end
end

local function rebuildIngame()
    ingameEntries = {}

    local num = 0
    if C and C.FriendList and type(C.FriendList.GetNumFriends) == "function" then
        num = safeNumber(C.FriendList.GetNumFriends()) or 0
    elseif C_FriendList and type(C_FriendList.GetNumFriends) == "function" then
        num = safeNumber(C_FriendList.GetNumFriends()) or 0
        ---@diagnostic disable-next-line: undefined-global
    elseif type(GetNumFriends) == "function" then
        ---@diagnostic disable-next-line: undefined-global
        num = safeNumber(GetNumFriends()) or 0
    end

    for i = 1, num do
        local info
        if C and C.FriendList and type(C.FriendList.GetFriendInfoByIndex) == "function" then
            info = C.FriendList.GetFriendInfoByIndex(i)
        elseif C_FriendList and type(C_FriendList.GetFriendInfoByIndex) == "function" then
            info = C_FriendList.GetFriendInfoByIndex(i)
            ---@diagnostic disable-next-line: undefined-global
        elseif type(GetFriendInfo) == "function" then
            -- Legacy API returns multiple values instead of a table.
            ---@diagnostic disable-next-line: undefined-global
            local name, level, className, area, connected, status, notes = GetFriendInfo(i)
            info = {
                name = name,
                level = level,
                className = className,
                area = area,
                connected = connected,
                notes = notes,
                status = status,
            }
        end

        if info and info.name then
            local online                      = info.connected and true or false
            local levelNum                    = safeNumber(info.level)
            local entry                       = {
                name       = info.name,
                icon       = getClassIcon(info.className or ""),
                type       = "friend",
                color      = online and COLOR_ONLINE or COLOR_OFFLINE,
                labelColor = LABEL_INGAME,
                _online    = online,
                _level     = (levelNum and levelNum > 0) and tostring(levelNum) or "",
                _class     = info.className or "",
                _zone      = info.area or "",
                _note      = (type(info.notes) == "string" and info.notes ~= "") and info.notes or "",
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
            entry.context_actions             = {
                {
                    name     = L["Whisper"],
                    func     = function() openWhisper(info.name) end,
                    modifier = "primary",
                },
                {
                    name     = L["Invite to Party"],
                    func     = function()
                        if entry._online then
                            C.PartyInfo.InviteUnit(info.name)
                        end
                    end,
                    modifier = "shift",
                },
            }

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
    InGameFriendsProvider.entries = ingameEntries
end

function BNetFriendsProvider:OnEnable()
    buildClassIconMap()
    rebuildAll()
end

function InGameFriendsProvider:OnEnable()
    -- intentionally empty — BNetFriendsProvider.OnEnable handles both
end

-- ── Options ───────────────────────────────────────────────────────────────────
local friendActionNames = { L["Whisper"], L["Invite to Party"] }
local friendModDefaults = { primary = L["Whisper"], shift = L["Invite to Party"] }

local bnetArgs          = {}
for k, v in pairs(Brannfred.GetModifierBindingArgs("bnet", friendActionNames, friendModDefaults)) do
    bnetArgs[k] = v
end
Brannfred:RegisterProviderOptions("BNetFriends", L["Battle.net"], bnetArgs)

local ingameArgs = {}
for k, v in pairs(Brannfred.GetModifierBindingArgs("friend", friendActionNames, friendModDefaults)) do
    ingameArgs[k] = v
end
Brannfred:RegisterProviderOptions("InGameFriends", L["In-Game"], ingameArgs)

-- ── Registration ───────────────────────────────────────────────────────────────
Brannfred:RegisterProvider(BNetFriendsProvider)
Brannfred:RegisterProvider(InGameFriendsProvider)

Brannfred:RegisterEvent("BN_FRIEND_LIST_SIZE_CHANGED", rebuildAll)
Brannfred:RegisterEvent("BN_FRIEND_INFO_CHANGED", rebuildAll)
Brannfred:RegisterEvent("FRIENDLIST_UPDATE", rebuildAll)
Brannfred:RegisterEvent("PLAYER_ENTERING_WORLD", function()
    C.FriendList.ShowFriends()
end)
