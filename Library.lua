local Env = (type(getgenv) == 'function' and getgenv()) or _G;

local function GetService(Name)
    local Service = game:GetService(Name);
    if type(cloneref) == 'function' then
        local Ok, Cloned = pcall(cloneref, Service);
        if Ok and Cloned then
            return Cloned;
        end;
    end;
    return Service;
end;

local InputService = GetService('UserInputService');
local TextService = GetService('TextService');
local CoreGui = GetService('CoreGui');
local Teams = GetService('Teams');
local Players = GetService('Players');
local RunService = GetService('RunService')
local TweenService = GetService('TweenService');
local Lighting = GetService('Lighting');
local RenderStepped = RunService.RenderStepped;
local LocalPlayer = Players.LocalPlayer;
local Mouse = LocalPlayer:GetMouse();

local OldLibrary = Env.Library;
if type(OldLibrary) == 'table' and OldLibrary.ScreenGui then
    pcall(function()
        if OldLibrary.Unload then OldLibrary:Unload(); end;
        OldLibrary.ScreenGui:Destroy();
    end);
    Env.Library = nil;
end

local ProtectGui = protectgui or (syn and syn.protect_gui) or (function() end);

local function GetGuiParent()
    local Ok, Hui = pcall(function()
        return type(gethui) == 'function' and gethui() or nil;
    end);
    if Ok and Hui then
        return Hui;
    end;
    return CoreGui;
end;

local ScreenGui = Instance.new('ScreenGui');
ScreenGui.Name = 'Aster';
pcall(ProtectGui, ScreenGui);
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global;
ScreenGui.ResetOnSpawn = false;
ScreenGui.Parent = GetGuiParent();

local Toggles = {};
local Options = {};

Env.Toggles = Toggles;
Env.Options = Options;

local Library = {
    Registry = {};
    RegistryMap = {};

    HudRegistry = {};

    FontColor = Color3.fromRGB(232, 232, 240);
    MainColor = Color3.fromRGB(18, 18, 22);
    BackgroundColor = Color3.fromRGB(12, 12, 15);
    AccentColor = Color3.fromRGB(139, 92, 246);
    AccentColor2 = Color3.fromRGB(56, 189, 248);
    OutlineColor = Color3.fromRGB(34, 34, 42);
    RiskColor = Color3.fromRGB(255, 70, 90),

    Black = Color3.new(0, 0, 0);

    AnimatedGradient = true;
    GradientSpeed = 0.35;
    MenuFadeTime = 0.2;

    Font = Enum.Font.GothamMedium,
    FontSize = 13,

    OpenedFrames = {};
    DependencyBoxes = {};

    Signals = {};
    ScreenGui = ScreenGui;

    Toggled = false;
    WireframeDrag = true;
    UseBlur = true;
    BlurSize = 24;
    UseDarken = true;
    DarkenAmount = 55;

    KeybindMode = 'All';

    NotifyConfig = {
        ClipDescendants  = false;
        MaxHeight        = 200;
        PosX             = 50;
        PosY             = 60;
        Transparency     = 60;
        Alignment        = "Center";
        BarSide          = "Bottom";
        SortOrder        = "Time";
    };
    NotifyQueue       = {};
    ActiveNotifyCount = 0;
    NotifyCounter     = 0;
};

Library.KeyPickerList = {};
Library.Toggles = Toggles;
Library.Options = Options;

Library.BlurEffect = Instance.new("BlurEffect")
Library.BlurEffect.Name = "AsterBlur"
Library.BlurEffect.Size = 0
Library.BlurEffect.Enabled = false
pcall(function() Library.BlurEffect.Parent = Lighting end)

do
    local OverlayGui = Instance.new("ScreenGui")
    OverlayGui.Name = "AsterBlurOverlay"
    OverlayGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    OverlayGui.DisplayOrder = -9999
    pcall(ProtectGui, OverlayGui)
    OverlayGui.Parent = GetGuiParent()

    Library.DarkOverlay = Instance.new("Frame")
    Library.DarkOverlay.Name = "DarkOverlay"
    Library.DarkOverlay.Size = UDim2.new(10, 0, 10, 0)
    Library.DarkOverlay.Position = UDim2.new(-5, 0, -5, 0)
    Library.DarkOverlay.BackgroundColor3 = Color3.new(0, 0, 0)
    Library.DarkOverlay.BackgroundTransparency = 1
    Library.DarkOverlay.BorderSizePixel = 0
    Library.DarkOverlay.ZIndex = 1
    Library.DarkOverlay.Parent = OverlayGui
end

function Library:UpdateBlur()
    local open = Library.Toggled and Library.UseBlur;
    local targetSize = open and Library.BlurSize or 0;

    if open then
        Library.BlurEffect.Enabled = true;
    end

    Library:Tween(Library.BlurEffect, { Size = targetSize }, 0.2);

    if Library.DarkOverlay then
        local dark = Library.Toggled and Library.UseDarken;
        Library:Tween(Library.DarkOverlay, { BackgroundTransparency = dark and (1 - (Library.DarkenAmount / 100)) or 1 }, 0.2);
    end

    if not open then
        task.delay(0.25, function()
            if not (Library.Toggled and Library.UseBlur) then
                pcall(function() Library.BlurEffect.Enabled = false end);
            end
        end);
    end
end

function Library:SetBlur(Size)
    Library.BlurSize = math.clamp(Size, 0, 56);
    if Library.Toggled and Library.UseBlur then
        Library.BlurEffect.Size = Library.BlurSize;
    end
end

-- Call this with any Groupbox to add a blur toggle + size slider
-- e.g. Library:AddBlurSlider(MyGroupbox)
function Library:AddBlurSlider(Groupbox)
    Groupbox:AddToggle('LinoriaUseBlur', {
        Text    = 'Background Blur';
        Default = Library.UseBlur;
        Tooltip = 'Blur the background when the menu is open';
        Callback = function(Value)
            Library.UseBlur = Value;
            Library:UpdateBlur();
        end;
    });
    Groupbox:AddSlider('LinoriaBlurSize', {
        Text     = 'Blur Amount';
        Default  = Library.BlurSize;
        Min      = 0;
        Max      = 56;
        Rounding = 0;
        Callback = function(Value)
            Library:SetBlur(Value);
        end;
    });
end

-- Call this with any Groupbox to add a darken toggle + amount slider
-- e.g. Library:AddDarkenSlider(MyGroupbox)
function Library:AddDarkenSlider(Groupbox)
    Groupbox:AddToggle('LinoriaUseDarken', {
        Text    = 'Background Darken';
        Default = Library.UseDarken;
        Tooltip = 'Darken the background when the menu is open';
        Callback = function(Value)
            Library.UseDarken = Value;
            Library:UpdateBlur();
        end;
    });
    Groupbox:AddSlider('LinoriaDarkenAmount', {
        Text     = 'Darken Amount';
        Default  = Library.DarkenAmount;
        Min      = 0;
        Max      = 100;
        Rounding = 0;
        Suffix   = '%';
        Callback = function(Value)
            Library.DarkenAmount = Value;
            Library:UpdateBlur();
        end;
    });
end

-- Control keybind frame background transparency (0 = opaque, 1 = invisible)
function Library:SetKeybindTransparency(Value)
    Value = math.clamp(Value, 0, 1);
    local Inner = Library.KeybindInner;
    if Library.KeybindFrame then
        Library.KeybindFrame.BackgroundTransparency = Value;
        Library.KeybindFrame.BorderSizePixel = Value >= 1 and 0 or 1;
        if not Inner then
            Inner = Library.KeybindFrame:FindFirstChildOfClass('Frame');
        end
    end
    if Inner then
        Inner.BackgroundTransparency = Value;
        Inner.BorderSizePixel = Value >= 1 and 0 or 1;
    end
    if Library.KeybindColorFrame then
        Library.KeybindColorFrame.BackgroundTransparency = Value;
    end
end

-- Call this with any Groupbox to add a keybind frame transparency slider
-- e.g. Library:AddKeybindTransparencySlider(MyGroupbox)
function Library:AddKeybindTransparencySlider(Groupbox)
    Groupbox:AddSlider('LinoriaKeybindTransparency', {
        Text     = 'Keybind Transparency';
        Default  = 0;
        Min      = 0;
        Max      = 100;
        Rounding = 0;
        Suffix   = '%';
        Callback = function(Value)
            Library:SetKeybindTransparency(Value / 100);
        end;
    });
end

function Library:SetFontSize(Size)
    Library.FontSize = Size
    for _, descendant in pairs(ScreenGui:GetDescendants()) do
        if descendant:IsA("TextLabel") or descendant:IsA("TextBox") or descendant:IsA("TextButton") then
            local offset = descendant:GetAttribute("FontSizeOffset")
            if offset then
                descendant.TextSize = Size + offset
            end
        end
    end
    local mobileUI = Library.MobileGui
    if mobileUI then
        for _, descendant in pairs(mobileUI:GetDescendants()) do
            if descendant:IsA("TextLabel") or descendant:IsA("TextBox") or descendant:IsA("TextButton") then
                local offset = descendant:GetAttribute("FontSizeOffset")
                if offset then
                    descendant.TextSize = Size + offset
                end
            end
        end
    end
end

local RainbowStep = 0
local Hue = 0

table.insert(Library.Signals, RenderStepped:Connect(function(Delta)
    RainbowStep = RainbowStep + Delta

    if RainbowStep >= (1 / 60) then
        RainbowStep = 0

        Hue = Hue + (1 / 400);
        if Hue > 1 then
            Hue = 0;
        end;

        Library.CurrentRainbowHue = Hue;
        Library.CurrentRainbowColor = Color3.fromHSV(Hue, 0.8, 1);
    end
end))

local function GetPlayersString()
    local PlayerList = Players:GetPlayers();
    for i = 1, #PlayerList do
        PlayerList[i] = PlayerList[i].Name;
    end;
    table.sort(PlayerList, function(str1, str2) return str1 < str2 end);

    return PlayerList;
end;

local function GetTeamsString()
    local TeamList = Teams:GetTeams();
    for i = 1, #TeamList do
        TeamList[i] = TeamList[i].Name;
    end;
    table.sort(TeamList, function(str1, str2) return str1 < str2 end);
    
    return TeamList;
end;

function Library:SafeCallback(f, ...)
    if (not f) then
        return;
    end;
    if not Library.NotifyOnError then
        return f(...);
    end;

    local success, event = pcall(f, ...);
    if not success then
        local _, i = event:find(":%d+: ");
        if not i then
            return Library:Notify(event);
        end;
        return Library:Notify(event:sub(i + 1), 3);
    end;
end;

function Library:AttemptSave()
    if Library.SaveManager then
        Library.SaveManager:Save();
    end;
end;

function Library:Create(Class, Properties)
    local _Instance = Class;
    if type(Class) == 'string' then
        _Instance = Instance.new(Class);
        if Properties.BorderColor3 == nil then
            pcall(function()
                _Instance.BorderSizePixel = 0;
            end);
        end;
    end;
    for Property, Value in next, Properties do
        pcall(function()
            _Instance[Property] = Value;
        end);
    end;

    if _Instance:IsA("TextLabel") or _Instance:IsA("TextBox") or _Instance:IsA("TextButton") then
        if Properties.TextSize then
            _Instance:SetAttribute("FontSizeOffset", Properties.TextSize - Library.FontSize)
        else
            _Instance:SetAttribute("FontSizeOffset", 0)
        end
    end

    return _Instance;
end;

function Library:ApplyTextStroke(Inst)
    Inst.TextStrokeTransparency = 1;
end;

function Library:ApplyGlow(Inst)

end;

function Library:CreateLabel(Properties, IsHud)
    local Dim = Properties.Dim;
    Properties.Dim = nil;
    local _Instance = Library:Create('TextLabel', {
        BackgroundTransparency = 1;
        Font = Library.Font;
        TextColor3 = Dim and Library:GetDimColor() or Library.FontColor;
        TextSize = Library.FontSize + 2;
        TextStrokeTransparency = 1;
    });

    Library:AddToRegistry(_Instance, {
        TextColor3 = Dim and function() return Library:GetDimColor() end or 'FontColor';
    }, IsHud);
    return Library:Create(_Instance, Properties);
end;

function Library:MakeDraggable(Instance, Cutoff, IsWindow)
    Instance.Active = true;
    Instance.InputBegan:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
            local StartPos = Instance.Position
            local DragStart = Input.Position

            if (DragStart.Y - Instance.AbsolutePosition.Y) > (Cutoff or 40) then
                return
            end

            local Dragging = true
            local HasMoved = false
            local Wireframe = nil
            local ChangedConn, EndedConn

            ChangedConn = InputService.InputChanged:Connect(function(Change)
                if Change.UserInputType == Enum.UserInputType.MouseMovement or Change == Input then
                    local Delta = Change.Position - DragStart
                    
                    if IsWindow and Library.WireframeDrag then
                        if not HasMoved and Delta.Magnitude > 2 then
                            HasMoved = true
                            
                            Wireframe = Library:Create("Frame", {
                                Size = Instance.Size,
                                Position = Instance.Position,
                                AnchorPoint = Instance.AnchorPoint,
                                BackgroundColor3 = Library.MainColor,
                                BackgroundTransparency = 0.5,
                                Active = false,
                                ZIndex = 100000,
                                Parent = ScreenGui
                            })
                         
                            local stroke = Library:Create("UIStroke", {
                                Color = Library.AccentColor,
                                Thickness = 1,
                                ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                                Parent = Wireframe
                            })
                        end
                        
                        if HasMoved and Wireframe then
                            Wireframe.Position = UDim2.new(
                                StartPos.X.Scale, StartPos.X.Offset + Delta.X,
                                StartPos.Y.Scale, StartPos.Y.Offset + Delta.Y
                            )
                        end
                    else
                        Instance.Position = UDim2.new(
                            StartPos.X.Scale, StartPos.X.Offset + Delta.X,
                            StartPos.Y.Scale, StartPos.Y.Offset + Delta.Y
                        )
                    end
                end
            end)

            EndedConn = InputService.InputEnded:Connect(function(EndInput)
                if EndInput == Input or EndInput.UserInputType == Enum.UserInputType.Touch then
                    Dragging = false
                    ChangedConn:Disconnect()
                    EndedConn:Disconnect()
                    
                    if IsWindow and Library.WireframeDrag and HasMoved and Wireframe then
                        Instance.Position = Wireframe.Position
                        
                        Wireframe:Destroy()
                        Wireframe = nil
                    end
                end
            end)
        end
    end)
end;

function Library:AddToolTip(InfoStr, HoverInstance)
    local X, Y = Library:GetTextBounds(InfoStr, Library.Font, Library.FontSize);
    local Tooltip = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor,

        Size = UDim2.fromOffset(X + 14, Y + 8),
        ZIndex = 100,
        Parent = Library.ScreenGui,

        Visible = false,
    })
    Library:Round(Tooltip, 5)
    Library:Stroke(Tooltip, 'OutlineColor')

    local Label = Library:CreateLabel({
        Position = UDim2.fromOffset(7, 4),
        Size = UDim2.fromOffset(X, Y);
        TextSize = Library.FontSize;
        Text = InfoStr,
        TextXAlignment = Enum.TextXAlignment.Left;
        ZIndex = Tooltip.ZIndex + 1,

        Parent = Tooltip;
    });
    Library:AddToRegistry(Tooltip, {
        BackgroundColor3 = 'MainColor';
    });
    local IsHovering = false

    HoverInstance.MouseEnter:Connect(function()
        if Library:MouseIsOverOpenedFrame() then
            return
        end

        IsHovering = true

        Tooltip.Position = UDim2.fromOffset(Mouse.X + 15, Mouse.Y + 12)
        Tooltip.Visible = true

        while IsHovering do
            RunService.Heartbeat:Wait()
            Tooltip.Position = UDim2.fromOffset(Mouse.X + 15, Mouse.Y + 12)
        end
    end)

    HoverInstance.MouseLeave:Connect(function()
        IsHovering = false
        Tooltip.Visible = false
    end)
end

function Library:OnHighlight(HighlightInstance, Instance, Properties, PropertiesDefault)
    HighlightInstance.MouseEnter:Connect(function()
        local Reg = Library.RegistryMap[Instance];

        for Property, ColorIdx in next, Properties do
            Instance[Property] = Library[ColorIdx] or ColorIdx;

            if Reg and Reg.Properties[Property] then
                Reg.Properties[Property] = ColorIdx;
            end;
        end;
    end)

    HighlightInstance.MouseLeave:Connect(function()
        local Reg = Library.RegistryMap[Instance];

        for Property, ColorIdx in next, PropertiesDefault do
            Instance[Property] = Library[ColorIdx] or ColorIdx;

            if Reg and Reg.Properties[Property] then
                Reg.Properties[Property] = ColorIdx;
            end;
        end;
    end)
end;

function Library:MouseIsOverOpenedFrame()
    for Frame, _ in next, Library.OpenedFrames do
        local AbsPos, AbsSize = Frame.AbsolutePosition, Frame.AbsoluteSize;
        if Mouse.X >= AbsPos.X and Mouse.X <= AbsPos.X + AbsSize.X
            and Mouse.Y >= AbsPos.Y and Mouse.Y <= AbsPos.Y + AbsSize.Y then

            return true;
        end;
    end;
end;

function Library:IsMouseOverFrame(Frame)
    local AbsPos, AbsSize = Frame.AbsolutePosition, Frame.AbsoluteSize;
    if Mouse.X >= AbsPos.X and Mouse.X <= AbsPos.X + AbsSize.X
        and Mouse.Y >= AbsPos.Y and Mouse.Y <= AbsPos.Y + AbsSize.Y then

        return true;
    end;
end;

function Library:UpdateDependencyBoxes()
    for _, Depbox in next, Library.DependencyBoxes do
        Depbox:Update();
    end;
end;

function Library:MapValue(Value, MinA, MaxA, MinB, MaxB)
    return (1 - ((Value - MinA) / (MaxA - MinA))) * MinB + ((Value - MinA) / (MaxA - MinA)) * MaxB;
end;

function Library:GetTextBounds(Text, Font, Size, Resolution)
    local Bounds = TextService:GetTextSize(Text, Size, Font, Resolution or Vector2.new(1920, 1080))
    return Bounds.X, Bounds.Y
end;

function Library:GetDarkerColor(Color)
    local H, S, V = Color3.toHSV(Color);
    return Color3.fromHSV(H, S, V / 1.5);
end;

local function fontScale(font)
    if font == Enum.Font.Code then return 0.9 end;
    if font == Enum.Font.RobotoMono then return 0.92 end;
    if font == Enum.Font.GothamBold then return 0.95 end;
    if font == Enum.Font.SciFi then return 0.84 end;
    if font == Enum.Font.Arcade then return 0.78 end;
    if font == Enum.Font.FredokaOne then return 0.86 end;
    if font == Enum.Font.Cartoon then return 0.88 end;
    return 1;
end;

Library.AccentColorDark = Library:GetDarkerColor(Library.AccentColor);

function Library:AddToRegistry(Instance, Properties, IsHud)
    local Idx = #Library.Registry + 1;
    local Data = {
        Instance = Instance;
        Properties = Properties;
        Idx = Idx;
    };

    table.insert(Library.Registry, Data);
    Library.RegistryMap[Instance] = Data;

    if IsHud then
        table.insert(Library.HudRegistry, Data);
    end;
end;

function Library:RemoveFromRegistry(Instance)
    local Data = Library.RegistryMap[Instance];

    if Data then
        for Idx = #Library.Registry, 1, -1 do
            if Library.Registry[Idx] == Data then
                table.remove(Library.Registry, Idx);
            end;
        end;

        for Idx = #Library.HudRegistry, 1, -1 do
            if Library.HudRegistry[Idx] == Data then
                table.remove(Library.HudRegistry, Idx);
            end;
        end;

        Library.RegistryMap[Instance] = nil;
    end;
end;

function Library:UpdateColorsUsingRegistry()
    Library.AccentColorDark = Library:GetDarkerColor(Library.AccentColor);
    for Idx, Object in next, Library.Registry do
        for Property, ColorIdx in next, Object.Properties do
            pcall(function()
                if type(ColorIdx) == 'string' then
                    Object.Instance[Property] = Library[ColorIdx];
                elseif type(ColorIdx) == 'function' then
                    Object.Instance[Property] = ColorIdx()
                end
            end);
        end;
    end;
    Library:UpdateGradients();
end;

function Library:GiveSignal(Signal)
    table.insert(Library.Signals, Signal)
end

Library.UnloadCallbacks = {};

function Library:Unload()
    if Library.Unloaded then
        return;
    end;
    Library.Unloaded = true;

    for Idx = #Library.Signals, 1, -1 do
        local Connection = table.remove(Library.Signals, Idx)
        if type(Connection) == 'function' then
            pcall(Connection)
        else
            pcall(function() Connection:Disconnect() end)
        end
    end

    for _, Callback in ipairs(Library.UnloadCallbacks) do
        pcall(Callback)
    end

    if Library.BlurEffect then
        pcall(function() Library.BlurEffect:Destroy() end)
    end

    if Library.DarkOverlay and Library.DarkOverlay.Parent then
        pcall(function() Library.DarkOverlay.Parent:Destroy() end)
    end

    if Library.MobileGui then
        pcall(function() Library.MobileGui:Destroy() end)
    end

    pcall(function() InputService.MouseIconEnabled = true end)
    ScreenGui:Destroy()
end

function Library:OnUnload(Callback)
    if type(Callback) == 'function' then
        table.insert(Library.UnloadCallbacks, Callback)
    end
end

Library:GiveSignal(ScreenGui.DescendantRemoving:Connect(function(Instance)
    if Library.Unloaded then
        return;
    end;
    if Library.RegistryMap[Instance] then
        Library:RemoveFromRegistry(Instance);
    end;
    if Library.GradientMap[Instance] then
        Library:RemoveGradient(Instance);
    end;
    Library.Glows[Instance] = nil;
end))

-- ---------------------------------------------------------------------------
-- Aster core: tween / shape helpers, animated gradients, icons, logo, search
-- ---------------------------------------------------------------------------
Library.Glows = {};
Library.Gradients = {};
Library.GradientMap = {};
Library.GradientTime = 0;
Library.SearchEntries = {};

function Library:Tween(Obj, Props, Time, Style, Dir)
    local Ok, Tw = pcall(function()
        local T = TweenService:Create(Obj, TweenInfo.new(Time or 0.15, Style or Enum.EasingStyle.Quad, Dir or Enum.EasingDirection.Out), Props);
        T:Play();
        return T;
    end);
    if Ok then return Tw end;
end;

function Library:Round(Obj, Radius)
    return Library:Create('UICorner', {
        CornerRadius = UDim.new(0, Radius or 6);
        Parent = Obj;
    });
end;

function Library:Stroke(Obj, ColorKey, Thickness, Transparency)
    local Stroke = Library:Create('UIStroke', {
        Color = Library[ColorKey or 'OutlineColor'];
        Thickness = Thickness or 1;
        Transparency = Transparency or 0;
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border;
        Parent = Obj;
    });
    Library:AddToRegistry(Stroke, { Color = ColorKey or 'OutlineColor' });
    return Stroke;
end;

function Library:GetDimColor()
    return Library.FontColor:Lerp(Library.MainColor, 0.45);
end;

function Library:GetSidebarColor()
    return Library.BackgroundColor:Lerp(Color3.new(0, 0, 0), 0.4);
end;

