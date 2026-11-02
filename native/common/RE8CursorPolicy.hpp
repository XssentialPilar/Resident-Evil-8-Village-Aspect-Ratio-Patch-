#pragma once
#include <array>
#include <string_view>

namespace re8_patch {
// Exact app.MenuDefine fields recovered from RE8's TDB69. No name substrings,
// generic GUI state, player absence, HID cursor requests or keyboard guesses.
inline constexpr auto authorized_cursor_menus = std::to_array<std::string_view>({
    "TitleMenu", "ShowTitleMenu", "MainMenu", "DemoTitle", "DemoMainMenu",
    "Ch10MainMenu", "RogueMainMenu", "RogueTitle", "RogueTitleGE",
    "BonusMenu", "GE_BonusMenu", "GalleryMenu", "StoreMenu", "SubMenu",
    "DifficultyMenu", "DifficultyWithVeryHardMenu", "ConceptArt", "ConceptArtList",
    "Figure", "FigureList", "ExtraArt", "ExtraArtList", "MovieList",
    "PauseMenu", "PauseClearGameMenu", "SystemPauseMenu", "EventPauseMenu",
    "EventPauseClearGameMenu", "EventPauseEndingMenu", "EventPauseNoSkipMenu",
    "EventPauseNoSkipClearGameMenu", "MoviePauseMenu", "MoviePauseClearGameMenu",
    "RoguePauseMenu", "RoguePauseClearGameMenu",
    "OptionPreset", "InitialSetting", "AdjustmentMenu", "AccessibilitySetting",
    "PlayerCameraTypeSetting", "KeyAssignMenu", "KeyHelpMenu", "KeyHelpVitaMenu",
    "AdditionalKeyAssignMenuGE", "AdditionalKeyHelpMenuGE", "ReNetSetting", "ReNetAgreement",
    "ShopMenu", "ShopMenuUnlimited", "ShopBuyMenu", "ShopSellMenu", "ShopRecipeMenu",
    "ShopCustomizeMenu", "ShopCustomizing", "ShopCustomizingSubMenu0",
    "ShopCustomizingSubMenu1", "ShopCustomizingSubMenu2", "ShopCustomizingSubMenu3",
    "InventoryMenu", "InventoryRogueMenu", "InventoryItem", "InventoryCraft",
    "InventoryKeyItem", "InventoryTreasure", "InventoryAbility", "InventoryStatus",
    "SaveMenu", "LoadMenu", "Ch10SaveMenu", "Ch10LoadMenu",
    "SaveTransitionMenu", "SaveTransitionMenuCh10", "Map"
});
constexpr bool is_authorized_cursor_menu(std::string_view name) {
    for (auto allowed : authorized_cursor_menus) {
        if (name == allowed) return true;
    }
    return false;
}
constexpr bool should_show_native_cursor(bool known_menu_visible, bool patch_config_open,
                                         bool focused_client) {
    return focused_client && (known_menu_visible || patch_config_open);
}
}
