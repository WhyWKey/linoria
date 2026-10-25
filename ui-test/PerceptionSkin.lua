local function Apply(Library, Config)

assert(type(Library) == 'table' and type(Library.Create) == 'function' and type(Library.CreateWindow) == 'function', 'PerceptionSkin: pass the Linoria Library as the first argument')
if type(Library.__PerceptionSkin) == 'table' then
    return Library.__PerceptionSkin
end
Config = type(Config) == 'table' and Config or {}

local Players = game:GetService('Players')
local LocalPlayer = Players.LocalPlayer

local function opt(key, default)
    local v = Config[key]
    if v == nil then return default end
    return v
end

local BLACK = Color3.new(0, 0, 0)
local WHITE = Color3.new(1, 1, 1)
local HEADER = 54
local PILL_H = 34
local TAB_W = 38
local TAB_GAP = 2

local Theme = {
    FontColor = Color3.fromRGB(210, 210, 214),
    MutedColor = Color3.fromRGB(122, 122, 134),
    MainColor = Color3.fromRGB(32, 32, 38),
    BackgroundColor = Color3.fromRGB(26, 26, 31),
    PanelColor = Color3.fromRGB(20, 20, 24),
    PillColor = Color3.fromRGB(14, 14, 17),
    OutlineColor = Color3.fromRGB(48, 48, 56),
    AccentColor = opt('Accent', Color3.fromRGB(110, 201, 200)),
}
if type(Config.Theme) == 'table' then
    for k, v in next, Config.Theme do Theme[k] = v end
end
for k, v in next, Theme do Library[k] = v end

local function Darker(c)
    if type(Library.GetDarkerColor) == 'function' then
        local ok, r = pcall(Library.GetDarkerColor, Library, c)
        if ok and r then return r end
    end
    local h, s, v = Color3.toHSV(c)
    return Color3.fromHSV(h, s, v * 0.6)
end
Library.AccentColorDark = Darker(Library.AccentColor)
Library.Font = opt('Font', Enum.Font.Gotham)
Library.FontSize = opt('FontSize', 13)

local Radius = opt('Radius', 10)
local PanelTransparency = opt('PanelTransparency', 0.05)
local CardTransparency = opt('CardTransparency', 0.4)
local Debug = opt('Debug', false)

local OrigCreate = Library.Create
local OrigOnHighlight = Library.OnHighlight
local OrigCreateWindow = Library.CreateWindow

local Wrappers = setmetatable({}, { __mode = 'k' })
local Inners = setmetatable({}, { __mode = 'k' })
local Rows = setmetatable({}, { __mode = 'k' })
local Popups = setmetatable({}, { __mode = 'k' })
local Seen = setmetatable({}, { __mode = 'k' })
local CapStack = {}
local Cards = setmetatable({}, { __mode = 'k' })
local Panels = {}

local function New(class, props)
    return OrigCreate(Library, class, props)
end

local function Warn(where, err)
    if Debug then warn('[PerceptionSkin] ' .. where .. ': ' .. tostring(err)) end
end

