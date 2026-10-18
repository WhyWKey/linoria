--[[
    MouseUI  |  stage 1 (core)
    BBot v3 look, Linoria-style Toggles/Options API, sUNC-aware executor layer.

    Window -> Tab -> (SubTab) -> Section / MultiSection -> elements
    Elements: Toggle (folding), Slider, Dropdown (multi), Button, Label, Divider, Image
]]

--// ============================== environment ==============================
local genv = (function()
    local ok, g = pcall(function() return getgenv() end)
    if ok and type(g) == "table" then return g end
    return _G
end)()

-- remove a previous instance so re-executing never stacks menus
do
    local prev = rawget(genv, "MouseUI")
    if type(prev) == "table" and type(prev.Unload) == "function" then
        pcall(prev.Unload, prev)
    end
end

local function Resolve(name)
    local ok, v = pcall(function() return genv[name] end)
    if ok and v ~= nil then return v end
    ok, v = pcall(function() return getfenv()[name] end)
    if ok and v ~= nil then return v end
    return nil
end

local Env = {
    cloneref       = Resolve("cloneref") or function(x) return x end,
    gethui         = Resolve("gethui"),
    getcustomasset = Resolve("getcustomasset") or Resolve("getsynasset"),
    writefile      = Resolve("writefile"),
    readfile       = Resolve("readfile"),
    isfile         = Resolve("isfile"),
    isfolder       = Resolve("isfolder"),
    makefolder     = Resolve("makefolder"),
    request        = Resolve("request") or Resolve("http_request"),
    httpget        = Resolve("httpget") or Resolve("HttpGet"),
    setclipboard   = Resolve("setclipboard") or Resolve("toclipboard"),
    identify       = Resolve("identifyexecutor") or Resolve("getexecutorname"),
    protect        = Resolve("protect_gui"),
}
do
    local syn = Resolve("syn")
    if type(syn) == "table" then
        Env.protect = Env.protect or syn.protect_gui
        Env.request = Env.request or syn.request
    end
end

local function Service(name)
    local ok, svc = pcall(function() return Env.cloneref(game:GetService(name)) end)
    if ok and svc then return svc end
    return game:GetService(name)
end

local Players          = Service("Players")
local UserInputService = Service("UserInputService")
local TweenService     = Service("TweenService")
local RunService       = Service("RunService")
local CoreGui          = Service("CoreGui")

local LocalPlayer = Players.LocalPlayer

--// ================================ library ================================
local Library = {
    Version = "0.1.0",
    Toggles = {},
    Options = {},
    Windows = {},
    Registry = {},
    Updaters = {},
    Shines = {},
    Connections = {},
    UnloadCallbacks = {},
    Visible = true,
    Unloaded = false,
    Shine = true,
    ToggleKey = Enum.KeyCode.RightShift,
    Font = Enum.Font.Code,
    TextSize = 13,
    Env = Env,
    Executor = "Unknown",
    Theme = {
        Accent  = Color3.fromRGB(150, 100, 235),
        Outline = Color3.fromRGB(8, 8, 8),
        Main    = Color3.fromRGB(28, 28, 28),
        Section = Color3.fromRGB(33, 33, 33),
        Field   = Color3.fromRGB(20, 20, 20),
        Border  = Color3.fromRGB(54, 54, 54),
        Text    = Color3.fromRGB(215, 215, 215),
        TextDim = Color3.fromRGB(135, 135, 135),
    },
    Presets = {
        Purple = Color3.fromRGB(150, 100, 235),
        Teal   = Color3.fromRGB(55, 165, 175),
        Orange = Color3.fromRGB(205, 115, 50),
    },
}

do
    local ok, name = pcall(function() return Env.identify and Env.identify() end)
    if ok and name then Library.Executor = tostring(name) end
    local files = Env.writefile and Env.readfile and Env.isfile and Env.isfolder and Env.makefolder
    Library.Caps = {
        Hui       = Env.gethui ~= nil,
        Files     = files ~= nil and files ~= false,
        Assets    = (files ~= nil and files ~= false) and Env.getcustomasset ~= nil,
        Request   = Env.request ~= nil,
        Clipboard = Env.setclipboard ~= nil,
    }
end

local function Round(n, d)
    local m = 10 ^ (d or 0)
    return math.floor(n * m + 0.5) / m
end
Library.Round = Round

local function Inside(inst, pos)
    local p, s = inst.AbsolutePosition, inst.AbsoluteSize
    return pos.X >= p.X and pos.X <= p.X + s.X and pos.Y >= p.Y and pos.Y <= p.Y + s.Y
end

