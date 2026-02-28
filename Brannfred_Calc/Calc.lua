-- ── Calc Provider ─────────────────────────────────────────────────────────────
-- Evaluates math expressions typed as !calc <expr> (aliases: !c, !math).
-- Uses a recursive-descent parser – no loadstring/setfenv required.

local L      = LibStub("AceLocale-3.0"):GetLocale("Brannfred_Calc")

-- ── Expression evaluator ──────────────────────────────────────────────────────
-- Grammar (highest to lowest precedence):
--   primary = number | '(' expr ')' | name | name '(' args ')'
--   power   = primary ('^' unary)*     right-associative
--   unary   = '-' unary | '+' unary | power
--   term    = unary (('*'|'/'|'%') unary)*
--   expr    = term  (('+'|'-') term)*

local CONSTS = { pi = math.pi, e = math.exp(1) }
local FUNCS  = {
    sqrt = math.sqrt,
    abs = math.abs,
    floor = math.floor,
    ceil = math.ceil,
    round = function(x) return math.floor(x + 0.5) end,
    sin = math.sin,
    cos = math.cos,
    tan = math.tan,
    asin = math.asin,
    acos = math.acos,
    atan = math.atan,
    log = math.log,
    ln = math.log,
    exp = math.exp,
    log2 = function(x) return math.log(x) / math.log(2) end,
    log10 = function(x) return math.log(x) / math.log(10) end,
    max = math.max,
    min = math.min,
}

local function evaluate(input)
    local s = input:lower():gsub("%s+", "")
    local i = 1

    local parseExpr, parseTerm, parseUnary, parsePower, parsePrimary

    parsePrimary = function()
        local c = s:sub(i, i)
        if c == "(" then
            i = i + 1
            local v = parseExpr()
            if v == nil or s:sub(i, i) ~= ")" then return nil end
            i = i + 1
            return v
        end
        -- Number literal (including scientific notation and bare decimals)
        local numStr = s:match("^%d+%.?%d*[eE][+-]?%d+", i)
            or s:match("^%d*%.%d+", i)
            or s:match("^%d+", i)
        if numStr then
            i = i + #numStr
            return tonumber(numStr)
        end
        -- Named constant or function
        local name = s:match("^%a[%w_]*", i)
        if name then
            i = i + #name
            if s:sub(i, i) == "(" then
                i = i + 1
                local args = {}
                if s:sub(i, i) ~= ")" then
                    local a = parseExpr()
                    if a == nil then return nil end
                    args[1] = a
                    while s:sub(i, i) == "," do
                        i = i + 1
                        a = parseExpr()
                        if a == nil then return nil end
                        args[#args + 1] = a
                    end
                end
                if s:sub(i, i) ~= ")" then return nil end
                i = i + 1
                local fn = FUNCS[name]
                if not fn then return nil end
                return fn(unpack(args))
            end
            return CONSTS[name]
        end
        return nil
    end

    parsePower = function()
        local base = parsePrimary()
        if base == nil then return nil end
        if s:sub(i, i) == "^" then
            i = i + 1
            local exp = parseUnary() -- right-associative: delegate back to unary
            if exp == nil then return nil end
            return base ^ exp
        end
        return base
    end

    parseUnary = function()
        local c = s:sub(i, i)
        if c == "-" then
            i = i + 1; local v = parseUnary(); return v and -v
        end
        if c == "+" then
            i = i + 1; return parseUnary()
        end
        return parsePower()
    end

    parseTerm = function()
        local v = parseUnary()
        if v == nil then return nil end
        while true do
            local c = s:sub(i, i)
            if c == "*" then
                i = i + 1; local r = parseUnary(); if r == nil then return nil end; v = v * r
            elseif c == "/" then
                i = i + 1; local r = parseUnary(); if r == nil then return nil end; v = v / r
            elseif c == "%" then
                i = i + 1; local r = parseUnary(); if r == nil then return nil end; v = v % r
            else
                break
            end
        end
        return v
    end

    parseExpr = function()
        local v = parseTerm()
        if v == nil then return nil end
        while true do
            local c = s:sub(i, i)
            if c == "+" then
                i = i + 1; local r = parseTerm(); if r == nil then return nil end; v = v + r
            elseif c == "-" then
                i = i + 1; local r = parseTerm(); if r == nil then return nil end; v = v - r
            else
                break
            end
        end
        return v
    end

    local ok, result = pcall(parseExpr)
    if not ok or type(result) ~= "number" then return nil end
    if i <= #s then return nil end -- unconsumed trailing input → syntax error
    return result
end

-- ── Number formatting ─────────────────────────────────────────────────────────
local function formatNumber(n)
    if n ~= n then return "NaN" end
    if n == math.huge then return "∞" end
    if n == -math.huge then return "-∞" end
    if n == math.floor(n) and math.abs(n) < 1e15 then
        return tostring(math.floor(n))
    end
    return string.format("%.10g", n)
end

-- ── Provider ──────────────────────────────────────────────────────────────────
local CalcProvider = {
    type         = "calc",
    label        = L["Calculator"],
    aliases      = { "c", "calc", "math" },
    prefixOnly   = true,
    providerIcon = "Interface/ICONS/inv_misc_punchcards_yellow",
    color        = { r = 0.4, g = 1.0, b = 0.5 },
    labelColor   = { r = 0.85, g = 0.85, b = 0.2 },
    entries      = {},
}

function CalcProvider:onQuery(query)
    self.entries = {}
    if query == "" then return end

    local result    = evaluate(query)
    local resultStr = result and formatNumber(result)

    self.entries[1] = {
        name       = resultStr or query,
        icon       = "Interface/Icons/inv_misc_punchcards_yellow",
        type       = "calc",
        color      = resultStr and self.color or { r = 0.5, g = 0.5, b = 0.5 },
        labelColor = self.labelColor,
        _noPreview = not resultStr,
        getStats   = resultStr and function() return query .. "  =  " .. resultStr end or nil,
        onActivate = resultStr and function()
            DEFAULT_CHAT_FRAME:AddMessage(
                "|cffffcc00[Brannfred]|r  " .. query .. "  =  " .. resultStr)
        end or nil,
    }
end

Brannfred:RegisterProvider(CalcProvider)
