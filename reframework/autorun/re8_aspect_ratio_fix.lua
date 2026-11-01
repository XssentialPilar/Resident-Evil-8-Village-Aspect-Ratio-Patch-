-- ==============================================================================
-- Resident Evil Village (RE8) - Aspect Ratio & Cursor Alignment Patch
-- Author: XssentialPilar
-- Compatibility: REFramework (1.5.9+ and Nightly builds)
-- Supported Ratios: 16:10 (1920x1200, 2560x1600, 2880x1800), 21:9, 32:9, 4:3, etc.
-- ==============================================================================

local SCRIPT_NAME = "RE8 Aspect Ratio & Cursor Patch"
local SCRIPT_VERSION = "v1.0.0"

-- Ensure this script only runs for Resident Evil 8 Village
local game_name = reframework:get_game_name()
if game_name ~= "re8" then
    return
end

log.info("[" .. SCRIPT_NAME .. "] Initializing " .. SCRIPT_VERSION .. " for RE8...")

-- Configuration defaults
local config = {
    enabled = true,
    remove_black_bars = true,
    fix_cursor_offset = true,
    hide_windows_cursor_in_game = true,
    constrain_hud_16_9 = false,
    horizontal_fov_adjust = true,
    fov_multiplier = 1.0,
    cursor_x_offset = 0.0,
    cursor_y_offset = 0.0,
    cursor_scale_x = 1.0,
    cursor_scale_y = 1.0,
}

local CONFIG_FILE = "re8_aspect_ratio_fix.json"

local function load_config()
    local loaded = json.load_file(CONFIG_FILE)
    if loaded then
        for k, v in pairs(loaded) do
            config[k] = v
        end
        log.info("[" .. SCRIPT_NAME .. "] Configuration loaded successfully.")
    end
end

local function save_config()
    json.dump_file(CONFIG_FILE, config)
    log.info("[" .. SCRIPT_NAME .. "] Configuration saved.")
end

load_config()

-- Cached SDK Types and Singletons
local scene_manager = sdk.get_native_singleton("via.SceneManager")
local scene_manager_type = sdk.find_type_definition("via.SceneManager")
local via_scene_view_type = sdk.find_type_definition("via.SceneView")
local via_window_type = sdk.find_type_definition("via.Window")
local via_camera_type = sdk.find_type_definition("via.Camera")
local via_hid_mouse_type = sdk.find_type_definition("via.hid.Mouse")
local via_gui_type = sdk.find_type_definition("via.gui.GUI")
local via_gui_view_type = sdk.find_type_definition("via.gui.View")
local hid_manager_type = sdk.find_type_definition("app.HIDManager")

-- Runtime state tracking
local current_screen_w = 1920
local current_screen_h = 1080
local current_aspect = 16.0 / 9.0
local is_16_10 = false
local is_ultrawide = false
local is_non_standard = false
local calculated_offset_y = 0.0
local calculated_scale_y = 1.0
local is_cursor_active = false

-- Mathematical FOV conversions
local function hor_to_ver_fov(fov, aspect)
    local rad_fov = math.rad(fov)
    return math.deg(2.0 * math.atan(math.tan(rad_fov / 2.0) / aspect))
end

local function ver_to_hor_fov(vfov, aspect)
    local rad_vfov = math.rad(vfov)
    return math.deg(2.0 * math.atan(math.tan(rad_vfov / 2.0) * aspect))
end