local function IsPress(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch
end

local function IsMove(input)
    return input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch
end

local function NextOrder(frame)
    local n = (frame:GetAttribute("o") or 0) + 1
    frame:SetAttribute("o", n)
    return n
end

local function RandomName()
    local t = {}
    for i = 1, 12 do t[i] = string.char(math.random(97, 122)) end
    return table.concat(t)
end

function Library:SafeCall(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then warn("[MouseUI] callback error: " .. tostring(err)) end
end

function Library:Connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(self.Connections, c)
    return c
end

function Library:Tween(inst, props, t)
    TweenService:Create(inst, TweenInfo.new(t or 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

function Library:Fire(obj)
    if obj.Callback then self:SafeCall(obj.Callback, obj.Value) end
    for _, fn in ipairs(obj.Changed) do self:SafeCall(fn, obj.Value) end
end

--// instance factory: New(class, props, themeMap)  themeMap = { Property = "ThemeKey" }
local TEXT_CLASS = { TextLabel = true, TextButton = true, TextBox = true }

function Library:New(class, props, theme)
    local inst = Instance.new(class)
    if class == "Frame" or class == "ScrollingFrame" or class == "ImageLabel" or class == "ImageButton" then
        inst.BorderSizePixel = 0
    end
    if class == "ImageLabel" or class == "ImageButton" then
        inst.BackgroundTransparency = 1
    end
    if TEXT_CLASS[class] then
        inst.BackgroundTransparency = 1
        inst.BorderSizePixel = 0
        inst.Font = self.Font
        inst.TextSize = self.TextSize
        inst.TextColor3 = self.Theme.Text
        inst.TextXAlignment = Enum.TextXAlignment.Left
        if class == "TextButton" then inst.AutoButtonColor = false end
    end
    local parent
    for k, v in pairs(props or {}) do
        if k == "Parent" then parent = v else inst[k] = v end
    end
    if theme then
        for prop, key in pairs(theme) do inst[prop] = self.Theme[key] end
        table.insert(self.Registry, { Inst = inst, Map = theme })
    end
    if parent then inst.Parent = parent end
    return inst
end

function Library:Stroke(parent, key)
    return self:New("UIStroke", {
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Thickness = 1,
        Parent = parent,
    }, { Color = key or "Border" })
end

local function ShineSequence()
    local a = Library.Theme.Accent
    local hi = a:Lerp(Color3.new(1, 1, 1), 0.55)
    return ColorSequence.new({
        ColorSequenceKeypoint.new(0, a),
        ColorSequenceKeypoint.new(0.5, hi),
        ColorSequenceKeypoint.new(1, a),
    })
end

function Library:RefreshTheme()
    for i = #self.Registry, 1, -1 do
        local e = self.Registry[i]
        if e.Inst.Parent == nil then
            table.remove(self.Registry, i)
        else
            for prop, key in pairs(e.Map) do e.Inst[prop] = self.Theme[key] end
        end
    end
    for g in pairs(self.Shines) do
        if g.Parent then g.Color = ShineSequence() else self.Shines[g] = nil end
    end
    for _, fn in ipairs(self.Updaters) do self:SafeCall(fn) end
end

function Library:SetTheme(key, color)
    assert(self.Theme[key] ~= nil, "unknown theme key: " .. tostring(key))
    self.Theme[key] = color
    self:RefreshTheme()
end

function Library:SetPreset(name)
    local c = self.Presets[name]
    assert(c, "unknown preset: " .. tostring(name))
    self:SetTheme("Accent", c)
end

--// ================================ icons ==================================
local ICON_ROOT, ICON_DIR = "MouseUI", "MouseUI/icons"
local FileIconCache = {}
local WarnedIcon = {}

local function Hash(s)
    local h = 5381
    for i = 1, #s do h = (h * 33 + s:byte(i)) % 4294967296 end
    return string.format("%08x", h)
end

local function DirectContent(src)
    if type(src) == "number" then return "rbxassetid://" .. tostring(math.floor(src)) end
    if type(src) ~= "string" then return nil end
    if src:match("^%d+$") then return "rbxassetid://" .. src end
    if src:match("^rbxassetid://") or src:match("^rbxasset://") or src:match("^rbxthumb://")
        or src:match("^rbxgameasset://") or src:find("roblox.com/asset", 1, true) then
        return src
    end
    return nil
end

local function EnsureIconDir()
    if not Library.Caps.Files then return false end
    local ok = pcall(function()
        if not Env.isfolder(ICON_ROOT) then Env.makefolder(ICON_ROOT) end
        if not Env.isfolder(ICON_DIR) then Env.makefolder(ICON_DIR) end
    end)
    return ok
end

local function FileContent(src)
    if FileIconCache[src] then return FileIconCache[src] end
    if not Library.Caps.Assets then
        if not WarnedIcon.assets then
            WarnedIcon.assets = true
            warn("[MouseUI] this executor lacks getcustomasset/filesystem; only rbxassetid icons work")
        end
        return nil
    end
    local path = src
    if src:match("^https?://") then
        if not EnsureIconDir() then return nil end
        path = ICON_DIR .. "/" .. Hash(src) .. ".png"
        local ok, have = pcall(Env.isfile, path)
        if not (ok and have) then
            local body
            if Env.request then
                local ok2, res = pcall(Env.request, { Url = src, Method = "GET" })
                if ok2 and type(res) == "table" and (res.StatusCode == nil or res.StatusCode == 200) then body = res.Body end
            end
            if type(body) ~= "string" or #body == 0 then
                body = nil
                if Env.httpget then
                    local ok3, res = pcall(Env.httpget, src)
                    if ok3 and type(res) == "string" then body = res end
                end
            end
            if type(body) ~= "string" or #body == 0 then
                body = nil
                local ok4, res = pcall(function() return game:HttpGet(src) end)
                if ok4 and type(res) == "string" then body = res end
            end
            if not body or #body == 0 then
                if not WarnedIcon[src] then WarnedIcon[src] = true; warn("[MouseUI] icon download failed: " .. src) end
                return nil
            end
            if not pcall(Env.writefile, path, body) then return nil end
        end
    else
        local ok, have = pcall(Env.isfile, path)
        if not (ok and have) then
            if not WarnedIcon[src] then WarnedIcon[src] = true; warn("[MouseUI] icon file not found: " .. src) end
            return nil
        end
    end
    local ok, content = pcall(Env.getcustomasset, path)
    if ok and content then
        FileIconCache[src] = content
        return content
    end
    return nil
end

-- src: asset id (number/string), rbxasset* url, https url, workspace file path,
--      or { Image = src, RectOffset = Vector2, RectSize = Vector2 } for spritesheets
function Library:ApplyIcon(img, src)
    if src == nil then img.Image = "" return end
    if type(src) == "table" then
        if src.RectOffset then img.ImageRectOffset = src.RectOffset end
        if src.RectSize then img.ImageRectSize = src.RectSize end
        src = src.Image or src.Source or src.Id
    end
    local direct = DirectContent(src)
    if direct then img.Image = direct return end
    if type(src) ~= "string" then return end
    task.spawn(function()
        local content = FileContent(src)
        if content and img.Parent then img.Image = content end
    end)
end

--// ================================= init ==================================
function Library:Init()
    if self.Gui then return end

    local function build(order)
        local gui = Instance.new("ScreenGui")
        gui.Name = RandomName()
        gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = true
        gui.DisplayOrder = order
        gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        if Env.protect then pcall(Env.protect, gui) end
        local candidates = {}
        if Env.gethui then
            local ok, h = pcall(Env.gethui)
            if ok and typeof(h) == "Instance" then table.insert(candidates, h) end
        end
        table.insert(candidates, CoreGui)
        if LocalPlayer then table.insert(candidates, LocalPlayer:WaitForChild("PlayerGui")) end
        for _, c in ipairs(candidates) do
            local ok = pcall(function() gui.Parent = c end)
            if ok and gui.Parent == c then break end
        end
        return gui
    end

    self.Gui = build(1000)
    self.PopupGui = build(1001)

    self.NotifyHolder = self:New("Frame", {
        Position = UDim2.fromOffset(10, 10),
        Size = UDim2.new(0, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.XY,
        BackgroundTransparency = 1,
        Parent = self.PopupGui,
    })
    self:New("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 4),
        Parent = self.NotifyHolder,
    })

    self:Connect(UserInputService.InputBegan, function(input)
        if IsPress(input) and self.Popup then
            local pos = UserInputService:GetMouseLocation()
            if not (Inside(self.Popup.Frame, pos) or Inside(self.Popup.Field, pos)) then
                self:ClosePopup()
            end
        end
        if input.KeyCode == self.ToggleKey and not UserInputService:GetFocusedTextBox() then
            self:SetVisible(not self.Visible)
        end
    end)

    self:Connect(RunService.Heartbeat, function()
        if not self.Shine then return end
        local x = -1 + 2 * ((os.clock() % 3) / 3)
        for g in pairs(self.Shines) do
            if g.Parent then g.Offset = Vector2.new(x, 0) else self.Shines[g] = nil end
        end
    end)

    genv.MouseUI = self
    genv.Toggles = self.Toggles
    genv.Options = self.Options
end

function Library:SetVisible(state)
    self.Visible = state and true or false
    self:ClosePopup()
    for _, w in ipairs(self.Windows) do w.Outer.Visible = self.Visible end
end

function Library:ClosePopup()
    if self.Popup then
        local p = self.Popup
        self.Popup = nil
        if p.Frame then p.Frame:Destroy() end
        if p.OnClose then self:SafeCall(p.OnClose) end
    end
end

function Library:OnUnload(fn)
    table.insert(self.UnloadCallbacks, fn)
end

function Library:Unload()
    if self.Unloaded then return end
    self.Unloaded = true
    for _, fn in ipairs(self.UnloadCallbacks) do self:SafeCall(fn) end
    for _, c in ipairs(self.Connections) do pcall(function() c:Disconnect() end) end
    if self.Gui then self.Gui:Destroy() end
    if self.PopupGui then self.PopupGui:Destroy() end
    if rawget(genv, "MouseUI") == self then genv.MouseUI = nil end
end

--// notifications
function Library:Notify(text, duration)
    self:Init()
    duration = duration or 4
    local Item = self:New("Frame", {
        Size = UDim2.fromOffset(0, 22),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
        LayoutOrder = NextOrder(self.NotifyHolder),
        Parent = self.NotifyHolder,
    }, { BackgroundColor3 = "Main" })
    local Bar = self:New("Frame", {
        Size = UDim2.new(0, 2, 1, 0),
        BackgroundTransparency = 1,
        Parent = Item,
    }, { BackgroundColor3 = "Accent" })
    local Label = self:New("TextLabel", {
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        Text = tostring(text),
        TextTransparency = 1,
        Parent = Item,
    }, { TextColor3 = "Text" })
    self:New("UIPadding", {
        PaddingLeft = UDim.new(0, 8),
        PaddingRight = UDim.new(0, 8),
        Parent = Label,
    })
    self:Tween(Item, { BackgroundTransparency = 0 }, 0.2)
    self:Tween(Bar, { BackgroundTransparency = 0 }, 0.2)
    self:Tween(Label, { TextTransparency = 0 }, 0.2)
    task.delay(duration, function()
        if not Item.Parent then return end
        self:Tween(Item, { BackgroundTransparency = 1 }, 0.3)
        self:Tween(Bar, { BackgroundTransparency = 1 }, 0.3)
        self:Tween(Label, { TextTransparency = 1 }, 0.3)
        task.delay(0.35, function() if Item.Parent then Item:Destroy() end end)
    end)
end

--// ============================== elements =================================
local Elements = {}
local ContainerMT = { __index = Elements }

local function NewContainer(frame)
    return setmetatable({ Frame = frame }, ContainerMT)
end

function Elements:_NewHolder()
    assert(self.Frame, "this element has no container; create it with Folding = true")
    local holder = Library:New("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = NextOrder(self.Frame),
        Parent = self.Frame,
    })
    Library:New("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 2),
        Parent = holder,
    })
    return holder
end

local function Common(obj, holder)
    obj.Holder = holder
    function obj:SetVisible(state) holder.Visible = state and true or false end
end

local function Register(kind, idx, obj)
    assert(type(idx) == "string", "element Idx must be a string")
    assert(not Library.Toggles[idx] and not Library.Options[idx], "duplicate Idx: " .. idx)
    Library[kind][idx] = obj
end

function Elements:AddLabel(text, wrap)
    local holder = self:_NewHolder()
    local Label = Library:New("TextLabel", {
        Size = UDim2.new(1, 0, 0, 14),
        AutomaticSize = wrap and Enum.AutomaticSize.Y or Enum.AutomaticSize.None,
        Text = tostring(text or ""),
        TextWrapped = wrap and true or false,
        TextTruncate = wrap and Enum.TextTruncate.None or Enum.TextTruncate.AtEnd,
        Parent = holder,
    }, { TextColor3 = "Text" })
    local obj = { Type = "Label" }
    Common(obj, holder)
    function obj:SetText(t) Label.Text = tostring(t) end
    return obj
end

function Elements:AddDivider()
    local holder = self:_NewHolder()
    local Row = Library:New("Frame", { Size = UDim2.new(1, 0, 0, 5), BackgroundTransparency = 1, Parent = holder })
    Library:New("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.new(1, 0, 0, 1),
        Parent = Row,
    }, { BackgroundColor3 = "Border" })
    local obj = { Type = "Divider" }
    Common(obj, holder)
    return obj
end

-- cfg: { Source = asset/url/file/table, Height = 64, Tint = Color3 | nil }
function Elements:AddImage(cfg)
    cfg = cfg or {}
    local holder = self:_NewHolder()
    local Img = Library:New("ImageLabel", {
        Size = UDim2.new(1, 0, 0, cfg.Height or 64),
        ScaleType = cfg.ScaleType or Enum.ScaleType.Fit,
        ImageColor3 = cfg.Tint or Color3.new(1, 1, 1),
        Parent = holder,
    })
    Library:ApplyIcon(Img, cfg.Source)
    local obj = { Type = "Image", Image = Img }
    Common(obj, holder)
    function obj:SetSource(src) Library:ApplyIcon(Img, src) end
    return obj
end

function Elements:AddButton(cfg, callback)
    if type(cfg) == "string" then cfg = { Text = cfg, Callback = callback } end
    cfg = cfg or {}
    local holder = self:_NewHolder()
    local Btn = Library:New("TextButton", {
        Size = UDim2.new(1, 0, 0, 18),
        Text = cfg.Text or "Button",
        TextXAlignment = Enum.TextXAlignment.Center,
        BackgroundTransparency = 0,
        Parent = holder,
    }, { BackgroundColor3 = "Field", TextColor3 = "Text" })
    Library:Stroke(Btn)
    local obj = { Type = "Button", Callback = cfg.Callback, Changed = {} }
    Common(obj, holder)
    Btn.MouseEnter:Connect(function() Library:Tween(Btn, { BackgroundColor3 = Library.Theme.Border }, 0.08) end)
    Btn.MouseLeave:Connect(function() Library:Tween(Btn, { BackgroundColor3 = Library.Theme.Field }, 0.08) end)
    Btn.MouseButton1Click:Connect(function()
        Library:ClosePopup()
        if obj.Callback then Library:SafeCall(obj.Callback) end
    end)
    function obj:SetText(t) Btn.Text = tostring(t) end
    return obj
end

function Elements:AddToggle(idx, cfg)
    cfg = cfg or {}
    local Toggle = {
        Type = "Toggle", Idx = idx,
        Value = cfg.Default == true,
        Callback = cfg.Callback, Changed = {},
    }
    Register("Toggles", idx, Toggle)

    local holder = self:_NewHolder()
    Common(Toggle, holder)

    local Row = Library:New("TextButton", {
        Size = UDim2.new(1, 0, 0, 16),
        LayoutOrder = 1,
        Text = "",
        Parent = holder,
    })
    local Box = Library:New("Frame", {
        Position = UDim2.new(0, 0, 0.5, -5),
        Size = UDim2.fromOffset(10, 10),
        Parent = Row,
    }, { BackgroundColor3 = "Field" })
    Library:Stroke(Box)
    local Fill = Library:New("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = Toggle.Value and 0 or 1,
        Parent = Box,
    }, { BackgroundColor3 = "Accent" })
    Library:New("TextLabel", {
        Position = UDim2.fromOffset(16, 0),
        Size = UDim2.new(1, cfg.Folding and -34 or -16, 1, 0),
        Text = cfg.Text or idx,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = Row,
    }, { TextColor3 = "Text" })

    function Toggle:SetValue(v)
        v = v and true or false
        if self.Value == v then return end
        self.Value = v
        Library:Tween(Fill, { BackgroundTransparency = v and 0 or 1 }, 0.1)
        Library:Fire(self)
    end
    function Toggle:OnChanged(fn) table.insert(self.Changed, fn) end
    Row.MouseButton1Click:Connect(function()
        Library:ClosePopup()
        Toggle:SetValue(not Toggle.Value)
    end)

    if cfg.Folding then
        local Arrow = Library:New("TextButton", {
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, 0, 0, 0),
            Size = UDim2.fromOffset(16, 16),
            Text = "+",
            TextXAlignment = Enum.TextXAlignment.Center,
            Parent = Row,
        }, { TextColor3 = "TextDim" })
        local Fold = Library:New("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            LayoutOrder = 2,
            Visible = false,
            Parent = holder,
        })
        Library:New("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 2),
            Parent = Fold,
        })
        Library:New("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingTop = UDim.new(0, 2), Parent = Fold })
        Toggle.Frame = Fold
        setmetatable(Toggle, ContainerMT)
        function Toggle:SetFolded(folded)
            Fold.Visible = not folded
            Arrow.Text = folded and "+" or "-"
        end
        Arrow.MouseButton1Click:Connect(function()
            Library:ClosePopup()
            Toggle:SetFolded(Fold.Visible)
        end)
        if cfg.Folded == false then Toggle:SetFolded(false) end
    end
    return Toggle
end

function Elements:AddSlider(idx, cfg)
    cfg = cfg or {}
    local Slider = {
        Type = "Slider", Idx = idx,
        Min = cfg.Min or 0, Max = cfg.Max or 100,
        Rounding = cfg.Rounding or 0,
        Suffix = cfg.Suffix or "",
        Callback = cfg.Callback, Changed = {},
    }
    Slider.Step = cfg.Step or 10 ^ (-Slider.Rounding)
    Slider.Value = math.clamp(Round(cfg.Default or Slider.Min, Slider.Rounding), Slider.Min, Slider.Max)
    Register("Options", idx, Slider)

    local holder = self:_NewHolder()
    Common(Slider, holder)

    local Top = Library:New("Frame", {
        Size = UDim2.new(1, 0, 0, 14),
        LayoutOrder = 1,
        BackgroundTransparency = 1,
        Parent = holder,
    })
    Library:New("TextLabel", {
        Size = UDim2.new(1, -56, 1, 0),
        Text = cfg.Text or idx,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = Top,
    }, { TextColor3 = "Text" })

    local function stepText()
        return string.format("%." .. math.max(Slider.Rounding, 1) .. "f", Slider.Step)
    end
    local StepLabel = Library:New("TextLabel", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -24, 0, 0),
        Size = UDim2.fromOffset(30, 14),
        Text = stepText(),
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = Top,
    }, { TextColor3 = "TextDim" })
    local Minus = Library:New("TextButton", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -12, 0, 0),
        Size = UDim2.fromOffset(12, 14),
        Text = "-",
        TextXAlignment = Enum.TextXAlignment.Center,
        Parent = Top,
    }, { TextColor3 = "Text" })
    local Plus = Library:New("TextButton", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.fromOffset(12, 14),
        Text = "+",
        TextXAlignment = Enum.TextXAlignment.Center,
        Parent = Top,
    }, { TextColor3 = "Text" })

    local Bar = Library:New("TextButton", {
        Size = UDim2.new(1, 0, 0, 12),
        LayoutOrder = 2,
        Text = "",
        BackgroundTransparency = 0,
        Parent = holder,
    }, { BackgroundColor3 = "Field" })
    Library:Stroke(Bar)
    local Fill = Library:New("Frame", { Size = UDim2.new(0, 0, 1, 0), Parent = Bar }, { BackgroundColor3 = "Accent" })
    local ValueLabel = Library:New("TextLabel", {
        Size = UDim2.new(1, 0, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Center,
        Parent = Bar,
    }, { TextColor3 = "Text" })

    local function render()
        local range = Slider.Max - Slider.Min
        local pct = range > 0 and (Slider.Value - Slider.Min) / range or 0
        Library:Tween(Fill, { Size = UDim2.new(pct, 0, 1, 0) }, 0.06)
        ValueLabel.Text = string.format("%." .. Slider.Rounding .. "f", Slider.Value) .. Slider.Suffix
    end
    render()

    function Slider:SetValue(v)
        v = math.clamp(Round(tonumber(v) or self.Value, self.Rounding), self.Min, self.Max)
        if v == self.Value then return end
        self.Value = v
        render()
        Library:Fire(self)
    end
    function Slider:SetStep(s)
        self.Step = s
        StepLabel.Text = stepText()
    end
    function Slider:OnChanged(fn) table.insert(self.Changed, fn) end

    Minus.MouseButton1Click:Connect(function() Slider:SetValue(Slider.Value - Slider.Step) end)
    Plus.MouseButton1Click:Connect(function() Slider:SetValue(Slider.Value + Slider.Step) end)

    local dragConn, endConn
    local function stop()
        if dragConn then dragConn:Disconnect() dragConn = nil end
        if endConn then endConn:Disconnect() endConn = nil end
    end
    local function update(x)
        local w = Bar.AbsoluteSize.X
        if w <= 0 then return end
        local pct = math.clamp((x - Bar.AbsolutePosition.X) / w, 0, 1)
        Slider:SetValue(Slider.Min + (Slider.Max - Slider.Min) * pct)
    end
    Bar.InputBegan:Connect(function(input)
        if not IsPress(input) then return end
        Library:ClosePopup()
        stop()
        update(input.Position.X)
        dragConn = UserInputService.InputChanged:Connect(function(i)
            if IsMove(i) then update(i.Position.X) end
        end)
        endConn = UserInputService.InputEnded:Connect(function(i)
            if IsPress(i) then stop() end
        end)
    end)
    Library:OnUnload(stop)
    return Slider
end

function Elements:AddDropdown(idx, cfg)
    cfg = cfg or {}
    local Dropdown = {
        Type = "Dropdown", Idx = idx,
        Values = cfg.Values or {},
        Multi = cfg.Multi == true,
        Callback = cfg.Callback, Changed = {},
    }
    Register("Options", idx, Dropdown)

    local function has(list, v)
        for _, x in ipairs(list) do if x == v then return true end end
        return false
    end

    if Dropdown.Multi then
        Dropdown.Value = {}
        local d = cfg.Default
        if type(d) == "table" then
            for k, v in pairs(d) do
                if type(k) == "number" and has(Dropdown.Values, v) then Dropdown.Value[v] = true
                elseif type(k) == "string" and v == true and has(Dropdown.Values, k) then Dropdown.Value[k] = true end
            end
        end
    else
        local d = cfg.Default
        if type(d) == "number" then d = Dropdown.Values[d] end
        if d ~= nil and has(Dropdown.Values, d) then
            Dropdown.Value = d
        elseif not cfg.AllowNull then
            Dropdown.Value = Dropdown.Values[1]
        end
    end

    local holder = self:_NewHolder()
    Common(Dropdown, holder)

    if cfg.Text then
        Library:New("TextLabel", {
            Size = UDim2.new(1, 0, 0, 14),
            LayoutOrder = 1,
            Text = cfg.Text,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = holder,
        }, { TextColor3 = "Text" })
    end
    local Field = Library:New("TextButton", {
        Size = UDim2.new(1, 0, 0, 18),
        LayoutOrder = 2,
        Text = "",
        BackgroundTransparency = 0,
        Parent = holder,
    }, { BackgroundColor3 = "Field" })
    Library:Stroke(Field)
    local ValueLabel = Library:New("TextLabel", {
        Position = UDim2.fromOffset(5, 0),
        Size = UDim2.new(1, -22, 1, 0),
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = Field,
    }, { TextColor3 = "Text" })
    Library:New("TextLabel", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -4, 0, 0),
        Size = UDim2.fromOffset(12, 18),
        Text = "-",
        TextXAlignment = Enum.TextXAlignment.Center,
        Parent = Field,
    }, { TextColor3 = "TextDim" })

    local function display()
        if Dropdown.Multi then
            local t = {}
            for _, v in ipairs(Dropdown.Values) do if Dropdown.Value[v] then t[#t + 1] = tostring(v) end end
            return #t > 0 and table.concat(t, ", ") or "..."
        end
        return Dropdown.Value ~= nil and tostring(Dropdown.Value) or "..."
    end
    local function render() ValueLabel.Text = display() end
    render()

    function Dropdown:SetValue(v)
        if self.Multi then
            local new = {}
            if type(v) == "table" then
                for k, x in pairs(v) do
                    if type(k) == "number" and has(self.Values, x) then new[x] = true
                    elseif type(k) == "string" and x == true and has(self.Values, k) then new[k] = true end
                end
            end
            self.Value = new
        else
            if v ~= nil and not has(self.Values, v) then return end
            self.Value = v
        end
        render()
        Library:Fire(self)
    end
    function Dropdown:SetValues(list)
        self.Values = list
        if self.Multi then
            for k in pairs(self.Value) do if not has(list, k) then self.Value[k] = nil end end
        elseif self.Value ~= nil and not has(list, self.Value) then
            self.Value = list[1]
        end
        if Library.Popup and Library.Popup.Owner == self then Library:ClosePopup() end
        render()
        Library:Fire(self)
    end
    function Dropdown:OnChanged(fn) table.insert(self.Changed, fn) end

    local function open()
        Library:ClosePopup()
        local abs, size = Field.AbsolutePosition, Field.AbsoluteSize
        local count = #Dropdown.Values
        local rows = math.min(math.max(count, 1), 8)
        local Popup = Library:New("Frame", {
            Position = UDim2.fromOffset(abs.X, abs.Y + size.Y + 1),
            Size = UDim2.fromOffset(size.X, rows * 16 + 2),
            Parent = Library.PopupGui,
        }, { BackgroundColor3 = "Field" })
        Library:Stroke(Popup, "Accent")
        local List = Library:New("ScrollingFrame", {
            Position = UDim2.fromOffset(0, 1),
            Size = UDim2.new(1, 0, 1, -2),
            BackgroundTransparency = 1,
            ScrollBarThickness = 2,
            CanvasSize = UDim2.fromOffset(0, count * 16),
            TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
            MidImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
            BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
            Parent = Popup,
        }, { ScrollBarImageColor3 = "Accent" })
        local buttons = {}
        local function paint()
            for v, b in pairs(buttons) do
                local on
                if Dropdown.Multi then on = Dropdown.Value[v] == true else on = Dropdown.Value == v end
                b.TextColor3 = on and Library.Theme.Accent or Library.Theme.Text
            end
        end
        for i, v in ipairs(Dropdown.Values) do
            local b = Library:New("TextButton", {
                Position = UDim2.fromOffset(0, (i - 1) * 16),
                Size = UDim2.new(1, 0, 0, 16),
                Text = tostring(v),
                Parent = List,
            })
            Library:New("UIPadding", { PaddingLeft = UDim.new(0, 5), Parent = b })
            buttons[v] = b
            b.MouseButton1Click:Connect(function()
                if Dropdown.Multi then
                    local new = {}
                    for k, x in pairs(Dropdown.Value) do new[k] = x end
                    if new[v] then new[v] = nil else new[v] = true end
                    Dropdown:SetValue(new)
                    paint()
                else
                    Dropdown:SetValue(v)
                    Library:ClosePopup()
                end
            end)
        end
        paint()
        Library.Popup = { Frame = Popup, Field = Field, Owner = Dropdown }
    end
    Field.MouseButton1Click:Connect(function()
        if Library.Popup and Library.Popup.Owner == Dropdown then Library:ClosePopup() else open() end
    end)
    return Dropdown
end

--// ================================ pages ==================================
local PageMethods = {}

local function BuildColumn(parent, pos, size)
    local Col = Library:New("ScrollingFrame", {
        Position = pos,
        Size = size,
        BackgroundTransparency = 1,
        ScrollBarThickness = 2,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
        MidImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
        BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
        Parent = parent,
    }, { ScrollBarImageColor3 = "Accent" })
    Library:New("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 6),
        Parent = Col,
    })
    Library:New("UIPadding", { PaddingRight = UDim.new(0, 4), Parent = Col })
    return Col