-- Hover feedback: stroke tweens to the accent, optional bg brighten
function Library:OnHover(Hit, Stroke, BgKey)
    Hit.MouseEnter:Connect(function()
        Library:Tween(Stroke, { Color = Library.AccentColor }, 0.12);
        if BgKey then
            Library:Tween(Hit, { BackgroundColor3 = Library[BgKey]:Lerp(Library.FontColor, 0.06) }, 0.12);
        end;
    end);
    Hit.MouseLeave:Connect(function()
        Library:Tween(Stroke, { Color = Library.OutlineColor }, 0.12);
        if BgKey then
            Library:Tween(Hit, { BackgroundColor3 = Library[BgKey] }, 0.12);
        end;
    end);
end;

-- Gradients -----------------------------------------------------------------
function Library:GradientSequence(Mode)
    local A, B = Library.AccentColor, Library.AccentColor2;
    if Mode == 'spin' then
        return ColorSequence.new({
            ColorSequenceKeypoint.new(0, A),
            ColorSequenceKeypoint.new(0.5, B),
            ColorSequenceKeypoint.new(1, A),
        });
    end;
    return ColorSequence.new(A, B);
end;

function Library:AddGradient(Gradient, Mode, Always, Axis)
    local Entry = {
        Gradient = Gradient;
        Mode = Mode or 'slide';
        Always = Always or false;
        Axis = Axis or 'X';
        BaseRotation = Gradient.Rotation;
        Phase = math.random();
    };
    Gradient.Color = Library:GradientSequence(Entry.Mode);
    table.insert(Library.Gradients, Entry);
    Library.GradientMap[Gradient] = Entry;
    return Gradient;
end;

function Library:RemoveGradient(Gradient)
    local Entry = Library.GradientMap[Gradient];
    if not Entry then return end;
    Library.GradientMap[Gradient] = nil;
    for Idx = #Library.Gradients, 1, -1 do
        if Library.Gradients[Idx] == Entry then
            table.remove(Library.Gradients, Idx);
            break
        end;
    end;
end;

function Library:UpdateGradients()
    for _, Entry in ipairs(Library.Gradients) do
        pcall(function()
            Entry.Gradient.Color = Library:GradientSequence(Entry.Mode);
        end);
    end;
end;

function Library:SetAccentGradient(C1, C2)
    if typeof(C1) == 'Color3' then
        Library.AccentColor = C1;
        Library.AccentColorDark = Library:GetDarkerColor(C1);
    end;
    if typeof(C2) == 'Color3' then
        Library.AccentColor2 = C2;
    end;
    Library:UpdateColorsUsingRegistry();
end;

function Library:SetAnimatedGradient(Bool)
    Library.AnimatedGradient = not not Bool;
end;

function Library:SetGradientSpeed(Speed)
    Library.GradientSpeed = tonumber(Speed) or Library.GradientSpeed;
end;

-- Icons ---------------------------------------------------------------------
-- Lucide 48px spritesheets (latte-soft/lucide-roblox): { sheet asset id, rect x, rect y }
Library.IconSize = 48;
Library.IconData = {
    ['crosshair'] = { 16898613044, 453, 869 };
    ['zap'] = { 16898613869, 918, 906 };
    ['eye'] = { 16898613353, 771, 563 };
    ['globe'] = { 16898613509, 771, 563 };
    ['shapes'] = { 16898613777, 257, 771 };
    ['box'] = { 16898612819, 771, 196 };
    ['layers'] = { 16898613509, 98, 967 };
    ['settings'] = { 16898613777, 771, 257 };
    ['users'] = { 16898613869, 967, 98 };
    ['shield'] = { 16898613777, 869, 0 };
    ['sword'] = { 16898613777, 710, 967 };
    ['swords'] = { 16898613777, 967, 759 };
    ['target'] = { 16898613869, 514, 771 };
    ['wand'] = { 16898613869, 404, 967 };
    ['user'] = { 16898613869, 661, 869 };
    ['palette'] = { 16898613613, 453, 918 };
    ['save'] = { 16898613699, 918, 453 };
    ['search'] = { 16898613699, 918, 857 };
    ['keyboard'] = { 16898613509, 453, 820 };
    ['bell'] = { 16898612819, 820, 257 };
    ['skull'] = { 16898613777, 49, 869 };
    ['sparkles'] = { 16898613777, 918, 49 };
    ['home'] = { 16898613509, 820, 147 };
    ['map'] = { 16898613613, 306, 771 };
    ['flame'] = { 16898613353, 967, 306 };
    ['camera'] = { 16898612819, 967, 563 };
    ['mouse-pointer'] = { 16898613613, 612, 869 };
    ['folder'] = { 16898613353, 404, 967 };
    ['chevron-down'] = { 16898612819, 196, 918 };
    ['x'] = { 16898613869, 869, 906 };
    ['wand-sparkles'] = { 16898613869, 453, 918 };
    ['radar'] = { 16898613699, 820, 404 };
    ['scan'] = { 16898613699, 967, 196 };
    ['rocket'] = { 16898613699, 918, 147 };
    ['user-round'] = { 16898613869, 967, 563 };
    ['settings-2'] = { 16898613777, 0, 771 };
    ['sliders-horizontal'] = { 16898613777, 820, 355 };
    ['paintbrush'] = { 16898613613, 918, 453 };
    ['lock'] = { 16898613509, 918, 857 };
    ['crown'] = { 16898613044, 404, 918 };
    ['bug'] = { 16898612819, 257, 967 };
    ['cpu'] = { 16898613044, 196, 869 };
    ['gamepad-2'] = { 16898613353, 710, 967 };
    ['list'] = { 16898613509, 869, 808 };
    ['monitor'] = { 16898613613, 404, 820 };
    ['activity'] = { 16898612629, 514, 771 };
    ['star'] = { 16898613777, 967, 147 };
    ['heart'] = { 16898613509, 661, 771 };
    ['flag'] = { 16898613353, 98, 918 };
    ['music'] = { 16898613613, 967, 563 };
    ['wifi'] = { 16898613869, 869, 808 };
    ['ghost'] = { 16898613353, 869, 906 };
    ['bot'] = { 16898612819, 869, 98 };
    ['compass'] = { 16898613044, 514, 967 };
    ['gauge'] = { 16898613353, 771, 955 };
    ['sun'] = { 16898613777, 967, 453 };
    ['moon'] = { 16898613613, 306, 918 };
    ['brush'] = { 16898612819, 404, 820 };
    ['package'] = { 16898613613, 918, 196 };
    ['check'] = { 16898612819, 710, 869 };
    ['info'] = { 16898613509, 612, 869 };
    ['bookmark'] = { 16898612819, 514, 918 };
    ['link'] = { 16898613509, 918, 453 };
    ['download'] = { 16898613044, 820, 906 };
    ['upload'] = { 16898613869, 612, 869 };
    ['trash-2'] = { 16898613869, 257, 918 };
    ['refresh-cw'] = { 16898613699, 404, 869 };
    ['circle-user'] = { 16898613044, 869, 257 };
    ['move'] = { 16898613613, 453, 820 };
    ['mouse'] = { 16898613613, 563, 918 };
};
Library.IconAliases = {
    skull = 'skull'; rage = 'zap'; aim = 'crosshair'; aimbot = 'crosshair'; ragebot = 'zap';
    esp = 'eye'; visuals = 'eye'; world = 'globe'; misc = 'shapes'; player = 'user'; players = 'users';
    config = 'settings'; configs = 'settings'; ui = 'settings'; cog = 'settings'; gear = 'settings';
};

function Library:RegisterIcon(Name, SheetId, X, Y, Size)
    Library.IconData[Name:lower()] = { SheetId, X, Y, Size };
end;

-- Returns { Image, ImageRectOffset, ImageRectSize } or nil
function Library:GetIcon(Name)
    if type(Name) == 'table' then
        if Name.Image then
            return {
                Image = Name.Image;
                ImageRectOffset = Name.ImageRectOffset or Vector2.new(0, 0);
                ImageRectSize = Name.ImageRectSize or Vector2.new(0, 0);
            };
        end;
        return nil;
    end;
    if type(Name) == 'number' then
        Name = 'rbxassetid://' .. tostring(Name);
    end;
    if type(Name) ~= 'string' or Name == '' then
        return nil;
    end;
    if Name:find('rbxasset', 1, true) or Name:find('http', 1, true) == 1 then
        return { Image = Name; ImageRectOffset = Vector2.new(0, 0); ImageRectSize = Vector2.new(0, 0) };
    end;
    local Key = Name:lower();
    local Data = Library.IconData[Key] or Library.IconData[Library.IconAliases[Key] or ''];
    if not Data then
        return nil;
    end;
    local Size = Data[4] or Library.IconSize;
    return {
        Image = 'rbxassetid://' .. tostring(Data[1]);
        ImageRectOffset = Vector2.new(Data[2], Data[3]);
        ImageRectSize = Vector2.new(Size, Size);
    };
end;

function Library:ApplyIcon(ImageObj, Name)
    local Icon = Library:GetIcon(Name);
    if not Icon then
        return false;
    end;
    ImageObj.Image = Icon.Image;
    ImageObj.ImageRectOffset = Icon.ImageRectOffset;
    ImageObj.ImageRectSize = Icon.ImageRectSize;
    return true;
end;

-- Tab icon: image if the icon resolves, otherwise a text glyph. Returns instance, colour property
function Library:CreateTabIcon(Parent, Icon, Name, ZIndex)
    local Image = Library:Create('ImageLabel', {
        AnchorPoint = Vector2.new(0.5, 0.5);
        BackgroundTransparency = 1;
        Position = UDim2.new(0.5, 0, 0.5, 0);
        Size = UDim2.fromOffset(20, 20);
        ZIndex = ZIndex;
        Parent = Parent;
    });
    if Library:ApplyIcon(Image, Icon or Name) then
        return Image, 'ImageColor3';
    end;
    Image:Destroy();
    local Glyph = Library:Create('TextLabel', {
        AnchorPoint = Vector2.new(0.5, 0.5);
        BackgroundTransparency = 1;
        Font = Enum.Font.GothamBold;
        Position = UDim2.new(0.5, 0, 0.5, 0);
        Size = UDim2.fromOffset(24, 24);
        Text = string.upper(string.sub(tostring(Name or '?'), 1, 1));
        TextSize = 16;
        ZIndex = ZIndex;
        Parent = Parent;
    });
    return Glyph, 'TextColor3';
end;

-- Logo ----------------------------------------------------------------------
Library.LogoImage = nil;

local function B64Decode(Data)
    local Chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    local Map = {};
    for Idx = 1, 64 do
        Map[string.byte(Chars, Idx)] = Idx - 1;
    end;
    local Out, Count, Bits, BitCount = {}, 0, 0, 0;
    for Idx = 1, #Data do
        local V = Map[string.byte(Data, Idx)];
        if V then
            Bits = Bits * 64 + V;
            BitCount = BitCount + 6;
            if BitCount >= 8 then
                BitCount = BitCount - 8;
                local Div = 2 ^ BitCount;
                local Byte = math.floor(Bits / Div);
                Bits = Bits - Byte * Div;
                Count = Count + 1;
                Out[Count] = string.char(Byte);
            end;
        end;
    end;
    return table.concat(Out);
end;

pcall(function()
    if type(writefile) ~= 'function' or type(getcustomasset) ~= 'function' then
        return;
    end;
    pcall(function()
        if type(makefolder) == 'function' and not (type(isfolder) == 'function' and isfolder('Aster')) then
            makefolder('Aster');
        end;
    end);
    local Path = 'Aster/aster_logo.png';
    local Bytes = B64Decode('iVBORw0KGgoAAAANSUhEUgAAAIAAAACACAQAAABpN6lAAAAN20lEQVR42u2df2wd1ZXHP/fO2GkdhzqJ7SSOYzuhEiQbWkD8AWKhW5VuoWqjXaGt+KeiWkUbqi5SUf9oK61EpO0f+0+VSqhSu9quQKxQf4jVKkVIFa2ISFshoVKiAKlYqH/EPxI7hJA4gdgz8+0fc9945r1nv5l5z3kp9lhIL49775zzveece+45595nRJsfQ1tJsO3mnzbPgG3r3EMX3e7TGgXgZm5vLxXtBmCEve2VAL/NAOxmR3ttgN/e1zPErrVrBAEGGQSitQlABAywHYjaZwVsGy1AhKGPLWxauyrQwxa66G/nOtBOCYB+bsCwc+0CsBMPGFq7AAy5pXDN2oBhgPZ6Avaaznn120YSGJSh6RoqhH+NYLaIMMNmlAj/TiBMxQUiwMMQXQsHya76+D4QERDSzZ5kbmMvYCcA2+nOyMkeugkJiAB/tSm0qyjwHpaIANjPo/yCt/guSslcD/2A2EJfsg74iO/yFr/gUfYDAREWbxWVQqvxZ+S5T7fosF5VqPj5upAvhKzQTYokhZLuFq6HL/R11zrUqzqsW9xInsxq0OqviqkLCdnAP3CQz+IBEBDSyXxmEdzl9NyyK+MJzCMW8PC5jdv4N17kv/g/rgIeUatDaK0GwCMk5Ab+mX9hr2PdYvABk/L6jVsDotRyWHk2YfDwESLC5z7u4xT/yX9z0b3hOrUBBo8Qn0O8xhH2EhIi/NSy9jd1vICl5ZCqVgaLjwgJ2csRXuMQPmGLLULLtCnW4c/pFUnSYqL3FX2+qlBvqUNGxun605IWFUh63vU3MurQW651tv+iJOkVfS71thb8tYp9X6hXP5EkBRniIy0qcp8v6g5nAK3QsaTtCWc6rdAdulinZwxCIEn6iXoTY3pdABATfr/GJIUZ5iskS6d0RA9omzpcD2T1/5JCRZKm1eW+RR3apgd0RKdcz6BqxFDSmO4Xsq1YF1ol+o87wa9lflY/0meq5ssI9ep9SZEiSQsadlKRlqnP6EearQNC/JbHW6MKrWB/s45WzX3kiHxT31RfwtDSSm6F9rmW8X93ppgx8hLA+vRNvenYjqrk4Kg2Nw9B8+zv0UlJC6kZimd+VIfU6VpVOzGe0N87Jyhu/081Wm3kOeY6dUijqZHjZ0HSSe1pFoJmDd8+TVeJ/qKkK/qeelwbs0zPg0m/RUnfWsasGfdtj76nK3XeNK19zRnE5mZ/n2YyRMWieUyfauC8+kL/ngHgiRXYqDjWn9KxKlVblDSjfc1IQfPsB1Wif3iFmU8D8HQCQCDpaAMmKpJwuEoVgmYhKMe+FRrRdIaURUln3PJkc/Q/lvQOJb3q3KCVe8XL7ZmM1AWSpjVSs4qsIgBWVj16I0PGoqQT2pNLH9NeQGUlSHsCjezOHp2oefcb6skBfEsAiIXxuRoSXtQNOc1R2guoALCgoZxz6AvdoBdr3v9cQ8VrEQC+c3sWqtjvyq2HWS+g4gzdkVuIPaGuKggWnGvkrzYAntB9GbckSNi3BcZY8gIqY/xjAfJtAkGQcb3uK24MbcHNs+jhKZRscUM8XufLXMHmDmFWMgJRaktaLDsQYbnCl3k9iQ4YLOIpeoryZAvu+COOMEDo+kVY5jjAPF7BCO5wzTcjBTPLHvMcYC4B3hIywJHCmeaC4n9vXbHzC1uRZ2qM2P8WFl+/rjreW2ycYpteXydSAAQlDY8R+m2NO/NKDk9gOYOcpuiE/CIb5WLzf7DqZb8vsfTE8aA/Z4xgJOm0NuTyBGqX5N9XUXWwiAzkf5XRRk0pSpyXUB9obwkX1Aj161KyCFYA+FCDhQGI375XH7jAShxgmdLG/LJkc0d7xUEGiFyPEMv3OYVfOEZranJBsSnawPYSafIQn1N8H+vosEQMcBC5cHyLjKCRUafeTuY/xnlTqaCUJ/RA1d6+uCeQtU2bUrIZKtLb6swrAzb3/B/gxmT+heFxLpUqdDZ18sHxv4ZLhrUNl3g8ocUScSMH8sqAzbnqwjdS2VvLOzxZwPVp7AVUssTlqs0sT/JOih7xDXIW39lcbSJu5p6ktTA8QYAtnaYaWRYWlZIBS8ATKRmAe7g5kdcWAAAP4RFiAOHxHk9hSqaoQlcTYmoUYxdlSyZDDE/xHh4CDCEeD+XjzubQ2RB4MGkbAj/nQsn5NwifgboA7KADlUp7CcsFfu6oiyl90AHTAgDEXvYmpFng6aayc+l6gDQAffQ2lZl8OuGnmuamALDA5xMFiLC8zcuopLDW9wLiWewq5QlUDKF4mbedIYyV4PN5+LM5xAvuISAkICBAPEeIX9IAmlRNUPU+EwZLAyB8Qp5DjsqQgHvyGFWbwwJ080V8NuDj04nhV5Q/6WOWtfYVT6Cscgn4FYZOfEftF+lubAX8HBagj//hJJfpZh9/x27+SHMF7sMl/k8+X+WPXGWUY7zJPBu5hT7mGzlrfo5hRzmUav9pzhWWAOP+4iKXkRUAsM5/SzZrhSTgHHdzgqCGg6ZLZJZaBfyhEMMQEaVYCZbV9NgTiLhaU2GYH5CQP1RR25hUUXguoxUZVh0H6RP0McAuRhhmiHv5+DKjf8BLTDDOGKeZZo736+xKzIqA2IJyUxiAfAxvoo8d7GKYEXazk21syb09XZrN85xlilHGGOc0M8xxqTAgLQKgCMNDDLKNLXTUWJMoKaVaiW1lRH/pWeQ8Z5lkorWA1AegEcMb6WUHg9y4AsNyNX2VkYoub0rYiIPeZgVA3mGSGc5xuTggFQCWWFadYsSY4V0MM8wwg2xjKxtazHCzgFzlXc4yyTjjTkJqAan0S8FRXwI+Ri+DbWa41YBMco4P60uA4WPsYDcjDDHETrazlR66rjOGmwXkChd4lzNMMcEEY4wyw4fId5rSxVYGGGGYfvroqfEPqhXjemM/ew+BiGog6KKTTnw6sQRc4mxsjOupQAdb2cGgU4Bd7KCXjcva67TBvNZzvmTY6q0tlznHDKedEkwyw7ssLmcE7QomcANb6WWQIUYcIH11DjsuLXOrbwTrLZNwiTnH8BgTTHKOd6v8yqwZjJaTAJNiox4gHWxhG4PsZJgRdjFAH59oOSCNGX6fOaY5zRjjTDHJWc7XzHDW7tfZw+RxhBoB4rGFfgYZYpgRdrKdfjbXMNysIyTeY5YzTDHGOBNMMsv5Gh+lIcOtcIXTgFDnaJNhM/0MOECGGKCfnsKF+REXmGXaeX4TTDPLezUMZTdLJeIUrdgM5QGkl+0FN0NnOFeC4VXaDBXaYDYE5Dh/S1ijCCEeL3NXC2a4ELX54gFBJiDyWoOMQDWhaUA8FplcNiR2GksHYYrhYmcHPW6tCYg0CYAlYjffyYTEhjlbKCuYBSRibNmW40SExRjIOEK9/C4TEvsPRhsm8HJk87t1OZPJvb+J2lxf6JGqouelMpl/baLw2RO6PzPiZXU3rjiwDWfPY57nCbhKQMAC4gtNxm7Hlw2JjTcZb/4CYoHAUfs88y5Z1lRewADH8fHw8fExfAmPoHT8HqaghrB4KiZLA2AI8PgSxlHp4XM8z0Q1BiACXiB0JFsiPsmddU6C5wfgTOoAZZqFK5wpDYDFcCefdBlh4RHyQp7wfZ7MkOEUpxKzFwFfber85nnmqFcgMce5pvYKX00Yrqa5SQA84NlkcA/4Cj0lr74RhoDpugDMsFjycj1DRA9fcdTFlD5bR9FKARAP99NECQwhm3m4QBlS9VoNp+sCcJqyJ1k9xMNsTlUwhPyUXPmrfABY/sTxZECDeBS/ieuPxpbxAsqtLoYIn0eTZHgEHOdP+Up4bE4TAz9MiIvLkL6WrwRlWVZrn6mSo1kivpYq4QLDD3Pztl4mlw8lj4VMGVLIAN8mKmEH6nkCMR2nKZN19oj4dqqCPS7hWshjAPNLwEe4VHa9WHq9XH6NH5gospCFeLzEk3huxx6f03mG3QSFjeE7TXsBHgG7eSZ1finA40leKnbLiC1owS2PMZ2cELJE9HGU7sQGl/cExgqu/SHdHKUvWf0jPKZ5rGgBZzGyIwwXeBiTBMc9QvbzS7oKuEUCJjLvNu6bIq5PF79kfxJbFBGGh7lQt4KlBcvg+sHJ9aOz64en14/Pr1+gsH6FxvolKuvX6KxfpLR+ldb6ZWrr1+l9pC5UbN2VmiEGj99wF48wiu+uVlWq0sPyAoupYOVYTb5YeCzygmtd2a2FhFh8RnmEu/gNXulDm01vhxttLEM8An7MrTzGKTw8DEGqruyNZWIC2VjAG6l6zwCDh8cpHuNWfkyAV3VD9XUEwJIcXOQH3MZD/JrQXaoaEKJUfb8c27ZOeOQSIiRwl6qG/JqHuI0fcLG1c1+kRqioHBgsV/kZP+MWHuQAn8bHh9SByTgXWFHBbK6wG8MGIOIER3mWk0n8P2w5tat0uXoFBHGSkxxmP5/lXu7m9gwAs1xgc51s8e3M8Dte4kVeT3L/q8J82ULJYipmk6KnbvoZTYqb4xz+TcAsN6bO9xl2M5uUUPirfcf8al+vH5MfX68/n6oMEZaIKW6qqRgRf2bpev1glem7Rr8vELkjzemApSVygdApshdm27rnlP6qAViKv9YLhVdnBK7p70619zdGxpM1oG1P+wBQkguYWLsATBE6ALQ2AZjlImKqnQC09/cGL3CeTmbXJgCxJzBHZ50TwGtEAiwR03ju05pUAZjErG0AJmqPMq4dAASM1q0cX0MAjJW4kuWvaju84rsRXdjGV918VAG4Lp72//p8mw/i/wXWC7y6RFgToAAAAABJRU5ErkJggg==');
    local Exists = false;
    pcall(function()
        Exists = type(isfile) == 'function' and isfile(Path) and type(readfile) == 'function' and #readfile(Path) == #Bytes;
    end);
    if not Exists then
        writefile(Path, Bytes);
    end;
    Library.LogoImage = getcustomasset(Path);
end);

-- Logo mark: gradient-tinted image, or a text 'A' glyph when the asset is unavailable
function Library:CreateLogo(Parent, Size, ZIndex, Always)
    local Holder = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Size = UDim2.fromOffset(Size, Size);
        ZIndex = ZIndex;
        Parent = Parent;
    });
    local Mark;
    if Library.LogoImage and Library.LogoImage ~= '' then
        Mark = Library:Create('ImageLabel', {
            BackgroundTransparency = 1;
            Image = Library.LogoImage;
            ImageColor3 = Color3.new(1, 1, 1);
            ScaleType = Enum.ScaleType.Fit;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = ZIndex;
            Parent = Holder;
        });
    else
        Mark = Library:Create('TextLabel', {
            BackgroundTransparency = 1;
            Font = Enum.Font.GothamBold;
            Size = UDim2.new(1, 0, 1, 0);
            Text = 'A';
            TextColor3 = Color3.new(1, 1, 1);
            TextSize = math.floor(Size * 0.9);
            ZIndex = ZIndex;
            Parent = Holder;
        });
    end;
    Library:AddGradient(Library:Create('UIGradient', { Rotation = 45; Parent = Mark }), 'slide', Always);
    return Holder;
