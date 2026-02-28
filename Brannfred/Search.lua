-- ── Fuzzy scoring ─────────────────────────────────────────────────────────────
local function fuzzyScore(str, pattern)
    str     = str:lower()
    pattern = pattern:lower()
    if pattern == "" then return 0 end

    local pos = str:find(pattern, 1, true)
    if pos then
        return 500 - pos + (pos == 1 and 200 or 0)
    end

    local score, si, pi, last, run = 0, 1, 1, 0, 0
    while si <= #str and pi <= #pattern do
        if str:sub(si, si) == pattern:sub(pi, pi) then
            run   = (si == last + 1) and run + 1 or 1
            score = score + run * 3
            if si == 1 then score = score + 10 end
            last = si
            pi   = pi + 1
        end
        si = si + 1
    end
    if pi <= #pattern then return nil end
    return score
end

-- ── Prefix parsing ────────────────────────────────────────────────────────────
-- "!spell fireball" → typeFilter="spell", query="fireball"
-- "!menu"           → typeFilter="menu",  query=""
-- "fireball"        → typeFilter=nil,     query="fireball"
-- Aliases ("!s", "!m", …) are declared by each provider via provider.aliases.
local function resolveTypePrefix(prefix)
    for _, provider in ipairs(Brannfred.providers) do
        if provider.type == prefix then return prefix end
        if provider.aliases then
            for _, alias in ipairs(provider.aliases) do
                if alias == prefix then return provider.type end
            end
        end
    end
    return prefix -- unknown → no results (no entry.type will match)
end

local function parseQuery(raw)
    local prefix, rest = raw:match("^!(%a+)%s*(.*)")
    if prefix then
        return resolveTypePrefix(prefix:lower()), rest
    end
    return nil, raw
end

-- ── Brannfred.Search ──────────────────────────────────────────────────────────────
-- Returns a list of { entry, score } sorted by score descending.
-- Supports optional type prefix: "!spell query", "!menu query", etc.
function Brannfred.Search(query, maxResults)
    maxResults = maxResults or 50
    query = query:match("^%s*(.-)%s*$")
    if query == "" then return {} end

    -- ── Prefix autocomplete ───────────────────────────────────────────────────
    -- "!"     → list all providers          "!sp" → filter to matching prefixes
    -- Skip when the partial is already an exact known type/alias (→ normal search).
    local prefixPartial = query:match("^!(%a*)$")
    if prefixPartial ~= nil then
        local partial = prefixPartial:lower()
        local skip = false
        if partial ~= "" then
            for _, p in ipairs(Brannfred.providers) do
                if p.type == partial then skip = true; break end
                for _, a in ipairs(p.aliases or {}) do
                    if a == partial then skip = true; break end
                end
                if skip then break end
            end
        end
        if not skip then
            local results = {}
            for _, provider in ipairs(Brannfred.providers) do
                local shortAlias = nil
                if partial == "" then
                    shortAlias = (provider.aliases and provider.aliases[1]) or provider.type
                else
                    for _, alias in ipairs(provider.aliases or {}) do
                        if alias:sub(1, #partial) == partial then
                            shortAlias = alias; break
                        end
                    end
                    if not shortAlias and provider.type:sub(1, #partial) == partial then
                        shortAlias = (provider.aliases and provider.aliases[1]) or provider.type
                    end
                end
                if shortAlias then
                    local icon = provider.providerIcon
                        or (provider.entries and provider.entries[1] and provider.entries[1].icon)
                        or "134400"
                    local entry
                    if provider.directActivate then
                        entry = {
                            name       = provider.label or provider.type,
                            icon       = icon,
                            type       = provider.type,
                            color      = provider.labelColor or { r = 0.8, g = 0.8, b = 0.8 },
                            labelColor = { r = 0.45, g = 0.45, b = 0.45 },
                            getMeta    = function() return "!" .. shortAlias end,
                            onActivate = provider.directActivate,
                        }
                    else
                        entry = {
                            name        = provider.label or provider.type,
                            icon        = icon,
                            type        = "_prefix",
                            color       = provider.labelColor or { r = 0.8, g = 0.8, b = 0.8 },
                            labelColor  = { r = 0.45, g = 0.45, b = 0.45 },
                            getMeta     = function() return "!" .. shortAlias end,
                            _insertText = "!" .. shortAlias .. " ",
                        }
                    end
                    results[#results + 1] = { entry = entry, score = 0 }
                end
            end
            return results
        end
    end

    local typeFilter, actualQuery = parseQuery(query)

    local scored = {}
    local preserveOrder = false
    local disabledProviders = Brannfred.db and Brannfred.db.profile.disabledProviders or {}
    for _, provider in ipairs(Brannfred.providers) do
        -- prefixOnly providers are excluded from global (unfiltered) search;
        -- user-disabled providers are also skipped in global search.
        local hiddenGlobally = not typeFilter
            and (provider.prefixOnly or disabledProviders[provider.type])
        if not hiddenGlobally then
            if typeFilter and provider.prefixOnly and provider.preserveOrder then
                preserveOrder = true
            end
            -- Dynamic providers (e.g. calculator) build their own entries per query;
            -- skip fuzzy scoring for them – they already decided what to show.
            local isDynamic = typeFilter and provider.type == typeFilter and provider.onQuery
            if isDynamic then
                provider:onQuery(actualQuery)
            end
            for _, entry in ipairs(provider.entries or {}) do
                if not typeFilter or entry.type == typeFilter then
                    if actualQuery == "" or isDynamic then
                        scored[#scored + 1] = { entry = entry, score = 0 }
                    else
                        local score = fuzzyScore(entry.searchName or entry.name, actualQuery)
                        if score then
                            scored[#scored + 1] = { entry = entry, score = score }
                        end
                    end
                end
            end
        end
    end

    local function sortKey(e) return e.searchName or e.name end

    if actualQuery == "" then
        -- providers with preserveOrder keep insertion order (e.g. history)
        if not preserveOrder then
            table.sort(scored, function(a, b) return sortKey(a.entry) < sortKey(b.entry) end)
        end
    else
        table.sort(scored, function(a, b)
            if a.score ~= b.score then return a.score > b.score end
            return sortKey(a.entry) < sortKey(b.entry)
        end)
    end

    local results = {}
    for i = 1, math.min(#scored, maxResults) do
        results[i] = scored[i]
    end
    return results
end
