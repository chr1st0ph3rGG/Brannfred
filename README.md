# Brannfred

[![Github Repository](https://img.shields.io/badge/github-repo-blue?logo=github)](https://github.com/chr1st0ph3rGG/Brannfred)
[![CurseForge Downloads](https://img.shields.io/curseforge/dt/1473403)](https://www.curseforge.com/wow/addons/brannfred)

Brannfred brings a spotlight-style search bar to WoW Anniversary. One keybind opens a floating input where you can fuzzy-search spells, quests, inventory, equipment sets, and more — all from a single place, without knowing where to look first.

Use a bang prefix (e.g. `!s` or `!spell`) to narrow results to a specific source. Other addons can register their own data sources via the provider API.

> **Note:** Currently targets WoW Anniversary only. Porting to other versions is not planned but may be considered if there is enough interest.

The Brannfred Frame is completely customizable; you can change border, colors, and font in the Brannfred Settings. Additionally, all icons can be styled with Masque.

## Opening Brannfred

There are three ways to open the search bar:

- **Keybind** — Go to \_Game Menu → Key Bindings → Other and bind a key to **"Toggle Brannfred search"**. This is the recommended way. Default is `Ctrl-+`.
- **Slash commands** — Type `/brannfred` or `/bfrd` in chat to toggle the frame.
- **Minimap icon** — Left-click the Brannfred minimap button.

## Modules

Brannfred comes with a bunch of powerful modules from the get-go

### Spellbook

**Prefix:** `!s`, `!spell`, or `!skill`

Simple search inside your Spellbook. Trade skills (i.e. opening any of the crafting menus) can be opened directly from Brannfred. Skills and so on can be dragged into your Action Bars.

- **`Enter`** — casts the spell (profession/trade skills only; combat spells cannot be cast from the search bar).
- **Drag** — picks up the spell so you can drop it onto an Action Bar slot.
- **Hover over icon** — shows the full spell tooltip including cast time, range, cost, and cooldown.

### Inventory

**Prefix:** `!b`, `!bag`, or `!inv`

This Module requires the Syndicator Addon to be installed. Simply search within your Brannfred search bar for pretty much everything in your inventory, bank, or other characters' inventory. Additionally, if you have Baganator installed you will be led to the corresponding inventory/bank space where the item gets highlighted.

- **`Enter`** — opens your bags (or bank) and highlights the item via Baganator if available.
- **`Shift-Enter`** — inserts the item link into the active chat input.
- **`Ctrl-Enter`** — opens the Dressing Room for equippable items. The search frame stays open so you can try on multiple items in a row (configurable in the Inventory options).
- **Drag** — picks up the item so you can move it or link it.
- **Hover over icon** — shows the full item tooltip.

### Quests

**Prefix:** `!q` or `!quest`

This Module requires the Questie Addon. It lets you search your quest log: `Enter` will open the quest in your Quest Log, `Shift-Enter` will provide a link to the quest in Chat, `Ctrl-Enter` will show the Quest on the Map, and `Alt-Enter` will set a TomTom Waypoint to the next Quest objective (TomTom is not required to use this Module but this functionality will do nothing if TomTom is not installed).

### Calculator

**Prefix:** `!calc`, `!c`, or `!math`

You can do quite a bit of calculation with it… I needed a use case for a dynamic data provider and that was the result. I went a bit overboard since I would only use the basic stuff, but since Lua provides a broad set of functions I added them :)…

**Operators**

| Operator          | Description                                         |
| ----------------- | --------------------------------------------------- |
| `+` `-` `*` `/`   | Basic arithmetic                                    |
| `%`               | Modulo                                              |
| `^`               | Exponentiation (right-associative: `2^3^2` = `2^9`) |
| Unary `-` and `+` | Negation / identity                                 |
| `()`              | Parentheses for grouping: `(2 + 3) * 4`             |

**Constants**

| Constant | Value                     |
| -------- | ------------------------- |
| `pi`     | π (3.14159…)              |
| `e`      | Euler's number (2.71828…) |

**Functions**

| Function                | Description            |
| ----------------------- | ---------------------- |
| `sqrt(x)`               | Square root            |
| `abs(x)`                | Absolute value         |
| `floor(x)`              | Round down             |
| `ceil(x)`               | Round up               |
| `round(x)`              | Round to nearest       |
| `sin/cos/tan(x)`        | Trigonometry (radians) |
| `asin/acos/atan(x)`     | Inverse trig functions |
| `log(x)/ln(x)`          | Natural logarithm      |
| `log2(x)`               | Base-2 logarithm       |
| `log10(x)`              | Base-10 logarithm      |
| `exp(x)`                | e^x                    |
| `min(a,b,…)/max(a,b,…)` | Minimum / Maximum      |

### Friends

**Prefix:** `!f` — shows both Battle.net and in-game friends together.
Use `!bnet` / `!bn` to show only Battle.net friends, or `!friend` / `!fr` for in-game friends only.

Lists all your friends sorted by priority: in-game online friends appear first, followed by Battle.net online friends (e.g. playing another game), and offline friends always at the bottom. Online friends are shown in green, offline in grey.

- **`Enter`** — pre-fills the chat box with `/w <name>` so you can start typing immediately.
- **`Shift-Enter`** — invites the friend to your party (only works when they are actively in-game).

**Battle.net friends:** when the friend is playing WoW, their character name is shown with the BattleTag appended in blue parentheses (e.g. `Friedbert (John#1234)`). When online but not in WoW, only the BattleTag or Real ID name is shown. The meta column shows AFK, DND, Online, or Offline status.

**In-game friends:** the meta column shows their level when online, or `Offline` otherwise.

The detail panel shows class, current zone, and any friend note you have set.

### Equipment Sets

**Prefix:** `!eq`, `!equip`, `!set`, or `!gear`

Requires the ItemRack addon. Lists all your saved equipment sets. `Enter` equips the selected set. The meta column shows `[active]` for the currently worn set, or the number of item slots the set defines.

## Provider API

Any addon can register its own data source with Brannfred. Create a new addon with `Brannfred` as a dependency, implement a provider table, and call `Brannfred:RegisterProvider()`.

### Minimal example

```lua
local MyProvider = {
    type         = "mytype",            -- unique string, used for prefix filtering
    label        = "My Source",         -- shown in the type label column
    aliases      = { "my", "mine" },    -- bang-prefix shortcuts: !my, !mine
    providerIcon = "Interface/ICONS/…", -- icon shown in the ! autocomplete list
    color        = { r=1, g=1, b=1 },
    labelColor   = { r=0.4, g=0.8, b=1 },
    entries      = {},
}

function MyProvider:OnEnable()
    self.entries = {}
    self.entries[#self.entries + 1] = {
        name       = "My Entry",
        icon       = "Interface/ICONS/…",
        type       = "mytype",           -- must match provider.type
        color      = self.color,
        labelColor = self.labelColor,
        onActivate = function() print("activated!") end,
    }
end

Brannfred:RegisterProvider(MyProvider)
```

### Provider fields

| Field            | Required | Description                                                                    |
| ---------------- | -------- | ------------------------------------------------------------------------------ |
| `type`           | yes      | Unique identifier string. Used for `!prefix` filtering.                        |
| `label`          | yes      | Human-readable name shown in the type-label column.                            |
| `aliases`        | —        | Additional bang-prefix strings (e.g. `{ "s", "spell" }`).                      |
| `providerIcon`   | —        | Icon shown in the `!` autocomplete list. Falls back to the first entry's icon. |
| `color`          | —        | Default `{r,g,b}` for entry name text.                                         |
| `labelColor`     | —        | Default `{r,g,b}` for the type label column.                                   |
| `entries`        | —        | Flat list of entry tables. Populated in `OnEnable` or `onQuery`.               |
| `OnEnable()`     | —        | Called when Brannfred enables. Build `self.entries` here.                      |
| `prefixOnly`           | —        | `true` → excluded from global (unprefixed) search.                                              |
| `preserveOrder`        | —        | `true` → Search does not re-sort entries; the provider is responsible for ordering them itself. |
| `hideFromAutocomplete` | —        | `true` → provider is hidden from the `!` autocomplete list but still reachable via its aliases. |
| `onQuery(query)`       | —        | Called per keystroke for dynamic providers; build `self.entries` inside it.                     |

### Entry fields

| Field               | Required | Description                                                                |
| ------------------- | -------- | -------------------------------------------------------------------------- |
| `name`              | yes      | Display name and default fuzzy-match target.                               |
| `icon`              | yes      | Texture path or FileDataID.                                                |
| `type`              | yes      | Must equal `provider.type`.                                                |
| `color`             | —        | `{r,g,b}` override for the entry name text.                                |
| `labelColor`        | —        | `{r,g,b}` override for the type label.                                     |
| `searchName`        | —        | Alternative string used for fuzzy matching (e.g. `"Fireball Rank 5"`).     |
| `getMeta()`         | —        | Returns a short string for the meta column (color escape codes supported). |
| `getStats()`        | —        | Returns a one-line stat string shown in the description panel header.      |
| `getDesc()`         | —        | Returns a longer description shown below the separator line.               |
| `onActivate()`      | —        | Called on `Enter` or left-click.                                           |
| `onDrag()`          | —        | Called when the row is dragged (e.g. `PickupSpellBookItem`).               |
| `onShiftActivate()` | —        | Called on `Shift-Enter`.                                                                                                                                          |
| `onCtrlActivate()`  | —        | Called on `Ctrl-Enter`. The frame closes afterwards unless `ctrlKeepsOpen` is set.                                                                                |
| `onAltActivate()`   | —        | Called on `Alt-Enter`.                                                                                                                                            |
| `ctrlKeepsOpen`     | —        | `true` or a function returning a boolean. When truthy the search frame stays open after `onCtrlActivate` fires. Use a function to read a live DB setting.         |
| `onIconTooltip(anchor)` | —    | Called when the cursor enters the entry's icon (both in the result rows and the description panel). `anchor` is the icon button frame. Show a `GameTooltip` here. |
| `_noPreview`        | —        | `true` → suppresses the description panel for this entry.                                                                                                         |

### Dynamic providers

For providers whose results depend on the typed query (e.g. a calculator), implement `onQuery(query)` instead of a static `entries` list. Brannfred calls `provider:onQuery(query)` on every keystroke when the user types `!mytype <query>`, then reads `provider.entries`. Set `prefixOnly = true` so the provider stays invisible in global search.

```lua
local DynProvider = {
    type          = "dyn",
    label         = "Dynamic",
    aliases       = { "dyn" },
    prefixOnly    = true,
    preserveOrder = true,
    entries       = {},
}

function DynProvider:onQuery(query)
    self.entries = {}
    -- build entries based on query …
    self.entries[1] = { name = "Result: " .. query, icon = "…", type = "dyn" }
end

Brannfred:RegisterProvider(DynProvider)
```

### Options sub-page

Providers can add a sub-page under Brannfred in the Blizzard options panel:

```lua
Brannfred:RegisterProviderOptions("MyType", "My Source", {
    someToggle = {
        type = "toggle",
        name = "Enable feature",
        get  = function() return Brannfred.db.profile.myFeature end,
        set  = function(_, v) Brannfred.db.profile.myFeature = v end,
    },
})
```
