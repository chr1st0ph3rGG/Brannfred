# Changelog

## 2.0.0

### Major Features

- **Context Menu System** — Complete redesign of how Brannfred handles actions:
  - Right-click on any result to open a context menu showing all available actions
  - Press `Tab` to quickly open the context menu for the currently selected result
  - Each action can be triggered via keybinding (modifier keys), mouse click, or number keys (1–0) in the menu
  - All providers now use the new `context_actions` system instead of `onActivate`/`onShiftActivate`/`onCtrlActivate`/`onAltActivate`

- **Modifier-based Action System** — Each entry can define multiple actions with different modifier keys:
  - **Primary** (`Enter` / Left-click) — the main action
  - **Shift**, **Ctrl**, **Alt** — hold these keys while pressing `Enter` or clicking for alternative actions
  - All modifier key assignments are **configurable per provider** in the addon options
  - Users can disable specific modifiers or reassign them as needed

- **Comprehensive Localization** — Support for 9 languages:
  - German (deDE), English (enUS), Spanish (esES), French (frFR), Italian (itIT), Korean (koKR), Portuguese (ptBR), Simplified Chinese (zhCN), Traditional Chinese (zhTW)
  - All providers and UI strings are now fully translated in all supported languages

- **New Context Menu UI** —
  - Shows entry name and all available actions with their modifier hints (`[En]`, `[Sh]`, `[Ct]`, `[Al]`)
  - Navigate with arrow keys or number keys
  - Press `Enter` to activate, `Escape`/`Tab` to close

### Changes

- **Inventory provider** — Actions refactored to context system; UI changed from "click mode" config option to direct action selection in context menu
- **Item Database, Quests, Spells, Friends, Equipment Sets, Menus providers** — All updated to use new context action system
- **Calculator provider** — Refactored to use context actions with "Result" as the primary action
- **Spell provider** — "Open profession" is now the primary action; "Link in Chat" is secondary (Shift)
- **Quests provider** — Added "Open in Quest Log", "Link in Chat", "Show on Map", "TomTom Waypoint" as configurable actions
- **Friends provider** — Added "Whisper" and "Invite to Party" actions with configurable modifiers
- **README** — Extensively updated with documentation on the new context menu system, modifier keys, and provider API changes

### Bugfixes

- Removed "Combat Log" menu entry, was not working anyway

### For Addon Developers

If you're using the Brannfred Provider API, you must update your entries:

**Old (1.x):**

```lua
entry.onActivate       = function() ... end
entry.onShiftActivate  = function() ... end
entry.onCtrlActivate   = function() ... end
entry.onAltActivate    = function() ... end
```

**New (2.0):**

```lua
entry.context_actions = {
    { name = "Action 1", func = function() ... end, modifier = "primary" },
    { name = "Action 2", func = function() ... end, modifier = "shift" },
    { name = "Action 3", func = function() ... end, modifier = "ctrl" },
}
```

All entries **must** define at least one action (usually with `modifier = "primary"`). See the README for complete documentation.

## 1.3.1

### Changes

- Classic MoP Support - Only the Equipment Set Provider is not yet working since it will require me to implement Blizzards Equipment Manager (Which I most likeley will not do now since I don't play Classic MoP)

## 1.3.0

### New Features

- Classic support — Brannfred now runs on Classic (Anniversary / Era / Hardcore / SoD); MoP Support will be added with the next Version

### Changes

- Keybinding: replaced the `Bindings.xml` approach with a custom in-game key-capture dialog accessible from the options panel, since it generated some annyoing warnings.
- Appearance: font and border dropdowns now use LibSharedMedia-3.0 — fonts are previewed in their own typeface (via LibDDI-1.0) and additional media registered by other addons (e.g. SharedMedia) is available automatically

### Bugfix

- Fixed a Event related bug in the Spell Provider

## 1.2.3

### Bugfix

- Fix ugly looking description text

## 1.2.2

### Bugfix

- Fix .pkgmeta to correctly move providers

## 1.2.1

### Changes

- Rearrange code stucture so it may work with packager

## 1.2.0

### New Features

- Item Database module (`Brannfred_ItemDB`) — search for items you don't own via `!idb` / `!itemdb`; uses Ludwig's item database
- Inventory: quality colours — item names are now coloured by rarity (grey / white / green / blue / purple / orange)
- Inventory: use / equip mode — new option to use or equip items directly on click; Ctrl+click shows the item in your bags instead (configurable, default is the previous behaviour)
- Quests: difficulty colours — quest names coloured by level difficulty relative to your character; completed quests show a green _(Completed)_ suffix; failed quests have their icon tinted red
- Friends: distinct type labels — Battle.net and in-game friends now show _Battle.net_ / _In-Game_ in the type column when listed together via `!f`

### Provider API

- Added: `iconColor` field on entries — `{r,g,b}` tint applied to the entry icon via `SetVertexColor` (defaults to white / no tint)

--

## 1.1.0

### New Features

- Friends Provider — Search your server and BattleNet friends

### Provider API

- Added: `onShiftActivate`, `onCtrlActivate`, and `onAltActivate` are now preserved
  in history entries — modifier-key handlers work correctly when an entry is activated
  from the history list.
- Added: `hideFromAutocomplete` field — set to `true` on a provider to exclude it
  from the `!` prefix suggestion list.
- Improved: Type-prefix aliases now support matching multiple providers at once,
  allowing providers to share a common prefix (e.g. `!f` → `friend` + `bnet`).

--

## v1.0.0 — Initial Release

Brannfred is a spotlight-style search addon for WoW Anniversary. Open a single floating search bar with one keybind and find spells, quests, inventory items, and equipment sets — without knowing where to look first.

### Features

Spellbook search — find and cast spells or open trade skills directly; drag entries to your action bars
Inventory search — search bags, bank, and alts (requires Syndicator); jump to item location with Bagnon support
Quest search — open, link, map, or set TomTom waypoints for quests (requires Questie)
Equipment sets — browse and equip ItemRack sets
Calculator — evaluate math expressions inline (!calc)
Bang prefixes — narrow results to a specific source (e.g. !s for spells, !q for quests)
Provider API — other addons can register their own data sources
Fully customizable — border, colors, font via Brannfred settings; icon styling via Masque