local function Guard(where, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then Warn(where, err) end
    return ok
end

local function Reg(inst, props, hud)
    Library:RemoveFromRegistry(inst)
    Library:AddToRegistry(inst, props, hud)
end

local function Corner(inst, r)
    return New('UICorner', { CornerRadius = UDim.new(0, r), Parent = inst })
end

local function Stroke(inst, colorName, thickness, transparency)
    local s = New('UIStroke', {
        Color = Library[colorName] or Library.OutlineColor,
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = inst,
    })
    Library:AddToRegistry(s, { Color = colorName })
    return s
end

local function Strip(inst)
    for _, c in ipairs(inst:GetChildren()) do
        if c:IsA('UICorner') or c:IsA('UIStroke') or c:IsA('UIGradient') then
            Library:RemoveFromRegistry(c)
            c:Destroy()
        end
    end
end

local function Flat(inst)
    Strip(inst)
    inst.BackgroundTransparency = 1
    inst.BorderSizePixel = 0
end

local function Capture(fn, ...)
    local list = { set = {} }
    CapStack[#CapStack + 1] = list
    local res = table.pack(pcall(fn, ...))
    table.remove(CapStack)
    return list, res
end

local function Generic(inst, props)
    local class = inst.ClassName
    if class == 'UIGradient' then
        local ok, kp = pcall(function() return inst.Color.Keypoints end)
        if ok and kp and #kp == 2 and math.abs(kp[2].Value.R * 255 - 212) < 1 and math.abs(kp[2].Value.G * 255 - 212) < 1 then
            inst:Destroy()
        end
        return
    end
    if class ~= 'Frame' then return end
    if inst.BackgroundTransparency >= 1 then return end

    local bst = inst.BorderSizePixel
    local bg, bc = inst.BackgroundColor3, inst.BorderColor3
    local parent = inst.Parent

    if props.Name == 'Color' and bg == WHITE then
        inst.BackgroundColor3 = Library.BackgroundColor
        inst.BorderSizePixel = 0
        Reg(inst, { BackgroundColor3 = 'BackgroundColor' })
        Corner(inst, 8)
        Stroke(inst, 'OutlineColor', 1, 0.2)
        Popups[inst] = true
        return
    end

    if parent and Popups[parent] then
        inst.BorderSizePixel = 0
        if bg == Library.BackgroundColor then inst.BackgroundTransparency = 1 end
        return
    end

    if parent and Wrappers[parent] and not Inners[parent] then
        Inners[parent] = inst
        inst.BorderSizePixel = 0
        Corner(inst, 4)
        if bc == Library.OutlineColor then
            Stroke(inst, 'OutlineColor', 1, 0)
        else
            New('UIStroke', { Color = bc, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = inst })
        end
        return
    end

    if bst == 0 then return end

    if bg == BLACK and bc == BLACK then
        inst.BackgroundTransparency = 1
        inst.BorderSizePixel = 0
        Wrappers[inst] = true
        return
    end

    if props.BorderMode == Enum.BorderMode.Middle then
        Rows[inst] = true
        inst.BorderSizePixel = 0
        inst.BackgroundTransparency = 1
        return
    end

    inst.BorderSizePixel = 0
    if bc ~= BLACK then
        Corner(inst, 3)
        Stroke(inst, 'OutlineColor', 1, 0.2)
    end
end

Library.Create = function(self, Class, Props)
    local inst = OrigCreate(self, Class, Props)
    for i = 1, #CapStack do
        local list = CapStack[i]
        if not list.set[inst] then
            list.set[inst] = true
            list[#list + 1] = inst
        end
    end
    if not Seen[inst] then
        Seen[inst] = true
        Guard('Generic', Generic, inst, Props or {})
    end
    return inst
end

Library.ApplyTextStroke = function(self, inst)
    inst.TextStrokeTransparency = 1
end

Library.OnHighlight = function(self, Highlight, Target, On, Off)
    if Wrappers[Target] and (On.BorderColor3 or Off.BorderColor3) then
        local function stroke()
            local inner = Inners[Target]
            return inner and inner:FindFirstChildOfClass('UIStroke')
        end
        Highlight.MouseEnter:Connect(function()
            local s = stroke()
            if s then s.Color = Library.AccentColor end
        end)
        Highlight.MouseLeave:Connect(function()
            local s = stroke()
            if s then s.Color = Library.OutlineColor end
        end)
        return
    end
    if Rows[Target] then
        Highlight.MouseEnter:Connect(function()
            Target.BackgroundColor3 = Library.AccentColor
            Target.BackgroundTransparency = 0.86
            if On.ZIndex then Target.ZIndex = On.ZIndex end
        end)
        Highlight.MouseLeave:Connect(function()
            Target.BackgroundTransparency = 1
            if Off.ZIndex then Target.ZIndex = Off.ZIndex end
        end)
        return
    end
    return OrigOnHighlight(self, Highlight, Target, On, Off)
end

local function WrapFn(tbl, name, post)
    local orig = tbl[name]
    if type(orig) ~= 'function' then return end
    tbl[name] = function(self, ...)
        local list, res = Capture(orig, self, ...)
        if not res[1] then error(res[2], 0) end
        Guard(name, post, self, res[2], list, ...)
        return table.unpack(res, 2, res.n)
    end
end

local function Muted(inst)
    inst.TextColor3 = Library.MutedColor
    Reg(inst, { TextColor3 = 'MutedColor' })
end

local function SkinToggle(Groupbox, Toggle, list)
    local Label = Toggle.TextLabel
    local Inner = Label.Parent
    local Outer = Inner.Parent
    local Region
    for _, c in ipairs(Outer:GetChildren()) do
        if c ~= Inner and c:IsA('Frame') then Region = c end
    end

    Outer.Size = UDim2.new(1, -4, 0, 16)
    Strip(Inner)
    Inner.BackgroundTransparency = 1
    Inner.BorderSizePixel = 0
    Label.Position = UDim2.new(0, 0, 0, 0)
    Label.Size = UDim2.new(1, -24, 1, 0)
    Label.TextXAlignment = Enum.TextXAlignment.Left
    local layout = Label:FindFirstChildOfClass('UIListLayout')
    if layout then layout.VerticalAlignment = Enum.VerticalAlignment.Center end
    if Region then Region.Size = UDim2.new(1, 0, 1, 0) end

    local Box = New('Frame', {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(15, 15),
        BackgroundColor3 = Library.MainColor,
        BorderSizePixel = 0,
        ZIndex = 7,
        Parent = Inner,
    })
    Corner(Box, 4)
    local BoxStroke = New('UIStroke', {
        Color = Library.OutlineColor,
        Thickness = 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = Box,
    })
    local Check = New('Frame', {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 1, 0),
        ZIndex = 8,
        Visible = false,
        Parent = Box,
    })
    New('Frame', {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromOffset(5, 8),
        Size = UDim2.fromOffset(2, 5),
        Rotation = -45,
        BackgroundColor3 = Color3.fromRGB(16, 22, 22),
        BorderSizePixel = 0,
        ZIndex = 8,
        Parent = Check,
    })
    New('Frame', {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromOffset(8.5, 6.5),
        Size = UDim2.fromOffset(2, 9),
        Rotation = 45,
        BackgroundColor3 = Color3.fromRGB(16, 22, 22),
        BorderSizePixel = 0,
        ZIndex = 8,
        Parent = Check,
    })
    Library:AddToRegistry(Box, { BackgroundColor3 = 'MainColor' })
    Library:AddToRegistry(BoxStroke, { Color = 'OutlineColor' })

    local hover = false
    local function apply()
        local on = Toggle.Value and true or false
        Box.BackgroundColor3 = on and Library.AccentColor or Library.MainColor
        BoxStroke.Color = (on or hover) and Library.AccentColor or Library.OutlineColor
        Check.Visible = on
        local rb = Library.RegistryMap[Box]
        if rb then rb.Properties.BackgroundColor3 = on and 'AccentColor' or 'MainColor' end
        local rs = Library.RegistryMap[BoxStroke]
        if rs then rs.Properties.Color = (on or hover) and 'AccentColor' or 'OutlineColor' end
    end

    local origDisplay = Toggle.Display
    Toggle.Display = function(t, ...)
        origDisplay(t, ...)
        Inner.BackgroundTransparency = 1
        apply()
    end
    Inner.BackgroundTransparency = 1
    apply()

    if Region then
        Region.MouseEnter:Connect(function() hover = true; apply() end)
        Region.MouseLeave:Connect(function() hover = false; apply() end)
    end
    Groupbox:Resize()
end

local function SkinSlider(Groupbox, Slider, list, Idx, Info)
    local Container = Groupbox.Container
    local Label, Outer
    for _, i in ipairs(list) do
        if i.Parent == Container then
            if i.ClassName == 'TextLabel' and not Label then Label = i end
            if i.ClassName == 'Frame' and not Outer and i.Size.Y.Offset == 13 and i.Size.X.Offset == -4 then Outer = i end
        end
    end
    if not Outer then return end
    local Inner = Outer:FindFirstChildOfClass('Frame')
    if not Inner then return end
    local Fill = Inner:FindFirstChildOfClass('Frame')
    local DisplayLabel = Inner:FindFirstChildOfClass('TextLabel')
    if not (Fill and DisplayLabel) then return end
    local Hide = Fill:FindFirstChildOfClass('Frame')

    local compact = Info and Info.Compact
    local yc = compact and 19 or 6
    Outer.Size = UDim2.new(1, -4, 0, compact and 24 or 12)
    Strip(Inner)
    Inner.BackgroundTransparency = 1
    Inner.BorderSizePixel = 0

    local Track = New('Frame', {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 0, 0, yc),
        Size = UDim2.new(1, 0, 0, 3),
        BackgroundColor3 = Library.MainColor,
        BorderSizePixel = 0,
        ZIndex = Fill.ZIndex - 1,
        Parent = Inner,
    })
    Corner(Track, 2)
    Library:AddToRegistry(Track, { BackgroundColor3 = 'OutlineColor' })
    Track.BackgroundColor3 = Library.OutlineColor

    Strip(Fill)
    Fill.BorderSizePixel = 0
    Fill.AnchorPoint = Vector2.new(0, 0.5)
    Fill.Position = UDim2.new(0, 0, 0, yc)
    Corner(Fill, 2)
    if Hide then Hide.Visible = false end

    local Value
    if Label then
        Label.Size = UDim2.new(1, 0, 0, 14)
        Label.TextYAlignment = Enum.TextYAlignment.Center
        Value = Library:CreateLabel({
            Size = UDim2.new(1, 0, 1, 0),
            TextSize = Library.FontSize,
            TextXAlignment = Enum.TextXAlignment.Right,
            Text = '',
            ZIndex = Label.ZIndex,
            Parent = Label,
        })
        Muted(Value)
        DisplayLabel.Visible = false
    else
        DisplayLabel.Size = UDim2.new(1, 0, 0, 14)
        DisplayLabel.Position = UDim2.new(0, 0, 0, 0)
        DisplayLabel.TextXAlignment = Enum.TextXAlignment.Left
    end

    local function sync()
        Fill.Size = UDim2.new(0, Fill.Size.X.Offset, 0, 3)
        if Hide then Hide.Visible = false end
        if Value then
            local txt = DisplayLabel.Text
            Value.Text = txt:match('^(.-)/') or txt
        end
    end

    local origDisplay = Slider.Display
    Slider.Display = function(s, ...)
        origDisplay(s, ...)
        sync()
    end

    local function measure()
        local w = Inner.AbsoluteSize.X
        if w and w > 8 then
            Slider.MaxSize = w
            Slider:Display()
        end
    end
    Inner:GetPropertyChangedSignal('AbsoluteSize'):Connect(measure)
    measure()
    Slider:Display()
    Groupbox:Resize()
end

local function SkinDropdown(Groupbox, Dropdown, list)
    local Container = Groupbox.Container
    local Label, Outer
    for _, i in ipairs(list) do
        if i.Parent == Container then
            if i.ClassName == 'TextLabel' and not Label then Label = i end
            if i.ClassName == 'Frame' and not Outer and i.Size.Y.Offset == 20 and i.Size.X.Offset == -4 then Outer = i end
        end
    end
    if Label then
        Label.Size = UDim2.new(1, 0, 0, 14)
        Label.TextYAlignment = Enum.TextYAlignment.Center
    end
    if not Outer then return end
    local Inner = Outer:FindFirstChildOfClass('Frame')
    if not Inner then return end
    local Arrow = Inner:FindFirstChildOfClass('ImageLabel')
    local Text = Inner:FindFirstChildOfClass('TextLabel')
    if Arrow then
        Arrow.Size = UDim2.fromOffset(10, 10)
        Arrow.Position = UDim2.new(1, -17, 0.5, 0)
        Arrow.ImageColor3 = Library.MutedColor
        Library:AddToRegistry(Arrow, { ImageColor3 = 'MutedColor' })
    end
    if Text then
        Text.Position = UDim2.new(0, 8, 0, 0)
        Text.Size = UDim2.new(1, -28, 1, 0)
        Text.TextWrapped = false
        Text.TextTruncate = Enum.TextTruncate.AtEnd
    end
    Groupbox:Resize()
end

local function SkinColorPicker(Parent, ColorPicker)
    local DF = ColorPicker.DisplayFrame
    if not DF then return end
    Strip(DF)
    DF.BorderSizePixel = 0
    DF.Size = UDim2.fromOffset(16, 16)
    Corner(DF, 4)
    New('UIStroke', {
        Color = BLACK,
        Transparency = 0.55,
        Thickness = 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = DF,
    })
    local checker = DF:FindFirstChildOfClass('ImageLabel')
    if checker then
        checker.Size = UDim2.new(1, 0, 1, 0)
        Corner(checker, 4)
    end
    local label = Parent and Parent.TextLabel
    local layout = label and label:FindFirstChildOfClass('UIListLayout')
    if layout then layout.VerticalAlignment = Enum.VerticalAlignment.Center end
end

local function SkinKeyPicker(Parent, KeyPicker, list)
    local label = Parent and Parent.TextLabel
    local layout = label and label:FindFirstChildOfClass('UIListLayout')
    if layout then layout.VerticalAlignment = Enum.VerticalAlignment.Center end
end

local function PatchFuncs(Funcs)
    if type(Funcs) ~= 'table' or Funcs.__PerceptionSkin then return end
    Funcs.__PerceptionSkin = true
    WrapFn(Funcs, 'AddToggle', SkinToggle)
    WrapFn(Funcs, 'AddSlider', SkinSlider)
    WrapFn(Funcs, 'AddDropdown', SkinDropdown)
    WrapFn(Funcs, 'AddColorPicker', SkinColorPicker)
    WrapFn(Funcs, 'AddKeyPicker', SkinKeyPicker)
end

local function PatchFrom(obj)
    local mt = getmetatable(obj)
    if type(mt) == 'table' and type(mt.__index) == 'table' then
        PatchFuncs(mt.__index)
    end
end

local function SkinGroupbox(Groupbox)
    local Container = Groupbox.Container
    local BoxInner = Container.Parent
    local BoxOuter = BoxInner.Parent

    Strip(BoxOuter)
    BoxOuter.BorderSizePixel = 0
    BoxOuter.BackgroundTransparency = CardTransparency
    Cards[BoxOuter] = true
    Corner(BoxOuter, 8)
    Stroke(BoxOuter, 'OutlineColor', 1, 0.5)

    Strip(BoxInner)
    BoxInner.BackgroundTransparency = 1
    BoxInner.BorderSizePixel = 0
    BoxInner.Position = UDim2.new(0, 0, 0, 0)
    BoxInner.Size = UDim2.new(1, 0, 1, 0)

    for _, c in ipairs(BoxInner:GetChildren()) do
        if c:IsA('Frame') and c ~= Container and c.Size.Y.Offset == 2 and c.BorderSizePixel == 0 then
            c.Visible = false
        elseif c:IsA('TextLabel') then
            c.Position = UDim2.new(0, 12, 0, 6)
            c.Size = UDim2.new(1, -24, 0, 18)
            c.TextXAlignment = Enum.TextXAlignment.Left
            c.TextSize = Library.FontSize - 1
            Muted(c)
        end
    end

    Container.Position = UDim2.new(0, 12, 0, 30)
    Container.Size = UDim2.new(1, -24, 1, -30)

    Groupbox.Resize = function(g)
        local Size = 0
        for _, El in ipairs(Container:GetChildren()) do
            if El:IsA('GuiObject') and El.Visible then
                Size = Size + El.Size.Y.Offset
            end
        end
        BoxOuter.Size = UDim2.new(1, 0, 0, 30 + Size + 8)
    end
    Groupbox:Resize()
end

local Glyphs = {
    legit = 'crosshair', aim = 'crosshair', aimbot = 'crosshair', combat = 'crosshair',
    rage = 'target', ragebot = 'target', main = 'target',
    visuals = 'eye', visual = 'eye', esp = 'eye', render = 'eye',
    world = 'globe', environment = 'globe', lighting = 'globe',
    players = 'people', player = 'people', users = 'people', entity = 'people',
    misc = 'bomb', miscellaneous = 'bomb', exploits = 'bomb', other = 'bomb',
    teleport = 'diamond', teleports = 'diamond', movement = 'diamond', locations = 'diamond',
    settings = 'gear', config = 'gear', configs = 'gear', ['ui settings'] = 'gear', options = 'gear',
}
if type(Config.Icons) == 'table' then
    for k, v in next, Config.Icons do Glyphs[string.lower(k)] = v end
end

local function BuildIcon(Parent, Name, state)
    local items = {}
    local function color()
        return state.active and Library.AccentColor or Library.MutedColor
    end
    local function ink(inst, prop)
        inst[prop] = color()
        items[#items + 1] = { inst, prop }
        Library:AddToRegistry(inst, { [prop] = color })
    end

    local P = New('Frame', {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.fromOffset(20, 20),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 3,
        Parent = Parent,
    })

    local function ring(w, h, x, y, th, cr)
        local f = New('Frame', {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, x or 0, 0.5, y or 0),
            Size = UDim2.fromOffset(w, h or w),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ZIndex = 3,
            Parent = P,
        })
        New('UICorner', { CornerRadius = cr or UDim.new(1, 0), Parent = f })
        local s = New('UIStroke', { Thickness = th or 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = f })
        ink(s, 'Color')
        return f
    end
    local function solid(w, h, x, y, rot, round)
        local f = New('Frame', {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, x or 0, 0.5, y or 0),
            Size = UDim2.fromOffset(w, h),
            Rotation = rot or 0,
            BorderSizePixel = 0,
            ZIndex = 3,
            Parent = P,
        })
        if round then New('UICorner', { CornerRadius = UDim.new(1, 0), Parent = f }) end
        ink(f, 'BackgroundColor3')
        return f
    end

    local key = Glyphs[string.lower(Name)]
    if type(key) == 'function' then
        Guard('icon', key, P, ink, New)
    elseif key == 'crosshair' then
        ring(10, 10, 0, 0, 1.5)
        solid(2, 4, 0, -8)
        solid(2, 4, 0, 8)
        solid(4, 2, -8, 0)
        solid(4, 2, 8, 0)
    elseif key == 'target' then
        ring(16)
        ring(8)
        solid(3, 3, 0, 0, 0, true)
    elseif key == 'eye' then
        ring(18, 11)
        solid(5, 5, 0, 0, 0, true)
    elseif key == 'globe' then
        ring(16)
        ring(7, 16)
        solid(16, 1.5, 0, 0)
    elseif key == 'people' then
        ring(6, 6, 0, -4)
        ring(13, 8, 0, 5)
    elseif key == 'bomb' then
        solid(12, 12, -1, 2, 0, true)
        solid(2, 6, 5, -6, 45)
        solid(3, 3, 8, -9, 0, true)
    elseif key == 'diamond' then
        local d = ring(11, 11, 0, 0, 1.5, UDim.new(0, 2))
        d.Rotation = 45
        solid(3, 3, 0, 0, 0, true)
    elseif key == 'gear' then
        ring(12, 12, 0, 0, 2.5)
        for i = 0, 7 do
            local a = math.rad(i * 45)
            solid(3, 3, math.cos(a) * 8, math.sin(a) * 8, i * 45)
        end
    else
        local t = Library:CreateLabel({
            Size = UDim2.new(1, 0, 1, 0),
            Text = string.upper(string.sub(Name, 1, 1)),
            TextSize = Library.FontSize + 1,
            Font = Enum.Font.GothamBold,
            ZIndex = 3,
            Parent = P,
        })
        Library:RemoveFromRegistry(t)
        ink(t, 'TextColor3')
    end

    return function(active)
        state.active = active and true or false
        for _, it in ipairs(items) do
            it[1][it[2]] = color()
        end
    end
