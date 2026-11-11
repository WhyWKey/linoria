
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

function Util.set(name, fallback)
    local value = flag(name, fallback)
    local out = {}
    if type(value) == "table" then
        for key, on in pairs(value) do
            if type(key) == "number" then out[on] = true elseif on then out[key] = true end
        end
    end
    return out
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
    if ThemeManager.SetDefaultTheme then ThemeManager:SetDefaultTheme("Aster Violet") end
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

local function wrapGroup(group, page, side)
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

local function surface(tab, onBox)
    local state = { load = { 0, 0 } }
    local function pick(side)
        if side == 1 or side == 2 then return side end
        return state.load[1] <= state.load[2] and 1 or 2
    end
    function state:Section(info)
        local side = pick(info.Side)
        local group = side == 1 and tab:AddLeftGroupbox(info.Name, info.Icon) or tab:AddRightGroupbox(info.Name, info.Icon)
        if onBox then onBox(group.Outer) end
        return wrapGroup(group, state, side)
    end
    function state:MultiSection(info)
        local side = pick(info.Side)
        local box = side == 1 and tab:AddLeftTabbox() or tab:AddRightTabbox()
        if onBox then onBox(box.Outer) end
        local sections = {}
        for index, name in ipairs(info.Sections) do
            sections[index] = wrapGroup(box:AddTab(name), state, side)
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
local OPTIONAL = { "PublicSettings", "NetworkClient", "HudCrosshairsInterface", "HudDamageInterface", "BulletInterface", "PlayerStatusEvents", "ContentInterface" }

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

function Game.canFire(weapon)
    if type(weapon) ~= "table" or type(weapon.canFire) ~= "function" then return true end
    local ok, state = pcall(weapon.canFire, weapon)
    return ok and state and true or false
end

function Game.isFirearm(weapon)
    return type(Game.stat(weapon, "bulletspeed")) == "number"
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
        record.entry, record.hash, record.torso, record.head = entry, hash, torso, head
        record.rendered, record.pos = rendered, position
        record.enemy = Game.isEnemy(entry, player)

        local health, maxHealth = 100, 100
        local okHealth, current, maximum = pcall(entry.getHealth, entry)
        if okHealth and type(current) == "number" then health, maxHealth = current, maximum or 100 end
        record.health, record.maxHealth = health, maxHealth

        local spring = entry._velspring
        local velocity = spring and spring.p
        record.velocity = typeof(velocity) == "Vector3" and velocity or Vector3.zero

        record.weaponName = nil
        if rendered then
            pcall(function()
                local weapon = entry:getWeaponObject()
                record.weaponName = weapon and weapon.weaponName
            end)
        end
        local okModel, model = pcall(object.getCharacterModel, object)
        record.model = (typeof(object._characterModel) == "Instance" and object._characterModel) or (okModel and typeof(model) == "Instance" and model) or torso.Parent

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

local Visible = { cache = setmetatable({}, { __mode = "k" }), nextFilter = 0 }
Visible.params = RaycastParams.new()
Visible.params.FilterType = Enum.RaycastFilterType.Exclude
pcall(function() Visible.params.RespectCanCollide = true end)

