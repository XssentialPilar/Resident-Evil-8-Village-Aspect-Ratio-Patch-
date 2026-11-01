-- ==============================================================================
-- Resident Evil 8 Village: Aspect Ratio & Ghost Cursor Synchronization Fix
-- Standalone Mod for REFramework
-- Compatible with 16:10, 21:9, 32:9, 4:3, and arbitrary resolutions
-- ==============================================================================

local SCRIPT_NAME = "RE8 Aspect Ratio & Cursor Fix"
local SCRIPT_VERSION = "v1.1.0"
local CONFIG_FILE = "re8_aspect_ratio_fix.json"

log.info(string.format("[%s] Initializing %s...", SCRIPT_NAME, SCRIPT_VERSION))

-- Default configuration
local config = {
    enabled = true,
    remove_black_bars = true,
    sync_cursor = true,
    auto_align_viewport = true,
    fov_adjustment = true,
    constrain_hud_16_9 = false,
    preset = 1, -- 1: Direct 1:1, 2: 16:10 Offset, 3: 16:10 Scale, 4: 21:9 Ultrawide, 5: Custom
    cursor_offset_x = 0.0,
    cursor_offset_y = 0.0,
    cursor_scale_x = 1.0,
    cursor_scale_y = 1.0,
    show_diagnostics = false,
}

local PRESET_NAMES = {
    "1:1 Direct Hardware Sync (Default)",
    "16:10 Offset Compensated (+60 Y)",
    "16:10 Scale Compensated (x1.111 Y)",
    "21:9 Ultrawide Offset",
    "Custom Calibration",
}

-- Safe config loader
local function load_config()
    local ok, loaded = pcall(function()
        return json.load_file(CONFIG_FILE)
    end)
    if ok and type(loaded) == "table" then
        for k, v in pairs(loaded) do
            config[k] = v
        end
        log.info(string.format("[%s] Configuration successfully loaded.", SCRIPT_NAME))
    else
        log.info(string.format("[%s] Initializing default configuration.", SCRIPT_NAME))
        pcall(function()
            json.dump_file(CONFIG_FILE, config)
        end)
    end
end

-- Safe config saver
local function save_config()
    local ok, err = pcall(function()
        json.dump_file(CONFIG_FILE, config)
    end)
    if ok then
        log.info(string.format("[%s] Configuration saved to %s.", SCRIPT_NAME, CONFIG_FILE))
    else
        log.error(string.format("[%s] Failed to save configuration: %s", SCRIPT_NAME, tostring(err)))
    end
end

load_config()

-- Cached Type Definitions and Singletons
local via_scene_view_type = sdk.find_type_definition("via.SceneView")
local via_camera_type = sdk.find_type_definition("via.Camera")
local via_gui_view_type = sdk.find_type_definition("via.gui.View")

-- Runtime state tracking
local screen_w = 1920
local screen_h = 1080
local screen_aspect = 16.0 / 9.0
local is_16_10 = false
local is_ultrawide = false
local is_custom_ratio = false
local letterbox_offset_y = 0.0
local pillarbox_offset_x = 0.0

-- Diagnostics tracking
local diag_hw_x = 0.0
local diag_hw_y = 0.0
local diag_game_x = 0.0
local diag_game_y = 0.0
local diag_delta_x = 0.0
local diag_delta_y = 0.0
local diag_bw = 0.0
local diag_bh = 0.0
local diag_sv_w = 0.0
local diag_sv_h = 0.0

