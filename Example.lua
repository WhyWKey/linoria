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
-- Default theme goes on the library before any UI or the intro paints
ThemeManager:SetLibrary(Library)
ThemeManager:SetFolder('AsterShowcase')
ThemeManager:SetDefaultTheme(Env.AsterDefaultTheme or 'Aster Violet')
ThemeManager:PreApply()

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
    World = Window:AddTab('World', 'globe'),
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

do
    local Enemy = Tabs.Visuals:AddSubTab('Enemy', 'swords')
    local Friendly = Tabs.Visuals:AddSubTab('Friendly', 'shield')
    local Local = Tabs.Visuals:AddSubTab('LocalPlayer', 'user')

    BuildEsp(Enemy, 'Enemy', 'Enemy')
    BuildEsp(Friendly, 'Friendly', 'Friendly')
    BuildEsp(Local, 'Self', 'LocalPlayer')

    local World = Enemy:AddRightTabbox()
    local Misc = World:AddTab('Misc')
    Misc:AddToggle('NoFlash', { Text = 'No flash', Default = false })
    Misc:AddToggle('NoSmoke', { Text = 'No smoke', Default = false })
    Misc:AddSlider('CameraFov', { Text = 'Camera FOV', Default = 70, Min = 30, Max = 120, Rounding = 0, Stepper = true })
    local Crosshair = World:AddTab('Crosshair')
    ColorToggle(Crosshair, 'CustomCrosshair', 'Custom crosshair', { Library.AccentColor })
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
    Toggles.BulletTracers:AddColorPicker('BulletTracerColor', { Default = Library.AccentColor2, Title = 'Tracer color' })
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
-- World: Lighting / Camera / Workspace overrides (restored when a feature is switched off)
----------------------------------------------------------------------
local WorldState = { Orig = {}, Sky = nil, Atmos = nil, OwnAtmos = false, Cross = nil, Last = 0 }

local function Svc(Name)
    local Ok, Result = pcall(function() return game:GetService(Name) end)
    return Ok and Result or nil
end
local Lighting, Workspace, RunService = Svc('Lighting'), Svc('Workspace'), Svc('RunService')

local function Cam()
    local Ok, Result = pcall(function() return Workspace.CurrentCamera end)
    return Ok and Result or nil
end

local function WGet(Obj, Prop)
    local Ok, Value = pcall(function() return Obj[Prop] end)
    if Ok then return Value end
end

local function WSet(Obj, Prop, Value)
    pcall(function() Obj[Prop] = Value end)
end

