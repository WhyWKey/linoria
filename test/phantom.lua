
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

function Util.notify(info)
    if type(Library.NotifyById) == "table" then
        local ok, note = pcall(Library.Notify, Library, info)
        if ok then return note end
    end
    local text = tostring(info.Text or "")
    if info.Title then text = info.Title .. ": " .. text end
    pcall(function() Library:Notify(text, info.Duration or 5) end)
    return nil
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
            AllowNull = info.Default == nil, Tooltip = info.Tooltip, Callback = info.Callback, Searchable = info.Searchable,
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
    function wrapped:Viewport(info)
        if type(group.AddViewport) ~= "function" then return nil end
        bump()
        return group:AddViewport(info.Flag, info)
    end
    function wrapped:Gallery(info)
        if type(group.AddGallery) ~= "function" then return nil end
        bump()
        return group:AddGallery(info.Flag, info)
    end
    function wrapped:Depends(conds, build)
        local target, box = wrapped, nil
        if type(group.AddDependencyBox) == "function" then
            local ok, made = pcall(group.AddDependencyBox, group)
            if ok and type(made) == "table" then target, box = wrapGroup(made, page, side), made end
        end
        build(target)
        if box then
            local list = {}
            for _, cond in ipairs(conds) do
                local control = Toggles[cond[1]] or Options[cond[1]]
                if control then list[#list + 1] = { control, cond[2] } end
            end
            pcall(box.SetupDependencies, box, list)
        end
        return target
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
    "HudScreenGui", "PlayerSettingsInterface", "WeaponUtils", "ContentUtils", "RoundSystemClientEvents" }

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

function Game.aimProgress(weapon)
    local character = type(weapon) == "table" and weapon._characterObject
    if type(character) ~= "table" then
        local interface = Game.mods.CharacterInterface
        local ok, object = pcall(function() return interface and interface.getCharacterObject() end)
        character = ok and object
    end
    if type(character) == "table" and type(character.getSpring) == "function" then
        local ok, value = pcall(function() return character:getSpring("masteraimspring").p end)
        if ok and type(value) == "number" and value == value then return math.clamp(value, 0, 1) end
    end
    return Game.aiming(weapon) and 1 or 0
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
            if method == "bullethit" and Game.onBulletHit then
                local _, player, position, part = ...
                pcall(Game.onBulletHit, player, position, part)
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

function Entities.live(entry)
    local okAlive, alive = pcall(entry.isAlive, entry)
    if not (okAlive and alive) then return false end
    if type(entry.isReady) == "function" then
        local okReady, ready = pcall(entry.isReady, entry)
        if okReady and not ready then return false end
    end
    return true
end

function Entities.parked(position)
    if position == Vector3.zero then return true end
    local now = os.clock()
    if Entities.floor == nil or now - (Entities.floorAt or 0) > 5 then
        Entities.floorAt = now
        local ok, floor = pcall(function() return Workspace.FallenPartsDestroyHeight end)
        Entities.floor = ok and type(floor) == "number" and floor or false
    end
    return Entities.floor and position.Y < Entities.floor or false
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
        if not Entities.live(entry) then return end
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
        if Entities.parked(position) then return end

        local health, maxHealth = 100, 100
        local okHealth, current, maximum = pcall(entry.getHealth, entry)
        if okHealth and type(current) == "number" then health, maxHealth = current, maximum or 100 end

        local record = Entities.byPlayer[player]
        if not record then
            record = { player = player, name = player.Name }
            Entities.byPlayer[player] = record
        end
        record.seen = true
        record.entry, record.hash, record.torso, record.head, record.object = entry, hash, torso, head, object
        record.rendered, record.pos = rendered, position
        record.enemy = Game.isEnemy(entry, player)
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
Visible.espParams = RaycastParams.new()
Visible.espParams.FilterType = Enum.RaycastFilterType.Exclude
pcall(function() Visible.espParams.RespectCanCollide = true end)
pcall(function() Visible.espParams.IgnoreWater = true end)
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
    for _, name in ipairs({ "Ignore", "Players", "Roots" }) do add(Workspace:FindFirstChild(name)) end
    local root = Game.rootPart()
    if root then add(root.Parent) end
    pcall(function() add(LocalPlayer.Character) end)
    Visible.espParams.FilterDescendantsInstances = table.clone(list)
    add(Workspace.Terrain)
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
    if cached then
        cached[1], cached[2] = now, result
    else
        Visible.cache[part] = { now, result }
    end
    return result
end

function Visible.exit(position, unit, instance)
    local ok, size = pcall(function() return instance.Size.Magnitude end)
    if not ok or type(size) ~= "number" then return nil end
    Visible.exitParams.FilterDescendantsInstances = { instance }
    return Workspace:Raycast(position + unit * size, -unit * size, Visible.exitParams)
end

function Visible.trace(origin, point, depth, params)
    params = params or Visible.params
    local vector = (point - origin) * 0.998
    local length = vector.Magnitude
    if length < 0.05 then return 0, 0 end
    local unit = vector / length
    local from, remaining = origin, vector
    local left, total, walls, seen = depth or 0, 0, 0, {}
    for _ = 1, 12 do
        local hit = Workspace:Raycast(from, remaining, params)
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
            if part and part.Parent and Visible.trace(origin, part.Position, nil, Visible.espParams) then
                value = true
                break
            end
        end
    end
    if cached then
        cached.at, cached.frame, cached.value = now, Game.frame, value
    else
        record.visCache = { at = now, frame = Game.frame, value = value }
    end
    return value
end

local Draw = { all = {}, hasApi = (type(Drawing) == "table" or type(Drawing) == "userdata") }
local SINK = setmetatable({}, { __newindex = function() end })

function Draw.wrap(object)
    local shadow, bound = {}, {}
    return setmetatable({}, {
        __index = function(_, key)
            local value = object[key]
            if type(value) ~= "function" then return value end
            local fn = bound[key]
            if not fn then
                fn = function(_, ...) return value(object, ...) end
                bound[key] = fn
            end
            return fn
        end,
        __newindex = function(_, key, value)
            if value ~= nil and shadow[key] == value then return end
            object[key] = value
            shadow[key] = value
        end,
    })
end

function Draw.new(kind, props)
    if not Draw.hasApi then return SINK end
    local ok, object = pcall(Drawing.new, kind)
    if not ok or not object then return SINK end
    object = Draw.wrap(object)
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
    local shadow = {}
    return setmetatable(proxy, { __newindex = function(_, prop, value)
        local set = apply[prop]
        if not set or (value ~= nil and shadow[prop] == value) then return end
        if pcall(set, value) then shadow[prop] = value end
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
    Barrel.progress = Game.aimProgress(weapon)
    Barrel.weight = Barrel.blend(Barrel.progress, flag("legit_barrel_ads", 0.9))
    Barrel.valid = true
end

function Barrel.smooth(x)
    x = math.clamp(x, 0, 1)
    return x * x * (3 - 2 * x)
end

function Barrel.blend(progress, threshold)
    if threshold <= 0 then return 1 end
    local hip = 1 - Barrel.smooth((progress - 0.02) / 0.1)
    local top = threshold + (1 - threshold) * 0.75
    local scoped = top - threshold > 1e-3 and Barrel.smooth((progress - threshold) / (top - threshold)) or (progress >= threshold and 1 or 0)
    return math.max(hip, scoped)
end

function Barrel.mix(eye, camLook)
    local weight = Barrel.valid and Barrel.weight or 0
    if weight >= 1 then return Barrel.fire, Barrel.look end
    if weight <= 0 then return eye, nil end
    local look = camLook + (Barrel.look - camLook) * weight
    return eye + (Barrel.fire - eye) * weight, look.Magnitude > 1e-3 and look.Unit or Barrel.look
end

function Barrel.center(mode, center)
    local weight = Barrel.valid and Barrel.weight or 0
    local point = mode == "Muzzle" and Barrel.muzzle2d or Barrel.hit2d
    if weight <= 0 or not point then return center end
    if weight >= 1 then return point end
    return center + (point - center) * weight
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
local BOUND_PARTS = { "Head", "Torso", "Left Leg", "Right Leg" }
local BOUND_SIDES, BOUND_LIFTS = { -2, 2 }, { Vector3.new(0, -1, 0), Vector3.new(0, 1, 0) }
local STATIC_CORNERS, PART_CORNERS = {}, {}
for _, sx in ipairs({ -1, 1 }) do
    for _, sy in ipairs({ -1, 1 }) do
        for _, sz in ipairs({ -1, 1 }) do
            STATIC_CORNERS[#STATIC_CORNERS + 1] = Vector3.new(2 * sx, 2.5 * sy, 1.25 * sz)
            for name, size in pairs(PART_SIZES) do
                local half = size * 0.5
                PART_CORNERS[name] = PART_CORNERS[name] or {}
                table.insert(PART_CORNERS[name], Vector3.new(half.X * sx, half.Y * sy, half.Z * sz))
            end
        end
    end
end
local CORNER_SEGMENTS = { { 0, 0, 1, 0 }, { 0, 0, 0, 1 }, { 1, 0, -1, 0 }, { 1, 0, 0, 1 }, { 0, 1, 1, 0 }, { 0, 1, 0, -1 }, { 1, 1, -1, 0 }, { 1, 1, 0, -1 } }

function ESP.bonePoints(hash, points)
    local head, torso = hash.Head, hash.Torso
    if not (head and torso and head.Parent and torso.Parent) then return nil end
    local center = torso.Position
    if points then
        for name in pairs(points) do points[name] = nil end
    else
        points = {}
    end
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

local function widen(cam, world, minX, minY, maxX, maxY)
    local point = cam:WorldToViewportPoint(world)
    if not (point.Z > 0) then return minX, minY, maxX, maxY, true end
    local px, py = point.X, point.Y
    if px < minX then minX = px end
    if px > maxX then maxX = px end
    if py < minY then minY = py end
    if py > maxY then maxY = py end
    return minX, minY, maxX, maxY, false
end

function ESP.bounds(cam, record, static)
    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
    local behind, back = false, false
    local center = record.torso.Position
    if static then
        local look = record.torso.CFrame.LookVector
        local frame = CFrame.new(center + Vector3.new(0, -0.5, 0)) * CFrame.Angles(0, math.atan2(-look.X, -look.Z), 0)
        for _, corner in ipairs(STATIC_CORNERS) do
            minX, minY, maxX, maxY, back = widen(cam, frame:PointToWorldSpace(corner), minX, minY, maxX, maxY)
            behind = behind or back
        end
    else
        for _, name in ipairs(BOUND_PARTS) do
            local part = record.hash[name]
            if part and part.Parent and (part.Position - center).Magnitude < 10 then
                local frame = part.CFrame
                for _, corner in ipairs(PART_CORNERS[name]) do
                    minX, minY, maxX, maxY, back = widen(cam, frame:PointToWorldSpace(corner), minX, minY, maxX, maxY)
                    behind = behind or back
                end
            end
        end
        local right = record.torso.CFrame.RightVector
        for _, side in ipairs(BOUND_SIDES) do
            local edge = center + right * side
            for _, lift in ipairs(BOUND_LIFTS) do
                minX, minY, maxX, maxY, back = widen(cam, edge + lift, minX, minY, maxX, maxY)
                behind = behind or back
            end
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
    local o = { all = {}, strips = {}, corners = {}, cornerEdges = {}, bones = {}, boneEdges = {}, capEdges = {}, capFills = {}, hidden = false,
        on = {}, points = {}, depth = {}, screen = {}, front = {}, gradColors = {} }
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

local function setLine(on, drawing, from, to, color, alpha, thick)
    drawing.From, drawing.To, drawing.Color, drawing.Transparency = from, to, color, alpha
    if thick then drawing.Thickness = thick end
    on[drawing] = true
end

local function espTint(S, visible, base)
    return S.visOverride and (visible and S.visColor or S.occColor) or base
end

local Chams = { objs = {}, pool = {}, container = nil }
local CHAM_PARTS = { "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }
local ChamStyle = {
    objs = {}, pool = {}, allowed = {}, order = {}, frame = 0, cfg = {}, rate = 1 / 20, styles = {},
    names = { "Classic", "Toon", "Ghost", "Glow shells" },
    viewNames = { "Classic", "Glow shells" },
    ghostMax = 8, shellMax = 3,
    keyLight = Vector3.new(0.45, -0.75, -0.5).Unit, rimLight = Vector3.new(0.7, -0.35, 0.6).Unit,
}

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
    ChamStyle.drop(player)
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

function Chams.style(slot, part, name, cfg, S, seen)
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
    if seen then
        layers.behind.Color3, layers.behind.Transparency = cfg.chamVis, cfg.chamVisT
    else
        layers.behind.Color3, layers.behind.Transparency = cfg.chamHid, cfg.chamHidT
    end
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

function Chams.signature(cfg, S)
    return table.concat({
        tostring(cfg.chamVis), cfg.chamVisT, tostring(cfg.chamHid), cfg.chamHidT,
        S.chamMode, S.chamGrow, tostring(S.chamGlow), S.chamGlowSize, tostring(S.chamRound), S.chamHead,
    }, "|")
end

function ChamStyle.nearer(a, b) return a.styleDist < b.styleDist end

ChamStyle.sigKeys = { "c1", "c2", "int", "walls", "visColor", "visAlpha", "occColor", "occAlpha", "toonGrow", "ghostCount", "ghostGradient", "glowShells", "glowOutline" }

function ChamStyle.read()
    local c = ChamStyle.cfg
    c.style = flag("chams_style", "Classic")
    if not ChamStyle.styles[c.style] then c.style = "Classic" end
    if c.style == "Classic" then return c end
    c.c1 = flag("chams_style_color", Color3.fromRGB(0, 220, 255))
    c.c2 = flag("chams_style_color2", Color3.fromRGB(255, 60, 200))
    c.speed = math.max(flag("chams_style_speed", 1), 0.05)
    c.int = flag("chams_style_int", 1)
    c.walls = flag("chams_style_walls", true)
    c.cap = math.max(1, math.floor(flag("chams_style_cap", 8)))
    c.vis = flag("chams_style_vis", false)
    c.visColor, c.visAlpha = flag("chams_style_vis_color", Color3.fromRGB(80, 255, 140)), Util.alpha("chams_style_vis_color", 0)
    c.occColor, c.occAlpha = flag("chams_style_occ_color", Color3.fromRGB(255, 70, 110)), Util.alpha("chams_style_occ_color", 0.25)
    c.toonGrow = flag("chams_toon_outline", 0.3)
    c.toonLine = flag("chams_toon_outline_color", Color3.fromRGB(12, 12, 18))
    c.toonShade = flag("chams_toon_shade", 0.45)
    c.toonRim = flag("chams_toon_rim", true)
    c.ghostCount = math.clamp(math.floor(flag("chams_ghost_count", 5)), 1, ChamStyle.ghostMax)
    c.ghostSpacing = math.max(flag("chams_ghost_spacing", 1.2), 0.1)
    c.ghostLength = math.max(flag("chams_ghost_length", 0.6), 0.05)
    c.ghostGradient = flag("chams_ghost_gradient", true)
    c.glowShells = math.clamp(math.floor(flag("chams_glow_shells", 3)), 1, ChamStyle.shellMax)
    c.glowPulse = flag("chams_glow_pulse", 0.5)
    c.glowOutline = flag("chams_glow_outline", false)
    local seen, changed = c.seen or {}, false
    c.seen = seen
    for _, key in ipairs(ChamStyle.sigKeys) do
        if seen[key] ~= c[key] then seen[key], changed = c[key], true end
    end
    if changed or not c.sig then c.sig = (c.sig or 0) + 1 end
    return c
end

function ChamStyle.plan(records, origin)
    local c = ChamStyle.read()
    ESP.S.chamStyle = c.style
    ChamStyle.frame = ChamStyle.frame + 1
    ChamStyle.origin = origin
    local allowed, order = ChamStyle.allowed, ChamStyle.order
    for player in pairs(allowed) do allowed[player] = nil end
    for index = #order, 1, -1 do order[index] = nil end
    if c.style ~= ChamStyle.current then
        ChamStyle.clear()
        ChamStyle.current = c.style
    end
    if c.style == "Classic" then return end
    for _, rec in ipairs(records) do
        local team = rec.enemy and ESP.enemy or ESP.team
        if team.enabled and team.chams and rec.rendered and rec.model and rec.model.Parent ~= nil then
            local dist = (rec.pos - origin).Magnitude
            if dist <= team.maxdist then
                rec.styleDist = dist
                order[#order + 1] = rec
            end
        end
    end
    table.sort(order, ChamStyle.nearer)
    for index = 1, math.min(#order, c.cap) do allowed[order[index].player] = true end
end

function ChamStyle.root()
    local home = ChamStyle.home
    if home and home.Parent then return home end
    local cam = Workspace.CurrentCamera
    if not cam then return nil end
    home = Instance.new("Folder")
    home.Name = Util.randomName()
    home.Parent = cam
    ChamStyle.home = home
    return home
end

function ChamStyle.view()
    if ChamStyle.views then return ChamStyle.views end
    local gui = Chams.getContainer()
    if not gui then return nil end
    local views = {}
    for index, key in ipairs({ "back", "front" }) do
        local frame = Instance.new("ViewportFrame")
        frame.Name = Util.randomName()
        frame.Size = UDim2.fromScale(1, 1)
        frame.BackgroundTransparency = 1
        frame.Ambient, frame.LightColor = WHITE, BLACK
        frame.ZIndex = index
        frame.Parent = gui
        views[key] = frame
    end
    local camera = Instance.new("Camera")
    camera.Parent = views.front
    views.back.CurrentCamera, views.front.CurrentCamera, views.camera = camera, camera, camera
    views.memo = { back = {}, front = {} }
    views.back.Visible = ChamStyle.current == "Toon"
    ChamStyle.views = views
    return views
end

function ChamStyle.make(rig, class, props, parent)
    local object = Instance.new(class)
    object.Name = Util.randomName()
    for key, value in pairs(props) do object[key] = value end
    object.Parent = parent
    rig.objects[#rig.objects + 1] = object
    return object
end

function ChamStyle.group(rig, parent)
    local folder = Instance.new("Folder")
    folder.Name = Util.randomName()
    folder.Parent = parent
    rig.folders[#rig.folders + 1] = { object = folder, parent = parent }
    return folder
end

function ChamStyle.size(name, grow)
    local size = name == "Head" and Vector3.new(1.2, 1.2, 1.2) or PART_SIZES[name]
    grow = grow or 0.06
    return size + Vector3.new(grow, grow, grow)
end

function ChamStyle.body(rig, parent, props, grow, loose)
    local set = {}
    for _, name in ipairs(CHAM_PARTS) do
        local base = { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Size = ChamStyle.size(name, grow) }
        for key, value in pairs(props) do base[key] = value end
        set[name] = ChamStyle.make(rig, "Part", base, parent)
    end
    if not loose then rig.sets[#rig.sets + 1] = set end
    return set
end

function ChamStyle.tint(set, color)
    for _, part in pairs(set) do part.Color = color end
end

function ChamStyle.fade(set, alpha)
    for _, part in pairs(set) do part.Transparency = alpha end
end

function ChamStyle.screen(cfg)
    local views = ChamStyle.views
    if not views then return end
    local alpha = math.clamp(1 - 0.75 * cfg.int, 0, 0.9)
    views.back.ImageTransparency, views.front.ImageTransparency = alpha, alpha
end

function ChamStyle.mix(alpha, extra)
    return 1 - (1 - alpha) * (1 - extra)
end

function ChamStyle.put(views, key, prop, value)
    local memo = views.memo[key]
    if memo[prop] ~= value then
        memo[prop] = value
        views[key][prop] = value
    end
end

function ChamStyle.toonLight(views, cam, cfg)
    local shade = math.clamp(cfg.toonShade, 0, 0.95)
    ChamStyle.put(views, "front", "Ambient", Color3.new(1 - shade, 1 - shade, 1 - shade))
    ChamStyle.put(views, "front", "LightColor", Color3.new(shade, shade, shade))
    ChamStyle.put(views, "front", "LightDirection", cam.CFrame:VectorToWorldSpace(ChamStyle.keyLight))
    ChamStyle.put(views, "back", "Ambient", cfg.toonLine)
    ChamStyle.put(views, "back", "LightColor", cfg.toonRim and cfg.c2 or BLACK)
    ChamStyle.put(views, "back", "LightDirection", cam.CFrame:VectorToWorldSpace(ChamStyle.rimLight))
end

function ChamStyle.glowGrow(shell, count)
    return 0.04 + 0.7 * (shell / count) ^ 1.5
end

ChamStyle.styles.Toon = {
    view = true,
    build = function(rig, views)
        rig.outline = ChamStyle.body(rig, ChamStyle.group(rig, views.back), { Material = Enum.Material.SmoothPlastic, Color = WHITE }, 0.3)
        rig.fill = ChamStyle.body(rig, ChamStyle.group(rig, views.front), { Material = Enum.Material.SmoothPlastic })
        rig.grow = 0.3
    end,
    paint = function(rig, cfg)
        if rig.grow ~= cfg.toonGrow then
            rig.grow = cfg.toonGrow
            for name, part in pairs(rig.outline) do part.Size = ChamStyle.size(name, cfg.toonGrow) end
        end
        ChamStyle.tint(rig.fill, rig.c1)
        ChamStyle.fade(rig.fill, rig.alpha)
        ChamStyle.fade(rig.outline, rig.alpha)
        ChamStyle.screen(cfg)
    end,
}

ChamStyle.styles.Ghost = {
    view = true,
    build = function(rig, views)
        local folder = ChamStyle.group(rig, views.front)
        rig.base = ChamStyle.body(rig, folder, { Material = Enum.Material.SmoothPlastic })
        for index = 1, ChamStyle.ghostMax do
            rig.ghosts[index] = { set = ChamStyle.body(rig, folder, { Material = Enum.Material.SmoothPlastic, Transparency = 1 }, 0, true), born = -math.huge }
        end
    end,
    paint = function(rig, cfg)
        ChamStyle.tint(rig.base, rig.c1)
        ChamStyle.fade(rig.base, ChamStyle.mix(math.clamp(0.75 - 0.45 * cfg.int, 0.1, 0.95), rig.alpha))
        for _, ghost in ipairs(rig.ghosts) do ghost.step = nil end
        if rig.ghostNext > cfg.ghostCount then rig.ghostNext = 1 end
    end,
    follow = function(rig, rec, now, cfg)
        local torso = rec.hash.Torso
        if not torso then return end
        local position = torso.Position
        if rig.ghostPos and (position - rig.ghostPos).Magnitude < cfg.ghostSpacing then return end
        local first = rig.ghostPos == nil
        rig.ghostPos = position
        if first then return end
        local ghost = rig.ghosts[rig.ghostNext]
        rig.ghostNext = rig.ghostNext % cfg.ghostCount + 1
        ghost.born, ghost.step = now, nil
        for name, part in pairs(ghost.set) do
            local real = rec.hash[name]
            if real then part.CFrame = real.CFrame end
        end
    end,
    tick = function(rig, cfg, now)
        local floor = math.clamp(0.8 - 0.4 * cfg.int, 0.2, 0.95)
        for index, ghost in ipairs(rig.ghosts) do
            local k = index <= cfg.ghostCount and (now - ghost.born) / cfg.ghostLength or 1
            local step = k >= 1 and -1 or math.floor(k * 16)
            if step ~= ghost.step then
                ghost.step = step
                if step < 0 then
                    ChamStyle.fade(ghost.set, 1)
                else
                    local t = (step + 0.5) / 16
                    ChamStyle.fade(ghost.set, ChamStyle.mix(floor + (1 - floor) * t * t * (3 - 2 * t), rig.alpha))
                    ChamStyle.tint(ghost.set, cfg.ghostGradient and Util.lerpColor(rig.c1, cfg.c2, t) or cfg.c2)
                end
            end
        end
    end,
}

ChamStyle.styles["Glow shells"] = {
    build = function(rig, root)
        local folder = ChamStyle.group(rig, root)
        for layer = 1, ChamStyle.shellMax + 1 do
            local list = {}
            for _, name in ipairs(CHAM_PARTS) do
                list[name] = ChamStyle.make(rig, "BoxHandleAdornment", { Size = ChamStyle.size(name, 0.03), ZIndex = layer, AdornCullingMode = Enum.AdornCullingMode.Never }, folder)
            end
            rig.layers[layer] = list
        end
        local lines = {}
        for _, name in ipairs(CHAM_PARTS) do
            lines[name] = ChamStyle.make(rig, "SelectionBox", { LineThickness = 0.035, SurfaceTransparency = 1, Visible = false }, folder)
        end
        rig.layers[#rig.layers + 1] = lines
        rig.lines = lines
    end,
    paint = function(rig, cfg)
        local count = cfg.glowShells
        for layer = 1, ChamStyle.shellMax + 1 do
            local shell = layer - 1
            local on = shell <= count
            local color = shell == 0 and rig.c1 or Util.lerpColor(rig.c1, cfg.c2, shell / count)
            for name, adornment in pairs(rig.layers[layer]) do
                adornment.Color3, adornment.AlwaysOnTop, adornment.Visible = color, cfg.walls, on
                if on and shell > 0 then adornment.Size = ChamStyle.size(name, ChamStyle.glowGrow(shell, count)) end
            end
            rig.layerAlpha[layer] = nil
        end
        local edge = Util.lerpColor(rig.c1, WHITE, 0.35)
        for _, line in pairs(rig.lines) do line.Visible, line.Color3, line.Transparency = cfg.glowOutline, edge, rig.alpha end
    end,
    follow = function(rig, rec)
        for _, name in ipairs(CHAM_PARTS) do
            local real = rec.hash[name]
            if rig.adornee[name] ~= real then
                rig.adornee[name] = real
                for _, list in ipairs(rig.layers) do list[name].Adornee = real end
            end
        end
    end,
    tick = function(rig, cfg, now)
        local count = cfg.glowShells
        local dim = cfg.glowPulse * 0.9 * (0.5 + 0.5 * math.cos(now * cfg.speed * 2.2))
        for layer = 1, count + 1 do
            local shell = layer - 1
            local alpha
            if shell == 0 then
                alpha = 1 - 0.6 * cfg.int
                alpha = alpha + (1 - alpha) * dim * 0.5
            else
                alpha = 1 - 0.55 * cfg.int * (1 - shell / (count + 1)) ^ 2
                alpha = alpha + (1 - alpha) * dim
            end
            alpha = math.floor(ChamStyle.mix(math.clamp(alpha, 0, 1), rig.alpha) * 30 + 0.5) / 30
            if rig.layerAlpha[layer] ~= alpha then
                rig.layerAlpha[layer] = alpha
                for _, adornment in pairs(rig.layers[layer]) do adornment.Transparency = alpha end
            end
        end
    end,
}

function ChamStyle.build(style)
    local def = ChamStyle.styles[style]
    if not def then return nil end
    local parent
    if def.view then parent = ChamStyle.view() else parent = ChamStyle.root() end
    if not parent then return nil end
    local rig = { style = style, objects = {}, sets = {}, textures = {}, folders = {}, layers = {}, layerAlpha = {}, ghosts = {}, adornee = {},
        parts = {}, frames = {}, animAt = 0, shown = true, world = not def.view, ghostNext = 1, c1 = WHITE, alpha = 0 }
    local ok, problem = pcall(def.build, rig, parent)
    if not ok then
        Util.note("chamstyle" .. tostring(problem), "cham style " .. style .. ":", problem)
        ChamStyle.destroy(rig)
        return nil
    end
    return rig
end

function ChamStyle.destroy(rig)
    for index = #rig.objects, 1, -1 do pcall(rig.objects[index].Destroy, rig.objects[index]) end
    for _, entry in ipairs(rig.folders) do pcall(entry.object.Destroy, entry.object) end
    rig.objects, rig.folders, rig.sets, rig.textures = {}, {}, {}, {}
end

function ChamStyle.show(rig, shown)
    if rig.shown == shown then return end
    rig.shown = shown
    for _, entry in ipairs(rig.folders) do entry.object.Parent = shown and entry.parent or nil end
end

function ChamStyle.take(style)
    local list = ChamStyle.pool[style]
    while list and #list > 0 do
        local rig = table.remove(list)
        local home = rig.folders[1]
        if home and home.parent.Parent then return rig end
        ChamStyle.destroy(rig)
    end
    return ChamStyle.build(style)
end

function ChamStyle.drop(player)
    local rig = ChamStyle.objs[player]
    if not rig then return end
    ChamStyle.objs[player] = nil
    ChamStyle.show(rig, false)
    rig.ghostPos = nil
    if next(rig.adornee) then
        for _, list in ipairs(rig.layers) do
            for _, adornment in pairs(list) do adornment.Adornee = nil end
        end
        rig.adornee = {}
    end
    local list = ChamStyle.pool[rig.style] or {}
    ChamStyle.pool[rig.style] = list
    if #list < (ChamStyle.cfg.cap or 8) then list[#list + 1] = rig else ChamStyle.destroy(rig) end
end

function ChamStyle.clear()
    for _, rig in pairs(ChamStyle.objs) do ChamStyle.destroy(rig) end
    for _, list in pairs(ChamStyle.pool) do
        for _, rig in ipairs(list) do ChamStyle.destroy(rig) end
    end
    ChamStyle.objs, ChamStyle.pool = {}, {}
    local views, home = ChamStyle.views, ChamStyle.home
    ChamStyle.views, ChamStyle.home = nil, nil
    if views then
        pcall(views.back.Destroy, views.back)
        pcall(views.front.Destroy, views.front)
    end
    if home then pcall(home.Destroy, home) end
end

function ChamStyle.pose(rig, rec)
    local hash, parts, frames, count = rec.hash, rig.parts, rig.frames, 0
    local posed = rig.posed
    if not posed then
        posed = setmetatable({}, { __mode = "k" })
        rig.posed = posed
    end
    for _, set in ipairs(rig.sets) do
        for name, part in pairs(set) do
            local real = hash[name]
            if real and real.Parent then
                local frame = real.CFrame
                if rig.world or posed[part] ~= frame then
                    posed[part] = frame
                    count = count + 1
                    parts[count], frames[count] = part, frame
                end
            end
        end
    end
    for index = #parts, count + 1, -1 do parts[index], frames[index] = nil, nil end
    if rig.world then
        if ChamStyle.bulk == nil then
            local ok, bulk = pcall(function() return Workspace.BulkMoveTo end)
            ChamStyle.bulk = ok and type(bulk) == "function" and bulk or false
        end
        if ChamStyle.bulk and pcall(ChamStyle.bulk, Workspace, parts, frames, Enum.BulkMoveMode.FireCFrameChanged) then return end
    end
    for index = 1, count do parts[index].CFrame = frames[index] end
end

function ChamStyle.update(rec, style)
    local def = ChamStyle.styles[style]
    if not def then return false end
    local cfg = ChamStyle.cfg
    local rig = ChamStyle.objs[rec.player]
    if not rig then
        rig = ChamStyle.take(style)
        if not rig then return false end
        ChamStyle.objs[rec.player] = rig
    end
    rig.frame = ChamStyle.frame
    local now = os.clock()
    local covered = def.view and not cfg.walls
    local visible = true
    if cfg.vis or covered then visible = Visible.entity(rec, ChamStyle.origin, now, flag("vis_interval", 100) / 1000) end
    local shown = visible or not covered
    ChamStyle.show(rig, shown)
    if not shown then return true end
    local state = cfg.vis and (visible and "vis" or "occ") or "base"
    if rig.sig ~= cfg.sig or rig.state ~= state then
        rig.sig, rig.state = cfg.sig, state
        if state == "vis" then
            rig.c1, rig.alpha = cfg.visColor, cfg.visAlpha
        elseif state == "occ" then
            rig.c1, rig.alpha = cfg.occColor, cfg.occAlpha
        else
            rig.c1, rig.alpha = cfg.c1, 0
        end
        def.paint(rig, cfg)
    end
    ChamStyle.pose(rig, rec)
    if def.follow then def.follow(rig, rec, now, cfg) end
    if def.tick and now >= rig.animAt then
        rig.animAt = now + ChamStyle.rate
        def.tick(rig, cfg, now)
    end
    return true
end

function ChamStyle.finish(cam, now)
    if ChamStyle.current == nil or ChamStyle.current == "Classic" then return end
    for player, rig in pairs(ChamStyle.objs) do
        if rig.frame ~= ChamStyle.frame then ChamStyle.drop(player) end
    end
    local views = ChamStyle.views
    if views and next(ChamStyle.objs) then
        views.camera.CFrame = cam.CFrame
        views.camera.FieldOfView = cam.FieldOfView
        if ChamStyle.current == "Toon" then ChamStyle.toonLight(views, cam, ChamStyle.cfg) end
    end
end

function ChamStyle.viewSpec(spec)
    if not spec then return spec end
    if flag("local_cham_style", "Classic") ~= "Glow shells" then return spec end
    local now = math.floor(os.clock() * 15) / 15
    local speed = math.max(flag("chams_style_speed", 1), 0.05)
    local wave = 0.5 + 0.5 * math.sin(now * speed * 3)
    spec.material, spec.texture = Enum.Material.Neon, ""
    spec.alpha = math.clamp(spec.alpha + 0.3 * wave, 0, 0.95)
    spec.vertex = Vector3.new(spec.color.R, spec.color.G, spec.color.B)
    return spec
end

function Chams.mute(entry)
    if entry.muted then return end
    entry.muted = true
    for _, slot in pairs(entry.parts) do
        slot.sig = nil
        for _, adornment in pairs(slot.layers) do adornment.Visible = false end
    end
end

function Chams.update(rec, cfg, S)
    local entry = Chams.objs[rec.player]
    local want = cfg and cfg.chams and rec.rendered and rec.model and rec.model.Parent ~= nil
    if not want then
        if entry then Chams.hide(entry) end
        ChamStyle.drop(rec.player)
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
    local sig = cfg.chamSig or Chams.signature(cfg, S)
    Chams.identity()
    if S.chamStyle and S.chamStyle ~= "Classic" and ChamStyle.allowed[rec.player] and ChamStyle.update(rec, S.chamStyle) then
        Chams.mute(entry)
        return
    end
    ChamStyle.drop(rec.player)
    entry.muted = nil
    local seen = false
    if S.chamMode == "Through walls" and rec.rendered and ChamStyle.origin then
        seen = Visible.entity(rec, ChamStyle.origin, os.clock(), flag("vis_interval", 100) / 1000)
    end
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
            if slot.adornee ~= part or slot.sig ~= sig or slot.seen ~= seen then
                slot.adornee, slot.sig, slot.seen = part, sig, seen
                Chams.style(slot, part, name, cfg, S, seen)
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
    local on = o.on

    if o.sig ~= S.font * 100 + S.size then
        o.sig = S.font * 100 + S.size
        for _, t in ipairs({ o.hpText, o.name, o.dist, o.weapon }) do t.Font, t.Size = S.font, S.size end
    end

    if cfg.fill then
        if S.gradient then
            local colors = o.gradColors
            if o.gradFrom ~= cfg.fillColor or o.gradTo ~= S.fill2 then
                o.gradFrom, o.gradTo = cfg.fillColor, S.fill2
                for index = 1, STRIPS do colors[index] = Util.lerpColor(cfg.fillColor, S.fill2, (index - 0.5) / STRIPS) end
            end
            local stripH = h / STRIPS
            for index = 1, STRIPS do
                local strip = o.strips[index]
                strip.Position = Vector2.new(x, y + math.floor((index - 1) * stripH))
                strip.Size = Vector2.new(w, math.ceil(stripH))
                strip.Color = colors[index]
                strip.Transparency = cfg.fillA
                on[strip] = true
            end
        else
            o.fill.Position, o.fill.Size = Vector2.new(x, y), Vector2.new(w, h)
            o.fill.Color, o.fill.Transparency = cfg.fillColor, cfg.fillA
            on[o.fill] = true
        end
    end

    local boxColor = espTint(S, visible, cfg.boxColor)
    local full = cfg.box and S.boxStyle == "Full"
    local corners = cfg.box and S.boxStyle ~= "Full"
    if full then
        o.box.Position, o.box.Size, o.box.Color, o.box.Transparency = Vector2.new(x, y), Vector2.new(w, h), boxColor, cfg.boxA
        o.outer.Position, o.outer.Size = Vector2.new(x - 1, y - 1), Vector2.new(w + 2, h + 2)
        o.inner.Position, o.inner.Size = Vector2.new(x + 1, y + 1), Vector2.new(w - 2, h - 2)
        on[o.box] = true
        if S.outline then on[o.outer], on[o.inner] = true, true end
    end
    if corners then
        local len = math.max(4, math.floor(w * 0.28))
        local lenV = math.max(4, math.floor(h * 0.2))
        for index, segment in ipairs(CORNER_SEGMENTS) do
            local fx, fy = x + w * segment[1], y + h * segment[2]
            local from, to = Vector2.new(fx, fy), Vector2.new(fx + len * segment[3], fy + lenV * segment[4])
            if S.outline then
                o.cornerEdges[index].From, o.cornerEdges[index].To = from, to
                on[o.cornerEdges[index]] = true
            end
            setLine(on, o.corners[index], from, to, boxColor, cfg.boxA, 1)
        end
    end

    if cfg.hp or cfg.hpNum then
        local frac = math.clamp(rec.health / math.max(rec.maxHealth, 1), 0, 1)
        local left = S.hpSide == "Left"
        local barX = left and (x - 6) or (x + w + 3)
        local barH = math.max(1, math.floor(h * frac))
        if cfg.hp then
            local color
            if frac > 0.5 then color = Util.lerpColor(S.hpMid, cfg.hpFull, (frac - 0.5) * 2)
            else color = Util.lerpColor(cfg.hpLow, S.hpMid, frac * 2) end
            o.hpBack.Position, o.hpBack.Size = Vector2.new(barX - 1, y - 1), Vector2.new(5, h + 2)
            o.hpBar.Position, o.hpBar.Size = Vector2.new(barX, y + h - barH), Vector2.new(3, barH)
            o.hpBar.Color, o.hpBar.Transparency = color, 1
            on[o.hpBack], on[o.hpBar] = true, true
        end
        if cfg.hpNum then
            local textX = left and (barX - 11) or (barX + 14)
            o.hpText.Text = tostring(math.floor(rec.health + 0.5))
            local lowest = math.max(y - 2, y + h - S.size)
            o.hpText.Position = Vector2.new(textX, math.clamp(y + h - barH - math.floor(S.size / 2), y - 2, lowest))
            o.hpText.Color, o.hpText.Transparency = cfg.hpNumColor, cfg.hpNumA
            on[o.hpText] = true
        end
    end

    if cfg.name then
        if o.nameFrom ~= rec.name or o.nameCase ~= S.case then
            o.nameFrom, o.nameCase = rec.name, S.case
            o.nameText = caseText(S.case, string.sub(rec.name, 1, 30))
        end
        o.name.Text = o.nameText
        o.name.Position = Vector2.new(x + w / 2, y - S.size - 3)
        o.name.Color, o.name.Transparency = cfg.nameColor, cfg.nameA
        on[o.name] = true
    end
    local lineY = y + h + 2
    if cfg.dist then
        local meters = math.floor(dist * STUDS_TO_M)
        if o.distFrom ~= meters or o.distCase ~= S.case then
            o.distFrom, o.distCase = meters, S.case
            o.distText = caseText(S.case, meters .. "m")
        end
        o.dist.Text = o.distText
        o.dist.Position = Vector2.new(x + w / 2, lineY)
        o.dist.Color, o.dist.Transparency = cfg.distColor, cfg.distA
        on[o.dist] = true
        lineY = lineY + S.size + 1
    end
    if cfg.weapon and rec.weaponName then
        local mode = S.weaponDisplay
        local icon = false
        if mode ~= "Text" then
            local top = mode == "Both" and lineY + S.size + 1 or lineY
            icon = Icons.place(o.weaponIcon, Icons.weaponKey(rec.weaponName, rec.weaponObject), x + w / 2, top + 7, 60, 13, cfg.weaponColor, cfg.weaponA)
            if icon then on[o.weaponIcon] = true end
        end
        if mode ~= "Icon" or not icon then
            o.weapon.Text = caseText(S.case, tostring(rec.weaponName))
            o.weapon.Position = Vector2.new(x + w / 2, lineY)
            o.weapon.Color, o.weapon.Transparency = cfg.weaponColor, cfg.weaponA
            on[o.weapon] = true
        end
    end

    if cfg.skeleton then
        local points = ESP.bonePoints(rec.hash, o.points)
        if points then
            local color = espTint(S, visible, cfg.skeletonColor)
            local frame = Stretch.cf(cam)
            local depth, screen, front = o.depth, o.screen, o.front
            for name in pairs(screen) do screen[name], front[name], depth[name] = nil, nil, nil end
            for name, world in pairs(points) do depth[name] = -frame:PointToObjectSpace(world).Z end
            for index, bone in ipairs(BONES) do
                local first, second = bone[1], bone[2]
                local a, b = points[first], points[second]
                if a and b then
                    local da, db = depth[first], depth[second]
                    local pa, pb
                    if da < NEAR_PLANE or db < NEAR_PLANE then
                        local ca, cb = ESP.clip(cam, a, b)
                        if ca then pa, pb = Draw.project(cam, ca), Draw.project(cam, cb) end
                    else
                        if not screen[first] then screen[first], front[first] = Draw.project(cam, a) end
                        if not screen[second] then screen[second], front[second] = Draw.project(cam, b) end
                        pa, pb = screen[first], screen[second]
                    end
                    if pa then
                        if S.skelOutline then setLine(on, o.boneEdges[index], pa, pb, BLACK, cfg.skeletonA, S.skelThick + 2) end
                        setLine(on, o.bones[index], pa, pb, color, cfg.skeletonA, S.skelThick)
                    end
                end
            end
            local fillRadius = S.skelJoints and S.skelThick + 0.75 or S.skelThick / 2
            if S.skelOutline or S.skelJoints or S.skelThick >= 2 then
                for index, name in ipairs(CAP_POINTS) do
                    local world = points[name]
                    if world then
                        if not screen[name] then screen[name], front[name] = Draw.project(cam, world) end
                        if front[name] then
                            local point = screen[name]
                            if S.skelOutline then
                                local edge = o.capEdges[index]
                                edge.Position, edge.Radius, edge.Transparency = point, fillRadius + 1, cfg.skeletonA
                                on[edge] = true
                            end
                            local fill = o.capFills[index]
                            fill.Position, fill.Radius, fill.Color, fill.Transparency = point, fillRadius, color, cfg.skeletonA
                            on[fill] = true
                        end
                    end
                end
            end
        end
    end

    local headPoint, headFront = Draw.project(cam, rec.head.Position)
    if cfg.dot and headFront then
        local radius = math.clamp(h * 0.09, 2, 12)
        o.dot.Position, o.dot.Radius, o.dot.Color, o.dot.Transparency = headPoint, radius, espTint(S, visible, cfg.dotColor), cfg.dotA
        o.dotEdge.Position, o.dotEdge.Radius = headPoint, radius
        on[o.dot] = true
        if S.outline then on[o.dotEdge] = true end
    end
    if cfg.view and headFront then
        local tip, tipFront = Draw.project(cam, rec.head.Position + rec.head.CFrame.LookVector * S.viewLen)
        if tipFront then setLine(on, o.view, headPoint, tip, espTint(S, visible, cfg.viewColor), cfg.viewA, 1) end
    end

    if cfg.tracer then
        local from
        if S.tracerOrigin == "Center" then from = center
        elseif S.tracerOrigin == "Top" then from = Vector2.new(viewport.X / 2, 0)
        elseif S.tracerOrigin == "Mouse" then from = UserInputService:GetMouseLocation()
        else from = Vector2.new(viewport.X / 2, viewport.Y) end
        setLine(on, o.tracer, from, Vector2.new(x + w / 2, y + h), espTint(S, visible, cfg.tracerColor), cfg.tracerA, S.tracerThick)
    end

    for _, drawing in ipairs(o.all) do
        if on[drawing] then
            on[drawing] = nil
            drawing.Visible = true
        else
            drawing.Visible = false
        end
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
    for _, cfg in ipairs({ ESP.enemy, ESP.team }) do
        local ok, sig = pcall(Chams.signature, cfg, ESP.S)
        cfg.chamSig = ok and sig or nil
    end
    local origin = Game.eye(cam).Position
    Util.guard("chamstyle", ChamStyle.plan, records, origin)
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
    Util.guard("chamstyle", ChamStyle.finish, cam, now)
end

function ESP.clear()
    for _, o in pairs(ESP.objects) do ESP.hide(o) end
    for player in pairs(Chams.objs) do Chams.remove(player) end
end

Util.onUnload(function()
    for _, o in pairs(ESP.objects) do ESP.destroy(o) end
    ESP.objects = {}
    for player in pairs(Chams.objs) do Chams.remove(player) end
    ChamStyle.clear()
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
    ["Purple Night"] = { "5084576400", "5260653793", "5260817288", "5260808177", "5260800833", "5260811073" },
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
local SKY_MODELS = {
    ["Sunless Blue Sky"] = "591067775",
    ["Sky-Realistic"] = "10256505900",
    ["Classic Roblox Sky"] = "339406852",
    ["Old Roblox Sky"] = "8539737017",
    ["Clouds Skybox"] = "3146864089",
    ["Realistic Skybox"] = "8238531417",
    ["Tropical Sunset"] = "169210648",
    ["Flaming Sunset (Jegabert)"] = "415691475",
    ["Sunset Skybox"] = "3017752195",
    ["Pink Sky"] = "12635340429",
    ["Nebula / Pink Galaxy"] = "13581482229",
    ["Starry Night"] = "911025794",
    ["Sparkling Night Sky"] = "10610570551",
    ["Epic Night Skybox"] = "143962526",
    ["Moon Night Sky"] = "15536138513",
    ["Dark Forest Sky"] = "18618123674",
    ["Realistic Space Skybox"] = "136402262",
    ["Space Sky (2011)"] = "61320635",
    ["Space Sky HD"] = "16262385808",
    ["Dark Storm Sky"] = "5098791091",
    ["Dark Green Sky"] = "566612745",
    ["Anime Sky Cloud Aesthetic"] = "118492785282531",
}
local SKY_MODEL_ORDER = { "Sunless Blue Sky", "Sky-Realistic", "Classic Roblox Sky", "Old Roblox Sky", "Clouds Skybox", "Realistic Skybox", "Tropical Sunset", "Flaming Sunset (Jegabert)", "Sunset Skybox", "Pink Sky", "Nebula / Pink Galaxy", "Starry Night", "Sparkling Night Sky", "Epic Night Skybox", "Moon Night Sky", "Dark Forest Sky", "Realistic Space Skybox", "Space Sky (2011)", "Space Sky HD", "Dark Storm Sky", "Dark Green Sky", "Anime Sky Cloud Aesthetic" }
local SKY_CHOICES = {}
for index, name in ipairs(SKY_ORDER) do SKY_CHOICES[index] = name end
for _, name in ipairs(SKY_MODEL_ORDER) do SKY_CHOICES[#SKY_CHOICES + 1] = name end
for _, name in ipairs({ "Custom", "Custom faces", "Single image", "Saved set", "Store asset" }) do SKY_CHOICES[#SKY_CHOICES + 1] = name end
local SKY_EXTRA = { "SunTextureId", "MoonTextureId", "StarCount", "SunAngularSize", "MoonAngularSize", "CelestialBodiesShown" }
local MODEL_LIGHT = {
    Atmosphere = { "Density", "Offset", "Color", "Decay", "Glare", "Haze" },
    BloomEffect = { "Intensity", "Size", "Threshold" },
    ColorCorrectionEffect = { "TintColor", "Saturation", "Contrast", "Brightness" },
    SunRaysEffect = { "Intensity", "Spread" },
}
local MODEL_FX = { BloomEffect = "model_bloom", ColorCorrectionEffect = "model_cc", SunRaysEffect = "model_rays" }
local ATMOS_PRESETS = {
    ["Clear Day"] = { 0.3, 0.25, { 199, 199, 199 }, { 106, 112, 125 }, 0, 0 },
    ["Hazy Afternoon"] = { 0.107, 0.143, { 138, 139, 166 }, { 250, 235, 235 }, 0.89, 0.36 },
    ["Golden Sunset"] = { 0.45, 0.28, { 255, 180, 130 }, { 130, 80, 50 }, 0.25, 1.4 },
    ["Moonlit Night"] = { 0.38, 0.3, { 90, 100, 140 }, { 40, 40, 70 }, 0, 1.4 },
    ["Neon Dream"] = { 0.25, 0.3, { 255, 200, 220 }, { 240, 150, 190 }, 1.5, 1 },
    ["Storm Front"] = { 0.55, 0, { 150, 155, 165 }, { 70, 75, 85 }, 0, 3 },
    ["Deep Space"] = { 0.12, 1, { 30, 30, 50 }, { 10, 10, 25 }, 0, 0 },
}
local ATMOS_ORDER = { "Clear Day", "Hazy Afternoon", "Golden Sunset", "Moonlit Night", "Neon Dream", "Storm Front", "Deep Space" }

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

local function assign(object, prop, value)
    if object[prop] ~= value then object[prop] = value end
end

local function effect(key, class, enabled)
    local object = World.fx[key]
    if not (object and object.Parent) then
        if not enabled then return nil end
        object = Instance.new(class)
        object.Name = Util.randomName()
        object.Parent = Lighting
        World.fx[key] = object
    end
    assign(object, "Enabled", enabled)
    return object
end

local function tune(key, class, flagName, set)
    local enabled = on(flagName) == true
    local object = effect(key, class, enabled)
    if object and enabled then set(object) end
end

local SKY_FIELDS = { "world_sky_f_up", "world_sky_f_dn", "world_sky_f_ft", "world_sky_f_bk", "world_sky_f_lf", "world_sky_f_rt" }
World.skyTex, World.hidden = {}, {}

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
    local sets, names, direct = {}, {}, {}
    for entry in string.gmatch(tostring(val("world_sky_saved") or ""), "[^;]+") do
        local name, list, mark = entry:match("^([^|]+)|([^|]+)|?([^|]*)$")
        local ids = name and World.expandIds(list)
        if ids and not sets[name] then
            sets[name], direct[name] = ids, mark == "tex"
            names[#names + 1] = name
        end
    end
    return sets, names, direct
end

function World.setLine(name, ids, direct)
    return name .. "|" .. table.concat(ids, ",") .. (direct and "|tex" or "")
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
        local sets, _, direct = World.savedSets()
        local name = val("world_sky_saved_pick")
        return sets[name], not direct[name]
    end
    if choice == "Store asset" or SKY_MODELS[choice] then
        local modelId = World.modelId(choice)
        local entry = modelId and World.skyModel(modelId)
        if entry then return entry.faces, false, entry end
        local hold = World.skyHold
        if hold then return hold.ids, hold.custom, hold.entry end
        return World.gameFaces(), false
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

World.models, World.modelJobs = {}, {}

function World.skyNote(id, text, duration)
    Util.notify({ Title = "Skybox", Text = text, Duration = duration or 6, Id = "sky_asset_" .. tostring(id) })
end

function World.skyDebug(text)
    if on("world_sky_debug") or on("misc_debug_kills") then print("[Aster sky] " .. text) end
end

function World.fetchAsset(url)
    local loaders = {
        { "GetObjects", function() return game:GetObjects(url) end },
        { "LoadLocalAsset", function() return game:GetService("InsertService"):LoadLocalAsset(url) end },
    }
    if type(getobjects) == "function" then
        loaders[3] = { "getobjects", function() return getobjects(url) end }
    end
    local reasons = {}
    for _, loader in ipairs(loaders) do
        local ok, result = pcall(loader[2])
        if ok and result ~= nil and propGet(result, "ClassName") ~= nil then result = { result } end
        if ok and type(result) == "table" and result[1] ~= nil then return result, loader[1] end
        local reason = ok and "empty" or tostring(result):gsub("^.-:%d+: ", "")
        reasons[#reasons + 1] = loader[1] .. " " .. reason:sub(1, 60)
    end
    return nil, table.concat(reasons, "; ")
end

function World.assetId(text)
    local s = tostring(text or ""):lower()
    local number = s:match("/asset/(%d+)") or s:match("/library/(%d+)") or s:match("/catalog/(%d+)") or s:match("[?&]id=(%d+)")
    if not number then
        local url = World.parseAsset(s)
        number = url and url:match("^rbxassetid://(%d+)$")
    end
    return number
end

function World.storeId()
    local text = tostring(val("world_sky_asset") or "")
    if text ~= World.assetText then World.assetText, World.assetAt = text, os.clock() end
    if World.storePick == nil and os.clock() - World.assetAt >= 1 then World.storePick = World.assetId(text) end
    return World.storePick
end

function World.modelId(choice)
    if choice == "Store asset" then return World.storeId() end
    return SKY_MODELS[choice]
end

function World.findIn(objects, class)
    for _, object in ipairs(objects) do
        if propGet(object, "ClassName") == class then return object end
        local ok, list = pcall(function() return object:GetDescendants() end)
        if ok and type(list) == "table" then
            for _, child in ipairs(list) do
                if propGet(child, "ClassName") == class then return child end
            end
        end
    end
    return nil
end

function World.loadModel(id)
    local started = os.clock()
    local objects, how = World.fetchAsset("rbxassetid://" .. id)
    local loaded = objects ~= nil
    objects = objects or {}
    local sky, entry, why = World.findIn(objects, "Sky"), nil, nil
    local decal = not sky and (World.findIn(objects, "Decal") or World.findIn(objects, "Texture"))
    local image = decal and propGet(decal, "Texture")
    if sky then
        entry = { id = id, faces = {}, props = {}, light = {}, kinds = {} }
        for index, face in ipairs(SKY_FACES) do
            local texture = propGet(sky, face)
            if type(texture) == "string" and texture ~= "" then entry.faces[index] = texture end
        end
        for _, prop in ipairs(SKY_EXTRA) do entry.props[prop] = propGet(sky, prop) end
        for class, props in pairs(MODEL_LIGHT) do
            local object = World.findIn(objects, class)
            if object and (class == "Atmosphere" or propGet(object, "Enabled") ~= false) then
                local copy = {}
                for _, prop in ipairs(props) do copy[prop] = propGet(object, prop) end
                entry.light[class] = copy
                entry.kinds[#entry.kinds + 1] = (class:gsub("Effect$", ""))
            end
        end
        table.sort(entry.kinds)
    elseif type(image) == "string" and image ~= "" then
        entry = { id = id, faces = { image, image, image, image, image, image }, props = {}, light = {}, kinds = {}, single = true }
    elseif not loaded then
        why = "download failed (" .. how .. ")"
    else
        local classes = {}
        for index = 1, math.min(#objects, 3) do classes[index] = tostring(propGet(objects[index], "ClassName")) end
        why = "no Sky or Decal inside (" .. table.concat(classes, ", ") .. ")"
    end
    for _, object in ipairs(objects) do pcall(function() object:Destroy() end) end
    local found = entry and (entry.single and "Decal image " .. image or "Sky " .. #entry.kinds .. " extras") or why
    World.skyDebug(string.format("asset %s loader=%s found=%s (%.2fs)", id, loaded and how or "none", found, os.clock() - started))
    return entry, why
end

function World.loadSky(id)
    if World.modelJobs[id] then return end
    World.modelJobs[id], World.models[id] = true, nil
    World.skyNote(id, "Loading sky " .. id .. "…", 30)
    task.spawn(function()
        local ok, entry, why = pcall(World.loadModel, id)
        if not ok then entry, why = nil, tostring(entry) end
        World.models[id], World.modelJobs[id] = entry or false, nil
        if not entry then
            World.skyNote(id, "Could not load sky " .. id .. ": " .. tostring(why) .. "; keeping the current sky", 8)
        elseif #entry.kinds > 0 and not on("world_sky_asset_light") then
            World.skyNote(id, "Loaded sky " .. id .. "; it also has " .. table.concat(entry.kinds, ", ") .. "; turn on Apply model lighting to use it", 6)
        else
            World.skyNote(id, "Loaded sky " .. id .. (entry.single and " (one image on all faces)" or ""), 4)
        end
    end)
end

function World.skyModel(id)
    if World.models[id] == nil then World.loadSky(id) end
    local entry = World.models[id]
    return type(entry) == "table" and entry or nil
end

function World.gameFaces()
    for child in pairs(World.hidden) do
        local ids, any = {}, false
        for index, face in ipairs(SKY_FACES) do
            local texture = propGet(child, face)
            if type(texture) == "string" and texture ~= "" then ids[index], any = texture, true end
        end
        if any then return ids end
    end
    return nil
end

function World.modelLight()
    local entry = World.shownEntry
    if not (entry and on("world_skybox") and on("world_sky_asset_light")) then return nil end
    return entry.light
end

function World.applyAsset()
    local id = World.assetId(val("world_sky_asset"))
    if not id then
        World.notify("Skybox: paste an asset id or a create.roblox.com/store/asset link")
        return
    end
    World.storePick = id
    if World.models[id] == false then World.models[id] = nil end
    pcall(function() Options.world_sky_box:SetValue("Store asset") end)
    pcall(function() Toggles.world_skybox:SetValue(true) end)
    if World.modelJobs[id] then
        World.skyNote(id, "Still loading sky " .. id .. "…", 30)
    elseif World.models[id] then
        World.skyNote(id, "Applied sky " .. id, 3)
    end
    World.skyModel(id)
end

function World.saveAsset()
    local id = World.modelId(val("world_sky_box")) or World.assetId(val("world_sky_asset"))
    if not id then
        World.notify("Skybox: pick a store sky or paste an asset id first")
        return
    end
    local entry = World.models[id]
    if type(entry) ~= "table" then
        if entry == false then World.models[id] = nil end
        World.loadSky(id)
        entry = World.models[id]
    end
    if type(entry) ~= "table" then
        if World.modelJobs[id] then World.skyNote(id, "Loading sky " .. id .. "…; press Save again once it has loaded", 30) end
        return
    end
    local list, count = {}, 0
    for index = 1, 6 do
        list[index] = entry.faces[index]
        if list[index] then count = count + 1 end
    end
    if count ~= 6 then
        World.notify("Skybox: asset " .. id .. " has empty faces and cannot be saved")
        return
    end
    local ok, info = pcall(function() return game:GetService("MarketplaceService"):GetProductInfo(tonumber(id)) end)
    local name = ok and type(info) == "table" and type(info.Name) == "string" and info.Name or nil
    if not name then
        for label, modelId in pairs(SKY_MODELS) do if modelId == id then name = label end end
    end
    World.storeSet(name or ("Asset " .. id), list, true)
end

function World.atmosPreset()
    local preset = ATMOS_PRESETS[val("world_atmos_preset")]
    if not preset then return end
    local density, offset, colour, decay, glare, haze = table.unpack(preset)
    pcall(function()
        Options.world_atmos_density:SetValue(density)
        Options.world_atmos_offset:SetValue(offset)
        Toggles.world_atmos_offset_on:SetValue(true)
        Options.world_atmos_color:SetValueRGB(Color3.fromRGB(colour[1], colour[2], colour[3]))
        Options.world_atmos_decay:SetValueRGB(Color3.fromRGB(decay[1], decay[2], decay[3]))
        Options.world_atmos_glare:SetValue(glare)
        Options.world_atmos_haze:SetValue(haze)
        Toggles.world_atmos:SetValue(true)
    end)
end

function World.skyJob(url)
    local final = url
    if on("world_sky_resolve") ~= false and url:match("^rbxassetid://%d+$") then
        local objects, how = World.fetchAsset(url)
        objects = objects or {}
        local decal = World.findIn(objects, "Decal") or World.findIn(objects, "Texture")
        local texture = decal and propGet(decal, "Texture")
        if type(texture) == "string" and texture ~= "" then final = texture end
        for _, object in ipairs(objects) do pcall(function() object:Destroy() end) end
        World.skyDebug("face " .. url .. " loader=" .. (objects[1] and how or "none") .. " image=" .. final)
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
    local ids, custom = World.skyIds()
    local list = {}
    for index = 1, 6 do list[index] = ids and ids[index] end
    if name == "" or #list ~= 6 then
        World.notify(name == "" and "Skybox: type a name first" or "Skybox: all six faces need an id to save")
        return
    end
    World.storeSet(name, list, not custom)
end

function World.storeSet(name, list, direct)
    name = tostring(name):gsub("[|;,]", "_"):match("^%s*(.-)%s*$")
    local sets, names, marks = World.savedSets()
    sets[name], marks[name] = list, direct == true
    if not table.find(names, name) then names[#names + 1] = name end
    local parts = {}
    for _, entry in ipairs(names) do parts[#parts + 1] = World.setLine(entry, sets[entry], marks[entry]) end
    Options.world_sky_saved:SetValue(table.concat(parts, ";"))
    World.refreshSaved()
    pcall(function() Options.world_sky_saved_pick:SetValue(name) end)
    World.notify("Skybox: saved " .. name)
end

function World.deleteSky()
    local name = val("world_sky_saved_pick")
    local sets, names, marks = World.savedSets()
    if not sets[name] then return end
    local parts = {}
    for _, entry in ipairs(names) do
        if entry ~= name then parts[#parts + 1] = World.setLine(entry, sets[entry], marks[entry]) end
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
    World.shownEntry = nil
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
        local ids, custom, entry = World.skyIds()
        if sky and ids then
            World.skyHold = { ids = ids, custom = custom, entry = entry }
            World.shownEntry = entry
            for index, face in ipairs(SKY_FACES) do
                local url = ids[index]
                put(sky, face, url and (custom and World.skyTexture(url) or url) or "")
            end
            if entry then
                for prop, value in pairs(entry.props) do put(sky, prop, value) end
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

local DynSky = {
    names = { "Aurora", "Galaxy drift", "Synthwave sunset", "Storm", "Nebula", "Starfield" },
    radius = 1800, height = 900, panels = 10, starCap = 60, angle = 0,
    objects = {}, beams = {}, curtains = {}, bolt = {}, boltBeams = {}, flashAt = -math.huge, boltAt = 0, shootAt = 0, waveAt = 0,
    clouds = "rbxassetid://5176277457", galaxy = "rbxassetid://1120738433", nebula = "rbxassetid://171448889", flare = "rbxassetid://8983307836",
    twinkle = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.1, 0.2), NumberSequenceKeypoint.new(0.3, 0.65), NumberSequenceKeypoint.new(0.5, 0.1),
        NumberSequenceKeypoint.new(0.7, 0.7), NumberSequenceKeypoint.new(0.9, 0.25), NumberSequenceKeypoint.new(1, 1),
    }),
}

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end

function DynSky.rand(low, high) return low + (high - low) * math.random() end

DynSky.presets = {
    Aurora = {
        dome = { tex = DynSky.clouds, low = rgb(10, 45, 45), high = rgb(25, 12, 60), alpha = 0.5, speed = 0.05, length = 900 },
        curtains = { rgb(60, 255, 170), rgb(80, 190, 255), rgb(190, 90, 255) },
        stars = { rate = 30, size = 4, color = rgb(220, 240, 255) }, shoot = 0.6, spin = 0.004,
        light = { atmos = { rgb(80, 150, 140), rgb(120, 90, 170) }, decay = rgb(20, 40, 60), density = 0.32, haze = 1, glare = 0, shift = rgb(110, 255, 200),
            cc = { rgb(225, 255, 240), 0.12, 0.06, -0.02 }, bloom = { 0.7, 32, 0.85 } },
    },
    ["Galaxy drift"] = {
        dome = { tex = DynSky.galaxy, low = rgb(70, 35, 120), high = rgb(20, 20, 70), alpha = 0.45, speed = 0.04, length = 1400 },
        stars = { rate = 45, size = 5, color = rgb(230, 220, 255) }, shoot = 1, spin = 0.012, dust = { color = rgb(190, 150, 255), rate = 6 },
        light = { atmos = { rgb(120, 100, 170), rgb(90, 80, 160) }, decay = rgb(40, 30, 70), density = 0.3, haze = 1.5, glare = 0, shift = rgb(170, 120, 255),
            cc = { rgb(220, 210, 255), 0.15, 0.05, 0 }, bloom = { 0.7, 30, 0.85 } },
    },
    ["Synthwave sunset"] = {
        dome = { tex = "", low = rgb(255, 90, 150), high = rgb(60, 20, 120), alpha = 0.35, speed = 0, length = 1 },
        sun = { rgb(255, 230, 120), rgb(255, 70, 160) },
        stars = { rate = 12, size = 3.5, color = rgb(255, 200, 240) }, shoot = 0.5, spin = 0,
        light = { atmos = { rgb(255, 140, 170), rgb(255, 120, 200) }, decay = rgb(110, 40, 120), density = 0.35, haze = 2, glare = 1, shift = rgb(255, 120, 200),
            cc = { rgb(255, 220, 235), 0.25, 0.15, 0 }, bloom = { 1, 36, 0.8 } },
    },
    Storm = {
        dome = { tex = DynSky.clouds, low = rgb(40, 42, 48), high = rgb(18, 20, 26), alpha = 0.55, speed = 0.25, length = 700 },
        bolts = true, shoot = 0, spin = 0.01, dust = { color = rgb(150, 155, 165), rate = 10 },
        light = { atmos = { rgb(110, 115, 125), rgb(90, 95, 110) }, decay = rgb(40, 42, 50), density = 0.5, haze = 3, glare = 0, shift = rgb(70, 75, 90),
            cc = { rgb(210, 215, 230), -0.35, 0.1, -0.05 }, bloom = { 0.3, 24, 0.95 } },
    },
    Nebula = {
        dome = { tex = DynSky.nebula, low = rgb(120, 60, 200), high = rgb(255, 90, 180), alpha = 0.5, speed = 0.03, length = 1800 },
        stars = { rate = 35, size = 4.5, color = rgb(255, 225, 250) }, shoot = 0.4, spin = 0.008, dust = { color = rgb(255, 140, 220), rate = 5 },
        light = { atmos = { rgb(170, 110, 200), rgb(110, 120, 220) }, decay = rgb(60, 30, 90), density = 0.32, haze = 1.5, glare = 0, shift = rgb(220, 120, 255),
            cc = { rgb(235, 215, 255), 0.2, 0.05, 0 }, bloom = { 0.8, 30, 0.85 } },
    },
    Starfield = {
        dome = { tex = "", low = rgb(5, 8, 20), high = rgb(0, 0, 8), alpha = 0.55, speed = 0, length = 1 },
        stars = { rate = 60, size = 4.5, color = rgb(235, 240, 255) }, shoot = 2, spin = 0.006,
        light = { atmos = { rgb(60, 70, 110), rgb(50, 60, 100) }, decay = rgb(10, 12, 30), density = 0.25, haze = 0.5, glare = 0, shift = rgb(120, 140, 255),
            cc = { rgb(215, 225, 255), -0.05, 0.05, -0.03 }, bloom = { 0.5, 28, 0.9 } },
    },
}

function DynSky.tinted(color, tint)
    return Color3.new(color.R * tint.R, color.G * tint.G, color.B * tint.B)
end

DynSky.cfgKeys = { "preset", "speed", "int", "stars", "shoot", "tint" }

function DynSky.settings()
    local cfg = DynSky.cfg or {}
    DynSky.cfg = cfg
    cfg.preset, cfg.speed, cfg.int = val("world_dsky_preset") or "Aurora", val("world_dsky_speed") or 1, val("world_dsky_int") or 1
    cfg.stars, cfg.shoot, cfg.tint = val("world_dsky_stars") or 1, val("world_dsky_shoot") or 6, val("world_dsky_tint") or WHITE
    return cfg
end

function DynSky.same(cfg)
    local sig = DynSky.sig
    if not sig then return false end
    for _, key in ipairs(DynSky.cfgKeys) do
        if sig[key] ~= cfg[key] then return false end
    end
    return true
end

function DynSky.make(class, props, parent)
    local rate = class == "ParticleEmitter" and props.Rate or 0
    if rate > 0 then props.Rate = 0 end
    local object = Instance.new(class)
    object.Name = Util.randomName()
    for key, value in pairs(props) do object[key] = value end
    object.Parent = parent
    DynSky.objects[#DynSky.objects + 1] = object
    if rate > 0 then
        DynSky.streams = DynSky.streams or {}
        DynSky.streams[#DynSky.streams + 1] = { emitter = object, rate = rate, acc = 1 }
    end
    return object
end

function DynSky.drop()
    for index = #DynSky.objects, 1, -1 do pcall(DynSky.objects[index].Destroy, DynSky.objects[index]) end
    DynSky.objects, DynSky.beams, DynSky.curtains, DynSky.bolt, DynSky.boltBeams, DynSky.streams = {}, {}, {}, {}, {}, {}
    DynSky.root, DynSky.dust, DynSky.shooter, DynSky.shootPoint, DynSky.sig, DynSky.def, DynSky.boltLit = nil, nil, nil, nil, nil, nil, nil
    DynSky.flashAt = -math.huge
end

function DynSky.solid(props)
    local base = { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Transparency = 1 }
    for key, value in pairs(props) do base[key] = value end
    return base
end

function DynSky.beam(a, b, width, props)
    local base = { Attachment0 = a, Attachment1 = b, FaceCamera = true, Width0 = width, Width1 = width, LightEmission = 0.4, LightInfluence = 0, Segments = 1 }
    for key, value in pairs(props) do base[key] = value end
    local beam = DynSky.make("Beam", base, DynSky.root)
    DynSky.beams[#DynSky.beams + 1] = beam
    return beam
end

function DynSky.point(position)
    return DynSky.make("Attachment", { Position = position }, DynSky.root)
end

function DynSky.build(cam, cfg, def)
    local origin = cam.CFrame.Position
    local R, H, tint, k = DynSky.radius, DynSky.height, cfg.tint, cfg.int
    DynSky.root = DynSky.make("Part", DynSky.solid({ Shape = Enum.PartType.Ball, Size = Vector3.new(R, R, R), CFrame = CFrame.new(origin) }), cam)
    DynSky.def = def
    local dome = def.dome
    local fade = NumberSequence.new(math.clamp(1 - dome.alpha * k, 0, 1))
    local wall = { Texture = dome.tex, TextureLength = dome.length, TextureSpeed = dome.speed * cfg.speed, TextureMode = Enum.TextureMode.Wrap,
        Color = ColorSequence.new(DynSky.tinted(dome.low, tint), DynSky.tinted(dome.high, tint)), Transparency = fade }
    local step = math.pi * 2 / DynSky.panels
    local width = 2 * math.pi * R / DynSky.panels * 1.12
    for index = 1, DynSky.panels do
        local angle = (index - 0.5) * step
        local x, z = math.cos(angle) * R, math.sin(angle) * R
        DynSky.beam(DynSky.point(Vector3.new(x, -R * 0.15, z)), DynSky.point(Vector3.new(x, H, z)), width, wall)
    end
    DynSky.beam(DynSky.point(Vector3.new(-R, H, 0)), DynSky.point(Vector3.new(R, H, 0)), 2 * R, {
        Texture = dome.tex, TextureLength = dome.length, TextureSpeed = dome.speed * cfg.speed, TextureMode = Enum.TextureMode.Wrap,
        Color = ColorSequence.new(DynSky.tinted(dome.high, tint)), Transparency = fade,
    })
    if def.curtains then
        local colors = {}
        for index, color in ipairs(def.curtains) do colors[index] = ColorSequenceKeypoint.new((index - 1) / (#def.curtains - 1), DynSky.tinted(color, tint)) end
        local veil = math.clamp(1 - 0.6 * k, 0, 1)
        for index = 1, 4 do
            local angle = index * 0.9 - 2.2
            local function at(spread) return Vector3.new(math.sin(angle + spread) * 1200, 380 + index * 25, -math.cos(angle + spread) * 1200) end
            DynSky.curtains[index] = DynSky.beam(DynSky.point(at(-0.35)), DynSky.point(at(0.35)), 320 * math.min(k, 1.5), {
                Texture = SMOKE, TextureMode = Enum.TextureMode.Stretch, TextureLength = 1, TextureSpeed = 0.2 * cfg.speed, Segments = 30, LightEmission = 1,
                Color = ColorSequence.new(colors),
                Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, veil), NumberSequenceKeypoint.new(0.75, veil), NumberSequenceKeypoint.new(1, 1) }),
            })
        end
    end
    if def.sun then
        DynSky.beam(DynSky.point(Vector3.new(0, 40, -R * 0.9)), DynSky.point(Vector3.new(0, 560, -R * 0.9)), 520, {
            Texture = DynSky.flare, TextureMode = Enum.TextureMode.Stretch, TextureLength = 1, LightEmission = 1,
            Color = ColorSequence.new(DynSky.tinted(def.sun[2], tint), DynSky.tinted(def.sun[1], tint)), Transparency = NumberSequence.new(math.clamp(1 - 0.85 * k, 0, 1)),
        })
    end
    if def.stars and cfg.stars > 0 then
        local stars = DynSky.make("ParticleEmitter", {
            Texture = SPARK, LightEmission = 1, LightInfluence = 0, LockedToPart = true, Speed = NumberRange.new(0), Lifetime = NumberRange.new(5, 9),
            Rate = math.min(DynSky.starCap, def.stars.rate * cfg.stars), Size = NumberSequence.new(def.stars.size), Rotation = NumberRange.new(0, 360),
            Color = ColorSequence.new(DynSky.tinted(def.stars.color, tint)), Transparency = DynSky.twinkle, EmissionDirection = Enum.NormalId.Top,
        }, DynSky.root)
        propSet(stars, "Shape", Enum.ParticleEmitterShape.Sphere)
        propSet(stars, "ShapeStyle", Enum.ParticleEmitterShapeStyle.Surface)
        propSet(stars, "ShapePartial", 0.5)
    end
    if (def.shoot or 0) > 0 and cfg.shoot > 0 then
        DynSky.shootPoint = DynSky.point(Vector3.new(0, H * 0.7, 0))
        DynSky.shooter = DynSky.make("ParticleEmitter", {
            Texture = SPARK, LightEmission = 1, LightInfluence = 0, Rate = 0, Speed = NumberRange.new(450, 650), Lifetime = NumberRange.new(0.5, 0.9),
            EmissionDirection = Enum.NormalId.Front, Orientation = Enum.ParticleOrientation.VelocityParallel,
            Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 7), NumberSequenceKeypoint.new(1, 0) }), Color = ColorSequence.new(DynSky.tinted(WHITE, tint)),
        }, DynSky.shootPoint)
        propSet(DynSky.shooter, "Squash", NumberSequence.new(-3))
    end
    if def.bolts then
        local glow = DynSky.tinted(rgb(170, 190, 255), tint)
        for index = 1, 10 do DynSky.bolt[index] = DynSky.point(Vector3.zero) end
        for index = 1, 9 do
            local list = DynSky.boltBeams
            list[#list + 1] = DynSky.beam(DynSky.bolt[index], DynSky.bolt[index + 1], 26, { Color = ColorSequence.new(glow), LightEmission = 1, Enabled = false, Transparency = NumberSequence.new(0.35) })
            list[#list + 1] = DynSky.beam(DynSky.bolt[index], DynSky.bolt[index + 1], 8, { Color = ColorSequence.new(WHITE), LightEmission = 1, Enabled = false, Transparency = NumberSequence.new(0) })
        end
    end
    if def.dust then
        DynSky.dust = DynSky.make("Part", DynSky.solid({ Size = Vector3.new(200, 80, 200), CFrame = CFrame.new(origin) }), cam)
        DynSky.make("ParticleEmitter", {
            Texture = SPARK, LightEmission = 0.5, LightInfluence = 0, LockedToPart = false, Rate = def.dust.rate * math.max(cfg.stars, 0.25),
            Speed = NumberRange.new(0.5, 2), SpreadAngle = Vector2.new(180, 180), Lifetime = NumberRange.new(4, 7), Size = NumberSequence.new(0.15),
            Color = ColorSequence.new(DynSky.tinted(def.dust.color, tint)), Transparency = DynSky.twinkle,
        }, DynSky.dust)
    end
end

function DynSky.strike(now, cfg)
    local rand = DynSky.rand
    local center = Vector3.new(rand(-1, 1), 0, rand(-1, 1))
    center = (center.Magnitude > 1e-3 and center.Unit or Vector3.new(1, 0, 0)) * rand(700, 1300)
    local top, bottom = center + Vector3.new(0, 700, 0), center + Vector3.new(rand(-150, 150), 120, rand(-150, 150))
    for index, point in ipairs(DynSky.bolt) do
        local k = (index - 1) / (#DynSky.bolt - 1)
        local jitter = (index == 1 or index == #DynSky.bolt) and 0 or 60
        point.Position = top + (bottom - top) * k + Vector3.new(rand(-jitter, jitter), 0, rand(-jitter, jitter))
    end
    DynSky.flashAt = now
    DynSky.boltAt = now + (3 + math.random() * 9) / math.max(cfg.speed, 0.1)
end

function DynSky.flashLevel(now)
    local t = now - DynSky.flashAt
    if t < 0 or t > 0.6 then return 0 end
    if t < 0.08 then return 1 end
    if t < 0.16 then return 0.3 end
    if t < 0.24 then return 0.9 end
    return 0.9 * (1 - (t - 0.24) / 0.36)
end

function DynSky.step(cam, now, dt)
    if not on("world_dsky") then
        if DynSky.root then DynSky.drop() end
        return
    end
    local cfg = DynSky.settings()
    local def = DynSky.presets[cfg.preset]
    if not def then return end
    if not (DynSky.root and DynSky.root.Parent) or not DynSky.same(cfg) then
        DynSky.drop()
        DynSky.build(cam, cfg, def)
        DynSky.sig = table.clone(cfg)
        DynSky.boltAt = now + 1.5
        DynSky.shootAt = now + 1
    end
    local origin = cam.CFrame.Position
    DynSky.angle = (DynSky.angle + (def.spin or 0) * cfg.speed * dt) % (math.pi * 2)
    DynSky.root.CFrame = CFrame.new(origin) * CFrame.Angles(0, DynSky.angle, 0)
    if DynSky.dust then DynSky.dust.CFrame = CFrame.new(origin) end
    for _, stream in ipairs(DynSky.streams or {}) do
        stream.acc = stream.acc + stream.rate * dt
        if stream.acc >= 1 then
            local count = math.floor(stream.acc)
            stream.acc = stream.acc - count
            pcall(stream.emitter.Emit, stream.emitter, math.min(count, 40))
        end
    end
    if #DynSky.curtains > 0 and now >= DynSky.waveAt then
        DynSky.waveAt = now + 0.1
        for index, curtain in ipairs(DynSky.curtains) do
            local phase = now * 0.4 * cfg.speed + index * 1.7
            curtain.CurveSize0, curtain.CurveSize1 = 160 * math.sin(phase), 160 * math.cos(phase * 0.8)
        end
    end
    if DynSky.shooter and now >= DynSky.shootAt then
        local rand = DynSky.rand
        DynSky.shootAt = now + 60 / math.max(cfg.shoot * (def.shoot or 0), 0.01) * (0.5 + math.random())
        local spot = Vector3.new(rand(-900, 900), rand(450, 750), rand(-900, 900))
        DynSky.shootPoint.CFrame = CFrame.new(spot, spot + Vector3.new(rand(-1, 1), -rand(0.15, 0.4), rand(-1, 1)))
        pcall(DynSky.shooter.Emit, DynSky.shooter, 1)
    end
    if def.bolts then
        if now >= DynSky.boltAt then DynSky.strike(now, cfg) end
        local lit = now - DynSky.flashAt <= 0.35
        if lit ~= DynSky.boltLit then
            DynSky.boltLit = lit
            for _, beam in ipairs(DynSky.boltBeams) do beam.Enabled = lit end
        end
    end
end

function DynSky.light(atmos, now)
    if not on("world_dsky") then return end
    local def = DynSky.presets[val("world_dsky_preset")]
    if not def then return end
    local spec, k, tint = def.light, math.clamp(val("world_dsky_int") or 1, 0, 2), val("world_dsky_tint") or WHITE
    local wave = 0.5 + 0.5 * math.sin(math.floor(now * 10) / 10 * (val("world_dsky_speed") or 1) * 0.35)
    if atmos then
        put(atmos, "Color", DynSky.tinted(Util.lerpColor(spec.atmos[1], spec.atmos[2], wave), tint))
        put(atmos, "Decay", DynSky.tinted(spec.decay, tint))
        put(atmos, "Density", spec.density * math.min(k, 1.3))
        put(atmos, "Haze", spec.haze * k)
        put(atmos, "Glare", spec.glare * k)
    end
    put(Lighting, "ColorShift_Top", DynSky.tinted(Util.lerpColor(BLACK, spec.shift, math.clamp(0.6 * k, 0, 1)), tint))
end

function DynSky.flashLight(now)
    local k = DynSky.root and DynSky.def and DynSky.def.bolts and DynSky.flashLevel(now) or 0
    if k <= 0 then return end
    local base, wanted = World.orig[Lighting], want[Lighting]
    local function from(prop, fallback)
        if wanted and wanted[prop] ~= nil then return wanted[prop] end
        if base and base[prop] ~= nil then return base[prop] end
        local value = propGet(Lighting, prop)
        return type(value) == "number" and value or fallback
    end
    local strength = math.clamp(val("world_dsky_int") or 1, 0, 2)
    put(Lighting, "ExposureCompensation", from("ExposureCompensation", 0) + 1.4 * k * strength)
    put(Lighting, "Brightness", from("Brightness", 1) + 1.5 * k * strength)
end

function DynSky.post(now)
    local def = on("world_dsky") and DynSky.presets[val("world_dsky_preset")] or nil
    local cc = effect("dsky_cc", "ColorCorrectionEffect", def ~= nil)
    local bloom = effect("dsky_bloom", "BloomEffect", def ~= nil)
    if not (def and cc and bloom) then return end
    local spec, k, tint = def.light, math.clamp(val("world_dsky_int") or 1, 0, 2), val("world_dsky_tint") or WHITE
    local flash = DynSky.root and def.bolts and DynSky.flashLevel(now) or 0
    assign(cc, "TintColor", DynSky.tinted(Util.lerpColor(WHITE, spec.cc[1], math.min(k, 1.5)), tint))
    assign(cc, "Saturation", spec.cc[2] * k)
    assign(cc, "Contrast", spec.cc[3] * k)
    assign(cc, "Brightness", spec.cc[4] * k + 0.25 * flash)
    assign(bloom, "Intensity", spec.bloom[1] * k)
    assign(bloom, "Size", spec.bloom[2])
    assign(bloom, "Threshold", spec.bloom[3])
end

function World.apply(dt, now)
    for _, props in pairs(want) do
        for prop in pairs(props) do props[prop] = nil end
    end

    local light = World.modelLight()
    local needAtmos = on("world_atmos") or (light and light.Atmosphere) ~= nil or on("world_dsky")
    local atmos = World.atmos
    if not (atmos and atmos.Parent) then
        atmos = Lighting:FindFirstChildOfClass("Atmosphere")
        World.atmos = atmos
    end
    if needAtmos and not atmos then
        local ok, created = pcall(Instance.new, "Atmosphere")
        if ok and created then
            pcall(function() created.Parent = Lighting end)
            World.atmos, World.ownAtmos, atmos = created, true, created
        end
    end

    DynSky.light(atmos, now)
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
    if light and light.Atmosphere and atmos then
        for prop, value in pairs(light.Atmosphere) do put(atmos, prop, value) end
    end
    if on("world_atmos") and atmos then
        put(atmos, "Density", val("world_atmos_density"))
        if on("world_atmos_offset_on") then put(atmos, "Offset", val("world_atmos_offset")) end
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
    DynSky.flashLight(now)

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

    if not needAtmos and World.ownAtmos and World.atmos then
        pcall(function() World.atmos:Destroy() end)
        want[World.atmos], World.orig[World.atmos] = nil, nil
        World.atmos, World.ownAtmos = nil, false
    end

    tune("cc", "ColorCorrectionEffect", "world_cc", function(object)
        assign(object, "TintColor", val("world_cc_tint"))
        assign(object, "Saturation", val("world_cc_sat"))
        assign(object, "Contrast", val("world_cc_con"))
        assign(object, "Brightness", val("world_cc_bri"))
    end)
    pcall(function()
        local glowBloom = on("cham_glow") == true and on("cham_bloom") == true and Chams.shown()
        local worldBloom = on("world_bloom") == true
        local bloom = effect("bloom", "BloomEffect", worldBloom or glowBloom)
        if bloom then
            local prefix = worldBloom and "world_bloom_" or "cham_bloom_"
            assign(bloom, "Intensity", val(prefix .. "i"))
            assign(bloom, "Size", val(prefix .. "s"))
            assign(bloom, "Threshold", val(prefix .. "t"))
        end
    end)
    tune("rays", "SunRaysEffect", "world_rays", function(object)
        assign(object, "Intensity", val("world_rays_i"))
        assign(object, "Spread", val("world_rays_s"))
    end)
    tune("dof", "DepthOfFieldEffect", "world_dof", function(object)
        assign(object, "FocusDistance", val("world_dof_focus"))
        assign(object, "InFocusRadius", val("world_dof_radius"))
        assign(object, "NearIntensity", val("world_dof_near"))
        assign(object, "FarIntensity", val("world_dof_far"))
    end)
    tune("blur", "BlurEffect", "world_blur", function(object)
        assign(object, "Size", val("world_blur_size"))
    end)
    DynSky.post(now)
    for class, key in pairs(MODEL_FX) do
        local props = light and light[class]
        local object = effect(key, class, props ~= nil)
        if object and props then
            for prop, value in pairs(props) do
                if propGet(object, prop) ~= value then propSet(object, prop, value) end
            end
        end
    end
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
    local density, speed, size, wind = val("world_weather_amount"), val("world_weather_speed"), val("world_weather_size"), val("world_weather_wind")
    local windDir, height, custom, color = val("world_weather_wind_dir"), val("world_weather_height"), on("world_weather_custom") == true, val("world_weather_color")
    local cfg = state.cfg
    if not (cfg and cfg.density == density and cfg.speed == speed and cfg.size == size and cfg.wind == wind and cfg.windDir == windDir
        and cfg.height == height and cfg.custom == custom and cfg.color == color) then
        cfg = { density = density, speed = speed, size = size, wind = wind, windDir = windDir, height = height, custom = custom, color = color }
        state.cfg, state.cfgSig = cfg, table.concat({ cfg.density, cfg.speed, cfg.size, cfg.wind, cfg.windDir, cfg.height, tostring(cfg.custom), tostring(cfg.color) }, "|")
    end
    local sig = state.cfgSig
    local position = cam.CFrame.Position
    local plan, mode = nil, "near"
    local cover = on("world_weather_map") == true
    local bounds = cover and World.mapBounds(now)
    if cover and not bounds then
        if next(state.cells) then World.dropWeather() end
        return
    end
    local gx0, gz0 = math.floor(position.X / CELL), math.floor(position.Z / CELL)
    local range = math.clamp(math.floor(val("world_weather_range") or 2), 1, 3)
    local cap = bounds and math.clamp(math.floor(val("world_weather_map_cap") or 100), 16, 400)
    if bounds and state.planFor == bounds and state.planCap == cap then
        plan, mode = state.plan, state.planMode
    elseif not bounds and state.planFor == false and state.planGx == gx0 and state.planGz == gz0 and state.planRange == range then
        plan, mode = state.plan, state.planMode
    elseif bounds then
        local size = math.max(CELL, math.sqrt(bounds.w * bounds.d / cap))
        local nx, nz = math.ceil(bounds.w / size), math.ceil(bounds.d / size)
        while nx * nz > cap do
            size = size * 1.05
            nx, nz = math.ceil(bounds.w / size), math.ceil(bounds.d / size)
        end
        mode, plan = table.concat({ "map", nx, nz, math.floor(size * 100) }, ":"), {}
        for gx = 0, nx - 1 do
            for gz = 0, nz - 1 do
                plan[#plan + 1] = { key = gx .. ":" .. gz, gx = gx, gz = gz, size = size, x = bounds.x + (gx + 0.5) * size, z = bounds.z + (gz + 0.5) * size, every = 1.5, stagger = (gx * 7 + gz * 3) % 11 * 0.1 }
            end
        end
        state.plan, state.planMode, state.planFor, state.planCap = plan, mode, bounds, cap
    else
        plan = {}
        for dx = -range, range do
            for dz = -range, range do
                if dx * dx + dz * dz <= (range + 0.5) * (range + 0.5) then
                    local gx, gz = gx0 + dx, gz0 + dz
                    plan[#plan + 1] = { key = gx .. ":" .. gz, gx = gx, gz = gz, size = CELL, x = (gx + 0.5) * CELL, z = (gz + 0.5) * CELL, every = 0.35, stagger = ((dx * 7 + dz * 3) % 5) * 0.06 }
                end
            end
        end
        state.plan, state.planMode, state.planFor, state.planGx, state.planGz, state.planRange = plan, mode, false, gx0, gz0, range
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
            local open, ground, camY = cell.open, cell.ground, cell.camY
            World.scanCell(cell, position.Y, bounds and bounds.top)
            if cell.open ~= open or cell.ground ~= ground or cell.camY ~= camY then cell.dirty = true end
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
    if not shown then
        for index = 1, 4 do cross.lines[index].Visible, cross.edges[index].Visible = false, false end
        cross.dot.Visible = false
        return
    end
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
    local tee = flag("cross_t", false)
    for index = 1, 4 do
        local drawn = not (tee and index == 4)
        if drawn then
            local direction = directions[index]
            if outline then
                local edge = cross.edges[index]
                edge.From, edge.To = center + direction * (near - 1), center + direction * (far + 1)
                edge.Thickness = whole + 2
            end
            local line = cross.lines[index]
            line.From, line.To = center + direction * near, center + direction * far
            line.Color, line.Transparency, line.Thickness = color, alpha, whole
        end
        cross.edges[index].Visible, cross.lines[index].Visible = drawn and outline, drawn
    end
    local dot = flag("cross_dot", false)
    if dot then
        cross.dot.Radius = whole % 2 == 1 and 1.5 or 2
        cross.dot.Position, cross.dot.Color, cross.dot.Transparency = center, color, alpha
    end
    cross.dot.Visible = dot
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
    DynSky.drop()
    for _, object in pairs(World.fx) do pcall(function() object:Destroy() end) end
    World.fx = {}
    if World.ownAtmos and World.atmos then pcall(function() World.atmos:Destroy() end) end
end)

local Tracers = {
    list = {}, fade = 0.5, fx = {}, particle = {},
    particleNames = { "Comet", "Plasma", "Smoke ribbon", "Frost", "Railgun", "Laser", "Ion bolt", "Tracer round", "Neon streak", "Void" },
    caps = { records = 20, enemy = 12, emitters = 32, rate = 120, life = 2.5, burst = 40, beams = 360, rays = 160, builds = 6, queue = 48 },
    owner = setmetatable({}, { __mode = "k" }), queue = {}, rays = 0, minSize = 0.3,
    fire = "rbxasset://textures/particles/fire_main.dds", ice = Color3.fromRGB(190, 235, 255),
    ring = "rbxassetid://5857851812", flare = "rbxassetid://8983307836", bolt = "rbxassetid://5833323391",
}

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

function Tracers.spawn(path, color, hit, speed, mine)
    local presets = Tracers.presets()
    local name = flag("trace_texture", "Lightning")
    if Tracers.particle[name] then return Tracers.spawnFx(name, path, color, hit, speed, mine) end
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

function Tracers.trajectory(origin, position, velocity, acceleration, life, segments)
    local flight = math.clamp(type(life) == "number" and life or 2, 0.1, 5)
    segments = segments or 47
    local step = math.max(0.04, flight / segments)
    local path = { origin }
    local previous, hit, cast = position, nil, nil
    local time = 0
    while time < flight - 1e-6 do
        time = math.min(time + step, flight)
        Tracers.rays = Tracers.rays - 1
        local point = position + velocity * time + acceleration * (0.5 * time * time)
        local result = Game.cast(previous, point - previous, Barrel.params)
        if result then
            path[#path + 1] = result.Position
            hit, cast = result.Position, result
            break
        end
        path[#path + 1] = point
        previous = point
    end
    return path, hit, cast, time
end

Tracers.solved = setmetatable({}, { __mode = "k" })

function Tracers.solve(info, mine)
    local shot = Tracers.solved[info]
    if shot then return shot end
    local position, velocity = info.position, info.velocity
    if typeof(position) ~= "Vector3" or typeof(velocity) ~= "Vector3" or velocity.Magnitude < 1e-3 then return nil end
    local origin = Tracers.origin(info, mine)
    if typeof(origin) ~= "Vector3" then return nil end
    local acceleration = typeof(info.acceleration) == "Vector3" and info.acceleration or Game.accel
    local life, segments = info.life, nil
    if not mine then
        if Tracers.rays <= 0 then return nil end
        local settings = Game.mods.PublicSettings
        local limit = settings and type(settings.bulletLifeTime) == "number" and settings.bulletLifeTime or 2
        life, segments = math.min(type(life) == "number" and life or limit, limit), 16
    end
    Barrel.refreshParams(os.clock())
    local path, hit, cast, time = Tracers.trajectory(origin, position, velocity, acceleration, life, segments)
    shot = { origin = origin, path = path, hit = hit, cast = cast, time = time, speed = velocity.Magnitude }
    Tracers.solved[info] = shot
    return shot
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
    if typeof(info.traceOrigin) == "Vector3" then return info.traceOrigin end
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
    if Tracers.particle[flag("trace_texture", "Lightning")] and not Tracers.room(mine, os.clock()) then return false end
    local shot = Tracers.solve(info, mine)
    if not shot then return false end
    local path = shot.path
    if #path < 2 or (path[#path] - shot.origin).Magnitude < 0.5 then return false end
    return Tracers.spawn(path, color, shot.hit, shot.speed, mine)
end

function Tracers.enqueue(info, bullet, mine)
    if not (flag("trace_on", false) or flag("trace_enemy_on", false) or flag("trace_team_on", false) or flag("impact_on", false)) then return end
    local queue = Tracers.queue
    if #queue >= Tracers.caps.queue then
        local drop = 1
        for index, item in ipairs(queue) do
            if not item.mine then
                drop = index
                break
            end
        end
        table.remove(queue, drop)
    end
    queue[#queue + 1] = {
        info = { position = info.position, velocity = info.velocity, acceleration = info.acceleration, life = info.life, visualorigin = info.visualorigin, extra = info.extra,
            traceOrigin = mine and Tracers.origin(info, true) or nil },
        bullet = bullet, mine = mine, at = os.clock(),
    }
end

function Tracers.drain(now)
    local queue = Tracers.queue
    if #queue == 0 then return end
    Tracers.rays = Tracers.caps.rays
    for _ = 1, Tracers.caps.builds do
        if #queue == 0 then break end
        local pick = 1
        for index, item in ipairs(queue) do
            if item.mine then
                pick = index
                break
            end
        end
        local item = table.remove(queue, pick)
        local late = now - item.at
        if item.mine or late < 0.5 then
            pcall(function()
                if Tracers.fromBullet(item.info, item.mine) and flag("trace_hide_beam", true) then Tracers.hideBeam(item.bullet) end
            end)
            if Tracers.onShot then pcall(Tracers.onShot, item.info, item.mine, late) end
        end
    end
end

function Tracers.settled(rec, now)
    return now >= (rec.quietAt or 0)
end

function Tracers.room(mine, now)
    local enemy, oldest = 0, nil
    for _, rec in ipairs(Tracers.fx) do
        if not rec.mine then
            enemy = enemy + 1
            oldest = oldest or rec
        end
    end
    if mine or enemy < Tracers.caps.enemy then return true end
    return now - oldest.born >= (oldest.travel or 0) + 0.3
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
    local active = flag("trace_on", false) or flag("trace_enemy_on", false) or flag("trace_team_on", false)
    for index = #Tracers.fx, 1, -1 do
        local rec = Tracers.fx[index]
        local age = now - rec.born
        if not active or (age >= rec.life and Tracers.settled(rec, now)) then
            Tracers.dropFx(rec)
            table.remove(Tracers.fx, index)
        else
            for slot = #rec.ticks, 1, -1 do
                local ok, done = pcall(rec.ticks[slot], age)
                if not ok then Util.note("tracer fx tick" .. tostring(done), "tracer fx:", done) end
                if not ok or done == true then table.remove(rec.ticks, slot) end
            end
        end
    end
end

function Tracers.make(rec, class, props, parent)
    local object = Instance.new(class)
    object.Name = Util.randomName()
    rec.objects[#rec.objects + 1] = object
    for key, value in pairs(props) do object[key] = value end
    object.Parent = parent or rec.holder
    return object
end

function Tracers.dropFx(rec)
    for index = #rec.objects, 1, -1 do
        local object = rec.objects[index]
        pcall(object.Destroy, object)
        rec.objects[index] = nil
    end
    rec.ticks = {}
end

function Tracers.solid(frame, size)
    return {
        Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
        Transparency = 1, Size = size or Vector3.new(0.2, 0.2, 0.2), CFrame = frame,
    }
end

function Tracers.curve(...)
    local values, keys = { ... }, {}
    for index = 1, #values, 2 do keys[#keys + 1] = NumberSequenceKeypoint.new(values[index], values[index + 1]) end
    return NumberSequence.new(keys)
end

function Tracers.frame(position, ahead)
    if ahead and ahead.Magnitude > 1e-4 then return CFrame.new(position, position + ahead) * CFrame.Angles(0, math.pi / 2, 0) end
    return CFrame.new(position)
end

function Tracers.point(rec, position, ahead)
    local point = Tracers.make(rec, "Attachment", {})
    point.WorldCFrame = Tracers.frame(position, ahead)
    return point
end

function Tracers.nodePoints(rec, ctx)
    local points, nodes = {}, ctx.nodes
    for index, position in ipairs(nodes) do
        points[index] = Tracers.point(rec, position, nodes[math.min(index + 1, #nodes)] - nodes[math.max(index - 1, 1)])
    end
    return points
end

function Tracers.distScale(position)
    local camera = propGet(Workspace, "CurrentCamera")
    local frame = camera and propGet(camera, "CFrame")
    if typeof(frame) ~= "CFrame" or typeof(position) ~= "Vector3" then return 1 end
    return math.clamp((position - frame.Position).Magnitude / 35, 1, 6)
end

function Tracers.sized(size, k, floor)
    if type(size) == "number" then size = NumberSequence.new(size) end
    local keys = typeof(size) == "NumberSequence" and size.Keypoints
    if type(keys) ~= "table" or #keys == 0 then return size end
    floor = (floor or Tracers.minSize) * k
    local out = {}
    local function value(key) return key.Time < 0.7 and math.max(key.Value * k, floor) or key.Value * k end
    for index, key in ipairs(keys) do
        local previous = keys[index - 1]
        if previous and previous.Time < 0.7 and key.Time > 0.7 then
            local span = key.Time - previous.Time
            local at = previous.Value + (key.Value - previous.Value) * (0.7 - previous.Time) / span
            out[#out + 1] = NumberSequenceKeypoint.new(0.7, math.max(at * k, floor), 0)
        end
        out[#out + 1] = NumberSequenceKeypoint.new(key.Time, value(key), (key.Envelope or 0) * k)
    end
    return NumberSequence.new(out)
end

function Tracers.emitter(rec, parent, props)
    local caps = Tracers.caps
    if rec.emitters >= caps.emitters then return nil end
    rec.emitters = rec.emitters + 1
    local base = {
        Texture = SPARK, LightEmission = 1, LightInfluence = 0, Rate = 0, Enabled = false, SpreadAngle = Vector2.new(180, 180),
        Rotation = NumberRange.new(0, 360), Transparency = Tracers.curve(0, 0, 1, 1),
    }
    for key, value in pairs(props) do base[key] = value end
    local rate = math.min(base.Rate, caps.rate)
    base.Rate = 0
    local life = base.Lifetime
    if life == nil or life.Max > caps.life then base.Lifetime = NumberRange.new(math.min(life and life.Min or 1, caps.life), caps.life) end
    if base.Lifetime.Max < 0.25 then base.Lifetime = NumberRange.new(math.max(base.Lifetime.Min, 0.15), 0.25) end
    if base.Size ~= nil then base.Size = Tracers.sized(base.Size, rec.sizeScale or 1) end
    local emitter = Tracers.make(rec, "ParticleEmitter", base, parent)
    if rec.bright ~= 1 then propSet(emitter, "Brightness", rec.bright) end
    Tracers.owner[emitter] = { rec = rec, life = base.Lifetime.Max }
    if rate > 0 then Tracers.stream(rec, emitter, rate) end
    return emitter
end

function Tracers.burst(emitter, count)
    if not emitter or not (count > 0) then return end
    local amount = math.min(math.max(1, math.floor(count + 0.5)), Tracers.caps.burst)
    if pcall(emitter.Emit, emitter, amount) then
        local own = Tracers.owner[emitter]
        if own then own.rec.quietAt = math.max(own.rec.quietAt or 0, os.clock() + own.life) end
    end
end

function Tracers.stream(rec, emitter, rate)
    local acc, last = 1, nil
    rec.ticks[#rec.ticks + 1] = function(age)
        if emitter.Parent == nil then return true end
        if emitter.Enabled then
            acc = acc + rate * (age - (last or age))
            if acc >= 1 then
                local count = math.floor(acc)
                acc = acc - count
                Tracers.burst(emitter, count)
            end
        end
        last = age
        return false
    end
end

function Tracers.perNode(rec, ctx, points, build)
    local list, scale = {}, rec.sizeScale
    for index, point in ipairs(points) do
        rec.sizeScale = ctx.scales and ctx.scales[index] or scale
        list[index] = Tracers.emitter(rec, point, build(ctx.t[index], index)) or false
    end
    rec.sizeScale = scale
    return list
end

function Tracers.sweep(rec, ctx, list, count)
    local fired, total = 0, #ctx.nodes
    rec.ticks[#rec.ticks + 1] = function(age)
        while fired < total and age >= ctx.travel * ctx.t[fired + 1] do
            fired = fired + 1
            Tracers.burst(list[fired] or nil, count)
        end
        return fired >= total
    end
end

function Tracers.at(ctx, u)
    local path, cumulative = ctx.path, ctx.cumulative
    local length = math.clamp(u, 0, 1) * ctx.total
    local cursor = 2
    while cursor < #path and cumulative[cursor] < length do cursor = cursor + 1 end
    local from, to = path[cursor - 1], path[cursor]
    local span = cumulative[cursor] - cumulative[cursor - 1]
    local k = span > 1e-6 and math.clamp((length - cumulative[cursor - 1]) / span, 0, 1) or 0
    local direction = to - from
    if direction.Magnitude < 1e-6 then direction = ctx.chord end
    return from + direction * k, direction.Unit
end

function Tracers.runner(rec, ctx, width, arrive)
    local part = Tracers.make(rec, "Part", Tracers.solid(CFrame.new(ctx.path[1])))
    local top = Tracers.make(rec, "Attachment", { Position = Vector3.new(0, width / 2, 0) }, part)
    local bottom = Tracers.make(rec, "Attachment", { Position = Vector3.new(0, -width / 2, 0) }, part)
    rec.ticks[#rec.ticks + 1] = function(age)
        local u = math.clamp(age / ctx.travel, 0, 1)
        part.CFrame = CFrame.new((Tracers.at(ctx, u)))
        if u >= 1 and arrive then arrive() end
        return u >= 1
    end
    return part, top, bottom
end

function Tracers.core(rec, ctx, points, width, alpha, tint)
    local list = {}
    for index = 1, #points - 1 do
        local beam = Tracers.make(rec, "Beam", {
            Attachment0 = points[index], Attachment1 = points[index + 1], FaceCamera = true, LightEmission = 1, LightInfluence = 0, Segments = 1,
            Width0 = width, Width1 = width, Transparency = NumberSequence.new(alpha),
            Color = ColorSequence.new(tint(ctx.colorAt(ctx.t[index])), tint(ctx.colorAt(ctx.t[index + 1]))),
        })
        propSet(beam, "Brightness", 2 * rec.bright)
        list[#list + 1] = beam
        rec.beams = rec.beams + 1
    end
    return list
end

function Tracers.fadeOut(rec, list, alpha, from, length)
    rec.ticks[#rec.ticks + 1] = function(age)
        local k = math.clamp((age - from) / length, 0, 1)
        if k > 0 then
            local value = NumberSequence.new(alpha + (1 - alpha) * k)
            for _, beam in ipairs(list) do propSet(beam, "Transparency", value) end
        end
        return k >= 1
    end
end

function Tracers.impact(rec, ctx, specs)
    if not ctx.hit then return end
    local point = Tracers.make(rec, "Part", Tracers.solid(CFrame.new(ctx.hit), Vector3.new(0.05, 0.05, 0.05)))
    local list, scale = {}, rec.sizeScale
    rec.sizeScale = Tracers.distScale(ctx.hit)
    for _, spec in ipairs(specs) do list[#list + 1] = { emitter = Tracers.emitter(rec, point, spec.props), count = spec.count } end
    rec.sizeScale = scale
    rec.ticks[#rec.ticks + 1] = function(age)
        if age < ctx.travel then return false end
        for _, item in ipairs(list) do Tracers.burst(item.emitter, item.count * ctx.density) end
        return true
    end
end

function Tracers.spawnFx(name, path, color, hit, speed, mine)
    local camera = propGet(Workspace, "CurrentCamera")
    if not camera then return false end
    local cumulative, total = Tracers.measure(path)
    if total < 1 then return false end
    local nodes = Tracers.nodes(path, cumulative, total, mine == false and 1 or math.clamp(math.ceil(total / 16), 3, 11))
    local gradient = flag("trace_gradient", false)
    local rainbow = gradient and flag("trace_rainbow", false)
    local start = flag("trace_grad_start", Color3.fromRGB(255, 94, 94))
    local finish = flag("trace_grad_end", Color3.fromRGB(94, 160, 255))
    local ctx = {
        path = path, cumulative = cumulative, total = total, nodes = nodes, t = {}, color = color, chord = path[#path] - path[1],
        hit = flag("trace_fx_impact", true) and hit or nil,
        travel = math.clamp(total / math.max(type(speed) == "number" and speed or 0, 300), 0.03, 1.2),
        keep = math.clamp(flag("trace_time", 4), 0.5, 10), density = math.clamp(flag("trace_fx_density", 1), 0.25, 3),
        scale = math.clamp(flag("trace_width", 1), 0.2, 3), psize = math.clamp(flag("trace_fx_size", 1), 0.25, 3),
        fade = gradient and math.clamp(flag("trace_grad_fade", 0), 0, 1) or 0,
    }
    if ctx.chord.Magnitude < 1e-6 then ctx.chord = Vector3.new(0, 0, -1) end
    ctx.scales = {}
    for index = 1, #nodes do
        ctx.t[index] = (index - 1) / (#nodes - 1)
        ctx.scales[index] = Tracers.distScale(nodes[index])
    end
    function ctx.colorAt(t)
        if rainbow then return Color3.fromHSV((t * 0.8) % 1, 0.85, 1) end
        if gradient then return Util.lerpColor(start, finish, t) end
        return color
    end
    local glow = flag("trace_glow", false)
    local rec = { objects = {}, ticks = {}, emitters = 0, beams = 0, born = os.clock(), bright = glow and 1 + 0.2 * math.clamp(flag("trace_glow_strength", 4), 0, 10) or 1,
        mine = mine ~= false, travel = ctx.travel, sizeScale = Tracers.distScale(path[math.ceil(#path / 2)]) }
    local build = rec.mine and Tracers.particle[name] or Tracers.cheap
    local ok = Util.guard("tracer fx " .. name, function()
        rec.holder = Tracers.make(rec, "Part", Tracers.solid(CFrame.new()), camera)
        rec.life = ctx.travel + build(rec, ctx) + 0.2
    end)
    if not ok then
        Tracers.dropFx(rec)
        return false
    end
    Tracers.evict(rec)
    Tracers.fx[#Tracers.fx + 1] = rec
    return true
end

function Tracers.evict(rec)
    local list, caps = Tracers.fx, Tracers.caps
    local beams, enemy = rec.beams, rec.mine and 0 or 1
    for _, other in ipairs(list) do
        beams = beams + other.beams
        if not other.mine then enemy = enemy + 1 end
    end
    local function over() return #list >= caps.records or beams > caps.beams or enemy > caps.enemy end
    while #list > 0 and over() do
        local pick
        for index, other in ipairs(list) do
            if not other.mine then
                pick = index
                break
            end
        end
        pick = pick or 1
        local oldest = table.remove(list, pick)
        beams = beams - oldest.beams
        if not oldest.mine then enemy = enemy - 1 end
        Tracers.dropFx(oldest)
    end
end

function Tracers.cheap(rec, ctx)
    local _, finish = Tracers.streak(rec, ctx, 0.2 * ctx.scale, 0.25, Tracers.plain, { hold = math.min(ctx.keep, 1), fade = 0.3 })
    Tracers.impact(rec, ctx, { { count = 6, props = {
        Lifetime = NumberRange.new(0.25, 0.4), Speed = NumberRange.new(6, 14), Drag = 2, Acceleration = Vector3.new(0, -40, 0),
        Size = Tracers.curve(0, 0.35 * ctx.psize, 1, 0), Color = ColorSequence.new(WHITE, ctx.color), Orientation = Enum.ParticleOrientation.VelocityParallel,
    } } })
    return finish
end

function Tracers.plain(color)
    return color
end

function Tracers.whiten(amount)
    return function(color) return Util.lerpColor(color, WHITE, amount) end
end

function Tracers.streak(rec, ctx, width, alpha, tint, opts)
    opts = opts or {}
    local nodes, list = ctx.nodes, {}
    for index = 1, #nodes - 1 do
        local ahead = nodes[index + 1] - nodes[index]
        local t0, t1 = ctx.t[index], ctx.t[index + 1]
        local a0, a1 = alpha + (1 - alpha) * ctx.fade * t0, alpha + (1 - alpha) * ctx.fade * t1
        local base = Tracers.point(rec, nodes[index], ahead)
        local tip = Tracers.point(rec, opts.instant and nodes[index + 1] or nodes[index], ahead)
        local beam = Tracers.make(rec, "Beam", {
            Attachment0 = base, Attachment1 = tip, FaceCamera = true, LightEmission = opts.emission or 1, LightInfluence = 0, Segments = 1,
            Width0 = width, Width1 = width, Transparency = NumberSequence.new(a0, a1), Color = ColorSequence.new(tint(ctx.colorAt(t0)), tint(ctx.colorAt(t1))),
        })
        propSet(beam, "Brightness", (opts.bright or 2) * rec.bright)
        if opts.z then propSet(beam, "ZOffset", opts.z) end
        rec.beams = rec.beams + 1
        list[index] = { beam = beam, tip = tip, t0 = t0, t1 = t1, a0 = a0, a1 = a1, open = not opts.instant }
    end
    if not opts.instant then
        rec.ticks[#rec.ticks + 1] = function(age)
            local u, open = math.clamp(age / ctx.travel, 0, 1), false
            for _, seg in ipairs(list) do
                if seg.open and u > seg.t0 then
                    local position, direction = Tracers.at(ctx, math.min(u, seg.t1))
                    seg.tip.WorldCFrame = Tracers.frame(position, direction)
                    seg.open = u < seg.t1
                end
                open = open or seg.open
            end
            return not open
        end
    end
    local from, length = ctx.travel + (opts.hold or ctx.keep), opts.fade or 0.4
    rec.ticks[#rec.ticks + 1] = function(age)
        local k = math.clamp((age - from) / length, 0, 1)
        if k > 0 then
            for _, seg in ipairs(list) do seg.beam.Transparency = NumberSequence.new(seg.a0 + (1 - seg.a0) * k, seg.a1 + (1 - seg.a1) * k) end
        end
        return k >= 1
    end
    return list, from + length - ctx.travel
end

function Tracers.reveal(rec, ctx, list, alpha)
    local shown = 0
    for _, beam in ipairs(list) do beam.Transparency = NumberSequence.new(1) end
    rec.ticks[#rec.ticks + 1] = function(age)
        while shown < #list and age >= ctx.travel * ctx.t[shown + 1] do
            shown = shown + 1
            list[shown].Transparency = NumberSequence.new(alpha)
        end
        return shown >= #list
    end
end

Tracers.particle.Comet = function(rec, ctx)
    local s, p = ctx.scale, ctx.psize
    local linger = { hold = ctx.keep * 0.6, fade = 0.6 }
    local _, finish = Tracers.streak(rec, ctx, 0.35 * s, 0.6, Tracers.plain, linger)
    Tracers.streak(rec, ctx, 0.08 * s, 0, Tracers.whiten(0.6), { hold = linger.hold, fade = linger.fade, bright = 3 })
    local head
    local part, top, bottom = Tracers.runner(rec, ctx, 0.45 * s, function() if head then head.Enabled = false end end)
    Tracers.make(rec, "Trail", {
        Attachment0 = top, Attachment1 = bottom, FaceCamera = true, LightEmission = 1, LightInfluence = 0, Lifetime = math.clamp(ctx.travel * 0.35, 0.05, 0.3),
        Color = ColorSequence.new(Util.lerpColor(ctx.colorAt(1), WHITE, 0.5), ctx.colorAt(0)), Transparency = NumberSequence.new(0, 1), WidthScale = NumberSequence.new(1, 0.1),
    }, part)
    Tracers.make(rec, "PointLight", { Color = ctx.color, Brightness = 2 * rec.bright, Range = 10 }, part)
    head = Tracers.emitter(rec, part, {
        Rate = 120, Enabled = true, Lifetime = NumberRange.new(0.25, 0.5), Speed = NumberRange.new(0.5, 2.5),
        Size = Tracers.curve(0, 0.45 * p, 1, 0), Color = ColorSequence.new(WHITE, ctx.colorAt(0)),
    })
    local tail = Tracers.perNode(rec, ctx, Tracers.nodePoints(rec, ctx), function(t)
        return {
            Lifetime = NumberRange.new(0.4, 0.9), Speed = NumberRange.new(1, 3), Acceleration = Vector3.new(0, -4, 0),
            Size = Tracers.curve(0, 0.25 * p, 1, 0), Color = ColorSequence.new(WHITE, ctx.colorAt(t)),
        }
    end)
    Tracers.sweep(rec, ctx, tail, 4 * ctx.density)
    Tracers.impact(rec, ctx, {
        { count = 1, props = { Texture = Tracers.flare, Lifetime = NumberRange.new(0.15, 0.2), Speed = NumberRange.new(0, 0), Size = Tracers.curve(0, 2.5 * p, 1, 0), Color = ColorSequence.new(WHITE, ctx.colorAt(1)) } },
        { count = 18, props = { Lifetime = NumberRange.new(0.3, 0.7), Speed = NumberRange.new(8, 18), Drag = 4, Size = Tracers.curve(0, 0.4 * p, 1, 0), Color = ColorSequence.new(WHITE, ctx.colorAt(1)) } },
    })
    return math.max(finish, 1)
end

Tracers.particle.Plasma = function(rec, ctx)
    local s, p = ctx.scale, ctx.psize
    local hold = math.max(ctx.keep, 1)
    local points = Tracers.nodePoints(rec, ctx)
    local _, finish = Tracers.streak(rec, ctx, 0.08 * s, 0, Tracers.whiten(0.75), { hold = hold, bright = 3 })
    local inner = Tracers.core(rec, ctx, points, 0.2 * s, 0.2, Tracers.whiten(0.4))
    local outer = Tracers.core(rec, ctx, points, 0.75 * s, 0.55, Tracers.plain)
    Tracers.reveal(rec, ctx, inner, 0.2)
    Tracers.reveal(rec, ctx, outer, 0.55)
    local sparks = Tracers.perNode(rec, ctx, points, function(t)
        return {
            Orientation = Enum.ParticleOrientation.VelocityParallel, Lifetime = NumberRange.new(0.08, 0.22), Speed = NumberRange.new(6, 14),
            Size = Tracers.curve(0, 0.15 * p, 1, 0), Color = ColorSequence.new(WHITE, ctx.colorAt(t)),
        }
    end)
    Tracers.sweep(rec, ctx, sparks, 6 * ctx.density)
    local step, settle = -1, ctx.travel + 0.45
    rec.ticks[#rec.ticks + 1] = function(age)
        local frame = math.floor(age / 0.05)
        if frame == step then return false end
        step = frame
        local spread = age < settle and 0.45 * s or 0
        for index = 2, #points - 1 do
            local offset = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * (2 * spread)
            points[index].WorldPosition = ctx.nodes[index] + offset
            if spread > 0 and frame % 3 == 0 and age >= ctx.travel * ctx.t[index] then Tracers.burst(sparks[index] or nil, 2 * ctx.density) end
        end
        return age >= settle
    end
    Tracers.fadeOut(rec, inner, 0.2, ctx.travel + hold, 0.4)
    Tracers.fadeOut(rec, outer, 0.55, ctx.travel + hold, 0.4)
    Tracers.impact(rec, ctx, {
        { count = 1, props = { Lifetime = NumberRange.new(0.25, 0.3), Speed = NumberRange.new(0, 0), Size = Tracers.curve(0, 3 * p, 1, 0), Color = ColorSequence.new(WHITE, ctx.colorAt(1)) } },
        { count = 16, props = { Orientation = Enum.ParticleOrientation.VelocityParallel, Lifetime = NumberRange.new(0.1, 0.3), Speed = NumberRange.new(10, 22), Size = Tracers.curve(0, 0.2 * p, 1, 0), Color = ColorSequence.new(WHITE, ctx.colorAt(1)) } },
    })
    return finish
end

Tracers.particle["Smoke ribbon"] = function(rec, ctx)
    local s, p = ctx.scale, ctx.psize
    local function soft(t) return Util.lerpColor(ctx.colorAt(t), WHITE, 0.3) end
    Tracers.streak(rec, ctx, 0.07 * s, 0.15, Tracers.whiten(0.5), { hold = math.min(ctx.keep, 0.5), fade = 0.5 })
    local part, top, bottom = Tracers.runner(rec, ctx, 0.5 * s)
    Tracers.make(rec, "Trail", {
        Attachment0 = top, Attachment1 = bottom, FaceCamera = true, Texture = SMOKE, TextureMode = Enum.TextureMode.Stretch, LightEmission = 0.2, LightInfluence = 0.5,
        Lifetime = ctx.keep, Color = ColorSequence.new(soft(1), soft(0)), Transparency = Tracers.curve(0, 0.35, 0.7, 0.6, 1, 1), WidthScale = NumberSequence.new(1, 3),
    }, part)
    local puffs = Tracers.perNode(rec, ctx, Tracers.nodePoints(rec, ctx), function(t)
        return {
            Texture = SMOKE, LightEmission = 0.15, LightInfluence = 0.6, Lifetime = NumberRange.new(1.4, 2.4), Speed = NumberRange.new(0.2, 0.6),
            RotSpeed = NumberRange.new(-30, 30), Size = Tracers.curve(0, 0.5 * p, 1, 2.6 * p), Transparency = Tracers.curve(0, 0.55, 1, 1),
            Color = ColorSequence.new(soft(t)),
        }
    end)
    Tracers.sweep(rec, ctx, puffs, 2 * ctx.density)
    Tracers.impact(rec, ctx, {
        { count = 6, props = { Texture = SMOKE, LightEmission = 0.15, LightInfluence = 0.6, Lifetime = NumberRange.new(1.2, 2), Speed = NumberRange.new(2, 5), Drag = 2, Size = Tracers.curve(0, 1 * p, 1, 4 * p), Transparency = Tracers.curve(0, 0.4, 1, 1), Color = ColorSequence.new(soft(1)) } },
        { count = 8, props = { Lifetime = NumberRange.new(0.2, 0.5), Speed = NumberRange.new(6, 14), Size = Tracers.curve(0, 0.2 * p, 1, 0), Color = ColorSequence.new(WHITE, ctx.colorAt(1)) } },
    })
    return math.max(ctx.keep, 2.4)
end

Tracers.particle.Frost = function(rec, ctx)
    local s, p = ctx.scale, ctx.psize
    local function icy(amount) return function(c) return Util.lerpColor(c, Tracers.ice, amount) end end
    local _, finish = Tracers.streak(rec, ctx, 0.45 * s, 0.6, icy(0.4), { z = -0.05 })
    Tracers.streak(rec, ctx, 0.1 * s, 0.05, icy(0.7), { bright = 2.5 })
    local crystals = Tracers.perNode(rec, ctx, Tracers.nodePoints(rec, ctx), function(t)
        return {
            Lifetime = NumberRange.new(1, 1.8), Speed = NumberRange.new(0.2, 1), Drag = 1.5, Acceleration = Vector3.new(0, -2.5, 0), RotSpeed = NumberRange.new(-20, 20),
            Size = Tracers.curve(0, 0.22 * p, 1, 0.05 * p), Color = ColorSequence.new(Util.lerpColor(ctx.colorAt(t), Tracers.ice, 0.5), WHITE),
        }
    end)
    Tracers.sweep(rec, ctx, crystals, 5 * ctx.density)
    Tracers.impact(rec, ctx, {
        { count = 6, props = { Texture = SMOKE, LightEmission = 0.3, Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(1, 3), Drag = 1, Size = Tracers.curve(0, 1 * p, 1, 4 * p), Transparency = Tracers.curve(0, 0.4, 1, 1), Color = ColorSequence.new(Tracers.ice, WHITE) } },
        { count = 16, props = { Orientation = Enum.ParticleOrientation.VelocityParallel, Lifetime = NumberRange.new(0.4, 0.9), Speed = NumberRange.new(6, 14), Acceleration = Vector3.new(0, -20, 0), Size = Tracers.curve(0, 0.25 * p, 1, 0), Color = ColorSequence.new(WHITE, Tracers.ice) } },
    })
    return math.max(finish, 1.8)
end

Tracers.particle.Railgun = function(rec, ctx)
    local s, p = ctx.scale, ctx.psize
    local linger = { hold = ctx.keep, fade = 0.8 }
    local _, finish = Tracers.streak(rec, ctx, 0.6 * s, 0.45, Tracers.plain, { hold = linger.hold, fade = linger.fade, z = -0.05 })
    Tracers.streak(rec, ctx, 0.14 * s, 0, Tracers.whiten(0.75), { hold = linger.hold, fade = linger.fade, bright = 3 })
    local rings = Tracers.perNode(rec, ctx, Tracers.nodePoints(rec, ctx), function(t)
        return {
            Texture = Tracers.ring, EmissionDirection = Enum.NormalId.Right, SpreadAngle = Vector2.new(0, 0), Speed = NumberRange.new(0.6, 1.2), Drag = 1.5,
            Orientation = Enum.ParticleOrientation.VelocityPerpendicular, Lifetime = NumberRange.new(0.9, 1.6), RotSpeed = NumberRange.new(90, 180),
            Size = Tracers.curve(0, 0.3 * p, 0.3, 0.8 * p, 1, 1.1 * p), Transparency = Tracers.curve(0, 0.1, 1, 1),
            Color = ColorSequence.new(Util.lerpColor(ctx.colorAt(t), WHITE, 0.4), ctx.colorAt(t)),
        }
    end)
    Tracers.sweep(rec, ctx, rings, 2 * ctx.density)
    Tracers.impact(rec, ctx, {
        { count = 1, props = { Texture = Tracers.flare, Lifetime = NumberRange.new(0.2, 0.3), Speed = NumberRange.new(0, 0), Size = Tracers.curve(0, 3.5 * p, 1, 0), Color = ColorSequence.new(WHITE, ctx.colorAt(1)) } },
        { count = 3, props = { Texture = Tracers.ring, Lifetime = NumberRange.new(0.4, 0.7), Speed = NumberRange.new(0, 0), Size = Tracers.curve(0, 0.4 * p, 1, 3 * p), Transparency = Tracers.curve(0, 0.1, 1, 1), Color = ColorSequence.new(ctx.colorAt(1)) } },
        { count = 20, props = { Orientation = Enum.ParticleOrientation.VelocityParallel, Lifetime = NumberRange.new(0.2, 0.5), Speed = NumberRange.new(12, 26), Drag = 3, Size = Tracers.curve(0, 0.2 * p, 1, 0), Color = ColorSequence.new(WHITE, ctx.colorAt(1)) } },
    })
    return math.max(finish, 1.8)
end

Tracers.particle.Laser = function(rec, ctx)
    local s, p = ctx.scale, ctx.psize
    ctx.travel = 0.03
    local linger = { instant = true, hold = ctx.keep, fade = 0.25 }
    local _, finish = Tracers.streak(rec, ctx, 0.24 * s, 0.82, Tracers.plain, { instant = true, hold = linger.hold, fade = linger.fade, z = -0.05 })
    Tracers.streak(rec, ctx, 0.05 * s, 0, Tracers.plain, { instant = true, hold = linger.hold, fade = linger.fade, bright = 4 })
    Tracers.streak(rec, ctx, 0.02 * s, 0, Tracers.whiten(0.85), { instant = true, hold = linger.hold, fade = linger.fade, bright = 4 })
    local shimmer = Tracers.perNode(rec, ctx, Tracers.nodePoints(rec, ctx), function(t)
        return {
            Texture = SMOKE, LightEmission = 0.4, Lifetime = NumberRange.new(0.6, 1.2), Speed = NumberRange.new(0.2, 0.6), Acceleration = Vector3.new(0, 1.5, 0),
            RotSpeed = NumberRange.new(-40, 40), Size = Tracers.curve(0, 0.15 * p, 1, 0.6 * p), Transparency = Tracers.curve(0, 0.85, 1, 1),
            Color = ColorSequence.new(Util.lerpColor(ctx.colorAt(t), WHITE, 0.5)),
        }
    end)
    Tracers.sweep(rec, ctx, shimmer, 2 * ctx.density)
    local again, stop = 0.35, ctx.travel + ctx.keep
    rec.ticks[#rec.ticks + 1] = function(age)
        if age >= again and age < stop then
            again = age + 0.35
            for _, emitter in ipairs(shimmer) do Tracers.burst(emitter or nil, ctx.density) end
        end
        return age >= stop
    end
    Tracers.impact(rec, ctx, {
        { count = 1, props = { Texture = Tracers.flare, Lifetime = NumberRange.new(0.2, 0.3), Speed = NumberRange.new(0, 0), Size = Tracers.curve(0, 1.6 * p, 1, 0.8 * p), Color = ColorSequence.new(WHITE, ctx.colorAt(1)) } },
        { count = 14, props = { Orientation = Enum.ParticleOrientation.VelocityParallel, Lifetime = NumberRange.new(0.15, 0.4), Speed = NumberRange.new(8, 18), Acceleration = Vector3.new(0, -30, 0), Size = Tracers.curve(0, 0.15 * p, 1, 0), Color = ColorSequence.new(WHITE, ctx.colorAt(1)) } },
    })
    return math.max(finish, 1.2)
end

Tracers.particle["Ion bolt"] = function(rec, ctx)
    local s, p = ctx.scale, ctx.psize
    local stop = ctx.travel + ctx.keep
    local points = Tracers.nodePoints(rec, ctx)
    local _, finish = Tracers.streak(rec, ctx, 0.05 * s, 0.4, Tracers.whiten(0.5))
    local bolt = Tracers.core(rec, ctx, points, 0.14 * s, 0, Tracers.whiten(0.5))
    local halo = Tracers.core(rec, ctx, points, 0.5 * s, 0.6, Tracers.plain)
    Tracers.reveal(rec, ctx, bolt, 0)
    Tracers.reveal(rec, ctx, halo, 0.6)
    local sparks = Tracers.perNode(rec, ctx, points, function(t)
        return {
            Orientation = Enum.ParticleOrientation.VelocityParallel, Lifetime = NumberRange.new(0.08, 0.25), Speed = NumberRange.new(8, 16),
            Size = Tracers.curve(0, 0.14 * p, 1, 0), Color = ColorSequence.new(WHITE, ctx.colorAt(t)),
        }
    end)
    Tracers.sweep(rec, ctx, sparks, 4 * ctx.density)
    local flicker = {}
    for index = 2, #points - 1, 3 do
        local emitter = Tracers.emitter(rec, points[index], {
            Texture = Tracers.bolt, Lifetime = NumberRange.new(0.06, 0.14), Speed = NumberRange.new(0, 0),
            Size = Tracers.curve(0, 1.1 * p, 1, 0.5 * p), Color = ColorSequence.new(WHITE, ctx.colorAt(ctx.t[index])),
        })
        if emitter then flicker[#flicker + 1] = { emitter = emitter, at = ctx.travel * ctx.t[index] } end
    end
    local step = -1
    rec.ticks[#rec.ticks + 1] = function(age)
        local frame = math.floor(age / 0.06)
        if frame == step then return false end
        step = frame
        for index = 2, #points - 1 do
            local offset = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * (1.2 * s)
            points[index].WorldPosition = ctx.nodes[index] + offset
        end
        if frame % 2 == 0 then
            for _, item in ipairs(flicker) do
                if age >= item.at then Tracers.burst(item.emitter, 1) end
            end
        end
        return age >= stop
    end
    Tracers.fadeOut(rec, bolt, 0, stop, 0.4)
    Tracers.fadeOut(rec, halo, 0.6, stop, 0.4)
    Tracers.impact(rec, ctx, {
        { count = 3, props = { Texture = Tracers.bolt, Lifetime = NumberRange.new(0.1, 0.25), Speed = NumberRange.new(0, 0), Size = Tracers.curve(0, 1.8 * p, 1, 0.6 * p), Color = ColorSequence.new(WHITE, ctx.colorAt(1)) } },
        { count = 18, props = { Orientation = Enum.ParticleOrientation.VelocityParallel, Lifetime = NumberRange.new(0.1, 0.3), Speed = NumberRange.new(10, 22), Size = Tracers.curve(0, 0.16 * p, 1, 0), Color = ColorSequence.new(WHITE, ctx.colorAt(1)) } },
    })
    return math.max(ctx.keep + 0.4, finish)
end

Tracers.particle["Tracer round"] = function(rec, ctx)
    local s, p = ctx.scale, ctx.psize
    local hot = Util.lerpColor(ctx.color, Color3.fromRGB(255, 190, 90), 0.35)
    local haze = math.min(ctx.keep, 2.5)
    local _, finish = Tracers.streak(rec, ctx, 0.06 * s, 0.55, Tracers.whiten(0.3), { hold = math.min(ctx.keep, 0.25), fade = 0.35 })
    local part, top, bottom = Tracers.runner(rec, ctx, 0.16 * s)
    local slug = Tracers.make(rec, "Trail", {
        Attachment0 = top, Attachment1 = bottom, FaceCamera = true, LightEmission = 1, LightInfluence = 0, Lifetime = math.clamp(ctx.travel * 0.12, 0.03, 0.08),
        Color = ColorSequence.new(WHITE, hot), Transparency = NumberSequence.new(0, 0.6), WidthScale = NumberSequence.new(1, 0.4),
    }, part)
    propSet(slug, "Brightness", 3 * rec.bright)
    Tracers.make(rec, "Trail", {
        Attachment0 = top, Attachment1 = bottom, FaceCamera = true, Texture = SMOKE, TextureMode = Enum.TextureMode.Stretch, LightEmission = 0.1, LightInfluence = 0.7,
        Lifetime = haze, Color = ColorSequence.new(Util.lerpColor(ctx.colorAt(0), Color3.fromRGB(150, 150, 150), 0.75)),
        Transparency = Tracers.curve(0, 0.75, 1, 1), WidthScale = NumberSequence.new(0.6, 2.5),
    }, part)
    Tracers.make(rec, "PointLight", { Color = hot, Brightness = 2 * rec.bright, Range = 6 }, part)
    local shed = Tracers.perNode(rec, ctx, Tracers.nodePoints(rec, ctx), function()
        return {
            Orientation = Enum.ParticleOrientation.VelocityParallel, Lifetime = NumberRange.new(0.1, 0.25), Speed = NumberRange.new(2, 6), Drag = 3,
            Size = Tracers.curve(0, 0.08 * p, 1, 0), Color = ColorSequence.new(WHITE, hot),
        }
    end)
    Tracers.sweep(rec, ctx, shed, 1.5 * ctx.density)
    Tracers.impact(rec, ctx, {
        { count = 14, props = { Orientation = Enum.ParticleOrientation.VelocityParallel, Lifetime = NumberRange.new(0.15, 0.4), Speed = NumberRange.new(8, 18), Acceleration = Vector3.new(0, -40, 0), Size = Tracers.curve(0, 0.14 * p, 1, 0), Color = ColorSequence.new(WHITE, hot) } },
        { count = 4, props = { Texture = SMOKE, LightEmission = 0, LightInfluence = 1, Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(1, 3), Drag = 2, Size = Tracers.curve(0, 0.4 * p, 1, 1.8 * p), Transparency = Tracers.curve(0, 0.55, 1, 1), Color = ColorSequence.new(Color3.fromRGB(170, 165, 155)) } },
    })
    return math.max(finish, haze, 1)
end

Tracers.particle["Neon streak"] = function(rec, ctx)
    local s, p = ctx.scale, ctx.psize
    local _, finish = Tracers.streak(rec, ctx, 1.4 * s, 0.82, Tracers.plain, { fade = 0.9, z = -0.1 })
    Tracers.streak(rec, ctx, 0.6 * s, 0.35, Tracers.plain, { fade = 0.9, z = -0.05 })
    Tracers.streak(rec, ctx, 0.22 * s, 0, Tracers.whiten(0.55), { fade = 0.9, bright = 3 })
    local motes = Tracers.perNode(rec, ctx, Tracers.nodePoints(rec, ctx), function(t)
        return {
            Texture = Tracers.flare, Lifetime = NumberRange.new(0.4, 0.8), Speed = NumberRange.new(0.2, 0.8), Drag = 2,
            Size = Tracers.curve(0, 0.5 * p, 1, 0), Transparency = Tracers.curve(0, 0.4, 1, 1), Color = ColorSequence.new(ctx.colorAt(t)),
        }
    end)
    Tracers.sweep(rec, ctx, motes, 2 * ctx.density)
    Tracers.impact(rec, ctx, {
        { count = 1, props = { Texture = Tracers.flare, Lifetime = NumberRange.new(0.25, 0.35), Speed = NumberRange.new(0, 0), Size = Tracers.curve(0, 3 * p, 1, 0), Transparency = Tracers.curve(0, 0.2, 1, 1), Color = ColorSequence.new(ctx.colorAt(1)) } },
        { count = 12, props = { Lifetime = NumberRange.new(0.3, 0.6), Speed = NumberRange.new(6, 14), Drag = 4, Size = Tracers.curve(0, 0.3 * p, 1, 0), Color = ColorSequence.new(WHITE, ctx.colorAt(1)) } },
    })
    return finish
end

Tracers.particle.Void = function(rec, ctx)
    local s, p = ctx.scale, ctx.psize
    local purple = Color3.fromRGB(150, 60, 255)
    local function edge(c) return Util.lerpColor(c, purple, 0.6) end
    local _, finish = Tracers.streak(rec, ctx, 0.7 * s, 0.55, edge, { fade = 0.6, z = -0.05 })
    Tracers.streak(rec, ctx, 0.3 * s, 0, function(c) return Util.lerpColor(c, BLACK, 0.92) end, { fade = 0.6, emission = 0, bright = 1 })
    local wisps = Tracers.perNode(rec, ctx, Tracers.nodePoints(rec, ctx), function(t)
        return {
            Lifetime = NumberRange.new(0.6, 1.2), Speed = NumberRange.new(0.8, 2), Drag = 2, RotSpeed = NumberRange.new(-90, 90),
            Size = Tracers.curve(0, 0.25 * p, 1, 0), Color = ColorSequence.new(edge(ctx.colorAt(t)), Util.lerpColor(purple, BLACK, 0.6)),
        }
    end)
    Tracers.sweep(rec, ctx, wisps, 4 * ctx.density)
    Tracers.impact(rec, ctx, {
        { count = 3, props = { Texture = SMOKE, LightEmission = 0, LightInfluence = 0, Lifetime = NumberRange.new(0.4, 0.6), Speed = NumberRange.new(0, 0.5), Size = Tracers.curve(0, 2.5 * p, 1, 0), Transparency = Tracers.curve(0, 0.2, 1, 1), Color = ColorSequence.new(Util.lerpColor(purple, BLACK, 0.85)) } },
        { count = 16, props = { Lifetime = NumberRange.new(0.3, 0.7), Speed = NumberRange.new(6, 14), Drag = 4, Size = Tracers.curve(0, 0.25 * p, 1, 0), Color = ColorSequence.new(WHITE, edge(ctx.colorAt(1))) } },
    })
    return math.max(finish, 1.4)
end

Util.onUnload(function()
    for _, record in ipairs(Tracers.list) do Tracers.drop(record) end
    Tracers.list = {}
    for _, rec in ipairs(Tracers.fx) do Tracers.dropFx(rec) end
    Tracers.fx, Tracers.queue = {}, {}
end)

local Impacts = {
    list = {}, cap = 30, build = {},
    names = { "Spark burst", "Dust puff", "Glow ring", "Neon crater", "Electric arc", "Ember splash", "Ice shatter", "Portal ripple", "Hologram marker", "Ink splat",
        "Shock decal", "Plasma scorch", "Gold coins", "Pixel shatter", "Lightning strike", "Smoke column", "Neon splash" },
    ring = "rbxassetid://5857851812", bolt = "rbxassetid://5833323391", shard = "rbxassetid://6772766413", dust = "rbxassetid://14302399641",
    heart = "rbxassetid://5857851618", flare = "rbxassetid://8983307836",
}

function Impacts.run(rec, age)
    for slot = #rec.ticks, 1, -1 do
        local ok, done = pcall(rec.ticks[slot], age)
        if not ok then Util.note("fx tick" .. tostring(done), "fx tick:", done) end
        if not ok or done == true then table.remove(rec.ticks, slot) end
    end
end

function Impacts.surface(position, normal)
    local up = normal.Unit
    local ref = math.abs(up.Y) > 0.95 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)
    local right = up:Cross(ref).Unit
    local back = right:Cross(up)
    return CFrame.new(position.X, position.Y, position.Z, right.X, up.X, back.X, right.Y, up.Y, back.Y, right.Z, up.Z, back.Z)
end

function Impacts.onBody(instance)
    local ok, body = pcall(function()
        local parent = instance.Parent
        return Visible.bodies[parent] or (parent and Visible.bodies[parent.Parent]) or false
    end)
    return ok and body == true
end

function Impacts.normal(shot)
    local path = shot.path
    local direction = path[#path] - path[math.max(#path - 1, 1)]
    direction = direction.Magnitude > 1e-4 and direction.Unit or Vector3.new(0, -1, 0)
    local normal = shot.cast and propGet(shot.cast, "Normal")
    if typeof(normal) ~= "Vector3" or normal.Magnitude < 1e-3 then
        local probe = Game.cast(shot.hit - direction * 0.5, direction, Barrel.params)
        normal = probe and propGet(probe, "Normal")
    end
    if typeof(normal) ~= "Vector3" or normal.Magnitude < 1e-3 then normal = -direction end
    return normal.Unit, direction
end

function Impacts.fromBullet(info, mine, late)
    if not flag("impact_on", false) then return false end
    if not mine and not (flag("impact_enemy", false) and not Tracers.isTeam(info)) then return false end
    local shot = Tracers.solve(info, mine)
    if not (shot and shot.hit) then return false end
    local instance = shot.cast and propGet(shot.cast, "Instance")
    if instance and Impacts.onBody(instance) then return false end
    local normal, direction = Impacts.normal(shot)
    return Impacts.add(shot.hit, normal, direction, math.clamp((shot.time or 0) - (late or 0), 0, 2))
end

Tracers.onShot = Impacts.fromBullet

function Impacts.add(position, normal, direction, delay)
    local chosen, names = Util.set("impact_list", { "Spark burst" }), {}
    for _, name in ipairs(Impacts.names) do
        if chosen[name] then names[#names + 1] = name end
    end
    if #names == 0 then return false end
    local cap = math.clamp(math.floor(flag("impact_max", Impacts.cap)), 1, Impacts.cap)
    while #Impacts.list > cap do Tracers.dropFx(table.remove(Impacts.list, 1)) end
    if #Impacts.list == cap then
        local oldest = Impacts.list[1]
        if oldest.built and not Tracers.settled(oldest, os.clock()) then return false end
        Tracers.dropFx(table.remove(Impacts.list, 1))
    end
    local rec = { objects = {}, ticks = {}, emitters = 0, bright = 1, at = os.clock() + delay, names = names, pos = position, normal = normal, direction = direction }
    Impacts.list[#Impacts.list + 1] = rec
    if delay <= 0 then Impacts.spawn(rec) end
    return true
end

function Impacts.spawn(rec)
    rec.built, rec.born, rec.life = true, os.clock(), 0
    local camera = propGet(Workspace, "CurrentCamera")
    if not camera then return end
    rec.sizeScale = Tracers.distScale(rec.pos)
    local up = flag("impact_align", true) and rec.normal or Vector3.new(0, 1, 0)
    local ctx = {
        frame = Impacts.surface(rec.pos, up), up = up, direction = rec.direction,
        color = flag("impact_color", Color3.fromRGB(120, 200, 255)), alpha = Util.alpha("impact_color", 0),
        size = math.clamp(flag("impact_size", 1), 0.25, 3), life = math.clamp(flag("impact_time", 1.2), 0.2, 5),
        density = math.clamp(flag("impact_density", 1), 0.25, 3),
    }
    local ok = Util.guard("impact", function()
        rec.holder = Tracers.make(rec, "Part", Tracers.solid(ctx.frame), camera)
        for _, name in ipairs(rec.names) do
            rec.life = math.max(rec.life, Impacts.build[name](rec, ctx) or ctx.life)
        end
    end)
    if not ok then
        Tracers.dropFx(rec)
        rec.life = 0
    end
end

function Impacts.step(now)
    if #Impacts.list == 0 then return end
    if not flag("impact_on", false) then return Impacts.clear() end
    for index = #Impacts.list, 1, -1 do
        local rec = Impacts.list[index]
        if not rec.built and now >= rec.at then Impacts.spawn(rec) end
        if rec.built then
            local age = now - rec.born
            if age >= rec.life and Tracers.settled(rec, now) then
                Tracers.dropFx(rec)
                table.remove(Impacts.list, index)
            else
                Impacts.run(rec, age)
            end
        end
    end
end

function Impacts.clear()
    for _, rec in ipairs(Impacts.list) do Tracers.dropFx(rec) end
    Impacts.list = {}
end

Util.onUnload(Impacts.clear)

function Impacts.preload()
    local list, seen = {}, {}
    local function add(id)
        if type(id) == "string" and id:find("^rbxassetid://") and not seen[id] then
            seen[id] = true
            list[#list + 1] = id
        end
    end
    for _, id in ipairs({ Tracers.ring, Tracers.flare, Tracers.bolt, Impacts.ring, Impacts.bolt, Impacts.shard, Impacts.dust, Impacts.heart, Impacts.flare, DynSky.flare, DynSky.clouds, DynSky.galaxy, DynSky.nebula }) do add(id) end
    for _, preset in pairs(Tracers.presets()) do add(preset.Texture) end
    local ok, provider = pcall(game.GetService, game, "ContentProvider")
    if ok and provider then pcall(provider.PreloadAsync, provider, list) end
end

task.spawn(function() pcall(Impacts.preload) end)

function Impacts.adorn(rec, class, props, parent)
    local base = { Adornee = parent or rec.holder, AlwaysOnTop = false, ZIndex = 0, AdornCullingMode = Enum.AdornCullingMode.Never }
    for key, value in pairs(props) do base[key] = value end
    return Tracers.make(rec, class, base, parent)
end

function Impacts.disc(rec, radius, color, alpha, inner, lift)
    local disc = Impacts.adorn(rec, "CylinderHandleAdornment", {
        Radius = radius, Height = 0.05, Color3 = color, Transparency = alpha,
        CFrame = CFrame.new(0, lift or 0.02, 0) * CFrame.Angles(math.pi / 2, 0, 0),
    })
    if inner then propSet(disc, "InnerRadius", inner) end
    return disc
end

function Impacts.fade(rec, list, from, length)
    rec.ticks[#rec.ticks + 1] = function(age)
        local k = math.clamp((age - from) / length, 0, 1)
        if k > 0 then
            for _, item in ipairs(list) do item[1].Transparency = item[2] + (1 - item[2]) * k end
        end
        return k >= 1
    end
end

function Impacts.emit(rec, ctx, count, props)
    local emitter = Tracers.emitter(rec, rec.holder, props)
    Tracers.burst(emitter, count * ctx.density)
    return emitter
end

function Impacts.spray(spread, props)
    props.EmissionDirection, props.SpreadAngle = Enum.NormalId.Top, Vector2.new(spread, spread)
    return props
end

Impacts.build["Spark burst"] = function(rec, ctx)
    local s = ctx.size
    Impacts.emit(rec, ctx, 1, { Lifetime = NumberRange.new(0.08, 0.12), Speed = NumberRange.new(0, 0), Size = Tracers.curve(0, 1.6 * s, 1, 0), Color = ColorSequence.new(WHITE, ctx.color) })
    Impacts.emit(rec, ctx, 24, Impacts.spray(70, {
        Orientation = Enum.ParticleOrientation.VelocityParallel, Lifetime = NumberRange.new(0.2, 0.55), Speed = NumberRange.new(10 * s, 26 * s), Drag = 2,
        Acceleration = Vector3.new(0, -50, 0), Size = Tracers.curve(0, 0.14 * s, 1, 0), Color = ColorSequence.new(WHITE, ctx.color),
    }))
    return 0.6
end

Impacts.build["Dust puff"] = function(rec, ctx)
    local s = ctx.size
    local tint = Util.lerpColor(ctx.color, Color3.fromRGB(170, 160, 145), 0.65)
    Impacts.emit(rec, ctx, 8, Impacts.spray(60, {
        Texture = SMOKE, LightEmission = 0, LightInfluence = 1, Lifetime = NumberRange.new(0.8, 1.6), Speed = NumberRange.new(2 * s, 5 * s), Drag = 3,
        RotSpeed = NumberRange.new(-40, 40), Acceleration = Vector3.new(0, 0.6, 0), Size = Tracers.curve(0, 0.5 * s, 1, 2.6 * s),
        Transparency = Tracers.curve(0, math.max(0.45, ctx.alpha), 1, 1), Color = ColorSequence.new(tint),
    }))
    Impacts.emit(rec, ctx, 12, Impacts.spray(80, {
        Texture = Impacts.dust, LightEmission = 0.3, LightInfluence = 0.7, Lifetime = NumberRange.new(0.6, 1.2), Speed = NumberRange.new(3 * s, 8 * s), Drag = 2,
        Acceleration = Vector3.new(0, -12, 0), Size = Tracers.curve(0, 0.12 * s, 1, 0.04 * s), Color = ColorSequence.new(tint, ctx.color),
    }))
    return 1.6
end

Impacts.build["Glow ring"] = function(rec, ctx)
    local s, alpha = ctx.size, math.max(ctx.alpha, 0.05)
    local soft = math.max(ctx.alpha, 0.55)
    local ring = Impacts.disc(rec, 0.2 * s, ctx.color, alpha, 0.16 * s, 0.03)
    local core = Impacts.disc(rec, 0.5 * s, Util.lerpColor(ctx.color, WHITE, 0.5), soft, nil, 0.02)
    rec.ticks[#rec.ticks + 1] = function(age)
        local k = math.clamp(age / ctx.life, 0, 1)
        local radius = (0.2 + 2.2 * (1 - (1 - k) ^ 3)) * s
        ring.Radius = radius
        propSet(ring, "InnerRadius", radius * 0.8)
        ring.Transparency, core.Transparency = alpha + (1 - alpha) * k, soft + (1 - soft) * math.min(k * 2, 1)
        return k >= 1
    end
    Impacts.emit(rec, ctx, 1, { Texture = Impacts.flare, Lifetime = NumberRange.new(0.2, 0.3), Speed = NumberRange.new(0, 0), Size = Tracers.curve(0, 1.4 * s, 1, 0), Transparency = Tracers.curve(0, 0.3, 1, 1), Color = ColorSequence.new(ctx.color) })
    return ctx.life
end

Impacts.build["Neon crater"] = function(rec, ctx)
    local s, a = ctx.size, ctx.alpha
    local pitAlpha, glowAlpha = math.max(a, 0.1), math.max(a, 0.7)
    local pit = Impacts.disc(rec, 0.45 * s, Util.lerpColor(ctx.color, BLACK, 0.85), pitAlpha, nil, 0.02)
    local rim = Impacts.disc(rec, 0.62 * s, ctx.color, a, 0.45 * s, 0.03)
    local glow = Impacts.disc(rec, 0.95 * s, ctx.color, glowAlpha, 0.62 * s, 0.025)
    local hold = ctx.life * 0.6
    rec.ticks[#rec.ticks + 1] = function(age)
        local k = math.clamp((age - hold) / (ctx.life - hold), 0, 1)
        local pulse = 0.5 + 0.5 * math.sin(age * 12)
        rim.Transparency = a + (1 - a) * (k + (1 - k) * 0.3 * pulse)
        glow.Transparency = glowAlpha + (1 - glowAlpha) * math.max(k, 0.5 * pulse)
        pit.Transparency = pitAlpha + (1 - pitAlpha) * k
        return age >= ctx.life
    end
    Impacts.emit(rec, ctx, 10, Impacts.spray(35, {
        Lifetime = NumberRange.new(0.6, 1.2), Speed = NumberRange.new(1 * s, 3 * s), Acceleration = Vector3.new(0, 4, 0), Drag = 1,
        Size = Tracers.curve(0, 0.18 * s, 1, 0), Color = ColorSequence.new(WHITE, ctx.color),
    }))
    return ctx.life
end

Impacts.build["Electric arc"] = function(rec, ctx)
    local s, a = ctx.size, ctx.alpha
    local chains, bolts = {}, {}
    for arc = 1, 4 do
        local chain = {}
        for index = 1, 4 do chain[index] = Tracers.make(rec, "Attachment", {}) end
        for index = 1, 3 do
            bolts[#bolts + 1] = Tracers.make(rec, "Beam", {
                Attachment0 = chain[index], Attachment1 = chain[index + 1], FaceCamera = true, LightEmission = 1, LightInfluence = 0, Segments = 1,
                Width0 = 0.09 * s, Width1 = 0.05 * s, Color = ColorSequence.new(WHITE, ctx.color), Transparency = NumberSequence.new(a),
            })
        end
        chains[arc] = chain
    end
    local function layout()
        for _, chain in ipairs(chains) do
            local angle, reach = math.random() * math.pi * 2, (0.6 + math.random() * 1.2) * s
            local finish = Vector3.new(math.cos(angle) * reach, 0.05, math.sin(angle) * reach)
            for index, point in ipairs(chain) do
                local t = (index - 1) / (#chain - 1)
                local jitter = Vector3.zero
                if index > 1 and index < #chain then jitter = Vector3.new(math.random() - 0.5, math.random() * 0.8, math.random() - 0.5) * (0.6 * s) end
                point.Position = finish * t + jitter + Vector3.new(0, 0.05, 0)
            end
        end
    end
    layout()
    local stop, step = math.min(ctx.life, 0.6), 0
    rec.ticks[#rec.ticks + 1] = function(age)
        local frame = math.floor(age / 0.05)
        if frame ~= step then
            step = frame
            layout()
        end
        local k = math.clamp((age - stop * 0.5) / (stop * 0.5), 0, 1)
        local value = NumberSequence.new(a + (1 - a) * k)
        for _, beam in ipairs(bolts) do beam.Transparency = value end
        return age >= stop
    end
    Impacts.emit(rec, ctx, 4, { Texture = Impacts.bolt, Lifetime = NumberRange.new(0.1, 0.25), Speed = NumberRange.new(0, 0), Size = Tracers.curve(0, 1.2 * s, 1, 0.4 * s), Color = ColorSequence.new(ctx.color) })
    Impacts.emit(rec, ctx, 14, Impacts.spray(80, {
        Orientation = Enum.ParticleOrientation.VelocityParallel, Lifetime = NumberRange.new(0.1, 0.3), Speed = NumberRange.new(8 * s, 18 * s),
        Size = Tracers.curve(0, 0.12 * s, 1, 0), Color = ColorSequence.new(WHITE, ctx.color),
    }))
    return stop + 0.3
end

Impacts.build["Ember splash"] = function(rec, ctx)
    local s = ctx.size
    local hot = Color3.fromRGB(255, 140, 40)
    local tint = Util.lerpColor(hot, ctx.color, 0.4)
    Impacts.emit(rec, ctx, 5, Impacts.spray(40, { Texture = Tracers.fire, Lifetime = NumberRange.new(0.2, 0.4), Speed = NumberRange.new(1, 3), Size = Tracers.curve(0, 1.1 * s, 1, 0), Color = ColorSequence.new(hot, ctx.color) }))
    Impacts.emit(rec, ctx, 18, Impacts.spray(55, {
        Lifetime = NumberRange.new(0.8, 1.8), Speed = NumberRange.new(6 * s, 14 * s), Drag = 1.5, Acceleration = Vector3.new(0, -24, 0),
        Size = Tracers.curve(0, 0.16 * s, 0.7, 0.1 * s, 1, 0),
        Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, WHITE), ColorSequenceKeypoint.new(0.3, tint), ColorSequenceKeypoint.new(1, Color3.fromRGB(90, 20, 10)) }),
    }))
    local light = Tracers.make(rec, "PointLight", { Color = tint, Brightness = 3, Range = 6 * s })
    rec.ticks[#rec.ticks + 1] = function(age)
        local k = math.clamp(age / 0.5, 0, 1)
        light.Brightness = 3 * (1 - k) * (0.7 + 0.3 * math.random())
        return k >= 1
    end
    return 1.8
end

Impacts.build["Ice shatter"] = function(rec, ctx)
    local s, a = ctx.size, ctx.alpha
    local tint = Util.lerpColor(ctx.color, Tracers.ice, 0.6)
    local frostAlpha = math.max(a, 0.35)
    local frost = Impacts.disc(rec, 0.75 * s, tint, frostAlpha, nil, 0.02)
    local list = { { frost, frostAlpha } }
    local crystals = {}
    for index = 1, 5 do
        local angle = index / 5 * math.pi * 2 + math.random() * 0.6
        local reach = (0.15 + math.random() * 0.4) * s
        local crystal = Impacts.adorn(rec, "BoxHandleAdornment", {
            Size = Vector3.new(0.12, 0.05, 0.12) * s, Color3 = Util.lerpColor(tint, WHITE, 0.3), Transparency = math.max(a, 0.15),
            CFrame = CFrame.new(math.cos(angle) * reach, 0.1 * s, math.sin(angle) * reach) * CFrame.Angles(math.random() - 0.5, angle, math.random() - 0.5),
        })
        crystals[index] = { crystal, (0.35 + math.random() * 0.35) * s }
        list[#list + 1] = { crystal, math.max(a, 0.15) }
    end
    rec.ticks[#rec.ticks + 1] = function(age)
        local k = math.clamp(age / 0.12, 0, 1)
        for _, item in ipairs(crystals) do item[1].Size = Vector3.new(0.12 * s, 0.05 * s + item[2] * k, 0.12 * s) end
        return k >= 1
    end
    Impacts.fade(rec, list, ctx.life * 0.5, ctx.life * 0.5)
    Impacts.emit(rec, ctx, 16, Impacts.spray(65, {
        Texture = Impacts.shard, Lifetime = NumberRange.new(0.5, 1), Speed = NumberRange.new(8 * s, 18 * s), Acceleration = Vector3.new(0, -60, 0),
        RotSpeed = NumberRange.new(-360, 360), Size = Tracers.curve(0, 0.25 * s, 1, 0.1 * s), Color = ColorSequence.new(tint, WHITE),
    }))
    Impacts.emit(rec, ctx, 4, Impacts.spray(70, {
        Texture = SMOKE, LightEmission = 0.3, Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(1, 3), Drag = 1,
        Size = Tracers.curve(0, 0.6 * s, 1, 2.4 * s), Transparency = Tracers.curve(0, 0.5, 1, 1), Color = ColorSequence.new(Tracers.ice, WHITE),
    }))
    return math.max(ctx.life, 1.4)
end

Impacts.build["Portal ripple"] = function(rec, ctx)
    local s, a = ctx.size, ctx.alpha
    local rings = {}
    for index = 1, 3 do
        rings[index] = Impacts.disc(rec, 0.1, index == 2 and Util.lerpColor(ctx.color, WHITE, 0.5) or ctx.color, 1, 0.08, 0.03 + index * 0.005)
    end
    local coreAlpha = math.max(a, 0.25)
    local core = Impacts.disc(rec, 0.9 * s, Util.lerpColor(ctx.color, BLACK, 0.6), coreAlpha, nil, 0.02)
    rec.ticks[#rec.ticks + 1] = function(age)
        for index, ring in ipairs(rings) do
            local k = math.clamp((age - (index - 1) * ctx.life * 0.18) / (ctx.life * 0.64), 0, 1)
            local radius = 0.1 + 2.2 * s * k
            ring.Radius = radius
            propSet(ring, "InnerRadius", radius * 0.88)
            ring.Transparency = (k <= 0 or k >= 1) and 1 or a + (1 - a) * k
        end
        local k = math.clamp(age / ctx.life, 0, 1)
        core.Radius = 0.9 * s * (1 - k * k)
        core.Transparency = coreAlpha + (1 - coreAlpha) * k
        return k >= 1
    end
    Impacts.emit(rec, ctx, 3, {
        Texture = Impacts.ring, Lifetime = NumberRange.new(0.4, 0.8), Speed = NumberRange.new(0, 0), RotSpeed = NumberRange.new(200, 400),
        Size = Tracers.curve(0, 0.2 * s, 1, 1.8 * s), Transparency = Tracers.curve(0, 0.2, 1, 1), Color = ColorSequence.new(ctx.color, WHITE),
    })
    return ctx.life
end

Impacts.build["Hologram marker"] = function(rec, ctx)
    local s, a = ctx.size, ctx.alpha
    local function at(age)
        local spin = age * 3
        return ctx.frame * CFrame.new(0, (0.9 + 0.08 * math.sin(age * 4)) * s, 0) * CFrame.Angles(spin * 0.7, spin, 0)
    end
    local cube = Tracers.make(rec, "Part", Tracers.solid(at(0), Vector3.new(0.6, 0.6, 0.6) * s))
    local box = Tracers.make(rec, "SelectionBox", { Adornee = cube, LineThickness = 0.025 * s, Color3 = ctx.color, Transparency = a, SurfaceColor3 = ctx.color, SurfaceTransparency = 0.85 }, cube)
    local inner = Impacts.adorn(rec, "BoxHandleAdornment", { Size = Vector3.new(0.25, 0.25, 0.25) * s, Color3 = WHITE, Transparency = math.max(a, 0.5) }, cube)
    local stem = Impacts.adorn(rec, "CylinderHandleAdornment", { Radius = 0.02 * s, Height = 0.9 * s, Color3 = ctx.color, Transparency = math.max(a, 0.4), CFrame = CFrame.new(0, 0.45 * s, 0) * CFrame.Angles(math.pi / 2, 0, 0) })
    local base = Impacts.disc(rec, 0.35 * s, ctx.color, math.max(a, 0.5), 0.3 * s, 0.03)
    local list = { { box, a }, { inner, math.max(a, 0.5) }, { stem, math.max(a, 0.4) }, { base, math.max(a, 0.5) } }
    rec.ticks[#rec.ticks + 1] = function(age)
        cube.CFrame = at(age)
        local k = math.clamp((age - ctx.life * 0.6) / (ctx.life * 0.4), 0, 1)
        box.SurfaceTransparency = 0.85 + 0.15 * k
        return age >= ctx.life
    end
    Impacts.fade(rec, list, ctx.life * 0.6, ctx.life * 0.4)
    return ctx.life
end

Impacts.build["Ink splat"] = function(rec, ctx)
    local s, a = ctx.size, ctx.alpha
    local ink = Util.lerpColor(ctx.color, BLACK, 0.25)
    local blots = {}
    for index = 1, 6 do
        local angle, reach = math.random() * math.pi * 2, index == 1 and 0 or (0.3 + math.random() * 0.7) * s
        local blot = Impacts.adorn(rec, "CylinderHandleAdornment", {
            Radius = 0.05, Height = 0.03, Color3 = ink, Transparency = a,
            CFrame = CFrame.new(math.cos(angle) * reach, 0.02 + index * 0.002, math.sin(angle) * reach) * CFrame.Angles(math.pi / 2, 0, 0),
        })
        blots[index] = { blot, index == 1 and 0.7 * s or (0.12 + math.random() * 0.25) * s }
    end
    rec.ticks[#rec.ticks + 1] = function(age)
        local grow = 1 - (1 - math.clamp(age / 0.12, 0, 1)) ^ 2
        local k = math.clamp((age - ctx.life * 0.7) / (ctx.life * 0.3), 0, 1)
        for _, item in ipairs(blots) do
            item[1].Radius = math.max(0.05, item[2] * grow)
            item[1].Transparency = a + (1 - a) * k
        end
        return age >= ctx.life
    end
    Impacts.emit(rec, ctx, 14, Impacts.spray(60, {
        LightEmission = 0, LightInfluence = 1, Lifetime = NumberRange.new(0.3, 0.6), Speed = NumberRange.new(6 * s, 12 * s), Acceleration = Vector3.new(0, -50, 0),
        Size = Tracers.curve(0, 0.15 * s, 1, 0.05 * s), Transparency = Tracers.curve(0, a, 1, 1), Color = ColorSequence.new(ink),
    }))
    return ctx.life
end

function Impacts.toss(rec, ctx, items, gravity)
    rec.ticks[#rec.ticks + 1] = function(age)
        local k = math.clamp((age - ctx.life * 0.7) / (ctx.life * 0.3), 0, 1)
        for _, item in ipairs(items) do
            local t = math.min(age, item.land)
            local y = math.max(item.v.Y * t - 0.5 * gravity * t * t, item.floor)
            item.object.CFrame = CFrame.new(item.v.X * t, y, item.v.Z * t) * CFrame.Angles(t * item.spin, t * item.spin * 0.6, 0)
            item.object.Transparency = item.alpha + (1 - item.alpha) * k
        end
        return age >= ctx.life
    end
end

function Impacts.flight(spread, rise, gravity, s)
    local angle, out = math.random() * math.pi * 2, (spread[1] + math.random() * (spread[2] - spread[1])) * s
    local up = (rise[1] + math.random() * (rise[2] - rise[1])) * s
    return Vector3.new(math.cos(angle) * out, up, math.sin(angle) * out), 2 * up / gravity
end

Impacts.build["Shock decal"] = function(rec, ctx)
    local s, a = ctx.size, ctx.alpha
    local darkAlpha = math.max(a, 0.2)
    local dark = Impacts.disc(rec, 0.35 * s, Util.lerpColor(ctx.color, BLACK, 0.8), darkAlpha, nil, 0.02)
    local ring = Impacts.disc(rec, 0.9 * s, ctx.color, a, 0.78 * s, 0.03)
    local list, cracks = { { dark, darkAlpha }, { ring, a } }, {}
    for index = 1, 7 do
        local crack = Impacts.adorn(rec, "BoxHandleAdornment", { Size = Vector3.new(0.04 * s, 0.02, 0.05), Color3 = Util.lerpColor(ctx.color, WHITE, 0.4), Transparency = a })
        cracks[index] = { crack, index / 7 * math.pi * 2 + (math.random() - 0.5) * 0.5, (0.7 + math.random() * 0.9) * s }
        list[#list + 1] = { crack, a }
    end
    rec.ticks[#rec.ticks + 1] = function(age)
        local grow = 1 - (1 - math.clamp(age / 0.1, 0, 1)) ^ 2
        for _, item in ipairs(cracks) do
            local length = math.max(item[3] * grow, 0.05)
            item[1].Size = Vector3.new(0.04 * s, 0.02, length)
            item[1].CFrame = CFrame.Angles(0, item[2], 0) * CFrame.new(0, 0.03, -length / 2)
        end
        return grow >= 1
    end
    Impacts.fade(rec, list, ctx.life * 0.6, ctx.life * 0.4)
    Impacts.emit(rec, ctx, 1, { Texture = Impacts.bolt, Lifetime = NumberRange.new(0.1, 0.2), Speed = NumberRange.new(0, 0), Size = Tracers.curve(0, 1.4 * s, 1, 0.4 * s), Color = ColorSequence.new(WHITE, ctx.color) })
    Impacts.emit(rec, ctx, 10, Impacts.spray(75, {
        Orientation = Enum.ParticleOrientation.VelocityParallel, Lifetime = NumberRange.new(0.15, 0.35), Speed = NumberRange.new(8 * s, 16 * s), Drag = 2,
        Size = Tracers.curve(0, 0.12 * s, 1, 0), Color = ColorSequence.new(WHITE, ctx.color),
    }))
    return ctx.life
end

Impacts.build["Plasma scorch"] = function(rec, ctx)
    local s, a = ctx.size, ctx.alpha
    local hot, ember = Util.lerpColor(ctx.color, WHITE, 0.4), Color3.fromRGB(120, 30, 10)
    local scorchAlpha = math.max(a, 0.25)
    local scorch = Impacts.disc(rec, 0.8 * s, Util.lerpColor(ctx.color, BLACK, 0.9), scorchAlpha, nil, 0.02)
    local rim = Impacts.disc(rec, 0.55 * s, hot, a, 0.4 * s, 0.03)
    local light = Tracers.make(rec, "PointLight", { Color = ctx.color, Brightness = 3, Range = 7 * s })
    rec.ticks[#rec.ticks + 1] = function(age)
        local k = math.clamp(age / ctx.life, 0, 1)
        rim.Color3 = Util.lerpColor(hot, ember, math.min(k * 1.5, 1))
        rim.Transparency = a + (1 - a) * k
        scorch.Transparency = scorchAlpha + (1 - scorchAlpha) * math.clamp((k - 0.6) / 0.4, 0, 1)
        light.Brightness = 3 * (1 - k)
        return k >= 1
    end
    Impacts.emit(rec, ctx, 6, Impacts.spray(25, {
        Texture = Tracers.fire, Lifetime = NumberRange.new(0.4, 0.8), Speed = NumberRange.new(1 * s, 3 * s), Acceleration = Vector3.new(0, 4, 0),
        Size = Tracers.curve(0, 0.8 * s, 1, 0), Transparency = Tracers.curve(0, 0.2, 1, 1), Color = ColorSequence.new(hot, ctx.color),
    }))
    Impacts.emit(rec, ctx, 10, Impacts.spray(60, {
        Lifetime = NumberRange.new(0.3, 0.7), Speed = NumberRange.new(5 * s, 11 * s), Drag = 2, Acceleration = Vector3.new(0, -20, 0),
        Size = Tracers.curve(0, 0.14 * s, 1, 0), Color = ColorSequence.new(WHITE, ctx.color),
    }))
    return ctx.life
end

Impacts.build["Gold coins"] = function(rec, ctx)
    local s, a = ctx.size, ctx.alpha
    local gold = Util.lerpColor(Color3.fromRGB(255, 200, 50), ctx.color, 0.15)
    local gravity, coins = 30 * s, {}
    for index = 1, 8 do
        local v, land = Impacts.flight({ 2, 5 }, { 7, 12 }, gravity, s)
        local coin = Impacts.adorn(rec, "CylinderHandleAdornment", { Radius = 0.16 * s, Height = 0.04 * s, Color3 = Util.lerpColor(gold, WHITE, math.random() * 0.3), Transparency = a })
        coins[index] = { object = coin, v = v, land = land, floor = 0.05, spin = 6 + math.random() * 10, alpha = a }
    end
    Impacts.toss(rec, ctx, coins, gravity)
    Impacts.emit(rec, ctx, 12, Impacts.spray(60, {
        Texture = SPARK, Lifetime = NumberRange.new(0.4, 0.9), Speed = NumberRange.new(3 * s, 8 * s), Drag = 2,
        Size = Tracers.curve(0, 0.3 * s, 1, 0), Color = ColorSequence.new(WHITE, gold),
    }))
    return ctx.life
end

Impacts.build["Pixel shatter"] = function(rec, ctx)
    local s, a = ctx.size, ctx.alpha
    local gravity, cubes = 40 * s, {}
    for index = 1, 12 do
        local v, land = Impacts.flight({ 3, 7 }, { 3, 8 }, gravity, s)
        local shade = index % 3 == 0 and Util.lerpColor(ctx.color, WHITE, 0.5) or (index % 3 == 1 and ctx.color or Util.lerpColor(ctx.color, BLACK, 0.35))
        local size = (0.12 + math.random() * 0.1) * s
        local cube = Impacts.adorn(rec, "BoxHandleAdornment", { Size = Vector3.new(size, size, size), Color3 = shade, Transparency = a })
        cubes[index] = { object = cube, v = v, land = land, floor = size / 2, spin = 4 + math.random() * 8, alpha = a }
    end
    Impacts.toss(rec, ctx, cubes, gravity)
    Impacts.emit(rec, ctx, 1, { Lifetime = NumberRange.new(0.08, 0.12), Speed = NumberRange.new(0, 0), Size = Tracers.curve(0, 1.2 * s, 1, 0), Color = ColorSequence.new(WHITE, ctx.color) })
    return ctx.life
end

Impacts.build["Lightning strike"] = function(rec, ctx)
    local s, a = ctx.size, ctx.alpha
    local top, glowAlpha = rec.pos + Vector3.new(0, 14 * s, 0), math.max(a, 0.6)
    local points, bolts, glows = {}, {}, {}
    for index = 1, 7 do points[index] = Tracers.make(rec, "Attachment", {}) end
    for index = 1, 6 do
        bolts[index] = Tracers.make(rec, "Beam", {
            Attachment0 = points[index], Attachment1 = points[index + 1], FaceCamera = true, LightEmission = 1, LightInfluence = 0, Segments = 1,
            Width0 = 0.18 * s, Width1 = 0.12 * s, Color = ColorSequence.new(WHITE, Util.lerpColor(ctx.color, WHITE, 0.4)), Transparency = NumberSequence.new(a),
        })
        glows[index] = Tracers.make(rec, "Beam", {
            Attachment0 = points[index], Attachment1 = points[index + 1], FaceCamera = true, LightEmission = 1, LightInfluence = 0, Segments = 1,
            Width0 = 0.8 * s, Width1 = 0.6 * s, Color = ColorSequence.new(ctx.color), Transparency = NumberSequence.new(glowAlpha),
        })
    end
    local function layout()
        for index, point in ipairs(points) do
            local jitter = (index == 1 or index == #points) and Vector3.zero or Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * (1.6 * s)
            point.WorldCFrame = CFrame.new(top + (rec.pos - top) * ((index - 1) / (#points - 1)) + jitter)
        end
    end
    layout()
    local light = Tracers.make(rec, "PointLight", { Color = Util.lerpColor(ctx.color, WHITE, 0.5), Brightness = 6, Range = 14 * s })
    local stop, step = math.min(ctx.life, 0.5), 0
    rec.ticks[#rec.ticks + 1] = function(age)
        local frame = math.floor(age / 0.05)
        if frame ~= step then
            step = frame
            layout()
        end
        local k = math.clamp(age / stop, 0, 1)
        local flicker = frame % 2 == 0 and 0 or 0.25
        local core, glow = NumberSequence.new(math.min(1, a + (1 - a) * k + flicker)), NumberSequence.new(glowAlpha + (1 - glowAlpha) * k)
        for index = 1, #bolts do bolts[index].Transparency, glows[index].Transparency = core, glow end
        light.Brightness = 6 * (1 - k)
        return k >= 1
    end
    Impacts.emit(rec, ctx, 2, { Texture = Impacts.bolt, Lifetime = NumberRange.new(0.1, 0.25), Speed = NumberRange.new(0, 0), Size = Tracers.curve(0, 2 * s, 1, 0.6 * s), Color = ColorSequence.new(WHITE, ctx.color) })
    Impacts.emit(rec, ctx, 18, Impacts.spray(70, {
        Orientation = Enum.ParticleOrientation.VelocityParallel, Lifetime = NumberRange.new(0.2, 0.5), Speed = NumberRange.new(10 * s, 22 * s), Acceleration = Vector3.new(0, -40, 0),
        Size = Tracers.curve(0, 0.14 * s, 1, 0), Color = ColorSequence.new(WHITE, ctx.color),
    }))
    Impacts.emit(rec, ctx, 4, Impacts.spray(80, {
        Texture = SMOKE, LightEmission = 0, LightInfluence = 1, Lifetime = NumberRange.new(0.6, 1.2), Speed = NumberRange.new(2 * s, 4 * s), Drag = 2,
        Size = Tracers.curve(0, 0.6 * s, 1, 2.4 * s), Transparency = Tracers.curve(0, 0.5, 1, 1), Color = ColorSequence.new(Color3.fromRGB(150, 150, 160)),
    }))
    return math.max(stop + 0.3, 0.8)
end

Impacts.build["Smoke column"] = function(rec, ctx)
    local s = ctx.size
    local tint = Util.lerpColor(ctx.color, Color3.fromRGB(120, 120, 125), 0.7)
    local plume = Tracers.emitter(rec, rec.holder, {
        Texture = SMOKE, LightEmission = 0, LightInfluence = 1, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(12, 12),
        Lifetime = NumberRange.new(1.6, 2.4), Speed = NumberRange.new(3 * s, 5 * s), Acceleration = Vector3.new(0, 3 * s, 0), Drag = 0.6,
        RotSpeed = NumberRange.new(-25, 25), Size = Tracers.curve(0, 0.6 * s, 1, 3 * s), Transparency = Tracers.curve(0, math.max(0.4, ctx.alpha), 0.6, 0.7, 1, 1),
        Color = ColorSequence.new(tint),
    })
    local again, stop = 0, ctx.life * 0.6
    rec.ticks[#rec.ticks + 1] = function(age)
        if age >= again and age < stop then
            again = age + 0.12
            Tracers.burst(plume, 2 * ctx.density)
        end
        return age >= stop
    end
    Impacts.emit(rec, ctx, 6, Impacts.spray(85, {
        Texture = SMOKE, LightEmission = 0, LightInfluence = 1, Lifetime = NumberRange.new(0.6, 1.2), Speed = NumberRange.new(2 * s, 4 * s), Drag = 3,
        Size = Tracers.curve(0, 0.4 * s, 1, 1.8 * s), Transparency = Tracers.curve(0, 0.5, 1, 1), Color = ColorSequence.new(tint),
    }))
    return stop + 2.4
end

Impacts.build["Neon splash"] = function(rec, ctx)
    local s, a = ctx.size, ctx.alpha
    local glowAlpha = math.max(a, 0.35)
    local puddle = Impacts.disc(rec, 0.1, ctx.color, glowAlpha, nil, 0.02)
    local ring = Impacts.disc(rec, 0.1, Util.lerpColor(ctx.color, WHITE, 0.5), a, 0.08, 0.03)
    rec.ticks[#rec.ticks + 1] = function(age)
        local grow = 1 - (1 - math.clamp(age / 0.15, 0, 1)) ^ 2
        local wave = math.clamp(age / (ctx.life * 0.5), 0, 1)
        local k = math.clamp((age - ctx.life * 0.6) / (ctx.life * 0.4), 0, 1)
        puddle.Radius = math.max(0.1, 0.9 * s * grow)
        puddle.Transparency = glowAlpha + (1 - glowAlpha) * k
        local radius = 0.1 + 1.8 * s * (1 - (1 - wave) ^ 2)
        ring.Radius = radius
        propSet(ring, "InnerRadius", radius * 0.85)
        ring.Transparency = a + (1 - a) * wave
        return age >= ctx.life
    end
    Impacts.emit(rec, ctx, 1, { Texture = Impacts.flare, Lifetime = NumberRange.new(0.15, 0.25), Speed = NumberRange.new(0, 0), Size = Tracers.curve(0, 1.8 * s, 1, 0), Color = ColorSequence.new(WHITE, ctx.color) })
    Impacts.emit(rec, ctx, 20, Impacts.spray(35, {
        Orientation = Enum.ParticleOrientation.VelocityParallel, Lifetime = NumberRange.new(0.3, 0.7), Speed = NumberRange.new(8 * s, 14 * s), Acceleration = Vector3.new(0, -40, 0),
        Size = Tracers.curve(0, 0.16 * s, 1, 0.05 * s), Color = ColorSequence.new(Util.lerpColor(ctx.color, WHITE, 0.4), ctx.color),
    }))
    return ctx.life
end

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
    ["Skeet (alt, clean)"] = "rbxassetid://83717596220569",
    ["Fatality"] = "rbxassetid://6607142036",
    ["Bameware"] = "rbxassetid://92614567965693",
    ["Bubble Pop"] = "rbxassetid://119697580657161",
    ["Metal Tick"] = "rbxassetid://16480551554",
    ["Bell"] = "rbxassetid://9126073001",
    ["CoD Hitmarker"] = "rbxassetid://160432334",
    ["Minecraft XP"] = "rbxassetid://101023147710668",
    ["Laser Zap"] = "rbxassetid://8952019380",
    ["Glass"] = "rbxassetid://113127656562744",
    ["Bass Hit"] = "rbxassetid://6374192318",
    ["osu!"] = "rbxassetid://7149255551",
    ["Electronic Ping"] = "rbxassetid://12221990",
    ["Crowbar"] = "rbxassetid://546410481",
    ["Kill Confirm (Warzone)"] = "rbxassetid://129006786473373",
    ["Overwatch Elimination"] = "rbxassetid://18410060814",
    ["Level Up"] = "rbxassetid://860861713",
    ["Celeste Level Up"] = "rbxassetid://127199850989931",
    ["Orchestral Hit"] = "rbxassetid://1844567848",
    ["Vine Boom"] = "rbxassetid://140367458608473",
    ["Mario Coin"] = "rbxassetid://203620899",
    ["Roblox Coin"] = "rbxassetid://127645268874265",
    ["Roblox UI Stinger"] = "rbxassetid://15675043410",
    ["Classic Victory"] = "rbxassetid://12222253",
    ["Steam Achievement"] = "rbxassetid://78959439349986",
    ["Xbox Achievement"] = "rbxassetid://114852766717197",
    ["Among Us Kill"] = "rbxassetid://5700183626",
    ["ULTRAKILL Coin"] = "rbxassetid://136124980150792",
    ["Headshot Ding"] = "rbxassetid://118799613600209",
    ["Headshot Ding (short)"] = "rbxassetid://137096881472307",
    ["Apex Shield Break"] = "rbxassetid://110698656704091",
    ["Fortnite Shield Crack"] = "rbxassetid://140073271098075",
    ["Fortnite Headshot"] = "rbxassetid://2513174484",
    ["Rust Headshot"] = "rbxassetid://4764109000",
    ["TF2 Default"] = "rbxassetid://3455144981",
    ["TF2 Note"] = "rbxassetid://3466988045",
    ["TF2 Beepo"] = "rbxassetid://3466987025",
    ["TF2 Retro"] = "rbxassetid://3466984142",
    ["Quake 3"] = "rbxassetid://18518730335",
    ["Quake (alt)"] = "rbxassetid://4868633804",
    ["Halo Plasma Hit"] = "rbxassetid://128012593895616",
    ["Halo Shield Pop"] = "rbxassetid://86717349989793",
    ["Bubble Pop (soft)"] = "rbxassetid://132948338000932",
    ["Roblox Bubble"] = "rbxassetid://17208204604",
    ["Soft Click"] = "rbxassetid://16480568821",
    ["8-Bit Blip"] = "rbxassetid://16480580213",
    ["Synth Blip"] = "rbxassetid://9125397583",
    ["8-Bit Hit"] = "rbxassetid://109598434966968",
    ["Katana Slash"] = "rbxassetid://140180249061198",
    ["Anime Slice"] = "rbxassetid://81776525964742",
    ["Punch"] = "rbxassetid://109316755832781",
    ["Glass Tink"] = "rbxassetid://9114618736",
    ["Water Drop"] = "rbxassetid://403292408",
    ["Minecraft Bow Ding"] = "rbxassetid://135478009117226",
    ["XP Orb Hit"] = "rbxassetid://15181891182",
    ["MW Hitmarker"] = "rbxassetid://138832207290954",
    ["Quake Hitmarker"] = "rbxassetid://1455817260",
    ["L4D2 Ding"] = "rbxassetid://97641752127312",
    ["Case Tick"] = "rbxassetid://134329097481839",
    ["Valorant Prime"] = "rbxassetid://18329331565",
    ["Valorant Reaver"] = "rbxassetid://18339080128",
    ["Apex Knock"] = "rbxassetid://93205253060872",
    ["Apex Kill"] = "rbxassetid://121098554975978",
    ["Fortnite Elim"] = "rbxassetid://4578268588",
    ["Quake Impressive"] = "rbxassetid://119653725017052",
    ["UT Excellent"] = "rbxassetid://109636227907658",
    ["UT Headshot"] = "rbxassetid://117061855740552",
    ["Halo Infinite Kill"] = "rbxassetid://18921249379",
    ["TF2 Domination"] = "rbxassetid://3759232123",
    ["TF2 Kill"] = "rbxassetid://124543461907751",
    ["Minecraft Orb"] = "rbxassetid://118671160608385",
    ["Minecraft Level Up"] = "rbxassetid://6647877129",
    ["Minecraft Hurt"] = "rbxassetid://535690488",
    ["8-Bit Explosion"] = "rbxassetid://298553078",
    ["Retro Pop Explosion"] = "rbxassetid://89770340622391",
    ["8-Bit Death"] = "rbxassetid://120320778004569",
    ["Sword Slash"] = "rbxassetid://140277245983305",
    ["MLG Airhorn"] = "rbxassetid://678089961",
    ["Record Scratch"] = "rbxassetid://9118086936",
    ["Bruh"] = "rbxassetid://140007222940724",
    ["Oof (Official)"] = "rbxassetid://79348298352567",
    ["Ka-ching"] = "rbxassetid://7112275565",
    ["Coins Ka-ching"] = "rbxassetid://1210852193",
    ["Gong"] = "rbxassetid://17798541626",
    ["Cute Gong"] = "rbxassetid://124380386119700",
    ["Warzone Elim"] = "rbxassetid://76988259513359",
    ["Overwatch 2 Kill"] = "rbxassetid://79327164938465",
    ["Killer7 Crit"] = "rbxassetid://72735383475864",
}
local HIT_SOUND_ORDER = { "Gamesense", "CSGO", "Click", "Hitmarker", "Minecraft", "Neverlose", "Rust", "TF2", "Windows", "Alt Hitmarker", "Alt Killshot", "Alt Headshot kill", "Skeet (alt, clean)", "Fatality", "Bameware", "Bubble Pop", "Metal Tick", "Bell", "CoD Hitmarker", "Minecraft XP", "Laser Zap", "Glass", "Bass Hit", "osu!", "Electronic Ping", "Crowbar",
    "Headshot Ding", "Headshot Ding (short)", "Apex Shield Break", "Fortnite Shield Crack", "Fortnite Headshot", "Rust Headshot", "TF2 Default", "TF2 Note", "TF2 Beepo", "TF2 Retro", "Quake 3", "Quake (alt)", "Halo Plasma Hit", "Halo Shield Pop", "Bubble Pop (soft)", "Roblox Bubble",
    "Soft Click", "8-Bit Blip", "Synth Blip", "8-Bit Hit", "Katana Slash", "Anime Slice", "Punch", "Glass Tink", "Water Drop", "Minecraft Bow Ding", "XP Orb Hit", "MW Hitmarker", "Quake Hitmarker", "L4D2 Ding", "Case Tick", "Custom" }
local KILL_SOUND_ORDER = { "Gamesense", "CSGO", "Click", "Hitmarker", "Minecraft", "Neverlose", "Rust", "TF2", "Windows", "Alt Hitmarker", "Alt Killshot", "Alt Headshot kill", "Kill Confirm (Warzone)", "Overwatch Elimination", "Level Up", "Celeste Level Up", "Orchestral Hit", "Vine Boom", "Mario Coin", "Roblox Coin", "Roblox UI Stinger", "Classic Victory", "Steam Achievement", "Xbox Achievement", "Among Us Kill", "ULTRAKILL Coin",
    "Valorant Prime", "Valorant Reaver", "Apex Knock", "Apex Kill", "Fortnite Elim", "Quake Impressive", "UT Excellent", "UT Headshot", "Halo Infinite Kill", "TF2 Domination", "TF2 Kill", "Minecraft Orb", "Minecraft Level Up", "Minecraft Hurt", "8-Bit Explosion",
    "Retro Pop Explosion", "8-Bit Death", "Sword Slash", "MLG Airhorn", "Record Scratch", "Bruh", "Oof (Official)", "Ka-ching", "Coins Ka-ching", "Gong", "Cute Gong", "Warzone Elim", "Overwatch 2 Kill", "Killer7 Crit", "Custom" }

local STREAK_SETS = {
    ["Valorant"] = { [1] = "7968068093", [2] = "7968069420", [3] = "7968071357", [4] = "7968072764", [5] = "7968074794" },
    ["Dota 2"] = { [1] = "140397943730865", [2] = "118926358887065", [3] = "140467520845555", [4] = "106862934557764", [5] = "101642576209921", [6] = "76056711922637", [7] = "82677534875089", [8] = "125621554040822", [9] = "80101615094724", [10] = "98999628638541", [11] = "109593039762499" },
    ["DotA Killstreak"] = { [1] = "93254093525275", [2] = "116907610084760", [3] = "110678298850636", [4] = "92723765069002", [5] = "125662494668382", [6] = "77212563363943", [7] = "111246371044303" },
    ["Unreal Tournament Multi-kill"] = { [2] = "937894293", [3] = "937890819", [4] = "937895810", [5] = "938073601", [6] = "938076502", [7] = "938072543" },
    ["Unreal Tournament 1-5"] = { [1] = "109636227907658", [2] = "937894293", [3] = "6410923021", [4] = "937890819", [5] = "938076502" },
    ["Kill Announcer 1-8"] = { [1] = "6042277821", [2] = "6042278260", [3] = "6042278776", [4] = "6042279307", [5] = "6042279740", [6] = "6042280097", [7] = "6042280481", [8] = "6042280887" },
    ["Unreal Tournament Spree"] = { [5] = "937898383", [10] = "937900118", [15] = "937902490", [20] = "937904734", [25] = "6410918897", [30] = "937906049" },
    ["Halo Reach Medals"] = { [5] = "79144706198435", [7] = "138109270661636", [10] = "101472665916770", [15] = "110655042933470", [20] = "139742166528829" },
    ["Call of Duty"] = { [3] = "132189707", [25] = "109945056933427" },
    ["Pitched tick"] = { [1] = "16480579910" },
}
local STREAK_SPREE = { ["Unreal Tournament Spree"] = true, ["Halo Reach Medals"] = true, ["Call of Duty"] = true }
local STREAK_SET_ORDER = { "None", "Valorant", "Dota 2", "DotA Killstreak", "Unreal Tournament Multi-kill", "Unreal Tournament 1-5", "Kill Announcer 1-8", "Unreal Tournament Spree", "Halo Reach Medals", "Call of Duty", "Pitched tick", "Pitched tick (use kill sound)" }
local STREAK_PITCH = { 1, 1.122, 1.26, 1.335, 1.498 }
local KILLCAM_SOUND = "rbxassetid://9125397583"

function Feedback.play(name, volume, pitch, customFlag, maxLength)
    local entry
    if name == "Custom" then entry = customFlag and World.parseAsset(flag(customFlag, "")) else entry = HIT_SOUNDS[name] end
    if type(entry) == "table" then entry = entry[math.random(#entry)] end
    if not entry then return false end
    Feedback.sound(entry, volume, pitch, maxLength)
    return true
end

function Feedback.sound(asset, volume, pitch, maxLength)
    pcall(function()
        local sound = Instance.new("Sound")
        sound.SoundId, sound.Volume, sound.PlaybackSpeed = asset, volume, pitch
        sound.Parent = game:GetService("SoundService")
        sound:Play()
        game:GetService("Debris"):AddItem(sound, 8)
        if type(maxLength) == "number" and maxLength > 0 then
            task.delay(maxLength, function() pcall(function() sound:Stop(); sound:Destroy() end) end)
        end
    end)
end

function Feedback.preview(kind, fallback)
    if not Feedback.play(flag(kind .. "_id", fallback), flag(kind .. "_vol", 1.5), flag(kind .. "_pitch", 1), kind .. "_custom", flag(kind .. "_max", 0)) then
        World.notify("Sound: type a sound id or link in Custom sound id first")
    end
end

function Feedback.onHit(isHead)
    Feedback.at, Feedback.head = os.clock(), isHead
    Feedback.addMark(Feedback.at, isHead)
    if flag("hit_snd", false) then
        local name = flag("hit_snd_id", "Gamesense")
        if isHead and flag("hit_snd_head", false) then name = flag("hit_snd_head_id", "Alt Headshot kill") end
        Feedback.play(name, flag("hit_snd_vol", 1.5), flag("hit_snd_pitch", 1), "hit_snd_custom", flag("hit_snd_max", 0.6))
    end
end

local Killcam = { cards = {}, LENGTH = 5 }

function Killcam.start(victim, now)
    if not flag("killcam_notify", true) then return "killcam off" end
    if not Game.localAlive() then return "killcam skipped (we are dead)" end
    local name = tostring(victim.Name)
    local note = Util.notify({
        Title = "Killcam", Text = name .. " is watching you", Duration = Killcam.LENGTH, Icon = "eye", Progress = true,
        Id = "killcam_" .. tostring(victim.UserId or name), Sound = flag("killcam_sound", false) and KILLCAM_SOUND or nil,
    })
    Killcam.cards[victim] = { at = now, note = note }
    return note and "killcam" or "killcam (text notify)"
end

function Killcam.close(victim)
    local card = Killcam.cards[victim]
    if not card then return end
    Killcam.cards[victim] = nil
    if card.note then pcall(function() card.note:Close() end) end
end

function Killcam.clear()
    for victim in pairs(Killcam.cards) do Killcam.close(victim) end
end

function Killcam.step(now)
    if next(Killcam.cards) == nil then return end
    if not flag("killcam_notify", true) or not Game.localAlive() then return Killcam.clear() end
    for victim, card in pairs(Killcam.cards) do
        if now - card.at >= Killcam.LENGTH or (card.note and card.note.Closing) then Killcam.close(victim) end
    end
end

pcall(function() Util.track(Players.PlayerRemoving:Connect(function(player) Killcam.close(player) end)) end)
Util.onUnload(Killcam.clear)

local Streak = { count = 0, total = 0, last = -math.huge, shownAt = -math.huge, BURST = 12 }
Streak.labels = { "Kill", "Double kill", "Triple kill", "Quadra kill", "Penta kill" }
Streak.styles = { "Valorant bars", "Overwatch", "Minimal", "Arcade" }

function Streak.label(count, style)
    if count == 5 and style == "Valorant bars" then return "Ace" end
    return Streak.labels[count] or ("x" .. count)
end

function Streak.soundFor(set, count, total)
    local ids = STREAK_SETS[set]
    if not ids then return nil end
    if STREAK_SPREE[set] then
        if ids[total] then return ids[total] end
        local top = 0
        for at in pairs(ids) do top = math.max(top, at) end
        return total > top and total % 5 == 0 and ids[top] or nil
    end
    for at = math.min(count, 40), 1, -1 do
        if ids[at] then return ids[at] end
    end
    return nil
end

function Streak.playSound(count, total)
    local set = flag("streak_snd_set", "Valorant")
    local volume = flag("streak_snd_vol", 1.5)
    local speed = STREAK_PITCH[math.clamp(count, 1, #STREAK_PITCH)]
    if set == "Pitched tick (use kill sound)" then
        return Feedback.play(flag("kill_snd_id", "Alt Killshot"), volume, flag("kill_snd_pitch", 1) * speed, "kill_snd_custom", flag("kill_snd_max", 2.5))
    end
    local id = Streak.soundFor(set, count, total)
    if not id then return false end
    Feedback.sound("rbxassetid://" .. id, volume, set == "Pitched tick" and speed or 1)
    return true
end

function Streak.onKill(now)
    if not flag("streak_on", false) then return false end
    if now - Streak.last > flag("streak_window", 4) then Streak.count = 0 end
    Streak.count, Streak.total, Streak.last = Streak.count + 1, Streak.total + 1, now
    Streak.show(Streak.count, Streak.total, now)
    local every = math.floor(flag("streak_milestone_every", 5))
    if flag("streak_milestone", false) and every >= 1 and Streak.total % every == 0 then
        Util.notify({ Title = "Kill streak", Text = Streak.total .. " kills without dying", Icon = "flame", Duration = 4, Id = "streak_milestone" })
    end
    return Streak.playSound(Streak.count, Streak.total) and flag("streak_mute_kill", true)
end

function Streak.died()
    Streak.total = 0
    if flag("streak_reset_death", true) then Streak.count, Streak.last = 0, -math.huge end
end

function Streak.test()
    if not flag("streak_on", false) then return World.notify("Kill streak: turn it on first") end
    Streak.onKill(os.clock())
end

function Streak.make(class, parent, props)
    local object = Instance.new(class)
    for key, value in pairs(props) do object[key] = value end
    object.Parent = parent
    return object
end

function Streak.container()
    if setthreadidentity then pcall(setthreadidentity, 7) end
    local parents = {}
    pcall(function() parents[#parents + 1] = game:GetService("CoreGui") end)
    pcall(function() if gethui then parents[#parents + 1] = gethui() end end)
    for _, parent in ipairs(parents) do
        local gui
        local ok = pcall(function()
            gui = Instance.new("ScreenGui")
            gui.Name = Util.randomName()
            gui.DisplayOrder = 20
            gui.IgnoreGuiInset = true
            gui.ResetOnSpawn = false
            gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
            gui.Parent = parent
        end)
        if ok and gui and gui.Parent then return gui end
        if gui then pcall(function() gui:Destroy() end) end
    end
    return nil
end

function Streak.build()
    local ui = Streak.ui
    if ui and ui.gui.Parent then return ui end
    Streak.destroy()
    local gui = Streak.container()
    if not gui then return nil end
    local make, centre = Streak.make, Vector2.new(0.5, 0.5)
    ui = { gui = gui, bars = {}, burst = {} }
    ui.root = make("Frame", gui, { AnchorPoint = centre, BackgroundTransparency = 1, Visible = false })
    ui.ring = make("Frame", ui.root, { AnchorPoint = centre, BackgroundTransparency = 1, Visible = false, ZIndex = 2 })
    make("UICorner", ui.ring, { CornerRadius = UDim.new(0.5, 0) })
    ui.ringStroke = make("UIStroke", ui.ring, { Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
    for index = 1, Streak.BURST do
        local dot = make("Frame", ui.root, { AnchorPoint = centre, BorderSizePixel = 0, Visible = false, ZIndex = 2 })
        make("UICorner", dot, { CornerRadius = UDim.new(0.5, 0) })
        ui.burst[index] = dot
    end
    for index = 1, 5 do ui.bars[index] = make("Frame", ui.root, { AnchorPoint = centre, BorderSizePixel = 0, Visible = false, ZIndex = 3 }) end
    ui.number = make("TextLabel", ui.root, { AnchorPoint = centre, BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, Text = "", TextColor3 = WHITE, ZIndex = 4 })
    ui.numberStroke = make("UIStroke", ui.number, { Thickness = 2 })
    ui.label = make("TextLabel", ui.root, { AnchorPoint = centre, BackgroundTransparency = 1, Font = Enum.Font.GothamBold, Text = "", TextColor3 = WHITE, ZIndex = 4 })
    ui.labelStroke = make("UIStroke", ui.label, { Thickness = 1.5, Color = BLACK })
    ui.total = make("TextLabel", ui.root, { AnchorPoint = centre, BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, Text = "", TextColor3 = WHITE, ZIndex = 4 })
    make("UIStroke", ui.total, { Thickness = 1, Color = BLACK, Transparency = 0.3 })
    Streak.ui = ui
    return ui
end

function Streak.show(count, total, now)
    local ui = Streak.build()
    if not ui then return end
    ui.count, ui.kills, ui.style, ui.live = count, total, flag("streak_style", "Valorant bars"), true
    assign(ui.number, "Text", tostring(count))
    assign(ui.label, "Text", string.upper(Streak.label(count, ui.style)))
    assign(ui.total, "Text", "STREAK " .. total)
    Streak.shownAt = now
    Streak.paint(ui, 0, now)
end

function Streak.paint(ui, t, now)
    local style, count, s = ui.style, ui.count, flag("streak_scale", 1)
    local life = math.max(flag("streak_time", 2.2), 0.5)
    local fade = math.clamp((t - (life - 0.35)) / 0.35, 0, 1)
    local color = Util.lerpColor(flag("streak_color", Color3.fromRGB(255, 80, 90)), flag("streak_color2", Color3.fromRGB(255, 200, 70)), math.clamp((count - 1) / 4, 0, 1))
    if style == "Arcade" then color = Color3.fromHSV((now * 0.5 + count * 0.13) % 1, 0.65, 1) end
    local kick = math.clamp(1 - t / 0.2, 0, 1)
    local pop = style == "Minimal" and 1 or 1 + ((style == "Arcade" and 0.7 or 0.3) + 0.06 * math.min(count, 5)) * kick * kick
    local width = 320 * s
    local cx, cy = width / 2, 44 * s
    local bars = style == "Valorant bars"
    local labelY = (bars and 108 or 94) * s
    assign(ui.root, "Size", UDim2.fromOffset(width, 150 * s))
    assign(ui.root, "Position", UDim2.new(0.5, 0, flag("streak_y", 0.72), 0))
    assign(ui.root, "Visible", true)
    assign(ui.number, "Position", UDim2.fromOffset(cx, cy))
    assign(ui.number, "Size", UDim2.fromOffset(width, 80 * s))
    assign(ui.number, "TextSize", math.floor(58 * s * pop + 0.5))
    assign(ui.number, "TextColor3", Util.lerpColor(WHITE, color, 0.3))
    assign(ui.number, "TextTransparency", fade)
    assign(ui.numberStroke, "Color", color)
    assign(ui.numberStroke, "Thickness", (1 + math.min(count, 6) * 0.6) * s)
    assign(ui.numberStroke, "Transparency", 0.15 + 0.85 * fade)
    assign(ui.label, "Position", UDim2.fromOffset(cx, labelY))
    assign(ui.label, "Size", UDim2.fromOffset(width, 28 * s))
    assign(ui.label, "TextSize", math.floor(22 * s * (1 + 0.4 * (pop - 1)) + 0.5))
    assign(ui.label, "TextColor3", color)
    assign(ui.label, "TextTransparency", fade)
    assign(ui.labelStroke, "Transparency", 0.4 + 0.6 * fade)
    assign(ui.total, "Visible", flag("streak_total", true) and ui.kills >= 2)
    assign(ui.total, "Position", UDim2.fromOffset(cx, labelY + 24 * s))
    assign(ui.total, "Size", UDim2.fromOffset(width, 18 * s))
    assign(ui.total, "TextSize", math.floor(14 * s + 0.5))
    assign(ui.total, "TextTransparency", 0.15 + 0.85 * fade)
    for index, bar in ipairs(ui.bars) do
        assign(bar, "Visible", bars)
        if bars then
            local lit = index <= count
            local grow = index == math.min(count, 5) and pop or 1
            assign(bar, "Position", UDim2.fromOffset(cx + (index - 3) * 34 * s, 88 * s))
            assign(bar, "Size", UDim2.fromOffset(28 * s * grow, 5 * s * grow))
            assign(bar, "BackgroundColor3", lit and color or WHITE)
            assign(bar, "BackgroundTransparency", lit and fade or 0.75 + 0.25 * fade)
        end
    end
    local ringT = t / 0.5
    local ringOn = (style == "Overwatch" or style == "Arcade" or (bars and count >= 3)) and ringT < 1
    assign(ui.ring, "Visible", ringOn)
    if ringOn then
        local size = (50 + 150 * (1 - (1 - ringT) ^ 2)) * s * (1 + 0.12 * math.min(count, 5))
        assign(ui.ring, "Position", UDim2.fromOffset(cx, cy))
        assign(ui.ring, "Size", UDim2.fromOffset(size, size))
        assign(ui.ringStroke, "Color", color)
        assign(ui.ringStroke, "Thickness", (2 + math.min(count, 5)) * s * (1 - ringT))
        assign(ui.ringStroke, "Transparency", ringT)
    end
    local burstT = t / 0.6
    local dots = burstT < 1 and style ~= "Minimal" and (style == "Arcade" or count >= 3) and math.min(Streak.BURST, 4 + 2 * count) or 0
    for index, dot in ipairs(ui.burst) do
        local shown = index <= dots
        assign(dot, "Visible", shown)
        if shown then
            local angle = index / dots * math.pi * 2 + count
            local ease = 1 - (1 - burstT) ^ 3
            local reach = (24 + (90 + 8 * math.min(count, 8)) * ease) * s
            local size = math.max(1, 7 * s * (1 - burstT))
            assign(dot, "Position", UDim2.fromOffset(cx + math.cos(angle) * reach, cy + math.sin(angle) * reach * 0.7))
            assign(dot, "Size", UDim2.fromOffset(size, size))
            assign(dot, "BackgroundColor3", color)
            assign(dot, "BackgroundTransparency", burstT)
        end
    end
end

function Streak.step(now)
    if not flag("streak_on", false) then
        if Streak.ui or Streak.count ~= 0 or Streak.total ~= 0 then Streak.clear() end
        return
    end
    local ui = Streak.ui
    if not (ui and ui.live) then return end
    local t = now - Streak.shownAt
    if t >= math.max(flag("streak_time", 2.2), 0.5) or not ui.gui.Parent then
        ui.live = false
        assign(ui.root, "Visible", false)
        return
    end
    Streak.paint(ui, t, now)
end

function Streak.destroy()
    local ui = Streak.ui
    Streak.ui = nil
    if ui then pcall(function() ui.gui:Destroy() end) end
end

function Streak.clear()
    Streak.count, Streak.total, Streak.last = 0, 0, -math.huge
    Streak.destroy()
end
Util.onUnload(Streak.clear)

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

function Feedback.identity()
    for _, name in ipairs({ "getthreadidentity", "getidentity", "getthreadcontext" }) do
        local fn = getgenv()[name]
        if type(fn) == "function" then
            local ok, level = pcall(fn)
            if ok then return level end
        end
    end
    return "?"
end

function Feedback.capture(info)
    if type(info) ~= "table" then return nil end
    local event = { victim = info.victim, attacker = info.attacker, forced = info.forced == true, weapon = info.weaponIndex, at = os.clock() }
    if flag("misc_debug_kills", false) then event.thread = Feedback.identity() end
    if event.attacker == LocalPlayer and event.victim ~= nil and event.victim ~= LocalPlayer then Feedback.noteKill(event.victim, event.at) end
    return event
end

function Feedback.onOwnKill(victim, info)
    local now = info.at or os.clock()
    local fired = {}
    Feedback.markKill(now)
    if flag("kill_fx", false) then fired[#fired + 1] = "kill effects" end
    fired[#fired + 1] = info.forced and "killcam skipped (forced)" or Killcam.start(victim, now)
    local muted = false
    if flag("streak_on", false) then
        muted = Streak.onKill(now)
        fired[#fired + 1] = "streak " .. Streak.count .. "/" .. Streak.total
    end
    if flag("kill_snd", false) then
        if muted then
            fired[#fired + 1] = "kill sound muted by streak"
        else
            Feedback.play(flag("kill_snd_id", "Alt Killshot"), flag("kill_snd_vol", 1.5), flag("kill_snd_pitch", 1), "kill_snd_custom", flag("kill_snd_max", 2.5))
            fired[#fired + 1] = "kill sound"
        end
    end
    return table.concat(fired, ", ")
end

function Feedback.onKill(info)
    if type(info) ~= "table" then return end
    local result = "not ours"
    if info.victim == LocalPlayer then
        Killcam.clear()
        Streak.died()
        result = "our death: killcam cleared, streak reset"
    elseif info.attacker == LocalPlayer and info.victim ~= nil then
        result = Feedback.onOwnKill(info.victim, info)
    end
    if flag("misc_debug_kills", false) then
        local function name(player) return player == nil and "nil" or tostring(type(player) ~= "string" and player.Name or player) end
        print(string.format("[Aster kills] victim=%s attacker=%s forced=%s weapon=%s thread=%s delay=%.3fs -> %s", name(info.victim), name(info.attacker),
            tostring(info.forced), tostring(info.weapon), tostring(info.thread), os.clock() - (info.at or os.clock()), result ~= "" and result or "nothing enabled"))
    end
end

Feedback.queue, Feedback.hits = {}, {}

function Feedback.push(queue, cap, fn, capture, ...)
    if #queue >= cap then table.remove(queue, 1) end
    if capture then
        queue[#queue + 1] = { fn = fn, args = { n = 1, capture(...) } }
    else
        queue[#queue + 1] = { fn = fn, args = table.pack(...) }
    end
end

function Feedback.defer(fn, capture, ...)
    Feedback.push(Feedback.queue, 64, fn, capture, ...)
end

function Feedback.deferHit(fn, ...)
    Feedback.push(Feedback.hits, 32, fn, nil, ...)
end

function Feedback.run(name)
    local queue = Feedback[name]
    if #queue == 0 then return end
    Feedback[name] = {}
    for _, item in ipairs(queue) do Util.guard("pf-event", item.fn, table.unpack(item.args, 1, item.args.n)) end
end

function Feedback.drain()
    Feedback.run("queue")
    Feedback.run("hits")
end

function Feedback.listen(key, event, fn, capture)
    if Feedback.hooked[key] or type(event) ~= "table" or type(event.connect) ~= "function" then return end
    local ok, connection = pcall(function()
        return event:connect(function(...) pcall(Feedback.defer, fn, capture, ...) end)
    end)
    if not ok then return end
    Feedback.hooked[key] = true
    Util.onUnload(function()
        pcall(function() connection:Disconnect() end)
        Feedback.hooked[key] = nil
    end)
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
                if bullet and type(info) == "table" then
                    local mine = type(info.extra) == "table" and info.extra.firearmObject ~= nil
                    pcall(Tracers.enqueue, info, bullet, mine)
                end
                return bullet
            end
        end)
    end
    local events = mods.PlayerStatusEvents or {}
    Feedback.listen("kills", events.onPlayerDied, Feedback.onKill, Feedback.capture)
    Feedback.listen("spawns", events.onPlayerSpawned, Killcam.close)
    Feedback.listen("rounds", (mods.RoundSystemClientEvents or {}).onRoundEnded, Killcam.clear)
end

Feedback.marks, Feedback.slots, Feedback.cfg = {}, {}, {}
Feedback.styles = { "Classic X", "Rotated plus", "Circle ring", "Diamond", "Brackets", "Dot" }
Feedback.anims = { "None", "Expand", "Shrink", "Spin", "Pulse" }
Feedback.corners = { Vector2.new(-1, -1), Vector2.new(1, -1), Vector2.new(-1, 1), Vector2.new(1, 1) }
Feedback.diagonals = { Vector2.new(-1, -1).Unit, Vector2.new(1, -1).Unit, Vector2.new(-1, 1).Unit, Vector2.new(1, 1).Unit }
Feedback.axes = { Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(-1, 0), Vector2.new(0, -1) }

function Feedback.addMark(now, isHead)
    local hit = Feedback.lastHit
    if #Feedback.marks >= 6 then table.remove(Feedback.marks, 1) end
    local mark = { at = now, head = isHead == true, kill = false, pos = hit and now - hit.at < 0.3 and hit.pos or nil }
    Feedback.marks[#Feedback.marks + 1] = mark
    return mark
end

function Feedback.noteHit(position, now)
    if typeof(position) ~= "Vector3" then return end
    Feedback.lastHit = { pos = position, at = now }
    local mark = Feedback.marks[#Feedback.marks]
    if mark and not mark.pos and now - mark.at < 0.3 then mark.pos = position end
end

function Feedback.markKill(now)
    if not (flag("hit_marker_kill", false) or flag("hit_marker_skull", false)) then return end
    local mark = Feedback.marks[#Feedback.marks]
    if not (mark and now - mark.at < 0.5) then mark = Feedback.addMark(now, false) end
    mark.kill, mark.at = true, now
end

function Feedback.slot(index)
    local slot = Feedback.slots[index]
    if slot then return slot end
    slot = { lines = {}, edges = {}, all = {}, on = {}, live = false }
    local function add(kind, props)
        props.Visible = false
        local drawing = Draw.new(kind, props)
        slot.all[#slot.all + 1] = drawing
        return drawing
    end
    for line = 1, 8 do
        slot.edges[line] = add("Line", { Thickness = 3, Color = BLACK, ZIndex = 11 })
        slot.lines[line] = add("Line", { Thickness = 1, ZIndex = 12 })
    end
    slot.ringEdge = add("Circle", { Filled = false, NumSides = 32, Color = BLACK, ZIndex = 11 })
    slot.ring = add("Circle", { Filled = false, NumSides = 32, ZIndex = 12 })
    slot.jaw = add("Square", { Filled = true, ZIndex = 12 })
    slot.eyes = { add("Circle", { Filled = true, NumSides = 12, Color = BLACK, ZIndex = 13 }), add("Circle", { Filled = true, NumSides = 12, Color = BLACK, ZIndex = 13 }) }
    Feedback.slots[index] = slot
    return slot
end

function Feedback.drawMark(slot, at, mark, progress, cfg)
    local on, used = slot.on, 0
    local scale, spin, gap = 1, 0, cfg.gap
    if cfg.anim == "Expand" then
        gap = gap + progress * 4
    elseif cfg.anim == "Shrink" then
        scale = 1 + 0.8 * (1 - progress) ^ 2
    elseif cfg.anim == "Spin" then
        spin = progress * math.pi
    elseif cfg.anim == "Pulse" then
        scale = 1 + 0.35 * math.sin(progress * math.pi * 3) ^ 2
    end
    local killed = mark.kill and cfg.kill
    if killed then scale = scale * cfg.killScale end
    local size, thick = cfg.size * scale, cfg.thick
    gap = gap * scale
    local color, opacity = cfg.color, cfg.opacity
    if killed then color, opacity = cfg.killColor, cfg.killOpacity elseif mark.head then color, opacity = cfg.headColor, cfg.headOpacity end
    local alpha = (1 - progress) * opacity
    local cos, sin = math.cos(spin), math.sin(spin)
    local function seg(x0, y0, x1, y1)
        used = used + 1
        local from = Vector2.new(at.X + x0 * cos - y0 * sin, at.Y + x0 * sin + y0 * cos)
        local to = Vector2.new(at.X + x1 * cos - y1 * sin, at.Y + x1 * sin + y1 * cos)
        local line = slot.lines[used]
        line.From, line.To, line.Color, line.Thickness, line.Transparency = from, to, color, thick, alpha
        on[line] = true
        if cfg.outline then
            local edge = slot.edges[used]
            edge.From, edge.To, edge.Thickness, edge.Transparency = from, to, thick + 2, alpha
            on[edge] = true
        end
    end
    local function circle(centre, radius, filled)
        local ring = slot.ring
        ring.Position, ring.Radius, ring.Filled, ring.Color, ring.Thickness, ring.Transparency = centre, radius, filled, color, thick, alpha
        on[ring] = true
        if cfg.outline then
            local edge = slot.ringEdge
            edge.Position, edge.Radius, edge.Thickness, edge.Transparency = centre, filled and radius + 1 or radius, filled and 2 or thick + 2, alpha
            on[edge] = true
        end
    end
    local style = (mark.kill and cfg.skull) and "Skull" or cfg.style
    if style == "Skull" then
        local r = math.max(size * 0.75, 4)
        circle(Vector2.new(at.X, at.Y - r * 0.2), r, true)
        local jaw = slot.jaw
        jaw.Position, jaw.Size, jaw.Color, jaw.Transparency = Vector2.new(at.X - r * 0.55, at.Y + r * 0.35), Vector2.new(r * 1.1, r * 0.75), color, alpha
        on[jaw] = true
        for side, eye in ipairs(slot.eyes) do
            eye.Position, eye.Radius, eye.Transparency = Vector2.new(at.X + (side == 1 and -1 or 1) * r * 0.38, at.Y - r * 0.2), r * 0.27, alpha
            on[eye] = true
        end
    elseif style == "Circle ring" then
        circle(at, gap + size * 0.6, false)
    elseif style == "Dot" then
        circle(at, math.max(2, size * 0.35), true)
    elseif style == "Diamond" then
        local r = gap + size
        seg(r, 0, 0, r)
        seg(0, r, -r, 0)
        seg(-r, 0, 0, -r)
        seg(0, -r, r, 0)
    elseif style == "Brackets" then
        local h, arm = gap + size, math.max(size * 0.6, 3)
        for _, corner in ipairs(Feedback.corners) do
            seg(corner.X * h, corner.Y * h, corner.X * (h - arm), corner.Y * h)
            seg(corner.X * h, corner.Y * h, corner.X * h, corner.Y * (h - arm))
        end
    else
        local reach = gap + size
        for _, direction in ipairs(style == "Rotated plus" and Feedback.axes or Feedback.diagonals) do
            seg(direction.X * gap, direction.Y * gap, direction.X * reach, direction.Y * reach)
        end
    end
end

function Feedback.stepMarks(cam, center, now)
    local marks = Feedback.marks
    while #marks > 0 and now - marks[1].at > 4 do table.remove(marks, 1) end
    if #marks > 0 and flag("hit_marker", false) then
        local cfg = Feedback.cfg
        cfg.duration = flag("hit_marker_time", 0.4)
        cfg.size, cfg.thick, cfg.gap = flag("hit_marker_size", 9), flag("hit_marker_thick", 1), flag("hit_marker_gap", 3)
        cfg.style, cfg.anim, cfg.outline = flag("hit_marker_style", "Classic X"), flag("hit_marker_anim", "Expand"), flag("hit_marker_outline", true)
        cfg.color, cfg.opacity = flag("hit_marker_color", WHITE), Util.opacity("hit_marker_color")
        cfg.headColor, cfg.headOpacity = flag("hit_marker_head", WHITE), Util.opacity("hit_marker_head")
        cfg.kill, cfg.skull, cfg.killScale = flag("hit_marker_kill", false), flag("hit_marker_skull", false), flag("hit_marker_kill_size", 1.5)
        cfg.killColor, cfg.killOpacity = flag("hit_marker_kill_color", WHITE), Util.opacity("hit_marker_kill_color")
        local world, drawn = flag("hit_marker_3d", false), 0
        for index = #marks, 1, -1 do
            local mark = marks[index]
            local life = cfg.duration * ((mark.kill and (cfg.kill or cfg.skull)) and 1.5 or 1)
            local age = now - mark.at
            if age >= 0 and age < life then
                local at, show = center, index == #marks
                if world and mark.pos then
                    local point, front = Draw.project(cam, mark.pos)
                    at, show = point, front
                end
                if show then
                    drawn = drawn + 1
                    Feedback.drawMark(Feedback.slot(drawn), at, mark, age / life, cfg)
                end
            end
        end
    end
    for _, slot in ipairs(Feedback.slots) do
        local on = slot.on
        local any = next(on) ~= nil
        if slot.live or any then
            for _, drawing in ipairs(slot.all) do drawing.Visible = on[drawing] == true end
            for drawing in pairs(on) do on[drawing] = nil end
            slot.live = any
        end
    end
end

function Feedback.step(cam, center, now)
    Feedback.stepMarks(cam, center, now)
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

local HitCham = { list = {}, cap = 12 }

function HitCham.victim(player)
    local record = Entities.byPlayer[player]
    if record and record.enemy == false then return nil end
    if record and type(record.hash) == "table" and record.rendered then return record.hash end
    local ok, hash = pcall(function()
        local entry = Game.mods.ReplicationInterface.getEntry(player)
        local object = entry and entry._thirdPersonObject
        return object and object:getCharacterHash()
    end)
    if ok and type(hash) == "table" then return hash end
    return nil
end

function HitCham.frameOf(part)
    local ok, frame = pcall(function() return part.CFrame end)
    if ok and typeof(frame) == "CFrame" then return frame end
    local okPosition, position = pcall(function() return part.Position end)
    if okPosition and typeof(position) == "Vector3" then return CFrame.new(position) end
    return nil
end

function HitCham.sizeOf(part, name)
    local ok, size = pcall(function() return part.Size end)
    if not (ok and typeof(size) == "Vector3") or math.min(size.X, size.Y, size.Z) < 0.05 then size = PART_SIZES[name] or Vector3.new(1, 1, 1) end
    return size
end

function HitCham.shape(rec, slot, round, grow, color, alpha, zindex)
    local class = round and Chams.roundClass() or "BoxHandleAdornment"
    local layer = { base = alpha, class = class }
    local props = { Adornee = slot.holder, AlwaysOnTop = rec.top, ZIndex = zindex, Color3 = color, Transparency = alpha, AdornCullingMode = Enum.AdornCullingMode.Never }
    if class == "BoxHandleAdornment" then
        layer.size = slot.size + Vector3.new(grow, grow, grow)
        props.Size = layer.size
    else
        local radius, height = Chams.headDimensions()
        if class == "SphereHandleAdornment" then radius = math.max(radius, height / 2) end
        layer.radius, layer.height = radius + grow / 2, height + grow
        props.Radius = layer.radius
        if class == "CylinderHandleAdornment" then props.Height, props.CFrame = layer.height, CFrame.new(Vector3.zero, Vector3.new(0, 90, 0)) end
    end
    layer.object = Tracers.make(rec, class, props, slot.holder)
    slot.layers[#slot.layers + 1] = layer
end

function HitCham.wire(rec, slot, color, alpha)
    local surface = 1 - (1 - alpha) * 0.15
    local layer = { base = alpha, class = "SelectionBox", surface = surface }
    layer.object = Tracers.make(rec, "SelectionBox", { Adornee = slot.holder, LineThickness = 0.04, Color3 = color, Transparency = alpha, SurfaceColor3 = color, SurfaceTransparency = surface }, slot.holder)
    slot.layers[#slot.layers + 1] = layer
end

function HitCham.curve(style, k)
    if style == "Pop" then
        local eased = 1 - (1 - k) ^ 3
        return eased, 1 + 0.3 * eased
    elseif style == "Pulse" then
        local wave = 0.5 - 0.5 * math.cos(k * math.pi * 6)
        return k + (1 - k) * 0.65 * wave, 1 + 0.06 * wave
    end
    return k, 1
end

function HitCham.paint(rec, fade, scale)
    fade, scale = math.floor(fade * 30 + 0.5) / 30, math.floor(scale * 60 + 0.5) / 60
    if fade == rec.fadeShown and scale == rec.scale then return end
    rec.fadeShown = fade
    local resize = scale ~= rec.scale
    for _, slot in ipairs(rec.slots) do
        for _, layer in ipairs(slot.layers) do
            local object = layer.object
            object.Transparency = layer.base + (1 - layer.base) * fade
            if layer.surface then object.SurfaceTransparency = layer.surface + (1 - layer.surface) * fade end
            if resize then
                if layer.size then
                    object.Size = layer.size * scale
                elseif layer.radius then
                    object.Radius = layer.radius * scale
                    if layer.class == "CylinderHandleAdornment" then object.Height = layer.height * scale end
                else
                    slot.holder.Size = slot.size * scale
                end
            end
        end
    end
    rec.scale = scale
end

function HitCham.follow(rec)
    for _, slot in ipairs(rec.slots) do
        local ok, alive = pcall(function() return slot.part.Parent ~= nil end)
        local frame = ok and alive and HitCham.frameOf(slot.part)
        if frame then slot.holder.CFrame = frame end
    end
end

function HitCham.onHit(player, position, partName)
    if player == nil or player == LocalPlayer or not flag("hit_cham_on", false) then return end
    local hash = HitCham.victim(player)
    local camera = propGet(Workspace, "CurrentCamera")
    if not (hash and camera) then return end
    local hitName = type(partName) == "string" and hash[partName] and partName or "Torso"
    local names = flag("hit_cham_part", false) and { hitName } or CHAM_PARTS
    local look = flag("hit_cham_look", "Solid")
    local color, alpha = flag("hit_cham_color", Color3.fromRGB(255, 70, 110)), Util.alpha("hit_cham_color", 0.35)
    local outline = flag("hit_cham_outline", false)
    local rec = {
        objects = {}, ticks = {}, slots = {}, emitters = 0, bright = 1, born = os.clock(), scale = 1, player = player,
        life = math.clamp(flag("hit_cham_time", 0.8), 0.1, 5), fade = flag("hit_cham_fade", "Linear"),
        follow = flag("hit_cham_follow", false), top = flag("hit_cham_top", true),
    }
    rec.span = rec.life
    local ok = Util.guard("hit chams", function()
        rec.root = Tracers.make(rec, "Part", Tracers.solid(CFrame.new()), camera)
        rec.holder = rec.root
        for _, name in ipairs(names) do
            local part = hash[name]
            local frame = part and HitCham.frameOf(part)
            if frame then
                local slot = { part = part, size = HitCham.sizeOf(part, name), layers = {} }
                slot.holder = Tracers.make(rec, "Part", Tracers.solid(frame, slot.size), rec.root)
                rec.slots[#rec.slots + 1] = slot
                if name == hitName then rec.hit = slot end
                local round = name == "Head"
                if look == "Wireframe" then
                    HitCham.wire(rec, slot, color, alpha)
                elseif look == "Glow" then
                    HitCham.shape(rec, slot, round, 0, Util.lerpColor(color, WHITE, 0.35), alpha * 0.6, 3)
                    HitCham.shape(rec, slot, round, 0.35, color, 0.75 + 0.25 * alpha, 1)
                else
                    HitCham.shape(rec, slot, round, 0, color, alpha, 3)
                end
                if outline then HitCham.shape(rec, slot, round, 0.14, flag("hit_cham_outline_color", WHITE), Util.alpha("hit_cham_outline_color", 0.4), 2) end
            end
        end
    end)
    if not ok or #rec.slots == 0 then
        Tracers.dropFx(rec)
        return
    end
    local cap = math.clamp(math.floor(flag("hit_cham_max", HitCham.cap)), 1, HitCham.cap)
    while #HitCham.list >= cap do Tracers.dropFx(table.remove(HitCham.list, 1)) end
    HitCham.list[#HitCham.list + 1] = rec
end

function HitCham.step(now)
    if #HitCham.list == 0 then return end
    if not flag("hit_cham_on", false) then return HitCham.clear() end
    for index = #HitCham.list, 1, -1 do
        local rec = HitCham.list[index]
        local age = now - rec.born
        if age >= rec.span then
            Tracers.dropFx(rec)
            table.remove(HitCham.list, index)
        else
            if rec.follow then HitCham.follow(rec) end
            HitCham.paint(rec, HitCham.curve(rec.fade, math.clamp(age / rec.life, 0, 1)))
            Impacts.run(rec, age)
        end
    end
end

function HitCham.clear()
    for _, rec in ipairs(HitCham.list) do Tracers.dropFx(rec) end
    HitCham.list = {}
end

Util.onUnload(HitCham.clear)

local HitFx = {
    list = {}, cap = 16, build = {},
    names = { "Sparks", "Shards", "Glow burst", "Electric", "Hearts", "Smoke", "Blood mist", "Crit star", "Shockring", "Pixel burst", "Feathers", "Confetti pop", "Damage flash", "Spark fountain" },
    legacy = { "Sparks", "Shards", "Glow burst", "Electric", "Hearts", "Smoke" },
}

function HitFx.emit(rec, ctx, count, props)
    local life = props.Lifetime
    if life then props.Lifetime = NumberRange.new(life.Min * ctx.time, life.Max * ctx.time) end
    local emitter = Tracers.emitter(rec, rec.holder, props)
    Tracers.burst(emitter, count * ctx.amount)
    return emitter
end

function HitFx.repeats(rec, ctx, emitter, count, times, every)
    local fired = 1
    rec.ticks[#rec.ticks + 1] = function(age)
        while fired < times and age >= fired * every do
            fired = fired + 1
            Tracers.burst(emitter, count * ctx.amount)
        end
        return fired >= times
    end
end

HitFx.build.Sparks = function(rec, ctx)
    local s = ctx.size
    HitFx.emit(rec, ctx, 18, {
        Orientation = Enum.ParticleOrientation.VelocityParallel, Lifetime = NumberRange.new(0.2, 0.5), Speed = NumberRange.new(8 * s, 18 * s), Drag = 2,
        Acceleration = Vector3.new(0, -40, 0), Size = Tracers.curve(0, 0.15 * s, 1, 0), Color = ColorSequence.new(WHITE, ctx.color),
    })
    return 0.6
end

HitFx.build.Shards = function(rec, ctx)
    local s = ctx.size
    HitFx.emit(rec, ctx, 10, {
        Texture = Impacts.shard, Lifetime = NumberRange.new(0.4, 0.8), Speed = NumberRange.new(5 * s, 12 * s), Acceleration = Vector3.new(0, -40, 0),
        RotSpeed = NumberRange.new(-300, 300), Size = Tracers.curve(0, 0.3 * s, 1, 0.1 * s), Color = ColorSequence.new(Util.lerpColor(ctx.color, WHITE, 0.4), ctx.color),
    })
    return 0.9
end

HitFx.build["Glow burst"] = function(rec, ctx)
    local s = ctx.size
    HitFx.emit(rec, ctx, 2, {
        Texture = Impacts.flare, Lifetime = NumberRange.new(0.2, 0.35), Speed = NumberRange.new(0, 0),
        Size = Tracers.curve(0, 0.5 * s, 0.3, 3 * s, 1, 0), Transparency = Tracers.curve(0, math.max(0.2, ctx.alpha), 1, 1), Color = ColorSequence.new(WHITE, ctx.color),
    })
    return 0.4
end

HitFx.build.Electric = function(rec, ctx)
    local s = ctx.size
    local emitter = HitFx.emit(rec, ctx, 3, {
        Texture = Impacts.bolt, Lifetime = NumberRange.new(0.08, 0.18), Speed = NumberRange.new(0, 0), Size = Tracers.curve(0, 1.2 * s, 1, 0.6 * s),
        Color = ColorSequence.new(WHITE, ctx.color),
    })
    HitFx.repeats(rec, ctx, emitter, 3, 5, 0.06)
    return 0.5
end

HitFx.build.Hearts = function(rec, ctx)
    local s = ctx.size
    HitFx.emit(rec, ctx, 6, {
        Texture = Impacts.heart, Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(2 * s, 4 * s), Drag = 1, Acceleration = Vector3.new(0, 3, 0),
        Rotation = NumberRange.new(-20, 20), Size = Tracers.curve(0, 0.35 * s, 0.5, 0.5 * s, 1, 0), Color = ColorSequence.new(Util.lerpColor(ctx.color, Color3.fromRGB(255, 90, 150), 0.5)),
    })
    return 1.5
end

HitFx.build.Smoke = function(rec, ctx)
    local s = ctx.size
    HitFx.emit(rec, ctx, 5, {
        Texture = SMOKE, LightEmission = 0.1, LightInfluence = 0.8, Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(1 * s, 2.5 * s), Drag = 1,
        RotSpeed = NumberRange.new(-30, 30), Size = Tracers.curve(0, 0.6 * s, 1, 2.2 * s), Transparency = Tracers.curve(0, math.max(0.4, ctx.alpha), 1, 1),
        Color = ColorSequence.new(Util.lerpColor(ctx.color, WHITE, 0.6)),
    })
    return 1.5
end

HitFx.build["Blood mist"] = function(rec, ctx)
    local s = ctx.size
    local blood = Util.lerpColor(Color3.fromRGB(170, 20, 30), ctx.color, 0.25)
    HitFx.emit(rec, ctx, 6, {
        Texture = SMOKE, LightEmission = 0, LightInfluence = 1, Lifetime = NumberRange.new(0.5, 0.9), Speed = NumberRange.new(1 * s, 3 * s), Drag = 3,
        RotSpeed = NumberRange.new(-40, 40), Size = Tracers.curve(0, 0.5 * s, 1, 2.4 * s), Transparency = Tracers.curve(0, math.max(0.35, ctx.alpha), 1, 1),
        Color = ColorSequence.new(blood, Util.lerpColor(blood, BLACK, 0.4)),
    })
    HitFx.emit(rec, ctx, 14, {
        LightEmission = 0, LightInfluence = 1, Lifetime = NumberRange.new(0.4, 0.8), Speed = NumberRange.new(4 * s, 9 * s), Drag = 1, Acceleration = Vector3.new(0, -45, 0),
        Size = Tracers.curve(0, 0.12 * s, 1, 0.06 * s), Color = ColorSequence.new(blood),
    })
    return 1
end

HitFx.build["Crit star"] = function(rec, ctx)
    local s = ctx.size
    local gold = Util.lerpColor(ctx.color, Color3.fromRGB(255, 215, 80), 0.5)
    for _, turn in ipairs({ 0, 45 }) do
        HitFx.emit(rec, ctx, 1, {
            Texture = Impacts.flare, Lifetime = NumberRange.new(0.3, 0.35), Speed = NumberRange.new(0, 0), Rotation = NumberRange.new(turn, turn), RotSpeed = NumberRange.new(180, 180),
            Size = Tracers.curve(0, 0.4 * s, 0.25, 3.2 * s, 1, 0), Transparency = Tracers.curve(0, math.max(0.05, ctx.alpha), 1, 1), Color = ColorSequence.new(WHITE, gold),
        })
    end
    HitFx.emit(rec, ctx, 8, {
        Orientation = Enum.ParticleOrientation.VelocityParallel, Lifetime = NumberRange.new(0.15, 0.3), Speed = NumberRange.new(14 * s, 22 * s), Drag = 5,
        Size = Tracers.curve(0, 0.22 * s, 1, 0), Color = ColorSequence.new(WHITE, gold),
    })
    return 0.5
end

HitFx.build.Shockring = function(rec, ctx)
    local s, a = ctx.size, ctx.alpha
    local facing = CFrame.new()
    local camera = ctx.camera and propGet(ctx.camera, "CFrame")
    if typeof(camera) == "CFrame" and (camera.Position - ctx.pos).Magnitude > 1e-3 then facing = CFrame.new(Vector3.zero, camera.Position - ctx.pos) end
    local rings = {}
    for index = 1, 2 do
        local ring = Impacts.adorn(rec, "CylinderHandleAdornment", {
            Radius = 0.1, Height = 0.04, Color3 = index == 1 and ctx.color or Util.lerpColor(ctx.color, WHITE, 0.5), Transparency = 1, CFrame = facing, AlwaysOnTop = true, ZIndex = 2,
        })
        propSet(ring, "InnerRadius", 0.08)
        rings[index] = ring
    end
    local span = 0.45 * ctx.time
    rec.ticks[#rec.ticks + 1] = function(age)
        for index, ring in ipairs(rings) do
            local k = math.clamp((age - (index - 1) * span * 0.3) / span, 0, 1)
            local radius = 0.1 + 2.2 * s * (1 - (1 - k) ^ 3)
            ring.Radius = radius
            propSet(ring, "InnerRadius", radius * 0.82)
            ring.Transparency = (k <= 0 or k >= 1) and 1 or a + (1 - a) * k
        end
        return age >= span * 1.3
    end
    HitFx.emit(rec, ctx, 1, { Texture = Impacts.ring, Lifetime = NumberRange.new(0.3, 0.4), Speed = NumberRange.new(0, 0), Size = Tracers.curve(0, 0.3 * s, 1, 3 * s), Transparency = Tracers.curve(0, 0.2, 1, 1), Color = ColorSequence.new(ctx.color) })
    return span * 1.3 + 0.1
end

HitFx.build["Pixel burst"] = function(rec, ctx)
    local s, a = ctx.size, ctx.alpha
    local pieces = {}
    for index = 1, 10 do
        local direction = Vector3.new(math.random() - 0.5, math.random() * 0.8 - 0.1, math.random() - 0.5)
        direction = direction.Magnitude > 1e-3 and direction.Unit or Vector3.new(0, 1, 0)
        local size = (0.1 + math.random() * 0.08) * s
        local shade = index % 2 == 0 and Util.lerpColor(ctx.color, WHITE, 0.45) or ctx.color
        pieces[index] = { object = Impacts.adorn(rec, "BoxHandleAdornment", { Size = Vector3.new(size, size, size), Color3 = shade, Transparency = a, AlwaysOnTop = true, ZIndex = 2 }), v = direction * ((6 + math.random() * 6) * s) }
    end
    local life = 0.7 * ctx.time
    rec.ticks[#rec.ticks + 1] = function(age)
        local k = math.clamp(age / life, 0, 1)
        for _, piece in ipairs(pieces) do
            local v = piece.v
            piece.object.CFrame = CFrame.new(v.X * age, v.Y * age - 14 * age * age, v.Z * age)
            piece.object.Transparency = a + (1 - a) * k * k
        end
        return k >= 1
    end
    return life
end

HitFx.build.Feathers = function(rec, ctx)
    local s = ctx.size
    HitFx.emit(rec, ctx, 8, {
        Texture = Impacts.shard, LightEmission = 0.2, LightInfluence = 0.8, Lifetime = NumberRange.new(1, 1.8), Speed = NumberRange.new(3 * s, 6 * s), Drag = 3,
        Acceleration = Vector3.new(0, -2, 0), RotSpeed = NumberRange.new(-120, 120), Size = Tracers.curve(0, 0.35 * s, 1, 0.25 * s), Transparency = Tracers.curve(0, ctx.alpha, 0.7, ctx.alpha, 1, 1),
        Color = ColorSequence.new(Util.lerpColor(ctx.color, WHITE, 0.75)),
    })
    return 1.8
end

HitFx.build["Confetti pop"] = function(rec, ctx)
    local s = ctx.size
    local hue = Color3.toHSV(ctx.color)
    for index = 0, 3 do
        HitFx.emit(rec, ctx, 7, {
            Texture = Impacts.shard, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(50, 50), Lifetime = NumberRange.new(0.8, 1.4),
            Speed = NumberRange.new(8 * s, 16 * s), Drag = 2, Acceleration = Vector3.new(0, -25, 0), RotSpeed = NumberRange.new(-400, 400),
            Size = Tracers.curve(0, 0.18 * s, 1, 0.14 * s), Color = ColorSequence.new(Color3.fromHSV((hue + index * 0.25) % 1, 0.75, 1)),
        })
    end
    return 1.4
end

HitFx.build["Damage flash"] = function(rec, ctx)
    local flashes = {}
    for _, name in ipairs(CHAM_PARTS) do
        local part = ctx.hash[name]
        local frame = part and HitCham.frameOf(part)
        if frame then
            local size = HitCham.sizeOf(part, name)
            local holder = Tracers.make(rec, "Part", Tracers.solid(frame, size))
            local box = Impacts.adorn(rec, "BoxHandleAdornment", { Adornee = holder, Size = size + Vector3.new(0.05, 0.05, 0.05), Color3 = WHITE, Transparency = 0.1, AlwaysOnTop = true, ZIndex = 4 }, holder)
            flashes[#flashes + 1] = { part = part, holder = holder, box = box }
        end
    end
    local life = 0.25 * ctx.time
    rec.ticks[#rec.ticks + 1] = function(age)
        local k = math.clamp(age / life, 0, 1)
        for _, flash in ipairs(flashes) do
            local frame = HitCham.frameOf(flash.part)
            if frame then flash.holder.CFrame = frame end
            flash.box.Transparency = 0.1 + 0.9 * k
        end
        return k >= 1
    end
    return life
end

HitFx.build["Spark fountain"] = function(rec, ctx)
    local s = ctx.size
    local emitter = HitFx.emit(rec, ctx, 6, {
        Orientation = Enum.ParticleOrientation.VelocityParallel, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(18, 18),
        Lifetime = NumberRange.new(0.4, 0.8), Speed = NumberRange.new(14 * s, 22 * s), Acceleration = Vector3.new(0, -50, 0),
        Size = Tracers.curve(0, 0.14 * s, 1, 0), Color = ColorSequence.new(WHITE, ctx.color),
    })
    HitFx.repeats(rec, ctx, emitter, 6, 8, 0.05)
    return 1.2
end

function HitFx.onHit(player, position, partName)
    if player == nil or player == LocalPlayer or not flag("hit_fx_on", false) then return end
    local head = partName == "Head"
    if flag("hit_fx_head", false) and not head then return end
    local chosen, names = Util.set("hit_fx_list", { "Sparks", "Glow burst" }), {}
    for _, name in ipairs(HitFx.names) do
        if chosen[name] then names[#names + 1] = name end
    end
    if #names == 0 then return end
    local hash = HitCham.victim(player)
    local camera = propGet(Workspace, "CurrentCamera")
    if not (hash and camera) then return end
    local hitName = type(partName) == "string" and hash[partName] and partName or "Torso"
    local centre = flag("hit_fx_at", "Hit point") == "Body centre"
    local anchor = centre and (hash.Torso or hash[hitName]) or hash[hitName]
    local frame = anchor and HitCham.frameOf(anchor)
    local spot = (not centre and typeof(position) == "Vector3") and position or (frame and frame.Position)
    if not spot then return end
    local ctx = {
        color = flag("hit_fx_color", Color3.fromRGB(255, 120, 80)), alpha = Util.alpha("hit_fx_color", 0), size = math.clamp(flag("hit_fx_size", 1), 0.25, 3),
        amount = math.clamp(flag("hit_fx_amount", 1), 0.25, 3), time = math.clamp(flag("hit_fx_time", 1), 0.3, 2.5), hash = hash, camera = camera, pos = spot, head = head,
    }
    local now = os.clock()
    local cap = math.clamp(math.floor(flag("hit_fx_max", 12)), 1, HitFx.cap)
    while #HitFx.list > cap do Tracers.dropFx(table.remove(HitFx.list, 1)) end
    if #HitFx.list == cap and not Tracers.settled(HitFx.list[1], now) then return end
    local rec = { objects = {}, ticks = {}, emitters = 0, bright = 1, born = now, life = 0, sizeScale = Tracers.distScale(spot) }
    local ok = Util.guard("hit fx", function()
        rec.holder = Tracers.make(rec, "Part", Tracers.solid(CFrame.new(spot)), camera)
        for _, name in ipairs(names) do
            rec.life = math.max(rec.life, (HitFx.build[name](rec, ctx) or 1) * ctx.time)
        end
    end)
    if not ok then
        Tracers.dropFx(rec)
        return
    end
    while #HitFx.list >= cap do Tracers.dropFx(table.remove(HitFx.list, 1)) end
    HitFx.list[#HitFx.list + 1] = rec
end

function HitFx.migrate()
    HitFx.pending = false
    local old = Util.set("hit_cham_fx", {})
    if next(old) == nil then return end
    if not flag("hit_fx_on", false) and Options.hit_fx_list and Toggles.hit_fx_on then
        local list = {}
        for _, name in ipairs(HitFx.legacy) do
            if old[name] then list[name] = true end
        end
        Options.hit_fx_list:SetValue(list)
        if Options.hit_fx_amount then Options.hit_fx_amount:SetValue(math.clamp(flag("hit_cham_fx_amount", 1), 0.25, 3)) end
        if Options.hit_fx_color then pcall(Options.hit_fx_color.SetValueRGB, Options.hit_fx_color, flag("hit_cham_color", Color3.fromRGB(255, 70, 110)), 0) end
        Toggles.hit_fx_on:SetValue(flag("hit_cham_on", false))
    end
    Options.hit_cham_fx:SetValue({})
end

function HitFx.step(now)
    if HitFx.pending then HitFx.migrate() end
    if #HitFx.list == 0 then return end
    if not flag("hit_fx_on", false) then return HitFx.clear() end
    for index = #HitFx.list, 1, -1 do
        local rec = HitFx.list[index]
        local age = now - rec.born
        if age >= rec.life and Tracers.settled(rec, now) then
            Tracers.dropFx(rec)
            table.remove(HitFx.list, index)
        else
            Impacts.run(rec, age)
        end
    end
end

function HitFx.clear()
    for _, rec in ipairs(HitFx.list) do Tracers.dropFx(rec) end
    HitFx.list = {}
end

Util.onUnload(HitFx.clear)

function Game.onBulletHit(player, position, partName)
    Feedback.noteHit(position, os.clock())
    if flag("hit_cham_on", false) or flag("hit_fx_on", false) then Feedback.deferHit(Game.buildHit, player, position, partName) end
end

function Game.buildHit(player, position, partName)
    Util.guard("hit chams", HitCham.onHit, player, position, partName)
    Util.guard("hit fx", HitFx.onHit, player, position, partName)
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
                            list[#list + 1] = { pos = position, screen = screen, group = group, part = part, index = index, key = screen + penalty + index * 0.001 }
                        end
                    end
                end
            end
        end
    end
    return list
end

local function byKey(a, b) return a.key < b.key end

function Aim.cell(v)
    return string.format("%d,%d,%d", math.floor(v.X * 10 + 0.5), math.floor(v.Y * 10 + 0.5), math.floor(v.Z * 10 + 0.5))
end

function Aim.trace(record, cand, eye, origin, depth)
    local memo = record.aimVis
    if not memo or memo.frame ~= Game.frame then
        memo = { frame = Game.frame }
        record.aimVis = memo
    end
    local key = Aim.cell(cand.pos) .. "|" .. Aim.cell(eye)
    if depth then key = key .. "|" .. Aim.cell(origin) .. "|" .. depth end
    local entry = memo[key]
    if entry then return true, entry.thickness, entry.walls end
    if Visible.budget <= 0 then return false end
    Visible.budget = Visible.budget - 1
    local thickness, walls = Visible.trace(eye, cand.pos)
    if not thickness and depth then
        thickness, walls = Visible.trace(origin, cand.pos, depth)
        if thickness then walls = math.max(walls, 1) end
    end
    memo[key] = { thickness = thickness, walls = walls }
    return true, thickness, walls
end

function Aim.remember(record, cand)
    local last = record.aimLast or {}
    record.aimLast = last
    last.at, last.part, last.mode, last.thickness = os.clock(), cand and cand.part, cand and cand.mode, cand and cand.thickness
    return cand
end

function Aim.recall(record, list)
    local last = record.aimLast
    if not (last and last.mode and os.clock() - last.at <= 0.1) then return nil end
    for _, cand in ipairs(list) do
        if cand.part == last.part then
            cand.mode, cand.thickness = last.mode, last.thickness
            return cand
        end
    end
    return nil
end

function Aim.select(record, cam, origin, center, radius, opts)
    local list = Aim.gather(record, cam, center, radius, opts)
    if not list or #list == 0 then return nil end
    table.sort(list, byKey)
    if not opts.visible then
        list[1].mode = "open"
        return list[1]
    end
    local eye = opts.eye or origin
    local fallback
    for _, cand in ipairs(list) do
        local known, thickness, walls = Aim.trace(record, cand, eye, origin, opts.depth)
        if not known then return fallback or Aim.recall(record, list) end
        if thickness then
            cand.thickness = thickness
            if walls == 0 then
                cand.mode = "visible"
                return Aim.remember(record, cand)
            end
            if not fallback then
                cand.mode = "pen"
                fallback = cand
            end
        end
    end
    return Aim.remember(record, fallback)
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
    opts.eye = Game.eye(cam).Position
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
    return L.silentFovBarrel and Barrel.center(L.silentFovAttach, screen) or screen
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
    L.predAlpha, L.predOutlineColor, L.predOutlineAlpha = Util.opacity("legit_pred_color"), flag("legit_pred_outline_color", BLACK), Util.opacity("legit_pred_outline_color")
    L.predSize, L.predDrop = flag("legit_pred_size", 6), flag("legit_pred_drop", true)
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

Legit.order = {}

function Legit.nearer(a, b) return a.aimScreen < b.aimScreen end

function Legit.choose(records, cam, origin, center, now)
    local L = Legit.L
    local order = Legit.order
    for index = #order, 1, -1 do order[index] = nil end
    for _, record in ipairs(records) do
        if record.rendered and (record.enemy or not L.teamCheck) then
            local distance = (record.torso.Position - origin).Magnitude
            if distance <= L.maxdist then
                local point, front = Draw.project(cam, record.torso.Position)
                record.aimDist, record.aimScreen = distance, front and (point - center).Magnitude or math.huge
                order[#order + 1] = record
            end
        end
    end
    table.sort(order, Legit.nearer)
    local bestRecord, bestCand, bestScore
    for _, record in ipairs(order) do
        local cand = Aim.select(record, cam, origin, center, Legit.radius, Aim.opts)
        if cand then
            local score = cand.screen
            if L.targetBy == "Distance" then score = record.aimDist
            elseif L.targetBy == "Lowest health" then score = record.health * 1000 + cand.screen end
            if not bestScore or score < bestScore then bestRecord, bestCand, bestScore = record, cand, score end
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
    }
    Legit.slots[index] = slot
    return slot
end

function Legit.hideSlot(slot)
    slot.outline.Visible, slot.dot.Visible = false, false
end

function Legit.drawSlot(slot, cam, record, cand, speed, weapon)
    local L = Legit.L
    local hit, aim = Aim.intercept(Legit.origin, cand.pos, Aim.velocity(record), speed, weapon)
    local point, front = Draw.project(cam, L.predDrop and aim or hit)
    if not front then
        Legit.hideSlot(slot)
        return
    end
    local size = L.predSize
    local outline = slot.outline
    outline.Position, outline.Radius, outline.Visible = point, size + 1.5, L.predOutline
    outline.Color, outline.Transparency = L.predOutlineColor, L.predOutlineAlpha * L.predAlpha
    slot.dot.Position, slot.dot.Radius, slot.dot.Color, slot.dot.Transparency, slot.dot.Visible = point, size, L.predColor, L.predAlpha, true
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

function Legit.runAim(dt, cam, now, records, center, weapon, origin, barrelLook)
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
            Legit.snapShown = true
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
    Legit.moved = Legit.turn(gameCam, origin, aimPoint, dt, now, cam, barrelLook, snap)
end

function Legit.onPress()
    if Util.menuOpen() or Util.typing() then return end
    local L, last = Legit.L, Legit.last
    Legit.pressAt, Legit.snapDone = os.clock(), false
    if not (L.semi and L.onfire and last.cam) then return end
    Legit.target = nil
    Legit.runAim(0, last.cam, Legit.pressAt, last.records, last.center, last.weapon, last.origin, last.barrelLook)
    if Legit.snapShown then Legit.snapline.Visible = true end
end

Util.track(UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then Util.guard("snap", Legit.onPress) end
end))

function Legit.stepAim(dt, cam, now, records, screen)
    local L = Legit.L
    Legit.moved, Legit.cand = false, nil
    local center = L.fovBarrel and Barrel.center(L.fovAttach, screen) or screen
    local weapon = Game.weapon()
    Legit.stepRadius(dt, weapon, cam)
    Legit.drawFov(center)
    Legit.snapShown = false
    Silent.step(dt, cam, weapon, screen)
    Aim.opts.depth = L.wallbang and weapon and Aim.depth(weapon, L.safety) or nil
    local eye = Game.eye(cam)
    local origin, barrelLook = eye.Position, nil
    Aim.opts.eye = eye.Position
    if L.barrel then
        local gameCam = Game.gameCamera()
        local camLook = gameCam and gameCam:getLookVector()
        if typeof(camLook) ~= "Vector3" then camLook = eye.LookVector end
        origin, barrelLook = Barrel.mix(eye.Position, camLook)
    end
    Legit.origin = origin
    local last = Legit.last
    last.cam, last.records, last.center, last.weapon, last.origin, last.barrelLook = cam, records, center, weapon, origin, barrelLook
    local ok, problem = pcall(Legit.runAim, dt, cam, now, records, center, weapon, origin, barrelLook)
    Legit.snapline.Visible = ok and Legit.snapShown
    if not ok then error(problem, 0) end
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
                        and (not wantVisible or Visible.check(part, eye.Position, now)) then
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

function Game.camoDatabase()
    if Game.camoDb then return Game.camoDb end
    local ok, database = pcall(function()
        local storage = game:GetService("ReplicatedStorage")
        local content = storage:FindFirstChild("Content")
        local production = content and content:FindFirstChild("ProductionContent")
        local module = production and production:FindFirstChild("CamoDatabase")
        return module and require(module)
    end)
    if ok and type(database) == "table" and next(database) ~= nil then Game.camoDb = database end
    return Game.camoDb
end

function Game.contentFolders(name)
    local found = {}
    pcall(function()
        local root = game:GetService("ReplicatedStorage"):FindFirstChild("Content")
        for _, folder in ipairs({ "ProductionContent", "TestContent" }) do
            local holder = root and root:FindFirstChild(folder)
            local database = holder and holder:FindFirstChild(name)
            if database then found[#found + 1] = database end
        end
    end)
    return found
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
    local database = Game.camoDatabase()
    if database then
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
    local own = Knife.override and Knife.override(name, knife.Camo)
    if own then
        knife.Camo = own
    elseif skin ~= "Default" then
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

function Local.isAperture(object)
    local name = propGet(object, "Name")
    if type(name) == "string" and string.sub(name, 1, 12) == "BlurAperture" then return true end
    local ok, inner, outer = pcall(function() return object:FindFirstChild("I1"), object:FindFirstChild("O1") end)
    if not (ok and inner and outer) then return false end
    local okBone, bone = pcall(function() return inner:IsA("Bone") end)
    return okBone and bone == true
end

function Local.apertures(weapon)
    local list = {}
    local components = weapon._activeComponents
    if type(components) ~= "table" then return list end
    for _, component in pairs(components) do
        local lens = type(component) == "table" and component._aperturelens
        local model = type(lens) == "table" and lens.model
        if model then list[#list + 1] = model end
    end
    return list
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
            elseif item.cat == "gun" and class == "mesh" and Local.isAperture(object) then
                item.aperture = true
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

function Local.applyItem(item, spec, hide, noglass, glassOff, interiorOff)
    if (item.glass or item.aperture) and not hide then
        local off
        if item.aperture then off = interiorOff else off = glassOff or (spec and noglass) end
        if not off then
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
    return ChamStyle.viewSpec({
        color = color, alpha = Util.alpha(base .. "_color", 0), material = material, texture = texture,
        refl = val(base .. "_refl") or 0, vertex = Vector3.new(color.R, color.G, color.B),
    })
end

function Local.settings()
    local state = { specs = {}, any = false, rm = {
        armLeft = on("local_rm_larm") == true, armRight = on("local_rm_rarm") == true,
        clothLeft = on("local_rm_lsleeve") == true, clothRight = on("local_rm_rsleeve") == true,
        glove = on("local_rm_gloves") == true, gun = on("local_rm_gun") == true,
    } }
    state.noglass = on("local_gun_noglass") == true
    state.glassOff = on("local_noglass") == true
    state.interiorOff = on("local_noaperture") == true
    if state.glassOff or state.interiorOff then state.any = true end
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
        Local.applyItem(item, state.specs[cat], hide, state.noglass, state.glassOff, state.interiorOff)
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
    local root = character:getRootPart().CFrame
    local relative = root:Inverse() * Stretch.cf(cam)
    local axes = CFrame.new(relative.Position):Inverse() * relative
    local spin = axes * CFrame.Angles(math.rad(pitch) * scale, math.rad(yaw) * scale, math.rad(roll) * scale) * axes:Inverse()
    local pivot = CFrame.new(base.Position)
    local shift = CFrame.new(axes * Vector3.new(x * scale, y * scale, -z * scale))
    local change = shift * pivot * spin * pivot:Inverse()
    main.C0 = change * base
    local apertures = Local.apertures(weapon)
    if #apertures > 0 then
        local carry = root * change * root:Inverse()
        for _, aperture in ipairs(apertures) do
            local at = propGet(aperture, "CFrame")
            if typeof(at) == "CFrame" then propSet(aperture, "CFrame", carry * at) end
        end
    end
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

local Skins = {
    store = { weapons = {}, presets = {} }, file = "Aster/PhantomForces/skins.json", slots = { "Slot1", "Slot2" },
    list = {}, classOf = {}, slot = "Slot1", syncing = false, dirty = false, keepView = false, buildAt = 0, hintAt = -math.huge, ready = false, sigs = {},
    retryFirst = 3, retryCap = 30, retryMax = 6,
    emptyText = "Pick a weapon", presetModes = { "Selected weapon", "All owned weapons", "All" },
}

Skins.classes = { "ASSAULT RIFLE", "BATTLE RIFLE", "CARBINE", "DMR", "LMG", "PDW", "SHOTGUN", "SNIPER RIFLE", "PISTOLS", "REVOLVERS", "MACHINE PISTOLS", "OTHER",
    "ONE HAND BLADE", "ONE HAND BLUNT", "TWO HAND BLADE", "TWO HAND BLUNT" }

Skins.ranges = {
    TextureProperties = { Transparency = { 0, 1 }, Emissivity = { 0, 100 }, Rotation = { 0, 360 }, StudsPerTileU = { 0.1, 10 }, StudsPerTileV = { 0.1, 10 }, OffsetStudsU = { 0, 30 }, OffsetStudsV = { 0, 30 } },
    BrickProperties = { Reflectance = { 0, 1 } },
}

Skins.rarity = {
    [0] = { "Default", Color3.fromRGB(85, 85, 85) }, { "Common", Color3.fromRGB(25, 50, 100) }, { "Uncommon", Color3.fromRGB(75, 50, 100) },
    { "Rare", Color3.fromRGB(150, 50, 150) }, { "Very Rare", Color3.fromRGB(150, 25, 25) }, { "Legendary", Color3.fromRGB(200, 150, 25) },
}

Skins.sliders = {
    { flag = "skin_emissivity", group = "TextureProperties", key = "Emissivity", name = "Emissivity", default = 1, decimals = 0.1, tip = "Multiplies the texture colour; above 1 makes it glow" },
    { flag = "skin_rotation", group = "TextureProperties", key = "Rotation", name = "Rotation", default = 0, decimals = 1, suffix = " deg" },
    { flag = "skin_studs_u", group = "TextureProperties", key = "StudsPerTileU", name = "Studs per tile U", default = 1, decimals = 0.01 },
    { flag = "skin_studs_v", group = "TextureProperties", key = "StudsPerTileV", name = "Studs per tile V", default = 1, decimals = 0.01 },
    { flag = "skin_offset_u", group = "TextureProperties", key = "OffsetStudsU", name = "Offset U", default = 0, decimals = 0.01 },
    { flag = "skin_offset_v", group = "TextureProperties", key = "OffsetStudsV", name = "Offset V", default = 0, decimals = 0.01 },
    { flag = "skin_reflectance", group = "BrickProperties", key = "Reflectance", name = "Reflectance", default = 0, decimals = 0.01 },
}

Skins.community = {
    { "Easy Neon Snowflakes", { Name = "Snowflakes*", BrickProperties = { Material = "Neon", Color = { 0, 170, 255 } } } },
    { "Colour-changing (Japan*)", { Name = "Waves 1*", TextureProperties = { Transparency = 0.2 }, BrickProperties = { Material = "Neon", Color = { 255, 0, 0 } } },
        { Name = "Waves 1*", TextureProperties = { Transparency = 0.2 }, BrickProperties = { Material = "Neon", Color = { 0, 255, 255 } } } },
    { "Groza Labyrinth 1.25", { Name = "Labyrinth", TextureProperties = { StudsPerTileU = 1.25, StudsPerTileV = 1.25 } } },
    { "Forcefield minimal tile", { Name = "Gold*", TextureProperties = { Color = { 0, 255, 255 }, StudsPerTileU = 0.1, StudsPerTileV = 0.1, Transparency = 1 }, BrickProperties = { Material = "ForceField", Color = { 0, 255, 255 } } } },
    { "Translucent forcefield 0.8", { Name = "Gold*", TextureProperties = { Transparency = 0.8 }, BrickProperties = { Material = "ForceField", Color = { 255, 255, 255 } } } },
    { "Glowing neon", { Name = "Gold*", TextureProperties = { Transparency = 1 }, BrickProperties = { Material = "Neon", Color = { 255, 0, 191 } } } },
    { "Forcefield black/green", { Name = "Gold*", BrickProperties = { Material = "ForceField", Color = { 0, 0, 0 } } }, { Name = "Gold*", BrickProperties = { Material = "ForceField", Color = { 0, 255, 0 } } } },
    { "Forcefield black/red", { Name = "Gold*", BrickProperties = { Material = "ForceField", Color = { 0, 0, 0 } } }, { Name = "Gold*", BrickProperties = { Material = "ForceField", Color = { 255, 0, 0 } } } },
    { "Sniper pink/toothpaste", { Name = "Gold*", BrickProperties = { Material = "ForceField", Color = { 255, 102, 204 } } }, { Name = "Gold*", BrickProperties = { Material = "ForceField", Color = { 0, 255, 255 } } } },
    { "Black and purple", { Name = "Gold*", BrickProperties = { Material = "SmoothPlastic", Color = { 17, 17, 17 } } }, { Name = "Gold*", BrickProperties = { Material = "Neon", Color = { 98, 37, 209 } } } },
    { "Dimensionless tint", { Name = "Dimensionless*", TextureProperties = { Color = { 255, 80, 80 } } } },
    { "Black glass", { Name = "Gold*", TextureProperties = { Transparency = 1 }, BrickProperties = { Material = "Glass", Color = { 0, 0, 0 } } } },
    { "Reflective chrome", { Name = "Gold*", BrickProperties = { Material = "SmoothPlastic", Color = { 200, 200, 200 }, Reflectance = 0.6 } },
        { Name = "Gold*", BrickProperties = { Material = "SmoothPlastic", Color = { 60, 60, 60 }, Reflectance = 0.6 } } },
}

function Skins.copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for key, item in pairs(value) do out[key] = Skins.copy(item) end
    return out
end

function Skins.dataset(name)
    if type(name) ~= "string" or name == "" then return nil end
    local sets = Game.mods.SkinCaseUtils
    if sets and type(sets.getSkinDataset) == "function" then
        local ok, data = pcall(sets.getSkinDataset, name)
        return ok and type(data) == "table" and data or nil
    end
    local database = Game.camoDatabase()
    local data = database and database[name]
    return type(data) == "table" and data or nil
end

function Skins.toRGB(color)
    if typeof(color) == "Color3" then
        return { math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5) }
    end
    if type(color) ~= "table" then return nil end
    local r, g, b = tonumber(color[1] or color.r or color.R), tonumber(color[2] or color.g or color.G), tonumber(color[3] or color.b or color.B)
    if not (r and g and b) then return nil end
    local function byte(value) return math.clamp(math.floor(value + 0.5), 0, 255) end
    return { byte(r), byte(g), byte(b) }
end

function Skins.toColor3(rgb)
    return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

function Skins.materials()
    if Skins.materialList then return Skins.materialList end
    local list = {}
    pcall(function()
        for _, item in ipairs(Enum.Material:GetEnumItems()) do
            if item.Name ~= "Air" and item.Name ~= "Water" then list[#list + 1] = item.Name end
        end
    end)
    if #list == 0 then
        for index, name in ipairs(Local.materials) do list[index] = name end
    end
    table.sort(list)
    Skins.materialList, Skins.materialSet = list, Util.toSet(list)
    return list
end

function Skins.materialName(value)
    if typeof(value) == "EnumItem" then value = value.Name end
    if type(value) ~= "string" then return nil end
    Skins.materials()
    return Skins.materialSet[value] and value or nil
end

function Skins.cleanSlot(raw)
    if type(raw) ~= "table" or type(raw.Name) ~= "string" or raw.Name == "" then return nil end
    local slot = { Name = raw.Name }
    for group, ranges in pairs(Skins.ranges) do
        local source, out = raw[group], {}
        if type(source) == "table" then
            for key, range in pairs(ranges) do
                local value = tonumber(source[key])
                if value and value == value then out[key] = math.clamp(value, range[1], range[2]) end
            end
            out.Color = Skins.toRGB(source.Color)
            if group == "BrickProperties" then out.Material = Skins.materialName(source.Material) end
        end
        if next(out) ~= nil then slot[group] = out end
    end
    return slot
end

function Skins.cleanCamo(raw)
    if type(raw) ~= "table" then return nil end
    local camo, any = {}, false
    for _, tag in ipairs(Skins.slots) do
        local slot = Skins.cleanSlot(raw[tag])
        if slot then camo[tag], any = slot, true end
    end
    return any and camo or nil
end

function Skins.cleanEntries(map)
    local out = {}
    if type(map) ~= "table" then return out end
    for name, camo in pairs(map) do
        if type(name) == "string" then out[name] = Skins.cleanCamo(camo) end
    end
    return out
end

function Skins.toCamoSlot(slot)
    if type(slot) ~= "table" or not Skins.dataset(slot.Name) then return nil end
    local out = { Name = slot.Name }
    for group in pairs(Skins.ranges) do
        local source = slot[group]
        if type(source) == "table" then
            local copy = {}
            for key, value in pairs(source) do copy[key] = value end
            if type(source.Color) == "table" then copy.Color = Skins.toColor3(source.Color) end
            out[group] = copy
        end
    end
    return out
end

function Skins.merge(name, camo)
    local entry = type(name) == "string" and Skins.store.weapons[name]
    if type(entry) ~= "table" then return nil end
    local merged, changed = {}, false
    if type(camo) == "table" then
        for tag, slot in pairs(camo) do merged[tag] = slot end
    end
    for _, tag in ipairs(Skins.slots) do
        local slot = Skins.toCamoSlot(entry[tag])
        if slot then merged[tag], changed = slot, true end
    end
    return changed and merged or nil
end

function Skins.camoFor(name, camo)
    if not flag("skin_on", true) then return nil end
    return Skins.merge(name, camo)
end

Knife.override = Skins.camoFor

function Skins.playerData()
    local data = Game.mods.PlayerDataClientInterface
    if not (data and type(data.getPlayerData) == "function") then return nil end
    local ok, pd = pcall(data.getPlayerData)
    return ok and type(pd) == "table" and pd or nil
end

function Skins.loadout(pd)
    local utils = Game.mods.ActiveLoadoutUtils
    if not (pd and utils and type(utils.getActiveLoadoutData) == "function") then return nil end
    local ok, loadout = pcall(utils.getActiveLoadoutData, pd)
    return ok and type(loadout) == "table" and loadout or nil
end

function Skins.owns(pd, name, equipped, owns)
    if equipped[name] then return true end
    if Knife.isKnife(name) then
        if flag("misc_knife_unlock", false) then return true end
        if flag("misc_knife_on", false) and flag("misc_knife", "Default") == name then return true end
    end
    if not owns then return false end
    local ok, owned = pcall(owns, pd, name)
    return ok and owned == true
end

function Skins.scan()
    local content = Game.mods.ContentInterface
    if not (content and type(content.getWeaponListFromClass) == "function") then return false end
    local pd = Skins.playerData()
    local utils = Game.mods.PlayerDataUtils
    local owns = Knife.realOwns or (utils and utils.ownsWeapon)
    if not (pd and type(owns) == "function") then owns = nil end
    local equipped = {}
    for _, slot in pairs(Skins.loadout(pd) or {}) do
        if type(slot) == "table" and type(slot.Name) == "string" then equipped[slot.Name] = true end
    end
    local list, classOf = {}, {}
    for _, class in ipairs(Skins.classes) do
        local ok, names = pcall(content.getWeaponListFromClass, class)
        if ok and type(names) == "table" then
            for _, name in ipairs(names) do
                if type(name) == "string" and not classOf[name] and Skins.owns(pd, name, equipped, owns) then
                    classOf[name] = class
                    list[#list + 1] = name
                end
            end
        end
    end
    table.sort(list)
    Skins.list, Skins.classOf, Skins.ready = list, classOf, owns ~= nil
    return Skins.ready
end

function Skins.filtered()
    local class = flag("skin_class", "All")
    local query = string.lower(tostring(flag("skin_search", "") or ""))
    local out = {}
    for _, name in ipairs(Skins.list) do
        local inClass = class == "All" or Skins.classOf[name] == class or (class == "Skinned" and Skins.store.weapons[name] ~= nil)
        if inClass and (query == "" or string.find(string.lower(name), query, 1, true)) then out[#out + 1] = name end
    end
    return out
end

function Skins.setValues(option, list)
    local sig = table.concat(list, "\0")
    if Skins.sigs[option] == sig then return false end
    Skins.sigs[option] = sig
    pcall(option.SetValues, option, list)
    return true
end

function Skins.weaponItems()
    local items = Skins.filtered()
    if #items == 0 then items[1] = Skins.ready and "None" or "Loading..." end
    return items
end

function Skins.syncWeapons()
    Skins.scan()
    local option = Options.skin_weapon
    if not (option and type(option.SetValues) == "function") then return end
    local items = Skins.weaponItems()
    Skins.setValues(option, items)
    local pick = Skins.classOf[option.Value] and option.Value or (Skins.classOf[items[1]] and items[1]) or nil
    if pick and pick ~= option.Value then pcall(option.SetValue, option, pick) end
    if pick and pick ~= Skins.selected then Skins.select(pick) end
    Skins.syncPresets()
end

function Skins.follow()
    local option = Options.skin_weapon
    local value = option and option.Value
    if type(value) == "string" and value ~= Skins.selected and Skins.classOf[value] then Skins.select(value) end
end

function Skins.show(name)
    local option = Options.skin_weapon
    if option and not table.find(option.Values or {}, name) then
        if Options.skin_class then pcall(Options.skin_class.SetValue, Options.skin_class, "All") end
        if Options.skin_search then pcall(Options.skin_search.SetValue, Options.skin_search, "") end
        Skins.syncWeapons()
    end
    if option then pcall(option.SetValue, option, name) end
    if Skins.selected ~= name then Skins.select(name) end
end

function Skins.image(id)
    if id == nil or id == "" then return nil end
    id = tostring(id)
    if id:match("^%d+$") then return "rbxassetid://" .. id end
    return id
end

function Skins.galleryItems()
    local database = Game.camoDatabase()
    if not database then return {} end
    local byCase, order = {}, {}
    for name in pairs(database) do
        local data = type(name) == "string" and Skins.dataset(name)
        if data then
            local case = type(data.Case) == "string" and data.Case or "Other"
            if not byCase[case] then
                byCase[case] = {}
                order[#order + 1] = case
            end
            local rarity = Skins.rarity[tonumber(data.Rarity) or 0] or Skins.rarity[0]
            table.insert(byCase[case], {
                Id = name, Name = type(data.DisplayName) == "string" and data.DisplayName or name, Image = Skins.image(data.TextureId),
                Color = rarity[2], Subtitle = rarity[1] .. " / " .. case, rank = tonumber(data.Rarity) or 0,
            })
        end
    end
    table.sort(order)
    local sets, items = Game.mods.SkinCaseUtils, {}
    for _, case in ipairs(order) do
        local skins = byCase[case]
        table.sort(skins, function(a, b)
            if a.rank ~= b.rank then return a.rank > b.rank end
            return a.Name < b.Name
        end)
        local info
        if sets and type(sets.getCaseDataset) == "function" then
            local ok, data = pcall(sets.getCaseDataset, case)
            if ok and type(data) == "table" then info = data end
        end
        local tier = info and tonumber(info.Tier)
        items[#items + 1] = {
            Id = "case:" .. case, Name = case, Children = skins, Image = Skins.image(info and info.CaseImg) or skins[1].Image,
            Color = tier and Skins.rarity[tier] and Skins.rarity[tier][2] or nil, Subtitle = (tier and "Tier " .. tier .. " / " or "") .. #skins .. " skins",
        }
    end
    return items
end

function Skins.syncCases()
    local items = Skins.galleryItems()
    Skins.cases = items
    if Skins.gallery then
        local parts = {}
        for _, case in ipairs(items) do
            parts[#parts + 1] = case.Id .. "|" .. tostring(case.Image) .. "|" .. tostring(case.Subtitle)
            for _, skin in ipairs(case.Children) do parts[#parts + 1] = skin.Id .. "|" .. tostring(skin.Image) .. "|" .. skin.Subtitle end
        end
        local sig = table.concat(parts, "\0")
        if Skins.casesSig ~= sig then
            Skins.casesSig = sig
            pcall(Skins.gallery.SetItems, Skins.gallery, items)
        end
    elseif Options.skin_case and type(Options.skin_case.SetValues) == "function" then
        local names = {}
        for _, case in ipairs(items) do names[#names + 1] = case.Name end
        if #names == 0 then names[1] = "None" end
        Skins.setValues(Options.skin_case, names)
        Skins.syncCaseSkins()
    end
    return #items > 0
end

function Skins.syncCaseSkins()
    local option = Options.skin_pick
    if not (option and type(option.SetValues) == "function") then return end
    local names, case = { "None" }, flag("skin_case", nil)
    for _, folder in ipairs(Skins.cases or {}) do
        if folder.Name == case then
            for _, skin in ipairs(folder.Children) do names[#names + 1] = skin.Id end
        end
    end
    Skins.setValues(option, names)
end

function Skins.base(name)
    local pd = Skins.playerData()
    local base, loadout = { Attachments = {} }, Skins.loadout(pd) or {}
    for _, key in ipairs({ "Primary", "Secondary", "Knife" }) do
        local slot = loadout[key]
        if type(slot) == "table" and slot.Name == name then
            if type(slot.Attachments) == "table" then base.Attachments = slot.Attachments end
            if type(slot.Camo) == "table" then base.Camo = slot.Camo end
            break
        end
    end
    pcall(function()
        local settings = pd.settings
        if not base.Camo then
            for _, byWeapon in pairs(settings.gunloadoutdata or {}) do
                local past = type(byWeapon) == "table" and byWeapon[name]
                if type(past) == "table" then
                    if type(past.Attachments) == "table" then base.Attachments = past.Attachments end
                    if type(past.Camo) == "table" then base.Camo = past.Camo end
                    break
                end
            end
        end
        local att = settings.attloadoutdata and settings.attloadoutdata[name]
        if type(att) == "table" then base.AttData = att end
    end)
    return base
end

function Skins.findModel(name)
    local content = Game.mods.ContentInterface
    if content and type(content.getWeaponModel) == "function" then
        local ok, model = pcall(content.getWeaponModel, name)
        if ok and typeof(model) == "Instance" then return model end
    end
    if content and type(content.getWeaponEntry) == "function" then
        local ok, entry = pcall(content.getWeaponEntry, name)
        if ok and type(entry) == "table" and typeof(entry.weaponModel) == "Instance" then return entry.weaponModel end
    end
    local ok, model = pcall(function()
        for _, database in ipairs(Game.contentFolders("WeaponDatabase")) do
            local classes = { Skins.classOf[name] and database:FindFirstChild(Skins.classOf[name]) }
            for _, class in ipairs(database:GetChildren()) do classes[#classes + 1] = class end
            for _, class in ipairs(classes) do
                local weapon = class:FindFirstChild(name)
                local hit = weapon and weapon:FindFirstChild(name .. " Main")
                if hit then return hit end
            end
        end
    end)
    return ok and typeof(model) == "Instance" and model or nil
end

function Skins.clone(source)
    local ok, copy = pcall(function()
        local was = source.Archivable
        source.Archivable = true
        local result = source:Clone()
        source.Archivable = was
        return result
    end)
    return ok and typeof(copy) == "Instance" and copy or nil
end

function Skins.buildModel(name)
    local content, utils = Game.mods.ContentInterface, Game.mods.WeaponUtils
    if type(name) ~= "string" then return nil, Skins.emptyText end
    if not content then return nil, "Game content not loaded yet" end
    local base = Skins.base(name)
    local camo = Skins.merge(name, base.Camo) or base.Camo
    local model, problem
    if utils and type(utils.constructWeapon) == "function" and not Knife.isKnife(name) then
        local ok, built = pcall(function()
            local compiler = Game.mods.ContentUtils
            local data
            if compiler and type(compiler.compileWeaponData) == "function" then
                data = compiler.compileWeaponData({ weaponName = name, weaponAttachments = base.Attachments })
            else
                data = content.getWeaponData(name)
            end
            if type(data) ~= "table" then error("no weapon data") end
            return utils.constructWeapon(name, data, base.Attachments, camo, base.AttData)
        end)
        if ok and typeof(built) == "Instance" then
            model = built
        else
            problem = ok and "constructWeapon returned nothing" or tostring(built)
            Util.note("skins-construct-" .. name, "skin changer: constructWeapon failed for " .. name .. ", previewing the bare model:", problem)
        end
    end
    if not model then
        local source = Skins.findModel(name)
        if not source then return nil, "Model not found: " .. name, problem end
        model = Skins.clone(source)
        if not model then return nil, "Model could not be copied: " .. name, problem end
        pcall(function()
            local nodes = model:FindFirstChild("MenuNodes")
            if nodes then nodes:Destroy() end
        end)
        if camo and utils and type(utils.textureModel) == "function" then pcall(utils.textureModel, model, camo) end
    end
    local okList, list = pcall(function() return model:GetDescendants() end)
    for _, object in ipairs(okList and list or {}) do
        pcall(function()
            if object:IsA("BasePart") then
                object.Anchored = true
                if object.Transparency == 1 and object.Name ~= "Trigger" then object:Destroy() end
            end
        end)
    end
    return model
end

function Skins.step(now)
    if Skins.saveAt and now >= Skins.saveAt then
        Skins.saveAt = nil
        Skins.save()
    end
    Skins.follow()
    Skins.recheck(now)
    if not Skins.dirty or now < Skins.buildAt then return end
    Skins.dirty = false
    if not Skins.viewport then return end
    Skins.buildAt = now + 0.15
    local name = Skins.selected
    local ok, model, reason, problem = pcall(Skins.buildModel, name)
    if not ok then model, reason, problem = nil, "Preview failed: " .. tostring(name), model end
    if typeof(model) ~= "Instance" then model = nil end
    if not model and name then
        Util.note("skins-preview-" .. name, "skin changer: " .. tostring(reason) .. (problem and " (" .. tostring(problem) .. ")" or ""))
        Skins.failed(name, now)
    else
        Skins.fail = nil
    end
    Skins.setEmpty(not model and reason or Skins.emptyText)
    local old = Skins.shown
    Skins.shown = model
    pcall(Skins.viewport.SetModel, Skins.viewport, model, Skins.keepView)
    Skins.keepView = true
    if old and old ~= model then pcall(function() old:Destroy() end) end
end

function Skins.retryKey(name)
    return table.concat({ name, tostring(Skins.classOf[name]), tostring(Skins.ready), tostring(Game.camoDatabase() ~= nil), tostring(#Game.contentFolders("WeaponDatabase")),
        tostring(Game.mods.ContentInterface ~= nil), tostring(Game.mods.WeaponUtils ~= nil) }, "|")
end

function Skins.failed(name, now)
    local fail = Skins.fail
    if not (fail and fail.name == name) then
        fail = { name = name, tries = 0, delay = Skins.retryFirst }
        Skins.fail = fail
    end
    fail.tries = fail.tries + 1
    fail.key, fail.checkAt, fail.retryAt = Skins.retryKey(name), now + 1, now + fail.delay
    fail.delay = math.min(fail.delay * 2, Skins.retryCap)
end

function Skins.recheck(now)
    local fail = Skins.fail
    if not fail or Skins.dirty or now < fail.checkAt then return end
    fail.checkAt = now + 1
    if Skins.retryKey(fail.name) ~= fail.key then
        fail.tries, fail.delay = 0, Skins.retryFirst
        Skins.dirty = true
    elseif fail.tries < Skins.retryMax and now >= fail.retryAt then
        Skins.dirty = true
    end
end

function Skins.setEmpty(text)
    local view = Skins.viewport
    if not view then return end
    if type(view.SetEmptyText) == "function" then
        pcall(view.SetEmptyText, view, text)
        return
    end
    if not (Skins.emptyLabel and propGet(Skins.emptyLabel, "Parent")) then
        Skins.emptyLabel = nil
        pcall(function()
            for _, child in ipairs(view.Frame:GetChildren()) do
                if child:IsA("TextLabel") and child.Text == Skins.emptyText then
                    Skins.emptyLabel = child
                    break
                end
            end
        end)
    end
    local label = Skins.emptyLabel
    if label and label.Text ~= text then pcall(function() label.Text = text end) end
end

function Skins.entry(create)
    local name = Skins.selected
    if not name then return nil end
    local entry = Skins.store.weapons[name]
    if not entry and create then
        entry = {}
        Skins.store.weapons[name] = entry
    end
    return entry
end

function Skins.current()
    local entry = Skins.entry(false)
    return entry and entry[Skins.slot] or nil
end

function Skins.changed()
    Skins.dirty = true
    Skins.saveAt = os.clock() + 1
    local entry = Skins.entry(false)
    if entry and next(entry) == nil then Skins.store.weapons[Skins.selected] = nil end
end

function Skins.select(name)
    if type(name) ~= "string" or not Skins.classOf[name] then name = nil end
    if name ~= Skins.selected then Skins.keepView, Skins.buildAt = false, 0 end
    Skins.selected = name
    Skins.dirty = true
    Skins.syncControls()
    Skins.syncPresets()
end

function Skins.setSlot(label)
    Skins.slot = label == "Slot 2" and "Slot2" or "Slot1"
    Skins.syncControls()
end

function Skins.hint(text)
    local now = os.clock()
    if now - Skins.hintAt < 3 then return end
    Skins.hintAt = now
    World.notify(text)
end

function Skins.setSkin(skin, on)
    if not Skins.selected then
        Skins.hint("Skin changer: pick a weapon first")
    elseif on and not Skins.dataset(skin) then
        Skins.hint("Skin changer: unknown skin " .. tostring(skin))
    elseif on then
        Skins.entry(true)[Skins.slot] = { Name = skin }
        Skins.changed()
    else
        local entry = Skins.entry(false)
        if entry and entry[Skins.slot] and entry[Skins.slot].Name == skin then
            entry[Skins.slot] = nil
            Skins.changed()
        end
    end
    Skins.syncControls()
end

function Skins.edit(group, key, value)
    if Skins.syncing then return end
    local slot = Skins.current()
    if not slot then
        Skins.hint("Skin changer: pick a skin for this slot in Cases first")
        return
    end
    slot[group] = slot[group] or {}
    slot[group][key] = value
    Skins.entry(false)[Skins.slot] = Skins.cleanSlot(slot)
    Skins.changed()
    Skins.status()
end

function Skins.effective()
    local slot = Skins.current() or {}
    local data = Skins.dataset(slot.Name) or {}
    local tex, brick = slot.TextureProperties or {}, slot.BrickProperties or {}
    local texPreset = type(data.TexturePreset) == "table" and data.TexturePreset or {}
    local brickPreset = type(data.BrickPreset) == "table" and data.BrickPreset or {}
    local values = {}
    for _, spec in ipairs(Skins.sliders) do
        local preset = spec.group == "TextureProperties" and texPreset or brickPreset
        local fallback = spec.key == "StudsPerTileV" and texPreset.StudsPerTileU or preset[spec.key]
        local custom = (spec.group == "TextureProperties" and tex or brick)[spec.key]
        local range = Skins.ranges[spec.group][spec.key]
        values[spec.flag] = math.clamp(tonumber(custom) or tonumber(fallback) or spec.default, range[1], range[2])
    end
    values.texColor = tex.Color and Skins.toColor3(tex.Color) or (typeof(texPreset.Color) == "Color3" and texPreset.Color) or WHITE
    values.texAlpha = math.clamp(tonumber(tex.Transparency) or tonumber(texPreset.Transparency) or 0, 0, 1)
    values.brickColor = brick.Color and Skins.toColor3(brick.Color) or (typeof(brickPreset.Color) == "Color3" and brickPreset.Color) or Color3.fromRGB(163, 162, 165)
    values.material = brick.Material or Skins.materialName(brickPreset.Material) or "SmoothPlastic"
    return values
end

function Skins.status()
    if not Skins.label then return end
    local slot = Skins.current()
    local text = (Skins.slot == "Slot2" and "Slot 2: " or "Slot 1: ") .. (slot and slot.Name or "no skin")
    if slot and (slot.TextureProperties or slot.BrickProperties) then text = text .. " (customised)" end
    Skins.label:SetText(text)
end

function Skins.syncControls()
    Skins.syncing = true
    pcall(function()
        local values = Skins.effective()
        for _, spec in ipairs(Skins.sliders) do
            local option = Options[spec.flag]
            if option then option:SetValue(values[spec.flag]) end
        end
        if Options.skin_tex_color then Options.skin_tex_color:SetValueRGB(values.texColor, values.texAlpha) end
        if Options.skin_brick_color then Options.skin_brick_color:SetValueRGB(values.brickColor) end
        if Options.skin_material then Options.skin_material:SetValue(values.material) end
        local slot = Skins.current()
        if Skins.gallery then
            Skins.gallery:SetValue(slot and slot.Name or nil)
        elseif Options.skin_pick then
            local name = slot and slot.Name
            local case = name and (Skins.dataset(name) or {}).Case
            if type(case) == "string" and Options.skin_case then
                Options.skin_case:SetValue(case)
                Skins.syncCaseSkins()
            end
            Options.skin_pick:SetValue(name or "None")
        end
    end)
    Skins.syncing = false
    Skins.status()
end

function Skins.resetWeapon()
    if not Skins.selected then return end
    Skins.store.weapons[Skins.selected] = nil
    Skins.dirty, Skins.saveAt = true, os.clock() + 1
    Skins.syncControls()
end

function Skins.resetSlot()
    local slot = Skins.current()
    if not slot then return end
    Skins.entry(false)[Skins.slot] = { Name = slot.Name }
    Skins.changed()
    Skins.syncControls()
end

function Skins.copySlot()
    local slot = Skins.current()
    if not slot then return end
    Skins.entry(false)[Skins.slot == "Slot1" and "Slot2" or "Slot1"] = Skins.copy(slot)
    Skins.changed()
    World.notify("Skin changer: copied to " .. (Skins.slot == "Slot1" and "Slot 2" or "Slot 1"))
end

function Skins.blueprints()
    if Skins.bp then return Skins.bp end
    local content = Game.mods.ContentInterface
    local list = {}
    if content and type(content.getAllBlueprints) == "function" and type(content.getBlueprintData) == "function" then
        local ok, ids = pcall(content.getAllBlueprints)
        for _, id in ipairs(ok and type(ids) == "table" and ids or {}) do
            local okData, blueprint = pcall(content.getBlueprintData, id)
            local camo = okData and type(blueprint) == "table" and Skins.cleanCamo(blueprint.weaponCamo)
            if camo then
                list[#list + 1] = { name = tostring(blueprint.itemName or id), weapon = tostring(blueprint.weaponName or "?"), camo = camo }
            end
        end
    end
    if #list > 0 then Skins.bp = list end
    return list
end

function Skins.presets(source)
    local found = { list = {}, byName = {}, weaponOf = {} }
    local query = string.lower(tostring(flag("skin_preset_search", "") or ""):match("^%s*(.-)%s*$"))
    local function add(label, camo, weapon)
        if found.byName[label] then return end
        if query ~= "" and not (string.find(string.lower(label), query, 1, true) or (weapon and string.find(string.lower(weapon), query, 1, true))) then return end
        found.byName[label], found.weaponOf[label] = camo, weapon
        found.list[#found.list + 1] = label
    end
    if source == "Community" then
        for _, preset in ipairs(Skins.community) do
            local camo = Skins.cleanCamo({ Slot1 = preset[2], Slot2 = preset[3] or preset[2] })
            if camo then add(preset[1], camo) end
        end
        return found
    end
    if source == "Blueprints" then
        local mode = flag("skin_preset_weapon", "Selected weapon")
        for _, blueprint in ipairs(Skins.blueprints()) do
            local weapon = blueprint.weapon
            if mode == "Selected weapon" then
                if weapon == Skins.selected then add(blueprint.name, blueprint.camo, weapon) end
            elseif mode == "All" or Skins.classOf[weapon] then
                add(weapon .. " \226\128\147 " .. blueprint.name, blueprint.camo, weapon)
            end
        end
    else
        for name, camo in pairs(Skins.store.presets) do add(name, camo) end
    end
    table.sort(found.list)
    return found
end

function Skins.syncPresets()
    local option = Options.skin_preset
    if not (option and type(option.SetValues) == "function") then return end
    local items = Skins.presets(flag("skin_preset_src", "Community")).list
    local list = {}
    for index, name in ipairs(items) do list[index] = name end
    if #list == 0 then list[1] = "None" end
    Skins.setValues(option, list)
    if not table.find(list, option.Value) then pcall(option.SetValue, option, list[1]) end
end

function Skins.applyPreset()
    local name = flag("skin_preset", nil)
    local found = Skins.presets(flag("skin_preset_src", "Community"))
    local camo, weapon = found.byName[name], found.weaponOf[name]
    if not camo then return Skins.hint("Skin changer: pick a preset first") end
    if weapon and weapon ~= Skins.selected then
        if not Skins.classOf[weapon] then return World.notify("Skin changer: you do not own " .. weapon .. ", blueprint not applied") end
        Skins.show(weapon)
    end
    if not Skins.selected then return Skins.hint("Skin changer: pick a weapon first") end
    local entry, applied, skipped = Skins.entry(true), 0, {}
    for _, tag in ipairs(Skins.slots) do
        local slot = camo[tag]
        if slot and Skins.dataset(slot.Name) then
            entry[tag] = Skins.copy(slot)
            applied = applied + 1
        elseif slot then
            skipped[#skipped + 1] = slot.Name
        end
    end
    if applied > 0 then
        for _, tag in ipairs(Skins.slots) do
            if not camo[tag] then entry[tag] = nil end
        end
    end
    Skins.changed()
    Skins.syncControls()
    if #skipped > 0 then World.notify("Skin changer: skipped unknown skin " .. table.concat(skipped, ", ")) end
    return applied
end

function Skins.savePreset()
    local name = tostring(flag("skin_preset_name", "") or ""):match("^%s*(.-)%s*$")
    local entry = Skins.entry(false)
    if name == "" then return Skins.hint("Skin changer: type a preset name first") end
    if not entry then return Skins.hint("Skin changer: this weapon has no skin to save") end
    Skins.store.presets[name] = Skins.copy(entry)
    Skins.save()
    if Options.skin_preset_search then pcall(Options.skin_preset_search.SetValue, Options.skin_preset_search, "") end
    if Options.skin_preset_src then Options.skin_preset_src:SetValue("Saved") end
    Skins.syncPresets()
    pcall(function() Options.skin_preset:SetValue(name) end)
    World.notify("Skin changer: saved preset " .. name)
end

function Skins.deletePreset()
    if flag("skin_preset_src", "Community") ~= "Saved" then return Skins.hint("Skin changer: only saved presets can be deleted") end
    local name = flag("skin_preset", nil)
    if not Skins.store.presets[name] then return end
    Skins.store.presets[name] = nil
    Skins.save()
    Skins.syncPresets()
end

function Skins.canSave()
    if Skins.writable == nil then
        Skins.writable = type(writefile) == "function"
        if not Skins.writable then Util.note("skins-nosave", "skin changer: no writefile in this executor, skins are not saved") end
    end
    return Skins.writable
end

function Skins.save()
    if not Skins.canSave() then return end
    local ok, text = pcall(function()
        return game:GetService("HttpService"):JSONEncode({ version = 1, weapons = Skins.store.weapons, presets = Skins.store.presets })
    end)
    if ok and type(text) == "string" then Util.guard("skins-save", writefile, Skins.file, text) end
end

function Skins.load()
    if type(readfile) ~= "function" then return false end
    if type(isfile) == "function" then
        local okHas, has = pcall(isfile, Skins.file)
        if not (okHas and has) then return false end
    end
    local ok, data = pcall(function() return game:GetService("HttpService"):JSONDecode(readfile(Skins.file)) end)
    if not (ok and type(data) == "table") then return false end
    Skins.store.weapons = Skins.cleanEntries(data.weapons)
    Skins.store.presets = Skins.cleanEntries(data.presets)
    return true
end

function Skins.refresh()
    local cases = Skins.syncCases()
    Skins.syncWeapons()
    Skins.syncPresets()
    Skins.synced = cases and Skins.ready
    return Skins.synced
end

function Skins.hook()
    for _, spec in ipairs({ { "FirearmObject", "skinFire" }, { "MeleeObject", "skinMelee" } }) do
        local owner, key = Game.mods[spec[1]], spec[2]
        if type(owner) == "table" and not Game.hooked[key] then
            Game.hooked[key] = Util.hook(owner, "new", function(original)
                if key == "skinFire" then
                    return function(character, index, name, attachments, camo, ...)
                        local ok, swapped = pcall(Skins.camoFor, name, camo)
                        if ok and swapped then camo = swapped end
                        return original(character, index, name, attachments, camo, ...)
                    end
                end
                return function(character, index, name, camo, ...)
                    local ok, swapped = pcall(Skins.camoFor, name, camo)
                    if ok and swapped then camo = swapped end
                    return original(character, index, name, camo, ...)
                end
            end)
        end
    end
    if not Skins.synced then Skins.refresh() end
end

Skins.load()

Util.onUnload(function()
    if Skins.saveAt then Skins.save() end
    Skins.saveAt = nil
    if Skins.shown then pcall(function() Skins.shown:Destroy() end) end
    Skins.shown = nil
end)

local Watch = {
    log = {}, seen = {}, skip = {}, conns = {}, cap = 200, shown = 8, period = 5, nilEvery = 3, gen = 0, on = false, notifyAt = -math.huge, file = "Aster/PhantomForces/watch_log.txt",
    scripts = { ModuleScript = true, LocalScript = true, Script = true },
    databases = { "WeaponDatabase", "AttachmentDatabase" },
    idleText = "No new scripts or modules since the baseline", offText = "Off: turn on to take a baseline and log new scripts",
}

function Watch.path(object)
    local ok, full = pcall(function() return object:GetFullName() end)
    if ok and type(full) == "string" then return full end
    local names, node = {}, object
    while node and #names < 32 do
        table.insert(names, 1, tostring(propGet(node, "Name")))
        node = propGet(node, "Parent")
    end
    return table.concat(names, ".")
end

function Watch.digest(text)
    local hash = 5381
    for index = 1, #text do hash = (hash * 33 + string.byte(text, index)) % 4294967296 end
    return string.format("%08x", math.floor(hash))
end

function Watch.hash(object)
    if type(getscripthash) == "function" then
        local ok, hash = pcall(getscripthash, object)
        if ok and hash ~= nil then return tostring(hash) end
    end
    if type(getscriptbytecode) == "function" then
        local ok, code = pcall(getscriptbytecode, object)
        if ok and type(code) == "string" and code ~= "" then return Watch.digest(code) .. "/" .. #code end
    end
    return nil
end

function Watch.stamp()
    local ok, text = pcall(os.date, "%H:%M:%S")
    return ok and type(text) == "string" and text or string.format("%.1f", os.clock())
end

function Watch.short(name)
    if #name > 48 then return "..." .. string.sub(name, -45) end
    return name
end

function Watch.render()
    if not Watch.label then return end
    local lines = {}
    for index = math.max(1, #Watch.log - Watch.shown + 1), #Watch.log do
        local entry = Watch.log[index]
        lines[#lines + 1] = entry.time .. " " .. entry.class .. " " .. Watch.short(entry.name)
    end
    Watch.label:SetText(#lines > 0 and table.concat(lines, "\n") or (Watch.on and Watch.idleText or Watch.offText))
end

function Watch.check(object, via)
    if Watch.seen[object] then return end
    Watch.seen[object] = true
    local class = tostring(propGet(object, "ClassName") or "?")
    local parent = propGet(object, "Parent")
    local entry = { time = Watch.stamp(), class = class, name = Watch.path(object), parent = parent and Watch.path(parent) or "nil", via = via, hash = Watch.scripts[class] and Watch.hash(object) or nil }
    entry.line = string.format("%s %s %s (parent %s, via %s)%s", entry.time, class, entry.name, entry.parent, via, entry.hash and " hash " .. entry.hash or "")
    table.insert(Watch.log, entry)
    if #Watch.log > Watch.cap then table.remove(Watch.log, 1) end
    if flag("misc_watch_print", false) then print("[Aster watch] " .. entry.line) end
    local now = os.clock()
    if flag("misc_watch_notify", true) and now >= Watch.notifyAt then
        Watch.notifyAt = now + 1
        World.notify("Script watcher: new " .. class .. " " .. Watch.short(entry.name))
    end
    Watch.render()
end

function Watch.children(object)
    local ok, list = pcall(function() return object:GetChildren() end)
    return ok and type(list) == "table" and list or {}
end

function Watch.each(fn, skipNil)
    for _, source in ipairs({ { "getloadedmodules", getloadedmodules }, { "getrunningscripts", getrunningscripts }, { "getnilinstances", not skipNil and getnilinstances } }) do
        local ok, list = false, nil
        if type(source[2]) == "function" then ok, list = pcall(source[2]) end
        for _, object in ipairs(ok and type(list) == "table" and list or {}) do
            if typeof(object) == "Instance" and not Watch.seen[object] and not Watch.skip[object] then
                if Watch.scripts[propGet(object, "ClassName")] then fn(object, source[1]) else Watch.skip[object] = true end
            end
        end
    end
    for _, name in ipairs(Watch.databases) do
        for _, database in ipairs(Game.contentFolders(name)) do
            for _, child in ipairs(Watch.children(database)) do
                if not Watch.seen[child] then fn(child, name) end
                for _, entry in ipairs(Watch.children(child)) do
                    if not Watch.seen[entry] then fn(entry, name) end
                end
            end
        end
    end
end

function Watch.listen(root, classes, via)
    if not root then return nil end
    local ok, connection = pcall(function()
        return root.DescendantAdded:Connect(function(object)
            if classes[object.ClassName] then Watch.check(object, via) end
        end)
    end)
    if not (ok and connection) then return nil end
    Watch.conns[#Watch.conns + 1] = connection
    return connection
end

function Watch.watchCharacter(character)
    if Watch.charConn then pcall(function() Watch.charConn:Disconnect() end) end
    Watch.charConn = nil
    if character then Watch.charConn = Watch.listen(character, Watch.scripts, "Character") end
end

function Watch.schedule(gen, count)
    task.delay(Watch.period, function()
        if Watch.gen ~= gen or not Watch.on then return end
        count = (count or 0) + 1
        Util.guard("watch", Watch.each, Watch.check, count % Watch.nilEvery ~= 0)
        Watch.schedule(gen, count)
    end)
end

function Watch.start()
    Watch.stop()
    Watch.on, Watch.gen = true, Watch.gen + 1
    Watch.seen, Watch.skip = setmetatable({}, { __mode = "k" }), setmetatable({}, { __mode = "k" })
    Util.guard("watch-baseline", Watch.each, function(object) Watch.seen[object] = true end)
    local function service(name)
        local ok, found = pcall(function() return game:GetService(name) end)
        return ok and found or nil
    end
    local function child(name)
        local ok, found = pcall(function() return LocalPlayer:FindFirstChild(name) or LocalPlayer:FindFirstChildOfClass(name) end)
        return ok and found or nil
    end
    Watch.listen(service("ReplicatedStorage"), Watch.scripts, "ReplicatedStorage")
    Watch.listen(service("ReplicatedFirst"), Watch.scripts, "ReplicatedFirst")
    Watch.listen(child("PlayerScripts"), Watch.scripts, "PlayerScripts")
    Watch.listen(child("PlayerGui"), Watch.scripts, "PlayerGui")
    Watch.watchCharacter(propGet(LocalPlayer, "Character"))
    pcall(function()
        Watch.conns[#Watch.conns + 1] = LocalPlayer.CharacterAdded:Connect(function(character) Watch.watchCharacter(character) end)
    end)
    Watch.schedule(Watch.gen)
    Watch.render()
end

function Watch.stop()
    Watch.on, Watch.gen = false, Watch.gen + 1
    for _, connection in ipairs(Watch.conns) do pcall(function() connection:Disconnect() end) end
    Watch.conns, Watch.charConn = {}, nil
    Watch.seen, Watch.skip = {}, {}
end

function Watch.set(value)
    if value then Watch.start() else Watch.stop() end
    Watch.render()
end

function Watch.dump()
    local lines, count = { "Aster script watcher dump " .. Watch.stamp(), "", "Loaded modules:" }, 0
    if type(getloadedmodules) == "function" then
        local ok, list = pcall(getloadedmodules)
        for _, module in ipairs(ok and type(list) == "table" and list or {}) do
            count = count + 1
            lines[#lines + 1] = Watch.path(module) .. (propGet(module, "Parent") and "" or " (nil parent)")
        end
    else
        lines[#lines + 1] = "getloadedmodules is not available in this executor"
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Watch log:"
    for _, entry in ipairs(Watch.log) do lines[#lines + 1] = entry.line end
    local ok, problem = pcall(function() writefile(Watch.file, table.concat(lines, "\n")) end)
    World.notify(ok and "Wrote " .. count .. " modules to " .. Watch.file or "Dump failed: " .. tostring(problem))
end

Util.onUnload(Watch.stop)

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

Corpse.kindFlags = {
    { kind = "enemy", on = "chams_dead_enemy", color = "chams_dead_enemy_color" },
    { kind = "team", on = "chams_dead_team", color = "chams_dead_team_color" },
    { kind = "local", on = "chams_dead_local", color = "chams_dead_local_color" },
}

function Corpse.state()
    local last = Corpse.last
    local materialName, texture, refl = val("chams_dead_mat") or "ForceField", val("chams_dead_tex") or "None", val("chams_dead_refl") or 0
    local hide, fade = on("chams_dead_hide") == true, val("chams_dead_fade") or 0
    local same = last and last.materialName == materialName and last.texture == texture and last.refl == refl and last.hide == hide and last.fade == fade
    if same then
        for _, spec in ipairs(Corpse.kindFlags) do
            local entry = last.kinds[spec.kind]
            if entry.enabled ~= (on(spec.on) == true) or entry.color ~= (val(spec.color) or WHITE) or entry.alpha ~= Util.alpha(spec.color, 0) then
                same = false
                break
            end
        end
    end
    if same then return last end
    local state = { materialName = materialName, texture = texture, refl = refl, hide = hide, fade = fade, kinds = {}, sig = (last and last.sig or 0) + 1 }
    for _, spec in ipairs(Corpse.kindFlags) do
        state.kinds[spec.kind] = { enabled = on(spec.on) == true, color = val(spec.color) or WHITE, alpha = Util.alpha(spec.color, 0) }
    end
    Corpse.last = state
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
    events = {}, pending = {}, kept = {}, fired = setmetatable({}, { __mode = "k" }), maxEvents = 6, fx = {}, window = 2, near = 6,
    names = { "Dissolve", "Lightning", "Shockwave", "Sparks", "Pillar", "Screen flash", "Soul rip", "Pixelate", "Glitch", "Tombstone", "Blackout ring", "Firework", "Crystallize", "Holo-scan", "Anime slash" },
    glow = "rbxasset://textures/particles/sparkles_main.dds",
    corpseNames = { "Zero-G float", "Ascend", "Ragdoll launch", "Black hole", "Disintegrate", "Ghost", "Freeze", "Confetti",
        "Melt", "Spaghettify", "Balloon", "Orbit", "Glass shatter", "Magnetize", "Puppet", "Time freeze", "Implode", "Vaporize" },
    movers = { ["Zero-G float"] = true, Ascend = true, ["Ragdoll launch"] = true, ["Black hole"] = true, Melt = true, Spaghettify = true, Balloon = true,
        Orbit = true, ["Glass shatter"] = true, Magnetize = true, Puppet = true, ["Time freeze"] = true, Implode = true },
    settle = 5, ice = Color3.fromRGB(170, 220, 255),
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
    local rate = base.Rate
    base.Rate = 0
    if base.Size ~= nil then base.Size = Tracers.sized(base.Size, ev.sizeScale or 1) end
    local emitter = KillFx.make(ev, "ParticleEmitter", base, parent)
    local group, life = ev.group, base.Lifetime
    group.life = math.max(group.life or 0, life and life.Max or 1)
    group.emitters = group.emitters or {}
    group.emitters[#group.emitters + 1] = emitter
    if rate > 0 then
        ev.streams = ev.streams or {}
        ev.streams[#ev.streams + 1] = { emitter = emitter, rate = rate, acc = 1 }
    end
    return emitter
end

function KillFx.shrink(size)
    return NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
end

function KillFx.ground(pos)
    local okCast, hit = pcall(Game.cast, pos + Vector3.new(0, 3, 0), Vector3.new(0, -60, 0), Visible.params)
    if okCast and hit and typeof(hit.Position) == "Vector3" then return hit.Position end
    return pos
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
        local finished, restored = false, false
        local function restore()
            if restored then return end
            restored = true
            for _, item in ipairs(parts) do
                Local.setIf(item.inst, "Material", item.material)
                Local.setIf(item.inst, "Color", item.color)
                Local.setIf(item.inst, "Transparency", item.base)
            end
            for _, item in ipairs(decals) do Local.setIf(item.inst, "Transparency", item.base) end
            Corpse.release(corpse)
        end
        ev.undo[#ev.undo + 1] = function()
            if not finished then restore() end
        end
        ev.ticks[#ev.ticks + 1] = function(t)
            if finished then return true end
            if propGet(corpse, "Parent") == nil then
                finished, restored = true, true
                Corpse.release(corpse)
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
            if progress >= 1.05 then
                finished = true
                KillFx.keep(corpse, restore)
            end
            return finished
        end
    end,
}

KillFx.fx.Shockwave = {
    start = function(ev, corpse, pos, opts)
        local ground = KillFx.ground(pos)
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
        if burst then KillFx.emitted[emitter] = os.clock() end
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

KillFx.emitted = setmetatable({}, { __mode = "k" })

function KillFx.burst(emitter, count)
    if not emitter or not (count > 0) then return end
    if pcall(emitter.Emit, emitter, math.max(1, math.floor(count + 0.5))) then KillFx.emitted[emitter] = os.clock() end
end

function KillFx.modifier(object)
    local value = propGet(object, "LocalTransparencyModifier")
    return type(value) == "number" and value or 0
end

function KillFx.body(ev, corpse)
    ev.bodies = ev.bodies or {}
    local body = ev.bodies[corpse]
    if body then return body end
    body = { parts = {}, decals = {}, groups = {}, open = 0, anchored = false, fade = 0 }
    ev.bodies[corpse] = body
    local ok, list = pcall(function() return corpse:GetDescendants() end)
    if not (ok and type(list) == "table") then return body end
    local byInst = {}
    for _, object in ipairs(list) do
        local kind = Local.kindOf(object)
        if kind and kind ~= "decal" and kind ~= "smesh" then
            local frame = propGet(object, "CFrame")
            if typeof(frame) ~= "CFrame" then
                local at = propGet(object, "Position")
                frame = typeof(at) == "Vector3" and CFrame.new(at) or nil
            end
            if frame then
                local top = object
                for _ = 1, 12 do
                    local parent = propGet(top, "Parent")
                    if not parent or parent == corpse then break end
                    top = parent
                end
                local group = body.groups[top]
                if not group then
                    group = { cf = frame, frame = frame }
                    body.groups[top] = group
                end
                local item = {
                    inst = object, cf = frame, at = frame, group = group, offset = group.cf:Inverse() * frame, top = top == object, name = propGet(object, "Name"),
                    anchored = propGet(object, "Anchored") == true, ltm = KillFx.modifier(object), alpha = propGet(object, "Transparency"), color = propGet(object, "Color"),
                    size = propGet(object, "Size"), fade = 0, sink = 0,
                }
                body.parts[#body.parts + 1], byInst[object] = item, item
            end
        end
    end
    for _, object in ipairs(list) do
        if Local.kindOf(object) == "decal" then
            body.decals[#body.decals + 1] = { inst = object, ltm = KillFx.modifier(object), owner = byInst[propGet(object, "Parent")] }
        end
    end
    body.unhide = function()
        for _, item in ipairs(body.parts) do
            propSet(item.inst, "LocalTransparencyModifier", item.ltm)
            if item.sized then
                item.sized = nil
                propSet(item.inst, "Size", item.size)
            end
        end
        for _, item in ipairs(body.decals) do propSet(item.inst, "LocalTransparencyModifier", item.ltm) end
    end
    ev.undo[#ev.undo + 1] = function()
        if body.open <= 0 then return end
        body.open = 0
        local settled = os.clock() >= ev.settle
        for _, item in ipairs(body.parts) do
            if body.anchored then
                propSet(item.inst, "CFrame", item.cf)
                propSet(item.inst, "Anchored", item.anchored or settled)
            end
        end
        body.unhide()
    end
    return body
end

function KillFx.pose(body, transform)
    if not body.anchored then
        body.anchored = true
        for _, item in ipairs(body.parts) do propSet(item.inst, "Anchored", true) end
    end
    for _, item in ipairs(body.parts) do
        item.at = transform(item)
        propSet(item.inst, "CFrame", item.at)
    end
end

function KillFx.rigid(body, pivot, target, turn)
    local move = CFrame.new(target) * turn * CFrame.new(-pivot)
    body.center = target
    KillFx.pose(body, function(item) return move * item.cf end)
end

function KillFx.resize(item, size)
    if typeof(item.size) ~= "Vector3" or size == item.sized then return end
    item.sized = size
    propSet(item.inst, "Size", size)
end

function KillFx.paint(body)
    for _, item in ipairs(body.parts) do
        local alpha = math.max(item.ltm, body.fade, item.fade, item.sink)
        if alpha ~= item.shown then
            item.shown = alpha
            propSet(item.inst, "LocalTransparencyModifier", alpha)
        end
    end
    for _, item in ipairs(body.decals) do
        local owner = item.owner
        local alpha = math.max(item.ltm, body.fade, owner and math.max(owner.fade, owner.sink) or 0)
        if alpha ~= item.shown then
            item.shown = alpha
            propSet(item.inst, "LocalTransparencyModifier", alpha)
        end
    end
end

function KillFx.drive(ev, corpse, body, length, tail, step)
    body.open = body.open + 1
    local closed = false
    local function close(keep)
        if closed then return end
        closed = true
        body.open = body.open - 1
        if keep and body.open <= 0 and not body.kept then
            body.kept = true
            KillFx.keep(corpse, body.unhide)
        end
    end
    ev.ticks[#ev.ticks + 1] = function(t)
        if propGet(corpse, "Parent") == nil then
            close(false)
            return true
        end
        local progress = math.clamp(t / length, 0, 1)
        if not closed then
            step(t, progress)
            if progress >= 1 then close(true) end
        end
        return t >= length + tail
    end
end

KillFx.fx["Zero-G float"] = {
    start = function(ev, corpse, pos, opts)
        local body = KillFx.body(ev, corpse)
        if #body.parts == 0 then return end
        local drift = Vector3.new(fxRand(-1.5, 1.5), 0, fxRand(-1.5, 1.5))
        local spin = Vector3.new(fxRand(-0.6, 0.6), fxRand(-0.8, 0.8), fxRand(-0.6, 0.6))
        local holder = KillFx.anchor(ev, pos, Vector3.new(3, 4, 2))
        local motes = KillFx.emitter(ev, holder, {
            Rate = math.floor(6 * opts.cint), Enabled = true, Lifetime = NumberRange.new(1.5, 2.5), Speed = NumberRange.new(0.2, 0.8),
            SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, 1.5, 0), Size = KillFx.shrink(0.25), Color = ColorSequence.new(opts.color2, opts.color),
        })
        KillFx.drive(ev, corpse, body, opts.cdur, 0.5, function(t, progress)
            local lift = Vector3.new(0, opts.height * (1 - (1 - progress) ^ 2) + 0.3 * math.sin(t * 2), 0) + drift * progress
            KillFx.rigid(body, pos, pos + lift, CFrame.Angles(spin.X * t, spin.Y * t, spin.Z * t))
            holder.CFrame = CFrame.new(pos + lift)
            body.fade = math.clamp((progress - 0.7) / 0.3, 0, 1)
            KillFx.paint(body)
            if progress >= 1 then motes.Enabled = false end
        end)
    end,
}

KillFx.fx.Ascend = {
    start = function(ev, corpse, pos, opts)
        local body = KillFx.body(ev, corpse)
        if #body.parts == 0 then return end
        local base = KillFx.anchor(ev, pos)
        local sky = KillFx.anchor(ev, pos + Vector3.new(0, 80, 0))
        local column = KillFx.beam(ev, base, KillFx.make(ev, "Attachment", {}, base), KillFx.make(ev, "Attachment", {}, sky), opts.color2, 0, 0)
        local halo = KillFx.anchor(ev, pos, Vector3.new(4, 0.2, 4))
        local ring = KillFx.emitter(ev, halo, {
            Rate = math.floor(14 * opts.cint), Enabled = true, Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(2, 4),
            EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(5, 5), Size = KillFx.shrink(0.4), Color = ColorSequence.new(WHITE, opts.color),
        })
        local light = KillFx.make(ev, "PointLight", { Color = opts.color2, Brightness = 0, Range = 18 }, halo)
        local width = 3.5 * math.sqrt(opts.cint)
        KillFx.drive(ev, corpse, body, opts.cdur, 1.4, function(t, progress)
            local target = pos + Vector3.new(0, opts.height * progress ^ 1.6, 0)
            KillFx.rigid(body, pos, target, CFrame.Angles(0, t * 1.2, 0))
            halo.CFrame = CFrame.new(target)
            body.fade = math.clamp((progress - 0.65) / 0.35, 0, 1)
            KillFx.paint(body)
            local glow = math.clamp(t / 0.3, 0, 1) * (1 - math.clamp((progress - 0.8) / 0.2, 0, 1))
            column.Width0, column.Width1 = width * glow, width * glow
            column.Transparency = NumberSequence.new(1 - 0.6 * glow, 1)
            light.Brightness = 3 * glow
            if progress >= 1 then ring.Enabled = false end
        end)
    end,
}

KillFx.fx["Ragdoll launch"] = {
    start = function(ev, corpse, pos, opts)
        local body = KillFx.body(ev, corpse)
        if #body.parts == 0 then return end
        local eye = ev.root and propGet(ev.root, "CFrame")
        local away = typeof(eye) == "CFrame" and pos - eye.Position or Vector3.new(fxRand(-1, 1), 0, fxRand(-1, 1))
        away = Vector3.new(away.X, 0, away.Z)
        away = away.Magnitude > 1e-3 and away.Unit or Vector3.new(1, 0, 0)
        local gravity = 60
        local velocity = away * (14 + 6 * opts.cint) + Vector3.new(0, math.sqrt(2 * gravity * opts.height * 1.5), 0)
        local tumble = Vector3.new(fxRand(4, 8), fxRand(-3, 3), fxRand(3, 6))
        local dust = KillFx.emitter(ev, KillFx.anchor(ev, pos), {
            Texture = SMOKE, LightEmission = 0.2, LightInfluence = 0.6, Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(4, 9),
            SpreadAngle = Vector2.new(180, 30), Drag = 3, Size = NumberSequence.new(1, 3), Transparency = NumberSequence.new(0.4, 1), Color = ColorSequence.new(opts.color2),
        })
        KillFx.burst(dust, 12 * opts.cint)
        local streak = KillFx.anchor(ev, pos)
        local sparks = KillFx.emitter(ev, streak, {
            Rate = math.floor(30 * opts.cint), Enabled = true, Lifetime = NumberRange.new(0.3, 0.6), Speed = NumberRange.new(0.5, 2),
            SpreadAngle = Vector2.new(180, 180), Size = KillFx.shrink(0.3), Color = ColorSequence.new(opts.color, opts.color2),
        })
        KillFx.drive(ev, corpse, body, opts.cdur, 0.7, function(t, progress)
            local target = pos + velocity * t + Vector3.new(0, -0.5 * gravity * t * t, 0)
            KillFx.rigid(body, pos, target, CFrame.Angles(tumble.X * t, tumble.Y * t, tumble.Z * t))
            streak.CFrame = CFrame.new(target)
            body.fade = math.clamp((progress - 0.7) / 0.3, 0, 1)
            KillFx.paint(body)
            if progress >= 1 then sparks.Enabled = false end
        end)
    end,
}

KillFx.fx["Black hole"] = {
    start = function(ev, corpse, pos, opts)
        local body = KillFx.body(ev, corpse)
        if #body.parts == 0 then return end
        local center = pos + Vector3.new(0, 3, 0)
        local core = KillFx.make(ev, "Part", {
            Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Shape = Enum.PartType.Ball,
            Material = Enum.Material.Neon, Color = BLACK, Transparency = 0, Size = Vector3.new(0.2, 0.2, 0.2), Position = center,
        })
        local holder = KillFx.anchor(ev, center, Vector3.new(10, 10, 10))
        local pull = KillFx.emitter(ev, holder, {
            Rate = math.floor(40 * opts.cint), Enabled = true, Lifetime = NumberRange.new(0.45, 0.55), Speed = NumberRange.new(9, 11),
            Size = KillFx.shrink(0.35), Color = ColorSequence.new(opts.color2, opts.color),
        })
        propSet(pull, "Shape", Enum.ParticleEmitterShape.Sphere)
        propSet(pull, "ShapeStyle", Enum.ParticleEmitterShapeStyle.Surface)
        propSet(pull, "ShapeInOut", Enum.ParticleEmitterShapeInOut.Inward)
        local blast = KillFx.emitter(ev, holder, {
            Lifetime = NumberRange.new(0.4, 0.9), Speed = NumberRange.new(20, 40), SpreadAngle = Vector2.new(180, 180), Drag = 3,
            Size = KillFx.shrink(0.5), Color = ColorSequence.new(WHITE, opts.color),
        })
        local count, points, beams = 16, {}, {}
        for index = 1, count do points[index] = KillFx.make(ev, "Attachment", {}, holder) end
        for index = 1, count do beams[index] = KillFx.beam(ev, holder, points[index], points[index % count + 1], opts.color, 0.4, 0.4) end
        local groups = {}
        for _, group in pairs(body.groups) do
            local start = group.cf.Position
            group.from = start - center
            group.turn = CFrame.new(-start) * group.cf
            group.delay = fxRand(0, 0.35)
            group.dir = math.random() < 0.5 and -1 or 1
            groups[#groups + 1] = group
        end
        local burst = false
        KillFx.drive(ev, corpse, body, opts.cdur, 1, function(t, progress)
            local pullK = math.clamp(progress / 0.85, 0, 1)
            for _, group in ipairs(groups) do
                local k = math.clamp((pullK - group.delay) / (1 - group.delay), 0, 1) ^ 2
                local spot = center + CFrame.Angles(0, k * math.pi * 3 * group.dir, 0) * (group.from * (1 - k))
                group.frame = CFrame.new(spot) * CFrame.Angles(k * 6, k * 9, 0) * group.turn
                group.sink = math.clamp((k - 0.75) / 0.25, 0, 1)
            end
            body.center = center
            KillFx.pose(body, function(item)
                item.sink = item.group.sink
                return item.group.frame * item.offset
            end)
            KillFx.paint(body)
            local grow = math.clamp(t / 0.4, 0, 1) * (1 - math.clamp((progress - 0.9) / 0.1, 0, 1))
            local size = 0.2 + 2.2 * grow * (1 + 0.08 * math.sin(t * 20))
            core.Size = Vector3.new(size, size, size)
            local radius = 4.5 * grow
            for index = 1, count do
                local angle = (index - 1) / count * math.pi * 2 + t * 4
                points[index].WorldPosition = center + Vector3.new(math.cos(angle) * radius, 0.15 * math.sin(angle * 2 + t * 6), math.sin(angle) * radius)
            end
            if progress >= 0.9 and not burst then
                burst = true
                pull.Enabled = false
                KillFx.burst(blast, 30 * opts.cint)
            end
        end)
    end,
}

KillFx.fx.Disintegrate = {
    start = function(ev, corpse, pos, opts)
        local body = KillFx.body(ev, corpse)
        local list = {}
        for _, item in ipairs(body.parts) do
            if type(item.alpha) == "number" and item.alpha < 1 then list[#list + 1] = item end
        end
        if #list == 0 then return end
        table.sort(list, function(a, b) return a.cf.Position.Y > b.cf.Position.Y end)
        local holder = KillFx.anchor(ev, pos)
        local wind = Vector3.new(fxRand(-1, 1), 0, fxRand(-1, 1))
        wind = (wind.Magnitude > 1e-3 and wind.Unit or Vector3.new(1, 0, 0)) * 6 + Vector3.new(0, 3, 0)
        for index, item in ipairs(list) do
            item.key = (index - 1) / #list * 0.6
            if index <= 12 then
                item.point = KillFx.make(ev, "Attachment", {}, holder)
                item.dust = KillFx.emitter(ev, item.point, {
                    Lifetime = NumberRange.new(0.8, 1.6), Speed = NumberRange.new(1, 4), SpreadAngle = Vector2.new(180, 180), Acceleration = wind, Drag = 0.5,
                    Size = KillFx.shrink(0.3), Color = ColorSequence.new(typeof(item.color) == "Color3" and item.color or opts.color, opts.color),
                })
            end
        end
        KillFx.drive(ev, corpse, body, opts.cdur, 1.6, function(t, progress)
            for _, item in ipairs(list) do
                local k = math.clamp((progress - item.key) / 0.4, 0, 1)
                if k > 0 and not item.burst then
                    item.burst = true
                    if item.point then
                        item.point.WorldPosition = item.at.Position
                        KillFx.burst(item.dust, 14 * opts.cint)
                    end
                end
                item.fade = k
            end
            KillFx.paint(body)
        end)
    end,
}

KillFx.fx.Ghost = {
    start = function(ev, corpse, pos, opts)
        local body = KillFx.body(ev, corpse)
        local ghosts, seen = {}, {}
        for _, item in ipairs(body.parts) do
            local size = PART_SIZES[item.name]
            if size and item.top and not seen[item.name] then
                seen[item.name] = true
                ghosts[#ghosts + 1] = { size = size, cf = item.cf, part = KillFx.make(ev, "Part", {
                    Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
                    Material = Enum.Material.ForceField, Color = opts.color, Transparency = 0, Size = size, CFrame = item.cf,
                }) }
            end
        end
        if #ghosts == 0 then return end
        local holder = KillFx.anchor(ev, pos, Vector3.new(2, 3, 1))
        local wisps = KillFx.emitter(ev, holder, {
            Rate = math.floor(10 * opts.cint), Enabled = true, Lifetime = NumberRange.new(0.8, 1.5), Speed = NumberRange.new(0.5, 1.5),
            EmissionDirection = Enum.NormalId.Bottom, Size = KillFx.shrink(0.3), Color = ColorSequence.new(opts.color2, opts.color),
        })
        local rise = math.max(4, opts.height * 0.6)
        ev.ticks[#ev.ticks + 1] = function(t)
            local progress = math.clamp(t / opts.cdur, 0, 1)
            local lift = Vector3.new(0.4 * math.sin(t * 3), rise * (1 - (1 - progress) ^ 2), 0)
            local stand = math.clamp(progress * 3, 0, 1)
            for _, ghost in ipairs(ghosts) do
                local spot = ghost.cf.Position
                local upright = CFrame.new(spot.X, pos.Y + (spot.Y - pos.Y) * (1 - stand), spot.Z)
                ghost.part.CFrame = CFrame.new(lift) * upright * CFrame.new(-spot) * ghost.cf
                ghost.part.Size = ghost.size * (1 + 0.25 * progress)
                ghost.part.Transparency = 0.15 + 0.85 * progress ^ 1.5
            end
            holder.CFrame = CFrame.new(pos + lift)
            if progress >= 0.8 then wisps.Enabled = false end
            return t >= opts.cdur + 0.6
        end
    end,
}

KillFx.fx.Freeze = {
    start = function(ev, corpse, pos, opts)
        local body = KillFx.body(ev, corpse)
        local list = {}
        for _, item in ipairs(body.parts) do
            if type(item.alpha) == "number" and item.alpha < 1 and typeof(item.color) == "Color3" then
                list[#list + 1] = { inst = item.inst, color = item.color, material = propGet(item.inst, "Material"), refl = propGet(item.inst, "Reflectance") }
            end
        end
        if #list == 0 then return end
        Corpse.owned[corpse] = true
        local finished, restored = false, false
        local function thaw()
            if restored then return end
            restored = true
            for _, item in ipairs(list) do
                Local.setIf(item.inst, "Material", item.material)
                Local.setIf(item.inst, "Color", item.color)
                Local.setIf(item.inst, "Reflectance", item.refl)
            end
            Corpse.release(corpse)
        end
        ev.undo[#ev.undo + 1] = function()
            if not finished then thaw() end
        end
        local holder = KillFx.anchor(ev, pos, Vector3.new(3, 5, 2))
        local frost = KillFx.emitter(ev, holder, {
            Rate = math.floor(10 * opts.cint), Enabled = true, Lifetime = NumberRange.new(1, 1.8), Speed = NumberRange.new(0.3, 1.2),
            SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, -2, 0), Size = KillFx.shrink(0.3), Color = ColorSequence.new(WHITE, KillFx.ice),
        })
        local mist = KillFx.emitter(ev, holder, {
            Texture = SMOKE, LightEmission = 0.3, Lifetime = NumberRange.new(1, 1.6), Speed = NumberRange.new(1, 3), SpreadAngle = Vector2.new(180, 180),
            Size = NumberSequence.new(1.5, 4), Transparency = NumberSequence.new(0.5, 1), Color = ColorSequence.new(KillFx.ice),
        })
        KillFx.burst(mist, 8 * opts.cint)
        KillFx.burst(frost, 20 * opts.cint)
        local shown = -1
        ev.ticks[#ev.ticks + 1] = function(t)
            if propGet(corpse, "Parent") == nil then
                finished, restored = true, true
                Corpse.release(corpse)
                return true
            end
            local k = math.clamp(t / 0.4, 0, 1)
            if k ~= shown and not finished then
                shown = k
                for _, item in ipairs(list) do
                    propSet(item.inst, "Material", Enum.Material.Ice)
                    propSet(item.inst, "Reflectance", 0.25)
                    propSet(item.inst, "Color", Util.lerpColor(item.color, KillFx.ice, k))
                end
            end
            holder.CFrame = CFrame.new(body.center or pos)
            if t >= opts.cdur and not finished then
                frost.Enabled = false
                finished = true
                KillFx.keep(corpse, thaw)
            end
            return t >= opts.cdur + 1.8
        end
    end,
}

KillFx.fx.Confetti = {
    start = function(ev, corpse, pos, opts)
        local holder = KillFx.anchor(ev, pos + Vector3.new(0, 1, 0))
        local colors = { opts.color, opts.color2, Color3.fromRGB(255, 90, 160), Color3.fromRGB(255, 220, 60), Color3.fromRGB(90, 230, 120), Color3.fromRGB(80, 160, 255) }
        local per = math.floor(math.min(25, 12 * opts.cint))
        for _, color in ipairs(colors) do
            local emitter = KillFx.emitter(ev, holder, {
                Lifetime = NumberRange.new(1.8, 3), Speed = NumberRange.new(18, 32), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(55, 55),
                Acceleration = Vector3.new(0, -22, 0), Drag = 1.5, RotSpeed = NumberRange.new(-360, 360), Size = NumberSequence.new(0.22),
                Color = ColorSequence.new(color), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.85, 0), NumberSequenceKeypoint.new(1, 1) }),
            })
            KillFx.burst(emitter, per)
        end
        ev.ticks[#ev.ticks + 1] = function(t) return t >= 3.2 end
    end,
}

function KillFx.copies(ev, body, props)
    local list, seen = {}, {}
    for _, item in ipairs(body.parts) do
        local size = PART_SIZES[item.name]
        if size and item.top and not seen[item.name] then
            seen[item.name] = true
            local base = { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Size = size, CFrame = item.cf }
            for key, value in pairs(props) do base[key] = value end
            list[#list + 1] = { size = size, cf = item.cf, turn = CFrame.new(-item.cf.Position) * item.cf, part = KillFx.make(ev, "Part", base) }
        end
    end
    return list
end

function KillFx.visible(body)
    local list = {}
    for _, item in ipairs(body.parts) do
        if type(item.alpha) == "number" and item.alpha < 1 then list[#list + 1] = item end
    end
    return list
end

function KillFx.solid(props)
    local base = { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false }
    for key, value in pairs(props) do base[key] = value end
    return base
end

KillFx.fx["Soul rip"] = {
    start = function(ev, corpse, pos, opts)
        local souls = KillFx.copies(ev, KillFx.body(ev, corpse), { Material = Enum.Material.ForceField, Color = opts.color2, Transparency = 0.1 })
        if #souls == 0 then return end
        local core = KillFx.anchor(ev, pos, Vector3.new(2, 3, 1))
        local base = KillFx.anchor(ev, pos)
        local tether = KillFx.beam(ev, base, KillFx.make(ev, "Attachment", {}, base), KillFx.make(ev, "Attachment", {}, core), opts.color, 0.6 * opts.int, 0.1)
        local wisps = KillFx.emitter(ev, core, {
            Rate = math.floor(16 * opts.int), Enabled = true, Lifetime = NumberRange.new(0.4, 0.9), Speed = NumberRange.new(0.5, 2),
            SpreadAngle = Vector2.new(180, 180), Size = KillFx.shrink(0.35), Color = ColorSequence.new(opts.color2, opts.color),
        })
        local length = 1.6
        ev.ticks[#ev.ticks + 1] = function(t)
            local eye = propGet(ev.root, "CFrame")
            local target = typeof(eye) == "CFrame" and eye.Position + eye.LookVector * 3 - Vector3.new(0, 1, 0) or pos + Vector3.new(0, 12, 0)
            local rise = math.clamp(t / 0.45, 0, 1)
            local pull = math.clamp((t - 0.45) / (length - 0.45), 0, 1) ^ 2
            local lifted = pos + Vector3.new(0, 3 * (1 - (1 - rise) ^ 2), 0)
            local center = lifted + (target - lifted) * pull
            local scale = 1 - 0.85 * pull
            for _, soul in ipairs(souls) do
                soul.part.CFrame = CFrame.new(center + (soul.cf.Position - pos) * scale) * soul.turn
                soul.part.Size = soul.size * scale
                soul.part.Transparency = 0.1 + 0.9 * pull ^ 1.5
            end
            core.CFrame = CFrame.new(center)
            tether.Transparency = NumberSequence.new(math.clamp(0.2 + pull, 0, 1))
            if t >= length then wisps.Enabled = false end
            return t >= length + 0.6
        end
    end,
}

KillFx.fx.Pixelate = {
    start = function(ev, corpse, pos, opts)
        local body = KillFx.body(ev, corpse)
        local sources = KillFx.visible(body)
        if #sources == 0 then return end
        local cap = math.floor(math.clamp(36 * opts.int, 12, 64))
        local per, cubes = math.max(1, math.floor(cap / #sources)), {}
        for _, item in ipairs(sources) do
            local size = PART_SIZES[item.name] or propGet(item.inst, "Size")
            if typeof(size) ~= "Vector3" then size = Vector3.new(1, 1, 1) end
            local color = typeof(item.color) == "Color3" and item.color or opts.color
            for _ = 1, per do
                if #cubes >= cap then break end
                local at = item.cf:PointToWorldSpace(Vector3.new(fxRand(-0.5, 0.5) * size.X, fxRand(-0.5, 0.5) * size.Y, fxRand(-0.5, 0.5) * size.Z))
                local away = at - pos
                away = away.Magnitude > 1e-3 and away.Unit or Vector3.new(0, 1, 0)
                local edge = fxRand(0.25, 0.45)
                cubes[#cubes + 1] = {
                    at = at, vel = away * fxRand(6, 14) * opts.int + Vector3.new(0, fxRand(6, 12), 0), spin = Vector3.new(fxRand(-8, 8), fxRand(-8, 8), 0), edge = edge,
                    part = KillFx.make(ev, "Part", KillFx.solid({ Material = Enum.Material.SmoothPlastic, Color = Util.lerpColor(color, opts.color, math.random() * 0.5), Size = Vector3.new(edge, edge, edge), CFrame = CFrame.new(at) })),
                }
            end
        end
        KillFx.drive(ev, corpse, body, 1.6, 0.1, function(t, progress)
            body.fade = 1
            KillFx.paint(body)
            for _, cube in ipairs(cubes) do
                local spot = cube.at + cube.vel * t + Vector3.new(0, -20 * t * t, 0)
                cube.part.CFrame = CFrame.new(spot) * CFrame.Angles(cube.spin.X * t, cube.spin.Y * t, 0)
                cube.part.Transparency = progress ^ 2
            end
        end)
    end,
}

KillFx.fx.Glitch = {
    start = function(ev, corpse, pos, opts)
        local body = KillFx.body(ev, corpse)
        local layers = {}
        for index, tint in ipairs({ Color3.fromRGB(255, 40, 60), Color3.fromRGB(40, 255, 120), Color3.fromRGB(60, 120, 255) }) do
            local copies = KillFx.copies(ev, body, { Material = Enum.Material.Neon, Color = tint, Transparency = 0.45 })
            if #copies == 0 then return end
            layers[index] = copies
        end
        local frame = -1
        KillFx.drive(ev, corpse, body, 0.9, 0.1, function(t, progress)
            local step = math.floor(t / 0.05)
            if step == frame and progress < 1 then return end
            frame = step
            local spread = 0.6 * opts.int * (1 - progress * 0.5)
            for index, copies in ipairs(layers) do
                local shift = Vector3.new(fxRand(-spread, spread) + (index - 2) * 0.25 * opts.int, fxRand(-spread, spread) * 0.4, fxRand(-spread, spread))
                local gone = progress >= 1 or (progress > 0.6 and math.random() < progress)
                for _, copy in ipairs(copies) do
                    copy.part.CFrame = CFrame.new(shift) * copy.cf
                    copy.part.Transparency = gone and 1 or 0.45 + 0.4 * progress
                end
            end
            body.fade = (progress > 0.7 or math.random() < 0.5) and 1 or 0
            KillFx.paint(body)
        end)
    end,
}

KillFx.fx.Tombstone = {
    start = function(ev, corpse, pos, opts)
        local ground = KillFx.ground(pos)
        local eye = propGet(ev.root, "CFrame")
        local face = typeof(eye) == "CFrame" and Vector3.new(eye.Position.X - ground.X, 0, eye.Position.Z - ground.Z) or Vector3.new(0, 0, 1)
        face = face.Magnitude > 1e-3 and face.Unit or Vector3.new(0, 0, 1)
        local spot = ground - face * 1.4
        local base = CFrame.new(spot, spot + face)
        local stone = Color3.fromRGB(120, 124, 132)
        local slab = KillFx.make(ev, "Part", KillFx.solid({ Material = Enum.Material.Slate, Color = stone, Size = Vector3.new(2.2, 3, 0.5), CFrame = base }))
        local cap = KillFx.make(ev, "Part", KillFx.solid({ Material = Enum.Material.Slate, Color = stone, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 2.2, 2.2), CFrame = base }))
        local gui = KillFx.make(ev, "SurfaceGui", { Face = Enum.NormalId.Front, LightInfluence = 0, CanvasSize = Vector2.new(220, 300) }, slab)
        local name = tostring(propGet(LocalPlayer, "DisplayName") or propGet(LocalPlayer, "Name") or "")
        KillFx.make(ev, "TextLabel", {
            Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "R.I.P.\n" .. name, TextScaled = true, Font = Enum.Font.GothamBold,
            TextColor3 = opts.color2, TextStrokeTransparency = 0.4, TextStrokeColor3 = opts.color,
        }, gui)
        local dust = KillFx.emitter(ev, KillFx.anchor(ev, spot), {
            Texture = SMOKE, LightEmission = 0.2, LightInfluence = 0.6, Lifetime = NumberRange.new(0.6, 1.2), Speed = NumberRange.new(2, 5),
            SpreadAngle = Vector2.new(180, 20), Drag = 3, Size = NumberSequence.new(0.8, 2), Transparency = NumberSequence.new(0.5, 1), Color = ColorSequence.new(stone),
        })
        KillFx.burst(dust, 10 * opts.int)
        local hold = math.max(1.5, opts.dur)
        ev.ticks[#ev.ticks + 1] = function(t)
            local rise = math.clamp(t / 0.35, 0, 1)
            local lift = -3.4 * (1 - rise) + 0.35 * math.sin(rise * math.pi)
            if t > hold then lift = lift - 3.4 * math.clamp((t - hold) / 0.5, 0, 1) end
            slab.CFrame = base * CFrame.new(0, 1.5 + lift, 0)
            cap.CFrame = base * CFrame.new(0, 3 + lift, 0) * CFrame.Angles(0, math.pi / 2, 0)
            return t >= hold + 0.6
        end
    end,
}

KillFx.fx["Blackout ring"] = {
    start = function(ev, corpse, pos, opts)
        local ground = KillFx.ground(pos)
        local holder = KillFx.anchor(ev, ground)
        local count, points, dark, rim = 32, {}, {}, {}
        for index = 1, count do points[index] = KillFx.make(ev, "Attachment", {}, holder) end
        for index = 1, count do
            dark[index] = KillFx.beam(ev, holder, points[index], points[index % count + 1], BLACK, 3, 3)
            dark[index].LightEmission = 0
            rim[index] = KillFx.beam(ev, holder, points[index], points[index % count + 1], opts.color, 0.3, 0.3)
        end
        local shell = KillFx.make(ev, "Part", KillFx.solid({ Shape = Enum.PartType.Ball, Material = Enum.Material.SmoothPlastic, Color = BLACK, Transparency = 0.3, Size = Vector3.new(2, 2, 2), Position = pos }))
        local eye = propGet(ev.root, "CFrame")
        local grade = nil
        if not (typeof(eye) == "CFrame" and (eye.Position - pos).Magnitude > opts.flashDist) then
            grade = KillFx.make(ev, "ColorCorrectionEffect", { Saturation = 0, Contrast = 0, Brightness = 0, TintColor = WHITE }, ev.root)
        end
        local reach, length = 40 * (0.7 + 0.3 * opts.int), 1.1
        ev.ticks[#ev.ticks + 1] = function(t)
            local progress = math.clamp(t / length, 0, 1)
            local radius = Util.lerp(2, reach, 1 - (1 - progress) ^ 2)
            local fade = NumberSequence.new(progress)
            local width = 0.5 + 4 * opts.int * (1 - progress)
            for index = 1, count do
                local angle = (index - 1) / count * math.pi * 2
                points[index].WorldPosition = ground + Vector3.new(math.cos(angle) * radius, 0.3, math.sin(angle) * radius)
                dark[index].Width0, dark[index].Width1, dark[index].Transparency = width, width, fade
                rim[index].Transparency = fade
            end
            local across = Util.lerp(2, 14, progress)
            shell.Size, shell.Transparency = Vector3.new(across, across, across), Util.lerp(0.3, 1, progress)
            if grade then
                local pulse = math.sin(math.pi * progress) * math.min(opts.int, 1.2)
                grade.Saturation, grade.Contrast, grade.Brightness = -0.85 * pulse, 0.25 * pulse, -0.12 * pulse
                grade.TintColor = Util.lerpColor(WHITE, Color3.fromRGB(200, 200, 215), pulse)
            end
            return progress >= 1
        end
    end,
}

KillFx.fx.Firework = {
    start = function(ev, corpse, pos, opts)
        local rockets = {}
        for index = 1, math.clamp(math.floor(3 * opts.int + 0.5), 2, 6) do
            local holder = KillFx.anchor(ev, pos)
            rockets[index] = {
                holder = holder, delay = (index - 1) * 0.18, height = fxRand(22, 34), drift = Vector3.new(fxRand(-6, 6), 0, fxRand(-6, 6)),
                trail = KillFx.emitter(ev, holder, {
                    Rate = 40, Enabled = true, Lifetime = NumberRange.new(0.3, 0.6), Speed = NumberRange.new(0.5, 2), SpreadAngle = Vector2.new(20, 20),
                    EmissionDirection = Enum.NormalId.Bottom, Size = KillFx.shrink(0.4), Color = ColorSequence.new(WHITE, opts.color2),
                }),
                burst = KillFx.emitter(ev, holder, {
                    Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(20, 34), SpreadAngle = Vector2.new(180, 180), Drag = 2.5,
                    Acceleration = Vector3.new(0, -12, 0), Size = KillFx.shrink(0.55), Color = ColorSequence.new(index % 2 == 1 and opts.color or opts.color2, WHITE),
                }),
                light = KillFx.make(ev, "PointLight", { Color = opts.color, Brightness = 0, Range = 40 }, holder),
            }
        end
        local flight = 0.7
        ev.ticks[#ev.ticks + 1] = function(t)
            for _, rocket in ipairs(rockets) do
                local age = t - rocket.delay
                if age > 0 then
                    local k = math.clamp(age / flight, 0, 1)
                    if not rocket.popped then
                        rocket.holder.CFrame = CFrame.new(pos + Vector3.new(0, rocket.height * (1 - (1 - k) ^ 2), 0) + rocket.drift * k)
                        if k >= 1 then
                            rocket.popped = true
                            rocket.trail.Enabled = false
                            KillFx.burst(rocket.burst, math.min(80, 50 * opts.int))
                        end
                    else
                        rocket.light.Brightness = 6 * opts.int * math.max(0, 1 - (age - flight) / 0.5)
                    end
                end
            end
            return t >= 3
        end
    end,
}

KillFx.fx.Crystallize = {
    start = function(ev, corpse, pos, opts)
        local body = KillFx.body(ev, corpse)
        local list = {}
        for _, item in ipairs(KillFx.visible(body)) do
            if typeof(item.color) == "Color3" then
                list[#list + 1] = { inst = item.inst, at = item.cf.Position, color = item.color, material = propGet(item.inst, "Material"), refl = propGet(item.inst, "Reflectance") }
            end
        end
        if #list == 0 then return end
        Corpse.owned[corpse] = true
        local finished, restored, shattered = false, false, false
        local function restore()
            if restored then return end
            restored = true
            for _, item in ipairs(list) do
                Local.setIf(item.inst, "Material", item.material)
                Local.setIf(item.inst, "Color", item.color)
                Local.setIf(item.inst, "Reflectance", item.refl)
            end
            Corpse.release(corpse)
        end
        ev.undo[#ev.undo + 1] = function()
            if not finished then restore() end
        end
        local crystal = Util.lerpColor(opts.color2, opts.color, 0.35)
        local holder = KillFx.anchor(ev, pos, Vector3.new(3, 5, 2))
        local glints = KillFx.emitter(ev, holder, {
            Rate = math.floor(12 * opts.int), Enabled = true, Lifetime = NumberRange.new(0.3, 0.7), Speed = NumberRange.new(0.2, 1),
            SpreadAngle = Vector2.new(180, 180), Size = KillFx.shrink(0.35), Color = ColorSequence.new(WHITE, crystal),
        })
        local shards, length = {}, math.max(1.4, opts.dur * 0.7)
        local shatterAt, shown = length * 0.55, -1
        KillFx.drive(ev, corpse, body, length, 0.2, function(t, progress)
            local k = math.clamp(t / 0.35, 0, 1)
            if k ~= shown then
                shown = k
                for _, item in ipairs(list) do
                    propSet(item.inst, "Material", Enum.Material.Glass)
                    propSet(item.inst, "Reflectance", 0.6)
                    propSet(item.inst, "Color", Util.lerpColor(item.color, crystal, k))
                end
            end
            if t >= shatterAt and not shattered then
                shattered = true
                body.fade = 1
                glints.Enabled = false
                for index = 1, math.floor(math.clamp(18 * opts.int, 8, 30)) do
                    local from = list[(index - 1) % #list + 1].at + Vector3.new(fxRand(-0.6, 0.6), fxRand(-0.8, 0.8), fxRand(-0.6, 0.6))
                    local away = from - pos
                    away = away.Magnitude > 1e-3 and away.Unit or Vector3.new(0, 1, 0)
                    shards[index] = {
                        at = from, vel = away * fxRand(8, 16) + Vector3.new(0, fxRand(4, 10), 0), spin = Vector3.new(fxRand(-10, 10), fxRand(-10, 10), fxRand(-10, 10)),
                        part = KillFx.make(ev, "Part", KillFx.solid({ Material = Enum.Material.Glass, Color = crystal, Reflectance = 0.5, Transparency = 0.2,
                            Size = Vector3.new(fxRand(0.15, 0.35), fxRand(0.5, 1.1), fxRand(0.15, 0.35)), CFrame = CFrame.new(from) })),
                    }
                end
            end
            if shattered then
                local age = t - shatterAt
                local fade = math.clamp(age / (length - shatterAt), 0, 1)
                for _, shard in ipairs(shards) do
                    shard.part.CFrame = CFrame.new(shard.at + shard.vel * age + Vector3.new(0, -25 * age * age, 0)) * CFrame.Angles(shard.spin.X * age, shard.spin.Y * age, shard.spin.Z * age)
                    shard.part.Transparency = 0.2 + 0.8 * fade
                end
            end
            KillFx.paint(body)
            if progress >= 1 and not finished then
                finished = true
                KillFx.keep(corpse, restore)
            end
        end)
    end,
}

KillFx.fx["Holo-scan"] = {
    start = function(ev, corpse, pos, opts)
        local body = KillFx.body(ev, corpse)
        local list = KillFx.visible(body)
        if #list == 0 then return end
        local low, high = math.huge, -math.huge
        for _, item in ipairs(list) do
            local y = item.cf.Position.Y
            low, high = math.min(low, y), math.max(high, y)
        end
        low, high = low - 1.2, high + 1.2
        local plane = KillFx.make(ev, "Part", KillFx.solid({ Material = Enum.Material.Neon, Color = opts.color, Transparency = 0.35, Size = Vector3.new(5, 0.06, 5), CFrame = CFrame.new(pos.X, high, pos.Z) }))
        KillFx.make(ev, "SelectionBox", { Adornee = plane, Color3 = opts.color2, LineThickness = 0.03, SurfaceTransparency = 1 }, plane)
        local motes = KillFx.emitter(ev, plane, {
            Rate = math.floor(30 * opts.int), Enabled = true, Lifetime = NumberRange.new(0.4, 0.8), Speed = NumberRange.new(0.5, 1.5),
            SpreadAngle = Vector2.new(180, 180), Size = KillFx.shrink(0.2), Color = ColorSequence.new(opts.color2, opts.color),
        })
        KillFx.drive(ev, corpse, body, math.max(1.2, opts.dur * 0.8), 0.3, function(t, progress)
            local y
            if progress < 0.4 then
                y = high + (low - high) * (progress / 0.4)
            else
                y = low + (high - low) * ((progress - 0.4) / 0.6)
                for _, item in ipairs(list) do item.fade = math.clamp((y - item.cf.Position.Y) / 0.8, 0, 1) end
            end
            plane.CFrame = CFrame.new(pos.X, y, pos.Z)
            if progress >= 1 then
                plane.Transparency = 1
                motes.Enabled = false
                for _, item in ipairs(list) do item.fade = 1 end
            end
            KillFx.paint(body)
        end)
    end,
}

KillFx.fx["Anime slash"] = {
    start = function(ev, corpse, pos, opts)
        local camera = ev.root
        local eye = propGet(camera, "CFrame")
        if typeof(eye) == "CFrame" and (eye.Position - pos).Magnitude > opts.flashDist then return end
        local gui = Chams.getContainer()
        if not gui then return end
        local okPoint, point = pcall(camera.WorldToViewportPoint, camera, pos)
        if not (okPoint and typeof(point) == "Vector3" and point.Z > 0) then return end
        local angle = fxRand(-35, 35)
        local flash = KillFx.make(ev, "Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 0.25, BorderSizePixel = 0, ZIndex = 1000 }, gui)
        local slashes = {}
        for index, color in ipairs({ opts.color, WHITE }) do
            slashes[index] = KillFx.make(ev, "Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(point.X, point.Y), Size = UDim2.fromOffset(0, 0), Rotation = angle,
                BackgroundColor3 = color, BackgroundTransparency = 0, BorderSizePixel = 0, ZIndex = 1000 + index,
            }, gui)
        end
        local length = 900 * math.clamp(opts.int, 0.5, 1.5)
        ev.ticks[#ev.ticks + 1] = function(t)
            local reach = math.clamp(t / 0.08, 0, 1)
            local thin = math.clamp((t - 0.12) / 0.25, 0, 1)
            for index, slash in ipairs(slashes) do
                slash.Size = UDim2.fromOffset(length * reach, (index == 1 and 22 or 8) * (1 - thin))
                slash.BackgroundTransparency = index == 1 and 0.3 + 0.7 * thin or thin
            end
            flash.BackgroundTransparency = 0.25 + 0.75 * math.clamp(t / 0.18, 0, 1)
            return t >= 0.4
        end
    end,
}

function KillFx.skin(ev, corpse, items)
    local list = {}
    for _, item in ipairs(items) do
        if typeof(item.color) == "Color3" then
            list[#list + 1] = { inst = item.inst, color = item.color, material = propGet(item.inst, "Material"), refl = propGet(item.inst, "Reflectance") }
        end
    end
    if #list == 0 then return nil end
    Corpse.owned[corpse] = true
    local skin = { list = list, finished = false, restored = false }
    function skin.restore()
        if skin.restored then return end
        skin.restored = true
        for _, entry in ipairs(list) do
            Local.setIf(entry.inst, "Material", entry.material)
            Local.setIf(entry.inst, "Color", entry.color)
            Local.setIf(entry.inst, "Reflectance", entry.refl)
        end
        Corpse.release(corpse)
    end
    function skin.paint(material, refl, color, k)
        if k == skin.shown then return end
        skin.shown = k
        for _, entry in ipairs(list) do
            propSet(entry.inst, "Material", material)
            propSet(entry.inst, "Reflectance", refl)
            propSet(entry.inst, "Color", Util.lerpColor(entry.color, color(entry.color), k))
        end
    end
    function skin.finish()
        if skin.finished then return end
        skin.finished = true
        KillFx.keep(corpse, skin.restore)
    end
    ev.undo[#ev.undo + 1] = function()
        if not skin.finished then skin.restore() end
    end
    return skin
end

function KillFx.groupList(body)
    local list = {}
    for top, group in pairs(body.groups) do
        local start = group.cf.Position
        group.start, group.turn, group.name = start, CFrame.new(-start) * group.cf, propGet(top, "Name")
        list[#list + 1] = group
    end
    table.sort(list, function(a, b) return a.start.Y > b.start.Y end)
    return list
end

function KillFx.posed(body)
    KillFx.pose(body, function(item) return item.group.frame * item.offset end)
end

function KillFx.flat(vector, fallback)
    local level = Vector3.new(vector.X, 0, vector.Z)
    return level.Magnitude > 1e-3 and level.Unit or fallback
end

function KillFx.noise(ev, holder, id, volume)
    return KillFx.make(ev, "Sound", { SoundId = id, Volume = volume }, holder)
end

KillFx.fx.Melt = {
    start = function(ev, corpse, pos, opts)
        local body = KillFx.body(ev, corpse)
        if #body.parts == 0 then return end
        local ground = KillFx.ground(pos)
        local hot = Util.lerpColor(opts.color, Color3.fromRGB(255, 140, 50), 0.5)
        local flat = CFrame.new(ground + Vector3.new(0, 0.04, 0)) * CFrame.Angles(0, 0, math.pi / 2)
        local puddle = KillFx.make(ev, "Part", KillFx.solid({
            Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Color = hot, Transparency = 0.2, Size = Vector3.new(0.08, 0.2, 0.2), CFrame = flat,
        }))
        local light = KillFx.make(ev, "PointLight", { Color = hot, Brightness = 0, Range = 12 }, puddle)
        local steam = KillFx.emitter(ev, puddle, {
            Texture = SMOKE, LightEmission = 0.4, Rate = math.floor(10 * opts.cint), Enabled = true, Lifetime = NumberRange.new(0.8, 1.6), Speed = NumberRange.new(1, 3),
            EmissionDirection = Enum.NormalId.Right, SpreadAngle = Vector2.new(25, 25), Size = NumberSequence.new(0.6, 2), Transparency = NumberSequence.new(0.6, 1), Color = ColorSequence.new(hot),
        })
        local drips = KillFx.emitter(ev, puddle, {
            Rate = math.floor(16 * opts.cint), Enabled = true, Lifetime = NumberRange.new(0.3, 0.7), Speed = NumberRange.new(1, 3),
            EmissionDirection = Enum.NormalId.Right, SpreadAngle = Vector2.new(60, 60), Acceleration = Vector3.new(0, -12, 0), Size = KillFx.shrink(0.2), Color = ColorSequence.new(WHITE, hot),
        })
        local floor = ground.Y - 0.6
        KillFx.drive(ev, corpse, body, opts.cdur, 0.4, function(t, progress)
            local k = progress ^ 1.4
            KillFx.pose(body, function(item)
                local at = item.cf.Position
                item.sink = math.clamp((k - 0.55) / 0.4, 0, 1)
                local spread = Vector3.new(at.X - pos.X, 0, at.Z - pos.Z) * (0.5 * k)
                return CFrame.new(spread + Vector3.new(0, (floor - at.Y) * k, 0)) * item.cf
            end)
            KillFx.paint(body)
            local wide = math.clamp(progress / 0.5, 0, 1) * (1 - math.clamp((progress - 0.85) / 0.15, 0, 1))
            local across = 0.2 + 5.5 * (1 - (1 - wide) ^ 2)
            puddle.Size = Vector3.new(0.08, across, across)
            puddle.Transparency = 0.2 + 0.8 * (1 - wide)
            light.Brightness = 2.5 * wide
            if progress >= 0.85 then steam.Enabled, drips.Enabled = false, false end
        end)
    end,
}

KillFx.fx.Spaghettify = {
    start = function(ev, corpse, pos, opts)
        local body = KillFx.body(ev, corpse)
        if #body.parts == 0 then return end
        local side = KillFx.flat(Vector3.new(fxRand(-1, 1), 0, fxRand(-1, 1)), Vector3.new(1, 0, 0))
        local point = pos + side * (4 + opts.height * 0.4) + Vector3.new(0, 2.5, 0)
        local core = KillFx.make(ev, "Part", KillFx.solid({
            Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Color = BLACK, Transparency = 0, Size = Vector3.new(0.2, 0.2, 0.2), Position = point,
        }))
        local swirl = KillFx.emitter(ev, KillFx.anchor(ev, point, Vector3.new(5, 5, 5)), {
            Rate = math.floor(30 * opts.cint), Enabled = true, Lifetime = NumberRange.new(0.35, 0.45), Speed = NumberRange.new(9, 11),
            Size = KillFx.shrink(0.25), Color = ColorSequence.new(opts.color2, opts.color),
        })
        propSet(swirl, "Shape", Enum.ParticleEmitterShape.Sphere)
        propSet(swirl, "ShapeStyle", Enum.ParticleEmitterShapeStyle.Surface)
        propSet(swirl, "ShapeInOut", Enum.ParticleEmitterShapeInOut.Inward)
        for _, item in ipairs(body.parts) do
            local from = item.cf.Position
            item.delay = math.clamp((from - point).Magnitude / 40, 0, 0.3)
            item.aim = (point - from).Magnitude > 0.05 and CFrame.new(Vector3.zero, point - from) or CFrame.new()
        end
        KillFx.drive(ev, corpse, body, opts.cdur, 0.4, function(t, progress)
            KillFx.pose(body, function(item)
                local k = math.clamp((progress - item.delay) / (1 - item.delay), 0, 1) ^ 2
                local from = item.cf.Position
                local spot = from + (point - from) * k
                local thin = math.max(0.08, 1 - 0.85 * k)
                if item.size then KillFx.resize(item, Vector3.new(item.size.X * thin, item.size.Y * thin, item.size.Z * (1 + 7 * k * (1 - k) * 2))) end
                item.sink = math.clamp(1 - (1 - k) / 0.2, 0, 1)
                if k < 0.15 then return CFrame.new(spot - from) * item.cf end
                return CFrame.new(spot) * item.aim
            end)
            KillFx.paint(body)
            local size = 0.2 + 1.4 * math.clamp(t / 0.4, 0, 1) * (1 - math.clamp((progress - 0.9) / 0.1, 0, 1))
            core.Size = Vector3.new(size, size, size)
            if progress >= 0.9 then swirl.Enabled = false end
        end)
    end,
}

KillFx.fx.Balloon = {
    start = function(ev, corpse, pos, opts)
        local body = KillFx.body(ev, corpse)
        if #body.parts == 0 then return end
        local holder = KillFx.anchor(ev, pos, Vector3.new(3, 4, 2))
        local burst = KillFx.emitter(ev, holder, {
            Lifetime = NumberRange.new(0.3, 0.7), Speed = NumberRange.new(18, 30), SpreadAngle = Vector2.new(180, 180), Drag = 4,
            Size = KillFx.shrink(0.45), Color = ColorSequence.new(opts.color, opts.color2),
        })
        local pop = KillFx.noise(ev, holder, HIT_SOUNDS["Bubble Pop"], 1.2)
        local phase, popped = fxRand(0, math.pi * 2), false
        KillFx.drive(ev, corpse, body, opts.cdur, 0.6, function(t, progress)
            local swell = math.clamp(progress / 0.6, 0, 1)
            local wobble = progress > 0.7 and 0.12 * math.sin(t * 45) * (progress - 0.7) / 0.3 or 0
            local grow = 1 + 0.9 * (1 - (1 - swell) ^ 2) + wobble
            local rise = opts.height * math.clamp((progress - 0.2) / 0.8, 0, 1) ^ 1.5
            local center = pos + Vector3.new(0.6 * math.sin(t * 1.7 + phase), rise, 0.6 * math.cos(t * 1.3 + phase))
            body.center = center
            KillFx.pose(body, function(item)
                if item.size then KillFx.resize(item, item.size * grow) end
                local at = item.cf.Position
                return CFrame.new(center + (at - pos) * grow - at) * item.cf
            end)
            holder.CFrame = CFrame.new(center)
            if progress >= 0.92 and not popped then
                popped = true
                body.fade = 1
                KillFx.burst(burst, 40 * opts.cint)
                pcall(pop.Play, pop)
            end
            KillFx.paint(body)
        end)
    end,
}

KillFx.fx.Orbit = {
    start = function(ev, corpse, pos, opts)
        local body = KillFx.body(ev, corpse)
        if #body.parts == 0 then return end
        local core, limbs = nil, {}
        for _, group in ipairs(KillFx.groupList(body)) do
            if group.name == "Torso" and not core then core = group else limbs[#limbs + 1] = group end
        end
        local base = core and core.start or pos
        for index, group in ipairs(limbs) do
            group.angle = (index - 1) / math.max(#limbs, 1) * math.pi * 2
            group.radius = 3 + fxRand(0, 1.2)
            group.tilt = fxRand(-0.4, 0.4)
            group.spin = Vector3.new(fxRand(-3, 3), fxRand(-3, 3), fxRand(-3, 3))
        end
        local holder = KillFx.anchor(ev, base, Vector3.new(6, 2, 6))
        local trail = KillFx.emitter(ev, holder, {
            Rate = math.floor(24 * opts.cint), Enabled = true, Lifetime = NumberRange.new(0.5, 1), Speed = NumberRange.new(0.2, 0.8),
            SpreadAngle = Vector2.new(180, 180), Size = KillFx.shrink(0.25), Color = ColorSequence.new(opts.color2, opts.color),
        })
        propSet(trail, "Shape", Enum.ParticleEmitterShape.Cylinder)
        propSet(trail, "ShapeStyle", Enum.ParticleEmitterShapeStyle.Surface)
        local rise = math.min(opts.height * 0.3, 3)
        KillFx.drive(ev, corpse, body, opts.cdur, 0.5, function(t, progress)
            local free = math.clamp(progress / 0.2, 0, 1)
            free = free * free * (3 - 2 * free)
            local center = base + Vector3.new(0, rise * (1 - (1 - progress) ^ 2), 0)
            body.center = center
            if core then core.frame = CFrame.new(center) * CFrame.Angles(0, t * 0.8 * free, 0) * core.turn end
            for _, group in ipairs(limbs) do
                local angle = group.angle + t * 2.4 * (1 + progress)
                local ring = center + Vector3.new(math.cos(angle) * group.radius, math.sin(angle * 2) * group.tilt * group.radius, math.sin(angle) * group.radius)
                local spot = group.start + (ring - group.start) * free
                group.frame = CFrame.new(spot) * CFrame.Angles(group.spin.X * t * free, group.spin.Y * t * free, group.spin.Z * t * free) * group.turn
            end
            KillFx.posed(body)
            holder.CFrame = CFrame.new(center)
            body.fade = math.clamp(1 - (1 - progress) / 0.2, 0, 1)
            KillFx.paint(body)
            if progress >= 0.85 then trail.Enabled = false end
        end)
    end,
}

KillFx.fx["Glass shatter"] = {
    start = function(ev, corpse, pos, opts)
        local body = KillFx.body(ev, corpse)
        local skin = KillFx.skin(ev, corpse, KillFx.visible(body))
        if not skin then return end
        local glass = Util.lerpColor(opts.color2, KillFx.ice, 0.5)
        local floor = KillFx.ground(pos).Y + 0.3
        local holder = KillFx.anchor(ev, pos, Vector3.new(3, 4, 2))
        local chips = KillFx.emitter(ev, holder, {
            Lifetime = NumberRange.new(0.5, 1), Speed = NumberRange.new(6, 14), SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, -30, 0),
            RotSpeed = NumberRange.new(-360, 360), Size = KillFx.shrink(0.25), Color = ColorSequence.new(WHITE, glass),
        })
        local tink = KillFx.noise(ev, holder, HIT_SOUNDS["Glass Tink"], 1.2)
        local groups = KillFx.groupList(body)
        for _, group in ipairs(groups) do
            local away = KillFx.flat(group.start - pos, KillFx.flat(Vector3.new(fxRand(-1, 1), 0, fxRand(-1, 1)), Vector3.new(1, 0, 0)))
            group.vel = away * fxRand(2, 5) + Vector3.new(0, fxRand(1, 4), 0)
            group.spin = Vector3.new(fxRand(-6, 6), fxRand(-6, 6), fxRand(-6, 6))
        end
        local hold, cracked = math.min(0.5, opts.cdur * 0.2), false
        KillFx.drive(ev, corpse, body, opts.cdur, 0.6, function(t, progress)
            skin.paint(Enum.Material.Glass, 0.4, function() return glass end, math.clamp(t / 0.3, 0, 1))
            local age = t - hold
            if age >= 0 and not cracked then
                cracked = true
                KillFx.burst(chips, 24 * opts.cint)
                pcall(tink.Play, tink)
            end
            for _, group in ipairs(groups) do
                local spot, turn = group.start, 0
                if age > 0 then
                    spot = spot + group.vel * age + Vector3.new(0, -30 * age * age, 0)
                    if spot.Y < floor then spot = Vector3.new(spot.X, floor, spot.Z) end
                    turn = math.min(age, 0.6)
                end
                group.frame = CFrame.new(spot) * CFrame.Angles(group.spin.X * turn, group.spin.Y * turn, group.spin.Z * turn) * group.turn
            end
            KillFx.posed(body)
            body.fade = math.clamp((progress - 0.75) / 0.25, 0, 1)
            KillFx.paint(body)
            if progress >= 1 then skin.finish() end
        end)
    end,
}

KillFx.fx.Magnetize = {
    start = function(ev, corpse, pos, opts)
        local body = KillFx.body(ev, corpse)
        if #body.parts == 0 then return end
        local groups = KillFx.groupList(body)
        local center, cell = pos + Vector3.new(0, 1.5, 0), 0.9
        local side = math.max(1, math.ceil((#groups) ^ (1 / 3) - 1e-9))
        local middle = Vector3.new(side - 1, side - 1, side - 1) * 0.5
        for index, group in ipairs(groups) do
            local slot = index - 1
            group.slot = center + (Vector3.new(slot % side, math.floor(slot / side) % side, math.floor(slot / (side * side))) - middle) * cell
            group.delay = (index - 1) / #groups * 0.3
        end
        local box = KillFx.anchor(ev, center, Vector3.new(side * cell + 0.2, side * cell + 0.2, side * cell + 0.2))
        local outline = KillFx.make(ev, "SelectionBox", { Adornee = box, Color3 = opts.color, LineThickness = 0.05, SurfaceTransparency = 1, Transparency = 1 }, box)
        local sparks = KillFx.emitter(ev, box, {
            Lifetime = NumberRange.new(0.2, 0.5), Speed = NumberRange.new(6, 12), SpreadAngle = Vector2.new(180, 180), Size = KillFx.shrink(0.25), Color = ColorSequence.new(WHITE, opts.color),
        })
        local dust = KillFx.emitter(ev, box, {
            Lifetime = NumberRange.new(0.6, 1.2), Speed = NumberRange.new(1, 3), SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, 3, 0),
            Size = KillFx.shrink(0.3), Color = ColorSequence.new(opts.color2, opts.color),
        })
        local snapped, dissolving = false, false
        KillFx.drive(ev, corpse, body, opts.cdur, 0.5, function(t, progress)
            local pull = math.clamp(progress / 0.45, 0, 1)
            for _, group in ipairs(groups) do
                local k = math.clamp((pull - group.delay) / (1 - group.delay), 0, 1) ^ 3
                if k >= 1 then
                    local shake = progress < 0.6 and Vector3.new(fxRand(-0.04, 0.04), fxRand(-0.04, 0.04), fxRand(-0.04, 0.04)) or Vector3.zero
                    group.frame = CFrame.new(group.slot + shake)
                    group.locked = true
                else
                    group.frame = CFrame.new(group.start + (group.slot - group.start) * k) * CFrame.Angles(k * 4, k * 6, 0) * group.turn
                end
            end
            KillFx.pose(body, function(item)
                if item.top and item.size then KillFx.resize(item, item.group.locked and Vector3.new(cell, cell, cell) or item.size) end
                return item.group.frame * (item.top and item.group.locked and CFrame.new() or item.offset)
            end)
            if pull >= 1 and not snapped then
                snapped = true
                outline.Transparency = 0
                KillFx.burst(sparks, 30 * opts.cint)
            end
            if progress >= 0.6 then
                if not dissolving then
                    dissolving = true
                    KillFx.burst(dust, 30 * opts.cint)
                end
                body.fade = math.clamp((progress - 0.6) / 0.35, 0, 1)
                outline.Transparency = body.fade
            end
            KillFx.paint(body)
        end)
    end,
}

KillFx.fx.Puppet = {
    start = function(ev, corpse, pos, opts)
        local body = KillFx.body(ev, corpse)
        if #body.parts == 0 then return end
        local groups = KillFx.groupList(body)
        local floor = KillFx.ground(pos).Y
        local lift = math.max(3, opts.height * 0.5)
        local holder = KillFx.anchor(ev, pos + Vector3.new(0, lift + 14, 0))
        local strings = {}
        for index, group in ipairs(groups) do
            group.phase = fxRand(0, math.pi * 2)
            if index <= 5 then
                local hook = KillFx.make(ev, "Attachment", {}, holder)
                hook.WorldPosition = Vector3.new(group.start.X, pos.Y + lift + 14, group.start.Z)
                local tie = KillFx.make(ev, "Attachment", {}, holder)
                tie.WorldPosition = group.start
                strings[#strings + 1] = { group = group, tie = tie, beam = KillFx.beam(ev, holder, hook, tie, WHITE, 0.05, 0.05) }
            end
        end
        local snap = KillFx.emitter(ev, holder, {
            Lifetime = NumberRange.new(0.3, 0.6), Speed = NumberRange.new(4, 8), SpreadAngle = Vector2.new(180, 180), Size = KillFx.shrink(0.2), Color = ColorSequence.new(WHITE, opts.color),
        })
        local hang, cut, landed = 0.6, false, false
        KillFx.drive(ev, corpse, body, opts.cdur, 0.4, function(t, progress)
            local height
            if progress < hang then
                local x = progress / hang * 3
                local step = math.min(math.floor(x), 2)
                local jerk = math.clamp((x - step) * 4, 0, 1) ^ 0.5
                height = lift * (step + jerk) / 3
            else
                if not cut then
                    cut = true
                    for _, line in ipairs(strings) do line.beam.Transparency = NumberSequence.new(1) end
                    holder.CFrame = CFrame.new((body.center or pos) + Vector3.new(0, lift, 0))
                    KillFx.burst(snap, 12 * opts.cint)
                end
                local age = (progress - hang) * opts.cdur
                height = math.max(0, lift - 30 * age * age)
                landed = landed or height <= 0
            end
            local dangle = landed and 0 or math.min(1, height)
            for _, group in ipairs(groups) do
                local swing = 0.35 * math.sin(t * 6 + group.phase) * dangle
                local spot = group.start + Vector3.new(swing, height, 0.6 * swing)
                if spot.Y < floor then spot = Vector3.new(spot.X, floor, spot.Z) end
                group.frame = CFrame.new(spot) * CFrame.Angles(swing * 0.6, 0, swing) * group.turn
            end
            body.center = pos + Vector3.new(0, height, 0)
            KillFx.posed(body)
            if not cut then
                for _, line in ipairs(strings) do line.tie.WorldPosition = line.group.frame.Position end
            end
            body.fade = math.clamp((progress - 0.85) / 0.15, 0, 1)
            KillFx.paint(body)
        end)
    end,
}

KillFx.fx["Time freeze"] = {
    start = function(ev, corpse, pos, opts)
        local body = KillFx.body(ev, corpse)
        local skin = KillFx.skin(ev, corpse, KillFx.visible(body))
        if not skin then return end
        local center = pos + Vector3.new(0, 1, 0)
        local eye = propGet(ev.root, "CFrame")
        local face = KillFx.flat(typeof(eye) == "CFrame" and eye.Position - center or Vector3.new(0, 0, 1), Vector3.new(0, 0, 1))
        local dial = CFrame.new(center, center + face)
        local holder = KillFx.anchor(ev, center)
        holder.CFrame = dial
        local count, radius, points, ring = 24, 3.2, {}, {}
        for index = 1, count do
            local angle = (index - 1) / count * math.pi * 2
            points[index] = KillFx.make(ev, "Attachment", {}, holder)
            points[index].WorldPosition = dial * Vector3.new(math.cos(angle) * radius, math.sin(angle) * radius, 0)
        end
        for index = 1, count do ring[index] = KillFx.beam(ev, holder, points[index], points[index % count + 1], opts.color2, 0.12, 0.12) end
        local hub = KillFx.make(ev, "Attachment", {}, holder)
        hub.WorldPosition = center
        local long, short = KillFx.make(ev, "Attachment", {}, holder), KillFx.make(ev, "Attachment", {}, holder)
        local hands = { KillFx.beam(ev, holder, hub, long, opts.color, 0.14, 0.06), KillFx.beam(ev, holder, hub, short, opts.color, 0.2, 0.1) }
        local runner = KillFx.make(ev, "Attachment", {}, holder)
        local motes = KillFx.emitter(ev, runner, {
            Rate = math.floor(60 * opts.cint), Enabled = true, Lifetime = NumberRange.new(0.8, 1.2), Speed = NumberRange.new(0, 0.2),
            Size = KillFx.shrink(0.3), Color = ColorSequence.new(WHITE, opts.color2),
        })
        local function gray(color)
            local level = 0.3 * color.R + 0.59 * color.G + 0.11 * color.B
            return Util.lerpColor(Color3.new(level, level, level), Color3.fromRGB(160, 160, 168), 0.4)
        end
        local length, frozen = math.max(1.5, opts.cdur), false
        KillFx.drive(ev, corpse, body, length, 0.6, function(t, progress)
            if not frozen then
                frozen = true
                KillFx.pose(body, function(item) return item.cf end)
            end
            skin.paint(Enum.Material.Marble, 0, gray, math.clamp(t / 0.4, 0, 1))
            local stop = math.min(t, 0.5)
            local spin = stop * (1 - stop) * 40
            long.WorldPosition = dial * Vector3.new(math.sin(spin) * radius * 0.85, math.cos(spin) * radius * 0.85, 0)
            short.WorldPosition = dial * Vector3.new(math.sin(spin / 12) * radius * 0.5, math.cos(spin / 12) * radius * 0.5, 0)
            local sweep = t * 5
            runner.WorldPosition = dial * Vector3.new(math.cos(sweep) * radius, math.sin(sweep) * radius, 0)
            local fade = NumberSequence.new(math.clamp((progress - 0.75) / 0.25, 0, 1))
            for _, beam in ipairs(ring) do beam.Transparency = fade end
            for _, beam in ipairs(hands) do beam.Transparency = fade end
            if progress >= 0.75 then motes.Enabled = false end
            if progress >= 1 then skin.finish() end
        end)
    end,
}

KillFx.fx.Implode = {
    start = function(ev, corpse, pos, opts)
        local body = KillFx.body(ev, corpse)
        if #body.parts == 0 then return end
        local center = pos + Vector3.new(0, 1, 0)
        local flash = KillFx.make(ev, "Part", KillFx.solid({
            Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Color = opts.color2, Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2), Position = center,
        }))
        local holder = KillFx.anchor(ev, center, Vector3.new(8, 8, 8))
        local pull = KillFx.emitter(ev, holder, {
            Rate = math.floor(30 * opts.cint), Enabled = true, Lifetime = NumberRange.new(0.35, 0.45), Speed = NumberRange.new(9, 11),
            Size = KillFx.shrink(0.3), Color = ColorSequence.new(opts.color2, opts.color),
        })
        propSet(pull, "Shape", Enum.ParticleEmitterShape.Sphere)
        propSet(pull, "ShapeStyle", Enum.ParticleEmitterShapeStyle.Surface)
        propSet(pull, "ShapeInOut", Enum.ParticleEmitterShapeInOut.Inward)
        local blast = KillFx.emitter(ev, holder, {
            Lifetime = NumberRange.new(0.3, 0.7), Speed = NumberRange.new(25, 45), SpreadAngle = Vector2.new(180, 180), Drag = 4, Size = KillFx.shrink(0.5), Color = ColorSequence.new(WHITE, opts.color),
        })
        local length, popped = math.max(0.8, opts.cdur * 0.5), false
        KillFx.drive(ev, corpse, body, length, 0.6, function(t, progress)
            local tremble = progress < 0.35 and 0.06 * math.sin(t * 70) or 0
            local k = math.clamp((progress - 0.35) / 0.45, 0, 1) ^ 3
            KillFx.pose(body, function(item)
                local at = item.cf.Position
                if item.size then KillFx.resize(item, item.size * (1 - 0.9 * k)) end
                item.sink = math.clamp((k - 0.7) / 0.3, 0, 1)
                return CFrame.new(center + (at - center) * (1 - k + tremble) - at) * item.cf
            end)
            if progress >= 0.8 and not popped then
                popped = true
                body.fade = 1
                pull.Enabled = false
                flash.Transparency = 0
                KillFx.burst(blast, 40 * opts.cint)
            end
            if popped then
                local age = math.clamp((progress - 0.8) / 0.2, 0, 1)
                local size = 0.2 + 3.5 * age
                flash.Size = Vector3.new(size, size, size)
                flash.Transparency = age
            end
            KillFx.paint(body)
        end)
    end,
}

KillFx.fx.Vaporize = {
    start = function(ev, corpse, pos, opts)
        local body = KillFx.body(ev, corpse)
        local list = KillFx.visible(body)
        if #list == 0 then return end
        local haze = KillFx.copies(ev, body, { Material = Enum.Material.Glass, Color = WHITE, Transparency = 0.75, Reflectance = 0 })
        local holder = KillFx.anchor(ev, pos, Vector3.new(3, 4, 2))
        local heat = KillFx.emitter(ev, holder, {
            Texture = SMOKE, LightEmission = 0.1, Rate = math.floor(14 * opts.cint), Enabled = true, Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(2, 4),
            EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(15, 15), Size = NumberSequence.new(1, 3), Transparency = NumberSequence.new(0.85, 1), Color = ColorSequence.new(WHITE),
        })
        local embers = KillFx.emitter(ev, holder, {
            Lifetime = NumberRange.new(0.6, 1.2), Speed = NumberRange.new(2, 6), SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, 6, 0),
            Size = KillFx.shrink(0.25), Color = ColorSequence.new(Color3.fromRGB(255, 200, 120), opts.color),
        })
        for _, item in ipairs(list) do item.key = 0.5 + fxRand(0, 0.15) end
        local flashed = false
        KillFx.drive(ev, corpse, body, opts.cdur, 1, function(t, progress)
            local shimmer = math.clamp(progress / 0.2, 0, 1)
            for _, copy in ipairs(haze) do
                local wave = Vector3.new(0.05 * math.sin(t * 31 + copy.cf.Position.Y), 0.04 * math.sin(t * 23), 0.05 * math.cos(t * 27))
                copy.part.CFrame = CFrame.new(wave) * copy.cf
                copy.part.Size = copy.size * (1 + 0.06 * shimmer)
                copy.part.Transparency = 0.75 + 0.25 * math.clamp((progress - 0.6) / 0.35, 0, 1)
            end
            if progress >= 0.5 and not flashed then
                flashed = true
                KillFx.burst(embers, 30 * opts.cint)
            end
            for _, item in ipairs(list) do item.fade = math.clamp((progress - item.key) / 0.25, 0, 1) end
            if progress >= 0.9 then heat.Enabled = false end
            KillFx.paint(body)
        end)
    end,
}

function KillFx.settings()
    return {
        color = val("kill_fx_color") or Color3.fromRGB(102, 204, 255), color2 = val("kill_fx_color2") or WHITE,
        int = val("kill_fx_int") or 1, dur = math.max(0.5, val("kill_fx_dur") or 2.5), flashDist = val("kill_fx_flash_dist") or 150,
        list = Util.set("kill_fx_list", { "Dissolve", "Lightning" }),
        corpse = Util.set("kill_fx_corpse", {}), cdur = math.max(0.5, val("kill_fx_corpse_dur") or 3), cint = val("kill_fx_corpse_int") or 1,
        height = val("kill_fx_corpse_height") or 10,
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
    group.pending = #ev.ticks - first + 1
end

function KillFx.retire(ev, group, now)
    local last
    for _, emitter in ipairs(group.emitters or {}) do
        propSet(emitter, "Enabled", false)
        last = math.max(last or -math.huge, KillFx.emitted[emitter] or -math.huge)
    end
    local at = last and last + (group.life or 0)
    if at and at > now then
        ev.lingering[#ev.lingering + 1] = { group = group, at = at }
    else
        KillFx.free(group)
    end
end

function KillFx.flow(ev, age)
    local dt = age - (ev.age or age)
    ev.age = age
    local streams = ev.streams
    for index = #streams, 1, -1 do
        local stream = streams[index]
        local emitter = stream.emitter
        if propGet(emitter, "Parent") == nil then
            table.remove(streams, index)
        elseif propGet(emitter, "Enabled") then
            stream.acc = stream.acc + stream.rate * dt
            if stream.acc >= 1 then
                local count = math.floor(stream.acc)
                stream.acc = stream.acc - count
                KillFx.burst(emitter, math.min(count, 40))
            end
        end
    end
end

function KillFx.keep(corpse, restore)
    KillFx.kept[#KillFx.kept + 1] = { corpse = corpse, restore = restore }
end

function KillFx.prune()
    for index = #KillFx.kept, 1, -1 do
        local entry = KillFx.kept[index]
        if propGet(entry.corpse, "Parent") == nil then
            Corpse.release(entry.corpse)
            table.remove(KillFx.kept, index)
        end
    end
end

function KillFx.clear()
    for _, ev in ipairs(KillFx.events) do KillFx.destroy(ev) end
    for _, entry in ipairs(KillFx.kept) do Util.guard("killfx restore", entry.restore) end
    KillFx.events, KillFx.pending, KillFx.seeded, KillFx.kept = {}, {}, false, {}
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

function KillFx.launch(model, pos, now, born)
    local opts = KillFx.settings()
    local root = propGet(Workspace, "CurrentCamera")
    if not root then return end
    while #KillFx.events >= KillFx.maxEvents do KillFx.destroy(table.remove(KillFx.events, 1)) end
    local ev = { born = now, groups = {}, ticks = {}, undo = {}, root = root, limit = math.max(opts.dur, opts.cdur) + 4, settle = (born or now) + KillFx.settle,
        streams = {}, lingering = {}, sizeScale = Tracers.distScale(pos) }
    KillFx.events[#KillFx.events + 1] = ev
    for _, name in ipairs(KillFx.names) do
        if opts.list[name] then KillFx.run(ev, name, KillFx.fx[name].start, model, pos, opts) end
    end
    local moved = false
    for _, name in ipairs(KillFx.corpseNames) do
        if opts.corpse[name] and not (moved and KillFx.movers[name]) then
            moved = moved or KillFx.movers[name] == true
            KillFx.run(ev, name, KillFx.fx[name].start, model, pos, opts)
        end
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
        if next(KillFx.events) or next(KillFx.pending) or KillFx.seeded or next(KillFx.kept) then KillFx.clear() end
        return
    end
    if next(KillFx.kept) then KillFx.prune() end
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
            Util.guard("killfx launch", KillFx.launch, model, pos, now, born)
        end
    end
    local events = KillFx.events
    for index = #events, 1, -1 do
        local ev = events[index]
        local age, ticks = now - ev.born, ev.ticks
        for slot = #ticks, 1, -1 do
            local entry = ticks[slot]
            ev.group = entry.group
            local ok, finished = pcall(entry.fn, age)
            if not ok then Util.note("killfx tick" .. tostring(finished), "killfx:", finished) end
            if not ok or finished == true then
                table.remove(ticks, slot)
                local group = entry.group
                group.pending = (group.pending or 1) - 1
                if group.pending <= 0 then KillFx.retire(ev, group, now) end
            end
        end
        if next(ev.streams) then KillFx.flow(ev, age) end
        local lingering = ev.lingering
        for slot = #lingering, 1, -1 do
            if now >= lingering[slot].at then
                KillFx.free(lingering[slot].group)
                table.remove(lingering, slot)
            end
        end
        if (#ticks == 0 and #lingering == 0) or age > ev.limit then
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
    FX = UI.page("FX", "sparkles"),
    Misc = UI.page("Misc", "shapes"),
}
local Status = {}
local ESPSubs = Pages.ESP:SubTabs({ { "Enemies", "swords" }, { "Teammates", "shield" }, { "Items & grenades", "package" }, { "Viewmodel", "user" } })

do
    local Subs = Pages.Legit:SubTabs({ { "Aim Assist", "crosshair" }, { "Silent Aim", "scan" }, { "Trigger & Recoil", "zap" } })

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
    Pred:Toggle({ Name = "Drop compensation", Flag = "legit_pred_drop", Default = true, Tooltip = "Like the game's Ballistics Tracker: the dot sits where to aim so the bullet's fall lands it on the target; off shows only the lead" })
    pickColor(Pred, "Dot", "legit_pred_color", Color3.fromRGB(255, 40, 40))
    Pred:Slider({ Name = "Dot size", Flag = "legit_pred_size", Min = 1, Max = 12, Default = 6, Decimals = 0.1, Suffix = " px" })
    Pred:Toggle({ Name = "Dot outline", Flag = "legit_pred_outline", Default = true }):Colorpicker({ Name = "Outline", Flag = "legit_pred_outline_color", Default = BLACK, Alpha = 0 })
    Pred:Toggle({ Name = "All enemies in FOV", Flag = "legit_pred_all", Tooltip = "Draws the dot for every enemy inside the FOV instead of only the aim target" })
    Pred:Toggle({ Name = "Aim at prediction", Flag = "legit_pred_aim", Tooltip = "Aims at the solved intercept point (full lead and drop) instead of the strength-limited lead below" })
    Master:Toggle({ Name = "Only while aiming down sights", Flag = "legit_ads" })
    Master:Toggle({ Name = "Only while shooting", Flag = "legit_shooting" })
    local FromBarrel = Master:Toggle({ Name = "Aim from barrel", Flag = "legit_barrel", Default = true, Tooltip = "Uses the weapon's bullet origin and direction (as the game computes them) for visibility, prediction and aiming; the camera is still the only thing that moves" }):Settings("Aim from barrel", 230)
    FromBarrel:Slider({ Name = "Scoped-in threshold", Flag = "legit_barrel_ads", Min = 0, Max = 1, Default = 0.9, Decimals = 0.01, Tooltip = "While aiming down sights the camera is used until the aim-in reaches this point, then it blends to the barrel; hip fire stays on the barrel. Also moves the FOV circles and the prediction dot. 0 = always the barrel" })
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

    local Trig = Subs["Trigger & Recoil"]
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

    local RcsBox = Trig:Section({ Name = "Recoil control", Column = 3, Icon = "target" })
    RcsBox:Toggle({ Name = "Enabled", Flag = "rcs_on", Tooltip = "Cancels the recoil of each shot by tracking where the barrel points relative to your view" }):Keybind({ Name = "Recoil key", Flag = "rcs_key", Default = "None", Mode = "Always" })
    RcsBox:Toggle({ Name = "Use barrel direction", Flag = "rcs_barrel", Default = true, Tooltip = "Compensates the barrel's own recoil, shake and sway; off falls back to the camera recoil springs only" })
    RcsBox:Slider({ Name = "Vertical control", Flag = "rcs_v", Min = 0, Max = 100, Default = 70, Decimals = 1, Suffix = "%" })
    RcsBox:Slider({ Name = "Horizontal control", Flag = "rcs_h", Min = 0, Max = 100, Default = 40, Decimals = 1, Suffix = "%" })
    RcsBox:Toggle({ Name = "Hipfire too", Flag = "rcs_hip", Default = true, Tooltip = "Off: only controls recoil while aiming down sights" })
    RcsBox:Slider({ Name = "Variation", Flag = "rcs_human", Min = 0, Max = 40, Default = 10, Decimals = 1, Suffix = "%", Tooltip = "Varies the strength over time so the spray does not look machine perfect" })
end

do
    Pages.Rage:Section({ Name = "Rage", Column = 1, Icon = "swords" }):Label({ Name = "Coming soon" })
    local MiscSubs = Pages.Misc:SubTabs({ { "General", "shapes" }, { "Skin changer", "palette" } })
    local General = MiscSubs.General
    local Fun = General:Section({ Name = "Fun", Column = 1, Icon = "shapes" })
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

    local Kn = General:Section({ Name = "Knife unlock", Column = 2, Icon = "swords" })
    Kn:Toggle({ Name = "Use selected knife", Flag = "misc_knife_on", Tooltip = "Spawns you with the knife and skin below. Client side only: the server still has your real knife, no loadout packet is sent", Callback = function() Skins.syncWeapons() end })
    Kn:Dropdown({ Name = "Knife", Flag = "misc_knife", Items = Knife.items(), Default = "Default", Tooltip = "Every melee weapon in the game's content; Default keeps your equipped knife", Callback = function() Skins.syncWeapons() end })
    Kn:Dropdown({ Name = "Knife skin", Flag = "misc_knife_skin", Items = Knife.skinItems(), Default = "Default", Tooltip = "Default keeps your knife's own skin, None strips it" })
    Kn:Toggle({ Name = "Unlock all knives", Flag = "misc_knife_unlock", Tooltip = "The loadout menu treats every knife as owned. Equipping an unowned knife there stays local: the packet that would tell the server is dropped", Callback = function() Skins.syncWeapons() end })
    Kn:Button({ Name = "Refresh knife list", Callback = function()
        Knife.synced = false
        Knife.syncUI()
    end })
    Kn:Label({ Name = "Applies on your next spawn" })

    local Wt = General:Section({ Name = "Script watcher", Column = 3, Icon = "scan" })
    Wt:Toggle({ Name = "Script watcher", Flag = "misc_watch", Tooltip = "Logs client scripts, modules and weapon/attachment database entries the game adds after you turn this on. Read only: nothing found is run, changed or removed", Callback = function(value) Watch.set(value) end })
    Wt:Toggle({ Name = "Notify", Flag = "misc_watch_notify", Default = true, Tooltip = "Shows a notification for each new item (at most one per second)" })
    Wt:Toggle({ Name = "Print to console", Flag = "misc_watch_print", Tooltip = "Prints every new item with its parent and script hash" })
    Wt:Button({ Name = "Dump loaded modules", Callback = function() Watch.dump() end })
    Watch.label = Wt:Label({ Name = Watch.offText })
    Watch.render()

    local SkinSub = MiscSubs["Skin changer"]
    local Pick = SkinSub:Section({ Name = "Weapon", Column = 1, Icon = "swords" })
    Skins.scan()
    local classItems = { "All", "Skinned" }
    for _, class in ipairs(Skins.classes) do classItems[#classItems + 1] = class end
    Pick:Toggle({ Name = "Enabled", Flag = "skin_on", Default = true, Tooltip = "Builds your own first-person weapons with the skins set here. Client side only: nothing is sent, other players see your real skins" })
    Pick:Dropdown({ Name = "Class", Flag = "skin_class", Items = classItems, Default = "All", Callback = function() Skins.syncWeapons() end })
    Pick:Input({ Name = "Search weapon", Flag = "skin_search", Placeholder = "name filter", Callback = function() Skins.syncWeapons() end })
    local weapons = Skins.weaponItems()
    Pick:Dropdown({ Name = "Weapon", Flag = "skin_weapon", Items = weapons, Default = weapons[1], Searchable = true, Tooltip = "Weapons you own, plus knives from Knife unlock", Callback = function(value) Skins.select(value) end })
    Skins.viewport = Pick:Viewport({ Flag = "skin_view", Height = 210, Clone = false, FOV = 40, AutoRotate = true, Hint = "Drag to rotate, wheel to zoom", EmptyText = Skins.emptyText })
    if not Skins.viewport then Pick:Label({ Name = "Update Library.lua for the 3D preview" }) end
    Pick:Dropdown({ Name = "Slot", Flag = "skin_slot", Items = { "Slot 1", "Slot 2" }, Default = "Slot 1", Callback = function(value) Skins.setSlot(value) end })
    Pick:Button({ Name = "Reset weapon", Callback = function() Skins.resetWeapon() end })
    Pick:Button({ Name = "Refresh weapons and skins", Callback = function()
        Skins.synced, Skins.bp = false, nil
        Skins.refresh()
    end })
    Pick:Label({ Name = "Applies on your next spawn; needs First Person Camo on in the game's settings" })

    local Edit = SkinSub:Section({ Name = "Customize", Column = 2, Icon = "palette" })
    Skins.label = Edit:Label({ Name = "Slot 1: no skin" })
    Edit:Label({ Name = "Texture colour" }):Colorpicker({ Name = "Texture colour", Flag = "skin_tex_color", Default = WHITE, Alpha = 0 })
    for _, spec in ipairs(Skins.sliders) do
        local range = Skins.ranges[spec.group][spec.key]
        if spec.group == "BrickProperties" then
            Edit:Label({ Name = "Brick colour" }):Colorpicker({ Name = "Brick colour", Flag = "skin_brick_color", Default = Color3.fromRGB(163, 162, 165) })
            Edit:Dropdown({ Name = "Material", Flag = "skin_material", Items = Skins.materials(), Default = "SmoothPlastic", Callback = function(value) Skins.edit("BrickProperties", "Material", value) end })
        end
        Edit:Slider({ Name = spec.name, Flag = spec.flag, Min = range[1], Max = range[2], Default = spec.default, Decimals = spec.decimals, Suffix = spec.suffix, Tooltip = spec.tip,
            Callback = function(value) Skins.edit(spec.group, spec.key, value) end })
    end
    Edit:Button({ Name = "Reset slot settings", Callback = function() Skins.resetSlot() end })
    Edit:Button({ Name = "Copy to other slot", Callback = function() Skins.copySlot() end })
    Skins.syncing = true
    for flagName, group in pairs({ skin_tex_color = "TextureProperties", skin_brick_color = "BrickProperties" }) do
        local option = Options[flagName]
        if option then
            option:OnChanged(function()
                Skins.edit(group, "Color", Skins.toRGB(option.Value))
                if group == "TextureProperties" then Skins.edit(group, "Transparency", Util.alpha(flagName, 0)) end
            end)
        end
    end
    Skins.syncing = false

    local Presets = SkinSub:Section({ Name = "Presets", Column = 2, Icon = "layers" })
    Presets:Dropdown({ Name = "Source", Flag = "skin_preset_src", Items = { "Community", "Blueprints", "Saved" }, Default = "Community", Tooltip = "Community: reddit looks. Blueprints: the game's weapon blueprints (skin only, no attachments). Saved: your own", Callback = function() Skins.syncPresets() end })
    Presets:Dropdown({ Name = "Blueprint weapons", Flag = "skin_preset_weapon", Items = Skins.presetModes, Default = Skins.presetModes[1], Tooltip = "Which weapons' blueprints are listed. Applying a blueprint for another owned weapon switches to that weapon", Callback = function() Skins.syncPresets() end })
    Presets:Input({ Name = "Search presets", Flag = "skin_preset_search", Placeholder = "preset or weapon name", Callback = function() Skins.syncPresets() end })
    Presets:Dropdown({ Name = "Preset", Flag = "skin_preset", Items = { "None" }, Default = "None", Searchable = true })
    Presets:Button({ Name = "Apply preset", Callback = function() Skins.applyPreset() end })
    Presets:Input({ Name = "Preset name", Flag = "skin_preset_name", Placeholder = "name for this weapon's skin" })
    Presets:Button({ Name = "Save as preset", Callback = function() Skins.savePreset() end })
    Presets:Button({ Name = "Delete preset", Callback = function() Skins.deletePreset() end })

    local Cases = SkinSub:Section({ Name = "Cases", Column = 3, Icon = "package" })
    Skins.gallery = Cases:Gallery({ Flag = "skin_cases", Height = 430, TileSize = 64, Search = true, Placeholder = "Search cases / skins...", Title = "Cases", Items = Skins.galleryItems(),
        Callback = function(item, _, selected) Skins.setSkin(item.Id, selected) end })
    if not Skins.gallery then
        Cases:Label({ Name = "Update Library.lua for the case gallery" })
        Cases:Dropdown({ Name = "Case", Flag = "skin_case", Items = { "None" }, Default = "None", Searchable = true, Callback = function() Skins.syncCaseSkins() end })
        Cases:Dropdown({ Name = "Skin", Flag = "skin_pick", Items = { "None" }, Default = "None", Searchable = true, Callback = function(value)
            if Skins.syncing then return end
            local slot = Skins.current()
            if value == "None" or value == nil then
                if slot then Skins.setSkin(slot.Name, false) end
            else
                Skins.setSkin(value, true)
            end
        end })
    end
    Cases:Label({ Name = "Click a skin to apply it to the slot, click it again to remove it" })
    Skins.refresh()
    Skins.select(Options.skin_weapon and Options.skin_weapon.Value)
end

do
    local function pickColor(popup, label, flagName, default, alpha)
        popup:Label({ Name = label }):Colorpicker({ Name = label, Flag = flagName, Default = default, Alpha = alpha or 0 })
    end

    local LocalSub = ESPSubs.Viewmodel
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
    Chams:Dropdown({ Name = "Cham style", Flag = "local_cham_style", Items = ChamStyle.viewNames, Default = "Classic", Tooltip = "Animates the viewmodel chams above; uses Style colour 2 and Style speed from the player chams settings" })

    local Remove = LocalSub:Section({ Name = "Remove parts", Column = 2, Icon = "eye" })
    Remove:Toggle({ Name = "Remove left arm", Flag = "local_rm_larm", Tooltip = "Hides the left arm's skin; sleeve and glove stay" })
    Remove:Toggle({ Name = "Remove right arm", Flag = "local_rm_rarm", Tooltip = "Hides the right arm's skin; sleeve and glove stay" })
    Remove:Toggle({ Name = "Remove left sleeve", Flag = "local_rm_lsleeve" })
    Remove:Toggle({ Name = "Remove right sleeve", Flag = "local_rm_rsleeve" })
    Remove:Toggle({ Name = "Remove gloves", Flag = "local_rm_gloves", Tooltip = "Both hands' gloves and accessories" })
    Remove:Toggle({ Name = "Remove gun", Flag = "local_rm_gun", Tooltip = "Hides the viewmodel weapon" })
    Remove:Toggle({ Name = "Remove scope glass", Flag = "local_noglass", Tooltip = "Hides sight lenses and glass on the weapon in your hands, with or without gun chams; reticles stay visible" })
    Remove:Toggle({ Name = "Remove scope interior", Flag = "local_noaperture", Tooltip = "Hides the dark eyepiece shadow some magnified scopes draw over the lens (ACOG, C79, VCOG style); the reticle stays" })

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
            Cham:Depends({ { "cham_glow", true } }, function(box)
                box:Slider({ Name = "Glow strength", Flag = "cham_glow_size", Min = 1, Max = 2.5, Default = 1.75, Decimals = 0.01 })
            end)
            Cham:Toggle({ Name = "Bloom", Flag = "cham_bloom", Default = true, Tooltip = "Drives a bloom effect while the glow is on; the World bloom settings win if that is enabled" })
            Cham:Depends({ { "cham_bloom", true } }, function(box)
                box:Slider({ Name = "Bloom intensity", Flag = "cham_bloom_i", Min = 0, Max = 3, Default = 0.4, Decimals = 0.01 })
                box:Slider({ Name = "Bloom size", Flag = "cham_bloom_s", Min = 0, Max = 56, Default = 24, Decimals = 0.1 })
                box:Slider({ Name = "Bloom threshold", Flag = "cham_bloom_t", Min = 0, Max = 2, Default = 0.95, Decimals = 0.01 })
            end)
            Cham:Slider({ Name = "Head size", Flag = "cham_head_size", Min = 0.8, Max = 1.6, Default = 1.15, Decimals = 0.01 })
            Cham:Toggle({ Name = "Round head", Flag = "cham_round_head", Default = true })
            Cham:Toggle({ Name = "Remove armor/gear", Flag = "chams_remove_gear", Default = true, Tooltip = "Hides helmets, armor and other cosmetics on players with chams so the body is covered cleanly; restored when chams stop" })
            Cham:Dropdown({ Name = "Style", Flag = "chams_style", Items = ChamStyle.names, Default = "Classic", Tooltip = "Classic is the adornment chams above. The other styles draw local copies posed to the player; players past the style cap use Classic" })
            Cham:Depends({ { "chams_style", function(value) return value ~= "Classic" end } }, function(styled)
                pickColor(styled, "Style colour", "chams_style_color", Color3.fromRGB(0, 220, 255))
                pickColor(styled, "Style colour 2", "chams_style_color2", Color3.fromRGB(255, 60, 200))
                styled:Slider({ Name = "Style speed", Flag = "chams_style_speed", Min = 0.1, Max = 4, Default = 1, Decimals = 0.05 })
                styled:Slider({ Name = "Style intensity", Flag = "chams_style_int", Min = 0.2, Max = 1.5, Default = 1, Decimals = 0.05 })
                styled:Toggle({ Name = "Style through walls", Flag = "chams_style_walls", Default = true, Tooltip = "Toon, Ghost and Glow shells show through walls; off hides styled players behind cover" })
                styled:Slider({ Name = "Style cap", Flag = "chams_style_cap", Min = 1, Max = 20, Default = 8, Decimals = 1, Tooltip = "Most players styled at once, nearest first; the rest use Classic" })
                styled:Toggle({ Name = "Style visibility colours", Flag = "chams_style_vis", Tooltip = "Replaces Style colour with the visible or behind-walls colour below, from the shared visibility check (Visibility check interval)" })
                styled:Depends({ { "chams_style_vis", true } }, function(box)
                    pickColor(box, "Style visible", "chams_style_vis_color", Color3.fromRGB(80, 255, 140))
                    pickColor(box, "Style behind walls", "chams_style_occ_color", Color3.fromRGB(255, 70, 110), 0.25)
                end)
            end)
            Cham:Depends({ { "chams_style", "Toon" } }, function(box)
                box:Slider({ Name = "Toon outline", Flag = "chams_toon_outline", Min = 0.05, Max = 0.8, Default = 0.3, Decimals = 0.01, Suffix = " studs" })
                pickColor(box, "Toon outline colour", "chams_toon_outline_color", Color3.fromRGB(12, 12, 18))
                box:Slider({ Name = "Toon shading", Flag = "chams_toon_shade", Min = 0, Max = 0.9, Default = 0.45, Decimals = 0.01, Tooltip = "How much darker the faces turned away from the light are" })
                box:Toggle({ Name = "Toon rim light", Flag = "chams_toon_rim", Default = true, Tooltip = "Lights the outline edges facing away from the camera in Style colour 2" })
            end)
            Cham:Depends({ { "chams_style", "Ghost" } }, function(box)
                box:Slider({ Name = "Ghost copies", Flag = "chams_ghost_count", Min = 1, Max = 8, Default = 5, Decimals = 1 })
                box:Slider({ Name = "Ghost spacing", Flag = "chams_ghost_spacing", Min = 0.3, Max = 4, Default = 1.2, Decimals = 0.1, Suffix = " studs", Tooltip = "A copy is left each time the player moves this far, so standing players leave none" })
                box:Slider({ Name = "Ghost trail length", Flag = "chams_ghost_length", Min = 0.15, Max = 1.5, Default = 0.6, Decimals = 0.05, Suffix = " s" })
                box:Toggle({ Name = "Ghost colour gradient", Flag = "chams_ghost_gradient", Default = true, Tooltip = "Copies blend from Style colour to Style colour 2 as they fade" })
            end)
            Cham:Depends({ { "chams_style", "Glow shells" } }, function(box)
                box:Slider({ Name = "Glow shells", Flag = "chams_glow_shells", Min = 1, Max = 3, Default = 3, Decimals = 1 })
                box:Slider({ Name = "Glow breathing", Flag = "chams_glow_pulse", Min = 0, Max = 1, Default = 0.5, Decimals = 0.05 })
                box:Toggle({ Name = "Glow outline", Flag = "chams_glow_outline" })
            end)
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

    local Other = Subs["Items & grenades"]
    local Drops = Other:Section({ Name = "Dropped items", Column = 1, Icon = "package" })
    local Item = Drops:Toggle({ Name = "Dropped items", Flag = "item_drops" }):Settings("Dropped items", 230)
    pickColor(Item, "Weapons", "item_drops_color", Color3.fromRGB(255, 190, 60))
    Item:Dropdown({ Name = "Display", Flag = "item_drops_display", Items = { "Text", "Icon", "Both" }, Default = "Text", Tooltip = "Icon draws the weapon silhouette, with the distance under it" })
    Item:Slider({ Name = "Max distance", Flag = "item_dist", Min = 20, Max = 1500, Default = 300, Decimals = 1, Suffix = " studs" })

    local Nades = Other:Section({ Name = "Grenade warning", Column = 2, Icon = "bell" })
    local Warn = Nades:Toggle({ Name = "Grenade warning", Flag = "nade_on", Tooltip = "Tracks enemy grenades and your own from the game's throw event" }):Settings("Grenade warning", 230)
    Warn:Toggle({ Name = "Enemy grenades", Flag = "nade_enemy", Default = true })
    pickColor(Warn, "Enemy", "nade_enemy_color", Color3.fromRGB(255, 90, 60))
    Warn:Toggle({ Name = "My grenades", Flag = "nade_own", Default = true })
    pickColor(Warn, "Mine", "nade_own_color", Color3.fromRGB(120, 255, 170))
    pickColor(Warn, "Blast ring", "nade_ring_color", Color3.fromRGB(255, 220, 60))
    pickColor(Warn, "Blast ring (lethal)", "nade_ring_lethal_color", Color3.fromRGB(255, 60, 60))
    Warn:Toggle({ Name = "Fuse timer", Flag = "nade_timer", Default = true })
    Warn:Toggle({ Name = "Flight path", Flag = "nade_path", Default = true, Tooltip = "The path from the server's replicated grenade nodes, up to the blast" })
    Warn:Slider({ Name = "Max distance", Flag = "nade_dist", Min = 50, Max = 1500, Default = 400, Decimals = 1, Suffix = " studs" })

    local Blast = Nades:Toggle({ Name = "Damage estimate", Flag = "nade_dmg", Default = true, Tooltip = "Torso damage to you at the blast point from the grenade's damage graph, 0 behind map cover" }):Settings("Damage estimate", 200)
    pickColor(Blast, "Safe", "nade_safe_color", Color3.fromRGB(90, 255, 130))
    pickColor(Blast, "Danger", "nade_danger_color", Color3.fromRGB(255, 60, 60))
    Blast:Toggle({ Name = "Blast radius ring", Flag = "nade_ring", Default = true, Tooltip = "Ground ring at the damage range of the grenade" })

    local Throw = Other:Section({ Name = "Throw predictor", Column = 3, Icon = "target" })
    local Pred = Throw:Toggle({ Name = "Predict throw", Flag = "nade_predict", Tooltip = "While the pin is pulled, draws the predicted path, landing and fuse left" }):Settings("Throw predictor", 200)
    pickColor(Pred, "Path", "nade_predict_color", Color3.fromRGB(120, 200, 255))
    Pred:Toggle({ Name = "Show before pin pull", Flag = "nade_predict_pre", Tooltip = "Dimmer preview while the pin is still in" })
    Pred:Toggle({ Name = "Bounce markers", Flag = "nade_predict_bounce", Default = true })
end

do
    local Subs = Pages.World:SubTabs({ { "Environment", "sun" }, { "Sky", "moon" }, { "Weather", "cloud" }, { "Post-processing", "palette" }, { "Camera", "camera" } })

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
    Atmos:Toggle({ Name = "Override offset", Flag = "world_atmos_offset_on", Tooltip = "Off keeps the map's own offset" })
    Atmos:Slider({ Name = "Offset", Flag = "world_atmos_offset", Min = 0, Max = 1, Default = 0, Decimals = 0.01 })
    Atmo:Dropdown({ Name = "Atmosphere preset", Flag = "world_atmos_preset", Items = ATMOS_ORDER, Default = ATMOS_ORDER[1], Tooltip = "Apply copies the preset into the Atmosphere settings and turns it on" })
    Atmo:Button({ Name = "Apply atmosphere preset", Callback = function() Util.guard("atmos-preset", World.atmosPreset) end })
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

    local Quick = Env:Section({ Name = "Quick toggles", Column = 3, Icon = "zap" })
    Quick:Toggle({ Name = "Full bright", Flag = "world_fullbright", Tooltip = "Overrides lighting values while on" })
    Quick:Toggle({ Name = "No shadows", Flag = "world_noshadow" })
    Quick:Toggle({ Name = "No fog", Flag = "world_nofog" })
    Quick:Toggle({ Name = "Remove sky", Flag = "world_nosky" })

    local SkySub = Subs.Sky
    local Box = SkySub:Section({ Name = "Skybox", Column = 1, Icon = "moon" })
    local Skybox = Box:Toggle({ Name = "Custom skybox", Flag = "world_skybox", Tooltip = "Replaces the sky textures; the original sky comes back when this is off" }):Settings("Custom skybox", 230)
    Skybox:Dropdown({ Name = "Skybox", Flag = "world_sky_box", Items = SKY_CHOICES, Default = SKY_CHOICES[1], Searchable = true })
    Skybox:Toggle({ Name = "Rotate skybox", Flag = "world_sky_spin" })
    Skybox:Slider({ Name = "Rotation speed", Flag = "world_sky_spin_speed", Min = -60, Max = 60, Default = 6, Decimals = 0.1, Suffix = " deg/s" })
    local Asset = SkySub:Section({ Name = "Skybox asset", Column = 1, Icon = "link" })
    Asset:Input({ Name = "Asset ID / store link", Flag = "world_sky_asset", Placeholder = "id or create.roblox.com/store/asset/<id>" })
    Asset:Button({ Name = "Apply", Callback = function() Util.guard("sky-asset", World.applyAsset) end })
    Asset:Toggle({ Name = "Apply model lighting", Flag = "world_sky_asset_light", Tooltip = "Also uses the Atmosphere, Bloom, Colour correction and Sun rays inside the sky model; they are undone when this or the skybox is off" })
    Asset:Button({ Name = "Save", Callback = function() task.spawn(Util.guard, "sky-asset-save", World.saveAsset) end })
    Asset:Toggle({ Name = "Debug sky loads", Flag = "world_sky_debug", Tooltip = "Prints which loader fetched each sky asset and what was inside it to the console (F9)" })
    local Cloud = SkySub:Section({ Name = "Clouds", Column = 1, Icon = "cloud" })
    local Clouds = Cloud:Toggle({ Name = "Clouds", Flag = "world_clouds" }):Settings("Clouds", 230)
    pickColor(Clouds, "Clouds", "world_clouds_color", WHITE)
    Clouds:Slider({ Name = "Cover", Flag = "world_clouds_cover", Min = 0, Max = 1, Default = 0.6, Decimals = 0.01 })
    Clouds:Slider({ Name = "Density", Flag = "world_clouds_density", Min = 0, Max = 1, Default = 0.6, Decimals = 0.01 })
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
    local Saved = SkySub:Section({ Name = "Saved skyboxes", Column = 3, Icon = "layers" })
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
    local Dyn = SkySub:Section({ Name = "Dynamic sky", Column = 3, Icon = "sparkles" })
    local DynSet = Dyn:Toggle({ Name = "Dynamic sky", Flag = "world_dsky", Tooltip = "Animated sky layers around the camera on top of any skybox, with slow atmosphere, colour and bloom changes; everything is undone when off" }):Settings("Dynamic sky", 230)
    DynSet:Slider({ Name = "Speed", Flag = "world_dsky_speed", Min = 0.1, Max = 4, Default = 1, Decimals = 0.05 })
    DynSet:Slider({ Name = "Intensity", Flag = "world_dsky_int", Min = 0.1, Max = 2, Default = 1, Decimals = 0.05 })
    DynSet:Slider({ Name = "Star density", Flag = "world_dsky_stars", Min = 0, Max = 3, Default = 1, Decimals = 0.05 })
    DynSet:Slider({ Name = "Shooting stars", Flag = "world_dsky_shoot", Min = 0, Max = 30, Default = 6, Decimals = 1, Suffix = " /min" })
    pickColor(DynSet, "Colour tint", "world_dsky_tint", WHITE)
    Dyn:Dropdown({ Name = "Sky preset", Flag = "world_dsky_preset", Items = DynSky.names, Default = "Aurora" })

    local Wx = Subs.Weather:Section({ Name = "Weather", Column = 1, Icon = "cloud" })
    Wx:Toggle({ Name = "Enabled", Flag = "world_weather", Tooltip = "Particles follow you in map-anchored cells and only fall where the sky is open above; Cover whole map replaces that with cells over the whole map" })
    Wx:Dropdown({ Name = "Type", Flag = "world_weather_preset", Items = WEATHER_NAMES, Default = "Snow" })
    Wx:Slider({ Name = "Density", Flag = "world_weather_amount", Min = 0.1, Max = 3, Default = 1, Decimals = 0.05 })
    Wx:Slider({ Name = "Speed", Flag = "world_weather_speed", Min = 0.2, Max = 3, Default = 1, Decimals = 0.05 })
    Wx:Slider({ Name = "Particle size", Flag = "world_weather_size", Min = 0.3, Max = 3, Default = 1, Decimals = 0.05 })
    local Cover = Subs.Weather:Section({ Name = "Coverage", Column = 2, Icon = "map" })
    local mapGear = Cover:Toggle({ Name = "Cover whole map", Flag = "world_weather_map", Tooltip = "Weather over the whole map only; the cells that follow you are switched off and come back when this is off. Cells grow so the count stays under the cap" }):Settings("Whole map", 200)
    mapGear:Slider({ Name = "Max cells", Flag = "world_weather_map_cap", Min = 16, Max = 400, Default = 100, Decimals = 1, Tooltip = "More cells = finer roof detection but more emitters" })
    mapGear:Slider({ Name = "Clear radius around player", Flag = "world_weather_clear_radius", Min = 0, Max = 150, Default = 40, Decimals = 1, Suffix = " studs", Tooltip = "Cells this close to you stay empty so nothing falls on or above you; 0 = off" })
    Cover:Slider({ Name = "Range", Flag = "world_weather_range", Min = 1, Max = 3, Default = 2, Decimals = 1, Suffix = " cells", Tooltip = "Rings of 28 stud cells around you; unused while Cover whole map is on" })
    Cover:Slider({ Name = "Spawn height", Flag = "world_weather_height", Min = 10, Max = 80, Default = 35, Decimals = 1, Suffix = " studs" })
    local Wind = Subs.Weather:Section({ Name = "Wind and colour", Column = 3, Icon = "cloud" })
    Wind:Slider({ Name = "Wind strength", Flag = "world_weather_wind", Min = 0, Max = 30, Default = 4, Decimals = 0.1 })
    Wind:Slider({ Name = "Wind direction", Flag = "world_weather_wind_dir", Min = 0, Max = 360, Default = 0, Decimals = 1, Suffix = " deg" })
    Wind:Toggle({ Name = "Custom colour", Flag = "world_weather_custom", Tooltip = "Overrides the colour each weather type comes with" }):Colorpicker({ Name = "Weather", Flag = "world_weather_color", Default = WHITE })

    local Fx = Subs["Post-processing"]
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
    local Motion = Cam:Section({ Name = "Crosshair motion", Column = 3, Icon = "refresh-cw" })
    local Spin = Motion:Toggle({ Name = "Spin", Flag = "cross_spin" }):Settings("Spin", 200)
    Spin:Slider({ Name = "Spin speed", Flag = "cross_spin_speed", Min = -360, Max = 360, Default = 90, Decimals = 1, Suffix = " deg/s" })
    local Pulse = Motion:Toggle({ Name = "Pulse gap", Flag = "cross_pulse" }):Settings("Pulse gap", 230)
    Pulse:Slider({ Name = "Pulse range", Flag = "cross_pulse_range", Min = 0, Max = 30, Default = 8, Decimals = 1, Suffix = " px" })
    Pulse:Slider({ Name = "Pulse speed", Flag = "cross_pulse_speed", Min = 0.2, Max = 10, Default = 3, Decimals = 0.1 })
end

do
    local Subs = Pages.FX:SubTabs({ { "Hits", "target" }, { "Kills", "skull" }, { "Bullets", "zap" } })
    local function pickColor(popup, label, flagName, default, alpha)
        popup:Label({ Name = label }):Colorpicker({ Name = label, Flag = flagName, Default = default, Alpha = alpha or 0 })
    end

    local function hidden(flagName, kind, value, values)
        local option = { Type = kind, Value = value, Values = values, Multi = type(value) == "table" }
        function option:SetValue(new)
            if kind == "Dropdown" then
                local out = {}
                for key, on in pairs(Util.toSet(new)) do
                    if on and table.find(values, key) then out[key] = true end
                end
                self.Value = out
            else
                self.Value = tonumber(new) or self.Value
            end
            if self.Changed then pcall(self.Changed, self.Value) end
        end
        function option:OnChanged(fn) self.Changed = fn end
        Options[flagName] = option
        return option
    end

    local Hits = Subs.Hits
    local Marker = Hits:Section({ Name = "Hit marker", Column = 1, Icon = "crosshair" })
    local MarkerMore = Marker:Toggle({ Name = "Hit marker", Flag = "hit_marker", Tooltip = "Drawn at the crosshair whenever the game registers one of your hits" }):Colorpicker({ Name = "Marker", Flag = "hit_marker_color", Default = WHITE, Alpha = 0 }):Colorpicker({ Name = "Headshot", Flag = "hit_marker_head", Default = Color3.fromRGB(255, 70, 70), Alpha = 0 }):Settings("Hit marker", 240)
    Marker:Dropdown({ Name = "Style", Flag = "hit_marker_style", Items = Feedback.styles, Default = "Classic X" })
    Marker:Dropdown({ Name = "Animation", Flag = "hit_marker_anim", Items = Feedback.anims, Default = "Expand" })
    Marker:Slider({ Name = "Size", Flag = "hit_marker_size", Min = 4, Max = 24, Default = 9, Decimals = 1, Suffix = " px" })
    Marker:Slider({ Name = "Duration", Flag = "hit_marker_time", Min = 0.1, Max = 1.2, Default = 0.4, Decimals = 0.01, Suffix = " s" })
    Marker:Toggle({ Name = "Kill marker", Flag = "hit_marker_kill", Tooltip = "Bigger marker in its own colour when the hit kills" }):Colorpicker({ Name = "Kill", Flag = "hit_marker_kill_color", Default = Color3.fromRGB(255, 190, 60), Alpha = 0 })
    Marker:Toggle({ Name = "3D at hit position", Flag = "hit_marker_3d", Tooltip = "Draws each marker where the bullet hit the player instead of at the crosshair" })
    Marker:Toggle({ Name = "Hide the game's marker", Flag = "hit_hide_game" })
    MarkerMore:Slider({ Name = "Thickness", Flag = "hit_marker_thick", Min = 1, Max = 5, Default = 1, Decimals = 1, Suffix = " px" })
    MarkerMore:Slider({ Name = "Gap", Flag = "hit_marker_gap", Min = 0, Max = 20, Default = 3, Decimals = 1, Suffix = " px" })
    MarkerMore:Toggle({ Name = "Outline", Flag = "hit_marker_outline", Default = true })
    MarkerMore:Depends({ { "hit_marker_kill", true } }, function(box)
        box:Slider({ Name = "Kill marker size", Flag = "hit_marker_kill_size", Min = 1, Max = 3, Default = 1.5, Decimals = 0.05, Suffix = "x" })
    end)
    MarkerMore:Toggle({ Name = "Skull on kill", Flag = "hit_marker_skull", Tooltip = "Replaces the marker with a skull when the hit kills" })
    local Hc = Hits:Section({ Name = "Hit chams", Column = 1, Icon = "user" })
    local HcMore = Hc:Toggle({ Name = "Hit chams", Flag = "hit_cham_on", Tooltip = "Flashes a local copy of the body you hit, built from adornments. Only your own bullet hits on enemies" }):Colorpicker({ Name = "Hit cham", Flag = "hit_cham_color", Default = Color3.fromRGB(255, 70, 110), Alpha = 0.35 }):Settings("Hit chams", 240)
    Hc:Dropdown({ Name = "Look", Flag = "hit_cham_look", Items = { "Solid", "Glow", "Wireframe" }, Default = "Solid" })
    Hc:Dropdown({ Name = "Fade style", Flag = "hit_cham_fade", Items = { "Linear", "Pop", "Pulse" }, Default = "Linear" })
    Hc:Slider({ Name = "Duration", Flag = "hit_cham_time", Min = 0.1, Max = 3, Default = 0.8, Decimals = 0.05, Suffix = " s" })
    Hc:Toggle({ Name = "Hit part only", Flag = "hit_cham_part", Tooltip = "Only the body part the bullet hit instead of the whole body" })
    Hc:Toggle({ Name = "Follow player", Flag = "hit_cham_follow", Tooltip = "Off keeps the pose from the moment of the hit; on moves with the player while it fades" })
    HcMore:Toggle({ Name = "Always on top", Flag = "hit_cham_top", Default = true })
    HcMore:Toggle({ Name = "Outline", Flag = "hit_cham_outline", Tooltip = "A second, slightly larger layer around each part" })
    HcMore:Depends({ { "hit_cham_outline", true } }, function(box)
        pickColor(box, "Outline colour", "hit_cham_outline_color", WHITE, 0.4)
    end)
    HcMore:Slider({ Name = "Max at once", Flag = "hit_cham_max", Min = 1, Max = 12, Default = 12, Decimals = 1, Tooltip = "The oldest cham is removed first" })
    hidden("hit_cham_fx", "Dropdown", {}, HitFx.legacy):OnChanged(function(value)
        if next(value) ~= nil then HitFx.pending = true end
    end)
    hidden("hit_cham_fx_amount", "Slider", 1)
    local HitSnd = Hits:Section({ Name = "Hit sound", Column = 3, Icon = "music" })
    HitSnd:Toggle({ Name = "Hit sound", Flag = "hit_snd" })
    HitSnd:Dropdown({ Name = "Sound", Flag = "hit_snd_id", Items = HIT_SOUND_ORDER, Default = "Gamesense", Searchable = true })
    HitSnd:Slider({ Name = "Volume", Flag = "hit_snd_vol", Min = 0.1, Max = 5, Default = 1.5, Decimals = 0.01 })
    HitSnd:Slider({ Name = "Pitch", Flag = "hit_snd_pitch", Min = 0.5, Max = 2, Default = 1, Decimals = 0.01 })
    HitSnd:Toggle({ Name = "Different on headshot", Flag = "hit_snd_head" })
    HitSnd:Dropdown({ Name = "Headshot sound", Flag = "hit_snd_head_id", Items = HIT_SOUND_ORDER, Default = "Alt Headshot kill", Searchable = true })
    HitSnd:Slider({ Name = "Max length", Flag = "hit_snd_max", Min = 0, Max = 3, Default = 0.6, Decimals = 0.05, Suffix = " s", Tooltip = "Stops long sounds (Glass Tink is about 4 s) after this long; 0 plays the whole sound" })
    HitSnd:Input({ Name = "Custom sound id", Flag = "hit_snd_custom", Placeholder = "id or link, used when Sound is Custom" })
    HitSnd:Button({ Name = "Preview", Callback = function() Util.guard("hit-preview", Feedback.preview, "hit_snd", "Gamesense") end })
    local HitEffects = Hits:Section({ Name = "Hit effects", Column = 2, Icon = "sparkles" })
    local HfMore = HitEffects:Toggle({ Name = "Hit effects", Flag = "hit_fx_on", Tooltip = "Local particle effects where your bullets hit enemies, separate from hit chams" }):Colorpicker({ Name = "Hit effect", Flag = "hit_fx_color", Default = Color3.fromRGB(255, 120, 80), Alpha = 0 }):Settings("Hit effects", 240)
    HitEffects:Dropdown({ Name = "Effects", Flag = "hit_fx_list", Items = HitFx.names, Multi = true, Default = { "Sparks", "Glow burst" }, Tooltip = "Pick several to layer them" })
    HitEffects:Slider({ Name = "Size", Flag = "hit_fx_size", Min = 0.25, Max = 3, Default = 1, Decimals = 0.05, Suffix = "x" })
    HitEffects:Slider({ Name = "Amount", Flag = "hit_fx_amount", Min = 0.25, Max = 3, Default = 1, Decimals = 0.05, Suffix = "x" })
    HitEffects:Slider({ Name = "Lifetime", Flag = "hit_fx_time", Min = 0.3, Max = 2.5, Default = 1, Decimals = 0.05, Suffix = "x" })
    HitEffects:Toggle({ Name = "Headshots only", Flag = "hit_fx_head" })
    HitEffects:Dropdown({ Name = "Position", Flag = "hit_fx_at", Items = { "Hit point", "Body centre" }, Default = "Hit point" })
    HfMore:Slider({ Name = "Max at once", Flag = "hit_fx_max", Min = 1, Max = 16, Default = 12, Decimals = 1, Tooltip = "The oldest effect is removed first" })
    local Dmg = Hits:Section({ Name = "Damage numbers", Column = 2, Icon = "target" })
    Dmg:Toggle({ Name = "Custom damage numbers", Flag = "dmg_on", Tooltip = "Replaces the game's floating numbers; the game's Damage Numbers setting must be on" })
    Dmg:Label({ Name = "Head" }):Colorpicker({ Name = "Head", Flag = "dmg_head", Default = Color3.fromRGB(255, 102, 102) })
    Dmg:Label({ Name = "Torso" }):Colorpicker({ Name = "Torso", Flag = "dmg_torso", Default = Color3.fromRGB(255, 150, 0) })
    Dmg:Label({ Name = "Limbs" }):Colorpicker({ Name = "Limbs", Flag = "dmg_limb", Default = Color3.fromRGB(255, 255, 0) })
    Dmg:Slider({ Name = "Size", Flag = "dmg_size", Min = 8, Max = 32, Default = 16, Decimals = 1, Suffix = " px" })
    Dmg:Slider({ Name = "Rise", Flag = "dmg_rise", Min = 10, Max = 150, Default = 60, Decimals = 1, Suffix = " px" })
    Dmg:Slider({ Name = "Duration", Flag = "dmg_time", Min = 0.4, Max = 3, Default = 1.1, Decimals = 0.01, Suffix = " s" })

    local Kills = Subs.Kills
    local KillSnd = Kills:Section({ Name = "Kill sound", Column = 1, Icon = "music" })
    KillSnd:Toggle({ Name = "Kill sound", Flag = "kill_snd", Tooltip = "Plays when you kill a player (from the game's death event)" })
    KillSnd:Dropdown({ Name = "Sound", Flag = "kill_snd_id", Items = KILL_SOUND_ORDER, Default = "Alt Killshot", Searchable = true })
    KillSnd:Slider({ Name = "Volume", Flag = "kill_snd_vol", Min = 0.1, Max = 5, Default = 1.5, Decimals = 0.01 })
    KillSnd:Slider({ Name = "Pitch", Flag = "kill_snd_pitch", Min = 0.5, Max = 2, Default = 1, Decimals = 0.01 })
    KillSnd:Slider({ Name = "Max length", Flag = "kill_snd_max", Min = 0, Max = 6, Default = 2.5, Decimals = 0.05, Suffix = " s", Tooltip = "Stops long sounds (Killer7 Crit is about 5 s) after this long; 0 plays the whole sound" })
    KillSnd:Input({ Name = "Custom sound id", Flag = "kill_snd_custom", Placeholder = "id or link, used when Sound is Custom" })
    KillSnd:Button({ Name = "Preview", Callback = function() Util.guard("kill-preview", Feedback.preview, "kill_snd", "Alt Killshot") end })
    local Kill = Kills:Section({ Name = "Kill effects", Column = 2, Icon = "flame" })
    local Fx = Kill:Toggle({ Name = "Kill effects", Flag = "kill_fx", Tooltip = "Plays local effects on the corpse of players you kill (from the game's death event). Visual only, nothing is sent to the server" }):Settings("Kill effects", 260)
    Fx:Dropdown({ Name = "Effects", Flag = "kill_fx_list", Items = KillFx.names, Multi = true, Default = { "Dissolve", "Lightning" } })
    pickColor(Fx, "Colour", "kill_fx_color", Color3.fromRGB(102, 204, 255))
    pickColor(Fx, "Secondary", "kill_fx_color2", Color3.fromRGB(235, 248, 255))
    Fx:Slider({ Name = "Intensity", Flag = "kill_fx_int", Min = 0.3, Max = 3, Default = 1, Decimals = 0.1 })
    Fx:Slider({ Name = "Duration", Flag = "kill_fx_dur", Min = 0.5, Max = 6, Default = 2.5, Decimals = 0.1, Suffix = " s", Tooltip = "Length of Dissolve, Pillar, Tombstone, Crystallize and Holo-scan" })
    Fx:Slider({ Name = "Screen flash only near", Flag = "kill_fx_flash_dist", Min = 20, Max = 500, Default = 150, Decimals = 1, Suffix = " studs" })
    Fx:Toggle({ Name = "Play sound", Flag = "kill_fx_sound" })
    Fx:Depends({ { "kill_fx_sound", true } }, function(box)
        box:Input({ Name = "Sound id", Flag = "kill_fx_sound_id", Placeholder = "rbxassetid or number" })
    end)
    Kill:Dropdown({ Name = "Corpse effects", Flag = "kill_fx_corpse", Items = KillFx.corpseNames, Multi = true, Tooltip = "Act on the body itself, locally. Only one movement effect (everything except Disintegrate, Ghost, Freeze, Confetti and Vaporize) runs per corpse: the first one in this list" })
    Kill:Slider({ Name = "Corpse effect time", Flag = "kill_fx_corpse_dur", Min = 1, Max = 8, Default = 3, Decimals = 0.1, Suffix = " s" })
    Kill:Slider({ Name = "Corpse particles", Flag = "kill_fx_corpse_int", Min = 0.3, Max = 3, Default = 1, Decimals = 0.1 })
    Kill:Slider({ Name = "Float height", Flag = "kill_fx_corpse_height", Min = 2, Max = 30, Default = 10, Decimals = 1, Suffix = " studs", Tooltip = "How high Zero-G float, Ascend, Ghost, Ragdoll launch, Balloon and Puppet carry the body" })
    local Dead = Kills:Section({ Name = "Corpse chams", Column = 3, Icon = "ghost" })
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
    local Run = Kills:Section({ Name = "Kill streak", Column = 3, Icon = "flame" })
    local RunMore = Run:Toggle({ Name = "Kill streak", Flag = "streak_on", Tooltip = "Banner and announcer for kills in quick succession: each kill within the window of the previous one raises the count" }):Colorpicker({ Name = "Streak", Flag = "streak_color", Default = Color3.fromRGB(255, 80, 90), Alpha = 0 }):Colorpicker({ Name = "Peak", Flag = "streak_color2", Default = Color3.fromRGB(255, 200, 70), Alpha = 0 }):Settings("Kill streak", 250)
    Run:Dropdown({ Name = "Style", Flag = "streak_style", Items = Streak.styles, Default = "Valorant bars" })
    Run:Slider({ Name = "Window", Flag = "streak_window", Min = 1, Max = 15, Default = 4, Decimals = 0.1, Suffix = " s", Tooltip = "Longest gap between two kills that still continues the streak" })
    Run:Dropdown({ Name = "Streak sound set", Flag = "streak_snd_set", Items = STREAK_SET_ORDER, Default = "Valorant", Searchable = true, Tooltip = "Counts past the end of a set repeat its last line. Spree sets (UT Spree, Halo, CoD) follow kills since your last death and only play on their thresholds" })
    Run:Slider({ Name = "Streak volume", Flag = "streak_snd_vol", Min = 0.1, Max = 5, Default = 1.5, Decimals = 0.01 })
    Run:Toggle({ Name = "Mute kill sound", Flag = "streak_mute_kill", Default = true, Tooltip = "Skips the normal kill sound when a streak sound plays for that kill" })
    Run:Button({ Name = "Test streak", Callback = function() Util.guard("streak-test", Streak.test) end })
    RunMore:Toggle({ Name = "Reset on death", Flag = "streak_reset_death", Default = true })
    RunMore:Slider({ Name = "Scale", Flag = "streak_scale", Min = 0.5, Max = 2, Default = 1, Decimals = 0.05, Suffix = "x" })
    RunMore:Slider({ Name = "Position Y", Flag = "streak_y", Min = 0.1, Max = 0.95, Default = 0.72, Decimals = 0.01, Tooltip = "Fraction of the screen height" })
    RunMore:Slider({ Name = "Duration", Flag = "streak_time", Min = 0.5, Max = 5, Default = 2.2, Decimals = 0.1, Suffix = " s" })
    RunMore:Toggle({ Name = "Show total streak", Flag = "streak_total", Default = true, Tooltip = "Kills since your last death, under the banner" })
    RunMore:Toggle({ Name = "Milestone notifications", Flag = "streak_milestone" })
    RunMore:Depends({ { "streak_milestone", true } }, function(box)
        box:Slider({ Name = "Milestone every", Flag = "streak_milestone_every", Min = 2, Max = 25, Default = 5, Decimals = 1, Suffix = " kills" })
    end)
    local Notice = Kills:Section({ Name = "Killcam", Column = 2, Icon = "eye" })
    Notice:Toggle({ Name = "Killcam notice", Flag = "killcam_notify", Default = true, Tooltip = "Estimate: the player you kill watches you on their killcam for up to 5 s, but they may skip it after 0.5 s and the game does not tell us. Closes early when they respawn, you die, they leave or the round ends" })
    Notice:Toggle({ Name = "Notice sound", Flag = "killcam_sound" })
    Notice:Toggle({ Name = "Debug kill events", Flag = "misc_debug_kills", Tooltip = "Prints one line per death event to the console (F9): victim, attacker, forced, the game thread identity and which kill features fired" })

    local Bullets = Subs.Bullets
    local Trace = Bullets:Section({ Name = "Bullet tracers", Column = 1, Icon = "zap" })
    Trace:Toggle({ Name = "Own bullets", Flag = "trace_on", Tooltip = "Draws a tracer from your barrel to where the shot lands" }):Colorpicker({ Name = "Tracer", Flag = "trace_color", Default = Color3.fromRGB(255, 94, 94) })
    Trace:Toggle({ Name = "Enemy bullets", Flag = "trace_enemy_on" }):Colorpicker({ Name = "Tracer", Flag = "trace_enemy_color", Default = Color3.fromRGB(94, 160, 255) })
    Trace:Toggle({ Name = "Team bullets", Flag = "trace_team_on" }):Colorpicker({ Name = "Tracer", Flag = "trace_team_color", Default = Color3.fromRGB(90, 220, 130) })
    local traceItems = { "Obelus", "Lightning", "DNA", "Beam", "Bolt", "Trail", "Zigzag", "Heartrate", "Chain", "Glitch", "Swirl" }
    for _, name in ipairs(Tracers.particleNames) do traceItems[#traceItems + 1] = name end
    Trace:Dropdown({ Name = "Tracer texture", Flag = "trace_texture", Items = traceItems, Default = "Lightning", Tooltip = "Comet to Void are particle tracers that follow the bullet's real path" })
    Trace:Slider({ Name = "Tracer lifetime", Flag = "trace_time", Min = 0.5, Max = 10, Default = 4, Decimals = 0.1, Suffix = " s" })
    Trace:Slider({ Name = "Tracer width", Flag = "trace_width", Min = 0.2, Max = 3, Default = 1, Decimals = 0.1, Suffix = "x" })
    Trace:Toggle({ Name = "Hide the game's beam", Flag = "trace_hide_beam", Default = true, Tooltip = "Turns off the game's own tracer beam on bullets that get a custom tracer" })
    local Style = Bullets:Section({ Name = "Tracer style", Column = 2, Icon = "sparkles" })
    local Glow = Style:Toggle({ Name = "Tracer glow", Flag = "trace_glow", Tooltip = "Full-bright beam plus a wider additive halo behind it" }):Settings("Tracer glow", 230)
    Glow:Slider({ Name = "Glow strength", Flag = "trace_glow_strength", Min = 0, Max = 10, Default = 4, Decimals = 0.1 })
    Glow:Toggle({ Name = "Glow uses tracer colour", Flag = "trace_glow_same", Default = true })
    Glow:Depends({ { "trace_glow_same", false } }, function(box)
        box:Label({ Name = "Glow colour" }):Colorpicker({ Name = "Glow colour", Flag = "trace_glow_color", Default = Color3.fromRGB(255, 255, 255) })
    end)
    local Grad = Style:Toggle({ Name = "Tracer gradient", Flag = "trace_gradient", Tooltip = "Colours the tracer from start to end along its whole length, replacing the single tracer colour" }):Settings("Tracer gradient", 230)
    Grad:Label({ Name = "Gradient start" }):Colorpicker({ Name = "Gradient start", Flag = "trace_grad_start", Default = Color3.fromRGB(255, 94, 94) })
    Grad:Label({ Name = "Gradient end" }):Colorpicker({ Name = "Gradient end", Flag = "trace_grad_end", Default = Color3.fromRGB(94, 160, 255) })
    Grad:Slider({ Name = "Gradient fade", Flag = "trace_grad_fade", Min = 0, Max = 1, Default = 0, Decimals = 0.01, Tooltip = "Fades the tracer toward its far end" })
    Grad:Toggle({ Name = "Rainbow", Flag = "trace_rainbow", Tooltip = "Cycles hue along the tracer instead of the two colours" })
    Style:Depends({ { "trace_texture", Tracers.particleNames } }, function(box)
        box:Slider({ Name = "Particle size", Flag = "trace_fx_size", Min = 0.25, Max = 3, Default = 1, Decimals = 0.05, Suffix = "x", Tooltip = "Particle tracers only; Tracer width sets their core beam" })
        box:Slider({ Name = "Particle density", Flag = "trace_fx_density", Min = 0.25, Max = 3, Default = 1, Decimals = 0.05, Suffix = "x", Tooltip = "Particle tracers only" })
        box:Toggle({ Name = "Particle impact burst", Flag = "trace_fx_impact", Default = true, Tooltip = "Particle tracers burst where the bullet hits" })
    end)
    local Imp = Bullets:Section({ Name = "Bullet impacts", Column = 3, Icon = "flame" })
    local ImpMore = Imp:Toggle({ Name = "Bullet impacts", Flag = "impact_on", Tooltip = "Local effects where your bullets hit the world, at the same hit point the tracers use" }):Colorpicker({ Name = "Impact", Flag = "impact_color", Default = Color3.fromRGB(120, 200, 255), Alpha = 0 }):Settings("Bullet impacts", 240)
    Imp:Toggle({ Name = "Enemy bullets too", Flag = "impact_enemy", Tooltip = "Same bullets the enemy tracers use; teammates are skipped" })
    Imp:Dropdown({ Name = "Effects", Flag = "impact_list", Items = Impacts.names, Multi = true, Default = { "Spark burst", "Glow ring" }, Tooltip = "Pick several to layer them" })
    Imp:Slider({ Name = "Size", Flag = "impact_size", Min = 0.25, Max = 3, Default = 1, Decimals = 0.05, Suffix = "x" })
    Imp:Slider({ Name = "Lifetime", Flag = "impact_time", Min = 0.2, Max = 5, Default = 1.2, Decimals = 0.05, Suffix = " s" })
    ImpMore:Slider({ Name = "Particle density", Flag = "impact_density", Min = 0.25, Max = 3, Default = 1, Decimals = 0.05, Suffix = "x" })
    ImpMore:Toggle({ Name = "Surface aligned", Flag = "impact_align", Default = true, Tooltip = "Lays the effect on the surface using the hit normal; off keeps it flat" })
    ImpMore:Slider({ Name = "Max at once", Flag = "impact_max", Min = 1, Max = 30, Default = 30, Decimals = 1, Tooltip = "The oldest impact is removed first" })
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
    SaveManager:SetIgnoreIndexes({ "MenuKeybind", "menu_notify_corner", "ui_view_Legit", "ui_view_ESP", "ui_view_World", "ui_view_FX", "ui_view_Misc" })
    local skinIndexes = { "skin_class", "skin_search", "skin_weapon", "skin_slot", "skin_tex_color", "skin_brick_color", "skin_material",
        "skin_preset_src", "skin_preset", "skin_preset_name", "skin_preset_search", "skin_preset_weapon", "skin_case", "skin_pick", "skin_view", "skin_cases" }
    for _, spec in ipairs(Skins.sliders) do skinIndexes[#skinIndexes + 1] = spec.flag end
    SaveManager:SetIgnoreIndexes(skinIndexes)
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
    Util.guard("dsky", DynSky.step, cam, now, dt)

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
        Util.guard("pf-events", Feedback.drain)
        Util.guard("feedback", Feedback.step, cam, center, now)
        Util.guard("bulletfx", Tracers.drain, now)
        Util.guard("tracers", Tracers.step, now)
        Util.guard("impacts", Impacts.step, now)
        Util.guard("hitchams", HitCham.step, now)
        Util.guard("hitfx", HitFx.step, now)
        Util.guard("nades", Nades.step, cam, now)
        Util.guard("streak", Streak.step, now)
        return
    end

    if now - Loop.hookAt > 3 then
        Loop.hookAt = now
        Util.guard("hooks", Feedback.hook)
        Util.guard("nadehook", Nades.hook)
        Util.guard("knifehook", Knife.hook)
        Util.guard("localhook", Local.hook)
        Util.guard("skinhook", Skins.hook)
    end
    Util.guard("pf-events", Feedback.drain)

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
    Util.guard("bulletfx", Tracers.drain, now)
    Util.guard("tracers", Tracers.step, now)
    Util.guard("impacts", Impacts.step, now)
    Util.guard("hitchams", HitCham.step, now)
    Util.guard("hitfx", HitFx.step, now)
    Util.guard("nades", Nades.step, cam, now)
    Util.guard("localvis", Local.step, now)
    Util.guard("corpse", Corpse.step, now)
    Util.guard("killfx", KillFx.step, now)
    Util.guard("killcam", Killcam.step, now)
    Util.guard("streak", Streak.step, now)
    Util.guard("skins", Skins.step, now)

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