end

local function BuildColumns(parent)
    local Host = Library:New("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Parent = parent,
    })
    local Left = BuildColumn(Host, UDim2.new(0, 0, 0, 0), UDim2.new(0.5, -3, 1, 0))
    local Right = BuildColumn(Host, UDim2.new(0.5, 3, 0, 0), UDim2.new(0.5, -3, 1, 0))
    return Host, Left, Right
end

-- returns Box and the y offset where content starts
local function BuildBox(column, title)
    local Box = Library:New("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = NextOrder(column),
        Parent = column,
    }, { BackgroundColor3 = "Section" })
    Library:Stroke(Box)
    local Line = Library:New("Frame", { Size = UDim2.new(1, 0, 0, 2), Parent = Box }, { BackgroundColor3 = "Accent" })
    local Grad = Library:New("UIGradient", { Color = ShineSequence(), Parent = Line })
    Library.Shines[Grad] = true
    local top = 2
    if title then
        Library:New("TextLabel", {
            Position = UDim2.fromOffset(6, 4),
            Size = UDim2.new(1, -12, 0, 14),
            Text = title,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = Box,
        }, { TextColor3 = "Text" })
        top = 20
    end
    return Box, top
end

local function BuildContent(parent, y)
    local Content = Library:New("Frame", {
        Position = UDim2.fromOffset(0, y),
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = parent,
    })
    Library:New("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 3),
        Parent = Content,
    })
    Library:New("UIPadding", {
        PaddingTop = UDim.new(0, 4),
        PaddingBottom = UDim.new(0, 6),
        PaddingLeft = UDim.new(0, 6),
        PaddingRight = UDim.new(0, 6),
        Parent = Content,
    })
    return Content
