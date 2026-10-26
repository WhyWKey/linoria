local function Apply(Library, Config)

assert(type(Library) == 'table' and type(Library.Create) == 'function' and type(Library.CreateWindow) == 'function', 'PerceptionSkin: pass the Linoria Library as the first argument')
if type(Library.__PerceptionSkin) == 'table' then
    return Library.__PerceptionSkin
end
Config = type(Config) == 'table' and Config or {}

local Players = game:GetService('Players')
local LocalPlayer = Players.LocalPlayer
local LiveOptions, LiveToggles = getgenv().Options, getgenv().Toggles

local function opt(key, default)
    local v = Config[key]
    if v == nil then return default end
    return v
end

local BLACK = Color3.new(0, 0, 0)
local WHITE = Color3.new(1, 1, 1)
local HEADER = 66
local PILL_H = 40
local TAB_W = 42
local TAB_GAP = 2
local SUB_H = 32
local CARD_TOP = 36
local CARD_PAD = 14

local Theme = {
    FontColor = Color3.fromRGB(182, 182, 182),
    MutedColor = Color3.fromRGB(110, 110, 110),
    MainColor = Color3.fromRGB(17, 17, 17),
    BackgroundColor = Color3.fromRGB(23, 23, 23),
    PanelColor = Color3.fromRGB(15, 15, 15),
    PillColor = Color3.fromRGB(19, 19, 19),
    OutlineColor = Color3.fromRGB(40, 40, 40),
    CheckColor = Color3.fromRGB(46, 46, 46),
    AccentColor = opt('Accent', Color3.fromRGB(103, 137, 147)),
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
local function mix(a, b, t)
    return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end
local function Bright()
    return mix(Library.FontColor, WHITE, 0.5)
end
local function pickFont(name, fallback)
    local ok, f = pcall(function() return Enum.Font[name] end)
    if ok and f then return f end
    return fallback
end
local Fonts = {
    Regular = opt('Font', pickFont('BuilderSans', Enum.Font.Gotham)),
    Medium = pickFont('BuilderSansMedium', Enum.Font.GothamMedium),
    Bold = pickFont('BuilderSansBold', Enum.Font.GothamBold),
}
Library.Font = Fonts.Regular
Library.FontSize = opt('FontSize', 12)

local Radius = opt('Radius', 10)
local PanelTransparency = opt('PanelTransparency', 0.02)
local CardTransparency = opt('CardTransparency', 0)
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

local PatchFrom

local function Muted(inst)
    inst.TextColor3 = Library.MutedColor
    Reg(inst, { TextColor3 = 'MutedColor' })
end

local Regions = setmetatable({}, { __mode = 'k' })

local function SkinToggle(Groupbox, Toggle, list)
    PatchFrom(Toggle)
    local Label = Toggle.TextLabel
    local Inner = Label.Parent
    local Outer = Inner.Parent
    local Region
    for _, c in ipairs(Outer:GetChildren()) do
        if c ~= Inner and c:IsA('Frame') then Region = c end
    end

    Outer.Size = UDim2.new(1, -4, 0, 22)
    Strip(Inner)
    Inner.BackgroundTransparency = 1
    Inner.BorderSizePixel = 0
    Label.Position = UDim2.new(0, 0, 0, 0)
    Label.Size = UDim2.new(1, -26, 1, 0)
    Label.TextXAlignment = Enum.TextXAlignment.Left
    local layout = Label:FindFirstChildOfClass('UIListLayout')
    if layout then
        layout.VerticalAlignment = Enum.VerticalAlignment.Center
        layout.Padding = UDim.new(0, 5)
    end
    if Region then
        Region.Size = UDim2.new(1, 0, 1, 0)
        Regions[Label] = Region
    end

    local Box = New('Frame', {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(16, 16),
        BackgroundColor3 = Library.CheckColor,
        BorderSizePixel = 0,
        ZIndex = 7,
        Parent = Inner,
    })
    Corner(Box, 4)
    local BoxStroke = New('UIStroke', {
        Color = Library.OutlineColor,
        Thickness = 1,
        Transparency = 0.5,
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
        Position = UDim2.fromOffset(5.3, 9),
        Size = UDim2.fromOffset(2, 5),
        Rotation = -45,
        BackgroundColor3 = Color3.fromRGB(240, 240, 240),
        BorderSizePixel = 0,
        ZIndex = 8,
        Parent = Check,
    })
    New('Frame', {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromOffset(9.6, 7.4),
        Size = UDim2.fromOffset(2, 10),
        Rotation = 45,
        BackgroundColor3 = Color3.fromRGB(240, 240, 240),
        BorderSizePixel = 0,
        ZIndex = 8,
        Parent = Check,
    })
    Library:AddToRegistry(Box, { BackgroundColor3 = 'CheckColor' })
    Library:AddToRegistry(BoxStroke, { Color = 'OutlineColor' })

    local hover = false
    local function apply()
        local on = Toggle.Value and true or false
        Box.BackgroundColor3 = on and Library.AccentColor or Library.CheckColor
        BoxStroke.Color = hover and Library.AccentColor or Library.OutlineColor
        BoxStroke.Transparency = hover and 0 or 0.5
        Check.Visible = on
        local rb = Library.RegistryMap[Box]
        if rb then rb.Properties.BackgroundColor3 = on and 'AccentColor' or 'CheckColor' end
        local rs = Library.RegistryMap[BoxStroke]
        if rs then rs.Properties.Color = hover and 'AccentColor' or 'OutlineColor' end
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
    local OH = 22
    local yc = compact and 25 or 17
    Outer.Size = UDim2.new(1, -4, 0, compact and 30 or OH)
    Strip(Inner)
    Inner.BackgroundTransparency = 1
    Inner.BorderSizePixel = 0

    local Track = New('Frame', {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 0, 0, yc),
        Size = UDim2.new(1, 0, 0, 2),
        BackgroundColor3 = Library.CheckColor,
        BorderSizePixel = 0,
        ZIndex = Fill.ZIndex - 1,
        Parent = Inner,
    })
    Corner(Track, 1)
    Library:AddToRegistry(Track, { BackgroundColor3 = 'CheckColor' })

    Strip(Fill)
    Fill.BorderSizePixel = 0
    Fill.AnchorPoint = Vector2.new(0, 0.5)
    Fill.Position = UDim2.new(0, 0, 0, yc)
    Corner(Fill, 1)
    if Hide then Hide.Visible = false end

    local Value
    if Label then
        Label.Size = UDim2.new(1, -4, 0, 14)
        Label.TextYAlignment = Enum.TextYAlignment.Center
        Value = Library:CreateLabel({
            AnchorPoint = Vector2.new(0, 0),
            Position = UDim2.new(0, 0, 0, 0),
            Size = UDim2.fromOffset(40, 11),
            TextSize = Library.FontSize - 3,
            TextXAlignment = Enum.TextXAlignment.Center,
            Text = '',
            ZIndex = Fill.ZIndex + 1,
            Parent = Inner,
        })
        Library:RemoveFromRegistry(Value)
        Value.TextColor3 = Library.MutedColor
        Library:AddToRegistry(Value, { TextColor3 = 'MutedColor' })
        DisplayLabel.Visible = false
    else
        DisplayLabel.Size = UDim2.new(1, 0, 0, 14)
        DisplayLabel.Position = UDim2.new(0, 0, 0, 0)
        DisplayLabel.TextXAlignment = Enum.TextXAlignment.Left
    end

    local function sync()
        local x = Fill.Size.X.Offset
        Fill.Size = UDim2.new(0, x, 0, 2)
        if Hide then Hide.Visible = false end
        if Value then
            local txt = DisplayLabel.Text
            txt = txt:match('^(.-)/') or txt
            Value.Text = txt
            local w = Library:GetTextBounds(txt, Library.Font, Library.FontSize - 3) + 6
            local total = Inner.AbsoluteSize.X
            if total <= 8 then total = Slider.MaxSize end
            local left = math.clamp(x - w / 2, 0, math.max(total - w, 0))
            Value.Size = UDim2.fromOffset(w, 11)
            Value.Position = UDim2.new(0, left, 0, 0)
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
        Label.Size = UDim2.new(1, -4, 0, 14)
        Label.TextYAlignment = Enum.TextYAlignment.Center
    end
    if not Outer then return end
    Outer.Size = UDim2.new(1, -4, 0, 24)
    local Inner = Outer:FindFirstChildOfClass('Frame')
    if not Inner then return end
    local Arrow = Inner:FindFirstChildOfClass('ImageLabel')
    local Text = Inner:FindFirstChildOfClass('TextLabel')
    if Arrow then
        Arrow.Size = UDim2.fromOffset(10, 10)
        Arrow.AnchorPoint = Vector2.new(0.5, 0.5)
        Arrow.Position = UDim2.new(1, -13, 0.5, 0)
        Arrow.ImageColor3 = Library.MutedColor
        Library:AddToRegistry(Arrow, { ImageColor3 = 'MutedColor' })
        local Sep = New('Frame', {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(1, -26, 0.5, 0),
            Size = UDim2.new(0, 1, 1, -8),
            BackgroundColor3 = Library.OutlineColor,
            BorderSizePixel = 0,
            ZIndex = Arrow.ZIndex,
            Parent = Inner,
        })
        Library:AddToRegistry(Sep, { BackgroundColor3 = 'OutlineColor' })
    end
    if Text then
        Text.Position = UDim2.new(0, 9, 0, 0)
        Text.Size = UDim2.new(1, -38, 1, 0)
        Text.TextWrapped = false
        Text.TextTruncate = Enum.TextTruncate.AtEnd
    end
    Groupbox:Resize()
