#include "RE8CursorPolicy.hpp"
#include <cstdlib>
#include <iostream>

void require(bool condition, const char* message) {
    if (!condition) { std::cerr << message << '\n'; std::exit(1); }
}
int main() {
    using namespace re8_patch;
    for (auto allowed : authorized_cursor_menus)
        require(is_authorized_cursor_menu(allowed), "Missing declared menu authorization");
    for (auto forbidden : {"Ammo", "Health", "InteractIcon", "Objective", "EventSkipGuide",
                           "RogueScore", "NightVision", "Scope", "Movie", "Book", "UnknownGUI",
                           "MouseCursor", "MapNotification", "MainMenuNotification", ""})
        require(!is_authorized_cursor_menu(forbidden), "HUD/unknown element authorized");
    // Interactive save-list variants are exact menu IDs; background persistence
    // and the in-world typewriter interaction prompt remain unauthorized.
    for (auto save_menu : {"SaveMenu", "Ch10SaveMenu", "SaveTransitionMenu", "SaveTransitionMenuCh10"})
        require(is_authorized_cursor_menu(save_menu), "Interactive save list not authorized");
    for (auto persistence : {"AutoSave", "SystemSave", "SaveLoadFlowManager", "SaveIcon", "TypewriterPrompt"})
        require(!is_authorized_cursor_menu(persistence), "Background save or interaction prompt authorized");
    // Exercise rapid menu/gameplay cycles: policy has no timers or sticky latch.
    for (int cycle = 0; cycle < 10000; ++cycle) {
        require(should_show_native_cursor(true, false, true), "Authorized menu hidden");
        require(!should_show_native_cursor(false, false, true), "Gameplay retained cursor");
        require(should_show_native_cursor(false, true, true), "Patch configuration hidden");
        require(!should_show_native_cursor(true, true, false), "Unfocused client retained authority");
        require(!should_show_native_cursor(false, false, false), "Unfocused gameplay retained authority");
    }
    std::cout << "Cursor policy: exact authorization, HUD rejection, focus and 10000 rapid cycles passed\n";
}