-- Update display metrics
local function update_screen_metrics()
    local main_view = sdk.get_main_view()
    if not main_view then return end

    local window = main_view:call("get_Window")
    if not window then return end

    local w = window:call("get_Width")
    local h = window:call("get_Height")

    if w and h and w > 0 and h > 0 then
        current_screen_w = w
        current_screen_h = h
        current_aspect = w / h
        
        -- Detect aspect ratio category
        is_16_10 = math.abs(current_aspect - (16.0 / 10.0)) < 0.03
        is_ultrawide = current_aspect > 1.85
        is_non_standard = math.abs(current_aspect - (16.0 / 9.0)) > 0.03

        if is_16_10 then
            -- In 16:10 (e.g. 1920x1200), standard 16:9 image would have height 1080.
            -- Height difference is 120px total, 60px top bar and 60px bottom bar.
            local standard_h = current_screen_w / (16.0 / 9.0)
            calculated_offset_y = (current_screen_h - standard_h) / 2.0
            calculated_scale_y = standard_h / current_screen_h
        elseif is_ultrawide then
            local standard_w = current_screen_h * (16.0 / 9.0)
            calculated_offset_y = 0.0
            calculated_scale_y = 1.0
        else
            calculated_offset_y = 0.0
            calculated_scale_y = 1.0
        end

        -- Synchronize borderless_size in Window struct (Offset 0xB0)
        -- This resolves RE Engine's internal coordinate clamping
        pcall(function()
            window:write_float(0xB0, tonumber(current_screen_w))
            window:write_float(0xB4, tonumber(current_screen_h))
        end)
    end
end

-- Apply Viewport & Black Bar Removal
local function apply_aspect_ratio_fix()
    if not config.enabled or not config.remove_black_bars then
        return
    end

    local main_view = sdk.get_main_view()
    if not main_view then return end

    -- DisplayType:
    -- 0 = Fit
    -- 1 = Uniform4x3
    -- 2 = Uniform16x9
    -- 3 = Uniform16x10
    -- 4 = Uniform21x9
    -- 5 = Uniform32x9
    local target_display_type = 0 -- Fit
    if is_16_10 then
        target_display_type = 3 -- Uniform16x10
    elseif is_ultrawide then
        if current_aspect > 3.0 then
            target_display_type = 5 -- Uniform32x9
        else
            target_display_type = 4 -- Uniform21x9
        end
    end

    local set_display_type = via_scene_view_type:get_method("set_DisplayType")
    if set_display_type then
        set_display_type:call(main_view, target_display_type)
    end

    -- Camera FOV adaptation
    local camera = sdk.get_primary_camera()
    if camera and config.horizontal_fov_adjust and is_non_standard then
        local get_fov = via_camera_type:get_method("get_FOV")
        local set_fov = via_camera_type:get_method("set_FOV")
        local set_vert_enable = via_camera_type:get_method("set_VerticalEnable")

        if set_vert_enable then
            -- Enabling vertical FOV lock maintains vertical view height (Hor+ scaling)
            set_vert_enable:call(camera, true)
        end
    end
end

-- Cursor Synchronization Engine
local function sync_mouse_cursor()
    if not config.enabled or not config.fix_cursor_offset then
        return
    end

    local main_view = sdk.get_main_view()
    if not main_view then return end

    local window = main_view:call("get_Window")
    if not window then return end

    -- Read raw window cursor position (offsets 0x78 and 0x7C in via.Window)
    local raw_x = window:read_float(0x78)
    local raw_y = window:read_float(0x7C)
    local show_cursor = window:read_byte(0x80) == 1

    is_cursor_active = show_cursor

    if show_cursor and raw_x and raw_y then
        -- If running on 16:10 without HUD letterbox:
        -- The internal game code applies an offset/scale matching the old letterbox.
        -- We re-align the cursor to ensure 1:1 precision with Windows cursor clicks.
        if is_16_10 then
            local adjusted_x = raw_x + config.cursor_x_offset
            -- Compensate for the letterbox subtraction if the game subtracted it:
            local adjusted_y = raw_y
            
            if not config.constrain_hud_16_9 then
                -- When HUD is full 16:10, calibrate vertical coordinate
                adjusted_y = (raw_y * config.cursor_scale_y) + config.cursor_y_offset
            else
                -- When HUD is 16:9 centered, offset by bar margin
                adjusted_y = raw_y - calculated_offset_y + config.cursor_y_offset
            end

            -- Ensure coordinates remain within legal screen bounds
            if adjusted_x < 0 then adjusted_x = 0 end
            if adjusted_x > current_screen_w then adjusted_x = current_screen_w end
            if adjusted_y < 0 then adjusted_y = 0 end
            if adjusted_y > current_screen_h then adjusted_y = current_screen_h end

            -- Write adjusted position back to engine window struct
            window:write_float(0x78, adjusted_x)
            window:write_float(0x7C, adjusted_y)
        end
    end
end