end

local InputService = game:GetService('UserInputService')

local function Drag(frame, update)
    frame.InputBegan:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
            update(Input.Position.X, Input.Position.Y)
            local changed = InputService.InputChanged:Connect(function(Change)
                if Change.UserInputType == Enum.UserInputType.MouseMovement or Change == Input then
                    update(Change.Position.X, Change.Position.Y)
                end
            end)
            local ended
            ended = InputService.InputEnded:Connect(function(End)
                if End == Input or End.UserInputType == Enum.UserInputType.Touch then
                    changed:Disconnect()
                    ended:Disconnect()
                    Library:AttemptSave()
                end
            end)
        end
    end)
end

local function frac(pos, size, x)
    if not size or size <= 0 then return 0 end
    return math.clamp((x - pos) / size, 0, 1)
end

local function BuildPopup(CP, Info, Outer)
    local hasAlpha = type(Info) == 'table' and Info.Transparency ~= nil
    for _, c in ipairs(Outer:GetChildren()) do
        if c:IsA('GuiObject') then c.Visible = false end
    end

    local W = 176
    local SVH = 120
    local AY = 34 + SVH + 8
    local HY = hasAlpha and (AY + 20) or AY
    Outer.Size = UDim2.fromOffset(W, HY + 12 + 10)
    Outer.BackgroundColor3 = Library.PanelColor
    Outer.BackgroundTransparency = 0.03
    Reg(Outer, { BackgroundColor3 = 'PanelColor' })

    local Box = New('TextBox', {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 10, 0, 8),
        Size = UDim2.new(1, -20, 0, 20),
        Font = Fonts.Medium,
        TextSize = Library.FontSize - 1,
        TextColor3 = Library.MutedColor,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        Text = '',
        ZIndex = 18,
        Parent = Outer,
    })
    Library:AddToRegistry(Box, { TextColor3 = 'MutedColor' })

    local SV = New('Frame', {
        Position = UDim2.new(0, 10, 0, 34),
        Size = UDim2.new(1, -20, 0, SVH),
        BackgroundColor3 = Color3.new(1, 0, 0),
        BorderSizePixel = 0,
        ZIndex = 18,
        Parent = Outer,
    })
    Corner(SV, 6)
    local White = New('Frame', {
        Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 19, Parent = SV,
    })
    Corner(White, 6)
    New('UIGradient', { Transparency = NumberSequence.new(0, 1), Parent = White })
    local Dark = New('Frame', {
        Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = BLACK, BorderSizePixel = 0, ZIndex = 20, Parent = SV,
    })
    Corner(Dark, 6)
    New('UIGradient', { Rotation = 90, Transparency = NumberSequence.new(1, 0), Parent = Dark })
    local SVCursor = New('Frame', {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromOffset(10, 10),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 22,
        Parent = SV,
    })
    Corner(SVCursor, 5)
    New('UIStroke', { Color = WHITE, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = SVCursor })

    local function marker(parent)
        local m = New('Frame', {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Size = UDim2.fromOffset(4, 16),
            BackgroundColor3 = WHITE,
            BorderSizePixel = 0,
            ZIndex = 22,
            Parent = parent,
        })
        Corner(m, 2)
        New('UIStroke', { Color = BLACK, Transparency = 0.5, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = m })
        return m
    end

    local A, AFill, ACursor
    if hasAlpha then
        A = New('Frame', {
            Position = UDim2.new(0, 10, 0, AY), Size = UDim2.new(1, -20, 0, 12),
            BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 18, Parent = Outer,
        })
        Corner(A, 4)
        local checker = New('ImageLabel', {
            Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
            Image = 'http://www.roblox.com/asset/?id=12977615774',
            ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(8, 8), ZIndex = 19, Parent = A,
        })
        Corner(checker, 4)
        AFill = New('Frame', {
            Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = CP.Value, BorderSizePixel = 0, ZIndex = 20, Parent = A,
        })
        Corner(AFill, 4)
        New('UIGradient', { Transparency = NumberSequence.new(1, 0), Parent = AFill })
        ACursor = marker(A)
    end

    local H = New('Frame', {
        Position = UDim2.new(0, 10, 0, HY), Size = UDim2.new(1, -20, 0, 12),
        BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 18, Parent = Outer,
    })
    Corner(H, 4)
    local kps = {}
    for i = 0, 6 do
        kps[#kps + 1] = ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i == 6 and 0 or i / 6, 1, 1))
    end
    New('UIGradient', { Color = ColorSequence.new(kps), Parent = H })
    local HCursor = marker(H)

    local function refresh()
        SV.BackgroundColor3 = Color3.fromHSV(CP.Hue, 1, 1)
        SVCursor.Position = UDim2.new(CP.Sat, 0, 1 - CP.Vib, 0)
        HCursor.Position = UDim2.new(CP.Hue, 0, 0.5, 0)
        if AFill then
            AFill.BackgroundColor3 = CP.Value
            ACursor.Position = UDim2.new(1 - CP.Transparency, 0, 0.5, 0)
        end
        if not Box:IsFocused() then
            local v = CP.Value
            local txt = string.format('#%02X%02X%02X', math.floor(v.R * 255 + 0.5), math.floor(v.G * 255 + 0.5), math.floor(v.B * 255 + 0.5))
            if hasAlpha then txt = txt .. string.format('%02X', math.floor((1 - CP.Transparency) * 255 + 0.5)) end
            Box.Text = txt
        end
    end

    Drag(SV, function(x, y)
        local p, sz = SV.AbsolutePosition, SV.AbsoluteSize
        CP.Sat = frac(p.X, sz.X, x)
        CP.Vib = 1 - frac(p.Y, sz.Y, y)
        CP:Display()
    end)
    Drag(H, function(x)
        local p, sz = H.AbsolutePosition, H.AbsoluteSize
        CP.Hue = frac(p.X, sz.X, x)
        CP:Display()
    end)
    if A then
        Drag(A, function(x)
            local p, sz = A.AbsolutePosition, A.AbsoluteSize
            CP.Transparency = 1 - frac(p.X, sz.X, x)
            CP:Display()
        end)
    end

    Box.FocusLost:Connect(function()
        local text = Box.Text
        local hex = text:match('^%s*#?(%x%x%x%x%x%x)%s*$') or text:match('^%s*#?(%x%x%x%x%x%x%x%x)%s*$')
        if hex then
            local c = Color3.fromRGB(tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16))
            CP.Hue, CP.Sat, CP.Vib = Color3.toHSV(c)
            if hasAlpha and #hex == 8 then CP.Transparency = 1 - tonumber(hex:sub(7, 8), 16) / 255 end
        else
            local nums = {}
            for n in text:gmatch('%-?%d+%.?%d*') do nums[#nums + 1] = tonumber(n) end
            if #nums >= 3 then
                local c = Color3.fromRGB(math.clamp(nums[1], 0, 255), math.clamp(nums[2], 0, 255), math.clamp(nums[3], 0, 255))
                CP.Hue, CP.Sat, CP.Vib = Color3.toHSV(c)
                if hasAlpha and nums[4] then CP.Transparency = 1 - math.clamp(nums[4], 0, 255) / 255 end
            end
        end
        CP:Display()
    end)

    local origDisplay = CP.Display
    CP.Display = function(self, ...)
        origDisplay(self, ...)
        Guard('picker refresh', refresh)
    end
    refresh()
end

local function ShrinkRegion(Parent, amount)
    local label = Parent and Parent.TextLabel
    local R = label and Regions[label]
    if R then R.Size = UDim2.new(1, R.Size.X.Offset - amount, 1, 0) end
end

local function SkinColorPicker(Parent, _, list, Idx, Info)
    ShrinkRegion(Parent, 24)
    local CP = getgenv().Options and getgenv().Options[Idx]
    if not CP then return end
    local DF = CP.DisplayFrame
    if DF then
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
    end
    local label = Parent and Parent.TextLabel
    local layout = label and label:FindFirstChildOfClass('UIListLayout')
    if layout then layout.VerticalAlignment = Enum.VerticalAlignment.Center end

    local Outer
    for _, i in ipairs(list) do
        if i.ClassName == 'Frame' and i.Name == 'Color' then Outer = i; break end
    end
    if Outer then BuildPopup(CP, Info, Outer) end
end

local ModeNames = { Off = 'Off Hotkey', Hold = 'On Hotkey', Press = 'Single Press', Toggle = 'Toggle', Always = 'Always on' }
local ModeOrder = { 'Off', 'Hold', 'Press', 'Toggle', 'Always' }

local function SkinKeyPicker(Parent, Idx, Info, list)
    ShrinkRegion(Parent, 29)
    local KP = getgenv().Options and getgenv().Options[Idx]
    if not KP then return end
    local label = Parent and Parent.TextLabel
    local layout = label and label:FindFirstChildOfClass('UIListLayout')
    if layout then layout.VerticalAlignment = Enum.VerticalAlignment.Center end

    local PickOuter
    for _, i in ipairs(list) do
        if i.ClassName == 'Frame' and i.Parent == label then PickOuter = i; break end
    end
    if not PickOuter then return end
    local PickInner = PickOuter:FindFirstChildOfClass('Frame')
    if not PickInner then return end
    local DisplayLabel = PickInner:FindFirstChildOfClass('TextLabel')
    if DisplayLabel then DisplayLabel.Visible = false end
    PickOuter.Size = UDim2.fromOffset(24, 16)
    for _, o in ipairs({ PickOuter, PickInner }) do
        for _, c in ipairs(o:GetChildren()) do
            if c:IsA('UIStroke') then Library:RemoveFromRegistry(c); c:Destroy() end
        end
        o.BackgroundTransparency = 1
        o.BorderSizePixel = 0
        Library:RemoveFromRegistry(o)
    end
    local ChipStroke = nil
    local z = PickInner.ZIndex

    local state = { picking = false }
    local iconItems = {}
    local function iconColor()
        return state.picking and Library.AccentColor or Library.MutedColor
    end
    local function ink(inst, prop)
        inst[prop] = iconColor()
        iconItems[#iconItems + 1] = { inst, prop }
        Library:AddToRegistry(inst, { [prop] = iconColor })
    end
    local function setIcon()
        for _, it in ipairs(iconItems) do it[1][it[2]] = iconColor() end
    end

    local K = New('Frame', {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.fromOffset(13, 9),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = z + 1,
        Parent = PickInner,
    })
    Corner(K, 2)
    local ks = New('UIStroke', { Thickness = 1.2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = K })
    ink(ks, 'Color')
    for _, x in ipairs({ 2, 5, 8 }) do
        local d = New('Frame', {
            Position = UDim2.fromOffset(x, 2), Size = UDim2.fromOffset(2, 1.5), BorderSizePixel = 0, ZIndex = z + 1, Parent = K,
        })
        ink(d, 'BackgroundColor3')
    end
    local sp = New('Frame', {
        Position = UDim2.fromOffset(3, 5), Size = UDim2.fromOffset(6, 1.5), BorderSizePixel = 0, ZIndex = z + 1, Parent = K,
    })
    ink(sp, 'BackgroundColor3')

    local Button = New('TextButton', {
        BackgroundTransparency = 1,
        Text = '',
        AutoButtonColor = false,
        Active = true,
        Size = UDim2.new(1, 0, 1, 0),
        ZIndex = z + 4,
        Parent = PickOuter,
    })

    local modes = {}
    local have = {}
    for _, m in ipairs(Info and Info.Modes or {}) do have[m] = true end
    for _, m in ipairs(ModeOrder) do
        if have[m] then modes[#modes + 1] = m; have[m] = nil end
    end
    for _, m in ipairs(Info and Info.Modes or {}) do
        if have[m] then modes[#modes + 1] = m; have[m] = nil end
    end

    local MENU_W = 118
    local ROW = 22
    local Menu = New('Frame', {
        AnchorPoint = Vector2.new(1, 0),
        Size = UDim2.fromOffset(MENU_W, 8 + ROW + 5 + #modes * ROW),
        BackgroundColor3 = Library.PanelColor,
        BackgroundTransparency = 0.03,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 60,
        Parent = Library.ScreenGui,
    })
    Library:AddToRegistry(Menu, { BackgroundColor3 = 'PanelColor' })
    Corner(Menu, 7)
    Stroke(Menu, 'OutlineColor', 1, 0.2)

    local function row(y, text)
        return New('TextButton', {
            AutoButtonColor = false,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(4, y),
            Size = UDim2.new(1, -8, 0, ROW),
            Font = Fonts.Medium,
            Text = text,
            TextSize = Library.FontSize - 1,
            TextColor3 = Library.MutedColor,
            ZIndex = 61,
            Parent = Menu,
        })
    end

    local KeyRow = row(4, '')
    KeyRow.TextColor3 = Library.FontColor
    Library:AddToRegistry(KeyRow, { TextColor3 = 'FontColor' })
    New('Frame', {
        Position = UDim2.fromOffset(10, 4 + ROW + 2),
        Size = UDim2.new(1, -20, 0, 1),
        BackgroundColor3 = Library.OutlineColor,
        BorderSizePixel = 0,
        ZIndex = 61,
        Parent = Menu,
    })
    Library:AddToRegistry(Menu:GetChildren()[#Menu:GetChildren()], { BackgroundColor3 = 'OutlineColor' })

    local rows = {}
    local refreshMenu
    for index, mode in ipairs(modes) do
        local r = row(4 + ROW + 5 + (index - 1) * ROW, ModeNames[mode] or mode)
        rows[mode] = r
        Library:AddToRegistry(r, { TextColor3 = function()
            return KP.Mode == mode and Library.AccentColor or Library.MutedColor
        end })
        r.MouseButton1Click:Connect(function()
            KP:SetValue({ KP.Value, mode })
            refreshMenu()
            Library:AttemptSave()
        end)
    end

    local function keyText()
        local k = KP.Value
        if k == nil or k == 'None' then return '[ ... ]' end
        if #k == 1 then k = string.lower(k) end
        return '[' .. k .. ']'
    end

    refreshMenu = function()
        KeyRow.Text = keyText()
        for mode, r in pairs(rows) do
            r.TextColor3 = KP.Mode == mode and Library.AccentColor or Library.MutedColor
        end
    end

    local function close()
        Menu.Visible = false
        Library.OpenedFrames[Menu] = nil
    end

    local function shown()
        local p = PickOuter
        while p and p ~= Library.ScreenGui do
            if p:IsA('GuiObject') and not p.Visible then return false end
            p = p.Parent
        end
        return p ~= nil
    end

    local function place()
        Menu.Position = UDim2.fromOffset(
            PickOuter.AbsolutePosition.X + PickOuter.AbsoluteSize.X,
            PickOuter.AbsolutePosition.Y + PickOuter.AbsoluteSize.Y + 4
        )
    end

    local function open()
        refreshMenu()
        place()
        Menu.Visible = true
        Library.OpenedFrames[Menu] = true
        task.spawn(function()
            while Menu.Visible do
                if not Library.Toggled or not shown() then close() break end
                place()
                task.wait()
            end
        end)
    end

    KeyRow.MouseButton1Click:Connect(function()
        if state.picking then return end
        state.picking = true
        setIcon()
        task.spawn(function()
            task.wait(0.2)
            local conn
            conn = InputService.InputBegan:Connect(function(Input)
                local Key
                if Input.UserInputType == Enum.UserInputType.Keyboard then
                    Key = Input.KeyCode == Enum.KeyCode.Escape and 'None' or Input.KeyCode.Name
                elseif Input.UserInputType == Enum.UserInputType.MouseButton1 then
                    Key = 'MB1'
                elseif Input.UserInputType == Enum.UserInputType.MouseButton2 then
                    Key = 'MB2'
                elseif Input.UserInputType == Enum.UserInputType.Touch then
                    Key = 'Touch'
                end
                if not Key then return end
                conn:Disconnect()
                task.delay(0.05, function()
                    KP.Value = Key
                    state.picking = false
                    setIcon()
                    Library:SafeCallback(KP.ChangedCallback, Input.KeyCode or Input.UserInputType)
                    Library:SafeCallback(KP.Changed, Input.KeyCode or Input.UserInputType)
                    Library:AttemptSave()
                    KP:Update()
                    refreshMenu()
                end)
            end)
        end)
    end)

    Button.MouseButton1Click:Connect(function()
        if Menu.Visible then close() else open() end
    end)
    Button.MouseEnter:Connect(function()
        if ChipStroke then ChipStroke.Color = Library.AccentColor end
    end)
    Button.MouseLeave:Connect(function()
        if ChipStroke then ChipStroke.Color = Library.OutlineColor end
    end)
    local origState = KP.GetState
    KP.GetState = function(self)
        local m = self.Mode
        if m == 'Off' then
            if self.Value == 'None' then return true end
            self.Mode = 'Hold'
            local held = origState(self)
            self.Mode = m
            return not held
        elseif m == 'Press' then
            return self.Toggled and true or false
        end
        return origState(self)
    end

    Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
        if KP.Mode ~= 'Press' or state.picking then return end
        local key = KP.Value
        if key == nil or key == 'None' then return end
        local hit = (key == 'MB1' and Input.UserInputType == Enum.UserInputType.MouseButton1)
            or (key == 'MB2' and Input.UserInputType == Enum.UserInputType.MouseButton2)
            or (key == 'Touch' and Input.UserInputType == Enum.UserInputType.Touch)
            or (Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode.Name == key)
        if hit then
            KP.Toggled = true
            KP:DoClick()
            KP:Update()
            task.delay(0.1, function()
                KP.Toggled = false
                KP:Update()
            end)
        end
    end))
end

local function WrapKeyPicker(Funcs)
    local orig = Funcs.AddKeyPicker
    if type(orig) ~= 'function' then return end
    Funcs.AddKeyPicker = function(self, Idx, Info, ...)
        if type(Info) == 'table' and Info.Modes == nil then
            Info.Modes = { 'Off', 'Hold', 'Press', 'Toggle', 'Always' }
        end
        local list, res = Capture(orig, self, Idx, Info, ...)
        if not res[1] then error(res[2], 0) end
        Guard('AddKeyPicker', SkinKeyPicker, self, Idx, Info, list)
        return table.unpack(res, 2, res.n)
    end
end

local function PatchFuncs(Funcs)
    if type(Funcs) ~= 'table' or Funcs.__PerceptionSkin then return end
    Funcs.__PerceptionSkin = true
    WrapFn(Funcs, 'AddToggle', SkinToggle)
    WrapFn(Funcs, 'AddSlider', SkinSlider)
    WrapFn(Funcs, 'AddDropdown', SkinDropdown)
    WrapFn(Funcs, 'AddColorPicker', SkinColorPicker)
    WrapKeyPicker(Funcs)
    WrapFn(Funcs, 'AddLabel', function(self, ret) PatchFrom(ret) end)
end

PatchFrom = function(obj)
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
    Corner(BoxOuter, 6)
    Stroke(BoxOuter, 'OutlineColor', 1, 0.6)

    Strip(BoxInner)
    BoxInner.BackgroundTransparency = 1
    BoxInner.BorderSizePixel = 0
    BoxInner.Position = UDim2.new(0, 0, 0, 0)
    BoxInner.Size = UDim2.new(1, 0, 1, 0)

    for _, c in ipairs(BoxInner:GetChildren()) do
        if c:IsA('Frame') and c ~= Container and c.Size.Y.Offset == 2 and c.BorderSizePixel == 0 then
            c.Visible = false
        elseif c:IsA('TextLabel') then
            c.Position = UDim2.new(0, 0, 0, 8)
            c.Size = UDim2.new(1, 0, 0, 20)
            c.TextXAlignment = Enum.TextXAlignment.Center
            c.TextSize = Library.FontSize + 2
            c.Font = Fonts.Medium
            Muted(c)
        end
    end

    Container.Position = UDim2.new(0, CARD_PAD, 0, CARD_TOP)
    Container.Size = UDim2.new(1, -CARD_PAD * 2, 1, -CARD_TOP)

    Groupbox.Resize = function(g)
        local Size = 0
        for _, El in ipairs(Container:GetChildren()) do
            if El:IsA('GuiObject') and El.Visible then
                Size = Size + El.Size.Y.Offset
            end
        end
        BoxOuter.Size = UDim2.new(1, 0, 0, CARD_TOP + Size + 10)
    end
    Groupbox:Resize()
end

local IconData = {
    eye = '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',
    half = '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',
    gear = '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',
    people = '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',
    cross = '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',
}
local B64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local B64Map = {}
for i = 1, 64 do B64Map[string.byte(B64, i)] = i - 1 end
local function b64decode(str)
    local out, acc, bits = {}, 0, 0
    for i = 1, #str do
        local v = B64Map[string.byte(str, i)]
        if v then
            acc = acc * 64 + v
            bits = bits + 6
            if bits >= 8 then
                bits = bits - 8
                local p = 2 ^ bits
                local byte = math.floor(acc / p)
                acc = acc - byte * p
                out[#out + 1] = string.char(byte)
            end
        end
    end
    return table.concat(out)
end

local IconCache = {}
local function IconAsset(key)
    if IconCache[key] ~= nil then return IconCache[key] or nil end
    IconCache[key] = false
    if opt('NativeIcons', true) == false then return nil end
    local data = IconData[key]
    if not data then return nil end
    local env = (getgenv and getgenv()) or {}
    local write = env.writefile or writefile
    local custom = env.getcustomasset or env.getsynasset or getcustomasset or getsynasset
    if type(write) ~= 'function' or type(custom) ~= 'function' then return nil end
    local ok, id = pcall(function()
        local folder = 'PerceptionSkin'
        local isf, mkf = env.isfolder or isfolder, env.makefolder or makefolder
        if type(isf) == 'function' and type(mkf) == 'function' and not isf(folder) then mkf(folder) end
        local path = folder .. '/icon_' .. key .. '.png'
        write(path, b64decode(data))
        return custom(path)
    end)
    if ok and type(id) == 'string' and id ~= '' then
        IconCache[key] = id
        return id
    end
    return nil
end

local ImageKeys = { crosshair = 'cross', eye = 'eye', globe = 'half', people = 'people', gear = 'gear' }

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
        return state.active and Bright() or Library.MutedColor
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
    local asset = type(key) == 'string' and ImageKeys[key] and IconAsset(ImageKeys[key])
    if asset then
        P.Size = UDim2.fromOffset(20, 20)
        local img = New('ImageLabel', {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Image = asset,
            ZIndex = 3,
            Parent = P,
        })
        ink(img, 'ImageColor3')
    elseif type(key) == 'function' then
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
            Font = Fonts.Bold,
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
        Corner(BoxOuter, 6)
        Stroke(BoxOuter, 'OutlineColor', 1, 0.6)
        Strip(BoxInner)
        BoxInner.BackgroundTransparency = 1
        BoxInner.BorderSizePixel = 0
        BoxInner.Position = UDim2.new(0, 0, 0, 0)
        BoxInner.Size = UDim2.new(1, 0, 1, 0)
        Buttons.Position = UDim2.new(0, 8, 0, 8)
        Buttons.Size = UDim2.new(1, -16, 0, 24)
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
        Label.TextSize = Library.FontSize + 1
        Label.Font = Fonts.Medium
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
            BoxOuter.Size = UDim2.new(1, 0, 0, CARD_TOP + 4 + Size + 10)
        end
    end
    TabObj.__skinStyle = style
    Container.Position = UDim2.new(0, CARD_PAD, 0, CARD_TOP + 4)
    Container.Size = UDim2.new(1, -CARD_PAD * 2, 1, -(CARD_TOP + 4))
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
    Corner(TabButton, 8)
    if Label then Label.Visible = false end
    if Indicator then
        Strip(Indicator)
        Indicator.AnchorPoint = Vector2.new(0.5, 1)
        Indicator.Position = UDim2.new(0.5, 0, 1, 0)
        Indicator.Size = UDim2.fromOffset(14, 2)
        Indicator.Position = UDim2.new(0.5, 0, 1, -3)
        Indicator.BackgroundColor3 = Bright()
        Library:RemoveFromRegistry(Indicator)
        Library:AddToRegistry(Indicator, { BackgroundColor3 = Bright })
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
    ctx.Pill.Size = UDim2.new(0, 14 + ctx.Count * TAB_W + (ctx.Count - 1) * TAB_GAP, 0, PILL_H)

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
        for _, sd in ipairs(sides) do
            sd.Position = UDim2.new(sd.Position.X.Scale, sd.Position.X.Offset, 0, SUB_H + 10)
            sd.Size = UDim2.new(sd.Size.X.Scale, sd.Size.X.Offset, 1, -(SUB_H + 10))
        end

        local widths = {}
        for index, name in ipairs(names) do
            widths[index] = Library:GetTextBounds(name, Fonts.Medium, Library.FontSize) + 28
        end

        local holder = New('Frame', {
            Position = UDim2.new(0, 0, 0, 0),
            Size = UDim2.new(1, 0, 0, SUB_H),
            BackgroundColor3 = Library.PillColor,
            BackgroundTransparency = 0.25,
            BorderSizePixel = 0,
            ZIndex = 3,
            Parent = TabFrame,
        })
        Library:AddToRegistry(holder, { BackgroundColor3 = 'PillColor' })
        Corner(holder, 6)
        Stroke(holder, 'OutlineColor', 1, 0.65)
        New('UIPadding', { PaddingLeft = UDim.new(0, 4), Parent = holder })
        New('UIListLayout', {
            FillDirection = Enum.FillDirection.Horizontal,
            Padding = UDim.new(0, 0),
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = holder,
        })

        local function apply()
            for name, group in pairs(bar.groups) do
                for _, frame in ipairs(group) do frame.Visible = name == bar.current end
            end
            for name, pill in pairs(bar.pills) do
                local active = name == bar.current
                pill.TextColor3 = active and Bright() or Library.MutedColor
                local r = Library.RegistryMap[pill]
                if r then r.Properties.TextColor3 = active and Bright or 'MutedColor' end
                local u = pill:FindFirstChild('Underline')
                if u then u.Visible = active end
            end
        end

        for index, name in ipairs(names) do
            local pill = New('TextButton', {
                AutoButtonColor = false,
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Size = UDim2.fromOffset(widths[index], SUB_H),
                LayoutOrder = index,
                Font = Fonts.Medium,
                Text = name,
                TextSize = Library.FontSize,
                TextColor3 = Library.MutedColor,
                ZIndex = 4,
                Parent = holder,
            })
            Library:AddToRegistry(pill, { TextColor3 = 'MutedColor' })
            local underline = New('Frame', {
                Name = 'Underline',
                AnchorPoint = Vector2.new(0.5, 1),
                Position = UDim2.new(0.5, 0, 1, -3),
                Size = UDim2.fromOffset(14, 2),
                BackgroundColor3 = Bright(),
                BorderSizePixel = 0,
                Visible = false,
                ZIndex = 5,
                Parent = pill,
            })
            Corner(underline, 1)
            Library:AddToRegistry(underline, { BackgroundColor3 = Bright })
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

    local Shadow = opt('Shadow', false) and New('ImageLabel', {
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

    local Logo = New('Frame', {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 18, 0, HEADER / 2),
        Size = UDim2.fromOffset(34, 34),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 3,
        Parent = Inner,
    })
    if type(Config.Logo) == 'string' and Config.Logo ~= '' then
        local img = New('ImageLabel', {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Image = Config.Logo,
            ZIndex = 3,
            Parent = Logo,
        })
        img.ImageColor3 = Library.FontColor
        Library:AddToRegistry(img, { ImageColor3 = 'FontColor' })
    else
        local function ringPart(size, thick, parent)
            local f = New('Frame', {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0.5, 0, 0.5, 0),
                Size = UDim2.fromOffset(size, size),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                ZIndex = 3,
                Parent = parent,
            })
            New('UICorner', { CornerRadius = UDim.new(1, 0), Parent = f })
            local st = New('UIStroke', {
                Color = Library.FontColor, Thickness = thick,
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = f,
            })
            Library:AddToRegistry(st, { Color = 'FontColor' })
            return f
        end
        ringPart(28, 3, Logo)
        ringPart(14, 2, Logo)
        local dot = New('Frame', {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            Size = UDim2.fromOffset(5, 5),
            BackgroundColor3 = Library.FontColor,
            BorderSizePixel = 0,
            ZIndex = 3,
            Parent = Logo,
        })
        New('UICorner', { CornerRadius = UDim.new(1, 0), Parent = dot })
        Library:AddToRegistry(dot, { BackgroundColor3 = 'FontColor' })
    end

    TitleLabel.AnchorPoint = Vector2.new(0, 0.5)
    TitleLabel.Position = UDim2.new(0, 62, 0, HEADER / 2)
    TitleLabel.Size = UDim2.new(0, 120, 0, 22)
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.Font = Fonts.Bold
    TitleLabel.TextSize = Library.FontSize + 4
    TitleLabel.TextTruncate = Enum.TextTruncate.AtEnd
    TitleLabel.ZIndex = 3
    Library:RemoveFromRegistry(TitleLabel)
    TitleLabel.TextColor3 = Bright()
    Library:AddToRegistry(TitleLabel, { TextColor3 = Bright })

    Strip(TabBarOuter)
    TabBarOuter.AnchorPoint = Vector2.new(0.5, 0.5)
    TabBarOuter.Position = UDim2.new(0.5, 0, 0, HEADER / 2)
    TabBarOuter.Size = UDim2.new(0, 14, 0, PILL_H)
    TabBarOuter.BorderSizePixel = 0
    TabBarOuter.BackgroundColor3 = Library.PillColor
    TabBarOuter.BackgroundTransparency = 0
    TabBarOuter.ZIndex = 2
    Reg(TabBarOuter, { BackgroundColor3 = 'PillColor' })
    Corner(TabBarOuter, 10)
    Stroke(TabBarOuter, 'OutlineColor', 1, 0.6)
    Flat(TabBarInner)
    TabArea.Position = UDim2.new(0, 7, 0, 3)
    TabArea.Size = UDim2.new(1, -14, 1, -6)
    TabList.Padding = UDim.new(0, TAB_GAP)
    TabList.VerticalAlignment = Enum.VerticalAlignment.Center

    local CHIP_W = 156
    local Chip = New('Frame', {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -16, 0, HEADER / 2),
        Size = UDim2.fromOffset(CHIP_W, PILL_H),
        BackgroundColor3 = Library.PillColor,
        BorderSizePixel = 0,
        ZIndex = 2,
        Parent = Inner,
    })
    Library:AddToRegistry(Chip, { BackgroundColor3 = 'PillColor' })
    Corner(Chip, 10)
    Stroke(Chip, 'OutlineColor', 1, 0.6)

    local uid = LocalPlayer and LocalPlayer.UserId or 0
    local uname = opt('UserName', LocalPlayer and (LocalPlayer.DisplayName or LocalPlayer.Name) or 'user')
    local Avatar = New('ImageLabel', {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 6, 0.5, 0),
        Size = UDim2.fromOffset(30, 30),
        BackgroundColor3 = Library.MainColor,
        BorderSizePixel = 0,
        Image = opt('Avatar', ''),
        ZIndex = 3,
        Parent = Chip,
    })
    Library:AddToRegistry(Avatar, { BackgroundColor3 = 'MainColor' })
    New('UICorner', { CornerRadius = UDim.new(1, 0), Parent = Avatar })
    if Config.Avatar == nil and uid ~= 0 then
        task.spawn(function()
            local ok, img = pcall(function()
                return Players:GetUserThumbnailAsync(uid, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
            end)
            if ok and img and Avatar.Parent then Avatar.Image = img end
        end)
    end

    local UserLabel = Library:CreateLabel({
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 44, 0.5, MapLabel and -7 or 0),
        Size = UDim2.new(1, -50, 0, 16),
        Text = tostring(uname),
        TextSize = Library.FontSize,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Font = Fonts.Bold,
        ZIndex = 3,
        Parent = Chip,
    })
    if MapLabel then
        MapLabel.Parent = Chip
        MapLabel.AnchorPoint = Vector2.new(0, 0.5)
        MapLabel.Position = UDim2.new(0, 44, 0.5, 8)
        MapLabel.Size = UDim2.new(1, -50, 0, 13)
        MapLabel.TextXAlignment = Enum.TextXAlignment.Left
        MapLabel.TextSize = Library.FontSize - 3
        MapLabel.TextTruncate = Enum.TextTruncate.AtEnd
        MapLabel.ZIndex = 3
        Muted(MapLabel)
    end

    Flat(MainOuter)
    MainOuter.Position = UDim2.new(0, 0, 0, HEADER)
    MainOuter.Size = UDim2.new(1, 0, 1, -HEADER)
    Flat(MainInner)
    Flat(TabContainer)
    TabContainer.Position = UDim2.new(0, 14, 0, 4)
    TabContainer.Size = UDim2.new(1, -28, 1, -16)

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

local deriving = false
function Skin.Derive()
    if not Skin.AutoDerive then return end
    deriving = true
    Library.PanelColor = mix(Library.BackgroundColor, BLACK, 0.35)
    Library.PillColor = mix(Library.BackgroundColor, BLACK, 0.17)
    Library.MutedColor = mix(Library.FontColor, Library.BackgroundColor, 0.45)
    Library.CheckColor = mix(Library.BackgroundColor, WHITE, 0.1)
    Library:UpdateColorsUsingRegistry()
    local O = LiveOptions or getgenv().Options
    if O then
        for _, k in ipairs({ 'PanelColor', 'MutedColor', 'CheckColor' }) do
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
    'SkinNotifyX', 'SkinNotifyY', 'SkinNotifyAlpha', 'PanelColor', 'MutedColor', 'CheckColor', 'SkinPanelAlpha', 'SkinCardAlpha',
}

local function BindEnv(tbl)
    if type(tbl) ~= 'table' or type(setfenv) ~= 'function' or type(getfenv) ~= 'function' then return end
    pcall(function()
        local env = setmetatable({
            Options = LiveOptions or getgenv().Options,
            Toggles = LiveToggles or getgenv().Toggles,
        }, { __index = getfenv(1) })
        for _, v in pairs(tbl) do
            if type(v) == 'function' then pcall(setfenv, v, env) end
        end
    end)
end

local function Safe(label, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then
        warn('[PerceptionSkin] ' .. label .. ': ' .. tostring(err))
        pcall(function() Library:Notify(label .. ' failed: ' .. tostring(err), 8) end)
    end
    return ok
end

function Skin.BuildSettings(Window, Opts)
    Opts = type(Opts) == 'table' and Opts or {}
    local TM, SM = Opts.ThemeManager, Opts.SaveManager
    local Tab = Window:AddTab(Opts.TabName or 'Settings')
    local subs = Tab:SubTabs({ 'Menu', 'Theme', 'Config' })

    local Menu = subs.Menu:AddLeftGroupbox('Menu')
    Menu:AddLabel('Menu bind'):AddKeyPicker('MenuKeybind', { Default = Opts.MenuKey or 'RightShift', NoUI = true, Text = 'Menu keybind' })
    Library.ToggleKeybind = (LiveOptions or getgenv().Options).MenuKeybind
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
        BindEnv(TM)
        TM.BuiltInThemes['Perception Skin'] = { 0, {
            FontColor = 'b6b6b6', MainColor = '111111', AccentColor = '678993',
            BackgroundColor = '171717', OutlineColor = '282828',
        } }
        TM.DefaultTheme = 'Perception Skin'
        if Opts.Folder then TM:SetFolder(Opts.Folder) end
        local origUpdate = TM.ThemeUpdate
        TM.ThemeUpdate = function(self, ...)
            origUpdate(self, ...)
            Skin.Derive()
        end
        Safe('ThemeManager', TM.ApplyToTab, TM, subs.Theme)
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
    Look:AddLabel('Control color'):AddColorPicker('CheckColor', {
        Default = Library.CheckColor, Title = 'Control color',
        Callback = function(c)
            if deriving then return end
            Skin.AutoDerive = false
            Library.CheckColor = c
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
        BindEnv(SM)
        SM:SetLibrary(Library)
        if Opts.Folder then SM:SetFolder(Opts.Folder .. '/' .. (Opts.Game or 'configs')) end
        if SM.IgnoreThemeSettings then SM:IgnoreThemeSettings() end
        SM:SetIgnoreIndexes(SETTINGS_FLAGS)
        local About = subs.Config:AddLeftGroupbox('Storage')
        About:AddLabel('Configs: ' .. tostring(SM.Folder) .. '/settings', true)
        About:AddLabel('Themes: ' .. tostring(TM and TM.Folder or SM.Folder) .. '/themes', true)
        Safe('SaveManager', SM.BuildConfigSection, SM, subs.Config)
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
