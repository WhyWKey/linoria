--[[
    Aster UI - full showcase. UI-only demo: callbacks print / notify, no game dependencies.
    Run in an executor:  loadstring(game:HttpGet(repo .. 'Example.lua'))()
    Override the source with getgenv().AsterRepo = 'https://.../main/'
    Skip the intro with getgenv().AsterSkipIntro = true
]]

local Env = getgenv()
local repo = Env.AsterRepo or 'https://raw.githubusercontent.com/WhyWKey/linoria/main/'

-- Re-execution: tear down the previous instance
if Env.AsterExampleUnload then
    pcall(Env.AsterExampleUnload)
    Env.AsterExampleUnload = nil
end

local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()

local Options, Toggles = Env.Options, Env.Toggles

Library.ShowToggleFrameInKeybinds = true -- keybind list gets a clickable toggle (mobile friendly)
Library.ShowCustomCursor = true
Library.NotifySide = 'Left'

local function Log(...) print('[Example]', ...) end

----------------------------------------------------------------------
-- Window + intro (window starts hidden; the intro shows the menu)
----------------------------------------------------------------------
local Window = Library:CreateWindow({
    Title = 'Aster Showcase',
    Center = true,
    AutoShow = false,
    Size = UDim2.fromOffset(820, 560),
    TabPadding = 8,
    MenuFadeTime = 0.2,
})

if Env.AsterSkipIntro then
    Library:Toggle()
else
    Library:PlayIntro({
        Title = 'ASTER',
        Subtitle = 'Showcase',
        Duration = 3,
        Steps = { 'Loading modules', 'Building interface', 'Applying theme', 'Ready' },
        Blur = true,
        OnFinish = function()
            if not Library.Toggled and not Library.Unloaded then Library:Toggle() end
            Log('intro finished')
        end,
    })
end

-- Weapon-class icons: reuse sprites already in the sheet under new names
for Name, From in next, { pistol = 'target', smg = 'zap', rifle = 'crosshair', shotgun = 'layers', sniper = 'scan' } do
    local Data = Library.IconData[From]
    if Data then Library:RegisterIcon(Name, Data[1], Data[2], Data[3], Data[4]) end
end

-- 'settings' icon tabs are pinned to the bottom of the sidebar automatically
local Tabs = {
    Legit = Window:AddTab('Legit', 'crosshair'),
    Visuals = Window:AddTab('Visuals', 'eye'),
    Misc = Window:AddTab('Misc', 'shapes'),
    Players = Window:AddTab('Players', 'users'),
    Settings = Window:AddTab('Settings', 'settings'),
}

----------------------------------------------------------------------
-- Legit: weapon-class sub-tabs
----------------------------------------------------------------------
local WeaponClasses = { 'Pistol', 'SMG', 'Rifle', 'Shotgun', 'Sniper' }

local function BuildAim(Sub, Class)
    local P = Class .. '_'
    local Box = Sub:AddLeftGroupbox('Aim Assist', 'crosshair')

    Box:AddToggle(P .. 'AimEnabled', {
        Text = 'Enabled',
        Default = false,
        Tooltip = 'Aim assist for ' .. Class,
        Callback = function(Value) Log(Class, 'aim assist:', Value) end,
    })
    Toggles[P .. 'AimEnabled']:AddKeyPicker(P .. 'AimKey', { Default = 'MB2', Mode = 'Hold', Text = Class .. ' aim assist', SyncToggleState = false })
    Box:AddSlider(P .. 'AimFov', { Text = 'FOV', Default = 80, Min = 1, Max = 360, Rounding = 0, Suffix = '°', Stepper = true })
    Box:AddToggle(P .. 'DynamicFov', { Text = 'Dynamic FOV', Default = false, Tooltip = 'Scales FOV with zoom' })
    Box:AddToggle(P .. 'UseBarrel', { Text = 'Use Barrel', Default = false })
    Box:AddToggle(P .. 'LockTarget', { Text = 'Lock Target', Default = false })
    Box:AddDropdown(P .. 'HitscanPriority', { Text = 'Hitscan Priority', Values = { 'Head', 'Chest', 'Closest', 'Random' }, Default = 1 })
    Box:AddDropdown(P .. 'HitscanPoints', {
        Text = 'Hitscan Points',
        Values = { 'Head', 'Neck', 'Chest', 'Stomach', 'Arms', 'Legs' },
        Default = { 'Head', 'Chest' },
        Multi = true,
    })

    local Smoothing = Box:AddSection('Smoothing', { Collapsed = true })
    Smoothing:AddSlider(P .. 'SmoothStart', { Text = 'Start', Default = 20, Min = 0, Max = 100, Rounding = 0, Suffix = '%' })
    Smoothing:AddSlider(P .. 'SmoothEnd', { Text = 'End', Default = 60, Min = 0, Max = 100, Rounding = 0, Suffix = '%' })
    Smoothing:AddSlider(P .. 'SmoothIncrement', { Text = 'Increment', Default = 2, Min = 0.1, Max = 10, Rounding = 1, Stepper = true, Step = 0.1 })
    Smoothing:AddSlider(P .. 'SmoothRandom', { Text = 'Randomization', Default = 10, Min = 0, Max = 50, Rounding = 0, Suffix = '%' })

    Box:AddToggle(P .. 'BarrelCorrection', { Text = 'Barrel Correction', Default = false })
    local Barrel = Box:AddDependencyBox()
    Barrel:AddSlider(P .. 'BarrelPitch', { Text = 'Pitch', Default = 0, Min = -45, Max = 45, Rounding = 1 })
    Barrel:AddSlider(P .. 'BarrelYaw', { Text = 'Yaw', Default = 0, Min = -45, Max = 45, Rounding = 1 })
    Barrel:SetupDependencies({ { Toggles[P .. 'BarrelCorrection'], true } })

    local Right = Sub:AddRightTabbox()
    local Silent = Right:AddTab('Silent Aim')
    Silent:AddToggle(P .. 'SilentEnabled', { Text = 'Enabled', Default = false, Risky = true, Tooltip = 'Risky flag turns the text red' })
    Silent:AddSlider(P .. 'SilentFov', { Text = 'FOV', Default = 60, Min = 1, Max = 360, Rounding = 0, Stepper = true })
    Silent:AddSlider(P .. 'SilentChance', { Text = 'Hit chance', Default = 100, Min = 0, Max = 100, Rounding = 0, Suffix = '%' })
    Silent:AddDropdown(P .. 'SilentPart', { Text = 'Target part', Values = { 'Head', 'Torso', 'Random' }, Default = 1 })
    local Trigger = Right:AddTab('Trigger Bot')
    Trigger:AddToggle(P .. 'TriggerEnabled', { Text = 'Enabled', Default = false })
    Toggles[P .. 'TriggerEnabled']:AddKeyPicker(P .. 'TriggerKey', { Default = 'None', Mode = 'Toggle', Text = Class .. ' trigger bot' })
    Trigger:AddSlider(P .. 'TriggerDelay', { Text = 'Delay', Default = 40, Min = 0, Max = 500, Rounding = 0, Suffix = 'ms' })
    Trigger:AddToggle(P .. 'TriggerWallcheck', { Text = 'Wall check', Default = true })
