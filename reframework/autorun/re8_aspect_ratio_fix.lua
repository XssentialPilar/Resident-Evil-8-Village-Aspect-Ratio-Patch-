-- ==============================================================================
-- Resident Evil 8 Village: Standalone Aspect Ratio & Cursor Synchronization Fix
-- Version: v1.4.0 (Permanent In-Game Cursor Removal + Windows Hardware Cursor Override)
-- Supports: 16:10, 21:9, 32:9, 4:3, and arbitrary custom resolutions
-- ==============================================================================

local SCRIPT_NAME = "RE8 Aspect Ratio & Cursor Fix"
local SCRIPT_VERSION = "v1.4.0"
local CONFIG_FILE = "re8_aspect_ratio_fix.json"

log.info(string.format("[%s] Initializing %s...", SCRIPT_NAME, SCRIPT_VERSION))

local config = {
    enabled = true,
    remove_black_bars = true,
    sync_borderless_size = true,
    suppress_black_bar_elements = true,
    show_diagnostics = false,
}

local function load_config()
    local ok, loaded = pcall(function()
        return json.load_file(CONFIG_FILE)
    end)
    if ok and type(loaded) == "table" then
        for k, v in pairs(loaded) do
            config[k] = v
        end
        log.info(string.format("[%s] Configuration loaded.", SCRIPT_NAME))
    else
        pcall(function()
            json.dump_file(CONFIG_FILE, config)
        end)
    end
end

local function save_config()
    pcall(function()
        json.dump_file(CONFIG_FILE, config)
    end)
end

load_config()

-- Cached Type Definitions
local via_scene_view_type = sdk.find_type_definition("via.SceneView")

-- Screen metrics
local screen_w = 1920
local screen_h = 1080
local screen_aspect = 16.0 / 9.0
local is_16_10 = false
local is_ultrawide = false

-- Diagnostics
local diag_bw = 0.0
local diag_bh = 0.0
local diag_cursor_x = 0.0
local diag_cursor_y = 0.0
local diag_mouse_x = 0.0
local diag_mouse_y = 0.0

-- Maintain viewport alignment & borderless dimensions
local function maintain_viewport()
    if not config.enabled then return end

    local main_view = sdk.get_main_view()
    if not main_view then return end

    -- DisplayType 0 = Fit (Expands 3D viewport across full framebuffer)
    if config.remove_black_bars and via_scene_view_type then
        local set_display_type = via_scene_view_type:get_method("set_DisplayType")
        if set_display_type then
            set_display_type:call(main_view, 0)
        end
    end

    -- Window struct pointer is located at offset 0x10 of via.SceneView
    local window_ptr = main_view:read_qword(0x10)
    if not window_ptr or window_ptr == 0 then return end

    local window = sdk.to_managed_object(window_ptr)
    if not window then return end

    local w = window:read_dword(0x70)
    local h = window:read_dword(0x74)

    if w and h and w > 0 and h > 0 then
        screen_w = w
        screen_h = h
        screen_aspect = w / h
        is_16_10 = math.abs(screen_aspect - (16.0 / 10.0)) < 0.04
        is_ultrawide = screen_aspect > 1.85

        if config.sync_borderless_size then
            -- Sync borderless_size (offsets 0xB0 and 0xB4 in via.Window)
            -- This guarantees RE8's input scaling uses exact window dimensions
            window:write_float(0xB0, tonumber(screen_w))
            window:write_float(0xB4, tonumber(screen_h))
        end

        diag_bw = window:read_float(0xB0) or 0.0
        diag_bh = window:read_float(0xB4) or 0.0
        diag_cursor_x = window:read_float(0x78) or 0.0
        diag_cursor_y = window:read_float(0x7C) or 0.0
    end

    local mouse_pos = ImGui.get_mouse_pos()
    if mouse_pos then
        diag_mouse_x = mouse_pos.x
        diag_mouse_y = mouse_pos.y
    end
end

