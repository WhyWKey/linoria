local PL2BootClock = os.clock or tick
local PL2BootStart = PL2BootClock()
local PL2BootT = PL2BootStart
-- [src] 00_boot.lua
-- aster for Prison Life (pl2), built on the aster v2 library. Generated from repo/pl2/src by repo/_tools_pl2/bundle.js.
local BUILD = "pl2-1"
local FOLDER = "prison life"

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

local Aster, ThemeManager, SaveManager, loader, win
local Util, F, Loop, Pages, Game, Entities, Data, Compat
local Draw, Visible, Esp, World, Fx, Combat, Player, Map, Avatar
local fetch, bootMark, Combat_init

local env = (type(getgenv) == "function" and getgenv()) or _G
local clock = os.clock or tick
local function ms(t0, t1) return math.floor(((t1 or clock()) - t0) * 1000 + 0.5) end
local Boot = { at = PL2BootStart or clock(), timings = {}, marks = {}, missing = {} }

-- a previous pl2 copy, and the old Linoria builds (dev.lua TS_*, repo/pl PL_*), would keep running beside this one
do
    local old = env.AsterPL2
    local rerun = env.TS_Connections ~= nil or env.PL_Connections ~= nil
    if type(old) == "table" and type(old.unload) == "function" then pcall(old.unload) end
    for _, key in ipairs({ "TS_Connections", "PL_Connections" }) do
        for _, connection in ipairs(type(env[key]) == "table" and env[key] or {}) do pcall(function() connection:Disconnect() end) end
        env[key] = nil
    end
    for _, drawing in ipairs(type(env.TS_Drawings) == "table" and env.TS_Drawings or {}) do pcall(function() drawing:Remove() end) end
    env.TS_Drawings = nil
    local linoria = env.Library
    if rerun and type(linoria) == "table" and type(linoria.Unload) == "function" and not linoria.Unloaded then pcall(linoria.Unload, linoria) end
    if type(env.AsterLoader) == "table" and type(env.AsterLoader.destroy) == "function" then pcall(env.AsterLoader.destroy) end
end

-- the GitHub API first: raw.githubusercontent and Fastly are blocked on some networks (same chain as Example.lua)
do
    local API = "https://api.github.com/repos/WhyWKey/linoria/contents/ui-test/"
    local MIRRORS = {
        "https://gcore.jsdelivr.net/gh/WhyWKey/linoria@main/ui-test/",
        "https://testingcf.jsdelivr.net/gh/WhyWKey/linoria@main/ui-test/",
        "https://cdn.jsdelivr.net/gh/WhyWKey/linoria@main/ui-test/",
        "https://raw.githubusercontent.com/WhyWKey/linoria/main/ui-test/",
    }
    local compile = loadstring or load
    local B64 = {}
    for i = 1, 64 do B64[string.byte("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/", i)] = i - 1 end

    local function b64decode(s)
        s = string.gsub(s, "[^%w%+/]", "")
        local out, floor = {}, math.floor
        for i = 1, #s - 1, 4 do
            local a, b, c, d = string.byte(s, i, i + 3)
            local v = B64[a] * 262144 + B64[b] * 4096 + (c and B64[c] or 0) * 64 + (d and B64[d] or 0)
            local x, y, z = floor(v / 65536), floor(v / 256) % 256, v % 256
            out[#out + 1] = d and string.char(x, y, z) or c and string.char(x, y) or string.char(x)
        end
        return table.concat(out)
    end

    local function decode64(s)
        local c = crypt
        for _, f in ipairs({ c and c.base64decode, c and type(c.base64) == "table" and c.base64.decode, base64_decode, base64decode }) do
            local ok, out = pcall(f, s)
            if ok and type(out) == "string" and #out > 0 then return out end
        end
        return b64decode(s)
    end

    local function usable(body)
        if type(body) ~= "string" then return nil, "body " .. tostring(body) end
        if #body < 64 then return nil, #body .. " bytes: " .. string.sub(body, 1, 80) end
        if string.find(body, "^%s*[<{]") then return nil, "error page, " .. #body .. " bytes: " .. string.sub(body, 1, 80) end
        return body
    end

    local function httpGet(url)
        local ok, body = pcall(function() return game:HttpGet(url) end)
        if not ok then return nil, tostring(body) end
        return usable(body)
    end

    local function viaRequest(url, headers)
        local req = request or http_request or (syn and syn.request) or (fluxus and fluxus.request) or (http and http.request)
        if not req then return nil, "no request function" end
        local ok, reply = pcall(req, { Url = url, Method = "GET", Headers = headers })
        if not ok then return nil, tostring(reply) end
        if type(reply) ~= "table" then return nil, "reply " .. tostring(reply) end
        local code = tonumber(reply.StatusCode)
        if code and code >= 400 then return nil, "status " .. tostring(reply.StatusCode) end
        return usable(reply.Body)
    end

    local function viaApiJson(api)
        local ok, json = pcall(function() return game:HttpGet(api) end)
        if not ok then return nil, tostring(json) end
        local content = type(json) == "string" and string.match(json, '"content"%s*:%s*"(.-)"')
        if not content then return nil, "no content in the API reply" end
        local okDecode, src = pcall(decode64, (string.gsub(content, "\\n", "")))
        if not okDecode then return nil, "base64: " .. tostring(src) end
        return usable(src)
    end

    -- path under ui-test/; returns what the chunk returns
    function fetch(path)
        local api = API .. path
        local ways = {
            { "request " .. api, function() return viaRequest(api, { Accept = "application/vnd.github.raw", ["User-Agent"] = "aster" }) end },
            { "HttpGet " .. api, function() return viaApiJson(api) end },
        }
        for _, base in ipairs(MIRRORS) do
            local url = base .. path
            ways[#ways + 1] = { "HttpGet " .. url, function() return httpGet(url) end }
            ways[#ways + 1] = { "request " .. url, function() return viaRequest(url) end }
        end
        local tried, start = {}, clock()
        for _, way in ipairs(ways) do
            local t0 = clock()
            local body, why = way[2]()
            if body then
                local t1 = clock()
                local fn, err = compile(body, "=" .. path)
                if fn then
                    local t2 = clock()
                    print("[aster pl] " .. path .. " from " .. way[1] .. ", " .. #body .. " bytes")
                    local result = fn()
                    Boot.timings[path] = { download = ms(start, t1), compile = ms(t1, t2), run = ms(t2) }
                    return result, body
                end
                why = "compile failed: " .. tostring(err)
            end
            tried[#tried + 1] = "  " .. way[1] .. ": " .. tostring(why) .. " (" .. ms(t0) .. " ms)"
        end
        error("[aster pl] could not load " .. path .. ":\n" .. table.concat(tried, "\n"), 0)
    end
end

local function breathe()
    if task and task.wait then pcall(task.wait) end
end

Aster = fetch("library.lua")
loader = Aster:Loader({ title = "aster", game = "Prison Life", build = BUILD })
loader:Stage("loading addons", 0.15)
breathe()

do
    local function addon(path)
        local ok, mod = pcall(function()
            local m = fetch(path)
            m:SetLibrary(Aster)
            m:SetFolder(FOLDER)
            return m
        end)
        if ok then return mod end
        print(tostring(mod))
        Boot.missing[#Boot.missing + 1] = path
        return nil
    end
    local t0 = clock()
    ThemeManager = addon("addons/thememanager.lua")
    loader:Stage("loading save manager", 0.25)
    breathe()
    SaveManager = addon("addons/savemanager.lua")
    if SaveManager then SaveManager:IgnoreThemeSettings() end
    Boot.addons = ms(t0)
end

Compat = { has = {} }
do
    local function fn(...)
        for index = 1, select("#", ...) do
            local candidate = select(index, ...)
            if type(candidate) == "function" then return candidate end
        end
        return nil
    end
    local function field(owner, key)
        if type(owner) ~= "table" and type(owner) ~= "userdata" then return nil end
        local ok, value = pcall(function() return owner[key] end)
        return ok and value or nil
    end
    Compat.request = fn(request, http_request, field(http, "request"), field(syn, "request"))
    Compat.hookfunction = fn(hookfunction, hookfunc, replaceclosure, detourfunction)
    Compat.isexecutorclosure = fn(isexecutorclosure, checkclosure, isourclosure)
    Compat.getconnections = fn(getconnections, get_signal_cons, get_connections, getsignals)
    Compat.getgc = fn(getgc, get_gc_objects)
    Compat.filtergc = fn(filtergc, filter_gc)
    Compat.getupvalue = fn(field(debug, "getupvalue"), getupvalue)
    Compat.getstack = fn(field(debug, "getstack"), getstack)
    Compat.setstack = fn(field(debug, "setstack"), setstack)
    Compat.info = fn(field(debug, "info"))
    Compat.gethui = fn(gethui, get_hidden_gui, gethiddenui)
    Compat.customasset = fn(getcustomasset, getsynasset)
    Compat.clipboard = fn(setclipboard, toclipboard, setrbxclipboard)
    Compat.touch = fn(firetouchinterest)
    Compat.netowner = fn(isnetworkowner, is_network_owner)
    Compat.mousemoverel = fn(mousemoverel)
    Compat.has.files = (fn(writefile) and fn(readfile) and fn(isfile) and fn(makefolder)) ~= nil
    Compat.has.drawing = type(Drawing) == "table" or type(Drawing) == "userdata"
end

Util = { unloaded = false, cleanup = {}, connections = {}, warned = {} }
function F(flag) return Aster.Flags[flag] end
Util.F = F

function Util.track(connection)
    Util.connections[#Util.connections + 1] = connection
    return connection
end

function Util.onUnload(fn)
    Util.cleanup[#Util.cleanup + 1] = fn
end

function Util.note(key, ...)
    if Util.warned[key] then return end
    Util.warned[key] = true
    warn("[aster pl]", ...)
end

function Util.guard(label, fn, ...)
    local ok, result = pcall(fn, ...)
    if not ok then Util.note(label .. tostring(result), label .. ":", result) end
    return ok, result
end

function Util.notify(text, kind, duration)
    pcall(function() Aster:Notify("aster", tostring(text), kind or "info", duration) end)
end

function Util.stage(text, fraction)
    pcall(function() loader:Stage(text, fraction) end)
end

function Util.typing()
    return UserInputService:GetFocusedTextBox() ~= nil
end

function Util.changed(flags, fn)
    if type(flags) == "string" then flags = { flags } end
    local exact, prefixes = {}, {}
    for _, flag in ipairs(flags) do
        if string.sub(flag, -1) == "*" then prefixes[#prefixes + 1] = string.sub(flag, 1, -2) else exact[flag] = true end
    end
    return Util.track(Aster.Changed:Connect(function(flag, value)
        if type(flag) ~= "string" then return end
        local hit = exact[flag]
        if not hit then
            for _, prefix in ipairs(prefixes) do
                if string.sub(flag, 1, #prefix) == prefix then hit = true break end
            end
        end
        if hit then Util.guard("changed " .. flag, fn, flag, value) end
    end))
end

function Util.feature(flag, on, off)
    local active = false
    local function apply(value)
        if value and not active then
            active = true
            if on then Util.guard(flag .. " on", on) end
        elseif not value and active then
            active = false
            if off then Util.guard(flag .. " off", off) end
        end
    end
    Util.track(Aster:OnChanged(flag, function(value) if not Util.unloaded then apply(value) end end))
    Util.onUnload(function() apply(false) end)
    if F(flag) then apply(true) end
    return apply
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

-- value engine: one original per object+prop no matter how many features hold it, so the last release restores the game value
do
    local held = {}

    local function write(object, prop, value)
        pcall(function() object[prop] = value end)
    end

    function Util.hold(tag, object, prop, value)
        if object == nil then return end
        local props = held[object]
        if not props then
            props = {}
            held[object] = props
        end
        local entry = props[prop]
        if not entry then
            local ok, original = pcall(function() return object[prop] end)
            if not ok then return end
            entry = { original = original, stack = {} }
            props[prop] = entry
        end
        for index, item in ipairs(entry.stack) do
            if item[1] == tag then
                table.remove(entry.stack, index)
                break
            end
        end
        entry.stack[#entry.stack + 1] = { tag, value }
        write(object, prop, value)
    end

    local function release(object, prop, tag)
        local props = held[object]
        local entry = props and props[prop]
        if not entry then return end
        for index = #entry.stack, 1, -1 do
            if tag == nil or entry.stack[index][1] == tag then table.remove(entry.stack, index) end
        end
        local top = entry.stack[#entry.stack]
        if top then
            write(object, prop, top[2])
            return
        end
        write(object, prop, entry.original)
        props[prop] = nil
        if next(props) == nil then held[object] = nil end
    end

    function Util.restore(tag, object, prop)
        if object ~= nil then return release(object, prop, tag) end
        local list = {}
        for o, props in pairs(held) do
            for p in pairs(props) do list[#list + 1] = { o, p } end
        end
        for _, pair in ipairs(list) do release(pair[1], pair[2], tag) end
    end

    function Util.held(object, prop)
        local props = held[object]
        return props ~= nil and props[prop] ~= nil
    end
end

-- a feature row: toggle, then (right to left) gear, key chip and swatches, with explicit flag names so dev.lua names survive
function Util.row(container, name, flag, o)
    o = o or {}
    local toggle = container:Toggle({ name = name, flag = flag, default = o.def == true, depends = o.dep, hud = o.hud, tip = o.tip })
    local gear
    if o.gear then gear = toggle:Settings({ title = o.gear ~= true and o.gear or string.lower(name) }) end
    local key = o.key
    if key then
        if type(key) == "string" then key = { key } end
        toggle:Keybind({ flag = key[1] or key.flag, default = key[2] or key.default, mode = key[3] or key.mode })
    end
    local swatches = o.sw or {}
    for index = #swatches, 1, -1 do
        local swatch = swatches[index]
        if type(swatch) == "string" then swatch = { swatch } end
        toggle:Color({ flag = swatch[1], default = swatch[2] or "#ffffff", gradient = swatch.gradient })
    end
    return toggle, gear
end

Loop = { phases = { render = {}, heartbeat = {} }, byName = {}, frames = 0 }
do
    local function sorted(list)
        table.sort(list, function(a, b)
            if a.priority == b.priority then return a.order < b.order end
            return a.priority < b.priority
        end)
    end
    local order = 0

    function Loop.register(name, fn, priority, phase)
        Loop.unregister(name)
        phase = phase == "heartbeat" and "heartbeat" or "render"
        order = order + 1
        local entry = { name = name, fn = fn, priority = priority or 100, phase = phase, order = order, label = "loop " .. name }
        local list = Loop.phases[phase]
        list[#list + 1] = entry
        sorted(list)
        Loop.byName[name] = entry
        return entry
    end

    function Loop.unregister(name)
        local entry = Loop.byName[name]
        if not entry then return end
        Loop.byName[name] = nil
        local list = Loop.phases[entry.phase]
        for index, other in ipairs(list) do
            if other == entry then
                table.remove(list, index)
                break
            end
        end
    end

    function Loop.has(name)
        return Loop.byName[name] ~= nil
    end

    function Loop.count()
        return #Loop.phases.render + #Loop.phases.heartbeat
    end

    local function run(phase, dt)
        local list = Loop.phases[phase]
        if #list == 0 or Util.unloaded then return end
        local records = Entities and Entities.update() or {}
        local now = clock()
        for _, entry in ipairs(table.move(list, 1, #list, 1, {})) do
            if Loop.byName[entry.name] == entry then Util.guard(entry.label, entry.fn, dt, now, records) end
        end
    end

    function Loop.step(dt)
        Loop.frames = Loop.frames + 1
        if Game then Game.frame = Loop.frames end
        run("render", dt)
    end

    function Loop.beat(dt)
        run("heartbeat", dt)
    end

    -- bound after the camera so aim and drawings see this frame's camera
    local bindName = "AsterPL2_" .. tostring(math.random(100000, 999999))
    local bound = pcall(function()
        RunService:BindToRenderStep(bindName, Enum.RenderPriority.Camera.Value + 1, Loop.step)
    end)
    if bound then
        Util.onUnload(function() pcall(function() RunService:UnbindFromRenderStep(bindName) end) end)
    else
        Util.track(RunService.RenderStepped:Connect(Loop.step))
    end
    Util.track(RunService.Heartbeat:Connect(Loop.beat))
end

Aster:OnUnload(function()
    Util.unloaded = true
    for index = #Util.cleanup, 1, -1 do pcall(Util.cleanup[index]) end
    Util.cleanup = {}
    for _, connection in ipairs(Util.connections) do pcall(function() connection:Disconnect() end) end
    Util.connections = {}
    Loop.phases, Loop.byName = { render = {}, heartbeat = {} }, {}
    Util.restore(nil)
    if env.AsterPL2 and env.AsterPL2.Util == Util then env.AsterPL2 = nil end
end)

-- called by the bundle after every part: timing plus loader progress
function bootMark(label, started, index, total)
    Boot.marks[#Boot.marks + 1] = { label, (clock() - started) * 1000 }
    if index < total then
        Util.stage("loaded " .. label, 0.3 + 0.55 * index / total)
        breathe()
    end
end

Pages = { tabs = {}, strips = {} }
Data = {}
bootMark("boot", PL2BootT, 1, 13)

PL2BootT = PL2BootClock()
-- [src] 05_data.lua
do
    Data.HIT_SOUND_NAMES = { "BowHit", "CSGO", "Click", "Damage", "Explosion", "Gamesense", "Hitmarker", "Hover", "Ice", "Impact", "Minecraft",
        "Neverlose", "Pop", "Rust", "Sparkle", "Steve", "TF2", "Windows", "PF Hitmarker", "PF Killshot", "PF Headshot kill" }
    Data.HIT_SOUNDS = {
        BowHit = "rbxassetid://1053296915", CSGO = "rbxassetid://5764885315", Click = "rbxassetid://1347140027",
        Damage = "rbxassetid://8587183599", Explosion = "rbxassetid://90854697257230", Gamesense = "rbxassetid://4817809188",
        Hitmarker = "rbxassetid://1129547534", Hover = "rbxassetid://6333717580", Ice = "rbxassetid://268934012",
        Impact = "rbxassetid://6759025689", Minecraft = "rbxassetid://4018616850", Neverlose = "rbxassetid://6607204501",
        Pop = "rbxassetid://18803667669", Rust = "rbxassetid://5043539486", Sparkle = "rbxassetid://132463144859699",
        Steve = "rbxassetid://4965083997", TF2 = "rbxassetid://8255306220", Windows = "rbxassetid://9066167010",
        ["PF Hitmarker"] = "rbxassetid://287062939",
        ["PF Killshot"] = { "rbxassetid://898398768", "rbxassetid://898398730", "rbxassetid://898398743" },
        ["PF Headshot kill"] = { "rbxassetid://898398768", "rbxassetid://898398785", "rbxassetid://898398795", "rbxassetid://898398809",
            "rbxassetid://898398817", "rbxassetid://898398837" },
    }

    Data.FX_WEAPONS = {
        { key = "ak47", label = "AK-47", tools = { "ak47" } },
        { key = "m4a1", label = "M4A1", tools = { "m4a1", "m4" } },
        { key = "mp5", label = "MP5", tools = { "mp5" } },
        { key = "fal", label = "FAL", tools = { "fal" } },
        { key = "r870", label = "Remington 870", tools = { "remington870", "r870", "remington" } },
        { key = "m700", label = "M700", tools = { "m700" } },
        { key = "m9", label = "M9", tools = { "m9" } },
        { key = "revolver", label = "Revolver", tools = { "revolver" } },
    }

    Data.FORCEFIELD_NAMES = { "Disabled", "Webbed", "Pixelated", "Swirl", "Shield", "Bubbles", "Matrix", "Honeycomb", "Clouds", "Galaxy",
        "Stars", "Wires", "Camo", "Hexagon", "Particles", "Triangular", "Wall", "Scanning" }
    Data.FORCEFIELD_TEXTURES = {
        Disabled = "", Webbed = "rbxassetid://2179243880", Pixelated = "rbxassetid://140652787", Swirl = "rbxassetid://8133639623",
        Shield = "rbxassetid://361073795", Bubbles = "rbxassetid://1461576423", Matrix = "rbxassetid://10713189068",
        Honeycomb = "rbxassetid://179898251", Clouds = "rbxassetid://5176277457", Galaxy = "rbxassetid://1120738433",
        Stars = "rbxassetid://598201818", Wires = "rbxassetid://14127933", Camo = "rbxassetid://3280937154",
        Hexagon = "rbxassetid://6175083785", Particles = "rbxassetid://1133822388", Triangular = "rbxassetid://4504368932",
        Wall = "rbxassetid://4271279", Scanning = "rbxassetid://5843010904",
    }

    -- giver models are matched by their ToolName attribute in game (the dump renamed AK47_7 / r870_2 / MP5_1)
    Data.GUN_ORDER = { "AK-47", "Remington 870", "MP5", "M700", "M4A1", "FAL", "Revolver" }
    Data.GUNS = {
        ["AK-47"] = { cframe = CFrame.new(-931.86, 92.2, 2039.39), keys = { "ak47", "ak" }, tool = { "AK-47", "AK47" } },
        ["Remington 870"] = { cframe = CFrame.new(820.45, 100.8, 2229.68), keys = { "r870", "remington870", "remington" }, tool = { "Remington 870", "Remington" } },
        MP5 = { cframe = CFrame.new(813.8, 100.8, 2229.62), keys = { "mp5" }, tool = { "MP5" } },
        M700 = { cframe = CFrame.new(-919.51, 95.07, 2036.23), keys = { "m700" }, tool = { "M700" } },
        M4A1 = { cframe = CFrame.new(847.68, 100.88, 2229.05), keys = { "m4a1", "m4" }, tool = { "M4A1" } },
        FAL = { cframe = CFrame.new(-902.63, 94.35, 2047.25), keys = { "fal" }, tool = { "FAL" } },
    }
    Data.PLACE_ORDER = { "Yard", "Academy", "Prison", "Armory", "Cafeteria", "Kitchen", "Police car spawner", "Top of the city building" }
    Data.PLACES = {
        Yard = CFrame.new(780.21, 98, 2470.5),
        Academy = CFrame.new(795.87, 98.19, 2542.61),
        Prison = CFrame.new(913.48, 100, 2388.36),
        Armory = CFrame.new(831.13, 99.98, 2233.09),
        Cafeteria = CFrame.new(905.89, 99.99, 2316.14),
        Kitchen = CFrame.new(923.09, 99.99, 2231.35),
        ["Police car spawner"] = CFrame.new(615.18, 98.2, 2501.2),
        ["Top of the city building"] = CFrame.new(-309.72, 118.04, 2015.59),
    }
    Data.ITEM_ORDER = { "Key card", "Breakfast", "Lunch", "Dinner", "Soda", "Chips", "Chocolate" }
    Data.ITEMS = {
        ["Key card"] = { "Key card" }, Breakfast = { "Breakfast" }, Lunch = { "Lunch" }, Dinner = { "Dinner" },
        Soda = { "Snacks", "Soda" }, Chips = { "Snacks", "Chips" }, Chocolate = { "Snacks", "Chocolate" },
    }

    -- sky presets: { name, bk, dn, ft, lf, rt, up, stars, sun size, moon size, sun tex, moon tex }, 0 = keep the default; built on first use
    local store
    local function build()
        return {
            skies = {
                { "Aesthetic 3", 151165214, 151165197, 151165224, 151165191, 151165206, 151165227, 500, 0, 0, 8281961896, 6444320592 },
                { "Aesthetic Mountains", 15470198023, 15470151245, 15470200128, 15470202648, 15470204862, 15470207755, 3000, 21, 11, 6196665106, 6444320592 },
                { "Afternoon", 162001887, 161998893, 162001897, 162001904, 162001919, 162001926, 3000, 21, 11, 0, 0 },
                { "Better Night", 15470289121, 15470291746, 15470294431, 15470297162, 15470299887, 15470303050, 3000, 21, 11, 0, 0 },
                { "Better Night 3", 2670643994, 2670643365, 2670643214, 2670643070, 2670644173, 2670644331, 500, 21, 1.5, 6196665106, 1075087760 },
                { "Blizzard", 16653221738, 16653222701, 16653224051, 16653225849, 16653227200, 16653228333, 3000, 21, 0, 6196665106, 6444320592 },
                { "Blue Clouds", 591058823, 591059876, 591058104, 591057861, 591057625, 591059642, 3000, 0, 0, 6196665106, 6444320592 },
                { "Blue Space", 366731024, 367147970, 366731193, 366731613, 366731514, 367149078, 0, 21, 11, 0, 0 },
                { "Blue Space (alt)", 16876541778, 16876543880, 16876546384, 16876548320, 16876550345, 16876552681, 3000, 21, 0, 8281961896, 6444320592 },
                { "Classic Roblox", 11138450201, 11138453351, 11138458027, 11138460736, 11138463127, 11138465883, 3000, 21, 11, 11138537872, 0 },
                { "Cloudy", 246480323, 246480523, 246480105, 246480549, 246480565, 246480504, 3000, 21, 11, 0, 0 },
                { "Cloudy (alt)", 4495864450, 4495864887, 4495865458, 4495866035, 4495866584, 4495867486, 3000, 21, 11, 0, 0 },
                { "Dark Skies", 149397692, 149397686, 149397697, 149397684, 149397688, 149397702, 3000, 21, 11, 0, 0 },
                { "Darkish Pink", 570555736, 570555964, 570555800, 570555840, 570555882, 570555929, 3000, 21, 11, 8281961896, 6444320592 },
                { "Dawn", 323479840, 323481190, 323480314, 323480786, 323480131, 323478865, 3000, 21, 11, 0, 0 },
                { "Dusk", 9778108979, 9778110864, 9778101192, 9778103329, 9778104889, 9778106496, 3000, 0, 11, 0, 0 },
                { "Earth", 15753305495, 15753362674, 15753305823, 15753310707, 15753304774, 15753304473, 3000, 0, 0, 0, 0 },
                { "Ethereal", 16823386986, 16823388586, 16823390254, 16823392344, 16823394120, 16823395515, 3000, 21, 11, 0, 0 },
                { "FPSBoost", 11457548274, 11457548274, 11457548274, 11457548274, 11457548274, 11457548274, 3000, 0, 0, 8281961896, 6444320592 },
                { "Flame", 6286780109, 6286782353, 6286784186, 6286785801, 6286788245, 6286790025, 3000, 21, 0, 8281961896, 6444320592 },
                { "Flaming Sunset", 415688378, 415688193, 415688242, 415688310, 415688274, 415688354, 3000, 0, 0, 6196665106, 6444320592 },
                { "Funny Storm", 6280934001, 6280935347, 6280936575, 6280938749, 6280940989, 6280942402, 3000, 21, 0, 8281961896, 6444320592 },
                { "Galaxy", 2049520382, 2049519279, 2049519882, 2049522478, 2049521207, 2049518578, 3000, 21, 11, 0, 0 },
                { "Galaxy (alt)", 159454299, 159454296, 159454293, 159454293, 159454293, 159454288, 3000, 0, 0, 8281961896, 6444320592 },
                { "Galaxy 2", 14164368678, 14164386126, 14164389230, 14164398493, 14164402782, 14164405298, 500, 0, 0, 8281961896, 6444320592 },
                { "Galaxy 3", 14543264135, 14543358958, 14543257810, 14543275895, 14543280890, 14543371676, 3000, 0, 0, 8281961896, 6444320592 },
                { "Green Haze", 160193404, 160193466, 160193461, 160193469, 160193463, 160193458, 3000, 0, 11, 0, 0 },
                { "Heaven", 7951826533, 7951706908, 7951694757, 7951697216, 7951700251, 7951703855, 3000, 21, 11, 0, 0 },
                { "Hell", 11730840088, 11730842997, 11730849615, 11730852920, 11730855491, 11730857150, 3000, 0, 11, 8281961896, 6444320592 },
                { "Horizontal Milky Way", 714276643, 714276541, 714276657, 714276648, 714276638, 714276621, 0, 21, 11, 0, 0 },
                { "Jungle", 525546178, 525544628, 525548536, 525550171, 525545319, 525546479, 3000, 21, 11, 0, 0 },
                { "Lunar Night", 187713366, 187712428, 187712836, 187713755, 187714525, 187712111, 0, 0, 0, 8281961896, 6444320592 },
                { "Milkyway", 129876530632297, 108406529909981, 104400530594543, 73372229972523, 87408857415924, 137817405681365, 3000, 0, 0, 8281961896, 6444320592 },
                { "Mountains", 368385273, 48015300, 368388290, 368390615, 368385190, 48015387, 3000, 21, 11, 0, 0 },
                { "Mountains (alt)", 15359410490, 15359411132, 15359412131, 15359411633, 15359417656, 15359412677, 3000, 21, 0, 8281961896, 6444320592 },
                { "Nebula", 171448875, 171448902, 171448848, 171448933, 171448925, 171448889, 3000, 21, 11, 0, 0 },
                { "Nebula (alt)", 5260808177, 5260653793, 5260817288, 5260800833, 5260811073, 5260824661, 3000, 0, 0, 8281961896, 6444320592 },
                { "Nebula 2", 16932794531, 16932797813, 16932800523, 16932803722, 16932806825, 16932810138, 3000, 0, 0, 8281961896, 6444320592 },
                { "Nebula 6", 16694187412, 16694190947, 16694194795, 16694197080, 16694200892, 16694204069, 3000, 21, 11, 8281961896, 6444320592 },
                { "Nether World", 14365019002, 14365023350, 14365018399, 14365018705, 14365018143, 14365019327, 3000, 0, 0, 8281961896, 6444320592 },
                { "New York", 11333973069, 11333969768, 11333964303, 11333971332, 11333982864, 11333967970, 3000, 0, 0, 6196665106, 6444320592 },
                { "Night", 12064107, 12064152, 12064121, 12063984, 12064115, 12064131, 0, 21, 11, 0, 0 },
                { "Night Light", 171447054, 171447094, 171447041, 171447128, 171447111, 171447068, 3000, 21, 11, 0, 0 },
                { "Ocean Sky", 11854686548, 11854687121, 11854693863, 11854696162, 11854698541, 11854708161, 3000, 1, 0, 4774583925, 4774580371 },
                { "Pink Art", 71607054149497, 78865378050055, 104560113223878, 80395333901607, 87570388049514, 79190209626172, 3000, 21, 0, 0, 0 },
                { "Pink Clouds", 271042516, 271077243, 271042556, 271042310, 271042467, 271077958, 1334, 21, 11, 0, 0 },
                { "Pink Mountains", 160188495, 160188614, 160188609, 160188589, 160188597, 160188588, 3000, 21, 0, 0, 0 },
                { "Purple", 8539982183, 8539981943, 8539981721, 8539981424, 8539980766, 8539981085, 3000, 0, 0, 8281961896, 6444320592 },
                { "Purple 2", 8107841671, 6444884785, 8107841671, 8107841671, 8107841671, 8107849791, 3000, 11, 0, 6196665106, 6444320592 },
                { "Purple 3", 433274085, 433274194, 433274131, 433274370, 433274429, 433274285, 3000, 0, 0, 8281961896, 6444320592 },
                { "Purple Clouds", 570557514, 570557775, 570557559, 570557620, 570557672, 570557727, 3000, 21, 0, 8281961896, 6444320592 },
                { "Purple Night", 5260808177, 5260653793, 5260817288, 5260800833, 5260800833, 5084576400, 3000, 0, 0, 8281961896, 6444320592 },
                { "Purple Planet", 16262356578, 16262358026, 16262360469, 16262362003, 16262363873, 16262366016, 3000, 21, 0, 8281961896, 6444320592 },
                { "Purple Space", 15983968922, 15983966825, 5260817288, 15983967420, 15983966246, 15983964246, 3000, 0, 0, 8281961896, 6444320592 },
                { "Red Dusk", 85146619291315, 123407860042117, 132624761762466, 102069641249982, 136526747107728, 136208328681929, 3000, 21, 11, 0, 0 },
                { "Redshift", 401664839, 401664862, 401664960, 401664881, 401664901, 401664936, 0, 21, 11, 0, 0 },
                { "SFOTH", 1012890, 1012891, 1012887, 1012889, 1012888, 1014449, 3000, 21, 11, 0, 0 },
                { "Saturn", 1898724755, 1898727189, 1898722814, 1898729298, 1898741025, 1898736761, 3000, 10, 0, 0, 0 },
                { "Smoke", 171410736, 171410748, 171410730, 171410766, 171410755, 171410742, 3000, 21, 11, 0, 0 },
                { "Solid Black", 2013298, 2013298, 2013298, 2013298, 2013298, 2013298, 0, 21, 11, 0, 0 },
                { "Space", 155441905, 155441905, 155441905, 155441905, 155441905, 155441905, 0, 21, 11, 0, 0 },
                { "Space (alt)", 166509999, 166510057, 166510116, 166510092, 166510131, 166510114, 3000, 0, 0, 8281961896, 6444320592 },
                { "Space 2", 11844076072, 11844069700, 11844067209, 11844063543, 11844058446, 11844053742, 3000, 11, 20, 0, 11844121592 },
                { "Storm", 171410784, 171410792, 171410775, 171410807, 171410798, 171410789, 3000, 21, 11, 0, 0 },
                { "Storm (alt)", 1618912481, 1618913943, 1618913244, 1618912849, 1618911568, 1618913654, 3000, 0, 0, 1084351190, 1075087760 },
                { "Sunset", 264908339, 264907909, 264909420, 264909758, 264908886, 264907379, 5000, 18, 11, 0, 0 },
                { "Underworld", 171560994, 171561019, 171560968, 171561065, 171561026, 171561009, 3000, 21, 11, 0, 0 },
                { "Valentines", 11427769401, 11427770685, 11427769401, 11427769401, 11427769401, 11427771954, 3000, 21, 0, 0, 0 },
                { "Vertical Milky Way", 5559289158, 5559290893, 5559300879, 5559292825, 5559302989, 5559302033, 3000, 1.440000057220459, 0.5699999928474426, 0, 0 },
                { "White", 321136141, 321136141, 321136141, 321136141, 321136141, 321136141, 0, 21, 11, 0, 0 },
                { "Winter", 155657655, 155674246, 155657609, 155657671, 155657619, 155674931, 3000, 21, 11, 8281961896, 6444320592 },
            },
        }
    end

    function Data.lazy(name)
        store = store or build()
        return store[name]
    end

    function Data.skyNames()
        local names = { "Default", "Custom" }
        for _, sky in ipairs(Data.lazy("skies") or {}) do names[#names + 1] = sky[1] end
        return names
    end

    function Data.sky(name)
        for _, sky in ipairs(Data.lazy("skies") or {}) do
            if sky[1] == name then return sky end
        end
        return nil
    end
end
bootMark("data", PL2BootT, 2, 13)

PL2BootT = PL2BootClock()
-- [src] 10_game.lua
do
    local R6_PARTS = { "Head", "Torso", "HumanoidRootPart", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }
    local TEAM_NAMES = { Guards = true, Inmates = true, Criminals = true, Neutral = true }

    local function newBus(name)
        local bus = { name = name, list = {} }
        function bus:Connect(fn)
            local connection = { Connected = true, fn = fn }
            function connection:Disconnect()
                if not connection.Connected then return end
                connection.Connected = false
                for index, other in ipairs(bus.list) do
                    if other == connection then
                        table.remove(bus.list, index)
                        break
                    end
                end
            end
            bus.list[#bus.list + 1] = connection
            return connection
        end
        function bus:Fire(...)
            for _, connection in ipairs(table.move(bus.list, 1, #bus.list, 1, {})) do
                if connection.Connected then Util.guard("event " .. name, connection.fn, ...) end
            end
        end
        function bus:Clear()
            for _, connection in ipairs(bus.list) do connection.Connected = false end
            bus.list = {}
        end
        return bus
    end

    Game = { frame = 0, events = {}, arrested = false, properties = {} }
    for _, name in ipairs({ "onOwnShot", "onEnemyShot", "onHit", "onKill", "onLocalDied", "onArrested", "onTased", "onRespawn" }) do
        Game.events[name] = newBus(name)
    end

    function Game.camera() return Workspace.CurrentCamera end

    function Game.eye(cam)
        cam = cam or Game.camera()
        return cam and cam.CFrame.Position or nil
    end

    function Game.localCharacter() return LocalPlayer.Character end

    function Game.humanoid(model)
        return model and model:FindFirstChildOfClass("Humanoid") or nil
    end

    function Game.rootPart()
        local character = Game.localCharacter()
        return character and character:FindFirstChild("HumanoidRootPart") or nil
    end

    function Game.localAlive()
        local humanoid = Game.humanoid(Game.localCharacter())
        return humanoid ~= nil and humanoid.Health > 0 and not Game.arrested
    end

    function Game.weapon()
        local character = Game.localCharacter()
        return character and character:FindFirstChildOfClass("Tool") or nil
    end

    function Game.remote(path)
        local node = ReplicatedStorage
        for name in string.gmatch(path, "[^%.]+") do
            node = node and node:FindFirstChild(name)
        end
        return node
    end

    function Game.toolProperties(name)
        local cached = Game.properties[name]
        if cached ~= nil then return cached or nil end
        local found = false
        pcall(function()
            local folder = Game.remote("SharedModules.ToolProperties")
            local module = folder and folder:FindFirstChild(name)
            local data = module and require(module)
            if type(data) == "table" then found = data end
        end)
        Game.properties[name] = found
        return found or nil
    end

    -- ToolProperties first, tool attributes win (the live ammo counts are attributes)
    function Game.weaponInfo(tool)
        local info = {}
        if not tool then return info end
        for key, value in pairs(Game.toolProperties(tool.Name) or {}) do info[key] = value end
        local ok, attributes = pcall(function() return tool:GetAttributes() end)
        if ok and type(attributes) == "table" then
            for key, value in pairs(attributes) do info[key] = value end
        end
        info.Name = tool.Name
        return info
    end

    function Game.aiming()
        local gui = LocalPlayer:FindFirstChild("PlayerGui")
        local cross = gui and gui:FindFirstChild("CrosshairGui")
        local scope = cross and cross:FindFirstChild("ScopeFrame")
        return scope ~= nil and scope.Visible == true
    end

    function Game.team(player)
        local team = player and player.Team
        local name = team and team.Name
        if TEAM_NAMES[name] then return name end
        return "Neutral"
    end

    -- Players-list relations (Aster.Relations, by name) replace dev.lua Friendly/Priority
    function Game.relation(player)
        local relations = Aster.Relations
        return player and relations and relations[player.Name] or nil
    end

    function Game.isEnemy(player)
        if not player or player == LocalPlayer then return false end
        local relation = Game.relation(player)
        if relation == "friend" or relation == "ignore" then return false end
        if relation == "target" then return true end
        local mine, theirs = LocalPlayer.Team, player.Team
        if not mine or not theirs then return true end
        return mine ~= theirs
    end

    function Game.isPeaceful(player)
        if not player or Game.relation(player) == "target" then return false end
        local team = player.Team
        if not team or team.Name ~= "Inmates" then return false end
        local character = player.Character
        return not (character and character:GetAttribute("Hostile") == true)
    end

    function Game.canDamage(player)
        if not player or player == LocalPlayer or player.Team == LocalPlayer.Team then return false end
        local character = player.Character
        if not character then return false end
        if Game.team(LocalPlayer) == "Guards" and Game.team(player) == "Inmates" and character:GetAttribute("Hostile") ~= true then return false end
        if character:FindFirstChildOfClass("ForceField") then return false end
        local humanoid = Game.humanoid(character)
        return humanoid ~= nil and humanoid.Health > 0
    end

    local function attribute(player, character, key)
        local value = character and character:GetAttribute(key)
        if value == nil and player then value = player:GetAttribute(key) end
        return value == true
    end

    function Game.state(player, into)
        local character = player and player.Character
        local state = into or {}
        state.hostile = attribute(player, character, "Hostile")
        state.trespassing = attribute(player, character, "Trespassing")
        state.tased = attribute(player, character, "Tased")
        state.forcefield = character ~= nil and character:FindFirstChildOfClass("ForceField") ~= nil
        return state
    end

    function Game.skipHit(part)
        if not part then return false end
        if part.Name == "RayPart" then return true end
        local cam = Game.camera()
        if cam and part:IsDescendantOf(cam) then return true end
        if part.Parent and part.Parent:IsA("Accessory") then return true end
        return part.CanQuery == false
    end

    -- re-casts past skipped hits (game tracers, accessories, non-query parts), 8 hops at most
    function Game.cast(origin, vector, params, skip)
        skip = skip or Game.skipHit
        local from, left = origin, vector
        for _ = 1, 8 do
            local result = Workspace:Raycast(from, left, params)
            if not result or not skip(result.Instance) then return result end
            local travelled = (result.Position - from).Magnitude + 0.01
            local length = left.Magnitude
            if travelled >= length then return nil end
            local direction = left.Unit
            from = result.Position + direction * 0.01
            left = direction * (length - travelled)
        end
        return nil
    end

    function Game.newParams(list, include)
        local ok, params = pcall(function()
            local made = RaycastParams.new()
            made.FilterType = include and Enum.RaycastFilterType.Include or Enum.RaycastFilterType.Exclude
            return made
        end)
        if not ok then return nil end
        pcall(function() params.RespectCanCollide = true end)
        pcall(function() params.IgnoreWater = true end)
        if list then pcall(function() params.FilterDescendantsInstances = list end) end
        return params
    end

    function Game.playerFromPart(part)
        local model = part and part:FindFirstAncestorOfClass("Model")
        while model do
            local player = Players:GetPlayerFromCharacter(model)
            if player then return player end
            model = model:FindFirstAncestorOfClass("Model")
        end
        return nil
    end

    Entities = { list = {}, shown = {}, byPlayer = {}, calls = 0, frame = -1 }

    -- re-resolved every frame: characters whose parts replicate after CharacterAdded must not keep nil parts for a life
    local function partsOf(record, model)
        local parts = record.parts
        if record.model ~= model or not parts then
            parts = {}
            record.model, record.parts = model, parts
        end
        for _, name in ipairs(R6_PARTS) do
            local part = parts[name]
            if not part or part.Parent ~= model then parts[name] = model:FindFirstChild(name) end
        end
        return parts
    end

    function Entities.present(record)
        if not record or not record.model or not record.root or not record.humanoid then return false end
        if record.humanoid.Health <= 0 or record.humanoid.Parent ~= record.model then return false end
        return record.model:IsDescendantOf(Workspace)
    end

    function Entities.live(record)
        return Entities.present(record) and not record.parked
    end

    local function refresh(player, model, humanoid, floor)
        local record = Entities.byPlayer[player]
        if not record then
            record = { player = player, name = player.Name, state = {} }
            Entities.byPlayer[player] = record
        end
        local parts = partsOf(record, model)
        local tool = model:FindFirstChildOfClass("Tool")
        record.root = parts.HumanoidRootPart or parts.Torso
        record.torso = parts.Torso or record.root
        record.head = parts.Head
        record.humanoid, record.health, record.maxHealth = humanoid, humanoid.Health, humanoid.MaxHealth
        record.team = Game.team(player)
        record.teamColor = player.TeamColor
        record.relation = Game.relation(player)
        record.enemy = Game.isEnemy(player)
        Game.state(player, record.state)
        record.weaponTool = tool
        record.weaponName = tool and tool.Name or nil
        local anchor = record.root
        record.pos = anchor and anchor.Position or nil
        record.vel = anchor and anchor.AssemblyLinearVelocity or nil
        record.parked = record.pos ~= nil and type(floor) == "number" and record.pos.Y < floor
        return record
    end

    function Entities.update()
        if Entities.frame == Game.frame then return Entities.list end
        Entities.frame = Game.frame
        Entities.calls = Entities.calls + 1
        local list, shown, seen = {}, {}, {}
        local floor = Workspace.FallenPartsDestroyHeight
        for _, player in ipairs(Players:GetPlayers()) do
            local model = player ~= LocalPlayer and player.Character or nil
            local humanoid = Game.humanoid(model)
            if model and humanoid then
                seen[player] = true
                local ok, record = pcall(refresh, player, model, humanoid, floor)
                if not ok then
                    Util.note("entity" .. tostring(record), "entity (" .. tostring(player.Name) .. "):", record)
                elseif Entities.present(record) then
                    shown[#shown + 1] = record
                    if not record.parked then list[#list + 1] = record end
                end
            end
        end
        for player in pairs(Entities.byPlayer) do
            if not seen[player] then Entities.byPlayer[player] = nil end
        end
        Entities.list, Entities.shown = list, shown
        return list
    end

    function Entities.clear()
        Entities.list, Entities.shown, Entities.byPlayer = {}, {}, {}
    end

    -- local character: died / respawn / arrested
    local localWatch = {}
    local function dropLocalWatch()
        for _, connection in ipairs(localWatch.connections or {}) do pcall(function() connection:Disconnect() end) end
        localWatch = {}
    end

    local function bindLocal(character)
        local humanoid = Game.humanoid(character)
        if localWatch.character == character and localWatch.humanoid == humanoid then return end
        dropLocalWatch()
        local watch = { character = character, humanoid = humanoid, connections = {} }
        localWatch = watch
        if not character then return end
        if humanoid then
            watch.connections[1] = humanoid.Died:Connect(function()
                if watch.died then return end
                watch.died = true
                Game.events.onLocalDied:Fire()
            end)
        else
            watch.connections[1] = character.ChildAdded:Connect(function(child)
                if localWatch == watch and child:IsA("Humanoid") then bindLocal(character) end
            end)
        end
    end

    if LocalPlayer.Character then bindLocal(LocalPlayer.Character) end
    Util.track(LocalPlayer.CharacterAdded:Connect(function(character)
        Game.arrested = false
        bindLocal(character)
        Game.events.onRespawn:Fire(character)
    end))
    Util.track(Players.PlayerRemoving:Connect(function(player) Entities.byPlayer[player] = nil end))

    local arrested = Game.remote("Remotes.ClientArrested")
    if arrested then
        Util.track(arrested.OnClientEvent:Connect(function(...)
            Game.arrested = true
            Game.events.onArrested:Fire(...)
        end))
    end
    local tased = Game.remote("GunRemotes.PlayerTased")
    if tased then
        Util.track(tased.OnClientEvent:Connect(function(...) Game.events.onTased:Fire(...) end))
    end

    -- shots
    local function pointOf(object)
        if not object then return nil end
        if object:IsA("Attachment") then return object.WorldPosition end
        if object:IsA("BasePart") then return object.Position end
        return nil
    end

    function Game.muzzlePosition(tool)
        if not tool then return nil end
        local handle = tool:FindFirstChild("Handle")
        return pointOf(tool:FindFirstChild("Muzzle")) or pointOf(handle and handle:FindFirstChild("Muzzle"))
    end

    local function barrelOf(tool)
        return Game.muzzlePosition(tool) or pointOf(tool and tool:FindFirstChild("Handle"))
    end

    function Game.shotOrigin(player, fallback)
        local character = player and player.Character
        if not character then return fallback end
        local muzzle = Game.muzzlePosition(character:FindFirstChildOfClass("Tool"))
        if muzzle then return muzzle end
        local head = character:FindFirstChild("Head")
        return head and head.Position or fallback
    end

    function Game.isLocalShot(origin)
        local barrel = barrelOf(Game.weapon())
        return barrel ~= nil and (barrel - origin).Magnitude <= 1.5
    end

    -- the server echoes our own shots from our HEAD (only the local createX call uses the muzzle)
    local function isOwnEcho(origin, shooter)
        if not Game.lastOwnShot or os.clock() - Game.lastOwnShot > 1 then return false end
        local character = Game.localCharacter()
        local head = character and character:FindFirstChild("Head")
        local distance = head and (head.Position - origin).Magnitude
        if not distance or distance > 2.5 then return false end
        local other = shooter and shooter.Character and shooter.Character:FindFirstChild("Head")
        return not other or distance < (other.Position - origin).Magnitude
    end

    function Game.guessShooter(origin)
        local best, bestDistance = nil, 8
        for _, player in ipairs(Players:GetPlayers()) do
            local character = player ~= LocalPlayer and player.Character
            if character then
                local head = character:FindFirstChild("Head")
                local distance = head and (head.Position - origin).Magnitude or math.huge
                local barrel = barrelOf(character:FindFirstChildOfClass("Tool"))
                if barrel then distance = math.min(distance, (barrel - origin).Magnitude) end
                if distance < bestDistance then best, bestDistance = player, distance end
            end
        end
        return best
    end

    local HIT_WINDOW = 0.8
    Game.hits = { pending = {}, watched = {}, window = HIT_WINDOW }

    function Game.reportCast(part, position)
        Game.lastCast = { part = part, position = position, at = os.clock() }
    end

    function Game.resolveShot(origin, hitPos)
        local cast = Game.lastCast
        if cast and cast.part and os.clock() - cast.at < 0.25 and (cast.position - hitPos).Magnitude < 1 then return cast.part, cast.position end
        local offset = hitPos - origin
        if offset.Magnitude < 0.1 then return nil, hitPos end
        local vector = offset.Unit * (offset.Magnitude + 1)
        local ignore = { Game.camera(), Game.localCharacter() }
        local result = Game.cast(origin, vector, Game.newParams(ignore))
        if result and Game.playerFromPart(result.Instance) then return result.Instance, result.Position end
        local characters = {}
        for _, other in ipairs(Players:GetPlayers()) do
            if other ~= LocalPlayer and other.Character then characters[#characters + 1] = other.Character end
        end
        if #characters > 0 then
            local through = Workspace:Raycast(origin, vector, Game.newParams(characters, true))
            if through and Game.playerFromPart(through.Instance) then return through.Instance, through.Position end
        end
        return result and result.Instance, result and result.Position or hitPos
    end

    local watchVictim

    function Game.ensureWatched(player)
        if not player or player == LocalPlayer then return end
        local character = player.Character
        if not character then return end
        local entry = Game.hits.watched[player]
        if entry and entry.character == character and entry.humanoid == Game.humanoid(character) then return end
        watchVictim(player, character)
    end

    function Game.ownShot(origin, hitPos, behavior, part)
        local now = os.clock()
        Game.lastOwnShot = now
        local position = hitPos
        if not part then part, position = Game.resolveShot(origin, hitPos) end
        Game.events.onOwnShot:Fire(origin, hitPos, part, behavior)
        local victim = part and Game.playerFromPart(part)
        if not victim or victim == LocalPlayer then return end
        Game.ensureWatched(victim)
        local queue = Game.hits.pending[victim] or {}
        Game.hits.pending[victim] = queue
        local partName = part.Name
        if partName == "HumanoidRootPart" then partName = "Torso" end
        queue[#queue + 1] = { expiry = now + HIT_WINDOW, at = now, position = position, partName = partName }
    end

    local function consume(player)
        local queue = Game.hits.pending[player]
        if not queue then return nil end
        local now = os.clock()
        while #queue > 0 and queue[1].expiry < now do table.remove(queue, 1) end
        if #queue == 0 then
            Game.hits.pending[player] = nil
            return nil
        end
        return table.remove(queue, 1)
    end

    local function unwatch(player)
        local entry = Game.hits.watched[player]
        if not entry then return end
        for _, connection in ipairs(entry.connections) do pcall(function() connection:Disconnect() end) end
        Game.hits.watched[player] = nil
    end

    -- a health drop within HIT_WINDOW of one of our shots on that player is our hit; Died after it is our kill
    function watchVictim(player, character)
        unwatch(player)
        local humanoid = Game.humanoid(character)
        if not humanoid then
            local waiting = { connections = {}, character = character }
            Game.hits.watched[player] = waiting
            waiting.connections[1] = character.ChildAdded:Connect(function(child)
                if Game.hits.watched[player] == waiting and child:IsA("Humanoid") then watchVictim(player, character) end
            end)
            return
        end
        local entry = { connections = {}, previous = humanoid.Health, character = character, humanoid = humanoid }
        Game.hits.watched[player] = entry
        local function kill(pending)
            entry.killed = true
            Game.events.onKill:Fire(player, pending.position, pending.partName)
        end
        entry.connections[1] = humanoid.HealthChanged:Connect(function(health)
            health = type(health) == "number" and health or humanoid.Health
            local damage = entry.previous - health
            entry.previous = health
            if damage <= 0 or entry.killed then return end
            local pending = consume(player)
            if not pending then return end
            entry.last = pending
            local killed = health <= 0
            Game.events.onHit:Fire(player, damage, pending.position, pending.partName, killed)
            if killed then kill(pending) end
        end)
        entry.connections[2] = humanoid.Died:Connect(function()
            if entry.killed then return end
            local pending = consume(player)
            local last = entry.last
            if not pending and last and os.clock() - last.at < HIT_WINDOW then pending = last end
            if pending then kill(pending) end
        end)
    end

    local function watchPlayer(player)
        if player == LocalPlayer then return end
        if player.Character then watchVictim(player, player.Character) end
        Util.track(player.CharacterAdded:Connect(function(character) watchVictim(player, character) end))
    end
    for _, player in ipairs(Players:GetPlayers()) do watchPlayer(player) end
    Util.track(Players.PlayerAdded:Connect(watchPlayer))
    Util.track(Players.PlayerRemoving:Connect(function(player)
        unwatch(player)
        Game.hits.pending[player] = nil
    end))

    -- own shots: the game's GunTracers.createX runs for every local shot with the muzzle as origin
    local TRACER_KINDS = { createBullet = false, createSniper = "Sniper", createTaser = "Taser" }
    local function hookTracers()
        local module
        pcall(function() module = require(Game.remote("SharedModules.GunTracers")) end)
        if type(module) ~= "table" then return false end
        Game.tracers = module
        for name, behavior in pairs(TRACER_KINDS) do
            Util.hook(module, name, function(original)
                return function(origin, target, ...)
                    if typeof(origin) == "Vector3" and typeof(target) == "Vector3" then
                        local own = Game.isLocalShot(origin)
                        if own then Util.guard("own shot", Game.ownShot, origin, target, behavior or nil) end
                        local filter = Game.tracerFilter
                        if type(filter) == "function" then
                            local ok, hide = pcall(filter, origin, target, behavior or nil, own)
                            if ok and hide then return end
                        end
                    end
                    return original(origin, target, ...)
                end
            end)
        end
        return true
    end
    Game.tracerHooked = hookTracers()

    local replicate = Game.remote("GunRemotes.ReplicateEvent")
    if replicate then
        Util.track(replicate.OnClientEvent:Connect(function(list)
            if type(list) ~= "table" then return end
            for _, shot in ipairs(list) do
                if type(shot) == "table" then
                    local origin, hitPos, behavior = shot[1], shot[2], shot[3]
                    if typeof(origin) == "Vector3" and typeof(hitPos) == "Vector3" and not Game.isLocalShot(origin) then
                        local shooter = Game.guessShooter(origin)
                        if not isOwnEcho(origin, shooter) then Game.events.onEnemyShot:Fire(shooter, origin, hitPos, behavior) end
                    end
                end
            end
        end))
    end

    -- castRay discovery: ActionArea.InputBegan handler -> upvalue 2 = shoot -> its castRay upvalue; getgc as fallback
    local function functionName(fn)
        if type(Compat.info) ~= "function" then return nil end
        local ok, name = pcall(Compat.info, fn, "n")
        return ok and name or nil
    end

    local function sourceOf(fn)
        if type(Compat.info) ~= "function" then return "" end
        local ok, source = pcall(Compat.info, fn, "s")
        return ok and tostring(source) or ""
    end

    local function upvalue(fn, index)
        if type(Compat.getupvalue) ~= "function" then return nil end
        local ok, value = pcall(Compat.getupvalue, fn, index)
        return ok and value or nil
    end

    local function castOf(shoot)
        for index = 1, 40 do
            local value = upvalue(shoot, index)
            if type(value) == "function" and functionName(value) == "castRay" then return value end
        end
        local fallback = upvalue(shoot, 16)
        return type(fallback) == "function" and fallback or nil
    end

    local function byConnections()
        if type(Compat.getconnections) ~= "function" then return nil end
        local gui = LocalPlayer:FindFirstChild("PlayerGui")
        local home = gui and gui:FindFirstChild("Home")
        local hud = home and home:FindFirstChild("hud")
        local area = hud and hud:FindFirstChild("ActionArea")
        if not area then return nil end
        local ok, list = pcall(Compat.getconnections, area.InputBegan)
        if not ok or type(list) ~= "table" then return nil end
        for _, connection in ipairs(list) do
            local fn = connection.Function
            local shoot = fn and upvalue(fn, 2)
            if type(shoot) == "function" then
                local cast = castOf(shoot)
                if cast then return cast, shoot end
            end
        end
        return nil
    end

    local function byGc()
        local function accept(fn)
            if type(fn) ~= "function" then return false end
            if Compat.isexecutorclosure and Compat.isexecutorclosure(fn) then return false end
            return functionName(fn) == "castRay" and string.find(sourceOf(fn), "GunController", 1, true) ~= nil
        end
        local getters = {
            Compat.filtergc and function() return Compat.filtergc("function", { Name = "castRay" }) end or false,
            Compat.getgc or false,
        }
        for _, getter in ipairs(getters) do
            if type(getter) == "function" then
                local ok, list = pcall(getter)
                if ok and type(list) == "table" then
                    for _, fn in ipairs(list) do
                        if accept(fn) then return fn end
                    end
                end
            end
        end
        return nil
    end

    function Game.findCastRay()
        if Game.castRay then return Game.castRay end
        local cast, shoot = byConnections()
        if not cast then cast = byGc() end
        Game.castRay, Game.shoot = cast, shoot
        return cast
    end
    Game.findCastRay()

    Util.onUnload(function()
        dropLocalWatch()
        for player in pairs(Game.hits.watched) do unwatch(player) end
        Game.hits.pending, Game.lastCast, Game.tracerFilter = {}, nil, nil
        for _, bus in pairs(Game.events) do bus:Clear() end
        Entities.clear()
    end)
end
bootMark("game", PL2BootT, 3, 13)

PL2BootT = PL2BootClock()
-- [src] 15_menu.lua
do
    Util.stage("building menu", 0.3)
    win = Aster:Window({
        title = "aster", folder = FOLDER, key = "insert", game = "Prison Life",
        user = { id = LocalPlayer and LocalPlayer.UserId or 0, display = LocalPlayer and LocalPlayer.DisplayName or "", name = LocalPlayer and LocalPlayer.Name or "" },
    })

    -- a strip page keeps one card set per strip value; this view points Page:Card at one of them
    local function view(page, value)
        local set = page.Variant.sets[tostring(value)]
        local handle = { page = page, value = value, set = set }
        function handle:Card(opts)
            local before = page._building
            page._building = set
            local ok, card = pcall(page.Card, page, opts)
            page._building = before
            if not ok then error(card, 2) end
            return card
        end
        return handle
    end

    local function items(list)
        local out = {}
        for index, item in ipairs(list) do
            if type(item) == "table" then out[index] = { k = item[1], label = item[2] } else out[index] = { k = item } end
        end
        return out
    end

    local SPEC = {
        { "combat", "combat", {
            { "legit", strip = { "legit.mode", { "aim", "silent", "trigger" } } },
            { "rage", strip = { "rage.mode", { "ragebot", "void", "weapon", "other" } } },
        } },
        { "visuals", "visuals", {
            { "esp", strip = { "esp.side", { "enemies", "team", "local" } } },
            { "world", strip = { "world.mode", { "lighting", "sky", "weather" } } },
            { "indicators" },
        } },
        { "effects", "target", {
            { "shoot" }, { "hit" }, { "kill" },
            { "gun sounds", id = "gunsounds", strip = { "sfx_weapon", {} } },
            { "atmosphere" },
        } },
        { "misc", "misc", {
            { "movement" }, { "character" }, { "interact" }, { "teleport" },
            { "vehicles", strip = { "vehicles.mode", { "spawner", "orbit" } } },
            { "server" },
        } },
        { "avatar", "players", {
            { "builder", wide = true }, { "outfits", wide = true }, { "players", wide = true },
        } },
    }
    for _, weapon in ipairs(Data.FX_WEAPONS) do
        table.insert(SPEC[3][3][4].strip[2], { weapon.key, string.lower(weapon.label) })
    end

    for _, tabSpec in ipairs(SPEC) do
        local tabName = tabSpec[1]
        local tab = win:Tab({ name = tabName, icon = tabSpec[2] })
        local pages = {}
        Pages.tabs[tabName], Pages[tabName], Pages.strips[tabName] = tab, pages, {}
        for _, pageSpec in ipairs(tabSpec[3]) do
            local key = pageSpec.id or pageSpec[1]
            local page = tab:Page({ name = pageSpec[1], id = pageSpec.id, wide = pageSpec.wide })
            pages[key] = page
            local stripSpec = pageSpec.strip
            if stripSpec then
                local list = items(stripSpec[2])
                local strip = page:Strip({ flag = stripSpec[1], items = list, default = list[1].k, save = false })
                Pages.strips[tabName][key] = strip
                page:Variants(strip, function() end)
                for _, item in ipairs(list) do pages[key .. "." .. item.k] = view(page, item.k) end
            end
        end
    end
end
bootMark("menu", PL2BootT, 4, 13)

PL2BootT = PL2BootClock()
-- [src] 20_esp.lua
do
    local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
    local STUDS_TO_M = 0.28
    local R6 = { "Head", "Torso", "HumanoidRootPart", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }
    local CHAM_PARTS = { "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }
    local BOUND_PARTS = { "Head", "Torso", "Left Leg", "Right Leg" }
    local PART_SIZES = {
        Head = Vector3.new(2, 1, 1), Torso = Vector3.new(2, 2, 1),
        ["Left Arm"] = Vector3.new(1, 2, 1), ["Right Arm"] = Vector3.new(1, 2, 1),
        ["Left Leg"] = Vector3.new(1, 2, 1), ["Right Leg"] = Vector3.new(1, 2, 1),
    }
    local PART_CORNERS = {}
    for name, size in pairs(PART_SIZES) do
        local list = {}
        for _, sx in ipairs({ -1, 1 }) do
            for _, sy in ipairs({ -1, 1 }) do
                for _, sz in ipairs({ -1, 1 }) do list[#list + 1] = Vector3.new(size.X * 0.5 * sx, size.Y * 0.5 * sy, size.Z * 0.5 * sz) end
            end
        end
        PART_CORNERS[name] = list
    end
    local LIMBS = { { "Left Arm", "neck" }, { "Right Arm", "neck" }, { "Left Leg", "pelvis" }, { "Right Leg", "pelvis" } }
    local CORNER_SEGMENTS = { { 0, 0, 1, 0 }, { 0, 0, 0, 1 }, { 1, 0, -1, 0 }, { 1, 0, 0, 1 }, { 0, 1, 1, 0 }, { 0, 1, 0, -1 }, { 1, 1, -1, 0 }, { 1, 1, 0, -1 } }
    local STATE_TAGS = { { "hostile", "Hostile" }, { "trespassing", "Trespassing" }, { "tased", "Tased" }, { "forcefield", "Forcefield" } }

    local function col(flag, default)
        local value = F(flag)
        if typeof(value) == "Color3" then return value end
        return default or WHITE
    end
    -- aster alpha is opacity (1 = solid); dev.lua stored the picker's transparency
    local function opacity(flag, default)
        local el = Aster.Elements[flag]
        if el and el.Alpha then
            local ok, value = pcall(el.Alpha, el)
            if ok and type(value) == "number" then return value end
        end
        return default or 1
    end
    local function num(flag, default)
        local value = F(flag)
        return type(value) == "number" and value or default
    end

    -- Draw: Drawing objects behind a write-on-change proxy, so an unchanged frame costs no property writes
    Draw = { all = {}, hasApi = (type(Drawing) == "table" or type(Drawing) == "userdata") }
    local SINK = setmetatable({}, { __newindex = function() end, __index = function() return function() end end })
    Draw.SINK = SINK

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

    function Draw.text(size, z)
        return Draw.new("Text", { Size = size or 13, Font = 2, Center = true, Outline = true, OutlineColor = BLACK, ZIndex = z or 8, Visible = false })
    end

    function Draw.project(cam, position)
        local point = cam:WorldToViewportPoint(position)
        return Vector2.new(point.X, point.Y), point.Z > 0, point.Z
    end

    Util.onUnload(function()
        for object in pairs(Draw.all) do pcall(function() object:Remove() end) end
        Draw.all = {}
    end)

    -- Visible: cached line-of-sight for combat and ESP; player bodies are skipped so any hit means a wall
    Visible = { cache = setmetatable({}, { __mode = "k" }), bodies = setmetatable({}, { __mode = "k" }), nextFilter = 0 }
    Visible.params = Game.newParams()
    local VIS_ORDER = { "Head", "Torso", "Right Leg", "Left Arm", "Left Leg", "Right Arm" }

    function Visible.refresh(now)
        for model in pairs(Visible.bodies) do
            if not model.Parent then Visible.bodies[model] = nil end
        end
        for _, rec in pairs(Entities.byPlayer) do
            if rec.model then Visible.bodies[rec.model] = true end
        end
        if now < Visible.nextFilter or not Visible.params then return end
        Visible.nextFilter = now + 1
        local list = {}
        local cam, character = Game.camera(), Game.localCharacter()
        if cam then list[#list + 1] = cam end
        if character then list[#list + 1] = character end
        pcall(function() Visible.params.FilterDescendantsInstances = list end)
    end

    function Visible.skip(part)
        return Game.skipHit(part) or Visible.bodies[part.Parent] ~= nil
    end

    function Visible.ray(origin, position)
        return Game.cast(origin, (position - origin) * 0.998, Visible.params, Visible.skip) == nil
    end

    function Visible.check(part, origin, now)
        now = now or os.clock()
        if Visible.frame ~= Game.frame then
            Visible.frame = Game.frame
            Visible.refresh(now)
        end
        origin = origin or Game.eye()
        local cached = Visible.cache[part]
        if cached and (cached[3] == Game.frame or now - cached[1] < 0.06) then return cached[2] end
        local result = origin ~= nil and Visible.ray(origin, part.Position)
        Visible.cache[part] = { now, result, Game.frame }
        return result
    end

    function Visible.entity(rec, origin, now, interval)
        local cached = rec.visCache
        if cached and (cached.frame == Game.frame or now - cached.at < (interval or 0.1)) then return cached.value end
        local value = false
        for index = 1, 3 do
            local part = rec.parts and rec.parts[VIS_ORDER[index]]
            if part and part.Parent and Visible.check(part, origin, now) then
                value = true
                break
            end
        end
        rec.visCache = { at = now, frame = Game.frame, value = value }
        return value
    end

    -- Highlights and adornments live in one hidden folder instead of inside the characters
    local Gui = {}
    function Gui.folder()
        if Gui.box and Gui.box.Parent then return Gui.box end
        local parents = {}
        pcall(function() if Compat.gethui then parents[#parents + 1] = Compat.gethui() end end)
        pcall(function() parents[#parents + 1] = game:GetService("CoreGui") end)
        parents[#parents + 1] = Workspace.CurrentCamera
        for _, parent in ipairs(parents) do
            local ok, folder = pcall(function()
                local made = Instance.new("Folder")
                made.Name = HttpService:GenerateGUID(false)
                made.Parent = parent
                return made
            end)
            if ok and folder and folder.Parent then
                Gui.box = folder
                return folder
            end
        end
        return nil
    end

    function Gui.make(class, props)
        local folder = Gui.folder()
        if not folder then return nil end
        local ok, inst = pcall(Instance.new, class)
        if not (ok and inst) then return nil end
        for key, value in pairs(props or {}) do pcall(function() inst[key] = value end) end
        inst.Parent = folder
        return inst
    end

    Util.onUnload(function()
        if Gui.box then pcall(function() Gui.box:Destroy() end) end
        Gui.box = nil
    end)

    Esp = { objects = {}, chams = {}, glows = {}, cfg = {}, me = { parts = {}, state = {} }, previewHp = 62 }
    local cfg = Esp.cfg

    function Esp.read()
        local c = cfg
        c.players, c.self = F("esp_players") ~= false, F("esp_local_player") == true
        c.enemiesOnly, c.hostileOnly, c.teamColors = F("esp_enemies_only"), F("esp_hostile_only"), F("esp_use_team_color")
        c.friend, c.prio = F("rel_hl_friendly"), F("rel_hl_priority")
        c.friendColor, c.prioColor = col("rel_hl_friendly_color", Color3.fromRGB(80, 255, 120)), col("rel_hl_priority_color", Color3.fromRGB(255, 70, 70))
        c.text = num("esp_text_size", 12)
        c.box, c.boxType, c.boxThick = F("esp_box"), F("esp_box_type") or "Corner", num("esp_box_thickness", 1)
        c.boxColor, c.boxA = col("esp_box_color"), opacity("esp_box_color")
        c.outline, c.outlineColor = F("esp_outline_enabled"), col("esp_outline_color", BLACK)
        c.fill, c.fillColor, c.fillA = F("esp_fill"), col("esp_fill_color"), opacity("esp_fill_color", 0.1)
        c.glow, c.glowColor, c.glowT = F("esp_glow"), col("esp_glow_color"), 1 - opacity("esp_glow_color", 0.28)
        c.name, c.nameType, c.nameColor = F("esp_name"), F("esp_name_type") or "Username", col("esp_name_color1")
        c.hp, c.hpSide, c.hpWidth = F("esp_healthbar"), F("esp_health_position") or "Left", math.max(1, num("esp_health_width", 1))
        c.hpFull = col("esp_healthbar_color_start", Color3.fromRGB(0, 255, 0))
        c.hpMid = col("esp_healthbar_color_middle", Color3.fromRGB(255, 255, 0))
        c.hpLow = col("esp_healthbar_color_end", Color3.fromRGB(255, 0, 0))
        c.dist, c.distColor = F("esp_distance"), col("esp_distance_color")
        c.weapon, c.weaponColor = F("esp_weapon"), col("esp_weapon_color")
        c.skel, c.skelColor, c.skelThick = F("esp_skeleton"), col("esp_skeleton_color"), num("esp_skeleton_thickness", 1.5)
        c.arrows, c.arrowColor = F("esp_arrows"), col("esp_arrow_color")
        c.arrowSize, c.arrowOrbit = num("esp_arrow_size", 14), num("esp_arrow_orbit", 100)
        c.teamInd, c.teamIndColor = F("esp_team_indicator"), col("esp_team_color")
        c.flags, c.flagsColor = F("esp_flags"), col("esp_flags_color", Color3.fromRGB(255, 200, 80))
        c.chams = F("esp_chams")
        c.visColor, c.visT = col("esp_chams_adorn_vis_color", Color3.fromRGB(59, 204, 90)), 1 - opacity("esp_chams_adorn_vis_color", 0.65)
        c.occColor, c.occT = col("esp_chams_adorn_occ_color", Color3.fromRGB(59, 144, 204)), 1 - opacity("esp_chams_adorn_occ_color", 0.3)
        c.grow, c.chamGlow = num("esp_chams_adorn_thickness", 0.1), F("esp_chams_adorn_glow")
        c.glowSize = math.max(num("esp_chams_adorn_glow_size", 1.75), 1)
        c.round, c.headSize = F("esp_chams_adorn_round_head") ~= false, num("esp_chams_adorn_head_size", 1.15)
        c.chamSig = table.concat({ tostring(c.visColor), c.visT, tostring(c.occColor), c.occT, c.grow, tostring(c.chamGlow), c.glowSize, tostring(c.round), c.headSize }, "|")
    end

    function Esp.wanted(rec)
        if rec.player == LocalPlayer then return cfg.self end
        if not cfg.players then return false end
        if (rec.relation == "friend" and cfg.friend) or (rec.relation == "target" and cfg.prio) then return true end
        if cfg.enemiesOnly and not rec.enemy then return false end
        if cfg.hostileOnly and Game.isPeaceful(rec.player) then return false end
        return true
    end

    function Esp.tint(rec)
        if rec.player == LocalPlayer then return nil end
        if rec.relation == "friend" and cfg.friend then return cfg.friendColor end
        if rec.relation == "target" and cfg.prio then return cfg.prioColor end
        if cfg.teamColors and rec.teamColor then
            if typeof(rec.teamColor) == "BrickColor" then return rec.teamColor.Color end
            if typeof(rec.teamColor) == "Color3" then return rec.teamColor end
        end
        return nil
    end

    function Esp.nameOf(rec)
        local player = rec.player
        local name = player and player.Name or rec.name or "?"
        local display = player and player.DisplayName or name
        if display == nil or display == "" then display = name end
        if cfg.nameType == "Display name" then return display end
        if cfg.nameType == "Display (@username)" and display ~= name then return display .. " (@" .. name .. ")" end
        return name
    end

    -- the local player has no Entities record; build one in place each frame
    function Esp.selfRecord()
        local character = Game.localCharacter()
        local humanoid = character and Game.humanoid(character)
        if not (humanoid and humanoid.Health > 0) then return nil end
        local rec = Esp.me
        for _, name in ipairs(R6) do rec.parts[name] = character:FindFirstChild(name) end
        rec.player, rec.model, rec.humanoid, rec.name = LocalPlayer, character, humanoid, LocalPlayer.Name
        rec.head, rec.root = rec.parts.Head, rec.parts.HumanoidRootPart or rec.parts.Torso
        rec.torso = rec.parts.Torso or rec.root
        if not rec.torso then return nil end
        rec.health, rec.maxHealth, rec.pos = humanoid.Health, humanoid.MaxHealth, rec.root.Position
        rec.team, rec.teamColor, rec.enemy = Game.team(LocalPlayer), LocalPlayer.TeamColor, false
        local tool = Game.weapon()
        rec.weaponName = tool and tool.Name or nil
        return rec
    end

    function Esp.make()
        local o = { all = {}, corners = {}, cornerEdges = {}, bones = {}, boneEdges = {}, on = {} }
        local function add(drawing) o.all[#o.all + 1] = drawing return drawing end
        local function line(z, color) return add(Draw.new("Line", { Thickness = 1, ZIndex = z, Color = color, Visible = false })) end
        local function square(filled, z, color) return add(Draw.new("Square", { Thickness = 1, Filled = filled, ZIndex = z, Color = color, Visible = false })) end
        o.fill = square(true, 1)
        o.outer, o.box, o.inner = square(false, 2, BLACK), square(false, 3), square(false, 2, BLACK)
        o.ringEdge = add(Draw.new("Circle", { Filled = false, NumSides = 32, Thickness = 3, ZIndex = 2, Color = BLACK, Visible = false }))
        o.ring = add(Draw.new("Circle", { Filled = false, NumSides = 32, Thickness = 1, ZIndex = 3, Visible = false }))
        for index = 1, 8 do
            o.cornerEdges[index] = line(2, BLACK)
            o.corners[index] = line(3)
        end
        for index = 1, 10 do
            o.boneEdges[index] = line(2, BLACK)
            o.bones[index] = line(3)
        end
        o.hpBack, o.hpBar = square(true, 4, Color3.fromRGB(10, 10, 10)), square(true, 5)
        o.name, o.dist, o.weapon = add(Draw.text(13, 8)), add(Draw.text(13, 8)), add(Draw.text(13, 8))
        o.side = add(Draw.text(13, 8))
        o.side.Center = false
        o.arrowEdge = add(Draw.new("Triangle", { Filled = false, Thickness = 1, Color = BLACK, ZIndex = 5, Visible = false }))
        o.arrow = add(Draw.new("Triangle", { Filled = true, ZIndex = 6, Visible = false }))
        return o
    end

    function Esp.hide(o)
        if o.hidden then return end
        o.hidden = true
        for _, drawing in ipairs(o.all) do drawing.Visible = false end
    end

    function Esp.destroy(o)
        for _, drawing in ipairs(o.all) do Draw.remove(drawing) end
        o.all = {}
    end

    function Esp.bounds(cam, rec)
        local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
        local center = rec.torso.Position
        for _, name in ipairs(BOUND_PARTS) do
            local part = rec.parts[name]
            if part and part.Parent and (part.Position - center).Magnitude < 10 then
                local frame = part.CFrame
                for _, corner in ipairs(PART_CORNERS[name]) do
                    local point = cam:WorldToViewportPoint(frame:PointToWorldSpace(corner))
                    if point.Z > 0 then
                        minX, maxX = math.min(minX, point.X), math.max(maxX, point.X)
                        minY, maxY = math.min(minY, point.Y), math.max(maxY, point.Y)
                    end
                end
            end
        end
        if minX == math.huge or not (cam:WorldToViewportPoint(center).Z > 0) then return nil end
        local size = cam.ViewportSize
        minX, maxX = math.clamp(minX, -size.X, size.X * 2), math.clamp(maxX, -size.X, size.X * 2)
        minY, maxY = math.clamp(minY, -size.Y, size.Y * 2), math.clamp(maxY, -size.Y, size.Y * 2)
        return math.floor(minX), math.floor(minY), math.floor(maxX - minX), math.floor(maxY - minY)
    end

    local function show(o, drawing) o.on[drawing] = true return drawing end

    local function setLine(o, drawing, from, to, color, thick)
        drawing.From, drawing.To, drawing.Color, drawing.Thickness = from, to, color, thick
        o.on[drawing] = true
    end

    function Esp.skeleton(cam, o, rec, color)
        local parts = rec.parts
        local head, torso = parts.Head, parts.Torso
        if not (head and torso) then return end
        local frame = torso.CFrame
        local neck, pelvis = frame:PointToWorldSpace(Vector3.new(0, 1, 0)), frame:PointToWorldSpace(Vector3.new(0, -1, 0))
        local joints = { neck = neck, pelvis = pelvis }
        local segments = { { head.Position, neck }, { neck, pelvis } }
        for _, limb in ipairs(LIMBS) do
            local part = parts[limb[1]]
            if part and part.Parent then
                local top, bottom = part.CFrame:PointToWorldSpace(Vector3.new(0, 1, 0)), part.CFrame:PointToWorldSpace(Vector3.new(0, -1, 0))
                segments[#segments + 1] = { joints[limb[2]], top }
                segments[#segments + 1] = { top, bottom }
            end
        end
        for index, segment in ipairs(segments) do
            local a, aFront = Draw.project(cam, segment[1])
            local b, bFront = Draw.project(cam, segment[2])
            if aFront and bFront then
                if cfg.outline then setLine(o, o.boneEdges[index], a, b, cfg.outlineColor, cfg.skelThick + 2) end
                setLine(o, o.bones[index], a, b, color, cfg.skelThick)
            end
        end
    end

    function Esp.arrow(cam, o, rec, color, viewport)
        local rel = cam.CFrame:PointToObjectSpace(rec.pos)
        local length = math.sqrt(rel.X * rel.X + rel.Z * rel.Z)
        local dir = length < 0.001 and Vector2.new(0, 1) or Vector2.new(rel.X / length, rel.Z / length)
        local size = cfg.arrowSize
        local tip = Vector2.new(viewport.X / 2, viewport.Y / 2) + dir * cfg.arrowOrbit
        local side = Vector2.new(-dir.Y, dir.X) * (size * 0.6)
        local base = tip - dir * (size * 1.3)
        o.arrow.PointA, o.arrow.PointB, o.arrow.PointC, o.arrow.Color = tip, base + side, base - side, color
        show(o, o.arrow)
        if cfg.outline then
            o.arrowEdge.PointA, o.arrowEdge.PointB, o.arrowEdge.PointC, o.arrowEdge.Color = tip, base + side, base - side, cfg.outlineColor
            show(o, o.arrowEdge)
        end
    end

    function Esp.draw(cam, o, rec, dist, viewport)
        local tint = Esp.tint(rec)
        local x, y, w, h = Esp.bounds(cam, rec)
        o.hidden = false
        if not (x and x + w > 0 and x < viewport.X and y + h > 0 and y < viewport.Y) then
            if cfg.arrows then Esp.arrow(cam, o, rec, tint or cfg.arrowColor, viewport) end
        else
            if o.size ~= cfg.text then
                o.size = cfg.text
                for _, text in ipairs({ o.name, o.dist, o.weapon, o.side }) do text.Size = cfg.text end
            end
            local boxColor = tint or cfg.boxColor
            if cfg.fill then
                o.fill.Position, o.fill.Size, o.fill.Color, o.fill.Transparency = Vector2.new(x, y), Vector2.new(w, h), tint or cfg.fillColor, cfg.fillA
                show(o, o.fill)
            end
            if cfg.box and cfg.boxType == "Circle" then
                local center, radius = Vector2.new(x + w / 2, y + h / 2), math.max(w, h) / 2
                o.ring.Position, o.ring.Radius, o.ring.Color, o.ring.Thickness, o.ring.Transparency = center, radius, boxColor, cfg.boxThick, cfg.boxA
                show(o, o.ring)
                if cfg.outline then
                    o.ringEdge.Position, o.ringEdge.Radius, o.ringEdge.Thickness, o.ringEdge.Color = center, radius, cfg.boxThick + 2, cfg.outlineColor
                    show(o, o.ringEdge)
                end
            elseif cfg.box and cfg.boxType == "Normal" then
                o.box.Position, o.box.Size, o.box.Color, o.box.Thickness, o.box.Transparency = Vector2.new(x, y), Vector2.new(w, h), boxColor, cfg.boxThick, cfg.boxA
                show(o, o.box)
                if cfg.outline then
                    o.outer.Position, o.outer.Size, o.outer.Color = Vector2.new(x - 1, y - 1), Vector2.new(w + 2, h + 2), cfg.outlineColor
                    o.inner.Position, o.inner.Size, o.inner.Color = Vector2.new(x + 1, y + 1), Vector2.new(w - 2, h - 2), cfg.outlineColor
                    show(o, o.outer)
                    show(o, o.inner)
                end
            elseif cfg.box then
                local lenX, lenY = math.max(4, math.floor(w * 0.28)), math.max(4, math.floor(h * 0.2))
                for index, seg in ipairs(CORNER_SEGMENTS) do
                    local fx, fy = x + w * seg[1], y + h * seg[2]
                    local from, to = Vector2.new(fx, fy), Vector2.new(fx + lenX * seg[3], fy + lenY * seg[4])
                    if cfg.outline then setLine(o, o.cornerEdges[index], from, to, cfg.outlineColor, cfg.boxThick + 2) end
                    setLine(o, o.corners[index], from, to, boxColor, cfg.boxThick)
                end
            end

            local below = y + h + 2
            if cfg.hp then
                local frac = math.clamp(rec.health / math.max(rec.maxHealth, 1), 0, 1)
                local color
                if frac > 0.5 then color = cfg.hpMid:Lerp(cfg.hpFull, (frac - 0.5) * 2) else color = cfg.hpLow:Lerp(cfg.hpMid, frac * 2) end
                local bw = cfg.hpWidth
                if cfg.hpSide == "Top" or cfg.hpSide == "Bottom" then
                    local by = cfg.hpSide == "Top" and (y - bw - 3) or below
                    o.hpBack.Position, o.hpBack.Size = Vector2.new(x - 1, by - 1), Vector2.new(w + 2, bw + 2)
                    o.hpBar.Position, o.hpBar.Size = Vector2.new(x, by), Vector2.new(math.max(1, math.floor(w * frac)), bw)
                    if cfg.hpSide == "Bottom" then below = below + bw + 3 end
                else
                    local bx = cfg.hpSide == "Right" and (x + w + 3) or (x - bw - 3)
                    local bh = math.max(1, math.floor(h * frac))
                    o.hpBack.Position, o.hpBack.Size = Vector2.new(bx - 1, y - 1), Vector2.new(bw + 2, h + 2)
                    o.hpBar.Position, o.hpBar.Size = Vector2.new(bx, y + h - bh), Vector2.new(bw, bh)
                end
                o.hpBar.Color = color
                show(o, o.hpBack)
                show(o, o.hpBar)
            end
            if cfg.name then
                local top = y - cfg.text - 3
                if cfg.hp and cfg.hpSide == "Top" then top = top - cfg.hpWidth - 3 end
                o.name.Text, o.name.Position, o.name.Color = Esp.nameOf(rec), Vector2.new(x + w / 2, top), tint or cfg.nameColor
                show(o, o.name)
            end
            if cfg.dist then
                o.dist.Text, o.dist.Position, o.dist.Color = math.floor(dist * STUDS_TO_M) .. "m", Vector2.new(x + w / 2, below), cfg.distColor
                show(o, o.dist)
                below = below + cfg.text + 1
            end
            if cfg.weapon and rec.weaponName then
                o.weapon.Text, o.weapon.Position, o.weapon.Color = tostring(rec.weaponName), Vector2.new(x + w / 2, below), cfg.weaponColor
                show(o, o.weapon)
            end
            if cfg.teamInd or cfg.flags then
                local lines = {}
                if cfg.teamInd and rec.team then lines[#lines + 1] = tostring(rec.team) end
                if cfg.flags then
                    local state = rec.state or {}
                    for _, tag in ipairs(STATE_TAGS) do
                        if state[tag[1]] then lines[#lines + 1] = tag[2] end
                    end
                end
                if #lines > 0 then
                    local sx = x + w + ((cfg.hp and cfg.hpSide == "Right") and cfg.hpWidth + 6 or 4)
                    o.side.Text, o.side.Position = table.concat(lines, "\n"), Vector2.new(sx, y - 1)
                    o.side.Color = (cfg.teamInd and rec.team) and cfg.teamIndColor or cfg.flagsColor
                    show(o, o.side)
                end
            end
            if cfg.skel then Esp.skeleton(cam, o, rec, tint or cfg.skelColor) end
        end
        for _, drawing in ipairs(o.all) do
            if o.on[drawing] then
                o.on[drawing] = nil
                drawing.Visible = true
            else
                drawing.Visible = false
            end
        end
    end

    -- chams: two HandleAdornment layers per body part, re-styled only when the signature or part size changes
    local function dropPair(pair)
        pcall(function() pair.behind:Destroy() end)
        pcall(function() pair.visible:Destroy() end)
    end

    function Esp.dropChams(player)
        local data = Esp.chams[player]
        if not data then return end
        for _, pair in pairs(data.parts) do dropPair(pair) end
        Esp.chams[player] = nil
    end

    local function adornment(part, onTop, z, round)
        local inst = Gui.make(round and "CylinderHandleAdornment" or "BoxHandleAdornment", { AlwaysOnTop = onTop, ZIndex = z })
        if not inst then return nil end
        pcall(function() inst.AdornCullingMode = Enum.AdornCullingMode.Never end)
        if round then inst.CFrame = CFrame.new(Vector3.new(0, 0, 0), Vector3.new(0, 90, 0)) end
        inst.Adornee = part
        return inst
    end

    function Esp.chamsFor(rec, color)
        local data = Esp.chams[rec.player]
        if data and data.model ~= rec.model then
            Esp.dropChams(rec.player)
            data = nil
        end
        if not data then
            data = { model = rec.model, parts = {} }
            Esp.chams[rec.player] = data
        end
        local sig = cfg.chamSig .. "|" .. tostring(color)
        for _, name in ipairs(CHAM_PARTS) do
            local part = rec.parts[name]
            local pair = data.parts[name]
            local round = name == "Head" and cfg.round
            if pair and (pair.part ~= part or pair.round ~= round or not pair.visible.Parent) then
                dropPair(pair)
                data.parts[name], pair = nil, nil
            end
            if part and part.Parent and not pair then
                local behind, visible = adornment(part, true, 1, round), adornment(part, false, -1, round)
                if behind and visible then
                    pair = { part = part, round = round, behind = behind, visible = visible }
                    data.parts[name] = pair
                else
                    dropPair({ behind = behind, visible = visible })
                end
            end
            if pair and (pair.sig ~= sig or pair.size ~= part.Size) then
                pair.sig, pair.size = sig, part.Size
                local grow = cfg.grow
                if round then
                    local size = part.Size
                    local radius, height = math.min(size.X, size.Z) / 2 * cfg.headSize, size.Y * cfg.headSize
                    pair.behind.Radius, pair.behind.Height = radius, height
                    pair.visible.Radius, pair.visible.Height = radius + grow / 2, height + grow
                else
                    pair.behind.Size, pair.visible.Size = part.Size, part.Size + Vector3.new(grow, grow, grow)
                end
                pair.behind.Color3, pair.behind.Transparency = cfg.occColor, cfg.occT
                pair.visible.Color3, pair.visible.AlwaysOnTop = color, cfg.chamGlow == true
                pair.visible.Transparency = cfg.chamGlow and cfg.visT / cfg.glowSize or cfg.visT
            end
        end
    end

    function Esp.glowFor(rec, color)
        local light = Esp.glows[rec.player]
        if not (light and light.Parent) then
            light = Gui.make("Highlight", { DepthMode = Enum.HighlightDepthMode.AlwaysOnTop })
            Esp.glows[rec.player] = light
            if not light then return end
        end
        if light.Adornee ~= rec.model then light.Adornee = rec.model end
        if light.FillColor ~= color then light.FillColor, light.OutlineColor = color, color end
        if light.FillTransparency ~= cfg.glowT then light.FillTransparency = cfg.glowT end
    end

    function Esp.dropGlow(player)
        local light = Esp.glows[player]
        if light then pcall(function() light:Destroy() end) end
        Esp.glows[player] = nil
    end

    function Esp.process(cam, rec, origin, viewport, seen)
        if not (rec.model and rec.torso and rec.torso.Parent) or not Esp.wanted(rec) then return end
        seen[rec.player] = true
        local tint = Esp.tint(rec)
        if cfg.chams then Esp.chamsFor(rec, tint or cfg.visColor) else Esp.dropChams(rec.player) end
        if cfg.glow then Esp.glowFor(rec, tint or cfg.glowColor) else Esp.dropGlow(rec.player) end
        if not Draw.hasApi then return end
        local o = Esp.objects[rec.player]
        if not o then
            o = Esp.make()
            Esp.objects[rec.player] = o
        end
        Esp.draw(cam, o, rec, (rec.pos - origin).Magnitude, viewport)
    end

    function Esp.step(dt, now, records)
        local cam = Game.camera()
        if not cam then return end
        Esp.read()
        local origin, viewport, seen = cam.CFrame.Position, cam.ViewportSize, {}
        for _, rec in ipairs(Entities.shown or records or {}) do
            local ok, problem = pcall(Esp.process, cam, rec, origin, viewport, seen)
            if not ok then Util.note("esp:" .. tostring(problem), "esp (" .. tostring(rec.name) .. "):", problem) end
        end
        if cfg.self then
            local rec = Esp.selfRecord()
            if rec then Util.guard("esp self", Esp.process, cam, rec, origin, viewport, seen) end
        end
        for player, o in pairs(Esp.objects) do
            if not seen[player] then
                Esp.hide(o)
                if not player.Parent then
                    Esp.destroy(o)
                    Esp.objects[player] = nil
                end
            end
        end
        for player in pairs(Esp.chams) do
            if not seen[player] then Esp.dropChams(player) end
        end
        for player in pairs(Esp.glows) do
            if not seen[player] then Esp.dropGlow(player) end
        end
    end

    function Esp.clear()
        for player, o in pairs(Esp.objects) do
            Esp.destroy(o)
            Esp.objects[player] = nil
        end
        for player in pairs(Esp.chams) do Esp.dropChams(player) end
        for player in pairs(Esp.glows) do Esp.dropGlow(player) end
    end

    Util.feature("esp_enabled", function()
        Loop.register("esp", Esp.step, 100)
    end, function()
        Loop.unregister("esp")
        Esp.clear()
    end)
    Util.onUnload(Esp.clear)

    -- FOV circles: radius from Combat when it scales the FOV, else the slider
    local Circles = { list = {} }
    Esp.circles = Circles
    function Circles.step()
        local mouse = UserInputService:GetMouseLocation()
        for _, prefix in ipairs({ "aim", "silent" }) do
            local circle = Circles.list[prefix]
            if not circle then
                circle = Draw.new("Circle", { NumSides = 64, ZIndex = 9, Visible = false })
                Circles.list[prefix] = circle
            end
            local on = F(prefix .. "_fov_show") == true
            if on then
                local radius = num(prefix .. "_fov", 120)
                if Combat and type(Combat.fovRadius) == "function" then
                    local ok, value = pcall(Combat.fovRadius, prefix)
                    if ok and type(value) == "number" then radius = value end
                end
                circle.Position, circle.Radius = mouse, radius
                circle.Color, circle.Transparency = col(prefix .. "_fov_color"), opacity(prefix .. "_fov_color")
                circle.Filled, circle.Thickness = F(prefix .. "_fov_filled") == true, num(prefix .. "_fov_thick", 1)
            end
            circle.Visible = on
        end
    end
    function Circles.sync()
        if F("aim_fov_show") or F("silent_fov_show") then
            Loop.register("fov_circles", Circles.step, 120)
        elseif Loop.has("fov_circles") then
            Loop.unregister("fov_circles")
            for _, circle in pairs(Circles.list) do circle.Visible = false end
        end
    end
    Util.changed({ "aim_fov_show", "silent_fov_show" }, Circles.sync)
    Circles.sync()

    -- crosshair: four Drawing arms (X9 cut the spread pulse and per-arm toggles)
    local Cross = { arms = {}, edges = {} }
    Esp.cross = Cross
    function Cross.step(dt, now)
        if #Cross.arms == 0 then
            for index = 1, 4 do
                Cross.edges[index] = Draw.new("Line", { ZIndex = 10, Visible = false })
                Cross.arms[index] = Draw.new("Line", { ZIndex = 11, Visible = false })
            end
        end
        if F("crosshair_hide_cursor") and UserInputService.MouseIconEnabled then Util.hold("crosshair", UserInputService, "MouseIconEnabled", false) end
        if not F("crosshair_hide_cursor") and Util.held(UserInputService, "MouseIconEnabled") then Util.restore("crosshair") end
        local mouse = UserInputService:GetMouseLocation()
        local angle = num("crosshair_rotation_angle", 0)
        if F("crosshair_rotation") then angle = angle + num("crosshair_rotation_speed", 90) * now end
        local gap, length, thick = num("crosshair_gap", 6), math.max(1, num("crosshair_length", 12)), math.max(1, num("crosshair_thickness", 2))
        local color, outline, edgeColor = col("crosshair_color"), F("crosshair_outline") == true, col("crosshair_outline_color", BLACK)
        for index = 1, 4 do
            local rad = math.rad(angle + index * 90)
            local dir = Vector2.new(math.cos(rad), math.sin(rad))
            local from, to = mouse + dir * gap, mouse + dir * (gap + length)
            local arm, edge = Cross.arms[index], Cross.edges[index]
            arm.From, arm.To, arm.Color, arm.Thickness, arm.Visible = from, to, color, thick, true
            if outline then
                edge.From, edge.To, edge.Color, edge.Thickness = from - dir, to + dir, edgeColor, thick + 2
            end
            edge.Visible = outline
        end
    end
    Util.feature("crosshair_enabled", function()
        Loop.register("crosshair", Cross.step, 130)
    end, function()
        Loop.unregister("crosshair")
        Util.restore("crosshair")
        for index = 1, #Cross.arms do
            Cross.arms[index].Visible = false
            Cross.edges[index].Visible = false
        end
    end)

    -- camera fov: the game drops FieldOfView when scoped, so only an unscoped camera is overridden
    local SCOPE_FOV = 30
    local CamFov = {}
    function CamFov.step()
        local cam = Game.camera()
        if not cam then return end
        if not CamFov.base then CamFov.base = cam.FieldOfView > SCOPE_FOV and cam.FieldOfView or 70 end
        local want = num("camera_fov_changer_amount", 100)
        if cam.FieldOfView > SCOPE_FOV and cam.FieldOfView ~= want then cam.FieldOfView = want end
    end
    Util.feature("camera_fov_changer", function()
        Loop.register("camera_fov", CamFov.step, 200)
    end, function()
        Loop.unregister("camera_fov")
        local cam = Game.camera()
        if cam and CamFov.base and cam.FieldOfView > SCOPE_FOV then pcall(function() cam.FieldOfView = CamFov.base end) end
        CamFov.base = nil
    end)

    -- local visuals: every write goes through Util.hold so toggling off or unloading restores the originals
    local Lv = { flags = { "viewmodel_body_color", "viewmodel_material_value", "viewmodel_disable_textures", "viewmodel_chams", "arm_material", "arm_disable_textures", "arm_remove_accessories", "Self_Chams" }, at = 0 }
    Esp.localVisuals = Lv

    local function texture(name)
        local list = Data.FORCEFIELD_TEXTURES or {}
        local id = list[name]
        if id == nil then
            for _, entry in ipairs(list) do
                if type(entry) == "table" and entry[1] == name then id = entry[2] end
            end
        end
        return (type(id) == "string" and id ~= "") and id or nil
    end

    function Lv.textureNames()
        local list, names = Data.FORCEFIELD_TEXTURES or {}, {}
        if Data.FORCEFIELD_NAMES then return Data.FORCEFIELD_NAMES end
        for _, entry in ipairs(list) do
            if type(entry) == "table" then names[#names + 1] = entry[1] end
        end
        if #names == 0 then
            for name in pairs(list) do names[#names + 1] = name end
            table.sort(names)
        end
        if names[1] ~= "Disabled" then table.insert(names, 1, "Disabled") end
        return names
    end

    local function put(tag, inst, key, value)
        local ok, current = pcall(function() return inst[key] end)
        if ok and current ~= value then Util.hold(tag, inst, key, value) end
    end

    function Lv.style(tag, inst, c)
        if inst:IsA("BasePart") then
            if inst.Transparency < 1 or Util.held(inst, "Transparency") then
                if c.color then put(tag, inst, "Color", c.color) end
                if c.transparency then put(tag, inst, "Transparency", c.transparency) end
                if c.material then put(tag, inst, "Material", c.material) end
            end
            if inst:IsA("MeshPart") and (c.texture or c.plain) then put(tag, inst, "TextureID", c.texture or "") end
        elseif inst:IsA("SpecialMesh") and (c.texture or c.plain) then
            put(tag, inst, "TextureId", c.texture or "")
        elseif inst:IsA("SurfaceAppearance") and (c.material or c.color) then
            put(tag, inst, "Parent", nil)
        elseif c.plain and (inst:IsA("Decal") or inst:IsA("Texture")) then
            put(tag, inst, "Transparency", 1)
        elseif c.plain and inst:IsA("Shirt") then
            put(tag, inst, "ShirtTemplate", "")
        elseif c.plain and inst:IsA("Pants") then
            put(tag, inst, "PantsTemplate", "")
        end
    end

    function Lv.highlight(key, adornee, on, fill, fillT, outline, outlineT)
        local light = Lv[key]
        if not (on and adornee) then
            if light then pcall(function() light:Destroy() end) end
            Lv[key] = nil
            return
        end
        if not (light and light.Parent) then
            light = Gui.make("Highlight", { DepthMode = Enum.HighlightDepthMode.AlwaysOnTop })
            Lv[key] = light
            if not light then return end
        end
        if light.Adornee ~= adornee then light.Adornee = adornee end
        light.FillColor, light.FillTransparency, light.OutlineColor, light.OutlineTransparency = fill, fillT, outline, outlineT
    end

    local function material(name)
        if not name or name == "Default" then return nil end
        local ok, value = pcall(function() return Enum.Material[name] end)
        return ok and value or nil
    end

    function Lv.step(dt, now)
        local character, tool = Game.localCharacter(), Game.weapon()
        Lv.highlight("gunLight", tool, F("viewmodel_chams"), col("viewmodel_chams_color", Color3.fromRGB(120, 80, 255)), 1 - opacity("viewmodel_chams_color", 0.5),
            col("viewmodel_chams_color2"), 1 - opacity("viewmodel_chams_color2"))
        Lv.highlight("selfLight", character, F("Self_Chams"), col("Self_ChamsColor1", Color3.fromRGB(80, 160, 255)), 1 - opacity("Self_ChamsColor1", 0.7),
            col("Self_ChamsColor2"), 1 - opacity("Self_ChamsColor2"))
        if now < Lv.at then return end
        Lv.at = now + 0.25
        if Lv.tool ~= tool then
            Util.restore("lv_gun")
            Lv.tool = tool
        end
        if Lv.character ~= character then
            Util.restore("lv_body")
            Util.restore("lv_acc")
            Lv.character = character
        end
        local gunMat = material(F("viewmodel_material_value"))
        local gunAlpha = 1 - opacity("viewmodel_body_color_value")
        if tool and (F("viewmodel_body_color") or gunMat or gunAlpha > 0 or F("viewmodel_disable_textures")) then
            local c = { material = gunMat, plain = F("viewmodel_disable_textures"), transparency = gunAlpha > 0 and gunAlpha or nil }
            if F("viewmodel_body_color") then c.color = col("viewmodel_body_color_value", Color3.fromRGB(202, 161, 13)) end
            if gunMat == Enum.Material.ForceField then c.texture = texture(F("viewmodel_texture_value")) end
            for _, inst in ipairs(tool:GetDescendants()) do Lv.style("lv_gun", inst, c) end
        else
            Util.restore("lv_gun")
        end
        if not character then return end
        if F("arm_material") or F("arm_disable_textures") then
            local c = { plain = true }
            if F("arm_material") then
                c.material, c.color = Enum.Material.ForceField, col("arm_material_color")
                c.transparency, c.texture = 1 - opacity("arm_material_color"), texture(F("arm_material_texture"))
            end
            for _, inst in ipairs(character:GetDescendants()) do
                if not (inst:FindFirstAncestorOfClass("Tool") or inst:FindFirstAncestorOfClass("Accessory")) then Lv.style("lv_body", inst, c) end
            end
        else
            Util.restore("lv_body")
        end
        if F("arm_remove_accessories") then
            for _, acc in ipairs(character:GetChildren()) do
                if acc:IsA("Accessory") then
                    for _, inst in ipairs(acc:GetDescendants()) do
                        if inst:IsA("BasePart") or inst:IsA("Decal") then put("lv_acc", inst, "Transparency", 1) end
                    end
                end
            end
        else
            Util.restore("lv_acc")
        end
    end

    function Lv.sync()
        local any = false
        for _, flag in ipairs(Lv.flags) do
            local value = F(flag)
            if value == true or (type(value) == "string" and value ~= "Default") then any = true end
        end
        if any then
            Lv.at = 0
            Loop.register("local_visuals", Lv.step, 110)
        elseif Loop.has("local_visuals") then
            Loop.unregister("local_visuals")
            Lv.off()
        end
    end

    function Lv.off()
        Util.restore("lv_gun")
        Util.restore("lv_body")
        Util.restore("lv_acc")
        Lv.highlight("gunLight")
        Lv.highlight("selfLight")
        Lv.tool, Lv.character = nil, nil
    end
    Util.changed(Lv.flags, Lv.sync)
    Util.onUnload(Lv.off)

    -- menu: visuals > esp (enemies / team / local) and the crosshair + camera cards on indicators
    local row = Util.row
    local function px(v) return v .. " px" end
    local enemies, team, mine = Pages.visuals["esp.enemies"], Pages.visuals["esp.team"], Pages.visuals["esp.local"]

    local card = enemies:Card({ name = "esp", id = "esp", side = "left" })
    row(card, "Enabled", "esp_enabled", { hud = "ESP" })
    local _, g = row(card, "Boxes", "esp_box", { sw = { { "esp_box_color", "#ffffff" } }, gear = "box" })
    g:Dropdown({ name = "Type", flag = "esp_box_type", options = { "Normal", "Corner", "Circle" }, default = "Corner" })
    g:Slider({ name = "Thickness", flag = "esp_box_thickness", min = 1, max = 5, step = 0.1, default = 1, fmt = px })
    row(g, "Outline", "esp_outline_enabled", { sw = { { "esp_outline_color", "#000000" } } })
    row(g, "Fill", "esp_fill", { sw = { { "esp_fill_color", "#ffffff1a" } } })
    _, g = row(card, "Name", "esp_name", { sw = { { "esp_name_color1", "#ffffff" } }, gear = "name" })
    g:Dropdown({ name = "Name type", flag = "esp_name_type", options = { "Username", "Display name", "Display (@username)" }, default = "Username" })
    g:Slider({ name = "Text size (all text)", flag = "esp_text_size", min = 8, max = 24, default = 12, fmt = px })
    _, g = row(card, "Health bar", "esp_healthbar", { sw = { { "esp_healthbar_color_end", "#ff0000" }, { "esp_healthbar_color_middle", "#ffff00" }, { "esp_healthbar_color_start", "#00ff00" } }, gear = "health" })
    g:Dropdown({ name = "Position", flag = "esp_health_position", options = { "Left", "Right", "Top", "Bottom" }, default = "Left" })
    g:Slider({ name = "Width", flag = "esp_health_width", min = 1, max = 6, default = 1, fmt = px })
    row(card, "Distance", "esp_distance", { sw = { { "esp_distance_color", "#ffffff" } } })
    row(card, "Weapon", "esp_weapon", { sw = { { "esp_weapon_color", "#ffffff" } } })
    _, g = row(card, "Skeleton", "esp_skeleton", { sw = { { "esp_skeleton_color", "#ffffff" } }, gear = "skeleton" })
    g:Slider({ name = "Thickness", flag = "esp_skeleton_thickness", min = 1, max = 4, step = 0.1, default = 1.5, fmt = px })
    _, g = row(card, "Arrows", "esp_arrows", { sw = { { "esp_arrow_color", "#ffffff" } }, gear = "arrows" })
    g:Slider({ name = "Size", flag = "esp_arrow_size", min = 8, max = 32, default = 14, fmt = px })
    g:Slider({ name = "Orbit radius", flag = "esp_arrow_orbit", min = 50, max = 300, default = 100, fmt = px })
    row(card, "Glow", "esp_glow", { sw = { { "esp_glow_color", "#ffffff47" } } })
    row(card, "Status flags", "esp_flags", { sw = { { "esp_flags_color", "#ffc850" } }, tip = "Hostile, trespassing, tased, forcefield" })

    local chams = enemies:Card({ name = "chams", id = "chams", side = "right" })
    _, g = row(chams, "Chams", "esp_chams", { sw = { { "esp_chams_adorn_vis_color", "#3bcc5aa6" }, { "esp_chams_adorn_occ_color", "#3b90cc4d" } }, gear = "chams" })
    g:Slider({ name = "Visible thickness", flag = "esp_chams_adorn_thickness", min = 0, max = 0.6, step = 0.01, default = 0.1 })
    row(g, "Glow", "esp_chams_adorn_glow")
    g:Slider({ name = "Glow strength", flag = "esp_chams_adorn_glow_size", min = 1, max = 2.5, step = 0.01, default = 1.75, depends = "esp_chams_adorn_glow" })
    row(g, "Round head", "esp_chams_adorn_round_head", { def = true })
    g:Slider({ name = "Head size", flag = "esp_chams_adorn_head_size", min = 0.8, max = 1.6, step = 0.01, default = 1.15, depends = "esp_chams_adorn_round_head" })

    local side = enemies:Card({ name = "preview", id = "esppreview", side = "right" })
    local view = side:Preview({ kind = "esp" })
    local function previewEsp()
        local hpSide = string.lower(tostring(F("esp_health_position") or "Left"))
        return {
            box = F("esp_box") and (F("esp_box_type") == "Normal" and "full" or "corner") or false,
            boxColor = col("esp_box_color"), outline = F("esp_outline_enabled"), boxThickness = num("esp_box_thickness", 1),
            fill = F("esp_fill"), fillColor = col("esp_fill_color"), fillAlpha = opacity("esp_fill_color", 0.1),
            health = F("esp_healthbar"), hp = Esp.previewHp, maxHp = 100, healthMode = "gradient", healthSide = hpSide == "right" and "right" or "left",
            low = col("esp_healthbar_color_end"), mid = col("esp_healthbar_color_middle"), high = col("esp_healthbar_color_start"), barWidth = num("esp_health_width", 1),
            name = F("esp_name") and (F("esp_name_type") == "Username" and "user" or "display") or false, nameColor = col("esp_name_color1"),
            display = "Dummy", user = "dummy", nameSize = num("esp_text_size", 12),
            skeleton = F("esp_skeleton"), skeletonColor = col("esp_skeleton_color"), skeletonThickness = num("esp_skeleton_thickness", 1.5),
            weapon = F("esp_weapon") and "Remington 870" or false, weaponColor = col("esp_weapon_color"),
            distance = F("esp_distance"), distanceColor = col("esp_distance_color"), distanceUnit = "meters",
            flags = F("esp_flags") and { "Hostile" } or {}, flagColor = col("esp_flags_color"),
        }
    end
    local function previewChams(wall)
        return {
            enabled = F("esp_chams"), walls = true, round = F("esp_chams_adorn_round_head") ~= false, grow = num("esp_chams_adorn_thickness", 0.1),
            visColor = col("esp_chams_adorn_vis_color"), visAlpha = opacity("esp_chams_adorn_vis_color", 0.65),
            occColor = col("esp_chams_adorn_occ_color"), occAlpha = opacity("esp_chams_adorn_occ_color", 0.3), wall = wall,
        }
    end
    local Scene = Aster.Scene
    if Scene and view then
        local preview = {}
        Esp.preview = preview
        local ok = Util.guard("esp preview", function()
            preview.dummy = Scene.Dummy(view, { motion = "none" })
            preview.wall = Scene.Wall(view, { cframe = CFrame.new(0, 2.5, 3), sweep = { from = -6.5, to = 6.5, move = 1.6, hold = 0.7 } })
            preview.chams = Scene.Chams(view, preview.dummy.Model, previewChams(preview.wall))
            preview.esp = Scene.Esp(view, preview.dummy.Model, previewEsp())
            if view.Fit then view:Fit() end
        end)
        if ok then
            Util.changed({ "esp_*" }, function()
                if preview.esp then preview.esp:Set(previewEsp()) end
                if preview.chams then preview.chams:Set(previewChams(preview.wall)) end
            end)
        end
        view.SetButtons({
            { "Damage", function()
                Esp.previewHp = math.max(5, Esp.previewHp - 25)
                if preview.esp then preview.esp:Set({ hp = Esp.previewHp }) end
            end },
            { "Heal", function()
                Esp.previewHp = 100
                if preview.esp then preview.esp:Set({ hp = Esp.previewHp }) end
            end },
        })
    end

    local filters = team:Card({ name = "filters", id = "filters", side = "left" })
    row(filters, "Players", "esp_players", { def = true })
    row(filters, "Local player", "esp_local_player")
    row(filters, "Enemies only", "esp_enemies_only")
    row(filters, "Hostile only (inmates)", "esp_hostile_only")
    local teamCard = team:Card({ name = "team", id = "team", side = "right" })
    row(teamCard, "Team colors", "esp_use_team_color")
    row(teamCard, "Team indicator", "esp_team_indicator", { sw = { { "esp_team_color", "#ffffff" } } })
    row(teamCard, "Highlight friendly", "rel_hl_friendly", { sw = { { "rel_hl_friendly_color", "#50ff78" } }, tip = "Friends from the players list are always shown in this colour" })
    row(teamCard, "Highlight priority", "rel_hl_priority", { sw = { { "rel_hl_priority_color", "#ff4646" } }, tip = "Targets from the players list are always shown in this colour" })

    local gun = mine:Card({ name = "gun", id = "gun", side = "left" })
    row(gun, "Gun color", "viewmodel_body_color", { sw = { { "viewmodel_body_color_value", "#caa10d" } } })
    gun:Dropdown({ name = "Material", flag = "viewmodel_material_value", options = { "Default", "ForceField", "Neon", "Glass", "SmoothPlastic", "Plastic" }, default = "Default" })
    gun:Dropdown({ name = "Forcefield texture", flag = "viewmodel_texture_value", options = Lv.textureNames, default = "Disabled", depends = { "viewmodel_material_value", "ForceField" } })
    row(gun, "Disable textures", "viewmodel_disable_textures")
    row(gun, "Gun chams", "viewmodel_chams", { sw = { { "viewmodel_chams_color", "#7850ff80" }, { "viewmodel_chams_color2", "#ffffff" } } })
    local body = mine:Card({ name = "body", id = "body", side = "right" })
    row(body, "Forcefield material", "arm_material", { sw = { { "arm_material_color", "#ffffff" } } })
    body:Dropdown({ name = "Forcefield texture", flag = "arm_material_texture", options = Lv.textureNames, default = "Disabled", depends = "arm_material" })
    row(body, "Disable textures", "arm_disable_textures")
    row(body, "Remove accessories", "arm_remove_accessories")
    row(body, "Self chams", "Self_Chams", { sw = { { "Self_ChamsColor1", "#50a0ffb3" }, { "Self_ChamsColor2", "#ffffff" } } })

    local ind = Pages.visuals.indicators
    local cross = ind:Card({ name = "crosshair", id = "crosshair", side = "right" })
    _, g = row(cross, "Crosshair", "crosshair_enabled", { sw = { { "crosshair_color", "#ffffff" } }, gear = "crosshair" })
    g:Slider({ name = "Length", flag = "crosshair_length", min = 1, max = 40, default = 12, fmt = px })
    g:Slider({ name = "Thickness", flag = "crosshair_thickness", min = 1, max = 8, default = 2, fmt = px })
    g:Slider({ name = "Gap", flag = "crosshair_gap", min = 0, max = 30, default = 6, fmt = px })
    row(g, "Outline", "crosshair_outline", { sw = { { "crosshair_outline_color", "#000000" } } })
    row(g, "Rotation", "crosshair_rotation")
    g:Slider({ name = "Angle", flag = "crosshair_rotation_angle", min = 0, max = 360, default = 0 })
    g:Slider({ name = "Spin speed", flag = "crosshair_rotation_speed", min = -360, max = 360, default = 90, depends = "crosshair_rotation" })
    row(cross, "Hide default cursor", "crosshair_hide_cursor", { dep = "crosshair_enabled" })
    local camCard = ind:Card({ name = "camera", id = "camera", side = "right" })
    _, g = row(camCard, "FOV changer", "camera_fov_changer", { gear = "fov" })
    g:Slider({ name = "FOV", flag = "camera_fov_changer_amount", min = 40, max = 140, default = 100, fmt = function(v) return v .. "\194\176" end })
end
bootMark("esp", PL2BootT, 5, 13)

PL2BootT = PL2BootClock()
-- [src] 30_world.lua
do
    World = { made = {}, angle = Vector3.new(0, 0, 0), clock = 0, hour = 12, skyToken = 0 }
    local WHITE = Color3.new(1, 1, 1)
    local FACES = { "SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp" }

    local function col(flag, default)
        local value = F(flag)
        if typeof(value) == "Color3" then return value end
        return default or WHITE
    end
    local function num(flag, default)
        local value = F(flag)
        return type(value) == "number" and value or default
    end
    local function put(tag, object, prop, value)
        if not object then return end
        local ok, current = pcall(function() return object[prop] end)
        if ok and current ~= value then Util.hold(tag, object, prop, value) end
    end
    local function has(list, value)
        if type(list) ~= "table" then return false end
        for key, item in pairs(list) do
            if item == value or (key == value and item == true) then return true end
        end
        return false
    end

    -- instances we create ourselves; the game's own objects are only ever touched through Util.hold
    function World.make(key, class, parent, props)
        local inst = World.made[key]
        if inst and inst.Parent then return inst end
        local ok, made = pcall(Instance.new, class)
        if not (ok and made) then return nil end
        made.Name = "Aster" .. class
        for prop, value in pairs(props or {}) do pcall(function() made[prop] = value end) end
        made.Parent = parent
        World.made[key] = made
        return made
    end

    function World.drop(key)
        local inst = World.made[key]
        if inst then pcall(function() inst:Destroy() end) end
        World.made[key] = nil
    end

    Util.onUnload(function()
        for key in pairs(World.made) do World.drop(key) end
    end)

    -- lighting and post: applied on flag change, re-asserted once a second while a lighting override is on
    local LIGHT = {
        { "lighting_toggle_Ambient", "Ambient", "lighting_colorAmbient" },
        { "lighting_toggle_Ambient", "OutdoorAmbient", "lighting_colorOutdoorAmbient" },
        { "lighting_toggle_Brightness", "Brightness", "lighting_number_Brightness" },
        { "lighting_toggle_ExposureCompensation", "ExposureCompensation", "lighting_number_ExposureCompensation" },
        { "lighting_toggle_FogStart", "FogStart", "lighting_number_FogStart" },
        { "lighting_toggle_FogEnd", "FogEnd", "lighting_number_FogEnd" },
        { "lighting_toggle_FogColor", "FogColor", "lighting_colorFogColor" },
    }

    function World.lighting()
        local any = false
        for _, entry in ipairs(LIGHT) do
            local value = F(entry[3])
            if F(entry[1]) and value ~= nil then
                any = true
                put("light_" .. entry[2], Lighting, entry[2], value)
            else
                Util.restore("light_" .. entry[2])
            end
        end
        return any
    end

    function World.post()
        if F("bloom_enabled") then
            local bloom = World.make("bloom", "BloomEffect", Lighting)
            if bloom then bloom.Intensity, bloom.Size, bloom.Threshold = num("bloom_intensity", 0.4), num("bloom_size", 24), num("bloom_threshold", 0.95) end
        else
            World.drop("bloom")
        end
        if F("color_correction_enabled") then
            local cc = World.make("cc", "ColorCorrectionEffect", Lighting)
            if cc then
                cc.TintColor, cc.Saturation = col("color_correction_tint"), num("color_correction_saturation", 0)
                cc.Contrast, cc.Brightness = num("color_correction_contrast", 0), num("color_correction_brightness", 0)
            end
        else
            World.drop("cc")
        end
        if F("sunrays_enabled") then
            local rays = World.make("rays", "SunRaysEffect", Lighting)
            if rays then rays.Intensity = math.clamp(num("sunrays_intensity", 1), 0, 1) end
        else
            World.drop("rays")
        end
        if F("atmosphere_enabled") then
            for _, child in ipairs(Lighting:GetChildren()) do
                if child:IsA("Atmosphere") and child ~= World.made.atmos then Util.hold("atmos", child, "Parent", nil) end
            end
            local atmos = World.make("atmos", "Atmosphere", Lighting)
            if atmos then
                atmos.Color, atmos.Decay = col("atmosphere_color"), col("atmosphere_decay")
                atmos.Density, atmos.Glare = num("atmosphere_density", 0.3), num("atmosphere_glare", 4.1)
                atmos.Haze, atmos.Offset = num("atmosphere_haze", 1), num("atmosphere_offset", 0.4)
            end
        else
            World.drop("atmos")
            Util.restore("atmos")
        end
        local blur = num("camera_blur", 0)
        if blur > 0 and Game.camera() then
            local effect = World.make("blur", "BlurEffect", Game.camera())
            if effect then effect.Size = blur end
        else
            World.drop("blur")
        end
    end

    function World.relight(dt, now)
        if now < (World.lightAt or 0) then return end
        World.lightAt = now + 1
        World.lighting()
    end

    function World.applyLight()
        if World.lighting() then
            Loop.register("world_light", World.relight, 50, "heartbeat")
        elseif Loop.has("world_light") then
            Loop.unregister("world_light")
        end
        World.post()
    end
    Util.changed({ "lighting_*", "bloom_*", "color_correction_*", "sunrays_*", "atmosphere_*", "camera_blur" }, World.applyLight)

    -- skybox: presets come from the lazily fetched data file; custom ids accept 1 asset (a Sky model or image) or 6 images
    local assetCache = {}
    local function assetUrl(id)
        id = tostring(id)
        if string.find(id, "://", 1, true) then return id end
        return "rbxassetid://" .. id
    end

    local function resolveAsset(id)
        if assetCache[id] then return assetCache[id] end
        local result
        local ok, objects = pcall(function() return game:GetObjects("rbxassetid://" .. id) end)
        if ok and type(objects) == "table" then
            for _, object in ipairs(objects) do
                local sky = object:IsA("Sky") and object or object:FindFirstChildWhichIsA("Sky", true)
                if sky then
                    result = { sky = sky }
                    break
                end
                if object:IsA("Decal") or object:IsA("Texture") then
                    result = { image = object.Texture }
                    break
                end
            end
        end
        result = result or { image = "rbxassetid://" .. id }
        assetCache[id] = result
        return result
    end

    function World.customFaces(text)
        local ids = {}
        for id in string.gmatch(tostring(text or ""), "%d+") do ids[#ids + 1] = id end
        if #ids == 1 then
            local asset, faces = resolveAsset(ids[1]), {}
            for _, face in ipairs(FACES) do faces[face] = asset.sky and asset.sky[face] or asset.image end
            if asset.sky then
                faces.SunTextureId, faces.MoonTextureId = asset.sky.SunTextureId, asset.sky.MoonTextureId
                faces.StarCount = asset.sky.StarCount
            end
            return faces
        elseif #ids == 6 then
            local faces = {}
            local order = { "SkyboxUp", "SkyboxDn", "SkyboxFt", "SkyboxBk", "SkyboxLf", "SkyboxRt" }
            for index, face in ipairs(order) do faces[face] = assetUrl(ids[index]) end
            return faces
        end
        return nil, #ids
    end

    -- data rows: {name, bk, dn, ft, lf, rt, up, stars, sun size, moon size, sun tex, moon tex}, 0 = keep the default
    function World.presetFaces(name)
        local entry = Data.sky(name)
        if not entry then return nil end
        local ids = type(entry[2]) == "table" and entry[2] or { entry[2], entry[3], entry[4], entry[5], entry[6], entry[7] }
        local faces = {}
        for index, face in ipairs(FACES) do
            if not ids[index] then return nil end
            faces[face] = assetUrl(ids[index])
        end
        local function extra(index) local value = entry[index] return (value and value ~= 0) and value or nil end
        faces.StarCount, faces.SunSize, faces.MoonSize = extra(8), extra(9), extra(10)
        faces.SunTextureId = extra(11) and assetUrl(extra(11)) or nil
        faces.MoonTextureId = extra(12) and assetUrl(extra(12)) or nil
        return faces
    end

    function World.skyNames()
        local names = { "Default", "Custom" }
        local ok, list = pcall(Data.skyNames)
        for _, name in ipairs(ok and type(list) == "table" and list or {}) do
            if name ~= "Default" and name ~= "Custom" then names[#names + 1] = name end
        end
        return names
    end

    function World.dropSky()
        World.drop("sky")
        Util.restore("skybox")
    end

    function World.setSky(faces)
        for _, child in ipairs(Lighting:GetChildren()) do
            if child:IsA("Sky") and child ~= World.made.sky then Util.hold("skybox", child, "Parent", nil) end
        end
        local sky = World.make("sky", "Sky", Lighting)
        if not sky then return end
        for _, face in ipairs(FACES) do
            if faces[face] then sky[face] = faces[face] end
        end
        local hide = F("skybox_disable") or {}
        sky.StarCount = has(hide, "stars") and 0 or (faces.StarCount or 3000)
        sky.SunAngularSize = has(hide, "sun") and 0 or (faces.SunSize or 21)
        sky.MoonAngularSize = has(hide, "moon") and 0 or (faces.MoonSize or 11)
        sky.SunTextureId = has(hide, "sun") and "" or (faces.SunTextureId or sky.SunTextureId)
        sky.MoonTextureId = has(hide, "moon") and "" or (faces.MoonTextureId or sky.MoonTextureId)
        World.skyObjects()
    end

    -- resolving may hit the network (data file, GetObjects), so it runs in its own thread; a newer request wins
    function World.skybox(delay)
        World.skyToken = World.skyToken + 1
        local token = World.skyToken
        local name = F("skybox_value") or "Default"
        if not F("skybox_enabled") or name == "Default" then
            World.dropSky()
            World.skyObjects()
            return
        end
        local function run()
            if token ~= World.skyToken or Util.unloaded then return end
            local faces, count
            if name == "Custom" then faces, count = World.customFaces(F("skybox_custom_ids")) else faces = World.presetFaces(name) end
            if token ~= World.skyToken or Util.unloaded then return end
            if faces then
                World.setSky(faces)
            else
                World.dropSky()
                if name == "Custom" and count and count > 0 then Util.notify("Custom skybox needs 1 or 6 ids, got " .. count, "warn") end
                if name ~= "Custom" then Util.notify("Skybox " .. name .. " could not be loaded", "warn") end
            end
        end
        if delay then task.delay(delay, run) else task.spawn(run) end
    end
    Util.changed({ "skybox_enabled", "skybox_value", "skybox_disable" }, function() World.skybox() end)
    Util.changed("skybox_custom_ids", function() World.skybox(0.8) end)

    -- sky motion (X8: spin, time of day and sky objects only; the sun_* pattern and fake sun were cut)
    function World.skyTarget()
        local sky = World.made.sky
        if sky and sky.Parent then return sky end
        return Lighting:FindFirstChildOfClass("Sky")
    end

    function World.skyObjects()
        local sky = World.skyTarget()
        if F("sky_objects") and sky then
            put("skyobj", sky, "StarCount", num("sky_stars", 3000))
            put("skyobj", sky, "SunAngularSize", num("sky_sun_size", 21))
            put("skyobj", sky, "MoonAngularSize", num("sky_moon_size", 11))
            put("skyobj", sky, "CelestialBodiesShown", F("sky_bodies") ~= false)
        else
            Util.restore("skyobj")
        end
    end

    local function hourDiff(a, b)
        local d = math.abs(a - b) % 24
        return math.min(d, 24 - d)
    end

    function World.motion(dt)
        local sky = World.skyTarget()
        if F("sky_spin") and sky then
            local x, y, z = num("sky_spin_x", 0), num("sky_spin_y", 6), num("sky_spin_z", 0)
            local value
            if F("sky_spin_mode") == "Sway" then
                World.clock = World.clock + dt
                local phase = math.sin(World.clock * 0.15 * math.pi * 2) * 25
                value = Vector3.new(x ~= 0 and phase or 0, y ~= 0 and phase or 0, z ~= 0 and phase or 0)
            else
                World.angle = World.angle + Vector3.new(x, y, z) * dt
                value = Vector3.new(World.angle.X % 360, World.angle.Y % 360, World.angle.Z % 360)
            end
            put("skyspin", sky, "SkyboxOrientation", value)
        end
        local mode = F("sky_time_mode") or "Off"
        if mode == "Cycle" then
            World.hour = (World.hour + num("sky_cycle_speed", 0.25) * dt) % 24
        elseif mode == "Locked" then
            World.hour = num("sky_time_locked", 14) % 24
        end
        if mode ~= "Off" and hourDiff(Lighting.ClockTime, World.hour) > 0.005 then Util.hold("skytime", Lighting, "ClockTime", World.hour) end
    end

    function World.skySync(flag)
        local mode = F("sky_time_mode") or "Off"
        if flag == "sky_time_mode" then
            if mode == "Off" then Util.restore("skytime") end
            if mode == "Cycle" then World.hour = Lighting.ClockTime end
        end
        if not F("sky_spin") then Util.restore("skyspin") end
        World.skyObjects()
        World.clouds()
        if F("sky_spin") or mode ~= "Off" then
            Loop.register("sky_motion", World.motion, 60)
        elseif Loop.has("sky_motion") then
            Loop.unregister("sky_motion")
        end
    end
    Util.changed({ "sky_*" }, World.skySync)

    function World.clouds()
        local terrain = Workspace:FindFirstChildOfClass("Terrain")
        if F("sky_clouds") and terrain then
            local clouds = terrain:FindFirstChildOfClass("Clouds")
            if not clouds then clouds = World.make("clouds", "Clouds", terrain) end
            if clouds then
                put("clouds", clouds, "Enabled", true)
                put("clouds", clouds, "Cover", num("sky_cloud_cover", 0.6))
                put("clouds", clouds, "Density", num("sky_cloud_density", 0.6))
                put("clouds", clouds, "Color", col("sky_cloud_color"))
            end
        else
            World.drop("clouds")
            Util.restore("clouds")
        end
        if F("sky_wind") then
            local rad = math.rad(num("sky_wind_dir", 0))
            put("wind", Workspace, "GlobalWind", Vector3.new(math.sin(rad), 0, -math.cos(rad)) * num("sky_wind_speed", 60))
        else
            Util.restore("wind")
        end
    end

    -- weather: a camera-following emitter plate plus rain lightning, as in dev.lua
    local WEATHER = {
        Snow = {
            { tex = "rbxasset://textures/particles/smoke_main.dds", alpha = 0.15, life = { 6, 9 }, rate = 220, speed = { 6, 10 }, size = { 0.35, 0.25 }, spread = 0.4, fall = -1, spin = true },
            { tex = "rbxasset://textures/particles/sparkles_main.dds", alpha = 0.35, life = { 6, 9 }, rate = 60, speed = { 5, 8 }, size = { 0.2, 0.15 }, spread = 0.6, fall = -0.5, spin = true },
        },
        Rain = {
            { tex = "rbxasset://textures/particles/smoke_main.dds", alpha = 0.35, life = { 1.2, 1.8 }, rate = 600, speed = { 70, 90 }, size = { 0.12, 0.1 }, spread = 0.05, fall = -40, streak = true },
        },
        Blizzard = {
            { tex = "rbxasset://textures/particles/smoke_main.dds", alpha = 0.1, life = { 3, 5 }, rate = 700, speed = { 18, 28 }, size = { 0.3, 0.2 }, spread = 0.8, fall = -6, spin = true },
            { tex = "rbxasset://textures/particles/smoke_main.dds", alpha = 0.75, life = { 3, 5 }, rate = 120, speed = { 14, 22 }, size = { 3, 5 }, spread = 1, fall = -2, spin = true },
        },
    }
    local BOLT_HOLD, BOLT_FADE = 0.12, 0.35
    local Weather = { emitters = {}, bolts = {}, strikeAt = 0 }
    World.weather = Weather

    function Weather.build(preset)
        Weather.destroy()
        local specs = WEATHER[preset]
        if not specs then return end
        local plate = World.make("weather", "Part", Workspace, { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1, Size = Vector3.new(140, 1, 140) })
        if not plate then return end
        for _, spec in ipairs(specs) do
            local emitter = Instance.new("ParticleEmitter")
            emitter.Texture = spec.tex
            emitter.Lifetime = NumberRange.new(spec.life[1], spec.life[2])
            if spec.spin then
                emitter.Rotation, emitter.RotSpeed = NumberRange.new(0, 360), NumberRange.new(-40, 40)
            end
            emitter.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, spec.alpha),
                NumberSequenceKeypoint.new(0.85, spec.alpha), NumberSequenceKeypoint.new(1, 1),
            })
            emitter.LockedToPart, emitter.EmissionDirection = false, Enum.NormalId.Bottom
            if spec.streak then emitter.Orientation = Enum.ParticleOrientation.VelocityParallel end
            emitter.Parent = plate
            Weather.emitters[#Weather.emitters + 1] = { emitter = emitter, spec = spec }
        end
        Weather.preset, Weather.sig = preset, nil
    end

    function Weather.destroy()
        World.drop("weather")
        Weather.emitters, Weather.preset, Weather.sig = {}, nil, nil
    end

    function Weather.look()
        local intensity, speed, size = num("weather_intensity", 1), num("weather_speed", 1), num("weather_size", 1)
        local glow, spread, color = num("weather_glow", 0), num("weather_spread", 1), col("weather_color", Color3.fromRGB(200, 200, 220))
        local strength, angle = num("weather_wind_strength", 2), math.rad(num("weather_wind_angle", 45))
        local sig = table.concat({ intensity, speed, size, glow, spread, tostring(color), strength, angle }, "|")
        if sig == Weather.sig then return end
        Weather.sig = sig
        for _, entry in ipairs(Weather.emitters) do
            local emitter, spec = entry.emitter, entry.spec
            emitter.Rate = spec.rate * intensity
            emitter.Speed = NumberRange.new(spec.speed[1] * speed, spec.speed[2] * speed)
            emitter.Size = NumberSequence.new(spec.size[1] * size, spec.size[2] * size)
            emitter.LightEmission, emitter.Color = glow, ColorSequence.new(color)
            emitter.SpreadAngle = Vector2.new(spec.spread * spread, spec.spread * spread)
            emitter.Acceleration = Vector3.new(math.sin(angle) * strength, spec.fall, math.cos(angle) * strength)
        end
    end

    function Weather.bolt(from, to)
        local color = col("weather_lightning_color", Color3.fromRGB(200, 220, 255))
        local thick, jagged, flash = num("weather_lightning_thickness", 0.2), num("weather_lightning_jagged", 6), num("weather_lightning_flash", 4)
        local folder = Instance.new("Folder")
        folder.Name = "AsterBolt"
        folder.Parent = Workspace
        local points = { from }
        for index = 1, 7 do
            local base = from:Lerp(to, index / 8)
            points[#points + 1] = base + Vector3.new((math.random() - 0.5) * jagged, (math.random() - 0.5) * jagged * 0.5, (math.random() - 0.5) * jagged)
        end
        points[#points + 1] = to
        local anchor = Instance.new("Part")
        anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch, anchor.Transparency = true, false, false, false, 1
        anchor.Size, anchor.Position = Vector3.new(1, 1, 1), to
        anchor.Parent = folder
        local attachments = {}
        for _, point in ipairs(points) do
            local attachment = Instance.new("Attachment")
            attachment.Parent = anchor
            attachment.WorldPosition = point
            attachments[#attachments + 1] = attachment
        end
        for index = 1, #attachments - 1 do
            local beam = Instance.new("Beam")
            beam.Attachment0, beam.Attachment1 = attachments[index], attachments[index + 1]
            beam.Color, beam.Width0, beam.Width1 = ColorSequence.new(color), thick, thick * 0.7
            beam.FaceCamera, beam.LightEmission, beam.LightInfluence = true, 1, 0
            beam.Transparency = NumberSequence.new(0)
            beam.Parent = folder
        end
        local light = Instance.new("PointLight")
        light.Color, light.Brightness, light.Range = color:Lerp(WHITE, 0.3), flash, 40
        light.Parent = anchor
        Weather.bolts[#Weather.bolts + 1] = { folder = folder, light = light, flash = flash, born = os.clock() }
    end

    function Weather.strike(cam)
        local position, height = cam.CFrame.Position, num("weather_height", 40)
        local angle, radius = math.random() * math.pi * 2, 20 + math.random() * 40
        local x, z = position.X + math.cos(angle) * radius, position.Z + math.sin(angle) * radius
        local params = Game.newParams({ Game.localCharacter() })
        local ground = position.Y - 40
        local hit = Workspace:Raycast(Vector3.new(x, position.Y + height, z), Vector3.new(0, -1000, 0), params)
        if hit then ground = hit.Position.Y end
        Weather.bolt(Vector3.new(x + (math.random() - 0.5) * 30, ground + height, z + (math.random() - 0.5) * 30), Vector3.new(x, ground, z))
    end

    function Weather.fade(now)
        for index = #Weather.bolts, 1, -1 do
            local bolt = Weather.bolts[index]
            local age = now - bolt.born
            if age >= BOLT_HOLD + BOLT_FADE + 0.2 then
                pcall(function() bolt.folder:Destroy() end)
                table.remove(Weather.bolts, index)
            elseif age > BOLT_HOLD then
                bolt.light.Brightness = bolt.flash * math.max(0, 1 - (age - BOLT_HOLD) / BOLT_FADE)
            end
        end
    end

    function Weather.step(dt, now)
        Weather.fade(now)
        local preset = F("weather_preset") or "Rain"
        if Weather.preset ~= preset or not (World.made.weather and World.made.weather.Parent) then Weather.build(preset) end
        Weather.look()
        local cam = Game.camera()
        if not cam then return end
        local plate = World.made.weather
        if plate then plate.Position = cam.CFrame.Position + Vector3.new(0, num("weather_height", 40), 0) end
        if preset == "Rain" and F("weather_lightning") and now >= Weather.strikeAt then
            Weather.strikeAt = now + num("weather_lightning_interval", 4) * (0.6 + math.random() * 0.8)
            Weather.strike(cam)
        end
    end

    function Weather.off()
        Weather.destroy()
        for _, bolt in ipairs(Weather.bolts) do pcall(function() bolt.folder:Destroy() end) end
        Weather.bolts = {}
    end

    Util.feature("weather_enabled", function()
        Loop.register("weather", Weather.step, 70)
    end, function()
        Loop.unregister("weather")
        Weather.off()
    end)
    Util.onUnload(Weather.off)

    -- map lights and xray walk the whole workspace; the walk is spread over frames, 1500 instances each
    local function inCharacter(inst)
        local model = inst:FindFirstAncestorOfClass("Model")
        while model do
            if model:FindFirstChildOfClass("Humanoid") then return true end
            model = model:FindFirstAncestorOfClass("Model")
        end
        return false
    end

    local function scanner(name, consider, apply, interval)
        local S = { name = name, known = {}, list = {}, at = 0 }
        function S.step(dt, now)
            local queue = S.queue
            if queue then
                local last = math.min(#queue, S.index + 1499)
                for index = S.index, last do
                    local inst = queue[index]
                    if not S.known[inst] then
                        local ok, record = Util.guard(name, consider, inst)
                        if ok and record then
                            S.known[inst] = record
                            S.list[#S.list + 1] = inst
                        end
                    end
                end
                S.index = last + 1
                if S.index > #queue then S.queue = nil end
            end
            if now < S.at then return end
            S.at = now + interval
            apply(S)
        end
        function S.start()
            S.queue, S.index = Workspace:GetDescendants(), 1
            S.conn = Util.track(Workspace.DescendantAdded:Connect(function(inst)
                if S.queue then
                    S.queue[#S.queue + 1] = inst
                else
                    S.queue, S.index = { inst }, 1
                end
            end))
            Loop.register(name, S.step, 90, "heartbeat")
        end
        function S.stop()
            Loop.unregister(name)
            if S.conn then pcall(function() S.conn:Disconnect() end) end
            S.conn, S.queue, S.known, S.list = nil, nil, {}, {}
            Util.restore(name)
        end
        return S
    end

    local Lights = scanner("maplights", function(inst)
        if not inst:IsA("Light") or inst:FindFirstAncestorOfClass("Tool") or inCharacter(inst) then return nil end
        local cam = Game.camera()
        if cam and inst:IsDescendantOf(cam) then return nil end
        local record = { Color = inst.Color, Brightness = inst.Brightness, Shadows = inst.Shadows }
        pcall(function() record.Range = inst.Range end)
        return record
    end, function(S)
        local recolor, color = F("maplights_recolor"), col("maplights_color", Color3.fromRGB(255, 214, 150))
        local force, brightness, range, shadows = F("maplights_force"), num("maplights_brightness", 1), num("maplights_range", 1), F("maplights_shadows")
        local keep = 0
        for index = 1, #S.list do
            local inst = S.list[index]
            if inst.Parent then
                keep = keep + 1
                S.list[keep] = inst
                local record = S.known[inst]
                put("maplights", inst, "Color", recolor and color or record.Color)
                put("maplights", inst, "Brightness", record.Brightness * brightness)
                if record.Range then put("maplights", inst, "Range", record.Range * range) end
                put("maplights", inst, "Shadows", shadows or record.Shadows)
                if force then
                    put("maplights", inst, "Enabled", true)
                elseif Util.held(inst, "Enabled") then
                    Util.restore("maplights", inst, "Enabled")
                end
            end
        end
        for index = #S.list, keep + 1, -1 do S.list[index] = nil end
    end, 0.15)
    World.lights = Lights
    Util.feature("maplights_enabled", Lights.start, Lights.stop)
    Util.changed({ "maplights_*" }, function() Lights.at = 0 end)

    local function ignoreSet()
        local set = {}
        for name in string.gmatch(tostring(F("misc_xray_ignore") or ""), "[^,]+") do
            set[(string.gsub(string.gsub(name, "^%s+", ""), "%s+$", ""))] = true
        end
        return set
    end

    local Xray
    Xray = scanner("xray", function(inst)
        if not inst:IsA("BasePart") or inst:IsA("Terrain") or inCharacter(inst) then return nil end
        if (Xray.ignore or {})[inst.Name] then return nil end
        Util.hold("xray", inst, "LocalTransparencyModifier", num("misc_xray_alpha", 0.5))
        return true
    end, function(S)
        local alpha = num("misc_xray_alpha", 0.5)
        if alpha == S.alpha then return end
        S.alpha = alpha
        for _, inst in ipairs(S.list) do
            if inst.Parent then put("xray", inst, "LocalTransparencyModifier", alpha) end
        end
    end, 0.25)
    World.xray = Xray
    local xrayStart = Xray.start
    function Xray.start()
        Xray.ignore, Xray.alpha = ignoreSet(), nil
        xrayStart()
    end
    Util.feature("misc_xray", Xray.start, Xray.stop)
    Util.changed("misc_xray_alpha", function() Xray.at = 0 end)
    Util.changed("misc_xray_ignore", function()
        if Loop.has("xray") then
            Xray.stop()
            Xray.start()
        end
    end)

    -- atmosphere presets drive the regular world flags, so a preset is just a starting point the user can tweak
    local C = Color3.fromRGB
    local ATMO_ORDER = { "Night", "Sunset", "Foggy Morning", "Neon Night", "Winter", "Inferno", "Dreamy Pink", "Deep Space" }
    local ATMO = {
        ["Night"] = { sky = "Night", ambient = C(20, 24, 40), outer = C(30, 36, 60), clock = 0, atmos = { C(60, 70, 110), C(20, 25, 50), 0.35, 1.5, 0, 0.2 }, bloom = { 0.5, 24, 0.9 }, cc = { C(200, 210, 255), -0.1, 0.1, 0 } },
        ["Sunset"] = { sky = "Sunset", ambient = C(120, 80, 70), outer = C(190, 120, 90), clock = 17.8, atmos = { C(255, 170, 120), C(255, 120, 80), 0.3, 1.8, 2, 0.3 }, bloom = { 0.6, 30, 0.85 }, cc = { C(255, 225, 200), 0.2, 0.05, 0 }, rays = 0.35 },
        ["Foggy Morning"] = { sky = "Cloudy", ambient = C(150, 155, 165), outer = C(170, 175, 185), clock = 7, atmos = { C(200, 205, 215), C(180, 185, 195), 0.55, 4, 0, 0 }, bloom = { 0.2, 24, 1 }, cc = { C(235, 238, 245), -0.25, 0, 0 } },
        ["Neon Night"] = { sky = "Purple Night", ambient = C(60, 30, 90), outer = C(90, 40, 130), clock = 0, atmos = { C(140, 60, 200), C(60, 20, 120), 0.3, 2, 1, 0.25 }, bloom = { 1.2, 40, 0.7 }, cc = { C(255, 200, 255), 0.35, 0.15, 0 } },
        ["Winter"] = { sky = "Winter", ambient = C(150, 170, 200), outer = C(190, 210, 235), clock = 12, atmos = { C(210, 225, 245), C(170, 190, 220), 0.4, 2.5, 0, 0 }, bloom = { 0.4, 24, 0.95 }, cc = { C(225, 240, 255), -0.1, 0, 0 } },
        ["Inferno"] = { sky = "Hell", ambient = C(110, 30, 20), outer = C(160, 50, 30), clock = 18, atmos = { C(255, 90, 40), C(160, 30, 10), 0.4, 2.5, 3, 0.2 }, bloom = { 1, 36, 0.8 }, cc = { C(255, 190, 170), 0.3, 0.2, 0 } },
        ["Dreamy Pink"] = { sky = "Pink Clouds", ambient = C(200, 150, 170), outer = C(230, 180, 200), clock = 16.5, atmos = { C(255, 200, 220), C(240, 150, 190), 0.25, 1, 1.5, 0.3 }, bloom = { 0.7, 32, 0.85 }, cc = { C(255, 230, 240), 0.15, 0, 0 } },
        ["Deep Space"] = { sky = "Galaxy", ambient = C(30, 30, 50), outer = C(40, 40, 70), clock = 0, bloom = { 0.8, 30, 0.9 }, cc = { C(220, 225, 255), 0.1, 0.1, 0 } },
    }
    local Atmo = { snaps = {}, assets = {}, path = "AsterV2/games/" .. FOLDER .. "/atmosphere.json" }
    World.atmo = Atmo

    local function set(flag, value) Aster:Set(flag, value) end
    local function part(flag) return F(flag) ~= false end
    local function pack(c) return { c.R, c.G, c.B } end
    local function unpackColor(list) return Color3.new(list[1], list[2], list[3]) end

    function Atmo.apply(preset, keepLight)
        if part("atmo_part_sky") and (preset.skyIds or preset.sky) then
            if preset.skyIds then set("skybox_custom_ids", preset.skyIds) end
            set("skybox_value", preset.skyIds and "Custom" or preset.sky)
            set("skybox_enabled", true)
        end
        if part("atmo_part_light") and not keepLight then
            set("lighting_toggle_Ambient", true)
            set("lighting_colorAmbient", preset.ambient)
            set("lighting_colorOutdoorAmbient", preset.outer)
            if preset.clock then
                set("sky_time_mode", "Locked")
                set("sky_time_locked", preset.clock)
            end
        end
        if part("atmo_part_atmos") then
            local a = preset.atmos
            set("atmosphere_enabled", a ~= nil)
            if a then
                set("atmosphere_color", a[1])
                set("atmosphere_decay", a[2])
                set("atmosphere_density", a[3])
                set("atmosphere_haze", a[4])
                set("atmosphere_glare", a[5])
                set("atmosphere_offset", a[6])
            end
        end
        if part("atmo_part_post") then
            local bloom, cc = preset.bloom, preset.cc
            set("bloom_enabled", bloom ~= nil)
            if bloom then
                set("bloom_intensity", bloom[1])
                set("bloom_size", bloom[2])
                set("bloom_threshold", bloom[3])
            end
            set("color_correction_enabled", cc ~= nil)
            if cc then
                set("color_correction_tint", cc[1])
                set("color_correction_saturation", cc[2])
                set("color_correction_contrast", cc[3])
                set("color_correction_brightness", cc[4])
            end
            set("sunrays_enabled", preset.rays ~= nil)
            if preset.rays then set("sunrays_intensity", preset.rays) end
        end
    end

    function Atmo.reset()
        for _, flag in ipairs({ "skybox_enabled", "atmosphere_enabled", "bloom_enabled", "color_correction_enabled", "sunrays_enabled", "lighting_toggle_Ambient" }) do set(flag, false) end
        set("sky_time_mode", "Off")
        Util.notify("Sky, atmosphere and post effects turned off")
    end

    function Atmo.fromSnap(snap)
        local preset = { ambient = unpackColor(snap.ambient), outer = unpackColor(snap.outer), clock = snap.clock, rays = snap.rays, skyIds = snap.skyIds }
        if snap.atmos then
            local a = snap.atmos
            preset.atmos = { unpackColor(a.color), unpackColor(a.decay), a.density, a.haze, a.glare, a.offset }
        end
        if snap.bloom then preset.bloom = { snap.bloom[1], snap.bloom[2], snap.bloom[3] } end
        if snap.cc then preset.cc = { unpackColor(snap.cc.tint), snap.cc.saturation, snap.cc.contrast, snap.cc.brightness } end
        return preset
    end

    function Atmo.load()
        local ok, data = pcall(function()
            if type(isfile) == "function" and isfile(Atmo.path) then return HttpService:JSONDecode(readfile(Atmo.path)) end
        end)
        if not (ok and type(data) == "table") then return end
        for _, entry in ipairs(type(data.snapshots) == "table" and data.snapshots or {}) do
            if type(entry) == "table" and type(entry.name) == "string" and type(entry.ambient) == "table" then Atmo.snaps[#Atmo.snaps + 1] = entry end
        end
        for _, entry in ipairs(type(data.assets) == "table" and data.assets or {}) do
            if type(entry) == "table" and type(entry.id) == "number" then
                Atmo.assets[#Atmo.assets + 1] = { id = entry.id, name = type(entry.name) == "string" and entry.name or ("Asset " .. entry.id) }
            end
        end
    end

    function Atmo.save()
        if type(writefile) ~= "function" then return end
        Util.guard("atmosphere save", function()
            writefile(Atmo.path, HttpService:JSONEncode({ assets = Atmo.assets, snapshots = Atmo.snaps }))
        end)
    end

    function Atmo.items()
        local items = {}
        for _, name in ipairs(ATMO_ORDER) do items[#items + 1] = { key = "p:" .. name, text = name, meta = "preset" } end
        for _, snap in ipairs(Atmo.snaps) do items[#items + 1] = { key = "c:" .. snap.name, text = snap.name, meta = "captured" } end
        for _, entry in ipairs(Atmo.assets) do items[#items + 1] = { key = "s:" .. entry.id, text = entry.name, meta = "asset" } end
        return items
    end

    function Atmo.find(key)
        key = tostring(key or "")
        local kind, rest = string.sub(key, 1, 1), string.sub(key, 3)
        if kind == "p" and ATMO[rest] then return { preset = ATMO[rest], name = rest } end
        for index, snap in ipairs(Atmo.snaps) do
            if kind == "c" and snap.name == rest then return { preset = Atmo.fromSnap(snap), name = rest, snap = index } end
        end
        for index, entry in ipairs(Atmo.assets) do
            if kind == "s" and tostring(entry.id) == rest then return { asset = entry.id, name = entry.name, saved = index } end
        end
        return nil
    end

    -- Creator Store asset: pull the Sky/Atmosphere/post objects out of the model and copy their values into the flags
    function Atmo.applyAsset(id)
        Util.notify("Loading asset " .. id .. "...")
        task.spawn(function()
            local ok, objects = pcall(function() return game:GetObjects("rbxassetid://" .. id) end)
            if not ok or type(objects) ~= "table" or #objects == 0 then
                Util.notify("Asset " .. id .. " could not be loaded", "warn")
                return
            end
            local found, wanted = {}, { Sky = "sky", Atmosphere = "atmos", BloomEffect = "bloom", ColorCorrectionEffect = "cc", SunRaysEffect = "rays" }
            for _, root in ipairs(objects) do
                local list = root:GetDescendants()
                table.insert(list, 1, root)
                for _, item in ipairs(list) do
                    local key = wanted[item.ClassName]
                    if key and not found[key] then found[key] = item end
                end
            end
            local preset = {}
            if found.sky then preset.skyIds = tostring(id) end
            if found.atmos then
                local a = found.atmos
                preset.atmos = { a.Color, a.Decay, a.Density, a.Haze, a.Glare, a.Offset }
            end
            if found.bloom then preset.bloom = { found.bloom.Intensity, found.bloom.Size, found.bloom.Threshold } end
            if found.cc then preset.cc = { found.cc.TintColor, found.cc.Saturation, found.cc.Contrast, found.cc.Brightness } end
            if found.rays then preset.rays = found.rays.Intensity end
            for _, root in ipairs(objects) do pcall(function() root:Destroy() end) end
            if not (found.sky or found.atmos or found.bloom or found.cc or found.rays) then
                Util.notify("Asset " .. id .. " has no sky, atmosphere or post effects", "warn")
                return
            end
            Atmo.apply(preset, true)
            Util.notify("Applied asset " .. id, "ok")
        end)
    end

    function Atmo.run(key)
        local item = Atmo.find(key or Atmo.selected)
        if not item then
            Util.notify("Pick a preset or asset first", "warn")
            return
        end
        if item.asset then
            Atmo.applyAsset(item.asset)
        else
            Atmo.apply(item.preset)
            Util.notify("Applied preset " .. item.name, "ok")
        end
    end

    function Atmo.capture()
        local name = string.match(tostring(F("atmo_capture_name") or ""), "^%s*(.-)%s*$") or ""
        if name == "" then name = "Captured " .. (#Atmo.snaps + 1) end
        for _, snap in ipairs(Atmo.snaps) do
            if snap.name == name then
                Util.notify("A captured preset named " .. name .. " already exists", "warn")
                return
            end
        end
        local snap = { name = name, ambient = pack(Lighting.Ambient), outer = pack(Lighting.OutdoorAmbient), clock = Lighting.ClockTime }
        local atmos = Lighting:FindFirstChildOfClass("Atmosphere")
        if atmos then snap.atmos = { color = pack(atmos.Color), decay = pack(atmos.Decay), density = atmos.Density, haze = atmos.Haze, glare = atmos.Glare, offset = atmos.Offset } end
        local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
        if bloom and bloom.Enabled then snap.bloom = { bloom.Intensity, bloom.Size, bloom.Threshold } end
        local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
        if cc and cc.Enabled then snap.cc = { tint = pack(cc.TintColor), saturation = cc.Saturation, contrast = cc.Contrast, brightness = cc.Brightness } end
        local rays = Lighting:FindFirstChildOfClass("SunRaysEffect")
        if rays and rays.Enabled then snap.rays = rays.Intensity end
        local sky = Lighting:FindFirstChildOfClass("Sky")
        if sky then
            local ids = {}
            for _, face in ipairs({ "SkyboxUp", "SkyboxDn", "SkyboxFt", "SkyboxBk", "SkyboxLf", "SkyboxRt" }) do
                local id = string.match(tostring(sky[face]), "(%d%d%d+)")
                if id and ids then ids[#ids + 1] = id else ids = nil end
            end
            if ids then snap.skyIds = table.concat(ids, " ") end
        end
        Atmo.snaps[#Atmo.snaps + 1] = snap
        Atmo.save()
        Atmo.refresh()
        Util.notify("Captured current lighting as " .. name, "ok")
    end

    function Atmo.add()
        local text = tostring(F("atmo_asset") or "")
        local id = tonumber(string.match(text, "store/asset/(%d+)") or string.match(text, "assetId=(%d+)") or string.match(text, "(%d%d%d%d+)"))
        if not id then
            Util.notify("Paste a Creator Store link or an asset id first", "warn")
            return
        end
        for _, entry in ipairs(Atmo.assets) do
            if entry.id == id then
                Util.notify("That asset is already saved", "warn")
                return
            end
        end
        local entry = { id = id, name = "Asset " .. id }
        Atmo.assets[#Atmo.assets + 1] = entry
        Atmo.save()
        Atmo.refresh()
        task.spawn(function()
            local ok, info = pcall(function() return game:GetService("MarketplaceService"):GetProductInfo(id) end)
            if ok and type(info) == "table" and type(info.Name) == "string" then
                entry.name = info.Name
                Atmo.save()
                Atmo.refresh()
            end
        end)
    end

    function Atmo.remove()
        local item = Atmo.find(Atmo.selected)
        if item and item.snap then
            table.remove(Atmo.snaps, item.snap)
        elseif item and item.saved then
            table.remove(Atmo.assets, item.saved)
        else
            Util.notify("Select a captured preset or a saved asset first", "warn")
            return
        end
        Atmo.selected = nil
        Atmo.save()
        Atmo.refresh()
    end

    function Atmo.refresh()
        if Atmo.list then Atmo.list:SetItems(Atmo.items()) end
    end

    -- the preview approximates the preset in the viewport (Atmosphere and Sky do not render there)
    function Atmo.previewOf(preset)
        local a = preset.atmos
        return {
            ambient = preset.ambient, light = preset.outer, lightDir = Vector3.new(-1, -1, -1),
            skyTop = a and a[1] or preset.outer, skyBottom = preset.ambient, fogColor = a and a[2] or preset.outer,
            density = a and a[3] or 0, haze = a and math.clamp(a[4] / 4, 0, 1) or 0,
        }
    end

    -- menu: visuals > world (lighting / sky / weather) and effects > atmosphere
    local row = Util.row
    local function studs(v) return v .. " studs" end
    local function deg(v) return v .. "\194\176" end
    local lightPage, skyPage, weatherPage = Pages.visuals["world.lighting"], Pages.visuals["world.sky"], Pages.visuals["world.weather"]

    local light = lightPage:Card({ name = "lighting", id = "lighting", side = "left" })
    row(light, "Ambient", "lighting_toggle_Ambient", { sw = { { "lighting_colorAmbient", "#ffffff" }, { "lighting_colorOutdoorAmbient", "#ffffff" } } })
    local _, g = row(light, "Brightness", "lighting_toggle_Brightness", { gear = "brightness" })
    g:Slider({ name = "Brightness value", flag = "lighting_number_Brightness", min = 0, max = 5, step = 0.01, default = 1.7 })
    _, g = row(light, "Exposure", "lighting_toggle_ExposureCompensation", { gear = "exposure" })
    g:Slider({ name = "Exposure value", flag = "lighting_number_ExposureCompensation", min = -5, max = 5, step = 0.01, default = -1.1 })
    _, g = row(light, "Fog start", "lighting_toggle_FogStart", { gear = "fog start" })
    g:Slider({ name = "Fog start value", flag = "lighting_number_FogStart", min = 0, max = 5000, default = 0, fmt = studs })
    _, g = row(light, "Fog end", "lighting_toggle_FogEnd", { gear = "fog end" })
    g:Slider({ name = "Fog end value", flag = "lighting_number_FogEnd", min = 0, max = 5000, default = 2500, fmt = studs })
    row(light, "Fog color", "lighting_toggle_FogColor", { sw = { { "lighting_colorFogColor", "#ffffff" } } })

    local post = lightPage:Card({ name = "post", id = "post", side = "right" })
    _, g = row(post, "Atmosphere", "atmosphere_enabled", { sw = { { "atmosphere_color", "#ffffff" } }, gear = "atmosphere" })
    g:Slider({ name = "Density", flag = "atmosphere_density", min = 0, max = 1, step = 0.01, default = 0.3 })
    g:Color({ name = "Decay color", flag = "atmosphere_decay", default = "#ffffff" })
    g:Slider({ name = "Glare", flag = "atmosphere_glare", min = 0, max = 10, step = 0.01, default = 4.1 })
    g:Slider({ name = "Haze", flag = "atmosphere_haze", min = 0, max = 10, step = 0.01, default = 1 })
    g:Slider({ name = "Offset", flag = "atmosphere_offset", min = -1, max = 1, step = 0.01, default = 0.4 })
    _, g = row(post, "Bloom", "bloom_enabled", { gear = "bloom" })
    g:Slider({ name = "Intensity", flag = "bloom_intensity", min = 0, max = 3, step = 0.01, default = 0.4 })
    g:Slider({ name = "Size", flag = "bloom_size", min = 0, max = 56, step = 0.5, default = 24 })
    g:Slider({ name = "Threshold", flag = "bloom_threshold", min = 0, max = 2, step = 0.01, default = 0.95 })
    _, g = row(post, "Color correction", "color_correction_enabled", { sw = { { "color_correction_tint", "#ffffff" } }, gear = "color correction" })
    g:Slider({ name = "Saturation", flag = "color_correction_saturation", min = -1, max = 1, step = 0.01, default = 0 })
    g:Slider({ name = "Contrast", flag = "color_correction_contrast", min = -1, max = 1, step = 0.01, default = 0 })
    g:Slider({ name = "Brightness", flag = "color_correction_brightness", min = -1, max = 1, step = 0.01, default = 0 })
    _, g = row(post, "Sun rays", "sunrays_enabled", { gear = "sun rays" })
    g:Slider({ name = "Sun rays intensity", flag = "sunrays_intensity", min = 0, max = 1, step = 0.01, default = 1 })
    post:Slider({ name = "Screen blur", flag = "camera_blur", min = 0, max = 20, step = 0.5, default = 0 })

    local lamps = lightPage:Card({ name = "map lights", id = "maplights", side = "right" })
    row(lamps, "Map lights", "maplights_enabled", { tip = "Customizes the lamps and lights built into the map" })
    row(lamps, "Always on", "maplights_force", { dep = "maplights_enabled" })
    row(lamps, "Recolor lights", "maplights_recolor", { dep = "maplights_enabled", sw = { { "maplights_color", "#ffd696" } } })
    lamps:Slider({ name = "Light brightness", flag = "maplights_brightness", min = 0, max = 10, step = 0.01, default = 1, depends = "maplights_enabled" })
    lamps:Slider({ name = "Light range", flag = "maplights_range", min = 0, max = 5, step = 0.01, default = 1, depends = "maplights_enabled" })
    row(lamps, "Light shadows", "maplights_shadows", { dep = "maplights_enabled" })

    local xray = lightPage:Card({ name = "xray", id = "xray", side = "left" })
    _, g = row(xray, "Xray", "misc_xray", { gear = "xray" })
    g:Slider({ name = "Part transparency", flag = "misc_xray_alpha", min = 0, max = 1, step = 0.01, default = 0.5 })
    g:Input({ name = "Keep opaque (names)", flag = "misc_xray_ignore", placeholder = "Door, Fence" })

    local skyCard = skyPage:Card({ name = "skybox", id = "skybox", side = "left" })
    row(skyCard, "Skybox", "skybox_enabled")
    skyCard:Dropdown({ name = "Preset", flag = "skybox_value", options = World.skyNames, default = "Default" })
    skyCard:Input({ name = "Custom ids", flag = "skybox_custom_ids", placeholder = "1 id or link, or 6: up down front back left right", depends = { "skybox_value", "Custom" } })
    skyCard:Dropdown({ name = "Hide parts", flag = "skybox_disable", options = { "stars", "sun", "moon" }, multi = true, default = { "stars", "sun", "moon" } })

    local motion = skyPage:Card({ name = "sky motion", id = "skymotion", side = "right" })
    _, g = row(motion, "Rotate skybox", "sky_spin", { gear = "rotation" })
    g:Dropdown({ name = "Mode", flag = "sky_spin_mode", options = { "Spin", "Sway" }, default = "Spin" })
    g:Slider({ name = "Yaw speed", flag = "sky_spin_y", min = -90, max = 90, step = 0.5, default = 6, fmt = function(v) return v .. "\194\176/s" end })
    g:Slider({ name = "Pitch speed", flag = "sky_spin_x", min = -90, max = 90, step = 0.5, default = 0, fmt = function(v) return v .. "\194\176/s" end })
    g:Slider({ name = "Roll speed", flag = "sky_spin_z", min = -90, max = 90, step = 0.5, default = 0, fmt = function(v) return v .. "\194\176/s" end })
    motion:Dropdown({ name = "Time", flag = "sky_time_mode", options = { "Off", "Cycle", "Locked" }, default = "Off", tip = "Kept on our own clock, so the game resetting the time does not undo it" })
    motion:Slider({ name = "Cycle speed", flag = "sky_cycle_speed", min = 0.01, max = 3, step = 0.01, default = 0.25, depends = { "sky_time_mode", "Cycle" }, fmt = function(v) return v .. " h/s" end })
    motion:Slider({ name = "Locked time", flag = "sky_time_locked", min = 0, max = 24, step = 0.1, default = 14, depends = { "sky_time_mode", "Locked" }, fmt = function(v) return v .. " h" end })
    _, g = row(motion, "Change sky objects", "sky_objects", { gear = "sky objects" })
    row(g, "Sun and moon", "sky_bodies", { def = true })
    g:Slider({ name = "Stars", flag = "sky_stars", min = 0, max = 5000, step = 50, default = 3000 })
    g:Slider({ name = "Sun size", flag = "sky_sun_size", min = 0, max = 60, default = 21 })
    g:Slider({ name = "Moon size", flag = "sky_moon_size", min = 0, max = 60, default = 11 })

    local cloudCard = skyPage:Card({ name = "clouds", id = "clouds", side = "right" })
    _, g = row(cloudCard, "Clouds", "sky_clouds", { sw = { { "sky_cloud_color", "#ffffff" } }, gear = "clouds" })
    g:Slider({ name = "Cover", flag = "sky_cloud_cover", min = 0, max = 1, step = 0.05, default = 0.6 })
    g:Slider({ name = "Density", flag = "sky_cloud_density", min = 0, max = 1, step = 0.05, default = 0.6 })
    _, g = row(cloudCard, "Cloud drift (wind)", "sky_wind", { gear = "drift", tip = "Moves the clouds through the workspace wind" })
    g:Slider({ name = "Drift direction", flag = "sky_wind_dir", min = 0, max = 360, step = 5, default = 0, fmt = deg })
    g:Slider({ name = "Drift speed", flag = "sky_wind_speed", min = 0, max = 1000, step = 5, default = 60 })

    local weatherCard = weatherPage:Card({ name = "weather", id = "weather", side = "left" })
    _, g = row(weatherCard, "Weather", "weather_enabled", { sw = { { "weather_color", "#c8c8dc" } }, gear = "look" })
    g:Slider({ name = "Speed", flag = "weather_speed", min = 0.2, max = 3, step = 0.01, default = 1 })
    g:Slider({ name = "Size", flag = "weather_size", min = 0.3, max = 3, step = 0.01, default = 1 })
    g:Slider({ name = "Glow", flag = "weather_glow", min = 0, max = 1, step = 0.01, default = 0 })
    g:Slider({ name = "Spread", flag = "weather_spread", min = 0.2, max = 3, step = 0.01, default = 1 })
    weatherCard:Dropdown({ name = "Preset", flag = "weather_preset", options = { "Snow", "Rain", "Blizzard" }, default = "Rain" })
    weatherCard:Slider({ name = "Intensity", flag = "weather_intensity", min = 0.1, max = 3, step = 0.01, default = 1 })
    weatherCard:Slider({ name = "Height", flag = "weather_height", min = 10, max = 120, default = 40, fmt = studs })

    local strike = weatherPage:Card({ name = "wind + lightning", id = "strike", side = "right" })
    strike:Slider({ name = "Wind strength", flag = "weather_wind_strength", min = 0, max = 20, step = 0.1, default = 2 })
    strike:Slider({ name = "Wind direction", flag = "weather_wind_angle", min = 0, max = 360, default = 45, fmt = deg })
    _, g = row(strike, "Lightning (rain only)", "weather_lightning", { sw = { { "weather_lightning_color", "#c8dcff" } }, gear = "lightning" })
    g:Slider({ name = "Thickness", flag = "weather_lightning_thickness", min = 0.05, max = 1, step = 0.01, default = 0.2 })
    g:Slider({ name = "Jaggedness", flag = "weather_lightning_jagged", min = 1, max = 15, step = 0.1, default = 6 })
    g:Slider({ name = "Flash", flag = "weather_lightning_flash", min = 0, max = 10, step = 0.1, default = 4 })
    g:Slider({ name = "Interval", flag = "weather_lightning_interval", min = 1, max = 15, step = 0.1, default = 4, fmt = function(v) return v .. " s" end })

    local atmoPage = Pages.effects.atmosphere
    local presets = atmoPage:Card({ name = "presets", id = "atmopresets", side = "left" })
    row(presets, "Sky", "atmo_part_sky", { def = true })
    row(presets, "Lighting", "atmo_part_light", { def = true })
    row(presets, "Atmosphere", "atmo_part_atmos", { def = true })
    row(presets, "Post effects", "atmo_part_post", { def = true })
    Atmo.list = presets:List({ items = Atmo.items(), rows = 7, save = false, callback = function(key)
        Atmo.selected = key
        local item = Atmo.find(key)
        if item and item.preset and Atmo.view then Atmo.view:Set(Atmo.previewOf(item.preset)) end
    end, activate = function(key) Atmo.run(key) end })
    presets:Buttons({ items = { { name = "Apply selected", primary = true, callback = function() Atmo.run() end }, { name = "Turn everything off", callback = Atmo.reset } } })
    presets:Input({ name = "Creator Store asset", flag = "atmo_asset", placeholder = "link or asset id" })
    presets:Buttons({ items = { { name = "Save asset", callback = Atmo.add }, { name = "Remove selected", callback = Atmo.remove } } })
    presets:Input({ name = "Capture name", flag = "atmo_capture_name", placeholder = "name for the current lighting" })
    presets:Button({ name = "Capture current lighting", callback = Atmo.capture })

    local atmoSide = atmoPage:Card({ name = "preview", id = "atmopreview", side = "right" })
    local atmoView = atmoSide:Preview({ kind = "atmosphere" })
    if Aster.Scene and atmoView then
        Util.guard("atmosphere preview", function()
            Atmo.view = Aster.Scene.Atmosphere(atmoView, Atmo.previewOf(ATMO[ATMO_ORDER[1]]))
        end)
    end
    task.defer(function()
        Atmo.load()
        Atmo.refresh()
    end)
end
bootMark("world", PL2BootT, 6, 13)

PL2BootT = PL2BootClock()
-- [src] 40_fx.lua
do
    Fx = { tracers = {}, pieces = {}, kills = {}, marks = {}, numbers = {}, saved = {}, gun = { next = 0, base = setmetatable({}, { __mode = "k" }), on = {} } }
    local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
    local SoundService = game:GetService("SoundService")
    Fx.path = "AsterV2/games/" .. FOLDER .. "/sounds.json"

    local function col(flag, default)
        local value = F(flag)
        if typeof(value) == "Color3" then return value end
        return default or WHITE
    end
    local function num(flag, default)
        local value = F(flag)
        return type(value) == "number" and value or default
    end
    local function set(object, prop, value)
        pcall(function() object[prop] = value end)
    end
    local function kill(object)
        if object then pcall(function() object:Destroy() end) end
    end
    local function rnd(a, b) return a + math.random() * (b - a) end
    local function spread()
        local v = Vector3.new(rnd(-1, 1), rnd(-1, 1), rnd(-1, 1))
        if v.Magnitude < 0.05 then return Vector3.new(0, 1, 0) end
        return v.Unit
    end

    -- ---- shared world folder + the on-demand frame loop ----
    function Fx.folder()
        local folder = Fx.made
        if folder and folder.Parent then return folder end
        folder = Instance.new("Folder")
        folder.Name = "AsterFx"
        folder.Parent = Workspace
        local anchor = Instance.new("Part")
        anchor.Name, anchor.Anchored, anchor.CanCollide, anchor.Transparency = "Anchor", true, false, 1
        set(anchor, "CanQuery", false)
        set(anchor, "CanTouch", false)
        anchor.Size, anchor.CFrame = Vector3.new(0.1, 0.1, 0.1), CFrame.new(0, 0, 0)
        anchor.Parent = folder
        Fx.made, Fx.anchor = folder, anchor
        return folder
    end
    Util.onUnload(function()
        kill(Fx.made)
        Fx.made, Fx.anchor = nil, nil
    end)

    function Fx.part(props)
        local p = Instance.new("Part")
        p.Anchored, p.CanCollide = true, false
        set(p, "CanQuery", false)
        set(p, "CanTouch", false)
        set(p, "CastShadow", false)
        p.Material = Enum.Material.Neon
        for key, value in pairs(props) do set(p, key, value) end
        p.Parent = Fx.folder()
        return p
    end

    local function busy()
        return #Fx.tracers > 0 or #Fx.pieces > 0 or #Fx.kills > 0 or #Fx.marks > 0 or #Fx.numbers > 0 or Fx.markShown
    end
    function Fx.wake()
        if not Loop.has("fx") then Loop.register("fx", function(dt, now) Fx.step(dt, now) end, 120) end
    end

    -- ---- sounds: built-in list (Data.HIT_SOUNDS) + saved sounds per group in sounds.json ----
    function Fx.asset(text)
        local s = string.match(tostring(text or ""), "^%s*(.-)%s*$")
        if s == "" then return nil end
        local lower = string.lower(s)
        local id = string.match(lower, "^rbxassetid://(%d+)")
        if id then return "rbxassetid://" .. id end
        if string.match(lower, "^rbx%a*://") then return s end
        if string.match(lower, "^https?://") then
            id = string.match(lower, "[?&]id=(%d+)") or string.match(lower, "/library/(%d+)") or string.match(lower, "/catalog/(%d+)") or string.match(lower, "/asset/(%d+)") or string.match(lower, "/(%d%d%d+)")
        else
            id = string.match(lower, "^%D*(%d+)%D*$")
        end
        return id and "rbxassetid://" .. id or nil
    end

    function Fx.load()
        local ok, data = pcall(function()
            if type(isfile) == "function" and isfile(Fx.path) then return HttpService:JSONDecode(readfile(Fx.path)) end
        end)
        if not (ok and type(data) == "table") then return end
        for group, list in pairs(data) do
            if type(group) == "string" and type(list) == "table" then
                local out = {}
                for _, entry in ipairs(list) do
                    if type(entry) == "table" and type(entry.name) == "string" and type(entry.id) == "string" then out[#out + 1] = { name = entry.name, id = entry.id } end
                end
                Fx.saved[group] = out
            end
        end
    end

    function Fx.save()
        if type(writefile) ~= "function" then return end
        Util.guard("sounds save", function()
            local path = ""
            for dir in string.gmatch("AsterV2/games/" .. FOLDER, "[^/]+") do
                path = path == "" and dir or path .. "/" .. dir
                if not isfolder(path) then makefolder(path) end
            end
            writefile(Fx.path, HttpService:JSONEncode(Fx.saved))
        end)
    end

    local function savedNamed(group, name)
        for index, entry in ipairs(Fx.saved[group] or {}) do
            if entry.name == name then return entry, index end
        end
        return nil
    end

    -- hit/kill lists end in "Custom"; gun lists start with "None"; both use <group>_custom when nothing else matches
    function Fx.names(group, gun)
        local names = { gun and "None" or nil }
        for _, entry in ipairs(Fx.saved[group] or {}) do names[#names + 1] = entry.name end
        for _, name in ipairs(Data.HIT_SOUND_NAMES) do names[#names + 1] = name end
        if not gun then names[#names + 1] = "Custom" end
        return names
    end

    function Fx.entry(group, name)
        local saved = savedNamed(group, name)
        if saved then return saved.id end
        local entry = Data.HIT_SOUNDS[name]
        if type(entry) == "table" then return entry[math.random(#entry)] end
        if entry then return entry end
        return Fx.asset(F(group .. "_custom"))
    end

    function Fx.play(asset, volume, pitch, var)
        if not asset then return nil end
        local sound = Instance.new("Sound")
        sound.Name = "AsterSound"
        sound.SoundId, sound.Volume = asset, volume or 1
        sound.PlaybackSpeed = math.max((pitch or 1) * (1 + rnd(-1, 1) * (var or 0)), 0.05)
        sound.Parent = SoundService
        pcall(function() sound:Play() end)
        pcall(function() game:GetService("Debris"):AddItem(sound, 6) end)
        return sound
    end

    function Fx.hitSound(group)
        local prefix = group == "kill" and "World_Kill" or "World_Hit"
        local asset = Fx.entry(group, F(prefix .. "SoundId"))
        if not asset then return Util.notify("Sound: pick a sound or type an id first", "warn") end
        return Fx.play(asset, num(prefix .. "Volume", 1), num(prefix .. "Pitch", 1), num(prefix .. "PitchVar", 0))
    end

    function Fx.addSaved(group, pick)
        local id = Fx.asset(F(group .. "_custom"))
        if not id then return Util.notify("Type a sound id or link first", "warn") end
        local name = string.match(tostring(F(group .. "_name") or ""), "^%s*(.-)%s*$")
        if name == "" then name = "Sound " .. string.match(id, "%d+") end
        local list = Fx.saved[group] or {}
        Fx.saved[group] = list
        local entry = savedNamed(group, name)
        if entry then entry.id = id else list[#list + 1] = { name = name, id = id } end
        Fx.save()
        if Aster.Elements[group .. "_name"] then Aster:Set(group .. "_name", "") end
        if pick and Aster.Elements[pick] then Aster:Set(pick, name) end
        Fx.refreshLists()
        Util.notify("Saved " .. name)
    end

    function Fx.removeSaved(group, pick)
        local _, index = savedNamed(group, F(pick))
        if not index then return Util.notify("Select a saved sound first", "warn") end
        table.remove(Fx.saved[group], index)
        Fx.save()
        Aster:Set(pick, Fx.names(group, string.sub(group, 1, 4) == "sfx_")[1])
        Fx.refreshLists()
    end

    Fx.lists = {}
    function Fx.refreshLists()
        for group, list in pairs(Fx.lists) do
            local items = {}
            for _, entry in ipairs(Fx.saved[group] or {}) do items[#items + 1] = { key = entry.name, text = entry.name, meta = "custom" } end
            for _, name in ipairs(Data.HIT_SOUND_NAMES) do items[#items + 1] = { key = name, text = name, meta = "built-in" } end
            pcall(list.SetItems, list, items)
        end
    end

    -- ---- tracers: 10 Beam looks between two attachments on one anchored part at the origin ----
    local function thin(id) return { tex = id, w = 0.12, alpha = 0, len = 3, mode = "Wrap", speed = 1, seg = 1 } end
    Fx.STYLES = {
        Obelus = { tex = "rbxassetid://2382169232", w = 0.3, alpha = 0.45, len = 5, mode = "Stretch", speed = 0, seg = 1, scene = "beam" },
        Lightning = { tex = "rbxassetid://7151778302", w = 1.2, alpha = 0.45, len = 1, mode = "Stretch", speed = 1, seg = 10, scene = "lightning" },
        DNA = { tex = "rbxassetid://7071778278", w = 0.8, alpha = 0.45, len = 2.4, mode = "Wrap", speed = 1, seg = 1 },
        Beam = thin("rbxassetid://12781852245"), Bolt = thin("rbxassetid://446111271"), Trail = thin("rbxassetid://6419989824"),
        Zigzag = thin("rbxassetid://1274380363"), Heartrate = thin("rbxassetid://5830549480"), Chain = thin("rbxassetid://9632168658"),
        Swirl = thin("rbxassetid://5638168605"),
    }
    Fx.STYLE_ORDER = { "Obelus", "Lightning", "DNA", "Beam", "Bolt", "Trail", "Zigzag", "Heartrate", "Chain", "Swirl" }

    function Fx.tracer(origin, target, color, color2)
        local style = Fx.STYLES[F("tracers_style")] or Fx.STYLES.Obelus
        local anchor = Fx.folder() and Fx.anchor
        local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
        a0.Position, a1.Position = origin, F("tracers_expand") ~= false and origin or target
        a0.Parent, a1.Parent = anchor, anchor
        local beam = Instance.new("Beam")
        local width = style.w * num("tracers_width", 1)
        local props = {
            Texture = style.tex, TextureLength = style.len, TextureMode = Enum.TextureMode[style.mode], TextureSpeed = style.speed, Segments = style.seg,
            Width0 = width, Width1 = width, FaceCamera = true, LightEmission = 1, LightInfluence = 0, Brightness = 1.5 * num("tracers_glow", 1),
            Color = ColorSequence.new(color, color2 or color), Transparency = NumberSequence.new(style.alpha), Attachment0 = a0, Attachment1 = a1,
        }
        for key, value in pairs(props) do set(beam, key, value) end
        beam.Parent = anchor
        local list = Fx.tracers
        if #list >= 40 then Fx.dropTracer(table.remove(list, 1)) end
        local item = { beam = beam, a0 = a0, a1 = a1, from = origin, to = target, age = 0, alpha = style.alpha,
            life = math.max(num("tracers_duration", 0.5), 0.05), fade = math.max(num("tracers_fade", 0.35), 0),
            expand = F("tracers_expand") ~= false, speed = num("tracers_expand_speed", 18) }
        list[#list + 1] = item
        Fx.wake()
        return item
    end

    function Fx.dropTracer(item)
        kill(item.beam)
        kill(item.a0)
        kill(item.a1)
    end

    local function stepTracers(dt)
        local list = Fx.tracers
        for index = #list, 1, -1 do
            local t = list[index]
            t.age = t.age + dt
            if t.expand then
                local k = math.min(1, t.age * t.speed / 6)
                t.a1.Position = t.from + (t.to - t.from) * k
                if k >= 1 then t.expand = false end
            end
            if t.age > t.life then
                local f = t.fade > 0 and (t.age - t.life) / t.fade or 1
                if f >= 1 then
                    Fx.dropTracer(t)
                    table.remove(list, index)
                else
                    t.beam.Transparency = NumberSequence.new(t.alpha + (1 - t.alpha) * f)
                end
            end
        end
    end

    -- ---- burst pieces: impacts and the 5 hit effects share one animated part list ----
    local function piece(props, life, vel, gravity, s1, spin, base)
        local list = Fx.pieces
        if #list >= 240 then kill(table.remove(list, 1).part) end
        local p = Fx.part(props)
        local item = { part = p, age = 0, life = life, from = props.CFrame.Position, vel = vel, g = gravity or 0, s0 = props.Size, s1 = s1 or props.Size, spin = spin, base = base or 0 }
        list[#list + 1] = item
        return item
    end

    Fx.HIT_EFFECTS = { "Sparks", "Ring", "Flash", "Blood", "Confetti" }
    local BURSTS = {
        Sparks = function(pos, color, size, life)
            for _ = 1, 8 do
                piece({ Size = Vector3.new(0.12, 0.12, 0.12) * size, CFrame = CFrame.new(pos), Color = color }, life * 0.5, spread() * 8 * size, 20)
            end
        end,
        Ring = function(pos, color, size, life)
            piece({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.05, 0.3, 0.3), CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2), Color = color, Transparency = 0.2 },
                life * 0.5, Vector3.new(0, 0, 0), 0, Vector3.new(0.05, 4 * size, 4 * size), nil, 0.2)
        end,
        Flash = function(pos, color, size, life)
            piece({ Shape = Enum.PartType.Ball, Size = Vector3.new(0.3, 0.3, 0.3), CFrame = CFrame.new(pos), Color = color, Transparency = 0.2 },
                life * 0.25, Vector3.new(0, 0, 0), 0, Vector3.new(2.5, 2.5, 2.5) * size, nil, 0.2)
        end,
        Blood = function(pos, color, size, life)
            for _ = 1, 10 do
                local dir = spread()
                piece({ Shape = Enum.PartType.Ball, Material = Enum.Material.SmoothPlastic, Size = Vector3.new(0.18, 0.18, 0.18) * size, CFrame = CFrame.new(pos), Color = color },
                    life * 0.6, (dir + Vector3.new(0, 0.8, 0)) * 5 * size, 30)
            end
        end,
        Confetti = function(pos, _, size, life)
            for i = 1, 12 do
                piece({ Material = Enum.Material.SmoothPlastic, Size = Vector3.new(0.25, 0.05, 0.15) * size, CFrame = CFrame.new(pos), Color = Color3.fromHSV(i / 12, 0.8, 1) },
                    life, (spread() + Vector3.new(0, 1.5, 0)) * 4 * size, 12, nil, Vector3.new(rnd(-12, 12), rnd(-12, 12), 0))
            end
        end,
    }

    function Fx.burst(kind, pos, color, size, life)
        local build = BURSTS[kind] or BURSTS.Sparks
        if typeof(pos) ~= "Vector3" then return end
        build(pos, color or WHITE, math.max(size or 1, 0.1), math.max(life or 1, 0.1))
        Fx.wake()
    end

    function Fx.impact(pos)
        local color = col("tracers_color")
        BURSTS.Sparks(pos, color, 0.6, 0.8)
        BURSTS.Flash(pos, color, 0.3, 0.6)
        Fx.wake()
    end

    function Fx.hitEffect(pos)
        Fx.burst(F("he_effect"), pos, col("he_color", Color3.fromRGB(255, 81, 0)), num("he_size", 2) / 2, num("he_duration", 2) / 2)
    end

    local function stepPieces(dt)
        local list = Fx.pieces
        for index = #list, 1, -1 do
            local it = list[index]
            it.age = it.age + dt
            local k = it.age / it.life
            if k >= 1 then
                kill(it.part)
                table.remove(list, index)
            else
                local pos = it.from + it.vel * it.age - Vector3.new(0, 0.5 * it.g * it.age * it.age, 0)
                local cf = CFrame.new(pos)
                if it.spin then cf = cf * CFrame.Angles(it.spin.X * it.age, it.spin.Y * it.age, 0) end
                if it.s1 ~= it.s0 then
                    it.part.Size = it.s0 + (it.s1 - it.s0) * k
                    if not it.spin and it.part.Shape == Enum.PartType.Cylinder then cf = cf * CFrame.Angles(0, 0, math.pi / 2) end
                end
                it.part.CFrame = cf
                it.part.Transparency = it.base + (1 - it.base) * k
            end
        end
    end

    -- ---- kill effects: Aster.Scene kill styles run on a local, anchored clone of the victim ----
    Fx.KILL_STYLES = Aster.Scene and Aster.Scene.KillStyles or { "Melt", "Spaghettify", "Balloon", "Orbit", "Glass", "Magnetize", "Puppet", "Freeze", "Implode", "Vaporize" }

    function Fx.killEffect(victim, style)
        local kills = Aster.Scene and Aster.Scene._kills
        local character = victim and victim.Character
        if not (kills and character) then return nil end
        style = kills[style] and style or "Vaporize"
        set(character, "Archivable", true)
        local ok, clone = pcall(function() return character:Clone() end)
        if not (ok and clone) then return nil end
        clone.Name = "AsterKill"
        local items, originals, center = {}, {}, nil
        for _, d in ipairs(clone:GetDescendants()) do
            if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Sound") or d:IsA("Tool") then
                kill(d)
            elseif d:IsA("BasePart") then
                d.Anchored, d.CanCollide = true, false
                set(d, "CanQuery", false)
                set(d, "CanTouch", false)
                local ok, cf = pcall(function() return d.CFrame end)
                if d.Name == "HumanoidRootPart" then
                    center = d.Position
                    d.Transparency = 1
                elseif ok and typeof(cf) == "CFrame" then
                    items[#items + 1] = { part = d, cf = cf, size = d.Size, t = d.Transparency, color = d.Color or WHITE }
                end
            end
        end
        if #items == 0 then
            kill(clone)
            return nil
        end
        center = center or items[1].cf.Position
        for i, it in ipairs(items) do
            local away = it.cf.Position - center
            it.dir = away.Magnitude > 0.05 and away.Unit or Vector3.new(0, 1, 0)
            it.i, it.n = i, #items
        end
        clone.Parent = Fx.folder()
        local tag = "ke_body_" .. tostring(victim.UserId or victim.Name)
        if F("ke_body") ~= false then
            for _, d in ipairs(character:GetDescendants()) do
                if d:IsA("BasePart") then Util.hold(tag, d, "LocalTransparencyModifier", 1) end
            end
        end
        local ctx = { center = center, ground = center.Y - 3, tint = col("ke_color", Color3.fromRGB(255, 120, 60)) }
        local item = { model = clone, style = style, run = kills[style](items, ctx), age = 0, life = math.max(num("ke_duration", 4) * 0.6, 0.3), hold = 0.4, tag = tag }
        local list = Fx.kills
        if #list >= 6 then Fx.dropKill(table.remove(list, 1)) end
        list[#list + 1] = item
        Fx.wake()
        return item
    end

    function Fx.dropKill(item)
        kill(item.model)
        Util.restore(item.tag)
    end

    local function stepKills(dt)
        local list = Fx.kills
        for index = #list, 1, -1 do
            local it = list[index]
            it.age = it.age + dt
            local k = math.min(1, it.age / it.life)
            Util.guard("kill style " .. it.style, it.run, k)
            if it.age >= it.life + it.hold then
                Fx.dropKill(it)
                table.remove(list, index)
            end
        end
    end

    -- ---- hit marker + damage numbers (Draw from 20_esp) ----
    Fx.MARKER_STYLES = { "Classic X", "Plus", "Circle", "Diamond", "Dot" }
    local R = math.sqrt(0.5)
    local DIAG = { Vector2.new(-R, -R), Vector2.new(R, -R), Vector2.new(-R, R), Vector2.new(R, R) }
    local AXES = { Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(-1, 0), Vector2.new(0, -1) }

    function Fx.markDraw()
        local d = Fx.markObjects
        if d or not Draw then return d end
        d = { lines = {}, edges = {}, all = {} }
        local function add(kind, props)
            props.Visible = false
            local object = Draw.new(kind, props)
            d.all[#d.all + 1] = object
            return object
        end
        for i = 1, 4 do
            d.edges[i] = add("Line", { Thickness = 3, Color = BLACK, ZIndex = 11 })
            d.lines[i] = add("Line", { Thickness = 1, ZIndex = 12 })
        end
        d.ringEdge = add("Circle", { Filled = false, NumSides = 32, Thickness = 3, Color = BLACK, ZIndex = 11 })
        d.ring = add("Circle", { Filled = false, NumSides = 32, Thickness = 1, ZIndex = 12 })
        Fx.markObjects = d
        return d
    end

    local function screenPoint(cam, pos)
        if pos and F("hit_marker_3d") then
            local point, front = Draw.project(cam, pos)
            if front then return point end
        end
        local ok, mouse = pcall(UserInputService.GetMouseLocation, UserInputService)
        if ok and typeof(mouse) == "Vector2" then return mouse end
        return Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
    end

    local function stepMarks(dt)
        local list = Fx.marks
        for index = #list, 1, -1 do
            local m = list[index]
            m.age = m.age + dt
            if m.age > m.life then table.remove(list, index) end
        end
        local d = Fx.markDraw()
        if not d then return end
        local mark, cam = list[#list], Game.camera()
        local on = {}
        if mark and cam then
            local at, k = screenPoint(cam, mark.pos), mark.age / mark.life
            local killed = mark.kill and F("hit_marker_kill") ~= false
            local scale = killed and 1.5 or 1
            local size, gap = num("hit_marker_size", 9) * scale, (3 + k * 4) * scale
            local color = killed and col("hit_marker_kill_color", Color3.fromRGB(255, 190, 60)) or col("hit_marker_color")
            local alpha = 1 - k
            local used = 0
            local function seg(a, b)
                used = used + 1
                local line, edge = d.lines[used], d.edges[used]
                line.From, line.To, line.Color, line.Transparency = at + a, at + b, color, alpha
                edge.From, edge.To, edge.Transparency = at + a, at + b, alpha
                on[line], on[edge] = true, true
            end
            local function ring(radius, filled)
                d.ring.Position, d.ring.Radius, d.ring.Filled, d.ring.Color, d.ring.Transparency = at, radius, filled, color, alpha
                d.ringEdge.Position, d.ringEdge.Radius, d.ringEdge.Transparency = at, radius + 1, alpha
                on[d.ring], on[d.ringEdge] = true, true
            end
            local style = F("hit_marker_style")
            if style == "Circle" then
                ring(gap + size * 0.6, false)
            elseif style == "Dot" then
                ring(math.max(2, size * 0.35), true)
            elseif style == "Diamond" then
                local r = gap + size
                for i = 1, 4 do seg(AXES[i] * r, AXES[i % 4 + 1] * r) end
            else
                for _, dir in ipairs(style == "Plus" and AXES or DIAG) do seg(dir * gap, dir * (gap + size)) end
            end
        end
        local any = next(on) ~= nil
        if any or Fx.markShown then
            for _, object in ipairs(d.all) do object.Visible = on[object] == true end
        end
        Fx.markShown = any
    end

    local function stepNumbers(dt)
        local list, cam = Fx.numbers, Game.camera()
        Fx.texts = Fx.texts or {}
        local used, life, rise = 0, num("dmg_time", 1.1), num("dmg_rise", 60)
        for index = #list, 1, -1 do
            local n = list[index]
            n.age = n.age + dt
            local t = n.age / life
            if t >= 1 then
                table.remove(list, index)
            elseif cam and Draw then
                local point, front = Draw.project(cam, n.pos)
                if front then
                    used = used + 1
                    local text = Fx.texts[used]
                    if not text then
                        text = Draw.text(16, 9)
                        Fx.texts[used] = text
                    end
                    local ease = 1 - (1 - math.min(t * 1.6, 1)) ^ 3
                    text.Text, text.Size, text.Color = n.text, num("dmg_size", 16) * (n.big and 1.5 or 1), n.color
                    text.Position = Vector2.new(point.X + n.dx * ease, point.Y - rise * ease)
                    text.Transparency, text.Visible = t > 0.6 and (1 - (t - 0.6) / 0.4) or 1, true
                end
            end
        end
        for index = used + 1, #Fx.texts do Fx.texts[index].Visible = false end
    end

    function Fx.step(dt)
        stepTracers(dt)
        stepPieces(dt)
        stepKills(dt)
        stepMarks(dt)
        stepNumbers(dt)
        if not busy() then Loop.unregister("fx") end
    end

    Util.onUnload(function()
        for _, item in ipairs(Fx.kills) do Fx.dropKill(item) end
        Fx.tracers, Fx.pieces, Fx.kills, Fx.marks, Fx.numbers = {}, {}, {}, {}, {}
    end)

    -- ---- gun sounds: Util.hold swaps the game's shot sounds per weapon (tag sfx_<key>) ----
    local REPLACE = "Replace game sound"
    local byTool = {}
    for _, weapon in ipairs(Data.FX_WEAPONS) do
        for _, name in ipairs(weapon.tools) do byTool[name] = weapon end
    end
    local function weaponOf(name)
        return byTool[string.lower((string.gsub(tostring(name or ""), "[^%w]", "")))]
    end
    local function isShot(sound)
        local name = string.lower(tostring(sound.Name))
        for _, word in ipairs({ "shoot", "fire", "shot", "bang" }) do
            if string.find(name, word, 1, true) then return true end
        end
        return false
    end

    function Fx.gunAsset(key)
        return Fx.entry(key, F(key .. "_sound"))
    end

    function Fx.gunApply(sound, weapon, owned)
        local key = "sfx_" .. weapon.key
        local asset = F(key .. "_on") and (owned or F(key .. "_others") ~= false) and Fx.gunAsset(key) or nil
        if not asset then
            for _, prop in ipairs({ "SoundId", "Volume", "PlaybackSpeed" }) do Util.restore(key, sound, prop) end
            return
        end
        local base = Fx.gun.base[sound]
        if not base then
            base = { volume = sound.Volume or 0.5 }
            Fx.gun.base[sound] = base
        end
        if F(key .. "_method") == REPLACE then
            if sound.SoundId ~= asset then Util.hold(key, sound, "SoundId", asset) end
            local volume = base.volume * num(key .. "_volume", 1)
            if sound.Volume ~= volume then Util.hold(key, sound, "Volume", volume) end
            if not sound.IsPlaying then
                Util.hold(key, sound, "PlaybackSpeed", math.max(num(key .. "_pitch", 1) * (1 + rnd(-1, 1) * num(key .. "_pitchvar", 0)), 0.05))
            end
        else
            Util.restore(key, sound, "SoundId")
            Util.restore(key, sound, "PlaybackSpeed")
            if F(key .. "_mute") ~= false then Util.hold(key, sound, "Volume", 0) else Util.restore(key, sound, "Volume") end
        end
    end

    local function scanTool(tool, owned)
        local weapon = weaponOf(tool.Name)
        if not weapon then return end
        for _, object in ipairs(tool:GetDescendants()) do
            if object:IsA("Sound") and isShot(object) then Fx.gunApply(object, weapon, owned) end
        end
    end

    function Fx.gunStep(_, now)
        if now < Fx.gun.next then return end
        Fx.gun.next = now + 0.25
        for _, player in ipairs(Players:GetPlayers()) do
            local owned = player == LocalPlayer
            local containers = { player.Character, owned and player:FindFirstChildOfClass("Backpack") or nil }
            for _, container in pairs(containers) do
                for _, child in ipairs(container:GetChildren()) do
                    if child:IsA("Tool") then scanTool(child, owned) end
                end
            end
        end
    end

    local function gunRefresh()
        local any = false
        for _, weapon in ipairs(Data.FX_WEAPONS) do
            local key = "sfx_" .. weapon.key
            local on = F(key .. "_on") == true
            if Fx.gun.on[key] and not on then Util.restore(key) end
            Fx.gun.on[key] = on
            if on then any = true end
        end
        Fx.gun.next = 0
        if any then
            if not Loop.has("gun_sounds") then Loop.register("gun_sounds", Fx.gunStep, 130) end
        elseif Loop.has("gun_sounds") then
            Loop.unregister("gun_sounds")
        end
    end

    -- Play on shot: our own sound on top of the (muted) game sound
    local function playOnShot(weaponName, owned)
        local weapon = weaponOf(weaponName)
        if not weapon then return end
        local key = "sfx_" .. weapon.key
        if not F(key .. "_on") or F(key .. "_method") == REPLACE or not (owned or F(key .. "_others") ~= false) then return end
        Fx.play(Fx.gunAsset(key), 0.5 * num(key .. "_volume", 1), num(key .. "_pitch", 1), num(key .. "_pitchvar", 0))
    end

    -- ---- game events ----
    local lastNotify = 0
    function Fx.onShot(origin, hitPos, own, shooter)
        if own then
            local tool = Game.weapon()
            if tool then playOnShot(tool.Name, true) end
            if F("tracers_enabled") then Fx.tracer(origin, hitPos, col("tracers_color"), F("tracers_gradient") and col("tracers_color2") or nil) end
            if F("World_Impacts") then Fx.impact(hitPos) end
            if F("he_enabled") and F("he_trigger") == "On shot" then Fx.hitEffect(hitPos) end
            return
        end
        local rec = shooter and Entities.byPlayer[shooter]
        if rec then playOnShot(rec.weaponName, false) end
        if F("tracers_enemy") and not (shooter and not Game.isEnemy(shooter)) then Fx.tracer(origin, hitPos, col("tracers_enemy_color", Color3.fromRGB(94, 160, 255))) end
    end

    function Fx.onHit(victim, damage, position, partName, killed)
        if F("World_HitSound") and not (killed and F("World_KillSound")) then Fx.hitSound("hit") end
        if F("hit_marker") then
            if #Fx.marks >= 6 then table.remove(Fx.marks, 1) end
            Fx.marks[#Fx.marks + 1] = { age = 0, life = num("hit_marker_time", 0.4), pos = position, kill = killed == true }
        end
        if F("dmg_on") and typeof(position) == "Vector3" and type(damage) == "number" then
            local color = partName == "Head" and col("dmg_head") or partName == "Torso" and col("dmg_torso") or col("dmg_limb")
            Fx.spiral = (Fx.spiral or 0) + 1
            if #Fx.numbers >= 24 then table.remove(Fx.numbers, 1) end
            Fx.numbers[#Fx.numbers + 1] = { pos = position, text = tostring(math.max(1, math.floor(damage + 0.5))), color = color, age = 0, dx = math.cos(2.4 * Fx.spiral) * 22, big = killed == true }
        end
        if F("World_HitNotify") and os.clock() - lastNotify > 0.25 then
            lastNotify = os.clock()
            Util.notify(string.format("hit %s in the %s for %d", tostring(victim and victim.Name), string.lower(tostring(partName or "body")), math.floor((damage or 0) + 0.5)))
        end
        if F("he_enabled") and F("he_trigger") ~= "On shot" then Fx.hitEffect(position) end
        Fx.wake()
    end

    function Fx.onKill(victim)
        if F("World_KillSound") then Fx.hitSound("kill") end
        local mark = Fx.marks[#Fx.marks]
        if mark then mark.kill, mark.life = true, num("hit_marker_time", 0.4) * 1.5 end
        if F("ke_enabled") then Fx.killEffect(victim, F("ke_effect")) end
    end

    local events = Game.events
    events.onOwnShot:Connect(function(origin, hitPos) Fx.onShot(origin, hitPos, true) end)
    events.onEnemyShot:Connect(function(shooter, origin, hitPos) Fx.onShot(origin, hitPos, false, shooter) end)
    events.onHit:Connect(Fx.onHit)
    events.onKill:Connect(Fx.onKill)
    local function filter(_, _, _, own) return own and F("tracers_enabled") and F("tracers_hide") ~= false end
    Game.tracerFilter = filter
    Util.onUnload(function() if Game.tracerFilter == filter then Game.tracerFilter = nil end end)

    -- ---- effects tab ----
    local row = Util.row
    local function secs(v) return v .. " s" end
    local Scene = Aster.Scene
    Fx.views = {}
    Fx.load()

    local function soundRow(card, name, group, prefix, default)
        local _, g = row(card, name, prefix .. "Sound", { gear = string.lower(name) })
        g:Dropdown({ name = "Sound", flag = prefix .. "SoundId", options = function() return Fx.names(group) end, default = default })
        g:Slider({ name = "Volume", flag = prefix .. "Volume", min = 0, max = 5, step = 0.01, default = 1 })
        g:Slider({ name = "Pitch", flag = prefix .. "Pitch", min = 0.5, max = 2, step = 0.01, default = 1 })
        g:Slider({ name = "Pitch variation", flag = prefix .. "PitchVar", min = 0, max = 0.5, step = 0.01, default = 0 })
        g:Input({ name = "Sound id", flag = group .. "_custom", placeholder = "audio id or link (Custom, or to save)" })
        g:Input({ name = "Sound name", flag = group .. "_name", placeholder = "name to save it under (optional)" })
        g:Buttons({ items = {
            { name = "Play", primary = true, callback = function() Fx.hitSound(group) end },
            { name = "Save", callback = function() Fx.addSaved(group, prefix .. "SoundId") end },
            { name = "Remove", callback = function() Fx.removeSaved(group, prefix .. "SoundId") end },
        } })
    end

    local function preview(page, kind, buttons)
        local card = Pages.effects[page]:Card({ name = "preview", id = "fxp_" .. kind, side = "right" })
        local v = { view = card:Preview({ kind = kind }) }
        if Scene and v.view then
            Util.guard("fx preview " .. kind, function()
                Scene.attach(v.view)
                v.dummy = Scene.Dummy(v.view, { motion = kind == "shoot" and "none" or "idle" })
                v.view:Fit()
            end)
        end
        if v.view and v.view.SetButtons then v.view.SetButtons(buttons(v)) end
        Fx.views[kind] = v
        return v
    end
    local function run(label, fn)
        return function() Util.guard(label, fn) end
    end

    local shoot = Pages.effects.shoot:Card({ name = "tracers", id = "fxtracers", side = "left" })
    local _, g = row(shoot, "Bullet tracers", "tracers_enabled", { sw = { { "tracers_color", "#ffffff" } }, gear = "tracers" })
    g:Dropdown({ name = "Style", flag = "tracers_style", options = Fx.STYLE_ORDER, default = "Obelus" })
    row(g, "Gradient", "tracers_gradient", { sw = { { "tracers_color2", "#ff5050" } } })
    g:Slider({ name = "Width", flag = "tracers_width", min = 0.3, max = 3, step = 0.1, default = 1, fmt = function(v) return v .. "x" end })
    g:Slider({ name = "Glow", flag = "tracers_glow", min = 1, max = 10, step = 0.1, default = 1 })
    g:Slider({ name = "Visible time", flag = "tracers_duration", min = 0.1, max = 5, step = 0.1, default = 0.5, fmt = secs })
    g:Slider({ name = "Fade time", flag = "tracers_fade", min = 0, max = 3, step = 0.01, default = 0.35, fmt = secs })
    row(g, "Expand from muzzle", "tracers_expand", { def = true })
    g:Slider({ name = "Expand speed", flag = "tracers_expand_speed", min = 4, max = 40, default = 18, depends = "tracers_expand" })
    row(g, "Hide the game's tracer", "tracers_hide", { def = true })
    row(shoot, "Enemy tracers", "tracers_enemy", { sw = { { "tracers_enemy_color", "#5ea0ff" } }, tip = "Shots replicated from enemies; teammates are skipped" })
    row(shoot, "Bullet impacts", "World_Impacts", { tip = "Sparks where your bullets land" })

    local function shootPreview(v)
        if not (Scene and v.dummy) or not (F("tracers_enabled") or F("World_Impacts")) then return end
        local style = Fx.STYLES[F("tracers_style")] or Fx.STYLES.Obelus
        Scene.Shoot(v.view, v.dummy, {
            style = style.scene or "line", color = col("tracers_color"), width = F("tracers_enabled") and 0.08 * num("tracers_width", 1) or 0, tracer = F("tracers_enabled"),
            life = num("tracers_duration", 0.5) + num("tracers_fade", 0.35), sparks = F("World_Impacts") == true, sparkColor = col("tracers_color"), brightness = num("tracers_glow", 1),
        })
    end
    local shootView = preview("shoot", "shoot", function(v)
        return { { "Shoot", run("shoot preview", function() shootPreview(v) end) } }
    end)
    local lastShot = 0
    Util.changed({ "tracers_*", "World_Impacts" }, function()
        if os.clock() - lastShot < 0.25 then return end
        lastShot = os.clock()
        shootPreview(shootView)
    end)

    local hit = Pages.effects.hit:Card({ name = "hit feedback", id = "fxhit", side = "left" })
    row(hit, "Hit notifications", "World_HitNotify")
    soundRow(hit, "Hit sound", "hit", "World_Hit", "Gamesense")
    _, g = row(hit, "Hit marker", "hit_marker", { sw = { { "hit_marker_color", "#ffffff" } }, gear = "hit marker" })
    g:Dropdown({ name = "Style", flag = "hit_marker_style", options = Fx.MARKER_STYLES, default = "Classic X" })
    g:Slider({ name = "Size", flag = "hit_marker_size", min = 4, max = 24, default = 9, fmt = function(v) return v .. " px" end })
    g:Slider({ name = "Duration", flag = "hit_marker_time", min = 0.1, max = 1.2, step = 0.01, default = 0.4, fmt = secs })
    row(g, "Kill colour", "hit_marker_kill", { def = true, sw = { { "hit_marker_kill_color", "#ffbe3c" } } })
    row(g, "At the hit position", "hit_marker_3d")
    _, g = row(hit, "Damage numbers", "dmg_on", { sw = { { "dmg_head", "#ff6666" }, { "dmg_torso", "#ff9600" }, { "dmg_limb", "#ffff00" } }, gear = "damage numbers" })
    g:Slider({ name = "Size", flag = "dmg_size", min = 8, max = 32, default = 16 })
    g:Slider({ name = "Rise", flag = "dmg_rise", min = 10, max = 150, default = 60 })
    g:Slider({ name = "Duration", flag = "dmg_time", min = 0.4, max = 3, step = 0.01, default = 1.1, fmt = secs })
    _, g = row(hit, "Hit effects", "he_enabled", { sw = { { "he_color", "#ff5100" } }, gear = "hit effects" })
    g:Dropdown({ name = "Effect", flag = "he_effect", options = Fx.HIT_EFFECTS, default = "Sparks" })
    g:Dropdown({ name = "Trigger", flag = "he_trigger", options = { "On hit", "On shot" }, default = "On hit" })
    g:Slider({ name = "Size", flag = "he_size", min = 0, max = 10, step = 0.1, default = 2 })
    g:Slider({ name = "Duration", flag = "he_duration", min = 0.1, max = 10, step = 0.1, default = 2, fmt = secs })

    local function hitPreview(v, part)
        if F("World_HitSound") then Fx.hitSound("hit") end
        if not (Scene and v.dummy) then return end
        Scene.Hit(v.view, v.dummy, {
            part = part, damage = part == "Head" and 87 or 34, life = num("dmg_time", 1.1),
            marker = F("hit_marker"), markerColor = col("hit_marker_color"), markerSize = num("hit_marker_size", 9),
            number = F("dmg_on"), color = part == "Head" and col("dmg_head") or col("dmg_torso"), flash = F("he_enabled") == true, flashColor = col("he_color"),
        })
    end
    preview("hit", "hit", function(v)
        return { { "Body", run("hit preview", function() hitPreview(v, "Torso") end) }, { "Head", run("hit preview", function() hitPreview(v, "Head") end) } }
    end)

    local killCard = Pages.effects.kill:Card({ name = "kill feedback", id = "fxkill", side = "left" })
    soundRow(killCard, "Kill sound", "kill", "World_Kill", "PF Killshot")
    _, g = row(killCard, "Kill effects", "ke_enabled", { sw = { { "ke_color", "#ff783c" } }, gear = "kill effects", tip = "Plays on a local copy of a player you killed" })
    g:Dropdown({ name = "Effect", flag = "ke_effect", options = Fx.KILL_STYLES, default = "Vaporize" })
    row(g, "Hide the real body", "ke_body", { def = true, tip = "The body stays hidden while its copy plays the effect" })
    g:Slider({ name = "Duration", flag = "ke_duration", min = 1, max = 8, step = 0.1, default = 4, fmt = secs })
    preview("kill", "kill", function(v)
        return {
            { "Kill", run("kill preview", function()
                if F("World_KillSound") then Fx.hitSound("kill") end
                if Scene and v.dummy then Scene.Kill(v.view, v.dummy, F("ke_effect"), { time = num("ke_duration", 4) * 0.6, color = col("ke_color") }) end
            end) },
            { "Reset", run("kill preview", function() if v.dummy then v.dummy:Reset() end end) },
        }
    end)

    for _, weapon in ipairs(Data.FX_WEAPONS) do
        local key = "sfx_" .. weapon.key
        local view = Pages.effects["gunsounds." .. weapon.key]
        local card = view:Card({ name = string.lower(weapon.label), id = "gs_" .. weapon.key, side = "left" })
        row(card, "Replace sound", key .. "_on", { tip = "Swaps this gun's shot sound locally" })
        card:Dropdown({ name = "Saved sound", flag = key .. "_sound", options = function() return Fx.names(key, true) end, default = "None" })
        card:Input({ name = "Sound id", flag = key .. "_custom", placeholder = "audio id or link (None plays it)" })
        card:Input({ name = "Sound name", flag = key .. "_name", placeholder = "name to save it under (optional)" })
        card:Buttons({ items = {
            { name = "Preview", primary = true, callback = function()
                local asset = Fx.gunAsset(key)
                if not asset then return Util.notify("Pick a sound or type an id first", "warn") end
                Fx.play(asset, 0.5 * num(key .. "_volume", 1), num(key .. "_pitch", 1), num(key .. "_pitchvar", 0))
            end },
            { name = "Save", callback = function() Fx.addSaved(key, key .. "_sound") end },
            { name = "Remove", callback = function() Fx.removeSaved(key, key .. "_sound") end },
        } })
        card:Slider({ name = "Volume", flag = key .. "_volume", min = 0, max = 3, step = 0.01, default = 1, fmt = function(v) return v .. "x" end })
        card:Slider({ name = "Pitch", flag = key .. "_pitch", min = 0.5, max = 2, step = 0.01, default = 1 })
        card:Slider({ name = "Pitch variation", flag = key .. "_pitchvar", min = 0, max = 0.5, step = 0.01, default = 0 })
        card:Dropdown({ name = "Method", flag = key .. "_method", options = { REPLACE, "Play on shot" }, default = REPLACE })
        row(card, "Other players' guns too", key .. "_others", { def = true })
        row(card, "Mute game sound (Play on shot)", key .. "_mute", { def = true })
        local sounds = view:Card({ name = "sounds", id = "gs_list_" .. weapon.key, side = "right" })
        Fx.lists[key] = sounds:List({ rows = 9, save = false, items = {}, callback = function(name)
            Aster:Set(key .. "_sound", name)
            Util.guard("gun sound audition", function() Fx.play(Fx.gunAsset(key), 0.5 * num(key .. "_volume", 1), num(key .. "_pitch", 1), 0) end)
        end })
    end
    Fx.refreshLists()
    Util.changed({ "sfx_*" }, function(flag)
        if string.sub(flag, -3) == "_on" or string.sub(flag, -7) == "_method" or string.sub(flag, -6) == "_sound" or string.sub(flag, -7) == "_others" then gunRefresh() end
    end)
    gunRefresh()
end
bootMark("fx", PL2BootT, 7, 13)

PL2BootT = PL2BootClock()
-- [src] 45_compat.lua
-- Old Linoria / aster v1 API on aster v2, for the combat block copied unchanged from dev.lua (50_combat.lua, run by 99_tail).
-- It provides what deps.txt lists as `shim`: groupboxes (Section / AddToggle / AddSlider / ...) that put their rows into cards on
-- Pages.combat and Pages.visuals.indicators, Options / Toggles over the aster flags, Library, Skin.CreateTargetInfo (Hud.Target),
-- Actions / ShotEvents / MiscActions (Combat is the Actions table) and the track / onUnload / Relations bridges.
do
    local function noop() end
    local MODES = { Hold = "hold", Toggle = "toggle", Always = "always" }

    -- old group (sub tab + section name) -> { tab, page view, card, side }; one card can collect several old sections
    local ROUTES = {
        CombatSubs = {
            Aim = {
                ["Aim assist"] = { "combat", "legit.aim", "aim assist", "left" },
                ["Aim smoothing"] = { "combat", "legit.aim", "smoothing", "right" },
                ["Triggerbot"] = { "combat", "legit.trigger", "triggerbot", "left" },
                ["Aim FOV"] = { "combat", "legit.aim", "fov + checks", "right" },
                ["Aim checks"] = { "combat", "legit.aim", "fov + checks", "right" },
            },
            Silent = {
                ["Silent aim"] = { "combat", "legit.silent", "silent aim", "left" },
                ["Silent checks"] = { "combat", "legit.silent", "fov + checks", "right" },
                ["Silent FOV"] = { "combat", "legit.silent", "fov + checks", "right" },
                ["Silent prediction"] = { "combat", "legit.silent", "prediction", "right" },
                ["Auto fire"] = { "combat", "legit.silent", "auto fire + switch", "left" },
                ["Weapon switching"] = { "combat", "legit.silent", "auto fire + switch", "left" },
            },
            Other = {
                ["Target info"] = { "visuals", "indicators", "target hud", "left" },
                ["Weapon utility"] = { "combat", "rage.weapon", "utility", "left" },
            },
        },
        RageSubs = {
            Main = {
                ["Ragebot"] = { "combat", "rage.ragebot", "ragebot", "left" },
                ["Target rules"] = { "combat", "rage.ragebot", "targets", "right" },
                ["Target"] = { "combat", "rage.ragebot", "targets", "right" },
                ["Status and safety"] = { "combat", "rage.ragebot", "status + safety", "right" },
            },
            Void = {
                ["Void spam"] = { "combat", "rage.void", "void spam", "left" },
                ["Void safety"] = { "combat", "rage.void", "void spam", "left" },
                ["Void pattern"] = { "combat", "rage.void", "pattern", "right" },
                ["Void hide"] = { "combat", "rage.void", "void hide", "left" },
                ["Peek spot"] = { "combat", "rage.void", "peek spot", "right" },
            },
            Aim = {
                ["Prediction and resolver"] = { "combat", "rage.weapon", "prediction + resolver", "right" },
                ["Wallbang"] = { "combat", "rage.weapon", "wallbang", "right" },
                ["Wallbang assist"] = { "combat", "rage.weapon", "wallbang", "right" },
                ["Gun mods"] = { "combat", "rage.weapon", "gun mods", "left" },
            },
            Other = {
                ["Orbit target"] = { "combat", "rage.other", "orbit target", "left" },
                ["Desync"] = { "combat", "rage.other", "desync", "right" },
            },
        },
        WorldSubs = {
            Indicators = {
                ["Reload indicator"] = { "visuals", "indicators", "reload", "left" },
                ["Ammo indicator"] = { "visuals", "indicators", "ammo", "left" },
                ["Wallbang indicator"] = { "visuals", "indicators", "wallbang", "right" },
            },
        },
    }

    local cards = {}
    local function cardFor(route)
        local tab, view, name, side = route[1], route[2], route[3], route[4]
        local id = "cb_" .. string.gsub(view, "[^%w]+", "_") .. "_" .. string.gsub(string.lower(name), "[^%w]+", "_")
        local key = tab .. "/" .. id
        if cards[key] then return cards[key] end
        local page = Pages[tab] and Pages[tab][view]
        if not page then
            Util.note("compat page " .. key, "combat rows need Pages." .. tab .. "[" .. view .. "], which is missing")
            return nil
        end
        local ok, card = pcall(page.Card, page, { name = name, id = id, side = side })
        if not ok then
            Util.note("compat card " .. key, "could not build card " .. name .. ":", card)
            return nil
        end
        cards[key] = card
        return card
    end

    local function hex8(color, opacity)
        local function byte(v) return math.floor(math.clamp(v, 0, 1) * 255 + 0.5) end
        return string.format("#%02x%02x%02x%02x", byte(color.R), byte(color.G), byte(color.B), byte(opacity))
    end

    local keyNames
    local function keyText(key)
        if key == nil or key == "" then return "None" end
        local mouse = string.match(key, "^m(%d)$")
        if mouse then return "MB" .. mouse end
        if not keyNames then
            keyNames = {}
            pcall(function()
                for _, item in ipairs(Enum.KeyCode:GetEnumItems()) do keyNames[string.lower(item.Name)] = item.Name end
            end)
        end
        return keyNames[key] or key
    end
    local function keyFix(name)
        if typeof(name) == "EnumItem" then return name.Name end
        local mouse = type(name) == "string" and string.match(string.upper(name), "^MB(%d)$")
        if mouse then return "m" .. mouse end
        return name
    end

    local function listOf(value)
        if type(value) == "string" then return { value } end
        local out = {}
        if type(value) ~= "table" then return out end
        if #value > 0 then
            for _, name in ipairs(value) do out[#out + 1] = tostring(name) end
        else
            for name, chosen in pairs(value) do
                if chosen then out[#out + 1] = tostring(name) end
            end
            table.sort(out)
        end
        return out
    end
    local function mapOf(list)
        local map = {}
        for _, name in ipairs(list) do map[name] = true end
        return map
    end

    -- keys made without Sync: their state does not follow the parent toggle, and a tap must not flip it
    local loose = setmetatable({}, { __mode = "k" })

    -- Options / Toggles objects: .Value, .Transparency, :SetValue :SetValues :OnChanged :OnClick :GetState
    local Option = {}
    local function valueOf(el)
        local value = el.Value
        if el.Kind == "dropdown" and el.Opts.multi then return mapOf(value) end
        if el.Kind == "keybind" then return keyText(value.key) end
        return value
    end
    function Option.__index(self, key)
        local method = rawget(Option, key)
        if method ~= nil then return method end
        local el = rawget(self, "_el")
        if key == "Value" then return valueOf(el) end
        if key == "Transparency" then
            if el.Kind == "color" and not el.Opts.opaque then return 1 - el:Alpha() end
            return nil
        end
        if key == "Mode" and el.Kind == "keybind" then
            for name, mode in pairs(MODES) do
                if mode == el.Value.mode then return name end
            end
        end
        return nil
    end
    function Option:SetValue(value)
        local el = rawget(self, "_el")
        if el.Kind == "dropdown" and el.Opts.multi then
            value = listOf(value)
        elseif el.Kind == "keybind" then
            if type(value) == "table" then value = { key = keyFix(value[1]), mode = MODES[value[2]] or el.Value.mode } else value = keyFix(value) end
        elseif el.Kind == "color" and type(value) == "string" then
            return
        end
        el:Set(value)
    end
    -- Linoria kept the selected names that left the list (players who left stay whitelisted / targeted); SetOptions drops them
    function Option:SetValues(list)
        local el = rawget(self, "_el")
        if not el.SetOptions then return end
        if el.Opts.multi and type(list) == "table" then
            local merged, listed = {}, {}
            for _, name in ipairs(list) do
                merged[#merged + 1] = name
                listed[tostring(name)] = true
            end
            for _, name in ipairs(el.Value) do
                if not listed[name] then merged[#merged + 1] = name end
            end
            list = merged
        end
        el:SetOptions(list)
    end
    function Option:OnChanged(fn)
        local el = rawget(self, "_el")
        return el.Changed:Connect(function() fn(valueOf(el)) end)
    end
    function Option:OnClick(fn)
        local el = rawget(self, "_el")
        if el.Pressed then return el.Pressed:Connect(function() fn() end) end
        return nil
    end
    function Option:GetState()
        local el = rawget(self, "_el")
        if el.Kind == "keybind" then
            if loose[el] then
                local mode = el.Value.mode
                if mode == "hold" then return el.Value.key ~= "" and el._held == true end
                if mode == "always" then return true end
            end
            return el:Active()
        end
        if el.Kind == "toggle" then return el.Value == true end
        return true
    end

    local objects = setmetatable({}, { __mode = "k" })
    local function lookup(wantToggle)
        return setmetatable({}, { __index = function(_, flag)
            local el = type(flag) == "string" and Aster.Elements[flag] or nil
            if not el or (el.Kind == "toggle") ~= wantToggle then return nil end
            local object = objects[el]
            if not object then
                object = setmetatable({ _el = el }, Option)
                objects[el] = object
            end
            return object
        end })
    end

    -- a row handle: what AddToggle / AddLabel return, with the Linoria addons (and the dev.lua wrapper names) on top
    local Handle = {}
    Handle.__index = Handle
    function Handle:SetText(text)
        local el = self.el
        if not el then return end
        if el.SetText then el:SetText(text) elseif el.Label then el.Label.Text = tostring(text) end
    end
    function Handle:AddColorPicker(flag, info)
        info = info or {}
        local el = self.el
        if not el then return self end
        local alpha = info.Transparency
        local default = info.Default or Color3.new(1, 1, 1)
        local ok, err = pcall(function()
            el:Color({ flag = flag, default = alpha ~= nil and hex8(default, 1 - alpha) or default, opaque = alpha == nil })
        end)
        if not ok then Util.note("compat color " .. flag, "color picker " .. flag .. " failed:", err) end
        return self
    end
    function Handle:AddKeyPicker(flag, info)
        info = info or {}
        local el = self.el
        if not el then return self end
        local sync = info.SyncToggleState == true
        local mode = sync and "toggle" or MODES[info.Mode] or "always"
        local key
        local ok, err = pcall(function()
            key = el:Keybind({ flag = flag, default = keyFix(info.Default) or "", mode = mode, hud = info.Text })
        end)
        if ok and key and not sync then loose[key] = true end
        if not ok then Util.note("compat key " .. flag, "key picker " .. flag .. " failed:", err) end
        return self
    end
    -- dev.lua's wrapper names
    function Handle:Colorpicker(info)
        local transparency = nil
        if info.Alpha then transparency = type(info.Alpha) == "number" and info.Alpha or 0 end
        return self:AddColorPicker(info.Flag, { Default = info.Default, Transparency = transparency })
    end
    function Handle:Keybind(info)
        return self:AddKeyPicker(info.Flag, { Default = info.Default, Mode = info.Mode, Text = info.Name, SyncToggleState = info.Sync == true })
    end

    -- Linoria groupbox. Rows are built into the card the section routes to; the card is made on the first row.
    local Group = {}
    Group.__index = Group

    local function build(group, flag, method, opts)
        local card = cardFor(group.route)
        if not card then return setmetatable({}, Handle) end
        local ok, el = pcall(card[method], card, opts)
        if not ok then
            Util.note("compat row " .. tostring(flag or opts.name), "row " .. tostring(flag or opts.name) .. " failed:", el)
            return setmetatable({}, Handle)
        end
        return setmetatable({ el = el }, Handle)
    end

    function Group:AddToggle(flag, info)
        return build(self, flag, "Toggle", { name = info.Text, flag = flag, default = info.Default == true, tip = info.Tooltip, callback = info.Callback })
    end
    function Group:AddSlider(flag, info)
        local rounding = info.Rounding or 0
        local suffix = info.Suffix or ""
        local opts = { name = info.Text, flag = flag, min = info.Min, max = info.Max, default = info.Default, step = rounding > 0 and 10 ^ -rounding or 1,
            tip = info.Tooltip, callback = info.Callback }
        if suffix ~= "" then opts.fmt = function(value) return string.format("%." .. rounding .. "f", value) .. suffix end end
        return build(self, flag, "Slider", opts)
    end
    function Group:AddDropdown(flag, info)
        local default = info.Default
        if info.Multi then default = listOf(default) end
        local callback = info.Callback
        if callback and info.Multi then
            local inner = callback
            callback = function(value) inner(mapOf(value)) end
        end
        return build(self, flag, "Dropdown", { name = info.Text, flag = flag, options = info.Values or {}, multi = info.Multi == true, default = default,
            tip = info.Tooltip, callback = callback })
    end
    function Group:AddInput(flag, info)
        return build(self, flag, "Input", { name = info.Text, flag = flag, default = info.Default or "", placeholder = info.Placeholder, callback = info.Callback })
    end
    function Group:AddButton(text, callback)
        return build(self, nil, "Button", { name = text, callback = callback })
    end
    function Group:AddLabel(text)
        return build(self, nil, "Label", { name = text })
    end
    function Group:AddDivider()
        return build(self, nil, "Divider", {})
    end
    function Group:AddKeyPicker(flag, info)
        return self:AddLabel(info.Text or flag):AddKeyPicker(flag, info)
    end
    function Group:AddColorPicker(flag, info)
        return self:AddLabel(info.Title or flag):AddColorPicker(flag, info)
    end

    -- dev.lua's wrapper over the groupbox (Section:Toggle{Name, Flag, ...}); toRounding as in dev.lua
    local function rounding(decimals)
        if type(decimals) ~= "number" or decimals <= 0 or decimals >= 1 then return 0 end
        return math.clamp(math.floor(-math.log10(decimals) + 0.5), 0, 4)
    end
    function Group:Toggle(info)
        return self:AddToggle(info.Flag, { Text = info.Name, Default = info.Default, Tooltip = info.Tooltip, Callback = info.Callback })
    end
    function Group:Slider(info)
        self:AddSlider(info.Flag, { Text = info.Name, Min = info.Min, Max = info.Max, Default = math.clamp(info.Default or info.Min, info.Min, info.Max),
            Rounding = rounding(info.Decimals), Suffix = info.Suffix, Tooltip = info.Tooltip, Callback = info.Callback })
    end
    function Group:Dropdown(info)
        self:AddDropdown(info.Flag, { Text = info.Name, Values = info.Items, Default = info.Default, Multi = info.Multi, Tooltip = info.Tooltip, Callback = info.Callback })
    end
    function Group:Label(info)
        return self:AddLabel(info.Name)
    end
    function Group:Button(info)
        self:AddButton(info.Name, info.Callback)
    end
    function Group:Input(info)
        self:AddInput(info.Flag, { Text = info.Name, Default = info.Default, Placeholder = info.Placeholder, Callback = info.Callback })
    end

    local function subs(owner, names)
        local out = {}
        for _, name in ipairs(names) do
            local routes = ROUTES[owner][name]
            out[name] = {
                Section = function(_, info)
                    local route = routes[info.Name]
                    if not route then
                        Util.note("compat route " .. owner .. name .. info.Name, "no card for " .. owner .. "." .. name .. " / " .. info.Name .. ", using rage > other")
                        route = { "combat", "rage.other", string.lower(info.Name), "right" }
                    end
                    return setmetatable({ route = route }, Group)
                end,
            }
        end
        return out
    end

    -- dev.lua's Skin.CreateTargetInfo panel on Aster.Hud.Target
    local Skin = { Version = "pl2-compat" }
    local SHOWS = { Status = { "visible" }, Extra = { "weapon", "distance" } }
    function Skin.CreateTargetInfo()
        local hud = Aster.Hud and Aster.Hud.Target
        local panel = { Outer = { Parent = true }, Options = { Health = true, Status = true, Extra = true } }
        function panel:SetOption(name, on)
            self.Options[name] = on
            for _, key in ipairs(SHOWS[name] or {}) do
                if hud then hud:SetOption(key, on) end
            end
        end
        function panel:SetVisible(on)
            if not on and hud then hud:Clear() end
        end
        function panel:Update(info)
            if not hud then return end
            if not info then
                hud:Clear()
                return
            end
            local tool = info.Tool ~= "none" and info.Tool or nil
            if tool and info.Sight == "Wallbang" then tool = tool .. " (wallbang)" end
            hud:Set({
                player = { display = info.Display, name = info.Name, id = info.UserId, team = info.TeamColor },
                hp = info.Health, maxhp = info.MaxHealth, distance = info.Distance, weapon = tool,
                visible = info.Sight == "Visible", relation = Aster.Relations and Aster.Relations[info.Name] or nil,
            })
        end
        function panel:Destroy()
            self.Outer.Parent = nil
            if hud then hud:Clear() end
        end
        return panel
    end

    local byId = {}
    local RELATIONS = { friend = "Friendly", ignore = "Friendly", target = "Priority" }
    local Relations = setmetatable({}, { __index = function(_, userId)
        local player = byId[userId]
        if not (player and player.Parent == Players) then
            player = nil
            for _, other in ipairs(Players:GetPlayers()) do
                if other.UserId == userId then player = other break end
            end
            byId[userId] = player
        end
        return player and RELATIONS[Aster.Relations and Aster.Relations[player.Name]] or nil
    end })

    local Library = setmetatable({}, { __index = function(_, key)
        if key == "Toggled" then return win ~= nil and win.Visible == true end
        return nil
    end })
    function Library:Notify(text, seconds) Util.notify(text, "info", seconds) end
    function Library:OnUnload(fn) Util.onUnload(fn) end
    function Library:Toggle() if win then win:Toggle() end end

    local Actions = {
        previewHitEffect = noop, previewKillEffect = noop, packRig = noop, getWeapon = noop, getAllWeapons = noop, getItem = noop, getPlace = noop,
        kickOnce = noop, fxHook = noop, autoHook = noop, assistHook = noop, fireAt = function() return false end,
        sp = { assist = {}, shooter = function(root) return root.Position end, realPos = function(root) return root.Position end },
        area = function() return "outside" end,
    }
    Combat = Actions

    -- the old code files its Drawing objects here
    env.TS_Drawings = {}
    Util.onUnload(function()
        for _, drawing in ipairs(env.TS_Drawings or {}) do pcall(function() drawing:Remove() end) end
        env.TS_Drawings = {}
    end)

    Compat.legacy = {
        Library = Library, Skin = Skin, Options = lookup(false), Toggles = lookup(true),
        CombatSubs = subs("CombatSubs", { "Aim", "Silent", "Other" }),
        RageSubs = subs("RageSubs", { "Main", "Void", "Aim", "Other" }),
        WorldSubs = subs("WorldSubs", { "Indicators" }),
        -- fire / last stay unset (40_fx owns the shot effects), so the ammo-drop fallback in the combat block never calls anything
        Actions = Actions, ShotEvents = { shot = {}, hit = {}, cast = {}, kill = {} }, MiscActions = { clearCheats = noop },
        track = Util.track, onUnload = Util.onUnload, Relations = Relations,
    }
end
bootMark("compat", PL2BootT, 8, 13)

PL2BootT = PL2BootClock()
-- [src] 50_combat.lua
-- GENERATED by repo/_tools_pl2/extract_combat.js from repo/dev.lua. Do not edit: rerun the tool.
-- The marked blocks are dev.lua lines copied unchanged (Luau compound assignments included); 45_compat.lua provides `env`.
-- patches (repo/_tools_pl2/combat_patches.js): A1 A2 A3 A4 A5 A7 C1 C2 B2 B1 B3 D1 D2 T
do
Combat_init = function(env)
local Library, Skin, Options, Toggles, CombatSubs, RageSubs, WorldSubs, Actions, ShotEvents, MiscActions, track, onUnload, Relations = env.Library, env.Skin, env.Options, env.Toggles, env.CombatSubs, env.RageSubs, env.WorldSubs, env.Actions, env.ShotEvents, env.MiscActions, env.track, env.onUnload, env.Relations
-- dev.lua 1389-1391: fxKey
local function fxKey(text)
    return string.lower((string.gsub(tostring(text or ""), "[^%w]", "")))
end
-- dev.lua 1465-1465: noop
local function noop() end
-- dev.lua 1882-1887: readFlag
local function readFlag(name, default)
    local object = Toggles[name]
    if object == nil then object = Options[name] end
    if object == nil or object.Value == nil then return default end
    return object.Value
end
-- dev.lua 1890-1899: isEnemy
local function isEnemy(player)
    if not player or player == LocalPlayer then return false end
    local explicit = Relations[player.UserId]
    if explicit == "Friendly" then return false end
    if explicit == "Priority" then return true end
    local mine, theirs = LocalPlayer.Team, player.Team
    if not mine or not theirs then return true end
    if mine == theirs then return false end
    return true
end
-- dev.lua 1900-1904: relationOf
local function relationOf(player)
    local explicit = Relations[player.UserId]
    if explicit then return explicit end
    return isEnemy(player) and "Enemy" or "Friendly"
end
-- dev.lua 1906-1912: isPeaceful
local function isPeaceful(player)
    if not player or Relations[player.UserId] == "Priority" then return false end
    local team = player.Team
    if not team or team.Name ~= "Inmates" then return false end
    local char = player.Character
    return not (char and char:GetAttribute("Hostile") == true)
end
-- dev.lua 2155-2155: WHITE
local WHITE = Color3.fromRGB(255, 255, 255)
-- dev.lua 10096-10096: Camera
    local Camera = function() return workspace.CurrentCamera end
-- dev.lua 10097-10097: flag
    local flag = readFlag
-- dev.lua 10098-10098: clock
    local clock = os.clock
-- dev.lua 10099-10099: v3
    local v3, ZERO = Vector3.new, Vector3.zero
-- dev.lua 10102-10102: warnf
    local function warnf(...) warn("[Aster][Misc]", ...) end
-- dev.lua 10103-10103: say
    local function say(text) pcall(function() Library:Notify(text, 4) end) end
-- dev.lua 10105-10105: features
    local features = {}
-- dev.lua 10106-10108: feature
    local function feature(flagName, start, stop)
        features[#features + 1] = { flag = flagName, start = start, stop = stop or noop, active = false }
    end
-- dev.lua 10109-10114: setActive
    local function setActive(f, on)
        if on == f.active then return end
        f.active = on
        local ok, err = pcall(on and f.start or f.stop)
        if not ok then warnf(f.flag, on and "start failed:" or "stop failed:", err) end
    end
-- dev.lua 10115-10120: isOn
    local function isOn(flagName)
        for _, f in ipairs(features) do
            if f.flag == flagName then return f.active end
        end
        return false
    end
-- dev.lua 10121-10124: switchOff
    local function switchOff(flagName)
        local t = Toggles[flagName]
        if t and t.SetValue then pcall(function() t:SetValue(false) end) end
    end
-- dev.lua 10126-10134: newBag
    local function newBag()
        local bag, list = {}, {}
        function bag.add(connection) list[#list + 1] = connection return connection end
        function bag.clear()
            for _, c in ipairs(list) do pcall(function() c:Disconnect() end) end
            table.clear(list)
        end
        return bag
    end
-- dev.lua 10138-10144: localParts
    local function localParts()
        local char = LocalPlayer.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        local root = char:FindFirstChild("HumanoidRootPart")
        if hum and root and hum.Health > 0 then return char, hum, root end
    end
-- dev.lua 10146-10160: otherEntities
    local function scanEntities()
        local list = {}
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                local char = player.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                local root = char and char:FindFirstChild("HumanoidRootPart")
                local head = char and char:FindFirstChild("Head")
                if hum and root and head and hum.Health > 0 then
                    list[#list + 1] = { Player = player, Character = char, Humanoid = hum, Root = root, Head = head }
                end
            end
        end
        return list
    end
    local entityList, entityAt = {}, -1
    local function otherEntities()
        local now = clock()
        if now - entityAt > 0.003 then
            entityAt = now
            entityList = scanEntities()
        end
        return entityList
    end
-- dev.lua 10162-10162: typing
    local function typing() return UserInputService:GetFocusedTextBox() ~= nil end
-- dev.lua 10278-10278: queryHeld
    local queryHeld = {}
-- dev.lua 10279-10284: holdQuery
    local function holdQuery(part)
        local entry = queryHeld[part]
        if entry then entry.n += 1 return end
        queryHeld[part] = { n = 1, original = part.CanQuery }
        part.CanQuery = false
    end
-- dev.lua 10285-10293: releaseQuery
    local function releaseQuery(part)
        local entry = queryHeld[part]
        if not entry then return end
        entry.n -= 1
        if entry.n <= 0 then
            queryHeld[part] = nil
            pcall(function() part.CanQuery = entry.original end)
        end
    end
-- dev.lua 10295-10297: waitForCars
    local function waitForCars(timeout)
        return workspace:FindFirstChild("CarContainer") or workspace:WaitForChild("CarContainer", timeout or 5)
    end
-- dev.lua 10640-10644: equippedGun
    local function equippedGun()
        local char = LocalPlayer.Character
        local tool = char and char:FindFirstChildOfClass("Tool")
        if tool and tool:GetAttribute("FireRate") ~= nil then return tool end
    end
-- dev.lua 10646-10657: allTools
    local function allTools()
        local list = {}
        local char, pack = LocalPlayer.Character, LocalPlayer:FindFirstChildOfClass("Backpack")
        for _, holder in ipairs({ char, pack }) do
            if holder then
                for _, child in ipairs(holder:GetChildren()) do
                    if child:IsA("Tool") then list[#list + 1] = child end
                end
            end
        end
        return list
    end
-- dev.lua 2163-2428: menu: legit + rage rows, target info
do
    local Aim = CombatSubs.Aim:Section({ Name = "Aim assist", Side = 1 })
    local aimEnabled = Aim:Toggle({ Name = "Enabled", Flag = "Aim_Global_Enabled", Default = false })
    aimEnabled:Keybind({ Name = "Aim key", Flag = "Aim_Global_Key", Default = "MB2", Mode = "Hold" })
    Aim:Dropdown({ Name = "Method", Flag = "aim_method", Items = { "Camera", "Mouse" }, Default = "Camera" })
    Aim:Slider({ Name = "FOV", Flag = "aim_fov", Min = 10, Max = 800, Default = 120, Suffix = "px", Decimals = 1 })
    Aim:Toggle({ Name = "Dynamic FOV", Flag = "aim_dynamic", Default = false })
    Aim:Slider({ Name = "Dynamic FOV amount", Flag = "aim_dynamic_amount", Min = 0, Max = 100, Default = 50, Suffix = "%", Decimals = 1 })
    Aim:Dropdown({ Name = "Dynamic FOV mode", Flag = "aim_dynamic_mode", Items = { "Distance", "Cursor", "Both" }, Default = "Distance", Tooltip = "Distance: the FOV is largest on close players and shrinks with range. Cursor: once a target is near your cursor (or already locked) the FOV grows so you keep it. Both: both together" })
    Aim:Slider({ Name = "Near distance", Flag = "aim_dyn_near", Min = 5, Max = 150, Default = 25, Suffix = " studs", Decimals = 1, Tooltip = "At or below this distance the FOV is at its largest" })
    Aim:Slider({ Name = "Far distance", Flag = "aim_dyn_far", Min = 50, Max = 1500, Default = 300, Suffix = " studs", Decimals = 1, Tooltip = "At or beyond this distance the FOV is at its smallest" })
    Aim:Dropdown({ Name = "Target priority", Flag = "aim_target", Items = { "Crosshair", "Distance", "Lowest health" }, Default = "Crosshair" })
    Aim:Slider({ Name = "Stickiness", Flag = "aim_sticky", Min = 0, Max = 100, Default = 30, Suffix = "%", Decimals = 1, Tooltip = "Bonus for staying on the current target so it does not flicker between two players" })
    Aim:Toggle({ Name = "Only while shooting", Flag = "aim_only_shoot", Default = false, Tooltip = "The assist only moves your aim while you hold the fire button" })
    Aim:Toggle({ Name = "Prediction", Flag = "aim_pred", Default = false, Tooltip = "Aims slightly ahead of moving players, from their tracked speed and your ping" })
    Aim:Slider({ Name = "Prediction strength", Flag = "aim_pred_mult", Min = 0, Max = 2, Default = 0.7, Suffix = "x", Decimals = 0.1 })
    Aim:Slider({ Name = "Miss chance", Flag = "aim_miss", Min = 0, Max = 60, Default = 0, Suffix = "%", Decimals = 1, Tooltip = "Now and then the assist aims a little off the target, like a real player" })
    Aim:Slider({ Name = "Miss size", Flag = "aim_miss_size", Min = 0.5, Max = 6, Default = 2.5, Suffix = " studs", Decimals = 0.1 })
    Aim:Toggle({ Name = "Lock target", Flag = "aim_lock", Default = false })
    Aim:Dropdown({ Name = "Hitscan priority", Flag = "aim_priority", Items = { "Closest", "Head", "Body" }, Default = "Closest" })
    Aim:Dropdown({ Name = "Hitscan points", Flag = "aim_points", Items = { "Head", "Torso", "Lower torso", "Root", "Left arm", "Right arm", "Left leg", "Right leg" }, Multi = true, Default = { "Head", "Torso" }, Tooltip = "Every hitbox the target can be aimed at. Arms and legs cover all R6 and R15 limb parts, Torso covers Torso and UpperTorso, Root is the HumanoidRootPart" })
    Aim:Toggle({ Name = "Multipoint", Flag = "aim_multipoint", Default = false, Tooltip = "Also scans points on the edges of each hitbox and aims at the one closest to your crosshair (and visible, with wall check on)" })
    Aim:Slider({ Name = "Point spread", Flag = "aim_mp_scale", Min = 10, Max = 100, Default = 70, Suffix = "%", Decimals = 1, Tooltip = "How far from the center of a hitbox the edge points are. Lower stays safely inside the hitbox" })
    Aim:Slider({ Name = "Reaction time", Flag = "aim_reaction", Min = 0, Max = 500, Default = 0, Suffix = "ms", Decimals = 1 })
    Aim:Slider({ Name = "Max distance", Flag = "aim_max_dist", Min = 50, Max = 2000, Default = 1000, Suffix = " studs", Decimals = 1 })

    local Smooth = CombatSubs.Aim:Section({ Name = "Aim smoothing", Side = 1 })
    Smooth:Toggle({ Name = "Smoothing", Flag = "aim_smooth", Default = true })
    Smooth:Slider({ Name = "Start", Flag = "aim_smooth_start", Min = 0, Max = 99, Default = 85, Suffix = "%", Decimals = 1 })
    Smooth:Slider({ Name = "End", Flag = "aim_smooth_end", Min = 0, Max = 99, Default = 20, Suffix = "%", Decimals = 1 })
    Smooth:Slider({ Name = "Increment", Flag = "aim_smooth_inc", Min = 0, Max = 200, Default = 50, Suffix = "%/s", Decimals = 1 })
    Smooth:Slider({ Name = "Randomization", Flag = "aim_smooth_rand", Min = 0, Max = 50, Default = 5, Suffix = "%", Decimals = 1 })
    Smooth:Toggle({ Name = "Humanize", Flag = "aim_human", Default = false, Tooltip = "Curved path, a small overshoot that corrects itself, slower fine adjustments and tiny jitter. It also lets go while you flick your own mouse" })
    Smooth:Slider({ Name = "Curve", Flag = "aim_curve", Min = 0, Max = 60, Default = 20, Suffix = "%", Decimals = 1 })
    Smooth:Slider({ Name = "Overshoot", Flag = "aim_over", Min = 0, Max = 60, Default = 15, Suffix = "%", Decimals = 1 })
    Smooth:Slider({ Name = "Jitter", Flag = "aim_jitter", Min = 0, Max = 6, Default = 1.5, Suffix = "px", Decimals = 0.1 })
    Smooth:Slider({ Name = "Flick release", Flag = "aim_flick", Min = 0, Max = 200, Default = 80, Suffix = "px", Decimals = 1, Tooltip = "Camera method only. The assist pauses for a moment when your own mouse moves more than this in one frame. 0 turns it off" })

    local Trigger = CombatSubs.Aim:Section({ Name = "Triggerbot", Side = 2 })
    local triggerEnabled = Trigger:Toggle({ Name = "Enabled", Flag = "Trigger_Global_Enabled", Default = false })
    triggerEnabled:Keybind({ Name = "Trigger key", Flag = "Trigger_Global_Key", Default = "None", Mode = "Always" })
    Trigger:Dropdown({ Name = "Hit part", Flag = "Trigger_Global_HitPart", Items = { "Head", "Torso", "Any" }, Default = "Head" })
    Trigger:Slider({ Name = "Delay", Flag = "Trigger_Global_Delay", Min = 0, Max = 300, Default = 40, Suffix = "ms", Decimals = 1 })
    Trigger:Slider({ Name = "Reaction time", Flag = "Trigger_Global_Reaction", Min = 0, Max = 200, Default = 0, Suffix = "ms", Decimals = 1 })
    Trigger:Toggle({ Name = "Magnet", Flag = "trigger_magnet", Default = false, Tooltip = "While the trigger key is held, the aim assist (its FOV, hitscan, smoothing and method settings) pulls onto the target as well, and the triggerbot fires once the crosshair is on it. Set the trigger key mode to Hold so it only works while held. The aim assist toggle itself can stay off." })
    Trigger:Slider({ Name = "Burst shots", Flag = "trigger_burst", Min = 0, Max = 10, Default = 0, Suffix = " shots", Decimals = 1, Tooltip = "Fires this many shots, then pauses. 0 means no bursts" })
    Trigger:Slider({ Name = "Burst pause", Flag = "trigger_burst_pause", Min = 50, Max = 1000, Default = 250, Suffix = "ms", Decimals = 1 })
    Trigger:Slider({ Name = "Magnet strength", Flag = "trigger_magnet_str", Min = 10, Max = 100, Default = 100, Suffix = "%", Decimals = 1, Tooltip = "How hard the magnet pulls when only the trigger key is held" })
    Trigger:Slider({ Name = "Magnet FOV", Flag = "trigger_magnet_fov", Min = 0, Max = 400, Default = 0, Suffix = "px", Decimals = 1, Tooltip = "FOV used by the magnet. 0 uses the aim assist FOV" })
    Trigger:Toggle({ Name = "Team check", Flag = "trigger_team", Default = false })
    Trigger:Toggle({ Name = "Forcefield check", Flag = "trigger_ff", Default = false })
    Trigger:Toggle({ Name = "Hostile only (inmates)", Flag = "trigger_hostile", Default = false })

    do
        local RB = RageSubs.Main:Section({ Name = "Ragebot", Side = 1 })
        RB:Toggle({ Name = "Enabled", Flag = "rb_enabled", Default = false, Tooltip = "Hides in the void, comes out next to the target, shoots and goes back" }):Keybind({ Name = "Ragebot key", Flag = "rb_key", Default = "None", Sync = true })
        RB:Dropdown({ Name = "Weapons", Flag = "rb_weapons", Items = { "AK-47", "M4A1", "MP5", "FAL", "Remington 870", "M700", "M9", "Revolver" }, Multi = true, Default = {}, Tooltip = "The ragebot cycles through these weapons while it shoots and equips them for you. Nothing selected keeps whatever you hold" })
        RB:Slider({ Name = "Weapon switch delay", Flag = "rb_switch_delay", Min = 0.05, Max = 2, Default = 0.15, Suffix = "s", Decimals = 0.01, Tooltip = "How long each weapon is held before the next one. An empty or reloading weapon is swapped out at once" })
        RB:Dropdown({ Name = "Autoget weapons", Flag = "rb_autoget", Items = { "AK-47", "Remington 870", "MP5", "M700", "M4A1", "FAL" }, Multi = true, Default = {}, Tooltip = "Picks these weapons up from their spawns whenever you do not have them, also after you respawn. The ragebot pauses while you fetch one" })
        RB:Dropdown({ Name = "Settings", Flag = "rb_settings", Items = { "View target", "Show server position", "Random peek spot" }, Multi = true, Default = {}, Tooltip = "View target: the camera follows the target. Show server position: a highlighted copy of you shows where the server sees you. Random peek spot: a new random spot around the target for every shot" })
        RB:Dropdown({ Name = "Hit part", Flag = "rb_part", Items = { "Head", "Torso", "Random" }, Default = "Head" })
        RB:Slider({ Name = "Shots per second", Flag = "rb_rate", Min = 1, Max = 30, Default = 12, Suffix = "/s", Decimals = 1 })
        RB:Slider({ Name = "Shot delay after peeking", Flag = "rb_shot_delay", Min = 0, Max = 0.3, Default = 0.03, Suffix = "s", Decimals = 0.01, Tooltip = "How long you stand at the peek spot before the first shot, so the server has your new position" })
        RB:Toggle({ Name = "Auto weapon by distance", Flag = "rb_aw", Default = false, Tooltip = "Uses the Remington 870 up close, the M700 far away and your other selected weapons in between. Needs those weapons in the Weapons list" })
        RB:Slider({ Name = "Shotgun below", Flag = "rb_aw_close", Min = 10, Max = 120, Default = 45, Suffix = " studs", Decimals = 1 })
        RB:Slider({ Name = "Sniper above", Flag = "rb_aw_far", Min = 100, Max = 800, Default = 250, Suffix = " studs", Decimals = 1 })
        RB:Toggle({ Name = "Wallbang", Flag = "rb_wallbang", Default = true, Tooltip = "Shots from the ragebot use the wallbang methods from the Gun tab, so they hit through walls and cover" })
        RB:Toggle({ Name = "Auto reload", Flag = "rb_reload", Default = false, Tooltip = "Reloads when the gun is empty. With void spam on you stay hidden while it reloads" })

        local RTR = RageSubs.Main:Section({ Name = "Target rules", Side = 1 })
        RTR:Slider({ Name = "Max distance", Flag = "rb_range", Min = 50, Max = 20000, Default = 2000, Suffix = " studs", Decimals = 1 })
        RTR:Toggle({ Name = "Swap targets", Flag = "rb_swap", Default = false, Tooltip = "Moves on to the next player when the current one takes no damage for the time below" })
        RTR:Slider({ Name = "Swap after", Flag = "rb_swap_time", Min = 1, Max = 30, Default = 4, Suffix = "s", Decimals = 0.5 })
        RTR:Toggle({ Name = "Skip forcefield targets", Flag = "rb_ff", Default = false, Tooltip = "Picks another target while one has a forcefield. Off: you stay hidden in the void until the forcefield is gone" })
        RTR:Toggle({ Name = "Ignore tased and arrested", Flag = "rb_down", Default = false })
        RTR:Toggle({ Name = "Ignore friendly team", Flag = "rb_team", Default = false })
        RTR:Toggle({ Name = "Hostile only (inmates)", Flag = "rb_hostile", Default = false })
        RTR:Toggle({ Name = "Skip targets that take no damage", Flag = "rb_skip_nodmg", Default = true, Tooltip = "Skips players the game deals no damage to: your own team, and inmates who are not hostile while you are a guard. A target with a forcefield is only picked when nobody else can be shot" })
        RTR:Toggle({ Name = "Deprioritise forcefield targets", Flag = "rb_ff_deprio", Default = true, Tooltip = "A target with a forcefield is picked last instead of making the ragebot wait for it while other listed targets can be shot. A single listed target is still waited for" })

        local RT = RageSubs.Main:Section({ Name = "Target", Side = 2 })
        RT:Toggle({ Name = "Add target to list", Flag = "rb_add", Default = false, Tooltip = "Press the key to add the player closest to your cursor to the target list. Press again on the same player to remove them" }):Keybind({ Name = "Add target key", Flag = "rb_add_key", Default = "G", Sync = false })
        RT:Dropdown({ Name = "Mode", Flag = "rb_tmode", Items = { "Target list", "Players tab" }, Default = "Target list", Tooltip = "Target list: only the players in the list below, nobody else. Players tab: only the player selected in the Players tab" })
        local names = {}
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then names[#names + 1] = player.Name end
        end
        table.sort(names, function(a, b) return a:lower() < b:lower() end)
        RT:Dropdown({ Name = "Targets", Flag = "rb_targets", Items = names, Multi = true, Default = {}, Tooltip = "Used by the Target list mode" })
        RT:Dropdown({ Name = "Whitelist", Flag = "rb_white", Items = names, Multi = true, Default = {}, Tooltip = "These players are never targeted" })
        Actions.rageResult = RT:Label({ Name = "Result: none" })
        RT:Input({ Name = "Player search", Flag = "rb_search", Default = "", Placeholder = "name or display name", Tooltip = "The buttons below use this player. Empty uses the player selected in the Players tab" })
        RT:Button({ Name = "Target player", Callback = function() if Actions.rageList then Actions.rageList("rb_targets", true) end end })
        RT:Button({ Name = "Whitelist player", Callback = function() if Actions.rageList then Actions.rageList("rb_white", true) end end })
        RT:Button({ Name = "Clear targets", Callback = function() if Actions.rageList then Actions.rageList("rb_targets", false) end end })
        RT:Button({ Name = "Clear whitelist", Callback = function() if Actions.rageList then Actions.rageList("rb_white", false) end end })

        local RS = RageSubs.Main:Section({ Name = "Status and safety", Side = 2 })
        RS:Toggle({ Name = "Hit feedback", Flag = "rb_feedback", Default = true, Tooltip = "The status text also shows hits, misses and why the last shot missed" })
        RS:Toggle({ Name = "Auto tune", Flag = "rb_autotune", Default = false, Tooltip = "After a few misses in a row it stays longer at the peek spot, waits longer before shooting and leads more. It relaxes again after hits" })
        RS:Toggle({ Name = "Show status", Flag = "rb_status", Default = false, Tooltip = "A line of text at the top of the screen with what the ragebot is doing" })
        RS:Slider({ Name = "Status offset", Flag = "rb_status_y", Min = -300, Max = 300, Default = 40, Suffix = "px", Decimals = 1, Tooltip = "Vertical distance of the status text from the middle of the screen" })
        RS:Toggle({ Name = "Safe mode", Flag = "rb_safe", Default = false, Tooltip = "Below the health percentage you stay hidden (or at home when void spam is off) until you healed" })
        RS:Slider({ Name = "Safe mode health", Flag = "rb_safe_hp", Min = 5, Max = 90, Default = 20, Suffix = "%", Decimals = 1 })
        RS:Toggle({ Name = "Shot log", Flag = "rb_shotlog", Default = false, Tooltip = "Records for every ragebot shot whether the server took the ammo, the damage, the part and the distance. The last result shows below" })
        Actions.shotLogLabel = RS:Label({ Name = "Shots: log off" })

        Actions.rageNames = names

        local RV = RageSubs.Void:Section({ Name = "Void spam", Side = 1 })
        RV:Toggle({ Name = "Void spam", Flag = "rb_void", Default = false, Tooltip = "Switches between a hiding spot far outside the map and the peek spot" }):Keybind({ Name = "Void key", Flag = "rb_void_key", Default = "None", Mode = "Hold" })
        RV:Dropdown({ Name = "When", Flag = "rb_void_when", Items = { "While targeting", "While reloading", "Smart", "Always" }, Default = "While targeting", Tooltip = "While targeting: hide between peeks the whole time. While reloading: hide only to reload. Smart: peek normally and hide for a while when the target stops taking damage. Always: also hides without a target" })
        RV:Toggle({ Name = "Show void location", Flag = "rb_void_show", Default = false, Tooltip = "A marker, a line and a distance text show where your hiding spot is" }):Colorpicker({ Name = "Void marker", Flag = "rb_void_color", Default = Color3.fromRGB(255, 80, 80), Alpha = 0 })
        RV:Slider({ Name = "In void", Flag = "rb_in_time", Min = 0.05, Max = 3, Default = 0.35, Suffix = "s", Decimals = 0.01 })
        RV:Toggle({ Name = "Wait in void", Flag = "rb_wait_void", Default = false, Tooltip = "With void spam on, you stay hidden in the void while there is no target, for example after a kill, instead of waiting in the map" })
        RV:Slider({ Name = "Out of void", Flag = "rb_out_time", Min = 0.05, Max = 2, Default = 0.2, Suffix = "s", Decimals = 0.01 })

        local RVS = RageSubs.Void:Section({ Name = "Void safety", Side = 1 })
        RVS:Toggle({ Name = "Avoid kill bricks", Flag = "rb_void_safe", Default = true, Tooltip = "Void spots inside or near kill parts are skipped. Parts are found by name, and a spot you died at in the void is avoided from then on" })
        RVS:Slider({ Name = "Safe margin", Flag = "rb_void_safe_margin", Min = 2, Max = 60, Default = 12, Suffix = " studs", Decimals = 1 })
        RVS:Input({ Name = "Kill part names", Flag = "rb_void_safe_names", Default = "kill,lava,death,deadly,acid,hurt,damage,toxic,spike,laser", Placeholder = "words separated by commas", Tooltip = "A part whose name or parent name contains one of these words counts as a kill brick" })

        local RVP = RageSubs.Void:Section({ Name = "Void pattern", Side = 1 })
        RVP:Slider({ Name = "Smart wait", Flag = "rb_smart_wait", Min = 1, Max = 30, Default = 8, Suffix = "s", Decimals = 0.5 })
        RVP:Slider({ Name = "Smart void time", Flag = "rb_smart_void", Min = 1, Max = 30, Default = 5, Suffix = "s", Decimals = 0.5 })
        RVP:Dropdown({ Name = "Pattern", Flag = "rb_pattern", Items = { "Under map", "Map edge", "High", "Far", "Extreme" }, Default = "Under map", Tooltip = "Map edge circles the outer edge of the whole map, so you are hard to target and players can run into kill planes chasing you. Under map hides just above the point where the engine destroys parts, below your real position, the same spot the Void desync uses. High, Far and Extreme are far above or beside the map and can be killed by the game's kill planes" })
        RVP:Slider({ Name = "Under map radius", Flag = "rb_under_radius", Min = 10, Max = 1500, Default = 250, Suffix = " studs", Decimals = 1, Tooltip = "Under map only: every position change teleports you to a random spot this far around you, underneath the map" })
        RVP:Slider({ Name = "Edge jump", Flag = "rb_edge_jump", Min = 0, Max = 3000, Default = 0, Suffix = " studs", Decimals = 10, Tooltip = "Map edge only: every position change teleports you along the edge. 0 jumps to a random spot on the edge, above 0 moves that many studs further around each time" })
        RVP:Slider({ Name = "Edge margin", Flag = "rb_edge_margin", Min = -100, Max = 400, Default = 25, Suffix = " studs", Decimals = 1, Tooltip = "Map edge only: distance outside the outermost map part. Negative goes inside it" })
        RVP:Slider({ Name = "Edge height", Flag = "rb_edge_y", Min = -250, Max = 250, Default = 0, Suffix = " studs", Decimals = 1, Tooltip = "Map edge only: height relative to you. It never goes below the point where parts are destroyed" })
        RVP:Dropdown({ Name = "Direction", Flag = "rb_dir", Items = { "+Y", "+X", "+Z" }, Multi = true, Default = { "+Y" }, Tooltip = "Every position change picks one of the selected directions at random. Does not affect the Under map pattern" })
        RVP:Slider({ Name = "Depth multiplier", Flag = "rb_depth", Min = 0.1, Max = 5, Default = 1, Suffix = "x", Decimals = 0.1 })
        RVP:Slider({ Name = "Position change interval", Flag = "rb_switch", Min = 0.01, Max = 1, Default = 0.05, Suffix = "s", Decimals = 0.01 })

        local VH = RageSubs.Void:Section({ Name = "Void hide", Side = 2 })
        VH:Toggle({ Name = "Void hide", Flag = "vh_enabled", Default = false, Tooltip = "Hides your server position in the void without the ragebot. Uses the pattern, interval and depth settings of this tab. The status text shows why you are in the void" }):Keybind({ Name = "Void key", Flag = "vh_key", Default = "None", Mode = "Hold" })
        VH:Dropdown({ Name = "Hide when", Flag = "vh_when", Items = { "Always", "Keybind", "Low health", "While reloading" }, Default = "Always", Tooltip = "Keybind: you are only in the void while the Void key is held (or toggled, depending on its mode)" })
        VH:Slider({ Name = "Low health", Flag = "vh_hp", Min = 5, Max = 95, Default = 35, Suffix = "%", Decimals = 1, Tooltip = "Low health only: hide below this health, come back once you healed 25% more" })

        local RP = RageSubs.Void:Section({ Name = "Peek spot", Side = 2 })
        RP:Dropdown({ Name = "Position", Flag = "rb_peek_mode", Items = { "Behind", "Front", "Left", "Right", "Side swap", "Swing", "Above", "Random", "Spiral" }, Default = "Behind", Tooltip = "Where you appear next to the target. Side swap alternates left and right every peek, Swing sways behind the target, Spiral circles it" })
        RP:Toggle({ Name = "Peek memory", Flag = "rb_peek_memory", Default = true, Tooltip = "Skips spots that missed twice in a row and, in Random and Spiral, comes back to the spot that hit last" })
        RP:Slider({ Name = "Distance", Flag = "rb_peek_dist", Min = 1, Max = 40, Default = 6, Suffix = " studs", Decimals = 0.5 })
        RP:Slider({ Name = "Height offset", Flag = "rb_peek_height", Min = -6, Max = 20, Default = 2, Suffix = " studs", Decimals = 0.5 })
        RP:Slider({ Name = "Spiral / swing speed", Flag = "rb_spiral_speed", Min = 0.5, Max = 30, Default = 6, Suffix = " rad/s", Decimals = 0.5 })
        RP:Dropdown({ Name = "Line of sight check", Flag = "rb_los", Items = { "Off", "Visible only" }, Default = "Off", Tooltip = "Visible only searches around the target for a spot with a clear line to the head and stays hidden when there is none" })

        local RR = RageSubs.Aim:Section({ Name = "Prediction and resolver", Side = 1 })
        RR:Toggle({ Name = "Prediction", Flag = "rb_pred", Default = false, Tooltip = "Aims ahead of a moving target" })
        RR:Slider({ Name = "Lead adjust", Flag = "rb_pred_extra", Min = 0, Max = 0.2, Default = 0.02, Suffix = "s", Decimals = 0.01, Tooltip = "Added to the lead time, which is worked out from your ping and the target speed" })
        RR:Slider({ Name = "Max lead", Flag = "rb_pred_cap", Min = 5, Max = 80, Default = 25, Suffix = " studs", Decimals = 1, Tooltip = "The aim point never moves further than this from the target" })
        RR:Toggle({ Name = "Landing check", Flag = "rb_pred_check", Default = true, Tooltip = "Checks that the predicted point is in range, not inside a wall and reachable. Otherwise the shot aims at the current position" })
        RR:Toggle({ Name = "Resolver", Flag = "rb_res", Default = false, Tooltip = "A target that hides outside the map is aimed at where it was last inside the map. Without it, hidden targets are skipped" })
    end

    local Wall = RageSubs.Aim:Section({ Name = "Wallbang", Side = 2 })
    Wall:Toggle({ Name = "Wallbang", Flag = "silent_wallbang", Default = false })
    Wall:Dropdown({
        Name = "Method", Flag = "wb_method", Items = { "Vape V4", "Aster Origin", "Aster Reach", "Aster Precise" }, Default = "Aster Reach",
        Tooltip = "Vape V4: Vape's origin scan, works best when you stand near a wall.\nAster Origin: scans more origins around you and tries the closest ones first (a bit better than Vape V4).\nAster Reach: reaches through more walls (origins up to twice the scan radius) but can be inaccurate sometimes.\nAster Precise: works out origins along the line to the target, closest first, and only widens the search when it has to.",
    })
    Wall:Toggle({ Name = "Use hitbox", Flag = "wb_hitbox", Default = true, Tooltip = "Also aim at points beside the target's body, not only at the part itself" })
    Wall:Slider({ Name = "Scan radius", Flag = "wb_radius", Min = 1, Max = 10, Default = 6, Suffix = " studs", Decimals = 0.1 })
    Wall:Toggle({ Name = "Damage check", Flag = "wb_damage", Default = true, Tooltip = "Only uses a shot origin and hit point that can deal damage: close enough to you and to the target's body, and inside the gun's range. The indicator, auto fire and assist use the same check." })
    Wall:Slider({ Name = "Max spot distance", Flag = "wb_spot", Min = 5, Max = 20, Default = 7.5, Suffix = " studs", Decimals = 0.1 })

    local Assist = RageSubs.Aim:Section({ Name = "Wallbang assist", Side = 2 })
    local assistToggle = Assist:Toggle({ Name = "Wallbang assist", Flag = "wb_assist", Default = false, Tooltip = "Works on anyone near your cursor, no silent aim needed. If an enemy is behind a wall, it moves the position the server sees up to (or into) the wall so the shot has a line, and sends the shot at that enemy." })
    assistToggle:Keybind({ Name = "Assist key", Flag = "wb_assist_key", Default = "None", Sync = true })
    Assist:Dropdown({ Name = "Move method", Flag = "wb_assist_method", Items = { "Server position", "Velocity" }, Default = "Server position", Tooltip = "Server position: only what the server sees moves (writes the character CFrame). Velocity: you really move there with physics (no CFrame writes) and walls next to you stop colliding on the way, then you return. The visualizer only applies to Server position." })
    Assist:Dropdown({ Name = "Mode", Flag = "wb_assist_mode", Items = { "Tween", "Teleport" }, Default = "Tween", Tooltip = "Tween moves at the speed below. Teleport jumps (Server position) or moves at 120 studs/s (Velocity)." })
    Assist:Toggle({ Name = "Inside wall", Flag = "wb_assist_inside", Default = false })
    Assist:Toggle({ Name = "Only while firing", Flag = "wb_assist_fire", Default = false, Tooltip = "Only moves while the fire button is held or auto fire is shooting" })
    Assist:Slider({ Name = "Assist FOV", Flag = "wb_assist_fov", Min = 10, Max = 800, Default = 250, Suffix = "px", Decimals = 1 })
    Assist:Slider({ Name = "Activation distance", Flag = "wb_assist_dist", Min = 1, Max = 45, Default = 25, Suffix = " studs", Decimals = 1 })
    Assist:Slider({ Name = "Tween speed", Flag = "wb_assist_speed", Min = 1, Max = 200, Default = 50, Suffix = " studs/s", Decimals = 1 })
    Assist:Slider({ Name = "Max target distance", Flag = "wb_assist_max", Min = 10, Max = 5000, Default = 200, Suffix = " studs", Decimals = 1 })
    local assistVisual = Assist:Toggle({ Name = "Visualizer", Flag = "wb_assist_visual", Default = false, Tooltip = "A highlighted copy of your character shows where the server sees you" })
    assistVisual:Colorpicker({ Name = "Fill", Flag = "wb_assist_fill", Default = Color3.fromRGB(255, 255, 255), Alpha = 0.6 })
    assistVisual:Colorpicker({ Name = "Outline", Flag = "wb_assist_line", Default = Color3.fromRGB(255, 255, 255), Alpha = 0 })

    local Silent = CombatSubs.Silent:Section({ Name = "Silent aim", Side = 1 })
    local silentEnabled = Silent:Toggle({ Name = "Enabled", Flag = "Silent_Global_Enabled", Default = false })
    silentEnabled:Keybind({ Name = "Silent key", Flag = "Silent_Global_Key", Default = "None", Mode = "Always" })
    Silent:Slider({ Name = "FOV", Flag = "silent_fov", Min = 10, Max = 800, Default = 150, Suffix = "px", Decimals = 1 })
    Silent:Toggle({ Name = "Dynamic FOV", Flag = "silent_dynamic", Default = false })
    Silent:Slider({ Name = "Dynamic FOV amount", Flag = "silent_dynamic_amount", Min = 0, Max = 100, Default = 50, Suffix = "%", Decimals = 1 })
    Silent:Dropdown({ Name = "Hitscan priority", Flag = "silent_priority", Items = { "Closest", "Head", "Body" }, Default = "Head" })
    Silent:Dropdown({ Name = "Hitscan points", Flag = "silent_points", Items = { "Head", "Torso", "Lower torso", "Root", "Left arm", "Right arm", "Left leg", "Right leg" }, Multi = true, Default = { "Head", "Torso" }, Tooltip = "Every hitbox the target can be aimed at. Arms and legs cover all R6 and R15 limb parts, Torso covers Torso and UpperTorso, Root is the HumanoidRootPart" })
    Silent:Toggle({ Name = "Multipoint", Flag = "silent_multipoint", Default = false, Tooltip = "Also scans points on the edges of each hitbox and aims at the one closest to your crosshair (and visible, with wall check on)" })
    Silent:Slider({ Name = "Point spread", Flag = "silent_mp_scale", Min = 10, Max = 100, Default = 70, Suffix = "%", Decimals = 1, Tooltip = "How far from the center of a hitbox the edge points are. Lower stays safely inside the hitbox" })
    Silent:Slider({ Name = "Hit chance", Flag = "Silent_Global_HitChance", Min = 1, Max = 100, Default = 100, Suffix = "%", Decimals = 1 })
    Silent:Slider({ Name = "Max distance", Flag = "silent_max_dist", Min = 50, Max = 2000, Default = 1000, Suffix = " studs", Decimals = 1 })

    local SilentChk = CombatSubs.Silent:Section({ Name = "Silent checks", Side = 1 })
    SilentChk:Toggle({ Name = "Wall check", Flag = "silent_wall", Default = false })
    SilentChk:Toggle({ Name = "Forcefield check", Flag = "silent_ff", Default = false })
    SilentChk:Toggle({ Name = "Hostile only (inmates)", Flag = "silent_hostile", Default = false })
    SilentChk:Toggle({ Name = "Team check", Flag = "silent_team", Default = false })
    SilentChk:Toggle({ Name = "Ignore tased / arrested", Flag = "silent_ignore_down", Default = false })

    local SilentPred = CombatSubs.Silent:Section({ Name = "Silent prediction", Side = 1 })
    SilentPred:Toggle({ Name = "Prediction", Flag = "silent_pred", Default = false, Tooltip = "Silent shots aim where the target will be when the shot arrives, from its tracked speed and your ping" })
    SilentPred:Toggle({ Name = "Auto time", Flag = "silent_pred_auto", Default = true })
    SilentPred:Slider({ Name = "Extra time", Flag = "silent_pred_extra", Min = 0, Max = 0.2, Default = 0.02, Suffix = "s", Decimals = 0.01 })
    SilentPred:Slider({ Name = "Base time", Flag = "silent_pred_base", Min = 0, Max = 0.5, Default = 0.07, Suffix = "s", Decimals = 0.01, Tooltip = "Manual lead time, only used with Auto time off" })
    SilentPred:Slider({ Name = "Multiplier", Flag = "silent_pred_mult", Min = 0, Max = 5, Default = 1, Suffix = "x", Decimals = 0.1 })
    SilentPred:Slider({ Name = "Max lead", Flag = "silent_pred_cap", Min = 5, Max = 80, Default = 25, Suffix = " studs", Decimals = 1 })
    SilentPred:Toggle({ Name = "Landing check", Flag = "silent_pred_check", Default = true, Tooltip = "Falls back to the current position when the predicted point is out of range, in a wall or not reachable" })
    SilentPred:Slider({ Name = "Erratic limit", Flag = "silent_pred_erratic", Min = 10, Max = 150, Default = 45, Suffix = " studs/s", Decimals = 1 })

    local FovAim = CombatSubs.Aim:Section({ Name = "Aim FOV", Side = 2 })
    local FovSilent = CombatSubs.Silent:Section({ Name = "Silent FOV", Side = 2 })
    local aimCircle = FovAim:Toggle({ Name = "Show FOV circle", Flag = "aim_fov_show", Default = false })
    aimCircle:Colorpicker({ Name = "Color", Flag = "aim_fov_color", Default = Color3.new(1, 1, 1), Alpha = true })
    FovAim:Toggle({ Name = "Filled", Flag = "aim_fov_filled", Default = false })
    FovAim:Slider({ Name = "Thickness", Flag = "aim_fov_thick", Min = 1, Max = 5, Default = 1, Decimals = 1 })

    local AimChk = CombatSubs.Aim:Section({ Name = "Aim checks", Side = 2 })
    AimChk:Toggle({ Name = "Team check", Flag = "aim_team", Default = false })
    AimChk:Toggle({ Name = "Wall check", Flag = "aim_wall", Default = false })
    AimChk:Toggle({ Name = "Forcefield check", Flag = "aim_ff", Default = false })
    AimChk:Toggle({ Name = "Hostile only (inmates)", Flag = "aim_hostile", Default = false })
    AimChk:Toggle({ Name = "Ignore tased / arrested", Flag = "aim_ignore_down", Default = false })
    local silentCircle = FovSilent:Toggle({ Name = "Show FOV circle", Flag = "silent_fov_show", Default = false })
    silentCircle:Colorpicker({ Name = "Color", Flag = "silent_fov_color", Default = Color3.fromRGB(255, 120, 120), Alpha = true })
    FovSilent:Toggle({ Name = "Filled", Flag = "silent_fov_filled", Default = false })
    FovSilent:Slider({ Name = "Thickness", Flag = "silent_fov_thick", Min = 1, Max = 5, Default = 1, Decimals = 1 })

    local AutoFire = CombatSubs.Silent:Section({ Name = "Auto fire", Side = 2 })
    AutoFire:Toggle({ Name = "Auto fire", Flag = "silent_autofire", Default = false })
    AutoFire:Slider({ Name = "Auto fire rate", Flag = "silent_autofire_rate", Min = 1, Max = 60, Default = 15, Suffix = " hz", Decimals = 1 })
    AutoFire:Toggle({ Name = "Auto fire: skip blocked", Flag = "silent_autofire_check", Default = true, Tooltip = "With wallbang on, auto fire only shoots targets you can see or wallbang" })

    local Switch = CombatSubs.Silent:Section({ Name = "Weapon switching", Side = 2 })
    Switch:Toggle({ Name = "Auto switch", Flag = "silent_switch", Default = false, Tooltip = "While auto fire has a target, switches between the weapons picked below. Weapons you do not have are skipped, and so are empty ones when another is ready" })
    Switch:Dropdown({ Name = "Switch weapons", Flag = "silent_switch_weapons", Items = { "AK-47", "M4A1", "MP5", "FAL", "Remington 870", "M700", "M9", "Revolver", "Taser" }, Multi = true, Default = {}, Tooltip = "The weapons to cycle through, in this order" })
    Switch:Slider({ Name = "Switch delay", Flag = "silent_switch_delay", Min = 0.03, Max = 2, Default = 0.3, Suffix = " s", Decimals = 0.01, Tooltip = "Time between weapon switches" })

    local OrbitSec = RageSubs.Other:Section({ Name = "Orbit target", Side = 2 })
    OrbitSec:Toggle({ Name = "Orbit target", Flag = "orbit_on", Default = false, Tooltip = "While silent aim has a target, the position the server sees circles that player. You stay where you are, only the server position moves." }):Keybind({ Name = "Orbit key", Flag = "orbit_key", Default = "None", Sync = true })
    OrbitSec:Dropdown({ Name = "Height", Flag = "orbit_mode", Items = { "Under the map", "Below target", "Near void" }, Default = "Under the map", Tooltip = "Under the map: below the lowest floor under the target. Below target: straight below the target's height. Near void: just above the void." })
    OrbitSec:Slider({ Name = "Depth", Flag = "orbit_depth", Min = 0, Max = 500, Default = 15, Suffix = " studs", Decimals = 0.5, Tooltip = "How far below the floor (Under the map) or below the target (Below target). It always stops short of the void" })
    OrbitSec:Slider({ Name = "Radius", Flag = "orbit_radius", Min = 0, Max = 100, Default = 6, Suffix = " studs", Decimals = 0.5 })
    OrbitSec:Slider({ Name = "Orbit speed", Flag = "orbit_spin", Min = 0, Max = 720, Default = 180, Suffix = " deg/s", Decimals = 1 })
    OrbitSec:Dropdown({ Name = "Direction", Flag = "orbit_dir", Items = { "Clockwise", "Counter clockwise" }, Default = "Clockwise" })
    OrbitSec:Slider({ Name = "Move speed", Flag = "orbit_speed", Min = 10, Max = 4000, Default = 150, Suffix = " studs/s", Decimals = 1, Tooltip = "How fast the server position travels to the orbit. 4000 jumps instantly" })
    OrbitSec:Slider({ Name = "Max target distance", Flag = "orbit_max", Min = 10, Max = 5000, Default = 500, Suffix = " studs", Decimals = 1 })
    local orbitVisual = OrbitSec:Toggle({ Name = "Visualizer", Flag = "orbit_visual", Default = false, Tooltip = "A highlighted copy of your character shows where the server sees you" })
    orbitVisual:Colorpicker({ Name = "Fill", Flag = "orbit_fill", Default = Color3.fromRGB(180, 120, 255), Alpha = 0.6 })
    orbitVisual:Colorpicker({ Name = "Outline", Flag = "orbit_line", Default = Color3.fromRGB(255, 255, 255), Alpha = 0 })
    local orbitTracer = OrbitSec:Toggle({ Name = "Tracer", Flag = "orbit_tracer", Default = false, Tooltip = "A line from you to where the server sees you" })
    orbitTracer:Colorpicker({ Name = "Color", Flag = "orbit_tracer_color", Default = Color3.fromRGB(180, 120, 255), Alpha = 0 })
    local orbitRing = OrbitSec:Toggle({ Name = "Show orbit ring", Flag = "orbit_ring", Default = false, Tooltip = "Draws the circle the server position travels on" })
    orbitRing:Colorpicker({ Name = "Color", Flag = "orbit_ring_color", Default = Color3.fromRGB(180, 120, 255), Alpha = 0.3 })

    local TargetSec = CombatSubs.Other:Section({ Name = "Target info", Side = 1 })
    TargetSec:Toggle({ Name = "Target info panel", Flag = "tinfo_on", Default = false, Tooltip = "A draggable panel about the player silent aim, the aim assist or the ragebot is locked onto. Drag it to move it." })
    TargetSec:Toggle({ Name = "Show health", Flag = "tinfo_health", Default = true })
    TargetSec:Toggle({ Name = "Show distance and line of sight", Flag = "tinfo_status", Default = true, Tooltip = "Visible, Wallbang (a wallbang spot exists) or Blocked" })
    TargetSec:Toggle({ Name = "Show team and weapon", Flag = "tinfo_extra", Default = true })
    TargetSec:Toggle({ Name = "Hide without target", Flag = "tinfo_hide", Default = true, Tooltip = "With the menu open the panel always shows so you can move it" })

    local GunMods = RageSubs.Aim:Section({ Name = "Gun mods", Side = 1 })
    GunMods:Toggle({ Name = "Gun modifications", Flag = "gun_mods", Default = false })
    GunMods:Slider({ Name = "Fire delay (% of stock)", Flag = "gun_fire_rate", Min = 1, Max = 100, Default = 100, Suffix = "%", Decimals = 1 })
    GunMods:Toggle({ Name = "No spread", Flag = "gun_no_spread", Default = false })
    GunMods:Slider({ Name = "Spread %", Flag = "gun_spread_pct", Min = 0, Max = 100, Default = 100, Suffix = "%", Decimals = 1, Tooltip = "Scales the stock spread down, for example 40% keeps some spread so shots still land a bit off-center. No spread overrides this" })
    GunMods:Toggle({ Name = "Full automatic", Flag = "gun_full_auto", Default = false })
    GunMods:Toggle({ Name = "Custom range", Flag = "gun_range_on", Default = false })
    GunMods:Slider({ Name = "Range", Flag = "gun_range", Min = 10, Max = 100000, Default = 1000, Suffix = " studs", Decimals = 1 })
end
-- dev.lua 2432-2435: menu: weapon utility
do
    local Utility = CombatSubs.Other:Section({ Name = "Weapon utility", Side = 2 })
    Utility:Toggle({ Name = "Auto reload", Flag = "gun_auto_reload", Default = false })
    Utility:Toggle({ Name = "Auto swap on empty", Flag = "gun_auto_swap", Default = false })
    Utility:Toggle({ Name = "Shoot through vehicles", Flag = "gun_vehicle_wallbang", Default = false })
end
-- dev.lua 3709-3723: menu: desync
do
    local Desync = RageSubs.Other:Section({ Name = "Desync", Side = 1 })
    Desync:Toggle({ Name = "Desync", Flag = "misc_desync", Default = false, Tooltip = "The server sees you at another position than the one you play at" }):Keybind({ Name = "Desync key", Flag = "misc_desync_key", Default = "None", Sync = true })
    Desync:Dropdown({
        Name = "Style", Flag = "misc_desync_style", Items = { "Offset", "Void" }, Default = "Offset",
        Tooltip = "Offset: the server position sits a fixed height below (or above) you.\nVoid: the server position is far below the map, just above the point where parts are destroyed.",
    })
    Desync:Slider({ Name = "Y offset", Flag = "misc_desync_y", Min = -10, Max = 10, Default = -2.5, Suffix = " studs", Decimals = 0.1 })
    Desync:Toggle({ Name = "Always underground", Flag = "misc_desync_under", Default = false, Tooltip = "Keeps the server position below the floor, also while you jump" })
    Desync:Toggle({ Name = "Filter structures", Flag = "misc_desync_filter", Default = false, Tooltip = "Looks for the lowest floor under you instead of the first surface (tables, roofs)" })
    Desync:Slider({ Name = "Follower speed", Flag = "misc_desync_speed", Min = 1, Max = 500, Default = 30, Suffix = " studs/s", Decimals = 1 })
    local desyncVisual = Desync:Toggle({ Name = "Visualizer", Flag = "misc_desync_visual", Default = false, Tooltip = "A highlighted copy of your character shows where the server sees you" })
    desyncVisual:Colorpicker({ Name = "Fill", Flag = "misc_desync_fill", Default = Color3.fromRGB(255, 255, 255), Alpha = 0.6 })
    desyncVisual:Colorpicker({ Name = "Outline", Flag = "misc_desync_line", Default = Color3.fromRGB(255, 255, 255), Alpha = 0 })
    local desyncTracer = Desync:Toggle({ Name = "Tracer", Flag = "misc_desync_tracer", Default = false })
    desyncTracer:Colorpicker({ Name = "Tracer color", Flag = "misc_desync_tracer_color", Default = Color3.fromRGB(255, 255, 255), Alpha = 0 })
end
-- dev.lua 4288-4315: menu: reload / ammo / wallbang indicators
do
    local Reload = WorldSubs.Indicators:Section({ Name = "Reload indicator", Side = 1 })
    Reload:Toggle({ Name = "Reload indicator", Flag = "reload_ind", Default = false, Tooltip = "A progress bar under the cursor while your gun reloads" })
    Reload:Toggle({ Name = "Show time", Flag = "reload_ind_text", Default = true })
    Reload:Slider({ Name = "Width", Flag = "reload_ind_w", Min = 40, Max = 300, Default = 120, Suffix = "px", Decimals = 1 })
    Reload:Slider({ Name = "Height", Flag = "reload_ind_h", Min = 3, Max = 16, Default = 6, Suffix = "px", Decimals = 1 })
    Reload:Slider({ Name = "Vertical offset", Flag = "reload_ind_y", Min = -300, Max = 300, Default = 40, Suffix = "px", Decimals = 1 })
    Reload:Label({ Name = "Bar color" }):Colorpicker({ Name = "Bar", Flag = "reload_ind_fill", Default = Color3.fromRGB(255, 255, 255), Alpha = 0 })
    Reload:Label({ Name = "Background color" }):Colorpicker({ Name = "Background", Flag = "reload_ind_back", Default = Color3.fromRGB(0, 0, 0), Alpha = 0.5 })

    local Ammo = WorldSubs.Indicators:Section({ Name = "Ammo indicator", Side = 1 })
    Ammo:Toggle({ Name = "Server bullet count", Flag = "ammo_ind", Default = false, Tooltip = "Shows how many bullets the server says your gun has. It turns yellow when that differs from the count your game shows." })
    Ammo:Toggle({ Name = "Show local count", Flag = "ammo_ind_local", Default = false, Tooltip = "Also shows the count your own game shows" })
    Ammo:Slider({ Name = "Text size", Flag = "ammo_ind_size", Min = 10, Max = 32, Default = 16, Decimals = 1 })
    Ammo:Slider({ Name = "Vertical offset", Flag = "ammo_ind_y", Min = -300, Max = 300, Default = 70, Suffix = "px", Decimals = 1 })
    Ammo:Label({ Name = "Normal color" }):Colorpicker({ Name = "Normal", Flag = "ammo_ind_c_ok", Default = Color3.fromRGB(255, 255, 255) })
    Ammo:Label({ Name = "Empty color" }):Colorpicker({ Name = "Empty", Flag = "ammo_ind_c_empty", Default = Color3.fromRGB(255, 80, 80) })
    Ammo:Label({ Name = "Mismatch color" }):Colorpicker({ Name = "Mismatch", Flag = "ammo_ind_c_diff", Default = Color3.fromRGB(255, 200, 60) })

    local Indicator = WorldSubs.Indicators:Section({ Name = "Wallbang indicator", Side = 2 })
    Indicator:Toggle({ Name = "Wallbang indicator", Flag = "wb_ind", Default = false, Tooltip = "Tells you if an enemy is visible, wallbangable with the wallbang method you use now (a spot that can deal damage), or not wallbangable" })
    Indicator:Toggle({ Name = "Show on cursor", Flag = "wb_ind_cursor", Default = true })
    Indicator:Toggle({ Name = "Show on everyone", Flag = "wb_ind_all", Default = false })
    Indicator:Toggle({ Name = "Always visible", Flag = "wb_ind_always", Default = false, Tooltip = "Also shows a label when there is no enemy near the cursor" })
    Indicator:Slider({ Name = "Text size", Flag = "wb_ind_size", Min = 10, Max = 28, Default = 14, Decimals = 1 })
    Indicator:Slider({ Name = "Max distance", Flag = "wb_ind_range", Min = 50, Max = 3000, Default = 1000, Suffix = " studs", Decimals = 1 })
    Indicator:Label({ Name = "Visible color" }):Colorpicker({ Name = "Visible", Flag = "wb_ind_c_vis", Default = Color3.fromRGB(90, 255, 120) })
    Indicator:Label({ Name = "Wallbangable color" }):Colorpicker({ Name = "Wallbangable", Flag = "wb_ind_c_wb", Default = Color3.fromRGB(255, 200, 60) })
    Indicator:Label({ Name = "Blocked color" }):Colorpicker({ Name = "Blocked", Flag = "wb_ind_c_block", Default = Color3.fromRGB(255, 80, 80) })
end
-- dev.lua 10659-10844: gun mods, auto reload + swap, vehicle wallbang
do
    do
        local bag = newBag()
        local originals = setmetatable({}, { __mode = "k" })
        local applied = setmetatable({}, { __mode = "k" })

        local function signature()
            return table.concat({
                tostring(flag("gun_no_spread", false)),
                tostring(flag("gun_spread_pct", 100)),
                tostring(flag("gun_full_auto", false)),
                tostring(flag("gun_fire_rate", 100)),
                tostring(flag("gun_range_on", false)),
                tostring(flag("gun_range", 1000)),
            }, "|")
        end

        local function apply(tool, restoreOnly)
            if tool:GetAttribute("FireRate") == nil and not originals[tool] then return false end
            if tool.Name == "Taser" then return false end
            local o = originals[tool]
            if not o then
                o = { SpreadRadius = tool:GetAttribute("SpreadRadius"), FireRate = tool:GetAttribute("FireRate"), AutoFire = tool:GetAttribute("AutoFire"), Range = tool:GetAttribute("Range"), AccurateRange = tool:GetAttribute("AccurateRange") }
                originals[tool] = o
            end
            local noSpread = not restoreOnly and flag("gun_no_spread", false)
            local auto = not restoreOnly and flag("gun_full_auto", false)
            local pct = restoreOnly and 100 or flag("gun_fire_rate", 100)
            local spreadPct = restoreOnly and 100 or flag("gun_spread_pct", 100)
            if o.SpreadRadius ~= nil then tool:SetAttribute("SpreadRadius", noSpread and 0 or o.SpreadRadius * (spreadPct / 100)) end
            if o.FireRate ~= nil then tool:SetAttribute("FireRate", o.FireRate * (pct / 100)) end
            if o.AutoFire ~= nil or auto then tool:SetAttribute("AutoFire", auto and true or o.AutoFire) end
            local ranged = not restoreOnly and flag("gun_range_on", false)
            if o.Range ~= nil or ranged then
                if o.Range ~= nil then
                    local want = ranged and flag("gun_range", 1000) or o.Range
                    if tool:GetAttribute("Range") ~= want then tool:SetAttribute("Range", want) end
                elseif ranged then
                    tool:SetAttribute("Range", flag("gun_range", 1000))
                end
            end
            if o.AccurateRange ~= nil then
                local want = ranged and math.max(o.AccurateRange, flag("gun_range", 1000)) or o.AccurateRange
                if tool:GetAttribute("AccurateRange") ~= want then tool:SetAttribute("AccurateRange", want) end
            end
            return true
        end

        local function reequip(tool)
            local char, hum = localParts()
            if not (char and hum) or tool.Parent ~= char then return end
            hum:UnequipTools()
            task.delay(0.2, function()
                local _, h = localParts()
                if h and tool.Parent == LocalPlayer:FindFirstChildOfClass("Backpack") then h:EquipTool(tool) end
            end)
        end

        local function sweep(restoreOnly)
            local sig = restoreOnly and "restore" or signature()
            local character = LocalPlayer.Character
            for _, tool in ipairs(allTools()) do
                local held = tool.Parent == character
                if applied[tool] ~= sig then
                    if apply(tool, restoreOnly) then
                        applied[tool] = sig
                        if held then reequip(tool) end
                    end
                elseif held and not restoreOnly then
                    apply(tool, false)
                end
            end
        end

        feature("gun_mods", function()
            bag.add(RunService.Heartbeat:Connect(function() sweep(false) end))
        end, function()
            bag.clear()
            for tool in pairs(originals) do applied[tool] = nil end
            sweep(true)
        end)
    end

    do
        local bag, nextTry = newBag(), 0
        local VirtualInputManager
        local cachedReload

        local function getReload()
            if cachedReload then return cachedReload end
            if type(getconnections) ~= "function" or not (debug and debug.getupvalue) then return end
            local home = LocalPlayer.PlayerGui:FindFirstChild("Home")
            local area = home and home:FindFirstChild("hud") and home.hud:FindFirstChild("ActionArea")
            if not area then return end
            local ok, list = pcall(getconnections, area.InputBegan)
            if not ok then return end
            for _, c in ipairs(list) do
                if c.Function then
                    local ok1, shoot = pcall(debug.getupvalue, c.Function, 2)
                    if ok1 and type(shoot) == "function" then
                        local ok2, reload = pcall(debug.getupvalue, shoot, 2)
                        if ok2 and type(reload) == "function" then cachedReload = reload return reload end
                    end
                end
            end
        end

        local function pressReload()
            if typing() then return false end
            local ok = pcall(function()
                VirtualInputManager = VirtualInputManager or game:GetService("VirtualInputManager")
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.R, false, game)
                task.wait(0.05)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.R, false, game)
            end)
            return ok
        end

        Actions.reloadGun = function()
            local reload = getReload()
            if reload then task.spawn(reload) else task.spawn(pressReload) end
        end

        local priority = { M4A1 = 1, ["AK-47"] = 1, MP5 = 1, FAL = 1, ["Remington 870"] = 2, M9 = 3, Revolver = 4 }
        local function swapTarget(current)
            local pack = LocalPlayer:FindFirstChildOfClass("Backpack")
            if not pack then return end
            local best
            for _, tool in ipairs(pack:GetChildren()) do
                if tool ~= current and tool:IsA("Tool") and tool:GetAttribute("FireRate") ~= nil
                    and (tool:GetAttribute("Local_ReloadSession") or 0) <= 0
                    and tool.Name ~= "Taser" and tool.Name ~= "M700" then
                    if not best or (priority[tool.Name] or 100) < (priority[best.Name] or 100) then best = tool end
                end
            end
            return best
        end

        feature("gun_auto_reload", function()
            bag.add(RunService.Heartbeat:Connect(function()
                if clock() < nextTry then return end
                local tool = equippedGun()
                if not tool then return end
                local ammo = tool:GetAttribute("Local_CurrentAmmo")
                if ammo == nil or ammo > 0 or (tool:GetAttribute("Local_ReloadSession") or 0) ~= 0 then return end
                if tool:GetAttribute("Behavior") == "Sniper" and (tool:GetAttribute("StoredAmmo") or 1) <= 0 then return end
                nextTry = clock() + 0.6
                local reload = getReload()
                if reload then task.spawn(reload) else task.spawn(pressReload) end
                if flag("gun_auto_swap", false) then
                    task.delay(0.15, function()
                        local _, hum = localParts()
                        local target = swapTarget(tool)
                        if hum and target then hum:EquipTool(target) end
                    end)
                end
            end))
        end, function()
            bag.clear()
        end)
    end

    do
        local bag, held, token = newBag(), {}, 0
        local function take(part)
            if part:IsA("BasePart") and not held[part] then held[part] = true holdQuery(part) end
        end
        feature("gun_vehicle_wallbang", function()
            token += 1
            local my = token
            task.spawn(function()
                local cars = waitForCars(5)
                if not cars or my ~= token then return end
                bag.add(cars.DescendantAdded:Connect(take))
                for i, part in ipairs(cars:GetDescendants()) do
                    if my ~= token then return end
                    take(part)
                    if i % 1500 == 0 then task.wait() end
                end
            end)
        end, function()
            token += 1
            bag.clear()
            for part in pairs(held) do releaseQuery(part) end
            table.clear(held)
        end)
    end
end
-- dev.lua 14805-15105: desync
do
    do
        local SP = Actions.sp
        local requests, order = {}, { "rage", "voidhide", "assist", "orbit", "desync" }
        local engine = newBag()
        local running = false
        local applied, realCF, realVel = nil, nil, nil
        local lastSpeed, lastStyle, lastWarn = 100, nil, 0
        local RESTORE, GHOST = "AsterServerPosRestore", "AsterServerPosGhost"
        SP.pos = nil
        local groundBelow

        local rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        rayParams.RespectCanCollide = true

        function SP.realPos(root)
            if applied and realCF then return realCF.Position end
            return root.Position
        end

        function SP.shooter(root)
            if SP.active == "orbit" then return SP.realPos(root) end
            return SP.pos or SP.realPos(root)
        end
        function SP.floorAt(position, lowest)
            return groundBelow(position, lowest)
        end

        local function picker(name, fallbackColor, fallbackAlpha)
            local object = Options[name]
            local color = object and typeof(object.Value) == "Color3" and object.Value or fallbackColor
            local alpha = object and tonumber(object.Transparency) or fallbackAlpha
            return color, alpha
        end
        function SP.visualStyle(fillFlag, lineFlag, tracerFlag)
            local fill, fillT = picker(fillFlag, WHITE, 0.6)
            local line, lineT = picker(lineFlag, WHITE, 0)
            local style = { fill = fill, fillT = fillT, line = line, lineT = lineT }
            if tracerFlag then style.tracer, style.tracerT = picker(tracerFlag, WHITE, 0) end
            return style
        end

        function groundBelow(position, lowest)
            local list = {}
            for _, player in ipairs(Players:GetPlayers()) do
                if player.Character then list[#list + 1] = player.Character end
            end
            list[#list + 1] = Camera()
            rayParams.FilterDescendantsInstances = list
            local hit = workspace:Raycast(position, v3(0, -600, 0), rayParams)
            if not hit then return nil end
            local floorY = hit.Position.Y
            if lowest then
                for _ = 1, 6 do
                    local below = workspace:Raycast(v3(position.X, floorY - 0.25, position.Z), v3(0, -600, 0), rayParams)
                    if not below then break end
                    floorY = below.Position.Y
                end
            end
            return floorY
        end

        local function follow(current, goal, speed, dt)
            local delta = goal - current
            local distance = delta.Magnitude
            local step = speed * dt
            if speed >= 4000 or distance <= step then return goal end
            return current + delta * (step / distance)
        end

        local ghost = { model = nil, highlight = nil, parts = {}, char = nil, count = 0, checked = 0, line = nil }

        local function hideGhost()
            if ghost.model then ghost.model.Parent = nil end
            if ghost.line then ghost.line.Visible = false end
        end
        local function destroyGhost()
            if ghost.model then pcall(function() ghost.model:Destroy() end) end
            ghost.model, ghost.highlight, ghost.char = nil, nil, nil
            table.clear(ghost.parts)
            if ghost.line then pcall(function() ghost.line.Visible = false end) end
        end
        local function buildGhost(char)
            destroyGhost()
            local model = Instance.new("Model")
            model.Name = "AsterServerPosition"
            local descendants = char:GetDescendants()
            for _, d in ipairs(descendants) do
                if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" and d.Transparency < 0.95 then
                    local ok, clone = pcall(function() return d:Clone() end)
                    if ok and clone then
                        for _, child in ipairs(clone:GetChildren()) do
                            if not child:IsA("SpecialMesh") then child:Destroy() end
                        end
                        clone.Anchored = true
                        clone.CanCollide = false
                        clone.CanTouch = false
                        clone.CanQuery = false
                        clone.CastShadow = false
                        clone.Massless = true
                        clone.Transparency = 0
                        clone.Material = Enum.Material.SmoothPlastic
                        clone.Parent = model
                        ghost.parts[#ghost.parts + 1] = { d, clone }
                    end
                end
            end
            local highlight = Instance.new("Highlight")
            highlight.Adornee = model
            highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            highlight.Parent = model
            ghost.model, ghost.highlight, ghost.char = model, highlight, char
            ghost.count, ghost.checked = #descendants, clock()
        end
        local function newLine()
            if not (Drawing and type(Drawing.new) == "function") then return nil end
            local ok, line = pcall(Drawing.new, "Line")
            if ok and line then
                table.insert(getgenv().TS_Drawings, line)
                return line
            end
            return nil
        end

        local function updateGhost()
            local style = lastStyle
            local char, _, root = localParts()
            local cam = workspace.CurrentCamera
            if not SP.pos or not style or not root or not cam then
                hideGhost()
                return
            end
            local now = clock()
            if ghost.char ~= char or not ghost.model then
                buildGhost(char)
            elseif now - ghost.checked > 0.5 then
                ghost.checked = now
                if #char:GetDescendants() ~= ghost.count then buildGhost(char) end
            end
            if ghost.model.Parent ~= cam then ghost.model.Parent = cam end
            local shift = SP.pos - root.Position
            for _, pair in ipairs(ghost.parts) do
                if pair[1].Parent then
                    pair[2].CFrame = pair[1].CFrame + shift
                    pair[2].Color = style.fill
                end
            end
            local highlight = ghost.highlight
            highlight.FillColor, highlight.FillTransparency = style.fill, style.fillT
            highlight.OutlineColor, highlight.OutlineTransparency = style.line, style.lineT
            if style.tracer then
                ghost.line = ghost.line or newLine()
                local line = ghost.line
                if line then
                    local a = cam:WorldToViewportPoint(root.Position)
                    local b = cam:WorldToViewportPoint(SP.pos)
                    line.Visible = a.Z > 0 and b.Z > 0
                    line.From = Vector2.new(a.X, a.Y)
                    line.To = Vector2.new(b.X, b.Y)
                    line.Color = style.tracer
                    line.Transparency = 1 - style.tracerT
                    line.Thickness = 1
                end
            elseif ghost.line then
                ghost.line.Visible = false
            end
        end

        local function onHeartbeat(dt)
            local _, _, root = localParts()
            if not root or isOn("misc_invis") then
                SP.pos, applied, realCF = nil, nil, nil
                return
            end
            local real = root.CFrame
            local realPos = real.Position
            local goal, speed, style
            SP.active = nil
            for _, name in ipairs(order) do
                local fn = requests[name]
                if fn then
                    local ok, g, s, v = pcall(fn, root, realPos)
                    if ok and g then goal, speed, style = g, s or 100, v SP.active = name break end
                end
            end
            if goal then
                lastSpeed, lastStyle = speed, style
                SP.pos = follow(SP.pos or realPos, goal, speed, dt)
            elseif SP.pos then
                SP.pos = follow(SP.pos, realPos, lastSpeed, dt)
                if (SP.pos - realPos).Magnitude < 0.05 then SP.pos = nil end
            end
            if SP.pos then
                realCF = real
                realVel = root.AssemblyLinearVelocity
                applied = CFrame.new(SP.pos) * (real - realPos)
                root.CFrame = applied
            else
                applied, realCF = nil, nil
                if next(requests) == nil then SP.stopEngine() end
            end
        end

        local function onRestore()
            if not applied then return end
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")

            if root and realCF then
                local drift = root.Position - applied.Position
                if drift.Magnitude < 0.5 then
                    root.CFrame = realCF
                else
                    root.CFrame = realCF + (drift.Magnitude < 40 and drift or Vector3.zero)
                end
                if realVel and (applied.Position - realCF.Position).Magnitude > 20 then
                    root.AssemblyLinearVelocity = realVel
                end
            end
            applied = nil
        end

        local function startEngine()
            if running then return end
            running = true
            engine.add(RunService.Heartbeat:Connect(function(dt)
                local ok, err = pcall(onHeartbeat, dt)
                if not ok and clock() - lastWarn > 5 then
                    lastWarn = clock()
                    warnf("server position:", err)
                end
            end))
            RunService:BindToRenderStep(RESTORE, Enum.RenderPriority.First.Value, function()
                pcall(onRestore)
            end)
            engine.add(RunService.Stepped:Connect(function()
                pcall(onRestore)
            end))
            RunService:BindToRenderStep(GHOST, Enum.RenderPriority.Last.Value, function()
                local ok, err = pcall(updateGhost)
                if not ok and clock() - lastWarn > 5 then
                    lastWarn = clock()
                    warnf("server position ghost:", err)
                end
            end)
        end

        function SP.stopEngine()
            if not running then return end
            running = false
            engine.clear()
            pcall(function() RunService:UnbindFromRenderStep(RESTORE) end)
            pcall(function() RunService:UnbindFromRenderStep(GHOST) end)
            destroyGhost()
        end

        function SP.enable(name, fn)
            requests[name] = fn
            startEngine()
        end

        function SP.disable(name)
            requests[name] = nil
        end

        onUnload(function()
            table.clear(requests)
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if applied and realCF and root then pcall(function() root.CFrame = realCF end) end
            applied, realCF, SP.pos = nil, nil, nil
            SP.stopEngine()
            destroyGhost()
            if ghost.line then pcall(function() ghost.line:Remove() end) ghost.line = nil end
        end)

        local function desyncRequest(_, realPos)
            local goal
            if flag("misc_desync_style", "Offset") == "Void" then
                local destroyAt = workspace.FallenPartsDestroyHeight
                if type(destroyAt) ~= "number" or destroyAt ~= destroyAt then destroyAt = -500 end
                goal = v3(realPos.X, math.min(math.max(destroyAt + 30, -2500), realPos.Y - 10), realPos.Z)
            else
                goal = realPos + v3(0, flag("misc_desync_y", -2.5), 0)
                if flag("misc_desync_under", false) then
                    local floorY = groundBelow(realPos, flag("misc_desync_filter", false))
                    if floorY then goal = v3(goal.X, math.min(goal.Y, floorY - 3), goal.Z) end
                end
            end
            local style
            if flag("misc_desync_visual", false) then
                style = SP.visualStyle("misc_desync_fill", "misc_desync_line", flag("misc_desync_tracer", false) and "misc_desync_tracer_color" or nil)
            end
            return goal, flag("misc_desync_speed", 30), style
        end
        feature("misc_desync", function()
            SP.enable("desync", desyncRequest)
        end, function()
            SP.disable("desync")
        end)
    end
end
-- dev.lua 15834-19107: gun discovery, aim assist, silent aim, ragebot + void, trigger, target info, orbit, wallbang assist, indicators
do
    ;(function()
        local rand = Random.new()

        local function has(value, key)
            if type(value) ~= "table" then return value == key end
            if value[key] == true then return true end
            for _, selected in pairs(value) do
                if selected == key then return true end
            end
            return false
        end

        local function keyActive(name)
            local picker = Options[name]
            if picker and type(picker.GetState) == "function" then
                local ok, state = pcall(picker.GetState, picker)
                if ok then return state == true end
            end
            return true
        end

        local function aimRef()
            local cam = Camera()
            if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
                return cam.ViewportSize / 2
            end
            return UserInputService:GetMouseLocation()
        end

        local Gun = { shoot = nil, cast = nil }

        local function functionName(fn)
            local ok, name = pcall(debug.info, fn, "n")
            return ok and name or nil
        end

        local function findByConnections()
            if type(getconnections) ~= "function" or type(debug) ~= "table" or type(debug.getupvalue) ~= "function" then
                return false
            end
            local home = LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("Home")
            local area = home and home:FindFirstChild("hud") and home.hud:FindFirstChild("ActionArea")
            if not area then return false end
            local ok, list = pcall(getconnections, area.InputBegan)
            if not ok or type(list) ~= "table" then return false end
            for _, connection in ipairs(list) do
                local fn = connection.Function
                if fn then
                    local okShoot, shoot = pcall(debug.getupvalue, fn, 2)
                    if okShoot and type(shoot) == "function" then
                        local cast
                        for index = 1, 40 do
                            local okUp, up = pcall(debug.getupvalue, shoot, index)
                            if not okUp then break end
                            if type(up) == "function" and functionName(up) == "castRay" then cast = up break end
                        end
                        if not cast then
                            local okUp, up = pcall(debug.getupvalue, shoot, 16)
                            if okUp and type(up) == "function" then cast = up end
                        end
                        if cast then
                            Gun.shoot, Gun.cast = shoot, cast
                            return true
                        end
                    end
                end
            end
            return false
        end

        local function sourceOf(fn)
            local ok, info = pcall(function() return debug.getinfo(fn) end)
            if ok and type(info) == "table" and info.source then return tostring(info.source) end
            local ok2, src = pcall(debug.info, fn, "s")
            return ok2 and tostring(src) or ""
        end

        local function findCastByGc()
            local function accept(fn)
                if type(fn) ~= "function" then return false end
                if type(isexecutorclosure) == "function" and isexecutorclosure(fn) then return false end
                return functionName(fn) == "castRay" and sourceOf(fn):find("GunController", 1, true) ~= nil
            end
            if type(filtergc) == "function" then
                local ok, list = pcall(filtergc, "function", { Name = "castRay" })
                if ok and type(list) == "table" then
                    for _, fn in ipairs(list) do
                        if accept(fn) then return fn end
                    end
                end
            end
            if type(getgc) == "function" then
                local ok, list = pcall(getgc)
                if ok and type(list) == "table" then
                    for _, fn in ipairs(list) do
                        if accept(fn) then return fn end
                    end
                end
            end
        end

        function Gun.find()
            if findByConnections() then return true end
            local cast = findCastByGc()
            if cast then
                Gun.cast = cast
                return true
            end
            return false
        end

        function Gun.range(data)
            local tool = Actions.gunTool and Actions.gunTool()
            local attribute = tool and tool:GetAttribute("Range")
            if type(attribute) == "number" and attribute > 0 then return attribute end
            return data and tonumber(data.Range) or nil
        end

        function Gun.data()
            if not Gun.shoot then return nil end
            local ok, data = pcall(debug.getupvalue, Gun.shoot, 10)
            return ok and type(data) == "table" and data or nil
        end

        local function readyGun()
            local tool = equippedGun()
            if not tool then return false end
            if tool:GetAttribute("Local_IsShooting") then return false end
            if (tool:GetAttribute("Local_ReloadSession") or 0) > 0 then return false end
            return (tool:GetAttribute("Local_CurrentAmmo") or 0) > 0
        end

        local function fireGun()
            if Gun.shoot then
                local obj = { UserInputState = Enum.UserInputState.Begin, UserInputType = Enum.UserInputType.MouseButton1, Position = Vector3.zero }
                task.spawn(Gun.shoot, obj)
                obj.UserInputState = Enum.UserInputState.End
                return
            end
            pcall(function()
                local vim = game:GetService("VirtualInputManager")
                local m = UserInputService:GetMouseLocation()
                vim:SendMouseButtonEvent(m.X, m.Y, 0, true, game, 0)
                task.delay(0.03, function() vim:SendMouseButtonEvent(m.X, m.Y, 0, false, game, 0) end)
            end)
        end

        local sight = RaycastParams.new()
        sight.FilterType = Enum.RaycastFilterType.Exclude
        sight.RespectCanCollide = true

        local function visibleFrom(from, part, char, at)
            local list = { Camera() }
            if LocalPlayer.Character then list[#list + 1] = LocalPlayer.Character end
            list[#list + 1] = char
            sight.FilterDescendantsInstances = list
            return workspace:Raycast(from, (at or part.Position) - from, sight) == nil
        end

        local HIT_GROUPS = {
            ["Head"] = { "Head" },
            ["Torso"] = { "UpperTorso", "Torso" },
            ["Lower torso"] = { "LowerTorso" },
            ["Root"] = { "HumanoidRootPart" },
            ["Left arm"] = { "Left Arm", "LeftUpperArm", "LeftLowerArm", "LeftHand" },
            ["Right arm"] = { "Right Arm", "RightUpperArm", "RightLowerArm", "RightHand" },
            ["Left leg"] = { "Left Leg", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot" },
            ["Right leg"] = { "Right Leg", "RightUpperLeg", "RightLowerLeg", "RightFoot" },
        }
        local MP_OFFSETS = { v3(1, 0, 0), v3(-1, 0, 0), v3(0, 1, 0), v3(0, -1, 0), v3(0, 0, 1), v3(0, 0, -1) }

        local function hitSelection(prefix)
            local picker = Options[prefix .. "_points"]
            local value = picker and picker.Value
            local chosen, any = {}, false
            for group in pairs(HIT_GROUPS) do
                if has(value, group) then chosen[group] = true any = true end
            end
            if has(value, "Body") then chosen["Torso"] = true any = true end
            if not any then chosen["Head"] = true end
            return chosen
        end

        local function hitParts(char, chosen)
            local list = {}
            for group, names in pairs(HIT_GROUPS) do
                if chosen[group] then
                    for _, name in ipairs(names) do
                        local found = char:FindFirstChild(name)
                        if found and found:IsA("BasePart") then list[#list + 1] = found end
                    end
                end
            end
            return list
        end

        local function partPoints(part, multipoint, scale)
            if not multipoint then return { part.Position } end
            local half = part.Size * 0.5 * scale
            local cf = part.CFrame
            local list = { part.Position }
            for _, off in ipairs(MP_OFFSETS) do
                list[#list + 1] = cf:PointToWorldSpace(v3(half.X * off.X, half.Y * off.Y, half.Z * off.Z))
            end
            return list
        end

        local function pointFlags(prefix)
            local picker = Options[prefix .. "_points"]
            local value = picker and picker.Value
            local head, body = has(value, "Head"), has(value, "Body")
            if not head and not body then head = true end
            return head, body
        end

        local Dyn = {}
        local function selectTarget(prefix, ref, from, opts)
            opts = opts or {}
            local cam = Camera()
            if not cam then return end
            local baseFov = opts.fov or flag(prefix .. "_fov", 120)
            local dynamic = flag(prefix .. "_dynamic", false)
            local amount = flag(prefix .. "_dynamic_amount", 50) / 100
            local dynMode = flag(prefix .. "_dynamic_mode", "Distance")
            local nearD, farD = flag(prefix .. "_dyn_near", 25), flag(prefix .. "_dyn_far", 300)
            local targetMode = flag(prefix .. "_target", "Crosshair")
            local sticky = flag(prefix .. "_sticky", 30) / 100
            local bestRadius
            local maxDist = math.min(flag(prefix .. "_max_dist", 1000), opts.limit or math.huge)
            local priority = flag(prefix .. "_priority", "Closest")
            local chosenGroups = hitSelection(prefix)
            local multipoint = flag(prefix .. "_multipoint", false)
            local mpScale = flag(prefix .. "_mp_scale", 70) / 100
            local bestPoint
            local team = flag(prefix .. "_team", false)
            local ignoreDown = opts.ignoreDown or flag(prefix .. "_ignore_down", false)
            local wall = flag(prefix .. "_wall", false) and not opts.skipWall
            local ffCheck = flag(prefix .. "_ff", false)
            local hostileCheck = flag(prefix .. "_hostile", false)

            local bestEntity, bestPart, bestScore, bestDist
            for _, e in ipairs(otherEntities()) do
                if (not opts.only or e.Player == opts.only) then
                    local distance = (e.Root.Position - from).Magnitude
                    local skip = distance > maxDist
                    if not skip and (Relations[e.Player.UserId] == "Friendly" or (team and relationOf(e.Player) == "Friendly")) then skip = true end
                    if not skip and ffCheck and e.Character:FindFirstChildOfClass("ForceField") then skip = true end
                    if not skip and hostileCheck and isPeaceful(e.Player) then skip = true end
                    if not skip and ignoreDown and (e.Character:GetAttribute("Tased") or e.Character:GetAttribute("Arrested")) then skip = true end
                    if not skip then
                        local radius = baseFov
                        if dynamic and dynMode ~= "Cursor" then
                            local t = math.clamp((distance - nearD) / math.max(farD - nearD, 1), 0, 1)
                            radius = baseFov * ((1 + amount) * (1 - t) + (1 - amount * 0.75) * t)
                        end
                        local headPart = e.Character:FindFirstChild("Head")
                        local bodyPart = e.Character:FindFirstChild("UpperTorso") or e.Character:FindFirstChild("Torso") or e.Root
                        local parts = hitParts(e.Character, chosenGroups)
                        for _, part in ipairs(parts) do
                          for _, point in ipairs(partPoints(part, multipoint, mpScale)) do
                            local screen, onScreen = cam:WorldToViewportPoint(point)
                            if onScreen then
                                local d = (Vector2.new(screen.X, screen.Y) - ref).Magnitude
                                local partRadius = radius
                                if dynamic and dynMode ~= "Distance" and (opts.current == e.Player or d <= baseFov * 0.45) then
                                    partRadius = radius * (1 + amount)
                                end
                                if (opts.ignoreFov or d <= partRadius) and (not wall or visibleFrom(from, part, e.Character, point)) then
                                    local score = d
                                    if targetMode == "Distance" then
                                        score = distance + d * 0.001
                                    elseif targetMode == "Lowest health" then
                                        score = e.Humanoid.Health * 10 + d * 0.05
                                    end
                                    if opts.current == e.Player then score *= (1 - sticky * 0.6) end
                                    if priority == "Head" and part ~= headPart then score += 1000 end
                                    if priority == "Body" and part == headPart then score += 1000 end
                                    if Relations[e.Player.UserId] == "Priority" then score -= 100000 end
                                    if not bestScore or score < bestScore then
                                        bestEntity, bestPart, bestScore, bestDist, bestRadius, bestPoint = e, part, score, d, partRadius, point
                                    end
                                end
                            end
                          end
                        end
                    end
                end
            end
            Dyn[prefix] = bestRadius
            return bestEntity, bestPart, bestDist, bestPoint
        end

        local function newCircle()
            local circle, drawing, gui, frame, stroke = {}, nil, nil, nil, nil
            if Drawing and type(Drawing.new) == "function" then
                local ok, obj = pcall(Drawing.new, "Circle")
                if ok and obj then
                    drawing = obj
                    table.insert(getgenv().TS_Drawings, obj)
                end
            end
            if not drawing then
                pcall(function()
                    gui = Instance.new("ScreenGui")
                    gui.Name = "TS_FovCircle"
                    gui.IgnoreGuiInset = true
                    gui.ResetOnSpawn = false
                    gui.DisplayOrder = 50
                    gui.Parent = (type(gethui) == "function" and gethui()) or game:GetService("CoreGui")
                    frame = Instance.new("Frame")
                    frame.AnchorPoint = Vector2.new(0.5, 0.5)
                    frame.BackgroundTransparency = 1
                    frame.BorderSizePixel = 0
                    frame.Visible = false
                    frame.Parent = gui
                    local corner = Instance.new("UICorner")
                    corner.CornerRadius = UDim.new(1, 0)
                    corner.Parent = frame
                    stroke = Instance.new("UIStroke")
                    stroke.Parent = frame
                end)
            end

            function circle.update(visible, position, radius, color, opacity, thickness, filled)
                if drawing then
                    drawing.Visible = visible
                    if visible then
                        drawing.Position = position
                        drawing.Radius = radius
                        drawing.Color = color
                        drawing.Transparency = opacity
                        drawing.Thickness = thickness
                        drawing.Filled = filled
                        drawing.NumSides = 64
                    end
                elseif frame then
                    frame.Visible = visible
                    if visible then
                        frame.Position = UDim2.fromOffset(position.X, position.Y)
                        frame.Size = UDim2.fromOffset(radius * 2, radius * 2)
                        frame.BackgroundColor3 = color
                        frame.BackgroundTransparency = filled and (1 - opacity * 0.35) or 1
                        stroke.Color = color
                        stroke.Thickness = thickness
                        stroke.Transparency = 1 - opacity
                    end
                end
            end
            function circle.destroy()
                if drawing then pcall(function() drawing.Visible = false drawing:Remove() end) drawing = nil end
                if gui then pcall(function() gui:Destroy() end) gui = nil end
            end
            return circle
        end

        local circles = { aim = newCircle(), silent = newCircle() }
        local circleRadius = {}
        local circleFeature = { aim = "Aim_Global_Enabled", silent = "Silent_Global_Enabled" }
        track(RunService.RenderStepped:Connect(function()
            local cam = Camera()
            if not cam then return end
            local ref = aimRef()
            for prefix, circle in pairs(circles) do
                local visible = flag(circleFeature[prefix], false) and flag(prefix .. "_fov_show", false)
                if visible then
                    local picker = Options[prefix .. "_fov_color"]
                    local color = picker and typeof(picker.Value) == "Color3" and picker.Value or Color3.new(1, 1, 1)
                    local opacity = 1 - (picker and tonumber(picker.Transparency) or 0)
                    local want = flag(prefix .. "_fov", 120)
                    if flag(prefix .. "_dynamic", false) and Dyn[prefix] then want = Dyn[prefix] end
                    circleRadius[prefix] = (circleRadius[prefix] or want) + (want - (circleRadius[prefix] or want)) * 0.2
                    circle.update(true, ref, circleRadius[prefix], color, opacity, flag(prefix .. "_fov_thick", 1), flag(prefix .. "_fov_filled", false))
                else
                    circle.update(false)
                end
            end
        end))
        onUnload(function()
            for _, circle in pairs(circles) do circle.destroy() end
        end)

        do
            local name = "TS_AimAssist"
            local lockedPlayer, acquiredAt, lastPlayer = nil, 0, nil
            local accX, accY, warned = 0, 0, false
            local pauseUntil, humanFor, bend, over, startLen, missRoll, missOff = 0, nil, 0, 0, 1, 0, Vector3.zero

            local function valid(player)
                local char = player and player.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                return hum ~= nil and hum.Health > 0 and char:FindFirstChild("HumanoidRootPart") ~= nil
            end

            local magnet, aimOn, bound = false, false, false

            local function aimWanted()
                if aimOn and keyActive("Aim_Global_Key") then return true end
                return magnet and keyActive("Trigger_Global_Key")
            end

            local step
            local function refreshBind()
                local want = aimOn or magnet
                if want == bound then return end
                bound = want
                if want then
                    lockedPlayer, lastPlayer, accX, accY = nil, nil, 0, 0
                    RunService:BindToRenderStep(name, Enum.RenderPriority.Camera.Value + 1, function(dt)
                        local ok, err = pcall(step, dt)
                        if not ok then warnf("aim assist error:", err) end
                    end)
                else
                    pcall(function() RunService:UnbindFromRenderStep(name) end)
                    lockedPlayer, lastPlayer = nil, nil
                end
            end

            Actions.aimMagnet = function(on)
                magnet = on and true or false
                refreshBind()
            end

            function step(dt)
                local cam = Camera()
                local _, _, root = localParts()
                if not cam or not root or typing() or not aimWanted() then
                    lockedPlayer, lastPlayer = nil, nil
                    accX, accY = 0, 0
                    return
                end
                local ref = aimRef()
                if flag("aim_only_shoot", false) then
                    local tool = Actions.gunTool and Actions.gunTool()
                    local shooting = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) or (tool ~= nil and tool:GetAttribute("Local_IsShooting") == true)
                    if not shooting then return end
                end
                local human = flag("aim_human", false)
                if human and flag("aim_method", "Camera") == "Camera" then
                    local limit = flag("aim_flick", 80)
                    if limit > 0 and UserInputService:GetMouseDelta().Magnitude > limit then pauseUntil = clock() + 0.18 end
                    if clock() < pauseUntil then return end
                end
                local magnetOnly = not (aimOn and keyActive("Aim_Global_Key"))
                local opts = { current = lastPlayer }
                if magnetOnly then
                    local magnetFov = flag("trigger_magnet_fov", 0)
                    if magnetFov > 0 then opts.fov = magnetFov end
                end
                if flag("aim_lock", false) and lockedPlayer and valid(lockedPlayer) then
                    opts.only = lockedPlayer
                    opts.ignoreFov = true
                end
                local eye = root.Parent and root.Parent:FindFirstChild("Head")
                local entity, part, _, pickedPoint = selectTarget("aim", ref, eye and eye.Position or root.Position, opts)
                if not entity then
                    lockedPlayer, lastPlayer = nil, nil
                    return
                end
                if lastPlayer ~= entity.Player then
                    lastPlayer = entity.Player
                    acquiredAt = clock()
                end
                if flag("aim_lock", false) then lockedPlayer = entity.Player end
                local held = clock() - acquiredAt
                if held < flag("aim_reaction", 0) / 1000 then return end

                local alpha = 1
                if flag("aim_smooth", true) then
                    local first, last, inc = flag("aim_smooth_start", 85), flag("aim_smooth_end", 20), flag("aim_smooth_inc", 50)
                    local smoothing = first > last and math.max(last, first - inc * held) or math.min(last, first + inc * held)
                    smoothing += (rand:NextNumber() * 2 - 1) * flag("aim_smooth_rand", 5)
                    smoothing = math.clamp(smoothing, 0, 99)
                    alpha = 1 - (smoothing / 100) ^ (math.min(dt, 0.1) * 60)
                end

                if magnetOnly then alpha *= flag("trigger_magnet_str", 100) / 100 end
                local goal = pickedPoint or part.Position
                local eyePos = eye and eye.Position or root.Position
                if flag("aim_pred", false) and Actions.predict and entity.Character then
                    local okP, predicted = pcall(Actions.predict.point, entity.Character, part, eyePos, "aim")
                    if okP and typeof(predicted) == "Vector3" then goal += predicted - part.Position end
                end
                local missChance = flag("aim_miss", 0)
                if missChance > 0 then
                    local nowT = clock()
                    if nowT >= missRoll then
                        missRoll = nowT + 0.7
                        if rand:NextNumber() * 100 < missChance then
                            local offset = Vector3.new(rand:NextNumber() * 2 - 1, rand:NextNumber() * 2 - 1, rand:NextNumber() * 2 - 1)
                            missOff = offset.Magnitude > 0.01 and offset.Unit * flag("aim_miss_size", 2.5) or Vector3.zero
                        else
                            missOff = Vector3.zero
                        end
                    end
                    goal += missOff
                end
                local method = flag("aim_method", "Camera")
                if method == "Mouse" and type(mousemoverel) ~= "function" then
                    if not warned then
                        warned = true
                        say("mousemoverel is not available, using the camera instead")
                    end
                    method = "Camera"
                end
                local screenPoint = cam:WorldToViewportPoint(goal)
                local goalScreen = Vector2.new(screenPoint.X, screenPoint.Y)
                if human then
                    local delta = goalScreen - ref
                    local len = delta.Magnitude
                    if len > 1 then
                        if acquiredAt ~= humanFor then
                            humanFor = acquiredAt
                            bend = (rand:NextNumber() * 0.5 + 0.5) * (rand:NextNumber() < 0.5 and -1 or 1)
                            over = rand:NextNumber()
                            startLen = len
                        end
                        local dir = delta / len
                        local perp = Vector2.new(-dir.Y, dir.X)
                        local fade = math.clamp(len / math.max(startLen, 1), 0, 1)
                        local shifted = delta + perp * (len * bend * flag("aim_curve", 20) / 100 * fade)
                        shifted += dir * (startLen * over * flag("aim_over", 15) / 100 * math.max(0, 1 - held / 0.3))
                        local jitter = flag("aim_jitter", 1.5)
                        shifted += Vector2.new(rand:NextNumber() * 2 - 1, rand:NextNumber() * 2 - 1) * jitter
                        alpha *= 0.55 + 0.45 * math.clamp(len / math.max(flag("aim_fov", 120), 1), 0, 1)
                        goalScreen = ref + shifted
                        if method ~= "Mouse" then
                            local ray = cam:ViewportPointToRay(goalScreen.X, goalScreen.Y)
                            goal = ray.Origin + ray.Direction * (goal - cam.CFrame.Position).Magnitude
                        end
                    end
                end
                if method == "Mouse" then
                    accX += (goalScreen.X - ref.X) * alpha
                    accY += (goalScreen.Y - ref.Y) * alpha
                    local ix = accX >= 0 and math.floor(accX) or math.ceil(accX)
                    local iy = accY >= 0 and math.floor(accY) or math.ceil(accY)
                    accX -= ix
                    accY -= iy
                    if ix ~= 0 or iy ~= 0 then pcall(mousemoverel, ix, iy) end
                else
                    cam.CFrame = cam.CFrame:Lerp(CFrame.lookAt(cam.CFrame.Position, goal), alpha)
                end
            end

            feature("Aim_Global_Enabled", function()
                aimOn = true
                refreshBind()
            end, function()
                aimOn = false
                refreshBind()
            end)

            onUnload(function()
                magnet, aimOn = false, false
                refreshBind()
            end)
        end

        local WB = { cache = {}, ray = RaycastParams.new(), overlap = OverlapParams.new(), history = {}, moved = 0 }
        WB.ray.FilterType = Enum.RaycastFilterType.Exclude
        WB.overlap.FilterType = Enum.RaycastFilterType.Exclude
        pcall(function()
            WB.ray.CollisionGroup = "ClientBullet"
            WB.overlap.CollisionGroup = "ClientBullet"
        end)
        local OFFSETS_NEAR = {
            v3(0, 1, 0), v3(1, 0, 0), v3(0.7, -0.5, -0.5), v3(-0.1, -0.8, -0.8), v3(-0.8, -0.5, -0.5), v3(-1, 0, 0),
            v3(-0.8, 0.4, 0.4), v3(0, 0.7, 0.7), v3(0.7, 0.5, 0.5), v3(1, 0, 0), v3(0.7, 0, -0.8), v3(-0.1, 0, -1),
            v3(-0.8, 0, -0.8), v3(-1, 0, 0), v3(-0.8, 0, 0.7), v3(0, 0, 1), v3(0.7, 0, 0.7), v3(1, 0, 0),
            v3(0.7, 0.4, -0.5), v3(-0.1, 0.7, -0.8), v3(-0.8, 0.4, -0.5), v3(-1, -0.1, 0), v3(-0.8, -0.5, 0.4),
            v3(0, -0.8, 0.7), v3(0.7, -0.6, 0.5), v3(0, -1, 0),
        }
        local OFFSETS_HIGH = {
            v3(0, 3, 0), v3(0, 5, 0), v3(0, 7, 0), v3(0, 10, 0),
            v3(1, 3, 0), v3(-1, 3, 0), v3(0, 3, 1), v3(0, 3, -1),
            v3(1, 5, 0), v3(-1, 5, 0), v3(0, 5, 1), v3(0, 5, -1),
            v3(1, 7, 0), v3(-1, 7, 0), v3(0, 7, 1), v3(0, 7, -1),
            v3(1, 10, 0), v3(-1, 10, 0), v3(0, 10, 1), v3(0, 10, -1),
            v3(0.7, 3, 0.7), v3(-0.7, 3, 0.7), v3(0.7, 3, -0.7), v3(-0.7, 3, -0.7),
            v3(0.7, 5, 0.7), v3(-0.7, 5, 0.7), v3(0.7, 5, -0.7), v3(-0.7, 5, -0.7),
            v3(0.7, 7, 0.7), v3(-0.7, 7, 0.7), v3(0.7, 7, -0.7), v3(-0.7, 7, -0.7),
            v3(0.7, 10, 0.7), v3(-0.7, 10, 0.7), v3(0.7, 10, -0.7), v3(-0.7, 10, -0.7),
            v3(0, 15, 0), v3(1, 15, 0), v3(-1, 15, 0), v3(0, 15, 1), v3(0, 15, -1),
        }

        local ignoreList = {}
        function WB.updateIgnore()
            local list = {}
            if LocalPlayer.Character then list[#list + 1] = LocalPlayer.Character end
            for _, player in ipairs(Players:GetPlayers()) do
                if player.Character then list[#list + 1] = player.Character end
            end
            local cars = workspace:FindFirstChild("CarContainer")
            if cars and flag("gun_vehicle_wallbang", false) then list[#list + 1] = cars end
            local same = #list == #ignoreList
            if same then
                for i = 1, #list do
                    if list[i] ~= ignoreList[i] then
                        same = false
                        break
                    end
                end
            end
            if same then return end
            ignoreList = list
            WB.ray.FilterDescendantsInstances = list
            WB.overlap.FilterDescendantsInstances = list
        end

        local function freeSpace(position)
            for _, part in ipairs(workspace:GetPartBoundsInRadius(position, 0, WB.overlap)) do
                if part.CanCollide and (part:GetClosestPointOnSurface(position) - position).Magnitude <= 0.0001 then
                    return false
                end
            end
            return true
        end

        local FLAT = Vector3.new(1, 0, 1)

        local function radius()
            return math.clamp(flag("wb_radius", 6), 1, 10)
        end

        local function lookFlat(shooterPos, targetPos)
            local flatDelta = (shooterPos - targetPos) * FLAT
            if flatDelta.Magnitude > 0.001 then
                return CFrame.lookAt(shooterPos * FLAT, targetPos * FLAT).LookVector
            end
            return v3(0, 0, -1)
        end

        local function pointsAround(center, look, scales)
            local list = {}
            for _, normalId in ipairs(Enum.NormalId:GetEnumItems()) do
                local normal = Vector3.fromNormalId(normalId)
                if (normal * FLAT):Dot(-look) > -0.5 then
                    for _, scale in ipairs(scales) do
                        local position = center + normal * scale
                        if freeSpace(position) then list[#list + 1] = position end
                    end
                end
            end
            return list
        end

        local function originsAround(center, look, scales, sets)
            local list = {}
            for _, scale in ipairs(scales) do
                for _, set in ipairs(sets) do
                    for _, offset in ipairs(set) do
                        if (offset * FLAT):Dot(look) > -0.5 then list[#list + 1] = center + offset * scale end
                    end
                end
            end
            return list
        end

        local function byDistance(list, from)
            local ranked = {}
            for index, position in ipairs(list) do ranked[index] = { position, (position - from).Magnitude, index } end
            table.sort(ranked, function(a, b)
                if a[2] ~= b[2] then return a[2] < b[2] end
                return a[3] < b[3]
            end)
            for index, entry in ipairs(ranked) do list[index] = entry[1] end
            return list
        end

        WB.filter = nil
        function WB.accept(origin, target)
            local f = WB.filter
            if not f then return true end
            if (origin - f.shooter).Magnitude > f.spot then return false end
            if (target - f.center).Magnitude > f.spot then return false end
            if f.range and (target - origin).Magnitude > f.range then return false end
            return true
        end

        local function firstClear(targets, origins)
            for _, target in ipairs(targets) do
                for _, origin in ipairs(origins) do
                    if WB.accept(origin, target) and not workspace:Raycast(target, origin - target, WB.ray) and freeSpace(origin) then
                        return origin, target
                    end
                end
            end
            return nil
        end

        local function append(into, list)
            for _, item in ipairs(list) do into[#into + 1] = item end
        end

        local METHODS = {}

        local LEGACY = { ["awp"] = "Aster Origin", ["awp v2"] = "Aster Reach", ["awp v2.1"] = "Aster Precise" }

        METHODS["Vape V4"] = function(shooter, target, surface, center, hitbox)
            local reach = radius() - math.min(WB.moved, 1)
            local look = lookFlat(shooter, target)
            local targets = {}
            if freeSpace(target) then
                if surface and (shooter - surface).Magnitude < 7.5 and WB.accept(surface, target) then return surface, target end
                targets[1] = target
            end
            if hitbox then append(targets, pointsAround(center, look, { 7.4 })) end
            local origins = { shooter }
            for _, position in ipairs(originsAround(shooter, look, { reach }, { OFFSETS_NEAR })) do
                if freeSpace(position) then origins[#origins + 1] = position end
            end
            return firstClear(targets, origins)
        end

        METHODS["Aster Origin"] = function(shooter, target, surface, center, hitbox)
            local reach = radius() - math.min(WB.moved, 1)
            local look = lookFlat(shooter, target)
            local origins = originsAround(shooter, look, { reach }, { OFFSETS_NEAR, OFFSETS_HIGH })
            origins[#origins + 1] = shooter
            byDistance(origins, shooter)
            if surface and (surface - shooter).Magnitude <= reach + 1.5 then table.insert(origins, 1, surface) end
            local targets = { target }
            if hitbox then append(targets, pointsAround(center, look, { radius() })) end
            return firstClear(targets, origins)
        end

        METHODS["Aster Reach"] = function(shooter, target, surface, center, hitbox)
            local reach = radius()
            local look = lookFlat(shooter, target)
            local origins = originsAround(shooter, look, { reach, reach * 2 }, { OFFSETS_NEAR, OFFSETS_HIGH })
            if surface then table.insert(origins, 1, surface) end
            local targets = { target }
            if hitbox then append(targets, pointsAround(center, look, { reach, reach * 2 })) end
            return firstClear(targets, origins)
        end

        METHODS["Aster Precise"] = function(shooter, target, surface, center, hitbox)
            local reach = radius()
            local look = lookFlat(shooter, target)
            local targets = { target }
            if hitbox then append(targets, pointsAround(center, look, { reach })) end

            local near, far = {}, {}
            local function add(position)
                if #near + #far >= 100 then return end
                local distance = (position - shooter).Magnitude
                if distance <= reach then near[#near + 1] = position
                elseif distance <= reach * 2 then far[#far + 1] = position end
            end

            add(shooter)
            if surface then add(surface) end

            local walk = RaycastParams.new()
            walk.FilterType = Enum.RaycastFilterType.Exclude
            pcall(function() walk.CollisionGroup = "ClientBullet" end)
            local skip = table.clone(WB.ray.FilterDescendantsInstances)
            walk.FilterDescendantsInstances = skip
            local back = shooter - target
            local side = back.Magnitude > 0.001 and back.Unit:Cross(v3(0, 1, 0)) or v3(1, 0, 0)
            side = side.Magnitude > 0.01 and side.Unit or v3(1, 0, 0)
            for _ = 1, 6 do
                local hit = workspace:Raycast(target, back, walk)
                if not hit then break end
                local front = hit.Position + hit.Normal * 0.05
                add(front)
                for _, shift in ipairs({ -3, -1.5, 1.5, 3 }) do add(front + side * shift) end
                skip[#skip + 1] = hit.Instance
                walk.FilterDescendantsInstances = skip
            end

            local toTarget = target - shooter
            local lineLength = toTarget.Magnitude
            if lineLength > 0.001 then
                local unit = toTarget / lineLength
                for step = 1, math.floor(math.min(reach * 2, lineLength)) do add(shooter + unit * step) end
            end
            for _, position in ipairs(originsAround(shooter, look, { reach * 0.5, reach }, { OFFSETS_NEAR })) do add(position) end

            byDistance(near, shooter)
            byDistance(far, shooter)
            append(near, far)
            return firstClear(targets, near)
        end

        local ALT_PARTS = { "Head", "UpperTorso", "Torso", "LowerTorso", "HumanoidRootPart", "LeftUpperArm", "RightUpperArm",
            "Left Arm", "Right Arm", "LeftUpperLeg", "RightUpperLeg", "Left Leg", "Right Leg" }
        local function altParts(char, except)
            local list = {}
            for _, name in ipairs(ALT_PARTS) do
                local candidate = char:FindFirstChild(name)
                if candidate and candidate ~= except and candidate:IsA("BasePart") then list[#list + 1] = candidate end
            end
            return list
        end

        local function wallbangPlan(origin, part, root, override)
            local position = part.Position
            local cached
            if not override then cached = WB.cache[part] end
            if cached == false then return nil end
            if cached then return "moved", cached[1], cached[2] end

            local blocked = workspace:Raycast(position, origin - position, WB.ray)
            if not blocked and not workspace:Raycast(origin, position - origin, WB.ray) then return "clear" end

            local shooter = override or Actions.sp.shooter(root)
            local anchor = part.Parent and part.Parent:FindFirstChild("HumanoidRootPart")
            local center = anchor and anchor.Position or position
            local method = LEGACY[flag("wb_method", "Aster Reach")] or flag("wb_method", "Aster Reach")
            local scan = METHODS[method] or METHODS["Aster Reach"]

            local data = Gun.data()
            WB.filter = flag("wb_damage", true) and {
                shooter = shooter, center = center, spot = flag("wb_spot", 7.5),
                range = Gun.range(data),
            } or nil
            local newOrigin, newTarget = scan(shooter, position, blocked and (blocked.Position + blocked.Normal * 0.01) or nil, center, flag("wb_hitbox", true))

            if not newOrigin and (method == "Aster Reach" or method == "Aster Precise") then
                local delta = position - shooter
                local dist = delta.Magnitude
                if dist > 0.5 then
                    local unit = delta.Unit
                    local flat = WB.filter and math.sqrt(unit.X * unit.X + unit.Z * unit.Z)
                    for i = 2, math.min(dist, 160), 2 do
                        if flat and i * flat - 0.5 > WB.filter.spot + 0.001 then break end
                        local ground = workspace:Raycast(shooter + unit * i, v3(0, -50, 0), WB.ray)
                        if ground then
                            local at = ground.Position + ground.Normal * 0.5
                            if WB.accept(at, position) and not workspace:Raycast(at, position - at, WB.ray) and freeSpace(at) then
                                newOrigin, newTarget = at, position
                                break
                            end
                        end
                    end
                end
                if not newOrigin then
                    for i = 3, 18, 3 do
                        local at = shooter + v3(0, i, 0)
                        if WB.accept(at, position) and not workspace:Raycast(at, position - at, WB.ray) and freeSpace(at) then
                            newOrigin, newTarget = at, position
                            break
                        end
                    end
                end
            end

            WB.filter = nil
            if newOrigin then
                if not override then WB.cache[part] = { newOrigin, newTarget } end
                return "moved", newOrigin, newTarget
            end
            if not override then WB.cache[part] = false end
            return nil
        end

        WB.lastTick = 0
        function WB.tick()
            local now = clock()
            if now - WB.lastTick > 0.15 then
                WB.lastTick = now
                table.clear(WB.cache)
                WB.updateIgnore()
            end
        end

        function WB.status(origin, part, shooter)
            local _, _, root = localParts()
            if not root or not part or not part.Parent then return "blocked" end
            local plan = wallbangPlan(origin, part, root, shooter)
            if plan == "clear" then return "visible" end
            if plan == "moved" then return "wallbang" end
            return "blocked"
        end

        Actions.probe = { Gun = Gun, WB = WB, plan = wallbangPlan }

        local Predict = {}
        Actions.predict = Predict
        do
            local tracks = {}
            local MAXAGE = 0.45
            local conn = RunService.Heartbeat:Connect(function()
                if not (flag("silent_pred", false) or flag("rb_pred", false) or flag("aim_pred", false) or (Actions.rage and Actions.rage.tune and Actions.rage.tune.force)) then
                    if next(tracks) then table.clear(tracks) end
                    return
                end
                local now = clock()
                for _, other in ipairs(Players:GetPlayers()) do
                    if other ~= LocalPlayer then
                        local root = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
                        if root then
                            local list = tracks[other]
                            if not list then list = {} tracks[other] = list end
                            list[#list + 1] = { now, root.Position }
                            while #list > 0 and now - list[1][1] > MAXAGE do table.remove(list, 1) end
                        else
                            tracks[other] = nil
                        end
                    end
                end
            end)
            onUnload(function() conn:Disconnect() end)

            -- returns velocity, change (how much the velocity changed over the window)
            function Predict.velocity(player, root)
                local list = tracks[player]
                local assembly = root and root.AssemblyLinearVelocity or ZERO
                if not list or #list < 3 then return assembly, 0 end
                local first, last = list[1], list[#list]
                local span = last[1] - first[1]
                if span < 0.08 then return assembly, 0 end
                local velocity = (last[2] - first[2]) / span
                local mid = list[math.ceil(#list / 2)]
                local change = 0
                if mid[1] - first[1] > 0.03 and last[1] - mid[1] > 0.03 then
                    local a = (mid[2] - first[2]) / (mid[1] - first[1])
                    local b = (last[2] - mid[2]) / (last[1] - mid[1])
                    change = (b - a).Magnitude
                end
                if assembly.Magnitude > velocity.Magnitude * 1.6 and assembly.Magnitude < 400 then velocity = assembly end
                return velocity, change
            end

            function Predict.ping()
                local ms
                pcall(function()
                    ms = game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()
                end)
                if type(ms) ~= "number" or ms ~= ms or ms <= 0 then
                    local ok, one = pcall(function() return LocalPlayer:GetNetworkPing() end)
                    ms = ok and type(one) == "number" and one * 2000 or 100
                end
                return math.clamp(ms, 0, 800) / 1000
            end

            function Predict.lead(prefix)
                local lead
                if flag(prefix .. "_pred_auto", true) then
                    lead = Predict.ping() * 0.75 + flag(prefix .. "_pred_extra", 0.02)
                else
                    lead = flag(prefix .. "_pred_base", 0.07)
                end
                return math.clamp(lead * (flag(prefix .. "_pred_mult", 1) + (prefix == "rb" and Predict.boost or 0)), 0, 1)
            end

            -- returns aimPosition, note, valid
            function Predict.point(char, part, origin, prefix)
                local position = part.Position
                local player = Players:GetPlayerFromCharacter(char)
                local root = char:FindFirstChild("HumanoidRootPart")
                if not player or not root then return position, "no track", false end
                local velocity, change = Predict.velocity(player, root)
                if velocity.Magnitude < 1.5 then return position, "standing", true end
                local humanoid = char:FindFirstChildOfClass("Humanoid")
                if humanoid and humanoid.FloorMaterial ~= Enum.Material.Air and math.abs(velocity.Y) < 14 then
                    velocity = v3(velocity.X, 0, velocity.Z)
                end
                local check = flag(prefix .. "_pred_check", true)
                local offset = velocity * Predict.lead(prefix)
                local note = string.format("%d st/s", math.floor(velocity.Magnitude))
                if check and change > flag(prefix .. "_pred_erratic", 45) then
                    offset = offset * 0.4
                    note = note .. ", erratic"
                end
                local cap = flag(prefix .. "_pred_cap", 25)
                if offset.Magnitude > cap then offset = offset.Unit * cap end
                local goal = position + offset
                if not check then return goal, note, true end

                pcall(WB.updateIgnore)
                local wall = workspace:Raycast(position, offset, WB.ray)
                if wall then
                    goal = wall.Position - offset.Unit * 0.6
                    note = note .. ", wall clamp"
                end
                if typeof(origin) == "Vector3" then
                    local range = Gun.range(Gun.data())
                    if range and (goal - origin).Magnitude > range then
                        return position, note .. ", out of range", false
                    end
                    local seenNow = not workspace:Raycast(origin, position - origin, WB.ray)
                    if seenNow and workspace:Raycast(origin, goal - origin, WB.ray) then
                        return position, note .. ", no line", false
                    end
                end
                return goal, note, true
            end
        end

        do
            local bag = newBag()
            local hookedCast, original = nil, nil
            local wants = { silent = false, fx = false, auto = false, assist = false, rage = false }
            local autoNext, loopToken, warnedStack = 0, 0, false
            local lastOrigin, lastNew

            local function silentActive()
                return flag("Silent_Global_Enabled", false) and keyActive("Silent_Global_Key")
            end

            local function anyWanted()
                return wants.silent or wants.fx or wants.auto or wants.assist or wants.rage
            end

            local function redirect(...)
                local origin = ...

                local force = Gun.force
                if force then
                    force.left = (force.left or 1) - 1
                    if force.left <= 0 or clock() >= force.expires then Gun.force = nil end
                    if clock() < force.expires and force.part.Parent then
                        local forcedPart = force.part
                        local _, _, forcedRoot = localParts()
                        if typeof(origin) == "Vector3" and forcedRoot and flag("rb_wallbang", true) then
                            WB.updateIgnore()
                            local status, moved, moveHit = wallbangPlan(origin, forcedPart, forcedRoot)
                            if not status and forcedPart.Parent then
                                for _, alt in ipairs(altParts(forcedPart.Parent, forcedPart)) do
                                    status, moved, moveHit = wallbangPlan(origin, alt, forcedRoot)
                                    if status then forcedPart = alt break end
                                end
                            end
                            if status == "moved" then
                                lastOrigin, lastNew = origin, moved
                                return forcedPart, moveHit or forcedPart.Position
                            end
                        end
                        return forcedPart, force.pos
                    end
                end

                if typeof(origin) ~= "Vector3" then return original(...) end
                local silentOn = wants.silent and silentActive()

                local A = Actions.sp.assist
                local assisted = not silentOn and wants.assist and A.part ~= nil and A.part.Parent ~= nil and clock() < (A.partUntil or 0)
                if not silentOn and not assisted then return original(...) end
                if silentOn and rand:NextNumber(0, 100) > flag("Silent_Global_HitChance", 100) then return original(...) end

                local data = Gun.data()
                local taser = data and data.Behavior == "Taser"
                local wallbang = flag("silent_wallbang", false)
                local entity, part, pickedPoint
                if assisted then
                    entity, part, wallbang = { Character = A.part.Parent }, A.part, true
                else
                    entity, part, _, pickedPoint = selectTarget("silent", aimRef(), origin, {
                        limit = Gun.range(data) or 1000,
                        ignoreDown = taser,
                        skipWall = wallbang,
                    })
                end
                if not entity then return original(...) end

                local args = table.pack(...)
                local _, _, myRoot = localParts()
                local usePart, newOrigin, hit = part, nil, nil
                if wallbang and myRoot then
                    WB.updateIgnore()
                    local status, moved, moveHit = wallbangPlan(origin, part, myRoot)
                    if not status then
                        for _, alt in ipairs(altParts(entity.Character, part)) do
                            status, moved, moveHit = wallbangPlan(origin, alt, myRoot)
                            if status then usePart = alt break end
                        end
                    end
                    if status == "moved" then
                        newOrigin, hit = moved, moveHit
                    elseif not status and flag("silent_wall", false) then
                        return original(...)
                    end
                end
                local aimPos = usePart.Position
                if pickedPoint and usePart == part then aimPos = pickedPoint end
                if silentOn and not assisted and flag("silent_pred", false) then
                    local okP, predicted, note = pcall(Predict.point, entity.Character, usePart, newOrigin or origin, "silent")
                    if okP and typeof(predicted) == "Vector3" then
                        aimPos += predicted - usePart.Position
                        Predict.note = note
                    end
                end
                if newOrigin then
                    lastOrigin, lastNew = origin, newOrigin
                    return usePart, (hit and (hit + (aimPos - usePart.Position))) or aimPos
                end
                args[2] = aimPos
                return original(table.unpack(args, 1, args.n))
            end

            local hookFn
            hookFn = function(...)
                lastOrigin, lastNew = nil, nil
                local packed = table.pack(pcall(redirect, ...))
                local results
                if packed[1] then
                    results = table.pack(table.unpack(packed, 2, packed.n))
                else
                    results = table.pack(original(...))
                end

                local fromPos, toPos = lastOrigin, lastNew
                if fromPos and toPos and type(debug) == "table" and type(debug.getstack) == "function" and type(debug.setstack) == "function" then
                    local replaced = 0
                    local function sweep(strict)
                        pcall(function()
                            local scanner = debug.info(1, "f")
                            for level = 2, 14 do
                                local fn = debug.info(level, "f")
                                local isTarget
                                if strict then
                                    isTarget = Gun.shoot ~= nil and fn == Gun.shoot
                                else
                                    isTarget = level >= 3 and type(fn) == "function" and fn ~= hookFn and fn ~= scanner
                                end
                                if isTarget then
                                    for index, value in debug.getstack(level) do
                                        if value == fromPos then
                                            debug.setstack(level, index, toPos)
                                            replaced += 1
                                        end
                                    end
                                end
                            end
                        end)
                    end
                    sweep(true)
                    if replaced == 0 then sweep(false) end
                    if replaced == 0 and not warnedStack then
                        warnedStack = true
                        warnf("wallbang: the shot origin could not be rewritten (needs debug.getstack and debug.setstack)")
                    end
                end

                local listeners = ShotEvents.cast
                for i = 1, #listeners do pcall(listeners[i], results[1], results[2]) end
                return table.unpack(results, 1, results.n)
            end

            local function unhook()
                if hookedCast and original then
                    pcall(function()
                        if type(restorefunction) == "function" then restorefunction(hookedCast)
                        else hookfunction(hookedCast, original) end
                    end)
                end
                hookedCast, original = nil, nil
            end

            local function install()
                if not Gun.find() then return false end
                if hookedCast == Gun.cast then return true end
                unhook()
                if type(hookfunction) ~= "function" then return false end
                local ok, old = pcall(hookfunction, Gun.cast, hookFn)
                if not ok or type(old) ~= "function" then return false end
                hookedCast, original = Gun.cast, old
                return true
            end

            local function refresh()
                loopToken += 1
                local mine = loopToken
                if not anyWanted() then
                    unhook()
                    return
                end
                task.spawn(function()
                    local tries = 0
                    while mine == loopToken and anyWanted() do
                        if install() then
                            tries = 0
                        else
                            tries += 1
                            if tries > 20 then
                                say("The gun could not be hooked (needs getconnections or filtergc, debug.getupvalue and hookfunction)")
                                if wants.silent then switchOff("Silent_Global_Enabled") end
                                return
                            end
                        end
                        task.wait(hookedCast and 2 or 1)
                    end
                end)
            end

            ShotEvents.hooked = function() return hookedCast ~= nil end
            Actions.fxHook = function(on)
                wants.fx = on and true or false
                refresh()
            end
            Actions.assistHook = function(on)
                wants.assist = on and true or false
                refresh()
            end
            Actions.autoHook = function(on)
                wants.auto = on and true or false
                refresh()
            end

            Actions.rageHook = function(on)
                wants.rage = on and true or false
                refresh()
            end
            Actions.readyGun = readyGun
            Actions.gunTool = equippedGun

            Actions.fireAt = function(part, position)
                if not part or not part.Parent then return false end
                if not hookedCast then
                    if not Gun.find() or not install() then return false end
                end
                local data = Gun.data()
                Gun.force = { part = part, pos = position or part.Position, expires = clock() + 0.6, left = math.max(math.floor(tonumber(data and data.ProjectileCount) or 1), 1) }
                fireGun()
                return true
            end

            local SWITCH_ORDER = {
                { label = "AK-47", tools = { "ak47" } },
                { label = "M4A1", tools = { "m4a1", "m4" } },
                { label = "MP5", tools = { "mp5" } },
                { label = "FAL", tools = { "fal" } },
                { label = "Remington 870", tools = { "remington870", "r870", "remington" } },
                { label = "M700", tools = { "m700" } },
                { label = "M9", tools = { "m9" } },
                { label = "Revolver", tools = { "revolver" } },
                { label = "Taser", tools = { "taser" } },
            }
            local switchNext = 0

            local function pickedIn(value, key)
                if type(value) ~= "table" then return false end
                if value[key] == true then return true end
                for _, chosen in pairs(value) do
                    if chosen == key then return true end
                end
                return false
            end

            local function toolFor(entry, holders)
                for _, holder in ipairs(holders) do
                    for _, child in ipairs(holder:GetChildren()) do
                        if child:IsA("Tool") then
                            local name = fxKey(child.Name)
                            for _, alias in ipairs(entry.tools) do
                                if name == alias then return child end
                            end
                        end
                    end
                end
                return nil
            end

            local function autoSwitch(now, head)
                if now < switchNext then return end
                local chosen = flag("silent_switch_weapons", {})
                local order = {}
                for _, entry in ipairs(SWITCH_ORDER) do
                    if pickedIn(chosen, entry.label) then order[#order + 1] = entry end
                end
                if #order == 0 then return end
                local entity = selectTarget("silent", aimRef(), head.Position, { limit = 1000, ignoreDown = false, skipWall = flag("silent_wallbang", false) })
                if not entity then return end
                switchNext = now + math.max(flag("silent_switch_delay", 0.3), 0.03)
                local character = LocalPlayer.Character
                local hum = character and character:FindFirstChildOfClass("Humanoid")
                if not hum then return end
                local current = character:FindFirstChildOfClass("Tool")
                local holders = { character }
                local pack = LocalPlayer:FindFirstChildOfClass("Backpack")
                if pack then holders[#holders + 1] = pack end
                local available = {}
                for _, entry in ipairs(order) do
                    local tool = toolFor(entry, holders)
                    if tool then available[#available + 1] = tool end
                end
                if #available == 0 then return end
                local index = 0
                for position, tool in ipairs(available) do
                    if tool == current then index = position break end
                end
                for step = 1, #available do
                    local candidate = available[(index + step - 1) % #available + 1]
                    local ammo = candidate:GetAttribute("Local_CurrentAmmo")
                    if candidate ~= current and (ammo == nil or ammo > 0) then
                        hum:EquipTool(candidate)
                        return
                    end
                end
            end

            feature("Silent_Global_Enabled", function()
                wants.silent = true
                refresh()
                local lastClear = 0
                bag.add(RunService.Heartbeat:Connect(function()
                    local now = clock()
                    if now - lastClear > 0.15 then
                        lastClear = now
                        table.clear(WB.cache)
                        WB.updateIgnore()
                    end
                    local _, _, mover = localParts()
                    if mover then
                        local history = WB.history
                        history[#history + 1] = { Actions.sp.realPos(mover), now }
                        while #history > 1 and now - history[1][2] > 0.1 do table.remove(history, 1) end
                        WB.moved = (history[#history][1] - history[1][1]).Magnitude
                    end
                    if flag("silent_autofire", false) and silentActive() and now >= autoNext and not typing() then
                        autoNext = now + 1 / math.max(flag("silent_autofire_rate", 15), 1)
                        local _, _, root = localParts()
                        local cam = Camera()
                        local head = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Head")
                        if root and cam and head and flag("silent_switch", false) then pcall(autoSwitch, now, head) end
                        if root and cam and head and readyGun() then
                            local data = Gun.data()
                            local entity, part = selectTarget("silent", aimRef(), head.Position, {
                                limit = Gun.range(data) or 1000,
                                ignoreDown = data and data.Behavior == "Taser",
                                skipWall = flag("silent_wallbang", false),
                            })

                            if entity and part and flag("silent_wallbang", false) and flag("silent_autofire_check", true) then
                                WB.tick()
                                if WB.status(head.Position, part) == "blocked" then entity = nil end
                            end
                            if entity then
                                Actions.lastAutoShot = clock()
                                fireGun()
                            end
                        end
                    end
                end))
            end, function()
                bag.clear()
                wants.silent = false
                refresh()
            end)

            onUnload(function()
                wants.silent, wants.fx, wants.auto, wants.assist, wants.rage = false, false, false, false, false
                loopToken += 1
                unhook()
                ShotEvents.hooked = nil
                Actions.fxHook, Actions.autoHook, Actions.assistHook, Actions.rageHook = noop, noop, noop, noop
                Actions.fireAt = function() return false end
            end)
        end

        do
            local R = {
                target = nil, entity = nil, center = nil, vel = ZERO, phase = "peek", lastPhase = "", phaseEnd = 0, peekAt = 0,
                nextShot = 0, voidPos = nil, voidRoll = 0, skip = {}, safe = false, status = "off", lastEval = 0,
                lastHealth = 0, lastDamage = 0, equipAt = 0, reloadAt = 0, getAt = 0, getUntil = 0, viewing = false, shownText = "", randAngle = 0, goal = nil, goalAt = 0, goalFor = nil,
                smart = { state = "waiting", t = nil, timer = 0, health = nil, dropped = false },
                peekMem = setmetatable({}, { __mode = "k" }), peekCount = 0, deathZones = {},
                stat = { shots = 0, hits = 0, misses = 0, missRun = 0, hitRun = 0, why = "", pending = {} },
                tune = { out = 0, delay = 0, boost = 0, force = false, steps = 0 },
            }
            Actions.rage = R
            local bag = newBag()
            local hist = setmetatable({}, { __mode = "k" })
            local statusText
            local errors = 0
            local ALIASES = {
                ["AK-47"] = { "ak47" }, ["M4A1"] = { "m4a1", "m4" }, ["MP5"] = { "mp5" }, ["FAL"] = { "fal" },
                ["Remington 870"] = { "remington870", "r870", "remington" }, ["M700"] = { "m700" }, ["M9"] = { "m9" }, ["Revolver"] = { "revolver" },
            }
            local HEAD_OFFSET = v3(0, 1.5, 0)
            local WEAPON_ORDER = { "AK-47", "M4A1", "MP5", "FAL", "Remington 870", "M700", "M9", "Revolver" }

            local function picked(value, key)
                if type(value) ~= "table" then return false end
                if value[key] == true then return true end
                for _, chosen in pairs(value) do
                    if chosen == key then return true end
                end
                return false
            end

            local function findPlayer(text)
                text = string.lower(tostring(text or ""))
                if text == "" then return nil end
                local partial
                for _, player in ipairs(Players:GetPlayers()) do
                    local name, display = string.lower(player.Name), string.lower(player.DisplayName)
                    if name == text or display == text then return player end
                    if not partial and (string.sub(name, 1, #text) == text or string.sub(display, 1, #text) == text) then partial = player end
                end
                if partial then return partial end
                for _, player in ipairs(Players:GetPlayers()) do
                    if string.find(string.lower(player.Name), text, 1, true) or string.find(string.lower(player.DisplayName), text, 1, true) then return player end
                end
                return nil
            end

            Actions.rageList = function(listFlag, add)
                local option = Options[listFlag]
                if not option or type(option.SetValue) ~= "function" then return end
                if not add then
                    pcall(function() option:SetValue({}) end)
                    return
                end
                local player = findPlayer(flag("rb_search", ""))
                if not player then player = Actions.selectedPlayer and Actions.selectedPlayer() end
                if not player then say("Type a name or select a player in the Players tab first") return end
                local value = {}
                if type(option.Value) == "table" then
                    for key, chosen in pairs(option.Value) do value[key] = chosen end
                end
                value[player.Name] = true
                pcall(function() option:SetValue(value) end)
                say(player.Name .. " added")
            end

            local function addAtCursor()
                if not flag("rb_add", false) or typing() then return end
                local cam = Camera()
                if not cam then return end
                local mouse = UserInputService:GetMouseLocation()
                local best, bestDist
                for _, e in ipairs(otherEntities()) do
                    local screen, onScreen = cam:WorldToViewportPoint(e.Root.Position)
                    if onScreen then
                        local d = (Vector2.new(screen.X, screen.Y) - mouse).Magnitude
                        if d <= 600 and (not bestDist or d < bestDist) then best, bestDist = e.Player, d end
                    end
                end
                if not best then say("No player near the cursor") return end
                local option = Options.rb_targets
                if not option or type(option.SetValue) ~= "function" then return end
                local value = {}
                if type(option.Value) == "table" then
                    for key, chosen in pairs(option.Value) do value[key] = chosen end
                end
                if value[best.Name] then
                    value[best.Name] = nil
                    say(best.Name .. " removed")
                else
                    value[best.Name] = true
                    say(best.Name .. " added")
                end
                pcall(function() option:SetValue(value) end)
            end
            task.defer(function()
                local key = Options.rb_add_key
                if key and type(key.OnClick) == "function" then key:OnClick(addAtCursor) end
            end)

            local function refreshNames()
                local names = {}
                for _, player in ipairs(Players:GetPlayers()) do
                    if player ~= LocalPlayer then names[#names + 1] = player.Name end
                end
                table.sort(names, function(a, b) return a:lower() < b:lower() end)
                for _, listFlag in ipairs({ "rb_targets", "rb_white" }) do
                    local option = Options[listFlag]
                    if option and type(option.SetValues) == "function" then pcall(function() option:SetValues(names) end) end
                end
            end
            track(Players.PlayerAdded:Connect(function() task.defer(refreshNames) end))
            track(Players.PlayerRemoving:Connect(function(player)
                hist[player] = nil
                R.skip[player] = nil
                task.defer(refreshNames)
            end))

            local function inBounds(position)
                local limit = flag("rb_bounds", 8000)
                return math.abs(position.X) < limit and math.abs(position.Z) < limit and position.Y > -400 and position.Y < 4000
            end

            local function centerOf(e)
                local position = e.Root.Position
                local now = clock()
                if inBounds(position) then
                    hist[e.Player] = { pos = position, t = now }
                    return position, e.Root.AssemblyLinearVelocity, true
                end
                if flag("rb_res", false) then
                    local last = hist[e.Player]
                    if last and now - last.t <= flag("rb_res_time", 2) then return last.pos, ZERO, false end
                end
                return nil
            end

            local function noDamage(player)
                if Relations[player.UserId] == "Priority" then return false end
                local mine, theirs = LocalPlayer.Team, player.Team
                if mine and theirs and mine == theirs then return true end
                if not (mine and theirs and mine.Name == "Guards" and theirs.Name == "Inmates") then return false end
                return not (player.Character and player.Character:GetAttribute("Hostile") == true)
            end

            local function usable(e)
                local player = e.Player
                if Relations[player.UserId] == "Friendly" then return false end
                if picked(flag("rb_white", {}), player.Name) then return false end
                local until_ = R.skip[player]
                if until_ and until_ > clock() then return false end
                if flag("rb_team", false) and relationOf(player) == "Friendly" then return false end
                if flag("rb_ff", false) and e.Character:FindFirstChildOfClass("ForceField") then return false end
                if flag("rb_hostile", false) and isPeaceful(player) then return false end
                if flag("rb_skip_nodmg", true) and noDamage(player) then return false end
                if flag("rb_down", false) and (e.Character:GetAttribute("Tased") or e.Character:GetAttribute("Arrested")) then return false end
                return true
            end

            local function pickTarget(realPos)
                local mode = flag("rb_tmode", "Target list")
                if mode ~= "Players tab" then mode = "Target list" end
                local list = flag("rb_targets", {})
                local range = flag("rb_range", 2000)
                local nearby = false
                local nearRange = 0
                local selected = mode == "Players tab" and Actions.selectedPlayer and Actions.selectedPlayer() or nil
                local cam = Camera()
                local mouse = UserInputService:GetMouseLocation()
                local best, bestScore, bestPos, bestVel, bestLive
                for _, e in ipairs(otherEntities()) do
                    if usable(e) then
                        local position, velocity, live = centerOf(e)
                        if position then
                            local distance = (position - realPos).Magnitude
                            local want
                            if mode == "Target list" then
                                want = picked(list, e.Player.Name) or (nearby and distance <= nearRange)
                            elseif mode == "Players tab" then
                                want = selected == e.Player or (nearby and distance <= nearRange)
                            else
                                want = true
                            end
                            if want and distance <= range then
                                local score = distance
                                if mode == "Closest to cursor" and cam then
                                    local screen, onScreen = cam:WorldToViewportPoint(position)
                                    score = onScreen and (Vector2.new(screen.X, screen.Y) - mouse).Magnitude or (1e6 + distance)
                                end
                                if Relations[e.Player.UserId] == "Priority" then score -= 1e7 end
                                if R.target == e.Player then score -= 12 end
                                if flag("rb_ff_deprio", true) and e.Character:FindFirstChildOfClass("ForceField") then score += 1e8 end
                                if not bestScore or score < bestScore then
                                    best, bestScore, bestPos, bestVel, bestLive = e, score, position, velocity, live
                                end
                            end
                        end
                    end
                end
                return best, bestPos, bestVel, bestLive
            end

            local owned, ownedAt = {}, -1
            local function findWeapon(label)
                local aliases = ALIASES[label]
                if not aliases then return nil end
                local now = clock()
                if now - ownedAt > 0.03 then
                    ownedAt = now
                    table.clear(owned)
                    local holders = { LocalPlayer.Character, LocalPlayer:FindFirstChildOfClass("Backpack") }
                    for _, holder in ipairs(holders) do
                        if holder then
                            for _, child in ipairs(holder:GetChildren()) do
                                if child:IsA("Tool") then owned[#owned + 1] = { child, fxKey(child.Name) } end
                            end
                        end
                    end
                end
                for _, entry in ipairs(owned) do
                    for _, alias in ipairs(aliases) do
                        if entry[2] == alias then return entry[1] end
                    end
                end
                return nil
            end

            local function gunState()
                local tool = Actions.gunTool and Actions.gunTool()
                if not tool then return nil, true, false end
                local ammo = tool:GetAttribute("Local_CurrentAmmo")
                local reloading = (tool:GetAttribute("Local_ReloadSession") or 0) > 0
                return tool, (ammo ~= nil and ammo <= 0) or reloading, reloading
            end

            local function randomChoice(list)
                return list[math.random(1, #list)]
            end

            local function mapBounds()
                local now = clock()
                if R.bounds and now - (R.boundsAt or 0) < 90 then return R.bounds end
                if R.boundsBusy then return R.bounds end
                R.boundsBusy = true
                task.spawn(function()
                    local xs, zs = {}, {}
                    local count = 0
                    local ok = pcall(function()
                        for _, part in ipairs(workspace:GetDescendants()) do
                            if part:IsA("BasePart") and part.Anchored and part.Size.Magnitude < 1500 then
                                local position = part.Position
                                if math.abs(position.X) < 20000 and math.abs(position.Z) < 20000 then
                                    xs[#xs + 1] = position.X
                                    zs[#zs + 1] = position.Z
                                end
                            end
                            count += 1
                            if count % 4000 == 0 then task.wait() end
                        end
                    end)
                    if ok and #xs > 20 then
                        table.sort(xs)
                        table.sort(zs)
                        local low, high = math.max(1, math.floor(#xs * 0.01)), math.min(#xs, math.ceil(#xs * 0.99))
                        R.bounds = { minX = xs[low], maxX = xs[high], minZ = zs[low], maxZ = zs[high] }
                    end
                    R.boundsAt = clock()
                    R.boundsBusy = false
                end)
                return R.bounds
            end

            local killParts, killAt, killBusy = {}, -1e9, false
            local function scanKill()
                local now = clock()
                if killBusy or now - killAt < 60 then return end
                killBusy, killAt = true, now
                task.spawn(function()
                    local words = {}
                    for word in string.gmatch(string.lower(tostring(flag("rb_void_safe_names", "kill,lava,death,deadly,acid,hurt,damage,toxic,spike,laser"))), "[^,%s]+") do
                        words[#words + 1] = word
                    end
                    local found, count = {}, 0
                    local function named(text)
                        text = string.lower(text)
                        for _, word in ipairs(words) do
                            if string.find(text, word, 1, true) then return true end
                        end
                        return false
                    end
                    pcall(function()
                        if #words == 0 then return end
                        for _, part in ipairs(workspace:GetDescendants()) do
                            if part:IsA("BasePart") and part.Size.Magnitude < 5000 then
                                local hit = named(part.Name) or (part.Parent ~= nil and part.Parent ~= workspace and named(part.Parent.Name))
                                if hit then
                                    local model = part:FindFirstAncestorOfClass("Model")
                                    if not (model and model:FindFirstChildOfClass("Humanoid")) then
                                        found[#found + 1] = part
                                        if #found >= 500 then break end
                                    end
                                end
                            end
                            count += 1
                            if count % 4000 == 0 then task.wait() end
                        end
                    end)
                    killParts = found
                    killBusy = false
                end)
            end

            local function voidClear(point)
                for _, zone in ipairs(R.deathZones) do
                    if (zone[1] - point).Magnitude < zone[2] then return false end
                end
                local margin = flag("rb_void_safe_margin", 12)
                for _, part in ipairs(killParts) do
                    if part.Parent then
                        local rel = part.CFrame:PointToObjectSpace(point)
                        local half = part.Size / 2
                        if math.abs(rel.X) <= half.X + margin and math.abs(rel.Y) <= half.Y + margin and math.abs(rel.Z) <= half.Z + margin then
                            return false
                        end
                    end
                end
                return true
            end

            local function pickSafe(generate)
                if not flag("rb_void_safe", true) then return generate() end
                scanKill()
                local last
                for _ = 1, 14 do
                    last = generate()
                    if voidClear(last) then return last end
                end
                return last
            end

            local function watchDeaths(addTo)
                local function hook(char)
                    local hum = char:WaitForChild("Humanoid", 5)
                    if not hum then return end
                    hum.Died:Connect(function()
                        if R.voidPos and clock() - (R.voidUsedAt or -100) < 1.5 and #R.deathZones < 30 then
                            R.deathZones[#R.deathZones + 1] = { R.voidPos, flag("rb_void_safe_margin", 12) + 25 }
                            warn("[Aster] void: you died in the void, that spot is avoided from now on")
                        end
                    end)
                end
                if LocalPlayer.Character then task.spawn(hook, LocalPlayer.Character) end
                addTo.add(LocalPlayer.CharacterAdded:Connect(hook))
            end

            local function edgePoint(now)
                local base = R.realPos or ZERO
                local bounds = mapBounds() or { minX = base.X - 500, maxX = base.X + 500, minZ = base.Z - 500, maxZ = base.Z + 500 }
                local margin = flag("rb_edge_margin", 25)
                local x0, x1 = bounds.minX - margin, bounds.maxX + margin
                local z0, z1 = bounds.minZ - margin, bounds.maxZ + margin
                local w, h = math.max(x1 - x0, 10), math.max(z1 - z0, 10)
                local perimeter = 2 * (w + h)
                local jump = flag("rb_edge_jump", 0)
                if jump > 0 and R.edgeD then
                    R.edgeD = (R.edgeD + jump) % perimeter
                else
                    R.edgeD = math.random() * perimeter
                end
                local d = R.edgeD
                local px, pz
                if d < w then px, pz = x0 + d, z0
                elseif d < w + h then px, pz = x1, z0 + (d - w)
                elseif d < 2 * w + h then px, pz = x1 - (d - w - h), z1
                else px, pz = x0, z1 - (d - 2 * w - h) end
                local destroyAt = workspace.FallenPartsDestroyHeight
                if type(destroyAt) ~= "number" or destroyAt ~= destroyAt or destroyAt < -1e5 or destroyAt > 1e4 then destroyAt = -500 end
                local y = math.max(base.Y + flag("rb_edge_y", 0), destroyAt + 30)
                return v3(px, y, pz)
            end

            local function voidPoint(now)
                local currentPattern = flag("rb_pattern", "Under map")
                if R.voidPattern ~= currentPattern then R.voidPattern, R.voidPos = currentPattern, nil end
                if R.voidPos and now - R.voidRoll < flag("rb_switch", 0.05) then return R.voidPos end
                R.voidRoll = now
                local depth = flag("rb_depth", 1)
                local pattern = flag("rb_pattern", "Under map")
                if pattern == "Map edge" then
                    R.voidPos = pickSafe(function() return edgePoint(now) end)
                    return R.voidPos
                end
                if pattern == "Under map" then
                    local base = R.realPos or ZERO
                    local destroyAt = workspace.FallenPartsDestroyHeight
                    if type(destroyAt) ~= "number" or destroyAt ~= destroyAt then destroyAt = -500 end
                    local floorY = math.min(math.max(destroyAt + 30, -2500), base.Y - 10)
                    local span = math.min(math.max(base.Y - 10 - floorY, 0), 250)
                    R.voidPos = pickSafe(function()
                        local angle = math.random() * math.pi * 2
                        local reach = flag("rb_under_radius", 250) * math.sqrt(math.random())
                        return v3(base.X + math.cos(angle) * reach, floorY + math.random() * span, base.Z + math.sin(angle) * reach)
                    end)
                    return R.voidPos
                end
                local main, a, b
                if pattern == "Far" then
                    main = randomChoice({ 2e6, 5e6, 1e7, 2e7, 5e7 }) * depth
                    a = (randomChoice({ 1e5, 2.5e5, 5e5, 1e6, 2e6 }) + math.random(1e4, 2e4)) * depth
                    b = (randomChoice({ 1e5, 2.5e5, 5e5, 1e6, 2e6 }) + math.random(1e4, 2e4)) * depth
                elseif pattern == "Extreme" then
                    main = randomChoice({ 1e8, 2.5e8, 5e8 }) * depth
                    a = randomChoice({ 1e7, 2.5e7, 5e7 }) * depth
                    b = randomChoice({ 1e7, 2.5e7, 5e7 }) * depth
                else
                    main = math.random(150000, 250000) * depth
                    a = math.random(1000, 5000) * depth
                    b = math.random(1000, 5000) * depth
                end
                main = math.clamp(main, -5e8, 5e8)
                a = math.clamp(a, -5e8, 5e8)
                b = math.clamp(b, -5e8, 5e8)
                local chosen = {}
                local value = flag("rb_dir", { "+Y" })
                for _, name in ipairs({ "+Y", "+X", "+Z" }) do
                    if picked(value, name) then chosen[#chosen + 1] = name end
                end
                local direction = #chosen > 0 and chosen[math.random(1, #chosen)] or "+Y"
                if direction == "+X" then
                    R.voidPos = v3(main, a, b)
                elseif direction == "+Z" then
                    R.voidPos = v3(a, b, main)
                else
                    R.voidPos = v3(a, main, b)
                end
                return R.voidPos
            end

            local function voidCenter(root)
                local base = Actions.sp.realPos(root)
                if flag("rb_pattern", "Under map") == "Under map" then
                    local destroyAt = workspace.FallenPartsDestroyHeight
                    if type(destroyAt) ~= "number" or destroyAt ~= destroyAt then destroyAt = -500 end
                    return v3(base.X, math.min(math.max(destroyAt + 30, -2500), base.Y - 10), base.Z)
                end
                if not R.voidPos then voidPoint(clock()) end
                return R.voidPos
            end

            local marker, markerLine, markerText
            local function hideMarker()
                if marker then marker.Parent = nil end
                if markerLine then markerLine.Visible = false end
                if markerText then markerText.Visible = false end
            end
            local function destroyMarker()
                if marker then pcall(function() marker:Destroy() end) marker = nil end
                if markerLine then pcall(function() markerLine:Remove() end) markerLine = nil end
                if markerText then pcall(function() markerText:Remove() end) markerText = nil end
            end
            local function updateMarker()
                if not (flag("rb_void_show", false) and flag("rb_void", false)) then hideMarker() return end
                local cam = Camera()
                local _, _, root = localParts()
                if not cam or not root then hideMarker() return end
                local at = voidCenter(root)
                if not at then hideMarker() return end
                local picker = Options.rb_void_color
                local color = picker and typeof(picker.Value) == "Color3" and picker.Value or Color3.fromRGB(255, 80, 80)
                if not marker then
                    marker = Instance.new("Part")
                    marker.Name = "AsterVoidMarker"
                    marker.Shape = Enum.PartType.Ball
                    marker.Size = v3(5, 5, 5)
                    marker.Anchored = true
                    marker.CanCollide = false
                    marker.CanQuery = false
                    marker.CanTouch = false
                    marker.CastShadow = false
                    marker.Material = Enum.Material.Neon
                    marker.Transparency = 0.25
                end
                marker.Color = color
                marker.Position = at
                if marker.Parent ~= cam then marker.Parent = cam end
                if Drawing and type(Drawing.new) == "function" then
                    if not markerLine then
                        local ok, line = pcall(Drawing.new, "Line")
                        if ok and line then markerLine = line table.insert(getgenv().TS_Drawings, line) end
                    end
                    if not markerText then
                        local ok, text = pcall(Drawing.new, "Text")
                        if ok and text then
                            markerText = text
                            text.Size, text.Center, text.Outline, text.Font = 14, true, true, 2
                            table.insert(getgenv().TS_Drawings, text)
                        end
                    end
                    local view = cam.ViewportSize
                    local screen = cam:WorldToViewportPoint(at)
                    local x, y = screen.X, screen.Y
                    if screen.Z < 0 then x, y = view.X - x, view.Y - y end
                    x = math.clamp(x, 40, view.X - 40)
                    y = math.clamp(y, 40, view.Y - 40)
                    local distance = (at - root.Position).Magnitude
                    if markerLine then
                        markerLine.From = Vector2.new(view.X / 2, view.Y)
                        markerLine.To = Vector2.new(x, y)
                        markerLine.Color = color
                        markerLine.Thickness = 1
                        markerLine.Visible = true
                    end
                    if markerText then
                        markerText.Text = string.format("void %d studs", math.floor(distance))
                        markerText.Color = color
                        markerText.Position = Vector2.new(x, y - 20)
                        markerText.Visible = true
                    end
                end
            end

            local function wantVoid(now, empty)
                if not flag("rb_void", false) then return false end
                local when = flag("rb_void_when", "While targeting")
                R.voidWhy = when == "While reloading" and "reloading" or when == "Smart" and "smart timer" or "hiding between peeks"
                if when == "While reloading" then return empty end
                if when ~= "Smart" then return true end
                local S = R.smart
                local hum = R.entity and R.entity.Humanoid
                local health = hum and hum.Health or 100
                local dt = S.t and (now - S.t) or 0
                S.t = now
                if S.health and health < S.health then S.dropped = true end
                S.health = health
                S.timer += dt
                if S.state == "waiting" then
                    if S.timer >= flag("rb_smart_wait", 8) then
                        S.timer = 0
                        if not S.dropped and health > 0 then S.state = "voiding" end
                        S.dropped = false
                    end
                    return false
                end
                if S.timer >= flag("rb_smart_void", 5) then
                    S.state, S.timer = "waiting", 0
                end
                return true
            end

            local function choosePart(e)
                local mode = flag("rb_part", "Head")
                if mode == "Random" then mode = math.random(1, 2) == 1 and "Head" or "Torso" end
                if mode == "Torso" then
                    return e.Character:FindFirstChild("UpperTorso") or e.Character:FindFirstChild("Torso") or e.Root
                end
                return e.Head
            end

            local function peekAt(e, base, now)
                local mode = R.randomSpot and "Random" or flag("rb_peek_mode", "Behind")
                local distance = flag("rb_peek_dist", 6)
                local height = flag("rb_peek_height", 2)
                local function ring(angle, extra)
                    return base + v3(math.cos(angle) * distance, height + (extra or 0), math.sin(angle) * distance)
                end
                local angle
                if mode == "Above" then
                    local goal = base + v3(0, math.max(height, 2), 0)
                    if flag("rb_los", "Off") ~= "Visible only" then return goal end
                    local start = 0
                    if WB.status(goal + HEAD_OFFSET, e.Head, goal) == "visible" then return goal end
                    angle = start
                elseif mode == "Behind" or mode == "Front" or mode == "Left" or mode == "Right" or mode == "Side swap" or mode == "Swing" then
                    local cf = e.Root.CFrame
                    local look, right = cf.LookVector, cf.RightVector
                    if mode == "Front" then
                        angle = math.atan2(look.Z, look.X)
                    elseif mode == "Left" then
                        angle = math.atan2(-right.Z, -right.X)
                    elseif mode == "Right" then
                        angle = math.atan2(right.Z, right.X)
                    elseif mode == "Side swap" then
                        local sign = R.peekCount % 2 == 0 and 1 or -1
                        angle = math.atan2(right.Z * sign, right.X * sign)
                    elseif mode == "Swing" then
                        angle = math.atan2(-look.Z, -look.X) + math.sin(now * flag("rb_spiral_speed", 6) * 0.5) * 1.2
                    else
                        angle = math.atan2(-look.Z, -look.X)
                    end
                elseif mode == "Random" then
                    angle = R.randAngle
                else
                    angle = now * flag("rb_spiral_speed", 6)
                end
                R.usedAngle = nil
                if mode ~= "Above" then
                    local mem = R.peekMem[e.Player]
                    if mem and flag("rb_peek_memory", true) then
                        local function bucket(value) return math.floor((value % (math.pi * 2)) / (math.pi / 8)) end
                        local function banned(value)
                            local entry = mem.bad[bucket(value)]
                            return entry ~= nil and entry[1] >= 2 and now - entry[2] < 12
                        end
                        if mem.good and now - mem.good[2] < 20 and (mode == "Random" or mode == "Spiral") and not banned(mem.good[1]) and math.random() < 0.5 then
                            angle = mem.good[1]
                        else
                            for step = 0, 15 do
                                if not banned(angle + step * math.pi / 8) then
                                    angle = angle + step * math.pi / 8
                                    break
                                end
                            end
                        end
                    end
                    R.usedAngle = angle
                end
                local goal = ring(angle)
                if flag("rb_los", "Off") ~= "Visible only" then return goal end
                WB.tick()
                if WB.status(goal + HEAD_OFFSET, e.Head, goal) == "visible" then return goal end
                for _, extra in ipairs({ 0, 4, 8 }) do
                    for step = 1, 8 do
                        local candidate = ring(angle + step * math.pi / 4, extra)
                        if WB.status(candidate + HEAD_OFFSET, e.Head, candidate) == "visible" then return candidate end
                    end
                end
                return nil
            end

            local ammoSeen = setmetatable({}, { __mode = "k" })

            local function serverAmmo(tool)
                local ammo = tool and tool:GetAttribute("CurrentAmmo")
                return type(ammo) == "number" and ammo or nil
            end

            local function shotLabel(text)
                if R.shotText == text then return end
                R.shotText = text
                local label = Actions.shotLogLabel
                if label and label.SetText then pcall(label.SetText, label, text) end
            end

            local function shotStart(part, aim)
                if not flag("rb_shotlog", false) then return nil end
                local tool = Actions.gunTool and Actions.gunTool()
                local _, _, root = localParts()
                local origin = R.goal and (R.goal + HEAD_OFFSET) or (root and root.Position) or aim
                return { tool = tool, part = part.Name, dist = (aim - origin).Magnitude, ammo = serverAmmo(tool) }
            end

            local function trackAmmo(list)
                if not flag("rb_shotlog", false) then
                    table.clear(ammoSeen)
                    shotLabel("Shots: log off")
                    return
                end
                if not R.shotText or R.shotText == "Shots: log off" then shotLabel(R.shotLast or "Shots: none yet") end
                local polled = {}
                local function poll(tool)
                    if not tool or polled[tool] then return end
                    polled[tool] = true
                    local ammo, last = serverAmmo(tool), ammoSeen[tool]
                    ammoSeen[tool] = ammo
                    if ammo and last and ammo < last then
                        local drops = last - ammo
                        for _, shot in ipairs(list) do
                            local log = shot and shot.log
                            if drops <= 0 then break end
                            if log and log.tool == tool and not log.dropped then
                                log.dropped = true
                                drops = drops - 1
                            end
                        end
                    end
                end
                poll(Actions.gunTool and Actions.gunTool())
                for _, shot in ipairs(list) do poll(shot and shot.log and shot.log.tool) end
            end

            local function logShot(shot, health)
                local log = shot.log
                if not log then return end
                local hit = health ~= nil
                local damage = hit and math.max(math.floor(shot.hp - health + 0.5), 0) or 0
                local known, dropped = log.ammo ~= nil, log.dropped == true
                local entries = R.shotLog
                if not entries then
                    entries = {}
                    R.shotLog = entries
                end
                entries[#entries + 1] = { gun = log.tool and log.tool.Name, part = log.part, dist = log.dist, damage = damage, hit = hit,
                    known = known, dropped = dropped, accepted = hit or dropped }
                if #entries > 30 then table.remove(entries, 1) end
                local outcome = hit and (damage .. "hp") or ((not known or dropped) and "no damage" or "rejected")
                R.shotLast = string.format("%s %dst %s", log.part, math.floor(log.dist + 0.5), outcome)
                shotLabel(R.shotLast)
            end

            local function fireNow(part, aim)
                if not R.run then return end
                if Actions.readyGun and Actions.readyGun() then
                    Actions.fireAt(part, aim)
                    local e = R.entity
                    if e then
                        local st = R.stat
                        st.shots += 1
                        local list = st.pending
                        list[#list + 1] = { t = clock(), hp = e.Humanoid.Health, player = e.Player, angle = R.usedAngle, note = R.predNote, log = shotStart(part, aim) }
                        if #list > 40 then table.remove(list, 1) end
                    end
                end
            end

            local function tuneStep(up)
                local t = R.tune
                if up then
                    t.out = math.min(t.out + 0.05, 0.4)
                    t.delay = math.min(t.delay + 0.01, 0.1)
                    t.boost = math.min(t.boost + 0.15, 0.6)
                    t.force = true
                    t.steps += 1
                else
                    t.out = math.max(t.out - 0.05, 0)
                    t.delay = math.max(t.delay - 0.01, 0)
                    t.boost = math.max(t.boost - 0.15, 0)
                    t.steps = math.max(t.steps - 1, 0)
                    if t.steps == 0 then t.force = false end
                end
                Actions.predict.boost = t.boost
            end

            local function angleBucket(value) return math.floor((value % (math.pi * 2)) / (math.pi / 8)) end

            local function evaluateShots(e, now)
                local st = R.stat
                local list = st.pending
                trackAmmo(list)
                if #list == 0 then return end
                local hum = e and e.Humanoid
                for index = 1, #list do
                    local shot = list[index]
                    if shot and hum and shot.player == e.Player and hum.Health < shot.hp - 0.01 and now - shot.t >= 0.03 then
                        st.hits += 1
                        logShot(shot, hum.Health)
                        st.hitRun += 1
                        st.missRun = 0
                        if shot.angle then
                            local mem = R.peekMem[shot.player]
                            if not mem then mem = { bad = {} } R.peekMem[shot.player] = mem end
                            mem.good = { shot.angle, now }
                            mem.bad[angleBucket(shot.angle)] = nil
                        end
                        for later = 1, #list do
                            local other = list[later]
                            if other and other.player == shot.player then other.hp = hum.Health end
                        end
                        list[index] = false
                        if st.hitRun >= 8 and flag("rb_autotune", false) then
                            st.hitRun = 0
                            tuneStep(false)
                        end
                        break
                    end
                end
                local keep = {}
                for index = 1, #list do
                    local shot = list[index]
                    if shot then
                        if now - shot.t > 0.9 then
                            st.misses += 1
                            logShot(shot, nil)
                            st.missRun += 1
                            st.hitRun = 0
                            local why = "no hit registered"
                            local note = shot.note or ""
                            if string.find(note, "no line", 1, true) then why = "no line to predicted spot"
                            elseif string.find(note, "out of range", 1, true) then why = "out of range"
                            elseif shot.player.Character and shot.player.Character:FindFirstChildOfClass("ForceField") then why = "target forcefield" end
                            st.why = why
                            if shot.angle then
                                local mem = R.peekMem[shot.player]
                                if not mem then mem = { bad = {} } R.peekMem[shot.player] = mem end
                                local key = angleBucket(shot.angle)
                                local entry = mem.bad[key]
                                mem.bad[key] = { (entry and entry[1] or 0) + 1, now }
                            end
                            if flag("rb_autotune", false) and st.missRun >= 5 then
                                st.missRun = 0
                                tuneStep(true)
                            end
                        else
                            keep[#keep + 1] = shot
                        end
                    end
                end
                st.pending = keep
            end

            local function rageRequest(root, realPos)
                if not R.run then return nil end
                local now = clock()
                R.realPos = realPos
                local _, hum = localParts()
                local tool, empty = gunState()
                if empty and R.altReady then empty = false end
                local voidOn = flag("rb_void", false)
                local when = flag("rb_void_when", "While targeting")
                local e = R.entity
                local settings = flag("rb_settings", {})
                local style = picked(settings, "Show server position") and Actions.sp.visualStyle("misc_desync_fill", "misc_desync_line") or nil
                R.randomSpot = picked(settings, "Random peek spot")
                local function inVoid(why)
                    R.voidUsedAt = now
                    R.status = "in void (" .. why .. ")"
                    return voidPoint(now), 1e9, style
                end
                if keyActive("rb_void_key") and not typing() then return inVoid("void key") end

                if now < R.getUntil or (Actions.gettingWeapon and Actions.gettingWeapon()) then
                    R.status = "getting weapon"
                    return nil
                end

                if flag("rb_safe", false) and hum and hum.MaxHealth > 0 then
                    local limit = flag("rb_safe_hp", 20) / 100
                    local fraction = hum.Health / hum.MaxHealth
                    if fraction <= limit then R.safe = true
                    elseif fraction >= math.min(limit + 0.25, 1) then R.safe = false end
                else
                    R.safe = false
                end

                if R.safe then
                    R.status = "safe mode"
                    if voidOn then return inVoid("safe mode, low health") end
                    return nil
                end

                if not e or not R.center then
                    local listed = flag("rb_targets", {})
                    R.status = (flag("rb_tmode", "Target list") == "Target list" and next(listed) == nil) and "no targets selected" or "waiting for target"
                    R.lastPhase = ""
                    if voidOn and flag("rb_wait_void", false) and (flag("rb_tmode", "Target list") ~= "Target list" or next(listed) ~= nil) then
                        return inVoid("waiting for target")
                    end
                    if voidOn and when == "Always" then
                        if now >= R.phaseEnd then
                            R.phase = R.phase == "void" and "peek" or "void"
                            R.phaseEnd = now + (R.phase == "void" and flag("rb_in_time", 0.35) or flag("rb_out_time", 0.2))
                        end
                        if R.phase == "void" then return inVoid("always mode, no target") end
                    end
                    return nil
                end

                if not tool then
                    R.status = "no gun"
                    return nil
                end

                if e.Character:FindFirstChildOfClass("ForceField") then
                    R.status = "target has forcefield"
                    R.lastPhase = ""
                    if voidOn then
                        local name = e.Player.DisplayName ~= "" and e.Player.DisplayName or e.Player.Name
                        local criminal = e.Player.Team ~= nil and e.Player.Team.Name == "Criminals"
                        local area = Actions.area and R.center and Actions.area(R.center) or "outside"
                        if criminal and area ~= "outside" then
                            return inVoid(string.format("waiting for criminal %s's forcefield to disappear before going inside prison area", name))
                        end
                        return inVoid(string.format("waiting for %s's forcefield to disappear", name))
                    end
                    return nil
                end

                if empty then
                    R.status = flag("rb_reload", false) and "reloading" or "gun empty"
                    R.lastPhase = ""
                    if voidOn then return inVoid(flag("rb_reload", false) and "reloading" or "gun empty, no reload") end
                    return nil
                end

                local hide = wantVoid(now, empty)
                if hide then
                    if now >= R.phaseEnd then
                        if R.phase == "void" then
                            R.phase = "peek"
                            R.phaseEnd = now + flag("rb_out_time", 0.2) + R.tune.out
                            R.randAngle = math.random() * math.pi * 2
                        else
                            R.phase = "void"
                            R.phaseEnd = now + flag("rb_in_time", 0.35)
                        end
                    end
                else
                    R.phase = "peek"
                    R.phaseEnd = 0
                end

                if R.phase == "void" then
                    R.lastPhase = "void"
                    return inVoid(R.voidWhy or "hiding between peeks")
                end

                if R.lastPhase ~= "peek" then
                    R.lastPhase = "peek"
                    R.peekCount += 1
                    R.peekAt = now
                end

                local lead, pvel = 0, R.vel
                local predOn = flag("rb_pred", false) or R.tune.force
                R.predNote = nil
                if predOn then
                    lead = Actions.predict.lead("rb")
                    pvel = Actions.predict.velocity(e.Player, e.Root)
                end
                local base = R.center + pvel * lead
                local goal
                if R.goal and R.goalFor == e.Player and now - R.goalAt < 0.05 then
                    goal = R.goal
                else
                    goal = peekAt(e, base, now)
                    R.goal, R.goalAt, R.goalFor = goal, now, e.Player
                end
                if not goal then
                    R.status = "no clear spot"
                    if voidOn then return inVoid("no clear spot near target") end
                    return nil
                end

                R.status = "killing " .. e.Player.Name
                if now - R.peekAt >= flag("rb_shot_delay", 0.03) + R.tune.delay and now >= R.nextShot and (not Actions.readyGun or Actions.readyGun()) then
                    R.nextShot = now + 1 / math.max(flag("rb_rate", 12), 1)
                    if R.randomSpot then R.randAngle = math.random() * math.pi * 2 end
                    local part = choosePart(e)
                    local aim = part.Position
                    if not (R.live) then aim = R.center + (part.Position - e.Root.Position) end
                    if predOn then
                        local okP, predicted, note = pcall(Actions.predict.point, e.Character, part, goal, "rb")
                        if okP and typeof(predicted) == "Vector3" then
                            aim += predicted - part.Position
                            R.predNote = note
                        end
                    end
                    local reach = Gun.range(Gun.data())
                    if reach and reach > 0 and (aim - (goal + HEAD_OFFSET)).Magnitude > reach then
                        R.status = "out of range"
                    else
                        task.defer(fireNow, part, aim)
                    end
                end
                return goal, 1e9, style
            end

            local function housekeeping(now)
                local char, hum, root = localParts()
                if not root then
                    R.target, R.entity, R.center = nil, nil, nil
                    return
                end
                local realPos = Actions.sp.realPos(root)
                local e, position, velocity, live = pickTarget(realPos)
                if e then
                    if R.target ~= e.Player then
                        R.target = e.Player
                        R.lastHealth = e.Humanoid.Health
                        R.lastDamage = now
                        R.smart.state, R.smart.timer, R.smart.dropped, R.smart.health, R.smart.t = "waiting", 0, false, nil, nil
                        R.goal = nil
                    end
                    if e.Humanoid.Health < R.lastHealth then R.lastDamage = now end
                    R.lastHealth = e.Humanoid.Health
                    if flag("rb_swap", false) and now - R.lastDamage > flag("rb_swap_time", 4) then
                        R.skip[e.Player] = now + flag("rb_swap_time", 4) * 2
                        R.lastDamage = now
                    end
                else
                    R.target = nil
                end
                R.entity, R.center, R.vel, R.live = e, position, velocity or ZERO, live ~= false
                pcall(evaluateShots, e, now)

                local chosen = flag("rb_weapons", {})
                local pool = {}
                local poolName = {}
                for _, name in ipairs(WEAPON_ORDER) do
                    if picked(chosen, name) then
                        local owned = findWeapon(name)
                        if owned then
                            pool[#pool + 1] = owned
                            poolName[owned] = name
                        end
                    end
                end
                R.altReady = false
                if e and hum and #pool > 0 then
                    local held = char:FindFirstChildOfClass("Tool")
                    local function ready(tool)
                        local ammo = tool:GetAttribute("Local_CurrentAmmo")
                        return (ammo == nil or ammo > 0) and (tool:GetAttribute("Local_ReloadSession") or 0) <= 0
                    end
                    if flag("rb_aw", false) and R.center then
                        local distance = (R.center - realPos).Magnitude
                        local want = distance <= flag("rb_aw_close", 45) and "close" or distance >= flag("rb_aw_far", 250) and "far" or "mid"
                        local fitting = {}
                        for _, tool in ipairs(pool) do
                            local name = poolName[tool]
                            local class = name == "Remington 870" and "close" or name == "M700" and "far" or "mid"
                            if class == want and ready(tool) then fitting[#fitting + 1] = tool end
                        end
                        if #fitting > 0 then pool = fitting end
                    end
                    local heldIndex = 0
                    for index, tool in ipairs(pool) do
                        if tool == held then heldIndex = index end
                    end
                    local heldReady = heldIndex > 0 and ready(held)
                    for _, tool in ipairs(pool) do
                        if tool ~= held and ready(tool) then R.altReady = true break end
                    end
                    if not heldReady or (#pool > 1 and now >= R.equipAt) then
                        local pick
                        for step = 1, #pool do
                            local tool = pool[(heldIndex + step - 1) % #pool + 1]
                            if tool ~= held and ready(tool) then pick = tool break end
                        end
                        if heldIndex == 0 and not pick then pick = pool[1] end
                        if pick then
                            R.equipAt = now + math.max(flag("rb_switch_delay", 0.15), 0.05)
                            pcall(function() hum:EquipTool(pick) end)
                        end
                    end
                end

                local settings = flag("rb_settings", {})
                local cam = Camera()
                if e and picked(settings, "View target") and cam then
                    if cam.CameraSubject ~= e.Humanoid then cam.CameraSubject = e.Humanoid end
                    R.viewing = true
                elseif R.viewing then
                    R.viewing = false
                    if cam and hum then cam.CameraSubject = hum end
                end

                local wanted = flag("rb_autoget", {})
                if now >= R.getAt and hum and hum.Health > 0 and not (Actions.gettingWeapon and Actions.gettingWeapon()) then
                    for _, name in ipairs({ "AK-47", "Remington 870", "MP5", "M700", "M4A1", "FAL" }) do
                        if picked(wanted, name) and not findWeapon(name) then
                            R.getAt = now + 3
                            R.getUntil = now + 0.6
                            if Actions.getWeapon then Actions.getWeapon(name) end
                            break
                        end
                    end
                end

                local text = "Result: none"
                if e then
                    local who = e.Player.DisplayName ~= "" and e.Player.DisplayName or e.Player.Name
                    text = string.sub("Result: " .. who, 1, 28)
                end
                if text ~= R.shownText and Actions.rageResult and Actions.rageResult.SetText then
                    R.shownText = text
                    Actions.rageResult:SetText(text)
                end

                local tool, empty, reloading = gunState()
                if tool and empty and not reloading and flag("rb_reload", false) and now >= R.reloadAt then
                    R.reloadAt = now + 0.6
                    if Actions.reloadGun then Actions.reloadGun() end
                end
            end

            local function newText()
                if not (Drawing and type(Drawing.new) == "function") then return nil end
                local ok, text = pcall(Drawing.new, "Text")
                if not ok or not text then return nil end
                table.insert(getgenv().TS_Drawings, text)
                text.Size, text.Center, text.Outline, text.Font = 14, true, true, 2
                text.Color = Color3.new(1, 1, 1)
                text.Visible = false
                return text
            end

            local vhText
            local function renderStatus(textObject, line)
                local cam = Camera()
                if not textObject or not cam then return end
                textObject.Text = line
                textObject.Size = 16
                textObject.Position = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2 + flag("rb_status_y", 40))
                textObject.Visible = true
            end

            local function voidHideRequest(root, realPos)
                R.realPos = realPos
                local when = flag("vh_when", "Always")
                local _, hum = localParts()
                local why
                if when == "Always" then
                    why = "always on"
                elseif when == "Keybind" then
                    if keyActive("vh_key") then why = "void key" end
                elseif when == "Low health" then
                    if hum and hum.MaxHealth > 0 then
                        local limit = flag("vh_hp", 35) / 100
                        local fraction = hum.Health / hum.MaxHealth
                        if fraction <= limit then R.vhLow = true
                        elseif fraction >= math.min(limit + 0.25, 1) then R.vhLow = false end
                        if R.vhLow then why = string.format("low health, %d%%", math.floor(fraction * 100)) end
                    end
                else
                    local _, empty = gunState()
                    if empty then why = "reloading" end
                end
                if not why then
                    R.vhStatus = "visible (waiting for " .. string.lower(when) .. ")"
                    return nil
                end
                R.vhStatus = "in void (" .. why .. ")"
                R.voidUsedAt = clock()
                return voidPoint(clock()), 1e9, nil
            end

            local vhBag = newBag()
            feature("vh_enabled", function()
                R.vhLow, R.vhStatus = false, "starting"
                task.spawn(Gun.find)
                watchDeaths(vhBag)
                Actions.sp.enable("voidhide", voidHideRequest)
                vhBag.add(RunService.RenderStepped:Connect(function()
                    if R.run or not flag("rb_status", false) then
                        if vhText then vhText.Visible = false end
                        return
                    end
                    vhText = vhText or newText()
                    renderStatus(vhText, "void hide: " .. tostring(R.vhStatus))
                end))
            end, function()
                vhBag.clear()
                Actions.sp.disable("voidhide")
                R.vhStatus = "off"
                if vhText then pcall(function() vhText.Visible = false end) end
            end)

            Actions.probe.rage = { request = rageRequest, fire = fireNow, evaluate = evaluateShots, housekeeping = housekeeping, pick = pickTarget, usable = usable }

            feature("rb_enabled", function()
                R.run = true
                R.phase, R.lastPhase, R.phaseEnd, R.voidPos = "peek", "", 0, nil
                R.stat = { shots = 0, hits = 0, misses = 0, missRun = 0, hitRun = 0, why = "", pending = {} }
                R.tune = { out = 0, delay = 0, boost = 0, force = false, steps = 0 }
                Actions.predict.boost = 0
                task.spawn(Gun.find)
                watchDeaths(bag)
                if Actions.rageHook then Actions.rageHook(true) end
                Actions.sp.enable("rage", rageRequest)
                local accumulated = 0
                bag.add(RunService.Heartbeat:Connect(function(dt)
                    accumulated += dt
                    if accumulated < 0.08 then return end
                    accumulated = 0
                    local ok, err = pcall(housekeeping, clock())
                    if not ok then
                        errors += 1
                        if errors <= 3 then warnf("ragebot error:", err) end
                    end
                end))
                bag.add(RunService.RenderStepped:Connect(function()
                    pcall(updateMarker)
                end))
                bag.add(RunService.RenderStepped:Connect(function()
                    if not flag("rb_status", false) then
                        if statusText then statusText.Visible = false end
                        return
                    end
                    statusText = statusText or newText()
                    local cam = Camera()
                    if not statusText or not cam then return end
                    local e = R.entity
                    local line = "ragebot: " .. R.status
                    if R.predNote and (flag("rb_pred", false) or R.tune.force) then line = line .. " | pred " .. R.predNote end
                    if flag("rb_feedback", true) then
                        local st = R.stat
                        local total = st.hits + st.misses
                        if total > 0 then
                            line = line .. string.format(" | hits %d/%d (%d%%)", st.hits, total, math.floor(st.hits / total * 100 + 0.5))
                            if st.why ~= "" and st.misses > 0 then line = line .. " | last miss: " .. st.why end
                        end
                        if R.tune.steps > 0 then line = line .. string.format(" | tuned +%.2fs", R.tune.out) end
                    end
                    if e then line = line .. string.format(" | %s %d hp", e.Player.DisplayName ~= "" and e.Player.DisplayName or e.Player.Name, math.floor(e.Humanoid.Health)) end
                    statusText.Text = line
                    statusText.Size = 16
                    statusText.Position = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2 + flag("rb_status_y", 40))
                    statusText.Visible = true
                end))
            end, function()
                R.run = false
                bag.clear()
                Actions.sp.disable("rage")
                if Actions.rageHook then Actions.rageHook(false) end
                R.target, R.entity, R.center, R.goal, R.safe = nil, nil, nil, nil, false
                R.status = "off"
                hideMarker()
                if R.viewing then
                    R.viewing = false
                    local _, ownHum = localParts()
                    local cam = Camera()
                    if cam and ownHum then cam.CameraSubject = ownHum end
                end
                if statusText then pcall(function() statusText.Visible = false end) end
            end)

            onUnload(function()
                R.run = false
                destroyMarker()
                if statusText then pcall(function() statusText:Remove() end) statusText = nil end
            end)
        end

        do
            local bag = newBag()
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Include
            pcall(function() params.CollisionGroup = "ClientBullet" end)
            local seenSince, nextShot = nil, 0
            local burstUntil, burstShots = 0, 0
            local TORSO = { Torso = true, UpperTorso = true, LowerTorso = true, HumanoidRootPart = true }

            feature("Trigger_Global_Enabled", function()
                seenSince, nextShot = nil, 0
                burstUntil, burstShots = 0, 0
                task.spawn(Gun.find)
                local magnetOn = false
                Actions.aimMagnet(flag("trigger_magnet", false))
                magnetOn = flag("trigger_magnet", false)
                bag.add(RunService.Heartbeat:Connect(function()
                    local wantMagnet = flag("trigger_magnet", false)
                    if wantMagnet ~= magnetOn then
                        magnetOn = wantMagnet
                        Actions.aimMagnet(wantMagnet)
                    end
                    local cam = Camera()
                    local _, _, root = localParts()
                    if not cam or not root or typing() or not keyActive("Trigger_Global_Key") or not readyGun() then
                        seenSince = nil
                        return
                    end
                    local ref = aimRef()
                    local ray = cam:ViewportPointToRay(ref.X, ref.Y)
                    local list = {}
                    for _, other in ipairs(Players:GetPlayers()) do
                        if other ~= LocalPlayer and other.Character then list[#list + 1] = other.Character end
                    end
                    params.FilterDescendantsInstances = list
                    local result = #list > 0 and workspace:Raycast(ray.Origin, ray.Direction * 1500, params) or nil
                    local model = result and result.Instance:FindFirstAncestorOfClass("Model")
                    local player = model and Players:GetPlayerFromCharacter(model)
                    local hum = model and model:FindFirstChildOfClass("Humanoid")
                    local good = player ~= nil and player ~= LocalPlayer and hum ~= nil and hum.Health > 0
                    if good and (Relations[player.UserId] == "Friendly" or (flag("trigger_team", false) and relationOf(player) == "Friendly")) then good = false end
                    if good and flag("trigger_ff", false) and model:FindFirstChildOfClass("ForceField") then good = false end
                    if good and flag("trigger_hostile", false) and isPeaceful(player) then good = false end
                    if good then
                        local mode = flag("Trigger_Global_HitPart", "Head")
                        if mode == "Head" then good = result.Instance.Name == "Head"
                        elseif mode == "Torso" then good = TORSO[result.Instance.Name] == true end
                    end
                    if good then
                        local data = Gun.data()
                        local head = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Head")
                        local range = Gun.range(data) or 1000
                        if not head then
                            good = false
                        elseif (result.Position - head.Position).Magnitude > range then
                            good = false
                        elseif not visibleFrom(head.Position, result.Instance, model) then
                            good = false
                        end
                    end
                    if not good then seenSince = nil return end
                    local now = clock()
                    seenSince = seenSince or now
                    if now - seenSince >= flag("Trigger_Global_Reaction", 0) / 1000 and now >= nextShot and now >= burstUntil then
                        nextShot = now + flag("Trigger_Global_Delay", 40) / 1000
                        fireGun()
                        local burst = flag("trigger_burst", 0)
                        if burst > 0 then
                            burstShots += 1
                            if burstShots >= burst then
                                burstShots = 0
                                burstUntil = now + flag("trigger_burst_pause", 250) / 1000
                            end
                        end
                    end
                end))
            end, function()
                bag.clear()
                seenSince = nil
                Actions.aimMagnet(false)
            end)
        end

        do
            local bag = newBag()
            local panel
            local nextPick = 0
            local picked, pickedPart

            local function destroyPanel()
                if panel then pcall(function() panel:Destroy() end) end
                panel = nil
            end

            local function buildPanel()
                if panel and panel.Outer and panel.Outer.Parent then return panel end
                destroyPanel()
                panel = Skin.CreateTargetInfo({})
                return panel
            end

            local function pickInfoTarget()
                local head = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Head")
                if not head or not Camera() then return nil end
                if flag("Silent_Global_Enabled", false) and keyActive("Silent_Global_Key") then
                    local data = Gun.data()
                    local entity, part = selectTarget("silent", aimRef(), head.Position, { skipWall = true, limit = Gun.range(data) or 1000 })
                    if entity then return entity, part end
                end
                if flag("Aim_Global_Enabled", false) then
                    local entity, part = selectTarget("aim", aimRef(), head.Position, { skipWall = true })
                    if entity then return entity, part end
                end
                local rage = Actions.rage
                if rage and flag("rb_enabled", false) and rage.entity and rage.entity.Character and rage.entity.Character.Parent then
                    return rage.entity, rage.entity.Character:FindFirstChild("Head") or rage.entity.Root
                end
                return nil
            end

            local function updatePanel()
                local p = buildPanel()
                local now = clock()
                if now >= nextPick then
                    nextPick = now + 0.1
                    picked, pickedPart = pickInfoTarget()
                end
                for name, key in pairs({ Health = "tinfo_health", Status = "tinfo_status", Extra = "tinfo_extra" }) do
                    local want = flag(key, true) and true or false
                    if p.Options[name] ~= want then p:SetOption(name, want) end
                end
                local entity, part = picked, pickedPart
                local character = entity and entity.Character
                local hum = character and character:FindFirstChildOfClass("Humanoid")
                local root = entity and entity.Root
                local menuOpen = Library.Toggled == true
                if not (entity and character and character.Parent and hum and root and root.Parent) then
                    p:Update(nil)
                    p:SetVisible(menuOpen or not flag("tinfo_hide", true))
                    return
                end
                local player = entity.Player
                local tool = character:FindFirstChildOfClass("Tool")
                local team = player.Team
                local head = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Head")
                local distance = head and (root.Position - head.Position).Magnitude or 0
                local sight = "Blocked"
                if part and part.Parent and head then
                    WB.tick()
                    local status = WB.status(head.Position, part)
                    if status == "visible" then
                        sight = "Visible"
                    elseif status == "wallbang" then
                        sight = flag("silent_wallbang", false) and "Wallbang" or "Blocked"
                    end
                end
                local data = Gun.data()
                p:Update({
                    Name = player.Name,
                    Display = player.DisplayName ~= "" and player.DisplayName or player.Name,
                    UserId = player.UserId,
                    Health = hum.Health,
                    MaxHealth = hum.MaxHealth,
                    Distance = distance,
                    Range = Gun.range(data) or flag("silent_max_dist", 1000),
                    Sight = sight,
                    Team = team and team.Name or "none",
                    TeamColor = team and team.TeamColor.Color or nil,
                    Tool = tool and tool.Name or "none",
                })
                p:SetVisible(true)
            end

            feature("tinfo_on", function()
                buildPanel()
                bag.add(RunService.RenderStepped:Connect(function()
                    local ok, err = pcall(updatePanel)
                    if not ok and clock() - (panel and panel.warned or 0) > 5 then
                        if panel then panel.warned = clock() end
                        warnf("target info:", err)
                    end
                end))
            end, function()
                bag.clear()
                destroyPanel()
            end)

            onUnload(function()
                bag.clear()
                destroyPanel()
            end)
        end

        do
            local bag = newBag()
            local orbit = { target = nil, angle = 0, last = nil, floorAt = 0, floorY = nil, floorFor = nil, nextPick = 0, ring = nil, ringParts = {} }

            local function destroyRing()
                if orbit.ring then pcall(function() orbit.ring:Destroy() end) end
                orbit.ring = nil
                table.clear(orbit.ringParts)
            end

            local function pickTarget(root)
                local cam = Camera()
                local head = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Head")
                if not cam or not head then return nil end
                local entity = selectTarget("silent", aimRef(), head.Position, { skipWall = true, ignoreDown = false, limit = flag("orbit_max", 500) })
                return entity and entity.Root or nil
            end

            local silentCache = { at = 0, root = nil }
            Actions.silentTarget = function()
                local now = clock()
                if now - silentCache.at > 0.1 then
                    silentCache.at = now
                    local ok, root = pcall(pickTarget)
                    silentCache.root = ok and root or nil
                end
                return silentCache.root
            end
            onUnload(function() Actions.silentTarget = nil end)

            local function orbitHeight(center)
                local void = workspace.FallenPartsDestroyHeight
                if type(void) ~= "number" or void ~= void or void < -1e5 or void > 1e4 then void = -500 end
                local floorLimit = void + 12
                local mode = flag("orbit_mode", "Under the map")
                local depth = flag("orbit_depth", 15)
                local y
                if mode == "Near void" then
                    y = math.min(void + 30, center.Y - 10)
                elseif mode == "Below target" then
                    y = center.Y - depth
                else
                    local now = clock()
                    if not orbit.floorY or now - orbit.floorAt > 0.25 or not orbit.floorFor or (orbit.floorFor - center).Magnitude > 4 then
                        orbit.floorAt, orbit.floorFor = now, center
                        orbit.floorY = Actions.sp.floorAt(center, true)
                    end
                    y = (orbit.floorY or (center.Y - 6)) - depth
                end
                return math.max(y, floorLimit)
            end

            local function updateRing(center, y, radius, color, transparency)
                local count = 28
                if not orbit.ring or orbit.ring.Parent == nil then
                    destroyRing()
                    local folder = Instance.new("Folder")
                    folder.Name = "AsterOrbitRing"
                    for i = 1, count do
                        local part = Instance.new("Part")
                        part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
                        part.CastShadow = false
                        part.Material = Enum.Material.Neon
                        part.Size = v3(0.25, 0.25, 1)
                        part.Parent = folder
                        orbit.ringParts[i] = part
                    end
                    folder.Parent = workspace.CurrentCamera
                    orbit.ring = folder
                end
                local step = (math.pi * 2) / count
                local length = math.max(radius * step * 1.05, 0.3)
                for i, part in ipairs(orbit.ringParts) do
                    local a1 = (i - 1) * step
                    local p = v3(center.X + math.cos(a1) * radius, y, center.Z + math.sin(a1) * radius)
                    local a2 = a1 + step
                    local q = v3(center.X + math.cos(a2) * radius, y, center.Z + math.sin(a2) * radius)
                    part.Size = v3(0.25, 0.25, length)
                    part.CFrame = CFrame.lookAt((p + q) / 2, q)
                    part.Color = color
                    part.Transparency = transparency
                end
            end

            local function orbitRequest(root, realPos)
                if not (flag("Silent_Global_Enabled", false) and keyActive("Silent_Global_Key")) then
                    orbit.last = nil
                    destroyRing()
                    return nil
                end
                local now = clock()
                local target = orbit.target
                if not target or not target.Parent or now >= orbit.nextPick then
                    target = pickTarget(root)
                    orbit.target = target
                    orbit.nextPick = now + 0.1
                end
                if not target or not target.Parent then
                    orbit.last = nil
                    destroyRing()
                    return nil
                end
                local dt = orbit.last and math.min(now - orbit.last, 0.1) or 0
                orbit.last = now
                local spin = math.rad(flag("orbit_spin", 180))
                if flag("orbit_dir", "Clockwise") ~= "Clockwise" then spin = -spin end
                orbit.angle = (orbit.angle + spin * dt) % (math.pi * 2)
                local center = target.Position
                local y = orbitHeight(center)
                local radius = flag("orbit_radius", 6)
                local goal = v3(center.X + math.cos(orbit.angle) * radius, y, center.Z + math.sin(orbit.angle) * radius)
                if flag("orbit_ring", false) then
                    local color, alpha = Actions.sp.ringStyle()
                    updateRing(center, y, radius, color, alpha)
                else
                    destroyRing()
                end
                local style
                if flag("orbit_visual", false) then
                    style = Actions.sp.visualStyle("orbit_fill", "orbit_line", flag("orbit_tracer", false) and "orbit_tracer_color" or nil)
                end
                return goal, flag("orbit_speed", 150), style
            end

            function Actions.sp.ringStyle()
                local option = Options["orbit_ring_color"]
                local color = option and typeof(option.Value) == "Color3" and option.Value or Color3.fromRGB(180, 120, 255)
                local alpha = option and tonumber(option.Transparency) or 0.3
                return color, alpha
            end

            feature("orbit_on", function()
                orbit.target, orbit.last, orbit.nextPick, orbit.floorY = nil, nil, 0, nil
                Actions.sp.enable("orbit", orbitRequest)
            end, function()
                Actions.sp.disable("orbit")
                orbit.target, orbit.last = nil, nil
                destroyRing()
            end)

            onUnload(function()
                Actions.sp.disable("orbit")
                destroyRing()
            end)
        end

        do
            local bag = newBag()
            local A = Actions.sp.assist
            A.goal, A.speed, A.style, A.part, A.partUntil = nil, 50, nil, nil, 0
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            pcall(function() params.CollisionGroup = "ClientBullet" end)
            local nextEval, errors = 0, 0

            local function firing()
                if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then return true end
                return clock() - (Actions.lastAutoShot or -10) < 0.4
            end

            local function evaluate()
                local char, _, root = localParts()
                if not char or not root or typing() then return nil end
                if flag("wb_assist_fire", false) and not firing() then return nil end
                local cam = Camera()
                if not cam then return nil end
                WB.tick()
                local head = char:FindFirstChild("Head")
                local realPos = Actions.sp.realPos(root)
                local headOffset = head and (head.Position - root.Position) or v3(0, 1.5, 0)
                local origin = realPos + headOffset
                local ref = aimRef()
                local fov, maxDist, reach = flag("wb_assist_fov", 250), flag("wb_assist_max", 200), flag("wb_assist_dist", 25)

                local candidates = {}
                for _, e in ipairs(otherEntities()) do
                    if Relations[e.Player.UserId] ~= "Friendly" and (e.Root.Position - realPos).Magnitude <= maxDist then
                        local screen, onScreen = cam:WorldToViewportPoint(e.Head.Position)
                        if onScreen then
                            local d = (Vector2.new(screen.X, screen.Y) - ref).Magnitude
                            if d <= fov then candidates[#candidates + 1] = { e = e, d = d } end
                        end
                    end
                end
                table.sort(candidates, function(a, b) return a.d < b.d end)

                for index = 1, math.min(#candidates, 4) do
                    local part = candidates[index].e.Head
                    local status = WB.status(origin, part, realPos)
                    if status == "visible" then
                        return nil
                    elseif status == "wallbang" then
                        return nil, part
                    end
                    local delta = part.Position - realPos
                    local distance = delta.Magnitude
                    if distance >= 2 then
                        params.FilterDescendantsInstances = WB.ray.FilterDescendantsInstances
                        local hit = workspace:Raycast(realPos, delta, params)
                        if hit and hit.Distance <= reach then
                            local unit = delta / distance
                            local point = flag("wb_assist_inside", false) and (hit.Position + unit * 1.5) or (hit.Position - unit * 1.2)
                            local goal = v3(point.X, realPos.Y + math.clamp(point.Y - realPos.Y, -4, 4), point.Z)

                            if WB.status(goal + headOffset, part, goal) ~= "blocked" then return goal, part end
                        end
                    end
                end
                return nil
            end

            local function step()
                local now = clock()
                if now < nextEval then return end
                nextEval = now + 0.1
                local goal, part = evaluate()
                A.goal = goal
                if goal then A.goalAt = now end
                if goal then
                    A.speed = flag("wb_assist_mode", "Tween") == "Teleport" and 1e9 or flag("wb_assist_speed", 50)
                    A.style = flag("wb_assist_visual", false) and Actions.sp.visualStyle("wb_assist_fill", "wb_assist_line") or nil
                end
                if part then A.part, A.partUntil = part, now + 0.35 end
            end

            local M = { home = nil, holdUntil = 0, heading = ZERO, modified = {} }
            local overlap = OverlapParams.new()
            overlap.FilterType = Enum.RaycastFilterType.Exclude

            local function releaseMoved()
                for part in pairs(M.modified) do pcall(function() part.CanCollide = true end) end
                table.clear(M.modified)
            end

            local function realMove(dt)
                local _, _, root = localParts()
                if not root or flag("wb_assist_method", "Server position") ~= "Velocity" then
                    if M.home or next(M.modified) then
                        M.home = nil
                        releaseMoved()
                    end
                    return
                end
                local now = clock()
                local wants = A.goal ~= nil and now - (A.goalAt or 0) < 0.4
                if wants or (M.home and firing()) then M.holdUntil = now + 0.5 end
                local target
                if wants then
                    if not M.home then M.home = root.Position end
                    target = A.goal
                elseif M.home and now < M.holdUntil then
                    target = root.Position
                elseif M.home then
                    target = M.home
                    if (root.Position - M.home).Magnitude < 1.5 then
                        M.home = nil
                        M.heading = ZERO
                        releaseMoved()
                        root.AssemblyLinearVelocity = ZERO
                        return
                    end
                else
                    return
                end
                local delta = target - root.Position
                local distance = delta.Magnitude
                local speed = flag("wb_assist_mode", "Tween") == "Teleport" and 120 or flag("wb_assist_speed", 50)
                local velocity = ZERO
                if distance > 0.6 then velocity = delta.Unit * math.min(speed, distance / math.max(dt, 1 / 120)) end
                M.heading = velocity
                root.AssemblyLinearVelocity = velocity
                root.AssemblyAngularVelocity = ZERO
            end

            local function noclipStep()
                if not M.home then
                    if next(M.modified) then releaseMoved() end
                    return
                end
                local char, hum, root = localParts()
                if not root or not hum then return end
                local list = { Camera(), char }
                for _, e in ipairs(otherEntities()) do list[#list + 1] = e.Character end
                overlap.FilterDescendantsInstances = list
                local center = root.CFrame + v3(0, 1, 0) + M.heading * 0.12
                local near = {}
                for _, part in ipairs(workspace:GetPartBoundsInBox(center, root.Size + v3(7, hum.HipHeight, 7), overlap)) do
                    near[part] = true
                    if part.CanCollide then M.modified[part] = true part.CanCollide = false end
                end
                for part in pairs(M.modified) do
                    if not near[part] then M.modified[part] = nil part.CanCollide = true end
                end
            end

            feature("wb_assist", function()
                Actions.sp.enable("assist", function()
                    if not A.goal or flag("wb_assist_method", "Server position") ~= "Server position" then return nil end
                    return A.goal, A.speed, A.style
                end)
                bag.add(RunService.Heartbeat:Connect(function(dt)
                    local ok, err = pcall(realMove, dt)
                    if not ok then
                        errors += 1
                        if errors <= 3 then warnf("wallbang assist move error:", err) end
                    end
                end))
                bag.add(RunService.Stepped:Connect(function()
                    pcall(noclipStep)
                end))
                Actions.assistHook(true)
                task.spawn(Gun.find)
                nextEval = 0
                bag.add(RunService.RenderStepped:Connect(function()
                    local ok, err = pcall(step)
                    if not ok then
                        errors += 1
                        if errors <= 3 then warnf("wallbang assist error:", err) end
                    end
                end))
            end, function()
                bag.clear()
                A.goal, A.style, A.part = nil, nil, nil
                M.home = nil
                releaseMoved()
                Actions.assistHook(false)
                Actions.sp.disable("assist")
            end)
        end

        do
            local function pick(name, fallbackColor, fallbackAlpha)
                local object = Options[name]
                local color = object and typeof(object.Value) == "Color3" and object.Value or fallbackColor
                local alpha = object and tonumber(object.Transparency) or fallbackAlpha
                return color, alpha
            end
            local drawingOk = Drawing ~= nil and type(Drawing.new) == "function"
            local function newDrawing(kind)
                if not drawingOk then return nil end
                local ok, object = pcall(Drawing.new, kind)
                if ok and object then
                    table.insert(getgenv().TS_Drawings, object)
                    return object
                end
                return nil
            end
            local function discard(object)
                if object then pcall(function() object.Visible = false object:Remove() end) end
            end

            local bag = newBag()
            local cursorText, pool, states, budget, warned = nil, {}, {}, 0, false
            local LABELS = { visible = "visible", wallbang = "wallbangable", blocked = "not wallbangable", range = "out of range" }
            local reach, frameColors, drawn = nil, {}, setmetatable({}, { __mode = "k" })

            local function shown(record, force)
                if force and record.alt then return record.altState, record.alt end
                return record.s
            end

            -- the shot falls back to the other body parts when the head fails: test one of them per refresh, keeping a part that passed
            local function probeAlt(e, origin, record)
                record.probed = true
                local list = altParts(e.Character, e.Head)
                if #list == 0 then return end
                local part = record.hint and e.Character:FindFirstChild(record.hint)
                if not part then
                    record.altAt = ((record.altAt or 0) % #list) + 1
                    part = list[record.altAt]
                end
                local state = WB.status(origin, part)
                if state ~= "blocked" then
                    record.alt, record.altState = part.Name, state
                else
                    record.hint = nil
                end
            end

            local stateColorNow
            local function stateColor(state)
                local color = frameColors[state]
                if not color then
                    color = stateColorNow(state)
                    frameColors[state] = color
                end
                return color
            end
            stateColorNow = function(state)
                if state == "visible" then return (pick("wb_ind_c_vis", Color3.fromRGB(90, 255, 120), 0)) end
                if state == "wallbang" then return (pick("wb_ind_c_wb", Color3.fromRGB(255, 200, 60), 0)) end
                return (pick("wb_ind_c_block", Color3.fromRGB(255, 80, 80), 0))
            end
            local function memo(text)
                local last = drawn[text]
                if not last then
                    last = {}
                    drawn[text] = last
                end
                return last
            end
            local function setVisible(text, on)
                local last = memo(text)
                if last.Visible ~= on then
                    last.Visible = on
                    text.Visible = on
                end
            end
            local function setText(text, content, x, y, size, color)
                local last = memo(text)
                if last.Text ~= content then last.Text = content text.Text = content end
                if last.Size ~= size then last.Size = size text.Size = size end
                if last.Color ~= color then last.Color = color text.Color = color end
                if last.X ~= x or last.Y ~= y then
                    last.X, last.Y = x, y
                    text.Position = Vector2.new(x, y)
                end
                setVisible(text, true)
            end
            local function hideTexts()
                if cursorText then setVisible(cursorText, false) end
                for _, text in pairs(pool) do setVisible(text, false) end
            end
            local function stateOf(e, origin, now, force)
                if reach and reach > 0 and (e.Head.Position - origin).Magnitude > reach then return "range" end
                local cached = states[e.Player]
                if cached and now - cached.t < 0.15 then
                    if force and cached.s == "blocked" and not cached.probed then probeAlt(e, origin, cached) end
                    return shown(cached, force)
                end
                if not force and budget <= 0 and cached then return shown(cached, force) end
                budget -= 1
                local state = WB.status(origin, e.Head)
                local record = { s = state, t = now, altAt = cached and cached.altAt, hint = cached and (cached.alt or cached.hint) }
                if force and state == "blocked" then probeAlt(e, origin, record) end
                states[e.Player] = record
                return shown(record, force)
            end

            local function indicatorStep()
                local cam = Camera()
                local char, _, root = localParts()
                if not cam or not root then
                    hideTexts()
                    return
                end
                WB.tick()
                local now = clock()
                local head = char:FindFirstChild("Head")
                local origin = head and head.Position or root.Position
                local size, range = flag("wb_ind_size", 14), flag("wb_ind_range", 1000)
                local everyone = flag("wb_ind_all", false)
                local ref = aimRef()
                budget = 3
                table.clear(frameColors)
                reach = Actions.gunTool and Actions.gunTool() and Gun.range(Gun.data()) or nil
                local used, best, bestD = {}, nil, nil
                for _, e in ipairs(otherEntities()) do
                    if Relations[e.Player.UserId] ~= "Friendly" and (e.Root.Position - root.Position).Magnitude <= range then
                        local screen, onScreen = cam:WorldToViewportPoint(e.Head.Position)
                        if onScreen then
                            local d = (Vector2.new(screen.X, screen.Y) - ref).Magnitude
                            if not bestD or d < bestD then best, bestD = e, d end
                            if everyone then
                                local state = stateOf(e, origin, now, false)
                                local text = pool[e.Player]
                                if not text then
                                    text = newDrawing("Text")
                                    if text then
                                        text.Center = true
                                        text.Outline = true
                                        pool[e.Player] = text
                                    end
                                end
                                if text then
                                    setText(text, LABELS[state], screen.X, screen.Y - size * 2.2, size, stateColor(state))
                                    used[e.Player] = true
                                end
                            end
                        end
                    end
                end
                for player, text in pairs(pool) do
                    if not used[player] then
                        setVisible(text, false)
                        if not player.Parent then
                            discard(text)
                            pool[player] = nil
                            states[player] = nil
                        end
                    end
                end

                if flag("wb_ind_cursor", true) then
                    if not cursorText then
                        cursorText = newDrawing("Text")
                        if cursorText then cursorText.Outline = true end
                    end
                    if cursorText then
                        if best and bestD <= 250 then
                            local state, alt = stateOf(best, origin, now, true)
                            setText(cursorText, LABELS[state] .. (alt and " (body)" or ""), ref.X + 24, ref.Y + 14, size, stateColor(state))
                        elseif flag("wb_ind_always", false) then
                            setText(cursorText, "no target", ref.X + 24, ref.Y + 14, size, Color3.fromRGB(180, 180, 180))
                        else
                            setVisible(cursorText, false)
                        end
                    end
                elseif cursorText then
                    setVisible(cursorText, false)
                end
            end

            feature("wb_ind", function()
                if not drawingOk then
                    say("The wallbang indicator needs the Drawing library")
                    switchOff("wb_ind")
                    return
                end
                bag.add(RunService.RenderStepped:Connect(function()
                    local ok, err = pcall(indicatorStep)
                    if not ok and not warned then
                        warned = true
                        warnf("wallbang indicator error:", err)
                    end
                end))
            end, function()
                bag.clear()
                hideTexts()
            end)

            local reloadBag = newBag()
            local back, fill, label, reloadWarned = nil, nil, nil, false
            local RELOAD_FALLBACK = { ["AK-47"] = 2, FAL = 2, M4A1 = 2, M9 = 2, MP5 = 2, ["Remington 870"] = 3.5, Taser = 3.4, M700 = 3, Revolver = 3 }

            local function hideReload()
                if back then back.Visible = false end
                if fill then fill.Visible = false end
                if label then label.Visible = false end
            end

            local function reloadStep()
                local tool = equippedGun()
                local session = tool and tool:GetAttribute("Local_ReloadSession")
                if type(session) ~= "number" or session <= 0 then
                    hideReload()
                    return
                end
                local data = Gun.data()
                local duration = (data and tonumber(data.ReloadTime)) or tonumber(tool:GetAttribute("ReloadTime")) or RELOAD_FALLBACK[tool.Name] or 2.5
                duration = math.max(duration, 0.1)
                local elapsed = tick() - session
                local progress = math.clamp(elapsed / duration, 0, 1)
                local width, height = flag("reload_ind_w", 120), flag("reload_ind_h", 6)
                local ref = aimRef()
                local x, y = ref.X - width / 2, ref.Y + flag("reload_ind_y", 40)

                back = back or newDrawing("Square")
                fill = fill or newDrawing("Square")
                if not back or not fill then return end
                local fillColor, fillAlpha = pick("reload_ind_fill", Color3.fromRGB(255, 255, 255), 0)
                local backColor, backAlpha = pick("reload_ind_back", Color3.fromRGB(0, 0, 0), 0.5)
                back.Filled, back.Color, back.Transparency = true, backColor, 1 - backAlpha
                back.Position, back.Size, back.Visible = Vector2.new(x - 1, y - 1), Vector2.new(width + 2, height + 2), true
                fill.Filled, fill.Color, fill.Transparency = true, fillColor, 1 - fillAlpha
                fill.Position, fill.Size, fill.Visible = Vector2.new(x, y), Vector2.new(math.max(width * progress, 0.01), height), true

                if flag("reload_ind_text", true) then
                    if not label then
                        label = newDrawing("Text")
                        if label then
                            label.Center = true
                            label.Outline = true
                            label.Size = 13
                            label.Color = Color3.fromRGB(255, 255, 255)
                        end
                    end
                    if label then
                        label.Text = string.format("reloading %.1fs", math.max(duration - elapsed, 0))
                        label.Position = Vector2.new(ref.X, y + height + 3)
                        label.Visible = true
                    end
                elseif label then
                    label.Visible = false
                end
            end

            feature("reload_ind", function()
                if not drawingOk then
                    say("The reload indicator needs the Drawing library")
                    switchOff("reload_ind")
                    return
                end
                task.spawn(Gun.find)
                reloadBag.add(RunService.RenderStepped:Connect(function()
                    local ok, err = pcall(reloadStep)
                    if not ok and not reloadWarned then
                        reloadWarned = true
                        warnf("reload indicator error:", err)
                    end
                end))
            end, function()
                reloadBag.clear()
                hideReload()
            end)

            local ammoBag = newBag()
            local ammoLabel, ammoWarned = nil, false
            local function ammoStep()
                local tool = equippedGun()
                local serverAmmo = tool and tool:GetAttribute("CurrentAmmo")
                if type(serverAmmo) ~= "number" then
                    if ammoLabel then ammoLabel.Visible = false end
                    return
                end
                local localAmmo = tool:GetAttribute("Local_CurrentAmmo")
                local maxAmmo, stored = tool:GetAttribute("MaxAmmo"), tool:GetAttribute("StoredAmmo")
                local text = "server " .. tostring(serverAmmo)
                if type(stored) == "number" then
                    text ..= " | " .. tostring(stored)
                elseif type(maxAmmo) == "number" then
                    text ..= "/" .. tostring(maxAmmo)
                end
                local mismatch = type(localAmmo) == "number" and localAmmo ~= serverAmmo
                if flag("ammo_ind_local", false) and type(localAmmo) == "number" then
                    text ..= "  (local " .. tostring(localAmmo) .. ")"
                end
                local color
                if serverAmmo <= 0 then
                    color = pick("ammo_ind_c_empty", Color3.fromRGB(255, 80, 80), 0)
                elseif mismatch then
                    color = pick("ammo_ind_c_diff", Color3.fromRGB(255, 200, 60), 0)
                else
                    color = pick("ammo_ind_c_ok", Color3.fromRGB(255, 255, 255), 0)
                end
                if not ammoLabel then
                    ammoLabel = newDrawing("Text")
                    if not ammoLabel then return end
                    ammoLabel.Center = true
                    ammoLabel.Outline = true
                end
                local ref = aimRef()
                ammoLabel.Text = text
                ammoLabel.Size = flag("ammo_ind_size", 16)
                ammoLabel.Color = color
                ammoLabel.Position = Vector2.new(ref.X, ref.Y + flag("ammo_ind_y", 70))
                ammoLabel.Visible = true
            end

            feature("ammo_ind", function()
                if not drawingOk then
                    say("The ammo indicator needs the Drawing library")
                    switchOff("ammo_ind")
                    return
                end
                ammoBag.add(RunService.RenderStepped:Connect(function()
                    local ok, err = pcall(ammoStep)
                    if not ok and not ammoWarned then
                        ammoWarned = true
                        warnf("ammo indicator error:", err)
                    end
                end))
            end, function()
                ammoBag.clear()
                if ammoLabel then ammoLabel.Visible = false end
            end)

            onUnload(function()
                discard(ammoLabel)
                ammoLabel = nil
                for _, text in pairs(pool) do discard(text) end
                table.clear(pool)
                discard(cursorText)
                discard(back)
                discard(fill)
                discard(label)
                cursorText, back, fill, label = nil, nil, nil, nil
            end)
        end
    end)()
end
-- dev.lua 19431-19440: feature runner + unload
do
    track(RunService.Heartbeat:Connect(function()
        for _, f in ipairs(features) do
            setActive(f, readFlag(f.flag, false) == true)
        end
    end))

    onUnload(function()
        for _, f in ipairs(features) do setActive(f, false) end
        MiscActions.clearCheats = noop
    end)
end
end
end
bootMark("combat", PL2BootT, 9, 13)

PL2BootT = PL2BootClock()
-- [src] 60_player.lua
do
    Player = {
        saved = {}, flagged = {}, cheats = {}, positions = {}, spawned = {}, lastChar = {}, fences = { parts = {}, nextScan = 0 },
        flying = false, yLevel = nil, spinAngle = 0, corpse = nil, cheatAcc = 0, spiderHit = nil,
        high = { started = nil }, long = { enableAt = nil },
        area = { name = "", at = 0, bounds = nil, boundsAt = -100 },
        antiJump = { humanoid = nil, disabled = {}, hooked = false, tries = 0, nextTry = 0 },
        collide = { head = nil, connection = nil, at = 0 },
        phase = { modified = {}, connection = nil },
        invis = { on = false, character = nil, track = nil, startAt = nil, held = nil },
        fling = { container = nil, modified = {}, prompts = {}, connections = {}, queue = nil, index = 0 },
        animCheck = { on = false, acc = 0, cleared = 0, suppressed = {}, verdict = {} },
    }
    local ZERO = Vector3.new(0, 0, 0)
    local ONE = Vector3.new(1, 1, 1)
    local FLAT = Vector3.new(1, 0, 1)
    local NONE = {}
    local FENCE_PART, FENCE_SCAN = "damagePart", 1
    local CAP_HEIGHT = 49.9
    local HOOK_TRIES = 20
    local INVIS_DELAY = 0.8
    local INVIS_R15, INVIS_R6 = "18665825805", "215384594"
    local PLANE_LOW, PLANE_HIGH = -10, 179.99
    local FLING_BATCH = 1000
    local atan2 = math.atan2 or math.atan
    local AREA_MIN, AREA_MAX, AREA_ANCHOR = Vector3.new(690, -50, 2170), Vector3.new(1010, 600, 2620), Vector3.new(850, 100, 2400)
    local AREA_SPEEDS = { inside = 32, yard = 50, outside = 100 }
    local AREA_FLAGS = { inside = "misc_walk_in", yard = "misc_walk_yard", outside = "misc_walk_out" }
    local AREA_NAMES = { inside = "inside prison", yard = "prison area", outside = "outside prison" }
    local MOVE_FLAGS = { "misc_fly", "misc_speed", "misc_walk", "misc_jumpmult", "misc_spider", "misc_highjump", "misc_longjump", "misc_noaccel",
        "misc_spinbot", "misc_no_jump_cd", "misc_camera_zoom", "misc_camera_phase", "misc_gravity", "misc_invis", "misc_anti_fling", "misc_anti_riot",
        "misc_anti_killplane", "char_fence_safe", "misc_destroy_body", "misc_disabler" }
    local MONITOR_FLAGS = { "misc_cheat_detector", "misc_anti_invis" }
    local NO_ACCEL_SKIP, CHEAT_STATES = {}, {}
    for _, name in ipairs({ "Climbing", "Swimming", "Seated", "Dead", "Physics", "Ragdoll", "FallingDown", "PlatformStanding" }) do
        NO_ACCEL_SKIP[Enum.HumanoidStateType[name]] = true
    end
    for _, name in ipairs({ "Running", "Jumping", "Freefall", "Landed", "FallingDown", "GettingUp", "Climbing", "Seated", "Ragdoll", "Dead", "None" }) do
        CHEAT_STATES[Enum.HumanoidStateType[name]] = true
    end
    local known = {}
    for _, id in ipairs({
        "125750702", "128777973", "128853357", "129423030", "129423131", "129967390", "129967478",
        "178130996", "180426354", "180435571", "180435792", "180436148", "180436334", "182393478",
        "182435998", "182436842", "182436935", "182491037", "182491065", "182491248", "182491277",
        "182491368", "182491423", "279227693", "279229192", "287112271", "388723916", "388726667",
        "389472570", "405194080", "405212265", "481088553", "481089053", "484200742", "484926359",
        "83690472549256", "107176344504758", "111090572475133", "113267949064300", "131326339350805",
    }) do known[id] = true end
    local want = {}

    local function flag(name, default)
        local value = Util.F(name)
        if value == nil then return default end
        return value
    end

    -- an attached keybind drives its toggle, so the toggle value is the whole gate
    local function active(name)
        return flag(name, false) == true
    end

    local function anyOn(list)
        for _, name in ipairs(list) do
            if Util.F(name) then return true end
        end
        return false
    end

    local function switchOff(name)
        if Util.F(name) then Aster:Set(name, false) end
    end

    local function say(text)
        Util.notify(text, "info", 3)
    end

    function Player.invisActive()
        return active("misc_invis")
    end

    local function localParts()
        local character = Game.localCharacter()
        if not character then return nil end
        return character, Game.humanoid(character), character:FindFirstChild("HumanoidRootPart")
    end

    local function read(object, prop)
        local ok, value = pcall(function() return object[prop] end)
        if ok then return value end
        return nil
    end

    local function write(object, prop, value)
        pcall(function() object[prop] = value end)
    end

    local function hold(object, prop, value)
        if not object then return end
        local saved = Player.saved[object]
        if not saved then
            saved = {}
            Player.saved[object] = saved
        end
        if saved[prop] == nil then
            local current = read(object, prop)
            if current == nil then saved[prop] = NONE else saved[prop] = current end
        end
        want[object] = want[object] or {}
        want[object][prop] = true
        if read(object, prop) ~= value then write(object, prop, value) end
    end

    -- keeps an existing hold alive without writing (the game locked the value, e.g. WalkSpeed 0 while tased)
    local function keep(object, prop)
        local saved = Player.saved[object]
        if saved and saved[prop] ~= nil then
            want[object] = want[object] or {}
            want[object][prop] = true
        end
    end

    local function settle()
        for object, saved in pairs(Player.saved) do
            local wanted = want[object]
            for prop, original in pairs(saved) do
                if not (wanted and wanted[prop]) then
                    if original ~= NONE then write(object, prop, original) end
                    saved[prop] = nil
                end
            end
            if next(saved) == nil then Player.saved[object] = nil end
        end
        want = {}
    end

    local function keyDown(name)
        if Util.typing() then return false end
        local ok, down = pcall(function() return UserInputService:IsKeyDown(Enum.KeyCode[name]) end)
        return ok and down == true
    end

    local function flat(vector)
        if typeof(vector) ~= "Vector3" then return ZERO end
        return Vector3.new(vector.X, 0, vector.Z)
    end

    local function stateOf(humanoid)
        local ok, state = pcall(function() return humanoid:GetState() end)
        if ok then return state end
        return nil
    end

    local function changeState(humanoid, name)
        pcall(function() humanoid:ChangeState(Enum.HumanoidStateType[name]) end)
    end

    local function grounded(humanoid)
        local state = stateOf(humanoid)
        return state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.Landed
    end

    local function addVelocity(root, delta)
        write(root, "AssemblyLinearVelocity", (read(root, "AssemblyLinearVelocity") or ZERO) + delta)
    end

    local function impulse(root, delta)
        if not pcall(function() root:ApplyImpulse(delta * root.AssemblyMass) end) then addVelocity(root, delta) end
    end

    -- the camera, my character and every other character: what the climb / phase / click rays skip
    local function bodies(includeMine)
        local list = { Game.camera() }
        for _, other in ipairs(Players:GetPlayers()) do
            if other.Character and (includeMine or other ~= LocalPlayer) then list[#list + 1] = other.Character end
        end
        return list
    end

    local function excludeParams(list, respect)
        local params = Game.newParams(list)
        if respect then pcall(function() params.RespectCanCollide = true end) end
        return params
    end
    Player.excludeParams = excludeParams

    function Player.capHeight(root, level, extra)
        local list = { root.Parent, Game.camera() }
        if extra then list[#list + 1] = extra end
        local hit = Workspace:Raycast(root.Position, Vector3.new(0, -500, 0), excludeParams(list))
        if not hit then return level end
        local limit = hit.Position.Y + CAP_HEIGHT
        if root.Position.Y > limit then
            root.CFrame = root.CFrame + Vector3.new(0, limit - root.Position.Y, 0)
            local velocity = read(root, "AssemblyLinearVelocity") or ZERO
            if velocity.Y > 0 then write(root, "AssemblyLinearVelocity", Vector3.new(velocity.X, 0, velocity.Z)) end
        end
        if level then return math.min(level, limit) end
        return level
    end

    local function sourceOf(connection)
        local ok, source = pcall(function() return connection.Function and Compat.info(connection.Function, "s") end)
        if ok and type(source) == "string" then return source end
        return ""
    end

    function Player.hookJump(humanoid)
        if type(Compat.getconnections) ~= "function" then return false end
        local ok, list = pcall(Compat.getconnections, humanoid:GetPropertyChangedSignal("Jump"))
        if not ok or type(list) ~= "table" then return false end
        local disabled, found = Player.antiJump.disabled, false
        for _, connection in ipairs(list) do
            if sourceOf(connection):find("AntiJump", 1, true) then
                pcall(function() connection:Disable() end)
                disabled[#disabled + 1] = connection
                found = true
            end
        end
        if not found and list[1] and list[1].Function then
            pcall(function() list[1]:Disable() end)
            disabled[#disabled + 1] = list[1]
            found = true
        end
        return found
    end

    function Player.releaseJump()
        for _, connection in ipairs(Player.antiJump.disabled) do pcall(function() connection:Enable() end) end
        Player.antiJump = { humanoid = nil, disabled = {}, hooked = false, tries = 0, nextTry = 0 }
    end

    function Player.noCooldown(now, humanoid)
        local state = Player.antiJump
        if state.humanoid ~= humanoid then
            state.disabled, state.hooked, state.tries, state.nextTry, state.humanoid = {}, false, 0, 0, humanoid
        end
        if not state.hooked and state.tries < HOOK_TRIES and now >= state.nextTry then
            state.tries, state.nextTry = state.tries + 1, now + 0.25
            state.hooked = Player.hookJump(humanoid)
        end
        if state.hooked or not keyDown("Space") then return end
        if read(humanoid, "FloorMaterial") ~= Enum.Material.Air and grounded(humanoid) then changeState(humanoid, "Jumping") end
    end

    -- Scripts.CharacterCollision forces Head.CanCollide back on; its first listener is switched off 0.5 s after each spawn
    function Player.disabler(now, character)
        local head = character:FindFirstChild("Head")
        local state = Player.collide
        if not head then return end
        if state.head ~= head then state.head, state.connection, state.at = head, nil, now + 0.5 end
        if state.connection or state.at == nil or now < state.at then return end
        state.at = nil
        local ok, list = pcall(Compat.getconnections, head:GetPropertyChangedSignal("CanCollide"))
        local first = ok and type(list) == "table" and list[1]
        if first then
            pcall(function() first:Disable() end)
            state.connection = first
        end
    end

    function Player.releaseCollide()
        local connection = Player.collide.connection
        if connection then pcall(function() connection:Enable() end) end
        Player.collide = { head = nil, connection = nil, at = 0 }
    end

    function Player.fly(dt, humanoid, root)
        local speed, vertical = flag("misc_fly_speed", 50), flag("misc_fly_vspeed", 40)
        local lift = (keyDown("Space") and 1 or 0) + (keyDown("LeftControl") and -1 or 0)
        local direction = read(humanoid, "MoveDirection") or ZERO
        if flag("misc_fly_mode", "Velocity") == "CFrame" then
            Player.yLevel = (Player.yLevel or root.Position.Y) + lift * vertical * dt
            write(root, "AssemblyLinearVelocity", ZERO)
            root.CFrame = root.CFrame + Vector3.new(direction.X * speed * dt, Player.yLevel - root.Position.Y, direction.Z * speed * dt)
        else
            Player.yLevel = nil
            write(root, "AssemblyLinearVelocity", Vector3.new(direction.X * speed, 2.25 + lift * vertical, direction.Z * speed))
        end
        if flag("misc_fly_cap", false) then Player.yLevel = Player.capHeight(root, Player.yLevel) end
    end

    function Player.speed(dt, humanoid, root)
        local speed, mode = flag("misc_speed_value", 50), flag("misc_speed_mode", "Velocity")
        if stateOf(humanoid) == Enum.HumanoidStateType.Climbing then return end
        if mode == "WalkSpeed" then return hold(humanoid, "WalkSpeed", speed) end
        local direction = read(humanoid, "MoveDirection") or ZERO
        if mode == "CFrame" then
            root.CFrame = root.CFrame + direction * FLAT * (speed * dt)
        else
            local velocity = read(root, "AssemblyLinearVelocity") or ZERO
            write(root, "AssemblyLinearVelocity", Vector3.new(direction.X * speed, velocity.Y, direction.Z * speed))
        end
    end

    -- dev's prison bounds: the electrified fence tops (fixed box fallback), a roof overhead = inside
    local function extents(part)
        local cf, size = part.CFrame, part.Size
        local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
        return Vector3.new((math.abs(r.X) * size.X + math.abs(u.X) * size.Y + math.abs(l.X) * size.Z) / 2,
            (math.abs(r.Y) * size.X + math.abs(u.Y) * size.Y + math.abs(l.Y) * size.Z) / 2,
            (math.abs(r.Z) * size.X + math.abs(u.Z) * size.Y + math.abs(l.Z) * size.Z) / 2)
    end

    function Player.areaBounds(now)
        local area = Player.area
        if area.bounds and now - area.boundsAt <= 30 then return area.bounds end
        local lo, hi
        local function grow(part)
            if (part.Position - AREA_ANCHOR).Magnitude > 450 then return end
            local ok, e = pcall(extents, part)
            if not ok then return end
            local pmin, pmax = part.Position - e, part.Position + e
            if lo then
                lo = Vector3.new(math.min(lo.X, pmin.X), math.min(lo.Y, pmin.Y), math.min(lo.Z, pmin.Z))
                hi = Vector3.new(math.max(hi.X, pmax.X), math.max(hi.Y, pmax.Y), math.max(hi.Z, pmax.Z))
            else
                lo, hi = pmin, pmax
            end
        end
        local fences = Workspace:FindFirstChild("Prison_Fences")
        if fences then
            local electric = false
            for _, part in ipairs(fences:GetDescendants()) do
                if part:IsA("BasePart") and part:FindFirstChild("TouchInterest") then
                    grow(part)
                    electric = true
                end
            end
            if not electric then
                for _, part in ipairs(fences:GetDescendants()) do
                    if part:IsA("BasePart") then grow(part) end
                end
            end
        end
        if lo and hi and (hi.X - lo.X) > 120 and (hi.Z - lo.Z) > 120 then
            area.bounds = { lo - Vector3.new(8, 0, 8), hi + Vector3.new(8, 0, 8), "fences" }
        else
            area.bounds = { AREA_MIN, AREA_MAX, "fixed box" }
        end
        area.boundsAt = now
        return area.bounds
    end

    function Player.areaOf(position, now)
        local bounds = Player.areaBounds(now)
        local lo, hi = bounds[1], bounds[2]
        if position.X < lo.X or position.X > hi.X or position.Z < lo.Z or position.Z > hi.Z then return "outside" end
        local hit = Workspace:Raycast(position + Vector3.new(0, 2.5, 0), Vector3.new(0, 80, 0), excludeParams(bodies(true), true))
        if hit and (read(hit.Instance, "Transparency") or 0) < 0.9 then return "inside" end
        return "yard"
    end

    function Player.walk(now, humanoid, root)
        local current = read(humanoid, "WalkSpeed") or 0
        if current <= 0.1 then return keep(humanoid, "WalkSpeed") end
        local speed = flag("misc_walk_value", 16)
        if flag("misc_walk_auto", false) then
            local area = Player.area
            if now - area.at > 0.25 then
                area.at = now
                local name = Player.areaOf(root.Position, now)
                if name ~= area.name then
                    area.name = name
                    if flag("misc_walk_notify", false) then
                        local custom = flag("misc_walk_custom", false) and flag(AREA_FLAGS[name], AREA_SPEEDS[name]) or AREA_SPEEDS[name]
                        say(string.format("Area: %s (%.0f studs/s, bounds from %s)", AREA_NAMES[name], custom, area.bounds[3]))
                    end
                end
            end
            speed = AREA_SPEEDS[area.name] or speed
            if flag("misc_walk_custom", false) then speed = flag(AREA_FLAGS[area.name], speed) end
        end
        hold(humanoid, "WalkSpeed", speed)
    end

    function Player.jumpMult(humanoid)
        local current = read(humanoid, "UseJumpPower") and read(humanoid, "JumpPower") or read(humanoid, "JumpHeight") or 0
        if current <= 0.1 and not (Player.saved[humanoid] and Player.saved[humanoid].JumpPower) then return end
        if current <= 0.1 then
            keep(humanoid, "UseJumpPower")
            return keep(humanoid, "JumpPower")
        end
        hold(humanoid, "UseJumpPower", true)
        hold(humanoid, "JumpPower", 50 * math.clamp(flag("misc_jumpmult_value", 1.5), 1, 3))
    end

    function Player.noAccel(humanoid, root)
        local walk = read(humanoid, "WalkSpeed") or 0
        if walk <= 0.1 or read(humanoid, "SeatPart") or read(humanoid, "Sit") then return end
        if NO_ACCEL_SKIP[stateOf(humanoid)] or read(humanoid, "FloorMaterial") == Enum.Material.Air then return end
        local velocity = read(root, "AssemblyLinearVelocity") or ZERO
        if flat(velocity).Magnitude > math.max(walk * 1.6, 45) then return end
        local direction = read(humanoid, "MoveDirection") or ZERO
        if direction.Magnitude > 0.05 then
            write(root, "AssemblyLinearVelocity", Vector3.new(direction.X * walk, velocity.Y, direction.Z * walk))
        else
            write(root, "AssemblyLinearVelocity", Vector3.new(0, velocity.Y, 0))
        end
    end

    local function shiftDown()
        return keyDown("LeftShift") or keyDown("RightShift")
    end

    function Player.spider(dt, humanoid, root)
        if active("misc_phase") and shiftDown() then
            Player.spiderHit = nil
            return
        end
        local params = excludeParams(bodies(true), true)
        pcall(function() params.CollisionGroup = root.CollisionGroup end)
        local hip = read(humanoid, "HipHeight") or 0
        local hit = Workspace:Raycast(root.Position - Vector3.new(0, hip - 0.5, 0), (read(humanoid, "MoveDirection") or ZERO) * 2.5, params)
        if Player.spiderHit and not hit then write(root, "AssemblyLinearVelocity", (read(root, "AssemblyLinearVelocity") or ZERO) * FLAT) end
        Player.spiderHit = hit
        if not (hit and hit.Normal and hit.Normal.Y == 0) then return end
        local power = flag("misc_spider_speed", 30)
        if flag("misc_spider_state", false) then changeState(humanoid, "Climbing") end
        write(root, "AssemblyLinearVelocity", (read(root, "AssemblyLinearVelocity") or ZERO) * FLAT)
        local mode = flag("misc_spider_mode", "Velocity")
        if mode == "CFrame" then
            root.CFrame = root.CFrame + Vector3.new(0, power * dt, 0)
        elseif mode == "Impulse" then
            impulse(root, Vector3.new(0, power, 0))
        else
            addVelocity(root, Vector3.new(0, power, 0))
        end
    end

    function Player.highJump(humanoid, root)
        if not grounded(humanoid) then return false end
        local power, mode = flag("misc_highjump_power", 50), flag("misc_highjump_mode", "Velocity")
        if mode == "Instant" then
            local rise, total = math.max(power - (read(humanoid, "JumpHeight") or 0), 0), 0
            repeat
                total = total + rise * 0.016
                rise = rise - Workspace.Gravity * 0.016
            until rise <= 0
            root.CFrame = root.CFrame + Vector3.new(0, total, 0)
            return true
        end
        changeState(humanoid, "Jumping")
        if mode == "Impulse" then
            -- one frame later, once the jump has set its own velocity; the auto switch-off must not cancel it
            local connection
            connection = RunService.Heartbeat:Connect(function()
                connection:Disconnect()
                impulse(root, Vector3.new(0, power - (read(root, "AssemblyLinearVelocity") or ZERO).Y, 0))
            end)
        else
            local velocity = read(root, "AssemblyLinearVelocity") or ZERO
            write(root, "AssemblyLinearVelocity", Vector3.new(velocity.X, power, velocity.Z))
        end
        return true
    end

    function Player.jumps(now, dt, humanoid, root)
        local high = Player.high
        if active("misc_highjump") then
            high.started = high.started or now
            if flag("misc_highjump_auto", true) then
                if Player.highJump(humanoid, root) or now - high.started > 3 then switchOff("misc_highjump") end
            elseif keyDown("Space") then
                Player.highJump(humanoid, root)
            end
        end
        local long = Player.long
        if not active("misc_longjump") then return end
        long.enableAt = long.enableAt or now + 0.1
        if read(humanoid, "FloorMaterial") ~= Enum.Material.Air then
            if long.enableAt < now and flag("misc_longjump_auto", true) then return switchOff("misc_longjump") end
            changeState(humanoid, "Jumping")
        end
        local direction = (read(humanoid, "MoveDirection") or ZERO) * flag("misc_longjump_speed", 50)
        local velocity = read(root, "AssemblyLinearVelocity") or ZERO
        local mode = flag("misc_longjump_mode", "Velocity")
        if mode == "Velocity" then
            write(root, "AssemblyLinearVelocity", Vector3.new(direction.X, velocity.Y, direction.Z))
        elseif mode == "Impulse" then
            local diff = (direction - velocity) * FLAT
            if diff.Magnitude > (direction == ZERO and 10 or 2) then impulse(root, diff) end
        else
            root.CFrame = root.CFrame + direction * dt
        end
    end

    local function rootJoint(character)
        local root = character:FindFirstChild("HumanoidRootPart")
        local direct = root and root:FindFirstChild("RootJoint")
        if direct and direct:IsA("Motor6D") then return direct end
        local lower = character:FindFirstChild("LowerTorso")
        local joint = lower and lower:FindFirstChild("Root")
        if joint and joint:IsA("Motor6D") then return joint end
        return nil
    end

    function Player.spin(dt, character, humanoid)
        local joint = rootJoint(character)
        if not joint then return end
        local saved = Player.saved[joint]
        local base = saved and saved.C0
        if base == nil or base == NONE then base = read(joint, "C0") end
        if typeof(base) ~= "CFrame" then return end
        Player.spinAngle = (Player.spinAngle + flag("misc_spinbot_speed", 10) * 16 * dt) % 360
        hold(humanoid, "AutoRotate", false)
        hold(joint, "C0", CFrame.Angles(0, math.rad(Player.spinAngle), 0) * base)
    end

    -- phase runs on Stepped (before physics, where the game puts collisions back); Loop has no such phase
    local function phaseRelease()
        for part in pairs(Player.phase.modified) do write(part, "CanCollide", true) end
        Player.phase.modified = {}
    end

    local function normalAxis(hit)
        local cf, normal = hit.Instance.CFrame, hit.Normal
        local x = math.abs(cf.RightVector:Dot(normal))
        if x >= math.abs(cf.UpVector:Dot(normal)) and x >= math.abs(cf.LookVector:Dot(normal)) then return "X" end
        return "Z"
    end

    function Player.phaseStep()
        local character, humanoid, root = localParts()
        if not (root and humanoid) then return end
        local modified = Player.phase.modified
        if active("misc_spider") and not shiftDown() then
            if next(modified) then phaseRelease() end
            return
        end
        local mode = flag("misc_phase_mode", "Part")
        if mode == "Character" then
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    modified[part] = true
                    part.CanCollide = false
                end
            end
        elseif mode == "Part" then
            local near = {}
            local ok, parts = pcall(function()
                local overlap = OverlapParams.new()
                overlap.FilterType = Enum.RaycastFilterType.Exclude
                overlap.FilterDescendantsInstances = bodies(true)
                return Workspace:GetPartBoundsInBox(root.CFrame + Vector3.new(0, 1, 0), root.Size + Vector3.new(7, read(humanoid, "HipHeight") or 0, 7), overlap)
            end)
            for _, part in ipairs(ok and type(parts) == "table" and parts or {}) do
                near[part] = true
                if part.CanCollide then
                    modified[part] = true
                    part.CanCollide = false
                end
            end
            for part in pairs(modified) do
                if not near[part] then
                    modified[part] = nil
                    write(part, "CanCollide", true)
                end
            end
        else
            local head = character:FindFirstChild("Head")
            local direction = read(humanoid, "MoveDirection") or ZERO
            if not head or direction.Magnitude < 0.1 then return end
            local list = bodies(true)
            local hit = Workspace:Raycast(head.Position, direction * 1.1, excludeParams(list, true))
            if not hit then return end
            local size = hit.Instance.Size[normalAxis(hit)]
            if size > flag("misc_phase_size", 5) then return end
            local dest = root.CFrame + hit.Normal * (-size - root.Size.X / 1.5)
            local okBox, blocked = pcall(function()
                local overlap = OverlapParams.new()
                overlap.FilterType = Enum.RaycastFilterType.Exclude
                overlap.FilterDescendantsInstances = list
                return #Workspace:GetPartBoundsInBox(dest, ONE, overlap) > 0
            end)
            if okBox and not blocked then root.CFrame = dest end
        end
    end

    function Player.clickTo(position)
        local _, humanoid, root = localParts()
        if not (root and typeof(position) == "Vector3") then return false end
        if (position - root.Position).Magnitude > flag("misc_clicktp_range", 500) then
            say("That point is out of click teleport range")
            return false
        end
        local lift = (humanoid and read(humanoid, "HipHeight") or 2) + 3
        root.CFrame = root.CFrame + (position + Vector3.new(0, lift, 0) - root.Position)
        write(root, "AssemblyLinearVelocity", ZERO)
        return true
    end

    local function stopInvisAnim()
        local track = Player.invis.track
        if not track then return end
        Player.invis.track = nil
        pcall(function() track:Stop(0) end)
        pcall(function() track:Destroy() end)
    end

    function Player.invisAnim(humanoid)
        stopInvisAnim()
        local animator = humanoid:FindFirstChildOfClass("Animator")
        if not animator then return false end
        local r15 = read(humanoid, "RigType") == Enum.HumanoidRigType.R15
        local animation = Instance.new("Animation")
        animation.AnimationId = "rbxassetid://" .. (r15 and INVIS_R15 or INVIS_R6)
        local ok, track = pcall(function() return animator:LoadAnimation(animation) end)
        animation:Destroy()
        if not (ok and track) then return false end
        pcall(function()
            track.Priority = Enum.AnimationPriority.Action4
            track:Play(0, 1, 0)
        end)
        Player.invis.track = track
        task.defer(function()
            if Player.invis.track ~= track then return end
            pcall(function()
                track.TimePosition = r15 and 1.95 or 0.4
                track:AdjustSpeed(0)
            end)
        end)
        return true
    end

    function Player.letGo(root)
        local held = Player.invis.held
        Player.invis.held = nil
        if not (root and held) then return end
        write(root, "AssemblyLinearVelocity", ZERO)
        write(root, "AssemblyAngularVelocity", ZERO)
        root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, held.yaw, 0)
    end

    function Player.invisStep(dt, now, character, humanoid, root)
        local state = Player.invis
        if state.character ~= character then
            stopInvisAnim()
            state.held, state.startAt = nil, state.character and now + INVIS_DELAY or now
            state.character, state.on = character, true
        end
        if state.startAt and now >= state.startAt then
            if Player.invisAnim(humanoid) or now - state.startAt > 2 then state.startAt = nil end
        end
        if not flag("misc_invis_under", true) then
            if state.held then Player.letGo(root) end
            return
        end
        if not state.held then
            local _, yaw = root.CFrame:ToEulerAnglesYXZ()
            state.held = { position = root.Position, yaw = yaw }
        end
        hold(humanoid, "AutoRotate", false)
        hold(humanoid, "PlatformStand", true)
        for _, part in ipairs(character:GetChildren()) do
            if part:IsA("BasePart") then hold(part, "CanCollide", false) end
        end
        if flag("misc_invis_move", false) then
            local direction = read(humanoid, "MoveDirection") or ZERO
            if direction.Magnitude > 0.1 then
                state.held.position = state.held.position + flat(direction).Unit * ((read(humanoid, "WalkSpeed") or 16) * dt)
                state.held.yaw = atan2(-direction.X, -direction.Z)
            end
        end
        write(root, "AssemblyLinearVelocity", ZERO)
        write(root, "AssemblyAngularVelocity", ZERO)
        root.CFrame = CFrame.new(state.held.position) * CFrame.fromEulerAnglesYXZ(math.rad(flag("misc_invis_pitch", 90)), state.held.yaw, 0)
    end

    function Player.invisOff()
        stopInvisAnim()
        local character, _, root = localParts()
        Player.letGo(root)
        if character then
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") then write(part, "LocalTransparencyModifier", 0) end
            end
        end
        Player.invis = { on = false, character = nil, track = nil, startAt = nil, held = nil }
    end

    function Player.killPlane(root)
        local y = root.Position.Y
        local clamped = math.clamp(y, PLANE_LOW, PLANE_HIGH)
        if clamped == y then return end
        root.CFrame = root.CFrame + Vector3.new(0, clamped - y, 0)
        write(root, "AssemblyLinearVelocity", (read(root, "AssemblyLinearVelocity") or ZERO) * FLAT)
    end

    function Player.antiRiot(records)
        for _, record in ipairs(records or {}) do
            if record.player ~= LocalPlayer and record.model then
                local shield = record.model:FindFirstChild("RiotShieldPart")
                if shield and shield:IsA("BasePart") then hold(shield, "CanQuery", false) end
            end
        end
    end

    function Player.fenceSafe(now)
        local state = Player.fences
        local stale = false
        for _, part in ipairs(state.parts) do
            if not part.Parent then stale = true end
        end
        if stale or now >= state.nextScan then
            state.nextScan = now + FENCE_SCAN
            local parts = {}
            local folder = Workspace:FindFirstChild("Prison_Fences")
            if folder then
                for _, object in ipairs(folder:GetDescendants()) do
                    if object.Name == FENCE_PART and object:IsA("BasePart") then parts[#parts + 1] = object end
                end
            end
            state.parts = parts
        end
        for _, part in ipairs(state.parts) do
            if part.Parent then hold(part, "CanTouch", false) end
        end
    end

    function Player.sinkBody(now)
        local corpse = Player.corpse
        corpse.started = corpse.started or now
        local character = corpse.character
        if not (character and character.Parent) or now - corpse.started >= 4 or not flag("misc_destroy_body", false) then
            Player.corpse = nil
            return
        end
        local void = (read(Workspace, "FallenPartsDestroyHeight") or -500) - 60
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                local position = part.Position
                write(part, "Anchored", false)
                write(part, "AssemblyLinearVelocity", ZERO)
                write(part, "AssemblyAngularVelocity", ZERO)
                write(part, "CFrame", CFrame.new(position.X, void, position.Z))
            end
        end
    end

    local function flingModify(part)
        local fling = Player.fling
        if not part:IsA("BasePart") or read(part, "CollisionGroup") == "Wheels" or fling.modified[part] then return end
        fling.modified[part] = { read(part, "CanCollide"), read(part, "CanTouch") }
        if (part:IsA("Seat") or part:IsA("VehicleSeat")) and part.Name == part.ClassName then
            local prompt = Instance.new("ProximityPrompt")
            prompt.ActionText = "Enter"
            prompt.Enabled = not read(part, "Occupant")
            prompt.MaxActivationDistance = 8
            prompt.RequiresLineOfSight = false
            prompt.Parent = part
            fling.prompts[prompt] = part
            fling.connections[#fling.connections + 1] = prompt.Triggered:Connect(function()
                local _, humanoid = localParts()
                if humanoid then pcall(function() part:Sit(humanoid) end) end
            end)
        end
        write(part, "CanCollide", false)
        write(part, "CanTouch", false)
    end

    function Player.antiFling(humanoid)
        local fling = Player.fling
        if fling.container and not fling.container.Parent then
            Player.flingOff()
            fling = Player.fling
        end
        if not fling.container then
            local cars = Workspace:FindFirstChild("CarContainer")
            if not cars then return end
            fling.container, fling.queue, fling.index = cars, cars:GetDescendants(), 0
            fling.connections[#fling.connections + 1] = cars.DescendantAdded:Connect(function(part) pcall(flingModify, part) end)
        end
        if fling.queue then
            local last = math.min(fling.index + FLING_BATCH, #fling.queue)
            for index = fling.index + 1, last do pcall(flingModify, fling.queue[index]) end
            fling.index = last
            if last >= #fling.queue then fling.queue = nil end
        end
        local seated = humanoid ~= nil and read(humanoid, "SeatPart") ~= nil
        for prompt, seat in pairs(fling.prompts) do
            if prompt.Parent then
                local enabled = not seated and not read(seat, "Occupant")
                if read(prompt, "Enabled") ~= enabled then write(prompt, "Enabled", enabled) end
            end
        end
    end

    function Player.flingOff()
        local fling = Player.fling
        for _, connection in ipairs(fling.connections) do pcall(function() connection:Disconnect() end) end
        for part, values in pairs(fling.modified) do
            write(part, "CanCollide", values[1])
            write(part, "CanTouch", values[2])
        end
        for prompt in pairs(fling.prompts) do pcall(function() prompt:Destroy() end) end
        Player.fling = { container = nil, modified = {}, prompts = {}, connections = {}, queue = nil, index = 0 }
    end

    local function animId(value)
        return tostring(value):match("(%d+)")
    end

    local function learn(root)
        if not root then return end
        for _, item in ipairs(root:GetDescendants()) do
            if item:IsA("Animation") then
                local id = animId(read(item, "AnimationId"))
                if id then known[id] = true end
            end
        end
    end

    function Player.considerTrack(track, other)
        local check = Player.animCheck
        if check.suppressed[track] then return end
        local animation = read(track, "Animation")
        local id = animation and animId(read(animation, "AnimationId"))
        if not id or known[id] then return end
        local key = tostring(other.UserId) .. ":" .. id
        if check.verdict[key] == nil then
            learn(ReplicatedStorage)
            learn(other.Character)
            learn(other:FindFirstChildOfClass("Backpack"))
            check.verdict[key] = known[id] == true
        end
        if check.verdict[key] then return end
        check.suppressed[track] = other
        Player.cheat(other, "invalid animation", 1)
    end

    function Player.antiInvis(dt)
        local check = Player.animCheck
        if not check.on then check.on, check.acc = true, 0.25 end
        check.acc, check.cleared = check.acc + dt, check.cleared + dt
        if check.cleared > 6 then check.cleared, check.verdict = 0, {} end
        if check.acc >= 0.25 then
            check.acc = 0
            for _, other in ipairs(Players:GetPlayers()) do
                local character = other ~= LocalPlayer and other.Character
                local humanoid = character and Game.humanoid(character)
                local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
                local ok, list = false, nil
                if animator then ok, list = pcall(function() return animator:GetPlayingAnimationTracks() end) end
                if ok and type(list) == "table" then
                    for _, track in ipairs(list) do Player.considerTrack(track, other) end
                end
            end
        end
        for track in pairs(check.suppressed) do
            local ok, playing = pcall(function() return track.IsPlaying end)
            if not ok or not playing then
                check.suppressed[track] = nil
            else
                pcall(function() track:AdjustWeight(0, 0) end)
            end
        end
    end

    function Player.antiInvisOff()
        for track in pairs(Player.animCheck.suppressed) do pcall(function() track:AdjustWeight(1, 0) end) end
        Player.animCheck = { on = false, acc = 0, cleared = 0, suppressed = {}, verdict = {} }
    end

    function Player.step(dt, now, records)
        local character, humanoid, root = localParts()
        local alive = humanoid ~= nil and root ~= nil and (read(humanoid, "Health") or 0) > 0
        local flying = alive and active("misc_fly")
        local invis = active("misc_invis")
        if alive then
            if active("misc_walk") then Player.walk(now, humanoid, root) end
            if active("misc_jumpmult") then Player.jumpMult(humanoid) end
            if active("misc_no_jump_cd") then Player.noCooldown(now, humanoid) end
            if active("misc_disabler") then Player.disabler(now, character) end
            if flying then Player.fly(dt, humanoid, root) end
            if active("misc_speed") and not flying and not active("misc_longjump") then Player.speed(dt, humanoid, root) end
            if active("misc_noaccel") and not (flying or active("misc_speed") or invis) then Player.noAccel(humanoid, root) end
            if active("misc_spider") then Player.spider(dt, humanoid, root) end
            Player.jumps(now, dt, humanoid, root)
            if active("misc_spinbot") then Player.spin(dt, character, humanoid) end
            if invis then Player.invisStep(dt, now, character, humanoid, root) end
            if flag("misc_anti_killplane", false) then Player.killPlane(root) end
            if active("misc_gravity") and flag("misc_gravity_mode", "Workspace") == "Local" and read(humanoid, "FloorMaterial") == Enum.Material.Air then
                addVelocity(root, Vector3.new(0, dt * (Workspace.Gravity - flag("misc_gravity_value", 196)), 0))
            end
        end
        if not flying then Player.yLevel = nil end
        if not active("misc_spider") then Player.spiderHit = nil end
        if not active("misc_no_jump_cd") and Player.antiJump.humanoid then Player.releaseJump() end
        if not active("misc_disabler") and Player.collide.head then Player.releaseCollide() end
        if not invis and Player.invis.on then Player.invisOff() end
        if flag("misc_anti_fling", false) then
            Player.antiFling(humanoid)
        elseif Player.fling.container then
            Player.flingOff()
        end
        if flag("misc_anti_riot", false) then Player.antiRiot(records) end
        if flag("char_fence_safe", false) then
            Player.fenceSafe(now)
        elseif #Player.fences.parts > 0 then
            Player.fences = { parts = {}, nextScan = 0 }
        end
        if Player.corpse then Player.sinkBody(now) end
        Player.flying = flying
        if flag("misc_camera_zoom", false) then
            hold(LocalPlayer, "CameraMaxZoomDistance", flag("misc_camera_zoom_max", 100000))
            hold(LocalPlayer, "CameraMode", Enum.CameraMode.Classic)
        end
        if flag("misc_camera_phase", false) then hold(LocalPlayer, "DevCameraOcclusionMode", Enum.DevCameraOcclusionMode.Invisicam) end
        if active("misc_gravity") and flag("misc_gravity_mode", "Workspace") == "Workspace" then hold(Workspace, "Gravity", flag("misc_gravity_value", 196)) end
        settle()
    end

    function Player.restoreAll()
        Player.flying, Player.corpse, Player.yLevel, Player.spiderHit = false, nil, nil, nil
        Player.high, Player.long = { started = nil }, { enableAt = nil }
        Player.releaseJump()
        Player.releaseCollide()
        Player.invisOff()
        Player.flingOff()
        Player.fences = { parts = {}, nextScan = 0 }
        want = {}
        settle()
    end

    -- cheat detector (dev: 20 hits for phase/speed/high jump, 1 for teleport/state/animation, flagged once per player)
    function Player.cheat(other, kind, limit)
        if not flag("misc_cheat_detector", false) or Player.flagged[other] then return end
        local counts = Player.cheats[other]
        if not counts then
            counts = {}
            Player.cheats[other] = counts
        end
        counts[kind] = (counts[kind] or 0) + 1
        if counts[kind] > limit then
            Player.flagged[other] = kind
            say(other.Name .. " may be cheating (" .. kind .. ")")
        end
    end

    function Player.clear(quiet)
        Player.flagged, Player.cheats = {}, {}
        if not quiet then say("Cheat flags cleared") end
    end

    local function overlapOf(include, list)
        local overlap = OverlapParams.new()
        overlap.FilterType = include and Enum.RaycastFilterType.Include or Enum.RaycastFilterType.Exclude
        overlap.FilterDescendantsInstances = list
        return overlap
    end

    local function pointIsFree(position)
        local ok, free = pcall(function()
            local list = {}
            for _, name in ipairs({ "CarContainer", "Doors" }) do
                local folder = Workspace:FindFirstChild(name)
                if folder then list[#list + 1] = folder end
            end
            local overlap = overlapOf(false, list)
            overlap.CollisionGroup = "Players"
            for _, part in ipairs(Workspace:GetPartBoundsInRadius(position, 0, overlap)) do
                if part.CanCollide and (part:GetClosestPointOnSurface(position) - position).Magnitude <= 0.0001 then return false end
            end
            return true
        end)
        return not ok or free
    end

    local function nearCar(position)
        local cars = Workspace:FindFirstChild("CarContainer")
        if not cars then return false end
        local ok, near = pcall(function()
            local overlap = overlapOf(true, { cars })
            overlap.MaxParts = 1
            return #Workspace:GetPartBoundsInRadius(position, 30, overlap) > 0
        end)
        return ok and near
    end

    function Player.detect(now)
        local inmates = game:GetService("Teams"):FindFirstChild("Inmates")
        for _, other in ipairs(Players:GetPlayers()) do
            local character = other ~= LocalPlayer and other.Character
            local humanoid = character and Game.humanoid(character)
            local root = character and character:FindFirstChild("HumanoidRootPart")
            local head = character and character:FindFirstChild("Head")
            if humanoid and root and head and (read(humanoid, "Health") or 0) > 0 then
                if Player.lastChar[other] ~= character then
                    Player.lastChar[other], Player.spawned[other], Player.positions[other] = character, now, nil
                end
                if not Player.flagged[other] then
                    local position = root.Position
                    if not pointIsFree(head.Position) then Player.cheat(other, "phase/noclip", 20) end
                    local state = stateOf(humanoid)
                    if state and not CHEAT_STATES[state] then Player.cheat(other, "invalid state " .. tostring(state.Name or state), 1) end
                    local velocity = read(root, "AssemblyLinearVelocity") or ZERO
                    if not read(humanoid, "SeatPart") then
                        if (velocity * FLAT).Magnitude > 26 and not nearCar(position) then Player.cheat(other, "speed", 20) end
                        local prev = Player.positions[other]
                        if prev and flag("misc_cheat_teleport", true) and ((position - prev[1]) * FLAT).Magnitude > 50 and not nearCar(position) then
                            local fresh = other.Team == inmates and (now - (Player.spawned[other] or 0)) <= 0.1
                            if not fresh then Player.cheat(other, "teleport", 1) end
                        end
                        if velocity.Y > 50 then Player.cheat(other, "highjump", 20) end
                        if not prev or (now - prev[2]) > 0.2 then Player.positions[other] = { position, now } end
                    else
                        Player.positions[other] = { position, now }
                    end
                end
            end
        end
    end

    function Player.monitorStep(dt, now)
        if flag("misc_anti_invis", false) then
            Player.antiInvis(dt)
        elseif Player.animCheck.on then
            Player.antiInvisOff()
        end
        if not flag("misc_cheat_detector", false) then return end
        Player.cheatAcc = Player.cheatAcc + dt
        if Player.cheatAcc < 0.05 then return end
        Player.cheatAcc = 0
        Player.detect(now)
    end

    -- the step settles (restores) whatever a flag stopped holding, so it runs while any of its flags is on and once more after
    function Player.sync()
        if anyOn(MOVE_FLAGS) then
            if not Loop.has("player_move") then Loop.register("player_move", Player.step, 35) end
        elseif Loop.has("player_move") then
            Loop.unregister("player_move")
            Player.restoreAll()
        end
        if anyOn(MONITOR_FLAGS) then
            if not Loop.has("player_monitor") then Loop.register("player_monitor", Player.monitorStep, 145) end
        elseif Loop.has("player_monitor") then
            Loop.unregister("player_monitor")
            Player.antiInvisOff()
        end
    end
    Util.changed(MOVE_FLAGS, Player.sync)
    Util.changed(MONITOR_FLAGS, Player.sync)
    Util.changed("misc_highjump", function() Player.high.started = nil end)
    Util.changed("misc_longjump", function() Player.long.enableAt = nil end)
    Util.changed("misc_cheat_detector", function(_, on)
        if on then return end
        Player.positions, Player.spawned, Player.lastChar = {}, {}, {}
        Player.clear(true)
    end)
    Util.feature("misc_disabler", function()
        if type(Compat.getconnections) == "function" then return end
        say("Disabler needs getconnections")
        task.defer(switchOff, "misc_disabler")
    end, function() end)
    Util.feature("misc_phase", function()
        local ok, stepped = pcall(function() return RunService.Stepped end)
        if ok and stepped then Player.phase.connection = stepped:Connect(function() Util.guard("phase", Player.phaseStep) end) end
    end, function()
        local connection = Player.phase.connection
        if connection then pcall(function() connection:Disconnect() end) end
        Player.phase.connection = nil
        phaseRelease()
    end)

    local okJump, jumpRequest = pcall(function() return UserInputService.JumpRequest end)
    if okJump and jumpRequest then
        Util.track(jumpRequest:Connect(function()
            if not active("misc_infjump") then return end
            local _, humanoid = localParts()
            if humanoid then changeState(humanoid, "Jumping") end
        end))
    end

    Util.track(Game.events.onLocalDied:Connect(function()
        if not flag("misc_destroy_body", false) then return end
        local character = Game.localCharacter()
        if character then Player.corpse = { character = character } end
    end))

    Util.track(UserInputService.InputBegan:Connect(function(input, processed)
        if processed or not active("misc_clicktp") or Util.typing() then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        if flag("misc_clicktp_ctrl", true) and not keyDown("LeftControl") then return end
        local character = Game.localCharacter()
        local cam = Game.camera()
        if not (character and cam) then return end
        local ok, hit = pcall(function()
            local at = UserInputService:GetMouseLocation()
            local ray = cam:ViewportPointToRay(at.X, at.Y)
            local result = Workspace:Raycast(ray.Origin, ray.Direction * 3000, excludeParams({ character, cam }))
            return result and result.Position
        end)
        if ok and hit then Player.clickTo(hit) end
    end))

    Util.track(Game.events.onRespawn:Connect(function()
        Player.flying, Player.yLevel = false, nil
        if flag("char_reapply", true) then return end
        for _, name in ipairs({ "misc_walk", "misc_jumpmult", "misc_no_jump_cd", "misc_camera_zoom", "misc_gravity" }) do switchOff(name) end
    end))

    Util.track(Players.PlayerRemoving:Connect(function(other)
        Player.cheats[other], Player.flagged[other], Player.positions[other], Player.spawned[other], Player.lastChar[other] = nil, nil, nil, nil, nil
    end))

    -- interact: melee aura, auto arrest, auto taze, anti taze
    local MC = { active = {}, acc = { melee = 0, arrest = 0, taze = 0 }, arrestUntil = 0, cooldown = 0, job = nil, warned = false, tasedUntil = 0, lastSpeed = 16, lastJump = 7.2 }
    local TASE_ANIMS = { ["279227693"] = true, ["279229192"] = true }
    Player.interact = MC

    local function aliveParts()
        local character = Game.localCharacter()
        if not character then return nil end
        local humanoid = Game.humanoid(character)
        local root = character:FindFirstChild("HumanoidRootPart")
        if humanoid and root and humanoid.Health > 0 then return character, humanoid, root end
        return nil
    end

    local function edge(name, on)
        local was = MC.active[name] == true
        MC.active[name] = on
        if on and not was then return "start" end
        if was and not on then return "stop" end
        return nil
    end

    local function usable(record)
        return record.player ~= LocalPlayer and record.head ~= nil and record.root ~= nil and record.humanoid ~= nil and record.humanoid.Health > 0
    end

    function MC.melee(dt, now, records)
        local on = flag("misc_melee", false)
        if edge("melee", on) == "start" then MC.acc.melee = 0 end
        if not on then return end
        MC.acc.melee = MC.acc.melee + dt
        if MC.acc.melee < flag("misc_melee_delay", 0.5) then return end
        MC.acc.melee = 0
        local melee = Game.remote("meleeEvent")
        if not melee then
            Util.note("mc_melee_remote", "meleeEvent not found")
            return
        end
        local _, _, root = aliveParts()
        if not root then return end
        local range = flag("misc_melee_range", 15)
        for _, record in ipairs(records or {}) do
            if usable(record) and (record.root.Position - root.Position).Magnitude < range
                and not (flag("misc_melee_friendly", true) and Game.relation(record.player) == "friend")
                and not (flag("misc_melee_ff", true) and record.model:FindFirstChildOfClass("ForceField")) then
                melee:FireServer(record.player, 1, 1)
            end
        end
    end

    function MC.arrestable(record)
        local model, state, team = record.model, Game.state(record.player), Game.team(record.player)
        if model:FindFirstChildOfClass("ForceField") or model:GetAttribute("Arrested") then return false end
        if team == "Criminals" then return flag("misc_arrest_criminals", true) end
        if team == "Inmates" then
            if not flag("misc_arrest_inmates", true) then return false end
            if state.hostile then return state.tased end
            return state.trespassing
        end
        return false
    end

    function MC.arrest(dt, now, records)
        local on = flag("misc_autoarrest", false)
        if edge("arrest", on) == "start" then MC.warned = false end
        if not on then return end
        MC.acc.arrest = MC.acc.arrest + dt
        if MC.acc.arrest < 0.05 or now < MC.arrestUntil then return end
        MC.acc.arrest = 0
        local arrest = Game.remote("Remotes.ArrestPlayer")
        if not arrest then
            Util.note("mc_arrest_remote", "ArrestPlayer remote not found")
            return
        end
        local character, humanoid, root = aliveParts()
        if not character or Game.team(LocalPlayer) ~= "Guards" then return end
        local range = math.min(flag("misc_arrest_range", 7.5), 7.5)
        local best, bestDist
        for _, record in ipairs(records or {}) do
            if usable(record) then
                local dist = (record.root.Position - root.Position).Magnitude
                if dist <= range and MC.arrestable(record) and (not bestDist or dist < bestDist) then
                    best, bestDist = record, dist
                end
            end
        end
        if not best then return end

        if not character:FindFirstChild("Handcuffs") and flag("misc_arrest_hand", true) then
            local pack = LocalPlayer:FindFirstChildOfClass("Backpack")
            local cuffs = pack and pack:FindFirstChild("Handcuffs")
            if cuffs then
                humanoid:EquipTool(cuffs)
                MC.arrestUntil = now + 0.4
            elseif not MC.warned then
                MC.warned = true
                Util.notify("Auto arrest needs the Handcuffs tool", "warn", 4)
            end
            return
        end

        local target = best.player
        MC.arrestUntil = now + 0.5
        task.spawn(function()
            local ok, result = pcall(function() return arrest:InvokeServer(target, 1) end)
            if ok and result then
                MC.arrestUntil = os.clock() + 7
                if flag("misc_arrest_notify", false) then Util.notify("Arrested " .. target.Name, "ok", 4) end
            end
        end)
    end

    function MC.wanted(player, model)
        if LocalPlayer.TeamColor == player.TeamColor then return false end
        local state = Game.state(player)
        if state.tased or model:GetAttribute("Arrested") or model:FindFirstChildOfClass("ForceField") then return false end
        if Game.team(LocalPlayer) == "Guards" then
            local team = Game.team(player)
            if team == "Criminals" then return true end
            if team == "Inmates" then return state.hostile or state.trespassing end
            return false
        end
        return true
    end

    local function visible(from, record, character)
        return Workspace:Raycast(from, record.head.Position - from, Game.newParams({ character, record.model })) == nil
    end

    local function fireAt(part, position)
        return Combat ~= nil and type(Combat.fireAt) == "function" and Combat.fireAt(part, position) == true
    end

    local function finishJob(now)
        MC.job = nil
        MC.cooldown = now + 1.5
    end

    local function shootJob(job, now)
        finishJob(now)
        local character = LocalPlayer.Character
        if not character or job.taser.Parent ~= character then return end
        local head = character:FindFirstChild("Head")
        if not head then return end
        if fireAt(job.head, job.head.Position) then return end
        local shoot = Game.remote("GunRemotes.ShootEvent")
        if shoot then
            pcall(function() shoot:FireServer({ { head.Position, job.head.Position, job.head } }) end)
        end
    end

    function MC.runJob(now)
        local job = MC.job
        if now < job.nextPoll then return end
        job.nextPoll = now + 0.05
        local character = LocalPlayer.Character
        if not character or not job.head.Parent or not job.humanoid or job.humanoid.Health <= 0 then return finishJob(now) end
        if not flag("misc_autotaze", false) or not MC.wanted(job.player, job.model) then return finishJob(now) end
        if now >= job.deadline then return shootJob(job, now) end
        if job.taser.Parent == character then
            local reload = job.taser:GetAttribute("Local_ReloadSession") or 0
            local ammo = job.taser:GetAttribute("Local_CurrentAmmo") or 1
            if reload == 0 and ammo > 0 then return shootJob(job, now) end
            if reload == 0 and ammo <= 0 and not job.kicked then
                job.kicked = true
                fireAt(job.head, job.head.Position)
            end
        end
    end

    function MC.taze(dt, now, records)
        local on = flag("misc_autotaze", false)
        local change = edge("taze", on)
        if change == "start" then
            MC.acc.taze = 0
            if Combat and Combat.wants then Combat.wants.auto = true end
        elseif change == "stop" then
            if Combat and Combat.wants then Combat.wants.auto = nil end
            if MC.job then finishJob(now) end
        end
        if not on then return end
        MC.acc.taze = MC.acc.taze + dt
        if MC.job then return MC.runJob(now) end
        if MC.acc.taze < 0.05 or now < MC.cooldown or (MC.arrestUntil - now) >= 3 then return end
        MC.acc.taze = 0
        local character, humanoid, root = aliveParts()
        if not character then return end
        local pack = LocalPlayer:FindFirstChildOfClass("Backpack")
        local taser = character:FindFirstChild("Taser") or (pack and pack:FindFirstChild("Taser"))
        if not taser then return end
        if flag("misc_taze_velocity", true) and root.AssemblyLinearVelocity.Magnitude >= 40 then return end
        local head = character:FindFirstChild("Head")
        if not head then return end
        local range = flag("misc_taze_range", 52)
        local best, bestDist
        for _, record in ipairs(records or {}) do
            if usable(record) then
                local dist = (record.head.Position - head.Position).Magnitude
                if dist <= range and MC.wanted(record.player, record.model) and visible(head.Position, record, character) and (not bestDist or dist < bestDist) then
                    best, bestDist = record, dist
                end
            end
        end
        if not best then return end
        if taser.Parent ~= character then humanoid:EquipTool(taser) end
        MC.job = { player = best.player, model = best.model, head = best.head, humanoid = best.humanoid, taser = taser, deadline = now + 5, nextPoll = now, kicked = false }
        MC.runJob(now)
    end

    function MC.onTased()
        if not flag("misc_anti_taze", false) then return end
        MC.tasedUntil = os.clock() + 4
        task.delay(0.15, function()
            pcall(function() game:GetService("StarterGui"):SetCore("ResetButtonCallback", true) end)
        end)
    end

    function MC.antiTaze(dt, now)
        local on = flag("misc_anti_taze", false)
        if edge("antitaze", on) == "stop" then MC.tasedUntil = 0 end
        if not on then return end
        local _, humanoid = aliveParts()
        if not humanoid then return end
        if now < MC.tasedUntil then
            if humanoid.WalkSpeed < MC.lastSpeed then humanoid.WalkSpeed = MC.lastSpeed end
            if humanoid.JumpHeight < MC.lastJump then humanoid.JumpHeight = MC.lastJump end
            if flag("misc_anti_taze_block", false) then
                pcall(function()
                    LocalPlayer:SetAttribute("BackpackEnabled", true)
                    local animator = humanoid:FindFirstChildOfClass("Animator")
                    if animator then
                        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                            local id = track.Animation and tostring(track.Animation.AnimationId):match("%d+")
                            if id and TASE_ANIMS[id] then track:Stop(0) end
                        end
                    end
                end)
            end
        else
            if humanoid.WalkSpeed > 0 then MC.lastSpeed = humanoid.WalkSpeed end
            if humanoid.JumpHeight > 0 then MC.lastJump = humanoid.JumpHeight end
        end
    end

    Util.track(Game.events.onTased:Connect(MC.onTased))

    -- off: one more step with the flag false runs its stop edge
    local function system(flagName, name, fn, priority)
        Util.feature(flagName, function() Loop.register(name, fn, priority) end, function()
            Loop.unregister(name)
            Util.guard(name .. " stop", fn, 0, os.clock(), {})
        end)
    end
    system("misc_anti_taze", "mc_antitaze", MC.antiTaze, 36)
    system("misc_melee", "mc_melee", MC.melee, 90)
    system("misc_autoarrest", "mc_arrest", MC.arrest, 91)
    system("misc_autotaze", "mc_taze", MC.taze, 92)

    -- menu: misc > movement / character / interact (dev.lua rows, ranges and defaults)
    local row = Util.row
    local function unit(suffix) return function(v) return v .. suffix end end
    local studs, speedUnit = unit(" studs"), unit(" studs/s")
    local movePage, charPage, interactPage = Pages.misc.movement, Pages.misc.character, Pages.misc.interact
    local MODES = { "Velocity", "Impulse", "CFrame" }

    local move = movePage:Card({ name = "movement", id = "movement", side = "left" })
    local _, g = row(move, "Fly", "misc_fly", { key = "misc_fly_key", gear = "fly" })
    g:Dropdown({ name = "Mode", flag = "misc_fly_mode", options = { "Velocity", "CFrame" }, default = "Velocity" })
    g:Slider({ name = "Speed", flag = "misc_fly_speed", min = 1, max = 150, step = 1, default = 50, fmt = studs })
    g:Slider({ name = "Vertical speed", flag = "misc_fly_vspeed", min = 1, max = 100, step = 1, default = 40, fmt = studs })
    row(g, "Height cap (49.9)", "misc_fly_cap")
    g:Label({ name = "Up: Space   Down: Left Ctrl" })
    _, g = row(move, "Speed", "misc_speed", { key = "misc_speed_key", gear = "speed" })
    g:Dropdown({ name = "Mode", flag = "misc_speed_mode", options = { "Velocity", "CFrame", "WalkSpeed" }, default = "Velocity" })
    g:Slider({ name = "Speed", flag = "misc_speed_value", min = 1, max = 150, step = 1, default = 50, fmt = studs })
    _, g = row(move, "Spider", "misc_spider", { key = "misc_spider_key", gear = "spider" })
    g:Dropdown({ name = "Mode", flag = "misc_spider_mode", options = MODES, default = "Velocity" })
    g:Slider({ name = "Climb speed", flag = "misc_spider_speed", min = 1, max = 100, step = 1, default = 30, fmt = studs })
    row(g, "Climb state", "misc_spider_state")
    _, g = row(move, "Walk speed", "misc_walk", { key = "misc_walk_key", gear = "walk speed" })
    g:Slider({ name = "Walk speed", flag = "misc_walk_value", min = 16, max = 200, step = 1, default = 16, fmt = speedUnit })
    row(g, "Automatic speed", "misc_walk_auto", { tip = "Picks the speed from where you are: inside a building of the prison, in the prison area, or outside the prison" })
    row(g, "Use custom speed", "misc_walk_custom", { tip = "Use the three sliders below. When off, automatic speed uses 32 / 50 / 100." })
    g:Slider({ name = "Speed inside prison", flag = "misc_walk_in", min = 16, max = 32, step = 1, default = 32, fmt = speedUnit })
    g:Slider({ name = "Speed in prison area", flag = "misc_walk_yard", min = 16, max = 100, step = 1, default = 50, fmt = speedUnit })
    g:Slider({ name = "Speed outside prison", flag = "misc_walk_out", min = 16, max = 100, step = 1, default = 100, fmt = speedUnit })
    row(g, "Notify area changes", "misc_walk_notify", { tip = "Shows which area the script thinks you are in" })
    row(move, "No acceleration", "misc_noaccel", { key = "misc_noaccel_key", tip = "Start and stop at full speed instead of speeding up and sliding" })

    local jumps = movePage:Card({ name = "jumps", id = "jumps", side = "right" })
    _, g = row(jumps, "High jump", "misc_highjump", { key = "misc_highjump_key", gear = "high jump" })
    g:Dropdown({ name = "Mode", flag = "misc_highjump_mode", options = { "Velocity", "Impulse", "Instant" }, default = "Velocity" })
    g:Slider({ name = "Power", flag = "misc_highjump_power", min = 1, max = 150, step = 1, default = 50, fmt = studs })
    row(g, "Auto disable (one jump)", "misc_highjump_auto", { def = true })
    _, g = row(jumps, "Long jump", "misc_longjump", { key = "misc_longjump_key", gear = "long jump" })
    g:Dropdown({ name = "Mode", flag = "misc_longjump_mode", options = MODES, default = "Velocity" })
    g:Slider({ name = "Speed", flag = "misc_longjump_speed", min = 1, max = 150, step = 1, default = 50, fmt = studs })
    row(g, "Auto disable on landing", "misc_longjump_auto", { def = true })
    _, g = row(jumps, "Jump multiplier", "misc_jumpmult", { key = "misc_jumpmult_key", gear = "jump multiplier" })
    g:Slider({ name = "Jump multiplier (max 3x)", flag = "misc_jumpmult_value", min = 1, max = 3, step = 0.05, default = 1.5, fmt = unit("x") })
    row(jumps, "Infinite jump", "misc_infjump", { key = "misc_infjump_key" })
    row(jumps, "No jump cooldown", "misc_no_jump_cd", { tip = "Turns off the game's AntiJump script. Without getconnections, holding Space jumps again on landing" })

    local extras = movePage:Card({ name = "phase + extras", id = "phase", side = "right" })
    _, g = row(extras, "Phase", "misc_phase", { key = "misc_phase_key", gear = "phase" })
    g:Dropdown({ name = "Mode", flag = "misc_phase_mode", options = { "Part", "Character", "CFrame" }, default = "Part" })
    g:Slider({ name = "Wall size (CFrame)", flag = "misc_phase_size", min = 1, max = 20, step = 1, default = 5, fmt = studs })
    g:Label({ name = "Hold Shift to Phase while Spider is on" })
    row(extras, "Disabler (fixes Character mode)", "misc_disabler", { tip = "Stops the game forcing your head collision back on. Needs getconnections" })
    _, g = row(extras, "Spinbot", "misc_spinbot", { key = "misc_spinbot_key", gear = "spinbot" })
    g:Slider({ name = "Spin speed", flag = "misc_spinbot_speed", min = 1, max = 40, step = 1, default = 10 })
    _, g = row(extras, "Click teleport", "misc_clicktp", { key = "misc_clicktp_key", gear = "click teleport" })
    row(g, "Hold Left Ctrl to teleport", "misc_clicktp_ctrl", { def = true })
    g:Slider({ name = "Click teleport range", flag = "misc_clicktp_range", min = 10, max = 2000, step = 1, default = 500, fmt = studs })

    local char = charPage:Card({ name = "character", id = "character", side = "left" })
    row(char, "Camera phase", "misc_camera_phase")
    _, g = row(char, "Infinite camera zoom", "misc_camera_zoom", { gear = "zoom", tip = "Lets you scroll the camera out as far as you want, in third person" })
    g:Slider({ name = "Max zoom distance", flag = "misc_camera_zoom_max", min = 100, max = 100000, step = 1, default = 100000, fmt = studs })
    _, g = row(char, "Gravity", "misc_gravity", { gear = "gravity" })
    g:Dropdown({ name = "Gravity mode", flag = "misc_gravity_mode", options = { "Workspace", "Local" }, default = "Workspace" })
    g:Slider({ name = "Gravity value", flag = "misc_gravity_value", min = 0, max = 300, step = 1, default = 196 })
    row(char, "Keep after respawn", "char_reapply", { def = true, tip = "Off: walk speed, jump multiplier, jump cooldown, zoom and gravity switch off when you respawn" })

    local invisCard = charPage:Card({ name = "invisibility", id = "invisibility", side = "left" })
    _, g = row(invisCard, "Invisibility", "misc_invis", { key = "misc_invis_key", gear = "invisibility" })
    row(g, "Hide under the map (look up)", "misc_invis_under", { def = true })
    row(g, "Move while hidden", "misc_invis_move")
    g:Slider({ name = "Look-up pitch", flag = "misc_invis_pitch", min = -90, max = 90, step = 1, default = 90, fmt = unit("\194\176") })

    local protect = charPage:Card({ name = "protection", id = "protection", side = "right" })
    row(protect, "Anti taze", "misc_anti_taze")
    row(protect, "Anti taze: no animation", "misc_anti_taze_block", { tip = "Also stops the taze animation and keeps your backpack usable. It never touches the game's scripts, so it can not crash the game" })
    row(protect, "Anti fling", "misc_anti_fling")
    row(protect, "Destroy body on death", "misc_destroy_body")
    row(protect, "Anti riot shield", "misc_anti_riot")
    row(protect, "Anti kill plane", "misc_anti_killplane")
    row(protect, "Anti invisible", "misc_anti_invis")
    row(protect, "Fence protection", "char_fence_safe", { tip = "The electrified prison fences stop registering your touch, so they do not hurt you; restored when off" })

    local detector = charPage:Card({ name = "cheat detector", id = "detector", side = "right" })
    row(detector, "Cheat detector", "misc_cheat_detector")
    row(detector, "Teleport check", "misc_cheat_teleport", { def = true })
    detector:Button({ name = "Clear flags", callback = function() Player.clear() end })

    local melee = interactPage:Card({ name = "melee aura", id = "melee", side = "left" })
    _, g = row(melee, "Melee aura", "misc_melee", { gear = "melee aura" })
    g:Slider({ name = "Range", flag = "misc_melee_range", min = 1, max = 15, step = 1, default = 15, fmt = studs })
    g:Slider({ name = "Delay", flag = "misc_melee_delay", min = 0.1, max = 1, step = 0.05, default = 0.5, fmt = unit("s") })
    row(g, "Skip friendly players", "misc_melee_friendly", { def = true })
    row(g, "Skip forcefield", "misc_melee_ff", { def = true })

    local arrestCard = interactPage:Card({ name = "arrest + taze", id = "arrest", side = "right" })
    _, g = row(arrestCard, "Auto arrest", "misc_autoarrest", { gear = "auto arrest" })
    g:Slider({ name = "Range", flag = "misc_arrest_range", min = 1, max = 7.5, step = 0.5, default = 7.5, fmt = studs })
    row(g, "Equip handcuffs", "misc_arrest_hand", { def = true })
    row(g, "Arrest inmates", "misc_arrest_inmates", { def = true })
    row(g, "Arrest criminals", "misc_arrest_criminals", { def = true })
    row(g, "Notify on arrest", "misc_arrest_notify")
    _, g = row(arrestCard, "Auto taze", "misc_autotaze", { gear = "auto taze" })
    g:Slider({ name = "Range", flag = "misc_taze_range", min = 1, max = 52, step = 1, default = 52, fmt = studs })
    row(g, "Velocity check", "misc_taze_velocity", { def = true })

    Player.sync()

    Util.onUnload(function()
        Loop.unregister("player_move")
        Loop.unregister("player_monitor")
        local connection = Player.phase.connection
        if connection then pcall(function() connection:Disconnect() end) end
        Player.phase.connection = nil
        phaseRelease()
        Player.restoreAll()
        Player.antiInvisOff()
        if Combat and Combat.wants then Combat.wants.auto = nil end
        MC.job, MC.active, MC.tasedUntil = nil, {}, 0
        Player.positions, Player.flagged, Player.cheats = {}, {}, {}
    end)
end
bootMark("player", PL2BootT, 10, 13)

PL2BootT = PL2BootClock()
-- [src] 70_map.lua
do
    Map = { queue = {}, job = nil, hopping = false }
    local ZERO = Vector3.new(0, 0, 0)
    local LIFT = Vector3.new(0, 3, 0)
    local FLAT = Vector3.new(1, 0, 1)
    local TAU = math.pi * 2
    local now = os.clock
    local okTags, CollectionService = pcall(function() return game:GetService("CollectionService") end)
    if not okTags then CollectionService = nil end

    -- dev.lua: touch givers are stood under (10 studs below the pivot) on a pad, click givers 3 above; GiverPressed every frame
    Map.GUNS = { "AK-47", "Remington 870", "MP5", "M700", "M4A1", "FAL", "Revolver" }
    Map.GIVERS = {
        ["AK-47"] = { method = "touch", needles = { "ak-47", "ak47" }, tool = { "AK-47", "AK47" }, item = "AK-47", keys = { "ak47", "ak" }, at = Vector3.new(-931.86, 92.2, 2039.39) },
        ["Remington 870"] = { method = "touch", needles = { "remington", "870" }, tool = { "Remington 870", "Remington" }, item = "Remington 870", keys = { "r870", "remington870", "remington" }, at = Vector3.new(820.45, 100.8, 2229.68) },
        ["MP5"] = { method = "touch", needles = { "mp5" }, tool = { "MP5" }, item = "MP5", keys = { "mp5" }, at = Vector3.new(813.8, 100.8, 2229.62) },
        ["M700"] = { method = "click", needles = { "m700" }, tool = { "M700" }, item = "M700", keys = { "m700" }, at = Vector3.new(-919.51, 95.07, 2036.23) },
        ["M4A1"] = { method = "click", needles = { "m4a1", "m4" }, tool = { "M4A1" }, item = "M4A1", keys = { "m4a1", "m4" }, at = Vector3.new(847.68, 100.88, 2229.05) },
        ["FAL"] = { method = "click", needles = { "fal" }, tool = { "FAL" }, item = "FAL", keys = { "fal" }, at = Vector3.new(-902.63, 94.35, 2047.25) },
        ["Revolver"] = { method = "click", needles = { "revolver" }, tool = { "Revolver" } },
    }
    Map.PLACES = {
        { "Yard", Vector3.new(780.21, 98, 2470.5) }, { "Academy", Vector3.new(795.87, 98.19, 2542.61) }, { "Prison", Vector3.new(913.48, 100, 2388.36) },
        { "Armory", Vector3.new(831.13, 99.98, 2233.09) }, { "Cafeteria", Vector3.new(905.89, 99.99, 2316.14) }, { "Kitchen", Vector3.new(923.09, 99.99, 2231.35) },
        { "Police car spawner", Vector3.new(615.18, 98.2, 2501.2) }, { "Top of the city building", Vector3.new(-309.72, 118.04, 2015.59) },
    }
    Map.ITEMS = { "Key card", "Breakfast", "Lunch", "Dinner", "Soda", "Chips", "Chocolate" }
    Map.ITEM_PATHS = { ["Key card"] = { "Key card" }, Breakfast = { "Breakfast" }, Lunch = { "Lunch" }, Dinner = { "Dinner" },
        Soda = { "Snacks", "Soda" }, Chips = { "Snacks", "Chips" }, Chocolate = { "Snacks", "Chocolate" } }
    Map.TEAMS = { "Inmates", "Guards", "Neutral" }
    Map.KEYCARD = "Key card"
    Map.FOODS = { Dinner = true, Lunch = true, Breakfast = true }
    Map.cards, Map.keyAt = {}, 0
    Map.food = { phase = nil, at = 0, nextAt = 0, warnAt = 0 }
    Map.doors, Map.doorIndex, Map.doorBlocks = {}, {}, {}
    Map.doorsDirty, Map.doorScanAt, Map.doorTickAt, Map.doorsAll, Map.doorsLive = true, 0, 0, false, false

    local function flag(name, default)
        local value = Util.F(name)
        if value == nil then return default end
        return value
    end

    local function switchOff(name)
        if Util.F(name) then Aster:Set(name, false) end
    end

    local function say(text)
        Util.notify(text, "info", 3)
    end

    local function localParts()
        local character = Game.localCharacter()
        if not character then return nil end
        return character, Game.humanoid(character), character:FindFirstChild("HumanoidRootPart")
    end

    local function assign(object, key, value)
        if object[key] ~= value then pcall(function() object[key] = value end) end
    end

    local function keyDown(name)
        if Util.typing() then return false end
        local ok, down = pcall(function() return UserInputService:IsKeyDown(Enum.KeyCode[name]) end)
        return ok and down == true
    end

    local function list(entries)
        local out = {}
        for index, entry in ipairs(entries) do out[index] = entry[1] end
        return out
    end

    local function nameHas(name, needles)
        local lowered = string.lower(tostring(name))
        for _, needle in ipairs(needles) do
            if lowered:find(needle, 1, true) then return true end
        end
        return false
    end

    local function positionOf(item)
        if item:IsA("BasePart") then return item.Position end
        local part = item:FindFirstChild("TouchGiver") or item:FindFirstChild("ITEMPICKUP")
        if part and part:IsA("BasePart") then return part.Position end
        for _, child in ipairs(item:GetDescendants()) do
            if child:IsA("BasePart") then return child.Position end
        end
        local ok, pivot = pcall(function() return item:GetPivot().Position end)
        if ok then return pivot end
        return nil
    end

    function Map.findTool(name)
        local pack = LocalPlayer:FindFirstChildOfClass("Backpack")
        local character = Game.localCharacter()
        return (pack and pack:FindFirstChild(name)) or (character and character:FindFirstChild(name)) or nil
    end

    local function hasTool(names)
        for _, name in ipairs(names) do
            local found = Map.findTool(name)
            if found then return found end
        end
        return nil
    end

    -- every giver model carries the tool it gives in its ToolName attribute (the old Prison_ITEMS names are gone)
    function Map.givers()
        local found, seen = {}, {}
        local function add(object)
            if object and not seen[object] then
                seen[object] = true
                found[#found + 1] = object
            end
        end
        if CollectionService then
            pcall(function()
                for _, tag in ipairs({ "Giver", "TouchGiver" }) do
                    for _, object in ipairs(CollectionService:GetTagged(tag)) do add(object) end
                end
            end)
        end
        for _, object in ipairs(Workspace:GetDescendants()) do
            if object:IsA("Model") and type(object:GetAttribute("ToolName")) == "string" then add(object) end
        end
        return found
    end

    function Map.giverFor(name)
        local entry = Map.GIVERS[name]
        if not entry then return nil end
        local root = Game.rootPart()
        local anchor = entry.method == "touch" and entry.at or (root and root.Position)
        local best, bestDistance
        for _, giver in ipairs(Map.givers()) do
            local tool = giver:GetAttribute("ToolName")
            local match = (type(tool) == "string" and (tool == name or nameHas(tool, entry.needles))) or (tool == nil and nameHas(giver.Name, entry.needles))
            local at = match and positionOf(giver)
            if at then
                local distance = anchor and (at - anchor).Magnitude or 0
                if not bestDistance or distance < bestDistance then best, bestDistance = giver, distance end
            end
        end
        return best
    end

    local function cleanName(name)
        return (string.gsub(string.gsub(string.lower(name), "_%d+$", ""), "[^%w]", ""))
    end

    function Map.pickup(entry)
        local folder = Workspace:FindFirstChild("Prison_ITEMS")
        if not (folder and entry.item) then return nil end
        local exact = folder:FindFirstChild(entry.item, true)
        if exact then return exact end
        local wanted = {}
        for _, key in ipairs(entry.keys) do wanted[key] = true end
        local best, bestDistance
        for _, object in ipairs(folder:GetDescendants()) do
            if wanted[cleanName(object.Name)] then
                local at = positionOf(object)
                local distance = at and (at - entry.at).Magnitude or math.huge
                if not bestDistance or distance < bestDistance then best, bestDistance = object, distance end
            end
        end
        return best
    end

    function Map.refusal(target)
        if not (target and CollectionService) then return "giver not found (walk closer so it loads)" end
        local model = CollectionService:HasTag(target, "Giver") and target or target.Parent
        if not model then return "unknown" end
        local team = LocalPlayer.Team
        if not (CollectionService:HasTag(model, "Team_Any") or (team and CollectionService:HasTag(model, "Team_" .. team.Name))) then
            local wanted = {}
            for _, tag in ipairs(CollectionService:GetTags(model)) do
                if string.sub(tag, 1, 5) == "Team_" then wanted[#wanted + 1] = string.sub(tag, 6) end
            end
            return "wrong team (needs " .. (#wanted > 0 and table.concat(wanted, "/") or "another team") .. ")"
        end
        local pass = model:FindFirstChild("premiumType") or (model.Parent and model.Parent:FindFirstChild("premiumType"))
        if pass then return "needs the " .. tostring(pass.Value) .. " gamepass" end
        return "refused by the server"
    end

    local function press(remote, target)
        pcall(function() remote:FireServer(target) end)
        local model = target:IsA("Model") and target or target:FindFirstAncestorOfClass("Model")
        if model and model ~= target then pcall(function() remote:FireServer(model) end) end
        local click = type(fireclickdetector) == "function" and fireclickdetector or nil
        if not click then return end
        for _, object in ipairs(target:GetDescendants()) do
            if object:IsA("ClickDetector") then pcall(click, object) end
        end
    end

    local function dropPad(job)
        local pad = job.pad
        job.pad = nil
        if pad then task.delay(0.6, function() pcall(function() pad:Destroy() end) end) end
    end

    -- the pickup fallback (dev getWeaponByPickup): stand on the Prison_ITEMS pickup, invoke after 0.5 s, check after the hold
    local function startPickup(job, at)
        local item = Map.pickup(job.entry)
        if not item then
            say(job.name .. " pickup was not found (it may be taken, it respawns after a while)")
            return false
        end
        local spot = positionOf(item)
        job.phase, job.item, job.started, job.invoked = "pickup", item, at, false
        job.stand = spot and CFrame.new(spot + LIFT) or CFrame.new(job.entry.at)
        job.hold = math.max(flag("tp_time", 0.8), 0.6)
        return true
    end

    function Map.begin(name)
        local entry = Map.GIVERS[name]
        local _, humanoid, root = localParts()
        if not entry then return false end
        if not root or not humanoid or humanoid.Health <= 0 then
            say("You need to be alive")
            return false
        end
        if hasTool(entry.tool) then
            say("Already have " .. name)
            return false
        end
        local at = now()
        local job = { name = name, entry = entry, home = root.CFrame, goHome = flag("tp_return", true), started = at }
        local remote = Game.remote("Remotes.GiverPressed") or Game.remote("SharedModules.Remotes.GiverPressed")
        local target = remote and Map.giverFor(name)
        local spot = target and positionOf(target)
        if spot then
            job.phase, job.remote, job.target = "giver", remote, target
            job.stand = CFrame.new(spot + (entry.method == "touch" and Vector3.new(0, -10, 0) or LIFT))
            job.timeout = entry.method == "touch" and 5 or math.max(flag("tp_time", 0.8), 1.6)
            local pad = Instance.new("Part")
            pad.Name = "Aster_GunPad"
            pad.Size = Vector3.new(16, 1, 16)
            pad.Anchored = true
            pad.Transparency = 1
            pad.CFrame = CFrame.new(job.stand.Position.X, job.stand.Position.Y - 0.5, job.stand.Position.Z)
            pad.Parent = Workspace
            job.pad = pad
        elseif not startPickup(job, at) then
            return false
        end
        Map.job = job
        Loop.register("map_jobs", Map.jobStep, 40, "heartbeat")
        Loop.register("map_jobs_home", Map.jobHome, 1)
        return true
    end

    function Map.nextJob()
        while not Map.job and #Map.queue > 0 do Map.begin(table.remove(Map.queue, 1)) end
    end

    function Map.request(name)
        if Map.job and Map.job.name == name then return false end
        for _, queued in ipairs(Map.queue) do
            if queued == name then return false end
        end
        table.insert(Map.queue, name)
        Map.nextJob()
        return true
    end

    function Map.getWeapon(name)
        return Map.request(name)
    end

    function Map.gettingWeapon()
        return Map.job ~= nil or #Map.queue > 0
    end

    function Map.finish(ok, quiet)
        local job = Map.job
        Map.job = nil
        if job then
            dropPad(job)
            local _, _, root = localParts()
            if root and job.goHome then
                root.CFrame = job.home
                root.AssemblyLinearVelocity = ZERO
            end
            if not quiet and not job.silent then
                if ok then
                    say("Got " .. job.name)
                elseif job.phase == "pickup" then
                    say(job.name .. " was refused by the server: wrong team, missing pass or already taken")
                else
                    say(job.name .. " failed: " .. Map.refusal(job.target))
                end
            end
        end
        if not Map.job then
            Loop.unregister("map_jobs")
            Loop.unregister("map_jobs_home")
        end
        if not quiet then Map.nextJob() end
    end

    -- render step: the character goes back home right after the physics frame it spent on the giver
    function Map.jobHome()
        local job = Map.job
        if not (job and job.back) then return end
        job.back = false
        local _, _, root = localParts()
        if root then
            root.CFrame = job.home
            root.AssemblyLinearVelocity = ZERO
        end
    end

    function Map.jobStep(dt, at)
        local job = Map.job
        if not job then return Map.finish(false, true) end
        local _, humanoid, root = localParts()
        if not root or not humanoid or humanoid.Health <= 0 then return Map.finish(false) end
        if hasTool(job.entry.tool) then return Map.finish(true) end
        if job.phase == "giver" then
            if at - job.started > job.timeout or not job.target.Parent then
                dropPad(job)
                if job.entry.method == "touch" then
                    if startPickup(job, at) then return end
                    job.silent = true
                end
                return Map.finish(false)
            end
            root.CFrame = job.stand
            press(job.remote, job.target)
            job.back = job.goHome
            return
        end
        if at - job.started < job.hold then
            root.AssemblyLinearVelocity = ZERO
            root.CFrame = job.stand * CFrame.new(math.random(-5, 5) / 10, 0, math.random(-5, 5) / 10)
        end
        if not job.invoked and at - job.started >= 0.5 then
            job.invoked = true
            local remote = Game.remote("Remotes.InteractWithItem")
            if not remote then
                say("InteractWithItem remote not found")
                job.silent = true
                return Map.finish(false)
            end
            local item = job.item
            task.spawn(function() pcall(function() remote:InvokeServer(item) end) end)
        end
        if at - job.started >= math.max(job.hold, 0.5) + 0.2 then Map.finish(false) end
    end

    function Map.getItem(name)
        local path = Map.ITEM_PATHS[name]
        local pack = LocalPlayer:FindFirstChildOfClass("Backpack")
        if not path or not pack then return nil end
        local node = ReplicatedStorage:FindFirstChild("Tools")
        for _, step in ipairs(path) do node = node and node:FindFirstChild(step) end
        if not node then
            say(name .. " was not found")
            return nil
        end
        local copy = node:Clone()
        copy.Parent = pack
        say("Added " .. name .. " (client-side copy)")
        return copy
    end

    function Map.gotoPlace(name)
        local _, humanoid, root = localParts()
        local place
        for _, entry in ipairs(Map.PLACES) do
            if entry[1] == name then place = entry[2] end
        end
        if not place or not root then return say("You need to be alive") end
        if humanoid and humanoid.SeatPart then humanoid.Sit = false end
        root.AssemblyLinearVelocity = ZERO
        root.CFrame = CFrame.new(place)
        say("Teleported to " .. name)
    end

    function Map.switchTeam(name)
        local remote = Game.remote("Remotes.RequestTeamChange")
        local team
        local ok, teams = pcall(function() return game:GetService("Teams"):GetTeams() end)
        for _, candidate in ipairs(ok and teams or {}) do
            if candidate.Name == name then team = candidate end
        end
        if not remote or not team then
            say("Team switch unavailable: " .. (remote and "team not found" or "remote not found"))
            return false
        end
        task.spawn(function()
            local sent, result = pcall(function() return remote:InvokeServer(team, 1) end)
            if not sent or result == false then say("The server refused the switch to " .. name) end
        end)
        return true
    end

    -- the settings > players list selection (Builtins) replaces dev's Players tab
    function Map.selectedPlayer()
        local settings = Pages.settings
        local listing = settings and settings.Players
        local ok, picked = pcall(function() return listing and listing:Selected() end)
        local name = ok and type(picked) == "table" and picked.name or (ok and type(picked) == "string" and picked) or nil
        local player = name and Players:FindFirstChild(name)
        if player and player ~= LocalPlayer and player.Parent then return player end
        return nil
    end

    -- vehicle fly + vehicle speed (dev): one heartbeat step while either is on
    local Veh = { saved = {}, seat = nil, flySeat = nil, inCar = false, welds = {} }
    Map.vehicle = Veh

    local function carFolder()
        return Workspace:FindFirstChild("CarContainer")
    end

    function Map.vehicleRestore()
        for seat, saved in pairs(Veh.saved) do
            pcall(function()
                seat.MaxSpeed = saved.speed
                seat.Torque = saved.torque
            end)
        end
        Veh.saved, Veh.seat = {}, nil
    end

    function Map.vehicleStep(dt)
        local _, humanoid, root = localParts()
        local seat = humanoid and humanoid.SeatPart
        if flag("misc_vspeed", false) then
            if seat and seat ~= Veh.seat then
                Veh.seat = seat
                local cars = carFolder()
                if cars and seat:IsDescendantOf(cars) then
                    local model = seat.Parent and seat.Parent.Parent
                    for _, object in ipairs((model or seat.Parent):GetDescendants()) do
                        if object:IsA("VehicleSeat") and not Veh.saved[object] then Veh.saved[object] = { speed = object.MaxSpeed, torque = object.Torque } end
                    end
                end
            end
            if seat then
                local value = flag("misc_vspeed_value", 140)
                for other in pairs(Veh.saved) do
                    if other.Parent then
                        assign(other, "MaxSpeed", value)
                        assign(other, "Torque", 4)
                    end
                end
            end
        elseif next(Veh.saved) then
            Map.vehicleRestore()
        end
        if not flag("misc_vfly", false) then return end
        if not (seat and root) then
            Veh.flySeat, Veh.inCar = nil, false
            return
        end
        if seat ~= Veh.flySeat then
            Veh.flySeat, Veh.welds = seat, {}
            local cars = carFolder()
            Veh.inCar = cars ~= nil and seat:IsA("VehicleSeat") and seat:IsDescendantOf(cars)
            if Veh.inCar then
                pcall(function()
                    local wheels = seat.Parent.Parent:FindFirstChild("Wheels")
                    for _, joint in ipairs(wheels and wheels:GetDescendants() or {}) do
                        if joint.Name == "Rotate" and joint:IsA("JointInstance") and joint.Part0 then Veh.welds[joint] = root.CFrame:ToObjectSpace(joint.Part0.CFrame) end
                    end
                end)
            end
        end
        if not Veh.inCar then return end
        local cam = Game.camera()
        local speed = flag("misc_vfly_speed", 60)
        local vertical = (keyDown("E") and 1 or 0) + (keyDown("Q") and -1 or 0)
        local move = humanoid.MoveDirection
        local _, yaw = cam.CFrame:ToEulerAnglesYXZ()
        root.AssemblyLinearVelocity = Vector3.new(0, 2.25, 0)
        root.AssemblyAngularVelocity = ZERO
        if flag("misc_vfly_camera", true) then
            local turn = CFrame.fromEulerAnglesYXZ(0, yaw, 0)
            local local_ = turn:VectorToObjectSpace(move)
            root.CFrame = CFrame.new(root.Position) * turn * CFrame.new(Vector3.new(local_.X, vertical, local_.Z) * speed * dt)
        else
            root.CFrame = CFrame.new(root.Position + (move + Vector3.new(0, vertical, 0)) * speed * dt) * CFrame.fromEulerAnglesYXZ(0, yaw, 0)
        end
        if flag("misc_vfly_cap", false) and Player and Player.capHeight then Player.capHeight(root, nil, carFolder()) end
        for joint, offset in pairs(Veh.welds) do
            if joint.Part0 then joint.Part0.CFrame = root.CFrame * offset end
        end
    end

    -- car spawner + orbit (dev Actions.carOrbit): engine in the render step, hold/regrab/spawn/strip on heartbeat
    local Cars = { list = {}, angle = 0, center = nil, ground = { at = 0 }, spawn = nil, radius = nil, nextState = 0, nextRegrab = 0, nextStrip = 0, warnAt = 0,
        state = { count = 0, owned = 0, regrabs = 0, stripped = 0, status = "Idle", detail = "", spawning = false } }
    Map.cars = Cars
    local state = Cars.state
    local GARAGE = Vector3.new(615.18, 98.2, 2501.2)
    Map.ORBIT_PRESETS = {
        ["Tornado"] = { car_pattern = "Tornado", car_radius = 40, car_height = 4, car_spread = 60, car_spin = 180, car_gap = 14, car_face = "Direction of travel", car_tilt = 0, car_dir = "Clockwise" },
        ["Halo"] = { car_pattern = "Ring", car_radius = 30, car_height = 25, car_spread = 0, car_spin = 120, car_gap = 14, car_face = "Direction of travel", car_tilt = 0, car_dir = "Clockwise" },
        ["Highway line"] = { car_pattern = "Line", car_radius = 35, car_height = 4, car_spread = 0, car_spin = 28, car_gap = 15, car_face = "Direction of travel", car_tilt = 0, car_dir = "Clockwise" },
        ["Windmill"] = { car_pattern = "Line", car_radius = 35, car_height = 18, car_spread = 0, car_spin = 120, car_gap = 14, car_face = "Direction of travel", car_tilt = 0, car_dir = "Clockwise" },
        ["Car wall"] = { car_pattern = "Wall", car_radius = 35, car_height = 22, car_spread = 0, car_spin = 0, car_gap = 14, car_face = "Fixed", car_tilt = 0, car_dir = "Clockwise" },
        ["Grid carpet"] = { car_pattern = "Grid", car_radius = 35, car_height = 20, car_spread = 0, car_spin = 0, car_gap = 14, car_face = "Fixed", car_tilt = 0, car_dir = "Clockwise" },
        ["Ferris wheel"] = { car_pattern = "Wheel", car_radius = 20, car_height = 28, car_spread = 0, car_spin = 45, car_gap = 14, car_face = "Fixed", car_tilt = 90, car_dir = "Clockwise" },
        ["Sphere cage"] = { car_pattern = "Sphere", car_radius = 35, car_height = 25, car_spread = 25, car_spin = 60, car_gap = 14, car_face = "Center", car_tilt = 0, car_dir = "Clockwise" },
        ["Double helix"] = { car_pattern = "Helix", car_radius = 28, car_height = 22, car_spread = 40, car_spin = 150, car_gap = 14, car_face = "Direction of travel", car_tilt = 0, car_dir = "Clockwise" },
        ["Cube"] = { car_pattern = "Cube", car_radius = 35, car_height = 22, car_spread = 0, car_spin = 40, car_gap = 12, car_face = "Fixed", car_tilt = 0, car_dir = "Clockwise" },
        ["Galaxy"] = { car_pattern = "Spiral", car_radius = 80, car_height = 15, car_spread = 0, car_spin = 40, car_gap = 14, car_face = "Direction of travel", car_tilt = 0, car_dir = "Clockwise" },
        ["Star"] = { car_pattern = "Star", car_radius = 40, car_height = 15, car_spread = 0, car_spin = 60, car_gap = 14, car_face = "Direction of travel", car_tilt = 0, car_dir = "Clockwise" },
        ["Figure eight"] = { car_pattern = "Figure eight", car_radius = 35, car_height = 15, car_spread = 0, car_spin = 100, car_gap = 14, car_face = "Direction of travel", car_tilt = 0, car_dir = "Clockwise" },
    }
    Map.ORBIT_PRESET_NAMES = { "Tornado", "Halo", "Highway line", "Windmill", "Car wall", "Grid carpet", "Ferris wheel", "Sphere cage", "Double helix", "Cube", "Galaxy", "Star", "Figure eight" }
    Map.SPAWN_PRESETS = { ["Careful 30"] = { car_target = 30, car_delay = 0.5 }, ["Quick 20"] = { car_target = 20, car_delay = 0.25 },
        ["Swarm 60"] = { car_target = 60, car_delay = 0.15 }, ["Mega 150"] = { car_target = 150, car_delay = 0.1 } }

    function Map.applyPreset(presets, name)
        local preset = presets[name]
        if not preset then return false end
        for name_, value in pairs(preset) do Aster:Set(name_, value) end
        say("Applied preset " .. name)
        return true
    end

    local function topCar(seat)
        local folder = carFolder()
        local node = seat
        while node and node.Parent and node.Parent ~= folder do node = node.Parent end
        if node and node.Parent == folder then return node end
        return seat.Parent
    end

    local function entryFor(seat)
        for _, entry in ipairs(Cars.list) do
            if entry.seat == seat then return entry end
        end
        return nil
    end

    function Map.adopt(seat)
        if entryFor(seat) then return nil end
        local look = seat.CFrame.LookVector * FLAT
        if look.Magnitude < 0.01 then look = Vector3.new(0, 0, -1) end
        look = look.Unit
        if flag("car_flip", false) then look = -look end
        local model = topCar(seat)
        local reference
        for _, other in ipairs(Cars.list) do
            if other.ref and (other.ref.spawn.Position - seat.Position).Magnitude < 40 then reference = other.ref end
        end
        reference = reference or { spawn = seat.CFrame, forward = look }
        local entry = { seat = seat, model = model, spawn = reference.spawn, forward = reference.forward, ref = reference, drop = 3, partsAt = 0 }
        if model and model:IsA("Model") then
            local ok, pivot = pcall(function() return model:GetPivot() end)
            if ok and pivot then entry.offset = seat.CFrame:ToObjectSpace(pivot) end
            local okBox, boxCF, boxSize = pcall(function() return model:GetBoundingBox() end)
            if okBox and boxCF and boxSize then entry.drop = math.clamp(seat.Position.Y - (boxCF.Position.Y - boxSize.Y / 2), 0.5, 10) end
        end
        Cars.list[#Cars.list + 1] = entry
        return entry
    end

    local function findPads()
        local items = Workspace:FindFirstChild("Prison_ITEMS")
        local buttons = items and items:FindFirstChild("buttons")
        local pads = {}
        for _, button in ipairs(buttons and buttons:GetChildren() or {}) do
            local pad = button.Name == "Car Spawner" and button:FindFirstChild("Car Spawner")
            if pad and pad:IsA("BasePart") and (pad.Position - GARAGE).Magnitude < 90 then pads[#pads + 1] = pad end
        end
        table.sort(pads, function(a, b) return (a.Position - GARAGE).Magnitude < (b.Position - GARAGE).Magnitude end)
        return pads
    end

    local function isOwner(seat)
        if not Compat.netowner then return true end
        local ok, result = pcall(Compat.netowner, seat)
        return ok and result == true
    end

    local function refreshState()
        for index = #Cars.list, 1, -1 do
            local seat = Cars.list[index].seat
            if not (seat and seat.Parent and seat:IsDescendantOf(Workspace)) then table.remove(Cars.list, index) end
        end
        local owned = 0
        for _, entry in ipairs(Cars.list) do
            if isOwner(entry.seat) then owned = owned + 1 end
        end
        state.count, state.owned = #Cars.list, owned
    end

    local function saveParts(entry, key, filter, props, values)
        if entry[key] then return end
        local saved = {}
        local model = entry.model
        for _, part in ipairs(model and model.Parent and model:GetDescendants() or { entry.seat }) do
            if part:IsA("BasePart") and filter(part) then
                local record = { part = part }
                for index, prop in ipairs(props) do
                    record[prop] = part[prop]
                    assign(part, prop, values[index])
                end
                saved[#saved + 1] = record
            end
        end
        entry[key] = saved
        return saved
    end

    local function restoreParts(entry, key, props)
        local saved = entry[key]
        if not saved then return 0 end
        for _, record in ipairs(saved) do
            if record.part.Parent then
                for _, prop in ipairs(props) do assign(record.part, prop, record[prop]) end
            end
        end
        entry[key] = nil
        return #saved
    end

    local STRIP = { "CanCollide", "CanTouch", "CanQuery", "Massless", "Transparency" }
    local function isWheel(part)
        local name = string.lower(part.Name)
        return name:find("wheel", 1, true) ~= nil or name:find("tire", 1, true) ~= nil or name:find("tyre", 1, true) ~= nil
    end
    local function unanchored(part) return not part.Anchored end

    local function stripEntry(entry)
        local saved = saveParts(entry, "stripped", isWheel, STRIP, { false, false, false, true, 1 })
        if saved then state.stripped = state.stripped + #saved end
    end

    local function unstripEntry(entry)
        state.stripped = math.max(state.stripped - restoreParts(entry, "stripped", STRIP), 0)
    end

    local function releaseEntry(entry)
        unstripEntry(entry)
        restoreParts(entry, "ghost", { "CanCollide" })
    end

    function Map.grabNear(range)
        local folder = carFolder()
        local _, _, root = localParts()
        if not (folder and root) then return 0 end
        local added = 0
        for _, seat in ipairs(folder:GetDescendants()) do
            if seat:IsA("VehicleSeat") and seat.Occupant == nil and (seat.Position - root.Position).Magnitude < range and not entryFor(seat) and isOwner(seat) then
                if Map.adopt(seat) then added = added + 1 end
            end
        end
        refreshState()
        return added
    end

    local function reclaim()
        local _, _, root = localParts()
        if not root then return 0 end
        local pulled = 0
        for _, entry in ipairs(Cars.list) do
            local seat = entry.seat
            if seat.Occupant == nil and not isOwner(seat) then
                seat.CFrame = root.CFrame * CFrame.new(0, 3, -10)
                seat.AssemblyLinearVelocity = ZERO
                pulled = pulled + 1
            end
        end
        return pulled
    end

    function Map.releaseCars(quiet)
        for _, entry in ipairs(Cars.list) do releaseEntry(entry) end
        Cars.list = {}
        state.count, state.owned = 0, 0
        if not quiet then say("Released all cars") end
    end

    function Map.grabCars()
        local _, _, root = localParts()
        if not (carFolder() and root) then return say("No cars found") end
        local added = Map.grabNear(flag("car_grab_range", 250))
        say(string.format("Grabbed %d cars, you now have %d", added, state.count))
    end

    function Map.regrab(quiet)
        local added = Map.grabNear(flag("car_grab_range", 250))
        local pulled = reclaim()
        state.regrabs = state.regrabs + added + pulled
        refreshState()
        if not quiet then say(string.format("Regrab: %d new, %d pulled back, %d total", added, pulled, state.count)) end
    end

    local function rotY(vector, a)
        local c, s = math.cos(a), math.sin(a)
        return Vector3.new(vector.X * c + vector.Z * s, vector.Y, -vector.X * s + vector.Z * c)
    end

    function Map.pattern(i, n, a, flatOnly)
        local pattern = flag("car_pattern", "Ring")
        local radius, height, spread, gap = flag("car_radius", 35), flag("car_height", 12), flag("car_spread", 0), flag("car_gap", 14)
        local frac = (i - 0.5) / n
        local phase = a + (i - 1) * (TAU / n)
        if pattern == "Line" then
            return rotY(Vector3.new((i - (n + 1) / 2) * gap, height, 0), a)
        elseif pattern == "Grid" or pattern == "Wall" then
            local cols = math.max(math.ceil(math.sqrt(pattern == "Wall" and n * 1.8 or n)), 1)
            local rows = math.ceil(n / cols)
            local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
            if pattern == "Wall" then return rotY(Vector3.new((col - (cols - 1) / 2) * gap, height + ((rows - 1) / 2 - row) * gap * 0.6, 0), a) end
            return rotY(Vector3.new((col - (cols - 1) / 2) * gap, height, (row - (rows - 1) / 2) * gap), a)
        elseif pattern == "Cube" then
            local side = math.max(math.ceil(n ^ (1 / 3) - 1e-6), 1)
            local lx, ly, lz = (i - 1) % side, math.floor((i - 1) / side) % side, math.floor((i - 1) / (side * side))
            local mid = (side - 1) / 2
            return rotY(Vector3.new((lx - mid) * gap, height + (ly - mid) * gap * 0.6, (lz - mid) * gap), a)
        elseif pattern == "Spiral" then
            local r, p = radius * (0.1 + 0.9 * frac), a + frac * math.pi * 4
            return Vector3.new(math.cos(p) * r, height, math.sin(p) * r)
        elseif pattern == "Star" then
            local spot = ((i - 1) / n) * 10
            local k = math.floor(spot)
            local function vertex(index)
                local ang = (index % 10) * math.pi / 5
                local rr = index % 2 == 0 and radius or radius * 0.45
                return Vector3.new(math.sin(ang) * rr, 0, math.cos(ang) * rr)
            end
            local point = vertex(k):Lerp(vertex(k + 1), spot - k)
            return rotY(Vector3.new(point.X, height, point.Z), a)
        elseif pattern == "Figure eight" then
            local d = 1 + math.sin(phase) ^ 2
            return Vector3.new(math.cos(phase) * radius * 1.4 / d, height, math.sin(phase) * math.cos(phase) * radius * 1.4 / d)
        elseif pattern == "Double ring" then
            if i % 2 == 0 then return Vector3.new(math.cos(-phase) * radius * 0.6, height + spread * 0.25, math.sin(-phase) * radius * 0.6) end
        elseif pattern == "Helix" then
            return Vector3.new(math.cos(phase) * radius, height + (frac - 0.5) * spread, math.sin(phase) * radius)
        elseif pattern == "Tornado" then
            local r, p = radius * (0.25 + 0.75 * frac), a + frac * math.pi * 6
            return Vector3.new(math.cos(p) * r, height + frac * spread, math.sin(p) * r)
        elseif pattern == "Sphere" then
            local y = 1 - 2 * frac
            local ring = math.sqrt(math.max(1 - y * y, 0))
            local p = a + (i - 1) * 2.399963
            return Vector3.new(math.cos(p) * ring * radius, height + y * (spread > 0 and spread or radius), math.sin(p) * ring * radius)
        elseif pattern == "Wheel" then
            local cam = Game.camera()
            local right = Vector3.new(1, 0, 0)
            if cam and not flatOnly then
                right = cam.CFrame.RightVector * FLAT
                right = right.Magnitude > 0.01 and right.Unit or Vector3.new(1, 0, 0)
            end
            return right * math.cos(phase) * radius + Vector3.new(0, height + math.sin(phase) * radius, 0)
        end
        return Vector3.new(math.cos(phase) * radius, height, math.sin(phase) * radius)
    end

    local function worldBodies(extra)
        local ignore = { extra }
        local folder = carFolder()
        if folder then ignore[#ignore + 1] = folder end
        for _, player in ipairs(Players:GetPlayers()) do
            if player.Character then ignore[#ignore + 1] = player.Character end
        end
        return ignore
    end

    local function groundAt(position, at)
        local ground = Cars.ground
        if ground.y and ground.around and at - ground.at < 0.4 and (ground.around - position).Magnitude < 6 then return ground.y end
        local hit = Workspace:Raycast(Vector3.new(position.X, position.Y + 300, position.Z), Vector3.new(0, -900, 0), Game.newParams(worldBodies(nil)))
        ground.at, ground.around, ground.y = at, position, hit and hit.Position.Y or nil
        return ground.y
    end

    local function orbitCenter(dt, root)
        local target
        local follow = flag("car_follow", "Self")
        if follow == "Selected player" then
            local player = Map.selectedPlayer()
            local character = player and player.Character
            local part = character and character:FindFirstChild("HumanoidRootPart")
            target = part and part.Position
        elseif follow == "Silent aim target" then
            local ok, part = pcall(function() return Combat and Combat.silentTarget and Combat.silentTarget() end)
            target = ok and part and part.Parent and part.Position or nil
        elseif follow == "Cursor" then
            local cam = Game.camera()
            pcall(function()
                local ref = UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter and cam.ViewportSize / 2 or UserInputService:GetMouseLocation()
                local ray = cam:ViewportPointToRay(ref.X, ref.Y)
                local hit = Workspace:Raycast(ray.Origin, ray.Direction * 2000, Game.newParams(worldBodies(cam)))
                target = hit and hit.Position or (ray.Origin + ray.Direction * 150)
            end)
        end
        if not target then
            local ok, real = pcall(function() return Combat and Combat.sp and Combat.sp.realPos and Combat.sp.realPos(root) end)
            target = ok and typeof(real) == "Vector3" and real or root.Position
        end
        if not Cars.center then
            Cars.center = target
        else
            Cars.center = Cars.center:Lerp(target, 1 - math.exp(-flag("car_smooth", 12) * dt))
        end
        return Cars.center
    end

    local function orbitCFrame(i, n, middle, at)
        local dir = flag("car_dir", "Clockwise") == "Clockwise" and 1 or -1
        local position = middle + Map.pattern(i, n, Cars.angle, false)
        local void = Workspace.FallenPartsDestroyHeight
        if type(void) ~= "number" or void ~= void then void = -500 end
        local top = math.huge
        if flag("car_cap", true) then
            top = flag("car_cap_y", 165)
            local floorY = groundAt(middle, at)
            if floorY then top = math.min(top, floorY + 48.5) end
        end
        position = Vector3.new(position.X, math.clamp(position.Y, void + 15, math.max(top, void + 16)), position.Z)
        local face = flag("car_face", "Direction of travel")
        local cf
        if face == "Center" then
            cf = CFrame.lookAt(position, Vector3.new(middle.X, position.Y, middle.Z) + Vector3.new(0, 0.001, 0))
        elseif face == "Fixed" then
            cf = CFrame.new(position)
        else
            local ahead = middle + Map.pattern(i, n, Cars.angle + dir * 0.05, false) - position
            cf = ahead.Magnitude > 1e-3 and CFrame.lookAt(position, position + ahead) or CFrame.new(position)
        end
        local tilt = flag("car_tilt", 0)
        if tilt ~= 0 then cf = cf * CFrame.Angles(0, 0, math.rad(tilt)) end
        return cf
    end

    local function parkCFrame(entry, k)
        local forward = entry.forward
        local right = forward:Cross(Vector3.new(0, 1, 0))
        right = right.Magnitude > 0.01 and right.Unit or Vector3.new(1, 0, 0)
        local lane, row, tier = k % 5, math.floor(k / 5) % 4, math.floor(k / 20)
        local spot = entry.spawn.Position + forward * (flag("car_forward", 25) + row * 22) + right * ((lane - 2) * 12)
        local lift = tier * 10
        if flag("car_cap", true) then lift = math.min(lift, math.max(flag("car_cap_y", 165) - spot.Y, 0)) end
        local key = math.floor(spot.X) .. "|" .. math.floor(spot.Z)
        if entry.groundKey ~= key then
            entry.groundKey = key
            local hit = Workspace:Raycast(Vector3.new(spot.X, entry.spawn.Position.Y + 25, spot.Z), Vector3.new(0, -400, 0), Game.newParams({ Game.camera(), carFolder(), LocalPlayer.Character }))
            entry.ground = hit and hit.Position.Y or entry.spawn.Position.Y - entry.drop
        end
        local position = Vector3.new(spot.X, entry.ground + entry.drop + 0.4 + lift, spot.Z)
        return CFrame.lookAt(position, position + forward)
    end

    local function carParts(entry, at)
        if entry.parts and at - entry.partsAt < 1 then return entry.parts end
        local parts = {}
        local model = entry.model
        for _, part in ipairs(model and model.Parent and model:GetDescendants() or {}) do
            if part:IsA("BasePart") and not part.Anchored and #parts < 60 then parts[#parts + 1] = part end
        end
        if #parts == 0 then parts[1] = entry.seat end
        entry.parts, entry.partsAt = parts, at
        return parts
    end

    local function pivot(entry, cf)
        local model = entry.model
        if entry.offset and model and model.Parent and model:IsA("Model") then
            if not pcall(function() model:PivotTo(cf * entry.offset) end) then entry.seat.CFrame = cf end
        else
            entry.seat.CFrame = cf
        end
    end

    local function placeEntry(entry, cf, velocity, at)
        entry.goal, entry.goalVelocity = cf, velocity or ZERO
        pivot(entry, cf)
        for _, part in ipairs(carParts(entry, at)) do
            part.AssemblyLinearVelocity = entry.goalVelocity
            part.AssemblyAngularVelocity = ZERO
        end
    end

    function Map.carEngine(dt, at)
        local orbiting, frozen = flag("car_orbit_on", false), flag("car_freeze", false)
        if not (orbiting or state.spawning or frozen) then return end
        refreshState()
        local count = #Cars.list
        local _, _, root = localParts()
        if count == 0 or not root then return end
        dt = math.min(dt, 0.1)
        if frozen then
            for _, entry in ipairs(Cars.list) do
                if entry.seat.Occupant == nil then
                    entry.frozen = entry.frozen or entry.seat.CFrame
                    placeEntry(entry, entry.frozen, ZERO, at)
                end
            end
            return
        end
        local middle
        if orbiting then
            local spin = math.rad(flag("car_spin", 90))
            if flag("car_dir", "Clockwise") ~= "Clockwise" then spin = -spin end
            Cars.angle = (Cars.angle + spin * dt) % TAU
            middle = orbitCenter(dt, root)
        else
            Cars.center = nil
        end
        for index, entry in ipairs(Cars.list) do
            if entry.seat.Occupant == nil then
                if not orbiting then saveParts(entry, "ghost", unanchored, { "CanCollide" }, { false }) end
                local goal = orbiting and orbitCFrame(index, count, middle, at) or parkCFrame(entry, index - 1)
                local velocity = ZERO
                if orbiting and entry.lastGoal and dt > 0 then
                    velocity = (goal.Position - entry.lastGoal.Position) / dt
                    if velocity.Magnitude > 150 then velocity = velocity.Unit * 150 end
                end
                entry.lastGoal = goal
                placeEntry(entry, goal, velocity, at)
            end
        end
    end

    local function spawnFinish(text)
        local spawn = Cars.spawn
        Cars.spawn = nil
        if not spawn then return end
        if spawn.watch then pcall(function() spawn.watch:Disconnect() end) end
        state.spawning = false
        if text then
            state.status = text
            say(text)
        end
        if spawn.mode ~= "Stay where I am" and flag("car_return", true) and spawn.home then
            local _, _, root = localParts()
            if root then root.CFrame = spawn.home end
        end
        switchOff("car_spawn_on")
    end

    function Map.spawnStart()
        local pads = findPads()
        local interact = Game.remote("Remotes.InteractWithItem")
        state.spawning, state.detail = true, ""
        if #pads == 0 or not interact then
            Cars.spawn = {}
            return spawnFinish(#pads == 0 and "Police garage spawners not found" or "InteractWithItem remote not found")
        end
        local use = flag("car_both", true) and { pads[1], pads[2] } or { pads[1] }
        local _, _, root = localParts()
        local stand = use[2] and (use[1].Position + use[2].Position) / 2 or use[1].Position
        local spawn = { pads = pads, use = use, remote = interact, home = root and root.CFrame, stand = stand + Vector3.new(0, 4, 0), spot = use[1].Position + LIFT,
            mode = flag("car_stand", "Next to spawner"), pending = {}, refused = 0, idle = 0, lastCount = #Cars.list, nextAt = 0, pressed = false }
        local folder = carFolder()
        if folder then spawn.watch = folder.ChildAdded:Connect(function(child) spawn.pending[child] = now() + 2 end) end
        if spawn.mode == "Next to spawner" and root then
            root.CFrame = CFrame.new(spawn.spot)
            root.AssemblyLinearVelocity = ZERO
        end
        state.status = "Spawning"
        Cars.spawn = spawn
    end

    local function spawnTick(at)
        local spawn = Cars.spawn
        for child, deadline in pairs(spawn.pending) do
            local seat = child:FindFirstChildWhichIsA("VehicleSeat", true)
            if seat then
                spawn.pending[child] = nil
                for _, pad in ipairs(spawn.pads) do
                    if (seat.Position - pad.Position).Magnitude < 80 then
                        if Map.adopt(seat) then state.detail = "Last car: " .. child.Name end
                        break
                    end
                end
            elseif at > deadline or not child.Parent then
                spawn.pending[child] = nil
            end
        end
        local _, _, root = localParts()
        if root and spawn.mode == "Pinned on spawner" then
            root.CFrame = CFrame.new(spawn.stand)
            root.AssemblyLinearVelocity = ZERO
        elseif root and spawn.mode == "Next to spawner" then
            local nearest = math.huge
            for _, pad in ipairs(spawn.use) do nearest = math.min(nearest, (pad.Position - root.Position).Magnitude) end
            if nearest > 12 then
                root.CFrame = CFrame.new(spawn.spot)
                root.AssemblyLinearVelocity = ZERO
            end
        end
        if at < spawn.nextAt then return end
        if spawn.pressed then
            if #Cars.list > spawn.lastCount then
                spawn.lastCount, spawn.refused, spawn.idle = #Cars.list, 0, 0
            else
                spawn.idle = spawn.idle + 1
            end
            if spawn.refused >= 8 then return spawnFinish("The spawner refused, you may be on the wrong team") end
            if spawn.idle >= 24 then return spawnFinish("No new cars appear, the spawn spot may be blocked") end
        end
        refreshState()
        if state.count >= math.floor(flag("car_target", 20)) then
            state.status = string.format("Done, %d cars", state.count)
            return spawnFinish(nil)
        end
        for _, pad in ipairs(spawn.use) do
            task.spawn(function()
                local ok, result = pcall(function() return spawn.remote:InvokeServer(pad) end)
                if ok and result == false then spawn.refused = spawn.refused + 1 end
            end)
        end
        spawn.pressed, spawn.nextAt = true, at + math.max(flag("car_delay", 0.25), 0.05)
    end

    function Map.carBeat(dt, at)
        if flag("car_dual", true) then
            for _, entry in ipairs(Cars.list) do
                local seat = entry.seat
                if entry.goal and seat.Parent and seat.Occupant == nil then
                    pivot(entry, entry.goal)
                    seat.AssemblyLinearVelocity = entry.goalVelocity or ZERO
                    seat.AssemblyAngularVelocity = ZERO
                end
            end
        end
        if flag("car_regrab", false) and at >= Cars.nextRegrab then
            Cars.nextRegrab = at + math.max(flag("car_regrab_cd", 2), 0.25)
            Map.regrab(true)
        end
        if Cars.spawn then spawnTick(at) end
        if flag("car_strip", false) and at >= Cars.nextStrip then
            Cars.nextStrip = at + 0.5
            for _, entry in ipairs(Cars.list) do
                if entry.model and entry.model.Parent then stripEntry(entry) end
            end
        end
        if at >= Cars.nextState then
            Cars.nextState = at + 0.25
            refreshState()
            if Map.carLabel then pcall(function() Map.carLabel:Set(string.format("%s - %d cars (%d owned) %s", state.status, state.count, state.owned, state.detail)) end) end
        end
    end

    -- the engine runs while any of these is on; it raises the simulation radius like dev so far cars stay owned
    local ENGINE_FLAGS = { "car_orbit_on", "car_spawn_on", "car_regrab", "car_freeze", "car_strip" }
    local function simulationRadius(on)
        local get, set = gethiddenproperty, sethiddenproperty
        if type(get) ~= "function" or type(set) ~= "function" then return end
        if on and not Cars.radius then
            Cars.radius = {}
            for _, name in ipairs({ "SimulationRadius", "MaximumSimulationRadius" }) do
                local ok, value = pcall(get, LocalPlayer, name)
                if ok and type(value) == "number" then
                    Cars.radius[name] = value
                    pcall(set, LocalPlayer, name, 1e9)
                end
            end
        elseif not on and Cars.radius then
            for name, value in pairs(Cars.radius) do pcall(set, LocalPlayer, name, value) end
            Cars.radius = nil
        end
    end

    function Map.carSync()
        local engine = flag("car_orbit_on", false) or flag("car_spawn_on", false) or flag("car_regrab", false) or flag("car_freeze", false)
        if engine or flag("car_strip", false) then
            if not Loop.has("map_cars_beat") then Loop.register("map_cars_beat", Map.carBeat, 86, "heartbeat") end
        else
            Loop.unregister("map_cars_beat")
        end
        if engine then
            if not Loop.has("map_cars") then Loop.register("map_cars", Map.carEngine, 86) end
        elseif Loop.has("map_cars") then
            Loop.unregister("map_cars")
            Cars.center = nil
        end
        simulationRadius(engine)
    end
    Util.changed(ENGINE_FLAGS, Map.carSync)
    Util.changed("car_spawn_on", function(_, on)
        if on and not Cars.spawn then return Map.spawnStart() end
        if not on and Cars.spawn then
            local spawn = Cars.spawn
            Cars.spawn = nil
            if spawn.watch then pcall(function() spawn.watch:Disconnect() end) end
            state.spawning = false
            if state.status == "Spawning" then state.status = "Stopped" end
        end
    end)
    Util.changed("car_freeze", function(_, on)
        for _, entry in ipairs(Cars.list) do entry.frozen = nil end
        if on then
            state.status = "Frozen in place"
        elseif state.status == "Frozen in place" then
            state.status = flag("car_orbit_on", false) and "Orbiting" or "Idle"
        end
    end)
    Util.changed("car_strip", function(_, on)
        if on then return end
        for _, entry in ipairs(Cars.list) do unstripEntry(entry) end
    end)
    Util.changed("car_orbit_on", function(_, on)
        if on then
            Cars.angle, Cars.center = 0, nil
            if not state.spawning then state.status = "Orbiting" end
        elseif not state.spawning and state.status == "Orbiting" then
            state.status = "Idle"
        end
    end)

    -- server hop / rejoin (dev: roproxy then roblox, 3 pages each, one pick)
    local function teleportService()
        local ok, service = pcall(function() return game:GetService("TeleportService") end)
        return ok and service or nil
    end

    function Map.servers()
        local minimum = flag("srv_hop_min", 0)
        for _, host in ipairs({ "games.roproxy.com", "games.roblox.com" }) do
            local found, cursor = {}, nil
            for _ = 1, 3 do
                local url = string.format("https://%s/v1/games/%d/servers/Public?sortOrder=Asc&excludeFullGames=true&limit=100%s", host, game.PlaceId, cursor and ("&cursor=" .. cursor) or "")
                local body
                if Compat.request then
                    local ok, reply = pcall(Compat.request, { Url = url, Method = "GET" })
                    if ok and type(reply) == "table" and reply.StatusCode == 200 and type(reply.Body) == "string" then body = reply.Body end
                else
                    local ok, reply = pcall(function() return game:HttpGet(url) end)
                    if ok and type(reply) == "string" then body = reply end
                end
                if not body then break end
                local okJson, data = pcall(function() return HttpService:JSONDecode(body) end)
                if not (okJson and type(data) == "table" and type(data.data) == "table") then break end
                for _, server in ipairs(data.data) do
                    if type(server) == "table" and server.id and server.id ~= game.JobId and type(server.playing) == "number" and type(server.maxPlayers) == "number"
                        and server.playing < server.maxPlayers and server.playing >= minimum then
                        found[#found + 1] = server
                    end
                end
                cursor = type(data.nextPageCursor) == "string" and data.nextPageCursor or nil
                if not cursor then break end
            end
            if #found > 0 then return found end
        end
        return {}
    end

    function Map.hop()
        if Map.hopping then return end
        local service = teleportService()
        if not service then return say("TeleportService unavailable") end
        Map.hopping = true
        say("Looking for a server...")
        task.spawn(function()
            local servers = Map.servers()
            if #servers == 0 then
                Map.hopping = false
                return say("No other server found. Try lowering the minimum players")
            end
            local mode = flag("srv_hop_mode", "Random")
            if mode == "Fewest players" then
                table.sort(servers, function(a, b) return a.playing < b.playing end)
            elseif mode == "Most players" then
                table.sort(servers, function(a, b) return a.playing > b.playing end)
            end
            local pick = mode == "Random" and servers[math.random(1, #servers)] or servers[1]
            say(string.format("Joining a server with %d/%d players", pick.playing, pick.maxPlayers))
            local ok, problem = pcall(function() service:TeleportToPlaceInstance(game.PlaceId, pick.id, LocalPlayer) end)
            if not ok then
                Map.hopping = false
                say("Teleport failed: " .. tostring(problem))
            end
        end)
    end

    function Map.rejoin()
        if Map.hopping then return end
        local service = teleportService()
        if not service then return say("TeleportService unavailable") end
        Map.hopping = true
        say("Rejoining...")
        local ok, problem = pcall(function()
            if #Players:GetPlayers() <= 1 then
                service:Teleport(game.PlaceId, LocalPlayer)
            else
                service:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
            end
        end)
        if not ok then
            Map.hopping = false
            say("Rejoin failed: " .. tostring(problem))
        end
    end

    pcall(function()
        Util.track(teleportService().TeleportInitFailed:Connect(function(_, result, message)
            Map.hopping = false
            say("Teleport failed: " .. tostring(message ~= "" and message or result))
        end))
    end)

    local function buildKeycard()
        local tools = ReplicatedStorage:FindFirstChild("Tools")
        local template = tools and tools:FindFirstChild(Map.KEYCARD)
        if template and template:IsA("Tool") then
            local ok, card = pcall(function() return template:Clone() end)
            if ok and card then return card end
        end
        local card = Instance.new("Tool")
        card.RequiresHandle = true
        card.CanBeDropped = false
        local handle = Instance.new("Part")
        handle.Name = "Handle"
        handle.Size = Vector3.new(0.2, 0.8, 1.2)
        handle.CanCollide = false
        handle.Massless = true
        handle.Parent = card
        return card
    end

    function Map.giveKeycard(quiet)
        local pack = LocalPlayer:FindFirstChildOfClass("Backpack")
        if not pack then
            if not quiet then say("Backpack not found, wait for your character") end
            return nil
        end
        if Map.findTool(Map.KEYCARD) then
            if not quiet then say("You already have a key card") end
            return nil
        end
        local card = buildKeycard()
        card.Name = Map.KEYCARD
        card.Parent = pack
        Map.cards[#Map.cards + 1] = card
        if not quiet then say("Key card added on your side only; hold it and walk into a door") end
        return card
    end

    function Map.dropKeycards()
        for _, card in ipairs(Map.cards) do pcall(function() card:Destroy() end) end
        Map.cards = {}
    end

    function Map.keyStep(at)
        if at < Map.keyAt or not flag("tp_key_keep", false) then return end
        Map.keyAt = at + 0.5
        local kept = {}
        for _, card in ipairs(Map.cards) do
            if card.Parent then kept[#kept + 1] = card end
        end
        Map.cards = kept
        local _, humanoid = localParts()
        if humanoid and humanoid.Health > 0 and not Map.findTool(Map.KEYCARD) then Map.giveKeycard(true) end
    end

    function Map.foodTool()
        local character = Game.localCharacter()
        local pack = LocalPlayer:FindFirstChildOfClass("Backpack")
        for _, holder in ipairs({ character or false, pack or false }) do
            for _, tool in ipairs(holder and holder:GetChildren() or {}) do
                if tool:IsA("Tool") and Map.FOODS[tool.Name] then
                    local left = tool:GetAttribute("Quantity")
                    if left == nil or left > 0 then return tool end
                end
            end
        end
        return nil
    end

    function Map.eat()
        local remote = Game.remote("Remotes.EatFood")
        if not remote then return false end
        task.spawn(function() pcall(function() remote:FireServer() end) end)
        return true
    end

    function Map.foodStep(at)
        local food = Map.food
        local character, humanoid = localParts()
        if not flag("food_auto", false) or not humanoid or humanoid.Health <= 0 then
            food.phase = nil
            return
        end
        if food.phase == "equip" then
            if food.tool.Parent ~= character then
                if at > food.at + 1 then food.phase, food.nextAt = nil, at + 1 end
                return
            end
            if at < food.at then return end
            Map.eat()
            food.phase, food.at, food.nextAt = "back", at + 0.5, at + 3.2
            return
        end
        if food.phase == "back" then
            if at < food.at then return end
            food.phase = nil
            local prev = food.prev
            if prev and prev.Parent and prev.Parent ~= character and food.tool.Parent == character then
                pcall(function() humanoid:EquipTool(prev) end)
            end
            return
        end
        local most = humanoid.MaxHealth > 0 and humanoid.MaxHealth or 100
        if at < food.nextAt or humanoid.Health / most * 100 >= flag("food_health", 50) then return end
        local tool = Map.foodTool()
        if not tool then
            if at >= food.warnAt then
                food.warnAt = at + 15
                say("Auto eat: no food left, use Get food")
            end
            return
        end
        local held = character:FindFirstChildOfClass("Tool")
        food.tool, food.prev, food.phase, food.at = tool, held ~= tool and held or nil, "equip", at + 0.15
        if tool.Parent ~= character then pcall(function() humanoid:EquipTool(tool) end) end
    end

    function Map.itemsStep(dt, at)
        Map.keyStep(at)
        Map.foodStep(at)
    end

    local DOOR_OPEN = { "Exploded", "ScheduledOpen", "PlayerOpened", "LocalPlayerOpened" }

    local function doorOpen(model)
        for _, key in ipairs(DOOR_OPEN) do
            if model:GetAttribute(key) then return true end
        end
        return false
    end

    local function addDoor(found, model, cell)
        if found[model] then return end
        local entry = Map.doorIndex[model]
        local block = cell and model or model:FindFirstChild("block") or (entry and entry.block)
        if not block then return end
        if not entry then
            entry = { model = model, cell = cell, held = false, forced = false, ghost = false, collide = {} }
            Map.doorIndex[model] = entry
        end
        local parts = {}
        for _, object in ipairs(block:GetDescendants()) do
            if object:IsA("BasePart") then parts[#parts + 1] = object end
        end
        local anchor = block:FindFirstChild("hitbox") or parts[1]
        entry.block, entry.parts, entry.ghost = block, parts, nil
        if anchor then entry.pos = anchor.Position end
        if not cell then Map.doorBlocks[block] = true end
        found[model] = entry
    end

    function Map.doorSettle(entry)
        if entry.cell or not entry.block then return end
        local wantParent = not doorOpen(entry.model) and entry.model or nil
        if entry.block.Parent ~= wantParent then pcall(function() entry.block.Parent = wantParent end) end
    end

    function Map.doorHold(entry)
        if entry.cell or not entry.block then return end
        local model = entry.model
        if not entry.held then entry.held, entry.saved = true, model:GetAttribute("LocalPlayerOpened") end
        if model:GetAttribute("LocalPlayerOpened") ~= true then pcall(function() model:SetAttribute("LocalPlayerOpened", true) end) end
        if entry.block.Parent ~= nil then pcall(function() entry.block.Parent = nil end) end
    end

    function Map.doorRelease(entry)
        if not entry.held then return end
        entry.held = false
        pcall(function() entry.model:SetAttribute("LocalPlayerOpened", entry.saved) end)
        entry.saved = nil
        Map.doorSettle(entry)
    end

    function Map.doorClose(entry)
        Map.doorRelease(entry)
        if entry.cell or not entry.block or entry.block.Parent == entry.model then return end
        entry.forced = true
        pcall(function() entry.block.Parent = entry.model end)
    end

    function Map.doorGhost(entry, on)
        if entry.ghost == on then return end
        entry.ghost = on
        if on then
            for _, part in ipairs(entry.parts) do
                if entry.collide[part] == nil then entry.collide[part] = part.CanCollide end
                assign(part, "CanCollide", false)
            end
            return
        end
        for part, collide in pairs(entry.collide) do assign(part, "CanCollide", collide) end
        entry.collide = {}
    end

    function Map.doorRestore(entry)
        Map.doorRelease(entry)
        if entry.forced then
            entry.forced = false
            Map.doorSettle(entry)
        end
        Map.doorGhost(entry, false)
    end

    function Map.scanDoors()
        local found, doors = {}, {}
        if CollectionService then
            local ok, tagged = pcall(function() return CollectionService:GetTagged("Door") end)
            for _, model in ipairs(ok and type(tagged) == "table" and tagged or {}) do addDoor(found, model, false) end
        end
        local folder = Workspace:FindFirstChild("Doors")
        for _, model in ipairs(folder and folder:GetChildren() or {}) do
            if model:IsA("Model") then addDoor(found, model, false) end
        end
        local cells = Workspace:FindFirstChild("CellDoors")
        for _, model in ipairs(cells and cells:GetChildren() or {}) do
            if model:IsA("Model") then addDoor(found, model, true) end
        end
        for model, entry in pairs(Map.doorIndex) do
            if not found[model] then
                Map.doorRestore(entry)
                Map.doorIndex[model] = nil
                Map.doorBlocks[entry.block] = nil
            end
        end
        for _, entry in pairs(found) do doors[#doors + 1] = entry end
        Map.doors, Map.doorsDirty = doors, false
        return doors
    end

    function Map.doorStep(dt, at)
        local auto, ghost = flag("door_auto", false), flag("door_nocollide", false)
        if not (Map.doorsAll or auto or ghost or Map.doorsLive) then return Loop.unregister("map_doors") end
        if Map.doorsDirty and at >= Map.doorScanAt then
            Map.doorScanAt = at + 0.5
            Map.scanDoors()
        end
        if at < Map.doorTickAt then return end
        Map.doorTickAt = at + 0.1
        local root = Game.rootPart()
        local range = flag("door_range", 12)
        local live = false
        for _, entry in ipairs(Map.doors) do
            if entry.model.Parent then
                if not entry.cell then
                    local near = auto and root and entry.pos and (entry.pos - root.Position).Magnitude <= range
                    if Map.doorsAll or near then Map.doorHold(entry) elseif entry.held then Map.doorRelease(entry) end
                end
                Map.doorGhost(entry, ghost)
                live = live or entry.held or entry.ghost == true
            else
                Map.doorsDirty = true
            end
        end
        Map.doorsLive = live
    end

    local function doorsOn()
        if not Loop.has("map_doors") then Loop.register("map_doors", Map.doorStep, 87) end
    end

    function Map.openDoors()
        Map.doorsAll, Map.doorTickAt = true, 0
        doorsOn()
        Map.doorStep(0, now())
        say("Opened " .. #Map.doors .. " doors on your screen")
    end

    function Map.closeDoors()
        Map.doorsAll = false
        if Map.doorsDirty then Map.scanDoors() end
        for _, entry in ipairs(Map.doors) do Map.doorClose(entry) end
        Map.doorTickAt = 0
        say("Closed the doors on your screen")
    end

    function Map.restoreDoors()
        Map.doorsAll, Map.doorsLive = false, false
        for _, entry in pairs(Map.doorIndex) do Map.doorRestore(entry) end
    end

    Util.track(Workspace.DescendantAdded:Connect(function(object)
        local name = object.Name
        if (name == "block" and not Map.doorBlocks[object]) or name == "Doors" or name == "CellDoors" then Map.doorsDirty = true end
    end))
    if CollectionService then
        pcall(function()
            Util.track(CollectionService:GetInstanceAddedSignal("Door"):Connect(function() Map.doorsDirty = true end))
        end)
    end

    -- keycard / food / doors run only while one of their flags is on
    Util.changed({ "door_auto", "door_nocollide" }, function(_, value) if value then doorsOn() end end)
    local function itemsSync()
        if flag("tp_key_keep", false) or flag("food_auto", false) then
            if not Loop.has("map_items") then Loop.register("map_items", Map.itemsStep, 41) end
        else
            Loop.unregister("map_items")
            Map.food.phase = nil
        end
    end
    Util.changed({ "tp_key_keep", "food_auto" }, itemsSync)
    local function vehiclesSync()
        if flag("misc_vspeed", false) or flag("misc_vfly", false) then
            if not Loop.has("map_vehicles") then Loop.register("map_vehicles", Map.vehicleStep, 85, "heartbeat") end
        elseif Loop.has("map_vehicles") then
            Loop.unregister("map_vehicles")
            Map.vehicleRestore()
            Veh.flySeat, Veh.inCar, Veh.welds = nil, false, {}
        end
    end
    Util.changed({ "misc_vspeed", "misc_vfly" }, vehiclesSync)

    -- menu: misc > teleport / vehicles / server, plus vehicle fly + speed on movement (dev.lua rows, ranges and defaults)
    local row = Util.row
    local function unit(suffix) return function(v) return v .. suffix end end
    local studs, seconds = unit(" studs"), unit(" s")
    local tpPage, serverPage = Pages.misc.teleport, Pages.misc.server
    local spawnPage, orbitPage = Pages.misc["vehicles.spawner"], Pages.misc["vehicles.orbit"]

    local guns = tpPage:Card({ name = "get guns", id = "guns", side = "left" })
    guns:Dropdown({ name = "Weapon", flag = "tp_weapon", options = Map.GUNS, default = "AK-47" })
    guns:Buttons({ items = {
        { name = "Get weapon", primary = true, callback = function() Map.request(flag("tp_weapon", "AK-47")) end },
        { name = "Get all weapons", callback = function()
            for _, name in ipairs(Map.GUNS) do Map.request(name) end
        end },
    } })

    local settings = tpPage:Card({ name = "teleport settings", id = "tpsettings", side = "left" })
    row(settings, "Return after pickup", "tp_return", { def = true })
    settings:Slider({ name = "Time at pickup", flag = "tp_time", min = 0.6, max = 2, step = 0.1, default = 0.8, fmt = unit("s") })

    local items = tpPage:Card({ name = "get items", id = "items", side = "right" })
    items:Dropdown({ name = "Item", flag = "tp_item", options = Map.ITEMS, default = "Key card" })
    items:Button({ name = "Get item", primary = true, callback = function() Map.getItem(flag("tp_item", "Key card")) end })
    row(items, "Keep keycard", "tp_key_keep", { tip = "Adds the local key card again after you respawn. Doors only check the tool in your hand" })
    local _, g = row(items, "Auto eat", "food_auto", { key = "food_auto_key", gear = "auto eat", tip = "Equips and eats a food tray when your health drops below the threshold" })
    g:Slider({ name = "Eat below", flag = "food_health", min = 5, max = 95, step = 1, default = 50, fmt = unit("% hp") })

    local places = tpPage:Card({ name = "teleport places", id = "places", side = "right" })
    places:Dropdown({ name = "Location", flag = "tp_place", options = list(Map.PLACES), default = "Yard" })
    places:Button({ name = "Teleport", primary = true, callback = function() Map.gotoPlace(flag("tp_place", "Yard")) end })
    places:Buttons({ items = { { name = "Open all doors", callback = Map.openDoors }, { name = "Close all doors", callback = Map.closeDoors } } })
    _, g = row(places, "Auto open doors", "door_auto", { gear = "auto open doors", tip = "Opens doors near you, on your screen only" })
    g:Slider({ name = "Door range", flag = "door_range", min = 4, max = 40, step = 1, default = 12, fmt = studs })
    row(places, "Doors no-collide", "door_nocollide", { tip = "Walk through keycard doors and cell doors, on your screen only" })

    local team = tpPage:Card({ name = "team", id = "team", side = "left" })
    team:Dropdown({ name = "Team", flag = "team_pick", options = Map.TEAMS, default = "Guards" })
    team:Button({ name = "Switch team", callback = function() Map.switchTeam(flag("team_pick", "Guards")) end })

    local vehicleCard = Pages.misc.movement:Card({ name = "vehicles", id = "vehicles", side = "left" })
    _, g = row(vehicleCard, "Vehicle fly", "misc_vfly", { key = "misc_vfly_key", gear = "vehicle fly" })
    g:Slider({ name = "Speed", flag = "misc_vfly_speed", min = 1, max = 100, step = 1, default = 60, fmt = studs })
    row(g, "Move along camera", "misc_vfly_camera", { def = true })
    row(g, "Height cap (49.9)", "misc_vfly_cap")
    g:Label({ name = "Up: E   Down: Q" })
    _, g = row(vehicleCard, "Vehicle speed", "misc_vspeed", { key = "misc_vspeed_key", gear = "vehicle speed" })
    g:Slider({ name = "Max speed", flag = "misc_vspeed_value", min = 80, max = 200, step = 1, default = 140 })

    local spawner = spawnPage:Card({ name = "car spawner", id = "carspawner", side = "left" })
    spawner:Dropdown({ name = "Preset", flag = "car_spawn_preset", options = { "Careful 30", "Quick 20", "Swarm 60", "Mega 150" }, default = "Quick 20", tip = "Sets the target and the delay. Press Apply preset after picking" })
    spawner:Button({ name = "Apply preset", callback = function() Map.applyPreset(Map.SPAWN_PRESETS, flag("car_spawn_preset", "Quick 20")) end })
    row(spawner, "Spawn cars", "car_spawn_on", { tip = "Presses the police garage car spawners over and over, moves each new car forward to free the spot and counts them. Needs the team that can use the garage." })
    spawner:Slider({ name = "Target cars", flag = "car_target", min = 1, max = 200, step = 1, default = 20, fmt = unit(" cars"), tip = "Stops spawning once this many cars are yours" })
    spawner:Slider({ name = "Spawn delay", flag = "car_delay", min = 0.05, max = 2, step = 0.05, default = 0.25, fmt = seconds, tip = "Time between spawn presses" })
    spawner:Slider({ name = "Move forward", flag = "car_forward", min = 5, max = 150, step = 0.5, default = 25, fmt = studs, tip = "How far in front of the garage new cars are parked while orbit is off. With orbit on they go straight to their orbit spot" })
    row(spawner, "Reverse forward", "car_flip", { tip = "Use this if the cars get parked behind the spawn spot" })
    row(spawner, "Use both spawners", "car_both", { def = true, tip = "The police garage has two spawner pads, using both doubles the speed" })
    spawner:Dropdown({ name = "Garage position", flag = "car_stand", options = { "Next to spawner", "Pinned on spawner", "Stay where I am" }, default = "Next to spawner",
        tip = "Next to spawner: you are moved onto the pad once and can then move around freely, you are only pulled back if you get too far away. Pinned: held on the pad. Stay: no teleport, walk there yourself" })
    row(spawner, "Return afterwards", "car_return", { def = true })
    spawner:Buttons({ items = { { name = "Grab nearby cars", callback = Map.grabCars }, { name = "Release all cars", callback = function() Map.releaseCars() end } } })

    local control = spawnPage:Card({ name = "car control", id = "carcontrol", side = "right" })
    row(control, "Auto regrab", "car_regrab", { tip = "Keeps picking up free cars near you and pulls back cars the server took from you" })
    control:Slider({ name = "Regrab cooldown", flag = "car_regrab_cd", min = 0.25, max = 10, step = 0.05, default = 2, fmt = seconds })
    control:Slider({ name = "Regrab range", flag = "car_grab_range", min = 20, max = 1000, step = 0.5, default = 250, fmt = studs, tip = "How far from you cars are picked up" })
    control:Button({ name = "Regrab all", callback = function() Map.regrab() end })
    row(control, "Stronger sync", "car_dual", { def = true, tip = "Places the cars a second time every frame after physics, so other players see them where you do. Turn it off if it lags" })
    row(control, "Place mode (freeze)", "car_freeze", { tip = "Leaves every car exactly where it is right now. Turn it off to continue the orbit" })
    row(control, "Strip wheels", "car_strip", { tip = "Hides your cars' wheels and turns off their collision so they glide easier. Looks only change for you, and it is undone when you turn it off" })
    Map.carLabel = control:Label({ name = "Idle - 0 cars" })

    local orbit = orbitPage:Card({ name = "orbit", id = "carorbit", side = "left" })
    orbit:Dropdown({ name = "Preset", flag = "car_preset", options = Map.ORBIT_PRESET_NAMES, default = "Tornado", tip = "Pick a look, then press Apply preset. It sets the pattern, size, speed, facing and tilt but never the car count" })
    orbit:Button({ name = "Apply preset", callback = function() Map.applyPreset(Map.ORBIT_PRESETS, flag("car_preset", "Tornado")) end })
    row(orbit, "Orbit cars", "car_orbit_on", { tip = "Your cars circle the center you pick. Only your own cars move, and only what the server lets you own" })
    orbit:Dropdown({ name = "Follow", flag = "car_follow", options = { "Self", "Cursor", "Selected player", "Silent aim target" }, default = "Self",
        tip = "Self circles you. Cursor circles the spot your mouse points at. Selected player circles the player picked in settings > players. Silent aim target circles whoever silent aim is on. Without a target it circles you" })
    orbit:Dropdown({ name = "Pattern", flag = "car_pattern", options = { "Ring", "Double ring", "Helix", "Tornado", "Sphere", "Wheel", "Line", "Grid", "Wall", "Cube", "Spiral", "Star", "Figure eight" }, default = "Ring",
        tip = "Line, Grid, Wall and Cube use the Spacing slider and turn around the center as they spin" })
    orbit:Slider({ name = "Radius", flag = "car_radius", min = 3, max = 1000, step = 0.5, default = 35, fmt = studs })
    orbit:Slider({ name = "Height", flag = "car_height", min = -20, max = 1000, step = 0.5, default = 12, fmt = studs, tip = "Height of the orbit above the center" })
    orbit:Slider({ name = "Height spread", flag = "car_spread", min = 0, max = 1000, step = 0.5, default = 0, fmt = studs, tip = "How tall the Helix, Tornado and Sphere patterns are" })
    orbit:Slider({ name = "Spacing", flag = "car_gap", min = 3, max = 60, step = 0.05, default = 14, fmt = studs, tip = "Gap between cars in the Line, Grid, Wall and Cube patterns" })
    local look = orbitPage:Card({ name = "motion", id = "carmotion", side = "right" })
    look:Slider({ name = "Orbit speed", flag = "car_spin", min = 0, max = 720, step = 1, default = 90, fmt = unit(" deg/s") })
    look:Dropdown({ name = "Direction", flag = "car_dir", options = { "Clockwise", "Counter clockwise" }, default = "Clockwise" })
    look:Dropdown({ name = "Facing", flag = "car_face", options = { "Direction of travel", "Center", "Fixed" }, default = "Direction of travel" })
    look:Slider({ name = "Car tilt", flag = "car_tilt", min = 0, max = 180, step = 1, default = 0, fmt = unit(" deg"), tip = "Rolls every car sideways, 90 puts them on their side" })
    look:Slider({ name = "Follow smoothing", flag = "car_smooth", min = 1, max = 60, step = 1, default = 12, fmt = unit(" /s"), tip = "How quickly the orbit center catches up with you or the cursor, lower is lazier" })
    row(look, "Stay under the height cap", "car_cap", { def = true, tip = "Keeps every car below the height limit and above the void, so the orbit never reaches the kill plane" })
    look:Slider({ name = "Height cap", flag = "car_cap_y", min = 20, max = 179, step = 1, default = 165, fmt = studs, tip = "Highest point a car may reach. The kill plane is at about 180" })

    local server = serverPage:Card({ name = "server", id = "server", side = "left" })
    server:Dropdown({ name = "Server hop picks", flag = "srv_hop_mode", options = { "Random", "Fewest players", "Most players" }, default = "Random", tip = "Which public server to join. Full servers and this one are skipped" })
    server:Slider({ name = "Minimum players", flag = "srv_hop_min", min = 0, max = 40, step = 1, default = 0, tip = "Skips servers with fewer players than this" })
    server:Buttons({ items = { { name = "Server hop", primary = true, callback = Map.hop }, { name = "Rejoin", callback = Map.rejoin } } })
    server:Label({ name = "Aster is not loaded again after joining, run it again" })

    if Combat then
        Combat.selectedPlayer, Combat.getWeapon, Combat.gettingWeapon = Map.selectedPlayer, Map.getWeapon, Map.gettingWeapon
    end
    itemsSync()
    vehiclesSync()
    Map.carSync()

    Util.onUnload(function()
        Map.queue = {}
        Map.finish(false, true)
        Map.vehicleRestore()
        Cars.spawn = nil
        Map.releaseCars(true)
        simulationRadius(false)
        Map.restoreDoors()
        Map.dropKeycards()
        Map.food.phase = nil
        Map.carLabel = nil
        if Combat and Combat.selectedPlayer == Map.selectedPlayer then
            Combat.selectedPlayer, Combat.getWeapon, Combat.gettingWeapon = nil, nil, nil
        end
    end)
end
bootMark("map", PL2BootT, 11, 13)

PL2BootT = PL2BootClock()
-- [src] 80_avatar.lua
do
    local okEditor, AvatarEditorService = pcall(function() return game:GetService("AvatarEditorService") end)
    if not okEditor then AvatarEditorService = nil end
    local Scene = Aster.Scene

    Avatar = { busy = false, wornKeys = {}, wornSet = {}, dynamicHeads = {}, headDynamic = false, listeners = {}, store = { recent = {}, favorites = {}, outfits = {} } }
    local Builder = { rig = "R6", desc = nil, stamp = 0 }
    Avatar.Builder = Builder
    local store = Avatar.store

    local HEADLESS_IDS = { [15093053680] = true, [134082579] = true, [4562128874] = true }
    local KORBLOX_LEFT, KORBLOX_RIGHT = 139607673, 139607718
    local ROOT = "AsterV2/games/" .. FOLDER
    local STORE_PATH = ROOT .. "/spoofer.json"
    local LOOK = { "Accessory", "Shirt", "Pants", "ShirtGraphic", "CharacterMesh", "BodyColors", "Clothing" }
    local LIMBS = { "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }

    local function notify(text, kind) Util.notify(text, kind) end

    local function localHumanoid()
        local char = LocalPlayer.Character
        return char, char and char:FindFirstChildOfClass("Humanoid")
    end
    local function isR6(humanoid) return humanoid.RigType == Enum.HumanoidRigType.R6 end

    local function decode(body)
        if type(body) == "table" then return body end
        if type(body) ~= "string" then return nil end
        local ok, data = pcall(function() return HttpService:JSONDecode(body) end)
        if ok and type(data) == "table" then return data end
        return nil
    end

    local function sender() return (Compat and Compat.request) or request or http_request end

    local function httpGet(url, headers)
        local send = sender()
        if send then
            local ok, reply = pcall(send, { Url = url, Method = "GET", Headers = headers })
            if ok and type(reply) == "table" and type(reply.Body) == "string" and reply.Body ~= "" then return reply.Body, tonumber(reply.StatusCode) end
            if ok and type(reply) == "table" then return nil, tonumber(reply.StatusCode) end
        end
        if headers and headers["Roblox-Place-Id"] then return nil, nil end
        local ok, body = pcall(function() return game:HttpGet(url) end)
        if ok and type(body) == "string" and body ~= "" then return body, nil end
        return nil, tonumber(string.match(tostring(body), "(%d%d%d)")), tostring(body)
    end

    local function httpPost(url, payload)
        local send = sender()
        if not send then return nil end
        local ok, reply = pcall(send, { Url = url, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = HttpService:JSONEncode(payload) })
        if ok and type(reply) == "table" and type(reply.Body) == "string" then return reply.Body end
        return nil
    end

    -- the snapshot is what reset and unload put back: clones of every look instance before the first apply on this character
    local Original
    local applyGen, watchers = 0, {}
    local function isLook(v)
        for _, c in ipairs(LOOK) do
            if v:IsA(c) then return true end
        end
        return false
    end
    local function isSkin(v) return v:IsA("SpecialMesh") or v:IsA("Decal") or v:IsA("SurfaceAppearance") end

    local function snapshot(char)
        if Original and Original.char == char then return end
        local snap = { char = char, look = {}, skin = {}, alpha = {} }
        for _, v in ipairs(char:GetChildren()) do
            if isLook(v) then pcall(function() snap.look[#snap.look + 1] = v:Clone() end) end
        end
        for _, name in ipairs(LIMBS) do
            local limb = char:FindFirstChild(name)
            if limb then
                local list = {}
                for _, d in ipairs(limb:GetChildren()) do
                    if isSkin(d) then pcall(function() list[#list + 1] = d:Clone() end) end
                end
                snap.skin[name], snap.alpha[name] = list, limb.Transparency
            end
        end
        Original = snap
    end

    local function dropWatchers()
        for _, conn in ipairs(watchers) do pcall(function() conn:Disconnect() end) end
        watchers = {}
    end

    function Avatar.restore()
        applyGen = applyGen + 1
        dropWatchers()
        local snap = Original
        Original = nil
        if not snap then return false end
        local char = snap.char
        if not (char and char.Parent and LocalPlayer.Character == char) then return false end
        for _, v in ipairs(char:GetChildren()) do
            if isLook(v) then pcall(function() v:Destroy() end) end
        end
        for name, list in pairs(snap.skin) do
            local limb = char:FindFirstChild(name)
            if limb then
                for _, d in ipairs(limb:GetChildren()) do
                    if isSkin(d) then pcall(function() d:Destroy() end) end
                end
                for _, d in ipairs(list) do pcall(function() d.Parent = limb end) end
                pcall(function() limb.Transparency = snap.alpha[name] end)
            end
        end
        for _, v in ipairs(snap.look) do pcall(function() v.Parent = char end) end
        Avatar.wornKeys, Avatar.applied = {}, nil
        return true
    end

    local function scaleAccessory(copy, factor)
        if math.abs(factor - 1) < 0.01 then return end
        for _, d in ipairs(copy:GetDescendants()) do
            if d:IsA("BasePart") then
                d.Size = d.Size * factor
            elseif d:IsA("SpecialMesh") then
                d.Scale = d.Scale * factor
            elseif d:IsA("Attachment") then
                d.CFrame = CFrame.new(d.CFrame.Position * factor) * d.CFrame.Rotation
            end
        end
    end

    local function descFactor(isHead)
        local desc = Avatar.currentDesc
        if not desc then return 1 end
        local ok, value = pcall(function()
            if isHead then return desc.HeadScale end
            return (desc.WidthScale + desc.HeightScale + desc.DepthScale) / 3
        end)
        return ok and tonumber(value) or 1
    end

    local function accessoryKey(acc)
        local handle = acc:FindFirstChild("Handle")
        local mesh, texture = "", ""
        if handle then
            pcall(function()
                local special = handle:FindFirstChildWhichIsA("SpecialMesh")
                if special then
                    mesh, texture = tostring(special.MeshId), tostring(special.TextureId)
                elseif handle:IsA("MeshPart") then
                    mesh, texture = tostring(handle.MeshId), tostring(handle.TextureID)
                end
            end)
        end
        return string.lower(acc.Name) .. "|" .. mesh .. "|" .. texture
    end

    local function dedupeAccessories(char)
        local seen = {}
        for _, child in ipairs(char:GetChildren()) do
            if child:IsA("Accessory") then
                local key = accessoryKey(child)
                if seen[key] then pcall(function() child:Destroy() end) end
                seen[key] = true
            end
        end
    end

    function Avatar.resolveUserId(input)
        if input == nil then return nil end
        local s = string.gsub(string.gsub(tostring(input), "^%s+", ""), "%s+$", "")
        if s == "" then return nil end
        local digits = string.match(s, "users/(%d+)") or string.match(s, "userId=(%d+)") or string.match(string.gsub(s, ",", ""), "^(%d+)$")
        if digits and tonumber(digits) and tonumber(digits) > 0 then return math.floor(tonumber(digits)) end
        local needle = string.gsub(s, "^@", "")
        local lower = string.lower(needle)
        for _, exact in ipairs({ true, false }) do
            for _, p in ipairs(Players:GetPlayers()) do
                local a, b = string.lower(p.Name), string.lower(p.DisplayName)
                if (exact and (a == lower or b == lower)) or (not exact and (string.sub(a, 1, #lower) == lower or string.sub(b, 1, #lower) == lower)) then return p.UserId end
            end
        end
        local ok, id = pcall(function() return Players:GetUserIdFromNameAsync(needle) end)
        if ok and type(id) == "number" and id > 0 then return math.floor(id) end
        for _, host in ipairs({ "users.roproxy.com", "users.roblox.com" }) do
            local data = decode(httpPost("https://" .. host .. "/v1/usernames/users", { usernames = { needle }, excludeBannedUsers = false }))
            local first = data and type(data.data) == "table" and data.data[1]
            if first and tonumber(first.id) then return math.floor(tonumber(first.id)) end
        end
        return nil
    end

    local function stripAppearance(char)
        for _, v in ipairs(char:GetChildren()) do
            if isLook(v) then pcall(function() v:Destroy() end) end
        end
        for _, name in ipairs({ "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }) do
            local limb = char:FindFirstChild(name)
            if limb then
                for _, d in ipairs(limb:GetChildren()) do
                    if d:IsA("SpecialMesh") then pcall(function() d:Destroy() end) end
                end
                limb.Transparency = 0
            end
        end
    end

    local function wearAccessory(char, acc, fromAsset)
        if not (char and acc and acc:IsA("Accessory")) then return false end
        local key = accessoryKey(acc)
        if Avatar.wornKeys[key] then return false end
        pcall(function()
            local copy = acc:Clone()
            for _, part in ipairs(copy:GetDescendants()) do
                if part:IsA("BasePart") then part.Anchored, part.CanCollide, part.Massless = false, false, true end
            end
            local handle = copy:FindFirstChild("Handle")
            if not handle then return copy:Destroy() end
            local preset = handle:FindFirstChild("AccessoryWeld")
            if preset and preset:IsA("JointInstance") and not fromAsset then
                local own = preset.Part0 == handle
                local other = own and preset.Part1 or preset.Part0
                local mapped = other and other ~= handle and (char:FindFirstChild(other.Name) or char:FindFirstChild(other.Name, true))
                if mapped then
                    if own then preset.Part1 = mapped else preset.Part0 = mapped end
                    copy.Parent = char
                    Avatar.wornKeys[key] = true
                    return
                end
            end
            local attachment, target
            for _, candidate in ipairs(handle:GetChildren()) do
                if candidate:IsA("Attachment") and not attachment then
                    for _, d in ipairs(char:GetDescendants()) do
                        if d:IsA("Attachment") and d.Name == candidate.Name and not d:IsDescendantOf(copy) then
                            attachment, target = candidate, d
                            break
                        end
                    end
                end
            end
            attachment = attachment or handle:FindFirstChildWhichIsA("Attachment")
            if fromAsset then scaleAccessory(copy, descFactor(target ~= nil and target.Parent ~= nil and target.Parent.Name == "Head")) end
            copy.Parent = char
            local weld = Instance.new("Weld")
            weld.Name = "AccessoryWeld"
            weld.Part0 = handle
            if target then
                weld.Part1, weld.C0, weld.C1 = target.Parent, attachment.CFrame, target.CFrame
            else
                weld.Part1 = char:FindFirstChild("Head") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso") or char:FindFirstChild("HumanoidRootPart")
            end
            weld.Parent = handle
            Avatar.wornKeys[key] = true
        end)
        return Avatar.wornKeys[key] == true
    end

    local function grabAsset(id)
        id = tonumber(id)
        if not id or id <= 0 then return nil end
        local ok, objects = pcall(function() return game:GetObjects("rbxassetid://" .. tostring(id)) end)
        if ok and type(objects) == "table" then return objects end
        return nil
    end

    local function copySpecialMesh(limb, source)
        pcall(function()
            local target = limb:FindFirstChildOfClass("SpecialMesh")
            if not target then
                target = Instance.new("SpecialMesh")
                target.Parent = limb
            end
            target.MeshType, target.MeshId, target.TextureId, target.Scale = source.MeshType, source.MeshId, source.TextureId, source.Scale
        end)
    end

    local function cloneMeshes(char, model)
        local count = 0
        for _, v in ipairs(char:GetChildren()) do
            if v:IsA("CharacterMesh") then pcall(function() v:Destroy() end) end
        end
        for _, v in ipairs(model:GetChildren()) do
            if v:IsA("CharacterMesh") and pcall(function() v:Clone().Parent = char end) then count = count + 1 end
        end
        return count
    end

    local R6_LIMBS = { { "Head", "Head" }, { "Torso", "Torso" }, { "LeftArm", "Left Arm" }, { "RightArm", "Right Arm" }, { "LeftLeg", "Left Leg" }, { "RightLeg", "Right Leg" } }
    local function r6Meshes(char, desc)
        local function wearLimb(assetId, bodyPart, limbName)
            local objects = grabAsset(assetId)
            if not objects then return false end
            local applied = false
            local function take(o)
                if o:IsA("CharacterMesh") then
                    if pcall(function()
                        local mesh = o:Clone()
                        pcall(function() mesh.BodyPart = bodyPart end)
                        mesh.Parent = char
                    end) then applied = true end
                elseif o:IsA("SpecialMesh") then
                    local limb = char:FindFirstChild(limbName)
                    if limb then
                        copySpecialMesh(limb, o)
                        applied = true
                    end
                elseif o:IsA("Accessory") then
                    if wearAccessory(char, o, true) then applied = true end
                end
                if limbName == "Head" and (o:IsA("FaceControls") or (o:IsA("MeshPart") and o.Name == "Head")) then Avatar.headDynamic = true end
            end
            for _, object in ipairs(objects) do
                take(object)
                for _, d in ipairs(object:GetDescendants()) do take(d) end
            end
            return applied
        end
        local count = 0
        for _, entry in ipairs(R6_LIMBS) do
            local okId, assetId = pcall(function() return tonumber(desc[entry[1]]) or 0 end)
            if okId and assetId > 0 and wearLimb(assetId, Enum.BodyPart[entry[1]], entry[2]) then count = count + 1 end
        end
        local okL, left = pcall(function() return tonumber(desc.LeftLeg) or 0 end)
        local okR, right = pcall(function() return tonumber(desc.RightLeg) or 0 end)
        if (okL and left == KORBLOX_LEFT) or (okR and right == KORBLOX_RIGHT) then
            if wearLimb(KORBLOX_LEFT, Enum.BodyPart.LeftLeg, "Left Leg") then count = count + 1 end
            if wearLimb(KORBLOX_RIGHT, Enum.BodyPart.RightLeg, "Right Leg") then count = count + 1 end
        end
        return count
    end

    local function copyClothesAndColors(char, model)
        for _, className in ipairs({ "Shirt", "Pants", "ShirtGraphic", "BodyColors" }) do
            local source = model:FindFirstChildOfClass(className)
            if source then pcall(function() source:Clone().Parent = char end) end
        end
        local head, sourceHead = char:FindFirstChild("Head"), model:FindFirstChild("Head")
        if not (head and sourceHead) then return end
        local gen = applyGen
        local function clearFaces()
            if gen ~= applyGen then return end
            for _, d in ipairs(head:GetChildren()) do
                if d:IsA("Decal") or d:IsA("SurfaceAppearance") then pcall(function() d:Destroy() end) end
            end
        end
        clearFaces()
        if sourceHead:IsA("MeshPart") then
            pcall(function()
                local mesh = head:FindFirstChildOfClass("SpecialMesh")
                if not mesh then
                    mesh = Instance.new("SpecialMesh")
                    mesh.Parent = head
                end
                mesh.MeshType, mesh.MeshId = Enum.MeshType.FileMesh, sourceHead.MeshId
                local appearance = sourceHead:FindFirstChildOfClass("SurfaceAppearance")
                local texture = appearance and appearance.ColorMap or ""
                mesh.TextureId = texture ~= "" and texture or sourceHead.TextureID
                local native, size = sourceHead.MeshSize, sourceHead.Size
                if native.X > 0 and native.Y > 0 and native.Z > 0 then mesh.Scale = Vector3.new(size.X / native.X, size.Y / native.Y, size.Z / native.Z) end
            end)
            -- the game re-adds the default face after a dynamic head lands; keep removing it for a while
            task.delay(0.75, clearFaces)
            task.delay(2, clearFaces)
            local watcher = head.ChildAdded:Connect(function(child)
                if gen == applyGen and child:IsA("Decal") then task.defer(function() pcall(function() child:Destroy() end) end) end
            end)
            watchers[#watchers + 1] = Util.track(watcher)
            task.delay(20, function() pcall(function() watcher:Disconnect() end) end)
        else
            for _, d in ipairs(sourceHead:GetChildren()) do
                if d:IsA("Decal") then pcall(function() d:Clone().Parent = head end) end
            end
            local sourceMesh = sourceHead:FindFirstChildOfClass("SpecialMesh")
            if sourceMesh then copySpecialMesh(head, sourceMesh) end
        end
    end

    local function isHeadlessName(object) return string.find(string.lower(object.Name), "headless", 1, true) ~= nil end

    local ACC_PROPS = { "HatAccessory", "HairAccessory", "FaceAccessory", "NeckAccessory", "ShouldersAccessory", "FrontAccessory", "BackAccessory", "WaistAccessory" }
    local function accessoriesFromDescription(char, desc)
        local headless, ids = false, {}
        pcall(function()
            for _, prop in ipairs(ACC_PROPS) do
                local value = desc[prop]
                if type(value) == "string" then
                    for id in string.gmatch(value, "%d+") do ids[#ids + 1] = tonumber(id) end
                end
            end
            for _, accessory in ipairs(desc:GetAccessories(true)) do
                if accessory.AssetId then ids[#ids + 1] = accessory.AssetId end
            end
        end)
        for _, id in ipairs(ids) do
            if HEADLESS_IDS[id] then headless = true end
            for _, object in ipairs(grabAsset(id) or {}) do
                local list = object:IsA("Accessory") and { object } or object:GetDescendants()
                for _, d in ipairs(list) do
                    if d:IsA("Accessory") then
                        if isHeadlessName(d) then headless = true end
                        wearAccessory(char, d, true)
                    elseif d:IsA("CharacterMesh") then
                        pcall(function() d:Clone().Parent = char end)
                    end
                end
            end
        end
        return headless
    end

    local DEFAULT_FACES = { "textures/face.png", "id=144080495", "//144080495", "id=144075659", "//144075659" }
    local function isDefaultFace(decal)
        local ok, texture = pcall(function() return string.lower(tostring(decal.Texture)) end)
        if not ok or texture == "" then return true end
        for _, pattern in ipairs(DEFAULT_FACES) do
            if string.find(texture, pattern, 1, true) then return true end
        end
        return false
    end

    local function headIsTextured(head, model, desc)
        if Avatar.headDynamic then return true end
        local okHead, headId = pcall(function() return tonumber(desc and desc.Head) or 0 end)
        if okHead and headId > 0 and Avatar.dynamicHeads[headId] then return true end
        local sourceHead = model and model:FindFirstChild("Head")
        if sourceHead and (sourceHead:IsA("MeshPart") or sourceHead:FindFirstChildOfClass("FaceControls")) then return true end
        local mesh = head:FindFirstChildOfClass("SpecialMesh")
        local okTexture, texture = pcall(function() return mesh and tostring(mesh.TextureId) or "" end)
        return okTexture and texture ~= ""
    end

    -- a textured head with no face asset must lose the default smile; otherwise drop duplicate and default decals
    function Avatar.fixFace(char, desc, model)
        local head = char and char:FindFirstChild("Head")
        if not head then return 0 end
        local okFace, faceId = pcall(function() return tonumber(desc and desc.Face) or 0 end)
        faceId = okFace and faceId or 0
        local decals, drop = {}, {}
        for _, d in ipairs(head:GetChildren()) do
            if d:IsA("Decal") and not d:IsA("Texture") then decals[#decals + 1] = d end
        end
        if faceId == 0 and headIsTextured(head, model, desc) then
            for _, d in ipairs(decals) do drop[d] = true end
        else
            local real, seen = {}, {}
            for _, d in ipairs(decals) do
                if not isDefaultFace(d) then real[tostring(d.Face)] = true end
            end
            for _, d in ipairs(decals) do
                local side = tostring(d.Face)
                local key = side .. "|" .. tostring(d.Texture)
                if seen[key] or (real[side] and isDefaultFace(d)) then drop[d] = true end
                seen[key] = true
            end
        end
        local removed = 0
        for d in pairs(drop) do
            if pcall(function() d:Destroy() end) then removed = removed + 1 end
        end
        return removed
    end

    local function applyDescription(humanoid, desc)
        local okAsync, async = pcall(function() return humanoid.ApplyDescriptionAsync end)
        if okAsync and type(async) == "function" and pcall(async, humanoid, desc) then return true end
        return (pcall(function() humanoid:ApplyDescription(desc) end))
    end

    local function forceHeadless(char)
        local head = char:FindFirstChild("Head")
        if not head then return end
        pcall(function()
            head.Transparency = 1
            for _, d in ipairs(head:GetChildren()) do
                if d:IsA("Decal") then d.Transparency = 1 end
            end
        end)
    end

    local modelCache, cacheOrder = {}, {}
    local function fetchModel(uid, rigType, outfitId)
        local key = (outfitId and ("o" .. tostring(outfitId)) or ("u" .. tostring(uid))) .. ":" .. tostring(rigType)
        local hit = modelCache[key]
        if hit then
            local okClone, copy = pcall(function() return hit.model:Clone() end)
            if okClone and copy then return copy, hit.desc end
        end
        local model
        local described, desc = pcall(function()
            if outfitId then return Players:GetHumanoidDescriptionFromOutfitId(outfitId) end
            return Players:GetHumanoidDescriptionFromUserIdAsync(uid)
        end)
        if not described then desc = nil end
        if desc then
            local ok, built = pcall(function() return Players:CreateHumanoidModelFromDescription(desc, rigType) end)
            if ok then model = built end
        end
        if not model and not outfitId then
            local ok, built = pcall(function() return Players:CreateHumanoidModelFromUserId(uid) end)
            if ok then model = built end
        end
        if model then
            local okClone, copy = pcall(function() return model:Clone() end)
            if okClone and copy then
                modelCache[key] = { model = copy, desc = desc }
                cacheOrder[#cacheOrder + 1] = key
                while #cacheOrder > 8 do
                    local old = table.remove(cacheOrder, 1)
                    local entry = modelCache[old]
                    modelCache[old] = nil
                    if entry then pcall(function() entry.model:Destroy() end) end
                end
            end
        end
        return model, desc
    end

    local function finishApply(char, humanoid, model, desc)
        stripAppearance(char)
        Avatar.wornKeys, Avatar.headDynamic = {}, false
        copyClothesAndColors(char, model)
        local meshes = cloneMeshes(char, model)
        if desc and isR6(humanoid) then meshes = meshes + r6Meshes(char, desc) end
        Avatar.fixFace(char, desc, model)
        for _, accessory in ipairs(model:GetChildren()) do
            if accessory:IsA("Accessory") then wearAccessory(char, accessory) end
        end
        local headless = desc ~= nil and accessoriesFromDescription(char, desc)
        for _, child in ipairs(char:GetChildren()) do
            if child:IsA("Accessory") and isHeadlessName(child) then headless = true end
        end
        if headless then forceHeadless(char) end
        dedupeAccessories(char)
        local accessories = 0
        for _, child in ipairs(char:GetChildren()) do
            if child:IsA("Accessory") then accessories = accessories + 1 end
        end
        pcall(function() model:Destroy() end)
        Avatar.applied = { meshes = meshes, accessories = accessories, headless = headless }
        notify(string.format("avatar applied (meshes %d, accessories %d%s)", meshes, accessories, headless and ", headless" or ""), "ok")
        return true
    end

    local function prepare(char)
        snapshot(char)
        applyGen = applyGen + 1
        dropWatchers()
    end

    local function applyAvatar(rawInput, outfitId)
        local char, humanoid = localHumanoid()
        if not humanoid then return notify("avatar: no character yet", "warn") end
        local uid = 0
        if not outfitId then
            uid = Avatar.resolveUserId(rawInput)
            if not uid then return notify("avatar: could not find user " .. tostring(rawInput or ""), "warn") end
        end
        notify("avatar: fetching " .. (outfitId and ("outfit " .. outfitId) or tostring(uid)) .. "...")
        local model, desc = fetchModel(uid, humanoid.RigType, outfitId)
        if LocalPlayer.Character ~= char then return false end
        Avatar.lastUid, Avatar.lastOutfit, Avatar.lastBuilt = (not outfitId) and uid or nil, outfitId, nil
        Avatar.currentDesc = desc
        prepare(char)
        if not model then
            if not desc then return notify("avatar: could not fetch that avatar", "warn") end
            Avatar.headDynamic = false
            applyDescription(humanoid, desc)
            if isR6(humanoid) then r6Meshes(char, desc) end
            Avatar.fixFace(char, desc, nil)
            dedupeAccessories(char)
            notify("avatar: applied the description only (no model)")
            return true
        end
        return finishApply(char, humanoid, model, desc)
    end

    local function applyBuiltDescription(desc)
        local char, humanoid = localHumanoid()
        if not humanoid then return notify("avatar: no character yet", "warn") end
        local okModel, model = pcall(function() return Players:CreateHumanoidModelFromDescription(desc, humanoid.RigType) end)
        if not okModel or not model then return notify("avatar: could not build that avatar", "warn") end
        if LocalPlayer.Character ~= char then return false end
        local okClone, copy = pcall(function() return desc:Clone() end)
        Avatar.lastUid, Avatar.lastOutfit, Avatar.lastBuilt = nil, nil, okClone and copy or desc
        Avatar.currentDesc = desc
        prepare(char)
        return finishApply(char, humanoid, model, desc)
    end

    local function locked(fn, ...)
        if Avatar.busy then return notify("avatar: still working on the last one", "warn") end
        Avatar.busy = true
        local ok, result = Util.guard("avatar apply", fn, ...)
        Avatar.busy = false
        if not ok then notify("avatar: apply failed, see the console", "warn") end
        return ok and result or false
    end

    function Avatar.applyUser(raw) return locked(applyAvatar, raw) end
    function Avatar.applyOutfit(outfitId) return locked(applyAvatar, nil, outfitId) end
    function Avatar.applyBuilt(desc) return locked(applyBuiltDescription, desc) end
    function Avatar.copy(player)
        if player and player.UserId then task.spawn(Avatar.applyUser, tostring(player.UserId)) end
    end
    function Avatar.reset()
        Avatar.lastUid, Avatar.lastOutfit, Avatar.lastBuilt = nil, nil, nil
        if Avatar.restore() then return notify("avatar: back to your own look", "ok") end
        notify("avatar: nothing to reset on this character")
    end

    -- store ------------------------------------------------------------------------------------------
    do
        local ok, data = pcall(function()
            if isfile and readfile and isfile(STORE_PATH) then return HttpService:JSONDecode(readfile(STORE_PATH)) end
        end)
        if ok and type(data) == "table" then
            for _, key in ipairs({ "recent", "favorites", "outfits" }) do
                if type(data[key]) == "table" then store[key] = data[key] end
            end
        end
    end

    function Avatar.save()
        if not writefile then return end
        pcall(function()
            if makefolder and isfolder then
                for _, dir in ipairs({ "AsterV2", "AsterV2/games", ROOT }) do
                    if not isfolder(dir) then makefolder(dir) end
                end
            end
            writefile(STORE_PATH, HttpService:JSONEncode(store))
        end)
    end

    local function sameInfo(a, b)
        return a.kind == b.kind and ((a.kind == "outfit" and a.id == b.id) or (a.kind ~= "outfit" and a.uid == b.uid))
    end
    function Avatar.favoriteIndex(info)
        for index, entry in ipairs(store.favorites) do
            if sameInfo(entry, info) then return index end
        end
        return nil
    end
    function Avatar.toggleFavorite(info)
        local index = Avatar.favoriteIndex(info)
        if index then
            table.remove(store.favorites, index)
        else
            table.insert(store.favorites, { kind = info.kind, id = info.id, uid = info.uid, name = info.name })
        end
        Avatar.save()
        return index == nil
    end
    function Avatar.recordRecent(uid, name, forget)
        for index = #store.recent, 1, -1 do
            if store.recent[index].uid == uid then table.remove(store.recent, index) end
        end
        if not forget then table.insert(store.recent, 1, { uid = uid, name = name }) end
        while #store.recent > 15 do table.remove(store.recent) end
        Avatar.save()
    end

    -- web api: proxies first, then roblox.com without the game headers that make it answer "denied"
    local PROXY_HOSTS = { "roproxy.com", "rprxy.xyz" }
    local BROWSER_UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"
    local workingKey
    local function candidatesFor(url)
        local list, seen, hosts = {}, {}, {}
        local custom = string.gsub(string.gsub(tostring(F("avatar_proxy") or ""), "^%s*https?://", ""), "[/%s]+$", "")
        if custom ~= "" then hosts[#hosts + 1] = custom end
        for _, host in ipairs(PROXY_HOSTS) do hosts[#hosts + 1] = host end
        for _, host in ipairs(hosts) do
            if not seen[host] then
                seen[host] = true
                list[#list + 1] = { key = host, url = (string.gsub(url, "roblox%.com", host)) }
            end
        end
        list[#list + 1] = { key = "roblox.com (no game headers)", url = url, override = true }
        list[#list + 1] = { key = "roblox.com", url = url }
        for index, entry in ipairs(list) do
            if entry.key == workingKey and index > 1 then
                table.remove(list, index)
                table.insert(list, 1, entry)
                break
            end
        end
        return list
    end

    function Avatar.httpJson(url)
        local lastStatus, attempts = nil, {}
        for _, candidate in ipairs(candidatesFor(url)) do
            local headers = { ["User-Agent"] = BROWSER_UA, ["Accept"] = "application/json" }
            if candidate.override then headers["Roblox-Place-Id"], headers["Roblox-Game-Id"], headers["Roblox-Session-Id"] = "0", "0", "" end
            local body, status, note = httpGet(candidate.url, headers)
            local data = decode(body)
            if data and not data.errors then
                workingKey = candidate.key
                return data, status
            end
            if data then
                local text = tostring(data.errors[1] and data.errors[1].message or "error")
                note, status = text, status or 400
                local denied = string.find(string.lower(text), "denied", 1, true) ~= nil
                if status == 429 or (status >= 400 and status < 500 and status ~= 403 and status ~= 401 and not denied) then return nil, status, text end
            end
            attempts[#attempts + 1] = candidate.key .. ":" .. tostring(status or "no reply") .. (note and (" (" .. string.sub(tostring(note), 1, 60) .. ")") or "")
            lastStatus = status or lastStatus
        end
        return nil, lastStatus, "[" .. table.concat(attempts, "; ") .. "]"
    end

    local function httpJsonRetry(url, alive)
        local data, status, message
        for attempt = 1, 4 do
            data, status, message = Avatar.httpJson(url)
            if data then return data, status end
            local retryable = status == nil or status == 429 or status >= 500
            if not retryable or attempt >= ((status == 429) and 4 or 2) or (alive and not alive()) then break end
            task.wait((status == 429) and (3 * attempt) or 1.5)
            if alive and not alive() then break end
        end
        return nil, status, message
    end

    function Avatar.fetchOutfits(uid, onChunk, alive)
        local seen, list = {}, {}
        local function take(entries)
            local fresh = {}
            for _, entry in ipairs(entries or {}) do
                if entry.id and not seen[entry.id] then
                    seen[entry.id] = true
                    local outfit = { id = entry.id, name = tostring(entry.name or entry.id) }
                    list[#list + 1], fresh[#fresh + 1] = outfit, outfit
                end
            end
            if #fresh > 0 and onChunk then onChunk(fresh, #list) end
            return #fresh
        end
        local firstStatus
        for page = 1, 20 do
            if page > 1 then task.wait(1) end
            local data, status = httpJsonRetry(string.format("https://avatar.roblox.com/v1/users/%d/outfits?page=%d&itemsPerPage=50", uid, page), alive)
            if not data then
                firstStatus = firstStatus or status
                break
            end
            if take(data.data) == 0 or #(data.data or {}) < 50 then break end
        end
        if #list == 0 and (not alive or alive()) then
            local token
            for page = 1, 20 do
                local url = string.format("https://avatar.roblox.com/v2/avatar/users/%d/outfits?outfitType=1&page=1&itemsPerPage=50&isEditable=true", uid)
                if token then url = url .. "&paginationToken=" .. token end
                if page > 1 then task.wait(2) end
                local data, status = httpJsonRetry(url, alive)
                if not data then
                    firstStatus = firstStatus or status
                    break
                end
                firstStatus = nil
                token = data.paginationToken or data.nextPageCursor or data.nextPageToken
                if take(data.data) == 0 or type(token) ~= "string" or token == "" then break end
            end
        end
        if #list == 0 and firstStatus then
            local kind = "unreachable"
            if firstStatus == 401 or firstStatus == 403 or firstStatus == 400 or firstStatus == 404 then kind = "private" end
            if firstStatus == 429 then kind = "rate limited" end
            return nil, kind
        end
        return list, #list > 0 and "public" or "no saved outfits"
    end

    -- builder ----------------------------------------------------------------------------------------
    local ACC_SLOTS = {
        Hat = { acc = "Hat" }, HairAccessory = { acc = "Hair" }, FaceAccessory = { acc = "Face" }, NeckAccessory = { acc = "Neck" },
        ShoulderAccessory = { acc = "Shoulder" }, FrontAccessory = { acc = "Front" }, BackAccessory = { acc = "Back" }, WaistAccessory = { acc = "Waist" },
        EyebrowAccessory = { acc = "Eyebrow" }, EyelashAccessory = { acc = "Eyelash" },
        Shirt = { prop = "Shirt" }, Pants = { prop = "Pants" }, TShirt = { prop = "GraphicTShirt" },
        Head = { prop = "Head" }, DynamicHead = { prop = "Head" }, Face = { prop = "Face" }, Torso = { prop = "Torso" },
        RightArm = { prop = "RightArm" }, LeftArm = { prop = "LeftArm" }, LeftLeg = { prop = "LeftLeg" }, RightLeg = { prop = "RightLeg" },
        ClimbAnimation = { prop = "ClimbAnimation" }, FallAnimation = { prop = "FallAnimation" }, IdleAnimation = { prop = "IdleAnimation" },
        JumpAnimation = { prop = "JumpAnimation" }, MoodAnimation = { prop = "MoodAnimation" }, RunAnimation = { prop = "RunAnimation" },
        SwimAnimation = { prop = "SwimAnimation" }, WalkAnimation = { prop = "WalkAnimation" },
    }
    local PROP_ORDER = { "Head", "Face", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg", "Shirt", "Pants", "GraphicTShirt", "IdleAnimation", "WalkAnimation", "RunAnimation", "JumpAnimation", "FallAnimation", "ClimbAnimation", "SwimAnimation", "MoodAnimation" }
    local COLOR_PROPS = { "HeadColor", "TorsoColor", "LeftArmColor", "RightArmColor", "LeftLegColor", "RightLegColor" }
    local SCALE_PROPS = { "HeightScale", "WidthScale", "DepthScale", "HeadScale", "BodyTypeScale", "ProportionScale" }
    Avatar.ACC_SLOTS, Avatar.COLOR_PROPS = ACC_SLOTS, COLOR_PROPS

    local ASSET_BY_VALUE = {}
    pcall(function()
        for _, item in ipairs(Enum.AvatarAssetType:GetEnumItems()) do ASSET_BY_VALUE[item.Value] = item.Name end
    end)
    local function assetTypeName(value)
        if typeof(value) == "EnumItem" or type(value) == "table" then return value.Name end
        if type(value) == "number" then return ASSET_BY_VALUE[value] end
        if type(value) == "string" then return value end
        return nil
    end
    local function thumb(kind, id) return string.format("rbxthumb://type=%s&id=%d&w=150&h=150", kind, id) end
    Avatar.thumb = thumb

    function Avatar.changed()
        Builder.stamp = Builder.stamp + 1
        local set = {}
        for _, item in ipairs(Avatar.wornItems()) do set[item.id] = true end
        Avatar.wornSet = set
        for _, fn in ipairs(Avatar.listeners) do Util.guard("avatar ui", fn) end
    end

    local function accessories(desc)
        local ok, list = pcall(function() return desc:GetAccessories(true) end)
        return ok and type(list) == "table" and list or {}
    end

    function Avatar.wearAsset(id, typeName, onlyAdd)
        local desc, slot = Builder.desc, typeName and ACC_SLOTS[typeName]
        if not (desc and slot) then return nil end
        if slot.acc then
            local list = accessories(desc)
            for index, entry in ipairs(list) do
                if entry.AssetId == id then
                    if onlyAdd then return true end
                    table.remove(list, index)
                    desc:SetAccessories(list, true)
                    return false
                end
            end
            list[#list + 1] = { AssetId = id, AccessoryType = Enum.AccessoryType[slot.acc], IsLayered = false }
            desc:SetAccessories(list, true)
            return true
        end
        if typeName == "DynamicHead" then Avatar.dynamicHeads[id] = true end
        if desc[slot.prop] == id then
            if onlyAdd then return true end
            desc[slot.prop] = 0
            return false
        end
        desc[slot.prop] = id
        return true
    end

    function Avatar.wornItems()
        local out, desc = {}, Builder.desc
        if not desc then return out end
        for _, a in ipairs(accessories(desc)) do out[#out + 1] = { id = a.AssetId, label = tostring(assetTypeName(a.AccessoryType) or "Accessory") } end
        for _, prop in ipairs(PROP_ORDER) do
            local ok, id = pcall(function() return desc[prop] end)
            if ok and type(id) == "number" and id ~= 0 then out[#out + 1] = { id = id, label = prop, prop = prop } end
        end
        return out
    end

    function Avatar.isWorn(id) return Avatar.wornSet[id] == true end

    function Avatar.removeItem(item)
        local desc = Builder.desc
        if not desc then return end
        if item.prop then
            desc[item.prop] = 0
            return
        end
        local list = accessories(desc)
        for index, a in ipairs(list) do
            if a.AssetId == item.id then
                table.remove(list, index)
                break
            end
        end
        desc:SetAccessories(list, true)
    end

    function Avatar.serialize(desc)
        local out = { acc = {}, props = {}, colors = {}, scales = {} }
        for _, a in ipairs(accessories(desc)) do
            out.acc[#out.acc + 1] = { id = a.AssetId, kind = assetTypeName(a.AccessoryType), layered = a.IsLayered == true, order = a.Order, puff = a.Puffiness }
        end
        for _, prop in ipairs(PROP_ORDER) do
            local ok, value = pcall(function() return desc[prop] end)
            if ok and type(value) == "number" and value ~= 0 then out.props[prop] = value end
        end
        for _, prop in ipairs(COLOR_PROPS) do
            local ok, color = pcall(function() return desc[prop] end)
            if ok and typeof(color) == "Color3" then out.colors[prop] = { color.R, color.G, color.B } end
        end
        for _, prop in ipairs(SCALE_PROPS) do
            local ok, value = pcall(function() return desc[prop] end)
            if ok and type(value) == "number" then out.scales[prop] = value end
        end
        return out
    end

    function Avatar.deserialize(data)
        local desc = Instance.new("HumanoidDescription")
        for prop, value in pairs(data.props or {}) do pcall(function() desc[prop] = value end) end
        for prop, rgb in pairs(data.colors or {}) do
            if type(rgb) == "table" then pcall(function() desc[prop] = Color3.new(rgb[1], rgb[2], rgb[3]) end) end
        end
        for prop, value in pairs(data.scales or {}) do pcall(function() desc[prop] = value end) end
        local list = {}
        for _, entry in ipairs(data.acc or {}) do
            local okType, accType = pcall(function() return Enum.AccessoryType[entry.kind] end)
            if okType and accType then
                local item = { AssetId = entry.id, AccessoryType = accType, IsLayered = entry.layered == true }
                if entry.layered then item.Order, item.Puffiness = entry.order or 1, entry.puff or 1 end
                list[#list + 1] = item
            end
        end
        pcall(function() desc:SetAccessories(list, true) end)
        return desc
    end

    function Avatar.setDescription(desc)
        Builder.desc, Builder.baseColors = desc, {}
        for _, prop in ipairs(COLOR_PROPS) do
            local ok, color = pcall(function() return desc[prop] end)
            if ok and typeof(color) == "Color3" then Builder.baseColors[prop] = color end
        end
        Avatar.changed()
    end

    function Avatar.loadMine()
        local desc
        if Avatar.currentDesc then
            local ok, copy = pcall(function() return Avatar.currentDesc:Clone() end)
            if ok then desc = copy end
        end
        if not desc then
            local ok, fetched = pcall(function() return Players:GetHumanoidDescriptionFromUserIdAsync(LocalPlayer.UserId) end)
            if ok then desc = fetched end
        end
        if not desc then
            local _, humanoid = localHumanoid()
            local ok, applied = pcall(function() return humanoid:GetAppliedDescription() end)
            if ok then desc = applied end
        end
        if not desc then
            notify("avatar: could not read your avatar, starting from an empty one", "warn")
            desc = Instance.new("HumanoidDescription")
        end
        Avatar.setDescription(desc)
    end

    function Avatar.edit(info)
        local ok, desc = pcall(function()
            if info.data then return Avatar.deserialize(info.data) end
            if info.kind == "outfit" then return Players:GetHumanoidDescriptionFromOutfitId(info.id) end
            return Players:GetHumanoidDescriptionFromUserIdAsync(info.uid)
        end)
        if not (ok and desc) then return notify("avatar: could not load " .. tostring(info.name), "warn") end
        Avatar.setDescription(desc)
        return true
    end

    function Avatar.setColor(prop, color)
        if not Builder.desc then return notify("avatar: the builder is still loading", "warn") end
        for _, name in ipairs(prop and { prop } or COLOR_PROPS) do pcall(function() Builder.desc[name] = color end) end
        Avatar.changed()
    end

    function Avatar.resetColors()
        if not (Builder.desc and Builder.baseColors) then return end
        for prop, color in pairs(Builder.baseColors) do pcall(function() Builder.desc[prop] = color end) end
        Avatar.changed()
    end

    function Avatar.saveOutfit(name)
        if not Builder.desc then return notify("avatar: nothing to save yet", "warn") end
        local data = Avatar.serialize(Builder.desc)
        if next(data.props) == nil and #data.acc == 0 then return notify("avatar: the builder is empty, wear something first", "warn") end
        name = (name and name ~= "") and name or ("outfit " .. (#store.outfits + 1))
        table.insert(store.outfits, 1, { name = name, rig = Builder.rig, data = data })
        while #store.outfits > 40 do table.remove(store.outfits) end
        Avatar.save()
        notify("avatar: saved " .. name, "ok")
        return true
    end

    -- catalog ----------------------------------------------------------------------------------------
    local CATEGORIES = {
        { "all", {}, nil, false, false }, { "hats", { "Hat" }, nil, false, true }, { "hair", { "HairAccessory" }, nil, false, true },
        { "face acc.", { "FaceAccessory" }, nil, false, true }, { "neck", { "NeckAccessory" }, nil, false, true },
        { "shoulder", { "ShoulderAccessory" }, nil, false, true }, { "front", { "FrontAccessory" }, nil, false, true },
        { "back", { "BackAccessory" }, nil, false, true }, { "waist", { "WaistAccessory" }, nil, false, true },
        { "shirts", { "Shirt" }, nil, false, true }, { "t-shirts", { "TShirt" }, nil, false, true }, { "pants", { "Pants" }, nil, false, true },
        { "heads", { "DynamicHead" }, nil, false, true }, { "bodies", {}, "BodyParts", true, false },
        { "animations", {}, "Animations", false, false }, { "emotes", { "EmoteAnimation" }, nil, true, false },
    }
    local CATEGORY_NAMES, CATEGORY_BY_NAME = {}, {}
    for index, entry in ipairs(CATEGORIES) do
        if entry[5] then
            for _, name in ipairs(entry[2]) do CATEGORIES[1][2][#CATEGORIES[1][2] + 1] = name end
        end
        CATEGORY_NAMES[index], CATEGORY_BY_NAME[entry[1]] = entry[1], entry
    end
    local KIND_NAMES = { "any", "limited", "roblox", "ugc", "premium", "free" }
    local SORTS = { { "relevance", "Relevance", 0 }, { "most favorited", "MostFavorited", 1 }, { "best selling", "Bestselling", 2 }, { "newest", "RecentlyCreated", 3 }, { "price low", "PriceLowToHigh", 4 }, { "price high", "PriceHighToLow", 5 } }
    local SORT_NAMES = {}
    for index, entry in ipairs(SORTS) do SORT_NAMES[index] = entry[1] end
    Avatar.CATEGORY_NAMES, Avatar.KIND_NAMES = CATEGORY_NAMES, KIND_NAMES

    local Catalog = { gen = 0, entries = {}, F = { keyword = "", types = CATEGORIES[1][2], kind = "any", sort = "Relevance", catName = "all", onSale = false } }
    Avatar.Catalog = Catalog

    function Avatar.setFilters(o)
        local f = Catalog.F
        local entry = CATEGORY_BY_NAME[o.category or f.catName] or CATEGORIES[1]
        f.catName, f.types, f.bundleType, f.robloxOnly = entry[1], entry[2], entry[3], entry[4]
        for _, s in ipairs(SORTS) do
            if s[1] == o.sort then f.sort = s[2] end
        end
        if o.keyword ~= nil then f.keyword = o.keyword end
        if o.kind then f.kind = o.kind end
        if o.onSale ~= nil then f.onSale = o.onSale == true end
        if o.price ~= nil then
            local low, high = string.match(tostring(o.price), "^%s*(%d*)%s*%-?%s*(%d*)%s*$")
            f.minPrice, f.maxPrice = tonumber(low or ""), tonumber(high or "")
            if f.minPrice and f.maxPrice and f.minPrice > f.maxPrice then f.minPrice, f.maxPrice = f.maxPrice, f.minPrice end
        end
    end

    local function onlyRoblox(f)
        local _, humanoid = localHumanoid()
        return f.robloxOnly == true or (f.bundleType ~= nil and humanoid ~= nil and isR6(humanoid))
    end

    local function searchParams(f, level)
        local params = CatalogSearchParams.new()
        params.SearchKeyword = f.keyword or ""
        if level == 3 then return params end
        pcall(function() params.SortType = Enum.CatalogSortType[f.sort] end)
        pcall(function()
            local types = {}
            for _, name in ipairs(f.types) do types[#types + 1] = Enum.AvatarAssetType[name] end
            if #types > 0 then params.AssetTypes = types end
        end)
        if f.bundleType then pcall(function() params.BundleTypes = { Enum.BundleType[f.bundleType] } end) end
        if level == 2 then return params end
        params.IncludeOffSale = not f.onSale
        pcall(function() params.Limit = 30 end)
        if onlyRoblox(f) or f.kind == "roblox" or f.kind == "limited" then pcall(function() params.CreatorName = "Roblox" end) end
        if f.kind == "free" then
            pcall(function() params.MaxPrice = 0 end)
        else
            if f.minPrice then pcall(function() params.MinPrice = f.minPrice end) end
            if f.maxPrice then pcall(function() params.MaxPrice = f.maxPrice end) end
        end
        return params
    end

    function Avatar.normItem(item)
        local id = item.Id or item.id
        if type(id) ~= "number" then return nil end
        local itemType = item.ItemType or item.itemType
        local restrictions = item.itemRestrictions or item.ItemRestrictions
        local limited, premium = item.IsLimited == true or item.IsLimitedUnique == true, type(item.PremiumPricing or item.premiumPricing) == "table" or item.IsPremium == true
        if type(restrictions) == "table" then
            for _, r in pairs(restrictions) do
                local text = string.lower(tostring(r))
                if text == "limited" or text == "limitedunique" then limited = true end
                if string.find(text, "premium", 1, true) then premium = true end
            end
        end
        local creator = item.CreatorName or item.creatorName or item.Creator or item.creator
        if type(creator) == "table" then creator = creator.Name or creator.name end
        creator = creator ~= nil and tostring(creator) or nil
        return {
            id = id, name = tostring(item.Name or item.name or id), price = item.Price or item.price or item.lowestPrice,
            assetName = assetTypeName(item.AssetType or item.assetType), creator = creator, limited = limited, premium = premium,
            roblox = creator == "Roblox" or creator == "Roblox Corporation" or item.CreatorTargetId == 1 or item.creatorTargetId == 1,
            isBundle = assetTypeName(itemType) == "Bundle", priceStatus = tostring(item.PriceStatus or item.priceStatus or ""),
        }
    end

    local function passes(f, e)
        if onlyRoblox(f) and not e.roblox then return false end
        if f.kind == "limited" then return e.limited and e.roblox end
        if f.kind == "roblox" then return e.roblox end
        if f.kind == "ugc" then return not e.roblox end
        if f.kind == "premium" then return e.premium end
        if f.kind == "free" then return e.price == 0 end
        if f.onSale and e.price == nil then return false end
        if type(e.price) == "number" then return not ((f.minPrice and e.price < f.minPrice) or (f.maxPrice and e.price > f.maxPrice)) end
        return not (f.minPrice or f.maxPrice)
    end

    local function httpSearch(f, cursor)
        local sort = 0
        for _, s in ipairs(SORTS) do
            if s[2] == f.sort then sort = s[3] end
        end
        local url = "https://catalog.roblox.com/v1/search/items/details?Keyword=" .. HttpService:UrlEncode(f.keyword or "") .. "&Limit=30&SortType=" .. sort
        if cursor then url = url .. "&cursor=" .. HttpService:UrlEncode(cursor) end
        if f.kind == "roblox" or f.kind == "limited" or onlyRoblox(f) then url = url .. "&CreatorName=Roblox" end
        if f.kind ~= "free" and f.minPrice then url = url .. "&MinPrice=" .. f.minPrice end
        if f.kind ~= "free" and f.maxPrice then url = url .. "&MaxPrice=" .. f.maxPrice end
        local data, status, message = Avatar.httpJson(url)
        if not data then data, status, message = Avatar.httpJson((string.gsub(url, "^https://catalog%.roblox%.com/v1/", "https://apis.roblox.com/catalog/v1/"))) end
        if not data then error("catalog request failed (" .. tostring(status) .. ") " .. tostring(message or ""), 0) end
        local wanted
        if #f.types > 0 then
            wanted = {}
            for _, name in ipairs(f.types) do wanted[name] = true end
        end
        local out = {}
        for _, raw in ipairs(data.data or {}) do
            local e = Avatar.normItem(raw)
            if e and (not wanted or not e.assetName or wanted[e.assetName]) and passes(f, e) then out[#out + 1] = e end
        end
        return out, data.nextPageCursor
    end

    local function engineSearch(append)
        local f = Catalog.F
        if not AvatarEditorService then error("no AvatarEditorService", 0) end
        if not append then
            local errs = {}
            for level = 1, 3 do
                local ok, res = pcall(function() return AvatarEditorService:SearchCatalogAsync(searchParams(f, level)) end)
                if ok then
                    Catalog.pages = res
                    break
                end
                errs[#errs + 1] = tostring(res)
            end
            if not Catalog.pages then error(table.concat(errs, " / "), 0) end
        elseif Catalog.pages then
            Catalog.pages:AdvanceToNextPageAsync()
        end
        local items = {}
        for _, raw in ipairs(Catalog.pages:GetCurrentPage()) do
            local e = Avatar.normItem(raw)
            if e and passes(f, e) then items[#items + 1] = e end
        end
        Catalog.finished = Catalog.pages.IsFinished == true
        return items
    end

    function Avatar.search(append, onDone)
        if append and (Catalog.busy or Catalog.finished) then return false end
        if not append then
            Catalog.gen = Catalog.gen + 1
            Catalog.pages, Catalog.cursor, Catalog.finished, Catalog.useWeb, Catalog.entries = nil, nil, false, false, {}
        end
        local gen = Catalog.gen
        Catalog.busy = true
        task.spawn(function()
            local items
            local okAll, err = pcall(function()
                local okEngine, result = false, nil
                if not Catalog.useWeb then okEngine, result = pcall(engineSearch, append) end
                if okEngine then
                    items = result
                    return
                end
                if not Catalog.useWeb then Catalog.useWeb, Catalog.engineErr = true, tostring(result) end
                if Catalog.webBlockedUntil and os.clock() < Catalog.webBlockedUntil then error("in-experience search is denied for this place", 0) end
                local okWeb, list, nextCursor = pcall(httpSearch, Catalog.F, append and Catalog.cursor or nil)
                if not okWeb then
                    if string.find(string.lower(tostring(list)), "denied", 1, true) then Catalog.webBlockedUntil = os.clock() + 60 end
                    error(tostring(list), 0)
                end
                items, Catalog.cursor, Catalog.finished = list, nextCursor, nextCursor == nil
            end)
            if gen ~= Catalog.gen then return end
            Catalog.busy, Catalog.error = false, (not okAll) and tostring(err) or nil
            if not okAll then
                Util.note("avatar search " .. tostring(err), "[aster] avatar: catalog search failed:", err)
                if onDone then onDone(nil, tostring(err)) end
                return
            end
            for _, e in ipairs(items) do Catalog.entries[#Catalog.entries + 1] = e end
            if onDone then onDone(items) end
        end)
        return true
    end

    local function itemDetails(id, kind)
        if not AvatarEditorService then return nil end
        local ok, info = pcall(function() return AvatarEditorService:GetItemDetails(id, Enum.AvatarItemType[kind]) end)
        return ok and type(info) == "table" and info or nil
    end

    function Avatar.typeOf(entry)
        if not entry.assetName then
            local info = itemDetails(entry.id, "Asset")
            if info then entry.assetName = assetTypeName(info.AssetType) end
        end
        return entry.assetName
    end

    function Avatar.playEmote(entry)
        local _, humanoid = localHumanoid()
        if not humanoid then return notify("avatar: no character yet", "warn") end
        if Avatar.emoteTrack then
            pcall(function() Avatar.emoteTrack:Stop() end)
            Avatar.emoteTrack = nil
            if Avatar.emoteId == entry.id then
                Avatar.emoteId = nil
                return notify("emote stopped")
            end
        end
        local ok, success, track = pcall(function() return humanoid:PlayEmoteAndGetAnimTrackById(entry.id) end)
        if ok and success and track then
            Avatar.emoteTrack, Avatar.emoteId = track, entry.id
            return notify("playing " .. entry.name)
        end
        notify("avatar: could not play " .. entry.name, "warn")
    end

    function Avatar.activate(entry)
        if not Builder.desc then return notify("avatar: the builder is still loading", "warn") end
        if entry.isBundle then
            local worn, details = 0, itemDetails(entry.id, "Bundle")
            for _, piece in ipairs(details and (details.BundledItems or details.bundledItems) or {}) do
                local pieceId = piece.Id or piece.id
                if assetTypeName(piece.Type or piece.type) == "Asset" and type(pieceId) == "number" then
                    local typeName = Avatar.typeOf({ id = pieceId })
                    if typeName and ACC_SLOTS[typeName] and pcall(Avatar.wearAsset, pieceId, typeName, true) then worn = worn + 1 end
                end
            end
            notify(string.format("avatar: wearing %d part(s) of %s", worn, entry.name))
            if worn > 0 then Avatar.changed() end
            return
        end
        local typeName = Avatar.typeOf(entry)
        if typeName == "EmoteAnimation" then return Avatar.playEmote(entry) end
        if not (typeName and ACC_SLOTS[typeName]) then return notify("avatar: " .. entry.name .. " is a type the builder can't wear", "warn") end
        local ok = Util.guard("avatar wear", Avatar.wearAsset, entry.id, typeName)
        if not ok then return notify("avatar: could not add that item", "warn") end
        Avatar.changed()
    end

    local function assembleModel(model)
        local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
        if not root then return end
        local done, joints = { [root] = true }, {}
        for _, inst in ipairs(model:GetDescendants()) do
            if inst:IsA("JointInstance") then joints[#joints + 1] = inst end
        end
        local progress, rounds = true, 0
        while progress and rounds < 40 do
            progress, rounds = false, rounds + 1
            for _, joint in ipairs(joints) do
                local p0, p1 = joint.Part0, joint.Part1
                if p0 and p1 and done[p0] and not done[p1] then
                    p1.CFrame = p0.CFrame * joint.C0 * joint.C1:Inverse()
                    done[p1], progress = true, true
                elseif p0 and p1 and done[p1] and not done[p0] then
                    p0.CFrame = p1.CFrame * joint.C1 * joint.C0:Inverse()
                    done[p0], progress = true, true
                end
            end
        end
    end

    -- ui ---------------------------------------------------------------------------------------------
    local PALETTE = {
        "#ffffff", "#e5e4df", "#a3a2a5", "#635f62", "#1b2a35", "#111111", "#f5cd30", "#fdea8d", "#da867a", "#c4281c", "#7b2e2f", "#694028",
        "#cda478", "#eab892", "#cc8e69", "#f0d5a0", "#7c5c46", "#5b402d", "#da8541", "#e29b40", "#ff98dc", "#e976c1", "#aa55ff", "#6225d1",
        "#0d69ac", "#2154b9", "#74869d", "#04afec", "#80bbdb", "#3d1585", "#287f47", "#4b974b", "#a1c48c", "#348e40", "#008f9c", "#12eed4",
    }
    local BODY_PARTS = { { "all parts" }, { "head", "HeadColor" }, { "torso", "TorsoColor" }, { "left arm", "LeftArmColor" }, { "right arm", "RightArmColor" }, { "left leg", "LeftLegColor" }, { "right leg", "RightLegColor" } }
    local PART_COLOR = { Head = "HeadColor", Torso = "TorsoColor", ["Left Arm"] = "LeftArmColor", ["Right Arm"] = "RightArmColor", ["Left Leg"] = "LeftLegColor", ["Right Leg"] = "RightLegColor" }
    local ui = { previews = {}, token = 0 }
    Avatar.ui = ui

    local function hex(s) return Color3.fromRGB(tonumber(string.sub(s, 2, 3), 16), tonumber(string.sub(s, 4, 5), 16), tonumber(string.sub(s, 6, 7), 16)) end
    local function idsIn(text)
        local out = {}
        for number in string.gmatch(tostring(text or ""), "%d+") do
            local value = tonumber(number)
            if value and value > 0 then out[#out + 1] = value end
        end
        return out
    end
    local function applyInfo(info)
        if not info then return notify("avatar: pick an avatar first", "warn") end
        if info.data then return task.spawn(Avatar.applyBuilt, Avatar.deserialize(info.data)) end
        if info.kind == "outfit" then return task.spawn(Avatar.applyOutfit, info.id) end
        task.spawn(Avatar.applyUser, tostring(info.uid))
    end
    local function editInfo(info)
        if not info then return notify("avatar: pick an avatar first", "warn") end
        task.spawn(function()
            if Avatar.edit(info) then pcall(function() win:Go(Pages.avatar.builder) end) end
        end)
    end
    local function applyBuilder()
        if not Builder.desc then return notify("avatar: the builder is still loading", "warn") end
        local ok, copy = pcall(function() return Builder.desc:Clone() end)
        task.spawn(Avatar.applyBuilt, ok and copy or Builder.desc)
    end

    function ui.boot()
        if ui.booted then return end
        ui.booted = true
        task.spawn(Avatar.loadMine)
        ui.runSearch(false)
    end

    -- the preview shows the real model built from the builder description; the parts dummy is the fallback when that fails
    local function render(p)
        p.stamp = Builder.stamp
        local stamp, desc = Builder.stamp, Builder.desc
        if not (p.dummy and desc) then return end
        for name, prop in pairs(PART_COLOR) do
            local part = p.dummy.Parts[name]
            local ok, color = pcall(function() return desc[prop] end)
            if part and ok and typeof(color) == "Color3" then part.Color = color end
        end
        task.delay(0.25, function()
            if p.stamp ~= stamp or Util.unloaded then return end
            local rig = Builder.rig == "R15" and Enum.HumanoidRigType.R15 or Enum.HumanoidRigType.R6
            local ok, model = pcall(function() return Players:CreateHumanoidModelFromDescription(desc:Clone(), rig) end)
            if p.stamp ~= stamp or Util.unloaded then
                if ok and model then pcall(function() model:Destroy() end) end
                return
            end
            if p.model then pcall(function() p.model:Destroy() end) end
            p.model = nil
            if not (ok and model) then
                p.dummy.Model.Parent = p.view.World
                return p.dummy:Fit(1.2)
            end
            pcall(assembleModel, model)
            for _, d in ipairs(model:GetDescendants()) do
                if d:IsA("BasePart") then
                    d.Anchored = true
                elseif d:IsA("LuaSourceContainer") or d:IsA("Sound") then
                    pcall(function() d:Destroy() end)
                end
            end
            p.dummy.Model.Parent = nil
            model.Parent = p.view.World
            p.model = model
            local okBox, cf, size = pcall(function() return model:GetBoundingBox() end)
            if okBox and cf and size then p.view:Fit({ center = cf.Position, reach = math.max(size.X, size.Y, size.Z) / 2, pad = 1.2 }) end
        end)
    end

    local function wornRows()
        local out = {}
        for _, w in ipairs(Avatar.wornItems()) do out[#out + 1] = { key = w.label .. w.id, name = w.label, sub = tostring(w.id), image = thumb("Asset", w.id), worn = w } end
        return out
    end
    local function takeOff(it)
        Util.guard("avatar remove", Avatar.removeItem, it.worn)
        Avatar.changed()
    end

    local function previewCard(page, id, full)
        local card = page:Card({ name = "preview", id = id, side = "right" })
        local p = { view = card:Preview({ kind = "avatar" }) }
        p.stat = card:Stat({ name = "Wearing", default = "loading..." })
        if full then
            card:Strip({ flag = "avatar_rig", items = { "R6", "R15" }, default = "R6", small = true, save = false })
            card:Toggle({ name = "Re-apply on respawn", flag = "avatar_respawn", default = true })
            local net = card:Section({ name = "network", key = "avatar.net" })
            net:Input({ flag = "avatar_proxy", placeholder = "proxy host, e.g. roproxy.com" })
        end
        p.worn = card:Tiles({ items = {}, mode = "list", empty = "nothing worn", click = takeOff })
        p.view.SetButtons({ { "Apply", applyBuilder }, { "Reset", Avatar.reset }, { "Mine", function() task.spawn(Avatar.loadMine) end } })
        if Scene then
            p.dummy = Scene.Dummy(p.view, { motion = "idle" })
            p.dummy:Fit(1.2)
            p.view:Orbit(true, 18)
            p.view:OnShow(function(on)
                if not on then return end
                ui.boot()
                if p.stamp ~= Builder.stamp then render(p) end
            end)
        end
        ui.previews[#ui.previews + 1] = p
        return p
    end

    -- builder: catalog / body / by id
    local builder = Pages.avatar.builder
    local card = builder:Card({ name = "avatar", id = "avb", side = "left" })
    local viewStrip = card:Strip({ flag = "avatar_view", items = { "catalog", "body", "by id" }, small = true, save = false })
    local views = {}
    local function view(name, el)
        views[name] = views[name] or {}
        table.insert(views[name], el)
        return el
    end

    local function catalogRows()
        local out = {}
        for _, e in ipairs(Catalog.entries) do
            local price = type(e.price) == "number" and (e.price == 0 and "free" or ("R$ " .. e.price)) or (e.isBundle and "bundle" or "off sale")
            out[#out + 1] = { key = e.id, name = e.name, sub = price .. (e.limited and " \194\183 limited" or ""), image = thumb(e.isBundle and "BundleThumbnail" or "Asset", e.id), entry = e }
        end
        return out
    end
    function ui.runSearch(append)
        if append and (Catalog.busy or Catalog.finished) then return false end
        ui.status:Set("searching...")
        return Avatar.search(append, function(_, err)
            if err then
                ui.status:Set("search failed")
                return notify("avatar: catalog search failed: " .. string.sub(err, 1, 120), "warn")
            end
            ui.catalog:SetItems(catalogRows())
            ui.status:Set(#Catalog.entries .. " items" .. (Catalog.finished and "" or ", more available"))
        end)
    end
    local function filters()
        Avatar.setFilters({ keyword = F("avatar_q") or "", category = F("avatar_cat"), sort = F("avatar_sort"), kind = F("avatar_kind"), onSale = F("avatar_sale"), price = F("avatar_price") or "" })
        if ui.booted then ui.runSearch(false) end
    end
    view("catalog", card:Input({ flag = "avatar_q", placeholder = "search the catalog, press enter", save = false, enter = filters }))
    view("catalog", card:Dropdown({ name = "Category", flag = "avatar_cat", options = CATEGORY_NAMES, default = "all", save = false }))
    view("catalog", card:Dropdown({ name = "Sort", flag = "avatar_sort", options = SORT_NAMES, default = "relevance", save = false }))
    view("catalog", card:Dropdown({ name = "Kind", flag = "avatar_kind", options = KIND_NAMES, default = "any", save = false }))
    view("catalog", card:Input({ flag = "avatar_price", placeholder = "price range, e.g. 10-200, press enter", save = false, enter = filters }))
    view("catalog", card:Toggle({ name = "On sale only", flag = "avatar_sale", save = false }))
    ui.status = view("catalog", card:Stat({ name = "Results", default = "-" }))
    ui.catalog = view("catalog", card:Tiles({ items = {}, empty = "no items", click = function(it) Avatar.activate(it.entry) end, isOn = function(it) return Avatar.isWorn(it.key) end }))
    ui.more = view("catalog", card:Buttons({ items = {
        { name = "Load more", callback = function() ui.runSearch(true) end },
        { name = "List view", callback = function()
            local list = ui.catalog:Mode() ~= "list"
            ui.catalog:SetMode(list and "list" or "grid")
            ui.more:SetText(2, list and "Grid view" or "List view")
        end },
    } }))
    Util.changed({ "avatar_cat", "avatar_sort", "avatar_kind", "avatar_sale" }, filters)

    local partNames = {}
    for index, entry in ipairs(BODY_PARTS) do partNames[index] = entry[1] end
    local function partProp()
        for _, entry in ipairs(BODY_PARTS) do
            if entry[1] == F("avatar_part") then return entry[2] end
        end
        return nil
    end
    local swatches = {}
    for index, h in ipairs(PALETTE) do swatches[index] = { key = h, name = h, color = hex(h) } end
    view("body", card:Dropdown({ name = "Part", flag = "avatar_part", options = partNames, default = "all parts", save = false }))
    view("body", card:Tiles({ items = swatches, click = function(it) Avatar.setColor(partProp(), it.color) end }))
    view("body", card:Color({ name = "Custom colour", flag = "avatar_color", default = "#f5cd30", opaque = true, save = false, callback = function(c) Avatar.setColor(partProp(), c) end }))
    view("body", card:Button({ name = "Reset colours", callback = Avatar.resetColors }))

    local function wearIds(on)
        local ids, count = idsIn(F("avatar_ids")), 0
        if #ids == 0 then return notify("avatar: type one or more asset ids", "warn") end
        if not Builder.desc then return notify("avatar: the builder is still loading", "warn") end
        for _, id in ipairs(ids) do
            if on then
                local typeName = Avatar.typeOf({ id = id })
                if typeName and ACC_SLOTS[typeName] and Util.guard("avatar wear", Avatar.wearAsset, id, typeName, true) then count = count + 1 end
            else
                for _, w in ipairs(Avatar.wornItems()) do
                    if w.id == id then
                        Avatar.removeItem(w)
                        count = count + 1
                    end
                end
            end
        end
        notify(string.format("avatar: %s %d of %d", on and "wearing" or "took off", count, #ids), count > 0 and "ok" or "warn")
        if count > 0 then Avatar.changed() end
    end
    view("by id", card:Input({ flag = "avatar_ids", placeholder = "asset ids, comma separated", save = false, enter = function() task.spawn(wearIds, true) end }))
    view("by id", card:Buttons({ items = {
        { name = "Wear", primary = true, callback = function() task.spawn(wearIds, true) end },
        { name = "Take off", callback = function() wearIds(false) end },
        { name = "Clear all", callback = function()
            for _, w in ipairs(Avatar.wornItems()) do Avatar.removeItem(w) end
            Avatar.changed()
        end },
    } }))
    ui.views = views
    function ui.showView(name)
        for key, list in pairs(views) do
            for _, el in ipairs(list) do el:SetVisible(key == name) end
        end
    end
    viewStrip:OnChanged(ui.showView)
    ui.showView(viewStrip.Value or "catalog")
    previewCard(builder, "avbp", true)
    Util.changed("avatar_rig", function(_, value)
        Builder.rig = value == "R15" and "R15" or "R6"
        Avatar.changed()
    end)

    -- outfits
    local outfits = Pages.avatar.outfits
    local oc = outfits:Card({ name = "outfits", id = "avo", side = "left" })
    local function outfitRows()
        local out = {}
        for index, o in ipairs(store.outfits) do
            local data = o.data or {}
            local n = #(data.acc or {})
            for _ in pairs(data.props or {}) do n = n + 1 end
            out[#out + 1] = { key = tostring(index), text = tostring(o.name), meta = tostring(o.rig or "R6") .. " \194\183 " .. n .. " items" }
        end
        return out
    end
    local function picked()
        return store.outfits[tonumber(F("avatar_outfit") or "") or 0]
    end
    local function refreshOutfits() ui.outfits:SetItems(outfitRows()) end
    local function deleteOutfit()
        local o = picked()
        if not o then return notify("avatar: pick an outfit first", "warn") end
        table.remove(store.outfits, tonumber(F("avatar_outfit")))
        Avatar.save()
        refreshOutfits()
        notify("avatar: deleted " .. tostring(o.name))
    end
    ui.outfits = oc:List({ flag = "avatar_outfit", items = outfitRows(), rows = 8, empty = "no saved outfits", save = false,
        callback = function()
            local o = picked()
            if o then Avatar.edit({ data = o.data, name = o.name }) end
        end,
        activate = function()
            local o = picked()
            if o then applyInfo({ data = o.data }) end
        end,
        menu = function(key)
            return {
                { text = "apply", callback = function() applyInfo({ data = picked().data }) end },
                { text = "rename", callback = function()
                    ui.outfits:Edit(key, function(text)
                        local o = store.outfits[tonumber(key)]
                        if o and text ~= "" then o.name = text end
                        Avatar.save()
                        refreshOutfits()
                    end)
                end },
                { text = "delete", callback = deleteOutfit },
            }
        end })
    oc:Input({ flag = "avatar_oname", placeholder = "outfit name", save = false })
    oc:Buttons({ items = {
        { name = "Save current", primary = true, callback = function()
            if Avatar.saveOutfit(F("avatar_oname") or "") then
                Aster:Set("avatar_oname", "", true)
                refreshOutfits()
            end
        end },
        { name = "Apply", callback = function()
            local o = picked()
            if not o then return notify("avatar: pick an outfit first", "warn") end
            applyInfo({ data = o.data })
        end },
        { name = "Delete", callback = deleteOutfit },
    } })
    previewCard(outfits, "avop", false)

    -- players + favorites: a click selects, a second click on the selected tile applies it
    local function selector(key)
        return function(it)
            if ui[key] == it.key then return applyInfo(it.info) end
            ui[key], ui[key .. "Info"] = it.key, it.info
        end
    end
    local function personRow(info)
        local image = info.kind == "outfit" and thumb("Outfit", info.id) or thumb("Avatar", info.uid)
        return { key = (info.kind == "outfit" and "o" .. tostring(info.id)) or ("u" .. tostring(info.uid)), name = tostring(info.name), sub = info.kind == "outfit" and "outfit" or "current avatar", image = image, info = info }
    end
    local function favRows()
        local out = {}
        for _, e in ipairs(store.favorites) do out[#out + 1] = personRow({ kind = e.kind, id = e.id, uid = e.uid, name = e.name or "?" }) end
        return out
    end
    local function recentRows()
        local out = {}
        for _, e in ipairs(store.recent) do out[#out + 1] = { key = tostring(e.uid), text = tostring(e.name), meta = tostring(e.uid) } end
        return out
    end
    local function star(it)
        local on = Avatar.toggleFavorite(it.info)
        notify(on and ("avatar: starred " .. tostring(it.info.name)) or ("avatar: unstarred " .. tostring(it.info.name)))
        ui.favorites:SetItems(favRows())
        ui.people:Refresh()
    end
    local isFav = function(it) return Avatar.favoriteIndex(it.info) ~= nil end

    local players = Pages.avatar.players
    local lc = players:Card({ name = "lookup", id = "avl", side = "left" })
    lc:Input({ flag = "spoof_avatar_user", placeholder = "user id, username or profile url", enter = function(v) ui.lookup(v) end })
    lc:Buttons({ items = {
        { name = "Look up", primary = true, callback = function() ui.lookup(F("spoof_avatar_user") or "") end },
        { name = "Me", callback = function() ui.loadTarget(LocalPlayer.UserId, LocalPlayer.Name) end },
    } })
    ui.lookStat = lc:Stat({ name = "Outfits", default = "-" })
    ui.people = lc:Tiles({ items = {}, empty = "look someone up", click = selector("sel"), fav = star, isFav = isFav, isOn = function(it) return ui.sel == it.key end })
    lc:Buttons({ items = {
        { name = "Apply", primary = true, callback = function() applyInfo(ui.selInfo) end },
        { name = "Edit in builder", callback = function() editInfo(ui.selInfo) end },
    } })
    local recent = lc:Section({ name = "recent", key = "avatar.recent", open = true })
    ui.recent = recent:List({ items = recentRows(), rows = 5, empty = "nobody yet", save = false,
        activate = function(key, row) ui.loadTarget(tonumber(key), row.text) end,
        menu = function(key, row)
            return {
                { text = "look up", callback = function() ui.loadTarget(tonumber(key), row.text) end },
                { text = "forget", callback = function()
                    Avatar.recordRecent(tonumber(key), nil, true)
                    ui.recent:SetItems(recentRows())
                end },
            }
        end })

    local fc = players:Card({ name = "favorites", id = "avf", side = "right" })
    ui.favorites = fc:Tiles({ items = favRows(), empty = "star a player or outfit to keep it here", click = selector("fav"), fav = star, isFav = isFav, isOn = function(it) return ui.fav == it.key end })
    fc:Buttons({ items = {
        { name = "Apply", primary = true, callback = function() applyInfo(ui.favInfo) end },
        { name = "Edit in builder", callback = function() editInfo(ui.favInfo) end },
        { name = "Remove", callback = function()
            if not ui.favInfo then return notify("avatar: pick a favourite first", "warn") end
            Avatar.toggleFavorite(ui.favInfo)
            ui.fav, ui.favInfo = nil, nil
            ui.favorites:SetItems(favRows())
            ui.people:Refresh()
        end },
    } })

    function ui.loadTarget(uid, name)
        if not uid then return end
        ui.token = ui.token + 1
        local token = ui.token
        ui.sel, ui.selInfo = nil, nil
        if uid ~= LocalPlayer.UserId then
            Avatar.recordRecent(uid, name)
            ui.recent:SetItems(recentRows())
        end
        local rows = { personRow({ kind = "user", uid = uid, name = name }) }
        ui.people:SetItems(rows)
        ui.lookStat:Set("loading...")
        task.spawn(function()
            local alive = function() return ui.token == token and not Util.unloaded end
            local list, state = Avatar.fetchOutfits(uid, function(fresh, total)
                if not alive() then return end
                for _, o in ipairs(fresh) do rows[#rows + 1] = personRow({ kind = "outfit", id = o.id, name = o.name }) end
                ui.people:SetItems(rows)
                ui.lookStat:Set(total .. " loaded...")
            end, alive)
            if alive() then ui.lookStat:Set(list and (#list .. " \194\183 " .. state) or state) end
        end)
    end

    function ui.lookup(value)
        value = tostring(value or "")
        local outfitId = tonumber(string.match(value, "[Oo]utfits?[:%s/=]*(%d+)"))
        if outfitId then
            local row = personRow({ kind = "outfit", id = outfitId, name = "outfit " .. outfitId })
            ui.people:SetItems({ row })
            ui.sel, ui.selInfo = row.key, row.info
            return ui.people:Refresh()
        end
        task.spawn(function()
            local uid = Avatar.resolveUserId(value)
            if not uid then return notify("avatar: could not find " .. value, "warn") end
            local okName, real = pcall(function() return Players:GetNameFromUserIdAsync(uid) end)
            ui.loadTarget(uid, (okName and type(real) == "string" and real ~= "") and real or value)
        end)
    end
    ui.people.Shown:Connect(function(on)
        if on and not ui.peopleBooted then
            ui.peopleBooted = true
            ui.loadTarget(LocalPlayer.UserId, LocalPlayer.Name)
        end
    end)

    table.insert(Avatar.listeners, function()
        local rows = wornRows()
        for _, p in ipairs(ui.previews) do
            p.worn:SetItems(rows)
            p.stat:Set(#rows > 0 and (#rows .. " items \194\183 " .. Builder.rig) or "nothing")
            if p.view.IsShown and p.view:IsShown() then render(p) end
        end
        ui.catalog:Refresh()
    end)

    local function respawned(char)
        if Original and Original.char ~= char then Original = nil end
        if F("avatar_respawn") == false or not (Avatar.lastUid or Avatar.lastOutfit or Avatar.lastBuilt) then return end
        task.delay(1.25, function()
            if Util.unloaded or F("avatar_respawn") == false or LocalPlayer.Character ~= char then return end
            if Avatar.lastBuilt then
                local ok, copy = pcall(function() return Avatar.lastBuilt:Clone() end)
                Avatar.applyBuilt(ok and copy or Avatar.lastBuilt)
            elseif Avatar.lastOutfit then
                Avatar.applyOutfit(Avatar.lastOutfit)
            elseif Avatar.lastUid then
                Avatar.applyUser(tostring(Avatar.lastUid))
            end
        end)
    end
    if Game and Game.events and Game.events.onRespawn then
        Game.events.onRespawn:Connect(respawned)
    else
        Util.track(LocalPlayer.CharacterAdded:Connect(respawned))
    end

    Util.onUnload(function()
        Avatar.lastUid, Avatar.lastOutfit, Avatar.lastBuilt = nil, nil, nil
        if Avatar.emoteTrack then pcall(function() Avatar.emoteTrack:Stop() end) end
        Avatar.restore()
        for _, entry in pairs(modelCache) do pcall(function() entry.model:Destroy() end) end
        modelCache, cacheOrder, Avatar.listeners = {}, {}, {}
        Catalog.gen = Catalog.gen + 1
        for _, p in ipairs(ui.previews) do
            p.stamp = -1
            if p.model then pcall(function() p.model:Destroy() end) end
        end
        Avatar.ui = nil
    end)
end
bootMark("avatar", PL2BootT, 12, 13)

PL2BootT = PL2BootClock()
-- [src] 99_tail.lua
do
    -- dev.lua's combat block, unchanged, on the compat shim; if it fails the rest of the script keeps working
    Util.stage("combat", 0.84)
    local started = clock()
    local ok, err = pcall(Combat_init, Compat.legacy)
    Boot.marks[#Boot.marks + 1] = { "combat init", (clock() - started) * 1000 }
    if not ok then
        Util.note("combat", "combat failed to load:", err)
        Util.notify("combat failed to load, the rest keeps working: " .. string.sub(tostring(err), 1, 160), "warn", 8)
    end

    Util.stage("building settings", 0.88)
    local players = {}
    if Avatar and type(Avatar.copy) == "function" then players.copyAvatar = Avatar.copy end
    Pages.settings = win:Builtins({
        players = players,
        onPanic = function()
            for flag, value in pairs(Aster.Flags) do
                local element = Aster.Elements[flag]
                if value == true and element and element.Kind == "toggle" and not string.find(flag, "^hud%.") then Aster:Set(flag, false) end
            end
        end,
    })
    Pages.tabs.settings = Pages.settings.Tab
    if ThemeManager then ThemeManager:ApplyToTab(Pages.settings.Tab) end
    if SaveManager then SaveManager:BuildConfigSection(Pages.settings.Tab) end

    env.AsterPL2 = {
        Aster = Aster, Window = win, ThemeManager = ThemeManager, SaveManager = SaveManager, Util = Util, Loop = Loop, Pages = Pages, Game = Game, Entities = Entities, Data = Data, Boot = Boot, Compat = Compat,
        Draw = Draw, Visible = Visible, Esp = Esp, World = World, Fx = Fx, Combat = Combat, Player = Player, Map = Map, Avatar = Avatar,
        unload = function() Aster:Unload() end,
    }

    loader:Done()
    local lib = Boot.timings["library.lua"] or {}
    local parts = {}
    for _, mark in ipairs(Boot.marks) do parts[#parts + 1] = mark[1] .. " " .. math.floor(mark[2] + 0.5) end
    print("[aster pl] " .. BUILD .. " boot " .. ms(Boot.at) .. "ms: library download " .. tostring(lib.download) .. " compile " .. tostring(lib.compile)
        .. " run " .. tostring(lib.run) .. ", addons " .. tostring(Boot.addons) .. ", parts " .. table.concat(parts, ", "))
    if SaveManager then SaveManager:LoadAutoloadConfig() end
    for _, path in ipairs(Boot.missing) do Util.notify("could not load " .. path .. ", continuing without it", "warn") end
    Util.notify("loaded, press insert to toggle the menu", "ok")
end
bootMark("tail", PL2BootT, 13, 13)
