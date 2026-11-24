-- aster v2 example: every widget, the built-in settings pages and the engine previews (Aster.Scene)
-- Set getgenv().ASTER2_LOCAL to a loaded library table, a Lua source string or a file path to skip the download.
local URL = "https://raw.githubusercontent.com/WhyWKey/linoria/main/ui-test/Library.lua"
local env = (getgenv and getgenv()) or _G
local compile = loadstring or load

local function fromSource(src)
    if type(src) ~= "string" or #src < 64 then error("bad download: " .. tostring(src), 0) end
    local fn, err = compile(src, "=aster2")
    if not fn then error("compile failed: " .. tostring(err), 0) end
    return fn()
end

local function loadAster()
    local loc = rawget(env, "ASTER2_LOCAL")
    if type(loc) == "table" then return loc end
    if type(loc) == "string" then
        if string.find(loc, "\n", 1, true) then return fromSource(loc) end
        if readfile and isfile and isfile(loc) then return fromSource(readfile(loc)) end
    end
    local ok, lib = pcall(function()
        local got, body = pcall(function() return game:HttpGet(URL) end)
        if got and type(body) == "string" and #body >= 64 then return fromSource(body) end
        local req = request or http_request or (syn and syn.request) or (http and http.request)
        if not req then return fromSource(body) end
        local sent, reply = pcall(req, { Url = URL, Method = "GET" })
        if sent and type(reply) == "table" and type(reply.Body) == "string" then return fromSource(reply.Body) end
        error("HttpGet failed (" .. tostring(body) .. "), request failed (" .. tostring(type(reply) == "table" and reply.StatusCode or reply) .. ")", 0)
    end)
    if ok and lib then return lib end
    if readfile and isfile and isfile("aster2/Library.lua") then return fromSource(readfile("aster2/Library.lua")) end
    error("[aster example] could not load Library.lua: " .. tostring(lib))
end

local Aster = loadAster()
local Scene = Aster.Scene
local Players = game:GetService("Players")
local me = Players.LocalPlayer
local gameName = "Prison Life"
pcall(function() gameName = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name end)

local loader = Aster:Loader({ title = "aster", game = gameName, build = "b2211" })
loader:Stage("loading library", 0.25)

local function F(flag) return Aster.Flags[flag] end
local function alpha(flag)
    local el = Aster.Elements[flag]
    return el and el.Alpha and el:Alpha() or 1
end
local function notify(src, text, kind) Aster:Notify(src, text, kind) end
local function cap(s) return (string.gsub(s, "^%l", string.upper)) end
local function has(list, v)
    for _, x in ipairs(list or {}) do if x == v then return true end end
    return false
end

-- a feature row the way the mock-up builds one: toggle, then (right to left) gear, key chip and swatches
local function row(c, name, flag, o)
    o = o or {}
    local t = c:Toggle({ name = name, flag = flag, default = o.def == true, depends = o.dep, hud = o.hud, tip = o.tip })
    local gear
    if o.gear then gear = t:Settings({ title = o.gear }) end
    if o.key then t:Keybind({ flag = flag .. ".key", default = o.key ~= true and o.key or nil, mode = o.mode }) end
    local sw = o.sw or {}
    for i = #sw, 1, -1 do t:Color({ flag = flag .. ".c" .. (i - 1), default = sw[i] }) end
    return t, gear
end