-- Apply calibration presets
local function apply_preset(index)
    config.preset = index
    if index == 1 then
        -- 1:1 Direct hardware coordinates
        config.cursor_offset_x = 0.0
        config.cursor_offset_y = 0.0
        config.cursor_scale_x = 1.0
        config.cursor_scale_y = 1.0
    elseif index == 2 then
        -- 16:10 Letterbox offset compensation
        config.cursor_offset_x = 0.0
        config.cursor_offset_y = letterbox_offset_y > 0 and letterbox_offset_y or 60.0
        config.cursor_scale_x = 1.0
        config.cursor_scale_y = 1.0
    elseif index == 3 then
        -- 16:10 Inverse aspect ratio scale (1200 / 1080 = 1.1111)
        config.cursor_offset_x = 0.0
        config.cursor_offset_y = 0.0
        config.cursor_scale_x = 1.0
        config.cursor_scale_y = screen_h > 0 and (screen_h / (screen_w / (16.0 / 9.0))) or (1200.0 / 1080.0)
    elseif index == 4 then
        -- 21:9 Ultrawide compensation
        config.cursor_offset_x = pillarbox_offset_x > 0 and pillarbox_offset_x or 320.0
        config.cursor_offset_y = 0.0
        config.cursor_scale_x = 1.0
        config.cursor_scale_y = 1.0
    end
end

-- Refresh screen metrics and detect resolution
local function update_screen_metrics(main_view, window)
    if not window then return end

    local w = window:call("get_Width")
    local h = window:call("get_Height")

    if w and h and w > 0 and h > 0 then
        screen_w = w
        screen_h = h
        screen_aspect = w / h

        is_16_10 = math.abs(screen_aspect - (16.0 / 10.0)) < 0.03
        is_ultrawide = screen_aspect > 1.85
        is_custom_ratio = math.abs(screen_aspect - (16.0 / 9.0)) > 0.03

        if is_16_10 then
            local standard_h = screen_w / (16.0 / 9.0)
            letterbox_offset_y = (screen_h - standard_h) / 2.0
            pillarbox_offset_x = 0.0
        elseif is_ultrawide then
            local standard_w = screen_h * (16.0 / 9.0)
            pillarbox_offset_x = (screen_w - standard_w) / 2.0
            letterbox_offset_y = 0.0
        else
            letterbox_offset_y = 0.0
            pillarbox_offset_x = 0.0
        end

        -- Auto-align borderless_size in via.Window struct (offset 0xB0)
        -- RE Engine uses this offset to clamp and transform mouse screen coordinates
        if config.auto_align_viewport then
            pcall(function()
                window:write_float(0xB0, tonumber(screen_w))
                window:write_float(0xB4, tonumber(screen_h))
            end)
        end
    end
end

-- Viewport and DisplayType alignment
local function align_viewport(main_view)
    if not config.enabled or not config.remove_black_bars or not main_view then
        return
    end

    -- Force SceneView resolution offsets to match full display
    if config.auto_align_viewport and screen_w > 0 and screen_h > 0 then
        pcall(function()
            main_view:write_float(0x30, tonumber(screen_w)) -- size.w
            main_view:write_float(0x34, tonumber(screen_h)) -- size.h
            main_view:write_float(0x38, tonumber(screen_w)) -- custom_display_size.w
            main_view:write_float(0x3C, tonumber(screen_h)) -- custom_display_size.h
            main_view:write_float(0x40, tonumber(screen_w)) -- present_rect.w
            main_view:write_float(0x44, tonumber(screen_h)) -- present_rect.h
        end)
    end

    -- DisplayType 0 = Fit (Fills entire display without letterbox or pillarbox)
    if via_scene_view_type then
        local set_display_type = via_scene_view_type:get_method("set_DisplayType")
        if set_display_type then
            set_display_type:call(main_view, 0)
        end
    end

    -- FOV Adaptation
    if config.fov_adjustment and is_custom_ratio and via_camera_type then
        local camera = sdk.get_primary_camera()
        if camera then
            local set_vert_enable = via_camera_type:get_method("set_VerticalEnable")
            if set_vert_enable then
                set_vert_enable:call(camera, true)
            end
        end
    end
end

