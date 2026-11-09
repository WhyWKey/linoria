local BUILD = "phantom-1109-d"
local SOURCE_URL = ""

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local UI_REPO = "https://raw.githubusercontent.com/WhyWKey/linoria/main/"

local function noop() end

local __ok, __err = xpcall(function()

-- The game runs inside an actor, so its modules do not exist in the normal Lua state. Relaunch this script there.
do
    local function inGameVm()
        local ok, request = pcall(function() return getrenv().shared.require end)
        return ok and type(request) == "function"
    end
    local inActor = getgenv().PF_INACTOR
    getgenv().PF_INACTOR = nil
    if not inActor and not inGameVm() then
        local source = getgenv().PF_SOURCE
        if (type(source) ~= "string" or #source < 2000) and SOURCE_URL ~= "" then
            local okGet, body = pcall(game.HttpGet, game, SOURCE_URL)
            if okGet and type(body) == "string" then source = body end
        end
        local run, list
        if type(getactorthreads) == "function" and type(run_on_thread) == "function" then
            run, list = run_on_thread, getactorthreads
        elseif type(getactors) == "function" and type(run_on_actor) == "function" then
            run, list = run_on_actor, getactors
        elseif type(getdeletedactors) == "function" and type(run_on_actor) == "function" then
            run, list = run_on_actor, getdeletedactors
        end
        if type(source) ~= "string" or #source < 2000 then
            warn("[Aster] Not inside the game's actor and no source to relaunch with. Start it with the loader (sets getgenv().PF_SOURCE) or fill in SOURCE_URL at the top of the file")
        elseif not run or type(create_comm_channel) ~= "function" or type(get_comm_channel) ~= "function" then
            warn("[Aster] This executor cannot run code inside actors (" .. tostring(identifyexecutor and identifyexecutor() or "unknown") .. ")")
        else
            local probe = [=[
                local Channel = get_comm_channel(...)
                local ok, request = pcall(function() return getrenv().shared.require end)
                if ok and type(request) == "function" then Channel:Fire() end
            ]=]
            local okList, actors = pcall(list)
            local found = false
            if okList and type(actors) == "table" then
                for _, actor in ipairs(actors) do
                    if found then break end
                    local okChannel, index, channel = pcall(create_comm_channel)
                    if okChannel and channel then
                        local function onReply()
                            if found then return end
                            found = true
                            getgenv().PF_INACTOR = true
                            pcall(run, actor, "getgenv().PF_INACTOR = true\n" .. source)
                        end
                        if not pcall(function() channel.Event:Connect(onReply) end) then
                            pcall(function() channel:connect(onReply) end)
                        end
                        pcall(run, actor, probe, index)
                    end
                end
                local started = os.clock()
                while not found and os.clock() - started < 5 do task.wait(0.1) end
            end
            if found then
                print("[Aster] relaunched inside the game's actor")
                return
            end
            warn("[Aster] No actor with the game's modules was found (" .. tostring(okList and type(actors) == "table" and #actors or 0) .. " actors checked)")
        end
    end
end

if type(getgenv().PF_Connections) == "table" then
    for _, connection in ipairs(getgenv().PF_Connections) do pcall(function() connection:Disconnect() end) end
end
getgenv().PF_Connections = {}
if getgenv().Library and type(getgenv().Library.Unload) == "function" then
    pcall(function() getgenv().Library:Unload() end)
end
getgenv().TS_Connections = getgenv().PF_Connections
getgenv().TS_Drawings = {}

local function track(connection)
    table.insert(getgenv().PF_Connections, connection)
    return connection
end

local function patchLibrarySource(source)
    local function swap(find, replace)
        local first, last = string.find(source, find, 1, true)
        if first then source = string.sub(source, 1, first - 1) .. replace .. string.sub(source, last + 1) end
    end

    swap("            local Event;\n            Event = InputService.InputBegan:Connect(function(Input)",
[[            local Event;
            task.spawn(function()
                while not Break do
                    for _, SideKey in ipairs({ 'MB4', 'MB5' }) do
                        if (not Break) and Library.ButtonDown and Library.ButtonDown(SideKey) then
                            Break = true;
                            Picking = false;
                            DisplayLabel.Text = SideKey;
                            KeyPicker.Value = SideKey;
                            Library:SafeCallback(KeyPicker.ChangedCallback, Enum.KeyCode.Unknown);
                            Library:SafeCallback(KeyPicker.Changed, Enum.KeyCode.Unknown);
                            Library:AttemptSave();
                            if Event then Event:Disconnect(); end;
                        end;
                    end;
                    task.wait();
                end;
            end);
            Event = InputService.InputBegan:Connect(function(Input)]])
    swap("                elseif Input.UserInputType == Enum.UserInputType.MouseButton2 then\n                    Key = 'MB2';",
         "                elseif Input.UserInputType == Enum.UserInputType.MouseButton2 then\n                    Key = 'MB2';\n                elseif Input.UserInputType == Enum.UserInputType.MouseButton3 then\n                    Key = 'MB3';")

    swap("                local Key = KeyPicker.Value;\n                if Key == 'MB1' or Key == 'MB2' or Key == 'Touch' then\n                    return Key == 'MB1' and",
         "                local Key = KeyPicker.Value;\n                if Key == 'MB3' or Key == 'MB4' or Key == 'MB5' then\n                    return (Library.ButtonDown and Library.ButtonDown(Key)) == true;\n                end;\n                if Key == 'MB1' or Key == 'MB2' or Key == 'Touch' then\n                    return Key == 'MB1' and")

    swap([==[        if KeyPicker.SyncToggleState then
            Info.Modes = { 'Toggle' }
            Info.Mode = 'Toggle'
        end]==],
         [==[        if KeyPicker.SyncToggleState then
            Info.Modes = { 'Toggle', 'Hold', 'Always' }
        end]==])

    swap([==[                KeyPicker.Mode = Mode;
]==],
         [==[                KeyPicker.Mode = Mode;
                if KeyPicker.SyncToggleState and Mode == 'Hold' and KeyPicker.Value ~= 'None' then
                    task.defer(function()
                        pcall(function() ParentObj:SetValue(KeyPicker:GetState() == true) end)
                    end)
                end
]==])

    swap([==[        KeyPicker:Update();
        Options[Idx] = KeyPicker;
]==],
         [==[        if KeyPicker.SyncToggleState then
            local HeldBefore = false
            Library:GiveSignal(RunService.Heartbeat:Connect(function()
                if KeyPicker.Mode ~= 'Hold' or KeyPicker.Value == 'None' or Picking or InputService:GetFocusedTextBox() then
                    HeldBefore = false
                    return
                end
                local Down = KeyPicker:GetState() == true
                if Down ~= HeldBefore then
                    HeldBefore = Down
                    ParentObj:SetValue(Down)
                end
            end))
        end

        KeyPicker:Update();
        Options[Idx] = KeyPicker;
]==])

    swap([==[                if Addon.Type == 'KeyPicker' and Addon.SyncToggleState then
                    Addon.Toggled = Bool
                    Addon:Update()
                end]==],
         [==[                if Addon.Type == 'KeyPicker' and Addon.SyncToggleState then
                    Addon.Toggled = Bool
                    Addon:Update()
                elseif Addon.Type == 'KeyPicker' then
                    Addon:Update()
                end]==])

    swap([==[            ContainerLabel.TextColor3 = State and Library.AccentColor or Library.FontColor;
            Library.RegistryMap[ContainerLabel].Properties.TextColor3 = State and 'AccentColor' or 'FontColor';]==],
         [==[            local ParentOn = true
            if ParentObj and ParentObj.Type == 'Toggle' then ParentOn = ParentObj.Value == true end
            local Lit = State == true and ParentOn
            if KeyPicker.Value == 'None' then KeybindEntry.Visible = false end

            ContainerLabel.TextColor3 = Lit and Library.AccentColor or Library.FontColor;
            Library.RegistryMap[ContainerLabel].Properties.TextColor3 = Lit and 'AccentColor' or 'FontColor';]==])

    swap("        Slider:Display();\n        Groupbox:AddBlank(Info.BlankSize or 6);",
[==[        local function FitSlider()
            local Span = SliderOuter.AbsoluteSize.X - 2;
            if Span > 20 and Span ~= Slider.MaxSize then
                Slider.MaxSize = Span;
                Slider:Display();
            end;
        end;
        SliderOuter:GetPropertyChangedSignal('AbsoluteSize'):Connect(FitSlider);
        task.defer(FitSlider);
        Slider:Display();
        Groupbox:AddBlank(Info.BlankSize or 6);]==])

    swap("        Toggle:Display();\n        Groupbox:AddBlank(Info.BlankSize or 5 + 2);",
[==[        local function FitToggle()
            local Width = Container.AbsoluteSize.X;
            if Width < 60 then return; end;
            ToggleLabel.Size = UDim2.new(0, math.max(Width - 30, 40), 1, 0);
            local Layout = ToggleLabel:FindFirstChildOfClass('UIListLayout');
            local Used = Layout and Layout.AbsoluteContentSize.X or 0;
            ToggleRegion.Size = UDim2.new(0, math.max(Width - 32 - Used, 40), 1, 0);
        end;
        Container:GetPropertyChangedSignal('AbsoluteSize'):Connect(FitToggle);
        do
            local Layout = ToggleLabel:FindFirstChildOfClass('UIListLayout');
            if Layout then Layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(FitToggle); end;
        end;
        task.defer(FitToggle);
        Toggle:Display();
        Groupbox:AddBlank(Info.BlankSize or 5 + 2);]==])

    swap("                if KeyPicker.Mode == 'Toggle' then\n                    local Key = KeyPicker.Value;\n",
         "                if KeyPicker.Mode == 'Toggle' and (not InputService:GetFocusedTextBox()) then\n                    local Key = KeyPicker.Value;\n")
    swap("                local Key = KeyPicker.Value;\n                if Key == 'MB3' or Key == 'MB4' or Key == 'MB5' then\n",
         "                if InputService:GetFocusedTextBox() then return false; end;\n                local Key = KeyPicker.Value;\n                if Key == 'MB3' or Key == 'MB4' or Key == 'MB5' then\n")
    swap("Cursor.ZIndex = 100;", "Cursor.ZIndex = 5000;")
    swap("CursorOutline.ZIndex = 99;", "CursorOutline.ZIndex = 4999;")
    return source
end


local Library = loadstring(patchLibrarySource(game:HttpGet(UI_REPO .. "Library.lua")))()
local Skin = loadstring(game:HttpGet(UI_REPO .. "ui-test/PerceptionSkin.lua?t=" .. os.time()))()(Library, { Brand = "Aster" })
for _, name in ipairs({ "CreatePanel", "BuildSettings", "CreateTargetInfo" }) do
    if type(Skin[name]) ~= "function" then
        error("PerceptionSkin.lua on GitHub is outdated (" .. tostring(Skin.Version) .. ", missing " .. name .. "). Upload the newest build-1028-b to ui-test/", 0)
    end
end
if tostring(Skin.Version) < "build-1103-a" then
    error("PerceptionSkin.lua on GitHub is outdated (" .. tostring(Skin.Version) .. "). Upload build-1103-a to ui-test/ (adds the third column when the menu is wide)", 0)
end
local ThemeManager = loadstring(game:HttpGet(UI_REPO .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(UI_REPO .. "addons/SaveManager.lua"))()

pcall(function()
    SaveManager.Parser.ColorPicker.Load = function(idx, data)
        local picker = getgenv().Options and getgenv().Options[idx]
        if picker then picker:SetValueRGB(Color3.fromHex(data.value), tonumber(data.transparency) or 0) end
    end
end)

getgenv().Library = Library

local Options = getgenv().Options
local Toggles = getgenv().Toggles

local cleanupTasks = {}
local function onUnload(fn)
    table.insert(cleanupTasks, fn)
end

Library:OnUnload(function()
    for _, fn in ipairs(cleanupTasks) do pcall(fn) end

    for _, connection in ipairs(getgenv().PF_Connections or {}) do
        pcall(function() connection:Disconnect() end)
    end
    getgenv().PF_Connections = {}

    for _, drawing in ipairs(getgenv().TS_Drawings or {}) do
        pcall(function() drawing:Remove() end)
    end
    getgenv().TS_Drawings = {}
end)

local function readFlag(name, default)
    local object = Toggles[name]
    if object == nil then object = Options[name] end
    if object == nil or object.Value == nil then return default end
    return object.Value
end


local LinoriaWindow = Library:CreateWindow({
    Title = "Aster  |  Phantom Forces  |  " .. BUILD,
    Center = true,
    AutoShow = false,
    MenuFadeTime = 0.2,

    UseBlur = false,
    UseDarken = false,
})

pcall(function() Library.ScreenGui.DisplayOrder = 100 end)

local function keyName(key)
    local ok, name = pcall(function() return key.Name end)
    if ok and type(name) == "string" then return name end
    return tostring(key or "None")
end

local function toRounding(decimals)
    if type(decimals) ~= "number" or decimals <= 0 or decimals >= 1 then return 0 end
    return math.clamp(math.floor(-math.log10(decimals) + 0.5), 0, 4)
end

local keybindRegistry = {}

local function escapeUnbinds(flag, fallback)
    local picker = Options[flag]
    if not picker then return end
    picker:OnChanged(function()
        if picker.Value == "Escape" then
            pcall(function() picker:SetValue({ fallback, picker.Mode }) end)
        end
    end)
end

local function wrapElement(linoriaObject)
    local element = {}
    function element:SetText(text)
        if linoriaObject.SetText then pcall(function() linoriaObject:SetText(text) end) end
    end
    function element:Colorpicker(info)
        if not linoriaObject.AddColorPicker then
            warn("Colorpicker skipped (element has no addon support):", info.Flag)
            return element
        end
        local pickerInfo = {
            Default = info.Default or Color3.fromRGB(255, 255, 255),
            Title = info.Name or "Color",
        }
        if info.Alpha then pickerInfo.Transparency = type(info.Alpha) == "number" and info.Alpha or 0 end
        linoriaObject:AddColorPicker(info.Flag, pickerInfo)
        return element
    end
    function element:Keybind(info)
        if not linoriaObject.AddKeyPicker then
            warn("Keybind skipped (element has no addon support):", info.Flag)
            return element
        end
        linoriaObject:AddKeyPicker(info.Flag, {
            Default = keyName(info.Default),
            Mode = info.Mode or "Toggle",
            Text = info.Name or "Keybind",
            NoUI = false,
            SyncToggleState = info.Sync == true,
        })
        escapeUnbinds(info.Flag, "None")
        table.insert(keybindRegistry, { flag = info.Flag, name = info.Name or info.Flag })
        return element
    end
    return element
end

local function wrapGroup(group, page, side)
    local wrapped = {}
    local function bump() page.load[side] = page.load[side] + 1 end

    function wrapped:Toggle(info)
        bump()
        return wrapElement(group:AddToggle(info.Flag, {
            Text = info.Name,
            Default = false,
            Tooltip = info.Tooltip,
            Callback = info.Callback,
        }))
    end

    function wrapped:Slider(info)
        bump()
        group:AddSlider(info.Flag, {
            Text = info.Name,
            Min = info.Min,
            Max = info.Max,
            Default = math.clamp(info.Default or info.Min, info.Min, info.Max),
            Rounding = toRounding(info.Decimals),
            Suffix = info.Suffix or "",
            Compact = false,
            HideMax = true,
            Tooltip = info.Tooltip,
            Callback = info.Callback,
        })
    end

    function wrapped:Dropdown(info)
        bump()
        group:AddDropdown(info.Flag, {
            Text = info.Name,
            Values = info.Items,
            Default = info.Default,
            Multi = info.Multi == true,
            AllowNull = info.Default == nil,
            Tooltip = info.Tooltip,
            Callback = info.Callback,
        })
    end

    function wrapped:Label(info)
        bump()

        return wrapElement(group:AddLabel(info.Name, #info.Name > 28))
    end

    function wrapped:Button(info)
        bump()
        group:AddButton(info.Name, info.Callback)
    end

    function wrapped:Input(info)
        bump()
        group:AddInput(info.Flag, {
            Text = info.Name,
            Default = info.Default or "",
            Placeholder = info.Placeholder or "",
            Finished = false,
            Callback = info.Callback,
        })
    end

    function wrapped:Listbox(info)
        bump()
        group:AddDropdown(info.Flag, { Text = "Player", SpecialType = "Player", AllowNull = true })
    end

    return wrapped
end

local GroupMeta
local function wrapPage(tab)
    local page = { load = { 0, 0 } }
    local function pickSide(side)
        if side == 1 or side == 2 then return side end
        return page.load[1] <= page.load[2] and 1 or 2
    end

    function page:Section(info)
        local side = pickSide(info.Side)
        local group = side == 1 and tab:AddLeftGroupbox(info.Name) or tab:AddRightGroupbox(info.Name)
        GroupMeta = GroupMeta or getmetatable(group)
        return wrapGroup(group, page, side)
    end

    function page:MultiSection(info)
        local side = pickSide(info.Side)
        local box = side == 1 and tab:AddLeftTabbox() or tab:AddRightTabbox()
        local sections = {}
        for index, name in ipairs(info.Sections) do
            sections[index] = wrapGroup(box:AddTab(name), page, side)
        end
        return table.unpack(sections)
    end

    function page:SubTabs(names)
        local raw = tab:SubTabs(names)
        local subs = {}
        for _, name in ipairs(names) do
            local target = raw[name]
            local sub = { load = { 0, 0 } }
            local function pick(side)
                if side == 1 or side == 2 then return side end
                return sub.load[1] <= sub.load[2] and 1 or 2
            end
            function sub:Section(info)
                local side = pick(info.Side)
                local group = side == 1 and target:AddLeftGroupbox(info.Name) or target:AddRightGroupbox(info.Name)
                GroupMeta = GroupMeta or getmetatable(group)
                return wrapGroup(group, sub, side)
            end
            function sub:Host()
                return target:AddHost()
            end
            function sub:MultiSection(info)
                local side = pick(info.Side)
                local box = side == 1 and target:AddLeftTabbox() or target:AddRightTabbox()
                local sections = {}
                for index, title in ipairs(info.Sections) do
                    sections[index] = wrapGroup(box:AddTab(title), sub, side)
                end
                return table.unpack(sections)
            end
            subs[name] = sub
        end
        return subs
    end

    return page
end

local Window = {}
function Window:Page(info)
    if info.Subtabs then
        local container = {}
        function container:SubPage(sub) return wrapPage(LinoriaWindow:AddTab(sub.Name)) end
        return container
    end
    return wrapPage(LinoriaWindow:AddTab(info.Name))
end



print("[Aster] build " .. BUILD .. " | skin " .. tostring(Skin.Version))

-- ============================================================ helpers
local warned = {}
local function note(key, ...)
    if warned[key] then return end
    warned[key] = true
    warn("[Aster]", ...)
end

local function safe(label, fn)
    return function(...)
        local ok, problem = pcall(fn, ...)
        if not ok then note(label .. tostring(problem), label .. ":", problem) end
    end
end

local function keyActive(name)
    local picker = Options[name]
    if picker and type(picker.GetState) == "function" then
        local ok, state = pcall(picker.GetState, picker)
        if ok then return state == true end
    end
    return true
end

local currentClass = nil
local PERFLAGS = { }
local function F(name, default)
    if currentClass and readFlag("ovr@" .. currentClass, false) then
        local value = readFlag(name .. "@" .. currentClass, nil)
        if value ~= nil then return value end
    end
    return readFlag(name, default)
end

local function weaponKeyActive(shared, own, perClass)
    if currentClass and readFlag(own .. "@" .. currentClass, false) then
        return keyActive(perClass .. "@" .. currentClass)
    end
    return keyActive(shared)
end

local function multi(name, fallback)
    local value = F(name, fallback)
    local out = {}
    if type(value) == "table" then
        for key, on in pairs(value) do
            if type(key) == "number" then out[on] = true elseif on then out[key] = true end
        end
    end
    return out
end

local function typing()
    return UserInputService:GetFocusedTextBox() ~= nil
end

-- ============================================================ core: game modules
local Core = { ready = false, mods = {}, via = {}, missing = {} }

local networkHooked
local function hookNetwork(network)
    if networkHooked or type(network) ~= "table" or type(network.send) ~= "function" then return end
    local original = network.send
    network.send = function(self, method, ...)
        if method == "debug" or method == "flaguser" then return nil end
        return original(self, method, ...)
    end
    networkHooked = true
    onUnload(function()
        pcall(function() network.send = original end)
        networkHooked = nil
    end)
end

local function loadCore()
    Core.ready, Core.mods, Core.via, Core.missing = false, {}, {}, {}
    local requireFn, loader
    pcall(function() requireFn = getrenv().shared.require end)
    local getUp = (debug and debug.getupvalues) or getupvalues
    if type(requireFn) == "function" and getUp then
        local function search(fn, depth)
            local ok, ups = pcall(getUp, fn)
            if not ok or type(ups) ~= "table" then return nil end
            for _, value in next, ups do
                if type(value) == "table" and rawget(value, "_cache") then return value end
            end
            if depth > 0 then
                for _, value in next, ups do
                    if type(value) == "function" then
                        local found = search(value, depth - 1)
                        if found then return found end
                    end
                end
            end
            return nil
        end
        loader = search(requireFn, 2)
    end

    local scripts = {}
    if type(getloadedmodules) == "function" then
        pcall(function()
            for _, module in ipairs(getloadedmodules()) do
                if not scripts[module.Name] then scripts[module.Name] = module end
            end
        end)
    end
    if type(getnilinstances) == "function" then
        pcall(function()
            for _, object in ipairs(getnilinstances()) do
                if typeof(object) == "Instance" and object:IsA("ModuleScript") and not scripts[object.Name] then
                    scripts[object.Name] = object
                end
            end
        end)
    end

    local function fetch(name)
        if type(requireFn) == "function" then
            local ok, module = pcall(requireFn, name)
            if ok and type(module) == "table" then return module, "shared.require" end
        end
        local entry = loader and loader._cache and loader._cache[name]
        if entry and type(entry.module) == "table" then return entry.module, "loader cache" end
        local script = scripts[name]
        if script then
            local ok, module = pcall(require, script)
            if ok and type(module) == "table" then return module, "module script" end
        end
        return nil
    end

    local needed = { "ReplicationInterface", "CharacterInterface", "CameraInterface" }
    for _, name in ipairs({ "ReplicationInterface", "CharacterInterface", "CameraInterface", "PublicSettings", "network" }) do
        Core.mods[name], Core.via[name] = fetch(name)
    end

    local gaps = false
    for _, name in ipairs(needed) do if not Core.mods[name] then gaps = true end end
    if gaps and type(getgc) == "function" then
        pcall(function()
            for _, value in ipairs(getgc(true)) do
                if type(value) == "table" then
                    if not Core.mods.ReplicationInterface and rawget(value, "operateOnAllEntries") and rawget(value, "getEntry") then
                        Core.mods.ReplicationInterface, Core.via.ReplicationInterface = value, "gc"
                    elseif not Core.mods.CharacterInterface and rawget(value, "getCharacterObject") and rawget(value, "isAlive") then
                        Core.mods.CharacterInterface, Core.via.CharacterInterface = value, "gc"
                    elseif not Core.mods.CameraInterface and rawget(value, "getActiveCamera") and rawget(value, "setCameraType") then
                        Core.mods.CameraInterface, Core.via.CameraInterface = value, "gc"
                    elseif not Core.mods.PublicSettings and rawget(value, "bulletAcceleration") then
                        Core.mods.PublicSettings, Core.via.PublicSettings = value, "gc"
                    end
                end
            end
        end)
    end

    for _, name in ipairs(needed) do
        if not Core.mods[name] then table.insert(Core.missing, name) end
    end
    Core.ready = #Core.missing == 0
    pcall(hookNetwork, Core.mods.network)
    Core.accel = Vector3.new(0, -196.2, 0)
    local settings = Core.mods.PublicSettings
    if settings and typeof(settings.bulletAcceleration) == "Vector3" then Core.accel = settings.bulletAcceleration end

    if Core.ready then
        local vias = {}
        for _, name in ipairs(needed) do vias[Core.via[name]] = true end
        local list = {}
        for via in pairs(vias) do table.insert(list, via) end
        table.sort(list)
        Core.summary = "loaded (" .. table.concat(list, ", ") .. ")"
    else
        Core.summary = "missing " .. table.concat(Core.missing, ", ")
        note("core", "Core modules not found:", table.concat(Core.missing, ", "), "| executor:", tostring(identifyexecutor and identifyexecutor() or "unknown"), "| getrenv().shared:", tostring(pcall(function() return getrenv().shared.require end)))
    end
end
loadCore()

-- ============================================================ core: local state
local frameId = 0

local function camera()
    return Workspace.CurrentCamera
end

local function gameCamera()
    local interface = Core.mods.CameraInterface
    if not interface then return nil end
    local ok, object = pcall(interface.getActiveCamera, "MainCamera", true)
    if ok and type(object) == "table" and object.setLookVector then return object end
    return nil
end

local function localAlive()
    local interface = Core.mods.CharacterInterface
    if not interface then return false end
    local ok, alive = pcall(interface.isAlive)
    return ok and alive == true
end

local function activeWeaponRaw()
    local interface = Core.mods.CharacterInterface
    if not (interface and localAlive()) then return nil end
    local ok, weapon = pcall(function()
        local character = interface.getCharacterObject()
        local controller = character and character:getWeaponController()
        return controller and controller:getActiveWeapon()
    end)
    if ok and type(weapon) == "table" then return weapon end
    return nil
end

local weaponFrame, weaponCache = -1, nil
local function activeWeapon()
    if weaponFrame == frameId then return weaponCache end
    weaponFrame = frameId
    weaponCache = activeWeaponRaw()
    return weaponCache
end

local function weaponStat(weapon, name)
    if type(weapon) ~= "table" or type(weapon.getWeaponStat) ~= "function" then return nil end
    local ok, value = pcall(weapon.getWeaponStat, weapon, name)
    if ok then return value end
    return nil
end

local TYPE_GROUP = { PISTOL = "Pistols", REVOLVER = "Pistols", ASSAULT = "Rifles", CARBINE = "Rifles", DMR = "DMR", SHOTGUN = "Shotguns", SNIPER = "Snipers", LMG = "LMGs" }
local classByName, classMapBuilt, classCache = {}, false, {}

local function groupOfFolder(name)
    local upper = tostring(name):upper():gsub("[%s_]+", "_")
    if upper:find("SNIPER", 1, true) then return "Snipers" end
    if upper:find("PISTOL", 1, true) or upper:find("REVOLVER", 1, true) then return "Pistols" end
    if upper:find("ASSAULT", 1, true) or upper:find("CARBINE", 1, true) or upper:find("BATTLE", 1, true) then return "Rifles" end
    if upper:find("PDW", 1, true) or upper:find("SMG", 1, true) then return "SMGs" end
    if upper:find("LMG", 1, true) then return "LMGs" end
    if upper:find("SHOTGUN", 1, true) then return "Shotguns" end
    if upper:find("DMR", 1, true) then return "DMR" end
    return "Other"
end

local function buildClassMap()
    classMapBuilt = true
    pcall(function()
        local root = game:GetService("ReplicatedStorage"):FindFirstChild("WeaponDatabase", true)
        if not root then return end
        for _, folder in ipairs(root:GetChildren()) do
            local group = groupOfFolder(folder.Name)
            for _, module in ipairs(folder:GetDescendants()) do
                if module:IsA("ModuleScript") and not classByName[module.Name] then classByName[module.Name] = group end
            end
        end
    end)
end

local function weaponClass(weapon)
    if type(weapon) ~= "table" then return nil end
    local name = weapon.weaponName
    if type(name) ~= "string" then return nil end
    if classCache[name] then return classCache[name] end
    if not classMapBuilt then buildClassMap() end
    local group = classByName[name]
    if not group then group = TYPE_GROUP[tostring(weaponStat(weapon, "type"))] or "Other" end
    classCache[name] = group
    return group
end

local function weaponAiming(weapon)
    if type(weapon) ~= "table" or type(weapon.isAiming) ~= "function" then return false end
    local ok, state = pcall(weapon.isAiming, weapon)
    return ok and state == true
end

local function weaponCanFire(weapon)
    if type(weapon) ~= "table" or type(weapon.canFire) ~= "function" then return true end
    local ok, state = pcall(weapon.canFire, weapon)
    return ok and state and true or false
end

-- ============================================================ core: players
local PART_NAMES = { "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }
local snapshot, snapshotFrame = {}, -1

local function entryVelocity(entry)
    local spring = entry._velspring
    local value = spring and spring.p
    if typeof(value) == "Vector3" then return value end
    return Vector3.zero
end

local function takeSnapshot()
    if snapshotFrame == frameId then return snapshot end
    snapshotFrame = frameId
    snapshot = {}
    local interface = Core.mods.ReplicationInterface
    if not interface then return snapshot end
    pcall(interface.operateOnAllEntries, function(player, entry)
        if player == LocalPlayer or type(entry) ~= "table" then return end
        local okAlive, alive = pcall(entry.isAlive, entry)
        if not (okAlive and alive) then return end
        local object = entry._thirdPersonObject
        if not object then return end
        local okHash, hash = pcall(object.getCharacterHash, object)
        if not (okHash and type(hash) == "table") then return end
        local torso, head = hash.Torso, hash.Head
        if not (torso and head and torso.Parent and head.Parent) then return end
        if not torso:IsDescendantOf(Workspace) then return end
        local torsoPosition, headPosition = torso.Position, head.Position
        if torsoPosition ~= torsoPosition or headPosition ~= headPosition then return end
        if (headPosition - torsoPosition).Magnitude > 8 then return end
        local okEnemy, enemy = pcall(entry.isEnemy, entry)
        local health, maxHealth = 100, 100
        local okHealth, currentHealth, currentMax = pcall(entry.getHealth, entry)
        if okHealth and type(currentHealth) == "number" then health, maxHealth = currentHealth, currentMax or 100 end
        local weaponName
        pcall(function()
            local registry = entry:getWeaponObject()
            weaponName = registry and registry.weaponName
        end)
        local okModel, model = pcall(object.getCharacterModel, object)
        snapshot[#snapshot + 1] = {
            player = player,
            entry = entry,
            hash = hash,
            model = (typeof(object._characterModel) == "Instance" and object._characterModel) or ((okModel and typeof(model) == "Instance") and model) or torso.Parent,
            torso = torso,
            head = head,
            enemy = not (okEnemy and enemy == false),
            health = health,
            maxHealth = maxHealth,
            velocity = entryVelocity(entry),
            weaponName = weaponName,
            name = player.Name,
        }
    end)
    return snapshot
end

-- ============================================================ core: visibility
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
pcall(function() rayParams.RespectCanCollide = true end)
local nextFilter = 0
local function refreshFilter(now)
    if now < nextFilter then return end
    nextFilter = now + 1
    local list = {}
    local current = camera()
    if current then list[#list + 1] = current end
    for _, name in ipairs({ "Ignore", "Players", "Roots" }) do
        local folder = Workspace:FindFirstChild(name)
        if folder then list[#list + 1] = folder end
    end
    rayParams.FilterDescendantsInstances = list
end

local visibleCache = setmetatable({}, { __mode = "k" })
local function isVisible(part, origin, now)
    local cached = visibleCache[part]
    if cached and now - cached[1] < 0.06 then return cached[2] end
    local direction = part.Position - origin
    local hit = Workspace:Raycast(origin, direction * 0.998, rayParams)
    local result = hit == nil
    visibleCache[part] = { now, result }
    return result
end

-- ============================================================ drawing helpers
local drawings = {}
local function newDrawing(kind, props)
    if type(Drawing) ~= "table" and type(Drawing) ~= "userdata" then return nil end
    local ok, object = pcall(Drawing.new, kind)
    if not ok or not object then return nil end
    for key, value in pairs(props or {}) do pcall(function() object[key] = value end) end
    drawings[object] = true
    return object
end
local function removeDrawing(object)
    if not object then return end
    drawings[object] = nil
    pcall(function() object:Remove() end)
end
local function setVisible(object, state)
    if object then object.Visible = state end
end
onUnload(function()
    for object in pairs(drawings) do pcall(function() object:Remove() end) end
    drawings = {}
end)

local BLACK = Color3.new(0, 0, 0)
local WHITE = Color3.new(1, 1, 1)

-- ============================================================ menu
local PF_StatusCore, PF_StatusWeapon, PF_StatusTarget, PF_StatusRecoil, PF_StatusClass
local LegitPage = Window:Page({ Name = "Legit", Columns = 2, Subtabs = false })
local LegitSubs = LegitPage:SubTabs({ "Shared", "Pistols", "Rifles", "SMGs", "LMGs", "Shotguns", "Snipers", "DMR", "Other", "Status" })
local VisualsPage = Window:Page({ Name = "Visuals", Columns = 2, Subtabs = false })
local MiscPage = Window:Page({ Name = "Misc", Columns = 2, Subtabs = false })
local MiscSubs = MiscPage:SubTabs({ "Camera", "Utility" })

do
    local CLASS_TABS = { "Pistols", "Rifles", "SMGs", "LMGs", "Shotguns", "Snipers", "DMR", "Other" }
    local ALL_TABS = { "Shared", "Pistols", "Rifles", "SMGs", "LMGs", "Shotguns", "Snipers", "DMR", "Other" }

    local function suffixOf(tabName)
        return tabName == "Shared" and "" or ("@" .. tabName)
    end

    local function setFlag(flag, value)
        local toggle = Toggles[flag]
        if toggle then toggle:SetValue(value) return true end
        local option = Options[flag]
        if option then option:SetValue(value) return true end
        return false
    end

    local function copyTab(from, to)
        for _, flag in ipairs(PERFLAGS) do
            local value = readFlag(flag .. suffixOf(from), nil)
            if value ~= nil then
                if type(value) == "table" then value = table.clone(value) end
                pcall(setFlag, flag .. suffixOf(to), value)
            end
        end
    end

    local function addSettings(sub, tabName)
        local suffix = suffixOf(tabName)
        local shared = tabName == "Shared"
        local function key(flag)
            if shared then table.insert(PERFLAGS, flag) end
            return flag .. suffix
        end

        if shared then
            local Master = sub:Section({ Name = "Master", Side = 1 })
            Master:Toggle({ Name = "Aimbot", Flag = "aim_enabled", Default = false, Tooltip = "Turns your view toward the target through the game's own camera while the key is held" }):Keybind({ Name = "Aim key", Flag = "aim_key", Default = "MB2", Mode = "Hold" })
            Master:Toggle({ Name = "Triggerbot", Flag = "trig_enabled", Default = false, Tooltip = "Fires when your crosshair is on an enemy" }):Keybind({ Name = "Trigger key", Flag = "trig_key", Default = "None", Mode = "Always" })
            Master:Toggle({ Name = "Recoil control", Flag = "rcs_enabled", Default = false, Tooltip = "Cancels the camera kick of each shot by reading the weapon's own recoil springs" }):Keybind({ Name = "Recoil key", Flag = "rcs_key", Default = "None", Mode = "Always" })
            Master:Toggle({ Name = "Show FOV circle", Flag = "fov_show", Default = true }):Colorpicker({ Name = "Circle color", Flag = "fov_color", Default = Color3.fromRGB(255, 255, 255) })
        else
            local Config = sub:Section({ Name = tabName .. " config", Side = 1 })
            Config:Toggle({ Name = "Override shared settings", Flag = "ovr@" .. tabName, Default = false, Tooltip = "While you hold a " .. tabName:lower() .. " weapon, this tab replaces the Shared tab. Off: Shared is used" })
            local others = {}
            for _, name in ipairs(ALL_TABS) do if name ~= tabName then table.insert(others, name) end end
            Config:Dropdown({ Name = "Copy from", Flag = "copy@" .. tabName, Items = others, Default = "Shared" })
            Config:Button({ Name = "Paste here", Callback = function()
                local from = readFlag("copy@" .. tabName, "Shared")
                copyTab(from, tabName)
                pcall(function() Library:Notify("Copied " .. from .. " into " .. tabName, 3) end)
            end })
            Config:Button({ Name = "Reset to shared", Callback = function()
                copyTab("Shared", tabName)
                pcall(function() Library:Notify(tabName .. " reset to Shared", 3) end)
            end })
            Config:Toggle({ Name = "Own aim key", Flag = "ownaim@" .. tabName, Default = false, Tooltip = "Use a separate aim key while you hold a " .. tabName:lower() .. " weapon" }):Keybind({ Name = tabName .. " aim key", Flag = "aim_key@" .. tabName, Default = "MB2", Mode = "Hold" })
            Config:Toggle({ Name = "Own trigger key", Flag = "owntrig@" .. tabName, Default = false, Tooltip = "Use a separate triggerbot key while you hold a " .. tabName:lower() .. " weapon" }):Keybind({ Name = tabName .. " trigger key", Flag = "trig_key@" .. tabName, Default = "None", Mode = "Always" })
        end

        local Aim_, Target_, Lead_ = sub:MultiSection({ Sections = { "Aim", "Target", "Precision" }, Side = 1 })
        Aim_:Toggle({ Name = "Visible only", Flag = key("aim_visible"), Default = true, Tooltip = "Ignores players behind walls" })
        Aim_:Toggle({ Name = "Only while aiming down sights", Flag = key("aim_ads"), Default = false })
        Aim_:Toggle({ Name = "Only while shooting", Flag = key("aim_shoot"), Default = false })
        Aim_:Slider({ Name = "Smoothing", Flag = key("aim_smooth"), Min = 1, Max = 60, Default = 12, Decimals = 1, Tooltip = "Higher is slower and looks more natural" })
        Aim_:Slider({ Name = "Max turn speed", Flag = key("aim_speed"), Min = 30, Max = 1440, Default = 420, Decimals = 1, Suffix = " °/s", Tooltip = "Caps how fast the view can turn, so it never snaps" })
        Aim_:Slider({ Name = "Max distance", Flag = key("aim_dist"), Min = 50, Max = 1500, Default = 600, Decimals = 1, Suffix = " studs" })
        Target_:Dropdown({ Name = "Priority", Flag = key("aim_priority"), Items = { "Crosshair", "Distance", "Lowest health" }, Default = "Crosshair" })
        Target_:Toggle({ Name = "Sticky lock", Flag = key("aim_sticky"), Default = true, Tooltip = "Once locked, the aimbot stays on that player even outside the FOV or range. It lets go when you release the aim key or the player dies" })
        Target_:Slider({ Name = "Switch delay", Flag = key("aim_switch"), Min = 0, Max = 500, Default = 120, Decimals = 1, Suffix = " ms", Tooltip = "Only used when Sticky lock is off" })
        Target_:Slider({ Name = "Reaction delay", Flag = key("aim_react"), Min = 0, Max = 400, Default = 60, Decimals = 1, Suffix = " ms", Tooltip = "Waits this long after picking a new target before moving" })
        Lead_:Toggle({ Name = "Bullet drop", Flag = key("lead_drop"), Default = true, Tooltip = "Aims higher by how far the bullet falls on its way, from the weapon's bullet speed and the game's bullet gravity" })
        Lead_:Toggle({ Name = "Moving targets", Flag = key("lead_move"), Default = true, Tooltip = "Aims ahead by the target's speed times the bullet's travel time" })
        Lead_:Slider({ Name = "Lead strength", Flag = key("lead_strength"), Min = 0, Max = 1.5, Default = 1, Decimals = 0.01 })
        Lead_:Slider({ Name = "Max lead", Flag = key("lead_max"), Min = 0, Max = 40, Default = 14, Decimals = 0.1, Suffix = " studs", Tooltip = "Caps how far ahead of a moving target it aims" })

        local sections = { "Parts", "FOV", "Humanize" }
        local Hits, Fov, Human = sub:MultiSection({ Sections = sections, Side = 2 })
        Hits:Dropdown({ Name = "Parts", Flag = key("aim_parts"), Items = { "Head", "Torso", "Arms", "Legs" }, Multi = true, Default = { "Head", "Torso" } })
        Hits:Dropdown({ Name = "Part choice", Flag = key("aim_choice"), Items = { "Closest to crosshair", "Priority order" }, Default = "Closest to crosshair", Tooltip = "Priority order tries Head, Torso, Arms, Legs and takes the first one that qualifies" })
        Fov:Slider({ Name = "Radius", Flag = key("fov_radius"), Min = 10, Max = 800, Default = 120, Decimals = 1, Suffix = " px" })
        Fov:Toggle({ Name = "Dynamic radius", Flag = key("fov_dynamic"), Default = false, Tooltip = "The radius depends on how far the target is" })
        Fov:Slider({ Name = "Radius when close", Flag = key("fov_near"), Min = 10, Max = 800, Default = 240, Decimals = 1, Suffix = " px" })
        Fov:Slider({ Name = "Radius at max distance", Flag = key("fov_far"), Min = 10, Max = 800, Default = 60, Decimals = 1, Suffix = " px" })
        Human:Slider({ Name = "Aim wobble", Flag = key("aim_noise"), Min = 0, Max = 3, Default = 0.25, Decimals = 0.01, Suffix = "°", Tooltip = "Small random drift on the aim point" })
        Human:Slider({ Name = "Wobble speed", Flag = key("aim_noise_speed"), Min = 0.2, Max = 6, Default = 1.4, Decimals = 0.1 })

        local lower = shared and { "Triggerbot", "Recoil", "Configs" } or { "Triggerbot", "Recoil" }
        local Trigger, Recoil_, Configs = sub:MultiSection({ Sections = lower, Side = 2 })
        Trigger:Toggle({ Name = "Visible only", Flag = key("trig_visible"), Default = true })
        Trigger:Toggle({ Name = "Only while aiming down sights", Flag = key("trig_ads"), Default = false })
        Trigger:Dropdown({ Name = "Parts", Flag = key("trig_parts"), Items = { "Head", "Torso", "Arms", "Legs" }, Multi = true, Default = { "Head", "Torso" } })
        Trigger:Slider({ Name = "Hitbox size", Flag = key("trig_scale"), Min = 0.4, Max = 1.6, Default = 0.9, Decimals = 0.01, Suffix = "x" })
        Trigger:Slider({ Name = "Max distance", Flag = key("trig_dist"), Min = 50, Max = 1500, Default = 400, Decimals = 1, Suffix = " studs" })
        Trigger:Slider({ Name = "Delay", Flag = key("trig_delay"), Min = 0, Max = 300, Default = 40, Decimals = 1, Suffix = " ms", Tooltip = "Time the crosshair must stay on the target before firing" })
        Trigger:Slider({ Name = "Hold", Flag = key("trig_hold"), Min = 20, Max = 500, Default = 70, Decimals = 1, Suffix = " ms", Tooltip = "How long the button stays down. Longer holds fire more shots on automatic guns" })
        Trigger:Slider({ Name = "Cooldown", Flag = key("trig_cool"), Min = 0, Max = 500, Default = 90, Decimals = 1, Suffix = " ms" })
        Recoil_:Slider({ Name = "Vertical control", Flag = key("rcs_v"), Min = 0, Max = 100, Default = 70, Decimals = 1, Suffix = "%", Tooltip = "How much of the upward kick is cancelled" })
        Recoil_:Slider({ Name = "Horizontal control", Flag = key("rcs_h"), Min = 0, Max = 100, Default = 40, Decimals = 1, Suffix = "%", Tooltip = "How much of the sideways kick is cancelled" })
        Recoil_:Toggle({ Name = "Hipfire too", Flag = key("rcs_hip"), Default = true, Tooltip = "Off: only controls recoil while aiming down sights" })
        Recoil_:Slider({ Name = "Variation", Flag = key("rcs_human"), Min = 0, Max = 40, Default = 10, Decimals = 1, Suffix = "%", Tooltip = "Varies the strength a little over time so the spray does not look machine perfect" })
        if shared then
            Configs:Button({ Name = "Copy Shared to all weapon tabs", Callback = function()
                for _, name in ipairs(CLASS_TABS) do copyTab("Shared", name) end
                pcall(function() Library:Notify("Shared copied into every weapon tab", 3) end)
            end })
            Configs:Button({ Name = "Turn off all overrides", Callback = function()
                for _, name in ipairs(CLASS_TABS) do pcall(setFlag, "ovr@" .. name, false) end
            end })
        end
    end

    for _, tabName in ipairs(ALL_TABS) do
        addSettings(LegitSubs[tabName], tabName)
    end

    local Status = LegitSubs.Status:Section({ Name = "Core", Side = 1 })
    PF_StatusRecoil = Status:Label({ Name = "Recoil: 0.0 / 0.0" })
    PF_StatusCore = Status:Label({ Name = "Core: " .. Core.summary })
    PF_StatusWeapon = Status:Label({ Name = "Weapon: none" })
    PF_StatusClass = Status:Label({ Name = "Class: none" })
    PF_StatusTarget = Status:Label({ Name = "Target: none" })
    Status:Button({ Name = "Reload core", Callback = function()
        loadCore()
        PF_StatusCore:SetText("Core: " .. Core.summary)
        pcall(function() Library:Notify("Core " .. Core.summary, 4) end)
    end })

    local FONT_ORDER = { "Tahoma", "Verdana", "Smallest Pixel", "Proggy", "Pixel Operator", "Minecraftia", "Inter", "Roboto Mono", "Lexend", "Gotham" }
    local PERTEAM = {}
    local function addTeamRows(box, friendly)
        local suffix = friendly and "@Friendly" or ""
        local function key(flag)
            if not friendly then table.insert(PERTEAM, flag) end
            return flag .. suffix
        end
        local white = Color3.fromRGB(255, 255, 255)
        box:Toggle({ Name = "Enabled", Flag = key("esp_enabled") })
        box:Toggle({ Name = "Name", Flag = key("esp_name") }):Colorpicker({ Name = "Name color", Flag = key("esp_name_color"), Default = white, Alpha = 0 })
        box:Toggle({ Name = "Box", Flag = key("esp_box_on") }):Colorpicker({ Name = "Box color", Flag = key("esp_color"), Default = white, Alpha = 0 })
        box:Toggle({ Name = "Box fill", Flag = key("esp_fill") }):Colorpicker({ Name = "Fill color", Flag = key("esp_fill_color"), Default = white, Alpha = 0.88 })
        box:Toggle({ Name = "Health bar", Flag = key("esp_health") }):Colorpicker({ Name = "Health color", Flag = key("esp_hp_full"), Default = white, Alpha = 0 })
        box:Toggle({ Name = "Health number", Flag = key("esp_hp_text") })
        box:Toggle({ Name = "Weapon name", Flag = key("esp_weapon") }):Colorpicker({ Name = "Weapon color", Flag = key("esp_weapon_color"), Default = white, Alpha = 0 })
        box:Toggle({ Name = "Weapon icon", Flag = key("esp_weapon_icon") }):Colorpicker({ Name = "Icon color", Flag = key("esp_weapon_icon_color"), Default = white, Alpha = 0 })
        box:Toggle({ Name = "Distance", Flag = key("esp_distance") }):Colorpicker({ Name = "Distance color", Flag = key("esp_dist_color"), Default = white, Alpha = 0 })
        box:Toggle({ Name = "Skeleton", Flag = key("esp_skeleton") }):Colorpicker({ Name = "Skeleton color", Flag = key("esp_skeleton_color"), Default = white, Alpha = 0 })
        box:Toggle({ Name = "Head dot", Flag = key("esp_head") }):Colorpicker({ Name = "Head dot color", Flag = key("esp_head_color"), Default = white, Alpha = 0 })
        box:Toggle({ Name = "Tracers", Flag = key("esp_tracer") }):Colorpicker({ Name = "Tracer color", Flag = key("esp_tracer_color"), Default = white, Alpha = 0 })
        box:Toggle({ Name = "Out of view", Flag = key("esp_arrows"), Tooltip = "Arrows at the screen edge that point toward players outside your view" }):Colorpicker({ Name = "Arrow color", Flag = key("esp_arrow_color"), Default = white, Alpha = 0 })
        box:Toggle({ Name = "Chams", Flag = key("cham_enabled"), Tooltip = "Colors each body part. Needs Enabled on" }):Colorpicker({ Name = "Visible", Flag = key("cham_vis"), Default = white, Alpha = 0.35 }):Colorpicker({ Name = "Behind walls", Flag = key("cham_hid"), Default = white, Alpha = 0.7 })
        box:Toggle({ Name = "Highlight outline", Flag = key("cham_line_on"), Tooltip = "Outlines the whole player. Needs Enabled on" }):Colorpicker({ Name = "Outline color", Flag = key("cham_line"), Default = white, Alpha = 0 })
        if friendly then
            box:Button({ Name = "Copy Enemy here", Callback = function()
                for _, flag in ipairs(PERTEAM) do
                    local value = readFlag(flag, nil)
                    if value ~= nil then
                        if type(value) == "table" then value = table.clone(value) end
                        pcall(setFlag, flag .. "@Friendly", value)
                    end
                end
                pcall(function() Library:Notify("Enemy settings copied to Friendly", 3) end)
            end })
        end
    end

    local TeamEnemy, TeamFriendly = VisualsPage:MultiSection({ Sections = { "Enemy", "Friendly" }, Side = 1 })
    addTeamRows(TeamEnemy, false)
    addTeamRows(TeamFriendly, true)

    local white = Color3.fromRGB(255, 255, 255)
    local General, GradientSet = VisualsPage:MultiSection({ Sections = { "General", "Gradient" }, Side = 1 })
    General:Slider({ Name = "Render distance", Flag = "esp_dist", Min = 50, Max = 3000, Default = 1500, Decimals = 1, Suffix = " studs" })
    General:Slider({ Name = "Text size", Flag = "esp_text", Min = 10, Max = 20, Default = 13, Decimals = 1, Suffix = " px" })
    General:Slider({ Name = "Scale", Flag = "esp_scale", Min = 0.7, Max = 1.6, Default = 1, Decimals = 0.01, Suffix = "x", Tooltip = "Scales text, line thickness and arrows together" })
    General:Dropdown({ Name = "Font", Flag = "esp_font", Items = FONT_ORDER, Default = "Tahoma" })
    General:Toggle({ Name = "Outlines", Flag = "esp_outline", Tooltip = "Dark outline on both sides of the box lines, and on the text, skeleton and icon" })
    General:Toggle({ Name = "Fade with distance", Flag = "esp_fade" })
    General:Toggle({ Name = "Smooth animations", Flag = "esp_smooth", Tooltip = "Fade in and smooth health changes" })
    General:Slider({ Name = "Animation speed", Flag = "esp_smooth_speed", Min = 1, Max = 20, Default = 8, Decimals = 0.1 })
    General:Toggle({ Name = "Visible color", Flag = "esp_vis", Tooltip = "Enemies you can see get every feature in this color, except the behind-walls chams" }):Colorpicker({ Name = "Visible color", Flag = "esp_vis_color", Default = white })
    General:Toggle({ Name = "Marked target", Flag = "esp_target", Tooltip = "The player your aimbot is locked on gets every feature in this color, except the behind-walls chams" }):Colorpicker({ Name = "Target color", Flag = "esp_target_color", Default = white })
    GradientSet:Toggle({ Name = "Gradient colors", Flag = "grad_on", Tooltip = "Colors flow between two colors and move over time" }):Colorpicker({ Name = "Color A", Flag = "grad_a", Default = white }):Colorpicker({ Name = "Color B", Flag = "grad_b", Default = white })
    GradientSet:Dropdown({ Name = "Apply to", Flag = "grad_apply", Items = { "Box fill", "Box outline", "Health bar", "Skeleton" }, Multi = true, Default = { "Box fill", "Skeleton" } })
    GradientSet:Slider({ Name = "Speed", Flag = "grad_speed", Min = 0, Max = 2, Default = 0.25, Decimals = 0.01, Tooltip = "0 keeps the gradient still" })
    GradientSet:Slider({ Name = "Stretch", Flag = "grad_stretch", Min = 0.3, Max = 3, Default = 1, Decimals = 0.01, Tooltip = "Higher repeats the colors more often" })

    local BoxSet, HealthSet, ExtraSet, ChamSet = VisualsPage:MultiSection({ Sections = { "Box", "Health", "Extras", "Chams" }, Side = 2 })
    BoxSet:Dropdown({ Name = "Style", Flag = "esp_box", Items = { "Full", "Corners" }, Default = "Corners" })
    BoxSet:Slider({ Name = "Thickness", Flag = "esp_thick", Min = 1, Max = 4, Default = 1, Decimals = 0.1, Suffix = " px" })
    BoxSet:Toggle({ Name = "Fit to pose", Flag = "esp_tight", Tooltip = "The box wraps the whole body, including crouching and prone" })
    BoxSet:Toggle({ Name = "Glow", Flag = "esp_glow", Tooltip = "Soft layers of color spreading out from the box" }):Colorpicker({ Name = "Glow color", Flag = "esp_glow_color", Default = white, Alpha = 0.5 })
    BoxSet:Slider({ Name = "Glow spread", Flag = "esp_glow_size", Min = 2, Max = 30, Default = 10, Decimals = 1, Suffix = " px" })
    HealthSet:Dropdown({ Name = "Position", Flag = "esp_hp_pos", Items = { "Left", "Right", "Top", "Bottom" }, Default = "Left" })
    HealthSet:Slider({ Name = "Width", Flag = "esp_hp_width", Min = 2, Max = 8, Default = 3, Decimals = 1, Suffix = " px" })
    HealthSet:Toggle({ Name = "Color by health", Flag = "esp_hp_dynamic", Tooltip = "Green when healthy, red when low, instead of the picked color" })
    HealthSet:Toggle({ Name = "Damage trail", Flag = "esp_hp_trail", Tooltip = "A fading bar shows the health that was just lost" })
    ExtraSet:Slider({ Name = "Skeleton thickness", Flag = "esp_skeleton_thick", Min = 1, Max = 4, Default = 1.5, Decimals = 0.1, Suffix = " px" })
    ExtraSet:Dropdown({ Name = "Tracer origin", Flag = "esp_tracer_from", Items = { "Bottom", "Center", "Top" }, Default = "Bottom" })
    ExtraSet:Toggle({ Name = "Arrow text", Flag = "esp_arrow_text", Tooltip = "Shows the name and distance next to each arrow" })
    ExtraSet:Slider({ Name = "Arrow size", Flag = "esp_arrow_size", Min = 8, Max = 32, Default = 14, Decimals = 1, Suffix = " px" })
    ExtraSet:Slider({ Name = "Arrow distance", Flag = "esp_arrow_radius", Min = 60, Max = 400, Default = 160, Decimals = 1, Suffix = " px" })
    ChamSet:Slider({ Name = "Thickness", Flag = "cham_thick", Min = 0, Max = 0.6, Default = 0.1, Decimals = 0.01 })
    ChamSet:Toggle({ Name = "Glow", Flag = "cham_glow" })
    ChamSet:Slider({ Name = "Glow strength", Flag = "cham_glow_size", Min = 1, Max = 2.5, Default = 1.75, Decimals = 0.01 })
    ChamSet:Toggle({ Name = "Round head", Flag = "cham_round" })
    ChamSet:Slider({ Name = "Head size", Flag = "cham_head", Min = 0.8, Max = 1.6, Default = 1.15, Decimals = 0.01 })
    ChamSet:Toggle({ Name = "Outline through walls", Flag = "cham_line_walls" })

    local CameraBox = MiscSubs.Camera:Section({ Name = "Camera", Side = 1 })
    CameraBox:Toggle({ Name = "Field of view", Flag = "cam_fov_on", Default = false, Tooltip = "Applies when you are not aiming down sights" })
    CameraBox:Slider({ Name = "Value", Flag = "cam_fov", Min = 50, Max = 120, Default = 85, Decimals = 1, Suffix = "°" })

    local Utility = MiscSubs.Utility:Section({ Name = "Utility", Side = 1 })
    Utility:Toggle({ Name = "Watermark", Flag = "misc_watermark", Default = true, Callback = function(value)
        pcall(function() Library:SetWatermarkVisibility(value) end)
    end })
    Utility:Toggle({ Name = "Anti AFK", Flag = "misc_afk", Default = true })
end

-- ============================================================ legit aim
local Aim = { target = nil, since = 0, reactUntil = 0, switchAt = 0, part = nil }
local fovCircle = newDrawing("Circle", { Thickness = 1, NumSides = 64, Filled = false, Visible = false, ZIndex = 5 })
local GROUPS = { Head = { "Head" }, Torso = { "Torso" }, Arms = { "Left Arm", "Right Arm" }, Legs = { "Left Leg", "Right Leg" } }
local GROUP_ORDER = { "Head", "Torso", "Arms", "Legs" }

local function lerp(a, b, t) return a + (b - a) * t end

local function dynamicRadius(distance, maxDistance)
    if not F("fov_dynamic", false) then return F("fov_radius", 120) end
    local t = math.clamp(distance / math.max(maxDistance, 1), 0, 1)
    return lerp(F("fov_near", 240), F("fov_far", 60), t)
end

local function leadPoint(origin, position, velocity, speed, useDrop, useMove, strength, maxLead)
    if type(speed) ~= "number" or speed <= 1 then return position end
    local accel = Core.accel
    local time = (position - origin).Magnitude / speed
    local aim = position
    for _ = 1, 3 do
        local move = Vector3.zero
        if useMove then
            move = velocity * time * strength
            if move.Magnitude > maxLead then move = move.Unit * maxLead end
        end
        local drop = Vector3.zero
        if useDrop then drop = -0.5 * accel * time * time * strength end
        aim = position + move + drop
        time = (aim - origin).Magnitude / speed
    end
    return aim
end

local function chooseTarget(records, cam, origin, center, now, weapon)
    local maxDistance = F("aim_dist", 600)
    local wantVisible = F("aim_visible", true)
    local groups = multi("aim_parts", { Head = true, Torso = true })
    local priorityMode = F("aim_choice", "Closest to crosshair") == "Priority order"
    local priority = F("aim_priority", "Crosshair")
    local speed = weaponStat(weapon, "bulletspeed")
    local useDrop, useMove = F("lead_drop", true), F("lead_move", true)
    local strength, maxLead = F("lead_strength", 1), F("lead_max", 14)

    local best, bestPart, bestAim, bestScore, bestScreen

    for _, record in ipairs(records) do
        if record.enemy then
            local distance = (record.torso.Position - origin).Magnitude
            if distance <= maxDistance then
                local radius = dynamicRadius(distance, maxDistance)
                local partChoice, partScreen, partWorld
                for _, groupName in ipairs(GROUP_ORDER) do
                    if groups[groupName] then
                        for _, partName in ipairs(GROUPS[groupName]) do
                            local part = record.hash[partName]
                            if part and part.Parent then
                                local point, onScreen = cam:WorldToViewportPoint(part.Position)
                                if onScreen and point.Z > 0 then
                                    local screen = (Vector2.new(point.X, point.Y) - center).Magnitude
                                    if screen <= radius and (not wantVisible or isVisible(part, origin, now)) then
                                        if priorityMode then
                                            partChoice, partScreen, partWorld = part, screen, part.Position
                                            break
                                        elseif not partScreen or screen < partScreen then
                                            partChoice, partScreen, partWorld = part, screen, part.Position
                                        end
                                    end
                                end
                            end
                        end
                        if priorityMode and partChoice then break end
                    end
                end
                if partChoice then
                    local score
                    if priority == "Distance" then
                        score = distance
                    elseif priority == "Lowest health" then
                        score = record.health * 1000 + partScreen
                    else
                        score = partScreen
                    end
                    if not bestScore or score < bestScore then
                        best, bestPart, bestScore, bestScreen = record, partChoice, score, partScreen
                        bestAim = leadPoint(origin, partWorld, record.velocity, speed, useDrop, useMove, strength, maxLead)
                    end
                end
            end
        end
    end
    return best, bestPart, bestAim
end

-- keeps following the locked player, ignoring FOV and range; returns nil for the part while they are hidden
local function holdTarget(record, cam, origin, center, now, weapon)
    local groups = multi("aim_parts", { Head = true, Torso = true })
    local wantVisible = F("aim_visible", true)
    local priorityMode = F("aim_choice", "Closest to crosshair") == "Priority order"
    local best, bestScore
    for _, groupName in ipairs(GROUP_ORDER) do
        if groups[groupName] then
            for _, partName in ipairs(GROUPS[groupName]) do
                local part = record.hash[partName]
                if part and part.Parent and (not wantVisible or isVisible(part, origin, now)) then
                    local point, onScreen = cam:WorldToViewportPoint(part.Position)
                    local score = (onScreen and point.Z > 0) and (Vector2.new(point.X, point.Y) - center).Magnitude or 1e5
                    if not bestScore or score < bestScore then best, bestScore = part, score end
                end
            end
            if priorityMode and best then break end
        end
    end
    if not best then return nil end
    local aim = leadPoint(origin, best.Position, record.velocity, weaponStat(weapon, "bulletspeed"), F("lead_drop", true), F("lead_move", true), F("lead_strength", 1), F("lead_max", 14))
    return best, aim
end

local function turnToward(gameCam, origin, aimPoint, dt, now)
    local direction = aimPoint - origin
    if direction.Magnitude < 0.01 then return end
    direction = direction.Unit

    local noise = F("aim_noise", 0.25)
    local targetPitch = math.atan2(direction.Y, math.sqrt(direction.X * direction.X + direction.Z * direction.Z))
    local targetYaw = math.atan2(-direction.X, -direction.Z)
    if noise > 0 then
        local rate = F("aim_noise_speed", 1.4)
        targetPitch += math.rad(noise) * math.noise(now * rate, 11.3) * 2
        targetYaw += math.rad(noise) * math.noise(now * rate, 47.9) * 2
    end

    local look = gameCam:getLookVector()
    if typeof(look) ~= "Vector3" then return end
    local currentPitch = math.atan2(look.Y, math.sqrt(look.X * look.X + look.Z * look.Z))
    local currentYaw = math.atan2(-look.X, -look.Z)
    local deltaPitch = targetPitch - currentPitch
    local deltaYaw = (targetYaw - currentYaw + math.pi) % (math.pi * 2) - math.pi

    local alpha = 1 - math.exp(-dt * 60 / math.max(F("aim_smooth", 12), 1))
    local stepPitch, stepYaw = deltaPitch * alpha, deltaYaw * alpha
    local cap = math.rad(F("aim_speed", 420)) * dt
    local size = math.sqrt(stepPitch * stepPitch + stepYaw * stepYaw)
    if size > cap and size > 0 then
        stepPitch, stepYaw = stepPitch * cap / size, stepYaw * cap / size
    end

    local base = gameCam:getAngles()
    if typeof(base) ~= "Vector3" then return end
    local pitch, yaw = base.X + stepPitch, base.Y + stepYaw
    local cosPitch = math.cos(pitch)
    gameCam:setLookVector(Vector3.new(-cosPitch * math.sin(yaw), math.sin(pitch), -cosPitch * math.cos(yaw)))
end

local function legitStep(dt, cam, now, records, center)
    Aim.moved = false
    local weapon = activeWeapon()
    local weaponName = weapon and weapon.weaponName or nil

    if fovCircle then
        local show = readFlag("fov_show", true) and readFlag("aim_enabled", false)
        fovCircle.Visible = show
        if show then
            local radius = F("fov_radius", 120)
            if F("fov_dynamic", false) then
                radius = Aim.target and Aim.radius or F("fov_near", 240)
            end
            fovCircle.Position = center
            fovCircle.Radius = radius
            fovCircle.Color = readFlag("fov_color", WHITE)
        end
    end

    if PF_StatusWeapon then
        local text = "Weapon: " .. tostring(weaponName or "none")
        local speed = weaponStat(weapon, "bulletspeed")
        if type(speed) == "number" then text ..= " | " .. math.floor(speed) .. " studs/s" end
        if Aim.lastWeaponText ~= text then
            Aim.lastWeaponText = text
            PF_StatusWeapon:SetText(text)
        end
    end

    local active = readFlag("aim_enabled", false) and weaponKeyActive("aim_key", "ownaim", "aim_key") and Library.Toggled ~= true and not typing()
    local speed = weaponStat(weapon, "bulletspeed")
    if not (active and weapon and type(speed) == "number") then
        Aim.target = nil
        return
    end
    if F("aim_ads", false) and not weaponAiming(weapon) then Aim.target = nil return end
    if F("aim_shoot", false) and not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then Aim.target = nil return end

    local gameCam = gameCamera()
    if not gameCam then return end
    local origin = cam.CFrame.Position

    local record, part, aimPoint
    if Aim.target and F("aim_sticky", true) then
        for _, candidate in ipairs(records) do
            if candidate.player == Aim.target and candidate.enemy then record = candidate break end
        end
        if record then
            part, aimPoint = holdTarget(record, cam, origin, center, now, weapon)
            Aim.record = record
            Aim.radius = dynamicRadius((record.torso.Position - origin).Magnitude, F("aim_dist", 600))
            if not part then return end
        else
            Aim.target = nil
        end
    end
    if not record then
        record, part, aimPoint = chooseTarget(records, cam, origin, center, now, weapon)
        if not record then
            Aim.target = nil
            return
        end
    end

    if Aim.target ~= record.player then
        local delay = F("aim_switch", 120) / 1000
        if Aim.target and now - Aim.switchAt < delay then return end
        Aim.target = record.player
        Aim.switchAt = now
        Aim.reactUntil = now + F("aim_react", 60) / 1000
    end
    Aim.part = part
    Aim.radius = dynamicRadius((record.torso.Position - origin).Magnitude, F("aim_dist", 600))
    Aim.record = record

    if now < Aim.reactUntil then return end
    turnToward(gameCam, origin, aimPoint, dt, now)
    Aim.moved = true
end

-- ============================================================ recoil control
local Recoil = { body = nil, head = nil, last = Vector3.zero, shown = Vector3.zero }

local function recoilOffset(gameCam)
    local body, head = gameCam._cameraBodySprings, gameCam._cameraHeadSprings
    local total = Vector3.zero
    pcall(function()
        if body then total += body:getP() end
        if head then total += head:getP() end
    end)
    return total, body, head
end

local function recoilStep(gameCam, weapon, now)
    local offset, body, head = recoilOffset(gameCam)
    Recoil.shown = offset
    if body ~= Recoil.body or head ~= Recoil.head then
        Recoil.body, Recoil.head, Recoil.last = body, head, offset
        return
    end
    local delta = offset - Recoil.last
    Recoil.last = offset

    local active = readFlag("rcs_enabled", false) and keyActive("rcs_key") and Library.Toggled ~= true
    if not active or Aim.moved then return end
    if not weapon or type(weaponStat(weapon, "bulletspeed")) ~= "number" then return end
    if not F("rcs_hip", true) and not weaponAiming(weapon) then return end

    local vertical, horizontal = F("rcs_v", 70) / 100, F("rcs_h", 40) / 100
    local variation = F("rcs_human", 10) / 100
    if variation > 0 then
        local factor = 1 - variation * (math.noise(now * 1.7, 31.4) + 1) * 0.5
        vertical, horizontal = vertical * factor, horizontal * factor
    end

    local base = gameCam:getAngles()
    if typeof(base) ~= "Vector3" then return end
    local pitch, yaw = base.X - delta.X * vertical, base.Y - delta.Y * horizontal
    local cosPitch = math.cos(pitch)
    gameCam:setLookVector(Vector3.new(-cosPitch * math.sin(yaw), math.sin(pitch), -cosPitch * math.cos(yaw)))
end

-- ============================================================ triggerbot
local Trigger = { onSince = nil, releaseAt = 0, nextAt = 0, down = false }

local function releaseTrigger()
    if Trigger.down then
        Trigger.down = false
        pcall(function() if mouse1release then mouse1release() end end)
    end
end
onUnload(releaseTrigger)

local function rayPointDistance(origin, direction, point)
    local offset = point - origin
    local along = offset:Dot(direction)
    if along <= 0 then return math.huge, along end
    return (offset - direction * along).Magnitude, along
end

local function triggerStep(cam, now, records)
    if Trigger.down and now >= Trigger.releaseAt then
        releaseTrigger()
        Trigger.nextAt = now + F("trig_cool", 90) / 1000
    end
    local active = readFlag("trig_enabled", false) and weaponKeyActive("trig_key", "owntrig", "trig_key") and Library.Toggled ~= true and not typing()
    if not active or type(mouse1press) ~= "function" then
        Trigger.onSince = nil
        if not active then releaseTrigger() end
        return
    end
    local weapon = activeWeapon()
    if not weapon or type(weaponStat(weapon, "bulletspeed")) ~= "number" then Trigger.onSince = nil return end
    if F("trig_ads", false) and not weaponAiming(weapon) then Trigger.onSince = nil return end

    local origin, direction = cam.CFrame.Position, cam.CFrame.LookVector
    local maxDistance = F("trig_dist", 400)
    local scale = F("trig_scale", 0.9)
    local groups = multi("trig_parts", { Head = true, Torso = true })
    local wantVisible = F("trig_visible", true)

    local onTarget = false
    for _, record in ipairs(records) do
        if record.enemy then
            for groupName in pairs(groups) do
                for _, partName in ipairs(GROUPS[groupName] or {}) do
                    local part = record.hash[partName]
                    if part and part.Parent then
                        local miss, along = rayPointDistance(origin, direction, part.Position)
                        if along <= maxDistance then
                            local size = part.Size
                            local radius = math.max(size.X, size.Y, size.Z) * 0.5 * scale
                            if miss <= radius and (not wantVisible or isVisible(part, origin, now)) then
                                onTarget = true
                                break
                            end
                        end
                    end
                end
                if onTarget then break end
            end
        end
        if onTarget then break end
    end

    if not onTarget then
        Trigger.onSince = nil
        return
    end
    Trigger.onSince = Trigger.onSince or now
    if Trigger.down or now < Trigger.nextAt then return end
    if now - Trigger.onSince < F("trig_delay", 40) / 1000 then return end
    if not weaponCanFire(weapon) then return end
    Trigger.down = true
    Trigger.releaseAt = now + F("trig_hold", 70) / 1000
    pcall(mouse1press)
end

-- ============================================================ ESP
local FONTS = { Plex = 2, Monospace = 3, UI = 0, System = 1 }
local STRIPS = 8
local espObjects, espState = {}, {}
local adornData, outlineSets = {}, {}
local adornFolder, outlineFolder

-- parenting into CoreGui needs a high thread identity, and code relaunched inside an actor often runs lower
local function elevate()
    for _, name in ipairs({ "setthreadidentity", "set_thread_identity", "setidentity", "setthreadcontext" }) do
        local fn = getgenv()[name]
        if type(fn) == "function" and pcall(fn, 7) then return true end
    end
    local syn_ = getgenv().syn
    if type(syn_) == "table" and type(syn_.set_thread_identity) == "function" then return pcall(syn_.set_thread_identity, 7) end
    return false
end

local containerNote
local function randomName()
    local letters = {}
    for index = 1, 10 do letters[index] = string.char(math.random(97, 122)) end
    return table.concat(letters)
end
local function ensureFolder(current)
    if current and current.Parent then return current end
    local parents = { { Workspace, "Workspace" } }
    local current_ = camera()
    if current_ then parents[#parents + 1] = { current_, "Camera" } end
    for _, entry in ipairs(parents) do
        local folder = Instance.new("Folder")
        folder.Name = randomName()
        if pcall(function() folder.Parent = entry[1] end) and folder.Parent then
            if containerNote ~= entry[2] then
                containerNote = entry[2]
                print("[Aster] chams container: " .. entry[2])
            end
            return folder
        end
        pcall(function() folder:Destroy() end)
    end
    return nil
end

local function pickerTransparency(flag, default)
    local option = Options[flag]
    if option and type(option.Transparency) == "number" then return math.clamp(option.Transparency, 0, 1) end
    return default
end

-- ---------------------------------------------------------------- settings
local cfgCache = {}
local function teamCfg(friendly)
    local suffix = friendly and "@Friendly" or ""
    local c = cfgCache[friendly]
    if not c then c = {} cfgCache[friendly] = c end
    local function r(flag, default) return readFlag(flag .. suffix, default) end
    local function g(flag, default) return readFlag(flag, default) end
    c.enabled = r("esp_enabled", false)
    c.color = r("esp_color", WHITE)
    c.box = r("esp_box_on", true) and g("esp_box", "Corners") or "Off"
    c.outlineOn, c.tight, c.glow = g("esp_outline", false), g("esp_tight", false), g("esp_glow", false)
    c.fillOn, c.fillColor, c.fillT, c.thick = r("esp_fill", false), r("esp_fill_color", WHITE), pickerTransparency("esp_fill_color" .. suffix, 0.88), g("esp_thick", 1)
    c.name, c.nameColor = r("esp_name", false), r("esp_name_color", WHITE)
    c.distance, c.distColor = r("esp_distance", false), r("esp_dist_color", WHITE)
    c.weapon, c.weaponColor = r("esp_weapon", false), r("esp_weapon_color", WHITE)
    c.weaponIcon, c.weaponIconColor = r("esp_weapon_icon", false), r("esp_weapon_icon_color", WHITE)
    c.text, c.textOutline = g("esp_text", 13), c.outlineOn
    c.health, c.hpPos, c.hpWidth, c.hpText, c.hpTrail = r("esp_health", false), g("esp_hp_pos", "Left"), g("esp_hp_width", 3), r("esp_hp_text", false), g("esp_hp_trail", false)
    c.hpColor, c.hpDynamic = r("esp_hp_full", WHITE), g("esp_hp_dynamic", false)
    c.skeleton, c.skeletonColor = r("esp_skeleton", false), r("esp_skeleton_color", WHITE)
    c.skeletonThick, c.skeletonOutline = g("esp_skeleton_thick", 1.5), c.outlineOn
    c.head, c.headColor = r("esp_head", false), r("esp_head_color", WHITE)
    c.tracer, c.tracerColor, c.tracerFrom = r("esp_tracer", false), r("esp_tracer_color", WHITE), g("esp_tracer_from", "Bottom")
    c.arrows, c.arrowColor, c.arrowText = r("esp_arrows", false), r("esp_arrow_color", WHITE), g("esp_arrow_text", false)
    c.arrowSize, c.arrowRadius = g("esp_arrow_size", 14), g("esp_arrow_radius", 160)
    c.chamOn = r("cham_enabled", false)
    c.chamVis, c.chamVisT = r("cham_vis", WHITE), pickerTransparency("cham_vis" .. suffix, 0.35)
    c.chamHid, c.chamHidT = r("cham_hid", WHITE), pickerTransparency("cham_hid" .. suffix, 0.7)
    c.lineOn, c.lineColor, c.lineT = r("cham_line_on", false), r("cham_line", WHITE), pickerTransparency("cham_line" .. suffix, 0)
    local function opacity(flag) return 1 - pickerTransparency(flag .. suffix, 0) end
    c.boxA, c.nameA, c.distA, c.weaponA, c.iconA = opacity("esp_color"), opacity("esp_name_color"), opacity("esp_dist_color"), opacity("esp_weapon_color"), opacity("esp_weapon_icon_color")
    c.hpA, c.skelA, c.headA, c.tracerA, c.arrowA = opacity("esp_hp_full"), opacity("esp_skeleton_color"), opacity("esp_head_color"), opacity("esp_tracer_color"), opacity("esp_arrow_color")
    return c
end

local function selectedSet(name, fallback)
    local value = readFlag(name, fallback)
    local out = {}
    if type(value) == "table" then
        for key, on in pairs(value) do
            if type(key) == "number" then out[on] = true elseif on then out[key] = true end
        end
    end
    return out
end

local function pingPong(t)
    t = t % 2
    if t > 1 then t = 2 - t end
    return t
end

-- ---------------------------------------------------------------- text labels and fonts
local HttpService = game:GetService("HttpService")
local FONT_URL = "https://raw.githubusercontent.com/sametexe001/luas/main/fonts/"
local FONT_DIR = "Aster/PhantomForces/fonts"
local FONT_FILES = {
    ["Tahoma"] = "fs-tahoma-8px.ttf", ["Verdana"] = "verdana.ttf", ["Smallest Pixel"] = "smallest_pixel-7.ttf",
    ["Proggy"] = "proggy-clean.ttf", ["Pixel Operator"] = "PixelOperator.ttf", ["Minecraftia"] = "minecraftia.ttf",
    ["Inter"] = "InterMedium.ttf", ["Roboto Mono"] = "RobotoMono-Regular.ttf", ["Lexend"] = "Lexend-Medium.ttf",
}
local DEFAULT_FACE = Font.fromEnum(Enum.Font.GothamMedium)
local fontFaces, fontLoading = {}, {}

local function download(url)
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if ok and type(body) == "string" and #body > 200 then return body end
    local requester = (syn and syn.request) or request or http_request
    if requester then
        local okRequest, response = pcall(requester, { Url = url, Method = "GET" })
        if okRequest and response and type(response.Body) == "string" and #response.Body > 200 then return response.Body end
    end
    error("download failed")
end

local function loadFont(name)
    local file = FONT_FILES[name]
    if not file or fontFaces[name] or fontLoading[name] then return end
    fontLoading[name] = true
    task.spawn(function()
        local ok, face = pcall(function()
            if not (writefile and isfile and getcustomasset) then error("file functions missing") end
            pcall(makefolder, "Aster")
            pcall(makefolder, "Aster/PhantomForces")
            pcall(makefolder, FONT_DIR)
            local ttf = FONT_DIR .. "/" .. file
            if not isfile(ttf) then writefile(ttf, download(FONT_URL .. file)) end
            local json = FONT_DIR .. "/" .. string.gsub(name, "%s", "") .. ".json"
            writefile(json, HttpService:JSONEncode({
                name = name,
                faces = { { name = "Regular", weight = 400, style = "Regular", assetId = getcustomasset(ttf) } },
            }))
            return Font.new(getcustomasset(json))
        end)
        if ok and face then fontFaces[name] = face else warn("[Aster] font " .. name .. " could not load: " .. tostring(face)) end
        fontLoading[name] = nil
    end)
end

local function fontFace(name)
    if name == "Gotham" or not FONT_FILES[name] then return DEFAULT_FACE end
    local face = fontFaces[name]
    if face then return face end
    loadFont(name)
    return DEFAULT_FACE
end

local labelGui
local function ensureLabelGui()
    if labelGui and labelGui.Parent then return labelGui end
    elevate()
    local parents = {}
    pcall(function() parents[#parents + 1] = game:GetService("CoreGui") end)
    pcall(function() if gethui then parents[#parents + 1] = gethui() end end)
    for _, parent in ipairs(parents) do
        local gui = Instance.new("ScreenGui")
        gui.Name = "PF_Text"
        pcall(function()
            gui.ResetOnSpawn = false
            gui.IgnoreGuiInset = true
            gui.DisplayOrder = 9
        end)
        if pcall(function() gui.Parent = parent end) and gui.Parent then
            labelGui = gui
            return gui
        end
        pcall(function() gui:Destroy() end)
    end
    return nil
end
onUnload(function()
    if labelGui then pcall(function() labelGui:Destroy() end) end
    labelGui = nil
end)

-- a text object with the same fields as a Drawing Text, rendered by a TextLabel so it can use any font
local function newLabel()
    local gui = ensureLabelGui()
    if not gui then return newDrawing("Text", { Center = true, Outline = true, Size = 13, Font = 2, ZIndex = 8 }) end
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.BorderSizePixel = 0
    label.AutomaticSize = Enum.AutomaticSize.XY
    label.Size = UDim2.fromOffset(0, 0)
    label.AnchorPoint = Vector2.new(0.5, 0)
    label.TextWrapped = false
    label.RichText = false
    label.TextColor3 = WHITE
    label.TextSize = 13
    label.FontFace = DEFAULT_FACE
    label.Visible = false
    label.ZIndex = 8
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1
    stroke.Color = BLACK
    stroke.Enabled = false
    stroke.Parent = label
    label.Parent = gui
    local proxy
    local setters = {
        Text = function(value) label.Text = value end,
        Size = function(value) label.TextSize = value end,
        Color = function(value) label.TextColor3 = value end,
        Position = function(value) label.Position = UDim2.fromOffset(math.floor(value.X), math.floor(value.Y)) end,
        Transparency = function(value)
            label.TextTransparency = 1 - value
            stroke.Transparency = 1 - value
        end,
        Outline = function(value) stroke.Enabled = value and true or false end,
        Visible = function(value) label.Visible = value and true or false end,
        FontFace = function(value) label.FontFace = value end,
    }
    proxy = setmetatable({}, {
        __newindex = function(_, key, value)
            local setter = setters[key]
            if setter then setter(value) end
        end,
        __index = function(_, key)
            if key == "Remove" then
                return function() pcall(function() label:Destroy() end) end
            end
            return nil
        end,
    })
    drawings[proxy] = true
    return proxy
end

-- ---------------------------------------------------------------- weapon icons
-- Every weapon in the game gets a pixel silhouette built from its class, magazine size and barrel length.
local ICON_SPECS = {
    ["1858carbine"] = "V01201",
    ["1858newarmy"] = "V00001",
    ["93r"] = "S00101",
    ["aa12"] = "H00032",
    ["aek919k"] = "S00200",
    ["aek971"] = "R00022",
    ["aek973"] = "C00221",
    ["aek973s"] = "C00221",
    ["aek999"] = "L00032",
    ["af2011a1"] = "P12002",
    ["ag3"] = "B00002",
    ["ak103"] = "R12220",
    ["ak105"] = "C11121",
    ["ak12"] = "R01121",
    ["ak1276"] = "H01120",
    ["ak12br"] = "L12220",
    ["ak12c"] = "C12221",
    ["ak12m"] = "R00022",
    ["ak12u"] = "C02122",
    ["ak15"] = "R12220",
    ["ak19"] = "R10022",
    ["ak308"] = "B00021",
    ["ak47"] = "R11220",
    ["ak74"] = "R00120",
    ["ak9"] = "C12221",
    ["akm"] = "R02220",
    ["aks74u"] = "S11220",
    ["aku12"] = "C02122",
    ["alien"] = "P02202",
    ["amiii"] = "P10100",
    ["an94"] = "R02120",
    ["ar36"] = "R11201",
    ["ar36c"] = "S10201",
    ["ar36k"] = "C11000",
    ["armcannon"] = "K01012",
    ["armpistol"] = "S01021",
    ["asmi"] = "S00001",
    ["aspbaton"] = "K01122",
    ["asval"] = "R12221",
    ["auga1"] = "R11220",
    ["auga2"] = "R10021",
    ["auga3"] = "C10121",
    ["auga3m2"] = "D02122",
    ["auga3para"] = "S02122",
    ["aughbar"] = "L00121",
    ["augunbullpup"] = "R11221",
    ["auto9"] = "S21100",
    ["automagiii"] = "P10100",
    ["awm"] = "N01220",
    ["aws"] = "N01222",
    ["balisong"] = "K01221",
    ["ballista"] = "N01222",
    ["banhammer"] = "T01232",
    ["banjo"] = "T00200",
    ["barefists"] = "K00132",
    ["baseballbat"] = "T00121",
    ["beowulfecr"] = "B12221",
    ["beowulftcr"] = "D00221",
    ["bfg50"] = "N02220",
    ["blockson"] = "S10100",
    ["bloxy"] = "K01130",
    ["boombox"] = "B12022",
    ["bottle"] = "K00031",
    ["boxybuster"] = "P00200",
    ["brassknuckle"] = "K01131",
    ["bren2"] = "R00110",
    ["bren2br"] = "B12111",
    ["bren2pps"] = "D11111",
    ["bren3"] = "R00210",
    ["brick"] = "K00101",
    ["bridalbrandisher"] = "K01102",
    ["bundlecharge"] = "G02002",
    ["bwc9"] = "S12002",
    ["bwc9a"] = "S12002",
    ["c25"] = "C00220",
    ["c7a2"] = "R00221",
    ["c8a2"] = "C02021",
    ["c8a3"] = "C02021",
    ["c8nld"] = "C10020",
    ["cancannon"] = "C10022",
    ["candycane"] = "K00201",
    ["car15"] = "C00221",
    ["chainsaw"] = "L11001",
    ["chosenone"] = "T02000",
    ["classicknife"] = "K01232",
    ["cleaver"] = "K00001",
    ["clementine"] = "T00021",
    ["clonker"] = "K02111",
    ["cobrayterminator"] = "H01102",
    ["coilgun"] = "P00020",
    ["colacannon"] = "C10022",
    ["coltacr"] = "R11221",
    ["coltlmg"] = "L00022",
    ["coltmars"] = "S01020",
    ["coltsmg635"] = "S11122",
    ["comp1022"] = "N02222",
    ["cookiecutter"] = "K00000",
    ["crane"] = "T01221",
    ["cricketbat"] = "K02202",
    ["crowbar"] = "K02220",
    ["cslr3"] = "N01220",
    ["cslr4a"] = "N02222",
    ["cursedshinai"] = "T00101",
    ["cutlass"] = "K02121",
    ["cutter"] = "K01000",
    ["darkheart"] = "K00021",
    ["dbv12"] = "H01120",
    ["deagle44"] = "V01201",
    ["deagle50"] = "V02102",
    ["deaglel5"] = "V01201",
    ["deaglexix"] = "V02102",
    ["doombox"] = "B12022",
    ["dragunovsvds"] = "N02222",
    ["dragunovsvu"] = "D02120",
    ["dsr50"] = "N00221",
    ["dt11"] = "H02022",
    ["dt11pro"] = "H02022",
    ["dynamite"] = "G01031",
    ["dynamite3"] = "G01211",
    ["ef88"] = "C11121",
    ["egun"] = "P00020",
    ["entrencher"] = "K02202",
    ["eshotgun"] = "H00120",
    ["executioner"] = "V01102",
    ["f90mbr"] = "R10021",
    ["fal5000"] = "B12001",
    ["fal5000t"] = "B10000",
    ["fal5063para"] = "B01201",
    ["falo5041"] = "L10121",
    ["falparashorty"] = "S02001",
    ["famas"] = "R02222",
    ["famascommando"] = "S12221",
    ["famasf1"] = "R02122",
    ["famasg2"] = "R02222",
    ["famasunbullpup"] = "R11021",
    ["fireaxe"] = "T02020",
    ["five0"] = "S10120",
    ["fiveseven"] = "P10102",
    ["fixer"] = "K01232",
    ["flameofolympia"] = "K01121",
    ["frag"] = "G00100",
    ["fryingpan"] = "K00001",
    ["ft300"] = "N01222",
    ["fumelee"] = "K01132",
    ["g1"] = "P02201",
    ["g11k2"] = "R21001",
    ["g17"] = "P02201",
    ["g18c"] = "S00101",
    ["g21"] = "P10101",
    ["g23"] = "P11102",
    ["g28"] = "D10121",
    ["g3"] = "B11200",
    ["g36"] = "R11201",
    ["g36c"] = "S10201",
    ["g36k"] = "C11000",
    ["g38"] = "R11022",
    ["g40"] = "P10201",
    ["g50"] = "P00102",
    ["gau5aa"] = "C00221",
    ["gb22"] = "P00101",
    ["gerat90"] = "R21001",
    ["gim1"] = "P11000",
    ["glock1"] = "P02201",
    ["glock17"] = "P02201",
    ["glock18"] = "S00101",
    ["glock21"] = "P10101",
    ["glock23"] = "P11102",
    ["glock40"] = "P10201",
    ["glock50"] = "P00102",
    ["goldendeagle2"] = "V00101",
    ["goldendeagle50"] = "V02001",
    ["goldengun"] = "P00002",
    ["goldenhk51b"] = "L10102",
    ["goldenpan"] = "K02201",
    ["goldenredhawk45"] = "V00201",
    ["goldenshorty"] = "H01202",
    ["goldentommygun"] = "S22000",
    ["goldenzip22"] = "H01200",
    ["goldhawk"] = "V00201",
    ["gospellblade"] = "K02120",
    ["grizzly"] = "V00201",
    ["groza1"] = "C01021",
    ["groza4"] = "C11120",
    ["gsh18"] = "P01101",
    ["gsp"] = "P10001",
    ["gustav66"] = "B00002",
    ["gyrojetcarbine"] = "C00201",
    ["gyrojetmarki"] = "P12000",
    ["hamriar"] = "L22022",
    ["hardballer"] = "P10000",
    ["harvester"] = "T00010",
    ["hattori"] = "T02130",
    ["havocblade"] = "K00100",
    ["hcar"] = "B11211",
    ["hecateii"] = "N00220",
    ["henry4570"] = "B02131",
    ["hk21"] = "L12102",
    ["hk337"] = "C01122",
    ["hk416"] = "R02221",
    ["hk416a5"] = "C12122",
    ["hk416c"] = "S01122",
    ["hk417"] = "B12021",
    ["hk51b"] = "D12100",
    ["hockeystick"] = "T02000",
    ["holidaytea"] = "K00031",
    ["honeybadger"] = "S01020",
    ["hornet"] = "L00000",
    ["howatype20"] = "R00221",
    ["hrunting"] = "K02122",
    ["huntingknife"] = "K02211",
    ["ia2ar"] = "R02220",
    ["ia2br"] = "B11021",
    ["ia2smg"] = "S11021",
    ["iar36"] = "L21001",
    ["icemourne"] = "T02210",
    ["icepick"] = "K00211",
    ["icicle"] = "K02132",
    ["imp9"] = "S11122",
    ["intervention"] = "N00222",
    ["ithaca37"] = "H02021",
    ["izhevskpb"] = "P01200",
    ["jason"] = "K00011",
    ["jg90"] = "D01100",
    ["jkey"] = "K02221",
    ["juan"] = "V02001",
    ["juancarbine"] = "V00101",
    ["judge"] = "H00001",
    ["juggun"] = "L02000",
    ["jury"] = "V01201",
    ["k14"] = "N02221",
    ["k1a"] = "C02121",
    ["k2"] = "R10021",
    ["k7"] = "S11022",
    ["kacsrr"] = "V02002",
    ["kama"] = "K00022",
    ["kanabo"] = "T00130",
    ["karambit"] = "K00220",
    ["karambitr"] = "K00220",
    ["kek50"] = "N00200",
    ["key"] = "K00021",
    ["keyboard"] = "K02120",
    ["kg99"] = "P12002",
    ["knife"] = "K01221",
    ["kommando"] = "K02002",
    ["kordr"] = "L22222",
    ["korpionvz61"] = "S11202",
    ["krampuskukri"] = "K02230",
    ["krinkov"] = "S11220",
    ["krissvector"] = "S11201",
    ["ks23m"] = "H01200",
    ["ksg12"] = "H00201",
    ["kunai"] = "K00121",
    ["l115a3"] = "N01220",
    ["l22"] = "C01020",
    ["l22a2"] = "C01020",
    ["l2a3"] = "S12102",
    ["l85a2"] = "R12121",
    ["l85a2unbullpup"] = "R01220",
    ["l85a3"] = "R02222",
    ["l86a2lsw"] = "L11220",
    ["l86lsw"] = "L11220",
    ["larata"] = "H01200",
    ["linkedsword"] = "K01212",
    ["lmgbling"] = "L10102",
    ["longsword"] = "T00001",
    ["lsvm04"] = "L00022",
    ["luty"] = "S00102",
    ["m107"] = "N02221",
    ["m110a1"] = "N02221",
    ["m110a1csass"] = "N02221",
    ["m14"] = "B12001",
    ["m14br"] = "B12001",
    ["m14dmr"] = "D10101",
    ["m16a1"] = "R02020",
    ["m16a2e2acr"] = "R11221",
    ["m16a3"] = "R01220",
    ["m16a4"] = "R10021",
    ["m17"] = "P00102",
    ["m1903"] = "N02221",
    ["m1911"] = "P12001",
    ["m1911a1"] = "P12001",
    ["m1918a2"] = "L10211",
    ["m2011"] = "P01001",
    ["m21"] = "D10101",
    ["m231"] = "R02220",
    ["m249saw"] = "L10232",
    ["m24stick"] = "G01021",
    ["m26frag"] = "G01222",
    ["m27iar"] = "L01022",
    ["m28gdmr"] = "D10121",
    ["m337"] = "C01122",
    ["m3712g"] = "H02021",
    ["m3822"] = "P12002",
    ["m38a7"] = "R11022",
    ["m3a1"] = "S00002",
    ["m4"] = "C12221",
    ["m416"] = "R02221",
    ["m416a5"] = "C12122",
    ["m416c"] = "S01122",
    ["m417a2"] = "B12021",
    ["m41a"] = "R01000",
    ["m45a1"] = "P12100",
    ["m4a1"] = "C01122",
    ["m560mini"] = "G01122",
    ["m60"] = "L01231",
    ["m60e6"] = "L01231",
    ["m67frag"] = "G00100",
    ["m7644"] = "P10101",
    ["m79thumper"] = "H00202",
    ["m7ngsw"] = "B12100",
    ["m82a1"] = "N02221",
    ["m9"] = "P10200",
    ["m93r"] = "S00101",
    ["mac10"] = "S02101",
    ["mac11"] = "S11202",
    ["mac15"] = "R01002",
    ["mac31"] = "S21002",
    ["machete"] = "K00101",
    ["magliteclub"] = "K01011",
    ["makarovpm"] = "P01001",
    ["mars"] = "S01020",
    ["mateba6"] = "V01001",
    ["max1115"] = "R01002",
    ["max31"] = "S21002",
    ["mc51sd"] = "D11202",
    ["mcxrattler"] = "S12202",
    ["mcxspear"] = "B12100",
    ["mcxvirtus"] = "C01101",
    ["mekleth"] = "K02002",
    ["mg36"] = "L21001",
    ["mg3kws"] = "L00232",
    ["mg42"] = "L11030",
    ["mg80"] = "L12102",
    ["mg89b"] = "D12100",
    ["mgv176"] = "L00002",
    ["microuzi"] = "S10101",
    ["minifix"] = "C10221",
    ["mjlnir"] = "K02101",
    ["mjolnir"] = "K02101",
    ["mk11"] = "D02222",
    ["mk11mod2"] = "D02222",
    ["mk12spr"] = "D11221",
    ["mk16socom"] = "R12120",
    ["mk16socomcqb"] = "S12022",
    ["mk16socomsc"] = "C02120",
    ["mk17socom"] = "B10221",
    ["mk17ultralight"] = "B12022",
    ["mk20ssr"] = "D00122",
    ["mk2frag"] = "G00200",
    ["model700"] = "N00220",
    ["model870"] = "H01100",
    ["morningstar"] = "T02210",
    ["mosinnagant"] = "N02220",
    ["mp10"] = "S01100",
    ["mp1911"] = "S10002",
    ["mp40"] = "S10101",
    ["mp412rex"] = "V01101",
    ["mp5"] = "S02200",
    ["mp510"] = "S12101",
    ["mp5k"] = "S02002",
    ["mp5sd"] = "S02000",
    ["mp7"] = "S02100",
    ["mp9"] = "S11122",
    ["msg90"] = "D01100",
    ["mts569"] = "D01101",
    ["naginata"] = "T02022",
    ["natahatchet"] = "K01022",
    ["neowulfecr"] = "B12221",
    ["neowulftcr"] = "D00221",
    ["nightstick"] = "K00221",
    ["noobslayer"] = "T02202",
    ["nordicwaraxe"] = "T01120",
    ["ntw20"] = "N00221",
    ["obrez"] = "N00221",
    ["origin12"] = "H01230",
    ["ots126"] = "P10002",
    ["p90"] = "S22202",
    ["pacificfm"] = "K01122",
    ["paddle"] = "T00032",
    ["pbgrenade"] = "G01230",
    ["pdc45"] = "P01200",
    ["pdx45"] = "S02100",
    ["pkm"] = "L12030",
    ["pkp"] = "L11231",
    ["pkpb"] = "D02132",
    ["pkpbychok"] = "D02132",
    ["pkppecheneg"] = "L11231",
    ["pl8"] = "D02102",
    ["pocketknife"] = "K02212",
    ["pp19bizon"] = "S22022",
    ["pp2000"] = "S11102",
    ["ppsh41"] = "S21201",
    ["present"] = "T02200",
    ["qbu88"] = "D02120",
    ["qbz95"] = "R02120",
    ["qbz97a"] = "R11022",
    ["qjb95lsw"] = "L22121",
    ["r1022"] = "D02221",
    ["railgun"] = "N00222",
    ["rama1130"] = "S20202",
    ["rattler"] = "S12202",
    ["rcs1022"] = "N02222",
    ["reaper"] = "T00111",
    ["reapr"] = "L20130",
    ["reapr338"] = "L20130",
    ["redhawk44"] = "V00200",
    ["regulator"] = "D10202",
    ["remington700"] = "N00220",
    ["remington870"] = "H01100",
    ["rgd5he"] = "G00212",
    ["rgnudzs"] = "G01002",
    ["rgoudzs"] = "G02102",
    ["rh44"] = "V00200",
    ["ritualsickle"] = "K01201",
    ["rm277"] = "B12122",
    ["rolyhg"] = "G02232",
    ["ropodshotty"] = "H00222",
    ["rpk"] = "L21221",
    ["rpk12"] = "L10120",
    ["rpk16"] = "L02122",
    ["rpk74"] = "L02220",
    ["rsh12"] = "D12200",
    ["rsquared"] = "V02002",
    ["ruger1022"] = "D02221",
    ["sa58osw"] = "D00102",
    ["sa58spr"] = "D10100",
    ["saiga12"] = "H01132",
    ["saiga12u"] = "H01030",
    ["saigasar"] = "D02131",
    ["saltyweasel"] = "C10020",
    ["sass308"] = "D11101",
    ["sawedoff"] = "H01101",
    ["scarh"] = "B10221",
    ["scarhamr"] = "L22022",
    ["scarl"] = "R12120",
    ["scarpdw"] = "S12022",
    ["scarsc"] = "C02120",
    ["scarssr"] = "D00122",
    ["scarul"] = "B12022",
    ["scls1gang"] = "T02211",
    ["scls2id"] = "K00120",
    ["scls3drastic"] = "T02122",
    ["scls4maliciousintent"] = "T00131",
    ["scoutrifle"] = "N01220",
    ["scx12"] = "H02221",
    ["semtex"] = "G00200",
    ["serbushotgun"] = "H02101",
    ["sfg50"] = "N01220",
    ["shak12"] = "B11121",
    ["skorpion"] = "S11202",
    ["sks"] = "D00222",
    ["sl8"] = "D02102",
    ["slaybells"] = "K01030",
    ["sledgehammer"] = "T00122",
    ["sleighbells"] = "K01232",
    ["smx10"] = "S01100",
    ["smx9"] = "S02200",
    ["smx910"] = "S12101",
    ["smx9k"] = "S02002",
    ["smx9sd"] = "S02000",
    ["sparkler"] = "K00101",
    ["spas12"] = "H00102",
    ["spearlt"] = "R01001",
    ["sr3m"] = "C10120",
    ["stakeout"] = "H01000",
    ["starlisfunpost"] = "K00032",
    ["stevensdb"] = "H01221",
    ["steyrscout"] = "N01220",
    ["stg44"] = "R00220",
    ["stg59h"] = "B11200",
    ["stg89c"] = "D11202",
    ["stickgrenade"] = "K00120",
    ["stoner96"] = "L12100",
    ["stopper"] = "T02122",
    ["streiter"] = "K00000",
    ["stungun"] = "K02011",
    ["stylisbrush"] = "T01211",
    ["sugarweasel"] = "C10020",
    ["supershorty"] = "H02101",
    ["svk12"] = "D01121",
    ["svk12e"] = "D01121",
    ["sweeper"] = "T00212",
    ["t13impact"] = "G00230",
    ["tacticalspatula"] = "K00020",
    ["tanto"] = "K02001",
    ["tanzaniteblade"] = "K01110",
    ["tanzanitepick"] = "K01202",
    ["tar21"] = "R02022",
    ["taser"] = "K02011",
    ["tec9"] = "S00200",
    ["terminator12g"] = "H01102",
    ["theaxe"] = "T00021",
    ["thecountdown"] = "K01211",
    ["thefix"] = "N00220",
    ["thunder"] = "N01222",
    ["timberwolf"] = "N02220",
    ["titaniumfal"] = "B10000",
    ["tomahawk"] = "K01221",
    ["tommygun"] = "S12002",
    ["toonblade"] = "K02101",
    ["toygun"] = "K02202",
    ["toym1911"] = "P02001",
    ["trainingbayonet"] = "T02211",
    ["trenchknife"] = "K01130",
    ["trenchmace"] = "K02130",
    ["trg42"] = "N02221",
    ["type20"] = "R00221",
    ["type771frag"] = "G01232",
    ["type88"] = "R22221",
    ["typewriter"] = "S22000",
    ["u41622"] = "P10022",
    ["uar"] = "R11221",
    ["uara1"] = "R11220",
    ["uara3"] = "C10121",
    ["uara3m2"] = "D02122",
    ["uara3para"] = "S02122",
    ["uarhbar"] = "L00121",
    ["uchiwa"] = "K00220",
    ["ukulele"] = "T02202",
    ["ump45"] = "S02100",
    ["usas12"] = "H00031",
    ["usc"] = "P01200",
    ["utilityknife"] = "K02212",
    ["uzi"] = "S02200",
    ["v40mini"] = "G02120",
    ["vector45"] = "S11201",
    ["vhsd2"] = "R10120",
    ["virtus"] = "C01101",
    ["vks"] = "N00220",
    ["voidstaff"] = "T01021",
    ["vssvintorez"] = "D12220",
    ["vz806"] = "R00110",
    ["vz806br"] = "B12111",
    ["vz806pps"] = "D11111",
    ["vz808"] = "R00210",
    ["wa2000"] = "N02222",
    ["warfan"] = "K00030",
    ["warhammer"] = "T01201",
    ["worldbuster"] = "T02011",
    ["x46a2"] = "S02100",
    ["x95r"] = "C12121",
    ["x95smg"] = "S11120",
    ["xm633doe"] = "S11122",
    ["zerocutter"] = "T02230",
    ["zip22"] = "P01202",
    ["zirconslamsickle"] = "T02000",
    ["zircontrident"] = "T00232",
    ["zweihander"] = "T02022",
}

local ICON_WIDTH, ICON_HEIGHT = 34, 14
local iconCache = {}

local function buildIcon(spec)
    local cls = string.sub(spec, 1, 1)
    local m = tonumber(string.sub(spec, 2, 2)) or 0
    local st = tonumber(string.sub(spec, 3, 3)) or 0
    local op = tonumber(string.sub(spec, 4, 4)) or 0
    local ln = tonumber(string.sub(spec, 5, 5)) or 0
    local fx = tonumber(string.sub(spec, 6, 6)) or 0
    local r = {}
    local function R(x, y, w, h) r[#r + 1] = { x, y, w, h } end
    local y0 = 4

    if cls == "R" or cls == "C" or cls == "B" or cls == "D" then
        local stock = st == 0 and 0 or (cls == "C" and 4 or 6)
        local hand = math.min(8, 5 + ln + (cls == "D" and 2 or 0) + (cls == "B" and 1 or 0) - (cls == "C" and 1 or 0))
        local barrel = 4 + ln + (cls == "D" and 1 or 0)
        local recv = 9
        if st == 1 then R(0, y0, stock, 1) R(0, y0 + 2, stock, 1) R(0, y0, 1, 3)
        elseif st == 2 then R(0, y0, stock, 3) R(0, y0, 1, 4) end
        local x = stock
        R(x, y0, recv, 3)
        R(x + recv, y0 + 1, hand, 2)
        R(x + recv + hand, y0 + 1, barrel, 1)
        R(x + recv + hand + barrel - 1, y0, 1, 3)
        R(x + recv + hand + barrel - 3, y0 - 1, 1, 1)
        R(x + 1, y0 - 1, 1, 1)
        R(x + 2, y0 + 3, 2, 3)
        R(x + 4, y0 + 3, 2, 1)
        if m == 0 then R(x + 6, y0 + 3, 2, 5)
        elseif m == 1 then R(x + 6, y0 + 3, 2, 3) R(x + 7, y0 + 6, 2, 3)
        elseif m == 2 then R(x + 5, y0 + 3, 5, 5) end
        if op == 1 then R(x + 3, y0 - 2, 4, 2)
        elseif op == 2 then R(x + 1, y0 - 3, 9, 2) R(x + 1, y0 - 1, 1, 1) R(x + 9, y0 - 1, 1, 1) end
        if fx == 1 then R(x + recv + 2, y0 + 3, 1, 2) end
    elseif cls == "S" then
        local stock = st == 0 and 0 or 4
        if st == 1 then R(0, y0 + 1, stock, 1) R(0, y0, 1, 3) elseif st == 2 then R(0, y0, stock, 3) end
        local x = stock
        R(x, y0, 11, 3)
        if fx == 2 then R(x + 11, y0, 6 + ln, 3) else R(x + 11, y0 + 1, 4 + ln, 1) end
        R(x + 1, y0 - 1, 1, 1)
        R(x + 2, y0 + 3, 2, 3)
        R(x + 4, y0 + 3, 2, 1)
        if m == 0 then R(x + 7, y0 + 3, 2, 6)
        elseif m == 1 then R(x + 7, y0 + 3, 2, 4) R(x + 8, y0 + 7, 2, 3)
        elseif m == 2 then R(x + 5, y0 + 3, 5, 5) end
        if op ~= 0 then R(x + 3, y0 - 2, 4, 2) end
    elseif cls == "L" then
        R(0, y0, 6, 3) R(0, y0, 1, 4)
        R(6, y0, 10, 4)
        R(16, y0 + 1, 8, 2)
        R(24, y0 + 1, 4 + ln, 1)
        R(27 + ln, y0, 1, 3)
        R(21, y0 + 3, 1, 5) R(25, y0 + 3, 1, 5)
        if m == 0 then R(9, y0 + 4, 6, 5) elseif m == 1 then R(9, y0 + 4, 6, 3) R(10, y0 + 7, 5, 3) else R(8, y0 + 4, 6, 6) end
        R(11, y0 - 2, 6, 1) R(11, y0 - 2, 1, 2) R(16, y0 - 2, 1, 2)
        R(7, y0 + 4, 2, 3)
    elseif cls == "H" then
        if st == 2 then R(0, y0 + 1, 7, 3) R(0, y0 + 1, 1, 4)
        elseif st == 1 then R(0, y0 + 1, 7, 1) R(0, y0 + 3, 7, 1) R(0, y0 + 1, 1, 3) end
        R(7, y0, 9, 3)
        local len = 10 + ln
        R(16, y0, len, 1)
        R(16, y0 + 2, len - 3, 1)
        R(17, y0 + 1, 5, 3)
        R(9, y0 + 3, 2, 3)
        R(15 + len, y0 - 1, 1, 1)
        if op == 1 then R(10, y0 - 1, 3, 1) end
    elseif cls == "N" then
        R(0, y0 + 1, 9, 3) R(2, y0, 5, 1)
        R(9, y0 + 1, 8, 3)
        R(17, y0 + 2, 13 + ln, 1)
        R(29 + ln, y0 + 1, 2, 3)
        R(10, y0 - 2, 11, 2) R(9, y0 - 3, 2, 4) R(19, y0 - 3, 2, 4)
        R(23, y0 + 3, 1, 5)
        R(12, y0 + 4, 2, 3)
    elseif cls == "P" then
        local len = 12 + ln
        R(6, 3, len, 3)
        R(6 + len, 4, 1, 1)
        R(7, 6, len - 3, 1)
        R(7, 7, 4, 3) R(6, 10, 4, 3)
        R(11, 7, 3, 1) R(13, 7, 1, 2)
        R(6, 2, 1, 1) R(5 + len, 2, 1, 1)
        if op == 1 then R(9, 1, 4, 2) end
        if fx == 1 then R(7 + len, 3, 2, 2) end
    elseif cls == "V" then
        local len = 8 + ln * 2
        R(8, 3, 9, 4)
        R(12, 2, 5, 6)
        R(17, 3, len, 2)
        R(17, 2, len, 1)
        R(16 + len, 2, 1, 4)
        R(15 + len, 1, 1, 1)
        R(7, 2, 2, 2)
        R(7, 7, 3, 3) R(6, 10, 4, 3)
        R(11, 7, 1, 2)
    elseif cls == "K" then
        local blade = 7 + ln * 2
        R(0, 5, 8, 3) R(0, 4, 1, 5)
        R(8, 3, 1, 7)
        R(9, 4, blade, 3)
        R(9 + blade, 5, 2, 2)
        R(11 + blade, 6, 2, 1)
        if fx == 1 then R(10, 3, math.max(blade - 2, 2), 1) end
    elseif cls == "T" then
        if fx == 1 then
            R(0, 6, 28, 1) R(28, 4, 4, 5) R(32, 6, 2, 1)
        elseif fx == 2 then
            R(0, 6, 26, 1) R(24, 2, 5, 9) R(29, 3, 2, 7) R(31, 4, 1, 5)
        else
            R(0, 5, 9, 3) R(0, 4, 1, 5)
            R(9, 2, 2, 10)
            R(11, 4, 20, 4) R(31, 5, 2, 2)
        end
    elseif cls == "G" then
        if fx == 1 then
            R(13, 3, 8, 10) R(13, 2, 8, 1) R(15, 1, 4, 1)
            R(22, 2, 5, 1)
        else
            R(12, 5, 10, 8) R(11, 6, 12, 6)
            R(15, 3, 4, 2)
            R(19, 2, 7, 1) R(23, 3, 1, 7)
            R(11, 2, 3, 1) R(11, 2, 1, 3)
        end
    end
    return r
end

local function iconFor(weaponName)
    if not weaponName then return nil end
    local key = string.lower(tostring(weaponName))
    key = string.gsub(key, "[^%w]", "")
    local cached = iconCache[key]
    if cached ~= nil then return cached or nil end
    local spec = ICON_SPECS[key]
    if not spec then
        iconCache[key] = false
        return nil
    end
    local rects = buildIcon(spec)
    iconCache[key] = rects
    return rects
end


-- ---------------------------------------------------------------- drawing pools
local LIST_KEYS = { glowSquares = true, hpStrips = true, innerCorners = true, iconRects = true, iconShadow = true, strips = true, sides = true, outerCorners = true, innerCorners = true, glowCorners = true, corners = true, bones = true, boneShadow = true }

local function makeEsp()
    local function label() return newLabel() end
    return {
        fill = newDrawing("Square", { Filled = true, ZIndex = 1 }),
        outer = newDrawing("Square", { Thickness = 1, Filled = false, Color = BLACK, ZIndex = 2 }),
        inner = newDrawing("Square", { Thickness = 1, Filled = false, Color = BLACK, ZIndex = 2 }),
        box = newDrawing("Square", { Thickness = 1, Filled = false, ZIndex = 3 }),
        name = label(), dist = label(), weapon = label(), hpText = label(), arrowText = label(),
        hpBack = newDrawing("Square", { Filled = true, Color = BLACK, ZIndex = 4 }),
        hpTrail = newDrawing("Square", { Filled = true, Color = WHITE, ZIndex = 5 }),
        hpFill = newDrawing("Square", { Filled = true, ZIndex = 6 }),
        tracer = newDrawing("Line", { Thickness = 1, ZIndex = 2 }),
        dot = newDrawing("Circle", { Thickness = 1, NumSides = 20, Filled = false, ZIndex = 5 }),
        arrow = newDrawing("Triangle", { Filled = true, ZIndex = 6 }),
        arrowEdge = newDrawing("Triangle", { Filled = false, Thickness = 1, Color = BLACK, ZIndex = 5 }),
        face = false,
    }
end

local function ensureList(object, key, count, kind, props)
    local list = object[key]
    if not list then
        list = {}
        object[key] = list
    end
    for index = #list + 1, count do
        list[index] = newDrawing(kind, props)
    end
    return list
end

local function eachDrawing(object, fn)
    for key, value in pairs(object) do
        if LIST_KEYS[key] then
            for _, inner in ipairs(value) do fn(inner) end
        elseif key ~= "face" and type(value) ~= "number" then
            fn(value)
        end
    end
end

local function hideEsp(object)
    if not object then return end
    eachDrawing(object, function(drawing) if drawing then drawing.Visible = false end end)
end

local function destroyEsp(object)
    if not object then return end
    eachDrawing(object, removeDrawing)
end

-- ---------------------------------------------------------------- skeleton
-- The game's third person rig has fixed part sizes, so every joint is a fixed offset inside its part (scaled by the real size)
local REF_SIZES = {
    Head = Vector3.new(2, 1, 1), Torso = Vector3.new(2, 2, 1),
    ["Left Arm"] = Vector3.new(1, 2, 1), ["Right Arm"] = Vector3.new(1, 2, 1),
    ["Left Leg"] = Vector3.new(1, 2, 1), ["Right Leg"] = Vector3.new(1, 2, 1),
}
local JOINTS = {
    head = { "Head", Vector3.new(0, 0, 0) },
    neck = { "Torso", Vector3.new(0, 0.8, 0) },
    pelvis = { "Torso", Vector3.new(0, -0.7, 0) },
    lShoulder = { "Left Arm", Vector3.new(0, 0.5, 0) },
    lHand = { "Left Arm", Vector3.new(0, -0.7, 0) },
    rShoulder = { "Right Arm", Vector3.new(0, 0.5, 0) },
    rHand = { "Right Arm", Vector3.new(0, -0.7, 0) },
    lHip = { "Left Leg", Vector3.new(0, 0.7, 0) },
    lFoot = { "Left Leg", Vector3.new(0, -0.7, 0) },
    rHip = { "Right Leg", Vector3.new(0, 0.7, 0) },
    rFoot = { "Right Leg", Vector3.new(0, -0.7, 0) },
}
local BONES = {
    { "head", "neck" }, { "neck", "pelvis" },
    { "neck", "lShoulder" }, { "neck", "rShoulder" },
    { "pelvis", "lHip" }, { "pelvis", "rHip" },
    { "lShoulder", "lHand" }, { "rShoulder", "rHand" },
    { "lHip", "lFoot" }, { "rHip", "rFoot" },
}

local function bonePoints(hash)
    local head, torso = hash.Head, hash.Torso
    if not (head and torso and head.Parent and torso.Parent) then return nil end
    local center = torso.Position
    local points = {}
    for name, joint in pairs(JOINTS) do
        local part = hash[joint[1]]
        if part and part.Parent and (part.Position - center).Magnitude < 10 then
            local ref = REF_SIZES[joint[1]]
            local size = part.Size
            local offset = Vector3.new(joint[2].X * size.X / ref.X, joint[2].Y * size.Y / ref.Y, joint[2].Z * size.Z / ref.Z)
            points[name] = part.CFrame:PointToWorldSpace(offset)
        end
    end
    return points
end

local function project(cam, position)
    local point = cam:WorldToViewportPoint(position)
    return Vector2.new(point.X, point.Y), point.Z > 0, point.Z
end

-- screen rectangle of the whole character
local function screenBounds(cam, record, tight)
    if not tight then
        local topPoint, topOn = project(cam, record.head.Position + Vector3.new(0, 0.9, 0))
        local lowest = record.torso.Position.Y
        for _, legName in ipairs({ "Left Leg", "Right Leg" }) do
            local leg = record.hash[legName]
            if leg and leg.Parent and leg.Position.Y - leg.Size.Y * 0.5 < lowest then lowest = leg.Position.Y - leg.Size.Y * 0.5 end
        end
        local bottomPoint, bottomOn = project(cam, Vector3.new(record.torso.Position.X, lowest, record.torso.Position.Z))
        if not (topOn and bottomOn) then return nil end
        local height = math.abs(bottomPoint.Y - topPoint.Y)
        local width = height * 0.8
        return (topPoint.X + bottomPoint.X) * 0.5 - width * 0.5, math.min(topPoint.Y, bottomPoint.Y), width, height
    end
    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
    for _, name in ipairs(PART_NAMES) do
        local part = record.hash[name]
        if part and part.Parent and (part.Position - record.torso.Position).Magnitude < 10 then
            local cframe, half = part.CFrame, part.Size * 0.5
            for _, sx in ipairs({ -1, 1 }) do
                for _, sy in ipairs({ -1, 1 }) do
                    for _, sz in ipairs({ -1, 1 }) do
                        local point, front = project(cam, cframe:PointToWorldSpace(Vector3.new(half.X * sx, half.Y * sy, half.Z * sz)))
                        if not front then return nil end
                        if point.X < minX then minX = point.X end
                        if point.X > maxX then maxX = point.X end
                        if point.Y < minY then minY = point.Y end
                        if point.Y > maxY then maxY = point.Y end
                    end
                end
            end
        end
    end
    if minX == math.huge then return nil end
    return minX - 2, minY - 2, maxX - minX + 4, maxY - minY + 4
end

local function setText(drawing, text, size, color, position, alpha, outline)
    if not drawing then return end
    drawing.Text, drawing.Size, drawing.Color, drawing.Position = text, size, color, position
    drawing.Transparency, drawing.Outline, drawing.Visible = alpha, outline, true
end

local function clampRange(value, low, high)
    if high < low then return low end
    return math.clamp(value, low, high)
end

local function drawLine(line, from, to, color, thickness, alpha)
    if not line then return end
    line.From, line.To, line.Color = from, to, color
    line.Thickness, line.Transparency, line.Visible = thickness, alpha, true
end

-- ---------------------------------------------------------------- chams
-- Every player gets a private model of clone parts that follow the real body parts. The adornments and the highlight outline
-- are attached to the clones, so nothing is ever added to the real character.
local function headDimensions(head)
    local size = head.Size
    local mesh = head:FindFirstChildOfClass("SpecialMesh")
    if mesh then size = Vector3.new(size.X * mesh.Scale.X, size.Y * mesh.Scale.Y, size.Z * mesh.Scale.Z) end
    return math.min(size.X, size.Z) / 2, size.Y
end

local function newAdornment(clone, alwaysOnTop, zIndex, round)
    local adornment = Instance.new(round and "CylinderHandleAdornment" or "BoxHandleAdornment")
    adornment.Adornee = clone
    adornment.AlwaysOnTop = alwaysOnTop
    adornment.ZIndex = zIndex
    adornment.AdornCullingMode = Enum.AdornCullingMode.Never
    if round then adornment.CFrame = CFrame.new(Vector3.new(0, 0, 0), Vector3.new(0, 90, 0)) end
    adornment.Parent = clone
    return adornment
end

local function makeClone(model, name)
    local clone = Instance.new("Part")
    clone.Name = randomName()
    clone.Anchored = true
    clone.CanCollide = false
    clone.CanTouch = false
    clone.CanQuery = false
    clone.CastShadow = false
    clone.Massless = true
    clone.Material = Enum.Material.SmoothPlastic
    clone.Transparency = 0.99
    clone.Size = Vector3.new(1, 1, 1)
    clone.Parent = model
    return clone
end

local function destroyPair(pair)
    pcall(function() pair.clone:Destroy() end)
end

local function clearChams(player)
    local data = adornData[player]
    if not data then return end
    if data.highlight then pcall(function() data.highlight:Destroy() end) end
    pcall(function() data.model:Destroy() end)
    adornData[player] = nil
end

local function updateChams(record, wanted, ctx)
    local player = record.player
    if not wanted then
        clearChams(player)
        return
    end
    adornFolder = ensureFolder(adornFolder)
    if not adornFolder then return end

    local data = adornData[player]
    if data and (data.hash ~= record.hash or not data.model.Parent) then
        clearChams(player)
        data = nil
    end
    if not data then
        local model = Instance.new("Model")
        model.Name = randomName()
        model.Parent = adornFolder
        data = { hash = record.hash, model = model, parts = {} }
        adornData[player] = data
    end

    local visibleColor = record.override or ctx.chamVis
    local signature = table.concat({
        tostring(ctx.chamHid), ctx.chamHidT, ctx.chamVisT, ctx.chamThick, tostring(ctx.chamGlow),
        ctx.chamGlowSize, tostring(ctx.chamRound), ctx.chamHead, tostring(visibleColor),
        tostring(ctx.adornOn),
    }, "|")

    for _, name in ipairs(PART_NAMES) do
        local part = record.hash[name]
        local pair = data.parts[name]
        if pair and (pair.source ~= part or not pair.clone.Parent or (name == "Head" and pair.round ~= ctx.chamRound)) then
            destroyPair(pair)
            data.parts[name] = nil
            pair = nil
        end
        if part and part.Parent then
            local round = ctx.chamRound and name == "Head"
            if not pair then
                local clone = makeClone(data.model, name)
                pair = {
                    source = part, clone = clone, round = round,
                    behind = newAdornment(clone, true, 1, round),
                    visible = newAdornment(clone, false, -1, round),
                }
                data.parts[name] = pair
            end
            pair.clone.CFrame = part.CFrame
            local size = part.Size
            if pair.signature ~= signature or pair.partSize ~= size then
                pair.signature, pair.partSize = signature, size
                local thickness = ctx.chamThick
                pair.clone.Size = size + Vector3.new(thickness, thickness, thickness)
                if round then
                    local radius, height = headDimensions(part)
                    radius, height = radius * ctx.chamHead, height * ctx.chamHead
                    pair.behind.Radius, pair.behind.Height = radius, height
                    pair.visible.Radius, pair.visible.Height = radius + thickness / 2, height + thickness
                else
                    pair.behind.Size = size
                    pair.visible.Size = size + Vector3.new(thickness, thickness, thickness)
                end
                pair.behind.Color3, pair.behind.Transparency = ctx.chamHid, ctx.chamHidT
                pair.visible.Color3 = visibleColor
                pair.visible.AlwaysOnTop = ctx.chamGlow
                pair.visible.Transparency = ctx.chamGlow and (ctx.chamVisT / ctx.chamGlowSize) or ctx.chamVisT
                pair.behind.Visible = ctx.adornOn and ctx.chamHidOn
                pair.visible.Visible = ctx.adornOn and ctx.chamVisOn
            end
        end
    end

    if ctx.lineOn then
        local highlight = data.highlight
        if not highlight or not highlight.Parent then
            highlight = Instance.new("Highlight")
            highlight.Name = randomName()
            highlight.FillTransparency = 1
            highlight.Adornee = data.model
            highlight.Parent = adornFolder
            data.highlight = highlight
        end
        highlight.OutlineColor = record.override or ctx.lineColor
        highlight.OutlineTransparency = ctx.lineT
        highlight.DepthMode = ctx.lineWalls and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
        highlight.Enabled = true
    elseif data.highlight then
        pcall(function() data.highlight:Destroy() end)
        data.highlight = nil
    end
end

onUnload(function()
    for player in pairs(adornData) do clearChams(player) end
    if adornFolder then pcall(function() adornFolder:Destroy() end) end
end)
track(Players.PlayerRemoving:Connect(function(player)
    clearChams(player)
end))

-- ---------------------------------------------------------------- per player drawing
local GLOW_LAYERS = 4
local CORNERS = { { 0, 0, 1, 1 }, { 1, 0, -1, 1 }, { 0, 1, 1, -1 }, { 1, 1, -1, -1 } }

local function drawPlayer(cam, object, state, record, cfg, ctx, now, dt, distance, origin)
    local alpha = state.alpha * ctx.opacity
    if ctx.fade then alpha *= math.clamp(1 - (distance / ctx.maxDistance) ^ 2 * 0.7, 0.3, 1) end
    if alpha <= 0.01 then return end
    local scale = ctx.scale
    local viewport, center = ctx.viewport, ctx.center

    local override = record.override
    local color = override or cfg.color

    local face = fontFace(ctx.fontName)
    if object.face ~= face then
        object.face = face
        for _, key in ipairs({ "name", "dist", "weapon", "hpText", "arrowText" }) do
            local text = object[key]
            if text then pcall(function() text.FontFace = face end) end
        end
    end

    local torsoPoint, torsoOn = project(cam, record.torso.Position)
    if not torsoOn then
        if cfg.arrows and object.arrow then
            local relative = cam.CFrame:PointToObjectSpace(record.torso.Position)
            local angle = math.atan2(relative.X, -relative.Z)
            local direction = Vector2.new(math.sin(angle), -math.cos(angle))
            local side = Vector2.new(-direction.Y, direction.X)
            local size = cfg.arrowSize * scale
            local pulse = 1 + math.sin(now * 5) * 0.06
            local anchor = center + direction * cfg.arrowRadius * scale
            local tip = anchor + direction * size * pulse
            local left = anchor - direction * size * 0.5 + side * size * 0.6
            local right = anchor - direction * size * 0.5 - side * size * 0.6
            for _, triangle in ipairs({ object.arrow, object.arrowEdge }) do
                triangle.PointA, triangle.PointB, triangle.PointC = tip, left, right
                triangle.Transparency, triangle.Visible = alpha * cfg.arrowA, true
            end
            object.arrow.Color = override or cfg.arrowColor
            if cfg.arrowText then
                local text = string.format("%s  %dm", record.name, math.floor(distance * 0.28))
                setText(object.arrowText, text, (cfg.text - 2) * scale, override or cfg.arrowColor, anchor + direction * (size + 12 * scale) - Vector2.new(0, cfg.text * scale * 0.5), alpha * cfg.arrowA, true)
            end
        end
        return
    end

    local left, top, width, height = screenBounds(cam, record, cfg.tight)
    if not left then return end
    local centerX = left + width * 0.5
    local right, bottom = left + width, top + height
    local position, size = Vector2.new(left, top), Vector2.new(width, height)
    local thickness = cfg.thick * scale
    local o = thickness * 0.5 + 0.5
    local boxOn = cfg.box ~= "Off"
    local gradOn = ctx.gradOn and not override
    local glowColor = override or ctx.glowColor
    local glowAlpha = 1 - ctx.glowT

    -- fill
    if cfg.fillOn and boxOn then
        local fillAlpha = (1 - cfg.fillT) * alpha
        if gradOn and ctx.gradFill then
            local strips = ensureList(object, "strips", STRIPS, "Square", { Filled = true, ZIndex = 1 })
            local stripHeight = height / STRIPS
            for index = 1, STRIPS do
                local strip = strips[index]
                if strip then
                    strip.Position = Vector2.new(left, top + (index - 1) * stripHeight)
                    strip.Size = Vector2.new(width, stripHeight + 0.5)
                    strip.Color = ctx.gradA:Lerp(ctx.gradB, pingPong(ctx.phase + (index - 1) / (STRIPS - 1) * ctx.gradStretch))
                    strip.Transparency, strip.Visible = fillAlpha, true
                end
            end
        else
            object.fill.Position, object.fill.Size, object.fill.Color = position, size, override or cfg.fillColor
            object.fill.Transparency, object.fill.Visible = fillAlpha, true
        end
    end

    local function outlineColor(x)
        if gradOn and ctx.gradOutline then return ctx.gradA:Lerp(ctx.gradB, pingPong(ctx.phase + x * ctx.gradStretch)) end
        return color
    end

    -- box
    if cfg.box == "Full" then
        if cfg.glow then
            local layers = ensureList(object, "glowSquares", GLOW_LAYERS, "Square", { Filled = false, ZIndex = 1 })
            for index = 1, GLOW_LAYERS do
                local layer = layers[index]
                if layer then
                    layer.Position, layer.Size, layer.Color = position, size, glowColor
                    layer.Thickness = thickness + ctx.glowSize * 2 * index / GLOW_LAYERS
                    layer.Transparency, layer.Visible = alpha * glowAlpha * 0.22, true
                end
            end
        end
        if cfg.outlineOn then
            object.outer.Position, object.outer.Size = position - Vector2.new(o, o), size + Vector2.new(o * 2, o * 2)
            object.outer.Transparency, object.outer.Visible = alpha * cfg.boxA, true
            if width > o * 4 and height > o * 4 then
                object.inner.Position, object.inner.Size = position + Vector2.new(o, o), size - Vector2.new(o * 2, o * 2)
                object.inner.Transparency, object.inner.Visible = alpha * cfg.boxA, true
            end
        end
        if gradOn and ctx.gradOutline then
            local sides = ensureList(object, "sides", 4, "Line", { ZIndex = 3 })
            local corners = { Vector2.new(left, top), Vector2.new(right, top), Vector2.new(right, bottom), Vector2.new(left, bottom) }
            for index = 1, 4 do
                drawLine(sides[index], corners[index], corners[index % 4 + 1], outlineColor((index - 1) / 4), thickness, alpha * cfg.boxA)
            end
        else
            object.box.Position, object.box.Size, object.box.Color = position, size, color
            object.box.Thickness, object.box.Transparency, object.box.Visible = thickness, alpha * cfg.boxA, true
        end
    elseif cfg.box == "Corners" then
        local length = math.min(width, height) * 0.28
        local outerLines = cfg.outlineOn and ensureList(object, "outerCorners", 8, "Line", { Thickness = 1, Color = BLACK, ZIndex = 2 })
        local glowLines = cfg.glow and ensureList(object, "glowCorners", 8 * GLOW_LAYERS, "Line", { ZIndex = 1 })
        local innerLines = cfg.outlineOn and ensureList(object, "innerCorners", 8, "Line", { Thickness = 1, Color = BLACK, ZIndex = 2 })
        local lines = ensureList(object, "corners", 8, "Line", { ZIndex = 3 })
        for index, corner in ipairs(CORNERS) do
            local cx, cy = left + corner[1] * width, top + corner[2] * height
            local sx, sy = corner[3], corner[4]
            local lineColor = outlineColor((index - 1) / 4)
            local hFrom, hTo = Vector2.new(cx, cy), Vector2.new(cx + sx * length, cy)
            local vFrom, vTo = Vector2.new(cx, cy), Vector2.new(cx, cy + sy * length)
            local h, v = index * 2 - 1, index * 2
            if glowLines then
                for layer = 1, GLOW_LAYERS do
                    local glowThickness = thickness + ctx.glowSize * 2 * layer / GLOW_LAYERS
                    drawLine(glowLines[(layer - 1) * 8 + h], hFrom, hTo, glowColor, glowThickness, alpha * glowAlpha * 0.22)
                    drawLine(glowLines[(layer - 1) * 8 + v], vFrom, vTo, glowColor, glowThickness, alpha * glowAlpha * 0.22)
                end
            end
            if outerLines then
                drawLine(outerLines[h], Vector2.new(cx - sx * o, cy - sy * o), Vector2.new(cx + sx * length, cy - sy * o), BLACK, 1, alpha * cfg.boxA)
                drawLine(outerLines[v], Vector2.new(cx - sx * o, cy - sy * o), Vector2.new(cx - sx * o, cy + sy * length), BLACK, 1, alpha * cfg.boxA)
            end
            if innerLines then
                drawLine(innerLines[h], Vector2.new(cx + sx * o, cy + sy * o), Vector2.new(cx + sx * length, cy + sy * o), BLACK, 1, alpha * cfg.boxA)
                drawLine(innerLines[v], Vector2.new(cx + sx * o, cy + sy * o), Vector2.new(cx + sx * o, cy + sy * length), BLACK, 1, alpha * cfg.boxA)
            end
            drawLine(lines[h], hFrom, hTo, lineColor, thickness, alpha * cfg.boxA)
            drawLine(lines[v], vFrom, vTo, lineColor, thickness, alpha * cfg.boxA)
        end
    end

    -- text
    local textSize = cfg.text * scale
    local barGap = cfg.hpWidth * scale + 4
    local topOffset = (cfg.health and cfg.hpPos == "Top") and barGap or 0
    local bottomOffset = (cfg.health and cfg.hpPos == "Bottom") and barGap or 0
    if cfg.name then
        setText(object.name, record.name, textSize, override or cfg.nameColor, Vector2.new(centerX, top - textSize - 3 - topOffset), alpha * cfg.nameA, cfg.textOutline)
    end
    local lineY = bottom + 2 + bottomOffset
    if cfg.distance then
        setText(object.dist, string.format("%dm", math.floor(distance * 0.28)), textSize - 1, override or cfg.distColor, Vector2.new(centerX, lineY), alpha * cfg.distA, cfg.textOutline)
        lineY += textSize
    end
    if cfg.weapon and record.weaponName then
        setText(object.weapon, tostring(record.weaponName), textSize - 1, override or cfg.weaponColor, Vector2.new(centerX, lineY), alpha * cfg.weaponA, cfg.textOutline)
        lineY += textSize
    end
    if cfg.weaponIcon and record.weaponName then
        local rects = iconFor(record.weaponName)
        if rects then
            local unit = math.max(1, math.floor(textSize / 6))
            local startX = math.floor(centerX - ICON_WIDTH * unit * 0.5)
            local startY = math.floor(lineY + 1)
            local pieces = ensureList(object, "iconRects", 18, "Square", { Filled = true, ZIndex = 7 })
            local shadows = cfg.outlineOn and ensureList(object, "iconShadow", 18, "Square", { Filled = true, Color = BLACK, ZIndex = 6 })
            for index, rect in ipairs(rects) do
                local x, y, w, h = startX + rect[1] * unit, startY + rect[2] * unit, rect[3] * unit, rect[4] * unit
                local piece = pieces[index]
                if piece then
                    piece.Position, piece.Size, piece.Color = Vector2.new(x, y), Vector2.new(w, h), override or cfg.weaponIconColor
                    piece.Transparency, piece.Visible = alpha * cfg.iconA, true
                end
                local shadow = shadows and shadows[index]
                if shadow then
                    shadow.Position, shadow.Size = Vector2.new(x - 1, y - 1), Vector2.new(w + 2, h + 2)
                    shadow.Transparency, shadow.Visible = alpha * cfg.iconA, true
                end
            end
        end
    end

    -- health
    local ratio = math.clamp(record.health / math.max(record.maxHealth, 1), 0, 1)
    local healthColor
    healthColor = override or (cfg.hpDynamic and Color3.fromRGB(255, 60, 60):Lerp(Color3.fromRGB(70, 255, 110), ratio) or cfg.hpColor)
    if cfg.health then
        local shown, trail = state.hp, state.trail
        local barWidth = cfg.hpWidth * scale
        local backPosition, backSize, fillPosition, fillSize, trailPosition, trailSize
        local vertical = cfg.hpPos == "Left" or cfg.hpPos == "Right"
        local function span(amount)
            if vertical then return Vector2.new(0, height * (1 - amount)), Vector2.new(barWidth, height * amount) end
            return Vector2.new(0, 0), Vector2.new(width * amount, barWidth)
        end
        local baseX, baseY
        if vertical then
            baseX = cfg.hpPos == "Left" and left - barGap or right + 3
            baseY = top
            backPosition, backSize = Vector2.new(baseX, top - 1), Vector2.new(barWidth + 2, height + 2)
        else
            baseX = left
            baseY = cfg.hpPos == "Top" and top - barGap or bottom + 3
            backPosition, backSize = Vector2.new(left - 1, baseY), Vector2.new(width + 2, barWidth + 2)
        end
        local inset = Vector2.new(1, 1)
        local offset, extent = span(shown)
        fillPosition, fillSize = Vector2.new(baseX, baseY) + offset + inset, extent
        local trailOffset, trailExtent = span(math.max(trail, shown))
        trailPosition, trailSize = Vector2.new(baseX, baseY) + trailOffset + inset, trailExtent
        object.hpBack.Position, object.hpBack.Size, object.hpBack.Transparency, object.hpBack.Visible = backPosition, backSize, alpha * cfg.hpA * 0.8, true
        if cfg.hpTrail and trail > shown + 0.004 then
            object.hpTrail.Position, object.hpTrail.Size = trailPosition, trailSize
            object.hpTrail.Color = Color3.fromRGB(255, 255, 255)
            object.hpTrail.Transparency, object.hpTrail.Visible = alpha * cfg.hpA * 0.55, true
        end
        if gradOn and ctx.gradHealth and fillSize.X > 0 and fillSize.Y > 0 then
            local strips = ensureList(object, "hpStrips", 8, "Square", { Filled = true, ZIndex = 6 })
            for index = 1, 8 do
                local strip = strips[index]
                if strip then
                    local from, to = (index - 1) / 8, index / 8
                    if vertical then
                        strip.Position = Vector2.new(fillPosition.X, fillPosition.Y + fillSize.Y * (1 - to))
                        strip.Size = Vector2.new(fillSize.X, fillSize.Y / 8 + 0.5)
                    else
                        strip.Position = Vector2.new(fillPosition.X + fillSize.X * from, fillPosition.Y)
                        strip.Size = Vector2.new(fillSize.X / 8 + 0.5, fillSize.Y)
                    end
                    strip.Color = ctx.gradA:Lerp(ctx.gradB, pingPong(ctx.phase + from * ctx.gradStretch))
                    strip.Transparency, strip.Visible = alpha * cfg.hpA, true
                end
            end
        else
            object.hpFill.Position, object.hpFill.Size, object.hpFill.Color = fillPosition, fillSize, healthColor
            object.hpFill.Transparency, object.hpFill.Visible = alpha * cfg.hpA, true
        end
        if cfg.hpText and ratio < 0.999 then
            local textPosition
            if cfg.hpPos == "Left" then textPosition = Vector2.new(backPosition.X - 9, clampRange(fillPosition.Y - textSize * 0.5, top - 2, bottom - textSize))
            elseif cfg.hpPos == "Right" then textPosition = Vector2.new(backPosition.X + barWidth + 12, clampRange(fillPosition.Y - textSize * 0.5, top - 2, bottom - textSize))
            else textPosition = Vector2.new(left + width * shown, backPosition.Y + barWidth + 2) end
            setText(object.hpText, tostring(math.floor(record.health)), textSize - 3, WHITE, textPosition, alpha * cfg.hpA, cfg.textOutline)
        end
    end

    -- skeleton
    if cfg.skeleton then
        local points = bonePoints(record.hash)
        if points then
            local boneThickness = cfg.skeletonThick * scale
            local bones = ensureList(object, "bones", #BONES, "Line", { ZIndex = 4 })
            local shadows = cfg.skeletonOutline and ensureList(object, "boneShadow", #BONES, "Line", { Color = BLACK, ZIndex = 3 })
            local flat = override or cfg.skeletonColor
            for index, pair in ipairs(BONES) do
                local a, b = points[pair[1]], points[pair[2]]
                if a and b then
                    local pa, onA = project(cam, a)
                    local pb, onB = project(cam, b)
                    if onA and onB then
                        local boneColor = flat
                        if gradOn and ctx.gradSkeleton then
                            boneColor = ctx.gradA:Lerp(ctx.gradB, pingPong(ctx.phase + (index - 1) / #BONES * ctx.gradStretch))
                        end
                        if shadows then drawLine(shadows[index], pa, pb, BLACK, boneThickness + 2, alpha * cfg.skelA) end
                        drawLine(bones[index], pa, pb, boneColor, boneThickness, alpha * cfg.skelA)
                    end
                end
            end
        end
    end

    if cfg.head then
        local headPoint, headOn = project(cam, record.head.Position)
        if headOn then
            object.dot.Position, object.dot.Color, object.dot.Radius = headPoint, override or cfg.headColor, math.max(height * 0.07, 2)
            object.dot.Transparency, object.dot.Visible = alpha * cfg.headA, true
        end
    end

    if cfg.tracer then
        local from = Vector2.new(viewport.X * 0.5, cfg.tracerFrom == "Top" and 0 or cfg.tracerFrom == "Center" and viewport.Y * 0.5 or viewport.Y)
        object.tracer.From, object.tracer.To, object.tracer.Color = from, Vector2.new(centerX, bottom), override or cfg.tracerColor
        object.tracer.Thickness, object.tracer.Transparency, object.tracer.Visible = math.max(scale, 1), alpha * cfg.tracerA * 0.8, true
    end
end

local function stepState(state, record, want, dt, now, ctx)
    local ratio = math.clamp(record.health / math.max(record.maxHealth, 1), 0, 1)
    if not ctx.smooth then
        state.alpha = want and 1 or 0
        state.hp, state.trail = ratio, ratio
        state.lastRatio = ratio
        return
    end
    local blend = 1 - math.exp(-ctx.speed * dt)
    state.alpha += ((want and 1 or 0) - state.alpha) * blend
    if state.alpha < 0.005 then state.alpha = 0 end
    if ratio < state.lastRatio - 0.001 then state.holdUntil = now + 0.35 end
    state.lastRatio = ratio
    state.hp += (ratio - state.hp) * blend
    if ratio > state.trail then
        state.trail = ratio
    elseif now >= (state.holdUntil or 0) then
        state.trail += (ratio - state.trail) * (1 - math.exp(-3 * dt))
    end
end

local function espStep(cam, now, dt, records, origin)
    local seen = {}
    local enemyCfg, friendCfg = teamCfg(false), teamCfg(true)
    local apply = selectedSet("grad_apply", { "Box fill", "Skeleton" })
    local gradOn = readFlag("grad_on", false)
    local ctx = {
        maxDistance = readFlag("esp_dist", 1500),
        fade = readFlag("esp_fade", false),
        opacity = 1,
        scale = readFlag("esp_scale", 1),
        fontName = readFlag("esp_font", "Tahoma"),
        smooth = readFlag("esp_smooth", false),
        speed = readFlag("esp_smooth_speed", 8),
        useVisible = readFlag("esp_vis", false),
        visibleColor = readFlag("esp_vis_color", WHITE),
        markTarget = readFlag("esp_target", false),
        targetColor = readFlag("esp_target_color", WHITE),
        viewport = cam.ViewportSize,
        center = cam.ViewportSize / 2,
        gradOn = gradOn,
        gradA = readFlag("grad_a", WHITE),
        gradB = readFlag("grad_b", WHITE),
        gradStretch = readFlag("grad_stretch", 1),
        phase = now * readFlag("grad_speed", 0.25),
        glowColor = readFlag("esp_glow_color", WHITE), glowT = pickerTransparency("esp_glow_color", 0.5), glowSize = readFlag("esp_glow_size", 10),
        gradFill = apply["Box fill"], gradOutline = apply["Box outline"], gradSkeleton = apply["Skeleton"], gradHealth = apply["Health bar"],
        chamVisOn = true, chamHidOn = true,
        chamThick = readFlag("cham_thick", 0.1),
        chamGlow = readFlag("cham_glow", false), chamGlowSize = math.max(readFlag("cham_glow_size", 1.75), 1),
        chamRound = readFlag("cham_round", false), chamHead = readFlag("cham_head", 1.15),
        lineWalls = readFlag("cham_line_walls", false),
    }

    for _, record in ipairs(records) do
        local player = record.player
        seen[player] = true
        local cfg = record.enemy and enemyCfg or friendCfg
        local distance = (record.torso.Position - origin).Magnitude
        local want = cfg.enabled and distance <= ctx.maxDistance
        local object, state = espObjects[player], espState[player]
        record.override = nil
        if cfg.enabled then
            if ctx.markTarget and Aim.target == player then record.override = ctx.targetColor
            elseif record.enemy and ctx.useVisible and isVisible(record.torso, origin, now) then record.override = ctx.visibleColor end
        end

        if want and not object then
            object = makeEsp()
            espObjects[player] = object
            local ratio = math.clamp(record.health / math.max(record.maxHealth, 1), 0, 1)
            state = { alpha = ctx.smooth and 0 or 1, hp = ratio, trail = ratio, lastRatio = ratio }
            espState[player] = state
        end
        if object and state then
            stepState(state, record, want, dt, now, ctx)
            hideEsp(object)
            if state.alpha > 0.01 then
                local ok, problem = pcall(drawPlayer, cam, object, state, record, cfg, ctx, now, dt, distance, origin)
                if not ok then
                    hideEsp(object)
                    note("esp:" .. tostring(player.Name) .. tostring(problem), "esp (" .. tostring(player.Name) .. "):", problem)
                end
            end
        end

        ctx.adornOn, ctx.lineOn = cfg.chamOn, cfg.lineOn
        ctx.chamVis, ctx.chamVisT, ctx.chamHid, ctx.chamHidT = cfg.chamVis, cfg.chamVisT, cfg.chamHid, cfg.chamHidT
        ctx.lineColor, ctx.lineT = cfg.lineColor, cfg.lineT
        ctx.chamSignature = table.concat({
            tostring(cfg.chamHid), cfg.chamHidT, cfg.chamVisT, ctx.chamThick, tostring(ctx.chamGlow),
            ctx.chamGlowSize, tostring(ctx.chamRound), ctx.chamHead,
        }, "|")
        local chamWanted = cfg.enabled and (cfg.chamOn or cfg.lineOn) and record.model and record.model.Parent and distance <= ctx.maxDistance
        local ok, problem = pcall(updateChams, record, chamWanted and true or false, ctx)
        if not ok then note("cham:" .. tostring(problem), "chams:", problem) end
    end

    for player, object in pairs(espObjects) do
        if not seen[player] then
            destroyEsp(object)
            espObjects[player] = nil
            espState[player] = nil
        end
    end
    for player in pairs(adornData) do
        if not seen[player] then clearChams(player) end
    end
end

-- ============================================================ main loop
local lastClock = os.clock()
local labelClock = 0
track(RunService.RenderStepped:Connect(safe("frame", function()
    frameId += 1
    local now = os.clock()
    local dt = math.clamp(now - lastClock, 1 / 240, 0.1)
    lastClock = now

    local cam = camera()
    if not cam then return end
    refreshFilter(now)

    if readFlag("cam_fov_on", false) then
        local weapon = activeWeapon()
        if not weaponAiming(weapon) then cam.FieldOfView = readFlag("cam_fov", 85) end
    end

    if not Core.ready then
        if now - (Core.retryAt or 0) > 3 then
            Core.retryAt = now
            loadCore()
            if Core.ready then
                if PF_StatusCore then PF_StatusCore:SetText("Core: " .. Core.summary) end
                pcall(function() Library:Notify("Core " .. Core.summary, 4) end)
            end
        end
        if fovCircle then fovCircle.Visible = false end
        for _, object in pairs(espObjects) do hideEsp(object) end
        return
    end

    currentClass = weaponClass(activeWeapon())
    local records = takeSnapshot()
    local origin = cam.CFrame.Position
    local center = cam.ViewportSize / 2

    local ok, problem = pcall(legitStep, dt, cam, now, records, center)
    if not ok then note("legit" .. tostring(problem), "legit:", problem) end
    ok, problem = pcall(function()
        local gameCam = gameCamera()
        if gameCam then recoilStep(gameCam, activeWeapon(), now) end
    end)
    if not ok then note("recoil" .. tostring(problem), "recoil:", problem) end
    ok, problem = pcall(triggerStep, cam, now, records)
    if not ok then note("trigger" .. tostring(problem), "trigger:", problem) end
    ok, problem = pcall(espStep, cam, now, dt, records, origin)
    if not ok then
        for _, object in pairs(espObjects) do hideEsp(object) end
        note("esp" .. tostring(problem), "esp:", problem)
    end

    if PF_StatusTarget and now - labelClock > 0.2 then
        labelClock = now
        if PF_StatusClass then
            local text = "Class: " .. tostring(currentClass or "none")
            if currentClass then text ..= readFlag("ovr@" .. currentClass, false) and " (override)" or " (shared)" end
            if Aim.lastClassText ~= text then
                Aim.lastClassText = text
                PF_StatusClass:SetText(text)
            end
        end
        if PF_StatusRecoil then
            PF_StatusRecoil:SetText(string.format("Recoil: %.1f / %.1f deg", math.deg(Recoil.shown.X), math.deg(Recoil.shown.Y)))
        end
        local text = "Target: none"
        if Aim.target and Aim.record then
            text = string.format("Target: %s | %d hp | %dm", Aim.record.name, math.floor(Aim.record.health), math.floor((Aim.record.torso.Position - origin).Magnitude * 0.28))
        end
        if Aim.lastTargetText ~= text then
            Aim.lastTargetText = text
            PF_StatusTarget:SetText(text)
        end
    end
end)))

track(LocalPlayer.Idled:Connect(safe("afk", function()
    if not readFlag("misc_afk", true) then return end
    local virtualUser = game:GetService("VirtualUser")
    virtualUser:CaptureController()
    virtualUser:ClickButton2(Vector2.new())
end)))

onUnload(function()
    for _, object in pairs(espObjects) do destroyEsp(object) end
    espObjects = {}
    releaseTrigger()
end)

-- ============================================================ settings
do
    pcall(function()
        if makefolder and isfolder then
            if not isfolder("Aster") then makefolder("Aster") end
            if not isfolder("Aster/PhantomForces") then makefolder("Aster/PhantomForces") end
        end
    end)
    local SettingsTab, SettingsSubs = Skin.BuildSettings(LinoriaWindow, { ThemeManager = ThemeManager, SaveManager = SaveManager, Folder = "Aster/PhantomForces", Game = "configs", MenuKey = "Delete" })
    escapeUnbinds("MenuKeybind", "Delete")
    Library:SetWatermark("Aster")
    Library:SetWatermarkVisibility(true)
end

pcall(function() SaveManager:LoadAutoloadConfig() end)
if not Library.Toggled then pcall(function() Library:Toggle() end) end
Library:Notify("Aster loaded | core " .. Core.summary, 5)

end, debug.traceback)
if not __ok then
    warn("[Aster] FAILED:\n" .. tostring(__err))
end