end

local function ColumnFor(page, side)
    if tostring(side or "Left"):lower() == "right" then return page.Right end
    return page.Left
end

function PageMethods:AddSection(cfg)
    if type(cfg) == "string" then cfg = { Name = cfg } end
    cfg = cfg or {}
    local Box, top = BuildBox(ColumnFor(self, cfg.Side), cfg.Name or "Section")
    local Section = NewContainer(BuildContent(Box, top))
    Section.Box = Box
    function Section:SetVisible(state) Box.Visible = state and true or false end
    return Section
end

-- cfg: { Tabs = {"A","B"}, Side = "Right" } -> returns one container per tab
function PageMethods:AddMultiSection(cfg)
    cfg = cfg or {}
    local names = cfg.Tabs or cfg
    assert(type(names) == "table" and #names > 0, "AddMultiSection needs a Tabs list")
    local Box = BuildBox(ColumnFor(self, cfg.Side), nil)

    local Strip = Library:New("Frame", {
        Position = UDim2.fromOffset(0, 2),
        Size = UDim2.new(1, 0, 0, 19),
        BackgroundTransparency = 1,
        Parent = Box,
    })
    Library:New("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = Strip,
    })
    Library:New("Frame", {
        Position = UDim2.fromOffset(0, 21),
        Size = UDim2.new(1, 0, 0, 1),
        Parent = Box,
    }, { BackgroundColor3 = "Border" })

    local Pages = Library:New("Frame", {
        Position = UDim2.fromOffset(0, 22),
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = Box,
    })
    Library:New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = Pages })

    local entries, containers = {}, {}
    local function select(target)
        Library:ClosePopup()
        for _, e in ipairs(entries) do
            e.Content.Visible = (e == target)
            e.Button:SetActive(e == target)
        end
    end
    for i, name in ipairs(names) do
        local entry = {}
        entry.Content = BuildContent(Pages, 0)
        entry.Content.LayoutOrder = i
        entry.Content.Visible = false
        entry.Button = Library.BuildButton(Strip, { Name = tostring(name), Compact = true }, function() select(entry) end)
        entries[i] = entry
        local c = NewContainer(entry.Content)
        c.Box = Box
        containers[i] = c
    end
    select(entries[1])
    return table.unpack(containers)
