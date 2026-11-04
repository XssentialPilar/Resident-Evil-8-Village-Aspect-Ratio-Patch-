#include "RE8CursorPolicy.hpp"
#include "RE8CursorGeometry.hpp"
#include <limits>
#include <cstdlib>
#include <iostream>

void require(bool condition, const char* message) {
    if (!condition) { std::cerr << message << '\n'; std::exit(1); }
}
int main() {
    static_assert(re8_patch::is_authorized_cursor_driver("app.GUIShopBuy"));
    static_assert(re8_patch::is_authorized_cursor_driver("app.GUIShopSell"));
    static_assert(re8_patch::is_authorized_cursor_driver("app.GUIShopCustomize"));
    static_assert(re8_patch::is_authorized_cursor_driver("app.GUISaveLoad"));
    static_assert(!re8_patch::is_authorized_cursor_driver("app.GUISaveIcon"));
    static_assert(!re8_patch::is_authorized_cursor_driver("app.GUIHud"));
    using namespace re8_patch;
    for (const auto [width, height] : {std::pair{1440.0f, 1080.0f}, {1920.0f, 1200.0f},
        {1920.0f, 1080.0f}, {2560.0f, 1440.0f}, {3440.0f, 1440.0f}, {3840.0f, 2160.0f}}) {
        for (const auto scale : {0.5f, 1.0f, 1.5f, 2.0f}) {
            for (int step = 0; step < 100; ++step) {
                const float x = width * step / 100.0f, y = height * (99-step) / 100.0f;
                const auto pixel = cursor_pixels(x, y, width, height, width*scale, height*scale);
                require(pixel && std::abs(pixel->x-x*scale)<0.001f && std::abs(pixel->y-y*scale)<0.001f, "Absolute cursor scale mismatch");
                const auto normalized = cursor_normalized(*pixel,width*scale,height*scale);
                require(std::abs((normalized.x+1)*width/2-x)<0.001f && std::abs((1-normalized.y)*height/2-y)<0.001f, "Cursor normalized round trip drift");
            }
        }
    }
    const auto mixed = cursor_pixels(960,600,1920,1200,1440,1080);
    require(mixed && mixed->x == 720 && mixed->y == 540, "Different client/backbuffer aspects must map their centers exactly");
    require(!cursor_pixels(-1,0,1920,1200,1920,1200), "Outside client accepted");
    require(!cursor_pixels(1920,0,1920,1200,1920,1200), "Right edge outside client accepted");
    require(!cursor_pixels(0,0,0,1200,1920,1200), "Zero client size accepted");
    require(!cursor_pixels(0,0,1920,1200,std::numeric_limits<float>::infinity(),1200), "Infinite buffer accepted");
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
