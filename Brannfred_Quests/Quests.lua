-- ── Quest Provider ─────────────────────────────────────────────────────────────
-- Active quests from the quest log. !q / !quest to search.
-- Click         → open quest in quest log
-- Shift+Click   → link quest in chat window
-- Ctrl+Click    → open world map, navigate to nearest objective / turn-in
-- Alt+Click     → set TomTom arrow to nearest objective / turn-in

local L                 = LibStub("AceLocale-3.0"):GetLocale("Brannfred_Quests")

local ICON_ACTIVE       = "Interface/AddOns/Questie/Icons/incomplete" -- gray ?
local ICON_COMPLETE     = "Interface/AddOns/Questie/Icons/complete" -- yellow ?

local ICON_COLOR_FAILED = { r = 1, g = 0.2, b = 0.2 }
local LABEL_COLOR       = { r = 0.4, g = 0.8, b = 0.4 }

-- Returns the WoW difficulty color for a quest level relative to the player.
-- Uses GetQuestDifficultyColor if available (Classic 1.14+), otherwise falls back
-- to a manual calculation with GetQuestGreenRange().
local function difficultyColor(level)
    if GetQuestDifficultyColor then
        local c = GetQuestDifficultyColor(level)
        return { r = c.r, g = c.g, b = c.b }
    end
    local player = UnitLevel("player")
    local diff   = level - player
    if diff >= 5 then
        return { r = 1.0, g = 0.1, b = 0.1 }    -- red
    elseif diff >= 3 then
        return { r = 1.0, g = 0.5, b = 0.25 }   -- orange
    elseif diff >= -2 then
        return { r = 1.0, g = 1.0, b = 0.0 }    -- yellow
    elseif -diff < (GetQuestGreenRange and GetQuestGreenRange() or 8) then
        return { r = 0.25, g = 0.75, b = 0.25 } -- green
    else
        return { r = 0.5, g = 0.5, b = 0.5 }    -- gray
    end
end

-- ── Questie module references ──────────────────────────────────────────────────
-- QuestieLoader is the only Questie global; everything else is accessed through it.
-- These are live references to the module tables – functions will be present once
-- Questie finishes loading (guaranteed by OptionalDeps: Questie in the TOC).
local QPlayer    = QuestieLoader and QuestieLoader:ImportModule("QuestiePlayer")
local QDistUtils = QuestieLoader and QuestieLoader:ImportModule("DistanceUtils")
local QZoneDB    = QuestieLoader and QuestieLoader:ImportModule("ZoneDB")
local QDB        = QuestieLoader and QuestieLoader:ImportModule("QuestieDB")

-- ── GetQuestLogTitle return order (no suggestedGroup in this WoW build) ────────
-- 1:title  2:level  3:questTag  4:isHeader  5:isCollapsed
-- 6:isComplete  7:frequency  8:questID

local function findQuestLogIndex(questID)
    local numEntries = GetNumQuestLogEntries()
    for i = 1, numEntries do
        local _, _, _, isHeader, _, _, _, qID = GetQuestLogTitle(i)
        if not isHeader and qID == questID then return i end
    end
    return nil
end

-- ── Action: link quest in chat ────────────────────────────────────────────────
local function linkQuestInChat(questID, questName, level)
    local link = string.format("|cffffff00|Hquest:%d:%d|h[%s]|h|r", questID, level or 0, questName)
    C_Timer.After(0, function()
        local chatEdit = ChatEdit_GetActiveWindow()
        if not (chatEdit and chatEdit:IsVisible()) then
            ChatEdit_ActivateChat(DEFAULT_CHAT_FRAME.editBox)
            chatEdit = DEFAULT_CHAT_FRAME.editBox
        end
        chatEdit:Insert(link)
    end)
end