end;

-- Search --------------------------------------------------------------------
function Library:AddSearchEntry(Root, Text, Frames)
    table.insert(Library.SearchEntries, { Root = Root; Text = Text or ''; Frames = Frames });
end;

function Library:ApplySearch(Query)
    Query = string.lower(tostring(Query or ''));
    Query = Query:gsub('^%s+', '');
    Query = Query:gsub('%s+$', '');
    local Filtering = Query ~= '';
    local Roots = {};

    for Idx = #Library.SearchEntries, 1, -1 do
        local Entry = Library.SearchEntries[Idx];
        local Alive = Entry.Frames[1] and Entry.Frames[1].Parent;
        if not Alive then
            table.remove(Library.SearchEntries, Idx);
        else
            local Root = Entry.Root;
            local Hit = (not Filtering)
                or string.find(string.lower(Entry.Text), Query, 1, true) ~= nil
                or (Root.Title ~= nil and string.find(string.lower(Root.Title), Query, 1, true) ~= nil);
            for _, Frame in ipairs(Entry.Frames) do
                Frame.Visible = Hit;
            end;
            if Hit and Entry.Text ~= '' then
                Root.SearchHit = true;
            end;
            Roots[Root] = true;
        end;
    end;

    for Root, _ in next, Roots do
        if Root.Outer then
            Root.Outer.Visible = (not Filtering) or Root.SearchHit == true or (Root.Title ~= nil and string.find(string.lower(Root.Title), Query, 1, true) ~= nil);
        end;
        Root.SearchHit = nil;
        if Root.Resize then
            Root:Resize();
        end;
    end;
end;

-- One shared connection drives every animated gradient, glow and the watermark stats
do
    local Accum, StatAccum, Frames = 0, 0, 0;
    local AtRest = false;

    local function ResetGradients()
        for _, Entry in ipairs(Library.Gradients) do
            pcall(function()
                Entry.Gradient.Offset = Vector2.new(0, 0);
                Entry.Gradient.Rotation = Entry.BaseRotation;
            end);
        end;
    end;

    local function UpdateStats(Elapsed)
        local Stats = Library.WatermarkStatLabels;
        if not Stats or not Library.Watermark or not Library.Watermark.Visible then
            return;
        end;
        Stats.Fps.Text = string.format('%d fps', math.floor(Frames / math.max(Elapsed, 0.001) + 0.5));
        local Ping = 0;
        pcall(function()
            Ping = game:GetService('Stats').Network.ServerStatsItem['Data Ping']:GetValue();
        end);
        Stats.Ping.Text = string.format('%d ms', math.floor(Ping + 0.5));
        Stats.Time.Text = os.date('%H:%M');
    end;

    Library:GiveSignal(RunService.RenderStepped:Connect(function(Dt)
        Library.GradientTime = Library.GradientTime + Dt * (Library.GradientSpeed or 0.35);
        Accum = Accum + Dt;
        StatAccum = StatAccum + Dt;
        Frames = Frames + 1;

        if StatAccum >= 1 then
            UpdateStats(StatAccum);
            StatAccum, Frames = 0, 0;
        end;

        if Accum < 1 / 30 then
            return;
        end;
        Accum = 0;

        if not Library.AnimatedGradient then
            if not AtRest then
                ResetGradients();
                AtRest = true;
            end;
            return;
        end;
        AtRest = false;

        local T = Library.GradientTime;
        local Toggled = Library.Toggled;
        local Wave = math.sin(T * math.pi * 2) * 0.5;
        for _, Entry in ipairs(Library.Gradients) do
            if Toggled or Entry.Always then
                local G = Entry.Gradient;
                if Entry.Mode == 'spin' then
                    G.Rotation = ((T * 360) + Entry.Phase * 360) % 360;
                elseif Entry.Mode == 'slide' then
                    local V = math.sin((T + Entry.Phase) * math.pi * 2) * 0.5;
                    G.Offset = Entry.Axis == 'Y' and Vector2.new(0, V) or Vector2.new(V, 0);
                end;
            end;
        end;

        if Toggled then
            local Pulse = 0.72 + Wave * 0.2;
            for Glow, _ in next, Library.Glows do
                Glow.ImageTransparency = Pulse;
            end;
        end;
    end));
end;

local BaseAddons = {};
do
    local Funcs = {};

    function Funcs:AddColorPicker(Idx, Info)
        local ToggleLabel = self.TextLabel;
        assert(Info.Default, 'AddColorPicker: Missing default value.');

        local ColorPicker = {
            Value = Info.Default;
            Transparency = Info.Transparency or 0;
            Type = 'ColorPicker';
            Title = type(Info.Title) == 'string' and Info.Title or 'Color picker',
            Callback = Info.Callback or function(Color) end;
        };

        function ColorPicker:SetHSVFromRGB(Color)
            local H, S, V = Color3.toHSV(Color);
            ColorPicker.Hue = H;
            ColorPicker.Sat = S;
            ColorPicker.Vib = V;
        end;

        ColorPicker:SetHSVFromRGB(ColorPicker.Value);
        local DisplayFrame = Library:Create('Frame', {
            BackgroundColor3 = ColorPicker.Value;
            Size = UDim2.new(0, 26, 0, 14);
            ZIndex = 6;
            Parent = ToggleLabel;
        });
        Library:Round(DisplayFrame, 4);
        Library:Create('UIStroke', {
            Color = Color3.new(1, 1, 1);
            Transparency = 0.85;
            Thickness = 1;
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border;
            Parent = DisplayFrame;
        });
        local CheckerFrame = Library:Create('ImageLabel', {
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 5;
            Image = 'http://www.roblox.com/asset/?id=12977615774';
            Visible = not not Info.Transparency;
            Parent = DisplayFrame;
        });
        Library:Round(CheckerFrame, 4);

        local PickerFrameOuter = Library:Create('Frame', {
            Name = 'Color';
            BackgroundTransparency = 1;
            Position = UDim2.fromOffset(math.max(4, DisplayFrame.AbsolutePosition.X + DisplayFrame.AbsoluteSize.X - 230), DisplayFrame.AbsolutePosition.Y + DisplayFrame.AbsoluteSize.Y + 6),
            Size = UDim2.fromOffset(230, Info.Transparency and 271 or 253);
            Visible = false;
            ZIndex = 15;
            Parent = ScreenGui,
        });
        DisplayFrame:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
            PickerFrameOuter.Position = UDim2.fromOffset(math.max(4, DisplayFrame.AbsolutePosition.X + DisplayFrame.AbsoluteSize.X - 230), DisplayFrame.AbsolutePosition.Y + DisplayFrame.AbsoluteSize.Y + 6);
        end)

        local PickerFrameInner = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 16;
            Parent = PickerFrameOuter;
        });
        Library:Round(PickerFrameInner, 6);
        Library:Stroke(PickerFrameInner, 'OutlineColor');
        local Highlight = Library:Create('Frame', {
            BackgroundColor3 = Library.AccentColor;
            BorderSizePixel = 0;
            Position = UDim2.new(0, 8, 0, 0);
            Size = UDim2.new(1, -16, 0, 2);
            ZIndex = 17;
            Parent = PickerFrameInner;
        });
        local SatVibMapOuter = Library:Create('Frame', {
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.new(0, 4, 0, 25);
            Size = UDim2.new(0, 200, 0, 200);
            ZIndex = 17;
            Parent = PickerFrameInner;
        });
        local SatVibMapInner = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 18;
            Parent = SatVibMapOuter;
        });
        local SatVibMap = Library:Create('ImageLabel', {
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 18;
            Image = 'rbxassetid://4155801252';
            Parent = SatVibMapInner;
        });
        local CursorOuter = Library:Create('ImageLabel', {
            AnchorPoint = Vector2.new(0.5, 0.5);
            Size = UDim2.new(0, 6, 0, 6);
            BackgroundTransparency = 1;
            Image = 'http://www.roblox.com/asset/?id=9619665977';
            ImageColor3 = Color3.new(0, 0, 0);
            ZIndex = 19;
            Parent = SatVibMap;
        });
        local CursorInner = Library:Create('ImageLabel', {
            Size = UDim2.new(0, CursorOuter.Size.X.Offset - 2, 0, CursorOuter.Size.Y.Offset - 2);
            Position = UDim2.new(0, 1, 0, 1);
            BackgroundTransparency = 1;
            Image = 'http://www.roblox.com/asset/?id=9619665977';
            ZIndex = 20;
            Parent = CursorOuter;
        })

        local HueSelectorOuter = Library:Create('Frame', {
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.new(0, 208, 0, 25);
            Size = UDim2.new(0, 15, 0, 200);
            ZIndex = 17;
            Parent = PickerFrameInner;
        });

        local HueSelectorInner = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(1, 1, 1);
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 18;
            Parent = HueSelectorOuter;
        });
        local HueCursor = Library:Create('Frame', { 
            BackgroundColor3 = Color3.new(1, 1, 1);
            AnchorPoint = Vector2.new(0, 0.5);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(1, 0, 0, 1);
            ZIndex = 18;
            Parent = HueSelectorInner;
        });

        local HueBoxOuter = Library:Create('Frame', {
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.fromOffset(4, 228),
            Size = UDim2.new(0.5, -6, 0, 20),
            ZIndex = 18,
            Parent = PickerFrameInner;
        });
        local HueBoxInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 18,
            Parent = HueBoxOuter;
        });
        Library:Create('UIGradient', {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212))
            });
            Rotation = 90;
            Parent = HueBoxInner;
        });

        local HueBox = Library:Create('TextBox', {
            BackgroundTransparency = 1;
            Position = UDim2.new(0, 5, 0, 0);
            Size = UDim2.new(1, -5, 1, 0);
            Font = Library.Font;
            PlaceholderColor3 = Color3.fromRGB(190, 190, 190);
            PlaceholderText = 'Hex color',
            Text = '#FFFFFF',
            TextColor3 = Library.FontColor;
            TextSize = Library.FontSize;
            TextStrokeTransparency = 0;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 20,
            Parent = HueBoxInner;
        });

        Library:ApplyTextStroke(HueBox);

        local RgbBoxBase = Library:Create(HueBoxOuter:Clone(), {
            Position = UDim2.new(0.5, 2, 0, 228),
            Size = UDim2.new(0.5, -6, 0, 20),
            Parent = PickerFrameInner
        });
        local RgbBox = Library:Create(RgbBoxBase.Frame:FindFirstChild('TextBox'), {
            Text = '255, 255, 255',
            PlaceholderText = 'RGB color',
            TextColor3 = Library.FontColor
        });
        local TransparencyBoxOuter, TransparencyBoxInner, TransparencyCursor;
        
        if Info.Transparency then 
            TransparencyBoxOuter = Library:Create('Frame', {
                BorderColor3 = Color3.new(0, 0, 0);
                Position = UDim2.fromOffset(4, 251);
                Size = UDim2.new(1, -8, 0, 15);
                ZIndex = 19;
                Parent = PickerFrameInner;
            });
            TransparencyBoxInner = Library:Create('Frame', {
                BackgroundColor3 = ColorPicker.Value;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, 0, 1, 0);
                ZIndex = 19;
                Parent = TransparencyBoxOuter;
            });
            Library:AddToRegistry(TransparencyBoxInner, { BorderColor3 = 'OutlineColor' });

            Library:Create('ImageLabel', {
                BackgroundTransparency = 1;
                Size = UDim2.new(1, 0, 1, 0);
                Image = 'http://www.roblox.com/asset/?id=12978095818';
                ZIndex = 20;
                Parent = TransparencyBoxInner;
            });
            TransparencyCursor = Library:Create('Frame', { 
                BackgroundColor3 = Color3.new(1, 1, 1);
                AnchorPoint = Vector2.new(0.5, 0);
                BorderColor3 = Color3.new(0, 0, 0);
                Size = UDim2.new(0, 1, 1, 0);
                ZIndex = 21;
                Parent = TransparencyBoxInner;
            });
        end;

        local DisplayLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 0, 14);
            Position = UDim2.fromOffset(5, 5);
            TextXAlignment = Enum.TextXAlignment.Left;
            TextSize = Library.FontSize;
            Text = ColorPicker.Title,
            TextWrapped = false;
            ZIndex = 16;
            Parent = PickerFrameInner;
        });
        local ContextMenu = {}
        do
            ContextMenu.Options = {}
            ContextMenu.Container = Library:Create('Frame', {
                BorderColor3 = Color3.new(),
                ZIndex = 14,
                Visible = false,
                Parent = ScreenGui
            })

            ContextMenu.Inner = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.fromScale(1, 1);
                ZIndex = 15;
                Parent = ContextMenu.Container;
            });
            Library:Create('UIListLayout', {
                Name = 'Layout',
                FillDirection = Enum.FillDirection.Vertical;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = ContextMenu.Inner;
            });
            Library:Create('UIPadding', {
                Name = 'Padding',
                PaddingLeft = UDim.new(0, 4),
                Parent = ContextMenu.Inner,
            });
            local function updateMenuPosition()
                ContextMenu.Container.Position = UDim2.fromOffset(
                    (DisplayFrame.AbsolutePosition.X + DisplayFrame.AbsoluteSize.X) + 4,
                    DisplayFrame.AbsolutePosition.Y + 1
                )
            end

            local function updateMenuSize()
                local menuWidth = 60
                for i, label in next, ContextMenu.Inner:GetChildren() do
                    if label:IsA('TextLabel') then
                        menuWidth = math.max(menuWidth, label.TextBounds.X)
                    end
                end

                ContextMenu.Container.Size = UDim2.fromOffset(
                    menuWidth + 8,
                    ContextMenu.Inner.Layout.AbsoluteContentSize.Y + 4
                )
            end

            DisplayFrame:GetPropertyChangedSignal('AbsolutePosition'):Connect(updateMenuPosition)
            ContextMenu.Inner.Layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(updateMenuSize)

            task.spawn(updateMenuPosition)
            task.spawn(updateMenuSize)

            Library:AddToRegistry(ContextMenu.Inner, {
                BackgroundColor3 = 'BackgroundColor';
                BorderColor3 = 'OutlineColor';
            });

            function ContextMenu:Show()
                self.Container.Visible = true
            end

            function ContextMenu:Hide()
                self.Container.Visible = false
            end

            function ContextMenu:AddOption(Str, Callback)
                if type(Callback) ~= 'function' then
                    Callback = function() end
                end

                local Button = Library:CreateLabel({
                    Active = false;
                    Size = UDim2.new(1, 0, 0, 15);
                    TextSize = Library.FontSize - 1;
                    Text = Str;
                    ZIndex = 16;
                    Parent = self.Inner;
                    TextXAlignment = Enum.TextXAlignment.Left,
                });
                Library:OnHighlight(Button, Button, 
                    { TextColor3 = 'AccentColor' },
                    { TextColor3 = 'FontColor' }
                );
                Button.InputBegan:Connect(function(Input)
                    if Input.UserInputType ~= Enum.UserInputType.MouseButton1 and Input.UserInputType ~= Enum.UserInputType.Touch then
                        return
                    end

                    Callback()
                end)
            end

            ContextMenu:AddOption('Copy color', function()
                Library.ColorClipboard = ColorPicker.Value
                Library:Notify('Copied color!', 2)
            end)

            ContextMenu:AddOption('Paste color', function()
                if not Library.ColorClipboard then
                    return Library:Notify('You have not copied a color!', 2)
                end
                ColorPicker:SetValueRGB(Library.ColorClipboard)
            end)


            ContextMenu:AddOption('Copy HEX', function()
                pcall(setclipboard, ColorPicker.Value:ToHex())
                Library:Notify('Copied hex code to clipboard!', 2)
            end)

            ContextMenu:AddOption('Copy RGB', function()
                pcall(setclipboard, table.concat({ math.floor(ColorPicker.Value.R * 255), math.floor(ColorPicker.Value.G * 255), math.floor(ColorPicker.Value.B * 255) }, ', '))
                Library:Notify('Copied RGB values to clipboard!', 2)
            end)

        end

        Library:AddToRegistry(PickerFrameInner, { BackgroundColor3 = 'BackgroundColor'; });
        Library:AddToRegistry(Highlight, { BackgroundColor3 = 'AccentColor'; });
        Library:AddToRegistry(SatVibMapInner, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor'; });
        Library:AddToRegistry(HueBoxInner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });
        Library:AddToRegistry(RgbBoxBase.Frame, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });
        Library:AddToRegistry(RgbBox, { TextColor3 = 'FontColor', });
        Library:AddToRegistry(HueBox, { TextColor3 = 'FontColor', });

        local SequenceTable = {};
        for Hue = 0, 1, 0.1 do
            table.insert(SequenceTable, ColorSequenceKeypoint.new(Hue, Color3.fromHSV(Hue, 1, 1)));
        end;

        local HueSelectorGradient = Library:Create('UIGradient', {
            Color = ColorSequence.new(SequenceTable);
            Rotation = 90;
            Parent = HueSelectorInner;
        });
        HueBox.FocusLost:Connect(function(enter)
            if enter then
                local success, result = pcall(Color3.fromHex, HueBox.Text)
                if success and typeof(result) == 'Color3' then
                    ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = Color3.toHSV(result)
                end
            end

            ColorPicker:Display()
        end)

        RgbBox.FocusLost:Connect(function(enter)
            if enter then
                local r, g, b = RgbBox.Text:match('(%d+),%s*(%d+),%s*(%d+)')
                if r and g and b then
                    ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = Color3.toHSV(Color3.fromRGB(r, g, b))
                end
            end

            ColorPicker:Display()
        end)

        function ColorPicker:Display()
            ColorPicker.Value = Color3.fromHSV(ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib);
            SatVibMap.BackgroundColor3 = Color3.fromHSV(ColorPicker.Hue, 1, 1);

            Library:Create(DisplayFrame, {
                BackgroundColor3 = ColorPicker.Value;
                BackgroundTransparency = ColorPicker.Transparency;
                BorderColor3 = Library:GetDarkerColor(ColorPicker.Value);
            });
            if TransparencyBoxInner then
                TransparencyBoxInner.BackgroundColor3 = ColorPicker.Value;
                TransparencyCursor.Position = UDim2.new(1 - ColorPicker.Transparency, 0, 0, 0);
            end;

            CursorOuter.Position = UDim2.new(ColorPicker.Sat, 0, 1 - ColorPicker.Vib, 0);
            HueCursor.Position = UDim2.new(0, 0, ColorPicker.Hue, 0);

            HueBox.Text = '#' .. ColorPicker.Value:ToHex()
            RgbBox.Text = table.concat({ math.floor(ColorPicker.Value.R * 255), math.floor(ColorPicker.Value.G * 255), math.floor(ColorPicker.Value.B * 255) }, ', ')

            Library:SafeCallback(ColorPicker.Callback, ColorPicker.Value);
            Library:SafeCallback(ColorPicker.Changed, ColorPicker.Value);
        end;

        function ColorPicker:OnChanged(Func)
            ColorPicker.Changed = Func;
            Func(ColorPicker.Value)
        end;

        function ColorPicker:Show()
            for Frame, Val in next, Library.OpenedFrames do
                if Frame.Name == 'Color' then
                    Frame.Visible = false;
                    Library.OpenedFrames[Frame] = nil;
                end;
            end;

            PickerFrameOuter.Visible = true;
            Library.OpenedFrames[PickerFrameOuter] = true;
        end;
        function ColorPicker:Hide()
            PickerFrameOuter.Visible = false;
            Library.OpenedFrames[PickerFrameOuter] = nil;
        end;
        function ColorPicker:SetValue(HSV, Transparency)
            local Color = Color3.fromHSV(HSV[1], HSV[2], HSV[3]);
            ColorPicker.Transparency = Transparency or 0;
            ColorPicker:SetHSVFromRGB(Color);
            ColorPicker:Display();
        end;

        function ColorPicker:SetValueRGB(Color, Transparency)
            ColorPicker.Transparency = Transparency or 0;
            ColorPicker:SetHSVFromRGB(Color);
            ColorPicker:Display();
        end;

        SatVibMap.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                local function UpdateColor(PosX, PosY)
                    local MinX = SatVibMap.AbsolutePosition.X;
                    local MaxX = MinX + SatVibMap.AbsoluteSize.X;
                    local MouseX = math.clamp(PosX, MinX, MaxX);

                    local MinY = SatVibMap.AbsolutePosition.Y;
                    local MaxY = MinY + SatVibMap.AbsoluteSize.Y;
                    local MouseY = math.clamp(PosY, MinY, MaxY);

                    ColorPicker.Sat = (MouseX - MinX) / (MaxX - MinX);
                    ColorPicker.Vib = 1 - ((MouseY - MinY) / (MaxY - MinY));
                    ColorPicker:Display();
                end

                UpdateColor(Input.Position.X, Input.Position.Y)

                local ChangedConn = InputService.InputChanged:Connect(function(Change)
                    if Change.UserInputType == Enum.UserInputType.MouseMovement or Change == Input then
                        UpdateColor(Change.Position.X, Change.Position.Y)
                    end
                end)

                local EndedConn
                EndedConn = InputService.InputEnded:Connect(function(EndInput)
                    if EndInput == Input or EndInput.UserInputType == Enum.UserInputType.Touch then
                        ChangedConn:Disconnect()
                        EndedConn:Disconnect()
                        Library:AttemptSave()
                    end
                end)
            end
        end);
        HueSelectorInner.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                local function UpdateHue(PosY)
                    local MinY = HueSelectorInner.AbsolutePosition.Y;
                    local MaxY = MinY + HueSelectorInner.AbsoluteSize.Y;
                    local MouseY = math.clamp(PosY, MinY, MaxY);

                    ColorPicker.Hue = ((MouseY - MinY) / (MaxY - MinY));
                    ColorPicker:Display();
                end

                UpdateHue(Input.Position.Y)

                local ChangedConn = InputService.InputChanged:Connect(function(Change)
                    if Change.UserInputType == Enum.UserInputType.MouseMovement or Change == Input then
                        UpdateHue(Change.Position.Y)
                    end
                end)

                local EndedConn
                EndedConn = InputService.InputEnded:Connect(function(EndInput)
                    if EndInput == Input or EndInput.UserInputType == Enum.UserInputType.Touch then
                        ChangedConn:Disconnect()
                        EndedConn:Disconnect()
                        Library:AttemptSave()
                    end
                end)
            end
        end);
        DisplayFrame.InputBegan:Connect(function(Input)
            if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) and not Library:MouseIsOverOpenedFrame() then
                if PickerFrameOuter.Visible then
                    ColorPicker:Hide()
                else
                    ContextMenu:Hide()
                    ColorPicker:Show()
                end;
            elseif Input.UserInputType == Enum.UserInputType.MouseButton2 and not Library:MouseIsOverOpenedFrame() then
                ContextMenu:Show()
                ColorPicker:Hide()
            end
        end);

        if TransparencyBoxInner then
            TransparencyBoxInner.InputBegan:Connect(function(Input)
                if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                    local function UpdateAlpha(PosX)
                        local MinX = TransparencyBoxInner.AbsolutePosition.X;
                        local MaxX = MinX + TransparencyBoxInner.AbsoluteSize.X;
                        local MouseX = math.clamp(PosX, MinX, MaxX);

                        ColorPicker.Transparency = 1 - ((MouseX - MinX) / (MaxX - MinX));
                        ColorPicker:Display();
                    end

                    UpdateAlpha(Input.Position.X)

                    local ChangedConn = InputService.InputChanged:Connect(function(Change)
                        if Change.UserInputType == Enum.UserInputType.MouseMovement or Change == Input then
                            UpdateAlpha(Change.Position.X)
                        end
                    end)

                    local EndedConn
                    EndedConn = InputService.InputEnded:Connect(function(EndInput)
                        if EndInput == Input or EndInput.UserInputType == Enum.UserInputType.Touch then
                            ChangedConn:Disconnect()
                            EndedConn:Disconnect()
                            Library:AttemptSave()
                        end
                    end)
                end
            end);
        end;

        Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
            if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) then
                local AbsPos, AbsSize = PickerFrameOuter.AbsolutePosition, PickerFrameOuter.AbsoluteSize;
                local DFPos = DisplayFrame.AbsolutePosition;
                local DFSize = DisplayFrame.AbsoluteSize;

                if Mouse.X < AbsPos.X or Mouse.X > AbsPos.X + AbsSize.X
                    or Mouse.Y < DFPos.Y or Mouse.Y > AbsPos.Y + AbsSize.Y then

                    if not (Mouse.X >= DFPos.X and Mouse.X <= DFPos.X + DFSize.X
                        and Mouse.Y >= DFPos.Y and Mouse.Y <= DFPos.Y + DFSize.Y) then
                        ColorPicker:Hide();
                    end
                end;

                if not Library:IsMouseOverFrame(ContextMenu.Container) then
                    ContextMenu:Hide()
                end
            end;

            if Input.UserInputType == Enum.UserInputType.MouseButton2 and ContextMenu.Container.Visible then
                if not Library:IsMouseOverFrame(ContextMenu.Container) and not Library:IsMouseOverFrame(DisplayFrame) then
                    ContextMenu:Hide()
                end
            end
        end))

        function ColorPicker:GetTransparency()
            return ColorPicker.Transparency;
        end;

        function ColorPicker:OnTransparencyChanged(Func)
            ColorPicker.TransparencyChanged = Func;
            Func(ColorPicker.Transparency);
        end;

        local _OrigDisplay = ColorPicker.Display;
        ColorPicker.Display = function(self)
            _OrigDisplay(self);
            Library:SafeCallback(ColorPicker.TransparencyChanged, ColorPicker.Transparency);
        end;

        ColorPicker:Display();
        ColorPicker.DisplayFrame = DisplayFrame

        Options[Idx] = ColorPicker;

        return self;
    end;

    function Funcs:AddColorPickerAlpha(Idx, Info)
        Info = Info or {};
        if Info.Transparency == nil then
            Info.Transparency = 0;
        end;
        return Funcs.AddColorPicker(self, Idx, Info);
    end;

    function Funcs:AddKeyPicker(Idx, Info)
        local ParentObj = self;
        local ToggleLabel = self.TextLabel;
        local Container = self.Container;

        assert(Info.Default, 'AddKeyPicker: Missing default value.');

        local KeyPicker = {
            Value = Info.Default;
            Toggled = false;
            Mode = Info.Mode or 'Toggle';
            Type = 'KeyPicker';
            Callback = Info.Callback or function(Value) end;
            ChangedCallback = Info.ChangedCallback or function(New) end;

            SyncToggleState = Info.SyncToggleState or false;
        };
        if KeyPicker.SyncToggleState then
            Info.Modes = { 'Toggle' }
            Info.Mode = 'Toggle'
        end

        local PickOuter = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            Size = UDim2.new(0, 34, 0, 16);
            ZIndex = 6;
            Parent = ToggleLabel;
        });
        Library:Round(PickOuter, 4);
        local PickStroke = Library:Stroke(PickOuter, 'OutlineColor');
        Library:AddToRegistry(PickOuter, {
            BackgroundColor3 = 'BackgroundColor';
        });
        local PickInner = PickOuter;
        local ChipLabel = Library:CreateLabel({
            Dim = true;
            Size = UDim2.new(1, 0, 1, 0);
            TextSize = Library.FontSize - 2;
            Text = '';
            ZIndex = 8;
            Parent = PickOuter;
        });
        local function SetChip(Value)
            Value = tostring(Value or '');
            if Value ~= '' and Value:sub(1, 1) ~= '.' then
                Value = '[' .. Value .. ']';
            end;
            ChipLabel.Text = Value;
            local W = Library:GetTextBounds(Value, Library.Font, Library.FontSize - 2);
            PickOuter.Size = UDim2.new(0, math.max(24, (W or 0) + 12), 0, 16);
        end;
        -- the rest of the picker assigns DisplayLabel.Text; route that to the chip
        local DisplayLabel = setmetatable({}, {
            __newindex = function(_, Key, Value)
                if Key == 'Text' then
                    SetChip(Value);
                end;
            end;
        });
        Library:OnHover(PickOuter, PickStroke);
        SetChip(Info.Default);

        local ModeSelectOuter = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            Size = UDim2.new(0, 64, 0, (Info.Modes and #Info.Modes or 3) * 20 + 6);
            Visible = false;
            ZIndex = 14;
            Parent = ScreenGui;
        });
        Library:Round(ModeSelectOuter, 5);
        Library:Stroke(ModeSelectOuter, 'OutlineColor');
        Library:AddToRegistry(ModeSelectOuter, {
            BackgroundColor3 = 'MainColor';
        });
        local function PlaceModeSelect()
            ModeSelectOuter.Position = UDim2.fromOffset(PickOuter.AbsolutePosition.X + PickOuter.AbsoluteSize.X - 64, PickOuter.AbsolutePosition.Y + PickOuter.AbsoluteSize.Y + 4);
        end;
        PickOuter:GetPropertyChangedSignal('AbsolutePosition'):Connect(PlaceModeSelect);
        PickOuter:GetPropertyChangedSignal('AbsoluteSize'):Connect(PlaceModeSelect);
        PlaceModeSelect();
        local ModeSelectInner = ModeSelectOuter;
        Library:Create('UIListLayout', {
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = ModeSelectInner;
        });
        Library:Create('UIPadding', {
            PaddingTop = UDim.new(0, 3);
            Parent = ModeSelectInner;
        });
        local KeybindEntry = Library:Create('Frame', {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 18),
            Visible = false,
            ZIndex = 110,
            Parent = Library.KeybindContainer,
        })

        local ContainerLabel = Library:CreateLabel({
            Position = UDim2.new(0, 2, 0, 0),
            Size = UDim2.new(1, -4, 1, 0),
            TextSize = Library.FontSize - 1,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 111,
            Parent = KeybindEntry,
        }, true)

        local Modes = Info.Modes or { 'Always', 'Toggle', 'Hold' };
        local ModeButtons = {};

        for Idx, Mode in next, Modes do
            local ModeButton = {};
            local Label = Library:CreateLabel({
                Active = false;
                Size = UDim2.new(1, 0, 0, 20);
                TextSize = Library.FontSize - 1;
                Text = Mode;
                ZIndex = 16;
                Parent = ModeSelectInner;
            });
            function ModeButton:Select()
                for _, Button in next, ModeButtons do
                    Button:Deselect();
                end;

                KeyPicker.Mode = Mode;

                Label.TextColor3 = Library.AccentColor;
                Library.RegistryMap[Label].Properties.TextColor3 = 'AccentColor';

                ModeSelectOuter.Visible = false;
            end;
            function ModeButton:Deselect()
                KeyPicker.Mode = nil;
                Label.TextColor3 = Library.FontColor;
                Library.RegistryMap[Label].Properties.TextColor3 = 'FontColor';
            end;

            Label.InputBegan:Connect(function(Input)
                if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) then
                    ModeButton:Select();
                    Library:AttemptSave();
                end;
            end);
            if Mode == KeyPicker.Mode then
                ModeButton:Select();
            end;

            ModeButtons[Mode] = ModeButton;
        end;

        function KeyPicker:Update()
            if Info.NoUI then
                return;
            end;

            local State = KeyPicker:GetState();

            local displayKey = (KeyPicker.Value == 'None') and '...' or KeyPicker.Value
            ContainerLabel.Text = string.format('[%s] %s (%s)', displayKey, Info.Text, KeyPicker.Mode);
            local kbMode = Library.KeybindMode or 'All'
            if kbMode == 'Active' then
                KeybindEntry.Visible = State == true
            elseif kbMode == 'Toggled' then
                local parentOn = false
                if ParentObj and ParentObj.Type == 'Toggle' then
                    parentOn = ParentObj.Value == true
                elseif KeyPicker.SyncToggleState and ParentObj then
                    parentOn = ParentObj.Value == true
                else
                    parentOn = true
                end
                KeybindEntry.Visible = parentOn
            else
                KeybindEntry.Visible = true
            end

            ContainerLabel.TextColor3 = State and Library.AccentColor or Library.FontColor;
            Library.RegistryMap[ContainerLabel].Properties.TextColor3 = State and 'AccentColor' or 'FontColor';

            local YSize = 0
            local XSize = 0

            for _, Frame in next, Library.KeybindContainer:GetChildren() do
                if Frame:IsA('Frame') and Frame.Visible then
                    YSize = YSize + 18;
                    local LabelChild = Frame:FindFirstChildOfClass('TextLabel')
                    if LabelChild and (LabelChild.TextBounds.X + 20 > XSize) then
                        XSize = LabelChild.TextBounds.X + 20 
                    end
                end;
            end;

            Library.KeybindFrame.Size = UDim2.new(0, math.max(XSize + 10 + 15, 210), 0, YSize + 36)
        end;
        function KeyPicker:GetState()
            if KeyPicker.Mode == 'Always' then
                return true;
            elseif KeyPicker.Mode == 'Hold' then
                if KeyPicker.Value == 'None' then
                    return false;
                end

                local Key = KeyPicker.Value;
                if Key == 'MB1' or Key == 'MB2' or Key == 'Touch' then
                    return Key == 'MB1' and InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
                        or Key == 'MB2' and InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
                        or Key == 'Touch' and true
                else
                    return InputService:IsKeyDown(Enum.KeyCode[KeyPicker.Value]);
                end;
            else
                return KeyPicker.Toggled;
            end;
        end;

        function KeyPicker:SetValue(Data)
            local Key, Mode = Data[1], Data[2];
            DisplayLabel.Text = Key;
            KeyPicker.Value = Key;
            ModeButtons[Mode]:Select();
            KeyPicker:Update();
        end;

        function KeyPicker:OnClick(Callback)
            KeyPicker.Clicked = Callback
        end

        function KeyPicker:OnChanged(Callback)
            KeyPicker.Changed = Callback
            Callback(KeyPicker.Value)
        end

        if ParentObj.Addons then
            table.insert(ParentObj.Addons, KeyPicker)
            table.insert(Library.KeyPickerList, KeyPicker)
        end

        function KeyPicker:DoClick()
            if ParentObj.Type == 'Toggle' and KeyPicker.SyncToggleState then
                ParentObj:SetValue(not ParentObj.Value)
            end

            Library:SafeCallback(KeyPicker.Callback, KeyPicker.Toggled)
            Library:SafeCallback(KeyPicker.Clicked, KeyPicker.Toggled)
        end

        local Picking = false;
        local LongPressTime = Info.LongPressTime or 0.55;
        local TouchMoveThreshold = Info.TouchMoveThreshold or 10;

        local function OpenModeSelect()
            ModeSelectOuter.Visible = true;
        end;

        local function BeginPicking()
            if Picking then
                return;
            end;

            Picking = true;

            DisplayLabel.Text = '';

            local Break;
            local Text = '';

            task.spawn(function()
                while (not Break) do
                    if Text == '...' then
                        Text = '';
                    end;

                    Text = Text .. '.';
                    DisplayLabel.Text = Text;

                    wait(0.4);
                end;
            end);

            wait(0.2);

            local Event;
            Event = InputService.InputBegan:Connect(function(Input)
                local Key;

                if Input.UserInputType == Enum.UserInputType.Keyboard then
                    Key = Input.KeyCode.Name;
                elseif Input.UserInputType == Enum.UserInputType.MouseButton1 then
                    Key = 'MB1';
                elseif Input.UserInputType == Enum.UserInputType.MouseButton2 then
                    Key = 'MB2';
                elseif Input.UserInputType == Enum.UserInputType.Touch then
                    Key = 'Touch';
                end;

                if not Key then
                    return;
                end;

                Break = true;
                Picking = false;

                DisplayLabel.Text = Key;
                KeyPicker.Value = Key;
                Library:SafeCallback(KeyPicker.ChangedCallback, Input.KeyCode or Input.UserInputType)
                Library:SafeCallback(KeyPicker.Changed, Input.KeyCode or Input.UserInputType)

                Library:AttemptSave();
                Event:Disconnect();
            end);
        end;

        PickOuter.InputBegan:Connect(function(Input)
            if Library:MouseIsOverOpenedFrame() then
                return;
            end;

            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                BeginPicking();
            elseif Input.UserInputType == Enum.UserInputType.MouseButton2 then
                OpenModeSelect();
            elseif Input.UserInputType == Enum.UserInputType.Touch then
                local StartPosition = Input.Position;
                local TouchMoved = false;
                local TouchEnded = false;
                local LongPressed = false;
                local ChangedConn;
                local EndedConn;

                ChangedConn = InputService.InputChanged:Connect(function(Change)
                    if Change == Input then
                        if (Change.Position - StartPosition).Magnitude > TouchMoveThreshold then
                            TouchMoved = true;
                        end;
                    end;
                end);

                EndedConn = InputService.InputEnded:Connect(function(EndInput)
                    if EndInput == Input then
                        TouchEnded = true;

                        if ChangedConn then
                            ChangedConn:Disconnect();
                        end;

                        if EndedConn then
                            EndedConn:Disconnect();
                        end;

                        if (not LongPressed) and (not TouchMoved) then
                            task.spawn(BeginPicking);
                        end;
                    end;
                end);

                task.delay(LongPressTime, function()
                    if TouchEnded or TouchMoved then
                        return;
                    end;

                    LongPressed = true;

                    if ChangedConn then
                        ChangedConn:Disconnect();
                    end;

                    if EndedConn then
                        EndedConn:Disconnect();
                    end;

                    OpenModeSelect();
                end);
            end;
        end);

        Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
            if (not Picking) then
                if KeyPicker.Mode == 'Toggle' then
                    local Key = KeyPicker.Value;

                    if Key == 'MB1' or Key == 'MB2' or Key == 'Touch' then
                        if Key == 'MB1' and Input.UserInputType == Enum.UserInputType.MouseButton1
                        or Key == 'MB2' and Input.UserInputType == Enum.UserInputType.MouseButton2 
                        or Key == 'Touch' and Input.UserInputType == Enum.UserInputType.Touch then
                            KeyPicker.Toggled = not KeyPicker.Toggled
                            KeyPicker:DoClick()
                        end;
                    elseif Input.UserInputType == Enum.UserInputType.Keyboard then
                        if Input.KeyCode.Name == Key then
                            KeyPicker.Toggled = not KeyPicker.Toggled;
                            KeyPicker:DoClick()
                        end;
                    end;
                end;

                KeyPicker:Update();
            end;
            if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) then
                local AbsPos, AbsSize = ModeSelectOuter.AbsolutePosition, ModeSelectOuter.AbsoluteSize;
                if Mouse.X < AbsPos.X or Mouse.X > AbsPos.X + AbsSize.X
                    or Mouse.Y < (AbsPos.Y - 20 - 1) or Mouse.Y > AbsPos.Y + AbsSize.Y then

                    ModeSelectOuter.Visible = false;
                end;
            end;
        end))

        Library:GiveSignal(InputService.InputEnded:Connect(function(Input)
            if (not Picking) then
                KeyPicker:Update();
            end;
        end))

        KeyPicker:Update();
        Options[Idx] = KeyPicker;

        return self;
    end;

    BaseAddons.__index = Funcs;
    BaseAddons.__namecall = function(Table, Key, ...)
        return Funcs[Key](...);
    end;
