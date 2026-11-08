-- Phantom Perception | built on the Perception menu skin
local BUILD = "phantom-1108-b"

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local UI_REPO = "https://raw.githubusercontent.com/WhyWKey/linoria/main/"

local function noop() end

local __ok, __err = xpcall(function()

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
local Skin = loadstring(game:HttpGet(UI_REPO .. "ui-test/PerceptionSkin.lua?t=" .. os.time()))()(Library, { Brand = "Phantom" })
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
    Title = "Phantom  |  " .. BUILD,
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
            Default = info.Default == true,
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



print("[Phantom] build " .. BUILD .. " | skin " .. tostring(Skin.Version))

-- ============================================================ helpers
local warned = {}
local function note(key, ...)
    if warned[key] then return end
    warned[key] = true
    warn("[Phantom]", ...)
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

local function multi(name, fallback)
    local value = readFlag(name, fallback)
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
    for _, name in ipairs({ "ReplicationInterface", "CharacterInterface", "CameraInterface", "PublicSettings" }) do
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
        note("core", "Core modules not found:", table.concat(Core.missing, ", "), "- run the script inside the game's actor if it has one")
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

local function activeWeapon()
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

local function weaponStat(weapon, name)
    if type(weapon) ~= "table" or type(weapon.getWeaponStat) ~= "function" then return nil end
    local ok, value = pcall(weapon.getWeaponStat, weapon, name)
    if ok then return value end
    return nil
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
            model = okModel and model or nil,
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
local PF_StatusCore, PF_StatusWeapon, PF_StatusTarget, PF_StatusRecoil
local LegitPage = Window:Page({ Name = "Legit", Columns = 2, Subtabs = false })
local LegitSubs = LegitPage:SubTabs({ "Aim", "Trigger", "Recoil", "Status" })
local VisualsPage = Window:Page({ Name = "Visuals", Columns = 2, Subtabs = false })
local VisualsSubs = VisualsPage:SubTabs({ "ESP", "Chams" })
local MiscPage = Window:Page({ Name = "Misc", Columns = 2, Subtabs = false })
local MiscSubs = MiscPage:SubTabs({ "Camera", "Utility" })

do
    local Aimbot = LegitSubs.Aim:Section({ Name = "Aimbot", Side = 1 })
    Aimbot:Toggle({ Name = "Enabled", Flag = "aim_enabled", Default = false, Tooltip = "Turns your view toward the target through the game's own camera while the key is held" }):Keybind({ Name = "Aim key", Flag = "aim_key", Default = "MB2", Mode = "Hold" })
    Aimbot:Toggle({ Name = "Only while aiming down sights", Flag = "aim_ads", Default = false })
    Aimbot:Toggle({ Name = "Only while shooting", Flag = "aim_shoot", Default = false })
    Aimbot:Toggle({ Name = "Visible only", Flag = "aim_visible", Default = true, Tooltip = "Ignores players behind walls" })
    Aimbot:Slider({ Name = "Smoothing", Flag = "aim_smooth", Min = 1, Max = 60, Default = 12, Decimals = 1, Tooltip = "Higher is slower and looks more natural" })
    Aimbot:Slider({ Name = "Max turn speed", Flag = "aim_speed", Min = 30, Max = 1440, Default = 420, Decimals = 1, Suffix = " °/s", Tooltip = "Caps how fast the view can turn, so it never snaps" })
    Aimbot:Slider({ Name = "Max distance", Flag = "aim_dist", Min = 50, Max = 1500, Default = 600, Decimals = 1, Suffix = " studs" })

    local Targeting = LegitSubs.Aim:Section({ Name = "Targeting", Side = 1 })
    Targeting:Dropdown({ Name = "Priority", Flag = "aim_priority", Items = { "Crosshair", "Distance", "Lowest health" }, Default = "Crosshair" })
    Targeting:Toggle({ Name = "Sticky target", Flag = "aim_sticky", Default = true, Tooltip = "Stays on the current target while it is still valid" })
    Targeting:Slider({ Name = "Switch delay", Flag = "aim_switch", Min = 0, Max = 500, Default = 120, Decimals = 1, Suffix = " ms" })
    Targeting:Slider({ Name = "Reaction delay", Flag = "aim_react", Min = 0, Max = 400, Default = 60, Decimals = 1, Suffix = " ms", Tooltip = "Waits this long after picking a new target before moving" })

    local Hits = LegitSubs.Aim:Section({ Name = "Hit parts", Side = 2 })
    Hits:Dropdown({ Name = "Parts", Flag = "aim_parts", Items = { "Head", "Torso", "Arms", "Legs" }, Multi = true, Default = { "Head", "Torso" } })
    Hits:Dropdown({ Name = "Part choice", Flag = "aim_choice", Items = { "Closest to crosshair", "Priority order" }, Default = "Closest to crosshair", Tooltip = "Priority order tries Head, Torso, Arms, Legs and takes the first one that qualifies" })

    local Fov = LegitSubs.Aim:Section({ Name = "Field of view", Side = 2 })
    Fov:Toggle({ Name = "Show circle", Flag = "fov_show", Default = true }):Colorpicker({ Name = "Circle color", Flag = "fov_color", Default = Color3.fromRGB(255, 255, 255) })
    Fov:Slider({ Name = "Radius", Flag = "fov_radius", Min = 10, Max = 800, Default = 120, Decimals = 1, Suffix = " px" })
    Fov:Toggle({ Name = "Dynamic radius", Flag = "fov_dynamic", Default = false, Tooltip = "The radius depends on how far the target is" })
    Fov:Slider({ Name = "Radius when close", Flag = "fov_near", Min = 10, Max = 800, Default = 240, Decimals = 1, Suffix = " px" })
    Fov:Slider({ Name = "Radius at max distance", Flag = "fov_far", Min = 10, Max = 800, Default = 60, Decimals = 1, Suffix = " px" })

    local Human = LegitSubs.Aim:Section({ Name = "Humanize", Side = 2 })
    Human:Slider({ Name = "Aim wobble", Flag = "aim_noise", Min = 0, Max = 3, Default = 0.25, Decimals = 0.01, Suffix = "°", Tooltip = "Small random drift on the aim point" })
    Human:Slider({ Name = "Wobble speed", Flag = "aim_noise_speed", Min = 0.2, Max = 6, Default = 1.4, Decimals = 0.1 })

    local Lead = LegitSubs.Aim:Section({ Name = "Weapon lead", Side = 2 })
    Lead:Toggle({ Name = "Bullet drop", Flag = "lead_drop", Default = true, Tooltip = "Aims higher by how far the bullet falls on its way, using the weapon's bullet speed and the game's gravity for bullets" })
    Lead:Toggle({ Name = "Moving targets", Flag = "lead_move", Default = true, Tooltip = "Aims ahead by the target's speed times the bullet's travel time" })
    Lead:Slider({ Name = "Lead strength", Flag = "lead_strength", Min = 0, Max = 1.5, Default = 1, Decimals = 0.01 })
    Lead:Slider({ Name = "Max lead", Flag = "lead_max", Min = 0, Max = 40, Default = 14, Decimals = 0.1, Suffix = " studs", Tooltip = "Caps how far ahead of a moving target it aims" })

    local Trigger = LegitSubs.Trigger:Section({ Name = "Triggerbot", Side = 1 })
    Trigger:Toggle({ Name = "Enabled", Flag = "trig_enabled", Default = false, Tooltip = "Fires when your crosshair is on an enemy" }):Keybind({ Name = "Trigger key", Flag = "trig_key", Default = "None", Mode = "Always" })
    Trigger:Toggle({ Name = "Visible only", Flag = "trig_visible", Default = true })
    Trigger:Toggle({ Name = "Only while aiming down sights", Flag = "trig_ads", Default = false })
    Trigger:Dropdown({ Name = "Parts", Flag = "trig_parts", Items = { "Head", "Torso", "Arms", "Legs" }, Multi = true, Default = { "Head", "Torso" } })
    Trigger:Slider({ Name = "Hitbox size", Flag = "trig_scale", Min = 0.4, Max = 1.6, Default = 0.9, Decimals = 0.01, Suffix = "x" })
    Trigger:Slider({ Name = "Max distance", Flag = "trig_dist", Min = 50, Max = 1500, Default = 400, Decimals = 1, Suffix = " studs" })
    local TriggerTiming = LegitSubs.Trigger:Section({ Name = "Timing", Side = 2 })
    TriggerTiming:Slider({ Name = "Delay", Flag = "trig_delay", Min = 0, Max = 300, Default = 40, Decimals = 1, Suffix = " ms", Tooltip = "Time the crosshair must stay on the target before firing" })
    TriggerTiming:Slider({ Name = "Hold", Flag = "trig_hold", Min = 20, Max = 500, Default = 70, Decimals = 1, Suffix = " ms", Tooltip = "How long the button stays down. Longer holds fire more shots on automatic guns" })
    TriggerTiming:Slider({ Name = "Cooldown", Flag = "trig_cool", Min = 0, Max = 500, Default = 90, Decimals = 1, Suffix = " ms" })

    local Recoil_ = LegitSubs.Recoil:Section({ Name = "Recoil control", Side = 1 })
    Recoil_:Toggle({ Name = "Enabled", Flag = "rcs_enabled", Default = false, Tooltip = "Cancels the camera kick of each shot. It reads the weapon's own recoil springs, so it follows every gun and attachment automatically" }):Keybind({ Name = "Recoil key", Flag = "rcs_key", Default = "None", Mode = "Always" })
    Recoil_:Slider({ Name = "Vertical control", Flag = "rcs_v", Min = 0, Max = 100, Default = 70, Decimals = 1, Suffix = "%", Tooltip = "How much of the upward kick is cancelled" })
    Recoil_:Slider({ Name = "Horizontal control", Flag = "rcs_h", Min = 0, Max = 100, Default = 40, Decimals = 1, Suffix = "%", Tooltip = "How much of the sideways kick is cancelled" })
    Recoil_:Toggle({ Name = "Hipfire too", Flag = "rcs_hip", Default = true, Tooltip = "Off: only controls recoil while aiming down sights" })
    Recoil_:Slider({ Name = "Variation", Flag = "rcs_human", Min = 0, Max = 40, Default = 10, Decimals = 1, Suffix = "%", Tooltip = "Varies the strength a little over time so the spray does not look machine perfect" })

    local Status = LegitSubs.Status:Section({ Name = "Core", Side = 1 })
    PF_StatusRecoil = Status:Label({ Name = "Recoil: 0.0 / 0.0" })
    PF_StatusCore = Status:Label({ Name = "Core: " .. Core.summary })
    PF_StatusWeapon = Status:Label({ Name = "Weapon: none" })
    PF_StatusTarget = Status:Label({ Name = "Target: none" })
    Status:Button({ Name = "Reload core", Callback = function()
        loadCore()
        PF_StatusCore:SetText("Core: " .. Core.summary)
        pcall(function() Library:Notify("Core " .. Core.summary, 4) end)
    end })

    local Players_ = VisualsSubs.ESP:Section({ Name = "Players", Side = 1 })
    Players_:Toggle({ Name = "Enabled", Flag = "esp_enabled", Default = false }):Colorpicker({ Name = "Enemy color", Flag = "esp_color", Default = Color3.fromRGB(255, 80, 80) })
    Players_:Toggle({ Name = "Show teammates", Flag = "esp_team", Default = false }):Colorpicker({ Name = "Team color", Flag = "esp_team_color", Default = Color3.fromRGB(90, 200, 120) })
    Players_:Toggle({ Name = "Visibility colors", Flag = "esp_vis", Default = false, Tooltip = "Uses a second color for enemies you can see" }):Colorpicker({ Name = "Visible color", Flag = "esp_vis_color", Default = Color3.fromRGB(255, 230, 80) })
    Players_:Slider({ Name = "Max distance", Flag = "esp_dist", Min = 50, Max = 3000, Default = 1500, Decimals = 1, Suffix = " studs" })

    local Boxes = VisualsSubs.ESP:Section({ Name = "Boxes and text", Side = 1 })
    Boxes:Dropdown({ Name = "Box", Flag = "esp_box", Items = { "Off", "Full", "Corners" }, Default = "Full" })
    Boxes:Toggle({ Name = "Name", Flag = "esp_name", Default = true })
    Boxes:Toggle({ Name = "Health bar", Flag = "esp_health", Default = true })
    Boxes:Toggle({ Name = "Distance", Flag = "esp_distance", Default = true })
    Boxes:Toggle({ Name = "Weapon", Flag = "esp_weapon", Default = false })
    Boxes:Slider({ Name = "Text size", Flag = "esp_text", Min = 10, Max = 20, Default = 13, Decimals = 1 })

    local Extras = VisualsSubs.ESP:Section({ Name = "Extras", Side = 2 })
    Extras:Toggle({ Name = "Skeleton", Flag = "esp_skeleton", Default = false })
    Extras:Toggle({ Name = "Head dot", Flag = "esp_head", Default = false })
    Extras:Toggle({ Name = "Tracers", Flag = "esp_tracer", Default = false })
    Extras:Dropdown({ Name = "Tracer origin", Flag = "esp_tracer_from", Items = { "Bottom", "Center", "Top" }, Default = "Bottom" })

    local Chams = VisualsSubs.Chams:Section({ Name = "Chams", Side = 1 })
    Chams:Toggle({ Name = "Enabled", Flag = "cham_enabled", Default = false, Tooltip = "Outlines players with a highlight that lives outside their character, so nothing is added to the character itself" })
    Chams:Toggle({ Name = "Fill color", Flag = "cham_fill_on", Default = true }):Colorpicker({ Name = "Fill color", Flag = "cham_fill", Default = Color3.fromRGB(255, 80, 80) })
    Chams:Slider({ Name = "Fill transparency", Flag = "cham_fill_t", Min = 0, Max = 1, Default = 0.6, Decimals = 0.01 })
    Chams:Toggle({ Name = "Outline", Flag = "cham_line_on", Default = true }):Colorpicker({ Name = "Outline color", Flag = "cham_line", Default = Color3.fromRGB(255, 255, 255) })
    Chams:Toggle({ Name = "Through walls", Flag = "cham_walls", Default = true })
    Chams:Toggle({ Name = "Teammates", Flag = "cham_team", Default = false })

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
    if not readFlag("fov_dynamic", false) then return readFlag("fov_radius", 120) end
    local t = math.clamp(distance / math.max(maxDistance, 1), 0, 1)
    return lerp(readFlag("fov_near", 240), readFlag("fov_far", 60), t)
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
    local maxDistance = readFlag("aim_dist", 600)
    local wantVisible = readFlag("aim_visible", true)
    local groups = multi("aim_parts", { Head = true, Torso = true })
    local priorityMode = readFlag("aim_choice", "Closest to crosshair") == "Priority order"
    local priority = readFlag("aim_priority", "Crosshair")
    local speed = weaponStat(weapon, "bulletspeed")
    local useDrop, useMove = readFlag("lead_drop", true), readFlag("lead_move", true)
    local strength, maxLead = readFlag("lead_strength", 1), readFlag("lead_max", 14)

    local best, bestPart, bestAim, bestScore, bestScreen
    local sticky = readFlag("aim_sticky", true)
    local current

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
                    if sticky and Aim.target == record.player then
                        score -= 1e6
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

local function turnToward(gameCam, origin, aimPoint, dt, now)
    local direction = aimPoint - origin
    if direction.Magnitude < 0.01 then return end
    direction = direction.Unit

    local noise = readFlag("aim_noise", 0.25)
    local targetPitch = math.atan2(direction.Y, math.sqrt(direction.X * direction.X + direction.Z * direction.Z))
    local targetYaw = math.atan2(-direction.X, -direction.Z)
    if noise > 0 then
        local rate = readFlag("aim_noise_speed", 1.4)
        targetPitch += math.rad(noise) * math.noise(now * rate, 11.3) * 2
        targetYaw += math.rad(noise) * math.noise(now * rate, 47.9) * 2
    end

    local look = gameCam:getLookVector()
    if typeof(look) ~= "Vector3" then return end
    local currentPitch = math.atan2(look.Y, math.sqrt(look.X * look.X + look.Z * look.Z))
    local currentYaw = math.atan2(-look.X, -look.Z)
    local deltaPitch = targetPitch - currentPitch
    local deltaYaw = (targetYaw - currentYaw + math.pi) % (math.pi * 2) - math.pi

    local alpha = 1 - math.exp(-dt * 60 / math.max(readFlag("aim_smooth", 12), 1))
    local stepPitch, stepYaw = deltaPitch * alpha, deltaYaw * alpha
    local cap = math.rad(readFlag("aim_speed", 420)) * dt
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
            local radius = readFlag("fov_radius", 120)
            if readFlag("fov_dynamic", false) then
                radius = Aim.target and Aim.radius or readFlag("fov_near", 240)
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

    local active = readFlag("aim_enabled", false) and keyActive("aim_key") and Library.Toggled ~= true and not typing()
    local speed = weaponStat(weapon, "bulletspeed")
    if not (active and weapon and type(speed) == "number") then
        Aim.target = nil
        return
    end
    if readFlag("aim_ads", false) and not weaponAiming(weapon) then Aim.target = nil return end
    if readFlag("aim_shoot", false) and not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then Aim.target = nil return end

    local gameCam = gameCamera()
    if not gameCam then return end
    local origin = cam.CFrame.Position

    local record, part, aimPoint = chooseTarget(records, cam, origin, center, now, weapon)
    if not record then
        Aim.target = nil
        return
    end

    if Aim.target ~= record.player then
        local delay = readFlag("aim_switch", 120) / 1000
        if Aim.target and now - Aim.switchAt < delay then return end
        Aim.target = record.player
        Aim.switchAt = now
        Aim.reactUntil = now + readFlag("aim_react", 60) / 1000
    end
    Aim.part = part
    Aim.radius = dynamicRadius((record.torso.Position - origin).Magnitude, readFlag("aim_dist", 600))
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
    if not readFlag("rcs_hip", true) and not weaponAiming(weapon) then return end

    local vertical, horizontal = readFlag("rcs_v", 70) / 100, readFlag("rcs_h", 40) / 100
    local variation = readFlag("rcs_human", 10) / 100
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
        Trigger.nextAt = now + readFlag("trig_cool", 90) / 1000
    end
    local active = readFlag("trig_enabled", false) and keyActive("trig_key") and Library.Toggled ~= true and not typing()
    if not active or type(mouse1press) ~= "function" then
        Trigger.onSince = nil
        if not active then releaseTrigger() end
        return
    end
    local weapon = activeWeapon()
    if not weapon or type(weaponStat(weapon, "bulletspeed")) ~= "number" then Trigger.onSince = nil return end
    if readFlag("trig_ads", false) and not weaponAiming(weapon) then Trigger.onSince = nil return end

    local origin, direction = cam.CFrame.Position, cam.CFrame.LookVector
    local maxDistance = readFlag("trig_dist", 400)
    local scale = readFlag("trig_scale", 0.9)
    local groups = multi("trig_parts", { Head = true, Torso = true })
    local wantVisible = readFlag("trig_visible", true)

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
    if now - Trigger.onSince < readFlag("trig_delay", 40) / 1000 then return end
    if not weaponCanFire(weapon) then return end
    Trigger.down = true
    Trigger.releaseAt = now + readFlag("trig_hold", 70) / 1000
    pcall(mouse1press)
end

-- ============================================================ ESP
local espObjects = {}
local chamObjects = {}
local chamFolder

local function chamParent()
    if chamFolder and chamFolder.Parent then return chamFolder end
    local parent
    pcall(function() if gethui then parent = gethui() end end)
    if not parent then pcall(function() parent = game:GetService("CoreGui") end) end
    if not parent then return nil end
    chamFolder = Instance.new("Folder")
    chamFolder.Name = "PF_Cham"
    chamFolder.Parent = parent
    return chamFolder
end
onUnload(function()
    for _, highlight in pairs(chamObjects) do pcall(function() highlight:Destroy() end) end
    chamObjects = {}
    if chamFolder then pcall(function() chamFolder:Destroy() end) end
end)

local function makeEsp()
    local object = {
        boxOutline = newDrawing("Square", { Thickness = 3, Filled = false, Color = BLACK, ZIndex = 1 }),
        box = newDrawing("Square", { Thickness = 1, Filled = false, ZIndex = 2 }),
        corners = {},
        name = newDrawing("Text", { Center = true, Outline = true, Size = 13, Font = 2, ZIndex = 4 }),
        info = newDrawing("Text", { Center = true, Outline = true, Size = 13, Font = 2, ZIndex = 4 }),
        hpBack = newDrawing("Square", { Filled = true, Color = BLACK, Transparency = 0.6, ZIndex = 1 }),
        hpFill = newDrawing("Square", { Filled = true, ZIndex = 2 }),
        skeleton = {},
        tracer = newDrawing("Line", { Thickness = 1, ZIndex = 1 }),
        dot = newDrawing("Circle", { Thickness = 1, NumSides = 20, Filled = false, ZIndex = 3 }),
    }
    for index = 1, 8 do object.corners[index] = newDrawing("Line", { Thickness = 1, ZIndex = 2 }) end
    for index = 1, 5 do object.skeleton[index] = newDrawing("Line", { Thickness = 1, ZIndex = 2 }) end
    return object
end

local function hideEsp(object)
    if not object then return end
    setVisible(object.boxOutline, false)
    setVisible(object.box, false)
    setVisible(object.name, false)
    setVisible(object.info, false)
    setVisible(object.hpBack, false)
    setVisible(object.hpFill, false)
    setVisible(object.tracer, false)
    setVisible(object.dot, false)
    for _, line in ipairs(object.corners) do setVisible(line, false) end
    for _, line in ipairs(object.skeleton) do setVisible(line, false) end
end

local function destroyEsp(object)
    if not object then return end
    removeDrawing(object.boxOutline)
    removeDrawing(object.box)
    removeDrawing(object.name)
    removeDrawing(object.info)
    removeDrawing(object.hpBack)
    removeDrawing(object.hpFill)
    removeDrawing(object.tracer)
    removeDrawing(object.dot)
    for _, line in ipairs(object.corners) do removeDrawing(line) end
    for _, line in ipairs(object.skeleton) do removeDrawing(line) end
end

local SKELETON = {
    { "Head", "Torso" }, { "Torso", "Left Arm" }, { "Torso", "Right Arm" }, { "Torso", "Left Leg" }, { "Torso", "Right Leg" },
}

local function project(cam, position)
    local point, onScreen = cam:WorldToViewportPoint(position)
    return Vector2.new(point.X, point.Y), onScreen and point.Z > 0, point.Z
end

local function espStep(cam, now, records, origin)
    local seen = {}
    local enabled = readFlag("esp_enabled", false)
    local chamsOn = readFlag("cham_enabled", false)
    local showTeam = readFlag("esp_team", false)
    local maxDistance = readFlag("esp_dist", 1500)
    local boxMode = readFlag("esp_box", "Full")
    local textSize = readFlag("esp_text", 13)
    local viewport = cam.ViewportSize
    local enemyColor = readFlag("esp_color", Color3.fromRGB(255, 80, 80))
    local teamColor = readFlag("esp_team_color", Color3.fromRGB(90, 200, 120))
    local visibleColor = readFlag("esp_vis_color", Color3.fromRGB(255, 230, 80))
    local useVisible = readFlag("esp_vis", false)
    local wantName, wantHealth, wantDistance, wantWeapon = readFlag("esp_name", true), readFlag("esp_health", true), readFlag("esp_distance", true), readFlag("esp_weapon", false)
    local wantSkeleton, wantDot, wantTracer = readFlag("esp_skeleton", false), readFlag("esp_head", false), readFlag("esp_tracer", false)
    local tracerFrom = readFlag("esp_tracer_from", "Bottom")
    local chamTeam = readFlag("cham_team", false)

    for _, record in ipairs(records) do
        local player = record.player
        seen[player] = true
        local distance = (record.torso.Position - origin).Magnitude
        local show = enabled and distance <= maxDistance and (record.enemy or showTeam)
        local object = espObjects[player]
        if not show then
            hideEsp(object)
        else
            if not object then
                object = makeEsp()
                espObjects[player] = object
            end
            local color = record.enemy and enemyColor or teamColor
            if record.enemy and useVisible and isVisible(record.torso, origin, now) then color = visibleColor end

            local topPoint, topOn = project(cam, record.head.Position + Vector3.new(0, 0.9, 0))
            local lowest = record.torso.Position.Y
            for _, legName in ipairs({ "Left Leg", "Right Leg" }) do
                local leg = record.hash[legName]
                if leg and leg.Parent and leg.Position.Y - leg.Size.Y * 0.5 < lowest then lowest = leg.Position.Y - leg.Size.Y * 0.5 end
            end
            local bottomPoint, bottomOn = project(cam, Vector3.new(record.torso.Position.X, lowest, record.torso.Position.Z))

            if not (topOn and bottomOn) then
                hideEsp(object)
            else
                local height = math.abs(bottomPoint.Y - topPoint.Y)
                local width = height * 0.55
                local centerX = (topPoint.X + bottomPoint.X) * 0.5
                local left, top = centerX - width * 0.5, math.min(topPoint.Y, bottomPoint.Y)

                if boxMode == "Full" then
                    object.boxOutline.Position, object.boxOutline.Size, object.boxOutline.Visible = Vector2.new(left, top), Vector2.new(width, height), true
                    object.box.Position, object.box.Size, object.box.Color, object.box.Visible = Vector2.new(left, top), Vector2.new(width, height), color, true
                else
                    object.boxOutline.Visible, object.box.Visible = false, false
                end
                local corner = math.min(width, height) * 0.28
                local showCorners = boxMode == "Corners"
                local cornerLines = {
                    { Vector2.new(left, top), Vector2.new(left + corner, top) }, { Vector2.new(left, top), Vector2.new(left, top + corner) },
                    { Vector2.new(left + width, top), Vector2.new(left + width - corner, top) }, { Vector2.new(left + width, top), Vector2.new(left + width, top + corner) },
                    { Vector2.new(left, top + height), Vector2.new(left + corner, top + height) }, { Vector2.new(left, top + height), Vector2.new(left, top + height - corner) },
                    { Vector2.new(left + width, top + height), Vector2.new(left + width - corner, top + height) }, { Vector2.new(left + width, top + height), Vector2.new(left + width, top + height - corner) },
                }
                for index, line in ipairs(object.corners) do
                    if line then
                        line.Visible = showCorners
                        if showCorners then line.From, line.To, line.Color = cornerLines[index][1], cornerLines[index][2], color end
                    end
                end

                if wantName and object.name then
                    object.name.Text, object.name.Size, object.name.Color = record.name, textSize, color
                    object.name.Position = Vector2.new(centerX, top - textSize - 3)
                    object.name.Visible = true
                else
                    setVisible(object.name, false)
                end

                local parts = {}
                if wantDistance then parts[#parts + 1] = string.format("%dm", math.floor(distance * 0.28)) end
                if wantWeapon and record.weaponName then parts[#parts + 1] = tostring(record.weaponName) end
                if #parts > 0 and object.info then
                    object.info.Text, object.info.Size, object.info.Color = table.concat(parts, " | "), textSize - 1, WHITE
                    object.info.Position = Vector2.new(centerX, top + height + 2)
                    object.info.Visible = true
                else
                    setVisible(object.info, false)
                end

                if wantHealth and object.hpBack and object.hpFill then
                    local ratio = math.clamp(record.health / math.max(record.maxHealth, 1), 0, 1)
                    object.hpBack.Position, object.hpBack.Size, object.hpBack.Visible = Vector2.new(left - 6, top - 1), Vector2.new(4, height + 2), true
                    object.hpFill.Position = Vector2.new(left - 5, top + height * (1 - ratio))
                    object.hpFill.Size = Vector2.new(2, height * ratio)
                    object.hpFill.Color = Color3.fromRGB(255, 60, 60):Lerp(Color3.fromRGB(80, 255, 110), ratio)
                    object.hpFill.Visible = true
                else
                    setVisible(object.hpBack, false)
                    setVisible(object.hpFill, false)
                end

                for index, pair in ipairs(SKELETON) do
                    local line = object.skeleton[index]
                    if line then
                        local a, b = record.hash[pair[1]], record.hash[pair[2]]
                        if wantSkeleton and a and b and a.Parent and b.Parent then
                            local pa, onA = project(cam, a.Position)
                            local pb, onB = project(cam, b.Position)
                            if onA and onB then
                                line.From, line.To, line.Color, line.Visible = pa, pb, color, true
                            else
                                line.Visible = false
                            end
                        else
                            line.Visible = false
                        end
                    end
                end

                if wantDot and object.dot then
                    local headPoint, headOn = project(cam, record.head.Position)
                    object.dot.Visible = headOn
                    if headOn then
                        object.dot.Position, object.dot.Color = headPoint, color
                        object.dot.Radius = math.max(height * 0.08, 2)
                    end
                else
                    setVisible(object.dot, false)
                end

                if wantTracer and object.tracer then
                    local from = Vector2.new(viewport.X * 0.5, tracerFrom == "Top" and 0 or tracerFrom == "Center" and viewport.Y * 0.5 or viewport.Y)
                    object.tracer.From, object.tracer.To, object.tracer.Color, object.tracer.Visible = from, Vector2.new(centerX, top + height), color, true
                else
                    setVisible(object.tracer, false)
                end
            end
        end

        local highlight = chamObjects[player]
        local chamShow = chamsOn and record.model and record.model.Parent and (record.enemy or chamTeam) and distance <= maxDistance
        if chamShow then
            if not highlight then
                local parent = chamParent()
                if parent then
                    highlight = Instance.new("Highlight")
                    highlight.Name = "PF"
                    highlight.Parent = parent
                    chamObjects[player] = highlight
                end
            end
            if highlight then
                highlight.Adornee = record.model
                highlight.FillColor = record.enemy and readFlag("cham_fill", enemyColor) or teamColor
                highlight.FillTransparency = readFlag("cham_fill_on", true) and readFlag("cham_fill_t", 0.6) or 1
                highlight.OutlineColor = readFlag("cham_line", WHITE)
                highlight.OutlineTransparency = readFlag("cham_line_on", true) and 0 or 1
                highlight.DepthMode = readFlag("cham_walls", true) and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
                highlight.Enabled = true
            end
        elseif highlight then
            highlight.Enabled = false
        end
    end

    for player, object in pairs(espObjects) do
        if not seen[player] then
            destroyEsp(object)
            espObjects[player] = nil
        end
    end
    for player, highlight in pairs(chamObjects) do
        if not seen[player] then
            pcall(function() highlight:Destroy() end)
            chamObjects[player] = nil
        end
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
        if fovCircle then fovCircle.Visible = false end
        for _, object in pairs(espObjects) do hideEsp(object) end
        return
    end

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
    ok, problem = pcall(espStep, cam, now, records, origin)
    if not ok then note("esp" .. tostring(problem), "esp:", problem) end

    if PF_StatusTarget and now - labelClock > 0.2 then
        labelClock = now
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
    local SettingsTab, SettingsSubs = Skin.BuildSettings(LinoriaWindow, { ThemeManager = ThemeManager, SaveManager = SaveManager, Folder = "PhantomPerception", Game = "configs", MenuKey = "Delete" })
    escapeUnbinds("MenuKeybind", "Delete")
    Library:SetWatermark("Phantom")
    Library:SetWatermarkVisibility(true)
end

pcall(function() SaveManager:LoadAutoloadConfig() end)
if not Library.Toggled then pcall(function() Library:Toggle() end) end
Library:Notify("Phantom loaded | core " .. Core.summary, 5)

end, debug.traceback)
if not __ok then
    warn("[Phantom] FAILED:\n" .. tostring(__err))
end