end

for _, Class in ipairs(WeaponClasses) do
    local Icon = Library:GetIcon(Class:lower()) and Class:lower() or nil
    -- icon-only sub-tab; without a resolved icon the bar falls back to the text label
    BuildAim(Tabs.Legit:AddSubTab(Class, Icon, { IconOnly = true, Callback = function(Name) Log('weapon class:', Name) end }), Class)
end

----------------------------------------------------------------------
-- Visuals: Enemy | Friendly | LocalPlayer
----------------------------------------------------------------------
local Previews = {}

local function ColorToggle(Parent, Idx, Text, Colors, Tooltip)
    Parent:AddToggle(Idx, { Text = Text, Default = false, Tooltip = Tooltip })
    local Toggle = Toggles[Idx]
    for I, Color in ipairs(Colors) do
        local Suffix = I > 1 and tostring(I) or ''
        Toggle:AddColorPicker(Idx .. 'Color' .. Suffix, { Default = Color, Title = Text .. ' color' .. (I > 1 and ' ' .. I or '') })
    end
    return Toggle
end

local function BuildEsp(Sub, P, Label)
    local Box = Sub:AddLeftGroupbox(Label .. ' ESP', 'eye')
    local TwoD = Box:AddSection('2D')
    local White = Color3.fromRGB(255, 255, 255)

    ColorToggle(TwoD, P .. 'Name', 'Name', { White })
    ColorToggle(TwoD, P .. 'Box', 'Box', { Color3.fromRGB(255, 70, 90), Color3.fromRGB(255, 70, 90) }, 'Outline + fill colour')
    ColorToggle(TwoD, P .. 'Health', 'Health Bar', { Color3.fromRGB(80, 255, 120), Color3.fromRGB(255, 60, 60) }, 'High and low health colours')
    ColorToggle(TwoD, P .. 'HealthNumber', 'Health Number', { White })
    ColorToggle(TwoD, P .. 'Weapon', 'Held Weapon', { Color3.fromRGB(205, 205, 215) })
    ColorToggle(TwoD, P .. 'Flags', 'Flags', { Color3.fromRGB(255, 200, 80) })
    local FlagsDep = TwoD:AddDependencyBox()
    FlagsDep:AddDropdown(P .. 'FlagList', { Text = 'Flags', Values = { 'Armed', 'Reloading', 'Aiming', 'Crouching', 'Spotted' }, Default = { 'Armed' }, Multi = true })
    FlagsDep:SetupDependencies({ { Toggles[P .. 'Flags'], true } })
    ColorToggle(TwoD, P .. 'Distance', 'Render Distance', { Color3.fromRGB(150, 150, 165) })
    local DistDep = TwoD:AddDependencyBox()
    DistDep:AddSlider(P .. 'MaxDistance', { Text = 'Max distance', Default = 800, Min = 50, Max = 3000, Rounding = 0, Suffix = 'st', Stepper = true, Step = 50 })
    DistDep:SetupDependencies({ { Toggles[P .. 'Distance'], true } })

    -- rows with an AddSettings popup
    local Chams = ColorToggle(Box, P .. 'Chams', 'Chams', { Color3.fromRGB(170, 90, 255), Color3.fromRGB(255, 255, 255) }, 'Fill + outline colour')
    local ChamsPopup = Chams:AddSettings('Chams settings', { Width = 230 })
    ChamsPopup:AddSlider(P .. 'ChamsTransparency', { Text = 'Transparency', Default = 0.35, Min = 0, Max = 1, Rounding = 2 })
    ChamsPopup:AddToggle(P .. 'ChamsOutline', { Text = 'Outline', Default = true })
    ChamsPopup:AddToggle(P .. 'ChamsVisibleOnly', { Text = 'Visible only', Default = false })
    ChamsPopup:AddDropdown(P .. 'ChamsMaterial', { Text = 'Material', Values = { 'Flat', 'Glass', 'Neon' }, Default = 1 })

    local Oov = ColorToggle(Box, P .. 'OutOfView', 'Out of View', { Color3.fromRGB(255, 120, 120) })
    local OovPopup = Oov:AddSettings('Out of view settings')
    OovPopup:AddSlider(P .. 'OovSize', { Text = 'Arrow size', Default = 16, Min = 6, Max = 40, Rounding = 0, Suffix = 'px' })
    OovPopup:AddSlider(P .. 'OovRadius', { Text = 'Radius', Default = 220, Min = 50, Max = 500, Rounding = 0 })
    OovPopup:AddToggle(P .. 'OovPulse', { Text = 'Pulse', Default = true })

    local Sound = ColorToggle(Box, P .. 'SoundTracker', 'Sound Tracker', { Color3.fromRGB(120, 200, 255) })
    local SoundPopup = Sound:AddSettings('Sound tracker settings')
    SoundPopup:AddSlider(P .. 'SoundDuration', { Text = 'Duration', Default = 2, Min = 0.5, Max = 6, Rounding = 1, Suffix = 's' })
    SoundPopup:AddDropdown(P .. 'SoundTypes', { Text = 'Sounds', Values = { 'Footsteps', 'Gunshots', 'Reloads' }, Default = { 'Footsteps', 'Gunshots' }, Multi = true })

    local Right = Sub:AddRightTabbox()
    local Settings = Right:AddTab('ESP Settings')
    Settings:AddDropdown(P .. 'BoxStyle', { Text = 'Box style', Values = { 'Full', 'Corner' }, Default = 1 })
    Settings:AddDropdown(P .. 'TextFont', { Text = 'Text font', Values = { 'UI', 'System', 'Plex', 'Monospace' }, Default = 1 })
    Settings:AddSlider(P .. 'TextSize', { Text = 'Text size', Default = 13, Min = 8, Max = 24, Rounding = 0, Stepper = true })
    Settings:AddToggle(P .. 'TeamCheck', { Text = 'Team check', Default = true })
    local Overrides = Right:AddTab('Color Overrides')
    Overrides:AddToggle(P .. 'OverrideColors', { Text = 'Override by visibility', Default = false })
    Overrides:AddLabel('Visible'):AddColorPicker(P .. 'VisibleColor', { Default = Color3.fromRGB(80, 255, 120), Title = 'Visible' })
    Overrides:AddLabel('Occluded'):AddColorPicker(P .. 'OccludedColor', { Default = Color3.fromRGB(255, 80, 80), Title = 'Occluded' })
    Overrides:AddLabel('Target'):AddColorPicker(P .. 'TargetColor', { Default = Color3.fromRGB(255, 220, 60), Title = 'Target', Transparency = 0 })

    return Box