end;

local BaseGroupbox = {};

do
    local Funcs = {};
    function Funcs:AddBlank(Size)
        local Groupbox = self;
        local Container = Groupbox.Container;
        Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 0, Size);
            ZIndex = 1;
            Parent = Container;
        });
    end;

    function Funcs:AddRow(Columns)
        local Groupbox = self
        local Container = Groupbox.Container

        local ColumnsCount = type(Columns) == 'number' and math.max(1, Columns) or 2

        local RowOuter = Library:Create('Frame', {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 0),
            ZIndex = 1,
            Parent = Container
        })

        Library:Create('UIListLayout', {
            FillDirection = Enum.FillDirection.Horizontal,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 8),
            Parent = RowOuter
        })

        local Boxes = {}

        for i = 1, ColumnsCount do
            local Box = { Type = 'Groupbox'; Root = Groupbox.Root or Groupbox }

            local BoxContainer = Library:Create('Frame', {
                BackgroundTransparency = 1,
                Size = UDim2.new(1 / ColumnsCount, -((ColumnsCount - 1) * 8) / ColumnsCount, 1, 0),
                ZIndex = 1,
                Parent = RowOuter
            })

            local BoxLayout = Library:Create('UIListLayout', {
                FillDirection = Enum.FillDirection.Vertical,
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 4),
                Parent = BoxContainer
            })

            Box.Container = BoxContainer
            setmetatable(Box, BaseGroupbox)

            function Box:Resize()
                local maxHeight = 0
                for _, child in next, RowOuter:GetChildren() do
                    if child:IsA('Frame') then
                        local layout = child:FindFirstChildOfClass('UIListLayout')
                        if layout and layout.AbsoluteContentSize.Y > maxHeight then
                            maxHeight = layout.AbsoluteContentSize.Y
                        end
                    end
                end
                RowOuter.Size = UDim2.new(1, 0, 0, maxHeight)
                if Groupbox.Resize then
                    Groupbox:Resize()
                end
            end

            BoxLayout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
                Box:Resize()
            end)

            table.insert(Boxes, Box)
        end

        Groupbox:AddBlank(1)
        if Groupbox.Resize then Groupbox:Resize() end

        return unpack(Boxes)
    end;
    function Funcs:AddLabel(Text, DoesWrap)
        local Label = {};

        local Groupbox = self;
        local Container = Groupbox.Container;

        local TextLabel = Library:CreateLabel({
            Size = UDim2.new(1, -4, 0, 18);
            TextSize = Library.FontSize;
            Text = Text;
            TextWrapped = DoesWrap or false,
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 5;
            Parent = Container;
        });
        if DoesWrap then
            local Y = select(2, Library:GetTextBounds(Text, Library.Font, Library.FontSize, Vector2.new(TextLabel.AbsoluteSize.X, math.huge)))
            TextLabel.Size = UDim2.new(1, -4, 0, Y)
        else
            Library:Create('UIListLayout', {
                Padding = UDim.new(0, 4);
                FillDirection = Enum.FillDirection.Horizontal;
                HorizontalAlignment = Enum.HorizontalAlignment.Right;
                VerticalAlignment = Enum.VerticalAlignment.Center;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = TextLabel;
            });
        end

        Label.TextLabel = TextLabel;
        Label.Container = Container;
        function Label:SetText(Text)
            TextLabel.Text = Text

            if DoesWrap then
                local Y = select(2, Library:GetTextBounds(Text, Library.Font, Library.FontSize, Vector2.new(TextLabel.AbsoluteSize.X, math.huge)))
                TextLabel.Size = UDim2.new(1, -4, 0, Y)
            end

            Groupbox:Resize();
        end

        if (not DoesWrap) then
            setmetatable(Label, BaseAddons);
        end

        Groupbox:AddBlank(5);
        Groupbox:Resize();

        return Label;
    end;
    function Funcs:AddButton(...)
        local Button = {};
        local function ProcessButtonParams(Class, Obj, ...)
            local Props = select(1, ...)
            if type(Props) == 'table' then
                Obj.Text = Props.Text
                Obj.Func = Props.Func
                Obj.DoubleClick = Props.DoubleClick
                Obj.Tooltip = Props.Tooltip
            else
                Obj.Text = select(1, ...)
                Obj.Func = select(2, ...)
            end

            assert(type(Obj.Func) == 'function', 'AddButton: `Func` callback is missing.');
        end

        ProcessButtonParams('Button', Button, ...)

        local Groupbox = self;
        local Container = Groupbox.Container;

        local function CreateBaseButton(Button)
            local Outer = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor;
                Size = UDim2.new(1, 0, 0, 24);
                ZIndex = 5;
            });
            Library:Round(Outer, 5);
            local Stroke = Library:Stroke(Outer, 'OutlineColor');
            Library:AddToRegistry(Outer, {
                BackgroundColor3 = 'BackgroundColor';
            });
            local Label = Library:CreateLabel({
                Size = UDim2.new(1, 0, 1, 0);
                TextSize = Library.FontSize;
                Text = Button.Text;
                ZIndex = 6;
                Parent = Outer;
            });
            Library:OnHover(Outer, Stroke, 'BackgroundColor');
            return Outer, Outer, Label
        end

        local function InitEvents(Button)
            local function WaitForEvent(event, timeout, validator)
                local bindable = Instance.new('BindableEvent')
                local connection = event:Connect(function(...)
                    if type(validator) == 'function' and validator(...) then
                        bindable:Fire(true)
                    else
                        bindable:Fire(false)
                    end
                end)
                task.delay(timeout, function()
                    connection:Disconnect()
                    bindable:Fire(false)
                end)
                local Result = bindable.Event:Wait()
                connection:Disconnect()
                return Result
            end

            local function ValidateClick(Input)
                if Library:MouseIsOverOpenedFrame() then
                    return false
                end

                if Input.UserInputType ~= Enum.UserInputType.MouseButton1 and Input.UserInputType ~= Enum.UserInputType.Touch then
                    return false
                end

                return true
            end

            Button.Outer.InputBegan:Connect(function(Input)
                if not ValidateClick(Input) then return end
 
                if Button.Locked then return end

                Button.Outer.BackgroundColor3 = Library.AccentColorDark
                Library:Tween(Button.Outer, { BackgroundColor3 = Library.BackgroundColor }, 0.25)

                if Button.DoubleClick then
                    Library:RemoveFromRegistry(Button.Label)
                    Library:AddToRegistry(Button.Label, { TextColor3 = 'AccentColor' })

                    Button.Label.TextColor3 = Library.AccentColor
                    Button.Label.Text = 'Are you sure?'
                    Button.Locked = true

                    local clicked = WaitForEvent(Button.Outer.InputBegan, 0.5, ValidateClick)

                    Library:RemoveFromRegistry(Button.Label)
                    Library:AddToRegistry(Button.Label, { TextColor3 = 'FontColor' })

                    Button.Label.TextColor3 = Library.FontColor
                    Button.Label.Text = Button.Text
                    task.defer(rawset, Button, 'Locked', false)

                    if clicked then
                        Library:SafeCallback(Button.Func)
                    end

                    return
                end

                Library:SafeCallback(Button.Func);
            end)
        end

        Button.Outer, Button.Inner, Button.Label = CreateBaseButton(Button)
        Button.Outer.Parent = Container

        InitEvents(Button)

        function Button:AddTooltip(tooltip)
            if type(tooltip) == 'string' then
                Library:AddToolTip(tooltip, self.Outer)
            end
            return self
        end

        function Button:AddButton(...)
            local SubButton = {}

            ProcessButtonParams('SubButton', SubButton, ...)

            self.Outer.Size = UDim2.new(0.5, -2, 0, 24)

            SubButton.Outer, SubButton.Inner, SubButton.Label = CreateBaseButton(SubButton)

            SubButton.Outer.Position = UDim2.new(1, 4, 0, 0)
            SubButton.Outer.Size = UDim2.new(1, 0, 1, 0)
            SubButton.Outer.Parent = self.Outer

            function SubButton:AddTooltip(tooltip)
                if type(tooltip) == 'string' then
                    Library:AddToolTip(tooltip, self.Outer)
                 end
                return SubButton
            end

            if type(SubButton.Tooltip) == 'string' then
                SubButton:AddTooltip(SubButton.Tooltip)
            end

            InitEvents(SubButton)
            return SubButton
        end

        if type(Button.Tooltip) == 'string' then
            Button:AddTooltip(Button.Tooltip)
        end

        Groupbox:AddBlank(5);
        Groupbox:Resize();

        return Button;
    end;

    function Funcs:AddDivider()
        local Groupbox = self;
        local Container = self.Container

        local Divider = {
            Type = 'Divider',
        }

        Groupbox:AddBlank(4);
        local Line = Library:Create('Frame', {
            BackgroundColor3 = Library.OutlineColor;
            Size = UDim2.new(1, 0, 0, 1);
            ZIndex = 5;
            Parent = Container;
        });
        Library:AddToRegistry(Line, {
            BackgroundColor3 = 'OutlineColor';
        });
        Groupbox:AddBlank(5);
        Groupbox:Resize();

        return Divider
    end

    function Funcs:AddInput(Idx, Info)
        assert(Info.Text, 'AddInput: Missing `Text` string.')

        local Textbox = {
            Value = Info.Default or '';
            Numeric = Info.Numeric or false;
            Finished = Info.Finished or false;
            Type = 'Input';
            Callback = Info.Callback or function(Value) end;
        };
        local Groupbox = self;
        local Container = Groupbox.Container;

        local InputLabel = Library:CreateLabel({
            Dim = true;
            Size = UDim2.new(1, 0, 0, 14);
            TextSize = Library.FontSize - 1;
            Text = Info.Text;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 5;
            Parent = Container;
        });

        Groupbox:AddBlank(3);

        local TextBoxOuter = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            Size = UDim2.new(1, 0, 0, 24);
            ZIndex = 5;
            Parent = Container;
        });
        Library:Round(TextBoxOuter, 5);
        local TextBoxStroke = Library:Stroke(TextBoxOuter, 'OutlineColor');
        Library:AddToRegistry(TextBoxOuter, {
            BackgroundColor3 = 'BackgroundColor';
        });
        Library:OnHover(TextBoxOuter, TextBoxStroke);
        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, TextBoxOuter)
        end

        local BoxClip = Library:Create('Frame', {
            BackgroundTransparency = 1;
            ClipsDescendants = true;

            Position = UDim2.new(0, 6, 0, 0);
            Size = UDim2.new(1, -12, 1, 0);

            ZIndex = 7;
            Parent = TextBoxOuter;
        })

        local Box = Library:Create('TextBox', {
            BackgroundTransparency = 1;

            Position = UDim2.fromOffset(0, 0),
            Size = UDim2.fromScale(5, 1),

            Font = Library.Font;
            PlaceholderColor3 = Library:GetDimColor();
            PlaceholderText = Info.Placeholder or '';

            Text = Info.Default or '';
            TextColor3 = Library.FontColor;
            TextSize = Library.FontSize;
            TextXAlignment = Enum.TextXAlignment.Left;

            ZIndex = 7;
            Parent = BoxClip;
        });

        Library:ApplyTextStroke(Box);
        function Textbox:SetValue(Text)
            if Info.MaxLength and #Text > Info.MaxLength then
                Text = Text:sub(1, Info.MaxLength);
            end;

            if Textbox.Numeric then
                if (not tonumber(Text)) and Text:len() > 0 then
                    Text = Textbox.Value
                end
            end

            Textbox.Value = Text;
            Box.Text = Text;

            Library:SafeCallback(Textbox.Callback, Textbox.Value);
            Library:SafeCallback(Textbox.Changed, Textbox.Value);
        end;

        if Textbox.Finished then
            Box.FocusLost:Connect(function(enter)
                if not enter then return end

                Textbox:SetValue(Box.Text);
                Library:AttemptSave();
            end)
        else
            Box:GetPropertyChangedSignal('Text'):Connect(function()
                Textbox:SetValue(Box.Text);
                Library:AttemptSave();
            end);
        end

        local function Update()
            local PADDING = 2
            local reveal = BoxClip.AbsoluteSize.X

            if not Box:IsFocused() or Box.TextBounds.X <= reveal - 2 * PADDING then
                Box.Position = UDim2.new(0, PADDING, 0, 0)
            else
                local cursor = Box.CursorPosition
                if cursor ~= -1 then
                    local subtext = string.sub(Box.Text, 1, cursor-1)
                    local width = TextService:GetTextSize(subtext, Box.TextSize, Box.Font, Vector2.new(math.huge, math.huge)).X

                    local currentCursorPos = Box.Position.X.Offset + width

                    if currentCursorPos < PADDING then
                        Box.Position = UDim2.fromOffset(PADDING-width, 0)
                    elseif currentCursorPos > reveal - PADDING - 1 then
                        Box.Position = UDim2.fromOffset(reveal-width-PADDING-1, 0)
                    end
                end
            end
        end

        task.spawn(Update)

        Box:GetPropertyChangedSignal('Text'):Connect(Update)
        Box:GetPropertyChangedSignal('CursorPosition'):Connect(Update)
        Box.FocusLost:Connect(function()
            Update()
            Library:Tween(TextBoxStroke, { Color = Library.OutlineColor }, 0.12)
        end)
        Box.Focused:Connect(function()
            Update()
            Library:Tween(TextBoxStroke, { Color = Library.AccentColor }, 0.12)
        end)

        Library:AddToRegistry(Box, {
            TextColor3 = 'FontColor';
            PlaceholderColor3 = function() return Library:GetDimColor() end;
        });

        function Textbox:OnChanged(Func)
            Textbox.Changed = Func;
            Func(Textbox.Value);
        end;

        Groupbox:AddBlank(5);
        Groupbox:Resize();

        Options[Idx] = Textbox;

        return Textbox;
    end;

    function Funcs:AddToggle(Idx, Info)
        assert(Info.Text, 'AddInput: Missing `Text` string.')

        local Toggle = {
            Value = Info.Default or false;
            Type = 'Toggle';

            Callback = Info.Callback or function(Value) end;
            Addons = {},
            Risky = Info.Risky,
        };
        local Groupbox = self;
        local Container = Groupbox.Container;

        local Row = Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 0, 18);
            ZIndex = 5;
            Parent = Container;
        });
        local ToggleLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 1, 0);
            TextSize = Library.FontSize;
            Text = Info.Text;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 6;
            Parent = Row;
        });
        Library:Create('UIListLayout', {
            Padding = UDim.new(0, 6);
            FillDirection = Enum.FillDirection.Horizontal;
            HorizontalAlignment = Enum.HorizontalAlignment.Right;
            VerticalAlignment = Enum.VerticalAlignment.Center;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = ToggleLabel;
        });

        -- last in the list so addons (chips, swatches) sit left of the pill
        local Pill = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            LayoutOrder = 100;
            Size = UDim2.fromOffset(26, 12);
            ZIndex = 7;
            Parent = ToggleLabel;
        });
        Library:Round(Pill, 6);
        local PillStroke = Library:Stroke(Pill, 'OutlineColor');
        Library:AddToRegistry(Pill, {
            BackgroundColor3 = 'BackgroundColor';
        });
        local OnFill = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(1, 1, 1);
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 8;
            Parent = Pill;
        });
        Library:Round(OnFill, 6);
        Library:AddGradient(Library:Create('UIGradient', { Parent = OnFill }), 'slide');
        local Knob = Library:Create('Frame', {
            AnchorPoint = Vector2.new(0, 0.5);
            BackgroundColor3 = Library:GetDimColor();
            Position = UDim2.new(0, 2, 0.5, 0);
            Size = UDim2.fromOffset(8, 8);
            ZIndex = 9;
            Parent = Pill;
        });
        Library:Round(Knob, 4);
        Library:AddToRegistry(Knob, {
            BackgroundColor3 = function()
                return Toggle.Value and Color3.new(1, 1, 1) or Library:GetDimColor();
            end;
        });

        local ToggleRegion = Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 10;
            Parent = Row;
        });
        ToggleRegion.MouseEnter:Connect(function()
            if not Toggle.Value then
                Library:Tween(PillStroke, { Color = Library.AccentColor }, 0.12);
            end
        end);
        ToggleRegion.MouseLeave:Connect(function()
            Library:Tween(PillStroke, { Color = Library.OutlineColor }, 0.12);
        end);

        function Toggle:UpdateColors()
            Toggle:Display(true);
        end;
        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, ToggleRegion)
        end

        function Toggle:Display(Instant)
            local On = Toggle.Value;
            local KnobPos = On and UDim2.new(0, 16, 0.5, 0) or UDim2.new(0, 2, 0.5, 0);
            local KnobColor = On and Color3.new(1, 1, 1) or Library:GetDimColor();

            if Instant then
                OnFill.BackgroundTransparency = On and 0 or 1;
                Knob.Position = KnobPos;
                Knob.BackgroundColor3 = KnobColor;
                PillStroke.Transparency = On and 1 or 0;
            else
                Library:Tween(OnFill, { BackgroundTransparency = On and 0 or 1 }, 0.16);
                Library:Tween(Knob, { Position = KnobPos; BackgroundColor3 = KnobColor }, 0.16);
                Library:Tween(PillStroke, { Transparency = On and 1 or 0 }, 0.16);
            end
        end;

        function Toggle:OnChanged(Func)
            Toggle.Changed = Func;
            Func(Toggle.Value);
        end;

        function Toggle:SetValue(Bool)
            Bool = (not not Bool);
            Toggle.Value = Bool;
            Toggle:Display();

            for _, Addon in next, Toggle.Addons do
                if Addon.Type == 'KeyPicker' and Addon.SyncToggleState then
                    Addon.Toggled = Bool
                    Addon:Update()
                end
            end

            Library:SafeCallback(Toggle.Callback, Toggle.Value);
            Library:SafeCallback(Toggle.Changed, Toggle.Value);
            Library:UpdateDependencyBoxes();
        end;
        ToggleRegion.InputBegan:Connect(function(Input)
            if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) and not Library:MouseIsOverOpenedFrame() then
                for _, Child in next, ToggleLabel:GetChildren() do
                    if Child ~= Pill and Child:IsA('GuiObject') and Child.Visible and Library:IsMouseOverFrame(Child) then
                        return;
                    end;
                end;

                Toggle:SetValue(not Toggle.Value)
                Library:AttemptSave();
            end;
        end);
        if Toggle.Risky then
            Library:RemoveFromRegistry(ToggleLabel)
            ToggleLabel.TextColor3 = Library.RiskColor
            Library:AddToRegistry(ToggleLabel, { TextColor3 = 'RiskColor' })
        end

        Toggle:Display(true);
        Groupbox:AddBlank(Info.BlankSize or 4);
        Groupbox:Resize();

        Toggle.TextLabel = ToggleLabel;
        Toggle.Container = Container;
        setmetatable(Toggle, BaseAddons);

        Toggles[Idx] = Toggle;

        Library:UpdateDependencyBoxes();

        return Toggle;
    end;

    function Funcs:AddSlider(Idx, Info)
        assert(Info.Default, 'AddSlider: Missing default value.');
        assert(Info.Text, 'AddSlider: Missing slider text.');
        assert(Info.Min, 'AddSlider: Missing minimum value.');
        assert(Info.Max, 'AddSlider: Missing maximum value.');
        assert(Info.Rounding, 'AddSlider: Missing rounding value.');
        local Slider = {
            Value = Info.Default;
            Min = Info.Min;
            Max = Info.Max;
            Rounding = Info.Rounding;
            MaxSize = 232;
            Type = 'Slider';
            Callback = Info.Callback or function(Value) end;
        };

        local Groupbox = self;
        local Container = Groupbox.Container;

        local Header = Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 0, 14);
            ZIndex = 5;
            Parent = Container;
        });
        Library:CreateLabel({
            Size = UDim2.new(1, 0, 1, 0);
            TextSize = Library.FontSize;
            Text = Info.Text;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 5;
            Parent = Header;
        });
        local DisplayLabel = Library:CreateLabel({
            Dim = true;
            Size = UDim2.new(1, 0, 1, 0);
            TextSize = Library.FontSize - 1;
            Text = '';
            TextXAlignment = Enum.TextXAlignment.Right;
            ZIndex = 5;
            Parent = Header;
        });
        Groupbox:AddBlank(3);

        local SliderOuter = Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 0, 12);
            ZIndex = 5;
            Parent = Container;
        });
        local Track = Library:Create('Frame', {
            AnchorPoint = Vector2.new(0, 0.5);
            BackgroundColor3 = Library.OutlineColor;
            Position = UDim2.new(0, 0, 0.5, 0);
            Size = UDim2.new(1, 0, 0, 4);
            ZIndex = 6;
            Parent = SliderOuter;
        });
        Library:Round(Track, 2);
        Library:AddToRegistry(Track, {
            BackgroundColor3 = 'OutlineColor';
        });
        local Fill = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(1, 1, 1);
            Size = UDim2.new(0, 0, 1, 0);
            ZIndex = 7;
            Parent = Track;
        });
        Library:Round(Fill, 2);
        Library:AddGradient(Library:Create('UIGradient', { Parent = Fill }), 'slide');
        local Knob = Library:Create('Frame', {
            AnchorPoint = Vector2.new(0.5, 0.5);
            BackgroundColor3 = Color3.new(1, 1, 1);
            Position = UDim2.new(1, 0, 0.5, 0);
            Size = UDim2.fromOffset(10, 10);
            ZIndex = 8;
            Parent = Fill;
        });
        Library:Round(Knob, 5);
        Library:Create('UIStroke', {
            Color = Color3.new(0, 0, 0);
            Transparency = 0.7;
            Thickness = 1;
            Parent = Knob;
        });

        SliderOuter.MouseEnter:Connect(function()
            Library:Tween(Knob, { Size = UDim2.fromOffset(12, 12) }, 0.1);
        end);
        SliderOuter.MouseLeave:Connect(function()
            if not Slider.Dragging then
                Library:Tween(Knob, { Size = UDim2.fromOffset(10, 10) }, 0.1);
            end
        end);
        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, SliderOuter)
        end

        function Slider:UpdateColors()
            Slider:Display(true);
        end;

        function Slider:Display(Instant)
            local Suffix = Info.Suffix or '';
            if Info.HideMax then
                DisplayLabel.Text = tostring(Slider.Value) .. Suffix;
            else
                DisplayLabel.Text = tostring(Slider.Value) .. Suffix .. ' / ' .. tostring(Slider.Max) .. Suffix;
            end

            local Alpha = 0;
            if Slider.Max ~= Slider.Min then
                Alpha = math.clamp((Slider.Value - Slider.Min) / (Slider.Max - Slider.Min), 0, 1);
            end
            local Target = UDim2.new(Alpha, 0, 1, 0);
            if Instant then
                Fill.Size = Target;
            else
                Library:Tween(Fill, { Size = Target }, 0.08);
            end
        end;
        function Slider:OnChanged(Func)
            Slider.Changed = Func;
            Func(Slider.Value);
        end;
        local function Round(Value)
            if Slider.Rounding == 0 then
                return math.floor(Value + 0.5);
            end;

            return tonumber(string.format('%.' .. Slider.Rounding .. 'f', Value))
        end;
        function Slider:GetValueFromXOffset(X)
            local Width = math.max(Track.AbsoluteSize.X, 1);
            return Round(Library:MapValue(math.clamp(X, 0, Width), 0, Width, Slider.Min, Slider.Max));
        end;
        function Slider:SetValue(Str)
            local Num = tonumber(Str);
            if (not Num) then
                return;
            end;

            Num = math.clamp(Num, Slider.Min, Slider.Max);

            Slider.Value = Num;
            Slider:Display();

            Library:SafeCallback(Slider.Callback, Slider.Value);
            Library:SafeCallback(Slider.Changed, Slider.Value);
        end;
        SliderOuter.InputBegan:Connect(function(Input)
            if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) and not Library:MouseIsOverOpenedFrame() then
                Slider.Dragging = true;

                local function UpdateSlider(PosX)
                    local nValue = Slider:GetValueFromXOffset(PosX - Track.AbsolutePosition.X);
                    local OldValue = Slider.Value;

                    Slider.Value = nValue;

                    Slider:Display();

                    if nValue ~= OldValue then
                        Library:SafeCallback(Slider.Callback, Slider.Value);
                        Library:SafeCallback(Slider.Changed, Slider.Value);
                    end;
                end

                UpdateSlider(Input.Position.X)

                local ChangedConn = InputService.InputChanged:Connect(function(Change)
                    if Change.UserInputType == Enum.UserInputType.MouseMovement or Change == Input then
                        UpdateSlider(Change.Position.X)
                    end
                end)

                local EndedConn
                EndedConn = InputService.InputEnded:Connect(function(EndInput)
                    if EndInput == Input or EndInput.UserInputType == Enum.UserInputType.Touch then
                        ChangedConn:Disconnect()
                        EndedConn:Disconnect()
                        Slider.Dragging = false;
                        if not Library:IsMouseOverFrame(SliderOuter) then
                            Library:Tween(Knob, { Size = UDim2.fromOffset(10, 10) }, 0.1);
                        end
                        Library:AttemptSave()
                    end
                end)
            end;
        end);

        Slider:Display(true);
        Groupbox:AddBlank(Info.BlankSize or 6);
        Groupbox:Resize();

        Options[Idx] = Slider;

        return Slider;
    end;
    function Funcs:AddDropdown(Idx, Info)
        if Info.SpecialType == 'Player' then
            Info.Values = GetPlayersString();
            Info.AllowNull = true;
        elseif Info.SpecialType == 'Team' then
            Info.Values = GetTeamsString();
            Info.AllowNull = true;
        end;

        assert(Info.Values, 'AddDropdown: Missing dropdown value list.');
        assert(Info.AllowNull or Info.Default, 'AddDropdown: Missing default value. Pass `AllowNull` as true if this was intentional.')

        if (not Info.Text) then
            Info.Compact = true;
        end;

        local Dropdown = {
            Values = Info.Values;
            Value = Info.Multi and {};
            Multi = Info.Multi;
            Type = 'Dropdown';
            SpecialType = Info.SpecialType;
            Callback = Info.Callback or function(Value) end;
        };

        local Groupbox = self;
        local Container = Groupbox.Container;

        if not Info.Compact then
            Library:CreateLabel({
                Dim = true;
                Size = UDim2.new(1, 0, 0, 14);
                TextSize = Library.FontSize - 1;
                Text = Info.Text;
                TextXAlignment = Enum.TextXAlignment.Left;
                ZIndex = 5;
                Parent = Container;
            });
            Groupbox:AddBlank(3);
        end

        local ITEM_H = 22;
        local MAX_DROPDOWN_ITEMS = 8;

        local DropdownOuter = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            Size = UDim2.new(1, 0, 0, 24);
            ZIndex = 5;
            Parent = Container;
        });
        Library:Round(DropdownOuter, 5);
        local DropdownStroke = Library:Stroke(DropdownOuter, 'OutlineColor');
        Library:AddToRegistry(DropdownOuter, {
            BackgroundColor3 = 'BackgroundColor';
        });

        local DropdownArrow = Library:Create('ImageLabel', {
            AnchorPoint = Vector2.new(1, 0.5);
            BackgroundTransparency = 1;
            ImageColor3 = Library:GetDimColor();
            Position = UDim2.new(1, -7, 0.5, 0);
            Size = UDim2.new(0, 14, 0, 14);
            ZIndex = 8;
            Parent = DropdownOuter;
        });
        if not Library:ApplyIcon(DropdownArrow, 'chevron-down') then
            DropdownArrow.Image = 'http://www.roblox.com/asset/?id=6282522798';
        end
        Library:AddToRegistry(DropdownArrow, {
            ImageColor3 = function() return Library:GetDimColor() end;
        });
        local ItemList = Library:CreateLabel({
            Position = UDim2.new(0, 8, 0, 0);
            Size = UDim2.new(1, -30, 1, 0);
            TextSize = Library.FontSize;
            Text = '--';
            TextXAlignment = Enum.TextXAlignment.Left;
            TextTruncate = Enum.TextTruncate.AtEnd;
            ZIndex = 7;
            Parent = DropdownOuter;
        });
        Library:OnHover(DropdownOuter, DropdownStroke);
        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, DropdownOuter)
        end

        local ListOuter = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            ClipsDescendants = true;
            ZIndex = 20;
            Visible = false;
            Parent = ScreenGui;
        });
        Library:Round(ListOuter, 5);
        Library:Stroke(ListOuter, 'OutlineColor');
        Library:AddToRegistry(ListOuter, {
            BackgroundColor3 = 'MainColor';
        });
        local ListHeight = MAX_DROPDOWN_ITEMS * ITEM_H + 6;
        local OpenToken = 0;

        local function RecalculateListPosition()
            local Y = DropdownOuter.AbsolutePosition.Y + DropdownOuter.AbsoluteSize.Y + 4;
            local ViewH = Library.ScreenGui.AbsoluteSize.Y;
            if ViewH > 0 and Y + ListHeight > ViewH and DropdownOuter.AbsolutePosition.Y - ListHeight - 4 > 0 then
                Y = DropdownOuter.AbsolutePosition.Y - ListHeight - 4;
            end
            ListOuter.Position = UDim2.fromOffset(DropdownOuter.AbsolutePosition.X, Y);
        end;

        local function RecalculateListSize(YSize)
            ListHeight = YSize or (MAX_DROPDOWN_ITEMS * ITEM_H + 6);
            ListOuter.Size = UDim2.fromOffset(DropdownOuter.AbsoluteSize.X, ListOuter.Visible and ListHeight or 0)
        end;
        RecalculateListPosition();
        RecalculateListSize();

        DropdownOuter:GetPropertyChangedSignal('AbsolutePosition'):Connect(RecalculateListPosition);

        local Scrolling = Library:Create('ScrollingFrame', {
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            CanvasSize = UDim2.new(0, 0, 0, 0);
            Position = UDim2.new(0, 3, 0, 3);
            Size = UDim2.new(1, -6, 1, -6);
            ZIndex = 21;
            Parent = ListOuter;

            TopImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png',
            BottomImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png',

            ScrollBarThickness = 2,
            ScrollBarImageColor3 = Library.AccentColor,
        });
        Library:AddToRegistry(Scrolling, {
            ScrollBarImageColor3 = 'AccentColor'
        })

        Library:Create('UIListLayout', {
            Padding = UDim.new(0, 0);
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = Scrolling;
        });
        function Dropdown:Display()
            local Values = Dropdown.Values;
            local Str = '';

            if Info.Multi then
                for Idx, Value in next, Values do
                    if Dropdown.Value[Value] then
                        Str = Str .. Value .. ', ';
                    end;
                end;

                Str = Str:sub(1, #Str - 2);
            else
                Str = Dropdown.Value or '';
            end;

            ItemList.Text = (Str == '' and '--' or Str);
        end;
        function Dropdown:GetActiveValues()
            if Info.Multi then
                local T = {};
                for Value, Bool in next, Dropdown.Value do
                    table.insert(T, Value);
                end;

                return T;
            else
                return Dropdown.Value and 1 or 0;
            end;
        end;

        function Dropdown:BuildDropdownList()
            local Values = Dropdown.Values;
            local Buttons = {};

            for _, Element in next, Scrolling:GetChildren() do
                if not Element:IsA('UIListLayout') then
                    Element:Destroy();
                end;
            end;

            local Count = 0;

            for Idx, Value in next, Values do
                local Table = {};
                Count = Count + 1;

                local Button = Library:Create('Frame', {
                    BackgroundColor3 = Library.OutlineColor;
                    BackgroundTransparency = 1;
                    Size = UDim2.new(1, 0, 0, ITEM_H);
                    ZIndex = 23;
                    Active = true,
                    Parent = Scrolling;
                });
                Library:Round(Button, 4);
                Library:AddToRegistry(Button, {
                    BackgroundColor3 = 'OutlineColor';
                });
                local ButtonLabel = Library:CreateLabel({
                    Active = false;
                    Size = UDim2.new(1, -14, 1, 0);
                    Position = UDim2.new(0, 8, 0, 0);
                    TextSize = Library.FontSize;
                    Text = Value;
                    TextXAlignment = Enum.TextXAlignment.Left;
                    TextTruncate = Enum.TextTruncate.AtEnd;
                    ZIndex = 25;
                    Parent = Button;
                });

                Button.MouseEnter:Connect(function()
                    Library:Tween(Button, { BackgroundTransparency = 0.45 }, 0.1);
                end);
                Button.MouseLeave:Connect(function()
                    Library:Tween(Button, { BackgroundTransparency = 1 }, 0.1);
                end);
                local Selected;

                if Info.Multi then
                    Selected = Dropdown.Value[Value];
                else
                    Selected = Dropdown.Value == Value;
                end;

                function Table:UpdateButton()
                    if Info.Multi then
                        Selected = Dropdown.Value[Value];
                    else
                        Selected = Dropdown.Value == Value;
                    end;

                    ButtonLabel.TextColor3 = Selected and Library.AccentColor or Library.FontColor;
                    Library.RegistryMap[ButtonLabel].Properties.TextColor3 = Selected and 'AccentColor' or 'FontColor';
                end;
                Button.InputBegan:Connect(function(Input)
                    if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) then
                        local Try = not Selected;

                        if Dropdown:GetActiveValues() == 1 and (not Try) and (not Info.AllowNull) then
                        else
                            if Info.Multi then
                                Selected = Try;

                                if Selected then
                                    Dropdown.Value[Value] = true;
                                else
                                    Dropdown.Value[Value] = nil;
                                end;
                            else
                                Selected = Try;

                                if Selected then
                                    Dropdown.Value = Value;
                                else
                                    Dropdown.Value = nil;
                                end;

                                for _, OtherButton in next, Buttons do
                                    OtherButton:UpdateButton();
                                end;
                            end;

                            Table:UpdateButton();
                            Dropdown:Display();

                            Library:SafeCallback(Dropdown.Callback, Dropdown.Value);
                            Library:SafeCallback(Dropdown.Changed, Dropdown.Value);

                            Library:AttemptSave();
                        end;
                    end;
                end);

                Table:UpdateButton();
                Dropdown:Display();

                Buttons[Button] = Table;
            end;
            Scrolling.CanvasSize = UDim2.fromOffset(0, Count * ITEM_H);

            local Y = math.clamp(Count * ITEM_H, 0, MAX_DROPDOWN_ITEMS * ITEM_H) + 6;
            RecalculateListSize(Y);
        end;

        function Dropdown:SetValues(NewValues)
            if NewValues then
                Dropdown.Values = NewValues;
            end;

            Dropdown:BuildDropdownList();
        end;

        function Dropdown:OpenDropdown()
            OpenToken = OpenToken + 1;
            RecalculateListPosition();
            ListOuter.Size = UDim2.fromOffset(DropdownOuter.AbsoluteSize.X, 0);
            ListOuter.Visible = true;
            Library.OpenedFrames[ListOuter] = true;
            Library:Tween(ListOuter, { Size = UDim2.fromOffset(DropdownOuter.AbsoluteSize.X, ListHeight) }, 0.16);
            Library:Tween(DropdownArrow, { Rotation = 180 }, 0.16);
        end;

        function Dropdown:CloseDropdown()
            if not ListOuter.Visible then
                return;
            end;

            OpenToken = OpenToken + 1;
            local Token = OpenToken;
            Library.OpenedFrames[ListOuter] = nil;
            Library:Tween(DropdownArrow, { Rotation = 0 }, 0.16);
            Library:Tween(ListOuter, { Size = UDim2.fromOffset(DropdownOuter.AbsoluteSize.X, 0) }, 0.12);
            task.delay(0.13, function()
                if Token == OpenToken then
                    ListOuter.Visible = false;
                end;
            end);
        end;

        function Dropdown:OnChanged(Func)
            Dropdown.Changed = Func;
            Func(Dropdown.Value);
        end;

        function Dropdown:SetValue(Val)
            if Dropdown.Multi then
                local nTable = {};
                for Value, Bool in next, Val do
                    if table.find(Dropdown.Values, Value) then
                        nTable[Value] = true
                    end;
                end;

                Dropdown.Value = nTable;
            else
                if (not Val) then
                    Dropdown.Value = nil;
                elseif table.find(Dropdown.Values, Val) then
                    Dropdown.Value = Val;
                end;
            end;

            Dropdown:BuildDropdownList();

            Library:SafeCallback(Dropdown.Callback, Dropdown.Value);
            Library:SafeCallback(Dropdown.Changed, Dropdown.Value);
        end;

        DropdownOuter.InputBegan:Connect(function(Input)
            if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) and not Library:MouseIsOverOpenedFrame() then
                if Library.OpenedFrames[ListOuter] then
                    Dropdown:CloseDropdown();
                else
                    Dropdown:OpenDropdown();
                end;
            end;
        end);
        Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
            if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) then
                if not Library:IsMouseOverFrame(ListOuter) and not Library:IsMouseOverFrame(DropdownOuter) then
                    Dropdown:CloseDropdown();
                end;
            end;
        end));
        Dropdown:BuildDropdownList();
        Dropdown:Display();

        local Defaults = {}

        if type(Info.Default) == 'string' then
            local Idx = table.find(Dropdown.Values, Info.Default)
            if Idx then
                table.insert(Defaults, Idx)
            end
        elseif type(Info.Default) == 'table' then
            for _, Value in next, Info.Default do
                local Idx = table.find(Dropdown.Values, Value)
                if Idx then
                    table.insert(Defaults, Idx)
                end
            end
        elseif type(Info.Default) == 'number' and Dropdown.Values[Info.Default] ~= nil then
            table.insert(Defaults, Info.Default)
        end

        if next(Defaults) then
            for i = 1, #Defaults do
                local Index = Defaults[i]
                if Info.Multi then
                    Dropdown.Value[Dropdown.Values[Index]] = true
                else
                    Dropdown.Value = Dropdown.Values[Index];
                end

                if (not Info.Multi) then break end
            end

            Dropdown:BuildDropdownList();
            Dropdown:Display();
        end

        Groupbox:AddBlank(Info.BlankSize or 5);
        Groupbox:Resize();

        Options[Idx] = Dropdown;

        return Dropdown;
    end;
    function Funcs:AddDependencyBox()
        local Depbox = {
            Dependencies = {};
        };
        
        local Groupbox = self;
        local Container = Groupbox.Container;

        local Holder = Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 0, 0);
            Visible = false;
            Parent = Container;
        });
        local Frame = Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 1, 0);
            Visible = true;
            Parent = Holder;
        });
        local Layout = Library:Create('UIListLayout', {
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = Frame;
        });
        function Depbox:Resize()
            Holder.Size = UDim2.new(1, 0, 0, Layout.AbsoluteContentSize.Y);
            Groupbox:Resize();
        end;

        Layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
            Depbox:Resize();
        end);
        Holder:GetPropertyChangedSignal('Visible'):Connect(function()
            Depbox:Resize();
        end);
        function Depbox:Update()
            for _, Dependency in next, Depbox.Dependencies do
                local Elem = Dependency[1];
                local Value = Dependency[2];

                if Elem.Type == 'Toggle' and Elem.Value ~= Value then
                    Holder.Visible = false;
                    Depbox:Resize();
                    return;
                end;
            end;

            Holder.Visible = true;
            Depbox:Resize();
        end;

        function Depbox:SetupDependencies(Dependencies)
            for _, Dependency in next, Dependencies do
                assert(type(Dependency) == 'table', 'SetupDependencies: Dependency is not of type `table`.');
                assert(Dependency[1], 'SetupDependencies: Dependency is missing element argument.');
                assert(Dependency[2] ~= nil, 'SetupDependencies: Dependency is missing value argument.');
            end;

            Depbox.Dependencies = Dependencies;
            Depbox:Update();
        end;

        Depbox.Container = Frame;
        Depbox.Root = Groupbox.Root or Groupbox;

        setmetatable(Depbox, BaseGroupbox);

        table.insert(Library.DependencyBoxes, Depbox);

        return Depbox;
    end;

    -- every element creator registers its rows with the search filter
    local function WrapSearch(Name, GetText)
        local Orig = Funcs[Name];
        Funcs[Name] = function(self, ...)
            local Container = self.Container;
            local Before = {};
            for _, Child in next, Container:GetChildren() do
                Before[Child] = true;
            end;
            local Result = Orig(self, ...);
            local Frames = {};
            for _, Child in next, Container:GetChildren() do
                if not Before[Child] and Child:IsA('GuiObject') then
                    table.insert(Frames, Child);
                end;
            end;
            if #Frames > 0 then
                Library:AddSearchEntry(self.Root or self, GetText(...), Frames);
            end;
            return Result;
        end;
    end;
    local function InfoText(Idx, Info)
        return type(Info) == 'table' and Info.Text or '';
    end;
    WrapSearch('AddToggle', InfoText);
    WrapSearch('AddSlider', InfoText);
    WrapSearch('AddDropdown', InfoText);
    WrapSearch('AddInput', InfoText);
    WrapSearch('AddLabel', function(Text) return type(Text) == 'string' and Text or '' end);
    WrapSearch('AddButton', function(A) return type(A) == 'table' and A.Text or (type(A) == 'string' and A or '') end);
    WrapSearch('AddDivider', function() return '' end);

    BaseGroupbox.__index = Funcs;
    BaseGroupbox.__namecall = function(Table, Key, ...)
        return Funcs[Key](...);
    end;
