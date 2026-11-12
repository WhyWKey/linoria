
local BUILD = "phantom-bbot-1"
local SOURCE_URL = ""
local UI_REPO = "https://raw.githubusercontent.com/WhyWKey/linoria/main/"

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer

local __ok, __err = xpcall(function()

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

local Util = { warned = {}, cleanup = {} }

function Util.track(connection)
    table.insert(getgenv().PF_Connections, connection)
    return connection
end

function Util.onUnload(fn)
    table.insert(Util.cleanup, fn)
end

function Util.note(key, ...)
    if Util.warned[key] then return end
    Util.warned[key] = true
    warn("[Aster]", ...)
end

function Util.guard(label, fn, ...)
    local ok, problem = pcall(fn, ...)
    if not ok then Util.note(label .. tostring(problem), label .. ":", problem) end
    return ok
end

function Util.randomName()
    local letters = {}
    for index = 1, 10 do letters[index] = string.char(math.random(97, 122)) end
    return table.concat(letters)
end

function Util.lerp(a, b, t) return a + (b - a) * t end

function Util.lerpColor(a, b, t)
    return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end

function Util.typing()
    return UserInputService:GetFocusedTextBox() ~= nil
end

function Util.hook(owner, key, build)
    if type(owner) ~= "table" then return false end
    local original = owner[key]
    if type(original) ~= "function" then return false end
    local ok = pcall(function() owner[key] = build(original) end)
    if not ok then return false end
    Util.onUnload(function() pcall(function() owner[key] = original end) end)
    return true
end

local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)

local function patchLibrarySource(source)
    local function swap(find, replace)
        local first, last = string.find(source, find, 1, true)
        if first then source = string.sub(source, 1, first - 1) .. replace .. string.sub(source, last + 1) end
    end

    swap("Key = 'MB2';", "Key = 'MB2';\n                elseif Input.UserInputType == Enum.UserInputType.MouseButton3 then\n                    Key = 'MB3';")
    swap("return InputService:IsKeyDown(Enum.KeyCode[KeyPicker.Value]);",
         "if KeyPicker.Value == 'MB3' then return InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton3); end;\n                    return InputService:IsKeyDown(Enum.KeyCode[KeyPicker.Value]);")
    swap("elseif Input.UserInputType == Enum.UserInputType.Keyboard then\n                        if Input.KeyCode.Name == Key then",
         "elseif Key == 'MB3' and Input.UserInputType == Enum.UserInputType.MouseButton3 then\n                        KeyPicker.Toggled = not KeyPicker.Toggled;\n                        KeyPicker:DoClick()\n                    elseif Input.UserInputType == Enum.UserInputType.Keyboard then\n                        if Input.KeyCode.Name == Key then")
    return source
end

local function loadRemote(path, patch)
    local body = game:HttpGet(UI_REPO .. path)
    if patch then
        local okPatch, patched = pcall(patch, body)
        if okPatch and type(patched) == "string" then
            local chunk = loadstring(patched)
            if chunk then return chunk() end
        end
    end
    return loadstring(body)()
end

local Library = loadRemote("Library.lua", patchLibrarySource)
local ThemeManager = loadRemote("addons/ThemeManager.lua")
local SaveManager = loadRemote("addons/SaveManager.lua")

getgenv().Library = Library
local Options, Toggles = getgenv().Options, getgenv().Toggles

Library:OnUnload(function()
    for index = #Util.cleanup, 1, -1 do pcall(Util.cleanup[index]) end
    for _, connection in ipairs(getgenv().PF_Connections or {}) do
        pcall(function() connection:Disconnect() end)
    end
    getgenv().PF_Connections = {}
end)

function Util.flag(name, default)
    local object = Toggles[name]
    if object == nil then object = Options[name] end
    if object == nil or object.Value == nil then return default end
    return object.Value
end
local flag = Util.flag

function Util.opacity(name)
    local option = Options[name]
    if option and type(option.Transparency) == "number" then return 1 - math.clamp(option.Transparency, 0, 1) end
    return 1
end

function Util.alpha(name, default)
    local option = Options[name]
    if option and type(option.Transparency) == "number" then return math.clamp(option.Transparency, 0, 1) end
    return default or 0
end

function Util.toSet(value)
    local out = {}
    if type(value) == "table" then
        for key, on in pairs(value) do
            if type(key) == "number" then out[on] = true elseif on then out[key] = true end
        end
    end
    return out
end

function Util.set(name, fallback)
    return Util.toSet(flag(name, fallback))
end

function Util.keyActive(name)
    local picker = Options[name]
    if picker and type(picker.GetState) == "function" then
        local ok, state = pcall(picker.GetState, picker)
        return ok and state == true
    end
    return true
end

function Util.menuOpen()
    return Library.Toggled == true
end

pcall(function()
    ThemeManager:SetLibrary(Library)
    ThemeManager:SetFolder("Aster/PhantomForces")
    if ThemeManager.SetDefaultTheme then ThemeManager:SetDefaultTheme(getgenv().AsterDefaultTheme or "Spoof") end
    if ThemeManager.PreApply then ThemeManager:PreApply() end
end)

local LibWindow = Library:CreateWindow({
    Title = "Aster",
    Size = UDim2.fromOffset(780, 560),
    Center = true,
    AutoShow = false,
    MenuFadeTime = 0.2,
    UseBlur = false,
    UseDarken = false,
})
pcall(function() Library.ScreenGui.DisplayOrder = 100 end)

local introPlayed = false
if not getgenv().AsterSkipIntro and type(Library.PlayIntro) == "function" then
    introPlayed = pcall(function()
        Library:PlayIntro({
            Title = "ASTER",
            Subtitle = "Aster.lua",
            Duration = 3,
            Steps = { "Loading modules", "Hooking network", "Waiting for game", "Ready" },
            Blur = true,
            OnFinish = function()
                if not Library.Toggled and not Library.Unloaded then Library:Toggle() end
            end,
        })
    end)
end

local UI = {}

local function keyName(key)
    local ok, name = pcall(function() return key.Name end)
    if ok and type(name) == "string" then return name end
    return tostring(key or "None")
end

local function toRounding(decimals)
    if type(decimals) ~= "number" or decimals <= 0 or decimals >= 1 then return 0 end
    return math.clamp(math.floor(-math.log10(decimals) + 0.5), 0, 4)
end

local function escapeUnbinds(name, fallback)
    local picker = Options[name]
    if not picker then return end
    picker:OnChanged(function()
        if picker.Value == "Escape" then
            pcall(function() picker:SetValue({ fallback, picker.Mode }) end)
        end
    end)
end

local wrapGroup

local function wrapElement(object)
    local element = {}
    function element:SetText(text)
        if object.SetText then pcall(function() object:SetText(text) end) end
    end
    function element:Colorpicker(info)
        if not object.AddColorPicker then return element end
        local pickerInfo = { Default = info.Default or WHITE, Title = info.Name or "Color" }
        if info.Alpha then pickerInfo.Transparency = type(info.Alpha) == "number" and info.Alpha or 0 end
        object:AddColorPicker(info.Flag, pickerInfo)
        return element
    end
    function element:Settings(name, width)
        local popup = object:AddSettings(name, { Width = width or 230 })
        return wrapGroup(popup, { load = { 0, 0 } }, 1)
    end
    function element:Keybind(info)
        if not object.AddKeyPicker then return element end
        object:AddKeyPicker(info.Flag, {
            Default = keyName(info.Default),
            Mode = info.Mode or "Toggle",
            Text = info.Name or "Keybind",
            NoUI = false,
            SyncToggleState = info.Sync == true,
        })
        escapeUnbinds(info.Flag, "None")
        return element
    end
    return element
end

function wrapGroup(group, page, side)
    local wrapped = {}
    local function bump() page.load[side] = page.load[side] + 1 end

    function wrapped:Toggle(info)
        bump()
        return wrapElement(group:AddToggle(info.Flag, {
            Text = info.Name, Default = info.Default == true, Tooltip = info.Tooltip, Callback = info.Callback,
        }))
    end
    function wrapped:Slider(info)
        bump()
        group:AddSlider(info.Flag, {
            Text = info.Name, Min = info.Min, Max = info.Max,
            Default = math.clamp(info.Default or info.Min, info.Min, info.Max),
            Rounding = toRounding(info.Decimals), Suffix = info.Suffix or "",
            Compact = false, HideMax = true, Tooltip = info.Tooltip, Callback = info.Callback,
        })
    end
    function wrapped:Dropdown(info)
        bump()
        group:AddDropdown(info.Flag, {
            Text = info.Name, Values = info.Items, Default = info.Default, Multi = info.Multi == true,
            AllowNull = info.Default == nil, Tooltip = info.Tooltip, Callback = info.Callback,
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
            Text = info.Name, Default = info.Default or "", Placeholder = info.Placeholder or "",
            Finished = false, Callback = info.Callback,
        })
    end
    return wrapped
end

local ICON_FALLBACK = "layers"
local function tabIcon(name)
    if type(name) == "string" and Library.IconData and Library.IconData[name] then return name end
    return ICON_FALLBACK
end

local function addBox(owner, column, name, icon)
    if column == 2 and type(owner.AddMiddleGroupbox) == "function" then return owner:AddMiddleGroupbox(name, icon) end
    if column == 3 then return owner:AddRightGroupbox(name, icon) end
    return owner:AddLeftGroupbox(name, icon)
end

local function surface(tab, onBox)
    local state = { load = { 0, 0, 0 } }
    local middle = type(tab.AddMiddleGroupbox) == "function"
    local function pick(column)
        if column == 1 or column == 3 or (column == 2 and middle) then return column end
        if column == nil and middle and state.load[2] < math.min(state.load[1], state.load[3]) then return 2 end
        return state.load[1] <= state.load[3] and 1 or 3
    end
    function state:Section(info)
        local column = pick(info.Column)
        local group = addBox(tab, column, info.Name, info.Icon)
        if onBox then onBox(group.Outer) end
        return wrapGroup(group, state, column)
    end
    function state:MultiSection(info)
        local column = pick(info.Column)
        local sections = {}
        if column == 2 and type(tab.AddMiddleTabbox) ~= "function" then
            for index, name in ipairs(info.Sections) do
                local group = addBox(tab, 2, name, info.Icons and info.Icons[index])
                if onBox then onBox(group.Outer) end
                sections[index] = wrapGroup(group, state, 2)
            end
            return table.unpack(sections)
        end
        local box
        if column == 2 then box = tab:AddMiddleTabbox(info.Name) elseif column == 1 then box = tab:AddLeftTabbox(info.Name) else box = tab:AddRightTabbox(info.Name) end
        if onBox then onBox(box.Outer) end
        for index, name in ipairs(info.Sections) do
            sections[index] = wrapGroup(box:AddTab(name), state, column)
        end
        return table.unpack(sections)
    end
    return state
end

local function wrapPage(tab, pageName)
    local page = surface(tab)

    function page:SubTabs(names)
        local plain, icons = {}, {}
        for index, entry in ipairs(names) do
            if type(entry) == "table" then plain[index], icons[index] = entry[1], entry[2] else plain[index] = entry end
        end
        local subs = {}
        if type(tab.AddSubTab) == "function" then
            for index, name in ipairs(plain) do
                local sub = tab:AddSubTab(name, icons[index])
                subs[name] = surface(sub)
            end
            return subs
        end
        local viewFlag = "ui_view_" .. pageName
        local boxes = {}
        local function show(name)
            for viewName, list in pairs(boxes) do
                for _, frame in ipairs(list) do frame.Visible = viewName == name end
            end
        end
        local baseSearch = Library.ApplySearch
        if type(baseSearch) == "function" then
            function Library:ApplySearch(...)
                baseSearch(self, ...)
                local option = Options[viewFlag]
                show(option and option.Value or plain[1])
            end
        end
        local selector = tab:AddLeftGroupbox(pageName .. " view", "list")
        selector:AddDropdown(viewFlag, { Text = "Section", Values = plain, Default = plain[1], Callback = show })
        for _, name in ipairs(plain) do
            boxes[name] = {}
            local sub = surface(tab, function(frame)
                table.insert(boxes[name], frame)
                local option = Options[viewFlag]
                frame.Visible = (option and option.Value or plain[1]) == name
            end)
            sub.load[1] = 2
            subs[name] = sub
        end
        return subs
    end
    return page
end

function UI.page(name, icon)
    return wrapPage(LibWindow:AddTab(name, tabIcon(icon)), name)
end

print("[Aster] build " .. BUILD)

local Game = { ready = false, mods = {}, via = {}, missing = {}, frame = 0, accel = Vector3.new(0, -196.2, 0), hooked = {} }

local REQUIRED = { "ReplicationInterface", "CharacterInterface", "CameraInterface" }
local OPTIONAL = { "PublicSettings", "NetworkClient", "HudCrosshairsInterface", "HudDamageInterface", "BulletInterface", "PlayerStatusEvents", "ContentInterface",
    "CharacterObject", "ActiveLoadoutUtils", "PlayerDataClientInterface", "PlayerDataUtils", "SkinCaseUtils", "FirearmObject", "MeleeObject", "GrenadeObject",
    "HudScreenGui", "PlayerSettingsInterface" }

function Game.load()
    Game.ready, Game.mods, Game.via, Game.missing = false, {}, {}, {}
    local requireFn
    pcall(function() requireFn = getrenv().shared.require end)

    local scripts = {}
    if type(getloadedmodules) == "function" then
        pcall(function()
            for _, module in ipairs(getloadedmodules()) do
                if not scripts[module.Name] then scripts[module.Name] = module end
            end
        end)
    end

    local function fetch(name)
        if type(requireFn) == "function" then
            local ok, module = pcall(requireFn, name)
            if ok and type(module) == "table" then return module, "shared.require" end
        end
        local script = scripts[name]
        if script then
            local ok, module = pcall(require, script)
            if ok and type(module) == "table" then return module, "module script" end
        end
        return nil
    end

    for _, list in ipairs({ REQUIRED, OPTIONAL }) do
        for _, name in ipairs(list) do
            Game.mods[name], Game.via[name] = fetch(name)
        end
    end

    local gaps = false
    for _, name in ipairs(REQUIRED) do if not Game.mods[name] then gaps = true end end
    local scanNow = os.clock()
    if gaps and type(getgc) == "function" and scanNow - (Game.scanAt or -math.huge) >= 30 then
        Game.scanAt = scanNow
        pcall(function()
            for _, value in ipairs(getgc(true)) do
                if type(value) == "table" then
                    if not Game.mods.ReplicationInterface and rawget(value, "operateOnAllEntries") and rawget(value, "getEntry") then
                        Game.mods.ReplicationInterface, Game.via.ReplicationInterface = value, "gc"
                    elseif not Game.mods.CharacterInterface and rawget(value, "getCharacterObject") and rawget(value, "isAlive") then
                        Game.mods.CharacterInterface, Game.via.CharacterInterface = value, "gc"
                    elseif not Game.mods.CameraInterface and rawget(value, "getActiveCamera") and rawget(value, "setCameraType") then
                        Game.mods.CameraInterface, Game.via.CameraInterface = value, "gc"
                    elseif not Game.mods.PublicSettings and rawget(value, "bulletAcceleration") then
                        Game.mods.PublicSettings, Game.via.PublicSettings = value, "gc"
                    end
                end
            end
        end)
    end

    for _, name in ipairs(REQUIRED) do
        if not Game.mods[name] then table.insert(Game.missing, name) end
    end
    Game.ready = #Game.missing == 0

    local settings = Game.mods.PublicSettings
    if settings and typeof(settings.bulletAcceleration) == "Vector3" then Game.accel = settings.bulletAcceleration end

    if Game.ready then
        local vias, list = {}, {}
        for _, name in ipairs(REQUIRED) do vias[Game.via[name]] = true end
        for via in pairs(vias) do table.insert(list, via) end
        table.sort(list)
        Game.summary = "loaded (" .. table.concat(list, ", ") .. ")"
    else
        Game.summary = "missing " .. table.concat(Game.missing, ", ")
        Util.note("core", "Core modules not found:", table.concat(Game.missing, ", "), "| executor:", tostring(identifyexecutor and identifyexecutor() or "unknown"))
    end
end

function Game.camera()
    return Workspace.CurrentCamera
end

local PhantomCam = { api = nil, failed = false, retryAt = 0 }

local Stretch = { base = nil, written = nil, eye = nil }

local function sameFrame(a, b)
    return a.Position == b.Position and a.LookVector == b.LookVector and a.UpVector == b.UpVector and a.RightVector == b.RightVector
end

function Stretch.cf(cam)
    return Stretch.base or cam.CFrame
end

function Stretch.restore(cam)
    local base, written = Stretch.base, Stretch.written
    Stretch.base, Stretch.written, Stretch.eye = nil, nil, nil
    if base and written and cam then
        pcall(function()
            if sameFrame(cam.CFrame, written) then cam.CFrame = base end
        end)
    end
end

function Stretch.apply(cam)
    Stretch.restore(cam)
    if not cam or not flag("world_stretch", false) then return end
    pcall(function()
        local sx, sy = math.clamp(flag("world_stretch_x", 0.75), 0.3, 1.27), math.clamp(flag("world_stretch_y", 1), 0.3, 1.2)
        if math.abs(sx - 1) < 1e-3 and math.abs(sy - 1) < 1e-3 then return end
        local base = cam.CFrame
        local api = PhantomCam.api
        local frame = api and api.GameCFrame()
        cam.CFrame = base * CFrame.new(0, 0, 0, sx, 0, 0, 0, sy, 0, 0, 0, 1)
        Stretch.base, Stretch.written = base, cam.CFrame
        Stretch.eye = typeof(frame) == "CFrame" and frame or base
    end)
end

function Game.eye(cam)
    if Stretch.eye then return Stretch.eye end
    local api = PhantomCam.api
    local frame = api and api.GameCFrame()
    if typeof(frame) == "CFrame" then return frame end
    return cam.CFrame
end

Game.mapSnap = setmetatable({}, { __mode = "k" })

function Game.isGlass(part)
    if not flag("vis_ignore_glass", true) then return false end
    local ok, glass = pcall(function()
        local snap = Game.mapSnap[part]
        local material = snap and snap.Material or part.Material
        local transparency = snap and snap.Transparency or part.Transparency
        if material == Enum.Material.Glass then return true end
        local name = string.lower(part.Name)
        return transparency > 0 and (string.find(name, "glass", 1, true) ~= nil or string.find(name, "window", 1, true) ~= nil)
    end)
    return ok and glass == true
end

function Game.skipHit(part)
    local ok, skip = pcall(function() return part.CanCollide == false or part.Transparency >= 1 end)
    if ok and skip then return true end
    return Game.isGlass(part)
end

function Game.cast(origin, vector, params, skip)
    skip = skip or Game.skipHit
    local from, remaining = origin, vector
    for _ = 1, 16 do
        local hit = Workspace:Raycast(from, remaining, params)
        if not hit then return nil end
        local instance = hit.Instance
        if instance == nil or not skip(instance) then return hit end
        local rest = remaining - (hit.Position - from)
        local length = rest.Magnitude
        if length < 0.05 then return nil end
        from = hit.Position + rest * (0.02 / length)
        remaining = rest - rest * (0.02 / length)
    end
    return nil
end

function Game.gameCamera()
    local interface = Game.mods.CameraInterface
    if not interface then return nil end
    local ok, object = pcall(interface.getActiveCamera, "MainCamera", true)
    if ok and type(object) == "table" and object.setLookVector then return object end
    return nil
end

function Game.localAlive()
    local interface = Game.mods.CharacterInterface
    if not interface then return false end
    local ok, alive = pcall(interface.isAlive)
    return ok and alive == true
end

local weaponFrame, weaponCache = -1, nil
function Game.weapon()
    if weaponFrame == Game.frame then return weaponCache end
    weaponFrame, weaponCache = Game.frame, nil
    local interface = Game.mods.CharacterInterface
    if interface and Game.localAlive() then
        local ok, weapon = pcall(function()
            local character = interface.getCharacterObject()
            local controller = character and character:getWeaponController()
            return controller and controller:getActiveWeapon()
        end)
        if ok and type(weapon) == "table" then weaponCache = weapon end
    end
    return weaponCache
end

function Game.stat(weapon, name)
    if type(weapon) ~= "table" or type(weapon.getWeaponStat) ~= "function" then return nil end
    local ok, value = pcall(weapon.getWeaponStat, weapon, name)
    if ok then return value end
    return nil
end

function Game.aiming(weapon)
    if type(weapon) ~= "table" or type(weapon.isAiming) ~= "function" then return false end
    local ok, state = pcall(weapon.isAiming, weapon)
    return ok and state == true
end

function Game.zoom(weapon)
    if type(weapon) ~= "table" or type(weapon.getActiveAimStats) ~= "function" then return nil end
    local ok, stats = pcall(weapon.getActiveAimStats, weapon)
    if not ok or type(stats) ~= "table" then return nil end
    local total, found = 1, false
    for _, stat in ipairs(stats) do
        local magnify, aimed = type(stat.sightmagspring) == "table" and stat.sightmagspring.p, type(stat.sightaimspring) == "table" and stat.sightaimspring.p
        local zoom = stat.zoom
        if stat.blackscope and type(aimed) == "number" and aimed <= (stat.scopebegin or 0.9) and type(stat.prezoom) == "number" then zoom = stat.prezoom end
        if type(zoom) == "number" and zoom > 0 and type(magnify) == "number" then
            total = total * zoom ^ math.clamp(magnify, 0, 1)
            found = true
        end
    end
    if not found then return nil end
    return math.max(total, 1)
end

function Game.cameraZoom()
    local camera = Game.gameCamera()
    local spring = camera and camera._magSpring
    local value = type(spring) == "table" and spring.p
    if type(value) ~= "number" then return 1 end
    return math.max(math.exp(value), 1)
end

function Game.canFire(weapon)
    if type(weapon) ~= "table" or type(weapon.canFire) ~= "function" then return true end
    local ok, state = pcall(weapon.canFire, weapon)
    return ok and state and true or false
end

function Game.isFirearm(weapon)
    return type(Game.stat(weapon, "bulletspeed")) == "number"
end

function Game.fireMode(weapon)
    if type(weapon) ~= "table" then return nil end
    local ok, mode = pcall(function()
        if type(weapon.getFiremode) == "function" then return weapon:getFiremode() end
        local modes = Game.stat(weapon, "firemodes")
        return type(modes) == "table" and modes[weapon._firemodeIndex or 1] or nil
    end)
    if not ok or mode == nil then return nil end
    if mode == true then return "auto" end
    if mode == 1 or mode == "SINGLE" or mode == "DOUBLE" or mode == "BINARY" then return "semi" end
    if mode == "SWITCH" or (type(mode) == "number" and mode > 1) then return "burst" end
    return nil
end

local CLASS_BY_TYPE = {
    PISTOL = "pistol", PISTOLS = "pistol", REVOLVER = "pistol", REVOLVERS = "pistol",
    SMG = "smg", PDW = "smg", ["MACHINE PISTOL"] = "smg", ["MACHINE PISTOLS"] = "smg",
    ASSAULT = "rifle", ["ASSAULT RIFLE"] = "rifle", CARBINE = "rifle", BATTLE = "rifle", ["BATTLE RIFLE"] = "rifle",
    LMG = "lmg", SNIPER = "sniper", ["SNIPER RIFLE"] = "sniper", DMR = "sniper", SHOTGUN = "shotgun",
}

local CLASS_BY_NAME = {
    G18 = "smg", MP5K = "smg", MP7 = "smg", MP10 = "smg", P90 = "smg", UMP45 = "smg", MAC10 = "smg", ["KRISS VECTOR"] = "smg", VECTOR = "smg",
    M9 = "pistol", M1911 = "pistol", ["DESERT EAGLE"] = "pistol", DEAGLE = "pistol",
    M4A1 = "rifle", AK47 = "rifle", AK12 = "rifle", M16A3 = "rifle", SCAR = "rifle", G36 = "rifle",
    M249 = "lmg", MG42 = "lmg", RPK = "lmg",
    AWM = "sniper", INTERVENTION = "sniper", DRAGUNOV = "sniper", M14 = "sniper", MK11 = "sniper",
    REMINGTON870 = "shotgun", M1014 = "shotgun", SPAS12 = "shotgun", ["MODEL 870"] = "shotgun",
}

local classCache = setmetatable({}, { __mode = "k" })

function Game.weaponClass(weapon)
    if type(weapon) ~= "table" then return nil end
    local cached = classCache[weapon]
    if cached ~= nil then return cached or nil end
    local class
    if Game.isFirearm(weapon) then
        local name = type(weapon.weaponName) == "string" and weapon.weaponName:upper() or nil
        class = name and CLASS_BY_NAME[name]
        if not class then
            local kind = Game.stat(weapon, "type")
            if kind == nil and type(weapon.getWeaponType) == "function" then
                local ok, value = pcall(weapon.getWeaponType, weapon)
                if ok then kind = value end
            end
            class = type(kind) == "string" and CLASS_BY_TYPE[kind:upper()] or nil
        end
    end
    classCache[weapon] = class or false
    return class
end

function Game.time()
    local network = Game.mods.NetworkClient
    if type(network) == "table" and type(network.getTime) == "function" then
        local ok, value = pcall(network.getTime, network)
        if ok and type(value) == "number" then return value end
    end
    return os.clock()
end

function Game.rootPart()
    local interface = Game.mods.CharacterInterface
    if not (interface and Game.localAlive()) then return nil end
    local ok, root = pcall(function() return interface.getCharacterObject():getRootPart() end)
    if ok and typeof(root) == "Instance" then return root end
    return nil
end

function Game.isEnemy(entry, player)
    local ok, enemy = pcall(entry.isEnemy, entry)
    if ok and type(enemy) == "boolean" then return enemy end
    return player.TeamColor ~= LocalPlayer.TeamColor
end

function Game.hookNetwork()
    local network = Game.mods.NetworkClient
    if Game.hooked.network or type(network) ~= "table" then return end
    Game.hooked.network = Util.hook(network, "send", function(original)
        return function(self, method, ...)
            if method == "debug" or method == "flaguser" then return nil end
            if Game.filterSend and Game.filterSend(method, ...) then return nil end
            if method == "newbullets" and Game.onNewBullets then
                local _, packet = ...
                pcall(Game.onNewBullets, packet)
            end
            return original(self, method, ...)
        end
    end)
end

Game.load()
Game.hookNetwork()
if type(Game.mods.NetworkClient) ~= "table" then
    Util.note("netclient", "NetworkClient not found: flaguser filter not installed")
    pcall(function() Library:Notify("NetworkClient not loaded - flaguser filter inactive", 6) end)
end

local Entities = { list = {}, byPlayer = {}, frame = -1 }

local PART_NAMES = { "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }

local PART_SIZES = {
    Head = Vector3.new(2, 1, 1), Torso = Vector3.new(2, 2, 1),
    ["Left Arm"] = Vector3.new(1, 2, 1), ["Right Arm"] = Vector3.new(1, 2, 1),
    ["Left Leg"] = Vector3.new(1, 2, 1), ["Right Leg"] = Vector3.new(1, 2, 1),
}

local Visible

local HIST_WINDOW, HIST_STEP, MAX_TRACK_SPEED = 0.3, 0.03, 60

function Entities.track(record, position, now)
    local hist = record.hist
    if not hist then
        hist = { head = 1, tail = 0 }
        record.hist = hist
    end
    local last = hist[hist.tail]
    if last and (now < last.t or (position - last.p).Magnitude > 20) then
        record.hist = nil
        record.vel = nil
        return Entities.track(record, position, now)
    end
    if not last or now - last.t >= HIST_STEP then
        hist.tail = hist.tail + 1
        hist[hist.tail] = { t = now, p = position }
    end
    while hist.tail - hist.head > 1 and now - hist[hist.head].t > HIST_WINDOW do
        hist[hist.head] = nil
        hist.head = hist.head + 1
    end
    local first, newest = hist[hist.head], hist[hist.tail]
    local span = newest.t - first.t
    if span >= 0.08 and span <= HIST_WINDOW * 1.5 then
        local velocity = (newest.p - first.p) / span
        if velocity.Magnitude > MAX_TRACK_SPEED then velocity = velocity.Unit * MAX_TRACK_SPEED end
        record.vel = velocity
    else
        record.vel = nil
    end
end

function Entities.update()
    if Entities.frame == Game.frame then return Entities.list end
    Entities.frame = Game.frame
    local list = {}
    Entities.list = list
    for _, record in pairs(Entities.byPlayer) do record.seen = false end
    local interface = Game.mods.ReplicationInterface
    if not interface then return list end

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

        local record = Entities.byPlayer[player]
        if not record then
            record = { player = player, name = player.Name }
            Entities.byPlayer[player] = record
        end
        record.seen = true
        record.entry, record.hash, record.torso, record.head, record.object = entry, hash, torso, head, object
        record.rendered, record.pos = rendered, position
        record.enemy = Game.isEnemy(entry, player)

        local health, maxHealth = 100, 100
        local okHealth, current, maximum = pcall(entry.getHealth, entry)
        if okHealth and type(current) == "number" then health, maxHealth = current, maximum or 100 end
        record.health, record.maxHealth = health, maxHealth

        local spring = entry._velspring
        local velocity = spring and spring.p
        record.velocity = typeof(velocity) == "Vector3" and velocity or Vector3.zero
        Entities.track(record, position, os.clock())

        record.weaponName, record.weaponObject = nil, nil
        if rendered then
            pcall(function()
                local weapon = entry:getWeaponObject()
                record.weaponName = weapon and weapon.weaponName
                record.weaponObject = weapon
            end)
        end
        local okModel, model = pcall(object.getCharacterModel, object)
        record.model = (typeof(object._characterModel) == "Instance" and object._characterModel) or (okModel and typeof(model) == "Instance" and model) or torso.Parent
        if record.model then Visible.bodies[record.model] = true end

        list[#list + 1] = record
    end)

    for player, record in pairs(Entities.byPlayer) do
        if not record.seen then
            record.gone = record.gone or os.clock()
            if os.clock() - record.gone > 5 then Entities.byPlayer[player] = nil end
        else
            record.gone = nil
        end
    end
    return list
end

Visible = { cache = setmetatable({}, { __mode = "k" }), bodies = setmetatable({}, { __mode = "k" }), nextFilter = 0, budget = 0 }
Visible.params = RaycastParams.new()
Visible.params.FilterType = Enum.RaycastFilterType.Exclude
pcall(function() Visible.params.RespectCanCollide = true end)
pcall(function() Visible.params.IgnoreWater = true end)
Visible.exitParams = RaycastParams.new()
Visible.exitParams.FilterType = Enum.RaycastFilterType.Include
pcall(function() Visible.exitParams.IgnoreWater = true end)

function Visible.refresh(now)
    Visible.budget = 48
    if now < Visible.nextFilter then return end
    Visible.nextFilter = now + 1
    local list = {}
    local function add(instance)
        if typeof(instance) == "Instance" then list[#list + 1] = instance end
    end
    add(Game.camera())
    add(Workspace.Terrain)
    for _, name in ipairs({ "Ignore", "Players", "Roots" }) do add(Workspace:FindFirstChild(name)) end
    local root = Game.rootPart()
    if root then add(root.Parent) end
    pcall(function() add(LocalPlayer.Character) end)
    Visible.params.FilterDescendantsInstances = list
end

function Visible.skip(part)
    return Game.skipHit(part) or Visible.bodies[part.Parent] ~= nil
end

function Visible.check(part, origin, now)
    local cached = Visible.cache[part]
    if cached and now - cached[1] < 0.06 then return cached[2] end
    local hit = Game.cast(origin, (part.Position - origin) * 0.998, Visible.params, Visible.skip)
    local result = hit == nil
    Visible.cache[part] = { now, result }
    return result
end

function Visible.exit(position, unit, instance)
    local ok, size = pcall(function() return instance.Size.Magnitude end)
    if not ok or type(size) ~= "number" then return nil end
    Visible.exitParams.FilterDescendantsInstances = { instance }
    return Workspace:Raycast(position + unit * size, -unit * size, Visible.exitParams)
end

function Visible.trace(origin, point, depth)
    local vector = (point - origin) * 0.998
    local length = vector.Magnitude
    if length < 0.05 then return 0, 0 end
    local unit = vector / length
    local from, remaining = origin, vector
    local left, total, walls, seen = depth or 0, 0, 0, {}
    for _ = 1, 12 do
        local hit = Workspace:Raycast(from, remaining, Visible.params)
        if not hit then return total, walls end
        local instance = hit.Instance
        if instance == nil or (not seen[instance] and not Visible.skip(instance)) then
            if instance ~= nil then seen[instance] = true end
            walls = walls + 1
            if not depth then return nil end
            local exit = instance ~= nil and Visible.exit(hit.Position, unit, instance)
            if exit then
                local thickness = unit:Dot(exit.Position - hit.Position)
                total = total + thickness
                left = left - thickness
                if left < 0 then return nil end
            end
        end
        local rest = remaining - (hit.Position - from)
        local restLength = rest.Magnitude
        if restLength < 0.05 then return total, walls end
        from = hit.Position + rest * (0.02 / restLength)
        remaining = rest - rest * (0.02 / restLength)
    end
    return nil
end

local VIS_ORDER = { "Head", "Torso", "Right Leg", "Left Arm", "Left Leg", "Right Arm" }

function Visible.entity(record, origin, now, interval)
    local cached = record.visCache
    if cached and (cached.frame == Game.frame or now - cached.at < interval) then return cached.value end
    local value = false
    if record.rendered then
        for index = 1, math.clamp(math.floor(flag("vis_rays", 3)), 1, #VIS_ORDER) do
            local part = record.hash[VIS_ORDER[index]]
            if part and part.Parent and Visible.trace(origin, part.Position) then
                value = true
                break
            end
        end
    end
    record.visCache = { at = now, frame = Game.frame, value = value }
    return value
end

local Draw = { all = {}, hasApi = (type(Drawing) == "table" or type(Drawing) == "userdata") }
local SINK = setmetatable({}, { __newindex = function() end })

function Draw.new(kind, props)
    if not Draw.hasApi then return SINK end
    local ok, object = pcall(Drawing.new, kind)
    if not ok or not object then return SINK end
    for key, value in pairs(props or {}) do pcall(function() object[key] = value end) end
    Draw.all[object] = true
    return object
end

function Draw.remove(object)
    if not object or object == SINK then return end
    Draw.all[object] = nil
    pcall(function() object:Remove() end)
end

function Draw.text(size, zindex)
    return Draw.new("Text", { Size = size or 13, Font = 2, Center = true, Outline = true, OutlineColor = BLACK, ZIndex = zindex or 8, Visible = false })
end

Util.onUnload(function()
    for object in pairs(Draw.all) do pcall(function() object:Remove() end) end
    Draw.all = {}
end)

local Icons = {
    data = {}, ratio = {}, asset = {}, busy = {}, retry = {}, bound = setmetatable({}, { __mode = "k" }),
    folder = "Aster/PhantomForces/icons", prefix = "csgo_v1_", cooldown = 30, dataOk = true, colorOk = true,
}

local WEAPON_ICON = {
    AK47 = "ak47", AK12 = "ak47", AK74 = "ak47", AKS74U = "ak47", AN94 = "ak47", ASVAL = "galilar", VAL = "galilar",
    M4 = "m4a1", M4A1 = "m4a1", M16 = "m4a1", M16A3 = "m4a1", M16A4 = "m4a1", HK416 = "m4a1_silencer", SCARL = "m4a1", SCAR = "m4a1",
    SCARH = "scar20", G36 = "sg556", G36C = "sg556", AUG = "aug", AUGA3 = "aug", FAL = "galilar", FAL5000 = "galilar", L85A2 = "famas", L85 = "famas",
    MP5 = "mp5sd", MP5K = "mp7", MP7 = "mp7", MP10 = "mac10", MAC10 = "mac10", UMP45 = "ump45", UMP = "ump45", P90 = "p90",
    VECTOR = "mp9", KRISSVECTOR = "mp9", BIZON = "bizon", PPSH = "bizon", MP9 = "mp9", TEC9 = "tec9",
    G18 = "glock", G17 = "glock", GLOCK = "glock", GLOCK17 = "glock", GLOCK18 = "glock", M9 = "p2000", M1911 = "p250", P226 = "usp_silencer", USP = "usp_silencer",
    FN57 = "fiveseven", FIVESEVEN = "fiveseven", DEAGLE = "deagle", DESERTEAGLE = "deagle", PYTHON = "revolver", REVOLVER = "revolver", M29 = "revolver", MAGNUM = "revolver",
    REMINGTON870 = "nova", MODEL870 = "nova", R870 = "nova", ["870"] = "nova", KSG12 = "xm1014", KSG = "xm1014", SAIGA12 = "xm1014", M1014 = "xm1014",
    SPAS12 = "mag7", DBS = "sawedoff", DB = "sawedoff", SAWEDOFF = "sawedoff",
    INTERVENTION = "awp", AWM = "awp", M98B = "awp", BARRETT = "awp", M82 = "awp", M700 = "ssg08", MOSIN = "ssg08", MOSINNAGANT = "ssg08", M24 = "ssg08",
    DRAGUNOV = "g3sg1", SVD = "g3sg1", MK11 = "g3sg1", M14 = "g3sg1", SKS = "g3sg1",
    M249 = "m249", RPK = "negev", MG42 = "negev", MG36 = "negev", PKM = "negev", M60 = "negev",
    TASER = "taser", C4 = "c4",
}

local CLASS_ICON = {
    pistol = "class_pistol", smg = "class_smg", rifle = "class_rifle", sniper = "class_sniper", shotgun = "class_shotgun", lmg = "class_lmg",
}

function Icons.norm(name)
    return (tostring(name):upper():gsub("[^%w]", ""))
end

function Icons.weaponKey(name, weapon)
    if type(name) ~= "string" or name == "" then return nil end
    local norm = Icons.norm(name)
    local key = WEAPON_ICON[norm]
    if key then return key end
    if norm:find("KNIFE", 1, true) or norm:find("KARAMBIT", 1, true) or norm:find("MACHETE", 1, true) then return "knife" end
    local class = CLASS_BY_NAME[name:upper()] or CLASS_BY_NAME[norm]
    if not class and weapon then class = Game.weaponClass(weapon) end
    return class and CLASS_ICON[class] or nil
end

function Icons.grenadeKey(name)
    local norm = type(name) == "string" and Icons.norm(name) or ""
    if norm:find("FLASH", 1, true) then return "flashbang" end
    if norm:find("SMOKE", 1, true) then return "smokegrenade" end
    if norm:find("MOLOTOV", 1, true) or norm:find("INCEN", 1, true) then return "molotov" end
    if norm:find("STUN", 1, true) or norm:find("IMPACT", 1, true) or norm:find("DECOY", 1, true) then return "decoy" end
    return "hegrenade"
end

function Icons.valid(data)
    return type(data) == "string" and #data > 64 and string.sub(data, 2, 4) == "PNG"
end

local function beUint(data, at)
    local a, b, c, d = string.byte(data, at, at + 3)
    return ((a * 256 + b) * 256 + c) * 256 + d
end

function Icons.warn(reason)
    if Icons.warned then return end
    Icons.warned = true
    warn("[Aster] icons: " .. reason)
end

function Icons.labelMode()
    if Icons.labels == nil then Icons.labels = type(getcustomasset) == "function" and type(writefile) == "function" end
    return Icons.labels
end

function Icons.fetch(url)
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if ok and Icons.valid(body) then return body end
    local send = (type(request) == "function" and request) or (type(http_request) == "function" and http_request) or (type(syn) == "table" and syn.request) or nil
    if send then
        local sent, response = pcall(send, { Url = url, Method = "GET" })
        local data = sent and type(response) == "table" and response.Body
        if Icons.valid(data) then return data end
    end
    return nil
end

function Icons.ensureFolder()
    if type(makefolder) ~= "function" then return end
    local built = ""
    for part in string.gmatch(Icons.folder, "[^/]+") do
        built = built == "" and part or (built .. "/" .. part)
        local exists = false
        if type(isfolder) == "function" then pcall(function() exists = isfolder(built) == true end) end
        if not exists then pcall(makefolder, built) end
    end
end

function Icons.container()
    if Icons.gui and Icons.gui.Parent then return Icons.gui end
    if setthreadidentity then pcall(setthreadidentity, 7) end
    local parents = {}
    pcall(function() parents[#parents + 1] = game:GetService("CoreGui") end)
    pcall(function() if gethui then parents[#parents + 1] = gethui() end end)
    for _, parent in ipairs(parents) do
        local gui
        local ok = pcall(function()
            gui = Instance.new("ScreenGui")
            gui.Name = Util.randomName()
            gui.DisplayOrder = 9
            gui.IgnoreGuiInset = true
            gui.ResetOnSpawn = false
            gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
            gui.Parent = parent
        end)
        if ok and gui and gui.Parent then
            Icons.gui = gui
            return gui
        end
        if gui then pcall(function() gui:Destroy() end) end
    end
    Icons.warn("no gui container for icon images")
    return nil
end

function Icons.store(key, data, asset)
    local width, height = beUint(data, 17), beUint(data, 21)
    if width < 1 or height < 1 then return false end
    Icons.data[key], Icons.ratio[key], Icons.asset[key] = data, width / height, asset
    return true
end

function Icons.load(key)
    local file = key .. ".png"
    local path = Icons.folder .. "/" .. Icons.prefix .. file
    local labels = Icons.labelMode()
    local body, cached
    if type(isfile) == "function" and type(readfile) == "function" then
        local ok, data = pcall(function() return isfile(path) and readfile(path) or nil end)
        if ok and Icons.valid(data) then body, cached = data, true end
    end
    if not body then
        body = Icons.fetch(UI_REPO .. "icons/" .. file)
        if not body then
            Icons.warn("download failed for " .. file)
            return false
        end
    end
    local asset
    if labels then
        if not cached then
            Icons.ensureFolder()
            local ok, err = pcall(writefile, path, body)
            if not ok then
                Icons.warn("write failed (" .. tostring(err) .. ")")
                return false
            end
        end
        local ok, result = pcall(getcustomasset, path)
        if not (ok and type(result) == "string" and result ~= "") then
            Icons.warn("getcustomasset failed (" .. tostring(result) .. ")")
            return false
        end
        asset = result
    end
    return Icons.store(key, body, asset)
end

function Icons.get(key)
    if type(key) ~= "string" then return nil end
    local data = Icons.data[key]
    if data then return data, Icons.ratio[key] end
    if Icons.busy[key] or (Icons.retry[key] and os.clock() < Icons.retry[key]) then return nil end
    Icons.busy[key] = true
    task.spawn(function()
        local ok, loaded = pcall(Icons.load, key)
        if not ok then Icons.warn("load error (" .. tostring(loaded) .. ")") end
        Icons.busy[key] = nil
        if not (ok and loaded) then Icons.retry[key] = os.clock() + Icons.cooldown end
    end)
    local ready = Icons.data[key]
    if ready then return ready, Icons.ratio[key] end
    return nil
end

local function setData(object, data) object.Data = data end
local function setColor(object, color) object.Color = color end

function Icons.place(image, key, cx, cy, maxW, maxH, color, alpha)
    if image == SINK or not Icons.dataOk then return false end
    local data, ratio = Icons.get(key)
    if not data then return false end
    local isLabel = type(image) == "table" and rawget(image, "_label") ~= nil
    if Icons.bound[image] ~= key then
        local payload = isLabel and Icons.asset[key] or data
        if not payload then return false end
        local bound
        if isLabel then bound = pcall(rawget(image, "_bind"), payload) else bound = pcall(setData, image, payload) end
        if not bound then
            Icons.warn(isLabel and "image label rejected the asset" or "Drawing Image has no Data support")
            Icons.dataOk = false
            return false
        end
        Icons.bound[image] = key
    end
    local height = math.floor(math.min(maxH, maxW / ratio) + 0.5)
    local width = math.floor(height * ratio + 0.5)
    image.Size = Vector2.new(width, height)
    image.Position = Vector2.new(math.floor(cx - width / 2 + 0.5), math.floor(cy - height / 2 + 0.5))
    if Icons.colorOk and not pcall(setColor, image, color) then Icons.colorOk = false end
    image.Transparency, image.Visible = alpha or 1, true
    return true
end

function Icons.label(zindex)
    local gui = Icons.container()
    if not gui then return nil end
    local label
    local ok = pcall(function()
        label = Instance.new("ImageLabel")
        label.Name = Util.randomName()
        label.BackgroundTransparency = 1
        label.BorderSizePixel = 0
        label.ScaleType = Enum.ScaleType.Fit
        label.ZIndex = zindex
        label.Visible = false
        label.Parent = gui
    end)
    if not (ok and label) then return nil end
    local proxy = {}
    local apply = {
        Visible = function(value) label.Visible = value end,
        Color = function(value) label.ImageColor3 = value end,
        Transparency = function(value) label.ImageTransparency = 1 - value end,
        Size = function(value) label.Size = UDim2.new(0, value.X, 0, value.Y) end,
        Position = function(value) label.Position = UDim2.new(0, value.X, 0, value.Y) end,
        ZIndex = function(value) label.ZIndex = value end,
    }
    rawset(proxy, "_label", label)
    rawset(proxy, "_bind", function(asset) label.Image = asset end)
    rawset(proxy, "Remove", function() pcall(function() label:Destroy() end) end)
    return setmetatable(proxy, { __newindex = function(_, prop, value)
        local set = apply[prop]
        if set then pcall(set, value) end
    end })
end

function Draw.image(zindex)
    zindex = zindex or 8
    if Icons.labelMode() then
        local proxy = Icons.label(zindex)
        if proxy then
            Draw.all[proxy] = true
            return proxy
        end
    end
    return Draw.new("Image", { Transparency = 1, ZIndex = zindex, Visible = false })
end

Util.onUnload(function()
    if Icons.gui then pcall(function() Icons.gui:Destroy() end) end
    Icons.gui = nil
end)

function Draw.project(cam, position)
    local point = cam:WorldToViewportPoint(position)
    return Vector2.new(point.X, point.Y), point.Z > 0, point.Z
end

local Barrel = { valid = false, paramsAt = 0 }

function Barrel.refreshParams(now)
    if Barrel.params and now < Barrel.paramsAt then return end
    Barrel.paramsAt = now + 1
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    pcall(function() params.RespectCanCollide = true end)
    pcall(function() params.IgnoreWater = true end)
    local list = {}
    local function add(instance)
        if typeof(instance) == "Instance" then list[#list + 1] = instance end
    end
    add(Game.camera())
    add(Workspace:FindFirstChild("Ignore"))
    add(Workspace.Terrain)
    local root = Game.rootPart()
    if root then
        local model = root.Parent
        add(model)
        add(model and model.Parent ~= Workspace and model.Parent)
    end
    pcall(function() add(LocalPlayer.Character) end)
    params.FilterDescendantsInstances = list
    Barrel.params = params
end

function Barrel.target(fire, look, distance, speed)
    local origin = fire
    local aim = Game.cast(origin, look * 2000, Barrel.params)
    local reach = distance
    if aim then
        local hitDistance = (aim.Position - origin).Magnitude
        if hitDistance > 3 then reach = math.min(hitDistance, distance) end
    end
    local flight = reach / math.max(speed or 2000, 1)
    local drop = Game.accel * (0.5 * flight * flight)
    return origin + look * reach + drop
end

function Barrel.update(cam, gameCam, weapon, now)
    Barrel.valid, Barrel.offset = false, nil
    if not (cam and gameCam and weapon and type(weapon.getBarrelCFrame) == "function") then return end
    local ok, frame = pcall(weapon.getBarrelCFrame, weapon)
    if not (ok and typeof(frame) == "CFrame") then return end
    local muzzle, look = frame.Position, frame.LookVector
    if muzzle ~= muzzle or look ~= look then return end
    Barrel.refreshParams(now)
    local fire = muzzle
    local okBase, base = pcall(gameCam.getBaseCFrame, gameCam)
    if okBase and typeof(base) == "CFrame" then
        local from = base.Position
        local hit = Game.cast(from, muzzle - from, Barrel.params)
        if hit and (hit.Position - from).Magnitude > 0.5 then fire = hit.Position + hit.Normal * 0.01 end
    end
    Barrel.fire, Barrel.look = fire, look
    Barrel.weapon, Barrel.aiming = weapon, Game.aiming(weapon)
    local okAngles, angles = pcall(gameCam.getAngles, gameCam)
    if okAngles and typeof(angles) == "Vector3" then
        local pitch = math.atan2(look.Y, math.sqrt(look.X * look.X + look.Z * look.Z))
        local yaw = math.atan2(-look.X, -look.Z)
        Barrel.offset = Vector3.new(pitch - angles.X, (yaw - angles.Y + math.pi) % (math.pi * 2) - math.pi, 0)
    end
    local speed = Game.stat(weapon, "bulletspeed")
    Barrel.hit = Barrel.target(fire, look, flag("barrel_distance", 300), speed)
    local muzzlePoint, muzzleFront = Draw.project(cam, muzzle)
    Barrel.muzzle2d = muzzleFront and muzzlePoint or nil
    local hitPoint, hitFront = Draw.project(cam, Barrel.hit)
    Barrel.hit2d = hitFront and hitPoint or nil
    Barrel.valid = true
end

function Barrel.point(mode, center)
    if not Barrel.valid then return center end
    if Game.aiming(Game.weapon()) then return center end
    if mode == "Muzzle" then return Barrel.muzzle2d or center end
    return Barrel.hit2d or center
end

local ESP = { objects = {}, seen = {}, enemy = {}, team = {}, S = {}, chams = {}, lastPrint = 0 }
local FONT_IDS = { Plex = 2, UI = 0, System = 1, Monospace = 3 }
local STRIPS = 8
local DARK = Color3.fromRGB(20, 20, 20)
local STUDS_TO_M = 0.28

local JOINTS = {
    head = { "Head", Vector3.new(0, 0, 0) },
    neck = { "Torso", Vector3.new(0, 1, 0) }, pelvis = { "Torso", Vector3.new(0, -1, 0) },
    lShoulder = { "Left Arm", Vector3.new(0, 0.85, 0) }, lElbow = { "Left Arm", Vector3.new(0, 0, 0) }, lHand = { "Left Arm", Vector3.new(0, -0.9, 0) },
    rShoulder = { "Right Arm", Vector3.new(0, 0.85, 0) }, rElbow = { "Right Arm", Vector3.new(0, 0, 0) }, rHand = { "Right Arm", Vector3.new(0, -0.9, 0) },
    lHip = { "Left Leg", Vector3.new(0, 0.85, 0) }, lKnee = { "Left Leg", Vector3.new(0, 0, 0) }, lFoot = { "Left Leg", Vector3.new(0, -0.95, 0) },
    rHip = { "Right Leg", Vector3.new(0, 0.85, 0) }, rKnee = { "Right Leg", Vector3.new(0, 0, 0) }, rFoot = { "Right Leg", Vector3.new(0, -0.95, 0) },
}
local BONES = {
    { "head", "neck" }, { "neck", "pelvis" },
    { "neck", "lShoulder" }, { "lShoulder", "lElbow" }, { "lElbow", "lHand" },
    { "neck", "rShoulder" }, { "rShoulder", "rElbow" }, { "rElbow", "rHand" },
    { "pelvis", "lHip" }, { "lHip", "lKnee" }, { "lKnee", "lFoot" },
    { "pelvis", "rHip" }, { "rHip", "rKnee" }, { "rKnee", "rFoot" },
}
local JOINT_DOTS = { "neck", "pelvis", "lShoulder", "lElbow", "lHand", "rShoulder", "rElbow", "rHand", "lHip", "lKnee", "lFoot", "rHip", "rKnee", "rFoot" }
local CAP_POINTS = { "head", table.unpack(JOINT_DOTS) }
local NEAR_PLANE = 0.1

function ESP.bonePoints(hash)
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
    return points
end

function ESP.clip(cam, a, b)
    local frame = Stretch.cf(cam)
    local da, db = -frame:PointToObjectSpace(a).Z, -frame:PointToObjectSpace(b).Z
    if da < NEAR_PLANE and db < NEAR_PLANE then return nil end
    if da < NEAR_PLANE then a = a + (b - a) * ((NEAR_PLANE - da) / (db - da))
    elseif db < NEAR_PLANE then b = a + (b - a) * ((NEAR_PLANE - da) / (db - da)) end
    return a, b
end

function ESP.bounds(cam, record, static)
    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
    local behind = false
    local function add(world)
        local point, front = Draw.project(cam, world)
        if not front then behind = true return end
        if point.X < minX then minX = point.X end
        if point.X > maxX then maxX = point.X end
        if point.Y < minY then minY = point.Y end
        if point.Y > maxY then maxY = point.Y end
    end
    local center = record.torso.Position
    if static then
        local look = record.torso.CFrame.LookVector
        local frame = CFrame.new(center + Vector3.new(0, -0.5, 0)) * CFrame.Angles(0, math.atan2(-look.X, -look.Z), 0)
        for _, sx in ipairs({ -1, 1 }) do
            for _, sy in ipairs({ -1, 1 }) do
                for _, sz in ipairs({ -1, 1 }) do
                    add(frame:PointToWorldSpace(Vector3.new(2 * sx, 2.5 * sy, 1.25 * sz)))
                end
            end
        end
    else
        for _, name in ipairs({ "Head", "Torso", "Left Leg", "Right Leg" }) do
            local part = record.hash[name]
            if part and part.Parent and (part.Position - center).Magnitude < 10 then
                local half = PART_SIZES[name] * 0.5
                for _, sx in ipairs({ -1, 1 }) do
                    for _, sy in ipairs({ -1, 1 }) do
                        for _, sz in ipairs({ -1, 1 }) do
                            add(part.CFrame:PointToWorldSpace(Vector3.new(half.X * sx, half.Y * sy, half.Z * sz)))
                        end
                    end
                end
            end
        end
        local right = record.torso.CFrame.RightVector
        for _, side in ipairs({ -1, 1 }) do
            for _, lift in ipairs({ -1, 1 }) do add(center + right * (2 * side) + Vector3.new(0, lift, 0)) end
        end
    end
    if behind or minX == math.huge then return nil end
    return math.floor(minX), math.floor(minY), math.floor(maxX - minX), math.floor(maxY - minY)
end

function ESP.readTeam(prefix, c)
    local function r(name, default) return flag(prefix .. name, default) end
    local function color(name, default) return r(name, default), Util.opacity(prefix .. name) end
    c.enabled, c.maxdist = r("on", false), r("dist", 1500)
    c.box = r("box", false)
    c.boxColor, c.boxA = color("box_color", WHITE)
    c.fill = r("fill", false)
    c.fillColor = r("fill_color", WHITE)
    c.fillA = 1 - Util.alpha(prefix .. "fill_color", 0.85)
    c.name = r("name", false)
    c.nameColor, c.nameA = color("name_color", WHITE)
    c.hp, c.hpLow, c.hpFull = r("hp", false), r("hp_low", WHITE), r("hp_full", WHITE)
    c.hpNum = r("hp_num", false)
    c.hpNumColor, c.hpNumA = color("hp_num_color", WHITE)
    c.dist = r("show_dist", false)
    c.distColor, c.distA = color("show_dist_color", WHITE)
    c.weapon = r("weapon", false)
    c.weaponColor, c.weaponA = color("weapon_color", WHITE)
    c.skeleton = r("skeleton", false)
    c.skeletonColor, c.skeletonA = color("skeleton_color", WHITE)
    c.dot = r("dot", false)
    c.dotColor, c.dotA = color("dot_color", WHITE)
    c.tracer = r("tracer", false)
    c.tracerColor, c.tracerA = color("tracer_color", WHITE)
    c.view = r("view", false)
    c.viewColor, c.viewA = color("view_color", WHITE)
    c.oov = r("oov", false)
    c.oovColor, c.oovA = color("oov_color", WHITE)
    c.chams = r("chams", false)
    c.chamVis, c.chamVisT = r("cham_vis", WHITE), Util.alpha(prefix .. "cham_vis", 0.5)
    c.chamHid, c.chamHidT = r("cham_hid", WHITE), Util.alpha(prefix .. "cham_hid", 0.5)
end

function ESP.readSettings()
    local S = ESP.S
    S.font = FONT_IDS[flag("esp_font", "Plex")] or 2
    S.size = flag("esp_text", 13)
    S.boxStyle = flag("esp_box_style", "Corners")
    S.static = flag("esp_box_mode", "Static") == "Static"
    S.outline = flag("esp_outline", true)
    S.gradient = flag("esp_fill_gradient", true)
    S.fill2 = flag("esp_fill_color2", DARK)
    S.hpMid = flag("esp_hp_mid", Color3.fromRGB(255, 210, 60))
    S.hpSide = flag("esp_hp_side", "Left")
    S.tracerOrigin = flag("esp_tracer_origin", "Bottom")
    S.tracerThick = flag("esp_tracer_thick", 1)
    S.skelThick = flag("esp_skel_thick", 1)
    S.skelOutline, S.skelJoints = flag("esp_skeleton_outline", true), flag("esp_skeleton_joints", false)
    S.case = flag("esp_case", "Normal")
    S.weaponDisplay = flag("esp_weapon_display", "Text")
    S.visOverride = flag("esp_vis", false)
    S.visColor, S.occColor = flag("esp_vis_color", Color3.fromRGB(80, 255, 120)), flag("esp_occ_color", Color3.fromRGB(255, 80, 80))
    S.chamMode = flag("cham_mode", "Through walls")
    S.chamGrow, S.chamGlowSize = flag("cham_grow", 0.1), flag("cham_glow_size", 1.75)
    S.chamGlow, S.chamRound = flag("cham_glow", false), flag("cham_round_head", true)
    S.chamHead = flag("cham_head_size", 1.15)
    S.chamGear = flag("chams_remove_gear", true)
    S.oovSize, S.oovRadius = flag("oov_size", 14), flag("oov_radius", 40)
    S.viewLen = flag("esp_view_len", 8)
end

function ESP.make()
    local o = { all = {}, strips = {}, corners = {}, cornerEdges = {}, bones = {}, boneEdges = {}, capEdges = {}, capFills = {}, hidden = false }
    local function add(drawing) o.all[#o.all + 1] = drawing return drawing end
    local function line(thick, z, color) return add(Draw.new("Line", { Thickness = thick, ZIndex = z, Color = color, Visible = false })) end
    local function square(filled, z, color) return add(Draw.new("Square", { Thickness = 1, Filled = filled, ZIndex = z, Color = color, Visible = false })) end
    local function text() return add(Draw.text(13, 8)) end

    o.fill = square(true, 1)
    for index = 1, STRIPS do o.strips[index] = square(true, 1) end
    o.outer, o.box, o.inner = square(false, 2, DARK), square(false, 3), square(false, 2, DARK)
    for index = 1, 8 do
        o.cornerEdges[index] = line(3, 2, BLACK)
        o.corners[index] = line(1, 3)
    end
    o.hpBack, o.hpBar = square(true, 4, Color3.fromRGB(10, 10, 10)), square(true, 5)
    o.hpText, o.name, o.dist, o.weapon = text(), text(), text(), text()
    o.weaponIcon = add(Draw.image(8))
    for index = 1, #BONES do
        o.boneEdges[index] = line(3, 2, BLACK)
        o.bones[index] = line(1, 3)
    end
    for index = 1, #CAP_POINTS do
        o.capEdges[index] = add(Draw.new("Circle", { Filled = true, NumSides = 14, ZIndex = 2, Color = BLACK, Visible = false }))
        o.capFills[index] = add(Draw.new("Circle", { Filled = true, NumSides = 14, ZIndex = 3, Visible = false }))
    end
    o.dotEdge = add(Draw.new("Circle", { Filled = false, NumSides = 16, Thickness = 1, Color = BLACK, ZIndex = 6, Visible = false }))
    o.dot = add(Draw.new("Circle", { Filled = true, NumSides = 16, ZIndex = 7, Visible = false }))
    o.tracer, o.view = line(1, 3), line(1, 3)
    o.arrowEdge = add(Draw.new("Triangle", { Filled = false, Thickness = 1, Color = BLACK, ZIndex = 5, Visible = false }))
    o.arrow = add(Draw.new("Triangle", { Filled = true, ZIndex = 6, Visible = false }))
    return o
end

function ESP.hide(o)
    if o.hidden then return end
    o.hidden, o.arrowOnly = true, false
    for _, drawing in ipairs(o.all) do drawing.Visible = false end
end

function ESP.destroy(o)
    for _, drawing in ipairs(o.all) do Draw.remove(drawing) end
    o.all = {}
end

local function caseText(mode, text)
    if mode == "lower" then return string.lower(text) end
    if mode == "UPPER" then return string.upper(text) end
    return text
end

local function setLine(drawing, from, to, color, alpha, thick)
    drawing.From, drawing.To, drawing.Color, drawing.Transparency, drawing.Visible = from, to, color, alpha, true
    if thick then drawing.Thickness = thick end
end

local Chams = { objs = {}, pool = {}, container = nil }
local CHAM_PARTS = { "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }

function Chams.identity()
    if setthreadidentity then pcall(setthreadidentity, 7) end
end

function Chams.getContainer()
    if Chams.container and Chams.container.Parent then return Chams.container end
    Chams.identity()
    local parents = {}
    pcall(function() parents[#parents + 1] = game:GetService("CoreGui") end)
    pcall(function() if gethui then parents[#parents + 1] = gethui() end end)
    for _, parent in ipairs(parents) do
        local gui
        local ok = pcall(function()
            gui = Instance.new("ScreenGui")
            gui.Name = Util.randomName()
            gui.DisplayOrder = 9
            gui.IgnoreGuiInset = true
            gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
            gui.Parent = parent
        end)
        if ok and gui and gui.Parent then
            Chams.container = gui
            return gui
        end
        if gui then pcall(function() gui:Destroy() end) end
    end
    local folder = Instance.new("Folder")
    folder.Name = Util.randomName()
    if pcall(function() folder.Parent = Workspace.CurrentCamera end) and folder.Parent then
        Chams.container = folder
        return folder
    end
    return nil
end

function Chams.roundClass()
    if Chams.round == nil then
        local ok, probe = pcall(Instance.new, "CylinderHandleAdornment")
        if ok and probe then
            pcall(function() probe:Destroy() end)
            Chams.round = "CylinderHandleAdornment"
        else
            Chams.round = "SphereHandleAdornment"
        end
    end
    return Chams.round
end

function Chams.acquire(round)
    local class = round and Chams.roundClass() or "BoxHandleAdornment"
    local list = Chams.pool[class]
    local adornment = list and table.remove(list)
    if adornment then return adornment end
    local container = Chams.getContainer()
    if not container then return nil end
    Chams.identity()
    local ok, created = pcall(Instance.new, class)
    if not (ok and created) then return nil end
    created.Name = Util.randomName()
    created.AdornCullingMode = Enum.AdornCullingMode.Never
    if class == "CylinderHandleAdornment" then
        created.CFrame = CFrame.new(Vector3.zero, Vector3.new(0, 90, 0))
    end
    created.Parent = container
    return created
end

function Chams.release(adornment)
    if not adornment then return end
    pcall(function()
        adornment.Visible = false
        adornment.Adornee = nil
    end)
    local class = adornment.ClassName
    Chams.pool[class] = Chams.pool[class] or {}
    table.insert(Chams.pool[class], adornment)
end

function Chams.dropSlot(slot)
    for _, adornment in pairs(slot.layers) do Chams.release(adornment) end
    slot.layers, slot.sig = {}, nil
end

function Chams.restoreGear(entry)
    if not entry.gear then return end
    for part, original in pairs(entry.gear) do pcall(function() part.Transparency = original end) end
    entry.gear = nil
end

function Chams.stripGear(entry, rec, now)
    if now < (entry.gearAt or 0) then return end
    entry.gearAt = now + 0.5
    local weaponModel = rec.object and rec.object._weaponModel
    local body = {}
    for _, part in pairs(rec.hash) do body[part] = true end
    local gear = entry.gear or {}
    entry.gear = gear
    local ok, list = pcall(rec.model.GetDescendants, rec.model)
    if not (ok and type(list) == "table") then return end
    for _, part in ipairs(list) do
        if not body[part] and gear[part] == nil and part:IsA("BasePart") and not (weaponModel and part:IsDescendantOf(weaponModel)) then
            local okRead, original = pcall(function() return part.Transparency end)
            if okRead and type(original) == "number" then
                gear[part] = original
                pcall(function() part.Transparency = 1 end)
            end
        end
    end
end

function Chams.remove(player)
    local entry = Chams.objs[player]
    if not entry then return end
    Chams.restoreGear(entry)
    for _, slot in pairs(entry.parts) do Chams.dropSlot(slot) end
    Chams.objs[player] = nil
end

function Chams.hide(entry)
    Chams.restoreGear(entry)
    if entry.hidden then return end
    entry.hidden = true
    for _, slot in pairs(entry.parts) do
        slot.sig = nil
        for _, adornment in pairs(slot.layers) do adornment.Visible = false end
    end
end

function Chams.build(slot)
    local behind, visible = Chams.acquire(slot.round), Chams.acquire(slot.round)
    if not (behind and visible) then
        Chams.release(behind)
        Chams.release(visible)
        return false
    end
    behind.AlwaysOnTop, behind.ZIndex = true, 1
    visible.AlwaysOnTop, visible.ZIndex = false, -1
    slot.layers = { behind = behind, visible = visible }
    return true
end

function Chams.headDimensions()
    local size = PART_SIZES.Head
    return size.X / 2 - 0.4, size.Y
end

function Chams.style(slot, part, name, cfg, S)
    local layers = slot.layers
    local grow = S.chamGrow
    for _, adornment in pairs(layers) do adornment.Adornee = part end
    if slot.round then
        local radius, height = Chams.headDimensions()
        radius, height = radius * S.chamHead, height * S.chamHead
        if layers.behind.ClassName == "SphereHandleAdornment" then
            radius, height = math.max(radius, height / 2), height
            layers.behind.Radius, layers.visible.Radius = radius, radius + grow / 2
        else
            layers.behind.Radius, layers.behind.Height = radius, height
            layers.visible.Radius, layers.visible.Height = radius + grow / 2, height + grow
        end
    else
        local size = typeof(part.Size) == "Vector3" and part.Size or PART_SIZES[name]
        if math.min(size.X, size.Y, size.Z) < 0.05 then size = PART_SIZES[name] end
        layers.behind.Size = size
        layers.visible.Size = size + Vector3.new(grow, grow, grow)
    end
    layers.behind.Color3, layers.behind.Transparency = cfg.chamHid, cfg.chamHidT
    layers.behind.Visible = S.chamMode == "Through walls"
    layers.visible.Color3, layers.visible.Transparency, layers.visible.Visible = cfg.chamVis, cfg.chamVisT, true
    layers.visible.AlwaysOnTop = false
    if S.chamGlow == true then
        pcall(function()
            local strength = math.max(tonumber(S.chamGlowSize) or 1, 1)
            layers.visible.Color3 = cfg.chamVis:Lerp(Color3.new(1, 1, 1), math.clamp((strength - 1) / 3, 0, 0.5))
            layers.visible.Transparency = cfg.chamVisT / strength
            layers.visible.AlwaysOnTop = S.chamMode == "Through walls"
        end)
    end
end

function Chams.shown()
    for _, entry in pairs(Chams.objs) do
        if not entry.hidden then return true end
    end
    return false
end

function Chams.update(rec, cfg, S)
    local entry = Chams.objs[rec.player]
    local want = cfg and cfg.chams and rec.rendered and rec.model and rec.model.Parent ~= nil
    if not want then
        if entry then Chams.hide(entry) end
        return
    end
    if not entry then
        entry = { parts = {} }
        Chams.objs[rec.player] = entry
    end
    entry.hidden = false
    if S.chamGear then
        Chams.stripGear(entry, rec, os.clock())
    else
        Chams.restoreGear(entry)
    end
    local sig = table.concat({
        tostring(cfg.chamVis), cfg.chamVisT, tostring(cfg.chamHid), cfg.chamHidT,
        S.chamMode, S.chamGrow, tostring(S.chamGlow), S.chamGlowSize, tostring(S.chamRound), S.chamHead,
    }, "|")
    for _, name in ipairs(CHAM_PARTS) do
        local part = rec.hash[name]
        local slot = entry.parts[name]
        if not (part and part.Parent) then
            if slot then
                Chams.dropSlot(slot)
                entry.parts[name] = nil
            end
        else
            local round = name == "Head" and S.chamRound
            if slot and slot.round ~= round then
                Chams.dropSlot(slot)
                entry.parts[name] = nil
                slot = nil
            end
            if not slot then
                slot = { round = round, layers = {} }
                entry.parts[name] = slot
            end
            local built = slot.layers.visible
            if built and not (built.Parent and slot.layers.behind.Parent) then slot.layers, slot.sig = {}, nil end
            if not slot.layers.visible and not Chams.build(slot) then return end
            Chams.identity()
            if slot.adornee ~= part or slot.sig ~= sig then
                slot.adornee, slot.sig = part, sig
                Chams.style(slot, part, name, cfg, S)
            else
                local layers = slot.layers
                if layers.visible.Adornee ~= part then layers.visible.Adornee = part end
                if layers.behind.Adornee ~= part then layers.behind.Adornee = part end
            end
        end
    end
end

function ESP.draw(cam, o, rec, cfg, S, now, origin, visible, dist, viewport, center)
    local x, y, w, h = ESP.bounds(cam, rec, S.static)
    local onScreen = x and (x + w > 0 and x < viewport.X and y + h > 0 and y < viewport.Y)

    if not onScreen then
        local showArrow = cfg.oov
        if showArrow then
            o.hidden = false
            local rel = Stretch.cf(cam):PointToObjectSpace(rec.pos)
            local flat = Vector2.new(rel.X, rel.Z)
            if flat.Magnitude < 0.001 then flat = Vector2.new(0, 1) end
            local direction = flat.Unit
            local radius = (S.oovRadius / 100) * math.min(viewport.X, viewport.Y) * 0.5
            local size = S.oovSize
            local tip = center + direction * radius
            local side = Vector2.new(-direction.Y, direction.X)
            local base = tip - direction * size * 1.3
            local a, b, c = tip, base + side * size * 0.6, base - side * size * 0.6
            local color = S.visOverride and (visible and S.visColor or S.occColor) or cfg.oovColor
            o.arrow.PointA, o.arrow.PointB, o.arrow.PointC = a, b, c
            o.arrow.Color, o.arrow.Transparency, o.arrow.Visible = color, cfg.oovA, true
            o.arrowEdge.PointA, o.arrowEdge.PointB, o.arrowEdge.PointC = a, b, c
            o.arrowEdge.Transparency, o.arrowEdge.Visible = cfg.oovA, S.outline
            if not o.arrowOnly then
                o.arrowOnly = true
                for _, drawing in ipairs(o.all) do
                    if drawing ~= o.arrow and drawing ~= o.arrowEdge then drawing.Visible = false end
                end
            end
        else
            ESP.hide(o)
        end
        return
    end

    o.hidden, o.arrowOnly = false, false
    o.arrow.Visible, o.arrowEdge.Visible = false, false
    local function tint(base) return S.visOverride and (visible and S.visColor or S.occColor) or base end

    if o.sig ~= S.font * 100 + S.size then
        o.sig = S.font * 100 + S.size
        for _, t in ipairs({ o.hpText, o.name, o.dist, o.weapon }) do t.Font, t.Size = S.font, S.size end
    end

    local fillOn = cfg.fill
    o.fill.Visible = false
    for index = 1, STRIPS do o.strips[index].Visible = false end
    if fillOn then
        if S.gradient then
            local stripH = h / STRIPS
            for index = 1, STRIPS do
                local strip = o.strips[index]
                strip.Position = Vector2.new(x, y + math.floor((index - 1) * stripH))
                strip.Size = Vector2.new(w, math.ceil(stripH))
                strip.Color = Util.lerpColor(cfg.fillColor, S.fill2, (index - 0.5) / STRIPS)
                strip.Transparency = cfg.fillA
                strip.Visible = true
            end
        else
            o.fill.Position, o.fill.Size = Vector2.new(x, y), Vector2.new(w, h)
            o.fill.Color, o.fill.Transparency, o.fill.Visible = cfg.fillColor, cfg.fillA, true
        end
    end

    local boxColor = tint(cfg.boxColor)
    local full = cfg.box and S.boxStyle == "Full"
    local corners = cfg.box and S.boxStyle ~= "Full"
    o.box.Visible, o.outer.Visible, o.inner.Visible = full, full and S.outline, full and S.outline
    if full then
        o.box.Position, o.box.Size, o.box.Color, o.box.Transparency = Vector2.new(x, y), Vector2.new(w, h), boxColor, cfg.boxA
        o.outer.Position, o.outer.Size = Vector2.new(x - 1, y - 1), Vector2.new(w + 2, h + 2)
        o.inner.Position, o.inner.Size = Vector2.new(x + 1, y + 1), Vector2.new(w - 2, h - 2)
    end
    for index = 1, 8 do o.corners[index].Visible, o.cornerEdges[index].Visible = false, false end
    if corners then
        local len = math.max(4, math.floor(w * 0.28))
        local lenV = math.max(4, math.floor(h * 0.2))
        local right, bottom = x + w, y + h
        local segments = {
            { Vector2.new(x, y), Vector2.new(x + len, y) }, { Vector2.new(x, y), Vector2.new(x, y + lenV) },
            { Vector2.new(right, y), Vector2.new(right - len, y) }, { Vector2.new(right, y), Vector2.new(right, y + lenV) },
            { Vector2.new(x, bottom), Vector2.new(x + len, bottom) }, { Vector2.new(x, bottom), Vector2.new(x, bottom - lenV) },
            { Vector2.new(right, bottom), Vector2.new(right - len, bottom) }, { Vector2.new(right, bottom), Vector2.new(right, bottom - lenV) },
        }
        for index, segment in ipairs(segments) do
            if S.outline then
                o.cornerEdges[index].From, o.cornerEdges[index].To, o.cornerEdges[index].Visible = segment[1], segment[2], true
            end
            setLine(o.corners[index], segment[1], segment[2], boxColor, cfg.boxA, 1)
        end
    end

    o.hpBack.Visible, o.hpBar.Visible, o.hpText.Visible = false, false, false
    if cfg.hp or cfg.hpNum then
        local frac = math.clamp(rec.health / math.max(rec.maxHealth, 1), 0, 1)
        local left = S.hpSide == "Left"
        local barX = left and (x - 6) or (x + w + 3)
        local barH = math.max(1, math.floor(h * frac))
        if cfg.hp then
            local color
            if frac > 0.5 then color = Util.lerpColor(S.hpMid, cfg.hpFull, (frac - 0.5) * 2)
            else color = Util.lerpColor(cfg.hpLow, S.hpMid, frac * 2) end
            o.hpBack.Position, o.hpBack.Size, o.hpBack.Visible = Vector2.new(barX - 1, y - 1), Vector2.new(5, h + 2), true
            o.hpBar.Position, o.hpBar.Size = Vector2.new(barX, y + h - barH), Vector2.new(3, barH)
            o.hpBar.Color, o.hpBar.Transparency, o.hpBar.Visible = color, 1, true
        end
        if cfg.hpNum then
            local textX = left and (barX - 11) or (barX + 14)
            o.hpText.Text = tostring(math.floor(rec.health + 0.5))
            local lowest = math.max(y - 2, y + h - S.size)
            o.hpText.Position = Vector2.new(textX, math.clamp(y + h - barH - math.floor(S.size / 2), y - 2, lowest))
            o.hpText.Color, o.hpText.Transparency, o.hpText.Visible = cfg.hpNumColor, cfg.hpNumA, true
        end
    end

    o.name.Visible = false
    if cfg.name then
        local label = caseText(S.case, string.sub(rec.name, 1, 30))
        o.name.Text = label
        o.name.Position = Vector2.new(x + w / 2, y - S.size - 3)
        o.name.Color, o.name.Transparency, o.name.Visible = cfg.nameColor, cfg.nameA, true
    end
    local lineY = y + h + 2
    o.dist.Visible, o.weapon.Visible, o.weaponIcon.Visible = false, false, false
    if cfg.dist then
        o.dist.Text = caseText(S.case, math.floor(dist * STUDS_TO_M) .. "m")
        o.dist.Position = Vector2.new(x + w / 2, lineY)
        o.dist.Color, o.dist.Transparency, o.dist.Visible = cfg.distColor, cfg.distA, true
        lineY = lineY + S.size + 1
    end
    if cfg.weapon and rec.weaponName then
        local mode = S.weaponDisplay
        local icon = false
        if mode ~= "Text" then
            local top = mode == "Both" and lineY + S.size + 1 or lineY
            icon = Icons.place(o.weaponIcon, Icons.weaponKey(rec.weaponName, rec.weaponObject), x + w / 2, top + 7, 60, 13, cfg.weaponColor, cfg.weaponA)
        end
        if mode ~= "Icon" or not icon then
            o.weapon.Text = caseText(S.case, tostring(rec.weaponName))
            o.weapon.Position = Vector2.new(x + w / 2, lineY)
            o.weapon.Color, o.weapon.Transparency, o.weapon.Visible = cfg.weaponColor, cfg.weaponA, true
        end
    end

    for index = 1, #BONES do o.bones[index].Visible, o.boneEdges[index].Visible = false, false end
    for index = 1, #CAP_POINTS do o.capEdges[index].Visible, o.capFills[index].Visible = false, false end
    if cfg.skeleton then
        local points = ESP.bonePoints(rec.hash)
        if points then
            local color = tint(cfg.skeletonColor)
            for index, bone in ipairs(BONES) do
                local a, b = points[bone[1]], points[bone[2]]
                if a and b then
                    local ca, cb = ESP.clip(cam, a, b)
                    if ca then
                        local pa, pb = Draw.project(cam, ca), Draw.project(cam, cb)
                        if S.skelOutline then setLine(o.boneEdges[index], pa, pb, BLACK, cfg.skeletonA, S.skelThick + 2) end
                        setLine(o.bones[index], pa, pb, color, cfg.skeletonA, S.skelThick)
                    end
                end
            end
            local fillRadius = S.skelJoints and S.skelThick + 0.75 or S.skelThick / 2
            if S.skelOutline or S.skelJoints or S.skelThick >= 2 then
                for index, name in ipairs(CAP_POINTS) do
                    local world = points[name]
                    if world then
                        local point, front = Draw.project(cam, world)
                        if front then
                            if S.skelOutline then
                                local edge = o.capEdges[index]
                                edge.Position, edge.Radius, edge.Transparency, edge.Visible = point, fillRadius + 1, cfg.skeletonA, true
                            end
                            local fill = o.capFills[index]
                            fill.Position, fill.Radius, fill.Color, fill.Transparency, fill.Visible = point, fillRadius, color, cfg.skeletonA, true
                        end
                    end
                end
            end
        end
    end

    o.dot.Visible, o.dotEdge.Visible, o.view.Visible = false, false, false
    local headPoint, headFront = Draw.project(cam, rec.head.Position)
    if cfg.dot and headFront then
        local radius = math.clamp(h * 0.09, 2, 12)
        o.dot.Position, o.dot.Radius, o.dot.Color, o.dot.Transparency, o.dot.Visible = headPoint, radius, tint(cfg.dotColor), cfg.dotA, true
        o.dotEdge.Position, o.dotEdge.Radius, o.dotEdge.Visible = headPoint, radius, S.outline
    end
    if cfg.view and headFront then
        local tip, tipFront = Draw.project(cam, rec.head.Position + rec.head.CFrame.LookVector * S.viewLen)
        if tipFront then setLine(o.view, headPoint, tip, tint(cfg.viewColor), cfg.viewA, 1) end
    end

    o.tracer.Visible = false
    if cfg.tracer then
        local from
        if S.tracerOrigin == "Center" then from = center
        elseif S.tracerOrigin == "Top" then from = Vector2.new(viewport.X / 2, 0)
        elseif S.tracerOrigin == "Mouse" then from = UserInputService:GetMouseLocation()
        else from = Vector2.new(viewport.X / 2, viewport.Y) end
        setLine(o.tracer, from, Vector2.new(x + w / 2, y + h), tint(cfg.tracerColor), cfg.tracerA, S.tracerThick)
    end
end

function ESP.chams(rec, cfg, S)
    local ok, problem = pcall(Chams.update, rec, cfg, S)
    if not ok then Util.note("cham:" .. tostring(problem), "chams (" .. tostring(rec.name) .. "):", problem) end
end

function ESP.processRecord(cam, rec, now, origin, viewport, center)
    local S = ESP.S
    local cfg = rec.enemy and ESP.enemy or ESP.team
    local o = ESP.objects[rec.player]
    if not o then
        o = ESP.make()
        ESP.objects[rec.player] = o
    end
    ESP.seen[rec.player] = true
    o.lastSeen = now

    local dist = (rec.pos - origin).Magnitude
    if not cfg.enabled or dist > cfg.maxdist then
        ESP.hide(o)
        ESP.chams(rec, nil, S)
        return
    end
    local visible = false
    if rec.rendered and S.visOverride then
        visible = Visible.entity(rec, origin, now, flag("vis_interval", 100) / 1000)
    end
    ESP.chams(rec, cfg, S)
    ESP.draw(cam, o, rec, cfg, S, now, origin, visible, dist, viewport, center)
end

function ESP.step(cam, now, records)
    ESP.readSettings()
    ESP.readTeam("esp_enemy_", ESP.enemy)
    ESP.readTeam("esp_team_", ESP.team)
    local origin = Game.eye(cam).Position
    local viewport = cam.ViewportSize
    local center = viewport / 2
    local seen = ESP.seen
    for player in pairs(seen) do seen[player] = nil end
    for _, rec in ipairs(records) do
        local ok, problem = pcall(ESP.processRecord, cam, rec, now, origin, viewport, center)
        if not ok then
            local o = ESP.objects[rec.player]
            if o then ESP.hide(o) end
            Util.note("esp:" .. tostring(problem), "esp (" .. tostring(rec.name) .. "):", problem)
        end
    end
    for player, o in pairs(ESP.objects) do
        if not ESP.seen[player] then
            ESP.hide(o)
            Chams.remove(player)
            if now - (o.lastSeen or 0) > 1.5 then
                ESP.destroy(o)
                ESP.objects[player] = nil
            end
        end
    end
end

function ESP.clear()
    for _, o in pairs(ESP.objects) do ESP.hide(o) end
    for player in pairs(Chams.objs) do Chams.remove(player) end
end

Util.onUnload(function()
    for _, o in pairs(ESP.objects) do ESP.destroy(o) end
    ESP.objects = {}
    for player in pairs(Chams.objs) do Chams.remove(player) end
    for _, list in pairs(Chams.pool) do
        for _, adornment in ipairs(list) do pcall(function() adornment:Destroy() end) end
    end
    Chams.pool = {}
    if Chams.container then pcall(function() Chams.container:Destroy() end) end
end)

local Items = { drops = {}, grenades = {}, texts = {}, images = {}, nextScan = 0 }

function Items.scan(now)
    if now < Items.nextScan then return end
    Items.nextScan = now + 0.25
    local ignore = Workspace:FindFirstChild("Ignore")
    local drops, grenades = {}, {}
    if ignore then
        local gunDrop = ignore:FindFirstChild("GunDrop")
        if gunDrop then
            for _, child in ipairs(gunDrop:GetChildren()) do
                if #drops < 60 then drops[#drops + 1] = child end
            end
        end

        local misc = ignore:FindFirstChild("Misc")
        if misc then
            for _, child in ipairs(misc:GetChildren()) do
                if child.Name == "Trigger" and child:IsA("BasePart") and child:FindFirstChild("Ticking") then
                    grenades[#grenades + 1] = child
                end
            end
        end
    end
    Items.drops, Items.grenades = drops, grenades
end

function Items.position(instance)
    local ok, position = pcall(function()
        if instance:IsA("Model") then return instance:GetPivot().Position end
        return instance.Position
    end)
    if ok and typeof(position) == "Vector3" then return position end
    return nil
end

function Items.step(cam, now)
    local used = 0
    if flag("item_drops", false) then
        Items.scan(now)
        local origin = Game.eye(cam).Position
        local color, alpha, maxDistance = flag("item_drops_color", WHITE), Util.opacity("item_drops_color"), flag("item_dist", 300)
        local display = flag("item_drops_display", "Text")
        for _, instance in ipairs(Items.drops) do
            local position = instance.Parent and Items.position(instance)
            local distance = position and (position - origin).Magnitude
            if distance and distance <= maxDistance then
                local point, front = Draw.project(cam, position)
                if front then
                    used = used + 1
                    local text = Items.texts[used]
                    if not text then
                        text = Draw.text(13, 7)
                        Items.texts[used] = text
                    end
                    local image = Items.images[used]
                    if not image then
                        image = Draw.image(7)
                        Items.images[used] = image
                    end
                    local size = ESP.S.size or 13
                    local mode = display
                    local icon = false
                    if mode ~= "Text" then
                        icon = Icons.place(image, Icons.weaponKey(tostring(instance.Name)), point.X, point.Y, 60, 13, color, alpha)
                    end
                    if not icon then image.Visible = false end
                    local meters = math.floor(distance * STUDS_TO_M) .. "m"
                    text.Font, text.Size = ESP.S.font or 2, size
                    text.Text = mode == "Text" and (tostring(instance.Name) .. " " .. meters) or (icon and mode == "Icon" and meters) or (tostring(instance.Name) .. " " .. meters)
                    text.Position = Vector2.new(point.X, point.Y + (icon and 8 or 0))
                    text.Color, text.Transparency, text.Visible = color, alpha, true
                end
            end
        end
    end
    for index = used + 1, #Items.texts do Items.texts[index].Visible = false end
    for index = used + 1, #Items.images do Items.images[index].Visible = false end
end

local World = { orig = {}, sky = nil, ownSky = nil, atmos = nil, ownAtmos = false, fx = {}, fov = {}, clouds = {}, weather = { cells = {} }, hour = nil, hue = 0, angle = 0 }

local SKY_FACES = { "SkyboxUp", "SkyboxDn", "SkyboxFt", "SkyboxBk", "SkyboxLf", "SkyboxRt" }
local SKY_PRESETS = {
    ["Afternoon"] = { "162001926", "161998893", "162001897", "162001887", "162001904", "162001919" },
    ["Aesthetic Mountains"] = { "15470207755", "15470151245", "15470200128", "15470198023", "15470202648", "15470204862" },
    ["Better Night"] = { "15470303050", "15470291746", "15470294431", "15470289121", "15470297162", "15470299887" },
    ["Blue Space"] = { "367149078", "367147970", "366731193", "366731024", "366731613", "366731514" },
    ["Cloudy"] = { "246480504", "246480523", "246480105", "246480323", "246480549", "246480565" },
    ["Dawn"] = { "323478865", "323481190", "323480314", "323479840", "323480786", "323480131" },
    ["Dusk"] = { "9778106496", "9778110864", "9778101192", "9778108979", "9778103329", "9778104889" },
    ["Earth"] = { "15753304473", "15753362674", "15753305823", "15753305495", "15753310707", "15753304774" },
    ["Ethereal"] = { "16823395515", "16823388586", "16823390254", "16823386986", "16823392344", "16823394120" },
    ["Galaxy"] = { "2049518578", "2049519279", "2049519882", "2049520382", "2049522478", "2049521207" },
    ["Heaven"] = { "7951703855", "7951706908", "7951694757", "7951826533", "7951697216", "7951700251" },
    ["Hell"] = { "11730857150", "11730842997", "11730849615", "11730840088", "11730852920", "11730855491" },
    ["Jungle"] = { "525546479", "525544628", "525548536", "525546178", "525550171", "525545319" },
    ["Lunar Night"] = { "187712111", "187712428", "187712836", "187713366", "187713755", "187714525" },
    ["Milkyway"] = { "137817405681365", "108406529909981", "104400530594543", "129876530632297", "73372229972523", "87408857415924" },
    ["Mountains"] = { "48015387", "48015300", "368388290", "368385273", "368390615", "368385190" },
    ["Nebula"] = { "171448889", "171448902", "171448848", "171448875", "171448933", "171448925" },
    ["Night"] = { "12064131", "12064152", "12064121", "12064107", "12063984", "12064115" },
    ["Ocean Sky"] = { "11854708161", "11854687121", "11854693863", "11854686548", "11854696162", "11854698541" },
    ["Pink Clouds"] = { "271077958", "271077243", "271042556", "271042516", "271042310", "271042467" },
    ["Purple Night"] = { "5084576400", "5260653793", "5260817288", "5260808177", "5260800833", "5260800833" },
    ["Red Dusk"] = { "136208328681929", "123407860042117", "132624761762466", "85146619291315", "102069641249982", "136526747107728" },
    ["Redshift"] = { "401664936", "401664862", "401664960", "401664839", "401664881", "401664901" },
    ["Saturn"] = { "1898736761", "1898727189", "1898722814", "1898724755", "1898729298", "1898741025" },
    ["Solid Black"] = { "2013298", "2013298", "2013298", "2013298", "2013298", "2013298" },
    ["Space"] = { "155441905", "155441905", "155441905", "155441905", "155441905", "155441905" },
    ["Storm"] = { "171410789", "171410792", "171410775", "171410784", "171410807", "171410798" },
    ["Sunset"] = { "264907379", "264907909", "264909420", "264908339", "264909758", "264908886" },
    ["Underworld"] = { "171561009", "171561019", "171560968", "171560994", "171561065", "171561026" },
    ["Winter"] = { "155674931", "155674246", "155657609", "155657655", "155657671", "155657619" },
}
local SKY_ORDER = { "Afternoon", "Aesthetic Mountains", "Better Night", "Blue Space", "Cloudy", "Dawn", "Dusk", "Earth", "Ethereal", "Galaxy", "Heaven", "Hell", "Jungle", "Lunar Night", "Milkyway", "Mountains", "Nebula", "Night", "Ocean Sky", "Pink Clouds", "Purple Night", "Red Dusk", "Redshift", "Saturn", "Solid Black", "Space", "Storm", "Sunset", "Underworld", "Winter" }
local SKY_CHOICES = {}
for index, name in ipairs(SKY_ORDER) do SKY_CHOICES[index] = name end
for _, name in ipairs({ "Custom", "Custom faces", "Single image", "Saved set" }) do SKY_CHOICES[#SKY_CHOICES + 1] = name end

local CELL = 28
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SNOW_WHITE = Color3.fromRGB(255, 255, 255)
local WEATHER = {
    Snow = { layers = {
        { texture = SMOKE, color = SNOW_WHITE, alpha = 0.15, count = 90, speed = { 6, 10 }, size = { 0.35, 0.25 }, spread = 0.4, spin = true },
        { texture = SPARK, color = SNOW_WHITE, alpha = 0.35, count = 25, speed = { 5, 8 }, size = { 0.2, 0.15 }, spread = 0.6, spin = true },
    } },
    Rain = { layers = {
        { texture = SMOKE, color = Color3.fromRGB(190, 205, 230), alpha = 0.35, count = 170, speed = { 70, 90 }, size = { 0.12, 0.1 }, spread = 0.05, parallel = true },
    } },
    Blizzard = { layers = {
        { texture = SMOKE, color = SNOW_WHITE, alpha = 0.1, count = 220, speed = { 18, 28 }, size = { 0.3, 0.2 }, spread = 0.8, spin = true, wind = 1.5, push = 6 },
        { texture = SMOKE, color = Color3.fromRGB(235, 240, 250), alpha = 0.75, count = 14, speed = { 14, 22 }, size = { 3, 5 }, spread = 1, spin = true, wind = 1.5, push = 6 },
    } },
    Ash = { layers = {
        { texture = SMOKE, color = Color3.fromRGB(120, 120, 120), alpha = 0.3, count = 60, speed = { 2, 4 }, size = { 0.3, 0.2 }, spread = 0.8, spin = true, wind = 1.5 },
        { texture = SMOKE, color = Color3.fromRGB(60, 60, 60), alpha = 0.5, count = 20, speed = { 1.5, 3 }, size = { 0.5, 0.3 }, spread = 1, spin = true, wind = 1.5 },
    } },
    Leaves = { layers = {
        { texture = SMOKE, color = Color3.fromRGB(190, 120, 40), alpha = 0.1, count = 16, speed = { 3, 5 }, size = { 0.55, 0.4 }, spread = 1.2, spin = true, wind = 1.6 },
        { texture = SMOKE, color = Color3.fromRGB(120, 150, 50), alpha = 0.1, count = 10, speed = { 3, 5 }, size = { 0.5, 0.35 }, spread = 1.2, spin = true, wind = 1.6 },
    } },
    Petals = { layers = {
        { texture = SMOKE, color = Color3.fromRGB(255, 170, 200), alpha = 0.1, count = 24, speed = { 2, 3.5 }, size = { 0.4, 0.3 }, spread = 1, spin = true, wind = 1.4 },
    } },
    Fireflies = { maxH = 9, layers = {
        { texture = SPARK, color = Color3.fromRGB(200, 255, 100), alpha = 0.1, count = 7, speed = { 0.6, 1.4 }, size = { 0.35, 0.25 }, spread = 1.5, life = { 5, 7 }, light = 1, wind = 0.3 },
    } },
    Sandstorm = { layers = {
        { texture = SMOKE, color = Color3.fromRGB(205, 170, 110), alpha = 0.55, count = 150, speed = { 3, 6 }, size = { 2.5, 3.5 }, spread = 1, spin = true, wind = 1, push = 22 },
        { texture = SMOKE, color = Color3.fromRGB(180, 145, 90), alpha = 0.3, count = 120, speed = { 2, 5 }, size = { 0.4, 0.3 }, spread = 1, wind = 1, push = 26 },
    } },
    Embers = { rise = true, layers = {
        { texture = SPARK, color = Color3.fromRGB(255, 130, 40), alpha = 0.05, count = 28, speed = { 3, 7 }, size = { 0.25, 0.1 }, spread = 25, life = { 2.5, 4 }, light = 1, accel = 2, wind = 0.8 },
    } },
    ['Fog bank'] = { maxH = 6, layers = {
        { texture = SMOKE, color = Color3.fromRGB(205, 210, 215), alpha = 0.88, count = 6, speed = { 0.2, 0.5 }, size = { 14, 20 }, spread = 1, spin = true, life = { 8, 10 }, wind = 0.4 },
    } },
}
local WEATHER_NAMES = { "Snow", "Rain", "Blizzard", "Ash", "Leaves", "Petals", "Fireflies", "Sandstorm", "Embers", "Fog bank" }

local function propGet(object, prop)
    local ok, value = pcall(function() return object[prop] end)
    if ok then return value end
    return nil
end

local function propSet(object, prop, value)
    pcall(function() object[prop] = value end)
end

local want = {}
local function put(object, prop, value)
    if not object then return end
    want[object] = want[object] or {}
    want[object][prop] = value
end
local function on(name) return Toggles[name] and Toggles[name].Value end
local function val(name) return Options[name] and Options[name].Value end

local function effect(key, class, enabled)
    local object = World.fx[key]
    if not (object and object.Parent) then
        if not enabled then return nil end
        object = Instance.new(class)
        object.Name = Util.randomName()
        object.Parent = Lighting
        World.fx[key] = object
    end
    object.Enabled = enabled
    return object
end

local function tune(key, class, flagName, set)
    local enabled = on(flagName) == true
    local object = effect(key, class, enabled)
    if object and enabled then set(object) end
end

local SKY_FIELDS = { "world_sky_f_up", "world_sky_f_dn", "world_sky_f_ft", "world_sky_f_bk", "world_sky_f_lf", "world_sky_f_rt" }
World.skyTex, World.hidden, World.skyFail = {}, {}, {}

function World.parseAsset(text)
    local s = tostring(text or ""):match("^%s*(.-)%s*$")
    if s == "" then return nil end
    local lower = s:lower()
    local number = lower:match("^rbxassetid://(%d+)")
    if number then return "rbxassetid://" .. number end
    if lower:match("^rbx%a*://") then return s end
    if lower:match("^https?://") then
        number = lower:match("[?&]id=(%d+)") or lower:match("/library/(%d+)") or lower:match("/catalog/(%d+)") or lower:match("/asset/(%d+)") or lower:match("/(%d%d%d+)")
    else
        number = lower:match("^%D*(%d+)%D*$")
    end
    if number then return "rbxassetid://" .. number end
    return nil
end

function World.expandIds(text)
    local ids, count = {}, 0
    for token in string.gmatch(tostring(text or ""), "[^%s,;|]+") do
        count = count + 1
        ids[count] = World.parseAsset(token) or false
    end
    if count == 1 then
        if not ids[1] then return nil end
        return { ids[1], ids[1], ids[1], ids[1], ids[1], ids[1] }
    end
    if count ~= 6 then return nil end
    for index = 1, 6 do if not ids[index] then ids[index] = nil end end
    return ids
end

function World.savedSets()
    local sets, names = {}, {}
    for entry in string.gmatch(tostring(val("world_sky_saved") or ""), "[^;]+") do
        local name, list = entry:match("^([^|]+)|(.+)$")
        local ids = name and World.expandIds(list)
        if ids and not sets[name] then
            sets[name] = ids
            names[#names + 1] = name
        end
    end
    return sets, names
end

function World.skyIds()
    local choice = val("world_sky_box")
    if choice == "Custom" then
        return World.expandIds(val("world_sky_custom")), true
    elseif choice == "Custom faces" then
        local ids, any = {}, false
        for index, flagName in ipairs(SKY_FIELDS) do
            ids[index] = World.parseAsset(val(flagName))
            any = any or ids[index] ~= nil
        end
        return any and ids or nil, true
    elseif choice == "Single image" then
        local id = World.parseAsset(val("world_sky_single"))
        return id and { id, id, id, id, id, id } or nil, true
    elseif choice == "Saved set" then
        local sets = World.savedSets()
        return sets[val("world_sky_saved_pick")], true
    end
    local preset = SKY_PRESETS[choice]
    if not preset then return nil end
    local ids = {}
    for index = 1, 6 do ids[index] = "rbxassetid://" .. preset[index] end
    return ids, false
end

function World.notify(text)
    pcall(function() Library:Notify(text, 6) end)
end

function World.skyJob(url)
    local final = url
    World.skyFail[url] = nil
    if on("world_sky_resolve") ~= false and url:match("^rbxassetid://%d+$") then
        local ok, objects = pcall(function() return game:GetObjects(url) end)
        local first = ok and type(objects) == "table" and objects[1]
        if not first then World.skyFail[url] = os.clock() + 10 end
        if first then
            local class = propGet(first, "ClassName")
            local texture = (class == "Decal" or class == "Texture") and propGet(first, "Texture")
            if type(texture) == "string" and texture ~= "" then final = texture end
            pcall(function() first:Destroy() end)
        end
    end
    World.skyTex[url] = final
    local failed = false
    local ok, service = pcall(game.GetService, game, "ContentProvider")
    if ok and service then
        pcall(function()
            service:PreloadAsync({ final }, function(_, status)
                local text = tostring(status)
                if text:find("Failure", 1, true) or text:find("TimedOut", 1, true) then failed = true end
            end)
        end)
    end
    if failed then World.notify("Skybox: failed to load " .. url .. (final ~= url and " (decal " .. final .. ")" or "")) end
end

function World.skyTexture(url)
    local entry = World.skyTex[url]
    local retry = World.skyFail[url]
    if retry and os.clock() >= retry then
        World.skyFail[url] = nil
        entry = nil
    end
    if entry == nil then
        World.skyTex[url] = false
        task.spawn(World.skyJob, url)
        entry = World.skyTex[url]
    end
    return entry or url
end

function World.refreshSaved()
    local option = Options.world_sky_saved_pick
    if not (option and type(option.SetValues) == "function") then return end
    local _, names = World.savedSets()
    if #names == 0 then names[1] = "None" end
    local current = option.Value
    pcall(option.SetValues, option, names)
    if current and table.find(names, current) then pcall(option.SetValue, option, current) end
end

function World.saveSky()
    local name = tostring(val("world_sky_save_name") or ""):gsub("[|;,]", "_"):match("^%s*(.-)%s*$")
    local ids = World.skyIds()
    local list = {}
    for index = 1, 6 do list[index] = ids and ids[index] end
    if name == "" or #list ~= 6 then
        World.notify(name == "" and "Skybox: type a name first" or "Skybox: all six faces need an id to save")
        return
    end
    local sets, names = World.savedSets()
    sets[name] = list
    if not table.find(names, name) then names[#names + 1] = name end
    local parts = {}
    for _, entry in ipairs(names) do parts[#parts + 1] = entry .. "|" .. table.concat(sets[entry], ",") end
    Options.world_sky_saved:SetValue(table.concat(parts, ";"))
    World.refreshSaved()
    pcall(function() Options.world_sky_saved_pick:SetValue(name) end)
    World.notify("Skybox: saved " .. name)
end

function World.deleteSky()
    local name = val("world_sky_saved_pick")
    local sets, names = World.savedSets()
    if not sets[name] then return end
    local parts = {}
    for _, entry in ipairs(names) do
        if entry ~= name then parts[#parts + 1] = entry .. "|" .. table.concat(sets[entry], ",") end
    end
    Options.world_sky_saved:SetValue(table.concat(parts, ";"))
    World.refreshSaved()
end

function World.showHidden()
    for child in pairs(World.hidden) do
        if propGet(child, "Parent") == nil then propSet(child, "Parent", Lighting) end
    end
    World.hidden = {}
end

function World.stepSky(dt)
    local skyOn = on("world_skybox") == true
    local raw = val("world_sky_saved") or ""
    if raw ~= World.savedRaw then
        World.savedRaw = raw
        World.refreshSaved()
    end
    local own = World.ownSky
    if own and (not skyOn or own.Parent ~= Lighting) then
        want[own], World.orig[own] = nil, nil
        pcall(function() own:Destroy() end)
        World.ownSky, own = nil, nil
    end
    local sky
    if skyOn then
        if not own then
            local ok, created = pcall(Instance.new, "Sky")
            if ok and created then
                created.Name = Util.randomName()
                pcall(function() created.Parent = Lighting end)
                World.ownSky, own = created, created
            end
        end
        sky = own
        if not World.skyWatch then
            World.skyWatch = true
            pcall(function() Util.track(Lighting.ChildAdded:Connect(function() World.skyDirty = true end)) end)
        end
        local clock = os.clock()
        if World.skyDirty ~= false or clock >= (World.skyScanAt or 0) then
            World.skyDirty, World.skyScanAt = false, clock + 1
            for _, child in ipairs(Lighting:GetChildren()) do
                if child ~= own and propGet(child, "ClassName") == "Sky" then World.hidden[child] = true end
            end
        end
        for child in pairs(World.hidden) do
            if propGet(child, "Parent") ~= nil then propSet(child, "Parent", nil) end
        end
        local ids, custom = World.skyIds()
        if sky and ids then
            for index, face in ipairs(SKY_FACES) do
                local url = ids[index]
                if url then put(sky, face, custom and World.skyTexture(url) or url) end
            end
        end
    else
        World.showHidden()
        local found = Lighting:FindFirstChildOfClass("Sky")
        if on("world_nosky") then
            if found then
                World.sky = found
                pcall(function() found.Parent = nil end)
            end
        else
            if World.sky and not World.sky.Parent then
                pcall(function() World.sky.Parent = Lighting end)
                found = World.sky
            end
            sky = found
        end
    end
    if not sky then return end
    if on("world_sky_objects") then
        put(sky, "StarCount", val("world_sky_stars"))
        put(sky, "SunAngularSize", val("world_sky_sun"))
        put(sky, "MoonAngularSize", val("world_sky_moon"))
        put(sky, "CelestialBodiesShown", val("world_sky_bodies") ~= false)
    end
    if on("world_sky_spin") then
        World.angle = (World.angle + val("world_sky_spin_speed") * dt) % 360
        put(sky, "SkyboxOrientation", Vector3.new(0, World.angle, 0))
    end
end

function World.cloudObject(enabled)
    local state = World.clouds
    if enabled then
        if not (state.object and state.object.Parent) then
            local terrain
            pcall(function() terrain = Workspace:FindFirstChildOfClass("Terrain") end)
            if not terrain then return nil end
            local existing = terrain:FindFirstChildOfClass("Clouds")
            if existing then
                state.object, state.created = existing, false
            else
                local ok, created = pcall(Instance.new, "Clouds")
                if not (ok and created) then return nil end
                created.Parent = terrain
                state.object, state.created = created, true
            end
        end
        return state.object
    end
    if state.object then
        if state.created then
            want[state.object], World.orig[state.object] = nil, nil
            pcall(function() state.object:Destroy() end)
        end
        state.object = nil
    end
    return nil
end

World.mapLight = { list = nil, cursor = 1, added = {}, sig = nil, map = nil, conn = nil }

function World.mapSpec()
    if not on("world_map") then return nil end
    local neon = on("world_map_neon") == true
    local material = neon and "Neon" or val("world_map_mat")
    if material == "Default" then material = nil end
    local k = 0
    if on("world_map_tint_on") or neon then
        k = val("world_map_tint_k") or 0
        if neon then k = math.max(k, 0.6) end
    end
    local trans = on("world_map_trans_on") and val("world_map_trans") or 0
    local refl = on("world_map_refl_on") and val("world_map_refl") or nil
    if not (material or k > 0 or trans > 0 or refl) then return nil end
    local tint = val("world_map_tint") or Color3.new(1, 1, 1)
    return { tint = tint, k = k, material = material, trans = trans, refl = refl,
        sig = string.format("%s|%s|%.3f|%.3f|%s", tostring(tint), tostring(material), k, trans, tostring(refl)) }
end

function World.mapPart(part, spec)
    local isPart = false
    pcall(function() isPart = part:IsA("BasePart") end)
    if not isPart then return end
    local snap = Game.mapSnap[part]
    if spec and not snap then
        snap = { Color = propGet(part, "Color"), Material = propGet(part, "Material"), Transparency = propGet(part, "Transparency"), Reflectance = propGet(part, "Reflectance"), CanCollide = propGet(part, "CanCollide") }
        if snap.Color == nil or snap.Transparency == nil then return end
        Game.mapSnap[part] = snap
    end
    if not snap then return end
    local color, material, transparency, reflectance = snap.Color, snap.Material, snap.Transparency, snap.Reflectance
    if spec then
        if spec.k > 0 then color = Util.lerpColor(snap.Color, spec.tint, spec.k) end
        if spec.material then
            local ok, enum = pcall(function() return Enum.Material[spec.material] end)
            if ok and enum then material = enum end
        end
        if spec.trans > 0 and snap.CanCollide == true then transparency = math.max(snap.Transparency, spec.trans) end
        if spec.refl then reflectance = spec.refl end
    else
        Game.mapSnap[part] = nil
    end
    if propGet(part, "Color") ~= color then propSet(part, "Color", color) end
    if material ~= nil and propGet(part, "Material") ~= material then propSet(part, "Material", material) end
    if propGet(part, "Transparency") ~= transparency then propSet(part, "Transparency", transparency) end
    if reflectance ~= nil and propGet(part, "Reflectance") ~= reflectance then propSet(part, "Reflectance", reflectance) end
end

function World.mapUnhook()
    local state = World.mapLight
    if state.conn then pcall(function() state.conn:Disconnect() end) end
    state.conn, state.added = nil, {}
end

function World.stepMap()
    local state = World.mapLight
    local spec = World.mapSpec()
    local map = Workspace:FindFirstChild("Map")
    if map ~= state.map then
        World.mapUnhook()
        state.map, state.sig = map, nil
    end
    if spec and map and not state.conn then
        local ok, conn = pcall(function()
            return map.DescendantAdded:Connect(function(object)
                if #state.added < 5000 then state.added[#state.added + 1] = object end
            end)
        end)
        if ok and conn then state.conn = conn end
    elseif not spec and state.conn then
        World.mapUnhook()
    end
    local sig = spec and map and spec.sig or (not spec and next(Game.mapSnap) and "restore") or nil
    if sig ~= state.sig then
        state.sig, state.cursor, state.list = sig, 1, nil
        if sig == "restore" then
            state.list = {}
            for part in pairs(Game.mapSnap) do state.list[#state.list + 1] = part end
        elseif sig then
            local ok, all = pcall(function() return map:GetDescendants() end)
            state.list = ok and all or {}
        end
    end
    if not sig then return end
    local budget = 300
    while budget > 0 and #state.added > 0 do
        World.mapPart(table.remove(state.added), spec)
        budget = budget - 1
    end
    local list = state.list
    while list and budget > 0 and state.cursor <= #list do
        World.mapPart(list[state.cursor], spec)
        state.cursor, budget = state.cursor + 1, budget - 1
    end
end

function World.dropMap()
    World.mapUnhook()
    local state = World.mapLight
    state.list, state.sig, state.map = nil, nil, nil
    for part in pairs(Game.mapSnap) do World.mapPart(part, nil) end
end

World.lightState = { list = nil, cursor = 1, added = {}, sig = nil, map = nil, conn = nil }
Game.lightSnap = setmetatable({}, { __mode = "k" })

function World.lightSpec()
    if not on("world_lights") then return nil end
    local spec = {
        bright = val("world_lights_bright") or 1, range = val("world_lights_range") or 1, angle = val("world_lights_angle") or 1,
        k = on("world_lights_tint_on") and (val("world_lights_tint_k") or 0) or 0, tint = val("world_lights_tint") or Color3.new(1, 1, 1),
        noShadow = on("world_lights_noshadow") == true, off = on("world_lights_off") == true,
    }
    spec.sig = string.format("%.3f|%.3f|%.3f|%.3f|%s|%s|%s", spec.bright, spec.range, spec.angle, spec.k, tostring(spec.tint), tostring(spec.noShadow), tostring(spec.off))
    return spec
end

function World.mapLightObject(object, spec)
    local isLight = false
    pcall(function() isLight = object:IsA("Light") end)
    if not isLight then return end
    local snap = Game.lightSnap[object]
    if spec and not snap then
        snap = { Brightness = propGet(object, "Brightness"), Range = propGet(object, "Range"), Angle = propGet(object, "Angle"), Color = propGet(object, "Color"), Shadows = propGet(object, "Shadows"), Enabled = propGet(object, "Enabled") }
        if snap.Brightness == nil then return end
        Game.lightSnap[object] = snap
    end
    if not snap then return end
    local want = { Brightness = snap.Brightness, Range = snap.Range, Angle = snap.Angle, Color = snap.Color, Shadows = snap.Shadows, Enabled = snap.Enabled }
    if spec then
        want.Brightness = snap.Brightness * spec.bright
        if snap.Range then want.Range = math.max(0, snap.Range * spec.range) end
        if snap.Angle then want.Angle = math.clamp(snap.Angle * spec.angle, 1, 180) end
        if snap.Color and spec.k > 0 then want.Color = Util.lerpColor(snap.Color, spec.tint, spec.k) end
        if spec.noShadow and snap.Shadows ~= nil then want.Shadows = false end
        if spec.off then want.Enabled = false end
    else
        Game.lightSnap[object] = nil
    end
    for prop, value in pairs(want) do
        if value ~= nil and propGet(object, prop) ~= value then propSet(object, prop, value) end
    end
end

function World.lightUnhook()
    local state = World.lightState
    if state.conn then pcall(function() state.conn:Disconnect() end) end
    state.conn, state.added = nil, {}
end

function World.stepLights()
    local state = World.lightState
    local spec = World.lightSpec()
    local map = Workspace:FindFirstChild("Map")
    if map ~= state.map then
        World.lightUnhook()
        state.map, state.sig = map, nil
    end
    if spec and map and not state.conn then
        local ok, conn = pcall(function()
            return map.DescendantAdded:Connect(function(object)
                if #state.added < 5000 then state.added[#state.added + 1] = object end
            end)
        end)
        if ok and conn then state.conn = conn end
    elseif not spec and state.conn then
        World.lightUnhook()
    end
    local sig = spec and map and spec.sig or (not spec and next(Game.lightSnap) and "restore") or nil
    if sig ~= state.sig then
        state.sig, state.cursor, state.list = sig, 1, nil
        if sig == "restore" then
            state.list = {}
            for object in pairs(Game.lightSnap) do state.list[#state.list + 1] = object end
        elseif sig then
            local ok, all = pcall(function() return map:GetDescendants() end)
            state.list = ok and all or {}
        end
    end
    if not sig then return end
    local budget = 300
    while budget > 0 and #state.added > 0 do
        World.mapLightObject(table.remove(state.added), spec)
        budget = budget - 1
    end
    local list = state.list
    while list and budget > 0 and state.cursor <= #list do
        World.mapLightObject(list[state.cursor], spec)
        state.cursor, budget = state.cursor + 1, budget - 1
    end
end

function World.dropLights()
    World.lightUnhook()
    local state = World.lightState
    state.list, state.sig, state.map = nil, nil, nil
    for object in pairs(Game.lightSnap) do World.mapLightObject(object, nil) end
end

function World.apply(dt, now)
    for _, props in pairs(want) do
        for prop in pairs(props) do props[prop] = nil end
    end

    local atmos = World.atmos
    if not (atmos and atmos.Parent) then
        atmos = Lighting:FindFirstChildOfClass("Atmosphere")
        World.atmos = atmos
    end
    if on("world_atmos") and not atmos then
        local ok, created = pcall(Instance.new, "Atmosphere")
        if ok and created then
            pcall(function() created.Parent = Lighting end)
            World.atmos, World.ownAtmos, atmos = created, true, created
        end
    end

    if on("world_time") then put(Lighting, "ClockTime", val("world_time_v")) end
    if on("world_cycle") then
        World.hour = ((World.hour or propGet(Lighting, "ClockTime") or 12) + val("world_cycle_speed") * dt) % 24
        put(Lighting, "ClockTime", World.hour)
    else
        World.hour = nil
    end
    if on("world_lat") then put(Lighting, "GeographicLatitude", val("world_lat_v")) end
    if on("world_ambient") then
        put(Lighting, "Ambient", val("world_ambient_in"))
        put(Lighting, "OutdoorAmbient", val("world_ambient_out"))
    end
    if on("world_shift") then
        put(Lighting, "ColorShift_Top", val("world_shift_top"))
        put(Lighting, "ColorShift_Bottom", val("world_shift_bottom"))
    end
    if on("world_env") then
        put(Lighting, "EnvironmentDiffuseScale", val("world_env_diffuse"))
        put(Lighting, "EnvironmentSpecularScale", val("world_env_specular"))
    end
    if on("world_fog") then
        put(Lighting, "FogStart", val("world_fog_start"))
        put(Lighting, "FogEnd", math.max(val("world_fog_end"), val("world_fog_start") + 1))
        put(Lighting, "FogColor", val("world_fog_color"))
    end
    if on("world_fog_grad") then
        local wave = (math.sin(now * val("world_fog_grad_speed")) + 1) * 0.5
        put(Lighting, "FogColor", Util.lerpColor(val("world_fog_color"), val("world_fog_color2"), wave))
    end
    if on("world_bright") then put(Lighting, "Brightness", val("world_bright_v")) end
    if on("world_exposure") then put(Lighting, "ExposureCompensation", val("world_exposure_v")) end
    if on("world_atmos") and atmos then
        put(atmos, "Density", val("world_atmos_density"))
        put(atmos, "Color", val("world_atmos_color"))
        put(atmos, "Decay", val("world_atmos_decay"))
        put(atmos, "Glare", val("world_atmos_glare"))
        put(atmos, "Haze", val("world_atmos_haze"))
    end
    if on("world_sky") then
        local preset = val("world_sky_preset")
        if preset == "Night" then
            put(Lighting, "ClockTime", 0)
            if atmos then put(atmos, "Color", Color3.fromRGB(60, 70, 110)); put(atmos, "Decay", Color3.fromRGB(10, 12, 30)) end
        elseif preset == "Sunset" then
            put(Lighting, "ClockTime", 18.2)
            if atmos then put(atmos, "Color", Color3.fromRGB(255, 160, 100)); put(atmos, "Decay", Color3.fromRGB(120, 60, 90)) end
        elseif preset == "Overcast" then
            put(Lighting, "ClockTime", 12)
            if atmos then put(atmos, "Color", Color3.fromRGB(170, 175, 185)); put(atmos, "Density", 0.55) end
        elseif preset == "Dusk" then
            put(Lighting, "ClockTime", 19.5)
            if atmos then put(atmos, "Color", Color3.fromRGB(140, 110, 200)); put(atmos, "Decay", Color3.fromRGB(40, 30, 80)) end
        end
    end
    if on("world_map_shadow") then
        put(Lighting, "GlobalShadows", on("world_map_shadow_on") ~= false)
        put(Lighting, "ShadowSoftness", val("world_map_soft"))
    end
    if on("world_noshadow") then put(Lighting, "GlobalShadows", false) end
    if on("world_nofog") then put(Lighting, "FogEnd", 1e9); put(Lighting, "FogStart", 1e9 - 1) end
    if on("world_fullbright") then
        put(Lighting, "Brightness", 2)
        put(Lighting, "ClockTime", 14)
        put(Lighting, "Ambient", Color3.new(1, 1, 1))
        put(Lighting, "OutdoorAmbient", Color3.new(1, 1, 1))
        put(Lighting, "GlobalShadows", false)
        put(Lighting, "FogEnd", 1e9)
        put(Lighting, "FogStart", 1e9 - 1)
    end
    if on("world_rainbow") then
        World.hue = (World.hue + val("world_rainbow_speed") * dt) % 1
        local colour = Color3.fromHSV(World.hue, val("world_rainbow_sat"), 1)
        local targets = Util.set("world_rainbow_targets", {})
        if targets.Ambient then
            put(Lighting, "Ambient", colour)
            put(Lighting, "OutdoorAmbient", colour)
        end
        if targets.Fog then put(Lighting, "FogColor", colour) end
        if targets["Colour shift"] then put(Lighting, "ColorShift_Top", colour) end
        if targets.Atmosphere and atmos then put(atmos, "Color", colour) end
    end

    Util.guard("sky", World.stepSky, dt)
    Util.guard("map-light", World.stepMap)
    Util.guard("map-lights", World.stepLights)
    local clouds = World.cloudObject(on("world_clouds") == true)
    if clouds then
        put(clouds, "Enabled", true)
        put(clouds, "Cover", val("world_clouds_cover"))
        put(clouds, "Density", val("world_clouds_density"))
        put(clouds, "Color", val("world_clouds_color"))
    end

    for object, props in pairs(want) do
        World.orig[object] = World.orig[object] or {}
        for prop, value in pairs(props) do
            if World.orig[object][prop] == nil then World.orig[object][prop] = propGet(object, prop) end
            if propGet(object, prop) ~= value then propSet(object, prop, value) end
        end
    end
    for object, saved in pairs(World.orig) do
        for prop, old in pairs(saved) do
            if not (want[object] and want[object][prop] ~= nil) then
                if old ~= nil then propSet(object, prop, old) end
                saved[prop] = nil
            end
        end
        if next(saved) == nil then World.orig[object] = nil end
    end

    if not on("world_atmos") and World.ownAtmos and World.atmos then
        pcall(function() World.atmos:Destroy() end)
        want[World.atmos], World.orig[World.atmos] = nil, nil
        World.atmos, World.ownAtmos = nil, false
    end

    tune("cc", "ColorCorrectionEffect", "world_cc", function(object)
        object.TintColor, object.Saturation = val("world_cc_tint"), val("world_cc_sat")
        object.Contrast, object.Brightness = val("world_cc_con"), val("world_cc_bri")
    end)
    pcall(function()
        local glowBloom = on("cham_glow") == true and on("cham_bloom") == true and Chams.shown()
        local worldBloom = on("world_bloom") == true
        local bloom = effect("bloom", "BloomEffect", worldBloom or glowBloom)
        if bloom then
            if worldBloom then
                bloom.Intensity, bloom.Size, bloom.Threshold = val("world_bloom_i"), val("world_bloom_s"), val("world_bloom_t")
            else
                bloom.Intensity, bloom.Size, bloom.Threshold = val("cham_bloom_i"), val("cham_bloom_s"), val("cham_bloom_t")
            end
        end
    end)
    tune("rays", "SunRaysEffect", "world_rays", function(object)
        object.Intensity, object.Spread = val("world_rays_i"), val("world_rays_s")
    end)
    tune("dof", "DepthOfFieldEffect", "world_dof", function(object)
        object.FocusDistance, object.InFocusRadius = val("world_dof_focus"), val("world_dof_radius")
        object.NearIntensity, object.FarIntensity = val("world_dof_near"), val("world_dof_far")
    end)
    tune("blur", "BlurEffect", "world_blur", function(object)
        object.Size = val("world_blur_size")
    end)
end

function World.dropWeather()
    local state = World.weather
    for _, cell in pairs(state.cells) do pcall(function() cell.part:Destroy() end) end
    state.cells, state.preset, state.sig, state.mode = {}, nil, nil, nil
end

function World.scanBounds(map)
    local ok, list = pcall(function() return map:GetDescendants() end)
    if not (ok and type(list) == "table") then return nil end
    local minX, minZ, maxX, maxZ, top = math.huge, math.huge, -math.huge, -math.huge, -math.huge
    for _, object in ipairs(list) do
        local okPart, isPart = pcall(function() return object:IsA("BasePart") end)
        if okPart and isPart then
            local okRead, position, size = pcall(function() return object.Position, object.Size end)
            if okRead and typeof(position) == "Vector3" and typeof(size) == "Vector3" then
                local reach = math.max(size.X, size.Z) / 2
                minX, maxX = math.min(minX, position.X - reach), math.max(maxX, position.X + reach)
                minZ, maxZ = math.min(minZ, position.Z - reach), math.max(maxZ, position.Z + reach)
                top = math.max(top, position.Y + size.Y / 2)
            end
        end
    end
    if maxX - minX <= 1 or maxZ - minZ <= 1 then return nil end
    return { x = minX, z = minZ, w = maxX - minX, d = maxZ - minZ, top = top }
end

function World.mapBounds(now)
    local state = World.weather
    if state.boundsAt and now < state.boundsAt then return state.bounds end
    state.boundsAt = now + 3
    local map = Workspace:FindFirstChild("Map")
    if not map then
        state.bounds, state.scanned = nil, nil
        return nil
    end
    if type(map.GetBoundingBox) == "function" then
        local ok, frame, size = pcall(map.GetBoundingBox, map)
        if ok and typeof(frame) == "CFrame" and typeof(size) == "Vector3" and size.X > 1 and size.Z > 1 then
            local center = frame.Position
            state.bounds = { x = center.X - size.X / 2, z = center.Z - size.Z / 2, w = size.X, d = size.Z, top = center.Y + size.Y / 2 }
            return state.bounds
        end
    end
    if state.scanned ~= map then
        state.bounds = World.scanBounds(map)
        state.scanned = state.bounds and map or nil
    end
    return state.bounds
end

function World.buildCell(cam, def, gx, gz, size, x, z)
    local part = Instance.new("Part")
    part.Name = Util.randomName()
    part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
    part.Transparency = 1
    part.Size = Vector3.new(size, 0.5, size)
    part.Position = Vector3.new(x, 0, z)
    local cell = { part = part, emitters = {}, gx = gx, gz = gz, nextAt = 0, open = false, x = x, z = z, size = size, ground = 0, camY = 0 }
    for _, layer in ipairs(def.layers) do
        local emitter = Instance.new("ParticleEmitter")
        emitter.Texture = layer.texture
        if layer.spin then
            emitter.Rotation = NumberRange.new(0, 360)
            emitter.RotSpeed = NumberRange.new(-40, 40)
        end
        emitter.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.15, layer.alpha),
            NumberSequenceKeypoint.new(0.85, layer.alpha),
            NumberSequenceKeypoint.new(1, 1),
        })
        emitter.LightEmission = layer.light or 0
        emitter.LockedToPart = false
        emitter.EmissionDirection = def.rise and Enum.NormalId.Top or Enum.NormalId.Bottom
        if layer.parallel then emitter.Orientation = Enum.ParticleOrientation.VelocityParallel end
        emitter.Enabled = false
        emitter.Parent = part
        cell.emitters[#cell.emitters + 1] = { object = emitter, layer = layer }
    end
    cell.parented = pcall(function() part.Parent = cam end)
    if not cell.parented then cell.parented = pcall(function() part.Parent = Workspace end) end
    return cell
end

function World.scanCell(cell, camY, top)
    cell.camY = camY
    if top then
        local hit = Game.cast(Vector3.new(cell.x, top + 5, cell.z), Vector3.new(0, -(top + 1000), 0), Visible.params)
        if not hit then
            cell.open, cell.ground = false, camY
            return
        end
        cell.ground = hit.Position.Y
        cell.open = true
        return
    end
    local origin = Vector3.new(cell.x, camY + 3, cell.z)
    cell.open = Game.cast(origin, Vector3.new(0, 400, 0), Visible.params) == nil
    if not cell.open then return end
    local down = Game.cast(origin, Vector3.new(0, -400, 0), Visible.params)
    cell.ground = down and down.Position.Y or camY - 40
end

function World.shapeCell(cell, def, cfg, sig)
    cell.sig, cell.dirty = sig, false
    for _, entry in ipairs(cell.emitters) do entry.object.Enabled = cell.open and not cell.cleared end
    if not cell.open then return end
    local span = math.clamp(cell.camY + cfg.height - cell.ground, 6, 90)
    if def.maxH then span = math.min(span, def.maxH) end
    cell.part.Position = Vector3.new(cell.x, def.rise and cell.ground + 0.5 or cell.ground + span, cell.z)
    local radians = math.rad(cfg.windDir)
    for _, entry in ipairs(cell.emitters) do
        local emitter, layer = entry.object, entry.layer
        local slow, fast = layer.speed[1] * cfg.speed, layer.speed[2] * cfg.speed
        local lifeLo, lifeHi
        if layer.life then
            lifeLo, lifeHi = layer.life[1], layer.life[2]
        else
            lifeHi = math.clamp(span / fast, 0.25, 14)
            lifeLo = lifeHi * 0.8
        end
        local push = cfg.wind * (layer.wind or 1) + (layer.push or 0)
        emitter.Lifetime = NumberRange.new(lifeLo, lifeHi)
        emitter.Rate = layer.count * cfg.density * (cell.size / CELL) ^ 2 / ((lifeLo + lifeHi) * 0.5)
        emitter.Speed = NumberRange.new(slow, fast)
        emitter.Size = NumberSequence.new(layer.size[1] * cfg.size, layer.size[2] * cfg.size)
        emitter.SpreadAngle = Vector2.new(layer.spread, layer.spread)
        emitter.Color = ColorSequence.new(cfg.custom and cfg.color or layer.color)
        emitter.Acceleration = Vector3.new(math.sin(radians) * push, layer.accel or 0, math.cos(radians) * push)
    end
end

function World.stepWeather(cam, now)
    local state = World.weather
    if not on("world_weather") then
        if next(state.cells) then World.dropWeather() end
        return
    end
    local preset = val("world_weather_preset")
    local def = WEATHER[preset]
    if not def then return end
    if state.preset ~= preset then
        World.dropWeather()
        state.preset = preset
    end
    local cfg = {
        density = val("world_weather_amount"), speed = val("world_weather_speed"), size = val("world_weather_size"),
        wind = val("world_weather_wind"), windDir = val("world_weather_wind_dir"), height = val("world_weather_height"),
        custom = on("world_weather_custom") == true, color = val("world_weather_color"),
    }
    local sig = table.concat({ cfg.density, cfg.speed, cfg.size, cfg.wind, cfg.windDir, cfg.height, tostring(cfg.custom), tostring(cfg.color) }, "|")
    local position = cam.CFrame.Position
    local plan, mode = {}, "near"
    local cover = on("world_weather_map") == true
    local bounds = cover and World.mapBounds(now)
    if cover and not bounds then
        if next(state.cells) then World.dropWeather() end
        return
    end
    if bounds then
        local cap = math.clamp(math.floor(val("world_weather_map_cap") or 100), 16, 400)
        local size = math.max(CELL, math.sqrt(bounds.w * bounds.d / cap))
        local nx, nz = math.ceil(bounds.w / size), math.ceil(bounds.d / size)
        while nx * nz > cap do
            size = size * 1.05
            nx, nz = math.ceil(bounds.w / size), math.ceil(bounds.d / size)
        end
        mode = table.concat({ "map", nx, nz, math.floor(size * 100) }, ":")
        for gx = 0, nx - 1 do
            for gz = 0, nz - 1 do
                plan[#plan + 1] = { key = gx .. ":" .. gz, gx = gx, gz = gz, size = size, x = bounds.x + (gx + 0.5) * size, z = bounds.z + (gz + 0.5) * size, every = 1.5, stagger = (gx * 7 + gz * 3) % 11 * 0.1 }
            end
        end
    else
        local gx0, gz0 = math.floor(position.X / CELL), math.floor(position.Z / CELL)
        local range = math.clamp(math.floor(val("world_weather_range") or 2), 1, 3)
        for dx = -range, range do
            for dz = -range, range do
                if dx * dx + dz * dz <= (range + 0.5) * (range + 0.5) then
                    local gx, gz = gx0 + dx, gz0 + dz
                    plan[#plan + 1] = { key = gx .. ":" .. gz, gx = gx, gz = gz, size = CELL, x = (gx + 0.5) * CELL, z = (gz + 0.5) * CELL, every = 0.35, stagger = ((dx * 7 + dz * 3) % 5) * 0.06 }
                end
            end
        end
    end
    if state.mode ~= mode then
        World.dropWeather()
        state.preset, state.mode = preset, mode
    end
    local clearRadius = math.clamp(val("world_weather_clear_radius") or 40, 0, 150)
    local keep, scans = {}, 0
    for _, item in ipairs(plan) do
        local key = item.key
        keep[key] = true
        local cell = state.cells[key]
        if cell and cell.parented and not cell.part.Parent then
            pcall(function() cell.part:Destroy() end)
            cell = nil
        end
        if not cell then
            cell = World.buildCell(cam, def, item.gx, item.gz, item.size, item.x, item.z)
            state.cells[key] = cell
        end
        if now >= cell.nextAt and scans < 8 then
            scans = scans + 1
            cell.nextAt = now + item.every + item.stagger
            World.scanCell(cell, position.Y, bounds and bounds.top)
            cell.dirty = true
        end
        if cell.dirty or cell.sig ~= sig then World.shapeCell(cell, def, cfg, sig) end
        local cleared = false
        if bounds and clearRadius > 0 then
            local half = cell.size / 2
            local dx = math.max(math.abs(position.X - cell.x) - half, 0)
            local dz = math.max(math.abs(position.Z - cell.z) - half, 0)
            cleared = dx * dx + dz * dz < clearRadius * clearRadius
        end
        if cell.cleared ~= cleared then
            cell.cleared = cleared
            if cell.open then
                for _, entry in ipairs(cell.emitters) do entry.object.Enabled = not cleared end
            end
        end
    end
    for key, cell in pairs(state.cells) do
        if not keep[key] then
            pcall(function() cell.part:Destroy() end)
            state.cells[key] = nil
        end
    end
end

function World.stepFov(dt)
    local state = World.fov
    local camera = Game.gameCamera()
    if flag("world_fov", false) and camera then
        local numeric = type(camera._baseFov) == "number"
        if state.object ~= camera then state.object, state.orig, state.blend = camera, numeric and camera._baseFov or nil, 0 end
        local tanHalf = math.tan(math.rad(flag("world_fov_v", 90)) / 2)
        if flag("world_fov_dyn", false) then
            local weapon = Game.weapon()
            local target = (weapon and Game.aiming(weapon)) and 1 or 0
            state.blend = state.blend + (target - state.blend) * (1 - math.exp(-dt * flag("world_fov_speed", 10)))
            local scopedTan = math.tan(math.rad(flag("world_fov_ads", 60)) / 2)
            tanHalf = math.exp(Util.lerp(math.log(tanHalf), math.log(scopedTan), state.blend))
        end
        local magnify = camera._magSpring
        local zoom = type(magnify) == "table" and magnify.p
        local mult = flag("world_fov_mult", 1)
        state.final = math.clamp(math.deg(2 * math.atan(tanHalf * math.exp(-(type(zoom) == "number" and zoom or 0) * mult))), 5, 150)
        if type(zoom) == "number" then tanHalf = tanHalf * math.exp(zoom * (1 - mult)) end
        if numeric then camera._baseFov = math.clamp(math.deg(2 * math.atan(tanHalf)), 5, 150) end
    else
        state.final = nil
        if state.object then
            if state.orig and type(state.object._baseFov) == "number" then state.object._baseFov = state.orig end
            state.object, state.orig = nil, nil
        end
    end
end

World.cross = { lines = {}, edges = {}, dot = Draw.new("Circle", { Filled = true, NumSides = 12, Radius = 1.5, ZIndex = 10, Visible = false }), angle = 0 }
for index = 1, 4 do
    World.cross.edges[index] = Draw.new("Line", { ZIndex = 9, Color = BLACK, Visible = false })
    World.cross.lines[index] = Draw.new("Line", { ZIndex = 10, Visible = false })
end

World.gameCross = {}

function World.gameCrossFrame()
    local state = World.gameCross
    if state.frame and propGet(state.frame, "Parent") then return state.frame end
    local hud = Game.mods.HudScreenGui
    local ok, frame = pcall(function()
        local gui = (hud and hud.getScreenGui()) or LocalPlayer:FindFirstChildOfClass("PlayerGui"):FindFirstChild("HudScreenGui")
        return gui:FindFirstChild("Main"):FindFirstChild("DisplayCrosshairs")
    end)
    state.frame = (ok and typeof(frame) == "Instance") and frame or nil
    return state.frame
end

function World.showGameCross()
    local frame = World.gameCross.hidden
    World.gameCross.hidden = nil
    if not frame then return end
    local enabled = true
    local settings = Game.mods.PlayerSettingsInterface
    if settings and type(settings.getValue) == "function" then
        local ok, value = pcall(settings.getValue, "togglecrosshairs")
        enabled = not (ok and value == false)
    end
    propSet(frame, "Visible", enabled and (not Game.mods.CharacterInterface or Game.localAlive()))
end

function World.hideGameCross(active)
    if not active then return World.showGameCross() end
    local frame = World.gameCrossFrame()
    if frame and propGet(frame, "Visible") then
        World.gameCross.hidden = frame
        propSet(frame, "Visible", false)
    end
end

function World.stepCrosshair(center, now, dt)
    local cross = World.cross
    local shown = flag("cross_on", false)
    Util.guard("gamecross", World.hideGameCross, shown and flag("cross_hide_game", false))
    for index = 1, 4 do cross.lines[index].Visible, cross.edges[index].Visible = false, false end
    cross.dot.Visible = false
    if not shown then return end
    local color, alpha = flag("cross_color", WHITE), Util.opacity("cross_color")
    local length, thick, gap = flag("cross_len", 8), flag("cross_thick", 2), flag("cross_gap", 5)
    local outline = flag("cross_outline", true)
    local whole = math.max(1, math.floor(thick + 0.5))
    local shift = whole % 2 == 1 and 0.5 or 0
    center = Vector2.new(math.floor(center.X + 0.5) + shift, math.floor(center.Y + 0.5) + shift)
    if flag("cross_pulse", false) then gap = gap + flag("cross_pulse_range", 8) * (math.sin(now * flag("cross_pulse_speed", 3)) + 1) * 0.5 end
    local near = math.floor(gap + 0.5) - shift
    local far = near + math.max(1, math.floor(length + 0.5))
    if flag("cross_spin", false) then
        cross.angle = (cross.angle + math.rad(flag("cross_spin_speed", 90)) * dt) % (math.pi * 2)
    else
        cross.angle = 0
    end
    local cos, sin = math.cos(cross.angle), math.sin(cross.angle)
    local directions = { Vector2.new(cos, sin), Vector2.new(-sin, cos), Vector2.new(-cos, -sin), Vector2.new(sin, -cos) }
    for index = 1, 4 do
        if not (flag("cross_t", false) and index == 4) then
            local direction = directions[index]
            if outline then
                local edge = cross.edges[index]
                edge.From, edge.To = center + direction * (near - 1), center + direction * (far + 1)
                edge.Thickness, edge.Visible = whole + 2, true
            end
            local line = cross.lines[index]
            line.From, line.To = center + direction * near, center + direction * far
            line.Color, line.Transparency, line.Thickness, line.Visible = color, alpha, whole, true
        end
    end
    if flag("cross_dot", false) then
        cross.dot.Radius = whole % 2 == 1 and 1.5 or 2
        cross.dot.Position, cross.dot.Color, cross.dot.Transparency, cross.dot.Visible = center, color, alpha, true
    end
end

Util.onUnload(function()
    local state = World.fov
    if state.object and state.orig and type(state.object._baseFov) == "number" then state.object._baseFov = state.orig end
    for object, saved in pairs(World.orig) do
        for prop, old in pairs(saved) do propSet(object, prop, old) end
    end
    World.orig = {}
    World.showGameCross()
    World.dropMap()
    World.dropLights()
    World.showHidden()
    if World.sky and not World.sky.Parent then pcall(function() World.sky.Parent = Lighting end) end
    if World.ownSky then pcall(function() World.ownSky:Destroy() end) end
    World.cloudObject(false)
    World.dropWeather()
    for _, object in pairs(World.fx) do pcall(function() object:Destroy() end) end
    World.fx = {}
    if World.ownAtmos and World.atmos then pcall(function() World.atmos:Destroy() end) end
end)

local Tracers = { list = {}, fade = 0.5 }

function Tracers.presets()
    if Tracers.table then return Tracers.table end
    local mode = Enum.TextureMode
    local function sequence(value) return NumberSequence.new(value) end
    local function thinStyle(id)
        return {
            Alpha = 0, Texture = id, Brightness = 1.5, Transparency = sequence(0), LightEmission = 1, LightInfluence = 0,
            Segments = 1, TextureLength = 3, TextureMode = mode.Wrap, TextureSpeed = 1,
            Width0 = 0.12, Width1 = 0.12, FaceCamera = true,
        }
    end
    Tracers.table = {
        Beam = thinStyle("rbxassetid://12781852245"),
        Bolt = thinStyle("rbxassetid://446111271"),
        Trail = thinStyle("rbxassetid://6419989824"),
        Zigzag = thinStyle("rbxassetid://1274380363"),
        Heartrate = thinStyle("rbxassetid://5830549480"),
        Chain = thinStyle("rbxassetid://9632168658"),
        Glitch = thinStyle("rbxassetid://8089467613"),
        Swirl = thinStyle("rbxassetid://5638168605"),
        Obelus = {
            Alpha = 0.45, Texture = "rbxassetid://2382169232", Brightness = 1.5, Transparency = sequence(0.45), LightEmission = 1, LightInfluence = 0,
            Segments = 1, TextureLength = 5, TextureMode = mode.Stretch, TextureSpeed = 0, Width0 = 0.3, Width1 = 0.3, FaceCamera = true,
        },
        Lightning = {
            Alpha = 0.45, Texture = "rbxassetid://7151778302", Brightness = 1.5, Transparency = sequence(0.45), LightEmission = 1, LightInfluence = 0,
            Segments = 10, TextureLength = 1, TextureMode = mode.Stretch, TextureSpeed = 1, Width0 = 1.2, Width1 = 1.2, FaceCamera = true,
        },
        DNA = {
            Alpha = 0.45, Texture = "rbxassetid://7071778278", Brightness = 1.5, Transparency = sequence(0.45), LightEmission = 1, LightInfluence = 0,
            Segments = 1, TextureLength = 12, TextureMode = mode.Wrap, TextureSpeed = 1, Width0 = 0.6, Width1 = 0.6, FaceCamera = true,
        },
    }
    return Tracers.table
end

function Tracers.drop(record)
    for _, beam in ipairs(record.beams) do pcall(function() beam:Destroy() end) end
    for _, point in ipairs(record.points) do pcall(function() point:Destroy() end) end
end

function Tracers.measure(path)
    local cumulative, total = { 0 }, 0
    for index = 2, #path do
        total = total + (path[index] - path[index - 1]).Magnitude
        cumulative[index] = total
    end
    local chord = path[#path] - path[1]
    local deviation = 0
    if chord.Magnitude > 1e-3 then
        local direction = chord.Unit
        for index = 2, #path - 1 do
            local relative = path[index] - path[1]
            deviation = math.max(deviation, (relative - direction * relative:Dot(direction)).Magnitude)
        end
    end
    return cumulative, total, deviation
end

function Tracers.nodes(path, cumulative, total, count)
    local nodes, cursor = { path[1] }, 2
    for step = 1, count - 1 do
        local length = total * step / count
        while cursor < #path and cumulative[cursor] < length do cursor = cursor + 1 end
        local span = cumulative[cursor] - cumulative[cursor - 1]
        local k = span > 1e-6 and math.clamp((length - cumulative[cursor - 1]) / span, 0, 1) or 0
        nodes[#nodes + 1] = path[cursor - 1] + (path[cursor] - path[cursor - 1]) * k
    end
    nodes[#nodes + 1] = path[#path]
    return nodes
end

function Tracers.spawn(path, color)
    local presets = Tracers.presets()
    local name = flag("trace_texture", "Lightning")
    local preset = presets[name] or presets.Lightning
    local scale = flag("trace_width", 1)
    local terrain = Workspace.Terrain
    local stretch = preset.TextureMode == Enum.TextureMode.Stretch
    local cumulative, total, deviation = Tracers.measure(path)
    local count = 1
    if deviation > (stretch and 2 or 0.6) then count = math.clamp(math.ceil(total / 25), 6, 12) end
    local nodes = Tracers.nodes(path, cumulative, total, count)

    local glow = flag("trace_glow", false)
    local strength = glow and math.clamp(flag("trace_glow_strength", 4), 0, 10) or 0
    local layer = glow and strength > 0
    local gradient = flag("trace_gradient", false)
    local rainbow = gradient and flag("trace_rainbow", false)
    local start = flag("trace_grad_start", Color3.fromRGB(255, 94, 94))
    local finish = flag("trace_grad_end", Color3.fromRGB(94, 160, 255))
    local fade = gradient and math.clamp(flag("trace_grad_fade", 0), 0, 1) or 0
    local glowColor = flag("trace_glow_color", Color3.fromRGB(255, 255, 255))
    local glowSame = flag("trace_glow_same", true)

    local function colorAt(t)
        if rainbow then return Color3.fromHSV((t * 0.8) % 1, 0.85, 1) end
        return Color3.new(start.R + (finish.R - start.R) * t, start.G + (finish.G - start.G) * t, start.B + (finish.B - start.B) * t)
    end
    local function colorRange(t0, t1)
        if not gradient then return ColorSequence.new(color) end
        if not rainbow then return ColorSequence.new(colorAt(t0), colorAt(t1)) end
        local steps = count == 1 and 8 or 3
        local keys = {}
        for step = 0, steps do keys[#keys + 1] = ColorSequenceKeypoint.new(step / steps, colorAt(t0 + (t1 - t0) * step / steps)) end
        return ColorSequence.new(keys)
    end

    local segment = total / count
    local record = { beams = {}, points = {}, parts = {}, born = os.clock() }
    local ok = pcall(function()
        for index, position in ipairs(nodes) do
            local point = Instance.new("Attachment")
            point.Name = Util.randomName()
            point.Parent = terrain
            local frame = CFrame.new(position)
            if count > 1 then
                local ahead = nodes[math.min(index + 1, #nodes)] - nodes[math.max(index - 1, 1)]
                if ahead.Magnitude > 1e-4 then frame = CFrame.new(position, position + ahead) * CFrame.Angles(0, math.pi / 2, 0) end
            end
            point.WorldCFrame = frame
            record.points[index] = point
        end
        local tiles = math.max(1, math.floor(segment / preset.TextureLength + 0.5))
        for index = 1, count do
            local t0, t1 = (index - 1) / count, index / count
            local reach = (nodes[index + 1] - nodes[index]).Magnitude / 3
            local function place(beam)
                beam.Attachment0, beam.Attachment1 = record.points[index], record.points[index + 1]
                if count > 1 then
                    beam.CurveSize0, beam.CurveSize1 = reach, -reach
                    beam.Segments = math.max(preset.Segments, 4)
                end
                beam.Parent = terrain
                record.beams[#record.beams + 1] = beam
            end
            local a0 = preset.Alpha + (1 - preset.Alpha) * fade * t0
            local a1 = preset.Alpha + (1 - preset.Alpha) * fade * t1
            local sequence = colorRange(t0, t1)
            if layer then
                local base = 0.9 - 0.06 * strength
                local g0, g1 = base + (1 - base) * fade * t0, base + (1 - base) * fade * t1
                local halo = Instance.new("Beam")
                halo.Name = Util.randomName()
                halo.LightEmission, halo.LightInfluence, halo.FaceCamera = 1, 0, true
                halo.Segments = preset.Segments
                halo.Width0, halo.Width1 = preset.Width0 * scale * (1.5 + 0.15 * strength), preset.Width1 * scale * (1.5 + 0.15 * strength)
                halo.Transparency = NumberSequence.new(g0, g1)
                halo.Color = glowSame and sequence or ColorSequence.new(glowColor)
                propSet(halo, "Brightness", preset.Brightness)
                propSet(halo, "ZOffset", -0.05)
                place(halo)
                record.parts[#record.parts + 1] = { beam = halo, a0 = g0, a1 = g1 }
            end
            local beam = Instance.new("Beam")
            beam.Name = Util.randomName()
            for prop, value in pairs(preset) do
                if prop == "Width0" or prop == "Width1" then value = value * scale end
                if prop == "Brightness" and glow then value = value * (1 + 0.2 * strength) end
                if prop ~= "Alpha" and prop ~= "Transparency" then beam[prop] = value end
            end
            if count > 1 and not stretch then beam.TextureLength = segment / tiles end
            beam.Transparency = NumberSequence.new(a0, a1)
            beam.Color = sequence
            place(beam)
            record.parts[#record.parts + 1] = { beam = beam, a0 = a0, a1 = a1 }
        end
    end)
    if not ok then
        Tracers.drop(record)
        return false
    end
    local used = #record.beams
    for _, other in ipairs(Tracers.list) do used = used + #other.beams end
    while #Tracers.list > 0 and (#Tracers.list >= 40 or used > 360) do
        local oldest = table.remove(Tracers.list, 1)
        used = used - #oldest.beams
        Tracers.drop(oldest)
    end
    Tracers.list[#Tracers.list + 1] = record
    return true
end

function Tracers.trajectory(origin, position, velocity, acceleration, life)
    local flight = math.clamp(type(life) == "number" and life or 2, 0.1, 5)
    local step = math.max(0.04, flight / 47)
    local path = { origin }
    local previous, hit = position, nil
    local time = 0
    while time < flight - 1e-6 do
        time = math.min(time + step, flight)
        local point = position + velocity * time + acceleration * (0.5 * time * time)
        local result = Game.cast(previous, point - previous, Barrel.params)
        if result then
            path[#path + 1] = result.Position
            hit = result.Position
            break
        end
        path[#path + 1] = point
        previous = point
    end
    return path, hit
end

function Tracers.hideBeam(bullet)
    local beams = type(bullet._beamObject) == "table" and bullet._beamObject.beams
    if type(beams) ~= "table" then return end
    for _, beam in pairs(beams) do propSet(beam, "Enabled", false) end
end

function Tracers.isTeam(info)
    local ok, list = pcall(Entities.update)
    if not (ok and type(list) == "table") then return false end
    local extra = type(info.extra) == "table" and info.extra
    for _, key in ipairs({ "player", "owner", "shooter" }) do
        local record = extra and typeof(extra[key]) == "Instance" and Entities.byPlayer[extra[key]]
        if record then return record.enemy == false end
    end
    local at = typeof(info.visualorigin) == "Vector3" and info.visualorigin or info.position
    local best, nearest = nil, 12
    for _, rec in ipairs(list) do
        local head = rec.head and rec.rendered and rec.head.Position or rec.pos
        local distance = math.min((rec.pos - at).Magnitude, (head - at).Magnitude)
        if distance < nearest then best, nearest = rec, distance end
    end
    return best ~= nil and best.enemy == false
end

function Tracers.origin(info, mine)
    local origin = info.visualorigin
    if not mine then return typeof(origin) == "Vector3" and origin or info.position end
    local extra = type(info.extra) == "table" and info.extra
    for _, weapon in ipairs({ extra and extra.firearmObject or false, Barrel.weapon or false }) do
        if type(weapon) == "table" and type(weapon.getBarrelCFrame) == "function" then
            local ok, frame = pcall(weapon.getBarrelCFrame, weapon)
            if ok and typeof(frame) == "CFrame" and frame.Position == frame.Position then return frame.Position end
        end
    end
    return typeof(origin) == "Vector3" and origin or info.position
end

function Tracers.fromBullet(info, mine)
    local position, velocity = info.position, info.velocity
    if typeof(position) ~= "Vector3" or typeof(velocity) ~= "Vector3" or velocity.Magnitude < 1e-3 then return false end
    local color
    if mine then
        if not flag("trace_on", false) then return false end
        color = flag("trace_color", Color3.fromRGB(255, 94, 94))
    elseif Tracers.isTeam(info) then
        if not flag("trace_team_on", false) then return false end
        color = flag("trace_team_color", Color3.fromRGB(90, 220, 130))
    else
        if not flag("trace_enemy_on", false) then return false end
        color = flag("trace_enemy_color", Color3.fromRGB(94, 160, 255))
    end
    local origin = Tracers.origin(info, mine)
    if typeof(origin) ~= "Vector3" then return false end
    local acceleration = typeof(info.acceleration) == "Vector3" and info.acceleration or Game.accel
    Barrel.refreshParams(os.clock())
    local path = Tracers.trajectory(origin, position, velocity, acceleration, info.life)
    if #path < 2 or (path[#path] - origin).Magnitude < 0.5 then return false end
    return Tracers.spawn(path, color)
end

function Tracers.step(now)
    local life = flag("trace_time", 4)
    for index = #Tracers.list, 1, -1 do
        local record = Tracers.list[index]
        local age = now - record.born
        if age >= life + Tracers.fade then
            Tracers.drop(record)
            table.remove(Tracers.list, index)
        elseif age > life then
            local k = (age - life) / Tracers.fade
            for _, part in ipairs(record.parts) do
                propSet(part.beam, "Transparency", NumberSequence.new(part.a0 + (1 - part.a0) * k, part.a1 + (1 - part.a1) * k))
            end
        end
    end
end

Util.onUnload(function()
    for _, record in ipairs(Tracers.list) do Tracers.drop(record) end
    Tracers.list = {}
end)

local Nades = { list = {}, known = {}, lines = {}, badges = {}, fade = setmetatable({}, { __mode = "k" }), hooked = false, scanAt = -math.huge, predAt = -math.huge }

local function hermite(t0, p0, v0, t1, p1, v1, t)
    if t0 == t1 then return p1 end
    local span = t1 - t0
    local a, b = (t - t0) / span, (t1 - t) / span
    return b * b * (b + 3 * a) * p0 + span * b * b * a * v0 - span * b * a * a * v1 + a * a * (a + 3 * b) * p1
end

local function graphDamage(graph, distance)
    for index = 1, #graph do
        local node = graph[index]
        if distance < node.distance then
            local previous = graph[index - 1]
            if not previous then return node.damage end
            local fraction = (distance - previous.distance) / (node.distance - previous.distance)
            return (1 - fraction) * previous.damage + fraction * node.damage
        end
    end
    return graph[#graph].damage
end

function Nades.data(name)
    local cached = Nades.known[name]
    if cached ~= nil then return cached or nil end
    local content = Game.mods.ContentInterface
    local data
    if content and type(content.getWeaponData) == "function" then
        local ok, value = pcall(content.getWeaponData, name)
        if ok and type(value) == "table" then data = value end
    end
    Nades.known[name] = data or false
    return data
end

function Nades.sample(nodes, t)
    local count = #nodes
    if t <= nodes[1].t then return nodes[1].p end
    for index = 1, count - 1 do
        local a, b = nodes[index], nodes[index + 1]
        if t < b.t then return hermite(a.t, a.p, a.v, b.t, b.p, b.v, t) end
    end
    return nodes[count].p
end

function Nades.onThrow(player, name, nodes, fuse)
    if type(nodes) ~= "table" or #nodes == 0 or type(fuse) ~= "number" or typeof(nodes[1].p) ~= "Vector3" then return end
    local own = player == LocalPlayer
    if not own and player.TeamColor == LocalPlayer.TeamColor then return end
    local ping = 0
    pcall(function() ping = Game.mods.NetworkClient.getPing() end)
    local boom = fuse - ping / 2
    local first, limit = nodes[1].t, math.min(boom, nodes[#nodes].t)
    local points = {}
    local t = first
    while t < limit and #points < 90 do
        points[#points + 1] = Nades.sample(nodes, t)
        t = t + 0.1
    end
    points[#points + 1] = Nades.sample(nodes, math.max(limit, first))
    if #Nades.list >= 24 then table.remove(Nades.list, 1) end
    Nades.list[#Nades.list + 1] = {
        player = player, name = name, nodes = nodes, own = own, data = Nades.data(name),
        recv = Game.time(), boom = boom, first = first, points = points, land = points[#points],
    }
end

function Nades.scanHandlers(fn)
    if type(fn) ~= "function" then return nil end
    local values = {}
    local getter = debug.getupvalues or getupvalues
    if type(getter) == "function" then
        local ok, list = pcall(getter, fn)
        if ok and type(list) == "table" then
            for _, value in pairs(list) do values[#values + 1] = value end
        end
    end
    if type(debug.getupvalue) == "function" then
        for index = 1, 40 do
            local ok, a, b = pcall(debug.getupvalue, fn, index)
            if not ok or (a == nil and b == nil) then break end
            values[#values + 1] = type(b) == "table" and b or a
        end
    end
    for _, value in ipairs(values) do
        if type(value) == "table" and type(rawget(value, "newgrenade")) == "function" then return value end
    end
    return nil
end

function Nades.findHandlers()
    local network = Game.mods.NetworkClient
    if type(network) ~= "table" then return nil end
    local found = Nades.scanHandlers(network.receive) or Nades.scanHandlers(network.fireReady)
    if found then return found end
    local now = os.clock()
    if type(getgc) == "function" and now - Nades.scanAt >= 30 then
        Nades.scanAt = now
        pcall(function()
            for _, value in ipairs(getgc(true)) do
                if type(value) == "table" and type(rawget(value, "newgrenade")) == "function" and type(rawget(value, "ping")) == "function" then
                    found = value
                    return
                end
            end
        end)
    end
    return found
end

function Nades.hook()
    if Nades.hooked then return end
    local handlers = Nades.findHandlers()
    if not handlers then return end
    local original = rawget(handlers, "newgrenade")
    handlers.newgrenade = function(player, name, nodes, windows, fuse, ...)
        pcall(Nades.onThrow, player, name, nodes, fuse)
        return original(player, name, nodes, windows, fuse, ...)
    end
    Nades.hooked = true
    Util.onUnload(function()
        pcall(function() handlers.newgrenade = original end)
        Nades.hooked = false
    end)
end

function Nades.mapParams()
    local map = Workspace:FindFirstChild("Map")
    if not map then Nades.params = nil return nil end
    local cached = Nades.params
    if cached and cached.FilterDescendantsInstances[1] == map then return cached end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    pcall(function() params.RespectCanCollide = true end)
    pcall(function() params.IgnoreWater = true end)
    params.FilterDescendantsInstances = { map }
    Nades.params = params
    return params
end

function Nades.damage(data, land, origin, cache, now)
    local graph = data and data.damageGraph
    if type(graph) ~= "table" or #graph == 0 then return nil end
    local radius = graph[#graph].distance
    local distance = (origin - land).Magnitude
    if distance >= radius then return 0, radius end
    if now - (cache.losAt or -1) > 0.15 then
        cache.losAt = now
        local params = Nades.mapParams()
        cache.blocked = params ~= nil and Workspace:Raycast(land, origin - land, params) ~= nil
    end
    if cache.blocked then return 0, radius end
    return graphDamage(graph, distance), radius
end

function Nades.line(cam, a, b, color, alpha, thick)
    local from, fromFront = Draw.project(cam, a)
    local to, toFront = Draw.project(cam, b)
    if not (fromFront and toFront) then return end
    Nades.lineUsed = Nades.lineUsed + 1
    local line = Nades.lines[Nades.lineUsed]
    if not line then
        line = Draw.new("Line", { ZIndex = 5, Visible = false })
        Nades.lines[Nades.lineUsed] = line
    end
    line.From, line.To, line.Color, line.Thickness, line.Transparency, line.Visible = from, to, color, thick, alpha, true
end

function Nades.ring(cam, center, radius, color, alpha)
    local segments = 28
    local previous
    for index = 0, segments do
        local angle = index / segments * math.pi * 2
        local point = center + Vector3.new(math.cos(angle) * radius, 0.15, math.sin(angle) * radius)
        if previous then Nades.line(cam, previous, point, color, alpha, 1) end
        previous = point
    end
end

Nades.predKey = {}

function Nades.badge()
    local grey = Color3.fromRGB(170, 172, 178)
    return {
        disc = Draw.new("Circle", { Filled = true, Radius = 20, NumSides = 32, Color = Color3.fromRGB(12, 12, 14), Transparency = 0.85, ZIndex = 6, Visible = false }),
        rim = Draw.new("Circle", { Filled = false, Radius = 20, NumSides = 32, Thickness = 1, Color = Color3.fromRGB(60, 60, 66), Transparency = 1, ZIndex = 7, Visible = false }),
        body = Draw.new("Circle", { Filled = true, Radius = 5, NumSides = 20, Color = grey, Transparency = 1, ZIndex = 8, Visible = false }),
        top = Draw.new("Square", { Filled = true, Size = Vector2.new(4, 3), Color = grey, Transparency = 1, ZIndex = 8, Visible = false }),
        lever = Draw.new("Square", { Filled = true, Size = Vector2.new(6, 2), Color = grey, Transparency = 1, ZIndex = 8, Visible = false }),
        icon = Draw.image(8),
        text = Draw.text(11, 9),
        back = Draw.new("Square", { Filled = true, Size = Vector2.new(24, 3), Color = Color3.fromRGB(40, 40, 44), Transparency = 1, ZIndex = 8, Visible = false }),
        bar = Draw.new("Square", { Filled = true, Size = Vector2.new(24, 3), Transparency = 1, ZIndex = 9, Visible = false }),
    }
end

local BADGE_R = 19

function Nades.fit(badge, text, top, bottom)
    local key = text .. "|" .. top .. "|" .. bottom
    if badge.fitKey == key then return badge.fitSize end
    local reach = math.max(math.abs(top), math.abs(bottom))
    local allowed = 2 * math.sqrt(math.max(BADGE_R * BADGE_R - reach * reach, 0)) - 2
    local size = 11
    while size > 7 do
        badge.text.Size = size
        local ok, bounds = pcall(function() return badge.text.TextBounds end)
        local width = ok and typeof(bounds) == "Vector2" and bounds.X > 0 and bounds.X or #text * size * 0.56
        if width <= allowed then break end
        size = size - 1
    end
    badge.text.Size = size
    badge.fitKey, badge.fitSize = key, size
    return size
end

function Nades.ease(key, target)
    local now = os.clock()
    local state = Nades.fade[key]
    if not state then
        state = { t = target, at = now }
        Nades.fade[key] = state
    end
    local dt = math.clamp(now - state.at, 0, 0.1)
    state.at = now
    state.t = state.t + (target - state.t) * math.min(1, dt * 8)
    return state.t
end

function Nades.label(cam, position, info)
    local point, front = Draw.project(cam, position)
    if not front then return end
    Nades.badgeUsed = Nades.badgeUsed + 1
    local badge = Nades.badges[Nades.badgeUsed]
    if not badge then
        badge = Nades.badge()
        Nades.badges[Nades.badgeUsed] = badge
    end
    local x, y = point.X, point.Y
    local t = Nades.ease(info.key or badge, info.threat or 0)
    local style = Nades.style(info.verdict, info.fallback, t)
    badge.disc.Position, badge.disc.Color, badge.disc.Transparency, badge.disc.Visible = point, style.disc, style.opacity, true
    badge.rim.Color = style.rim
    badge.rim.Position, badge.rim.Visible = point, true
    if Icons.place(badge.icon, info.icon or "hegrenade", x, y - 9, 16, 14, style.icon, 1) then
        badge.body.Visible, badge.top.Visible, badge.lever.Visible = false, false, false
    else
        badge.icon.Visible = false
        badge.body.Color, badge.top.Color, badge.lever.Color = style.icon, style.icon, style.icon
        badge.body.Position, badge.body.Visible = Vector2.new(x, y - 8), true
        badge.top.Position, badge.top.Visible = Vector2.new(x - 2, y - 15), true
        badge.lever.Position, badge.lever.Visible = Vector2.new(x - 1, y - 17), true
    end
    local hasBar = info.frac ~= nil
    if info.text then
        local top = hasBar and -1 or 1
        local size = Nades.fit(badge, info.text, top, top + 11)
        badge.text.Text, badge.text.Position, badge.text.Color, badge.text.Visible = info.text, Vector2.new(x, y + top + (11 - size) / 2), style.text, true
    else
        badge.text.Visible = false
    end
    if hasBar then
        local width = math.max(math.floor(24 * math.clamp(info.frac, 0, 1) + 0.5), 1)
        badge.back.Position, badge.back.Color, badge.back.Visible = Vector2.new(x - 12, y + 12), style.back, true
        badge.bar.Position, badge.bar.Size, badge.bar.Color, badge.bar.Visible = Vector2.new(x - 12, y + 12), Vector2.new(width, 3), style.bar, true
    else
        badge.back.Visible, badge.bar.Visible = false, false
    end
end

function Nades.hideBadge(badge)
    for _, object in pairs(badge) do
        if typeof(object) ~= "string" and typeof(object) ~= "number" then object.Visible = false end
    end
end

function Nades.style(verdict, fallback, t)
    local danger = flag("nade_danger_color", Color3.fromRGB(255, 60, 60))
    local mix = Util.lerpColor
    return {
        icon = mix(Color3.fromRGB(170, 172, 178), Color3.fromRGB(235, 235, 235), t),
        disc = mix(Color3.fromRGB(12, 12, 14), danger, t),
        opacity = 0.85 + 0.1 * t,
        rim = mix(Color3.fromRGB(60, 60, 66), Color3.fromRGB(255, 140, 140), t),
        text = WHITE,
        bar = mix(verdict and Color3.fromRGB(255, 60, 60) or fallback, Color3.fromRGB(120, 10, 10), t),
        back = mix(Color3.fromRGB(40, 40, 44), Color3.fromRGB(200, 70, 70), t),
    }
end

function Nades.verdict(damage)
    if damage == nil then return nil end
    if damage <= 0 then return "Safe", flag("nade_safe_color", Color3.fromRGB(90, 255, 130)) end
    local shown = math.floor(damage + 0.5)
    local label = shown >= 100 and "LETHAL" or "-" .. shown .. " hp"
    return label, Util.lerpColor(flag("nade_ring_color", Color3.fromRGB(255, 220, 60)), flag("nade_ring_lethal_color", Color3.fromRGB(255, 60, 60)), math.clamp(damage / 100, 0, 1))
end

function Nades.simulate(origin, velocity, gravity, elasticity, friction, duration)
    local params = Nades.mapParams()
    local step = 0.05
    local points, bounces = { origin }, {}
    local position, speed = origin, velocity
    local elapsed = 0
    while elapsed < duration and #points < 130 do
        local move = speed * step + gravity * (0.5 * step * step)
        local hit = params and Game.cast(position, move, params)
        if hit then
            local used = step * math.clamp((hit.Position - position).Magnitude / math.max(move.Magnitude, 1e-6), 0, 1)
            speed = speed + gravity * used
            position = hit.Position + hit.Normal * 0.05
            local along = hit.Normal * speed:Dot(hit.Normal)
            speed = (speed - along) * (1 - friction) - along * elasticity + gravity * (step - used)
            points[#points + 1] = position
            bounces[#bounces + 1] = position
            if #bounces > 5 or speed.Magnitude < 2 then break end
        else
            position = position + move
            speed = speed + gravity * step
            points[#points + 1] = position
        end
        elapsed = elapsed + step
    end
    return points, bounces
end

function Nades.throwState(weapon)
    local gameCam = Game.gameCamera()
    local root = Game.rootPart()
    if not (gameCam and root and weapon._mainPart) then return nil end
    local speed = Game.stat(weapon, "throwspeed")
    if type(speed) ~= "number" then return nil end
    local ok, frame, base, mainPosition = pcall(function()
        return gameCam:getCFrame(), gameCam:getBaseCFrame().Position, weapon._mainPart.CFrame.Position
    end)
    if not (ok and typeof(frame) == "CFrame") then return nil end
    local aim = (frame * CFrame.Angles(math.rad(Game.stat(weapon, "throwangle") or 0), 0, 0)).LookVector
    local okVelocity, rootVelocity = pcall(function() return root.AssemblyLinearVelocity end)
    if not (okVelocity and typeof(rootVelocity) == "Vector3") then
        okVelocity, rootVelocity = pcall(function() return root.Velocity end)
    end
    if not (okVelocity and typeof(rootVelocity) == "Vector3") then rootVelocity = Vector3.zero end
    local start = mainPosition
    local params = Nades.mapParams()
    local hit = params and Workspace:Raycast(base, mainPosition - base, params)
    if hit then start = hit.Position + hit.Normal * 0.01 end
    return start, aim * speed + rootVelocity
end

function Nades.predict(cam, now, origin)
    local weapon = Game.weapon()
    local held, armed = false, false
    if flag("nade_predict", false) and weapon and type(weapon.getWeaponType) == "function" then
        local ok, kind = pcall(weapon.getWeaponType, weapon)
        held = ok and kind == "Grenade" and type(weapon.isEquipped) == "function" and weapon:isEquipped() == true
        if held then
            local okArmed, state = pcall(weapon.isState, weapon, "armed")
            armed = okArmed and state == true
            if not armed and not flag("nade_predict_pre", false) then held = false end
        end
    end
    if not held then
        Nades.pred = nil
        return
    end
    local pred = Nades.pred
    if not pred or pred.weapon ~= weapon or pred.armed ~= armed or now - Nades.predAt > 0.05 then
        Nades.predAt = now
        local start, velocity = Nades.throwState(weapon)
        if not start then
            Nades.pred = nil
            return
        end
        local duration = Game.stat(weapon, "fusetime") or 5
        if armed and type(weapon._fuseTime) == "number" then duration = math.max(weapon._fuseTime - Game.time(), 0.1) end
        local gravity = typeof(weapon._acceleration) == "Vector3" and weapon._acceleration or Vector3.new(0, -80, 0)
        local points, bounces = Nades.simulate(start, velocity, gravity, weapon._bounceElasticity or 0.2, weapon._frictionConstant or 0.08, duration)
        pred = { weapon = weapon, points = points, bounces = bounces, land = points[#points], duration = duration, armed = armed, cache = pred and pred.cache or {} }
        Nades.pred = pred
    end
    local color = flag("nade_predict_color", Color3.fromRGB(120, 200, 255))
    local alpha = armed and 1 or 0.45
    for index = 1, #pred.points - 1 do Nades.line(cam, pred.points[index], pred.points[index + 1], color, alpha, 1.5) end
    if flag("nade_predict_bounce", true) then
        for _, point in ipairs(pred.bounces) do Nades.ring(cam, point, 0.8, color, alpha) end
    end
    local data = weapon._weaponData or weapon.weaponData
    local damage = Nades.damage(data, pred.land, origin, pred.cache, now)
    local verdict, verdictColor = Nades.verdict(damage)
    local radius = data and type(data.damageGraph) == "table" and #data.damageGraph > 0 and data.damageGraph[#data.damageGraph].distance
    Nades.ring(cam, pred.land, 1.5, color, alpha)
    if radius and flag("nade_ring", true) then Nades.ring(cam, pred.land, radius, verdictColor or color, 0.6 * alpha) end
    local left = armed and type(weapon._fuseTime) == "number" and math.max(weapon._fuseTime - Game.time(), 0) or pred.duration
    local total = math.max(Game.stat(weapon, "fusetime") or pred.duration, 0.1)
    local show = verdict and flag("nade_dmg", true)
    Nades.label(cam, pred.land, {
        text = show and verdict or nil, verdict = show and verdict or nil, fallback = color, key = Nades.predKey, icon = Icons.grenadeKey(weapon.weaponName),
        threat = show and damage and math.clamp(damage / 100, 0, 1) or 0, frac = left / total,
    })
end

function Nades.step(cam, now)
    Nades.lineUsed, Nades.badgeUsed = 0, 0
    if flag("nade_on", false) then
        local ownOn, enemyOn = flag("nade_own", true), flag("nade_enemy", true)
        local maxDistance = flag("nade_dist", 400)
        local ownColor, enemyColor = flag("nade_own_color", Color3.fromRGB(120, 255, 170)), flag("nade_enemy_color", Color3.fromRGB(255, 90, 60))
        local root = Game.rootPart()
        local camPosition = Game.eye(cam).Position
        local origin = root and root.Position or camPosition
        local time = Game.time()
        for index = #Nades.list, 1, -1 do
            local record = Nades.list[index]
            local elapsed = time - record.recv
            local remaining = record.boom - elapsed
            if remaining < -0.3 then
                table.remove(Nades.list, index)
            elseif (record.own and ownOn) or (not record.own and enemyOn) then
                local position = Nades.sample(record.nodes, math.max(elapsed, record.first))
                if (position - camPosition).Magnitude <= maxDistance then
                    local color = record.own and ownColor or enemyColor
                    if flag("nade_path", true) then
                        local from = math.max(1, math.floor((elapsed - record.first) / 0.1) + 1)
                        local last = position
                        for pointIndex = from, #record.points do
                            Nades.line(cam, last, record.points[pointIndex], color, 0.9, 1.5)
                            last = record.points[pointIndex]
                        end
                    end
                    record.cache = record.cache or {}
                    local damage, radius = Nades.damage(record.data, record.land, origin, record.cache, now)
                    local verdict, verdictColor = Nades.verdict(damage)
                    if radius and flag("nade_ring", true) then Nades.ring(cam, record.land, radius, verdictColor or color, 0.7) end
                    local show = verdict and flag("nade_dmg", true)
                    Nades.label(cam, position, {
                        text = show and verdict or nil, verdict = show and verdict or nil, fallback = color, key = record, icon = Icons.grenadeKey(record.name),
                        threat = show and damage and math.clamp(damage / 100, 0, 1) or 0,
                        frac = flag("nade_timer", true) and math.max(remaining, 0) / math.max(record.boom, 0.1) or nil,
                    })
                end
            end
        end
        if not Nades.hooked then
            Items.scan(now)
            for _, instance in ipairs(Items.grenades) do
                local position = instance.Parent and Items.position(instance)
                if position and (position - camPosition).Magnitude <= maxDistance then
                    Nades.label(cam, position, { text = math.floor((position - camPosition).Magnitude * STUDS_TO_M) .. "m", fallback = enemyColor, key = instance })
                end
            end
        end
    end
    local root = Game.rootPart()
    Nades.predict(cam, now, root and root.Position or Game.eye(cam).Position)
    for index = Nades.lineUsed + 1, #Nades.lines do Nades.lines[index].Visible = false end
    for index = Nades.badgeUsed + 1, #Nades.badges do Nades.hideBadge(Nades.badges[index]) end
end

local Feedback = { at = -10, head = false, numbers = {}, texts = {}, spiral = 0, hooked = {} }

local HIT_SOUNDS = {
    ["Gamesense"] = "rbxassetid://4817809188",
    ["CSGO"] = "rbxassetid://5764885315",
    ["Click"] = "rbxassetid://1347140027",
    ["Hitmarker"] = "rbxassetid://1129547534",
    ["Minecraft"] = "rbxassetid://4018616850",
    ["Neverlose"] = "rbxassetid://6607204501",
    ["Rust"] = "rbxassetid://5043539486",
    ["TF2"] = "rbxassetid://8255306220",
    ["Windows"] = "rbxassetid://9066167010",
    ["Alt Hitmarker"] = "rbxassetid://287062939",
    ["Alt Killshot"] = { "rbxassetid://898398768", "rbxassetid://898398730", "rbxassetid://898398743" },
    ["Alt Headshot kill"] = { "rbxassetid://898398768", "rbxassetid://898398785", "rbxassetid://898398795", "rbxassetid://898398809", "rbxassetid://898398817", "rbxassetid://898398837" },
}
local HIT_SOUND_ORDER = { "Gamesense", "CSGO", "Click", "Hitmarker", "Minecraft", "Neverlose", "Rust", "TF2", "Windows", "Alt Hitmarker", "Alt Killshot", "Alt Headshot kill" }

function Feedback.play(name, volume, pitch)
    local entry = HIT_SOUNDS[name]
    if type(entry) == "table" then entry = entry[math.random(#entry)] end
    if not entry then return end
    pcall(function()
        local sound = Instance.new("Sound")
        sound.SoundId, sound.Volume, sound.PlaybackSpeed = entry, volume, pitch
        sound.Parent = game:GetService("SoundService")
        sound:Play()
        game:GetService("Debris"):AddItem(sound, 4)
    end)
end

function Feedback.onHit(isHead)
    Feedback.at, Feedback.head = os.clock(), isHead
    if flag("hit_snd", false) then
        local name = flag("hit_snd_id", "Gamesense")
        if isHead and flag("hit_snd_head", false) then name = flag("hit_snd_head_id", "Alt Headshot kill") end
        Feedback.play(name, flag("hit_snd_vol", 1.5), flag("hit_snd_pitch", 1))
    end
end

Feedback.kills = {}

function Feedback.noteKill(victim, now)
    local record = Entities.byPlayer[victim]
    local kill = { victim = victim, at = now, model = record and record.model, pos = record and record.pos }
    pcall(function()
        local entry = Game.mods.ReplicationInterface.getEntry(victim)
        local object = entry and entry._thirdPersonObject
        local model = object and object._characterModel
        if typeof(model) == "Instance" then kill.model = model end
        if typeof(kill.pos) ~= "Vector3" and entry then
            local position = entry:getPosition()
            if typeof(position) == "Vector3" then kill.pos = position end
        end
    end)
    if #Feedback.kills >= 12 then table.remove(Feedback.kills, 1) end
    Feedback.kills[#Feedback.kills + 1] = kill
end

function Feedback.onKill(info)
    if type(info) ~= "table" or info.attacker ~= LocalPlayer or info.victim == nil or info.victim == LocalPlayer then return end
    Feedback.noteKill(info.victim, os.clock())
    if not flag("kill_snd", false) then return end
    Feedback.play(flag("kill_snd_id", "Alt Killshot"), flag("kill_snd_vol", 1.5), flag("kill_snd_pitch", 1))
end

function Feedback.addNumber(position, part, damage, big)
    if typeof(position) ~= "Vector3" or type(damage) ~= "number" then return end
    local shown = damage
    if shown > 99 and shown < 100 then shown = 99 elseif shown > 0 and shown < 1 then shown = 1 else shown = math.floor(shown + 0.5) end
    local color
    if part == "Head" then color = flag("dmg_head", Color3.fromRGB(255, 102, 102))
    elseif part == "Torso" then color = flag("dmg_torso", Color3.fromRGB(255, 150, 0))
    else color = flag("dmg_limb", Color3.fromRGB(255, 255, 0)) end
    Feedback.spiral = Feedback.spiral + 1
    local angle = 2.399963229728653 * Feedback.spiral
    if #Feedback.numbers >= 24 then table.remove(Feedback.numbers, 1) end
    Feedback.numbers[#Feedback.numbers + 1] = {
        pos = position, text = tostring(shown), color = color, born = os.clock(),
        dx = math.cos(angle) * 22, big = big == true,
    }
end

function Feedback.hook()
    local mods = Game.mods
    if not Feedback.hooked.marker and mods.HudCrosshairsInterface then
        Feedback.hooked.marker = Util.hook(mods.HudCrosshairsInterface, "fireHitmarker", function(original)
            return function(isHead, ...)
                pcall(Feedback.onHit, isHead == true)
                if flag("hit_hide_game", false) then return nil end
                return original(isHead, ...)
            end
        end)
    end
    if not Feedback.hooked.damage and mods.HudDamageInterface then
        Feedback.hooked.damage = Util.hook(mods.HudDamageInterface, "createDamageRangeEffect", function(original)
            return function(position, part, damage, big, ...)
                if flag("dmg_on", false) then
                    pcall(Feedback.addNumber, position, part, damage, big)
                    return nil
                end
                return original(position, part, damage, big, ...)
            end
        end)
    end
    if not Feedback.hooked.bullets and mods.BulletInterface then
        Feedback.hooked.bullets = Util.hook(mods.BulletInterface, "newBullet", function(original)
            return function(info, ...)
                local bullet = original(info, ...)
                pcall(function()
                    if not bullet or type(info) ~= "table" then return end
                    local mine = type(info.extra) == "table" and info.extra.firearmObject ~= nil
                    if Tracers.fromBullet(info, mine) and flag("trace_hide_beam", true) then Tracers.hideBeam(bullet) end
                end)
                return bullet
            end
        end)
    end
    local events = mods.PlayerStatusEvents
    if not Feedback.hooked.kills and events and events.onPlayerDied and type(events.onPlayerDied.connect) == "function" then
        local ok, connection = pcall(function()
            return events.onPlayerDied:connect(function(info) pcall(Feedback.onKill, info) end)
        end)
        if ok then
            Feedback.hooked.kills = true
            Util.onUnload(function()
                pcall(function() connection:Disconnect() end)
                Feedback.hooked.kills = nil
            end)
        end
    end
end

Feedback.lines, Feedback.edges = {}, {}
for index = 1, 4 do
    Feedback.edges[index] = Draw.new("Line", { Thickness = 3, Color = BLACK, ZIndex = 11, Visible = false })
    Feedback.lines[index] = Draw.new("Line", { Thickness = 1, ZIndex = 12, Visible = false })
end

function Feedback.step(cam, center, now)
    local age = now - Feedback.at
    local duration = flag("hit_marker_time", 0.4)
    local show = flag("hit_marker", false) and age < duration
    for index = 1, 4 do Feedback.lines[index].Visible, Feedback.edges[index].Visible = false, false end
    if show then
        local progress = age / duration
        local size = flag("hit_marker_size", 9)
        local gap = 3 + progress * 4
        local color = Feedback.head and flag("hit_marker_head", WHITE) or flag("hit_marker_color", WHITE)
        for index = 1, 4 do
            local direction = Vector2.new(index % 2 == 1 and -1 or 1, index <= 2 and -1 or 1).Unit
            local from, to = center + direction * gap, center + direction * (gap + size)
            local edge, line = Feedback.edges[index], Feedback.lines[index]
            edge.From, edge.To, edge.Transparency, edge.Visible = from, to, 1 - progress, true
            line.From, line.To, line.Color, line.Transparency, line.Visible = from, to, color, 1 - progress, true
        end
    end

    local life, rise, size = flag("dmg_time", 1.1), flag("dmg_rise", 60), flag("dmg_size", 16)
    local used = 0
    for index = #Feedback.numbers, 1, -1 do
        local number = Feedback.numbers[index]
        local t = (now - number.born) / life
        if t >= 1 then
            table.remove(Feedback.numbers, index)
        else
            local point, front = Draw.project(cam, number.pos)
            if front then
                used = used + 1
                local text = Feedback.texts[used]
                if not text then
                    text = Draw.text(16, 9)
                    Feedback.texts[used] = text
                end
                local ease = 1 - (1 - math.min(t * 1.6, 1)) ^ 3
                text.Text = number.text
                text.Size = number.big and size * 1.5 or size
                text.Position = Vector2.new(point.X + number.dx * ease, point.Y - rise * ease)
                text.Color, text.Transparency, text.Visible = number.color, t > 0.6 and (1 - (t - 0.6) / 0.4) or 1, true
            end
        end
    end
    for index = used + 1, #Feedback.texts do Feedback.texts[index].Visible = false end
end

local Legit = { target = nil, record = nil, part = nil, switchAt = 0, reactUntil = 0, moved = false, radius = 0, zoom = 1, L = {}, pressAt = -1e9, snapTime = 0.12, last = {} }
local GROUPS = { Head = { "Head" }, Torso = { "Torso" }, Arms = { "Left Arm", "Right Arm" }, Legs = { "Left Leg", "Right Leg" } }
local GROUP_ORDER = { "Head", "Torso", "Arms", "Legs" }

Legit.circle = Draw.new("Circle", { Thickness = 1, NumSides = 64, Filled = false, Visible = false, ZIndex = 5 })
Legit.circleFill = Draw.new("Circle", { NumSides = 64, Filled = true, Visible = false, ZIndex = 4 })
Legit.snapline = Draw.new("Line", { Thickness = 1, Visible = false, ZIndex = 6 })

local INSET = 0.8
local POINT_OFFSETS = {
    Head = { { 0, 0, 0 }, { 1, 0, 0 }, { -1, 0, 0 }, { 0, 1, 0 }, { 0, -1, 0 }, { 0, 0, 1 }, { 0, 0, -1 } },
    Torso = { { 0, 0, 0 }, { 1, 1, 0 }, { -1, 1, 0 }, { 1, -1, 0 }, { -1, -1, 0 }, { 0, 1, 0 }, { 0, -1, 0 }, { 1, 0, 0 }, { -1, 0, 0 } },
    Limb = { { 0, 0, 0 }, { 0, 1, 0 }, { 0, -1, 0 } },
}
local PURPLE = Color3.fromRGB(170, 80, 255)

local Aim = { opts = {} }
local Silent = { tickets = {}, rollAt = -1, pass = true, opts = {}, dots = {}, radius = 0, zoom = 1 }

function Aim.depth(weapon, safety)
    local depth = Game.stat(weapon, "penetrationdepth")
    if type(depth) == "number" and depth > 0 then return depth * safety end
    return nil
end

function Aim.velocity(record)
    return record.vel or record.velocity
end

function Aim.intercept(origin, position, velocity, speed, weapon)
    local bulletAccel = Game.stat(weapon, "bulletaccel")
    if type(bulletAccel) ~= "number" then bulletAccel = 0 end
    local time = (position - origin).Magnitude / speed
    local hit, aim, direction = position, position, nil
    for _ = 1, 8 do
        hit = position + velocity * time
        local accel = Game.accel
        if direction and bulletAccel ~= 0 then accel = accel + direction * bulletAccel end
        aim = hit - accel * (0.5 * time * time)
        local vector = aim - origin
        local length = vector.Magnitude
        if length < 1e-3 then break end
        direction = vector / length
        time = length / speed
    end
    return hit, aim, time
end

function Aim.rotate(vector, from, to)
    local axis = from:Cross(to)
    local sin, cos = axis.Magnitude, from:Dot(to)
    if sin < 1e-6 then return cos > 0 and vector or to end
    local k = axis / sin
    return (vector * cos + k:Cross(vector) * sin + k * (k:Dot(vector) * (1 - cos))).Unit
end

function Aim.offsets(name)
    if name == "Head" or name == "Torso" then return POINT_OFFSETS[name] end
    return POINT_OFFSETS.Limb
end

function Aim.gather(record, cam, center, radius, opts)
    if radius then
        local point, front, depth = Draw.project(cam, record.torso.Position)
        if not front then return nil end
        local pixels = (cam.ViewportSize.Y / 2) / math.tan(math.rad(cam.FieldOfView) / 2)
        if (point - center).Magnitude > radius + 4 * pixels / math.max(depth, 1) then return nil end
    end
    local list = {}
    local count = opts.multi and opts.max or 1
    for _, group in ipairs(GROUP_ORDER) do
        if opts.parts[group] then
            local penalty = (opts.choice ~= "Closest" and group ~= opts.choice) and 1e5 or 0
            for _, name in ipairs(GROUPS[group]) do
                local part = record.hash[name]
                if part and part.Parent then
                    local offsets = Aim.offsets(name)
                    local half = PART_SIZES[name] * (0.5 * (opts.scale or 1) * INSET)
                    for index = 1, math.min(count, #offsets) do
                        local offset = offsets[index]
                        local position = part.Position
                        if index > 1 then
                            position = part.CFrame:PointToWorldSpace(Vector3.new(offset[1] * half.X, offset[2] * half.Y, offset[3] * half.Z))
                        end
                        local point, front = Draw.project(cam, position)
                        local screen = front and (point - center).Magnitude or 1e5
                        if (radius == nil and front) or screen <= (radius or 0) then
                            list[#list + 1] = { pos = position, screen = screen, group = group, part = part, key = screen + penalty + index * 0.001 }
                        end
                    end
                end
            end
        end
    end
    return list
end

local function byKey(a, b) return a.key < b.key end

function Aim.select(record, cam, origin, center, radius, opts)
    local list = Aim.gather(record, cam, center, radius, opts)
    if not list or #list == 0 then return nil end
    table.sort(list, byKey)
    local fallback
    for _, cand in ipairs(list) do
        if not opts.visible then
            cand.mode = "open"
            return cand
        end
        if Visible.budget <= 0 then break end
        Visible.budget = Visible.budget - 1
        local thickness, walls = Visible.trace(origin, cand.pos, opts.depth)
        if thickness then
            cand.thickness = thickness
            if walls == 0 then
                cand.mode = "visible"
                return cand
            end
            if not fallback then
                cand.mode = "pen"
                fallback = cand
            end
        end
    end
    return fallback
end

function Silent.acquire(origin, weapon)
    local cam = Game.camera()
    if not cam then return nil end
    local temporary = Stretch.base == nil
    if temporary then Stretch.apply(cam) end
    local ok, record, cand = pcall(Silent.select, cam, origin, weapon)
    if temporary then Stretch.restore(cam) end
    if not ok then Util.note("silentacq", "acquire:", record); return nil end
    return record, cand
end

function Silent.select(cam, origin, weapon)
    local L = Legit.L
    Visible.budget = 48
    local opts = Silent.opts
    opts.visible, opts.parts, opts.choice = L.silentVisible, L.silentParts, L.silentChoice
    opts.multi, opts.scale, opts.max = L.silentMulti, L.silentMultiScale, L.silentMultiMax
    opts.depth = L.silentWallbang and Aim.depth(weapon, L.silentSafety) or nil
    local center = Silent.fovCenter(cam.ViewportSize / 2)
    local bestRecord, bestCand
    for _, record in ipairs(Entities.list) do
        if record.rendered and (record.enemy or not L.silentTeam) and (record.torso.Position - origin).Magnitude <= L.silentDist then
            local cand = Aim.select(record, cam, origin, center, Silent.radius, opts)
            if cand and (not bestCand or cand.screen < bestCand.screen) then bestRecord, bestCand = record, cand end
        end
    end
    return bestRecord, bestCand
end

function Silent.rewrite(info)
    local L = Legit.L
    local extra = type(info) == "table" and info.extra
    if type(extra) ~= "table" or extra.firearmObject == nil or extra.bulletTicket == nil then return end
    if not (L.silent and Game.ready) or Util.menuOpen() then return end
    local velocity, origin = info.velocity, info.position
    if typeof(velocity) ~= "Vector3" or typeof(origin) ~= "Vector3" then return end
    local now = os.clock()
    if now - Silent.rollAt > 0.05 then
        Silent.rollAt = now
        Silent.pass = math.random() * 100 < L.silentChance
    end
    if not Silent.pass then return end
    local speed = velocity.Magnitude
    if speed < 1 then return end
    local weapon = extra.firearmObject
    local record, cand = Silent.acquire(origin, weapon)
    if not record then return end
    Silent.shot = { record = record, cand = cand, at = now }
    local aim, time = cand.pos, (cand.pos - origin).Magnitude / speed
    if L.silentPred then
        local _
        _, aim, time = Aim.intercept(origin, cand.pos, Aim.velocity(record), speed, weapon)
    end
    local settings = Game.mods.PublicSettings
    if time > (settings and settings.bulletLifeTime or 2) then return end
    local vector = aim - origin
    if vector.Magnitude < 0.01 then return end
    local direction, old = vector.Unit, velocity / speed
    local reference
    local okFrame, frame = pcall(weapon.getBarrelCFrame, weapon)
    if okFrame and typeof(frame) == "CFrame" then reference = frame.LookVector end
    if reference and (old - reference).Magnitude < 0.6 then direction = Aim.rotate(old, reference, direction) end
    info.velocity = direction * speed
    local bulletAccel = Game.stat(weapon, "bulletaccel")
    if type(bulletAccel) == "number" and bulletAccel ~= 0 and typeof(info.acceleration) == "Vector3" then
        info.acceleration = info.acceleration + (direction - old) * bulletAccel
    end
    Silent.tickets[extra.bulletTicket] = { dir = direction, at = now }
end

function Silent.patch(packet)
    local tickets = Silent.tickets
    if next(tickets) == nil or type(packet) ~= "table" or type(packet.bullets) ~= "table" then return end
    for _, bullet in ipairs(packet.bullets) do
        local entry = tickets[bullet[2]]
        if entry then
            bullet[1] = entry.dir
            tickets[bullet[2]] = nil
        end
    end
    local now = os.clock()
    for ticket, entry in pairs(tickets) do
        if now - entry.at > 5 then tickets[ticket] = nil end
    end
end
Game.onNewBullets = Silent.patch

function Silent.hook()
    if Silent.hooked or not Game.mods.BulletInterface then return end
    Silent.hooked = Util.hook(Game.mods.BulletInterface, "newBullet", function(original)
        return function(info, ...)
            if Legit.L.silent then pcall(Silent.rewrite, info) end
            return original(info, ...)
        end
    end)
end

Silent.ring = Draw.new("Circle", { Thickness = 1, NumSides = 64, Filled = false, Visible = false, ZIndex = 5 })
Silent.ringFill = Draw.new("Circle", { NumSides = 64, Filled = true, Visible = false, ZIndex = 4 })

function Silent.fovCenter(screen)
    local L = Legit.L
    return L.silentFovBarrel and Barrel.point(L.silentFovAttach, screen) or screen
end

function Silent.step(dt, cam, weapon, screen)
    local L = Legit.L
    if L.silent then Silent.hook() end
    local center = Silent.fovCenter(screen)
    Legit.scaleRadius(Silent, dt, weapon, cam, L.silentFov, L.silentFovDynamic, L.silentFovZoom, L.silentFovSpeed)
    local shot = Silent.shot
    local locked = shot and os.clock() - shot.at < 0.35
    Legit.paintFov(Silent.ring, Silent.ringFill, center, Silent.radius, L.silent and L.silentFovDraw, locked, "legit_silent_fov", Color3.fromRGB(255, 200, 80))
    local shown = 0
    if L.silent and L.silentShowPoints and shot and os.clock() - shot.at < 1.5 and shot.record.rendered then
        for _, point in ipairs(Aim.gather(shot.record, cam, center, nil, Silent.opts) or {}) do
            if shown >= 27 then break end
            shown = shown + 1
            local dot = Silent.dots[shown]
            if not dot then
                dot = Draw.new("Circle", { NumSides = 10, Radius = 2, Filled = true, ZIndex = 23, Visible = false })
                Silent.dots[shown] = dot
            end
            dot.Position = Draw.project(cam, point.pos)
            dot.Color = point.pos == shot.cand.pos and L.silentPointColor or WHITE
            dot.Visible = true
        end
    end
    for index = shown + 1, #Silent.dots do Silent.dots[index].Visible = false end
end

function Legit.read()
    local L = Legit.L
    L.aim = flag("legit_aim", false)
    L.visible, L.ads, L.shooting = flag("legit_visible", true), flag("legit_ads", false), flag("legit_shooting", false)
    L.smooth, L.speed = flag("legit_smooth", 12), flag("legit_speed", 420)
    L.maxdist, L.deadzone = flag("legit_dist", 600), flag("legit_deadzone", 2)
    L.parts = Util.set("legit_parts", { Head = true, Torso = true })
    L.choice, L.targetBy = flag("legit_priority", "Closest"), flag("legit_target_by", "Crosshair")
    L.sticky, L.switch, L.react = flag("legit_sticky", true), flag("legit_switch", 120), flag("legit_react", 60)
    L.drop, L.move = flag("legit_drop", true), flag("legit_move", true)
    L.strength, L.maxLead = flag("legit_strength", 1), flag("legit_maxlead", 14)
    L.noise, L.noiseSpeed = flag("legit_noise", 0.25), flag("legit_noise_speed", 1.4)
    L.fovRadius, L.fovDynamic = flag("legit_fov", 120), flag("legit_fov_dynamic", false)
    L.fovZoom, L.fovSpeed = flag("legit_fov_zoom", 1), flag("legit_fov_speed", 10)
    L.teamCheck = flag("legit_team_check", true)
    L.barrel = flag("legit_barrel", true)
    L.fovBarrel, L.fovAttach = flag("legit_fov_barrel", false), flag("legit_fov_attach", "Aim hit")
    L.multi, L.multiScale, L.multiMax = flag("legit_multi", false), flag("legit_multi_scale", 60) / 100, math.floor(flag("legit_multi_max", 5))
    L.showPoints, L.pointColor = flag("legit_multi_show", false), flag("legit_multi_color", Color3.fromRGB(120, 255, 170))
    L.wallbang, L.safety = flag("legit_wallbang", false), flag("legit_pen_safety", 90) / 100
    L.pred, L.predShow, L.predAim, L.predAll = flag("legit_pred", false), flag("legit_pred_show", true), flag("legit_pred_aim", false), flag("legit_pred_all", false)
    L.predColor, L.predOutline = flag("legit_pred_color", Color3.fromRGB(255, 40, 40)), flag("legit_pred_outline", true)
    L.silent, L.silentFov, L.silentChance = flag("legit_silent", false), flag("legit_silent_fov", 90), flag("legit_silent_chance", 100)
    L.silentVisible = flag("legit_silent_visible", true)
    L.silentParts = Util.set("legit_silent_parts", { Head = true, Torso = true })
    L.silentChoice = flag("legit_silent_priority", "Closest")
    L.silentTeam, L.silentDist = flag("legit_silent_team", true), flag("legit_silent_dist", 600)
    L.silentMulti, L.silentMultiScale, L.silentMultiMax = flag("legit_silent_multi", false), flag("legit_silent_multi_scale", 60) / 100, math.floor(flag("legit_silent_multi_max", 5))
    L.silentShowPoints, L.silentPointColor = flag("legit_silent_multi_show", false), flag("legit_silent_multi_color", Color3.fromRGB(120, 255, 170))
    L.silentWallbang, L.silentSafety = flag("legit_silent_wallbang", false), flag("legit_silent_pen_safety", 90) / 100
    L.silentPred = flag("legit_silent_pred", false)
    L.silentFovDraw, L.silentFovBarrel, L.silentFovAttach = flag("legit_silent_fov_draw", true), flag("legit_silent_fov_barrel", false), flag("legit_silent_fov_attach", "Aim hit")
    L.silentFovDynamic, L.silentFovZoom, L.silentFovSpeed = flag("legit_silent_fov_dynamic", false), flag("legit_silent_fov_zoom", 1), flag("legit_silent_fov_speed", 10)
    local opts = Aim.opts
    opts.visible, opts.parts, opts.choice = L.visible, L.parts, L.choice
    opts.multi, opts.scale, opts.max = L.multi, L.multiScale, L.multiMax

    L.semi = false
    if flag("legit_semi", false) and Util.keyActive("legit_semi_key") and not Util.menuOpen() and not Util.typing() then
        local weapon = Game.weapon()
        if weapon and Game.isFirearm(weapon) and Game.fireMode(weapon) == "semi" then
            L.semi = true
            L.smooth, L.fovRadius = flag("legit_semi_smooth", 6), flag("legit_semi_fov", 90)
            L.parts, L.choice = Util.set("legit_semi_parts", { Head = true }), flag("legit_semi_priority", "Head")
            L.onfire = flag("legit_semi_onfire", false)
            opts.parts, opts.choice = L.parts, L.choice
        end
    end
end

function Legit.scaleRadius(state, dt, weapon, cam, radius, dynamic, scale, speed)
    local ratio = 1
    if dynamic and weapon then
        ratio = Game.zoom(weapon) or Game.cameraZoom()
        if ratio <= 1.001 and Game.aiming(weapon) then
            local gameCam = Game.gameCamera()
            local base = gameCam and gameCam._baseFov
            if type(base) == "number" and cam.FieldOfView > 1 then ratio = math.max(base / cam.FieldOfView, 1) end
        end
    end
    state.zoom = state.zoom + (ratio - state.zoom) * (1 - math.exp(-dt * speed))
    if dynamic then
        local limit = math.max(radius, cam.ViewportSize.Y * 0.5)
        radius = math.min(radius * math.min(state.zoom ^ scale, 4), limit)
    end
    state.radius = radius
end

function Legit.stepRadius(dt, weapon, cam)
    local L = Legit.L
    Legit.scaleRadius(Legit, dt, weapon, cam, L.fovRadius, L.fovDynamic, L.fovZoom, L.fovSpeed)
end

function Legit.lead(origin, position, velocity, weapon)
    local L = Legit.L
    local speed = Game.stat(weapon, "bulletspeed")
    if type(speed) ~= "number" or speed <= 1 then return position end
    local time = (position - origin).Magnitude / speed
    local aim = position
    for _ = 1, 3 do
        local move = Vector3.zero
        if L.move then
            move = velocity * time * L.strength
            if move.Magnitude > L.maxLead then move = move.Unit * L.maxLead end
        end
        local drop = Vector3.zero
        if L.drop then drop = -0.5 * Game.accel * time * time * L.strength end
        aim = position + move + drop
        time = (aim - origin).Magnitude / speed
    end
    return aim
end

function Legit.choose(records, cam, origin, center, now)
    local L = Legit.L
    local bestRecord, bestCand, bestScore
    for _, record in ipairs(records) do
        if record.rendered and (record.enemy or not L.teamCheck) then
            local distance = (record.torso.Position - origin).Magnitude
            if distance <= L.maxdist then
                local cand = Aim.select(record, cam, origin, center, Legit.radius, Aim.opts)
                if cand then
                    local score = cand.screen
                    if L.targetBy == "Distance" then score = distance
                    elseif L.targetBy == "Lowest health" then score = record.health * 1000 + cand.screen end
                    if not bestScore or score < bestScore then bestRecord, bestCand, bestScore = record, cand, score end
                end
            end
        end
    end
    return bestRecord, bestCand
end

function Legit.turn(gameCam, origin, aimPoint, dt, now, cam, barrelLook, instant)
    local L = Legit.L
    local direction = aimPoint - origin
    if direction.Magnitude < 0.01 then return false end
    direction = direction.Unit

    local targetPitch = math.atan2(direction.Y, math.sqrt(direction.X * direction.X + direction.Z * direction.Z))
    local targetYaw = math.atan2(-direction.X, -direction.Z)
    if L.noise > 0 then
        targetPitch = targetPitch + math.rad(L.noise) * math.noise(now * L.noiseSpeed, 11.3) * 2
        targetYaw = targetYaw + math.rad(L.noise) * math.noise(now * L.noiseSpeed, 47.9) * 2
    end

    local look = barrelLook or gameCam:getLookVector()
    if typeof(look) ~= "Vector3" then return false end
    local currentPitch = math.atan2(look.Y, math.sqrt(look.X * look.X + look.Z * look.Z))
    local currentYaw = math.atan2(-look.X, -look.Z)
    local deltaPitch = targetPitch - currentPitch
    local deltaYaw = (targetYaw - currentYaw + math.pi) % (math.pi * 2) - math.pi

    local pixels = (cam.ViewportSize.Y / 2) / math.tan(math.rad(cam.FieldOfView) / 2)
    if math.sqrt(deltaPitch * deltaPitch + deltaYaw * deltaYaw) * pixels < L.deadzone then return false end

    local alpha = instant and 1 or 1 - math.exp(-dt * 60 / math.max(L.smooth, 1))
    local stepPitch, stepYaw = deltaPitch * alpha, deltaYaw * alpha
    local cap = math.rad(L.speed) * dt
    local size = math.sqrt(stepPitch * stepPitch + stepYaw * stepYaw)
    if not instant and size > cap and size > 0 then
        stepPitch, stepYaw = stepPitch * cap / size, stepYaw * cap / size
    end

    local base = gameCam:getAngles()
    if typeof(base) ~= "Vector3" then return false end
    local pitch, yaw = base.X + stepPitch, base.Y + stepYaw
    local cosPitch = math.cos(pitch)
    gameCam:setLookVector(Vector3.new(-cosPitch * math.sin(yaw), math.sin(pitch), -cosPitch * math.cos(yaw)))
    return true
end

function Legit.paintFov(circle, fill, center, radius, show, locked, prefix, base)
    circle.Visible = show
    if not show then
        fill.Visible = false
        return
    end
    local color = flag(prefix .. "_color", base)
    if locked and flag(prefix .. "_lock", true) then color = flag(prefix .. "_lock_color", color) end
    circle.Position, circle.Radius, circle.Color = center, radius, color
    circle.Thickness = flag(prefix .. "_thick", 1)
    local filled = flag(prefix .. "_fill", false)
    fill.Visible = filled
    if filled then
        fill.Position, fill.Radius = center, radius
        fill.Color = flag(prefix .. "_fill_color", base)
        fill.Transparency = 1 - Util.alpha(prefix .. "_fill_color", 0.9)
    end
end

function Legit.drawFov(center)
    local L = Legit.L
    Legit.paintFov(Legit.circle, Legit.circleFill, center, Legit.radius, flag("legit_fov_draw", true) and (L.aim or L.semi), Legit.target, "legit_fov", WHITE)
end

Legit.slots, Legit.dots = {}, {}

function Legit.slot(index)
    local slot = Legit.slots[index]
    if slot then return slot end
    slot = {
        outline = Draw.new("Circle", { NumSides = 24, Filled = true, Color = BLACK, ZIndex = 20, Visible = false }),
        dot = Draw.new("Circle", { NumSides = 24, Filled = true, ZIndex = 21, Visible = false }),
        aim = Draw.new("Circle", { NumSides = 16, Filled = true, Color = PURPLE, ZIndex = 22, Visible = false }),
        label = Draw.text(13, 22),
        brackets = {},
    }
    for corner = 1, 8 do
        slot.brackets[corner] = Draw.new("Line", { Thickness = 1.5, Color = PURPLE, ZIndex = 22, Visible = false })
    end
    Legit.slots[index] = slot
    return slot
end

function Legit.hideSlot(slot)
    slot.outline.Visible, slot.dot.Visible, slot.aim.Visible, slot.label.Visible = false, false, false, false
    for _, line in ipairs(slot.brackets) do line.Visible = false end
end

function Legit.drawSlot(slot, cam, record, cand, speed, weapon)
    local L = Legit.L
    local hit = Aim.intercept(Legit.origin, cand.pos, Aim.velocity(record), speed, weapon)
    local point, front = Draw.project(cam, hit)
    if not front then
        Legit.hideSlot(slot)
        return
    end
    slot.outline.Position, slot.outline.Radius, slot.outline.Visible = point, 7.5, L.predOutline
    slot.dot.Position, slot.dot.Radius, slot.dot.Color, slot.dot.Visible = point, 6, L.predColor, true
    local aimPoint, aimFront = Draw.project(cam, cand.pos)
    slot.aim.Position, slot.aim.Radius, slot.aim.Visible = aimPoint, 2.5, aimFront

    local head = record.hash.Head
    local headPoint, headFront = nil, false
    if head and head.Parent then headPoint, headFront = Draw.project(cam, head.Position) end
    for _, line in ipairs(slot.brackets) do line.Visible = headFront end
    slot.label.Visible = headFront
    if not headFront then return end
    local top = Draw.project(cam, head.Position + Stretch.cf(cam).UpVector * 0.9)
    local half = math.max((top - headPoint).Magnitude, 8)
    local arm = half * 0.45
    local index = 0
    for _, sx in ipairs({ -1, 1 }) do
        for _, sy in ipairs({ -1, 1 }) do
            local corner = headPoint + Vector2.new(sx * half, sy * half)
            local horizontal, vertical = slot.brackets[index * 2 + 1], slot.brackets[index * 2 + 2]
            horizontal.From, horizontal.To = corner, corner - Vector2.new(sx * arm, 0)
            vertical.From, vertical.To = corner, corner - Vector2.new(0, sy * arm)
            index = index + 1
        end
    end
    slot.label.Text, slot.label.Color = record.name, WHITE
    slot.label.Position = Vector2.new(headPoint.X, headPoint.Y - half - 16)
end

function Legit.stepPredict(cam, center, records)
    local L = Legit.L
    local used = 0
    local weapon = Game.weapon()
    local speed = weapon and Game.stat(weapon, "bulletspeed")
    if L.pred and L.predShow and type(speed) == "number" and speed > 1 and Legit.origin then
        local origin = Legit.origin
        if L.predAll then
            Visible.budget = math.max(Visible.budget, 16)
            for _, record in ipairs(records) do
                if used >= 8 then break end
                if record.rendered and (record.enemy or not L.teamCheck) and (record.torso.Position - origin).Magnitude <= L.maxdist then
                    local cand = Aim.select(record, cam, origin, center, Legit.radius, Aim.opts)
                    if cand then
                        used = used + 1
                        Legit.drawSlot(Legit.slot(used), cam, record, cand, speed, weapon)
                    end
                end
            end
        else
            local record, cand = Legit.record, Legit.cand
            if not cand then record, cand = Legit.choose(records, cam, origin, center, os.clock()) end
            if record and cand then
                used = 1
                Legit.drawSlot(Legit.slot(1), cam, record, cand, speed, weapon)
            end
        end
    end
    for index = used + 1, #Legit.slots do Legit.hideSlot(Legit.slots[index]) end
end

function Legit.stepPoints(cam, center)
    local L = Legit.L
    local shown = 0
    if L.showPoints and Legit.cand and Legit.record then
        local list = Aim.gather(Legit.record, cam, center, nil, Aim.opts) or {}
        for _, cand in ipairs(list) do
            if shown >= 27 then break end
            shown = shown + 1
            local dot = Legit.dots[shown]
            if not dot then
                dot = Draw.new("Circle", { NumSides = 10, Radius = 2, Filled = true, ZIndex = 23, Visible = false })
                Legit.dots[shown] = dot
            end
            dot.Position = Draw.project(cam, cand.pos)
            dot.Color = cand.pos == Legit.cand.pos and L.pointColor or WHITE
            dot.Visible = true
        end
    end
    for index = shown + 1, #Legit.dots do Legit.dots[index].Visible = false end
end

function Legit.runAim(dt, cam, now, records, center, weapon, origin, useBarrel)
    local L = Legit.L
    local active = L.semi or (L.aim and Util.keyActive("legit_aim_key") and not Util.menuOpen() and not Util.typing())
    if not (active and weapon and Game.isFirearm(weapon)) then Legit.target = nil return end
    if L.ads and not Game.aiming(weapon) then Legit.target = nil return end
    local snap = L.semi and L.onfire
    if snap then
        if now - Legit.pressAt > Legit.snapTime then Legit.target = nil return end
        if Legit.snapDone then return end
    elseif L.shooting and not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
        Legit.target = nil
        return
    end

    local gameCam = Game.gameCamera()
    if not gameCam then return end

    local record, cand
    if Legit.target and L.sticky then
        local held = Entities.byPlayer[Legit.target]
        if held and held.seen and held.rendered and (held.enemy or not L.teamCheck) then
            record = held
            cand = Aim.select(held, cam, origin, center, nil, Aim.opts)
            Legit.record = held
            if not cand then return end
        else
            Legit.target = nil
        end
    end
    if not record then
        record, cand = Legit.choose(records, cam, origin, center, now)
        if not record then Legit.target = nil return end
    end

    if Legit.target ~= record.player then
        if Legit.target and now - Legit.switchAt < L.switch / 1000 then return end
        Legit.target = record.player
        Legit.switchAt = now
        Legit.reactUntil = now + L.react / 1000
    end
    Legit.part, Legit.record, Legit.cand = cand.part, record, cand

    if flag("legit_snapline", false) then
        local point, front = Draw.project(cam, cand.pos)
        if front then
            Legit.snapline.From, Legit.snapline.To = center, point
            Legit.snapline.Color = flag("legit_snapline_color", WHITE)
            Legit.snapline.Visible = true
        end
    end
    if now < Legit.reactUntil and not snap then return end
    local aimPoint
    local speed = Game.stat(weapon, "bulletspeed")
    if L.pred and L.predAim and type(speed) == "number" and speed > 1 then
        local _, compensated = Aim.intercept(origin, cand.pos, Aim.velocity(record), speed, weapon)
        aimPoint = compensated
    end
    aimPoint = aimPoint or Legit.lead(origin, cand.pos, Aim.velocity(record), weapon)
    if snap then Legit.snapDone = true end
    Legit.moved = Legit.turn(gameCam, origin, aimPoint, dt, now, cam, useBarrel and Barrel.look or nil, snap)
end

function Legit.onPress()
    if Util.menuOpen() or Util.typing() then return end
    local L, last = Legit.L, Legit.last
    Legit.pressAt, Legit.snapDone = os.clock(), false
    if not (L.semi and L.onfire and last.cam) then return end
    Legit.target = nil
    Legit.runAim(0, last.cam, Legit.pressAt, last.records, last.center, last.weapon, last.origin, last.useBarrel)
end

Util.track(UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then Util.guard("snap", Legit.onPress) end
end))

function Legit.stepAim(dt, cam, now, records, screen)
    local L = Legit.L
    Legit.moved, Legit.cand = false, nil
    local center = L.fovBarrel and Barrel.point(L.fovAttach, screen) or screen
    local weapon = Game.weapon()
    Legit.stepRadius(dt, weapon, cam)
    Legit.drawFov(center)
    Legit.snapline.Visible = false
    Silent.step(dt, cam, weapon, screen)
    Aim.opts.depth = L.wallbang and weapon and Aim.depth(weapon, L.safety) or nil
    local useBarrel = L.barrel and Barrel.valid
    local origin = useBarrel and Barrel.fire or Game.eye(cam).Position
    Legit.origin = origin
    local last = Legit.last
    last.cam, last.records, last.center, last.weapon, last.origin, last.useBarrel = cam, records, center, weapon, origin, useBarrel
    Legit.runAim(dt, cam, now, records, center, weapon, origin, useBarrel)
    Legit.stepPredict(cam, center, records)
    Legit.stepPoints(cam, center)
end

local Recoil = { key = nil, last = Vector3.zero, shown = Vector3.zero }

function Legit.stepRecoil(now)
    local gameCam = Game.gameCamera()
    if not gameCam then return end
    local offset = Vector3.zero
    local body, head = gameCam._cameraBodySprings, gameCam._cameraHeadSprings
    local useBarrel = flag("rcs_barrel", true) and Barrel.valid and Barrel.offset ~= nil
    local key1, key2
    if useBarrel then
        offset, key1, key2 = Barrel.offset, Barrel.weapon, Barrel.aiming
    else
        pcall(function()
            if body then offset = offset + body:getP() end
            if head then offset = offset + head:getP() end
        end)
        key1, key2 = body, head
    end
    Recoil.shown = offset
    local delta = offset - Recoil.last
    Recoil.last = offset
    local reset = Recoil.barrel ~= useBarrel or Recoil.key1 ~= key1 or Recoil.key2 ~= key2 or delta.Magnitude > math.rad(20)
    Recoil.barrel, Recoil.key1, Recoil.key2 = useBarrel, key1, key2
    if reset then return end

    if not (flag("rcs_on", false) and Util.keyActive("rcs_key")) or Util.menuOpen() or Legit.moved then return end
    local weapon = Game.weapon()
    if not (weapon and Game.isFirearm(weapon)) then return end
    if not flag("rcs_hip", true) and not Game.aiming(weapon) then return end

    local vertical, horizontal = flag("rcs_v", 70) / 100, flag("rcs_h", 40) / 100
    local variation = flag("rcs_human", 10) / 100
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

local Trigger = { onSince = nil, releaseAt = 0, nextAt = 0, down = false }

function Trigger.release()
    if Trigger.down then
        Trigger.down = false
        pcall(function() if mouse1release then mouse1release() end end)
    end
end
Util.onUnload(Trigger.release)

function Legit.rayBox(origin, direction, cframe, size, maxDistance)
    local o, d = cframe:PointToObjectSpace(origin), cframe:VectorToObjectSpace(direction)
    local tmin, tmax = 0, maxDistance
    for _, axis in ipairs({ "X", "Y", "Z" }) do
        local oa, da, ha = o[axis], d[axis], size[axis] * 0.5
        if math.abs(da) < 1e-6 then
            if math.abs(oa) > ha then return false end
        else
            local t1, t2 = (-ha - oa) / da, (ha - oa) / da
            if t1 > t2 then t1, t2 = t2, t1 end
            if t1 > tmin then tmin = t1 end
            if t2 < tmax then tmax = t2 end
            if tmin > tmax then return false end
        end
    end
    return true
end

function Legit.stepTrigger(cam, now, records)
    if Trigger.down and now >= Trigger.releaseAt then
        Trigger.release()
        Trigger.nextAt = now + flag("trig_cool", 90) / 1000
    end
    local active = flag("trig_on", false) and Util.keyActive("trig_key") and not Util.menuOpen() and not Util.typing()
    if not active or type(mouse1press) ~= "function" then
        Trigger.onSince = nil
        if not active then Trigger.release() end
        return
    end
    local weapon = Game.weapon()
    if not (weapon and Game.isFirearm(weapon)) then Trigger.onSince = nil return end
    if flag("trig_ads", false) and not Game.aiming(weapon) then Trigger.onSince = nil return end

    local eye = Game.eye(cam)
    local origin, direction = eye.Position, eye.LookVector
    if flag("legit_barrel", true) and Barrel.valid then origin, direction = Barrel.fire, Barrel.look end
    local maxDistance, scale = flag("trig_dist", 400), flag("trig_scale", 1)
    local groups, wantVisible = Util.set("trig_parts", { Head = true, Torso = true }), flag("trig_visible", true)
    local teamCheck = flag("legit_team_check", true)

    local onTarget = false
    for _, record in ipairs(records) do
        if record.rendered and (record.enemy or not teamCheck) then
            for groupName in pairs(groups) do
                for _, partName in ipairs(GROUPS[groupName] or {}) do
                    local part = record.hash[partName]
                    if part and part.Parent and PART_SIZES[partName]
                        and Legit.rayBox(origin, direction, part.CFrame, PART_SIZES[partName] * scale, maxDistance)
                        and (not wantVisible or Visible.check(part, origin, now)) then
                        onTarget = true
                    end
                end
            end
        end
        if onTarget then break end
    end

    if not onTarget then Trigger.onSince = nil return end
    Trigger.onSince = Trigger.onSince or now
    if Trigger.down or now < Trigger.nextAt then return end
    if now - Trigger.onSince < flag("trig_delay", 40) / 1000 then return end
    if not Game.canFire(weapon) then return end
    Trigger.down = true
    Trigger.releaseAt = now + flag("trig_hold", 70) / 1000
    pcall(mouse1press)
end

local Knife = { classes = { "ONE HAND BLADE", "TWO HAND BLADE", "ONE HAND BLUNT", "TWO HAND BLUNT" } }

function Knife.list()
    local content = Game.mods.ContentInterface
    if not (content and type(content.getWeaponListFromClass) == "function") then return {} end
    local seen, names = {}, {}
    for _, class in ipairs(Knife.classes) do
        local ok, list = pcall(content.getWeaponListFromClass, class)
        if ok and type(list) == "table" then
            for _, name in ipairs(list) do
                if type(name) == "string" and not seen[name] then
                    seen[name] = true
                    names[#names + 1] = name
                end
            end
        end
    end
    table.sort(names)
    if #names > 0 then Knife.set = seen end
    return names
end

function Knife.isKnife(name)
    if not Knife.set then Knife.list() end
    return Knife.set ~= nil and Knife.set[name] == true
end

function Knife.valid(name)
    local content = Game.mods.ContentInterface
    if not (content and type(name) == "string") then return false end
    local okModel, model = pcall(content.getWeaponModel, name)
    local okData, data = pcall(content.getWeaponData, name)
    return okModel and typeof(model) == "Instance" and okData and type(data) == "table"
end

function Knife.skinNames()
    local names = {}
    local ok, database = pcall(function()
        local storage = game:GetService("ReplicatedStorage")
        local content = storage:FindFirstChild("Content")
        local production = content and content:FindFirstChild("ProductionContent")
        local module = production and production:FindFirstChild("CamoDatabase")
        return module and require(module)
    end)
    if ok and type(database) == "table" then
        for name in pairs(database) do
            if type(name) == "string" then names[#names + 1] = name end
        end
    end
    table.sort(names)
    return names
end

function Knife.items()
    local items = { "Default" }
    for _, name in ipairs(Knife.list()) do items[#items + 1] = name end
    return items
end

function Knife.skinItems()
    local items = { "Default", "None" }
    for _, name in ipairs(Knife.skinNames()) do items[#items + 1] = name end
    return items
end

function Knife.camo(name, skin)
    if skin == "None" then return {} end
    local sets = Game.mods.SkinCaseUtils
    if sets and type(sets.getSkinDataset) == "function" then
        local ok, data = pcall(sets.getSkinDataset, skin)
        if not (ok and type(data) == "table") then return nil end
    end
    local content = Game.mods.ContentInterface
    local okSlots, slots = pcall(content.getCamoSlots, name)
    if not (okSlots and type(slots) == "table") then return nil end
    local camo = {}
    for _, tag in pairs(slots) do camo[tag] = { Name = skin } end
    return camo
end

function Knife.ownLoadout(loadout)
    local utils, data = Game.mods.ActiveLoadoutUtils, Game.mods.PlayerDataClientInterface
    if not (utils and data) then return true end
    local ok, current = pcall(function() return utils.getActiveLoadoutData(data.getPlayerData()) end)
    return not ok or current == loadout
end

function Knife.swap(loadout)
    if not flag("misc_knife_on", false) or type(loadout) ~= "table" then return nil end
    local choice, skin = flag("misc_knife", "Default"), flag("misc_knife_skin", "Default")
    if choice == "Default" and skin == "Default" then return nil end
    if not Knife.ownLoadout(loadout) then return nil end
    local real = type(loadout.Knife) == "table" and loadout.Knife or nil
    local name = choice ~= "Default" and choice or (real and real.Name)
    if not Knife.valid(name) then return nil end
    local knife = {}
    if real then
        for key, value in pairs(real) do knife[key] = value end
    end
    knife.Name = name
    if choice ~= "Default" then knife.Attachments = {} end
    if skin ~= "Default" then
        local camo = Knife.camo(name, skin)
        if camo then knife.Camo = camo end
    end
    local copy = {}
    for key, value in pairs(loadout) do copy[key] = value end
    copy.Knife = knife
    return copy
end

function Knife.filterSend(method, slot, name)
    if method ~= "changeWeapon" and method ~= "equipWeaponLoadout" then return false end
    if not flag("misc_knife_unlock", false) or not Knife.isKnife(name) then return false end
    local interface, owns = Game.mods.PlayerDataClientInterface, Knife.realOwns
    if not (interface and owns) then return false end
    local ok, owned = pcall(function() return owns(interface.getPlayerData(), name) end)
    return ok and not owned
end

Game.filterSend = Knife.filterSend

function Knife.syncUI()
    local names = Knife.list()
    if #names == 0 then return false end
    for flagName, items in pairs({ misc_knife = Knife.items(), misc_knife_skin = Knife.skinItems() }) do
        local option = Options[flagName]
        if option and type(option.SetValues) == "function" then
            local current = option.Value
            pcall(option.SetValues, option, items)
            if current and table.find(items, current) then pcall(option.SetValue, option, current) end
        end
    end
    Knife.synced = true
    return true
end

function Knife.hook()
    local spawner = Game.mods.CharacterObject
    if not Game.hooked.knifeSpawn and type(spawner) == "table" then
        Game.hooked.knifeSpawn = Util.hook(spawner, "new", function(original)
            return function(root, direction, loadout, ...)
                local ok, swapped = pcall(Knife.swap, loadout)
                if ok and swapped then loadout = swapped end
                return original(root, direction, loadout, ...)
            end
        end)
    end
    local data = Game.mods.PlayerDataUtils
    if not Game.hooked.knifeOwn and type(data) == "table" then
        Game.hooked.knifeOwn = Util.hook(data, "ownsWeapon", function(original)
            Knife.realOwns = original
            return function(playerData, name, ...)
                if flag("misc_knife_unlock", false) and Knife.isKnife(name) then return true end
                return original(playerData, name, ...)
            end
        end)
    end
    if not Knife.synced then Knife.syncUI() end
end

local Local = { recs = setmetatable({}, { __mode = "k" }), textures = {}, names = {}, idle = { specs = {}, rm = {} }, cats = { "arm", "glove", "cloth", "gun" } }

Local.materials = { "ForceField", "Plastic", "SmoothPlastic", "Neon", "Glass", "Metal", "Foil", "DiamondPlate", "CorrodedMetal", "Ice", "Glacier", "Marble", "Granite", "Wood", "Fabric", "Leather", "Rubber", "Sand", "Concrete", "Slate" }

for _, entry in ipairs({
    { "None", "" }, { "Webbed", "rbxassetid://2179243880" }, { "Pixelated", "rbxassetid://140652787" }, { "Swirl", "rbxassetid://8133639623" },
    { "Shield", "rbxassetid://361073795" }, { "Bubbles", "rbxassetid://1461576423" }, { "Matrix", "rbxassetid://10713189068" },
    { "Honeycomb", "rbxassetid://179898251" }, { "Clouds", "rbxassetid://5176277457" }, { "Galaxy", "rbxassetid://1120738433" },
    { "Stars", "rbxassetid://598201818" }, { "Wires", "rbxassetid://14127933" }, { "Camo", "rbxassetid://3280937154" },
    { "Hexagon", "rbxassetid://6175083785" }, { "Particles", "rbxassetid://1133822388" }, { "Triangular", "rbxassetid://4504368932" },
    { "Wall", "rbxassetid://4271279" }, { "Scanning", "rbxassetid://5843010904" },
}) do
    Local.names[#Local.names + 1] = entry[1]
    Local.textures[entry[1]] = entry[2]
end

function Local.kindOf(object)
    local function is(class)
        local ok, result = pcall(function() return object:IsA(class) end)
        return ok and result == true
    end
    if is("MeshPart") then return "mesh" end
    if is("UnionOperation") then return "union" end
    if is("BasePart") then return "part" end
    if is("SpecialMesh") then return "smesh" end
    if is("Texture") or is("Decal") then return "decal" end
    return nil
end

function Local.armCategory(object, model)
    local node = object
    for _ = 1, 12 do
        if not node or node == model then break end
        local name = propGet(node, "Name")
        if name == "Sleeves" then return "cloth" end
        if name == "SkinTone" then return "arm" end
        node = propGet(node, "Parent")
    end
    return "glove"
end

Local.glassWords = { "glass", "lens", "reticle", "window", "screen", "hologram", "holo", "reflector", "crosshair" }
Local.sightWords = { "sight", "optic", "scope", "acog", "holo", "reflex", "thermal", "attachment" }

function Local.hasWord(name, words)
    if type(name) ~= "string" then return false end
    name = string.lower(name)
    for _, word in ipairs(words) do
        if string.find(name, word, 1, true) then return true end
    end
    return false
end

function Local.isGlass(object, model)
    if Local.hasWord(propGet(object, "Name"), Local.glassWords) then return true end
    if propGet(object, "Material") == Enum.Material.Glass then return true end
    local okKids, kids = pcall(function() return object:GetChildren() end)
    if okKids and type(kids) == "table" then
        for _, kid in ipairs(kids) do
            local okGui, gui = pcall(function() return kid:IsA("SurfaceGui") end)
            if okGui and gui then return true end
        end
    end
    local alpha = propGet(object, "Transparency")
    if type(alpha) == "number" and alpha >= 0.05 and alpha <= 0.99 then
        local node = propGet(object, "Parent")
        for _ = 1, 12 do
            if not node or node == model then break end
            if Local.hasWord(propGet(node, "Name"), Local.sightWords) then return true end
            node = propGet(node, "Parent")
        end
    end
    return false
end

function Local.build(model, kind)
    local items = {}
    local ok, list = pcall(function() return model:GetDescendants() end)
    if not (ok and type(list) == "table") then return items end
    for _, object in ipairs(list) do
        local class = Local.kindOf(object)
        if class then
            local item = { inst = object, kind = class, cat = kind == "weapon" and "gun" or Local.armCategory(object, model) }
            if class == "decal" and item.cat == "gun" then
                local parent = propGet(object, "Parent")
                local parentName = propGet(parent, "Name")
                item.keep = type(parentName) == "string" and string.find(string.lower(parentName), "sight", 1, true) ~= nil
                if not item.keep and parent and parent ~= model then
                    local okPart, isPart = pcall(function() return parent:IsA("BasePart") end)
                    item.keep = okPart and isPart and Local.isGlass(parent, model) or false
                end
            elseif item.cat == "gun" and (class == "part" or class == "mesh" or class == "union") and object ~= model and Local.isGlass(object, model) then
                item.glass = true
            end
            items[#items + 1] = item
        end
    end
    return items
end

function Local.snapshot(item)
    local object, orig = item.inst, {}
    if item.kind == "smesh" then
        orig.TextureId, orig.VertexColor = propGet(object, "TextureId"), propGet(object, "VertexColor")
        return orig
    end
    orig.Transparency = propGet(object, "Transparency")
    if type(orig.Transparency) ~= "number" then return nil end
    if item.kind == "decal" then return orig end
    orig.Material, orig.Color, orig.Reflectance = propGet(object, "Material"), propGet(object, "Color"), propGet(object, "Reflectance")
    if orig.Color == nil then return nil end
    if item.kind == "mesh" then orig.TextureID = propGet(object, "TextureID") end
    if item.kind == "union" then orig.UsePartColor = propGet(object, "UsePartColor") end
    return orig
end

function Local.setIf(object, prop, value)
    if value ~= nil and propGet(object, prop) ~= value then propSet(object, prop, value) end
end

function Local.writeTransparency(item, want, current)
    if want == nil or current == want then return end
    if want >= 1 or current < 1 or item.wrote == 1 then
        propSet(item.inst, "Transparency", want)
        item.wrote = want
    end
end

function Local.restoreItem(item)
    local object, orig = item.inst, item.orig
    item.orig = nil
    if not orig then return end
    if item.kind == "smesh" then
        Local.setIf(object, "TextureId", orig.TextureId)
        Local.setIf(object, "VertexColor", orig.VertexColor)
    else
        if item.wrote ~= nil and propGet(object, "Transparency") == item.wrote then propSet(object, "Transparency", orig.Transparency) end
        if item.kind ~= "decal" then
            Local.setIf(object, "Material", orig.Material)
            Local.setIf(object, "Color", orig.Color)
            Local.setIf(object, "Reflectance", orig.Reflectance)
            Local.setIf(object, "TextureID", orig.TextureID)
            Local.setIf(object, "UsePartColor", orig.UsePartColor)
        end
    end
    item.wrote = nil
end

function Local.applyItem(item, spec, hide, noglass)
    if item.glass and not hide then
        if not (spec and noglass) then
            if item.orig then Local.restoreItem(item) end
            return
        end
        if item.orig == nil then item.orig = Local.snapshot(item) or false end
        local current = propGet(item.inst, "Transparency")
        if item.orig and type(current) == "number" then Local.writeTransparency(item, 1, current) end
        return
    end
    if not (hide or spec) then
        if item.orig then Local.restoreItem(item) end
        return
    end
    if item.orig == nil then item.orig = Local.snapshot(item) or false end
    local orig, object = item.orig, item.inst
    if not orig then return end
    if item.kind == "smesh" then
        if spec then
            Local.setIf(object, "TextureId", spec.texture)
            Local.setIf(object, "VertexColor", spec.vertex)
        end
        return
    end
    local current = propGet(object, "Transparency")
    if type(current) ~= "number" then return end
    if orig.Transparency >= 1 and current < 1 and item.wrote == nil then orig.Transparency = current end
    if item.kind == "decal" then
        if hide or not item.keep then Local.writeTransparency(item, 1, current) end
        return
    end
    if hide then
        Local.writeTransparency(item, 1, current)
        return
    end
    Local.setIf(object, "Material", spec.material)
    Local.setIf(object, "Color", spec.color)
    Local.setIf(object, "Reflectance", spec.refl)
    if item.kind == "mesh" then Local.setIf(object, "TextureID", spec.texture) end
    if item.kind == "union" then Local.setIf(object, "UsePartColor", true) end
    Local.writeTransparency(item, orig.Transparency < 1 and spec.alpha or nil, current)
end

function Local.spec(cat)
    local base = "local_" .. cat
    if not on(base) then return nil end
    local color = val(base .. "_color") or WHITE
    local materialName = val(base .. "_mat") or "ForceField"
    local okMaterial, material = pcall(function() return Enum.Material[materialName] end)
    if not (okMaterial and material) then return nil end
    local texture = ""
    if materialName == "ForceField" then texture = Local.textures[val(base .. "_tex") or "None"] or "" end
    return {
        color = color, alpha = Util.alpha(base .. "_color", 0), material = material, texture = texture,
        refl = val(base .. "_refl") or 0, vertex = Vector3.new(color.R, color.G, color.B),
    }
end

function Local.settings()
    local state = { specs = {}, any = false, rm = {
        armLeft = on("local_rm_larm") == true, armRight = on("local_rm_rarm") == true,
        clothLeft = on("local_rm_lsleeve") == true, clothRight = on("local_rm_rsleeve") == true,
        glove = on("local_rm_gloves") == true, gun = on("local_rm_gun") == true,
    } }
    state.noglass = on("local_gun_noglass") == true
    for _, cat in ipairs(Local.cats) do
        local spec = Local.spec(cat)
        state.specs[cat] = spec
        if spec then state.any = true end
    end
    for _, hidden in pairs(state.rm) do
        if hidden then state.any = true end
    end
    return state
end

function Local.styleRec(rec, state)
    for _, item in ipairs(rec.items) do
        local cat = item.cat
        local hide = state.rm[(cat == "glove" or cat == "gun") and cat or cat .. (rec.side or "")]
        Local.applyItem(item, state.specs[cat], hide, state.noglass)
    end
end

function Local.track(model, kind, side, now)
    if not model then return end
    local rec = Local.recs[model]
    if not rec then
        rec = { kind = kind, side = side, items = Local.build(model, kind) }
        Local.recs[model] = rec
    end
    rec.seen = now
end

function Local.collect(now)
    local interface = Game.mods.CharacterInterface
    if not (interface and Game.localAlive()) then return end
    local ok, character = pcall(interface.getCharacterObject)
    if not (ok and type(character) == "table") then return end
    if type(character.getArmModels) == "function" then
        local okArms, left, right = pcall(character.getArmModels, character)
        if okArms then
            Local.track(left, "arm", "Left", now)
            Local.track(right, "arm", "Right", now)
        end
    end
    local weapon = Game.weapon()
    if weapon then
        local okModel, model = pcall(function() return weapon._weaponModel or weapon:getWeaponModel() end)
        if okModel then Local.track(model, "weapon", nil, now) end
    end
end

function Local.refresh(now)
    local state = Local.settings()
    if not state.any and next(Local.recs) == nil then return end
    if state.any then Local.collect(now) end
    for model, rec in pairs(Local.recs) do
        if not state.any or now - rec.seen > 20 then
            Local.styleRec(rec, Local.idle)
            Local.recs[model] = nil
        else
            Local.styleRec(rec, state)
        end
    end
end

function Local.offset(weapon)
    if not on("local_vm") then return end
    local x, y, z = flag("local_vm_x", 0), flag("local_vm_y", 0), flag("local_vm_z", 0)
    local pitch, yaw, roll = flag("local_vm_pitch", 0), flag("local_vm_yaw", 0), flag("local_vm_roll", 0)
    if x == 0 and y == 0 and z == 0 and pitch == 0 and yaw == 0 and roll == 0 then return end
    local main, character = weapon._mainWeld, weapon._characterObject
    local cam = Game.camera()
    if not (main and character and cam) then return end
    local scale = 1
    if flag("local_vm_aim", false) and type(weapon._aimArmSpring) == "table" and type(weapon._aimArmSpring.p) == "number" then
        scale = 1 - math.clamp(weapon._aimArmSpring.p, 0, 1)
    end
    local base = main.C0
    local relative = character:getRootPart().CFrame:Inverse() * Stretch.cf(cam)
    local axes = CFrame.new(relative.Position):Inverse() * relative
    local spin = axes * CFrame.Angles(math.rad(pitch) * scale, math.rad(yaw) * scale, math.rad(roll) * scale) * axes:Inverse()
    local pivot = CFrame.new(base.Position)
    local shift = CFrame.new(axes * Vector3.new(x * scale, y * scale, -z * scale))
    local change = shift * pivot * spin * pivot:Inverse()
    main.C0 = change * base
    local left, right = character:getArmWelds()
    if left then left.C0 = change * left.C0 end
    if right then right.C0 = change * right.C0 end
end

function Local.afterStep(weapon)
    Local.hooked = true
    pcall(Local.offset, weapon)
    Local.refresh(os.clock())
end

function Local.hook()
    for _, name in ipairs({ "FirearmObject", "MeleeObject", "GrenadeObject" }) do
        local key, owner = "step" .. name, Game.mods[name]
        if owner and not Game.hooked[key] then
            Game.hooked[key] = Util.hook(owner, "step", function(original)
                return function(self, ...)
                    local a, b = original(self, ...)
                    Util.guard("localvis", Local.afterStep, self)
                    return a, b
                end
            end)
        end
    end
end

function Local.step(now)
    if Local.hooked then
        Local.hooked = false
        return
    end
    Local.refresh(now)
end

Util.onUnload(function()
    for model, rec in pairs(Local.recs) do
        Local.styleRec(rec, Local.idle)
        Local.recs[model] = nil
    end
end)

local Corpse = { recs = setmetatable({}, { __mode = "k" }), owned = setmetatable({}, { __mode = "k" }), held = setmetatable({}, { __mode = "k" }), bodyNames = {}, lifetime = 30, matchRange = 10, scanAt = 0 }

for _, name in ipairs(PART_NAMES) do Corpse.bodyNames[name] = true end

function Corpse.container()
    local cached = Corpse.folder
    if cached and propGet(cached, "Parent") then return cached end
    Corpse.folder, Corpse.connected = nil, nil
    local ignore = Workspace:FindFirstChild("Ignore")
    local folder = ignore and ignore:FindFirstChild("DeadBody")
    if not folder then return nil end
    Corpse.folder = folder
    return folder
end

function Corpse.kindOf(model)
    local torso = model:FindFirstChild("Torso")
    local position = torso and propGet(torso, "Position")
    if typeof(position) ~= "Vector3" then return "enemy" end
    local best, kind = Corpse.matchRange, "enemy"
    for _, record in pairs(Entities.byPlayer) do
        if typeof(record.pos) == "Vector3" then
            local distance = (record.pos - position).Magnitude
            if distance < best then best, kind = distance, record.enemy == false and "team" or "enemy" end
        end
    end
    if typeof(Corpse.localPos) == "Vector3" and (Corpse.localPos - position).Magnitude < best then kind = "local" end
    return kind
end

function Corpse.add(model, now)
    if Corpse.recs[model] or not on("chams_dead") or propGet(model, "Parent") == nil then return end
    local items = Local.build(model, "weapon")
    for _, item in ipairs(items) do
        local node = item.inst
        for _ = 1, 12 do
            local parent = propGet(node, "Parent")
            if not parent or parent == model then break end
            node = parent
        end
        item.extra = not Corpse.bodyNames[propGet(node, "Name")]
    end
    Corpse.recs[model] = { items = items, kind = Corpse.kindOf(model), born = now, sig = nil }
end

function Corpse.state()
    local state = { materialName = val("chams_dead_mat") or "ForceField", texture = val("chams_dead_tex") or "None", refl = val("chams_dead_refl") or 0,
        hide = on("chams_dead_hide") == true, fade = val("chams_dead_fade") or 0, kinds = {} }
    local parts = { state.materialName, state.texture, state.refl, tostring(state.hide), state.fade }
    for _, kind in ipairs({ "enemy", "team", "local" }) do
        local flagName = "chams_dead_" .. kind .. "_color"
        local entry = { enabled = on("chams_dead_" .. kind) == true, color = val(flagName) or WHITE, alpha = Util.alpha(flagName, 0) }
        state.kinds[kind] = entry
        parts[#parts + 1] = tostring(entry.enabled) .. tostring(entry.color) .. entry.alpha
    end
    state.sig = table.concat(parts, "|")
    local okMaterial, material = pcall(function() return Enum.Material[state.materialName] end)
    state.material = okMaterial and material or nil
    state.textureId = state.materialName == "ForceField" and Local.textures[state.texture] or ""
    return state
end

function Corpse.style(rec, state, now)
    local entry = state.kinds[rec.kind]
    local spec
    if entry.enabled and state.material then
        local alpha = entry.alpha
        if state.fade > 0 then
            local fadeStart = Corpse.lifetime - state.fade
            local age = now - rec.born
            if age > fadeStart then alpha = alpha + (1 - alpha) * math.clamp((age - fadeStart) / state.fade, 0, 1) end
        end
        spec = { color = entry.color, alpha = alpha, material = state.material, texture = state.textureId, refl = state.refl,
            vertex = Vector3.new(entry.color.R, entry.color.G, entry.color.B) }
    end
    for _, item in ipairs(rec.items) do
        Local.applyItem(item, spec, spec and state.hide and item.extra)
    end
end

function Corpse.restoreAll()
    for model, rec in pairs(Corpse.recs) do
        if Corpse.owned[model] then
            Corpse.held[model] = rec
        else
            for _, item in ipairs(rec.items) do Local.applyItem(item, nil, nil) end
        end
        Corpse.recs[model] = nil
    end
end

function Corpse.release(model)
    Corpse.owned[model] = nil
    local held, rec = Corpse.held[model], Corpse.recs[model]
    Corpse.held[model] = nil
    if held then
        for _, item in ipairs(held.items) do Local.applyItem(item, nil, nil) end
    end
    if rec then rec.sig = nil end
end

function Corpse.step(now)
    if not on("chams_dead") then
        if next(Corpse.recs) then Corpse.restoreAll() end
        return
    end
    local root = Game.rootPart()
    if root then Corpse.localPos = propGet(root, "Position") end
    local folder = Corpse.container()
    if folder and not Corpse.connected then
        Corpse.connected = true
        pcall(function()
            Util.track(folder.ChildAdded:Connect(function(child) Util.guard("corpseadd", Corpse.add, child, os.clock()) end))
        end)
    end
    if folder and now >= Corpse.scanAt then
        Corpse.scanAt = now + 1
        local ok, children = pcall(folder.GetChildren, folder)
        if ok and type(children) == "table" then
            for _, child in ipairs(children) do Corpse.add(child, now) end
        end
    end
    if next(Corpse.recs) == nil then return end
    local state = Corpse.state()
    for model, rec in pairs(Corpse.recs) do
        if propGet(model, "Parent") == nil then
            Corpse.recs[model] = nil
        elseif Corpse.owned[model] then
            rec.sig = nil
        elseif rec.sig ~= state.sig or (state.fade > 0 and now - rec.born > Corpse.lifetime - state.fade) then
            rec.sig = state.sig
            Corpse.style(rec, state, now)
        end
    end
end

Util.onUnload(Corpse.restoreAll)

local KillFx = {
    events = {}, pending = {}, fired = setmetatable({}, { __mode = "k" }), maxEvents = 6, fx = {}, window = 2, near = 6,
    names = { "Dissolve", "Lightning", "Shockwave", "Sparks", "Pillar", "Screen flash" },
    glow = "rbxasset://textures/particles/sparkles_main.dds",
}

local function fxRand(low, high) return low + (high - low) * math.random() end

function KillFx.make(ev, class, props, parent)
    local object = Instance.new(class)
    object.Name = Util.randomName()
    ev.group[#ev.group + 1] = object
    for key, value in pairs(props) do object[key] = value end
    object.Parent = parent or ev.root
    return object
end

function KillFx.anchor(ev, pos, size)
    return KillFx.make(ev, "Part", {
        Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
        Transparency = 1, Size = size or Vector3.new(1, 1, 1), Position = pos,
    })
end

function KillFx.beam(ev, parent, a0, a1, color, width0, width1)
    return KillFx.make(ev, "Beam", {
        Attachment0 = a0, Attachment1 = a1, Color = ColorSequence.new(color), LightEmission = 1, LightInfluence = 0,
        FaceCamera = true, Segments = 1, Width0 = width0, Width1 = width1, Transparency = NumberSequence.new(0),
    }, parent)
end

function KillFx.emitter(ev, parent, props)
    local base = {
        Texture = KillFx.glow, LightEmission = 1, LightInfluence = 0, Rate = 0, Enabled = false,
        Rotation = NumberRange.new(0, 360), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) }),
    }
    for key, value in pairs(props) do base[key] = value end
    return KillFx.make(ev, "ParticleEmitter", base, parent)
end

function KillFx.shrink(size)
    return NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
end

function KillFx.jag(from, to, count, spread)
    local delta = to - from
    local axis = math.abs(delta.Unit.Y) > 0.98 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)
    local side = delta:Cross(axis).Unit
    local up = delta:Cross(side).Unit
    local points = { from }
    for index = 1, count - 1 do
        points[#points + 1] = from + delta * (index / count) + side * fxRand(-spread, spread) + up * fxRand(-spread, spread)
    end
    points[#points + 1] = to
    return points
end

KillFx.fx.Lightning = {
    start = function(ev, corpse, pos, opts)
        local top = pos + Vector3.new(fxRand(-8, 8), fxRand(60, 80), fxRand(-8, 8))
        local holder = KillFx.anchor(ev, pos)
        local chains = { { from = top, to = pos, count = 12, spread = 4.5, width = 0.9 * opts.int, taper = 0.5 } }
        for _ = 1, math.random(1, 2) do
            local origin = top + (pos - top) * fxRand(0.3, 0.8)
            local heading = Vector3.new(fxRand(-1, 1), fxRand(-1.2, -0.2), fxRand(-1, 1)).Unit
            chains[#chains + 1] = { from = origin, to = origin + heading * fxRand(12, 22), count = 4, spread = 1.5, width = 0.5 * opts.int, taper = 0.8 }
        end
        local beams = {}
        for _, chain in ipairs(chains) do
            chain.points = {}
            for index = 1, chain.count + 1 do chain.points[index] = KillFx.make(ev, "Attachment", {}, holder) end
            for index = 1, chain.count do
                local w0 = chain.width * (1 - chain.taper * (index - 1) / chain.count)
                local w1 = chain.width * (1 - chain.taper * index / chain.count)
                beams[#beams + 1] = KillFx.beam(ev, holder, chain.points[index], chain.points[index + 1], opts.color, w0, w1)
                beams[#beams + 1] = KillFx.beam(ev, holder, chain.points[index], chain.points[index + 1], WHITE, w0 * 0.4, w1 * 0.4)
            end
        end
        local function reshape()
            for _, chain in ipairs(chains) do
                local points = KillFx.jag(chain.from, chain.to, chain.count, chain.spread)
                for index, attachment in ipairs(chain.points) do attachment.WorldPosition = points[index] end
            end
        end
        reshape()
        local light = KillFx.make(ev, "PointLight", { Color = opts.color, Brightness = 8 * opts.int, Range = 30 }, holder)
        local frame, shown = 0, 0
        ev.ticks[#ev.ticks + 1] = function(t)
            local step = math.floor(t / 0.06)
            if step ~= frame and step < 4 then
                frame = step
                reshape()
            end
            local fade = math.clamp((t - 0.24) / 0.36, 0, 1)
            if fade ~= shown then
                shown = fade
                for _, beam in ipairs(beams) do beam.Transparency = NumberSequence.new(fade) end
            end
            light.Brightness = 8 * opts.int * math.max(0, 1 - t / 0.35)
            return t >= 0.6
        end
    end,
}

KillFx.fx.Dissolve = {
    start = function(ev, corpse, pos, opts)
        local ok, list = pcall(function() return corpse:GetDescendants() end)
        if not (ok and type(list) == "table") then return end
        local parts, decals, byPart, low, high = {}, {}, {}, math.huge, -math.huge
        for _, object in ipairs(list) do
            local kind = Local.kindOf(object)
            local base = propGet(object, "Transparency")
            if type(base) == "number" then
                if kind == "decal" then
                    decals[#decals + 1] = { inst = object, base = base }
                elseif kind then
                    local at = propGet(object, "Position")
                    if base < 1 and typeof(at) == "Vector3" then
                        local item = { inst = object, base = base, y = at.Y, alpha = -1, material = propGet(object, "Material"), color = propGet(object, "Color") }
                        parts[#parts + 1], byPart[object] = item, item
                        low, high = math.min(low, at.Y), math.max(high, at.Y)
                    end
                end
            end
        end
        if #parts == 0 then return end
        Corpse.owned[corpse] = true
        local span = math.max(high - low, 0.01)
        for _, item in ipairs(parts) do item.key = (item.y - low) / span * 0.55 + math.random() * 0.25 end
        for _, item in ipairs(decals) do
            local owner = byPart[propGet(item.inst, "Parent")]
            item.key = owner and owner.key or 0.4
        end
        local rate = math.max(2, math.floor(10 * opts.int))
        local finished = false
        ev.undo[#ev.undo + 1] = function()
            if finished then return end
            finished = true
            for _, item in ipairs(parts) do
                Local.setIf(item.inst, "Material", item.material)
                Local.setIf(item.inst, "Color", item.color)
                Local.setIf(item.inst, "Transparency", item.base)
            end
            for _, item in ipairs(decals) do Local.setIf(item.inst, "Transparency", item.base) end
            Corpse.release(corpse)
        end
        ev.ticks[#ev.ticks + 1] = function(t)
            if finished then return true end
            if propGet(corpse, "Parent") == nil then
                finished = true
                return true
            end
            local progress = t / opts.dur
            for _, item in ipairs(parts) do
                local alpha = math.clamp((progress - item.key) / 0.2, 0, 1)
                if alpha ~= item.alpha then
                    item.alpha = alpha
                    local object = item.inst
                    if alpha > 0 then
                        if not item.glow then
                            item.glow = true
                            propSet(object, "Material", Enum.Material.Neon)
                            item.emitter = KillFx.emitter(ev, object, {
                                Rate = rate, Enabled = true, Lifetime = NumberRange.new(0.6, 1.3), Speed = NumberRange.new(1, 4),
                                Acceleration = Vector3.new(0, 6, 0), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(40, 40),
                                Size = KillFx.shrink(0.35), Color = ColorSequence.new(opts.color2, opts.color),
                            })
                        end
                        propSet(object, "Color", Util.lerpColor(opts.color2, opts.color, alpha))
                    end
                    propSet(object, "Transparency", item.base + (1 - item.base) * alpha)
                    if alpha >= 1 and item.emitter then propSet(item.emitter, "Enabled", false) end
                end
            end
            for _, item in ipairs(decals) do
                propSet(item.inst, "Transparency", item.base + (1 - item.base) * math.clamp((progress - item.key) / 0.2, 0, 1))
            end
            if progress >= 1.05 then finished = true end
            return finished
        end
    end,
}

KillFx.fx.Shockwave = {
    start = function(ev, corpse, pos, opts)
        local ground = pos
        local okCast, hit = pcall(Game.cast, pos + Vector3.new(0, 3, 0), Vector3.new(0, -60, 0), Visible.params)
        if okCast and hit and typeof(hit.Position) == "Vector3" then ground = hit.Position end
        local holder = KillFx.anchor(ev, ground)
        local count, points, beams = 24, {}, {}
        for index = 1, count do points[index] = KillFx.make(ev, "Attachment", {}, holder) end
        for index = 1, count do
            beams[index] = KillFx.beam(ev, holder, points[index], points[index % count + 1], opts.color, 1, 1)
        end
        local shell = KillFx.make(ev, "Part", {
            Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Shape = Enum.PartType.Ball,
            Material = Enum.Material.Neon, Color = opts.color2, Transparency = 0.45, Size = Vector3.new(2, 2, 2), Position = pos,
        })
        local reach = 30 * (0.7 + 0.3 * opts.int)
        ev.ticks[#ev.ticks + 1] = function(t)
            local progress = math.clamp(t / 0.9, 0, 1)
            local radius = Util.lerp(2, reach, 1 - (1 - progress) ^ 2)
            local width = 0.2 + 1.4 * opts.int * (1 - progress)
            local fade = NumberSequence.new(progress)
            for index = 1, count do
                local angle = (index - 1) / count * math.pi * 2
                points[index].WorldPosition = ground + Vector3.new(math.cos(angle) * radius, 0.4, math.sin(angle) * radius)
                beams[index].Width0, beams[index].Width1, beams[index].Transparency = width, width, fade
            end
            local across = Util.lerp(2, 18, progress)
            shell.Size, shell.Transparency = Vector3.new(across, across, across), Util.lerp(0.45, 1, progress)
            return progress >= 1
        end
    end,
}

KillFx.fx.Sparks = {
    start = function(ev, corpse, pos, opts)
        local holder = KillFx.anchor(ev, pos)
        local emitter = KillFx.emitter(ev, holder, {
            Speed = NumberRange.new(25, 55), SpreadAngle = Vector2.new(180, 180), Lifetime = NumberRange.new(0.4, 1),
            Acceleration = Vector3.new(0, -70, 0), Size = KillFx.shrink(0.5), Color = ColorSequence.new(opts.color, opts.color2),
            Orientation = Enum.ParticleOrientation.VelocityParallel,
        })
        local count = math.floor(40 * opts.int)
        local burst = pcall(function() emitter:Emit(count) end)
        if not burst then
            propSet(emitter, "Rate", count * 8)
            propSet(emitter, "Enabled", true)
        end
        ev.ticks[#ev.ticks + 1] = function(t)
            if t > 0.12 and not burst then propSet(emitter, "Enabled", false) end
            return t >= 1.2
        end
    end,
}

KillFx.fx.Pillar = {
    start = function(ev, corpse, pos, opts)
        local width = 3.5 * math.sqrt(opts.int)
        local column = KillFx.make(ev, "Part", {
            Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Shape = Enum.PartType.Cylinder,
            Material = Enum.Material.Neon, Color = opts.color, Transparency = 0.2, Size = Vector3.new(1, width, width), Position = pos,
        })
        local base = KillFx.anchor(ev, pos, Vector3.new(3, 0.2, 3))
        local emitter = KillFx.emitter(ev, base, {
            Rate = math.floor(18 * opts.int), Enabled = true, Lifetime = NumberRange.new(1, 2), Speed = NumberRange.new(10, 20),
            EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(10, 10), Size = KillFx.shrink(0.5),
            Color = ColorSequence.new(opts.color2, opts.color),
        })
        ev.ticks[#ev.ticks + 1] = function(t)
            local height = 120 * math.min(1, t / 0.2)
            local girth = width * (1 + 0.12 * math.sin(t * 16))
            column.Size = Vector3.new(height, girth, girth)
            column.CFrame = CFrame.new(pos.X, pos.Y + height / 2 - 2, pos.Z) * CFrame.Angles(0, 0, math.pi / 2)
            column.Transparency = 0.2 + 0.8 * math.clamp(t / opts.dur, 0, 1) ^ 1.3
            if t > opts.dur * 0.7 then propSet(emitter, "Enabled", false) end
            return t >= opts.dur
        end
    end,
}

KillFx.fx["Screen flash"] = {
    start = function(ev, corpse, pos, opts)
        local camera = ev.root
        local eye = camera and propGet(camera, "CFrame")
        if eye and (eye.Position - pos).Magnitude > opts.flashDist then return end
        local gui = Chams.getContainer()
        if not gui then return end
        local frame = KillFx.make(ev, "Frame", {
            Size = UDim2.fromScale(1, 1), BackgroundColor3 = Util.lerpColor(opts.color, WHITE, 0.6), BackgroundTransparency = 0.6,
            BorderSizePixel = 0, ZIndex = 1000,
        }, gui)
        ev.ticks[#ev.ticks + 1] = function(t)
            local progress = math.clamp(t / 0.25, 0, 1)
            frame.BackgroundTransparency = 0.6 + 0.4 * progress
            return progress >= 1
        end
    end,
}

function KillFx.settings()
    return {
        color = val("kill_fx_color") or Color3.fromRGB(102, 204, 255), color2 = val("kill_fx_color2") or WHITE,
        int = val("kill_fx_int") or 1, dur = math.max(0.5, val("kill_fx_dur") or 2.5), flashDist = val("kill_fx_flash_dist") or 150,
        list = Util.set("kill_fx_list", { "Dissolve", "Lightning" }),
    }
end

function KillFx.free(group)
    for index = #group, 1, -1 do
        local object = group[index]
        pcall(object.Destroy, object)
        group[index] = nil
    end
end

function KillFx.destroy(ev)
    for _, undo in ipairs(ev.undo) do Util.guard("killfx undo", undo) end
    for _, group in ipairs(ev.groups) do KillFx.free(group) end
    ev.groups, ev.ticks, ev.undo = {}, {}, {}
end

function KillFx.run(ev, name, fn, ...)
    local group, first = {}, #ev.ticks + 1
    ev.group = group
    ev.groups[#ev.groups + 1] = group
    Util.guard("killfx " .. name, fn, ev, ...)
    for slot = first, #ev.ticks do ev.ticks[slot] = { fn = ev.ticks[slot], group = group } end
end

function KillFx.clear()
    for _, ev in ipairs(KillFx.events) do KillFx.destroy(ev) end
    KillFx.events, KillFx.pending, KillFx.seeded = {}, {}, false
end

function KillFx.queue(child, now)
    if not on("kill_fx") or KillFx.fired[child] then return end
    KillFx.fired[child] = true
    KillFx.pending[child] = now
end

function KillFx.anchorOf(model)
    for _, name in ipairs({ "Torso", "Head" }) do
        local ok, part = pcall(model.FindFirstChild, model, name)
        local at = ok and part and propGet(part, "Position")
        if typeof(at) == "Vector3" then return at end
    end
    return nil
end

function KillFx.modelKill(model)
    for index, kill in ipairs(Feedback.kills) do
        if kill.model ~= nil and kill.model == model then return index end
    end
    return nil
end

function KillFx.closest(kill, model, distance)
    for other in pairs(KillFx.pending) do
        if other ~= model and not KillFx.modelKill(other) then
            local at = KillFx.anchorOf(other)
            if at and (kill.pos - at).Magnitude < distance then return false end
        end
    end
    return true
end

function KillFx.claim(model, pos, now)
    local kills = Feedback.kills
    for index = #kills, 1, -1 do
        if now - kills[index].at > KillFx.window then table.remove(kills, index) end
    end
    local best = KillFx.modelKill(model)
    if not best and pos then
        local bestDistance = KillFx.near
        for index, kill in ipairs(kills) do
            if kill.model == nil and typeof(kill.pos) == "Vector3" then
                local distance = (kill.pos - pos).Magnitude
                if distance < bestDistance and KillFx.closest(kill, model, distance) then best, bestDistance = index, distance end
            end
        end
    end
    if not best then return false end
    table.remove(kills, best)
    return true
end

function KillFx.launch(model, pos, now)
    local opts = KillFx.settings()
    local root = propGet(Workspace, "CurrentCamera")
    if not root then return end
    while #KillFx.events >= KillFx.maxEvents do KillFx.destroy(table.remove(KillFx.events, 1)) end
    local ev = { born = now, groups = {}, ticks = {}, undo = {}, root = root, limit = opts.dur + 4 }
    KillFx.events[#KillFx.events + 1] = ev
    for _, name in ipairs(KillFx.names) do
        if opts.list[name] then KillFx.run(ev, name, KillFx.fx[name].start, model, pos, opts) end
    end
    local id = on("kill_fx_sound") and tostring(val("kill_fx_sound_id") or "") or ""
    if id:match("%S") then
        KillFx.run(ev, "sound", function()
            local holder = KillFx.anchor(ev, pos)
            local sound = KillFx.make(ev, "Sound", { SoundId = id:match("^%d+$") and "rbxassetid://" .. id or id, Volume = 1 }, holder)
            pcall(sound.Play, sound)
            ev.ticks[#ev.ticks + 1] = function(t) return t >= 3 end
        end)
    end
end

function KillFx.step(now)
    if not on("kill_fx") then
        if next(KillFx.events) or next(KillFx.pending) or KillFx.seeded then KillFx.clear() end
        return
    end
    local root = Game.rootPart()
    if root then Corpse.localPos = propGet(root, "Position") end
    local folder = Corpse.container()
    if folder and folder ~= KillFx.watching then
        KillFx.watching = folder
        pcall(function()
            Util.track(folder.ChildAdded:Connect(function(child) Util.guard("killfxadd", KillFx.queue, child, os.clock()) end))
        end)
    end
    if folder and not KillFx.seeded then
        KillFx.seeded = true
        local ok, children = pcall(folder.GetChildren, folder)
        if ok and type(children) == "table" then
            for _, child in ipairs(children) do KillFx.fired[child] = true end
        end
    end
    for model, born in pairs(KillFx.pending) do
        local pos = KillFx.anchorOf(model)
        if propGet(model, "Parent") == nil or now - born > KillFx.window then
            KillFx.pending[model] = nil
        elseif pos and KillFx.claim(model, pos, now) then
            KillFx.pending[model] = nil
            Util.guard("killfx launch", KillFx.launch, model, pos, now)
        end
    end
    local events = KillFx.events
    for index = #events, 1, -1 do
        local ev = events[index]
        local age, ticks = now - ev.born, ev.ticks
        for slot = #ticks, 1, -1 do
            local entry = ticks[slot]
            local ok, finished = pcall(entry.fn, age)
            if not ok then Util.note("killfx tick" .. tostring(finished), "killfx:", finished) end
            if not ok or finished == true then
                KillFx.free(entry.group)
                table.remove(ticks, slot)
            end
        end
        if #ticks == 0 or age > ev.limit then
            KillFx.destroy(ev)
            table.remove(events, index)
        end
    end
end

Util.onUnload(KillFx.clear)

local Pages = {
    Legit = UI.page("Legit", "crosshair"),
    Rage = UI.page("Rage", "swords"),
    ESP = UI.page("ESP", "eye"),
    World = UI.page("World", "globe"),
    Misc = UI.page("Misc", "shapes"),
}
local Status = {}
local ESPSubs = Pages.ESP:SubTabs({ { "Enemies", "swords" }, { "Teammates", "shield" }, { "Other", "package" }, { "Local", "user" } })

do
    local Subs = Pages.Legit:SubTabs({ { "Aim Assist", "crosshair" }, { "Silent Aim", "scan" }, { "Trigger Bot", "zap" }, { "Recoil", "target" } })

    local Aim = Subs["Aim Assist"]
    local function pickColor(popup, label, flagName, default, alpha)
        popup:Label({ Name = label }):Colorpicker({ Name = label, Flag = flagName, Default = default, Alpha = alpha or 0 })
    end
    local Master = Aim:Section({ Name = "Aim assist", Column = 1, Icon = "crosshair" })
    Master:Toggle({ Name = "Enabled", Flag = "legit_aim", Tooltip = "Turns your view toward the target through the game's camera while the key is held" }):Keybind({ Name = "Aim key", Flag = "legit_aim_key", Default = "MB2", Mode = "Hold" })
    local Semi = Master:Toggle({ Name = "Semi-auto aim", Flag = "legit_semi", Tooltip = "A second aim key that only works while the equipped weapon is set to semi (single shot); it uses its own FOV, smoothing and hitboxes and overrides the normal key. Other aim settings are shared" }):Keybind({ Name = "Semi-auto key", Flag = "legit_semi_key", Default = "MB2", Mode = "Hold" }):Settings("Semi-auto aim", 230)
    Semi:Slider({ Name = "Semi FOV", Flag = "legit_semi_fov", Min = 10, Max = 800, Default = 90, Decimals = 1, Suffix = " px" })
    Semi:Slider({ Name = "Semi smoothing", Flag = "legit_semi_smooth", Min = 1, Max = 60, Default = 6, Decimals = 1 })
    Semi:Dropdown({ Name = "Semi hitbox priority", Flag = "legit_semi_priority", Items = { "Closest", "Head", "Torso" }, Default = "Head" })
    Semi:Dropdown({ Name = "Semi hitboxes", Flag = "legit_semi_parts", Items = { "Head", "Torso", "Arms", "Legs" }, Multi = true, Default = { "Head" } })
    Semi:Toggle({ Name = "Snap on shot", Flag = "legit_semi_onfire", Tooltip = "Does nothing until you press mouse 1, then snaps onto the target once for that shot (no smoothing or reaction delay)" })
    Master:Toggle({ Name = "Team check", Flag = "legit_team_check", Default = true, Tooltip = "Only enemies are targeted (shared with the triggerbot)" })
    local VisibleCheck = Master:Toggle({ Name = "Visible check", Flag = "legit_visible", Default = true, Tooltip = "Only aims at points with a clear line from the barrel, multi-ray, ignoring glass, non-solid parts and other players" }):Settings("Visible check", 230)
    VisibleCheck:Slider({ Name = "ESP rays per player", Flag = "vis_rays", Min = 1, Max = 6, Default = 3, Decimals = 1, Tooltip = "Body parts traced for ESP visible/hidden colours; stops at the first clear one" })
    VisibleCheck:Slider({ Name = "ESP check interval", Flag = "vis_interval", Min = 20, Max = 400, Default = 100, Decimals = 1, Suffix = " ms", Tooltip = "How long an ESP visibility result is reused" })
    local Multi = Master:Toggle({ Name = "Multipoint", Flag = "legit_multi", Tooltip = "Tests several points per hitbox and aims at the best visible one nearest the crosshair" }):Settings("Multipoint", 230)
    Multi:Slider({ Name = "Multipoint scale", Flag = "legit_multi_scale", Min = 10, Max = 100, Default = 60, Decimals = 1, Suffix = "%", Tooltip = "How far from the hitbox centre the extra points sit" })
    Multi:Slider({ Name = "Max points", Flag = "legit_multi_max", Min = 1, Max = 9, Default = 5, Decimals = 1, Tooltip = "Points tested per body part (head up to 7, torso up to 9, limbs up to 3)" })
    Multi:Toggle({ Name = "Show points", Flag = "legit_multi_show", Tooltip = "Small dots on the target's tested points" })
    pickColor(Multi, "Chosen point", "legit_multi_color", Color3.fromRGB(120, 255, 170))
    local Wall = Master:Toggle({ Name = "Wallbang", Flag = "legit_wallbang", Tooltip = "Also targets players behind walls that the equipped weapon can shoot through, using the game's own penetration rule (entry to exit thickness summed against penetration depth)" }):Settings("Wallbang", 230)
    Wall:Slider({ Name = "Penetration safety", Flag = "legit_pen_safety", Min = 50, Max = 100, Default = 90, Decimals = 1, Suffix = "%", Tooltip = "Share of the weapon's penetration depth the walls may use" })
    local Pred = Master:Toggle({ Name = "Bullet prediction", Flag = "legit_pred", Tooltip = "Solves where the bullet meets the target from its speed, drop and the target's tracked velocity" }):Settings("Bullet prediction", 230)
    Pred:Toggle({ Name = "Show prediction dot", Flag = "legit_pred_show", Default = true })
    pickColor(Pred, "Dot", "legit_pred_color", Color3.fromRGB(255, 40, 40))
    Pred:Toggle({ Name = "Dot outline", Flag = "legit_pred_outline", Default = true })
    Pred:Toggle({ Name = "All enemies in FOV", Flag = "legit_pred_all", Tooltip = "Draws the dot for every enemy inside the FOV instead of only the aim target" })
    Pred:Toggle({ Name = "Aim at prediction", Flag = "legit_pred_aim", Tooltip = "Aims at the solved intercept point (full lead and drop) instead of the strength-limited lead below" })
    Master:Toggle({ Name = "Only while aiming down sights", Flag = "legit_ads" })
    Master:Toggle({ Name = "Only while shooting", Flag = "legit_shooting" })
    Master:Toggle({ Name = "Aim from barrel", Flag = "legit_barrel", Default = true, Tooltip = "Uses the weapon's bullet origin and direction (as the game computes them) for visibility, prediction and aiming; the camera is still the only thing that moves" })
    Master:Dropdown({ Name = "Hitbox priority", Flag = "legit_priority", Items = { "Closest", "Head", "Torso" }, Default = "Closest", Tooltip = "Closest picks the part nearest the crosshair; Head/Torso prefer that part when it qualifies" })
    Master:Dropdown({ Name = "Hitboxes", Flag = "legit_parts", Items = { "Head", "Torso", "Arms", "Legs" }, Multi = true, Default = { "Head", "Torso" } })
    Master:Dropdown({ Name = "Target by", Flag = "legit_target_by", Items = { "Crosshair", "Distance", "Lowest health" }, Default = "Crosshair" })

    local Smooth, Target, Predict = Aim:MultiSection({ Name = "Aim tuning", Sections = { "Smoothing", "Target", "Prediction" }, Icons = { "clock", "target", "zap" }, Column = 2 })
    Smooth:Slider({ Name = "Smoothing", Flag = "legit_smooth", Min = 1, Max = 60, Default = 12, Decimals = 1, Tooltip = "Higher is slower and looks more natural" })
    Smooth:Slider({ Name = "Max turn speed", Flag = "legit_speed", Min = 30, Max = 1440, Default = 420, Decimals = 1, Suffix = " deg/s" })
    Smooth:Slider({ Name = "Deadzone", Flag = "legit_deadzone", Min = 0, Max = 30, Default = 2, Decimals = 1, Suffix = " px", Tooltip = "No movement when the target is this close to the crosshair" })
    Smooth:Slider({ Name = "Wobble", Flag = "legit_noise", Min = 0, Max = 3, Default = 0.25, Decimals = 0.01, Suffix = " deg", Tooltip = "Small random drift on the aim point" })
    Smooth:Slider({ Name = "Wobble speed", Flag = "legit_noise_speed", Min = 0.2, Max = 6, Default = 1.4, Decimals = 0.1 })
    Target:Slider({ Name = "Max distance", Flag = "legit_dist", Min = 50, Max = 1500, Default = 600, Decimals = 1, Suffix = " studs" })
    Target:Toggle({ Name = "Sticky target", Flag = "legit_sticky", Default = true, Tooltip = "Stays on the locked player until you release the key or they die" })
    Target:Slider({ Name = "Switch delay", Flag = "legit_switch", Min = 0, Max = 500, Default = 120, Decimals = 1, Suffix = " ms", Tooltip = "Minimum time between target changes" })
    Target:Slider({ Name = "Reaction delay", Flag = "legit_react", Min = 0, Max = 400, Default = 60, Decimals = 1, Suffix = " ms" })
    Predict:Toggle({ Name = "Bullet drop", Flag = "legit_drop", Default = true, Tooltip = "Aims higher by the fall of the bullet, from the weapon's bullet speed and the game's gravity" })
    Predict:Toggle({ Name = "Moving targets", Flag = "legit_move", Default = true, Tooltip = "Leads the target by its speed times the bullet's travel time" })
    Predict:Slider({ Name = "Strength", Flag = "legit_strength", Min = 0, Max = 1.5, Default = 1, Decimals = 0.01 })
    Predict:Slider({ Name = "Max lead", Flag = "legit_maxlead", Min = 0, Max = 40, Default = 14, Decimals = 0.1, Suffix = " studs" })

    local Fov = Aim:Section({ Name = "FOV", Column = 3, Icon = "scan" })
    Fov:Toggle({ Name = "Draw FOV circle", Flag = "legit_fov_draw", Default = true }):Colorpicker({ Name = "Circle", Flag = "legit_fov_color", Default = WHITE, Alpha = 0 })
    Fov:Toggle({ Name = "Filled", Flag = "legit_fov_fill" }):Colorpicker({ Name = "Fill", Flag = "legit_fov_fill_color", Default = WHITE, Alpha = 0.92 })
    Fov:Toggle({ Name = "Locked colour", Flag = "legit_fov_lock", Default = true, Tooltip = "The circle changes colour while a target is held" }):Colorpicker({ Name = "Locked", Flag = "legit_fov_lock_color", Default = Color3.fromRGB(255, 80, 80), Alpha = 0 })
    Fov:Toggle({ Name = "Attach to barrel", Flag = "legit_fov_barrel", Tooltip = "Centres the circle on the weapon barrel instead of the screen centre" })
    Fov:Dropdown({ Name = "Attach point", Flag = "legit_fov_attach", Items = { "Aim hit", "Muzzle" }, Default = "Aim hit", Tooltip = "Aim hit is where the barrel is pointing; Muzzle is the barrel tip" })
    Fov:Slider({ Name = "Barrel distance", Flag = "barrel_distance", Min = 50, Max = 1000, Default = 300, Decimals = 1, Suffix = " studs", Tooltip = "Convergence distance of the Aim hit point along the barrel" })
    Fov:Slider({ Name = "Radius", Flag = "legit_fov", Min = 10, Max = 800, Default = 120, Decimals = 1, Suffix = " px" })
    Fov:Slider({ Name = "Thickness", Flag = "legit_fov_thick", Min = 1, Max = 4, Default = 1, Decimals = 0.1, Suffix = " px" })
    Fov:Toggle({ Name = "Dynamic radius", Flag = "legit_fov_dynamic", Tooltip = "The radius grows while scoped: Radius x (unscoped FOV / current FOV) ^ scale, up to 4x or half the screen height, so the circle keeps the same angular coverage as the view zooms in" })
    Fov:Slider({ Name = "Zoom FOV scale", Flag = "legit_fov_zoom", Min = 0, Max = 2, Default = 1, Decimals = 0.01, Suffix = "x", Tooltip = "Exponent on the zoom ratio; 1 keeps the angular coverage, 0 ignores zoom" })
    Fov:Slider({ Name = "Blend speed", Flag = "legit_fov_speed", Min = 2, Max = 30, Default = 10, Decimals = 0.1 })
    Fov:Toggle({ Name = "Target line", Flag = "legit_snapline", Tooltip = "A line from the crosshair to the aimed body part" }):Colorpicker({ Name = "Line", Flag = "legit_snapline_color", Default = Color3.fromRGB(255, 80, 80), Alpha = 0 })

    local Info = Aim:Section({ Name = "Status", Column = 3, Icon = "info" })
    Status.core = Info:Label({ Name = "Core: " .. tostring(Game.summary) })
    Status.weapon = Info:Label({ Name = "Weapon: none" })
    Status.target = Info:Label({ Name = "Target: none" })
    Status.recoil = Info:Label({ Name = "Recoil: 0.0 / 0.0" })
    Info:Button({ Name = "Reload core", Callback = function()
        Game.load()
        Game.hookNetwork()
        Feedback.hook()
        Nades.hook()
        Status.core:SetText("Core: " .. tostring(Game.summary))
        pcall(function() Library:Notify("Core " .. tostring(Game.summary), 4) end)
    end })

    local Sil = Subs["Silent Aim"]
    local SilBox = Sil:Section({ Name = "Silent aim", Column = 1, Icon = "crosshair" })
    SilBox:Toggle({ Name = "Enabled", Flag = "legit_silent", Tooltip = "Redirects your own bullets (client bullet and the newbullets packet) at the target without moving the camera or weapon. Risk: the server sees shots that do not match your view direction" })
    SilBox:Slider({ Name = "Hit chance", Flag = "legit_silent_chance", Min = 1, Max = 100, Default = 100, Decimals = 1, Suffix = "%", Tooltip = "Chance that a shot is redirected" })
    SilBox:Toggle({ Name = "Team check", Flag = "legit_silent_team", Default = true, Tooltip = "Only enemies are targeted" })
    SilBox:Toggle({ Name = "Visible check", Flag = "legit_silent_visible", Default = true, Tooltip = "Only redirects to points with a clear line from the barrel, or walls the weapon can shoot through when wallbang is on" })
    local SilMulti = SilBox:Toggle({ Name = "Multipoint", Flag = "legit_silent_multi", Tooltip = "Tests several points per hitbox and redirects to the best visible one nearest the crosshair" }):Settings("Multipoint", 230)
    SilMulti:Slider({ Name = "Multipoint scale", Flag = "legit_silent_multi_scale", Min = 10, Max = 100, Default = 60, Decimals = 1, Suffix = "%", Tooltip = "How far from the hitbox centre the extra points sit" })
    SilMulti:Slider({ Name = "Max points", Flag = "legit_silent_multi_max", Min = 1, Max = 9, Default = 5, Decimals = 1, Tooltip = "Points tested per body part (head up to 7, torso up to 9, limbs up to 3)" })
    SilMulti:Toggle({ Name = "Show points", Flag = "legit_silent_multi_show", Tooltip = "Small dots on the points tested for your last redirected shot" })
    pickColor(SilMulti, "Chosen point", "legit_silent_multi_color", Color3.fromRGB(120, 255, 170))
    local SilWall = SilBox:Toggle({ Name = "Wallbang", Flag = "legit_silent_wallbang", Tooltip = "Also redirects to players behind walls that the equipped weapon can shoot through" }):Settings("Wallbang", 230)
    SilWall:Slider({ Name = "Penetration safety", Flag = "legit_silent_pen_safety", Min = 50, Max = 100, Default = 90, Decimals = 1, Suffix = "%", Tooltip = "Share of the weapon's penetration depth the walls may use" })
    SilBox:Toggle({ Name = "Bullet prediction", Flag = "legit_silent_pred", Tooltip = "Leads the target and compensates drop from bullet speed and the target's tracked velocity; off aims straight at the point" })
    SilBox:Slider({ Name = "Max distance", Flag = "legit_silent_dist", Min = 50, Max = 1500, Default = 600, Decimals = 1, Suffix = " studs" })
    local SilTarget = Sil:Section({ Name = "Silent targeting", Column = 2, Icon = "target" })
    SilTarget:Dropdown({ Name = "Hitbox priority", Flag = "legit_silent_priority", Items = { "Closest", "Head", "Torso" }, Default = "Closest", Tooltip = "Closest picks the part nearest the crosshair; Head/Torso prefer that part when it qualifies" })
    SilTarget:Dropdown({ Name = "Hitboxes", Flag = "legit_silent_parts", Items = { "Head", "Torso", "Arms", "Legs" }, Multi = true, Default = { "Head", "Torso" } })
    local SilFov = Sil:Section({ Name = "Silent FOV", Column = 3, Icon = "scan" })
    SilFov:Slider({ Name = "Radius", Flag = "legit_silent_fov", Min = 5, Max = 600, Default = 90, Decimals = 1, Suffix = " px", Tooltip = "Radius around the silent FOV centre (screen centre, or the barrel when attached) where a target can be redirected to" })
    SilFov:Toggle({ Name = "Draw FOV circle", Flag = "legit_silent_fov_draw", Default = true }):Colorpicker({ Name = "Circle", Flag = "legit_silent_fov_color", Default = Color3.fromRGB(255, 200, 80), Alpha = 0 })
    SilFov:Toggle({ Name = "Filled", Flag = "legit_silent_fov_fill" }):Colorpicker({ Name = "Fill", Flag = "legit_silent_fov_fill_color", Default = Color3.fromRGB(255, 200, 80), Alpha = 0.92 })
    SilFov:Toggle({ Name = "Locked colour", Flag = "legit_silent_fov_lock", Default = true, Tooltip = "The circle changes colour briefly after a redirected shot" }):Colorpicker({ Name = "Locked", Flag = "legit_silent_fov_lock_color", Default = Color3.fromRGB(255, 80, 80), Alpha = 0 })
    SilFov:Toggle({ Name = "Attach to barrel", Flag = "legit_silent_fov_barrel", Tooltip = "Centres the circle and the silent target search on the weapon barrel instead of the screen centre" })
    SilFov:Dropdown({ Name = "Attach point", Flag = "legit_silent_fov_attach", Items = { "Aim hit", "Muzzle" }, Default = "Aim hit", Tooltip = "Aim hit is where the barrel is pointing (distance from Aim assist > FOV > Barrel distance); Muzzle is the barrel tip" })
    SilFov:Slider({ Name = "Thickness", Flag = "legit_silent_fov_thick", Min = 1, Max = 4, Default = 1, Decimals = 0.1, Suffix = " px" })
    SilFov:Toggle({ Name = "Dynamic radius", Flag = "legit_silent_fov_dynamic", Tooltip = "The radius grows while scoped: Silent FOV x (unscoped FOV / current FOV) ^ scale, up to 4x or half the screen height" })
    SilFov:Slider({ Name = "Zoom FOV scale", Flag = "legit_silent_fov_zoom", Min = 0, Max = 2, Default = 1, Decimals = 0.01, Suffix = "x", Tooltip = "Exponent on the zoom ratio; 1 keeps the angular coverage, 0 ignores zoom" })
    SilFov:Slider({ Name = "Blend speed", Flag = "legit_silent_fov_speed", Min = 2, Max = 30, Default = 10, Decimals = 0.1 })

    local Trig = Subs["Trigger Bot"]
    local TriggerBox = Trig:Section({ Name = "Trigger bot", Column = 1, Icon = "zap" })
    TriggerBox:Toggle({ Name = "Enabled", Flag = "trig_on", Tooltip = "Fires when the crosshair is on an enemy hitbox" }):Keybind({ Name = "Trigger key", Flag = "trig_key", Default = "None", Mode = "Always" })
    TriggerBox:Toggle({ Name = "Visible only", Flag = "trig_visible", Default = true })
    TriggerBox:Toggle({ Name = "Only while aiming down sights", Flag = "trig_ads" })
    TriggerBox:Dropdown({ Name = "Hitboxes", Flag = "trig_parts", Items = { "Head", "Torso", "Arms", "Legs" }, Multi = true, Default = { "Head", "Torso" } })
    TriggerBox:Slider({ Name = "Hitbox size", Flag = "trig_scale", Min = 0.4, Max = 1.6, Default = 1, Decimals = 0.01, Suffix = "x" })
    local Timing = Trig:Section({ Name = "Timing", Column = 2, Icon = "clock" })
    Timing:Slider({ Name = "Max distance", Flag = "trig_dist", Min = 50, Max = 1500, Default = 400, Decimals = 1, Suffix = " studs" })
    Timing:Slider({ Name = "Delay", Flag = "trig_delay", Min = 0, Max = 300, Default = 40, Decimals = 1, Suffix = " ms", Tooltip = "How long the crosshair must stay on the target before firing" })
    Timing:Slider({ Name = "Hold", Flag = "trig_hold", Min = 20, Max = 500, Default = 70, Decimals = 1, Suffix = " ms", Tooltip = "How long the button stays down; longer holds fire more shots on automatics" })
    Timing:Slider({ Name = "Cooldown", Flag = "trig_cool", Min = 0, Max = 500, Default = 90, Decimals = 1, Suffix = " ms" })

    local Rcs = Subs["Recoil"]
    local RcsBox = Rcs:Section({ Name = "Recoil control", Column = 1, Icon = "target" })
    RcsBox:Toggle({ Name = "Enabled", Flag = "rcs_on", Tooltip = "Cancels the recoil of each shot by tracking where the barrel points relative to your view" }):Keybind({ Name = "Recoil key", Flag = "rcs_key", Default = "None", Mode = "Always" })
    RcsBox:Toggle({ Name = "Use barrel direction", Flag = "rcs_barrel", Default = true, Tooltip = "Compensates the barrel's own recoil, shake and sway; off falls back to the camera recoil springs only" })
    RcsBox:Slider({ Name = "Vertical control", Flag = "rcs_v", Min = 0, Max = 100, Default = 70, Decimals = 1, Suffix = "%" })
    RcsBox:Slider({ Name = "Horizontal control", Flag = "rcs_h", Min = 0, Max = 100, Default = 40, Decimals = 1, Suffix = "%" })
    RcsBox:Toggle({ Name = "Hipfire too", Flag = "rcs_hip", Default = true, Tooltip = "Off: only controls recoil while aiming down sights" })
    RcsBox:Slider({ Name = "Variation", Flag = "rcs_human", Min = 0, Max = 40, Default = 10, Decimals = 1, Suffix = "%", Tooltip = "Varies the strength over time so the spray does not look machine perfect" })
end

do
    Pages.Rage:Section({ Name = "Rage", Column = 1, Icon = "swords" }):Label({ Name = "Coming soon" })
    local Fun = Pages.Misc:Section({ Name = "Fun", Column = 1, Icon = "shapes" })
    local Pc = Fun:Toggle({ Name = "PhantomCam", Flag = "misc_phantomcam", Tooltip = "Body cam: the view follows where the weapon's barrel points" })
        :Keybind({ Name = "PhantomCam key", Flag = "misc_phantomcam_key", Default = "None", Mode = "Toggle", Sync = true })
        :Settings("PhantomCam", 230)
    Pc:Slider({ Name = "Strength", Flag = "misc_phantomcam_strength", Min = 0, Max = 5, Default = 2.5, Decimals = 0.01, Tooltip = "Barrel: 0 leaves the view alone, 1 points it where the barrel points, above 1 exaggerates it. World character: scales the head motion" })
    Pc:Slider({ Name = "Sway", Flag = "misc_phantomcam_sway", Min = 0, Max = 5, Default = 1, Decimals = 0.01, Tooltip = "Tilts the view with the viewmodel's motion (walking, sprinting, reloading, recoil)" })
    Pc:Slider({ Name = "Smoothing", Flag = "misc_phantomcam_smooth", Min = 0, Max = 1, Default = 0, Decimals = 0.01 })
    Pc:Slider({ Name = "Position follow", Flag = "misc_phantomcam_position", Min = 0, Max = 1, Default = 0, Decimals = 0.01, Tooltip = "Moves the camera toward the weapon's barrel" })
    Pc:Toggle({ Name = "Roll", Flag = "misc_phantomcam_roll", Tooltip = "Also follows the barrel's roll" })
    Pc:Toggle({ Name = "Only while aiming", Flag = "misc_phantomcam_aiming" })
    Pc:Toggle({ Name = "Disable while scoped", Flag = "misc_phantomcam_noscope" })
    Pc:Dropdown({ Name = "Mode", Flag = "misc_phantomcam_mode", Items = { "Barrel", "World character" }, Default = "Barrel", Tooltip = "Barrel follows the weapon's aim; World character puts the camera at your character's head" })
    Pc:Toggle({ Name = "Hide viewmodel", Flag = "misc_phantomcam_viewmodel", Default = true, Tooltip = "World character mode: hides the first-person arms and weapon" })
    Pc:Toggle({ Name = "Hide hat/head", Flag = "misc_phantomcam_hat", Default = true, Tooltip = "World character mode: hides your character's head and hat so they do not block the view" })
    Pc:Slider({ Name = "Forward offset", Flag = "misc_phantomcam_forward", Min = 0, Max = 2, Default = 0.5, Decimals = 0.01, Suffix = " studs" })
    Pc:Slider({ Name = "Camera FOV", Flag = "misc_phantomcam_fov", Min = 0, Max = 120, Default = 0, Decimals = 1, Tooltip = "0 keeps the game's FOV" })
    Pc:Toggle({ Name = "Debug", Flag = "misc_phantomcam_debug", Tooltip = "Prints a PhantomCam status line to the console once per second" })

    local Kn = Pages.Misc:Section({ Name = "Knife unlock", Column = 2, Icon = "swords" })
    Kn:Toggle({ Name = "Use selected knife", Flag = "misc_knife_on", Tooltip = "Spawns you with the knife and skin below. Client side only: the server still has your real knife, no loadout packet is sent" })
    Kn:Dropdown({ Name = "Knife", Flag = "misc_knife", Items = Knife.items(), Default = "Default", Tooltip = "Every melee weapon in the game's content; Default keeps your equipped knife" })
    Kn:Dropdown({ Name = "Knife skin", Flag = "misc_knife_skin", Items = Knife.skinItems(), Default = "Default", Tooltip = "Default keeps your knife's own skin, None strips it" })
    Kn:Toggle({ Name = "Unlock all knives", Flag = "misc_knife_unlock", Tooltip = "The loadout menu treats every knife as owned. Equipping an unowned knife there stays local: the packet that would tell the server is dropped" })
    Kn:Button({ Name = "Refresh knife list", Callback = function()
        Knife.synced = false
        Knife.syncUI()
    end })
    Kn:Label({ Name = "Applies on your next spawn" })
end

do
    local function pickColor(popup, label, flagName, default, alpha)
        popup:Label({ Name = label }):Colorpicker({ Name = label, Flag = flagName, Default = default, Alpha = alpha or 0 })
    end

    local LocalSub = ESPSubs.Local
    local Chams = LocalSub:Section({ Name = "Viewmodel chams", Column = 1, Icon = "palette" })
    local function chams(label, cat, tooltip, tint)
        local base = "local_" .. cat
        local popup = Chams:Toggle({ Name = label, Flag = base, Tooltip = tooltip }):Settings(label, 230)
        pickColor(popup, "Colour", base .. "_color", tint)
        popup:Dropdown({ Name = "Material", Flag = base .. "_mat", Items = Local.materials, Default = "ForceField" })
        popup:Dropdown({ Name = "Texture", Flag = base .. "_tex", Items = Local.names, Default = "None", Tooltip = "Pattern drawn by the ForceField material" })
        popup:Slider({ Name = "Reflectance", Flag = base .. "_refl", Min = 0, Max = 1, Default = 0, Decimals = 0.01 })
        if cat == "gun" then popup:Toggle({ Name = "Hide scope glass", Flag = "local_gun_noglass", Default = true, Tooltip = "Makes sight lenses fully clear; they are never recoloured either way" }) end
    end
    chams("Arm chams", "arm", "First-person skin parts of your arms (SkinTone)", Color3.fromRGB(255, 120, 160))
    chams("Glove chams", "glove", "First-person arm parts that are neither sleeve nor skin: gloves and accessories", Color3.fromRGB(120, 200, 255))
    chams("Clothes chams", "cloth", "First-person sleeves", Color3.fromRGB(170, 120, 255))
    chams("Gun chams", "gun", "The weapon in your hands: every part of the viewmodel weapon", Color3.fromRGB(120, 255, 170))

    local Remove = LocalSub:Section({ Name = "Remove parts", Column = 2, Icon = "eye" })
    Remove:Toggle({ Name = "Remove left arm", Flag = "local_rm_larm", Tooltip = "Hides the left arm's skin; sleeve and glove stay" })
    Remove:Toggle({ Name = "Remove right arm", Flag = "local_rm_rarm", Tooltip = "Hides the right arm's skin; sleeve and glove stay" })
    Remove:Toggle({ Name = "Remove left sleeve", Flag = "local_rm_lsleeve" })
    Remove:Toggle({ Name = "Remove right sleeve", Flag = "local_rm_rsleeve" })
    Remove:Toggle({ Name = "Remove gloves", Flag = "local_rm_gloves", Tooltip = "Both hands' gloves and accessories" })
    Remove:Toggle({ Name = "Remove gun", Flag = "local_rm_gun", Tooltip = "Hides the viewmodel weapon" })

    local Changer = LocalSub:Section({ Name = "Viewmodel changer", Column = 3, Icon = "camera" })
    local Offset = Changer:Toggle({ Name = "Viewmodel offset", Flag = "local_vm", Tooltip = "Moves and tilts the weapon and arms after the game positions them; bullets and your aim are not affected" }):Settings("Viewmodel offset", 230)
    Offset:Slider({ Name = "X (right)", Flag = "local_vm_x", Min = -2, Max = 2, Default = 0, Decimals = 0.01, Suffix = " studs" })
    Offset:Slider({ Name = "Y (up)", Flag = "local_vm_y", Min = -2, Max = 2, Default = 0, Decimals = 0.01, Suffix = " studs" })
    Offset:Slider({ Name = "Z (forward)", Flag = "local_vm_z", Min = -2, Max = 2, Default = 0, Decimals = 0.01, Suffix = " studs" })
    Offset:Slider({ Name = "Pitch", Flag = "local_vm_pitch", Min = -180, Max = 180, Default = 0, Decimals = 1, Suffix = " deg" })
    Offset:Slider({ Name = "Yaw", Flag = "local_vm_yaw", Min = -180, Max = 180, Default = 0, Decimals = 1, Suffix = " deg" })
    Offset:Slider({ Name = "Roll", Flag = "local_vm_roll", Min = -180, Max = 180, Default = 0, Decimals = 1, Suffix = " deg" })
    Offset:Toggle({ Name = "Fade out while aiming", Flag = "local_vm_aim", Tooltip = "The offset shrinks to nothing as you aim down sights" })

    local Assets = LocalSub:Section({ Name = "Viewmodel assets", Column = 3, Icon = "list" })
    Assets:Button({ Name = "Print arm assets to console", Callback = function()
        local lines, cap = {}, 200
        local function add(text)
            if #lines < cap then lines[#lines + 1] = text elseif #lines == cap then lines[cap + 1] = "... (truncated)" end
        end
        local function tree(object, depth, maxDepth)
            local okKids, kids = pcall(function() return object:GetChildren() end)
            if not (okKids and type(kids) == "table") then return end
            for _, child in ipairs(kids) do
                local okName, text = pcall(function() return string.rep("  ", depth) .. tostring(child.Name) .. " [" .. tostring(child.ClassName) .. "]" end)
                add(okName and text or string.rep("  ", depth) .. "?")
                if depth < maxDepth then tree(child, depth + 1, maxDepth) end
            end
        end
        add("== ReplicatedStorage.Character (depth 3) ==")
        pcall(function()
            local folder = game:GetService("ReplicatedStorage"):FindFirstChild("Character")
            if folder then tree(folder, 1, 3) else add("  (not found)") end
        end)
        add("== Current viewmodel arms ==")
        pcall(function()
            local interface = Game.mods.CharacterInterface
            local character = interface and interface.getCharacterObject()
            local left, right = character.getArmModels(character)
            for label, model in pairs({ Left = left, Right = right }) do
                if model then
                    add(label .. ": " .. tostring(model.Name) .. " [" .. tostring(model.ClassName) .. "]")
                    for _, object in ipairs(model:GetDescendants()) do add("  " .. tostring(object.Name) .. " [" .. tostring(object.ClassName) .. "]") end
                end
            end
            if not (left or right) then add("  (no arm models)") end
        end)
        print(table.concat(lines, "\n"))
    end })
end

do
    local Subs = ESPSubs

    local function pickColor(popup, label, flagName, default, alpha)
        popup:Label({ Name = label }):Colorpicker({ Name = label, Flag = flagName, Default = default, Alpha = alpha or 0 })
    end

    local function buildTeam(sub, prefix, label, tint, hidden, shared)
        local function key(name) return prefix .. name end
        local Main = sub:Section({ Name = label .. " ESP", Column = 1, Icon = "eye" })
        local Body = sub:Section({ Name = label .. " body", Column = 2, Icon = "user" })
        local Marks = sub:Section({ Name = label .. " indicators", Column = 3, Icon = "target" })
        local On = Main:Toggle({ Name = "Enabled", Flag = key("on"), Tooltip = "Master switch for this tab" }):Settings("Range", 230)
        On:Slider({ Name = "Max distance", Flag = key("dist"), Min = 50, Max = 3000, Default = 1500, Decimals = 1, Suffix = " studs", Tooltip = "Players further away are not drawn" })

        local Box = Main:Toggle({ Name = "Boxes", Flag = key("box") }):Settings("Boxes", 230)
        pickColor(Box, "Box", key("box_color"), tint)
        Box:Toggle({ Name = "Filled", Flag = key("fill") })
        pickColor(Box, "Fill", key("fill_color"), tint, 0.85)
        if shared then
            Box:Dropdown({ Name = "Box style", Flag = "esp_box_style", Items = { "Corners", "Full" }, Default = "Corners" })
            Box:Dropdown({ Name = "Box mode", Flag = "esp_box_mode", Items = { "Static", "Dynamic" }, Default = "Static", Tooltip = "Static is a fixed size box; Dynamic wraps the body parts" })
            Box:Toggle({ Name = "Gradient fill", Flag = "esp_fill_gradient", Default = true, Tooltip = "Blends the fill into the second colour toward the feet" })
            pickColor(Box, "Fill end", "esp_fill_color2", Color3.fromRGB(20, 20, 20))
            Box:Toggle({ Name = "Outlines", Flag = "esp_outline", Default = true, Tooltip = "Dark outline on the box, dot and arrows" })
        end

        local Name = Main:Toggle({ Name = "Names", Flag = key("name") }):Settings("Names", 230)
        pickColor(Name, "Name", key("name_color"), WHITE)
        if shared then
            Name:Dropdown({ Name = "Font", Flag = "esp_font", Items = { "Plex", "UI", "System", "Monospace" }, Default = "Plex" })
            Name:Slider({ Name = "Size", Flag = "esp_text", Min = 10, Max = 20, Default = 13, Decimals = 1, Suffix = " px" })
            Name:Dropdown({ Name = "Text case", Flag = "esp_case", Items = { "Normal", "lower", "UPPER" }, Default = "Normal" })
        end

        local Hp = Main:Toggle({ Name = "Health", Flag = key("hp") }):Settings("Health", 230)
        pickColor(Hp, "Low health", key("hp_low"), Color3.fromRGB(255, 60, 60))
        pickColor(Hp, "Full health", key("hp_full"), Color3.fromRGB(80, 255, 120))
        Hp:Toggle({ Name = "Health number", Flag = key("hp_num") })
        pickColor(Hp, "Number", key("hp_num_color"), WHITE)
        if shared then
            Hp:Dropdown({ Name = "Health bar side", Flag = "esp_hp_side", Items = { "Left", "Right" }, Default = "Left" })
            pickColor(Hp, "Mid health", "esp_hp_mid", Color3.fromRGB(255, 210, 60))
        end

        local Dist = Main:Toggle({ Name = "Distance", Flag = key("show_dist") }):Settings("Distance", 200)
        pickColor(Dist, "Distance", key("show_dist_color"), Color3.fromRGB(190, 190, 205))

        local Weapon = Main:Toggle({ Name = "Weapon", Flag = key("weapon") }):Settings("Weapon", 200)
        pickColor(Weapon, "Weapon", key("weapon_color"), Color3.fromRGB(205, 205, 215))
        if shared then Weapon:Dropdown({ Name = "Weapon display", Flag = "esp_weapon_display", Items = { "Text", "Icon", "Both" }, Default = "Text", Tooltip = "Icon draws the weapon's silhouette (downloaded on first use) and falls back to text until it loads" }) end

        local Skel = Body:Toggle({ Name = "Skeleton", Flag = key("skeleton") }):Settings("Skeleton", 200)
        pickColor(Skel, "Skeleton", key("skeleton_color"), WHITE)
        if shared then
            Skel:Slider({ Name = "Skeleton thickness", Flag = "esp_skel_thick", Min = 1, Max = 4, Default = 1, Decimals = 0.1, Suffix = " px" })
            Skel:Toggle({ Name = "Outline", Flag = "esp_skeleton_outline", Default = true, Tooltip = "Thin dark line under the bones" })
            Skel:Toggle({ Name = "Joint dots", Flag = "esp_skeleton_joints", Tooltip = "Dots at the shoulders, elbows, hands, hips, knees and feet" })
        end

        local Dot = Body:Toggle({ Name = "Head dot", Flag = key("dot") }):Settings("Head dot", 200)
        pickColor(Dot, "Head dot", key("dot_color"), tint)

        local Trace = Marks:Toggle({ Name = "Snaplines", Flag = key("tracer"), Tooltip = "Line from the screen to the player's feet" }):Settings("Snaplines", 200)
        pickColor(Trace, "Snapline", key("tracer_color"), tint)
        if shared then
            Trace:Dropdown({ Name = "Snapline origin", Flag = "esp_tracer_origin", Items = { "Bottom", "Center", "Top", "Mouse" }, Default = "Bottom" })
            Trace:Slider({ Name = "Snapline thickness", Flag = "esp_tracer_thick", Min = 1, Max = 4, Default = 1, Decimals = 0.1, Suffix = " px" })
        end

        local View = Marks:Toggle({ Name = "View direction", Flag = key("view"), Tooltip = "Where the player is looking, drawn from the head" }):Settings("View direction", 200)
        pickColor(View, "View", key("view_color"), Color3.fromRGB(255, 220, 60))
        if shared then View:Slider({ Name = "View line length", Flag = "esp_view_len", Min = 2, Max = 30, Default = 8, Decimals = 0.1, Suffix = " studs" }) end

        local Arrow = Marks:Toggle({ Name = "Arrows", Flag = key("oov"), Tooltip = "Arrows pointing at players you cannot see on screen" }):Settings("Arrows", 230)
        pickColor(Arrow, "Arrow", key("oov_color"), tint)
        if shared then
            Arrow:Slider({ Name = "Arrow size", Flag = "oov_size", Min = 8, Max = 32, Default = 14, Decimals = 1, Suffix = " px" })
            Arrow:Slider({ Name = "Arrow distance", Flag = "oov_radius", Min = 5, Max = 100, Default = 40, Decimals = 1, Suffix = " %", Tooltip = "Distance from the screen centre; 100 is the edge" })
        end

        local Cham = Body:Toggle({ Name = "Chams", Flag = key("chams"), Tooltip = "Adornment chams on each body part" }):Settings("Chams", 230)
        pickColor(Cham, "Visible", key("cham_vis"), tint, 0.5)
        pickColor(Cham, "Behind walls", key("cham_hid"), hidden, 0.5)
        if shared then
            Cham:Dropdown({ Name = "Mode", Flag = "cham_mode", Items = { "Through walls", "Visible only" }, Default = "Through walls", Tooltip = "Through walls switches between the two colours by line of sight" })
            Cham:Slider({ Name = "Thickness", Flag = "cham_grow", Min = 0, Max = 1, Default = 0.1, Decimals = 0.01, Suffix = " studs" })
            Cham:Toggle({ Name = "Glow", Flag = "cham_glow", Tooltip = "Draws the visible layer on top, brighter and more opaque, so bloom picks it up" })
            Cham:Slider({ Name = "Glow strength", Flag = "cham_glow_size", Min = 1, Max = 2.5, Default = 1.75, Decimals = 0.01 })
            Cham:Toggle({ Name = "Bloom", Flag = "cham_bloom", Default = true, Tooltip = "Drives a bloom effect while the glow is on; the World bloom settings win if that is enabled" })
            Cham:Slider({ Name = "Bloom intensity", Flag = "cham_bloom_i", Min = 0, Max = 3, Default = 0.4, Decimals = 0.01 })
            Cham:Slider({ Name = "Bloom size", Flag = "cham_bloom_s", Min = 0, Max = 56, Default = 24, Decimals = 0.1 })
            Cham:Slider({ Name = "Bloom threshold", Flag = "cham_bloom_t", Min = 0, Max = 2, Default = 0.95, Decimals = 0.01 })
            Cham:Slider({ Name = "Head size", Flag = "cham_head_size", Min = 0.8, Max = 1.6, Default = 1.15, Decimals = 0.01 })
            Cham:Toggle({ Name = "Round head", Flag = "cham_round_head", Default = true })
            Cham:Toggle({ Name = "Remove armor/gear", Flag = "chams_remove_gear", Default = true, Tooltip = "Hides helmets, armor and other cosmetics on players with chams so the body is covered cleanly; restored when chams stop" })
        end
        if shared then
            local Vis = Body:Toggle({ Name = "Colour by visibility", Flag = "esp_vis", Tooltip = "Box, skeleton, snapline, dot, view line and arrows use the popup colours" }):Settings("Visibility colours", 200)
            pickColor(Vis, "Visible", "esp_vis_color", Color3.fromRGB(80, 255, 120))
            pickColor(Vis, "Behind walls", "esp_occ_color", Color3.fromRGB(255, 80, 80))
            Body:Toggle({ Name = "Ignore glass", Flag = "vis_ignore_glass", Default = true, Tooltip = "Bullets pass through glass, so visibility checks, aimbot, triggerbot and grenade prediction see through it" })
        end
    end
    buildTeam(Subs.Enemies, "esp_enemy_", "Enemy", Color3.fromRGB(255, 70, 90), Color3.fromRGB(170, 60, 255), true)
    buildTeam(Subs.Teammates, "esp_team_", "Teammate", Color3.fromRGB(90, 220, 130), Color3.fromRGB(60, 150, 255))

    local Other = Subs.Other
    local World = Other:Section({ Name = "Items and grenades", Column = 1, Icon = "package" })
    local Item = World:Toggle({ Name = "Dropped items", Flag = "item_drops" }):Settings("Dropped items", 230)
    pickColor(Item, "Weapons", "item_drops_color", Color3.fromRGB(255, 190, 60))
    Item:Dropdown({ Name = "Display", Flag = "item_drops_display", Items = { "Text", "Icon", "Both" }, Default = "Text", Tooltip = "Icon draws the weapon silhouette, with the distance under it" })
    Item:Slider({ Name = "Max distance", Flag = "item_dist", Min = 20, Max = 1500, Default = 300, Decimals = 1, Suffix = " studs" })

    local Warn = World:Toggle({ Name = "Grenade warning", Flag = "nade_on", Tooltip = "Tracks enemy grenades and your own from the game's throw event" }):Settings("Grenade warning", 230)
    Warn:Toggle({ Name = "Enemy grenades", Flag = "nade_enemy", Default = true })
    pickColor(Warn, "Enemy", "nade_enemy_color", Color3.fromRGB(255, 90, 60))
    Warn:Toggle({ Name = "My grenades", Flag = "nade_own", Default = true })
    pickColor(Warn, "Mine", "nade_own_color", Color3.fromRGB(120, 255, 170))
    pickColor(Warn, "Blast ring", "nade_ring_color", Color3.fromRGB(255, 220, 60))
    pickColor(Warn, "Blast ring (lethal)", "nade_ring_lethal_color", Color3.fromRGB(255, 60, 60))
    Warn:Toggle({ Name = "Fuse timer", Flag = "nade_timer", Default = true })
    Warn:Toggle({ Name = "Flight path", Flag = "nade_path", Default = true, Tooltip = "The path from the server's replicated grenade nodes, up to the blast" })
    Warn:Slider({ Name = "Max distance", Flag = "nade_dist", Min = 50, Max = 1500, Default = 400, Decimals = 1, Suffix = " studs" })

    local Blast = World:Toggle({ Name = "Damage estimate", Flag = "nade_dmg", Default = true, Tooltip = "Torso damage to you at the blast point from the grenade's damage graph, 0 behind map cover" }):Settings("Damage estimate", 200)
    pickColor(Blast, "Safe", "nade_safe_color", Color3.fromRGB(90, 255, 130))
    pickColor(Blast, "Danger", "nade_danger_color", Color3.fromRGB(255, 60, 60))
    Blast:Toggle({ Name = "Blast radius ring", Flag = "nade_ring", Default = true, Tooltip = "Ground ring at the damage range of the grenade" })

    local Pred = World:Toggle({ Name = "Predict throw", Flag = "nade_predict", Tooltip = "While the pin is pulled, draws the predicted path, landing and fuse left" }):Settings("Throw predictor", 200)
    pickColor(Pred, "Path", "nade_predict_color", Color3.fromRGB(120, 200, 255))
    Pred:Toggle({ Name = "Show before pin pull", Flag = "nade_predict_pre", Tooltip = "Dimmer preview while the pin is still in" })
    Pred:Toggle({ Name = "Bounce markers", Flag = "nade_predict_bounce", Default = true })

    local Dead = Other:Section({ Name = "Corpses", Column = 2, Icon = "user" })
    local Cham = Dead:Toggle({ Name = "Corpse chams", Flag = "chams_dead", Tooltip = "Restyles the ragdoll left behind when a player dies by changing its material, colour and transparency. The game removes corpses after about 30 seconds" }):Settings("Corpse chams", 260)
    Cham:Toggle({ Name = "Enemy corpses", Flag = "chams_dead_enemy", Default = true, Tooltip = "Corpses whose owner could not be matched count as enemy" })
    pickColor(Cham, "Enemy", "chams_dead_enemy_color", Color3.fromRGB(255, 70, 90))
    Cham:Toggle({ Name = "Team corpses", Flag = "chams_dead_team" })
    pickColor(Cham, "Team", "chams_dead_team_color", Color3.fromRGB(90, 220, 130))
    Cham:Toggle({ Name = "My corpse", Flag = "chams_dead_local" })
    pickColor(Cham, "Mine", "chams_dead_local_color", Color3.fromRGB(120, 200, 255))
    Cham:Dropdown({ Name = "Material", Flag = "chams_dead_mat", Items = Local.materials, Default = "ForceField" })
    Cham:Dropdown({ Name = "Texture", Flag = "chams_dead_tex", Items = Local.names, Default = "None", Tooltip = "Pattern drawn by the ForceField material" })
    Cham:Slider({ Name = "Reflectance", Flag = "chams_dead_refl", Min = 0, Max = 1, Default = 0, Decimals = 0.01 })
    Cham:Toggle({ Name = "Hide clothing/accessories", Flag = "chams_dead_hide", Tooltip = "Hides everything on the corpse except the six body parts" })
    Cham:Slider({ Name = "Fade out time", Flag = "chams_dead_fade", Min = 0, Max = 15, Default = 0, Decimals = 0.1, Suffix = " s", Tooltip = "Fades the corpse out over the last seconds before the game removes it; 0 is off" })

    local Kill = Other:Section({ Name = "Kill effects", Column = 3, Icon = "flame" })
    local Fx = Kill:Toggle({ Name = "Kill effects", Flag = "kill_fx", Tooltip = "Plays local effects on the corpse of players you kill (from the game's death event). Visual only, nothing is sent to the server" }):Settings("Kill effects", 260)
    Fx:Dropdown({ Name = "Effects", Flag = "kill_fx_list", Items = KillFx.names, Multi = true, Default = { "Dissolve", "Lightning" } })
    pickColor(Fx, "Colour", "kill_fx_color", Color3.fromRGB(102, 204, 255))
    pickColor(Fx, "Secondary", "kill_fx_color2", Color3.fromRGB(235, 248, 255))
    Fx:Slider({ Name = "Intensity", Flag = "kill_fx_int", Min = 0.3, Max = 3, Default = 1, Decimals = 0.1 })
    Fx:Slider({ Name = "Duration", Flag = "kill_fx_dur", Min = 0.5, Max = 6, Default = 2.5, Decimals = 0.1, Suffix = " s", Tooltip = "Length of Dissolve and Pillar" })
    Fx:Slider({ Name = "Screen flash only near", Flag = "kill_fx_flash_dist", Min = 20, Max = 500, Default = 150, Decimals = 1, Suffix = " studs" })
    Fx:Toggle({ Name = "Play sound", Flag = "kill_fx_sound" })
    Fx:Input({ Name = "Sound id", Flag = "kill_fx_sound_id", Placeholder = "rbxassetid or number" })
end

do
    local Subs = Pages.World:SubTabs({ { "Environment", "sun" }, { "Sky", "moon" }, { "Weather", "cloud" }, { "Effects", "palette" }, { "Camera", "camera" }, { "Feedback", "flame" } })

    local Env = Subs.Environment
    local function pickColor(popup, label, flagName, default, alpha)
        popup:Label({ Name = label }):Colorpicker({ Name = label, Flag = flagName, Default = default, Alpha = alpha or 0 })
    end

    local Light = Env:Section({ Name = "Lighting", Column = 1, Icon = "sun" })
    local Time = Light:Toggle({ Name = "Time of day", Flag = "world_time" }):Settings("Time of day", 230)
    Time:Slider({ Name = "Clock time", Flag = "world_time_v", Min = 0, Max = 24, Default = 14, Decimals = 0.1, Suffix = " h" })
    Time:Toggle({ Name = "Day / night cycle", Flag = "world_cycle", Tooltip = "Runs the clock continuously from the current time" })
    Time:Slider({ Name = "Cycle speed", Flag = "world_cycle_speed", Min = 0.05, Max = 6, Default = 0.5, Decimals = 0.05, Suffix = " h/s" })
    Light:Toggle({ Name = "Sun latitude", Flag = "world_lat", Tooltip = "Tilts the sun's path across the sky" }):Settings("Sun latitude", 230):Slider({ Name = "Latitude", Flag = "world_lat_v", Min = -80, Max = 80, Default = 20, Decimals = 1, Suffix = " deg" })
    Light:Toggle({ Name = "Brightness", Flag = "world_bright" }):Settings("Brightness", 230):Slider({ Name = "Brightness value", Flag = "world_bright_v", Min = 0, Max = 10, Default = 2, Decimals = 0.1 })
    Light:Toggle({ Name = "Exposure", Flag = "world_exposure" }):Settings("Exposure", 230):Slider({ Name = "Exposure value", Flag = "world_exposure_v", Min = -3, Max = 3, Default = 0, Decimals = 0.1 })
    local Ambient = Light:Toggle({ Name = "Ambient", Flag = "world_ambient" }):Settings("Ambient", 230)
    pickColor(Ambient, "Indoor", "world_ambient_in", Color3.fromRGB(150, 150, 170))
    pickColor(Ambient, "Outdoor", "world_ambient_out", Color3.fromRGB(170, 170, 190))
    local Shift = Light:Toggle({ Name = "Colour shift", Flag = "world_shift", Tooltip = "Tints the light that hits surfaces facing the sky (top) and the ground (bottom)" }):Settings("Colour shift", 230)
    pickColor(Shift, "Top", "world_shift_top", Color3.fromRGB(255, 170, 90))
    pickColor(Shift, "Bottom", "world_shift_bottom", Color3.fromRGB(60, 80, 140))
    local EnvLight = Light:Toggle({ Name = "Environment light", Flag = "world_env" }):Settings("Environment light", 230)
    EnvLight:Slider({ Name = "Diffuse", Flag = "world_env_diffuse", Min = 0, Max = 1, Default = 1, Decimals = 0.01 })
    EnvLight:Slider({ Name = "Specular", Flag = "world_env_specular", Min = 0, Max = 1, Default = 1, Decimals = 0.01 })

    local Quick = Env:Section({ Name = "Quick toggles", Column = 1, Icon = "zap" })
    Quick:Toggle({ Name = "Full bright", Flag = "world_fullbright", Tooltip = "Overrides lighting values while on" })
    Quick:Toggle({ Name = "No shadows", Flag = "world_noshadow" })
    Quick:Toggle({ Name = "No fog", Flag = "world_nofog" })
    Quick:Toggle({ Name = "Remove sky", Flag = "world_nosky" })

    local Atmo = Env:Section({ Name = "Fog and atmosphere", Column = 2, Icon = "cloud" })
    local Fog = Atmo:Toggle({ Name = "Custom fog", Flag = "world_fog" }):Settings("Custom fog", 230)
    pickColor(Fog, "Fog", "world_fog_color", Color3.fromRGB(180, 190, 210))
    Fog:Slider({ Name = "Fog start", Flag = "world_fog_start", Min = 0, Max = 2000, Default = 0, Decimals = 1, Suffix = " studs" })
    Fog:Slider({ Name = "Fog end", Flag = "world_fog_end", Min = 10, Max = 5000, Default = 1500, Decimals = 1, Suffix = " studs" })
    local FogGrad = Atmo:Toggle({ Name = "Fog gradient", Flag = "world_fog_grad", Tooltip = "Fades the fog colour between the fog colour above and this one" }):Settings("Fog gradient", 230)
    pickColor(FogGrad, "Second fog", "world_fog_color2", Color3.fromRGB(120, 70, 190))
    FogGrad:Slider({ Name = "Gradient speed", Flag = "world_fog_grad_speed", Min = 0.1, Max = 6, Default = 1, Decimals = 0.1 })
    local Atmos = Atmo:Toggle({ Name = "Atmosphere", Flag = "world_atmos" }):Settings("Atmosphere", 230)
    pickColor(Atmos, "Colour", "world_atmos_color", Color3.fromRGB(199, 199, 199))
    pickColor(Atmos, "Decay", "world_atmos_decay", Color3.fromRGB(106, 112, 125))
    Atmos:Slider({ Name = "Density", Flag = "world_atmos_density", Min = 0, Max = 1, Default = 0.3, Decimals = 0.01 })
    Atmos:Slider({ Name = "Glare", Flag = "world_atmos_glare", Min = 0, Max = 10, Default = 0, Decimals = 0.01 })
    Atmos:Slider({ Name = "Haze", Flag = "world_atmos_haze", Min = 0, Max = 10, Default = 0, Decimals = 0.01 })
    Atmo:Toggle({ Name = "Mood preset", Flag = "world_sky", Tooltip = "Sets the time of day and atmosphere colours together" }):Settings("Mood preset", 200):Dropdown({ Name = "Preset", Flag = "world_sky_preset", Items = { "Night", "Sunset", "Overcast", "Dusk" }, Default = "Night" })

    local MapLight = Env:Section({ Name = "Map lighting", Column = 3, Icon = "palette" })
    local MapShadow = MapLight:Toggle({ Name = "Map shadows", Flag = "world_map_shadow", Tooltip = "Global shadows and how soft they are; No shadows / Full bright still win" }):Settings("Map shadows", 230)
    MapShadow:Toggle({ Name = "Shadows enabled", Flag = "world_map_shadow_on", Default = true })
    MapShadow:Slider({ Name = "Shadow softness", Flag = "world_map_soft", Min = 0, Max = 1, Default = 0.2, Decimals = 0.01 })
    local MapSurf = MapLight:Toggle({ Name = "Map surfaces", Flag = "world_map", Tooltip = "Recolours and restyles the map's parts; collision and sizes are never touched" }):Settings("Map surfaces", 240)
    MapSurf:Toggle({ Name = "Colour tint", Flag = "world_map_tint_on" })
    pickColor(MapSurf, "Tint", "world_map_tint", Color3.fromRGB(120, 170, 255))
    MapSurf:Slider({ Name = "Tint strength", Flag = "world_map_tint_k", Min = 0, Max = 1, Default = 0.5, Decimals = 0.01 })
    MapSurf:Dropdown({ Name = "Material", Flag = "world_map_mat", Items = { "Default", "SmoothPlastic", "Plastic", "Metal", "Neon", "Glass", "ForceField" }, Default = "Default" })
    MapSurf:Toggle({ Name = "Neon map", Flag = "world_map_neon", Tooltip = "Neon material with the tint (at least 60% strength)" })
    MapSurf:Toggle({ Name = "Transparency", Flag = "world_map_trans_on", Tooltip = "Only affects solid parts; walls still block shots and movement" })
    MapSurf:Slider({ Name = "Map transparency", Flag = "world_map_trans", Min = 0, Max = 0.9, Default = 0.3, Decimals = 0.01 })
    MapSurf:Toggle({ Name = "Reflectance", Flag = "world_map_refl_on" })
    MapSurf:Slider({ Name = "Map reflectance", Flag = "world_map_refl", Min = 0, Max = 1, Default = 0.3, Decimals = 0.01 })
    local MapLamps = MapLight:Toggle({ Name = "Map lights", Flag = "world_lights", Tooltip = "Scales the map's own point, spot and surface lights; originals come back when off" }):Settings("Map lights", 240)
    MapLamps:Slider({ Name = "Brightness", Flag = "world_lights_bright", Min = 0, Max = 2, Default = 1, Decimals = 0.01, Suffix = "x" })
    MapLamps:Slider({ Name = "Range", Flag = "world_lights_range", Min = 0, Max = 2, Default = 1, Decimals = 0.01, Suffix = "x" })
    MapLamps:Slider({ Name = "Spot angle", Flag = "world_lights_angle", Min = 0.1, Max = 1.5, Default = 1, Decimals = 0.01, Suffix = "x" })
    MapLamps:Toggle({ Name = "Light colour", Flag = "world_lights_tint_on" })
    pickColor(MapLamps, "Colour", "world_lights_tint", Color3.fromRGB(255, 170, 90))
    MapLamps:Slider({ Name = "Colour strength", Flag = "world_lights_tint_k", Min = 0, Max = 1, Default = 0.5, Decimals = 0.01 })
    MapLamps:Toggle({ Name = "No light shadows", Flag = "world_lights_noshadow" })
    MapLamps:Toggle({ Name = "Disable lights", Flag = "world_lights_off" })

    local SkySub = Subs.Sky
    local Box = SkySub:Section({ Name = "Skybox", Column = 1, Icon = "moon" })
    local Skybox = Box:Toggle({ Name = "Custom skybox", Flag = "world_skybox", Tooltip = "Replaces the sky textures; the original sky comes back when this is off" }):Settings("Custom skybox", 230)
    Skybox:Dropdown({ Name = "Skybox", Flag = "world_sky_box", Items = SKY_CHOICES, Default = SKY_CHOICES[1] })
    Skybox:Toggle({ Name = "Rotate skybox", Flag = "world_sky_spin" })
    Skybox:Slider({ Name = "Rotation speed", Flag = "world_sky_spin_speed", Min = -60, Max = 60, Default = 6, Decimals = 0.1, Suffix = " deg/s" })
    local Own = SkySub:Section({ Name = "Custom skybox ids", Column = 2, Icon = "moon" })
    Own:Toggle({ Name = "Resolve decal ids", Flag = "world_sky_resolve", Default = true, Tooltip = "Decal ids are not image ids; this looks up the image inside the decal (needs GetObjects)" })
    Own:Input({ Name = "Custom ids (1 or 6)", Flag = "world_sky_custom", Placeholder = "1 or 6 ids: up down front back left right" })
    Own:Input({ Name = "Single image (all faces)", Flag = "world_sky_single", Placeholder = "id, rbxassetid:// or roblox.com link" })
    Own:Input({ Name = "Custom sky: Back", Flag = "world_sky_f_bk", Placeholder = "id or link" })
    Own:Input({ Name = "Custom sky: Down", Flag = "world_sky_f_dn", Placeholder = "id or link" })
    Own:Input({ Name = "Custom sky: Front", Flag = "world_sky_f_ft", Placeholder = "id or link" })
    Own:Input({ Name = "Custom sky: Left", Flag = "world_sky_f_lf", Placeholder = "id or link" })
    Own:Input({ Name = "Custom sky: Right", Flag = "world_sky_f_rt", Placeholder = "id or link" })
    Own:Input({ Name = "Custom sky: Up", Flag = "world_sky_f_up", Placeholder = "id or link" })
    local Saved = SkySub:Section({ Name = "Saved skyboxes", Column = 1, Icon = "layers" })
    Saved:Input({ Name = "Name", Flag = "world_sky_save_name", Placeholder = "name for the current skybox" })
    Saved:Button({ Name = "Save current skybox", Callback = function() Util.guard("sky-save", World.saveSky) end })
    Saved:Dropdown({ Name = "Saved set", Flag = "world_sky_saved_pick", Items = { "None" }, Default = "None" })
    Saved:Button({ Name = "Delete selected", Callback = function() Util.guard("sky-delete", World.deleteSky) end })
    Saved:Input({ Name = "Stored sets", Flag = "world_sky_saved", Placeholder = "name|6 ids; ..." })
    local Bodies = SkySub:Section({ Name = "Sun, moon and stars", Column = 3, Icon = "sun" })
    local Sky = Bodies:Toggle({ Name = "Override", Flag = "world_sky_objects" }):Settings("Sun, moon and stars", 230)
    Sky:Slider({ Name = "Stars", Flag = "world_sky_stars", Min = 0, Max = 5000, Default = 3000, Decimals = 1 })
    Sky:Slider({ Name = "Sun size", Flag = "world_sky_sun", Min = 0, Max = 60, Default = 21, Decimals = 1, Suffix = " deg" })
    Sky:Slider({ Name = "Moon size", Flag = "world_sky_moon", Min = 0, Max = 60, Default = 11, Decimals = 1, Suffix = " deg" })
    Sky:Toggle({ Name = "Show sun and moon", Flag = "world_sky_bodies", Default = true })
    local Cloud = SkySub:Section({ Name = "Clouds", Column = 3, Icon = "cloud" })
    local Clouds = Cloud:Toggle({ Name = "Clouds", Flag = "world_clouds" }):Settings("Clouds", 230)
    pickColor(Clouds, "Clouds", "world_clouds_color", WHITE)
    Clouds:Slider({ Name = "Cover", Flag = "world_clouds_cover", Min = 0, Max = 1, Default = 0.6, Decimals = 0.01 })
    Clouds:Slider({ Name = "Density", Flag = "world_clouds_density", Min = 0, Max = 1, Default = 0.6, Decimals = 0.01 })

    local Wx = Subs.Weather:Section({ Name = "Weather", Column = 1, Icon = "cloud" })
    Wx:Toggle({ Name = "Enabled", Flag = "world_weather", Tooltip = "Particles follow you in map-anchored cells and only fall where the sky is open above; Cover whole map replaces that with cells over the whole map" })
    Wx:Dropdown({ Name = "Type", Flag = "world_weather_preset", Items = WEATHER_NAMES, Default = "Snow" })
    Wx:Slider({ Name = "Density", Flag = "world_weather_amount", Min = 0.1, Max = 3, Default = 1, Decimals = 0.05 })
    Wx:Slider({ Name = "Speed", Flag = "world_weather_speed", Min = 0.2, Max = 3, Default = 1, Decimals = 0.05 })
    Wx:Slider({ Name = "Particle size", Flag = "world_weather_size", Min = 0.3, Max = 3, Default = 1, Decimals = 0.05 })
    local mapGear = Wx:Toggle({ Name = "Cover whole map", Flag = "world_weather_map", Tooltip = "Weather over the whole map only; the cells that follow you are switched off and come back when this is off. Cells grow so the count stays under the cap" }):Settings("Whole map", 200)
    mapGear:Slider({ Name = "Max cells", Flag = "world_weather_map_cap", Min = 16, Max = 400, Default = 100, Decimals = 1, Tooltip = "More cells = finer roof detection but more emitters" })
    mapGear:Slider({ Name = "Clear radius around player", Flag = "world_weather_clear_radius", Min = 0, Max = 150, Default = 40, Decimals = 1, Suffix = " studs", Tooltip = "Cells this close to you stay empty so nothing falls on or above you; 0 = off" })
    Wx:Slider({ Name = "Range", Flag = "world_weather_range", Min = 1, Max = 3, Default = 2, Decimals = 1, Suffix = " cells", Tooltip = "Rings of 28 stud cells around you; unused while Cover whole map is on" })
    Wx:Slider({ Name = "Spawn height", Flag = "world_weather_height", Min = 10, Max = 80, Default = 35, Decimals = 1, Suffix = " studs" })
    local Wind = Subs.Weather:Section({ Name = "Wind and colour", Column = 2, Icon = "cloud" })
    Wind:Slider({ Name = "Wind strength", Flag = "world_weather_wind", Min = 0, Max = 30, Default = 4, Decimals = 0.1 })
    Wind:Slider({ Name = "Wind direction", Flag = "world_weather_wind_dir", Min = 0, Max = 360, Default = 0, Decimals = 1, Suffix = " deg" })
    Wind:Toggle({ Name = "Custom colour", Flag = "world_weather_custom", Tooltip = "Overrides the colour each weather type comes with" }):Colorpicker({ Name = "Weather", Flag = "world_weather_color", Default = WHITE })

    local Fx = Subs.Effects
    local Screen = Fx:Section({ Name = "Colour correction", Column = 1, Icon = "palette" })
    local Cc = Screen:Toggle({ Name = "Enabled", Flag = "world_cc" }):Settings("Colour correction", 230)
    pickColor(Cc, "Tint", "world_cc_tint", WHITE)
    Cc:Slider({ Name = "Saturation", Flag = "world_cc_sat", Min = -1, Max = 1, Default = 0, Decimals = 0.01 })
    Cc:Slider({ Name = "Contrast", Flag = "world_cc_con", Min = -1, Max = 1, Default = 0, Decimals = 0.01 })
    Cc:Slider({ Name = "Brightness", Flag = "world_cc_bri", Min = -1, Max = 1, Default = 0, Decimals = 0.01 })
    local Bloom = Fx:Section({ Name = "Bloom and sun rays", Column = 2, Icon = "sun" })
    local Bl = Bloom:Toggle({ Name = "Bloom", Flag = "world_bloom" }):Settings("Bloom", 230)
    Bl:Slider({ Name = "Intensity", Flag = "world_bloom_i", Min = 0, Max = 3, Default = 0.4, Decimals = 0.01 })
    Bl:Slider({ Name = "Size", Flag = "world_bloom_s", Min = 0, Max = 56, Default = 24, Decimals = 0.1 })
    Bl:Slider({ Name = "Threshold", Flag = "world_bloom_t", Min = 0, Max = 2, Default = 0.95, Decimals = 0.01 })
    local Rays = Bloom:Toggle({ Name = "Sun rays", Flag = "world_rays" }):Settings("Sun rays", 230)
    Rays:Slider({ Name = "Ray intensity", Flag = "world_rays_i", Min = 0, Max = 1, Default = 0.25, Decimals = 0.01 })
    Rays:Slider({ Name = "Ray spread", Flag = "world_rays_s", Min = 0, Max = 1, Default = 1, Decimals = 0.01 })
    local Blur = Fx:Section({ Name = "Depth of field and blur", Column = 3, Icon = "scan" })
    local Dof = Blur:Toggle({ Name = "Depth of field", Flag = "world_dof" }):Settings("Depth of field", 230)
    Dof:Slider({ Name = "Focus distance", Flag = "world_dof_focus", Min = 0, Max = 500, Default = 50, Decimals = 1, Suffix = " studs" })
    Dof:Slider({ Name = "In focus radius", Flag = "world_dof_radius", Min = 0, Max = 200, Default = 30, Decimals = 1, Suffix = " studs" })
    Dof:Slider({ Name = "Near blur", Flag = "world_dof_near", Min = 0, Max = 1, Default = 0.5, Decimals = 0.01 })
    Dof:Slider({ Name = "Far blur", Flag = "world_dof_far", Min = 0, Max = 1, Default = 0.5, Decimals = 0.01 })
    Blur:Toggle({ Name = "Screen blur", Flag = "world_blur" }):Settings("Screen blur", 200):Slider({ Name = "Blur size", Flag = "world_blur_size", Min = 0, Max = 56, Default = 8, Decimals = 0.1 })
    local Rainbow = Env:Section({ Name = "Colour cycle", Column = 2, Icon = "palette" })
    local Rb = Rainbow:Toggle({ Name = "Rainbow", Flag = "world_rainbow", Tooltip = "Cycles the chosen colours through the rainbow" }):Settings("Rainbow", 230)
    Rb:Dropdown({ Name = "Applies to", Flag = "world_rainbow_targets", Items = { "Ambient", "Fog", "Colour shift", "Atmosphere" }, Multi = true, Default = { "Ambient" } })
    Rb:Slider({ Name = "Speed", Flag = "world_rainbow_speed", Min = 0.01, Max = 1, Default = 0.1, Decimals = 0.01 })
    Rb:Slider({ Name = "Saturation", Flag = "world_rainbow_sat", Min = 0, Max = 1, Default = 0.7, Decimals = 0.01 })

    local Cam = Subs.Camera
    local Fov = Cam:Section({ Name = "Camera", Column = 1, Icon = "camera" })
    local FovSet = Fov:Toggle({ Name = "Field of view", Flag = "world_fov", Tooltip = "Sets the game camera's base FOV; aiming zoom stays relative to it" }):Settings("Field of view", 230)
    FovSet:Slider({ Name = "FOV", Flag = "world_fov_v", Min = 60, Max = 120, Default = 90, Decimals = 1, Suffix = " deg" })
    FovSet:Toggle({ Name = "Dynamic scope FOV", Flag = "world_fov_dyn", Tooltip = "Blends smoothly from the FOV above to the scoped FOV below while you aim" })
    FovSet:Slider({ Name = "Scoped FOV", Flag = "world_fov_ads", Min = 20, Max = 120, Default = 60, Decimals = 1, Suffix = " deg" })
    FovSet:Slider({ Name = "Blend speed", Flag = "world_fov_speed", Min = 2, Max = 30, Default = 10, Decimals = 0.1 })
    FovSet:Slider({ Name = "Scope zoom multiplier", Flag = "world_fov_mult", Min = 0.5, Max = 3, Default = 1, Decimals = 0.01, Suffix = "x", Tooltip = "Scales the game's own scope zoom; 1 leaves it unchanged" })
    local StretchSet = Fov:Toggle({ Name = "Stretch resolution", Flag = "world_stretch", Tooltip = "Scales the rendered image sideways or vertically; aim maths keep using the real camera" }):Settings("Stretch resolution", 230)
    StretchSet:Slider({ Name = "Stretch X", Flag = "world_stretch_x", Min = 0.3, Max = 1.27, Default = 0.75, Decimals = 0.01, Suffix = "x", Tooltip = "Below 1 gives the classic 4:3 stretched look" })
    StretchSet:Slider({ Name = "Stretch Y", Flag = "world_stretch_y", Min = 0.3, Max = 1.2, Default = 1, Decimals = 0.01, Suffix = "x" })
    local Cross = Cam:Section({ Name = "Crosshair", Column = 2, Icon = "crosshair" })
    local Ch = Cross:Toggle({ Name = "Custom crosshair", Flag = "cross_on" }):Settings("Crosshair", 230)
    pickColor(Ch, "Crosshair", "cross_color", Color3.fromRGB(120, 255, 170))
    Ch:Toggle({ Name = "Hide game crosshair", Flag = "cross_hide_game", Tooltip = "Hides Phantom Forces' own hipfire crosshair while Custom crosshair is on; it comes back when either is turned off" })
    Ch:Toggle({ Name = "Attach to barrel", Flag = "cross_barrel", Tooltip = "Draws the crosshair at the weapon barrel instead of the screen centre" })
    Ch:Dropdown({ Name = "Attach point", Flag = "cross_barrel_pt", Items = { "Aim hit", "Muzzle" }, Default = "Aim hit", Tooltip = "Aim hit is where the barrel is pointing; Muzzle is the barrel tip" })
    Ch:Slider({ Name = "Length", Flag = "cross_len", Min = 1, Max = 40, Default = 8, Decimals = 1, Suffix = " px" })
    Ch:Slider({ Name = "Thickness", Flag = "cross_thick", Min = 1, Max = 6, Default = 2, Decimals = 1, Suffix = " px" })
    Ch:Slider({ Name = "Gap", Flag = "cross_gap", Min = 0, Max = 30, Default = 5, Decimals = 1, Suffix = " px" })
    Ch:Toggle({ Name = "Outline", Flag = "cross_outline", Default = true })
    Ch:Toggle({ Name = "Centre dot", Flag = "cross_dot" })
    Ch:Toggle({ Name = "T style", Flag = "cross_t", Tooltip = "Leaves out the top arm" })
    local Spin = Cross:Toggle({ Name = "Spin", Flag = "cross_spin" }):Settings("Spin", 200)
    Spin:Slider({ Name = "Spin speed", Flag = "cross_spin_speed", Min = -360, Max = 360, Default = 90, Decimals = 1, Suffix = " deg/s" })
    local Pulse = Cross:Toggle({ Name = "Pulse gap", Flag = "cross_pulse" }):Settings("Pulse gap", 230)
    Pulse:Slider({ Name = "Pulse range", Flag = "cross_pulse_range", Min = 0, Max = 30, Default = 8, Decimals = 1, Suffix = " px" })
    Pulse:Slider({ Name = "Pulse speed", Flag = "cross_pulse_speed", Min = 0.2, Max = 10, Default = 3, Decimals = 0.1 })

    local Fb = Subs.Feedback
    local Marker, HitSnd, KillSnd = Fb:MultiSection({ Name = "Hits and kills", Sections = { "Hit marker", "Hit sound", "Kill sound" }, Icons = { "crosshair", "zap", "flame" }, Column = 1 })
    Marker:Toggle({ Name = "Hit marker", Flag = "hit_marker", Tooltip = "Drawn at the crosshair whenever the game registers one of your hits" }):Colorpicker({ Name = "Marker", Flag = "hit_marker_color", Default = WHITE, Alpha = 0 }):Colorpicker({ Name = "Headshot", Flag = "hit_marker_head", Default = Color3.fromRGB(255, 70, 70), Alpha = 0 })
    Marker:Slider({ Name = "Size", Flag = "hit_marker_size", Min = 4, Max = 24, Default = 9, Decimals = 1, Suffix = " px" })
    Marker:Slider({ Name = "Duration", Flag = "hit_marker_time", Min = 0.1, Max = 1.2, Default = 0.4, Decimals = 0.01, Suffix = " s" })
    Marker:Toggle({ Name = "Hide the game's marker", Flag = "hit_hide_game" })
    HitSnd:Toggle({ Name = "Hit sound", Flag = "hit_snd" })
    HitSnd:Dropdown({ Name = "Sound", Flag = "hit_snd_id", Items = HIT_SOUND_ORDER, Default = "Gamesense" })
    HitSnd:Slider({ Name = "Volume", Flag = "hit_snd_vol", Min = 0.1, Max = 5, Default = 1.5, Decimals = 0.01 })
    HitSnd:Slider({ Name = "Pitch", Flag = "hit_snd_pitch", Min = 0.5, Max = 2, Default = 1, Decimals = 0.01 })
    HitSnd:Toggle({ Name = "Different on headshot", Flag = "hit_snd_head" })
    HitSnd:Dropdown({ Name = "Headshot sound", Flag = "hit_snd_head_id", Items = HIT_SOUND_ORDER, Default = "Alt Headshot kill" })
    KillSnd:Toggle({ Name = "Kill sound", Flag = "kill_snd", Tooltip = "Plays when you kill a player (from the game's death event)" })
    KillSnd:Dropdown({ Name = "Sound", Flag = "kill_snd_id", Items = HIT_SOUND_ORDER, Default = "Alt Killshot" })
    KillSnd:Slider({ Name = "Volume", Flag = "kill_snd_vol", Min = 0.1, Max = 5, Default = 1.5, Decimals = 0.01 })
    KillSnd:Slider({ Name = "Pitch", Flag = "kill_snd_pitch", Min = 0.5, Max = 2, Default = 1, Decimals = 0.01 })

    local Dmg = Fb:Section({ Name = "Damage numbers", Column = 2, Icon = "target" })
    local Trace = Fb:Section({ Name = "Bullet tracers", Column = 3, Icon = "zap" })
    Dmg:Toggle({ Name = "Custom damage numbers", Flag = "dmg_on", Tooltip = "Replaces the game's floating numbers; the game's Damage Numbers setting must be on" })
    Dmg:Label({ Name = "Head" }):Colorpicker({ Name = "Head", Flag = "dmg_head", Default = Color3.fromRGB(255, 102, 102) })
    Dmg:Label({ Name = "Torso" }):Colorpicker({ Name = "Torso", Flag = "dmg_torso", Default = Color3.fromRGB(255, 150, 0) })
    Dmg:Label({ Name = "Limbs" }):Colorpicker({ Name = "Limbs", Flag = "dmg_limb", Default = Color3.fromRGB(255, 255, 0) })
    Dmg:Slider({ Name = "Size", Flag = "dmg_size", Min = 8, Max = 32, Default = 16, Decimals = 1, Suffix = " px" })
    Dmg:Slider({ Name = "Rise", Flag = "dmg_rise", Min = 10, Max = 150, Default = 60, Decimals = 1, Suffix = " px" })
    Dmg:Slider({ Name = "Duration", Flag = "dmg_time", Min = 0.4, Max = 3, Default = 1.1, Decimals = 0.01, Suffix = " s" })
    Trace:Toggle({ Name = "Own bullets", Flag = "trace_on", Tooltip = "Draws a tracer from your barrel to where the shot lands" }):Colorpicker({ Name = "Tracer", Flag = "trace_color", Default = Color3.fromRGB(255, 94, 94) })
    Trace:Toggle({ Name = "Enemy bullets", Flag = "trace_enemy_on" }):Colorpicker({ Name = "Tracer", Flag = "trace_enemy_color", Default = Color3.fromRGB(94, 160, 255) })
    Trace:Toggle({ Name = "Team bullets", Flag = "trace_team_on" }):Colorpicker({ Name = "Tracer", Flag = "trace_team_color", Default = Color3.fromRGB(90, 220, 130) })
    Trace:Dropdown({ Name = "Tracer texture", Flag = "trace_texture", Items = { "Obelus", "Lightning", "DNA", "Beam", "Bolt", "Trail", "Zigzag", "Heartrate", "Chain", "Glitch", "Swirl" }, Default = "Lightning" })
    Trace:Slider({ Name = "Tracer lifetime", Flag = "trace_time", Min = 0.5, Max = 10, Default = 4, Decimals = 0.1, Suffix = " s" })
    Trace:Slider({ Name = "Tracer width", Flag = "trace_width", Min = 0.2, Max = 3, Default = 1, Decimals = 0.1, Suffix = "x" })
    local Glow = Trace:Toggle({ Name = "Tracer glow", Flag = "trace_glow", Tooltip = "Full-bright beam plus a wider additive halo behind it" }):Settings("Tracer glow", 230)
    Glow:Slider({ Name = "Glow strength", Flag = "trace_glow_strength", Min = 0, Max = 10, Default = 4, Decimals = 0.1 })
    Glow:Toggle({ Name = "Glow uses tracer colour", Flag = "trace_glow_same", Default = true })
    Glow:Label({ Name = "Glow colour" }):Colorpicker({ Name = "Glow colour", Flag = "trace_glow_color", Default = Color3.fromRGB(255, 255, 255) })
    local Grad = Trace:Toggle({ Name = "Tracer gradient", Flag = "trace_gradient", Tooltip = "Colours the tracer from start to end along its whole length, replacing the single tracer colour" }):Settings("Tracer gradient", 230)
    Grad:Label({ Name = "Gradient start" }):Colorpicker({ Name = "Gradient start", Flag = "trace_grad_start", Default = Color3.fromRGB(255, 94, 94) })
    Grad:Label({ Name = "Gradient end" }):Colorpicker({ Name = "Gradient end", Flag = "trace_grad_end", Default = Color3.fromRGB(94, 160, 255) })
    Grad:Slider({ Name = "Gradient fade", Flag = "trace_grad_fade", Min = 0, Max = 1, Default = 0, Decimals = 0.01, Tooltip = "Fades the tracer toward its far end" })
    Grad:Toggle({ Name = "Rainbow", Flag = "trace_rainbow", Tooltip = "Cycles hue along the tracer instead of the two colours" })
    Trace:Toggle({ Name = "Hide the game's beam", Flag = "trace_hide_beam", Default = true, Tooltip = "Turns off the game's own tracer beam on bullets that get a custom tracer" })
end

do
    local FOLDER = "Aster/PhantomForces"
    pcall(function()
        if makefolder and isfolder then
            if not isfolder("Aster") then makefolder("Aster") end
            if not isfolder(FOLDER) then makefolder(FOLDER) end
        end
    end)
    local Tab = LibWindow:AddTab("Settings", "settings")
    local native = type(Tab.AddSubTab) == "function"
    local MenuSub = native and Tab:AddSubTab("Menu", "keyboard") or Tab
    local ThemeSub = native and Tab:AddSubTab("Theme", "palette") or Tab
    local ConfigSub = native and Tab:AddSubTab("Config", "save") or Tab

    local Menu = MenuSub:AddLeftGroupbox("Menu", "keyboard")
    Menu:AddLabel("Menu key"):AddKeyPicker("MenuKeybind", { Default = "Delete", Mode = "Toggle", Text = "Menu key", NoUI = true })
    Library.ToggleKeybind = Options.MenuKeybind
    escapeUnbinds("MenuKeybind", "Delete")
    Menu:AddToggle("menu_hide_cursor", { Text = "Hide game cursor", Default = true })
    Toggles.menu_hide_cursor:OnChanged(function() pcall(function() Library:SetHideGameCursor(Toggles.menu_hide_cursor.Value) end) end)
    Menu:AddToggle("menu_watermark", { Text = "Watermark", Default = true })
    Menu:AddToggle("menu_keybinds", { Text = "Keybind list", Default = false })
    Toggles.menu_watermark:OnChanged(function() pcall(function() Library:SetWatermarkVisibility(Toggles.menu_watermark.Value) end) end)
    Toggles.menu_keybinds:OnChanged(function() pcall(function() Library:SetKeybindListVisibility(Toggles.menu_keybinds.Value) end) end)
    if type(Library.SetNotifyCorner) == "function" then
        Menu:AddDropdown("menu_notify_corner", {
            Text = "Notification corner",
            Values = { "Top Left", "Top Center", "Top Right", "Bottom Left", "Bottom Center", "Bottom Right" },
            Default = 1,
        })
        Options.menu_notify_corner:OnChanged(function() pcall(function() Library:SetNotifyCorner(Options.menu_notify_corner.Value) end) end)
    end
    Menu:AddButton("Test notification", function() Library:Notify("Aster notification test", 3) end)
    Menu:AddButton({ Text = "Unload Aster", Func = function() Library:Unload() end, DoubleClick = true, Tooltip = "Double click to unload" })

    ThemeManager:SetLibrary(Library)
    SaveManager:SetLibrary(Library)
    ThemeManager:SetFolder(FOLDER)
    SaveManager:SetFolder(FOLDER)
    ThemeManager.HudToggles = false
    if native and ThemeManager.CreateColors then
        ThemeManager:CreateColors(ThemeSub:AddLeftGroupbox("Colors", "palette"))
        ThemeManager:CreatePresets(addBox(ThemeSub, 2, "Presets", "folder"))
        ThemeManager:CreateAppearance(addBox(ThemeSub, 3, "Appearance", "monitor"))
        ThemeManager:Finalize()
    elseif ThemeManager.ApplyToTab then
        ThemeManager:ApplyToTab(ThemeSub)
    else
        Library:Notify("Outdated ThemeManager: upload addons/ThemeManager.lua from the latest release", 10)
    end
    SaveManager:IgnoreThemeSettings()
    SaveManager:SetIgnoreIndexes({ "MenuKeybind", "menu_notify_corner", "ui_view_Legit", "ui_view_ESP", "ui_view_World" })
    SaveManager:BuildConfigSection(ConfigSub)

    if type(Library.GetLayout) == "function" and type(Library.SetLayout) == "function" then
        local Http = game:GetService("HttpService")
        local function withConfig(manager, name, apply)
            local path = tostring(manager.Folder) .. "/settings/" .. tostring(name) .. ".json"
            local data = Http:JSONDecode(readfile(path))
            if type(data) == "table" then apply(data, path) end
        end
        local function watch(key, run)
            local real, used = Library[key], false
            Library[key] = function(...) used = true return real(...) end
            local ran, ok, problem = pcall(run)
            Library[key] = real
            if not ran then error(ok, 0) end
            return used, ok, problem
        end
        Util.hook(SaveManager, "Save", function(original)
            return function(self, name)
                local native, ok, problem = watch("GetLayout", function() return original(self, name) end)
                if ok and not native then
                    Util.guard("layout-save", withConfig, self, name, function(data, path)
                        local layout = Library:GetLayout()
                        if type(layout) == "table" then
                            data.layout = layout
                            writefile(path, Http:JSONEncode(data))
                        end
                    end)
                end
                return ok, problem
            end
        end)
        Util.hook(SaveManager, "Load", function(original)
            return function(self, name)
                local native, ok, problem = watch("SetLayout", function() return original(self, name) end)
                if ok and not native then
                    Util.guard("layout-load", withConfig, self, name, function(data)
                        if type(data.layout) == "table" then Library:SetLayout(data.layout) end
                    end)
                end
                return ok, problem
            end
        end)
    end
end

local PHANTOMCAM_SOURCE = [==[
local SOURCE_URL = "https://raw.githubusercontent.com/SoSpoof/Phantom-cam/main/phantomcam.lua"

local HOST = getgenv().PhantomCamHost == true
getgenv().PhantomCamHost = nil

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local MAX_TURN = 0.6
local MAX_PITCH = 1.5
local MAX_SHIFT = 1.5
local MAX_BODY = 2.5
local REST_RATE = 0.5
local SWAY_MOVE = 0.35
local STALE = 0.05
local EYE = Vector3.new(0, 0.125, 0)

for _, name in ipairs({ "PhantomCamApi", "PhantomCam" }) do
    local previous = getgenv()[name]
    if type(previous) == "table" and type(previous.Destroy) == "function" then pcall(previous.Destroy) end
    getgenv()[name] = nil
end

local HookChain = {}

function HookChain.add(object, id, priority, fn)
    local chain = rawget(object, "__hookchain")
    if not chain then
        chain = { list = {}, orig = rawget(object, "postStep") }
        chain.wrapper = function(self, dt)
            local orig = chain.orig
            local a, b = nil, nil
            if orig then a, b = orig(self, dt) end
            local snapshot = table.move(chain.list, 1, #chain.list, 1, {})
            for _, entry in ipairs(snapshot) do pcall(entry.fn, self, dt) end
            return a, b
        end
        local set, problem = pcall(function() object.postStep = chain.wrapper end)
        if not set then return false, problem end
        rawset(object, "__hookchain", chain)
    end
    for index, entry in ipairs(chain.list) do
        if entry.id == id then table.remove(chain.list, index) break end
    end
    table.insert(chain.list, { id = id, priority = priority, fn = fn })
    table.sort(chain.list, function(a, b) return a.priority < b.priority end)
    return true
end

function HookChain.has(object, id)
    local chain = rawget(object, "__hookchain")
    if not chain then return false end
    for _, entry in ipairs(chain.list) do
        if entry.id == id then return true end
    end
    return false
end

function HookChain.remove(object, id)
    local chain = rawget(object, "__hookchain")
    if not chain then return end
    for index, entry in ipairs(chain.list) do
        if entry.id == id then table.remove(chain.list, index) break end
    end
    if #chain.list == 0 and rawget(object, "postStep") == chain.wrapper then
        pcall(function() object.postStep = chain.orig end)
        rawset(object, "__hookchain", nil)
    end
end

local Cam = {
    settings = {
        strength = 2.5, smoothing = 0, position = 0, roll = false, onlyAiming = false, noScope = false,
        mode = "Barrel", hideViewmodel = true, hideHat = true, forward = 0.5, fov = 0, sway = 1, debug = false,
    },
    mods = {},
    fails = {},
    why = {},
    hidden = { view = {}, hat = {} },
    scanAt = { view = 0, hat = 0 },
    passes = { hook = 0, bind = 0, rs = 0 },
    amount = 0,
    running = false,
    warned = {},
    bindName = "pc" .. tostring(math.random(100000, 999999)),
    retryAt = 0,
    attachAt = 0,
    bodyAt = 0,
    debugAt = 0,
    token = 0,
    kept = 0,
    lost = 0,
    frameDt = 1 / 60,
    info = {},
    keys = {},
}

local function note(key, ...)
    if Cam.warned[key] then return end
    Cam.warned[key] = true
    warn("[PhantomCam]", ...)
end

local function wrap(angle)
    return (angle + math.pi) % (math.pi * 2) - math.pi
end

local function same(a, b)
    return a.Position == b.Position and a.LookVector == b.LookVector and a.UpVector == b.UpVector
end

local function limit(vector, max)
    local size = vector.Magnitude
    if size > max then return vector * (max / size) end
    return vector
end

local function vec(v)
    return string.format("(%.1f,%.1f,%.1f)", v.X, v.Y, v.Z)
end

local function bind(name, priority, fn)
    local ok = pcall(function() RunService:BindToRenderStep(name, priority, fn) end)
    if ok then
        return function() pcall(function() RunService:UnbindFromRenderStep(name) end) end, true
    end
    local connection = RunService.RenderStepped:Connect(fn)
    return function() connection:Disconnect() end, false
end

local function lastPriority()
    local ok, value = pcall(function() return Enum.RenderPriority.Last.Value end)
    return ok and type(value) == "number" and value or 2000
end

local function debugOn()
    return Cam.settings.debug == true or getgenv().PhantomCamDebug == true
end

function Cam.req(name)
    local requireFn
    pcall(function() requireFn = getrenv().shared.require end)
    local why = "getrenv().shared.require missing (not inside the game's actor?)"
    if type(requireFn) == "function" then
        local ok, module = pcall(requireFn, name)
        if ok and type(module) == "table" then return module end
        why = ok and ("shared.require returned " .. type(module)) or tostring(module)
    end
    if type(getloadedmodules) == "function" then
        local found
        pcall(function()
            for _, loaded in ipairs(getloadedmodules()) do
                if loaded.Name == name then
                    local okRequire, result = pcall(require, loaded)
                    if okRequire and type(result) == "table" then found = result return end
                end
            end
        end)
        if found then return found end
    end
    return nil, why
end

function Cam.load()
    if Cam.mods.CharacterInterface and Cam.mods.CameraInterface then return end
    local now = os.clock()
    if now < Cam.retryAt then return end
    Cam.retryAt = now + 3
    for _, name in ipairs({ "CharacterInterface", "CameraInterface" }) do
        if not Cam.mods[name] then
            local module, why = Cam.req(name)
            if module then
                Cam.mods[name] = module
            else
                Cam.fails[name] = (Cam.fails[name] or 0) + 1
                Cam.why[name] = why
                if Cam.fails[name] >= 2 then
                    note("load" .. name, "cannot load " .. name .. ": " .. tostring(why) .. (name == "CameraInterface" and " - no camera hook, render-step fallback only" or " - no weapon/barrel data"))
                end
            end
        end
    end
end

function Cam.weapon()
    local interface = Cam.mods.CharacterInterface
    if not interface then return nil, "no CharacterInterface" end
    local why
    local ok, weapon = pcall(function()
        if not interface.isAlive() then why = "dead" return nil end
        local character = interface.getCharacterObject()
        if not character then why = "no character object" return nil end
        local controller = character:getWeaponController()
        if not controller then why = "no weapon controller" return nil end
        local active = controller:getActiveWeapon()
        if not active then why = "no active weapon" end
        return active
    end)
    if not ok then return nil, "error: " .. tostring(weapon) end
    if type(weapon) == "table" then return weapon end
    return nil, why
end

function Cam.barrel(weapon)
    if type(weapon.getBarrelCFrame) ~= "function" then return nil, "weapon has no getBarrelCFrame" end
    local ok, frame = pcall(weapon.getBarrelCFrame, weapon)
    if not ok then return nil, "getBarrelCFrame error: " .. tostring(frame) end
    if typeof(frame) ~= "CFrame" then return nil, "getBarrelCFrame returned " .. typeof(frame) end
    local position, look = frame.Position, frame.LookVector
    if position ~= position or look ~= look then return nil, "barrel is NaN" end
    return frame
end

function Cam.aiming(weapon)
    if type(weapon.isAiming) ~= "function" then return false end
    local ok, state = pcall(weapon.isAiming, weapon)
    return ok and state == true
end

function Cam.zoom(weapon)
    if type(weapon.getActiveAimStats) ~= "function" then return 1 end
    local ok, stats = pcall(weapon.getActiveAimStats, weapon)
    if not ok or type(stats) ~= "table" then return 1 end
    local total = 1
    for _, stat in ipairs(stats) do
        local magnify = type(stat.sightmagspring) == "table" and stat.sightmagspring.p
        local zoom = stat.zoom
        if type(zoom) == "number" and zoom > 0 and type(magnify) == "number" then
            total = total * zoom ^ math.clamp(magnify, 0, 1)
        end
    end
    return total
end

function Cam.head()
    local ok, position = pcall(function()
        local character = game:GetService("Players").LocalPlayer.Character
        local head = character and character:FindFirstChild("Head")
        if head and head.Parent then return head.Position end
        local interface = Cam.mods.CharacterInterface
        local object = interface and interface.getCharacterObject()
        local root = object and object:getRealRootPart()
        if root then return root.Position + Vector3.new(0, 1.5, 0) end
        return nil
    end)
    if ok and typeof(position) == "Vector3" and position == position then return position end
    return nil
end

function Cam.isAlive()
    local interface = Cam.mods.CharacterInterface
    if interface then
        local ok, alive = pcall(interface.isAlive)
        if ok then return alive == true end
    end
    return Cam.head() ~= nil
end

function Cam.detach()
    local object = Cam.hooked
    Cam.hooked = nil
    if object then HookChain.remove(object, "phantomcam") end
end

function Cam.attach(now)
    if now < Cam.attachAt then return end
    Cam.attachAt = now + 0.25
    local interface = Cam.mods.CameraInterface
    if not interface or type(interface.getActiveCamera) ~= "function" then return end
    local ok, object = pcall(interface.getActiveCamera, "MainCamera", true)
    if not (ok and type(object) == "table") then
        Cam.hookWhy = ok and "no MainCamera active (menu/spectate)" or tostring(object)
        return
    end
    if Cam.hooked == object and HookChain.has(object, "phantomcam") then
        if Cam.passes.hook == 0 and now - Cam.hookedAt > 3 and Cam.isAlive() then
            note("hookdead", "camera hook installed but the game never called it - relying on render-step passes")
        end
        return
    end
    Cam.detach()
    local token = Cam.token
    local function hook(self, dt)
        if Cam.running and Cam.token == token then Cam.run("hook", type(dt) == "number" and dt or nil) end
    end
    local set, problem = HookChain.add(object, "phantomcam", 10, hook)
    if not set then
        Cam.hookWhy = "cannot set postStep: " .. tostring(problem)
        note("hookset", Cam.hookWhy)
        return
    end
    Cam.hooked, Cam.hookedAt, Cam.hookWhy = object, now, nil
end

function Cam.bodyDestroy()
    local body = Cam.body
    Cam.body, Cam.bodyPos, Cam.bodyVel, Cam.bodyAccel, Cam.bodyStance, Cam.bodySprint, Cam.bodyRest = nil, nil, nil, nil, nil, nil, nil
    if not body then return end
    pcall(function() body:unqueueWelds() end)
    pcall(function() body:Destroy() end)
end

function Cam.bodyBuild(now)
    if Cam.body or now < Cam.bodyAt then return end
    Cam.bodyAt = now + 3
    local class, why = Cam.req("ThirdPersonObject")
    if not (class and type(class.new) == "function") then
        Cam.bodyWhy = "ThirdPersonObject unavailable: " .. tostring(why)
        note("bodyclass", Cam.bodyWhy .. " - using synthesized head motion")
        return
    end
    local weapons = {}
    local stub = {
        getActiveWeaponIndex = function() return 1 end,
        getWeaponObjects = function() return weapons end,
        getWeaponObject = function() return nil end,
        isEnemy = function() return false end,
        _posspring = { p = Vector3.zero },
    }
    local player = game:GetService("Players").LocalPlayer
    local ok, body = pcall(class.new, player, Vector3.zero, stub)
    if not (ok and type(body) == "table") then
        Cam.bodyWhy = "ThirdPersonObject.new failed: " .. tostring(body)
        note("bodynew", Cam.bodyWhy .. " - using synthesized head motion")
        return
    end
    pcall(function() body._rootPart.Parent = nil end)
    pcall(function()
        body._leftFoot.makesound = false
        body._rightFoot.makesound = false
        body._equipSpring.p, body._equipSpring.t = 1, 1
    end)
    Cam.body, Cam.bodyWhy = body, nil
end

function Cam.bodyHead(frame, dt, now)
    local interface = Cam.mods.CharacterInterface
    if not interface then return nil end
    Cam.bodyBuild(now)
    local body = Cam.body
    if not body then return nil end
    local ok, head = pcall(function()
        local object = interface.getCharacterObject()
        local position = object:getRealRootPart().Position
        local velocity = Vector3.zero
        local accel = Vector3.zero
        if Cam.bodyPos then
            local alpha = 1 - math.exp(-dt * 20)
            local rawVelocity = limit((position - Cam.bodyPos) / dt, 60)
            velocity = Cam.bodyVel + (rawVelocity - Cam.bodyVel) * alpha
            accel = Cam.bodyAccel + (limit((velocity - Cam.bodyVel) / dt, 200) - Cam.bodyAccel) * (1 - math.exp(-dt * 10))
        end
        Cam.bodyPos, Cam.bodyVel, Cam.bodyAccel = position, velocity, accel
        local mode = object:getMovementMode()
        if mode ~= Cam.bodyStance then Cam.bodyStance = mode body:setStance(mode) end
        local sprint = object:isSprinting() == true
        if sprint ~= Cam.bodySprint then Cam.bodySprint = sprint body:setSprint(sprint) end
        local pitch, yaw = frame:ToOrientation()
        local camera = Cam.hooked
        local angles = camera and camera:getAngles()
        if typeof(angles) ~= "Vector3" then angles = Vector3.new(pitch, yaw, 0) end
        local root = CFrame.new(position) * CFrame.Angles(0, body:getBaseAngle(), 0)
        body:step(true, root, velocity, angles, angles, accel, dt)
        local cframe = body._neckWeld:getCFrame()
        if typeof(cframe) ~= "CFrame" then cframe = body._head.CFrame end
        return cframe
    end)
    if ok and typeof(head) == "CFrame" and head.Position == head.Position then return head end
    Cam.bodyWhy = "body step failed: " .. tostring(head)
    note("bodystep", Cam.bodyWhy .. " - using synthesized head motion")
    Cam.bodyDestroy()
    Cam.bodyAt = now + 10
    return nil
end

function Cam.collectView(camera)
    local list = {}
    local ok, children = pcall(camera.GetChildren, camera)
    if not (ok and type(children) == "table") then return list end
    for _, child in ipairs(children) do
        if child.ClassName == "Model" then
            local okDescendants, descendants = pcall(child.GetDescendants, child)
            for _, part in ipairs(okDescendants and descendants or {}) do
                if part:IsA("BasePart") then list[#list + 1] = part end
            end
        end
    end
    return list
end

function Cam.collectHat()
    local list = {}
    pcall(function()
        local character = game:GetService("Players").LocalPlayer.Character
        if not character then return end
        local head = character:FindFirstChild("Head")
        if head then list[#list + 1] = head end
        for _, child in ipairs(character:GetChildren()) do
            if child.ClassName == "Accessory" or child.ClassName == "Hat" then
                for _, part in ipairs(child:GetDescendants()) do
                    if part:IsA("BasePart") then list[#list + 1] = part end
                end
            end
        end
    end)
    return list
end

function Cam.restoreHidden(kind)
    for part, original in pairs(Cam.hidden[kind]) do
        pcall(function() part.LocalTransparencyModifier = original end)
    end
    Cam.hidden[kind] = {}
    Cam.scanAt[kind] = 0
end

function Cam.syncHidden(kind, want, collect, now)
    if not want then
        if next(Cam.hidden[kind]) then Cam.restoreHidden(kind) end
        return
    end
    if now < Cam.scanAt[kind] then return end
    Cam.scanAt[kind] = now + 0.25
    local store = Cam.hidden[kind]
    for _, part in ipairs(collect()) do
        if store[part] == nil then
            local ok, original = pcall(function() return part.LocalTransparencyModifier end)
            store[part] = ok and type(original) == "number" and original or 0
        end
        pcall(function() part.LocalTransparencyModifier = 1 end)
    end
end

function Cam.applyFov(camera, value)
    if camera.FieldOfView ~= Cam.fovWritten then Cam.fovGame = camera.FieldOfView end
    if value >= 20 then
        camera.FieldOfView = value
        Cam.fovWritten = value
    elseif Cam.fovWritten then
        if camera.FieldOfView == Cam.fovWritten then camera.FieldOfView = Cam.fovGame end
        Cam.fovWritten = nil
    end
end

function Cam.reset()
    Cam.amount, Cam.smoothed, Cam.written, Cam.rest, Cam.swayRest, Cam.pending = 0, nil, nil, nil, nil, false
end

function Cam.clear()
    Cam.smoothed, Cam.written, Cam.rest, Cam.swayRest, Cam.pending = nil, nil, nil, nil, false
end

function Cam.report(now)
    if not debugOn() or now < Cam.debugAt then return end
    Cam.debugAt = now + 1
    local i = Cam.info
    local hook
    if Cam.hooked then
        hook = "hooked calls=" .. Cam.passes.hook
    elseif Cam.mods.CameraInterface then
        hook = "none (" .. tostring(Cam.hookWhy or "pending") .. ")"
    else
        hook = "no CameraInterface (" .. tostring(Cam.why.CameraInterface) .. ")"
    end
    local body = i.world and (Cam.body and "thirdperson" or ("synth (" .. tostring(Cam.bodyWhy or "pending") .. ")")) or "n/a"
    local readback = Cam.lost == 0 and "ok" or ("OVERWRITTEN " .. tostring(Cam.lostBy))
    local camera = Workspace.CurrentCamera
    warn("[PhantomCam]", string.format(
        "mode=%s active=%s src=%s hook=[%s] passes h/b/r=%d/%d/%d prio=%s weapon=%s barrel=%s body=%s amount=%.2f offset=%.1fdeg/%.2fst game=%s final=%s readback=%s kept/lost=%d/%d fov=%.1f gamecam=%s",
        i.world and "World" or "Barrel", tostring(Cam.running), tostring(i.source), hook,
        Cam.passes.hook, Cam.passes.bind, Cam.passes.rs, tostring(Cam.prio),
        i.weapon and "yes" or ("no: " .. tostring(i.weaponWhy)),
        i.barrel and "yes" or ("no: " .. tostring(i.barrelWhy)),
        body, Cam.amount, i.deg or 0, i.studs or 0,
        i.game and vec(i.game.Position) or "-", i.final and vec(i.final.Position) or "-",
        readback, Cam.kept, Cam.lost, camera and camera.FieldOfView or 0, tostring(i.gamecam or "-")))
end

function Cam.step(source, dt)
    local camera = Workspace.CurrentCamera
    if not camera then return end
    local now = os.clock()
    Cam.passes[source] = (Cam.passes[source] or 0) + 1
    local current = camera.CFrame
    local frame = current
    if source ~= "hook" then Cam.attach(now) end
    if Cam.written then
        local untouched = same(current, Cam.written)
        if Cam.pending and Cam.pendingSource ~= source and now - Cam.writtenAt < math.min(0.012, Cam.frameDt * 0.5) then
            Cam.pending = false
            if untouched then
                Cam.kept = Cam.kept + 1
            else
                Cam.lost = Cam.lost + 1
                Cam.lostBy = Cam.pendingSource .. " then " .. source
                if Cam.lost >= 10 and Cam.lost > Cam.kept then
                    note("lost", "the game overwrites the camera after PhantomCam writes it (" .. Cam.lost .. " of " .. (Cam.lost + Cam.kept) .. " frames, " .. Cam.lostBy .. ")")
                end
            end
        end
        if untouched then
            frame = Cam.gameCFrame or current
            if now - Cam.writtenAt < STALE then return end
        end
    end
    Cam.gameCFrame = frame
    local elapsed = math.clamp(now - (Cam.clock or now), 1 / 240, 0.1)
    dt = math.clamp(dt or elapsed, 1 / 240, 0.1)
    Cam.clock = now
    Cam.frameDt = Cam.frameDt + (elapsed - Cam.frameDt) * 0.1

    Cam.load()
    local s = Cam.settings
    local world = s.mode == "World character"
    local info = Cam.info
    info.world, info.source, info.game = world, source, frame
    local object = Cam.hooked
    if source == "hook" and object and type(object.getCFrame) == "function" then
        local okFrame, own = pcall(object.getCFrame, object)
        if okFrame and typeof(own) == "CFrame" then info.gamecam = same(own, current) and "match" or "differs" end
    end
    local function hiding(active)
        Cam.syncHidden("view", active and s.hideViewmodel, function() return Cam.collectView(camera) end, now)
        Cam.syncHidden("hat", active and s.hideHat, Cam.collectHat, now)
    end
    Cam.applyFov(camera, s.fov)
    local weapon, weaponWhy = Cam.weapon()
    local barrel, barrelWhy
    if weapon then barrel, barrelWhy = Cam.barrel(weapon) else barrelWhy = weaponWhy end
    info.weapon, info.weaponWhy, info.barrel, info.barrelWhy = weapon ~= nil, weaponWhy, barrel ~= nil, barrelWhy
    local alive = world and Cam.isAlive()
    if not world and Cam.body then Cam.bodyDestroy() end
    if not barrel and not alive then
        if Cam.body then Cam.bodyDestroy() end
        hiding(false)
        Cam.reset()
        info.final, info.deg, info.studs = nil, 0, 0
        return
    end
    local target = 1
    local aiming = weapon and Cam.aiming(weapon)
    if s.onlyAiming and not aiming then target = 0 end
    if s.noScope and aiming and Cam.zoom(weapon) > 1.2 then target = 0 end
    Cam.amount = Cam.amount + (target - Cam.amount) * (1 - math.exp(-dt * 12))
    hiding(world and Cam.amount > 0.05)
    local idle = not world and s.strength <= 0 and s.position <= 0 and s.sway <= 0
    if Cam.amount < 0.002 or idle then
        Cam.clear()
        info.final, info.deg, info.studs = nil, 0, 0
        return
    end
    local head = world and Cam.bodyHead(frame, dt, now) or nil
    if world and not barrel and not head then note("world", "world character: no weapon/viewmodel or body motion source, view stays on the game camera") end
    local ref = barrel or frame

    local gx, gy, gz = frame:ToOrientation()
    local bx, by, bz = ref:ToOrientation()
    local dx, dy, dz = bx - gx, wrap(by - gy), wrap(bz - gz)
    local size = math.sqrt(dx * dx + dy * dy)
    local rawTurn = Vector3.new(dx, dy, (s.roll or world) and dz or 0)
    if size > MAX_TURN then rawTurn = Vector3.new(dx * MAX_TURN / size, dy * MAX_TURN / size, rawTurn.Z) end
    local cur = Vector3.new(dx, dy, dz)
    local rel = frame:PointToObjectSpace(ref.Position)
    local restAlpha = 1 - math.exp(-dt * REST_RATE)
    Cam.rest = Cam.rest or rel
    Cam.swayRest = Cam.swayRest or cur
    local motion = Vector3.zero
    local rawSway = Vector3.zero
    if not aiming then
        motion = limit(rel - Cam.rest, MAX_SHIFT)
        local dev = cur - Cam.swayRest
        rawSway = Vector3.new(wrap(dev.X), wrap(dev.Y), wrap(dev.Z))
        rawSway = rawSway + Vector3.new(motion.Y * SWAY_MOVE, -motion.X * SWAY_MOVE, -motion.X * SWAY_MOVE * 0.6)
        Cam.rest = Cam.rest + (rel - Cam.rest) * restAlpha
        Cam.swayRest = Cam.swayRest + Vector3.new(wrap(cur.X - Cam.swayRest.X), wrap(cur.Y - Cam.swayRest.Y), wrap(cur.Z - Cam.swayRest.Z)) * restAlpha
    end
    local rawPos = Vector3.zero
    if world then
        if head then
            if not aiming then
                local delta = frame:VectorToObjectSpace(head.Position + EYE - frame.Position)
                Cam.bodyRest = Cam.bodyRest or delta
                rawPos = limit(delta * math.min(s.strength, 1) + (delta - Cam.bodyRest) * math.max(s.strength - 1, 0), MAX_BODY)
                Cam.bodyRest = Cam.bodyRest + (delta - Cam.bodyRest) * restAlpha
            end
        else
            rawPos = motion * s.strength
        end
    elseif s.position > 0 then
        rawPos = rel * s.position
    end

    if Cam.smoothed and s.smoothing > 0 then
        local rate = 1 + 59 * (1 - math.clamp(s.smoothing, 0, 1)) ^ 2
        local alpha = 1 - math.exp(-dt * rate)
        local old = Cam.smoothed
        Cam.smoothed = { turn = old.turn + (rawTurn - old.turn) * alpha, pos = old.pos + (rawPos - old.pos) * alpha, sway = old.sway + (rawSway - old.sway) * alpha }
    else
        Cam.smoothed = { turn = rawTurn, pos = rawPos, sway = rawSway }
    end

    local gain = (world and math.min(s.strength, 1) or s.strength) * Cam.amount
    local swayGain = s.sway * Cam.amount
    local turn, sway = Cam.smoothed.turn, Cam.smoothed.sway
    local devX, devY = turn.X * gain + sway.X * swayGain, turn.Y * gain + sway.Y * swayGain
    local devSize = math.sqrt(devX * devX + devY * devY)
    if devSize > MAX_TURN then devX, devY = devX * MAX_TURN / devSize, devY * MAX_TURN / devSize end
    local pitch = math.clamp(gx + devX, -MAX_PITCH, MAX_PITCH)
    local rotation = CFrame.fromOrientation(pitch, gy + devY, gz + turn.Z * gain + sway.Z * swayGain)
    local origin = frame:PointToWorldSpace(Cam.smoothed.pos * Cam.amount)
    if world then origin = origin + rotation.LookVector * (s.forward * Cam.amount) end
    camera.CFrame = CFrame.new(origin) * rotation
    Cam.written = camera.CFrame
    Cam.writtenAt, Cam.pending, Cam.pendingSource = now, true, source
    info.final = Cam.written
    info.studs = (Cam.written.Position - frame.Position).Magnitude
    info.deg = math.deg(math.acos(math.clamp(frame.LookVector:Dot(Cam.written.LookVector), -1, 1)))
end

function Cam.run(source, dt)
    if not Cam.running then return end
    local ok, problem = pcall(Cam.step, source, dt)
    if not ok then note("step" .. tostring(problem), "step error:", problem) end
    if debugOn() then pcall(Cam.report, os.clock()) end
end

local API = {}

function API.Start()
    if Cam.running then return true end
    Cam.reset()
    Cam.token = Cam.token + 1
    Cam.prio = lastPriority()
    Cam.passes = { hook = 0, bind = 0, rs = 0 }
    Cam.kept, Cam.lost, Cam.lostBy = 0, 0, nil
    Cam.running = true
    Cam.load()
    Cam.attachAt = 0
    Cam.attach(os.clock())
    local unbind, native = bind(Cam.bindName, Cam.prio, function(dt) Cam.run("bind", dt) end)
    Cam.unbind = unbind
    if not native then note("bind", "BindToRenderStep failed, using RenderStepped only") end
    local okSignal, connection = pcall(function()
        return RunService.RenderStepped:Connect(function(dt) Cam.run("rs", dt) end)
    end)
    Cam.rsConn = okSignal and connection or nil
    return true
end

function API.Stop()
    if not Cam.running then return end
    Cam.running = false
    Cam.token = Cam.token + 1
    if Cam.unbind then pcall(Cam.unbind) end
    Cam.unbind = nil
    if Cam.rsConn then pcall(function() Cam.rsConn:Disconnect() end) end
    Cam.rsConn = nil
    Cam.detach()
    Cam.bodyDestroy()
    local camera = Workspace.CurrentCamera
    if camera and Cam.written and Cam.gameCFrame then
        local ok, untouched = pcall(same, camera.CFrame, Cam.written)
        if ok and untouched then pcall(function() camera.CFrame = Cam.gameCFrame end) end
    end
    Cam.gameCFrame = nil
    if camera then pcall(Cam.applyFov, camera, 0) end
    Cam.restoreHidden("view")
    Cam.restoreHidden("hat")
    Cam.reset()
end

local LIMITS = { strength = 5, sway = 5, forward = 2, fov = 120 }

function API.Set(key, value)
    local s = Cam.settings
    if s[key] == nil then return end
    if type(s[key]) == "number" then
        value = tonumber(value)
        if not value then return end
        value = math.clamp(value, 0, LIMITS[key] or 1)
    elseif type(s[key]) == "string" then
        if value ~= "Barrel" and value ~= "World character" then return end
    else
        value = value == true
    end
    s[key] = value
end

function API.Sync(read)
    API.Set("strength", read("strength", 2.5))
    API.Set("smoothing", read("smooth", 0))
    API.Set("position", read("position", 0))
    API.Set("roll", read("roll", false))
    API.Set("onlyAiming", read("aiming", false))
    API.Set("noScope", read("noscope", false))
    API.Set("mode", read("mode", "Barrel"))
    API.Set("hideViewmodel", read("viewmodel", true))
    API.Set("hideHat", read("hat", true))
    API.Set("forward", read("forward", 0.5))
    API.Set("fov", read("fov", 0))
    API.Set("sway", read("sway", 1))
    API.Set("debug", read("debug", false))
    local on = read("on", false) == true
    if on and not Cam.running then API.Start() elseif not on and Cam.running then API.Stop() end
end

function API.GameCFrame()
    if not Cam.running then return nil end
    local camera = Workspace.CurrentCamera
    if camera and Cam.written then
        local current = camera.CFrame
        if not same(current, Cam.written) then return current end
    end
    return Cam.gameCFrame
end

function API.Active()
    return Cam.running
end

function API.Destroy()
    API.Stop()
    for _, connection in ipairs(Cam.keys) do pcall(function() connection:Disconnect() end) end
    Cam.keys = {}
    if getgenv().PhantomCamApi == API then getgenv().PhantomCamApi = nil end
    if getgenv().PhantomCam == API then getgenv().PhantomCam = nil end
end

getgenv().PhantomCamApi = API

if HOST then return API end


local function standalone()
    do
        local function inGameVm()
            local ok, request = pcall(function() return getrenv().shared.require end)
            return ok and type(request) == "function"
        end
        local inActor = getgenv().PC_INACTOR
        getgenv().PC_INACTOR = nil
        if not inActor and not inGameVm() then
            local source = getgenv().PC_SOURCE
            if (type(source) ~= "string" or #source < 500) and SOURCE_URL ~= "" then
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
            if type(source) ~= "string" or #source < 500 then
                warn("[PhantomCam] Not inside the game's actor and no source to relaunch with. Set getgenv().PC_SOURCE")
            elseif not run or type(create_comm_channel) ~= "function" or type(get_comm_channel) ~= "function" then
                warn("[PhantomCam] This executor cannot run code inside actors")
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
                                getgenv().PC_INACTOR = true
                                pcall(run, actor, "getgenv().PC_INACTOR = true\n" .. source)
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
                if found then return end
                warn("[PhantomCam] No actor with the game's modules was found")
            end
        end
    end

    local config = type(getgenv().PhantomCamConfig) == "table" and getgenv().PhantomCamConfig or {}
    local fields = {
        Mode = "mode", Strength = "strength", Smooth = "smoothing", Position = "position", Roll = "roll",
        Viewmodel = "hideViewmodel", Hat = "hideHat", Forward = "forward", FOV = "fov",
        OnlyAiming = "onlyAiming", NoScope = "noScope", Sway = "sway", Debug = "debug",
    }
    API.Set("mode", "World character")
    API.Set("smoothing", 0.25)
    for field, key in pairs(fields) do
        if config[field] ~= nil then API.Set(key, config[field]) end
    end

    local function keyOf(value, default)
        if typeof(value) == "EnumItem" then return value end
        if type(value) == "string" then
            local ok, item = pcall(function() return Enum.KeyCode[value] end)
            if ok and item then return item end
        end
        return default
    end
    local toggleKey = keyOf(config.ToggleKey, Enum.KeyCode.P)
    local unloadKey = keyOf(config.UnloadKey, Enum.KeyCode.End)

    table.insert(Cam.keys, UserInputService.InputBegan:Connect(function(input, processed)
        if processed or UserInputService:GetFocusedTextBox() then return end
        if input.KeyCode == unloadKey then
            API.Destroy()
        elseif input.KeyCode == toggleKey then
            if Cam.running then API.Stop() else API.Start() end
        end
    end))

    getgenv().PhantomCam = API
    API.Start()
end

local ok, problem = xpcall(standalone, debug.traceback)
if not ok then warn("[PhantomCam] FAILED:\n" .. tostring(problem)) end

return API
]==]

function PhantomCam.load()
    local function valid(api) return type(api) == "table" and type(api.Sync) == "function" end
    local api
    getgenv().PhantomCamHost = true
    local chunk = loadstring(PHANTOMCAM_SOURCE)
    if chunk then
        local okRun, result = pcall(chunk)
        if okRun and valid(result) then api = result end
    end
    if not api then
        local okRemote, result = pcall(loadRemote, "phantomcam.lua")
        if okRemote and valid(result) then api = result end
    end
    getgenv().PhantomCamHost = nil
    if not api then return false end
    PhantomCam.api = api
    Util.onUnload(api.Destroy)
    return true
end

function PhantomCam.read(name, default)
    return flag(name == "on" and "misc_phantomcam" or "misc_phantomcam_" .. name, default)
end

function PhantomCam.sync(now)
    if not PhantomCam.api then
        if not flag("misc_phantomcam", false) or now < PhantomCam.retryAt then return end
        PhantomCam.retryAt = now + 10
        if not PhantomCam.load() then
            pcall(function() Library:Notify("PhantomCam could not be loaded from the repo", 5) end)
            pcall(function() Toggles.misc_phantomcam:SetValue(false) end)
            return
        end
    end
    PhantomCam.api.Sync(PhantomCam.read)
end

local Loop = { last = os.clock(), labelAt = 0, retryAt = 0, retryDelay = 3, hookAt = 0, frames = 0, fpsAt = os.clock(), fps = 60 }

function Loop.step()
    Game.frame = Game.frame + 1
    local now = os.clock()
    local dt = math.clamp(now - Loop.last, 1 / 240, 0.1)
    Loop.last = now
    Loop.frames = Loop.frames + 1
    if now - Loop.fpsAt >= 0.5 then
        Loop.fps = math.floor(Loop.frames / (now - Loop.fpsAt))
        Loop.frames, Loop.fpsAt = 0, now
    end

    local cam = Game.camera()
    if not cam then return end
    Util.guard("phantomcam", PhantomCam.sync, now)
    Visible.refresh(now)
    local center = cam.ViewportSize / 2

    Util.guard("world", World.apply, dt, now)
    Util.guard("weather", World.stepWeather, cam, now)

    if not Game.ready then
        Barrel.valid = false
        Util.guard("crosshair", World.stepCrosshair, center, now, dt)
        if now - Loop.retryAt > Loop.retryDelay then
            Loop.retryAt = now
            Loop.retryDelay = math.min(Loop.retryDelay * 2, 30)
            Game.load()
            Game.hookNetwork()
            if Game.ready then
                if Status.core then Status.core:SetText("Core: " .. tostring(Game.summary)) end
                pcall(function() Library:Notify("Core " .. tostring(Game.summary), 4) end)
            end
        end
        Legit.circle.Visible, Legit.circleFill.Visible = false, false
        Silent.ring.Visible, Silent.ringFill.Visible = false, false
        ESP.clear()
        Util.guard("items", Items.step, cam, now)
        Util.guard("feedback", Feedback.step, cam, center, now)
        Util.guard("tracers", Tracers.step, now)
        Util.guard("nades", Nades.step, cam, now)
        return
    end

    if now - Loop.hookAt > 3 then
        Loop.hookAt = now
        Util.guard("hooks", Feedback.hook)
        Util.guard("nadehook", Nades.hook)
        Util.guard("knifehook", Knife.hook)
        Util.guard("localhook", Local.hook)
    end

    local records = Entities.update()
    Util.guard("fov", World.stepFov, dt)
    Legit.read()
    local gameCam = Game.gameCamera()
    Util.guard("barrel", Barrel.update, cam, gameCam, Game.weapon(), now)
    local crossAt = center
    if flag("cross_barrel", false) then crossAt = Barrel.point(flag("cross_barrel_pt", "Aim hit"), center) end
    Util.guard("crosshair", World.stepCrosshair, crossAt, now, dt)
    Util.guard("aim", Legit.stepAim, dt, cam, now, records, center)
    Util.guard("recoil", Legit.stepRecoil, now)
    Util.guard("trigger", Legit.stepTrigger, cam, now, records)
    Util.guard("esp", ESP.step, cam, now, records)
    Util.guard("items", Items.step, cam, now)
    Util.guard("feedback", Feedback.step, cam, center, now)
    Util.guard("tracers", Tracers.step, now)
    Util.guard("nades", Nades.step, cam, now)
    Util.guard("localvis", Local.step, now)
    Util.guard("corpse", Corpse.step, now)
    Util.guard("killfx", KillFx.step, now)

    if now - Loop.labelAt > 0.2 then
        Loop.labelAt = now
        local weapon = Game.weapon()
        local text = "Weapon: " .. tostring(weapon and weapon.weaponName or "none")
        local speed = Game.stat(weapon, "bulletspeed")
        if type(speed) == "number" then text = text .. " | " .. math.floor(speed) .. " studs/s" end
        if Status.weapon and Loop.weaponText ~= text then Loop.weaponText = text; Status.weapon:SetText(text) end
        text = "Target: none"
        if Legit.target and Legit.record then
            text = string.format("Target: %s | %d hp | %dm", Legit.record.name, math.floor(Legit.record.health), math.floor((Legit.record.torso.Position - Game.eye(cam).Position).Magnitude * STUDS_TO_M))
        end
        if Status.target and Loop.targetText ~= text then Loop.targetText = text; Status.target:SetText(text) end
        text = string.format("Recoil: %.1f / %.1f deg", math.deg(Recoil.shown.X), math.deg(Recoil.shown.Y))
        if Status.recoil and Loop.recoilText ~= text then Loop.recoilText = text; Status.recoil:SetText(text) end
    end
end

Nades.hook()

local function loopFrame()
    Stretch.apply(Game.camera())
    local ok, problem = pcall(Loop.step)
    if not ok then Util.note("loop" .. tostring(problem), "frame:", problem) end
    Stretch.restore(Game.camera())
end

local HookChain = {}

function HookChain.add(object, id, priority, fn)
    local chain = rawget(object, "__hookchain")
    if not chain then
        chain = { list = {}, orig = rawget(object, "postStep") }
        chain.wrapper = function(self, dt)
            local orig = chain.orig
            local a, b = nil, nil
            if orig then a, b = orig(self, dt) end
            local snapshot = table.move(chain.list, 1, #chain.list, 1, {})
            for _, entry in ipairs(snapshot) do pcall(entry.fn, self, dt) end
            return a, b
        end
        local set, problem = pcall(function() object.postStep = chain.wrapper end)
        if not set then return false, problem end
        rawset(object, "__hookchain", chain)
    end
    for index, entry in ipairs(chain.list) do
        if entry.id == id then table.remove(chain.list, index) break end
    end
    table.insert(chain.list, { id = id, priority = priority, fn = fn })
    table.sort(chain.list, function(a, b) return a.priority < b.priority end)
    return true
end

function HookChain.has(object, id)
    local chain = rawget(object, "__hookchain")
    if not chain then return false end
    for _, entry in ipairs(chain.list) do
        if entry.id == id then return true end
    end
    return false
end

function HookChain.remove(object, id)
    local chain = rawget(object, "__hookchain")
    if not chain then return end
    for index, entry in ipairs(chain.list) do
        if entry.id == id then table.remove(chain.list, index) break end
    end
    if #chain.list == 0 and rawget(object, "postStep") == chain.wrapper then
        pcall(function() object.postStep = chain.orig end)
        rawset(object, "__hookchain", nil)
    end
end

local LateCam = { object = nil, gen = 0, calls = 0, hookedAt = 0, fovWritten = nil, fovGame = nil, sigCam = nil, sigConn = nil, writing = false }

function LateCam.wanted()
    return World.fov.final ~= nil or flag("world_stretch", false)
end

function LateCam.fovTarget()
    local want = World.fov.final
    if want and flag("misc_phantomcam", false) and PhantomCam.read("fov", 0) >= 20 then return nil end
    return want
end

function LateCam.unwatch()
    local conn = LateCam.sigConn
    LateCam.sigCam, LateCam.sigConn = nil, nil
    if conn then pcall(function() conn:Disconnect() end) end
end

function LateCam.watch(cam)
    if LateCam.sigCam == cam and LateCam.sigConn then return end
    LateCam.unwatch()
    if not cam then return end
    local ok, conn = pcall(function()
        return cam:GetPropertyChangedSignal("FieldOfView"):Connect(function()
            if LateCam.writing or LateCam.sigCam ~= cam then return end
            local want = LateCam.fovTarget()
            if not want or math.abs(cam.FieldOfView - want) <= 0.01 then return end
            LateCam.fovGame = cam.FieldOfView
            LateCam.writing = true
            pcall(function() cam.FieldOfView = want end)
            LateCam.writing = false
            LateCam.fovWritten = want
        end)
    end)
    if ok and conn then LateCam.sigCam, LateCam.sigConn = cam, conn end
end

function LateCam.pass()
    local cam = Game.camera()
    if not cam then return end
    local want = LateCam.fovTarget()
    if want then LateCam.watch(cam) else LateCam.unwatch() end
    if want then
        if cam.FieldOfView ~= LateCam.fovWritten then LateCam.fovGame = cam.FieldOfView end
        if cam.FieldOfView ~= want then
            LateCam.writing = true
            cam.FieldOfView = want
            LateCam.writing = false
        end
        LateCam.fovWritten = want
    elseif LateCam.fovWritten then
        if not World.fov.final and LateCam.fovGame and cam.FieldOfView == LateCam.fovWritten then cam.FieldOfView = LateCam.fovGame end
        LateCam.fovWritten = nil
    end
    if Stretch.written and Stretch.base and flag("world_stretch", false) and sameFrame(cam.CFrame, Stretch.written) then return end
    Stretch.apply(cam)
end

function LateCam.detach()
    LateCam.gen = LateCam.gen + 1
    local object = LateCam.object
    LateCam.object = nil
    if object then HookChain.remove(object, "latecam") end
end

function LateCam.attach(now)
    if not Game.mods.CameraInterface then
        Util.note("camera-interface", "camera: CameraInterface unavailable, FOV/stretch use render-step fallback only")
        return
    end
    local object = Game.gameCamera()
    if not object then return end
    if LateCam.object == object and HookChain.has(object, "latecam") then
        if LateCam.calls == 0 and LateCam.wanted() and now - LateCam.hookedAt > 3 and Game.localAlive() then
            Util.note("camera-hookdead", "camera: postStep hook never called by the game, using render-step fallback")
        end
        return
    end
    if LateCam.object and LateCam.object ~= object then HookChain.remove(LateCam.object, "latecam") end
    local gen = LateCam.gen + 1
    LateCam.gen = gen
    local function hook()
        if LateCam.gen == gen then
            LateCam.calls = LateCam.calls + 1
            Util.guard("latecam", LateCam.pass)
        end
    end
    local set, problem = HookChain.add(object, "latecam", 20, hook)
    if not set then
        Util.note("camera-set", "camera: cannot hook postStep (" .. tostring(problem) .. "), using render-step fallback")
        return
    end
    if LateCam.object ~= object then LateCam.calls, LateCam.hookedAt = 0, now end
    LateCam.object = object
end

function LateCam.fallback()
    if LateCam.wanted() then LateCam.attach(os.clock()) elseif LateCam.object then LateCam.detach() end
    Util.guard("latecam", LateCam.pass)
end

local LOOP_BIND = Util.randomName()
local okCameraPriority, cameraPriority = pcall(function() return Enum.RenderPriority.Camera.Value end)
if okCameraPriority and type(cameraPriority) == "number" and pcall(function() RunService:BindToRenderStep(LOOP_BIND, cameraPriority + 2, loopFrame) end) then
    Util.onUnload(function() pcall(function() RunService:UnbindFromRenderStep(LOOP_BIND) end) end)
else
    Util.track(RunService.RenderStepped:Connect(loopFrame))
end

do
    local late = LateCam.fallback
    local function early() Stretch.restore(Game.camera()) end
    local lateName, earlyName = Util.randomName(), Util.randomName()
    local okLast, last = pcall(function() return Enum.RenderPriority.Last.Value end)
    local okFirst, first = pcall(function() return Enum.RenderPriority.First.Value end)
    if okLast and type(last) == "number" and pcall(function() RunService:BindToRenderStep(lateName, last + 10, late) end) then
        Util.onUnload(function() pcall(function() RunService:UnbindFromRenderStep(lateName) end) end)
    else
        Util.track(RunService.RenderStepped:Connect(late))
    end
    if okFirst and type(first) == "number" and pcall(function() RunService:BindToRenderStep(earlyName, first, early) end) then
        Util.onUnload(function() pcall(function() RunService:UnbindFromRenderStep(earlyName) end) end)
    end
    Util.onUnload(function()
        LateCam.detach()
        LateCam.unwatch()
        local cam = Game.camera()
        if cam and LateCam.fovWritten and LateCam.fovGame and cam.FieldOfView == LateCam.fovWritten then pcall(function() cam.FieldOfView = LateCam.fovGame end) end
        LateCam.fovWritten = nil
        Stretch.restore(cam)
    end)
end

pcall(function() SaveManager:LoadAutoloadConfig() end)
pcall(function() Library:SetWatermark("Aster") end)
pcall(function() Library:SetWatermarkVisibility(Toggles.menu_watermark == nil or Toggles.menu_watermark.Value) end)
if not introPlayed and not Library.Toggled then pcall(function() Library:Toggle() end) end
Library:Notify("Aster loaded | core " .. tostring(Game.summary), 5)

end, debug.traceback)
if not __ok then
    warn("[Aster] FAILED:\n" .. tostring(__err))
end