-- Core Cursor Synchronization Routine
local function synchronize_cursor(window)
    if not config.enabled or not config.sync_cursor or not window then
        return
    end

    -- Read hardware mouse position from ImGui
    local mouse_pos = ImGui.get_mouse_pos()
    if not mouse_pos then return end

    diag_hw_x = mouse_pos.x
    diag_hw_y = mouse_pos.y

    -- Read current engine cursor coordinates from via.Window (0x78, 0x7C)
    local cur_x = window:read_float(0x78)
    local cur_y = window:read_float(0x7C)
    if cur_x and cur_y then
        diag_game_x = cur_x
        diag_game_y = cur_y
        diag_delta_x = cur_x - diag_hw_x
        diag_delta_y = cur_y - diag_hw_y
    end

    -- Compute target cursor coordinate
    local target_x = (diag_hw_x + config.cursor_offset_x) * config.cursor_scale_x
    local target_y = (diag_hw_y + config.cursor_offset_y) * config.cursor_scale_y

    -- Clamp to screen limits
    if target_x < 0 then target_x = 0 end
    if target_x > screen_w then target_x = screen_w end
    if target_y < 0 then target_y = 0 end
    if target_y > screen_h then target_y = screen_h end

    -- Write synchronized position directly into RE Engine's cursor struct
    pcall(function()
        window:write_float(0x78, target_x)
        window:write_float(0x7C, target_y)
    end)
end

-- Suppress black bar letterbox and pillarbox GUI objects
re.on_pre_gui_draw_element(function(gui_element)
    if not config.enabled or not config.remove_black_bars then
        return true
    end

    local game_object = gui_element:call("get_GameObject")
    if not game_object then return true end

    local name = game_object:call("get_Name")
    if name then
        if name == "GUI_PillarBox" or name == "GUIEventPillar" or
           name == "AcLetterBox" or name == "LetterBox" or
           name == "LetterBoxBehavior" or name == "BlackFadeLetterBox" or
           name == "ui0211" then
            game_object:call("set_Draw", false)
            return false
        end
    end

    -- Constrain UI if user requested 16:9 safe frame
    if config.constrain_hud_16_9 and via_gui_view_type then
        local view = gui_element:call("get_View")
        if view then
            local set_res_adjust = via_gui_view_type:get_method("set_ResolutionAdjust(System.Boolean)")
            local set_scale = via_gui_view_type:get_method("set_ResAdjustScale(via.gui.ResolutionAdjustScale)")
            local set_anchor = via_gui_view_type:get_method("set_ResAdjustAnchor(via.gui.ResolutionAdjustAnchor)")

            if set_res_adjust and set_scale and set_anchor then
                set_scale:call(view, 2) -- FitSmallRatioAxis
                set_anchor:call(view, 4) -- CenterCenter
                set_res_adjust:call(view, true)
            end
        end
    end

    return true
end)

-- Frame lifecycle hooks
re.on_frame(function()
    local main_view = sdk.get_main_view()
    if not main_view then return end

    local window = main_view:call("get_Window")
    if not window then return end

    update_screen_metrics(main_view, window)
    align_viewport(main_view)
    synchronize_cursor(window)

    -- Cache diagnostics values
    diag_bw = window:read_float(0xB0) or 0.0
    diag_bh = window:read_float(0xB4) or 0.0
    diag_sv_w = main_view:read_float(0x30) or 0.0
    diag_sv_h = main_view:read_float(0x34) or 0.0
end)

-- Pre-application entry hooks for precise input interception
re.on_pre_application_entry("UpdateHID", function()
    local main_view = sdk.get_main_view()
    if main_view then
        local window = main_view:call("get_Window")
        if window then
            synchronize_cursor(window)
        end
    end
end)

re.on_pre_application_entry("UpdateGUI", function()
    local main_view = sdk.get_main_view()
    if main_view then
        local window = main_view:call("get_Window")
        if window then
            synchronize_cursor(window)
        end
    end
end)

