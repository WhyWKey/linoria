-- MouseUI example. Swap the first line for loadstring(game:HttpGet("<your raw url>"))() once hosted.
local Library = loadstring(readfile("https://raw.githubusercontent.com/WhyWKey/linoria/refs/heads/main/ui-test/library.lua"))()
local Toggles, Options = Library.Toggles, Library.Options

local Window = Library:CreateWindow({ Title = "mouse | stage 1", ToggleKey = Enum.KeyCode.RightShift })

local Combat = Window:AddTab({ Name = "Combat" })
local Visuals = Window:AddTab({ Name = "Visuals" })

-- left column: section with a folding toggle, slider, dropdowns
local Aim = Combat:AddSection({ Name = "Aim Assist", Side = "Left" })
local Enabled = Aim:AddToggle("AimEnabled", { Text = "Enabled", Default = false, Folding = true })
Enabled:AddSlider("AimSmooth", { Text = "Smoothing", Min = 0, Max = 100, Default = 20, Suffix = "%" })
Enabled:AddToggle("AimLock", { Text = "Lock Target" })
Aim:AddSlider("AimFOV", { Text = "FOV", Min = 0, Max = 360, Default = 90, Rounding = 1, Step = 0.1, Suffix = "°" })
Aim:AddDropdown("AimPoints", { Text = "Hitscan Points", Values = { "Head", "Torso", "Body" }, Multi = true, Default = { "Head" } })
Aim:AddDropdown("AimSort", { Text = "Sorting", Values = { "FOV", "Distance", "Health" }, Default = "FOV" })
Aim:AddButton("Notify", function() Library:Notify("hello from MouseUI", 3) end)

-- right column: tabbed section
local SilentAim, TriggerBot = Combat:AddMultiSection({ Tabs = { "Silent Aim", "Trigger Bot" }, Side = "Right" })
SilentAim:AddToggle("SilentEnabled", { Text = "Enabled" })
SilentAim:AddSlider("SilentHitChance", { Text = "Hit Chance", Min = 0, Max = 100, Default = 30, Suffix = "%" })
TriggerBot:AddToggle("TriggerEnabled", { Text = "Enabled" })
TriggerBot:AddSlider("TriggerDelay", { Text = "Delay", Min = 0, Max = 500, Default = 50, Suffix = "ms" })

-- icon subtabs (BBot weapon-row look): replace the ids with your own image ids
local Weapons = Visuals:AddSection({ Name = "Preview", Side = "Left" })
Weapons:AddImage({ Source = 6031094678, Height = 48 })
local Pistol = Visuals:AddSubTab({ Name = "Pistol", Icon = 6031094678, IconOnly = true })
local Rifle = Visuals:AddSubTab({ Name = "Rifle", Icon = 6031094670, IconOnly = true })
Pistol:AddSection({ Name = "Pistol", Side = "Left" }):AddToggle("PistolESP", { Text = "ESP" })
Rifle:AddSection({ Name = "Rifle", Side = "Left" }):AddToggle("RifleESP", { Text = "ESP" })

-- theme presets: Purple, Teal, Orange
local Settings = Window:AddTab({ Name = "Settings" })
local Theme = Settings:AddSection({ Name = "Theme", Side = "Left" })
Theme:AddDropdown("ThemePreset", {
    Text = "Preset", Values = { "Purple", "Teal", "Orange" }, Default = "Purple",
    Callback = function(v) Library:SetPreset(v) end,
})
Theme:AddButton("Unload", function() Library:Unload() end)

Toggles.AimEnabled:OnChanged(function(v) print("aim enabled:", v) end)
Library:Notify("loaded on " .. Library.Executor, 4)
