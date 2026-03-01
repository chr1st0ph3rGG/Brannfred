-- ── History Provider ──────────────────────────────────────────────────────────
-- Shows recently activated/dragged entries via !history (or !h).
-- prefixOnly = true  → never appears in global search results.
-- preserveOrder = true → entries keep insertion order (most recent first).

local L = LibStub("AceLocale-3.0"):GetLocale("Brannfred_History")

local HistoryProvider = {
    type          = "history",
    label         = L["History"],
    aliases       = { "h", "history" },
    prefixOnly    = true,
    preserveOrder = true,
    providerIcon  = "Interface/ICONS/INV_Misc_PocketWatch_02",
    color         = { r = 0.85, g = 0.85, b = 0.85 },
    labelColor    = { r = 0.55, g = 0.55, b = 1.0 },
    entries       = Brannfred.history, -- live reference, always up to date
}

Brannfred:RegisterProvider(HistoryProvider)

Brannfred:RegisterProviderOptions("History", L["History"], {
    clearHistory = {
        type  = "execute",
        name  = L["Clear history"],
        desc  = L["Clears the history"],
        order = 1,
        func  = function() Brannfred.ClearHistory() end,
    },
})