end

local TabboxSkinned = setmetatable({}, { __mode = 'k' })

local function SkinTabboxTab(Tabbox, TabObj)
    PatchFrom(TabObj)
    local Container = TabObj.Container
    local BoxInner = Container.Parent
    local BoxOuter = BoxInner.Parent
    local Buttons = BoxInner:FindFirstChildOfClass('Frame')
    if not Buttons then return end

    if not TabboxSkinned[BoxOuter] then
        TabboxSkinned[BoxOuter] = true
        Strip(BoxOuter)
        BoxOuter.BorderSizePixel = 0
        BoxOuter.BackgroundTransparency = CardTransparency
        Cards[BoxOuter] = true
        Corner(BoxOuter, 8)
        Stroke(BoxOuter, 'OutlineColor', 1, 0.5)
        Strip(BoxInner)
        BoxInner.BackgroundTransparency = 1
        BoxInner.BorderSizePixel = 0
        BoxInner.Position = UDim2.new(0, 0, 0, 0)
        BoxInner.Size = UDim2.new(1, 0, 1, 0)
        Buttons.Position = UDim2.new(0, 8, 0, 6)
        Buttons.Size = UDim2.new(1, -16, 0, 22)
    end

    local Button
    for _, c in ipairs(Buttons:GetChildren()) do
        if c:IsA('Frame') then Button = c end
    end
    if not Button then return end
    Strip(Button)
    Button.BackgroundTransparency = 1
    Button.BorderSizePixel = 0
    local Label, Highlight
    for _, c in ipairs(Button:GetChildren()) do
        if c:IsA('TextLabel') then
            Label = c
        elseif c:IsA('Frame') then
            if c.Size.Y.Offset == 2 then
                Highlight = c
            else
                c.Visible = false
                c.BackgroundTransparency = 1
            end
        end
    end
    if Highlight then
        Strip(Highlight)
        Highlight.AnchorPoint = Vector2.new(0.5, 1)
        Highlight.Position = UDim2.new(0.5, 0, 1, 0)
        Highlight.Size = UDim2.new(0, 14, 0, 2)
        Corner(Highlight, 1)
    end
    if Label then
        Label.TextSize = Library.FontSize - 1
        Label.Font = Enum.Font.GothamMedium
    end

    local function style()
        local active = Container.Visible
        Button.BackgroundTransparency = 1
        if Label then
            Label.TextColor3 = active and Library.FontColor or Library.MutedColor
            local r = Library.RegistryMap[Label]
            if r then r.Properties.TextColor3 = active and 'FontColor' or 'MutedColor' end
        end
        if Highlight then Highlight.Visible = active end
    end

    local origShow, origHide, origResize = TabObj.Show, TabObj.Hide, TabObj.Resize
    TabObj.Show = function(t, ...)
        origShow(t, ...)
        for _, other in next, Tabbox.Tabs do
            if other.__skinStyle then other.__skinStyle() end
        end
    end
    TabObj.Hide = function(t, ...)
        origHide(t, ...)
        style()
    end
    TabObj.Resize = function(t, ...)
        origResize(t, ...)
        if Container.Visible then
            local Size = 0
            for _, El in ipairs(Container:GetChildren()) do
                if El:IsA('GuiObject') and El.Visible then Size = Size + El.Size.Y.Offset end
            end
            BoxOuter.Size = UDim2.new(1, 0, 0, 34 + Size + 8)
        end
    end
    TabObj.__skinStyle = style
    Container.Position = UDim2.new(0, 12, 0, 34)
    Container.Size = UDim2.new(1, -24, 1, -34)
    style()
    TabObj:Resize()
