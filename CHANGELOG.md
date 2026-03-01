# Changelog

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