-- REFramework ImGui Menu Interface
re.on_draw_ui(function()
    if ImGui.tree_node("RE8 Aspect Ratio & Ghost Cursor Fix (" .. SCRIPT_VERSION .. ")") then
        local changed = false

        local val
        val, config.enabled = ImGui.checkbox("Enable Mod", config.enabled)
        if val then changed = true end

        if config.enabled then
            ImGui.spacing()
            ImGui.text_colored(string.format("Current Display: %dx%d (Aspect Ratio: %.2f:1)", screen_w, screen_h, screen_aspect), 0.2, 0.9, 0.4, 1.0)
            if is_16_10 then
                ImGui.text_colored("Status: 16:10 Display Detected (Native 1200p / 1600p / 1800p)", 0.3, 0.8, 1.0, 1.0)
            elseif is_ultrawide then
                ImGui.text_colored("Status: Ultrawide Display Detected (21:9 / 32:9)", 0.3, 0.8, 1.0, 1.0)
            else
                ImGui.text_colored("Status: Standard 16:9 Display", 0.8, 0.8, 0.8, 1.0)
            end

            ImGui.separator()
            ImGui.text("Aspect Ratio & Viewport Options:")
            val, config.remove_black_bars = ImGui.checkbox("Remove Black Bars (Aspect Ratio Fix)", config.remove_black_bars)
            if val then changed = true end

            val, config.auto_align_viewport = ImGui.checkbox("Auto-Align Viewport & Borderless Resolution", config.auto_align_viewport)
            if val then changed = true end

            val, config.fov_adjustment = ImGui.checkbox("Automatic Vertical FOV Preservation (Hor+)", config.fov_adjustment)
            if val then changed = true end

            val, config.constrain_hud_16_9 = ImGui.checkbox("Constrain HUD Elements to 16:9 Center", config.constrain_hud_16_9)
            if val then changed = true end

            ImGui.separator()
            ImGui.text("Ghost Cursor Elimination & Alignment:")
            val, config.sync_cursor = ImGui.checkbox("Synchronize In-Game Cursor with Mouse", config.sync_cursor)
            if val then changed = true end

            if config.sync_cursor then
                ImGui.spacing()
                local preset_changed
                preset_changed, config.preset = ImGui.combo("Calibration Preset", config.preset, PRESET_NAMES)
                if preset_changed then
                    apply_preset(config.preset)
                    changed = true
                end

                val, config.cursor_offset_x = ImGui.slider_float("Cursor Offset X (px)", config.cursor_offset_x, -400.0, 400.0)
                if val then
                    config.preset = 5
                    changed = true
                end

                val, config.cursor_offset_y = ImGui.slider_float("Cursor Offset Y (px)", config.cursor_offset_y, -400.0, 400.0)
                if val then
                    config.preset = 5
                    changed = true
                end

                val, config.cursor_scale_x = ImGui.slider_float("Cursor Scale X", config.cursor_scale_x, 0.5, 1.5)
                if val then
                    config.preset = 5
                    changed = true
                end

                val, config.cursor_scale_y = ImGui.slider_float("Cursor Scale Y", config.cursor_scale_y, 0.5, 1.5)
                if val then
                    config.preset = 5
                    changed = true
                end

                if ImGui.button("Reset to 1:1 Direct Sync") then
                    apply_preset(1)
                    changed = true
                end
                ImGui.same_line()
                if ImGui.button("Apply 16:10 (+60px Y)") then
                    apply_preset(2)
                    changed = true
                end
                ImGui.same_line()
                if ImGui.button("Apply 16:10 Inverse Scale") then
                    apply_preset(3)
                    changed = true
                end
            end

            ImGui.separator()
            val, config.show_diagnostics = ImGui.checkbox("Show Real-Time Diagnostics", config.show_diagnostics)
            if val then changed = true end

            if config.show_diagnostics then
                ImGui.indent()
                ImGui.text(string.format("Windows Hardware Mouse: X=%.1f, Y=%.1f", diag_hw_x, diag_hw_y))
                ImGui.text(string.format("Game Cursor Pos (0x78): X=%.1f, Y=%.1f", diag_game_x, diag_game_y))
                ImGui.text(string.format("Offset Delta: dX=%.1f px, dY=%.1f px", diag_delta_x, diag_delta_y))
                ImGui.text(string.format("Window borderless_size (0xB0): %.1fx%.1f", diag_bw, diag_bh))
                ImGui.text(string.format("SceneView Size (0x30): %.1fx%.1f", diag_sv_w, diag_sv_h))
                ImGui.unindent()
            end

            ImGui.spacing()
            if ImGui.button("Save Current Settings") then
                save_config()
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
