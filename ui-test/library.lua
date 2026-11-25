-- [src] 00_head.lua
local Env = (type(getgenv) == "function" and getgenv()) or _G
local warn = warn or function(...) print(...) end

local Aster, Util, Theme, Text, Input, Store, Layer, Kinds, Element, Container, Icons, Exec = {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}
local Anim, Scroll = {}, {}

do
    function Exec.first(...)
        for index = 1, select("#", ...) do
            local candidate = select(index, ...)
            if type(candidate) == "function" then return candidate end
        end
        return nil
    end

    function Exec.field(owner, key)
        if type(owner) ~= "table" and type(owner) ~= "userdata" then return nil end
        local ok, value = pcall(function() return owner[key] end)
        return ok and value or nil
    end

    local first, field = Exec.first, Exec.field
    Exec.cloneref = first(cloneref, clonereference)
    Exec.gethui = first(gethui, get_hidden_gui, gethiddenui)
    Exec.isactive = first(isrbxactive, iswindowactive, isgameactive)
    Exec.clipboard = first(setclipboard, toclipboard, setrbxclipboard)
    Exec.customasset = first(getcustomasset, getsynasset)
    Exec.protect = first(protectgui, field(syn, "protect_gui")) or function() end
    Exec.request = first(request, http_request, field(http, "request"), field(syn, "request"))
    Exec.fs = {
        read = first(readfile),
        write = first(writefile),
        isfile = first(isfile),
        isfolder = first(isfolder),
        makefolder = first(makefolder),
        list = first(listfiles),
        delete = first(delfile),
    }
    Exec.hasFs = Exec.fs.read ~= nil and Exec.fs.write ~= nil and Exec.fs.isfile ~= nil and Exec.fs.makefolder ~= nil

    function Exec.httpGet(url)
        local ok, body = pcall(function() return game:HttpGet(url) end)
        if ok and type(body) == "string" then return body end
        if Exec.request then
            local sent, reply = pcall(Exec.request, { Url = url, Method = "GET" })
            if sent and type(reply) == "table" and type(reply.Body) == "string" then return reply.Body end
        end
        return nil
    end

    function Exec.service(name)
        local service = game:GetService(name)
        if Exec.cloneref then
            local ok, cloned = pcall(Exec.cloneref, service)
            if ok and cloned then return cloned end
        end
        return service
    end

    function Exec.guiParent()
        local ok, hui = pcall(function() return Exec.gethui and Exec.gethui() or nil end)
        if ok and typeof(hui) == "Instance" then
            local okLayer, isLayer = pcall(function() return hui:IsA("LayerCollector") end)
            if not (okLayer and isLayer) then return hui end
        end
        return Exec.service("CoreGui")
    end
end

local Players = Exec.service("Players")
local RunService = Exec.service("RunService")
local UserInputService = Exec.service("UserInputService")
local TextService = Exec.service("TextService")
local TweenService = Exec.service("TweenService")
local HttpService = Exec.service("HttpService")
local LocalPlayer = Players.LocalPlayer

do
    function Util.guard(fn, ...)
        local result = table.pack(pcall(fn, ...))
        if not result[1] then
            warn("[aster] " .. tostring(result[2]))
            return false
        end
        return table.unpack(result, 1, result.n)
    end

    function Util.snap(n)
        return math.floor(n + 0.5)
    end

    function Util.clamp(v, lo, hi)
        if hi < lo then hi = lo end
        if v < lo then return lo end
        if v > hi then return hi end
        return v
    end

    function Util.slug(s)
        s = string.lower(tostring(s or ""))
        s = string.gsub(s, "[^%w]+", "_")
        s = string.gsub(s, "^_+", "")
        s = string.gsub(s, "_+$", "")
        return s
    end

    function Util.hex(value)
        if typeof(value) == "Color3" then return value end
        if type(value) ~= "string" then return nil end
        value = string.lower(value)
        local digits = string.match(value, "^#?(%x%x%x%x%x%x)$") or string.match(value, "^#?(%x%x%x%x%x%x)%x%x$")
        if not digits then return nil end
        return Color3.fromRGB(tonumber(string.sub(digits, 1, 2), 16), tonumber(string.sub(digits, 3, 4), 16), tonumber(string.sub(digits, 5, 6), 16))
    end

    function Util.toHex(color)
        return string.format("#%02x%02x%02x", Util.snap(color.R * 255), Util.snap(color.G * 255), Util.snap(color.B * 255))
    end

    function Util.mix(a, b, t)
        a, b = Util.hex(a), Util.hex(b)
        return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
    end

    function Util.same(a, b)
        if a == b then return true end
        if type(a) ~= "table" or type(b) ~= "table" then return false end
        for k, v in pairs(a) do
            if b[k] ~= v then return false end
        end
        for k in pairs(b) do
            if a[k] == nil then return false end
        end
        return true
    end

    function Util.copy(t)
        if type(t) ~= "table" then return t end
        local out = {}
        for k, v in pairs(t) do out[k] = v end
        return out
    end

    function Util.json(value)
        local ok, text = pcall(function() return HttpService:JSONEncode(value) end)
        return ok and text or nil
    end

    function Util.unjson(text)
        if type(text) ~= "string" then return nil end
        local ok, value = pcall(function() return HttpService:JSONDecode(text) end)
        return ok and value or nil
    end

    local DEFAULTS = {
        Frame = { BorderSizePixel = 0 },
        TextLabel = { BorderSizePixel = 0, BackgroundTransparency = 1 },
        TextButton = { BorderSizePixel = 0, AutoButtonColor = false, Text = "" },
        TextBox = { BorderSizePixel = 0, ClearTextOnFocus = false },
        ImageLabel = { BorderSizePixel = 0, BackgroundTransparency = 1 },
        ImageButton = { BorderSizePixel = 0, BackgroundTransparency = 1, AutoButtonColor = false },
        ViewportFrame = { BorderSizePixel = 0 },
    }

    function Util.new(class, props, children)
        local obj = Instance.new(class)
        local defaults = DEFAULTS[class]
        if defaults then
            for key, value in pairs(defaults) do
                if not (props and props[key] ~= nil) then obj[key] = value end
            end
        end
        local parent
        if props then
            for key, value in pairs(props) do
                if key == "Parent" then
                    parent = value
                elseif key ~= "Theme" and key ~= "TextStyle" then
                    obj[key] = value
                end
            end
            if props.TextStyle then Text.style(obj, props.TextStyle) end
            if props.Theme then
                for prop, token in pairs(props.Theme) do Theme.bind(obj, prop, token) end
            end
        end
        if children then
            for _, child in ipairs(children) do child.Parent = obj end
        end
        if parent then obj.Parent = parent end
        return obj
    end

    local Signal = {}
    Signal.__index = Signal
    Util.Signal = Signal

    function Signal.new()
        return setmetatable({ _list = {} }, Signal)
    end

    function Signal:Connect(fn)
        local list = self._list
        local conn = { Connected = true }
        function conn.Disconnect()
            if not conn.Connected then return end
            conn.Connected = false
            for index = #list, 1, -1 do
                if list[index] == conn then table.remove(list, index) break end
            end
        end
        conn.Fn = fn
        list[#list + 1] = conn
        return conn
    end

    function Signal:Fire(...)
        local snapshot = table.move(self._list, 1, #self._list, 1, {})
        for _, conn in ipairs(snapshot) do
            if conn.Connected then Util.guard(conn.Fn, ...) end
        end
    end

    function Signal:Destroy()
        for _, conn in ipairs(self._list) do conn.Connected = false end
        self._list = {}
    end

    local Maid = {}
    Maid.__index = Maid
    Util.Maid = Maid

    function Maid.new()
        return setmetatable({ _items = {} }, Maid)
    end

    function Maid:Add(item)
        if item ~= nil then self._items[#self._items + 1] = item end
        return item
    end

    function Maid:Clean()
        local items = self._items
        self._items = {}
        for index = #items, 1, -1 do
            local item = items[index]
            local kind = typeof(item)
            if kind == "function" then
                Util.guard(item)
            elseif kind == "RBXScriptConnection" then
                pcall(function() item:Disconnect() end)
            elseif kind == "Instance" then
                pcall(function() item:Destroy() end)
            elseif type(item) == "table" then
                if item.Disconnect then
                    pcall(item.Disconnect, item)
                elseif item.Destroy then
                    pcall(item.Destroy, item)
                elseif item.Clean then
                    pcall(item.Clean, item)
                end
            end
        end
    end
    Maid.Destroy = Maid.Clean
end

do
    local previous = Env.Aster2
    if type(previous) == "table" and type(previous.Unload) == "function" then
        pcall(previous.Unload, previous)
    end
    Env.Aster2 = Aster

    Aster.Version = "2.0.0"
    Aster.Unloaded = false
    Aster.Theme = Theme
    Aster._maid = Util.Maid.new()
    Aster.Unloading = Util.Signal.new()
    Aster._ = { Util = Util, Theme = Theme, Text = Text, Input = Input, Store = Store, Layer = Layer, Kinds = Kinds,
        Element = Element, Container = Container, Icons = Icons, Exec = Exec, Anim = Anim, Scroll = Scroll }

    local function screen(name, order)
        local gui = Instance.new("ScreenGui")
        gui.Name = name
        pcall(Exec.protect, gui)
        gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = true
        gui.DisplayOrder = order
        gui.Parent = Exec.guiParent()
        return Aster._maid:Add(gui)
    end
    Aster.Gui = { Hud = screen("Aster2Hud", 90), Main = screen("Aster2", 100), Popup = screen("Aster2Popup", 110), Tip = screen("Aster2Tip", 120), Toast = screen("Aster2Toast", 130) }

    function Aster:OnUnload(fn)
        return self.Unloading:Connect(fn)
    end

    function Aster:Unload()
        if self.Unloaded then return end
        self.Unloaded = true
        self.Unloading:Fire()
        if Layer.closeAll then Util.guard(Layer.closeAll) end
        self._maid:Clean()
        if Env.Aster2 == self then Env.Aster2 = nil end
    end
end

-- [src] 05_theme.lua
do
    local PRESETS = {
        { "gold", { accent = "#c9a96e", bg = "#0c0c0e", panel = "#15151a", border = "#2a2a31", text = "#ededf2", style = "gradient",
            btnBg = "#1e1e23", btnBd = "#000000", btnTx = "#c4c4cd", btnHv = "#26262c", ddBg = "#1c1c21", ddBd = "#000000", ddTx = "#c4c4cd", ddlBg = "#111114", ddHl = "#c9a96e" } },
        { "midnight", { accent = "#8f9bf0", bg = "#0a0c13", panel = "#121725", border = "#262d45", text = "#e4e8f6", style = "gradient",
            btnBg = "#182036", btnBd = "#04060b", btnTx = "#c3c9de", btnHv = "#202a46", ddBg = "#161d31", ddBd = "#04060b", ddTx = "#c3c9de", ddlBg = "#0f1320", ddHl = "#8f9bf0" } },
        { "mono", { accent = "#e8e4dc", bg = "#0b0b0b", panel = "#171717", border = "#2e2e2e", text = "#eeeeee", style = "flat",
            btnBg = "#1c1c1c", btnBd = "#000000", btnTx = "#c9c9c9", btnHv = "#262626", ddBg = "#1a1a1a", ddBd = "#000000", ddTx = "#c9c9c9", ddlBg = "#121212", ddHl = "#e8e4dc" } },
        { "ember", { accent = "#e0794a", bg = "#0e0b0a", panel = "#1a1412", border = "#33271f", text = "#f1e8e3", style = "gradient",
            btnBg = "#251b17", btnBd = "#060403", btnTx = "#d9cac2", btnHv = "#30231d", ddBg = "#221915", ddBd = "#060403", ddTx = "#d9cac2", ddlBg = "#16100e", ddHl = "#e0794a" } },
        { "classic", { accent = "#0055ff", bg = "#141414", panel = "#1c1c1c", border = "#323232", text = "#ffffff", style = "flat" } },
        { "violet", { accent = "#7e48a3", bg = "#232323", panel = "#1e1e1e", border = "#141414", text = "#ffffff", style = "flat" } },
        { "rift", { accent = "#c50754", bg = "#191335", panel = "#1e1842", border = "#3c355d", text = "#ffffff", style = "gradient" } },
        { "jest", { accent = "#db4467", bg = "#1c1c1c", panel = "#242424", border = "#373737", text = "#ffffff", style = "gradient" } },
        { "mint", { accent = "#3db488", bg = "#1c1c1c", panel = "#242424", border = "#373737", text = "#ffffff", style = "flat" } },
    }
    local BASE = PRESETS[1][2]
    local KEYS = { "accent", "bg", "panel", "border", "text", "btnBg", "btnBd", "btnTx", "btnHv", "ddBg", "ddBd", "ddTx", "ddlBg", "ddHl" }
    local function complete(p)
        local function mix(a, b, t) return Util.toHex(Util.mix(p[a], p[b], t)) end
        p.btnBg = p.btnBg or mix("panel", "text", 0.05)
        p.btnBd = p.btnBd or "#000000"
        p.btnTx = p.btnTx or mix("text", "bg", 0.2)
        p.btnHv = p.btnHv or mix("panel", "text", 0.1)
        p.ddBg = p.ddBg or mix("panel", "text", 0.04)
        p.ddBd = p.ddBd or "#000000"
        p.ddTx = p.ddTx or p.btnTx
        p.ddlBg = p.ddlBg or mix("panel", "bg", 0.5)
        p.ddHl = p.ddHl or p.accent
        return p
    end
    for _, preset in ipairs(PRESETS) do complete(preset[2]) end
    Theme.Keys = KEYS
    local STYLES = { flat = true, gradient = true }
    local STOCK = {
        bg = { bg = "#0c0c0e", side = "#09090b", well = "#08080a" },
        panel = { panel = "#15151a", panel2 = "#0f0f12", card = "#111114", hi = "#16161a" },
        border = { ln2 = "#2a2a31", ln = "#1f1f25", ln3 = "#3a3a43" },
        text = { tx = "#ededf2", tx2 = "#c4c4cd", tx3 = "#9494a0", tx4 = "#686874" },
    }
    local SHADES = {
        bg = function(c) return { bg = c, side = Util.mix(c, "#000000", 0.25), well = Util.mix(c, "#000000", 0.33) } end,
        panel = function(c) return { panel = c, panel2 = Util.mix(c, "#000000", 0.28), card = Util.mix(c, "#000000", 0.19), hi = c } end,
        border = function(c, bg) return { ln2 = c, ln = Util.mix(c, bg, 0.3), ln3 = Util.mix(c, "#ffffff", 0.07) } end,
        text = function(c, bg) return { tx = c, tx2 = Util.mix(c, bg, 0.18), tx3 = Util.mix(c, bg, 0.4), tx4 = Util.mix(c, bg, 0.6) } end,
    }

    Theme.Presets = {}
    for index, preset in ipairs(PRESETS) do Theme.Presets[index] = preset[1] end
    Theme.Base = Util.copy(BASE)
    Theme.T = {}
    Theme.Changed = Util.Signal.new()
    local registry = {}
    local watched = setmetatable({}, { __mode = "k" })
    Aster._maid:Add(function()
        for obj in pairs(registry) do registry[obj] = nil end
    end)

    local function derive()
        local base, T = Theme.Base, {}
        for _, key in ipairs({ "bg", "panel", "border", "text" }) do
            local stock = base[key] == BASE[key] and (key == "bg" or key == "panel" or base.bg == BASE.bg)
            local shades = stock and STOCK[key] or SHADES[key](base[key], base.bg)
            for name, color in pairs(shades) do T[name] = Util.hex(color) end
        end
        local gradient = base.style == "gradient"
        local function lo(c) return gradient and Util.mix(c, "#000000", 0.3) or Util.hex(c) end
        for _, key in ipairs(KEYS) do T[key] = T[key] or Util.hex(base[key]) end
        T.btnBg2, T.btnHv2, T.ddBg2 = lo(base.btnBg), lo(base.btnHv), lo(base.ddBg)
        T.black, T.white = Color3.new(0, 0, 0), Color3.new(1, 1, 1)
        T.edge = T.black
        T.ok, T.warn, T.bad, T.mute = Util.hex("#6fd69a"), Util.hex("#e8b13c"), Util.hex("#ef6a6a"), Util.hex("#7a7a84")
        T.style = base.style
        Theme.T = T
    end

    local function resolve(token)
        if type(token) == "function" then return token(Theme.T) end
        return Theme.T[token]
    end

    local function paint(obj, prop, token)
        local value = resolve(token)
        if value ~= nil then pcall(function() obj[prop] = value end) end
    end

    function Theme.bind(obj, prop, token)
        if watched[obj] == "dead" then return obj end
        local props = registry[obj]
        if not props then
            props = {}
            registry[obj] = props
            if not watched[obj] then
                watched[obj] = true
                pcall(function()
                    obj.Destroying:Connect(function()
                        registry[obj] = nil
                        watched[obj] = "dead"
                    end)
                end)
            end
        end
        props[prop] = token
        if Anim.running and Anim.running(obj, prop) then Anim.stop(obj, prop) end
        paint(obj, prop, token)
        return obj
    end

    function Theme.repaint(obj)
        local props = registry[obj]
        if not props then return end
        for prop, token in pairs(props) do paint(obj, prop, token) end
    end

    function Theme.unbind(obj, prop)
        local props = registry[obj]
        if not props then return end
        if prop then props[prop] = nil else registry[obj] = nil end
    end

    function Theme.fill(obj, top, bottom)
        local gradient = obj:FindFirstChildOfClass("UIGradient") or Util.new("UIGradient", { Rotation = 90, Parent = obj })
        obj.BackgroundColor3 = Color3.new(1, 1, 1)
        Theme.bind(gradient, "Color", function(T) return ColorSequence.new(resolve(top), resolve(bottom)) end)
        return gradient
    end

    function Theme:Get(token)
        return resolve(token)
    end

    function Theme.bound(obj)
        local props = registry[obj]
        return props and Util.copy(props) or nil
    end

    function Theme.dead(obj)
        return watched[obj] == "dead"
    end

    function Theme.count()
        local n = 0
        for _ in pairs(registry) do n = n + 1 end
        return n
    end

    function Theme.PresetData(name)
        for _, preset in ipairs(PRESETS) do
            if preset[1] == name then return Util.copy(preset[2]) end
        end
        return nil
    end

    function Theme:Set(partial)
        if type(partial) ~= "table" then return false end
        local base = Theme.Base
        local followHl = partial.ddHl == nil and Util.toHex(Util.hex(base.ddHl)) == Util.toHex(Util.hex(base.accent))
        for _, key in ipairs(KEYS) do
            local color = Util.hex(partial[key])
            if color then base[key] = Util.toHex(color) end
        end
        if STYLES[partial.style] then base.style = partial.style end
        if followHl and partial.accent then base.ddHl = base.accent end
        derive()
        for obj, props in pairs(registry) do
            for prop, token in pairs(props) do paint(obj, prop, token) end
        end
        Theme.Changed:Fire(Theme.T)
        return true
    end

    function Theme:Preset(name)
        for _, preset in ipairs(PRESETS) do
            if preset[1] == name then return self:Set(preset[2]) end
        end
        return false
    end

    function Theme:Name()
        for _, preset in ipairs(PRESETS) do
            local same = preset[2].style == Theme.Base.style
            for _, key in ipairs(KEYS) do
                if preset[2][key] ~= Theme.Base[key] then same = false end
            end
            if same then return preset[1] end
        end
        return "custom"
    end

    function Theme:Export()
        return Util.copy(Theme.Base)
    end

    derive()
end

-- [src] 06_text.lua
do
    Text.Styles = {
        body = { enum = Enum.Font.Arial, size = 12 },
        bold = { enum = Enum.Font.ArialBold, size = 12 },
        brand = { enum = Enum.Font.ArialBold, size = 14 },
        small = { enum = Enum.Font.Arial, size = 10, caps = true },
        tiny = { enum = Enum.Font.Arial, size = 10 },
    }
    local cache = {}

    function Text.caps(style, text)
        local spec = Text.Styles[style] or Text.Styles.body
        return spec.caps and string.upper(text) or text
    end

    function Text.style(obj, style)
        local spec = Text.Styles[style] or Text.Styles.body
        if spec.face then obj.FontFace = spec.face else obj.Font = spec.enum end
        obj.TextSize = spec.size
        return obj
    end

    function Text.size(text, style)
        local spec = Text.Styles[style] or Text.Styles.body
        text = Text.caps(style, tostring(text))
        local key = (style or "body") .. "\0" .. text
        local hit = cache[key]
        if hit then return hit end
        local ok, bounds = pcall(function()
            return TextService:GetTextSize(text, spec.size, spec.enum, Vector2.new(10000, 10000))
        end)
        hit = ok and Vector2.new(math.ceil(bounds.X), math.ceil(bounds.Y)) or Vector2.new(#text * 6, spec.size)
        cache[key] = hit
        return hit
    end

    function Text.width(text, style)
        return Text.size(text, style).X
    end
end

-- [src] 08_input.lua
do
    local MOUSE = {
        [Enum.UserInputType.MouseButton1] = "m1",
        [Enum.UserInputType.MouseButton2] = "m2",
        [Enum.UserInputType.MouseButton3] = "m3",
    }
    local keyHandlers = Util.Signal.new()
    local captured

    local GuiService = Exec.service("GuiService")

    function Input.inset()
        local ok, inset = pcall(function() return GuiService:GetGuiInset() end)
        if ok and typeof(inset) == "Vector2" then return inset end
        return Vector2.new(0, 0)
    end

    function Input.mouse()
        return UserInputService:GetMouseLocation()
    end

    function Input.guiMouse()
        return UserInputService:GetMouseLocation() - Input.inset()
    end

    function Input.rect(gui)
        local pos, size = gui.AbsolutePosition + Input.inset(), gui.AbsoluteSize
        return pos.X, pos.Y, size.X, size.Y
    end

    function Input.over(gui, point)
        if not gui then return false end
        point = point or Input.mouse()
        local x, y, w, h = Input.rect(gui)
        return point.X >= x and point.Y >= y and point.X < x + w and point.Y < y + h
    end

    function Input.shift()
        local ok, down = pcall(function()
            return UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
        end)
        return ok and down or false
    end

    function Input.keyName(input)
        local name = MOUSE[input.UserInputType]
        if name then return name end
        if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode then
            local key = input.KeyCode.Name
            if key == "Unknown" then return nil end
            return string.lower(key)
        end
        return nil
    end

    function Input.ctrl()
        local ok, down = pcall(function() return UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) end)
        return ok and down or false
    end

    function Input.onKey(fn)
        return keyHandlers:Connect(fn)
    end

    function Input.capture(move, up)
        if captured then captured(true) end
        local maid = Util.Maid.new()
        local function finish(cancelled)
            if captured ~= finish then return end
            captured = nil
            maid:Clean()
            if up then Util.guard(up, Input.mouse(), cancelled == true) end
        end
        captured = finish
        maid:Add(UserInputService.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement and move then Util.guard(move, Input.mouse()) end
        end))
        maid:Add(UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then finish(false) end
        end))
        return function() finish(true) end
    end

    local function relay(down)
        return function(input, processed)
            local name = Input.keyName(input)
            if name then keyHandlers:Fire(name, down, input, processed) end
        end
    end
    Aster._maid:Add(UserInputService.InputBegan:Connect(relay(true)))
    Aster._maid:Add(UserInputService.InputEnded:Connect(relay(false)))
    Aster._maid:Add(function()
        if captured then captured(true) end
        keyHandlers:Destroy()
    end)
end

-- [src] 10_store.lua
do
    local data
    local memory = { configs = {}, autoload = nil }
    Store.Root = "aster2/" .. tostring(game.PlaceId)
    Store.Selected = "default"
    Store.Changed = Util.Signal.new()

    local function path(name)
        return Store.Root .. "/" .. name
    end

    local function ensureFolders()
        if not Exec.hasFs then return false end
        local built = ""
        for part in string.gmatch(Store.Root .. "/configs", "[^/]+") do
            built = built == "" and part or built .. "/" .. part
            pcall(function()
                if not (Exec.fs.isfolder and Exec.fs.isfolder(built)) then Exec.fs.makefolder(built) end
            end)
        end
        return true
    end

    local function readFile(file)
        if not Exec.hasFs then return nil end
        local ok, text = pcall(function()
            if Exec.fs.isfile(file) then return Exec.fs.read(file) end
            return nil
        end)
        if ok and type(text) == "string" then return text end
        return nil
    end

    local function writeFile(file, text)
        if not Exec.hasFs then return false end
        ensureFolders()
        return (pcall(Exec.fs.write, file, text))
    end

    local function load()
        if data then return data end
        data = {}
        local decoded = Util.unjson(readFile(path("ui.json")))
        if type(decoded) == "table" then data = decoded end
        return data
    end

    local function warnMemory()
        if Store._warned then return end
        Store._warned = true
        print("[aster] no file API, settings are kept in memory only")
    end

    function Store.init(folder)
        if type(folder) == "string" and folder ~= "" then Store.Root = "aster2/" .. folder end
        data = nil
        ensureFolders()
    end

    function Store.get(key, default, fix)
        local value = load()[key]
        if value == nil then return default end
        if fix then
            local ok, fixed = pcall(fix, value)
            if not ok or fixed == nil then return default end
            return fixed
        end
        return value
    end

    function Store.put(key, value)
        load()[key] = value
        if not Exec.hasFs then
            warnMemory()
            return false
        end
        local text = Util.json(data)
        if not text then return false end
        return writeFile(path("ui.json"), text)
    end

    local fix = {}
    Store.fix = fix

    local function isMap(v)
        if type(v) ~= "table" then return false end
        for k in pairs(v) do
            if type(k) ~= "string" then return false end
        end
        return true
    end
    local function finite(n)
        return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
    end
    fix.isMap, fix.finite = isMap, finite

    function fix.bool(v)
        if type(v) == "boolean" then return v end
        return nil
    end

    function fix.pair(v)
        if type(v) == "table" and #v == 2 and finite(v[1]) and finite(v[2]) then return { v[1], v[2] } end
        return nil
    end

    function fix.flags(v)
        if not isMap(v) then return nil end
        local out = {}
        for k, x in pairs(v) do
            if type(x) == "boolean" then out[k] = x end
        end
        return out
    end

    function fix.sizes(v)
        if not isMap(v) then return nil end
        local out = {}
        for k, x in pairs(v) do
            if finite(x) and x > 0 then out[k] = Util.snap(x) end
        end
        return out
    end

    function fix.strings(v)
        if not isMap(v) then return nil end
        local out = {}
        for k, x in pairs(v) do
            if type(x) == "string" then out[k] = x end
        end
        return out
    end

    function fix.layouts(v)
        if not isMap(v) then return nil end
        local out = {}
        for k, cols in pairs(v) do
            local good = type(cols) == "table" and #cols == 2
            if good then
                for _, ids in ipairs(cols) do
                    if type(ids) ~= "table" then
                        good = false
                    else
                        for _, id in ipairs(ids) do
                            if type(id) ~= "string" then good = false end
                        end
                    end
                end
            end
            if good then out[k] = { Util.copy(cols[1]), Util.copy(cols[2]) } end
        end
        return out
    end

    function Store.cfgName(v)
        v = string.lower(tostring(v or ""))
        v = string.gsub(v, "^%s+", "")
        v = string.gsub(v, "%s+$", "")
        v = string.gsub(v, "[^a-z0-9 _%-]", "")
        return string.sub(v, 1, 24)
    end

    local function cfgPath(name)
        return path("configs/" .. name .. ".json")
    end

    function Store.encode()
        local flags = {}
        for flag, el in pairs(Aster.Elements) do
            local kind = Kinds[el.Kind]
            if kind and kind.default ~= nil and el.Opts.save ~= false then
                local value = el.Value
                if kind.encode then
                    local ok, encoded = pcall(kind.encode, value, el.Opts, el)
                    value = ok and encoded or nil
                elseif typeof(value) == "Color3" then
                    value = Util.toHex(value)
                end
                if value ~= nil and Util.json({ value }) then
                    flags[flag] = value
                elseif value ~= nil then
                    warn("[aster] cannot save flag " .. tostring(flag))
                end
            end
        end
        return { version = 1, saved = os.time(), flags = flags }
    end

    function Store.apply(config)
        if type(config) ~= "table" or not isMap(config.flags) then return false end
        local count = 0
        for flag, raw in pairs(config.flags) do
            local el = Aster.Elements[flag]
            local kind = el and Kinds[el.Kind]
            if kind and kind.default ~= nil and el.Opts.save ~= false then
                local value = raw
                if kind.decode then
                    local ok, decoded = pcall(kind.decode, raw, el.Opts, el)
                    value = ok and decoded or nil
                end
                if value ~= nil and el:Set(value) then count = count + 1 end
            end
        end
        return true, count
    end

    function Store.exists(name)
        name = Store.cfgName(name)
        if name == "" then return false end
        if not Exec.hasFs then return memory.configs[name] ~= nil end
        local ok, found = pcall(Exec.fs.isfile, cfgPath(name))
        return ok and found == true
    end

    local function readConfig(name)
        local text
        if Exec.hasFs then text = readFile(cfgPath(name)) else text = memory.configs[name] end
        local decoded = Util.unjson(text)
        if type(decoded) == "table" then return decoded end
        return nil
    end

    function Store.list()
        local names = {}
        if Exec.hasFs then
            ensureFolders()
            local ok, files = pcall(function() return Exec.fs.list and Exec.fs.list(path("configs")) or {} end)
            for _, file in ipairs(ok and files or {}) do
                local name = string.match(string.gsub(tostring(file), "\\", "/"), "([^/]+)%.json$")
                if name then names[#names + 1] = name end
            end
        else
            for name in pairs(memory.configs) do names[#names + 1] = name end
        end
        table.sort(names)
        local out = {}
        for _, name in ipairs(names) do
            local config = readConfig(name)
            out[#out + 1] = { name = name, saved = config and tonumber(config.saved) or nil }
        end
        return out
    end

    function Store.save(name)
        name = Store.cfgName(name or Store.Selected)
        if name == "" then return false, "bad name" end
        local text = Util.json(Store.encode())
        if not text then return false, "encode failed" end
        if Exec.hasFs then
            if not writeFile(cfgPath(name), text) then return false, "write failed" end
        else
            warnMemory()
            memory.configs[name] = text
        end
        Store.Selected = name
        Store.Changed:Fire("save", name)
        return true
    end

    function Store.load(name)
        name = Store.cfgName(name or Store.Selected)
        local config = readConfig(name)
        if not config then return false, "no config " .. name end
        local ok, count = Store.apply(config)
        if not ok then return false, "bad config " .. name end
        Store.Selected = name
        Store.Changed:Fire("load", name)
        return true, count
    end

    function Store.delete(name)
        name = Store.cfgName(name)
        if not Store.exists(name) then return false end
        if Exec.hasFs then
            if not (Exec.fs.delete and pcall(Exec.fs.delete, cfgPath(name))) then return false end
        else
            memory.configs[name] = nil
        end
        if Store.getAutoload() == name then Store.autoload(nil) end
        Store.Changed:Fire("delete", name)
        return true
    end

    function Store.rename(old, new)
        old, new = Store.cfgName(old), Store.cfgName(new)
        if new == "" or old == new or not Store.exists(old) or Store.exists(new) then return false end
        local text = Exec.hasFs and readFile(cfgPath(old)) or memory.configs[old]
        if not text then return false end
        if Exec.hasFs then
            if not writeFile(cfgPath(new), text) then return false end
            pcall(Exec.fs.delete, cfgPath(old))
        else
            memory.configs[new], memory.configs[old] = text, nil
        end
        if Store.getAutoload() == old then Store.autoload(new) end
        if Store.Selected == old then Store.Selected = new end
        Store.Changed:Fire("rename", new, old)
        return true
    end

    function Store.duplicate(name, new)
        name = Store.cfgName(name)
        if not Store.exists(name) then return false, "no config " .. name end
        if new == nil then
            new = Store.cfgName(name .. " copy")
            local i = 2
            while Store.exists(new) and i < 100 do
                new = Store.cfgName(name .. " copy " .. i)
                i = i + 1
            end
        else
            new = Store.cfgName(new)
        end
        if new == "" or new == name or Store.exists(new) then return false, "bad name" end
        local text = Exec.hasFs and readFile(cfgPath(name)) or memory.configs[name]
        if not text then return false, "read failed" end
        if Exec.hasFs then
            if not writeFile(cfgPath(new), text) then return false, "write failed" end
        else
            memory.configs[new] = text
        end
        Store.Selected = new
        Store.Changed:Fire("duplicate", new, name)
        return true, new
    end

    function Store.autoload(name)
        name = name and Store.cfgName(name) or nil
        if name == "" then name = nil end
        if Exec.hasFs then
            if name then
                writeFile(path("autoload.txt"), name)
            elseif Exec.fs.delete then
                pcall(function()
                    if Exec.fs.isfile(path("autoload.txt")) then Exec.fs.delete(path("autoload.txt")) end
                end)
            end
        else
            memory.autoload = name
        end
        Store.Changed:Fire("autoload", name)
        return true
    end

    function Store.getAutoload()
        local name
        if Exec.hasFs then name = readFile(path("autoload.txt")) else name = memory.autoload end
        name = name and Store.cfgName(name) or nil
        if name == "" then return nil end
        return name
    end

    function Store.runAutoload()
        local name = Store.getAutoload()
        if not name or not Store.exists(name) then return false end
        return Store.load(name)
    end
end

-- [src] 12_element.lua
do
    local LINE, PAD, GAP, INDENT, LEAD = 20, 8, 4, 16, 8
    Element.LINE, Element.PAD, Element.GAP, Element.INDENT, Element.LEAD = LINE, PAD, GAP, INDENT, LEAD
    Element.__index = Element
    Container.__index = Container

    Aster.Flags = {}
    Aster.Elements = {}
    Aster.Changed = Util.Signal.new()
    Aster._index = {}
    local public, state = {}, {}
    local anyState = Util.Signal.new()

    local function signal(map, flag)
        local found = map[flag]
        if not found then
            found = Util.Signal.new()
            map[flag] = found
        end
        return found
    end

    function Aster:OnChanged(flag, fn)
        return signal(public, flag):Connect(fn)
    end

    function Aster:Set(flag, value, silent)
        local el = self.Elements[flag]
        if not el then return false end
        return el:Set(value, silent)
    end

    function Aster:Get(flag)
        return self.Flags[flag]
    end

    setmetatable(Kinds, {
        __newindex = function(t, name, spec)
            assert(type(spec) == "table" and type(spec.method) == "string" and type(spec.build) == "function", "Kinds." .. tostring(name) .. " needs method and build")
            assert(Container[spec.method] == nil, "Container:" .. spec.method .. " already exists")
            spec.name = name
            local class = spec.methods or {}
            class.__index = class
            spec.class = setmetatable(class, Element)
            rawset(t, name, spec)
            Container[spec.method] = function(self, opts) return self:_add(name, opts) end
            if spec.slot then
                assert(Element[spec.method] == nil, "Element:" .. spec.method .. " already exists")
                Element[spec.method] = function(self, opts) return self:_attach(name, opts) end
            end
        end,
    })

    local function check(kind, opts, value)
        if value == nil then return nil end
        if not kind.validate then return value end
        local ok, result = pcall(kind.validate, opts, value)
        if ok then return result end
        return nil
    end

    local function slotWidth(kind, opts)
        if type(kind.slot) == "function" then return kind.slot(opts) end
        return kind.slot
    end

    local function truthy(value)
        if value == nil or value == false or value == 0 or value == "" then return false end
        if type(value) == "table" and next(value) == nil then return false end
        return true
    end

    local function isElement(value)
        return type(value) == "table" and rawget(value, "Kind") ~= nil and rawget(value, "_state") ~= nil
    end

    local function remove(list, item)
        for index = #list, 1, -1 do
            if list[index] == item then table.remove(list, index) end
        end
    end

    function Element._new(kind, opts, container, parent, host)
        opts = opts or {}
        local el = setmetatable({
            Kind = kind.name, Opts = opts, Flag = opts.flag, Container = container, Parent = parent,
            Visible = true, Disabled = false, Lit = false, Hover = false, Attached = {},
            Changed = Util.Signal.new(), Shown = Util.Signal.new(), _state = Util.Signal.new(), _maid = Util.Maid.new(),
        }, kind.class)
        el._maid:Add(el.Changed)
        el._maid:Add(el.Shown)
        el._maid:Add(el._state)

        if kind.default ~= nil then
            local value = check(kind, opts, opts.default)
            if value == nil then
                local fallback = kind.default
                if type(fallback) == "function" then fallback = fallback(opts) end
                value = check(kind, opts, fallback)
                if value == nil then value = fallback end
            end
            el.Value = value
            if el.Flag then
                if Aster.Elements[el.Flag] then warn("[aster] duplicate flag " .. tostring(el.Flag)) end
                Aster.Elements[el.Flag] = el
                Aster.Flags[el.Flag] = value
            end
        end

        if parent then
            el.Row = parent.Row
            el.Slot = host
            parent.Attached[#parent.Attached + 1] = el
        else
            el:_row(kind)
            if kind.slot then
                host = el:_slot(slotWidth(kind, opts))
                el.Slot = host
            else
                host = el.Row
            end
            container.Elements[#container.Elements + 1] = el
        end
        el._wasShown = el:IsShown()

        local ok, result = pcall(kind.build, el, host)
        if not ok then
            warn("[aster] " .. kind.name .. " build: " .. tostring(result))
            result = nil
        end
        el:_paint()
        if opts.depends ~= nil then el:_depends(opts.depends) end
        if opts.disabled then el:SetDisabled(true) end
        if opts.visible == false then el:SetVisible(false) end
        if opts.name and not parent and kind.index ~= false then el:_index(opts.name, container.Path) end
        if opts.tip and Layer.tip then el._maid:Add(Layer.tip(el.Slot or el.Row, opts.tip)) end
        if not parent then container:_layout() end
        if result ~= nil and result ~= false then return result end
        return el
    end

    function Element:_row(kind)
        local opts = self.Opts
        local indent = opts.depends ~= nil and opts.indent ~= false
        local row = Util.new("Frame", {
            Name = tostring(opts.flag or kind.name), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, LINE), Parent = self.Container.Frame,
        })
        self.Row = row
        self.X = PAD + (indent and INDENT or 0)
        self._used = 0
        self._maid:Add(row)
        if indent then
            Util.new("Frame", { Name = "Dep", Position = UDim2.fromOffset(PAD + 4, 0), Size = UDim2.new(0, 1, 1, 0), Theme = { BackgroundColor3 = "ln2" }, Parent = row })
        end
        if kind.label ~= false and opts.name then
            self.Label = Util.new("TextLabel", {
                Name = "Label", Text = tostring(opts.name), TextStyle = "body", TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd, Parent = row,
            })
            self:_labelPaint()
            self:_fit()
        end
        self._shade = Util.new("Frame", {
            Name = "Shade", Visible = false, Active = true, ZIndex = 50, BackgroundTransparency = 0.38,
            Size = UDim2.fromScale(1, 1), Theme = { BackgroundColor3 = self.Container.Bg }, Parent = row,
        })
        self._maid:Add(row.MouseEnter:Connect(function()
            if self.Disabled or (Layer.active and Layer.active()) then return end
            self:_hover(true)
        end))
        self._maid:Add(row.MouseLeave:Connect(function() self:_hover(false) end))
    end

    function Element:_labelPaint()
        if not self.Label then return end
        Theme.bind(self.Label, "TextColor3", function(T)
            return (self.Lit or self.Hover) and T.tx or T.tx2
        end)
    end

    function Element:_hover(on)
        on = on and true or false
        if self.Hover == on then return end
        self.Hover = on
        self.Row.BackgroundTransparency = on and 0.978 or 1
        self:_labelPaint()
        self:_paint()
    end

    function Element:_light(on)
        self.Lit = on and true or false
        self:_labelPaint()
    end

    function Element:_fit()
        if not self.Label then return end
        local right = self._used > 0 and (self._used - GAP + LEAD) or 0
        self.Label.Position = UDim2.fromOffset(self.X, 0)
        self.Label.Size = UDim2.new(1, -(self.X + PAD + right), 0, LINE)
    end

    function Element:_lead(width)
        if self.Parent then return self.Parent:_lead(width) end
        local frame = Util.new("Frame", { Name = "Lead", BackgroundTransparency = 1, Position = UDim2.fromOffset(self.X, 0), Size = UDim2.fromOffset(width, LINE), Parent = self.Row })
        self.X = self.X + width + LEAD
        self:_fit()
        return frame
    end

    function Element:_slot(width)
        if self.Parent then return self.Parent:_slot(width) end
        width = Util.snap(width or LINE)
        local frame = Util.new("Frame", {
            Name = "Slot", BackgroundTransparency = 1, Position = UDim2.new(1, -(PAD + self._used + width), 0, 0),
            Size = UDim2.fromOffset(width, LINE), Parent = self.Row,
        })
        self._used = self._used + width + GAP
        self:_fit()
        return frame
    end

    function Element:_attach(name, opts)
        local kind = Kinds[name]
        assert(kind and kind.slot, "kind " .. tostring(name) .. " cannot attach")
        local host = self:_slot(slotWidth(kind, opts or {}))
        return Element._new(kind, opts, self.Container, self, host)
    end

    function Element:_index(label, path)
        local entry = { Label = tostring(label), Lower = string.lower(tostring(label)), Path = Util.copy(path or {}), Element = self }
        Aster._index[#Aster._index + 1] = entry
        self._indexed = self._indexed or {}
        self._indexed[#self._indexed + 1] = entry
        return entry
    end

    function Element:_height()
        local kind = Kinds[self.Kind]
        local height = kind.height or LINE
        if type(height) == "function" then
            local ok, result = pcall(height, self, self.Container.Width)
            height = ok and tonumber(result) or LINE
        end
        return Util.snap(height)
    end

    function Element:_relayout()
        if self.Parent then return self.Parent:_relayout() end
        self.Container:_layout()
    end

    function Element:_paint()
        local kind = Kinds[self.Kind]
        if kind.paint then Util.guard(kind.paint, self) end
    end

    function Element:_refresh()
        local off = (self._manualOff or self._depOff or (self.Parent ~= nil and self.Parent.Disabled)) and true or false
        if off ~= self.Disabled then
            self.Disabled = off
            if self._shade then self._shade.Visible = off end
            if off and self.Hover then self:_hover(false) end
            self:_paint()
        end
        for _, child in ipairs(self.Attached) do child:_refresh() end
    end

    function Element:_shown()
        local now = self:IsShown()
        if now ~= self._wasShown then
            self._wasShown = now
            self.Shown:Fire(now)
        end
        for _, child in ipairs(self.Attached) do child:_shown() end
    end

    function Element:_depends(dep)
        local function test()
            if type(dep) == "function" then
                local ok, result = pcall(dep)
                return ok and truthy(result)
            elseif type(dep) == "string" then
                return truthy(Aster.Flags[dep])
            elseif isElement(dep) then
                return truthy(dep.Value)
            elseif type(dep) == "table" then
                local value = Aster.Flags[dep[1] or dep.flag]
                local want = dep[2]
                if want == nil then want = dep.value end
                if want == nil then return truthy(value) end
                if type(want) == "table" then
                    for _, option in ipairs(want) do
                        if option == value then return true end
                    end
                    return false
                end
                return value == want
            end
            return true
        end
        local function update()
            self._depOff = not test()
            self:_refresh()
        end
        if type(dep) == "function" then
            self._maid:Add(anyState:Connect(update))
        elseif type(dep) == "string" then
            self._maid:Add(signal(state, dep):Connect(update))
        elseif isElement(dep) then
            self._maid:Add(dep._state:Connect(update))
        elseif type(dep) == "table" then
            self._maid:Add(signal(state, dep[1] or dep.flag):Connect(update))
        end
        update()
    end

    function Element:Get()
        return self.Value
    end

    function Element:Set(value, silent)
        local kind = Kinds[self.Kind]
        if kind.default == nil then return false end
        local checked = check(kind, self.Opts, value)
        if checked == nil then return false end
        if (kind.equal or Util.same)(checked, self.Value) then return true end
        self.Value = checked
        local flag = self.Flag
        if flag and Aster.Elements[flag] == self then Aster.Flags[flag] = checked end
        self:_paint()
        self._state:Fire(checked)
        if flag and state[flag] then state[flag]:Fire(checked) end
        anyState:Fire(flag, checked)
        if not silent then
            if self.Opts.callback then Util.guard(self.Opts.callback, checked, self) end
            self.Changed:Fire(checked, self)
            if flag and public[flag] then public[flag]:Fire(checked, self) end
            Aster.Changed:Fire(flag, checked, self)
        end
        return true
    end

    function Element:OnChanged(fn)
        return self.Changed:Connect(fn)
    end

    function Element:IsShown()
        if not self.Visible or self.Destroyed then return false end
        if self.Parent then return self.Parent:IsShown() end
        return self.Container:IsShown()
    end

    function Element:SetVisible(visible)
        visible = visible ~= false
        if self.Visible == visible then return end
        self.Visible = visible
        if self.Parent then
            self.Slot.Visible = visible
        else
            self.Row.Visible = visible
            self.Container:_layout()
        end
        self:_shown()
    end

    function Element:SetDisabled(disabled)
        self._manualOff = disabled ~= false
        self:_refresh()
    end

    function Element:Destroy()
        if self.Destroyed then return end
        self.Destroyed = true
        for index = #self.Attached, 1, -1 do self.Attached[index]:Destroy() end
        local kind = Kinds[self.Kind]
        if kind.destroy then Util.guard(kind.destroy, self) end
        if self.Flag and Aster.Elements[self.Flag] == self then
            Aster.Elements[self.Flag] = nil
            Aster.Flags[self.Flag] = nil
        end
        for _, entry in ipairs(self._indexed or {}) do remove(Aster._index, entry) end
        self._maid:Clean()
        if self.Parent then
            remove(self.Parent.Attached, self)
            if self.Slot then self.Slot:Destroy() end
        else
            remove(self.Container.Elements, self)
            self.Container:_layout()
        end
    end

    function Container.new(frame, opts)
        opts = opts or {}
        local width = opts.width
        if not width then
            local ok, size = pcall(function() return frame.AbsoluteSize.X end)
            width = ok and size or 0
        end
        local c = setmetatable({
            Frame = frame, Width = Util.snap(width), Height = -1, Elements = {}, Path = opts.path or {}, Bg = opts.bg or "panel",
            PadTop = opts.padTop or 0, PadBottom = opts.padBottom or 0, AutoSize = opts.autosize ~= false,
            Resized = Util.Signal.new(), Shown = Util.Signal.new(), _isShown = opts.shown == true,
        }, Container)
        c:_layout()
        return c
    end

    function Container:_add(name, opts)
        local kind = Kinds[name]
        assert(kind, "unknown kind " .. tostring(name))
        return Element._new(kind, opts, self)
    end

    function Container:_layout()
        local y = self.PadTop
        for _, el in ipairs(self.Elements) do
            if el.Visible then
                local height = el:_height()
                el.Row.Position = UDim2.fromOffset(0, y)
                el.Row.Size = UDim2.new(1, 0, 0, height)
                y = y + height
            end
        end
        y = y + self.PadBottom
        if self.AutoSize then
            local size = self.Frame.Size
            self.Frame.Size = UDim2.new(size.X.Scale, size.X.Offset, 0, y)
        end
        if y ~= self.Height then
            self.Height = y
            self.Resized:Fire(y)
        end
        return y
    end

    function Container:_resize(width)
        self.Width = Util.snap(width)
        local function visit(el)
            local kind = Kinds[el.Kind]
            if kind.resize then Util.guard(kind.resize, el, self.Width) end
            for _, child in ipairs(el.Attached) do visit(child) end
        end
        for _, el in ipairs(self.Elements) do visit(el) end
        self:_layout()
    end

    function Container:IsShown()
        return self._isShown and not self.Destroyed
    end

    function Container:_show(shown)
        shown = shown and true or false
        if self._isShown == shown then return end
        self._isShown = shown
        self.Shown:Fire(shown)
        for _, el in ipairs(self.Elements) do el:_shown() end
    end

    function Container:Destroy()
        if self.Destroyed then return end
        local list = table.move(self.Elements, 1, #self.Elements, 1, {})
        for index = #list, 1, -1 do list[index]:Destroy() end
        self.Destroyed = true
        self.Resized:Destroy()
        self.Shown:Destroy()
    end
end

-- [src] 15_anim.lua
do
    Anim.Times = { fade = 0.14, move = 0.18, intro = 0.2, bar = 0.24, trail = 0.4 }
    Anim.calm = false
    Anim.Changed = Util.Signal.new()

    function Anim.bezier(x1, y1, x2, y2)
        local cx = 3 * x1
        local bx = 3 * (x2 - x1) - cx
        local ax = 1 - cx - bx
        local cy = 3 * y1
        local by = 3 * (y2 - y1) - cy
        local ay = 1 - cy - by
        return function(k)
            if k <= 0 then return 0 end
            if k >= 1 then return 1 end
            local t = k
            for _ = 1, 6 do
                local x = ((ax * t + bx) * t + cx) * t - k
                local d = (3 * ax * t + 2 * bx) * t + cx
                if math.abs(x) < 1e-4 or d == 0 then break end
                t = t - x / d
            end
            return ((ay * t + by) * t + cy) * t
        end
    end
    Anim.ease = Anim.bezier(0.2, 0.7, 0.2, 1)
    Anim.linear = function(k) return k end
    Anim.sine = function(k) return 0.5 - math.cos(k * math.pi) / 2 end

    local tracks, props, values = {}, setmetatable({}, { __mode = "k" }), {}
    local conn

    local function lerp(a, b, t)
        local kind = typeof(a)
        if kind == "number" then return a + (b - a) * t end
        if kind == "UDim2" then
            return UDim2.new(a.X.Scale + (b.X.Scale - a.X.Scale) * t, Util.snap(a.X.Offset + (b.X.Offset - a.X.Offset) * t),
                a.Y.Scale + (b.Y.Scale - a.Y.Scale) * t, Util.snap(a.Y.Offset + (b.Y.Offset - a.Y.Offset) * t))
        end
        if kind == "Color3" then
            return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
        end
        if kind == "Vector2" then return Vector2.new(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t) end
        if kind == "UDim" then return UDim.new(a.Scale + (b.Scale - a.Scale) * t, Util.snap(a.Offset + (b.Offset - a.Offset) * t)) end
        if t >= 1 then return b end
        return a
    end
    Anim.lerp = lerp

    function Anim.time(kind)
        if Anim.calm then return 0 end
        if type(kind) == "number" then return kind end
        return Anim.Times[kind or "move"] or Anim.Times.move
    end

    local function release(track)
        track.dead = true
        if track.obj then
            local map = props[track.obj]
            if map then
                for prop in pairs(track.to) do
                    if map[prop] == track then map[prop] = nil end
                end
            end
        elseif track.key ~= nil and values[track.key] == track then
            values[track.key] = nil
        end
    end

    local function apply(track, e)
        if track.obj then
            for prop, goal in pairs(track.to) do
                local token = track.tokens and track.tokens[prop]
                if token ~= nil then goal = Theme:Get(token) or goal end
                local value = lerp(track.from[prop], goal, e)
                pcall(function() track.obj[prop] = value end)
            end
        elseif track.step then
            Util.guard(track.step, track.from + (track.to - track.from) * e, e)
        end
    end

    local function finish(track)
        if track.dead then return end
        apply(track, 1)
        release(track)
        if track.tokens and not Theme.dead(track.obj) then
            for prop, token in pairs(track.tokens) do
                if track.to[prop] ~= nil then Theme.bind(track.obj, prop, token) end
            end
        end
        if track.done then Util.guard(track.done) end
    end

    local function step(dt)
        if #tracks == 0 then return end
        local list = tracks
        tracks = {}
        local keep = {}
        for _, track in ipairs(list) do
            if not track.dead then
                if track.tick then
                    local ok, more = Util.guard(track.tick, dt)
                    if not ok or not more or track.dead then
                        track.dead = true
                    else
                        keep[#keep + 1] = track
                    end
                else
                    track.elapsed = track.elapsed + dt
                    local k = track.duration > 0 and math.min(1, track.elapsed / track.duration) or 1
                    if k >= 1 then
                        finish(track)
                    else
                        apply(track, track.ease(k))
                        keep[#keep + 1] = track
                    end
                end
            end
        end
        for _, track in ipairs(tracks) do keep[#keep + 1] = track end
        tracks = keep
        if #tracks == 0 and conn then
            conn:Disconnect()
            conn = nil
        end
    end

    local function start(track)
        tracks[#tracks + 1] = track
        if not conn and not Aster.Unloaded then
            conn = RunService.RenderStepped:Connect(step)
        end
        return track
    end

    local Handle = {}
    Handle.__index = Handle
    function Handle:Stop()
        if self.dead then return end
        release(self)
    end
    function Handle:Finish()
        finish(self)
    end
    function Handle:Running()
        return not self.dead
    end

    local function dead(done)
        if done then Util.guard(done) end
        return setmetatable({ dead = true }, Handle)
    end

    function Anim.stop(obj, prop)
        local map = props[obj]
        if not map then return end
        if prop then
            local track = map[prop]
            if track then
                track.to[prop] = nil
                track.from[prop] = nil
                map[prop] = nil
                if next(track.to) == nil then track.dead = true end
            end
        else
            for name, track in pairs(map) do
                track.to[name] = nil
                if next(track.to) == nil then track.dead = true end
            end
            props[obj] = nil
        end
    end

    function Anim.running(obj, prop)
        local map = props[obj]
        if not map then return false end
        if prop then return map[prop] ~= nil end
        return next(map) ~= nil
    end

    function Anim.to(obj, goals, kind, done, ease)
        local duration = Anim.time(kind)
        local tokens
        for prop, goal in pairs(goals) do
            Anim.stop(obj, prop)
            if type(goal) == "string" or type(goal) == "function" then
                tokens = tokens or {}
                tokens[prop] = goal
                Theme.unbind(obj, prop)
            end
        end
        if duration <= 0 then
            for prop, goal in pairs(goals) do
                if tokens and tokens[prop] then Theme.bind(obj, prop, goal) else pcall(function() obj[prop] = goal end) end
            end
            return dead(done)
        end
        local track = setmetatable({ obj = obj, from = {}, to = {}, tokens = tokens, elapsed = 0, duration = duration, ease = ease or Anim.ease, done = done }, Handle)
        local map = props[obj]
        if not map then
            map = {}
            props[obj] = map
        end
        for prop, goal in pairs(goals) do
            if tokens and tokens[prop] then goal = Theme:Get(goal) end
            local ok, now = pcall(function() return obj[prop] end)
            track.from[prop] = ok and now or goal
            track.to[prop] = goal
            map[prop] = track
        end
        return start(track)
    end

    function Anim.value(key, from, to, kind, stepFn, done, ease)
        if key ~= nil and values[key] then release(values[key]) end
        local duration = Anim.time(kind)
        if duration <= 0 or from == to then
            Util.guard(stepFn, to, 1)
            return dead(done)
        end
        local track = setmetatable({ key = key, from = from, to = to, step = stepFn, elapsed = 0, duration = duration, ease = ease or Anim.ease, done = done }, Handle)
        if key ~= nil then values[key] = track end
        return start(track)
    end

    function Anim.loop(fn)
        return start(setmetatable({ tick = fn }, Handle))
    end

    function Anim.after(seconds, fn)
        local left = seconds
        local handle
        handle = Anim.loop(function(dt)
            left = left - dt
            if left > 0 then return true end
            Util.guard(fn)
            return false
        end)
        if seconds <= 0 then
            handle:Stop()
            Util.guard(fn)
        end
        return handle
    end

    function Anim.follow(current, apply, rate)
        rate = rate or 0.25
        local f = setmetatable({ Value = current, Target = current }, Handle)
        local function close(cur, aim, q)
            if type(cur) == "number" then
                if math.abs(aim - cur) < 0.3 then return aim end
                return cur + (aim - cur) * q
            end
            local x = math.abs(aim.X - cur.X) < 0.3 and aim.X or cur.X + (aim.X - cur.X) * q
            local y = math.abs(aim.Y - cur.Y) < 0.3 and aim.Y or cur.Y + (aim.Y - cur.Y) * q
            return Vector2.new(x, y)
        end
        f.tick = function(dt)
            local q = Anim.calm and 1 or 1 - rate ^ math.min(4, dt * 60)
            local nextValue = close(f.Value, f.Target, q)
            if nextValue ~= f.Value then
                f.Value = nextValue
                Util.guard(apply, nextValue)
            end
            return true
        end
        function f.Snap()
            f.Value = f.Target
            Util.guard(apply, f.Value)
        end
        function f.Set(target)
            f.Target = target
            if Anim.calm then f.Snap() end
        end
        function f.Settled()
            return f.Value == f.Target
        end
        return start(f)
    end
    Anim.lerpFollow = Anim.follow

    function Anim.coalesce(apply)
        local pending, loop
        local c = {}
        local function run()
            if pending == nil then return end
            local value = pending
            pending = nil
            Util.guard(apply, value)
        end
        function c.Push(value)
            pending = value
            if loop or Aster.Unloaded then return end
            loop = Anim.loop(function()
                if pending == nil then
                    loop = nil
                    return false
                end
                run()
                return true
            end)
        end
        function c.Flush()
            if loop then
                loop:Stop()
                loop = nil
            end
            run()
        end
        function c.Cancel()
            pending = nil
            if loop then
                loop:Stop()
                loop = nil
            end
        end
        return c
    end

    function Anim.count()
        local n = 0
        for _, track in ipairs(tracks) do
            if not track.dead then n = n + 1 end
        end
        return n
    end

    function Anim.flush()
        for _ = 1, 50 do
            local busy = false
            for _, track in ipairs(table.move(tracks, 1, #tracks, 1, {})) do
                if not track.dead and not track.tick then
                    finish(track)
                    busy = true
                end
            end
            if not busy then break end
        end
    end

    function Anim.setCalm(on)
        on = on and true or false
        if Anim.calm == on then return end
        Anim.calm = on
        if on then Anim.flush() end
        Store.put("calm", on)
        Anim.Changed:Fire(on)
    end

    Anim.calm = Store.get("calm", false, function(v) if type(v) == "boolean" then return v end return nil end)

    Aster._maid:Add(function()
        for _, track in ipairs(tracks) do track.dead = true end
        tracks = {}
        if conn then
            conn:Disconnect()
            conn = nil
        end
    end)
end

-- [src] 20_layer.lua
do
    local stack = {}
    local tipLabel
    local MARGIN, LINE = 8, 20

    local function within(gui, frame)
        local ok, yes = pcall(function() return gui == frame or gui:IsDescendantOf(frame) end)
        return ok and yes
    end

    local function viewport()
        local ok, size = pcall(function() return workspace.CurrentCamera.ViewportSize end)
        return ok and size or Vector2.new(1920, 1080)
    end

    local function origin(layer)
        local ok, at = pcall(function() return (layer or Aster.Gui.Popup).AbsolutePosition end)
        return ok and at or Vector2.new(0, 0)
    end

    function Layer.rect(gui, layer)
        local o = origin(layer)
        local at, size = gui.AbsolutePosition, gui.AbsoluteSize
        return at.X - o.X, at.Y - o.Y, size.X, size.Y
    end

    function Layer.point(layer)
        local o = origin(layer) + Input.inset()
        local mouse = Input.mouse()
        return mouse.X - o.X, mouse.Y - o.Y
    end

    function Layer.bounds(box)
        local vp = viewport()
        local l, t, r, b = 0, 0, vp.X, vp.Y
        if typeof(box) == "Instance" then
            local x, y, w, h = Layer.rect(box)
            l, t, r, b = math.max(l, x), math.max(t, y), math.min(r, x + w), math.min(b, y + h)
        elseif type(box) == "table" then
            local x, y = box.x or box[1] or 0, box.y or box[2] or 0
            l, t = math.max(l, x), math.max(t, y)
            r, b = math.min(r, x + (box.w or box[3] or vp.X)), math.min(b, y + (box.h or box[4] or vp.Y))
        end
        return l + MARGIN, t + MARGIN, r - MARGIN, b - MARGIN
    end

    function Layer.room(anchor, box)
        local _, t, _, b = Layer.bounds(box)
        local _, y, _, h = Layer.rect(anchor)
        return math.max(0, b - (y + h) - 4), math.max(0, y - 4 - t)
    end

    local function clamp(v, lo, hi)
        if hi < lo then return lo end
        return math.max(lo, math.min(v, hi))
    end

    function Layer.spot(frame, anchor, side, box)
        local ax, ay, aw, ah = Layer.rect(anchor)
        local l, t, r, b = Layer.bounds(box)
        local w, h = frame.Size.X.Offset, frame.Size.Y.Offset
        local x, y
        if side == "field" then
            local below, above = Layer.room(anchor, box)
            x = ax + aw - w
            if h <= below then
                y = ay + ah + 4
            elseif h <= above then
                y = ay - h - 4
            elseif below >= above then
                y = ay + ah + 4
            else
                y = ay - h - 4
            end
        elseif side == "right" then
            x, y = ax + aw + 8, ay - 6
            if x + w > r then x = ax - w - 8 end
        elseif side == "left" then
            x, y = ax - w - 8, ay - 6
            if x < l then x = ax + aw + 8 end
        elseif side == "top" or side == "up" then
            x, y = ax + aw - w, ay - h - 8
            if y < t then y = ay + ah + 6 end
        else
            x = side == "start" and ax or ax + aw - w
            y = ay + ah + 6
            if y + h > b then y = ay - h - 6 end
        end
        return Util.snap(clamp(x, l, r - w)), Util.snap(clamp(y, t, b - h))
    end

    function Layer.place(frame, anchor, side, box)
        local x, y = Layer.spot(frame, anchor, side, box)
        Anim.stop(frame, "Position")
        frame.Position = UDim2.fromOffset(x, y)
        return x, y
    end

    local function remove(handle)
        for index = #stack, 1, -1 do
            if stack[index] == handle then
                table.remove(stack, index)
                return true
            end
        end
        return false
    end

    function Layer.open(anchor, content, opts)
        opts = opts or {}
        for index = #stack, 1, -1 do
            local open = stack[index]
            if open.Anchor == anchor and opts.toggle ~= false then
                open.Close()
                return open
            end
        end
        for index = #stack, 1, -1 do
            if within(anchor, stack[index].Frame) then break end
            stack[index].Close()
        end
        local width = Util.snap(opts.width or anchor.AbsoluteSize.X)
        local frame = Util.new("Frame", {
            Name = "Popup", ZIndex = 10 + #stack, Size = UDim2.fromOffset(width, Util.snap(opts.height or 0)),
            Theme = { BackgroundColor3 = opts.bg or "card" }, Parent = Aster.Gui.Popup,
        })
        local stroke = Util.new("UIStroke", { Thickness = 1, Transparency = opts.strokeAlpha or 0, Theme = { Color = opts.stroke or "ln3" }, Parent = frame })
        local veil = Util.new("Frame", { Name = "Veil", ZIndex = 1000, Size = UDim2.fromScale(1, 1), Theme = { BackgroundColor3 = opts.bg or "card" }, Parent = frame })
        local handle = { Frame = frame, Anchor = anchor, Opts = opts, Closed = false, Stroke = stroke }
        local maid = Util.Maid.new()
        handle.Maid = maid

        function handle.Close()
            if handle.Closed then return end
            for index = #stack, 1, -1 do
                if stack[index] == handle then
                    for above = #stack, index + 1, -1 do stack[above].Close() end
                    break
                end
            end
            remove(handle)
            handle.Closed = true
            maid:Clean()
            if opts.onClose then Util.guard(opts.onClose, handle) end
            frame.Name = "Closing"
            local function gone() pcall(function() frame:Destroy() end) end
            if Anim.calm or Aster.Unloaded then
                gone()
            else
                veil.Visible = true
                Anim.to(veil, { BackgroundTransparency = 0 }, "fade", gone)
            end
        end
        function handle.Place()
            if handle.Closed then return end
            Layer.place(frame, opts.by or anchor, opts.side, opts.box)
        end
        function handle.Resize(a, b)
            local height = type(a) == "table" and b or a
            frame.Size = UDim2.fromOffset(frame.Size.X.Offset, Util.snap(height))
            handle.Place()
        end
        function handle.Width(a, b)
            local w = type(a) == "table" and b or a
            frame.Size = UDim2.fromOffset(Util.snap(w), frame.Size.Y.Offset)
            handle.Place()
        end
        stack[#stack + 1] = handle
        if type(content) == "function" then
            Util.guard(content, frame, handle)
        elseif typeof(content) == "Instance" then
            content.Parent = frame
            if not opts.height then frame.Size = UDim2.fromOffset(width, content.Size.Y.Offset) end
        end
        if handle.Closed then return handle end
        local x, y = Layer.place(frame, opts.by or anchor, opts.side, opts.box)
        if Anim.calm then
            veil.Visible = false
        else
            frame.Position = UDim2.fromOffset(x, y - 3)
            Anim.to(frame, { Position = UDim2.fromOffset(x, y) }, "fade")
            Anim.to(veil, { BackgroundTransparency = 1 }, "fade", function()
                if not handle.Closed then veil.Visible = false end
            end)
        end
        return handle
    end

    function Layer.option(parent, opts)
        local row = Util.new("TextButton", {
            Name = opts.name or "Option", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1,
            Position = UDim2.fromOffset(0, opts.y or 0), Size = UDim2.new(1, 0, 0, opts.height or LINE), Parent = parent,
        })
        local tint = Util.new("Frame", { Name = "Tint", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Theme = { BackgroundColor3 = "ddHl" }, Parent = row })
        local bar = Util.new("Frame", { Name = "Bar", Visible = false, Size = UDim2.new(0, 2, 1, 0), Theme = { BackgroundColor3 = "ddHl" }, Parent = row })
        local label = Util.new("TextButton", {
            Name = "Text", BackgroundTransparency = 1, Text = tostring(opts.text or ""), TextStyle = "body", TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
            Position = UDim2.fromOffset(opts.pad or 8, 0), Size = UDim2.new(1, -((opts.pad or 8) + (opts.right or 8)), 1, 0), Parent = row,
        })
        local entry = { Row = row, Label = label, Tint = tint, Bar = bar, Selected = false, Over = false, Muted = opts.disabled == true, Click = Util.Signal.new() }
        for _, gui in ipairs({ row, label }) do
            gui.MouseButton1Click:Connect(function() entry.Click:Fire("m1") end)
            gui.MouseButton2Click:Connect(function() entry.Click:Fire("m2") end)
        end
        function entry.Paint(kind)
            local sel, over = entry.Selected, entry.Over and not entry.Muted
            bar.Visible = sel
            Anim.to(tint, { BackgroundTransparency = sel and (over and 0.83 or 0.88) or 1 }, kind)
            Anim.to(row, { BackgroundTransparency = (over and not sel) and 0.96 or 1 }, kind)
            Theme.bind(label, "TextColor3", entry.Muted and "tx4" or (sel and "ddHl" or (over and "tx" or "tx2")))
        end
        function entry.Select(on, kind)
            entry.Selected = on and true or false
            entry.Paint(kind or "fade")
        end
        row.MouseEnter:Connect(function()
            entry.Over = true
            entry.Paint("fade")
        end)
        row.MouseLeave:Connect(function()
            entry.Over = false
            entry.Paint("fade")
        end)
        entry.Selected = opts.selected == true
        entry.Paint(0)
        return entry
    end

    function Layer.menu(anchor, items, opts)
        opts = opts or {}
        local list = type(items) == "function" and items() or items
        local width = 150
        for _, item in ipairs(list) do
            if type(item) == "table" then
                local text = tostring(item.text or item.label or item.name or item.head or "")
                local hint = item.hint and (Text.width(tostring(item.hint), "tiny") + 8) or 0
                width = math.max(width, Text.width(text, "body") + 20 + hint)
            elseif item ~= "-" then
                width = math.max(width, Text.width(tostring(item), "body") + 20)
            end
        end
        local menuOpts = {}
        for k, v in pairs(opts) do menuOpts[k] = v end
        menuOpts.width = opts.width or Util.snap(width)
        return Layer.open(anchor, function(frame, handle)
            local y = 4
            handle.Items = {}
            for _, item in ipairs(list) do
                if item == "-" then
                    Util.new("Frame", { Name = "Sep", Position = UDim2.fromOffset(0, y + 4), Size = UDim2.new(1, 0, 0, 1), Theme = { BackgroundColor3 = "ln" }, Parent = frame })
                    y = y + 9
                elseif type(item) == "table" and item.head then
                    Util.new("TextLabel", {
                        Name = "Head", Text = Text.caps("small", tostring(item.head)), TextStyle = "small", TextXAlignment = Enum.TextXAlignment.Left,
                        Position = UDim2.fromOffset(12, y + 6), Size = UDim2.new(1, -24, 0, 12), Theme = { TextColor3 = "tx4" }, Parent = frame,
                    })
                    y = y + 22
                else
                    if type(item) ~= "table" then item = { text = tostring(item) } end
                    local entry = Layer.option(frame, {
                        name = "Item", y = y, text = item.text or item.label or item.name, selected = item.active or item.sel,
                        disabled = item.disabled, right = item.hint and 12 or 8,
                    })
                    if item.hint then
                        Util.new("TextLabel", {
                            Name = "Hint", Text = tostring(item.hint), TextStyle = "tiny", TextXAlignment = Enum.TextXAlignment.Right,
                            Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, -12, 1, 0), Theme = { TextColor3 = "tx4" }, Parent = entry.Row,
                        })
                    end
                    entry.Click:Connect(function(button)
                        if button ~= "m1" or item.disabled or handle.Closed then return end
                        Layer.closeAll()
                        local fn = item.callback or item.act
                        if fn then Util.guard(fn, item) end
                    end)
                    handle.Items[#handle.Items + 1] = entry
                    y = y + LINE
                end
            end
            handle.Resize(y + 4)
        end, menuOpts)
    end

    function Layer.box()
        local win = Aster._window
        if win and not win.Destroyed and win.Win then return win.Win end
        return nil
    end

    function Layer.chevron(parent, pos, token)
        local holder = Util.new("Frame", { Name = "Chev", BackgroundTransparency = 1, Position = pos, Size = UDim2.fromOffset(7, 4), Parent = parent })
        local px = {}
        for i = 1, 4 do
            px[i] = Util.new("Frame", { Name = "Px", Size = UDim2.fromOffset(9 - 2 * i, 1), Position = UDim2.fromOffset(i - 1, i - 1), Theme = { BackgroundColor3 = token }, Parent = holder })
        end
        local c = { Frame = holder, Open = false }
        function c.Set(open, kind)
            c.Open = open and true or false
            for i = 1, 4 do
                local y = c.Open and (4 - i) or (i - 1)
                Anim.to(px[i], { Position = UDim2.fromOffset(i - 1, y) }, kind or 0)
            end
        end
        function c.Paint(t)
            for _, p in ipairs(px) do Theme.bind(p, "BackgroundColor3", t) end
        end
        return c
    end

    function Layer.button(parent, text, fn, opts)
        opts = opts or {}
        local width = opts.width or (Text.width(tostring(text), "body") + 16)
        local frame = Util.new("Frame", { Name = opts.name or "Button", Size = UDim2.fromOffset(width, opts.height or 20), Position = opts.position or UDim2.fromOffset(0, 0), Parent = parent })
        Theme.fill(frame, "btnBg", "btnBg2")
        Util.new("UIStroke", { Thickness = 1, Theme = { Color = "btnBd" }, Parent = frame })
        local hover = Util.new("Frame", { Name = "Hover", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = frame })
        Theme.fill(hover, "btnHv", "btnHv2")
        local hit = Util.new("TextButton", {
            Name = "Hit", BackgroundTransparency = 1, Text = tostring(text), TextStyle = "body", TextTruncate = Enum.TextTruncate.AtEnd,
            Size = UDim2.fromScale(1, 1), Theme = { TextColor3 = "btnTx" }, Parent = frame,
        })
        local b = { Frame = frame, Hit = hit, Width = width, Disabled = false }
        local function paint(over, kind)
            local on = over and not b.Disabled
            Theme.bind(hit, "TextColor3", b.Disabled and "tx4" or (on and "tx" or "btnTx"))
            Anim.to(hover, { BackgroundTransparency = on and 0 or 1 }, kind)
        end
        hit.MouseEnter:Connect(function() paint(true, "fade") end)
        hit.MouseLeave:Connect(function() paint(false, "fade") end)
        hit.MouseButton1Click:Connect(function()
            if b.Disabled or not fn then return end
            Util.guard(fn, b)
        end)
        function b.SetDisabled(off)
            b.Disabled = off and true or false
            paint(false, 0)
        end
        function b.SetText(t)
            hit.Text = tostring(t)
        end
        paint(false, 0)
        return b
    end

    function Layer.closeAll()
        for index = #stack, 1, -1 do
            if stack[index] then stack[index].Close() end
        end
    end

    function Layer.active()
        return #stack > 0
    end

    function Layer.top()
        return stack[#stack]
    end

    function Layer.tip(gui, text)
        local maid = Util.Maid.new()
        maid:Add(gui.MouseEnter:Connect(function()
            local value = type(text) == "function" and text() or text
            if not value or value == "" then return end
            if not tipLabel then
                tipLabel = Aster._maid:Add(Util.new("TextLabel", {
                    Name = "Tip", BackgroundTransparency = 0, TextStyle = "body", Visible = false,
                    Theme = { BackgroundColor3 = "card", TextColor3 = "tx2" }, Parent = Aster.Gui.Tip,
                }))
                Util.new("UIStroke", { Thickness = 1, Theme = { Color = "ln3" }, Parent = tipLabel })
            end
            local size = Text.size(value, "body")
            local x, y = Layer.point(Aster.Gui.Tip)
            local vp = viewport()
            local w = size.X + 12
            tipLabel.Text = tostring(value)
            tipLabel.Size = UDim2.fromOffset(w, 20)
            tipLabel.Position = UDim2.fromOffset(Util.snap(clamp(x + 12, 4, vp.X - w - 4)), Util.snap(clamp(y + 16, 4, vp.Y - 24)))
            tipLabel.Visible = true
        end))
        maid:Add(gui.MouseLeave:Connect(function()
            if tipLabel then tipLabel.Visible = false end
        end))
        maid:Add(function()
            if tipLabel then tipLabel.Visible = false end
        end)
        return maid
    end

    Aster._maid:Add(Input.onKey(function(name, down)
        if not down or #stack == 0 then return end
        if name == "escape" then
            stack[#stack].Close()
        elseif name == "m1" or name == "m2" then
            for index = #stack, 1, -1 do
                local handle = stack[index]
                if not handle then break end
                if Input.over(handle.Frame) or Input.over(handle.Anchor) or (handle.Opts.by and Input.over(handle.Opts.by)) then break end
                handle.Close()
            end
        end
    end))
end

-- [src] 22_scroll.lua
do
    Scroll.__index = Scroll
    Scroll.STEP = 64
    local live = setmetatable({}, { __mode = "k" })

    local function isWheel(input)
        return input.UserInputType == Enum.UserInputType.MouseWheel
    end

    function Scroll.new(parent, opts)
        opts = opts or {}
        local frame = Util.new("Frame", {
            Name = opts.name or "Scroll", BackgroundTransparency = 1, ClipsDescendants = true,
            Position = opts.position or UDim2.new(0, 0, 0, 0), Size = opts.size or UDim2.fromScale(1, 1), ZIndex = opts.zindex or 1, Parent = parent,
        })
        local content = Util.new("Frame", { Name = "Content", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), Parent = frame })
        local bar = Util.new("Frame", { Name = "Bar", BackgroundTransparency = 1, Active = true, Visible = false, ZIndex = 40, Size = UDim2.fromOffset(9, 0), Parent = frame })
        local rail = Util.new("Frame", { Name = "Rail", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, Position = UDim2.new(1, -2, 0, 0), Size = UDim2.new(0, 1, 1, 0), Parent = bar })
        local thumb = Util.new("Frame", { Name = "Thumb", Active = true, BackgroundTransparency = 1, Position = UDim2.new(1, -3, 0, 0), Size = UDim2.fromOffset(3, 16), Parent = bar })
        local s = setmetatable({
            Frame = frame, Content = content, Bar = bar, Thumb = thumb, Rail = rail, Y = 0, Height = 0, Max = 0, End = opts.endGap or 4,
            Wheel = opts.wheel ~= false, Changed = Util.Signal.new(), _maid = Util.Maid.new(), _len = 0, _th = 16, _shown = false,
        }, Scroll)
        s._maid:Add(s.Changed)
        live[s] = true
        Theme.bind(thumb, "BackgroundColor3", function(T)
            return (s._hot or s._drag) and T.accent or T.ln3
        end)

        s._maid:Add(frame.InputChanged:Connect(function(input)
            if isWheel(input) then
                s:_wheel(input.Position.Z)
            elseif input.UserInputType == Enum.UserInputType.MouseMovement then
                s:_show()
            end
        end))
        s._maid:Add(bar.MouseEnter:Connect(function() s:_hover(true) end))
        s._maid:Add(bar.MouseLeave:Connect(function() s:_hover(false) end))
        local function press(input, onThumb)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
            if onThumb or Input.over(thumb) then s:_grab() else s:_page() end
        end
        s._maid:Add(bar.InputBegan:Connect(function(input) press(input, false) end))
        s._maid:Add(thumb.InputBegan:Connect(function(input) press(input, true) end))
        s._maid:Add(function()
            live[s] = nil
            if s._glide then s._glide:Stop() end
            if s._hide then s._hide:Stop() end
            if s._cancel then s._cancel() end
        end)
        return s
    end

    function Scroll:View()
        return self.Frame.AbsoluteSize.Y
    end

    function Scroll:_place()
        self.Content.Position = UDim2.fromOffset(0, -Util.snap(self.Y))
        if self._len > 0 then
            local k = self.Max > 0 and Util.clamp(self.Y / self.Max, 0, 1) or 0
            self.Thumb.Position = UDim2.new(1, -3, 0, Util.snap((self._len - self._th) * k))
        end
    end

    function Scroll:Refit()
        local view = self:View()
        self.Max = math.max(0, self.Height - view)
        if self.Y > self.Max then self.Y = self.Max end
        if self.Max < 1 then
            self.Bar.Visible = false
            self._len = 0
            self.Y = 0
        else
            self._len = math.max(0, view - 4 - self.End)
            self._th = math.max(16, Util.snap(self._len * view / self.Height))
            self.Bar.Visible = true
            self.Bar.Position = UDim2.new(1, -12, 0, 4)
            self.Bar.Size = UDim2.fromOffset(9, self._len)
            self.Thumb.Size = UDim2.fromOffset(3, self._th)
        end
        self:_place()
    end

    function Scroll:SetHeight(height)
        height = Util.snap(height)
        self.Height = height
        self.Content.Size = UDim2.new(1, 0, 0, height)
        self:Refit()
    end

    function Scroll:To(y, glide)
        y = Util.clamp(y, 0, self.Max)
        if glide and not Anim.calm then
            self:_glideTo(y)
            return
        end
        if self._glide then
            self._glide:Stop()
            self._glide = nil
        end
        self:_set(y)
    end

    function Scroll:_set(y)
        y = Util.clamp(y, 0, self.Max)
        if y == self.Y then return end
        self.Y = y
        self:_place()
        self:_show()
        self.Changed:Fire(y)
    end

    function Scroll:_glideTo(y)
        local g = self._glide
        if not g or not g:Running() then
            g = Anim.follow(self.Y, function(v)
                self:_set(v)
                if self._glide and self._glide.Settled() then
                    self._glide:Stop()
                    self._glide = nil
                end
            end, 0.72)
            self._glide = g
        end
        g.Set(y)
    end

    function Scroll:Aim()
        if self._glide and self._glide:Running() then return self._glide.Target end
        return self.Y
    end

    function Scroll:By(dy, glide)
        self:To(self:Aim() + dy, glide)
    end

    function Scroll:CanScroll(dir)
        if self.Max < 1 then return false end
        local from = self:Aim()
        if dir < 0 then return from > 0 end
        return from < self.Max
    end

    function Scroll:_wheel(z)
        if not self.Wheel or z == 0 or Input.shift() then return end
        local dir = z > 0 and -1 or 1
        for other in pairs(live) do
            if other ~= self and other.Wheel and other.Frame:IsDescendantOf(self.Frame) and Input.over(other.Frame) and other:CanScroll(dir) then return end
        end
        if not self:CanScroll(dir) then return end
        self:By(dir * Scroll.STEP * math.abs(z), true)
    end

    function Scroll:Reveal(top, bottom, center)
        local view = self:View()
        local y = self:Aim()
        if center then
            y = (top + bottom) / 2 - view / 2
        elseif top < y then
            y = top
        elseif bottom > y + view then
            y = bottom - view
        end
        self:To(y, true)
    end

    function Scroll:_hover(on)
        self._hot = on
        Theme.bind(self.Thumb, "BackgroundColor3", function(T)
            return (self._hot or self._drag) and T.accent or T.ln3
        end)
        self:_show()
    end

    function Scroll:_show()
        if self._len <= 0 then return end
        if not self._shown then
            self._shown = true
            Anim.to(self.Thumb, { BackgroundTransparency = 0 }, "fade")
            Anim.to(self.Rail, { BackgroundTransparency = 0.965 }, "fade")
        end
        self._left = 0.9
        if self._hide and self._hide:Running() then return end
        self._hide = Anim.loop(function(dt)
            self._left = self._left - dt
            if self._left > 0 then return true end
            self._hide = nil
            if self._hot or self._drag then return false end
            self._shown = false
            Anim.to(self.Thumb, { BackgroundTransparency = 1 }, "move")
            Anim.to(self.Rail, { BackgroundTransparency = 1 }, "move")
            return false
        end)
    end

    function Scroll:_grab()
        if self._glide then
            self._glide:Stop()
            self._glide = nil
        end
        local y0, s0 = Input.mouse().Y, self.Y
        local k = self.Max / math.max(1, self._len - self._th)
        self._drag = true
        self:_hover(self._hot)
        self._cancel = Input.capture(function(pos)
            self:_set(s0 + (pos.Y - y0) * k)
        end, function()
            self._drag = false
            self._cancel = nil
            self:_hover(self._hot)
        end)
    end

    function Scroll:_page()
        local _, ty = Input.rect(self.Thumb)
        local dir = Input.mouse().Y < ty and -1 or 1
        self:To(self:Aim() + dir * self:View() * 0.9)
    end

    function Scroll:Destroy()
        if self.Destroyed then return end
        self.Destroyed = true
        self._maid:Clean()
        self.Frame:Destroy()
    end
end

-- [src] 30_window.lua
do
    local SIDE, BAR, WHO, TABH, STH = 152, 40, 56, 28, 20
    local MINW, MINH, W0, H0 = 560, 380, 704, 480
    local PAD, GAP, HEADH, CARDMIN, STACK, COLMIN = 8, 8, 26, 48, 440, 64
    local Window, Tab, Page, Card, Set = {}, {}, {}, {}, {}
    Window.__index = Window
    Tab.__index = Tab
    Set.__index = Set
    Card.__index = Card
    setmetatable(Card, { __index = Container })
    Aster._.Window = { Window = Window, Tab = Tab, Page = Page, Card = Card, Set = Set }
    Window.MINW, Window.MINH, Window.W0, Window.H0, Window.STACK, Window.CARDMIN = MINW, MINH, W0, H0, STACK, CARDMIN

    local function kindMethod(key)
        if type(key) ~= "string" or string.sub(key, 1, 1) == "_" then return false end
        for _, spec in pairs(Kinds) do
            if type(spec) == "table" and spec.method == key then return true end
        end
        return false
    end

    local PageMeta = {
        __index = function(page, key)
            local method = Page[key]
            if method ~= nil then return method end
            if kindMethod(key) then
                return function(self, opts)
                    local top = self:_topBox()
                    return top[key](top, opts)
                end
            end
            return nil
        end,
    }

    local function rule(parent, name, pos, size, token, z)
        return Util.new("Frame", { Name = name, Position = pos, Size = size, ZIndex = z or 1, Theme = { BackgroundColor3 = token }, Parent = parent })
    end

    local function label(parent, props, style, token)
        props.Parent = parent
        props.TextStyle = style or "body"
        props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
        props.TextTruncate = props.TextTruncate or Enum.TextTruncate.AtEnd
        props.Theme = props.Theme or { TextColor3 = token or "tx" }
        return Util.new("TextLabel", props)
    end

    local function tint(obj, token, transparency)
        if not obj then return end
        if Icons.tint then return Icons.tint(obj, token, transparency) end
        Theme.bind(obj, "ImageColor3", token)
        if transparency then obj.ImageTransparency = transparency end
    end

    local function hasIcon(name)
        if type(name) ~= "string" then return false end
        if Icons.has then return Icons.has(name) end
        return Icons.get ~= nil and Icons.get(name) ~= nil
    end

    local function makeIcon(parent, name, props)
        if not hasIcon(name) then return nil end
        if Icons.make then return Icons.make(parent, name, props) end
        props.Name, props.Image, props.Parent = "Icon", Icons.get(name), parent
        return Util.new("ImageLabel", props)
    end

    local function dots(parent, props, base, token)
        props.BackgroundTransparency = 1
        props.Active = true
        props.Parent = parent
        local holder = Util.new("Frame", props)
        local spots = { { 0, 0 }, { -3, 0 }, { -6, 0 }, { 0, -3 }, { -3, -3 }, { 0, -6 } }
        holder:SetAttribute("dots", true)
        local list = {}
        for i, spot in ipairs(spots) do
            list[i] = Util.new("Frame", { Name = "Dot", Position = UDim2.fromOffset(base + spot[1], base + spot[2]), Size = UDim2.fromOffset(2, 2), Theme = { BackgroundColor3 = token }, Parent = holder })
        end
        return holder, function()
            for _, dot in ipairs(list) do Theme.repaint(dot) end
        end
    end

    local function chevron(parent, pos, token)
        local holder = Util.new("Frame", { Name = "Chev", BackgroundTransparency = 1, Position = pos, Size = UDim2.fromOffset(7, 7), Parent = parent })
        local px = {}
        for i = 1, 7 do
            px[i] = Util.new("Frame", { Size = UDim2.fromOffset(1, 1), Theme = { BackgroundColor3 = token }, Parent = holder })
        end
        local c = { Frame = holder }
        function c.Set(open)
            for i = 0, 6 do
                local b = 3 - math.abs(3 - i)
                if open then
                    px[i + 1].Position = UDim2.fromOffset(i, 1 + b)
                else
                    px[i + 1].Position = UDim2.fromOffset(2 + b, i)
                end
            end
        end
        function c.Paint()
            for _, p in ipairs(px) do Theme.repaint(p) end
        end
        return c
    end
    Window._chevron, Window._dots = chevron, dots

    local function pressed(input)
        return input.UserInputType == Enum.UserInputType.MouseButton1
    end

    local function pathKey(path)
        local parts = {}
        for _, node in ipairs(path or {}) do
            if type(node) == "table" then parts[#parts + 1] = tostring(node.id or node.name or node.kind) end
        end
        return table.concat(parts, "/")
    end
    Window._pathKey = pathKey

    function Aster:Window(opts)
        if type(opts) == "string" then opts = { title = opts } end
        opts = opts or {}
        if self._window and not self._window.Destroyed then return self._window end
        Store.init(opts.folder or tostring(game.PlaceId))
        Anim.calm = Store.get("calm", false, Store.fix.bool)
        local win = setmetatable({
            Title = opts.title or "aster", Tabs = {}, Key = string.lower(opts.key or "insert"), Visible = true, Opts = opts,
            Toggled = Util.Signal.new(), PageChanged = Util.Signal.new(), _nav = {}, _sets = {}, _subKeys = {}, _maid = Util.Maid.new(),
        }, Window)
        win.Layout = Store.get("layout", {}, Store.fix.layouts)
        win.Folds = Store.get("fold", {}, Store.fix.flags)
        win.Sizes = Store.get("csize", {}, Store.fix.sizes)
        win.Subs = Store.get("subs", {}, Store.fix.flags)
        win._want = Store.get("at", nil, function(v)
            if type(v) ~= "table" or type(v.tab) ~= "string" then return nil end
            return { tab = v.tab, page = Store.fix.strings(v.page) or {} }
        end) or { page = {} }
        win.At = { tab = nil, page = {} }
        win.Size = Store.get("size", { W0, H0 }, function(v)
            local pair = Store.fix.pair(v)
            if pair and pair[1] > 0 and pair[2] > 0 then return { Util.snap(pair[1]), Util.snap(pair[2]) } end
            return nil
        end)
        win.Pos = Store.get("pos", nil, Store.fix.pair)
        self._window = win
        Aster._maid:Add(win._maid)
        win:_build()
        win:_fit()
        win._maid:Add(Aster.Gui.Main:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() win:_fit() end))
        win._maid:Add(Input.onKey(function(name, down)
            if not down or name ~= win.Key then return end
            if UserInputService:GetFocusedTextBox() then return end
            win:Toggle()
        end))
        local first
        first = RunService.Heartbeat:Connect(function()
            if first then
                first:Disconnect()
                first = nil
            end
            win:_ready()
        end)
        win._maid:Add(function()
            if first then first:Disconnect() end
        end)
        return win
    end

    function Window:_build()
        local main = Aster.Gui.Main
        local rig = Util.new("Frame", { Name = "Rig", BackgroundTransparency = 0, Active = true, Theme = { BackgroundColor3 = "ln2" }, Parent = main })
        Util.new("UIStroke", { Thickness = 1, Theme = { Color = "edge" }, Parent = rig })
        self.Frame = rig
        self._maid:Add(rig)
        local frame = Util.new("Frame", { Name = "Win", ClipsDescendants = true, Position = UDim2.fromOffset(1, 1), Size = UDim2.new(1, -2, 1, -2), Theme = { BackgroundColor3 = "bg" }, Parent = rig })
        self.Win = frame
        Util.new("Frame", { Name = "Accent", BackgroundTransparency = 0.45, ZIndex = 20, Size = UDim2.new(1, 0, 0, 1), Theme = { BackgroundColor3 = "accent" }, Parent = frame })

        local side = Util.new("Frame", { Name = "Side", Size = UDim2.new(0, SIDE, 1, 0), Theme = { BackgroundColor3 = "side" }, Parent = frame })
        self.Side = side
        rule(side, "Edge", UDim2.new(1, -1, 0, 0), UDim2.new(0, 1, 1, 0), "ln", 5)
        local brand = Util.new("Frame", { Name = "Brand", Active = true, Size = UDim2.new(1, -1, 0, BAR), BackgroundColor3 = Color3.new(1, 1, 1), Parent = side })
        Theme.bind(Util.new("UIGradient", { Rotation = 90, Parent = brand }), "Color", function(T)
            return ColorSequence.new(Util.mix(T.side, "#ffffff", 0.03), T.side)
        end)
        rule(brand, "Line", UDim2.new(0, 0, 1, -1), UDim2.new(1, 0, 0, 1), "ln")
        local logo = Icons.get and Icons.get("logo")
        local drawLogo = Aster.Hud and Aster.Hud.Logo
        if logo then
            Util.new("ImageLabel", { Name = "Logo", Image = logo, Position = UDim2.fromOffset(10, 11), Size = UDim2.fromOffset(18, 18), Theme = { ImageColor3 = "accent" }, Parent = brand })
        elseif drawLogo and select(2, Util.guard(drawLogo, brand, 18, "accent")) then
            brand.Logo.Position = UDim2.fromOffset(10, 11)
        else
            Util.new("Frame", { Name = "Logo", Position = UDim2.fromOffset(15, 16), Size = UDim2.fromOffset(8, 8), Theme = { BackgroundColor3 = "accent" }, Parent = brand })
        end
        self.Brand = brand
        self.Mark = label(brand, { Name = "Mark", Text = self.Title, Position = UDim2.fromOffset(36, 0), Size = UDim2.new(1, -48, 1, 0) }, "brand", "tx")

        self.TabScroll = Scroll.new(side, { name = "Tabs", position = UDim2.fromOffset(0, BAR), size = UDim2.new(1, -1, 1, -(BAR + WHO)) })
        self.Seg = Util.new("Frame", { Name = "Seg", ZIndex = 5, Size = UDim2.fromOffset(2, TABH), Visible = false, Theme = { BackgroundColor3 = "accent" }, Parent = self.TabScroll.Content })
        self._segY = 0

        local who = Util.new("Frame", { Name = "Who", BackgroundTransparency = 1, Position = UDim2.new(0, 0, 1, -WHO), Size = UDim2.new(1, -1, 0, WHO), Parent = side })
        rule(who, "Line", UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0, 1), "ln")
        local av = Util.new("Frame", { Name = "Avatar", Position = UDim2.fromOffset(12, 10), Size = UDim2.fromOffset(36, 36), Theme = { BackgroundColor3 = "ln3" }, Parent = who })
        local well = Util.new("Frame", { Name = "Well", Position = UDim2.fromOffset(1, 1), Size = UDim2.fromOffset(34, 34), Theme = { BackgroundColor3 = "well" }, Parent = av })
        self.Headshot = Util.new("ImageLabel", { Name = "Headshot", Size = UDim2.fromScale(1, 1), Parent = well })
        local nameW = SIDE - 1 - 56 - 12
        self.WhoDisplay = label(who, { Name = "Display", Position = UDim2.fromOffset(56, 8), Size = UDim2.fromOffset(nameW, 14) }, "bold", "tx")
        self.WhoUser = label(who, { Name = "User", Position = UDim2.fromOffset(56, 23), Size = UDim2.fromOffset(nameW, 12) }, "tiny", "tx4")
        self.WhoGame = label(who, { Name = "Game", Position = UDim2.fromOffset(56, 36), Size = UDim2.fromOffset(nameW, 12) }, "tiny", "tx4")
        self:_who()

        local mainArea = Util.new("Frame", { Name = "Main", BackgroundTransparency = 1, Position = UDim2.fromOffset(SIDE, 0), Size = UDim2.new(1, -SIDE, 1, 0), Parent = frame })
        local head = Util.new("Frame", { Name = "Head", Active = true, Size = UDim2.new(1, 0, 0, BAR), BackgroundColor3 = Color3.new(1, 1, 1), Parent = mainArea })
        Theme.bind(Util.new("UIGradient", { Rotation = 90, Parent = head }), "Color", function(T)
            return ColorSequence.new(Util.mix(T.bg, "#ffffff", 0.03), T.bg)
        end)
        rule(head, "Line", UDim2.new(0, 0, 1, -1), UDim2.new(1, 0, 0, 1), "ln")
        self.Head = head
        self.TitleLabel = label(head, { Name = "Title", Text = "", Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -80, 1, 0) }, "bold", "tx")
        self.SearchButton = self:_iconButton(head, "Search", "search", "find", UDim2.new(1, -60, 0, 8), function() self:_search() end)
        self.SaveButton = self:_iconButton(head, "Save", "save", "save", UDim2.new(1, -32, 0, 8), function() self:_saveConfig() end)

        self.Body = Scroll.new(mainArea, { name = "Body", position = UDim2.fromOffset(0, BAR), size = UDim2.new(1, 0, 1, -BAR), endGap = 12 })
        self.Lift = Util.new("Frame", { Name = "Lift", BackgroundTransparency = 1, ZIndex = 30, Size = UDim2.fromScale(1, 1), Parent = frame })

        self:_handles(rig)
        self:_dragging(brand)
        self:_dragging(head)
    end

    function Window:_iconButton(parent, name, icon, text, pos, fn)
        local btn = Util.new("TextButton", { Name = name, BackgroundTransparency = 1, Position = pos, Size = UDim2.fromOffset(24, 24), Theme = { BackgroundColor3 = "hi" }, Parent = parent })
        local stroke = Util.new("UIStroke", { Thickness = 1, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Theme = { Color = "ln2" }, Parent = btn })
        local hot = false
        local slot
        local function paint(on)
            hot = on
            btn.BackgroundTransparency = hot and 0 or 1
            stroke.Transparency = hot and 0 or 1
            if slot.Obj then tint(slot.Obj, hot and "tx" or "tx3") else Theme.bind(slot.Text, "TextColor3", hot and "tx" or "tx3") end
        end
        slot = self:_iconSlot(btn, icon, { Position = UDim2.fromOffset(5, 5), Size = UDim2.fromOffset(14, 14) }, function() if slot then paint(hot) end end)
        if not slot.Obj then
            slot.Text = label(btn, { Name = "Icon", Text = Text.caps("small", text), Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.None }, "small", "tx3")
        end
        paint(false)
        btn.MouseEnter:Connect(function() paint(true) end)
        btn.MouseLeave:Connect(function() paint(btn:GetAttribute("open") == true) end)
        btn.MouseButton1Click:Connect(fn)
        btn:SetAttribute("paint", true)
        return btn
    end

    function Window:_iconSlot(parent, name, props, paint, owner)
        local slot = {}
        function slot.Build()
            if slot.Obj then slot.Obj:Destroy() end
            slot.Obj = makeIcon(parent, name, Util.copy(props))
            if slot.Obj and Icons.watch then Icons.watch(slot.Obj, owner) end
            if paint and slot.Text == nil then paint(slot.Obj) end
            return slot.Obj
        end
        slot.Build()
        if slot.Obj then
            self._iconSlots = self._iconSlots or {}
            self._iconSlots[#self._iconSlots + 1] = slot
            if not self._iconConn and Icons.Changed then
                self._iconConn = self._maid:Add(Icons.Changed:Connect(function()
                    for _, s in ipairs(self._iconSlots) do s.Build() end
                end))
            end
        end
        return slot
    end

    function Window:_who()
        local opts = self.Opts.user or {}
        local player = LocalPlayer
        local id = opts.id or Exec.field(player, "UserId") or 0
        local display = opts.display or Exec.field(player, "DisplayName") or Exec.field(player, "Name") or "player"
        local name = opts.name or Exec.field(player, "Name") or "player"
        self.WhoDisplay.Text = tostring(display)
        self.WhoUser.Text = "@" .. tostring(name)
        self.Headshot.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(id) .. "&w=48&h=48"
        local gameName = self.Opts.game
        if gameName then
            self.WhoGame.Text = tostring(gameName)
            return
        end
        self.WhoGame.Text = tostring(Exec.field(game, "Name") or "")
        task.spawn(function()
            local ok, info = pcall(function() return Exec.service("MarketplaceService"):GetProductInfo(game.PlaceId) end)
            if ok and type(info) == "table" and type(info.Name) == "string" and not self.Destroyed then self.WhoGame.Text = info.Name end
        end)
    end

    function Window:_viewport()
        local size = Aster.Gui.Main.AbsoluteSize
        return size.X, size.Y
    end

    function Window:_fit()
        local vw, vh = self:_viewport()
        local w = Util.clamp(Util.snap(self.Size[1]), MINW, math.max(MINW, vw - 16))
        local h = Util.clamp(Util.snap(self.Size[2]), MINH, math.max(MINH, vh - 16))
        self.Shown = { w, h }
        self.Frame.Size = UDim2.fromOffset(w, h)
        local pos = self.Pos or { Util.snap((vw - w) / 2), Util.snap((vh - h) / 2) }
        self:_move(pos[1], pos[2])
        self:_reflow()
    end

    function Window:_move(x, y)
        local vw, vh = self:_viewport()
        local w, h = self.Shown[1], self.Shown[2]
        x = Util.snap(Util.clamp(x, 8, vw - 8 - w))
        y = Util.snap(Util.clamp(y, 8, vh - 8 - h))
        self.Pos = { x, y }
        local goal = UDim2.fromOffset(x, y)
        if self.Frame.Position == goal then return end
        self.Frame.Position = goal
    end

    function Window:_reflow()
        self.TabScroll:Refit()
        self:_layoutTabs()
        local page = self.Page
        if page then page:_relayout(false) end
        self.Body:Refit()
    end

    function Window:_dragging(handle)
        self._maid:Add(handle.InputBegan:Connect(function(input)
            if not pressed(input) or self._sizing then return end
            local m0 = Input.mouse()
            local x0, y0 = self.Pos[1], self.Pos[2]
            Layer.closeAll()
            local move = Anim.coalesce(function(pos)
                self:_move(x0 + pos.X - m0.X, y0 + pos.Y - m0.Y)
            end)
            Input.capture(move.Push, function()
                move.Flush()
                Store.put("pos", self.Pos)
            end)
        end))
    end

    function Window:_handles(rig)
        local hx = Util.new("Frame", { Name = "SizeX", Active = true, BackgroundTransparency = 1, ZIndex = 7, Position = UDim2.new(1, -1, 0, 0), Size = UDim2.new(0, 6, 1, -8), Parent = rig })
        local hy = Util.new("Frame", { Name = "SizeY", Active = true, BackgroundTransparency = 1, ZIndex = 7, Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, -8, 0, 6), Parent = rig })
        local state = { hot = false, on = false, lim = false }
        local grip, repaint = dots(rig, { Name = "SizeXY", ZIndex = 8, Position = UDim2.new(1, -11, 1, -11), Size = UDim2.fromOffset(16, 16) }, 6, function(T)
            if state.lim then return T.tx4 end
            if state.hot or state.on then return T.accent end
            return T.ln3
        end)
        self.Grips = { x = hx, y = hy, xy = grip }
        self._gripState = state
        grip.MouseEnter:Connect(function() state.hot = true repaint() end)
        grip.MouseLeave:Connect(function() state.hot = false repaint() end)
        local function start(axis)
            return function(input)
                if not pressed(input) then return end
                Layer.closeAll()
                local m0 = Input.mouse()
                local w0, h0 = self.Shown[1], self.Shown[2]
                local vw, vh = self:_viewport()
                local maxW, maxH = math.max(MINW, vw - 8 - self.Pos[1]), math.max(MINH, vh - 8 - self.Pos[2])
                self._sizing = true
                state.on = true
                repaint()
                local size = Anim.coalesce(function(pair)
                    if pair[1] ~= self.Size[1] or pair[2] ~= self.Size[2] then self:_resize(pair[1], pair[2]) end
                end)
                Input.capture(function(pos)
                    local w, h = w0 + pos.X - m0.X, h0 + pos.Y - m0.Y
                    local lim = (axis ~= "y" and (w < MINW - 2 or w > maxW + 2)) or (axis ~= "x" and (h < MINH - 2 or h > maxH + 2))
                    if lim ~= state.lim then
                        state.lim = lim
                        repaint()
                    end
                    size.Push({ Util.snap(axis == "y" and w0 or Util.clamp(w, MINW, maxW)), Util.snap(axis == "x" and h0 or Util.clamp(h, MINH, maxH)) })
                end, function()
                    size.Flush()
                    self._sizing = false
                    state.on, state.lim = false, false
                    repaint()
                    Store.put("size", self.Size)
                    Store.put("pos", self.Pos)
                end)
            end
        end
        self._maid:Add(hx.InputBegan:Connect(start("x")))
        self._maid:Add(hy.InputBegan:Connect(start("y")))
        self._maid:Add(grip.InputBegan:Connect(start("xy")))
    end

    function Window:_resize(w, h)
        self.Size = { Util.snap(w), Util.snap(h) }
        local x, y = self.Pos[1], self.Pos[2]
        self:_fit()
        self:_move(x, y)
    end

    function Window:SetSize(w, h)
        self:_resize(w, h)
        Store.put("size", self.Size)
    end

    function Window:Toggle(visible)
        if visible == nil then visible = not self.Visible end
        visible = visible and true or false
        if visible == self.Visible then return end
        self.Visible = visible
        self.Frame.Visible = visible
        if not visible then Layer.closeAll() end
        self.Toggled:Fire(visible)
    end

    function Window:SetKey(name)
        if type(name) == "string" and name ~= "" then self.Key = string.lower(name) end
    end

    function Window:SetTitle(title)
        self.Title = tostring(title)
        self.Mark.Text = self.Title
    end

    function Window:Unload()
        Aster:Unload()
    end

    function Window:_saveConfig()
        local ok = Store.save(Store.Selected)
        if Aster.Notify then
            Util.guard(Aster.Notify, Aster, "config", (ok and "saved " or "could not save ") .. tostring(Store.Selected), ok and "ok" or "warn")
        end
    end

    function Window:Destroy()
        if self.Destroyed then return end
        self.Destroyed = true
        self._maid:Clean()
        if Aster._window == self then Aster._window = nil end
    end

    function Window:Tab(opts)
        if type(opts) == "string" then opts = { name = opts } end
        opts = opts or {}
        local name = tostring(opts.name or opts.title or ("tab " .. (#self.Tabs + 1)))
        local tab = setmetatable({ Window = self, Name = name, Id = opts.id or Util.slug(name), Icon = opts.icon, Pages = {}, _open = 0, _hot = false }, Tab)
        self.Tabs[#self.Tabs + 1] = tab
        local content = self.TabScroll.Content
        local btn = Util.new("TextButton", { Name = "Tab_" .. tab.Id, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, TABH), Parent = content })
        tab.Button = btn
        tab.HoverBar = Util.new("Frame", { Name = "Hover", Visible = false, Size = UDim2.new(0, 2, 1, 0), Theme = { BackgroundColor3 = "ln3" }, Parent = btn })
        local x = 12
        local slot = self:_iconSlot(btn, opts.icon, { Position = UDim2.fromOffset(12, 7), Size = UDim2.fromOffset(14, 14) }, function(obj)
            tab.IconImage = obj
            if tab.Label then tab:_paint() end
        end, tab)
        if slot.Obj then x = 34 end
        tab.Label = label(btn, { Name = "Label", Text = name, Position = UDim2.fromOffset(x, 0), Size = UDim2.new(1, -(x + 8), 1, 0) }, "body", "tx3")
        tab.PageX = opts.icon and 34 or 24
        tab.List = Util.new("Frame", { Name = "Pages_" .. tab.Id, BackgroundTransparency = 1, ClipsDescendants = true, Size = UDim2.new(1, 0, 0, 0), Parent = content })
        btn.MouseButton1Click:Connect(function() self:Go(tab) end)
        btn.MouseEnter:Connect(function()
            tab._hot = true
            tab:_paint()
        end)
        btn.MouseLeave:Connect(function()
            tab._hot = false
            tab:_paint()
        end)
        tab:_paint()
        self:_layoutTabs()
        return tab
    end

    function Tab:_paint()
        local active = self.Window.Page ~= nil and self.Window.Page.Tab == self
        local btn = self.Button
        Theme.bind(btn, "BackgroundColor3", active and "accent" or "white")
        btn.BackgroundTransparency = active and 0.93 or (self._hot and 0.97 or 1)
        self.HoverBar.Visible = self._hot and not active
        Text.style(self.Label, active and "bold" or "body")
        Theme.bind(self.Label, "TextColor3", (active or self._hot) and "tx" or "tx3")
        tint(self.IconImage, active and "accent" or (self._hot and "tx" or "tx3"), (active or self._hot) and 0 or 0.3)
        for _, page in ipairs(self.Pages) do page:_paintButton() end
    end

    function Tab:Page(opts)
        if type(opts) == "string" then opts = { name = opts } end
        opts = opts or {}
        local win = self.Window
        local name = tostring(opts.name or opts.title or ("page " .. (#self.Pages + 1)))
        local id = opts.id or Util.slug(name)
        local page = setmetatable({ Tab = self, Window = win, Name = name, Id = id, Icon = opts.icon, Wide = opts.wide == true, Base = self.Id .. "/" .. id, _hot = false }, PageMeta)
        self.Pages[#self.Pages + 1] = page
        page.Frame = Util.new("Frame", { Name = "Page_" .. self.Id .. "_" .. id, BackgroundTransparency = 1, Visible = false, Size = UDim2.new(1, 0, 0, 0), Parent = win.Body.Content })
        page.Path = { { kind = "tab", ref = self, name = self.Name, id = self.Id }, { kind = "page", ref = page, name = name, id = id } }
        page.Set = Set.new(page, nil)
        page._building = page.Set
        local btn = Util.new("TextButton", { Name = "Page_" .. id, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1,
            Position = UDim2.fromOffset(0, (#self.Pages - 1) * STH), Size = UDim2.new(1, 0, 0, STH), Parent = self.List })
        page.Button = btn
        local x = self.PageX
        win:_iconSlot(btn, opts.icon, { Position = UDim2.fromOffset(x - 16, 5), Size = UDim2.fromOffset(10, 10) }, function(obj)
            page.IconImage = obj
            if page.Label then page:_paintButton() else tint(obj, "tx3", 0.3) end
        end)
        page.Label = label(btn, { Name = "Label", Text = string.lower(name), TextTransparency = self._open > 0.5 and 0 or 1, Position = UDim2.fromOffset(x, 0), Size = UDim2.new(1, -(x + 8), 1, 0) }, "body", "tx3")
        btn.MouseButton1Click:Connect(function() win:Go(page) end)
        btn.MouseEnter:Connect(function()
            page._hot = true
            page:_paintButton()
        end)
        btn.MouseLeave:Connect(function()
            page._hot = false
            page:_paintButton()
        end)
        win._nav[#win._nav + 1] = { Label = self.Name .. " " .. name, Lower = string.lower(self.Name .. " " .. name), Path = page.Path, Page = page }
        local want = win._want
        local wantPage = want.page[self.Id]
        if not win.Page then
            win:Go(page, true)
        elseif want.tab == self.Id and win.Page.Tab ~= self and (wantPage == nil or wantPage == id) then
            win:Go(page, true)
        elseif want.tab == self.Id and win.Page.Tab == self and wantPage == id then
            win:Go(page, true)
        end
        self:_paint()
        win:_layoutTabs()
        return page
    end

    function Window:_layoutTabs()
        local y = 8
        local active = self.Page and self.Page.Tab
        local activeY
        for _, tab in ipairs(self.Tabs) do
            tab.Button.Position = UDim2.fromOffset(0, y)
            if tab == active then activeY = y end
            y = y + TABH
            local full = #tab.Pages > 0 and (#tab.Pages * STH + 8) or 0
            local height = Util.snap(full * tab._open)
            tab.List.Position = UDim2.fromOffset(0, y)
            tab.List.Size = UDim2.new(1, 0, 0, height)
            tab.List.Visible = height > 0
            y = y + height
        end
        self.TabScroll:SetHeight(y + 8)
        self._activeY = activeY
        if activeY and not self._segAnim then self._segY = activeY end
        self.Seg.Visible = activeY ~= nil
        self.Seg.Position = UDim2.fromOffset(0, Util.snap(self._segY or 0))
    end

    function Window:_openTabs(instant)
        local active = self.Page and self.Page.Tab
        local from, to = {}, {}
        for i, tab in ipairs(self.Tabs) do
            from[i] = tab._open
            to[i] = tab == active and 1 or 0
            if from[i] ~= to[i] then
                for _, page in ipairs(tab.Pages) do
                    if to[i] == 1 then
                        local lbl = page.Label
                        if instant or Anim.calm then
                            lbl.TextTransparency = 0
                        else
                            Anim.after(0.04, function() Anim.to(lbl, { TextTransparency = 0 }, "fade") end)
                        end
                    else
                        Anim.to(page.Label, { TextTransparency = 1 }, instant and 0 or "fade")
                    end
                end
            end
        end
        local y0 = self._segY
        if instant or Anim.calm or not self._placed then
            self._placed = true
            for i, tab in ipairs(self.Tabs) do tab._open = to[i] end
            self._segAnim = false
            self:_layoutTabs()
            return
        end
        self._segAnim = true
        Anim.value(self.Tabs, 0, 1, "move", function(k)
            for i, tab in ipairs(self.Tabs) do
                if from[i] then tab._open = from[i] + (to[i] - from[i]) * k end
            end
            self:_layoutTabs()
            if self._activeY then
                self._segY = y0 + (self._activeY - y0) * k
                self.Seg.Position = UDim2.fromOffset(0, Util.snap(self._segY))
            end
        end, function()
            self._segAnim = false
            self:_layoutTabs()
        end)
    end

    function Window:Go(target, instant)
        local page = target
        if getmetatable(target) == Tab then
            local wanted = self.At.page[target.Id] or self._want.page[target.Id]
            page = nil
            for _, p in ipairs(target.Pages) do
                if p.Id == wanted then page = p end
            end
            page = page or target.Pages[1]
        end
        if not page or page == self.Page then return end
        Layer.closeAll()
        local old = self.Page
        self.Page = page
        self.At.tab = page.Tab.Id
        self.At.page[page.Tab.Id] = page.Id
        if self._ready_ then Store.put("at", self.At) end
        if old then
            old.Frame.Visible = false
            old:_shown(false)
        end
        page.Frame.Visible = true
        self.TitleLabel.Text = string.upper(page.Name)
        page:_shown(true)
        self.Body.Y = 0
        page:_relayout(false)
        self.Body:To(0)
        if not instant and not Anim.calm then
            page.Frame.Position = UDim2.fromOffset(0, 4)
            Anim.to(page.Frame, { Position = UDim2.fromOffset(0, 0) }, "move")
        else
            Anim.stop(page.Frame, "Position")
            page.Frame.Position = UDim2.fromOffset(0, 0)
        end
        for _, tab in ipairs(self.Tabs) do tab:_paint() end
        self:_openTabs(instant)
        self.PageChanged:Fire(page)
    end

    function Page:_paintButton()
        local active = self.Window.Page == self
        local btn = self.Button
        Theme.bind(btn, "BackgroundColor3", active and "accent" or "white")
        btn.BackgroundTransparency = active and 0.96 or (self._hot and 0.98 or 1)
        Theme.bind(self.Label, "TextColor3", active and "accent" or (self._hot and "tx" or "tx3"))
        tint(self.IconImage, active and "accent" or (self._hot and "tx" or "tx3"), (active or self._hot) and 0 or 0.3)
    end

    function Page:_current()
        local v = self.Variant
        if v and v.sets[v.key] then return v.sets[v.key] end
        return self.Set
    end

    function Page:_shown(on)
        local current = self:_current()
        for _, set in ipairs(self:_sets()) do set:_show(on and set == current) end
        if self.Top then self.Top:_show(on) end
    end

    function Page:_sets()
        local list = { self.Set }
        if self.Variant then
            for _, v in ipairs(self.Variant.values) do list[#list + 1] = self.Variant.sets[tostring(v)] end
        end
        return list
    end

    function Page:_relayout(animate)
        self:_current():_place(animate)
    end

    function Page:_inner()
        local width = self.Window.Body.Frame.AbsoluteSize.X
        if width <= 0 then width = W0 - SIDE - 2 end
        return width - 2 * PAD, width <= STACK
    end

    function Page:_topBox()
        if self.Top then return self.Top end
        local inner = self:_inner()
        local frame = Util.new("Frame", { Name = "Top", BackgroundTransparency = 1, Position = UDim2.fromOffset(PAD, PAD), Size = UDim2.fromOffset(inner, 0), Parent = self.Frame })
        self.TopFrame = frame
        self.Top = Container.new(frame, { width = inner, path = self.Path, bg = "bg", shown = self.Window.Page == self })
        self.Top.Resized:Connect(function()
            if self.Window.Page == self then self:_relayout(false) end
        end)
        return self.Top
    end

    function Page:_top(height)
        local el = self:_topBox():_TopSlot({ height = height })
        return el.Row
    end

    function Page:_topHeight()
        if not self.Top then return 0 end
        return self.Top.Height
    end

    function Page:Variants(strip, fn)
        local values = {}
        if type(strip) == "table" and strip.Kind then
            local items = strip.Opts.items or strip.Opts.options or strip.Opts.values or {}
            for _, item in ipairs(items) do
                if type(item) == "table" then item = item.k or item.key or item.value or item[1] end
                values[#values + 1] = item
            end
        elseif type(strip) == "table" then
            values, strip = strip, nil
        end
        local variant = { strip = strip, values = values, sets = {}, key = nil }
        self.Variant = variant
        for _, v in ipairs(values) do
            local set = Set.new(self, v)
            variant.sets[tostring(v)] = set
            self._building = set
            Util.guard(fn, v, self)
        end
        self._building = self.Set
        local current = strip and strip.Value
        if variant.sets[tostring(current)] == nil then current = values[1] end
        variant.key = tostring(current)
        variant.value = current
        if strip and strip._state then
            strip._maid:Add(strip._state:Connect(function(v) self:SetVariant(v) end))
        end
        self:_shown(self.Window.Page == self)
        if self.Window.Page == self then self:_relayout(false) end
        return self
    end

    function Page:SetVariant(v)
        local variant = self.Variant
        if not variant or variant.sets[tostring(v)] == nil or variant.key == tostring(v) then return false end
        Layer.closeAll()
        variant.key, variant.value = tostring(v), v
        local strip = variant.strip
        if strip and strip.Value ~= v then strip:Set(v) end
        self:_shown(self.Window.Page == self)
        if self.Window.Page == self then self:_relayout(false) end
        return true
    end

    function Set.new(page, variant)
        local key = page.Base .. (variant ~= nil and ("." .. tostring(variant)) or "")
        local set = setmetatable({ Page = page, Window = page.Window, Variant = variant, Key = key, Cards = {}, Order = {}, Rows = {}, _geo = nil }, Set)
        page.Window._sets[key] = set
        return set
    end

    function Set:_show(on)
        for _, card in ipairs(self.Order) do
            if not card._lifted then card.Root.Visible = on end
            card:_show(on and not card.Folded)
        end
        self._showing = on
    end

    function Set:_build(saved)
        saved = saved or self.Window.Layout[self.Key] or { {}, {} }
        local byId, used = self.Cards, {}
        local inSecond = {}
        for _, id in ipairs(saved[2]) do inSecond[id] = true end
        local fl, fullSet = {}, {}
        for _, id in ipairs(saved[1]) do
            if byId[id] and inSecond[id] then fl[#fl + 1] = id end
        end
        local isFl = {}
        for _, id in ipairs(fl) do isFl[id] = true end
        local second = {}
        for _, id in ipairs(saved[2]) do
            if isFl[id] then second[#second + 1] = id end
        end
        if table.concat(fl, "\0") == table.concat(second, "\0") then
            for _, id in ipairs(fl) do fullSet[id] = true end
        else
            fl = {}
        end
        local segs = {}
        for i = 1, 2 do
            local list = { {} }
            for _, id in ipairs(saved[i]) do
                if fullSet[id] then list[#list + 1] = {} else table.insert(list[#list], id) end
            end
            segs[i] = list
        end
        local rows, band = {}, nil
        local function open()
            band = { cols = { {}, {} } }
            rows[#rows + 1] = band
        end
        open()
        for k = 1, #fl + 1 do
            for i = 1, 2 do
                for _, id in ipairs(segs[i][k] or {}) do
                    local card = byId[id]
                    if card and not used[id] then
                        used[id] = true
                        card.Full = false
                        table.insert(band.cols[i], card)
                    end
                end
            end
            local f = fl[k]
            if f then
                used[f] = true
                byId[f].Full = true
                rows[#rows + 1] = { full = byId[f] }
                open()
            end
        end
        for _, card in ipairs(self.Order) do
            if not used[card.Id] then
                card.Full = false
                table.insert(band.cols[card.Side], card)
            end
        end
        self.Rows = rows
    end

    function Set:_find(item)
        for r, row in ipairs(self.Rows) do
            if row.full == item then return r, nil, nil end
            if row.cols then
                for ci = 1, 2 do
                    for idx, x in ipairs(row.cols[ci]) do
                        if x == item then return r, ci, idx end
                    end
                end
            end
        end
        return nil
    end

    function Set:_remove(item)
        local r, ci, idx = self:_find(item)
        if not r then return nil end
        if ci then
            table.remove(self.Rows[r].cols[ci], idx)
        else
            table.remove(self.Rows, r)
        end
        return r, ci, idx
    end

    function Set:_serialize()
        local L = { {}, {} }
        for _, row in ipairs(self.Rows) do
            if row.full then
                local card = row.full
                if not card.ghost then
                    L[1][#L[1] + 1] = card.Id
                    if card.Full then L[2][#L[2] + 1] = card.Id end
                end
            else
                local ids = { {}, {} }
                for i = 1, 2 do
                    for _, item in ipairs(row.cols[i]) do
                        if not item.ghost then ids[i][#ids[i] + 1] = item.Id end
                    end
                end
                for i = 1, 2 do
                    for _, item in ipairs(row.cols[i]) do
                        if not item.ghost and item.Full then
                            local count = 0
                            for _, other in ipairs(row.cols[3 - i]) do
                                if not other.ghost and (other.RestY or 0) < (item.RestY or 0) then count = count + 1 end
                            end
                            table.insert(ids[3 - i], math.min(count + 1, #ids[3 - i] + 1), item.Id)
                        end
                    end
                end
                for i = 1, 2 do
                    for _, id in ipairs(ids[i]) do L[i][#L[i] + 1] = id end
                end
            end
        end
        return L
    end

    function Set:_save(L)
        L = L or self:_serialize()
        self.Window.Layout[self.Key] = L
        Store.put("layout", self.Window.Layout)
        return L
    end

    function Set:_place(animate)
        local page, win = self.Page, self.Window
        local inner, stacked = page:_inner()
        local y = PAD
        local topH = page:_topHeight()
        if page.TopFrame then
            page.TopFrame.Position = UDim2.fromOffset(PAD, PAD)
            if page.Top.Width ~= inner then page.Top:_resize(inner) end
            page.TopFrame.Size = UDim2.fromOffset(inner, topH)
        end
        if topH > 0 then y = y + topH + GAP end
        local c1 = inner
        if not stacked then c1 = math.floor((inner - GAP) * (page.Wide and 1.9 / 2.9 or 0.5)) end
        local xs = { PAD, stacked and PAD or PAD + c1 + GAP }
        local ws = { c1, stacked and inner or inner - GAP - c1 }
        local dragging = win._drag ~= nil and win._drag.set == self
        local geo = { stacked = stacked, inner = inner, x = xs, w = ws, bands = {} }
        self._geo = geo
        local function put(item, x, top, w)
            item.RestX, item.RestY, item.RestW = x, top, w
            if item.ghost then
                item.RestH = item.H
                item.Root.Position = UDim2.fromOffset(x, top)
                item.Root.Size = UDim2.fromOffset(w, item.H)
                return item.H
            end
            local h = item:_outer()
            item.RestH = h
            if item._lifted then return h end
            if item.W ~= w then item:_width(w) end
            local goal = UDim2.fromOffset(x, top)
            if animate and item._placed and item.Root.Position ~= goal then
                Anim.to(item.Root, { Position = goal }, "move")
            else
                Anim.stop(item.Root, "Position")
                item.Root.Position = goal
            end
            item._placed = true
            return h
        end
        for _, row in ipairs(self.Rows) do
            if row.full then
                y = y + put(row.full, PAD, y, inner) + GAP
            else
                local empty = #row.cols[1] == 0 and #row.cols[2] == 0
                if not empty or dragging then
                    local band = { row = row, top = y, cols = {} }
                    if stacked then
                        for i = 1, 2 do
                            local col = row.cols[i]
                            if #col > 0 or dragging then
                                local top = y
                                for _, item in ipairs(col) do y = y + put(item, PAD, y, inner) + GAP end
                                local bottom = math.max(y - GAP, top + COLMIN)
                                if #col == 0 then y = top + COLMIN + GAP elseif bottom > y - GAP then y = bottom + GAP end
                                band.cols[#band.cols + 1] = { ci = i, col = col, x = PAD, w = inner, top = top, bottom = bottom }
                            end
                        end
                        band.bottom = y - GAP
                    else
                        local bottom = y + COLMIN
                        for i = 1, 2 do
                            local cy = y
                            for _, item in ipairs(row.cols[i]) do cy = cy + put(item, xs[i], cy, ws[i]) + GAP end
                            local colBottom = math.max(cy - GAP, y + COLMIN)
                            band.cols[i] = { ci = i, col = row.cols[i], x = xs[i], w = ws[i], top = y, bottom = colBottom }
                            if colBottom > bottom then bottom = colBottom end
                        end
                        band.bottom = bottom
                        y = bottom + GAP
                    end
                    geo.bands[#geo.bands + 1] = band
                end
            end
        end
        local total = math.max(y - GAP, PAD) + 12
        page.Frame.Size = UDim2.new(1, 0, 0, total)
        self.Height = total
        if win.Page == page and page:_current() == self then win.Body:SetHeight(total) end
    end

    function Page:Card(opts)
        if type(opts) == "string" then opts = { name = opts } end
        opts = opts or {}
        local win, set = self.Window, self._building
        local title = tostring(opts.name or opts.title or "card")
        local id = opts.id or Util.slug(title)
        if id == "" then id = "card" end
        if set.Cards[id] then
            local n = 2
            while set.Cards[id .. "_" .. n] do n = n + 1 end
            id = id .. "_" .. n
        end
        local side = (opts.side == "right" or opts.side == 2 or opts.col == "r") and 2 or 1
        local key = set.Key .. ":" .. id
        local frame = Util.new("Frame", { Name = "Card_" .. id, Active = true, Visible = set._showing == true, Theme = { BackgroundColor3 = "edge" }, Parent = self.Frame })
        local bg = Util.new("Frame", { Name = "Bg", ClipsDescendants = true, Position = UDim2.fromOffset(1, 1), Size = UDim2.new(1, -2, 1, -2), Theme = { BackgroundColor3 = "panel2" }, Parent = frame })
        Theme.fill(Util.new("Frame", { Name = "Glow", Size = UDim2.new(1, 0, 0, 120), Parent = bg }), "panel", "panel2")
        local ring = Util.new("Frame", { Name = "Ring", BackgroundTransparency = 1, ZIndex = 2, Position = UDim2.fromOffset(2, 2), Size = UDim2.new(1, -4, 1, -4), Parent = frame })
        local stroke = Util.new("UIStroke", { Thickness = 1, Transparency = 0.955, Color = Color3.new(1, 1, 1), Parent = ring })
        Util.new("Frame", { Name = "Accent", ZIndex = 4, Position = UDim2.fromOffset(1, 1), Size = UDim2.new(1, -2, 0, 1), Theme = { BackgroundColor3 = "accent" }, Parent = frame })
        local head = Util.new("Frame", { Name = "Head", Active = true, BackgroundTransparency = 1, ZIndex = 3, Position = UDim2.fromOffset(1, 1), Size = UDim2.new(1, -2, 0, 24), Parent = frame })
        local titleLabel = label(head, { Name = "Title", Text = title, ZIndex = 3, Position = UDim2.fromOffset(8, 2), Size = UDim2.new(1, -40, 0, 22) }, "bold", "tx")
        local fold = Util.new("TextButton", { Name = "Fold", BackgroundTransparency = 1, ZIndex = 4, Position = UDim2.new(1, -24, 0, 5), Size = UDim2.fromOffset(20, 16), Parent = head })
        local shade1 = Util.new("Frame", { Name = "Shade", ZIndex = 3, Position = UDim2.fromOffset(1, 25), Size = UDim2.new(1, -2, 0, 1), Theme = { BackgroundColor3 = "edge" }, Parent = frame })
        local shade2 = Util.new("Frame", { Name = "Shine", ZIndex = 3, BackgroundTransparency = 0.975, BackgroundColor3 = Color3.new(1, 1, 1), Position = UDim2.fromOffset(1, 26), Size = UDim2.new(1, -2, 0, 1), Parent = frame })
        local scroll = Scroll.new(frame, { name = "Body", position = UDim2.fromOffset(1, 25), size = UDim2.new(1, -2, 0, 0), endGap = 10, wheel = false, zindex = 2 })
        local path = table.move(self.Path, 1, #self.Path, 1, {})
        if set.Variant ~= nil then path[#path + 1] = { kind = "variant", ref = self, value = set.Variant, name = tostring(set.Variant), id = tostring(set.Variant) } end
        local node = { kind = "card", name = title, id = id }
        path[#path + 1] = node
        local guess = math.max(80, math.floor((select(1, self:_inner()) - GAP) / 2))
        local card = Container.new(scroll.Content, { width = guess - 2, path = path, bg = "panel", padTop = 2, padBottom = 6, shown = false })
        setmetatable(card, Card)
        node.ref = card
        card.Id, card.Title, card.Set, card.Page, card.Window, card.Key, card.Side = id, title, set, self, win, key, side
        card.Root, card.Body, card.Head, card.TitleLabel, card.FoldButton, card.Stroke = frame, scroll, head, titleLabel, fold, stroke
        card.Folded = win.Folds[key] == true
        card.Fixed = win.Sizes[key]
        card.W = guess
        card._bodyH = 0
        card._shades = { shade1, shade2 }
        card._cmaid = Util.Maid.new()
        card._state = { hot = false, on = false, lim = false, foldHot = false }
        card.Chev = chevron(fold, UDim2.fromOffset(6, 4), function(T)
            if card._state.foldHot then return T.accent end
            return T.tx4
        end)
        card.Chev.Set(not card.Folded)
        card:_grips()
        card.Resized:Connect(function(h)
            scroll:SetHeight(h)
            card:_sync()
        end)
        scroll:SetHeight(card.Height)
        frame.Size = UDim2.fromOffset(guess, HEADH)
        frame.MouseEnter:Connect(function()
            card._state.hot = true
            card:_ring()
        end)
        frame.MouseLeave:Connect(function()
            card._state.hot = false
            card:_ring()
        end)
        fold.MouseEnter:Connect(function()
            card._state.foldHot = true
            card.Chev.Paint()
        end)
        fold.MouseLeave:Connect(function()
            card._state.foldHot = false
            card.Chev.Paint()
        end)
        fold.MouseButton1Click:Connect(function() card:Fold(not card.Folded) end)
        card._cmaid:Add(head.InputBegan:Connect(function(input)
            if not pressed(input) then return end
            local now = tick()
            if card._click and now - card._click < 0.3 then
                card._click = nil
                card:Fold(not card.Folded)
                return
            end
            card._click = now
            win:_cardDrag(card)
        end))
        set.Cards[id] = card
        set.Order[#set.Order + 1] = card
        win._nav[#win._nav + 1] = { Label = title, Lower = string.lower(title), Path = path, Card = card }
        card:_sync(true)
        set:_build()
        if win.Page == self and self:_current() == set then
            card:_show(not card.Folded)
            set:_place(false)
        end
        return card
    end

    function Card:_grips()
        local frame, state = self.Root, self._state
        local function token(T)
            if state.lim then return T.tx4 end
            if state.gripHot or state.on then return T.accent end
            return T.ln3
        end
        local grip, repaint = dots(frame, { Name = "Grip", ZIndex = 6, Position = UDim2.new(1, -12, 1, -12), Size = UDim2.fromOffset(12, 12) }, 8, token)
        self.EdgeX = Util.new("Frame", { Name = "EdgeX", Active = true, BackgroundTransparency = 1, ZIndex = 6, Position = UDim2.new(1, -4, 0, 24), Size = UDim2.new(0, 7, 1, -36), Parent = frame })
        self.EdgeY = Util.new("Frame", { Name = "EdgeY", Active = true, BackgroundTransparency = 1, ZIndex = 6, Position = UDim2.new(0, 0, 1, -4), Size = UDim2.new(1, -12, 0, 7), Parent = frame })
        self.Grip = grip
        self._repaintGrip = repaint
        grip.MouseEnter:Connect(function()
            state.gripHot = true
            repaint()
        end)
        grip.MouseLeave:Connect(function()
            state.gripHot = false
            repaint()
        end)
        local win = self.Window
        local function start(axis)
            return function(input)
                if not pressed(input) then return end
                if axis == "xy" then
                    local now = tick()
                    if self._gripClick and now - self._gripClick < 0.3 then
                        self._gripClick = nil
                        self:ResetSize()
                        return
                    end
                    self._gripClick = now
                end
                win:_cardSize(self, axis)
            end
        end
        self._cmaid:Add(self.EdgeX.InputBegan:Connect(start("x")))
        self._cmaid:Add(self.EdgeY.InputBegan:Connect(start("y")))
        self._cmaid:Add(grip.InputBegan:Connect(start("xy")))
    end

    function Card:_ring()
        local state = self._state
        local hot = state.hot or self._lifted
        if state.lim or self._lifted then
            Theme.bind(self.Stroke, "Color", "accent")
            self.Stroke.Transparency = self._lifted and 0.65 or 0.7
        else
            Theme.unbind(self.Stroke, "Color")
            self.Stroke.Color = Color3.new(1, 1, 1)
            self.Stroke.Transparency = hot and 0.93 or 0.955
        end
        if self._repaintGrip then self._repaintGrip() end
    end

    function Card:_lim(on)
        if self._state.lim == on then return end
        self._state.lim = on
        self:_ring()
    end

    function Card:_target()
        if self.Folded then return 0 end
        local nat = self.Height
        if self.Fixed then return math.max(0, math.min(self.Fixed - HEADH, nat)) end
        return nat
    end

    function Card:_outer()
        return HEADH + Util.snap(self._bodyH)
    end

    function Card:_apply()
        local body = Util.snap(self._bodyH)
        self.Root.Size = UDim2.fromOffset(self.W, HEADH + body)
        self.Body.Frame.Size = UDim2.new(1, -2, 0, body)
        self.Body:Refit()
        self.Body.Wheel = not self.Folded and self.Height > body + 0.5
        for _, shade in ipairs(self._shades) do shade.Visible = body > 0 end
        local gripsOn = not self.Folded and not self._lifted
        self.Grip.Visible, self.EdgeX.Visible, self.EdgeY.Visible = gripsOn, gripsOn, gripsOn
    end

    function Card:_sync(quiet)
        if self._tween and self._tween:Running() then return end
        if self._sizing then return end
        self._bodyH = self:_target()
        self:_apply()
        if not quiet then self:_relayoutPage(false) end
    end

    function Card:_relayoutPage(animate)
        local page, set = self.Page, self.Set
        if self.Window.Page == page and page:_current() == set then set:_place(animate) end
    end

    function Card:_width(w)
        self.W = w
        self.Root.Size = UDim2.fromOffset(w, self:_outer())
        self:_resize(w - 2)
    end

    function Card:_tweenTo(onDone)
        if self._tween then self._tween:Stop() end
        local from, to = self._bodyH, self:_target()
        self._tween = Anim.value(self, from, to, "move", function(v)
            self._bodyH = v
            self:_apply()
            self:_relayoutPage(false)
        end, function()
            self._tween = nil
            self:_sync()
            if onDone then onDone() end
        end)
    end

    function Card:Fold(folded)
        folded = folded and true or false
        if folded == self.Folded then return end
        self.Folded = folded
        self.Window.Folds[self.Key] = folded or nil
        Store.put("fold", self.Window.Folds)
        self.Chev.Set(not folded)
        if not folded then self:_show(self.Window.Page == self.Page and self.Page:_current() == self.Set) end
        self:_tweenTo(function()
            if self.Folded then self:_show(false) end
        end)
    end

    function Card:IsFolded()
        return self.Folded
    end

    function Card:SetTitle(title)
        self.Title = tostring(title)
        self.TitleLabel.Text = self.Title
    end

    function Card:_minH()
        local first
        for _, el in ipairs(self.Elements) do
            if el.Visible then
                first = el
                break
            end
        end
        local want = first and (HEADH + self.PadTop + first:_height() + 4) or CARDMIN
        want = math.ceil(want / 4) * 4
        return math.min(HEADH + self.Height, math.max(CARDMIN, want))
    end

    function Card:ResetSize()
        local win, set = self.Window, self.Set
        win.Sizes[self.Key] = nil
        self.Fixed = nil
        Store.put("csize", win.Sizes)
        if self.Full then
            self.Full = false
            set:_build(set:_save())
            set:_place(true)
        end
        self:_tweenTo()
    end

    function Card:SetHeight(h)
        local nat = HEADH + self.Height
        if h == nil or h >= nat then self.Fixed = nil else self.Fixed = math.max(self:_minH(), Util.snap(h)) end
        self.Window.Sizes[self.Key] = self.Fixed
        Store.put("csize", self.Window.Sizes)
        self:_tweenTo()
    end

    function Card:SetSpan(full)
        full = full and true or false
        if self.Full == full then return end
        self.Full = full
        local set = self.Set
        set:_build(set:_save())
        set:_place(true)
    end

    function Window:_cardDrag(card)
        if card._land then card._land() end
        if self._drag or card._sizing then return end
        local set, page = card.Set, card.Page
        local m0 = Input.mouse()
        local lifted, ghost, follow, loop, grab, homeRows = false, nil, nil, nil, nil, nil
        local function toLift(x, y)
            local wx, wy = Input.rect(self.Win)
            return x - wx, y - wy
        end
        local function copyRows()
            local out = {}
            for i, row in ipairs(set.Rows) do
                if row.full then out[i] = { full = row.full } else out[i] = { cols = { Util.copy(row.cols[1]), Util.copy(row.cols[2]) } } end
            end
            return out
        end
        local function place(pos)
            local lx, ly = toLift(pos.X - grab.X, pos.Y - grab.Y)
            follow.Set(Vector2.new(lx, ly))
            local geo = set._geo
            if not geo then return end
            local px, py = Input.rect(page.Frame)
            local mx, my = pos.X - px, pos.Y - py
            local best, bestD
            for _, band in ipairs(geo.bands) do
                for _, col in ipairs(band.cols) do
                    local top = geo.stacked and col.top or band.top
                    local bottom = geo.stacked and col.bottom or band.bottom
                    local d = math.max(0, top - my, my - bottom)
                    if not geo.stacked then d = d + math.abs(mx - (col.x + col.w / 2)) end
                    if not bestD or d < bestD then best, bestD = col, d end
                end
            end
            if not best then return end
            local list = best.col
            local before
            for _, item in ipairs(list) do
                if item ~= ghost and (item.RestY or 0) + (item.RestH or 0) / 2 > my then
                    before = item
                    break
                end
            end
            local r, ci, idx = set:_find(ghost)
            if ci and set.Rows[r].cols[ci] == list then
                local nextItem = list[idx + 1]
                if nextItem == before then return end
            end
            set:_remove(ghost)
            local at = #list + 1
            if before then
                for i, item in ipairs(list) do
                    if item == before then at = i end
                end
            end
            table.insert(list, at, ghost)
            set:_place(true)
        end
        local function lift()
            lifted = true
            local x, y = Input.rect(card.Root)
            grab = Vector2.new(m0.X - x, m0.Y - y)
            ghost = { ghost = true, H = card:_outer(), Root = Util.new("Frame", { Name = "Ghost", BackgroundTransparency = 0.96, Theme = { BackgroundColor3 = "accent" }, Parent = page.Frame }) }
            Util.new("UIStroke", { Thickness = 1, Transparency = 0.55, Theme = { Color = "accent" }, Parent = ghost.Root })
            local r, ci, idx = set:_find(card)
            if not r then return end
            if ci then set.Rows[r].cols[ci][idx] = ghost else set.Rows[r].full = ghost end
            homeRows = copyRows()
            Layer.closeAll()
            card._lifted = true
            Anim.stop(card.Root, "Position")
            local lx, ly = toLift(x, y)
            card.Root.Parent = self.Lift
            card.Root.Position = UDim2.fromOffset(lx, ly)
            card:_ring()
            card:_apply()
            self._drag = { card = card, ghost = ghost, set = set }
            set:_place(true)
            follow = Anim.follow(Vector2.new(lx, ly), function(v)
                card.Root.Position = UDim2.fromOffset(Util.snap(v.X), Util.snap(v.Y))
            end, 0.25)
            loop = Anim.loop(function(dt)
                local pos = Input.mouse()
                local _, by, _, bh = Input.rect(self.Body.Frame)
                local dy = 0
                if pos.Y < by + 40 then dy = -8 elseif pos.Y > by + bh - 40 then dy = 8 end
                if dy ~= 0 and self.Body:CanScroll(dy) then
                    self.Body:To(self.Body.Y + dy * math.min(4, dt * 60))
                    place(pos)
                end
                return true
            end)
        end
        local queued = Anim.coalesce(function(pos) place(pos) end)
        local function drop(cancelled)
            queued.Cancel()
            follow:Stop()
            loop:Stop()
            if cancelled and homeRows then set.Rows = homeRows end
            set:_place(true)
            local px, py = Input.rect(page.Frame)
            local tx, ty = toLift(px + ghost.RestX, py + ghost.RestY)
            local done = false
            local function land()
                if done then return end
                done = true
                card._land = nil
                Anim.stop(card.Root, "Position")
                local r, ci, idx = set:_find(ghost)
                if r then
                    if ci then set.Rows[r].cols[ci][idx] = card else set.Rows[r].full = card end
                end
                ghost.Root:Destroy()
                card._lifted = false
                card.Root.Parent = page.Frame
                card.Root.Position = UDim2.fromOffset(ghost.RestX, ghost.RestY)
                card.Root.Visible = set._showing == true
                self._drag = nil
                card:_ring()
                card:_apply()
                if not cancelled then set:_build(set:_save()) end
                set:_place(false)
            end
            card._land = land
            Anim.to(card.Root, { Position = UDim2.fromOffset(tx, ty) }, "move", land)
        end
        Input.capture(function(pos)
            if not lifted then
                if (pos - m0).Magnitude < 5 then return end
                lift()
                if not lifted or not follow then return end
            end
            queued.Push(pos)
        end, function(_, cancelled)
            if lifted and follow and not cancelled then queued.Flush() end
            if lifted and follow then drop(cancelled) end
        end)
    end

    function Window:_cardSize(card, axis)
        if card._lifted or self._drag then return end
        local set = card.Set
        local geo = set._geo
        if not geo then return end
        Layer.closeAll()
        if card._tween then
            card._tween:Stop()
            card._tween = nil
        end
        local m0 = Input.mouse()
        local full0 = card.Full
        local nat = HEADH + card.Height
        local minH = card:_minH()
        local h0 = card:_outer()
        local right = PAD + geo.inner
        local one = full0 and geo.w[1] or card.RestW
        local left1 = full0 and PAD or card.RestX
        local cut = (left1 + one + right) / 2
        if right - (left1 + one) < 48 then cut = left1 + one + 24 end
        local edge0 = full0 and right or (card.RestX + card.RestW)
        local hgt, moved, follow = h0, false, nil
        card._sizing = true
        card._state.on = true
        card:_ring()
        local function show(v)
            card._bodyH = math.max(0, math.min(v, nat) - HEADH)
            card:_apply()
            card:_relayoutPage(false)
        end
        Input.capture(function(pos)
            if axis ~= "y" and not geo.stacked then
                local want = edge0 + pos.X - m0.X > cut
                if want ~= card.Full then card:SetSpan(want) end
            end
            if axis ~= "x" and not card.Folded and pos.Y ~= m0.Y then
                moved = true
                local want = math.floor((h0 + pos.Y - m0.Y) / 4 + 0.5) * 4
                hgt = Util.clamp(want, minH, nat)
                card:_lim(want < minH - 2 or want > nat + 2)
                if Anim.calm then
                    show(hgt)
                else
                    if not follow then follow = Anim.follow(h0, show, 0.25) end
                    follow.Set(hgt)
                end
            end
        end, function(_, cancelled)
            if follow then follow:Stop() end
            card._sizing = false
            card._state.on = false
            card:_lim(false)
            card:_ring()
            if cancelled then
                card:SetSpan(full0)
            elseif moved then
                card.Fixed = hgt < nat and hgt or nil
                self.Sizes[card.Key] = card.Fixed
                Store.put("csize", self.Sizes)
            end
            card:_tweenTo()
        end)
    end

    Kinds._topslot = {
        method = "_TopSlot", label = false, index = false,
        height = function(el) return el.Opts.height or 20 end,
        build = function() end,
    }

    local function sectionPaint(el)
        local open, hot = el._open, el._hot
        Text.style(el._label, open and "bold" or "body")
        Theme.bind(el._label, "TextColor3", hot and "tx" or (open and "tx2" or "tx3"))
        el._head.BackgroundTransparency = hot and 0.98 or 1
        el._chev.Paint()
        el._chev.Set(open)
        local width = Text.width(el._name, open and "bold" or "body")
        el._rule.Position = UDim2.fromOffset(24 + width + 8, 12)
        el._rule.Size = UDim2.new(1, -(24 + width + 16), 0, 1)
    end

    Kinds.section = {
        method = "Section", label = false,
        height = function(el) return 28 + Util.snap(el._bodyH or 0) end,
        methods = {
            Open = function(el, open, instant)
                open = open ~= false
                local inner = el._inner
                if not inner then return end
                if el._open ~= open then
                    el._open = open
                    local win = Aster._window
                    if win then
                        win.Subs[el._key] = open
                        Store.put("subs", win.Subs)
                    end
                end
                sectionPaint(el)
                if open then inner:_show(el:IsShown()) end
                if el._tw then el._tw:Stop() end
                el._tw = Anim.value(el, el._bodyH, open and inner.Height or 0, instant and 0 or "move", function(v)
                    el._bodyH = v
                    el._body.Size = UDim2.new(1, 0, 0, Util.snap(v))
                    el:_relayout()
                end, function()
                    el._tw = nil
                    if not el._open then inner:_show(false) end
                end)
            end,
            IsOpen = function(el) return el._open end,
        },
        build = function(el, row)
            local opts, outer = el.Opts, el.Container
            local name = tostring(opts.name or "section")
            local win = Aster._window
            local key = opts.key or (pathKey(outer.Path) .. ":" .. Util.slug(name))
            el._name, el._key, el._default = name, key, opts.open == true
            local open = el._default
            if win then
                if win.Subs[key] ~= nil then open = win.Subs[key] end
                win._subKeys[key] = true
                win._sections = win._sections or setmetatable({}, { __mode = "k" })
                win._sections[el] = true
            end
            el._open, el._hot = open, false
            local head = Util.new("TextButton", { Name = "Head", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 2), Size = UDim2.new(1, 0, 0, 24), Parent = row })
            el._head = head
            el._chev = chevron(head, UDim2.fromOffset(8, 8), function(T)
                if el._hot then return T.tx end
                return el._open and T.accent or T.tx3
            end)
            el._label = label(head, { Name = "Label", Text = name, Position = UDim2.fromOffset(24, 0), Size = UDim2.new(1, -32, 1, 0), TextTruncate = Enum.TextTruncate.None }, "body", "tx3")
            el._rule = rule(head, "Rule", UDim2.fromOffset(0, 12), UDim2.new(0, 0, 0, 0), "ln")
            local body = Util.new("Frame", { Name = "Body", BackgroundTransparency = 1, ClipsDescendants = true, Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 0), Parent = row })
            el._body = body
            rule(body, "Line", UDim2.fromOffset(12, 0), UDim2.new(0, 1, 1, 0), "ln2")
            local frame = Util.new("Frame", { Name = "Inner", BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -16, 0, 0), Parent = body })
            local path = table.move(outer.Path, 1, #outer.Path, 1, {})
            path[#path + 1] = { kind = "section", ref = el, name = name, id = Util.slug(name) }
            local inner = Container.new(frame, { width = outer.Width - 16, path = path, bg = outer.Bg, shown = false })
            el._inner = inner
            el._bodyH = open and inner.Height or 0
            body.Size = UDim2.new(1, 0, 0, Util.snap(el._bodyH))
            inner.Resized:Connect(function(h)
                if not (el._tw and el._tw:Running()) then
                    el._bodyH = el._open and h or 0
                    body.Size = UDim2.new(1, 0, 0, Util.snap(el._bodyH))
                end
                el:_relayout()
            end)
            el._maid:Add(el.Shown:Connect(function(v) inner:_show(v and el._open) end))
            inner:_show(el:IsShown() and open)
            head.MouseEnter:Connect(function()
                el._hot = true
                sectionPaint(el)
            end)
            head.MouseLeave:Connect(function()
                el._hot = false
                sectionPaint(el)
            end)
            head.MouseButton1Click:Connect(function() el:Open(not el._open) end)
            sectionPaint(el)
            return inner
        end,
        resize = function(el, width)
            if el._inner then el._inner:_resize(width - 16) end
        end,
        destroy = function(el)
            if el._tw then el._tw:Stop() end
            if el._inner then el._inner:Destroy() end
        end,
    }

    function Window:Search(query)
        local q = string.lower(tostring(query or ""))
        q = string.match(q, "^%s*(.-)%s*$")
        if q == "" then return {} end
        local hits = {}
        local function scan(list)
            for _, entry in ipairs(list) do
                if #hits >= 12 then return end
                if type(entry.Lower) == "string" and string.find(entry.Lower, q, 1, true) then hits[#hits + 1] = entry end
            end
        end
        scan(Aster._index)
        scan(self._nav)
        return hits
    end

    function Window.describe(entry)
        local parts, gear = {}, nil
        for _, node in ipairs(entry.Path or {}) do
            if type(node) == "table" then
                if node.kind == "tab" or node.kind == "page" or node.kind == "variant" then
                    parts[#parts + 1] = string.lower(tostring(node.name))
                elseif node.kind == "gear" then
                    gear = tostring(node.name or "gear")
                end
            elseif node == "gear" then
                gear = "gear"
            end
        end
        local text = table.concat(parts, " / ")
        if gear then text = text .. " \194\183 " .. string.lower(gear) end
        return text
    end

    function Window:_search()
        local open = self._searchHandle
        if open and not open.Closed then
            open.Close()
            return
        end
        local win = self
        self._searchHandle = Layer.open(self.SearchButton, function(frame, handle)
            local field = Util.new("Frame", { Name = "Field", Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, 24), Theme = { BackgroundColor3 = "ddBg" }, Parent = frame })
            Util.new("UIStroke", { Thickness = 1, Theme = { Color = "ddBd" }, Parent = field })
            local box = Util.new("TextBox", {
                Name = "Query", Text = "", PlaceholderText = "search", TextStyle = "body", TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1,
                Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -16, 1, 0), Theme = { TextColor3 = "ddTx", PlaceholderColor3 = "tx4" }, Parent = field,
            })
            local results = Scroll.new(frame, { name = "Results", position = UDim2.fromOffset(0, 40), size = UDim2.new(1, 0, 0, 0) })
            local rows = {}
            local hits = {}
            local function pick(entry)
                handle.Close()
                win:_reveal(entry)
            end
            local function draw()
                for _, r in ipairs(rows) do r:Destroy() end
                rows = {}
                hits = win:Search(box.Text)
                local count = #hits
                local q = string.match(box.Text, "^%s*(.-)%s*$")
                if q ~= "" and count == 0 then
                    rows[1] = label(results.Content, { Name = "None", Text = "no matches", Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -24, 0, 24) }, "body", "tx4")
                    count = 1
                end
                for i, entry in ipairs(hits) do
                    local btn = Util.new("TextButton", { Name = "Result", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, Position = UDim2.fromOffset(0, (i - 1) * 24), Size = UDim2.new(1, 0, 0, 24), Parent = results.Content })
                    if i == 1 then
                        Theme.bind(btn, "BackgroundColor3", "ddHl")
                        btn.BackgroundTransparency = 0.93
                        rule(btn, "Bar", UDim2.new(0, 0, 0, 0), UDim2.new(0, 2, 1, 0), "ddHl")
                    end
                    label(btn, { Name = "Label", Text = entry.Label, Position = UDim2.fromOffset(8, 0), Size = UDim2.new(0.5, -8, 1, 0) }, "body", "tx2")
                    label(btn, { Name = "Where", Text = Window.describe(entry), TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0.5, -12, 1, 0) }, "tiny", "tx4")
                    btn.MouseButton1Click:Connect(function() pick(entry) end)
                    rows[#rows + 1] = btn
                end
                results:SetHeight(count * 24)
                local listH = math.min(count * 24, 260)
                results.Frame.Size = UDim2.new(1, 0, 0, listH)
                results:Refit()
                handle.Resize(8 + 24 + (count > 0 and (8 + listH) or 0) + 8)
            end
            box:GetPropertyChangedSignal("Text"):Connect(draw)
            box.FocusLost:Connect(function(enter)
                if not enter then return end
                draw()
                if hits[1] then pick(hits[1]) end
            end)
            draw()
            pcall(function() box:CaptureFocus() end)
            win.SearchBox = box
        end, { side = "bottom", width = 300, box = self.Win })
        return self._searchHandle
    end

    function Window:_flash(row)
        local flash = Util.new("Frame", { Name = "Flash", BackgroundTransparency = 0.84, Size = UDim2.fromScale(1, 1), Theme = { BackgroundColor3 = "accent" }, Parent = row })
        Anim.to(flash, { BackgroundTransparency = 1 }, 1.2, function() flash:Destroy() end, Anim.linear)
        return flash
    end

    function Window:_reveal(target)
        local entry = target
        if type(target) == "table" and target.Path == nil and target[1] ~= nil then entry = { Path = target } end
        if type(entry) ~= "table" then return false end
        local gear, card
        for _, node in ipairs(entry.Path or {}) do
            if type(node) == "table" and node.ref then
                if node.kind == "page" then
                    self:Go(node.ref)
                elseif node.kind == "variant" then
                    node.ref:SetVariant(node.value)
                elseif node.kind == "card" then
                    card = node.ref
                    card:Fold(false)
                elseif node.kind == "section" then
                    node.ref:Open(true)
                elseif node.kind == "gear" then
                    gear = node
                end
            elseif type(node) == "table" and node.kind == "gear" then
                gear = node
            end
        end
        local row = entry.Element and entry.Element.Row or (card and card.Root)
        local function finish()
            if row and self.Page then
                if card and entry.Element and card.Body.Max > 0 then
                    local _, cy = Input.rect(card.Body.Content)
                    local _, ry, _, rh = Input.rect(row)
                    local view = card.Body:View()
                    card.Body:To((ry - cy) + rh / 2 - view / 2)
                end
                local _, py = Input.rect(self.Page.Frame)
                local _, ry, _, rh = Input.rect(row)
                self.Body:Reveal(ry - py, ry - py + rh, gear == nil)
                if entry.Element then self:_flash(row) end
            end
            if gear then
                local ref = gear.ref
                if ref and ref.Open then Util.guard(ref.Open, ref) elseif type(gear.open) == "function" then Util.guard(gear.open) end
            end
        end
        if Anim.calm then finish() else Anim.after(0.2, finish) end
        return true
    end

    function Window:_ready()
        if self._ready_ then return end
        self._ready_ = true
        self:_prune()
        if self.Opts.autoload ~= false then Store.runAutoload() end
    end

    function Window:_prune()
        local stale = {}
        for key, L in pairs(self.Layout) do
            local set = self._sets[key]
            local ok = set ~= nil
            if ok then
                for _, ids in ipairs(L) do
                    for _, id in ipairs(ids) do
                        if not set.Cards[id] then ok = false end
                    end
                end
            end
            if not ok then stale[#stale + 1] = key end
        end
        for _, key in ipairs(stale) do
            self.Layout[key] = nil
            local set = self._sets[key]
            if set then set:_build() end
        end
        if #stale > 0 then Store.put("layout", self.Layout) end
        for _, pair in ipairs({ { "fold", self.Folds }, { "csize", self.Sizes } }) do
            local map, dirty = pair[2], false
            for k in pairs(map) do
                local pk, id = string.match(k, "^(.*):([^:]*)$")
                local set = pk and self._sets[pk]
                if not (set and set.Cards[id]) then
                    map[k] = nil
                    dirty = true
                end
            end
            if dirty then Store.put(pair[1], map) end
        end
        local dirty = false
        for k in pairs(self.Subs) do
            if not self._subKeys[k] then
                self.Subs[k] = nil
                dirty = true
            end
        end
        if dirty then Store.put("subs", self.Subs) end
        if self.Page then self.Page:_relayout(false) end
        return #stale
    end

    function Window:ResetLayout()
        self.Layout, self.Folds, self.Sizes, self.Subs = {}, {}, {}, {}
        Store.put("layout", self.Layout)
        Store.put("fold", self.Folds)
        Store.put("csize", self.Sizes)
        Store.put("subs", self.Subs)
        for _, set in pairs(self._sets) do
            for _, card in ipairs(set.Order) do
                card.Fixed = nil
                if card.Folded then
                    card.Folded = false
                    card.Chev.Set(true)
                end
            end
            set:_build()
        end
        for el in pairs(self._sections or {}) do
            if not el.Destroyed then el:Open(el._default) end
        end
        self.Subs = {}
        Store.put("subs", self.Subs)
        if self.Page then self.Page:_shown(true) end
        for _, set in pairs(self._sets) do
            for _, card in ipairs(set.Order) do card:_tweenTo() end
        end
        self:SetSize(W0, H0)
        if self.Page then self.Page:_relayout(true) end
    end
end

-- [src] 40_toggle.lua
do
    local LINE, BOX = Element.LINE, 12

    local function tween(obj, props, kind)
        return Anim.to(obj, props, kind or 0)
    end

    local function lower(T)
        if T.style == "gradient" then return Util.mix(T.accent, T.well, 0.3) end
        return T.accent
    end

    Kinds.toggle = {
        method = "Toggle", default = false,
        validate = function(opts, value)
            if type(value) == "boolean" then return value end
            return nil
        end,
        build = function(el, row)
            el.Hit = Util.new("TextButton", { Name = "Hit", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, LINE), Parent = row })
            local lead = el:_lead(BOX - Element.LEAD + 4)
            local box = Util.new("Frame", { Name = "Box", Position = UDim2.fromOffset(0, (LINE - BOX) / 2), Size = UDim2.fromOffset(BOX, BOX), Theme = { BackgroundColor3 = "black" }, Parent = lead })
            local inner = Util.new("Frame", { Name = "Inner", Position = UDim2.fromOffset(1, 1), Size = UDim2.fromOffset(BOX - 2, BOX - 2), Parent = box })
            Theme.fill(inner, "ln2", "hi")
            el._ring = Util.new("Frame", { Name = "Ring", BackgroundTransparency = 0.95, Size = UDim2.fromScale(1, 1), Theme = { BackgroundColor3 = "white" }, Parent = inner })
            local core = Util.new("Frame", { Name = "Core", Position = UDim2.fromOffset(1, 1), Size = UDim2.fromOffset(BOX - 4, BOX - 4), Parent = el._ring })
            Theme.fill(core, "ln2", "hi")
            el._fill = Util.new("Frame", { Name = "Fill", BackgroundTransparency = 1, Position = UDim2.fromOffset(1, 1), Size = UDim2.fromOffset(BOX - 2, BOX - 2), Parent = box })
            Theme.fill(el._fill, "accent", lower)
            el._shine = Util.new("Frame", { Name = "Shine", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 1), Theme = { BackgroundColor3 = "white" }, Parent = el._fill })
            el.Box = box
            el._maid:Add(el.Hit.MouseButton1Click:Connect(function()
                if el.Disabled then return end
                el:Set(not el.Value)
            end))
        end,
        paint = function(el)
            local on = el.Value == true
            local kind = el._painted and "fade" or nil
            el._painted = true
            tween(el._fill, { BackgroundTransparency = on and 0 or 1 }, kind)
            tween(el._shine, { BackgroundTransparency = on and 0.75 or 1 }, kind)
            tween(el._ring, { BackgroundTransparency = el.Hover and 0.88 or 0.95 }, kind)
            el:_light(on)
        end,
    }
end

-- [src] 41_slider.lua
do
    local LINE, PAD = Element.LINE, Element.PAD
    local HEIGHT, TOP, TRACK_Y, STEP_W, EDIT_W = 36, 4, 24, 14, 52

    local function tween(obj, props, kind)
        return Anim.to(obj, props, kind or 0)
    end

    local function clamp(value, min, max)
        return math.max(min, math.min(max, value))
    end

    local function range(opts)
        local min, max = tonumber(opts.min) or 0, tonumber(opts.max) or 100
        if max < min then min, max = max, min end
        local step = tonumber(opts.step) or 1
        if step <= 0 or step ~= step then step = 1 end
        return min, max, step
    end

    local function decimals(step)
        local digits = string.match(string.format("%.10g", step), "%.(%d+)$")
        return digits and #digits or 0
    end

    local function snapValue(opts, value)
        if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then return nil end
        local min, max, step = range(opts)
        value = clamp(min + math.floor((value - min) / step + 0.5) * step, min, max)
        return tonumber(string.format("%." .. decimals(step) .. "f", value))
    end

    local function format(el, value)
        local opts = el.Opts
        if opts.fmt then
            local ok, text = Util.guard(opts.fmt, value)
            if ok and text ~= nil then return tostring(text) end
        end
        local _, _, step = range(opts)
        return string.format("%." .. decimals(step) .. "f", value)
    end

    local function lower(T)
        if T.style == "gradient" then return Util.mix(T.accent, T.well, 0.45) end
        return T.accent
    end

    local function innerWidth(el)
        local width = el.Container.Width
        if not width or width <= 0 then
            local ok, size = pcall(function() return el.Row.AbsoluteSize.X end)
            width = ok and size or 0
        end
        return math.max(0, width - el.X - PAD - 2)
    end

    local function stepper(el, row, text, dir)
        local button = Util.new("TextButton", {
            Name = dir < 0 and "Minus" or "Plus",
            Size = UDim2.fromOffset(STEP_W, STEP_W), Theme = { BackgroundColor3 = "black" }, Parent = row,
        })
        local inner = Util.new("Frame", { Name = "Inner", Position = UDim2.fromOffset(1, 1), Size = UDim2.fromOffset(STEP_W - 2, STEP_W - 2), Parent = button })
        Theme.fill(inner, "btnBg", "btnBg2")
        local label = Util.new("TextLabel", { Name = "Text", Text = text, TextStyle = "body", Size = UDim2.fromScale(1, 1), Theme = { TextColor3 = "tx3" }, Parent = inner })
        el._maid:Add(button.MouseEnter:Connect(function() Theme.bind(label, "TextColor3", "accent") end))
        el._maid:Add(button.MouseLeave:Connect(function() Theme.bind(label, "TextColor3", "tx3") end))
        el._maid:Add(button.MouseButton1Click:Connect(function()
            if el.Disabled then return end
            local _, _, step = range(el.Opts)
            el:Set(el.Value + dir * step)
        end))
        return button
    end

    local function origin(input)
        local mouse = Input.mouse()
        return mouse.X - input.Position.X, mouse.Y - input.Position.Y
    end

    local function edit(el)
        if el._edit or el.Disabled then return end
        local maid = Util.Maid.new()
        el._maid:Add(maid)
        local cancelled, done = false, false
        local box = maid:Add(Util.new("TextBox", {
            Name = "Edit", Text = format(el, el.Value), TextStyle = "body", TextXAlignment = Enum.TextXAlignment.Right,
            Size = UDim2.fromOffset(EDIT_W, 16), Theme = { BackgroundColor3 = "well", TextColor3 = "tx" }, Parent = el.Row,
        }))
        Util.new("UIStroke", { Thickness = 1, Theme = { Color = "accent" }, Parent = box })
        el._edit = box
        local function close()
            if done then return end
            done = true
            local text = box.Text
            el._edit = nil
            maid:Clean()
            local value = tonumber((string.gsub(string.match(text, "^%s*(%-?[%d%.,]+)") or "", ",", ".")))
            if not cancelled and value then el:Set(value) end
            el:_paint()
        end
        maid:Add(box.FocusLost:Connect(close))
        maid:Add(Input.onKey(function(name, down)
            if down and name == "escape" then
                cancelled = true
                if box:IsFocused() then box:ReleaseFocus(false) end
                close()
            end
        end))
        el:_paint()
        box:CaptureFocus()
    end

    local function drag(el, input)
        if el.Disabled then return end
        if Input.ctrl() then return edit(el) end
        local ox = origin(input)
        local min, max = range(el.Opts)
        local function at(pos)
            local width = innerWidth(el)
            local x = pos.X - ox - el._track.AbsolutePosition.X - 1
            el:Set(min + clamp(width > 0 and x / width or 0, 0, 1) * (max - min))
        end
        el._dragging = true
        at(Input.mouse())
        el._stopDrag = Input.capture(at, function()
            el._dragging = false
            el._stopDrag = nil
            el:_paint()
        end)
    end

    Kinds.slider = {
        method = "Slider", height = HEIGHT,
        default = function(opts) return (range(opts)) end,
        validate = function(opts, value) return snapValue(opts, tonumber(value)) end,
        build = function(el, row)
            local x = el.X
            local track = Util.new("Frame", {
                Name = "Track", Position = UDim2.fromOffset(x, TRACK_Y), Size = UDim2.new(1, -(x + PAD), 0, 8),
                Theme = { BackgroundColor3 = "black" }, Parent = row,
            })
            local inner = Util.new("Frame", { Name = "Inner", Position = UDim2.fromOffset(1, 1), Size = UDim2.new(1, -2, 1, -2), Parent = track })
            Theme.fill(inner, "well", "card")
            el._fill = Util.new("Frame", { Name = "Fill", Size = UDim2.new(0, 0, 1, 0), Parent = inner })
            Theme.fill(el._fill, "accent", lower)
            Util.new("Frame", { Name = "Shine", BackgroundTransparency = 0.82, Size = UDim2.new(1, 0, 0, 1), Theme = { BackgroundColor3 = "white" }, Parent = el._fill })
            el._glow = Util.new("Frame", { Name = "Glow", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Theme = { BackgroundColor3 = "white" }, Parent = el._fill })
            el._track = track

            el._num = Util.new("TextLabel", { Name = "Value", TextStyle = "body", TextXAlignment = Enum.TextXAlignment.Right, Theme = { TextColor3 = "tx" }, Parent = row })
            el._unit = Util.new("TextLabel", {
                Name = "Unit", Text = tostring(el.Opts.unit or ""):gsub("^%s+", ""), TextStyle = "body",
                TextXAlignment = Enum.TextXAlignment.Right, Theme = { TextColor3 = "tx4" }, Parent = row,
            })
            el.Minus = stepper(el, row, "-", -1)
            el.Plus = stepper(el, row, "+", 1)
            el.Minus.Position = UDim2.new(1, -(PAD + STEP_W * 2 + 2), 0, TOP + 1)
            el.Plus.Position = UDim2.new(1, -(PAD + STEP_W), 0, TOP + 1)

            el.TrackHit = Util.new("TextButton", {
                Name = "TrackHit", BackgroundTransparency = 1, Position = UDim2.fromOffset(x, TRACK_Y - 6), Size = UDim2.new(1, -(x + PAD), 0, 20), Parent = row,
            })
            el.ValueHit = Util.new("TextButton", { Name = "ValueHit", BackgroundTransparency = 1, Parent = row })
            el._maid:Add(el.TrackHit.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then drag(el, input) end
            end))
            el._maid:Add(el.ValueHit.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 and Input.ctrl() then edit(el) end
            end))
            el._maid:Add(el.TrackHit.MouseEnter:Connect(function()
                el._trackHover = true
                el:_paint()
            end))
            el._maid:Add(el.TrackHit.MouseLeave:Connect(function()
                el._trackHover = false
                el:_paint()
            end))
            el._maid:Add(row.InputChanged:Connect(function(input)
                if el.Disabled or input.UserInputType ~= Enum.UserInputType.MouseWheel then return end
                if not Input.shift() or input.Position.Z == 0 then return end
                local _, _, step = range(el.Opts)
                el:Set(el.Value + (input.Position.Z > 0 and step or -step))
            end))
            el._maid:Add(function()
                if el._stopDrag then el._stopDrag() end
            end)
        end,
        paint = function(el)
            local min, max = range(el.Opts)
            local first = not el._painted
            local kind = not (first or el._dragging) and "move" or nil
            el._painted = true
            local text = format(el, el.Value)
            local unit = el._unit.Text
            local unitW = unit ~= "" and Text.width(unit, "body") or 0
            local numW = el._edit and EDIT_W or Text.width(text, "body")
            local right = PAD + STEP_W * 2 + 2 + 8
            el._unit.Position = UDim2.new(1, -(right + unitW), 0, TOP)
            el._unit.Size = UDim2.fromOffset(unitW, 16)
            local numRight = right + unitW + (unitW > 0 and 4 or 0)
            el._num.Text = text
            el._num.Visible = el._edit == nil
            el._num.Position = UDim2.new(1, -(numRight + numW), 0, TOP)
            el._num.Size = UDim2.fromOffset(numW, 16)
            el.ValueHit.Position = UDim2.new(1, -(numRight + numW), 0, TOP)
            el.ValueHit.Size = UDim2.fromOffset(numW + (unitW > 0 and unitW + 4 or 0), 16)
            if el._edit then el._edit.Position = UDim2.new(1, -(numRight + EDIT_W), 0, TOP) end
            if el.Label then
                el.Label.Position = UDim2.fromOffset(el.X, TOP)
                el.Label.Size = UDim2.new(1, -(el.X + numRight + numW + 8), 0, 16)
            end
            local fraction = max > min and (el.Value - min) / (max - min) or 0
            tween(el._fill, { Size = UDim2.new(0, Util.snap(fraction * innerWidth(el)), 1, 0) }, kind)
            tween(el._glow, { BackgroundTransparency = (el._trackHover or el._dragging) and not el.Disabled and 0.88 or 1 }, not first and "fade" or nil)
        end,
        resize = function(el)
            local painted = el._painted
            el._painted = false
            el:_paint()
            el._painted = painted
        end,
        methods = {
            Edit = function(self) edit(self) end,
        },
    }
end

-- [src] 42_keybind.lua
do
    local SLOT, PULSE = 44, 1.1
    local MODES = { always = "a", toggle = "t", hold = "h" }
    local MOUSE = {
        mousebutton1 = "m1", mousebutton2 = "m2", mousebutton3 = "m3", mousebutton4 = "m4", mousebutton5 = "m5",
        m1 = "m1", m2 = "m2", m3 = "m3", m4 = "m4", m5 = "m5",
    }
    local SHORT = {
        insert = "ins", delete = "del", pagedown = "pgdn", pageup = "pgup", space = "spc", capslock = "caps", ["return"] = "ent",
        backspace = "bksp", leftshift = "lshf", rightshift = "rshf", leftcontrol = "lctl", rightcontrol = "rctl", leftalt = "lalt",
        rightalt = "ralt", backquote = "`", minus = "-", equals = "=", escape = "esc", right = "rgt", semicolon = ";", quote = "'",
        comma = ",", period = ".", slash = "/", backslash = "\\", leftbracket = "[", rightbracket = "]",
        zero = "0", one = "1", two = "2", three = "3", four = "4", five = "5", six = "6", seven = "7", eight = "8", nine = "9",
    }
    local list = {}
    local listening, swallowClick, swallowMenu

    local function tween(obj, props, kind)
        return Anim.to(obj, props, kind or 0)
    end

    local function keyOf(value)
        if value == nil or value == false then return "" end
        if typeof(value) == "EnumItem" then value = value.Name end
        if type(value) ~= "string" then return nil end
        local key = string.lower(value)
        key = string.gsub(key, "^enum%.keycode%.", "")
        key = string.gsub(key, "^enum%.userinputtype%.", "")
        if key == "none" or key == "unknown" then return "" end
        return MOUSE[key] or key
    end

    local function short(key)
        if SHORT[key] then return SHORT[key] end
        local pad = string.match(key, "^keypad(.+)$")
        if pad then return "num" .. string.sub(SHORT[pad] or pad, 1, 3) end
        return string.sub(key, 1, 4)
    end

    local function escape(text)
        return (string.gsub(text, "[<>&]", { ["<"] = "&lt;", [">"] = "&gt;", ["&"] = "&amp;" }))
    end

    local function hex(color)
        return Util.toHex(color)
    end

    local function parentToggle(el)
        local parent = el.Parent
        if parent and parent.Kind == "toggle" then return parent end
        return nil
    end

    local function sync(el)
        local active = el:Active()
        if active ~= el._active then
            el._active = active
            el.ActiveChanged:Fire(active, el)
            Kinds.keybind.Changed:Fire(el)
        end
    end

    local function stopListen()
        local el = listening
        if not el then return end
        listening = nil
        el._listen = false
        if el._pulse then el._pulse:Stop() end
        el._pulse = nil
        tween(el._chip, { TextTransparency = 0 }, "fade")
        el:_paint()
    end

    local function startListen(el)
        if el.Disabled then return end
        stopListen()
        listening = el
        el._listen = true
        el:_paint()
        if Anim.calm then return end
        local clock = 0
        el._pulse = Anim.loop(function(dt)
            clock = (clock + dt) % PULSE
            el._chip.TextTransparency = 0.55 * Anim.sine(clock / PULSE * 2)
            return listening == el
        end)
    end

    local function press(el, down)
        if down and el.Disabled then return end
        local mode = el.Value.mode
        if down then
            el.Pressed:Fire(el)
            if mode == "toggle" then
                local parent = parentToggle(el)
                if parent then
                    parent:Set(not parent.Value)
                else
                    el._on = not el._on
                end
            end
        end
        if mode == "hold" then el._held = down end
        sync(el)
        el:_paint()
    end

    Aster._maid:Add(Input.onKey(function(name, down, input)
        if listening then
            if not down then return end
            local el = listening
            if name == "escape" or name == "m1" then
                stopListen()
                if name == "m1" then swallowClick = el end
                return
            end
            stopListen()
            if name == "m2" then swallowMenu = el end
            el:Set({ key = name, mode = el.Value.mode })
            return
        end
        if down and (name == "m1" or name == "m2") then swallowClick, swallowMenu = nil, nil end
        if down and not MOUSE[name] then
            local ok, box = pcall(function() return UserInputService:GetFocusedTextBox() end)
            if ok and box then return end
        end
        local snapshot = table.move(list, 1, #list, 1, {})
        for _, el in ipairs(snapshot) do
            if el.Value.key == name and not el.Destroyed then press(el, down) end
        end
    end))

    local function release()
        for _, el in ipairs(list) do
            if el._held then press(el, false) end
        end
    end
    pcall(function() Aster._maid:Add(UserInputService.WindowFocusReleased:Connect(release)) end)

    Kinds.keybind = {
        method = "Keybind", slot = SLOT,
        default = function(opts) return { key = "", mode = MODES[opts.mode] and opts.mode or "toggle" } end,
        validate = function(opts, value)
            local mode = MODES[opts.mode] and opts.mode or "toggle"
            if type(value) == "table" and typeof(value) ~= "EnumItem" then
                local key = keyOf(value.key)
                if key == nil then return nil end
                if value.mode ~= nil and not MODES[value.mode] then return nil end
                return { key = key, mode = value.mode or mode }
            end
            local key = keyOf(value)
            if key == nil then return nil end
            return { key = key, mode = mode }
        end,
        encode = function(value) return { key = value.key, mode = value.mode } end,
        build = function(el, slot)
            el.ActiveChanged = el._maid:Add(Util.Signal.new())
            el.Pressed = el._maid:Add(Util.Signal.new())
            el._chip = Util.new("TextLabel", {
                Name = "Chip", RichText = true, TextStyle = "tiny", TextXAlignment = Enum.TextXAlignment.Right,
                Size = UDim2.fromScale(1, 1), Parent = slot,
            })
            el.Hit = Util.new("TextButton", { Name = "Hit", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = slot })
            el._maid:Add(el.Hit.MouseEnter:Connect(function()
                el._chipHover = true
                el:_paint()
            end))
            el._maid:Add(el.Hit.MouseLeave:Connect(function()
                el._chipHover = false
                el:_paint()
            end))
            el._maid:Add(el.Hit.MouseButton1Click:Connect(function()
                if swallowClick == el then
                    swallowClick = nil
                    return
                end
                startListen(el)
            end))
            el._maid:Add(el.Hit.MouseButton2Click:Connect(function()
                if swallowMenu == el then
                    swallowMenu = nil
                    return
                end
                if el.Disabled then return end
                el:Menu()
            end))
            local parent = parentToggle(el)
            if parent then
                el._maid:Add(parent._state:Connect(function()
                    sync(el)
                    el:_paint()
                end))
            end
            list[#list + 1] = el
            el._maid:Add(function()
                if listening == el then stopListen() end
                for index = #list, 1, -1 do
                    if list[index] == el then table.remove(list, index) end
                end
                Kinds.keybind.Changed:Fire(el)
            end)
            el._active = el:Active()
            Kinds.keybind.Changed:Fire(el)
        end,
        paint = function(el)
            local value = el.Value
            if el._painted and el._shownValue and not Util.same(el._shownValue, value) then
                el._shownValue = value
                if value.mode ~= "hold" then el._held = false end
                sync(el)
                Kinds.keybind.Changed:Fire(el)
            end
            el._painted = true
            el._shownValue = value
            local active = value.key ~= "" and el:Active()
            local listen = el._listen
            Theme.bind(el._chip, "TextColor3", (listen or active) and "accent" or (el._chipHover and not el.Disabled and "tx2" or "tx4"))
            Theme.bind(el._chip, "Text", function(T)
                if listen then return "[...]" end
                if value.key == "" then return "[-]" end
                local letter = MODES[value.mode]
                local muted = active and Util.mix(T.accent, T.panel, 0.4) or Util.mix(T.tx4, T.bg, 0.3)
                return "[" .. escape(short(value.key)) .. " <font color=\"" .. hex(muted) .. "\">" .. letter .. "</font>]"
            end)
        end,
        methods = {
            Active = function(self)
                local value = self.Value
                local parent = parentToggle(self)
                local base = true
                if parent then
                    base = parent.Value == true
                elseif value.mode == "toggle" then
                    base = self._on == true
                end
                if value.mode == "hold" then return base and value.key ~= "" and self._held == true end
                return base
            end,
            Key = function(self) return self.Value.key end,
            Mode = function(self) return self.Value.mode end,
            Name = function(self)
                local opts = self.Opts
                local parent = self.Parent
                return tostring(opts.hud or opts.name or (parent and (parent.Opts.hud or parent.Opts.name)) or "keybind")
            end,
            Listen = function(self) startListen(self) end,
            Menu = function(self)
                local value = self.Value
                local items = {}
                for _, mode in ipairs({ "always", "toggle", "hold" }) do
                    items[#items + 1] = { text = mode, active = value.mode == mode, callback = function()
                        self:Set({ key = self.Value.key, mode = mode })
                    end }
                end
                items[#items + 1] = { text = "clear key", callback = function()
                    self:Set({ key = "", mode = self.Value.mode })
                end }
                return Layer.menu(self.Hit, items, { width = 96 })
            end,
            Set = function(self, value, silent)
                if type(value) == "string" or typeof(value) == "EnumItem" then
                    value = { key = value, mode = self.Value and self.Value.mode }
                end
                return Element.Set(self, value, silent)
            end,
        },
    }
    Kinds.keybind.List = list
    Kinds.keybind.Changed = Aster._maid:Add(Util.Signal.new())
end

-- [src] 43_color.lua
do
    local LINE = Element.LINE
    local SW_W, SW_H = 18, 10
    local WIDTH, PAD, FIELD, SV_H, BAR_H = 208, 8, 192, 120, 10
    local PRESETS = { "#c9a96e", "#e8e4dc", "#8f9bf0", "#e8639a", "#6fd69a", "#4ec3e0", "#ef6a6a", "#f2d16b" }
    local owners = setmetatable({}, { __mode = "k" })

    local function tween(obj, props, kind)
        return Anim.to(obj, props, kind or 0)
    end

    local function clamp(value, min, max)
        return math.max(min, math.min(max, value))
    end

    local function alphaOf(value)
        if type(value) ~= "string" then return nil end
        local digits = string.match(string.lower(value), "^#?%x%x%x%x%x%x(%x%x)$")
        return digits and tonumber(digits, 16) / 255 or nil
    end

    local function validHex(value)
        if type(value) ~= "string" then return false end
        local text = string.lower(value)
        return string.match(text, "^#?%x%x%x%x%x%x$") ~= nil or string.match(text, "^#?%x%x%x%x%x%x%x%x$") ~= nil
    end

    local function toColor(value)
        if typeof(value) == "Color3" then return value end
        if validHex(value) then return Util.hex(value) end
        return nil
    end

    local function round2(value)
        return math.floor(clamp(value, 0, 1) * 100 + 0.5) / 100
    end

    local function full(color, alpha, opaque)
        local text = Util.toHex(color)
        if alpha < 1 and not opaque then text = text .. string.format("%02x", Util.snap(alpha * 255)) end
        return text
    end

    local function checker(parent, width, height, tile)
        local frame = Util.new("Frame", { Name = "Checker", Size = UDim2.fromOffset(width, height), Theme = { BackgroundColor3 = "black" }, Parent = parent })
        local row = 0
        for y = 0, height - 1, tile do
            local column = 0
            for x = 0, width - 1, tile do
                Util.new("Frame", {
                    Name = "Tile", Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(math.min(tile, width - x), math.min(tile, height - y)),
                    BackgroundTransparency = (row + column) % 2 == 0 and 0.6 or 0.4, Theme = { BackgroundColor3 = "white" }, Parent = frame,
                })
                column = column + 1
            end
            row = row + 1
        end
        return frame
    end

    local function knob(parent, width, height)
        local outer = Util.new("Frame", { Name = "Knob", BackgroundTransparency = 1, Size = UDim2.fromOffset(width, height), Parent = parent })
        Util.new("UIStroke", { Thickness = 1, Theme = { Color = "black" }, Parent = outer })
        local inner = Util.new("Frame", { Name = "Ring", BackgroundTransparency = 1, Position = UDim2.fromOffset(1, 1), Size = UDim2.fromOffset(width - 2, height - 2), Parent = outer })
        Util.new("UIStroke", { Thickness = 1, Theme = { Color = "white" }, Parent = inner })
        return outer
    end

    local function dragOn(maid, gui, fn)
        maid:Add(gui.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
            local mouse = Input.mouse()
            local ox, oy = mouse.X - input.Position.X, mouse.Y - input.Position.Y
            local function at(pos)
                local origin, size = gui.AbsolutePosition, gui.AbsoluteSize
                fn(clamp((pos.X - ox - origin.X) / math.max(1, size.X), 0, 1), clamp((pos.Y - oy - origin.Y) / math.max(1, size.Y), 0, 1))
            end
            at(mouse)
            maid:Add(Input.capture(at))
        end))
    end

    local function picker(el)
        local opaque = el.Opts.opaque == true
        local rowY = opaque and 154 or 172
        local presetY = rowY + 32
        local height = presetY + 12 + PAD
        local state = {}
        el._pick = state

        local function load()
            local h, s, v = Color3.toHSV(el.Value)
            if s == 0 or v == 0 then h = state.h or h end
            if v == 0 then s = state.s or s end
            state.h, state.s, state.v, state.a = h, s, v, el._alpha
        end
        load()

        local function commit()
            state.own = true
            el:_apply(Color3.fromHSV(math.min(state.h, 0.9999), state.s, state.v), state.a)
            state.own = false
        end

        return Layer.open(el.Hit, function(frame, handle)
            local maid = Util.Maid.new()
            state.maid = maid
            local sv = Util.new("TextButton", { Name = "SV", Position = UDim2.fromOffset(PAD, PAD), Size = UDim2.fromOffset(FIELD, SV_H), Parent = frame })
            local white = Util.new("Frame", { Name = "White", Size = UDim2.fromScale(1, 1), Theme = { BackgroundColor3 = "white" }, Parent = sv })
            Util.new("UIGradient", { Transparency = NumberSequence.new(0, 1), Parent = white })
            local black = Util.new("Frame", { Name = "Black", Size = UDim2.fromScale(1, 1), Theme = { BackgroundColor3 = "black" }, Parent = sv })
            Util.new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0), Parent = black })
            local svKnob = knob(sv, 10, 10)

            local hue = Util.new("TextButton", { Name = "Hue", Position = UDim2.fromOffset(PAD, 136), Size = UDim2.fromOffset(FIELD, BAR_H), Theme = { BackgroundColor3 = "white" }, Parent = frame })
            local stops = {}
            for index = 0, 6 do stops[#stops + 1] = ColorSequenceKeypoint.new(index / 6, Color3.fromHSV((index % 6) / 6, 1, 1)) end
            Util.new("UIGradient", { Color = ColorSequence.new(stops), Parent = hue })
            local hueKnob = knob(hue, 5, 14)

            local alpha, alphaFill, alphaKnob
            if not opaque then
                alpha = Util.new("TextButton", { Name = "Alpha", BackgroundTransparency = 1, Position = UDim2.fromOffset(PAD, 154), Size = UDim2.fromOffset(FIELD, BAR_H), Parent = frame })
                checker(alpha, FIELD, BAR_H, 5)
                alphaFill = Util.new("Frame", { Name = "Fill", Size = UDim2.fromScale(1, 1), Parent = alpha })
                Util.new("UIGradient", { Transparency = NumberSequence.new(1, 0), Parent = alphaFill })
                alphaKnob = knob(alpha, 5, 14)
            end

            local prev = Util.new("Frame", { Name = "Preview", Position = UDim2.fromOffset(PAD, rowY), Size = UDim2.fromOffset(32, 24), Theme = { BackgroundColor3 = "ln2" }, Parent = frame })
            local prevBox = checker(prev, 30, 22, 8)
            prevBox.Position = UDim2.fromOffset(1, 1)
            local prevFill = Util.new("Frame", { Name = "Fill", Position = UDim2.fromOffset(1, 1), Size = UDim2.fromOffset(30, 22), Parent = prev })

            local field = Util.new("Frame", { Name = "Field", Position = UDim2.fromOffset(PAD + 40, rowY), Size = UDim2.fromOffset(FIELD - 40, 24), Theme = { BackgroundColor3 = "black" }, Parent = frame })
            local fieldInner = Util.new("Frame", { Name = "Inner", Position = UDim2.fromOffset(1, 1), Size = UDim2.new(1, -2, 1, -2), Parent = field })
            Theme.fill(fieldInner, "well", "card")
            local box = Util.new("TextBox", {
                Name = "Hex", BackgroundTransparency = 1, TextStyle = "body", TextXAlignment = Enum.TextXAlignment.Left,
                Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -16, 1, 0), Theme = { TextColor3 = "tx" }, Parent = fieldInner,
            })
            el.HexBox = box

            local count = #PRESETS
            for index, color in ipairs(PRESETS) do
                local x0 = Util.snap((index - 1) * (FIELD + 4) / count)
                local x1 = Util.snap(index * (FIELD + 4) / count) - 4
                local button = Util.new("TextButton", {
                    Name = "Preset" .. index, Position = UDim2.fromOffset(PAD + x0, presetY), Size = UDim2.fromOffset(x1 - x0, 12),
                    Theme = { BackgroundColor3 = "ln2" }, Parent = frame,
                })
                Util.new("Frame", { Name = "Swatch", Position = UDim2.fromOffset(1, 1), Size = UDim2.new(1, -2, 1, -2), BackgroundColor3 = Util.hex(color), Parent = button })
                maid:Add(button.MouseButton1Click:Connect(function()
                    state.h, state.s, state.v = Color3.toHSV(Util.hex(color))
                    state.a = 1
                    commit()
                end))
            end

            function state.draw(typed)
                local color = Color3.fromHSV(math.min(state.h, 0.9999), state.s, state.v)
                sv.BackgroundColor3 = Color3.fromHSV(math.min(state.h, 0.9999), 1, 1)
                svKnob.Position = UDim2.fromOffset(Util.snap(state.s * FIELD) - 5, Util.snap((1 - state.v) * SV_H) - 5)
                hueKnob.Position = UDim2.fromOffset(Util.snap(state.h * FIELD) - 2, -2)
                if alpha then
                    alphaFill.BackgroundColor3 = color
                    alphaKnob.Position = UDim2.fromOffset(Util.snap(state.a * FIELD) - 2, -2)
                end
                prevFill.BackgroundColor3 = color
                prevFill.BackgroundTransparency = 1 - (opaque and 1 or state.a)
                if not typed then
                    state.typing = true
                    box.Text = full(color, state.a, opaque)
                    state.typing = false
                end
            end

            dragOn(maid, sv, function(x, y)
                state.s, state.v = x, 1 - y
                commit()
            end)
            dragOn(maid, hue, function(x)
                state.h = math.min(x, 0.9999)
                commit()
            end)
            if alpha then
                dragOn(maid, alpha, function(x)
                    state.a = round2(x)
                    commit()
                end)
            end
            maid:Add(box:GetPropertyChangedSignal("Text"):Connect(function()
                if state.typing then return end
                local text = string.gsub(box.Text, "^%s+", "")
                text = string.gsub(text, "%s+$", "")
                if not validHex(text) then return end
                state.h, state.s, state.v = Color3.toHSV(Util.hex(text))
                state.a = opaque and 1 or (alphaOf(text) or 1)
                state.typing = true
                state.own = true
                el:_apply(Color3.fromHSV(math.min(state.h, 0.9999), state.s, state.v), state.a)
                state.own = false
                state.draw(true)
                state.typing = false
            end))
            maid:Add(box.FocusLost:Connect(function() state.draw(false) end))

            state.draw(false)
            handle.Resize(height)
        end, {
            side = "right", width = WIDTH, height = height,
            onClose = function()
                if state.maid then state.maid:Clean() end
                if el._pick == state then el._pick = nil end
                el.HexBox = nil
                el:_paint()
            end,
        })
    end

    Kinds.color = {
        method = "Color", slot = SW_W,
        default = function() return Color3.new(1, 1, 1) end,
        validate = function(opts, value) return toColor(value) end,
        equal = function(a, b)
            return typeof(a) == "Color3" and typeof(b) == "Color3" and Util.toHex(a) == Util.toHex(b)
        end,
        encode = function(value, opts, el)
            el = el or owners[opts]
            return Util.toHex(value) .. string.format("%02x", Util.snap((el and el._alpha or 1) * 255))
        end,
        decode = function(value)
            if validHex(value) then return value end
            return nil
        end,
        build = function(el, slot)
            owners[el.Opts] = el
            local alpha = tonumber(el.Opts.alpha) or alphaOf(el.Opts.default) or 1
            el._alpha = el.Opts.opaque and 1 or round2(alpha)
            local y = (LINE - SW_H) / 2
            local ring = Util.new("Frame", { Name = "Ring", Position = UDim2.fromOffset(-1, y - 1), Size = UDim2.fromOffset(SW_W + 2, SW_H + 2), Theme = { BackgroundColor3 = "ln2" }, Parent = slot })
            el._glow = Util.new("Frame", { Name = "Glow", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Theme = { BackgroundColor3 = "accent" }, Parent = ring })
            local border = Util.new("Frame", { Name = "Border", BackgroundTransparency = 0.4, Position = UDim2.fromOffset(1, 1), Size = UDim2.fromOffset(SW_W, SW_H), Theme = { BackgroundColor3 = "black" }, Parent = ring })
            local well = checker(border, SW_W - 2, SW_H - 2, 6)
            well.Position = UDim2.fromOffset(1, 1)
            el.Swatch = Util.new("Frame", { Name = "Swatch", Position = UDim2.fromOffset(1, 1), Size = UDim2.fromOffset(SW_W - 2, SW_H - 2), Parent = border })
            el.Hit = Util.new("TextButton", { Name = "Hit", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, LINE), Parent = slot })
            el._maid:Add(el.Hit.MouseEnter:Connect(function()
                el._swHover = true
                el:_paint()
            end))
            el._maid:Add(el.Hit.MouseLeave:Connect(function()
                el._swHover = false
                el:_paint()
            end))
            el._maid:Add(el.Hit.MouseButton1Click:Connect(function()
                if el.Disabled then return end
                el:Open()
            end))
            el._maid:Add(function()
                if el._popup then el._popup.Close() end
            end)
        end,
        paint = function(el)
            local kind = el._painted and "fade" or nil
            el._painted = true
            el.Swatch.BackgroundColor3 = el.Value
            el.Swatch.BackgroundTransparency = 1 - el._alpha
            local open = el._pick ~= nil
            tween(el._glow, { BackgroundTransparency = ((el._swHover and not el.Disabled) or open) and 0 or 1 }, kind)
            local state = el._pick
            if state and state.draw and not state.own then
                local h, s, v = Color3.toHSV(el.Value)
                if s == 0 or v == 0 then h = state.h end
                if v == 0 then s = state.s end
                state.h, state.s, state.v, state.a = h, s, v, el._alpha
                state.draw(state.typing)
            elseif state and state.draw then
                state.draw(state.typing)
            end
        end,
        methods = {
            Alpha = function(self) return self._alpha end,
            Hex = function(self) return full(self.Value, self._alpha, self.Opts.opaque) end,
            SetAlpha = function(self, alpha, silent)
                return self:_apply(self.Value, alpha, silent)
            end,
            Open = function(self)
                if self._popup and not self._popup.Closed then
                    self._popup.Close()
                    return nil
                end
                self._popup = picker(self)
                self:_paint()
                return self._popup
            end,
            Close = function(self)
                if self._popup then self._popup.Close() end
            end,
            Set = function(self, value, silent)
                local color = toColor(value)
                if not color then return false end
                local alpha = alphaOf(value)
                return self:_apply(color, alpha or self._alpha, silent)
            end,
            _apply = function(self, color, alpha, silent)
                alpha = tonumber(alpha)
                if not alpha or alpha ~= alpha then return false end
                alpha = self.Opts.opaque and 1 or round2(alpha)
                if alpha ~= self._alpha then
                    self._alpha = alpha
                    self.Value = false
                end
                return Element.Set(self, color, silent)
            end,
        },
    }
end

-- [src] 44_basic.lua
do
    local LINE, PAD = Element.LINE, Element.PAD
    local BTN_H, BTN_GAP = 24, 8

    local function tween(obj, props, kind)
        return Anim.to(obj, props, kind or 0)
    end

    local function contentWidth(el)
        local width = el.Container.Width
        if not width or width <= 0 then
            local ok, size = pcall(function() return el.Row.AbsoluteSize.X end)
            width = ok and size or 0
        end
        return math.max(0, width - el.X - PAD)
    end

    local function button(el, item)
        local primary = item.primary == true
        local frame = Util.new("Frame", { Name = "Button", Parent = el.Row })
        local stroke = Util.new("UIStroke", { Thickness = 1, Parent = frame })
        local hover
        if primary then
            Theme.bind(frame, "BackgroundColor3", "accent")
            frame.BackgroundTransparency = 0.92
            Theme.bind(stroke, "Color", "accent")
            stroke.Transparency = 0.65
        else
            Theme.fill(frame, "btnBg", "btnBg2")
            Theme.bind(stroke, "Color", "btnBd")
            hover = Util.new("Frame", { Name = "Hover", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = frame })
            Theme.fill(hover, "btnHv", "btnHv2")
        end
        local hit = Util.new("TextButton", {
            Name = "Hit", BackgroundTransparency = 1, Text = tostring(item.name or item.text or ""), TextStyle = "body",
            TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.fromScale(1, 1), Parent = frame,
        })
        local entry = { Frame = frame, Hit = hit, Item = item, Hover = hover, Primary = primary, Over = false }
        local function paint(kind)
            local over = entry.Over and not el.Disabled
            if primary then
                Theme.bind(hit, "TextColor3", "accent")
                tween(frame, { BackgroundTransparency = over and 0.87 or 0.92 }, kind)
            else
                Theme.bind(hit, "TextColor3", over and "tx" or "btnTx")
                tween(hover, { BackgroundTransparency = over and 0 or 1 }, kind)
            end
        end
        entry.Paint = paint
        el._maid:Add(hit.MouseEnter:Connect(function()
            entry.Over = true
            paint("fade")
        end))
        el._maid:Add(hit.MouseLeave:Connect(function()
            entry.Over = false
            paint("fade")
        end))
        el._maid:Add(hit.MouseButton1Click:Connect(function()
            if el.Disabled then return end
            local fn = item.callback or item.fn
            if fn then Util.guard(fn, el) end
        end))
        paint(nil)
        return entry
    end

    local function layoutButtons(el)
        local list = el._buttons
        local count = #list
        if count == 0 then return end
        local width = contentWidth(el)
        for index, entry in ipairs(list) do
            local x0 = Util.snap((index - 1) * (width + BTN_GAP) / count)
            local x1 = Util.snap(index * (width + BTN_GAP) / count) - BTN_GAP
            entry.Frame.Position = UDim2.fromOffset(el.X + x0 + 1, 5)
            entry.Frame.Size = UDim2.fromOffset(math.max(0, x1 - x0 - 2), BTN_H - 2)
        end
    end

    local function buttonsKind(method, items)
        return {
            method = method, label = false, height = BTN_H + 8,
            build = function(el, row)
                el._buttons = {}
                for _, item in ipairs(items(el.Opts)) do el._buttons[#el._buttons + 1] = button(el, item) end
                el.Buttons = {}
                for index, entry in ipairs(el._buttons) do el.Buttons[index] = entry.Hit end
                el.Hit = el.Buttons[1]
                layoutButtons(el)
            end,
            paint = function(el)
                for _, entry in ipairs(el._buttons or {}) do entry.Paint("fade") end
            end,
            resize = function(el) layoutButtons(el) end,
            methods = {
                SetText = function(self, a, b)
                    local index, text = 1, a
                    if b ~= nil then index, text = a, b end
                    local entry = self._buttons[index]
                    if entry then entry.Hit.Text = tostring(text) end
                end,
            },
        }
    end

    Kinds.button = buttonsKind("Button", function(opts) return { opts } end)
    Kinds.buttons = buttonsKind("Buttons", function(opts) return opts.items or opts.buttons or opts end)

    Kinds.input = {
        method = "Input", default = "",
        height = function(el) return (el.Opts.name and LINE or 4) + BTN_H + 4 end,
        validate = function(opts, value)
            if type(value) == "number" then value = tostring(value) end
            if type(value) ~= "string" then return nil end
            local max = tonumber(opts.max)
            if max and #value > max then value = string.sub(value, 1, max) end
            return value
        end,
        build = function(el, row)
            local top = el.Opts.name and LINE or 4
            local field = Util.new("Frame", {
                Name = "Field", Position = UDim2.fromOffset(el.X, top), Size = UDim2.new(1, -(el.X + PAD), 0, BTN_H),
                Theme = { BackgroundColor3 = "black" }, Parent = row,
            })
            local inner = Util.new("Frame", { Name = "Inner", Position = UDim2.fromOffset(1, 1), Size = UDim2.new(1, -2, 1, -2), Parent = field })
            Theme.fill(inner, "well", "card")
            el._focus = Util.new("Frame", { Name = "Focus", BackgroundTransparency = 1, Position = UDim2.fromOffset(1, 1), Size = UDim2.new(1, -2, 1, -2), Parent = inner })
            el._focusStroke = Util.new("UIStroke", { Thickness = 1, Transparency = 1, Theme = { Color = "accent" }, Parent = el._focus })
            el.Box = Util.new("TextBox", {
                Name = "Box", BackgroundTransparency = 1, Text = el.Value, PlaceholderText = tostring(el.Opts.placeholder or el.Opts.ph or ""),
                TextStyle = "body", TextXAlignment = Enum.TextXAlignment.Left, ClipsDescendants = true,
                Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -16, 1, 0), Theme = { TextColor3 = "tx", PlaceholderColor3 = "tx4" }, Parent = inner,
            })
            el._maid:Add(el.Box:GetPropertyChangedSignal("Text"):Connect(function()
                if el._painting then return end
                if el.Disabled then
                    el:_paint()
                    return
                end
                el:Set(el.Box.Text)
                if el.Box.Text ~= el.Value then el:_paint() end
            end))
            el._maid:Add(el.Box.Focused:Connect(function()
                el._focused = true
                el:_paint()
            end))
            el._maid:Add(el.Box.FocusLost:Connect(function(enter)
                el._focused = false
                el:_paint()
                if enter and el.Opts.enter and not el.Disabled then Util.guard(el.Opts.enter, el.Value, el) end
            end))
        end,
        paint = function(el)
            local kind = el._painted and "fade" or nil
            el._painted = true
            if el.Box.Text ~= el.Value then
                el._painting = true
                el.Box.Text = el.Value
                el._painting = false
            end
            el.Box.TextEditable = not el.Disabled
            tween(el._focusStroke, { Transparency = el._focused and not el.Disabled and 0.5 or 1 }, kind)
        end,
        methods = {
            Focus = function(self) if not self.Disabled then self.Box:CaptureFocus() end end,
        },
    }

    Kinds.label = {
        method = "Label", label = false,
        build = function(el, row)
            el.TextLabel = Util.new("TextLabel", {
                Name = "Text", Text = tostring(el.Opts.text or el.Opts.name or ""), TextStyle = "body", TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(el.X, 0), Size = UDim2.new(1, -(el.X + PAD), 0, LINE),
                Theme = { TextColor3 = el.Opts.muted and "tx3" or "tx2" }, Parent = row,
            })
        end,
        methods = {
            SetText = function(self, text) self.TextLabel.Text = tostring(text) end,
        },
    }

    Kinds.stat = {
        method = "Stat", label = false, default = "",
        validate = function(opts, value)
            if value == nil then return nil end
            return tostring(value)
        end,
        build = function(el, row)
            el._name = Util.new("TextLabel", {
                Name = "Name", Text = tostring(el.Opts.name or ""), TextStyle = "body", TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(el.X, 0), Parent = row,
            })
            el._value = Util.new("TextLabel", { Name = "Value", TextStyle = "bold", TextXAlignment = Enum.TextXAlignment.Right, Parent = row })
            if el.Opts.click then
                el.Hit = Util.new("TextButton", { Name = "Hit", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, LINE), Parent = row })
                el._maid:Add(el.Hit.MouseEnter:Connect(function()
                    el._over = true
                    el:_paint()
                end))
                el._maid:Add(el.Hit.MouseLeave:Connect(function()
                    el._over = false
                    el:_paint()
                end))
                el._maid:Add(el.Hit.MouseButton1Click:Connect(function()
                    if not el.Disabled then Util.guard(el.Opts.click, el) end
                end))
            end
        end,
        paint = function(el)
            local width = Text.width(el.Value, "bold")
            local over = el._over and not el.Disabled
            el._value.Text = el.Value
            el._value.Position = UDim2.new(1, -(PAD + width), 0, 0)
            el._value.Size = UDim2.fromOffset(width, LINE)
            el._name.Size = UDim2.new(1, -(el.X + PAD + width + 8), 0, LINE)
            Theme.bind(el._name, "TextColor3", over and "accent" or "tx3")
            Theme.bind(el._value, "TextColor3", over and "accent" or "tx2")
        end,
    }

    Kinds.divider = {
        method = "Divider", label = false, index = false, height = 9,
        build = function(el, row)
            Util.new("Frame", { Name = "Line", Position = UDim2.fromOffset(el.X, 4), Size = UDim2.new(1, -(el.X + PAD), 0, 1), Theme = { BackgroundColor3 = "ln" }, Parent = row })
        end,
    }
end

-- [src] 50_dropdown.lua
do
    local LINE, PAD = Element.LINE, Element.PAD
    local FIELD_H, LIST_MAX, MIN_W = 20, 264, 150

    local function options(el)
        local src = el.Opts.options or el.Opts.values or el.Opts.items or {}
        if type(src) == "function" then
            local ok, list = pcall(src)
            src = ok and type(list) == "table" and list or {}
        end
        local out = {}
        for _, v in ipairs(src) do out[#out + 1] = tostring(v) end
        return out
    end

    local function has(list, value)
        for _, v in ipairs(list) do
            if v == value then return true end
        end
        return false
    end

    local function shown(el)
        if not el.Opts.multi then return tostring(el.Value), "" end
        local picked = {}
        for _, option in ipairs(options(el)) do
            if has(el.Value, option) then picked[#picked + 1] = option end
        end
        for _, v in ipairs(el.Value) do
            if not has(picked, v) then picked[#picked + 1] = v end
        end
        if #picked == 0 then return "none", "" end
        local room = el._valueW or 0
        local text = table.concat(picked, ", ")
        if room <= 0 or Text.width(text, "body") <= room then return text, "" end
        for k = #picked - 1, 1, -1 do
            local more = "+" .. (#picked - k)
            local part = table.concat(picked, ", ", 1, k)
            if Text.width(part, "body") <= room - Text.width(more, "bold") - 4 or k == 1 then return part, more end
        end
        return text, ""
    end

    local function layout(el)
        local top = el.Label and 24 or 4
        local width = math.max(0, el.Container.Width - el.X - PAD)
        el.Field.Position = UDim2.fromOffset(el.X, top)
        el.Field.Size = UDim2.fromOffset(width, FIELD_H)
        if el.Label then
            el.Label.Position = UDim2.fromOffset(el.X, 4)
            el.Label.Size = UDim2.new(1, -(el.X + PAD), 0, 16)
        end
        el._valueW = width - 8 - 8 - 7 - 4
    end

    local function paintField(el, kind)
        local open = el._handle ~= nil and not el._handle.Closed
        local over = el._over and not el.Disabled
        local text, more = shown(el)
        el.ValueLabel.Text = text
        el.More.Text = more
        local moreW = more ~= "" and Text.width(more, "bold") or 0
        el.More.Size = UDim2.fromOffset(moreW, FIELD_H - 2)
        el.More.Position = UDim2.new(1, -(8 + 7 + 4 + moreW), 0, 0)
        el.ValueLabel.Size = UDim2.new(1, -(8 + 8 + 7 + 4 + (moreW > 0 and moreW + 4 or 0)), 1, 0)
        Theme.bind(el.ValueLabel, "TextColor3", (open or over) and "tx" or "ddTx")
        Theme.bind(el._ringStroke, "Color", open and "ddHl" or "white")
        Anim.to(el._ringStroke, { Transparency = open and 0.5 or (over and 0.91 or 0.96) }, kind)
        el._chev.Paint(open and "ddHl" or "tx4")
        if el._chev.Open ~= open then el._chev.Set(open, kind and "move" or 0) end
    end

    local function openList(el)
        if el.Disabled then return end
        if el._handle and not el._handle.Closed then
            el._handle.Close()
            return
        end
        local list = options(el)
        local rowsH = math.max(1, #list) * LINE
        local natural = math.min(rowsH, LIST_MAX) + 8
        local fieldW = el.Field.AbsoluteSize.X
        local box = Layer.box()
        el._handle = Layer.open(el.Field, function(frame, handle)
            local below, above = Layer.room(el.Field, box)
            local room = math.max(below, above, 48)
            local height = math.min(natural, room)
            local scroll = Scroll.new(frame, { name = "List", position = UDim2.fromOffset(0, 4), size = UDim2.new(1, 0, 0, height - 8) })
            handle.Scroll = scroll
            handle.Options = {}
            local function sync()
                for _, entry in ipairs(handle.Options) do
                    local on
                    if el.Opts.multi then on = has(el.Value, entry.Value) else on = el.Value == entry.Value end
                    if entry.Selected ~= on then entry.Select(on) end
                end
            end
            handle.Sync = sync
            if #list == 0 then
                Util.new("TextLabel", {
                    Name = "None", Text = "no options", TextStyle = "body", TextXAlignment = Enum.TextXAlignment.Left,
                    Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -16, 0, LINE), Theme = { TextColor3 = "tx4" }, Parent = scroll.Content,
                })
            end
            for index, option in ipairs(list) do
                local entry = Layer.option(scroll.Content, { name = "Option", y = (index - 1) * LINE, text = option })
                entry.Value = option
                entry.Click:Connect(function(button)
                    if button ~= "m1" or el.Disabled or handle.Closed then return end
                    if el.Opts.multi then
                        local value = {}
                        local found = false
                        for _, v in ipairs(el.Value) do
                            if v == option then found = true else value[#value + 1] = v end
                        end
                        if not found then value[#value + 1] = option end
                        local ordered = {}
                        for _, o in ipairs(list) do
                            if has(value, o) then ordered[#ordered + 1] = o end
                        end
                        el:Set(ordered)
                        sync()
                    else
                        el:Set(option)
                        handle.Close()
                    end
                end)
                handle.Options[index] = entry
            end
            scroll:SetHeight(rowsH)
            sync()
            handle.Resize(height)
            local selected
            for index, option in ipairs(list) do
                if (el.Opts.multi and has(el.Value, option)) or el.Value == option then
                    selected = index
                    break
                end
            end
            if selected then scroll:Reveal((selected - 1) * LINE, selected * LINE) end
        end, {
            side = "field", box = box, width = Util.snap(math.max(fieldW, MIN_W)), bg = "ddlBg", stroke = "ddHl", strokeAlpha = 0.55,
            onClose = function(h)
                if h.Scroll then h.Scroll._maid:Clean() end
                if el._handle == h then el._handle = nil end
                if not el.Destroyed then paintField(el, "fade") end
            end,
        })
        if el._handle and el._handle.Closed then el._handle = nil end
        paintField(el, "fade")
    end

    Kinds.dropdown = {
        method = "Dropdown",
        height = function(el) return el.Label and 48 or 28 end,
        default = function(opts)
            if opts.multi then return {} end
            local src = opts.options or opts.values or opts.items or {}
            if type(src) == "function" then
                local ok, list = pcall(src)
                src = ok and type(list) == "table" and list or {}
            end
            return src[1] ~= nil and tostring(src[1]) or ""
        end,
        validate = function(opts, value)
            if opts.multi then
                if type(value) == "string" then value = { value } end
                if type(value) ~= "table" then return nil end
                local out, seen = {}, {}
                for _, v in ipairs(value) do
                    v = tostring(v)
                    if not seen[v] then
                        seen[v] = true
                        out[#out + 1] = v
                    end
                end
                return out
            end
            if value == nil or type(value) == "table" then return nil end
            value = tostring(value)
            local src = opts.options or opts.values or opts.items
            if type(src) == "table" and #src > 0 and not opts.free then
                for _, v in ipairs(src) do
                    if tostring(v) == value then return value end
                end
                return nil
            end
            return value
        end,
        equal = function(a, b)
            if type(a) ~= "table" or type(b) ~= "table" then return a == b end
            if #a ~= #b then return false end
            for i = 1, #a do
                if a[i] ~= b[i] then return false end
            end
            return true
        end,
        build = function(el, row)
            local field = Util.new("TextButton", { Name = "Field", Theme = { BackgroundColor3 = "ddBd" }, Parent = row })
            local inner = Util.new("Frame", { Name = "Inner", Position = UDim2.fromOffset(1, 1), Size = UDim2.new(1, -2, 1, -2), Parent = field })
            Theme.fill(inner, "ddBg", "ddBg2")
            local ring = Util.new("Frame", { Name = "Ring", BackgroundTransparency = 1, Position = UDim2.fromOffset(1, 1), Size = UDim2.new(1, -2, 1, -2), Parent = inner })
            el._ringStroke = Util.new("UIStroke", { Thickness = 1, Transparency = 0.96, Theme = { Color = "white" }, Parent = ring })
            el.ValueLabel = Util.new("TextLabel", {
                Name = "Value", TextStyle = "body", TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
                Position = UDim2.fromOffset(7, 0), Size = UDim2.new(1, -26, 1, 0), Parent = inner,
            })
            el.More = Util.new("TextLabel", { Name = "More", Text = "", TextStyle = "bold", Theme = { TextColor3 = "ddHl" }, Parent = inner })
            el._chev = Layer.chevron(inner, UDim2.new(1, -15, 0, 7), "tx4")
            el.Field = field
            layout(el)
            el._maid:Add(field.MouseEnter:Connect(function()
                el._over = true
                paintField(el, "fade")
            end))
            el._maid:Add(field.MouseLeave:Connect(function()
                el._over = false
                paintField(el, "fade")
            end))
            el._maid:Add(field.MouseButton1Click:Connect(function() openList(el) end))
        end,
        paint = function(el)
            if not el.Field then return end
            layout(el)
            if el._handle and not el._handle.Closed and el._handle.Sync then el._handle.Sync() end
            if el.Disabled and el._handle and not el._handle.Closed then el._handle.Close() end
            paintField(el, el._painted and "fade" or nil)
            el._painted = true
        end,
        resize = function(el)
            if el.Field then
                layout(el)
                paintField(el)
            end
        end,
        destroy = function(el)
            if el._handle and not el._handle.Closed then el._handle.Close() end
        end,
        methods = {
            Open = function(self)
                if not (self._handle and not self._handle.Closed) then openList(self) end
                return self._handle
            end,
            Close = function(self)
                if self._handle and not self._handle.Closed then self._handle.Close() end
            end,
            IsOpen = function(self)
                return self._handle ~= nil and not self._handle.Closed
            end,
            Has = function(self, option)
                if self.Opts.multi then return has(self.Value, tostring(option)) end
                return self.Value == tostring(option)
            end,
            Options = function(self)
                return options(self)
            end,
            SetOptions = function(self, list)
                self.Opts.options, self.Opts.values, self.Opts.items = list, nil, nil
                local current = self.Value
                if self.Opts.multi then
                    local keep = {}
                    for _, v in ipairs(current) do
                        if has(options(self), v) then keep[#keep + 1] = v end
                    end
                    if #keep ~= #current then self:Set(keep) else self:_paint() end
                elseif not has(options(self), current) and not self.Opts.free then
                    local first = options(self)[1]
                    if first ~= nil then self:Set(first) else self:_paint() end
                else
                    self:_paint()
                end
                if self._handle and not self._handle.Closed then
                    self._handle.Close()
                    openList(self)
                end
            end,
        },
    }
end

-- [src] 51_settings.lua
do
    local LINE = Element.LINE
    local HEAD, WIDTH, GEAR = 22, 216, 11

    local function gear(parent)
        local holder = Util.new("Frame", { Name = "Gear", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, Util.snap((LINE - GEAR) / 2)), Size = UDim2.fromOffset(GEAR, GEAR), Parent = parent })
        local parts = {}
        local image = Icons.get and Icons.get("gear")
        if image then
            parts[1] = Util.new("ImageLabel", { Name = "Icon", Image = image, Size = UDim2.fromScale(1, 1), Parent = holder })
            return holder, function(token) Theme.bind(parts[1], "ImageColor3", token) end
        end
        local ring = Util.new("Frame", { Name = "Ring", BackgroundTransparency = 1, Position = UDim2.fromOffset(3, 3), Size = UDim2.fromOffset(5, 5), Parent = holder })
        local stroke = Util.new("UIStroke", { Thickness = 1, Parent = ring })
        local teeth = { { 5, 0, 1, 2 }, { 5, 9, 1, 2 }, { 0, 5, 2, 1 }, { 9, 5, 2, 1 }, { 1, 1, 2, 2 }, { 8, 1, 2, 2 }, { 1, 8, 2, 2 }, { 8, 8, 2, 2 } }
        for _, t in ipairs(teeth) do
            parts[#parts + 1] = Util.new("Frame", { Name = "Tooth", Position = UDim2.fromOffset(t[1], t[2]), Size = UDim2.fromOffset(t[3], t[4]), Parent = holder })
        end
        return holder, function(token)
            Theme.bind(stroke, "Color", token)
            for _, p in ipairs(parts) do Theme.bind(p, "BackgroundColor3", token) end
        end
    end

    local function title(el)
        local opts = el.Opts
        if opts.title then return tostring(opts.title) end
        if el.Parent and el.Parent.Opts.name then return tostring(el.Parent.Opts.name) end
        return tostring(opts.name or "settings")
    end

    local function isOpen(el)
        return el._handle ~= nil and not el._handle.Closed
    end

    local function paint(el, kind)
        local hot = (el._over or isOpen(el)) and not el.Disabled
        el._paintGear(hot and "accent" or "tx4")
    end

    local function open(el)
        if el.Disabled or el.Destroyed then return nil end
        if isOpen(el) then return el._handle end
        local inner = el.Inner
        el._handle = Layer.open(el.Hit, function(frame, handle)
            Util.new("TextLabel", {
                Name = "Title", Text = Text.caps("small", el._title), TextStyle = "small", TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
                Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 10), Theme = { TextColor3 = "tx4" }, Parent = frame,
            })
            el._holder.Position = UDim2.fromOffset(0, HEAD)
            el._holder.Parent = frame
            inner:_show(true)
            inner:_layout()
            handle.Resize(HEAD + inner.Height)
            handle.Maid:Add(inner.Resized:Connect(function(h)
                if not handle.Closed then handle.Resize(HEAD + h) end
            end))
        end, {
            side = "right", width = el._width, box = Layer.box(),
            onClose = function(h)
                if not inner.Destroyed then inner:_show(false) end
                if el._holder and not el.Destroyed then el._holder.Parent = el._park end
                if el._handle == h then el._handle = nil end
                if not el.Destroyed then paint(el, "fade") end
            end,
        })
        if el._handle and el._handle.Closed then el._handle = nil end
        paint(el, "fade")
        return el._handle
    end

    Kinds.settings = {
        method = "Settings", slot = GEAR + 1, index = false,
        build = function(el, slot)
            local opts = el.Opts
            el._title = title(el)
            el._width = Util.snap(opts.width or WIDTH)
            local icon, paintGear = gear(slot)
            el._icon, el._paintGear = icon, paintGear
            el.Hit = Util.new("TextButton", { Name = "Hit", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = slot })
            el._park = Util.new("Frame", { Name = "Park", Visible = false, BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 0), Parent = slot })
            el._holder = Util.new("Frame", { Name = "Rows", BackgroundTransparency = 1, Size = UDim2.fromOffset(el._width, 0), Parent = el._park })
            local outer = el.Container
            local path = table.move(outer.Path, 1, #outer.Path, 1, {})
            path[#path + 1] = { kind = "gear", ref = el, name = el._title, id = "gear" }
            el.Inner = Container.new(el._holder, { width = el._width, path = path, bg = "card", padTop = 0, padBottom = 6, shown = false })
            el.Inner.Gear = el
            el._maid:Add(el.Hit.MouseEnter:Connect(function()
                el._over = true
                paint(el, "fade")
            end))
            el._maid:Add(el.Hit.MouseLeave:Connect(function()
                el._over = false
                paint(el, "fade")
            end))
            el._maid:Add(el.Hit.MouseButton1Click:Connect(function()
                if el.Disabled then return end
                if isOpen(el) then el._handle.Close() else open(el) end
            end))
            el._maid:Add(el.Shown:Connect(function(v)
                if not v and isOpen(el) then el._handle.Close() end
            end))
            return el.Inner
        end,
        paint = function(el)
            if not el._paintGear then return end
            if el.Disabled and isOpen(el) then el._handle.Close() end
            paint(el)
        end,
        destroy = function(el)
            if isOpen(el) then el._handle.Close() end
            if el.Inner then el.Inner:Destroy() end
        end,
        methods = {
            Open = function(self) return open(self) end,
            Close = function(self)
                if isOpen(self) then self._handle.Close() end
            end,
            Toggle = function(self)
                if isOpen(self) then self._handle.Close() else open(self) end
            end,
            IsOpen = function(self) return isOpen(self) end,
        },
    }
end

-- [src] 52_strip.lua
do
    local PAD = Element.PAD
    local ICON_DATA = {
        combat = { w = 14, h = 14, png = "iVBORw0KGgoAAAANSUhEUgAAABwAAAAcCAYAAAByDd+UAAACP0lEQVR4nN2VjW3TUBSFz50AdwLcCUgnoBskTIA9QcsEdSYAJkgyAWEC0gnqToA7QbOB+a5f/HASx8FFQqKfdHQU358Tv6c2phdQAyYDbBSjBxzyXmEgGQk2RamkQoFCUiXpO9lb/CyGBiEolfQZzdAQa/SJ4EoDDAYSlklaoJYnVEl6j5x7lEp6i1pyM1vqBIZ6IWyBZQo8ooxFJe61GhOfm3k+TrClpHfIWVLK8SMMHcGCTL/f7CvDt3iEeo2J53GeRwlWSLpBTm49bxoHWhhMJf1EzlGYQ0+N7QW2UPqCtaGXdnCnfQPfsBl6pHmCj4L5BNsoHO+aHR/wyF7grvkZOVc0l/ho2DPBHpBzwZ4t3nAYmCnc3ZOZpfoL2OUhb1Bunbs0FKGpkHSH7s3sWj3sem5QgnLrLOtC30bhz2duZoV2GIUaH4SB+MVof8Y8rIFSt3Z+Fz3nmwBroH2vn9LJWh+x2aG/0PkjzRTu2clt7JGiCE2ZwrKKpkv8xbCrPfrcOl/KUIQmb/BG54rGEh8NeybYA3Iu2LPFG/YCHZrX2BSVNF7ho2A+wX6gCVqZWaYOfYGp9A//tTkMZQp36fiCuXWOhXqNiWdxnkcJdodukZNb5+5a4sAhLFhK+oicEuW2u1NqNRYD+TjBFsjdWdnBUbY0A6dgUaawqGWLSnStwEYhJEEtufW8WctgoENoqnCsUzTEChWEVRrA0B9BcILNUKpwV84cVQo/Q1v8LIZGQ3iNiZDR86MHHPL+n8BfDuoLJAsTGIcAAAAASUVORK5CYII=", px = "6,0,2,2,4,2,6,1,3,3,2,1,6,3,2,1,9,3,2,1,2,4,2,1,10,4,2,1,2,5,1,1,11,5,1,1,0,6,4,2,6,6,2,2,10,6,4,2,2,8,1,1,11,8,1,1,2,9,2,1,10,9,2,1,3,10,2,1,6,10,2,1,9,10,2,1,4,11,6,1,6,12,2,2" },
        players = { w = 14, h = 14, png = "iVBORw0KGgoAAAANSUhEUgAAABwAAAAcCAYAAAByDd+UAAACwklEQVR4nO2U23GbUBRF96kguILgCoQqCFQQp4KgCixXYLkCyxWYVBClgqAKjCswriCkAmVdXcAgQBr96CtrZs9mzhMEuqYL83+hdrvdLRZLClCFcjN7wluoCQXES51gciFDIuwZOT+kQAszc+5qM0nfUS7promPMbqQAQH2gkJJW7RBBQolpZK+oFLSnOEV9Wuub5GjQgsz2+ADDA3oDPhhZqkOIL/BvqIn8kvcxSIskzRDJfFrfIChATS/YaH8ExR4D/KxpN+oN5h4KOkNORIzy3WAoQE07jDRMJp3UDJaQ9jdoHvKhZllOqBX3EDTfhhc0VThPUiHqp+EfG8GORcPJX0jtcF7GBpAUy7/YSxs5C7Jp/Jf8NbMYtUQD1XfCMzJFXiPqYWx6nckvzRXTZ37iQKUWJ0jfoM9owBtrXMjXUYXOhiwxm6Ro5RXhALkeGLoEne1ufwv4viLYnIFPmByoYNBN1gm6RNqcANTBm7wPdStsVT+/7oiV2qCowsbGBhhAaoYVuA9yAfEKy5PcnKhG4bNUCj/s76eGu56pmoMjULTPbZEATqkQmuGPuA96EslPaLRvKEeNMTyX1uoD16RWxKgGWoo0B2Dc9XQn8kf5A6XT6zztIZaKI6wF+R4R0uKN3gP6m6wNfqMHHPqCnxPnc/kP7acXILvMdRC4QsWoV8opbDCR6E2wDL5Q7ygdo63kI+wXH7pwuoDpF1IwUrSPXpHEQUVfhR6AqyUH/pgZit1IL+Sn5mTS/Dewjcs1MQZOAV9qfw7L+m7xlvIhfo46q6N/6dx4RIB9geJ4D52DvTvMMcV7RXeQqrAZigxPq79cIKx/Nn5SjDCz4L+Uv4DSoyh6kAulz/2EiPXLFxij2hrE4fuMejP5Yfe0b/GWzq5B+MdNwtjceDKv4dMZ0J/KimU/zhydTjMGRcX5eIL/wGKZjwsQgV1IwAAAABJRU5ErkJggg==", px = "3,2,4,1,9,2,1,1,2,3,2,2,7,3,1,2,3,5,1,1,6,5,2,1,10,3,1,3,3,6,4,1,8,6,2,1,2,8,6,1,10,8,2,1,1,9,2,1,7,9,2,1,11,9,2,1,8,10,2,2,1,10,1,3,9,12,1,1,12,10,1,3" },
        visuals = { w = 14, h = 14, png = "iVBORw0KGgoAAAANSUhEUgAAABwAAAAcCAYAAAByDd+UAAACZUlEQVR4nO2U4VHiYBCG363gchUYKzBXgVjBhQoMFUAHhx1gBYYKiBVcqMBYwcUOYgXcs34hEoigM46/fGYeX4bdZZOPiOmL+V746bx74WazSYjfGCvo1Arem1lFnsTwKCy6JuaSYh3HFy5YvCTfxHAQFsWS7nCkV+7RP9h1kla/8y2lpImZ1RpgcCHLRpJWGOEzLlw+pCEPoD8iZq0/sMEx/aX2OFjIcKZwZ84jpgzWegfMxpIKvEBnYma5dugtZCAlVugszSzTDm19iiMFSkm39BVkB325pGt0xrv1biFNCfEXI1za4bI7ItMwOf0TsoP+XGFpg1fWPsWGXoyIB4wlrc1spB2op8QKnRvMFcgk/UGndycOcxVxgbWkX9Qb44UXFsQUnzDxAtlBvZR0iTdmNtcO1OYKS9d2eKERUeEZ3hizxpuxpH/ojHmzIHvQsyGcc9t7gCjFauepGdGDekqs0Dn/6MKf1Buyg1Ksdp7a6YX88TcXxBRrtWdNdlAvFY50YnuPObW5jh/pA8baHikvtoUKz7CkcEV2UE+JFTY4w3uM8BrnCoyZK8gO5h6IBJ/w5dkwXrxA0Qulwi9FTnFCdlDPFRYMsbS3/42ecUS9ImXYQVNKrNDJaZqQHW19hpforHFBX0F20HdHZAr07tywB82ZXn/aKvSBWu+A2VjhghN0Jrb3nR8sdBj0gVLheBtc4C3DDXkA/RExxRlG2DvGXQYXOnxILI5Vr8fnFFi1OklrilvWmLGs1gCGR2FxpnDlF3iMR/TvM9cRTi7cwuKESDFW0KkVLFhUkScx/FK+F346/wGf+A9m24VFswAAAABJRU5ErkJggg==", px = "5,2,4,1,3,3,3,1,8,3,3,1,2,4,2,1,6,4,2,1,10,4,2,1,1,5,2,1,5,5,4,1,11,5,2,1,0,6,2,2,4,6,2,2,8,6,2,2,12,6,2,2,1,8,2,1,5,8,4,1,11,8,2,1,2,9,2,1,6,9,2,1,10,9,2,1,3,10,2,1,9,10,2,1,4,11,6,1" },
        misc = { w = 14, h = 14, png = "iVBORw0KGgoAAAANSUhEUgAAABwAAAAcCAYAAAByDd+UAAAA/ElEQVR4nO2Ui23CQBQE93WQVJCUkBLsTighqSDnCqAEOoESKAEqgA6O4SeMeQc+85OAkVYrnawd6WTbdGfewiQxxh+qT1zMrKSOMNIJhIWkEXFB6G67h22oCWdkqD3/5LyQgaDtw5ks2P6k17ATqSaVmQXB44S5sFtoc6VTHV5pECBwt93DNtSELvjcbfewDQhXn8WAuOAr5NBZ2JW38Oq8sJDXPvmNwR+v/YTO5pQwUilKMxurA22EFdnRk/RFSrtUyH6Q8/NmuP7MnPoguVTW/HkzFnRPYRPGI7UiaE9P0reucaVN8O2EHqXdQDhWml+EEzqbpPBWPL9wCftPYh0ve9AbAAAAAElFTkSuQmCC", px = "7,2,4,1,1,3,8,1,10,3,3,1,7,4,4,1,3,9,4,1,1,10,3,1,5,10,8,1,3,11,4,1" },
        gear = { w = 14, h = 14, png = "iVBORw0KGgoAAAANSUhEUgAAABwAAAAcCAYAAAByDd+UAAACs0lEQVR4nN2U4XHaQBCF304KiNyBKzAiDXCqwKSBWG4gdiqI0wFOAxGpACpANGCLVEAHlgvIkG85wIAECZ78Sd7MN0+3t3sP30g2vUKLxaKHycym2EkyOFkELjAPPHn+5AEXef9wIGflkm4gM7Mab4ieo4FsJ9gE7mkptKXGAM0V1gH3zFah1K+wICld4apWlPQNce9LsAmkMKPuvpHBjlYDpV5Cr+Aego6rVLyZIaQwg0BgjW9k0NBe6E94A89QSBpBBa4U+pBLegvr3hk0wlytgS5CL7AH8AOmkHPAXC2i91zxx/TAQ9/R+wNvyKBVHDLBgggzs6CVqPewoKiSvSm+FHulYqjXM7whg4YYzCV9g2dIGZ5TS3j2Wh+2NYJr4/roOVe8br/ea9t7Q12HAgutXhaGbnGvTbCgqDHU0Ac/fETfe9z7BtgNDM0s154OBT5iKWRmVrIOiq+664xajYt6ipWKoZnt9lasu/iObKuhTcvD6bmT9BnGrPv4RuwVirfxxczuWCc8P0Gbsr8ROMIu4RN7A9YJz0/QpuzQlVZYBzLbvSbXGbUaF/UEewJXl3pFLSj2zlin+I4OBRaK13TP0C3utRF2CS5/dvXBNaZv+UzfALuBoZ3w0uSKn0ANXQbn1BKeC72ErjWGnJ6annNJj+C91/ann4WL4VItHzH1oJfPY8RehS/F3gQL2vtnsS2DVjF8gT3AGygVf/FcLaL3XPFGgl7zr40DEmwCKfgBHlpDIf4qmIGrA33IFa9x3VtBZlwzvqNG4F6YH/wBvkIPjmkKH+E7+A+pILO9UIMdEfiIpeBhYT1APRdrxb0OuLyngpK+Qoi+BCsVeyrqXXyjtsBc0i0Emmu8IXoWmNhvzLvYTrBS0oCWQltqHfidOPBo4DGdPOAi7/8PDELklTpRvwBfV1OmYXcDnwAAAABJRU5ErkJggg==", px = "2,2,1,1,6,0,2,3,10,2,2,1,3,3,8,1,3,4,2,1,9,4,2,1,3,5,1,1,5,5,4,1,10,5,1,1,0,6,4,2,5,6,1,2,8,6,1,2,10,6,4,2,3,8,1,1,5,8,4,1,10,8,1,1,3,9,2,1,9,9,2,1,3,10,8,1,2,11,1,1,11,11,1,1,6,11,2,3" },
        theme = { w = 14, h = 14, png = "iVBORw0KGgoAAAANSUhEUgAAABwAAAAcCAYAAAByDd+UAAACXUlEQVR4nL2Ui3HaQBRF76vASgVWKgiuIKIDUkFEBZAKIioIVBBSAXRgUQGkAi8VRK6AnM3GZEEfJGfGZ+bORdp9e/cnTG/MqwJPp9Mck5ktsUEMDiRshO2R54HQA96bQYGEJZgPSxVwCqEV3gtDvSFwg03QEXnu0ZrAKd4LQ70gLJf0HXkekGePPFMzW6sHvQIJSxUGT9DCzAoB7wtJX1GF/NY63aBv4COWSdqZWaYI2kpJH1FJ2xjvxFAnDDjBNugZjRjUKYL2VNIT8nyifYu30hnIYAm2R6mirbyGfoXC1jqFra3wRgy1Eg10NLNUHdDXKdzahbVMzGOoEQZIsF/IMzazUh3QP5P0iDzv6F/hNboCC4XV7ezqorRBTalwgRbWssquwCcs1YBvjJpc4Vt11LzHaxiqERUezSzVAKh1Cmc5tYaJGqpB0RKboRVFc7w3t2rbAkuFs5hawyy7oDZX2J2dNZx9W6BT2JaxcTt5ziV9Rj/sxgTomync1qOZpbrCUA2KSkUr5LlQuLGN2xRD31yvWGGhKIDnCb83qPX2vUDfJTZDC2v4NAzVoChXmKUTf1XI4yTdoVJSIWDAHXaGugTbo1Qt/6uGavwtPKB7tKLQrzKTtEV36A+8v6inzxKboZ8oo7nCL7goiKF4hO2RZ07xinepwup82wfenetpm2FL5Hmg6YDXOBc0wSCFwll6Sklfrgeizwj7hjIFFtZwdi90BnoYcIKtFW0llApk+sczygnb4q3cDPQQmmBrhYA42OODSoWwCu+kV2AM4anCGXoOhDgNYHDg//Iboe0BLOm2khoAAAAASUVORK5CYII=", px = "6,1,2,1,5,2,4,1,5,3,1,1,8,3,1,1,4,4,2,1,8,4,2,1,3,5,2,1,9,5,2,1,3,6,1,2,10,6,1,2,2,8,2,1,10,8,2,1,5,9,1,1,3,9,1,2,5,10,2,1,10,9,1,2,3,11,2,1,9,11,2,1,5,12,4,1" },
        search = { w = 14, h = 14, png = "iVBORw0KGgoAAAANSUhEUgAAABwAAAAcCAYAAAByDd+UAAACBElEQVR4nO2V323aUByFz2+CegNgAm4mKAxQiUxQeK8UbxBH6ntggpIJClLf60yAswGZIGYC+t3arbBz/Qcp5Cmf9OlE4Z57EjkQ0zvzMfiX4/HoiAH6HErKSp/MLCd7Y9hIOfQDfTYRM7oie9E4yNgNkUiK8IBZaY6udICeVNLCzPbqIDjIWEzco2eLcy7LyQqcmxFrSZ9wL+kqdO6UV4Nc4ojfGOHCzNZqgfP+XCppjCvOx2QjocEd4XBLeUZ2QscRvue5prchg1QGT4oHHFLMyV7QXRI3+GBmczVQH5wRP/HRzCY6A7oTFY8io3tFBqkPJpJucUUpJntDNyJeUHQr955SeYHSWtJXvDOzRGdC/0h4RtbwFqkPxsQ9binMyN7QdcQOD3QjMkh9cKLiOewpjcje0J2r+FR6tJbnb/gfSv4ne0HPNcUN2Qu6O8LhnbU8jsqgh2Ki4g8nx5H1eGucdJ7RtXUMX8EFqaTPmOHCzHwG4ewtkajgC2d/kY00DQ5VfFwN0LPEDT5xYc7rjq/HGKPDf2Q4Nc6QQYKDHi6NiETFp0cbz/gNv+MYM5xaw6hhKwzPCK9Df6HngBmm4rf3l3Mu4utUxZkMp8b3yQqdg3W4eMhFewXgtYhI1TJ69mAXXaNvPuhpG73IoKc2+mDlv6yLDXrK0SXGDObkZQdDvPvgHypH1h3/azltAAAAAElFTkSuQmCC", px = "3,2,6,1,2,3,2,1,8,3,2,1,9,4,1,1,9,5,2,2,2,4,1,4,9,7,1,1,2,8,2,1,8,8,2,1,3,9,7,1,5,10,2,1,10,10,1,1,11,11,1,1,12,12,1,1" },
        save = { w = 14, h = 14, png = "iVBORw0KGgoAAAANSUhEUgAAABwAAAAcCAYAAAByDd+UAAABYUlEQVR4nO2WwU3DMBiF37sjceUYCe50g6aTUDYIE+BsUDZoJ8HeoAOAlCNXJO7huU4iA26UNiUH6Cd9cmP9r0+KIsvExPyzwrquV1puZcuFvJEf8kWmuGp8a9ySfNCa5HuhBTCXY1mr9F7rDyg7okInLYAMwJ2sAGxkirnMEeadLOSlTJZSdkSFJUmj5xzAs3QkcyTQjAHwKEuGzEy/LfaUUnZo2GJkIYT24tIn7Rdad/xKoSfad4yyQwsr6PUgTY5gSWXQoKzBiMIhlFQGDcoaHFGYAVhiGFYZiwZlDQ4txAj0XwbnQg1ZRIV6zhBOmkPYkKyUNTiiMMfwr7RlQX08yhqMKHyXW9nHTPqTZcETFDpGoRSatQjZBc+FLRqyCKGSExdaBDOEo63C/sO7ZYkwv0aYzxF0HFB4Shx7CldaZrLFX6Kupb9Evco+/Jyf93N+vsVfqgqtO74UTsHfL/wErCc6LP6vouAAAAAASUVORK5CYII=", px = "4,1,1,1,8,1,1,1,2,2,9,1,10,3,2,1,4,3,1,2,8,3,1,2,4,5,5,1,4,8,6,1,2,3,1,8,4,9,1,2,9,9,1,2,11,4,1,7,2,11,10,1,4,12,1,1,9,12,1,1" },
        friend = { w = 14, h = 14, png = "iVBORw0KGgoAAAANSUhEUgAAABwAAAAcCAYAAAByDd+UAAACTElEQVR4nO2V7XHaUBBF71YQuYLIFURUkEcFcSqIXAFQgU0FERVEqSCkgogKLCpAriBKBeQ8noUtJD4zw6+cmcOd0b7dNVgC05X5v1Dr9XpEOEkR1liY2Yy8iL0LWZQQ39DnLiXem5nPs+hdyLKIeMJY0gLnWGIsKZX0EStJA5bW5MkYdmBhRozwu5ml2oH6nPiEM+pjcgs1J+kXilpnfueCh6YVESu8g5JsQd0pDK2o35Jb3tREzYgWnQsemtZEb0MDR3rPcNnp0oVwQ09NtqAcS1phZyg1pwsWFgo3xr2Z5dqBeqpwBy8wl/QFGyJM0FOozcR46cBAp/BXVgpLC73wUvuBEQ7RSXrAUxgaL70wOCNG6KkUTDBCz4w/ZMw5p7C0IdbrO57iW3LjZS8MuyNySe+w4Q+mLJuTHehxCp+OONOZ37nQB0MSIsKaGSW5F846/ctCBkTEB4wVPtYlc2qyF847XbKQxgdijBHuUmPGvCnZgr6EyNAvdNrBsAUNTuGWj/XKEmuM0L/bhhInDC50IoZbWJYQT+h5xjHD5mQLzt0RGb5Hz4BzJXkUwy0M8ssS/IkpQ2qyF85GRK7wJV5ydkAeZbuQAY8KD/AzJgyoyYPQExGVwmMzNbNHHcFwA80rIpb0mcY5eRL0pQr/84q+W/Ighr4pIn6jaNpcOwf614Tnhvaa3MtmOOedwrOzpCEhz4L+SuEGGtqRO7ZZOCa+4sJ6np1j0F8o/LpM6M/IvTQLncIXcEVDrjOhP5UUi58j+gsdwPCqXH3hX1pc7qRYkOUyAAAAAElFTkSuQmCC", px = "3,2,4,1,2,3,2,2,7,3,1,2,10,3,2,2,3,5,1,1,6,5,8,1,3,6,4,1,10,6,2,2,2,8,6,1,1,9,2,1,7,9,2,1,8,10,2,2,1,10,1,3,9,12,1,1" },
        target = { w = 14, h = 14, png = "iVBORw0KGgoAAAANSUhEUgAAABwAAAAcCAYAAAByDd+UAAACDElEQVR4nN2V0XGbQBRF7+uADkQqiFKBUQd2BVEqkFKBUQVBFUSpwO4gUIFJBUEd0AE5q8VIEBaJzMQfPjPHd8Ty9s4iSzL9A03T3BEys4KYheFsKGwIVzh7fvaAg753WEhHLOkjLjGVJ5VU4i+6K93A1UKKIuIRtzhFhjszq8kgk4WUJZK+YyxPgSVu0LHHJd6ho5L0xcxyBTAcpS37iY4jrl83Yq0hxGsj3OtE0kHSAh0ra+8dchoYwgYR8YKxpB+4ZYOaPMF6Q3SFDi5FRIafsZL0ieWa7NENXMJwRmzwiMvhIOu5gOuJLuB6RJS4wD3rW7KHYQ+GYkm/0bGywKMJwXyi81vxwQb/vWOF98QTFjY4wa2wRy7/j/TAHs9kx1hhKv8x2HPzlpwNe2TEBndmluoCYzHR+RGEKOzKadknlz/VFKu3L+RPDwZT/c9Hij24+Z54wsKunCoEe+Typ31gj2eyY6wwlt7wY+FgKCM2WGnkG4P104ZcXxEdXI+IF4wVeEsM/6IdLHGBB0lfGa7JE6w3hCvs5rkUEd9wrcA3lMNwFDZIdH40lS5+BVhriK6Ql4n6vyora+8dYhik3eggf1JHLn/yLToyXGIizxHXoTKH4SSURkQq/55O4X4bU8pqMsjVwlcojuVP43xExw5LJ0WVbsBwNpQ3hCiZPT97wEHf+y9MBPTlmskfkID2lx/3H6sAAAAASUVORK5CYII=", px = "6,0,2,2,5,2,4,1,3,3,8,1,3,4,1,1,6,4,2,1,10,4,1,1,2,5,2,1,10,5,2,1,0,6,5,2,9,6,5,2,2,8,2,1,10,8,2,1,3,9,1,1,6,9,2,1,10,9,1,1,3,10,8,1,5,11,4,1,6,12,2,2" },
        ignore = { w = 14, h = 14, png = "iVBORw0KGgoAAAANSUhEUgAAABwAAAAcCAYAAAByDd+UAAACR0lEQVR4nO2VwXHaUBRF76sg34usLSqwvMgumZAKIBVEqiBOBcYVxKkAqCC4AuFJdlkYVxBYZ2E6IOfxERYgBGy8yOTMnLm2eP9fS5+RTS/M/8I1i8UiEB1MFHWmit6Z2Zw8iGEjFCWSvmIXmxjhF4qnaqCxkLJMUh9LZjiVNFakLSmRdI4luZkNtAfDWijrE5kij5ix0YTcgdmUGEi6QOcns+/IHWoL2SDT8519Y/EV2Qhrzolf+Bqd3GrudKeQhYmk3+gcWxaIAlP8g2Vpy7bOtK7wO9HFR4ZTshHmA1GW+aPv4B1e4Ig9PpJrNgpXi5/QuWR4Qu5lNV8ta7NmznX//QGdM79GLtkuzBTPbmZmiRpgNhAFprguI5fwuf/8CnOrnKXhGoZ6kq7x3sza2gNzgSgwxZ0yh5mxpPd4Y2Y9rdguHEj6hDdWGarCTCAKTLG2zGGup/jHD80s04qTCvk8EAWmuLfMYbanIwp7ikP3tvVI+SwQBabYWOYwP9YRjzRT/NJMGWqRS7geiAJTPFjmsOaJCJhbw5fGB3zQuWRwsrp2allKPKBzVp3fKHQYHhEdnOAHPLUsEOWaoVXOzzHcgAWJnl9t5WvqqDKH9bfEZ3RadujV5rAoUzxLx0vfsHBG7oU1gbjGK3Ryq5xdiWEtbPCDeIvOBHPjTMkdmE2JPno6Q9t6lCV7Cx02yhQ3KpnjBMeKtBVLApbkVnNnJY2FDqWJpFvsYBND7FE2VQOGR0FxILqYKOpMFfV/Q3PyIIYvyr9f+BfSaQUsM2o+IAAAAABJRU5ErkJggg==", px = "4,2,6,1,3,3,2,1,9,3,2,1,2,4,2,1,9,4,3,1,8,5,1,1,7,6,1,1,6,7,1,1,2,5,1,4,5,8,1,1,11,5,1,4,2,9,3,1,10,9,2,1,3,10,2,1,9,10,2,1,4,11,6,1" },
        pistols = { w = 29, h = 16, png = "iVBORw0KGgoAAAANSUhEUgAAADsAAAAgCAYAAACsNADrAAAB2UlEQVR4nO2Xj03bQBhHf98ENRt4hGxQZ4N0giYTNBvUtwGdoDABZYLaE2AmIEwQMwG8kx1AwX8OCRuT5ElPn+SLo3txclJMR8Qp9lA5xXbxCAxPbmaJJgRb69xbayz3LSX9xH0SVZRY4JRIVFFigSWuzMzP5tg69C8eAgXOjeC22EzSdzwUroldHEtsbvyGT7Gn2K9NbkcS+4AJsUVb7FLSOX7DMbjECw3DhtCNwLARgmNVGxjjCTszSzUwrbE7iF4zUg37lJ1NIdZDcKawJ+ys3jT3JJL+46WZLbUH6+eMX5gbh4dGIDR2y4iwD2dvY53V117D+g1jhs4a1oegN5ZNxZLuMARn9ca5L1EVOzezTK9gzUf6WM/c9taHIiR2wbjCEJy9xEaMGRZcK5nPsOY/hETSPc7214fCsBM2lkr6jSE4q2Ob4L1iVf+mElX84PX/mKMQEpsp7HDybFTZRKzKHX8IXTNHw7ATYreMCD+KW1wTmmlkOmMJjRV+OO3IMdVbSgIL5qdh2AqxC8YVvoeVmV1ogvTFpgo/nHacEVsyJ0dfbKbww8lzTeiCOUn6YreMCENZ2US/wp7WWEJjvf9wOiO2ZE6SrtiIMcNQPv207aM19hA5qtgnNLjDIdmxhDUAAAAASUVORK5CYII=", px = "6,2,1,1,25,2,1,1,3,3,25,4,4,7,13,1,15,8,1,1,11,8,1,2,14,9,2,1,4,8,6,3,13,10,2,1,4,11,10,1,4,12,6,1,3,13,7,1,3,14,6,1" },
        smgs = { w = 32, h = 16, png = "iVBORw0KGgoAAAANSUhEUgAAAEAAAAAgCAYAAACinX6EAAABgElEQVR4nO2YgW3CMBBF7yYoI7QTkA2wJ+goTTfoBmSEdpLaG4QNGKFMkD4LRYIoJgmkVRT7SU8fgXzYX0SJUEmcXAAmTS4Ak2a2ApqmKYg9xjioakkuirsL4MAbYostBVYYo8YS/wwK9sQkFMNhKuLyMO8Mq8korDEi8o1L4igiH+z9ixyFYjiME5EdtlhVdXID1hhZXgFT8KpqcgG8CIdxcl1ACnjNBay3AKsDl3BLLgD7CrA6MIA1BVFhl8s5MWo8YR9PWOAPHjCwxQ12qfGEXUr2Hz4b5O4CYjCrIYawGpnPciPnu4tXrlEB3nNyvb8Wq5E5Y8kFYN8XWL1zMLMaYgirkfksN/LfBcwJm22IIUqssY8CK/S64gLG4HWlBXgcQ83hSjLMdLKWAtjw5O9kpJNcQC5gh12sJlJARbxhlxdVPcoDTN5MDDZZEHs0chsnI/5xuoTZz3K+Nb5iIDz+fjKjJB9izgKMnB9gxmD1wZ/uXOQCMGlyAZg0yRfwC/Ne5SEqhqBWAAAAAElFTkSuQmCC", px = "7,3,19,1,1,4,2,1,7,4,24,1,1,5,30,1,1,6,26,1,1,7,2,2,10,7,5,2,18,7,1,2,10,9,9,1,21,7,3,5,10,10,4,3,21,12,2,1,9,13,6,1" },
        rifles = { w = 43, h = 16, png = "iVBORw0KGgoAAAANSUhEUgAAAFUAAAAgCAYAAABjGjQoAAACXUlEQVR4nO2YwXHaUBRF76sgeJddcAUhFQRW2ZIKolSAXUGgA6ggogLDMquIDkQFUXbZoVRAzh8NiSMkbEDfFuN/Zs7chc2b96+FhDEFGieU6oFQqgdCqR4IpXoglOqBUKoHQqkeuIhSt9ttIuk93mdiZmO1EGPhIfkJU9yR6B9rls/JZ4MdE+2XmqmwKeZmFqsGdohU9HTL76VkLa7UDdnBx5Cp0JFjio5IUleXzcQOXPn0NJb0BQdmlugArtQtGQilnk1fxxOp8AZTdPRwijtWZtZ/qaX6YmWh1MZZ2QsudYA+yCk1baLUJS6cDMzJvzB6SNxhHROreDjwOrfTL3yNZVbG1aAWc2qptUXeh9FjFU/MOiZWX+o3/IBlcl5zRbaWY0pd4sLJoXLyQRidaP9Du2ONb3Fi9aXOcIRVXJtZppbyUKlLXDg5RE4eBaM3RAfLzHCEsQrLJKJw7Kv6jzJjnxuylbhSM0lvcMcSF04Wz8mTYG5X0g+s4iPGkl5hHa7URNJ3LJOz2xXZSlypHbKHjpRlc/JsmDsk7rCKa3R0VU/GLhlzYhX/c5e55edTsnUYeoEyxqp+SP00s64eCXO6Uu0V/45ZKdkqDL1AGYmq74dzM4t0BMyKJH3FMq7QgTX07moKn6VuiA6W+WwHvmKrg3lTYoRlUhxYi4r1UioFdOXhLcvcWNX3VzdvYC0p1lepfVU/tX9z8A55MsyOtV/sGvvMzslnx1epPSLR/x+Z3MEjDp6SZ8H8SMVXbm7+3I68R/vGS6lPAcX2iB6FxmoZF1tqmwmleiCU6oE/2RfzIYfgquAAAAAASUVORK5CYII=", px = "21,4,3,1,0,5,34,1,38,5,1,1,0,6,42,2,0,8,8,1,0,9,5,1,12,8,4,2,19,8,4,2,0,10,2,1,16,10,3,1,20,10,3,1,11,10,4,2,21,11,3,1,22,12,3,1,11,12,3,2,23,13,2,1" },
        snipers = { w = 51, h = 16, png = "iVBORw0KGgoAAAANSUhEUgAAAGUAAAAgCAYAAAAL6bYQAAACX0lEQVR4nO2YMY7TUBRF7+uQKBhqGhf04x1gV7SzA7IDMisgWQHZAZ4VUFPhrGDMCsgUSJRBAokunDiJ+HHsJJ5xJn+Sf6SjFzn2s/+7shzHFPCOEIqHnGwos9ksprzAOr6Z2ZTqJUcJhYGNKJfocmNmmTqA/j1Jn7CJ1MxyecqxQsklvcFjkVoIZZ0QynZCKB7iUyg3mEnqSXqHLtdYYB09be7/Bd9iE6n5Hoo7JC623HZION+IEqNLxqkzvhtI+oAuqTUMsWl/vMIY6+jTr6B6ieF8YbkeMZRtcC0D1QzZWoZiDfs/BcoAWFiuZSiQ6PC8xt/4E6v0tNCljwXW0dNClz4W2IT/7ymVUM6BAqe4i3l4fepBYO6R1p+Hd2aWnWsovjI2s2TfULb9+nGJ8SMG7sfYWoSS2o4HJz0iSbd4gafCLyzwUFzgJa4YW1ehcPy8+VeM8ZQYG0PSI9NVKJ8pV9iGiaQf+Bz/4CuM1MxEPAixC57We0oD8wVMsY4LjHEX11jgiomkSIs7LMVEm+8bLkMzG+gMMNwnlC5IrXK3cd5EIZQNDOfDyfWwUO7wOyba5C8+w9RCKHthOB9OrmUoLLzc1hZ6DFQ/1ImkSPy3pcVnl0iLt/EUE9Ufv2JoIZR2uD0qTCRF2k6KiUIoJYZrA2Xh5ba2uD0qDG2PYXJ8T4u7pomMPpnOgDIABpJrOVAWXm5ri9ujwtD2CCXwn3sFUMeWUFKrPOAD2+kylFtKjFVSC6G0ostQZpQ6XhLKlBrYky5DGVHe4xoE0tk5zoUwMA8JoXhICMVDQige8g8QPPkh0Y8mOAAAAABJRU5ErkJggg==", px = "27,1,4,1,15,2,16,2,1,4,1,1,18,4,3,1,24,4,3,1,1,5,30,1,1,6,49,1,9,7,27,1,49,7,1,1,1,7,4,2,8,8,14,1,1,9,12,1,16,9,6,1,9,10,13,1,1,10,1,2,9,11,3,3" },
        shotguns = { w = 41, h = 16, png = "iVBORw0KGgoAAAANSUhEUgAAAFMAAAAgCAYAAABuBERvAAABrElEQVR4nO2Wy03DUBAAd88gQQeECkgH2J1QAnQSOoBKeO7A6SAcuRlxRmbWGClKnkNsFimQHWm0jp6/E0eKSuBGxHQkYjoSMR2JmI5ETEcipiMR05EuZtu2c8YZrrNU1YYZ7MlXzCQi15jDgtZo2Gx6azSOOjrtFowrvNsn5r40WKNh8xxvxJcH+fSQWOAcS8+Yx07EdCRiZrjDGsdSR8xtSlVNMoGIuU2pBxjzDd/xHBtc4ib2l8LIrW1yiif4gsYZzvEnVLjJLTFr5mgUfytmqXzDnLtlu1LVQjZgKQnk1r6DYwsRecLJcN3u+b3oTsaNJRkX8xmNC8xRaR+Ic7eMSvvP67CUBHJr+8DxDcPe0ClUOvG6QyjaTSUZjmk/wRpXIpKEbW6i4ZgntgvJUypvpQD7tYxdVDrxoTj1TERmMo3uOZhuKNpNLRhzNOreFRdLkoH9Cxn+iT2q6o30sG+S3dhD3TL/PF3MsRDIQhaS51JVV3KEjI5JyEKG38p7Qv6Lt2wKU2JayEK2ecUZMRvmUTI6ZjBMxHQkYjoSMR2JmI5ETEcipiMR05EPUcyhEickClMAAAAASUVORK5CYII=", px = "1,4,4,1,1,5,40,2,1,7,33,1,12,8,1,1,15,8,1,1,23,8,8,1,1,8,10,2,12,9,4,1,24,9,7,1,7,10,3,1,6,11,4,1" },
        heavy = { w = 44, h = 16, png = "iVBORw0KGgoAAAANSUhEUgAAAFgAAAAgCAYAAACW5L+YAAAClklEQVR4nO2X4W3aQBhAv0/qz0phhGwQd4LaE3SErkA3CBPABmWEdoKeJ4jZADYwUn9Wct9hLKjxmQu9a4Hck54+Bfnu7BeUgEoiKilwZFLgyKTAkbmLwE3TGBH5iL4UqmrkH5ACR+beAhc6Es73upBEC8zDZIw5BoUwBeMPOMuIRzjf60KieHywfYDda5fCXrt9wAZeYGhyOcWek2GhI+G4NyPtcxY6cl1IdjGPDg4RuGH8D35ihb/QxXt8h/ba/nUrHn3KDMouJk2M7APvqbHCDiMH7Os1WjaqupYj2Kth3CKlquZyITz2hPGEHVv2q1yBL6HGCnO5TWqs8FImmGFHqfzCxgJvsUIfMnzAxIFSzwQulQvEA8f6t06p9PvrwKy1796vaOctU6rH87rYd1hgR8V+U+/AXDNhPGHW816osUIXK3pMma9iLPBaRJbSRrQ+yjDd32oj7Rr7m7M/231zEfmBLmaq+iw9WNcw7B4Z+lDo/nMtS+3aGJR69IbzRdHelJHTwENscC1tzMrKoWtxwL5TxhxdzDR84FziUHNGxXwVivamjJwG3qDd0GqEyQE10xv2XYrIZ+xj3/UPaKS1z7NwHmboQ6H7wNeGog1h5BC40EA3y74vjKFI3/ETjlFhhj4UGuieQ3MSmBvdvRYC9m0YQ3zhmAXTCUtzGf/7fUyhVx44Y0zQBjYSAPbMxR3oA+dUTCdn1vcpNNB9h2YXOAYEmjLmeAIxzp7L+lxSYDcEWsrwP7hSPT7usD6XFNgNgV4YGfaZ6cBHsz6szyUFdkOghjFEoR4xWD5hGGm/PY6xwpw9a+bVESUwcXIZfvdt8fFaY8QgVuCMYaT9MtGxwSlxvzHfDIqJiKTAkUmBI5MCR+Y3MdIqMO0hhtwAAAAASUVORK5CYII=", px = "25,2,6,1,25,3,1,1,1,4,1,1,10,4,16,1,30,3,1,2,1,5,32,1,41,5,2,1,9,6,34,1,1,6,2,2,7,7,26,1,1,8,7,1,12,8,4,1,18,8,7,1,26,8,11,1,1,9,2,1,12,9,13,1,1,10,1,1,11,10,4,1,19,10,6,3,11,11,3,3" },
        shoot = { w = 21, h = 16, png = "iVBORw0KGgoAAAANSUhEUgAAACsAAAAgCAYAAACLmoEDAAABL0lEQVR4nO2U3U3DMBRG790oGxBGYAPYgA1CJiBs4G4QJkjZoGzQEcIE5twIlz+lcRXZbSUf6ejrQxyf9qEqV0SJTUWJTUWJTUWJTUV0rPe+Yp7R2Kiqk8woETfsLES9MRZbi8iAa2ixwcAOnYi8cs9eFrBYz87CS5RJFfuTEL5R1ZH9h8Vu5QgcrAV4rpa0sQEL7fCFu0f2gGIUGWMDFvqgqj07oRjFGWID9gs/st+xETE7rHANLTZ4KncE98qHiauKXSLiy8TQYoOn0Krqk4BiFGeI/cB7Qnt2wv66BnYWHr5lcsZaZGdy98gesFjPzsIBZXLEvqMT5MpfkQGLreUIHNwKfD034Br+xobAnnv2soBiFMRWTIeG4+VOMhMdewmU2FSU2FSU2FSU2FR8Ap2ReiF+vS5PAAAAAElFTkSuQmCC", px = "0,5,4,1,5,5,12,1,5,6,14,1,2,7,18,2,5,9,14,1,0,10,4,1,5,10,12,1" },
        hit = { w = 16, h = 16, png = "iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAByklEQVR4nO2W23HbMBRE91YQlOBUEHQQsQOnA6kDp5K4A6mDuAPCHSgVxCUwFSjnjoDEEkkR5CR+zOjM7Kw/gMX5kG2ZXpmrwNsUOBwOgfpOvprZnl4MW5H6Rr6w1dEn9AS4EKiWRNKRxhZKsBUp3wpkTxo7kxgSSJI+k4JfaGymBDuRakkghUczW+kZQwKRSpI+kEJHGquUyBvnj/8iq/ONnoCTB5IWSOS7VY87gwJOHkqaIZHvVD/ujAo4eTCpL/HRzj5MnA3UT+JduPi4c1HAYThSSX8lNma20wCcXUvaEmfycWdSwGE4UknSHYM7XYCza0n3ZPJxp0rAYTgw2PHjJHPOVgv8L64C70eAD9YNH6wnVTDnbJUAg5FqyQPDG3oUzm6pW9LYv/g1ZDBSLQnE2TG8oXtwdkutdaQjjU1IGBmFwUi1JJCC/4WLDD/pGZy90fF/fvmL6XSksQsSowIMRmro8dXYYL6TNENiUCAPzXq8kO8mVUr0BPLAoscLeSOpQmJIIOn0K9msxwvsRCrpVOLRKr6SBSpJ+kQWPV5gK1JJR4kfxLc6+g89AYeLgXogd1zY04thK1L35Jatjj5hUOAluQq8usBvLx/cIVMZ7QIAAAAASUVORK5CYII=", px = "3,2,1,1,12,2,1,1,2,3,3,1,11,3,3,1,3,4,3,1,10,4,3,1,4,5,2,1,10,5,2,1,5,9,1,1,10,9,1,1,4,10,3,1,9,10,3,1,3,11,3,1,10,11,3,1,2,12,3,1,11,12,3,1,3,13,1,1,12,13,1,1" },
        kill = { w = 15, h = 16, png = "iVBORw0KGgoAAAANSUhEUgAAAB0AAAAgCAYAAADud3N8AAABp0lEQVR4nO2V4W3aUBRGv28DOkGdDegEtSdIuwHdoBtgb9ANmm6QTFAzQdmg7gZs4B5jP/JsjImIUSIlRzq6P7jywXoPYb0Arzda1/UtI5W0xEStgUqtWyxtPzAnMZ6E2JrxHRf4VHb4g3jBHMV4BLEl4yc281K2+JV4pQFHUYILxh9M9HwqSZ8I75gHjD2I/makmo/mnDPmAeMBgqmkJjo3me1SHcPoPeMW5+aX7ZU6htG/jETzUxG9Ye4x7iGYSGqi1+LG3U2Oo6muc56BzN25notm7hYD7OWS1hgobOeKYCfVxLPeZjTR8UXK3C0G2Mt1WfQDezvmY7SB5XtG/DvNPE/0gZ0vzD3DaKr+8hZ3GJOoNVCpNWaBSwxkjr68sQfhldp/mHMUuMZzfLN9pwjjEYRTSXeSPuIYG9spe6WkzzjGP1yxV2qAcRQemOv0m2TmYeyk6h9HTOHBWQcuiW7MW6qDvVLjb1t4xuhTKfwexVGIJpISXU5FtNIIxkmI14zABnP1b2yGuaLLRMyMk0x+2ECzZgQ2mOs92kHTjJNMfngtXiT6H09E4SGm6PAfAAAAAElFTkSuQmCC", px = "4,1,7,1,3,2,9,1,2,3,11,2,1,5,13,1,1,6,3,1,11,6,3,1,2,7,2,2,6,6,3,3,11,7,2,2,3,9,9,1,3,10,4,1,8,10,4,1,3,11,9,1,4,12,7,1,4,13,2,2,7,13,1,2,9,13,2,2" },
        atmosphere = { w = 20, h = 16, png = "iVBORw0KGgoAAAANSUhEUgAAACgAAAAgCAYAAABgrToAAAAB8UlEQVR4nO2WjVHbQBhE90sDuAS5gtgVRKoAdxC7ApMKoIMoDYRzB04FERVEqQCV4FTgvENgGNDPyZIMzPBmdtay5uaepTvJpo7s9/sZdUb+mtmOHpVjBDNJX0hiZplG5n0KIrEUIOD0DM5lahDk/CX1g3OD3P4XgkwQS/pNPCurkKyDsdfUUlLOuDndmxeCHiZykr4Sz9TMCrXAmCtJl8Szsg4/rIlKQQ8TOknZw0Qcx5LWZEE8haQt8bez4PyEz5mklGOngagVfAqTX1NLVbMjKzPb0oPTKohcSvkr18YcyZwelEZB5CJJtyQEvxwSelCM1ILgBfWdhDI11qMG5E4QkUzls81zY2axgO+dHndzCIlVPBv78D4E60Cw6y3+ST6RQuXu3ljPN0qbYKTwTVKHk/TtWNFGQQ+SKbUmfchJYkdItgp6kHTqthar2JjZUh0JEvQgGUu6IOfkWPwfiM8kkjQjOdmRjdVcXSPBIDmhzonTsOyIX6dOzwgSRCxSuZsXZEzmSOb0gVbBe7k/ZELG5heCC/pAiKBT/w0SSo6gX6cHQgRvqUinY45kTt9hpBEE99SpKVRumm2IYKbH9/SpmYYIptSavAZJiOCEylQ+YE/JPzJrFXwA0StJsRhEzsiY3JDUQtbga/Mh2Jc3L/gfoW+/mPHuzeoAAAAASUVORK5CYII=", px = "6,0,1,2,2,2,2,1,9,2,2,1,5,3,3,1,4,4,5,1,1,5,1,2,4,5,6,2,4,7,9,1,5,8,8,1,6,9,11,1,4,10,14,2,4,12,16,1,5,13,14,1" },
    }

    Icons.Assets = Icons.Assets or {}
    Icons.Data = ICON_DATA
    Icons.Folder = "aster2/icons"
    Icons.broken = false
    Icons._made = {}
    Icons._rects = {}
    Icons.Changed = Util.Signal.new()
    Aster._maid:Add(Icons.Changed)

    local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local DEC = {}
    for i = 1, 64 do DEC[string.byte(B64, i)] = i - 1 end

    function Icons.decode(text)
        local out = {}
        local bits, count = 0, 0
        for i = 1, #text do
            local v = DEC[string.byte(text, i)]
            if v then
                bits = bits * 64 + v
                count = count + 1
                if count == 4 then
                    out[#out + 1] = string.char(math.floor(bits / 65536), math.floor(bits / 256) % 256, bits % 256)
                    bits, count = 0, 0
                end
            end
        end
        if count == 3 then
            bits = bits * 64
            out[#out + 1] = string.char(math.floor(bits / 65536), math.floor(bits / 256) % 256)
        elseif count == 2 then
            bits = bits * 4096
            out[#out + 1] = string.char(math.floor(bits / 65536))
        end
        return table.concat(out)
    end

    local function folder(path)
        local built = ""
        for piece in string.gmatch(path, "[^/]+") do
            built = built == "" and piece or built .. "/" .. piece
            if not (Exec.fs.isfolder and Exec.fs.isfolder(built)) then Exec.fs.makefolder(built) end
        end
    end

    local function asset(name)
        local made = Icons._made[name]
        if made ~= nil then return made or nil end
        Icons._made[name] = false
        local data = ICON_DATA[name]
        if not (data and Exec.customasset and Exec.hasFs) or Icons.broken then return nil end
        local file = Icons.Folder .. "/" .. name .. "-" .. #data.png .. ".png"
        local ok, id = pcall(function()
            if not Exec.fs.isfile(file) then
                folder(Icons.Folder)
                Exec.fs.write(file, Icons.decode(data.png))
            end
            return Exec.customasset(file)
        end)
        if ok and type(id) == "string" and id ~= "" then
            Icons._made[name] = id
            return id
        end
        return nil
    end

    function Icons.get(name)
        if type(name) ~= "string" or name == "" then return nil end
        if string.match(name, "^rbxasset") or string.match(name, "^rbxthumb") or string.match(name, "^http") then return name end
        return Icons.Assets[name] or asset(name)
    end

    function Icons.bitmap(name)
        local data = type(name) == "string" and ICON_DATA[name]
        if not data then return nil end
        local rects = Icons._rects[name]
        if not rects then
            local nums = {}
            for n in string.gmatch(data.px, "%d+") do nums[#nums + 1] = tonumber(n) end
            rects = {}
            for i = 1, #nums - 3, 4 do rects[#rects + 1] = { nums[i], nums[i + 1], nums[i + 2], nums[i + 3] } end
            Icons._rects[name] = rects
        end
        return { w = data.w, h = data.h, rects = rects }
    end

    function Icons.has(name)
        return Icons.get(name) ~= nil or Icons.bitmap(name) ~= nil
    end

    function Icons.aspect(name)
        local data = type(name) == "string" and ICON_DATA[name]
        if not data then return 1 end
        return data.w / data.h
    end

    function Icons.draw(parent, name, props)
        local map = Icons.bitmap(name)
        if not map then return nil end
        local box = Util.new("Frame", { Name = "Icon", BackgroundTransparency = 1, Size = UDim2.fromOffset(map.w, map.h), Parent = parent })
        for k, v in pairs(props or {}) do box[k] = v end
        for _, r in ipairs(map.rects) do
            Util.new("Frame", {
                Name = "Px", BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1),
                Position = UDim2.fromScale(r[1] / map.w, r[2] / map.h), Size = UDim2.fromScale(r[3] / map.w, r[4] / map.h), Parent = box,
            })
        end
        box:SetAttribute("bitmap", name)
        return box
    end

    function Icons.make(parent, name, props)
        local image = Icons.get(name)
        if image then
            local icon = Util.new("ImageLabel", { Name = "Icon", Image = image, BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, Parent = parent })
            for k, v in pairs(props or {}) do icon[k] = v end
            return icon
        end
        return Icons.draw(parent, name, props)
    end

    function Icons.tint(icon, token, transparency, kind)
        if not icon then return end
        if icon:IsA("ImageLabel") then
            Theme.bind(icon, "ImageColor3", token)
            if transparency then Anim.to(icon, { ImageTransparency = transparency }, kind or 0) end
            return
        end
        for _, px in ipairs(icon:GetChildren()) do
            Theme.bind(px, "BackgroundColor3", token)
            if transparency then px.BackgroundTransparency = transparency end
        end
    end

    function Icons.watch(icon, owner)
        if not (icon and icon:IsA("ImageLabel")) or Icons.broken then return end
        local name
        for k, id in pairs(Icons._made) do
            if id and id == icon.Image then name = k end
        end
        if not name then return end
        local function onScreen()
            if owner and owner.IsShown and not owner:IsShown() then return false end
            local ok, seen = pcall(function()
                if not icon.Visible then return false end
                local pos, size = icon.AbsolutePosition, icon.AbsoluteSize
                local view = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
                if size.X <= 0 or size.Y <= 0 then return false end
                return not view or (pos.X + size.X > 0 and pos.Y + size.Y > 0 and pos.X < view.X and pos.Y < view.Y)
            end)
            return not ok or seen
        end
        local function check(seen)
            Anim.after(4, function()
                if Icons.broken or not icon.Parent or icon.Image ~= Icons._made[name] then return end
                local now = onScreen()
                if not (seen and now) then return check(now) end
                local ok, loaded = pcall(function() return icon.IsLoaded end)
                if ok and loaded == false then
                    Icons.broken = true
                    Icons._made = {}
                    Icons.Changed:Fire(Icons.shown())
                end
            end)
        end
        check(onScreen())
    end

    function Icons.register(name, asset)
        if type(name) == "table" then
            for k, v in pairs(name) do Icons.Assets[k] = v end
        else
            Icons.Assets[name] = asset
        end
        Icons.Changed:Fire(Icons.shown())
    end

    function Icons.shown()
        return Store.get("icons", true, Store.fix and Store.fix.bool) ~= false
    end

    function Icons.SetShown(on)
        on = on ~= false
        if Icons.shown() == on then return end
        Store.put("icons", on)
        Icons.Changed:Fire(on)
    end

    local function items(opts)
        local out = {}
        for _, item in ipairs(opts.items or opts.options or opts.values or {}) do
            if type(item) == "table" then
                local key = item.k or item.key or item.value or item[1]
                out[#out + 1] = { key = tostring(key), label = tostring(item.label or item.text or item.name or key), icon = item.icon }
            else
                out[#out + 1] = { key = tostring(item), label = tostring(item) }
            end
        end
        return out
    end

    local function geometry(el)
        local top = el.Container.Bg == "bg"
        local inset = top and 0 or PAD
        local pad = top and 0 or 4
        local width = math.max(0, el.Container.Width - 2 * inset)
        return inset, pad, width
    end

    local function cellHeight(el)
        return el.Opts.small and 24 or 40
    end

    local function paintCell(el, cell, kind)
        local act = cell.Item.key == el.Value
        local over = cell.Over and not el.Disabled
        local token = act and "accent" or (over and "tx2" or "tx3")
        Theme.bind(cell.Label, "TextColor3", token)
        Anim.to(cell.Tint, { BackgroundTransparency = act and 0.94 or 1 }, kind)
        Anim.to(cell.Hit, { BackgroundTransparency = (over and not act) and 0.985 or 1 }, kind)
        Icons.tint(cell.Icon, token, (act or over) and 0 or 0.25, kind)
    end

    local function slide(el, kind)
        local cell
        for _, c in ipairs(el._cells) do
            if c.Item.key == el.Value then cell = c end
        end
        if not cell then
            el._seg.Visible = false
            return
        end
        el._seg.Visible = true
        local goal = { Position = UDim2.fromOffset(cell.X, cellHeight(el) - 1), Size = UDim2.fromOffset(cell.W, 2) }
        Anim.to(el._seg, goal, el._placed and kind or 0)
        el._placed = true
    end

    local function layout(el)
        local inset, pad, width = geometry(el)
        local h = cellHeight(el)
        el._box.Position = UDim2.fromOffset(inset, pad)
        el._box.Size = UDim2.fromOffset(width, h + 2)
        local inner = width - 2
        local n = #el._cells
        for i, cell in ipairs(el._cells) do
            local x0 = Util.snap((i - 1) * inner / n)
            local x1 = Util.snap(i * inner / n)
            cell.X, cell.W = x0, x1 - x0
            cell.Hit.Position = UDim2.fromOffset(x0, 0)
            cell.Hit.Size = UDim2.fromOffset(x1 - x0, h)
            cell.Line.Visible = i < n
        end
        slide(el, 0)
    end

    local function build(el)
        for _, cell in ipairs(el._cells or {}) do cell.Hit:Destroy() end
        el._cells = {}
        local list = items(el.Opts)
        local show = Icons.shown()
        local anyIcon = false
        for _, item in ipairs(list) do
            if show and Icons.has(item.icon) then anyIcon = true end
        end
        el.TextOnly = not anyIcon
        local h = cellHeight(el)
        for _, item in ipairs(list) do
            local hit = Util.new("TextButton", { Name = "Cell", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, Parent = el._inner })
            local tint = Util.new("Frame", { Name = "Tint", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Theme = { BackgroundColor3 = "accent" }, Parent = hit })
            local line = Util.new("Frame", { Name = "Line", Position = UDim2.new(1, -1, 0, 0), Size = UDim2.new(0, 1, 1, 0), Theme = { BackgroundColor3 = "ln" }, Parent = hit })
            local label
            local icon
            if anyIcon and not el.Opts.small then
                local top = Util.snap((h - 30) / 2)
                if Icons.get(item.icon) then
                    icon = Icons.make(hit, item.icon, { Position = UDim2.new(0, 4, 0, top), Size = UDim2.new(1, -8, 0, 16) })
                elseif Icons.bitmap(item.icon) then
                    local w = Util.snap(16 * Icons.aspect(item.icon))
                    icon = Icons.draw(hit, item.icon, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, top), Size = UDim2.fromOffset(w, 16) })
                end
                label = Util.new("TextLabel", {
                    Name = "Label", Text = Text.caps("small", item.label), TextStyle = "small", TextTruncate = Enum.TextTruncate.AtEnd,
                    Position = UDim2.new(0, 2, 0, top + 20), Size = UDim2.new(1, -4, 0, 10), Parent = hit,
                })
            else
                local iw = 0
                if el.Opts.small and show and Icons.has(item.icon) then
                    iw = math.max(14, Util.snap(14 * Icons.aspect(item.icon)))
                    icon = Icons.make(hit, item.icon, { Position = UDim2.fromOffset(6, Util.snap((h - 14) / 2)), Size = UDim2.fromOffset(iw, 14) })
                end
                label = Util.new("TextLabel", {
                    Name = "Label", Text = item.label, TextStyle = "body", TextTruncate = Enum.TextTruncate.AtEnd,
                    Position = UDim2.fromOffset(icon and iw + 8 or 4, 0), Size = UDim2.new(1, icon and -(iw + 12) or -8, 1, 0), Parent = hit,
                })
            end
            local cell = { Item = item, Hit = hit, Tint = tint, Line = line, Label = label, Icon = icon, Over = false, X = 0, W = 0 }
            hit.MouseEnter:Connect(function()
                cell.Over = true
                paintCell(el, cell, "fade")
            end)
            hit.MouseLeave:Connect(function()
                cell.Over = false
                paintCell(el, cell, "fade")
            end)
            hit.MouseButton1Click:Connect(function()
                if el.Disabled then return end
                el:Set(item.key)
            end)
            el._cells[#el._cells + 1] = cell
            paintCell(el, cell, 0)
            Icons.watch(icon, el)
        end
        layout(el)
    end

    Kinds.strip = {
        method = "Strip", label = false,
        height = function(el)
            local _, pad = geometry(el)
            return cellHeight(el) + 2 + 2 * pad
        end,
        default = function(opts)
            local list = items(opts)
            return list[1] and list[1].key or ""
        end,
        validate = function(opts, value)
            if value == nil then return nil end
            value = tostring(value)
            for _, item in ipairs(items(opts)) do
                if item.key == value then return value end
            end
            return nil
        end,
        build = function(el, row)
            el._box = Util.new("Frame", { Name = "Strip", BackgroundColor3 = Color3.new(0, 0, 0), Parent = row })
            el._inner = Util.new("Frame", { Name = "Inner", Position = UDim2.fromOffset(1, 1), Size = UDim2.new(1, -2, 1, -2), Parent = el._box })
            Theme.fill(el._inner, "panel", "panel2")
            el._seg = Util.new("Frame", { Name = "Seg", ZIndex = 5, Size = UDim2.fromOffset(0, 2), Theme = { BackgroundColor3 = "accent" }, Parent = el._inner })
            build(el)
            el._maid:Add(Icons.Changed:Connect(function()
                if not el.Destroyed then build(el) end
            end))
        end,
        paint = function(el)
            if not el._cells then return end
            for _, cell in ipairs(el._cells) do paintCell(el, cell, "fade") end
            slide(el, "move")
        end,
        resize = function(el)
            if el._cells then layout(el) end
        end,
        methods = {
            SetItems = function(self, list)
                self.Opts.items, self.Opts.options, self.Opts.values = list, nil, nil
                build(self)
                local keys = items(self.Opts)
                local found = false
                for _, item in ipairs(keys) do
                    if item.key == self.Value then found = true end
                end
                if not found and keys[1] then self:Set(keys[1].key) else self:_paint() end
            end,
            Items = function(self) return items(self.Opts) end,
        },
    }
end

-- [src] 53_list.lua
do
    local LINE, PAD = Element.LINE, Element.PAD
    local DOUBLE = 0.35
    local DOT = " \194\183 "

    local function clock()
        local ok, t = pcall(tick)
        if ok and type(t) == "number" then return t end
        return os.clock()
    end

    local function notify(src, text, kind)
        if Aster.Notify then Util.guard(Aster.Notify, Aster, src, text, kind) end
    end

    local function two(n)
        return string.format("%02d", tonumber(n) or 0)
    end

    local function savedAt(epoch)
        if type(epoch) ~= "number" then return "" end
        local ok, t = pcall(os.date, "*t", epoch)
        if not ok or type(t) ~= "table" then return "" end
        return "saved " .. two(t.hour) .. ":" .. two(t.min) .. DOT .. two(t.day) .. "/" .. two(t.month)
    end

    local function normal(src)
        if type(src) == "function" then
            local ok, list = pcall(src)
            src = ok and type(list) == "table" and list or {}
        end
        local out = {}
        for _, item in ipairs(src or {}) do
            if type(item) == "table" then
                local key = item.key or item.name or item.text or item[1]
                out[#out + 1] = { key = tostring(key), text = tostring(item.text or item.name or key), meta = item.meta, marker = item.marker, data = item }
            else
                out[#out + 1] = { key = tostring(item), text = tostring(item) }
            end
        end
        return out
    end

    local function view(el, row, spec)
        local v = { Rows = {}, Items = {}, Selected = spec.selected, Spec = spec, MaxRows = spec.rows or 7 }
        local box = Util.new("Frame", { Name = "List", BackgroundColor3 = Color3.new(0, 0, 0), Parent = row })
        local well = Util.new("Frame", { Name = "Well", Position = UDim2.fromOffset(1, 1), Size = UDim2.new(1, -2, 1, -2), Theme = { BackgroundColor3 = "well" }, Parent = box })
        local scroll = Scroll.new(well, { name = "Rows" })
        el._maid:Add(function() scroll:Destroy() end)
        local empty = Util.new("TextLabel", {
            Name = "None", Visible = false, Text = spec.empty or "no items", TextStyle = "body", TextXAlignment = Enum.TextXAlignment.Left,
            Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -16, 0, LINE), Theme = { TextColor3 = "tx4" }, Parent = well,
        })
        v.Box, v.Well, v.Scroll, v.Empty = box, well, scroll, empty

        local function paintRow(r, kind)
            local sel = r.Item and r.Item.key == v.Selected
            local over = r.Over and not el.Disabled
            r.Bar.Visible = sel
            Anim.to(r.Tint, { BackgroundTransparency = sel and (over and 0.83 or 0.88) or 1 }, kind)
            Anim.to(r.Hit, { BackgroundTransparency = (over and not sel) and 0.97 or 1 }, kind)
            Theme.bind(r.Label, "TextColor3", sel and "ddHl" or (over and "tx" or "tx2"))
        end

        local function fit(r)
            local item = r.Item
            local right = 8
            local metaW = item.meta and item.meta ~= "" and Text.width(tostring(item.meta), "tiny") or 0
            r.Meta.Text = item.meta and tostring(item.meta) or ""
            r.Meta.Size = UDim2.fromOffset(metaW, LINE)
            r.Meta.Position = UDim2.new(1, -(right + metaW), 0, 0)
            if metaW > 0 then right = right + metaW + 8 end
            local markW = item.marker and item.marker ~= "" and Text.width(tostring(item.marker), "tiny") or 0
            r.Marker.Text = item.marker and tostring(item.marker) or ""
            r.Marker.Size = UDim2.fromOffset(markW, LINE)
            r.Marker.Position = UDim2.new(1, -(right + markW), 0, 0)
            if markW > 0 then right = right + markW + 8 end
            r.Label.Text = item.text
            r.Label.Size = UDim2.new(1, -(8 + right), 1, 0)
            if r.Edit then r.Edit.Size = UDim2.new(1, -(8 + right), 1, -4) end
        end

        local function rowFor(index)
            local r = v.Rows[index]
            if r then return r end
            local hit = Util.new("TextButton", { Name = "Row", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, Parent = scroll.Content })
            r = { Hit = hit, Over = false }
            r.Tint = Util.new("Frame", { Name = "Tint", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Theme = { BackgroundColor3 = "ddHl" }, Parent = hit })
            r.Sep = Util.new("Frame", { Name = "Sep", BackgroundTransparency = 0.975, Size = UDim2.new(1, 0, 0, 1), Theme = { BackgroundColor3 = "white" }, Parent = hit })
            r.Bar = Util.new("Frame", { Name = "Bar", Visible = false, Size = UDim2.new(0, 2, 1, 0), Theme = { BackgroundColor3 = "ddHl" }, Parent = hit })
            r.Label = Util.new("TextButton", {
                Name = "Text", BackgroundTransparency = 1, TextStyle = "body", TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
                Position = UDim2.fromOffset(8, 0), Parent = hit,
            })
            r.Marker = Util.new("TextLabel", { Name = "Marker", TextStyle = "tiny", Theme = { TextColor3 = "accent" }, Parent = hit })
            r.Meta = Util.new("TextLabel", { Name = "Meta", TextStyle = "tiny", TextXAlignment = Enum.TextXAlignment.Right, Theme = { TextColor3 = "tx4" }, Parent = hit })
            hit.MouseEnter:Connect(function()
                r.Over = true
                paintRow(r, "fade")
            end)
            hit.MouseLeave:Connect(function()
                r.Over = false
                paintRow(r, "fade")
            end)
            local function press(button)
                local item = r.Item
                if not item or el.Disabled or r.Edit then return end
                local now = clock()
                local double = button == "m1" and v._lastKey == item.key and v._lastAt and now - v._lastAt <= DOUBLE
                v._lastKey, v._lastAt = item.key, now
                if double then v._lastAt = nil end
                v.Select(item.key)
                if double and spec.activate then
                    Util.guard(spec.activate, item.key, item.data or item)
                elseif button == "m2" and spec.menu then
                    local ok, entries = Util.guard(spec.menu, item.key, item.data or item, r)
                    if ok and type(entries) == "table" and #entries > 0 then
                        v.Menu = Layer.menu(r.Meta.Text ~= "" and r.Meta or r.Hit, entries, { box = Layer.box() })
                    end
                end
            end
            for _, gui in ipairs({ hit, r.Label }) do
                gui.MouseButton1Click:Connect(function() press("m1") end)
                gui.MouseButton2Click:Connect(function() press("m2") end)
            end
            v.Rows[index] = r
            return r
        end

        function v.Height()
            local n = math.max(1, math.min(#v.Items, v.MaxRows))
            return n * LINE + 2
        end

        function v.Layout(x, y, width)
            box.Position = UDim2.fromOffset(x, y)
            box.Size = UDim2.fromOffset(width, v.Height())
            scroll:Refit()
        end

        function v.Paint(kind)
            for _, r in ipairs(v.Rows) do
                if r.Item then paintRow(r, kind) end
            end
        end

        function v.Select(key)
            if key == v.Selected then return end
            v.Selected = key
            v.Paint("fade")
            if spec.select then Util.guard(spec.select, key) end
        end

        function v.Reveal()
            for index, item in ipairs(v.Items) do
                if item.key == v.Selected then scroll:Reveal((index - 1) * LINE, index * LINE) end
            end
        end

        function v.Draw()
            v.Items = normal(spec.items)
            for index, item in ipairs(v.Items) do
                local r = rowFor(index)
                r.Item = item
                r.Hit.Visible = true
                r.Hit.Position = UDim2.fromOffset(0, (index - 1) * LINE)
                r.Hit.Size = UDim2.new(1, 0, 0, LINE)
                r.Sep.Visible = index > 1
                fit(r)
                paintRow(r, 0)
            end
            for index = #v.Items + 1, #v.Rows do
                v.Rows[index].Item = nil
                v.Rows[index].Hit.Visible = false
            end
            empty.Visible = #v.Items == 0
            scroll:SetHeight(#v.Items * LINE)
        end

        function v.Edit(key, done)
            local r
            for _, row in ipairs(v.Rows) do
                if row.Item and row.Item.key == key then r = row end
            end
            if not r or r.Edit then return nil end
            local cancelled, finished = false, false
            r.Label.Visible = false
            local edit = Util.new("TextBox", {
                Name = "Edit", Text = r.Item.text, TextStyle = "body", TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false,
                Position = UDim2.fromOffset(6, 2), Size = UDim2.new(1, -16, 1, -4), Theme = { BackgroundColor3 = "card", TextColor3 = "tx" }, Parent = r.Hit,
            })
            Util.new("UIStroke", { Thickness = 1, Transparency = 0.5, Theme = { Color = "accent" }, Parent = edit })
            r.Edit = edit
            fit(r)
            local keyConn = Input.onKey(function(name, down)
                if down and name == "escape" then cancelled = true end
            end)
            local function finish(enter)
                if finished then return end
                finished = true
                keyConn:Disconnect()
                local text = edit.Text
                r.Edit = nil
                edit:Destroy()
                r.Label.Visible = true
                if not cancelled and done then Util.guard(done, text, enter) end
                if not el.Destroyed then v.Draw() end
            end
            edit.FocusLost:Connect(function(enter) finish(enter) end)
            pcall(function() edit:CaptureFocus() end)
            return edit
        end

        return v
    end

    Kinds.list = {
        method = "List", label = false,
        default = "",
        validate = function(opts, value)
            if value == nil then return nil end
            return tostring(value)
        end,
        height = function(el)
            local top = el.Opts.name and LINE or 0
            return top + 4 + (el._view and el._view.Height() or LINE + 2) + 4
        end,
        build = function(el, row)
            local opts = el.Opts
            if opts.name then
                el._title = Util.new("TextLabel", {
                    Name = "Label", Text = tostring(opts.name), TextStyle = "body", TextXAlignment = Enum.TextXAlignment.Left,
                    Position = UDim2.fromOffset(el.X, 0), Size = UDim2.new(1, -(el.X + PAD), 0, LINE), Theme = { TextColor3 = "tx2" }, Parent = row,
                })
            end
            el._view = view(el, row, {
                items = function() return opts.items or opts.options or {} end,
                rows = opts.rows, empty = opts.empty, selected = el.Value,
                select = function(key) el:Set(key) end,
                activate = opts.activate or opts.onActivate,
                menu = opts.menu,
            })
            el._view.Draw()
        end,
        paint = function(el)
            local v = el._view
            if not v then return end
            if v.Selected ~= el.Value then
                v.Selected = el.Value
                v.Paint("fade")
            end
            local top = el.Opts.name and LINE or 0
            v.Layout(el.X, top + 4, math.max(0, el.Container.Width - el.X - PAD))
        end,
        resize = function(el) el:_paint() end,
        methods = {
            SetItems = function(self, items)
                self.Opts.items, self.Opts.options = items, nil
                self:Refresh()
            end,
            Refresh = function(self)
                local v = self._view
                v.Draw()
                self:_paint()
                self:_relayout()
            end,
            Items = function(self) return self._view.Items end,
            Edit = function(self, key, done) return self._view.Edit(key, done) end,
            Reveal = function(self) self._view.Reveal() end,
        },
    }

    local function copyName(name)
        local base = Store.cfgName(name .. " copy")
        local candidate, i = base, 2
        while Store.exists(candidate) and i < 100 do
            candidate = Store.cfgName(name .. " copy " .. i)
            i = i + 1
        end
        return candidate
    end

    local function duplicate(name)
        if Store.duplicate then return Store.duplicate(name) end
        local target = copyName(name)
        if not Exec.hasFs then return false end
        local ok = pcall(function()
            local root = Store.Root .. "/configs/"
            Exec.fs.write(root .. target .. ".json", Exec.fs.read(root .. Store.cfgName(name) .. ".json"))
        end)
        if not ok then return false end
        Store.Selected = target
        Store.Changed:Fire("save", target)
        return true, target
    end

    Kinds.configs = {
        method = "Configs", label = false, index = false,
        height = function(el)
            return 4 + (el._view and el._view.Height() or LINE + 2) + 4
        end,
        build = function(el, row)
            local opts = el.Opts
            local function items()
                local list = {}
                local auto = Store.getAutoload()
                for _, entry in ipairs(Store.list()) do
                    list[#list + 1] = { key = entry.name, text = entry.name, meta = savedAt(entry.saved), marker = entry.name == auto and "autoload" or nil }
                end
                return list
            end
            local v
            local function load(name)
                local ok, why = Store.load(name)
                notify("config", ok and ("loaded " .. name) or tostring(why), ok and "ok" or "warn")
                if opts.onLoad then Util.guard(opts.onLoad, name, ok) end
            end
            v = view(el, row, {
                items = items, rows = opts.rows, empty = opts.empty or "no configs", selected = Store.Selected,
                select = function(key)
                    Store.Selected = key
                    if opts.onSelect then Util.guard(opts.onSelect, key) end
                end,
                activate = function(key) load(key) end,
                menu = function(key)
                    return {
                        { text = "rename", callback = function() el:Rename(key) end },
                        { text = "duplicate", callback = function()
                            local ok, made = duplicate(key)
                            notify("config", ok and ("duplicated as " .. tostring(made)) or ("could not duplicate " .. key), ok and "ok" or "warn")
                        end },
                        "-",
                        { text = "delete", callback = function()
                            local ok = Store.delete(key)
                            notify("config", ok and ("deleted " .. key) or ("could not delete " .. key), "warn")
                        end },
                    }
                end,
            })
            el._view = v
            v.Draw()
            el._maid:Add(Store.Changed:Connect(function(what, name)
                if el.Destroyed then return end
                if what == "delete" and v.Selected == name then
                    local first = Store.list()[1]
                    v.Selected = first and first.name or nil
                    Store.Selected = v.Selected or Store.Selected
                elseif what ~= "autoload" and name then
                    v.Selected = name
                end
                el:Refresh()
                v.Reveal()
            end))
        end,
        paint = function(el)
            local v = el._view
            if not v then return end
            v.Layout(el.X, 4, math.max(0, el.Container.Width - el.X - PAD))
        end,
        resize = function(el) el:_paint() end,
        methods = {
            Refresh = function(self)
                self._view.Draw()
                self:_paint()
                self:_relayout()
            end,
            Selected = function(self) return self._view.Selected end,
            Select = function(self, name)
                self._view.Select(Store.cfgName(name))
                self._view.Reveal()
            end,
            Rename = function(self, name)
                return self._view.Edit(name, function(text)
                    local new = Store.cfgName(text)
                    if new == "" or new == name then return end
                    if Store.exists(new) then
                        notify("config", new .. " already exists", "warn")
                    elseif Store.rename(name, new) then
                        self._view.Selected = new
                        notify("config", "renamed to " .. new, "ok")
                    end
                end)
            end,
            Load = function(self, name)
                name = name or self._view.Selected
                if not name then return false end
                return Store.load(name)
            end,
        },
    }
    Kinds.configs.savedAt = savedAt
    Kinds.configs.duplicate = duplicate

    local PROW, PLIST, TOOLS, HEADER = 28, 280, 24, 20
    local RELS = { "friend", "target", "ignore" }
    local REL_TOKEN = { friend = "ok", target = "accent", ignore = "bad" }
    local FILTERS = { "all", "friends", "targets", "team" }
    local COLS = { { "", 20 }, { "name", 0, "player" }, { "", 40, "team" }, { "hp", 24, "hp" }, { "dist", 56, "dist" }, { "", 52, "relation" } }
    local Relations = {}
    local RelationChanged = Util.Signal.new()
    Aster._maid:Add(RelationChanged)
    Aster.Relations = Relations

    local function setRelation(name, rel)
        name = tostring(name)
        if rel == "" or rel == "none" then rel = nil end
        if Relations[name] == rel then return end
        Relations[name] = rel
        RelationChanged:Fire(name, rel)
    end

    local function defaultSource()
        local out = {}
        local me = LocalPlayer
        local root
        pcall(function() root = me.Character and me.Character:FindFirstChild("HumanoidRootPart") end)
        local ok, list = pcall(function() return Players:GetPlayers() end)
        for _, p in ipairs(ok and list or {}) do
            local entry = { name = p.Name, display = p.DisplayName or p.Name, id = p.UserId, me = p == me, player = p, hp = 0, dist = 0, team = "" }
            pcall(function()
                if p.Team then
                    entry.team = string.lower(p.Team.Name)
                    entry.teamColor = p.TeamColor.Color
                end
                local char = p.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hum then entry.hp = Util.snap(hum.Health / math.max(1, hum.MaxHealth) * 100) end
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp and root and not entry.me then entry.dist = Util.snap((hrp.Position - root.Position).Magnitude) end
            end)
            out[#out + 1] = entry
        end
        return out
    end

    local function colX(width)
        local fixed, gaps = 0, (#COLS - 1) * 8
        for _, c in ipairs(COLS) do fixed = fixed + c[2] end
        local flex = math.max(40, width - 2 * PAD - fixed - gaps)
        local xs, x = {}, PAD
        for i, c in ipairs(COLS) do
            local w = c[2] > 0 and c[2] or flex
            xs[i] = { x, w }
            x = x + w + 8
        end
        return xs
    end

    local function hpToken(hp)
        if hp > 60 then return "ok" end
        if hp > 25 then return "warn" end
        return "bad"
    end

    local function playersBuild(el, row)
        local opts = el.Opts
        local st = { sort = opts.sort or "dist", dir = opts.dir or 1, filter = "all", query = "", selected = nil, rows = {}, data = {}, list = {} }
        el._pl = st
        local tools = Util.new("Frame", { Name = "Tools", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, TOOLS + 8), Parent = row })
        local searchHost = Util.new("Frame", { Name = "SearchHost", BackgroundTransparency = 1, Parent = tools })
        local search = Container.new(searchHost, { width = 100, bg = el.Container.Bg, shown = true })
        st.searchC = search
        st.search = search:Input({ placeholder = "search", callback = function(v)
            st.query = string.lower(v)
            el:Refresh(true)
        end })
        local filterHost = Util.new("Frame", { Name = "FilterHost", BackgroundTransparency = 1, Parent = tools })
        local filterC = Container.new(filterHost, { width = 96, bg = el.Container.Bg, shown = true })
        st.filterC = filterC
        st.filterDd = filterC:Dropdown({ options = FILTERS, default = "all", callback = function(v)
            st.filter = v
            el:Refresh(true)
        end })
        st.refresh = Layer.button(tools, "Refresh", function() el:Refresh() end, { name = "Refresh", height = TOOLS - 2 })
        el._maid:Add(function()
            search:Destroy()
            filterC:Destroy()
        end)

        local header = Util.new("Frame", { Name = "Header", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, TOOLS + 8), Size = UDim2.new(1, 0, 0, HEADER), Parent = row })
        Util.new("Frame", { Name = "Line", Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1), Theme = { BackgroundColor3 = "ln" }, Parent = header })
        st.heads = {}
        for i, c in ipairs(COLS) do
            if c[3] then
                local right = i > 2
                local cls = c[1] ~= "" and "TextButton" or "TextLabel"
                local h = Util.new(cls, {
                    Name = "Col_" .. c[3], BackgroundTransparency = 1, Text = Text.caps("small", c[3]), TextStyle = "small",
                    TextXAlignment = right and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left, Theme = { TextColor3 = "tx4" }, Parent = header,
                })
                local entry = { Gui = h, Key = c[1], Index = i, Right = right }
                if c[1] ~= "" then
                    entry.Chev = Layer.chevron(h, UDim2.fromOffset(0, 8), "accent")
                    h.MouseButton1Click:Connect(function()
                        if el.Disabled then return end
                        if st.sort == c[1] then st.dir = -st.dir else st.dir = c[1] == "name" and 1 or -1 end
                        st.sort = c[1]
                        el:Refresh(true)
                    end)
                end
                st.heads[#st.heads + 1] = entry
            end
        end
        st.header = header
        st.scroll = Scroll.new(row, { name = "Players", position = UDim2.fromOffset(0, TOOLS + 8 + HEADER) })
        el._maid:Add(function() st.scroll:Destroy() end)
        st.none = Util.new("TextLabel", {
            Name = "None", Visible = false, TextStyle = "body", Size = UDim2.new(1, 0, 0, 48), Theme = { TextColor3 = "tx4" }, Parent = st.scroll.Content,
        })
        st.tools = tools
        st.searchHost, st.filterHost = searchHost, filterHost

        el._maid:Add(RelationChanged:Connect(function()
            if not el.Destroyed then el:Refresh(true) end
        end))
        if opts.rate ~= false then
            local left = 0
            local loop
            el._maid:Add(function() if loop then loop:Stop() end end)
            loop = Anim.loop(function(dt)
                if el.Destroyed then return false end
                left = left - dt
                if left <= 0 then
                    left = tonumber(opts.rate) or 1
                    if el:IsShown() then el:Refresh() end
                end
                return true
            end)
        end
    end

    local function paintPlayerRow(el, r, kind)
        local st = el._pl
        local sel = r.Data and r.Data.name == st.selected
        local over = r.Over and not el.Disabled
        r.Bar.Visible = sel
        Anim.to(r.Tint, { BackgroundTransparency = sel and 0.93 or 1 }, kind)
        Anim.to(r.Hit, { BackgroundTransparency = (over and not sel) and 0.978 or 1 }, kind)
        local ign = r.Data and Relations[r.Data.name] == "ignore"
        r.Display.TextTransparency = ign and 0.55 or 0
        r.User.TextTransparency = ign and 0.55 or 0
        r.Head.ImageTransparency = ign and 0.55 or 0
    end

    local function relButton(el, r, rel, parent)
        local b = Util.new("TextButton", { Name = "Rel_" .. rel, BackgroundTransparency = 1, Size = UDim2.fromOffset(16, 16), Parent = parent })
        local stroke = Util.new("UIStroke", { Thickness = 1, Transparency = 1, Theme = { Color = REL_TOKEN[rel] }, Parent = b })
        local image = Icons.get and Icons.get(rel)
        local glyph
        if image then
            glyph = Util.new("ImageLabel", { Name = "Icon", Image = image, Position = UDim2.fromOffset(2, 2), Size = UDim2.fromOffset(12, 12), Parent = b })
        else
            glyph = Util.new("TextLabel", { Name = "Glyph", Text = string.upper(string.sub(rel, 1, 1)), TextStyle = "tiny", Size = UDim2.fromScale(1, 1), Parent = b })
        end
        local e = { Button = b, Stroke = stroke, Glyph = glyph, Rel = rel, Over = false }
        function e.Paint(kind)
            local on = r.Data and Relations[r.Data.name] == rel
            local token = on and REL_TOKEN[rel] or (e.Over and "tx" or "tx4")
            Theme.bind(glyph, image and "ImageColor3" or "TextColor3", token)
            Theme.bind(b, "BackgroundColor3", REL_TOKEN[rel])
            Anim.to(b, { BackgroundTransparency = on and 0.92 or 1 }, kind)
            Anim.to(stroke, { Transparency = on and 0.6 or (e.Over and 0.4 or 1) }, kind)
            if not on then Theme.bind(stroke, "Color", e.Over and "ln2" or REL_TOKEN[rel]) else Theme.bind(stroke, "Color", REL_TOKEN[rel]) end
        end
        b.MouseEnter:Connect(function()
            e.Over = true
            e.Paint("fade")
        end)
        b.MouseLeave:Connect(function()
            e.Over = false
            e.Paint("fade")
        end)
        b.MouseButton1Click:Connect(function()
            if el.Disabled or not r.Data or r.Data.me then return end
            if Relations[r.Data.name] == rel then setRelation(r.Data.name, nil) else setRelation(r.Data.name, rel) end
            local p = r.Data
            notify("players", tostring(p.display or p.name) .. (Relations[p.name] and (" marked as " .. rel) or " relation cleared"), Relations[p.name] == "friend" and "ok" or nil)
        end)
        return e
    end

    local function playerRow(el, index)
        local st = el._pl
        local r = st.rows[index]
        if r then return r end
        local hit = Util.new("TextButton", { Name = "Player", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, Parent = st.scroll.Content })
        r = { Hit = hit, Over = false }
        r.Tint = Util.new("Frame", { Name = "Tint", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Theme = { BackgroundColor3 = "accent" }, Parent = hit })
        r.Bar = Util.new("Frame", { Name = "Bar", Visible = false, Size = UDim2.new(0, 2, 1, 0), Theme = { BackgroundColor3 = "accent" }, Parent = hit })
        r.Pic = Util.new("Frame", { Name = "Pic", Size = UDim2.fromOffset(20, 20), Theme = { BackgroundColor3 = "well" }, Parent = hit })
        Util.new("UIStroke", { Thickness = 1, Theme = { Color = "ln3" }, Parent = r.Pic })
        r.Head = Util.new("ImageLabel", { Name = "Headshot", Size = UDim2.fromScale(1, 1), Parent = r.Pic })
        r.Display = Util.new("TextLabel", { Name = "Display", TextStyle = "bold", TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Theme = { TextColor3 = "tx" }, Parent = hit })
        r.User = Util.new("TextLabel", { Name = "User", TextStyle = "tiny", TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Theme = { TextColor3 = "tx4" }, Parent = hit })
        r.Team = Util.new("TextLabel", { Name = "Team", TextStyle = "tiny", TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Theme = { TextColor3 = "tx4" }, Parent = hit })
        r.Hp = Util.new("TextLabel", { Name = "Hp", TextStyle = "body", TextXAlignment = Enum.TextXAlignment.Right, Parent = hit })
        r.Dist = Util.new("TextLabel", { Name = "Dist", TextStyle = "body", TextXAlignment = Enum.TextXAlignment.Right, Theme = { TextColor3 = "tx2" }, Parent = hit })
        r.Studs = Util.new("TextLabel", { Name = "Studs", Text = " studs", TextStyle = "tiny", TextXAlignment = Enum.TextXAlignment.Left, Theme = { TextColor3 = "tx4" }, Parent = hit })
        r.RelBox = Util.new("Frame", { Name = "Relation", BackgroundTransparency = 1, Parent = hit })
        r.You = Util.new("TextLabel", { Name = "You", Text = "you", TextStyle = "tiny", TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.fromScale(1, 1), Theme = { TextColor3 = "tx4" }, Parent = r.RelBox })
        r.Rels = {}
        for i, rel in ipairs(RELS) do
            local e = relButton(el, r, rel, r.RelBox)
            e.Button.Position = UDim2.new(1, -(16 + (3 - i) * 18), 0, 0)
            r.Rels[i] = e
        end
        hit.MouseEnter:Connect(function()
            r.Over = true
            paintPlayerRow(el, r, "fade")
        end)
        hit.MouseLeave:Connect(function()
            r.Over = false
            paintPlayerRow(el, r, "fade")
        end)
        hit.MouseButton1Click:Connect(function()
            if el.Disabled or not r.Data then return end
            if st.selected == r.Data.name then el:Select(nil) else el:Select(r.Data.name) end
        end)
        st.rows[index] = r
        return r
    end

    local function fillRow(el, r, p, xs)
        r.Data = p
        local studsW = Text.width(" studs", "tiny")
        r.Pic.Position = UDim2.fromOffset(xs[1][1], 4)
        local pid = tonumber(p.id)
        r.Head.Image = (pid and pid > 0) and ("rbxthumb://type=AvatarHeadShot&id=" .. string.format("%.0f", pid) .. "&w=48&h=48") or ""
        r.Display.Text = tostring(p.display or p.name)
        r.Display.Position = UDim2.fromOffset(xs[2][1], 2)
        r.Display.Size = UDim2.fromOffset(xs[2][2], 13)
        r.User.Text = "@" .. tostring(p.name)
        r.User.Position = UDim2.fromOffset(xs[2][1], 15)
        r.User.Size = UDim2.fromOffset(xs[2][2], 11)
        r.Team.Text = tostring(p.tag or p.team or "")
        r.Team.Position = UDim2.fromOffset(xs[3][1], 0)
        r.Team.Size = UDim2.fromOffset(xs[3][2], PROW)
        if typeof(p.teamColor) == "Color3" then
            Theme.unbind(r.Team, "TextColor3")
            r.Team.TextColor3 = p.teamColor
        else
            Theme.bind(r.Team, "TextColor3", "tx4")
        end
        local hp = tonumber(p.hp) or 0
        r.Hp.Text = tostring(Util.snap(hp))
        Theme.bind(r.Hp, "TextColor3", hpToken(hp))
        r.Hp.Position = UDim2.fromOffset(xs[4][1], 0)
        r.Hp.Size = UDim2.fromOffset(xs[4][2], PROW)
        local x5, w5 = xs[5][1], xs[5][2]
        if p.me then
            r.Dist.Text = "-"
            r.Studs.Visible = false
            r.Dist.Position = UDim2.fromOffset(x5, 0)
            r.Dist.Size = UDim2.fromOffset(w5, PROW)
        else
            r.Dist.Text = tostring(Util.snap(tonumber(p.dist) or 0))
            r.Studs.Visible = true
            r.Dist.Position = UDim2.fromOffset(x5, 0)
            r.Dist.Size = UDim2.fromOffset(w5 - studsW, PROW)
            r.Studs.Position = UDim2.fromOffset(x5 + w5 - studsW, 1)
            r.Studs.Size = UDim2.fromOffset(studsW, PROW)
        end
        r.RelBox.Position = UDim2.fromOffset(xs[6][1], 6)
        r.RelBox.Size = UDim2.fromOffset(xs[6][2], 16)
        r.You.Visible = p.me == true
        for _, e in ipairs(r.Rels) do
            e.Button.Visible = not p.me
            e.Paint(0)
        end
        paintPlayerRow(el, r, 0)
    end

    local function playersLayout(el)
        local st = el._pl
        local width = el.Container.Width
        local btnW = st.refresh.Width
        local filterW = 96
        local searchW = math.max(40, width - 2 * PAD - btnW - filterW - 8)
        st.searchHost.Position = UDim2.fromOffset(0, 0)
        st.searchHost.Size = UDim2.fromOffset(searchW + 2 * PAD, TOOLS + 8)
        st.searchC:_resize(searchW + 2 * PAD)
        st.filterHost.Position = UDim2.fromOffset(PAD + searchW + 4 - PAD, 2)
        st.filterHost.Size = UDim2.fromOffset(filterW + 2 * PAD, 28)
        st.filterC:_resize(filterW + 2 * PAD)
        st.refresh.Frame.Position = UDim2.fromOffset(width - PAD - btnW + 1, 5)
        local xs = colX(width)
        st.xs = xs
        for _, h in ipairs(st.heads) do
            local x, w = xs[h.Index][1], xs[h.Index][2]
            local text = Text.caps("small", COLS[h.Index][3])
            h.Gui.Position = UDim2.fromOffset(x, 0)
            h.Gui.Size = UDim2.fromOffset(w, HEADER)
            local sorted = h.Key ~= "" and h.Key == st.sort
            Theme.bind(h.Gui, "TextColor3", sorted and "accent" or "tx4")
            if h.Chev then
                h.Chev.Frame.Visible = sorted
                local tw = Text.width(text, "small")
                local cx = h.Right and (w - tw - 10) or (tw + 4)
                h.Chev.Frame.Position = UDim2.fromOffset(cx, 8)
                h.Chev.Set(st.dir > 0, 0)
            end
        end
        local count = #st.list
        local listH = count == 0 and 48 or math.min(count * PROW, PLIST)
        st.listH = listH
        st.scroll.Frame.Size = UDim2.new(1, 0, 0, listH)
        st.scroll:SetHeight(count == 0 and 48 or count * PROW)
    end

    local function keep(st, p, mine)
        local f = st.filter
        if f == "friends" and Relations[p.name] ~= "friend" then return false end
        if f == "targets" and Relations[p.name] ~= "target" then return false end
        if f == "team" and (p.team or "") ~= (mine or "") then return false end
        local q = st.query
        if q ~= "" and not (string.find(string.lower(tostring(p.name)), q, 1, true) or string.find(string.lower(tostring(p.display or "")), q, 1, true)) then return false end
        return true
    end

    Kinds.players = {
        method = "Players", label = false, index = false,
        height = function(el)
            local st = el._pl
            return TOOLS + 8 + HEADER + (st and st.listH or 48) + 8
        end,
        build = function(el, row)
            playersBuild(el, row)
            el:Refresh()
        end,
        paint = function(el)
            if not el._pl then return end
            for _, r in ipairs(el._pl.rows) do
                if r.Data then paintPlayerRow(el, r, "fade") end
            end
        end,
        resize = function(el) el:Refresh(true) end,
        methods = {
            Refresh = function(self, keepData)
                local st = self._pl
                if not keepData or not st.fetched then
                    local src = self.Opts.source or defaultSource
                    local ok, list = Util.guard(src)
                    st.data = ok and type(list) == "table" and list or {}
                    st.fetched = true
                end
                local mine
                for _, p in ipairs(st.data) do
                    if p.me then mine = p.team end
                end
                local list = {}
                for _, p in ipairs(st.data) do
                    if keep(st, p, mine) then list[#list + 1] = p end
                end
                local sort, dir = st.sort, st.dir
                table.sort(list, function(a, b)
                    if sort == "name" then
                        local x, y = string.lower(tostring(a.display or a.name)), string.lower(tostring(b.display or b.name))
                        if x == y then return tostring(a.name) < tostring(b.name) end
                        if dir > 0 then return x < y end
                        return x > y
                    end
                    local x, y = tonumber(a[sort]) or 0, tonumber(b[sort]) or 0
                    if x == y then return tostring(a.name) < tostring(b.name) end
                    if dir > 0 then return x < y end
                    return x > y
                end)
                st.list = list
                playersLayout(self)
                for i, p in ipairs(list) do
                    local r = playerRow(self, i)
                    r.Hit.Visible = true
                    r.Hit.Position = UDim2.fromOffset(0, (i - 1) * PROW)
                    r.Hit.Size = UDim2.new(1, 0, 0, PROW)
                    fillRow(self, r, p, st.xs)
                end
                for i = #list + 1, #st.rows do
                    st.rows[i].Data = nil
                    st.rows[i].Hit.Visible = false
                end
                st.none.Visible = #list == 0
                st.none.Text = st.query ~= "" and "no matches" or ("no " .. st.filter)
                local found = false
                for _, p in ipairs(st.data) do
                    if p.name == st.selected then
                        found = true
                        st.selectedData = p
                    end
                end
                if st.selected and not found then self:Select(nil) end
                if self.Opts.onUpdate and st.selectedData then Util.guard(self.Opts.onUpdate, st.selectedData, self) end
                self:_relayout()
            end,
            Select = function(self, name)
                local st = self._pl
                if st.selected == name then return end
                st.selected = name
                st.selectedData = nil
                for _, p in ipairs(st.data) do
                    if p.name == name then st.selectedData = p end
                end
                for _, r in ipairs(st.rows) do
                    if r.Data then paintPlayerRow(self, r, "fade") end
                end
                local fn = self.Opts.onSelect or self.Opts.select
                if fn then Util.guard(fn, st.selectedData, self) end
            end,
            Selected = function(self) return self._pl.selectedData end,
            SetSort = function(self, key, dir)
                self._pl.sort, self._pl.dir = key, dir or 1
                self:Refresh(true)
            end,
            SetFilter = function(self, f)
                self._pl.filterDd:Set(f)
            end,
            Relation = function(_, name) return Relations[tostring(name)] end,
            SetRelation = function(_, name, rel) setRelation(name, rel) end,
            Rows = function(self) return self._pl.list end,
        },
    }
    Kinds.players.Relations = Relations
    Kinds.players.RelationChanged = RelationChanged
    Kinds.players.SetRelation = setRelation
    Kinds.players.source = defaultSource
end

-- [src] 54_tiles.lua
do
    local PAD = Element.PAD
    local MIN, GAP, MAXH, LROW = 76, 4, 236, 28

    local function list(el)
        local src = el.Opts.items or {}
        if type(src) == "function" then
            local ok, out = pcall(src)
            src = ok and type(out) == "table" and out or {}
        end
        return src
    end

    local function flag(el, item, field, fn)
        local f = el.Opts[fn]
        if f then
            local ok, v = pcall(f, item)
            return ok and v and true or false
        end
        return item[field] == true
    end

    local function grid(el)
        local width = math.max(0, el.Container.Width - 2 * PAD)
        if el._mode == "list" then return width, 1, width, LROW end
        local cols = math.max(1, math.floor((width + GAP) / (MIN + GAP)))
        local cell = (width - (cols - 1) * GAP) / cols
        local thumb = Util.snap(math.min(cell - 8, 64))
        return width, cols, cell, thumb + 36
    end

    local function paintTile(el, t, kind)
        local on = flag(el, t.Item, "on", "isOn")
        local fav = flag(el, t.Item, "fav", "isFav")
        local over = t.Over and not el.Disabled
        Theme.bind(t.Frame, "BackgroundColor3", on and "accent" or (over and "ln3" or "ln"))
        Anim.to(t.Frame, { BackgroundTransparency = on and 0.45 or 0 }, kind)
        Anim.to(t.Tint, { BackgroundTransparency = on and 0.95 or 1 }, kind)
        Theme.bind(t.Star, "BackgroundColor3", fav and "accent" or "tx3")
        t.Star.Visible = fav or over
        Theme.bind(t.Name, "TextColor3", (on or over) and "tx" or "tx2")
    end

    local function tile(el, index)
        local t = el._tiles[index]
        if t then return t end
        local frame = Util.new("Frame", { Name = "Tile", Parent = el._scroll.Content })
        local inner = Util.new("TextButton", { Name = "Hit", Position = UDim2.fromOffset(1, 1), Size = UDim2.new(1, -2, 1, -2), Theme = { BackgroundColor3 = "well" }, Parent = frame })
        local tint = Util.new("Frame", { Name = "Tint", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Theme = { BackgroundColor3 = "accent" }, Parent = inner })
        local thumb = Util.new("ImageLabel", { Name = "Thumb", BackgroundTransparency = 0, ScaleType = Enum.ScaleType.Fit, Parent = inner })
        local name = Util.new("TextLabel", { Name = "Name", TextStyle = "tiny", TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = inner })
        local sub = Util.new("TextLabel", { Name = "Sub", RichText = true, TextStyle = "tiny", TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Theme = { TextColor3 = "tx3" }, Parent = inner })
        local starHit = Util.new("TextButton", { Name = "Fav", BackgroundTransparency = 1, Size = UDim2.fromOffset(14, 14), ZIndex = 3, Parent = inner })
        local star = Util.new("Frame", { Name = "Star", Rotation = 45, Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(6, 6), Parent = starHit })
        t = { Frame = frame, Hit = inner, Tint = tint, Thumb = thumb, Name = name, Sub = sub, StarHit = starHit, Star = star, Over = false }
        inner.MouseEnter:Connect(function()
            t.Over = true
            paintTile(el, t, "fade")
        end)
        inner.MouseLeave:Connect(function()
            t.Over = false
            paintTile(el, t, "fade")
        end)
        inner.MouseButton1Click:Connect(function()
            if el.Disabled or not t.Item then return end
            local fn = el.Opts.click or el.Opts.callback
            if fn then Util.guard(fn, t.Item, el) end
            paintTile(el, t, "fade")
        end)
        starHit.MouseButton1Click:Connect(function()
            if el.Disabled or not t.Item then return end
            if el.Opts.fav then Util.guard(el.Opts.fav, t.Item, el) end
            paintTile(el, t, "fade")
        end)
        el._tiles[index] = t
        return t
    end

    local function place(el, t, index, item, cols, cell, th)
        local listMode = el._mode == "list"
        local c = (index - 1) % cols
        local r = math.floor((index - 1) / cols)
        local x0 = Util.snap(c * (cell + GAP))
        local x1 = Util.snap(c * (cell + GAP) + cell)
        t.Item = item
        t.Frame.Visible = true
        t.Frame.Position = UDim2.fromOffset(x0, r * (th + (listMode and 0 or GAP)))
        t.Frame.Size = UDim2.fromOffset(x1 - x0, th)
        local w = x1 - x0 - 2
        local img = item.image or item.thumb
        t.Thumb.Image = type(img) == "string" and img or ""
        if typeof(item.color) == "Color3" then
            Theme.unbind(t.Thumb, "BackgroundColor3")
            t.Thumb.BackgroundColor3 = item.color
        else
            Theme.bind(t.Thumb, "BackgroundColor3", "panel2")
        end
        t.Name.Text = tostring(item.name or item.text or item.key or "")
        t.Sub.Text = tostring(item.sub or item.note or "")
        if listMode then
            t.Thumb.Position = UDim2.fromOffset(4, 3)
            t.Thumb.Size = UDim2.fromOffset(th - 8, th - 8)
            t.Name.Position = UDim2.fromOffset(th + 4, 0)
            t.Name.Size = UDim2.new(1, -(th + 4 + 100), 1, 0)
            t.Sub.TextXAlignment = Enum.TextXAlignment.Right
            t.Sub.Position = UDim2.new(1, -96, 0, 0)
            t.Sub.Size = UDim2.new(0, 72, 1, 0)
            t.StarHit.Position = UDim2.new(1, -20, 0, Util.snap((th - 2 - 14) / 2))
        else
            local side = th - 36
            t.Thumb.Position = UDim2.fromOffset(Util.snap((w - side) / 2), 4)
            t.Thumb.Size = UDim2.fromOffset(side, side)
            t.Name.TextXAlignment = Enum.TextXAlignment.Left
            t.Name.Position = UDim2.fromOffset(4, side + 6)
            t.Name.Size = UDim2.new(1, -8, 0, 12)
            t.Sub.TextXAlignment = Enum.TextXAlignment.Left
            t.Sub.Position = UDim2.fromOffset(4, side + 18)
            t.Sub.Size = UDim2.new(1, -8, 0, 12)
            t.StarHit.Position = UDim2.new(1, -16, 0, 2)
        end
        paintTile(el, t, 0)
    end

    local function draw(el)
        local items = list(el)
        local _, cols, cell, th = grid(el)
        for index, item in ipairs(items) do place(el, tile(el, index), index, item, cols, cell, th) end
        for index = #items + 1, #el._tiles do
            el._tiles[index].Item = nil
            el._tiles[index].Frame.Visible = false
        end
        el._empty.Visible = #items == 0
        local rows = math.ceil(#items / cols)
        local listMode = el._mode == "list"
        local total = #items == 0 and 36 or (rows * th + math.max(0, rows - 1) * (listMode and 0 or GAP))
        el._total = total
        el._viewH = math.min(total, el.Opts.maxHeight or MAXH)
        el._scroll:SetHeight(total)
    end

    local function layout(el)
        local width = grid(el)
        el._scroll.Frame.Position = UDim2.fromOffset(PAD, 4)
        el._scroll.Frame.Size = UDim2.fromOffset(width, el._viewH or 36)
        el._scroll:Refit()
    end

    Kinds.tiles = {
        method = "Tiles", label = false, index = false,
        height = function(el) return 4 + (el._viewH or 36) + 8 end,
        build = function(el, row)
            el._tiles = {}
            el._mode = el.Opts.mode == "list" and "list" or "grid"
            el._scroll = Scroll.new(row, { name = "Tiles" })
            el._maid:Add(function() el._scroll:Destroy() end)
            el._empty = Util.new("TextLabel", {
                Name = "None", Visible = false, Text = tostring(el.Opts.empty or "no items"), TextStyle = "body", TextXAlignment = Enum.TextXAlignment.Left,
                Size = UDim2.new(1, 0, 0, 36), Theme = { TextColor3 = "tx4" }, Parent = el._scroll.Content,
            })
            draw(el)
            layout(el)
        end,
        paint = function(el)
            if not el._tiles then return end
            for _, t in ipairs(el._tiles) do
                if t.Item then paintTile(el, t, "fade") end
            end
        end,
        resize = function(el)
            if not el._tiles then return end
            draw(el)
            layout(el)
        end,
        methods = {
            SetItems = function(self, items)
                self.Opts.items = items
                self:Refresh()
            end,
            Refresh = function(self)
                draw(self)
                layout(self)
                self:_relayout()
            end,
            SetMode = function(self, mode)
                self._mode = mode == "list" and "list" or "grid"
                self:Refresh()
            end,
            Mode = function(self) return self._mode end,
            Tiles = function(self) return self._tiles end,
        },
    }
end

-- [src] 55_preview.lua
do
    local PAD = Element.PAD
    local BTN_H, FOOT_GAP = 20, 4
    local ASPECT = { esp = 7 / 6, avatar = 5 / 4, shoot = 10 / 16, hit = 10 / 16, kill = 10 / 16, atmosphere = 10 / 16 }

    local function ratio(opts)
        if tonumber(opts.aspect) then return tonumber(opts.aspect) end
        return ASPECT[opts.kind or opts.preview] or 10 / 16
    end

    local function viewSize(el)
        local width = math.max(0, el.Container.Width - el.X - PAD)
        local height = el.Opts.viewHeight or Util.snap((width - 2) * ratio(el.Opts)) + 2
        return width, height
    end

    local function layout(el)
        local h = el._handle
        local width, height = viewSize(el)
        h.Box.Position = UDim2.fromOffset(el.X, 4)
        h.Box.Size = UDim2.fromOffset(width, height)
        h.Size = Vector2.new(width - 2, height - 2)
        local x = el.X + width
        for index = #h.Buttons, 1, -1 do
            local b = h.Buttons[index]
            x = x - b.Width - 2
            b.Frame.Position = UDim2.fromOffset(x + 1, 4 + height + FOOT_GAP + 1)
            x = x - FOOT_GAP
        end
        if h._w ~= width or h._h ~= height then
            h._w, h._h = width, height
            h.Resized:Fire(h.Size)
            if el.Opts.draw then Util.guard(el.Opts.draw, h) end
        end
    end

    Kinds.preview = {
        method = "Preview", label = false, index = false,
        height = function(el)
            local _, height = viewSize(el)
            local h = el._handle
            local foot = (h and #h.Buttons > 0) and (FOOT_GAP + BTN_H) or 0
            return 4 + height + foot + 8
        end,
        build = function(el, row)
            local opts = el.Opts
            local box = Util.new("Frame", { Name = "View", Theme = { BackgroundColor3 = "ln" }, Parent = row })
            local inner = Util.new("Frame", { Name = "Inner", ClipsDescendants = true, Position = UDim2.fromOffset(1, 1), Size = UDim2.new(1, -2, 1, -2), Theme = { BackgroundColor3 = "well" }, Parent = box })
            local viewport = Util.new("ViewportFrame", { Name = "Viewport", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = inner })
            local camera = Instance.new("Camera")
            camera.FieldOfView = opts.fov or 40
            camera.Parent = viewport
            pcall(function() viewport.CurrentCamera = camera end)
            local world = Instance.new("WorldModel")
            world.Parent = viewport
            local handle = {
                Element = el, Kind = opts.kind or opts.preview or "custom", Box = box, Frame = inner, Viewport = viewport, Camera = camera, World = world,
                Buttons = {}, Size = Vector2.new(0, 0), Resized = Util.Signal.new(),
            }
            el._maid:Add(handle.Resized)
            el._handle = handle
            row:SetAttribute("preview", handle.Kind)

            function handle.SetButtons(a, b)
                local items = type(a) == "table" and a.Element == el and b or a
                for _, button in ipairs(handle.Buttons) do button.Frame:Destroy() end
                handle.Buttons = {}
                for _, item in ipairs(items or {}) do
                    local text = type(item) == "table" and (item.text or item.name or item[1]) or tostring(item)
                    local fn = type(item) == "table" and (item.callback or item.fn or item[2]) or nil
                    local button = Layer.button(row, text, function()
                        if el.Disabled then return end
                        if fn then Util.guard(fn, handle) end
                    end, { height = BTN_H - 2, name = "Button" })
                    handle.Buttons[#handle.Buttons + 1] = button
                end
                layout(el)
                el:_relayout()
            end
            function handle.Clear()
                for _, child in ipairs(world:GetChildren()) do child:Destroy() end
                for _, child in ipairs(viewport:GetChildren()) do
                    if child ~= camera and child ~= world then child:Destroy() end
                end
            end
            function handle.Focus(a, b, c)
                local model, pad = a, b
                if type(a) == "table" and a.Element == el then model, pad = b, c end
                local ok, cf, size = pcall(function() return model:GetBoundingBox() end)
                if not ok then return false end
                local center = cf.Position
                local fov = math.rad(camera.FieldOfView)
                local reach = math.max(size.X, size.Y, size.Z) / 2
                local dist = reach / math.tan(fov / 2) * (pad or 1.25)
                camera.CFrame = CFrame.new(center + Vector3.new(0, 0, dist), center)
                return true
            end
            handle.SetButtons(opts.buttons or {})
            return handle
        end,
        resize = function(el)
            if el._handle then layout(el) end
        end,
        paint = function(el)
            if not el._handle then return end
            for _, b in ipairs(el._handle.Buttons) do b.SetDisabled(el.Disabled) end
        end,
        destroy = function(el)
            if el._handle then pcall(function() el._handle.Clear() end) end
        end,
    }
end

-- [src] 56_scene.lua
do
    local Scene = {}
    Aster.Scene = Scene
    Aster._.Scene = Scene
    Scene.adornInViewport = false

    local R6 = { "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }
    local SIZES = {
        Head = Vector3.new(2, 1, 1), Torso = Vector3.new(2, 2, 1), HumanoidRootPart = Vector3.new(2, 2, 1),
        ["Left Arm"] = Vector3.new(1, 2, 1), ["Right Arm"] = Vector3.new(1, 2, 1),
        ["Left Leg"] = Vector3.new(1, 2, 1), ["Right Leg"] = Vector3.new(1, 2, 1),
    }
    local JOINTS = {
        head = { "Head", Vector3.new(0, 0, 0) },
        neck = { "Torso", Vector3.new(0, 1, 0) }, pelvis = { "Torso", Vector3.new(0, -1, 0) },
        lShoulder = { "Left Arm", Vector3.new(0, 0.85, 0) }, lElbow = { "Left Arm", Vector3.new(0, 0, 0) }, lHand = { "Left Arm", Vector3.new(0, -0.9, 0) },
        rShoulder = { "Right Arm", Vector3.new(0, 0.85, 0) }, rElbow = { "Right Arm", Vector3.new(0, 0, 0) }, rHand = { "Right Arm", Vector3.new(0, -0.9, 0) },
        lHip = { "Left Leg", Vector3.new(0, 0.85, 0) }, lKnee = { "Left Leg", Vector3.new(0, 0, 0) }, lFoot = { "Left Leg", Vector3.new(0, -0.95, 0) },
        rHip = { "Right Leg", Vector3.new(0, 0.85, 0) }, rKnee = { "Right Leg", Vector3.new(0, 0, 0) }, rFoot = { "Right Leg", Vector3.new(0, -0.95, 0) },
        gun = { "Right Arm", Vector3.new(0, -1.1, -0.5) },
    }
    local BONES = {
        { "head", "neck" }, { "neck", "pelvis" },
        { "neck", "lShoulder" }, { "lShoulder", "lElbow" }, { "lElbow", "lHand" },
        { "neck", "rShoulder" }, { "rShoulder", "rElbow" }, { "rElbow", "rHand" },
        { "pelvis", "lHip" }, { "lHip", "lKnee" }, { "lKnee", "lFoot" },
        { "pelvis", "rHip" }, { "rHip", "rKnee" }, { "rKnee", "rFoot" },
    }
    Scene.R6, Scene.Sizes, Scene.Joints, Scene.Bones = R6, SIZES, JOINTS, BONES
    local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)

    local function color(v, default)
        return Util.hex(v) or default
    end
    local function num(v, default)
        return tonumber(v) or default
    end
    local function opt(v, default)
        if v == nil then return default end
        return v
    end
    local function lerp(a, b, t)
        return a + (b - a) * t
    end
    local function part(props)
        local p = Instance.new("Part")
        p.Anchored, p.CanCollide = true, false
        pcall(function()
            p.CanQuery, p.CanTouch, p.CastShadow = false, false, false
            p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
        end)
        p.Material = Enum.Material.SmoothPlastic
        local parent = props.Parent
        props.Parent = nil
        if props.Shape then p.Shape = props.Shape end
        for k, v in pairs(props) do p[k] = v end
        p.Parent = parent
        return p
    end
    local function material(name)
        local ok, m = pcall(function() return Enum.Material[name] end)
        if ok and m then return m end
        return Enum.Material.Neon
    end
    local function modelOf(target)
        if type(target) == "table" and target.Model then return target.Model, target end
        return target, nil
    end
    local function bodyPart(model, name)
        if not model then return nil end
        local ok, found = pcall(function() return model:FindFirstChild(name) end)
        if ok and found then return found end
        return nil
    end
    local function line(parent, name, z)
        return Util.new("Frame", { Name = name, BorderSizePixel = 0, ZIndex = z or 1, Size = UDim2.fromOffset(0, 0), Parent = parent })
    end
    local function placeRect(f, x, y, w, h)
        f.Position = UDim2.fromOffset(Util.snap(x), Util.snap(y))
        f.Size = UDim2.fromOffset(math.max(0, Util.snap(w)), math.max(0, Util.snap(h)))
    end
    local function placeLine(f, x1, y1, x2, y2, thick)
        local dx, dy = x2 - x1, y2 - y1
        local len = math.sqrt(dx * dx + dy * dy)
        f.AnchorPoint = Vector2.new(0.5, 0.5)
        f.Position = UDim2.fromOffset(Util.snap((x1 + x2) / 2), Util.snap((y1 + y2) / 2))
        f.Size = UDim2.fromOffset(Util.snap(len), thick or 1)
        f.Rotation = math.deg(math.atan2(dy, dx))
    end
    Scene._placeRect, Scene._placeLine = placeRect, placeLine

    local function crosses(a, b, cf, size)
        local p0, p1 = cf:PointToObjectSpace(a), cf:PointToObjectSpace(b)
        local t0, t1 = 0, 1
        local o = { p0.X, p0.Y, p0.Z }
        local d = { p1.X - p0.X, p1.Y - p0.Y, p1.Z - p0.Z }
        local h = { size.X / 2, size.Y / 2, size.Z / 2 }
        for i = 1, 3 do
            if math.abs(d[i]) < 1e-9 then
                if o[i] < -h[i] or o[i] > h[i] then return false end
            else
                local ta, tb = (-h[i] - o[i]) / d[i], (h[i] - o[i]) / d[i]
                if ta > tb then ta, tb = tb, ta end
                if ta > t0 then t0 = ta end
                if tb < t1 then t1 = tb end
                if t0 > t1 then return false end
            end
        end
        return true
    end
    Scene._crosses = crosses

    function Scene.attach(handle)
        if handle._scene then return handle end
        handle._scene = true
        local el = handle.Element
        local camera = handle.Camera
        local maid = Util.Maid.new()
        handle.Maid = maid
        el._maid:Add(maid)
        Aster._maid:Add(maid)
        local shown = Util.Signal.new()
        maid:Add(shown)
        maid:Add(el.Shown:Connect(function(on) shown:Fire(on) end))

        function handle:IsShown()
            return el:IsShown() and not Aster.Unloaded and not el.Destroyed
        end
        function handle:OnShow(fn)
            local conn = shown:Connect(fn)
            if handle:IsShown() then Util.guard(fn, true) end
            return conn
        end
        function handle:Loop(fn)
            local loop = { stopped = false }
            local anim
            local function run(on)
                if on and not anim and not loop.stopped then
                    anim = Anim.loop(function(dt)
                        if loop.stopped or not handle:IsShown() then
                            anim = nil
                            return false
                        end
                        Util.guard(fn, dt)
                        return true
                    end)
                elseif not on and anim then
                    anim:Stop()
                    anim = nil
                end
            end
            local conn = handle:OnShow(run)
            function loop.Stop()
                if loop.stopped then return end
                loop.stopped = true
                conn.Disconnect()
                if anim then anim:Stop() end
                anim = nil
            end
            function loop.Running() return anim ~= nil end
            loop.Disconnect = loop.Stop
            maid:Add(loop)
            return loop
        end
        function handle:Project(pos)
            local w, h = handle.Size.X, handle.Size.Y
            local rel = camera.CFrame:PointToObjectSpace(pos)
            local depth = -rel.Z
            if depth <= 1e-3 or h <= 0 then return 0, 0, depth, false end
            local focal = (h / 2) / math.tan(math.rad(camera.FieldOfView) / 2)
            local x = w / 2 + rel.X / depth * focal
            local y = h / 2 - rel.Y / depth * focal
            return Util.snap(x), Util.snap(y), depth, x >= 0 and x <= w and y >= 0 and y <= h
        end
        local function place()
            local view = handle._view
            if not view then return end
            local turn = CFrame.Angles(0, math.rad(view.yaw), 0) * Vector3.new(0, 0, view.dist)
            camera.CFrame = CFrame.new(view.center + turn, view.center)
        end
        function handle:Fit(pad, yaw)
            local spec = type(pad) == "table" and pad or { pad = pad, yaw = yaw }
            local center, reach = spec.center, spec.reach
            if not (center and reach) then
                local ok, cf, size = pcall(function() return handle.World:GetBoundingBox() end)
                if not ok or not size or size.Magnitude == 0 then return false end
                center = center or cf.Position
                reach = reach or math.max(size.X, size.Y, size.Z) / 2
            end
            local fov = math.rad(camera.FieldOfView)
            handle._view = { center = center, dist = reach / math.tan(fov / 2) * num(spec.pad, 1.25), yaw = num(spec.yaw, 0) }
            place()
            return true
        end
        function handle:SetModel(model, fit)
            model.Parent = handle.World
            if fit ~= false then handle:Fit() end
            return model
        end
        function handle:Orbit(on, speed)
            if handle._orbit then
                handle._orbit.Stop()
                handle._orbit = nil
            end
            if on == false then return end
            if not handle._view then handle:Fit() end
            handle._orbit = handle:Loop(function(dt)
                local view = handle._view
                if not view then return end
                view.yaw = (view.yaw + num(speed, 24) * dt) % 360
                place()
            end)
            return handle._orbit
        end
        return handle
    end
    local attach = Scene.attach

    local Dummy = {}
    Dummy.__index = Dummy
    Scene.DummyClass = Dummy

    local function strip(model)
        for _, d in ipairs(model:GetDescendants()) do
            local ok, junk = pcall(function()
                return d:IsA("BaseScript") or d:IsA("ModuleScript") or d:IsA("ForceField") or d:IsA("Sound")
            end)
            if ok and junk then pcall(function() d:Destroy() end) end
        end
        return model
    end

    local function isR6(model)
        return model ~= nil and bodyPart(model, "Torso") ~= nil and bodyPart(model, "Head") ~= nil
    end

    local function fromCharacter()
        local char = LocalPlayer and LocalPlayer.Character
        if not char then return nil end
        local old
        pcall(function()
            old = char.Archivable
            char.Archivable = true
        end)
        local ok, copy = pcall(function() return char:Clone() end)
        pcall(function() char.Archivable = old end)
        if ok and isR6(copy) then return strip(copy) end
        if ok and copy then pcall(function() copy:Destroy() end) end
        return nil
    end

    local function fromUser(id)
        id = id or (LocalPlayer and LocalPlayer.UserId)
        if not id then return nil end
        local ok, model = pcall(function()
            local desc = Players:GetHumanoidDescriptionFromUserId(id)
            return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R6)
        end)
        if not (ok and isR6(model)) then
            if ok and model then pcall(function() model:Destroy() end) end
            ok, model = pcall(function() return Players:CreateHumanoidModelFromUserId(id) end)
        end
        if ok and isR6(model) then return strip(model) end
        if ok and model then pcall(function() model:Destroy() end) end
        return nil
    end

    local function fromParts(skin)
        local model = Instance.new("Model")
        model.Name = "Dummy"
        for _, name in ipairs(R6) do
            local p = part({ Name = name, Size = SIZES[name], Color = skin, CFrame = CFrame.new(), Parent = model })
            if name == "Head" then
                local mesh = Instance.new("SpecialMesh")
                pcall(function()
                    mesh.MeshType = Enum.MeshType.Head
                    mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
                end)
                mesh.Parent = p
            end
        end
        local root = part({ Name = "HumanoidRootPart", Size = SIZES.HumanoidRootPart, Transparency = 1, CFrame = CFrame.new(), Parent = model })
        pcall(function() model.PrimaryPart = root end)
        local humanoid = Instance.new("Humanoid")
        pcall(function()
            humanoid.RigType = Enum.HumanoidRigType.R6
            humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        end)
        humanoid.Parent = model
        return model
    end

    local function build(opts)
        local source = opts.source or "auto"
        local model, from
        if source == "auto" or source == "character" then
            model = fromCharacter()
            from = model and "character"
        end
        if not model and (source == "auto" or source == "user") then
            model = fromUser(opts.userId)
            from = model and "user"
        end
        if not model then
            model = fromParts(color(opts.color, Color3.fromRGB(163, 162, 165)))
            from = "parts"
        end
        model.Name = "Dummy"
        return model, from
    end

    local function rig(dummy)
        local model = dummy.Model
        local parts, followers, orig = {}, {}, {}
        for _, name in ipairs(R6) do parts[name] = bodyPart(model, name) end
        parts.HumanoidRootPart = bodyPart(model, "HumanoidRootPart")
        local body = {}
        for _, p in pairs(parts) do body[p] = true end
        local joints = {}
        for _, d in ipairs(model:GetDescendants()) do
            local okPart, isPart = pcall(function() return d:IsA("BasePart") end)
            if okPart and isPart and not body[d] then
                local anchor = parts.Head
                for _, j in ipairs(d:GetChildren()) do
                    local okJ, other = pcall(function()
                        if not j:IsA("JointInstance") and not j:IsA("WeldConstraint") then return nil end
                        return j.Part0 == d and j.Part1 or j.Part0
                    end)
                    if okJ and other and body[other] then anchor = other end
                end
                local ok, offset = pcall(function() return anchor.CFrame:ToObjectSpace(d.CFrame) end)
                offset = ok and offset or CFrame.new()
                followers[#followers + 1] = { part = d, anchor = anchor, offset = offset, scaled = offset }
            end
            local okJoint, isJoint = pcall(function() return d:IsA("JointInstance") or d:IsA("WeldConstraint") end)
            if okJoint and isJoint then joints[#joints + 1] = d end
        end
        for _, j in ipairs(joints) do pcall(function() j:Destroy() end) end
        local function remember(p)
            pcall(function()
                p.Anchored = true
                p.CanCollide = false
                orig[p] = { Size = p.Size, Transparency = p.Transparency, Color = p.Color, Material = p.Material }
            end)
        end
        for _, p in pairs(parts) do remember(p) end
        for _, f in ipairs(followers) do remember(f.part) end
        dummy.Parts, dummy._followers, dummy._orig = parts, followers, orig
    end

    function Scene.Dummy(handle, opts)
        if type(handle) == "table" and handle.Viewport == nil and opts == nil then handle, opts = nil, handle end
        opts = opts or {}
        local model, from = build(opts)
        local walk = opts.walk or {}
        local dummy = setmetatable({
            Model = model, Source = from, Motion = opts.motion or "idle", Handle = handle,
            Walk = { from = num(walk.from, -5), to = num(walk.to, 5), speed = num(walk.speed, 4) },
            _base = opts.cframe or (CFrame.new(0, 3, 0) * CFrame.Angles(0, math.pi, 0)), _t = 0, _paused = false,
            Height = 1, Width = 1,
        }, Dummy)
        rig(dummy)
        if opts.height or opts.width then dummy:SetScale(opts.height, opts.width, true) end
        dummy:Pose(0)
        if handle then
            attach(handle)
            model.Parent = handle.World
            if opts.fit ~= false then dummy:Fit() end
            dummy._loop = handle:Loop(function(dt)
                if dummy._paused then return end
                dummy._t = dummy._t + dt
                dummy:Pose()
            end)
            handle.Maid:Add(dummy)
        end
        return dummy
    end

    function Dummy:Fit(pad)
        local handle = self.Handle
        if not handle then return false end
        if pad then self._pad = pad end
        local base = self._base.Position
        local h = self.Height
        local reach = 3.2 * h
        local cx = base.X
        if self.Motion == "walk" then
            reach = math.max(reach, (self.Walk.to - self.Walk.from) / 2 + 1.5)
            cx = base.X + (self.Walk.from + self.Walk.to) / 2
        end
        local yaw = handle._view and handle._view.yaw or 0
        return handle:Fit({ center = Vector3.new(cx, base.Y + 2.5 * h - 2.9, base.Z), reach = reach, pad = self._pad or 1.15, yaw = yaw })
    end

    function Dummy:_resize()
        local h, w = self.Height, self.Width
        for p, o in pairs(self._orig) do
            pcall(function() p.Size = Vector3.new(o.Size.X * w, o.Size.Y * h, o.Size.Z * w) end)
        end
        for _, f in ipairs(self._followers) do
            local o = f.offset
            f.scaled = CFrame.new(o.X * w, o.Y * h, o.Z * w) * (o - o.Position)
        end
    end

    function Dummy:SetScale(h, w, noFit)
        h = math.max(0.25, math.min(3, num(h, self.Height)))
        w = math.max(0.25, math.min(3, num(w, self.Width)))
        if h == self.Height and w == self.Width then return self end
        self.Height, self.Width = h, w
        self:_resize()
        self:Pose()
        if not noFit then self:Fit() end
        return self
    end

    function Dummy:Extents()
        local lo, hi
        for _, p in pairs(self.Parts) do
            if p.Name ~= "HumanoidRootPart" then
                local cf, s = p.CFrame, p.Size / 2
                for i = 0, 7 do
                    local v = cf * Vector3.new(i % 2 == 0 and -s.X or s.X, i % 4 < 2 and -s.Y or s.Y, i < 4 and -s.Z or s.Z)
                    lo = lo and Vector3.new(math.min(lo.X, v.X), math.min(lo.Y, v.Y), math.min(lo.Z, v.Z)) or v
                    hi = hi and Vector3.new(math.max(hi.X, v.X), math.max(hi.Y, v.Y), math.max(hi.Z, v.Z)) or v
                end
            end
        end
        if not lo then return Vector3.new(), Vector3.new() end
        return hi - lo, (hi + lo) / 2
    end

    function Dummy:SetMotion(motion)
        self.Motion = motion or "none"
        self._t = 0
        self:Fit()
        self:Pose(0)
    end

    function Dummy:SetRoot(cf)
        self._base = cf
        self:Pose()
    end

    function Dummy:Pause(on)
        self._paused = on ~= false
    end

    function Dummy:_root(t)
        if self.Motion ~= "walk" then return self._base, 0 end
        local w = self.Walk
        local span = math.max(w.to - w.from, 0.01)
        local s = (t * w.speed / span) % 2
        local dir = 1
        if s > 1 then
            s = 2 - s
            dir = -1
        end
        local base = self._base.Position
        local face = dir > 0 and -math.pi / 2 or math.pi / 2
        return CFrame.new(base.X + w.from + span * s, base.Y, base.Z) * CFrame.Angles(0, face, 0), dir
    end

    function Dummy:Pose(t)
        t = t or self._t
        local root = self:_root(t)
        local swing, bob, look = 0, 0, 0
        if self.Motion == "walk" then
            local phase = t * self.Walk.speed * 2.2
            swing = math.sin(phase) * 0.75
            bob = math.abs(math.cos(phase)) * 0.12
        elseif self.Motion == "idle" then
            swing = math.sin(t * 1.4) * 0.06
            bob = math.sin(t * 2.8) * 0.03
            look = math.sin(t * 0.7) * 0.15
        end
        local h, w = self.Height, self.Width
        local torso = root * CFrame.new(0, bob + 3 * (h - 1), 0)
        local p = self.Parts
        local cfs = {
            Torso = torso, HumanoidRootPart = torso,
            Head = torso * CFrame.new(0, h, 0) * CFrame.Angles(0, look, 0) * CFrame.new(0, 0.5 * h, 0),
            ["Left Arm"] = torso * CFrame.new(-1.5 * w, 0.5 * h, 0) * CFrame.Angles(swing, 0, 0) * CFrame.new(0, -0.5 * h, 0),
            ["Right Arm"] = torso * CFrame.new(1.5 * w, 0.5 * h, 0) * CFrame.Angles(-swing, 0, 0) * CFrame.new(0, -0.5 * h, 0),
            ["Left Leg"] = torso * CFrame.new(-0.5 * w, -h, 0) * CFrame.Angles(-swing, 0, 0) * CFrame.new(0, -h, 0),
            ["Right Leg"] = torso * CFrame.new(0.5 * w, -h, 0) * CFrame.Angles(swing, 0, 0) * CFrame.new(0, -h, 0),
        }
        for name, cf in pairs(cfs) do
            if p[name] then p[name].CFrame = cf end
        end
        for _, f in ipairs(self._followers) do
            pcall(function() f.part.CFrame = f.anchor.CFrame * f.scaled end)
        end
        self.Root = torso
        return torso
    end

    function Dummy:Point(name)
        local spec = JOINTS[name]
        local p = spec and self.Parts[spec[1]]
        if not p then return nil end
        local o = spec[2]
        return p.CFrame * Vector3.new(o.X * self.Width, o.Y * self.Height, o.Z * self.Width)
    end

    function Dummy:Reset()
        for p, o in pairs(self._orig) do
            pcall(function()
                p.Size, p.Transparency, p.Color, p.Material = o.Size, o.Transparency, o.Color, o.Material
            end)
        end
        self:_resize()
        self:Pose()
    end

    function Dummy:Destroy()
        if self.Destroyed then return end
        self.Destroyed = true
        if self._loop then self._loop.Stop() end
        pcall(function() self.Model:Destroy() end)
    end

    local Wall = {}
    Wall.__index = Wall

    function Scene.Wall(handle, opts)
        attach(handle)
        opts = opts or {}
        local wall = setmetatable({ Handle = handle, Visible = true, Offset = 0, _t = 0 }, Wall)
        wall.Base = opts.cframe or CFrame.new(2.5, 2.5, 3)
        wall.Part = part({
            Name = "Wall", Size = opts.size or Vector3.new(5, 6, 0.4), CFrame = wall.Base,
            Color = color(opts.color, Color3.fromRGB(70, 70, 78)), Transparency = num(opts.transparency, 0),
            Material = material(opts.material or "SmoothPlastic"), Parent = handle.World,
        })
        handle.Maid:Add(wall)
        if opts.sweep then wall:Sweep(opts.sweep) end
        return wall
    end

    function Wall:isOccluded(target)
        if not self.Visible or self.Destroyed then return false end
        local point = target
        if typeof(target) ~= "Vector3" then
            local ok, pos = pcall(function() return target.CFrame.Position end)
            if not ok then return false end
            point = pos
        end
        return crosses(self.Handle.Camera.CFrame.Position, point, self.Part.CFrame, self.Part.Size)
    end
    Wall.IsOccluded = Wall.isOccluded

    function Wall:SetOffset(x)
        self.Offset = x
        self.Part.CFrame = self.Base * CFrame.new(x, 0, 0)
    end

    function Wall:SweepAt(t)
        local s = self._sweep
        if not s then return self.Offset end
        local stops = { s.from, s.center, s.to, s.center }
        local leg = s.hold + s.move
        t = t % (leg * 4)
        local i = math.floor(t / leg)
        local into = t - i * leg
        local a, b = stops[i + 1], stops[(i + 1) % 4 + 1]
        if into < s.hold then return a end
        local k = (into - s.hold) / s.move
        return lerp(a, b, k * k * (3 - 2 * k))
    end

    function Wall:Sweep(spec)
        if self._loop then
            self._loop.Stop()
            self._loop = nil
        end
        if spec == false then
            self._sweep = nil
            self:SetOffset(0)
            return self
        end
        spec = type(spec) == "table" and spec or {}
        self._sweep = {
            from = num(spec.from, -6.5), to = num(spec.to, 6.5), center = num(spec.center, 0),
            move = math.max(num(spec.move, 1.6), 0.05), hold = math.max(num(spec.hold, 0.7), 0),
        }
        self._t = 0
        self:SetOffset(self:SweepAt(0))
        self._loop = self.Handle:Loop(function(dt)
            self._t = self._t + dt
            self:SetOffset(self:SweepAt(self._t))
        end)
        return self
    end

    function Wall:SetVisible(on)
        self.Visible = on ~= false
        self.Part.Transparency = self.Visible and 0 or 1
    end

    function Wall:Destroy()
        if self.Destroyed then return end
        self.Destroyed = true
        if self._loop then self._loop.Stop() end
        pcall(function() self.Part:Destroy() end)
    end

    local Chams = {}
    Chams.__index = Chams
    local CHAM_DEFAULTS = {
        enabled = true, visColor = WHITE, visAlpha = 0.5, occColor = WHITE, occAlpha = 0.5, walls = true,
        grow = 0.1, round = true, head = 1.15, glow = false, glowSize = 1.75, material = "SmoothPlastic",
    }
    local REGIONS = { "behind", "left", "right", "top", "bottom" }
    local CUBE = {}
    for _, sx in ipairs({ -0.5, 0.5 }) do
        for _, sy in ipairs({ -0.5, 0.5 }) do
            for _, sz in ipairs({ -0.5, 0.5 }) do CUBE[#CUBE + 1] = Vector3.new(sx, sy, sz) end
        end
    end

    local function roundClass()
        if Scene._round == nil then
            local ok, probe = pcall(Instance.new, "CylinderHandleAdornment")
            if ok and probe then
                pcall(function() probe:Destroy() end)
                Scene._round = "CylinderHandleAdornment"
            else
                Scene._round = "SphereHandleAdornment"
            end
        end
        return Scene._round
    end

    function Scene.Chams(handle, target, cfg)
        attach(handle)
        local model = modelOf(target)
        local chams = setmetatable({ Handle = handle, Model = model, Cfg = {}, slots = {}, _force = nil }, Chams)
        for k, v in pairs(CHAM_DEFAULTS) do chams.Cfg[k] = v end
        chams:_merge(cfg)
        chams:_rebuild()
        chams._loop = handle:Loop(function() chams:Update() end)
        handle.Maid:Add(chams)
        return chams
    end

    function Chams:_merge(cfg)
        for k, v in pairs(cfg or {}) do
            if k == "visColor" or k == "occColor" then
                self.Cfg[k] = color(v, self.Cfg[k])
            else
                self.Cfg[k] = v
            end
        end
    end

    function Chams:_pick()
        return self._force or (Scene.adornInViewport and "adorn" or "parts")
    end

    function Chams:_overlay()
        if self.Overlay then return self.Overlay end
        local root = Util.new("Frame", { Name = "Chams", BackgroundTransparency = 1, ZIndex = 2, Size = UDim2.fromScale(1, 1), Parent = self.Handle.Frame })
        local views = {}
        for _, key in ipairs(REGIONS) do
            local clip = Util.new("Frame", { Name = "Clip_" .. key, BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 2, Size = UDim2.fromOffset(0, 0), Parent = root })
            local view = Util.new("ViewportFrame", { Name = "View", BackgroundTransparency = 1, ZIndex = 2, Size = UDim2.fromOffset(0, 0), Parent = clip })
            pcall(function()
                view.Ambient, view.LightColor = WHITE, BLACK
            end)
            local cam = Instance.new("Camera")
            cam.Parent = view
            pcall(function() view.CurrentCamera = cam end)
            views[key] = { key = key, clip = clip, view = view, camera = cam }
        end
        self.Root, self.Views = root, views
        self.Overlay, self.OverlayCamera = views.behind.view, views.behind.camera
        return self.Overlay
    end

    function Chams:_adorn(round, behind)
        local class = round and roundClass() or "BoxHandleAdornment"
        local ok, a = pcall(Instance.new, class)
        if not (ok and a) then return nil end
        pcall(function() a.AdornCullingMode = Enum.AdornCullingMode.Never end)
        if class == "CylinderHandleAdornment" then a.CFrame = CFrame.new(Vector3.new(0, 0, 0), Vector3.new(0, 90, 0)) end
        a.AlwaysOnTop = behind
        a.ZIndex = behind and 1 or -1
        a.Name = behind and "Behind" or "Visible"
        a.Parent = self.Handle.Viewport
        return a
    end

    function Chams:_piece(round, view, name)
        return part({
            Name = name, Shape = round and Enum.PartType.Cylinder or Enum.PartType.Block,
            Size = Vector3.new(1, 1, 1), Transparency = 1, Material = material(self.Cfg.material), Parent = view,
        })
    end

    function Chams:_drop()
        for _, slot in pairs(self.slots) do
            for _, layer in pairs(slot.layers) do pcall(function() layer:Destroy() end) end
            for _, layer in ipairs(slot.copies or {}) do pcall(function() layer:Destroy() end) end
        end
        self.slots = {}
        if self.Root then pcall(function() self.Root:Destroy() end) end
        self.Root, self.Views, self.Overlay, self.OverlayCamera = nil, nil, nil, nil
    end

    function Chams:_rebuild()
        self:_drop()
        self.Mode = self:_pick()
        if not self.Cfg.enabled then return end
        local parts = self.Mode == "parts"
        if parts then self:_overlay() end
        for _, name in ipairs(R6) do
            local p = bodyPart(self.Model, name)
            if p then
                local round = name == "Head" and self.Cfg.round == true
                local slot = { name = name, part = p, round = round, cover = 0, state = "visible" }
                if parts then
                    slot.layers = { behind = self:_piece(round, self.Views.behind.view, "Behind") }
                    slot.copies = {}
                    for i = 2, #REGIONS do slot.copies[i - 1] = self:_piece(round, self.Views[REGIONS[i]].view, "Visible") end
                    slot.layers.visible = slot.copies[1]
                else
                    local behind, visible = self:_adorn(round, true), self:_adorn(round, false)
                    if not (behind and visible) then
                        if behind then behind:Destroy() end
                        if visible then visible:Destroy() end
                        self._force = "parts"
                        return self:_rebuild()
                    end
                    slot.layers = { behind = behind, visible = visible }
                end
                self.slots[name] = slot
                self:_style(slot)
            end
        end
        self:Update()
    end

    function Chams:_style(slot)
        local cfg, layers, p = self.Cfg, slot.layers, slot.part
        local grow = num(cfg.grow, 0.1)
        local headScale = num(cfg.head, 1.15)
        local parts = self.Mode == "parts"
        local size = SIZES[slot.name]
        pcall(function()
            if typeof(p.Size) == "Vector3" and math.min(p.Size.X, p.Size.Y, p.Size.Z) >= 0.05 then size = p.Size end
        end)
        local behindSize, visibleSize
        if slot.round then
            local radius, height = (SIZES.Head.X / 2 - 0.4) * headScale, SIZES.Head.Y * headScale
            if parts then
                behindSize = Vector3.new(height, radius * 2, radius * 2)
                visibleSize = Vector3.new(height + grow, radius * 2 + grow, radius * 2 + grow)
            elseif layers.behind.ClassName == "SphereHandleAdornment" then
                radius = math.max(radius, height / 2)
                layers.behind.Radius, layers.visible.Radius = radius, radius + grow / 2
            else
                layers.behind.Radius, layers.behind.Height = radius, height
                layers.visible.Radius, layers.visible.Height = radius + grow / 2, height + grow
            end
        else
            behindSize, visibleSize = size, size + Vector3.new(grow, grow, grow)
        end
        local visT = 1 - num(cfg.visAlpha, 0.5)
        local visColor = cfg.visColor
        slot.behindColor, slot.behindT = cfg.occColor, 1 - num(cfg.occAlpha, 0.5)
        if cfg.glow == true then
            local strength = math.max(num(cfg.glowSize, 1), 1)
            visColor = visColor:Lerp(WHITE, Util.clamp((strength - 1) / 3, 0, 0.5))
            visT = visT / strength
        end
        slot.visColor, slot.visT = visColor, visT
        if parts then
            layers.behind.Size, layers.behind.Color, layers.behind.Transparency = behindSize, slot.behindColor, slot.behindT
            for _, copy in ipairs(slot.copies) do
                copy.Size, copy.Color, copy.Transparency = visibleSize, visColor, visT
            end
            slot.cf = nil
            return
        end
        if behindSize then layers.behind.Size, layers.visible.Size = behindSize, visibleSize end
        layers.behind.Color3, layers.visible.Color3 = slot.behindColor, visColor
        layers.behind.Adornee, layers.visible.Adornee = p, p
        layers.visible.AlwaysOnTop = cfg.glow == true and cfg.walls ~= false
    end

    function Chams:_sync()
        local main = self.Handle.Camera
        local cf, fov = main.CFrame, main.FieldOfView
        for _, v in pairs(self.Views) do
            if v.cf ~= cf or v.fov ~= fov then
                v.cf, v.fov = cf, fov
                v.camera.CFrame, v.camera.FieldOfView = cf, fov
            end
        end
    end

    local function rectOf(handle, cf, size)
        local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
        for _, c in ipairs(CUBE) do
            local x, y, depth = handle:Project(cf * Vector3.new(c.X * size.X, c.Y * size.Y, c.Z * size.Z))
            if depth <= 1e-3 then return nil end
            x0, y0, x1, y1 = math.min(x0, x), math.min(y0, y), math.max(x1, x), math.max(y1, y)
        end
        return { x0 = x0, y0 = y0, x1 = x1, y1 = y1 }
    end
    Scene._rectOf = rectOf

    function Chams:Cover()
        local wall, handle = self.Cfg.wall, self.Handle
        if not wall or wall.Destroyed or not wall.Visible then return nil end
        local r = rectOf(handle, wall.Part.CFrame, wall.Part.Size)
        if not r then return nil end
        local _, _, depth = handle:Project(wall.Part.CFrame.Position)
        r.depth = depth
        return r
    end

    local function region(v, x, y, w, h, W, H, on)
        x, y = Util.clamp(x, 0, W), Util.clamp(y, 0, H)
        w, h = Util.clamp(w, 0, W - x), Util.clamp(h, 0, H - y)
        local key = x .. ":" .. y .. ":" .. w .. ":" .. h .. ":" .. W .. ":" .. H .. ":" .. tostring(on)
        if v.key == key then return end
        v.key = key
        v.x, v.y, v.w, v.h = x, y, w, h
        v.clip.Visible = on and w > 0 and h > 0
        v.clip.Position, v.clip.Size = UDim2.fromOffset(x, y), UDim2.fromOffset(w, h)
        v.view.Position, v.view.Size = UDim2.fromOffset(-x, -y), UDim2.fromOffset(W, H)
    end

    function Chams:_clip(r)
        local W, H = self.Handle.Size.X, self.Handle.Size.Y
        local v = self.Views
        local x0, y0, x1, y1 = W, 0, W, 0
        if r then x0, y0, x1, y1 = r.x0, r.y0, r.x1, r.y1 end
        x0, x1 = Util.clamp(x0, 0, W), Util.clamp(x1, 0, W)
        y0, y1 = Util.clamp(y0, 0, H), Util.clamp(y1, 0, H)
        region(v.behind, x0, y0, x1 - x0, y1 - y0, W, H, self.Cfg.walls ~= false)
        region(v.left, 0, 0, x0, H, W, H, true)
        region(v.right, x1, 0, W - x1, H, W, H, true)
        region(v.top, x0, 0, x1 - x0, y0, W, H, true)
        region(v.bottom, x0, y1, x1 - x0, H - y1, W, H, true)
    end

    local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2)

    function Chams:Update()
        if self.Destroyed then return end
        local cfg = self.Cfg
        local wall = cfg.wall
        if self.Mode ~= "parts" then
            for _, slot in pairs(self.slots) do
                local occluded = wall ~= nil and wall:isOccluded(slot.part) or false
                slot.occluded = occluded
                slot.state = occluded and "occluded" or "visible"
                slot.cover = occluded and 1 or 0
                slot.layers.behind.Transparency, slot.layers.visible.Transparency = slot.behindT, slot.visT
                slot.layers.behind.Visible = occluded and cfg.walls ~= false
                slot.layers.visible.Visible = not occluded
            end
            return
        end
        if not self.Views then return end
        local handle = self.Handle
        self:_sync()
        local cover = self:Cover()
        local torso = self.slots.Torso
        if cover and torso then
            local _, _, depth = handle:Project(torso.part.CFrame.Position)
            if cover.depth >= depth then cover = nil end
        end
        self.Covered = cover
        self:_clip(cover)
        for _, slot in pairs(self.slots) do
            local cf = slot.part.CFrame
            if slot.round then cf = cf * UPRIGHT end
            if slot.cf ~= cf then
                slot.cf = cf
                slot.layers.behind.CFrame = cf
                for _, copy in ipairs(slot.copies) do copy.CFrame = cf end
            end
            local f = 0
            local r = cover and rectOf(handle, slot.part.CFrame, slot.part.Size)
            if r then
                local area = math.max(1, (r.x1 - r.x0) * (r.y1 - r.y0))
                local w = math.max(0, math.min(r.x1, cover.x1) - math.max(r.x0, cover.x0))
                local h = math.max(0, math.min(r.y1, cover.y1) - math.max(r.y0, cover.y0))
                f = Util.clamp(w * h / area, 0, 1)
            end
            slot.cover = f
            slot.state = f <= 0 and "visible" or (f >= 1 and "occluded" or "partial")
            slot.occluded = f >= 1
        end
    end

    function Chams:Set(cfg)
        local before = self.Cfg.round
        local wasOn = self.Cfg.enabled
        self:_merge(cfg)
        if before ~= self.Cfg.round or wasOn ~= self.Cfg.enabled or (cfg and cfg.material and self.Mode == "parts") then
            self:_rebuild()
            return self
        end
        for _, slot in pairs(self.slots) do self:_style(slot) end
        if self.Views then self.Views.behind.key = nil end
        self:Update()
        return self
    end

    function Chams:SetMode(mode)
        if mode ~= nil and mode ~= "adorn" and mode ~= "parts" then return false end
        self._force = mode
        self:_rebuild()
        return true
    end

    function Chams:Layers()
        local out = {}
        for name, slot in pairs(self.slots) do out[name] = { behind = slot.layers.behind, visible = slot.layers.visible, copies = slot.copies, state = slot.state, cover = slot.cover } end
        return out
    end

    function Chams:Count()
        local n = 0
        for _, slot in pairs(self.slots) do
            for _, layer in pairs(slot.layers) do
                if layer.Parent then n = n + 1 end
            end
        end
        return n
    end

    function Chams:Destroy()
        if self.Destroyed then return end
        self.Destroyed = true
        if self._loop then self._loop.Stop() end
        self:_drop()
    end

    local Esp = {}
    Esp.__index = Esp
    local ESP_COLORS = { boxColor = true, fillColor = true, low = true, mid = true, high = true, nameColor = true, skeletonColor = true, infoColor = true, tracerColor = true, weaponColor = true, distanceColor = true, flagColor = true }
    local ESP_DEFAULTS = {
        box = "full", boxColor = WHITE, boxThickness = 1, outline = true, fill = false, fillColor = nil, fillAlpha = 0.2,
        health = true, hp = 72, maxHp = 100, healthMode = "gradient", low = "#ff3c3c", mid = "#ffc83c", high = "#78e03c", healthNumber = true,
        healthSide = "left", barWidth = 2,
        name = "display", nameColor = WHITE, nameSize = nil, nameOutline = true,
        skeleton = false, skeletonColor = WHITE, skeletonThickness = 1, skeletonOutline = false, joints = false,
        weapon = "AK-47", weaponMode = "text", distance = true, distanceUnit = "studs", infoColor = WHITE,
        flags = {}, flagColors = false, tracer = false, tracerColor = WHITE,
    }
    local JOINT_KEYS = {}
    for key in pairs(JOINTS) do
        if key ~= "gun" then JOINT_KEYS[#JOINT_KEYS + 1] = key end
    end
    table.sort(JOINT_KEYS)
    local function px(v, default, lo, hi)
        return Util.clamp(math.floor((tonumber(v) or default) + 0.5), lo, hi)
    end
    local CORNERS = {}
    for _, sx in ipairs({ -0.5, 0.5 }) do
        for _, sy in ipairs({ -0.5, 0.5 }) do
            for _, sz in ipairs({ -0.5, 0.5 }) do CORNERS[#CORNERS + 1] = Vector3.new(sx, sy, sz) end
        end
    end

    local function label(parent, name, style, z)
        return Util.new("TextLabel", {
            Name = name, BackgroundTransparency = 1, ZIndex = z or 4, TextColor3 = WHITE, TextStrokeTransparency = 0.4, TextStrokeColor3 = BLACK,
            Size = UDim2.fromOffset(0, 0), TextStyle = style, Visible = false, Parent = parent,
        })
    end

    local function setText(l, text, style, x, y, align)
        local size = Text.size(text, style)
        local w, h = size.X, size.Y
        if align == "center" then x = x - w / 2 elseif align == "right" then x = x - w end
        l.Text = text
        placeRect(l, x, y, w, h)
        l.Visible = true
        return w, h
    end

    function Scene.Esp(handle, target, cfg)
        attach(handle)
        local model = modelOf(target)
        local esp = setmetatable({ Handle = handle, Model = model, Cfg = {}, _segs = {}, _bones = {}, _flags = {} }, Esp)
        for k, v in pairs(ESP_DEFAULTS) do esp.Cfg[k] = v end
        esp:_merge(cfg)
        local root = Util.new("Frame", { Name = "Esp", BackgroundTransparency = 1, ZIndex = 5, Size = UDim2.fromScale(1, 1), Parent = handle.Frame })
        esp.Root = root
        esp.Fill = line(root, "Fill", 1)
        for i = 1, 8 do
            esp._segs[i] = { out = line(root, "BoxOutline", 2), col = line(root, "Box", 3) }
            esp._segs[i].out.BackgroundColor3 = BLACK
        end
        esp.Box = esp._segs[1].col
        esp.BarBack = line(root, "BarBack", 2)
        esp.BarBack.BackgroundColor3 = BLACK
        esp.Bar = line(root, "Bar", 3)
        esp.BarGradient = Util.new("UIGradient", { Rotation = 90, Enabled = false, Parent = esp.Bar })
        esp.Hp = label(root, "Hp", "tiny")
        esp.Name = label(root, "Name", "body")
        esp.Info = { weapon = label(root, "Weapon", "tiny"), distance = label(root, "Distance", "tiny") }
        esp._boneOut, esp._joints = {}, {}
        for i = 1, #BONES do
            esp._boneOut[i] = line(root, "BoneOutline", 1)
            esp._boneOut[i].BackgroundColor3 = BLACK
            esp._bones[i] = line(root, "Bone", 2)
        end
        for _, key in ipairs(JOINT_KEYS) do
            esp._joints[key] = line(root, "Joint", 3)
            esp._joints[key].AnchorPoint = Vector2.new(0.5, 0.5)
        end
        esp.Tracer = line(root, "Tracer", 2)
        esp._loop = handle:Loop(function() esp:Update() end)
        handle.Maid:Add(esp)
        esp:Update()
        return esp
    end

    function Esp:_merge(cfg)
        for k, v in pairs(cfg or {}) do
            if ESP_COLORS[k] then self.Cfg[k] = color(v, self.Cfg[k]) else self.Cfg[k] = v end
        end
    end

    function Esp:Set(cfg)
        self:_merge(cfg)
        self:Update()
        return self
    end

    function Esp:Rect()
        local r = self._rect
        if not r then return nil end
        return r[1], r[2], r[3], r[4]
    end

    local function healthColor(cfg, frac)
        local low, mid, high = color(cfg.low, WHITE), color(cfg.mid, WHITE), color(cfg.high, WHITE)
        if frac < 0.5 then return low:Lerp(mid, frac * 2) end
        return mid:Lerp(high, (frac - 0.5) * 2)
    end

    function Esp:_name()
        local cfg = self.Cfg
        if cfg.name == "user" then
            if cfg.user then return tostring(cfg.user) end
            local ok, n = pcall(function() return LocalPlayer.Name end)
            return ok and n and tostring(n) or "dummy"
        end
        if cfg.display then return tostring(cfg.display) end
        local ok, n = pcall(function() return LocalPlayer.DisplayName or LocalPlayer.Name end)
        return ok and n and tostring(n) or "Dummy"
    end

    function Esp:Update()
        if self.Destroyed then return end
        local cfg, handle = self.Cfg, self.Handle
        local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
        for _, name in ipairs(R6) do
            local p = bodyPart(self.Model, name)
            if p then
                local cf, size = p.CFrame, SIZES[name]
                for _, c in ipairs(CORNERS) do
                    local x, y, depth = handle:Project(cf * (size * c))
                    if depth > 0 then
                        if x < minX then minX = x end
                        if y < minY then minY = y end
                        if x > maxX then maxX = x end
                        if y > maxY then maxY = y end
                    end
                end
            end
        end
        if minX == math.huge then
            self.Root.Visible = false
            self._rect = nil
            return
        end
        self.Root.Visible = true
        local x, y, w, h = minX, minY, math.max(2, maxX - minX), math.max(2, maxY - minY)
        self._rect = { x, y, w, h }

        self.Fill.Visible = cfg.box ~= false and cfg.fill == true
        if self.Fill.Visible then
            placeRect(self.Fill, x, y, w, h)
            self.Fill.BackgroundColor3 = cfg.fillColor or cfg.boxColor
            self.Fill.BackgroundTransparency = 1 - num(cfg.fillAlpha, 0.2)
        end
        local rects = {}
        local t = px(cfg.boxThickness, 1, 1, 6)
        if cfg.box == "corner" then
            local lx, ly = math.max(2 * t, Util.snap(w / 4)), math.max(2 * t, Util.snap(h / 5))
            rects = {
                { x, y, lx, t }, { x, y, t, ly }, { x + w - lx, y, lx, t }, { x + w - t, y, t, ly },
                { x, y + h - t, lx, t }, { x, y + h - ly, t, ly }, { x + w - lx, y + h - t, lx, t }, { x + w - t, y + h - ly, t, ly },
            }
        elseif cfg.box ~= false then
            rects = { { x, y, w, t }, { x, y + h - t, w, t }, { x, y, t, h }, { x + w - t, y, t, h } }
        end
        for i, seg in ipairs(self._segs) do
            local r = rects[i]
            seg.col.Visible = r ~= nil
            seg.out.Visible = r ~= nil and cfg.outline ~= false
            if r then
                placeRect(seg.col, r[1], r[2], r[3], r[4])
                seg.col.BackgroundColor3 = cfg.boxColor
                placeRect(seg.out, r[1] - 1, r[2] - 1, r[3] + 2, r[4] + 2)
            end
        end

        local hp, maxHp = num(cfg.hp, 100), math.max(num(cfg.maxHp, 100), 1)
        local frac = Util.clamp(hp / maxHp, 0, 1)
        local showBar = cfg.health ~= false
        self.BarBack.Visible, self.Bar.Visible = showBar, showBar
        self.Hp.Visible = false
        local bw = px(cfg.barWidth, 2, 1, 8)
        local right = cfg.healthSide == "right"
        local bx = right and x + w + 1 or x - bw - 3
        if showBar then
            placeRect(self.BarBack, bx, y - 1, bw + 2, h + 2)
            self.BarBack.BackgroundTransparency = 0.2
            local fh = Util.snap(h * frac)
            placeRect(self.Bar, bx + 1, y + h - fh, bw, fh)
            if cfg.healthMode == "solid" then
                self.BarGradient.Enabled = false
                self.Bar.BackgroundColor3 = healthColor(cfg, frac)
            else
                self.Bar.BackgroundColor3 = WHITE
                self.BarGradient.Enabled = true
                self.BarGradient.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, healthColor(cfg, frac)),
                    ColorSequenceKeypoint.new(1, color(cfg.low, WHITE)),
                })
            end
            if cfg.healthNumber ~= false and hp < maxHp then
                if right then
                    setText(self.Hp, tostring(math.floor(hp + 0.5)), "tiny", bx + bw + 3, y + h - fh - 5, "left")
                else
                    setText(self.Hp, tostring(math.floor(hp + 0.5)), "tiny", bx - 1, y + h - fh - 5, "right")
                end
            end
        end

        if cfg.name then
            local base = Text.Styles.body.size
            local size = px(cfg.nameSize, base, 6, 32)
            local text = self:_name()
            local tw, th = Text.size(text, "body").X, Text.size(text, "body").Y
            if size ~= base then tw, th = math.ceil(tw * size / base), math.ceil(th * size / base) end
            self.Name.Text = text
            self.Name.TextSize = size
            placeRect(self.Name, x + Util.snap((w - tw) / 2), y - th - 3, tw, th)
            self.Name.Visible = true
            self.Name.TextColor3 = cfg.nameColor
            self.Name.TextStrokeTransparency = cfg.nameOutline == false and 1 or 0.4
        else
            self.Name.Visible = false
        end

        local below = y + h + 2
        local weapon = self.Info.weapon
        local wcol = cfg.weaponColor or cfg.infoColor
        local icon = nil
        if cfg.weapon and cfg.weaponMode == "icon" then
            if self.WeaponIcon == nil then
                self.WeaponIcon = Icons.make(self.Root, "rifles", { Name = "WeaponIcon", ZIndex = 4, Visible = false }) or false
            end
            icon = self.WeaponIcon or nil
        end
        if icon then
            weapon.Visible = false
            local ih = 10
            local iw = math.max(1, Util.snap(ih * Icons.aspect("rifles")))
            placeRect(icon, x + Util.snap((w - iw) / 2), below, iw, ih)
            icon.Visible = true
            if icon:IsA("ImageLabel") then
                icon.ImageColor3 = wcol
            else
                for _, p in ipairs(icon:GetChildren()) do p.BackgroundColor3 = wcol end
            end
            below = below + ih + 1
        elseif cfg.weapon then
            local _, th = setText(weapon, tostring(cfg.weapon), "tiny", x + w / 2, below, "center")
            weapon.TextColor3 = wcol
            below = below + th
        else
            weapon.Visible = false
        end
        if self.WeaponIcon and not icon then self.WeaponIcon.Visible = false end
        local dist = self.Info.distance
        local torso = bodyPart(self.Model, "Torso")
        if cfg.distance ~= false and torso then
            local studs = (handle.Camera.CFrame.Position - torso.CFrame.Position).Magnitude
            local u = cfg.distanceUnit
            local text = (u == "meters" or u == "m" or u == "meter") and (tostring(math.floor(studs * 0.28 + 0.5)) .. "m") or (tostring(math.floor(studs + 0.5)) .. " studs")
            setText(dist, text, "tiny", x + w / 2, below, "center")
            dist.TextColor3 = cfg.distanceColor or cfg.infoColor
        else
            dist.Visible = false
        end

        local flags = type(cfg.flags) == "table" and cfg.flags or {}
        local fx = (right and showBar) and bx + bw + 4 or x + w + 3
        for i, text in ipairs(flags) do
            local l = self._flags[i]
            if not l then
                l = label(self.Root, "Flag", "tiny")
                self._flags[i] = l
            end
            setText(l, tostring(text), "tiny", fx, y + (i - 1) * 10, "left")
            local per = type(cfg.flagColors) == "table" and cfg.flagColors[text]
            l.TextColor3 = (per and color(per, nil)) or cfg.flagColor or cfg.infoColor
        end
        for i = #flags + 1, #self._flags do self._flags[i].Visible = false end

        local points = {}
        local st = px(cfg.skeletonThickness, 1, 1, 6)
        local so = cfg.skeleton == true and cfg.skeletonOutline == true
        if cfg.skeleton then
            for key, spec in pairs(JOINTS) do
                local p = bodyPart(self.Model, spec[1])
                if p then
                    local px, py, depth = handle:Project(p.CFrame * spec[2])
                    if depth > 0 then points[key] = { px, py } end
                end
            end
        end
        for i, bone in ipairs(BONES) do
            local f, a, b = self._bones[i], points[bone[1]], points[bone[2]]
            local o = self._boneOut[i]
            f.Visible = cfg.skeleton == true and a ~= nil and b ~= nil
            o.Visible = f.Visible and so
            if f.Visible then
                placeLine(f, a[1], a[2], b[1], b[2], st)
                f.BackgroundColor3 = cfg.skeletonColor
                if so then
                    placeLine(o, a[1], a[2], b[1], b[2], st + 2)
                    o.Size = UDim2.fromOffset(f.Size.X.Offset + 2, st + 2)
                end
            end
        end
        local js = st + 2
        for key, dot in pairs(self._joints) do
            local p = points[key]
            dot.Visible = cfg.skeleton == true and cfg.joints == true and p ~= nil
            if dot.Visible then
                dot.Position = UDim2.fromOffset(Util.snap(p[1]), Util.snap(p[2]))
                dot.Size = UDim2.fromOffset(js, js)
                dot.BackgroundColor3 = cfg.skeletonColor
            end
        end

        self.Tracer.Visible = cfg.tracer == true
        if cfg.tracer == true then
            placeLine(self.Tracer, handle.Size.X / 2, handle.Size.Y, x + w / 2, y + h)
            self.Tracer.BackgroundColor3 = cfg.tracerColor
        end
    end

    function Esp:Destroy()
        if self.Destroyed then return end
        self.Destroyed = true
        if self._loop then self._loop.Stop() end
        pcall(function() self.Root:Destroy() end)
    end

    local Fx = {}
    Fx.__index = Fx

    local function newFx(handle)
        if not handle._fx then
            handle._fx = {}
            handle.Maid:Add(function()
                for fx in pairs(handle._fx) do fx:Stop() end
            end)
        end
        local fx = setmetatable({ Handle = handle, items = {}, tracks = {}, running = true }, Fx)
        handle._fx[fx] = true
        return fx
    end

    function Fx:Add(item)
        self.items[#self.items + 1] = item
        return item
    end

    function Fx:Run(seconds, step, done)
        local track = Anim.value(nil, 0, 1, seconds, function(k) step(k) end, done, Anim.linear)
        self.tracks[#self.tracks + 1] = track
        return track
    end

    function Fx:Running()
        return self.running
    end

    function Fx:Stop()
        if not self.running then return end
        self.running = false
        for _, track in ipairs(self.tracks) do pcall(function() track:Stop() end) end
        for _, item in ipairs(self.items) do pcall(function() item:Destroy() end) end
        self.items, self.tracks = {}, {}
        if self.Handle._fx then self.Handle._fx[self] = nil end
        if self._onStop then Util.guard(self._onStop) end
    end
    Fx.Destroy = Fx.Stop

    function Scene.Shoot(handle, dummy, opts)
        attach(handle)
        opts = opts or {}
        local fx = newFx(handle)
        local from = opts.from or (dummy and dummy:Point("gun")) or Vector3.new(0, 3, 0)
        local to = opts.to
        if not to then
            local look = Vector3.new(0, 0, -1)
            pcall(function() look = dummy.Parts.Torso.CFrame.LookVector end)
            to = from + look * 14
        end
        local tint = color(opts.color, Color3.fromRGB(255, 200, 90))
        local width = num(opts.width, 0.08)
        local style = opts.style or "line"
        local pieces = {}
        local function seg(a, b, w, col, base)
            local len = math.max((b - a).Magnitude, 0.01)
            local p = part({ Name = "Tracer", Size = Vector3.new(w, w, len), CFrame = CFrame.new((a + b) / 2, b), Color = col, Transparency = base, Material = Enum.Material.Neon, Parent = handle.World })
            fx:Add(p)
            pieces[#pieces + 1] = { part = p, base = base }
        end
        local puffs = {}
        if style == "beam" then
            seg(from, to, width, WHITE, 0)
            seg(from, to, width * 3, tint, 0.55)
        elseif style == "lightning" then
            local frame = CFrame.new(from, to)
            local n, last = 8, from
            for i = 1, n do
                local point = from:Lerp(to, i / n)
                if i < n then point = point + frame.RightVector * (math.random() - 0.5) * 0.7 + frame.UpVector * (math.random() - 0.5) * 0.7 end
                seg(last, point, width, tint, 0)
                last = point
            end
        elseif style == "smoke" then
            seg(from, to, width * 0.6, tint, 0.3)
            for i = 1, 10 do
                local p = part({ Name = "Puff", Shape = Enum.PartType.Ball, Size = Vector3.new(0.25, 0.25, 0.25), CFrame = CFrame.new(from:Lerp(to, i / 10)), Color = Color3.fromRGB(190, 190, 196), Transparency = 0.4, Parent = handle.World })
                fx:Add(p)
                puffs[#puffs + 1] = { part = p, at = from:Lerp(to, i / 10) }
            end
        else
            seg(from, to, width, tint, 0)
        end
        local sparks = {}
        if opts.sparks ~= false then
            for _ = 1, 8 do
                local dir = Vector3.new(math.random() - 0.5, math.random() * 0.8, math.random() - 0.5).Unit
                local p = part({ Name = "Spark", Size = Vector3.new(0.12, 0.12, 0.12), CFrame = CFrame.new(to), Color = tint, Material = Enum.Material.Neon, Parent = handle.World })
                fx:Add(p)
                sparks[#sparks + 1] = { part = p, dir = dir }
            end
        end
        fx:Run(num(opts.life, 0.6), function(k)
            for _, piece in ipairs(pieces) do piece.part.Transparency = lerp(piece.base, 1, k) end
            for _, puff in ipairs(puffs) do
                local s = lerp(0.25, 0.9, k)
                puff.part.Size = Vector3.new(s, s, s)
                puff.part.CFrame = CFrame.new(puff.at + Vector3.new(0, k * 0.6, 0))
                puff.part.Transparency = lerp(0.4, 1, k)
            end
            for _, spark in ipairs(sparks) do
                spark.part.CFrame = CFrame.new(to + spark.dir * (k * 1.5) - Vector3.new(0, k * k * 1.2, 0))
                spark.part.Transparency = k
            end
        end, function() fx:Stop() end)
        return fx
    end

    function Scene.Hit(handle, dummy, opts)
        attach(handle)
        opts = opts or {}
        local fx = newFx(handle)
        local target = dummy.Parts[opts.part or "Head"] or dummy.Parts.Torso
        local mark = color(opts.markerColor, WHITE)
        local layer = fx:Add(Util.new("Frame", { Name = "HitFx", BackgroundTransparency = 1, ZIndex = 6, Size = UDim2.fromScale(1, 1), Parent = handle.Frame }))
        local lines = {}
        for i = 1, 4 do
            lines[i] = line(layer, "Marker", 2)
            lines[i].BackgroundColor3 = mark
        end
        local number = label(layer, "Damage", "body", 3)
        number.Text = tostring(opts.damage or 34)
        number.TextColor3 = color(opts.color, Color3.fromRGB(255, 90, 90))
        local flashes = {}
        if opts.flash ~= false then
            for _, name in ipairs(R6) do
                local p = dummy.Parts[name]
                if p then
                    local f = part({ Name = "HitFlash", Size = SIZES[name] + Vector3.new(0.08, 0.08, 0.08), CFrame = p.CFrame, Color = color(opts.color, Color3.fromRGB(255, 90, 90)), Material = Enum.Material.Neon, Transparency = 0.3, Parent = handle.World })
                    fx:Add(f)
                    flashes[#flashes + 1] = { part = f, body = p }
                end
            end
        end
        local DIAG = { { 1, 1 }, { -1, 1 }, { -1, -1 }, { 1, -1 } }
        fx:Run(num(opts.life, 0.8), function(k)
            local px, py, depth = handle:Project(target.CFrame.Position)
            layer.Visible = depth > 0
            for i, d in ipairs(DIAG) do
                local a, b = 3 * 0.7071, 9 * 0.7071
                placeLine(lines[i], px + d[1] * a, py + d[2] * a, px + d[1] * b, py + d[2] * b)
                lines[i].BackgroundTransparency = k * k
            end
            setText(number, number.Text, "body", px + 10, py - 12 - k * 14, "left")
            number.TextTransparency = k
            number.TextStrokeTransparency = lerp(0.4, 1, k)
            for _, f in ipairs(flashes) do
                f.part.CFrame = f.body.CFrame
                f.part.Transparency = lerp(0.3, 1, k)
            end
        end, function() fx:Stop() end)
        return fx
    end

    Scene.KillStyles = { "Melt", "Spaghettify", "Balloon", "Orbit", "Glass", "Magnetize", "Puppet", "Freeze", "Implode", "Vaporize" }
    local KILL_ALIAS = { ["time freeze"] = "Freeze", ["glass shatter"] = "Glass" }
    for _, name in ipairs(Scene.KillStyles) do KILL_ALIAS[string.lower(name)] = name end

    local function late(k, from)
        return math.max(0, (k - from) / (1 - from))
    end
    local function rotOf(cf)
        return cf - cf.Position
    end
    local ICE = Color3.fromRGB(160, 215, 255)

    local KILLS = {
        Melt = function(items, ctx)
            return function(k)
                for _, it in ipairs(items) do
                    local s = Vector3.new(it.size.X * (1 + k * 0.6), it.size.Y * (1 - k * 0.85), it.size.Z * (1 + k * 0.6))
                    local y = lerp(it.cf.Y, ctx.ground + s.Y / 2, k)
                    it.part.Size = s
                    it.part.CFrame = it.cf + Vector3.new(0, y - it.cf.Y, 0)
                    it.part.Color = it.color:Lerp(ctx.tint, k)
                    it.part.Transparency = lerp(it.t, 1, late(k, 0.7))
                end
            end
        end,
        Spaghettify = function(items)
            return function(k)
                for _, it in ipairs(items) do
                    local s = Vector3.new(it.size.X * (1 - 0.8 * k), it.size.Y * (1 + 5 * k), it.size.Z * (1 - 0.8 * k))
                    it.part.Size = s
                    it.part.CFrame = it.cf + Vector3.new(0, k * k * 8 + (s.Y - it.size.Y) / 2, 0)
                    it.part.Transparency = lerp(it.t, 1, late(k, 0.6))
                end
            end
        end,
        Balloon = function(items, ctx)
            return function(k)
                for _, it in ipairs(items) do
                    it.part.Size = it.size * (1 + 1.4 * k)
                    it.part.CFrame = it.cf + Vector3.new(0, k * k * 7, 0)
                    it.part.Color = it.color:Lerp(ctx.tint, k)
                    it.part.Transparency = lerp(it.t, 1, late(k, 0.75))
                end
            end
        end,
        Orbit = function(items, ctx)
            return function(k)
                for _, it in ipairs(items) do
                    local angle = k * math.pi * 4 + it.i / it.n * math.pi * 2
                    local r = k * 3.5
                    local pos = ctx.center + Vector3.new(math.cos(angle) * r, it.cf.Y - ctx.center.Y + k * 2, math.sin(angle) * r)
                    it.part.CFrame = it.cf:Lerp(CFrame.new(pos) * CFrame.Angles(k * 6, angle, 0), math.min(1, k * 3))
                    it.part.Transparency = lerp(it.t, 1, late(k, 0.8))
                end
            end
        end,
        Glass = function(items)
            return function(k)
                for _, it in ipairs(items) do
                    it.part.Material = Enum.Material.Glass
                    it.part.Color = it.color:Lerp(ICE, 0.6)
                    local pos = it.cf.Position + it.dir * (k * 5) + Vector3.new(0, 3 * k - 9 * k * k, 0)
                    it.part.CFrame = CFrame.new(pos) * rotOf(it.cf) * CFrame.Angles(k * 5 * (it.i % 3 + 1), k * 3, 0)
                    it.part.Transparency = lerp(0.3, 1, k)
                end
            end
        end,
        Magnetize = function(items, ctx)
            local pole = ctx.center + Vector3.new(0, 3.5, 0)
            return function(k)
                for _, it in ipairs(items) do
                    local pos = it.cf.Position:Lerp(pole, k * k)
                    it.part.CFrame = CFrame.new(pos) * rotOf(it.cf) * CFrame.Angles(0, k * 4, 0)
                    it.part.Size = it.size * (1 - 0.6 * k)
                    it.part.Color = it.color:Lerp(ctx.tint, k)
                    it.part.Transparency = lerp(it.t, 1, late(k, 0.85))
                end
            end
        end,
        Puppet = function(items)
            return function(k)
                local lift = math.sin(k * math.pi) * 2
                local slack = late(k, 0.75)
                for _, it in ipairs(items) do
                    local flail = CFrame.Angles(math.sin(k * 20 + it.i) * 0.8 * k, 0, math.cos(k * 16 + it.i) * 0.6 * k)
                    it.part.CFrame = it.cf * flail + Vector3.new(0, lift - slack * 2.5, 0)
                end
            end
        end,
        Freeze = function(items)
            return function(k)
                for _, it in ipairs(items) do
                    it.part.Material = Enum.Material.Ice
                    it.part.Color = it.color:Lerp(ICE, math.min(1, k * 2))
                    it.part.Size = it.size * (1 + 0.08 * k)
                    it.part.Transparency = lerp(it.t, 0.2, k)
                end
            end
        end,
        Implode = function(items, ctx)
            return function(k)
                for _, it in ipairs(items) do
                    local e = k * k
                    it.part.CFrame = CFrame.new(it.cf.Position:Lerp(ctx.center, e)) * rotOf(it.cf) * CFrame.Angles(0, k * 8, k * 4)
                    it.part.Size = it.size * math.max(0.02, 1 - e)
                end
            end
        end,
        Vaporize = function(items, ctx)
            return function(k)
                for _, it in ipairs(items) do
                    it.part.Material = Enum.Material.Neon
                    it.part.Color = it.color:Lerp(ctx.tint, math.min(1, k * 3))
                    it.part.CFrame = it.cf + Vector3.new(math.sin(it.i * 7 + k * 9) * 0.3 * k, k * 3, 0)
                    it.part.Size = it.size * (1 - 0.7 * k)
                    it.part.Transparency = lerp(it.t, 1, k)
                end
            end
        end,
    }
    Scene._kills = KILLS

    function Scene.Kill(handle, dummy, style, opts)
        attach(handle)
        opts = opts or {}
        style = KILL_ALIAS[string.lower(tostring(style or "Melt"))] or "Melt"
        if dummy._kill then dummy._kill:Stop() end
        local fx = newFx(handle)
        fx.Style = style
        dummy._kill = fx
        dummy:Pause(true)
        local items = {}
        local center = dummy.Parts.Torso.CFrame.Position
        local function add(p)
            local ok, it = pcall(function()
                return { part = p, cf = p.CFrame, size = p.Size, t = p.Transparency, color = p.Color }
            end)
            if not ok then return end
            local away = it.cf.Position - center
            it.dir = away.Magnitude > 0.05 and away.Unit or Vector3.new(0, 1, 0)
            items[#items + 1] = it
        end
        for _, name in ipairs(R6) do
            if dummy.Parts[name] then add(dummy.Parts[name]) end
        end
        for _, f in ipairs(dummy._followers) do add(f.part) end
        for i, it in ipairs(items) do it.i, it.n = i, #items end
        local ctx = { center = center, ground = center.Y - 3, tint = color(opts.color, Color3.fromRGB(255, 120, 60)) }
        local step = KILLS[style](items, ctx)
        fx._onStop = function()
            if dummy._kill == fx then dummy._kill = nil end
            if dummy.Destroyed then return end
            dummy:Reset()
            dummy:Pause(false)
        end
        fx:Run(num(opts.time, 1.2), step, function()
            fx.tracks[#fx.tracks + 1] = Anim.after(num(opts.hold, 0.6), function() fx:Stop() end)
        end)
        return fx
    end

    Scene.Atmospheres = {
        Default = { ambient = "#a0a0a8", light = "#ffffff", lightDir = Vector3.new(-1, -1, -1), skyTop = "#2c3444", skyBottom = "#6a7486", fogColor = "#c0c8d4", density = 0, haze = 0 },
        Day = { ambient = "#b4b4b4", light = "#fff4e0", lightDir = Vector3.new(-0.6, -1, -0.4), skyTop = "#4a8cdc", skyBottom = "#bcdcf4", fogColor = "#d8e6f4", density = 0.15, haze = 0.3 },
        Dusk = { ambient = "#8a6a6a", light = "#ffb070", lightDir = Vector3.new(-1, -0.3, -0.2), skyTop = "#2a2a5a", skyBottom = "#f08c50", fogColor = "#e09070", density = 0.25, haze = 0.6 },
        Night = { ambient = "#40485c", light = "#8090c0", lightDir = Vector3.new(0.3, -1, 0.5), skyTop = "#05060c", skyBottom = "#1a2238", fogColor = "#101828", density = 0.3, haze = 0.4 },
        Fog = { ambient = "#a8a8a8", light = "#e0e0e0", lightDir = Vector3.new(-1, -1, -1), skyTop = "#9aa0a8", skyBottom = "#c8ccd0", fogColor = "#c8ccd0", density = 0.7, haze = 0.8 },
        Neon = { ambient = "#7040a0", light = "#ff40c0", lightDir = Vector3.new(-1, -1, -1), skyTop = "#100020", skyBottom = "#401060", fogColor = "#ff40c0", density = 0.2, haze = 0.5 },
    }
    local Atm = {}
    Atm.__index = Atm

    function Scene.Atmosphere(handle, preset)
        attach(handle)
        local view = handle.Viewport
        local atm = setmetatable({ Handle = handle }, Atm)
        pcall(function() atm._orig = { view.Ambient, view.LightColor, view.LightDirection } end)
        atm.Sky = Util.new("Frame", { Name = "Sky", ZIndex = 0, BackgroundColor3 = WHITE, Size = UDim2.fromScale(1, 1), Parent = handle.Frame })
        atm.SkyGradient = Util.new("UIGradient", { Rotation = 90, Parent = atm.Sky })
        atm.Fog = Util.new("Frame", { Name = "Fog", ZIndex = 3, BackgroundColor3 = WHITE, Size = UDim2.fromScale(1, 1), Parent = handle.Frame })
        atm.FogGradient = Util.new("UIGradient", { Rotation = 90, Parent = atm.Fog })
        handle.Maid:Add(atm)
        atm:Set(preset)
        return atm
    end

    function Atm:Set(preset)
        local values = {}
        for k, v in pairs(Scene.Atmospheres.Default) do values[k] = v end
        if type(preset) == "string" then preset = Scene.Atmospheres[preset] end
        for k, v in pairs(type(preset) == "table" and preset or {}) do values[k] = v end
        self.Values = values
        local view = self.Handle.Viewport
        pcall(function()
            view.Ambient = color(values.ambient, WHITE)
            view.LightColor = color(values.light, WHITE)
            view.LightDirection = values.lightDir
        end)
        self.SkyGradient.Color = ColorSequence.new(color(values.skyTop, BLACK), color(values.skyBottom, BLACK))
        local density = Util.clamp(num(values.density, 0), 0, 1)
        local haze = Util.clamp(num(values.haze, 0), 0, 1)
        local bottom = density * 0.85
        local top = bottom * (1 - haze)
        self.Fog.Visible = density > 0
        self.Fog.BackgroundColor3 = color(values.fogColor, WHITE)
        self.FogGradient.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1 - top), NumberSequenceKeypoint.new(1, 1 - bottom) })
        self.FogTop, self.FogBottom = top, bottom
        return self
    end

    function Atm:Destroy()
        if self.Destroyed then return end
        self.Destroyed = true
        local view, orig = self.Handle.Viewport, self._orig
        if orig then
            pcall(function() view.Ambient, view.LightColor, view.LightDirection = orig[1], orig[2], orig[3] end)
        end
        pcall(function() self.Sky:Destroy() end)
        pcall(function() self.Fog:Destroy() end)
    end
end

-- [src] 60_hud.lua
do
    local Hud = { Booting = false, Entered = false }
    Aster.Hud = Hud
    local H = {}
    Hud._ = H

    local KEYS = { "wm", "kb", "sp", "tg" }
    local CORNERS = { ["top left"] = true, ["top right"] = true, ["bottom left"] = true, ["bottom right"] = true }
    local KIND = { hit = "accent", kill = "accent", death = "bad", warn = "warn", ok = "ok", info = "mute" }
    local ROW, HEAD, PANELW = 18, 24, 176

    local function readSaved()
        return Store.get("hud", {}, function(v)
            if type(v) ~= "table" then return nil end
            local out = {}
            for _, key in ipairs(KEYS) do
                local pair = Store.fix.pair(v[key])
                if pair then out[key] = { Util.snap(pair[1]), Util.snap(pair[2]) } end
            end
            return out
        end)
    end
    H.saved = readSaved()

    function H.save()
        Store.put("hud", H.saved)
    end

    function H.viewport()
        local ok, size = pcall(function() return Aster.Gui.Hud.AbsoluteSize end)
        if ok and size and size.X > 0 then return size.X, size.Y end
        return 1920, 1080
    end

    function H.menuOpen()
        local win = Aster._window
        return win ~= nil and not win.Destroyed and win.Visible == true
    end

    function H.label(parent, props, style, token)
        props.TextStyle = style or "body"
        props.Theme = props.Theme or { TextColor3 = token or "tx" }
        props.Parent = parent
        if props.TextXAlignment == nil then props.TextXAlignment = Enum.TextXAlignment.Left end
        return Util.new("TextLabel", props)
    end

    function H.ring(body)
        local white = Color3.new(1, 1, 1)
        local sides = {
            { UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 1) }, { UDim2.new(0, 0, 1, -1), UDim2.new(1, 0, 0, 1) },
            { UDim2.fromOffset(0, 0), UDim2.new(0, 1, 1, 0) }, { UDim2.new(1, -1, 0, 0), UDim2.new(0, 1, 1, 0) },
        }
        for index, side in ipairs(sides) do
            Util.new("Frame", { Name = "Ring" .. index, BackgroundColor3 = white, BackgroundTransparency = 0.955, ZIndex = 2, Position = side[1], Size = side[2], Parent = body })
        end
    end

    function H.card(parent, name, w, h, opts)
        opts = opts or {}
        local root = Util.new("CanvasGroup", {
            Name = name, BorderSizePixel = 0, Size = UDim2.fromOffset(w, h), GroupTransparency = 0,
            Theme = { BackgroundColor3 = "edge" }, Parent = parent,
        })
        local body = Util.new("Frame", { Name = "Body", Position = UDim2.fromOffset(1, 1), Size = UDim2.new(1, -2, 1, -2), Theme = { BackgroundColor3 = "panel" }, Parent = root })
        if opts.gradient then Theme.fill(body, "panel", "panel2") end
        H.ring(body)
        if opts.accent ~= false then
            Util.new("Frame", { Name = "Accent", ZIndex = 5, Size = UDim2.new(1, 0, 0, 1), Theme = { BackgroundColor3 = "accent" }, Parent = body })
        end
        return root, body
    end

    function H.logo(parent, size, token)
        local box = Util.new("Frame", { Name = "Logo", BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size), Parent = parent })
        local r = size / 2
        local seen = {}
        local a, b, turn = 0.44 * size, 0.18 * size, math.rad(-20)
        local dot = size >= 16 and 2 or 1
        local count = math.max(16, size * 3)
        for index = 0, count - 1 do
            local t = index / count * math.pi * 2
            local ex, ey = a * math.cos(t), b * math.sin(t)
            local x = Util.snap(r + ex * math.cos(turn) - ey * math.sin(turn) - dot / 2)
            local y = Util.snap(r + ex * math.sin(turn) + ey * math.cos(turn) - dot / 2)
            local key = x .. ":" .. y
            if not seen[key] then
                seen[key] = true
                Util.new("Frame", { Name = "Orbit", Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(dot, dot), Theme = { BackgroundColor3 = token or "accent" }, Parent = box })
            end
        end
        for row = 0, size - 1 do
            local dy = math.abs(row + 0.5 - r) / r
            local half = r * (1 - dy ^ (2 / 3)) ^ 1.5
            local width = Util.snap(half * 2)
            if width < 1 and dy < 1 then width = 1 end
            if width >= 1 then
                Util.new("Frame", {
                    Name = "Star", ZIndex = 2, Position = UDim2.fromOffset(Util.snap(r - width / 2), row), Size = UDim2.fromOffset(width, 1),
                    Theme = { BackgroundColor3 = token or "accent" }, Parent = box,
                })
            end
        end
        return box
    end
    Hud.Logo = H.logo

    function H.clamp(w, h, x, y)
        local vw, vh = H.viewport()
        return Util.snap(Util.clamp(x, 8, vw - 8 - w)), Util.snap(Util.clamp(y, 8, vh - 8 - h))
    end

    function H.put(widget, glide)
        if not widget.Root or widget.Dragging then return end
        local x, y = widget:_spot()
        x, y = H.clamp(widget.W, widget.H, x, y)
        widget.X, widget.Y = x, y
        local goal = UDim2.fromOffset(x, y)
        if glide and widget.Root.Visible and widget.Placed then
            Anim.to(widget.Root, { Position = goal }, "move")
        else
            Anim.stop(widget.Root, "Position")
            widget.Root.Position = goal
        end
        widget.Placed = true
        if widget.Moved then widget:Moved(glide) end
    end

    function H.resize(widget, w, h, glide)
        widget.W, widget.H = w, h
        local goal = UDim2.fromOffset(w, h)
        if glide and widget.Root.Visible and widget.Placed then
            Anim.to(widget.Root, { Size = goal }, "move")
        else
            Anim.stop(widget.Root, "Size")
            widget.Root.Size = goal
        end
    end

    function H.drag(widget)
        local root = widget.Root
        Aster._maid:Add(root.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 or not H.menuOpen() or Hud.Booting then return end
            local m0 = Input.mouse()
            local x0, y0 = widget.X or 0, widget.Y or 0
            Anim.stop(root, "Position")
            widget.Dragging = true
            local follow = Anim.follow(Vector2.new(x0, y0), function(v)
                root.Position = UDim2.fromOffset(Util.snap(v.X), Util.snap(v.Y))
                if widget.Moved then widget:Moved(false, v) end
            end)
            Input.capture(function(pos)
                local x, y = H.clamp(widget.W, widget.H, x0 + pos.X - m0.X, y0 + pos.Y - m0.Y)
                widget.X, widget.Y = x, y
                follow.Set(Vector2.new(x, y))
            end, function()
                widget.Dragging = false
                H.saved[widget.Key] = { widget.X, widget.Y }
                H.save()
                if widget.Dropped then widget:Dropped() end
                Anim.loop(function()
                    if follow.Settled() or widget.Dragging then
                        follow:Stop()
                        if not widget.Dragging then
                            root.Position = UDim2.fromOffset(widget.X, widget.Y)
                            if widget.Moved then widget:Moved(false) end
                        end
                        return false
                    end
                    return true
                end)
            end)
        end))
    end

    function H.active(on)
        for _, widget in ipairs(H.widgets or {}) do
            if widget.Root then widget.Root.Active = on end
        end
    end

    function H.short(key)
        local map = { leftshift = "lshift", rightshift = "rshift", leftcontrol = "lctrl", rightcontrol = "rctrl", leftalt = "lalt", rightalt = "ralt", capslock = "caps", backspace = "back", insert = "ins", delete = "del", pageup = "pgup", pagedown = "pgdn" }
        key = string.lower(tostring(key or ""))
        return map[key] or key
    end

    function H.fade(obj, from, to, kind, done)
        if from ~= nil then obj.GroupTransparency = from end
        return Anim.to(obj, { GroupTransparency = to }, kind or "fade", done)
    end

    local Watermark = {
        Key = "wm", Enabled = true, Corner = "top left", W = 0, H = 20, Title = "aster", User = "", Game = "",
        On = { logo = true, user = true, game = true, fps = true, ping = true, time = true },
        Order = { "logo", "user", "game", "fps", "ping", "time" }, Segs = {}, Values = { fps = "0", ping = "0", time = "00:00" },
    }
    Hud.Watermark = Watermark
    local SEPW = 6 + Text.width("|", "body") + 6

    do
        local root, body = H.card(Aster.Gui.Hud, "Watermark", 40, 20)
        Watermark.Root, Watermark.Body = root, body
        local ok, display = pcall(function() return LocalPlayer.DisplayName or LocalPlayer.Name end)
        Watermark.User = ok and display and tostring(display) or ""
        local named, name = pcall(function() return game.Name end)
        Watermark.Game = named and type(name) == "string" and name ~= "Game" and name or ""

        local function seg(key)
            local frame = Util.new("CanvasGroup", {
                Name = "Seg_" .. key, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 3, Visible = false,
                Size = UDim2.fromOffset(0, 18), Parent = body,
            })
            local s = { Key = key, Frame = frame, Parts = {}, Shown = false }
            s.Sep = H.label(frame, { Name = "Sep", Text = "|", TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromOffset(SEPW, 18) }, "body", "ln3")
            Watermark.Segs[key] = s
            return s
        end
        local function text(s, name, token, value, slot)
            local labelObj = H.label(s.Frame, { Name = name, Text = "" }, "body", token)
            s.Parts[#s.Parts + 1] = { obj = labelObj, value = value, slot = slot, gap = 4 }
            return labelObj
        end
        local logoSeg = seg("logo")
        logoSeg.Parts[1] = { obj = H.logo(logoSeg.Frame, 11), width = 11, y = 3, gap = 4 }
        text(logoSeg, "Title", "accent", function() return Watermark.Title end)
        text(seg("user"), "User", "tx", function() return Watermark.User end)
        text(seg("game"), "Game", "tx", function() return Watermark.Game end)
        local fps = seg("fps")
        text(fps, "N", "tx", function() return Watermark.Values.fps end, true)
        text(fps, "Unit", "tx3", function() return "fps" end)
        local ping = seg("ping")
        text(ping, "N", "tx", function() return Watermark.Values.ping end, true)
        text(ping, "Unit", "tx3", function() return "ms" end)
        text(seg("time"), "Clock", "tx", function() return Watermark.Values.time end)
    end

    function Watermark._measure(s, first)
        local x = first and 0 or SEPW
        s.Sep.Visible = not first
        local count = #s.Parts
        for index, part in ipairs(s.Parts) do
            local w = part.width
            if part.value then
                local value = tostring(part.value())
                if part.obj.Text ~= value then part.obj.Text = value end
                w = Text.width(value, "body")
                if part.slot then
                    w = math.max(Text.width("000", "body"), w)
                    part.obj.TextXAlignment = Enum.TextXAlignment.Right
                end
                part.obj.Size = UDim2.fromOffset(w, 18)
            end
            part.obj.Position = UDim2.fromOffset(x, part.y or 0)
            x = x + w
            if index < count then x = x + (part.gap or 0) end
        end
        s.Frame.Size = UDim2.fromOffset(x, 18)
        return x
    end

    function Watermark:_layout(glide)
        local x, first = 6, true
        for _, key in ipairs(self.Order) do
            local s = self.Segs[key]
            if self.On[key] then
                local w = self._measure(s, first)
                local goal = UDim2.fromOffset(x, 0)
                if not s.Shown then
                    s.Shown = true
                    s.Frame.Visible = true
                    Anim.stop(s.Frame, "Position")
                    s.Frame.Position = goal
                    if glide then H.fade(s.Frame, 1, 0, "move") else Anim.stop(s.Frame, "GroupTransparency") s.Frame.GroupTransparency = 0 end
                elseif glide then
                    Anim.to(s.Frame, { Position = goal }, "move")
                    if Anim.running(s.Frame, "GroupTransparency") then H.fade(s.Frame, nil, 0, "move") end
                else
                    Anim.stop(s.Frame, "Position")
                    s.Frame.Position = goal
                end
                x = x + w
                first = false
            elseif s.Shown then
                s.Shown = false
                if glide then
                    H.fade(s.Frame, nil, 1, "move", function() if not s.Shown then s.Frame.Visible = false end end)
                else
                    s.Frame.Visible = false
                end
            end
        end
        H.resize(self, x + 6 + 2, 20, glide)
        H.put(self, glide)
    end

    function Watermark:_spot()
        if self.Corner == "custom" and H.saved.wm then return H.saved.wm[1], H.saved.wm[2] end
        local vw, vh = H.viewport()
        local corner = CORNERS[self.Corner] and self.Corner or "top left"
        local x = string.find(corner, "right") and vw - 8 - self.W or 8
        local y = string.find(corner, "bottom") and vh - 8 - self.H or 8
        return x, y
    end

    function Watermark:Moved(glide, live)
        if live then self.LiveX, self.LiveY = live.X, live.Y else self.LiveX, self.LiveY = nil, nil end
        if H.toasts then H.toasts(glide) end
    end

    function Watermark:Dropped()
        self.Corner = "custom"
    end

    function Watermark:SetEnabled(on)
        on = on ~= false
        if self.Enabled == on then return end
        self.Enabled = on
        self.Root.Visible = on
        if on then
            self:_layout(false)
            self:_enter(0)
        end
        if H.toasts then H.toasts(true) end
    end

    function Watermark:SetPosition(corner)
        if corner == "custom" then
            if not H.saved.wm then H.saved.wm = { self.X or 8, self.Y or 8 } end
        elseif CORNERS[corner] then
            H.saved.wm = nil
        else
            return false
        end
        self.Corner = corner
        H.save()
        H.put(self, true)
        return true
    end

    function Watermark:SetSegments(list)
        local on = {}
        if type(list) == "table" then
            for key, value in pairs(list) do
                if type(key) == "number" then on[tostring(value)] = true elseif value then on[key] = true end
            end
        end
        for _, key in ipairs(self.Order) do self.On[key] = on[key] == true end
        self:_layout(true)
    end

    function Watermark:SetSegment(key, on)
        if self.Segs[key] == nil then return false end
        self.On[key] = on ~= false
        self:_layout(true)
        return true
    end

    function Watermark:SetTitle(s)
        self.Title = tostring(s or "")
        self:_layout(true)
    end

    function Watermark:SetUser(s)
        self.User = tostring(s or "")
        self:_layout(true)
    end

    function Watermark:SetGame(s)
        self.Game = tostring(s or "")
        self:_layout(true)
    end

    function Watermark:_enter(delay)
        if not self.Enabled then return end
        local root = self.Root
        local y = self.Y or 8
        local function go()
            Anim.stop(root, "Position")
            root.Position = UDim2.fromOffset(self.X or 8, y - 6)
            root.GroupTransparency = 1
            Anim.to(root, { Position = UDim2.fromOffset(self.X or 8, y), GroupTransparency = 0 }, "move")
        end
        if delay and delay > 0 and not Anim.calm then
            root.GroupTransparency = 1
            Anim.after(delay, go)
        else
            go()
        end
    end

    function Watermark:_tick(values)
        local changed = false
        for key, value in pairs(values) do
            if self.Values[key] ~= value then
                local old = Text.width(self.Values[key], "body")
                self.Values[key] = value
                if math.max(old, Text.width("000", "body")) ~= math.max(Text.width(value, "body"), Text.width("000", "body")) then changed = true end
            end
        end
        if changed then
            self:_layout(true)
        else
            for _, key in ipairs({ "fps", "ping", "time" }) do
                local s = self.Segs[key]
                local part = s.Parts[1]
                local value = tostring(part.value())
                if part.obj.Text ~= value then part.obj.Text = value end
            end
        end
    end

    local function listPanel(key, title, nameToken)
        local p = { Key = key, Title = title, Enabled = true, HideEmpty = false, W = PANELW, H = 0, Sig = nil, Items = {}, NameToken = nameToken }
        p.Root, p.Body = H.card(Aster.Gui.Hud, title:sub(1, 1):upper() .. title:sub(2), PANELW, 50, { gradient = true })
        H.label(p.Body, { Name = "Title", Text = title, Position = UDim2.fromOffset(8, 2), Size = UDim2.new(1, -16, 0, HEAD - 2) }, "bold", "tx")
        Util.new("Frame", { Name = "Line", ZIndex = 3, Position = UDim2.fromOffset(0, HEAD), Size = UDim2.new(1, 0, 0, 1), Theme = { BackgroundColor3 = "edge" }, Parent = p.Body })
        Util.new("Frame", { Name = "Hl", ZIndex = 3, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.975, Position = UDim2.fromOffset(0, HEAD + 1), Size = UDim2.new(1, 0, 0, 1), Parent = p.Body })
        p.Rows = Util.new("Frame", { Name = "Rows", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, HEAD + 3), Size = UDim2.new(1, 0, 1, -(HEAD + 3)), Parent = p.Body })
        return p
    end

    function H.rows(p, items, glide)
        local parts = {}
        for _, item in ipairs(items) do
            parts[#parts + 1] = table.concat({ tostring(item.name), tostring(item.chip or ""), tostring(item.mode or ""), item.active and "1" or "0" }, "\1")
        end
        local sig = table.concat(parts, "\2") .. "|" .. tostring(p.Enabled) .. tostring(p.HideEmpty)
        if sig == p.Sig then return false end
        p.Sig = sig
        p.Items = items
        for _, child in ipairs(p.Rows:GetChildren()) do child:Destroy() end
        local inner = p.W - 2
        local list = #items > 0 and items or { { name = "none", none = true } }
        for index, item in ipairs(list) do
            local row = Util.new("Frame", { Name = "Row" .. index, BackgroundTransparency = 1, Position = UDim2.fromOffset(0, (index - 1) * ROW), Size = UDim2.new(1, 0, 0, ROW), Parent = p.Rows })
            local right = inner - 8
            if item.mode and item.mode ~= "" then
                local w = p.ModeW or Text.width(item.mode, "tiny")
                H.label(row, { Name = "Mode", Text = item.mode, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromOffset(right - w, 0), Size = UDim2.fromOffset(w, ROW) }, "tiny", "tx4")
                right = right - w - 6
            end
            if item.chip and item.chip ~= "" then
                local w = Text.width(item.chip, "tiny")
                H.label(row, { Name = "Chip", Text = item.chip, Position = UDim2.fromOffset(right - w, 0), Size = UDim2.fromOffset(w, ROW) }, "tiny", item.active and "accent" or "tx4")
                right = right - w - 6
            end
            local token = item.none and "tx4" or (item.active and "accent" or p.NameToken)
            H.label(row, { Name = "Name", Text = tostring(item.name), TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(8, 0), Size = UDim2.fromOffset(math.max(0, right - 8), ROW) }, "body", token)
        end
        local shown = p.Enabled and not (p.HideEmpty and #items == 0)
        local height = 2 + HEAD + 3 + #list * ROW + 4
        local was = p.Root.Visible
        p.Root.Visible = shown
        H.resize(p, p.W, height, glide and was)
        H.put(p, glide and was)
        if shown and not was and glide then H.fade(p.Root, 1, 0, "fade") end
        return true
    end

    local Keybinds = listPanel("kb", "keybinds", "tx3")
    Keybinds.ActiveOnly = false
    Keybinds.ModeW = 36
    Hud.Keybinds = Keybinds
    local Spectators = listPanel("sp", "spectators", "tx2")
    Spectators.List = {}
    Hud.Spectators = Spectators

    function Keybinds:_spot()
        if H.saved.kb then return H.saved.kb[1], H.saved.kb[2] end
        local _, vh = H.viewport()
        return 8, Util.snap(vh * 0.39)
    end

    function Keybinds:Moved(glide, live)
        if H.saved.sp then return end
        if live then
            local x, y = H.clamp(Spectators.W, Spectators.H, live.X, live.Y + self.H + 8)
            Anim.stop(Spectators.Root, "Position")
            Spectators.X, Spectators.Y = x, y
            Spectators.Root.Position = UDim2.fromOffset(x, y)
        else
            H.put(Spectators, glide)
        end
    end

    function Spectators:_spot()
        if H.saved.sp then return H.saved.sp[1], H.saved.sp[2] end
        if Keybinds.Root.Visible and Keybinds.X then return Keybinds.X, Keybinds.Y + Keybinds.H + 8 end
        return Keybinds:_spot()
    end

    function Keybinds:Collect()
        local items = {}
        local kind = Kinds.keybind
        for _, el in ipairs(kind and kind.List or {}) do
            local value = el.Value
            if not el.Destroyed and type(value) == "table" and value.key and value.key ~= "" then
                local ok, active = pcall(el.Active, el)
                active = ok and active == true
                if active or not self.ActiveOnly then
                    local named, name = pcall(el.Name, el)
                    items[#items + 1] = { name = named and name or "keybind", chip = "[" .. H.short(value.key) .. "]", mode = value.mode, active = active, el = el }
                end
            end
        end
        return items
    end

    function Keybinds:Refresh(glide)
        return H.rows(self, self:Collect(), glide ~= false)
    end

    function Keybinds:SetEnabled(on)
        self.Enabled = on ~= false
        self:Refresh()
        H.put(Spectators, true)
    end

    function Keybinds:SetActiveOnly(on)
        self.ActiveOnly = on == true or on == "active" or on == "active only"
        self:Refresh()
    end

    function Keybinds:SetHideEmpty(on)
        self.HideEmpty = on ~= false
        self:Refresh()
        H.put(Spectators, true)
    end

    function Spectators:Set(list)
        local items = {}
        for _, entry in ipairs(type(list) == "table" and list or {}) do
            local name, mode
            if typeof(entry) == "Instance" then
                local ok, display = pcall(function() return entry.DisplayName end)
                name = ok and display or entry.Name
            elseif type(entry) == "table" then
                local who = entry.name or entry.Name or entry[1] or entry.player
                if typeof(who) == "Instance" then
                    local ok, display = pcall(function() return who.DisplayName end)
                    who = ok and display or who.Name
                end
                name, mode = who, entry.mode or entry.Mode or entry[2]
            else
                name = entry
            end
            if name ~= nil then items[#items + 1] = { name = tostring(name), mode = mode and tostring(mode) or nil } end
        end
        self.List = items
        return H.rows(self, items, true)
    end

    function Spectators:SetEnabled(on)
        self.Enabled = on ~= false
        self.Sig = nil
        H.rows(self, self.List, true)
    end

    function Spectators:SetHideEmpty(on)
        self.HideEmpty = on ~= false
        self.Sig = nil
        H.rows(self, self.List, true)
    end

    local Target = {
        Key = "tg", Enabled = true, Mode = "below crosshair", W = 220, H = 52, Shown = false, BarMode = "gradient",
        Show = { headshot = true, weapon = true, distance = true, visible = true, relation = true },
        Colors = { Util.hex("#ff3c3c"), Util.hex("#ffc83c"), Util.hex("#78e03c") }, Hp = 0, Count = 0, F = 1, Lag = 1,
    }
    Hud.Target = Target
    local BARW = 157

    do
        local root, body = H.card(Aster.Gui.Hud, "Target", Target.W, Target.H, { gradient = true })
        Target.Root, Target.Body = root, body
        root.Visible = false
        root.GroupTransparency = 1
        Target.Edge = Util.new("Frame", { Name = "Relation", ZIndex = 6, Visible = false, Position = UDim2.fromOffset(0, 1), Size = UDim2.new(0, 2, 1, -1), Theme = { BackgroundColor3 = "bad" }, Parent = body })
        local who = Util.new("CanvasGroup", { Name = "Who", BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 3, Size = UDim2.fromScale(1, 1), Parent = body })
        Target.Who = who
        Target.Pic = Util.new("Frame", { Name = "Pic", Position = UDim2.fromOffset(5, 5), Size = UDim2.fromOffset(40, 40), Parent = who })
        Theme.bind(Target.Pic, "BackgroundColor3", function(T) return Util.mix(Target.TeamColor or T.ln3, T.panel2, 0.72) end)
        Target.Shot = Util.new("ImageLabel", { Name = "Headshot", Size = UDim2.fromScale(1, 1), Image = "", Parent = Target.Pic })
        Target.Dot = Util.new("Frame", { Name = "Team", Position = UDim2.fromOffset(53, 10), Size = UDim2.fromOffset(5, 5), Parent = who })
        Theme.bind(Target.Dot, "BackgroundColor3", function(T) return Target.TeamColor or T.tx4 end)
        local unitW, numW = Text.width("hp", "tiny"), Text.width("000", "bold")
        local unitX = 212 - unitW
        local numX = unitX - 2 - numW
        Target.Name = H.label(who, { Name = "Name", Text = "", TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(63, 5), Size = UDim2.fromOffset(numX - 4 - 63, 15) }, "bold", "tx")
        Target.Num = H.label(who, { Name = "Hp", Text = "0", TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromOffset(numX, 5), Size = UDim2.fromOffset(numW, 15) }, "bold", "tx")
        H.label(who, { Name = "Unit", Text = "hp", Position = UDim2.fromOffset(unitX, 6), Size = UDim2.fromOffset(unitW, 15) }, "tiny", "tx4")
        Target.Info = H.label(who, { Name = "Info", Text = "", RichText = true, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(53, 20), Size = UDim2.fromOffset(BARW + 2, 14) }, "tiny", "tx3")
        local track = Util.new("Frame", { Name = "Bar", ZIndex = 3, Position = UDim2.fromOffset(53, 39), Size = UDim2.fromOffset(BARW + 2, 6), Theme = { BackgroundColor3 = "edge" }, Parent = body })
        local well = Util.new("Frame", { Name = "Well", ClipsDescendants = true, Position = UDim2.fromOffset(1, 1), Size = UDim2.fromOffset(BARW, 4), Theme = { BackgroundColor3 = "well" }, Parent = track })
        Target.Trail = Util.new("Frame", { Name = "Trail", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.72, Size = UDim2.fromOffset(BARW, 4), Parent = well })
        Target.Fill = Util.new("Frame", { Name = "Fill", BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 2, Size = UDim2.fromOffset(BARW, 4), Parent = well })
        Target.Grad = Util.new("Frame", { Name = "Colour", BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromOffset(BARW, 4), Parent = Target.Fill })
        Target.Gradient = Util.new("UIGradient", { Parent = Target.Grad })
        local lock = Util.new("CanvasGroup", { Name = "Lock", BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 10, GroupTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = root })
        Target.Lock = lock
        local edges = {
            { UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 1), 0 }, { UDim2.new(0, 0, 1, -1), UDim2.new(1, 0, 0, 1), 0 },
            { UDim2.fromOffset(0, 0), UDim2.new(0, 1, 1, 0), 0 }, { UDim2.new(1, -1, 0, 0), UDim2.new(0, 1, 1, 0), 0 },
            { UDim2.fromOffset(1, 1), UDim2.new(1, -2, 0, 1), 0.8 }, { UDim2.new(0, 1, 1, -2), UDim2.new(1, -2, 0, 1), 0.8 },
            { UDim2.fromOffset(1, 1), UDim2.new(0, 1, 1, -2), 0.8 }, { UDim2.new(1, -2, 0, 1), UDim2.new(0, 1, 1, -2), 0.8 },
        }
        for index, edge in ipairs(edges) do
            Util.new("Frame", { Name = "Edge" .. index, BackgroundTransparency = edge[3], Position = edge[1], Size = edge[2], Theme = { BackgroundColor3 = "accent" }, Parent = lock })
        end
    end

    function Target:_spot()
        if self.Mode == "custom" and H.saved.tg then return H.saved.tg[1], H.saved.tg[2] end
        local vw, vh = H.viewport()
        local x = (vw - self.W) / 2
        if self.Mode == "bottom centre" then return x, vh - self.H - 96 end
        return x, vh / 2 + 40
    end

    function Target:Dropped()
        self.Mode = "custom"
    end

    function Target:SetPosition(mode)
        if mode == "custom" then
            if not H.saved.tg then H.saved.tg = { self.X or 0, self.Y or 0 } end
        elseif mode == "below crosshair" or mode == "bottom centre" then
            H.saved.tg = nil
        else
            return false
        end
        self.Mode = mode
        H.save()
        H.put(self, true)
        return true
    end

    function H.hpColor(f)
        local c = Target.Colors
        if f < 0.33 then return c[1] end
        if f <= 0.66 then return c[2] end
        return c[3]
    end

    function Target:_paintBar(instant)
        local f = self.F
        local c = self.Colors
        if self.BarMode == "solid" then
            local only = H.hpColor(f)
            self.Gradient.Color = ColorSequence.new(only, only)
        else
            self.Gradient.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, c[1]), ColorSequenceKeypoint.new(0.5, c[2]), ColorSequenceKeypoint.new(1, c[3]) })
        end
        Theme.bind(self.Num, "TextColor3", function() return H.hpColor(Target.F) end)
        local w = Util.snap(BARW * f)
        local goal = UDim2.fromOffset(w, 4)
        if self._trail then
            self._trail:Stop()
            self._trail = nil
        end
        if instant then
            Anim.stop(self.Fill, "Size")
            Anim.stop(self.Trail, "Size")
            self.Fill.Size = goal
            self.Trail.Size = goal
            self.Lag = f
            Anim.value(self, self.Hp, self.Hp, 0, function(v) Target.Num.Text = tostring(Util.snap(v)) end)
            self.Count = self.Hp
            return
        end
        Anim.to(self.Fill, { Size = goal }, "move")
        if f >= self.Lag then
            Anim.stop(self.Trail, "Size")
            self.Trail.Size = goal
            self.Lag = f
        else
            self.Lag = f
            self._trail = Anim.after(Anim.calm and 0 or 0.35, function()
                Target._trail = nil
                Anim.to(Target.Trail, { Size = goal }, "trail")
            end)
        end
        local from = self.Count
        Anim.value(self, from, self.Hp, "trail", function(v)
            Target.Count = v
            local text = tostring(Util.snap(v))
            if Target.Num.Text ~= text then Target.Num.Text = text end
        end)
    end

    function H.who(data)
        local player = data.player or data.Player or data[1]
        local info = { key = player }
        if typeof(player) == "Instance" then
            local ok = pcall(function()
                info.name = player.DisplayName or player.Name
                info.user = player.Name
                info.id = player.UserId
                if player.Team then info.team = player.TeamColor and player.TeamColor.Color end
            end)
            if not ok then info.name = tostring(player) end
        elseif type(player) == "table" then
            info.name = player.display or player.DisplayName or player.name or player.Name
            info.id = player.id or player.userId or player.UserId
            info.team = Util.hex(player.team or player.teamColor)
            info.key = info.id or info.name
        elseif player ~= nil then
            info.name = tostring(player)
        end
        if data.name then info.name = data.name end
        if data.team then info.team = Util.hex(data.team) end
        info.name = tostring(info.name or "?")
        return info
    end

    function Target:_paintWho(info)
        self.Name.Text = info.name
        self.TeamColor = info.team
        Theme.repaint(self.Dot)
        Theme.repaint(self.Pic)
        local id = tonumber(info.id)
        self.Shot.Image = id and id > 0 and ("rbxthumb://type=AvatarHeadShot&id=" .. tostring(math.floor(id)) .. "&w=48&h=48") or ""
    end

    function Target:_paintInfo()
        local d = self.Data or {}
        local show = self.Show
        Theme.bind(self.Info, "Text", function(T)
            local parts = {}
            if show.weapon and d.weapon and d.weapon ~= "" then parts[#parts + 1] = tostring(d.weapon) end
            if show.distance and tonumber(d.distance) then parts[#parts + 1] = tostring(Util.snap(tonumber(d.distance))) .. " studs" end
            if show.visible and d.visible ~= nil then
                local vis = d.visible == true
                parts[#parts + 1] = "<font color=\"" .. Util.toHex(vis and T.ok or T.warn) .. "\">" .. (vis and "visible" or "behind wall") .. "</font>"
            end
            local escaped = {}
            for index, part in ipairs(parts) do
                escaped[index] = string.find(part, "<font", 1, true) and part or (part:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
            end
            return table.concat(escaped, " <font color=\"" .. Util.toHex(T.tx4) .. "\">\194\183</font> ")
        end)
        local relation = show.relation and d.relation
        local token = (relation == "friend" or relation == "ally") and "ok" or ((relation == "target" or relation == "enemy") and "bad" or nil)
        self.Edge.Visible = token ~= nil
        if token then Theme.bind(self.Edge, "BackgroundColor3", token) end
        self.Pic.Visible = show.headshot
        H.fade(self.Lock, nil, d.locked and 0 or 1, "fade")
    end

    function Target:Set(data)
        if type(data) ~= "table" and data ~= nil then data = { player = data } end
        local player = data and (data.player or data.Player or data[1] or data.name)
        if not player then
            self.Data = nil
            if self.Shown then
                self.Shown = false
                local root = self.Root
                Anim.to(root, { Position = UDim2.fromOffset(self.X or 0, (self.Y or 0) + 6), GroupTransparency = 1 }, "fade", function()
                    if not Target.Shown then root.Visible = false end
                end)
            end
            return
        end
        self.Data = data
        local info = H.who(data)
        local maxhp = tonumber(data.maxhp or data.maxHp) or 100
        if maxhp <= 0 then maxhp = 100 end
        local hp = Util.clamp(tonumber(data.hp or data.health) or maxhp, 0, maxhp)
        self.Hp = Util.snap(hp)
        self.F = hp / maxhp
        local fresh = info.key ~= self.WhoKey
        self.WhoKey = info.key
        local entering = not self.Shown and self.Enabled
        if fresh and self.Shown and not Anim.calm then
            local ghost = self.Who:Clone()
            ghost.Name = "Ghost"
            ghost.ZIndex = 4
            ghost.GroupTransparency = 0
            ghost.Parent = self.Body
            Anim.to(ghost, { GroupTransparency = 1 }, "move", function() ghost:Destroy() end)
            H.fade(self.Who, 1, 0, "move")
        end
        if fresh then self:_paintWho(info) end
        self:_paintInfo()
        self:_paintBar(fresh)
        if entering then
            self.Shown = true
            local root = self.Root
            root.Visible = true
            H.put(self, false)
            root.Position = UDim2.fromOffset(self.X, self.Y + 6)
            root.GroupTransparency = 1
            Anim.to(root, { Position = UDim2.fromOffset(self.X, self.Y), GroupTransparency = 0 }, "intro")
        end
    end

    function Target:Clear()
        self:Set(nil)
    end

    function Target:SetEnabled(on)
        self.Enabled = on ~= false
        if not self.Enabled then
            self.Shown = false
            Anim.stop(self.Root)
            self.Root.Visible = false
        elseif self.Data then
            self:Set(self.Data)
        end
    end

    function Target:SetOption(key, on)
        if self.Show[key] == nil then return false end
        self.Show[key] = on ~= false
        if self.Data then self:_paintInfo() end
        return true
    end

    function Target:SetBarMode(mode)
        self.BarMode = mode == "solid" and "solid" or "gradient"
        self:_paintBar(true)
    end

    function Target:SetColors(lo, mid, hi)
        if type(lo) == "table" and typeof(lo) ~= "Color3" then lo, mid, hi = lo[1] or lo.lo, lo[2] or lo.mid, lo[3] or lo.hi end
        self.Colors = { Util.hex(lo) or self.Colors[1], Util.hex(mid) or self.Colors[2], Util.hex(hi) or self.Colors[3] }
        self:_paintBar(true)
    end

    local Notify = { Enabled = true, Position = "top left", Duration = 3, Max = 6, Prefix = true, Timer = true, List = {} }
    Hud.Notify = setmetatable(Notify, { __call = function(self, ...) return self:Push(...) end })
    local NPOS = { ["top left"] = true, ["top right"] = true, ["bottom left"] = true, ["bottom right"] = true, ["top centre"] = true }

    function H.toasts(glide)
        local vw, vh = H.viewport()
        local pos = NPOS[Notify.Position] and Notify.Position or "top left"
        local top = string.sub(pos, 1, 3) == "top"
        local left, right = string.find(pos, "left") ~= nil, string.find(pos, "right") ~= nil
        local wx, wy = 8, 0
        if Watermark.Enabled and Watermark.Root.Visible and Watermark.X then
            local x, y = Watermark.LiveX or Watermark.X, Watermark.LiveY or Watermark.Y
            local c0, c1 = vw / 2 - 120, vw / 2 + 120
            if left then c0, c1 = 8, 248 elseif right then c0, c1 = vw - 248, vw - 8 end
            local near = top and y < vh / 4 or (not top and y + Watermark.H > vh * 0.75)
            if x < c1 and x + Watermark.W > c0 and near then
                wy = top and y + Watermark.H or vh - y
                if left then wx = x elseif right then wx = vw - (x + Watermark.W) end
            end
        end
        local count = #Notify.List
        for index, t in ipairs(Notify.List) do
            local y = top and 8 + wy + (index - 1) * 24 or vh - 4 - wy - (count - index + 1) * 24
            local x = left and wx or (right and vw - wx - t.W or (vw - t.W) / 2)
            x, y = Util.snap(x), Util.snap(y)
            t.X, t.Y = x, y
            t.Dx, t.Dy = left and -12 or (right and 12 or 0), (left or right) and 0 or -8
            local goal = UDim2.fromOffset(x, y)
            if t.Fresh then
                t.Fresh = false
                Anim.stop(t.Root, "Position")
                t.Root.Position = UDim2.fromOffset(x + t.Dx, y + t.Dy)
                t.Root.GroupTransparency = 1
                Anim.to(t.Root, { Position = goal }, "move")
                Anim.to(t.Root, { GroupTransparency = 0 }, "fade")
            elseif glide then
                Anim.to(t.Root, { Position = goal }, "move")
            else
                Anim.stop(t.Root, "Position")
                t.Root.Position = goal
            end
        end
    end

    function H.leave(t, relayout)
        if t.Gone then return end
        t.Gone = true
        for index = #Notify.List, 1, -1 do
            if Notify.List[index] == t then table.remove(Notify.List, index) end
        end
        local root = t.Root
        Anim.to(root, { Position = UDim2.fromOffset((t.X or 0) + (t.Dx or -12), (t.Y or 0) + (t.Dy or 0)), GroupTransparency = 1 }, "move", function() root:Destroy() end)
        if relayout ~= false then H.toasts(true) end
    end

    function Notify:Push(a, b, c, d)
        local opts
        if type(a) == "table" then
            opts = a
        elseif b ~= nil then
            opts = { source = a, text = b, kind = c, duration = d }
        else
            opts = { text = a }
        end
        if not self.Enabled or Aster.Unloaded then return nil end
        local text = tostring(opts.text or opts.Text or opts[1] or "")
        local source = opts.source or opts.src or opts.title
        local kind = KIND[opts.kind] and opts.kind or "info"
        local life = tonumber(opts.duration or opts.time) or self.Duration
        if life <= 0 then life = self.Duration end
        local vw = H.viewport()
        local prefix = self.Prefix and source and source ~= "" and ("[" .. tostring(source) .. "]: ") or ""
        local pw, tw = prefix ~= "" and Text.width(prefix, "body") or 0, Text.width(text, "body")
        local w = math.min(2 + 8 + pw + tw + 6, math.max(40, vw - 16))
        local root, body = H.card(Aster.Gui.Toast, "Toast", w, 20, { accent = false })
        root.GroupTransparency = 1
        Util.new("Frame", { Name = "Event", ZIndex = 4, Size = UDim2.new(0, 2, 1, 0), Theme = { BackgroundColor3 = KIND[kind] }, Parent = body })
        if prefix ~= "" then H.label(body, { Name = "Source", Text = prefix, Position = UDim2.fromOffset(8, 0), Size = UDim2.fromOffset(pw, 18) }, "body", "tx3") end
        H.label(body, { Name = "Text", Text = text, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(8 + pw, 0), Size = UDim2.fromOffset(math.max(0, w - 2 - 8 - pw - 6), 18) }, "body", "tx")
        local timer
        if self.Timer then
            timer = Util.new("Frame", { Name = "Timer", ZIndex = 4, BackgroundTransparency = 0.2, Position = UDim2.fromOffset(2, 17), Size = UDim2.fromOffset(w - 4, 1), Theme = { BackgroundColor3 = "accent" }, Parent = body })
        end
        local t = { Root = root, W = w, Life = life, Left = life, Kind = kind, Text = text, Source = source, TimerLine = timer, TimerW = w - 4, Fresh = true }
        function t.Close() H.leave(t) end
        self.List[#self.List + 1] = t
        local extra = #self.List - math.max(1, self.Max)
        for _ = 1, extra do H.leave(self.List[1], false) end
        H.toasts(true)
        return t
    end

    function H.tickToasts(dt)
        for _, t in ipairs(table.move(Notify.List, 1, #Notify.List, 1, {})) do
            t.Left = t.Left - dt
            if t.TimerLine then
                local w = Util.snap(t.TimerW * math.max(0, t.Left) / t.Life)
                t.TimerLine.Size = UDim2.fromOffset(w, 1)
            end
            if t.Left <= 0 then H.leave(t) end
        end
    end

    function Notify:Clear()
        for _, t in ipairs(table.move(self.List, 1, #self.List, 1, {})) do H.leave(t, false) end
    end

    function Notify:SetEnabled(on)
        self.Enabled = on ~= false
        if not self.Enabled then self:Clear() end
    end

    function Notify:SetPosition(pos)
        if not NPOS[pos] then return false end
        self.Position = pos
        H.toasts(true)
        return true
    end

    function Notify:SetDuration(seconds)
        seconds = tonumber(seconds)
        if seconds and seconds > 0 then self.Duration = seconds end
    end

    function Notify:SetMax(n)
        n = tonumber(n)
        if not n then return end
        self.Max = math.max(1, math.floor(n))
        local extra = #self.List - self.Max
        for _ = 1, extra do H.leave(self.List[1], false) end
        H.toasts(true)
    end

    function Notify:SetPrefix(on)
        self.Prefix = on ~= false
    end

    function Notify:SetTimer(on)
        self.Timer = on ~= false
        for _, t in ipairs(self.List) do
            if t.TimerLine then t.TimerLine.Visible = self.Timer end
        end
    end

    function Aster:Notify(...)
        return Notify:Push(...)
    end

    H.widgets = { Watermark, Keybinds, Spectators, Target }
    for _, widget in ipairs(H.widgets) do H.drag(widget) end

    do
        local okStats, Stats = pcall(Exec.service, "Stats")
        function H.ping()
            local ok, value = pcall(function() return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
            if okStats and ok and type(value) == "number" then return value end
            ok, value = pcall(function() return LocalPlayer:GetNetworkPing() * 1000 end)
            if ok and type(value) == "number" then return value end
            return 0
        end
    end

    function H.sample(fps)
        local ok, clock = pcall(os.date, "%H:%M")
        return { fps = tostring(Util.snap(fps or 0)), ping = tostring(Util.snap(H.ping())), time = ok and tostring(clock) or "00:00" }
    end

    do
        local frames, elapsed = 0, 0
        Hud._loop = Anim.loop(function(dt)
            if Aster.Unloaded then return false end
            frames = frames + 1
            elapsed = elapsed + dt
            if elapsed >= 1 then
                Watermark:_tick(H.sample(frames / elapsed))
                frames, elapsed = 0, 0
            end
            H.tickToasts(dt)
            return true
        end)
    end

    function Hud:Place(glide)
        for _, widget in ipairs(H.widgets) do
            if widget.Root.Visible or widget == Target then H.put(widget, glide) end
        end
        H.toasts(glide)
    end

    function Hud:ResetPositions()
        H.saved = {}
        H.save()
        Watermark.Corner = "top left"
        if Target.Mode == "custom" then Target.Mode = "below crosshair" end
        self:Place(true)
    end

    function Hud:Enter(delay)
        Hud.Booting = false
        Aster.Gui.Hud.Enabled = true
        Hud.Entered = true
        self:Place(false)
        Watermark:_enter(delay or 0)
        for _, panel in ipairs({ Keybinds, Spectators }) do
            if panel.Root.Visible then
                panel.Root.GroupTransparency = 1
                if delay and delay > 0 and not Anim.calm then
                    Anim.after(delay, function() H.fade(panel.Root, 1, 0, "intro") end)
                else
                    H.fade(panel.Root, 1, 0, "intro")
                end
            end
        end
    end

    function H.attach(win)
        H.saved = readSaved()
        local opts = win.Opts or {}
        Watermark.Title = tostring(opts.title or Watermark.Title)
        if type(opts.user) == "table" and (opts.user.display or opts.user.name) then Watermark.User = tostring(opts.user.display or opts.user.name) end
        if type(opts.game) == "string" and opts.game ~= "" then Watermark.Game = opts.game end
        Watermark.Corner = H.saved.wm and "custom" or (Watermark.Corner == "custom" and "top left" or Watermark.Corner)
        if H.saved.tg then Target.Mode = "custom" elseif Target.Mode == "custom" then Target.Mode = "below crosshair" end
        win._maid:Add(win.Toggled:Connect(function(visible) H.active(visible) end))
        H.active(win.Visible)
        if Hud.Booting then win.Frame.Visible = false end
        Watermark:_layout(false)
        Keybinds:Refresh(false)
        Hud:Place(false)
    end

    do
        local makeWindow = Aster.Window
        function Aster:Window(opts)
            local existed = self._window and not self._window.Destroyed
            local win = makeWindow(self, opts)
            if win and not existed then Util.guard(H.attach, win) end
            return win
        end
        local classes = Aster._.Window
        local Window = classes and classes.Window
        if Window then
            function Window:Notify(...)
                return Notify:Push(...)
            end
            local reset = Window.ResetLayout
            if reset then
                function Window:ResetLayout(...)
                    reset(self, ...)
                    Hud:ResetPositions()
                end
            end
        end
    end

    if Kinds.keybind and Kinds.keybind.Changed then
        Aster._maid:Add(Kinds.keybind.Changed:Connect(function() Keybinds:Refresh(true) end))
    end
    Aster._maid:Add(Aster.Gui.Hud:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() Hud:Place(false) end))

    if Watermark.Game == "" then
        task.spawn(function()
            local ok, info = pcall(function() return Exec.service("MarketplaceService"):GetProductInfo(game.PlaceId) end)
            if ok and type(info) == "table" and type(info.Name) == "string" and Watermark.Game == "" and not Aster.Unloaded then
                Watermark:SetGame(info.Name)
            end
        end)
    end

    Watermark:_tick(H.sample(0))
    Watermark:_layout(false)
    Keybinds:Refresh(false)
    Spectators:Set({})
    H.put(Target, false)
    H.active(false)
    Hud:Enter(0)
end

-- [src] 65_loader.lua
do
    local Hud = Aster.Hud
    local Loader = {}
    Loader.__index = Loader
    Hud.LoaderClass = Loader
    local W, H, BODYW = 220, 56, 218

    function Aster:Loader(opts)
        if type(opts) == "string" then opts = { title = opts } end
        opts = opts or {}
        if Hud.ActiveLoader and not Hud.ActiveLoader.Finished then Hud.ActiveLoader:_destroy() end
        local self = setmetatable({ Opts = opts, Progress = 0, Dots = 1, Finished = false, _maid = Util.Maid.new() }, Loader)
        Hud.ActiveLoader = self
        Aster._maid:Add(self._maid)
        Hud.Booting = true
        Aster.Gui.Hud.Enabled = false
        local win = Aster._window
        if win and not win.Destroyed then win.Frame.Visible = false end

        local vw, vh = Hud._.viewport()
        local root = Util.new("CanvasGroup", {
            Name = "Loader", BorderSizePixel = 0, GroupTransparency = 1, Theme = { BackgroundColor3 = "edge" },
            Position = UDim2.fromOffset(Util.snap((vw - W) / 2) - 1, Util.snap((vh - H) / 2) - 1), Size = UDim2.fromOffset(W + 2, H + 2), Parent = Aster.Gui.Toast,
        })
        self.Root = root
        self._maid:Add(root)
        local frame = Util.new("Frame", { Name = "Border", Position = UDim2.fromOffset(1, 1), Size = UDim2.fromOffset(W, H), Theme = { BackgroundColor3 = "ln2" }, Parent = root })
        local body = Util.new("Frame", { Name = "Body", Position = UDim2.fromOffset(1, 1), Size = UDim2.fromOffset(BODYW, H - 2), Theme = { BackgroundColor3 = "bg" }, Parent = frame })
        self.Body = body
        local tileRing = Util.new("Frame", { Name = "TileRing", Theme = { BackgroundColor3 = "edge" }, Position = UDim2.fromOffset(9, 7), Size = UDim2.fromOffset(34, 34), Parent = body })
        local tile = Util.new("Frame", { Name = "Tile", Position = UDim2.fromOffset(1, 1), Size = UDim2.fromOffset(32, 32), Theme = { BackgroundColor3 = "ln2" }, Parent = tileRing })
        local well = Util.new("Frame", { Name = "Well", Position = UDim2.fromOffset(1, 1), Size = UDim2.fromOffset(30, 30), Theme = { BackgroundColor3 = "well" }, Parent = tile })
        local logo = Hud.Logo(well, 18, "accent")
        logo.Position = UDim2.fromOffset(6, 6)
        self.TitleLabel = Hud._.label(body, { Name = "Title", Text = "Loading.", TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(52, 10), Size = UDim2.fromOffset(BODYW - 52 - 12, 15) }, "body", "tx2")
        self.StageLabel = Hud._.label(body, { Name = "Stage", Text = "", TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(52, 27), Size = UDim2.fromOffset(BODYW - 52 - 12, 13) }, "tiny", "tx4")
        local function track(name, y)
            local bar = Util.new("Frame", { Name = name, ClipsDescendants = true, BackgroundTransparency = 0.9, Position = UDim2.fromOffset(0, y), Size = UDim2.fromOffset(BODYW, 2), Theme = { BackgroundColor3 = "accent" }, Parent = body })
            local fill = Util.new("Frame", { Name = "Fill", Size = UDim2.fromOffset(0, 2), Theme = { BackgroundColor3 = "accent" }, Parent = bar })
            return bar, fill
        end
        self.Bar, self.Fill = track("Progress", H - 2 - 5)
        self.Activity, self.Sweep = track("Activity", H - 2 - 2)
        local seg = Util.snap(BODYW * 0.28)
        self.Sweep.Size = UDim2.fromOffset(seg, 2)
        self.Sweep.Position = UDim2.fromOffset(-seg, 0)

        local clock, dotClock = 0, 0
        self._loop = self._maid:Add(Anim.loop(function(dt)
            if self.Finished and self._faded then return false end
            clock = clock + dt
            local phase = (clock % 2.8) / 1.4
            local k = phase <= 1 and phase or 2 - phase
            local x = -seg + (BODYW + seg) * Anim.sine(k)
            self.Sweep.Position = UDim2.fromOffset(Util.snap(x), 0)
            if not self._named then
                dotClock = dotClock + dt
                if dotClock >= 0.32 then
                    dotClock = dotClock - 0.32
                    self.Dots = self.Dots % 3 + 1
                    self.TitleLabel.Text = "Loading" .. string.rep(".", self.Dots)
                end
            end
            return true
        end))
        Anim.to(root, { GroupTransparency = 0 }, "intro")
        return self
    end

    function Loader:Stage(text, progress)
        if self.Finished then return self end
        if text ~= nil then self.StageLabel.Text = tostring(text) end
        progress = tonumber(progress)
        if progress then
            self.Progress = Util.clamp(progress, 0, 1)
            Anim.to(self.Fill, { Size = UDim2.fromOffset(Util.snap(BODYW * self.Progress), 2) }, "bar")
        end
        return self
    end

    function Loader:_destroy()
        self.Finished = true
        self._faded = true
        if Hud.ActiveLoader == self then Hud.ActiveLoader = nil end
        self._maid:Clean()
    end

    function Loader:_bootIn()
        local win = Aster._window
        if win and not win.Destroyed then
            if not win.Visible then win:Toggle(true) end
            local rig = win.Frame
            local x, y = rig.Position.X.Offset, rig.Position.Y.Offset
            local w, h = rig.Size.X.Offset, rig.Size.Y.Offset
            local dx, dy = Util.snap(w * 0.01), Util.snap(h * 0.01)
            local group = Util.new("CanvasGroup", {
                Name = "BootIn", BackgroundTransparency = 1, BorderSizePixel = 0, GroupTransparency = 1,
                Position = UDim2.fromOffset(x + dx, y + dy), Size = UDim2.fromOffset(w, h), Parent = Aster.Gui.Main,
            })
            local scale = Util.new("UIScale", { Scale = 0.98, Parent = group })
            rig.Parent = group
            rig.Position = UDim2.fromOffset(0, 0)
            rig.Visible = true
            local function unwrap()
                if rig.Parent == group then
                    rig.Parent = Aster.Gui.Main
                    local pos = win.Pos or { x, y }
                    rig.Position = UDim2.fromOffset(pos[1], pos[2])
                end
                scale:Destroy()
                group:Destroy()
            end
            Aster._maid:Add(group)
            Anim.to(scale, { Scale = 1 }, "intro")
            Anim.to(group, { GroupTransparency = 0, Position = UDim2.fromOffset(x, y) }, "intro", unwrap)
            self.BootGroup = group
        end
        Hud:Enter(0.2)
    end

    function Loader:Done(instant)
        if self.Finished then return end
        self.Finished = true
        self._named = true
        local opts = self.Opts
        self.Progress = 1
        Anim.to(self.Fill, { Size = UDim2.fromOffset(BODYW, 2) }, "bar")
        local gameName = opts.game or (Hud.Watermark and Hud.Watermark.Game ~= "" and Hud.Watermark.Game) or opts.title or "aster"
        self.TitleLabel.Text = tostring(gameName)
        Text.style(self.TitleLabel, "bold")
        Theme.bind(self.TitleLabel, "TextColor3", "tx")
        self.StageLabel.Text = tostring(opts.title or "aster") .. " \194\183 build " .. tostring(opts.build or Aster.Version)
        local function finish()
            Anim.to(self.Root, { GroupTransparency = 1 }, "intro", function()
                self._faded = true
                if Hud.ActiveLoader == self then Hud.ActiveLoader = nil end
                self._maid:Clean()
                self:_bootIn()
            end)
        end
        if instant or Anim.calm then finish() else Anim.after(0.7, finish) end
    end
end

-- [src] 68_themes.lua
do
    local TM = { Folder = "themes", Custom = {}, Changed = Util.Signal.new(), _memory = {} }
    Aster.ThemeManager = TM
    Aster._maid:Add(TM.Changed)
    TM.Groups = {
        { "colours", "th.cols", { { "bg", "Background" }, { "panel", "Main" }, { "accent", "Accent" }, { "border", "Outline" }, { "text", "Font" } } },
        { "buttons", "th.btns", { { "btnBg", "Button background" }, { "btnBd", "Button border" }, { "btnTx", "Button text" }, { "btnHv", "Button hover" } } },
        { "dropdowns", "th.dds", { { "ddBg", "Box background" }, { "ddBd", "Box border" }, { "ddTx", "Box text" }, { "ddlBg", "List background" }, { "ddHl", "Highlighted option" } } },
    }

    local function folder()
        return Store.Root .. "/" .. TM.Folder
    end

    local function file(name)
        return folder() .. "/" .. name .. ".json"
    end

    local function ensure()
        local built = ""
        for part in string.gmatch(folder(), "[^/]+") do
            built = built == "" and part or built .. "/" .. part
            pcall(function()
                if not (Exec.fs.isfolder and Exec.fs.isfolder(built)) then Exec.fs.makefolder(built) end
            end)
        end
    end

    local function read(path)
        if not Exec.hasFs then return TM._memory[path] end
        local ok, text = pcall(function()
            if Exec.fs.isfile(path) then return Exec.fs.read(path) end
            return nil
        end)
        if ok and type(text) == "string" then return text end
        return nil
    end

    local function write(path, text)
        if not Exec.hasFs then
            TM._memory[path] = text
            return true
        end
        ensure()
        return (pcall(Exec.fs.write, path, text))
    end

    local function remove(path)
        if not Exec.hasFs then
            local had = TM._memory[path] ~= nil
            TM._memory[path] = nil
            return had
        end
        return Exec.fs.delete ~= nil and (pcall(Exec.fs.delete, path))
    end

    local function names()
        local out = {}
        if Exec.hasFs then
            ensure()
            local ok, files = pcall(function() return Exec.fs.list and Exec.fs.list(folder()) or {} end)
            for _, path in ipairs(ok and files or {}) do
                local name = string.match(string.gsub(tostring(path), "\\", "/"), "([^/]+)%.json$")
                if name then out[#out + 1] = name end
            end
        else
            local prefix = folder() .. "/"
            for path in pairs(TM._memory) do
                if string.sub(path, 1, #prefix) == prefix then
                    local name = string.match(string.sub(path, #prefix + 1), "^([^/]+)%.json$")
                    if name then out[#out + 1] = name end
                end
            end
        end
        table.sort(out)
        return out
    end

    function TM.fix(v)
        if type(v) ~= "table" then return nil end
        local out = {}
        for _, key in ipairs(Theme.Keys) do
            if type(v[key]) == "string" and Util.hex(v[key]) then out[key] = Util.toHex(Util.hex(v[key])) end
        end
        if v.style == "flat" or v.style == "gradient" then out.style = v.style end
        return out
    end

    function TM.name(v)
        return Store.cfgName(v)
    end

    function TM:SetFolder(name)
        if type(name) == "string" and name ~= "" then self.Folder = name end
        self:ReloadCustomThemes()
    end

    function TM:IsBuiltIn(name)
        return Theme.PresetData(name) ~= nil
    end

    function TM:ReloadCustomThemes()
        self.Custom = {}
        for _, name in ipairs(names()) do
            local data = TM.fix(Util.unjson(read(file(name))))
            if data and next(data) and not self:IsBuiltIn(name) then self.Custom[name] = data end
        end
        local list = {}
        for name in pairs(self.Custom) do list[#list + 1] = name end
        table.sort(list)
        return list
    end

    function TM:GetCustomTheme(name)
        name = TM.name(name)
        return self.Custom[name] and Util.copy(self.Custom[name]) or nil
    end

    function TM:GetTheme(name)
        return Theme.PresetData(name) or self:GetCustomTheme(name)
    end

    function TM:List()
        local default = self:GetDefault()
        local out = {}
        for _, name in ipairs(Theme.Presets) do
            out[#out + 1] = { key = name, text = name, meta = "built-in", marker = name == default and "default" or nil }
        end
        local custom = {}
        for name in pairs(self.Custom) do custom[#custom + 1] = name end
        table.sort(custom)
        for _, name in ipairs(custom) do
            out[#out + 1] = { key = name, text = name, meta = "custom", marker = name == default and "default" or nil }
        end
        return out
    end

    local function same(data)
        for _, key in ipairs(Theme.Keys) do
            if data[key] and Util.toHex(Util.hex(data[key])) ~= Util.toHex(Util.hex(Theme.Base[key])) then return false end
        end
        return (data.style or Theme.Base.style) == Theme.Base.style
    end

    function TM:Match()
        local builtin = Theme:Name()
        if builtin ~= "custom" then return builtin end
        local list = {}
        for name in pairs(self.Custom) do list[#list + 1] = name end
        table.sort(list)
        for _, name in ipairs(list) do
            if same(self.Custom[name]) then return name end
        end
        return "custom"
    end

    function TM:ApplyTheme(name)
        local data = self:GetTheme(name)
        if not data then return false end
        Theme:Set(data)
        return true
    end

    function TM:SaveCustomTheme(name)
        name = TM.name(name)
        if name == "" then return false, "type a name first" end
        if self:IsBuiltIn(name) then return false, name .. " is a built-in theme" end
        local text = Util.json(Theme:Export())
        if not text or not write(file(name), text) then return false, "could not write " .. name end
        self:ReloadCustomThemes()
        self.Changed:Fire("save", name)
        return true, name
    end

    function TM:DeleteCustomTheme(name)
        name = TM.name(name)
        if not self.Custom[name] then return false end
        if not remove(file(name)) then return false end
        if self:GetDefault() == name then remove(folder() .. "/default.txt") end
        self:ReloadCustomThemes()
        self.Changed:Fire("delete", name)
        return true
    end

    function TM:SaveDefault(name)
        name = TM.name(name)
        if not self:GetTheme(name) then return false end
        if not write(folder() .. "/default.txt", name) then return false end
        self.Changed:Fire("default", name)
        return true
    end

    function TM:GetDefault()
        local name = read(folder() .. "/default.txt")
        name = name and TM.name(name) or ""
        if name == "" then return nil end
        return name
    end

    function TM:LoadDefault()
        local name = self:GetDefault()
        if not name then return false end
        return self:ApplyTheme(name)
    end

    function TM:Init()
        if self._init then return end
        self._init = true
        self:ReloadCustomThemes()
        if not self:LoadDefault() then
            local saved = Store.get("theme", nil, TM.fix)
            if saved and next(saved) then Theme:Set(saved) end
        end
        local pending
        Aster._maid:Add(Theme.Changed:Connect(function()
            if pending then pending:Stop() end
            pending = Anim.after(0.4, function()
                pending = nil
                Store.put("theme", Theme:Export())
            end)
        end))
    end

    local function notify(text, kind)
        if Aster.Notify then Aster:Notify("theme", text, kind) end
    end

    function TM:ApplyToCard(card)
        self:Init()
        local h = { Card = card, Colours = {} }
        local syncing = false
        h.List = card:List({ items = function() return TM:List() end, rows = 6, empty = "no themes", default = self:Match(), save = false, callback = function(v)
            if not syncing and v ~= "" and v ~= "custom" then TM:ApplyTheme(v) end
        end })
        h.Preset = h.List
        h.Style = card:Dropdown({ name = "Fill style", options = { "flat", "gradient" }, default = Theme.Base.style, save = false, callback = function(v)
            if not syncing then Theme:Set({ style = v }) end
        end })
        if Icons.SetShown and Icons.shown then
            h.Icons = card:Dropdown({ name = "Strip icons", options = { "on", "off" }, default = Icons.shown() and "on" or "off", save = false, callback = function(v)
                Icons.SetShown(v == "on")
            end })
        end
        for _, group in ipairs(self.Groups) do
            local section = card:Section({ name = group[1], key = group[2], open = group[2] == "th.cols" })
            for _, entry in ipairs(group[3]) do
                local key = entry[1]
                h.Colours[key] = section:Color({ name = entry[2], default = Theme.Base[key], opaque = true, save = false, callback = function(v)
                    if not syncing then Theme:Set({ [key] = v }) end
                end })
            end
        end
        h.Name = card:Input({ placeholder = "theme name", max = 24 })
        local function target()
            local typed = TM.name(h.Name.Value)
            if typed ~= "" then return typed end
            local picked = h.List.Value
            if picked ~= "" and picked ~= "custom" then return picked end
            return nil
        end
        local function save()
            local ok, why = TM:SaveCustomTheme(target() or "")
            if ok then h.Name:Set("") end
            notify(ok and ("saved " .. why) or why, ok and "ok" or "warn")
        end
        h.Name.Opts.enter = save
        local armed
        local function disarm()
            if armed then armed:Stop() end
            armed = nil
            if h.Actions and not h.Actions.Destroyed then h.Actions:SetText(3, "Delete") end
        end
        h.Actions = card:Buttons({ items = {
            { name = "Save", primary = true, callback = save },
            { name = "Load", callback = function()
                local name = target()
                if not name or not TM:ApplyTheme(name) then return notify("pick a theme first", "warn") end
                notify("loaded " .. name, "ok")
            end },
            { name = "Delete", callback = function()
                local name = target()
                if not name or not TM.Custom[name] then return notify("pick a custom theme", "warn") end
                if not armed then
                    h.Actions:SetText(3, "Confirm")
                    armed = Anim.after(2.5, disarm)
                    return
                end
                disarm()
                if TM:DeleteCustomTheme(name) then notify("deleted " .. name, "warn") end
            end },
        } })
        h.Extra = card:Buttons({ items = {
            { name = "Set as default", callback = function()
                local name = target() or TM:Match()
                if not TM:SaveDefault(name) then return notify("save the theme first", "warn") end
                notify(name .. " loads on inject", "ok")
            end },
            { name = "Refresh", callback = function()
                TM:ReloadCustomThemes()
                h.List:Refresh()
                notify(#TM:List() .. " themes found")
            end },
        } })
        local function sync()
            syncing = true
            for key, el in pairs(h.Colours) do
                if not el.Destroyed then el:Set(Theme.Base[key], true) end
            end
            if not h.Style.Destroyed then h.Style:Set(Theme.Base.style, true) end
            if not h.List.Destroyed then h.List:Set(TM:Match(), true) end
            syncing = false
        end
        h.List._maid:Add(Theme.Changed:Connect(sync))
        h.List._maid:Add(TM.Changed:Connect(function()
            disarm()
            if h.List.Destroyed then return end
            h.List:Refresh()
            sync()
        end))
        h.Sync = sync
        return h
    end

    function TM:ApplyToTab(target, opts)
        opts = opts or {}
        local page = target
        if type(target) == "table" and not target.Card and target.Page then
            page = target:Page({ name = opts.page or "theme", icon = opts.icon or "theme" })
        end
        if type(page) ~= "table" or not page.Card then error("[aster] ApplyToTab needs a page or a tab") end
        local card = page:Card({ name = opts.name or "theme", side = opts.side or "left" })
        return self:ApplyToCard(card), card
    end
    TM.ApplyToPage = TM.ApplyToTab
end

-- [src] 70_builtins.lua
do
    local Builtins = {}
    Builtins.__index = Builtins
    Aster._.Builtins = Builtins
    local WMSEG = { "user", "game", "fps", "ping", "time" }
    local NPOS = { "top left", "top right", "bottom left", "bottom right", "top centre" }
    local CORNERS = { "top left", "top right", "bottom left", "bottom right", "custom" }
    local RELS = { "none", "friend", "target", "ignore" }

    local function notify(source, text, kind)
        if Aster.Notify then Aster:Notify(source, text, kind) end
    end

    local function hud()
        return Aster.Hud
    end

    local function call(owner, method, ...)
        local target = owner and owner[method]
        if type(target) == "function" then return Util.guard(target, owner, ...) end
        return false
    end

    function Builtins.loadTheme()
        Aster.ThemeManager:Init()
    end

    function Builtins:_configs(page)
        local card = page:Card({ name = "configs", side = "left" })
        local list = card:Configs({ rows = 7 })
        local nameBox = card:Input({ placeholder = "config name", max = 24 })
        local function create()
            local name = Store.cfgName(nameBox.Value)
            if name == "" then return notify("config", "type a name first", "warn") end
            if Store.exists(name) then return notify("config", name .. " already exists", "warn") end
            local ok, why = Store.save(name)
            if not ok then return notify("config", tostring(why), "warn") end
            nameBox:Set("")
            notify("config", "created " .. name, "ok")
        end
        nameBox.Opts.enter = create
        card:Button({ name = "Create", callback = create })
        local function selected()
            local name = list:Selected()
            if not name or not Store.exists(name) then
                notify("config", "pick a config first", "warn")
                return nil
            end
            return name
        end
        local armed
        local actions
        local function disarm()
            if armed then armed:Stop() end
            armed = nil
            if actions and not actions.Destroyed then actions:SetText(3, "Delete") end
        end
        actions = card:Buttons({ items = {
            { name = "Load", callback = function()
                local name = selected()
                if not name then return end
                local ok, why = Store.load(name)
                notify("config", ok and ("loaded " .. name) or tostring(why), ok and "ok" or "warn")
            end },
            { name = "Save", primary = true, callback = function()
                local name = list:Selected() or Store.Selected
                local ok, why = Store.save(name)
                notify("config", ok and ("saved " .. Store.cfgName(name)) or tostring(why), ok and "ok" or "warn")
            end },
            { name = "Delete", callback = function()
                local name = selected()
                if not name then return end
                if not armed then
                    actions:SetText(3, "Confirm")
                    armed = Anim.after(2.5, disarm)
                    return
                end
                disarm()
                if Store.delete(name) then notify("config", "deleted " .. name, "warn") end
            end },
        } })
        local auto
        card:Buttons({ items = {
            { name = "Autoload", callback = function()
                local name = selected()
                if not name then return end
                Store.autoload(name)
                notify("config", name .. " loads on inject", "ok")
            end },
            { name = "Refresh", callback = function()
                list:Refresh()
                notify("config", #Store.list() .. " configs found")
            end },
        } })
        local side = page:Card({ name = "autoload", side = "right" })
        auto = side:Toggle({ name = "Load on inject", default = Store.getAutoload() ~= nil, save = false, callback = function(v)
            if v then
                local name = list:Selected() or Store.Selected
                if Store.exists(name) then Store.autoload(name) else
                    notify("config", "save a config first", "warn")
                    auto:Set(false, true)
                end
            else
                Store.autoload(nil)
            end
        end })
        self._maid:Add(Store.Changed:Connect(function(verb)
            disarm()
            if not auto.Destroyed then auto:Set(Store.getAutoload() ~= nil, true) end
        end))
        self.Configs, self.ConfigName, self.ConfigButtons, self.Autoload = list, nameBox, actions, auto
        self.Cards.configs, self.Cards.autoload = card, side
    end

    function Builtins:_menu(page)
        local win, opts = self.Window, self.Opts
        local card = page:Card({ name = "menu", side = "right" })
        self.MenuKey = card:Keybind({ name = "Menu key", flag = "ui.menu", default = win.Key, callback = function(v)
            if v.key ~= "" then win:SetKey(v.key) end
        end })
        self.PanicKey = card:Keybind({ name = "Panic key", flag = "ui.panic", default = opts.panicKey or "end" })
        self._maid:Add(self.PanicKey.Pressed:Connect(function()
            if UserInputService:GetFocusedTextBox() then return end
            self.Panicked:Fire()
            if opts.onPanic then Util.guard(opts.onPanic) end
            notify("panic", "everything disabled", "warn")
        end))
        self.Calm = card:Toggle({ name = "Reduce motion", default = Anim.calm == true, save = false, callback = function(v) Anim.setCalm(v) end })
        card:Buttons({ items = {
            { name = "Collapse all", callback = function()
                local current = win.Page and win.Page:_current()
                for _, c in ipairs(current and current.Order or {}) do
                    if not c:IsFolded() then c:Fold(true) end
                end
            end },
            { name = "Reset layout", callback = function()
                win:ResetLayout()
                notify("layout", "reset", "ok")
            end },
        } })
        self.Cards.menu = card
    end

    function Builtins:_hud(page)
        local H = hud()
        if not H then return end
        local card = page:Card({ name = "hud", side = "right" })
        local wm = card:Section({ name = "watermark", key = "hud.wms" })
        wm:Toggle({ name = "Watermark", flag = "hud.wm", default = true, callback = function(v) call(H.Watermark, "SetEnabled", v) end })
        wm:Dropdown({ name = "Segments", flag = "hud.wmf", options = WMSEG, default = WMSEG, multi = true, depends = "hud.wm", callback = function(v)
            local on = { "logo" }
            for _, key in ipairs(v) do on[#on + 1] = key end
            call(H.Watermark, "SetSegments", on)
        end })
        local corner = wm:Dropdown({ name = "Position", flag = "hud.wmp", options = CORNERS, default = H.Watermark.Corner or "top left", depends = "hud.wm", callback = function(v) call(H.Watermark, "SetPosition", v) end })
        self._maid:Add(self.Window.PageChanged:Connect(function()
            if not corner.Destroyed and H.Watermark.Corner then corner:Set(H.Watermark.Corner, true) end
        end))
        local kb = card:Section({ name = "keybinds", key = "hud.kbl" })
        kb:Toggle({ name = "Keybind list", flag = "hud.kb", default = true, callback = function(v) call(H.Keybinds, "SetEnabled", v) end })
        kb:Dropdown({ name = "Show", flag = "hud.kbs", options = { "all binds", "active only" }, default = "all binds", depends = "hud.kb", callback = function(v) call(H.Keybinds, "SetActiveOnly", v == "active only") end })
        kb:Toggle({ name = "Hide when empty", flag = "hud.kbe", default = true, depends = "hud.kb", callback = function(v) call(H.Keybinds, "SetHideEmpty", v) end })
        card:Toggle({ name = "Spectator list", flag = "hud.spec", default = true, callback = function(v) call(H.Spectators, "SetEnabled", v) end })
        local nf = card:Section({ name = "notifications", key = "hud.nfl" })
        nf:Toggle({ name = "Notifications", flag = "hud.nf", default = true, callback = function(v) call(H.Notify, "SetEnabled", v) end })
        nf:Dropdown({ name = "Position", flag = "hud.pos", options = NPOS, default = "top left", depends = "hud.nf", callback = function(v) call(H.Notify, "SetPosition", v) end })
        nf:Slider({ name = "Duration", flag = "hud.nft", min = 1, max = 10, step = 0.5, default = 3, depends = "hud.nf",
            fmt = function(v) return string.format("%.1f s", v) end, callback = function(v) call(H.Notify, "SetDuration", v) end })
        nf:Slider({ name = "Max on screen", flag = "hud.nfm", min = 1, max = 8, default = 6, depends = "hud.nf", callback = function(v) call(H.Notify, "SetMax", v) end })
        nf:Toggle({ name = "Source prefix", flag = "hud.nfp", default = true, depends = "hud.nf", callback = function(v) call(H.Notify, "SetPrefix", v) end })
        nf:Toggle({ name = "Timer line", flag = "hud.nfd", default = true, depends = "hud.nf", callback = function(v) call(H.Notify, "SetTimer", v) end })
        nf:Button({ name = "Test", depends = "hud.nf", callback = function() Builtins.testToasts() end })
        self.Cards.hud = card
    end

    local TESTS = {
        { "aimbot", "hit vanta in the head for 87", "hit" }, { "aimbot", "killed vanta with AK-47 (118 studs)", "kill" },
        { "combat", "killed by marrow with M9", "death" }, { "esp", "ping above 150 ms, esp slowed", "warn" },
        { "config", "saved 'legit'", "ok" }, { "players", "kit joined the server", "info" },
    }
    function Builtins.testToasts()
        for index, t in ipairs(TESTS) do
            if index == 1 then notify(t[1], t[2], t[3]) else Anim.after((index - 1) * 0.12, function() notify(t[1], t[2], t[3]) end) end
        end
    end

    local function character(p)
        local player = p and p.player
        if not player then
            pcall(function() player = Players:FindFirstChild(p.name) end)
        end
        return player and player.Character
    end

    local function spectate(p, on)
        pcall(function()
            local camera = workspace.CurrentCamera
            local own = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            local char = character(p)
            local hum = on and char and char:FindFirstChildOfClass("Humanoid")
            camera.CameraSubject = hum or own
        end)
    end

    local function teleport(p)
        local ok = pcall(function()
            local char = character(p)
            local root = LocalPlayer.Character.HumanoidRootPart
            root.CFrame = char.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3)
        end)
        return ok
    end

    function Builtins:_players(page)
        local opts = type(self.Opts.players) == "table" and self.Opts.players or {}
        local card = page:Card({ name = "players", side = "left" })
        local info = page:Card({ name = "player", side = "right" })
        local current, spectating, paintPlayer
        local nameStat = info:Stat({ name = "Player", default = "-" })
        local hpStat = info:Stat({ name = "Health", default = "-" })
        local distStat = info:Stat({ name = "Distance", default = "-" })
        local idStat = info:Stat({ name = "User id", default = "-" })
        local relation = info:Dropdown({ name = "Relation", options = RELS, default = "none", save = false, callback = function(v)
            if current and not current.me then Kinds.players.SetRelation(current.name, v) end
        end })
        local function act(name, fn)
            return { name = name, callback = function()
                if current then fn(current) end
            end }
        end
        local moves = info:Buttons({ items = {
            act("Spectate", function(p)
                local on = spectating ~= p.name
                spectating = on and p.name or nil
                local hook = opts.spectate
                if hook then Util.guard(hook, p, on) else spectate(p, on) end
                paintPlayer()
                notify("spectate", on and ("spectating " .. tostring(p.display or p.name)) or "back to your camera")
            end),
            act("Teleport to", function(p)
                local hook = opts.teleport
                local ok = hook and Util.guard(hook, p) or (not hook and teleport(p))
                notify("teleport", ok and ("moved to " .. tostring(p.display or p.name)) or "could not teleport", ok and "ok" or "warn")
            end),
        } })
        local links = info:Buttons({ items = {
            act("Copy avatar", function(p)
                if not opts.copyAvatar then return notify("avatar", "copy avatar is not available here", "warn") end
                Util.guard(opts.copyAvatar, p)
                notify("avatar", "copied @" .. tostring(p.name) .. "'s avatar", "ok")
            end),
            act("View profile", function(p)
                local url = "https://www.roblox.com/users/" .. string.format("%.0f", tonumber(p.id) or 0) .. "/profile"
                if Exec.clipboard then pcall(Exec.clipboard, url) end
                notify("profile", url)
            end),
        } })
        self._maid:Add(function()
            if spectating and not opts.spectate then spectate(nil, false) end
            spectating = nil
        end)
        local list
        paintPlayer = function()
            local p = current
            nameStat:Set(p and tostring(p.display or p.name) or "-")
            hpStat:Set(p and (tostring(p.hp or 0) .. " hp") or "-")
            distStat:Set(p and (p.me and "-" or (tostring(p.dist or 0) .. " studs")) or "-")
            idStat:Set(p and string.format("%.0f", tonumber(p.id) or 0) or "-")
            relation:Set(p and Kinds.players.Relations[p.name] or "none", true)
            relation:SetDisabled(p == nil or p.me == true)
            moves:SetDisabled(p == nil or p.me == true)
            links:SetDisabled(p == nil)
            moves:SetText(1, p and spectating == p.name and "Stop" or "Spectate")
        end
        list = card:Players({ source = opts.source, rate = opts.rate, onSelect = function(p)
            current = p
            paintPlayer()
        end, onUpdate = function(p)
            current = p
            paintPlayer()
        end })
        self._maid:Add(Kinds.players.RelationChanged:Connect(function() paintPlayer() end))
        paintPlayer()
        local targets = page:Card({ name = "targets", side = "left" })
        targets:Toggle({ name = "Focus marked targets", flag = "pl.focus", default = true })
        targets:Toggle({ name = "Notify when a target joins", flag = "pl.notify", default = true })
        targets:Toggle({ name = "Tracer to targets", flag = "pl.trace" }):Color({ flag = "pl.trace.c0", default = "#c9a96e" })
        local friends = page:Card({ name = "friends", side = "left" })
        friends:Toggle({ name = "Treat Roblox friends as friends", flag = "pl.rbx", default = true })
        friends:Toggle({ name = "Hide friends from esp", flag = "pl.fesp" })
        friends:Color({ name = "Friend colour", flag = "pl.fcol", default = "#6fd69a" })
        self.Players, self.PlayerInfo = list, { Name = nameStat, Health = hpStat, Distance = distStat, Id = idStat, Relation = relation, Moves = moves, Links = links }
        self.Cards.players, self.Cards.player, self.Cards.targets, self.Cards.friends = card, info, targets, friends
    end

    function Builtins:_theming(page)
        local card = page:Card({ name = "theme", side = "left" })
        self.Theme = Aster.ThemeManager:ApplyToCard(card)
        self.Cards.theme = card
    end

    function Aster:Builtins(win, opts)
        win = win or self._window
        opts = opts or {}
        if not win then error("[aster] Builtins needs a window") end
        if win._builtins then return win._builtins end
        local b = setmetatable({ Window = win, Opts = opts, Cards = {}, Pages = {}, Panicked = Util.Signal.new(), _maid = Util.Maid.new() }, Builtins)
        win._builtins = b
        win._maid:Add(b._maid)
        b._maid:Add(b.Panicked)
        Builtins.loadTheme()
        local tab = win:Tab({ name = opts.name or "settings", icon = opts.icon or "gear" })
        b.Tab = tab
        if opts.configs ~= false then
            b.Pages.configs = tab:Page({ name = "configs", icon = "gear" })
            b:_configs(b.Pages.configs)
            b:_menu(b.Pages.configs)
            if opts.hud ~= false then b:_hud(b.Pages.configs) end
        end
        if opts.players ~= false then
            b.Pages.players = tab:Page({ name = "players", icon = "players", wide = true })
            b:_players(b.Pages.players)
        end
        if opts.theming ~= false then
            b.Pages.theming = tab:Page({ name = "theming", icon = "theme" })
            b:_theming(b.Pages.theming)
        end
        return b
    end

    local classes = Aster._.Window
    if classes and classes.Window then
        function classes.Window:Builtins(opts)
            return Aster:Builtins(self, opts)
        end
    end
end

-- [src] 99_tail.lua
if Kinds.keybind then Aster.Keybinds = Kinds.keybind.List end
return Aster
