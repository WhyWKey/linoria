local Env = (type(getgenv) == 'function' and getgenv()) or _G;

-- Executor functions under every name the supported executors document (first one that is a function wins).
local function FirstFn(...)
    for Index = 1, select('#', ...) do
        local Value = select(Index, ...);
        if type(Value) == 'function' then
            return Value;
        end;
    end;
    return nil;
end;

local function SafeField(Owner, Key)
    if type(Owner) ~= 'table' and type(Owner) ~= 'userdata' then
        return nil;
    end;
    local Ok, Value = pcall(function() return Owner[Key]; end);
    return Ok and Value or nil;
end;

local Exec = {
    cloneref = FirstFn(cloneref, clonereference);
    gethui = FirstFn(gethui, get_hidden_gui, gethiddenui);
    isactive = FirstFn(isrbxactive, iswindowactive, isgameactive);
    clipboard = FirstFn(setclipboard, toclipboard, setrbxclipboard);
    customasset = FirstFn(getcustomasset, getsynasset);
    protect = FirstFn(protectgui, SafeField(syn, 'protect_gui'));
    request = FirstFn(request, http_request, SafeField(http, 'request'), SafeField(syn, 'request'));
};

function Exec.HttpGet(Url)
    local Ok, Body = pcall(function() return game:HttpGet(Url); end);
    if Ok and type(Body) == 'string' then
        return Body;
    end;
    if Exec.request then
        local Sent, Response = pcall(Exec.request, { Url = Url, Method = 'GET' });
        if Sent and type(Response) == 'table' and type(Response.Body) == 'string' then
            return Response.Body;
        end;
    end;
    return nil;
end;

local function GetService(Name)
    local Service = game:GetService(Name);
    if Exec.cloneref then
        local Ok, Cloned = pcall(Exec.cloneref, Service);
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

local ProtectGui = Exec.protect or (function() end);

local function GetGuiParent()
    local Ok, Hui = pcall(function()
        return Exec.gethui and Exec.gethui() or nil;
    end);
    if Ok and typeof(Hui) == 'Instance' then
        -- Real's gethui is CoreGui.RobloxGui: a ScreenGui nested in a ScreenGui does not render
        local OkLayer, Layer = pcall(function() return Hui:IsA('LayerCollector'); end);
        if true then
            return Hui;
        end;
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

    FontColor = Color3.fromRGB(233, 232, 245);
    MainColor = Color3.fromRGB(20, 20, 28);
    BackgroundColor = Color3.fromRGB(11, 11, 16);
    AccentColor = Color3.fromRGB(139, 92, 246);
    AccentColor2 = Color3.fromRGB(74, 168, 255);
    OutlineColor = Color3.fromRGB(38, 38, 51);
    RiskColor = Color3.fromRGB(244, 63, 94);

    -- derived colours: recomputed from the base colours unless overridden (see ResolveColors)
    SidebarColor = Color3.new(0, 0, 0);
    GroupboxColor = Color3.new(0, 0, 0);
    InputColor = Color3.new(0, 0, 0);
    TrackColor = Color3.new(0, 0, 0);
    ToggleOffColor = Color3.new(0, 0, 0);
    HoverColor = Color3.new(0, 0, 0);
    DimColor = Color3.new(0, 0, 0);
    IndicatorColor = Color3.new(0, 0, 0);
    NotifyColor = Color3.new(0, 0, 0);
    WatermarkColor = Color3.new(0, 0, 0);
    KeybindColor = Color3.new(0, 0, 0);
    ColorOverrides = {};

    Black = Color3.new(0, 0, 0);

    -- the gradient only ever paints the window outline
    AnimatedGradient = true;
    GradientSpeed = 0.35;
    GradientAngle = 45;
    OutlineMode = 'Gradient';
    OutlineThickness = 1;
    WidgetAccent = true;
    WidgetAccentStyle = 'Gradient';
    StrokeThickness = 1;
    CornerScale = 1;
    WindowTransparency = 0;
    UIScale = 1;
    MenuFadeTime = 0.2;

    PlayerPriorities = {};
    PlayerLists = {};

    Font = Enum.Font.Gotham,
    CardOutline = false;
    TopAccentLine = false;
    SliderShowMax = false;
    FontSize = 13,

    OpenedFrames = {};
    DependencyBoxes = {};
    ColumnScrollers = {};

    Signals = {};
    ScreenGui = ScreenGui;

    Toggled = false;
    WireframeDrag = true;
    UseBlur = true;
    BlurSize = 24;
    UseDarken = true;
    DarkenAmount = 55;

    MinWidth = 760;
    MinHeight = 460;
    MovableSections = true;
    ShowCustomCursor = true;
    HideGameCursor = true;

    KeybindMode = 'All';
    -- open menu swallows clicks outside it (full-screen sink under the window); false = game input passes through
    BlockGameInput = true;
    -- true = clicking a toggle's label or row flips it too, not only the switch
    ToggleClickRow = false;

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
-- row keybind chips (chip frame -> re-measure), refreshed when the font changes
Library.KeyChips = setmetatable({}, { __mode = 'k' });
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

    -- no tweens: animating blur size or a screen-sized frame re-renders the whole screen every frame
    Library.BlurEffect.Size = targetSize;
    Library.BlurEffect.Enabled = open and true or false;

    if Library.DarkOverlay then
        local dark = Library.Toggled and Library.UseDarken;
        Library.DarkOverlay.BackgroundTransparency = dark and (1 - (Library.DarkenAmount / 100)) or 1;
        Library.DarkOverlay.Visible = dark and true or false;
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
    for _, extra in ipairs({ Library.MobileGui or false, Library.PopupGui or false }) do
        if extra then
        for _, descendant in pairs(extra:GetDescendants()) do
            if descendant:IsA("TextLabel") or descendant:IsA("TextBox") or descendant:IsA("TextButton") then
                local offset = descendant:GetAttribute("FontSizeOffset")
                if offset then
                    descendant.TextSize = Size + offset
                end
            end
        end
        end
    end
    for _, Refresh in next, Library.KeyChips do
        pcall(Refresh);
    end;
    if Library.RelayoutNotifications then Library:RelayoutNotifications() end;
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
    local Follow
    Library:GiveSignal(function()
        if Follow then Follow:Disconnect(); Follow = nil end
    end)

    Library:Hover(HoverInstance, function()
        if Library:MouseIsOverOpenedFrame() then
            return
        end

        Tooltip.Position = UDim2.fromOffset(Mouse.X + 15, Mouse.Y + 12)
        Tooltip.Visible = true

        if Follow then Follow:Disconnect() end
        Follow = RunService.Heartbeat:Connect(function()
            Tooltip.Position = UDim2.fromOffset(Mouse.X + 15, Mouse.Y + 12)
        end)
    end, function()
        if Follow then Follow:Disconnect(); Follow = nil end
        Tooltip.Visible = false
    end)
end

function Library:OnHighlight(HighlightInstance, Instance, Properties, PropertiesDefault)
    Library:Hover(HighlightInstance, function()
        local Reg = Library.RegistryMap[Instance];

        for Property, ColorIdx in next, Properties do
            Instance[Property] = Library[ColorIdx] or ColorIdx;

            if Reg and Reg.Properties[Property] then
                Reg.Properties[Property] = ColorIdx;
            end;
        end;
    end, function()
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

-- Mouse / side-button binds. Roblox has no XButton input type, so MB4/MB5 are polled through an executor key-state function.
Library.SideKeys = { MB4 = 0x05, MB5 = 0x06 };
Library.SideState = { MB4 = false, MB5 = false };
Library.SideBinders = {};
Library.SideMouseSupported = false;
local SidePollFn, SideConn;

function Library:DetectSideMouse()
    SidePollFn = nil;
    local Candidates = {
        function() return iskeypressed end,
        function() return keyispressed end,
        function() return getasynckeystate end,
        function() return GetAsyncKeyState end,
    };
    for _, Get in ipairs(Candidates) do
        local _, Fn = pcall(Get);
        if type(Fn) == 'function' then
            local Ok, Res = pcall(Fn, 0x05);
            if Ok and (type(Res) == 'boolean' or type(Res) == 'number') then
                SidePollFn = Fn;
                break;
            end;
        end;
    end;
    Library.SideMouseSupported = SidePollFn ~= nil;
    Library:UpdateSidePolling();
    return Library.SideMouseSupported;
end;

-- MB4/MB5 are hidden (shown as unbound) while no key-state function exists; the bound value is kept for configs.
function Library:SideKeyHidden(Key)
    return Library.SideKeys[Key] ~= nil and not Library.SideMouseSupported;
end;

function Library:SideDown(Key)
    local Code = Library.SideKeys[Key];
    if not SidePollFn or not Code then
        return false;
    end;
    if Exec.isactive then
        local Ok, Active = pcall(Exec.isactive);
        if Ok and Active == false then
            return false;
        end;
    end;
    local Ok, Res = pcall(SidePollFn, Code);
    if not Ok then
        return false;
    end;
    if type(Res) == 'number' then
        return Res < 0 or Res >= 32768;
    end;
    return Res == true;
end;

-- A mouse click inside the open menu should not fire a MB1/MB2 bind.
function Library:IsMenuClick(Key)
    if Key ~= 'MB1' and Key ~= 'MB2' and Key ~= 'Touch' then
        return false;
    end;
    local Menu = Library.MenuOuter;
    return Library.Toggled and Menu ~= nil and Library:IsMouseOverFrame(Menu) == true;
end;

-- Keystrokes meant for a focused TextBox (dropdown search, slider editor, chat) must never reach binds.
-- Mouse input still passes: a click outside the box is what releases its focus.
function Library:IsTypingInput(Input)
    if Input and Input.UserInputType ~= Enum.UserInputType.Keyboard then
        return false;
    end;
    local Ok, Box = pcall(function() return InputService:GetFocusedTextBox() end);
    return Ok and Box ~= nil;
end;

function Library:KeyNameFromInput(Input)
    local Type = Input.UserInputType;
    if Type == Enum.UserInputType.Keyboard then
        return Input.KeyCode.Name;
    elseif Type == Enum.UserInputType.MouseButton1 then
        return 'MB1';
    elseif Type == Enum.UserInputType.MouseButton2 then
        return 'MB2';
    elseif Type == Enum.UserInputType.MouseButton3 then
        return 'MB3';
    elseif Type == Enum.UserInputType.Touch then
        return 'Touch';
    end;
end;

local KeyShortNames = {
    LeftShift = 'LShift'; RightShift = 'RShift'; LeftControl = 'LCtrl'; RightControl = 'RCtrl';
    LeftAlt = 'LAlt'; RightAlt = 'RAlt'; LeftSuper = 'LWin'; RightSuper = 'RWin';
    Return = 'Enter'; Escape = 'Esc'; Backspace = 'Back'; Delete = 'Del'; Insert = 'Ins';
    PageUp = 'PgUp'; PageDown = 'PgDn'; CapsLock = 'Caps'; Space = 'Space';
    Zero = '0'; One = '1'; Two = '2'; Three = '3'; Four = '4';
    Five = '5'; Six = '6'; Seven = '7'; Eight = '8'; Nine = '9';
};

-- Short label for a bind, shared by the row chip and the keybind list: MB1..MB5, '-' when unbound.
function Library:KeyDisplayName(Key)
    Key = tostring(Key or 'None');
    if Key == '' or Key == 'None' or Key == 'Unknown' then
        return '-';
    end;
    local Button = Key:match('^MouseButton(%d)$') or Key:match('^Mouse%s*(%d)$') or Key:match('^MB(%d)$');
    if Button then
        return 'MB' .. Button;
    end;
    local Pad = Key:match('^Keypad(.+)$');
    if Pad then
        return 'Num' .. (KeyShortNames[Pad] or Pad);
    end;
    return KeyShortNames[Key] or Key;
end;

-- True if a held-key bind named Key is currently down (mouse buttons, side buttons and keys).
function Library:IsBindDown(Key)
    if Key == 'None' or Key == nil then
        return false;
    elseif Key == 'MB1' or Key == 'MB2' or Key == 'MB3' then
        return InputService:IsMouseButtonPressed(Enum.UserInputType['MouseButton' .. Key:sub(3)]);
    elseif Key == 'MB4' or Key == 'MB5' then
        return Library:SideDown(Key);
    elseif Key == 'Touch' then
        return true;
    end;
    if Library:IsTypingInput() then
        return false;
    end;
    local Ok, Code = pcall(function() return Enum.KeyCode[Key] end);
    return Ok and Code ~= nil and InputService:IsKeyDown(Code) or false;
end;

function Library:SideEdge(Key, Down)
    Library.SideState[Key] = Down;
    if Down then
        for _, Binder in next, Library.SideBinders do
            Binder(Key);
        end;
        if not Library.JustBound then
            local TK = Library.ToggleKeybind;
            if (type(TK) == 'table' and TK.Value == Key) or TK == Key then
                task.spawn(Library.Toggle);
            end;
        end;
    end;
    for _, KP in ipairs(Library.KeyPickerList) do
        if Down and KP.Value == Key and not Library.JustBound then
            KP:HandleBindPress(Key);
        end;
    end;
    Library:RefreshKeybinds();
end;

function Library:UpdateSidePolling()
    local Need = false;
    if SidePollFn and not Library.Unloaded then
        if next(Library.SideBinders) ~= nil then
            Need = true;
        else
            local TK = Library.ToggleKeybind;
            if Library.SideKeys[type(TK) == 'table' and TK.Value or TK] then
                Need = true;
            end;
            for _, KP in ipairs(Library.KeyPickerList) do
                if Library.SideKeys[KP.Value] then
                    Need = true;
                    break;
                end;
            end;
        end;
    end;

    if Need and not SideConn then
        for Key in next, Library.SideKeys do
            Library.SideState[Key] = Library:SideDown(Key);
        end;
        SideConn = RunService.Heartbeat:Connect(function()
            for Key in next, Library.SideKeys do
                local Down = Library:SideDown(Key);
                if Down ~= Library.SideState[Key] then
                    Library:SideEdge(Key, Down);
                end;
            end;
        end);
    elseif not Need and SideConn then
        SideConn:Disconnect();
        SideConn = nil;
    end;
end;

table.insert(Library.Signals, function()
    if SideConn then SideConn:Disconnect(); SideConn = nil end;
end);
Library:DetectSideMouse();

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
    Library:ResolveColors();
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
    Library:ApplyOutline();
end;

function Library:GiveSignal(Signal)
    table.insert(Library.Signals, Signal)
end

Library.UnloadCallbacks = {};

function Library:CloseSliderEditor()
    local Editor = Library.SliderEditor;
    if Editor then Editor.Close(); end;
end;

function Library:Unload()
    if Library.Unloaded then
        return;
    end;
    Library.Unloaded = true;
    Library:CloseSliderEditor();
    for Chip in next, Library.KeyChips do
        Library.KeyChips[Chip] = nil;
    end;

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

    if Library.PopupGui then
        pcall(function() Library.PopupGui:Destroy() end)
    end

    if Library.DarkOverlay and Library.DarkOverlay.Parent then
        pcall(function() Library.DarkOverlay.Parent:Destroy() end)
    end

    if Library.MobileGui then
        pcall(function() Library.MobileGui:Destroy() end)
    end

    Library.CursorToken = (Library.CursorToken or 0) + 1;
    if Library.CursorGui then pcall(function() Library.CursorGui:Destroy() end) end;
    if Library.SavedMouseIcon ~= nil then
        pcall(function() InputService.MouseIconEnabled = Library.SavedMouseIcon end)
        Library.SavedMouseIcon = nil;
        Library.CursorGui = nil;
    end;
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

-- One live tween per instance: a new tween or a direct Snap cancels the old one so it cannot finish later and overwrite the state.
Library.LiveTweens = setmetatable({}, { __mode = 'k' });
function Library:Snap(Obj, Props)
    local Old = Library.LiveTweens[Obj];
    if Old then Library.LiveTweens[Obj] = nil; pcall(function() Old:Cancel() end) end;
    if Props then
        for K, V in next, Props do pcall(function() Obj[K] = V end) end;
    end;
end;

function Library:Tween(Obj, Props, Time, Style, Dir)
    if Library.SnapTweens then
        Library:Snap(Obj, Props);
        return;
    end;
    local Prev = Library.LiveTweens[Obj];
    if Prev then pcall(function() Prev:Cancel() end) end;
    local Ok, Tw = pcall(function()
        local T = TweenService:Create(Obj, TweenInfo.new(Time or 0.15, Style or Enum.EasingStyle.Quad, Dir or Enum.EasingDirection.Out), Props);
        T:Play();
        return T;
    end);
    if Ok then Library.LiveTweens[Obj] = Tw; return Tw end;
end;

-- Hover is purely state-derived: no MouseEnter/MouseLeave. Every frame the menu is open, Library:UpdateHovers
-- finds the topmost GuiObject under the mouse; an entry is hovered only if that object is its Hit or a descendant.
Library.Hovers = setmetatable({}, { __mode = 'k' });
function Library:Hover(Hit, OnEnter, OnLeave)
    local Entry = { Hit = Hit; On = false; Enter = OnEnter; Leave = OnLeave };
    function Entry.Exit(Instant)
        if not Entry.On then return end;
        Entry.On = false;
        if Instant then Library.SnapTweens = true end;
        pcall(OnLeave);
        Library.SnapTweens = false;
    end;
    Library.Hovers[Entry] = true;
    return Entry;
end;

local function Clipped(Hit, X, Y)
    local Cur = Hit.Parent;
    while Cur and Cur:IsA('GuiObject') do
        if Cur.ClipsDescendants then
            local P, S = Cur.AbsolutePosition, Cur.AbsoluteSize;
            if X < P.X or X > P.X + S.X or Y < P.Y or Y > P.Y + S.Y then return true end;
        end;
        Cur = Cur.Parent;
    end;
    return false;
end;

function Library:TopObjectAt(X, Y)
    local Root = ScreenGui.Parent;
    if Root and Root:IsA('BasePlayerGui') then
        local Ok, List = pcall(Root.GetGuiObjectsAtPosition, Root, X, Y);
        if Ok and type(List) == 'table' then
            local Popups = Library.PopupGui;
            for _, Obj in ipairs(List) do
                if Obj:IsDescendantOf(ScreenGui) or (Popups and Obj:IsDescendantOf(Popups)) then return Obj end;
            end;
            return false;
        end;
    end;
    return nil;
end;

function Library:UpdateHovers(Force)
    local X, Y = Mouse.X, Mouse.Y;
    local Top = (not Force) and Library:TopObjectAt(X, Y) or nil;
    local Any = false;
    -- an open float covers whatever sits under it, even when TopObjectAt is unavailable
    local Cover = Library.ActiveFloat and Library.ActiveFloat.Frame;
    if Cover and not Library:IsMouseOverFrame(Cover) then Cover = nil end;
    for Entry in next, Library.Hovers do
        local Hit = Entry.Hit;
        local Want = false;
        if not Force and Hit.Parent then
            Want = true;
            local Cur = Hit;
            while Cur and Cur:IsA('GuiObject') do
                if not Cur.Visible then Want = false; break end;
                Cur = Cur.Parent;
            end;
            if Want then
                local P, S = Hit.AbsolutePosition, Hit.AbsoluteSize;
                Want = X >= P.X and X <= P.X + S.X and Y >= P.Y and Y <= P.Y + S.Y and not Clipped(Hit, X, Y);
            end;
            if Want and Top ~= nil then
                Want = Top ~= false and (Top == Hit or Top:IsDescendantOf(Hit));
            end;
            if Want and Cover then
                Want = Hit == Cover or Hit:IsDescendantOf(Cover);
            end;
        end;
        if Want and not Entry.On then
            Entry.On = true;
            task.spawn(Entry.Enter);
        elseif not Want and Entry.On then
            Entry.Exit(true);
        end;
        if Entry.On then Any = true end;
    end;
    Library.CursorHot = Any;
end;
Library.SweepHovers = Library.UpdateHovers;

Library.Corners = setmetatable({}, { __mode = 'k' });
Library.Strokes = setmetatable({}, { __mode = 'k' });
Library.TransparentFrames = setmetatable({}, { __mode = 'k' });

function Library:Round(Obj, Radius)
    local Base = Radius or 6;
    local Corner = Library:Create('UICorner', {
        CornerRadius = UDim.new(0, math.floor(Base * Library.CornerScale + 0.5));
        Parent = Obj;
    });
    Library.Corners[Corner] = Base;
    return Corner;
end;

function Library:Stroke(Obj, ColorKey, Thickness, Transparency)
    local Stroke = Library:Create('UIStroke', {
        Color = Library[ColorKey or 'OutlineColor'];
        Thickness = (Thickness or 1) * Library.StrokeThickness;
        Transparency = Transparency or 0;
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border;
        Parent = Obj;
    });
    Library.Strokes[Stroke] = Thickness or 1;
    Library:AddToRegistry(Stroke, { Color = ColorKey or 'OutlineColor' });
    return Stroke;
end;

-- Frame whose background fades with the window transparency setting (Factor 0..1 of the setting)
function Library:AddTransparent(Frame, Factor)
    Library.TransparentFrames[Frame] = Factor or 1;
    Frame.BackgroundTransparency = math.clamp(Library.WindowTransparency * (Factor or 1), 0, 1);
    return Frame;
end;

function Library:GetDimColor()
    return Library.DimColor;
end;

function Library:GetSidebarColor()
    return Library.SidebarColor;
end;

-- Derived theme colours. Each follows its base colour until a ColorOverride is set.
Library.DerivedColors = {
    { 'SidebarColor',    function(L) return L.BackgroundColor:Lerp(Color3.new(0, 0, 0), 0.4) end, 'Sidebar' };
    { 'GroupboxColor',   function(L) return L.MainColor end, 'Groupbox' };
    { 'InputColor',      function(L) return L.BackgroundColor end, 'Input field' };
    { 'TrackColor',      function(L) return L.OutlineColor end, 'Slider track' };
    { 'ToggleOffColor',  function(L) return L.BackgroundColor end, 'Toggle off' };
    { 'HoverColor',      function(L) return L.OutlineColor end, 'Hover' };
    { 'DimColor',        function(L) return L.FontColor:Lerp(L.MainColor, 0.45) end, 'Dim text' };
    { 'IndicatorColor',  function(L) return L.AccentColor end, 'Tab indicator' };
    { 'NotifyColor',     function(L) return L.MainColor end, 'Notification' };
    { 'WatermarkColor',  function(L) return L.MainColor end, 'Watermark' };
    { 'KeybindColor',    function(L) return L.MainColor end, 'Keybind list' };
};
Library.BaseColorKeys = { 'BackgroundColor', 'MainColor', 'AccentColor', 'AccentColor2', 'OutlineColor', 'FontColor', 'RiskColor' };

function Library:ResolveColors()
    Library.AccentColorDark = Library:GetDarkerColor(Library.AccentColor);
    for _, Def in ipairs(Library.DerivedColors) do
        Library[Def[1]] = Library.ColorOverrides[Def[1]] or Def[2](Library);
    end;
end;

-- derived colours must exist before any UI or the intro is built
Library:ResolveColors();

function Library:SetMinSize(Width, Height)
    Library.MinWidth = math.max(320, tonumber(Width) or Library.MinWidth);
    Library.MinHeight = math.max(240, tonumber(Height) or Library.MinHeight);
    if Library.ClampWindow then Library.ClampWindow() end;
end;

function Library:SetColorOverride(Key, Color)
    if typeof(Color) ~= 'Color3' then return end;
    Library.ColorOverrides[Key] = Color;
end;

function Library:ClearColorOverride(Key)
    Library.ColorOverrides[Key] = nil;
end;

function Library:IsDerivedColor(Key)
    for _, Def in ipairs(Library.DerivedColors) do
        if Def[1] == Key then return true end;
    end;
    return false;
end;

-- Sets any theme colour by key (base or derived) and repaints
function Library:SetThemeColor(Key, Color)
    if typeof(Color) ~= 'Color3' then return end;
    if Library:IsDerivedColor(Key) then
        Library:SetColorOverride(Key, Color);
    else
        Library[Key] = Color;
    end;
    Library:UpdateColorsUsingRegistry();
end;

Library:ResolveColors();

local function IsText(Inst)
    return Inst:IsA('TextLabel') or Inst:IsA('TextBox') or Inst:IsA('TextButton');
end;

function Library:SetFont(Font)
    if type(Font) == 'string' then
        local Ok, Item = pcall(function() return Enum.Font[Font] end);
        if not Ok or not Item then return end;
        Font = Item;
    end;
    if not Font then return end;
    local Old = Library.Font;
    Library.Font = Font;
    local Roots = { ScreenGui, Library.PopupGui, Library.MobileGui };
    for _, Root in next, Roots do
        for _, Descendant in ipairs(Root:GetDescendants()) do
            if IsText(Descendant) and Descendant.Font == Old then
                Descendant.Font = Font;
            end;
        end;
    end;
    for _, Refresh in next, Library.KeyChips do
        pcall(Refresh);
    end;
    if Library.RelayoutNotifications then Library:RelayoutNotifications() end;
end;

function Library:SetCornerScale(Scale)
    Library.CornerScale = math.clamp(tonumber(Scale) or 1, 0, 3);
    for Corner, Base in next, Library.Corners do
        pcall(function()
            Corner.CornerRadius = UDim.new(0, math.floor(Base * Library.CornerScale + 0.5));
        end);
    end;
end;

function Library:SetStrokeThickness(Value)
    Library.StrokeThickness = math.clamp(tonumber(Value) or 1, 0, 4);
    for Stroke, Base in next, Library.Strokes do
        pcall(function()
            Stroke.Thickness = Base * Library.StrokeThickness;
        end);
    end;
end;

function Library:SetWindowTransparency(Value)
    Library.WindowTransparency = math.clamp(tonumber(Value) or 0, 0, 0.9);
    for Frame, Factor in next, Library.TransparentFrames do
        pcall(function()
            Frame.BackgroundTransparency = Library.WindowTransparency * Factor;
        end);
    end;
end;

function Library:SetUIScale(Value)
    Library.UIScale = math.clamp(tonumber(Value) or 1, 0.6, 1.6);
    if Library.WindowScale then
        Library.WindowScale.Scale = Library.UIScale;
    end;
    if Library.PopupScale then
        Library.PopupScale.Scale = Library.UIScale;
    end;
end;

function Library:SetKeybindListVisibility(Bool)
    if Library.KeybindFrame then
        Library.KeybindFrame.Visible = not not Bool;
    end;
end;

-- Hover feedback: stroke tweens to the accent, optional bg brighten
function Library:OnHover(Hit, Stroke, BgKey)
    Library:Hover(Hit, function()
        Library:Tween(Stroke, { Color = Library.AccentColor }, 0.12);
        if BgKey then
            Library:Tween(Hit, { BackgroundColor3 = Library[BgKey]:Lerp(Library.FontColor, 0.06) }, 0.12);
        end;
    end, function()
        Library:Tween(Stroke, { Color = Library.OutlineColor }, 0.12);
        if BgKey then
            Library:Tween(Hit, { BackgroundColor3 = Library[BgKey] }, 0.12);
        end;
    end);
end;

-- Gradients -----------------------------------------------------------------
function Library:GradientSequence(Mode, Flat)
    local A, B = Library.AccentColor, Library.AccentColor2;
    if Flat then
        return ColorSequence.new(A, A);
    end;
    if Mode == 'spin' then
        return ColorSequence.new({
            ColorSequenceKeypoint.new(0, A),
            ColorSequenceKeypoint.new(0.5, B),
            ColorSequenceKeypoint.new(1, A),
        });
    end;
    return ColorSequence.new(A, B);
end;

-- Outline gradients follow Library.OutlineMode; the menu body never uses a gradient
function Library:AddGradient(Gradient, Mode, Always, Axis, Outline)
    local Entry = {
        Gradient = Gradient;
        Mode = Mode or 'slide';
        Always = Always or false;
        Axis = Axis or 'X';
        Outline = Outline or false;
        BaseRotation = Gradient.Rotation;
        Phase = Outline and 0 or math.random();
    };
    Gradient.Color = Library:GradientSequence(Entry.Mode, Entry.Outline and Library.OutlineMode ~= 'Gradient');
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
    local Flat = Library.OutlineMode ~= 'Gradient';
    for _, Entry in ipairs(Library.Gradients) do
        pcall(function()
            if Entry.Outline and Entry.Mode == 'spin' then
                Entry.BaseRotation = Library.GradientAngle;
            end;
            Entry.Gradient.Color = Library:GradientSequence(Entry.Mode, Entry.Outline and Flat);
        end);
    end;
    Library:ApplyWidgetAccent();
    Library.GradientDirty = true;
end;

-- Widget accent bars were removed; setters kept so existing callers do not error
function Library:ApplyWidgetAccent() end;

function Library:SetWidgetAccent(Bool)
    Library.WidgetAccent = not not Bool;
    Library:ApplyWidgetAccent();
end;

function Library:SetWidgetAccentStyle(Style)
    Library.WidgetAccentStyle = tostring(Style or ''):lower() == 'solid' and 'Solid' or 'Gradient';
    Library:ApplyWidgetAccent();
    Library.GradientDirty = true;
end;

-- Animates a keybind row open/closed; Visible is dropped only once the collapse has finished
function Library:SetRowShown(Row, Shown)
    if Row:GetAttribute('Shown') == Shown then return end;
    Row:SetAttribute('Shown', Shown);
    if Shown then Row.Visible = true end;
    Library:Tween(Row, { Size = UDim2.new(1, 0, 0, Shown and 18 or 0) }, 0.16);
    if not Shown then
        task.delay(0.18, function()
            if Row.Parent and Row:GetAttribute('Shown') == false then Row.Visible = false end;
        end);
    end;
end;

-- Paints the window outline for the current OutlineMode / thickness (nothing else uses the gradient)
function Library:ApplyOutline()
    local Outline = Library.Outline;
    if not Outline then return end;
    local Mode = Library.OutlineMode;
    Outline.Stroke.Thickness = Library.OutlineThickness;
    Outline.Stroke.Transparency = Mode == 'None' and 1 or 0.3;
    Outline.TopLine.Visible = Mode ~= 'None' and Library.TopAccentLine;
    Outline.TopLine.Size = UDim2.new(1, -40, 0, math.max(1, Library.OutlineThickness + 1));
end;

function Library:SetOutlineMode(Mode)
    Mode = tostring(Mode or ''):lower();
    Library.OutlineMode = Mode == 'solid' and 'Solid' or (Mode == 'none' and 'None' or 'Gradient');
    Library:UpdateGradients();
    Library:ApplyOutline();
end;

function Library:SetOutlineThickness(Value)
    Library.OutlineThickness = math.clamp(tonumber(Value) or 1, 0, 6);
    Library:ApplyOutline();
end;

function Library:SetGradientAngle(Angle)
    Library.GradientAngle = (tonumber(Angle) or 0) % 360;
    Library:UpdateGradients();
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
    Library.GradientDirty = true;
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
    ['cloud'] = { 16898613044, 918, 306 };
    ['clock'] = { 16898613044, 771, 661 };
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
    if Name:find('rbxasset', 1, true) or Name:find('rbxthumb', 1, true) == 1 or Name:find('http', 1, true) == 1 then
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
-- aster_logo.png is fetched from the repo in the background; until then (or without
-- writefile/getcustomasset) logos use the Frame-built star below.
Library.LogoImage = nil;
Library.LogoListeners = {};

task.spawn(function()
    pcall(function()
        if type(writefile) ~= 'function' or not Exec.customasset then
            return;
        end;
        local Path = 'Aster/aster_logo_v5.png';
        pcall(function()
            if type(makefolder) == 'function' and not (type(isfolder) == 'function' and isfolder('Aster')) then
                makefolder('Aster');
            end;
        end);
        local Base = Env.AsterRepo or 'https://raw.githubusercontent.com/WhyWKey/linoria/main/';
        local Ok, Data = pcall(Exec.HttpGet, Base .. 'aster_logo.png');
        local FromCache = false;
        if not (Ok and type(Data) == 'string' and #Data > 64 and string.sub(Data, 2, 4) == 'PNG') then
            Data = nil;
            pcall(function()
                if type(isfile) == 'function' and isfile(Path) then
                    Data = readfile(Path);
                    FromCache = Data ~= nil;
                end;
            end);
        end;
        if not Data then
            return;
        end;
        if not FromCache then
            writefile(Path, Data);
        end;
        local Asset = Exec.customasset(Path);
        if type(Asset) ~= 'string' or Asset == '' then
            return;
        end;
        Library.LogoImage = Asset;
        for _, Listener in ipairs(Library.LogoListeners) do
            pcall(Listener, Asset);
        end;
    end);
end);

-- Accent-tinted orbit mark (star + ring, no tile): image when available, otherwise a Frame-built 4-point star.
-- Returns the holder Frame plus a handle { SetSize, Draw, Destroy }. Hidden starts invisible for Draw to fade in.
function Library:CreateLogo(Parent, Size, ZIndex, Always, Hidden)
    local Holder = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Size = UDim2.fromOffset(Size, Size);
        ZIndex = ZIndex;
        Parent = Parent;
    });
    local Content = Library:Create('Frame', {
        AnchorPoint = Vector2.new(0.5, 0.5);
        BackgroundTransparency = 1;
        Position = UDim2.fromScale(0.5, 0.5);
        Size = UDim2.fromScale(1, 1);
        ZIndex = ZIndex;
        Parent = Holder;
    });
    local Scale = Library:Create('UIScale', { Scale = Hidden and 0.6 or 1; Parent = Content });
    local StartAlpha = Hidden and 1 or 0;

    local Pieces = {};
    local function AddPiece(Class, Props, Prop)
        Props.Parent = Content;
        Props.ZIndex = ZIndex + 1;
        Props[Prop] = StartAlpha;
        local Piece = Library:Create(Class, Props);
        Pieces[#Pieces + 1] = { Instance = Piece; Prop = Prop };
        return Piece;
    end;

    -- Frames cannot draw curves, so the concave star is a stack of centred rectangles whose corners
    -- trace the star's quadrant curve (same cubic as aster_orbit_c.svg). The pieces overlap, so they
    -- fade as one CanvasGroup where available.
    local GroupOk, Group = pcall(Instance.new, 'CanvasGroup');
    local Star = Library:Create(GroupOk and Group or Instance.new('Frame'), {
        BackgroundTransparency = 1;
        Size = UDim2.fromScale(1, 1);
        ZIndex = ZIndex + 1;
        Parent = Content;
    });
    if GroupOk then
        Star.GroupTransparency = StartAlpha;
        Pieces[1] = { Instance = Star; Prop = 'GroupTransparency' };
    end;
    local function Fill(W, H)
        local Piece = Library:Create('Frame', {
            AnchorPoint = Vector2.new(0.5, 0.5);
            BackgroundColor3 = Library.AccentColor;
            BackgroundTransparency = GroupOk and 0 or StartAlpha;
            BorderSizePixel = 0;
            Position = UDim2.fromScale(0.5, 0.5);
            Size = UDim2.fromScale(W, H);
            ZIndex = ZIndex + 1;
            Parent = Star;
        });
        Library:AddToRegistry(Piece, { BackgroundColor3 = 'AccentColor' });
        if not GroupOk then
            Pieces[#Pieces + 1] = { Instance = Piece; Prop = 'BackgroundTransparency' };
        end;
    end;
    -- quadrant control points of the star tip-to-tip, normalised so the tips touch the slot edges
    local P1, P2 = 0.23, 0.085;
    for _, T in ipairs({ 0.03, 0.08, 0.14, 0.21, 0.29, 0.38, 0.5 }) do
        local U = 1 - T;
        local X = U * U * U + 3 * U * U * T * P1 + 3 * U * T * T * P2;
        local Y = 3 * U * U * T * P2 + 3 * U * T * T * P1 + T * T * T;
        Fill(X, Y);
        if T < 0.5 then
            Fill(Y, X);
        end;
    end;

    local Img;
    local function UseImage(Asset)
        if Img or not Holder.Parent then
            return;
        end;
        Img = AddPiece('ImageLabel', {
            AnchorPoint = Vector2.new(0.5, 0.5);
            BackgroundTransparency = 1;
            Image = Asset;
            ImageColor3 = Library.AccentColor;
            Position = UDim2.fromScale(0.5, 0.5);
            Size = UDim2.fromScale(1, 1);
        }, 'ImageTransparency');
        Img.ImageTransparency = Pieces[1].Instance[Pieces[1].Prop];
        Library:AddToRegistry(Img, { ImageColor3 = 'AccentColor' });
        Star.Visible = false;
    end;
    if Library.LogoImage then
        UseImage(Library.LogoImage);
    else
        table.insert(Library.LogoListeners, UseImage);
    end;

    local Logo = {};
    function Logo.SetSize(NewSize)
        Holder.Size = UDim2.fromOffset(NewSize, NewSize);
    end;
    function Logo.Draw(Duration, Delay)
        Duration = Duration or 0.6;
        for _, Piece in ipairs(Pieces) do
            Piece.Instance[Piece.Prop] = 1;
        end;
        Scale.Scale = 0.6;
        pcall(function()
            local Fade = TweenInfo.new(Duration * 0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, Delay or 0);
            for _, Piece in ipairs(Pieces) do
                TweenService:Create(Piece.Instance, Fade, { [Piece.Prop] = 0 }):Play();
            end;
            TweenService:Create(Scale, TweenInfo.new(Duration, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, Delay or 0), { Scale = 1 }):Play();
        end);
    end;
    function Logo.Destroy()
        local Pos = table.find(Library.LogoListeners, UseImage);
        if Pos then
            table.remove(Library.LogoListeners, Pos);
        end;
        Holder:Destroy();
    end;
    return Holder, Logo;
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
    Library.SearchQuery = Query;

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
            local Match = (not Filtering) or Root.SearchHit == true or (Root.Title ~= nil and string.find(string.lower(Root.Title), Query, 1, true) ~= nil);
            -- a box in an inactive sub-tab stays hidden whatever the query says
            Root.Outer.Visible = Match and (Root.Gate == nil or Root.Gate());
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

        if Library.Toggled or Library.HoverDirty then
            Library.HoverDirty = not Library.Toggled;
            Library:UpdateHovers(not Library.Toggled);
        end;

        if Accum < 1 / 30 then
            return;
        end;
        Accum = 0;

        if not Library.AnimatedGradient then
            if not AtRest or Library.GradientDirty then
                ResetGradients();
                AtRest = true;
                Library.GradientDirty = false;
            end;
            return;
        end;
        AtRest = false;
        Library.GradientDirty = false;

        local T = Library.GradientTime;
        local Toggled = Library.Toggled;
        local Wave = math.sin(T * math.pi * 2) * 0.5;
        for _, Entry in ipairs(Library.Gradients) do
            if Toggled or Entry.Always then
                local G = Entry.Gradient;
                if Entry.Mode == 'spin' then
                    G.Rotation = (Entry.BaseRotation + (T * 360) + Entry.Phase * 360) % 360;
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

-- Overlays (pickers, dropdown lists) must live in the same ScreenGui as their owner so popups stack correctly
local function OverlayOf(Inst)
    local Cur = Inst;
    while Cur do
        if Cur.ClassName == 'ScreenGui' then
            return Cur;
        end;
        Cur = Cur.Parent;
    end;
    return ScreenGui;
end;

-- Floats -------------------------------------------------------------------
-- Dropdown lists and colour pickers: anchored panels in the popup gui, only one open at a time
local BoldFonts = {
    [Enum.Font.Gotham] = Enum.Font.GothamBold;
    [Enum.Font.GothamMedium] = Enum.Font.GothamBold;
    [Enum.Font.SourceSans] = Enum.Font.SourceSansBold;
    [Enum.Font.Arial] = Enum.Font.ArialBold;
};
function Library:BoldFont()
    return BoldFonts[Library.Font] or Library.Font;
end;

function Library:CreateFloat(Width)
    local Gui = Library:GetPopupGui();
    local Frame = Library:Create('Frame', {
        Name = 'AsterFloat';
        Active = true;
        BackgroundColor3 = Library.BackgroundColor;
        Size = UDim2.fromOffset(Width, 40);
        Visible = false;
        ZIndex = 40;
        Parent = Gui;
    });
    Library:Round(Frame, 6);
    Library:Stroke(Frame, 'OutlineColor');
    Library:AddToRegistry(Frame, { BackgroundColor3 = 'BackgroundColor' });
    local Float = {
        Frame = Frame;
        Scale = Library:Create('UIScale', { Scale = Library.UIScale; Parent = Frame });
        Open = false;
    };
    -- below the anchor (above it if the screen runs out), kept on screen
    function Float:Place(Anchor, AlignRight)
        local Pos, Size = Anchor.AbsolutePosition, Anchor.AbsoluteSize;
        local View, Box = Gui.AbsoluteSize, Frame.AbsoluteSize;
        local X = AlignRight and (Pos.X + Size.X - Box.X) or Pos.X;
        X = math.clamp(X, 4, math.max(4, View.X - Box.X - 4));
        local Y = Pos.Y + Size.Y + 4;
        if View.Y > 0 and Y + Box.Y > View.Y - 4 and Pos.Y - Box.Y - 4 > 4 then
            Y = Pos.Y - Box.Y - 4;
        end;
        Frame.Position = UDim2.fromOffset(X, Y);
    end;
    return Float;
end;

function Library:OpenFloat(Float, Owner, OnClose)
    if Library.ActiveFloat and Library.ActiveFloat ~= Float then
        Library:CloseFloat();
    end;
    Library:SyncPopupOrder();
    Float.Scale.Scale = Library.UIScale;
    Float.Owner = Owner;
    Float.OnClose = OnClose;
    Float.Open = true;
    Float.Frame.Visible = true;
    Library.OpenedFrames[Float.Frame] = true;
    Library.ActiveFloat = Float;
end;

function Library:CloseFloat(Float)
    Float = Float or Library.ActiveFloat;
    if not Float or not Float.Open then return end;
    Float.Open = false;
    Float.Frame.Visible = false;
    Library.OpenedFrames[Float.Frame] = nil;
    if Library.ActiveFloat == Float then
        Library.ActiveFloat = nil;
    end;
    if Float.OnClose then pcall(Float.OnClose) end;
end;

Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
    local Float = Library.ActiveFloat;
    if not Float then return end;
    if Input.KeyCode == Enum.KeyCode.Escape then
        if Float.OnEscape and Float.OnEscape() then return end;
        Library:CloseFloat();
        return;
    end;
    local Type = Input.UserInputType;
    if Type ~= Enum.UserInputType.MouseButton1 and Type ~= Enum.UserInputType.MouseButton2 and Type ~= Enum.UserInputType.Touch then return end;
    if Library:IsMouseOverFrame(Float.Frame) or (Float.Owner and Library:IsMouseOverFrame(Float.Owner)) then return end;
    Library:CloseFloat();
end));

-- Row addons live in a holder just past the label's right edge, so the text truncates before them.
-- Fixed order, left to right: swatches, gear, keybind, toggle pill (keybinds line up in one column).
local ADDON_GAP = 6;
local AddonOrder = { ColorPicker = 10; Settings = 50; KeyPicker = 80; Pill = 100 };

local function AddonHolder(Owner)
    if Owner.AddonHolder then return Owner.AddonHolder end;
    local Label = Owner.TextLabel;
    local Holder = Library:Create('Frame', {
        AnchorPoint = Vector2.new(0, 0.5);
        BackgroundTransparency = 1;
        Name = 'Addons';
        Position = UDim2.new(1, ADDON_GAP, 0.5, 0);
        Size = UDim2.new(0, 0, 1, 0);
        ZIndex = Label.ZIndex;
        Parent = Label;
    });
    Library:Create('UIListLayout', {
        Padding = UDim.new(0, ADDON_GAP);
        FillDirection = Enum.FillDirection.Horizontal;
        HorizontalAlignment = Enum.HorizontalAlignment.Right;
        VerticalAlignment = Enum.VerticalAlignment.Center;
        SortOrder = Enum.SortOrder.LayoutOrder;
        Parent = Holder;
    });
    Label.TextTruncate = Enum.TextTruncate.AtEnd;
    Owner.AddonHolder = Holder;
    Owner.LabelSize = Label.Size;
    return Holder;
end;

-- Next LayoutOrder for an addon kind; several of one kind keep the order they were added in
local function AddonSlot(Owner, Kind)
    local Base, Count = AddonOrder[Kind], 0;
    for _, Child in ipairs(AddonHolder(Owner):GetChildren()) do
        local Order = Child:IsA('GuiObject') and Child.LayoutOrder or -1;
        if Order >= Base and Order < Base + 10 then
            Count = Count + 1;
        end;
    end;
    return Base + Count;
end;

-- Sizes the holder to its visible addons and gives the label whatever width is left
local function ArrangeAddons(Owner)
    local Holder = Owner.AddonHolder;
    if not Holder then return end;
    local Width, Count = 0, 0;
    for _, Child in ipairs(Holder:GetChildren()) do
        if Child:IsA('GuiObject') and Child.Visible then
            Width = Width + Child.Size.X.Offset;
            Count = Count + 1;
        end;
    end;
    if Count > 1 then Width = Width + (Count - 1) * ADDON_GAP end;
    Holder.Size = UDim2.new(0, Width, 1, 0);
    local Base = Owner.LabelSize;
    Owner.TextLabel.Size = UDim2.new(Base.X.Scale, Base.X.Offset - (Count > 0 and Width + ADDON_GAP or 0), Base.Y.Scale, Base.Y.Offset);
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
        local HasAlpha = Info.Transparency ~= nil;

        function ColorPicker:SetHSVFromRGB(Color)
            local H, S, V = Color3.toHSV(Color);
            ColorPicker.Hue = H;
            ColorPicker.Sat = S;
            ColorPicker.Vib = V;
        end;

        ColorPicker:SetHSVFromRGB(ColorPicker.Value);
        local DisplayFrame = Library:Create('Frame', {
            BackgroundColor3 = ColorPicker.Value;
            LayoutOrder = AddonSlot(self, 'ColorPicker');
            Size = UDim2.new(0, 26, 0, 14);
            ZIndex = 6;
            Parent = AddonHolder(self);
        });
        Library:Round(DisplayFrame, 3);
        Library:Stroke(DisplayFrame, 'OutlineColor');
        -- inset and shown only while see-through: a same-size light checker under the fill bleeds out of the rounded corners
        local CheckerFrame = Library:Create('ImageLabel', {
            BorderSizePixel = 0;
            Position = UDim2.fromOffset(1, 1);
            Size = UDim2.new(1, -2, 1, -2);
            ZIndex = 5;
            Image = 'http://www.roblox.com/asset/?id=12977615774';
            Visible = HasAlpha and ColorPicker.Transparency > 0;
            Parent = DisplayFrame;
        });
        Library:Round(CheckerFrame, 2);

        -- several swatches on one row shrink to compact chips
        self.Swatches = self.Swatches or {};
        table.insert(self.Swatches, DisplayFrame);
        if #self.Swatches > 1 or Info.Compact then
            for _, Swatch in ipairs(self.Swatches) do
                Swatch.Size = UDim2.new(0, 18, 0, 14);
            end;
        end;
        ArrangeAddons(self);

        -- Popup: header (title + swatch), saturation/value square, hue bar, alpha bar, hex + alpha footer
        local PAD, SQ, BAR, GAP, HEAD, FOOT = 10, 170, 12, 8, 30, 26;
        local Width = PAD + SQ + GAP + BAR + (HasAlpha and (GAP + BAR) or 0) + PAD;
        local Float = Library:CreateFloat(Width);
        local Panel = Float.Frame;
        Panel.Size = UDim2.fromOffset(Width, HEAD + SQ + 6 + FOOT + 2);

        Library:CreateLabel({
            Position = UDim2.fromOffset(PAD, 0);
            Size = UDim2.new(1, -PAD * 2 - 34, 0, HEAD);
            TextSize = Library.FontSize;
            Text = ColorPicker.Title;
            TextTruncate = Enum.TextTruncate.AtEnd;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 41;
            Parent = Panel;
        });
        local HeadSwatch = Library:Create('Frame', {
            AnchorPoint = Vector2.new(1, 0.5);
            BackgroundColor3 = ColorPicker.Value;
            Position = UDim2.new(1, -PAD, 0, HEAD / 2);
            Size = UDim2.fromOffset(26, 14);
            ZIndex = 42;
            Parent = Panel;
        });
        Library:Round(HeadSwatch, 3);
        if HasAlpha then
            local HeadChecker = Library:Create('ImageLabel', {
                BorderSizePixel = 0;
                Image = 'http://www.roblox.com/asset/?id=12977615774';
                Size = UDim2.new(1, 0, 1, 0);
                ZIndex = 41;
                Parent = HeadSwatch;
            });
            Library:Round(HeadChecker, 3);
        end;

        local SatVibMap = Library:Create('Frame', {
            BackgroundColor3 = Color3.fromHSV(ColorPicker.Hue, 1, 1);
            Position = UDim2.fromOffset(PAD, HEAD);
            Size = UDim2.fromOffset(SQ, SQ);
            ZIndex = 41;
            Parent = Panel;
        });
        Library:Round(SatVibMap, 4);
        local SatVibImage = Library:Create('ImageLabel', {
            BackgroundTransparency = 1;
            Image = 'rbxassetid://4155801252';
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 42;
            Parent = SatVibMap;
        });
        Library:Round(SatVibImage, 4);
        -- ring cursor: white over a faint dark ring so it reads on both ends of the square
        local CursorOuter = Library:Create('Frame', {
            AnchorPoint = Vector2.new(0.5, 0.5);
            BackgroundTransparency = 1;
            Size = UDim2.fromOffset(12, 12);
            ZIndex = 44;
            Parent = SatVibMap;
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(1, 0); Parent = CursorOuter });
        Library:Create('UIStroke', { Color = Color3.new(0, 0, 0); Transparency = 0.6; Thickness = 1; Parent = CursorOuter });
        local CursorInner = Library:Create('Frame', {
            AnchorPoint = Vector2.new(0.5, 0.5);
            BackgroundTransparency = 1;
            Position = UDim2.fromScale(0.5, 0.5);
            Size = UDim2.fromOffset(9, 9);
            ZIndex = 45;
            Parent = CursorOuter;
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(1, 0); Parent = CursorInner });
        Library:Create('UIStroke', { Color = Color3.new(1, 1, 1); Thickness = 1.5; Parent = CursorInner });

        local function BarHandle(Parent)
            local Handle = Library:Create('Frame', {
                AnchorPoint = Vector2.new(0.5, 0.5);
                BackgroundColor3 = Color3.new(1, 1, 1);
                Position = UDim2.fromScale(0.5, 0);
                Size = UDim2.new(1, 4, 0, 3);
                ZIndex = 45;
                Parent = Parent;
            });
            Library:Round(Handle, 1);
            Library:Create('UIStroke', { Color = Color3.new(0, 0, 0); Transparency = 0.55; Thickness = 1; Parent = Handle });
            return Handle;
        end;

        local HueBar = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(1, 1, 1);
            Position = UDim2.fromOffset(PAD + SQ + GAP, HEAD);
            Size = UDim2.fromOffset(BAR, SQ);
            ZIndex = 41;
            Parent = Panel;
        });
        Library:Round(HueBar, 3);
        local SequenceTable = {};
        for Hue = 0, 1, 0.1 do
            table.insert(SequenceTable, ColorSequenceKeypoint.new(Hue, Color3.fromHSV(Hue, 1, 1)));
        end;
        Library:Create('UIGradient', {
            Color = ColorSequence.new(SequenceTable);
            Rotation = 90;
            Parent = HueBar;
        });
        local HueCursor = BarHandle(HueBar);

        local AlphaBar, AlphaFill, AlphaCursor;
        if HasAlpha then
            AlphaBar = Library:Create('Frame', {
                BackgroundTransparency = 1;
                Position = UDim2.fromOffset(PAD + SQ + GAP + BAR + GAP, HEAD);
                Size = UDim2.fromOffset(BAR, SQ);
                ZIndex = 41;
                Parent = Panel;
            });
            local Checker = Library:Create('ImageLabel', {
                BorderSizePixel = 0;
                Image = 'http://www.roblox.com/asset/?id=12977615774';
                ScaleType = Enum.ScaleType.Tile;
                TileSize = UDim2.fromOffset(BAR, BAR);
                Size = UDim2.new(1, 0, 1, 0);
                ZIndex = 41;
                Parent = AlphaBar;
            });
            Library:Round(Checker, 3);
            AlphaFill = Library:Create('Frame', {
                BackgroundColor3 = ColorPicker.Value;
                Size = UDim2.new(1, 0, 1, 0);
                ZIndex = 42;
                Parent = AlphaBar;
            });
            Library:Round(AlphaFill, 3);
            Library:Create('UIGradient', {
                Rotation = 90;
                Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 0),
                    NumberSequenceKeypoint.new(1, 1),
                });
                Parent = AlphaFill;
            });
            AlphaCursor = BarHandle(AlphaBar);
        end;

        local HexBox = Library:Create('TextBox', {
            BackgroundTransparency = 1;
            ClearTextOnFocus = false;
            Font = Library.Font;
            PlaceholderColor3 = Library:GetDimColor();
            PlaceholderText = '#rrggbb';
            Position = UDim2.fromOffset(PAD, HEAD + SQ + 6);
            Size = UDim2.new(0.5, -PAD, 0, FOOT - 4);
            Text = '#ffffff';
            TextColor3 = Library.FontColor;
            TextSize = Library.FontSize;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 42;
            Parent = Panel;
        });
        Library:AddToRegistry(HexBox, {
            TextColor3 = 'FontColor';
            PlaceholderColor3 = function() return Library:GetDimColor() end;
        });
        local AlphaLabel = Library:CreateLabel({
            Dim = true;
            Position = UDim2.new(0.5, 0, 0, HEAD + SQ + 6);
            Size = UDim2.new(0.5, -PAD, 0, FOOT - 4);
            Text = 'alpha 255';
            TextSize = Library.FontSize - 1;
            TextXAlignment = Enum.TextXAlignment.Right;
            ZIndex = 42;
            Parent = Panel;
        });

        local ContextMenu = {}
        do
            ContextMenu.Options = {}
            ContextMenu.Container = Library:Create('Frame', {
                BorderColor3 = Color3.new(),
                ZIndex = 14,
                Visible = false,
                Parent = OverlayOf(ToggleLabel)
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
                ColorPicker:SetValueRGB(Library.ColorClipboard, ColorPicker.Transparency)
            end)

            ContextMenu:AddOption('Copy HEX', function()
                pcall(Exec.clipboard, ColorPicker.Value:ToHex())
                Library:Notify('Copied hex code to clipboard!', 2)
            end)

            ContextMenu:AddOption('Copy RGB', function()
                pcall(Exec.clipboard, table.concat({ math.floor(ColorPicker.Value.R * 255), math.floor(ColorPicker.Value.G * 255), math.floor(ColorPicker.Value.B * 255) }, ', '))
                Library:Notify('Copied RGB values to clipboard!', 2)
            end)
        end

        -- '#rgb', 'rrggbb' and '#rrggbb' are accepted
        local function ParseHex(Text)
            local Hex = tostring(Text or ''):gsub('%s', ''):gsub('^#', '');
            if #Hex == 3 then
                Hex = Hex:sub(1, 1):rep(2) .. Hex:sub(2, 2):rep(2) .. Hex:sub(3, 3):rep(2);
            end;
            if #Hex ~= 6 or Hex:find('[^%x]') then return nil end;
            return Color3.fromRGB(tonumber(Hex:sub(1, 2), 16), tonumber(Hex:sub(3, 4), 16), tonumber(Hex:sub(5, 6), 16));
        end;

        HexBox.FocusLost:Connect(function(Enter)
            local Color = Enter and ParseHex(HexBox.Text);
            if Color then
                ColorPicker:SetValueRGB(Color, ColorPicker.Transparency);
                Library:AttemptSave();
            else
                HexBox.Text = '#' .. ColorPicker.Value:ToHex();
            end;
        end);

        function ColorPicker:Display()
            ColorPicker.Value = Color3.fromHSV(ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib);
            SatVibMap.BackgroundColor3 = Color3.fromHSV(ColorPicker.Hue, 1, 1);

            Library:Create(DisplayFrame, {
                BackgroundColor3 = ColorPicker.Value;
                BackgroundTransparency = ColorPicker.Transparency;
                BorderColor3 = Library:GetDarkerColor(ColorPicker.Value);
            });
            CheckerFrame.Visible = HasAlpha and ColorPicker.Transparency > 0;
            HeadSwatch.BackgroundColor3 = ColorPicker.Value;
            HeadSwatch.BackgroundTransparency = ColorPicker.Transparency;
            if AlphaFill then
                AlphaFill.BackgroundColor3 = ColorPicker.Value;
                AlphaCursor.Position = UDim2.fromScale(0.5, ColorPicker.Transparency);
            end;

            CursorOuter.Position = UDim2.new(ColorPicker.Sat, 0, 1 - ColorPicker.Vib, 0);
            HueCursor.Position = UDim2.fromScale(0.5, ColorPicker.Hue);

            if not HexBox:IsFocused() then
                HexBox.Text = '#' .. ColorPicker.Value:ToHex();
            end;
            AlphaLabel.Text = 'alpha ' .. tostring(math.floor((1 - ColorPicker.Transparency) * 255 + 0.5));

            Library:SafeCallback(ColorPicker.Callback, ColorPicker.Value);
            Library:SafeCallback(ColorPicker.Changed, ColorPicker.Value);
        end;

        function ColorPicker:OnChanged(Func)
            ColorPicker.Changed = Func;
            Func(ColorPicker.Value)
        end;

        local function Place()
            Float:Place(DisplayFrame, true);
        end;
        function ColorPicker:Show()
            ContextMenu:Hide();
            Library:OpenFloat(Float, DisplayFrame);
            Place();
        end;
        function ColorPicker:Hide()
            Library:CloseFloat(Float);
        end;
        DisplayFrame:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
            if Float.Open then Place() end;
        end);

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

        -- press on Target, then follow the pointer until release
        local function Track(Target, Input, Update)
            if Input.UserInputType ~= Enum.UserInputType.MouseButton1 and Input.UserInputType ~= Enum.UserInputType.Touch then return end;
            local function Apply(Pos)
                local P, S = Target.AbsolutePosition, Target.AbsoluteSize;
                Update(
                    math.clamp((Pos.X - P.X) / math.max(S.X, 1), 0, 1),
                    math.clamp((Pos.Y - P.Y) / math.max(S.Y, 1), 0, 1)
                );
                ColorPicker:Display();
            end;
            Apply(Input.Position);
            local ChangedConn = InputService.InputChanged:Connect(function(Change)
                if Change.UserInputType == Enum.UserInputType.MouseMovement or Change == Input then
                    Apply(Change.Position);
                end;
            end);
            local EndedConn;
            EndedConn = InputService.InputEnded:Connect(function(EndInput)
                if EndInput == Input or EndInput.UserInputType == Enum.UserInputType.MouseButton1 or EndInput.UserInputType == Enum.UserInputType.Touch then
                    ChangedConn:Disconnect();
                    EndedConn:Disconnect();
                    Library:AttemptSave();
                end;
            end);
        end;

        SatVibMap.InputBegan:Connect(function(Input)
            Track(SatVibMap, Input, function(X, Y)
                ColorPicker.Sat = X;
                ColorPicker.Vib = 1 - Y;
            end);
        end);
        HueBar.InputBegan:Connect(function(Input)
            Track(HueBar, Input, function(_, Y)
                ColorPicker.Hue = Y;
            end);
        end);
        if AlphaBar then
            AlphaBar.InputBegan:Connect(function(Input)
                Track(AlphaBar, Input, function(_, Y)
                    ColorPicker.Transparency = Y;
                end);
            end);
        end;

        DisplayFrame.InputBegan:Connect(function(Input)
            if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) and not Library:MouseIsOverOpenedFrame() then
                if Float.Open then
                    ColorPicker:Hide()
                else
                    ColorPicker:Show()
                end;
            elseif Input.UserInputType == Enum.UserInputType.MouseButton2 and not Library:MouseIsOverOpenedFrame() then
                ColorPicker:Hide()
                ContextMenu:Show()
            end
        end);

        Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
            if not ContextMenu.Container.Visible then return end;
            if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                if not Library:IsMouseOverFrame(ContextMenu.Container) then
                    ContextMenu:Hide()
                end
            elseif Input.UserInputType == Enum.UserInputType.MouseButton2 then
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
        ColorPicker.Float = Float
        ColorPicker.HexBox = HexBox

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

        -- 18px rows: chip height keeps the row's parity so it centres on whole pixels
        -- CHIP_TEXT: chip text size at the default 13pt font, where the chip stays 16px
        local CHIP_ROW, CHIP_H, CHIP_PAD, CHIP_MIN, CHIP_TEXT = 18, 16, 6, 28, 11;
        local PickOuter = Library:Create('Frame', {
            BackgroundColor3 = Library.InputColor;
            LayoutOrder = AddonSlot(ParentObj, 'KeyPicker');
            Size = UDim2.fromOffset(CHIP_MIN, CHIP_H);
            ZIndex = 6;
            Parent = AddonHolder(ParentObj);
        });
        Library:Round(PickOuter, 3);
        local PickStroke = Library:Stroke(PickOuter, 'OutlineColor');
        Library:AddToRegistry(PickOuter, {
            BackgroundColor3 = 'InputColor';
        });
        local ChipLabel = Library:CreateLabel({
            Dim = true;
            Size = UDim2.fromScale(1, 1);
            TextSize = Library.FontSize - 2;
            TextXAlignment = Enum.TextXAlignment.Center;
            TextYAlignment = Enum.TextYAlignment.Center;
            Text = '';
            ZIndex = 8;
            Parent = PickOuter;
        });
        local ChipValue;
        local function SetChip(Value)
            ChipValue = Value;
            local Text = Value == '...' and '[...]' or '[' .. Library:KeyDisplayName(Value) .. ']';
            ChipLabel.Text = Text;
            local TW, TH = Library:GetTextBounds(Text, ChipLabel.Font, ChipLabel.TextSize);
            TW, TH = math.ceil(TW or 0), math.ceil(TH or 0);
            -- same parity as the text on both axes, so centring never lands on a half pixel
            local W = math.max(CHIP_MIN, TW + CHIP_PAD * 2);
            if (W - TW) % 2 == 1 then W = W + 1 end;
            local H = ChipLabel.TextSize > CHIP_TEXT and math.max(CHIP_H, TH + 4) or CHIP_H;
            if (CHIP_ROW - H) % 2 == 1 then H = H + 1 end;
            local Nudge = (H - TH) % 2;
            ChipLabel.Position = UDim2.fromOffset(0, Nudge);
            ChipLabel.Size = UDim2.new(1, 0, 1, -Nudge);
            PickOuter.Size = UDim2.fromOffset(W, H);
            ArrangeAddons(ParentObj);
        end;
        Library.KeyChips[PickOuter] = function() SetChip(ChipValue) end;
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
            Parent = OverlayOf(ToggleLabel);
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
            ClipsDescendants = true,
            Size = UDim2.new(1, 0, 0, 0),
            Visible = false,
            ZIndex = 110,
            Parent = Library.KeybindContainer,
        })
        KeybindEntry:SetAttribute('Shown', false);
        Library:Create('UIListLayout', {
            FillDirection = Enum.FillDirection.Horizontal,
            Padding = UDim.new(0, 6),
            SortOrder = Enum.SortOrder.LayoutOrder,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            Parent = KeybindEntry,
        })

        local StateDot = Library:Create('Frame', {
            BackgroundColor3 = Library:GetDimColor(),
            BorderSizePixel = 0,
            LayoutOrder = 1,
            Size = UDim2.fromOffset(6, 6),
            ZIndex = 111,
            Parent = KeybindEntry,
        })
        Library:Create('UICorner', { CornerRadius = UDim.new(1, 0), Parent = StateDot })
        Library:AddToRegistry(StateDot, { BackgroundColor3 = function() return Library:GetDimColor() end }, true)

        local function RowLabel(Order, Dim)
            return Library:CreateLabel({
                Dim = Dim,
                AutomaticSize = Enum.AutomaticSize.X,
                LayoutOrder = Order,
                Size = UDim2.new(0, 0, 1, 0),
                TextSize = Library.FontSize - 1,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 111,
                Parent = KeybindEntry,
            }, true)
        end
        local KeyLabel = RowLabel(2, false)
        local NameLabel = RowLabel(3, false)
        local ModeLabel = RowLabel(4, true)
        Library:RemoveFromRegistry(KeyLabel)
        Library:AddToRegistry(KeyLabel, { TextColor3 = 'AccentColor' }, true)
        KeyLabel.TextColor3 = Library.AccentColor

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

            KeyLabel.Text = string.format('[%s]', Library:KeyDisplayName(KeyPicker.Value));
            NameLabel.Text = tostring(Info.Text);
            ModeLabel.Text = string.format('%s', KeyPicker.Mode or '');
            local Want = false
            local kbMode = Library.KeybindMode or 'All'
            if kbMode == 'Active' then
                Want = State == true
            elseif kbMode == 'Toggled' then
                local parentOn = false
                if ParentObj and ParentObj.Type == 'Toggle' then
                    parentOn = ParentObj.Value == true
                elseif KeyPicker.SyncToggleState and ParentObj then
                    parentOn = ParentObj.Value == true
                else
                    parentOn = true
                end
                Want = parentOn
            else
                Want = true
            end

            local Filter = Library.KeybindFilter;
            if Filter.OnlyBound and (KeyPicker.Value == 'None' or Library:SideKeyHidden(KeyPicker.Value)) then
                Want = false;
            end;
            if Filter.OnlyEnabled then
                local On = State;
                if ParentObj and ParentObj.Type == 'Toggle' then On = ParentObj.Value == true end;
                if not On then Want = false end;
            end;

            NameLabel.TextColor3 = State and Library.AccentColor or Library.FontColor;
            Library.RegistryMap[NameLabel].Properties.TextColor3 = State and 'AccentColor' or 'FontColor';
            StateDot.BackgroundColor3 = State and Library.AccentColor or Library:GetDimColor();
            Library.RegistryMap[StateDot].Properties.BackgroundColor3 = State and 'AccentColor' or function() return Library:GetDimColor() end;

            Library:SetRowShown(KeybindEntry, Want)

            local YSize = 0
            local XSize = 0

            for _, Frame in next, Library.KeybindContainer:GetChildren() do
                if Frame:IsA('Frame') and Frame:GetAttribute('Shown') then
                    YSize = YSize + 18;
                    local Layout = Frame:FindFirstChildOfClass('UIListLayout')
                    if Layout and Layout.AbsoluteContentSize.X + 20 > XSize then
                        XSize = Layout.AbsoluteContentSize.X + 20
                    end
                end;
            end;

            local Target = UDim2.new(0, math.max(XSize + 10, 210), 0, YSize + 36)
            if Library.KeybindTarget ~= Target then
                Library.KeybindTarget = Target
                Library:Tween(Library.KeybindFrame, { Size = Target }, 0.16)
            end
        end;
        function KeyPicker:GetState()
            if KeyPicker.Mode == 'Always' then
                return true;
            elseif KeyPicker.Mode == 'Hold' then
                if KeyPicker.Value == 'None' then
                    return false;
                end

                return Library:IsBindDown(KeyPicker.Value);
            else
                return KeyPicker.Toggled;
            end;
        end;

        function KeyPicker:SetValue(Data)
            local Key, Mode = Data[1], Data[2];
            DisplayLabel.Text = Key;
            KeyPicker.Value = Key;
            ModeButtons[Mode]:Select();
            Library:UpdateSidePolling();
            KeyPicker:Update();
        end;

        -- Bind pressed (any source): flips Toggle-mode state.
        function KeyPicker:HandleBindPress(Key)
            if KeyPicker.Mode == 'Toggle' and not Library:IsMenuClick(Key) then
                KeyPicker.Toggled = not KeyPicker.Toggled;
                KeyPicker:DoClick();
            end;
            KeyPicker:Update();
        end;

        -- Applies a bind picked in binding mode.
        function KeyPicker:SetKey(Key, Raw)
            DisplayLabel.Text = Key;
            KeyPicker.Value = Key;
            Library:SafeCallback(KeyPicker.ChangedCallback, Raw or Key);
            Library:SafeCallback(KeyPicker.Changed, Raw or Key);
            Library:UpdateSidePolling();
            Library:AttemptSave();
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

            -- steady '[...]': animated dots would resize the chip and re-lay the row every tick
            DisplayLabel.Text = '...';

            wait(0.2);

            local Event;
            local function Finish(Key, Raw)
                Picking = false;
                Library.SideBinders[KeyPicker] = nil;
                Library.JustBound = true;
                task.delay(0, function() Library.JustBound = false end);
                if Event then Event:Disconnect() end;
                KeyPicker:SetKey(Key, Raw);
            end;

            Event = InputService.InputBegan:Connect(function(Input)
                local Key = Library:KeyNameFromInput(Input);
                if Key then
                    Finish(Key, Input.KeyCode or Input.UserInputType);
                end;
            end);
            Library.SideBinders[KeyPicker] = function(Key)
                Finish(Key, Key);
            end;
            Library:UpdateSidePolling();
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
                local Key = Library:KeyNameFromInput(Input);
                if Key and Key == KeyPicker.Value and not Library.JustBound and not Library.SliderEditor and not Library:IsTypingInput(Input) then
                    KeyPicker:HandleBindPress(Key);
                else
                    KeyPicker:Update();
                end;
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
        Library:UpdateSidePolling();
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
                BackgroundColor3 = Library.InputColor;
                Size = UDim2.new(1, 0, 0, 24);
                ZIndex = 5;
            });
            Library:Round(Outer, 5);
            local Stroke = Library:Stroke(Outer, 'OutlineColor');
            Library:AddToRegistry(Outer, {
                BackgroundColor3 = 'InputColor';
            });
            local Label = Library:CreateLabel({
                Size = UDim2.new(1, 0, 1, 0);
                TextSize = Library.FontSize;
                Text = Button.Text;
                ZIndex = 6;
                Parent = Outer;
            });
            Library:OnHover(Outer, Stroke, 'InputColor');
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
                Library:Tween(Button.Outer, { BackgroundColor3 = Library.InputColor }, 0.25)

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
            TextTruncate = Enum.TextTruncate.AtEnd;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 5;
            Parent = Container;
        });

        Groupbox:AddBlank(3);

        local TextBoxOuter = Library:Create('Frame', {
            BackgroundColor3 = Library.InputColor;
            Size = UDim2.new(1, 0, 0, 24);
            ZIndex = 5;
            Parent = Container;
        });
        Library:Round(TextBoxOuter, 5);
        local TextBoxStroke = Library:Stroke(TextBoxOuter, 'OutlineColor');
        Library:AddToRegistry(TextBoxOuter, {
            BackgroundColor3 = 'InputColor';
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
        Toggle.TextLabel = ToggleLabel;
        local Addons = AddonHolder(Toggle);

        local Pill = Library:Create('Frame', {
            BackgroundColor3 = Library.ToggleOffColor;
            LayoutOrder = AddonOrder.Pill;
            Size = UDim2.fromOffset(26, 12);
            ZIndex = 7;
            Parent = Addons;
        });
        Library:Round(Pill, 6);
        local PillStroke = Library:Stroke(Pill, 'OutlineColor');
        Library:AddToRegistry(Pill, {
            BackgroundColor3 = 'ToggleOffColor';
        });
        local OnFill = Library:Create('Frame', {
            BackgroundColor3 = Library.AccentColor;
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 8;
            Parent = Pill;
        });
        Library:Round(OnFill, 6);
        Library:AddToRegistry(OnFill, { BackgroundColor3 = 'AccentColor' });
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
        -- click/hover target for the switch, a few pixels larger than the 26x12 pill and above the row region
        local SwitchHit = Library:Create('Frame', {
            Name = 'SwitchHit';
            BackgroundTransparency = 1;
            Position = UDim2.fromOffset(-3, -3);
            Size = UDim2.new(1, 6, 1, 6);
            ZIndex = 11;
            Parent = Pill;
        });
        local HoverRow, HoverSwitch = false, false;
        local function PaintHover()
            local On = HoverSwitch or (HoverRow and Library.ToggleClickRow);
            if On and not Toggle.Value then
                Library:Tween(PillStroke, { Color = Library.AccentColor }, 0.12);
            elseif not On then
                Library:Tween(PillStroke, { Color = Library.OutlineColor }, 0.12);
            end;
        end;
        Library:Hover(ToggleRegion, function() HoverRow = true; PaintHover() end, function() HoverRow = false; PaintHover() end);
        Library:Hover(SwitchHit, function() HoverSwitch = true; PaintHover() end, function() HoverSwitch = false; PaintHover() end);

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
        local function Clicked(Input)
            return (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) and not Library:MouseIsOverOpenedFrame();
        end;
        SwitchHit.InputBegan:Connect(function(Input)
            if not Clicked(Input) then return end;
            Toggle:SetValue(not Toggle.Value)
            Library:AttemptSave();
        end);
        -- the whole row only flips the toggle with Library.ToggleClickRow; a click on the switch is SwitchHit's
        ToggleRegion.InputBegan:Connect(function(Input)
            if not Library.ToggleClickRow or not Clicked(Input) or Library:IsMouseOverFrame(SwitchHit) then return end;
            for _, Child in next, Addons:GetChildren() do
                if Child ~= Pill and Child:IsA('GuiObject') and Child.Visible and Library:IsMouseOverFrame(Child) then
                    return;
                end;
            end;

            Toggle:SetValue(not Toggle.Value)
            Library:AttemptSave();
        end);
        if Toggle.Risky then
            Library:RemoveFromRegistry(ToggleLabel)
            ToggleLabel.TextColor3 = Library.RiskColor
            Library:AddToRegistry(ToggleLabel, { TextColor3 = 'RiskColor' })
        end

        Toggle:Display(true);
        ArrangeAddons(Toggle);
        Groupbox:AddBlank(Info.BlankSize or 4);
        Groupbox:Resize();

        Toggle.Container = Container;
        Toggle.Switch = Pill;
        Toggle.SwitchHit = SwitchHit;
        Toggle.Region = ToggleRegion;
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
        local TitleLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 1, 0);
            TextSize = Library.FontSize;
            Text = Info.Text;
            TextTruncate = Enum.TextTruncate.AtEnd;
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
        if Info.Stepper then
            DisplayLabel.Size = UDim2.new(1, -44, 1, 0);
            local Step = tonumber(Info.Step) or (Info.Rounding == 0 and 1 or 10 ^ -Info.Rounding);
            local function StepButton(Text, XOffset, Dir)
                local Btn = Library:Create('TextButton', {
                    AnchorPoint = Vector2.new(1, 0.5);
                    AutoButtonColor = false;
                    BackgroundColor3 = Library.InputColor;
                    Font = Library.Font;
                    Position = UDim2.new(1, XOffset, 0.5, 0);
                    Size = UDim2.fromOffset(18, 14);
                    Text = Text;
                    TextColor3 = Library.FontColor;
                    TextSize = Library.FontSize;
                    ZIndex = 7;
                    Parent = Header;
                });
                Library:Round(Btn, 4);
                local BtnStroke = Library:Stroke(Btn, 'OutlineColor');
                Library:AddToRegistry(Btn, { BackgroundColor3 = 'InputColor'; TextColor3 = 'FontColor' });
                Library:OnHover(Btn, BtnStroke);
                Btn.MouseButton1Click:Connect(function()
                    local New = Slider.Value + Dir * Step;
                    Slider:SetValue(Slider.Rounding == 0 and math.floor(New + 0.5) or tonumber(string.format('%.' .. Slider.Rounding .. 'f', New)));
                    Library:AttemptSave();
                end);
            end;
            StepButton('+', 0, 1);
            StepButton('-', -22, -1);
        end;
        Groupbox:AddBlank(3);

        local SliderOuter = Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 0, 12);
            ZIndex = 5;
            Parent = Container;
        });
        local Track = Library:Create('Frame', {
            AnchorPoint = Vector2.new(0, 0.5);
            BackgroundColor3 = Library.TrackColor;
            Position = UDim2.new(0, 0, 0.5, 0);
            Size = UDim2.new(1, 0, 0, 4);
            ZIndex = 6;
            Parent = SliderOuter;
        });
        Library:Round(Track, 2);
        Library:AddToRegistry(Track, {
            BackgroundColor3 = 'TrackColor';
        });
        local Fill = Library:Create('Frame', {
            BackgroundColor3 = Library.AccentColor;
            Size = UDim2.new(0, 0, 1, 0);
            ZIndex = 7;
            Parent = Track;
        });
        Library:Round(Fill, 2);
        Library:AddToRegistry(Fill, { BackgroundColor3 = 'AccentColor' });
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

        Slider.Holder = SliderOuter;
        Library:Hover(SliderOuter, function()
            Library:Tween(Knob, { Size = UDim2.fromOffset(12, 12) }, 0.1);
        end, function()
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
            if Info.HideMax or (Info.HideMax == nil and not Library.SliderShowMax) then
                DisplayLabel.Text = tostring(Slider.Value) .. Suffix;
            else
                DisplayLabel.Text = tostring(Slider.Value) .. Suffix .. ' / ' .. tostring(Slider.Max) .. Suffix;
            end
            -- the title gives way to the value text and the stepper buttons
            local ValueW = Library:GetTextBounds(DisplayLabel.Text, Library.Font, Library.FontSize - 1) or 0;
            TitleLabel.Size = UDim2.new(1, -(ValueW + 8 + (Info.Stepper and 44 or 0)), 1, 0);

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
        local function OpenEditor()
            Library:CloseSliderEditor();
            local Box = Library:Create('TextBox', {
                AnchorPoint = Vector2.new(0, 0.5);
                BackgroundColor3 = Library.InputColor;
                ClearTextOnFocus = false;
                Font = Library.Font;
                Position = UDim2.new(0, 0, 0.5, 0);
                Size = UDim2.new(1, 0, 0, 18);
                Text = tostring(Slider.Value);
                TextColor3 = Library.FontColor;
                TextSize = Library.FontSize;
                ZIndex = 20;
                Parent = SliderOuter;
            });
            Library:Round(Box, 4);
            Library:Stroke(Box, 'AccentColor');
            local Done = false;
            local Editor = { Box = Box };
            function Editor.Close()
                if Done then return; end;
                Done = true;
                if Library.SliderEditor == Editor then Library.SliderEditor = nil; end;
                pcall(function() Box:Destroy() end);
            end;
            Library.SliderEditor = Editor;
            Box.FocusLost:Connect(function(EnterPressed)
                if Done then return; end;
                local Text = Box.Text;
                Editor.Close();
                if not EnterPressed then return; end;
                local Str = tostring(Text):match('[-+]?%d*%.?%d+[eE][-+]?%d+') or tostring(Text):match('[-+]?%d*%.?%d+');
                local Num = tonumber(Str);
                if not Num or Num ~= Num then return; end;
                Slider:SetValue(Round(math.clamp(Num, Slider.Min, Slider.Max)));
                Library:AttemptSave();
            end);
            pcall(function()
                Box:CaptureFocus();
                Box.SelectionStart = 1;
                Box.CursorPosition = #Box.Text + 1;
            end);
        end;
        SliderOuter.InputBegan:Connect(function(Input)
            if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) and not Library:MouseIsOverOpenedFrame() then
                if InputService:IsKeyDown(Enum.KeyCode.LeftControl) or InputService:IsKeyDown(Enum.KeyCode.RightControl) then
                    OpenEditor();
                    return;
                end;
                Library:CloseSliderEditor();
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
                TextTruncate = Enum.TextTruncate.AtEnd;
                TextXAlignment = Enum.TextXAlignment.Left;
                ZIndex = 5;
                Parent = Container;
            });
            Groupbox:AddBlank(3);
        end

        local ITEM_H = 24;
        local MAX_DROPDOWN_ITEMS = 8;
        local MIN_W = 170;

        local DropdownOuter = Library:Create('Frame', {
            BackgroundColor3 = Library.InputColor;
            Size = UDim2.new(1, 0, 0, 24);
            ZIndex = 5;
            Parent = Container;
        });
        Library:Round(DropdownOuter, 5);
        local DropdownStroke = Library:Stroke(DropdownOuter, 'OutlineColor');
        Library:AddToRegistry(DropdownOuter, {
            BackgroundColor3 = 'InputColor';
        });

        local DropdownArrow = Library:Create('ImageLabel', {
            AnchorPoint = Vector2.new(1, 0.5);
            BackgroundTransparency = 1;
            ImageColor3 = Library:GetDimColor();
            Position = UDim2.new(1, -7, 0.5, 0);
            Size = UDim2.new(0, 12, 0, 12);
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
            Text = 'None';
            TextXAlignment = Enum.TextXAlignment.Left;
            TextTruncate = Enum.TextTruncate.AtEnd;
            ZIndex = 7;
            Parent = DropdownOuter;
        });
        -- multi: "+N" for the selections after the first one
        local CountLabel = Library:CreateLabel({
            Dim = true;
            AnchorPoint = Vector2.new(1, 0);
            Position = UDim2.new(1, -24, 0, 0);
            Size = UDim2.new(0, 34, 1, 0);
            TextSize = Library.FontSize - 1;
            Text = '';
            TextXAlignment = Enum.TextXAlignment.Right;
            Visible = false;
            ZIndex = 7;
            Parent = DropdownOuter;
        });
        Library:OnHover(DropdownOuter, DropdownStroke);
        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, DropdownOuter)
        end

        -- Popup: muted header, divider, borderless rows, multi gets an All / None footer
        local Title = Info.Text or Info.Title;
        local HEAD_H = Title and 28 or 0;
        local SEARCH_H = 30;
        local FOOT_H = Info.Multi and 36 or 0;
        -- rows in Values order, and the values the search currently lets through
        local Rows, Shown = {}, {};
        local Float = Library:CreateFloat(MIN_W);
        local Panel = Float.Frame;
        if Title then
            Library:CreateLabel({
                Dim = true;
                Position = UDim2.fromOffset(10, 0);
                Size = UDim2.new(1, -20, 0, HEAD_H);
                TextSize = Library.FontSize - 1;
                Text = Info.Multi and (Title .. ' / multi-select') or Title;
                TextTruncate = Enum.TextTruncate.AtEnd;
                TextXAlignment = Enum.TextXAlignment.Left;
                ZIndex = 41;
                Parent = Panel;
            });
            local HeadLine = Library:Create('Frame', {
                BackgroundColor3 = Library.OutlineColor;
                Position = UDim2.fromOffset(0, HEAD_H - 1);
                Size = UDim2.new(1, 0, 0, 1);
                ZIndex = 41;
                Parent = Panel;
            });
            Library:AddToRegistry(HeadLine, { BackgroundColor3 = 'OutlineColor' });
        end;

        local SearchOuter = Library:Create('Frame', {
            Name = 'Search';
            Active = true;
            BackgroundColor3 = Library.InputColor;
            Position = UDim2.fromOffset(6, HEAD_H + 6);
            Size = UDim2.new(1, -12, 0, SEARCH_H - 6);
            Visible = false;
            ZIndex = 42;
            Parent = Panel;
        });
        Library:Round(SearchOuter, 4);
        local SearchStroke = Library:Stroke(SearchOuter, 'OutlineColor');
        Library:AddToRegistry(SearchOuter, { BackgroundColor3 = 'InputColor' });
        local SearchIcon = Library:Create('ImageLabel', {
            AnchorPoint = Vector2.new(0, 0.5);
            BackgroundTransparency = 1;
            ImageColor3 = Library:GetDimColor();
            Position = UDim2.new(0, 7, 0.5, 0);
            Size = UDim2.fromOffset(12, 12);
            ZIndex = 43;
            Parent = SearchOuter;
        });
        local SearchX = 8;
        if Library:ApplyIcon(SearchIcon, 'search') then
            Library:AddToRegistry(SearchIcon, { ImageColor3 = function() return Library:GetDimColor() end });
            SearchX = 24;
        else
            SearchIcon:Destroy();
        end;
        local SearchBox = Library:Create('TextBox', {
            BackgroundTransparency = 1;
            ClearTextOnFocus = false;
            Font = Library.Font;
            PlaceholderColor3 = Library:GetDimColor();
            PlaceholderText = 'Search...';
            Position = UDim2.fromOffset(SearchX, 0);
            Size = UDim2.new(1, -SearchX - 6, 1, 0);
            Text = '';
            TextColor3 = Library.FontColor;
            TextSize = Library.FontSize - 1;
            TextXAlignment = Enum.TextXAlignment.Left;
            TextTruncate = Enum.TextTruncate.AtEnd;
            ZIndex = 43;
            Parent = SearchOuter;
        });
        Library:AddToRegistry(SearchBox, { TextColor3 = 'FontColor'; PlaceholderColor3 = function() return Library:GetDimColor() end });

        local Scrolling = Library:Create('ScrollingFrame', {
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            CanvasSize = UDim2.new(0, 0, 0, 0);
            Position = UDim2.fromOffset(0, HEAD_H + 4);
            Size = UDim2.new(1, 0, 0, ITEM_H);
            ZIndex = 41;
            Parent = Panel;

            TopImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png',
            BottomImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png',

            ScrollBarThickness = 2,
            ScrollBarImageColor3 = Library.OutlineColor,
        });
        Library:AddToRegistry(Scrolling, {
            ScrollBarImageColor3 = 'OutlineColor'
        })
        Library:Create('UIPadding', {
            PaddingLeft = UDim.new(0, 4);
            PaddingRight = UDim.new(0, 6);
            Parent = Scrolling;
        });
        Library:Create('UIListLayout', {
            Padding = UDim.new(0, 0);
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = Scrolling;
        });

        local Footer;
        if Info.Multi then
            Footer = Library:Create('Frame', {
                AnchorPoint = Vector2.new(0, 1);
                BackgroundTransparency = 1;
                Position = UDim2.new(0, 0, 1, 0);
                Size = UDim2.new(1, 0, 0, FOOT_H);
                ZIndex = 41;
                Parent = Panel;
            });
            local FootLine = Library:Create('Frame', {
                BackgroundColor3 = Library.OutlineColor;
                Size = UDim2.new(1, 0, 0, 1);
                ZIndex = 41;
                Parent = Footer;
            });
            Library:AddToRegistry(FootLine, { BackgroundColor3 = 'OutlineColor' });
            local function FootButton(Name, XScale, XOffset, OnClick)
                local Btn = Library:Create('Frame', {
                    Name = Name;
                    Active = true;
                    BackgroundColor3 = Library.InputColor;
                    Position = UDim2.new(XScale, XOffset, 0, 7);
                    Size = UDim2.new(0.5, -12, 0, 22);
                    ZIndex = 42;
                    Parent = Footer;
                });
                Library:Round(Btn, 4);
                local BtnStroke = Library:Stroke(Btn, 'OutlineColor');
                Library:AddToRegistry(Btn, { BackgroundColor3 = 'InputColor' });
                Library:CreateLabel({
                    Size = UDim2.new(1, 0, 1, 0);
                    Text = Name;
                    TextSize = Library.FontSize - 1;
                    ZIndex = 43;
                    Parent = Btn;
                });
                Library:OnHover(Btn, BtnStroke, 'InputColor');
                Btn.InputBegan:Connect(function(Input)
                    if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                        OnClick();
                        Library:AttemptSave();
                    end;
                end);
                return Btn;
            end;
            -- both act only on the rows the search lets through
            local function SetShown(On)
                local New = {};
                for Value in next, Dropdown.Value do
                    New[Value] = true;
                end;
                for _, Value in ipairs(Shown) do
                    New[Value] = On or nil;
                end;
                Dropdown:SetValue(New);
            end;
            FootButton('All', 0, 8, function() SetShown(true) end);
            FootButton('None', 0.5, 4, function() SetShown(false) end);
        end;

        local ListHeight = ITEM_H;
        local function RecalculateListSize(Count)
            local Top = HEAD_H + (SearchOuter.Visible and SEARCH_H or 0);
            ListHeight = math.clamp(Count, 1, MAX_DROPDOWN_ITEMS) * ITEM_H;
            Scrolling.Position = UDim2.fromOffset(0, Top + 4);
            Scrolling.Size = UDim2.new(1, 0, 0, ListHeight);
            Scrolling.CanvasSize = UDim2.fromOffset(0, Count * ITEM_H);
            local Width = math.max(MIN_W, DropdownOuter.AbsoluteSize.X / math.max(Library.UIScale, 0.1));
            Panel.Size = UDim2.fromOffset(Width, Top + 4 + ListHeight + 4 + FOOT_H);
        end;

        local function Place()
            Float:Place(DropdownOuter, false);
        end;

        local function Searchable()
            if Info.Searchable ~= nil then return Info.Searchable and true or false end;
            return #Dropdown.Values > MAX_DROPDOWN_ITEMS;
        end;

        local EmptyLabel;
        local function Filter()
            SearchOuter.Visible = Searchable();
            local Query = SearchOuter.Visible and SearchBox.Text:lower() or '';
            Shown = {};
            for _, Row in ipairs(Rows) do
                local Match = Query == '' or tostring(Row.Value):lower():find(Query, 1, true) ~= nil;
                Row.Button.Visible = Match;
                if Match then table.insert(Shown, Row.Value) end;
            end;
            if EmptyLabel then
                EmptyLabel.Text = #Rows == 0 and 'No options' or 'No matches';
                EmptyLabel.Visible = #Shown == 0;
            end;
            RecalculateListSize(#Shown);
            if Float.Open then Place() end;
        end;

        local function FocusSearch()
            task.defer(function()
                if Float.Open and SearchOuter.Visible then
                    pcall(SearchBox.CaptureFocus, SearchBox);
                end;
            end);
        end;

        SearchBox:GetPropertyChangedSignal('Text'):Connect(function()
            Scrolling.CanvasPosition = Vector2.new(0, 0);
            Filter();
        end);
        SearchBox.Focused:Connect(function()
            Library:Tween(SearchStroke, { Color = Library.AccentColor }, 0.12);
        end);
        SearchBox.FocusLost:Connect(function(EnterPressed)
            Library:Tween(SearchStroke, { Color = Library.OutlineColor }, 0.12);
            if not (EnterPressed and Float.Open) then return end;
            local First = Shown[1];
            if Info.Multi or First == nil or SearchBox.Text == '' then
                FocusSearch();
                return;
            end;
            if Dropdown.Value ~= First then
                Dropdown:SetValue(First);
                Library:AttemptSave();
            end;
            Dropdown:CloseDropdown();
        end);
        -- Esc clears the search first, a second Esc closes
        function Float.OnEscape()
            if not SearchOuter.Visible or SearchBox.Text == '' then return false end;
            SearchBox.Text = '';
            FocusSearch();
            return true;
        end;
        DropdownOuter:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
            if Float.Open then Place() end;
        end);

        function Dropdown:Display()
            local Values = Dropdown.Values;

            if Info.Multi then
                local First, Count = nil, 0;
                for _, Value in ipairs(Values) do
                    if Dropdown.Value[Value] then
                        Count = Count + 1;
                        if First == nil then First = Value end;
                    end;
                end;
                ItemList.Text = First ~= nil and tostring(First) or 'None';
                CountLabel.Text = Count > 1 and ('+' .. tostring(Count - 1)) or '';
                CountLabel.Visible = Count > 1;
                ItemList.Size = UDim2.new(1, Count > 1 and -64 or -30, 1, 0);
            else
                ItemList.Text = Dropdown.Value ~= nil and tostring(Dropdown.Value) or 'None';
            end;
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
            Rows = {};

            for _, Element in next, Scrolling:GetChildren() do
                if Element:IsA('GuiObject') then
                    Element:Destroy();
                end;
            end;

            local Count = 0;

            for Idx, Value in ipairs(Values) do
                local Table = {};
                Count = Count + 1;

                local Button = Library:Create('Frame', {
                    Name = 'Row';
                    BackgroundColor3 = Library.HoverColor;
                    BackgroundTransparency = 1;
                    LayoutOrder = Count;
                    Size = UDim2.new(1, 0, 0, ITEM_H);
                    ZIndex = 42;
                    Active = true,
                    Parent = Scrolling;
                });
                Library:Round(Button, 4);
                Library:AddToRegistry(Button, {
                    BackgroundColor3 = 'HoverColor';
                });
                local Check = Library:Create('ImageLabel', {
                    AnchorPoint = Vector2.new(0, 0.5);
                    BackgroundTransparency = 1;
                    ImageColor3 = Library.FontColor;
                    Position = UDim2.new(0, 7, 0.5, 0);
                    Size = UDim2.fromOffset(12, 12);
                    Visible = false;
                    ZIndex = 43;
                    Parent = Button;
                });
                if Library:ApplyIcon(Check, 'check') then
                    Library:AddToRegistry(Check, { ImageColor3 = 'FontColor' });
                else
                    Check:Destroy();
                    Check = Library:CreateLabel({
                        Position = UDim2.fromOffset(6, 0);
                        Size = UDim2.new(0, 14, 1, 0);
                        Text = utf8 and utf8.char(0x2713) or 'v';
                        TextSize = Library.FontSize;
                        Visible = false;
                        ZIndex = 43;
                        Parent = Button;
                    });
                end;
                local ButtonLabel = Library:CreateLabel({
                    Active = false;
                    Size = UDim2.new(1, -32, 1, 0);
                    Position = UDim2.new(0, 26, 0, 0);
                    TextSize = Library.FontSize;
                    Text = tostring(Value);
                    TextXAlignment = Enum.TextXAlignment.Left;
                    TextTruncate = Enum.TextTruncate.AtEnd;
                    ZIndex = 43;
                    Parent = Button;
                });

                Library:Hover(Button, function()
                    Library:Tween(Button, { BackgroundTransparency = 0.55 }, 0.1);
                end, function()
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

                    Check.Visible = Selected and true or false;
                    ButtonLabel.Font = Selected and Library:BoldFont() or Library.Font;
                    ButtonLabel.TextColor3 = Selected and Library.FontColor or Library:GetDimColor();
                    Library.RegistryMap[ButtonLabel].Properties.TextColor3 = Selected and 'FontColor' or 'DimColor';
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
                            Library:UpdateDependencyBoxes();

                            Library:AttemptSave();
                        end;

                        -- a single choice is done once picked; multi stays open for more.
                        -- Deferred so other click-away handlers still see this float as open.
                        if not Info.Multi then
                            task.defer(Dropdown.CloseDropdown, Dropdown);
                        end;
                    end;
                end);

                Table:UpdateButton();

                Buttons[Button] = Table;
                table.insert(Rows, { Button = Button; Value = Value });
            end;

            EmptyLabel = Library:CreateLabel({
                Dim = true;
                Name = 'Empty';
                LayoutOrder = Count + 1;
                Size = UDim2.new(1, 0, 0, ITEM_H);
                Text = 'No options';
                TextSize = Library.FontSize - 1;
                TextXAlignment = Enum.TextXAlignment.Left;
                Visible = false;
                ZIndex = 43;
                Parent = Scrolling;
            });
            Library:Create('UIPadding', { PaddingLeft = UDim.new(0, 26); Parent = EmptyLabel });

            Dropdown:Display();
            Filter();
        end;

        function Dropdown:SetValues(NewValues)
            if NewValues then
                Dropdown.Values = NewValues;
            end;

            Dropdown:BuildDropdownList();
        end;

        function Dropdown:OpenDropdown()
            SearchBox.Text = '';
            Filter();
            -- bring the current single choice into view
            local Index = (not Info.Multi) and Dropdown.Value ~= nil and table.find(Dropdown.Values, Dropdown.Value);
            Scrolling.CanvasPosition = Vector2.new(0, Index and math.max(0, (Index - 1) * ITEM_H - (ListHeight - ITEM_H) / 2) or 0);
            Library:OpenFloat(Float, DropdownOuter, function()
                if SearchBox:IsFocused() then pcall(SearchBox.ReleaseFocus, SearchBox) end;
                Library:Tween(DropdownArrow, { Rotation = 0 }, 0.14);
            end);
            Place();
            Library:Tween(DropdownArrow, { Rotation = 180 }, 0.14);
            FocusSearch();
        end;

        function Dropdown:CloseDropdown()
            Library:CloseFloat(Float);
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
            Library:UpdateDependencyBoxes();
        end;

        DropdownOuter.InputBegan:Connect(function(Input)
            if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) and (Float.Open or not Library:MouseIsOverOpenedFrame()) then
                if Float.Open then
                    Dropdown:CloseDropdown();
                else
                    Dropdown:OpenDropdown();
                end;
            end;
        end);
        Dropdown:BuildDropdownList();

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
        end

        Groupbox:AddBlank(Info.BlankSize or 5);
        Groupbox:Resize();

        Dropdown.Float = Float;
        Dropdown.Button = DropdownOuter;
        Dropdown.List = Scrolling;
        Dropdown.Footer = Footer;
        Dropdown.Search = SearchBox;
        Options[Idx] = Dropdown;

        return Dropdown;
    end;
    -- Want: a value (true/false for toggles, an option for dropdowns; any selected one counts in a multi),
    -- a list of allowed values, or function(Value, Element) -> bool
    local function DependencyMet(Elem, Want)
        local Value = Elem.Value;
        if type(Want) == 'function' then
            return Want(Value, Elem) and true or false;
        end;
        if type(Want) == 'table' then
            for _, Allowed in next, Want do
                if DependencyMet(Elem, Allowed) then return true end;
            end;
            return false;
        end;
        if Elem.Type == 'Dropdown' and type(Value) == 'table' then
            return Value[Want] == true;
        end;
        return Value == Want;
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
        -- summed offsets like Groupbox:Resize; AbsoluteContentSize is in screen pixels and drifts under UIScale
        function Depbox:Resize()
            local Size = 0;
            for _, Element in next, Frame:GetChildren() do
                if Element:IsA('GuiObject') and Element.Visible then
                    Size = Size + Element.Size.Y.Offset;
                end;
            end;
            Holder.Size = UDim2.new(1, 0, 0, Size);
            Groupbox:Resize();
        end;

        Layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
            Depbox:Resize();
        end);
        Holder:GetPropertyChangedSignal('Visible'):Connect(function()
            Depbox:Resize();
        end);
        function Depbox:Update()
            local Show = true;
            for _, Dependency in next, Depbox.Dependencies do
                if not DependencyMet(Dependency[1], Dependency[2]) then
                    Show = false;
                    break;
                end;
            end;

            Depbox.Visible = Show;
            Holder.Visible = Show;
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
        Depbox.Holder = Holder;
        Depbox.Root = Groupbox.Root or Groupbox;

        setmetatable(Depbox, BaseGroupbox);

        table.insert(Library.DependencyBoxes, Depbox);

        return Depbox;
    end;

    -- Collapsible block: the header (arrow + name) folds the content and the groupbox resizes with it
    function Funcs:AddSection(Name, Opts)
        Opts = type(Opts) == 'table' and Opts or {};
        local Groupbox = self;
        local HEADER = 22;
        local Section = { Name = Name; Type = 'Section'; Collapsed = Opts.Collapsed == true; };

        local Holder = Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 0, HEADER);
            ZIndex = 5;
            Parent = Groupbox.Container;
        });
        local Header = Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 0, HEADER - 2);
            ZIndex = 6;
            Parent = Holder;
        });
        local Arrow = Library:Create('ImageLabel', {
            AnchorPoint = Vector2.new(0.5, 0.5);
            BackgroundTransparency = 1;
            ImageColor3 = Library:GetDimColor();
            Position = UDim2.fromOffset(7, (HEADER - 2) / 2);
            Rotation = Section.Collapsed and -90 or 0;
            Size = UDim2.fromOffset(14, 14);
            ZIndex = 7;
            Parent = Header;
        });
        local ArrowGlyph;
        if Library:ApplyIcon(Arrow, 'chevron-down') then
            Library:AddToRegistry(Arrow, { ImageColor3 = function() return Library:GetDimColor() end });
        else
            Arrow:Destroy();
            ArrowGlyph = Library:CreateLabel({
                Dim = true;
                Position = UDim2.fromOffset(0, 0);
                Size = UDim2.fromOffset(14, HEADER - 2);
                Text = Section.Collapsed and '+' or '-';
                TextSize = Library.FontSize;
                ZIndex = 7;
                Parent = Header;
            });
        end;
        Library:CreateLabel({
            Dim = true;
            Position = UDim2.fromOffset(20, 0);
            Size = UDim2.new(1, -20, 1, 0);
            Text = Name;
            TextSize = Library.FontSize - 1;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 7;
            Parent = Header;
        });
        local Line = Library:Create('Frame', {
            BackgroundColor3 = Library.OutlineColor;
            Position = UDim2.new(0, 0, 0, HEADER - 3);
            Size = UDim2.new(1, 0, 0, 1);
            ZIndex = 6;
            Parent = Holder;
        });
        Library:AddToRegistry(Line, { BackgroundColor3 = 'OutlineColor' });

        local Content = Library:Create('Frame', {
            BackgroundTransparency = 1;
            Position = UDim2.fromOffset(0, HEADER + 2);
            Size = UDim2.new(1, 0, 0, 0);
            Visible = not Section.Collapsed;
            ZIndex = 5;
            Parent = Holder;
        });
        local Layout = Library:Create('UIListLayout', {
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = Content;
        });

        function Section:Resize()
            local Inner = Section.Collapsed and 0 or Layout.AbsoluteContentSize.Y;
            Content.Size = UDim2.new(1, 0, 0, Inner);
            Holder.Size = UDim2.new(1, 0, 0, HEADER + (Section.Collapsed and 0 or (Inner + 4)));
            Groupbox:Resize();
        end;
        function Section:SetCollapsed(Bool)
            Section.Collapsed = not not Bool;
            Content.Visible = not Section.Collapsed;
            if ArrowGlyph then
                ArrowGlyph.Text = Section.Collapsed and '+' or '-';
            else
                Library:Tween(Arrow, { Rotation = Section.Collapsed and -90 or 0 }, 0.14);
            end;
            Section:Resize();
        end;
        function Section:Toggle()
            Section:SetCollapsed(not Section.Collapsed);
        end;
        Layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
            Section:Resize();
        end);
        Header.InputBegan:Connect(function(Input)
            if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) and not Library:MouseIsOverOpenedFrame() then
                Section:Toggle();
            end;
        end);

        Section.Container = Content;
        Section.Holder = Holder;
        Section.Root = Groupbox.Root or Groupbox;
        setmetatable(Section, BaseGroupbox);
        Section:Resize();
        return Section;
    end;

    -- While the pointer is over Frame the scrolling frames around it stop scrolling, so the wheel belongs to Frame.
    -- Counted per frame: two widgets entering/leaving in the same hover pass must not leave a column locked.
    local WheelHolds = setmetatable({}, { __mode = 'k' });
    -- Extra: optional function returning more scrolling frames to hold (a popup has no window ancestors)
    local function HoldWheel(Frame, Should, Extra)
        local Held = {};
        local function Release()
            for Side in next, Held do
                local Hold = WheelHolds[Side];
                if Hold then
                    Hold.Count = Hold.Count - 1;
                    if Hold.Count <= 0 then
                        WheelHolds[Side] = nil;
                        pcall(function() Side.ScrollingEnabled = Hold.Was end);
                    end;
                end;
            end;
            Held = {};
        end;
        local function Take(Side)
            if Held[Side] then return end;
            Held[Side] = true;
            local Hold = WheelHolds[Side];
            if not Hold then
                Hold = { Count = 0; Was = Side.ScrollingEnabled ~= false };
                WheelHolds[Side] = Hold;
                Side.ScrollingEnabled = false;
            end;
            Hold.Count = Hold.Count + 1;
        end;
        Library:Hover(Frame, function()
            if Should and not Should() then return end;
            local Cur = Frame.Parent;
            while Cur and Cur:IsA('GuiObject') do
                if Cur:IsA('ScrollingFrame') then Take(Cur) end;
                Cur = Cur.Parent;
            end;
            for _, Side in ipairs(Extra and Extra() or {}) do
                if Side.Parent then Take(Side) end;
            end;
        end, Release);
        Library:GiveSignal(Release);
        return Release;
    end;
    Library.HoldWheel = HoldWheel;

    local function IsPointer(Type)
        return Type == Enum.UserInputType.MouseButton1 or Type == Enum.UserInputType.Touch;
    end;

    -- 3D showcase with its own camera: drag orbits, wheel zooms, right/middle drag pans, double-click resets
    function Funcs:AddViewport(Idx, Info)
        Info = type(Info) == 'table' and Info or {};
        local Groupbox = self;
        local Container = Groupbox.Container;
        local Fill = Info.Height == 'Fill';
        local Height = math.max(40, tonumber(Info.Height) or 200);
        local LABEL_H = type(Info.Text) == 'string' and 17 or 0;

        local Viewport = {
            Type = 'Viewport';
            Model = nil;
            Owned = false;
            AutoRotate = Info.AutoRotate == true;
            RotateSpeed = tonumber(Info.RotateSpeed) or 24;
            IdleDelay = tonumber(Info.IdleDelay) or 1.5;
            Sensitivity = tonumber(Info.Sensitivity) or 0.4;
            MinPitch = math.clamp(tonumber(Info.MinPitch) or -80, -89, 89);
            MaxPitch = math.clamp(tonumber(Info.MaxPitch) or 80, -89, 89);
            DefaultYaw = tonumber(Info.Yaw) or 35;
            DefaultPitch = tonumber(Info.Pitch) or 15;
            FOV = math.clamp(tonumber(Info.FOV) or 40, 1, 120);
            Padding = tonumber(Info.Padding) or 1.1;
            MinZoom = tonumber(Info.MinZoom) or 0.5;
            MaxZoom = tonumber(Info.MaxZoom) or 3;
            Yaw = 0;
            Pitch = 0;
            Distance = 10;
            FitDistance = 10;
            MinDistance = 1;
            MaxDistance = 30;
            Radius = 1;
            Center = Vector3.new(0, 0, 0);
            Focus = Vector3.new(0, 0, 0);
            Spin = 0;
            LastInput = -math.huge;
            Dragging = false;
        };
        Viewport.Yaw, Viewport.Pitch = Viewport.DefaultYaw, math.clamp(Viewport.DefaultPitch, Viewport.MinPitch, Viewport.MaxPitch);

        local Holder = Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = Fill and UDim2.new(1, 0, 1, 0) or UDim2.new(1, 0, 0, LABEL_H + Height + 5);
            ZIndex = 5;
            Parent = Container;
        });
        if LABEL_H > 0 then
            Library:CreateLabel({
                Dim = true;
                Size = UDim2.new(1, 0, 0, 14);
                TextSize = Library.FontSize - 1;
                Text = Info.Text;
                TextXAlignment = Enum.TextXAlignment.Left;
                ZIndex = 5;
                Parent = Holder;
            });
        end;

        -- Background: a Color3 is fixed, a theme key (default InputColor) follows the theme
        local BgKey = type(Info.Background) == 'string' and Info.Background or 'InputColor';
        local BgFixed = typeof(Info.Background) == 'Color3' and Info.Background or nil;
        local View = Library:Create('ViewportFrame', {
            Active = true;
            BackgroundColor3 = BgFixed or Library[BgKey] or Library.InputColor;
            Position = UDim2.fromOffset(0, LABEL_H);
            Size = Fill and UDim2.new(1, 0, 1, -LABEL_H) or UDim2.new(1, 0, 0, Height);
            ZIndex = 5;
            Parent = Holder;
        });
        Library:Round(View, 5);
        local Stroke = Library:Stroke(View, 'OutlineColor');
        if not BgFixed then
            Library:AddToRegistry(View, { BackgroundColor3 = function() return Library[BgKey] or Library.InputColor end });
        end;
        Library:OnHover(View, Stroke);

        local Camera = Library:Create('Camera', { FieldOfView = Viewport.FOV; Parent = View });
        View.CurrentCamera = Camera;

        function Viewport:SetLighting(Light)
            Light = type(Light) == 'table' and Light or {};
            pcall(function()
                View.Ambient = typeof(Light.Ambient) == 'Color3' and Light.Ambient or Color3.fromRGB(150, 150, 160);
                View.LightColor = typeof(Light.LightColor) == 'Color3' and Light.LightColor or Color3.fromRGB(255, 255, 255);
                View.LightDirection = typeof(Light.LightDirection) == 'Vector3' and Light.LightDirection or Vector3.new(-1, -1, -0.6);
            end);
        end;
        Viewport:SetLighting(Info);

        local Empty = Library:CreateLabel({
            Dim = true;
            AnchorPoint = Vector2.new(0.5, 0.5);
            Position = UDim2.fromScale(0.5, 0.5);
            Size = UDim2.new(1, -16, 0, 16);
            Text = 'No model';
            TextSize = Library.FontSize - 1;
            ZIndex = 6;
            Parent = View;
        });
        local Hint;
        if Info.Hint ~= false then
            Hint = Library:CreateLabel({
                Dim = true;
                AnchorPoint = Vector2.new(0, 1);
                Position = UDim2.new(0, 8, 1, -5);
                Size = UDim2.new(1, -16, 0, 14);
                Text = type(Info.Hint) == 'string' and Info.Hint or ('drag to rotate ' .. (utf8 and utf8.char(0x2022) or '-') .. ' scroll to zoom');
                TextSize = Library.FontSize - 2;
                TextTruncate = Enum.TextTruncate.AtEnd;
                TextXAlignment = Enum.TextXAlignment.Left;
                ZIndex = 6;
                Parent = View;
            });
        end;
        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, View);
        end;
        -- shown in place of the model while there is none (a thumbnail while the real avatar loads)
        local Fallback = Library:Create('ImageLabel', {
            Name = 'Fallback';
            BackgroundTransparency = 1;
            ScaleType = Enum.ScaleType.Fit;
            Size = UDim2.fromScale(1, 1);
            Visible = false;
            ZIndex = 5;
            Parent = View;
        });
        local Status = Library:CreateLabel({
            Dim = true;
            Position = UDim2.fromOffset(8, 6);
            Size = UDim2.new(1, -16, 0, 14);
            Text = '';
            TextSize = Library.FontSize - 1;
            TextTruncate = Enum.TextTruncate.AtEnd;
            TextXAlignment = Enum.TextXAlignment.Left;
            Visible = false;
            ZIndex = 6;
            Parent = View;
        });
        local function SyncEmpty()
            local None = Viewport.Model == nil;
            Fallback.Visible = None and Viewport.Fallback ~= nil;
            Empty.Visible = None and Viewport.Fallback == nil;
        end;

        local function Apply()
            local Y, P = math.rad(Viewport.Yaw), math.rad(Viewport.Pitch);
            local F, D = Viewport.Focus, Viewport.Distance;
            local Flat = math.cos(P) * D;
            local Pos = Vector3.new(F.X + math.sin(Y) * Flat, F.Y + math.sin(P) * D, F.Z + math.cos(Y) * Flat);
            Camera.CFrame = CFrame.new(Pos, F);
        end;

        -- any input stops the idle spin; the hint fades after the first one
        local function Touched()
            Viewport.LastInput = os.clock();
            Viewport.Spin = 0;
            if Hint and not Viewport.Interacted then
                Viewport.Interacted = true;
                Library:Tween(Hint, { TextTransparency = 1 }, 0.4);
            end;
        end;

        local function Bounds(Model)
            local Ok, CF, Size = pcall(function()
                if Model:IsA('BasePart') then return Model.CFrame, Model.Size end;
                return Model:GetBoundingBox();
            end);
            if Ok and CF and Size then return CF.Position, Size end;
        end;

        -- KeepZoom also carries zoom and pan over when the new model is about the same size (a rebuilt preview)
        local function Fit(KeepAngles, KeepZoom)
            local Center, Size;
            if Viewport.Model then Center, Size = Bounds(Viewport.Model) end;
            local Radius = math.max(Size and Size.Magnitude / 2 or 1, 0.05);
            local FitDistance = Radius / math.sin(math.rad(Viewport.FOV) / 2) * Viewport.Padding;
            local Same = KeepZoom and math.abs(Radius / Viewport.Radius - 1) <= 0.15;
            local Ratio = Viewport.Distance / Viewport.FitDistance;
            local Offset = Viewport.Focus - Viewport.Center;
            Viewport.Center = Center or Vector3.new(0, 0, 0);
            Viewport.Focus = Viewport.Center;
            Viewport.Radius = Radius;
            Viewport.FitDistance = FitDistance;
            Viewport.MinDistance = math.min(Radius * Viewport.MinZoom, FitDistance);
            Viewport.MaxDistance = math.max(FitDistance * Viewport.MaxZoom, FitDistance);
            Viewport.Distance = FitDistance;
            if Same then
                Viewport.Distance = math.clamp(FitDistance * Ratio, Viewport.MinDistance, Viewport.MaxDistance);
                local Len, Max = Offset.Magnitude, Radius * 1.5;
                if Len > Max then Offset = Offset * (Max / Len) end;
                Viewport.Focus = Viewport.Center + Offset;
            end;
            if not KeepAngles then
                Viewport.Yaw = Viewport.DefaultYaw;
                Viewport.Pitch = math.clamp(Viewport.DefaultPitch, Viewport.MinPitch, Viewport.MaxPitch);
            end;
            Apply();
        end;

        -- Archivable = false would make Clone return nil; scripts are dropped so a showcase copy never runs code
        local function CloneModel(Model)
            local Ok, Copy = pcall(function()
                local Was = Model.Archivable;
                Model.Archivable = true;
                local Result = Model:Clone();
                Model.Archivable = Was;
                return Result;
            end);
            if not Ok or not Copy then return end;
            for _, Desc in ipairs(Copy:GetDescendants()) do
                if Desc:IsA('BaseScript') then pcall(function() Desc:Destroy() end) end;
            end;
            if not (Copy:IsA('Model') or Copy:IsA('BasePart')) then
                local Wrap = Instance.new('Model');
                Copy.Parent = Wrap;
                Copy = Wrap;
            end;
            return Copy;
        end;

        function Viewport:SetModel(Model, KeepView)
            local Old = Viewport.Model;
            if Old then
                if Viewport.Owned then
                    pcall(function() Old:Destroy() end);
                else
                    pcall(function() Old.Parent = Viewport.OldParent end);
                end;
            end;
            Viewport.Model, Viewport.Owned, Viewport.OldParent = nil, false, nil;
            if typeof(Model) == 'Instance' then
                if Info.Clone == false then
                    local Parent = Model.Parent;
                    if pcall(function() Model.Parent = View end) then
                        Viewport.Model, Viewport.OldParent = Model, Parent;
                    end;
                else
                    local Copy = CloneModel(Model);
                    if Copy then
                        Copy.Parent = View;
                        Viewport.Model, Viewport.Owned = Copy, true;
                    end;
                end;
            end;
            SyncEmpty();
            Fit(KeepView, KeepView and Old ~= nil);
            return Viewport.Model;
        end;

        -- a '%d' in the image is filled with the local UserId (rbxthumb avatar urls)
        function Viewport:SetFallback(Image)
            if type(Image) == 'number' then Image = 'rbxassetid://' .. Image end;
            if type(Image) ~= 'string' or Image == '' then Image = nil end;
            if Image and Image:find('%d', 1, true) then
                Image = Image:gsub('%%d', tostring(tonumber(LocalPlayer.UserId) or 0));
            end;
            Viewport.Fallback = Image;
            Fallback.Image = Image or '';
            SyncEmpty();
        end;

        function Viewport:SetStatus(Text)
            Text = Text ~= nil and tostring(Text) or '';
            Status.Text = Text;
            Status.Visible = Text ~= '';
        end;

        function Viewport:GetModel()
            return Viewport.Model;
        end;

        function Viewport:SetEmptyText(Text)
            Empty.Text = type(Text) == 'string' and Text or 'No model';
        end;
        Viewport:SetEmptyText(Info.EmptyText);

        function Viewport:ResetView()
            Viewport.Spin = 0;
            Fit(false);
        end;

        function Viewport:SetAutoRotate(Bool)
            Viewport.AutoRotate = not not Bool;
            if not Viewport.AutoRotate then Viewport.Spin = 0 end;
        end;

        function Viewport:SetVisible(Bool)
            Holder.Visible = not not Bool;
            Groupbox:Resize();
        end;

        -- DX/DY in pixels
        function Viewport:Orbit(DX, DY)
            local S = Viewport.Sensitivity;
            Viewport.Yaw = (Viewport.Yaw - (tonumber(DX) or 0) * S) % 360;
            Viewport.Pitch = math.clamp(Viewport.Pitch + (tonumber(DY) or 0) * S, Viewport.MinPitch, Viewport.MaxPitch);
            Apply();
        end;

        -- positive steps zoom in
        function Viewport:Zoom(Steps)
            Viewport.Distance = math.clamp(Viewport.Distance * (0.88 ^ (tonumber(Steps) or 0)), Viewport.MinDistance, Viewport.MaxDistance);
            Apply();
        end;

        -- moves the focus so the model follows the pointer, kept within 1.5 radii of the model centre
        function Viewport:Pan(DX, DY)
            DX, DY = tonumber(DX) or 0, tonumber(DY) or 0;
            local Y, P = math.rad(Viewport.Yaw), math.rad(Viewport.Pitch);
            local K = 2 * Viewport.Distance * math.tan(math.rad(Viewport.FOV) / 2) / math.max(View.AbsoluteSize.Y, 1);
            local RX, RZ = math.cos(Y), -math.sin(Y);
            local UX, UY, UZ = -math.sin(Y) * math.sin(P), math.cos(P), -math.cos(Y) * math.sin(P);
            local F, C = Viewport.Focus, Viewport.Center;
            local OX = F.X - C.X + (-RX * DX + UX * DY) * K;
            local OY = F.Y - C.Y + (UY * DY) * K;
            local OZ = F.Z - C.Z + (-RZ * DX + UZ * DY) * K;
            local Len, Max = math.sqrt(OX * OX + OY * OY + OZ * OZ), Viewport.Radius * 1.5;
            if Len > Max then
                OX, OY, OZ = OX / Len * Max, OY / Len * Max, OZ / Len * Max;
            end;
            Viewport.Focus = Vector3.new(C.X + OX, C.Y + OY, C.Z + OZ);
            Apply();
        end;

        local Drag;
        local function StopDrag()
            if not Drag then return end;
            for _, Conn in ipairs(Drag.Conns) do Conn:Disconnect() end;
            Drag = nil;
            Viewport.Dragging = false;
            Viewport.LastInput = os.clock();
        end;
        Library:GiveSignal(StopDrag);

        View.InputBegan:Connect(function(Input)
            local Type = Input.UserInputType;
            local Mode = IsPointer(Type) and 'Orbit'
                or ((Type == Enum.UserInputType.MouseButton2 or Type == Enum.UserInputType.MouseButton3) and 'Pan')
                or nil;
            if not Mode or Library:MouseIsOverOpenedFrame() then return end;
            if Type == Enum.UserInputType.MouseButton1 then
                local Now = os.clock();
                if Viewport.LastClick and Now - Viewport.LastClick < 0.35 then
                    Viewport.LastClick = nil;
                    StopDrag();
                    Touched();
                    Viewport:ResetView();
                    return;
                end;
                Viewport.LastClick = Now;
            end;
            StopDrag();
            Touched();
            local Last = Input.Position;
            Drag = { Mode = Mode; Conns = {} };
            Viewport.Dragging = true;
            table.insert(Drag.Conns, InputService.InputChanged:Connect(function(Change)
                if Change.UserInputType ~= Enum.UserInputType.MouseMovement and Change ~= Input then return end;
                local Pos = Change.Position;
                if not Pos or not Last then Last = Pos; return end;
                local DX, DY = Pos.X - Last.X, Pos.Y - Last.Y;
                Last = Pos;
                if Mode == 'Orbit' then Viewport:Orbit(DX, DY) else Viewport:Pan(DX, DY) end;
                Touched();
            end));
            table.insert(Drag.Conns, InputService.InputEnded:Connect(function(EndInput)
                if EndInput == Input or EndInput.UserInputType == Type then StopDrag() end;
            end));
        end);

        View.InputChanged:Connect(function(Input)
            if Input.UserInputType ~= Enum.UserInputType.MouseWheel or Library:MouseIsOverOpenedFrame() then return end;
            local Z = Input.Position and Input.Position.Z or 0;
            if Z ~= 0 then
                Viewport:Zoom(Z > 0 and 1 or -1);
                Touched();
            end;
        end);
        HoldWheel(View);

        -- idle spin eases in after IdleDelay and stops at once on input
        Library:GiveSignal(RunService.RenderStepped:Connect(function(Dt)
            if not Viewport.Model or not Holder.Parent or not Holder.Visible then return end;
            local Idle = Viewport.AutoRotate and not Viewport.Dragging and Library.Toggled
                and os.clock() - Viewport.LastInput >= Viewport.IdleDelay;
            local Target = Idle and Viewport.RotateSpeed or 0;
            if Target == 0 and Viewport.Spin == 0 then return end;
            Viewport.Spin = Viewport.Spin + (Target - Viewport.Spin) * math.min(1, (Dt or 0) * 2.5);
            if Target == 0 and math.abs(Viewport.Spin) < 0.05 then
                Viewport.Spin = 0;
                return;
            end;
            Viewport.Yaw = (Viewport.Yaw + Viewport.Spin * (Dt or 0)) % 360;
            Apply();
        end));

        Viewport.Holder = Holder;
        Viewport.Frame = View;
        Viewport.Camera = Camera;
        Viewport.FallbackImage = Fallback;
        Viewport.StatusLabel = Status;
        Viewport:SetFallback(Info.Fallback);
        Viewport:SetModel(Info.Model);

        Groupbox:Resize();
        if Idx ~= nil then Options[Idx] = Viewport end;
        return Viewport;
    end;

    -- Two-level tile grid (cases -> skins): an item with Children opens in place, a leaf toggles selection
    function Funcs:AddGallery(Idx, Info)
        Info = type(Info) == 'table' and Info or {};
        local Groupbox = self;
        local Container = Groupbox.Container;
        local TILE = math.max(32, tonumber(Info.MinTile) or tonumber(Info.TileSize) or 72);
        local Aspect = tonumber(Info.Aspect);
        local GAP, NAME_H, PAD_R = 6, 20, 6;
        local HEAD_H = Info.Header == false and 0 or 22;
        local HEAD_GAP = HEAD_H > 0 and 4 or 0;
        local TILE_H = TILE + NAME_H;
        local ROW_H, ROW_GAP = math.max(24, math.floor(tonumber(Info.RowHeight) or 52)), 4;
        local Virtual = Info.Virtual == true;
        local Fill = Info.Height == 'Fill';
        local Height = math.max(60, tonumber(Info.Height) or 240);
        local LABEL_H = type(Info.Text) == 'string' and 17 or 0;
        local SEARCH_H = Info.Search and 28 or 0;
        local TOP = LABEL_H + HEAD_H + HEAD_GAP + SEARCH_H;
        local Multi = Info.Multi == true;

        local Gallery = {
            Type = 'Gallery';
            Multi = Multi;
            Virtual = Virtual;
            View = (Virtual or Info.View == 'List') and 'List' or 'Grid';
            Items = {};
            Data = {};
            Path = {};
            Filter = '';
            Value = Multi and {} or nil;
            Tiles = {};
            Pool = {};
            Columns = 1;
            Callback = Info.Callback or function(Item, Path, Selected) end;
        };

        local function IdOf(Item)
            if Item.Id ~= nil then return Item.Id end;
            if Item.Name ~= nil then return Item.Name end;
            return Item;
        end;
        local function NameOf(Item)
            local Name = Item.Name ~= nil and Item.Name or Item.Id;
            return Name ~= nil and type(Name) ~= 'table' and tostring(Name) or '?';
        end;
        local function IsFolder(Item)
            return type(Item.Children) == 'table';
        end;
        local function Clean(List)
            local Out = {};
            if type(List) == 'table' then
                for _, Item in ipairs(List) do
                    if type(Item) == 'table' then table.insert(Out, Item) end;
                end;
            end;
            return Out;
        end;
        local function Copy(List)
            local Out = {};
            for Index, Item in ipairs(List) do Out[Index] = Item end;
            return Out;
        end;
        local function IsSelected(Id)
            if Multi then return Gallery.Value[Id] == true end;
            return Gallery.Value ~= nil and Gallery.Value == Id;
        end;
        local function Matches(Target, Item)
            return Item == Target or IdOf(Item) == Target;
        end;
        -- depth-first: the item (by id or by table) and the folders above it
        local function Locate(Target)
            local Trail = {};
            local function Walk(List)
                for _, Item in ipairs(Clean(List)) do
                    if Matches(Target, Item) then return Item end;
                    if IsFolder(Item) then
                        table.insert(Trail, Item);
                        local Hit = Walk(Item.Children);
                        if Hit then return Hit end;
                        table.remove(Trail);
                    end;
                end;
            end;
            local Item = Walk(Gallery.Items);
            if Item then return Item, Copy(Trail) end;
        end;
        local function Level()
            local Top = Gallery.Path[#Gallery.Path];
            return Clean(Top and Top.Children or Gallery.Items);
        end;

        local Holder = Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = Fill and UDim2.new(1, 0, 1, 0) or UDim2.new(1, 0, 0, TOP + Height + 5);
            ZIndex = 5;
            Parent = Container;
        });
        if LABEL_H > 0 then
            Library:CreateLabel({
                Dim = true;
                Size = UDim2.new(1, 0, 0, 14);
                TextSize = Library.FontSize - 1;
                Text = Info.Text;
                TextXAlignment = Enum.TextXAlignment.Left;
                ZIndex = 5;
                Parent = Holder;
            });
        end;

        local Header = Library:Create('Frame', {
            BackgroundTransparency = 1;
            Position = UDim2.fromOffset(0, LABEL_H);
            Size = UDim2.new(1, 0, 0, HEAD_H);
            Visible = HEAD_H > 0;
            ZIndex = 5;
            Parent = Holder;
        });
        local BackText = (utf8 and utf8.char(0x2039) or '<') .. ' Back';
        local BackW = Library:GetTextBounds(BackText, Library.Font, Library.FontSize - 1) + 16;
        local BackButton = Library:Create('Frame', {
            Name = 'Back';
            Active = true;
            BackgroundColor3 = Library.InputColor;
            Size = UDim2.fromOffset(BackW, HEAD_H - 2);
            Visible = false;
            ZIndex = 6;
            Parent = Header;
        });
        Library:Round(BackButton, 4);
        local BackStroke = Library:Stroke(BackButton, 'OutlineColor');
        Library:AddToRegistry(BackButton, { BackgroundColor3 = 'InputColor' });
        Library:CreateLabel({
            Size = UDim2.new(1, 0, 1, 0);
            Text = BackText;
            TextSize = Library.FontSize - 1;
            ZIndex = 7;
            Parent = BackButton;
        });
        Library:OnHover(BackButton, BackStroke, 'InputColor');
        local Title = Library:CreateLabel({
            Size = UDim2.new(1, -70, 1, 0);
            Text = '';
            TextSize = Library.FontSize;
            TextTruncate = Enum.TextTruncate.AtEnd;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 6;
            Parent = Header;
        });
        local Count = Library:CreateLabel({
            Dim = true;
            AnchorPoint = Vector2.new(1, 0);
            Position = UDim2.new(1, 0, 0, 0);
            Size = UDim2.new(0, 68, 1, 0);
            Text = '';
            TextSize = Library.FontSize - 1;
            TextXAlignment = Enum.TextXAlignment.Right;
            ZIndex = 6;
            Parent = Header;
        });

        local SearchBox, Syncing;
        if Info.Search then
            local SearchOuter = Library:Create('Frame', {
                BackgroundColor3 = Library.InputColor;
                Position = UDim2.fromOffset(0, LABEL_H + HEAD_H + HEAD_GAP);
                Size = UDim2.new(1, 0, 0, 24);
                ZIndex = 5;
                Parent = Holder;
            });
            Library:Round(SearchOuter, 5);
            local SearchStroke = Library:Stroke(SearchOuter, 'OutlineColor');
            Library:AddToRegistry(SearchOuter, { BackgroundColor3 = 'InputColor' });
            Library:OnHover(SearchOuter, SearchStroke);
            SearchBox = Library:Create('TextBox', {
                BackgroundTransparency = 1;
                ClearTextOnFocus = false;
                Font = Library.Font;
                PlaceholderColor3 = Library:GetDimColor();
                PlaceholderText = type(Info.Placeholder) == 'string' and Info.Placeholder or 'Search...';
                Position = UDim2.fromOffset(8, 0);
                Size = UDim2.new(1, -16, 1, 0);
                Text = '';
                TextColor3 = Library.FontColor;
                TextSize = Library.FontSize;
                TextXAlignment = Enum.TextXAlignment.Left;
                ZIndex = 6;
                Parent = SearchOuter;
            });
            Library:AddToRegistry(SearchBox, { TextColor3 = 'FontColor'; PlaceholderColor3 = function() return Library:GetDimColor() end });
            SearchBox.Focused:Connect(function() Library:Tween(SearchStroke, { Color = Library.AccentColor }, 0.12) end);
            SearchBox.FocusLost:Connect(function() Library:Tween(SearchStroke, { Color = Library.OutlineColor }, 0.12) end);
            SearchBox:GetPropertyChangedSignal('Text'):Connect(function()
                if not Syncing then Gallery:SetFilter(SearchBox.Text) end;
            end);
        end;

        local ListOuter = Library:Create('Frame', {
            BackgroundTransparency = 1;
            ClipsDescendants = true;
            Position = UDim2.fromOffset(0, TOP);
            Size = Fill and UDim2.new(1, 0, 1, -TOP) or UDim2.new(1, 0, 0, Height);
            ZIndex = 5;
            Parent = Holder;
        });
        local List = Library:Create('ScrollingFrame', {
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            CanvasSize = UDim2.new(0, 0, 0, 0);
            Size = UDim2.new(1, 0, 1, 0);
            TopImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png';
            BottomImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png';
            MidImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png';
            ScrollBarThickness = 2;
            ScrollBarImageColor3 = Library.OutlineColor;
            ZIndex = 6;
            Parent = ListOuter;
        });
        Library:AddToRegistry(List, { ScrollBarImageColor3 = 'OutlineColor' });
        -- 1px inset so tile strokes are not clipped at the edges
        Library:Create('UIPadding', {
            PaddingLeft = UDim.new(0, 1);
            PaddingTop = UDim.new(0, 1);
            PaddingRight = UDim.new(0, PAD_R);
            Parent = List;
        });
        -- a virtual list places its pooled rows itself
        local Grid = (not Virtual) and Library:Create('UIGridLayout', {
            CellPadding = UDim2.fromOffset(GAP, GAP);
            CellSize = UDim2.fromOffset(TILE, TILE_H);
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = List;
        }) or nil;
        local Empty = Library:CreateLabel({
            Dim = true;
            AnchorPoint = Vector2.new(0.5, 0.5);
            Position = UDim2.fromScale(0.5, 0.5);
            Size = UDim2.new(1, -16, 0, 16);
            Text = '';
            TextSize = Library.FontSize - 1;
            Visible = false;
            ZIndex = 7;
            Parent = ListOuter;
        });
        HoldWheel(ListOuter, function()
            return List.CanvasSize.Y.Offset > ListOuter.AbsoluteSize.Y / math.max(Library.UIScale, 0.1);
        end);
        -- status while items exist ('Loading...' under a filled list); with no items the empty label says it
        local StatusChip = Library:Create('Frame', {
            Name = 'Status';
            AnchorPoint = Vector2.new(0.5, 1);
            BackgroundColor3 = Library.MainColor;
            Position = UDim2.new(0.5, 0, 1, -6);
            Size = UDim2.fromOffset(80, 20);
            Visible = false;
            ZIndex = 12;
            Parent = ListOuter;
        });
        Library:Round(StatusChip, 5);
        Library:Stroke(StatusChip, 'OutlineColor');
        Library:AddToRegistry(StatusChip, { BackgroundColor3 = 'MainColor' });
        local StatusText = Library:CreateLabel({
            Dim = true;
            Size = UDim2.fromScale(1, 1);
            Text = '';
            TextSize = Library.FontSize - 1;
            ZIndex = 13;
            Parent = StatusChip;
        });

        local function ScrollY()
            local Pos = List.CanvasPosition;
            return Pos and Pos.Y or 0;
        end;

        -- OnEnd fires once per item count, so a page that adds nothing ends the paging
        local EndAt;
        local function CheckEnd()
            if type(Info.OnEnd) ~= 'function' or #Gallery.Path > 0 or #Gallery.Items == 0 or EndAt == #Gallery.Items then return end;
            local ViewH = ListOuter.AbsoluteSize.Y / math.max(Library.UIScale, 0.1);
            local Margin = tonumber(Info.EndThreshold) or ROW_H;
            if ScrollY() + ViewH < List.CanvasSize.Y.Offset - Margin then return end;
            EndAt = #Gallery.Items;
            task.spawn(Library.SafeCallback, Library, Info.OnEnd, Gallery);
        end;

        local Refresh;
        -- tiles stretch to fill the row; Info.Columns fixes the count, otherwise as many TileSize tiles as fit
        local function Layout()
            local W = List.AbsoluteSize.X / math.max(Library.UIScale, 0.1) - PAD_R - 1;
            if Virtual then
                Gallery.Columns = 1;
                local Count = #Gallery.Data;
                List.CanvasSize = UDim2.fromOffset(0, Count > 0 and (Count * (ROW_H + ROW_GAP) - ROW_GAP + 2) or 0);
                Refresh();
                CheckEnd();
                return;
            end;
            local Cols, CellW, CellH, Gap;
            if Gallery.View == 'List' then
                Cols, CellW, CellH, Gap = 1, math.max(24, math.floor(W)), ROW_H, ROW_GAP;
            else
                Cols = tonumber(Info.Columns) and math.max(1, math.floor(Info.Columns))
                    or math.max(1, math.floor((W + GAP) / (TILE + GAP)));
                CellW = math.max(24, math.floor((W - GAP * (Cols - 1)) / Cols));
                CellH = Aspect and math.max(NAME_H + 24, math.floor(CellW * Aspect)) or TILE_H;
                Gap = GAP;
            end;
            Gallery.Columns = Cols;
            Grid.CellPadding = UDim2.fromOffset(Gap, Gap);
            Grid.CellSize = UDim2.fromOffset(CellW, CellH);
            local Shown = 0;
            for _, Tile in ipairs(Gallery.Tiles) do
                if Tile.Frame.Visible then Shown = Shown + 1 end;
            end;
            local Rows = math.ceil(Shown / Cols);
            List.CanvasSize = UDim2.fromOffset(0, Rows > 0 and (Rows * (CellH + Gap) - Gap + 2) or 0);
            CheckEnd();
        end;
        List:GetPropertyChangedSignal('AbsoluteSize'):Connect(Layout);
        ListOuter:GetPropertyChangedSignal('AbsoluteSize'):Connect(function()
            if Virtual then Layout() end;
        end);
        -- Render resets the scroll before the canvas is re-measured; that reset must not page
        local Resetting = false;
        List:GetPropertyChangedSignal('CanvasPosition'):Connect(function()
            if Resetting then return end;
            if Virtual then Refresh() end;
            CheckEnd();
        end);

        -- one tooltip per gallery (tiles are rebuilt on every navigation)
        local Tip, TipName, TipSub, TipConn, TipOwner;
        local function HideTip()
            if TipConn then TipConn:Disconnect(); TipConn = nil end;
            TipOwner = nil;
            if Tip then Tip.Visible = false end;
        end;
        local function ShowTip(Tile)
            if Info.Tooltips == false or Library:MouseIsOverOpenedFrame() then return end;
            if not Tip then
                Tip = Library:Create('Frame', {
                    BackgroundColor3 = Library.MainColor;
                    Visible = false;
                    ZIndex = 100;
                    Parent = Library.ScreenGui;
                });
                Library:Round(Tip, 5);
                Library:Stroke(Tip, 'OutlineColor');
                Library:AddToRegistry(Tip, { BackgroundColor3 = 'MainColor' });
                TipName = Library:CreateLabel({
                    Position = UDim2.fromOffset(8, 5);
                    TextSize = Library.FontSize;
                    TextXAlignment = Enum.TextXAlignment.Left;
                    ZIndex = 101;
                    Parent = Tip;
                });
                TipSub = Library:CreateLabel({
                    Dim = true;
                    TextSize = Library.FontSize - 1;
                    TextXAlignment = Enum.TextXAlignment.Left;
                    ZIndex = 101;
                    Parent = Tip;
                });
                Gallery.Tooltip = Tip;
            end;
            local Item = Tile.Item;
            local Name = NameOf(Item);
            local Sub = Item.Subtitle ~= nil and tostring(Item.Subtitle)
                or (Tile.Folder and (#Clean(Item.Children) .. ' items') or nil);
            local NX, NY = Library:GetTextBounds(Name, Library.Font, Library.FontSize);
            local SX, SY = 0, 0;
            if Sub then SX, SY = Library:GetTextBounds(Sub, Library.Font, Library.FontSize - 1) end;
            TipName.Text = Name;
            TipName.Size = UDim2.fromOffset(NX, NY);
            TipSub.Visible = Sub ~= nil;
            TipSub.Text = Sub or '';
            TipSub.Position = UDim2.fromOffset(8, 7 + NY);
            TipSub.Size = UDim2.fromOffset(SX, SY);
            Tip.Size = UDim2.fromOffset(math.max(NX, SX) + 16, 10 + NY + (Sub and (SY + 2) or 0));
            Tip.Position = UDim2.fromOffset(Mouse.X + 15, Mouse.Y + 12);
            Tip.Visible = true;
            TipOwner = Tile;
            if TipConn then TipConn:Disconnect() end;
            TipConn = RunService.Heartbeat:Connect(function()
                Tip.Position = UDim2.fromOffset(Mouse.X + 15, Mouse.Y + 12);
            end);
        end;
        Library:GiveSignal(HideTip);

        local function Paint(Tile)
            local On = IsSelected(Tile.Id);
            Tile.Badge.Visible = On;
            Tile.Label.TextColor3 = On and Library.AccentColor or Library.FontColor;
            if not Tile.Hovered then
                Library:Tween(Tile.Stroke, { Color = On and Library.AccentColor or Library.OutlineColor }, 0.12);
            end;
        end;

        local function CheckBadge(Parent)
            local Badge = Library:Create('Frame', {
                Name = 'Badge';
                AnchorPoint = Vector2.new(1, 0);
                BackgroundColor3 = Library.AccentColor;
                Position = UDim2.new(1, -4, 0, 4);
                Size = UDim2.fromOffset(16, 16);
                Visible = false;
                ZIndex = 10;
                Parent = Parent;
            });
            Library:Round(Badge, 8);
            Library:AddToRegistry(Badge, { BackgroundColor3 = 'AccentColor' });
            local Check = Library:Create('ImageLabel', {
                AnchorPoint = Vector2.new(0.5, 0.5);
                BackgroundTransparency = 1;
                ImageColor3 = Color3.new(1, 1, 1);
                Position = UDim2.fromScale(0.5, 0.5);
                Size = UDim2.fromOffset(10, 10);
                ZIndex = 11;
                Parent = Badge;
            });
            if not Library:ApplyIcon(Check, 'check') then
                Check:Destroy();
                Library:Create('TextLabel', {
                    BackgroundTransparency = 1;
                    Font = Library:BoldFont();
                    Size = UDim2.fromScale(1, 1);
                    Text = utf8 and utf8.char(0x2713) or 'v';
                    TextColor3 = Color3.new(1, 1, 1);
                    TextSize = Library.FontSize - 2;
                    ZIndex = 11;
                    Parent = Badge;
                });
            end;
            return Badge;
        end;

        -- small MainColor chip with dim text (folder counts, Item.Badge); returns the chip and its width
        local function TagChip(Parent, Name, Text, X)
            local W = math.ceil(Library:GetTextBounds(Text, Library.Font, Library.FontSize - 2)) + 10;
            local Chip = Library:Create('Frame', {
                Name = Name;
                BackgroundColor3 = Library.MainColor;
                BackgroundTransparency = 0.15;
                Position = UDim2.fromOffset(X, 4);
                Size = UDim2.fromOffset(W, 14);
                ZIndex = 10;
                Parent = Parent;
            });
            Library:Round(Chip, 4);
            Library:AddToRegistry(Chip, { BackgroundColor3 = 'MainColor' });
            Library:CreateLabel({
                Dim = true;
                Size = UDim2.fromScale(1, 1);
                Text = Text;
                TextSize = Library.FontSize - 2;
                ZIndex = 11;
                Parent = Chip;
            });
            return Chip, W;
        end;

        local STAR = utf8 and utf8.char(0x2605) or '*';
        local function StarMark(Parent, Props)
            local Star = Library:Create('TextLabel', {
                Name = 'Star';
                BackgroundTransparency = 1;
                Font = Library.Font;
                Size = UDim2.fromOffset(14, 14);
                Text = STAR;
                TextColor3 = Library.AccentColor;
                TextSize = Library.FontSize;
                ZIndex = 10;
                Parent = Parent;
            });
            Library:AddToRegistry(Star, { TextColor3 = 'AccentColor' });
            for Key, Value in next, Props do Star[Key] = Value end;
            return Star;
        end;

        local Activate;
        local function BuildTile(Item, Order)
            local Tile = { Item = Item; Id = IdOf(Item); Folder = IsFolder(Item); Hovered = false };
            local Frame = Library:Create('Frame', {
                Name = 'Tile';
                Active = true;
                BackgroundColor3 = Library.InputColor;
                LayoutOrder = Order;
                ZIndex = 7;
                Parent = List;
            });
            Library:Round(Frame, 5);
            local Stroke = Library:Stroke(Frame, 'OutlineColor');
            Library.RegistryMap[Stroke].Properties.Color = function()
                return (Tile.Hovered or IsSelected(Tile.Id)) and Library.AccentColor or Library.OutlineColor;
            end;
            Library:AddToRegistry(Frame, { BackgroundColor3 = 'InputColor' });

            -- relative to the cell so Aspect (cell height from width) keeps the name row at the bottom
            local Art = Library:Create('Frame', {
                BackgroundTransparency = 1;
                Position = UDim2.fromOffset(4, 4);
                Size = UDim2.new(1, -8, 1, -(NAME_H + 6));
                ZIndex = 8;
                Parent = Frame;
            });
            local Icon = Library:GetIcon(Item.Image);
            if typeof(Item.Swatch) == 'Color3' then
                Art.BackgroundTransparency = 0;
                Art.BackgroundColor3 = Item.Swatch;
                Library:Round(Art, 4);
            elseif Icon then
                Library:Create('ImageLabel', {
                    BackgroundTransparency = 1;
                    Image = Icon.Image;
                    ImageRectOffset = Icon.ImageRectOffset;
                    ImageRectSize = Icon.ImageRectSize;
                    ScaleType = Enum.ScaleType.Fit;
                    Size = UDim2.fromScale(1, 1);
                    ZIndex = 8;
                    Parent = Art;
                });
            else
                local Place = Library:Create('ImageLabel', {
                    AnchorPoint = Vector2.new(0.5, 0.5);
                    BackgroundTransparency = 1;
                    ImageColor3 = Library:GetDimColor();
                    Position = UDim2.fromScale(0.5, 0.5);
                    Size = UDim2.fromOffset(22, 22);
                    ZIndex = 8;
                    Parent = Art;
                });
                if Library:ApplyIcon(Place, Tile.Folder and 'package' or 'paintbrush') then
                    Library:AddToRegistry(Place, { ImageColor3 = function() return Library:GetDimColor() end });
                else
                    Place:Destroy();
                    Library:CreateLabel({
                        Dim = true;
                        Size = UDim2.fromScale(1, 1);
                        Text = string.upper(string.sub(NameOf(Item), 1, 1));
                        TextSize = Library.FontSize + 6;
                        ZIndex = 8;
                        Parent = Art;
                    });
                end;
            end;

            Tile.Label = Library:CreateLabel({
                Position = UDim2.new(0, 6, 1, -(NAME_H + 2));
                Size = UDim2.new(1, -12, 0, NAME_H - 6);
                Text = NameOf(Item);
                TextSize = Library.FontSize - 1;
                TextTruncate = Enum.TextTruncate.AtEnd;
                ZIndex = 9;
                Parent = Frame;
            });
            Library.RegistryMap[Tile.Label].Properties.TextColor3 = function()
                return IsSelected(Tile.Id) and Library.AccentColor or Library.FontColor;
            end;

            -- rarity strip along the bottom edge
            if typeof(Item.Color) == 'Color3' then
                local Bar = Library:Create('Frame', {
                    Name = 'Rarity';
                    AnchorPoint = Vector2.new(0, 1);
                    BackgroundColor3 = Item.Color;
                    Position = UDim2.new(0, 6, 1, -2);
                    Size = UDim2.new(1, -12, 0, 2);
                    ZIndex = 9;
                    Parent = Frame;
                });
                Library:Round(Bar, 1);
            end;

            -- top-left, in order: folder count, favourite star, Item.Badge text
            local X = 4;
            if Tile.Folder then
                local _, W = TagChip(Frame, 'Count', tostring(#Clean(Item.Children)), X);
                X = X + W + 4;
            end;
            if Item.Star then
                StarMark(Frame, { Position = UDim2.fromOffset(X, 4) });
                X = X + 18;
            end;
            if Item.Badge ~= nil and tostring(Item.Badge) ~= '' then
                TagChip(Frame, 'Tag', tostring(Item.Badge), X);
            end;

            local Badge = CheckBadge(Frame);

            Library:Hover(Frame, function()
                Tile.Hovered = true;
                Library:Tween(Stroke, { Color = Library.AccentColor }, 0.12);
                Library:Tween(Frame, { BackgroundColor3 = Library.InputColor:Lerp(Library.FontColor, 0.06) }, 0.12);
                ShowTip(Tile);
            end, function()
                Tile.Hovered = false;
                Library:Tween(Stroke, { Color = IsSelected(Tile.Id) and Library.AccentColor or Library.OutlineColor }, 0.12);
                Library:Tween(Frame, { BackgroundColor3 = Library.InputColor }, 0.12);
                if TipOwner == Tile then HideTip() end;
            end);
            Frame.InputBegan:Connect(function(Input)
                if IsPointer(Input.UserInputType) and not Library:MouseIsOverOpenedFrame() then
                    Activate(Tile);
                end;
            end);

            Tile.Frame, Tile.Stroke, Tile.Badge = Frame, Stroke, Badge;
            Paint(Tile);
            return Tile;
        end;

        -- List view row: built once, re-bound to any item (the virtual list pools these)
        local ART = ROW_H - 12;
        local TEXT_X = 6 + ART + 10;
        local HoverButton = type(Info.HoverButton) == 'table' and Info.HoverButton or nil;

        local function ArrangeRow(Tile)
            local W, N = 0, 0;
            for _, Child in ipairs(Tile.Right:GetChildren()) do
                if Child:IsA('GuiObject') and Child.Visible then
                    W, N = W + Child.Size.X.Offset, N + 1;
                end;
            end;
            W = W + math.max(0, N - 1) * 6;
            Tile.Right.Size = UDim2.fromOffset(W, 20);
            local Room = -(TEXT_X + 8 + (W > 0 and W + 10 or 0));
            Tile.Label.Size = UDim2.new(1, Room, 0, 16);
            Tile.Sub.Size = UDim2.new(1, Room, 0, 14);
        end;

        local function NewRow()
            local Tile = { Hovered = false; Buttons = {}; Actions = {} };
            local Frame = Library:Create('Frame', {
                Name = 'Tile';
                Active = true;
                BackgroundColor3 = Library.InputColor;
                Size = UDim2.new(1, 0, 0, ROW_H);
                ZIndex = 7;
                Parent = List;
            });
            Library:Round(Frame, 5);
            local Stroke = Library:Stroke(Frame, 'OutlineColor');
            Library.RegistryMap[Stroke].Properties.Color = function()
                return (Tile.Hovered or IsSelected(Tile.Id)) and Library.AccentColor or Library.OutlineColor;
            end;
            Library:AddToRegistry(Frame, { BackgroundColor3 = 'InputColor' });

            local Art = Library:Create('Frame', {
                Name = 'Art';
                BackgroundColor3 = Library.MainColor;
                Position = UDim2.fromOffset(6, 6);
                Size = UDim2.fromOffset(ART, ART);
                ZIndex = 8;
                Parent = Frame;
            });
            Library:Round(Art, 4);
            Library:AddToRegistry(Art, { BackgroundColor3 = function()
                local Swatch = Tile.Item and Tile.Item.Swatch;
                return typeof(Swatch) == 'Color3' and Swatch or Library.MainColor;
            end });
            Tile.Image = Library:Create('ImageLabel', {
                BackgroundTransparency = 1;
                ScaleType = Enum.ScaleType.Fit;
                Size = UDim2.fromScale(1, 1);
                ZIndex = 9;
                Parent = Art;
            });
            Tile.Letter = Library:CreateLabel({
                Dim = true;
                Size = UDim2.fromScale(1, 1);
                Text = '';
                TextSize = Library.FontSize + 2;
                ZIndex = 9;
                Parent = Art;
            });
            Tile.Label = Library:CreateLabel({
                Position = UDim2.fromOffset(TEXT_X, 0);
                Text = '';
                TextSize = Library.FontSize;
                TextTruncate = Enum.TextTruncate.AtEnd;
                TextXAlignment = Enum.TextXAlignment.Left;
                ZIndex = 9;
                Parent = Frame;
            });
            Library.RegistryMap[Tile.Label].Properties.TextColor3 = function()
                return IsSelected(Tile.Id) and Library.AccentColor or Library.FontColor;
            end;
            Tile.Sub = Library:CreateLabel({
                Dim = true;
                Position = UDim2.fromOffset(TEXT_X, 0);
                Text = '';
                TextSize = Library.FontSize - 1;
                TextTruncate = Enum.TextTruncate.AtEnd;
                TextXAlignment = Enum.TextXAlignment.Left;
                ZIndex = 9;
                Parent = Frame;
            });
            Tile.Rarity = Library:Create('Frame', {
                Name = 'Rarity';
                Position = UDim2.fromOffset(2, 8);
                Size = UDim2.new(0, 2, 1, -16);
                Visible = false;
                ZIndex = 9;
                Parent = Frame;
            });
            Library:Round(Tile.Rarity, 1);

            -- right side, in order: Item.Badge text, star, Item.Actions, HoverButton, check
            local Right = Library:Create('Frame', {
                Name = 'Right';
                AnchorPoint = Vector2.new(1, 0.5);
                BackgroundTransparency = 1;
                Position = UDim2.new(1, -8, 0.5, 0);
                Size = UDim2.fromOffset(0, 20);
                ZIndex = 9;
                Parent = Frame;
            });
            Library:Create('UIListLayout', {
                FillDirection = Enum.FillDirection.Horizontal;
                HorizontalAlignment = Enum.HorizontalAlignment.Right;
                VerticalAlignment = Enum.VerticalAlignment.Center;
                Padding = UDim.new(0, 6);
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = Right;
            });
            Tile.Right = Right;
            Tile.Tag = Library:CreateLabel({
                Dim = true;
                Name = 'Tag';
                LayoutOrder = 1;
                Size = UDim2.fromOffset(0, 20);
                Text = '';
                TextSize = Library.FontSize - 1;
                Visible = false;
                ZIndex = 10;
                Parent = Right;
            });
            Tile.Star = StarMark(Right, { LayoutOrder = 2; Size = UDim2.fromOffset(14, 20); Visible = false });
            if HoverButton then
                Tile.Hover = Library:CreatePill(Right, tostring(HoverButton.Text or 'Play'), function()
                    if Tile.Item then Library:SafeCallback(HoverButton.Callback, Tile.Item, Tile) end;
                end, { Height = 20; ZIndex = 10 });
                Tile.Hover.Frame.LayoutOrder = 100;
                Tile.Hover.Frame.Visible = false;
                table.insert(Tile.Buttons, Tile.Hover);
            end;
            local Badge = CheckBadge(Right);
            Badge.AnchorPoint = Vector2.new(0, 0);
            Badge.LayoutOrder = 200;

            Library:Hover(Frame, function()
                Tile.Hovered = true;
                Library:Tween(Stroke, { Color = Library.AccentColor }, 0.12);
                Library:Tween(Frame, { BackgroundColor3 = Library.InputColor:Lerp(Library.FontColor, 0.06) }, 0.12);
                if Tile.Hover then
                    Tile.Hover.Frame.Visible = true;
                    ArrangeRow(Tile);
                end;
            end, function()
                Tile.Hovered = false;
                Library:Tween(Stroke, { Color = IsSelected(Tile.Id) and Library.AccentColor or Library.OutlineColor }, 0.12);
                Library:Tween(Frame, { BackgroundColor3 = Library.InputColor }, 0.12);
                if Tile.Hover then
                    Tile.Hover.Frame.Visible = false;
                    ArrangeRow(Tile);
                end;
            end);
            -- a press on one of the row's buttons belongs to that button, not to the row
            Frame.InputBegan:Connect(function(Input)
                if not Tile.Item or not IsPointer(Input.UserInputType) or Library:MouseIsOverOpenedFrame() then return end;
                for _, Button in ipairs(Tile.Buttons) do
                    if Button.Frame.Visible and Library:IsMouseOverFrame(Button.Frame) then return end;
                end;
                Activate(Tile);
            end);

            Tile.Frame, Tile.Stroke, Tile.Badge, Tile.Art = Frame, Stroke, Badge, Art;
            return Tile;
        end;

        local function BindRow(Tile, Item, Order)
            Tile.Item, Tile.Id, Tile.Folder = Item, IdOf(Item), IsFolder(Item);
            Tile.Frame.LayoutOrder = Order;
            local Swatch = typeof(Item.Swatch) == 'Color3' and Item.Swatch or nil;
            Tile.Art.BackgroundColor3 = Swatch or Library.MainColor;
            local Icon = (not Swatch) and Library:GetIcon(Item.Image) or nil;
            Tile.Image.Visible = Icon ~= nil;
            if Icon then
                Tile.Image.Image = Icon.Image;
                Tile.Image.ImageRectOffset = Icon.ImageRectOffset;
                Tile.Image.ImageRectSize = Icon.ImageRectSize;
            end;
            Tile.Letter.Visible = Swatch == nil and Icon == nil;
            Tile.Letter.Text = string.upper(string.sub(NameOf(Item), 1, 1));

            local SubText = Item.Subtitle ~= nil and tostring(Item.Subtitle)
                or (Tile.Folder and (#Clean(Item.Children) .. ' items') or nil);
            local NameY = SubText and math.floor((ROW_H - 32) / 2) or math.floor((ROW_H - 16) / 2);
            Tile.Label.Text = NameOf(Item);
            Tile.Label.Position = UDim2.fromOffset(TEXT_X, NameY);
            Tile.Sub.Text = SubText or '';
            Tile.Sub.Visible = SubText ~= nil;
            Tile.Sub.Position = UDim2.fromOffset(TEXT_X, NameY + 18);

            Tile.Rarity.Visible = typeof(Item.Color) == 'Color3';
            if Tile.Rarity.Visible then Tile.Rarity.BackgroundColor3 = Item.Color end;

            local TagText = Item.Badge ~= nil and tostring(Item.Badge) or '';
            Tile.Tag.Text = TagText;
            Tile.Tag.Visible = TagText ~= '';
            Tile.Tag.Size = UDim2.fromOffset(TagText ~= '' and math.ceil(Library:GetTextBounds(TagText, Library.Font, Library.FontSize - 1)) or 0, 20);
            Tile.Star.Visible = Item.Star == true;

            if Tile.ActionList ~= Item.Actions then
                for _, Pill in ipairs(Tile.Actions) do
                    local At = table.find(Tile.Buttons, Pill);
                    if At then table.remove(Tile.Buttons, At) end;
                    pcall(function() Pill.Frame:Destroy() end);
                end;
                Tile.Actions, Tile.ActionList = {}, Item.Actions;
                for Index, Action in ipairs(type(Item.Actions) == 'table' and Item.Actions or {}) do
                    if type(Action) == 'table' then
                        local Pill = Library:CreatePill(Tile.Right, tostring(Action.Text or Action[1] or '?'), function()
                            if Tile.Item then Library:SafeCallback(Action.Callback or Action[2], Tile.Item, Tile) end;
                        end, { Height = 20; ZIndex = 10 });
                        Pill.Frame.LayoutOrder = 10 + Index;
                        table.insert(Tile.Actions, Pill);
                        table.insert(Tile.Buttons, Pill);
                    end;
                end;
            end;
            ArrangeRow(Tile);
            Paint(Tile);
        end;

        local function MakeTile(Item, Order)
            if Gallery.View ~= 'List' then return BuildTile(Item, Order) end;
            local Tile = NewRow();
            BindRow(Tile, Item, Order);
            return Tile;
        end;

        -- only the rows in view exist; they are re-bound as the list scrolls
        function Refresh()
            if not Virtual then return end;
            local Stride = ROW_H + ROW_GAP;
            local ViewH = ListOuter.AbsoluteSize.Y / math.max(Library.UIScale, 0.1);
            local Need = math.max(1, math.ceil(ViewH / Stride) + 1);
            while #Gallery.Pool < Need do
                table.insert(Gallery.Pool, NewRow());
            end;
            local First = math.max(0, math.floor(ScrollY() / Stride));
            local Tiles = {};
            for Index, Row in ipairs(Gallery.Pool) do
                local At = First + Index;
                local Item = Index <= Need and Gallery.Data[At] or nil;
                if Item then
                    if Row.Item ~= Item then BindRow(Row, Item, At) end;
                    Row.Frame.Position = UDim2.fromOffset(0, (At - 1) * Stride);
                    Row.Frame.Visible = true;
                    table.insert(Tiles, Row);
                else
                    Row.Item, Row.Id = nil, nil;
                    Row.Frame.Visible = false;
                end;
            end;
            Gallery.Tiles = Tiles;
        end;

        local function Hits(Item, Query)
            local Fields = { NameOf(Item), Item.Subtitle, type(Item.Id) ~= 'table' and Item.Id or nil };
            for Index = 1, 3 do
                local Field = Fields[Index];
                if Field ~= nil and string.find(string.lower(tostring(Field)), Query, 1, true) then
                    return true;
                end;
            end;
            return false;
        end;

        local function ApplyFilter()
            local Query, Shown, Total = Gallery.Filter, 0, 0;
            local Data = {};
            if Virtual then
                for _, Item in ipairs(Level()) do
                    Total = Total + 1;
                    if Query == '' or Hits(Item, Query) then table.insert(Data, Item) end;
                end;
            else
                Total = #Gallery.Tiles;
                for _, Tile in ipairs(Gallery.Tiles) do
                    local Hit = Query == '' or Hits(Tile.Item, Query);
                    Tile.Frame.Visible = Hit;
                    if Hit then table.insert(Data, Tile.Item) end;
                end;
            end;
            Gallery.Data = Data;
            Shown = #Data;
            Count.Text = Query ~= '' and string.format('%d / %d', Shown, Total)
                or string.format('%d %s', Total, Total == 1 and 'item' or 'items');
            Empty.Text = Gallery.Status
                or (Total == 0 and (type(Info.EmptyText) == 'string' and Info.EmptyText or 'No items') or 'No matches');
            Empty.Visible = Shown == 0;
            StatusChip.Visible = Gallery.Status ~= nil and Shown > 0;
            if StatusChip.Visible then
                StatusText.Text = Gallery.Status;
                StatusChip.Size = UDim2.fromOffset(math.ceil(Library:GetTextBounds(Gallery.Status, Library.Font, Library.FontSize - 1)) + 20, 20);
            end;
            Layout();
        end;

        local function Render()
            HideTip();
            if not Virtual then
                for _, Tile in ipairs(Gallery.Tiles) do
                    pcall(function() Tile.Frame:Destroy() end);
                end;
                Gallery.Tiles = {};
                for Order, Item in ipairs(Level()) do
                    table.insert(Gallery.Tiles, MakeTile(Item, Order));
                end;
            end;
            local Top = Gallery.Path[#Gallery.Path];
            local X = Top and (BackW + 8) or 0;
            BackButton.Visible = Top ~= nil;
            Title.Text = Top and NameOf(Top) or (type(Info.Title) == 'string' and Info.Title or 'All');
            Title.Position = UDim2.fromOffset(X, 0);
            Title.Size = UDim2.new(1, -X - 72, 1, 0);
            Resetting = true;
            pcall(function() List.CanvasPosition = Vector2.new(0, 0) end);
            Resetting = false;
            ApplyFilter();
        end;

        local function SetQuery(Text)
            Text = Text == nil and '' or tostring(Text);
            local Query = string.lower(Text);
            Query = Query:gsub('^%s+', '');
            Query = Query:gsub('%s+$', '');
            Gallery.Filter = Query;
            if SearchBox and SearchBox.Text ~= Text then
                Syncing = true;
                SearchBox.Text = Text;
                Syncing = false;
            end;
        end;

        local function Navigate(Path)
            Gallery.Path = Path;
            SetQuery('');
            Render();
            Library:SafeCallback(Info.OnNavigate, Gallery.Path);
        end;

        local function Commit(Id, Bool, Item, Path)
            Bool = not not Bool;
            if IsSelected(Id) == Bool then return false end;
            if Multi then
                Gallery.Value[Id] = Bool or nil;
            elseif Bool then
                Gallery.Value = Id;
            else
                Gallery.Value = nil;
            end;
            for _, Tile in ipairs(Gallery.Tiles) do Paint(Tile) end;
            if Item then
                Library:SafeCallback(Gallery.Callback, Item, Path or {}, Bool);
            end;
            Library:SafeCallback(Gallery.Changed, Gallery.Value);
            return true;
        end;

        function Activate(Tile)
            if Tile.Folder then
                local Path = Copy(Gallery.Path);
                table.insert(Path, Tile.Item);
                Navigate(Path);
            else
                Commit(Tile.Id, not IsSelected(Tile.Id), Tile.Item, Copy(Gallery.Path));
                Library:AttemptSave();
            end;
        end;

        function Gallery:SetItems(Items)
            Gallery.Items = Clean(Items);
            EndAt = nil;
            -- stay in the open folder while it still exists
            local Path, List = {}, Gallery.Items;
            for _, Old in ipairs(Gallery.Path) do
                local Found;
                for _, Item in ipairs(Clean(List)) do
                    if IsFolder(Item) and IdOf(Item) == IdOf(Old) then Found = Item; break end;
                end;
                if not Found then break end;
                table.insert(Path, Found);
                List = Found.Children;
            end;
            Gallery.Path = Path;
            Render();
        end;

        -- Target: an id or an item table. A folder opens; a leaf opens the level that holds it.
        function Gallery:Open(Target)
            if Target == nil then return false end;
            local Item, Path;
            for _, Other in ipairs(Level()) do
                if Matches(Target, Other) then
                    Item, Path = Other, Copy(Gallery.Path);
                    break;
                end;
            end;
            if not Item then Item, Path = Locate(Target) end;
            if not Item then return false end;
            if IsFolder(Item) then table.insert(Path, Item) end;
            Navigate(Path);
            return true;
        end;

        function Gallery:Back()
            if #Gallery.Path == 0 then return false end;
            local Path = Copy(Gallery.Path);
            table.remove(Path);
            Navigate(Path);
            return true;
        end;

        function Gallery:Home()
            if #Gallery.Path > 0 then Navigate({}) end;
        end;

        function Gallery:SetFilter(Text)
            SetQuery(Text);
            ApplyFilter();
        end;

        -- fires Callback(item, path, bool) when the item is in the tree, and OnChanged
        function Gallery:SetSelected(Id, Bool)
            if Id == nil then return false end;
            if Bool == nil then Bool = true end;
            local Item, Path = Locate(Id);
            if Item then Id = IdOf(Item) end;
            return Commit(Id, Bool, Item, Path);
        end;

        function Gallery:IsSelected(Id)
            return Id ~= nil and IsSelected(Id);
        end;

        -- single: item, id (item is nil when the id is not in the tree); multi: { items }, { ids }
        function Gallery:GetSelected()
            if not Multi then
                if Gallery.Value == nil then return nil, nil end;
                return (Locate(Gallery.Value)), Gallery.Value;
            end;
            local Items, Ids, Seen = {}, {}, {};
            local function Walk(List)
                for _, Item in ipairs(Clean(List)) do
                    local Id = IdOf(Item);
                    if IsFolder(Item) then
                        Walk(Item.Children);
                    elseif Gallery.Value[Id] and not Seen[Id] then
                        Seen[Id] = true;
                        table.insert(Items, Item);
                        table.insert(Ids, Id);
                    end;
                end;
            end;
            Walk(Gallery.Items);
            for Id in next, Gallery.Value do
                if not Seen[Id] then table.insert(Ids, Id) end;
            end;
            return Items, Ids;
        end;

        -- replaces the selection without per-item callbacks; single: id or nil, multi: { id, ... } or { [id] = true }
        function Gallery:SetValue(Value)
            if Multi then
                local Set = {};
                if type(Value) == 'table' then
                    for Key, Val in next, Value do
                        if Val == true then Set[Key] = true elseif type(Key) == 'number' then Set[Val] = true end;
                    end;
                end;
                Gallery.Value = Set;
            else
                Gallery.Value = Value;
            end;
            for _, Tile in ipairs(Gallery.Tiles) do Paint(Tile) end;
            Library:SafeCallback(Gallery.Changed, Gallery.Value);
        end;

        function Gallery:OnChanged(Func)
            Gallery.Changed = Func;
            Func(Gallery.Value);
        end;

        function Gallery:SetVisible(Bool)
            Holder.Visible = not not Bool;
            if not Holder.Visible then HideTip() end;
            Groupbox:Resize();
        end;

        -- 'Grid' or 'List'; a virtual gallery is always a list
        function Gallery:SetView(View)
            View = View == 'List' and 'List' or 'Grid';
            if Virtual or View == Gallery.View then return false end;
            Gallery.View = View;
            Render();
            return true;
        end;

        -- adds to the root level without rebuilding the tiles already there (paged results); returns the count added
        function Gallery:AppendItems(Items)
            local Added = Clean(Items);
            for _, Item in ipairs(Added) do
                table.insert(Gallery.Items, Item);
            end;
            if #Added == 0 then return 0 end;
            if #Gallery.Path == 0 and not Virtual then
                local Base = #Gallery.Tiles;
                for Index, Item in ipairs(Added) do
                    table.insert(Gallery.Tiles, MakeTile(Item, Base + Index));
                end;
            end;
            ApplyFilter();
            return #Added;
        end;

        -- nil or '' clears it; shown in place of the empty text, or as a chip under the items
        function Gallery:SetStatus(Text)
            Text = Text ~= nil and tostring(Text) or '';
            Gallery.Status = Text ~= '' and Text or nil;
            ApplyFilter();
        end;

        function Gallery:Refresh()
            ApplyFilter();
        end;

        BackButton.InputBegan:Connect(function(Input)
            if IsPointer(Input.UserInputType) and not Library:MouseIsOverOpenedFrame() then
                Gallery:Back();
            end;
        end);

        if Info.Default ~= nil then
            if Multi then
                for _, Id in ipairs(type(Info.Default) == 'table' and Info.Default or { Info.Default }) do
                    Gallery.Value[Id] = true;
                end;
            else
                Gallery.Value = Info.Default;
            end;
        end;

        Gallery.Holder = Holder;
        Gallery.List = List;
        Gallery.Title = Title;
        Gallery.CountLabel = Count;
        Gallery.EmptyLabel = Empty;
        Gallery.BackButton = BackButton;
        Gallery.SearchBox = SearchBox;
        Gallery.ListOuter = ListOuter;
        Gallery.StatusChip = StatusChip;
        Gallery:SetItems(Info.Items);
        if Info.Status ~= nil then Gallery:SetStatus(Info.Status) end;

        Groupbox:Resize();
        if Idx ~= nil then Options[Idx] = Gallery end;
        return Gallery;
    end;

    function Funcs:AddPlayerList(Config)
        return Library:CreatePlayerList(self, Config);
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
            -- popups are not part of the page search
            if #Frames > 0 and not (self.Root or self).NoSearch then
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
    WrapSearch('AddPlayerList', function() return 'players' end);
    WrapSearch('AddViewport', InfoText);
    WrapSearch('AddGallery', InfoText);

    -- outside a groupbox (a canvas pane, any Frame): no search entry, nothing to resize
    local function LooseHost(Parent, What)
        local Wrapper = typeof(Parent) ~= 'Instance' and type(Parent) == 'table';
        if Wrapper and Parent.Container and Parent.Resize then return Parent end;
        local Frame = Wrapper and (Parent.Frame or Parent.Container) or Parent;
        assert(typeof(Frame) == 'Instance', What .. ': missing parent');
        return { Container = Frame; NoSearch = true; Resize = function() end };
    end;
    function Library:CreateViewport(Parent, Info)
        Info = type(Info) == 'table' and Info or {};
        return Funcs.AddViewport(LooseHost(Parent, 'CreateViewport'), Info.Idx, Info);
    end;
    function Library:CreateGallery(Parent, Info)
        Info = type(Info) == 'table' and Info or {};
        return Funcs.AddGallery(LooseHost(Parent, 'CreateGallery'), Info.Idx, Info);
    end;

    BaseGroupbox.__index = Funcs;
    BaseGroupbox.__namecall = function(Table, Key, ...)
        return Funcs[Key](...);
    end;
end;
-- Chain extra listeners onto an element without losing the user's OnChanged handler
function Library:AddChangedHook(Element, Hook)
    if type(Element) ~= 'table' or type(Hook) ~= 'function' then return end;
    if not Element.Hooks then
        local Hooks = {};
        local User = Element.Changed;
        Element.Hooks = Hooks;
        Element.Changed = function(...)
            if User then User(...) end;
            for _, H in ipairs(Hooks) do pcall(H, ...) end;
        end;
        Element.OnChanged = function(_, Func)
            User = Func;
            Func(Element.Value);
        end;
    end;
    table.insert(Element.Hooks, Hook);
end;

-- Canvas widgets --------------------------------------------------------------
-- Building blocks for full-area canvases (Tab:AddCanvas); each also works in any Frame.
local function FrameOf(Parent)
    if typeof(Parent) ~= 'Instance' and type(Parent) == 'table' then return Parent.Container or Parent.Frame end;
    return Parent;
end;

local function IsClick(Input)
    return (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch)
        and not Library:MouseIsOverOpenedFrame();
end;

-- Info: { Color = 'MainColor', Position, Size, Radius = 6, ZIndex = 5 }. Returns the frame and its stroke.
function Library:CreateBevel(Parent, Info)
    Info = type(Info) == 'table' and Info or {};
    local Key = type(Info.Color) == 'string' and Info.Color or 'MainColor';
    local Frame = Library:Create('Frame', {
        BackgroundColor3 = Library[Key];
        Position = Info.Position or UDim2.new(0, 0, 0, 0);
        Size = Info.Size or UDim2.new(1, 0, 1, 0);
        ZIndex = Info.ZIndex or 5;
        Parent = FrameOf(Parent);
    });
    Library:Round(Frame, Info.Radius or 6);
    local Stroke = Library:Stroke(Frame, 'OutlineColor');
    Library:AddToRegistry(Frame, { BackgroundColor3 = Key });
    return Frame, Stroke;
end;

-- Info: { Height = 22, Width = nil (fit text) | number | 'Fill', Position, ZIndex = 6, Active = false }
function Library:CreatePill(Parent, Text, Callback, Info)
    Info = type(Info) == 'table' and Info or {};
    local H = math.max(14, math.floor(tonumber(Info.Height) or 22));
    local Z = Info.ZIndex or 6;
    local Pill = { Type = 'Pill'; Text = ''; Active = Info.Active == true; Hovered = false; Callback = Callback };
    local Frame = Library:Create('Frame', {
        Name = 'Pill';
        Active = true;
        BackgroundColor3 = Library.MainColor;
        Position = Info.Position or UDim2.new(0, 0, 0, 0);
        Size = UDim2.fromOffset(40, H);
        ZIndex = Z;
        Parent = FrameOf(Parent);
    });
    Library:Round(Frame, math.min(6, math.floor(H / 2)));
    local Stroke = Library:Stroke(Frame, 'OutlineColor');
    Library.RegistryMap[Stroke].Properties.Color = function()
        return (Pill.Active or Pill.Hovered) and Library.AccentColor or Library.OutlineColor;
    end;
    Library:AddToRegistry(Frame, { BackgroundColor3 = 'MainColor' });
    local Label = Library:CreateLabel({
        Size = UDim2.fromScale(1, 1);
        Text = '';
        TextSize = Library.FontSize - 1;
        TextTruncate = Enum.TextTruncate.AtEnd;
        ZIndex = Z + 1;
        Parent = Frame;
    });
    Library.RegistryMap[Label].Properties.TextColor3 = function()
        return Pill.Active and Library.AccentColor or Library.FontColor;
    end;

    local function Paint()
        Library:Tween(Stroke, { Color = (Pill.Active or Pill.Hovered) and Library.AccentColor or Library.OutlineColor }, 0.12);
        Label.TextColor3 = Pill.Active and Library.AccentColor or Library.FontColor;
    end;
    function Pill:SetText(NewText)
        Pill.Text = NewText ~= nil and tostring(NewText) or '';
        Label.Text = Pill.Text;
        if Info.Width == 'Fill' then
            Frame.Size = UDim2.new(1, 0, 0, H);
            Pill.Width = 0;
        else
            Pill.Width = tonumber(Info.Width) and math.floor(Info.Width)
                or (math.ceil(Library:GetTextBounds(Pill.Text, Library.Font, Library.FontSize - 1)) + (H >= 22 and 20 or 16));
            Frame.Size = UDim2.fromOffset(Pill.Width, H);
        end;
    end;
    function Pill:SetActive(Bool)
        Pill.Active = not not Bool;
        Paint();
    end;
    function Pill:SetVisible(Bool)
        Frame.Visible = not not Bool;
    end;

    Library:Hover(Frame, function()
        Pill.Hovered = true;
        Paint();
    end, function()
        Pill.Hovered = false;
        Paint();
    end);
    Frame.InputBegan:Connect(function(Input)
        if IsClick(Input) then Library:SafeCallback(Pill.Callback, Pill) end;
    end);

    Pill.Frame, Pill.Label, Pill.Stroke = Frame, Label, Stroke;
    Pill:SetText(Text);
    Paint();
    return Pill;
end;

-- Info: { Height = 24, Icon = nil, Text = '', Position, Size, ZIndex = 6, Callback = fn(text, enter), Changed = fn(text) }
function Library:CreateInput(Parent, Placeholder, Info)
    Info = type(Info) == 'table' and Info or {};
    local H = math.max(18, math.floor(tonumber(Info.Height) or 24));
    local Z = Info.ZIndex or 6;
    local Input = { Type = 'Input'; Callback = Info.Callback; Changed = Info.Changed };
    local Frame = Library:Create('Frame', {
        BackgroundColor3 = Library.InputColor;
        Position = Info.Position or UDim2.new(0, 0, 0, 0);
        Size = Info.Size or UDim2.new(1, 0, 0, H);
        ZIndex = Z;
        Parent = FrameOf(Parent);
    });
    Library:Round(Frame, 5);
    local Stroke = Library:Stroke(Frame, 'OutlineColor');
    Library:AddToRegistry(Frame, { BackgroundColor3 = 'InputColor' });
    local X = 8;
    if Info.Icon then
        local Icon = Library:Create('ImageLabel', {
            AnchorPoint = Vector2.new(0, 0.5);
            BackgroundTransparency = 1;
            ImageColor3 = Library:GetDimColor();
            Position = UDim2.new(0, 8, 0.5, 0);
            Size = UDim2.fromOffset(14, 14);
            ZIndex = Z + 1;
            Parent = Frame;
        });
        if Library:ApplyIcon(Icon, Info.Icon) then
            Library:AddToRegistry(Icon, { ImageColor3 = function() return Library:GetDimColor() end });
            X = 28;
        else
            Icon:Destroy();
        end;
    end;
    local Box = Library:Create('TextBox', {
        BackgroundTransparency = 1;
        ClearTextOnFocus = false;
        Font = Library.Font;
        PlaceholderColor3 = Library:GetDimColor();
        PlaceholderText = Placeholder ~= nil and tostring(Placeholder) or '';
        Position = UDim2.fromOffset(X, 0);
        Size = UDim2.new(1, -X - 8, 1, 0);
        Text = Info.Text ~= nil and tostring(Info.Text) or '';
        TextColor3 = Library.FontColor;
        TextSize = Library.FontSize;
        TextTruncate = Enum.TextTruncate.AtEnd;
        TextXAlignment = Enum.TextXAlignment.Left;
        ZIndex = Z + 1;
        Parent = Frame;
    });
    Library:AddToRegistry(Box, { TextColor3 = 'FontColor'; PlaceholderColor3 = function() return Library:GetDimColor() end });
    local Silent = false;
    Box.Focused:Connect(function() Library:Tween(Stroke, { Color = Library.AccentColor }, 0.12) end);
    Box.FocusLost:Connect(function(Enter)
        Library:Tween(Stroke, { Color = Library.OutlineColor }, 0.12);
        Library:SafeCallback(Input.Callback, Box.Text, Enter == true);
    end);
    Box:GetPropertyChangedSignal('Text'):Connect(function()
        if not Silent then Library:SafeCallback(Input.Changed, Box.Text) end;
    end);

    function Input:GetText() return Box.Text end;
    function Input:SetText(Text, Quiet)
        Silent = Quiet == true;
        Box.Text = Text ~= nil and tostring(Text) or '';
        Silent = false;
    end;
    function Input:Focus() pcall(function() Box:CaptureFocus() end) end;

    Input.Frame, Input.Box, Input.Stroke = Frame, Box, Stroke;
    return Input;
end;

-- Info: { Items = { 'A', 'B' }, Default, Style = 'Pill'|'Underline'|'Chip', Scroll = false, Fill = false,
--         Height = 28, Position, Size, ZIndex = 6, Callback = fn(name) }
function Library:CreateSegmented(Parent, Info)
    Info = type(Info) == 'table' and Info or {};
    local Style = (Info.Style == 'Underline' or Info.Style == 'Chip') and Info.Style or 'Pill';
    local H = math.max(18, math.floor(tonumber(Info.Height) or 28));
    local Z = Info.ZIndex or 6;
    local Inset = Style == 'Pill' and 3 or 0;
    local PAD = Style == 'Chip' and 10 or 12;
    local GAP = Style == 'Pill' and 2 or (Style == 'Chip' and 6 or 4);
    local TEXT = Style == 'Chip' and Library.FontSize - 1 or Library.FontSize;
    local BH = H - Inset * 2;
    local Bar = { Type = 'Segmented'; Style = Style; Items = {}; Buttons = {}; Value = nil; Callback = Info.Callback };

    local Holder = Library:Create('Frame', {
        Name = 'Segmented';
        BackgroundColor3 = Library.InputColor;
        BackgroundTransparency = Style == 'Pill' and 0 or 1;
        Position = Info.Position or UDim2.new(0, 0, 0, 0);
        Size = Info.Size or UDim2.new(1, 0, 0, H);
        ZIndex = Z;
        Parent = FrameOf(Parent);
    });
    if Style == 'Pill' then
        Library:Round(Holder, 6);
        Library:Stroke(Holder, 'OutlineColor');
        Library:AddToRegistry(Holder, { BackgroundColor3 = 'InputColor' });
    elseif Style == 'Underline' then
        local Line = Library:Create('Frame', {
            BackgroundColor3 = Library.OutlineColor;
            Position = UDim2.new(0, 0, 1, -1);
            Size = UDim2.new(1, 0, 0, 1);
            ZIndex = Z;
            Parent = Holder;
        });
        Library:AddToRegistry(Line, { BackgroundColor3 = 'OutlineColor' });
    end;
    local Row = Library:Create(Info.Scroll and 'ScrollingFrame' or 'Frame', {
        BackgroundTransparency = 1;
        BorderSizePixel = 0;
        ClipsDescendants = true;
        Position = UDim2.fromOffset(Inset, Inset);
        Size = UDim2.new(1, -Inset * 2, 1, -Inset * 2);
        ZIndex = Z;
        Parent = Holder;
    });
    if Info.Scroll then
        Row.ScrollingDirection = Enum.ScrollingDirection.X;
        Row.ScrollBarThickness = 0;
        Row.CanvasSize = UDim2.new(0, 0, 0, 0);
        Row.InputChanged:Connect(function(Input)
            if Input.UserInputType ~= Enum.UserInputType.MouseWheel then return end;
            local Max = math.max(0, Row.CanvasSize.X.Offset - Row.AbsoluteSize.X / math.max(Library.UIScale, 0.1));
            local Pos = Row.CanvasPosition;
            local Z0 = Input.Position and Input.Position.Z or 0;
            Row.CanvasPosition = Vector2.new(math.clamp((Pos and Pos.X or 0) - Z0 * 40, 0, Max), 0);
        end);
        Library.HoldWheel(Row, function()
            return Row.CanvasSize.X.Offset > Row.AbsoluteSize.X / math.max(Library.UIScale, 0.1);
        end);
    end;

    local function IsOn(Button) return Button.Name == Bar.Value end;
    local function Paint()
        for _, Button in ipairs(Bar.Buttons) do
            local On = IsOn(Button);
            if Style == 'Pill' then
                Library:Tween(Button.Frame, { BackgroundTransparency = On and 0.85 or 1 }, 0.12);
            elseif Style == 'Underline' then
                Button.Line.Visible = On;
            else
                Library:Tween(Button.Stroke, { Color = On and Library.AccentColor or Library.OutlineColor }, 0.12);
            end;
            Button.Label.TextColor3 = On and (Style == 'Chip' and Library.AccentColor or Library.FontColor) or Library:GetDimColor();
        end;
    end;

    local function Build()
        for _, Button in ipairs(Bar.Buttons) do
            pcall(function() Button.Frame:Destroy() end);
        end;
        Bar.Buttons = {};
        local X, N = 0, #Bar.Items;
        for Index, Name in ipairs(Bar.Items) do
            local Button = { Name = Name };
            local TextW = math.ceil(Library:GetTextBounds(Name, Library.Font, TEXT));
            local Frame = Library:Create('Frame', {
                Name = 'Item';
                Active = true;
                BackgroundColor3 = Style == 'Chip' and Library.InputColor or Library.AccentColor;
                BackgroundTransparency = Style == 'Chip' and 0 or 1;
                LayoutOrder = Index;
                ZIndex = Z + 1;
                Parent = Row;
            });
            if Info.Fill and N > 0 then
                local Gaps = GAP * (N - 1);
                Frame.Position = UDim2.new((Index - 1) / N, math.floor((Index - 1) * (GAP - Gaps / N) + 0.5), 0, 0);
                Frame.Size = UDim2.new(1 / N, -math.floor(Gaps / N + 0.5), 0, BH);
            else
                Frame.Position = UDim2.fromOffset(X, 0);
                Frame.Size = UDim2.fromOffset(TextW + PAD * 2, BH);
                X = X + TextW + PAD * 2 + GAP;
            end;
            Library:Round(Frame, 5);
            if Style == 'Chip' then
                Button.Stroke = Library:Stroke(Frame, 'OutlineColor');
                Library.RegistryMap[Button.Stroke].Properties.Color = function()
                    return IsOn(Button) and Library.AccentColor or Library.OutlineColor;
                end;
                Library:AddToRegistry(Frame, { BackgroundColor3 = 'InputColor' });
            else
                Library:AddToRegistry(Frame, { BackgroundColor3 = 'AccentColor' });
            end;
            Button.Label = Library:CreateLabel({
                Size = UDim2.fromScale(1, 1);
                Text = Name;
                TextSize = TEXT;
                TextTruncate = Enum.TextTruncate.AtEnd;
                ZIndex = Z + 2;
                Parent = Frame;
            });
            Library.RegistryMap[Button.Label].Properties.TextColor3 = function()
                if not IsOn(Button) then return Library:GetDimColor() end;
                return Style == 'Chip' and Library.AccentColor or Library.FontColor;
            end;
            if Style == 'Underline' then
                Button.Line = Library:Create('Frame', {
                    Name = 'Line';
                    AnchorPoint = Vector2.new(0.5, 1);
                    BackgroundColor3 = Library.AccentColor;
                    Position = UDim2.new(0.5, 0, 1, 0);
                    Size = UDim2.fromOffset(TextW + 4, 2);
                    Visible = false;
                    ZIndex = Z + 2;
                    Parent = Frame;
                });
                Library:AddToRegistry(Button.Line, { BackgroundColor3 = 'AccentColor' });
            end;
            Library:Hover(Frame, function()
                if IsOn(Button) then return end;
                if Style == 'Pill' then
                    Library:Tween(Frame, { BackgroundTransparency = 0.94 }, 0.1);
                elseif Style == 'Chip' then
                    Library:Tween(Button.Stroke, { Color = Library.AccentColor }, 0.1);
                end;
                Button.Label.TextColor3 = Library.FontColor;
            end, Paint);
            Frame.InputBegan:Connect(function(Input)
                if IsClick(Input) then Bar:SetValue(Name) end;
            end);
            Button.Frame = Frame;
            Bar.Buttons[Index] = Button;
        end;
        Bar.ContentWidth = math.max(0, X - GAP);
        if Info.Scroll then Row.CanvasSize = UDim2.fromOffset(Bar.ContentWidth, 0) end;
    end;

    -- Silent skips Callback/OnChanged; returns true when the value changed
    function Bar:SetValue(Name, Silent)
        if Name == nil or not table.find(Bar.Items, Name) then return false end;
        local Changed = Bar.Value ~= Name;
        Bar.Value = Name;
        Paint();
        if Changed and not Silent then
            Library:SafeCallback(Bar.Callback, Name);
            Library:SafeCallback(Bar.Changed, Name);
        end;
        return Changed;
    end;
    function Bar:GetValue() return Bar.Value end;
    -- keeps the value while it is still listed, otherwise falls back to the first item without a callback
    function Bar:SetItems(List)
        local Items = {};
        for _, Name in ipairs(type(List) == 'table' and List or {}) do
            if type(Name) == 'string' or type(Name) == 'number' then table.insert(Items, tostring(Name)) end;
        end;
        Bar.Items = Items;
        Build();
        if not table.find(Items, Bar.Value) then Bar.Value = Items[1] end;
        Paint();
    end;
    function Bar:OnChanged(Func) Bar.Changed = Func end;
    function Bar:SetVisible(Bool) Holder.Visible = not not Bool end;

    Bar.Frame, Bar.Row = Holder, Row;
    Bar:SetItems(Info.Items);
    if Info.Default ~= nil and table.find(Bar.Items, tostring(Info.Default)) then
        Bar.Value = tostring(Info.Default);
        Paint();
    end;
    if typeof(Parent) ~= 'Instance' and type(Parent) == 'table' and Parent.Resize then Parent:Resize() end;
    return Bar;
end;

-- Horizontal row of item tiles (gallery item shape). Info: { Height = 70, TileSize = 54, Items, EmptyText = 'Nothing here',
--   Remove = false (hover shows a cross), Position, ZIndex = 6, Callback = fn(item, index) }
function Library:CreateStrip(Parent, Info)
    Info = type(Info) == 'table' and Info or {};
    local H = math.max(24, math.floor(tonumber(Info.Height) or 70));
    local T = math.min(H - 6, math.max(16, math.floor(tonumber(Info.TileSize) or 54)));
    local GAP, Z = 6, Info.ZIndex or 6;
    local Strip = { Type = 'Strip'; Items = {}; Tiles = {}; Callback = Info.Callback };
    local Holder, HolderStroke = Library:CreateBevel(Parent, {
        Color = 'InputColor';
        Position = Info.Position;
        Size = UDim2.new(1, 0, 0, H);
        Radius = 5;
        ZIndex = Z;
    });
    Holder.Name = 'Strip';
    local Row = Library:Create('ScrollingFrame', {
        BackgroundTransparency = 1;
        BorderSizePixel = 0;
        CanvasSize = UDim2.new(0, 0, 0, 0);
        Position = UDim2.fromOffset(6, 0);
        Size = UDim2.new(1, -12, 1, 0);
        ScrollBarThickness = 2;
        ScrollBarImageColor3 = Library.OutlineColor;
        ScrollingDirection = Enum.ScrollingDirection.X;
        TopImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png';
        BottomImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png';
        MidImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png';
        ZIndex = Z;
        Parent = Holder;
    });
    Library:AddToRegistry(Row, { ScrollBarImageColor3 = 'OutlineColor' });
    local Empty = Library:CreateLabel({
        Dim = true;
        Size = UDim2.fromScale(1, 1);
        Text = type(Info.EmptyText) == 'string' and Info.EmptyText or 'Nothing here';
        TextSize = Library.FontSize - 1;
        ZIndex = Z + 1;
        Parent = Holder;
    });
    Row.InputChanged:Connect(function(Input)
        if Input.UserInputType ~= Enum.UserInputType.MouseWheel then return end;
        local Max = math.max(0, Row.CanvasSize.X.Offset - Row.AbsoluteSize.X / math.max(Library.UIScale, 0.1));
        local Pos = Row.CanvasPosition;
        local Z0 = Input.Position and Input.Position.Z or 0;
        Row.CanvasPosition = Vector2.new(math.clamp((Pos and Pos.X or 0) - Z0 * 40, 0, Max), 0);
    end);
    Library.HoldWheel(Holder, function()
        return Row.CanvasSize.X.Offset > Row.AbsoluteSize.X / math.max(Library.UIScale, 0.1);
    end);

    local CROSS = utf8 and utf8.char(0xD7) or 'x';
    local function BuildTile(Item, Index)
        local Tile = { Item = Item; Hovered = false };
        local Swatch = typeof(Item.Swatch) == 'Color3' and Item.Swatch or nil;
        local Frame = Library:Create('Frame', {
            Name = 'Tile';
            Active = true;
            BackgroundColor3 = Swatch or Library.MainColor;
            Position = UDim2.fromOffset((Index - 1) * (T + GAP), math.floor((H - T) / 2));
            Size = UDim2.fromOffset(T, T);
            ZIndex = Z + 1;
            Parent = Row;
        });
        Library:Round(Frame, 5);
        local Stroke = Library:Stroke(Frame, 'OutlineColor');
        Library.RegistryMap[Stroke].Properties.Color = function()
            return Tile.Hovered and Library.AccentColor or Library.OutlineColor;
        end;
        if not Swatch then Library:AddToRegistry(Frame, { BackgroundColor3 = 'MainColor' }) end;
        local Icon = (not Swatch) and Library:GetIcon(Item.Image) or nil;
        if Icon then
            Library:Create('ImageLabel', {
                BackgroundTransparency = 1;
                Image = Icon.Image;
                ImageRectOffset = Icon.ImageRectOffset;
                ImageRectSize = Icon.ImageRectSize;
                Position = UDim2.fromOffset(4, 4);
                ScaleType = Enum.ScaleType.Fit;
                Size = UDim2.new(1, -8, 1, -8);
                ZIndex = Z + 2;
                Parent = Frame;
            });
        elseif not Swatch then
            local Name = Item.Name ~= nil and tostring(Item.Name) or '?';
            Library:CreateLabel({
                Dim = true;
                Size = UDim2.fromScale(1, 1);
                Text = string.upper(string.sub(Name, 1, 1));
                TextSize = Library.FontSize + 2;
                ZIndex = Z + 2;
                Parent = Frame;
            });
        end;
        if typeof(Item.Color) == 'Color3' then
            local Bar = Library:Create('Frame', {
                Name = 'Rarity';
                AnchorPoint = Vector2.new(0, 1);
                BackgroundColor3 = Item.Color;
                Position = UDim2.new(0, 6, 1, -2);
                Size = UDim2.new(1, -12, 0, 2);
                ZIndex = Z + 3;
                Parent = Frame;
            });
            Library:Round(Bar, 1);
        end;
        local Cross;
        if Info.Remove then
            Cross = Library:Create('Frame', {
                Name = 'Remove';
                AnchorPoint = Vector2.new(1, 0);
                BackgroundColor3 = Library.MainColor;
                Position = UDim2.new(1, -2, 0, 2);
                Size = UDim2.fromOffset(14, 14);
                Visible = false;
                ZIndex = Z + 3;
                Parent = Frame;
            });
            Library:Round(Cross, 7);
            Library:AddToRegistry(Cross, { BackgroundColor3 = 'MainColor' });
            Library:CreateLabel({
                Size = UDim2.fromScale(1, 1);
                Text = CROSS;
                TextSize = Library.FontSize;
                ZIndex = Z + 4;
                Parent = Cross;
            });
        end;
        Library:Hover(Frame, function()
            Tile.Hovered = true;
            Library:Tween(Stroke, { Color = Library.AccentColor }, 0.12);
            if Cross then Cross.Visible = true end;
        end, function()
            Tile.Hovered = false;
            Library:Tween(Stroke, { Color = Library.OutlineColor }, 0.12);
            if Cross then Cross.Visible = false end;
        end);
        Frame.InputBegan:Connect(function(Input)
            if IsClick(Input) then Library:SafeCallback(Strip.Callback, Item, Index) end;
        end);
        Tile.Frame, Tile.Stroke = Frame, Stroke;
        return Tile;
    end;

    function Strip:SetItems(Items)
        for _, Tile in ipairs(Strip.Tiles) do
            pcall(function() Tile.Frame:Destroy() end);
        end;
        Strip.Items, Strip.Tiles = {}, {};
        for _, Item in ipairs(type(Items) == 'table' and Items or {}) do
            if type(Item) == 'table' then
                table.insert(Strip.Items, Item);
                table.insert(Strip.Tiles, BuildTile(Item, #Strip.Items));
            end;
        end;
        local N = #Strip.Items;
        Row.CanvasSize = UDim2.fromOffset(N > 0 and (N * (T + GAP) - GAP) or 0, 0);
        Empty.Visible = N == 0;
    end;
    function Strip:SetEmptyText(Text)
        Empty.Text = Text ~= nil and tostring(Text) or 'Nothing here';
    end;
    function Strip:SetVisible(Bool) Holder.Visible = not not Bool end;

    Strip.Frame, Strip.List, Strip.Stroke = Holder, Row, HolderStroke;
    Strip:SetItems(Info.Items);
    return Strip;
end;

-- Floating card (target info). Position is kept per Key in Library.CardPositions and saved with the layout.
Library.CardPositions = {};
Library.InfoCards = {};
local function CardPosition(Saved)
    if type(Saved) ~= 'table' then return nil end;
    local XS, XO, YS, YO = tonumber(Saved[1]), tonumber(Saved[2]), tonumber(Saved[3]), tonumber(Saved[4]);
    if not (XS and XO and YS and YO) then return nil end;
    return UDim2.new(XS, math.floor(XO), YS, math.floor(YO));
end;

-- Info: { Title = 'Target', Key = Title, Rows = { 'Health', 'Distance', 'Team', 'Weapon' }, Image = true, Width = 220, Position = UDim2 }
function Library:CreateInfoCard(Info)
    Info = type(Info) == 'table' and Info or {};
    local Rows = type(Info.Rows) == 'table' and Info.Rows or { 'Health', 'Distance', 'Team', 'Weapon' };
    local W = math.max(140, math.floor(tonumber(Info.Width) or 220));
    local PAD, ROW, Z = 10, 18, 150;
    local IMG = Info.Image ~= false and 40 or 0;
    local HEAD = math.max(IMG, 34);
    local HasHealth = table.find(Rows, 'Health') ~= nil;
    local BAR_Y = PAD + HEAD + 8;
    local ROWS_Y = BAR_Y + (HasHealth and 10 or 0);
    local H = ROWS_Y + #Rows * ROW + PAD - 2;
    local Card = { Type = 'InfoCard'; Title = tostring(Info.Title or 'Target'); Rows = {}; Data = {}; Visible = false };
    Card.Key = tostring(Info.Key or Card.Title);

    local Frame = Library:Create('Frame', {
        Name = 'InfoCard';
        BackgroundColor3 = Library.MainColor;
        Position = CardPosition(Library.CardPositions[Card.Key]) or Info.Position or UDim2.new(0, 24, 0.5, -math.floor(H / 2));
        Size = UDim2.fromOffset(W, H);
        Visible = false;
        ZIndex = Z;
        Parent = ScreenGui;
    });
    Library:Round(Frame, 6);
    Library:Stroke(Frame, 'OutlineColor');
    Library:AddToRegistry(Frame, { BackgroundColor3 = 'MainColor' });

    local Image;
    if IMG > 0 then
        Image = Library:Create('ImageLabel', {
            BackgroundColor3 = Library.InputColor;
            Image = '';
            Position = UDim2.fromOffset(PAD, PAD);
            ScaleType = Enum.ScaleType.Crop;
            Size = UDim2.fromOffset(IMG, IMG);
            ZIndex = Z + 1;
            Parent = Frame;
        });
        Library:Round(Image, 5);
        Library:AddToRegistry(Image, { BackgroundColor3 = 'InputColor' });
    end;
    local TextX = PAD + (IMG > 0 and IMG + 10 or 0);
    local TitleLabel = Library:CreateLabel({
        Dim = true;
        Position = UDim2.fromOffset(TextX, PAD + math.floor((HEAD - 34) / 2));
        Size = UDim2.new(1, -TextX - PAD, 0, 14);
        Text = Card.Title;
        TextSize = Library.FontSize - 2;
        TextXAlignment = Enum.TextXAlignment.Left;
        ZIndex = Z + 1;
        Parent = Frame;
    });
    local NameLabel = Library:CreateLabel({
        Font = Library:BoldFont();
        Position = UDim2.fromOffset(TextX, PAD + math.floor((HEAD - 34) / 2) + 16);
        Size = UDim2.new(1, -TextX - PAD, 0, 18);
        Text = '-';
        TextSize = Library.FontSize + 1;
        TextTruncate = Enum.TextTruncate.AtEnd;
        TextXAlignment = Enum.TextXAlignment.Left;
        ZIndex = Z + 1;
        Parent = Frame;
    });
    local Fill, Low;
    if HasHealth then
        local Track = Library:Create('Frame', {
            BackgroundColor3 = Library.TrackColor;
            Position = UDim2.fromOffset(PAD, BAR_Y);
            Size = UDim2.new(1, -PAD * 2, 0, 4);
            ZIndex = Z + 1;
            Parent = Frame;
        });
        Library:Round(Track, 2);
        Library:AddToRegistry(Track, { BackgroundColor3 = 'TrackColor' });
        Fill = Library:Create('Frame', {
            Name = 'Health';
            BackgroundColor3 = Library.AccentColor;
            Size = UDim2.fromScale(1, 1);
            ZIndex = Z + 2;
            Parent = Track;
        });
        Library:Round(Fill, 2);
        Library:AddToRegistry(Fill, { BackgroundColor3 = function() return Low and Library.RiskColor or Library.AccentColor end });
    end;
    for Index, Name in ipairs(Rows) do
        Name = tostring(Name);
        local Y = ROWS_Y + (Index - 1) * ROW;
        local KeyLabel = Library:CreateLabel({
            Dim = true;
            Position = UDim2.fromOffset(PAD, Y);
            Size = UDim2.new(0.45, -PAD, 0, ROW);
            Text = Name;
            TextSize = Library.FontSize - 1;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = Z + 1;
            Parent = Frame;
        });
        local Value = Library:CreateLabel({
            Position = UDim2.new(0.45, 0, 0, Y);
            Size = UDim2.new(0.55, -PAD, 0, ROW);
            Text = '-';
            TextSize = Library.FontSize - 1;
            TextTruncate = Enum.TextTruncate.AtEnd;
            TextXAlignment = Enum.TextXAlignment.Right;
            ZIndex = Z + 1;
            Parent = Frame;
        });
        local Dot;
        if Name == 'Team' then
            Dot = Library:Create('Frame', {
                Name = 'TeamDot';
                AnchorPoint = Vector2.new(1, 0.5);
                BackgroundColor3 = Library.OutlineColor;
                Position = UDim2.new(1, -PAD, 0, Y + math.floor(ROW / 2));
                Size = UDim2.fromOffset(8, 8);
                Visible = false;
                ZIndex = Z + 2;
                Parent = Frame;
            });
            Library:Round(Dot, 4);
        end;
        Card.Rows[Name] = { Key = KeyLabel; Value = Value; Dot = Dot };
    end;

    function Card:SetRow(Name, Text)
        local Row = Card.Rows[Name];
        if Row then Row.Value.Text = Text ~= nil and tostring(Text) or '-' end;
    end;
    -- Data: { Name, UserId, Health, MaxHealth, Distance, Team, TeamColor, Weapon, Visible, [any row name] = text }
    function Card:Update(Data)
        if type(Data) ~= 'table' then return end;
        for Key, Value in next, Data do Card.Data[Key] = Value end;
        local D = Card.Data;
        if Data.Name ~= nil then NameLabel.Text = tostring(Data.Name) end;
        if Image and Data.UserId ~= nil then
            local Id = math.floor(tonumber(Data.UserId) or 0);
            Image.Image = Id > 0 and ('rbxthumb://type=AvatarHeadShot&id=' .. Id .. '&w=150&h=150') or '';
        end;
        if Data.Health ~= nil or Data.MaxHealth ~= nil then
            local Max = math.max(tonumber(D.MaxHealth) or 100, 1);
            local Hp = math.clamp(tonumber(D.Health) or Max, 0, Max);
            Card:SetRow('Health', math.floor(Hp + 0.5) .. ' / ' .. math.floor(Max + 0.5));
            Low = Hp / Max < 0.3;
            if Fill then
                Fill.Size = UDim2.fromScale(Hp / Max, 1);
                Fill.BackgroundColor3 = Low and Library.RiskColor or Library.AccentColor;
            end;
        end;
        if Data.Distance ~= nil then
            local Dist = tonumber(Data.Distance);
            Card:SetRow('Distance', Dist and (math.floor(Dist + 0.5) .. ' studs') or tostring(Data.Distance));
        end;
        if Data.Team ~= nil then Card:SetRow('Team', Data.Team) end;
        if Data.TeamColor ~= nil and Card.Rows.Team and Card.Rows.Team.Dot then
            local Color = Data.TeamColor;
            if typeof(Color) == 'BrickColor' then Color = Color.Color end;
            local Row = Card.Rows.Team;
            Row.Dot.Visible = typeof(Color) == 'Color3';
            if Row.Dot.Visible then Row.Dot.BackgroundColor3 = Color end;
            Row.Value.Size = UDim2.new(0.55, Row.Dot.Visible and -(PAD + 14) or -PAD, 0, ROW);
        end;
        for Name, Row in next, Card.Rows do
            if Name ~= 'Health' and Name ~= 'Distance' and Name ~= 'Team' and Data[Name] ~= nil then
                Row.Value.Text = tostring(Data[Name]);
            end;
        end;
        if Data.Visible ~= nil then Card:SetVisible(Data.Visible) end;
    end;
    function Card:SetVisible(Bool)
        Card.Visible = not not Bool;
        Frame.Visible = Card.Visible;
    end;
    function Card:SetTitle(Text)
        Card.Title = Text ~= nil and tostring(Text) or '';
        TitleLabel.Text = Card.Title;
    end;
    function Card:SetPosition(Position)
        if typeof(Position) ~= 'UDim2' then return end;
        Frame.Position = Position;
        Library.CardPositions[Card.Key] = { Position.X.Scale, Position.X.Offset, Position.Y.Scale, Position.Y.Offset };
    end;
    function Card:Destroy()
        local At = table.find(Library.InfoCards, Card);
        if At then table.remove(Library.InfoCards, At) end;
        pcall(function() Frame:Destroy() end);
    end;

    -- dragged by the body while the menu is open; the drop is saved like a card move
    Frame.InputBegan:Connect(function(Input)
        if not Library.Toggled or not IsClick(Input) then return end;
        local Start, From = Input.Position, Frame.Position;
        local Moved, Ended;
        Moved = InputService.InputChanged:Connect(function(Change)
            if Change.UserInputType ~= Enum.UserInputType.MouseMovement and Change ~= Input then return end;
            local Scale = math.max(Library.UIScale, 0.1);
            local DX = math.floor((Change.Position.X - Start.X) / Scale + 0.5);
            local DY = math.floor((Change.Position.Y - Start.Y) / Scale + 0.5);
            Frame.Position = UDim2.new(From.X.Scale, From.X.Offset + DX, From.Y.Scale, From.Y.Offset + DY);
        end);
        Ended = InputService.InputEnded:Connect(function(EndInput)
            if EndInput ~= Input and EndInput.UserInputType ~= Enum.UserInputType.MouseButton1 and EndInput.UserInputType ~= Enum.UserInputType.Touch then return end;
            Moved:Disconnect();
            Ended:Disconnect();
            if Frame.Position ~= From then
                Card:SetPosition(Frame.Position);
                Library:SafeCallback(Library.OnLayoutChanged, Library:GetLayout());
            end;
        end);
    end);

    Card.Frame, Card.Image, Card.TitleLabel, Card.NameLabel, Card.HealthBar = Frame, Image, TitleLabel, NameLabel, Fill;
    table.insert(Library.InfoCards, Card);
    return Card;
end;

-- Panes: a canvas, each side of a Split and each page of AddPages. Shown state is derived
-- (frame visible up the chain, tab active, menu open) and OnShow/OnHide fire on its edges.
local PaneMethods = {};
PaneMethods.__index = PaneMethods;

local function MakePane(Frame, Parent)
    local Pane = setmetatable({ Frame = Frame; Parent = Parent; Shown = false; ShowFns = {}; HideFns = {}; Groupboxes = {} }, PaneMethods);
    if Parent then
        Pane.Canvas, Pane.Tab = Parent.Canvas, Parent.Tab;
        table.insert(Pane.Canvas.Nodes, Pane);
        Pane.Shown = Pane:IsShown();
    end;
    return Pane;
end;

local function SyncNode(Node)
    local Now = Node:IsShown();
    if Now == Node.Shown then return end;
    Node.Shown = Now;
    if Now then
        if Node.Build and not Node.Built then
            Node.Built = true;
            Library:SafeCallback(Node.Build, Node);
        end;
        for _, Entry in ipairs(Node.ShowFns) do
            local First = not Entry.Seen;
            Entry.Seen = true;
            Library:SafeCallback(Entry.Fn, Node, First);
        end;
    else
        for _, Fn in ipairs(Node.HideFns) do
            Library:SafeCallback(Fn, Node);
        end;
    end;
end;

function PaneMethods:IsShown()
    if not self.Frame.Parent or not self.Frame.Visible then return false end;
    if self.Parent then return self.Parent:IsShown() end;
    return self.Tab.Active == true and Library.Toggled == true and not Library.Unloaded;
end;

-- Fn(Pane, First): First is true the first time this handler sees the pane shown (build lazily there)
function PaneMethods:OnShow(Fn)
    local Entry = { Fn = Fn; Seen = false };
    table.insert(self.ShowFns, Entry);
    if self.Shown then
        Entry.Seen = true;
        Library:SafeCallback(Fn, self, true);
    end;
    return self;
end;

function PaneMethods:OnHide(Fn)
    table.insert(self.HideFns, Fn);
    return self;
end;

-- re-derives the shown state of the whole canvas this pane belongs to
function PaneMethods:Sync()
    local Canvas = self.Canvas;
    SyncNode(Canvas);
    for _, Node in ipairs(Canvas.Nodes) do SyncNode(Node) end;
end;

-- vertical stack that scrolls (groupboxes go here); Info: { Padding = 10 }
function PaneMethods:AddScroll(Info)
    Info = type(Info) == 'table' and Info or {};
    local Scroll = Library:Create('ScrollingFrame', {
        BackgroundTransparency = 1;
        BorderSizePixel = 0;
        CanvasSize = UDim2.new(0, 0, 0, 0);
        Size = UDim2.new(1, 0, 1, 0);
        BottomImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png';
        TopImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png';
        MidImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png';
        ScrollBarThickness = 2;
        ScrollBarImageColor3 = Library.OutlineColor;
        ZIndex = 2;
        Parent = self.Frame;
    });
    Library:AddToRegistry(Scroll, { ScrollBarImageColor3 = 'OutlineColor' });
    table.insert(Library.ColumnScrollers, Scroll);
    Library:Create('UIPadding', { PaddingRight = UDim.new(0, 5); Parent = Scroll });
    local Layout = Library:Create('UIListLayout', {
        Padding = UDim.new(0, math.floor(tonumber(Info.Padding) or 10));
        FillDirection = Enum.FillDirection.Vertical;
        SortOrder = Enum.SortOrder.LayoutOrder;
        HorizontalAlignment = Enum.HorizontalAlignment.Center;
        Parent = Scroll;
    });
    Layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
        Scroll.CanvasSize = UDim2.fromOffset(0, Layout.AbsoluteContentSize.Y + 2);
    end);
    if not self.Scroll then self.Scroll = Scroll end;
    return Scroll;
end;

-- a real groupbox (every Add* method, flags, configs) stacked in the pane: not a movable card, not searched
function PaneMethods:AddGroupbox(Info, Icon)
    if type(Info) ~= 'table' then Info = { Name = tostring(Info); Icon = Icon } end;
    if not self.Scroll then self:AddScroll() end;
    local Copy = {};
    for Key, Value in next, Info do Copy[Key] = Value end;
    Copy.Host, Copy.SubTab = self.Scroll, nil;
    local Box = self.Tab:AddGroupbox(Copy);
    if Copy.Name ~= nil then self.Groupboxes[Copy.Name] = Box end;
    return Box;
end;

-- Info: { Size = px (fixed side) | Ratio = 0.5, Side = 'Right'|'Left' (which side Size fixes), Gap = 10,
--         Direction = 'Horizontal'|'Vertical' }. Returns the two panes (left/top first).
function PaneMethods:Split(Info)
    Info = type(Info) == 'table' and Info or {};
    local Gap = math.max(0, math.floor(tonumber(Info.Gap) or 10));
    local Vertical = Info.Direction == 'Vertical';
    local Fixed = tonumber(Info.Size);
    local APos, ASize, BPos, BSize;
    if Fixed then
        Fixed = math.max(0, math.floor(Fixed));
        if Info.Side == 'Left' or Info.Side == 'Top' then
            APos, ASize = { 0, 0 }, { 0, Fixed };
            BPos, BSize = { 0, Fixed + Gap }, { 1, -(Fixed + Gap) };
        else
            APos, ASize = { 0, 0 }, { 1, -(Fixed + Gap) };
            BPos, BSize = { 1, -Fixed }, { 0, Fixed };
        end;
    else
        local Ratio = math.clamp(tonumber(Info.Ratio) or 0.5, 0.05, 0.95);
        local Half = math.floor(Gap / 2);
        APos, ASize = { 0, 0 }, { Ratio, -Half };
        BPos, BSize = { Ratio, Gap - Half }, { 1 - Ratio, -(Gap - Half) };
    end;
    local function Side(Pos, Size, Name)
        return Library:Create('Frame', {
            Name = Name;
            BackgroundTransparency = 1;
            ClipsDescendants = true;
            Position = Vertical and UDim2.new(0, 0, Pos[1], Pos[2]) or UDim2.new(Pos[1], Pos[2], 0, 0);
            Size = Vertical and UDim2.new(1, 0, Size[1], Size[2]) or UDim2.new(Size[1], Size[2], 1, 0);
            ZIndex = 2;
            Parent = self.Frame;
        });
    end;
    local A = MakePane(Side(APos, ASize, 'PaneA'), self);
    local B = MakePane(Side(BPos, BSize, 'PaneB'), self);
    self.Panes = { A, B };
    return A, B;
end;

-- Segmented bar on top switching page panes. Opts: { Default, Style = 'Pill', Height = 28, Gap = 8, Scroll = true,
--   Callback = fn(name) }. Returns Pages with Pages[name] = Page. The controller (Select, GetPage, GetCurrent, Bar,
--   Current, List) is reached through __index, so a page name always wins over it.
function PaneMethods:AddPages(Names, Opts)
    Opts = type(Opts) == 'table' and Opts or {};
    local BarH = math.max(18, math.floor(tonumber(Opts.Height) or 28));
    local Top = BarH + math.max(0, math.floor(tonumber(Opts.Gap) or 8));
    local Owner = self;
    local List, ByName, Current = {}, {}, nil;
    local Control = { List = List };
    local Pages = setmetatable({}, { __index = function(_, Key)
        if Key == 'Current' then return Current end;
        return Control[Key];
    end });
    Control.Bar = Library:CreateSegmented(self.Frame, {
        Items = Names;
        Default = Opts.Default;
        Style = Opts.Style or 'Pill';
        Height = BarH;
        Scroll = Opts.Scroll ~= false;
        Callback = function(Name) Control.Select(Pages, Name) end;
    });
    for _, Name in ipairs(Control.Bar.Items) do
        local Frame = Library:Create('Frame', {
            Name = 'Page';
            BackgroundTransparency = 1;
            ClipsDescendants = true;
            Position = UDim2.fromOffset(0, Top);
            Size = UDim2.new(1, 0, 1, -Top);
            Visible = false;
            ZIndex = 2;
            Parent = Owner.Frame;
        });
        local Page = MakePane(Frame, Owner);
        Page.Name = Name;
        rawset(Pages, Name, Page);
        ByName[Name] = Page;
        table.insert(List, Page);
    end;
    function Control.GetPage(_, Name) return ByName[Name] end;
    function Control.GetCurrent() return Current end;
    function Control.Select(_, Name)
        local Page = ByName[Name];
        if not Page then return false end;
        for _, Other in ipairs(List) do
            Other.Frame.Visible = Other == Page;
        end;
        local Changed = Current ~= Page;
        Current = Page;
        Control.Bar:SetValue(Name, true);
        Owner:Sync();
        if Changed then Library:SafeCallback(Opts.Callback, Name) end;
        return true;
    end;
    if Control.Bar.Value then Control.Select(Pages, Control.Bar.Value) end;
    return Pages;
end;

-- Popups --------------------------------------------------------------------
-- Toggle:AddSettings panels live in their own ScreenGui so they sit above the window
Library.Popups = {};

function Library:GetPopupGui()
    if Library.PopupGui and Library.PopupGui.Parent then
        return Library.PopupGui;
    end;
    local Gui = Instance.new('ScreenGui');
    Gui.Name = 'AsterPopups';
    pcall(ProtectGui, Gui);
    Gui.ZIndexBehavior = Enum.ZIndexBehavior.Global;
    Gui.ResetOnSpawn = false;
    pcall(function() Gui.DisplayOrder = 5 end);
    Gui.Parent = GetGuiParent();
    Library.PopupGui = Gui;
    -- dropdown rows are rebuilt on every SetValue, so their registry entries must go with them
    Library:GiveSignal(Gui.DescendantRemoving:Connect(function(Instance)
        if not Library.Unloaded and Library.RegistryMap[Instance] then
            Library:RemoveFromRegistry(Instance);
        end;
    end));
    return Gui;
end;

-- The host script may raise ScreenGui.DisplayOrder, so popups must follow it
function Library:SyncPopupOrder()
    local Gui = Library.PopupGui;
    if Gui and Gui.Parent then
        pcall(function() Gui.DisplayOrder = math.max(5, ScreenGui.DisplayOrder + 1) end);
    end;
end;

function Library:CloseAllPopups(Except)
    Library:CloseFloat();
    for _, Popup in ipairs(Library.Popups) do
        if Popup ~= Except and Popup.Open then
            Popup:Close();
        end;
    end;
end;

-- Section layout ----------------------------------------------------------------
-- { [TabName] = { [1] = { 'Card', ... }, [2] = {...}, [3] = {...} } }. Sub-tab cards are keyed 'Sub/Card'.
function Library:GetLayout()
    local Layout = {};
    local Window = Library.Window;
    if not Window then return Layout end;
    for _, Tab in ipairs(Window.TabList) do
        if Tab.Cards and #Tab.Cards > 0 then
            local Cols = {};
            for Col = 1, Tab.ColumnCount do
                local Keys = {};
                for _, Card in ipairs(Tab:GetCards(Col)) do
                    table.insert(Keys, Card.Key);
                end;
                Cols[Col] = Keys;
            end;
            Layout[Tab.Name] = Cols;
        end;
    end;
    -- floating info cards: { [Key] = { XScale, XOffset, YScale, YOffset } }
    if next(Library.CardPositions) ~= nil then
        local Cards = {};
        for Key, Pos in next, Library.CardPositions do Cards[Key] = Pos end;
        Layout.__cards = Cards;
    end;
    return Layout;
end;

-- Listed cards move to their column in the given order; unlisted ones keep their place after them.
function Library:SetLayout(Layout)
    local Window = Library.Window;
    if type(Layout) ~= 'table' then return end;
    if type(Layout.__cards) == 'table' then
        for Key, Pos in next, Layout.__cards do
            local At = CardPosition(Pos);
            if At then
                Library.CardPositions[Key] = { At.X.Scale, At.X.Offset, At.Y.Scale, At.Y.Offset };
                for _, Card in ipairs(Library.InfoCards) do
                    if Card.Key == Key then Card.Frame.Position = At end;
                end;
            end;
        end;
    end;
    if not Window then return end;
    for TabName, Cols in next, Layout do
        local Tab = Window.Tabs[TabName];
        if Tab and Tab.Cards and type(Cols) == 'table' then
            for ColKey, Keys in next, Cols do
                local Col = tonumber(ColKey);
                if Col and Col >= 1 and Col <= Tab.ColumnCount and type(Keys) == 'table' then
                    for Index, Key in ipairs(Keys) do
                        local Card = Tab:FindCard(Key);
                        if Card then Tab:MoveCard(Card, Col, Index) end;
                    end;
                end;
            end;
        end;
    end;
end;

Library:GiveSignal(function()
    if Library.CardDrag then Library.CardDrag.Stop(false) end;
end);

-- Info: { Width = 230, Icon = 'settings' }. Returns a container with the usual Add* methods.
BaseAddons.__index.AddSettings = function(self, Name, Info)
    Info = type(Info) == 'table' and Info or {};
    local Parent = self.TextLabel;
    assert(Parent, 'AddSettings: element has no row.');

    local Popup = { Type = 'Settings'; Open = false; Name = Name; Root = { NoSearch = true } };
    local Width = Info.Width or 230;
    local Gui = Library:GetPopupGui();
    Library:SyncPopupOrder();

    local Gear = Library:Create('Frame', {
        BackgroundTransparency = 1;
        LayoutOrder = AddonSlot(self, 'Settings');
        Size = UDim2.fromOffset(16, 16);
        ZIndex = 8;
        Parent = AddonHolder(self);
    });
    ArrangeAddons(self);
    local GearIcon = Library:Create('ImageLabel', {
        AnchorPoint = Vector2.new(0.5, 0.5);
        BackgroundTransparency = 1;
        ImageColor3 = Library:GetDimColor();
        Position = UDim2.fromScale(0.5, 0.5);
        Size = UDim2.fromOffset(14, 14);
        ZIndex = 9;
        Parent = Gear;
    });
    local GearColor = function() return Popup.Open and Library.AccentColor or Library:GetDimColor() end;
    if Library:ApplyIcon(GearIcon, Info.Icon or 'settings') then
        Library:AddToRegistry(GearIcon, { ImageColor3 = GearColor });
    else
        GearIcon:Destroy();
        GearIcon = Library:CreateLabel({
            Dim = true;
            Size = UDim2.fromScale(1, 1);
            Text = '+';
            TextSize = Library.FontSize + 2;
            ZIndex = 9;
            Parent = Gear;
        });
        Library.RegistryMap[GearIcon].Properties.TextColor3 = GearColor;
    end;
    local ColorProp = GearIcon:IsA('ImageLabel') and 'ImageColor3' or 'TextColor3';

    local Frame = Library:Create('Frame', {
        BackgroundColor3 = Library.GroupboxColor;
        Active = true;
        Size = UDim2.fromOffset(Width, 40);
        Visible = false;
        ZIndex = 3;
        Parent = Gui;
    });
    Library:Round(Frame, 6);
    Library:Stroke(Frame, 'OutlineColor');
    Library:AddToRegistry(Frame, { BackgroundColor3 = 'GroupboxColor' });
    local Scale = Library:Create('UIScale', { Scale = Library.UIScale; Parent = Frame });
    Library:CreateLabel({
        Dim = true;
        Position = UDim2.fromOffset(10, 6);
        Size = UDim2.new(1, -20, 0, 16);
        Text = Name or 'Settings';
        TextSize = Library.FontSize - 1;
        TextXAlignment = Enum.TextXAlignment.Left;
        ZIndex = 4;
        Parent = Frame;
    });
    -- content scrolls once the popup hits its cap (MaxHeight, or 70% of the screen)
    local TOP, PAD, BOTTOM = 26, 2, 8;
    local Content = Library:Create('ScrollingFrame', {
        Active = true;
        BackgroundTransparency = 1;
        BorderSizePixel = 0;
        CanvasSize = UDim2.new(0, 0, 0, 0);
        Position = UDim2.fromOffset(0, TOP);
        Size = UDim2.new(1, 0, 1, -(TOP + BOTTOM));
        TopImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png';
        BottomImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png';
        MidImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png';
        ScrollBarThickness = 2;
        ScrollBarImageColor3 = Library.AccentColor;
        ScrollingDirection = Enum.ScrollingDirection.Y;
        ZIndex = 4;
        Parent = Frame;
    });
    Library:AddToRegistry(Content, { ScrollBarImageColor3 = 'AccentColor' });
    Library:Create('UIPadding', {
        PaddingLeft = UDim.new(0, 10);
        PaddingRight = UDim.new(0, 10);
        PaddingTop = UDim.new(0, PAD);
        PaddingBottom = UDim.new(0, PAD);
        Parent = Content;
    });
    local Layout = Library:Create('UIListLayout', {
        FillDirection = Enum.FillDirection.Vertical;
        SortOrder = Enum.SortOrder.LayoutOrder;
        Parent = Content;
    });

    -- sizes in popup units; Gui is in screen pixels, so divide by the scale
    local function ScaleOf() return math.max(Scale.Scale, 0.1) end;
    function Popup:GetMaxHeight()
        local ViewY = Gui.AbsoluteSize.Y;
        local Cap = ViewY > 0 and math.max(80, math.floor(ViewY * 0.7 / ScaleOf())) or math.huge;
        return Info.MaxHeight and math.min(Info.MaxHeight, Cap) or Cap;
    end;

    local function Place()
        local S = ScaleOf();
        local Pos, Size = Gear.AbsolutePosition, Gear.AbsoluteSize;
        local View = Gui.AbsoluteSize;
        local BoxX, BoxY = Frame.Size.X.Offset * S, Frame.Size.Y.Offset * S;
        local X = math.clamp(Pos.X + Size.X - BoxX, 4, math.max(4, View.X - BoxX - 4));
        local Y = Pos.Y + Size.Y + 6;
        if View.Y > 0 and Y + BoxY > View.Y - 4 then
            local Above = Pos.Y - BoxY - 6;
            Y = Above >= 4 and Above or math.clamp(Y, 4, math.max(4, View.Y - BoxY - 4));
        end;
        Frame.Position = UDim2.fromOffset(math.floor(X), math.floor(Y));
    end;

    function Popup:Resize()
        local Height = 0;
        for _, Element in next, Content:GetChildren() do
            if Element:IsA('GuiObject') and Element.Visible then
                Height = Height + Element.Size.Y.Offset;
            end;
        end;
        Height = Height + PAD * 2;
        local View = math.min(Height, Popup:GetMaxHeight() - TOP - BOTTOM);
        Content.CanvasSize = UDim2.fromOffset(0, Height);
        Popup.ContentHeight = Height;
        Popup.Scrolls = Height > View;
        Frame.Size = UDim2.fromOffset(Width, TOP + View + BOTTOM);
        if Popup.Open then Place() end;
    end;
    function Popup:Show()
        Library:CloseAllPopups(Popup);
        Library:SyncPopupOrder();
        Popup.Open = true;
        Scale.Scale = Library.UIScale;
        Popup:Resize();
        Place();
        Frame.Visible = true;
        GearIcon[ColorProp] = Library.AccentColor;
    end;
    function Popup:Close()
        local Child = Library.ActiveFloat;
        if Child and Child.Owner and Child.Owner:IsDescendantOf(Frame) then
            Library:CloseFloat(Child);
        end;
        Popup.Open = false;
        Frame.Visible = false;
        GearIcon[ColorProp] = Library:GetDimColor();
    end;
    function Popup:Toggle()
        if Popup.Open then Popup:Close() else Popup:Show() end;
    end;
    function Popup:SetTitle(Text)
        for _, Child in next, Frame:GetChildren() do
            if Child:IsA('TextLabel') then
                Child.Text = Text;
                return;
            end;
        end;
    end;
    Layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
        Popup:Resize();
    end);
    Gear:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
        if Popup.Open then Place() end;
    end);
    Library:GiveSignal(Gui:GetPropertyChangedSignal('AbsoluteSize'):Connect(function()
        if Popup.Open then Popup:Resize() end;
    end));
    -- the window columns are not ancestors of the popup, so hold them explicitly
    Library.HoldWheel(Frame, nil, function() return Library.ColumnScrollers end);

    Gear.InputBegan:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
            if not Library:MouseIsOverOpenedFrame() then
                Popup:Toggle();
            end;
        end;
    end);
    Library:Hover(Gear, function()
        if not Popup.Open then
            Library:Tween(GearIcon, { [ColorProp] = Library.FontColor }, 0.1);
        end;
    end, function()
        if not Popup.Open then
            Library:Tween(GearIcon, { [ColorProp] = Library:GetDimColor() }, 0.1);
        end;
    end);
    Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
        if not Popup.Open then return end;
        if Input.UserInputType ~= Enum.UserInputType.MouseButton1 and Input.UserInputType ~= Enum.UserInputType.Touch then return end;
        if Library:IsMouseOverFrame(Frame) or Library:IsMouseOverFrame(Gear) or Library:MouseIsOverOpenedFrame() then return end;
        Popup:Close();
    end));

    Popup.Container = Content;
    Popup.Scroller = Content;
    Popup.Frame = Frame;
    Popup.Button = Gear;
    setmetatable(Popup, BaseGroupbox);
    table.insert(Library.Popups, Popup);
    self.SettingsPopups = self.SettingsPopups or {};
    table.insert(self.SettingsPopups, Popup);
    Popup:Resize();
    return Popup;
end;

-- Player priorities + player list ---------------------------------------------
Library.PlayerPriorities = Library.PlayerPriorities or {};
Library.PlayerLists = Library.PlayerLists or {};
Library.PriorityList = { 'None', 'Friendly', 'Enemy', 'Priority' };
-- theme keys, resolved at use so priorities follow the active theme
Library.PriorityColors = {
    Friendly = 'AccentColor2';
    Enemy = 'RiskColor';
    Priority = 'AccentColor';
};
Library.AvatarCache = {};

local function UserIdOf(Target)
    if type(Target) == 'number' then return Target end;
    if type(Target) == 'string' then
        local Num = tonumber(Target);
        if Num then return Num end;
        local Found = Players:FindFirstChild(Target);
        return Found and Found.UserId or nil;
    end;
    local Ok, Id = pcall(function() return Target.UserId end);
    return Ok and Id or nil;
end;

function Library:GetPlayerPriority(Target)
    local Id = UserIdOf(Target);
    return Id and Library.PlayerPriorities[Id] or 'None';
end;

function Library:SetPlayerPriority(Target, Priority, Silent)
    local Id = UserIdOf(Target);
    if not Id then return false end;
    if Priority == nil or Priority == 'None' then
        Library.PlayerPriorities[Id] = nil;
    else
        Library.PlayerPriorities[Id] = Priority;
    end;
    for _, List in ipairs(Library.PlayerLists) do
        pcall(List.Changed_, List, Id, Target, Priority or 'None', Silent);
    end;
    if not Silent then
        Library:AttemptSave();
    end;
    return true;
end;

-- Map of userId (number or string) -> priority; replaces the current table (config load)
function Library:SetPlayerPriorities(Map)
    Library.PlayerPriorities = {};
    for Key, Value in next, Map or {} do
        local Id = tonumber(Key);
        if Id and type(Value) == 'string' and Value ~= 'None' then
            Library.PlayerPriorities[Id] = Value;
        end;
    end;
    for _, List in ipairs(Library.PlayerLists) do
        pcall(List.Refresh, List);
    end;
end;

function Library:GetPlayerPriorities()
    local Out = {};
    for Id, Value in next, Library.PlayerPriorities do
        Out[tostring(Id)] = Value;
    end;
    return Out;
end;

local ColumnWidths = { Name = 0.36; DisplayName = 0.3; UserId = 0.28; Priority = 0.24; Team = 0.2; Age = 0.14 };

-- Config: { Columns, Priorities, Height, InfoPanel = true, OnPriorityChanged = fn(player, priority) }
function Library:CreatePlayerList(Parent, Config)
    Config = type(Config) == 'table' and Config or {};
    local Host = Parent and (Parent.Container or Parent);
    assert(Host, 'CreatePlayerList: Missing parent.');

    Library.PlayerListCount = (Library.PlayerListCount or 0) + 1;
    local Columns = Config.Columns or { 'Name', 'UserId', 'Priority' };
    local Priorities = Config.Priorities or Library.PriorityList;
    local Height = Config.Height or 300;
    local ShowInfo = Config.InfoPanel ~= false;
    local InfoH = ShowInfo and 104 or 0;
    local ROW_H = 22;
    local PL = { Type = 'PlayerList'; Priorities = Priorities; OnPriorityChanged = Config.OnPriorityChanged; Selected = nil; Filter = ''; Rows = {} };

    local Holder = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Size = UDim2.new(1, 0, 0, Height);
        ZIndex = 5;
        Parent = Host;
    });

    local function MakeBox(Props, Radius)
        Props.ZIndex = Props.ZIndex or 5;
        local Frame = Library:Create(Props.Class or 'Frame', Props);
        Library:Round(Frame, Radius or 5);
        Library:Stroke(Frame, 'OutlineColor');
        return Frame;
    end;

    local SearchOuter = MakeBox({
        BackgroundColor3 = Library.InputColor;
        Size = UDim2.new(1, -68, 0, 24);
        Parent = Holder;
    });
    Library:AddToRegistry(SearchOuter, { BackgroundColor3 = 'InputColor' });
    local SearchBox = Library:Create('TextBox', {
        BackgroundTransparency = 1;
        ClearTextOnFocus = false;
        Font = Library.Font;
        PlaceholderColor3 = Library:GetDimColor();
        PlaceholderText = 'Search players...';
        Position = UDim2.fromOffset(8, 0);
        Size = UDim2.new(1, -16, 1, 0);
        Text = '';
        TextColor3 = Library.FontColor;
        TextSize = Library.FontSize;
        TextXAlignment = Enum.TextXAlignment.Left;
        ZIndex = 6;
        Parent = SearchOuter;
    });
    Library:AddToRegistry(SearchBox, { TextColor3 = 'FontColor'; PlaceholderColor3 = function() return Library:GetDimColor() end });

    local RefreshBtn = MakeBox({
        Class = 'TextButton';
        AnchorPoint = Vector2.new(1, 0);
        AutoButtonColor = false;
        BackgroundColor3 = Library.InputColor;
        Font = Library.Font;
        Position = UDim2.new(1, 0, 0, 0);
        Size = UDim2.fromOffset(62, 24);
        Text = 'Refresh';
        TextColor3 = Library.FontColor;
        TextSize = Library.FontSize;
        Parent = Holder;
    });
    Library:AddToRegistry(RefreshBtn, { BackgroundColor3 = 'InputColor'; TextColor3 = 'FontColor' });
    Library:OnHover(RefreshBtn, RefreshBtn:FindFirstChildOfClass('UIStroke') or RefreshBtn, 'InputColor');

    -- column layout
    local Total = 0;
    for _, Col in ipairs(Columns) do Total = Total + (ColumnWidths[Col] or 0.25) end;
    local Xs, Ws, Cursor = {}, {}, 0;
    for Idx, Col in ipairs(Columns) do
        local W = (ColumnWidths[Col] or 0.25) / Total;
        Xs[Idx], Ws[Idx] = Cursor, W;
        Cursor = Cursor + W;
    end;

    local Header = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Position = UDim2.fromOffset(0, 30);
        Size = UDim2.new(1, 0, 0, 16);
        ZIndex = 5;
        Parent = Holder;
    });
    for Idx, Col in ipairs(Columns) do
        Library:CreateLabel({
            Dim = true;
            Position = UDim2.new(Xs[Idx], 8, 0, 0);
            Size = UDim2.new(Ws[Idx], -8, 1, 0);
            Text = Col == 'UserId' and 'User ID' or (Col == 'DisplayName' and 'Display' or Col);
            TextSize = Library.FontSize - 1;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 6;
            Parent = Header;
        });
    end;

    local ListOuter = MakeBox({
        BackgroundColor3 = Library.InputColor;
        ClipsDescendants = true;
        Position = UDim2.fromOffset(0, 48);
        Size = UDim2.new(1, 0, 1, -(48 + InfoH + (ShowInfo and 6 or 0)));
        Parent = Holder;
    });
    Library:AddToRegistry(ListOuter, { BackgroundColor3 = 'InputColor' });
    local List = Library:Create('ScrollingFrame', {
        BackgroundTransparency = 1;
        BorderSizePixel = 0;
        CanvasSize = UDim2.new(0, 0, 0, 0);
        Position = UDim2.fromOffset(2, 2);
        ScrollBarImageColor3 = Library.AccentColor;
        ScrollBarThickness = 2;
        Size = UDim2.new(1, -4, 1, -4);
        TopImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png';
        BottomImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png';
        ZIndex = 6;
        Parent = ListOuter;
    });
    Library:AddToRegistry(List, { ScrollBarImageColor3 = 'AccentColor' });
    local ListLayout = Library:Create('UIListLayout', { SortOrder = Enum.SortOrder.LayoutOrder; Parent = List });
    ListLayout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
        List.CanvasSize = UDim2.fromOffset(0, ListLayout.AbsoluteContentSize.Y);
    end);
    local EmptyLabel = Library:CreateLabel({
        Dim = true;
        AnchorPoint = Vector2.new(0.5, 0.5);
        Position = UDim2.fromScale(0.5, 0.5);
        Size = UDim2.new(1, 0, 0, 16);
        Text = 'No players found';
        TextSize = Library.FontSize;
        Visible = false;
        ZIndex = 6;
        Parent = ListOuter;
    });

    -- info panel
    local Avatar, NameLabel, IdLabel, CreatedLabel, Pseudo, PriorityDropdown;
    local DropIdx = 'AsterPlayerPriority' .. Library.PlayerListCount;
    if ShowInfo then
        local Panel = MakeBox({
            BackgroundColor3 = Library.InputColor;
            AnchorPoint = Vector2.new(0, 1);
            Position = UDim2.fromScale(0, 1);
            Size = UDim2.new(1, 0, 0, InfoH);
            Parent = Holder;
        });
        Library:AddToRegistry(Panel, { BackgroundColor3 = 'InputColor' });
        Avatar = Library:Create('ImageLabel', {
            BackgroundColor3 = Library.OutlineColor;
            Position = UDim2.fromOffset(8, 8);
            Size = UDim2.fromOffset(60, 60);
            ZIndex = 6;
            Parent = Panel;
        });
        Library:Round(Avatar, 6);
        Library:AddToRegistry(Avatar, { BackgroundColor3 = 'OutlineColor' });
        local function Line(Y, Dim, Size)
            return Library:CreateLabel({
                Dim = Dim;
                Position = UDim2.fromOffset(78, Y);
                Size = UDim2.new(1, -86, 0, 16);
                Text = '';
                TextSize = Size or Library.FontSize;
                TextTruncate = Enum.TextTruncate.AtEnd;
                TextXAlignment = Enum.TextXAlignment.Left;
                ZIndex = 6;
                Parent = Panel;
            });
        end;
        NameLabel = Line(8, false, Library.FontSize + 1);
        IdLabel = Line(28, true, Library.FontSize - 1);
        CreatedLabel = Line(46, true, Library.FontSize - 1);
        Library:CreateLabel({
            Dim = true;
            Position = UDim2.fromOffset(8, 76);
            Size = UDim2.fromOffset(60, 22);
            Text = 'Priority';
            TextSize = Library.FontSize - 1;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 6;
            Parent = Panel;
        });
        local DropHost = Library:Create('Frame', {
            BackgroundTransparency = 1;
            Position = UDim2.fromOffset(72, 74);
            Size = UDim2.new(1, -80, 0, 24);
            ZIndex = 5;
            Parent = Panel;
        });
        Library:Create('UIListLayout', { SortOrder = Enum.SortOrder.LayoutOrder; Parent = DropHost });
        Pseudo = { Container = DropHost; Root = { NoSearch = true }; Resize = function() end };
        setmetatable(Pseudo, BaseGroupbox);
        PL.Updating = true;
        PriorityDropdown = Pseudo:AddDropdown(DropIdx, {
            Values = Priorities;
            Default = 1;
            Callback = function(Value)
                if PL.Updating or not PL.Selected then return end;
                PL:SetPriority(PL.Selected, Value);
            end;
        });
        PL.Updating = false;
    end;

    local function PriorityColor(Priority)
        local Key = Library.PriorityColors[Priority];
    if typeof(Key) == 'Color3' then return Key end;
    return Key and Library[Key] or Library:GetDimColor();
    end;

    local function CellText(Col, Player)
        if Col == 'Name' then
            return Player.Name .. (Player == Players.LocalPlayer and ' (you)' or '');
        elseif Col == 'DisplayName' then
            return Player.DisplayName;
        elseif Col == 'UserId' then
            return tostring(Player.UserId);
        elseif Col == 'Priority' then
            return Library:GetPlayerPriority(Player);
        elseif Col == 'Team' then
            return Player.Team and Player.Team.Name or '-';
        elseif Col == 'Age' then
            return tostring(Player.AccountAge) .. 'd';
        end;
        return '';
    end;

    local function Paint(Id)
        local Row = PL.Rows[Id];
        if not Row then return end;
        local Selected = PL.Selected and PL.Selected.UserId == Id;
        Library:Snap(Row.Frame, { BackgroundTransparency = Selected and 0.78 or 1 });
    end;

    function PL:UpdateInfo()
        if not ShowInfo then return end;
        local Player = PL.Selected;
        PL.Updating = true;
        if not Player then
            NameLabel.Text = 'Select a player';
            IdLabel.Text = '';
            CreatedLabel.Text = '';
            Avatar.Image = '';
            PL.Updating = false;
            return;
        end;
        NameLabel.Text = Player.Name .. (Player.DisplayName ~= Player.Name and (' (' .. Player.DisplayName .. ')') or '');
        IdLabel.Text = 'User ID: ' .. tostring(Player.UserId);
        local Ok, Created = pcall(function()
            local Stamp = os.time() - Player.AccountAge * 86400;
            return os.date('%Y-%m-%d', Stamp) .. ' (' .. Player.AccountAge .. ' days)';
        end);
        CreatedLabel.Text = 'Created: ' .. (Ok and Created or 'unknown');
        PriorityDropdown:SetValue(Library:GetPlayerPriority(Player));
        PL.Updating = false;

        local Id = Player.UserId;
        local Cached = Library.AvatarCache[Id];
        Avatar.Image = Cached or '';
        if not Cached then
            task.spawn(function()
                local Done, Content = pcall(function()
                    return (Players:GetUserThumbnailAsync(Id, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100));
                end);
                if Done and type(Content) == 'string' then
                    Library.AvatarCache[Id] = Content;
                    if PL.Selected and PL.Selected.UserId == Id and Avatar.Parent then
                        Avatar.Image = Content;
                    end;
                end;
            end);
        end;
    end;

    function PL:SetSelected(Player)
        local Old = PL.Selected;
        PL.Selected = Player;
        if Old then Paint(Old.UserId) end;
        if Player then Paint(Player.UserId) end;
        PL:UpdateInfo();
    end;
    function PL:GetSelected()
        return PL.Selected;
    end;
    function PL:GetPriority(Player)
        return Library:GetPlayerPriority(Player);
    end;
    function PL:SetPriority(Player, Priority)
        if Priority ~= 'None' and not table.find(Priorities, Priority) then return end;
        Library:SetPlayerPriority(Player, Priority);
    end;
    -- called for every list when any priority changes
    function PL:Changed_(Id, Target, Priority, Silent)
        local Row = PL.Rows[Id];
        if Row and Row.Priority then
            Row.Priority.Text = Priority;
            Row.Priority.TextColor3 = PriorityColor(Priority);
        end;
        if PL.Selected and PL.Selected.UserId == Id and PriorityDropdown then
            PL.Updating = true;
            PriorityDropdown:SetValue(Priority);
            PL.Updating = false;
        end;
        if not Silent and PL.OnPriorityChanged then
            local Player = typeof(Target) == 'Instance' and Target or Players:GetPlayerByUserId(Id) or Id;
            Library:SafeCallback(PL.OnPriorityChanged, Player, Priority);
        end;
    end;

    function PL:Refresh()
        if PL.Destroyed then return end;
        for _, Child in next, List:GetChildren() do
            if Child:IsA('GuiObject') then Child:Destroy() end;
        end;
        PL.Rows = {};
        local Query = string.lower(PL.Filter);
        local Shown, SelectedStill = {}, false;
        for _, Player in ipairs(Players:GetPlayers()) do
            if PL.Selected and Player == PL.Selected then SelectedStill = true end;
            local Hay = string.lower(Player.Name .. ' ' .. Player.DisplayName .. ' ' .. tostring(Player.UserId));
            if Query == '' or string.find(Hay, Query, 1, true) then
                table.insert(Shown, Player);
            end;
        end;
        table.sort(Shown, function(A, B) return string.lower(A.Name) < string.lower(B.Name) end);
        if PL.Selected and not SelectedStill then
            PL:SetSelected(nil);
        end;

        for Order, Player in ipairs(Shown) do
            local Frame = Library:Create('Frame', {
                BackgroundColor3 = Library.AccentColor;
                BackgroundTransparency = 1;
                LayoutOrder = Order;
                Size = UDim2.new(1, 0, 0, ROW_H);
                ZIndex = 7;
                Parent = List;
            });
            Library:Round(Frame, 4);
            Library:AddToRegistry(Frame, { BackgroundColor3 = 'AccentColor' });
            local Row = { Frame = Frame };
            for Idx, Col in ipairs(Columns) do
                local Text = CellText(Col, Player);
                local Label = Library:CreateLabel({
                    Dim = Col ~= 'Name';
                    Position = UDim2.new(Xs[Idx], 8, 0, 0);
                    Size = UDim2.new(Ws[Idx], -10, 1, 0);
                    Text = Text;
                    TextSize = Library.FontSize - 1;
                    TextTruncate = Enum.TextTruncate.AtEnd;
                    TextXAlignment = Enum.TextXAlignment.Left;
                    ZIndex = 8;
                    Parent = Frame;
                });
                if Col == 'Priority' then
                    Row.Priority = Label;
                    Library:RemoveFromRegistry(Label);
                    Label.TextColor3 = PriorityColor(Text);
                end;
            end;
            PL.Rows[Player.UserId] = Row;
            Paint(Player.UserId);
            Frame.InputBegan:Connect(function(Input)
                if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                    PL:SetSelected(Player);
                end;
            end);
            Library:Hover(Frame, function()
                if not (PL.Selected and PL.Selected == Player) then
                    Library:Tween(Frame, { BackgroundTransparency = 0.92 }, 0.08);
                end;
            end, function()
                Paint(Player.UserId);
            end);
        end;
        EmptyLabel.Visible = #Shown == 0;
    end;

    function PL:SetFilter(Text)
        SearchBox.Text = tostring(Text or '');
    end;
    function PL:Destroy()
        PL.Destroyed = true;
        local At = table.find(Library.PlayerLists, PL);
        if At then table.remove(Library.PlayerLists, At) end;
        if Options[DropIdx] then Options[DropIdx] = nil end;
        Holder:Destroy();
    end;

    SearchBox:GetPropertyChangedSignal('Text'):Connect(function()
        PL.Filter = SearchBox.Text;
        PL:Refresh();
    end);
    RefreshBtn.MouseButton1Click:Connect(function()
        PL:Refresh();
    end);
    local Pending = false;
    local function Queue()
        if Pending then return end;
        Pending = true;
        task.delay(0.15, function()
            Pending = false;
            PL:Refresh();
        end);
    end;
    Library:GiveSignal(Players.PlayerAdded:Connect(Queue));
    Library:GiveSignal(Players.PlayerRemoving:Connect(Queue));

    table.insert(Library.PlayerLists, PL);
    PL.Frame = Holder;
    PL:UpdateInfo();
    PL:Refresh();
    if type(Parent) == 'table' and Parent.AddBlank then
        Parent:AddBlank(4);
        Parent:Resize();
    end;
    return PL;
end;

-- Intro -----------------------------------------------------------------------
local function TweenDelayed(Obj, Props, Time, Delay, Style, Dir)
    pcall(function()
        TweenService:Create(Obj, TweenInfo.new(Time, Style or Enum.EasingStyle.Quad, Dir or Enum.EasingDirection.Out, 0, false, Delay or 0), Props):Play();
    end);
end;

-- Config: { Title, Subtitle, Duration, Steps = {}, Blur = true, ShowMenu = true, Skippable = true,
--           Manual = false, WaitForStable = true, OnFinish = fn }. Returns a handle with Skip / Cancel / SetStatus / SetProgress / Finish.
-- Never yields: the intro stays hidden until frames are smooth again, because the script that calls it
-- usually freezes the client while it builds the UI and a wall-clock timeline would be over by then.
function Library:PlayIntro(Config)
    Config = type(Config) == 'table' and Config or {};
    if Library.Unloaded then return nil end;
    if Library.ActiveIntro then Library.ActiveIntro:Cancel() end;
    -- the menu appears again when the intro ends
    if Library.Toggled and Library.Toggle and Config.HideMenu ~= false then
        Library:Toggle();
    end;

    local Title = tostring(Config.Title or 'ASTER');
    local Subtitle = Config.Subtitle ~= nil and tostring(Config.Subtitle) or '';
    local Duration = math.max(1.2, tonumber(Config.Duration) or 2.6);
    local Steps = type(Config.Steps) == 'table' and Config.Steps or {};
    local Accent = Config.AccentColor or Library.AccentColor;
    local Accent2 = Config.AccentColor2 or Library.AccentColor2;
    local Intro = { Playing = true; Started = false; Progress = 0 };
    -- every timed tween waits on the intro's own clock so a hitch pauses the timeline instead of skipping it
    local Queue = {};
    local function Schedule(Obj, Props, Time, Delay, Style, Dir)
        table.insert(Queue, { At = Delay or 0; Obj = Obj; Props = Props; Time = Time; Style = Style; Dir = Dir });
    end;
    -- registered so the intro repaints live if the theme changes mid-play
    local Registered = {};
    local function Reg(Obj, Props, IsAccent)
        if IsAccent and Config.AccentColor then return Obj end;
        table.insert(Registered, Obj);
        Library:AddToRegistry(Obj, Props);
        return Obj;
    end;

    local Gui = Instance.new('ScreenGui');
    Gui.Name = 'AsterIntro';
    pcall(ProtectGui, Gui);
    Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling;
    Gui.ResetOnSpawn = false;
    Gui.Enabled = false;
    pcall(function() Gui.IgnoreGuiInset = true; Gui.DisplayOrder = 100 end);
    Gui.Parent = GetGuiParent();
    Intro.Gui = Gui;

    local Backdrop = Library:Create('Frame', {
        BackgroundColor3 = Library.SidebarColor;
        BackgroundTransparency = 1;
        Size = UDim2.fromScale(1, 1);
        Parent = Gui;
    });
    Reg(Backdrop, { BackgroundColor3 = 'SidebarColor' });
    local Blur;
    if Config.Blur ~= false then
        pcall(function()
            Blur = Instance.new('BlurEffect');
            Blur.Name = 'AsterIntroBlur';
            Blur.Size = 0;
            Blur.Parent = Lighting;
        end);
    end;
    Schedule(Backdrop, { BackgroundTransparency = Config.BackdropTransparency or 0.2 }, 0.4);
    if Blur then Schedule(Blur, { Size = 18 }, 0.5) end;

    local GroupOk, Group = pcall(Instance.new, 'CanvasGroup');
    local Center = Library:Create(GroupOk and Group or Instance.new('Frame'), {
        AnchorPoint = Vector2.new(0.5, 0.5);
        BackgroundTransparency = 1;
        ClipsDescendants = false;
        Position = UDim2.new(0.5, 0, 0.5, -67);
        Size = UDim2.fromOffset(1000, 520);
        Parent = Gui;
    });
    -- canvas groups always clip, so it is oversized (rings, long titles); Y0 shifts content down inside it
    local Y0 = 180;
    local ViewY = 800;
    pcall(function() ViewY = workspace.CurrentCamera.ViewportSize.Y end);
    local BaseScale = math.clamp(ViewY / 900, 0.6, 1.5);
    local CenterScale = Library:Create('UIScale', { Scale = BaseScale; Parent = Center });
    local function Fade(Alpha)
        pcall(function() Center.GroupTransparency = Alpha end);
    end;

    local function Circle(Size, Y, Props)
        Props.AnchorPoint = Vector2.new(0.5, 0.5);
        Props.Position = UDim2.new(0.5, 0, 0, Y + Y0);
        Props.Size = UDim2.fromOffset(Size, Size);
        Props.Parent = Center;
        local Frame = Library:Create('Frame', Props);
        Library:Create('UICorner', { CornerRadius = UDim.new(1, 0); Parent = Frame });
        return Frame;
    end;

    for Idx = 1, 2 do
        local Ring = Circle(70, 62, { BackgroundTransparency = 1 });
        local Stroke = Library:Create('UIStroke', { Color = Accent; Thickness = 2; Transparency = 0.1; Parent = Ring });
        Reg(Stroke, { Color = 'AccentColor' }, true);
        Schedule(Ring, { Size = UDim2.fromOffset(250, 250) }, 1.3, 0.1 + (Idx - 1) * 0.4, Enum.EasingStyle.Quint);
        Schedule(Stroke, { Transparency = 1 }, 1.3, 0.1 + (Idx - 1) * 0.4);
    end;

    local Logo;
    local LogoApi;
    pcall(function() Logo, LogoApi = Library:CreateLogo(Center, 84, 3, false, true) end);
    if Logo then
        Logo.AnchorPoint = Vector2.new(0.5, 0.5);
        Logo.Position = UDim2.new(0.5, 0, 0, 62 + Y0);
        LogoApi.Draw(0.9, 0.05);
    end;

    local Sweep = Library:Create('Frame', {
        AnchorPoint = Vector2.new(0.5, 0.5);
        BackgroundColor3 = Accent;
        Position = UDim2.new(0.5, 0, 0, 124 + Y0);
        Size = UDim2.fromOffset(0, 1);
        Parent = Center;
    });
    Reg(Sweep, { BackgroundColor3 = 'AccentColor' }, true);
    Schedule(Sweep, { Size = UDim2.fromOffset(320, 1) }, 0.6, 0.3, Enum.EasingStyle.Quint);
    Schedule(Sweep, { BackgroundTransparency = 1 }, 0.5, 1.1);

    -- title letters reveal one by one, sliding up
    local TitleRow = Library:Create('Frame', {
        AnchorPoint = Vector2.new(0.5, 0);
        AutomaticSize = Enum.AutomaticSize.X;
        BackgroundTransparency = 1;
        Position = UDim2.new(0.5, 0, 0, 134 + Y0);
        Size = UDim2.fromOffset(0, 44);
        Parent = Center;
    });
    Library:Create('UIListLayout', {
        FillDirection = Enum.FillDirection.Horizontal;
        Padding = UDim.new(0, 3);
        SortOrder = Enum.SortOrder.LayoutOrder;
        Parent = TitleRow;
    });
    local Index = 0;
    for Char in string.gmatch(Title, '.') do
        Index = Index + 1;
        local Ok, Width = pcall(Library.GetTextBounds, Library, Char, Enum.Font.GothamBold, 32);
        local Cell = Library:Create('Frame', {
            BackgroundTransparency = 1;
            LayoutOrder = Index;
            Size = UDim2.fromOffset((Ok and Width or 22) + 8, 44);
            Parent = TitleRow;
        });
        local Letter = Library:Create('TextLabel', {
            BackgroundTransparency = 1;
            Font = Enum.Font.GothamBold;
            Position = UDim2.fromOffset(0, 14);
            Size = UDim2.fromScale(1, 1);
            ClipsDescendants = false;
            Text = Char;
            TextColor3 = Library.FontColor;
            TextSize = 32;
            TextTransparency = 1;
            Parent = Cell;
        });
        Reg(Letter, { TextColor3 = 'FontColor' });
        local Delay = 0.45 + Index * 0.06;
        Schedule(Letter, { Position = UDim2.fromOffset(0, 0); TextTransparency = 0 }, 0.45, Delay, Enum.EasingStyle.Back);
    end;

    local SubLabel = Library:Create('TextLabel', {
        AnchorPoint = Vector2.new(0.5, 0);
        BackgroundTransparency = 1;
        Font = Enum.Font.Gotham;
        Position = UDim2.new(0.5, 0, 0, 184 + Y0);
        Size = UDim2.fromOffset(600, 20);
        Text = Subtitle;
        TextColor3 = Library:GetDimColor();
        TextSize = 13;
        TextTransparency = 1;
        Parent = Center;
    });
    Reg(SubLabel, { TextColor3 = 'DimColor' });
    Schedule(SubLabel, { TextTransparency = 0 }, 0.5, 0.45 + Index * 0.06 + 0.1);

    local BarW = 300;
    local StepLabel = Library:Create('TextLabel', {
        AnchorPoint = Vector2.new(0.5, 0);
        BackgroundTransparency = 1;
        Font = Enum.Font.Gotham;
        Position = UDim2.new(0.5, -40, 0, 210 + Y0);
        Size = UDim2.fromOffset(BarW - 80, 18);
        Text = '';
        TextColor3 = Library:GetDimColor();
        TextSize = 12;
        TextTransparency = 1;
        TextTruncate = Enum.TextTruncate.AtEnd;
        TextXAlignment = Enum.TextXAlignment.Left;
        Parent = Center;
    });
    Reg(StepLabel, { TextColor3 = 'DimColor' });
    local Percent = Library:Create('TextLabel', {
        AnchorPoint = Vector2.new(0.5, 0);
        BackgroundTransparency = 1;
        Font = Enum.Font.GothamBold;
        Position = UDim2.new(0.5, BarW / 2 - 30, 0, 210 + Y0);
        Size = UDim2.fromOffset(60, 18);
        Text = '0%';
        TextColor3 = Library.FontColor;
        TextSize = 12;
        TextTransparency = 1;
        TextXAlignment = Enum.TextXAlignment.Right;
        Parent = Center;
    });
    Reg(Percent, { TextColor3 = 'FontColor' });
    local function BarSequence()
        local A, B = Config.AccentColor or Library.AccentColor, Config.AccentColor2 or Library.AccentColor2;
        return ColorSequence.new({ ColorSequenceKeypoint.new(0, A), ColorSequenceKeypoint.new(0.5, B), ColorSequenceKeypoint.new(1, A) });
    end;
    local Track = Library:Create('Frame', {
        AnchorPoint = Vector2.new(0.5, 0);
        BackgroundColor3 = Library.FontColor;
        BackgroundTransparency = 1;
        Position = UDim2.new(0.5, 0, 0, 232 + Y0);
        Size = UDim2.fromOffset(BarW, 4);
        Parent = Center;
    });
    Reg(Track, { BackgroundColor3 = 'FontColor' });
    Library:Create('UICorner', { CornerRadius = UDim.new(1, 0); Parent = Track });
    local Fill = Library:Create('Frame', {
        BackgroundColor3 = Color3.new(1, 1, 1);
        Size = UDim2.fromScale(0, 1);
        Parent = Track;
    });
    Library:Create('UICorner', { CornerRadius = UDim.new(1, 0); Parent = Fill });
    local Gradient = Library:Create('UIGradient', {
        Color = BarSequence();
        Parent = Fill;
    });
    Reg(Gradient, { Color = BarSequence });
    local BarDelay = 0.6;
    Schedule(Track, { BackgroundTransparency = 0.88 }, 0.4, BarDelay);
    Schedule(StepLabel, { TextTransparency = 0 }, 0.4, BarDelay);
    Schedule(Percent, { TextTransparency = 0 }, 0.4, BarDelay);

    local StepShown = 0;
    function Intro:SetStatus(Text)
        StepLabel.Text = tostring(Text or '');
        StepLabel.TextTransparency = 0.6;
        TweenDelayed(StepLabel, { TextTransparency = 0 }, 0.15);
    end;
    function Intro:SetProgress(Alpha)
        Intro.Progress = math.clamp(tonumber(Alpha) or 0, 0, 1);
        Fill.Size = UDim2.fromScale(Intro.Progress, 1);
        Percent.Text = tostring(math.floor(Intro.Progress * 100)) .. '%';
        local Idx = math.min(#Steps, math.floor(Intro.Progress * #Steps) + 1);
        if #Steps > 0 and Idx ~= StepShown and Intro.Progress < 1 then
            StepShown = Idx;
            Intro:SetStatus(Steps[Idx]);
        end;
    end;

    local Connections = {};
    local Cleaned = false;
    local function Cleanup()
        if Cleaned then return end;
        Cleaned = true;
        for _, Connection in ipairs(Connections) do
            pcall(function() Connection:Disconnect() end);
        end;
        Connections = {};
        for _, Obj in ipairs(Registered) do
            Library:RemoveFromRegistry(Obj);
        end;
        if Logo then
            for _, Descendant in ipairs(Logo:GetDescendants()) do
                Library:RemoveFromRegistry(Descendant);
            end;
        end;
        if Blur then pcall(function() Blur:Destroy() end) end;
        pcall(function() Gui:Destroy() end);
        if Library.ActiveIntro == Intro then Library.ActiveIntro = nil end;
    end;

    local Ended = false;
    function Intro:Cancel()
        Ended = true;
        Intro.Playing = false;
        Cleanup();
    end;

    local function ShowMenu()
        if Config.ShowMenu ~= false and not Library.Unloaded and not Library.Toggled then
            Library:Toggle();
        end;
    end;

    -- Quick collapse: bar completes, content scales out, backdrop and blur fade, menu fades in
    function Intro:Finish()
        if Ended then return end;
        Ended = true;
        Intro.Playing = false;
        if not Intro.Started then
            -- nothing on screen yet, so there is nothing to animate out
            Cleanup();
            ShowMenu();
            if not Library.Unloaded then Library:SafeCallback(Config.OnFinish) end;
            return;
        end;
        Intro:SetProgress(1);
        StepLabel.Text = Config.DoneText or 'Ready';
        for _, Connection in ipairs(Connections) do
            pcall(function() Connection:Disconnect() end);
        end;
        Connections = {};
        TweenDelayed(CenterScale, { Scale = BaseScale * 1.12 }, 0.45, 0.1, Enum.EasingStyle.Quint, Enum.EasingDirection.In);
        pcall(function()
            TweenService:Create(Center, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.1), { GroupTransparency = 1 }):Play();
        end);
        TweenDelayed(Backdrop, { BackgroundTransparency = 1 }, 0.5, 0.15);
        if Blur then TweenDelayed(Blur, { Size = 0 }, 0.5, 0.15) end;
        task.delay(0.2, ShowMenu);
        task.delay(0.7, function()
            Cleanup();
            if not Library.Unloaded then Library:SafeCallback(Config.OnFinish) end;
        end);
    end;
    function Intro:Skip()
        Intro:Finish();
    end;

    local T = 0;
    local Lead = 0.6;
    local function RunQueue()
        local Index = 1;
        while Index <= #Queue do
            local Item = Queue[Index];
            if Item.At <= T then
                table.remove(Queue, Index);
                TweenDelayed(Item.Obj, Item.Props, Item.Time, 0, Item.Style, Item.Dir);
            else
                Index = Index + 1;
            end;
        end;
    end;
    local function Begin()
        if Ended or Intro.Started then return end;
        Intro.Started = true;
        Gui.Enabled = true;
        RunQueue();
        if Config.Skippable ~= false then
            table.insert(Connections, InputService.InputBegan:Connect(function(Input)
                if (Input.KeyCode == Enum.KeyCode.Escape or Input.KeyCode == Enum.KeyCode.Space) and not Library:IsTypingInput(Input) then
                    Intro:Skip();
                end;
            end));
        end;
    end;

    local StableFrames = math.max(1, tonumber(Config.StableFrames) or 10);
    local StableTimeout = tonumber(Config.StableTimeout) or 10;
    local StartDelay = math.max(0, tonumber(Config.StartDelay) or 0.2);
    local Waited, Smooth, Settle = 0, 0, nil;
    table.insert(Connections, RunService.Heartbeat:Connect(function(Dt)
        Dt = tonumber(Dt) or 1 / 60;
        if not Intro.Started then
            Waited = Waited + Dt;
            if Settle then
                Settle = Settle + math.min(Dt, 1 / 30);
                if Settle >= StartDelay then Begin() end;
            elseif Dt < 1 / 20 then
                Smooth = Smooth + 1;
                if Smooth >= StableFrames then Settle = 0 end;
            else
                Smooth = 0;
            end;
            if not Intro.Started and Waited >= StableTimeout then Begin() end;
            return;
        end;
        T = T + math.min(Dt, 1 / 30);
        RunQueue();
        Gradient.Offset = Vector2.new(-1 + (T * 0.9) % 2, 0);
        if not Config.Manual then
            local Alpha = math.clamp((T - Lead) / math.max(0.1, Duration - Lead - 0.2), 0, 1);
            Intro:SetProgress(Alpha * Alpha * (3 - 2 * Alpha));
            if T >= Duration then
                Intro:Finish();
            end;
        end;
    end));
    if Config.WaitForStable == false then Begin() end;

    Library:OnUnload(function() Intro:Cancel() end);
    Library.ActiveIntro = Intro;
    return Intro;
end;


do
    Library.NotificationStack = {};
    -- open and closing notification handles, oldest first; NotifyById maps an Id to its open handle
    Library.Notifications = {};
    Library.NotifyById = {};

    Library.NotificationArea = Library:Create('Frame', {
        BackgroundTransparency  = 1;
        Position                = UDim2.new(0, 0, 0, 40);
        Size                    = UDim2.new(0, 320, 1, -50);
        ZIndex                  = 100;
        Parent                  = ScreenGui;
    });
    -- no padding: each card's holder carries its own gap, so the gap collapses with the card
    Library:Create('UIListLayout', {
        Padding        = UDim.new(0, 0);
        FillDirection  = Enum.FillDirection.Vertical;
        SortOrder      = Enum.SortOrder.LayoutOrder;
        Parent         = Library.NotificationArea;
    });

    function Library:ConfigureNotifications(Cfg)
        local C = Library.NotifyConfig;
        for k, v in next, Cfg do C[k] = v end;

        local AnchorX = C.Alignment == "Left" and 0 or (C.Alignment == "Right" and 1 or 0.5);
        local Top     = (C.VAnchor or C.BarSide) == "Top";
        local AnchorY = Top and 0 or 1;
        local VAlign  = Top and Enum.VerticalAlignment.Top or Enum.VerticalAlignment.Bottom;
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

    Library.NotifyCorners = {
        ['Top Left']      = { PosX = 1;  PosY = 3;  Alignment = 'Left';   VAnchor = 'Top' };
        ['Top Center']    = { PosX = 50; PosY = 3;  Alignment = 'Center'; VAnchor = 'Top' };
        ['Top Right']     = { PosX = 99; PosY = 3;  Alignment = 'Right';  VAnchor = 'Top' };
        ['Bottom Left']   = { PosX = 1;  PosY = 97; Alignment = 'Left';   VAnchor = 'Bottom' };
        ['Bottom Center'] = { PosX = 50; PosY = 97; Alignment = 'Center'; VAnchor = 'Bottom' };
        ['Bottom Right']  = { PosX = 99; PosY = 97; Alignment = 'Right';  VAnchor = 'Bottom' };
    };
    Library.NotifyCornerList = { 'Top Left', 'Top Center', 'Top Right', 'Bottom Left', 'Bottom Center', 'Bottom Right' };

    function Library:SetNotifyCorner(Corner)
        local Preset = Library.NotifyCorners[Corner];
        if not Preset then return end;
        Library.NotifyCorner = Corner;
        Library:ConfigureNotifications(Preset);
    end;

    -- Watermark pill: logo | brand | fps | ping | time
    local WatermarkOuter = Library:Create('Frame', {
        BackgroundColor3 = Library.WatermarkColor;
        AutomaticSize = Enum.AutomaticSize.X;
        AnchorPoint = Vector2.new(0.5, 0);
        Position = UDim2.new(0.5, 0, 0, 8);
        Size = UDim2.new(0, 0, 0, 28);
        ZIndex = 200;
        Visible = false;
        Parent = ScreenGui;
    });
    Library:Round(WatermarkOuter, 7);
    Library:Stroke(WatermarkOuter, 'OutlineColor');
    Library:AddToRegistry(WatermarkOuter, {
        BackgroundColor3 = 'WatermarkColor';
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

    local WatermarkLogo = Library:CreateLogo(WatermarkContent, 18, 202, true);
    WatermarkLogo.LayoutOrder = 1;

    local WatermarkLabel = Library:CreateLabel({
        AutomaticSize = Enum.AutomaticSize.X;
        Font = Enum.Font.GothamBold;
        LayoutOrder = 2;
        Size = UDim2.new(0, 0, 1, 0);
        Text = 'aster';
        TextColor3 = Library.AccentColor;
        TextSize = Library.FontSize;
        TextXAlignment = Enum.TextXAlignment.Left;
        ZIndex = 203;
        Parent = WatermarkContent;
    }, true);
    Library:RemoveFromRegistry(WatermarkLabel);
    Library:AddToRegistry(WatermarkLabel, { TextColor3 = 'AccentColor' }, true);

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


    Library.Watermark = WatermarkOuter;
    Library.WatermarkText = WatermarkLabel;
    Library.WatermarkStats = true;
    Library:MakeDraggable(Library.Watermark);

    -- Hotkeys panel
    local KeybindOuter = Library:Create('Frame', {
        AnchorPoint = Vector2.new(0, 0.5);
        BackgroundColor3 = Library.KeybindColor;
        Position = UDim2.new(0, 10, 0.5, 0);
        Size = UDim2.new(0, 210, 0, 36);
        Visible = false;
        ZIndex = 100;
        Parent = ScreenGui;
    });
    Library:Round(KeybindOuter, 7);
    Library:Stroke(KeybindOuter, 'OutlineColor');
    Library:AddToRegistry(KeybindOuter, {
        BackgroundColor3 = 'KeybindColor';
    }, true);

    Library.KeybindInner = KeybindOuter;

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
        PaddingRight = UDim.new(0, 10),
        Parent = KeybindContainer,
    })
    KeybindContainer.ClipsDescendants = true;

    Library.KeybindFrame = KeybindOuter;
    Library.KeybindTarget = KeybindOuter.Size;
    Library.KeybindContainer = KeybindContainer;
    Library:MakeDraggable(KeybindOuter);
end;

function Library:SetKeybindMode(Mode)
    assert(Mode == 'All' or Mode == 'Active' or Mode == 'Toggled',
        "SetKeybindMode: Mode must be 'All', 'Active', or 'Toggled'")
    Library.KeybindMode = Mode
    Library:RefreshKeybinds()
end

-- Filter = { OnlyEnabled = list only features currently on, OnlyBound = list only features with a key set }
Library.KeybindFilter = Library.KeybindFilter or { OnlyEnabled = false; OnlyBound = false };
function Library:SetKeybindListFilter(Filter)
    Filter = Filter or {};
    for _, Key in ipairs({ 'OnlyEnabled', 'OnlyBound' }) do
        if Filter[Key] ~= nil then Library.KeybindFilter[Key] = not not Filter[Key] end;
    end;
    Library:RefreshKeybinds();
end;

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

-- Notifications ---------------------------------------------------------------
-- Cards use the groupbox look (NotifyColor panel, outline, 6px corners). One RenderStepped ticker runs the
-- enter/exit animation, the timer and the progress bar of every card, so nothing waits on task.wait.
Library.NotifyMaxVisible = 6;
Library.NotifyMaxWidth = 300;
Library.NotifyMinWidth = 160;
Library.NotifyIcon = 'bell';
Library.NotifySoundVolume = 0.5;

local NOTIFY_PAD, NOTIFY_GAP, NOTIFY_ICON, NOTIFY_SLIDE = 10, 6, 14, 18;
local NOTIFY_IN, NOTIFY_OUT = 0.22, 0.2;

local NotifyMethods = {};
NotifyMethods.__index = NotifyMethods;

local function NotifyAccent(Note)
    return Note.Accent or Library.AccentColor;
end;

local PaintNotify;

local function LayoutNotify(Note)
    if Note.Dead then return end;
    local Size = Library.FontSize;
    local Bold = Library:BoldFont();
    local HasIcon = false;
    if Note.Icon ~= false then
        HasIcon = Library:ApplyIcon(Note.IconImage, Note.Icon or Library.NotifyIcon);
    end;
    Note.IconImage.Visible = HasIcon;
    local TextX = NOTIFY_PAD + (HasIcon and NOTIFY_ICON + 8 or 0);

    local TitleW, TitleH = 0, 0;
    if Note.Title then TitleW, TitleH = Library:GetTextBounds(Note.Title, Bold, Size) end;
    local TextW, LineH = Library:GetTextBounds(Note.Text ~= '' and Note.Text or 'A', Library.Font, Size);
    if Note.Text == '' then TextW = 0 end;
    local W = math.clamp(math.ceil(math.max(TitleW, TextW)) + TextX + NOTIFY_PAD, Library.NotifyMinWidth, Library.NotifyMaxWidth);
    local AreaW = W - TextX - NOTIFY_PAD;
    local BodyH = 0;
    if Note.Text ~= '' then
        local _, Wrapped = Library:GetTextBounds(Note.Text, Library.Font, Size, Vector2.new(AreaW, 10000));
        BodyH = math.ceil(Wrapped);
    end;
    TitleH, LineH = math.ceil(TitleH), math.ceil(LineH);

    local Y = NOTIFY_PAD;
    local Title, Body = Note.TitleLabel, Note.TextLabel;
    Title.Visible = Note.Title ~= nil;
    Title.Font = Bold;
    Title.TextSize = Size;
    Title.Text = Note.Title or '';
    if Note.Title then
        Title.Position = UDim2.fromOffset(TextX, Y);
        Title.Size = UDim2.fromOffset(AreaW, TitleH);
        Y = Y + TitleH + (BodyH > 0 and 2 or 0);
    end;
    Body.Visible = BodyH > 0;
    Body.Font = Library.Font;
    Body.TextSize = Size;
    Body.Text = Note.Text;
    Body.Position = UDim2.fromOffset(TextX, Y);
    Body.Size = UDim2.fromOffset(AreaW, BodyH);
    Y = Y + BodyH;

    local H = Y + NOTIFY_PAD;
    local FirstLine = Note.Title and TitleH or LineH;
    Note.IconImage.Position = UDim2.fromOffset(NOTIFY_PAD, NOTIFY_PAD + math.floor((FirstLine - NOTIFY_ICON) / 2));
    Note.Card.Size = UDim2.fromOffset(W, H);
    Note.Track.Position = UDim2.fromOffset(NOTIFY_PAD, H - 4);
    Note.Track.Size = UDim2.fromOffset(W - NOTIFY_PAD * 2, 2);
    Note.Track.Visible = Note.Progress and Note.Duration < math.huge;
    Note.W, Note.H = W, H;
    Note.LastE, Note.BarPx = nil, nil;
    PaintNotify(Note, 1 - (1 - Note.Show) ^ 3);
end;

function PaintNotify(Note, E)
    local C = Library.NotifyConfig;
    local Bottom = (C.VAnchor or C.BarSide) ~= 'Top';
    local Dir = C.Alignment == 'Right' and 1 or (C.Alignment == 'Left' and -1 or 0);
    local Base = math.clamp(Library.WindowTransparency * 0.6, 0, 1);
    local Key = E .. ':' .. Base .. ':' .. Dir .. ':' .. tostring(Bottom);
    if Note.LastE ~= Key then
        Note.LastE = Key;
        local Fade = 1 - E;
        Note.Holder.Size = UDim2.fromOffset(Note.W, math.floor((Note.H + NOTIFY_GAP) * E + 0.5));
        Note.Card.AnchorPoint = Vector2.new(0, Bottom and 1 or 0);
        Note.Card.Position = UDim2.new(0, Dir * math.floor(NOTIFY_SLIDE * Fade + 0.5), Bottom and 1 or 0, 0);
        Note.Card.BackgroundTransparency = Base + (1 - Base) * Fade;
        Note.Stroke.Transparency = Fade;
        Note.TitleLabel.TextTransparency = Fade;
        Note.TextLabel.TextTransparency = Fade;
        Note.IconImage.ImageTransparency = Fade;
        Note.Track.BackgroundTransparency = 0.5 + 0.5 * Fade;
        Note.Bar.BackgroundTransparency = Fade;
    end;
    local Frac = 1;
    if Note.Duration > 0 and Note.Duration < math.huge then
        Frac = math.clamp(1 - Note.Elapsed / Note.Duration, 0, 1);
    end;
    local Px = math.floor((Note.W - NOTIFY_PAD * 2) * Frac + 0.5);
    if Note.BarPx ~= Px then
        Note.BarPx = Px;
        Note.Bar.Size = UDim2.fromOffset(Px, 2);
    end;
end;

local function BuildNotify(Note)
    local Holder = Library:Create('Frame', {
        Name = 'Notification';
        BackgroundTransparency = 1;
        LayoutOrder = Note.Order;
        Size = UDim2.fromOffset(0, 0);
        ZIndex = 100;
        Parent = Library.NotificationArea;
    });
    local Card = Library:Create('Frame', {
        BackgroundColor3 = Library.NotifyColor;
        BackgroundTransparency = 1;
        ZIndex = 101;
        Parent = Holder;
    });
    Library:Round(Card, 6);
    Library:AddToRegistry(Card, { BackgroundColor3 = 'NotifyColor' });
    local Stroke = Library:Stroke(Card, 'OutlineColor', 1, 1);

    local Icon = Library:Create('ImageLabel', {
        BackgroundTransparency = 1;
        ImageColor3 = NotifyAccent(Note);
        ImageTransparency = 1;
        Size = UDim2.fromOffset(NOTIFY_ICON, NOTIFY_ICON);
        ZIndex = 103;
        Parent = Card;
    });
    Library:AddToRegistry(Icon, { ImageColor3 = function() return NotifyAccent(Note) end });

    local Title = Library:CreateLabel({
        TextSize = Library.FontSize;
        TextTransparency = 1;
        TextTruncate = Enum.TextTruncate.AtEnd;
        TextXAlignment = Enum.TextXAlignment.Left;
        TextYAlignment = Enum.TextYAlignment.Top;
        ZIndex = 103;
        Parent = Card;
    });
    local Body = Library:CreateLabel({
        TextSize = Library.FontSize;
        TextTransparency = 1;
        TextWrapped = true;
        TextXAlignment = Enum.TextXAlignment.Left;
        TextYAlignment = Enum.TextYAlignment.Top;
        ZIndex = 103;
        Parent = Card;
    });
    -- with a title the body steps back to the dim colour, like a groupbox header over its rows
    Library:RemoveFromRegistry(Body);
    Library:AddToRegistry(Body, { TextColor3 = function() return Note.Title and Library:GetDimColor() or Library.FontColor end });

    local Track = Library:Create('Frame', {
        BackgroundColor3 = Library.OutlineColor;
        BackgroundTransparency = 1;
        ZIndex = 102;
        Parent = Card;
    });
    Library:Round(Track, 1);
    Library:AddToRegistry(Track, { BackgroundColor3 = 'OutlineColor' });
    local Bar = Library:Create('Frame', {
        BackgroundColor3 = NotifyAccent(Note);
        BackgroundTransparency = 1;
        ZIndex = 103;
        Parent = Track;
    });
    Library:Round(Bar, 1);
    Library:AddToRegistry(Bar, { BackgroundColor3 = function() return NotifyAccent(Note) end });

    Note.Holder, Note.Card, Note.Stroke, Note.IconImage = Holder, Card, Stroke, Icon;
    Note.TitleLabel, Note.TextLabel, Note.Track, Note.Bar = Title, Body, Track, Bar;
end;

local function RepaintNotifyColors(Note)
    Note.IconImage.ImageColor3 = NotifyAccent(Note);
    Note.Bar.BackgroundColor3 = NotifyAccent(Note);
    Note.TextLabel.TextColor3 = Note.Title and Library:GetDimColor() or Library.FontColor;
end;

local function PlayNotifySound(Id)
    if Id == nil or Id == false then return end;
    pcall(function()
        local Asset = tostring(Id);
        if not Asset:find('://', 1, true) then Asset = 'rbxassetid://' .. Asset end;
        local Sound = Instance.new('Sound');
        Sound.SoundId = Asset;
        Sound.Volume = Library.NotifySoundVolume;
        Sound.Parent = game:GetService('SoundService');
        Sound.Ended:Connect(function() Sound:Destroy() end);
        Sound:Play();
        task.delay(15, function() pcall(function() Sound:Destroy() end) end);
    end);
end;

local function NotifyTitle(Value)
    if Value == nil or Value == false then return nil end;
    Value = tostring(Value);
    return Value ~= '' and Value or nil;
end;

function NotifyMethods:SetText(Text)
    self.Text = Text ~= nil and tostring(Text) or '';
    LayoutNotify(self);
    return self;
end;

function NotifyMethods:SetTitle(Title)
    self.Title = NotifyTitle(Title);
    if not self.Dead then RepaintNotifyColors(self) end;
    LayoutNotify(self);
    return self;
end;

function NotifyMethods:SetDuration(Seconds)
    self.Duration = tonumber(Seconds) or self.Duration;
    self.Elapsed = 0;
    LayoutNotify(self);
    return self;
end;

function NotifyMethods:Update(Info)
    if Info.Title ~= nil then self.Title = NotifyTitle(Info.Title) end;
    if Info.Text ~= nil then self.Text = tostring(Info.Text) end;
    if Info.Icon ~= nil then self.Icon = Info.Icon end;
    if Info.Accent ~= nil then self.Accent = typeof(Info.Accent) == 'Color3' and Info.Accent or nil end;
    if Info.Progress ~= nil then self.Progress = Info.Progress ~= false end;
    if Info.Duration ~= nil then self.Duration = tonumber(Info.Duration) or self.Duration end;
    self.Elapsed = 0;
    if not self.Dead then RepaintNotifyColors(self) end;
    LayoutNotify(self);
    PlayNotifySound(Info.Sound);
    return self;
end;

function NotifyMethods:Close()
    if self.Closing then return end;
    self.Closing = true;
    if self.Id ~= nil and Library.NotifyById[self.Id] == self then
        Library.NotifyById[self.Id] = nil;
    end;
    Library.ActiveNotifyCount = math.max(0, Library.ActiveNotifyCount - 1);
end;

local function DestroyNotify(Note)
    Note.Dead = true;
    for _, Obj in ipairs(Note.Holder:GetDescendants()) do
        Library:RemoveFromRegistry(Obj);
    end;
    Note.Holder:Destroy();
end;

local function StepNotify(Note, Dt)
    if Note.Closing then
        Note.Show = math.max(0, Note.Show - Dt / NOTIFY_OUT);
    else
        Note.Show = math.min(1, Note.Show + Dt / NOTIFY_IN);
        Note.Elapsed = Note.Elapsed + Dt;
        if Note.Elapsed >= Note.Duration then Note:Close() end;
    end;
    PaintNotify(Note, 1 - (1 - Note.Show) ^ 3);
    if Note.Closing and Note.Show <= 0 then
        DestroyNotify(Note);
        return true;
    end;
end;

Library:GiveSignal(RenderStepped:Connect(function(Delta)
    local List = Library.Notifications;
    if #List == 0 then return end;
    Delta = tonumber(Delta) or 0;
    for Idx = #List, 1, -1 do
        if StepNotify(List[Idx], Delta) then
            table.remove(List, Idx);
        end;
    end;
end));

function Library:RelayoutNotifications()
    for _, Note in ipairs(Library.Notifications) do
        LayoutNotify(Note);
    end;
end;

-- Library:Notify(Text, Duration) or Library:Notify({ Title, Text, Duration, Icon, Accent, Progress, Id, Sound }) -> handle
function Library:Notify(Info, Duration)
    if type(Info) ~= 'table' then
        Info = { Text = Info; Duration = Duration };
    end;
    local Text = Info.Text ~= nil and tostring(Info.Text) or '';
    local Title = NotifyTitle(Info.Title);
    if Text == '' and not Title then return end;

    local Existing = Info.Id ~= nil and Library.NotifyById[Info.Id];
    if Existing and not Existing.Closing then
        return Existing:Update(Info);
    end;

    Library.NotifyCounter = Library.NotifyCounter + 1;
    local Note = setmetatable({
        Id = Info.Id;
        Title = Title;
        Text = Text;
        Icon = Info.Icon;
        Accent = typeof(Info.Accent) == 'Color3' and Info.Accent or nil;
        Progress = Info.Progress ~= false;
        Duration = tonumber(Info.Duration) or 5;
        Elapsed = 0;
        Show = 0;
        Order = Library.NotifyConfig.SortOrder == 'Text Length' and #Text or Library.NotifyCounter;
    }, NotifyMethods);
    BuildNotify(Note);
    RepaintNotifyColors(Note);
    LayoutNotify(Note);
    table.insert(Library.Notifications, Note);
    Library.ActiveNotifyCount = Library.ActiveNotifyCount + 1;
    if Note.Id ~= nil then Library.NotifyById[Note.Id] = Note end;

    -- oldest open cards make room past the cap
    local Open = {};
    for _, Other in ipairs(Library.Notifications) do
        if not Other.Closing then Open[#Open + 1] = Other end;
    end;
    for Idx = 1, #Open - math.max(1, Library.NotifyMaxVisible) do
        Open[Idx]:Close();
    end;

    PlayNotifySound(Info.Sound);
    return Note;
end;

-- kept for scripts that queued through the old API
function Library:ProcessNotifyQueue()
    while #Library.NotifyQueue > 0 do
        local Item = table.remove(Library.NotifyQueue, 1);
        Library:Notify(Item.Text, Item.Time);
    end;
end;

function Library:SpawnNotify(Text, Time)
    return Library:Notify(Text, Time);
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

    if typeof(Config.Size) ~= 'UDim2' then Config.Size = UDim2.fromOffset(900, 600) end
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
    Library.Window = Window;

    local Outer = Library:Create('Frame', {
        AnchorPoint = Config.AnchorPoint,
        BackgroundTransparency = 1;
        Position = Config.Position,
        Size = Config.Size,
        Visible = false;
        ZIndex = 1;
        Parent = ScreenGui;
    });
    Library.MenuOuter = Outer;
    Library:MakeDraggable(Outer, HEADER_H, true);

    local WindowScale = Library:Create('UIScale', { Scale = Library.UIScale; Parent = Outer });
    Library.WindowScale = WindowScale;
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
    Library:AddTransparent(Inner, 1);
    local BorderStroke = Library:Create('UIStroke', {
        Color = Color3.new(1, 1, 1);
        Thickness = Library.OutlineThickness;
        Transparency = 0.3;
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border;
        Parent = Inner;
    });
    Library:AddGradient(Library:Create('UIGradient', { Parent = BorderStroke }), 'spin', true, 'X', true);

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
    Library:AddGradient(TopLineGradient, 'slide', false, 'X', true);
    Library.Outline = { Stroke = BorderStroke; TopLine = TopLine; TopLineGradient = TopLineGradient };
    Library:UpdateGradients();
    Library:ApplyOutline();

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
        BackgroundColor3 = 'SidebarColor';
    });
    Library:AddTransparent(Sidebar, 1);
    local SidebarFill = Library:Create('Frame', {
        BackgroundColor3 = Library:GetSidebarColor();
        Position = UDim2.new(1, -8, 0, 0);
        Size = UDim2.new(0, 8, 1, 0);
        ZIndex = 3;
        Parent = Sidebar;
    });
    Library:AddToRegistry(SidebarFill, {
        BackgroundColor3 = 'SidebarColor';
    });
    Library:AddTransparent(SidebarFill, 1);
    local SidebarEdge = Library:Create('Frame', {
        BackgroundColor3 = Library.OutlineColor;
        Position = UDim2.new(1, -1, 0, 0);
        Size = UDim2.new(0, 1, 1, 0);
        ZIndex = 4;
        Parent = Sidebar;
    });
    Library:AddToRegistry(SidebarEdge, { BackgroundColor3 = 'OutlineColor' });

    local SidebarLogo = Library:CreateLogo(Sidebar, 36, 5, true);
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
        TextColor3 = Library.AccentColor;
        TextSize = Library.FontSize + 4;
        ZIndex = 4;
        Parent = HeaderLeft;
    });
    Library:AddToRegistry(WindowLabel, { TextColor3 = 'AccentColor' });
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
        -- min size comes from Library.MinWidth/MinHeight (SetMinSize); max is the viewport
        local function Limits(Left, Top)
            local Scale = math.max(Library.UIScale or 1, 0.1);
            local VP = Library.ScreenGui.AbsoluteSize;
            local MaxW = math.max(VP.X / Scale - Left, 1);
            local MaxH = math.max(VP.Y / Scale - Top, 1);
            return math.min(Library.MinWidth, MaxW), math.min(Library.MinHeight, MaxH), MaxW, MaxH;
        end;

        local function ClampWindow()
            if Library.Unloaded or Library.ScreenGui.AbsoluteSize.X <= 0 then return end;
            local MinW, MinH, MaxW, MaxH = Limits(10, 10);
            local W = math.clamp(Outer.Size.X.Offset, MinW, MaxW);
            local H = math.clamp(Outer.Size.Y.Offset, MinH, MaxH);
            if W ~= Outer.Size.X.Offset or H ~= Outer.Size.Y.Offset then
                Outer.Size = UDim2.fromOffset(W, H);
            end;
        end;
        Library.ClampWindow = ClampWindow;
        function Window:SetSize(Size)
            if typeof(Size) == 'UDim2' then Outer.Size = Size end;
            ClampWindow();
        end;
        ClampWindow();
        Library:GiveSignal(Library.ScreenGui:GetPropertyChangedSignal('AbsoluteSize'):Connect(ClampWindow));

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

                local Scale = math.max(Library.UIScale or 1, 0.1);
                local MinW, MinH, MaxW, MaxH = Limits(TopLeft.X / Scale, TopLeft.Y / Scale);
                local NewW = math.clamp(StartSize.X.Offset + Delta.X / Scale, MinW, MaxW);
                local NewH = math.clamp(StartSize.Y.Offset + Delta.Y / Scale, MinH, MaxH);

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

    function Window:AddTab(Name, Icon, Opts)
        Opts = type(Opts) == 'table' and Opts or {};
        local Tab = {
            Groupboxes = {};
            Tabboxes = {};
            SubTabs = {};
            SubTabList = {};
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
            BackgroundColor3 = Library.AccentColor;
            BackgroundTransparency = 1;
            LayoutOrder = Tab.LayoutOrder;
            Size = UDim2.fromOffset(TAB_BTN, TAB_BTN);
            ZIndex = 5;
            Parent = Tab.Bottom and BottomArea or TabArea;
        });
        Library:Round(TabButton, 8);
        Library:AddToRegistry(TabButton, { BackgroundColor3 = 'AccentColor' });

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
            table.insert(Library.ColumnScrollers, Side);
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
        local COLS, COL_GAP = 3, 10;
        local Columns = {};
        for Col = 1, COLS do
            Columns[Col] = MakeSide(
                UDim2.new((Col - 1) / COLS, (Col - 1) * COL_GAP / COLS, 0, 0),
                UDim2.new(1 / COLS, -COL_GAP * (COLS - 1) / COLS, 1, 0)
            );
        end;
        Tab.ColumnCount = COLS;
        Tab.Columns = Columns;
        Tab.Cards = {};
        Tab.Canvases = {};

        -- Info.Column (1..3) wins; legacy Info.Side 2 means the right-most column
        local function ColumnOf(Info)
            local Col = tonumber(Info.Column);
            if not Col then
                Col = Info.Side == 2 and COLS or (tonumber(Info.Side) or 1);
            end;
            return math.clamp(math.floor(Col), 1, COLS);
        end;

        function Tab:FindCard(Key)
            for _, Card in ipairs(Tab.Cards) do
                if Card.Key == Key then return Card end;
            end;
        end;

        -- cards of one column in display order (hidden sub-tab cards included)
        function Tab:GetCards(Col)
            local List = {};
            for _, Card in ipairs(Tab.Cards) do
                if Card.Column == Col then table.insert(List, Card) end;
            end;
            table.sort(List, function(A, B) return A.Outer.LayoutOrder < B.Outer.LayoutOrder end);
            return List;
        end;

        local function Reflow(Col)
            for Order, Card in ipairs(Tab:GetCards(Col)) do
                Card.Outer.LayoutOrder = Order;
            end;
        end;

        -- Index counts the other cards of the target column, 1 = top
        function Tab:MoveCard(Card, Col, Index)
            if type(Card) == 'string' then Card = Tab:FindCard(Card) end;
            if not Card then return end;
            Col = math.clamp(math.floor(tonumber(Col) or Card.Column), 1, COLS);
            local Old = Card.Column;
            local List = {};
            for _, Other in ipairs(Tab:GetCards(Col)) do
                if Other ~= Card then table.insert(List, Other) end;
            end;
            table.insert(List, math.clamp(math.floor(tonumber(Index) or (#List + 1)), 1, #List + 1), Card);
            Card.Column = Col;
            Card.Outer.Parent = Columns[Col];
            for Order, Other in ipairs(List) do
                Other.Outer.LayoutOrder = Order;
            end;
            if Old ~= Col then Reflow(Old) end;
        end;

        -- column under X (nearest one when between columns) and the slot under Y, skipping hidden cards
        local function DropTarget(Card, X, Y)
            local Col, Best = 1, math.huge;
            for I, Side in ipairs(Columns) do
                local P, S = Side.AbsolutePosition, Side.AbsoluteSize;
                local D = X < P.X and (P.X - X) or (X > P.X + S.X and (X - P.X - S.X) or 0);
                if D < Best then Best, Col = D, I end;
            end;
            local List = {};
            for _, Other in ipairs(Tab:GetCards(Col)) do
                if Other ~= Card then table.insert(List, Other) end;
            end;
            local Index, LineY, Last;
            for I, Other in ipairs(List) do
                if Other.Outer.Visible then
                    local P, S = Other.Outer.AbsolutePosition, Other.Outer.AbsoluteSize;
                    if Y < P.Y + S.Y / 2 then
                        Index, LineY = I, P.Y - COL_GAP / 2;
                        break;
                    end;
                    Last, LineY = I, P.Y + S.Y + COL_GAP / 2;
                end;
            end;
            Index = Index or (Last and Last + 1) or 1;
            return Col, Index, LineY or (Columns[Col].AbsolutePosition.Y + 2);
        end;

        local DropLine = Library:Create('Frame', {
            BackgroundColor3 = Library.AccentColor;
            Size = UDim2.fromOffset(100, 2);
            Visible = false;
            ZIndex = 30;
            Parent = TabFrame;
        });
        Library:Round(DropLine, 1);
        Library:AddToRegistry(DropLine, { BackgroundColor3 = 'AccentColor' });

        -- press a card header and move past a few pixels to drag it; a plain click passes through
        local function BindCardDrag(Card, Handle)
            Handle.InputBegan:Connect(function(Input)
                if Input.UserInputType ~= Enum.UserInputType.MouseButton1 and Input.UserInputType ~= Enum.UserInputType.Touch then return end;
                if not Library.MovableSections or Library.CardDrag or Library:MouseIsOverOpenedFrame() then return end;
                local SX, SY = Input.Position.X, Input.Position.Y;
                local Drag = { Card = Card; Started = false };
                local Ghost, MovedConn, EndedConn;
                Library.CardDrag = Drag;

                function Drag.Stop(Commit)
                    if MovedConn then MovedConn:Disconnect() end;
                    if EndedConn then EndedConn:Disconnect() end;
                    if Library.CardDrag == Drag then Library.CardDrag = nil end;
                    DropLine.Visible = false;
                    if Ghost then pcall(function() Ghost:Destroy() end) end;
                    if Commit and Drag.Started and Drag.Col then
                        Tab:MoveCard(Card, Drag.Col, Drag.Index);
                        Library:SafeCallback(Library.OnLayoutChanged, Library:GetLayout());
                    end;
                end;

                MovedConn = InputService.InputChanged:Connect(function(Change)
                    if Change.UserInputType ~= Enum.UserInputType.MouseMovement and Change ~= Input then return end;
                    local X, Y = Change.Position.X, Change.Position.Y;
                    if not Drag.Started then
                        if math.abs(X - SX) + math.abs(Y - SY) < 5 then return end;
                        Drag.Started = true;
                        Library:CloseAllPopups();
                        local Abs, Size = Card.Outer.AbsolutePosition, Card.Outer.AbsoluteSize;
                        Drag.OX, Drag.OY = SX - Abs.X, SY - Abs.Y;
                        -- transient, so coloured directly instead of through the registry
                        Ghost = Library:Create('Frame', {
                            BackgroundColor3 = Library.GroupboxColor;
                            BackgroundTransparency = 0.35;
                            Size = UDim2.fromOffset(Size.X, math.min(Size.Y, 220));
                            ZIndex = 60;
                            Parent = Library:GetPopupGui();
                        });
                        Library:Create('UICorner', { CornerRadius = UDim.new(0, math.floor(6 * Library.UIScale * Library.CornerScale + 0.5)); Parent = Ghost });
                        Library:Create('UIStroke', { Color = Library.OutlineColor; Thickness = 1; Parent = Ghost });
                        Library:Create('TextLabel', {
                            BackgroundTransparency = 1;
                            Font = Library.Font;
                            Position = UDim2.fromOffset(12 * Library.UIScale, 0);
                            Size = UDim2.new(1, -24, 0, 28 * Library.UIScale);
                            Text = Card.Title or Card.Key;
                            TextColor3 = Library.FontColor;
                            TextSize = math.floor((Library.FontSize - 1) * Library.UIScale + 0.5);
                            TextTransparency = 0.25;
                            TextXAlignment = Enum.TextXAlignment.Left;
                            ZIndex = 61;
                            Parent = Ghost;
                        });
                    end;
                    Ghost.Position = UDim2.fromOffset(X - Drag.OX, Y - Drag.OY);

                    local Col, Index, LineY = DropTarget(Card, X, Y);
                    Drag.Col, Drag.Index = Col, Index;
                    local Scale = math.max(Library.UIScale, 0.1);
                    local Side, Origin = Columns[Col], TabFrame.AbsolutePosition;
                    DropLine.Size = UDim2.fromOffset(math.max(Side.AbsoluteSize.X / Scale - 5, 20), 2);
                    DropLine.Position = UDim2.fromOffset((Side.AbsolutePosition.X - Origin.X) / Scale, (LineY - Origin.Y) / Scale - 1);
                    DropLine.Visible = true;
                end);
                EndedConn = InputService.InputEnded:Connect(function(EndInput)
                    if EndInput == Input or EndInput.UserInputType == Enum.UserInputType.MouseButton1 or EndInput.UserInputType == Enum.UserInputType.Touch then
                        Drag.Stop(true);
                    end;
                end);
            end);
        end;

        local function AddCard(Box, Outer, Info, Handle)
            local Key = Info.Name or ('Tabbox ' .. tostring(#Tab.Cards + 1));
            if Info.SubTab then Key = Info.SubTab.Name .. '/' .. Key end;
            local Base, N = Key, 1;
            while Tab:FindCard(Key) do
                N = N + 1;
                Key = Base .. ' #' .. N;
            end;
            local Card = { Key = Key; Title = Info.Name; Box = Box; Outer = Outer; Column = ColumnOf(Info) };
            Outer.LayoutOrder = #Tab:GetCards(Card.Column) + 1;
            Outer.Parent = Columns[Card.Column];
            table.insert(Tab.Cards, Card);
            Box.Card = Card;
            if Handle then BindCardDrag(Card, Handle) end;
            return Card;
        end;

        function Tab:ShowTab()
            if Window.ActiveTab == Tab then return; end;
            for _, Other in ipairs(Window.TabList) do
                if Other ~= Tab then
                    Other:HideTab();
                end;
            end;

            Library:CloseAllPopups();
            local First = Window.ActiveTab == nil;
            Window.ActiveTab = Tab;
            Tab.Active = true;
            TabTitleLabel.Text = Name;
            if SearchBox.Text ~= '' then
                SearchBox.Text = '';
            end;

            TabFrame.Visible = true;
            Library:Tween(TabButton, { BackgroundTransparency = 0.86 }, 0.15);
            Library:Tween(IconInst, { [IconProp] = Library.AccentColor }, 0.15);
            if Tab.SyncCanvases then Tab:SyncCanvases() end;

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
            if Tab.SyncCanvases then Tab:SyncCanvases() end;
        end;
        function Tab:SetLayoutOrder(Position)
            Tab.LayoutOrder = Position;
            TabButton.LayoutOrder = Position;
        end;

        -- Tab:AddGroupbox(Name, Column?, Icon?) or the legacy Tab:AddGroupbox({ Name, Side | Column, Icon })
        function Tab:AddGroupbox(Info, Column, Icon)
            if type(Info) ~= 'table' then
                Info = { Name = tostring(Info); Column = Column; Icon = Icon };
            end;
            local Groupbox = {};
            local BoxOuter = Library:Create('Frame', {
                BackgroundColor3 = Library.GroupboxColor;
                Size = UDim2.new(1, 0, 0, 100);
                ZIndex = 2;
                Visible = Info.Host ~= nil or Info.SubTab == nil or Info.SubTab.Active;
            });
            Library:Round(BoxOuter, 6);
            if Library.CardOutline then Library:Stroke(BoxOuter, 'OutlineColor'); end;
            Library:AddToRegistry(BoxOuter, {
                BackgroundColor3 = 'GroupboxColor';
            });
            Library:AddTransparent(BoxOuter, 0.6);

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
            -- the header doubles as the drag handle for moving the card
            local DragHandle = Library:Create('Frame', {
                Name = 'DragHandle';
                BackgroundTransparency = 1;
                Size = UDim2.new(1, 0, 0, 28);
                ZIndex = 6;
                Parent = BoxOuter;
            });
            local TOP = 32;
            local Container = Library:Create('Frame', {
                BackgroundTransparency = 1;
                Position = UDim2.new(0, 12, 0, TOP);
                Size = UDim2.new(1, -24, 1, -TOP);
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

                BoxOuter.Size = UDim2.new(1, 0, 0, TOP + Size + 8);
            end;

            Groupbox.Container = Container;
            Groupbox.Outer = BoxOuter;
            Groupbox.Title = Info.Name;
            Groupbox.SubTab = Info.SubTab;
            if Info.SubTab then
                local Sub = Info.SubTab;
                Groupbox.Gate = function() return Sub.Active end;
                table.insert(Sub.Boxes, Groupbox);
                Sub.Groupboxes[Info.Name] = Groupbox;
            end;
            -- Info.Host (a canvas pane scroller): stacked there, outside the card layout and the search
            if Info.Host then
                Groupbox.NoSearch = true;
                BoxOuter.LayoutOrder = #Info.Host:GetChildren();
                BoxOuter.Parent = Info.Host;
            else
                AddCard(Groupbox, BoxOuter, Info, DragHandle);
            end;
            setmetatable(Groupbox, BaseGroupbox);
            Groupbox:AddBlank(3);
            Groupbox:Resize();

            if Info.Host then
                return Groupbox;
            elseif Info.SubTab and Tab.Groupboxes[Info.Name] then
                Tab.Groupboxes[Info.SubTab.Name .. '/' .. Info.Name] = Groupbox;
            else
                Tab.Groupboxes[Info.Name] = Groupbox;
            end;

            return Groupbox;
        end;

        function Tab:AddLeftGroupbox(Name, Icon)
            return Tab:AddGroupbox({ Side = 1; Name = Name; Icon = Icon; });
        end;

        function Tab:AddMiddleGroupbox(Name, Icon)
            return Tab:AddGroupbox({ Column = 2; Name = Name; Icon = Icon; });
        end;

        function Tab:AddRightGroupbox(Name, Icon)
            return Tab:AddGroupbox({ Side = 2; Name = Name; Icon = Icon; });
        end;

        -- Tab:AddTabbox(Name, Column?, { IconOnly }) or the legacy Tab:AddTabbox({ Name, Side | Column, IconOnly })
        function Tab:AddTabbox(Info, Column, Opts)
            if type(Info) ~= 'table' then
                Info = { Name = Info ~= nil and tostring(Info) or nil; Column = Column; IconOnly = type(Opts) == 'table' and Opts.IconOnly };
            end;
            local IconOnly = Info.IconOnly;
            local Tabbox = {
                Tabs = {};
            };

            local BoxOuter = Library:Create('Frame', {
                BackgroundColor3 = Library.GroupboxColor;
                Size = UDim2.new(1, 0, 0, 0);
                ZIndex = 2;
                Visible = Info.SubTab == nil or Info.SubTab.Active;
            });
            Library:Round(BoxOuter, 6);
            if Library.CardOutline then Library:Stroke(BoxOuter, 'OutlineColor'); end;
            Library:AddToRegistry(BoxOuter, {
                BackgroundColor3 = 'GroupboxColor';
            });
            Library:AddTransparent(BoxOuter, 0.6);
            if Info.SubTab then
                table.insert(Info.SubTab.Boxes, Tabbox);
            end;
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
            Tabbox.Title = Info.Name;
            AddCard(Tabbox, BoxOuter, Info, TabboxButtons);

            -- Icon is optional; with Info.IconOnly the header shows just the icon (tooltip carries the name)
            function Tabbox:AddTab(Name, Icon)
                local Tab = { Selected = false };
                local Button = Library:Create('Frame', {
                    BackgroundTransparency = 1;
                    Size = UDim2.new(0.5, 0, 1, 0);
                    ZIndex = 6;
                    Parent = TabboxButtons;
                });
                local TabHighlight = Library:Create('Frame', {
                    AnchorPoint = Vector2.new(0.5, 1);
                    BackgroundColor3 = Library.AccentColor;
                    Position = UDim2.new(0.5, 0, 1, 0);
                    Size = UDim2.new(1, -16, 0, 2);
                    Visible = false;
                    ZIndex = 10;
                    Parent = Button;
                });
                Library:Round(TabHighlight, 1);
                Library:AddToRegistry(TabHighlight, { BackgroundColor3 = 'AccentColor' });
                local Content = Library:Create('Frame', {
                    BackgroundTransparency = 1;
                    Size = UDim2.new(1, 0, 1, 0);
                    ZIndex = 7;
                    Parent = Button;
                });
                Library:Create('UIListLayout', {
                    FillDirection = Enum.FillDirection.Horizontal;
                    HorizontalAlignment = Enum.HorizontalAlignment.Center;
                    VerticalAlignment = Enum.VerticalAlignment.Center;
                    Padding = UDim.new(0, 5);
                    SortOrder = Enum.SortOrder.LayoutOrder;
                    Parent = Content;
                });
                local TabIcon;
                if Icon then
                    TabIcon = Library:Create('ImageLabel', {
                        BackgroundTransparency = 1;
                        LayoutOrder = 1;
                        Size = UDim2.fromOffset(IconOnly and 16 or 14, IconOnly and 16 or 14);
                        ZIndex = 8;
                        Parent = Content;
                    });
                    if Library:ApplyIcon(TabIcon, Icon) then
                        Library:AddToRegistry(TabIcon, { ImageColor3 = function() return Tab.Selected and Library.AccentColor or Library:GetDimColor() end });
                    else
                        TabIcon:Destroy();
                        TabIcon = nil;
                    end;
                end;
                if IconOnly then
                    Library:AddToolTip(Name, Button);
                end;
                local ButtonLabel = Library:CreateLabel({
                    Dim = true;
                    AutomaticSize = Enum.AutomaticSize.X;
                    LayoutOrder = 2;
                    Size = UDim2.new(0, 0, 1, 0);
                    TextSize = Library.FontSize;
                    Text = Name;
                    TextXAlignment = Enum.TextXAlignment.Center;
                    Visible = not (IconOnly and TabIcon ~= nil);
                    ZIndex = 8;
                    Parent = Content;
                });
                Library.RegistryMap[ButtonLabel].Properties.TextColor3 = function()
                    return Tab.Selected and Library.FontColor or Library:GetDimColor();
                end;
                local function Paint()
                    ButtonLabel.TextColor3 = Tab.Selected and Library.FontColor or Library:GetDimColor();
                    if TabIcon then
                        TabIcon.ImageColor3 = Tab.Selected and Library.AccentColor or Library:GetDimColor();
                    end;
                end;
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
                    Tab.Selected = true;
                    Paint();

                    Tab:Resize();
                end;
                function Tab:Hide()
                    Container.Visible = false;
                    TabHighlight.Visible = false;
                    Tab.Selected = false;
                    Paint();
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
                    Paint();
                end;

                return Tab;
            end;

            Tab.Tabboxes[Info.Name or ''] = Tabbox;

            return Tabbox;
        end;
        -- Opts: { IconOnly = bool }
        function Tab:AddLeftTabbox(Name, Opts)
            return Tab:AddTabbox({ Name = Name, Side = 1; IconOnly = type(Opts) == 'table' and Opts.IconOnly });
        end;

        function Tab:AddMiddleTabbox(Name, Opts)
            return Tab:AddTabbox({ Name = Name, Column = 2; IconOnly = type(Opts) == 'table' and Opts.IconOnly });
        end;

        function Tab:AddRightTabbox(Name, Opts)
            return Tab:AddTabbox({ Name = Name, Side = 2; IconOnly = type(Opts) == 'table' and Opts.IconOnly });
        end;

        -- Sub-tabs: a bar at the top of the page. Each sub-tab owns boxes that show and hide together.
        local SUB_H = 34;
        local SUB_PAD, SUB_ICON, SUB_ICON_GAP = 10, 14, 6;
        local SubBar, SubRow;
        local function EnsureSubBar()
            if SubBar then return end;
            SubBar = Library:Create('Frame', {
                BackgroundTransparency = 1;
                Size = UDim2.new(1, 0, 0, SUB_H);
                ZIndex = 3;
                Parent = TabFrame;
            });
            SubRow = Library:Create('Frame', {
                BackgroundTransparency = 1;
                Size = UDim2.new(1, 0, 1, 0);
                ZIndex = 3;
                Parent = SubBar;
            });
            Library:Create('UIListLayout', {
                FillDirection = Enum.FillDirection.Horizontal;
                Padding = UDim.new(0, 4);
                SortOrder = Enum.SortOrder.LayoutOrder;
                VerticalAlignment = Enum.VerticalAlignment.Center;
                Parent = SubRow;
            });
            local Line = Library:Create('Frame', {
                BackgroundColor3 = Library.OutlineColor;
                Position = UDim2.new(0, 0, 0, SUB_H - 1);
                Size = UDim2.new(1, 0, 0, 1);
                ZIndex = 3;
                Parent = TabFrame;
            });
            Library:AddToRegistry(Line, { BackgroundColor3 = 'OutlineColor' });
            for _, Side in ipairs(Columns) do
                Side.Position = UDim2.new(Side.Position.X.Scale, Side.Position.X.Offset, 0, SUB_H + 8);
                Side.Size = UDim2.new(Side.Size.X.Scale, Side.Size.X.Offset, 1, -(SUB_H + 8));
            end;
            for _, Canvas in ipairs(Tab.Canvases) do
                Canvas.Frame.Position = UDim2.fromOffset(0, SUB_H + 8);
                Canvas.Frame.Size = UDim2.new(1, 0, 1, -(SUB_H + 8));
            end;
            Tab.SubBar = SubBar;
        end;

        -- Tab:AddSubTab(Name, Icon?, { IconOnly = bool, Callback = fn })
        function Tab:AddSubTab(SubName, Icon, Opts)
            if type(Icon) == 'table' then
                Opts = Icon;
                Icon = Opts.Icon;
            end;
            Opts = type(Opts) == 'table' and Opts or {};
            EnsureSubBar();

            local IconOnly = Opts.IconOnly == true;
            local Sub = { Name = SubName; Tab = Tab; Active = false; Boxes = {}; Groupboxes = {}; IconOnly = IconOnly; Callback = Opts.Callback };
            local TextW = Library:GetTextBounds(SubName, Library.Font, Library.FontSize) or 40;
            local Button = Library:Create('Frame', {
                BackgroundColor3 = Library.AccentColor;
                BackgroundTransparency = 1;
                LayoutOrder = #Tab.SubTabList + 1;
                Size = UDim2.fromOffset(32, SUB_H - 4);
                ZIndex = 4;
                Parent = SubRow;
            });
            Library:Round(Button, 6);
            Library:AddToRegistry(Button, { BackgroundColor3 = 'AccentColor' });
            local Content = Library:Create('Frame', {
                BackgroundTransparency = 1;
                Size = UDim2.new(1, 0, 1, 0);
                ZIndex = 5;
                Parent = Button;
            });
            Library:Create('UIListLayout', {
                FillDirection = Enum.FillDirection.Horizontal;
                HorizontalAlignment = Enum.HorizontalAlignment.Center;
                VerticalAlignment = Enum.VerticalAlignment.Center;
                Padding = UDim.new(0, SUB_ICON_GAP);
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = Content;
            });
            local SubIcon;
            if Icon then
                SubIcon = Library:Create('ImageLabel', {
                    BackgroundTransparency = 1;
                    LayoutOrder = 1;
                    Size = UDim2.fromOffset(IconOnly and 18 or SUB_ICON, IconOnly and 18 or SUB_ICON);
                    ZIndex = 6;
                    Parent = Content;
                });
                if Library:ApplyIcon(SubIcon, Icon) then
                    Library:AddToRegistry(SubIcon, { ImageColor3 = function() return Sub.Active and Library.AccentColor or Library:GetDimColor() end });
                else
                    SubIcon:Destroy();
                    SubIcon = nil;
                end;
            end;
            local ShowLabel = not (IconOnly and SubIcon ~= nil);
            -- sized from the icon that actually resolved, so an unknown icon name leaves no empty slot
            if ShowLabel then
                Button.Size = UDim2.fromOffset(SUB_PAD * 2 + TextW + (SubIcon and SUB_ICON + SUB_ICON_GAP or 0), SUB_H - 4);
            end;
            local SubLabel = Library:CreateLabel({
                Dim = true;
                AutomaticSize = Enum.AutomaticSize.X;
                LayoutOrder = 2;
                Size = UDim2.new(0, 0, 1, 0);
                TextSize = Library.FontSize;
                Text = SubName;
                Visible = ShowLabel;
                ZIndex = 6;
                Parent = Content;
            });
            Library.RegistryMap[SubLabel].Properties.TextColor3 = function()
                return Sub.Active and Library.FontColor or Library:GetDimColor();
            end;
            if IconOnly then
                Library:AddToolTip(SubName, Button);
            end;

            local function Paint()
                SubLabel.TextColor3 = Sub.Active and Library.FontColor or Library:GetDimColor();
                if SubIcon then
                    SubIcon.ImageColor3 = Sub.Active and Library.AccentColor or Library:GetDimColor();
                end;
                Library:Tween(Button, { BackgroundTransparency = Sub.Active and 0.88 or 1 }, 0.12);
            end;

            function Sub:SetActive(Bool)
                Sub.Active = Bool;
                for _, Box in ipairs(Sub.Boxes) do
                    if Box.Outer then
                        Box.Outer.Visible = Bool;
                    end;
                end;
                Paint();
            end;
            function Sub:Show()
                for _, Other in ipairs(Tab.SubTabList) do
                    Other:SetActive(Other == Sub);
                end;
                Tab.ActiveSub = Sub;
                Tab:SyncCanvases();
                -- re-run the filter so search hits never un-hide a box of another sub-tab
                Library:ApplySearch(Library.SearchQuery or '');
                Library:SafeCallback(Sub.Callback, Sub.Name);
            end;
            function Sub:AddGroupbox(Info, Column, BoxIcon)
                if type(Info) ~= 'table' then
                    Info = { Name = tostring(Info); Column = Column; Icon = BoxIcon };
                end;
                Info.SubTab = Sub;
                return Tab:AddGroupbox(Info);
            end;
            function Sub:AddLeftGroupbox(BoxName, BoxIcon)
                return Sub:AddGroupbox({ Side = 1; Name = BoxName; Icon = BoxIcon; });
            end;
            function Sub:AddMiddleGroupbox(BoxName, BoxIcon)
                return Sub:AddGroupbox({ Column = 2; Name = BoxName; Icon = BoxIcon; });
            end;
            function Sub:AddRightGroupbox(BoxName, BoxIcon)
                return Sub:AddGroupbox({ Side = 2; Name = BoxName; Icon = BoxIcon; });
            end;
            function Sub:AddTabbox(BoxName, Column, BoxOpts)
                return Tab:AddTabbox({ Name = BoxName; Column = Column; SubTab = Sub; IconOnly = type(BoxOpts) == 'table' and BoxOpts.IconOnly });
            end;
            function Sub:AddLeftTabbox(BoxName, BoxOpts)
                return Sub:AddTabbox(BoxName, 1, BoxOpts);
            end;
            function Sub:AddMiddleTabbox(BoxName, BoxOpts)
                return Sub:AddTabbox(BoxName, 2, BoxOpts);
            end;
            function Sub:AddRightTabbox(BoxName, BoxOpts)
                return Sub:AddTabbox(BoxName, 3, BoxOpts);
            end;
            -- full-area canvas shown only while this sub-tab is active
            function Sub:AddCanvas(CanvasInfo)
                CanvasInfo = type(CanvasInfo) == 'table' and CanvasInfo or {};
                CanvasInfo.SubTab = Sub;
                return Tab:AddCanvas(CanvasInfo);
            end;

            Button.InputBegan:Connect(function(Input)
                if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                    if not Sub.Active then
                        Sub:Show();
                    end;
                end;
            end);
            Library:Hover(Button, function()
                if not Sub.Active then
                    Library:Tween(Button, { BackgroundTransparency = 0.94 }, 0.1);
                end;
            end, function()
                if not Sub.Active then
                    Library:Tween(Button, { BackgroundTransparency = 1 }, 0.1);
                end;
            end);

            Sub.Button = Button;
            Tab.SubTabs[SubName] = Sub;
            table.insert(Tab.SubTabList, Sub);
            if not Tab.ActiveSub then
                Tab.ActiveSub = Sub;
                Sub.Active = true;
            end;
            Paint();
            return Sub;
        end;

        -- Full-area canvas (Info.SubTab: only while that sub-tab is active). While one shows, the three columns hide.
        -- Info: { Name, Padding = 0, Lazy = true, Build = fn(Canvas) }: Build runs on the first show (at once with Lazy = false)
        function Tab:AddCanvas(Info)
            Info = type(Info) == 'table' and Info or {};
            local Sub = Info.SubTab;
            local Top = SubBar and (SUB_H + 8) or 0;
            local Frame = Library:Create('Frame', {
                Name = 'Canvas';
                BackgroundTransparency = 1;
                ClipsDescendants = true;
                Position = UDim2.fromOffset(0, Top);
                Size = UDim2.new(1, 0, 1, -Top);
                Visible = false;
                ZIndex = 2;
                Parent = TabFrame;
            });
            local Pad = math.floor(tonumber(Info.Padding) or 0);
            if Pad > 0 then
                Library:Create('UIPadding', {
                    PaddingLeft = UDim.new(0, Pad);
                    PaddingRight = UDim.new(0, Pad);
                    PaddingTop = UDim.new(0, Pad);
                    PaddingBottom = UDim.new(0, Pad);
                    Parent = Frame;
                });
            end;
            local Canvas = MakePane(Frame, nil);
            Canvas.Canvas, Canvas.Tab, Canvas.Sub, Canvas.Nodes = Canvas, Tab, Sub, {};
            Canvas.Name = Info.Name or (Sub and Sub.Name) or Name;
            Canvas.Build = type(Info.Build) == 'function' and Info.Build or nil;
            function Canvas:Destroy()
                local At = table.find(Tab.Canvases, Canvas);
                if At then table.remove(Tab.Canvases, At) end;
                if Sub and Sub.Canvas == Canvas then Sub.Canvas = nil end;
                if Canvas.Shown then
                    Canvas.Shown = false;
                    for _, Fn in ipairs(Canvas.HideFns) do Library:SafeCallback(Fn, Canvas) end;
                end;
                pcall(function() Frame:Destroy() end);
                Tab:SyncCanvases();
            end;
            table.insert(Tab.Canvases, Canvas);
            if Sub then Sub.Canvas = Canvas end;
            if Canvas.Build and Info.Lazy == false then
                Canvas.Built = true;
                Library:SafeCallback(Canvas.Build, Canvas);
            end;
            Tab:SyncCanvases();
            return Canvas;
        end;

        function Tab:SyncCanvases()
            local Covered = false;
            for _, Canvas in ipairs(Tab.Canvases) do
                local On = Canvas.Sub == nil or Canvas.Sub.Active == true;
                Canvas.Frame.Visible = On;
                if On then Covered = true end;
            end;
            for _, Side in ipairs(Columns) do
                Side.Visible = not Covered;
            end;
            for _, Canvas in ipairs(Tab.Canvases) do
                Canvas:Sync();
            end;
        end;

        function Tab:SelectSubTab(Target)
            local Sub = type(Target) == 'table' and Target or Tab.SubTabs[Target];
            if Sub then
                Sub:Show();
            end;
        end;

        TabButton.InputBegan:Connect(function(Input)
            if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) then
                Tab:ShowTab();
            end;
        end);
        Library:Hover(TabButton, function()
            if not Tab.Active then
                Library:Tween(TabButton, { BackgroundTransparency = 0.94 }, 0.12);
            end;
            local Pos = TabPosition(Tab);
            TabTipLabel.Text = Name;
            TabTip.Size = UDim2.fromOffset((Library:GetTextBounds(Name, Library.Font, Library.FontSize - 1) or 40) + 20, 24);
            TabTip.Position = UDim2.new(0, SIDEBAR_W + 2, Pos.Y.Scale, Pos.Y.Offset);
            TabTip.Visible = true;
            Library:Tween(TabTip, { Position = UDim2.new(0, SIDEBAR_W + 8, Pos.Y.Scale, Pos.Y.Offset) }, 0.14);
        end, function()
            if not Tab.Active then
                Library:Tween(TabButton, { BackgroundTransparency = 1 }, 0.12);
            end;
            TabTip.Visible = false;
        end);

        Window.Tabs[Name] = Tab;
        if not Window.ActiveTab then
            Tab:ShowTab();
        end;
        return Tab;
    end;

    -- Modal frees the mouse; while BlockGameInput is on it also covers the screen under the window (ZIndex 0)
    -- so clicks outside the menu stop here instead of reaching the game's UI or the world
    local ModalElement = Library:Create('TextButton', {
        Name = 'InputSink';
        AutoButtonColor = false;
        BackgroundTransparency = 1;
        Size = UDim2.new(0, 0, 0, 0);
        Visible = false;
        Text = '';
        Modal = false;
        ZIndex = 0;
        Parent = ScreenGui;
    });
    Library.InputSink = ModalElement;
    function Library:SyncInputSink()
        local Block = Library.BlockGameInput ~= false;
        ModalElement.Modal = Library.Toggled;
        ModalElement.Position = Block and UDim2.fromOffset(0, -64) or UDim2.fromOffset(0, 0);
        ModalElement.Size = Block and UDim2.new(1, 0, 1, 64) or UDim2.fromOffset(0, 0);
        ModalElement.Visible = Library.Toggled;
    end;
    -- Linoria cursor: accent arrow over a black outline; the game cursor is only hidden while it shows and HideGameCursor is on
    function Library:StartCursor()
        if Library.ShowCustomCursor == false then return end;
        Library.CursorToken = (Library.CursorToken or 0) + 1;
        local Token = Library.CursorToken;
        if Library.CursorGui then pcall(function() Library.CursorGui:Destroy() end) end;

        task.spawn(function()
            if Library.SavedMouseIcon == nil then Library.SavedMouseIcon = InputService.MouseIconEnabled end;

            local Gui = Instance.new('ScreenGui');
            pcall(ProtectGui, Gui);
            Gui.Name = 'AsterCursor';
            Gui.ResetOnSpawn = false;
            Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling;
            pcall(function() Gui.IgnoreGuiInset = true; Gui.DisplayOrder = 2147483647 end);
            Gui.Parent = GetGuiParent();
            Library.CursorGui = Gui;

            local Cursor = Library:Create('ImageLabel', {
                Name = 'Cursor';
                Image = 'http://www.roblox.com/asset/?id=4292970642';
                BackgroundTransparency = 1;
                Size = UDim2.fromOffset(17, 17);
                Rotation = -45;
                ZIndex = 100;
                Parent = Gui;
            });
            local CursorOutline = Library:Create('ImageLabel', {
                Name = 'CursorOutline';
                Image = 'http://www.roblox.com/asset/?id=4292970642';
                ImageColor3 = Color3.new();
                BackgroundTransparency = 1;
                Size = UDim2.fromOffset(19, 19);
                Rotation = -45;
                ZIndex = 99;
                Parent = Gui;
            });

            local Hidden = false;
            while Library.Toggled and not Library.Unloaded and Token == Library.CursorToken and ScreenGui.Parent do
                if Library.HideGameCursor ~= false then
                    InputService.MouseIconEnabled = false;
                    Hidden = true;
                elseif Hidden then
                    InputService.MouseIconEnabled = Library.SavedMouseIcon;
                    Hidden = false;
                end;
                -- the gui ignores the inset, so the mouse location maps straight onto it
                local Pos = InputService:GetMouseLocation();
                local At = UDim2.fromOffset(Pos.X, Pos.Y - 1);
                Cursor.ImageColor3 = Library.AccentColor;
                Cursor.Position, CursorOutline.Position = At, At - UDim2.fromOffset(1, 1);

                RenderStepped:Wait();
            end;

            pcall(function() Gui:Destroy() end);
            if Token == Library.CursorToken and not Library.Unloaded then
                InputService.MouseIconEnabled = Library.SavedMouseIcon;
                Library.SavedMouseIcon = nil;
                Library.CursorGui = nil;
            end;
        end);
    end;

    function Library:SetHideGameCursor(Bool)
        Library.HideGameCursor = Bool and true or false;
        if Library.CursorGui and Library.Toggled and Library.SavedMouseIcon ~= nil then
            InputService.MouseIconEnabled = (not Library.HideGameCursor) and Library.SavedMouseIcon;
        end;
    end;

    function Library:Toggle()
        Library.Toggled = not Library.Toggled;
        Library:SyncInputSink();
        for _, Tab in ipairs(Window.TabList) do
            Tab:SyncCanvases();
        end;
        Library.ToggleToken = (Library.ToggleToken or 0) + 1;
        local Token = Library.ToggleToken;
        local Fade = Library.MenuFadeTime or 0.2;

        if Library.Toggled then
            Outer.Visible = true;
            Veil.Visible = true;
            Veil.BackgroundTransparency = 0;
            WindowScale.Scale = Library.UIScale;
            Shadow.ImageTransparency = 0.45;
            Library:Tween(Veil, { BackgroundTransparency = 1 }, Fade);
            task.delay(Fade + 0.02, function()
                if Token == Library.ToggleToken then
                    Veil.Visible = false;
                end;
            end);
        else
            Veil.Visible = true;
            Library:Tween(Veil, { BackgroundTransparency = 0 }, Fade);
            for Frame, _ in next, Library.OpenedFrames do
                Frame.Visible = false;
                Library.OpenedFrames[Frame] = nil;
            end;
            Library:CloseAllPopups();
            Library:CloseSliderEditor();
            Library:UpdateHovers(true);
            task.delay(Fade, function()
                if Token == Library.ToggleToken then
                    Outer.Visible = false;
                    Veil.Visible = false;
                end;
            end);
        end;

        if Library.Toggled then
            if Library.ClampWindow then Library.ClampWindow() end;
            Library:StartCursor();
        end;
        Library:UpdateBlur();
    end

    Library:GiveSignal(InputService.InputBegan:Connect(function(Input, Processed)
        if Library.SliderEditor or Library:IsTypingInput(Input) then return; end;
        local Bound = Library.ToggleKeybind;
        if type(Bound) == 'table' and Bound.Type == 'KeyPicker' then
            if not Library.JustBound and next(Library.SideBinders) == nil and Library:KeyNameFromInput(Input) == Bound.Value then
                task.spawn(Library.Toggle)
            end
        elseif type(Bound) == 'string' then
            if not Library.JustBound and next(Library.SideBinders) == nil and Library:KeyNameFromInput(Input) == Bound then
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
            BackgroundColor3 = Library.BackgroundColor,
            BorderSizePixel  = 0,
            Position         = UDim2.new(0, 1, 0, 1),
            Size             = UDim2.new(1, -2, 1, -2),
            ZIndex           = 302,
            Parent           = AccentFrame,
        })
        Library:AddToRegistry(Inner, { BackgroundColor3 = 'BackgroundColor' })

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
            TextColor3          = Library.FontColor,
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
            or  Library.FontColor
    end)

    local _origUpdate = Library.UpdateColorsUsingRegistry
    Library.UpdateColorsUsingRegistry = function(self)
        _origUpdate(self)
    end
end

Env.Library = Library
return Library
