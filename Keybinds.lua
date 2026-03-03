local L = LibStub("AceLocale-3.0"):GetLocale("Brannfred")
local C = LibStub("C_Everywhere")

local button = CreateFrame("Button", "BrannfredToggleButton", UIParent)
button:RegisterForClicks("AnyUp")
button:SetSize(1, 1)
button:SetPoint("CENTER")
button:SetScript("OnClick", function()
    Brannfred:OnToggleFrame()
end)

-- Key capture overlay
local capture = CreateFrame("Frame", nil, UIParent,
    BackdropTemplateMixin and "BackdropTemplate" or nil)
capture:SetSize(300, 80)
capture:SetPoint("CENTER")
capture:SetFrameStrata("DIALOG")
capture:EnableKeyboard(true)
capture:EnableMouse(true)
if capture.SetPropagateKeyboardInput then
    capture:SetPropagateKeyboardInput(false)
end
capture:SetBackdrop({
    bgFile   = "Interface/Buttons/WHITE8X8",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    edgeSize = 16,
    insets   = { left = 4, right = 4, top = 4, bottom = 4 },
})
capture:SetBackdropColor(0, 0, 0, 0.92)
capture:SetBackdropBorderColor(1, 0.82, 0, 1)
capture:Hide()

local captureTitle = capture:CreateFontString(nil, "OVERLAY", "GameFontNormal")
captureTitle:SetPoint("CENTER", 0, 18)
captureTitle:SetText(L["Press a key to bind..."])

local captureCurrent = capture:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
captureCurrent:SetPoint("CENTER", 0, -4)

local captureHint = capture:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
captureHint:SetPoint("CENTER", 0, -22)
captureHint:SetTextColor(0.5, 0.5, 0.5)
captureHint:SetText(L["ESC to cancel, DEL to clear"])

capture:SetScript("OnKeyDown", function(self, key)
    if key == "LSHIFT" or key == "RSHIFT" or key == "LCTRL" or key == "RCTRL"
    or key == "LALT"   or key == "RALT"   or key == "LMETA" or key == "RMETA" then
        return
    end

    if key == "ESCAPE" then
        self:Hide()
        return
    end

    local binding = "CLICK BrannfredToggleButton:LeftButton"

    if key == "DELETE" then
        local current = GetBindingKey(binding)
        if current then
            SetBinding(current, nil)
            SaveBindings(GetCurrentBindingSet())
        end
        self:Hide()
        return
    end

    if IsShiftKeyDown()   then key = "SHIFT-"   .. key end
    if IsControlKeyDown() then key = "CTRL-"    .. key end
    if IsAltKeyDown()     then key = "ALT-"     .. key end

    while GetBindingKey(binding) do
        SetBinding(GetBindingKey(binding), nil)
    end
    SetBindingClick(key, "BrannfredToggleButton", "LeftButton")
    SaveBindings(GetCurrentBindingSet())
    self:Hide()
end)

capture:SetScript("OnHide", function()
    C.Timer.After(0, function()
        local ACD = LibStub("AceConfigDialog-3.0")
        local bliz = ACD.BlizOptions and ACD.BlizOptions["Brannfred"]
        local widget = bliz and bliz["Brannfred"]
        if widget and widget.frame and widget.frame:IsShown() then
            ACD:Open("Brannfred", widget)
        end
    end)
end)

function Brannfred.OpenKeybindCapture()
    local key = GetBindingKey("CLICK BrannfredToggleButton:LeftButton")
    captureCurrent:SetText(key
        and (L["Current"] .. ": |cffffd700" .. key .. "|r")
        or  ("|cff888888" .. L["No key bound"] .. "|r"))
    capture:Show()
end
