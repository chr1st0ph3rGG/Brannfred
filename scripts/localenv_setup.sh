#!/bin/bash
# Core Module and Provider Modules getting symlinked to the WoW addon folder.

WOW_BASE="/Applications/World of Warcraft"

TARGETS=(
    "$WOW_BASE/_anniversary_/Interface/AddOns"
    "$WOW_BASE/_classic_era_/Interface/AddOns"
    "$WOW_BASE/_classic_/Interface/AddOns"
)

MODULES=(
    ".:Brannfred"
    "Providers/Calculator:Brannfred_Calc"
    "Providers/History:Brannfred_History"
    "Providers/Inventory:Brannfred_Inventory"
    "Providers/Menus:Brannfred_Menus"
    "Providers/Quests:Brannfred_Quests"
    "Providers/Spells:Brannfred_Spells"
    "Providers/EquipSets:Brannfred_EquipSets"
    "Providers/Friends:Brannfred_Friends"
    "Providers/ItemDB:Brannfred_ItemDB"
)

for target in "${TARGETS[@]}"; do
    for entry in "${MODULES[@]}"; do
        src="${entry%%:*}"
        name="${entry##*:}"
        ln -sfh "$PWD/$src" "$target/$name"
    done
done