end

--// tab / subtab buttons (text, icon, or both)
function Library.BuildButton(parent, cfg, onClick)
    local B = { Active = false }
    B.Frame = Library:New("Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
        LayoutOrder = NextOrder(parent),
        Parent = parent,
    })
    local Inner = Library:New("Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
        Parent = B.Frame,
    })
    Library:New("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 5),
        Parent = Inner,
    })
    local pad = cfg.Compact and 6 or 10
    Library:New("UIPadding", {
        PaddingLeft = UDim.new(0, pad),
        PaddingRight = UDim.new(0, pad),
        Parent = Inner,
    })
    local Icon, Label
    if cfg.Icon ~= nil then
        local s = cfg.IconSize or 14
        Icon = Library:New("ImageLabel", {
            Size = UDim2.fromOffset(s, s),
            LayoutOrder = 1,
            ScaleType = Enum.ScaleType.Fit,
            Parent = Inner,
        })
        Library:ApplyIcon(Icon, cfg.Icon)
    end
    if not (cfg.IconOnly and cfg.Icon ~= nil) then
        Label = Library:New("TextLabel", {
            Size = UDim2.new(0, 0, 1, 0),
            AutomaticSize = Enum.AutomaticSize.X,
            LayoutOrder = 2,
            Text = cfg.Name or "Tab",
            Parent = Inner,
        })
    end
    local Underline = Library:New("Frame", {
        Position = UDim2.new(0, 0, 1, -1),
        Size = UDim2.new(1, 0, 0, 1),
        Visible = false,
        Parent = B.Frame,
    }, { BackgroundColor3 = "Accent" })
    local Click = Library:New("TextButton", {
        Size = UDim2.new(1, 0, 1, 0),
        Text = "",
        ZIndex = 2,
        Parent = B.Frame,
    })
    Click.MouseButton1Click:Connect(function() onClick() end)

    function B:Render()
        local col = self.Active and Library.Theme.Text or Library.Theme.TextDim
        if Label then Label.TextColor3 = col end
        if Icon and cfg.Tint ~= false then Icon.ImageColor3 = col end
        Underline.Visible = self.Active
    end
    function B:SetActive(state)
        self.Active = state and true or false
        self:Render()
    end
    B:Render()
    table.insert(Library.Updaters, function() B:Render() end)
    return B