function Visible.refresh(now)
    if now < Visible.nextFilter then return end
    Visible.nextFilter = now + 1
    local list = {}
    local current = Game.camera()
    if current then list[#list + 1] = current end
    for _, name in ipairs({ "Ignore", "Players", "Roots" }) do
        local folder = Workspace:FindFirstChild(name)
        if folder then list[#list + 1] = folder end
    end
    Visible.params.FilterDescendantsInstances = list
end

function Visible.check(part, origin, now)
    local cached = Visible.cache[part]
    if cached and now - cached[1] < 0.06 then return cached[2] end
    local hit = Workspace:Raycast(origin, (part.Position - origin) * 0.998, Visible.params)
    local result = hit == nil
    Visible.cache[part] = { now, result }
    return result
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
    local list = {}
    local current = Game.camera()
    if current then list[#list + 1] = current end
    local ignore = Workspace:FindFirstChild("Ignore")
    if ignore then list[#list + 1] = ignore end
    params.FilterDescendantsInstances = list
    Barrel.params = params
end

function Barrel.update(cam, gameCam, weapon, now)
    Barrel.valid = false
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
        local hit = Workspace:Raycast(from, muzzle - from, Barrel.params)
        if hit then fire = hit.Position + hit.Normal * 0.01 end
    end
    local aim = Workspace:Raycast(fire, look * 2000, Barrel.params)
    Barrel.fire, Barrel.look = fire, look
    Barrel.hit = aim and aim.Position or fire + look * 500
    local muzzlePoint, muzzleFront = Draw.project(cam, muzzle)
    Barrel.muzzle2d = muzzleFront and muzzlePoint or nil
    local hitPoint, hitFront = Draw.project(cam, Barrel.hit)
    Barrel.hit2d = hitFront and hitPoint or nil
    Barrel.valid = true
end

function Barrel.point(mode, center)
    if not Barrel.valid then return center end
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
    lShoulder = { "Left Arm", Vector3.new(0, 0.5, 0) }, lHand = { "Left Arm", Vector3.new(0, -0.7, 0) },
    rShoulder = { "Right Arm", Vector3.new(0, 0.5, 0) }, rHand = { "Right Arm", Vector3.new(0, -0.7, 0) },
    lHip = { "Left Leg", Vector3.new(0, 0.7, 0) }, lFoot = { "Left Leg", Vector3.new(0, -0.7, 0) },
    rHip = { "Right Leg", Vector3.new(0, 0.7, 0) }, rFoot = { "Right Leg", Vector3.new(0, -0.7, 0) },
}
local BONES = {
    { "head", "shoulderMid" }, { "shoulderMid", "hipMid" },
    { "lShoulder", "rShoulder" }, { "lShoulder", "lHand" }, { "rShoulder", "rHand" },
    { "lHip", "rHip" }, { "lHip", "lFoot" }, { "rHip", "rFoot" },
}

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
    if points.lShoulder and points.rShoulder then points.shoulderMid = (points.lShoulder + points.rShoulder) * 0.5 end
    if points.lHip and points.rHip then points.hipMid = (points.lHip + points.rHip) * 0.5 end
    return points
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
    S.case = flag("esp_case", "Normal")
    S.visOverride = flag("esp_vis", false)
    S.visColor, S.occColor = flag("esp_vis_color", Color3.fromRGB(80, 255, 120)), flag("esp_occ_color", Color3.fromRGB(255, 80, 80))
    S.chamMode = flag("cham_mode", "Through walls")
    S.chamGrow, S.chamGlowSize = flag("cham_grow", 0.1), flag("cham_glow_size", 0.35)
    S.chamGlow, S.chamRound = flag("cham_glow", true), flag("cham_round_head", true)
    S.oovSize, S.oovRadius = flag("oov_size", 14), flag("oov_radius", 40)
    S.viewLen = flag("esp_view_len", 8)
end

function ESP.make()
    local o = { all = {}, strips = {}, corners = {}, cornerEdges = {}, bones = {}, hidden = false }
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
    for index = 1, #BONES do o.bones[index] = line(1, 3) end
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

function Chams.getContainer()
    if Chams.container and Chams.container.Parent then return Chams.container end
    local folder = Instance.new("Folder")
    folder.Name = Util.randomName()
    local parents = {}
    pcall(function() if gethui then parents[#parents + 1] = gethui() end end)
    pcall(function() parents[#parents + 1] = game:GetService("CoreGui") end)
    parents[#parents + 1] = Workspace.CurrentCamera
    for _, parent in ipairs(parents) do
        if parent and pcall(function() folder.Parent = parent end) and folder.Parent then
            Chams.container = folder
            return folder
        end
    end
    return nil
end

function Chams.acquire(round)
    local class = round and "SphereHandleAdornment" or "BoxHandleAdornment"
    local list = Chams.pool[class]
    local adornment = list and table.remove(list)
    if adornment then return adornment end
    local container = Chams.getContainer()
    if not container then return nil end
    local ok, created = pcall(Instance.new, class)
    if not (ok and created) then return nil end
    created.Name = Util.randomName()
    created.AdornCullingMode = Enum.AdornCullingMode.Never
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

function Chams.remove(player)
    local entry = Chams.objs[player]
    if not entry then return end
    for _, slot in pairs(entry.parts) do Chams.dropSlot(slot) end
    Chams.objs[player] = nil
end

function Chams.hide(entry)
    if entry.hidden then return end
    entry.hidden = true
    for _, slot in pairs(entry.parts) do
        slot.sig = nil
        for _, adornment in pairs(slot.layers) do adornment.Visible = false end
    end
end

function Chams.build(slot)
    local behind, visible, glow = Chams.acquire(slot.round), Chams.acquire(slot.round), Chams.acquire(slot.round)
    if not (behind and visible and glow) then
        Chams.release(behind)
        Chams.release(visible)
        Chams.release(glow)
        return false
    end
    behind.AlwaysOnTop, behind.ZIndex = true, 1
    visible.AlwaysOnTop, visible.ZIndex = false, -1
    glow.AlwaysOnTop, glow.ZIndex = false, -2
    slot.layers = { behind = behind, visible = visible, glow = glow }
    return true
end

function Chams.style(slot, part, name, cfg, S)
    local layers = slot.layers
    local grow, extra = S.chamGrow, S.chamGlowSize
    for _, adornment in pairs(layers) do adornment.Adornee = part end
    if slot.round then
        local radius = 0.62 + grow * 0.5
        layers.behind.Radius, layers.visible.Radius, layers.glow.Radius = radius, radius, radius + extra * 0.5
    else
        local size = PART_SIZES[name] + Vector3.new(grow, grow, grow)
        layers.behind.Size, layers.visible.Size = size, size
        layers.glow.Size = size + Vector3.new(extra, extra, extra)
    end
    layers.behind.Color3, layers.behind.Transparency = cfg.chamHid, cfg.chamHidT
    layers.behind.Visible = S.chamMode == "Through walls"
    layers.visible.Color3, layers.visible.Transparency, layers.visible.Visible = cfg.chamVis, cfg.chamVisT, true
    layers.glow.Color3, layers.glow.Transparency = cfg.chamVis, 1 - (1 - cfg.chamVisT) * 0.35
    layers.glow.Visible = S.chamGlow
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
    local sig = table.concat({
        tostring(cfg.chamVis), cfg.chamVisT, tostring(cfg.chamHid), cfg.chamHidT,
        S.chamMode, S.chamGrow, tostring(S.chamGlow), S.chamGlowSize, tostring(S.chamRound),
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
            if not slot.layers.visible and not Chams.build(slot) then return end
            if slot.adornee ~= part or slot.sig ~= sig then
                slot.adornee, slot.sig = part, sig
                Chams.style(slot, part, name, cfg, S)
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
            local rel = cam.CFrame:PointToObjectSpace(rec.pos)
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
    o.dist.Visible, o.weapon.Visible = false, false
    if cfg.dist then
        o.dist.Text = caseText(S.case, math.floor(dist * STUDS_TO_M) .. "m")
        o.dist.Position = Vector2.new(x + w / 2, lineY)
        o.dist.Color, o.dist.Transparency, o.dist.Visible = cfg.distColor, cfg.distA, true
        lineY = lineY + S.size + 1
    end
    if cfg.weapon and rec.weaponName then
        o.weapon.Text = caseText(S.case, tostring(rec.weaponName))
        o.weapon.Position = Vector2.new(x + w / 2, lineY)
        o.weapon.Color, o.weapon.Transparency, o.weapon.Visible = cfg.weaponColor, cfg.weaponA, true
    end

    for index = 1, #BONES do o.bones[index].Visible = false end
    if cfg.skeleton then
        local points = ESP.bonePoints(rec.hash)
        if points then
            local color = tint(cfg.skeletonColor)
            for index, bone in ipairs(BONES) do
                local a, b = points[bone[1]], points[bone[2]]
                if a and b then
                    local pa, fa = Draw.project(cam, a)
                    local pb, fb = Draw.project(cam, b)
                    if fa and fb then setLine(o.bones[index], pa, pb, color, cfg.skeletonA, S.skelThick) end
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
        Chams.update(rec, nil, S)
        return
    end
    local visible = false
    if rec.rendered and S.visOverride then
        visible = Visible.check(rec.head, origin, now) or Visible.check(rec.torso, origin, now)
    end
    ESP.draw(cam, o, rec, cfg, S, now, origin, visible, dist, viewport, center)
    Chams.update(rec, cfg, S)
end

function ESP.step(cam, now, records)
    ESP.readSettings()
    ESP.readTeam("esp_enemy_", ESP.enemy)
    ESP.readTeam("esp_team_", ESP.team)
    local origin = cam.CFrame.Position
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

local Items = { drops = {}, grenades = {}, texts = {}, nextScan = 0 }

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
        local origin = cam.CFrame.Position
        local color, alpha, maxDistance = flag("item_drops_color", WHITE), Util.opacity("item_drops_color"), flag("item_dist", 300)
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
                    text.Font, text.Size = ESP.S.font or 2, ESP.S.size or 13
                    text.Text = tostring(instance.Name) .. " " .. math.floor(distance * STUDS_TO_M) .. "m"
                    text.Position = Vector2.new(point.X, point.Y)
                    text.Color, text.Transparency, text.Visible = color, alpha, true
                end
            end
        end
    end
    for index = used + 1, #Items.texts do Items.texts[index].Visible = false end
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
SKY_CHOICES[#SKY_CHOICES + 1] = "Custom"

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

function World.skyIds()
    local choice = val("world_sky_box")
    if choice == "Custom" then
        local ids = {}
        for number in string.gmatch(tostring(val("world_sky_custom") or ""), "%d+") do ids[#ids + 1] = number end
        if #ids == 1 then return { ids[1], ids[1], ids[1], ids[1], ids[1], ids[1] } end
        if #ids == 6 then return ids end
        return nil
    end
    return SKY_PRESETS[choice]
end

function World.stepSky(dt)
    local skyOn = on("world_skybox") == true
    local sky = Lighting:FindFirstChildOfClass("Sky")
    if on("world_nosky") and not skyOn then
        if sky and sky ~= World.ownSky then
            World.sky = sky
            pcall(function() sky.Parent = nil end)
        end
        sky = nil
    elseif World.sky and not World.sky.Parent then
        pcall(function() World.sky.Parent = Lighting end)
        sky = World.sky
    end
    if skyOn then
        if not sky then
            local ok, created = pcall(Instance.new, "Sky")
            if ok and created then
                created.Name = Util.randomName()
                pcall(function() created.Parent = Lighting end)
                World.ownSky, sky = created, created
            end
        end
        local ids = sky and World.skyIds()
        if ids then
            for index, face in ipairs(SKY_FACES) do put(sky, face, "rbxassetid://" .. ids[index]) end
        end
    elseif World.ownSky then
        want[World.ownSky], World.orig[World.ownSky] = nil, nil
        pcall(function() World.ownSky:Destroy() end)
        World.ownSky = nil
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
    tune("bloom", "BloomEffect", "world_bloom", function(object)
        object.Intensity, object.Size, object.Threshold = val("world_bloom_i"), val("world_bloom_s"), val("world_bloom_t")
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
    state.cells, state.preset, state.sig = {}, nil, nil
end

function World.buildCell(cam, def, gx, gz)
    local part = Instance.new("Part")
    part.Name = Util.randomName()
    part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
    part.Transparency = 1
    part.Size = Vector3.new(CELL, 0.5, CELL)
    local cell = { part = part, emitters = {}, gx = gx, gz = gz, nextAt = 0, open = false, x = (gx + 0.5) * CELL, z = (gz + 0.5) * CELL, ground = 0, camY = 0 }
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

function World.scanCell(cell, camY)
    local origin = Vector3.new(cell.x, camY + 3, cell.z)
    cell.camY = camY
    cell.open = Workspace:Raycast(origin, Vector3.new(0, 400, 0), Visible.params) == nil
    if not cell.open then return end
    local down = Workspace:Raycast(origin, Vector3.new(0, -400, 0), Visible.params)
    cell.ground = down and down.Position.Y or camY - 40
end

function World.shapeCell(cell, def, cfg, sig)
    cell.sig, cell.dirty = sig, false
    for _, entry in ipairs(cell.emitters) do entry.object.Enabled = cell.open end
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
        emitter.Rate = layer.count * cfg.density / ((lifeLo + lifeHi) * 0.5)
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
    local gx0, gz0 = math.floor(position.X / CELL), math.floor(position.Z / CELL)
    local range = math.clamp(math.floor(val("world_weather_range") or 2), 1, 3)
    local keep = {}
    for dx = -range, range do
        for dz = -range, range do
            if dx * dx + dz * dz <= (range + 0.5) * (range + 0.5) then
                local gx, gz = gx0 + dx, gz0 + dz
                local key = gx .. ":" .. gz
                keep[key] = true
                local cell = state.cells[key]
                if cell and cell.parented and not cell.part.Parent then
                    pcall(function() cell.part:Destroy() end)
                    cell = nil
                end
                if not cell then
                    cell = World.buildCell(cam, def, gx, gz)
                    state.cells[key] = cell
                end
                if now >= cell.nextAt then
                    cell.nextAt = now + 0.35 + ((dx * 7 + dz * 3) % 5) * 0.06
                    World.scanCell(cell, position.Y)
                    cell.dirty = true
                end
                if cell.dirty or cell.sig ~= sig then World.shapeCell(cell, def, cfg, sig) end
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
    if flag("world_fov", false) and camera and type(camera._baseFov) == "number" then
        if state.object ~= camera then state.object, state.orig, state.blend = camera, camera._baseFov, 0 end
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
        if type(zoom) == "number" then tanHalf = tanHalf * math.exp(zoom * (1 - flag("world_fov_mult", 1))) end
        camera._baseFov = math.clamp(math.deg(2 * math.atan(tanHalf)), 5, 150)
    elseif state.object then
        if state.orig and type(state.object._baseFov) == "number" then state.object._baseFov = state.orig end
        state.object, state.orig = nil, nil
    end
end

World.cross = { lines = {}, edges = {}, dot = Draw.new("Circle", { Filled = true, NumSides = 12, Radius = 1.5, ZIndex = 10, Visible = false }), angle = 0 }
for index = 1, 4 do
    World.cross.edges[index] = Draw.new("Line", { ZIndex = 9, Color = BLACK, Visible = false })
    World.cross.lines[index] = Draw.new("Line", { ZIndex = 10, Visible = false })
end

function World.stepCrosshair(center, now, dt)
    local cross = World.cross
    local shown = flag("cross_on", false)
    for index = 1, 4 do cross.lines[index].Visible, cross.edges[index].Visible = false, false end
    cross.dot.Visible = false
    if not shown then return end
    local color, alpha = flag("cross_color", WHITE), Util.opacity("cross_color")
    local length, thick, gap = flag("cross_len", 8), flag("cross_thick", 2), flag("cross_gap", 5)
    local outline = flag("cross_outline", true)
    if flag("cross_pulse", false) then gap = gap + flag("cross_pulse_range", 8) * (math.sin(now * flag("cross_pulse_speed", 3)) + 1) * 0.5 end
    if flag("cross_spin", false) then
        cross.angle = (cross.angle + math.rad(flag("cross_spin_speed", 90)) * dt) % (math.pi * 2)
    else
        cross.angle = 0
    end
    for index = 1, 4 do
        if not (flag("cross_t", false) and index == 4) then
            local angle = cross.angle + (index - 1) * math.pi / 2
            local direction = Vector2.new(math.cos(angle), math.sin(angle))
            if outline then
                local edge = cross.edges[index]
                edge.From, edge.To = center + direction * (gap - 1), center + direction * (gap + length + 1)
                edge.Thickness, edge.Visible = thick + 2, true
            end
            local line = cross.lines[index]
            line.From, line.To = center + direction * gap, center + direction * (gap + length)
            line.Color, line.Transparency, line.Thickness, line.Visible = color, alpha, thick, true
        end
    end
    if flag("cross_dot", false) then
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
    if World.sky and not World.sky.Parent then pcall(function() World.sky.Parent = Lighting end) end
    if World.ownSky then pcall(function() World.ownSky:Destroy() end) end
    World.cloudObject(false)
    World.dropWeather()
    for _, object in pairs(World.fx) do pcall(function() object:Destroy() end) end
    World.fx = {}
    if World.ownAtmos and World.atmos then pcall(function() World.atmos:Destroy() end) end
end)

local Trail = { list = {}, lines = {} }

function Trail.add(bullet, info, mine)
    local start = info.visualorigin or info.position
    if typeof(start) ~= "Vector3" then return end
    if #Trail.list >= 48 then table.remove(Trail.list, 1) end
    Trail.list[#Trail.list + 1] = { bullet = bullet, points = { { start, os.clock() } }, mine = mine }
end

function Trail.hideBeam(bullet)
    local beams = type(bullet._beamObject) == "table" and bullet._beamObject.beams
    if type(beams) ~= "table" then return end
    for _, beam in pairs(beams) do propSet(beam, "Enabled", false) end
end

function Trail.step(cam, now)
    local ownOn, otherOn = flag("trace_path_on", false), flag("trace_path_enemy_on", false)
    local duration, thick = flag("trace_time", 1.5), flag("trace_thick", 1.5)
    local ownColor, otherColor = flag("trace_path_color", Color3.fromRGB(255, 94, 94)), flag("trace_path_enemy_color", Color3.fromRGB(94, 160, 255))
    local used = 0
    if not (ownOn or otherOn) then Trail.list = {} end
    for index = #Trail.list, 1, -1 do
        local record = Trail.list[index]
        local points = record.points
        if not record.endedAt then
            local bullet = record.bullet
            local position = type(bullet) == "table" and bullet.position
            if typeof(position) == "Vector3" and (position - points[#points][1]).Magnitude > 0.05 then
                points[#points + 1] = { position, now }
            end
            if type(bullet) ~= "table" or bullet.pendingDeletion then record.endedAt = now end
        end
        while #points > 2 and now - points[1][2] > duration do table.remove(points, 1) end
        if record.endedAt and now - record.endedAt > duration then
            table.remove(Trail.list, index)
        elseif (record.mine and ownOn) or (not record.mine and otherOn) then
            local color = record.mine and ownColor or otherColor
            for segment = 1, #points - 1 do
                local alpha = 1 - (now - points[segment + 1][2]) / duration
                if alpha > 0 and used < 600 then
                    local from, fromFront = Draw.project(cam, points[segment][1])
                    local to, toFront = Draw.project(cam, points[segment + 1][1])
                    if fromFront and toFront then
                        used = used + 1
                        local line = Trail.lines[used]
                        if not line then
                            line = Draw.new("Line", { ZIndex = 4, Visible = false })
                            Trail.lines[used] = line
                        end
                        line.From, line.To, line.Color, line.Thickness, line.Transparency, line.Visible = from, to, color, thick, alpha, true
                    end
                end
            end
        end
    end
    for index = used + 1, #Trail.lines do Trail.lines[index].Visible = false end
end

local Nades = { list = {}, known = {}, lines = {}, texts = {}, hooked = false, scanAt = -math.huge, predAt = -math.huge }

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
    if Nades.params ~= nil then return Nades.params or nil end
    local map = Workspace:FindFirstChild("Map")
    if not map then return nil end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
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

function Nades.label(cam, position, lines)
    local point, front = Draw.project(cam, position)
    if not front then return end
    local y = point.Y
    for _, entry in ipairs(lines) do
        Nades.textUsed = Nades.textUsed + 1
        local text = Nades.texts[Nades.textUsed]
        if not text then
            text = Draw.text(13, 9)
            Nades.texts[Nades.textUsed] = text
        end
        text.Font, text.Size = ESP.S.font or 2, ESP.S.size or 13
        text.Text, text.Position, text.Color, text.Transparency, text.Visible = entry[1], Vector2.new(point.X, y), entry[2], 1, true
        y = y + (ESP.S.size or 13) + 1
    end
end

function Nades.verdict(damage)
    if damage == nil then return nil end
    if damage <= 0 then return "SAFE", flag("nade_safe_color", Color3.fromRGB(90, 255, 130)) end
    local shown = math.floor(damage + 0.5)
    local label = shown >= 100 and "LETHAL " .. shown or "-" .. shown .. " HP"
    return label, Util.lerpColor(Color3.fromRGB(255, 220, 60), flag("nade_danger_color", Color3.fromRGB(255, 60, 60)), math.clamp(damage / 100, 0, 1))
end

function Nades.simulate(origin, velocity, gravity, elasticity, friction, duration)
    local params = Nades.mapParams()
    local step = 0.05
    local points, bounces = { origin }, {}
    local position, speed = origin, velocity
    local elapsed = 0
    while elapsed < duration and #points < 130 do
        local move = speed * step + gravity * (0.5 * step * step)
        local hit = params and Workspace:Raycast(position, move, params)
        if hit then
            position = hit.Position + hit.Normal * 0.05
            local along = hit.Normal * speed:Dot(hit.Normal)
            speed = (speed - along) * (1 - friction) - along * elasticity + gravity * step
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
    local held = false
    if flag("nade_predict", false) and weapon and type(weapon.getWeaponType) == "function" then
        local ok, kind = pcall(weapon.getWeaponType, weapon)
        held = ok and kind == "Grenade" and type(weapon.isEquipped) == "function" and weapon:isEquipped() == true
    end
    if not held then
        Nades.pred = nil
        return
    end
    local pred = Nades.pred
    if not pred or pred.weapon ~= weapon or now - Nades.predAt > 0.05 then
        Nades.predAt = now
        local start, velocity = Nades.throwState(weapon)
        if not start then
            Nades.pred = nil
            return
        end
        local duration = Game.stat(weapon, "fusetime") or 5
        local okArmed, armed = pcall(weapon.isState, weapon, "armed")
        if okArmed and armed and type(weapon._fuseTime) == "number" then duration = math.max(weapon._fuseTime - Game.time(), 0.1) end
        local gravity = typeof(weapon._acceleration) == "Vector3" and weapon._acceleration or Vector3.new(0, -80, 0)
        local points, bounces = Nades.simulate(start, velocity, gravity, weapon._bounceElasticity or 0.2, weapon._frictionConstant or 0.08, duration)
        pred = { weapon = weapon, points = points, bounces = bounces, land = points[#points], duration = duration, cache = pred and pred.cache or {} }
        Nades.pred = pred
    end
    local color = flag("nade_predict_color", Color3.fromRGB(120, 200, 255))
    for index = 1, #pred.points - 1 do Nades.line(cam, pred.points[index], pred.points[index + 1], color, 1, 1.5) end
    if flag("nade_predict_bounce", true) then
        for _, point in ipairs(pred.bounces) do Nades.ring(cam, point, 0.8, color, 1) end
    end
    local data = weapon._weaponData or weapon.weaponData
    local verdict, verdictColor = Nades.verdict((Nades.damage(data, pred.land, origin, pred.cache, now)))
    local radius = data and type(data.damageGraph) == "table" and #data.damageGraph > 0 and data.damageGraph[#data.damageGraph].distance
    Nades.ring(cam, pred.land, 1.5, color, 1)
    if radius and flag("nade_ring", true) then Nades.ring(cam, pred.land, radius, verdictColor or color, 0.6) end
    local lines = { { string.format("Lands %.1fs", pred.duration), color } }
    if verdict and flag("nade_dmg", true) then lines[2] = { verdict, verdictColor } end
    Nades.label(cam, pred.land + Vector3.new(0, 1.5, 0), lines)
end

function Nades.step(cam, now)
    Nades.lineUsed, Nades.textUsed = 0, 0
    if flag("nade_on", false) then
        local ownOn, enemyOn = flag("nade_own", true), flag("nade_enemy", true)
        local maxDistance = flag("nade_dist", 400)
        local ownColor, enemyColor = flag("nade_own_color", Color3.fromRGB(120, 255, 170)), flag("nade_enemy_color", Color3.fromRGB(255, 90, 60))
        local root = Game.rootPart()
        local camPosition = cam.CFrame.Position
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
                    local lines = {}
                    if flag("nade_timer", true) then lines[#lines + 1] = { string.format("%.1fs", math.max(remaining, 0)), color } end
                    local verdict, verdictColor
                    record.cache = record.cache or {}
                    local damage, radius = Nades.damage(record.data, record.land, origin, record.cache, now)
                    verdict, verdictColor = Nades.verdict(damage)
                    if verdict and flag("nade_dmg", true) then lines[#lines + 1] = { verdict, verdictColor } end
                    if radius and flag("nade_ring", true) then Nades.ring(cam, record.land, radius, verdictColor or color, 0.7) end
                    if #lines > 0 then Nades.label(cam, position + Vector3.new(0, 1, 0), lines) end
                end
            end
        end
        if not Nades.hooked then
            Items.scan(now)
            for _, instance in ipairs(Items.grenades) do
                local position = instance.Parent and Items.position(instance)
                if position and (position - camPosition).Magnitude <= maxDistance then
                    Nades.label(cam, position, { { "Grenade " .. math.floor((position - camPosition).Magnitude * STUDS_TO_M) .. "m", enemyColor } })
                end
            end
        end
    end
    local root = Game.rootPart()
    Nades.predict(cam, now, root and root.Position or cam.CFrame.Position)
    for index = Nades.lineUsed + 1, #Nades.lines do Nades.lines[index].Visible = false end
    for index = Nades.textUsed + 1, #Nades.texts do Nades.texts[index].Visible = false end
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

function Feedback.onKill(info)
    if type(info) ~= "table" or info.attacker ~= LocalPlayer or info.victim == LocalPlayer then return end
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
                    if mine and flag("trace_on", false) then
                        bullet:setColor(flag("trace_color", Color3.fromRGB(255, 94, 94)))
                    elseif not mine and flag("trace_enemy_on", false) then
                        bullet:setColor(flag("trace_enemy_color", Color3.fromRGB(94, 160, 255)))
                    end
                    if (mine and flag("trace_path_on", false)) or (not mine and flag("trace_path_enemy_on", false)) then
                        Trail.add(bullet, info, mine)
                        if flag("trace_hide_beam", false) then Trail.hideBeam(bullet) end
                    end
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

local Legit = { target = nil, record = nil, part = nil, switchAt = 0, reactUntil = 0, moved = false, radius = 0, L = {} }
local GROUPS = { Head = { "Head" }, Torso = { "Torso" }, Arms = { "Left Arm", "Right Arm" }, Legs = { "Left Leg", "Right Leg" } }
local GROUP_ORDER = { "Head", "Torso", "Arms", "Legs" }

Legit.circle = Draw.new("Circle", { Thickness = 1, NumSides = 64, Filled = false, Visible = false, ZIndex = 5 })
Legit.circleFill = Draw.new("Circle", { NumSides = 64, Filled = true, Visible = false, ZIndex = 4 })
Legit.snapline = Draw.new("Line", { Thickness = 1, Visible = false, ZIndex = 6 })

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
    L.fovNear, L.fovFar = flag("legit_fov_near", 240), flag("legit_fov_far", 60)
    L.teamCheck = flag("legit_team_check", true)
    L.barrel = flag("legit_barrel", true)
    L.fovBarrel, L.fovAttach = flag("legit_fov_barrel", false), flag("legit_fov_attach", "Aim hit")
end

function Legit.radiusFor(distance)
    local L = Legit.L
    if not L.fovDynamic then return L.fovRadius end
    return Util.lerp(L.fovNear, L.fovFar, math.clamp(distance / math.max(L.maxdist, 1), 0, 1))
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

function Legit.pickPart(record, cam, origin, center, now, radius)
    local L = Legit.L
    local best, bestScore, preferred, preferredScore
    for _, group in ipairs(GROUP_ORDER) do
        if L.parts[group] then
            for _, partName in ipairs(GROUPS[group]) do
                local part = record.hash[partName]
                if part and part.Parent then
                    local point, front = Draw.project(cam, part.Position)
                    local screen = front and (point - center).Magnitude or 1e5
                    if (radius == nil and front or screen <= (radius or 0)) and (not L.visible or Visible.check(part, origin, now)) then
                        if not bestScore or screen < bestScore then best, bestScore = part, screen end
                        if group == L.choice and (not preferredScore or screen < preferredScore) then preferred, preferredScore = part, screen end
                    end
                end
            end
        end
    end
    if preferred then return preferred, preferredScore end
    return best, bestScore
end

function Legit.choose(records, cam, origin, center, now)
    local L = Legit.L
    local bestRecord, bestPart, bestScore
    for _, record in ipairs(records) do
        if record.rendered and (record.enemy or not L.teamCheck) then
            local distance = (record.torso.Position - origin).Magnitude
            if distance <= L.maxdist then
                local part, screen = Legit.pickPart(record, cam, origin, center, now, Legit.radiusFor(distance))
                if part then
                    local score = screen
                    if L.targetBy == "Distance" then score = distance
                    elseif L.targetBy == "Lowest health" then score = record.health * 1000 + screen end
                    if not bestScore or score < bestScore then bestRecord, bestPart, bestScore = record, part, score end
                end
            end
        end
    end
    return bestRecord, bestPart
end

function Legit.turn(gameCam, origin, aimPoint, dt, now, cam, barrelLook)
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

    local alpha = 1 - math.exp(-dt * 60 / math.max(L.smooth, 1))
    local stepPitch, stepYaw = deltaPitch * alpha, deltaYaw * alpha
    local cap = math.rad(L.speed) * dt
    local size = math.sqrt(stepPitch * stepPitch + stepYaw * stepYaw)
    if size > cap and size > 0 then
        stepPitch, stepYaw = stepPitch * cap / size, stepYaw * cap / size
    end

    local base = gameCam:getAngles()
    if typeof(base) ~= "Vector3" then return false end
    local pitch, yaw = base.X + stepPitch, base.Y + stepYaw
    local cosPitch = math.cos(pitch)
    gameCam:setLookVector(Vector3.new(-cosPitch * math.sin(yaw), math.sin(pitch), -cosPitch * math.cos(yaw)))
    return true
end

function Legit.drawFov(center)
    local L = Legit.L
    local show = flag("legit_fov_draw", true) and L.aim
    Legit.circle.Visible = show
    if not show then
        Legit.circleFill.Visible = false
        return
    end
    local radius = L.fovRadius
    if L.fovDynamic then radius = Legit.target and Legit.radius or L.fovNear end
    local color = flag("legit_fov_color", WHITE)
    if Legit.target and flag("legit_fov_lock", true) then color = flag("legit_fov_lock_color", color) end
    Legit.circle.Position, Legit.circle.Radius, Legit.circle.Color = center, radius, color
    Legit.circle.Thickness = flag("legit_fov_thick", 1)
    local filled = flag("legit_fov_fill", false)
    Legit.circleFill.Visible = filled
    if filled then
        Legit.circleFill.Position, Legit.circleFill.Radius = center, radius
        Legit.circleFill.Color = flag("legit_fov_fill_color", WHITE)
        Legit.circleFill.Transparency = 1 - Util.alpha("legit_fov_fill_color", 0.9)
    end
end

function Legit.stepAim(dt, cam, now, records, screen)
    local L = Legit.L
    Legit.moved = false
    local center = L.fovBarrel and Barrel.point(L.fovAttach, screen) or screen
    Legit.drawFov(center)
    Legit.snapline.Visible = false

    local weapon = Game.weapon()
    local active = L.aim and Util.keyActive("legit_aim_key") and not Util.menuOpen() and not Util.typing()
    if not (active and weapon and Game.isFirearm(weapon)) then Legit.target = nil return end
    if L.ads and not Game.aiming(weapon) then Legit.target = nil return end
    if L.shooting and not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then Legit.target = nil return end

    local gameCam = Game.gameCamera()
    if not gameCam then return end
    local useBarrel = L.barrel and Barrel.valid
    local origin = useBarrel and Barrel.fire or cam.CFrame.Position

    local record, part
    if Legit.target and L.sticky then
        local held = Entities.byPlayer[Legit.target]
        if held and held.seen and held.rendered and (held.enemy or not L.teamCheck) then
            record = held
            part = Legit.pickPart(held, cam, origin, center, now, nil)
            Legit.record = held
            Legit.radius = Legit.radiusFor((held.torso.Position - origin).Magnitude)
            if not part then return end
        else
            Legit.target = nil
        end
    end
    if not record then
        record, part = Legit.choose(records, cam, origin, center, now)
        if not record then Legit.target = nil return end
    end

    if Legit.target ~= record.player then
        if Legit.target and now - Legit.switchAt < L.switch / 1000 then return end
        Legit.target = record.player
        Legit.switchAt = now
        Legit.reactUntil = now + L.react / 1000
    end
    Legit.part, Legit.record = part, record
    Legit.radius = Legit.radiusFor((record.torso.Position - origin).Magnitude)

    if flag("legit_snapline", false) then
        local point, front = Draw.project(cam, part.Position)
        if front then
            Legit.snapline.From, Legit.snapline.To = center, point
            Legit.snapline.Color = flag("legit_snapline_color", WHITE)
            Legit.snapline.Visible = true
        end
    end
    if now < Legit.reactUntil then return end
    local aimPoint = Legit.lead(origin, part.Position, record.velocity, weapon)
    Legit.moved = Legit.turn(gameCam, origin, aimPoint, dt, now, cam, useBarrel and Barrel.look or nil)
end

local Recoil = { body = nil, head = nil, last = Vector3.zero, shown = Vector3.zero }

function Legit.stepRecoil(now)
    local gameCam = Game.gameCamera()
    if not gameCam then return end
    local body, head = gameCam._cameraBodySprings, gameCam._cameraHeadSprings
    local offset = Vector3.zero
    pcall(function()
        if body then offset = offset + body:getP() end
        if head then offset = offset + head:getP() end
    end)
    Recoil.shown = offset
    if body ~= Recoil.body or head ~= Recoil.head then
        Recoil.body, Recoil.head, Recoil.last = body, head, offset
        return
    end
    local delta = offset - Recoil.last
    Recoil.last = offset

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

    local origin, direction = cam.CFrame.Position, cam.CFrame.LookVector
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

local Pages = {
    Legit = UI.page("Legit", "crosshair"),
    Rage = UI.page("Rage", "swords"),
    ESP = UI.page("ESP", "eye"),
    World = UI.page("World", "globe"),
    Misc = UI.page("Misc", "shapes"),
}
local Status = {}

do
    local Subs = Pages.Legit:SubTabs({ { "Aim Assist", "crosshair" }, { "Trigger Bot", "zap" }, { "Recoil", "target" } })

    local Aim = Subs["Aim Assist"]
    local Master = Aim:Section({ Name = "Aim assist", Side = 1, Icon = "crosshair" })
    Master:Toggle({ Name = "Enabled", Flag = "legit_aim", Tooltip = "Turns your view toward the target through the game's camera while the key is held" }):Keybind({ Name = "Aim key", Flag = "legit_aim_key", Default = "MB2", Mode = "Hold" })
    Master:Toggle({ Name = "Team check", Flag = "legit_team_check", Default = true, Tooltip = "Only enemies are targeted (shared with the triggerbot)" })
    Master:Toggle({ Name = "Visible only", Flag = "legit_visible", Default = true })
    Master:Toggle({ Name = "Only while aiming down sights", Flag = "legit_ads" })
    Master:Toggle({ Name = "Only while shooting", Flag = "legit_shooting" })
    Master:Toggle({ Name = "Aim from barrel", Flag = "legit_barrel", Default = true, Tooltip = "Uses the weapon's bullet origin and direction (as the game computes them) for visibility, prediction and aiming; the camera is still the only thing that moves" })
    Master:Dropdown({ Name = "Hitbox priority", Flag = "legit_priority", Items = { "Closest", "Head", "Torso" }, Default = "Closest", Tooltip = "Closest picks the part nearest the crosshair; Head/Torso prefer that part when it qualifies" })
    Master:Dropdown({ Name = "Hitboxes", Flag = "legit_parts", Items = { "Head", "Torso", "Arms", "Legs" }, Multi = true, Default = { "Head", "Torso" } })
    Master:Dropdown({ Name = "Target by", Flag = "legit_target_by", Items = { "Crosshair", "Distance", "Lowest health" }, Default = "Crosshair" })

    local Smooth, Target, Predict = Aim:MultiSection({ Sections = { "Smoothing", "Target", "Prediction" }, Side = 1 })
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

    local Fov = Aim:Section({ Name = "FOV", Side = 2, Icon = "scan" })
    Fov:Toggle({ Name = "Draw FOV circle", Flag = "legit_fov_draw", Default = true }):Colorpicker({ Name = "Circle", Flag = "legit_fov_color", Default = WHITE, Alpha = 0 })
    Fov:Toggle({ Name = "Filled", Flag = "legit_fov_fill" }):Colorpicker({ Name = "Fill", Flag = "legit_fov_fill_color", Default = WHITE, Alpha = 0.92 })
    Fov:Toggle({ Name = "Locked colour", Flag = "legit_fov_lock", Default = true, Tooltip = "The circle changes colour while a target is held" }):Colorpicker({ Name = "Locked", Flag = "legit_fov_lock_color", Default = Color3.fromRGB(255, 80, 80), Alpha = 0 })
    Fov:Toggle({ Name = "Attach to barrel", Flag = "legit_fov_barrel", Tooltip = "Centres the circle on the weapon barrel instead of the screen centre" })
    Fov:Dropdown({ Name = "Attach point", Flag = "legit_fov_attach", Items = { "Aim hit", "Muzzle" }, Default = "Aim hit", Tooltip = "Aim hit is where the barrel is pointing; Muzzle is the barrel tip" })
    Fov:Slider({ Name = "Radius", Flag = "legit_fov", Min = 10, Max = 800, Default = 120, Decimals = 1, Suffix = " px" })
    Fov:Slider({ Name = "Thickness", Flag = "legit_fov_thick", Min = 1, Max = 4, Default = 1, Decimals = 0.1, Suffix = " px" })
    Fov:Toggle({ Name = "Dynamic radius", Flag = "legit_fov_dynamic", Tooltip = "The radius shrinks with the target's distance" })
    Fov:Slider({ Name = "Radius when close", Flag = "legit_fov_near", Min = 10, Max = 800, Default = 240, Decimals = 1, Suffix = " px" })
    Fov:Slider({ Name = "Radius at max distance", Flag = "legit_fov_far", Min = 10, Max = 800, Default = 60, Decimals = 1, Suffix = " px" })
    Fov:Toggle({ Name = "Target line", Flag = "legit_snapline", Tooltip = "A line from the crosshair to the aimed body part" }):Colorpicker({ Name = "Line", Flag = "legit_snapline_color", Default = Color3.fromRGB(255, 80, 80), Alpha = 0 })

    local Info = Aim:Section({ Name = "Status", Side = 2, Icon = "info" })
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

    local Trig = Subs["Trigger Bot"]
    local TriggerBox = Trig:Section({ Name = "Trigger bot", Side = 1, Icon = "zap" })
    TriggerBox:Toggle({ Name = "Enabled", Flag = "trig_on", Tooltip = "Fires when the crosshair is on an enemy hitbox" }):Keybind({ Name = "Trigger key", Flag = "trig_key", Default = "None", Mode = "Always" })
    TriggerBox:Toggle({ Name = "Visible only", Flag = "trig_visible", Default = true })
    TriggerBox:Toggle({ Name = "Only while aiming down sights", Flag = "trig_ads" })
    TriggerBox:Dropdown({ Name = "Hitboxes", Flag = "trig_parts", Items = { "Head", "Torso", "Arms", "Legs" }, Multi = true, Default = { "Head", "Torso" } })
    TriggerBox:Slider({ Name = "Hitbox size", Flag = "trig_scale", Min = 0.4, Max = 1.6, Default = 1, Decimals = 0.01, Suffix = "x" })
    local Timing = Trig:Section({ Name = "Timing", Side = 2, Icon = "clock" })
    Timing:Slider({ Name = "Max distance", Flag = "trig_dist", Min = 50, Max = 1500, Default = 400, Decimals = 1, Suffix = " studs" })
    Timing:Slider({ Name = "Delay", Flag = "trig_delay", Min = 0, Max = 300, Default = 40, Decimals = 1, Suffix = " ms", Tooltip = "How long the crosshair must stay on the target before firing" })
    Timing:Slider({ Name = "Hold", Flag = "trig_hold", Min = 20, Max = 500, Default = 70, Decimals = 1, Suffix = " ms", Tooltip = "How long the button stays down; longer holds fire more shots on automatics" })
    Timing:Slider({ Name = "Cooldown", Flag = "trig_cool", Min = 0, Max = 500, Default = 90, Decimals = 1, Suffix = " ms" })

    local Rcs = Subs["Recoil"]
    local RcsBox = Rcs:Section({ Name = "Recoil control", Side = 1, Icon = "target" })
    RcsBox:Toggle({ Name = "Enabled", Flag = "rcs_on", Tooltip = "Cancels the camera kick of each shot by reading the camera's recoil springs" }):Keybind({ Name = "Recoil key", Flag = "rcs_key", Default = "None", Mode = "Always" })
    RcsBox:Slider({ Name = "Vertical control", Flag = "rcs_v", Min = 0, Max = 100, Default = 70, Decimals = 1, Suffix = "%" })
    RcsBox:Slider({ Name = "Horizontal control", Flag = "rcs_h", Min = 0, Max = 100, Default = 40, Decimals = 1, Suffix = "%" })
    RcsBox:Toggle({ Name = "Hipfire too", Flag = "rcs_hip", Default = true, Tooltip = "Off: only controls recoil while aiming down sights" })
    RcsBox:Slider({ Name = "Variation", Flag = "rcs_human", Min = 0, Max = 40, Default = 10, Decimals = 1, Suffix = "%", Tooltip = "Varies the strength over time so the spray does not look machine perfect" })
end

do
    Pages.Rage:Section({ Name = "Rage", Side = 1, Icon = "swords" }):Label({ Name = "Coming soon" })
    Pages.Misc:Section({ Name = "Misc", Side = 1, Icon = "shapes" }):Label({ Name = "Coming soon" })
end

do
    local Subs = Pages.ESP:SubTabs({ { "Enemies", "swords" }, { "Teammates", "shield" }, { "Settings", "sliders-horizontal" }, { "Items", "package" }, { "Grenades", "flame" } })

    local function buildTeam(sub, prefix, label, tint, hidden)
        local function key(name) return prefix .. name end
        local Main = sub:Section({ Name = label .. " ESP", Side = 1, Icon = "eye" })
        Main:Toggle({ Name = "Enabled", Flag = key("on"), Tooltip = "Master switch for this tab" })
        Main:Slider({ Name = "Max distance", Flag = key("dist"), Min = 50, Max = 3000, Default = 1500, Decimals = 1, Suffix = " studs", Tooltip = "Players further away are not drawn" })
        Main:Toggle({ Name = "Box", Flag = key("box") }):Colorpicker({ Name = "Box", Flag = key("box_color"), Default = tint, Alpha = 0 })
        Main:Toggle({ Name = "Filled", Flag = key("fill") }):Colorpicker({ Name = "Fill", Flag = key("fill_color"), Default = tint, Alpha = 0.85 })
        Main:Toggle({ Name = "Name", Flag = key("name") }):Colorpicker({ Name = "Name", Flag = key("name_color"), Default = WHITE, Alpha = 0 })
        Main:Toggle({ Name = "Health bar", Flag = key("hp") }):Colorpicker({ Name = "Low health", Flag = key("hp_low"), Default = Color3.fromRGB(255, 60, 60), Alpha = 0 }):Colorpicker({ Name = "Full health", Flag = key("hp_full"), Default = Color3.fromRGB(80, 255, 120), Alpha = 0 })
        Main:Toggle({ Name = "Health number", Flag = key("hp_num") }):Colorpicker({ Name = "Number", Flag = key("hp_num_color"), Default = WHITE, Alpha = 0 })
        Main:Toggle({ Name = "Distance", Flag = key("show_dist") }):Colorpicker({ Name = "Distance", Flag = key("show_dist_color"), Default = Color3.fromRGB(190, 190, 205), Alpha = 0 })
        Main:Toggle({ Name = "Weapon", Flag = key("weapon") }):Colorpicker({ Name = "Weapon", Flag = key("weapon_color"), Default = Color3.fromRGB(205, 205, 215), Alpha = 0 })

        local Over = sub:Section({ Name = label .. " overlays", Side = 2, Icon = "layers" })
        Over:Toggle({ Name = "Skeleton", Flag = key("skeleton") }):Colorpicker({ Name = "Skeleton", Flag = key("skeleton_color"), Default = WHITE, Alpha = 0 })
        Over:Toggle({ Name = "Head dot", Flag = key("dot") }):Colorpicker({ Name = "Head dot", Flag = key("dot_color"), Default = tint, Alpha = 0 })
        Over:Toggle({ Name = "Tracer", Flag = key("tracer"), Tooltip = "Line from the screen to the player's feet" }):Colorpicker({ Name = "Tracer", Flag = key("tracer_color"), Default = tint, Alpha = 0 })
        Over:Toggle({ Name = "View direction", Flag = key("view"), Tooltip = "Where the player is looking, drawn from the head" }):Colorpicker({ Name = "View", Flag = key("view_color"), Default = Color3.fromRGB(255, 220, 60), Alpha = 0 })
        Over:Toggle({ Name = "Off-screen arrows", Flag = key("oov"), Tooltip = "Arrows pointing at players you cannot see on screen" }):Colorpicker({ Name = "Arrow", Flag = key("oov_color"), Default = tint, Alpha = 0 })
        Over:Toggle({ Name = "Chams", Flag = key("chams"), Tooltip = "Adornment chams on each body part. First colour is the visible layer, second the layer behind walls" }):Colorpicker({ Name = "Visible", Flag = key("cham_vis"), Default = tint, Alpha = 0.5 }):Colorpicker({ Name = "Behind walls", Flag = key("cham_hid"), Default = hidden, Alpha = 0.5 })
    end
    buildTeam(Subs.Enemies, "esp_enemy_", "Enemy", Color3.fromRGB(255, 70, 90), Color3.fromRGB(170, 60, 255))
    buildTeam(Subs.Teammates, "esp_team_", "Teammate", Color3.fromRGB(90, 220, 130), Color3.fromRGB(60, 150, 255))

    local Set = Subs.Settings
    local Text, Box, Colors = Set:MultiSection({ Sections = { "Text", "Box", "Colors" }, Side = 1 })
    Text:Dropdown({ Name = "Font", Flag = "esp_font", Items = { "Plex", "UI", "System", "Monospace" }, Default = "Plex" })
    Text:Slider({ Name = "Size", Flag = "esp_text", Min = 10, Max = 20, Default = 13, Decimals = 1, Suffix = " px" })
    Text:Dropdown({ Name = "Text case", Flag = "esp_case", Items = { "Normal", "lower", "UPPER" }, Default = "Normal" })
    Text:Toggle({ Name = "Outlines", Flag = "esp_outline", Default = true, Tooltip = "Dark outline on the box, dot and arrows" })
    Box:Dropdown({ Name = "Box style", Flag = "esp_box_style", Items = { "Corners", "Full" }, Default = "Corners" })
    Box:Dropdown({ Name = "Box mode", Flag = "esp_box_mode", Items = { "Static", "Dynamic" }, Default = "Static", Tooltip = "Static is a fixed size box; Dynamic wraps the body parts" })
    Box:Toggle({ Name = "Gradient fill", Flag = "esp_fill_gradient", Default = true, Tooltip = "Blends the fill into the second colour toward the feet" }):Colorpicker({ Name = "Fill end", Flag = "esp_fill_color2", Default = Color3.fromRGB(20, 20, 20), Alpha = 0 })
    Box:Dropdown({ Name = "Health bar side", Flag = "esp_hp_side", Items = { "Left", "Right" }, Default = "Left" })
    Box:Label({ Name = "Mid health colour" }):Colorpicker({ Name = "Mid health", Flag = "esp_hp_mid", Default = Color3.fromRGB(255, 210, 60), Alpha = 0 })
    Colors:Toggle({ Name = "Colour by visibility", Flag = "esp_vis", Tooltip = "Box, skeleton, tracer, dot, view line and arrows use the colours below" })
    Colors:Label({ Name = "Visible" }):Colorpicker({ Name = "Visible", Flag = "esp_vis_color", Default = Color3.fromRGB(80, 255, 120), Alpha = 0 })
    Colors:Label({ Name = "Behind walls" }):Colorpicker({ Name = "Behind walls", Flag = "esp_occ_color", Default = Color3.fromRGB(255, 80, 80), Alpha = 0 })

    local Lines, Cham, Arrow = Set:MultiSection({ Sections = { "Lines", "Chams", "Arrows" }, Side = 2 })
    Lines:Dropdown({ Name = "Tracer origin", Flag = "esp_tracer_origin", Items = { "Bottom", "Center", "Top", "Mouse" }, Default = "Bottom" })
    Lines:Slider({ Name = "Tracer thickness", Flag = "esp_tracer_thick", Min = 1, Max = 4, Default = 1, Decimals = 0.1, Suffix = " px" })
    Lines:Slider({ Name = "Skeleton thickness", Flag = "esp_skel_thick", Min = 1, Max = 4, Default = 1, Decimals = 0.1, Suffix = " px" })
    Lines:Slider({ Name = "View line length", Flag = "esp_view_len", Min = 2, Max = 30, Default = 8, Decimals = 0.1, Suffix = " studs" })
    Cham:Dropdown({ Name = "Mode", Flag = "cham_mode", Items = { "Through walls", "Visible only" }, Default = "Through walls", Tooltip = "Through walls switches between the two colours by line of sight" })
    Cham:Slider({ Name = "Thickness", Flag = "cham_grow", Min = 0, Max = 1, Default = 0.1, Decimals = 0.01, Suffix = " studs" })
    Cham:Toggle({ Name = "Glow", Flag = "cham_glow", Default = true, Tooltip = "Adds a soft halo layer around the visible chams" })
    Cham:Slider({ Name = "Glow size", Flag = "cham_glow_size", Min = 0.05, Max = 1.5, Default = 0.35, Decimals = 0.01, Suffix = " studs" })
    Cham:Toggle({ Name = "Round head", Flag = "cham_round_head", Default = true })
    Arrow:Slider({ Name = "Arrow size", Flag = "oov_size", Min = 8, Max = 32, Default = 14, Decimals = 1, Suffix = " px" })
    Arrow:Slider({ Name = "Arrow distance", Flag = "oov_radius", Min = 5, Max = 100, Default = 40, Decimals = 1, Suffix = " %", Tooltip = "Distance from the screen centre; 100 is the edge" })

    local Item = Subs.Items:Section({ Name = "Items", Side = 1, Icon = "package" })
    Item:Toggle({ Name = "Dropped weapons", Flag = "item_drops" }):Colorpicker({ Name = "Weapons", Flag = "item_drops_color", Default = Color3.fromRGB(255, 190, 60), Alpha = 0 })
    Item:Slider({ Name = "Max distance", Flag = "item_dist", Min = 20, Max = 1500, Default = 300, Decimals = 1, Suffix = " studs" })

    local Warn = Subs.Grenades:Section({ Name = "Grenade warning", Side = 1, Icon = "flame" })
    Warn:Toggle({ Name = "Enabled", Flag = "nade_on", Tooltip = "Tracks enemy grenades and your own from the game's throw event" })
    Warn:Toggle({ Name = "Enemy grenades", Flag = "nade_enemy", Default = true }):Colorpicker({ Name = "Enemy", Flag = "nade_enemy_color", Default = Color3.fromRGB(255, 90, 60), Alpha = 0 })
    Warn:Toggle({ Name = "My grenades", Flag = "nade_own", Default = true }):Colorpicker({ Name = "Mine", Flag = "nade_own_color", Default = Color3.fromRGB(120, 255, 170), Alpha = 0 })
    Warn:Toggle({ Name = "Fuse timer", Flag = "nade_timer", Default = true })
    Warn:Toggle({ Name = "Flight path", Flag = "nade_path", Default = true, Tooltip = "The path from the server's replicated grenade nodes, up to the blast" })
    Warn:Slider({ Name = "Max distance", Flag = "nade_dist", Min = 50, Max = 1500, Default = 400, Decimals = 1, Suffix = " studs" })
    local Blast = Subs.Grenades:Section({ Name = "Damage visualizer", Side = 2, Icon = "flame" })
    Blast:Toggle({ Name = "Damage estimate", Flag = "nade_dmg", Default = true, Tooltip = "Torso damage to you at the blast point from the grenade's damage graph, 0 behind map cover" }):Colorpicker({ Name = "Safe", Flag = "nade_safe_color", Default = Color3.fromRGB(90, 255, 130), Alpha = 0 }):Colorpicker({ Name = "Danger", Flag = "nade_danger_color", Default = Color3.fromRGB(255, 60, 60), Alpha = 0 })
    Blast:Toggle({ Name = "Blast radius ring", Flag = "nade_ring", Default = true, Tooltip = "Ground ring at the damage range of the grenade" })
    local Pred = Subs.Grenades:Section({ Name = "Throw predictor", Side = 2, Icon = "crosshair" })
    Pred:Toggle({ Name = "Predict throw", Flag = "nade_predict", Tooltip = "While holding a grenade, draws the predicted path and landing" }):Colorpicker({ Name = "Path", Flag = "nade_predict_color", Default = Color3.fromRGB(120, 200, 255), Alpha = 0 })
    Pred:Toggle({ Name = "Bounce markers", Flag = "nade_predict_bounce", Default = true })
end

do
    local Subs = Pages.World:SubTabs({ { "Environment", "sun" }, { "Sky", "moon" }, { "Weather", "cloud" }, { "Effects", "palette" }, { "Camera", "camera" }, { "Feedback", "flame" } })

    local Env = Subs.Environment
    local Light = Env:Section({ Name = "Lighting", Side = 1, Icon = "sun" })
    Light:Toggle({ Name = "Time of day", Flag = "world_time" })
    Light:Slider({ Name = "Clock time", Flag = "world_time_v", Min = 0, Max = 24, Default = 14, Decimals = 0.1, Suffix = " h" })
    Light:Toggle({ Name = "Day / night cycle", Flag = "world_cycle", Tooltip = "Runs the clock continuously from the current time" })
    Light:Slider({ Name = "Cycle speed", Flag = "world_cycle_speed", Min = 0.05, Max = 6, Default = 0.5, Decimals = 0.05, Suffix = " h/s" })
    Light:Toggle({ Name = "Sun latitude", Flag = "world_lat", Tooltip = "Tilts the sun's path across the sky" })
    Light:Slider({ Name = "Latitude", Flag = "world_lat_v", Min = -80, Max = 80, Default = 20, Decimals = 1, Suffix = " deg" })
    Light:Toggle({ Name = "Brightness", Flag = "world_bright" })
    Light:Slider({ Name = "Brightness value", Flag = "world_bright_v", Min = 0, Max = 10, Default = 2, Decimals = 0.1 })
    Light:Toggle({ Name = "Exposure", Flag = "world_exposure" })
    Light:Slider({ Name = "Exposure value", Flag = "world_exposure_v", Min = -3, Max = 3, Default = 0, Decimals = 0.1 })
    Light:Toggle({ Name = "Ambient", Flag = "world_ambient" }):Colorpicker({ Name = "Indoor", Flag = "world_ambient_in", Default = Color3.fromRGB(150, 150, 170) }):Colorpicker({ Name = "Outdoor", Flag = "world_ambient_out", Default = Color3.fromRGB(170, 170, 190) })
    Light:Toggle({ Name = "Colour shift", Flag = "world_shift", Tooltip = "Tints the light that hits surfaces facing the sky (top) and the ground (bottom)" }):Colorpicker({ Name = "Top", Flag = "world_shift_top", Default = Color3.fromRGB(255, 170, 90) }):Colorpicker({ Name = "Bottom", Flag = "world_shift_bottom", Default = Color3.fromRGB(60, 80, 140) })
    Light:Toggle({ Name = "Environment light", Flag = "world_env" })
    Light:Slider({ Name = "Diffuse", Flag = "world_env_diffuse", Min = 0, Max = 1, Default = 1, Decimals = 0.01 })
    Light:Slider({ Name = "Specular", Flag = "world_env_specular", Min = 0, Max = 1, Default = 1, Decimals = 0.01 })

    local Quick = Env:Section({ Name = "Quick toggles", Side = 1, Icon = "zap" })
    Quick:Toggle({ Name = "Full bright", Flag = "world_fullbright", Tooltip = "Overrides lighting values while on" })
    Quick:Toggle({ Name = "No shadows", Flag = "world_noshadow" })
    Quick:Toggle({ Name = "No fog", Flag = "world_nofog" })
    Quick:Toggle({ Name = "Remove sky", Flag = "world_nosky" })

    local Atmo = Env:Section({ Name = "Fog and atmosphere", Side = 2, Icon = "cloud" })
    Atmo:Toggle({ Name = "Custom fog", Flag = "world_fog" }):Colorpicker({ Name = "Fog", Flag = "world_fog_color", Default = Color3.fromRGB(180, 190, 210) })
    Atmo:Slider({ Name = "Fog start", Flag = "world_fog_start", Min = 0, Max = 2000, Default = 0, Decimals = 1, Suffix = " studs" })
    Atmo:Slider({ Name = "Fog end", Flag = "world_fog_end", Min = 10, Max = 5000, Default = 1500, Decimals = 1, Suffix = " studs" })
    Atmo:Toggle({ Name = "Fog gradient", Flag = "world_fog_grad", Tooltip = "Fades the fog colour between the fog colour above and this one" }):Colorpicker({ Name = "Second fog", Flag = "world_fog_color2", Default = Color3.fromRGB(120, 70, 190) })
    Atmo:Slider({ Name = "Gradient speed", Flag = "world_fog_grad_speed", Min = 0.1, Max = 6, Default = 1, Decimals = 0.1 })
    Atmo:Toggle({ Name = "Atmosphere", Flag = "world_atmos" }):Colorpicker({ Name = "Colour", Flag = "world_atmos_color", Default = Color3.fromRGB(199, 199, 199) }):Colorpicker({ Name = "Decay", Flag = "world_atmos_decay", Default = Color3.fromRGB(106, 112, 125) })
    Atmo:Slider({ Name = "Density", Flag = "world_atmos_density", Min = 0, Max = 1, Default = 0.3, Decimals = 0.01 })
    Atmo:Slider({ Name = "Glare", Flag = "world_atmos_glare", Min = 0, Max = 10, Default = 0, Decimals = 0.01 })
    Atmo:Slider({ Name = "Haze", Flag = "world_atmos_haze", Min = 0, Max = 10, Default = 0, Decimals = 0.01 })
    Atmo:Toggle({ Name = "Mood preset", Flag = "world_sky", Tooltip = "Sets the time of day and atmosphere colours together" })
    Atmo:Dropdown({ Name = "Preset", Flag = "world_sky_preset", Items = { "Night", "Sunset", "Overcast", "Dusk" }, Default = "Night" })

    local SkySub = Subs.Sky
    local Box = SkySub:Section({ Name = "Skybox", Side = 1, Icon = "moon" })
    Box:Toggle({ Name = "Custom skybox", Flag = "world_skybox", Tooltip = "Replaces the sky textures; the original sky comes back when this is off" })
    Box:Dropdown({ Name = "Skybox", Flag = "world_sky_box", Items = SKY_CHOICES, Default = SKY_CHOICES[1] })
    Box:Input({ Name = "Custom ids", Flag = "world_sky_custom", Placeholder = "1 image id, or 6: up down front back left right" })
    Box:Toggle({ Name = "Rotate skybox", Flag = "world_sky_spin" })
    Box:Slider({ Name = "Rotation speed", Flag = "world_sky_spin_speed", Min = -60, Max = 60, Default = 6, Decimals = 0.1, Suffix = " deg/s" })
    local Bodies = SkySub:Section({ Name = "Sun, moon and stars", Side = 2, Icon = "sun" })
    Bodies:Toggle({ Name = "Override", Flag = "world_sky_objects" })
    Bodies:Slider({ Name = "Stars", Flag = "world_sky_stars", Min = 0, Max = 5000, Default = 3000, Decimals = 1 })
    Bodies:Slider({ Name = "Sun size", Flag = "world_sky_sun", Min = 0, Max = 60, Default = 21, Decimals = 1, Suffix = " deg" })
    Bodies:Slider({ Name = "Moon size", Flag = "world_sky_moon", Min = 0, Max = 60, Default = 11, Decimals = 1, Suffix = " deg" })
    Bodies:Toggle({ Name = "Show sun and moon", Flag = "world_sky_bodies", Default = true })
    local Cloud = SkySub:Section({ Name = "Clouds", Side = 2, Icon = "cloud" })
    Cloud:Toggle({ Name = "Clouds", Flag = "world_clouds" }):Colorpicker({ Name = "Clouds", Flag = "world_clouds_color", Default = WHITE })
    Cloud:Slider({ Name = "Cover", Flag = "world_clouds_cover", Min = 0, Max = 1, Default = 0.6, Decimals = 0.01 })
    Cloud:Slider({ Name = "Density", Flag = "world_clouds_density", Min = 0, Max = 1, Default = 0.6, Decimals = 0.01 })

    local Wx = Subs.Weather:Section({ Name = "Weather", Side = 1, Icon = "cloud" })
    Wx:Toggle({ Name = "Enabled", Flag = "world_weather", Tooltip = "Particles follow you in map-anchored cells and only fall where the sky is open above" })
    Wx:Dropdown({ Name = "Type", Flag = "world_weather_preset", Items = WEATHER_NAMES, Default = "Snow" })
    Wx:Slider({ Name = "Density", Flag = "world_weather_amount", Min = 0.1, Max = 3, Default = 1, Decimals = 0.05 })
    Wx:Slider({ Name = "Speed", Flag = "world_weather_speed", Min = 0.2, Max = 3, Default = 1, Decimals = 0.05 })
    Wx:Slider({ Name = "Particle size", Flag = "world_weather_size", Min = 0.3, Max = 3, Default = 1, Decimals = 0.05 })
    Wx:Slider({ Name = "Range", Flag = "world_weather_range", Min = 1, Max = 3, Default = 2, Decimals = 1, Suffix = " cells", Tooltip = "Rings of 28 stud cells around you" })
    Wx:Slider({ Name = "Spawn height", Flag = "world_weather_height", Min = 10, Max = 80, Default = 35, Decimals = 1, Suffix = " studs" })
    local Wind = Subs.Weather:Section({ Name = "Wind and colour", Side = 2, Icon = "cloud" })
    Wind:Slider({ Name = "Wind strength", Flag = "world_weather_wind", Min = 0, Max = 30, Default = 4, Decimals = 0.1 })
    Wind:Slider({ Name = "Wind direction", Flag = "world_weather_wind_dir", Min = 0, Max = 360, Default = 0, Decimals = 1, Suffix = " deg" })
    Wind:Toggle({ Name = "Custom colour", Flag = "world_weather_custom", Tooltip = "Overrides the colour each weather type comes with" }):Colorpicker({ Name = "Weather", Flag = "world_weather_color", Default = WHITE })

    local Fx = Subs.Effects
    local Screen = Fx:Section({ Name = "Colour correction", Side = 1, Icon = "palette" })
    Screen:Toggle({ Name = "Enabled", Flag = "world_cc" }):Colorpicker({ Name = "Tint", Flag = "world_cc_tint", Default = WHITE })
    Screen:Slider({ Name = "Saturation", Flag = "world_cc_sat", Min = -1, Max = 1, Default = 0, Decimals = 0.01 })
    Screen:Slider({ Name = "Contrast", Flag = "world_cc_con", Min = -1, Max = 1, Default = 0, Decimals = 0.01 })
    Screen:Slider({ Name = "Brightness", Flag = "world_cc_bri", Min = -1, Max = 1, Default = 0, Decimals = 0.01 })
    local Bloom = Fx:Section({ Name = "Bloom and sun rays", Side = 2, Icon = "sun" })
    Bloom:Toggle({ Name = "Bloom", Flag = "world_bloom" })
    Bloom:Slider({ Name = "Intensity", Flag = "world_bloom_i", Min = 0, Max = 3, Default = 0.4, Decimals = 0.01 })
    Bloom:Slider({ Name = "Size", Flag = "world_bloom_s", Min = 0, Max = 56, Default = 24, Decimals = 0.1 })
    Bloom:Slider({ Name = "Threshold", Flag = "world_bloom_t", Min = 0, Max = 2, Default = 0.95, Decimals = 0.01 })
    Bloom:Toggle({ Name = "Sun rays", Flag = "world_rays" })
    Bloom:Slider({ Name = "Ray intensity", Flag = "world_rays_i", Min = 0, Max = 1, Default = 0.25, Decimals = 0.01 })
    Bloom:Slider({ Name = "Ray spread", Flag = "world_rays_s", Min = 0, Max = 1, Default = 1, Decimals = 0.01 })
    local Blur = Fx:Section({ Name = "Depth of field and blur", Side = 1, Icon = "scan" })
    Blur:Toggle({ Name = "Depth of field", Flag = "world_dof" })
    Blur:Slider({ Name = "Focus distance", Flag = "world_dof_focus", Min = 0, Max = 500, Default = 50, Decimals = 1, Suffix = " studs" })
    Blur:Slider({ Name = "In focus radius", Flag = "world_dof_radius", Min = 0, Max = 200, Default = 30, Decimals = 1, Suffix = " studs" })
    Blur:Slider({ Name = "Near blur", Flag = "world_dof_near", Min = 0, Max = 1, Default = 0.5, Decimals = 0.01 })
    Blur:Slider({ Name = "Far blur", Flag = "world_dof_far", Min = 0, Max = 1, Default = 0.5, Decimals = 0.01 })
    Blur:Toggle({ Name = "Screen blur", Flag = "world_blur" })
    Blur:Slider({ Name = "Blur size", Flag = "world_blur_size", Min = 0, Max = 56, Default = 8, Decimals = 0.1 })
    local Rainbow = Env:Section({ Name = "Colour cycle", Side = 2, Icon = "palette" })
    Rainbow:Toggle({ Name = "Rainbow", Flag = "world_rainbow", Tooltip = "Cycles the chosen colours through the rainbow" })
    Rainbow:Dropdown({ Name = "Applies to", Flag = "world_rainbow_targets", Items = { "Ambient", "Fog", "Colour shift", "Atmosphere" }, Multi = true, Default = { "Ambient" } })
    Rainbow:Slider({ Name = "Speed", Flag = "world_rainbow_speed", Min = 0.01, Max = 1, Default = 0.1, Decimals = 0.01 })
    Rainbow:Slider({ Name = "Saturation", Flag = "world_rainbow_sat", Min = 0, Max = 1, Default = 0.7, Decimals = 0.01 })

    local Cam = Subs.Camera
    local Fov = Cam:Section({ Name = "Camera", Side = 1, Icon = "camera" })
    Fov:Toggle({ Name = "Field of view", Flag = "world_fov", Tooltip = "Sets the game camera's base FOV; aiming zoom stays relative to it" })
    Fov:Slider({ Name = "FOV", Flag = "world_fov_v", Min = 60, Max = 120, Default = 90, Decimals = 1, Suffix = " deg" })
    Fov:Toggle({ Name = "Dynamic scope FOV", Flag = "world_fov_dyn", Tooltip = "Blends smoothly from the FOV above to the scoped FOV below while you aim" })
    Fov:Slider({ Name = "Scoped FOV", Flag = "world_fov_ads", Min = 20, Max = 120, Default = 60, Decimals = 1, Suffix = " deg" })
    Fov:Slider({ Name = "Blend speed", Flag = "world_fov_speed", Min = 2, Max = 30, Default = 10, Decimals = 0.1 })
    Fov:Slider({ Name = "Scope zoom multiplier", Flag = "world_fov_mult", Min = 0.5, Max = 3, Default = 1, Decimals = 0.01, Suffix = "x", Tooltip = "Scales the game's own scope zoom; 1 leaves it unchanged" })
    local Cross = Cam:Section({ Name = "Crosshair", Side = 2, Icon = "crosshair" })
    Cross:Toggle({ Name = "Custom crosshair", Flag = "cross_on" }):Colorpicker({ Name = "Crosshair", Flag = "cross_color", Default = Color3.fromRGB(120, 255, 170), Alpha = 0 })
    Cross:Toggle({ Name = "Attach to barrel", Flag = "cross_barrel", Tooltip = "Draws the crosshair at the weapon barrel instead of the screen centre" })
    Cross:Dropdown({ Name = "Attach point", Flag = "cross_barrel_pt", Items = { "Aim hit", "Muzzle" }, Default = "Aim hit", Tooltip = "Aim hit is where the barrel is pointing; Muzzle is the barrel tip" })
    Cross:Slider({ Name = "Length", Flag = "cross_len", Min = 1, Max = 40, Default = 8, Decimals = 1, Suffix = " px" })
    Cross:Slider({ Name = "Thickness", Flag = "cross_thick", Min = 1, Max = 6, Default = 2, Decimals = 1, Suffix = " px" })
    Cross:Slider({ Name = "Gap", Flag = "cross_gap", Min = 0, Max = 30, Default = 5, Decimals = 1, Suffix = " px" })
    Cross:Toggle({ Name = "Outline", Flag = "cross_outline", Default = true })
    Cross:Toggle({ Name = "Centre dot", Flag = "cross_dot" })
    Cross:Toggle({ Name = "T style", Flag = "cross_t", Tooltip = "Leaves out the top arm" })
    Cross:Toggle({ Name = "Spin", Flag = "cross_spin" })
    Cross:Slider({ Name = "Spin speed", Flag = "cross_spin_speed", Min = -360, Max = 360, Default = 90, Decimals = 1, Suffix = " deg/s" })
    Cross:Toggle({ Name = "Pulse gap", Flag = "cross_pulse" })
    Cross:Slider({ Name = "Pulse range", Flag = "cross_pulse_range", Min = 0, Max = 30, Default = 8, Decimals = 1, Suffix = " px" })
    Cross:Slider({ Name = "Pulse speed", Flag = "cross_pulse_speed", Min = 0.2, Max = 10, Default = 3, Decimals = 0.1 })

    local Fb = Subs.Feedback
    local Marker, HitSnd, KillSnd = Fb:MultiSection({ Sections = { "Hit marker", "Hit sound", "Kill sound" }, Side = 1 })
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

    local Dmg, Trace = Fb:MultiSection({ Sections = { "Damage numbers", "Bullet tracers" }, Side = 2 })
    Dmg:Toggle({ Name = "Custom damage numbers", Flag = "dmg_on", Tooltip = "Replaces the game's floating numbers; the game's Damage Numbers setting must be on" })
    Dmg:Label({ Name = "Head" }):Colorpicker({ Name = "Head", Flag = "dmg_head", Default = Color3.fromRGB(255, 102, 102) })
    Dmg:Label({ Name = "Torso" }):Colorpicker({ Name = "Torso", Flag = "dmg_torso", Default = Color3.fromRGB(255, 150, 0) })
    Dmg:Label({ Name = "Limbs" }):Colorpicker({ Name = "Limbs", Flag = "dmg_limb", Default = Color3.fromRGB(255, 255, 0) })
    Dmg:Slider({ Name = "Size", Flag = "dmg_size", Min = 8, Max = 32, Default = 16, Decimals = 1, Suffix = " px" })
    Dmg:Slider({ Name = "Rise", Flag = "dmg_rise", Min = 10, Max = 150, Default = 60, Decimals = 1, Suffix = " px" })
    Dmg:Slider({ Name = "Duration", Flag = "dmg_time", Min = 0.4, Max = 3, Default = 1.1, Decimals = 0.01, Suffix = " s" })
    Trace:Toggle({ Name = "Own bullets", Flag = "trace_on", Tooltip = "Recolours the game's tracer beams of your shots" }):Colorpicker({ Name = "Tracer", Flag = "trace_color", Default = Color3.fromRGB(255, 94, 94) })
    Trace:Toggle({ Name = "Other players' bullets", Flag = "trace_enemy_on" }):Colorpicker({ Name = "Tracer", Flag = "trace_enemy_color", Default = Color3.fromRGB(94, 160, 255) })
    Trace:Toggle({ Name = "Own bullet path", Flag = "trace_path_on", Tooltip = "Draws the path your bullet actually flew, from the barrel, including drop" }):Colorpicker({ Name = "Path", Flag = "trace_path_color", Default = Color3.fromRGB(255, 94, 94) })
    Trace:Toggle({ Name = "Other players' bullet path", Flag = "trace_path_enemy_on" }):Colorpicker({ Name = "Path", Flag = "trace_path_enemy_color", Default = Color3.fromRGB(94, 160, 255) })
    Trace:Slider({ Name = "Path duration", Flag = "trace_time", Min = 0.2, Max = 5, Default = 1.5, Decimals = 0.1, Suffix = " s" })
    Trace:Slider({ Name = "Path thickness", Flag = "trace_thick", Min = 1, Max = 4, Default = 1.5, Decimals = 0.1, Suffix = " px" })
    Trace:Toggle({ Name = "Hide the game's beam", Flag = "trace_hide_beam", Tooltip = "Turns off the game's own tracer beam on bullets whose path is drawn" })
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
        ThemeManager:CreatePresets(ThemeSub:AddLeftGroupbox("Presets", "folder"))
        ThemeManager:CreateAppearance(ThemeSub:AddRightGroupbox("Appearance", "monitor"))
        ThemeManager:Finalize()
    elseif ThemeManager.ApplyToTab then
        ThemeManager:ApplyToTab(ThemeSub)
    else
        Library:Notify("Outdated ThemeManager: upload addons/ThemeManager.lua from the latest release", 10)
    end
    SaveManager:IgnoreThemeSettings()
    SaveManager:SetIgnoreIndexes({ "MenuKeybind", "menu_notify_corner", "ui_view_Legit", "ui_view_ESP", "ui_view_World" })
    SaveManager:BuildConfigSection(ConfigSub)
end

local Loop = { last = os.clock(), labelAt = 0, watermarkAt = 0, retryAt = 0, retryDelay = 3, hookAt = 0, frames = 0, fpsAt = os.clock(), fps = 60 }

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
        ESP.clear()
        Util.guard("items", Items.step, cam, now)
        Util.guard("feedback", Feedback.step, cam, center, now)
        Util.guard("trail", Trail.step, cam, now)
        Util.guard("nades", Nades.step, cam, now)
        return
    end

    if now - Loop.hookAt > 3 then
        Loop.hookAt = now
        Util.guard("hooks", Feedback.hook)
        Util.guard("nadehook", Nades.hook)
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
    Util.guard("trail", Trail.step, cam, now)
    Util.guard("nades", Nades.step, cam, now)

    if now - Loop.watermarkAt > 0.5 then
        Loop.watermarkAt = now
        local ping = ""
        pcall(function()
            local network = Game.mods.NetworkClient
            if network and network.getPing then ping = " | " .. math.floor(network.getPing() * 1000) .. "ms" end
        end)
        pcall(function() Library:SetWatermark(string.format("Aster | %d fps%s", Loop.fps, ping)) end)
    end

    if now - Loop.labelAt > 0.2 then
        Loop.labelAt = now
        local weapon = Game.weapon()
        local text = "Weapon: " .. tostring(weapon and weapon.weaponName or "none")
        local speed = Game.stat(weapon, "bulletspeed")
        if type(speed) == "number" then text = text .. " | " .. math.floor(speed) .. " studs/s" end
        if Status.weapon and Loop.weaponText ~= text then Loop.weaponText = text; Status.weapon:SetText(text) end
        text = "Target: none"
        if Legit.target and Legit.record then
            text = string.format("Target: %s | %d hp | %dm", Legit.record.name, math.floor(Legit.record.health), math.floor((Legit.record.torso.Position - cam.CFrame.Position).Magnitude * STUDS_TO_M))
        end
        if Status.target and Loop.targetText ~= text then Loop.targetText = text; Status.target:SetText(text) end
        text = string.format("Recoil: %.1f / %.1f deg", math.deg(Recoil.shown.X), math.deg(Recoil.shown.Y))
        if Status.recoil and Loop.recoilText ~= text then Loop.recoilText = text; Status.recoil:SetText(text) end
    end
end

Nades.hook()

Util.track(RunService.RenderStepped:Connect(function()
    local ok, problem = pcall(Loop.step)
    if not ok then Util.note("loop" .. tostring(problem), "frame:", problem) end
end))

pcall(function() SaveManager:LoadAutoloadConfig() end)
pcall(function() Library:SetWatermarkVisibility(Toggles.menu_watermark == nil or Toggles.menu_watermark.Value) end)
if not introPlayed and not Library.Toggled then pcall(function() Library:Toggle() end) end
Library:Notify("Aster loaded | core " .. tostring(Game.summary), 5)

end, debug.traceback)
if not __ok then
    warn("[Aster] FAILED:\n" .. tostring(__err))
end