end;
do
    Library.NotificationStack = {};

    Library.NotificationArea = Library:Create('Frame', {
        BackgroundTransparency  = 1;
        Position                = UDim2.new(0, 0, 0, 40);
        Size                    = UDim2.new(0, 320, 1, -50);
        ZIndex                  = 100;
        Parent                  = ScreenGui;
    });
    Library:Create('UIListLayout', {
        Padding        = UDim.new(0, 6);
        FillDirection  = Enum.FillDirection.Vertical;
        SortOrder      = Enum.SortOrder.LayoutOrder;
        Parent         = Library.NotificationArea;
    });

    function Library:ConfigureNotifications(Cfg)
        local C = Library.NotifyConfig;
        for k, v in next, Cfg do C[k] = v end;

        local AnchorX = C.Alignment == "Left" and 0 or (C.Alignment == "Right" and 1 or 0.5);
        local AnchorY = C.BarSide == "Top" and 0 or 1;
        local VAlign  = C.BarSide == "Top" and Enum.VerticalAlignment.Top or Enum.VerticalAlignment.Bottom;
        local HAlign  = C.Alignment == "Left" and Enum.HorizontalAlignment.Left or (C.Alignment == "Right" and Enum.HorizontalAlignment.Right or Enum.HorizontalAlignment.Center);

        Library.NotificationArea.AnchorPoint        = Vector2.new(AnchorX, AnchorY);
        Library.NotificationArea.Position           = UDim2.new(C.PosX / 100, 0, C.PosY / 100, 0);
        Library.NotificationArea.ClipsDescendants   = C.ClipDescendants;
        Library.NotificationArea.AutomaticSize      = Enum.AutomaticSize.XY;

        local SizeConstraint = Library.NotificationArea:FindFirstChildOfClass('UISizeConstraint');
        if C.ClipDescendants then
            if not SizeConstraint then
                SizeConstraint = Library:Create('UISizeConstraint', { Parent = Library.NotificationArea });
            end;
            SizeConstraint.MaxSize = Vector2.new(math.huge, C.MaxHeight);
        elseif SizeConstraint then
            SizeConstraint:Destroy();
        end;

        local Layout = Library.NotificationArea:FindFirstChildOfClass('UIListLayout');
        if Layout then
            Layout.VerticalAlignment    = VAlign;
            Layout.HorizontalAlignment  = HAlign;
        end;
    end;

    Library:ConfigureNotifications({});

    -- Watermark pill: logo | brand | fps | ping | time
    local WatermarkOuter = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        AutomaticSize = Enum.AutomaticSize.X;
        Position = UDim2.new(0, 16, 0, -24);
        Size = UDim2.new(0, 0, 0, 26);
        ZIndex = 200;
        Visible = false;
        Parent = ScreenGui;
    });
    Library:Round(WatermarkOuter, 7);
    Library:Stroke(WatermarkOuter, 'OutlineColor');
    Library:AddToRegistry(WatermarkOuter, {
        BackgroundColor3 = 'MainColor';
    }, true);

    local WatermarkContent = Library:Create('Frame', {
        AutomaticSize = Enum.AutomaticSize.X;
        BackgroundTransparency = 1;
        Size = UDim2.new(0, 0, 1, 0);
        ZIndex = 201;
        Parent = WatermarkOuter;
    });
    Library:Create('UIListLayout', {
        FillDirection = Enum.FillDirection.Horizontal;
        Padding = UDim.new(0, 8);
        SortOrder = Enum.SortOrder.LayoutOrder;
        VerticalAlignment = Enum.VerticalAlignment.Center;
        Parent = WatermarkContent;
    });
    Library:Create('UIPadding', {
        PaddingLeft = UDim.new(0, 10);
        PaddingRight = UDim.new(0, 10);
        Parent = WatermarkContent;
    });

    local WatermarkLogo = Library:CreateLogo(WatermarkContent, 16, 202, true);
    WatermarkLogo.LayoutOrder = 1;

    local WatermarkLabel = Library:CreateLabel({
        AutomaticSize = Enum.AutomaticSize.X;
        Font = Enum.Font.GothamBold;
        LayoutOrder = 2;
        Size = UDim2.new(0, 0, 1, 0);
        Text = 'aster';
        TextColor3 = Color3.new(1, 1, 1);
        TextSize = Library.FontSize;
        TextXAlignment = Enum.TextXAlignment.Left;
        ZIndex = 203;
        Parent = WatermarkContent;
    }, true);
    Library:RemoveFromRegistry(WatermarkLabel);
    Library:AddGradient(Library:Create('UIGradient', { Parent = WatermarkLabel }), 'slide', true);

    Library.WatermarkStatLabels = {};
    Library.WatermarkDividers = {};
    for Index, Key in ipairs({ 'Fps', 'Ping', 'Time' }) do
        local Divider = Library:Create('Frame', {
            BackgroundColor3 = Library.OutlineColor;
            LayoutOrder = Index * 2 + 1;
            Size = UDim2.fromOffset(1, 12);
            ZIndex = 203;
            Parent = WatermarkContent;
        });
        Library:AddToRegistry(Divider, { BackgroundColor3 = 'OutlineColor' }, true);
        local Stat = Library:CreateLabel({
            Dim = true;
            AutomaticSize = Enum.AutomaticSize.X;
            LayoutOrder = Index * 2 + 2;
            Size = UDim2.new(0, 0, 1, 0);
            Text = Key == 'Fps' and '-- fps' or (Key == 'Ping' and '-- ms' or '--:--');
            TextSize = Library.FontSize - 1;
            ZIndex = 203;
            Parent = WatermarkContent;
        }, true);
        table.insert(Library.WatermarkDividers, Divider);
        Library.WatermarkStatLabels[Key] = Stat;
    end;

    local WatermarkLine = Library:Create('Frame', {
        BackgroundColor3 = Color3.new(1, 1, 1);
        BorderSizePixel = 0;
        Position = UDim2.new(0, 8, 1, -2);
        Size = UDim2.new(1, -16, 0, 2);
        ZIndex = 204;
        Parent = WatermarkOuter;
    });
    Library:Round(WatermarkLine, 1);
    Library:AddGradient(Library:Create('UIGradient', { Parent = WatermarkLine }), 'slide', true);

    Library.Watermark = WatermarkOuter;
    Library.WatermarkText = WatermarkLabel;
    Library.WatermarkStats = true;
    Library:MakeDraggable(Library.Watermark);

    -- Hotkeys panel
    local KeybindOuter = Library:Create('Frame', {
        AnchorPoint = Vector2.new(0, 0.5);
        BackgroundColor3 = Library.MainColor;
        Position = UDim2.new(0, 10, 0.5, 0);
        Size = UDim2.new(0, 210, 0, 36);
        Visible = false;
        ZIndex = 100;
        Parent = ScreenGui;
    });
    Library:Round(KeybindOuter, 7);
    Library:Stroke(KeybindOuter, 'OutlineColor');
    Library:AddToRegistry(KeybindOuter, {
        BackgroundColor3 = 'MainColor';
    }, true);

    local ColorFrame = Library:Create('Frame', {
        BackgroundColor3 = Color3.new(1, 1, 1);
        BorderSizePixel = 0;
        Position = UDim2.new(0, 8, 0, 0);
        Size = UDim2.new(1, -16, 0, 2);
        ZIndex = 102;
        Parent = KeybindOuter;
    });
    Library:Round(ColorFrame, 1);
    Library:AddGradient(Library:Create('UIGradient', { Parent = ColorFrame }), 'slide', true);
    Library.KeybindInner = KeybindOuter;
    Library.KeybindColorFrame = ColorFrame;

    local KeybindIcon = Library:Create('ImageLabel', {
        BackgroundTransparency = 1;
        ImageColor3 = Library.AccentColor;
        Position = UDim2.fromOffset(10, 8);
        Size = UDim2.fromOffset(14, 14);
        ZIndex = 104;
        Parent = KeybindOuter;
    });
    if Library:ApplyIcon(KeybindIcon, 'keyboard') then
        Library:AddToRegistry(KeybindIcon, { ImageColor3 = 'AccentColor' }, true);
    else
        KeybindIcon:Destroy();
    end;
    local KeybindLabel = Library:CreateLabel({
        Size = UDim2.new(1, -34, 0, 30);
        Position = UDim2.new(0, 30, 0, 0);
        TextXAlignment = Enum.TextXAlignment.Left,
        TextSize = Library.FontSize;
        Text = 'Hotkeys';
        ZIndex = 104;
        Parent = KeybindOuter;
    }, true);
    local KeybindContainer = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Size = UDim2.new(1, 0, 1, -30);
        Position = UDim2.new(0, 0, 0, 30);
        ZIndex = 1;
        Parent = KeybindOuter;
    });
    Library:Create('UIListLayout', {
        FillDirection = Enum.FillDirection.Vertical;
        SortOrder = Enum.SortOrder.LayoutOrder;
        Parent = KeybindContainer;
    });
    Library:Create('UIPadding', {
        PaddingLeft = UDim.new(0, 10),
        Parent = KeybindContainer,
    })

    Library.KeybindFrame = KeybindOuter;
    Library.KeybindContainer = KeybindContainer;
    Library:MakeDraggable(KeybindOuter);