end

local SubTabMethods = setmetatable({}, { __index = PageMethods })
local SubTabMT = { __index = SubTabMethods }
local TabMethods = setmetatable({}, { __index = PageMethods })
local TabMT = { __index = TabMethods }

-- cfg: "Name" or { Name, Icon, IconOnly, IconSize, Tint }
function TabMethods:AddSubTab(cfg)
    if type(cfg) == "string" then cfg = { Name = cfg } end
    cfg = cfg or {}
    if not self.Strip then
        self.Strip = Library:New("Frame", {
            Size = UDim2.new(1, 0, 0, 26),
            BackgroundTransparency = 1,
            Parent = self.Page,
        })
        Library:New("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = self.Strip,
        })
        Library:New("Frame", {
            Position = UDim2.fromOffset(0, 26),
            Size = UDim2.new(1, 0, 0, 1),
            Parent = self.Page,
        }, { BackgroundColor3 = "Border" })
        self.Body.Position = UDim2.fromOffset(0, 32)
        self.Body.Size = UDim2.new(1, 0, 1, -32)
        self.Cols.Visible = false
    end
    local Sub = setmetatable({ Name = cfg.Name or "Sub", Tab = self }, SubTabMT)
    Sub.Host, Sub.Left, Sub.Right = BuildColumns(self.Body)
    Sub.Host.Visible = false
    Sub.Button = Library.BuildButton(self.Strip, cfg, function() self:SelectSubTab(Sub) end)
    table.insert(self.SubTabs, Sub)
    if not self.ActiveSub then self:SelectSubTab(Sub) end
    return Sub
