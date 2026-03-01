#!/bin/bash
# Core Module and Provider Modules getting symlinked to the WoW addon folder.
ln -sfh "$PWD" "/Applications/World of Warcraft/_anniversary_/Interface/AddOns/Brannfred"
ln -sfh "$PWD/Providers/Calculator" "/Applications/World of Warcraft/_anniversary_/Interface/AddOns/Brannfred_Calc"
ln -sfh "$PWD/Providers/History" "/Applications/World of Warcraft/_anniversary_/Interface/AddOns/Brannfred_History"
ln -sfh "$PWD/Providers/Inventory" "/Applications/World of Warcraft/_anniversary_/Interface/AddOns/Brannfred_Inventory"
ln -sfh "$PWD/Providers/Menus" "/Applications/World of Warcraft/_anniversary_/Interface/AddOns/Brannfred_Menus"
ln -sfh "$PWD/Providers/Quests" "/Applications/World of Warcraft/_anniversary_/Interface/AddOns/Brannfred_Quests"
ln -sfh "$PWD/Providers/Spells" "/Applications/World of Warcraft/_anniversary_/Interface/AddOns/Brannfred_Spells"
ln -sfh "$PWD/Providers/EquipSets" "/Applications/World of Warcraft/_anniversary_/Interface/AddOns/Brannfred_EquipSets"
ln -sfh "$PWD/Providers/Friends" "/Applications/World of Warcraft/_anniversary_/Interface/AddOns/Brannfred_Friends"
ln -sfh "$PWD/Providers/ItemDB" "/Applications/World of Warcraft/_anniversary_/Interface/AddOns/Brannfred_ItemDB"