end;

function Library:SetKeybindMode(Mode)
    assert(Mode == 'All' or Mode == 'Active' or Mode == 'Toggled',
        "SetKeybindMode: Mode must be 'All', 'Active', or 'Toggled'")
    Library.KeybindMode = Mode
    Library:RefreshKeybinds()
end

function Library:RefreshKeybinds()
    for _, kp in ipairs(Library.KeyPickerList) do
        if not kp.NoUI then
            pcall(function() kp:Update() end)
        end
    end
end

function Library:SetWatermarkVisibility(Bool)
    Library.Watermark.Visible = Bool;
end;

function Library:SetWatermarkStats(Bool)
    Library.WatermarkStats = not not Bool;
    for _, Divider in next, Library.WatermarkDividers do
        Divider.Visible = Library.WatermarkStats;
    end;
    for _, Stat in next, Library.WatermarkStatLabels do
        Stat.Visible = Library.WatermarkStats;
    end;
end;

function Library:SetWatermark(Text)
    Library.WatermarkText.Text = Text or 'aster';
    Library:SetWatermarkVisibility(true)
end;

function Library:Notify(Text, Time)
    if not Text or Text == "" then return end;
    table.insert(Library.NotifyQueue, { Text = Text, Time = Time });
    Library:ProcessNotifyQueue();
end;

function Library:ProcessNotifyQueue()
    local C = Library.NotifyConfig;
    local ItemHeight = 30 + 6;
    while #Library.NotifyQueue > 0 do
        if C.ClipDescendants and (Library.ActiveNotifyCount + 1) * ItemHeight > C.MaxHeight then break end;
        local Item = table.remove(Library.NotifyQueue, 1);
        Library:SpawnNotify(Item.Text, Item.Time);
    end;
end;

function Library:SpawnNotify(Text, Time)
    Time = Time or 5;
    local H = 30;
    local W = (Library:GetTextBounds(Text, Library.Font, Library.FontSize) or 200) + 44;
    local NotifyTransparency = math.min((Library.NotifyConfig.Transparency or 0) / 100, 0.35);
    Library.NotifyCounter = Library.NotifyCounter + 1;
    local Outer = Library:Create('Frame', {
        BackgroundTransparency  = 1;
        ClipsDescendants        = true;
        LayoutOrder             = Library.NotifyConfig.SortOrder == "Text Length" and #Text or Library.NotifyCounter;
        Size                    = UDim2.fromOffset(W, H);
        ZIndex                  = 100;
        Parent                  = Library.NotificationArea;
    });
    local Inner = Library:Create('Frame', {
        BackgroundColor3  = Library.MainColor;
        BackgroundTransparency = NotifyTransparency;
        Position          = UDim2.new(-1, -12, 0, 0);
        Size              = UDim2.new(1, 0, 1, 0);
        ZIndex            = 101;
        Parent            = Outer;
    });
    Library:Round(Inner, 6);
    Library:AddToRegistry(Inner, { BackgroundColor3 = 'MainColor' });
    local InnerStroke = Library:Stroke(Inner, 'OutlineColor', 1, NotifyTransparency);

    local Logo = Library:CreateLogo(Inner, 14, 103, true);
    Logo.Position = UDim2.fromOffset(10, 8);
    Library:CreateLabel({
        Position = UDim2.new(0, 32, 0, 0);
        Size = UDim2.new(1, -40, 1, 0);
        Text = Text;
        TextXAlignment = Enum.TextXAlignment.Left;
        TextSize = Library.FontSize;
        ZIndex = 103;
        Parent = Inner;
    });

    local BarSide = Library.NotifyConfig.BarSide or "Bottom";
    local BarPos, BarSize, BarEnd;
    if BarSide == "Top" then
        BarPos  = UDim2.new(0, 8, 0, 0);
        BarSize = UDim2.new(1, -16, 0, 2);
        BarEnd  = UDim2.new(0, 0, 0, 2);
    elseif BarSide == "Bottom" then
        BarPos  = UDim2.new(0, 8, 1, -2);
        BarSize = UDim2.new(1, -16, 0, 2);
        BarEnd  = UDim2.new(0, 0, 0, 2);
    elseif BarSide == "Left" then
        BarPos  = UDim2.new(0, 0, 0, 6);
        BarSize = UDim2.new(0, 2, 1, -12);
        BarEnd  = UDim2.new(0, 2, 0, 0);
    else
        BarPos  = UDim2.new(1, -2, 0, 6);
        BarSize = UDim2.new(0, 2, 1, -12);
        BarEnd  = UDim2.new(0, 2, 0, 0);
    end;
    local Bar = Library:Create('Frame', {
        BackgroundColor3  = Color3.new(1, 1, 1);
        Position          = BarPos;
        Size              = BarSize;
        ZIndex            = 104;
        Parent            = Inner;
    });
    Library:Round(Bar, 1);
    Library:AddGradient(Library:Create('UIGradient', { Parent = Bar }), 'slide', true);

    Library:Tween(Inner, { Position = UDim2.new(0, 0, 0, 0) }, 0.3, Enum.EasingStyle.Quint);
    Library:Tween(Bar, { Size = BarEnd }, Time, Enum.EasingStyle.Linear);
    Library.ActiveNotifyCount = Library.ActiveNotifyCount + 1;
    task.spawn(function()
        task.wait(Time);
        Library:Tween(Inner, { Position = UDim2.new(-1, -12, 0, 0) }, 0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.In);
        task.wait(0.25);
        Library:Tween(Outer, { Size = UDim2.fromOffset(W, 0) }, 0.12);
        task.wait(0.14);
        Outer:Destroy();
        Library.ActiveNotifyCount = Library.ActiveNotifyCount - 1;
        Library:ProcessNotifyQueue();
    end);