-- refresh fn(flag) whenever a flag with one of the prefixes changes (configs loads included)
local function follow(prefixes, fn)
    return Aster.Changed:Connect(function(flag)
        if type(flag) ~= "string" then return end
        for _, p in ipairs(prefixes) do
            if string.sub(flag, 1, #p) == p then return fn(flag) end
        end
    end)
end

loader:Stage("building menu", 0.5)
local win = Aster:Window({
    title = "aster", folder = "example", key = "insert", game = gameName,
    user = { id = me and me.UserId or 0, display = me and me.DisplayName or "", name = me and me.Name or "" },
})

-- combat ----------------------------------------------------------------------------------------
local CLASSES = { "pistols", "smgs", "rifles", "snipers", "shotguns", "heavy" }
local PARTS = { "head", "neck", "upper torso", "lower torso", "arms", "legs" }
local combat = win:Tab({ name = "combat", icon = "combat" })

local legit = combat:Page({ name = "legit" })
local legitStrip = legit:Strip({ flag = "aim.cls", items = (function()
    local out = {}
    for _, k in ipairs(CLASSES) do out[#out + 1] = { k = k, icon = k } end
    return out
end)(), default = "rifles" })
legit:Variants(legitStrip, function(cls, page)
    local c = "aim." .. cls .. "."
    local target = page:Card({ name = "targeting", id = "target", side = "left" })
    local on = row(target, "Enabled", c .. "on", { def = true, sw = { "#c9a96e" }, key = "m2", mode = "hold", hud = "Aimbot" })
    row(target, "Silent aim", c .. "silent", { dep = c .. "on" })
    row(target, "Visible only", c .. "vis", { def = true, dep = c .. "on" })
    target:Dropdown({ name = "Target part", flag = c .. "part", options = { "head", "neck", "upper torso", "lower torso", "nearest" }, default = "head" })
    target:Dropdown({ name = "Hitboxes", flag = c .. "hb", options = PARTS, default = { "head", "upper torso" }, multi = true })
    local prio = target:Section({ name = "priority", key = "aim.prio", open = true })
    prio:Dropdown({ name = "Priority", flag = c .. "prio", options = { "crosshair", "distance", "health", "threat" }, default = "crosshair" })
    prio:Slider({ name = "Max distance", flag = c .. "maxd", min = 50, max = 1500, step = 10, default = 600, fmt = function(v) return v .. " studs" end })
    row(prio, "Sticky target", c .. "sticky", { def = true })

    local fov = page:Card({ name = "field of view", id = "fov", side = "right" })
    row(fov, "Draw fov circle", c .. "fovd", { def = true, sw = { "#e8e4dc" } })
    fov:Slider({ name = "Radius", flag = c .. "fov", min = 10, max = 400, default = 120, fmt = function(v) return v .. " px" end })
    fov:Slider({ name = "Smoothing", flag = c .. "smooth", min = 1, max = 20, step = 0.5, default = 6.5 })
    local hum = fov:Section({ name = "humanize", key = "aim.hum" })
    row(hum, "Jitter", c .. "jit")
    hum:Slider({ name = "Jitter amount", flag = c .. "jita", min = 0, max = 10, step = 0.5, default = 2.5, depends = c .. "jit" })
    row(hum, "Curved path", c .. "curve", { def = true })
    hum:Slider({ name = "Reaction time", flag = c .. "react", min = 0, max = 400, step = 5, default = 90, fmt = function(v) return v .. " ms" end })

    local fire = page:Card({ name = "fire", side = "right" })
    row(fire, "Auto fire", c .. "af", { key = true, sw = { "#ef6a6a" } })
    fire:Slider({ name = "Shot delay", flag = c .. "afd", min = 0, max = 300, default = 40, depends = c .. "af", fmt = function(v) return v .. " ms" end })
    local cond = fire:Section({ name = "conditions", key = "aim.cond" })
    row(cond, "Only when scoped", c .. "scope", { def = cls == "snipers" })
    row(cond, "Not while flashed", c .. "flash", { def = true })
    row(cond, "Not while airborne", c .. "jump")
    return on
end)

local rage = combat:Page({ name = "rage" })
local rageStrip = rage:Strip({ flag = "rage.cls", items = CLASSES, default = "rifles" })
rage:Variants(rageStrip, function(cls, page)
    local c = "rage." .. cls .. "."
    local sel = page:Card({ name = "target selection", id = "rtarget", side = "left" })
    row(sel, "Enabled", c .. "on", { def = true, sw = { "#ef6a6a" }, key = true, hud = "Ragebot" })
    sel:Dropdown({ name = "Target selection", flag = c .. "sel", options = { "crosshair", "distance", "lowest health", "highest damage", "cycle" }, default = "highest damage", depends = c .. "on" })
    sel:Dropdown({ name = "Hitboxes", flag = c .. "hb", options = PARTS, default = { "head", "upper torso", "lower torso" }, multi = true, depends = c .. "on" })
    row(sel, "Prefer body aim", c .. "baim", { key = true, mode = "hold" })
    sel:Dropdown({ name = "Body aim when", flag = c .. "baimw", options = { "lethal", "in air", "high inaccuracy", "always" }, default = { "lethal" }, multi = true, depends = c .. "baim" })
    local acc = page:Card({ name = "accuracy", id = "racc", side = "right" })
    acc:Slider({ name = "Hit chance", flag = c .. "hc", min = 0, max = 100, default = 60, fmt = function(v) return v .. "%" end })
    acc:Slider({ name = "Min damage", flag = c .. "md", min = 1, max = 120, default = 40 })
    row(acc, "Auto scope", c .. "ascope", { def = cls == "snipers" })
    row(acc, "Auto stop", c .. "astop", { def = true })
end)

-- visuals / esp ---------------------------------------------------------------------------------
local visuals = win:Tab({ name = "visuals", icon = "visuals" })
local espPage = visuals:Page({ name = "esp" })
local espCard = espPage:Card({ name = "esp", side = "left" })
local FLAGS = { "armored", "scoped", "reloading", "has keycard" }
local FLAGC = { armored = "#c6c6cf", scoped = "#4ec3e0", reloading = "#e8b04a", ["has keycard"] = "#c9a96e" }
local pct = function(v) return v .. "%" end
local px = function(v) return v .. " px" end

local _, g = row(espCard, "Box", "esp.box", { def = true, sw = { "#ffffff" }, gear = "box" })
g:Dropdown({ name = "Style", flag = "esp.boxs", options = { "full", "corners" }, default = "full" })
g:Slider({ name = "Thickness", flag = "esp.boxt", min = 1, max = 3, default = 1, fmt = px })
row(g, "Outline", "esp.boxo", { def = true })
row(g, "Fill", "esp.boxf", { sw = { "#ffffff" } })
g:Slider({ name = "Fill opacity", flag = "esp.boxfa", min = 0, max = 100, default = 15, depends = "esp.boxf", fmt = pct })

_, g = row(espCard, "Health bar", "esp.hp", { def = true, sw = { "#ff3c3c", "#ffc83c", "#78e03c" }, gear = "health" })
g:Dropdown({ name = "Side", flag = "esp.hps", options = { "left", "right" }, default = "left" })
g:Dropdown({ name = "Mode", flag = "esp.hpm", options = { "gradient", "solid" }, default = "gradient" })
row(g, "Show number", "esp.hpn", { def = true })
g:Slider({ name = "Bar width", flag = "esp.hpw", min = 1, max = 4, default = 2, fmt = px })

_, g = row(espCard, "Name", "esp.name", { def = true, sw = { "#ffffff" }, gear = "name" })
g:Dropdown({ name = "Shows", flag = "esp.namet", options = { "display name", "username" }, default = "display name" })
g:Slider({ name = "Size", flag = "esp.namez", min = 8, max = 14, default = 11, fmt = px })
row(g, "Outline", "esp.nameo", { def = true })

_, g = row(espCard, "Skeleton", "esp.skel", { sw = { "#e8e4dc" }, gear = "skeleton" })
g:Slider({ name = "Thickness", flag = "esp.skelt", min = 1, max = 3, default = 1, fmt = px })
row(g, "Outline", "esp.skelo", { def = true })
row(g, "Joints", "esp.skelj")

_, g = row(espCard, "Weapon", "esp.wpn", { def = true, sw = { "#ffffff" }, gear = "weapon" })
g:Dropdown({ name = "Show as", flag = "esp.wpnm", options = { "text", "icon" }, default = "text" })
g:Dropdown({ name = "Case", flag = "esp.wpnc", options = { "upper", "lower", "normal" }, default = "upper" })

_, g = row(espCard, "Distance", "esp.dist", { sw = { "#c6c6cf" }, gear = "distance" })
g:Dropdown({ name = "Unit", flag = "esp.distu", options = { "studs", "meters" }, default = "studs" })

_, g = row(espCard, "Flags", "esp.flags", { gear = "flags" })
g:Dropdown({ name = "Shown flags", flag = "esp.fl", options = FLAGS, default = { "armored", "reloading" }, multi = true })
row(g, "Colour per flag", "esp.flpc", { def = true })
g:Color({ name = "Single colour", flag = "esp.flags.c0", default = "#c6c6cf" })

-- chams are Classic only: a visible and an occluded layer, switched by the preview wall
_, g = row(espCard, "Chams", "ch.on", { key = true, gear = "chams" })
g:Color({ name = "Visible colour", flag = "ch.vis", default = "#c9a96e80" })
row(g, "Through walls", "ch.xq", { def = true })
g:Color({ name = "Occluded colour", flag = "ch.occ", default = "#8f9bf0aa", depends = "ch.xq" })
row(g, "Round head", "ch.round", { def = true })
g:Slider({ name = "Grow", flag = "ch.grow", min = 0, max = 0.3, step = 0.01, default = 0.1, fmt = function(v) return string.format("%.2f studs", v) end })

local espSide = espPage:Card({ name = "preview", id = "esps", side = "right" })
local espHp = 62
local espView = espSide:Preview({ kind = "esp" })
espSide:Slider({ name = "Max distance", flag = "esp.max", min = 50, max = 2000, step = 10, default = 800, fmt = function(v) return v .. " studs" end })

local function weaponText()
    local w = "AK-47"
    local case = F("esp.wpnc")
    if case == "upper" then w = string.upper(w) elseif case == "lower" then w = string.lower(w) end
    return w
end
local function espCfg()
    local flags = {}
    if F("esp.flags") then for _, f in ipairs(F("esp.fl") or {}) do flags[#flags + 1] = f end end
    return {
        box = F("esp.box") and (F("esp.boxs") == "corners" and "corner" or "full") or false,
        boxColor = F("esp.box.c0"), outline = F("esp.boxo"), fill = F("esp.boxf"), fillColor = F("esp.boxf.c0"), fillAlpha = (F("esp.boxfa") or 15) / 100,
        health = F("esp.hp"), hp = espHp, maxHp = 100, healthMode = F("esp.hpm"),
        low = F("esp.hp.c0"), mid = F("esp.hp.c1"), high = F("esp.hp.c2"), healthNumber = F("esp.hpn"),
        name = F("esp.name") and (F("esp.namet") == "username" and "user" or "display") or false, nameColor = F("esp.name.c0"),
        display = me and me.DisplayName, user = me and me.Name,
        skeleton = F("esp.skel"), skeletonColor = F("esp.skel.c0"),
        weapon = F("esp.wpn") and weaponText() or false, weaponColor = F("esp.wpn.c0"),
        distance = F("esp.dist"), distanceColor = F("esp.dist.c0"), flags = flags,
        flagColors = F("esp.flpc") and FLAGC or nil, flagColor = F("esp.flags.c0"),
        boxThickness = F("esp.boxt"), healthSide = F("esp.hps"), barWidth = F("esp.hpw"), nameSize = F("esp.namez"), nameOutline = F("esp.nameo"),
        skeletonThickness = F("esp.skelt"), skeletonOutline = F("esp.skelo"), joints = F("esp.skelj"), weaponMode = F("esp.wpnm"), distanceUnit = F("esp.distu"),
    }
end
local function chamsCfg(wall)
    return {
        enabled = F("ch.on"), walls = F("ch.xq"), round = F("ch.round"), grow = F("ch.grow"),
        visColor = F("ch.vis"), visAlpha = alpha("ch.vis"), occColor = F("ch.occ"), occAlpha = alpha("ch.occ"), wall = wall,
    }
end

local espScene = {}
if Scene then
    local dummy = Scene.Dummy(espView, { motion = "walk", walk = { from = -5, to = 5, speed = 4 } })
    local wall = Scene.Wall(espView, {})
    espScene.dummy, espScene.wall = dummy, wall
    espScene.chams = Scene.Chams(espView, dummy.Model, chamsCfg(wall))
    espScene.esp = Scene.Esp(espView, dummy.Model, espCfg())
    espView:Fit()
    espView.Maid:Add(follow({ "esp.", "ch." }, function()
        espScene.esp:Set(espCfg())
        espScene.chams:Set(chamsCfg(wall))
    end))
end
espView.SetButtons({
    { "Damage", function()
        espHp = math.max(5, espHp - 25)
        if espScene.esp then espScene.esp:Set({ hp = espHp }) end
    end },
    { "Heal", function()
        espHp = 100
        if espScene.esp then espScene.esp:Set({ hp = espHp }) end
    end },
})

-- visuals / world + indicators ------------------------------------------------------------------
local world = visuals:Page({ name = "world" })
local light = world:Card({ name = "world", id = "light", side = "left" })
row(light, "Fullbright", "w.full", { key = true })
row(light, "Custom fog", "w.fog")
light:Slider({ name = "Fog end", flag = "w.fogd", min = 50, max = 3000, step = 25, default = 900, depends = "w.fog", fmt = function(v) return v .. " studs" end })
light:Color({ name = "Fog colour", flag = "w.fogc", default = "#202028", depends = "w.fog" })
local rem = world:Card({ name = "removals", id = "rem", side = "right" })
rem:Dropdown({ name = "Remove", flag = "w.rem", options = { "shadows", "grass", "post effects", "bloom", "blur" }, default = { "post effects", "blur" }, multi = true })
row(rem, "Field of view override", "w.fp")
rem:Slider({ name = "Camera fov", flag = "w.fov", min = 60, max = 120, default = 90, depends = "w.fp", fmt = function(v) return v .. "\194\176" end })

local Hud = Aster.Hud
local ind = visuals:Page({ name = "indicators" })
local indc = ind:Card({ name = "indicators", id = "ind", side = "left" })
row(indc, "Off-screen arrows", "ind.arrows", { sw = { "#c9a96e" } })
indc:Slider({ name = "Arrow distance", flag = "ind.ard", min = 20, max = 200, default = 80, depends = "ind.arrows", fmt = px })
row(indc, "Feature indicators", "ind.state", { def = true })
row(indc, "Velocity graph", "ind.vel")
local hitLink = ind:Card({ name = "hit markers", id = "hit", side = "right" })
local thud = ind:Card({ name = "target hud", id = "thud", side = "left" })
thud:Toggle({ name = "Enabled", flag = "tg.on", default = true, callback = function(v) Hud.Target:SetEnabled(v) end })
thud:Dropdown({ name = "Position", flag = "tg.pos", options = { "below crosshair", "bottom centre", "custom" }, default = "below crosshair", depends = "tg.on",
    callback = function(v) Hud.Target:SetPosition(v) end })
for _, o in ipairs({ { "tg.hs", "Show headshot", "headshot" }, { "tg.wpn", "Show weapon", "weapon" }, { "tg.dist", "Show distance", "distance" },
    { "tg.vis", "Show visibility", "visible" }, { "tg.rel", "Show relation", "relation" } }) do
    thud:Toggle({ name = o[2], flag = o[1], default = true, depends = "tg.on", callback = function(v) Hud.Target:SetOption(o[3], v) end })
end
thud:Dropdown({ name = "Health bar", flag = "tg.hpm", options = { "solid", "gradient" }, default = "gradient", depends = "tg.on", callback = function(v) Hud.Target:SetBarMode(v) end })
local xh = ind:Card({ name = "crosshair", id = "xh", side = "right" })
row(xh, "Custom crosshair", "xh.on", { sw = { "#c9a96e" } })
xh:Slider({ name = "Size", flag = "xh.size", min = 2, max = 20, default = 6, depends = "xh.on", fmt = px })
xh:Slider({ name = "Gap", flag = "xh.gap", min = 0, max = 10, default = 3, depends = "xh.on", fmt = px })
-- the esp health colours drive the target hud bar too
follow({ "esp.hp.c" }, function() Hud.Target:SetColors(F("esp.hp.c0"), F("esp.hp.c1"), F("esp.hp.c2")) end)

-- visuals / effects -----------------------------------------------------------------------------
local FXG = { "shoot", "hit", "kill", "atmosphere" }
local TRACERS = { "beam", "lightning", "smoke trail", "wisp", "comet", "pulse" }
local TRACER_STYLE = { beam = "beam", lightning = "lightning", ["smoke trail"] = "smoke" }
local GUNS = { "ak-47", "fal", "m4a1", "remington 870", "m9", "mp5", "taser" }
local KILLFX = { "melt", "spaghettify", "balloon", "orbit", "glass shatter", "magnetize", "puppet", "time freeze", "implode", "vaporize" }
local SOUNDS = { "skeet", "bell", "click", "bubble", "bameware", "custom id" }
local SKIES = { "caustic", "nebula", "night city", "sunset", "custom id" }
local secs = function(v) return string.format("%.1f s", v) end
-- Atmosphere then Lighting values in ATMK order, then the sky preset ("" keeps the game sky)
local ATMK = { "atm.d", "atm.o", "atm.c", "atm.dc", "atm.g", "atm.hz", "lt.ct", "lt.br", "lt.amb", "lt.oamb", "lt.ex" }
local ATM = {
    default = { 0.395, 0, "#c7aa6b", "#5c3c0d", 0, 0, 14.5, 3, "#464646", "#464646", 0, "" },
    dusk = { 0.45, 0.1, "#b07a6a", "#3a2a4a", 0.8, 1.5, 18.2, 1.6, "#3a3550", "#6a5a70", -0.2, "sunset" },
    ["foggy morning"] = { 0.62, 0.25, "#c9ccd2", "#8a9098", 0, 4, 7.5, 1.4, "#6a6e76", "#8a8e96", 0.1, "" },
    night = { 0.3, 0, "#1c2236", "#0a0d18", 0, 0.5, 0, 0.4, "#1a1d2c", "#2a2f45", -0.5, "night city" },
    overcast = { 0.5, 0.1, "#9a9ea6", "#6a6e76", 0, 2.5, 12, 1.2, "#5a5e66", "#7a7e86", -0.1, "" },
    ["sunset haze"] = { 0.48, 0.15, "#e0a070", "#8a4a3a", 2.5, 3, 17.6, 2.2, "#5a4038", "#a06a50", 0.2, "sunset" },
    alien = { 0.55, 0.2, "#6fd6a0", "#3a1a5a", 1.5, 2, 21, 1.5, "#203a30", "#3a6a50", 0.3, "nebula" },
}
local ATMN = { "default", "dusk", "foggy morning", "night", "overcast", "sunset haze", "alien", "custom" }
local A0 = ATM.default

local effects = visuals:Page({ name = "effects" })
local fxStrip = effects:Strip({ flag = "fx.grp", items = (function()
    local out = {}
    for _, k in ipairs(FXG) do out[#out + 1] = { k = k, icon = k } end
    return out
end)() })
local fxViews = {}

local function shootCard(c)
    local _, gg = row(c, "Tracers", "fx.tr", { def = true, sw = { "#c9a96e" }, gear = "tracers" })
    gg:Dropdown({ name = "Style", flag = "fx.trs", options = TRACERS, default = "beam" })
    gg:Slider({ name = "Thickness", flag = "fx.trw", min = 0.5, max = 6, step = 0.5, default = 2, fmt = px })
    gg:Slider({ name = "Lifetime", flag = "fx.trl", min = 0.2, max = 3, step = 0.1, default = 0.8, fmt = secs })
    gg:Slider({ name = "Brightness", flag = "fx.trbr", min = 0, max = 200, default = 100, fmt = pct })
    row(gg, "Glow", "fx.trglow", { def = true })
    row(gg, "Fade out", "fx.trfade", { def = true })
    _, gg = row(c, "Impacts", "fx.imp", { def = true, sw = { "#e8e4dc" }, gear = "impacts" })
    gg:Dropdown({ name = "Style", flag = "fx.imps", options = { "sparks", "dust", "decal", "ripple" }, default = "sparks" })
    gg:Slider({ name = "Size", flag = "fx.impz", min = 0, max = 100, default = 40, fmt = pct })
    _, gg = row(c, "Gun sounds", "fx.gs", { def = true, gear = "gun sounds" })
    gg:Dropdown({ name = "Weapon", flag = "fx.gsw", options = GUNS, default = GUNS[1] })
    gg:Dropdown({ name = "Sound", flag = "fx.gss", options = SOUNDS, default = "click" })
end

local function hitCard(c)
    local _, gg = row(c, "Hit marker", "hm.on", { def = true, sw = { "#ffffff" }, gear = "hit marker" })
    gg:Dropdown({ name = "Style", flag = "hm.style", options = { "cross", "circle", "world" }, default = "cross" })
    gg:Slider({ name = "Size", flag = "fx.hms", min = 4, max = 24, default = 10, fmt = px })
    _, gg = row(c, "Damage numbers", "hm.dmg", { sw = { "#ef6a6a" }, gear = "damage numbers" })
    gg:Dropdown({ name = "Animation", flag = "fx.dmgs", options = { "float up", "pop", "stack" }, default = "float up" })
    gg:Slider({ name = "Duration", flag = "fx.dmgt", min = 0.2, max = 3, step = 0.1, default = 1, fmt = secs })
    _, gg = row(c, "Hit chams", "fx.hc", { sw = { "#ef6a6a" }, gear = "hit chams" })
    gg:Dropdown({ name = "Material", flag = "fx.hcm", options = { "flat", "neon", "forcefield" }, default = "neon" })
    gg:Slider({ name = "Duration", flag = "fx.hct", min = 0.1, max = 3, step = 0.1, default = 0.6, fmt = secs })
    _, gg = row(c, "Hit effects", "fx.hfx", { def = true, gear = "hit effects" })
    gg:Dropdown({ name = "Effects", flag = "fx.he", options = { "sparks", "blood", "ring", "flash", "confetti" }, default = { "sparks" }, multi = true })
    gg:Slider({ name = "Intensity", flag = "fx.hei", min = 0, max = 100, default = 50, fmt = pct })
    _, gg = row(c, "Hit sound", "hm.snd", { gear = "hit sound" })
    gg:Dropdown({ name = "Sound", flag = "hm.sndf", options = SOUNDS, default = "skeet" })
    gg:Input({ name = "Sound id", flag = "fx.hsid", placeholder = "sound id" })
    gg:Slider({ name = "Volume", flag = "hm.vol", min = 0, max = 100, default = 60, fmt = pct })
end

local function killCard(c)
    local _, gg = row(c, "Kill notice", "fx.kn", { def = true, sw = { "#c9a96e" }, gear = "kill notice" })
    gg:Dropdown({ name = "Style", flag = "fx.kns", options = { "feed", "centre", "banner" }, default = "feed" })
    _, gg = row(c, "Kill effects", "fx.kfx", { def = true, gear = "kill effects" })
    gg:Dropdown({ name = "Effects", flag = "fx.ke", options = KILLFX, default = { "vaporize" }, multi = true })
    gg:Slider({ name = "Intensity", flag = "fx.kei", min = 0, max = 100, default = 70, fmt = pct })
    row(gg, "Random each kill", "fx.kerand")
    _, gg = row(c, "Fade corpses", "fx.cf", { def = true, gear = "corpses" })
    gg:Slider({ name = "Fade time", flag = "fx.cft", min = 0, max = 30, default = 5, fmt = function(v) return v .. " s" end })
    row(gg, "Keep ragdoll", "fx.crag")
    _, gg = row(c, "Streak announcer", "fx.kst", { gear = "kill streak" })
    gg:Dropdown({ name = "Voice", flag = "fx.kstv", options = { "unreal", "quake", "halo", "text only" }, default = "unreal" })
    gg:Slider({ name = "Reset after", flag = "fx.kstr", min = 2, max = 30, default = 8, fmt = function(v) return v .. " s" end })
    _, gg = row(c, "Kill sound", "fx.ks", { gear = "kill sound" })
    gg:Dropdown({ name = "Sound", flag = "fx.ksf", options = SOUNDS, default = "bell" })
    gg:Slider({ name = "Volume", flag = "fx.ksv", min = 0, max = 100, default = 70, fmt = pct })
end

local atmSetting = false
local function atmCard(c)
    c:Dropdown({ name = "Preset", flag = "atm.pre", options = ATMN, default = "default", callback = function(v)
        local p = ATM[v]
        if not p then return end
        atmSetting = true
        for i, k in ipairs(ATMK) do Aster:Set(k, p[i]) end
        if p[12] ~= "" then Aster:Set("fx.skyp", p[12]) end
        Aster:Set("fx.sky", p[12] ~= "")
        atmSetting = false
    end })
    local _, gg = row(c, "Custom skybox", "fx.sky", { gear = "skybox" })
    gg:Dropdown({ name = "Preset", flag = "fx.skyp", options = SKIES, default = "nebula" })
    gg:Input({ name = "Sky id", flag = "fx.skyid", placeholder = "sky id" })
    gg:Slider({ name = "Rotation speed", flag = "fx.skyr", min = 0, max = 10, step = 0.5, default = 1 })
    c:Slider({ name = "Density", flag = "atm.d", min = 0, max = 1, step = 0.005, default = A0[1] })
    c:Slider({ name = "Offset", flag = "atm.o", min = 0, max = 1, step = 0.01, default = A0[2] })
    c:Color({ name = "Colour", flag = "atm.c", default = A0[3], opaque = true })
    c:Color({ name = "Decay", flag = "atm.dc", default = A0[4], opaque = true })
    c:Slider({ name = "Glare", flag = "atm.g", min = 0, max = 10, step = 0.1, default = A0[5] })
    c:Slider({ name = "Haze", flag = "atm.hz", min = 0, max = 10, step = 0.1, default = A0[6] })
end
local function lightCard(c)
    c:Slider({ name = "Clock time", flag = "lt.ct", min = 0, max = 24, step = 0.1, default = A0[7],
        fmt = function(v) return string.format("%02d:%02d", math.floor(v), math.floor(v % 1 * 60 + 0.5) % 60) end })
    c:Slider({ name = "Brightness", flag = "lt.br", min = 0, max = 10, step = 0.1, default = A0[8] })
    c:Color({ name = "Ambient", flag = "lt.amb", default = A0[9], opaque = true })
    c:Color({ name = "Outdoor ambient", flag = "lt.oamb", default = A0[10], opaque = true })
    c:Slider({ name = "Exposure", flag = "lt.ex", min = -3, max = 3, step = 0.05, default = A0[11],
        fmt = function(v) return (v > 0 and "+" or "") .. string.format("%.2f", v) end })
end
local FXL = { shoot = shootCard, hit = hitCard, kill = killCard, atmosphere = atmCard }

-- the effect previews: the same dummy drives every demo, the footer buttons fire them by hand
local function hook(v, prefixes, fn)
    local conn = follow(prefixes, fn)
    if v.view.Maid then v.view.Maid:Add(conn) end
end
local function later(t, fn)
    if task and task.delay then task.delay(t, fn) else fn() end
end
local function shoot(v)
    if not (Scene and v.dummy) or not (F("fx.tr") or F("fx.imp")) then return nil end
    return Scene.Shoot(v.view, v.dummy, {
        style = TRACER_STYLE[F("fx.trs")] or "line", color = F("fx.tr.c0"), width = F("fx.tr") and (F("fx.trw") or 2) * 0.04 or 0,
        life = F("fx.trl"), sparks = F("fx.imp"), sparkColor = F("fx.imp.c0"), sparkSize = (F("fx.impz") or 40) / 100,
        tracer = F("fx.tr"), glow = F("fx.trglow"), fade = F("fx.trfade"), brightness = (F("fx.trbr") or 100) / 100,
    })
end
local function hit(v, part)
    if not (Scene and v.dummy) then return nil end
    return Scene.Hit(v.view, v.dummy, {
        part = part, damage = part == "Head" and 87 or 34, life = F("fx.dmgt"),
        marker = F("hm.on"), markerColor = F("hm.on.c0"), markerSize = F("fx.hms"),
        number = F("hm.dmg"), color = F("hm.dmg.c0"),
        flash = F("fx.hc"), flashColor = F("fx.hc.c0"), flashTime = F("fx.hct"),
    })
end
local function killStyle()
    local list = F("fx.ke") or {}
    if #list == 0 then return nil end
    local pick = F("fx.kerand") and list[math.random(#list)] or list[1]
    return cap(pick)
end
local function kill(v)
    if not F("fx.kfx") then return nil end
    local style = killStyle()
    if F("fx.kn") then notify("aimbot", "killed dummy" .. (style and (" \194\183 " .. string.lower(style)) or ""), "kill") end
    if not (Scene and v.dummy and style) then return nil end
    return Scene.Kill(v.view, v.dummy, style, { time = 0.6 + 1.2 * (F("fx.kei") or 70) / 100, color = F("fx.kn.c0") })
end
local function lift(c, k)
    return Color3.new(math.min(1, c.R * k), math.min(1, c.G * k), math.min(1, c.B * k))
end
local function atmTable()
    local t = (F("lt.ct") or 14.5) / 24 * 2 * math.pi
    local k = math.max(0.1, (F("lt.br") or 3) / 3) * 2 ^ (F("lt.ex") or 0)
    return {
        ambient = F("lt.amb"), light = lift(F("lt.oamb") or Color3.new(0.3, 0.3, 0.3), k * 2),
        lightDir = Vector3.new(math.sin(t), -math.max(0.2, -math.cos(t)), 0.4),
        skyTop = F("atm.dc"), skyBottom = F("atm.c"), fogColor = F("atm.c"),
        density = F("atm.d"), haze = (F("atm.hz") or 0) / 10, offset = F("atm.o"), glare = F("atm.g"),
    }
end

local FXV = {
    shoot = function(v)
        local last = 0
        hook(v, { "fx.tr", "fx.imp" }, function()
            if os.clock() - last < 0.25 then return end
            last = os.clock()
            shoot(v)
        end)
        return { { "Shoot", function() shoot(v) end }, { "Burst", function()
            for i = 0, 2 do later(i * 0.12, function() shoot(v) end) end
        end } }
    end,
    hit = function(v)
        hook(v, { "hm.", "fx.hc", "fx.dmg", "fx.hms" }, function() hit(v, "Torso") end)
        return { { "Body", function() hit(v, "Torso") end }, { "Head", function() hit(v, "Head") end } }
    end,
    kill = function(v)
        return { { "Kill", function() kill(v) end }, { "Reset", function() if v.dummy then v.dummy:Reset() end end } }
    end,
    atmosphere = function(v)
        if Scene then
            v.atm = Scene.Atmosphere(v.view, atmTable())
            hook(v, { "atm.", "lt." }, function(flag)
                if flag ~= "atm.pre" then v.atm:Set(atmTable()) end
            end)
            v.view:Orbit(true)
        end
        local function step(d)
            local at = 1
            for i, n in ipairs(ATMN) do if n == F("atm.pre") then at = i end end
            at = (at - 1 + d) % (#ATMN - 1) + 1
            Aster:Set("atm.pre", ATMN[at])
            notify("atmosphere", ATMN[at])
        end
        return { { "Previous", function() step(-1) end }, { "Next", function() step(1) end } }
    end,
}

effects:Variants(fxStrip, function(grp, page)
    local left = page:Card({ name = grp == "atmosphere" and grp or ("on " .. grp), id = "fxl", side = "left" })
    FXL[grp](left)
    local right = page:Card({ name = "preview", id = "fxp", side = "right" })
    local v = { view = right:Preview({ kind = grp }) }
    if Scene then
        Scene.attach(v.view)
        v.dummy = Scene.Dummy(v.view, { motion = grp == "shoot" and "none" or "idle" })
        v.view:Fit()
    end
    v.view.SetButtons(FXV[grp](v))
    fxViews[grp] = v
    if grp == "atmosphere" then lightCard(page:Card({ name = "lighting", id = "fxlt", side = "right" })) end
end)

-- a preset writes every value; touching one afterwards flips the preset to custom
local function hexOf(c)
    return string.format("#%02x%02x%02x", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end
local function atmIs(name)
    local p = ATM[name]
    if not p then return false end
    for i, k in ipairs(ATMK) do
        local cur, want = F(k), p[i]
        if type(want) == "string" then
            if typeof(cur) ~= "Color3" or hexOf(cur) ~= want then return false end
        elseif type(cur) ~= "number" or math.abs(cur - want) > 1e-6 then
            return false
        end
    end
    return true
end
follow({ "atm.", "lt.", "fx.sky" }, function(flag)
    if flag == "atm.pre" or atmSetting or F("atm.pre") == "custom" then return end
    if not atmIs(F("atm.pre")) then Aster:Set("atm.pre", "custom", true) end
end)

hitLink:Stat({ name = "Hit marker", default = "effects / hit", click = function()
    win:Go(effects)
    effects:SetVariant("hit")
end })

-- misc ------------------------------------------------------------------------------------------
local misc = win:Tab({ name = "misc", icon = "misc" })
local movement = misc:Page({ name = "movement" })
local mv = movement:Card({ name = "movement", id = "mv", side = "left" })
row(mv, "Bunny hop", "mv.bhop", { def = true, key = "space", mode = "hold" })
row(mv, "Auto strafe", "mv.strafe", { dep = "mv.bhop" })
row(mv, "Speed", "mv.speed", { key = "c" })
mv:Slider({ name = "Walk speed", flag = "mv.spd", min = 16, max = 60, default = 24, depends = "mv.speed" })
row(mv, "Edge jump", "mv.edge", { key = "e" })
local fly = movement:Card({ name = "flight", id = "fly", side = "right" })
row(fly, "Fly", "fly.on", { key = "f" })
fly:Slider({ name = "Fly speed", flag = "fly.spd", min = 10, max = 200, default = 60, depends = "fly.on" })
row(fly, "Noclip", "fly.noclip", { key = "n" })

local others = misc:Page({ name = "others" })
local oth = others:Card({ name = "other", id = "oth", side = "left" })
row(oth, "Anti afk", "o.afk", { def = true })
row(oth, "Unlock fps", "o.fps")
oth:Slider({ name = "Fps cap", flag = "o.cap", min = 30, max = 360, default = 240, depends = "o.fps" })
row(oth, "Auto rejoin on kick", "o.rj")
local srv = others:Card({ name = "server", id = "srv", side = "right" })
srv:Stat({ name = "Place", default = string.lower(gameName) })
local pingStat = srv:Stat({ name = "Ping", default = "-" })
local function playerCount() return #Players:GetPlayers() .. " / " .. tostring(Players.MaxPlayers or "?") end
local countStat = srv:Stat({ name = "Players", default = playerCount() })
srv:Buttons({ items = {
    { name = "Rejoin", callback = function()
        notify("server", "rejoining...")
        pcall(function() game:GetService("TeleportService"):Teleport(game.PlaceId, me) end)
    end },
    { name = "Server hop", callback = function() notify("server", "finding a new server...") end },
} })
local function serverStats()
    pcall(function() pingStat:Set(math.floor(me:GetNetworkPing() * 1000 + 0.5) .. " ms") end)
    countStat:Set(playerCount())
end
serverStats()
Aster:OnUnload((function()
    local alive = true
    if task and task.spawn and task.wait then
        task.spawn(function()
            while alive do
                task.wait(2)
                if alive then serverStats() end
            end
        end)
    end
    return function() alive = false end
end)())


-- misc / avatar ---------------------------------------------------------------------------------
local CATS = { "hats", "hair", "face", "shirts", "pants", "bundles", "animations", "emotes" }
local NAMES = {
    hats = { "valkyrie helm", "dominus frigidus", "sparkle time fedora", "clockwork shades", "bucket hat", "beanie" },
    hair = { "messy black", "blonde spikes", "side part", "pink bob", "long wavy", "buzz cut" },
    face = { "super super happy", "chill", "beast mode", "playful vampire", "winning smile", "skeptic" },
    shirts = { "bomber jacket", "plaid flannel", "hoodie grey", "trackjacket", "chain tee", "sweater vest" },
    pants = { "cargo black", "ripped jeans", "joggers", "shorts camo", "track pants", "slacks" },
    bundles = { "rthro normal", "stylish", "knights of redcliff", "robloxian 2.0", "city life", "oldschool" },
    animations = { "ninja", "levitation", "stylish", "zombie", "toy", "mage" },
    emotes = { "floss", "tilt", "shrug", "salute", "hype dance", "point" },
}
local ITEMS, BYID = {}, {}
for ci, cat in ipairs(CATS) do
    for i, name in ipairs(NAMES[cat]) do
        local n = (ci - 1) * 6 + (i - 1)
        local it = { key = tostring(1028606 + n * 7919), cat = cat, name = name, price = 25 + (n * 37 % 300), sale = n % 5 == 0,
            color = Color3.fromHSV(((n * 47) % 360) / 360, 0.45, 0.45) }
        it.cost = it.sale and math.floor(it.price * 0.7 + 0.5) or it.price
        it.sub = "R$ " .. it.cost
        ITEMS[#ITEMS + 1], BYID[it.key] = it, it
    end
end
local AV = { worn = {}, fav = {} }
local BODYC = { { "head", "#f5cd30" }, { "torso", "#0d69ac" }, { "arms", "#f5cd30" }, { "legs", "#a4bd47" } }
local OUTFITS = { { "daily", {} }, { "guard drip", {} }, { "all black", {} } }
local avChanged = {}
local function avFire() for _, fn in ipairs(avChanged) do fn() end end
local function wornItems()
    local out = {}
    for _, it in ipairs(ITEMS) do if AV.worn[it.key] then out[#out + 1] = it end end
    return out
end

local avatar = misc:Page({ name = "avatar", wide = true })
local avc = avatar:Card({ name = "avatar", id = "avc", side = "left" })
local VIEWS = { "catalog", "body", "by id", "outfits", "favorites" }
local avStrip = avc:Strip({ flag = "av.view", items = VIEWS, small = true, save = false })
local views = {}
local function view(name, el)
    views[name] = views[name] or {}
    table.insert(views[name], el)
    return el
end
local function catalogItems()
    local q, cat, so = string.lower(F("av.q") or ""), F("av.cat"), F("av.sort")
    local out = {}
    for _, it in ipairs(ITEMS) do
        if (cat == "all" or it.cat == cat) and string.find(it.name, q, 1, true) and (not F("av.sale") or it.sale) then out[#out + 1] = it end
    end
    if so ~= "relevance" then
        table.sort(out, function(a, b)
            if so == "name" then return a.name < b.name end
            if so == "price low to high" then return a.cost < b.cost end
            return a.cost > b.cost
        end)
    end
    return out
end
local function favItems()
    local out = {}
    for _, it in ipairs(ITEMS) do if AV.fav[it.key] then out[#out + 1] = it end end
    return out
end
local function wear(it)
    AV.worn[it.key] = not AV.worn[it.key] or nil
    notify("avatar", (AV.worn[it.key] and "wearing " or "took off ") .. it.name)
    avFire()
end
local function star(it)
    AV.fav[it.key] = not AV.fav[it.key] or nil
    avFire()
end
local tileOpts = function(items, empty)
    return { items = items, empty = empty, click = wear, fav = star,
        isOn = function(it) return AV.worn[it.key] == true end, isFav = function(it) return AV.fav[it.key] == true end }
end
view("catalog", avc:Input({ flag = "av.q", placeholder = "search", save = false }))
local catOpts = { "all" }
for _, c in ipairs(CATS) do catOpts[#catOpts + 1] = c end
view("catalog", avc:Dropdown({ name = "Category", flag = "av.cat", options = catOpts, default = "all", save = false }))
view("catalog", avc:Dropdown({ name = "Sort", flag = "av.sort", options = { "relevance", "price low to high", "price high to low", "name" }, default = "relevance", save = false }))
view("catalog", avc:Toggle({ name = "On sale only", flag = "av.sale", save = false }))
local catalog = view("catalog", avc:Tiles(tileOpts(catalogItems(), "no items")))
for _, bc in ipairs(BODYC) do
    view("body", avc:Color({ name = cap(bc[1]) .. " colour", flag = "av.c." .. bc[1], default = bc[2], opaque = true }))
end
view("body", avc:Slider({ name = "Height", flag = "av.h", min = 90, max = 105, default = 100, fmt = pct }))
view("body", avc:Slider({ name = "Width", flag = "av.w", min = 70, max = 100, default = 100, fmt = pct }))
view("body", avc:Slider({ name = "Head", flag = "av.hd", min = 95, max = 100, default = 100, fmt = pct }))
local idBox = view("by id", avc:Input({ flag = "av.id", placeholder = "asset id", save = false }))
local function wearId()
    local v = string.gsub(idBox.Value or "", "%s", "")
    if not string.match(v, "^%d%d%d%d+$") or #v > 15 then return notify("avatar", "asset ids are 4 to 15 digits", "warn") end
    local it = BYID[v]
    if it then
        if not AV.worn[v] then wear(it) end
    else
        notify("avatar", "wearing asset " .. v, "ok")
    end
end
idBox.Opts.enter = wearId
view("by id", avc:Button({ name = "Wear", primary = true, callback = wearId }))
local outfitSel = OUTFITS[1][1]
local function outfitRows()
    local out = {}
    for _, o in ipairs(OUTFITS) do
        local n = 0
        for _ in pairs(o[2]) do n = n + 1 end
        out[#out + 1] = { key = o[1], text = o[1], meta = n .. " items" }
    end
    return out
end
local outfitList = view("outfits", avc:List({ items = outfitRows(), rows = 5, empty = "no outfits", save = false,
    callback = function(k) outfitSel = k end, activate = function(k) outfitSel = k end }))
local outfitName = view("outfits", avc:Input({ flag = "av.oname", placeholder = "outfit name", save = false }))
local function findOutfit(name)
    for i, o in ipairs(OUTFITS) do if o[1] == name then return o, i end end
    return nil
end
view("outfits", avc:Buttons({ items = {
    { name = "Save", primary = true, callback = function()
        local name = string.lower(outfitName.Value or "")
        if name == "" then name = "outfit " .. (#OUTFITS + 1) end
        local o = findOutfit(name)
        local copy = {}
        for k in pairs(AV.worn) do copy[k] = true end
        if o then o[2] = copy else OUTFITS[#OUTFITS + 1] = { name, copy } end
        outfitSel = name
        outfitName:Set("")
        outfitList:SetItems(outfitRows())
        notify("outfits", "saved " .. name, "ok")
    end },
    { name = "Load", callback = function()
        local o = findOutfit(outfitSel)
        if not o then return notify("outfits", "pick an outfit first", "warn") end
        AV.worn = {}
        for k in pairs(o[2]) do AV.worn[k] = true end
        avFire()
        notify("outfits", "loaded " .. o[1], "ok")
    end },
    { name = "Delete", callback = function()
        local o, i = findOutfit(outfitSel)
        if not o then return notify("outfits", "pick an outfit first", "warn") end
        table.remove(OUTFITS, i)
        outfitSel = OUTFITS[1] and OUTFITS[1][1]
        outfitList:SetItems(outfitRows())
        notify("outfits", "deleted " .. o[1], "warn")
    end },
} }))
local favorites = view("favorites", avc:Tiles(tileOpts(favItems(), "no favorites")))
local function showView(v)
    for name, list in pairs(views) do
        for _, el in ipairs(list) do el:SetVisible(name == v) end
    end
end
avStrip:OnChanged(showView)
showView(avStrip.Value)
follow({ "av.q", "av.cat", "av.sort", "av.sale" }, function() catalog:SetItems(catalogItems()) end)
table.insert(avChanged, function()
    catalog:Refresh()
    favorites:SetItems(favItems())
end)

-- the preview is the engine dummy wearing the stand-in outfit: body colours, shirt and pants tint, a hat or hair block on the head
local avp = avatar:Card({ name = "preview", id = "avp", side = "right" })
local avView = avp:Preview({ kind = "avatar" })
local avSum = avp:Stat({ name = "Outfit", default = "nothing worn" })
avp:Toggle({ name = "Re-apply on respawn", flag = "av.respawn", default = true })
local avScene = {}
local function firstOf(list, cat)
    for _, it in ipairs(list) do if it.cat == cat then return it end end
    return nil
end
local function dress()
    local worn = wornItems()
    local total = 0
    for _, it in ipairs(worn) do total = total + it.cost end
    avSum:Set(#worn > 0 and (#worn .. " items \194\183 R$ " .. total) or "nothing worn")
    local d = avScene.dummy
    if not d then return end
    local shirt, pants, top = firstOf(worn, "shirts"), firstOf(worn, "pants"), firstOf(worn, "hats") or firstOf(worn, "hair")
    local paint = {
        Head = F("av.c.head"), Torso = shirt and shirt.color or F("av.c.torso"),
        ["Left Arm"] = F("av.c.arms"), ["Right Arm"] = F("av.c.arms"),
        ["Left Leg"] = pants and pants.color or F("av.c.legs"), ["Right Leg"] = pants and pants.color or F("av.c.legs"),
    }
    for name, color in pairs(paint) do
        local part = d.Parts[name]
        if part and color then part.Color = color end
    end
    if top and not avScene.hat then
        local hat = Instance.new("Part")
        hat.Name = "AsterHat"
        hat.Anchored, hat.CanCollide = true, false
        hat.Material = Enum.Material.SmoothPlastic
        hat.Parent = d.Model
        avScene.hat = hat
    elseif not top and avScene.hat then
        avScene.hat:Destroy()
        avScene.hat = nil
    end
    if avScene.hat then
        avScene.hat.Color = top.color
        avScene.hat.Size = top.cat == "hats" and Vector3.new(1.4, 0.5, 1.4) or Vector3.new(1.25, 0.35, 1.25)
    end
end
if Scene then
    avScene.dummy = Scene.Dummy(avView, { motion = "idle" })
    avView:Fit()
    avView:Orbit(true, 18)
    avView:Loop(function()
        local hat, head = avScene.hat, avScene.dummy.Parts.Head
        if hat and head then hat.CFrame = head.CFrame * CFrame.new(0, head.Size.Y / 2 + hat.Size.Y / 2, 0) end
    end)
    avView.Maid:Add(follow({ "av.c." }, dress))
else
    follow({ "av.c." }, dress)
end
table.insert(avChanged, dress)
dress()
avView.SetButtons({
    { "Reset", function()
        AV.worn = {}
        for _, bc in ipairs(BODYC) do Aster:Set("av.c." .. bc[1], bc[2]) end
        if avScene.dummy then avScene.dummy:Reset() end
        avFire()
        notify("avatar", "reset")
    end },
    { "Apply", function() notify("avatar", "applied " .. #wornItems() .. " items", "ok") end },
})

-- misc / exploits -------------------------------------------------------------------------------
local exploits = misc:Page({ name = "exploits" })
local tick = exploits:Card({ name = "tickbase", id = "tick", side = "left" })
row(tick, "Double tap", "ex.dt", { key = true })
tick:Dropdown({ name = "Recharge", flag = "ex.dtm", options = { "instant", "after shot", "manual" }, default = "after shot", depends = "ex.dt" })
tick:Slider({ name = "Shift ticks", flag = "ex.dts", min = 1, max = 16, default = 14, depends = "ex.dt" })
row(tick, "Hide shots", "ex.hs", { key = true })
local lag = exploits:Card({ name = "fake lag", id = "lag", side = "left" })
row(lag, "Fake lag", "ex.fl", { key = true })
lag:Dropdown({ name = "Mode", flag = "ex.flm", options = { "static", "adaptive", "random", "on peek" }, default = "adaptive", depends = "ex.fl" })
lag:Slider({ name = "Choke", flag = "ex.fla", min = 1, max = 14, default = 8, depends = "ex.fl", fmt = function(v) return v .. " ticks" end })
row(lag, "Visualize lag", "ex.flv", { sw = { "#8f9bf0" }, dep = "ex.fl" })
local net = exploits:Card({ name = "network", id = "net", side = "right" })
row(net, "Fake latency", "ex.ping")
net:Slider({ name = "Added latency", flag = "ex.pingv", min = 0, max = 400, step = 10, default = 150, depends = "ex.ping", fmt = function(v) return v .. " ms" end })
row(net, "Desync", "ex.desync", { key = true })
net:Slider({ name = "Desync angle", flag = "ex.dsa", min = 0, max = 58, default = 58, depends = "ex.desync", fmt = function(v) return v .. "\194\176" end })
local chr = exploits:Card({ name = "character", id = "chr", side = "right" })
row(chr, "No fall damage", "ex.nofall", { def = true })
row(chr, "Infinite stamina", "ex.stam")
row(chr, "Instant interact", "ex.inter")
row(chr, "Camera noclip", "ex.cam", { key = true })

-- settings: the built-in configs, players and theming pages ----------------------------------------
loader:Stage("starting hud", 0.85)
local settings = win:Builtins({
    onPanic = function()
        for flag, v in pairs(Aster.Flags) do
            if v == true and Aster.Elements[flag] and Aster.Elements[flag].Kind == "toggle" and not string.find(flag, "^hud%.") then Aster:Set(flag, false) end
        end
    end,
})

loader:Done()
notify("aster", "loaded, press insert to toggle the menu", "ok")
return { Aster = Aster, Window = win, Settings = settings, Esp = espScene, Effects = fxViews, Avatar = avScene, Views = { esp = espView, avatar = avView } }