-- Desired values are collected per frame; anything no longer wanted goes back to its saved original.
local function WorldApply(Force)
    if Library.Unloaded and not Force then return end
    local Want = {}
    local function Put(Obj, Prop, Value)
        if not Obj then return end
        Want[Obj] = Want[Obj] or {}
        Want[Obj][Prop] = Value
    end
    local function On(Idx) return Toggles[Idx] and Toggles[Idx].Value end
    local function Val(Idx) return Options[Idx] and Options[Idx].Value end

    if Lighting then
        local Atmos = WorldState.Atmos
        if not (Atmos and Atmos.Parent) then
            Atmos = Lighting:FindFirstChildOfClass('Atmosphere')
            WorldState.Atmos = Atmos
        end
        if On('WorldAtmosphere') and not Atmos then
            local Ok, New = pcall(Instance.new, 'Atmosphere')
            if Ok and New then
                pcall(function() New.Parent = Lighting end)
                WorldState.Atmos, WorldState.OwnAtmos, Atmos = New, true, New
            end
        end

        if On('WorldTime') then Put(Lighting, 'ClockTime', Val('WorldTimeValue')) end
        if On('WorldAmbient') then
            Put(Lighting, 'Ambient', Options.WorldAmbientColor.Value)
            Put(Lighting, 'OutdoorAmbient', Options.WorldOutdoorColor.Value)
        end
        if On('WorldFog') then
            Put(Lighting, 'FogStart', Val('WorldFogStart'))
            Put(Lighting, 'FogEnd', math.max(Val('WorldFogEnd'), Val('WorldFogStart') + 1))
            Put(Lighting, 'FogColor', Options.WorldFogColor.Value)
        end
        if On('WorldBrightness') then Put(Lighting, 'Brightness', Val('WorldBrightnessValue')) end
        if On('WorldExposure') then Put(Lighting, 'ExposureCompensation', Val('WorldExposureValue')) end
        if On('WorldAtmosphere') and Atmos then Put(Atmos, 'Density', Val('WorldAtmosphereDensity')) end
        if On('WorldSkybox') then
            local Preset = Val('WorldSkyboxPreset')
            local Sky = WorldState.Sky
            if Preset == 'Night' then
                Put(Lighting, 'ClockTime', 0)
                if Sky then Put(Sky, 'StarCount', 5000) end
                if Atmos then Put(Atmos, 'Color', Color3.fromRGB(60, 70, 110)); Put(Atmos, 'Decay', Color3.fromRGB(10, 12, 30)) end
            elseif Preset == 'Sunset' then
                Put(Lighting, 'ClockTime', 18.2)
                if Atmos then Put(Atmos, 'Color', Color3.fromRGB(255, 160, 100)); Put(Atmos, 'Decay', Color3.fromRGB(120, 60, 90)) end
            elseif Preset == 'Overcast' then
                Put(Lighting, 'ClockTime', 12)
                if Atmos then Put(Atmos, 'Color', Color3.fromRGB(170, 175, 185)); Put(Atmos, 'Density', 0.55) end
            elseif Preset == 'Dusk' then
                Put(Lighting, 'ClockTime', 19.5)
                if Atmos then Put(Atmos, 'Color', Color3.fromRGB(140, 110, 200)); Put(Atmos, 'Decay', Color3.fromRGB(40, 30, 80)) end
            end
        end
        if On('WorldNoShadows') then Put(Lighting, 'GlobalShadows', false) end
        if On('WorldNoFog') then Put(Lighting, 'FogEnd', 1e9); Put(Lighting, 'FogStart', 1e9 - 1) end
        if On('WorldFullBright') then
            Put(Lighting, 'Brightness', 2)
            Put(Lighting, 'ClockTime', 14)
            Put(Lighting, 'Ambient', Color3.new(1, 1, 1))
            Put(Lighting, 'OutdoorAmbient', Color3.new(1, 1, 1))
            Put(Lighting, 'GlobalShadows', false)
            Put(Lighting, 'FogEnd', 1e9)
            Put(Lighting, 'FogStart', 1e9 - 1)
        end
    end
    if Workspace and On('WorldGravity') then Put(Workspace, 'Gravity', Val('WorldGravityValue')) end
    local Camera = Cam()
    if Camera and On('WorldFov') then Put(Camera, 'FieldOfView', Val('WorldFovValue')) end

    for Obj, Props in next, Want do
        WorldState.Orig[Obj] = WorldState.Orig[Obj] or {}
        for Prop, Value in next, Props do
            if WorldState.Orig[Obj][Prop] == nil then WorldState.Orig[Obj][Prop] = WGet(Obj, Prop) end
            if WGet(Obj, Prop) ~= Value then WSet(Obj, Prop, Value) end
        end
    end
    for Obj, Saved in next, WorldState.Orig do
        for Prop, Old in next, Saved do
            if not (Want[Obj] and Want[Obj][Prop] ~= nil) then
                if Old ~= nil then WSet(Obj, Prop, Old) end
                Saved[Prop] = nil
            end
        end
        if next(Saved) == nil then WorldState.Orig[Obj] = nil end
    end

    -- Sky removal keeps the instance so it can be put back
    if Lighting then
        local Sky = WorldState.Sky
        if On('WorldNoSky') then
            local Found = Lighting:FindFirstChildOfClass('Sky')
            if Found then WorldState.Sky = Found; pcall(function() Found.Parent = nil end) end
        elseif Sky and not Sky.Parent then
            pcall(function() Sky.Parent = Lighting end)
        elseif not Sky then
            WorldState.Sky = Lighting:FindFirstChildOfClass('Sky')
        end
        if not On('WorldAtmosphere') and WorldState.OwnAtmos and WorldState.Atmos then
            pcall(function() WorldState.Atmos:Destroy() end)
            WorldState.Atmos, WorldState.OwnAtmos = nil, false
        end
    end
end