end

local function SkinTab(ctx, Tab, Name, list)
    local TabButton
    for _, i in ipairs(list) do
        if i.ClassName == 'Frame' and i.Parent == ctx.TabArea then TabButton = i; break end
    end
    if not TabButton then return end

    local Label, Indicator
    for _, c in ipairs(TabButton:GetChildren()) do
        if c:IsA('TextLabel') then
            Label = c
        elseif c:IsA('Frame') and c.Size.Y.Offset == 2 and c.BorderSizePixel == 0 then
            Indicator = c
        end
    end

    Strip(TabButton)
    TabButton.BorderSizePixel = 0
    TabButton.Size = UDim2.new(0, TAB_W, 1, 0)
    Corner(TabButton, 7)
    if Label then Label.Visible = false end
    if Indicator then
        Strip(Indicator)
        Indicator.AnchorPoint = Vector2.new(0.5, 1)
        Indicator.Position = UDim2.new(0.5, 0, 1, 0)
        Indicator.Size = UDim2.fromOffset(16, 2)
        Corner(Indicator, 1)
    end

    local state = { active = false }
    local setIcon = BuildIcon(TabButton, Name, state)

    local function style(active)
        TabButton.BackgroundTransparency = active and 0 or 1
        setIcon(active)
    end

    local origShow, origHide = Tab.ShowTab, Tab.HideTab
    Tab.ShowTab = function(t, ...)
        origShow(t, ...)
        style(true)
    end
    Tab.HideTab = function(t, ...)
        origHide(t, ...)
        style(false)
    end
    style(Indicator and Indicator.Visible or false)

    TabButton.MouseEnter:Connect(function()
        local tip = ctx.Tip
        if not tip then return end
        tip.Label.Text = Name
        local w = Library:GetTextBounds(Name, Library.Font, Library.FontSize - 1)
        tip.Frame.Size = UDim2.fromOffset(w + 14, 22)
        local ip = ctx.Inner.AbsolutePosition
        tip.Frame.Position = UDim2.fromOffset(
            TabButton.AbsolutePosition.X - ip.X + TabButton.AbsoluteSize.X / 2,
            TabButton.AbsolutePosition.Y - ip.Y + TabButton.AbsoluteSize.Y + 10
        )
        tip.Frame.Visible = true
    end)
    TabButton.MouseLeave:Connect(function()
        if ctx.Tip then ctx.Tip.Frame.Visible = false end
    end)

    ctx.Count = ctx.Count + 1
    ctx.Pill.Size = UDim2.new(0, 12 + ctx.Count * TAB_W + (ctx.Count - 1) * TAB_GAP, 0, PILL_H)

    local sides = {}
    for _, i in ipairs(list) do
        if i.ClassName == 'ScrollingFrame' then sides[#sides + 1] = i end
    end
    if sides[1] then
        sides[1].Position = UDim2.new(0, 0, 0, 0)
        sides[1].Size = UDim2.new(0.5, -5, 1, 0)
    end
    if sides[2] then
        sides[2].Position = UDim2.new(0.5, 5, 0, 0)
        sides[2].Size = UDim2.new(0.5, -5, 1, 0)
    end

    local TabFrame
    for _, i in ipairs(list) do
        if i.ClassName == 'Frame' and i.Name == 'TabFrame' then TabFrame = i; break end
    end

    Tab.SubTabs = function(t, names)
        local bar = { current = names[1], pills = {}, groups = {} }
        local subs = {}
        local SUB_H = 34
        for _, sd in ipairs(sides) do
            sd.Position = UDim2.new(sd.Position.X.Scale, sd.Position.X.Offset, 0, SUB_H)
            sd.Size = UDim2.new(sd.Size.X.Scale, sd.Size.X.Offset, 1, -SUB_H)
        end

        local widths, total = {}, 0
        for index, name in ipairs(names) do
            widths[index] = Library:GetTextBounds(name, Enum.Font.GothamMedium, Library.FontSize - 1) + 22
            total = total + widths[index] + (index > 1 and 4 or 0)
        end

        local holder = New('Frame', {
            AnchorPoint = Vector2.new(0.5, 0),
            Position = UDim2.new(0.5, 0, 0, 2),
            Size = UDim2.fromOffset(total, 24),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ZIndex = 3,
            Parent = TabFrame,
        })
        New('UIListLayout', {
            FillDirection = Enum.FillDirection.Horizontal,
            Padding = UDim.new(0, 4),
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = holder,
        })

        local function apply()
            for name, group in pairs(bar.groups) do
                for _, frame in ipairs(group) do frame.Visible = name == bar.current end
            end
            for name, pill in pairs(bar.pills) do
                local active = name == bar.current
                pill.BackgroundTransparency = active and 0 or 1
                pill.TextColor3 = active and Library.FontColor or Library.MutedColor
                local r = Library.RegistryMap[pill]
                if r then
                    r.Properties.TextColor3 = active and 'FontColor' or 'MutedColor'
                    r.Properties.BackgroundColor3 = 'MainColor'
                end
            end
        end

        for index, name in ipairs(names) do
            local pill = New('TextButton', {
                AutoButtonColor = false,
                BackgroundColor3 = Library.MainColor,
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Size = UDim2.fromOffset(widths[index], 24),
                LayoutOrder = index,
                Font = Enum.Font.GothamMedium,
                Text = name,
                TextSize = Library.FontSize - 1,
                TextColor3 = Library.MutedColor,
                ZIndex = 4,
                Parent = holder,
            })
            Corner(pill, 6)
            Library:AddToRegistry(pill, { BackgroundColor3 = 'MainColor', TextColor3 = 'MutedColor' })
            pill.MouseButton1Click:Connect(function()
                if Library:MouseIsOverOpenedFrame() then return end
                bar.current = name
                apply()
            end)
            bar.pills[name] = pill
            bar.groups[name] = {}

            local function add(side, title)
                local g = t:AddGroupbox({ Side = side, Name = title })
                local outer = g.Container.Parent.Parent
                table.insert(bar.groups[name], outer)
                outer.Visible = name == bar.current
                return g
            end
            local sub = {}
            local function addBox(side)
                local tb = side == 1 and t:AddLeftTabbox() or t:AddRightTabbox()
                local registered = false
                local oa = tb.AddTab
                tb.AddTab = function(self, title)
                    local r = oa(self, title)
                    if not registered then
                        registered = true
                        local outer = r.Container.Parent.Parent
                        table.insert(bar.groups[name], outer)
                        outer.Visible = name == bar.current
                    end
                    return r
                end
                return tb
            end
            function sub:AddLeftTabbox() return addBox(1) end
            function sub:AddRightTabbox() return addBox(2) end
            function sub:AddGroupbox(info) return add(info.Side or 1, info.Name) end
            function sub:AddLeftGroupbox(title) return add(1, title) end
            function sub:AddRightGroupbox(title) return add(2, title) end
            subs[name] = sub
        end
        apply()
        return subs
    end

    local origGroupbox = Tab.AddGroupbox
    Tab.AddGroupbox = function(t, Info)
        local _, res = Capture(origGroupbox, t, Info)
        if not res[1] then error(res[2], 0) end
        local Groupbox = res[2]
        Guard('groupbox', function()
            PatchFrom(Groupbox)
            SkinGroupbox(Groupbox)
        end)
        return Groupbox
    end

    local origTabbox = Tab.AddTabbox
    if type(origTabbox) == 'function' then
        Tab.AddTabbox = function(t, Info)
            local _, res = Capture(origTabbox, t, Info)
            if not res[1] then error(res[2], 0) end
            local Tabbox = res[2]
            local origAdd = Tabbox.AddTab
            if type(origAdd) == 'function' then
                Tabbox.AddTab = function(tb, TabName)
                    local _, r2 = Capture(origAdd, tb, TabName)
                    if not r2[1] then error(r2[2], 0) end
                    Guard('tabbox', SkinTabboxTab, Tabbox, r2[2])
                    return r2[2]
                end
            end
            return Tabbox
        end
    end
end

local function DressWindow(Window)
    local Outer = Window.Holder
    local Inner = Outer and Outer:FindFirstChild('Inner')
    if not Inner then return end

    local labels, frames = {}, {}
    for _, c in ipairs(Inner:GetChildren()) do
        if c:IsA('TextLabel') then labels[#labels + 1] = c
        elseif c:IsA('Frame') then frames[#frames + 1] = c end
    end
    local TitleLabel, MapLabel = labels[1], labels[2]
    local TabBarOuter, MainOuter
    for _, f in ipairs(frames) do
        local y = f.Position.Y.Offset
        if y == 25 and not TabBarOuter then TabBarOuter = f
        elseif y == 58 and not MainOuter then MainOuter = f end
    end
    if not (TitleLabel and TabBarOuter and MainOuter) then return end

    local TabBarInner = TabBarOuter:FindFirstChildOfClass('Frame')
    local TabArea = TabBarInner and TabBarInner:FindFirstChildOfClass('Frame')
    local TabList = TabArea and TabArea:FindFirstChildOfClass('UIListLayout')
    local MainInner = MainOuter:FindFirstChildOfClass('Frame')
    local TabContainer = MainInner and MainInner:FindFirstChildOfClass('Frame')
    if not (TabArea and TabList and MainInner and TabContainer) then return end

    Outer.ClipsDescendants = false
    Outer.BackgroundTransparency = 1

    local Shadow = New('ImageLabel', {
        Name = 'Shadow',
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Position = UDim2.new(0.5, 0, 0.5, 4),
        Size = UDim2.new(1, 56, 1, 56),
        Image = 'rbxassetid://6014261993',
        ImageColor3 = BLACK,
        ImageTransparency = 0.55,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(49, 49, 450, 450),
        ZIndex = 0,
        Active = false,
        Parent = Outer,
    })

    Strip(Inner)
    Inner.Position = UDim2.new(0, 0, 0, 0)
    Inner.Size = UDim2.new(1, 0, 1, 0)
    Inner.BorderSizePixel = 0
    Inner.BackgroundColor3 = Library.PanelColor
    Inner.BackgroundTransparency = PanelTransparency
    Panels[#Panels + 1] = Inner
    Inner.ClipsDescendants = true
    Reg(Inner, { BackgroundColor3 = 'PanelColor' })
    Corner(Inner, Radius)
    Stroke(Inner, 'OutlineColor', 1, 0.15)

    local brand = opt('Brand', nil)
    if brand then TitleLabel.Text = brand end
    TitleLabel.AnchorPoint = Vector2.new(0, 0.5)
    TitleLabel.Position = UDim2.new(0, 46, 0, HEADER / 2)
    TitleLabel.Size = UDim2.new(0, 160, 0, 20)
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.Font = Enum.Font.GothamBold
    TitleLabel.TextSize = Library.FontSize + 2
    TitleLabel.TextTruncate = Enum.TextTruncate.AtEnd
    TitleLabel.ZIndex = 3

    local Logo = New('Frame', {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 16, 0, HEADER / 2),
        Size = UDim2.fromOffset(24, 24),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 3,
        Parent = Inner,
    })
    New('UICorner', { CornerRadius = UDim.new(1, 0), Parent = Logo })
    local LogoStroke = New('UIStroke', {
        Color = Library.AccentColor, Thickness = 2,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = Logo,
    })
    Library:AddToRegistry(LogoStroke, { Color = 'AccentColor' })
    local LogoRing = New('Frame', {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.fromOffset(12, 12),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 3,
        Parent = Logo,
    })
    New('UICorner', { CornerRadius = UDim.new(1, 0), Parent = LogoRing })
    local LogoRingStroke = New('UIStroke', {
        Color = Library.AccentColor, Thickness = 1.5,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = LogoRing,
    })
    Library:AddToRegistry(LogoRingStroke, { Color = 'AccentColor' })
    local LogoDot = New('Frame', {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.fromOffset(4, 4),
        BackgroundColor3 = Library.AccentColor,
        BorderSizePixel = 0,
        ZIndex = 3,
        Parent = Logo,
    })
    New('UICorner', { CornerRadius = UDim.new(1, 0), Parent = LogoDot })
    Library:AddToRegistry(LogoDot, { BackgroundColor3 = 'AccentColor' })

    Strip(TabBarOuter)
    TabBarOuter.AnchorPoint = Vector2.new(0.5, 0.5)
    TabBarOuter.Position = UDim2.new(0.5, 0, 0, HEADER / 2)
    TabBarOuter.Size = UDim2.new(0, 12, 0, PILL_H)
    TabBarOuter.BorderSizePixel = 0
    TabBarOuter.BackgroundColor3 = Library.PillColor
    TabBarOuter.BackgroundTransparency = 0.1
    TabBarOuter.ZIndex = 2
    Reg(TabBarOuter, { BackgroundColor3 = 'PillColor' })
    Corner(TabBarOuter, 9)
    Stroke(TabBarOuter, 'OutlineColor', 1, 0.5)
    Flat(TabBarInner)
    TabArea.Position = UDim2.new(0, 6, 0, 3)
    TabArea.Size = UDim2.new(1, -12, 1, -6)
    TabList.Padding = UDim.new(0, TAB_GAP)
    TabList.VerticalAlignment = Enum.VerticalAlignment.Center

    local Divider = New('Frame', {
        Position = UDim2.new(0, 0, 0, HEADER),
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = Library.OutlineColor,
        BackgroundTransparency = 0.45,
        BorderSizePixel = 0,
        ZIndex = 2,
        Parent = Inner,
    })
    Library:AddToRegistry(Divider, { BackgroundColor3 = 'OutlineColor' })

    local uid = LocalPlayer and LocalPlayer.UserId or 0
    local uname = opt('UserName', LocalPlayer and (LocalPlayer.DisplayName or LocalPlayer.Name) or 'user')
    local Avatar = New('ImageLabel', {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -16, 0, HEADER / 2),
        Size = UDim2.fromOffset(30, 30),
        BackgroundColor3 = Library.MainColor,
        BorderSizePixel = 0,
        Image = opt('Avatar', ''),
        ZIndex = 3,
        Parent = Inner,
    })
    Library:AddToRegistry(Avatar, { BackgroundColor3 = 'MainColor' })
    New('UICorner', { CornerRadius = UDim.new(1, 0), Parent = Avatar })
    local AvStroke = New('UIStroke', {
        Color = Library.AccentColor, Thickness = 1.5,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = Avatar,
    })
    Library:AddToRegistry(AvStroke, { Color = 'AccentColor' })
    if Config.Avatar == nil and uid ~= 0 then
        task.spawn(function()
            local ok, img = pcall(function()
                return Players:GetUserThumbnailAsync(uid, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
            end)
            if ok and img and Avatar.Parent then Avatar.Image = img end
        end)
    end

    local UserLabel = Library:CreateLabel({
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -54, 0, HEADER / 2 - (MapLabel and 7 or 0)),
        Size = UDim2.new(0, 150, 0, 16),
        Text = tostring(uname),
        TextSize = Library.FontSize,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Font = Enum.Font.GothamMedium,
        ZIndex = 3,
        Parent = Inner,
    })
    if MapLabel then
        MapLabel.AnchorPoint = Vector2.new(1, 0.5)
        MapLabel.Position = UDim2.new(1, -54, 0, HEADER / 2 + 8)
        MapLabel.Size = UDim2.new(0, 150, 0, 14)
        MapLabel.TextSize = Library.FontSize - 2
        MapLabel.TextTruncate = Enum.TextTruncate.AtEnd
        MapLabel.ZIndex = 3
        Muted(MapLabel)
    end

    Flat(MainOuter)
    MainOuter.Position = UDim2.new(0, 0, 0, HEADER + 1)
    MainOuter.Size = UDim2.new(1, 0, 1, -(HEADER + 1))
    Flat(MainInner)
    Flat(TabContainer)
    TabContainer.Position = UDim2.new(0, 12, 0, 10)
    TabContainer.Size = UDim2.new(1, -24, 1, -20)

    local grip
    for _, c in ipairs(Outer:GetChildren()) do
        if c:IsA('Frame') and c.Size.X.Offset == 46 then grip = c end
    end
    if grip then
        Strip(grip)
        grip.BackgroundTransparency = 1
        grip.AnchorPoint = Vector2.new(1, 1)
        grip.Position = UDim2.new(1, -2, 1, -2)
        grip.Size = UDim2.fromOffset(24, 24)
        for i = 0, 2 do
            for j = 0, i do
                local d = New('Frame', {
                    AnchorPoint = Vector2.new(1, 1),
                    Position = UDim2.new(1, -6 - j * 4, 1, -6 - (2 - i) * 4),
                    Size = UDim2.fromOffset(2, 2),
                    BackgroundColor3 = Library.MutedColor,
                    BorderSizePixel = 0,
                    ZIndex = 101,
                    Active = false,
                    Parent = grip,
                })
                Library:AddToRegistry(d, { BackgroundColor3 = 'MutedColor' })
            end
        end
    end

    local ctx = { Count = 0, TabArea = TabArea, Pill = TabBarOuter, Inner = Inner }

    local TipFrame = New('Frame', {
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundColor3 = Library.MainColor,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(60, 22),
        Visible = false,
        ZIndex = 60,
        Active = false,
        Parent = Inner,
    })
    Library:AddToRegistry(TipFrame, { BackgroundColor3 = 'MainColor' })
    Corner(TipFrame, 5)
    Stroke(TipFrame, 'OutlineColor', 1, 0.2)
    local TipLabel = Library:CreateLabel({
        Size = UDim2.new(1, 0, 1, 0),
        TextSize = Library.FontSize - 1,
        Text = '',
        ZIndex = 61,
        Parent = TipFrame,
    })
    ctx.Tip = { Frame = TipFrame, Label = TipLabel }

    local origAddTab = Window.AddTab
    Window.AddTab = function(self, Name)
        local list, res = Capture(origAddTab, self, Name)
        if not res[1] then error(res[2], 0) end
        Guard('tab', SkinTab, ctx, res[2], Name, list)
        return res[2]
    end
end

Library.CreateWindow = function(self, ...)
    local args = { ... }
    local cfg = {}
    if type(args[1]) == 'table' then
        for k, v in next, args[1] do cfg[k] = v end
    else
        cfg.Title = args[1]
        cfg.AutoShow = args[2] or false
    end
    if typeof(cfg.Size) ~= 'UDim2' then cfg.Size = opt('Size', UDim2.fromOffset(720, 520)) end
    if type(cfg.TabPadding) ~= 'number' then cfg.TabPadding = 0 end
    local Window = OrigCreateWindow(self, cfg)
    Guard('window', DressWindow, Window)
    return Window
end

Guard('keybinds', function()
    local O, I, C = Library.KeybindFrame, Library.KeybindInner, Library.KeybindColorFrame
    if not (O and I) then return end
    O.BackgroundTransparency = 1
    O.BorderSizePixel = 0
    Strip(I)
    I.BorderSizePixel = 0
    I.BackgroundTransparency = 0.08
    Reg(I, { BackgroundColor3 = 'PanelColor' }, true)
    I.BackgroundColor3 = Library.PanelColor
    Corner(I, 8)
    Stroke(I, 'OutlineColor', 1, 0.2)
    if C then C.Visible = false end
    for _, c in ipairs(I:GetChildren()) do
        if c:IsA('TextLabel') then
            c.Position = UDim2.new(0, 12, 0, 2)
            c.Size = UDim2.new(1, -12, 0, 20)
            c.TextXAlignment = Enum.TextXAlignment.Left
            c.TextSize = Library.FontSize - 1
            Muted(c)
        end
    end
    if Library.KeybindContainer then
        local pad = Library.KeybindContainer:FindFirstChildOfClass('UIPadding')
        if pad then pad.PaddingLeft = UDim.new(0, 12) end
    end
end)

Guard('fonts', function()
    for _, d in ipairs(Library.ScreenGui:GetDescendants()) do
        if (d:IsA('TextLabel') or d:IsA('TextBox') or d:IsA('TextButton')) and d.Font == Enum.Font.Code then
            d.Font = Library.Font
            d.TextStrokeTransparency = 1
        elseif d:IsA('UIStroke') and d.Parent and d.Parent:IsA('TextLabel') then
            d:Destroy()
        end
    end
end)

local Skin = { AutoDerive = true }

local function mix(a, b, t)
    return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end

local deriving = false
function Skin.Derive()
    if not Skin.AutoDerive then return end
    deriving = true
    Library.PanelColor = mix(Library.BackgroundColor, BLACK, 0.2)
    Library.PillColor = mix(Library.BackgroundColor, BLACK, 0.45)
    Library.MutedColor = mix(Library.FontColor, Library.BackgroundColor, 0.55)
    Library:UpdateColorsUsingRegistry()
    local O = getgenv().Options
    if O then
        for _, k in ipairs({ 'PanelColor', 'MutedColor' }) do
            if O[k] and O[k].SetValueRGB then pcall(O[k].SetValueRGB, O[k], Library[k]) end
        end
    end
    deriving = false
end

function Skin.SetPanelTransparency(v)
    PanelTransparency = v
    for _, p in ipairs(Panels) do
        if p.Parent then p.BackgroundTransparency = v end
    end
end

function Skin.SetCardTransparency(v)
    CardTransparency = v
    for c in pairs(Cards) do
        if c.Parent then c.BackgroundTransparency = v end
    end
end

function Skin.SetAccent(color)
    Library.AccentColor = color
    Library.AccentColorDark = Darker(color)
    Library:UpdateColorsUsingRegistry()
end

function Skin.SetTheme(tbl)
    for k, v in next, tbl do Library[k] = v end
    if tbl.AccentColor then Library.AccentColorDark = Darker(tbl.AccentColor) end
    Library:UpdateColorsUsingRegistry()
end

local SETTINGS_FLAGS = {
    'KeybindMenuOpen', 'SkinKeybindMode', 'MenuKeybind', 'LinoriaKeybindTransparency', 'LinoriaUseBlur', 'LinoriaBlurSize',
    'LinoriaUseDarken', 'LinoriaDarkenAmount', 'SkinWireframe', 'SkinFontSize', 'SkinNotifyAlign', 'SkinNotifySide',
    'SkinNotifyX', 'SkinNotifyY', 'SkinNotifyAlpha', 'PanelColor', 'MutedColor', 'SkinPanelAlpha', 'SkinCardAlpha',
}

function Skin.BuildSettings(Window, Opts)
    Opts = type(Opts) == 'table' and Opts or {}
    local TM, SM = Opts.ThemeManager, Opts.SaveManager
    local Tab = Window:AddTab(Opts.TabName or 'Settings')
    local subs = Tab:SubTabs({ 'Menu', 'Theme', 'Config' })

    local Menu = subs.Menu:AddLeftGroupbox('Menu')
    Menu:AddLabel('Menu bind'):AddKeyPicker('MenuKeybind', { Default = Opts.MenuKey or 'RightShift', NoUI = true, Text = 'Menu keybind' })
    Library.ToggleKeybind = getgenv().Options.MenuKeybind
    Menu:AddToggle('KeybindMenuOpen', {
        Text = 'Keybind list',
        Default = false,
        Callback = function(v) if Library.KeybindFrame then Library.KeybindFrame.Visible = v end end,
    })
    Menu:AddDropdown('SkinKeybindMode', {
        Text = 'Keybind list shows',
        Values = { 'All', 'Active', 'Toggled' },
        Default = Library.KeybindMode or 'All',
        Callback = function(v) Library:SetKeybindMode(v) end,
    })
    Library:AddKeybindTransparencySlider(Menu)
    Menu:AddSlider('SkinFontSize', {
        Text = 'Font size', Default = Library.FontSize, Min = 11, Max = 18, Rounding = 0, HideMax = true,
        Callback = function(v) if v ~= Library.FontSize then Library:SetFontSize(v) end end,
    })
    Menu:AddButton('Unload', function() Library:Unload() end)

    local Display = subs.Menu:AddRightGroupbox('Display')
    Library:AddBlurSlider(Display)
    Library:AddDarkenSlider(Display)
    Display:AddToggle('SkinWireframe', {
        Text = 'Wireframe drag', Default = Library.WireframeDrag ~= false,
        Callback = function(v) Library.WireframeDrag = v end,
    })

    local Notif = subs.Menu:AddRightGroupbox('Notifications')
    Notif:AddDropdown('SkinNotifyAlign', {
        Text = 'Alignment', Values = { 'Left', 'Center', 'Right' }, Default = Library.NotifyConfig.Alignment or 'Center',
        Callback = function(v) Library:ConfigureNotifications({ Alignment = v }) end,
    })
    Notif:AddDropdown('SkinNotifySide', {
        Text = 'Stack from', Values = { 'Top', 'Bottom' }, Default = Library.NotifyConfig.BarSide == 'Top' and 'Top' or 'Bottom',
        Callback = function(v) Library:ConfigureNotifications({ BarSide = v }) end,
    })
    Notif:AddSlider('SkinNotifyX', {
        Text = 'Position X', Default = Library.NotifyConfig.PosX, Min = 0, Max = 100, Rounding = 0, HideMax = true, Suffix = '%',
        Callback = function(v) Library:ConfigureNotifications({ PosX = v }) end,
    })
    Notif:AddSlider('SkinNotifyY', {
        Text = 'Position Y', Default = Library.NotifyConfig.PosY, Min = 0, Max = 100, Rounding = 0, HideMax = true, Suffix = '%',
        Callback = function(v) Library:ConfigureNotifications({ PosY = v }) end,
    })
    Notif:AddSlider('SkinNotifyAlpha', {
        Text = 'Transparency', Default = Library.NotifyConfig.Transparency or 0, Min = 0, Max = 100, Rounding = 0, HideMax = true, Suffix = '%',
        Callback = function(v) Library:ConfigureNotifications({ Transparency = v }) end,
    })
    Notif:AddButton('Test notification', function() Library:Notify('Notification preview', 3) end)

    if TM then
        TM:SetLibrary(Library)
        TM.BuiltInThemes['Perception Teal'] = { 0, {
            FontColor = 'd2d2d6', MainColor = '202026', AccentColor = '6ec9c8',
            BackgroundColor = '1a1a1f', OutlineColor = '303038',
        } }
        TM.DefaultTheme = 'Perception Teal'
        if Opts.Folder then TM:SetFolder(Opts.Folder) end
        local origUpdate = TM.ThemeUpdate
        TM.ThemeUpdate = function(self, ...)
            origUpdate(self, ...)
            Skin.Derive()
        end
        TM:ApplyToTab(subs.Theme)
    end

    local Look = subs.Theme:AddRightGroupbox('Appearance')
    Look:AddLabel('Panel color'):AddColorPicker('PanelColor', {
        Default = Library.PanelColor, Title = 'Panel color',
        Callback = function(c)
            if deriving then return end
            Skin.AutoDerive = false
            Library.PanelColor = c
            Library:UpdateColorsUsingRegistry()
        end,
    })
    Look:AddLabel('Muted text color'):AddColorPicker('MutedColor', {
        Default = Library.MutedColor, Title = 'Muted text color',
        Callback = function(c)
            if deriving then return end
            Skin.AutoDerive = false
            Library.MutedColor = c
            Library:UpdateColorsUsingRegistry()
        end,
    })
    Look:AddSlider('SkinPanelAlpha', {
        Text = 'Panel opacity', Default = math.floor((1 - PanelTransparency) * 100 + 0.5), Min = 40, Max = 100,
        Rounding = 0, HideMax = true, Suffix = '%',
        Callback = function(v) Skin.SetPanelTransparency(1 - v / 100) end,
    })
    Look:AddSlider('SkinCardAlpha', {
        Text = 'Card opacity', Default = math.floor((1 - CardTransparency) * 100 + 0.5), Min = 0, Max = 100,
        Rounding = 0, HideMax = true, Suffix = '%',
        Callback = function(v) Skin.SetCardTransparency(1 - v / 100) end,
    })
    Look:AddButton('Auto colors', function()
        Skin.AutoDerive = true
        Skin.Derive()
    end)

    if SM then
        SM:SetLibrary(Library)
        if Opts.Folder then SM:SetFolder(Opts.Folder .. '/' .. (Opts.Game or 'configs')) end
        if SM.IgnoreThemeSettings then SM:IgnoreThemeSettings() end
        SM:SetIgnoreIndexes(SETTINGS_FLAGS)
        local About = subs.Config:AddLeftGroupbox('Storage')
        About:AddLabel('Configs: ' .. tostring(SM.Folder) .. '/settings', true)
        About:AddLabel('Themes: ' .. tostring(TM and TM.Folder or SM.Folder) .. '/themes', true)
        SM:BuildConfigSection(subs.Config)
    else
        local About = subs.Config:AddLeftGroupbox('Config')
        About:AddLabel('Pass SaveManager in Skin.BuildSettings options to enable configs.', true)
    end

    return Tab, subs
end

Library.__PerceptionSkin = Skin
return Skin

end

local given = ...
if given ~= nil then
    return Apply(...)
end
return Apply
