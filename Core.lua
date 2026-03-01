Brannfred = LibStub("AceAddon-3.0"):NewAddon("Brannfred", "AceConsole-3.0", "AceEvent-3.0")

local L = LibStub("AceLocale-3.0"):GetLocale("Brannfred")
_G["BINDING_NAME_CLICK BrannfredToggleButton:LeftButton"] = L["Toggle Brannfred search"]

Brannfred.providers        = {}
Brannfred.providerOptions  = {}  -- { key, name, args } per provider
Brannfred.history          = {}  -- session history, most recent first

local HISTORY_MAX = 20

function Brannfred.AddToHistory(entry)
    if not entry then return end
    local original = entry._originalEntry or entry  -- unwrap history wrappers

    -- Move to top if already present (dedup by name + original type)
    for i, h in ipairs(Brannfred.history) do
        if h.name == original.name and h._originalType == original.type then
            table.remove(Brannfred.history, i)
            break
        end
    end

    table.insert(Brannfred.history, 1, {
        name              = original.name,
        icon              = original.icon,
        type              = "history",
        color             = original.color,
        labelColor        = original.labelColor,
        getMeta           = original.getMeta,
        getStats          = original.getStats,
        getDesc           = original.getDesc,
        onActivate        = original.onActivate,
        onShiftActivate   = original.onShiftActivate,
        onCtrlActivate    = original.onCtrlActivate,
        onAltActivate     = original.onAltActivate,
        onDrag            = original.onDrag,
        _originalType     = original.type,
        _originalEntry    = original,
    })

    while #Brannfred.history > HISTORY_MAX do
        Brannfred.history[#Brannfred.history] = nil
    end

    -- Persist to SavedVariables
    if Brannfred.db then
        local saved = Brannfred.db.profile.history
        for i, s in ipairs(saved) do
            if s.name == original.name and s._originalType == original.type then
                table.remove(saved, i)
                break
            end
        end
        table.insert(saved, 1, {
            name          = original.name,
            icon          = original.icon,
            _originalType = original.type,
        })
        while #saved > HISTORY_MAX do
            saved[#saved] = nil
        end
    end
end

function Brannfred.ClearHistory()
    wipe(Brannfred.history)
    if Brannfred.db then
        wipe(Brannfred.db.profile.history)
    end
end

function Brannfred:FindProviderEntry(providerType, name)
    for _, provider in ipairs(self.providers) do
        if provider.type == providerType then
            for _, entry in ipairs(provider.entries or {}) do
                if entry.name == name then
                    return entry
                end
            end
        end
    end
end

function Brannfred:RebuildHistory()
    if not self.db then return end
    wipe(Brannfred.history)
    for _, saved in ipairs(self.db.profile.history) do
        local original = self:FindProviderEntry(saved._originalType, saved.name)
        if original then
            Brannfred.history[#Brannfred.history + 1] = {
                name           = saved.name,
                icon           = saved.icon,
                type           = "history",
                color          = original.color,
                labelColor     = original.labelColor,
                getMeta        = original.getMeta,
                getStats       = original.getStats,
                getDesc        = original.getDesc,
                onActivate     = original.onActivate,
                onDrag         = original.onDrag,
                _originalType  = saved._originalType,
                _originalEntry = original,
            }
        else
            -- Entry no longer available (e.g. spell unlearned) – show as stub
            Brannfred.history[#Brannfred.history + 1] = {
                name          = saved.name,
                icon          = saved.icon,
                type          = "history",
                _originalType = saved._originalType,
            }
        end
    end
end

local BORDER_TEXTURE_VALUES = {
    ["none"]                                              = "None",
    ["Interface/Buttons/WHITE8X8"]                        = "Solid",
    ["Interface/Tooltips/UI-Tooltip-Border"]              = "Tooltip",
    ["Interface/DialogFrame/UI-DialogBox-Border"]         = "Dialog",
    ["Interface/DialogFrame/UI-DialogBox-Gold-Border"]    = "Dialog (Gold)",
    ["Interface/FriendsFrame/UI-Toast-Border"]            = "Toast",
}

-- Native edgeSize for each texture — keeps 9-slice corners sharp.
local BORDER_TEXTURE_SIZE = {
    ["none"]                                              = 0,
    ["Interface/Buttons/WHITE8X8"]                        = 1,
    ["Interface/Tooltips/UI-Tooltip-Border"]              = 16,
    ["Interface/DialogFrame/UI-DialogBox-Border"]         = 32,
    ["Interface/DialogFrame/UI-DialogBox-Gold-Border"]    = 32,
    ["Interface/FriendsFrame/UI-Toast-Border"]            = 12,
}

-- Visual inset at native size (= opaque border pixels, used as default contentPadding).
local BORDER_TEXTURE_INSET = {
    ["none"]                                              = 0,
    ["Interface/Buttons/WHITE8X8"]                        = 1,
    ["Interface/Tooltips/UI-Tooltip-Border"]              = 5,
    ["Interface/DialogFrame/UI-DialogBox-Border"]         = 11,
    ["Interface/DialogFrame/UI-DialogBox-Gold-Border"]    = 11,
    ["Interface/FriendsFrame/UI-Toast-Border"]            = 4,
}

local FONT_VALUES = {
    ["fonts/frizqt__.ttf"]       = "FrizQuadrata (Standard)",
    ["fonts/arialn.ttf"]         = "Arial Narrow",
    ["fonts/morpheus.ttf"]       = "Morpheus",
    ["fonts/skurri.ttf"]         = "Skurri",
    ["fonts/LifeCraft_Font.ttf"] = "LifeCraft",
}

local ANCHOR_VALUES = {
    CENTER      = "Center",
    TOP         = "Top",
    TOPLEFT     = "Top Left",
    TOPRIGHT    = "Top Right",
    LEFT        = "Left",
    RIGHT       = "Right",
    BOTTOM      = "Bottom",
    BOTTOMLEFT  = "Bottom Left",
    BOTTOMRIGHT = "Bottom Right",
}

-- External addons can call this at any time.
-- If Brannfred is already enabled the provider's OnEnable runs immediately.
function Brannfred:RegisterProvider(provider)
    table.insert(self.providers, provider)
    if self:IsEnabled() and provider.OnEnable then
        provider:OnEnable()
    end
end

-- External addons can call this at any time.
-- If OnInitialize has already run the options sub-page is registered immediately.
--   key         : unique string, used as part of the options table name
--   displayName : shown in the Blizzard sidebar (localized)
--   args        : AceConfig args table with the actual options
function Brannfred:RegisterProviderOptions(key, displayName, args)
    table.insert(self.providerOptions, { key = key, name = displayName, args = args })
    if self.db then  -- OnInitialize already ran → register on the spot
        LibStub("AceConfig-3.0"):RegisterOptionsTable("Brannfred_" .. key, {
            name = displayName,
            type = "group",
            args = args,
        })
        LibStub("AceConfigDialog-3.0"):AddToBlizOptions("Brannfred_" .. key, displayName, "Brannfred")
    end
end

local defaults = {
    profile = {
        frameWidth        = 420,
        visibleRows       = 10,
        fontSize          = 13,
        fontPath          = "fonts/frizqt__.ttf",
        posAnchor         = "TOP",
        posX              = 0,
        posY              = -280,
        closeOnDrag_spell = true,
        closeOnDrag_item  = true,
        borderTexture     = "Interface/Buttons/WHITE8X8",
        borderSize        = 1,
        contentPadding    = 1,
        bgR               = 0.07, bgG = 0.07, bgB = 0.07, bgA = 0.93,
        borderR           = 0.25, borderG = 0.25, borderB = 0.25, borderA = 1.0,
        minimap           = { hide = false },
        useMasque         = false,
        disabledProviders = {},  -- { [providerType] = true } → hidden in global search
        history           = {},  -- { { name, icon, _originalType }, ... }
    },
}

local function OpenBlizOptions()
    if Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(Brannfred.optionsCategoryID)
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(Brannfred.optionsPanel)
        InterfaceOptionsFrame_OpenToCategory(Brannfred.optionsPanel)
    end
end

function Brannfred:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("BrannfredDB", defaults, true)

    self:RegisterChatCommand("brannfred", "OnToggleFrame")
    self:RegisterChatCommand("bfrd",      "OnToggleFrame")

    local ldb = LibStub("LibDataBroker-1.1"):NewDataObject("Brannfred", {
        type  = "launcher",
        icon  = "Interface/ICONS/INV_Misc_Spyglass_02",
        OnClick = function(_, button)
            if button == "RightButton" then
                OpenBlizOptions()
            else
                Brannfred:OnToggleFrame()
            end
        end,
        OnTooltipShow = function(tt)
            tt:AddLine("Brannfred")
            tt:AddLine(L["Left-click to toggle search"], 1, 1, 1)
            tt:AddLine(L["Right-click for settings"],    1, 1, 1)
        end,
    })
    LibStub("LibDBIcon-1.0"):Register("Brannfred", ldb, self.db.profile.minimap)

    local function get(k)   return function()    return self.db.profile[k]    end end
    local function set(k)   return function(_, v) self.db.profile[k] = v; self.ApplyFrameSettings() end end

    -- Main Brannfred page — appearance & position
    LibStub("AceConfig-3.0"):RegisterOptionsTable("Brannfred", {
        name = "Brannfred",
        type = "group",
        args = {
            appearance = {
                type   = "group",
                name   = L["Appearance"],
                inline = true,
                order  = 1,
                args   = {
                    frameWidth = {
                        type  = "range",
                        name  = L["Width"],
                        desc  = L["Width of the search frame"],
                        min   = 300, max = 800, step = 10,
                        order = 1,
                        get   = get("frameWidth"),
                        set   = set("frameWidth"),
                    },
                    visibleRows = {
                        type  = "range",
                        name  = L["Visible rows"],
                        desc  = L["Number of visible result rows"],
                        min   = 3, max = 20, step = 1,
                        order = 2,
                        get   = get("visibleRows"),
                        set   = set("visibleRows"),
                    },
                    fontPath = {
                        type   = "select",
                        name   = L["Font"],
                        order  = 3,
                        values = FONT_VALUES,
                        get    = get("fontPath"),
                        set    = set("fontPath"),
                    },
                    fontSize = {
                        type  = "range",
                        name  = L["Font size"],
                        min   = 8, max = 24, step = 1,
                        order = 4,
                        get   = get("fontSize"),
                        set   = set("fontSize"),
                    },
                    bgColor = {
                        type     = "color",
                        name     = L["Background color"],
                        hasAlpha = true,
                        order    = 5,
                        get      = function()
                            local p = self.db and self.db.profile or {}
                            return p.bgR or 0.07, p.bgG or 0.07, p.bgB or 0.07, p.bgA or 0.93
                        end,
                        set      = function(_, r, g, b, a)
                            local p = self.db.profile
                            p.bgR, p.bgG, p.bgB, p.bgA = r, g, b, a
                            self.ApplyFrameSettings()
                        end,
                    },
                    borderColor = {
                        type     = "color",
                        name     = L["Border color"],
                        hasAlpha = true,
                        order    = 6,
                        get      = function()
                            local p = self.db and self.db.profile or {}
                            return p.borderR or 0.25, p.borderG or 0.25, p.borderB or 0.25, p.borderA or 1.0
                        end,
                        set      = function(_, r, g, b, a)
                            local p = self.db.profile
                            p.borderR, p.borderG, p.borderB, p.borderA = r, g, b, a
                            self.ApplyFrameSettings()
                        end,
                    },
                    borderTexture = {
                        type   = "select",
                        name   = L["Border texture"],
                        order  = 7,
                        values = BORDER_TEXTURE_VALUES,
                        get    = get("borderTexture"),
                        set    = function(_, v)
                            local p = self.db.profile
                            p.borderTexture = v
                            -- snap to native edgeSize so 9-slice corners stay sharp
                            local native = BORDER_TEXTURE_SIZE[v]
                            if native then
                                p.borderSize     = native
                                p.contentPadding = BORDER_TEXTURE_INSET[v] or native
                            end
                            self.ApplyFrameSettings()
                        end,
                    },
                    borderSize = {
                        type  = "range",
                        name  = L["Border size"],
                        min   = 0, max = 32, step = 1,
                        order = 8,
                        get   = get("borderSize"),
                        set   = set("borderSize"),
                    },
                    contentPadding = {
                        type  = "range",
                        name  = L["Content padding"],
                        desc  = L["Inner spacing between border and content"],
                        min   = 0, max = 40, step = 1,
                        order = 9,
                        get   = get("contentPadding"),
                        set   = set("contentPadding"),
                    },
                    minimapButton = {
                        type  = "toggle",
                        name  = L["Minimap button"],
                        order = 11,
                        get   = function() return not self.db.profile.minimap.hide end,
                        set   = function(_, val)
                            self.db.profile.minimap.hide = not val
                            if val then
                                LibStub("LibDBIcon-1.0"):Show("Brannfred")
                            else
                                LibStub("LibDBIcon-1.0"):Hide("Brannfred")
                            end
                        end,
                    },
                    useMasque = {
                        type     = "toggle",
                        name     = L["Icon skins (Masque)"],
                        desc     = function()
                            if not LibStub("Masque", true) then
                                return L["Requires the Masque addon to be installed"]
                            end
                            return L["Apply Masque button skins to result icons"]
                        end,
                        disabled = function() return not LibStub("Masque", true) end,
                        order    = 10,
                        get      = get("useMasque"),
                        set      = set("useMasque"),
                    },
                },
            },
            position = {
                type   = "group",
                name   = L["Position"],
                inline = true,
                order  = 2,
                args   = {
                    posAnchor = {
                        type   = "select",
                        name   = L["Anchor"],
                        order  = 1,
                        values = ANCHOR_VALUES,
                        get    = get("posAnchor"),
                        set    = set("posAnchor"),
                    },
                    posX = {
                        type  = "range",
                        name  = L["X Offset"],
                        min   = -1000, max = 1000, step = 1,
                        order = 2,
                        get   = get("posX"),
                        set   = set("posX"),
                    },
                    posY = {
                        type  = "range",
                        name  = L["Y Offset"],
                        min   = -800, max = 800, step = 1,
                        order = 3,
                        get   = get("posY"),
                        set   = set("posY"),
                    },
                },
            },
            providers = {
                type   = "group",
                name   = L["Search providers"],
                inline = true,
                order  = 3,
                args   = {
                    activeProviders = {
                        type   = "multiselect",
                        name   = L["Show in global search"],
                        desc   = L["Providers shown when searching without a type prefix"],
                        order  = 1,
                        values = function()
                            local t = {}
                            for _, p in ipairs(Brannfred.providers) do
                                if not p.prefixOnly and not p.onQuery then
                                    t[p.type] = p.label or p.type
                                end
                            end
                            return t
                        end,
                        get = function(_, key)
                            return not self.db.profile.disabledProviders[key]
                        end,
                        set = function(_, key, val)
                            self.db.profile.disabledProviders[key] = not val or nil
                        end,
                    },
                },
            },
        },
    })
    Brannfred.optionsPanel, Brannfred.optionsCategoryID = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("Brannfred", "Brannfred")

    -- Profile management sub-page
    LibStub("AceConfig-3.0"):RegisterOptionsTable("Brannfred_Profile",
        LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db))
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions("Brannfred_Profile", L["Profiles"], "Brannfred")

    -- One sub-page per provider that registered options
    for _, p in ipairs(self.providerOptions) do
        LibStub("AceConfig-3.0"):RegisterOptionsTable("Brannfred_" .. p.key, {
            name = p.name,
            type = "group",
            args = p.args,
        })
        LibStub("AceConfigDialog-3.0"):AddToBlizOptions("Brannfred_" .. p.key, p.name, "Brannfred")
    end
end

function Brannfred:OnEnable()
    for _, provider in ipairs(self.providers) do
        if provider.OnEnable then
            provider:OnEnable()
        end
    end

    -- Registered last so it appears at the bottom of the ! autocomplete list
    local settingsName = "Brannfred " .. L["Settings"]
    self:RegisterProvider({
        type           = "config",
        label          = settingsName,
        aliases        = { "cfg" },
        directActivate = OpenBlizOptions,
        providerIcon   = "Interface/ICONS/Trade_Engineering",
        entries        = {
            {
                name       = settingsName,
                icon       = "Interface/ICONS/Trade_Engineering",
                type       = "config",
                onActivate = OpenBlizOptions,
            },
        },
    })

    self:RebuildHistory()
    self.ApplyFrameSettings()
end

function Brannfred:OnDisable()
end

function Brannfred:OnToggleFrame(input)
    if strtrim(input or "") == "config" then
        OpenBlizOptions()
        return
    end
    if self.searchFrame:IsShown() then
        self.searchFrame:Hide()
    else
        if self.db then
            local p      = self.db.profile or {}
            local anchor = p.posAnchor or "TOP"
            local posX   = p.posX      or 0
            local posY   = p.posY      or -280
            self.searchFrame:ClearAllPoints()
            self.searchFrame:SetPoint(anchor, UIParent, anchor, posX, posY)
        end
        self.searchFrame:Show()
        C_Timer.After(0.05, function() Brannfred.searchEditBox:SetFocus() end)
    end
end