end;

function Library:CreateWindow(...)
    local Arguments = { ... }
    local Config = { AnchorPoint = Vector2.zero }

    if type(...) == 'table' then
        Config = ...;
    else
        Config.Title = Arguments[1]
        Config.AutoShow = Arguments[2] or false;
    end

    if type(Config.Title) ~= 'string' then Config.Title = 'Aster' end
    if type(Config.TabPadding) ~= 'number' then Config.TabPadding = 0 end
    if type(Config.MenuFadeTime) ~= 'number' then Config.MenuFadeTime = 0.2 end
    Library.MenuFadeTime = Config.MenuFadeTime;

    if type(Config.UseBlur) == 'boolean' then Library.UseBlur = Config.UseBlur end
    if type(Config.BlurSize) == 'number' then Library.BlurSize = Config.BlurSize end
    if type(Config.UseDarken) == 'boolean' then Library.UseDarken = Config.UseDarken end
    if type(Config.DarkenAmount) == 'number' then Library.DarkenAmount = Config.DarkenAmount end

    if typeof(Config.Size) ~= 'UDim2' then Config.Size = UDim2.fromOffset(740, 520) end
    if typeof(Config.Position) ~= 'UDim2' then Config.Position = UDim2.fromOffset(175, 50) end

    if InputService.TouchEnabled then
        local vp = Library.ScreenGui.AbsoluteSize
        local maxWidth = math.min(Config.Size.X.Offset, vp.X - 20)
      
        local maxHeight = math.min(Config.Size.Y.Offset, vp.Y - 60)
        Config.Size = UDim2.fromOffset(maxWidth, maxHeight)
    end

    if Config.Center then
        Config.AnchorPoint = Vector2.new(0.5, 0.5)
        Config.Position = UDim2.fromScale(0.5, 0.5)
    end

    local SIDEBAR_W = 56;
    local HEADER_H = 46;
    local TAB_BTN = 40;
    local TAB_STEP = 44;
    local TAB_TOP = 64;
    local TAB_BOTTOM = 10;

    local Window = {
        Tabs = {};
        TabList = {};
    };

    local Outer = Library:Create('Frame', {
        AnchorPoint = Config.AnchorPoint,
        BackgroundTransparency = 1;
        Position = Config.Position,
        Size = Config.Size,
        Visible = false;
        ZIndex = 1;
        Parent = ScreenGui;
    });
    Library:MakeDraggable(Outer, HEADER_H, true);

    local WindowScale = Library:Create('UIScale', { Scale = 1; Parent = Outer });
    local Shadow = Library:Create('ImageLabel', {
        BackgroundTransparency = 1;
        Image = 'rbxassetid://6014261993';
        ImageColor3 = Color3.new(0, 0, 0);
        ImageTransparency = 0.45;
        Position = UDim2.fromOffset(-20, -16);
        ScaleType = Enum.ScaleType.Slice;
        SliceCenter = Rect.new(49, 49, 450, 450);
        Size = UDim2.new(1, 40, 1, 40);
        ZIndex = 1;
        Parent = Outer;
    });

    local Inner = Library:Create('Frame', {
        Name = "Inner",
        BackgroundColor3 = Library.BackgroundColor;
        Size = UDim2.new(1, 0, 1, 0);
        ZIndex = 2;
        Parent = Outer;
    });
    Library:Round(Inner, 8);
    Library:AddToRegistry(Inner, {
        BackgroundColor3 = 'BackgroundColor';
    });
    local BorderStroke = Library:Create('UIStroke', {
        Color = Color3.new(1, 1, 1);
        Thickness = 1;
        Transparency = 0.45;
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border;
        Parent = Inner;
    });
    Library:AddGradient(Library:Create('UIGradient', { Parent = BorderStroke }), 'spin', true);

    local TopLine = Library:Create('Frame', {
        AnchorPoint = Vector2.new(0.5, 0);
        BackgroundColor3 = Color3.new(1, 1, 1);
        Position = UDim2.new(0.5, 0, 0, 0);
        Size = UDim2.new(1, -40, 0, 2);
        ZIndex = 12;
        Parent = Inner;
    });
    Library:Round(TopLine, 1);
    local TopLineGradient = Library:Create('UIGradient', {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.15, 0),
            NumberSequenceKeypoint.new(0.85, 0),
            NumberSequenceKeypoint.new(1, 1),
        });
        Parent = TopLine;
    });
    Library:AddGradient(TopLineGradient, 'slide');

    -- Sidebar
    local Sidebar = Library:Create('Frame', {
        Name = 'Sidebar';
        BackgroundColor3 = Library:GetSidebarColor();
        Size = UDim2.new(0, SIDEBAR_W, 1, 0);
        ZIndex = 3;
        Parent = Inner;
    });
    Library:Round(Sidebar, 8);
    Library:AddToRegistry(Sidebar, {
        BackgroundColor3 = function() return Library:GetSidebarColor() end;
    });
    local SidebarFill = Library:Create('Frame', {
        BackgroundColor3 = Library:GetSidebarColor();
        Position = UDim2.new(1, -8, 0, 0);
        Size = UDim2.new(0, 8, 1, 0);
        ZIndex = 3;
        Parent = Sidebar;
    });
    Library:AddToRegistry(SidebarFill, {
        BackgroundColor3 = function() return Library:GetSidebarColor() end;
    });
    local SidebarEdge = Library:Create('Frame', {
        BackgroundColor3 = Library.OutlineColor;
        Position = UDim2.new(1, -1, 0, 0);
        Size = UDim2.new(0, 1, 1, 0);
        ZIndex = 4;
        Parent = Sidebar;
    });
    Library:AddToRegistry(SidebarEdge, { BackgroundColor3 = 'OutlineColor' });

    local LogoGlow = Library:Create('ImageLabel', {
        AnchorPoint = Vector2.new(0.5, 0.5);
        BackgroundTransparency = 1;
        Image = 'rbxassetid://6014261993';
        ImageColor3 = Library.AccentColor;
        ImageTransparency = 0.75;
        Position = UDim2.new(0.5, 0, 0, 30);
        ScaleType = Enum.ScaleType.Slice;
        SliceCenter = Rect.new(49, 49, 450, 450);
        Size = UDim2.fromOffset(52, 52);
        ZIndex = 4;
        Parent = Sidebar;
    });
    Library:AddToRegistry(LogoGlow, { ImageColor3 = 'AccentColor' });
    Library.Glows[LogoGlow] = true;

    local SidebarLogo = Library:CreateLogo(Sidebar, 28, 5, true);
    SidebarLogo.AnchorPoint = Vector2.new(0.5, 0.5);
    SidebarLogo.Position = UDim2.new(0.5, 0, 0, 30);
    Library.SidebarLogo = SidebarLogo;

    local TabArea = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Position = UDim2.new(0, 0, 0, TAB_TOP);
        Size = UDim2.new(1, 0, 1, -TAB_TOP);
        ZIndex = 4;
        Parent = Sidebar;
    });
    local TabListLayout = Library:Create('UIListLayout', {
        Padding = UDim.new(0, TAB_STEP - TAB_BTN);
        FillDirection = Enum.FillDirection.Vertical;
        HorizontalAlignment = Enum.HorizontalAlignment.Center;
        SortOrder = Enum.SortOrder.LayoutOrder;
        Parent = TabArea;
    });
    local BottomArea = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Size = UDim2.new(1, 0, 1, -TAB_BOTTOM);
        ZIndex = 4;
        Parent = Sidebar;
    });
    Library:Create('UIListLayout', {
        Padding = UDim.new(0, TAB_STEP - TAB_BTN);
        FillDirection = Enum.FillDirection.Vertical;
        HorizontalAlignment = Enum.HorizontalAlignment.Center;
        SortOrder = Enum.SortOrder.LayoutOrder;
        VerticalAlignment = Enum.VerticalAlignment.Bottom;
        Parent = BottomArea;
    });

    local Indicator = Library:Create('Frame', {
        AnchorPoint = Vector2.new(0, 0.5);
        BackgroundColor3 = Color3.new(1, 1, 1);
        Position = UDim2.new(0, 0, 0, TAB_TOP + TAB_BTN / 2);
        Size = UDim2.fromOffset(3, 22);
        Visible = false;
        ZIndex = 8;
        Parent = Inner;
    });
    Library:Round(Indicator, 2);
    Library:AddGradient(Library:Create('UIGradient', { Parent = Indicator; Rotation = 90 }), 'slide', false, 'Y');

    local TabTip = Library:Create('Frame', {
        AnchorPoint = Vector2.new(0, 0.5);
        BackgroundColor3 = Library.MainColor;
        Size = UDim2.fromOffset(60, 24);
        Visible = false;
        ZIndex = 60;
        Parent = Inner;
    });
    Library:Round(TabTip, 5);
    Library:Stroke(TabTip, 'OutlineColor');
    Library:AddToRegistry(TabTip, { BackgroundColor3 = 'MainColor' });
    local TabTipLabel = Library:CreateLabel({
        Size = UDim2.new(1, 0, 1, 0);
        TextSize = Library.FontSize - 1;
        Text = '';
        ZIndex = 61;
        Parent = TabTip;
    });

    -- Header
    local Header = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Position = UDim2.new(0, SIDEBAR_W, 0, 0);
        Size = UDim2.new(1, -SIDEBAR_W, 0, HEADER_H);
        ZIndex = 3;
        Parent = Inner;
    });
    local HeaderLeft = Library:Create('Frame', {
        AutomaticSize = Enum.AutomaticSize.X;
        BackgroundTransparency = 1;
        Position = UDim2.new(0, 18, 0, 0);
        Size = UDim2.new(0, 0, 1, 0);
        ZIndex = 4;
        Parent = Header;
    });
    Library:Create('UIListLayout', {
        FillDirection = Enum.FillDirection.Horizontal;
        Padding = UDim.new(0, 8);
        SortOrder = Enum.SortOrder.LayoutOrder;
        VerticalAlignment = Enum.VerticalAlignment.Center;
        Parent = HeaderLeft;
    });
    local WindowLabel = Library:Create('TextLabel', {
        AutomaticSize = Enum.AutomaticSize.X;
        BackgroundTransparency = 1;
        Font = Enum.Font.GothamBold;
        LayoutOrder = 1;
        RichText = true;
        Size = UDim2.new(0, 0, 1, 0);
        Text = Config.Title or '';
        TextColor3 = Color3.new(1, 1, 1);
        TextSize = Library.FontSize + 4;
        ZIndex = 4;
        Parent = HeaderLeft;
    });
    Library:AddGradient(Library:Create('UIGradient', { Parent = WindowLabel }), 'slide');
    Library:CreateLabel({
        Dim = true;
        AutomaticSize = Enum.AutomaticSize.X;
        LayoutOrder = 2;
        Size = UDim2.new(0, 0, 1, 0);
        Text = '/';
        TextSize = Library.FontSize + 2;
        ZIndex = 4;
        Parent = HeaderLeft;
    });
    local TabTitleLabel = Library:CreateLabel({
        Dim = true;
        AutomaticSize = Enum.AutomaticSize.X;
        LayoutOrder = 3;
        Size = UDim2.new(0, 0, 1, 0);
        Text = '';
        TextSize = Library.FontSize + 1;
        ZIndex = 4;
        Parent = HeaderLeft;
    });
    local HeaderLine = Library:Create('Frame', {
        BackgroundColor3 = Library.OutlineColor;
        Position = UDim2.new(0, 16, 1, -1);
        Size = UDim2.new(1, -32, 0, 1);
        ZIndex = 4;
        Parent = Header;
    });
    Library:AddToRegistry(HeaderLine, { BackgroundColor3 = 'OutlineColor' });

    local SearchHolder = Library:Create('Frame', {
        AnchorPoint = Vector2.new(1, 0.5);
        BackgroundColor3 = Library:GetSidebarColor();
        Position = UDim2.new(1, -16, 0.5, -1);
        Size = UDim2.fromOffset(170, 28);
        ZIndex = 5;
        Parent = Header;
    });
    Library:Round(SearchHolder, 6);
    local SearchStroke = Library:Stroke(SearchHolder, 'OutlineColor');
    Library:AddToRegistry(SearchHolder, {
        BackgroundColor3 = function() return Library:GetSidebarColor() end;
    });
    local SearchIcon = Library:Create('ImageLabel', {
        AnchorPoint = Vector2.new(0, 0.5);
        BackgroundTransparency = 1;
        ImageColor3 = Library:GetDimColor();
        Position = UDim2.new(0, 9, 0.5, 0);
        Size = UDim2.fromOffset(14, 14);
        ZIndex = 6;
        Parent = SearchHolder;
    });
    if Library:ApplyIcon(SearchIcon, 'search') then
        Library:AddToRegistry(SearchIcon, { ImageColor3 = function() return Library:GetDimColor() end });
    else
        SearchIcon:Destroy();
    end;
    local SearchBox = Library:Create('TextBox', {
        BackgroundTransparency = 1;
        ClearTextOnFocus = false;
        Font = Library.Font;
        PlaceholderColor3 = Library:GetDimColor();
        PlaceholderText = 'Search...';
        Position = UDim2.new(0, 30, 0, 0);
        Size = UDim2.new(1, -38, 1, 0);
        Text = '';
        TextColor3 = Library.FontColor;
        TextSize = Library.FontSize;
        TextXAlignment = Enum.TextXAlignment.Left;
        ZIndex = 6;
        Parent = SearchHolder;
    });
    Library:AddToRegistry(SearchBox, {
        TextColor3 = 'FontColor';
        PlaceholderColor3 = function() return Library:GetDimColor() end;
    });
    SearchBox.Focused:Connect(function()
        Library:Tween(SearchStroke, { Color = Library.AccentColor }, 0.12);
        Library:Tween(SearchHolder, { Size = UDim2.fromOffset(210, 28) }, 0.18, Enum.EasingStyle.Quint);
    end);
    SearchBox.FocusLost:Connect(function()
        Library:Tween(SearchStroke, { Color = Library.OutlineColor }, 0.12);
        if SearchBox.Text == '' then
            Library:Tween(SearchHolder, { Size = UDim2.fromOffset(170, 28) }, 0.18, Enum.EasingStyle.Quint);
        end;
    end);
    SearchBox:GetPropertyChangedSignal('Text'):Connect(function()
        Library:ApplySearch(SearchBox.Text);
    end);

    -- Content
    local MainSectionInner = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Position = UDim2.new(0, SIDEBAR_W, 0, HEADER_H);
        Size = UDim2.new(1, -SIDEBAR_W, 1, -HEADER_H);
        ZIndex = 2;
        Parent = Inner;
    });
    local TabContainer = Library:Create('Frame', {
        BackgroundTransparency = 1;
        ClipsDescendants = true;
        Position = UDim2.new(0, 14, 0, 12);
        Size = UDim2.new(1, -28, 1, -24);
        ZIndex = 2;
        Parent = MainSectionInner;
    });
    local ContentVeil = Library:Create('Frame', {
        BackgroundColor3 = Library.BackgroundColor;
        BackgroundTransparency = 1;
        Position = UDim2.new(0, 14, 0, 12);
        Size = UDim2.new(1, -28, 1, -24);
        Visible = false;
        ZIndex = 12;
        Parent = MainSectionInner;
    });
    Library:AddToRegistry(ContentVeil, { BackgroundColor3 = 'BackgroundColor' });

    -- Window-wide fade veil for open/close
    local Veil = Library:Create('Frame', {
        BackgroundColor3 = Library.BackgroundColor;
        BackgroundTransparency = 1;
        Size = UDim2.new(1, 0, 1, 0);
        Visible = false;
        ZIndex = 500;
        Parent = Outer;
    });
    Library:Round(Veil, 8);
    Library:AddToRegistry(Veil, { BackgroundColor3 = 'BackgroundColor' });

    -- Resize grip (a diagonal triangle drawn with a hard-stop gradient)
    local CornerCircle = Library:Create('Frame', {
        AnchorPoint      = Vector2.new(1, 1);
        BackgroundColor3 = Library.OutlineColor;
        Position         = UDim2.new(1, -3, 1, -3);
        Size             = UDim2.fromOffset(12, 12);
        ZIndex           = 100;
        Active           = true;
        Parent           = Outer;
    });
    Library:Create('UIGradient', {
        Rotation = 45;
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.5, 1),
            NumberSequenceKeypoint.new(0.51, 0),
            NumberSequenceKeypoint.new(1, 0),
        });
        Parent = CornerCircle;
    });
    Library:AddToRegistry(CornerCircle, {
        BackgroundColor3 = 'OutlineColor';
    });

    do
        local MinW = 560;
        local MinH = 380;

        local Resizing = false;
        local ResizeConn, EndConn;
        local StartSize, DragStart, DragType;
        local HasMoved = false;
        local Wireframe;

        local function StopResize()
            Resizing = false;
            if ResizeConn then ResizeConn:Disconnect(); ResizeConn = nil; end
            if EndConn then EndConn:Disconnect(); EndConn = nil; end
        end;

        local function StartResize(Position, FromType)
            if Resizing then return; end
            StopResize();

            Resizing = true;
            StartSize = Outer.Size;
            DragStart = Position;
            DragType = FromType;
            HasMoved = false;
            if Wireframe then Wireframe:Destroy(); Wireframe = nil; end

            ResizeConn = InputService.InputChanged:Connect(function(Change)
                local T = Change.UserInputType;
                if T ~= Enum.UserInputType.MouseMovement and T ~= Enum.UserInputType.Touch then return; end
                if DragType ~= Enum.UserInputType.Touch and T == Enum.UserInputType.Touch then return; end

                local Delta = Change.Position - DragStart;
                if not HasMoved and Delta.Magnitude <= 2 then return; end

                local TopLeft = Outer.AbsolutePosition;
                local VPSize = Library.ScreenGui.AbsoluteSize;

                local NewW = math.clamp(StartSize.X.Offset + Delta.X, MinW, VPSize.X - TopLeft.X);
                local NewH = math.clamp(StartSize.Y.Offset + Delta.Y, MinH, VPSize.Y - TopLeft.Y);

                if Library.WireframeDrag then
                    if not HasMoved then
                        HasMoved = true;

                        Wireframe = Library:Create('Frame', {
                            Size = UDim2.fromOffset(NewW, NewH);
                            Position = UDim2.fromOffset(TopLeft.X, TopLeft.Y);
                            BackgroundTransparency = 1;
                            Active = false;
                            ZIndex = 100000;
                            Parent = ScreenGui;
                        });
                        Library:Round(Wireframe, 8);

                        Library:Create('UIStroke', {
                            Color = Library.AccentColor;
                            Thickness = 1;
                            ApplyStrokeMode = Enum.ApplyStrokeMode.Border;
                            Parent = Wireframe;
                        });
                    end;

                    if HasMoved and Wireframe then
                        Wireframe.Position = UDim2.fromOffset(TopLeft.X, TopLeft.Y);
                        Wireframe.Size = UDim2.fromOffset(NewW, NewH);
                    end;
                else
                    HasMoved = true;
                    Outer.Size = UDim2.fromOffset(NewW, NewH);
                end;
            end);

            EndConn = InputService.InputEnded:Connect(function(EndInput)
                if EndInput.UserInputType == DragType then
                    if Library.WireframeDrag and HasMoved and Wireframe then
                        Outer.Size = Wireframe.Size;
                        Wireframe:Destroy();
                        Wireframe = nil;
                    end;
                    StopResize();
                end;
            end);
        end;

        local function OnHandlePressed(Position, InputType)
            StartResize(Position, InputType);
        end;

        CornerCircle.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                OnHandlePressed(Input.Position, Input.UserInputType);
            end;
        end);

        Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
            if Input.UserInputType ~= Enum.UserInputType.MouseButton1 and Input.UserInputType ~= Enum.UserInputType.Touch then return; end
            if Resizing or not Library.Toggled then return; end

            local WindowPos = Outer.AbsolutePosition;
            local WindowSize = Outer.AbsoluteSize;
            local CenterX = WindowPos.X + WindowSize.X;
            local CenterY = WindowPos.Y + WindowSize.Y;
            local P = Input.Position;
            local Rad = 26;
            local DX = CenterX - P.X;
            local DY = CenterY - P.Y;

            if (DX * DX) + (DY * DY) <= (Rad * Rad) then
                OnHandlePressed(P, Input.UserInputType);
            end;
        end));
        Library:GiveSignal(function() StopResize(); end);
    end;

    function Window:SetWindowTitle(Title)
        WindowLabel.Text = Title;
    end;

    -- Y position (in window space) of a tab's button centre; used by the indicator and tooltip
    local function TabPosition(Tab)
        local Same = {};
        for _, T in ipairs(Window.TabList) do
            if T.Bottom == Tab.Bottom then
                table.insert(Same, T);
            end;
        end;
        table.sort(Same, function(A, B)
            if A.LayoutOrder ~= B.LayoutOrder then return A.LayoutOrder < B.LayoutOrder end;
            return A.Seq < B.Seq;
        end);
        local Idx = table.find(Same, Tab) or 1;
        if Tab.Bottom then
            return UDim2.new(0, 0, 1, -(TAB_BOTTOM + TAB_BTN / 2 + (#Same - Idx) * TAB_STEP));
        end;
        return UDim2.new(0, 0, 0, TAB_TOP + TAB_BTN / 2 + (Idx - 1) * TAB_STEP);
    end;

    local function MoveIndicator(Tab, Instant)
        local Pos = TabPosition(Tab);
        Indicator.Visible = true;
        if Instant then
            Indicator.Position = Pos;
        else
            Library:Tween(Indicator, { Position = Pos }, 0.28, Enum.EasingStyle.Quint);
        end;
    end;

    function Window:AddTab(Name, Icon, Opts)
        Opts = type(Opts) == 'table' and Opts or {};
        local Tab = {
            Groupboxes = {};
            Tabboxes = {};
            Name = Name;
            Active = false;
            Seq = #Window.TabList + 1;
            LayoutOrder = #Window.TabList + 1;
        };
        if Opts.Bottom ~= nil then
            Tab.Bottom = not not Opts.Bottom;
        else
            Tab.Bottom = type(Icon) == 'string' and Icon:lower() == 'settings';
        end;
        table.insert(Window.TabList, Tab);

        local TabButton = Library:Create('Frame', {
            BackgroundColor3 = Library.OutlineColor;
            BackgroundTransparency = 1;
            LayoutOrder = Tab.LayoutOrder;
            Size = UDim2.fromOffset(TAB_BTN, TAB_BTN);
            ZIndex = 5;
            Parent = Tab.Bottom and BottomArea or TabArea;
        });
        Library:Round(TabButton, 8);
        Library:AddToRegistry(TabButton, { BackgroundColor3 = 'OutlineColor' });

        local IconInst, IconProp = Library:CreateTabIcon(TabButton, Icon, Name, 6);
        local function IconColor()
            return Tab.Active and Library.AccentColor or Library:GetDimColor();
        end;
        IconInst[IconProp] = IconColor();
        Library:AddToRegistry(IconInst, { [IconProp] = IconColor });

        local TabFrame = Library:Create('Frame', {
            Name = 'TabFrame',
            BackgroundTransparency = 1;
            Position = UDim2.new(0, 0, 0, 0);
            Size = UDim2.new(1, 0, 1, 0);
            Visible = false;
            ZIndex = 2;
            Parent = TabContainer;
        });
        local function MakeSide(Position, Size)
            local Side = Library:Create('ScrollingFrame', {
                BackgroundTransparency = 1;
                BorderSizePixel = 0;
                Position = Position;
                Size = Size;
                CanvasSize = UDim2.new(0, 0, 0, 0);
                BottomImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png';
                TopImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png';
                MidImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png';
                ScrollBarThickness = 2;
                ScrollBarImageColor3 = Library.OutlineColor;
                ZIndex = 2;
                Parent = TabFrame;
            });
            Library:AddToRegistry(Side, { ScrollBarImageColor3 = 'OutlineColor' });
            Library:Create('UIPadding', { PaddingRight = UDim.new(0, 5); Parent = Side });
            local Layout = Library:Create('UIListLayout', {
                Padding = UDim.new(0, 10);
                FillDirection = Enum.FillDirection.Vertical;
                SortOrder = Enum.SortOrder.LayoutOrder;
                HorizontalAlignment = Enum.HorizontalAlignment.Center;
                Parent = Side;
            });
            Layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
                Side.CanvasSize = UDim2.fromOffset(0, Layout.AbsoluteContentSize.Y + 2);
            end);
            return Side;
        end;
        local LeftSide = MakeSide(UDim2.new(0, 0, 0, 0), UDim2.new(0.5, -5, 1, 0));
        local RightSide = MakeSide(UDim2.new(0.5, 5, 0, 0), UDim2.new(0.5, -5, 1, 0));

        function Tab:ShowTab()
            if Window.ActiveTab == Tab then return; end;
            for _, Other in ipairs(Window.TabList) do
                if Other ~= Tab then
                    Other:HideTab();
                end;
            end;

            local First = Window.ActiveTab == nil;
            Window.ActiveTab = Tab;
            Tab.Active = true;
            TabTitleLabel.Text = Name;
            if SearchBox.Text ~= '' then
                SearchBox.Text = '';
            end;

            TabFrame.Visible = true;
            Library:Tween(TabButton, { BackgroundTransparency = 0 }, 0.15);
            Library:Tween(IconInst, { [IconProp] = Library.AccentColor }, 0.15);
            MoveIndicator(Tab, First);

            if not First then
                TabFrame.Position = UDim2.fromOffset(0, 12);
                Library:Tween(TabFrame, { Position = UDim2.fromOffset(0, 0) }, 0.22, Enum.EasingStyle.Quint);
                ContentVeil.Visible = true;
                ContentVeil.BackgroundTransparency = 0.55;
                Library:Tween(ContentVeil, { BackgroundTransparency = 1 }, 0.2);
                task.delay(0.22, function()
                    if Window.ActiveTab == Tab then
                        ContentVeil.Visible = false;
                    end;
                end);
            end;
        end;
        function Tab:HideTab()
            if not Tab.Active then return; end;
            Tab.Active = false;
            TabFrame.Visible = false;
            Library:Tween(TabButton, { BackgroundTransparency = 1 }, 0.15);
            Library:Tween(IconInst, { [IconProp] = Library:GetDimColor() }, 0.15);
        end;
        function Tab:SetLayoutOrder(Position)
            Tab.LayoutOrder = Position;
            TabButton.LayoutOrder = Position;
            if Window.ActiveTab then
                MoveIndicator(Window.ActiveTab, true);
            end;
        end;

        function Tab:AddGroupbox(Info)
            local Groupbox = {};
            local BoxOuter = Library:Create('Frame', {
                BackgroundColor3 = Library.MainColor;
                Size = UDim2.new(1, 0, 0, 100);
                ZIndex = 2;
                Parent = Info.Side == 1 and LeftSide or RightSide;
            });
            Library:Round(BoxOuter, 6);
            Library:Stroke(BoxOuter, 'OutlineColor');
            Library:AddToRegistry(BoxOuter, {
                BackgroundColor3 = 'MainColor';
            });

            local TitleX = 12;
            local GroupIcon = Info.Icon and Library:GetIcon(Info.Icon);
            if GroupIcon then
                local GroupIconInst = Library:Create('ImageLabel', {
                    BackgroundTransparency = 1;
                    ImageColor3 = Library:GetDimColor();
                    Position = UDim2.fromOffset(12, 7);
                    Size = UDim2.fromOffset(14, 14);
                    ZIndex = 5;
                    Parent = BoxOuter;
                });
                Library:ApplyIcon(GroupIconInst, Info.Icon);
                Library:AddToRegistry(GroupIconInst, { ImageColor3 = function() return Library:GetDimColor() end });
                TitleX = 32;
            end;
            local GroupboxLabel = Library:CreateLabel({
                Dim = true;
                Size = UDim2.new(1, -TitleX - 8, 0, 28);
                Position = UDim2.new(0, TitleX, 0, 0);
                TextSize = Library.FontSize - 1;
                Text = Info.Name;
                TextXAlignment = Enum.TextXAlignment.Left;
                ZIndex = 5;
                Parent = BoxOuter;
            });
            local TitleLine = Library:Create('Frame', {
                BackgroundColor3 = Library.OutlineColor;
                Position = UDim2.new(0, 0, 0, 28);
                Size = UDim2.new(1, 0, 0, 1);
                ZIndex = 5;
                Parent = BoxOuter;
            });
            Library:AddToRegistry(TitleLine, { BackgroundColor3 = 'OutlineColor' });
            local Container = Library:Create('Frame', {
                BackgroundTransparency = 1;
                Position = UDim2.new(0, 12, 0, 36);
                Size = UDim2.new(1, -24, 1, -36);
                ZIndex = 1;
                Parent = BoxOuter;
            });
            Library:Create('UIListLayout', {
                FillDirection = Enum.FillDirection.Vertical;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = Container;
            });
            function Groupbox:Resize()
                local Size = 0;
                for _, Element in next, Groupbox.Container:GetChildren() do
                    if (not Element:IsA('UIListLayout')) and Element.Visible then
                        Size = Size + Element.Size.Y.Offset;
                    end;
                end;

                BoxOuter.Size = UDim2.new(1, 0, 0, 36 + Size + 6);
            end;

            Groupbox.Container = Container;
            Groupbox.Outer = BoxOuter;
            Groupbox.Title = Info.Name;
            setmetatable(Groupbox, BaseGroupbox);
            Groupbox:AddBlank(3);
            Groupbox:Resize();

            Tab.Groupboxes[Info.Name] = Groupbox;

            return Groupbox;
        end;

        function Tab:AddLeftGroupbox(Name, Icon)
            return Tab:AddGroupbox({ Side = 1; Name = Name; Icon = Icon; });
        end;

        function Tab:AddRightGroupbox(Name, Icon)
            return Tab:AddGroupbox({ Side = 2; Name = Name; Icon = Icon; });
        end;

        function Tab:AddTabbox(Info)
            local Tabbox = {
                Tabs = {};
            };

            local BoxOuter = Library:Create('Frame', {
                BackgroundColor3 = Library.MainColor;
                Size = UDim2.new(1, 0, 0, 0);
                ZIndex = 2;
                Parent = Info.Side == 1 and LeftSide or RightSide;
            });
            Library:Round(BoxOuter, 6);
            Library:Stroke(BoxOuter, 'OutlineColor');
            Library:AddToRegistry(BoxOuter, {
                BackgroundColor3 = 'MainColor';
            });
            local TabboxButtons = Library:Create('Frame', {
                BackgroundTransparency = 1;
                Position = UDim2.new(0, 0, 0, 0);
                Size = UDim2.new(1, 0, 0, 28);
                ZIndex = 5;
                Parent = BoxOuter;
            });
            Library:Create('UIListLayout', {
                FillDirection = Enum.FillDirection.Horizontal;
                HorizontalAlignment = Enum.HorizontalAlignment.Left;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = TabboxButtons;
            });
            local TabboxLine = Library:Create('Frame', {
                BackgroundColor3 = Library.OutlineColor;
                Position = UDim2.new(0, 0, 0, 28);
                Size = UDim2.new(1, 0, 0, 1);
                ZIndex = 5;
                Parent = BoxOuter;
            });
            Library:AddToRegistry(TabboxLine, { BackgroundColor3 = 'OutlineColor' });
            Tabbox.Outer = BoxOuter;

            function Tabbox:AddTab(Name)
                local Tab = {};
                local Button = Library:Create('Frame', {
                    BackgroundTransparency = 1;
                    Size = UDim2.new(0.5, 0, 1, 0);
                    ZIndex = 6;
                    Parent = TabboxButtons;
                });
                local TabHighlight = Library:Create('Frame', {
                    AnchorPoint = Vector2.new(0.5, 1);
                    BackgroundColor3 = Color3.new(1, 1, 1);
                    Position = UDim2.new(0.5, 0, 1, 0);
                    Size = UDim2.new(1, -16, 0, 2);
                    Visible = false;
                    ZIndex = 10;
                    Parent = Button;
                });
                Library:Round(TabHighlight, 1);
                Library:AddGradient(Library:Create('UIGradient', { Parent = TabHighlight }), 'slide');
                local ButtonLabel = Library:CreateLabel({
                    Dim = true;
                    Size = UDim2.new(1, 0, 1, 0);
                    TextSize = Library.FontSize;
                    Text = Name;
                    TextXAlignment = Enum.TextXAlignment.Center;
                    ZIndex = 7;
                    Parent = Button;
                });
                local Container = Library:Create('Frame', {
                    BackgroundTransparency = 1;
                    Position = UDim2.new(0, 12, 0, 36);
                    Size = UDim2.new(1, -24, 1, -36);
                    ZIndex = 1;
                    Visible = false;
                    Parent = BoxOuter;
                });
                Library:Create('UIListLayout', {
                    FillDirection = Enum.FillDirection.Vertical;
                    SortOrder = Enum.SortOrder.LayoutOrder;
                    Parent = Container;
                });
                function Tab:Show()
                    for _, Tab in next, Tabbox.Tabs do
                        Tab:Hide();
                    end;

                    Container.Visible = true;
                    TabHighlight.Visible = true;

                    ButtonLabel.TextColor3 = Library.FontColor;
                    Library.RegistryMap[ButtonLabel].Properties.TextColor3 = 'FontColor';

                    Tab:Resize();
                end;
                function Tab:Hide()
                    Container.Visible = false;
                    TabHighlight.Visible = false;

                    ButtonLabel.TextColor3 = Library:GetDimColor();
                    Library.RegistryMap[ButtonLabel].Properties.TextColor3 = function() return Library:GetDimColor() end;
                end;
                function Tab:Resize()
                    local TabCount = 0;
                    for _, Tab in next, Tabbox.Tabs do
                        TabCount = TabCount + 1;
                    end;

                    for _, Button in next, TabboxButtons:GetChildren() do
                        if not Button:IsA('UIListLayout') then
                            Button.Size = UDim2.new(1 / TabCount, 0, 1, 0);
                        end;
                    end;

                    if (not Container.Visible) then
                        return;
                    end;

                    local Size = 0;

                    for _, Element in next, Tab.Container:GetChildren() do
                        if (not Element:IsA('UIListLayout')) and Element.Visible then
                            Size = Size + Element.Size.Y.Offset;
                        end;
                    end;

                    BoxOuter.Size = UDim2.new(1, 0, 0, 36 + Size + 6);
                end;
                Button.InputBegan:Connect(function(Input)
                    if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) and not Library:MouseIsOverOpenedFrame() then
                        Tab:Show();
                        Tab:Resize();
                    end;
                end);

                Tab.Container = Container;
                Tabbox.Tabs[Name] = Tab;

                setmetatable(Tab, BaseGroupbox);

                Tab:AddBlank(3);
                Tab:Resize();

                if #TabboxButtons:GetChildren() == 2 then
                    Tab:Show();
                else
                    ButtonLabel.TextColor3 = Library:GetDimColor();
                    Library.RegistryMap[ButtonLabel].Properties.TextColor3 = function() return Library:GetDimColor() end;
                end;

                return Tab;
            end;

            Tab.Tabboxes[Info.Name or ''] = Tabbox;

            return Tabbox;
        end;
        function Tab:AddLeftTabbox(Name)
            return Tab:AddTabbox({ Name = Name, Side = 1; });
        end;

        function Tab:AddRightTabbox(Name)
            return Tab:AddTabbox({ Name = Name, Side = 2; });
        end;

        TabButton.InputBegan:Connect(function(Input)
            if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) then
                Tab:ShowTab();
            end;
        end);
        TabButton.MouseEnter:Connect(function()
            if not Tab.Active then
                Library:Tween(TabButton, { BackgroundTransparency = 0.6 }, 0.12);
            end;
            local Pos = TabPosition(Tab);
            TabTipLabel.Text = Name;
            TabTip.Size = UDim2.fromOffset((Library:GetTextBounds(Name, Library.Font, Library.FontSize - 1) or 40) + 20, 24);
            TabTip.Position = UDim2.new(0, SIDEBAR_W + 2, Pos.Y.Scale, Pos.Y.Offset);
            TabTip.Visible = true;
            Library:Tween(TabTip, { Position = UDim2.new(0, SIDEBAR_W + 8, Pos.Y.Scale, Pos.Y.Offset) }, 0.14);
        end);
        TabButton.MouseLeave:Connect(function()
            if not Tab.Active then
                Library:Tween(TabButton, { BackgroundTransparency = 1 }, 0.12);
            end;
            TabTip.Visible = false;
        end);

        Window.Tabs[Name] = Tab;
        if Window.ActiveTab then
            MoveIndicator(Window.ActiveTab, true);
        else
            Tab:ShowTab();
        end;
        return Tab;
    end;

    local ModalElement = Library:Create('TextButton', {
        BackgroundTransparency = 1;
        Size = UDim2.new(0, 0, 0, 0);
        Visible = true;
        Text = '';
        Modal = false;
        Parent = ScreenGui;
    });
    function Library:Toggle()
        Library.Toggled = not Library.Toggled;
        ModalElement.Modal = Library.Toggled;
        Library.ToggleToken = (Library.ToggleToken or 0) + 1;
        local Token = Library.ToggleToken;
        local Fade = Library.MenuFadeTime or 0.2;

        if Library.Toggled then
            Outer.Visible = true;
            WindowScale.Scale = 0.95;
            Veil.Visible = true;
            Veil.BackgroundTransparency = 0;
            Shadow.ImageTransparency = 1;
            Library:Tween(WindowScale, { Scale = 1 }, Fade, Enum.EasingStyle.Quint);
            Library:Tween(Veil, { BackgroundTransparency = 1 }, Fade);
            Library:Tween(Shadow, { ImageTransparency = 0.45 }, Fade);
            task.delay(Fade + 0.02, function()
                if Token == Library.ToggleToken then
                    Veil.Visible = false;
                end;
            end);
        else
            Veil.Visible = true;
            Library:Tween(WindowScale, { Scale = 0.96 }, Fade, Enum.EasingStyle.Quint);
            Library:Tween(Veil, { BackgroundTransparency = 0 }, Fade);
            Library:Tween(Shadow, { ImageTransparency = 1 }, Fade);
            for Frame, _ in next, Library.OpenedFrames do
                Frame.Visible = false;
                Library.OpenedFrames[Frame] = nil;
            end;
            task.delay(Fade, function()
                if Token == Library.ToggleToken then
                    Outer.Visible = false;
                    Veil.Visible = false;
                    WindowScale.Scale = 1;
                end;
            end);
        end;

        if Library.Toggled then
            task.spawn(function()
                local State = InputService.MouseIconEnabled;
                local GuiService = game:GetService("GuiService");

                local Cursor = Instance.new("ImageLabel", ScreenGui);
                Cursor.Image = "http://www.roblox.com/asset/?id=4292970642";
                Cursor.BackgroundTransparency = 1;
                Cursor.ZIndex = 100;

                local CursorOutline = Instance.new("ImageLabel", ScreenGui);
                CursorOutline.Image = "http://www.roblox.com/asset/?id=4292970642";
                CursorOutline.ImageColor3 = Color3.new();
                CursorOutline.BackgroundTransparency = 1;
                CursorOutline.ZIndex = 99;

                Cursor.Size, CursorOutline.Size = UDim2.fromOffset(17, 17), UDim2.fromOffset(19, 19);
                Cursor.Rotation, CursorOutline.Rotation = -45, -45;

                while Library.Toggled and ScreenGui.Parent do
                    InputService.MouseIconEnabled = false;

                    local mPos = InputService:GetMouseLocation();
                    local udim = UDim2.fromOffset(mPos.X, mPos.Y - GuiService:GetGuiInset().Y - 1);

                    Cursor.ImageColor3 = Library.AccentColor;
                    Cursor.Position, CursorOutline.Position = udim, udim - UDim2.fromOffset(1, 1);

                    RenderStepped:Wait();
                end;

                InputService.MouseIconEnabled = State;

                Cursor:Destroy();
                CursorOutline:Destroy();
            end);
        end;
        Library:UpdateBlur();
    end

    Library:GiveSignal(InputService.InputBegan:Connect(function(Input, Processed)
        if type(Library.ToggleKeybind) == 'table' and Library.ToggleKeybind.Type == 'KeyPicker' then
            if Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode.Name == Library.ToggleKeybind.Value then
                task.spawn(Library.Toggle)
            end
        elseif type(Library.ToggleKeybind) == 'string' then
            if Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode.Name == Library.ToggleKeybind then
                task.spawn(Library.Toggle)
            end
        elseif Input.KeyCode == Enum.KeyCode.RightControl or (Input.KeyCode == Enum.KeyCode.RightShift and (not Processed)) then
            task.spawn(Library.Toggle)
        end
    end))

    if Config.AutoShow then task.spawn(Library.Toggle) end

    Window.Holder = Outer;
    Window.Sidebar = Sidebar;
    Window.SearchBox = SearchBox;
    return Window;