-- Custom crosshair: four bars + optional dot in the Library's own gui container
local function CrosshairUpdate()
    local Enabled = Toggles.WorldCrosshair and Toggles.WorldCrosshair.Value
    if not Enabled or Library.Unloaded then
        if WorldState.Cross then pcall(function() WorldState.Cross:Destroy() end); WorldState.Cross = nil end
        return
    end
    local Root = WorldState.Cross
    if not (Root and Root.Parent) then
        local Ok, Gui = pcall(function()
            local New = Instance.new('ScreenGui')
            New.Name = 'AsterCrosshair'
            New.IgnoreGuiInset = true
            New.DisplayOrder = 5
            New.ResetOnSpawn = false
            New.Parent = Library.ScreenGui and Library.ScreenGui.Parent or Svc('CoreGui')
            local Holder = Instance.new('Frame')
            Holder.Name = 'Holder'
            Holder.BackgroundTransparency = 1
            Holder.AnchorPoint = Vector2.new(0.5, 0.5)
            Holder.Position = UDim2.fromScale(0.5, 0.5)
            Holder.Size = UDim2.fromOffset(0, 0)
            Holder.Parent = New
            for _, Name in ipairs({ 'Up', 'Down', 'Left', 'Right', 'Dot' }) do
                local Bar = Instance.new('Frame')
                Bar.Name = Name
                Bar.BorderSizePixel = 0
                Bar.AnchorPoint = Vector2.new(0.5, 0.5)
                Bar.Parent = Holder
            end
            return New
        end)
        if not Ok or not Gui then return end
        Root = Gui
        WorldState.Cross = Gui
    end
    pcall(function()
        local Holder = Root.Holder
        local Size, Gap, Thick = Options.WorldCrossSize.Value, Options.WorldCrossGap.Value, Options.WorldCrossThickness.Value
        local Color = Options.WorldCrossColor.Value
        local Half = Gap + Size / 2
        local Layout = {
            Up = { UDim2.fromOffset(0, -Half), UDim2.fromOffset(Thick, Size) },
            Down = { UDim2.fromOffset(0, Half), UDim2.fromOffset(Thick, Size) },
            Left = { UDim2.fromOffset(-Half, 0), UDim2.fromOffset(Size, Thick) },
            Right = { UDim2.fromOffset(Half, 0), UDim2.fromOffset(Size, Thick) },
            Dot = { UDim2.fromOffset(0, 0), UDim2.fromOffset(Thick + 1, Thick + 1) },
        }
        for Name, Data in next, Layout do
            local Bar = Holder[Name]
            Bar.Position, Bar.Size, Bar.BackgroundColor3 = Data[1], Data[2], Color
            Bar.Visible = Name ~= 'Dot' or Toggles.WorldCrossDot.Value
        end
    end)
end