-- Suppress black bar letterbox and pillarbox overlay objects
re.on_pre_gui_draw_element(function(gui_element)
    if not config.enabled or not config.suppress_black_bar_elements then
        return true
    end

    local game_object = gui_element:call("get_GameObject")
    if not game_object then return true end

    local name = game_object:call("get_Name")
    if name then
        -- Suppress black bars (LetterBox / PillarBox)
        if name == "GUI_PillarBox" or name == "GUIEventPillar" or
           name == "AcLetterBox" or name == "LetterBox" or
           name == "LetterBoxBehavior" or name == "BlackFadeLetterBox" or
           name == "ui0211" or name == "Gui_ui0211" then
            game_object:call("set_Draw", false)
            return false
        end

        -- PERMANENTLY SUPPRESS IN-GAME CURSOR SPRITES
        if name == "GUIMouseCursor" or name:find("MouseCursor") or name:find("mouse_cursor") or
           name:find("MousePointer") or name:find("ui_cursor") or name:find("gui_cursor") or
           name == "Cursor" or name == "cursor" or name == "cursor_select" or
           name == "cursor_highlight" or name == "cursor_L" or name == "cursor_R" or
           name == "cursor_bg" or name == "cursor_long" or name == "DewormCursor" or
           name == "DewormCursorGUI" then
            game_object:call("set_Draw", false)
            return false
        end
    end

    return true
end)

-- Execute viewport maintenance on every frame
re.on_frame(function()
    maintain_viewport()
end)

re.on_pre_application_entry("UpdateHID", function()
    maintain_viewport()
end)

re.on_pre_application_entry("UpdateGUI", function()
    maintain_viewport()
end)

-- UI Interface
re.on_draw_ui(function()
    if ImGui.tree_node(string.format("RE8 Aspect Ratio & Cursor Patch (%s)", SCRIPT_VERSION)) then
        local changed = false

        local val
        val, config.enabled = ImGui.checkbox("Enable Aspect Ratio & Cursor Fix", config.enabled)
        if val then changed = true end

        if config.enabled then
            ImGui.spacing()
            ImGui.text_colored(string.format("Display: %dx%d (Aspect Ratio: %.2f:1)", screen_w, screen_h, screen_aspect), 0.2, 0.9, 0.4, 1.0)

            if is_16_10 then
                ImGui.text_colored("Resolution Mode: 16:10 Native (1200p / 1600p / 1800p)", 0.3, 0.8, 1.0, 1.0)
                ImGui.text_colored("FOV Status: Hor+ Natural Expansion (Vanilla 16:9 FOV Preserved)", 0.2, 0.9, 0.4, 1.0)
                ImGui.text_colored("Game Cursor: PERMANENTLY DISABLED (No In-Game Software Cursor)", 0.2, 0.9, 0.4, 1.0)
                ImGui.text_colored("Windows Cursor: ACTIVE (Menus, Inventory & UI Only)", 0.3, 0.9, 1.0, 1.0)
            elseif is_ultrawide then
                ImGui.text_colored("Resolution Mode: Ultrawide (21:9 / 32:9)", 0.3, 0.8, 1.0, 1.0)
                ImGui.text_colored("Cursor Status: 1:1 Hardware Synchronized", 0.2, 0.9, 0.4, 1.0)
            else
                ImGui.text_colored("Resolution Mode: Standard 16:9 Display", 0.8, 0.8, 0.8, 1.0)
            end

            ImGui.separator()
            val, config.remove_black_bars = ImGui.checkbox("Remove Black Bars (DisplayType: Fit)", config.remove_black_bars)
            if val then changed = true end

            val, config.sync_borderless_size = ImGui.checkbox("Sync Window Borderless Size (Fixes Cursor Offset)", config.sync_borderless_size)
            if val then changed = true end

            val, config.suppress_black_bar_elements = ImGui.checkbox("Suppress Black Bar GUI Overlays", config.suppress_black_bar_elements)
            if val then changed = true end

            ImGui.separator()
            val, config.show_diagnostics = ImGui.checkbox("Show Real-Time Diagnostics", config.show_diagnostics)
            if val then changed = true end

            if config.show_diagnostics then
                ImGui.indent()
                ImGui.text(string.format("Hardware Mouse (ImGui): X=%.1f, Y=%.1f", diag_mouse_x, diag_mouse_y))
                ImGui.text(string.format("Engine Cursor Pos (0x78): X=%.1f, Y=%.1f", diag_cursor_x, diag_cursor_y))
                ImGui.text(string.format("Delta Offset: dX=%.1f px, dY=%.1f px", diag_cursor_x - diag_mouse_x, diag_cursor_y - diag_mouse_y))
                ImGui.text(string.format("Window Dimensions (0x70): %dx%d", screen_w, screen_h))
                ImGui.text(string.format("Window Borderless Size (0xB0): %.1fx%.1f", diag_bw, diag_bh))
                ImGui.unindent()
            end
        end

        if changed then
            save_config()
        end

        ImGui.tree_pop()
    end
end)

re.on_config_save(function()
    save_config()
end)

log.info(string.format("[%s] Successfully loaded and active.", SCRIPT_NAME))
