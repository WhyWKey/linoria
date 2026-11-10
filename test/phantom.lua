local BUILD = "phantom-1109-j"
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
    for _, name in ipairs({ "ReplicationInterface", "CharacterInterface", "CameraInterface", "PublicSettings", "network", "AudioSystem", "WeaponUtils", "ContentUtils" }) do
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
-- the game keeps every third person body part at size 0 and only uses welds for position, so real sizes are fixed values
local PART_SIZES = {
    Head = Vector3.new(2, 1, 1), Torso = Vector3.new(2, 2, 1),
    ["Left Arm"] = Vector3.new(1, 2, 1), ["Right Arm"] = Vector3.new(1, 2, 1),
    ["Left Leg"] = Vector3.new(1, 2, 1), ["Right Leg"] = Vector3.new(1, 2, 1),
}
local snapshotAll = {}
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
    snapshotAll = {}
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
        if not (torso and head) then return end
        -- the game only builds the body in the world for players on screen; the others have a stale model with no parent
        local rendered = torso:IsDescendantOf(Workspace)
        local position
        if rendered then
            local torsoPosition, headPosition = torso.Position, head.Position
            if torsoPosition ~= torsoPosition or headPosition ~= headPosition then return end
            if (headPosition - torsoPosition).Magnitude > 8 then return end
            position = torsoPosition
        else
            local okPosition, value = pcall(entry.getPosition, entry)
            if not (okPosition and typeof(value) == "Vector3" and value == value) then return end
            position = value
        end
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
        local record = {
            rendered = rendered,
            pos = position,
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
        snapshotAll[#snapshotAll + 1] = record
        if rendered then snapshot[#snapshot + 1] = record end
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

    local PERTEAM = {}
    local white = Color3.fromRGB(255, 255, 255)
    local function addTeamRows(box, friendly)
        local suffix = friendly and "@Friendly" or ""
        local function key(flag)
            if not friendly then table.insert(PERTEAM, flag) end
            return flag .. suffix
        end
        box:Toggle({ Name = "2D", Flag = key("esp_enabled"), Tooltip = "Master switch for everything in this tab" })
        box:Toggle({ Name = "Name", Flag = key("esp_name") }):Colorpicker({ Name = "Name color", Flag = key("esp_name_color"), Default = white, Alpha = 0 })
        box:Toggle({ Name = "Box", Flag = key("esp_box") }):Colorpicker({ Name = "Box color", Flag = key("esp_box_color"), Default = white, Alpha = 0 }):Colorpicker({ Name = "Box fill", Flag = key("esp_fill_color"), Default = white, Alpha = 0.88 })
        box:Toggle({ Name = "Health Bar", Flag = key("esp_hp") }):Colorpicker({ Name = "Low health", Flag = key("esp_hp_low"), Default = white, Alpha = 0 }):Colorpicker({ Name = "Full health", Flag = key("esp_hp_full"), Default = white, Alpha = 0 })
        box:Toggle({ Name = "Health Number", Flag = key("esp_hp_num") }):Colorpicker({ Name = "Number color", Flag = key("esp_hp_num_color"), Default = white, Alpha = 0 })
        box:Toggle({ Name = "Held Weapon", Flag = key("esp_weapon") }):Colorpicker({ Name = "Weapon color", Flag = key("esp_weapon_color"), Default = white, Alpha = 0 })
        box:Toggle({ Name = "Held Weapon Icon", Flag = key("esp_icon"), Tooltip = "The weapon's real model, drawn under the box" }):Colorpicker({ Name = "Icon tint", Flag = key("esp_icon_color"), Default = white, Alpha = 0 })
        box:Toggle({ Name = "Skeleton", Flag = key("esp_skeleton") }):Colorpicker({ Name = "Skeleton color", Flag = key("esp_skeleton_color"), Default = white, Alpha = 0 })
        box:Dropdown({ Name = "Flags", Flag = key("esp_flags"), Items = { "Distance", "Visible", "Target" }, Multi = true, Default = {} })
        box:Slider({ Name = "Render Distance", Flag = key("esp_dist"), Min = 50, Max = 3000, Default = 1500, Decimals = 1, Suffix = " studs" })
        box:Toggle({ Name = "Chams", Flag = key("esp_chams"), Tooltip = "Adornment chams on every body part. First picker is the visible layer, second is behind walls. Settings in the Chams tab" }):Colorpicker({ Name = "Visible", Flag = key("esp_cham_vis"), Default = white, Alpha = 0.5 }):Colorpicker({ Name = "Behind walls", Flag = key("esp_cham_hid"), Default = white, Alpha = 0.5 })
        box:Toggle({ Name = "Out of View", Flag = key("esp_oov"), Tooltip = "Arrows at the screen edge pointing at players you cannot see on screen. Settings in the Out of View tab" }):Colorpicker({ Name = "Arrow color", Flag = key("esp_oov_color"), Default = white, Alpha = 0 })
        box:Toggle({ Name = "Sound Tracker", Flag = key("esp_sound"), Tooltip = "A ring on the ground where a player makes sound. Settings in the Sound Tracker tab" }):Colorpicker({ Name = "Ring color", Flag = key("esp_sound_color"), Default = white, Alpha = 0 })
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

    local EspSettings, ColorOverrides = VisualsPage:MultiSection({ Sections = { "ESP Settings", "Color Overrides" }, Side = 1 })
    EspSettings:Dropdown({ Name = "Font", Flag = "esp_font", Items = { "Plex", "UI", "System", "Monospace" }, Default = "Plex" })
    EspSettings:Dropdown({ Name = "Box Mode", Flag = "esp_box_mode", Items = { "Static", "Dynamic" }, Default = "Static" })
    EspSettings:Slider({ Name = "Size", Flag = "esp_text", Min = 10, Max = 20, Default = 13, Decimals = 1, Suffix = " px" })
    EspSettings:Slider({ Name = "Fade Time", Flag = "esp_fade_time", Min = 0, Max = 1, Default = 0.2, Decimals = 0.01, Suffix = " s" })
    EspSettings:Dropdown({ Name = "Text Case", Flag = "esp_case", Items = { "Normal", "lower", "UPPER" }, Default = "Normal" })
    EspSettings:Slider({ Name = "Max Text Length", Flag = "esp_max_text", Min = 5, Max = 30, Default = 30, Decimals = 1 })
    EspSettings:Slider({ Name = "Max HP Visibility Cap", Flag = "esp_hp_cap", Min = 1, Max = 100, Default = 100, Decimals = 1 })
    EspSettings:Slider({ Name = "Skeleton Thickness", Flag = "esp_skel_thick", Min = 1, Max = 4, Default = 1, Decimals = 0.1, Suffix = " px" })
    EspSettings:Toggle({ Name = "Debug Print", Flag = "esp_debug", Tooltip = "Prints what the ESP is doing to the console every 3 seconds" })
    EspSettings:Toggle({ Name = "Outlines", Flag = "esp_outline", Tooltip = "Dark outline on both sides of the box, and on text, skeleton and arrows" })
    ColorOverrides:Toggle({ Name = "Visible Color", Flag = "esp_vis", Tooltip = "Enemies you can see get every feature in this color, except the behind-walls chams" }):Colorpicker({ Name = "Visible color", Flag = "esp_vis_color", Default = white })
    ColorOverrides:Toggle({ Name = "Highlight Target", Flag = "esp_target", Tooltip = "The player your aimbot is locked on gets every feature in this color, except the behind-walls chams" }):Colorpicker({ Name = "Target color", Flag = "esp_target_color", Default = white })

    local ChamSet, OovSet, SoundSet = VisualsPage:MultiSection({ Sections = { "Chams", "Out of View", "Sound Tracker" }, Side = 2 })
    ChamSet:Dropdown({ Name = "Parent", Flag = "cham_parent", Items = { "Workspace", "Part", "CoreGui" }, Default = "Workspace", Tooltip = "Where the adornments live: a folder in Workspace, inside each body part (BBOT), or CoreGui (Constant). Try another if one shows nothing" })
    ChamSet:Slider({ Name = "Layer Size", Flag = "cham_layer", Min = 0, Max = 0.5, Default = 0.05, Decimals = 0.01 })
    ChamSet:Slider({ Name = "Head Size", Flag = "cham_head", Min = 0.8, Max = 1.6, Default = 1, Decimals = 0.01 })
    ChamSet:Toggle({ Name = "Glow", Flag = "cham_glow", Tooltip = "A larger, softer layer around every body part" }):Colorpicker({ Name = "Glow color", Flag = "cham_glow_color", Default = white, Alpha = 0.7 })
    ChamSet:Slider({ Name = "Glow Size", Flag = "cham_glow_size", Min = 0.05, Max = 1, Default = 0.3, Decimals = 0.01 })
    OovSet:Slider({ Name = "Arrow Size", Flag = "oov_size", Min = 8, Max = 32, Default = 14, Decimals = 1, Suffix = " px" })
    OovSet:Slider({ Name = "Arrow Distance", Flag = "oov_radius", Min = 5, Max = 100, Default = 40, Decimals = 1, Suffix = " %", Tooltip = "How far from the center the arrows sit. 100 is the screen edge" })
    OovSet:Toggle({ Name = "Dynamic Size", Flag = "oov_dynamic_size", Tooltip = "Closer players get bigger arrows" })
    OovSet:Toggle({ Name = "Dynamic Fade", Flag = "oov_fade", Tooltip = "Far players get fainter arrows" })
    OovSet:Slider({ Name = "Fade Distance", Flag = "oov_fade_distance", Min = 20, Max = 400, Default = 150, Decimals = 1, Suffix = " m" })
    SoundSet:Slider({ Name = "Duration", Flag = "snd_duration", Min = 0.3, Max = 2, Default = 0.9, Decimals = 0.01, Suffix = " s" })
    SoundSet:Slider({ Name = "Max Radius", Flag = "snd_radius", Min = 3, Max = 12, Default = 5, Decimals = 0.1, Suffix = " studs" })
    SoundSet:Toggle({ Name = "Through Walls", Flag = "snd_walls", Tooltip = "Off hides the ring while the player is behind cover" })

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
                            local size = PART_SIZES[partName] or Vector3.new(1, 1, 1)
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
-- 2D ESP in the style of BBOT: triple-rect boxes, a thin health bar, outlined text, plain skeleton lines, edge arrows,
-- adornment chams parented to the real body parts, and footstep rings drawn from the game's own sound calls.
local FONT_IDS = { Plex = 2, UI = 0, System = 1, Monospace = 3 }
local FONT_ORDER = { "Plex", "UI", "System", "Monospace" }
local espObjects, espState = {}, {}
local adornData = {}
local sounds = {}
local lastRecords = {}
local RING_SEGMENTS = 24
local dbg = { arrows = 0, rings = 0, soundEvents = 0, soundMatched = 0, soundArgs = "none", chamsMade = 0, chamsInfo = "none", drawn = 0, errors = 0 }

local function randomName()
    local letters = {}
    for index = 1, 10 do letters[index] = string.char(math.random(97, 122)) end
    return table.concat(letters)
end

local function pickerTransparency(flag, default)
    local option = Options[flag]
    if option and type(option.Transparency) == "number" then return math.clamp(option.Transparency, 0, 1) end
    return default
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

local function lerpColor(a, b, t)
    return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end

-- ---------------------------------------------------------------- settings
local cfgCache = {}
local function teamCfg(friendly)
    local suffix = friendly and "@Friendly" or ""
    local c = cfgCache[friendly]
    if not c then c = {} cfgCache[friendly] = c end
    local function r(flag, default) return readFlag(flag .. suffix, default) end
    local function opacity(flag) return 1 - pickerTransparency(flag .. suffix, 0) end
    c.enabled = r("esp_enabled", false)
    c.distance = r("esp_dist", 1500)
    c.name, c.nameColor, c.nameA = r("esp_name", false), r("esp_name_color", WHITE), opacity("esp_name_color")
    c.box, c.boxColor, c.boxA = r("esp_box", false), r("esp_box_color", WHITE), opacity("esp_box_color")
    c.fillColor, c.fillA = r("esp_fill_color", WHITE), opacity("esp_fill_color")
    c.hp, c.hpLow, c.hpFull, c.hpA = r("esp_hp", false), r("esp_hp_low", WHITE), r("esp_hp_full", WHITE), opacity("esp_hp_full")
    c.hpNum, c.hpNumColor, c.hpNumA = r("esp_hp_num", false), r("esp_hp_num_color", WHITE), opacity("esp_hp_num_color")
    c.weapon, c.weaponColor, c.weaponA = r("esp_weapon", false), r("esp_weapon_color", WHITE), opacity("esp_weapon_color")
    c.icon, c.iconColor, c.iconA = r("esp_icon", false), r("esp_icon_color", WHITE), opacity("esp_icon_color")
    c.skeleton, c.skeletonColor, c.skeletonA = r("esp_skeleton", false), r("esp_skeleton_color", WHITE), opacity("esp_skeleton_color")
    c.flags = selectedSet("esp_flags" .. suffix, {})
    c.flagColor, c.flagA = r("esp_flags_color", WHITE), opacity("esp_flags_color")
    c.chams = r("esp_chams", false)
    c.chamVis, c.chamVisT = r("esp_cham_vis", WHITE), pickerTransparency("esp_cham_vis" .. suffix, 0.5)
    c.chamHid, c.chamHidT = r("esp_cham_hid", WHITE), pickerTransparency("esp_cham_hid" .. suffix, 0.5)
    c.oov, c.oovColor, c.oovA = r("esp_oov", false), r("esp_oov_color", WHITE), opacity("esp_oov_color")
    c.sound, c.soundColor, c.soundA = r("esp_sound", false), r("esp_sound_color", WHITE), opacity("esp_sound_color")
    return c
end

-- ---------------------------------------------------------------- weapon icons
-- Icons are the game's own weapon models, built with its own weapon code and shown in a small ViewportFrame.
local labelGui
local function elevate()
    for _, name in ipairs({ "setthreadidentity", "set_thread_identity", "setidentity", "setthreadcontext" }) do
        local fn = getgenv()[name]
        if type(fn) == "function" and pcall(fn, 7) then return true end
    end
    return false
end

local function ensureLabelGui()
    if labelGui and labelGui.Parent then return labelGui end
    elevate()
    local parents = {}
    pcall(function() parents[#parents + 1] = game:GetService("CoreGui") end)
    pcall(function() if gethui then parents[#parents + 1] = gethui() end end)
    for _, parent in ipairs(parents) do
        local gui = Instance.new("ScreenGui")
        gui.Name = randomName()
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

local ICON_W, ICON_H = 66, 22
local iconTemplates = {}
local function buildIconTemplate(weaponName)
    elevate()
    local weaponUtils, contentUtils = Core.mods.WeaponUtils, Core.mods.ContentUtils
    if not (weaponUtils and contentUtils and weaponUtils.constructWeapon and contentUtils.compileWeaponData) then return false end
    local ok, model = pcall(function()
        local data = contentUtils.compileWeaponData({ weaponName = weaponName })
        local built = weaponUtils.constructWeapon(weaponName, data, nil, nil, nil, true)
        return built
    end)
    if not ok or typeof(model) ~= "Instance" then return false end
    local frame = Instance.new("ViewportFrame")
    frame.BackgroundTransparency = 1
    frame.BorderSizePixel = 0
    frame.Size = UDim2.fromOffset(ICON_W, ICON_H)
    frame.Ambient = Color3.new(0.9, 0.9, 0.9)
    frame.LightColor = Color3.new(1, 1, 1)
    frame.LightDirection = Vector3.new(-1, -1, -1)
    local cam = Instance.new("Camera")
    cam.FieldOfView = 20
    cam.Parent = frame
    frame.CurrentCamera = cam
    local okParent = pcall(function()
        for _, part in ipairs(model:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Anchored = true
                part.Transparency = part.Transparency >= 1 and 1 or 0
            end
        end
        model.Parent = frame
    end)
    if not okParent then pcall(function() model:Destroy() end) return false end
    local okBox, cframe, size = pcall(function() return model:GetBoundingBox() end)
    if not okBox then frame:Destroy() return false end
    local axes = { { "X", size.X, cframe.RightVector }, { "Y", size.Y, cframe.UpVector }, { "Z", size.Z, cframe.LookVector } }
    table.sort(axes, function(a, b) return a[2] > b[2] end)
    local long, second, short = axes[1], axes[2], axes[3]
    local right, up, view = long[3], second[3], short[3]
    if math.abs(up:Dot(Vector3.yAxis)) < math.abs(right:Dot(Vector3.yAxis)) then right, up = up, right end
    local aspect = ICON_W / ICON_H
    local tanV = math.tan(math.rad(cam.FieldOfView / 2))
    local distance = math.max((long[2] / 2) / (tanV * aspect), (second[2] / 2) / tanV) * 1.15 + short[2] / 2
    cam.CFrame = CFrame.lookAt(cframe.Position + view * distance, cframe.Position, up)
    return frame
end

local function iconFor(weaponName)
    if not weaponName then return nil end
    local template = iconTemplates[weaponName]
    if template == nil then
        iconTemplates[weaponName] = false
        local gui = ensureLabelGui()
        if gui then
            local ok, frame = pcall(buildIconTemplate, weaponName)
            if ok and frame then
                frame.Visible = false
                frame.Parent = gui
                iconTemplates[weaponName] = frame
            end
        end
        template = iconTemplates[weaponName]
    end
    return template or nil
end
onUnload(function()
    for _, frame in pairs(iconTemplates) do if frame then pcall(function() frame:Destroy() end) end end
    iconTemplates = {}
end)

-- ---------------------------------------------------------------- drawing objects
local function makeEsp()
    local function text() return newDrawing("Text", { Size = 13, Font = 2, Center = true, Outline = true, OutlineColor = BLACK, ZIndex = 8 }) end
    local object = {
        fill = newDrawing("Square", { Filled = true, ZIndex = 1 }),
        outer = newDrawing("Square", { Thickness = 1, Filled = false, Color = Color3.fromRGB(20, 20, 20), ZIndex = 2 }),
        box = newDrawing("Square", { Thickness = 1, Filled = false, ZIndex = 3 }),
        inner = newDrawing("Square", { Thickness = 1, Filled = false, Color = Color3.fromRGB(20, 20, 20), ZIndex = 2 }),
        hpBack = newDrawing("Square", { Filled = true, Color = Color3.fromRGB(10, 10, 10), ZIndex = 4 }),
        hpFill = newDrawing("Square", { Filled = true, ZIndex = 5 }),
        hpText = text(), name = text(), weapon = text(),
        arrow = newDrawing("Triangle", { Filled = true, ZIndex = 6 }),
        arrowEdge = newDrawing("Triangle", { Filled = false, Thickness = 1, Color = BLACK, ZIndex = 5 }),
        bones = {}, boneEdges = {}, flagTexts = {}, ring = {},
        icon = false, iconName = false,
    }
    for index = 1, 10 do
        object.boneEdges[index] = newDrawing("Line", { Thickness = 3, Color = BLACK, ZIndex = 2 })
        object.bones[index] = newDrawing("Line", { Thickness = 1, ZIndex = 3 })
    end
    for index = 1, 3 do object.flagTexts[index] = text() end
    for index = 1, RING_SEGMENTS do object.ring[index] = newDrawing("Line", { Thickness = 1, ZIndex = 3 }) end
    return object
end

local LIST_KEYS = { bones = true, boneEdges = true, flagTexts = true, ring = true }
local function eachDrawing(object, fn)
    for key, value in pairs(object) do
        if LIST_KEYS[key] then
            for _, inner in ipairs(value) do if inner then fn(inner) end end
        elseif type(value) == "table" or type(value) == "userdata" then
            fn(value)
        end
    end
end

local function hideEsp(object)
    if not object then return end
    eachDrawing(object, function(drawing) pcall(function() drawing.Visible = false end) end)
    if object.icon then pcall(function() object.icon.Visible = false end) end
end

local function destroyEsp(object)
    if not object then return end
    eachDrawing(object, removeDrawing)
    if object.icon then pcall(function() object.icon:Destroy() end) end
end

-- ---------------------------------------------------------------- skeleton
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
-- stick figure: head over a shoulder bar, a spine down to a hip bar, arms and legs hanging straight down from the bar ends
local BONES = {
    { "head", "shoulderMid" }, { "shoulderMid", "hipMid" },
    { "lShoulder", "rShoulder" }, { "lShoulder", "lHand" }, { "rShoulder", "rHand" },
    { "lHip", "rHip" }, { "lHip", "lFoot" }, { "rHip", "rFoot" },
}

local function bonePoints(hash)
    local head, torso = hash.Head, hash.Torso
    if not (head and torso and head.Parent and torso.Parent) then return nil end
    local center = torso.Position
    local points = {}
    for name, joint in pairs(JOINTS) do
        local part = hash[joint[1]]
        if part and part.Parent and (part.Position - center).Magnitude < 10 then
            points[name] = part.CFrame:PointToWorldSpace(joint[2])
        end
    end
    -- legs sit close together in the rig, so the hips and feet are pushed outward to make the legs hang straight down
    local right = torso.CFrame.RightVector
    for _, name in ipairs({ "lHip", "lFoot", "rHip", "rFoot" }) do
        local point = points[name]
        if point then
            local side = (point - center):Dot(right) >= 0 and 1 or -1
            points[name] = point + right * (0.5 * side)
        end
    end
    if points.lShoulder and points.rShoulder then points.shoulderMid = (points.lShoulder + points.rShoulder) * 0.5 end
    if points.lHip and points.rHip then points.hipMid = (points.lHip + points.rHip) * 0.5 end
    return points
end

-- ---------------------------------------------------------------- geometry
local function project(cam, position)
    local point = cam:WorldToViewportPoint(position)
    return Vector2.new(point.X, point.Y), point.Z > 0, point.Z
end

local BOX_PARTS = { "Head", "Torso", "Left Leg", "Right Leg" }
-- the rectangle that wraps the whole character; arms are represented by a fixed reach so it does not jump while aiming
local function playerBounds(cam, record, static)
    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
    local function add(world)
        local point, front = project(cam, world)
        if not front then return true end
        if point.X < minX then minX = point.X end
        if point.X > maxX then maxX = point.X end
        if point.Y < minY then minY = point.Y end
        if point.Y > maxY then maxY = point.Y end
        return true
    end
    local center = record.torso.Position
    if static then
        -- a fixed-size upright box around the standing character, turned with the torso's heading only
        local look = record.torso.CFrame.LookVector
        local yaw = math.atan2(-look.X, -look.Z)
        local frame = CFrame.new(center + Vector3.new(0, -0.5, 0)) * CFrame.Angles(0, yaw, 0)
        for _, sx in ipairs({ -1, 1 }) do
            for _, sy in ipairs({ -1, 1 }) do
                for _, sz in ipairs({ -1, 1 }) do
                    if not add(frame:PointToWorldSpace(Vector3.new(2 * sx, 2.5 * sy, 1.25 * sz))) then return nil end
                end
            end
        end
        return math.floor(minX), math.floor(minY), math.floor(maxX - minX), math.floor(maxY - minY)
    end
    for _, name in ipairs(BOX_PARTS) do
        local part = record.hash[name]
        if part and part.Parent and (part.Position - center).Magnitude < 10 then
            local cframe, half = part.CFrame, PART_SIZES[name] * 0.5
            for _, sx in ipairs({ -1, 1 }) do
                for _, sy in ipairs({ -1, 1 }) do
                    for _, sz in ipairs({ -1, 1 }) do
                        if not add(cframe:PointToWorldSpace(Vector3.new(half.X * sx, half.Y * sy, half.Z * sz))) then return nil end
                    end
                end
            end
        end
    end
    local right = record.torso.CFrame.RightVector
    for _, side in ipairs({ -1, 1 }) do
        for _, lift in ipairs({ -1, 1 }) do
            if not add(center + right * (2 * side) + Vector3.new(0, lift, 0)) then return nil end
        end
    end
    if minX == math.huge then return nil end
    return math.floor(minX), math.floor(minY), math.floor(maxX - minX), math.floor(maxY - minY)
end

local function clampRange(value, low, high)
    if high < low then return low end
    return math.clamp(value, low, high)
end

local function rotate(vector, angle)
    local c, s = math.cos(angle), math.sin(angle)
    return Vector2.new(vector.X * c - vector.Y * s, vector.X * s + vector.Y * c)
end

-- ---------------------------------------------------------------- chams
-- BBOT style: two box adornments per body part, parented to the real part. The inner one draws through walls,
-- the outer one only where the part can be seen. A third larger layer is the glow.

local function newAdorn(part, isHead, alwaysOnTop, zIndex, parent)
    local adorn = Instance.new(isHead and "CylinderHandleAdornment" or "BoxHandleAdornment")
    adorn.Name = randomName()
    adorn.Adornee = part
    adorn.ZIndex = zIndex
    adorn.AlwaysOnTop = alwaysOnTop
    adorn.AdornCullingMode = Enum.AdornCullingMode.Never
    if isHead then adorn.CFrame = CFrame.new(Vector3.zero, Vector3.new(0, 1, 0)) end
    adorn.Visible = false
    adorn.Parent = parent or part
    return adorn
end

local chamFolder
local function destroyChams(player)
    local data = adornData[player]
    if not data then return end
    for _, set in pairs(data.parts) do
        for _, adorn in pairs({ set.hidden, set.visible, set.glow }) do pcall(function() adorn:Destroy() end) end
    end
    adornData[player] = nil
end

local function updateChams(record, wanted, cfg, ctx)
    local player = record.player
    if not wanted then
        destroyChams(player)
        return
    end
    local data = adornData[player]
    if data and data.hash ~= record.hash then
        destroyChams(player)
        data = nil
    end
    if not data then
        data = { hash = record.hash, parts = {} }
        adornData[player] = data
    end
    local visibleColor = record.override or cfg.chamVis
    local mode = ctx.chamParent
    elevate()
    for _, name in ipairs(PART_NAMES) do
        local part = record.hash[name]
        local set = data.parts[name]
        if set and (set.source ~= part or not set.hidden.Parent or set.mode ~= mode) then
            for _, adorn in pairs({ set.hidden, set.visible, set.glow }) do pcall(function() adorn:Destroy() end) end
            data.parts[name] = nil
            set = nil
        end
        if part and part.Parent then
            local isHead = name == "Head"
            if not set then
                local parent = part
                if mode == "CoreGui" then
                    parent = ensureLabelGui() or part
                elseif mode == "Workspace" then
                    if not (chamFolder and chamFolder.Parent) then
                        chamFolder = Instance.new("Folder")
                        chamFolder.Name = randomName()
                        chamFolder.Parent = Workspace
                    end
                    parent = chamFolder
                end
                local okMake, made = pcall(function()
                    return {
                        source = part, mode = mode,
                        hidden = newAdorn(part, isHead, true, 1, parent),
                        visible = newAdorn(part, isHead, false, -1, parent),
                        glow = newAdorn(part, isHead, true, 0, parent),
                    }
                end)
                if not okMake then
                    dbg.chamsInfo = "create failed: " .. tostring(made)
                    note("chammake" .. tostring(made), "chams could not be created:", made)
                    return
                end
                set = made
                data.parts[name] = set
                dbg.chamsMade += 1
                dbg.chamsInfo = string.format("%s parent=%s mode=%s", name, tostring(set.hidden.Parent and set.hidden.Parent.ClassName), mode)
            end
            local layer, glow = ctx.chamLayer, ctx.chamGlowOn and ctx.chamGlowSize or 0
            local size = PART_SIZES[name]
            local signature = table.concat({ tostring(size), mode, layer, glow, ctx.chamHead, tostring(cfg.chamHid), cfg.chamHidT, tostring(visibleColor), cfg.chamVisT, tostring(ctx.chamGlowColor), ctx.chamGlowT }, "|")
            if set.signature ~= signature then
                set.signature = signature
                if isHead then
                    local radius, height = 0.65 * ctx.chamHead, 1.05 * ctx.chamHead
                    set.hidden.Radius, set.hidden.Height = math.max(radius - 0.1, 0.1), math.max(height - 0.1, 0.1)
                    set.visible.Radius, set.visible.Height = radius + layer, height + layer
                    set.glow.Radius, set.glow.Height = radius + layer + glow, height + layer + glow
                else
                    set.hidden.Size = size - Vector3.new(0.1, 0.1, 0.1)
                    set.visible.Size = size + Vector3.new(layer, layer, layer)
                    set.glow.Size = size + Vector3.new(layer + glow, layer + glow, layer + glow)
                end
                set.hidden.Color3, set.hidden.Transparency = cfg.chamHid, cfg.chamHidT
                set.visible.Color3, set.visible.Transparency = visibleColor, cfg.chamVisT
                set.glow.Color3, set.glow.Transparency = ctx.chamGlowColor, ctx.chamGlowT
            end
            set.hidden.Visible = true
            set.visible.Visible = true
            set.glow.Visible = ctx.chamGlowOn
        end
    end
end

onUnload(function()
    for player in pairs(adornData) do destroyChams(player) end
    if chamFolder then pcall(function() chamFolder:Destroy() end) end
end)
track(Players.PlayerRemoving:Connect(function(player)
    destroyChams(player)
    sounds[player] = nil
end))

-- ---------------------------------------------------------------- sound tracker
local soundHooked
local function hookSounds()
    if soundHooked then return end
    local audio = Core.mods.AudioSystem
    if type(audio) ~= "table" or type(audio.playSound) ~= "function" then return end
    local original = audio.playSound
    audio.playSound = function(...)
        local packed = table.pack(...)
        local root = packed[8]
        dbg.soundArgs = typeof(root) == "Instance" and (root.ClassName .. ":" .. root.Name) or typeof(root)
        if typeof(root) == "Instance" then dbg.soundEvents += 1 end
        if typeof(root) == "Instance" and (readFlag("esp_sound", false) or readFlag("esp_sound@Friendly", false)) then
            pcall(function()
                for _, record in ipairs(lastRecords) do
                    local match = root == record.torso or (record.model and root:IsDescendantOf(record.model))
                    if match then
                        dbg.soundMatched += 1
                        local current = sounds[record.player]
                        if not current or os.clock() - current.t0 > current.duration then
                            sounds[record.player] = { t0 = os.clock(), duration = readFlag("snd_duration", 0.9) }
                        end
                        break
                    end
                end
            end)
        end
        return original(...)
    end
    soundHooked = true
    onUnload(function()
        pcall(function() audio.playSound = original end)
        soundHooked = nil
    end)
end

-- ---------------------------------------------------------------- per player drawing
local function setText(drawing, text, size, font, color, x, y, alpha, center, outline)
    drawing.Text, drawing.Size, drawing.Font, drawing.Color = text, size, font, color
    drawing.Center, drawing.Outline = center, outline
    drawing.Position = Vector2.new(math.floor(x), math.floor(y))
    drawing.Transparency, drawing.Visible = alpha, true
end

local function casedText(text, mode, maxLength)
    if mode == "lower" then text = string.lower(text) elseif mode == "UPPER" then text = string.upper(text) end
    if #text > maxLength then text = string.sub(text, 1, maxLength) end
    return text
end

local function drawArrow(object, cam, record, cfg, ctx, alpha, color, meters)
    local relative = cam.CFrame:PointToObjectSpace(record.pos)
    local direction
    if math.abs(relative.X) < 0.001 and math.abs(relative.Y) < 0.001 then
        direction = Vector2.new(0, 1)
    else
        local angle = math.atan2(-relative.Y, relative.X)
        direction = Vector2.new(math.cos(angle), math.sin(angle))
    end
    local size = ctx.arrowSize
    if ctx.arrowDynamic then size = math.clamp(size * (1.6 - meters / 150), size * 0.6, size * 1.6) end
    local viewport, center = ctx.viewport, ctx.center
    local radius = ctx.arrowRadius / 100 * viewport.X * 0.5
    local limit = math.huge
    if math.abs(direction.X) > 0.001 then limit = math.min(limit, (viewport.X * 0.5 - 10) / math.abs(direction.X)) end
    if math.abs(direction.Y) > 0.001 then limit = math.min(limit, (viewport.Y * 0.5 - 10) / math.abs(direction.Y)) end
    radius = math.min(radius, limit)
    local tip = center + direction * radius
    local pointB = tip - rotate(direction, 0.5) * size
    local pointC = tip - rotate(direction, -0.5) * size
    local fade = alpha
    if ctx.arrowFade then fade *= math.clamp(1 - meters / ctx.arrowFadeDistance, 0.15, 1) end
    dbg.arrows += 1
    object.arrow.PointA, object.arrow.PointB, object.arrow.PointC = tip, pointB, pointC
    object.arrow.Color, object.arrow.Transparency, object.arrow.Visible = color, fade, true
    if ctx.outline then
        object.arrowEdge.PointA, object.arrowEdge.PointB, object.arrowEdge.PointC = tip, pointB, pointC
        object.arrowEdge.Transparency, object.arrowEdge.Visible = fade, true
    end
end

local function drawRing(object, cam, record, cfg, ctx, now, alpha, visible)
    local sound = sounds[record.player]
    if not sound then return end
    local age = now - sound.t0
    if age > sound.duration then
        sounds[record.player] = nil
        return
    end
    if not ctx.soundWalls and not visible then return end
    dbg.rings += 1
    local progress = age / sound.duration
    local radius = 2 + (ctx.soundRadius - 2) * progress
    local fadeOut = math.clamp((sound.duration - age) / 0.2, 0, 1)
    local feet = record.pos - Vector3.new(0, 3, 0)
    local previous, previousFront
    local first, firstFront
    for index = 0, RING_SEGMENTS do
        local angle = (index % RING_SEGMENTS) / RING_SEGMENTS * math.pi * 2
        local point, front = project(cam, feet + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius))
        if index > 0 and front and previousFront then
            local line = object.ring[index]
            line.From, line.To = previous, point
            line.Color = cfg.soundColor
            line.Transparency = cfg.soundA * alpha * fadeOut
            line.Visible = true
        end
        previous, previousFront = point, front
    end
end

local function drawPlayer(cam, object, state, record, cfg, ctx, now, distance, origin)
    dbg.drawn += 1
    local alpha = state.alpha
    local meters = math.floor(distance * 0.28)
    local visible = record.rendered and isVisible(record.torso, origin, now) or false
    local outline = ctx.outline
    local size, font = ctx.textSize, ctx.font
    local override = record.override

    local screen = project(cam, record.pos)
    local _, front = project(cam, record.pos)
    local onScreen = front and screen.X >= 0 and screen.X <= ctx.viewport.X and screen.Y >= 0 and screen.Y <= ctx.viewport.Y

    if not onScreen then
        if cfg.oov then drawArrow(object, cam, record, cfg, ctx, alpha * cfg.oovA, override or cfg.oovColor, meters) end
        if cfg.sound and record.rendered then drawRing(object, cam, record, cfg, ctx, now, alpha, visible) end
        return
    end
    if not record.rendered then return end

    local x, y, w, h = playerBounds(cam, record, ctx.boxStatic)
    if cfg.sound then drawRing(object, cam, record, cfg, ctx, now, alpha, visible) end
    if not x or w < 2 or h < 2 then return end

    local boxColor = override or cfg.boxColor
    if cfg.box then
        if outline then
            object.outer.Position, object.outer.Size = Vector2.new(x - 1, y - 1), Vector2.new(w + 2, h + 2)
            object.outer.Transparency, object.outer.Visible = alpha * cfg.boxA, true
            object.inner.Position, object.inner.Size = Vector2.new(x + 1, y + 1), Vector2.new(w - 2, h - 2)
            object.inner.Transparency, object.inner.Visible = alpha * cfg.boxA, true
        end
        object.box.Position, object.box.Size = Vector2.new(x, y), Vector2.new(w, h)
        object.box.Color, object.box.Transparency, object.box.Visible = boxColor, alpha * cfg.boxA, true
        if cfg.fillA > 0.01 then
            object.fill.Position, object.fill.Size = Vector2.new(x, y), Vector2.new(w, h)
            object.fill.Color, object.fill.Transparency, object.fill.Visible = cfg.fillColor, alpha * cfg.fillA, true
        end
    end

    local health = math.clamp(state.hp * 100, 0, 100)
    if cfg.hp then
        local fillHeight = math.floor(h * health / 100)
        object.hpBack.Position, object.hpBack.Size = Vector2.new(x - 6, y - 1), Vector2.new(4, h + 2)
        object.hpBack.Transparency, object.hpBack.Visible = alpha * cfg.hpA, true
        object.hpFill.Position, object.hpFill.Size = Vector2.new(x - 5, y + h - fillHeight), Vector2.new(2, fillHeight)
        object.hpFill.Color = lerpColor(cfg.hpLow, cfg.hpFull, health / 100)
        object.hpFill.Transparency, object.hpFill.Visible = alpha * cfg.hpA, true
    end
    if cfg.hpNum and health <= ctx.hpCap and health > 0 then
        local label = object.hpText
        setText(label, tostring(math.floor(health + 0.5)), size, font, cfg.hpNumColor, x - 7, y, alpha * cfg.hpNumA, false, outline)
        local bounds = label.TextBounds
        local fillTop = cfg.hp and (y + h - math.floor(h * health / 100)) or y
        local labelY = clampRange(fillTop - bounds.Y * 0.5, y - 4, y + h - 10)
        label.Position = Vector2.new(math.floor(x - bounds.X - (cfg.hp and 7 or 3)), math.floor(labelY))
    end

    if cfg.name then
        setText(object.name, casedText(record.name, ctx.textCase, ctx.maxText), size, font, override or cfg.nameColor, x + w * 0.5, y - size - 2, alpha * cfg.nameA, true, outline)
    end

    local below = 0
    if cfg.weapon then
        setText(object.weapon, casedText(record.weaponName or "???", ctx.textCase, ctx.maxText), size, font, override or cfg.weaponColor, x + w * 0.5, y + h, alpha * cfg.weaponA, true, outline)
        below += size - 1
    end
    if cfg.icon then
        local okIcon, template = pcall(iconFor, record.weaponName)
        if not okIcon then
            note("icon" .. tostring(template), "icons unavailable:", template)
            template = nil
            ctx.iconsBroken = true
        end
        if template and not ctx.iconsBroken then
            local okShow, problem = pcall(function()
            if object.iconName ~= record.weaponName or not object.icon or not object.icon.Parent then
                if object.icon then pcall(function() object.icon:Destroy() end) end
                object.icon = template:Clone()
                object.icon.Parent = template.Parent
                object.iconName = record.weaponName
            end
            local icon = object.icon
            icon.Position = UDim2.fromOffset(math.floor(x + w * 0.5 - ICON_W * 0.5), math.floor(y + h + below + 2))
            icon.ImageColor3 = cfg.iconColor
            icon.ImageTransparency = 1 - alpha * cfg.iconA
            icon.Visible = true
            end)
            if not okShow then
                note("iconshow" .. tostring(problem), "icon draw failed:", problem)
                if object.icon then pcall(function() object.icon:Destroy() end) end
                object.icon, object.iconName = false, false
                iconTemplates[record.weaponName] = false
            end
        elseif not cfg.weapon then
            setText(object.weapon, casedText(record.weaponName or "???", ctx.textCase, ctx.maxText), size, font, override or cfg.iconColor, x + w * 0.5, y + h, alpha * cfg.iconA, true, outline)
        end
    end

    local flagY = y - 4
    local flagIndex = 0
    local function flag(text)
        flagIndex += 1
        local label = object.flagTexts[flagIndex]
        if not label then return end
        setText(label, text, size, font, override or cfg.flagColor, x + w + 3, flagY, alpha * cfg.flagA, false, outline)
        flagY += size
    end
    if cfg.flags.Distance then flag(meters .. "m") end
    if cfg.flags.Visible and visible then flag("Visible") end
    if cfg.flags.Target and Aim.target == record.player then flag("Target") end

    if cfg.skeleton then
        local points = bonePoints(record.hash)
        if points then
            local skeletonColor = override or cfg.skeletonColor
            for index, bone in ipairs(BONES) do
                local a, b = points[bone[1]], points[bone[2]]
                if a and b then
                    local from, fromFront = project(cam, a)
                    local to, toFront = project(cam, b)
                    if fromFront and toFront then
                        if outline then
                            local edge = object.boneEdges[index]
                            edge.From, edge.To = from, to
                            edge.Thickness = ctx.skeletonThick + 2
                            edge.Transparency, edge.Visible = alpha * cfg.skeletonA, true
                        end
                        local line = object.bones[index]
                        line.From, line.To, line.Color = from, to, skeletonColor
                        line.Thickness = ctx.skeletonThick
                        line.Transparency, line.Visible = alpha * cfg.skeletonA, true
                    end
                end
            end
        end
    end
end

local function stepState(state, record, want, dt, ctx)
    local ratio = math.clamp(record.health / math.max(record.maxHealth, 1), 0, 1)
    state.hp = ratio
    if ctx.fadeTime <= 0.001 then
        state.alpha = want and 1 or 0
        return
    end
    local step = dt / ctx.fadeTime
    state.alpha = math.clamp(state.alpha + (want and step or -step), 0, 1)
end

local function espStep(cam, now, dt, records, origin)
    lastRecords = records
    local seen = {}
    local enemyCfg, friendCfg = teamCfg(false), teamCfg(true)
    local ctx = {
        debug = readFlag("esp_debug", false),
        viewport = cam.ViewportSize,
        center = cam.ViewportSize / 2,
        outline = readFlag("esp_outline", false),
        skeletonThick = readFlag("esp_skel_thick", 1),
        boxStatic = readFlag("esp_box_mode", "Static") == "Static",
        textSize = readFlag("esp_text", 13),
        font = FONT_IDS[readFlag("esp_font", "Plex")] or 2,
        fadeTime = readFlag("esp_fade_time", 0.2),
        textCase = readFlag("esp_case", "Normal"),
        maxText = readFlag("esp_max_text", 30),
        hpCap = readFlag("esp_hp_cap", 100),
        useVisible = readFlag("esp_vis", false), visibleColor = readFlag("esp_vis_color", WHITE),
        markTarget = readFlag("esp_target", false), targetColor = readFlag("esp_target_color", WHITE),
        chamParent = readFlag("cham_parent", "Workspace"), chamLayer = readFlag("cham_layer", 0.05), chamHead = readFlag("cham_head", 1),
        chamGlowOn = readFlag("cham_glow", false), chamGlowSize = readFlag("cham_glow_size", 0.3),
        chamGlowColor = readFlag("cham_glow_color", WHITE), chamGlowT = pickerTransparency("cham_glow_color", 0.7),
        arrowSize = readFlag("oov_size", 14), arrowDynamic = readFlag("oov_dynamic_size", false),
        arrowRadius = readFlag("oov_radius", 40), arrowFade = readFlag("oov_fade", false),
        arrowFadeDistance = readFlag("oov_fade_distance", 150),
        soundRadius = readFlag("snd_radius", 5), soundWalls = readFlag("snd_walls", true),
    }
    pcall(hookSounds)

    for _, record in ipairs(records) do
        local player = record.player
        seen[player] = true
        if espState[player] then espState[player].lastSeen = now end
        local cfg = record.enemy and enemyCfg or friendCfg
        local distance = (record.pos - origin).Magnitude
        local want = cfg.enabled and distance <= cfg.distance
        local object, state = espObjects[player], espState[player]
        record.override = nil
        if cfg.enabled then
            if ctx.markTarget and Aim.target == player then record.override = ctx.targetColor
            elseif record.rendered and record.enemy and ctx.useVisible and isVisible(record.torso, origin, now) then record.override = ctx.visibleColor end
        end

        if want and not object then
            object = makeEsp()
            espObjects[player] = object
            state = { alpha = ctx.fadeTime <= 0.001 and 1 or 0, hp = 1, lastSeen = now }
            espState[player] = state
        end
        if object and state then
            stepState(state, record, want, dt, ctx)
            hideEsp(object)
            if state.alpha > 0.01 then
                local ok, problem = pcall(drawPlayer, cam, object, state, record, cfg, ctx, now, distance, origin)
                if not ok then
                    dbg.errors += 1
                    hideEsp(object)
                    note("esp:" .. tostring(problem), "esp (" .. tostring(player.Name) .. "):", problem)
                end
            end
        end

        local chamsWanted = want and record.rendered and cfg.chams and record.model and record.model.Parent
        local ok, problem = pcall(updateChams, record, chamsWanted and true or false, cfg, ctx)
        if not ok then note("cham:" .. tostring(problem), "chams:", problem) end
    end

    for player, object in pairs(espObjects) do
        if not seen[player] then
            hideEsp(object)
            local state = espState[player]
            if not state or now - (state.lastSeen or 0) > 1.5 then
                destroyEsp(object)
                espObjects[player] = nil
                espState[player] = nil
            end
        end
    end
    for player, data in pairs(adornData) do
        if not seen[player] then
            data.missing = (data.missing or now)
            if now - data.missing > 1.5 then destroyChams(player) end
        else
            data.missing = nil
        end
    end
    if ctx.debug and now - (dbg.printedAt or 0) > 3 then
        dbg.printedAt = now
        local list = {}
        for _, record in ipairs(records) do
            local cfg = record.enemy and enemyCfg or friendCfg
            list[#list + 1] = string.format("%s[%s en=%s 2D=%s oov=%s ch=%s snd=%s]", record.name, math.floor((record.pos - origin).Magnitude * 0.28) .. "m", tostring(record.enemy), tostring(cfg.enabled), tostring(cfg.oov), tostring(cfg.chams), tostring(cfg.sound))
        end
        print(string.format("[Aster debug %s] records=%d arrows=%d rings=%d drawn=%d errors=%d", BUILD, #records, dbg.arrows, dbg.rings, dbg.drawn, dbg.errors))
        print("  chams: made=" .. dbg.chamsMade .. " | " .. dbg.chamsInfo)
        print(string.format("  sound: hooked=%s audioModule=%s events=%d matched=%d lastArg8=%s", tostring(soundHooked), tostring(Core.mods.AudioSystem ~= nil), dbg.soundEvents, dbg.soundMatched, dbg.soundArgs))
        print("  players: " .. table.concat(list, ", "))
        dbg.arrows, dbg.rings, dbg.drawn = 0, 0, 0
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
    ok, problem = pcall(espStep, cam, now, dt, snapshotAll, origin)
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