do
    local Time = Tabs.World:AddLeftGroupbox('Lighting', 'sun')
    Time:AddToggle('WorldTime', { Text = 'Time of day', Default = false })
    Time:AddSlider('WorldTimeValue', { Text = 'Clock time', Default = 14, Min = 0, Max = 24, Rounding = 1, Suffix = 'h' })
    Time:AddToggle('WorldBrightness', { Text = 'Brightness', Default = false })
    Time:AddSlider('WorldBrightnessValue', { Text = 'Value', Default = 2, Min = 0, Max = 10, Rounding = 1 })
    Time:AddToggle('WorldExposure', { Text = 'Exposure', Default = false })
    Time:AddSlider('WorldExposureValue', { Text = 'Compensation', Default = 0, Min = -3, Max = 3, Rounding = 1 })
    Time:AddToggle('WorldAmbient', { Text = 'Ambient colors', Default = false })
    Time:AddLabel('Ambient'):AddColorPicker('WorldAmbientColor', { Default = Color3.fromRGB(120, 120, 140), Title = 'Ambient' })
    Time:AddLabel('Outdoor ambient'):AddColorPicker('WorldOutdoorColor', { Default = Color3.fromRGB(140, 140, 160), Title = 'Outdoor ambient' })

    local Atmo = Tabs.World:AddLeftGroupbox('Fog and atmosphere', 'cloud')
    Atmo:AddToggle('WorldFog', { Text = 'Custom fog', Default = false })
    Atmo:AddSlider('WorldFogStart', { Text = 'Fog start', Default = 0, Min = 0, Max = 2000, Rounding = 0, Suffix = 'st' })
    Atmo:AddSlider('WorldFogEnd', { Text = 'Fog end', Default = 800, Min = 10, Max = 5000, Rounding = 0, Suffix = 'st' })
    Atmo:AddLabel('Fog color'):AddColorPicker('WorldFogColor', { Default = Color3.fromRGB(150, 160, 180), Title = 'Fog color' })
    Atmo:AddToggle('WorldAtmosphere', { Text = 'Atmosphere density', Default = false })
    Atmo:AddSlider('WorldAtmosphereDensity', { Text = 'Density', Default = 0.3, Min = 0, Max = 1, Rounding = 2 })
    Atmo:AddToggle('WorldSkybox', { Text = 'Sky preset', Default = false })
    Atmo:AddDropdown('WorldSkyboxPreset', { Text = 'Preset', Values = { 'Night', 'Sunset', 'Overcast', 'Dusk' }, Default = 1 })

    local Quick = Tabs.World:AddRightGroupbox('Quick toggles', 'zap')
    Quick:AddToggle('WorldFullBright', { Text = 'Full bright', Default = false, Tooltip = 'Overrides lighting values while on' })
    Quick:AddToggle('WorldNoFog', { Text = 'No fog', Default = false })
    Quick:AddToggle('WorldNoSky', { Text = 'Remove sky', Default = false })
    Quick:AddToggle('WorldNoShadows', { Text = 'Remove shadows', Default = false })

    local Cm = Tabs.World:AddRightGroupbox('Camera and physics', 'camera')
    Cm:AddToggle('WorldFov', { Text = 'Field of view', Default = false })
    Cm:AddSlider('WorldFovValue', { Text = 'FOV', Default = 90, Min = 30, Max = 120, Rounding = 0, Stepper = true })
    Cm:AddToggle('WorldGravity', { Text = 'Gravity', Default = false })
    Cm:AddSlider('WorldGravityValue', { Text = 'Gravity', Default = 196, Min = 0, Max = 400, Rounding = 0 })

    local Cross = Tabs.World:AddRightGroupbox('Crosshair', 'crosshair')
    Cross:AddToggle('WorldCrosshair', { Text = 'Custom crosshair', Default = false })
    Cross:AddLabel('Color'):AddColorPicker('WorldCrossColor', { Default = Library.AccentColor, Title = 'Crosshair color' })
    Cross:AddSlider('WorldCrossSize', { Text = 'Length', Default = 8, Min = 2, Max = 30, Rounding = 0, Suffix = 'px' })
    Cross:AddSlider('WorldCrossGap', { Text = 'Gap', Default = 4, Min = 0, Max = 20, Rounding = 0, Suffix = 'px' })
    Cross:AddSlider('WorldCrossThickness', { Text = 'Thickness', Default = 2, Min = 1, Max = 6, Rounding = 0, Suffix = 'px' })
    Cross:AddToggle('WorldCrossDot', { Text = 'Center dot', Default = false })

    for Idx in next, Toggles do
        if Idx:sub(1, 5) == 'World' then
            Toggles[Idx]:OnChanged(function() WorldApply(); CrosshairUpdate() end)
        end
    end
    for Idx in next, Options do
        if Idx:sub(1, 5) == 'World' then
            Options[Idx]:OnChanged(function() WorldApply(); CrosshairUpdate() end)
        end
    end
end

-- Re-assert every 0.25s in case the game resets a value; restores on unload
local WorldConn = RunService and RunService.Heartbeat:Connect(function()
    local Now = os.clock()
    if Now - WorldState.Last < 0.25 then return end
    WorldState.Last = Now
    pcall(WorldApply)
end)

Library:OnUnload(function()
    if WorldConn then WorldConn:Disconnect() end
    for Idx in next, Toggles do
        if Idx:sub(1, 5) == 'World' then Toggles[Idx].Value = false end
    end
    pcall(WorldApply, true)
    pcall(CrosshairUpdate)
end)

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
    Menu:AddDropdown('KeybindListFilter', {
        Text = 'Keybind list shows',
        Values = { 'All', 'Only enabled', 'Only bound', 'Enabled and bound' },
        Default = 1,
    })
    Options.KeybindListFilter:OnChanged(function()
        local V = Options.KeybindListFilter.Value
        Library:SetKeybindListFilter({
            OnlyEnabled = V == 'Only enabled' or V == 'Enabled and bound',
            OnlyBound = V == 'Only bound' or V == 'Enabled and bound',
        })
    end)
    Menu:AddToggle('MenuWidgetAccent', { Text = 'Widget accent bar', Default = true })
    Menu:AddDropdown('MenuWidgetAccentStyle', {
        Text = 'Widget accent style',
        Values = { 'Solid', 'Gradient' },
        Default = 2,
    })
    Toggles.MenuWidgetAccent:OnChanged(function() Library:SetWidgetAccent(Toggles.MenuWidgetAccent.Value) end)
    Options.MenuWidgetAccentStyle:OnChanged(function() Library:SetWidgetAccentStyle(Options.MenuWidgetAccentStyle.Value) end)
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