end;

local function OnPlayerChange()
    local PlayerList = GetPlayersString();
    for _, Value in next, Options do
        if Value.Type == 'Dropdown' and Value.SpecialType == 'Player' then
            Value:SetValues(PlayerList);
        end;
    end;
end;

Library:GiveSignal(Players.PlayerAdded:Connect(OnPlayerChange));
Library:GiveSignal(Players.PlayerRemoving:Connect(OnPlayerChange));

if InputService.TouchEnabled then
    local MobileGui = Instance.new("ScreenGui")
    MobileGui.Name = "AsterMobileUI"
    MobileGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    pcall(ProtectGui, MobileGui)
    MobileGui.Parent = GetGuiParent()
    Library.MobileGui = MobileGui

    local BTN_W, BTN_H = 88, 30
    local BTN_GAP      = 40  

    local function CreateMobileButton(name, text, startPos)
        local Outer = Library:Create('Frame', {
            Name             = name .. "Outer",
            BackgroundColor3 = Library.OutlineColor,
            BorderSizePixel  = 0,
            Position         = startPos,
            Size             = UDim2.new(0, BTN_W, 0, BTN_H),
            ZIndex           = 300,
            Parent           = MobileGui,
            Active           = true,
        })
        Library:AddToRegistry(Outer, { BackgroundColor3 = 'OutlineColor' })

        local AccentFrame = Library:Create('Frame', {
            Name             = name .. "Accent",
            BackgroundColor3 = Library.AccentColor,
            BorderSizePixel  = 0,
            Position         = UDim2.new(0, 1, 0, 1),
            Size             = UDim2.new(1, -2, 1, -2),
            ZIndex           = 301,
            Parent           = Outer,
        })
        Library:AddToRegistry(AccentFrame, { BackgroundColor3 = 'AccentColor' })

        local Inner = Library:Create('Frame', {
            Name             = name .. "Inner",
            BackgroundColor3 = Color3.fromRGB(8, 8, 12),
            BorderSizePixel  = 0,
            Position         = UDim2.new(0, 1, 0, 1),
            Size             = UDim2.new(1, -2, 1, -2),
            ZIndex           = 302,
            Parent           = AccentFrame,
        })

        local GradientOverlay = Library:Create('Frame', {
            Name             = name .. "Gradient",
            BackgroundColor3 = Color3.new(1, 1, 1), 
            BorderSizePixel  = 0,
            Size             = UDim2.new(1, 0, 1, 0),
            ZIndex           = 303,
            Parent           = Inner,
        })
        Library:Create('UIGradient', {
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.90), 
                NumberSequenceKeypoint.new(1, 1.0)   
            }),
            Rotation = 90,
            Parent = GradientOverlay,
        })

        local Btn = Library:Create('TextButton', {
            Name                = name .. "Btn",
            BackgroundTransparency = 1,
            Size                = UDim2.new(1, 0, 1, 0),
            Font                = Library.Font,
            Text                = text,
            TextColor3          = Color3.fromRGB(255, 255, 255),
            TextSize            = Library.FontSize - 1,
            ZIndex              = 304,
            Parent              = Inner,
            Active              = true,
        })

        return Outer, Btn
    end

    local ToggleOuter, ToggleBtn = CreateMobileButton("Toggle", "Toggle UI",  UDim2.new(0, 10, 0, 10))
    local LockOuter,   LockBtn  = CreateMobileButton("Lock",   "Unlock UI",  UDim2.new(0, 10, 0, 10 + BTN_H + (BTN_GAP - BTN_H)))

    local IsUnlocked = false

    local function BindMobileButtonAction(Btn, Outer, ClickAction)
        local dragging  = false
        local dragInput = nil
        local dragStart = nil
        local startPos  = nil
        local hasMoved  = false

        Btn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
                dragging  = true
                hasMoved  = false
                dragStart = input.Position
                startPos  = Outer.Position
                dragInput = input

                local connection
                connection = input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragging = false
                        connection:Disconnect()
                        if not hasMoved then
                            ClickAction()
                        end
                    end
                end)
            end
        end)

        Library:GiveSignal(InputService.InputChanged:Connect(function(input)
            if input == dragInput and dragging then
                local delta = input.Position - dragStart
                if delta.Magnitude > 3 then
                    hasMoved = true
                end
                if IsUnlocked and hasMoved then
                    Outer.Position = UDim2.new(
                        startPos.X.Scale, startPos.X.Offset + delta.X,
                        startPos.Y.Scale, startPos.Y.Offset + delta.Y
                    )
                end
            end
        end))
    end

    BindMobileButtonAction(ToggleBtn, ToggleOuter, function()
        Library:Toggle()
    end)

    BindMobileButtonAction(LockBtn, LockOuter, function()
        IsUnlocked = not IsUnlocked
        LockBtn.Text = IsUnlocked and "Lock UI" or "Unlock UI"
        LockBtn.TextColor3 = IsUnlocked
            and Library.AccentColor
            or  Color3.fromRGB(255, 255, 255)
    end)

    local _origUpdate = Library.UpdateColorsUsingRegistry
    Library.UpdateColorsUsingRegistry = function(self)
        _origUpdate(self)
    end
end

Env.Library = Library
return Library