-- Remove black letterbox/pillarbox GUI objects
re.on_pre_gui_draw_element(function(gui_element)
    if not config.enabled or not config.remove_black_bars then
        return true
    end

    local game_object = gui_element:call("get_GameObject")
    if not game_object then return true end

    local name = game_object:call("get_Name")
    if name then
        -- Identify letterbox and black bar masks
        if name == "GUI_PillarBox" or name == "GUIEventPillar" or 
           name == "AcLetterBox" or name == "LetterBox" or 
           name == "LetterBoxBehavior" or name == "BlackFadeLetterBox" then
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

-- Main execution hooks
re.on_pre_application_entry("UpdateBehavior", function()
    update_screen_metrics()
    apply_aspect_ratio_fix()
    sync_mouse_cursor()
end)

re.on_application_entry("LockScene", function()
    apply_aspect_ratio_fix()
end)

-- In-game ImGui Menu
re.on_draw_ui(function()
    if ImGui.tree_node("RE8 Aspect Ratio & Cursor Patch (" .. SCRIPT_VERSION .. ")") then
        local changed = false

        changed, config.enabled = ImGui.checkbox("Enable Aspect Ratio & Cursor Fix", config.enabled)
        
        if config.enabled then
            ImGui.spacing()
            ImGui.text_colored(string.format("Detected Resolution: %dx%d (Ratio: %.2f:1)", current_screen_w, current_screen_h, current_aspect), 0.2, 0.8, 1.0, 1.0)
            
            if is_16_10 then
                ImGui.text_colored("Aspect Ratio Profile: 16:10 (Letterbox Removed)", 0.2, 1.0, 0.4, 1.0)
            elseif is_ultrawide then
                ImGui.text_colored("Aspect Ratio Profile: Ultrawide (Pillarbox Removed)", 0.2, 1.0, 0.4, 1.0)
            else
                ImGui.text_colored("Aspect Ratio Profile: Standard 16:9", 0.8, 0.8, 0.8, 1.0)
            end

            ImGui.separator()
            ImGui.spacing()

            local c1 = false
            c1, config.remove_black_bars = ImGui.checkbox("Remove Black Bars (Full Screen Viewport)", config.remove_black_bars)
            changed = changed or c1

            local c2 = false
            c2, config.fix_cursor_offset = ImGui.checkbox("Fix Ghost Cursor & Mouse Offset", config.fix_cursor_offset)
            changed = changed or c2

            local c3 = false
            c3, config.horizontal_fov_adjust = ImGui.checkbox("Adaptive Camera FOV (Preserve Vertical FOV)", config.horizontal_fov_adjust)
            changed = changed or c3

            local c4 = false
            c4, config.constrain_hud_16_9 = ImGui.checkbox("Center HUD Elements (16:9 Safe Frame)", config.constrain_hud_16_9)
            changed = changed or c4

            ImGui.spacing()
            if ImGui.tree_node("Advanced Cursor Fine-Tuning") then
                local cx = false
                cx, config.cursor_x_offset = ImGui.slider_float("Cursor X Offset (px)", config.cursor_x_offset, -100.0, 100.0)
                changed = changed or cx

                local cy = false
                cy, config.cursor_y_offset = ImGui.slider_float("Cursor Y Offset (px)", config.cursor_y_offset, -100.0, 100.0)
                changed = changed or cy

                local csx = false
                csx, config.cursor_scale_x = ImGui.slider_float("Cursor Scale X", config.cursor_scale_x, 0.5, 1.5)
                changed = changed or csx

                local csy = false
                csy, config.cursor_scale_y = ImGui.slider_float("Cursor Scale Y", config.cursor_scale_y, 0.5, 1.5)
                changed = changed or csy

                if ImGui.button("Reset Cursor Calibration") then
                    config.cursor_x_offset = 0.0
                    config.cursor_y_offset = 0.0
                    config.cursor_scale_x = 1.0
                    config.cursor_scale_y = 1.0
                    changed = true
                end

                ImGui.tree_pop()
            end

            ImGui.spacing()
            if ImGui.button("Save Settings") or changed then
                save_config()
            end
        end

        ImGui.tree_pop()
    end
end)

log.info("[" .. SCRIPT_NAME .. "] Loaded successfully.")
