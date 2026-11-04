-- Read-only, one-shot metadata inspection. No hooks, writes to game objects,
-- process controls, or input injection. Delete this script after inspection.
local done = false
re.on_frame(function()
    if done then return end
    if not sdk.find_type_definition("app.GUIMouseCursor") then return end
    done = true
    local result = {}
    for _, name in ipairs({"app.GUIMouseCursor", "via.gui.TransformObject",
        "via.gui.View", "via.gui.GUI", "via.hid.Mouse", "via.hid.MouseDevice",
        "app.GUIManager", "app.GUIInputManager", "via.Point", "via.Size",
        "via.gui.PlayObject", "via.gui.Panel"}) do
        local t = sdk.find_type_definition(name)
        local entry = { methods = {}, fields = {} }
        if t then
            for _, m in ipairs(t:get_methods()) do
                local row = {name = m:get_name()}
                row.parameters = {}
                pcall(function()
                    for _, p in ipairs(m:get_param_types()) do table.insert(row.parameters, p:get_full_name()) end
                    row.static = m:is_static()
                    row.function_address = tostring(m:get_function())
                end)
                pcall(function() row.returns = m:get_return_type():get_full_name() end)
                table.insert(entry.methods, row)
            end
            for _, f in ipairs(t:get_fields()) do
                local row = {name = f:get_name()}
                pcall(function() row.type = f:get_type():get_full_name() end)
                pcall(function() row.offset = f:get_offset_from_base() end)
                table.insert(entry.fields, row)
            end
        end
        result[name] = entry
    end
    json.dump_file("RE8Display-cursor-metadata.json", result)
    log.info("[RE8Display.CursorInspect] Read-only metadata saved")
end)

local samples, next_sample, types = {}, 0, {}
local function scalar(v, name)
    local ok, value = pcall(function() return v:get_field(name) end)
    if ok and type(value) == "number" then return value end
    ok, value = pcall(function() return v[name] end)
    if ok and type(value) == "number" then return value end
end
local function pair(v)
    if v == nil then return nil end
    return {x=scalar(v,"x"),y=scalar(v,"y"),w=scalar(v,"w"),h=scalar(v,"h"),
        width=scalar(v,"width"),height=scalar(v,"height")}
end
re.on_pre_gui_draw_element(function(element)
    if #samples >= 80 or os.clock() < next_sample then return true end
    local ok = pcall(function()
        local name = element:get_type_definition():get_full_name()
        if not types[name] then types[name] = true; log.info("[RE8Display.CursorInspect] draw type="..name) end
        local cursor = name == "app.GUIMouseCursor" and element or nil
        if not cursor then
            local success, found = pcall(function() return element:call("getComponent(System.Type)", sdk.typeof("app.GUIMouseCursor")) end)
            if success then cursor = found end
        end
        if not cursor then
            local success, found = pcall(function() return element:call("get_GameObject"):call("getComponent(System.Type)", sdk.typeof("app.GUIMouseCursor")) end)
            if success then cursor = found end
        end
        if not cursor then return end
        next_sample = os.clock() + 0.5
        local sample = {time=os.clock()}
        for _, method in ipairs({"get_currentCursorPosition", "getCurrentScreenPoint", "getMainViewSize"}) do
            local success, value = pcall(function() return cursor:call(method) end)
            sample[method] = success and pair(value) or tostring(value)
        end
        for _, method in ipairs({"get_mainPanel","get_layoutPanel","get_modePanel","get_cursorPanel"}) do
            local success, panel = pcall(function() return cursor:call(method) end)
            if success and panel then
                local row = {}
                for _, getter in ipairs({"get_Position","get_GlobalPosition","get_Scale"}) do
                    local got, value = pcall(function() return panel:call(getter) end)
                    row[getter] = got and pair(value) or tostring(value)
                end
                sample[method] = row
            end
        end
        table.insert(samples,sample)
        json.dump_file("RE8Display-cursor-samples.json",samples)
    end)
    return true
end)
