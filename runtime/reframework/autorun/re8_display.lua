-- Resident Evil Village display diagnostics (development / runtime validation pending).
-- Projection, viewport and cursor ownership live in the native RE8 controllers.
-- Never replace the engine's mouse coordinate transforms or write raw structures.
local CONFIG_FILE = "re8_display.json"
local LEGACY_CONFIG_FILE = "re8_aspect_ratio_fix.json"
local config = { show_diagnostics = false }
local ui = imgui or ImGui

local function read_config(path)
    local ok, value = pcall(json.load_file, path)
    if ok and type(value) == "table" then return value end
    return nil
end

local loaded = read_config(CONFIG_FILE) or read_config(LEGACY_CONFIG_FILE)
if loaded and type(loaded.show_diagnostics) == "boolean" then
    config.show_diagnostics = loaded.show_diagnostics
end

local function save_config()
    local ok = pcall(json.dump_file, CONFIG_FILE, config)
    if not ok then log.warn("[RE8 Display] Could not save display diagnostics configuration.") end
end

-- No frame/HID/GUI-update callbacks: the native display controller handles the
-- render buffer, camera and menu transitions. Inspect only while this panel is open.
re.on_draw_ui(function()
    if not ui or not ui.tree_node("RE8 Display Diagnostics") then return end
    local changed
    changed, config.show_diagnostics = ui.checkbox("Show display diagnostics", config.show_diagnostics)
    if changed then save_config() end
    if config.show_diagnostics then
        local size = ui.get_display_size()
        if size and size.x > 0 and size.y > 0 then
            local aspect = size.x / size.y
            local safe_width = math.min(size.x, size.y * 16 / 9)
            local safe_height = math.min(size.y, size.x * 9 / 16)
            ui.text(string.format("ImGui output: %.0fx%.0f (%.4f:1)", size.x, size.y, aspect))
            ui.text(string.format("Reference UI safe area: %.0fx%.0f; margins %.1f, %.1f",
                safe_width, safe_height, (size.x - safe_width) / 2, (size.y - safe_height) / 2))
        end
        ui.text("Projection and proportional UI options: Graphics / Ultrawide/FOV Options.")
        ui.text("Manual override preserves your calibration; turn it off for automatic projection.")
        ui.text("Map input and coordinate conversion remain under RE Engine control.")
        ui.text("Per-menu alignment, map movement and resize behavior require in-game validation.")
    end
    ui.tree_pop()
end)

re.on_config_save(save_config)
log.info("[RE8 Display] Diagnostics loaded. Native controllers own projection and cursor state.")