-- ── Action: open quest log ─────────────────────────────────────────────────────
local function openQuestInLog(questID)
    -- GetQuestLogIndexByID is faster; fall back to manual search if missing
    local idx = (GetQuestLogIndexByID and GetQuestLogIndexByID(questID))
        or findQuestLogIndex(questID)
    if idx and idx > 0 then
        SelectQuestLogEntry(idx)
    end
    -- Support WideQuestLogPlus (QuestLogExFrame), ClassicQuestLog, default
    local questFrame = QuestLogExFrame or ClassicQuestLog or QuestLogFrame
    if questFrame then
        if not questFrame:IsShown() then
            if not InCombatLockdown() then
                ShowUIPanel(questFrame)
            end
        end
        if QuestLog_UpdateQuestDetails then QuestLog_UpdateQuestDetails() end
        if QuestLog_Update then QuestLog_Update() end
    end
end

-- ── Questie nearest spawn (shared by map + TomTom) ────────────────────────────
-- Returns uiMapId, x, y  (x/y in 0-100 range, Questie convention).
--
-- Method 1: DistanceUtils.GetNearestSpawnForQuest – uses the live quest object
--   with populated spawnLists. Picks finisher for complete quests, nearest
--   incomplete objective otherwise. Fails if Questie hasn't built spawnLists yet.
--
-- Method 2: Direct QuestieDB lookup of the finisher NPC/object – always
--   available from the static DB, used as fallback when Method 1 returns nil.
local function getQuestNearestSpawn(questID)
    if not QZoneDB then return nil end

    -- Helper: first usable coord from spawns table {[zoneId] = {{x,y},...}}
    local function firstSpawn(spawns)
        if type(spawns) ~= "table" then return nil end
        for zoneId, list in pairs(spawns) do
            if list and list[1] then
                local uiMapId = QZoneDB:GetUiMapIdByAreaId(zoneId)
                if uiMapId then return uiMapId, list[1][1], list[1][2] end
            end
        end
    end

    -- Method 1: via live Questie quest object + DistanceUtils
    if QPlayer and QDistUtils then
        local quest = QPlayer.currentQuestlog and QPlayer.currentQuestlog[questID]
        if quest and type(quest) == "table" then
            local ok, spawn, zone = pcall(QDistUtils.GetNearestSpawnForQuest, quest)
            if ok and spawn and zone then
                local uiMapId = QZoneDB:GetUiMapIdByAreaId(zone)
                if uiMapId then return uiMapId, spawn[1], spawn[2] end
            end
        end
    end

    -- Method 2: direct DB lookup for finisher NPC/object (static, always available)
    if not QDB then return nil end
    local finishedBy = QDB.QueryQuestSingle and QDB.QueryQuestSingle(questID, "finishedBy")
    if finishedBy then
        -- finishedBy[1] = {npcId,...}  finishedBy[2] = {objectId,...}
        for _, npcId in ipairs(finishedBy[1] or {}) do
            local spawns = QDB.QueryNPCSingle and QDB.QueryNPCSingle(npcId, "spawns")
            local uiMapId, x, y = firstSpawn(spawns)
            if uiMapId then return uiMapId, x, y end
        end
        for _, objId in ipairs(finishedBy[2] or {}) do
            local spawns = QDB.QueryObjectSingle and QDB.QueryObjectSingle(objId, "spawns")
            local uiMapId, x, y = firstSpawn(spawns)
            if uiMapId then return uiMapId, x, y end
        end
    end

    return nil
end

-- ── Action: show on map ────────────────────────────────────────────────────────
local function showQuestOnMap(questID)
    local uiMapId = getQuestNearestSpawn(questID)
    WorldMapFrame:Show()
    if uiMapId then
        WorldMapFrame:SetMapID(uiMapId)
    end
end

