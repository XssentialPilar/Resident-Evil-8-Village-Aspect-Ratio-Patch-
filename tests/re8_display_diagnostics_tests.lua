local ui_callback, save_callback
local read_paths, writes = {}, {}
local draw_count, text_count = 0, 0
re = {
    on_draw_ui = function(callback) ui_callback = callback end,
    on_config_save = function(callback) save_callback = callback end,
}
-- There is deliberately no sdk, HID, draw hook, frame callback or raw-memory API.
json = {
    load_file = function(path)
        read_paths[#read_paths + 1] = path
        if path == "re8_display.json" then return nil end
        if path == "re8_aspect_ratio_fix.json" then return {show_diagnostics = true, enabled = false} end
        error("Unexpected path")
    end,
    dump_file = function(path, value)
        writes[#writes + 1] = {path = path, show = value.show_diagnostics}
    end,
}
log = {info = function() end, warn = function() end}
imgui = {
    tree_node = function() return true end,
    checkbox = function(_, value) assert(value == true); return false, value end,
    get_display_size = function() return {x = 3440, y = 1440} end,
    text = function(value) assert(type(value) == "string"); text_count = text_count + 1 end,
    tree_pop = function() draw_count = draw_count + 1 end,
}
assert(loadfile(display_script_path))()
assert(type(ui_callback) == "function" and type(save_callback) == "function")
assert(#read_paths == 2 and read_paths[1] == "re8_display.json")
ui_callback()
assert(draw_count == 1 and text_count >= 3)
save_callback()
assert(#writes == 1 and writes[1].path == "re8_display.json" and writes[1].show == true)
-- Minimized/zero output must remain safe and must not create geometry writes.
imgui.get_display_size = function() return {x = 0, y = 0} end
ui_callback()
assert(draw_count == 2)
-- A persisted non-boolean cannot enable diagnostics.
json.load_file = function() return {show_diagnostics = "true"} end
imgui.checkbox = function(_, value) assert(value == false); return false, value end
assert(loadfile(display_script_path))()
ui_callback()
print("PASS: Lua 5.4 load, migrated boolean configuration, panel rendering and zero-size output; no engine API required.")