end

function TabMethods:SelectSubTab(target)
    Library:ClosePopup()
    self.ActiveSub = target
    for _, s in ipairs(self.SubTabs) do
        s.Host.Visible = (s == target)
        s.Button:SetActive(s == target)
    end
end

--// ================================ window =================================
local WindowMethods = {}
local WindowMT = { __index = WindowMethods }

function Library:CreateWindow(cfg)
    self:Init()
    cfg = cfg or {}
    local size = cfg.Size or UDim2.fromOffset(540, 580)
    local Window = setmetatable({ Tabs = {}, Library = self }, WindowMT)

    Window.Outer = self:New("Frame", {
        Name = "Window",
        Size = size,
        Position = cfg.Position or UDim2.new(0.5, -size.X.Offset / 2, 0.5, -size.Y.Offset / 2),
        Visible = self.Visible,
        Parent = self.Gui,
    }, { BackgroundColor3 = "Outline" })
    local Inner = self:New("Frame", {
        Position = UDim2.fromOffset(1, 1),
        Size = UDim2.new(1, -2, 1, -2),
        ClipsDescendants = true,
        Parent = Window.Outer,
    }, { BackgroundColor3 = "Main" })

    local TitleBar = self:New("Frame", {
        Size = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1,
        Parent = Inner,
    })
    Window.TitleLabel = self:New("TextLabel", {
        Position = UDim2.fromOffset(6, 0),
        Size = UDim2.new(1, -12, 1, 0),
        Text = cfg.Title or "MouseUI",
        Parent = TitleBar,
    }, { TextColor3 = "Text" })

    Window.TabBar = self:New("Frame", {
        Position = UDim2.fromOffset(6, 22),
        Size = UDim2.new(1, -12, 0, 22),
        Parent = Inner,
    }, { BackgroundColor3 = "Section" })
    self:Stroke(Window.TabBar)
    self:New("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = Window.TabBar,
    })
    self:New("Frame", {
        Position = UDim2.fromOffset(6, 45),
        Size = UDim2.new(1, -12, 0, 1),
        Parent = Inner,
    }, { BackgroundColor3 = "Accent" })
    Window.Body = self:New("Frame", {
        Position = UDim2.fromOffset(6, 51),
        Size = UDim2.new(1, -12, 1, -57),
        BackgroundTransparency = 1,
        Parent = Inner,
    })

    -- dragging
    local dragConn, endConn
    local function stopDrag()
        if dragConn then dragConn:Disconnect() dragConn = nil end
        if endConn then endConn:Disconnect() endConn = nil end
    end
    TitleBar.InputBegan:Connect(function(input)
        if not IsPress(input) then return end
        self:ClosePopup()
        stopDrag()
        local startMouse = Vector2.new(input.Position.X, input.Position.Y)
        local startPos = Window.Outer.Position
        dragConn = UserInputService.InputChanged:Connect(function(i)
            if not IsMove(i) then return end
            local d = Vector2.new(i.Position.X, i.Position.Y) - startMouse
            Window.Outer.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end)
        endConn = UserInputService.InputEnded:Connect(function(i)
            if IsPress(i) then stopDrag() end
        end)
    end)
    self:OnUnload(stopDrag)

    -- touch devices without a keyboard get an on-screen toggle
    local wantButton = cfg.MobileButton
    if wantButton == nil then
        wantButton = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
    end
    if wantButton then
        local MB = self:New("TextButton", {
            Position = UDim2.fromOffset(10, 120),
            Size = UDim2.fromOffset(60, 24),
            Text = "Menu",
            TextXAlignment = Enum.TextXAlignment.Center,
            BackgroundTransparency = 0,
            Parent = self.Gui,
        }, { BackgroundColor3 = "Main", TextColor3 = "Text" })
        self:Stroke(MB, "Accent")
        MB.MouseButton1Click:Connect(function() self:SetVisible(not self.Visible) end)
    end

    if cfg.ToggleKey then self.ToggleKey = cfg.ToggleKey end
    table.insert(self.Windows, Window)
    return Window
end

function WindowMethods:SetTitle(text) self.TitleLabel.Text = tostring(text) end
function WindowMethods:SetVisible(state) self.Outer.Visible = state and true or false end

-- cfg: "Name" or { Name, Icon, IconOnly, IconSize, Tint }
function WindowMethods:AddTab(cfg)
    if type(cfg) == "string" then cfg = { Name = cfg } end
    cfg = cfg or {}
    local Tab = setmetatable({ Name = cfg.Name or "Tab", Window = self, SubTabs = {} }, TabMT)
    Tab.Button = Library.BuildButton(self.TabBar, cfg, function() self:SelectTab(Tab) end)
    Tab.Page = Library:New("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Visible = false,
        Parent = self.Body,
    })
    Tab.Body = Library:New("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Parent = Tab.Page,
    })
    Tab.Cols, Tab.Left, Tab.Right = BuildColumns(Tab.Body)
    table.insert(self.Tabs, Tab)
    if not self.Active then self:SelectTab(Tab) end
    return Tab
end

function WindowMethods:SelectTab(target)
    Library:ClosePopup()
    self.Active = target
    for _, t in ipairs(self.Tabs) do
        t.Page.Visible = (t == target)
        t.Button:SetActive(t == target)
    end
end

return Library
