-- MouseUI loader: tries every fetch method the executor has and says exactly what failed.
-- Edit URL (must be a RAW link) and/or FILE, then run.
local URL  = "https://raw.githubusercontent.com/WhyWKey/linoria/refs/heads/main/ui-test/library.lua"
local FILE = "MouseUI.lua" -- fallback: file inside the executor's workspace folder

local function genvGet(name)
    local ok, v = pcall(function() return getgenv()[name] end)
    if ok and v ~= nil then return v end
    local ok2, v2 = pcall(function() return getfenv()[name] end)
    if ok2 then return v2 end
    return nil
end

local function fetch()
    local errors = {}
    local function note(msg) errors[#errors + 1] = msg end

    -- 1) game:HttpGet (classic)
    local ok, res = pcall(function() return game:HttpGet(URL) end)
    if ok and type(res) == "string" and #res > 0 then return res end
    note("game:HttpGet -> " .. (ok and "returned " .. typeof(res) or tostring(res)))

    -- 2) global httpget / HttpGet (documented form on some executors)
    local hg = genvGet("httpget") or genvGet("HttpGet")
    if hg then
        ok, res = pcall(hg, URL)
        if ok and type(res) == "string" and #res > 0 then return res end
        note("httpget -> " .. (ok and "returned " .. typeof(res) or tostring(res)))
    end

    -- 3) request / http_request
    local req = genvGet("request") or genvGet("http_request")
    if req then
        ok, res = pcall(req, { Url = URL, Method = "GET" })
        if ok and type(res) == "table" and type(res.Body) == "string" and #res.Body > 0 and (res.StatusCode == nil or res.StatusCode == 200) then
            return res.Body
        end
        note("request -> " .. (ok and ("status " .. tostring(type(res) == "table" and res.StatusCode)) or tostring(res)))
    end

    -- 4) local workspace file
    local rf = genvGet("readfile")
    if rf then
        ok, res = pcall(rf, FILE)
        if ok and type(res) == "string" and #res > 0 then return res end
        note("readfile(" .. FILE .. ") -> " .. (ok and "returned " .. typeof(res) or tostring(res)))
    end

    return nil, table.concat(errors, "\n  ")
end

local source, why = fetch()
assert(source, "[MouseUI loader] could not get the library source:\n  " .. tostring(why))

local chunk, err = loadstring(source, "=MouseUI")
assert(chunk, "[MouseUI loader] library failed to compile: " .. tostring(err))

local Library = chunk()

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