-- ── Action: TomTom waypoint ────────────────────────────────────────────────────
local function setTomTomWaypoint(questID, questName)
    if not TomTom then
        print("|cffff9900Brannfred:|r " .. L["TomTom not found"])
        return
    end

    local uiMapId, x, y = getQuestNearestSpawn(questID)
    if not uiMapId then
        print("|cffff9900Brannfred:|r " .. L["No coordinates found"] .. " (" .. questName .. ")")
        return
    end

    -- TomTom expects x/y as 0-1; Questie stores them as 0-100
    local ok, err = pcall(function()
        TomTom:AddWaypoint(uiMapId, x / 100, y / 100, { title = questName, crazy = true })
    end)
    if not ok then
        print("|cffff9900Brannfred TomTom:|r " .. tostring(err))
    end
end

-- ── Provider ───────────────────────────────────────────────────────────────────
local QuestsProvider = {
    type         = "quest",
    label        = L["Quests"],
    aliases      = { "q" },
    providerIcon = "Interface/ICONS/INV_Misc_Note_06",
    color        = COLOR_ACTIVE,
    labelColor   = LABEL_COLOR,
    entries      = {},
    prefixOnly   = false,
}

function QuestsProvider:OnEnable()
    self.entries = {}

    local savedSel = GetQuestLogSelection and GetQuestLogSelection()
    local numEntries = GetNumQuestLogEntries()

    for i = 1, numEntries do
        local title, level, _, isHeader, _, isComplete, _, questID = GetQuestLogTitle(i)

        if not isHeader and title and title ~= "" and questID and questID > 0 then
            local complete = (isComplete == 1)
            local failed   = (isComplete == -1)
            local lvl      = level or 0
            local color    = difficultyColor(lvl)

            -- Cache objectives now so we don't call SelectQuestLogEntry at hover time
            SelectQuestLogEntry(i)
            local totalObj, doneObj = GetNumQuestLeaderBoards(), 0
            local objLines = {}
            for j = 1, totalObj do
                local text, _, done = GetQuestLogLeaderBoard(j)
                if text and text ~= "" then
                    objLines[#objLines + 1] =
                        (done and "|cff00ff00" or "|cffcccccc") .. text .. "|r"
                    if done then doneObj = doneObj + 1 end
                end
            end
            local cachedDesc = table.concat(objLines, "\n")
            local cachedStats
            if complete then
                cachedStats = "|cff00ff00" .. L["Ready to turn in"] .. "|r"
            elseif failed then
                cachedStats = "|cffff4444" .. L["Quest failed"] .. "|r"
            elseif totalObj > 0 then
                cachedStats = doneObj .. "/" .. totalObj .. " " .. L["objectives"]
            else
                cachedStats = ""
            end

            local entry                     = {
                name       = complete and (title .. " |cff55ff55(" .. L["Completed"] .. ")|r") or title,
                icon       = complete and ICON_COMPLETE or ICON_ACTIVE,
                type       = "quest",
                color      = color,
                iconColor  = failed and ICON_COLOR_FAILED or nil,
                labelColor = LABEL_COLOR,
                _questID   = questID,
            }
            entry.getMeta                   = function() return lvl > 0 and ("L" .. lvl) or "" end
            entry.getStats                  = function() return cachedStats end
            entry.getDesc                   = function() return cachedDesc end
            entry.onActivate                = function() openQuestInLog(questID) end
            entry.onShiftActivate           = function() linkQuestInChat(questID, title, lvl) end
            entry.onCtrlActivate            = function() showQuestOnMap(questID) end
            entry.onAltActivate             = function() setTomTomWaypoint(questID, title) end

            self.entries[#self.entries + 1] = entry
        end
    end

    if savedSel and savedSel > 0 then
        SelectQuestLogEntry(savedSel)
    end
end

-- ── Registration ───────────────────────────────────────────────────────────────
Brannfred:RegisterProvider(QuestsProvider)

local function onQuestUpdate()
    QuestsProvider:OnEnable()
end
Brannfred:RegisterEvent("QUEST_LOG_UPDATE", onQuestUpdate)
Brannfred:RegisterEvent("QUEST_ACCEPTED", onQuestUpdate)