end

local function LinkPreview(Preview, P)
    Preview:Bind({
        Name = Toggles[P .. 'Name'], NameColor = Options[P .. 'NameColor'],
        Box = Toggles[P .. 'Box'], BoxColor = Options[P .. 'BoxColor'],
        Health = Toggles[P .. 'Health'], HealthColor = Options[P .. 'HealthColor'], HealthLowColor = Options[P .. 'HealthColor2'],
        HealthNumber = Toggles[P .. 'HealthNumber'],
        Weapon = Toggles[P .. 'Weapon'], WeaponColor = Options[P .. 'WeaponColor'],
        Flags = Toggles[P .. 'Flags'], FlagsColor = Options[P .. 'FlagsColor'],
        Distance = Toggles[P .. 'Distance'], DistanceColor = Options[P .. 'DistanceColor'],
        Chams = Toggles[P .. 'Chams'], ChamsColor = Options[P .. 'ChamsColor'], ChamsOutlineColor = Options[P .. 'ChamsColor2'],
        ChamsTransparency = Options[P .. 'ChamsTransparency'], ChamsOutline = Toggles[P .. 'ChamsOutline'],
        BoxStyle = Options[P .. 'BoxStyle'],
    })
    -- Transform form: dropdown value -> preview text
    Preview:Link('FlagsText', Options[P .. 'FlagList'], function(Value)
        local Out = {}
        for Name, On in next, Value do
            if On then Out[#Out + 1] = Name:upper() end
        end
        table.sort(Out)
        return Out
    end)
end

do
    local Enemy = Tabs.Visuals:AddSubTab('Enemy', 'swords')
    local Friendly = Tabs.Visuals:AddSubTab('Friendly', 'shield')
    local Local = Tabs.Visuals:AddSubTab('LocalPlayer', 'user')

    BuildEsp(Enemy, 'Enemy', 'Enemy')
    BuildEsp(Friendly, 'Friendly', 'Friendly')
    BuildEsp(Local, 'Self', 'LocalPlayer')

    local PreviewBox = Enemy:AddRightGroupbox('ESP Preview', 'scan')
    Previews.Enemy = PreviewBox:AddPreview({ Height = 260, Title = 'Enemy preview' })
    LinkPreview(Previews.Enemy, 'Enemy')
    PreviewBox:AddSlider('PreviewHealth', { Text = 'Preview health', Default = 78, Min = 0, Max = 100, Rounding = 0, Suffix = '%' })
    Options.PreviewHealth:OnChanged(function() Previews.Enemy:SetHealth(Options.PreviewHealth.Value) end)

    local World = Enemy:AddRightTabbox()
    local Misc = World:AddTab('Misc')
    Misc:AddToggle('NoFlash', { Text = 'No flash', Default = false })
    Misc:AddToggle('NoSmoke', { Text = 'No smoke', Default = false })
    Misc:AddSlider('CameraFov', { Text = 'Camera FOV', Default = 70, Min = 30, Max = 120, Rounding = 0, Stepper = true })
    local Crosshair = World:AddTab('Crosshair')
    ColorToggle(Crosshair, 'CustomCrosshair', 'Custom crosshair', { Color3.fromRGB(255, 255, 255) })
    Crosshair:AddSlider('CrosshairSize', { Text = 'Size', Default = 8, Min = 2, Max = 30, Rounding = 0, Suffix = 'px' })
    Crosshair:AddSlider('CrosshairGap', { Text = 'Gap', Default = 3, Min = 0, Max = 20, Rounding = 0, Suffix = 'px' })
    local Viewmodel = World:AddTab('Viewmodel')
    Viewmodel:AddToggle('ViewmodelOffset', { Text = 'Offset', Default = false })
    Viewmodel:AddSlider('ViewmodelX', { Text = 'X', Default = 0, Min = -3, Max = 3, Rounding = 1 })
    Viewmodel:AddSlider('ViewmodelY', { Text = 'Y', Default = 0, Min = -3, Max = 3, Rounding = 1 })
    Viewmodel:AddSlider('ViewmodelZ', { Text = 'Z', Default = 0, Min = -3, Max = 3, Rounding = 1 })

    local Items = Enemy:AddRightTabbox()
    local Drops = Items:AddTab('Drops')
    ColorToggle(Drops, 'DropEsp', 'Dropped weapons', { Color3.fromRGB(255, 190, 60) })
    Drops:AddSlider('DropDistance', { Text = 'Max distance', Default = 300, Min = 20, Max = 1500, Rounding = 0, Suffix = 'st' })
    local Grenades = Items:AddTab('Grenades')
    ColorToggle(Grenades, 'GrenadeEsp', 'Grenade ESP', { Color3.fromRGB(255, 90, 60) })
    Grenades:AddToggle('GrenadeTrajectory', { Text = 'Trajectory', Default = false })
    local WorldTab = Items:AddTab('World')
    WorldTab:AddToggle('FullBright', { Text = 'Full bright', Default = false })
    WorldTab:AddSlider('WorldTime', { Text = 'Time of day', Default = 14, Min = 0, Max = 24, Rounding = 1, Suffix = 'h' })
    WorldTab:AddLabel('Ambient'):AddColorPicker('AmbientColor', { Default = Color3.fromRGB(128, 128, 140), Title = 'Ambient', Transparency = 0 })

    local Body = Local:AddRightTabbox()
    local L3P = Body:AddTab('L3P')
    L3P:AddToggle('ThirdPerson', { Text = 'Third person', Default = false })
    Toggles.ThirdPerson:AddKeyPicker('ThirdPersonKey', { Default = 'None', Mode = 'Toggle', Text = 'Third person' })
    L3P:AddSlider('ThirdPersonDistance', { Text = 'Distance', Default = 8, Min = 2, Max = 25, Rounding = 1, Stepper = true, Step = 0.5 })
    local Character = Body:AddTab('Character')
    ColorToggle(Character, 'ForceField', 'Forcefield body', { Color3.fromRGB(120, 180, 255) })
    Character:AddToggle('HideArms', { Text = 'Hide arms', Default = false })
    Character:AddDropdown('BodyMaterial', { Text = 'Material', Values = { 'Plastic', 'ForceField', 'Neon', 'Glass' }, Default = 1 })
end

----------------------------------------------------------------------
-- Misc: general tabboxes, weaponry sections, element demo
----------------------------------------------------------------------
do
    local General = Tabs.Misc:AddSubTab('General', 'package')
    local Weaponry = Tabs.Misc:AddSubTab('Weaponry', 'sword')
    local Demo = Tabs.Misc:AddSubTab('Elements', 'sparkles')

    -- General: groupboxes with sub-tabs
    local Move = General:AddLeftTabbox()
    local MoveTab = Move:AddTab('Movement')
    MoveTab:AddToggle('Bhop', { Text = 'Bunny hop', Default = false })
    Toggles.Bhop:AddKeyPicker('BhopKey', { Default = 'None', Mode = 'Hold', Text = 'Bunny hop' })
    MoveTab:AddSlider('WalkSpeed', { Text = 'Walk speed', Default = 16, Min = 8, Max = 120, Rounding = 0, Stepper = true })
    MoveTab:AddToggle('InfJump', { Text = 'Infinite jump', Default = false })
    local ChatTab = Move:AddTab('Chat')
    ChatTab:AddToggle('ChatSpam', { Text = 'Chat spam', Default = false })
    ChatTab:AddInput('ChatSpamText', { Text = 'Message', Default = 'Aster on top', Placeholder = 'Message...' })
    ChatTab:AddSlider('ChatSpamDelay', { Text = 'Delay', Default = 3, Min = 1, Max = 15, Rounding = 0, Suffix = 's' })
    local TweaksTab = Move:AddTab('Tweaks')
    TweaksTab:AddToggle('AntiAfk', { Text = 'Anti AFK', Default = true })
    TweaksTab:AddToggle('UnlockFps', { Text = 'Unlock FPS', Default = false })

    local Vote = General:AddRightTabbox()
    local VoteTab = Vote:AddTab('Votekick')
    VoteTab:AddToggle('AutoVoteNo', { Text = 'Auto vote no', Default = false })
    VoteTab:AddDropdown('VotekickTarget', { Text = 'Target', SpecialType = 'Player' })
    VoteTab:AddButton({ Text = 'Start votekick', Func = function() Library:Notify('Votekick (demo): ' .. tostring(Options.VotekickTarget.Value), 3) end })
    local AutoTab = Vote:AddTab('Automation')
    AutoTab:AddToggle('AutoRespawn', { Text = 'Auto respawn', Default = false })
    AutoTab:AddToggle('AutoReload', { Text = 'Auto reload', Default = false })
    AutoTab:AddToggle('AutoBuy', { Text = 'Auto buy loadout', Default = false })

    local Extra = General:AddLeftTabbox()
    local ExtraTab = Extra:AddTab('Extra')
    ExtraTab:AddToggle('HitMarkers', { Text = 'Hit markers', Default = true })
    ExtraTab:AddToggle('KillFeedTweaks', { Text = 'Kill feed tweaks', Default = false })
    local SoundTab = Extra:AddTab('Sounds')
    SoundTab:AddToggle('HitSound', { Text = 'Hit sound', Default = false })
    SoundTab:AddDropdown('HitSoundId', { Text = 'Sound', Values = { 'Bell', 'Skeet', 'Pop', 'Bonk' }, Default = 1 })
    SoundTab:AddSlider('HitSoundVolume', { Text = 'Volume', Default = 50, Min = 0, Max = 100, Rounding = 0, Suffix = '%' })
    local ExploitTab = Extra:AddTab('Exploits')
    ExploitTab:AddToggle('FakeLag', { Text = 'Fake lag', Default = false, Risky = true })
    ExploitTab:AddSlider('FakeLagAmount', { Text = 'Amount', Default = 4, Min = 1, Max = 20, Rounding = 0 })

    -- Weaponry: collapsible sections
    local Gun = Weaponry:AddLeftGroupbox('Weaponry', 'sword')
    local Recoil = Gun:AddSection('Recoil')
    Recoil:AddToggle('NoRecoil', { Text = 'Recoil control', Default = false })
    Recoil:AddSlider('RecoilX', { Text = 'Horizontal', Default = 100, Min = 0, Max = 100, Rounding = 0, Suffix = '%' })
    Recoil:AddSlider('RecoilY', { Text = 'Vertical', Default = 100, Min = 0, Max = 100, Rounding = 0, Suffix = '%' })
    local Behaviors = Gun:AddSection('Behaviors', { Collapsed = true })
    Behaviors:AddToggle('InstantEquip', { Text = 'Instant equip', Default = false })
    Behaviors:AddToggle('AutoFire', { Text = 'Force automatic', Default = false })
    Behaviors:AddToggle('NoSway', { Text = 'No sway', Default = false })
    local WMove = Gun:AddSection('Movement', { Collapsed = true })
    WMove:AddToggle('FullSpeedAim', { Text = 'Full speed while aiming', Default = false })
    WMove:AddSlider('AimWalkSpeed', { Text = 'Aim walk speed', Default = 60, Min = 10, Max = 100, Rounding = 0, Suffix = '%' })
    local Model = Gun:AddSection('Model', { Collapsed = true })
    ColorToggle(Model, 'WeaponChams', 'Weapon chams', { Color3.fromRGB(170, 90, 255) })
    Model:AddDropdown('WeaponMaterial', { Text = 'Material', Values = { 'Plastic', 'Neon', 'ForceField' }, Default = 1 })
    local Bullets = Gun:AddSection('Bullets', { Collapsed = true })
    Bullets:AddToggle('BulletTracers', { Text = 'Bullet tracers', Default = false })
    Toggles.BulletTracers:AddColorPicker('BulletTracerColor', { Default = Color3.fromRGB(255, 255, 255), Title = 'Tracer color' })
    Bullets:AddSlider('TracerLife', { Text = 'Lifetime', Default = 1.5, Min = 0.2, Max = 5, Rounding = 1, Suffix = 's' })

    local Sections = Weaponry:AddRightGroupbox('Section control', 'layers')
    Sections:AddLabel('Sections fold and the groupbox resizes.', true)
    Sections:AddButton({ Text = 'Toggle Recoil', Func = function() Recoil:Toggle() end })
    Sections:AddButton({ Text = 'Collapse all', Func = function()
        for _, S in ipairs({ Recoil, Behaviors, WMove, Model, Bullets }) do S:SetCollapsed(true) end
    end }):AddButton({ Text = 'Expand all', Func = function()
        for _, S in ipairs({ Recoil, Behaviors, WMove, Model, Bullets }) do S:SetCollapsed(false) end
    end })

    ------------------------------------------------------------------
    -- Element demo
    ------------------------------------------------------------------
    local Basic = Demo:AddLeftGroupbox('Toggles, sliders, keypickers', 'sliders-horizontal')
    Basic:AddToggle('AimEnabled', {
        Text = 'Toggle + keybind',
        Default = false,
        Tooltip = 'Toggle with a tooltip',
        Callback = function(Value) Log('AimEnabled callback:', Value) end,
    })
    Toggles.AimEnabled:AddKeyPicker('AimKey', { Default = 'MB2', Mode = 'Hold', Text = 'Aim key', SyncToggleState = false })
    Toggles.AimEnabled:OnChanged(function() Log('AimEnabled OnChanged:', Toggles.AimEnabled.Value) end)
    Basic:AddToggle('ToggleColor', { Text = 'Toggle + colorpicker', Default = true })
    Toggles.ToggleColor:AddColorPicker('ToggleColorValue', { Default = Color3.fromRGB(255, 80, 120), Title = 'Toggle color' })
    Basic:AddToggle('ToggleBoth', { Text = 'Key + 3 colours + settings', Default = false, Risky = true })
    Toggles.ToggleBoth:AddKeyPicker('BothKey', { Default = 'None', Mode = 'Toggle', Text = 'Both key' })
    Toggles.ToggleBoth:AddColorPicker('BothColor', { Default = Color3.fromRGB(80, 200, 255), Title = 'Colour 1' })
    Toggles.ToggleBoth:AddColorPicker('BothColor2', { Default = Color3.fromRGB(255, 200, 80), Title = 'Colour 2' })
    Toggles.ToggleBoth:AddColorPicker('BothColor3', { Default = Color3.fromRGB(120, 255, 140), Title = 'Colour 3' })
    local BothPopup = Toggles.ToggleBoth:AddSettings('Popup demo', { Width = 220 })
    BothPopup:AddSlider('PopupSlider', { Text = 'Inside popup', Default = 5, Min = 0, Max = 10, Rounding = 0 })
    BothPopup:AddButton({ Text = 'Close popup', Func = function() BothPopup:Close() end })

    Basic:AddDivider()
    Basic:AddSlider('SliderInt', { Text = 'Integer + stepper', Default = 50, Min = 0, Max = 100, Rounding = 0, Stepper = true })
    Basic:AddSlider('SliderFloat', { Text = 'Float (2 dp)', Default = 0.25, Min = 0, Max = 1, Rounding = 2, Stepper = true, Step = 0.05 })
    Basic:AddSlider('SliderSuffix', { Text = 'With suffix', Default = 150, Min = 10, Max = 800, Rounding = 0, Suffix = 'px' })
    Basic:AddSlider('SliderCompact', { Text = 'Compact, hide max', Default = 30, Min = 0, Max = 60, Rounding = 0, Compact = true, HideMax = true })
    Options.SliderInt:OnChanged(function() Log('SliderInt:', Options.SliderInt.Value) end)

    Basic:AddDivider()
    Basic:AddLabel('Keybind modes (watch the keybind list):')
    Basic:AddLabel('Always'):AddKeyPicker('KeyAlways', { Default = 'None', Mode = 'Always', Text = 'Mode: Always' })
    Basic:AddLabel('Toggle'):AddKeyPicker('KeyToggle', { Default = 'T', Mode = 'Toggle', Text = 'Mode: Toggle' })
    Basic:AddLabel('Hold'):AddKeyPicker('KeyHold', { Default = 'H', Mode = 'Hold', Text = 'Mode: Hold' })
    Options.KeyToggle:OnClick(function() Log('KeyToggle state =', Options.KeyToggle:GetState()) end)
    Options.KeyHold:OnChanged(function() Log('KeyHold key changed to', Options.KeyHold.Value) end)

    local Pick = Demo:AddLeftGroupbox('Dropdowns, inputs, colours', 'list')
    Pick:AddDropdown('DropSingle', {
        Text = 'Single', Values = { 'Head', 'Torso', 'Arms', 'Legs' }, Default = 1, Tooltip = 'Single-select dropdown',
        Callback = function(Value) Log('DropSingle:', Value) end,
    })
    Pick:AddDropdown('DropMulti', { Text = 'Multi', Values = { 'Alpha', 'Beta', 'Gamma', 'Delta' }, Default = { 'Alpha', 'Gamma' }, Multi = true })
    Pick:AddDropdown('DropNull', { Text = 'AllowNull', Values = { 'One', 'Two', 'Three' }, Default = 1, Multi = true, AllowNull = true })
    Pick:AddDropdown('DropCompact', { Values = { 'No label (compact)', 'Second', 'Third' }, Default = 1 })
    Pick:AddDropdown('DropPlayers', { Text = 'Player list', SpecialType = 'Player' })
    Pick:AddDropdown('DropTeams', { Text = 'Team list', SpecialType = 'Team' })
    Options.DropMulti:OnChanged(function()
        local Picked = {}
        for Name, State in next, Options.DropMulti.Value do
            if State then Picked[#Picked + 1] = Name end
        end
        Log('DropMulti:', table.concat(Picked, ', '))
    end)
    Pick:AddButton({ Text = 'Replace DropSingle values', Func = function()
        Options.DropSingle:SetValues({ 'Red', 'Green', 'Blue' })
        Options.DropSingle:SetValue('Green')
    end })

    Pick:AddDivider()
    Pick:AddInput('InputText', { Text = 'Text input', Default = 'hello', Placeholder = 'Type here...', Tooltip = 'Updates on every keystroke', Callback = function(Value) Log('InputText:', Value) end })
    Pick:AddInput('InputFinished', { Text = 'Finished (enter to apply)', Default = '', Placeholder = 'Press enter', Finished = true })
    Pick:AddInput('InputNumeric', { Text = 'Numeric only', Default = '10', Numeric = true })
    Pick:AddInput('InputMax', { Text = 'MaxLength 8', Default = '', Placeholder = 'max 8 chars', MaxLength = 8 })

    Pick:AddDivider()
    Pick:AddLabel('Plain colour'):AddColorPicker('ColorPlain', { Default = Color3.fromRGB(0, 255, 140), Title = 'Plain color' })
    Pick:AddLabel('With transparency'):AddColorPicker('ColorAlpha', {
        Default = Color3.fromRGB(255, 255, 255), Title = 'Color + transparency', Transparency = 0.4,
        Callback = function(Value) Log('ColorAlpha callback:', Value) end,
    })
    Pick:AddLabel('Two on one label'):AddColorPicker('ColorA', { Default = Color3.fromRGB(255, 0, 0) })
        :AddColorPicker('ColorB', { Default = Color3.fromRGB(0, 0, 255) })
    Options.ColorAlpha:OnChanged(function() Log('ColorAlpha:', Options.ColorAlpha.Value, Options.ColorAlpha.Transparency) end)

    local Misc = Demo:AddRightGroupbox('Buttons, labels, dependencies', 'mouse')
    Misc:AddButton({ Text = 'Plain button', Func = function() Library:Notify('Plain button clicked', 3) end, Tooltip = 'Single click' })
    Misc:AddButton({ Text = 'Button', Func = function() Library:Notify('Button', 2) end })
        :AddButton({ Text = 'Sub-button', Func = function() Library:Notify('Sub-button', 2) end })
    Misc:AddButton({ Text = 'Double click me', DoubleClick = true, Func = function() Library:Notify('Double click confirmed', 3) end, Tooltip = 'Requires two clicks' })
    Misc:AddButton('Positional args', function() Log('positional button') end)
    Misc:AddDivider()
    Misc:AddLabel('A short label')
    Misc:AddLabel('This is a long label with wrapping enabled, it should flow over several lines inside the groupbox.', true)
    local Dynamic = Misc:AddLabel('Dynamic label (click the button)')
    local Clicks = 0
    Misc:AddButton({ Text = 'Change label text', Func = function()
        Clicks = Clicks + 1
        Dynamic:SetText('Clicked ' .. Clicks .. ' time(s)')
    end })
    Misc:AddBlank(8)
    Misc:AddDivider()
    Misc:AddToggle('DepMaster', { Text = 'Show dependent controls', Default = false })
    local DepBox = Misc:AddDependencyBox()
    DepBox:AddSlider('DepSlider', { Text = 'Dependent slider', Default = 3, Min = 0, Max = 10, Rounding = 0 })
    DepBox:AddToggle('DepToggle', { Text = 'Dependent toggle', Default = true })
    local Nested = DepBox:AddDependencyBox()
    Nested:AddLabel('Nested: needs both toggles on')
    Nested:SetupDependencies({ { Toggles.DepToggle, true } })
    DepBox:SetupDependencies({ { Toggles.DepMaster, true } })

    local Notif = Demo:AddRightGroupbox('Notifications and HUD', 'bell')
    Notif:AddButton({ Text = 'Notify (3s)', Func = function() Library:Notify('Short notification', 3) end })
    Notif:AddButton({ Text = 'Notify (8s)', Func = function() Library:Notify('Long notification, stays 8 seconds', 8) end })
    Notif:AddButton({ Text = 'Spam 4 (queue)', Func = function()
        for I = 1, 4 do Library:Notify('Queued notification #' .. I, 3) end
    end })
    Notif:AddDropdown('NotifySide', { Text = 'Notify side', Values = { 'Left', 'Right' }, Default = 1 })
    Options.NotifySide:OnChanged(function()
        Library.NotifySide = Options.NotifySide.Value
        Library:Notify('Side: ' .. Options.NotifySide.Value, 3)
    end)
    Notif:AddToggle('ShowWatermark', { Text = 'Watermark', Default = true })
    Notif:AddToggle('ShowKeybinds', { Text = 'Keybind list', Default = true })
    Toggles.ShowWatermark:OnChanged(function() Library:SetWatermarkVisibility(Toggles.ShowWatermark.Value) end)
    Toggles.ShowKeybinds:OnChanged(function() Library:SetKeybindListVisibility(Toggles.ShowKeybinds.Value) end)
end

local Frames, Clock, FPS = 0, os.clock(), 60
local WatermarkConn = game:GetService('RunService').RenderStepped:Connect(function()
    Frames = Frames + 1
    local Now = os.clock()
    if Now - Clock < 0.5 then return end
    FPS = math.floor(Frames / (Now - Clock))
    Frames, Clock = 0, Now
    if Toggles.ShowWatermark and Toggles.ShowWatermark.Value then
        Library:SetWatermark(('Aster Showcase | %d fps'):format(FPS))
    end
end)

Library:OnUnload(function()
    WatermarkConn:Disconnect()
    Env.AsterExampleUnload = nil
    Log('Unloaded')
end)
Env.AsterExampleUnload = function()
    pcall(function() Library:Unload() end)
end

----------------------------------------------------------------------
-- Players: player list with priorities
----------------------------------------------------------------------
do
    local ListBox = Tabs.Players:AddLeftGroupbox('Player list', 'users')
    local List = ListBox:AddPlayerList({
        Columns = { 'Name', 'UserId', 'Priority' },
        Priorities = { 'None', 'Friendly', 'Enemy', 'Priority' },
        Height = 300,
        InfoPanel = true,
        OnPriorityChanged = function(Player, Priority) Log('priority', Player and Player.Name, '->', Priority) end,
    })
    local Tools = Tabs.Players:AddRightGroupbox('Tools', 'wrench')
    Tools:AddInput('PlayerFilter', { Text = 'Filter', Placeholder = 'Name...', Callback = function(Value) List:SetFilter(Value) end })
    Tools:AddButton({ Text = 'Refresh list', Func = function() List:Refresh() end })
    Tools:AddButton({ Text = 'Mark selected Enemy', Func = function()
        local Selected = List:GetSelected()
        if Selected then List:SetPriority(Selected, 'Enemy') else Library:Notify('Select a player first', 2) end
    end })
    Tools:AddButton({ Text = 'Print priorities', Func = function()
        for Id, Priority in next, Library:GetPlayerPriorities() do Log(Id, Priority) end
    end })
    Tools:AddLabel('Priorities are saved with the config.', true)
end

----------------------------------------------------------------------
-- Settings: Menu | Theme | Config (icon-only sub-tabs)
----------------------------------------------------------------------
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
ThemeManager.HudToggles = false -- the Menu sub-tab owns the watermark / keybind list toggles

do
    local MenuSub = Tabs.Settings:AddSubTab('Menu', 'keyboard', { IconOnly = true })
    local ThemeSub = Tabs.Settings:AddSubTab('Theme', 'palette', { IconOnly = true })
    local ConfigSub = Tabs.Settings:AddSubTab('Config', 'save', { IconOnly = true })

    local Menu = MenuSub:AddLeftGroupbox('Menu', 'keyboard')
    Menu:AddLabel('Menu bind'):AddKeyPicker('MenuKeybind', { Default = 'RightShift', NoUI = true, Text = 'Menu keybind' })
    Library.ToggleKeybind = Options.MenuKeybind
    Menu:AddToggle('MenuWatermark', { Text = 'Watermark', Default = true })
    Menu:AddToggle('MenuKeybindList', { Text = 'Keybind list', Default = true })
    Toggles.MenuWatermark:OnChanged(function() Library:SetWatermarkVisibility(Toggles.MenuWatermark.Value) end)
    Toggles.MenuKeybindList:OnChanged(function() Library:SetKeybindListVisibility(Toggles.MenuKeybindList.Value) end)
    Menu:AddDropdown('MenuNotifyCorner', {
        Text = 'Notification corner',
        Values = { 'Top Left', 'Top Center', 'Top Right', 'Bottom Left', 'Bottom Center', 'Bottom Right' },
        Default = 1,
    })
    Options.MenuNotifyCorner:OnChanged(function() Library:SetNotifyCorner(Options.MenuNotifyCorner.Value) end)
    Menu:AddButton({ Text = 'Test notification', Func = function() Library:Notify('Aster Showcase notification', 4) end })
    Menu:AddButton({ Text = 'Replay intro', Func = function()
        Library:PlayIntro({ Title = 'ASTER', Subtitle = 'Showcase', Duration = 2.2, Steps = { 'Replaying' } })
    end })
    Menu:AddButton({ Text = 'Unload', Func = function() Library:Unload() end, DoubleClick = true, Tooltip = 'Double click to unload' })

    -- Theme: all colours (incl. derived), presets / custom themes, appearance
    ThemeManager:SetFolder('AsterShowcase')
    SaveManager:SetFolder('AsterShowcase')
    if ThemeManager.CreateColors then
        ThemeManager:CreateColors(ThemeSub:AddLeftGroupbox('Colors', 'palette'))
        ThemeManager:CreatePresets(ThemeSub:AddLeftGroupbox('Presets', 'folder'))
        ThemeManager:CreateAppearance(ThemeSub:AddRightGroupbox('Appearance', 'monitor'))

        local Backdrop = ThemeSub:AddRightGroupbox('Backdrop and HUD', 'layers')
        Library:AddBlurSlider(Backdrop)
        Library:AddDarkenSlider(Backdrop)
        Library:AddKeybindTransparencySlider(Backdrop)
        Backdrop:AddButton({ Text = 'Replay intro', Func = function()
            Library:PlayIntro({ Title = 'ASTER', Subtitle = 'Showcase', Duration = 2.2, Steps = { 'Replaying' } })
        end })

        local Esp = ThemeSub:AddRightGroupbox('ESP preview', 'eye')
        Esp:AddToggle('ThemePreviewRotate', { Text = 'Auto rotate', Default = false })
        Esp:AddInput('ThemePreviewUserId', { Text = 'Avatar user ID', Default = '6135348224', Numeric = true, Finished = true })
        Toggles.ThemePreviewRotate:OnChanged(function() Previews.Enemy:Set('AutoRotate', Toggles.ThemePreviewRotate.Value) end)
        Options.ThemePreviewUserId:OnChanged(function()
            local Id = tonumber(Options.ThemePreviewUserId.Value)
            if Id and Id > 0 then Previews.Enemy:Set('UserId', Id) end
        end)
        ThemeManager:Finalize()
    else
        Library:Notify('Outdated ThemeManager: upload addons/ThemeManager.lua from the latest release', 10)
        warn('[Aster] ThemeManager.CreateColors missing. Upload addons/ThemeManager.lua from the latest release.')
        if ThemeManager.ApplyToTab then
            ThemeManager:ApplyToTab(ThemeSub)
        end
    end

    SaveManager:IgnoreThemeSettings()
    SaveManager:SetIgnoreIndexes({ 'MenuKeybind', 'MenuNotifyCorner' })
    SaveManager:BuildConfigSection(ConfigSub)
    SaveManager:LoadAutoloadConfig()
end

Library:SetWatermarkVisibility(true)
Library:Notify('Aster Showcase loaded - press ' .. tostring(Options.MenuKeybind.Value) .. ' to toggle the menu', 6)
