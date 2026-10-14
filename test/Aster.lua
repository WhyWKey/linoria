-- Loader: a blurred backdrop with a centered progress bar and a status line above it. The status line
-- shows what the script is doing while it loads; when loading ends the bar fills, the blur and the
-- loader fade out, and the menu opens.
local Loader = (function()
    local self = { target = 0, shown = 0, closed = false }
    local Lighting = game:GetService("Lighting")
    local RunService = game:GetService("RunService")
    local gui, blur, dim, statusLabel, fill, percentLabel, titleLabel, track, connection
    local fade = 0

    local function destroy()
        self.closed = true
        if connection then pcall(function() connection:Disconnect() end) connection = nil end
        if gui then pcall(function() gui:Destroy() end) gui = nil end
        if blur then pcall(function() blur:Destroy() end) blur = nil end
    end
    self.destroy = destroy
    pcall(function()
        local old = getgenv().AsterLoader
        if old and old.destroy then old.destroy() end
        getgenv().AsterLoader = self
    end)

    -- The bar starts in the accent colour saved by the last run (theme changes are saved), and switches to the
    -- live one as soon as the theme is applied.
    local accent = Color3.fromRGB(102, 137, 148)
    pcall(function()
        if isfile and isfile("Aster/loader_accent.txt") then accent = Color3.fromHex(readfile("Aster/loader_accent.txt")) end
    end)

    local built = pcall(function()
        gui = Instance.new("ScreenGui")
        gui.Name = "Aster_Loader"
        gui.IgnoreGuiInset = true
        gui.ResetOnSpawn = false
        gui.DisplayOrder = 10000
        gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        local parent
        pcall(function() if gethui then parent = gethui() end end)
        if not parent then pcall(function() parent = game:GetService("CoreGui") end) end
        gui.Parent = parent or game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")

        blur = Instance.new("BlurEffect")
        blur.Name = "Aster_LoaderBlur"
        blur.Size = 0
        blur.Parent = Lighting

        dim = Instance.new("Frame")
        dim.Size = UDim2.fromScale(1, 1)
        dim.BackgroundColor3 = Color3.new(0, 0, 0)
        dim.BackgroundTransparency = 0.55
        dim.BorderSizePixel = 0
        dim.Parent = gui

        local card = Instance.new("Frame")
        card.AnchorPoint = Vector2.new(0.5, 0.5)
        card.Position = UDim2.fromScale(0.5, 0.5)
        card.Size = UDim2.fromOffset(380, 84)
        card.BackgroundTransparency = 1
        card.Parent = gui

        local function label(size, y, h, color, font)
            local l = Instance.new("TextLabel")
            l.BackgroundTransparency = 1
            l.Size = UDim2.new(1, 0, 0, h)
            l.Position = UDim2.fromOffset(0, y)
            l.Font = font
            l.TextSize = size
            l.TextColor3 = color
            l.Text = ""
            l.Parent = card
            return l
        end
        titleLabel = label(18, 0, 22, Color3.fromRGB(230, 230, 230), Enum.Font.GothamBold)
        titleLabel.Text = "ASTER"
        statusLabel = label(14, 26, 20, Color3.fromRGB(182, 182, 182), Enum.Font.Gotham)
        statusLabel.Text = "Starting"

        track = Instance.new("Frame")
        track.Position = UDim2.fromOffset(0, 54)
        track.Size = UDim2.new(1, 0, 0, 6)
        track.BackgroundColor3 = Color3.fromRGB(34, 34, 34)
        track.BorderSizePixel = 0
        track.Parent = card
        local trackCorner = Instance.new("UICorner")
        trackCorner.CornerRadius = UDim.new(1, 0)
        trackCorner.Parent = track

        fill = Instance.new("Frame")
        fill.Size = UDim2.fromScale(0, 1)
        fill.BackgroundColor3 = accent
        fill.BorderSizePixel = 0
        fill.Parent = track
        local fillCorner = Instance.new("UICorner")
        fillCorner.CornerRadius = UDim.new(1, 0)
        fillCorner.Parent = fill

        percentLabel = label(12, 64, 18, Color3.fromRGB(130, 130, 130), Enum.Font.Gotham)
        percentLabel.Text = "0%"

        connection = RunService.RenderStepped:Connect(function(dt)
            self.shown += (self.target - self.shown) * math.min(1, dt * 9)
            if fill then fill.Size = UDim2.fromScale(math.clamp(self.shown, 0, 1), 1) end
            if percentLabel then percentLabel.Text = math.floor(self.shown * 100 + 0.5) .. "%" end
            if blur and fade == 0 then blur.Size = math.min(18, blur.Size + dt * 60) end
        end)
    end)
    if not built then destroy() end

    local function setFade(alpha) -- 0 = fully shown, 1 = gone
        fade = alpha
        pcall(function()
            if blur then blur.Size = 18 * (1 - alpha) end
            if dim then dim.BackgroundTransparency = 0.55 + 0.45 * alpha end
            for _, l in ipairs({ titleLabel, statusLabel, percentLabel }) do l.TextTransparency = alpha end
            if track then track.BackgroundTransparency = alpha end
            if fill then fill.BackgroundTransparency = alpha end
        end)
    end

    -- Shows a status line and moves the bar to the given progress (0 to 1). Yields one frame so it draws.
    function self.step(text, progress)
        if self.closed then return end
        self.target = math.max(self.target, progress or self.target)
        pcall(function() if statusLabel then statusLabel.Text = tostring(text) end end)
        task.wait()
    end

    -- Checks the executor functions the script relies on and shows how many exist.
    function self.verify(progress)
        local names = { "hookfunction", "getconnections", "isnetworkowner", "mousemoverel", "Drawing", "gethui", "getgenv" }
        local found = 0
        for _, name in ipairs(names) do
            local ok, value = pcall(function() return getgenv()[name] end)
            if ok and value ~= nil then found += 1 end
        end
        local hasDebug = pcall(function() return debug.getupvalue end)
        if hasDebug then found += 1 end
        self.step(("Verifying environment (%d/%d)"):format(found, #names + 1), progress)
    end

    -- Fills the bar, opens the menu through onDone, then fades the loader and the blur out.
    function self.finish(onDone)
        if not self.closed then
            self.step("Ready", 1)
            local started = os.clock()
            while self.shown < 0.985 and os.clock() - started < 1.5 and not self.closed do task.wait() end
            task.wait(0.2)
        end
        pcall(onDone)
        if self.closed then return end
        local started = os.clock()
        while os.clock() - started < 0.35 and not self.closed do
            setFade(math.clamp((os.clock() - started) / 0.35, 0, 1))
            task.wait()
        end
        destroy()
    end

    function self.setAccent(color)
        accent = color
        pcall(function() if fill and not self.failed then fill.BackgroundColor3 = color end end)
    end

    function self.saveAccent(color)
        pcall(function()
            if not writefile then return end
            if makefolder and isfolder and not isfolder("Aster") then makefolder("Aster") end
            writefile("Aster/loader_accent.txt", color:ToHex())
        end)
    end

    function self.fail(message)
        self.failed = true
        if self.closed then return end
        pcall(function()
            statusLabel.Text = "Failed to load: " .. tostring(message):sub(1, 70)
            statusLabel.TextColor3 = Color3.fromRGB(255, 110, 110)
            fill.BackgroundColor3 = Color3.fromRGB(255, 110, 110)
        end)
        task.wait(3)
        destroy()
    end

    return self
end)()

Loader.step("Starting", 0.02)
local __plOk, __plErr = xpcall(function()
Loader.step("Starting session", 0.06)
-- Clean up anything a previous run of this script left behind.
if type(getgenv().TS_Connections) == "table" then
    for _, connection in ipairs(getgenv().TS_Connections) do
        pcall(function() connection:Disconnect() end)
    end
end
getgenv().TS_Connections = {}
if type(getgenv().TS_Drawings) == "table" then
    for _, drawing in ipairs(getgenv().TS_Drawings) do
        pcall(function() drawing:Remove() end)
    end
end
getgenv().TS_Drawings = {}

local function track(connection)
    table.insert(getgenv().TS_Connections, connection)
    return connection
end

if type(getgenv().HydrogenESP_Unload) == "function" then
    pcall(getgenv().HydrogenESP_Unload)
end

if getgenv().Library and type(getgenv().Library.Unload) == "function" then
    pcall(function() getgenv().Library:Unload() end)
end

Loader.step("Cleaning previous run", 0.12)
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- Skybox presets (asset list credit: larpclaude). "Default" leaves the game's own sky alone.
local SKYBOX_PRESETS = {
    ["Default"] = { KeepOriginal = true },
    ["Afternoon"] = {
        StarCount = 3000, SunAngularSize = 21, MoonAngularSize = 11,
        SkyboxUp = "rbxassetid://162001926",
        SkyboxDn = "rbxassetid://161998893",
        SkyboxFt = "rbxassetid://162001897",
        SkyboxBk = "rbxassetid://162001887",
        SkyboxLf = "rbxassetid://162001904",
        SkyboxRt = "rbxassetid://162001919",
    },
    ["Blue Space"] = {
        StarCount = 0, SunAngularSize = 21, MoonAngularSize = 11,
        SkyboxUp = "rbxassetid://367149078",
        SkyboxDn = "rbxassetid://367147970",
        SkyboxFt = "rbxassetid://366731193",
        SkyboxBk = "rbxassetid://366731024",
        SkyboxLf = "rbxassetid://366731613",
        SkyboxRt = "rbxassetid://366731514",
    },
    ["Classic Roblox"] = {
        StarCount = 3000, SunAngularSize = 21, MoonAngularSize = 11,
        SkyboxUp = "rbxassetid://11138465883",
        SkyboxDn = "rbxassetid://11138453351",
        SkyboxFt = "rbxassetid://11138458027",
        SkyboxBk = "rbxassetid://11138450201",
        SkyboxLf = "rbxassetid://11138460736",
        SkyboxRt = "rbxassetid://11138463127",
        SunTextureId = "rbxassetid://11138537872",
    },
    ["Cloudy"] = {
        StarCount = 3000, SunAngularSize = 21, MoonAngularSize = 11,
        SkyboxUp = "rbxassetid://246480504",
        SkyboxDn = "rbxassetid://246480523",
        SkyboxFt = "rbxassetid://246480105",
        SkyboxBk = "rbxassetid://246480323",
        SkyboxLf = "rbxassetid://246480549",
        SkyboxRt = "rbxassetid://246480565",
    },
    ["Dark Skies"] = {
        StarCount = 3000, SunAngularSize = 21, MoonAngularSize = 11,
        SkyboxUp = "rbxassetid://149397702",
        SkyboxDn = "rbxassetid://149397686",
        SkyboxFt = "rbxassetid://149397697",
        SkyboxBk = "rbxassetid://149397692",
        SkyboxLf = "rbxassetid://149397684",
        SkyboxRt = "rbxassetid://149397688",
    },
    ["Dawn"] = {
        StarCount = 3000, SunAngularSize = 21, MoonAngularSize = 11,
        SkyboxUp = "rbxassetid://323478865",
        SkyboxDn = "rbxassetid://323481190",
        SkyboxFt = "rbxassetid://323480314",
        SkyboxBk = "rbxassetid://323479840",
        SkyboxLf = "rbxassetid://323480786",
        SkyboxRt = "rbxassetid://323480131",
    },
    ["Dusk"] = {
        StarCount = 3000, SunAngularSize = 0, MoonAngularSize = 11,
        SkyboxUp = "rbxassetid://9778106496",
        SkyboxDn = "rbxassetid://9778110864",
        SkyboxFt = "rbxassetid://9778101192",
        SkyboxBk = "rbxassetid://9778108979",
        SkyboxLf = "rbxassetid://9778103329",
        SkyboxRt = "rbxassetid://9778104889",
    },
    ["Earth"] = {
        StarCount = 3000, SunAngularSize = 0, MoonAngularSize = 0,
        SkyboxUp = "rbxassetid://15753304473",
        SkyboxDn = "rbxassetid://15753362674",
        SkyboxFt = "rbxassetid://15753305823",
        SkyboxBk = "rbxassetid://15753305495",
        SkyboxLf = "rbxassetid://15753310707",
        SkyboxRt = "rbxassetid://15753304774",
    },
    ["Ethereal"] = {
        StarCount = 3000, SunAngularSize = 21, MoonAngularSize = 11,
        SkyboxUp = "rbxassetid://16823395515",
        SkyboxDn = "rbxassetid://16823388586",
        SkyboxFt = "rbxassetid://16823390254",
        SkyboxBk = "rbxassetid://16823386986",
        SkyboxLf = "rbxassetid://16823392344",
        SkyboxRt = "rbxassetid://16823394120",
    },
    ["Galaxy"] = {
        StarCount = 3000, SunAngularSize = 21, MoonAngularSize = 11,
        SkyboxUp = "rbxassetid://2049518578",
        SkyboxDn = "rbxassetid://2049519279",
        SkyboxFt = "rbxassetid://2049519882",
        SkyboxBk = "rbxassetid://2049520382",
        SkyboxLf = "rbxassetid://2049522478",
        SkyboxRt = "rbxassetid://2049521207",
    },
    ["Heaven"] = {
        StarCount = 3000, SunAngularSize = 21, MoonAngularSize = 11,
        SkyboxUp = "rbxassetid://7951703855",
        SkyboxDn = "rbxassetid://7951706908",
        SkyboxFt = "rbxassetid://7951694757",
        SkyboxBk = "rbxassetid://7951826533",
        SkyboxLf = "rbxassetid://7951697216",
        SkyboxRt = "rbxassetid://7951700251",
    },
    ["Horizontal Milky Way"] = {
        StarCount = 0, SunAngularSize = 21, MoonAngularSize = 11,
        SkyboxUp = "rbxassetid://714276621",
        SkyboxDn = "rbxassetid://714276541",
        SkyboxFt = "rbxassetid://714276657",
        SkyboxBk = "rbxassetid://714276643",
        SkyboxLf = "rbxassetid://714276648",
        SkyboxRt = "rbxassetid://714276638",
    },
    ["Jungle"] = {
        StarCount = 3000, SunAngularSize = 21, MoonAngularSize = 11,
        SkyboxUp = "rbxassetid://525546479",
        SkyboxDn = "rbxassetid://525544628",
        SkyboxFt = "rbxassetid://525548536",
        SkyboxBk = "rbxassetid://525546178",
        SkyboxLf = "rbxassetid://525550171",
        SkyboxRt = "rbxassetid://525545319",
    },
    ["Mountains"] = {
        StarCount = 3000, SunAngularSize = 21, MoonAngularSize = 11,
        SkyboxUp = "rbxassetid://48015387",
        SkyboxDn = "rbxassetid://48015300",
        SkyboxFt = "rbxassetid://368388290",
        SkyboxBk = "rbxassetid://368385273",
        SkyboxLf = "rbxassetid://368390615",
        SkyboxRt = "rbxassetid://368385190",
    },
    ["Nebula"] = {
        StarCount = 3000, SunAngularSize = 21, MoonAngularSize = 11,
        SkyboxUp = "rbxassetid://171448889",
        SkyboxDn = "rbxassetid://171448902",
        SkyboxFt = "rbxassetid://171448848",
        SkyboxBk = "rbxassetid://171448875",
        SkyboxLf = "rbxassetid://171448933",
        SkyboxRt = "rbxassetid://171448925",
    },
    ["Night"] = {
        StarCount = 0, SunAngularSize = 21, MoonAngularSize = 11,
        SkyboxUp = "rbxassetid://12064131",
        SkyboxDn = "rbxassetid://12064152",
        SkyboxFt = "rbxassetid://12064121",
        SkyboxBk = "rbxassetid://12064107",
        SkyboxLf = "rbxassetid://12063984",
        SkyboxRt = "rbxassetid://12064115",
    },
    ["Night Light"] = {
        StarCount = 3000, SunAngularSize = 21, MoonAngularSize = 11,
        SkyboxUp = "rbxassetid://171447068",
        SkyboxDn = "rbxassetid://171447094",
        SkyboxFt = "rbxassetid://171447041",
        SkyboxBk = "rbxassetid://171447054",
        SkyboxLf = "rbxassetid://171447128",
        SkyboxRt = "rbxassetid://171447111",
    },
    ["Ocean Sky"] = {
        StarCount = 3000, SunAngularSize = 1, MoonAngularSize = 0,
        SkyboxUp = "rbxassetid://11854708161",
        SkyboxDn = "rbxassetid://11854687121",
        SkyboxFt = "rbxassetid://11854693863",
        SkyboxBk = "rbxassetid://11854686548",
        SkyboxLf = "rbxassetid://11854696162",
        SkyboxRt = "rbxassetid://11854698541",
        SunTextureId = "rbxassetid://4774583925",
        MoonTextureId = "rbxassetid://4774580371",
    },
    ["Pink Clouds"] = {
        StarCount = 1334, SunAngularSize = 21, MoonAngularSize = 11,
        SkyboxUp = "rbxassetid://271077958",
        SkyboxDn = "rbxassetid://271077243",
        SkyboxFt = "rbxassetid://271042556",
        SkyboxBk = "rbxassetid://271042516",
        SkyboxLf = "rbxassetid://271042310",
        SkyboxRt = "rbxassetid://271042467",
    },
    ["Red Dusk"] = {
        StarCount = 3000, SunAngularSize = 21, MoonAngularSize = 11,
        SkyboxUp = "rbxassetid://136208328681929",
        SkyboxDn = "rbxassetid://123407860042117",
        SkyboxFt = "rbxassetid://132624761762466",
        SkyboxBk = "rbxassetid://85146619291315",
        SkyboxLf = "rbxassetid://102069641249982",
        SkyboxRt = "rbxassetid://136526747107728",
    },
    ["Redshift"] = {
        StarCount = 0, SunAngularSize = 21, MoonAngularSize = 11,
        SkyboxUp = "rbxassetid://401664936",
        SkyboxDn = "rbxassetid://401664862",
        SkyboxFt = "rbxassetid://401664960",
        SkyboxBk = "rbxassetid://401664839",
        SkyboxLf = "rbxassetid://401664881",
        SkyboxRt = "rbxassetid://401664901",
    },
    ["SFOTH"] = {
        StarCount = 3000, SunAngularSize = 21, MoonAngularSize = 11,
        SkyboxUp = "rbxassetid://1014449",
        SkyboxDn = "rbxassetid://1012891",
        SkyboxFt = "rbxassetid://1012887",
        SkyboxBk = "rbxassetid://1012890",
        SkyboxLf = "rbxassetid://1012889",
        SkyboxRt = "rbxassetid://1012888",
    },
    ["Saturn"] = {
        StarCount = 3000, SunAngularSize = 10, MoonAngularSize = 0,
        SkyboxUp = "rbxassetid://1898736761",
        SkyboxDn = "rbxassetid://1898727189",
        SkyboxFt = "rbxassetid://1898722814",
        SkyboxBk = "rbxassetid://1898724755",
        SkyboxLf = "rbxassetid://1898729298",
        SkyboxRt = "rbxassetid://1898741025",
        MoonTextureId = "rbxassetid://0",
    },
    ["Smoke"] = {
        StarCount = 3000, SunAngularSize = 21, MoonAngularSize = 11,
        SkyboxUp = "rbxassetid://171410742",
        SkyboxDn = "rbxassetid://171410748",
        SkyboxFt = "rbxassetid://171410730",
        SkyboxBk = "rbxassetid://171410736",
        SkyboxLf = "rbxassetid://171410766",
        SkyboxRt = "rbxassetid://171410755",
    },
    ["Solid Black"] = {
        StarCount = 0, SunAngularSize = 21, MoonAngularSize = 11,
        SkyboxUp = "rbxassetid://2013298",
        SkyboxDn = "rbxassetid://2013298",
        SkyboxFt = "rbxassetid://2013298",
        SkyboxBk = "rbxassetid://2013298",
        SkyboxLf = "rbxassetid://2013298",
        SkyboxRt = "rbxassetid://2013298",
    },
    ["Space"] = {
        StarCount = 0, SunAngularSize = 21, MoonAngularSize = 11,
        SkyboxUp = "rbxassetid://155441905",
        SkyboxDn = "rbxassetid://155441905",
        SkyboxFt = "rbxassetid://155441905",
        SkyboxBk = "rbxassetid://155441905",
        SkyboxLf = "rbxassetid://155441905",
        SkyboxRt = "rbxassetid://155441905",
    },
    ["Storm"] = {
        StarCount = 3000, SunAngularSize = 21, MoonAngularSize = 11,
        SkyboxUp = "rbxassetid://171410789",
        SkyboxDn = "rbxassetid://171410792",
        SkyboxFt = "rbxassetid://171410775",
        SkyboxBk = "rbxassetid://171410784",
        SkyboxLf = "rbxassetid://171410807",
        SkyboxRt = "rbxassetid://171410798",
    },
    ["Sunset"] = {
        StarCount = 5000, SunAngularSize = 18, MoonAngularSize = 11,
        SkyboxUp = "rbxassetid://264907379",
        SkyboxDn = "rbxassetid://264907909",
        SkyboxFt = "rbxassetid://264909420",
        SkyboxBk = "rbxassetid://264908339",
        SkyboxLf = "rbxassetid://264909758",
        SkyboxRt = "rbxassetid://264908886",
    },
    ["Underworld"] = {
        StarCount = 3000, SunAngularSize = 21, MoonAngularSize = 11,
        SkyboxUp = "rbxassetid://171561009",
        SkyboxDn = "rbxassetid://171561019",
        SkyboxFt = "rbxassetid://171560968",
        SkyboxBk = "rbxassetid://171560994",
        SkyboxLf = "rbxassetid://171561065",
        SkyboxRt = "rbxassetid://171561026",
    },
    ["Vertical Milky Way"] = {
        StarCount = 3000, SunAngularSize = 1.440000057220459, MoonAngularSize = 0.5699999928474426,
        SkyboxUp = "rbxassetid://5559302033",
        SkyboxDn = "rbxassetid://5559290893",
        SkyboxFt = "rbxassetid://5559300879",
        SkyboxBk = "rbxassetid://5559289158",
        SkyboxLf = "rbxassetid://5559292825",
        SkyboxRt = "rbxassetid://5559302989",
    },
    ["White"] = {
        StarCount = 0, SunAngularSize = 21, MoonAngularSize = 11,
        SkyboxUp = "rbxassetid://321136141",
        SkyboxDn = "rbxassetid://321136141",
        SkyboxFt = "rbxassetid://321136141",
        SkyboxBk = "rbxassetid://321136141",
        SkyboxLf = "rbxassetid://321136141",
        SkyboxRt = "rbxassetid://321136141",
    },
    -- Second list (credit: larpClaude)
    ["Aesthetic 3"] = {
        StarCount = 500, SunAngularSize = 0, MoonAngularSize = 0,
        SkyboxUp = "rbxassetid://151165227",
        SkyboxDn = "rbxassetid://151165197",
        SkyboxFt = "rbxassetid://151165224",
        SkyboxBk = "rbxassetid://151165214",
        SkyboxLf = "rbxassetid://151165191",
        SkyboxRt = "rbxassetid://151165206",
        SunTextureId = "rbxassetid://8281961896",
        MoonTextureId = "rbxassetid://6444320592",
    },
    ["Aesthetic Mountains"] = {
        StarCount = 3000, SunAngularSize = 21, MoonAngularSize = 11,
        SkyboxUp = "rbxassetid://15470207755",
        SkyboxDn = "rbxassetid://15470151245",
        SkyboxFt = "rbxassetid://15470200128",
        SkyboxBk = "rbxassetid://15470198023",
        SkyboxLf = "rbxassetid://15470202648",
        SkyboxRt = "rbxassetid://15470204862",
        SunTextureId = "rbxassetid://6196665106",
        MoonTextureId = "rbxassetid://6444320592",
    },
    ["Better Night"] = {
        StarCount = 3000,
        SkyboxUp = "rbxassetid://15470303050",
        SkyboxDn = "rbxassetid://15470291746",
        SkyboxFt = "rbxassetid://15470294431",
        SkyboxBk = "rbxassetid://15470289121",
        SkyboxLf = "rbxassetid://15470297162",
        SkyboxRt = "rbxassetid://15470299887",
    },
    ["Better Night 3"] = {
        StarCount = 500, SunAngularSize = 21, MoonAngularSize = 1.5,
        SkyboxUp = "rbxassetid://2670644331",
        SkyboxDn = "rbxassetid://2670643365",
        SkyboxFt = "rbxassetid://2670643214",
        SkyboxBk = "rbxassetid://2670643994",
        SkyboxLf = "rbxassetid://2670643070",
        SkyboxRt = "rbxassetid://2670644173",
        SunTextureId = "rbxassetid://6196665106",
        MoonTextureId = "rbxassetid://1075087760",
    },
    ["Blizzard"] = {
        StarCount = 3000, SunAngularSize = 21, MoonAngularSize = 0,
        SkyboxUp = "rbxassetid://16653228333",
        SkyboxDn = "rbxassetid://16653222701",
        SkyboxFt = "rbxassetid://16653224051",
        SkyboxBk = "rbxassetid://16653221738",
        SkyboxLf = "rbxassetid://16653225849",
        SkyboxRt = "rbxassetid://16653227200",
        SunTextureId = "rbxassetid://6196665106",
        MoonTextureId = "rbxassetid://6444320592",
    },
    ["Blue Clouds"] = {
        StarCount = 3000, SunAngularSize = 0, MoonAngularSize = 0,
        SkyboxUp = "rbxassetid://591059642",
        SkyboxDn = "rbxassetid://591059876",
        SkyboxFt = "rbxassetid://591058104",
        SkyboxBk = "rbxassetid://591058823",
        SkyboxLf = "rbxassetid://591057861",
        SkyboxRt = "rbxassetid://591057625",
        SunTextureId = "rbxassetid://6196665106",
        MoonTextureId = "rbxassetid://6444320592",
    },
    ["Blue Space (alt)"] = {
        StarCount = 3000, SunAngularSize = 21, MoonAngularSize = 0,
        SkyboxUp = "rbxassetid://16876552681",
        SkyboxDn = "rbxassetid://16876543880",
        SkyboxFt = "rbxassetid://16876546384",
        SkyboxBk = "rbxassetid://16876541778",
        SkyboxLf = "rbxassetid://16876548320",
        SkyboxRt = "rbxassetid://16876550345",
        SunTextureId = "rbxassetid://8281961896",
        MoonTextureId = "rbxassetid://6444320592",
    },
    ["Cloudy (alt)"] = {
        StarCount = 3000,
        SkyboxUp = "rbxassetid://4495867486",
        SkyboxDn = "rbxassetid://4495864887",
        SkyboxFt = "rbxassetid://4495865458",
        SkyboxBk = "rbxassetid://4495864450",
        SkyboxLf = "rbxassetid://4495866035",
        SkyboxRt = "rbxassetid://4495866584",
    },
    ["Darkish Pink"] = {
        StarCount = 3000, SunAngularSize = 21, MoonAngularSize = 11,
        SkyboxUp = "rbxassetid://570555929",
        SkyboxDn = "rbxassetid://570555964",
        SkyboxFt = "rbxassetid://570555800",
        SkyboxBk = "rbxassetid://570555736",
        SkyboxLf = "rbxassetid://570555840",
        SkyboxRt = "rbxassetid://570555882",
        SunTextureId = "rbxassetid://8281961896",
        MoonTextureId = "rbxassetid://6444320592",
    },
    ["FPSBoost"] = {
        StarCount = 3000, SunAngularSize = 0, MoonAngularSize = 0,
        SkyboxUp = "rbxassetid://11457548274",
        SkyboxDn = "rbxassetid://11457548274",
        SkyboxFt = "rbxassetid://11457548274",
        SkyboxBk = "rbxassetid://11457548274",
        SkyboxLf = "rbxassetid://11457548274",
        SkyboxRt = "rbxassetid://11457548274",
        SunTextureId = "rbxassetid://8281961896",
        MoonTextureId = "rbxassetid://6444320592",
    },
    ["Flame"] = {
        StarCount = 3000, SunAngularSize = 21, MoonAngularSize = 0,
        SkyboxUp = "rbxassetid://6286790025",
        SkyboxDn = "rbxassetid://6286782353",
        SkyboxFt = "rbxassetid://6286784186",
        SkyboxBk = "rbxassetid://6286780109",
        SkyboxLf = "rbxassetid://6286785801",
        SkyboxRt = "rbxassetid://6286788245",
        SunTextureId = "rbxassetid://8281961896",
        MoonTextureId = "rbxassetid://6444320592",
    },
    ["Flaming Sunset"] = {
        StarCount = 3000, SunAngularSize = 0, MoonAngularSize = 0,
        SkyboxUp = "rbxassetid://415688354",
        SkyboxDn = "rbxassetid://415688193",
        SkyboxFt = "rbxassetid://415688242",
        SkyboxBk = "rbxassetid://415688378",
        SkyboxLf = "rbxassetid://415688310",
        SkyboxRt = "rbxassetid://415688274",
        SunTextureId = "rbxassetid://6196665106",
        MoonTextureId = "rbxassetid://6444320592",
    },
    ["Funny Storm"] = {
        StarCount = 3000, SunAngularSize = 21, MoonAngularSize = 0,
        SkyboxUp = "rbxassetid://6280942402",
        SkyboxDn = "rbxassetid://6280935347",
        SkyboxFt = "rbxassetid://6280936575",
        SkyboxBk = "rbxassetid://6280934001",
        SkyboxLf = "rbxassetid://6280938749",
        SkyboxRt = "rbxassetid://6280940989",
        SunTextureId = "rbxassetid://8281961896",
        MoonTextureId = "rbxassetid://6444320592",
    },
    ["Galaxy (alt)"] = {
        StarCount = 3000, SunAngularSize = 0, MoonAngularSize = 0,
        SkyboxUp = "rbxassetid://159454288",
        SkyboxDn = "rbxassetid://159454296",
        SkyboxFt = "rbxassetid://159454293",
        SkyboxBk = "rbxassetid://159454299",
        SkyboxLf = "rbxassetid://159454293",
        SkyboxRt = "rbxassetid://159454293",
        SunTextureId = "rbxassetid://8281961896",
        MoonTextureId = "rbxassetid://6444320592",
    },
    ["Galaxy 2"] = {
        StarCount = 500, SunAngularSize = 0, MoonAngularSize = 0,
        SkyboxUp = "rbxassetid://14164405298",
        SkyboxDn = "rbxassetid://14164386126",
        SkyboxFt = "rbxassetid://14164389230",
        SkyboxBk = "rbxassetid://14164368678",
        SkyboxLf = "rbxassetid://14164398493",
        SkyboxRt = "rbxassetid://14164402782",
        SunTextureId = "rbxassetid://8281961896",
        MoonTextureId = "rbxassetid://6444320592",
    },
    ["Galaxy 3"] = {
        StarCount = 3000, SunAngularSize = 0, MoonAngularSize = 0,
        SkyboxUp = "rbxassetid://14543371676",
        SkyboxDn = "rbxassetid://14543358958",
        SkyboxFt = "rbxassetid://14543257810",
        SkyboxBk = "rbxassetid://14543264135",
        SkyboxLf = "rbxassetid://14543275895",
        SkyboxRt = "rbxassetid://14543280890",
        SunTextureId = "rbxassetid://8281961896",
        MoonTextureId = "rbxassetid://6444320592",
    },
    ["Green Haze"] = {
        SunAngularSize = 0,
        SkyboxUp = "rbxassetid://160193458",
        SkyboxDn = "rbxassetid://160193466",
        SkyboxFt = "rbxassetid://160193461",
        SkyboxBk = "rbxassetid://160193404",
        SkyboxLf = "rbxassetid://160193469",
        SkyboxRt = "rbxassetid://160193463",
    },
    ["Hell"] = {
        StarCount = 3000, SunAngularSize = 0, MoonAngularSize = 11,
        SkyboxUp = "rbxassetid://11730857150",
        SkyboxDn = "rbxassetid://11730842997",
        SkyboxFt = "rbxassetid://11730849615",
        SkyboxBk = "rbxassetid://11730840088",
        SkyboxLf = "rbxassetid://11730852920",
        SkyboxRt = "rbxassetid://11730855491",
        SunTextureId = "rbxassetid://8281961896",
        MoonTextureId = "rbxassetid://6444320592",
    },
    ["Lunar Night"] = {
        StarCount = 0, SunAngularSize = 0, MoonAngularSize = 0,
        SkyboxUp = "rbxassetid://187712111",
        SkyboxDn = "rbxassetid://187712428",
        SkyboxFt = "rbxassetid://187712836",
        SkyboxBk = "rbxassetid://187713366",
        SkyboxLf = "rbxassetid://187713755",
        SkyboxRt = "rbxassetid://187714525",
        SunTextureId = "rbxassetid://8281961896",
        MoonTextureId = "rbxassetid://6444320592",
    },
    ["Milkyway"] = {
        StarCount = 3000, SunAngularSize = 0, MoonAngularSize = 0,
        SkyboxUp = "rbxassetid://137817405681365",
        SkyboxDn = "rbxassetid://108406529909981",
        SkyboxFt = "rbxassetid://104400530594543",
        SkyboxBk = "rbxassetid://129876530632297",
        SkyboxLf = "rbxassetid://73372229972523",
        SkyboxRt = "rbxassetid://87408857415924",
        SunTextureId = "rbxassetid://8281961896",
        MoonTextureId = "rbxassetid://6444320592",
    },
    ["Mountains (alt)"] = {
        StarCount = 3000, SunAngularSize = 21, MoonAngularSize = 0,
        SkyboxUp = "rbxassetid://15359412677",
        SkyboxDn = "rbxassetid://15359411132",
        SkyboxFt = "rbxassetid://15359412131",
        SkyboxBk = "rbxassetid://15359410490",
        SkyboxLf = "rbxassetid://15359411633",
        SkyboxRt = "rbxassetid://15359417656",
        SunTextureId = "rbxassetid://8281961896",
        MoonTextureId = "rbxassetid://6444320592",
    },
    ["Nebula (alt)"] = {
        StarCount = 3000, SunAngularSize = 0, MoonAngularSize = 0,
        SkyboxUp = "rbxassetid://5260824661",
        SkyboxDn = "rbxassetid://5260653793",
        SkyboxFt = "rbxassetid://5260817288",
        SkyboxBk = "rbxassetid://5260808177",
        SkyboxLf = "rbxassetid://5260800833",
        SkyboxRt = "rbxassetid://5260811073",
        SunTextureId = "rbxassetid://8281961896",
        MoonTextureId = "rbxassetid://6444320592",
    },
    ["Nebula 2"] = {
        StarCount = 3000, SunAngularSize = 0, MoonAngularSize = 0,
        SkyboxUp = "rbxassetid://16932810138",
        SkyboxDn = "rbxassetid://16932797813",
        SkyboxFt = "rbxassetid://16932800523",
        SkyboxBk = "rbxassetid://16932794531",
        SkyboxLf = "rbxassetid://16932803722",
        SkyboxRt = "rbxassetid://16932806825",
        SunTextureId = "rbxassetid://8281961896",
        MoonTextureId = "rbxassetid://6444320592",
    },
    ["Nebula 6"] = {
        StarCount = 3000, SunAngularSize = 21, MoonAngularSize = 11,
        SkyboxUp = "rbxassetid://16694204069",
        SkyboxDn = "rbxassetid://16694190947",
        SkyboxFt = "rbxassetid://16694194795",
        SkyboxBk = "rbxassetid://16694187412",
        SkyboxLf = "rbxassetid://16694197080",
        SkyboxRt = "rbxassetid://16694200892",
        SunTextureId = "rbxassetid://8281961896",
        MoonTextureId = "rbxassetid://6444320592",
    },
    ["Nether World"] = {
        StarCount = 3000, SunAngularSize = 0, MoonAngularSize = 0,
        SkyboxUp = "rbxassetid://14365019327",
        SkyboxDn = "rbxassetid://14365023350",
        SkyboxFt = "rbxassetid://14365018399",
        SkyboxBk = "rbxassetid://14365019002",
        SkyboxLf = "rbxassetid://14365018705",
        SkyboxRt = "rbxassetid://14365018143",
        SunTextureId = "rbxassetid://8281961896",
        MoonTextureId = "rbxassetid://6444320592",
    },
    ["New York"] = {
        StarCount = 3000, SunAngularSize = 0, MoonAngularSize = 0,
        SkyboxUp = "rbxassetid://11333967970",
        SkyboxDn = "rbxassetid://11333969768",
        SkyboxFt = "rbxassetid://11333964303",
        SkyboxBk = "rbxassetid://11333973069",
        SkyboxLf = "rbxassetid://11333971332",
        SkyboxRt = "rbxassetid://11333982864",
        SunTextureId = "rbxassetid://6196665106",
        MoonTextureId = "rbxassetid://6444320592",
    },
    ["Pink Art"] = {
        StarCount = 3000, SunAngularSize = 21, MoonAngularSize = 0,
        SkyboxUp = "rbxassetid://79190209626172",
        SkyboxDn = "rbxassetid://78865378050055",
        SkyboxFt = "rbxassetid://104560113223878",
        SkyboxBk = "rbxassetid://71607054149497",
        SkyboxLf = "rbxassetid://80395333901607",
        SkyboxRt = "rbxassetid://87570388049514",
    },
    ["Pink Mountains"] = {
        StarCount = 3000, SunAngularSize = 21, MoonAngularSize = 0,
        SkyboxUp = "rbxassetid://160188588",
        SkyboxDn = "rbxassetid://160188614",
        SkyboxFt = "rbxassetid://160188609",
        SkyboxBk = "rbxassetid://160188495",
        SkyboxLf = "rbxassetid://160188589",
        SkyboxRt = "rbxassetid://160188597",
    },
    ["Purple"] = {
        StarCount = 3000, SunAngularSize = 0, MoonAngularSize = 0,
        SkyboxUp = "rbxassetid://8539981085",
        SkyboxDn = "rbxassetid://8539981943",
        SkyboxFt = "rbxassetid://8539981721",
        SkyboxBk = "rbxassetid://8539982183",
        SkyboxLf = "rbxassetid://8539981424",
        SkyboxRt = "rbxassetid://8539980766",
        SunTextureId = "rbxassetid://8281961896",
        MoonTextureId = "rbxassetid://6444320592",
    },
    ["Purple 2"] = {
        StarCount = 3000, SunAngularSize = 11, MoonAngularSize = 0,
        SkyboxUp = "rbxassetid://8107849791",
        SkyboxDn = "rbxassetid://6444884785",
        SkyboxFt = "rbxassetid://8107841671",
        SkyboxBk = "rbxassetid://8107841671",
        SkyboxLf = "rbxassetid://8107841671",
        SkyboxRt = "rbxassetid://8107841671",
        SunTextureId = "rbxassetid://6196665106",
        MoonTextureId = "rbxassetid://6444320592",
    },
    ["Purple 3"] = {
        StarCount = 3000, SunAngularSize = 0, MoonAngularSize = 0,
        SkyboxUp = "rbxassetid://433274285",
        SkyboxDn = "rbxassetid://433274194",
        SkyboxFt = "rbxassetid://433274131",
        SkyboxBk = "rbxassetid://433274085",
        SkyboxLf = "rbxassetid://433274370",
        SkyboxRt = "rbxassetid://433274429",
        SunTextureId = "rbxassetid://8281961896",
        MoonTextureId = "rbxassetid://6444320592",
    },
    ["Purple Clouds"] = {
        StarCount = 3000, SunAngularSize = 21, MoonAngularSize = 0,
        SkyboxUp = "rbxassetid://570557727",
        SkyboxDn = "rbxassetid://570557775",
        SkyboxFt = "rbxassetid://570557559",
        SkyboxBk = "rbxassetid://570557514",
        SkyboxLf = "rbxassetid://570557620",
        SkyboxRt = "rbxassetid://570557672",
        SunTextureId = "rbxassetid://8281961896",
        MoonTextureId = "rbxassetid://6444320592",
    },
    ["Purple Night"] = {
        StarCount = 3000, SunAngularSize = 0, MoonAngularSize = 0,
        SkyboxUp = "rbxassetid://5084576400",
        SkyboxDn = "rbxassetid://5260653793",
        SkyboxFt = "rbxassetid://5260817288",
        SkyboxBk = "rbxassetid://5260808177",
        SkyboxLf = "rbxassetid://5260800833",
        SkyboxRt = "rbxassetid://5260800833",
        SunTextureId = "rbxassetid://8281961896",
        MoonTextureId = "rbxassetid://6444320592",
    },
    ["Purple Planet"] = {
        StarCount = 3000, SunAngularSize = 21, MoonAngularSize = 0,
        SkyboxUp = "rbxassetid://16262366016",
        SkyboxDn = "rbxassetid://16262358026",
        SkyboxFt = "rbxassetid://16262360469",
        SkyboxBk = "rbxassetid://16262356578",
        SkyboxLf = "rbxassetid://16262362003",
        SkyboxRt = "rbxassetid://16262363873",
        SunTextureId = "rbxassetid://8281961896",
        MoonTextureId = "rbxassetid://6444320592",
    },
    ["Purple Space"] = {
        StarCount = 3000, SunAngularSize = 0, MoonAngularSize = 0,
        SkyboxUp = "rbxassetid://15983964246",
        SkyboxDn = "rbxassetid://15983966825",
        SkyboxFt = "rbxassetid://5260817288",
        SkyboxBk = "rbxassetid://15983968922",
        SkyboxLf = "rbxassetid://15983967420",
        SkyboxRt = "rbxassetid://15983966246",
        SunTextureId = "rbxassetid://8281961896",
        MoonTextureId = "rbxassetid://6444320592",
    },
    ["Space (alt)"] = {
        StarCount = 3000, SunAngularSize = 0, MoonAngularSize = 0,
        SkyboxUp = "rbxassetid://166510114",
        SkyboxDn = "rbxassetid://166510057",
        SkyboxFt = "rbxassetid://166510116",
        SkyboxBk = "rbxassetid://166509999",
        SkyboxLf = "rbxassetid://166510092",
        SkyboxRt = "rbxassetid://166510131",
        SunTextureId = "rbxassetid://8281961896",
        MoonTextureId = "rbxassetid://6444320592",
    },
    ["Space 2"] = {
        StarCount = 3000, SunAngularSize = 11, MoonAngularSize = 20,
        SkyboxUp = "rbxassetid://11844053742",
        SkyboxDn = "rbxassetid://11844069700",
        SkyboxFt = "rbxassetid://11844067209",
        SkyboxBk = "rbxassetid://11844076072",
        SkyboxLf = "rbxassetid://11844063543",
        SkyboxRt = "rbxassetid://11844058446",
        MoonTextureId = "rbxassetid://11844121592",
    },
    ["Storm (alt)"] = {
        SunAngularSize = 0, MoonAngularSize = 0,
        SkyboxUp = "rbxassetid://1618913654",
        SkyboxDn = "rbxassetid://1618913943",
        SkyboxFt = "rbxassetid://1618913244",
        SkyboxBk = "rbxassetid://1618912481",
        SkyboxLf = "rbxassetid://1618912849",
        SkyboxRt = "rbxassetid://1618911568",
        SunTextureId = "rbxassetid://1084351190",
        MoonTextureId = "rbxassetid://1075087760",
    },
    ["Valentines"] = {
        StarCount = 3000, SunAngularSize = 21, MoonAngularSize = 0,
        SkyboxUp = "rbxassetid://11427771954",
        SkyboxDn = "rbxassetid://11427770685",
        SkyboxFt = "rbxassetid://11427769401",
        SkyboxBk = "rbxassetid://11427769401",
        SkyboxLf = "rbxassetid://11427769401",
        SkyboxRt = "rbxassetid://11427769401",
    },
    ["Winter"] = {
        StarCount = 3000, SunAngularSize = 21, MoonAngularSize = 11,
        SkyboxUp = "rbxassetid://155674931",
        SkyboxDn = "rbxassetid://155674246",
        SkyboxFt = "rbxassetid://155657609",
        SkyboxBk = "rbxassetid://155657655",
        SkyboxLf = "rbxassetid://155657671",
        SkyboxRt = "rbxassetid://155657619",
        SunTextureId = "rbxassetid://8281961896",
        MoonTextureId = "rbxassetid://6444320592",
    },
}

local SKYBOX_NAMES = { "Default" }
do
    local names = {}
    for name in pairs(SKYBOX_PRESETS) do
        if name ~= "Default" then table.insert(names, name) end
    end
    table.sort(names)
    for _, name in ipairs(names) do table.insert(SKYBOX_NAMES, name) end
end

-- Hit sounds. Names fill the dropdown, ids are played by playHitSound().
local HIT_SOUNDS = {
    ["BowHit"] = "rbxassetid://1053296915",
    ["CSGO"] = "rbxassetid://5764885315",
    ["Click"] = "rbxassetid://1347140027",
    ["Damage"] = "rbxassetid://8587183599",
    ["Explosion"] = "rbxassetid://90854697257230",
    ["Gamesense"] = "rbxassetid://4817809188",
    ["Hitmarker"] = "rbxassetid://1129547534",
    ["Hover"] = "rbxassetid://6333717580",
    ["Ice"] = "rbxassetid://268934012",
    ["Impact"] = "rbxassetid://6759025689",
    ["Minecraft"] = "rbxassetid://4018616850",
    ["Neverlose"] = "rbxassetid://6607204501",
    ["Pop"] = "rbxassetid://18803667669",
    ["Rust"] = "rbxassetid://5043539486",
    ["Sparkle"] = "rbxassetid://132463144859699",
    ["Steve"] = "rbxassetid://4965083997",
    ["TF2"] = "rbxassetid://8255306220",
    ["Windows"] = "rbxassetid://9066167010",
}
local HIT_SOUND_NAMES = {}
for name in pairs(HIT_SOUNDS) do table.insert(HIT_SOUND_NAMES, name) end
table.sort(HIT_SOUND_NAMES)
local playHitSound -- assigned in the logic section below
local function noop() end
local SpooferActions = { apply = noop, reset = noop } -- replaced by the avatar changer in the logic section

-- Forcefield textures: set on MeshParts, they replace the animated forcefield pattern.
local FORCEFIELD_TEXTURE_NAMES = { "Disabled", "Webbed", "Pixelated", "Swirl", "Shield", "Bubbles", "Matrix", "Honeycomb", "Clouds", "Galaxy", "Stars", "Wires", "Camo", "Hexagon", "Particles", "Triangular", "Wall", "Scanning" }
local FORCEFIELD_TEXTURES = {
    ["Disabled"] = "",
    ["Webbed"] = "rbxassetid://2179243880",
    ["Pixelated"] = "rbxassetid://140652787",
    ["Swirl"] = "rbxassetid://8133639623",
    ["Shield"] = "rbxassetid://361073795",
    ["Bubbles"] = "rbxassetid://1461576423",
    ["Matrix"] = "rbxassetid://10713189068",
    ["Honeycomb"] = "rbxassetid://179898251",
    ["Clouds"] = "rbxassetid://5176277457",
    ["Galaxy"] = "rbxassetid://1120738433",
    ["Stars"] = "rbxassetid://598201818",
    ["Wires"] = "rbxassetid://14127933",
    ["Camo"] = "rbxassetid://3280937154",
    ["Hexagon"] = "rbxassetid://6175083785",
    ["Particles"] = "rbxassetid://1133822388",
    ["Triangular"] = "rbxassetid://4504368932",
    ["Wall"] = "rbxassetid://4271279",
    ["Scanning"] = "rbxassetid://5843010904",
}

-- Beam looks for your own bullet tracers. Other players keep the game's tracers.
local TRACER_PRESETS = {
    ["Obelus"] = {
        Texture = "rbxassetid://2382169232", Brightness = 1.5,
        Transparency = NumberSequence.new(0.45), BaseTransparency = 0.45,
        LightEmission = 1, LightInfluence = 0, Segments = 1, TextureLength = 5,
        TextureMode = Enum.TextureMode.Stretch, TextureSpeed = 0, Width0 = 0.3, Width1 = 0.3, FaceCamera = true,
    },
    ["Lightning"] = {
        Texture = "rbxassetid://7151778302", Brightness = 1.5,
        Transparency = NumberSequence.new(0.45), BaseTransparency = 0.45,
        LightEmission = 1, LightInfluence = 0, Segments = 10, TextureLength = 1,
        TextureMode = Enum.TextureMode.Stretch, TextureSpeed = 1, Width0 = 1.2, Width1 = 1.2, FaceCamera = true,
    },
    ["DNA"] = {
        Texture = "rbxassetid://7071778278", Brightness = 1.5,
        Transparency = NumberSequence.new(0.45), BaseTransparency = 0.45,
        LightEmission = 1, LightInfluence = 0, Segments = 1, TextureLength = 12,
        TextureMode = Enum.TextureMode.Wrap, TextureSpeed = 1, Width0 = 0.6, Width1 = 0.6, FaceCamera = true,
    },
}
-- Styles from the Kicia tracer source: thin textured beams.
local function thinStyle(texture)
    return {
        Texture = texture, Brightness = 1,
        Transparency = NumberSequence.new(0), BaseTransparency = 0,
        LightEmission = 1, LightInfluence = 0, Segments = 1, TextureLength = 4,
        TextureMode = Enum.TextureMode.Stretch, TextureSpeed = 1, Width0 = 0.08, Width1 = 0.08, FaceCamera = true,
    }
end
TRACER_PRESETS["Plain"] = thinStyle("")
TRACER_PRESETS["Beam"] = thinStyle("rbxassetid://12781852245")
TRACER_PRESETS["Bolt"] = thinStyle("rbxassetid://446111271")
TRACER_PRESETS["Trail"] = thinStyle("rbxassetid://6419989824")
TRACER_PRESETS["Zigzag"] = thinStyle("rbxassetid://1274380363")
TRACER_PRESETS["Heartrate"] = thinStyle("rbxassetid://5830549480")
TRACER_PRESETS["Chain"] = thinStyle("rbxassetid://9632168658")
TRACER_PRESETS["Glitch"] = thinStyle("rbxassetid://8089467613")
TRACER_PRESETS["Swirl"] = thinStyle("rbxassetid://5638168605")
local TRACER_NAMES = { "Obelus", "Lightning", "DNA", "Plain", "Beam", "Bolt", "Trail", "Zigzag", "Heartrate", "Chain", "Glitch", "Swirl" }
local WEATHER_NAMES = { "Snow", "Rain", "Blizzard" }

local LocalPlayer = Players.LocalPlayer

Loader.verify(0.16)
local UI_REPO = "https://raw.githubusercontent.com/WhyWKey/linoria/main/"
Loader.step("Downloading UI library", 0.22)
local Library = loadstring(game:HttpGet(UI_REPO .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(UI_REPO .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(UI_REPO .. "addons/SaveManager.lua"))()
-- This library never sets HasTransparency on color pickers, so SaveManager reset every alpha
-- to 0 when a config loaded. Loading now restores the saved transparency.
pcall(function()
    SaveManager.Parser.ColorPicker.Load = function(idx, data)
        local picker = getgenv().Options and getgenv().Options[idx]
        if picker then picker:SetValueRGB(Color3.fromHex(data.value), tonumber(data.transparency) or 0) end
    end
end)
Loader.step("UI library ready", 0.34)
getgenv().Library = Library

local Options = getgenv().Options
local Toggles = getgenv().Toggles


-- One-time cleanup hook. Linoria stores a single OnUnload callback, so every
-- module registers its cleanup here and the callback below runs them all.
local cleanupTasks = {}
local function onUnload(fn)
    table.insert(cleanupTasks, fn)
end

Library:OnUnload(function()
    for _, fn in ipairs(cleanupTasks) do pcall(fn) end

    for _, connection in ipairs(getgenv().TS_Connections or {}) do
        pcall(function() connection:Disconnect() end)
    end
    getgenv().TS_Connections = {}

    for _, drawing in ipairs(getgenv().TS_Drawings or {}) do
        pcall(function() drawing:Remove() end)
    end
    getgenv().TS_Drawings = {}
end)

-- Linoria keeps values on Toggles[...] / Options[...].
-- Toggle -> boolean, Slider -> number, Dropdown -> string (or {name = true} when Multi),
-- ColorPicker -> Color3, KeyPicker -> key name string.
local function readFlag(name, default)
    local object = Toggles[name]
    if object == nil then object = Options[name] end
    if object == nil or object.Value == nil then return default end
    return object.Value
end

-- Player relationships: a player can be marked Friendly or Priority; everyone else is judged by team.
local Relations = {} -- [UserId] = "Friendly" | "Priority"
local function isEnemy(player)
    if not player or player == LocalPlayer then return false end
    local explicit = Relations[player.UserId]
    if explicit == "Friendly" then return false end
    if explicit == "Priority" then return true end
    local mine, theirs = LocalPlayer.Team, player.Team
    if not mine or not theirs then return true end
    if mine == theirs then return false end
    return true -- a Neutral player on either side counts as an enemy
end
local function relationOf(player)
    local explicit = Relations[player.UserId]
    if explicit then return explicit end
    return isEnemy(player) and "Enemy" or "Friendly"
end
-- Hostile only: an Inmate that is not Hostile is peaceful. This applies whatever team you are on;
-- Priority players are never treated as peaceful.
local function isPeaceful(player)
    if not player or Relations[player.UserId] == "Priority" then return false end
    local team = player.Team
    if not team or team.Name ~= "Inmates" then return false end
    local char = player.Character
    return not (char and char:GetAttribute("Hostile") == true)
end

-- Palette of the library's built-in "Perception" theme, applied before the window is built.
Library.FontColor = Color3.fromRGB(182, 182, 182)
Library.MainColor = Color3.fromRGB(20, 20, 20)
Library.BackgroundColor = Color3.fromRGB(23, 23, 23)
Library.AccentColor = Color3.fromRGB(102, 137, 148)
Library.OutlineColor = Color3.fromRGB(24, 24, 24)
Library.AccentColorDark = Library:GetDarkerColor(Library.AccentColor)
Library:UpdateColorsUsingRegistry()

Loader.step("Building menu", 0.42)
local LinoriaWindow = Library:CreateWindow({
    Title = "Aster",
    Center = true,
    AutoShow = false, -- the loader opens the menu when it finishes
    MenuFadeTime = 0.2,
    -- Resizing is built into this library: drag the round grip in the bottom-right corner.
    -- Blur and darken are off by default so the game stays visible while you tweak visuals;
    -- both can be turned on in Settings > Background.
    UseBlur = false,
    UseDarken = false,
})

-- Keep the menu above the ESP overlay (player names used to draw over it).
pcall(function() Library.ScreenGui.DisplayOrder = 100 end)

-- ===== Compatibility layer =====================================================
-- The UI below is written as Page / Section / MultiSection / Toggle / Slider calls.
-- This layer maps each of them onto Linoria tabs, groupboxes and tabboxes.
local function keyName(key)
    local ok, name = pcall(function() return key.Name end)
    if ok and type(name) == "string" then return name end
    return tostring(key or "None")
end

local function toRounding(decimals)
    if type(decimals) ~= "number" or decimals <= 0 or decimals >= 1 then return 0 end
    return math.clamp(math.floor(-math.log10(decimals) + 0.5), 0, 4)
end

-- Pressing Escape while picking a key clears the keybind (the menu key falls back to its default instead).
local function escapeUnbinds(flag, fallback)
    local picker = Options[flag]
    if not picker then return end
    picker:OnChanged(function()
        if picker.Value == "Escape" then
            pcall(function() picker:SetValue({ fallback, picker.Mode }) end)
        end
    end)
end

local function wrapElement(linoriaObject)
    local element = {}
    function element:Colorpicker(info)
        if not linoriaObject.AddColorPicker then
            warn("Colorpicker skipped (element has no addon support):", info.Flag)
            return element
        end
        local pickerInfo = {
            Default = info.Default or Color3.fromRGB(255, 255, 255),
            Title = info.Name or "Color",
        }
        if info.Alpha then pickerInfo.Transparency = type(info.Alpha) == "number" and info.Alpha or 0 end -- shows the alpha slider; value is Options[flag].Transparency
        linoriaObject:AddColorPicker(info.Flag, pickerInfo)
        return element
    end
    function element:Keybind(info)
        if not linoriaObject.AddKeyPicker then
            warn("Keybind skipped (element has no addon support):", info.Flag)
            return element
        end
        linoriaObject:AddKeyPicker(info.Flag, {
            Default = keyName(info.Default),
            Mode = info.Mode or "Toggle",
            Text = info.Name or "Keybind",
            NoUI = false,
            SyncToggleState = info.Sync == true, -- the key flips the toggle it is attached to
        })
        escapeUnbinds(info.Flag, "None")
        return element
    end
    return element
end

local function wrapGroup(group, page, side)
    local wrapped = {}
    local function bump() page.load[side] = page.load[side] + 1 end

    function wrapped:Toggle(info)
        bump()
        return wrapElement(group:AddToggle(info.Flag, {
            Text = info.Name,
            Default = info.Default == true,
            Tooltip = info.Tooltip,
            Callback = info.Callback,
        }))
    end

    function wrapped:Slider(info)
        bump()
        group:AddSlider(info.Flag, {
            Text = info.Name,
            Min = info.Min,
            Max = info.Max,
            Default = math.clamp(info.Default or info.Min, info.Min, info.Max),
            Rounding = toRounding(info.Decimals),
            Suffix = info.Suffix or "",
            Compact = false,
            HideMax = true,
            Tooltip = info.Tooltip,
            Callback = info.Callback,
        })
    end

    function wrapped:Dropdown(info)
        bump()
        group:AddDropdown(info.Flag, {
            Text = info.Name,
            Values = info.Items,
            Default = info.Default,
            Multi = info.Multi == true,
            AllowNull = info.Default == nil,
            Tooltip = info.Tooltip,
            Callback = info.Callback,
        })
    end

    function wrapped:Label(info)
        bump()
        -- Linoria only gives unwrapped labels the colorpicker/keybind addons, so wrap
        -- (multi-line) only for long plain-text labels.
        return wrapElement(group:AddLabel(info.Name, #info.Name > 28))
    end

    function wrapped:Button(info)
        bump()
        group:AddButton(info.Name, info.Callback)
    end

    -- text box; the value is always current (Options[flag].Value), no Enter needed
    function wrapped:Input(info)
        bump()
        group:AddInput(info.Flag, {
            Text = info.Name,
            Default = info.Default or "",
            Placeholder = info.Placeholder or "",
            Finished = false,
            Callback = info.Callback,
        })
    end

    -- Player picker: Linoria builds and refreshes the player list itself.
    function wrapped:Listbox(info)
        bump()
        group:AddDropdown(info.Flag, { Text = "Player", SpecialType = "Player", AllowNull = true })
    end

    return wrapped
end

local function wrapPage(tab)
    local page = { load = { 0, 0 } }
    local function pickSide(side)
        if side == 1 or side == 2 then return side end
        return page.load[1] <= page.load[2] and 1 or 2   -- third column: use the emptier side
    end

    function page:Section(info)
        local side = pickSide(info.Side)
        local group = side == 1 and tab:AddLeftGroupbox(info.Name) or tab:AddRightGroupbox(info.Name)
        return wrapGroup(group, page, side)
    end

    function page:MultiSection(info)
        local side = pickSide(info.Side)
        local box = side == 1 and tab:AddLeftTabbox() or tab:AddRightTabbox()
        local sections = {}
        for index, name in ipairs(info.Sections) do
            sections[index] = wrapGroup(box:AddTab(name), page, side)
        end
        return table.unpack(sections)
    end

    return page
end

local Window = {}
function Window:Page(info)
    if info.Subtabs then
        local container = {}
        function container:SubPage(sub) return wrapPage(LinoriaWindow:AddTab(sub.Name)) end
        return container
    end
    return wrapPage(LinoriaWindow:AddTab(info.Name))
end

-- Pages ---------------------------------------------------------------
local CombatTab   = Window:Page({ Name = "Combat",  Columns = 2, Subtabs = false })
local VisualsPage = Window:Page({ Name = "Visuals", Columns = 2, Subtabs = false })
local WorldPage   = Window:Page({ Name = "World",   Columns = 2, Subtabs = false })

local PlayersPage  = Window:Page({ Name = "Players", Columns = 2, Subtabs = false })
local SpooferPage  = Window:Page({ Name = "Spoofer", Columns = 2, Subtabs = false })
local MiscPage     = Window:Page({ Name = "Misc",    Columns = 2, Subtabs = false })
local MiscActions  = { clearCheats = noop }
local TeleportPage = Window:Page({ Name = "Teleport", Columns = 2, Subtabs = false })
local ShotEvents = { shot = {}, hit = {}, cast = {} } -- listeners: shot(origin, target), hit(player, position), cast(part, position)
local Actions = {
    previewHitEffect = noop, getWeapon = noop, getAllWeapons = noop, getItem = noop, getPlace = noop,
    kickOnce = noop, fxHook = noop, autoHook = noop, fireAt = function() return false end,
    sp = { assist = {}, shooter = function(root) return root.Position end, realPos = function(root) return root.Position end },
    area = function() return "outside" end,
}

local WHITE = Color3.fromRGB(255, 255, 255)
local BLACK = Color3.fromRGB(0, 0, 0)

-- Combat
do
-- Combat
do
    -- Aim assist (camera or mouse) ------------------------------------------------------
    local Aim = CombatTab:Section({ Name = "Aim assist", Side = 1 })
    local aimEnabled = Aim:Toggle({ Name = "Enabled", Flag = "Aim_Global_Enabled", Default = false })
    aimEnabled:Keybind({ Name = "Aim key", Flag = "Aim_Global_Key", Default = "MB2", Mode = "Hold" })
    Aim:Dropdown({ Name = "Method", Flag = "aim_method", Items = { "Camera", "Mouse" }, Default = "Camera" })
    Aim:Slider({ Name = "FOV", Flag = "aim_fov", Min = 10, Max = 800, Default = 120, Suffix = "px", Decimals = 1 })
    Aim:Toggle({ Name = "Dynamic FOV", Flag = "aim_dynamic", Default = false })
    Aim:Slider({ Name = "Dynamic FOV amount", Flag = "aim_dynamic_amount", Min = 0, Max = 100, Default = 50, Suffix = "%", Decimals = 1 })
    Aim:Toggle({ Name = "Lock target", Flag = "aim_lock", Default = false })
    Aim:Dropdown({ Name = "Hitscan priority", Flag = "aim_priority", Items = { "Closest", "Head", "Body" }, Default = "Closest" })
    Aim:Dropdown({ Name = "Hitscan points", Flag = "aim_points", Items = { "Head", "Body" }, Multi = true, Default = { "Head", "Body" } })
    Aim:Slider({ Name = "Reaction time", Flag = "aim_reaction", Min = 0, Max = 500, Default = 0, Suffix = "ms", Decimals = 1 })
    Aim:Slider({ Name = "Max distance", Flag = "aim_max_dist", Min = 50, Max = 2000, Default = 1000, Suffix = " studs", Decimals = 1 })
    Aim:Toggle({ Name = "Team check", Flag = "aim_team", Default = false })
    Aim:Toggle({ Name = "Wall check", Flag = "aim_wall", Default = false })
    Aim:Toggle({ Name = "Forcefield check", Flag = "aim_ff", Default = false })
    Aim:Toggle({ Name = "Hostile only (inmates)", Flag = "aim_hostile", Default = false })
    Aim:Toggle({ Name = "Ignore tased / arrested", Flag = "aim_ignore_down", Default = false })

    local Smooth = CombatTab:Section({ Name = "Aim smoothing", Side = 1 })
    Smooth:Toggle({ Name = "Smoothing", Flag = "aim_smooth", Default = true })
    Smooth:Slider({ Name = "Start", Flag = "aim_smooth_start", Min = 0, Max = 99, Default = 85, Suffix = "%", Decimals = 1 })
    Smooth:Slider({ Name = "End", Flag = "aim_smooth_end", Min = 0, Max = 99, Default = 20, Suffix = "%", Decimals = 1 })
    Smooth:Slider({ Name = "Increment", Flag = "aim_smooth_inc", Min = 0, Max = 200, Default = 50, Suffix = "%/s", Decimals = 1 })
    Smooth:Slider({ Name = "Randomization", Flag = "aim_smooth_rand", Min = 0, Max = 50, Default = 5, Suffix = "%", Decimals = 1 })

    local Trigger = CombatTab:Section({ Name = "Triggerbot", Side = 1 })
    local triggerEnabled = Trigger:Toggle({ Name = "Enabled", Flag = "Trigger_Global_Enabled", Default = false })
    triggerEnabled:Keybind({ Name = "Trigger key", Flag = "Trigger_Global_Key", Default = "None", Mode = "Always" })
    Trigger:Dropdown({ Name = "Hit part", Flag = "Trigger_Global_HitPart", Items = { "Head", "Torso", "Any" }, Default = "Head" })
    Trigger:Slider({ Name = "Delay", Flag = "Trigger_Global_Delay", Min = 0, Max = 300, Default = 40, Suffix = "ms", Decimals = 1 })
    Trigger:Slider({ Name = "Reaction time", Flag = "Trigger_Global_Reaction", Min = 0, Max = 200, Default = 0, Suffix = "ms", Decimals = 1 })
    Trigger:Toggle({ Name = "Team check", Flag = "trigger_team", Default = false })
    Trigger:Toggle({ Name = "Forcefield check", Flag = "trigger_ff", Default = false })
    Trigger:Toggle({ Name = "Hostile only (inmates)", Flag = "trigger_hostile", Default = false })

    local Wall = CombatTab:Section({ Name = "Wallbang", Side = 1 })
    Wall:Toggle({ Name = "Wallbang", Flag = "silent_wallbang", Default = false })
    Wall:Dropdown({
        Name = "Method", Flag = "wb_method", Items = { "Vape V4", "awp", "awp v2", "awp v2.1" }, Default = "awp v2",
        Tooltip = "Vape V4: Vape's origin scan, works best when you stand near a wall.\nawp: scans more origins around you and tries the closest ones first (a bit better than Vape V4).\nawp v2: reaches through more walls (origins up to twice the scan radius) but can be inaccurate sometimes.\nawp v2.1: works out origins along the line to the target, closest first, and only widens the search when it has to.",
    })
    Wall:Toggle({ Name = "Use hitbox", Flag = "wb_hitbox", Default = true, Tooltip = "Also aim at points beside the target's body, not only at the part itself" })
    Wall:Slider({ Name = "Scan radius", Flag = "wb_radius", Min = 1, Max = 10, Default = 6, Suffix = " studs", Decimals = 0.1 })

    local Assist = CombatTab:Section({ Name = "Wallbang assist", Side = 1 })
    local assistToggle = Assist:Toggle({ Name = "Wallbang assist", Flag = "wb_assist", Default = false, Tooltip = "Moves the position the server sees up to (or into) the wall in front of your silent aim target, so the wallbang has a better origin. Needs silent aim and wallbang." })
    assistToggle:Keybind({ Name = "Assist key", Flag = "wb_assist_key", Default = "None", Sync = true })
    Assist:Dropdown({ Name = "Mode", Flag = "wb_assist_mode", Items = { "Tween", "Teleport" }, Default = "Tween" })
    Assist:Toggle({ Name = "Inside wall", Flag = "wb_assist_inside", Default = false })
    Assist:Slider({ Name = "Activation distance", Flag = "wb_assist_dist", Min = 1, Max = 45, Default = 25, Suffix = " studs", Decimals = 1 })
    Assist:Slider({ Name = "Tween speed", Flag = "wb_assist_speed", Min = 1, Max = 200, Default = 50, Suffix = " studs/s", Decimals = 1 })
    Assist:Slider({ Name = "Max target distance", Flag = "wb_assist_max", Min = 10, Max = 5000, Default = 200, Suffix = " studs", Decimals = 1 })
    local assistVisual = Assist:Toggle({ Name = "Visualizer", Flag = "wb_assist_visual", Default = false, Tooltip = "A highlighted copy of your character shows where the server sees you" })
    assistVisual:Colorpicker({ Name = "Fill", Flag = "wb_assist_fill", Default = Color3.fromRGB(255, 255, 255), Alpha = 0.6 })
    assistVisual:Colorpicker({ Name = "Outline", Flag = "wb_assist_line", Default = Color3.fromRGB(255, 255, 255), Alpha = 0 })

    -- Silent aim ---------------------------------------------------------------------------
    local Silent = CombatTab:Section({ Name = "Silent aim", Side = 2 })
    local silentEnabled = Silent:Toggle({ Name = "Enabled", Flag = "Silent_Global_Enabled", Default = false })
    silentEnabled:Keybind({ Name = "Silent key", Flag = "Silent_Global_Key", Default = "None", Mode = "Always" })
    Silent:Slider({ Name = "FOV", Flag = "silent_fov", Min = 10, Max = 800, Default = 150, Suffix = "px", Decimals = 1 })
    Silent:Toggle({ Name = "Dynamic FOV", Flag = "silent_dynamic", Default = false })
    Silent:Slider({ Name = "Dynamic FOV amount", Flag = "silent_dynamic_amount", Min = 0, Max = 100, Default = 50, Suffix = "%", Decimals = 1 })
    Silent:Dropdown({ Name = "Hitscan priority", Flag = "silent_priority", Items = { "Closest", "Head", "Body" }, Default = "Head" })
    Silent:Dropdown({ Name = "Hitscan points", Flag = "silent_points", Items = { "Head", "Body" }, Multi = true, Default = { "Head", "Body" } })
    Silent:Slider({ Name = "Hit chance", Flag = "Silent_Global_HitChance", Min = 1, Max = 100, Default = 100, Suffix = "%", Decimals = 1 })
    Silent:Slider({ Name = "Max distance", Flag = "silent_max_dist", Min = 50, Max = 2000, Default = 1000, Suffix = " studs", Decimals = 1 })
    Silent:Toggle({ Name = "Wall check", Flag = "silent_wall", Default = false })
    Silent:Toggle({ Name = "Forcefield check", Flag = "silent_ff", Default = false })
    Silent:Toggle({ Name = "Hostile only (inmates)", Flag = "silent_hostile", Default = false })
    Silent:Toggle({ Name = "Team check", Flag = "silent_team", Default = false })
    Silent:Toggle({ Name = "Ignore tased / arrested", Flag = "silent_ignore_down", Default = false })
    Silent:Toggle({ Name = "Auto fire", Flag = "silent_autofire", Default = false })
    Silent:Slider({ Name = "Auto fire rate", Flag = "silent_autofire_rate", Min = 1, Max = 60, Default = 15, Suffix = " hz", Decimals = 1 })

    -- FOV circles (one per assist) ---------------------------------------------------------
    local FovAim, FovSilent = CombatTab:MultiSection({ Sections = { "Aim FOV", "Silent FOV" }, Side = 2 })
    local aimCircle = FovAim:Toggle({ Name = "Show FOV circle", Flag = "aim_fov_show", Default = false })
    aimCircle:Colorpicker({ Name = "Color", Flag = "aim_fov_color", Default = Color3.new(1, 1, 1), Alpha = true })
    FovAim:Toggle({ Name = "Filled", Flag = "aim_fov_filled", Default = false })
    FovAim:Slider({ Name = "Thickness", Flag = "aim_fov_thick", Min = 1, Max = 5, Default = 1, Decimals = 1 })
    local silentCircle = FovSilent:Toggle({ Name = "Show FOV circle", Flag = "silent_fov_show", Default = false })
    silentCircle:Colorpicker({ Name = "Color", Flag = "silent_fov_color", Default = Color3.fromRGB(255, 120, 120), Alpha = true })
    FovSilent:Toggle({ Name = "Filled", Flag = "silent_fov_filled", Default = false })
    FovSilent:Slider({ Name = "Thickness", Flag = "silent_fov_thick", Min = 1, Max = 5, Default = 1, Decimals = 1 })

    local GunMods = CombatTab:Section({ Name = "Gun mods", Side = 2 })
    GunMods:Toggle({ Name = "Gun modifications", Flag = "gun_mods", Default = false })
    GunMods:Slider({ Name = "Fire delay (% of stock)", Flag = "gun_fire_rate", Min = 1, Max = 100, Default = 100, Suffix = "%", Decimals = 1 })
    GunMods:Toggle({ Name = "No spread", Flag = "gun_no_spread", Default = false })
    GunMods:Toggle({ Name = "Full automatic", Flag = "gun_full_auto", Default = false })
    GunMods:Toggle({ Name = "Custom range", Flag = "gun_range_on", Default = false })
    GunMods:Slider({ Name = "Range", Flag = "gun_range", Min = 10, Max = 100000, Default = 1000, Suffix = " studs", Decimals = 1 })
    local Hits = CombatTab:Section({ Name = "Hit feedback", Side = 2 })
    Hits:Toggle({ Name = "Hit notifications", Flag = "World_HitNotify", Default = false })
    Hits:Toggle({ Name = "Hit sounds", Flag = "World_HitSound", Default = false })
    Hits:Dropdown({ Name = "Hit sound", Flag = "World_HitSoundId", Items = HIT_SOUND_NAMES, Default = "Gamesense" })
    Hits:Slider({ Name = "Hit volume", Flag = "World_HitVolume", Min = 0, Max = 5, Default = 1, Decimals = 0.01 })
    Hits:Button({ Name = "Preview sound", Callback = function() if playHitSound then playHitSound() end end })
    Hits:Toggle({ Name = "Bullet impacts", Flag = "World_Impacts", Default = false })
    local Utility = CombatTab:Section({ Name = "Weapon utility", Side = 2 })
    Utility:Toggle({ Name = "Auto reload", Flag = "gun_auto_reload", Default = false })
    Utility:Toggle({ Name = "Auto swap on empty", Flag = "gun_auto_swap", Default = false })
    Utility:Toggle({ Name = "Shoot through vehicles", Flag = "gun_vehicle_wallbang", Default = false })
end


end

-- Misc ----------------------------------------------------------------------------------
do
    -- Movement: two tabboxes keep the six movement modules compact
    local fly, speed, spider = MiscPage:MultiSection({ Sections = { "Fly", "Speed", "Spider" }, Side = 1 })
    fly:Toggle({ Name = "Fly", Flag = "misc_fly", Default = false }):Keybind({ Name = "Fly key", Flag = "misc_fly_key", Default = "None", Sync = true })
    fly:Dropdown({ Name = "Mode", Flag = "misc_fly_mode", Items = { "Velocity", "CFrame" }, Default = "Velocity" })
    fly:Slider({ Name = "Speed", Flag = "misc_fly_speed", Min = 1, Max = 150, Default = 50, Suffix = " studs", Decimals = 1 })
    fly:Slider({ Name = "Vertical speed", Flag = "misc_fly_vspeed", Min = 1, Max = 100, Default = 40, Suffix = " studs", Decimals = 1 })
    fly:Toggle({ Name = "Height cap (49.9)", Flag = "misc_fly_cap", Default = true })
    fly:Label({ Name = "Up: Space   Down: Left Ctrl" })
    speed:Toggle({ Name = "Speed", Flag = "misc_speed", Default = false }):Keybind({ Name = "Speed key", Flag = "misc_speed_key", Default = "None", Sync = true })
    speed:Dropdown({ Name = "Mode", Flag = "misc_speed_mode", Items = { "Velocity", "CFrame", "WalkSpeed" }, Default = "Velocity" })
    speed:Slider({ Name = "Speed", Flag = "misc_speed_value", Min = 1, Max = 150, Default = 50, Suffix = " studs", Decimals = 1 })
    spider:Toggle({ Name = "Spider", Flag = "misc_spider", Default = false }):Keybind({ Name = "Spider key", Flag = "misc_spider_key", Default = "None", Sync = true })
    spider:Dropdown({ Name = "Mode", Flag = "misc_spider_mode", Items = { "Velocity", "Impulse", "CFrame" }, Default = "Velocity" })
    spider:Slider({ Name = "Climb speed", Flag = "misc_spider_speed", Min = 1, Max = 100, Default = 30, Suffix = " studs", Decimals = 1 })
    spider:Toggle({ Name = "Climb state", Flag = "misc_spider_state", Default = false })

    local high, long, phase = MiscPage:MultiSection({ Sections = { "High jump", "Long jump", "Phase" }, Side = 1 })
    high:Toggle({ Name = "High jump", Flag = "misc_highjump", Default = false }):Keybind({ Name = "High jump key", Flag = "misc_highjump_key", Default = "None", Sync = true })
    high:Dropdown({ Name = "Mode", Flag = "misc_highjump_mode", Items = { "Velocity", "Impulse", "Instant" }, Default = "Velocity" })
    high:Slider({ Name = "Power", Flag = "misc_highjump_power", Min = 1, Max = 150, Default = 50, Suffix = " studs", Decimals = 1 })
    high:Toggle({ Name = "Auto disable (one jump)", Flag = "misc_highjump_auto", Default = true })
    long:Toggle({ Name = "Long jump", Flag = "misc_longjump", Default = false }):Keybind({ Name = "Long jump key", Flag = "misc_longjump_key", Default = "None", Sync = true })
    long:Dropdown({ Name = "Mode", Flag = "misc_longjump_mode", Items = { "Velocity", "Impulse", "CFrame" }, Default = "Velocity" })
    long:Slider({ Name = "Speed", Flag = "misc_longjump_speed", Min = 1, Max = 150, Default = 50, Suffix = " studs", Decimals = 1 })
    long:Toggle({ Name = "Auto disable on landing", Flag = "misc_longjump_auto", Default = true })
    phase:Toggle({ Name = "Phase", Flag = "misc_phase", Default = false }):Keybind({ Name = "Phase key", Flag = "misc_phase_key", Default = "None", Sync = true })
    phase:Dropdown({ Name = "Mode", Flag = "misc_phase_mode", Items = { "Part", "Character", "CFrame" }, Default = "Part" })
    phase:Slider({ Name = "Wall size (CFrame)", Flag = "misc_phase_size", Min = 1, Max = 20, Default = 5, Suffix = " studs", Decimals = 1 })
    phase:Label({ Name = "Hold Shift to Phase while Spider is on" })
    phase:Toggle({ Name = "Disabler (fixes Character mode)", Flag = "misc_disabler", Default = false })

    local Character = MiscPage:Section({ Name = "Character", Side = 1 })
    Character:Toggle({ Name = "No jump cooldown", Flag = "misc_no_jump_cd", Default = false })
    Character:Toggle({ Name = "Camera phase", Flag = "misc_camera_phase", Default = false })
    Character:Toggle({ Name = "Gravity", Flag = "misc_gravity", Default = false })
    Character:Dropdown({ Name = "Gravity mode", Flag = "misc_gravity_mode", Items = { "Workspace", "Local" }, Default = "Workspace" })
    Character:Slider({ Name = "Gravity value", Flag = "misc_gravity_value", Min = 0, Max = 300, Default = 196, Decimals = 1 })

    local World = MiscPage:Section({ Name = "Xray", Side = 1 })
    World:Toggle({ Name = "Xray", Flag = "misc_xray", Default = false })
    World:Slider({ Name = "Part transparency", Flag = "misc_xray_alpha", Min = 0, Max = 1, Default = 0.5, Decimals = 0.01 })
    World:Input({ Name = "Keep opaque (names)", Flag = "misc_xray_ignore", Default = "", Placeholder = "Door, Fence" })

    local Melee = MiscPage:Section({ Name = "Melee aura", Side = 2 })
    Melee:Toggle({ Name = "Melee aura", Flag = "misc_melee", Default = false })
    Melee:Slider({ Name = "Range", Flag = "misc_melee_range", Min = 1, Max = 15, Default = 15, Suffix = " studs", Decimals = 1 })
    Melee:Slider({ Name = "Delay", Flag = "misc_melee_delay", Min = 0.1, Max = 1, Default = 0.5, Suffix = "s", Decimals = 0.05 })
    Melee:Toggle({ Name = "Skip friendly players", Flag = "misc_melee_friendly", Default = true })
    Melee:Toggle({ Name = "Skip forcefield", Flag = "misc_melee_ff", Default = true })

    local arrest, taze = MiscPage:MultiSection({ Sections = { "Auto arrest", "Auto taze" }, Side = 2 })
    arrest:Toggle({ Name = "Auto arrest", Flag = "misc_autoarrest", Default = false })
    arrest:Slider({ Name = "Range", Flag = "misc_arrest_range", Min = 1, Max = 7.5, Default = 7.5, Suffix = " studs", Decimals = 0.5 })
    arrest:Toggle({ Name = "Equip handcuffs", Flag = "misc_arrest_hand", Default = true })
    arrest:Toggle({ Name = "Arrest inmates", Flag = "misc_arrest_inmates", Default = true })
    arrest:Toggle({ Name = "Arrest criminals", Flag = "misc_arrest_criminals", Default = true })
    arrest:Toggle({ Name = "Notify on arrest", Flag = "misc_arrest_notify", Default = false })
    taze:Toggle({ Name = "Auto taze", Flag = "misc_autotaze", Default = false })
    taze:Slider({ Name = "Range", Flag = "misc_taze_range", Min = 1, Max = 52, Default = 52, Suffix = " studs", Decimals = 1 })
    taze:Toggle({ Name = "Velocity check", Flag = "misc_taze_velocity", Default = true })

    local Protect = MiscPage:Section({ Name = "Protection", Side = 2 })
    Protect:Toggle({ Name = "Anti taze", Flag = "misc_anti_taze", Default = false })
    Protect:Toggle({ Name = "Anti fling", Flag = "misc_anti_fling", Default = false })
    Protect:Toggle({ Name = "Destroy body on death", Flag = "misc_destroy_body", Default = false })
    Protect:Toggle({ Name = "Anti riot shield", Flag = "misc_anti_riot", Default = false })
    Protect:Toggle({ Name = "Anti kill plane", Flag = "misc_anti_killplane", Default = false })
    Protect:Toggle({ Name = "Anti invisible", Flag = "misc_anti_invis", Default = false })

    local Detect = MiscPage:Section({ Name = "Cheat detector", Side = 2 })
    Detect:Toggle({ Name = "Cheat detector", Flag = "misc_cheat_detector", Default = false })
    Detect:Toggle({ Name = "Teleport check", Flag = "misc_cheat_teleport", Default = true })
    Detect:Button({ Name = "Clear flags", Callback = function() MiscActions.clearCheats() end })

    local Fling = MiscPage:Section({ Name = "Fling cars", Side = 2 })
    Fling:Toggle({ Name = "Fling cars", Flag = "misc_fling_cars", Default = false })
    Fling:Slider({ Name = "Target range", Flag = "misc_fling_range", Min = 20, Max = 1000, Default = 300, Suffix = " studs", Decimals = 1 })

    local Invis = MiscPage:Section({ Name = "Invisibility", Side = 2 })
    local invisToggle = Invis:Toggle({ Name = "Invisibility", Flag = "misc_invis", Default = false })
    invisToggle:Keybind({ Name = "Invisibility key", Flag = "misc_invis_key", Default = "None", Sync = true })
    Invis:Toggle({ Name = "Hide under the map (look up)", Flag = "misc_invis_under", Default = true })
    Invis:Toggle({ Name = "Move while hidden", Flag = "misc_invis_move", Default = false })
    Invis:Slider({ Name = "Look-up pitch", Flag = "misc_invis_pitch", Min = -90, Max = 90, Default = 90, Suffix = "°", Decimals = 1 })

    local Desync = MiscPage:Section({ Name = "Desync", Side = 2 })
    Desync:Toggle({ Name = "Desync", Flag = "misc_desync", Default = false, Tooltip = "The server sees you at another position than the one you play at" }):Keybind({ Name = "Desync key", Flag = "misc_desync_key", Default = "None", Sync = true })
    Desync:Dropdown({
        Name = "Style", Flag = "misc_desync_style", Items = { "Offset", "Void" }, Default = "Offset",
        Tooltip = "Offset: the server position sits a fixed height below (or above) you.\nVoid: the server position is far below the map, just above the point where parts are destroyed.",
    })
    Desync:Slider({ Name = "Y offset", Flag = "misc_desync_y", Min = -10, Max = 10, Default = -2.5, Suffix = " studs", Decimals = 0.1 })
    Desync:Toggle({ Name = "Always underground", Flag = "misc_desync_under", Default = false, Tooltip = "Keeps the server position below the floor, also while you jump" })
    Desync:Toggle({ Name = "Filter structures", Flag = "misc_desync_filter", Default = false, Tooltip = "Looks for the lowest floor under you instead of the first surface (tables, roofs)" })
    Desync:Slider({ Name = "Follower speed", Flag = "misc_desync_speed", Min = 1, Max = 500, Default = 30, Suffix = " studs/s", Decimals = 1 })
    local desyncVisual = Desync:Toggle({ Name = "Visualizer", Flag = "misc_desync_visual", Default = false, Tooltip = "A highlighted copy of your character shows where the server sees you" })
    desyncVisual:Colorpicker({ Name = "Fill", Flag = "misc_desync_fill", Default = Color3.fromRGB(255, 255, 255), Alpha = 0.6 })
    desyncVisual:Colorpicker({ Name = "Outline", Flag = "misc_desync_line", Default = Color3.fromRGB(255, 255, 255), Alpha = 0 })
    local desyncTracer = Desync:Toggle({ Name = "Tracer", Flag = "misc_desync_tracer", Default = false })
    desyncTracer:Colorpicker({ Name = "Tracer color", Flag = "misc_desync_tracer_color", Default = Color3.fromRGB(255, 255, 255), Alpha = 0 })

    local Walk = MiscPage:Section({ Name = "Walk speed", Side = 1 })
    Walk:Toggle({ Name = "Walk speed", Flag = "misc_walk", Default = false }):Keybind({ Name = "Walk speed key", Flag = "misc_walk_key", Default = "None", Sync = true })
    Walk:Slider({ Name = "Walk speed", Flag = "misc_walk_value", Min = 16, Max = 200, Default = 16, Suffix = " studs/s", Decimals = 1 })
    Walk:Toggle({ Name = "No acceleration", Flag = "misc_noaccel", Default = false, Tooltip = "Start and stop at full speed instead of speeding up and sliding" }):Keybind({ Name = "No acceleration key", Flag = "misc_noaccel_key", Default = "None", Sync = true })
    Walk:Toggle({ Name = "Automatic speed", Flag = "misc_walk_auto", Default = false, Tooltip = "Picks the speed from where you are: inside a building of the prison, in the prison area, or outside the prison" })
    Walk:Toggle({ Name = "Use custom speed", Flag = "misc_walk_custom", Default = false, Tooltip = "Use the three sliders below. When off, automatic speed uses 32 / 50 / 100." })
    Walk:Slider({ Name = "Speed inside prison", Flag = "misc_walk_in", Min = 16, Max = 32, Default = 32, Suffix = " studs/s", Decimals = 1 })
    Walk:Slider({ Name = "Speed in prison area", Flag = "misc_walk_yard", Min = 16, Max = 100, Default = 50, Suffix = " studs/s", Decimals = 1 })
    Walk:Slider({ Name = "Speed outside prison", Flag = "misc_walk_out", Min = 16, Max = 100, Default = 100, Suffix = " studs/s", Decimals = 1 })
    Walk:Toggle({ Name = "Notify area changes", Flag = "misc_walk_notify", Default = false, Tooltip = "Shows which area the script thinks you are in" })

    local Move = MiscPage:Section({ Name = "Movement", Side = 1 })
    Move:Toggle({ Name = "Jump multiplier", Flag = "misc_jumpmult", Default = false }):Keybind({ Name = "Jump multiplier key", Flag = "misc_jumpmult_key", Default = "None", Sync = true })
    Move:Slider({ Name = "Jump multiplier (max 3x)", Flag = "misc_jumpmult_value", Min = 1, Max = 3, Default = 1.5, Suffix = "x", Decimals = 0.05 })
    Move:Toggle({ Name = "Spinbot", Flag = "misc_spinbot", Default = false }):Keybind({ Name = "Spinbot key", Flag = "misc_spinbot_key", Default = "None", Sync = true })
    Move:Slider({ Name = "Spin speed", Flag = "misc_spinbot_speed", Min = 1, Max = 40, Default = 10, Decimals = 1 })
    Move:Toggle({ Name = "Infinite jump", Flag = "misc_infjump", Default = false }):Keybind({ Name = "Infinite jump key", Flag = "misc_infjump_key", Default = "None", Sync = true })
    Move:Toggle({ Name = "Click teleport", Flag = "misc_clicktp", Default = false }):Keybind({ Name = "Click teleport key", Flag = "misc_clicktp_key", Default = "None", Sync = true })
    Move:Toggle({ Name = "Hold Left Ctrl to teleport", Flag = "misc_clicktp_ctrl", Default = true })
    Move:Slider({ Name = "Click teleport range", Flag = "misc_clicktp_range", Min = 10, Max = 2000, Default = 500, Suffix = " studs", Decimals = 1 })

    local vFly, vSpeed = MiscPage:MultiSection({ Sections = { "Vehicle fly", "Vehicle speed" }, Side = 1 })
    vFly:Toggle({ Name = "Vehicle fly", Flag = "misc_vfly", Default = false }):Keybind({ Name = "Vehicle fly key", Flag = "misc_vfly_key", Default = "None", Sync = true })
    vFly:Slider({ Name = "Speed", Flag = "misc_vfly_speed", Min = 1, Max = 100, Default = 60, Suffix = " studs", Decimals = 1 })
    vFly:Toggle({ Name = "Move along camera", Flag = "misc_vfly_camera", Default = true })
    vFly:Toggle({ Name = "Height cap (49.9)", Flag = "misc_vfly_cap", Default = true })
    vFly:Label({ Name = "Up: E   Down: Q" })
    vSpeed:Toggle({ Name = "Vehicle speed", Flag = "misc_vspeed", Default = false }):Keybind({ Name = "Vehicle speed key", Flag = "misc_vspeed_key", Default = "None", Sync = true })
    vSpeed:Slider({ Name = "Max speed", Flag = "misc_vspeed_value", Min = 80, Max = 200, Default = 140, Decimals = 1 })
end


-- Teleport -------------------------------------------------------------------------------
do
    local Guns = TeleportPage:Section({ Name = "Get guns", Side = 1 })
    Guns:Dropdown({ Name = "Weapon", Flag = "tp_weapon", Items = { "AK-47", "Remington 870", "MP5", "M700", "M4A1", "FAL", "Revolver" }, Default = "AK-47" })
    Guns:Button({ Name = "Get weapon", Callback = function() Actions.getWeapon(readFlag("tp_weapon", "AK-47")) end })
    Guns:Button({ Name = "Get all weapons", Callback = function() Actions.getAllWeapons() end })

    local Settings = TeleportPage:Section({ Name = "Teleport settings", Side = 1 })
    Settings:Toggle({ Name = "Return after pickup", Flag = "tp_return", Default = true })
    Settings:Slider({ Name = "Time at pickup", Flag = "tp_time", Min = 0.6, Max = 2, Default = 0.8, Suffix = "s", Decimals = 0.1 })

    local Items = TeleportPage:Section({ Name = "Get items", Side = 2 })
    Items:Dropdown({ Name = "Item", Flag = "tp_item", Items = { "Key card", "Breakfast", "Lunch", "Dinner", "Soda", "Chips", "Chocolate" }, Default = "Key card" })
    Items:Button({ Name = "Get item", Callback = function() Actions.getItem(readFlag("tp_item", "Key card")) end })

    local Places = TeleportPage:Section({ Name = "Teleport places", Side = 2 })
    Places:Dropdown({ Name = "Location", Flag = "tp_place", Items = { "Yard", "Academy", "Prison", "Armory", "Cafeteria", "Kitchen", "Police car spawner", "Top of the city building" }, Default = "Yard" })
    Places:Button({ Name = "Teleport", Callback = function() Actions.getPlace(readFlag("tp_place", "Yard")) end })
end

-- Visuals (ESP and chams) and World (world, camera, gun, body and self visuals)
do
    ---------------- left column ----------------
    -- ESP list (toggles with their color swatches)
    local EspList = VisualsPage:MultiSection({ Sections = { "Players" }, Side = 1 })
    EspList:Toggle({ Name = "Enabled", Flag = "esp_enabled", Default = false })
    EspList:Toggle({ Name = "Name", Flag = "esp_name", Default = false }):Colorpicker({ Name = "Color", Flag = "esp_name_color1", Default = WHITE })
    EspList:Toggle({ Name = "Boxes", Flag = "esp_box", Default = false }):Colorpicker({ Name = "Color", Flag = "esp_box_color", Default = WHITE })
    EspList:Toggle({ Name = "Outline", Flag = "esp_outline_enabled", Default = false }):Colorpicker({ Name = "Color", Flag = "esp_outline_color", Default = BLACK })
    EspList:Toggle({ Name = "Fill", Flag = "esp_fill", Default = false }):Colorpicker({ Name = "Color", Flag = "esp_fill_color", Default = WHITE, Alpha = 0.9 })
    EspList:Toggle({ Name = "Glow", Flag = "esp_glow", Default = false }):Colorpicker({ Name = "Color", Flag = "esp_glow_color", Default = WHITE, Alpha = 0.72 })
    local hp = EspList:Toggle({ Name = "Health bar", Flag = "esp_healthbar", Default = false })
    hp:Colorpicker({ Name = "Full HP", Flag = "esp_healthbar_color_start", Default = Color3.fromRGB(0, 255, 0) })
    hp:Colorpicker({ Name = "Mid HP", Flag = "esp_healthbar_color_middle", Default = Color3.fromRGB(255, 255, 0) })
    hp:Colorpicker({ Name = "Low HP", Flag = "esp_healthbar_color_end", Default = Color3.fromRGB(255, 0, 0) })
    EspList:Toggle({ Name = "Distance", Flag = "esp_distance", Default = false }):Colorpicker({ Name = "Color", Flag = "esp_distance_color", Default = WHITE })
    EspList:Toggle({ Name = "Weapon", Flag = "esp_weapon", Default = false }):Colorpicker({ Name = "Color", Flag = "esp_weapon_color", Default = WHITE })
    EspList:Toggle({ Name = "Skeleton", Flag = "esp_skeleton", Default = false }):Colorpicker({ Name = "Color", Flag = "esp_skeleton_color", Default = WHITE })
    EspList:Toggle({ Name = "Arrows", Flag = "esp_arrows", Default = false }):Colorpicker({ Name = "Color", Flag = "esp_arrow_color", Default = WHITE })
    EspList:Toggle({ Name = "Team indicator", Flag = "esp_team_indicator", Default = false }):Colorpicker({ Name = "Color", Flag = "esp_team_color", Default = WHITE })
    EspList:Toggle({ Name = "Enemies only", Flag = "esp_enemies_only", Default = false })
    EspList:Toggle({ Name = "Hostile only (inmates)", Flag = "esp_hostile_only", Default = false })
    EspList:Toggle({ Name = "Team colors", Flag = "esp_use_team_color", Default = false })
EspList:Toggle({ Name = "Chams", Flag = "esp_chams", Default = false }):Colorpicker({ Name = "Visible", Flag = "esp_chams_adorn_vis_color", Default = Color3.fromRGB(59, 204, 90), Alpha = 0.35 }):Colorpicker({ Name = "Behind walls", Flag = "esp_chams_adorn_occ_color", Default = Color3.fromRGB(59, 144, 204), Alpha = 0.7 })

    -- ESP settings
    local SetGeneral, SetBox, SetHealth, SetArrows = VisualsPage:MultiSection({ Sections = { "General", "Box", "Health", "Arrows" }, Side = 2 })
    SetGeneral:Toggle({ Name = "Players", Flag = "esp_players", Default = true })
    SetGeneral:Toggle({ Name = "Local player", Flag = "esp_local_player", Default = false })
    SetGeneral:Slider({ Name = "Text size (all text)", Flag = "esp_text_size", Suffix = " px", Min = 8, Max = 24, Default = 12, Decimals = 1 })
    SetGeneral:Slider({ Name = "Thickness", Flag = "esp_skeleton_thickness", Suffix = " px", Min = 1, Max = 4, Default = 1.5, Decimals = 0.1 })
    SetBox:Dropdown({ Name = "Type", Flag = "esp_box_type", Items = { "Normal", "Corner", "Circle" }, Default = "Corner" })
    SetBox:Slider({ Name = "Thickness", Flag = "esp_box_thickness", Suffix = " px", Min = 1, Max = 5, Default = 1, Decimals = 0.1 })
    SetHealth:Dropdown({ Name = "Position", Flag = "esp_health_position", Items = { "Left", "Right", "Top", "Bottom" }, Default = "Left" })
    SetHealth:Slider({ Name = "Width", Flag = "esp_health_width", Suffix = " px", Min = 1, Max = 6, Default = 1, Decimals = 1 })
    SetArrows:Slider({ Name = "Size", Flag = "esp_arrow_size", Suffix = " px", Min = 8, Max = 32, Default = 14, Decimals = 1 })
    SetArrows:Slider({ Name = "Orbit radius", Flag = "esp_arrow_orbit", Suffix = " px", Min = 50, Max = 300, Default = 100, Decimals = 1 })

    -- Chams (adornment layers)
    local AdornLayers, AdornGlow = VisualsPage:MultiSection({ Sections = { "Layers", "Glow" }, Side = 2 })
    AdornLayers:Slider({ Name = "Visible thickness", Flag = "esp_chams_adorn_thickness", Min = 0, Max = 0.6, Default = 0.1, Decimals = 0.01 })
    AdornGlow:Toggle({ Name = "Glow", Flag = "esp_chams_adorn_glow", Default = false })
    AdornGlow:Slider({ Name = "Glow strength", Flag = "esp_chams_adorn_glow_size", Min = 1, Max = 2.5, Default = 1.75, Decimals = 0.01 })
    AdornGlow:Toggle({ Name = "Round head", Flag = "esp_chams_adorn_round_head", Default = true })
    AdornGlow:Slider({ Name = "Head size", Flag = "esp_chams_adorn_head_size", Min = 0.8, Max = 1.6, Default = 1.15, Decimals = 0.01 })

    -- Camera
    local CamFov = VisualsPage:Section({ Name = "Camera", Side = 1 })
CamFov:Toggle({ Name = "FOV changer", Flag = "camera_fov_changer", Default = false })
CamFov:Slider({ Name = "FOV", Flag = "camera_fov_changer_amount", Min = 40, Max = 140, Default = 100, Suffix = "°", Decimals = 1 })

    ---------------- right column ----------------
    -- World lighting
    local LightMain, LightTime, LightFog = WorldPage:MultiSection({ Sections = { "Light", "Time", "Fog" }, Side = 1 })
    LightMain:Toggle({ Name = "Ambient", Flag = "lighting_toggle_Ambient", Default = false }):Colorpicker({ Name = "Color", Flag = "lighting_colorAmbient", Default = WHITE })
    LightMain:Toggle({ Name = "Brightness", Flag = "lighting_toggle_Brightness", Default = false })
    LightMain:Slider({ Name = "Brightness value", Flag = "lighting_number_Brightness", Min = 0, Max = 5, Default = 1.7, Decimals = 0.01 })
    LightMain:Toggle({ Name = "Exposure", Flag = "lighting_toggle_ExposureCompensation", Default = false })
    LightMain:Slider({ Name = "Exposure value", Flag = "lighting_number_ExposureCompensation", Min = -5, Max = 5, Default = -1.1, Decimals = 0.01 })
    LightTime:Toggle({ Name = "Clock time", Flag = "lighting_toggle_ClockTime", Default = false })
    LightTime:Slider({ Name = "Clock time value", Flag = "lighting_number_ClockTime", Min = 0, Max = 24, Default = 9.2, Decimals = 0.01 })
    LightFog:Toggle({ Name = "Fog start", Flag = "lighting_toggle_FogStart", Default = false })
    LightFog:Slider({ Name = "Fog start value", Flag = "lighting_number_FogStart", Suffix = " stud(s)", Min = 0, Max = 5000, Default = 0, Decimals = 1 })
    LightFog:Toggle({ Name = "Fog end", Flag = "lighting_toggle_FogEnd", Default = false })
    LightFog:Slider({ Name = "Fog end value", Flag = "lighting_number_FogEnd", Suffix = " stud(s)", Min = 0, Max = 5000, Default = 2500, Decimals = 1 })
    LightFog:Toggle({ Name = "Fog color", Flag = "lighting_toggle_FogColor", Default = false }):Colorpicker({ Name = "Color", Flag = "lighting_colorFogColor", Default = WHITE })

    -- Sky, atmosphere and post effects
    local EnvSky, EnvAtmos, EnvBloom, EnvScreen = WorldPage:MultiSection({ Sections = { "Sky", "Atmos", "Bloom", "Screen" }, Side = 1 })
    EnvSky:Toggle({ Name = "Skybox", Flag = "skybox_enabled", Default = false })
    EnvSky:Dropdown({ Name = "Preset", Flag = "skybox_value", Items = SKYBOX_NAMES, Default = SKYBOX_NAMES[1] })
    EnvSky:Dropdown({ Name = "Hide parts", Flag = "skybox_disable", Items = { "stars", "sun", "moon" }, Multi = true, Default = { "stars", "sun", "moon" } })
    EnvAtmos:Toggle({ Name = "Atmosphere", Flag = "atmosphere_enabled", Default = false }):Colorpicker({ Name = "Color", Flag = "atmosphere_color", Default = WHITE })
    EnvAtmos:Slider({ Name = "Density", Flag = "atmosphere_density", Min = 0, Max = 1, Default = 0.3, Decimals = 0.01 })
    EnvAtmos:Label({ Name = "Decay color" }):Colorpicker({ Name = "Decay", Flag = "atmosphere_decay", Default = WHITE })
    EnvAtmos:Slider({ Name = "Glare", Flag = "atmosphere_glare", Min = 0, Max = 10, Default = 4.1, Decimals = 0.01 })
    EnvAtmos:Slider({ Name = "Haze", Flag = "atmosphere_haze", Min = 0, Max = 10, Default = 1, Decimals = 0.01 })
    EnvAtmos:Slider({ Name = "Offset", Flag = "atmosphere_offset", Min = -1, Max = 1, Default = 0.4, Decimals = 0.01 })
    EnvBloom:Toggle({ Name = "Bloom", Flag = "bloom_enabled", Default = false })
    EnvBloom:Slider({ Name = "Intensity", Flag = "bloom_intensity", Min = 0, Max = 3, Default = 0.4, Decimals = 0.01 })
    EnvBloom:Slider({ Name = "Size", Flag = "bloom_size", Min = 0, Max = 56, Default = 24, Decimals = 0.01 })
    EnvBloom:Slider({ Name = "Threshold", Flag = "bloom_threshold", Min = 0, Max = 2, Default = 0.95, Decimals = 0.01 })
    EnvScreen:Toggle({ Name = "Color correction", Flag = "color_correction_enabled", Default = false }):Colorpicker({ Name = "Tint", Flag = "color_correction_tint", Default = WHITE })
    EnvScreen:Slider({ Name = "Saturation", Flag = "color_correction_saturation", Min = -1, Max = 1, Default = 0, Decimals = 0.01 })
    EnvScreen:Slider({ Name = "Contrast", Flag = "color_correction_contrast", Min = -1, Max = 1, Default = 0, Decimals = 0.01 })
    EnvScreen:Slider({ Name = "Brightness", Flag = "color_correction_brightness", Min = -1, Max = 1, Default = 0, Decimals = 0.01 })
    EnvScreen:Toggle({ Name = "Sun rays", Flag = "sunrays_enabled", Default = false })
    EnvScreen:Slider({ Name = "Sun rays intensity", Flag = "sunrays_intensity", Min = 0, Max = 1, Default = 1, Decimals = 0.01 })
    EnvScreen:Slider({ Name = "Screen blur", Flag = "camera_blur", Min = 0, Max = 20, Default = 0, Decimals = 0.01 })

    -- Gun
    local GunLook, GunChams, GunTracerTab, GunTimingTab = VisualsPage:MultiSection({ Sections = { "Viewmodel", "Chams", "Tracers", "Timing" }, Side = 2 })
GunLook:Toggle({ Name = "Gun color", Flag = "viewmodel_body_color", Default = false }):Colorpicker({ Name = "Color", Flag = "viewmodel_body_color_value", Default = Color3.fromRGB(202, 161, 13), Alpha = true })
GunLook:Dropdown({ Name = "Material", Flag = "viewmodel_material_value", Items = { "Default", "ForceField", "Neon", "Glass", "SmoothPlastic", "Plastic" }, Default = "Default" })
GunLook:Dropdown({ Name = "Forcefield texture", Flag = "viewmodel_texture_value", Items = FORCEFIELD_TEXTURE_NAMES, Default = "Disabled" })
GunLook:Toggle({ Name = "Disable textures", Flag = "viewmodel_disable_textures", Default = false })
GunChams:Toggle({ Name = "Gun chams", Flag = "viewmodel_chams", Default = false }):Colorpicker({ Name = "Fill", Flag = "viewmodel_chams_color", Default = Color3.fromRGB(120, 80, 255), Alpha = 0.5 }):Colorpicker({ Name = "Outline", Flag = "viewmodel_chams_color2", Default = WHITE, Alpha = true })
GunTracerTab:Toggle({ Name = "Bullet tracers", Flag = "tracers_enabled", Default = false }):Colorpicker({ Name = "Color", Flag = "tracers_color", Default = WHITE })
GunTracerTab:Dropdown({ Name = "Style", Flag = "tracers_style", Items = TRACER_NAMES, Default = "Obelus" })
GunTracerTab:Slider({ Name = "Width", Flag = "tracers_width", Suffix = "x", Min = 0.3, Max = 3, Default = 1, Decimals = 0.1 })
GunTracerTab:Slider({ Name = "Glow", Flag = "tracers_glow", Min = 1, Max = 10, Default = 1, Decimals = 0.1 })
GunTimingTab:Slider({ Name = "Visible time", Flag = "tracers_duration", Suffix = "s", Min = 0.1, Max = 5, Default = 0.5, Decimals = 0.1 })
GunTimingTab:Slider({ Name = "Fade time", Flag = "tracers_fade", Suffix = "s", Min = 0, Max = 3, Default = 0.35, Decimals = 0.01 })
GunTimingTab:Toggle({ Name = "Expand from muzzle", Flag = "tracers_expand", Default = true })
GunTimingTab:Slider({ Name = "Expand speed", Flag = "tracers_expand_speed", Min = 4, Max = 40, Default = 18, Decimals = 1 })

    -- Body
    local BodyForce, BodyExtra = VisualsPage:MultiSection({ Sections = { "Arms", "Extras" }, Side = 2 })
BodyForce:Toggle({ Name = "Forcefield material", Flag = "arm_material", Default = false }):Colorpicker({ Name = "Color", Flag = "arm_material_color", Default = Color3.fromRGB(255, 255, 255), Alpha = true })
BodyForce:Dropdown({ Name = "Forcefield texture", Flag = "arm_material_texture", Items = FORCEFIELD_TEXTURE_NAMES, Default = "Disabled" })
BodyExtra:Toggle({ Name = "Disable textures", Flag = "arm_disable_textures", Default = false })
BodyExtra:Toggle({ Name = "Remove accessories", Flag = "arm_remove_accessories", Default = false })

    -- Self chams (Highlight)
    local SelfChams = VisualsPage:Section({ Name = "Self chams", Side = 2 })
    SelfChams:Toggle({ Name = "Self chams", Flag = "Self_Chams", Default = false }):Colorpicker({ Name = "Fill", Flag = "Self_ChamsColor1", Default = Color3.fromRGB(80, 160, 255), Alpha = 0.3 }):Colorpicker({ Name = "Outline", Flag = "Self_ChamsColor2", Default = WHITE, Alpha = true })

    -- Weather + lightning (left column, under the camera)
    local WeatherMain, WeatherLook, WeatherWind, WeatherStrike = WorldPage:MultiSection({ Sections = { "Weather", "Look", "Wind", "Strike" }, Side = 1 })
    WeatherMain:Toggle({ Name = "Weather", Flag = "weather_enabled", Default = false }):Colorpicker({ Name = "Color", Flag = "weather_color", Default = Color3.fromRGB(200, 200, 220) })
    WeatherMain:Dropdown({ Name = "Preset", Flag = "weather_preset", Items = WEATHER_NAMES, Default = "Rain" })
    WeatherMain:Slider({ Name = "Intensity", Flag = "weather_intensity", Min = 0.1, Max = 3, Default = 1, Decimals = 0.01 })
    WeatherMain:Slider({ Name = "Height", Flag = "weather_height", Suffix = " studs", Min = 10, Max = 120, Default = 40, Decimals = 1 })
    WeatherLook:Slider({ Name = "Speed", Flag = "weather_speed", Min = 0.2, Max = 3, Default = 1, Decimals = 0.01 })
    WeatherLook:Slider({ Name = "Size", Flag = "weather_size", Min = 0.3, Max = 3, Default = 1, Decimals = 0.01 })
    WeatherLook:Slider({ Name = "Glow", Flag = "weather_glow", Min = 0, Max = 1, Default = 0, Decimals = 0.01 })
    WeatherLook:Slider({ Name = "Spread", Flag = "weather_spread", Min = 0.2, Max = 3, Default = 1, Decimals = 0.01 })
    WeatherWind:Slider({ Name = "Strength", Flag = "weather_wind_strength", Min = 0, Max = 20, Default = 2, Decimals = 0.1 })
    WeatherWind:Slider({ Name = "Direction", Flag = "weather_wind_angle", Suffix = "°", Min = 0, Max = 360, Default = 45, Decimals = 1 })
    WeatherStrike:Toggle({ Name = "Lightning (rain only)", Flag = "weather_lightning", Default = false }):Colorpicker({ Name = "Color", Flag = "weather_lightning_color", Default = Color3.fromRGB(200, 220, 255) })
    WeatherStrike:Slider({ Name = "Thickness", Flag = "weather_lightning_thickness", Min = 0.05, Max = 1, Default = 0.2, Decimals = 0.01 })
    WeatherStrike:Slider({ Name = "Jaggedness", Flag = "weather_lightning_jagged", Min = 1, Max = 15, Default = 6, Decimals = 0.1 })
    WeatherStrike:Slider({ Name = "Flash", Flag = "weather_lightning_flash", Min = 0, Max = 10, Default = 4, Decimals = 0.1 })
    WeatherStrike:Slider({ Name = "Interval", Flag = "weather_lightning_interval", Suffix = "s", Min = 1, Max = 15, Default = 4, Decimals = 0.1 })

    -- Custom crosshair (right column, under self chams)
    local CrossMain, CrossOutline, CrossMotion, CrossArms = VisualsPage:MultiSection({ Sections = { "Crosshair", "Outline", "Motion", "Arms" }, Side = 1 })
    CrossMain:Toggle({ Name = "Crosshair", Flag = "crosshair_enabled", Default = false }):Colorpicker({ Name = "Color", Flag = "crosshair_color", Default = WHITE })
    CrossMain:Slider({ Name = "Length", Flag = "crosshair_length", Suffix = " px", Min = 1, Max = 40, Default = 12, Decimals = 1 })
    CrossMain:Slider({ Name = "Thickness", Flag = "crosshair_thickness", Suffix = " px", Min = 1, Max = 8, Default = 2, Decimals = 1 })
    CrossMain:Slider({ Name = "Gap", Flag = "crosshair_gap", Suffix = " px", Min = 0, Max = 30, Default = 6, Decimals = 1 })
    CrossMain:Toggle({ Name = "Hide default cursor", Flag = "crosshair_hide_cursor", Default = false })
    CrossOutline:Toggle({ Name = "Outline", Flag = "crosshair_outline", Default = false }):Colorpicker({ Name = "Color", Flag = "crosshair_outline_color", Default = BLACK })
    CrossOutline:Slider({ Name = "Outline thickness", Flag = "crosshair_outline_thickness", Suffix = " px", Min = 1, Max = 4, Default = 1, Decimals = 1 })
    CrossMotion:Toggle({ Name = "Rotation", Flag = "crosshair_rotation", Default = false })
    CrossMotion:Slider({ Name = "Angle", Flag = "crosshair_rotation_angle", Suffix = "°", Min = 0, Max = 360, Default = 0, Decimals = 1 })
    CrossMotion:Slider({ Name = "Spin speed", Flag = "crosshair_rotation_speed", Suffix = "°/s", Min = -360, Max = 360, Default = 90, Decimals = 1 })
    CrossMotion:Toggle({ Name = "Pulsing spread", Flag = "crosshair_spread", Default = false })
    CrossMotion:Slider({ Name = "Spread min", Flag = "crosshair_spread_min", Suffix = " px", Min = 0, Max = 40, Default = 4, Decimals = 1 })
    CrossMotion:Slider({ Name = "Spread max", Flag = "crosshair_spread_max", Suffix = " px", Min = 0, Max = 60, Default = 16, Decimals = 1 })
    CrossMotion:Slider({ Name = "Spread speed", Flag = "crosshair_spread_speed", Min = 0, Max = 10, Default = 3, Decimals = 0.1 })
    CrossArms:Toggle({ Name = "Top arm", Flag = "crosshair_arm_top", Default = true })
    CrossArms:Toggle({ Name = "Bottom arm", Flag = "crosshair_arm_bottom", Default = true })
    CrossArms:Toggle({ Name = "Left arm", Flag = "crosshair_arm_left", Default = true })
    CrossArms:Toggle({ Name = "Right arm", Flag = "crosshair_arm_right", Default = true })

    -- Hit effects and particle aura -------------------------------------------------------
    local HitFx = WorldPage:Section({ Name = "Hit effects", Side = 2 })
    local heToggle = HitFx:Toggle({ Name = "Hit effects", Flag = "he_enabled", Default = false })
    heToggle:Colorpicker({ Name = "Color", Flag = "he_color", Default = Color3.fromRGB(255, 81, 0) })
    HitFx:Dropdown({ Name = "Effect", Flag = "he_effect", Items = { "nova", "sparks", "bubble", "orbs", "air", "blood", "glitch", "slash", "cosmic", "crescentslash" }, Default = "nova" })
    HitFx:Dropdown({ Name = "Trigger", Flag = "he_trigger", Items = { "On hit", "On shot" }, Default = "On hit" })
    HitFx:Slider({ Name = "Size", Flag = "he_size", Min = 0, Max = 10, Default = 2, Decimals = 0.1 })
    HitFx:Slider({ Name = "Duration", Flag = "he_duration", Min = 0.1, Max = 10, Default = 2, Suffix = "s", Decimals = 0.1 })
    HitFx:Button({ Name = "Preview effect", Callback = function() Actions.previewHitEffect() end })

    local AuraBox = WorldPage:Section({ Name = "Particle aura", Side = 1 })
    local auraToggle = AuraBox:Toggle({ Name = "Particle aura", Flag = "pa_enabled", Default = false })
    auraToggle:Colorpicker({ Name = "Color", Flag = "pa_color", Default = Color3.fromRGB(133, 220, 255), Alpha = 0.2 })
    AuraBox:Dropdown({ Name = "Aura", Flag = "pa_source", Items = { "starlight", "heavenly", "ribbon", "sakura", "angel", "wind", "flow", "star" }, Default = "angel" })
end


-- Spoofer
do
    local Avatar = SpooferPage:Section({ Name = "Avatar changer", Side = 1 })
    Avatar:Input({ Name = "User", Flag = "spoof_avatar_user", Placeholder = "UserId, username or profile URL" })
    Avatar:Button({ Name = "Apply avatar", Callback = function()
        task.spawn(function() SpooferActions.apply() end)
    end })
    Avatar:Button({ Name = "Reset to my avatar", Callback = function()
        task.spawn(function() SpooferActions.reset() end)
    end })
    Avatar:Toggle({ Name = "Re-apply on respawn", Flag = "spoof_avatar_reapply", Default = true })

end

-- Players
do
-- Players
do
    local PlayerListSection = PlayersPage:Section({ Name = "Players", Side = 1 })
    local KickSection = PlayersPage:Section({ Name = "Kick exploit", Side = 1 })
    local PlayerOptions = PlayersPage:Section({ Name = "Player", Side = 2 })
    KickSection:Button({ Name = "Fling selected player", Callback = function() Actions.kickOnce() end })
    KickSection:Toggle({ Name = "Loop fling selected", Flag = "misc_kick_sel", Default = false })
    KickSection:Toggle({ Name = "Loop fling all", Flag = "misc_kick_all", Default = false })
    KickSection:Toggle({ Name = "Skip players inside the prison", Flag = "misc_kick_filter", Default = false })
    KickSection:Toggle({ Name = "Velocity protection", Flag = "misc_kick_velprot", Default = true })
    KickSection:Toggle({ Name = "Move to the car spawner", Flag = "misc_kick_move", Default = true })
    KickSection:Toggle({ Name = "Grab a gun first", Flag = "misc_kick_equip", Default = false })
    KickSection:Label({ Name = "Stand on the car spawner plate first or it will not work. Needs isnetworkowner." })

    local function currentPlayerNames()
        local names = {}
        for _, player in ipairs(Players:GetPlayers()) do
            table.insert(names, player.Name)
        end
        table.sort(names, function(a, b) return a:lower() < b:lower() end)
        return names
    end

    local ActualPlayerList = PlayerListSection:Listbox({
        Size = 230,
        Items = currentPlayerNames(),
        Default = currentPlayerNames()[1] or "",
        Multi = false,
        Flag = "Player_Selected",
    })

    local PlayerRelations = {}

    local function selectedPlayer()
        local name = readFlag("Player_Selected", "")
        return name ~= "" and Players:FindFirstChild(name) or nil
    end

    PlayerOptions:Dropdown({
        Name = "Relationship",
        Flag = "Player_Relationship",
        Items = { "None", "Friendly", "Priority" },
        Default = "None",
        Callback = function(Value)
            local player = selectedPlayer()
            if not player then return end
            if Value == "Friendly" or Value == "Priority" then Relations[player.UserId] = Value else Relations[player.UserId] = nil end
        end,
    })
    PlayerOptions:Toggle({ Name = "Highlight friendly", Flag = "rel_hl_friendly", Default = false }):Colorpicker({ Name = "Friendly color", Flag = "rel_hl_friendly_color", Default = Color3.fromRGB(80, 255, 120) })
    PlayerOptions:Toggle({ Name = "Highlight priority", Flag = "rel_hl_priority", Default = false }):Colorpicker({ Name = "Priority color", Flag = "rel_hl_priority_color", Default = Color3.fromRGB(255, 70, 70) })
    task.defer(function()
        local picker = Options.Player_Selected
        if picker and type(picker.OnChanged) == "function" then
            picker:OnChanged(function()
                local player = selectedPlayer()
                local dropdown = Options.Player_Relationship
                if player and dropdown and dropdown.SetValue then dropdown:SetValue(Relations[player.UserId] or "None") end
            end)
        end
    end)

    PlayerOptions:Button({
        Name = "Teleport",
        Callback = function()
            local target = selectedPlayer()
            local targetRoot = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
            local ownRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if targetRoot and ownRoot then
                ownRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 3)
                Library:Notify("Teleported to " .. target.Name, 3)
            end
        end,
    })

    local oldCameraSubject
    local spectating = false
    PlayerOptions:Toggle({
        Name = "Spectate",
        Flag = "Player_Spectate",
        Default = false,
        Callback = function(Value)
            spectating = Value
            local camera = workspace.CurrentCamera
            if not camera then return end
            if Value then
                local target = selectedPlayer()
                local humanoid = target and target.Character and target.Character:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    oldCameraSubject = camera.CameraSubject
                    camera.CameraSubject = humanoid
                else
                    spectating = false
                end
            elseif oldCameraSubject then
                camera.CameraSubject = oldCameraSubject
                oldCameraSubject = nil
            end
        end,
    })

    PlayerOptions:Label({ Name = "Selected player controls" })

    local function refreshPlayerList()
        if not ActualPlayerList or type(ActualPlayerList.Refresh) ~= "function" then return end
        pcall(function()
            ActualPlayerList:Refresh(currentPlayerNames())
        end)
    end

    Players.PlayerAdded:Connect(function()
        task.defer(refreshPlayerList)
    end)
    Players.PlayerRemoving:Connect(function(player)
        PlayerRelations[player] = nil
        if selectedPlayer() == player and spectating then
            spectating = false
            local camera = workspace.CurrentCamera
            if camera and oldCameraSubject then
                camera.CameraSubject = oldCameraSubject
                oldCameraSubject = nil
            end
        end
        task.defer(refreshPlayerList)
    end)
end


end

-- UI Settings
do
    local SettingsTab = LinoriaWindow:AddTab("Settings")

    -- Menu --------------------------------------------------------------
    local MenuGroup = SettingsTab:AddLeftGroupbox("Menu")
    MenuGroup:AddButton("Unload", function() Library:Unload() end)
    MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", { Default = "RightControl", NoUI = true, Text = "Menu keybind" })
    escapeUnbinds("MenuKeybind", "RightControl")
    MenuGroup:AddToggle("KeybindMenuOpen", {
        Default = Library.KeybindFrame.Visible,
        Text = "Show keybinds",
        Callback = function(value) Library.KeybindFrame.Visible = value end,
    })
    MenuGroup:AddToggle("ShowWatermark", {
        Text = "Show watermark",
        Default = true,
        Callback = function(value) Library:SetWatermarkVisibility(value) end,
    })
    MenuGroup:AddToggle("WireframeResize", {
        Text = "Outline while resizing",
        Default = Library.WireframeDrag == true,
        Tooltip = "Drag the round grip in the bottom-right corner to resize the menu",
        Callback = function(value) Library.WireframeDrag = value end,
    })

    -- Background (blur, darken, keybind list transparency) ---------------------
    local BackgroundGroup = SettingsTab:AddLeftGroupbox("Background")
    if Library.AddBlurSlider then Library:AddBlurSlider(BackgroundGroup) end
    if Library.AddDarkenSlider then Library:AddDarkenSlider(BackgroundGroup) end
    if Library.AddKeybindTransparencySlider then Library:AddKeybindTransparencySlider(BackgroundGroup) end

    -- Notifications -------------------------------------------------------------
    -- Library:ConfigureNotifications needs a table of the settings that changed.
    if Library.NotifyConfig and Library.ConfigureNotifications then
        local config = Library.NotifyConfig
        local function configure(key)
            return function(value) Library:ConfigureNotifications({ [key] = value }) end
        end

        local NotifyGroup = SettingsTab:AddRightGroupbox("Notifications")
        NotifyGroup:AddDropdown("NotificationBarSide", {
            Text = "Accent bar position", Values = { "Top", "Bottom", "Left", "Right" },
            Default = config.BarSide or "Bottom", Callback = configure("BarSide"),
        })
        NotifyGroup:AddDropdown("NotificationAlignment", {
            Text = "Alignment", Values = { "Left", "Center", "Right" },
            Default = config.Alignment or "Center", Callback = configure("Alignment"),
        })
        NotifyGroup:AddSlider("NotificationPosX", {
            Text = "Position X", Min = 0, Max = 100, Rounding = 0, Suffix = "%",
            Default = config.PosX or 50, Callback = configure("PosX"),
        })
        NotifyGroup:AddSlider("NotificationPosY", {
            Text = "Position Y", Min = 0, Max = 100, Rounding = 0, Suffix = "%",
            Default = config.PosY or 60, Callback = configure("PosY"),
        })
        NotifyGroup:AddSlider("NotificationTransparency", {
            Text = "Transparency", Min = 0, Max = 100, Rounding = 0, Suffix = "%",
            Default = config.Transparency or 60, Callback = configure("Transparency"),
        })
        NotifyGroup:AddSlider("NotificationMaxHeight", {
            Text = "Max height", Min = 50, Max = 500, Rounding = 0, Suffix = " px",
            Default = config.MaxHeight or 200, Callback = configure("MaxHeight"),
        })
        NotifyGroup:AddToggle("NotificationClipDescendants", {
            Text = "Clip to max height", Default = config.ClipDescendants == true,
            Callback = configure("ClipDescendants"),
        })
        NotifyGroup:AddDropdown("NotificationSortOrder", {
            Text = "Sort order", Values = { "Time", "Text Length" },
            Default = config.SortOrder or "Time", Callback = configure("SortOrder"),
        })
        NotifyGroup:AddButton("Test notification", function() Library:Notify("Test notification", 3) end)
    end

    Library.ToggleKeybind = Options.MenuKeybind
    Library:SetWatermark("Aster")
    Library:SetWatermarkVisibility(true)

    ThemeManager:SetLibrary(Library)
    SaveManager:SetLibrary(Library)
    SaveManager:IgnoreThemeSettings()
    SaveManager:SetIgnoreIndexes({ "MenuKeybind", "Player_Relationship", "Player_Selected" })
    ThemeManager.DefaultTheme = "Perception"
    ThemeManager:SetFolder("Aster")
    SaveManager:SetFolder("Aster/configs")
    SaveManager:BuildConfigSection(SettingsTab)
    ThemeManager:ApplyToTab(SettingsTab)
    Loader.setAccent(Library.AccentColor)
    do -- keep the saved loader colour in step with the theme
        local alive, last = true, Library.AccentColor
        onUnload(function() alive = false end)
        task.spawn(function()
            while alive do
                task.wait(2)
                if Library.AccentColor ~= last then
                    last = Library.AccentColor
                    Loader.saveAccent(last)
                end
            end
        end)
    end
end

do
    local LightingService = game:GetService("Lighting")
    local SoundService = game:GetService("SoundService")
    local Debris = game:GetService("Debris")

    local function getFlag(name, default)
        return readFlag(name, default)
    end

    local function pickerAlpha(name, default)
        local object = Options[name]
        return object and tonumber(object.Transparency) or default
    end

    local function getColor(name, default)
        local object = Options[name]
        if object and typeof(object.Value) == "Color3" then return object.Value end
        return default
    end

    local function isMultiSelected(value, key)
        if type(value) ~= "table" then return false end
        if value[key] == true then return true end
        for _, selected in pairs(value) do
            if selected == key then return true end
        end
        return false
    end

    local function safeEnumMaterial(name)
        if type(name) ~= "string" or name == "Default" then return nil end
        return Enum.Material[name]
    end

    local function newDrawing(kind)
        if not Drawing or type(Drawing.new) ~= "function" then return nil end
        local ok, obj = pcall(function() return Drawing.new(kind) end)
        if ok and obj then table.insert(getgenv().TS_Drawings, obj) end
        return ok and obj or nil
    end

    
    local fovCircle = newDrawing("Circle")
    if fovCircle then
        fovCircle.Visible = false
        fovCircle.Radius = 100
        fovCircle.Color = Color3.new(1, 1, 1)
        fovCircle.Thickness = 1
        fovCircle.Filled = false
        fovCircle.Transparency = 1
    end

    
    
    -- The ESP library bakes the health gradient colors in when a player's ESP object is
    -- created and never updates them afterwards, so the Full / Mid / Low HP color pickers
    -- had no effect. This adds the per-frame update (and lets the gradient work for Top and
    -- Bottom bars too). If the library changes and the anchors stop matching, it is left as is.
    local function replaceOnce(source, old, new)
        local first, last = string.find(source, old, 1, true)
        if not first then return source, false end
        return string.sub(source, 1, first - 1) .. new .. string.sub(source, last + 1), true
    end

    local HEALTH_GRADIENT_UPDATE = table.concat({
        "espObj.HealthGradient.Rotation=isHorizontal and 180 or 90;",
        "local hc1,hc2,hc3=GetCfg(\"HealthBar.Gradient.Color1\"),GetCfg(\"HealthBar.Gradient.Color2\"),GetCfg(\"HealthBar.Gradient.Color3\");",
        "if espObj._hc1~=hc1 or espObj._hc2~=hc2 or espObj._hc3~=hc3 then",
        "espObj._hc1,espObj._hc2,espObj._hc3=hc1,hc2,hc3;",
        "espObj.HealthGradient.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,hc1),ColorSequenceKeypoint.new(0.5,hc2),ColorSequenceKeypoint.new(1,hc3)}) end;",
    }, " ")

    -- The ESP library decides who to track in ScanDirectories(). This adds a call to a filter
    -- function (getgenv().TS_ESPFilter, set below) right after its own local-player check.
    local TEAM_FILTER_ANCHOR = "if not ESPConfig.LocalPlayer and player==LocalPlayer then continue end"
    local TEAM_FILTER_HOOK = TEAM_FILTER_ANCHOR .. " if getgenv().TS_ESPFilter and not getgenv().TS_ESPFilter(player) then continue end"

    local function patchEspSource(source)
        local patched, okOne = replaceOnce(source, "if gradientEnabled and not isHorizontal then", "if gradientEnabled then")
        local okTwo
        patched, okTwo = replaceOnce(patched, "espObj.HealthGradient.Rotation=90;", HEALTH_GRADIENT_UPDATE)
        if not (okOne and okTwo) then
            warn("Health color patch skipped: the ESP library changed")
            patched = source
        end

        local filtered, okThree = replaceOnce(patched, TEAM_FILTER_ANCHOR, TEAM_FILTER_HOOK)
        if not okThree then
            warn("Team filter patch skipped: the ESP library changed")
            filtered = patched
        end
        -- per-player config overrides (colors for highlighted / team colored players)
        local withOverride, okFour = replaceOnce(filtered,
            "newTracked[player.Character]={name=player.Name,Cheap=false}",
            "newTracked[player.Character]={name=player.Name,Cheap=false,Config=getgenv().TS_ESPOverride and getgenv().TS_ESPOverride(player) or nil}")
        if not okFour then
            warn("Highlight color patch skipped: the ESP library changed")
            return filtered
        end
        return withOverride
    end

    Loader.step("Loading ESP library", 0.56)
    local COINCIDE_ESP_URL = "https://raw.githubusercontent.com/ExtroDevGit/Coincide-UI/refs/heads/main/esp_lib.lua"
    local CoincideESP
    do
        local ok, result = pcall(function()
            return loadstring(patchEspSource(game:HttpGet(COINCIDE_ESP_URL)))()
        end)
        if ok and type(result) == "table" then
            CoincideESP = result
        else
            warn("Coincide ESP failed to load:", result)
        end
    end

    local function setCoincide(path, value)
        if not CoincideESP then return false end
        local cfg = CoincideESP:GetConfig()
        local cursor = cfg
        local parts = string.split(path, ".")
        for i = 1, #parts - 1 do
            cursor = cursor[parts[i]]
            if type(cursor) ~= "table" then return false end
        end
        local key = parts[#parts]
        if cursor[key] ~= value then
            cursor[key] = value
            return true
        end
        return false
    end

    -- ESP update rate: the library's own maximum.
    local ESP_MAX_FPS = 140

    -- Enemies only: not on your team (a Neutral player counts as an enemy); Friendly players are hidden,
    -- Priority players are always shown.
    -- Hostile only: Inmates that are not Hostile are hidden, whichever team you are on. Criminals, Guards
    -- and Priority players stay visible.
    local function hiddenAsPeaceful(player)
        return getFlag("esp_hostile_only", false) and isPeaceful(player)
    end
    local function teamAllowed(player)
        if player ~= LocalPlayer and getFlag("esp_enemies_only", false) and not isEnemy(player) then return false end
        if player ~= LocalPlayer and hiddenAsPeaceful(player) then return false end
        return true
    end
    getgenv().TS_ESPFilter = teamAllowed

    -- Highlight colors (players marked Friendly or Priority in the Players tab) win over team colors. They recolor the ESP library
    -- boxes and text through its per-player config overrides, plus the skeleton and the visible
    -- chams layer here. The behind-walls chams color is never changed.
    local function relationColor(player)
        if player == LocalPlayer then return nil end
        local explicit = Relations[player.UserId]
        if explicit == "Friendly" and getFlag("rel_hl_friendly", false) then
            return getColor("rel_hl_friendly_color", Color3.fromRGB(80, 255, 120))
        elseif explicit == "Priority" and getFlag("rel_hl_priority", false) then
            return getColor("rel_hl_priority_color", Color3.fromRGB(255, 70, 70))
        end
        if getFlag("esp_use_team_color", false) and player.Team then
            return player.Team.TeamColor.Color
        end
        return nil
    end

    local overrideCache = {}
    getgenv().TS_ESPOverride = function(player)
        local color = relationColor(player)
        if not color then return nil end
        local key = tostring(color)
        local entry = overrideCache[key]
        if not entry then
            entry = { BoxColor = color, TextColor = color, GlowColor = color, BoxFill = { Color = color } }
            overrideCache[key] = entry
        end
        return entry
    end
    onUnload(function()
        getgenv().TS_ESPFilter = nil
        getgenv().TS_ESPOverride = nil
    end)

    -- The library only rescans its player list every few seconds. Adding and removing a
    -- throw-away Folder in Workspace marks it dirty, so team changes show up within 0.2s.
    local lastTeamSignature
    local function checkTeamChanges()
        local parts = {}
        table.insert(parts, table.concat({
            tostring(getFlag("esp_enemies_only", false)), tostring(getFlag("esp_hostile_only", false)), tostring(getFlag("esp_use_team_color", false)),
            tostring(getFlag("rel_hl_friendly", false)), tostring(getFlag("rel_hl_priority", false)),
            tostring(getColor("rel_hl_friendly_color", Color3.new(1, 1, 1))), tostring(getColor("rel_hl_priority_color", Color3.new(1, 1, 1))),
        }, ":"))
        for _, player in ipairs(Players:GetPlayers()) do
            table.insert(parts, (player.Team and player.Team.Name or "-") .. ":" .. relationOf(player) .. ":" .. tostring(hiddenAsPeaceful(player)))
        end
        local signature = table.concat(parts, ",")
        if signature == lastTeamSignature then return end
        lastTeamSignature = signature
        local kick = Instance.new("Folder")
        kick.Name = "TS_Rescan"
        kick.Parent = workspace
        kick:Destroy()
    end

    local function syncCoincideESP()
        if not CoincideESP then return end
        checkTeamChanges()
        local changed = false
        local function put(path, value)
            if setCoincide(path, value) then changed = true end
        end

        put("Enabled", getFlag("esp_enabled", false))
        put("Players", getFlag("esp_players", true))
        put("LocalPlayer", getFlag("esp_local_player", false))
        put("LimitFPS", ESP_MAX_FPS)
        put("DynamicBoxes", getFlag("esp_dynamic_boxes", false))
        put("DynamicBoxesCheap", getFlag("esp_dynamic_cheap", false))
        put("DynamicBoxesIncludeAll", getFlag("esp_dynamic_include_all", false))
        put("VisibilityCheckRate", getFlag("esp_visibility_rate", 0.3))

        put("Boxes", getFlag("esp_box", false))
        put("BoxType", getFlag("esp_box_type", "Corner"))
        put("BoxColor", getColor("esp_box_color", Color3.fromRGB(255, 255, 255)))
        put("BoxThickness", getFlag("esp_box_thickness", 1))
        put("Outlines.Style", getFlag("esp_outline_enabled", true) and "Full" or "None")
        put("Outlines.Color", getColor("esp_outline_color", Color3.fromRGB(0, 0, 0)))
        put("Outlines.Thickness", getFlag("esp_outline_thickness", 1))

        put("BoxFill.Enabled", getFlag("esp_fill", false))
        put("BoxFill.Color", getColor("esp_fill_color", Color3.fromRGB(255, 255, 255)))
        put("BoxFill.Transparency", math.clamp(pickerAlpha("esp_fill_color", 0.9), 0, 1))
        put("BoxFill.Gradient.Enabled", getFlag("esp_fill_gradient", false))
        put("BoxFill.Gradient.Color1", getColor("esp_fill_gradient_1", getColor("esp_fill_color", Color3.fromRGB(255, 255, 255))))
        put("BoxFill.Gradient.Color2", getColor("esp_fill_gradient_2", getColor("esp_fill_color", Color3.fromRGB(255, 255, 255)):Lerp(Color3.new(1,1,1), 0.25)))
        put("BoxFill.Gradient.Color3", getColor("esp_fill_gradient_3", getColor("esp_fill_color", Color3.fromRGB(255, 255, 255))))

        put("Glow", getFlag("esp_glow", false))
        put("GlowColor", getColor("esp_glow_color", Color3.fromRGB(255, 255, 255)))
        put("GlowTransparency", math.clamp(pickerAlpha("esp_glow_color", 0.72), 0, 1))
        put("GlowGradient", getFlag("esp_glow_gradient", false))

        put("Names", getFlag("esp_name", false))
        put("TextSize", getFlag("esp_text_size", 12))
        put("TextColor", getColor("esp_name_color1", Color3.fromRGB(255, 255, 255)))
        put("TextOutline", true)
        put("TeamIndicator.Enabled", getFlag("esp_team_indicator", false))
        put("TeamIndicator.UseTeamColor", getFlag("esp_team_use_color", false))
        put("TeamIndicator.Color", getColor("esp_team_color", Color3.fromRGB(255, 255, 255)))
        put("TeamIndicator.Compact", getFlag("esp_team_compact", false))
        put("FriendlyIndicator.Enabled", getFlag("esp_team_check", false))
        put("FriendlyIndicator.CheckTeam", getFlag("esp_team_check", false))
        put("FriendlyIndicator.CheckFriends", getFlag("esp_friendly_friends_check", false))
        put("FriendlyIndicator.Color", getColor("esp_friendly_color", Color3.fromRGB(0, 255, 0)))
        put("Distance.Enabled", getFlag("esp_distance", false))
        local distanceUnit = getFlag("esp_distance_unit", "Meters")
        put("Distance.Unit", distanceUnit)
        put("Distance.Ending", distanceUnit == "Studs" and "s" or "m")
        put("Distance.Color", getColor("esp_distance_color", Color3.fromRGB(255, 255, 255)))
        put("Weapon.Enabled", getFlag("esp_weapon", false))
        put("Weapon.UseToolFallback", getFlag("esp_weapon_fallback", false))
        put("Weapon.Color", getColor("esp_weapon_color", Color3.fromRGB(255, 255, 255)))

        put("Flags.Enabled", getFlag("esp_flags", false))
        put("Flags.Position", getFlag("esp_flags_position", "Right"))
        local flagOpts = getFlag("esp_flags_options", { Moving = true }) or {}
        put("Flags.Options.Idle", isMultiSelected(flagOpts, "Idle"))
        put("Flags.Options.Moving", isMultiSelected(flagOpts, "Moving"))
        put("Flags.Options.Jumping", isMultiSelected(flagOpts, "Jumping"))
        put("Flags.Options.Swimming", isMultiSelected(flagOpts, "Swimming"))
        put("Flags.Colors.Idle", getColor("esp_flag_idle_color", Color3.fromRGB(255,255,255)))
        put("Flags.Colors.Moving", getColor("esp_flag_moving_color", Color3.fromRGB(255,210,80)))
        put("Flags.Colors.Jumping", getColor("esp_flag_jumping_color", Color3.fromRGB(255,150,80)))
        put("Flags.Colors.Swimming", getColor("esp_flag_swimming_color", Color3.fromRGB(80,150,255)))

        put("OffScreenArrows.Enabled", getFlag("esp_arrows", false))
        put("OffScreenArrows.Size", getFlag("esp_arrow_size", 14))
        put("OffScreenArrows.OrbitRadius", getFlag("esp_arrow_orbit", 100))
        put("OffScreenArrows.Color", getColor("esp_arrow_color", Color3.fromRGB(255,255,255)))

        put("HealthBar.Enabled", getFlag("esp_healthbar", false))
        put("HealthBar.Position", getFlag("esp_health_position", "Left"))
        put("HealthBar.Width", getFlag("esp_health_width", 1))
        put("HealthBar.ShowText", getFlag("esp_health_text", false))
        put("HealthBar.HideWhenFullHP", getFlag("esp_health_hide_full", false))
        put("HealthBar.Gradient.Enabled", true)
        put("HealthBar.Gradient.Color1", getColor("esp_healthbar_color_start", Color3.fromRGB(0, 255, 0)))
        put("HealthBar.Gradient.Color2", getColor("esp_healthbar_color_middle", Color3.fromRGB(255, 255, 0)))
        put("HealthBar.Gradient.Color3", getColor("esp_healthbar_color_end", Color3.fromRGB(255, 0, 0)))

        put("Skeleton.Enabled", false) -- drawn by this script (see Skeleton ESP below)
        put("Skeleton.Gradient.Enabled", false)
        put("Skeleton.Outline", getFlag("esp_skeleton_outline", true))
        put("Skeleton.OutlineColor", getColor("esp_skeleton_outline_color", Color3.fromRGB(0, 0, 0)))
        put("Skeleton.Color", getColor("esp_skeleton_color", Color3.fromRGB(255, 255, 255)))

        put("Chams.Enabled", false) -- chams are drawn by updateAdornChams below

        if changed then
            CoincideESP:InvalidateCache()
        end
    end

    if CoincideESP then
        syncCoincideESP()
    end

    
    
    local function ensureEffect(className, name)
        local effect = LightingService:FindFirstChild(name)
        if not effect or not effect:IsA(className) then
            if effect then effect:Destroy() end
            effect = Instance.new(className)
            effect.Name = name
            if className ~= "Atmosphere" then effect.Enabled = false end
        end
        return effect
    end

    local bloom = ensureEffect("BloomEffect", "TS_Bloom")
    bloom.Parent = LightingService
    local colorCorrection = ensureEffect("ColorCorrectionEffect", "TS_ColorCorrection")
    colorCorrection.Parent = LightingService
    local sunRays = ensureEffect("SunRaysEffect", "TS_SunRays")
    sunRays.Parent = LightingService
    local atmosphere = ensureEffect("Atmosphere", "TS_Atmosphere")
    atmosphere.Parent = nil
    local hiddenAtmospheres = {}
    local tsSky
    local originalSkyBackup
    local originalSkyCaptured = false

    local function captureOriginalSky()
        if originalSkyCaptured then return end
        originalSkyCaptured = true
        for _, child in ipairs(LightingService:GetChildren()) do
            if child:IsA("Sky") and child.Name ~= "TS_Skybox" then
                originalSkyBackup = child:Clone()
                child:Destroy()
                break
            end
        end
    end

    local function restoreOriginalSky()
        if tsSky then
            tsSky:Destroy()
            tsSky = nil
        end
        if originalSkyBackup and not LightingService:FindFirstChild(originalSkyBackup.Name) then
            originalSkyBackup:Clone().Parent = LightingService
        end
    end

    local originalLighting = {
        Ambient = LightingService.Ambient,
        Brightness = LightingService.Brightness,
        ClockTime = LightingService.ClockTime,
        ExposureCompensation = LightingService.ExposureCompensation,
        FogStart = LightingService.FogStart,
        FogEnd = LightingService.FogEnd,
        FogColor = LightingService.FogColor,
        GlobalShadows = LightingService.GlobalShadows,
        Technology = LightingService.Technology,
    }

    local function applySkybox()
        local enabled = getFlag("skybox_enabled", false)
        if not enabled then
            restoreOriginalSky()
            return
        end
        local preset = SKYBOX_PRESETS[getFlag("skybox_value", SKYBOX_NAMES[1])]
        if not preset then return end
        if preset.KeepOriginal then
            restoreOriginalSky()
            return
        end
        captureOriginalSky()
        if not tsSky or not tsSky.Parent then
            tsSky = Instance.new("Sky")
            tsSky.Name = "TS_Skybox"
            tsSky.Parent = LightingService
        end
        tsSky.SkyboxUp = preset.SkyboxUp; tsSky.SkyboxDn = preset.SkyboxDn; tsSky.SkyboxFt = preset.SkyboxFt; tsSky.SkyboxBk = preset.SkyboxBk; tsSky.SkyboxLf = preset.SkyboxLf; tsSky.SkyboxRt = preset.SkyboxRt
        tsSky.StarCount = preset.StarCount or 3000
        tsSky.SunAngularSize = preset.SunAngularSize or 21
        tsSky.MoonAngularSize = preset.MoonAngularSize or 11
        tsSky.SunTextureId = preset.SunTextureId or ""
        tsSky.MoonTextureId = preset.MoonTextureId or ""
        local disable = getFlag("skybox_disable", {})
        if type(disable) == "table" then
            if isMultiSelected(disable, "stars") then tsSky.StarCount = 0 end
            if isMultiSelected(disable, "sun") then tsSky.SunAngularSize = 0; tsSky.SunTextureId = "" end
            if isMultiSelected(disable, "moon") then tsSky.MoonAngularSize = 0; tsSky.MoonTextureId = "" end
        end
    end

    -- A property is only touched while its toggle is on. When the toggle turns
    -- off, the value the game had at that moment is restored once.
    local lightingApplied = {}
    local lightingRestore = {}

    local function applyLightingProp(prop, on, value)
        if on then
            if not lightingApplied[prop] then
                lightingApplied[prop] = true
                lightingRestore[prop] = LightingService[prop]
            end
            if LightingService[prop] ~= value then
                LightingService[prop] = value
            end
        elseif lightingApplied[prop] then
            lightingApplied[prop] = nil
            LightingService[prop] = lightingRestore[prop]
        end
    end

    local function applyWorldLighting()
        applyLightingProp("Ambient", getFlag("lighting_toggle_Ambient", false), getColor("lighting_colorAmbient", originalLighting.Ambient))
        applyLightingProp("Brightness", getFlag("lighting_toggle_Brightness", false), getFlag("lighting_number_Brightness", originalLighting.Brightness))
        applyLightingProp("ExposureCompensation", getFlag("lighting_toggle_ExposureCompensation", false), getFlag("lighting_number_ExposureCompensation", originalLighting.ExposureCompensation))
        applyLightingProp("ClockTime", getFlag("lighting_toggle_ClockTime", false), getFlag("lighting_number_ClockTime", originalLighting.ClockTime))
        applyLightingProp("FogStart", getFlag("lighting_toggle_FogStart", false), getFlag("lighting_number_FogStart", originalLighting.FogStart))
        applyLightingProp("FogEnd", getFlag("lighting_toggle_FogEnd", false), getFlag("lighting_number_FogEnd", originalLighting.FogEnd))
        applyLightingProp("FogColor", getFlag("lighting_toggle_FogColor", false), getColor("lighting_colorFogColor", originalLighting.FogColor))

        -- No toggle for these two: they only apply while they differ from the game's own value.
        local shadows = getFlag("lighting_bool_GlobalShadows", originalLighting.GlobalShadows)
        pcall(applyLightingProp, "GlobalShadows", shadows ~= originalLighting.GlobalShadows, shadows)

        local techName = getFlag("lighting_technology", originalLighting.Technology.Name)
        pcall(function()
            applyLightingProp("Technology", techName ~= originalLighting.Technology.Name, Enum.Technology[techName])
        end)
    end

    local function applyAtmosphere()
        if getFlag("atmosphere_enabled", false) then
            if atmosphere.Parent ~= LightingService then
                for _, child in ipairs(LightingService:GetChildren()) do
                    if child:IsA("Atmosphere") and child ~= atmosphere then
                        table.insert(hiddenAtmospheres, child)
                        child.Parent = nil
                    end
                end
                atmosphere.Parent = LightingService
            end
            atmosphere.Color = getColor("atmosphere_color", WHITE)
            atmosphere.Decay = getColor("atmosphere_decay", WHITE)
            atmosphere.Glare = getFlag("atmosphere_glare", 4.1)
            atmosphere.Haze = getFlag("atmosphere_haze", 1)
            atmosphere.Density = getFlag("atmosphere_density", 0.3)
            atmosphere.Offset = getFlag("atmosphere_offset", 0.4)
        elseif atmosphere.Parent then
            atmosphere.Parent = nil
            for _, original in ipairs(hiddenAtmospheres) do
                original.Parent = LightingService
            end
            table.clear(hiddenAtmospheres)
        end
    end

    local function applyPostEffects()
        local bloomOn = getFlag("bloom_enabled", false)
        bloom.Enabled = bloomOn
        if bloomOn then
            bloom.Size = getFlag("bloom_size", 24)
            bloom.Intensity = getFlag("bloom_intensity", 0.4)
            bloom.Threshold = getFlag("bloom_threshold", 0.95)
        end

        local ccOn = getFlag("color_correction_enabled", false)
        colorCorrection.Enabled = ccOn
        if ccOn then
            colorCorrection.TintColor = getColor("color_correction_tint", WHITE)
            colorCorrection.Saturation = getFlag("color_correction_saturation", 0)
            colorCorrection.Contrast = getFlag("color_correction_contrast", 0)
            colorCorrection.Brightness = getFlag("color_correction_brightness", 0)
        end

        local raysOn = getFlag("sunrays_enabled", false)
        sunRays.Enabled = raysOn
        if raysOn then
            sunRays.Spread = math.clamp(getFlag("sunrays_spread", 1), 0, 1)
            sunRays.Intensity = math.clamp(getFlag("sunrays_intensity", 1), 0, 1)
        end

        applyAtmosphere()
    end

    local updateAdornChams
    ;(function()
    -- Layered adornment chams ---------------------------------------
    -- Two box adornments per body part, same idea as the reference script:
    --   behind-walls layer: AlwaysOnTop, so it shows through geometry
    --   visible layer: depth tested and slightly thicker, so it only appears
    --   (and sits around the first layer) while that part is really in view.
    local adornFolder = Instance.new("Folder")
    adornFolder.Name = "TS_AdornChams"
    do
        local parent
        pcall(function() if gethui then parent = gethui() end end)
        pcall(function() adornFolder.Parent = parent or game:GetService("CoreGui") end)
        if not adornFolder.Parent then adornFolder.Parent = workspace.CurrentCamera end
    end
    local adornData = {}

    local function newAdornment(part, alwaysOnTop, zIndex, round)
        local adornment = Instance.new(round and "CylinderHandleAdornment" or "BoxHandleAdornment")
        adornment.Adornee = part
        adornment.AlwaysOnTop = alwaysOnTop
        adornment.ZIndex = zIndex
        adornment.AdornCullingMode = Enum.AdornCullingMode.Never
        if round then
            -- A cylinder's length runs along Z; look straight up so it stands like a head.
            adornment.CFrame = CFrame.new(Vector3.new(0, 0, 0), Vector3.new(0, 90, 0))
        end
        adornment.Parent = adornFolder
        return adornment
    end

    local function destroyPair(pair)
        pcall(function() pair.behind:Destroy() end)
        pcall(function() pair.visible:Destroy() end)
    end

    local function clearAdornments(player)
        local data = adornData[player]
        if not data then return end
        for _, pair in pairs(data.parts) do destroyPair(pair) end
        adornData[player] = nil
    end

    -- Radius and height of the round head layer, from the head part and its mesh scale.
    local function headDimensions(head)
        local size = head.Size
        local mesh = head:FindFirstChildOfClass("SpecialMesh")
        if mesh then
            size = Vector3.new(size.X * mesh.Scale.X, size.Y * mesh.Scale.Y, size.Z * mesh.Scale.Z)
        end
        return math.min(size.X, size.Z) / 2, size.Y
    end

    function updateAdornChams()
        local active = getFlag("esp_enabled", false)
            and getFlag("esp_chams", false)
        if not active then
            for player in pairs(adornData) do clearAdornments(player) end
            return
        end

        local behindColor = getColor("esp_chams_adorn_occ_color", Color3.fromRGB(59, 144, 204))
        local behindTransparency = math.clamp(pickerAlpha("esp_chams_adorn_occ_color", 0.7), 0, 1)
        local visibleColor = getColor("esp_chams_adorn_vis_color", Color3.fromRGB(59, 204, 90))
        local visibleTransparency = math.clamp(pickerAlpha("esp_chams_adorn_vis_color", 0.35), 0, 1)
        local thickness = getFlag("esp_chams_adorn_thickness", 0.1)
        local grow = Vector3.new(thickness, thickness, thickness)
        -- Glow (same idea as the reference): the outer layer also draws through walls,
        -- and its transparency is divided by the strength so it reads brighter.
        local glowOn = getFlag("esp_chams_adorn_glow", false)
        local glowSize = math.max(getFlag("esp_chams_adorn_glow_size", 1.75), 1)
        local roundHead = getFlag("esp_chams_adorn_round_head", true)
        local headScale = getFlag("esp_chams_adorn_head_size", 1.15)
        local playersOn = getFlag("esp_players", true)
        local localOn = getFlag("esp_local_player", false)

        -- Runs every frame, so properties are only written when a setting or a part size changed.
        local signature = table.concat({
            tostring(behindColor), behindTransparency, tostring(visibleColor), visibleTransparency,
            thickness, tostring(glowOn), glowSize, tostring(roundHead), headScale,
        }, "|")

        local seen = {}
        for _, player in ipairs(Players:GetPlayers()) do
            local wanted = playersOn and (player ~= LocalPlayer or localOn) and teamAllowed(player)
            local character = wanted and player.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            if character and humanoid and humanoid.Health > 0 then
                seen[player] = true
                local data = adornData[player]
                if data and data.character ~= character then
                    clearAdornments(player)
                    data = nil
                end
                if not data then
                    data = { character = character, parts = {} }
                    adornData[player] = data
                end

                for part, pair in pairs(data.parts) do
                    local isHead = part.Name == "Head"
                    if not part:IsDescendantOf(character) or (isHead and pair.round ~= roundHead) then
                        destroyPair(pair)
                        data.parts[part] = nil
                    end
                end

                local playerVisible = relationColor(player) or visibleColor
                local playerSignature = signature .. "|" .. tostring(playerVisible)
                for _, part in ipairs(character:GetChildren()) do
                    if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.Transparency < 1 then
                        local round = roundHead and part.Name == "Head"
                        local pair = data.parts[part]
                        if not pair then
                            pair = {
                                round = round,
                                behind = newAdornment(part, true, 1, round),
                                visible = newAdornment(part, false, -1, round),
                            }
                            data.parts[part] = pair
                        end

                        local size = part.Size
                        if pair.signature ~= playerSignature or pair.partSize ~= size then
                            pair.signature = playerSignature
                            pair.partSize = size

                            if round then
                                local radius, height = headDimensions(part)
                                radius, height = radius * headScale, height * headScale
                                pair.behind.Radius = radius
                                pair.behind.Height = height
                                pair.visible.Radius = radius + thickness / 2
                                pair.visible.Height = height + thickness
                            else
                                pair.behind.Size = size
                                pair.visible.Size = size + grow
                            end

                            pair.behind.Color3 = behindColor
                            pair.behind.Transparency = behindTransparency

                            pair.visible.Visible = true
                            pair.visible.Color3 = playerVisible
                            pair.visible.AlwaysOnTop = glowOn
                            pair.visible.Transparency = glowOn and (visibleTransparency / glowSize) or visibleTransparency
                        end
                    end
                end
            end
        end

        for player in pairs(adornData) do
            if not seen[player] then clearAdornments(player) end
        end
    end

    track(Players.PlayerRemoving:Connect(clearAdornments))
    onUnload(function()
        for player in pairs(adornData) do clearAdornments(player) end
        pcall(function() adornFolder:Destroy() end)
    end)

    end)()
    local updateSkeletons
    ;(function()
    -- Skeleton ESP --------------------------------------------------
    -- Drawn here with Drawing lines (R15 uses the part chain, R6 uses points on the torso and limbs).
    local R15_BONES = {
        { "Head", "UpperTorso" }, { "UpperTorso", "LowerTorso" },
        { "UpperTorso", "LeftUpperArm" }, { "LeftUpperArm", "LeftLowerArm" }, { "LeftLowerArm", "LeftHand" },
        { "UpperTorso", "RightUpperArm" }, { "RightUpperArm", "RightLowerArm" }, { "RightLowerArm", "RightHand" },
        { "LowerTorso", "LeftUpperLeg" }, { "LeftUpperLeg", "LeftLowerLeg" }, { "LeftLowerLeg", "LeftFoot" },
        { "LowerTorso", "RightUpperLeg" }, { "RightUpperLeg", "RightLowerLeg" }, { "RightLowerLeg", "RightFoot" },
    }
    local MAX_BONES = #R15_BONES
    local skeletonLines = {}
    local skeletonSegments = {}

    local function pointOf(part, offset)
        return (part.CFrame * CFrame.new(offset)).Position
    end

    local function collectSegments(character)
        table.clear(skeletonSegments)
        local upperTorso = character:FindFirstChild("UpperTorso")
        if upperTorso then
            for _, bone in ipairs(R15_BONES) do
                local a, b = character:FindFirstChild(bone[1]), character:FindFirstChild(bone[2])
                if a and b then table.insert(skeletonSegments, { a.Position, b.Position }) end
            end
            return
        end

        local torso, head = character:FindFirstChild("Torso"), character:FindFirstChild("Head")
        if not torso or not head then return end
        local neck = pointOf(torso, Vector3.new(0, 1, 0))
        local pelvis = pointOf(torso, Vector3.new(0, -1, 0))
        table.insert(skeletonSegments, { head.Position, neck })
        table.insert(skeletonSegments, { neck, pelvis })
        for _, limb in ipairs({ { "Left Arm", neck }, { "Right Arm", neck }, { "Left Leg", pelvis }, { "Right Leg", pelvis } }) do
            local part = character:FindFirstChild(limb[1])
            if part then
                table.insert(skeletonSegments, { limb[2], pointOf(part, Vector3.new(0, 1, 0)) })
                table.insert(skeletonSegments, { pointOf(part, Vector3.new(0, 1, 0)), pointOf(part, Vector3.new(0, -1, 0)) })
            end
        end
    end

    local function skeletonEntry(player)
        local entry = skeletonLines[player]
        if entry then return entry end
        entry = { outline = {}, inner = {} }
        for index = 1, MAX_BONES * 2 do
            local outline = newDrawing("Line")
            local inner = newDrawing("Line")
            if not outline or not inner then return nil end
            outline.ZIndex = 1
            inner.ZIndex = 2
            outline.Visible = false
            inner.Visible = false
            entry.outline[index] = outline
            entry.inner[index] = inner
        end
        skeletonLines[player] = entry
        return entry
    end

    local function hideSkeleton(entry)
        for index = 1, #entry.inner do
            entry.inner[index].Visible = false
            entry.outline[index].Visible = false
        end
    end

    local function dropSkeleton(player)
        local entry = skeletonLines[player]
        if not entry then return end
        for index = 1, #entry.inner do
            pcall(function() entry.inner[index]:Remove() end)
            pcall(function() entry.outline[index]:Remove() end)
        end
        skeletonLines[player] = nil
    end

    function updateSkeletons()
        local camera = workspace.CurrentCamera
        local enabled = camera and getFlag("esp_enabled", false) and getFlag("esp_skeleton", false)
        if not enabled then
            for _, entry in pairs(skeletonLines) do hideSkeleton(entry) end
            return
        end

        local color = getColor("esp_skeleton_color", Color3.fromRGB(255, 255, 255))
        local outlineOn = getFlag("esp_skeleton_outline", true)
        local outlineColor = getColor("esp_skeleton_outline_color", Color3.fromRGB(0, 0, 0))
        local thickness = getFlag("esp_skeleton_thickness", 1.5)
        local playersOn = getFlag("esp_players", true)
        local localOn = getFlag("esp_local_player", false)

        for _, player in ipairs(Players:GetPlayers()) do
            local character = player.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            local wanted = playersOn and (player ~= LocalPlayer or localOn) and teamAllowed(player)
            local entry = skeletonLines[player]
            local playerColor = relationColor(player) or color

            if wanted and character and humanoid and humanoid.Health > 0 then
                entry = entry or skeletonEntry(player)
                if entry then
                    collectSegments(character)
                    for index = 1, #entry.inner do
                        local segment = skeletonSegments[index]
                        local inner, outline = entry.inner[index], entry.outline[index]
                        local drawn = false
                        if segment then
                            local from, fromVisible = camera:WorldToViewportPoint(segment[1])
                            local to, toVisible = camera:WorldToViewportPoint(segment[2])
                            if fromVisible and toVisible and from.Z > 0 and to.Z > 0 then
                                local a, b = Vector2.new(from.X, from.Y), Vector2.new(to.X, to.Y)
                                outline.From, outline.To = a, b
                                outline.Color = outlineColor
                                outline.Thickness = thickness + 2
                                outline.Visible = outlineOn
                                inner.From, inner.To = a, b
                                inner.Color = playerColor
                                inner.Thickness = thickness
                                inner.Visible = true
                                drawn = true
                            end
                        end
                        if not drawn then
                            inner.Visible = false
                            outline.Visible = false
                        end
                    end
                end
            elseif entry then
                hideSkeleton(entry)
            end
        end
    end

    track(Players.PlayerRemoving:Connect(dropSkeleton))
    onUnload(function()
        for player in pairs(skeletonLines) do dropSkeleton(player) end
    end)

    end)()
    local hitConnections, pendingHits, onLocalShot
    ;(function()
    -- Hit feedback ---------------------------------------------------
    -- Only bullets YOU fire count. The tracer hook below calls onLocalShot(origin, target) for
    -- each of your shots (the origin is your tool's Muzzle). The shot's path is raycast to find
    -- which player it hits, and that player is marked as "expecting damage from you" for a short
    -- window. Hit sound and notification fire only when that player's health then drops, so
    -- damage from anyone else in the server never triggers them.
    local HIT_WINDOW = 0.8
    local lastHitNotify = 0
    hitConnections = {}
    pendingHits = {} -- [player] = { expiry, expiry, ... } (one entry per pellet / bullet)

    playHitSound = function()
        local soundId = HIT_SOUNDS[getFlag("World_HitSoundId", "Gamesense")]
        if not soundId then return end
        local sound = Instance.new("Sound")
        sound.SoundId = soundId
        sound.Volume = getFlag("World_HitVolume", 1)
        sound.Parent = SoundService
        sound:Play()
        Debris:AddItem(sound, 6)
    end

    local function onHit(player, damage, killed, position)
        if getFlag("World_HitSound", false) then
            playHitSound()
        end
        if getFlag("World_HitNotify", false) and os.clock() - lastHitNotify > 0.25 then
            lastHitNotify = os.clock()
            Library:Notify(string.format("Hit %s for %d%s", player.Name, math.floor(damage + 0.5), killed and " (kill)" or ""), 2)
        end
        if not position then
            local head = player.Character and player.Character:FindFirstChild("Head")
            position = head and head.Position
        end
        for _, listener in ipairs(ShotEvents.hit) do pcall(listener, player, position) end
    end

    function onLocalShot(origin, target)
        ShotEvents.last = os.clock()
        local offset = target - origin
        if offset.Magnitude < 0.1 then return end
        for _, listener in ipairs(ShotEvents.shot) do pcall(listener, origin, target) end

        local ignore = {}
        if LocalPlayer.Character then table.insert(ignore, LocalPlayer.Character) end
        if workspace.CurrentCamera then table.insert(ignore, workspace.CurrentCamera) end
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = ignore

        -- a little past the target so the surface the game found is certainly inside the ray
        local result = workspace:Raycast(origin, offset.Unit * (offset.Magnitude + 1), params)
        local model = result and result.Instance:FindFirstAncestorOfClass("Model")
        local victim = model and Players:GetPlayerFromCharacter(model)
        if not victim then
            -- Wallbang: the bullet goes through walls the ray above stops at, so look along the same line at
            -- player characters only. Without this a wallbanged hit never counted and made no sound.
            local characters = {}
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= LocalPlayer and other.Character then characters[#characters + 1] = other.Character end
            end
            if #characters > 0 then
                local playersOnly = RaycastParams.new()
                playersOnly.FilterType = Enum.RaycastFilterType.Include
                playersOnly.FilterDescendantsInstances = characters
                local through = workspace:Raycast(origin, offset.Unit * (offset.Magnitude + 1), playersOnly)
                local throughModel = through and through.Instance:FindFirstAncestorOfClass("Model")
                local throughVictim = throughModel and Players:GetPlayerFromCharacter(throughModel)
                if throughVictim then result, victim = through, throughVictim end
            end
        end
        if not victim or victim == LocalPlayer then return end

        local queue = pendingHits[victim]
        if not queue then
            queue = {}
            pendingHits[victim] = queue
        end
        table.insert(queue, { expiry = os.clock() + HIT_WINDOW, position = result.Position })
    end

    ShotEvents.fire = onLocalShot

    local function consumePendingHit(player)
        local queue = pendingHits[player]
        if not queue then return false end
        local now = os.clock()
        while #queue > 0 and queue[1].expiry < now do table.remove(queue, 1) end
        if #queue == 0 then return false end
        return table.remove(queue, 1)
    end

    local function hookPlayer(player)
        if player == LocalPlayer then return end

        local function onCharacter(character)
            if hitConnections[player] then
                hitConnections[player]:Disconnect()
                hitConnections[player] = nil
            end
            local humanoid = character:WaitForChild("Humanoid", 5)
            if not humanoid then return end

            local previous = humanoid.Health
            hitConnections[player] = humanoid.HealthChanged:Connect(function(health)
                local damage = previous - health
                previous = health
                local pending = damage > 0 and consumePendingHit(player)
                if pending then
                    onHit(player, damage, health <= 0, pending.position)
                end
            end)
        end

        track(player.CharacterAdded:Connect(onCharacter))
        if player.Character then
            task.spawn(onCharacter, player.Character)
        end
    end

    for _, player in ipairs(Players:GetPlayers()) do hookPlayer(player) end
    track(Players.PlayerAdded:Connect(hookPlayer))
    track(Players.PlayerRemoving:Connect(function(player)
        pendingHits[player] = nil
        if hitConnections[player] then
            hitConnections[player]:Disconnect()
            hitConnections[player] = nil
        end
    end))

    end)()
    -- Unload cleanup -------------------------------------------------
    onUnload(function()
        for _, connection in pairs(hitConnections) do
            pcall(function() connection:Disconnect() end)
        end
        table.clear(hitConnections)

        for prop in pairs(lightingApplied) do
            pcall(function() LightingService[prop] = lightingRestore[prop] end)
        end
        restoreOriginalSky()
        for _, effect in ipairs({ bloom, colorCorrection, sunRays, atmosphere }) do
            pcall(function() effect:Destroy() end)
        end
        for _, original in ipairs(hiddenAtmospheres) do
            pcall(function() original.Parent = LightingService end)
        end

        if type(getgenv().HydrogenESP_Unload) == "function" then
            pcall(getgenv().HydrogenESP_Unload)
        end
    end)

    -- Local visuals (gun, body, self chams, camera, tracers) -------------------------
    -- Prison Life keeps the gun as a Tool inside the character and the arms are the
    -- character's own R6 limbs, so everything below works on those instances.
    local FORCEFIELD = Enum.Material.ForceField
    local SCOPE_FOV = 30 -- the game forces FOV 15 while scoped; never fight that

    local function getAlpha(name)
        local object = Options[name]
        return object and tonumber(object.Transparency) or 0
    end

    local function textureIdFor(name)
        local id = FORCEFIELD_TEXTURES[name]
        if id and id ~= "" then return id end
        return nil
    end

    -- Original property values, so every change can be undone exactly.
    local saved = setmetatable({}, { __mode = "k" })
    local SAVED_PROPS = {
        { "BasePart", { "Color", "Material", "Transparency" } },
        { "MeshPart", { "TextureID" } },
        { "SpecialMesh", { "TextureId" } },
        { "Decal", { "Transparency" } },
        { "Shirt", { "ShirtTemplate" } },
        { "Pants", { "PantsTemplate" } },
        { "ShirtGraphic", { "Graphic" } },
    }

    local function snapshot(inst)
        local data = saved[inst]
        if data then return data end
        data = {}
        for _, entry in ipairs(SAVED_PROPS) do
            if inst:IsA(entry[1]) then
                for _, name in ipairs(entry[2]) do
                    local ok, value = pcall(function() return inst[name] end)
                    if ok then data[name] = value end
                end
            end
        end
        saved[inst] = data
        return data
    end

    local function setProp(inst, name, value)
        local ok, current = pcall(function() return inst[name] end)
        if ok and current ~= value then
            pcall(function() inst[name] = value end)
        end
    end

    local function restoreInstance(inst)
        local data = saved[inst]
        if not data then return end
        for name, value in pairs(data) do setProp(inst, name, value) end
        saved[inst] = nil
    end

    local function restoreTree(root)
        if not root then return end
        restoreInstance(root)
        for _, inst in ipairs(root:GetDescendants()) do restoreInstance(inst) end
    end

    -- cfg: color, transparency, material, texture (asset id) and disableTextures
    local function styleInstance(inst, cfg)
        if inst:IsA("BasePart") then
            local data = snapshot(inst)
            if (data.Transparency or 0) < 1 then -- parts the game hides stay hidden
                setProp(inst, "Color", cfg.color or data.Color)
                setProp(inst, "Transparency", cfg.transparency or data.Transparency)
                setProp(inst, "Material", cfg.material or data.Material)
            end
            if inst:IsA("MeshPart") then
                if cfg.texture then
                    setProp(inst, "TextureID", cfg.texture)
                elseif cfg.disableTextures then
                    setProp(inst, "TextureID", "")
                else
                    setProp(inst, "TextureID", data.TextureID)
                end
            end
        elseif inst:IsA("SpecialMesh") then
            local data = snapshot(inst)
            if cfg.texture then
                setProp(inst, "TextureId", cfg.texture)
            elseif cfg.disableTextures then
                setProp(inst, "TextureId", "")
            else
                setProp(inst, "TextureId", data.TextureId)
            end
        elseif inst:IsA("Decal") then -- also covers Texture
            local data = snapshot(inst)
            setProp(inst, "Transparency", cfg.disableTextures and 1 or data.Transparency)
        elseif inst:IsA("Shirt") then
            local data = snapshot(inst)
            setProp(inst, "ShirtTemplate", cfg.disableTextures and "" or data.ShirtTemplate)
        elseif inst:IsA("Pants") then
            local data = snapshot(inst)
            setProp(inst, "PantsTemplate", cfg.disableTextures and "" or data.PantsTemplate)
        elseif inst:IsA("ShirtGraphic") then
            local data = snapshot(inst)
            setProp(inst, "Graphic", cfg.disableTextures and "" or data.Graphic)
        end
    end

    local updateLocalVisuals, updateBlur
    ;(function()
    -- Gun: the equipped Tool ---------------------------------------------
    local function gunConfig()
        local colorOn = getFlag("viewmodel_body_color", false)
        local material = safeEnumMaterial(getFlag("viewmodel_material_value", "Default"))
        local transparency = getAlpha("viewmodel_body_color_value")
        local disable = getFlag("viewmodel_disable_textures", false)
        if not (colorOn or material or transparency > 0 or disable) then return nil end

        local cfg = { disableTextures = disable, material = material }
        if colorOn then cfg.color = getColor("viewmodel_body_color_value", Color3.fromRGB(202, 161, 13)) end
        if transparency > 0 then cfg.transparency = transparency end
        if cfg.material == FORCEFIELD then
            cfg.texture = textureIdFor(getFlag("viewmodel_texture_value", "Disabled"))
        end
        return cfg
    end

    -- Gun chams: a Highlight on the equipped Tool (fill and outline alpha come from the pickers)
    local gunHighlight
    local function destroyGunHighlight()
        if gunHighlight then
            pcall(function() gunHighlight:Destroy() end)
            gunHighlight = nil
        end
    end

    local function updateGunChams(tool)
        if not (tool and getFlag("viewmodel_chams", false)) then
            destroyGunHighlight()
            return
        end
        if not gunHighlight or gunHighlight.Parent ~= tool then
            destroyGunHighlight()
            gunHighlight = Instance.new("Highlight")
            gunHighlight.Name = "TS_GunChams"
            gunHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            pcall(function() gunHighlight.Adornee = tool end) -- falls back to highlighting its parent
            gunHighlight.Parent = tool
        end
        gunHighlight.FillColor = getColor("viewmodel_chams_color", Color3.fromRGB(120, 80, 255))
        gunHighlight.FillTransparency = getAlpha("viewmodel_chams_color")
        gunHighlight.OutlineColor = getColor("viewmodel_chams_color2", Color3.fromRGB(255, 255, 255))
        gunHighlight.OutlineTransparency = getAlpha("viewmodel_chams_color2")
    end

    local styledTool
    local function updateGun()
        local character = LocalPlayer.Character
        local tool = character and character:FindFirstChildOfClass("Tool")
        local cfg = gunConfig()

        if styledTool and styledTool ~= tool then
            restoreTree(styledTool)
            styledTool = nil
        end

        updateGunChams(tool)
        if not tool then return end

        if cfg then
            styledTool = tool
            for _, inst in ipairs(tool:GetDescendants()) do styleInstance(inst, cfg) end
        elseif styledTool then
            restoreTree(styledTool)
            styledTool = nil
        end
    end

    -- Body: the character without its Tool and accessories ------------------------
    local function isBodyInstance(inst)
        return not inst:FindFirstAncestorOfClass("Tool") and not inst:FindFirstAncestorOfClass("Accessory")
    end

    local function bodyConfig()
        local forceOn = getFlag("arm_material", false)
        local disable = getFlag("arm_disable_textures", false)
        if not (forceOn or disable) then return nil end

        -- The forcefield sits under shirts and pants, so the clothing templates are
        -- removed whenever it is on; that way the material always shows.
        local cfg = { disableTextures = disable or forceOn }
        if forceOn then
            cfg.material = FORCEFIELD
            cfg.color = getColor("arm_material_color", Color3.fromRGB(255, 255, 255))
            cfg.transparency = getAlpha("arm_material_color")
            cfg.texture = textureIdFor(getFlag("arm_material_texture", "Disabled"))
        end
        return cfg
    end

    local styledCharacter
    local accessoriesHidden = false
    local function updateBody()
        local character = LocalPlayer.Character
        if styledCharacter ~= character then styledCharacter = nil end
        if not character then
            accessoriesHidden = false
            return
        end

        local cfg = bodyConfig()
        if cfg then
            styledCharacter = character
            for _, inst in ipairs(character:GetDescendants()) do
                if isBodyInstance(inst) then styleInstance(inst, cfg) end
            end
        elseif styledCharacter then
            for _, inst in ipairs(character:GetDescendants()) do
                if isBodyInstance(inst) then restoreInstance(inst) end
            end
            styledCharacter = nil
        end

        if getFlag("arm_remove_accessories", false) then
            accessoriesHidden = true
            for _, accessory in ipairs(character:GetChildren()) do
                if accessory:IsA("Accessory") then
                    for _, inst in ipairs(accessory:GetDescendants()) do
                        if inst:IsA("BasePart") or inst:IsA("Decal") then
                            snapshot(inst)
                            setProp(inst, "Transparency", 1)
                        end
                    end
                end
            end
        elseif accessoriesHidden then
            accessoriesHidden = false
            for _, accessory in ipairs(character:GetChildren()) do
                if accessory:IsA("Accessory") then restoreTree(accessory) end
            end
        end
    end

    -- Self chams (Highlight only) --------------------------------------------
    local selfHighlight
    local function destroySelfHighlight()
        if selfHighlight then
            pcall(function() selfHighlight:Destroy() end)
            selfHighlight = nil
        end
    end

    local function updateSelfChams()
        local character = LocalPlayer.Character
        if not (character and getFlag("Self_Chams", false)) then
            destroySelfHighlight()
            return
        end
        if not selfHighlight or selfHighlight.Parent ~= character then
            destroySelfHighlight()
            selfHighlight = Instance.new("Highlight")
            selfHighlight.Name = "TS_SelfChams"
            selfHighlight.Adornee = character
            selfHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            selfHighlight.Parent = character
        end
        selfHighlight.FillColor = getColor("Self_ChamsColor1", Color3.fromRGB(80, 160, 255))
        selfHighlight.OutlineColor = getColor("Self_ChamsColor2", Color3.fromRGB(255, 255, 255))
        selfHighlight.FillTransparency = getAlpha("Self_ChamsColor1")
        selfHighlight.OutlineTransparency = getAlpha("Self_ChamsColor2")
    end

    function updateLocalVisuals()
        updateGun()
        updateBody()
        updateSelfChams()
    end

    -- Camera: FOV ---------------------------------------------
    -- Bound after every other camera script and run every frame, so the values stick.
    local CAMERA_STEP = "TS_Camera"
    pcall(function() RunService:UnbindFromRenderStep(CAMERA_STEP) end)
    local fovOverridden = false
    local baseFov = 70

    local function cameraStep()
        local cam = workspace.CurrentCamera
        if not cam then return end

        if getFlag("camera_fov_changer", false) then
            local current = cam.FieldOfView
            if not fovOverridden then
                fovOverridden = true
                baseFov = current > SCOPE_FOV and current or 70
            end
            if current > SCOPE_FOV then
                cam.FieldOfView = getFlag("camera_fov_changer_amount", 100)
            end
        elseif fovOverridden then
            fovOverridden = false
            if cam.FieldOfView > SCOPE_FOV then cam.FieldOfView = baseFov end
        end
    end
    RunService:BindToRenderStep(CAMERA_STEP, Enum.RenderPriority.Last.Value, cameraStep)

    function updateBlur()
        local cam = workspace.CurrentCamera
        if not cam then return end
        local blur = getFlag("camera_blur", 0)
        local effect = cam:FindFirstChild("CameraBlur")
        if blur > 0 then
            if not effect then
                effect = Instance.new("BlurEffect")
                effect.Name = "CameraBlur"
                effect.Parent = cam
            end
            effect.Size = blur
        elseif effect then
            effect:Destroy()
        end
    end

    onUnload(function()
        pcall(function() RunService:UnbindFromRenderStep(CAMERA_STEP) end)
        local cam = workspace.CurrentCamera
        if fovOverridden and cam then pcall(function() cam.FieldOfView = baseFov end) end
        if styledTool then restoreTree(styledTool) end
        if styledCharacter then
            for _, inst in ipairs(styledCharacter:GetDescendants()) do restoreInstance(inst) end
        end
        local character = LocalPlayer.Character
        if character then
            for _, accessory in ipairs(character:GetChildren()) do
                if accessory:IsA("Accessory") then restoreTree(accessory) end
            end
        end
        destroySelfHighlight()
        destroyGunHighlight()
        local blurEffect = cam and cam:FindFirstChild("CameraBlur")
        if blurEffect then pcall(function() blurEffect:Destroy() end) end
    end)

    end)()
    local updateTracers
    ;(function()
    -- Bullet tracers (your own shots only) ---------------------------------------
    -- The game draws every tracer through SharedModules.GunTracers: your shots come from
    -- GunController with the equipped tool's Muzzle position as the origin, other players'
    -- shots come from ClientReplicator. The create* functions are wrapped. A shot whose origin is
    -- your own Muzzle is reported to the hit feedback above and, when tracers are on, drawn as a
    -- Beam instead; every other call goes to the original untouched.
    local TRACER_FUNCTIONS = { "createBullet", "createSniper", "createTaser" }
    local activeTracers = {}
    local tracerModule
    local tracerOriginals = {}

    local function isLocalShot(origin)
        local character = LocalPlayer.Character
        local tool = character and character:FindFirstChildOfClass("Tool")
        local muzzle = tool and tool:FindFirstChild("Muzzle")
        return muzzle ~= nil and (muzzle.Position - origin).Magnitude < 0.5
    end

    local function destroyTracer(tracer)
        pcall(function() tracer.beam:Destroy() end)
        pcall(function() tracer.a0:Destroy() end)
        pcall(function() tracer.a1:Destroy() end)
    end

    local function drawTracer(origin, target)
        local preset = TRACER_PRESETS[getFlag("tracers_style", "Obelus")] or TRACER_PRESETS.Obelus
        local width = getFlag("tracers_width", 1)
        local glow = getFlag("tracers_glow", 1)
        local expand = getFlag("tracers_expand", true)
        local terrain = workspace.Terrain

        local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
        a0.Parent = terrain
        a0.WorldPosition = origin
        a1.Parent = terrain
        a1.WorldPosition = expand and origin or target

        local beam = Instance.new("Beam")
        beam.Attachment0 = a0
        beam.Attachment1 = a1
        beam.Color = ColorSequence.new(getColor("tracers_color", Color3.fromRGB(255, 255, 255)))
        if preset.Texture ~= "" then beam.Texture = preset.Texture end
        beam.Transparency = preset.Transparency
        beam.LightEmission = preset.LightEmission
        beam.LightInfluence = preset.LightInfluence
        beam.Segments = preset.Segments
        beam.TextureLength = preset.TextureLength
        beam.TextureMode = preset.TextureMode
        beam.TextureSpeed = preset.TextureSpeed
        beam.Width0 = preset.Width0 * width
        beam.Width1 = preset.Width1 * width
        beam.FaceCamera = preset.FaceCamera
        -- glow 1 keeps the preset's brightness; higher values scale it up steeply (10000^((g-1)/20))
        pcall(function() beam.Brightness = preset.Brightness * 10000 ^ ((glow - 1) / 20) end)
        beam.Parent = terrain

        table.insert(activeTracers, {
            a0 = a0, a1 = a1, beam = beam, origin = origin, target = target,
            age = 0, life = math.max(getFlag("tracers_duration", 0.5), 0.05), fade = math.max(getFlag("tracers_fade", 0.35), 0),
            base = preset.BaseTransparency, expand = expand,
            pos = expand and 0 or 1, vel = 0,
            speed = getFlag("tracers_expand_speed", 18), damper = 0.7,
        })
    end

    -- Visible for `life` seconds, then fades over `fade`. With "Expand" the far end runs from the
    -- muzzle to the hit on a damped spring (speed 18, damping 0.7 by default) and overshoots slightly.
    function updateTracers(dt)
        if #activeTracers == 0 then return end
        dt = math.min(dt, 1 / 20)
        for index = #activeTracers, 1, -1 do
            local tracer = activeTracers[index]
            tracer.age += dt
            if tracer.expand then
                local steps = math.max(1, math.ceil(dt * 120))
                local h = dt / steps
                for _ = 1, steps do
                    local accel = tracer.speed * tracer.speed * (1 - tracer.pos) - 2 * tracer.damper * tracer.speed * tracer.vel
                    tracer.vel += accel * h
                    tracer.pos += tracer.vel * h
                end
                tracer.a1.WorldPosition = tracer.origin:Lerp(tracer.target, tracer.pos)
            end

            if tracer.age >= tracer.life + tracer.fade then
                destroyTracer(tracer)
                table.remove(activeTracers, index)
            elseif tracer.age >= tracer.life then
                local progress = tracer.fade > 0 and math.clamp((tracer.age - tracer.life) / tracer.fade, 0, 1) or 1
                tracer.beam.Transparency = NumberSequence.new(tracer.base + (1 - tracer.base) * progress)
            end
        end
    end

    local function handleLocalShot(origin, target)
        pcall(onLocalShot, origin, target)
        return getFlag("tracers_enabled", false) and pcall(drawTracer, origin, target)
    end

    local function installTracerHook()
        local module
        local found = pcall(function()
            local shared = game:GetService("ReplicatedStorage"):WaitForChild("SharedModules", 10)
            module = require(shared:WaitForChild("GunTracers", 10))
        end)
        if not found or type(module) ~= "table" then return false end

        -- put back anything an earlier run replaced, so wrappers never stack
        local previous = getgenv().TS_TracerOriginals
        if type(previous) == "table" then
            for name, original in pairs(previous) do module[name] = original end
        end
        getgenv().TS_TracerOriginals = {}

        for _, name in ipairs(TRACER_FUNCTIONS) do
            local original = module[name]
            if type(original) == "function" then
                getgenv().TS_TracerOriginals[name] = original
                tracerOriginals[name] = original
                module[name] = function(origin, target, ...)
                    if typeof(origin) == "Vector3" and typeof(target) == "Vector3" and isLocalShot(origin) then
                        if handleLocalShot(origin, target) then return end
                    end
                    return original(origin, target, ...)
                end
            end
        end
        tracerModule = module
        return true
    end

    -- Fallback when the module cannot be required: watch for the game's RayPart and swap it.
    local function watchRayParts()
        local cam = workspace.CurrentCamera
        if not cam then return end
        track(cam.ChildAdded:Connect(function(child)
            if child.Name ~= "RayPart" then return end
            local look = child.CFrame.LookVector
            local half = child.Size.Z / 2
            local origin = child.Position - look * half
            local target = child.Position + look * half
            if isLocalShot(origin) and handleLocalShot(origin, target) then
                child:Destroy()
            end
        end))
    end

    task.spawn(function()
        if not installTracerHook() then
            warn("Tracers: GunTracers module not found, watching RayParts instead")
            watchRayParts()
        end
    end)

    onUnload(function()
        if tracerModule then
            for name, original in pairs(tracerOriginals) do tracerModule[name] = original end
        end
        getgenv().TS_TracerOriginals = nil
        for _, tracer in ipairs(activeTracers) do destroyTracer(tracer) end
        table.clear(activeTracers)
        table.clear(pendingHits)
    end)

    end)()
    local updateCrosshair
    ;(function()
    -- Custom crosshair -----------------------------------------------------------
    -- Four bars, each an outline frame with a fill frame inside, laid out around the mouse and
    -- rotated about it. The bars are horizontal frames turned by 0 / 90 / 180 / -90 degrees.
    local ARM_NAMES = { "Top", "Bottom", "Left", "Right" }
    local ARM_DIRECTIONS = { Top = -90, Bottom = 90, Left = 180, Right = 0 }
    local crosshairGui, crosshairContainer
    local crosshairArms = {}
    local cursorHidden, cursorOriginal = false, true

    local function guiParent()
        local parent
        pcall(function() if gethui then parent = gethui() end end)
        return parent or game:GetService("CoreGui")
    end

    local function ensureCrosshair()
        if crosshairGui then return true end
        local ok = pcall(function()
            local gui = Instance.new("ScreenGui")
            gui.Name = "TS_Crosshair"
            gui.DisplayOrder = 90 -- under the menu
            gui.IgnoreGuiInset = true
            gui.ResetOnSpawn = false
            gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
            gui.Enabled = false
            gui.Parent = guiParent()

            local container = Instance.new("Frame")
            container.AnchorPoint = Vector2.new(0.5, 0.5)
            container.Size = UDim2.fromOffset(0, 0)
            container.BackgroundTransparency = 1
            container.Parent = gui

            for _, name in ipairs(ARM_NAMES) do
                local outline = Instance.new("Frame")
                outline.Name = name
                outline.AnchorPoint = Vector2.new(0.5, 0.5)
                outline.BorderSizePixel = 0
                outline.Parent = container

                local fill = Instance.new("Frame")
                fill.AnchorPoint = Vector2.new(0.5, 0.5)
                fill.Position = UDim2.fromScale(0.5, 0.5)
                fill.BorderSizePixel = 0
                fill.Parent = outline

                crosshairArms[name] = { outline = outline, fill = fill }
            end
            crosshairGui, crosshairContainer = gui, container
        end)
        return ok and crosshairGui ~= nil
    end

    function updateCrosshair()
        local enabled = getFlag("crosshair_enabled", false)

        if enabled and getFlag("crosshair_hide_cursor", false) then
            if not cursorHidden then
                cursorOriginal = UserInputService.MouseIconEnabled
                cursorHidden = true
            end
            UserInputService.MouseIconEnabled = false
        elseif cursorHidden then
            UserInputService.MouseIconEnabled = cursorOriginal
            cursorHidden = false
        end

        if not enabled then
            if crosshairGui then crosshairGui.Enabled = false end
            return
        end
        if not ensureCrosshair() then return end
        crosshairGui.Enabled = true

        local mouse = UserInputService:GetMouseLocation()
        crosshairContainer.Position = UDim2.fromOffset(math.round(mouse.X), math.round(mouse.Y))

        local now = os.clock()
        local angle = getFlag("crosshair_rotation_angle", 0)
        if getFlag("crosshair_rotation", false) then
            angle = (angle + getFlag("crosshair_rotation_speed", 90) * now) % 360
        end

        local gap = getFlag("crosshair_gap", 6)
        if getFlag("crosshair_spread", false) then
            local low, high = getFlag("crosshair_spread_min", 4), getFlag("crosshair_spread_max", 16)
            local pulse = 0.5 - 0.5 * math.cos(now * getFlag("crosshair_spread_speed", 3))
            gap += low + (high - low) * pulse
        end

        local length = math.max(1, getFlag("crosshair_length", 12))
        local thickness = math.max(1, getFlag("crosshair_thickness", 2))
        local outlineOn = getFlag("crosshair_outline", false)
        local outlineSize = getFlag("crosshair_outline_thickness", 1)
        local color = getColor("crosshair_color", Color3.fromRGB(255, 255, 255))
        local outlineColor = getColor("crosshair_outline_color", Color3.fromRGB(0, 0, 0))
        local middle = gap + length / 2

        for _, name in ipairs(ARM_NAMES) do
            local arm = crosshairArms[name]
            local visible = getFlag("crosshair_arm_" .. string.lower(name), true)
            arm.outline.Visible = visible
            if visible then
                local rotation = angle + ARM_DIRECTIONS[name]
                local radians = math.rad(rotation)
                arm.outline.Position = UDim2.fromOffset(math.cos(radians) * middle, math.sin(radians) * middle)
                arm.outline.Rotation = rotation
                arm.fill.Size = UDim2.fromOffset(length, thickness)
                arm.fill.BackgroundColor3 = color
                if outlineOn then
                    arm.outline.BackgroundTransparency = 0
                    arm.outline.BackgroundColor3 = outlineColor
                    arm.outline.Size = UDim2.fromOffset(length + outlineSize * 2, thickness + outlineSize * 2)
                else
                    arm.outline.BackgroundTransparency = 1
                    arm.outline.Size = UDim2.fromOffset(length, thickness)
                end
            end
        end
    end

    onUnload(function()
        if cursorHidden then
            pcall(function() UserInputService.MouseIconEnabled = cursorOriginal end)
            cursorHidden = false
        end
        if crosshairGui then pcall(function() crosshairGui:Destroy() end) end
        crosshairGui, crosshairContainer = nil, nil
        table.clear(crosshairArms)
    end)

    end)()
    local updateWeather
    ;(function()
    -- Weather + lightning ----------------------------------------------------------
    -- Particle emitters on an invisible part that follows the camera, plus optional lightning
    -- strikes around you while the Rain preset is selected.
    local WEATHER_SPECS = {
        Snow = {
            { Texture = "rbxasset://textures/particles/smoke_main.dds", TransparencyMax = 0.15, LifetimeMin = 6, LifetimeMax = 9,
              BaseRate = 220, SpeedMin = 6, SpeedMax = 10, SizeStart = 0.35, SizeEnd = 0.25, BaseSpread = 0.4, BaseAccelerationY = -1,
              RotationMin = 0, RotationMax = 360, RotationSpeedMin = -40, RotationSpeedMax = 40 },
            { Texture = "rbxasset://textures/particles/sparkles_main.dds", TransparencyMax = 0.35, LifetimeMin = 6, LifetimeMax = 9,
              BaseRate = 60, SpeedMin = 5, SpeedMax = 8, SizeStart = 0.2, SizeEnd = 0.15, BaseSpread = 0.6, BaseAccelerationY = -0.5,
              RotationMin = 0, RotationMax = 360, RotationSpeedMin = -40, RotationSpeedMax = 40 },
        },
        Rain = {
            { Texture = "rbxasset://textures/particles/smoke_main.dds", TransparencyMax = 0.35, LifetimeMin = 1.2, LifetimeMax = 1.8,
              BaseRate = 600, SpeedMin = 70, SpeedMax = 90, SizeStart = 0.12, SizeEnd = 0.1, BaseSpread = 0.05, BaseAccelerationY = -40,
              RotationMin = 0, RotationMax = 0, RotationSpeedMin = 0, RotationSpeedMax = 0,
              Orientation = Enum.ParticleOrientation.VelocityParallel },
        },
        Blizzard = {
            { Texture = "rbxasset://textures/particles/smoke_main.dds", TransparencyMax = 0.1, LifetimeMin = 3, LifetimeMax = 5,
              BaseRate = 700, SpeedMin = 18, SpeedMax = 28, SizeStart = 0.3, SizeEnd = 0.2, BaseSpread = 0.8, BaseAccelerationY = -6,
              RotationMin = 0, RotationMax = 360, RotationSpeedMin = -40, RotationSpeedMax = 40 },
            { Texture = "rbxasset://textures/particles/smoke_main.dds", TransparencyMax = 0.75, LifetimeMin = 3, LifetimeMax = 5,
              BaseRate = 120, SpeedMin = 14, SpeedMax = 22, SizeStart = 3, SizeEnd = 5, BaseSpread = 1, BaseAccelerationY = -2,
              RotationMin = 0, RotationMax = 360, RotationSpeedMin = -40, RotationSpeedMax = 40 },
        },
    }
    local LIGHTNING_RADIUS_MIN = 20   -- strikes land 20-60 studs from you
    local LIGHTNING_GROUND_DROP = 40  -- used when the ground ray finds nothing
    local LIGHTNING_RAY_LENGTH = 1000
    local LIGHTNING_JITTER = 30
    local LIGHTNING_HOLD, LIGHTNING_DISSIPATE = 0.12, 0.35

    local weatherPart, weatherEmitters, weatherBuiltPreset, weatherSignature
    local bolts = {}
    local nextStrike = 0

    local function destroyWeather()
        for _, entry in ipairs(weatherEmitters or {}) do pcall(function() entry.emitter:Destroy() end) end
        weatherEmitters = nil
        if weatherPart then pcall(function() weatherPart:Destroy() end) end
        weatherPart, weatherBuiltPreset, weatherSignature = nil, nil, nil
    end

    local function buildWeather(preset)
        destroyWeather()
        local specs = WEATHER_SPECS[preset]
        if not specs then return end

        weatherPart = Instance.new("Part")
        weatherPart.Name = "TS_WeatherEmitter"
        weatherPart.Anchored = true
        weatherPart.CanCollide = false
        weatherPart.CanQuery = false
        weatherPart.CanTouch = false
        weatherPart.Transparency = 1
        weatherPart.Size = Vector3.new(140, 1, 140)
        weatherPart.Parent = workspace

        weatherEmitters = {}
        for _, spec in ipairs(specs) do
            local emitter = Instance.new("ParticleEmitter")
            emitter.Texture = spec.Texture
            emitter.Lifetime = NumberRange.new(spec.LifetimeMin, spec.LifetimeMax)
            emitter.Rotation = NumberRange.new(spec.RotationMin, spec.RotationMax)
            emitter.RotSpeed = NumberRange.new(spec.RotationSpeedMin, spec.RotationSpeedMax)
            emitter.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1),
                NumberSequenceKeypoint.new(0.15, spec.TransparencyMax),
                NumberSequenceKeypoint.new(0.85, spec.TransparencyMax),
                NumberSequenceKeypoint.new(1, 1),
            })
            emitter.LockedToPart = false
            -- Particles are launched out of the emitter's face: the default is the top face, which
            -- sent them upward before gravity pulled them back. The bottom face makes them fall.
            emitter.EmissionDirection = Enum.NormalId.Bottom
            if spec.Orientation then emitter.Orientation = spec.Orientation end
            emitter.Parent = weatherPart
            table.insert(weatherEmitters, { emitter = emitter, spec = spec })
        end
        weatherBuiltPreset = preset
        weatherSignature = nil
    end

    -- Writes the emitter settings, but only when one of them changed.
    local function applyWeatherSettings()
        local intensity = getFlag("weather_intensity", 1)
        local speed = getFlag("weather_speed", 1)
        local size = getFlag("weather_size", 1)
        local glow = getFlag("weather_glow", 0)
        local spread = getFlag("weather_spread", 1)
        local color = getColor("weather_color", Color3.fromRGB(200, 200, 220))
        local windStrength = getFlag("weather_wind_strength", 2)
        local windAngle = getFlag("weather_wind_angle", 45)

        local signature = table.concat({ intensity, speed, size, glow, spread, tostring(color), windStrength, windAngle }, "|")
        if signature == weatherSignature then return end
        weatherSignature = signature

        local radians = math.rad(windAngle)
        local windX, windZ = math.sin(radians) * windStrength, math.cos(radians) * windStrength
        for _, entry in ipairs(weatherEmitters) do
            local emitter, spec = entry.emitter, entry.spec
            emitter.Rate = spec.BaseRate * intensity
            emitter.Speed = NumberRange.new(spec.SpeedMin * speed, spec.SpeedMax * speed)
            emitter.Size = NumberSequence.new(spec.SizeStart * size, spec.SizeEnd * size)
            emitter.LightEmission = glow
            emitter.SpreadAngle = Vector2.new(spec.BaseSpread * spread, spec.BaseSpread * spread)
            emitter.Color = ColorSequence.new(color)
            emitter.Acceleration = Vector3.new(windX, spec.BaseAccelerationY, windZ)
        end
    end

    local function spawnBolt(fromPos, toPos)
        local color = getColor("weather_lightning_color", Color3.fromRGB(200, 220, 255))
        local thickness = getFlag("weather_lightning_thickness", 0.2)
        local jagged = getFlag("weather_lightning_jagged", 6)
        local flash = getFlag("weather_lightning_flash", 4)
        local segments = 8

        local folder = Instance.new("Folder")
        folder.Name = "TS_LightningBolt"
        folder.Parent = workspace

        local points = { fromPos }
        for i = 1, segments - 1 do
            local base = fromPos:Lerp(toPos, i / segments)
            table.insert(points, base + Vector3.new(
                (math.random() - 0.5) * jagged,
                (math.random() - 0.5) * jagged * 0.5,
                (math.random() - 0.5) * jagged))
        end
        table.insert(points, toPos)

        local attachments = {}
        for _, point in ipairs(points) do
            local attachment = Instance.new("Attachment")
            attachment.Parent = workspace.Terrain
            attachment.WorldPosition = point
            table.insert(attachments, attachment)
        end
        for i = 1, #attachments - 1 do
            local beam = Instance.new("Beam")
            beam.Attachment0 = attachments[i]
            beam.Attachment1 = attachments[i + 1]
            beam.Color = ColorSequence.new(color)
            beam.Width0 = thickness
            beam.Width1 = thickness * 0.7
            beam.FaceCamera = true
            beam.LightEmission = 1
            beam.LightInfluence = 0
            pcall(function() beam.Brightness = 8 end)
            beam.Transparency = NumberSequence.new(0)
            beam.Parent = folder
        end

        -- flash at the impact point
        local anchor = Instance.new("Part")
        anchor.Anchored = true
        anchor.CanCollide = false
        anchor.CanQuery = false
        anchor.CanTouch = false
        anchor.Transparency = 1
        anchor.Size = Vector3.new(1, 1, 1)
        anchor.Position = toPos
        anchor.Parent = folder
        local light = Instance.new("PointLight")
        light.Color = color:Lerp(Color3.fromRGB(255, 255, 255), 0.3)
        light.Brightness = flash
        light.Range = 40
        light.Parent = anchor

        table.insert(bolts, { folder = folder, attachments = attachments, light = light, flash = flash, born = os.clock() })
    end

    local function strikeNearCamera()
        local cam = workspace.CurrentCamera
        if not cam then return end
        local position = cam.CFrame.Position
        local height = getFlag("weather_height", 40)

        local angle = math.random() * math.pi * 2
        local radius = LIGHTNING_RADIUS_MIN + math.random() * 40
        local x = position.X + math.cos(angle) * radius
        local z = position.Z + math.sin(angle) * radius

        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        if LocalPlayer.Character then params.FilterDescendantsInstances = { LocalPlayer.Character } end

        local groundY = position.Y - LIGHTNING_GROUND_DROP
        local hit = workspace:Raycast(Vector3.new(x, position.Y + height, z), Vector3.new(0, -LIGHTNING_RAY_LENGTH, 0), params)
        if hit then groundY = hit.Position.Y end

        local from = Vector3.new(
            x + (math.random() - 0.5) * LIGHTNING_JITTER,
            groundY + height,
            z + (math.random() - 0.5) * LIGHTNING_JITTER)
        spawnBolt(from, Vector3.new(x, groundY, z))
    end

    local function destroyBolt(bolt)
        for _, attachment in ipairs(bolt.attachments) do pcall(function() attachment:Destroy() end) end
        pcall(function() bolt.folder:Destroy() end)
    end

    local function updateBolts()
        if #bolts == 0 then return end
        local now = os.clock()
        for index = #bolts, 1, -1 do
            local bolt = bolts[index]
            local age = now - bolt.born
            if age >= LIGHTNING_HOLD + LIGHTNING_DISSIPATE + 0.2 then
                destroyBolt(bolt)
                table.remove(bolts, index)
            elseif age > LIGHTNING_HOLD then
                bolt.light.Brightness = bolt.flash * math.max(0, 1 - (age - LIGHTNING_HOLD) / LIGHTNING_DISSIPATE)
            end
        end
    end

    function updateWeather()
        updateBolts()

        if not getFlag("weather_enabled", false) then
            if weatherPart then destroyWeather() end
            return
        end

        local preset = getFlag("weather_preset", "Rain")
        if not weatherPart or weatherBuiltPreset ~= preset then buildWeather(preset) end
        if not weatherPart then return end
        applyWeatherSettings()

        local cam = workspace.CurrentCamera
        if cam then
            weatherPart.Position = cam.CFrame.Position + Vector3.new(0, getFlag("weather_height", 40), 0)
        end

        if preset == "Rain" and getFlag("weather_lightning", false) then
            local now = os.clock()
            if now >= nextStrike then
                nextStrike = now + getFlag("weather_lightning_interval", 4) * (0.6 + math.random() * 0.8)
                strikeNearCamera()
            end
        end
    end

    onUnload(function()
        destroyWeather()
        for _, bolt in ipairs(bolts) do destroyBolt(bolt) end
        table.clear(bolts)
    end)

    -- end local visuals

    end)()
    -- Avatar changer (Spoofer tab) -----------------------------------------------------
    -- Rebuilds YOUR character's look from another user's avatar. It is client side only: you
    -- see the new look, everyone else still sees your real avatar. R6 limbs (CharacterMesh,
    -- Korblox) and headless are handled. The Spoofer tab's buttons call SpooferActions.
    ;(function()
        local HEADLESS_IDS = { [15093053680] = true, [134082579] = true, [4562128874] = true }
        local KORBLOX_LEFT, KORBLOX_RIGHT = 139607673, 139607718
        local lastUid
        local busy = false
        local wornKeys = {} -- accessories already worn in this apply, so the same item is never added twice
        local currentDesc -- the HumanoidDescription being applied (its scales size accessories)

        -- accessories loaded straight from their asset are unscaled; scale them like the avatar's description
        local function scaleAccessory(copy, factor)
            if math.abs(factor - 1) < 0.01 then return end
            for _, d in ipairs(copy:GetDescendants()) do
                if d:IsA("BasePart") then
                    d.Size = d.Size * factor
                elseif d:IsA("SpecialMesh") then
                    d.Scale = d.Scale * factor
                elseif d:IsA("Attachment") then
                    d.CFrame = CFrame.new(d.CFrame.Position * factor) * d.CFrame.Rotation
                end
            end
        end

        local function descFactor(isHead)
            local desc = currentDesc
            if not desc then return 1 end
            local ok, value = pcall(function()
                if isHead then return desc.HeadScale end
                return (desc.WidthScale + desc.HeightScale + desc.DepthScale) / 3
            end)
            return ok and tonumber(value) or 1
        end

        -- identity of an accessory: name + mesh + texture (the same hat from the model and from the description match)
        local function accessoryKey(acc)
            local handle = acc:FindFirstChild("Handle")
            local mesh, texture = "", ""
            if handle then
                pcall(function()
                    local special = handle:FindFirstChildWhichIsA("SpecialMesh")
                    if special then
                        mesh, texture = tostring(special.MeshId), tostring(special.TextureId)
                    elseif handle:IsA("MeshPart") then
                        mesh, texture = tostring(handle.MeshId), tostring(handle.TextureID)
                    end
                end)
            end
            return string.lower(acc.Name) .. "|" .. mesh .. "|" .. texture
        end

        -- keeps the first copy of every accessory and destroys the rest
        local function dedupeAccessories(char)
            local seen, removed = {}, 0
            for _, child in ipairs(char:GetChildren()) do
                if child:IsA("Accessory") then
                    local key = accessoryKey(child)
                    if seen[key] then
                        pcall(function() child:Destroy() end)
                        removed += 1
                    else
                        seen[key] = true
                    end
                end
            end
            return removed
        end

        local function notify(message)
            Library:Notify(message, 4)
        end

        -- UserId number, username, @username or a profile URL
        local function resolveUserId(input)
            if input == nil then return nil end
            local s = tostring(input):gsub("^%s+", ""):gsub("%s+$", "")
            if s == "" then return nil end

            local fromUrl = s:match("users/(%d+)") or s:match("userId=(%d+)")
            if fromUrl then
                local n = tonumber(fromUrl)
                if n and n > 0 then return math.floor(n) end
            end

            local digits = s:gsub(",", ""):match("^(%d+)$")
            if digits then
                local n = tonumber(digits)
                if n and n > 0 then return math.floor(n) end
            end

            local lower = s:lower()
            for _, p in ipairs(Players:GetPlayers()) do
                if p.Name:lower() == lower or p.DisplayName:lower() == lower then
                    return p.UserId
                end
            end

            local ok, id = pcall(function() return Players:GetUserIdFromNameAsync(s) end)
            if ok and typeof(id) == "number" and id > 0 then return math.floor(id) end

            if s:sub(1, 1) == "@" then
                ok, id = pcall(function() return Players:GetUserIdFromNameAsync(s:sub(2)) end)
                if ok and typeof(id) == "number" and id > 0 then return math.floor(id) end
            end
            return nil
        end

        -- removes the current look so a new one starts clean
        local function stripAppearance(char)
            if not char then return end
            for _, v in ipairs(char:GetChildren()) do
                if v:IsA("Accessory") or v:IsA("Shirt") or v:IsA("Pants") or v:IsA("ShirtGraphic")
                    or v:IsA("CharacterMesh") or v:IsA("BodyColors") or v:IsA("Clothing") then
                    pcall(function() v:Destroy() end)
                end
            end
            for _, name in ipairs({ "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }) do
                local limb = char:FindFirstChild(name)
                if limb then
                    for _, d in ipairs(limb:GetChildren()) do
                        if d:IsA("SpecialMesh") then pcall(function() d:Destroy() end) end
                    end
                    limb.Transparency = 0
                end
            end
        end

        local function wearAccessory(char, acc, fromAsset)
            if not char or not acc or not acc:IsA("Accessory") then return false end
            local key = accessoryKey(acc)
            if wornKeys[key] then return false end
            local ok = pcall(function()
                local copy = acc:Clone()
                for _, part in ipairs(copy:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.Anchored = false
                        part.CanCollide = false
                        part.Massless = true
                    end
                end
                local handle = copy:FindFirstChild("Handle")
                if not handle then
                    copy:Destroy()
                    return
                end

                local attachment = handle:FindFirstChildWhichIsA("Attachment")
                local targetAttachment
                if attachment then
                    for _, d in ipairs(char:GetDescendants()) do
                        if d:IsA("Attachment") and d.Name == attachment.Name and not d:IsDescendantOf(copy) then
                            targetAttachment = d
                            break
                        end
                    end
                end

                if fromAsset then
                    local isHead = targetAttachment ~= nil and targetAttachment.Parent ~= nil and targetAttachment.Parent.Name == "Head"
                    scaleAccessory(copy, descFactor(isHead))
                end

                copy.Parent = char
                local weld = Instance.new("Weld")
                weld.Name = "AccessoryWeld"
                weld.Part0 = handle
                if targetAttachment then
                    weld.Part1 = targetAttachment.Parent
                    weld.C0 = attachment.CFrame
                    weld.C1 = targetAttachment.CFrame
                else
                    weld.Part1 = char:FindFirstChild("Head") or char:FindFirstChild("Torso")
                        or char:FindFirstChild("UpperTorso") or char:FindFirstChild("HumanoidRootPart")
                end
                weld.Parent = handle
                wornKeys[key] = true
            end)
            return ok and wornKeys[key] == true
        end

        local function grabAsset(id)
            id = tonumber(id)
            if not id or id <= 0 then return nil end
            local ok, objects = pcall(function() return game:GetObjects("rbxassetid://" .. tostring(id)) end)
            if ok and type(objects) == "table" then return objects end
            return nil
        end

        local function applyCharacterMeshesFromModel(char, model)
            local count = 0
            for _, v in ipairs(char:GetChildren()) do
                if v:IsA("CharacterMesh") then pcall(function() v:Destroy() end) end
            end
            for _, v in ipairs(model:GetChildren()) do
                if v:IsA("CharacterMesh") then
                    pcall(function()
                        v:Clone().Parent = char
                        count += 1
                    end)
                end
            end
            return count
        end

        local function copySpecialMesh(limb, source)
            pcall(function()
                local target = limb:FindFirstChildOfClass("SpecialMesh")
                if not target then
                    target = Instance.new("SpecialMesh")
                    target.Parent = limb
                end
                target.MeshType = source.MeshType
                target.MeshId = source.MeshId
                target.TextureId = source.TextureId
                target.Scale = source.Scale
            end)
        end

        -- R6 limbs come from asset ids in the description (CharacterMesh / SpecialMesh / accessories)
        local function applyR6MeshesFromDescription(char, desc)
            if not desc then return 0 end

            local function wearLimbAsset(assetId, bodyPart, limbName)
                local objects = grabAsset(assetId)
                if not objects then return false end
                local applied = false
                for _, object in ipairs(objects) do
                    if object:IsA("CharacterMesh") then
                        pcall(function()
                            local mesh = object:Clone()
                            pcall(function() mesh.BodyPart = bodyPart end)
                            mesh.Parent = char
                            applied = true
                        end)
                    end
                    for _, d in ipairs(object:GetDescendants()) do
                        if d:IsA("CharacterMesh") then
                            pcall(function()
                                local mesh = d:Clone()
                                pcall(function() mesh.BodyPart = bodyPart end)
                                mesh.Parent = char
                                applied = true
                            end)
                        elseif d:IsA("SpecialMesh") then
                            local limb = char:FindFirstChild(limbName)
                            if limb then
                                copySpecialMesh(limb, d)
                                applied = true
                            end
                        elseif d:IsA("Accessory") then
                            if wearAccessory(char, d, true) then applied = true end
                        end
                    end
                    if object:IsA("SpecialMesh") then
                        local limb = char:FindFirstChild(limbName)
                        if limb then
                            copySpecialMesh(limb, object)
                            applied = true
                        end
                    end
                    if object:IsA("Accessory") then
                        if wearAccessory(char, object, true) then applied = true end
                    end
                end
                return applied
            end

            local limbs = {
                { "Head", Enum.BodyPart.Head, "Head" },
                { "Torso", Enum.BodyPart.Torso, "Torso" },
                { "LeftArm", Enum.BodyPart.LeftArm, "Left Arm" },
                { "RightArm", Enum.BodyPart.RightArm, "Right Arm" },
                { "LeftLeg", Enum.BodyPart.LeftLeg, "Left Leg" },
                { "RightLeg", Enum.BodyPart.RightLeg, "Right Leg" },
            }
            local count = 0
            for _, entry in ipairs(limbs) do
                local assetId = 0
                pcall(function() assetId = tonumber(desc[entry[1]]) or 0 end)
                if assetId > 0 and wearLimbAsset(assetId, entry[2], entry[3]) then count += 1 end
            end

            -- Korblox needs both legs even when only one id is in the description
            local leftId, rightId = 0, 0
            pcall(function() leftId = tonumber(desc.LeftLeg) or 0 end)
            pcall(function() rightId = tonumber(desc.RightLeg) or 0 end)
            if leftId == KORBLOX_LEFT or rightId == KORBLOX_RIGHT then
                if wearLimbAsset(KORBLOX_LEFT, Enum.BodyPart.LeftLeg, "Left Leg") then count += 1 end
                if wearLimbAsset(KORBLOX_RIGHT, Enum.BodyPart.RightLeg, "Right Leg") then count += 1 end
            end
            return count
        end

        local function copyClothesAndColors(char, model)
            for _, className in ipairs({ "Shirt", "Pants", "ShirtGraphic", "BodyColors" }) do
                local source = model:FindFirstChildOfClass(className)
                if source then pcall(function() source:Clone().Parent = char end) end
            end

            local head, sourceHead = char:FindFirstChild("Head"), model:FindFirstChild("Head")
            if head and sourceHead then
                local function clearFaces()
                    for _, d in ipairs(head:GetChildren()) do
                        if d:IsA("Decal") or d:IsA("Texture") or d:IsA("SurfaceAppearance") then pcall(function() d:Destroy() end) end
                    end
                end
                clearFaces()
                if sourceHead:IsA("MeshPart") then
                    -- Dynamic head: its face lives in the head mesh and textures. The model's classic
                    -- "face" decal is the default Roblox face, so it is not copied (it used to stack on
                    -- top of the dynamic face), and the old head's face is removed.
                    pcall(function()
                        local mesh = head:FindFirstChildOfClass("SpecialMesh")
                        if not mesh then
                            mesh = Instance.new("SpecialMesh")
                            mesh.Parent = head
                        end
                        mesh.MeshType = Enum.MeshType.FileMesh
                        mesh.MeshId = sourceHead.MeshId
                        local appearance = sourceHead:FindFirstChildOfClass("SurfaceAppearance")
                        local texture = appearance and appearance.ColorMap or ""
                        mesh.TextureId = texture ~= "" and texture or sourceHead.TextureID
                        local native, size = sourceHead.MeshSize, sourceHead.Size
                        if native.X > 0 and native.Y > 0 and native.Z > 0 then
                            mesh.Scale = Vector3.new(size.X / native.X, size.Y / native.Y, size.Z / native.Z)
                        end
                    end)
                    -- the game can add its own face back; sweep again shortly after
                    task.delay(0.75, clearFaces)
                    task.delay(2, clearFaces)
                else
                    for _, d in ipairs(sourceHead:GetChildren()) do
                        if d:IsA("Decal") then pcall(function() d:Clone().Parent = head end) end
                    end
                    local sourceMesh = sourceHead:FindFirstChildOfClass("SpecialMesh")
                    if sourceMesh then copySpecialMesh(head, sourceMesh) end
                end
            end
        end

        local function copyAccessories(char, model)
            local count = 0
            for _, accessory in ipairs(model:GetChildren()) do
                if accessory:IsA("Accessory") and wearAccessory(char, accessory) then count += 1 end
            end
            return count
        end

        -- accessories listed in the description that the model did not include; also finds headless
        local function loadAccessoriesFromDescription(char, desc)
            local count, headless = 0, false
            if not desc then return count, headless end

            local ids = {}
            pcall(function()
                for _, prop in ipairs({ "HatAccessory", "HairAccessory", "FaceAccessory", "NeckAccessory",
                    "ShouldersAccessory", "FrontAccessory", "BackAccessory", "WaistAccessory" }) do
                    local value = desc[prop]
                    if type(value) == "string" and value ~= "" then
                        for id in string.gmatch(tostring(value), "%d+") do table.insert(ids, tonumber(id)) end
                    end
                end
                if desc.GetAccessories then
                    for _, accessory in ipairs(desc:GetAccessories(true)) do
                        if accessory.AssetId then table.insert(ids, accessory.AssetId) end
                    end
                end
            end)

            for _, id in ipairs(ids) do
                if HEADLESS_IDS[id] then headless = true end
                local objects = grabAsset(id)
                if objects then
                    for _, object in ipairs(objects) do
                        if object:IsA("Accessory") then
                            if string.find(string.lower(object.Name), "headless", 1, true) then headless = true end
                            if wearAccessory(char, object, true) then count += 1 end
                        else
                            for _, d in ipairs(object:GetDescendants()) do
                                if d:IsA("Accessory") then
                                    if string.find(string.lower(d.Name), "headless", 1, true) then headless = true end
                                    if wearAccessory(char, d, true) then count += 1 end
                                elseif d:IsA("CharacterMesh") then
                                    pcall(function()
                                        d:Clone().Parent = char
                                        count += 1
                                    end)
                                end
                            end
                        end
                    end
                end
            end
            return count, headless
        end

        local function forceHeadless(char)
            local head = char and char:FindFirstChild("Head")
            if not head then return end
            pcall(function()
                head.Transparency = 1
                for _, d in ipairs(head:GetChildren()) do
                    if d:IsA("Decal") or d:IsA("Texture") then d.Transparency = 1 end
                end
            end)
        end

        local function fetchModel(uid, rigType)
            local desc
            local described, result = pcall(function() return Players:GetHumanoidDescriptionFromUserIdAsync(uid) end)
            if described then desc = result end
            if described and desc and Players.CreateHumanoidModelFromDescription then
                local ok, built = pcall(function() return Players:CreateHumanoidModelFromDescription(desc, rigType) end)
                if ok and built then return built, desc end
            end
            local ok, built = pcall(function() return Players:CreateHumanoidModelFromUserId(uid) end)
            if ok and built then return built, desc end
            ok, built = pcall(function() return Players:CreateHumanoidModelFromUserIdAsync(uid) end)
            if ok and built then return built, desc end
            return nil, desc
        end

        local function applyAvatar(rawInput)
            local char = LocalPlayer.Character
            local humanoid = char and char:FindFirstChildOfClass("Humanoid")
            if not humanoid then
                notify("Avatar changer: no character yet")
                return false
            end

            local raw = tostring(rawInput or ""):gsub("^%s+", ""):gsub("%s+$", "")
            if raw == "" then
                notify("Avatar changer: type a UserId, username or profile URL first")
                return false
            end
            local uid = resolveUserId(raw)
            if not uid then
                notify("Avatar changer: could not find user " .. raw)
                return false
            end

            stripAppearance(char)
            wornKeys = {}
            notify("Avatar changer: fetching " .. tostring(uid) .. "...")
            lastUid = uid

            local model, desc = fetchModel(uid, humanoid.RigType)
            currentDesc = desc
            if not model then
                if desc then
                    pcall(function()
                        if humanoid.ApplyDescriptionAsync then humanoid:ApplyDescriptionAsync(desc) else humanoid:ApplyDescription(desc) end
                    end)
                    if humanoid.RigType == Enum.HumanoidRigType.R6 then applyR6MeshesFromDescription(char, desc) end
                    dedupeAccessories(char)
                    notify("Avatar changer: applied the description only (no model)")
                    return true
                end
                notify("Avatar changer: could not fetch that avatar")
                return false
            end

            stripAppearance(char) -- the fetch yields; make sure nothing came back meanwhile
            wornKeys = {}
            copyClothesAndColors(char, model)

            local meshCount = applyCharacterMeshesFromModel(char, model)
            if desc and humanoid.RigType == Enum.HumanoidRigType.R6 then
                meshCount += applyR6MeshesFromDescription(char, desc)
            end

            local accessoryCount = copyAccessories(char, model)
            local headless = false
            if desc then
                local extra, isHeadless = loadAccessoriesFromDescription(char, desc)
                accessoryCount += extra
                headless = isHeadless
            end
            if not headless then
                for _, child in ipairs(char:GetChildren()) do
                    if child:IsA("Accessory") and string.find(string.lower(child.Name), "headless", 1, true) then
                        headless = true
                        break
                    end
                end
            end
            if headless then forceHeadless(char) end

            dedupeAccessories(char)
            accessoryCount = 0
            for _, child in ipairs(char:GetChildren()) do
                if child:IsA("Accessory") then accessoryCount += 1 end
            end

            pcall(function() model:Destroy() end)
            notify(string.format("Avatar applied (meshes %d, accessories %d%s)", meshCount, accessoryCount, headless and ", headless" or ""))
            return true
        end

        -- one at a time: fetching takes a moment and overlapping changes would fight each other
        local function runApply(raw)
            if busy then
                notify("Avatar changer: still working on the last one")
                return false
            end
            busy = true
            local ok, result = pcall(applyAvatar, raw)
            busy = false
            if not ok then
                warn("Avatar changer failed:", result)
                notify("Avatar changer failed, see the console")
                return false
            end
            return result
        end

        SpooferActions.apply = function()
            runApply(getFlag("spoof_avatar_user", ""))
        end

        SpooferActions.reset = function()
            if runApply(tostring(LocalPlayer.UserId)) then lastUid = nil end
        end

        track(LocalPlayer.CharacterAdded:Connect(function()
            if not lastUid or not getFlag("spoof_avatar_reapply", true) then return end
            task.delay(1.25, function()
                if lastUid and getFlag("spoof_avatar_reapply", true) then runApply(lastUid) end
            end)
        end))

        onUnload(function()
            SpooferActions.apply, SpooferActions.reset = noop, noop
        end)
    end)()

    local syncClock = 1
    track(RunService.RenderStepped:Connect(function(dt)
        local cam = workspace.CurrentCamera
        if cam and fovCircle then
            fovCircle.Visible = getFlag("aimbot_fov_outline", false)
            fovCircle.Radius = getFlag("silent_radius", 100)
            fovCircle.Color = getColor("aimbot_outline_color1", Color3.new(1,1,1))
            fovCircle.Position = cam.ViewportSize / 2
            if getFlag("aimbot_fov_moving", false) then
                fovCircle.NumSides = 60
            end
        end
        syncClock += dt
        if syncClock >= 0.1 then
            syncClock = 0
            syncCoincideESP()
        end
        updateAdornChams()
        updateSkeletons()
        applySkybox()
        applyWorldLighting()
        applyPostEffects()
        updateBlur()
        updateLocalVisuals()
        updateTracers(dt)
        updateCrosshair()
        updateWeather()
    end))
end


Loader.step("Loading misc features", 0.72)
-- Misc and gun mods -----------------------------------------------------------------
-- Every feature is registered with feature(flag, start, stop). One Heartbeat watcher starts or
-- stops it when its toggle changes (this also covers loading a saved config), and unloading
-- the script stops them all. Everything is off until switched on.
do
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local TeamsService = game:GetService("Teams")
    local Camera = function() return workspace.CurrentCamera end
    local flag = readFlag
    local clock = os.clock
    local v3, ZERO = Vector3.new, Vector3.zero
    local FLAT = Vector3.new(1, 0, 1)

    local function warnf(...) warn("[Aster][Misc]", ...) end
    local function say(text) pcall(function() Library:Notify(text, 4) end) end

    -- feature registry -----------------------------------------------------------------
    local features = {}
    local function feature(flagName, start, stop)
        features[#features + 1] = { flag = flagName, start = start, stop = stop or noop, active = false }
    end
    local function setActive(f, on)
        if on == f.active then return end
        f.active = on
        local ok, err = pcall(on and f.start or f.stop)
        if not ok then warnf(f.flag, on and "start failed:" or "stop failed:", err) end
    end
    local function isOn(flagName)
        for _, f in ipairs(features) do
            if f.flag == flagName then return f.active end
        end
        return false
    end
    local function switchOff(flagName)
        local t = Toggles[flagName]
        if t and t.SetValue then pcall(function() t:SetValue(false) end) end
    end

    -- a small bag of connections that can be dropped together
    local function newBag()
        local bag, list = {}, {}
        function bag.add(connection) list[#list + 1] = connection return connection end
        function bag.clear()
            for _, c in ipairs(list) do pcall(function() c:Disconnect() end) end
            table.clear(list)
        end
        return bag
    end

    local stepSignal = RunService.PreSimulation or RunService.Heartbeat

    -- character helpers --------------------------------------------------------------
    local function localParts()
        local char = LocalPlayer.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        local root = char:FindFirstChild("HumanoidRootPart")
        if hum and root and hum.Health > 0 then return char, hum, root end
    end

    local function otherEntities()
        local list = {}
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                local char = player.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                local root = char and char:FindFirstChild("HumanoidRootPart")
                local head = char and char:FindFirstChild("Head")
                if hum and root and head and hum.Health > 0 then
                    list[#list + 1] = { Player = player, Character = char, Humanoid = hum, Root = root, Head = head }
                end
            end
        end
        return list
    end

    local function typing() return UserInputService:GetFocusedTextBox() ~= nil end

    local function shiftDown()
        return UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
    end

    -- Several features switch CanQuery off on parts; a reference count keeps them from
    -- restoring each other's changes.
    local queryHeld = {}
    local function holdQuery(part)
        local entry = queryHeld[part]
        if entry then entry.n += 1 return end
        queryHeld[part] = { n = 1, original = part.CanQuery }
        part.CanQuery = false
    end
    local function releaseQuery(part)
        local entry = queryHeld[part]
        if not entry then return end
        entry.n -= 1
        if entry.n <= 0 then
            queryHeld[part] = nil
            pcall(function() part.CanQuery = entry.original end)
        end
    end

    local function waitForCars(timeout)
        return workspace:FindFirstChild("CarContainer") or workspace:WaitForChild("CarContainer", timeout or 5)
    end

    -- Fly and vehicle fly are held to 49.9 studs above the ground (the game's own limit).
    local CAP_HEIGHT = 49.9
    local capRay = RaycastParams.new()
    capRay.FilterType = Enum.RaycastFilterType.Exclude
    local function capHeight(root, level, extraIgnore)
        local list = { root.Parent, Camera() }
        if extraIgnore then list[#list + 1] = extraIgnore end
        capRay.FilterDescendantsInstances = list
        local hit = workspace:Raycast(root.Position, v3(0, -500, 0), capRay)
        if not hit then return level end
        local limit = hit.Position.Y + CAP_HEIGHT
        if root.Position.Y > limit then
            root.CFrame += v3(0, limit - root.Position.Y, 0)
            local velocity = root.AssemblyLinearVelocity
            if velocity.Y > 0 then root.AssemblyLinearVelocity = v3(velocity.X, 0, velocity.Z) end
        end
        return level and math.min(level, limit) or level
    end

    -- cheat flags (CheatDetector and AntiInvisible share them) ------------------------------
    local cheatCounts, cheatFlagged = {}, {}
    local function flagCheat(player, kind, limit)
        if not isOn("misc_cheat_detector") or cheatFlagged[player.UserId] then return end
        local counts = cheatCounts[player.UserId]
        if not counts then counts = {} cheatCounts[player.UserId] = counts end
        counts[kind] = (counts[kind] or 0) + 1
        if counts[kind] > limit then
            cheatFlagged[player.UserId] = true
            say(player.Name .. " may be cheating (" .. kind .. ")")
        end
    end

    -- ======================================================================================
    -- Camera phase: Invisicam occlusion keeps the camera from being pushed in by walls
    -- ======================================================================================
    do
        local bag, original = newBag(), nil
        feature("misc_camera_phase", function()
            original = LocalPlayer.DevCameraOcclusionMode
            LocalPlayer.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Invisicam
            bag.add(RunService.RenderStepped:Connect(function()
                if LocalPlayer.DevCameraOcclusionMode ~= Enum.DevCameraOcclusionMode.Invisicam then
                    LocalPlayer.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Invisicam
                end
            end))
        end, function()
            bag.clear()
            if original then LocalPlayer.DevCameraOcclusionMode = original end
            original = nil
        end)
    end

    -- ======================================================================================
    -- No jump cooldown: the game's AntiJump script is a token bucket on Humanoid.Jump
    -- ======================================================================================
    do
        local bag, disabled, token, hooked = newBag(), {}, 0, false

        local function sourceOf(connection)
            local ok, src = pcall(function()
                return connection.Function and debug.info(connection.Function, "s")
            end)
            return ok and type(src) == "string" and src or ""
        end

        local function hookJump(hum)
            if type(getconnections) ~= "function" then return false end
            local ok, list = pcall(getconnections, hum:GetPropertyChangedSignal("Jump"))
            if not ok or type(list) ~= "table" then return false end
            local found = false
            for _, c in ipairs(list) do
                if sourceOf(c):find("AntiJump") then
                    pcall(function() c:Disable() end)
                    disabled[#disabled + 1] = c
                    found = true
                end
            end
            if not found and list[1] and list[1].Function then
                pcall(function() list[1]:Disable() end)
                disabled[#disabled + 1] = list[1]
                found = true
            end
            return found
        end

        local function attach(char)
            table.clear(disabled)
            hooked = false
            local my = token
            task.spawn(function()
                local hum = char:WaitForChild("Humanoid", 5)
                if not hum then return end
                for _ = 1, 20 do
                    if my ~= token then return end
                    if hookJump(hum) then hooked = true return end
                    task.wait(0.25)
                end
            end)
        end

        feature("misc_no_jump_cd", function()
            token += 1
            if LocalPlayer.Character then attach(LocalPlayer.Character) end
            bag.add(LocalPlayer.CharacterAdded:Connect(attach))
            -- fallback while the game's script cannot be disabled: jump directly from the ground
            bag.add(RunService.Heartbeat:Connect(function()
                if hooked or typing() or not UserInputService:IsKeyDown(Enum.KeyCode.Space) then return end
                local _, hum = localParts()
                if hum and hum.FloorMaterial ~= Enum.Material.Air then
                    local state = hum:GetState()
                    if state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.Landed then
                        hum:ChangeState(Enum.HumanoidStateType.Jumping)
                    end
                end
            end))
        end, function()
            token += 1
            bag.clear()
            for _, c in ipairs(disabled) do pcall(function() c:Enable() end) end
            table.clear(disabled)
            hooked = false
        end)
    end

    -- ======================================================================================
    -- Xray: local transparency on map parts
    -- ======================================================================================
    do
        local bag, modified, token = newBag(), {}, 0
        local appliedAlpha, appliedIgnore = nil, nil

        local function ignoreSet()
            local set = {}
            for name in tostring(flag("misc_xray_ignore", "")):gmatch("[^,]+") do
                set[(name:gsub("^%s+", ""):gsub("%s+$", ""))] = true
            end
            return set
        end

        local ignore = {}
        local function isCharacterPart(part)
            local node = part.Parent
            while node and node ~= workspace do
                if node:IsA("Model") and node:FindFirstChildOfClass("Humanoid") then return true end
                node = node.Parent
            end
            return false
        end

        local function modify(part)
            if not part:IsA("BasePart") or part:IsA("Terrain") then return end
            if ignore[part.Name] or isCharacterPart(part) then return end
            modified[part] = true
            part.LocalTransparencyModifier = flag("misc_xray_alpha", 0.5)
        end

        local function reset()
            for part in pairs(modified) do
                pcall(function() part.LocalTransparencyModifier = 0 end)
            end
            table.clear(modified)
        end

        local function scan()
            token += 1
            local my = token
            reset()
            ignore = ignoreSet()
            appliedIgnore = flag("misc_xray_ignore", "")
            appliedAlpha = flag("misc_xray_alpha", 0.5)
            task.spawn(function()
                local list = workspace:GetDescendants()
                for i, item in ipairs(list) do
                    if my ~= token then return end
                    modify(item)
                    if i % 1500 == 0 then task.wait() end
                end
            end)
        end

        feature("misc_xray", function()
            scan()
            bag.add(workspace.DescendantAdded:Connect(modify))
            bag.add(RunService.Heartbeat:Connect(function()
                local alpha = flag("misc_xray_alpha", 0.5)
                if flag("misc_xray_ignore", "") ~= appliedIgnore then
                    scan()
                elseif alpha ~= appliedAlpha then
                    appliedAlpha = alpha
                    for part in pairs(modified) do
                        pcall(function() part.LocalTransparencyModifier = alpha end)
                    end
                end
            end))
        end, function()
            token += 1
            bag.clear()
            reset()
        end)
    end

    -- ======================================================================================
    -- Gravity
    -- ======================================================================================
    do
        local bag, old, changing = newBag(), nil, false
        local function applyWorkspace()
            changing = true
            workspace.Gravity = flag("misc_gravity_value", 196)
            changing = false
        end
        feature("misc_gravity", function()
            if flag("misc_gravity_mode", "Workspace") == "Workspace" then
                old = workspace.Gravity
                applyWorkspace()
                bag.add(workspace:GetPropertyChangedSignal("Gravity"):Connect(function()
                    if changing then return end
                    old = workspace.Gravity
                    applyWorkspace()
                end))
                bag.add(RunService.Heartbeat:Connect(function()
                    if workspace.Gravity ~= flag("misc_gravity_value", 196) then applyWorkspace() end
                end))
            else
                bag.add(stepSignal:Connect(function(dt)
                    local _, hum, root = localParts()
                    if hum and hum.FloorMaterial == Enum.Material.Air then
                        root.AssemblyLinearVelocity += v3(0, dt * (workspace.Gravity - flag("misc_gravity_value", 196)), 0)
                    end
                end))
            end
        end, function()
            bag.clear()
            if old then workspace.Gravity = old old = nil end
        end)
    end

    -- ======================================================================================
    -- Cheat detector
    -- ======================================================================================
    do
        local bag = newBag()
        local positions, spawned, lastChar = {}, {}, {}
        local okStates = {
            [Enum.HumanoidStateType.Running] = true, [Enum.HumanoidStateType.Jumping] = true,
            [Enum.HumanoidStateType.Freefall] = true, [Enum.HumanoidStateType.Landed] = true,
            [Enum.HumanoidStateType.FallingDown] = true, [Enum.HumanoidStateType.GettingUp] = true,
            [Enum.HumanoidStateType.Climbing] = true, [Enum.HumanoidStateType.Seated] = true,
            [Enum.HumanoidStateType.Ragdoll] = true, [Enum.HumanoidStateType.Dead] = true,
            [Enum.HumanoidStateType.None] = true,
        }
        local overlap = OverlapParams.new()
        overlap.CollisionGroup = "Players"
        overlap.FilterType = Enum.RaycastFilterType.Exclude
        local carOverlap = OverlapParams.new()
        carOverlap.FilterType = Enum.RaycastFilterType.Include
        carOverlap.MaxParts = 1

        local function refreshFilters()
            local exclude, include = {}, {}
            local cars, doors = workspace:FindFirstChild("CarContainer"), workspace:FindFirstChild("Doors")
            if cars then exclude[#exclude + 1] = cars include[#include + 1] = cars end
            if doors then exclude[#exclude + 1] = doors end
            overlap.FilterDescendantsInstances = exclude
            carOverlap.FilterDescendantsInstances = include
            return #include > 0
        end

        -- true when the point is not inside any solid part
        local function pointIsFree(pos)
            for _, part in ipairs(workspace:GetPartBoundsInRadius(pos, 0, overlap)) do
                if part.CanCollide and (part:GetClosestPointOnSurface(pos) - pos).Magnitude <= 0.0001 then
                    return false
                end
            end
            return true
        end

        local acc = 0
        feature("misc_cheat_detector", function()
            acc = 0
            bag.add(RunService.Heartbeat:Connect(function(dt)
                acc += dt
                if acc < 0.05 then return end
                acc = 0
                local haveCars = refreshFilters()
                local nearCar = function(pos)
                    return haveCars and #workspace:GetPartBoundsInRadius(pos, 30, carOverlap) > 0
                end
                for _, e in ipairs(otherEntities()) do
                    local player = e.Player
                    if lastChar[player] ~= e.Character then
                        lastChar[player] = e.Character
                        spawned[player] = clock()
                        positions[player] = nil
                    end
                    if not cheatFlagged[player.UserId] then
                        local pos = e.Root.Position
                        if not pointIsFree(e.Head.Position) then flagCheat(player, "phase/noclip", 20) end
                        local state = e.Humanoid:GetState()
                        if not okStates[state] then flagCheat(player, "invalid state " .. state.Name, 1) end
                        local velocity = e.Root.AssemblyLinearVelocity
                        if not e.Humanoid.SeatPart then
                            if (velocity * FLAT).Magnitude > 26 and not nearCar(pos) then flagCheat(player, "speed", 20) end
                            local prev = positions[player]
                            if prev and flag("misc_cheat_teleport", true) and ((pos - prev[1]) * FLAT).Magnitude > 50 and not nearCar(pos) then
                                local fresh = player.Team == TeamsService:FindFirstChild("Inmates") and (clock() - (spawned[player] or 0)) <= 0.1
                                if not fresh then flagCheat(player, "teleport", 1) end
                            end
                            if velocity.Y > 50 then flagCheat(player, "highjump", 20) end
                            if not prev or (clock() - prev[2]) > 0.2 then positions[player] = { pos, clock() } end
                        else
                            positions[player] = { pos, clock() }
                        end
                    end
                end
            end))
            bag.add(Players.PlayerRemoving:Connect(function(player)
                positions[player], spawned[player], lastChar[player] = nil, nil, nil
            end))
        end, function()
            bag.clear()
            table.clear(positions)
            table.clear(cheatCounts)
            table.clear(cheatFlagged)
        end)

        MiscActions.clearCheats = function()
            table.clear(cheatCounts)
            table.clear(cheatFlagged)
            say("Cheat flags cleared")
        end
    end

    -- ======================================================================================
    -- Gun helpers (shared by gun mods and auto reload)
    -- ======================================================================================
    local function equippedGun()
        local char = LocalPlayer.Character
        local tool = char and char:FindFirstChildOfClass("Tool")
        if tool and tool:GetAttribute("FireRate") ~= nil then return tool end
    end

    local function allTools()
        local list = {}
        local char, pack = LocalPlayer.Character, LocalPlayer:FindFirstChildOfClass("Backpack")
        for _, holder in ipairs({ char, pack }) do
            if holder then
                for _, child in ipairs(holder:GetChildren()) do
                    if child:IsA("Tool") then list[#list + 1] = child end
                end
            end
        end
        return list
    end

    -- ======================================================================================
    -- Gun modifications (combat). The game copies a tool's attributes into its gun config at
    -- equip time, so the attributes are edited and the equipped gun is re-equipped once.
    -- ======================================================================================
    do
        local bag = newBag()
        local originals = setmetatable({}, { __mode = "k" })
        local applied = setmetatable({}, { __mode = "k" })

        local function signature()
            return table.concat({
                tostring(flag("gun_no_spread", false)),
                tostring(flag("gun_full_auto", false)),
                tostring(flag("gun_fire_rate", 100)),
                tostring(flag("gun_range_on", false)),
                tostring(flag("gun_range", 1000)),
            }, "|")
        end

        local function apply(tool, restoreOnly)
            if tool:GetAttribute("FireRate") == nil and not originals[tool] then return false end
            if tool.Name == "Taser" then return false end
            local o = originals[tool]
            if not o then
                o = { SpreadRadius = tool:GetAttribute("SpreadRadius"), FireRate = tool:GetAttribute("FireRate"), AutoFire = tool:GetAttribute("AutoFire"), Range = tool:GetAttribute("Range") }
                originals[tool] = o
            end
            local noSpread = not restoreOnly and flag("gun_no_spread", false)
            local auto = not restoreOnly and flag("gun_full_auto", false)
            local pct = restoreOnly and 100 or flag("gun_fire_rate", 100)
            if o.SpreadRadius ~= nil then tool:SetAttribute("SpreadRadius", noSpread and 0 or o.SpreadRadius) end
            if o.FireRate ~= nil then tool:SetAttribute("FireRate", o.FireRate * (pct / 100)) end
            if o.AutoFire ~= nil or auto then tool:SetAttribute("AutoFire", auto and true or o.AutoFire) end
            if o.Range ~= nil then
                local ranged = not restoreOnly and flag("gun_range_on", false)
                tool:SetAttribute("Range", ranged and flag("gun_range", 1000) or o.Range)
            end
            return true
        end

        local function reequip(tool)
            local char, hum = localParts()
            if not (char and hum) or tool.Parent ~= char then return end
            hum:UnequipTools()
            task.delay(0.2, function()
                local _, h = localParts()
                if h and tool.Parent == LocalPlayer:FindFirstChildOfClass("Backpack") then h:EquipTool(tool) end
            end)
        end

        local function sweep(restoreOnly)
            local sig = restoreOnly and "restore" or signature()
            for _, tool in ipairs(allTools()) do
                if applied[tool] ~= sig then
                    applied[tool] = sig
                    if apply(tool, restoreOnly) and tool.Parent == LocalPlayer.Character then
                        reequip(tool)
                    end
                end
            end
        end

        feature("gun_mods", function()
            bag.add(RunService.Heartbeat:Connect(function() sweep(false) end))
        end, function()
            bag.clear()
            for tool in pairs(originals) do applied[tool] = nil end
            sweep(true)
        end)
    end

    -- ======================================================================================
    -- Auto reload
    -- ======================================================================================
    do
        local bag, nextTry = newBag(), 0
        local VirtualInputManager
        local cachedReload

        local function getReload()
            if cachedReload then return cachedReload end
            if type(getconnections) ~= "function" or not (debug and debug.getupvalue) then return end
            local home = LocalPlayer.PlayerGui:FindFirstChild("Home")
            local area = home and home:FindFirstChild("hud") and home.hud:FindFirstChild("ActionArea")
            if not area then return end
            local ok, list = pcall(getconnections, area.InputBegan)
            if not ok then return end
            for _, c in ipairs(list) do
                if c.Function then
                    local ok1, shoot = pcall(debug.getupvalue, c.Function, 2)
                    if ok1 and type(shoot) == "function" then
                        local ok2, reload = pcall(debug.getupvalue, shoot, 2)
                        if ok2 and type(reload) == "function" then cachedReload = reload return reload end
                    end
                end
            end
        end

        local function pressReload()
            if typing() then return false end
            local ok = pcall(function()
                VirtualInputManager = VirtualInputManager or game:GetService("VirtualInputManager")
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.R, false, game)
                task.wait(0.05)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.R, false, game)
            end)
            return ok
        end

        local priority = { M4A1 = 1, ["AK-47"] = 1, MP5 = 1, FAL = 1, ["Remington 870"] = 2, M9 = 3, Revolver = 4 }
        local function swapTarget(current)
            local pack = LocalPlayer:FindFirstChildOfClass("Backpack")
            if not pack then return end
            local best
            for _, tool in ipairs(pack:GetChildren()) do
                if tool ~= current and tool:IsA("Tool") and tool:GetAttribute("FireRate") ~= nil
                    and (tool:GetAttribute("Local_ReloadSession") or 0) <= 0
                    and tool.Name ~= "Taser" and tool.Name ~= "M700" then
                    if not best or (priority[tool.Name] or 100) < (priority[best.Name] or 100) then best = tool end
                end
            end
            return best
        end

        feature("gun_auto_reload", function()
            bag.add(RunService.Heartbeat:Connect(function()
                if clock() < nextTry then return end
                local tool = equippedGun()
                if not tool then return end
                local ammo = tool:GetAttribute("Local_CurrentAmmo")
                if ammo == nil or ammo > 0 or (tool:GetAttribute("Local_ReloadSession") or 0) ~= 0 then return end
                if tool:GetAttribute("Behavior") == "Sniper" and (tool:GetAttribute("StoredAmmo") or 1) <= 0 then return end
                nextTry = clock() + 0.6
                local reload = getReload()
                if reload then task.spawn(reload) else task.spawn(pressReload) end
                if flag("gun_auto_swap", false) then
                    task.delay(0.15, function()
                        local _, hum = localParts()
                        local target = swapTarget(tool)
                        if hum and target then hum:EquipTool(target) end
                    end)
                end
            end))
        end, function()
            bag.clear()
        end)
    end

    -- ======================================================================================
    -- Shoot through vehicles / riot shields (the bullet ray ignores parts with CanQuery off)
    -- ======================================================================================
    do
        local bag, held, token = newBag(), {}, 0
        local function take(part)
            if part:IsA("BasePart") and not held[part] then held[part] = true holdQuery(part) end
        end
        feature("gun_vehicle_wallbang", function()
            token += 1
            local my = token
            task.spawn(function()
                local cars = waitForCars(5)
                if not cars or my ~= token then return end
                bag.add(cars.DescendantAdded:Connect(take))
                for i, part in ipairs(cars:GetDescendants()) do
                    if my ~= token then return end
                    take(part)
                    if i % 1500 == 0 then task.wait() end
                end
            end)
        end, function()
            token += 1
            bag.clear()
            for part in pairs(held) do releaseQuery(part) end
            table.clear(held)
        end)
    end

    do
        local bag, held = newBag(), {}
        local acc = 0
        feature("misc_anti_riot", function()
            bag.add(RunService.Heartbeat:Connect(function(dt)
                acc += dt
                if acc < 0.05 then return end
                acc = 0
                for _, e in ipairs(otherEntities()) do
                    local shield = e.Character:FindFirstChild("RiotShieldPart")
                    if shield and shield:IsA("BasePart") and not held[shield] then
                        held[shield] = true
                        holdQuery(shield)
                    end
                end
                for shield in pairs(held) do
                    if not shield:IsDescendantOf(workspace) then held[shield] = nil queryHeld[shield] = nil end
                end
            end))
        end, function()
            bag.clear()
            for shield in pairs(held) do releaseQuery(shield) end
            table.clear(held)
        end)
    end

    -- ======================================================================================
    -- Anti kill plane
    -- ======================================================================================
    do
        local bag = newBag()
        feature("misc_anti_killplane", function()
            bag.add(RunService.Heartbeat:Connect(function()
                local _, _, root = localParts()
                if not root then return end
                local y = root.Position.Y
                local diff = math.clamp(y, -10, 179.99) - y
                if math.abs(diff) > 0 then
                    root.CFrame += v3(0, diff, 0)
                    root.AssemblyLinearVelocity *= FLAT
                end
            end))
        end, function() bag.clear() end)
    end

    -- ======================================================================================
    -- Anti fling: car parts stop colliding and touching; seats get their own prompt
    -- ======================================================================================
    do
        local bag = newBag()
        local modified, prompts, token = {}, {}, 0

        local function refreshPrompts()
            local _, hum = localParts()
            for prompt, seat in pairs(prompts) do
                if prompt.Parent then
                    prompt.Enabled = not (hum and hum.SeatPart) and not seat.Occupant
                end
            end
        end

        local function modify(part)
            if not part:IsA("BasePart") or part.CollisionGroup == "Wheels" or modified[part] then return end
            modified[part] = { part.CanCollide, part.CanTouch }
            if (part:IsA("Seat") or part:IsA("VehicleSeat")) and part.Name == part.ClassName then
                local prompt = Instance.new("ProximityPrompt")
                prompt.ActionText = "Enter"
                prompt.Enabled = not part.Occupant
                prompt.MaxActivationDistance = 8
                prompt.RequiresLineOfSight = false
                prompt.Parent = part
                prompts[prompt] = part
                bag.add(prompt.Triggered:Connect(function()
                    local _, hum = localParts()
                    if hum then part:Sit(hum) end
                end))
                bag.add(part:GetPropertyChangedSignal("Occupant"):Connect(refreshPrompts))
            end
            part.CanCollide = false
            part.CanTouch = false
        end

        feature("misc_anti_fling", function()
            token += 1
            local my = token
            task.spawn(function()
                local cars = waitForCars(5)
                if not cars or my ~= token then return end
                bag.add(cars.DescendantAdded:Connect(modify))
                for i, part in ipairs(cars:GetDescendants()) do
                    if my ~= token then return end
                    modify(part)
                    if i % 1000 == 0 then task.wait() end
                end
            end)
            local function watchSeat(char)
                local hum = char:WaitForChild("Humanoid", 5)
                if hum then bag.add(hum:GetPropertyChangedSignal("SeatPart"):Connect(refreshPrompts)) end
            end
            if LocalPlayer.Character then task.spawn(watchSeat, LocalPlayer.Character) end
            bag.add(LocalPlayer.CharacterAdded:Connect(watchSeat))
        end, function()
            token += 1
            bag.clear()
            for part, value in pairs(modified) do
                pcall(function() part.CanCollide = value[1] part.CanTouch = value[2] end)
            end
            for prompt in pairs(prompts) do pcall(function() prompt:Destroy() end) end
            table.clear(modified)
            table.clear(prompts)
        end)
    end

    -- ======================================================================================
    -- Destroy body on death: the ragdoll stays in the world after you die and can be flung. Every part is
    -- moved below FallenPartsDestroyHeight, where the engine removes it, so nothing is left to kick.
    -- ======================================================================================
    do
        local bag = newBag()
        feature("misc_destroy_body", function()
            local function watch(char)
                local hum = char:WaitForChild("Humanoid", 5)
                if not hum then return end
                bag.add(hum.Died:Connect(function()
                    task.spawn(function()
                        local void = workspace.FallenPartsDestroyHeight - 60
                        local started = clock()
                        while clock() - started < 4 and char.Parent do
                            for _, part in ipairs(char:GetDescendants()) do
                                if part:IsA("BasePart") then
                                    part.Anchored = false
                                    part.AssemblyLinearVelocity = ZERO
                                    part.AssemblyAngularVelocity = ZERO
                                    part.CFrame = CFrame.new(part.Position.X, void, part.Position.Z)
                                end
                            end
                            RunService.Heartbeat:Wait()
                        end
                    end)
                end))
            end
            if LocalPlayer.Character then task.spawn(watch, LocalPlayer.Character) end
            bag.add(LocalPlayer.CharacterAdded:Connect(watch))
        end, function()
            bag.clear()
        end)
    end

    -- ======================================================================================
    -- Anti taze
    -- ======================================================================================
    do
        local bag, disabled, until_ = newBag(), {}, 0
        local lastSpeed, lastJump = 16, 7.2
        local remote

        local function sourceOf(connection)
            local ok, src = pcall(function() return connection.Function and debug.info(connection.Function, "s") end)
            return ok and type(src) == "string" and src or ""
        end

        local function hookGame()
            if type(getconnections) ~= "function" or not remote then return end
            local ok, list = pcall(getconnections, remote.OnClientEvent)
            if not ok or type(list) ~= "table" then return end
            for _, c in ipairs(list) do
                if c.Function and sourceOf(c):find("ClientInputHandler") then
                    pcall(function() c:Disable() end)
                    disabled[#disabled + 1] = c
                end
            end
        end

        feature("misc_anti_taze", function()
            local gun = ReplicatedStorage:FindFirstChild("GunRemotes") or ReplicatedStorage:WaitForChild("GunRemotes", 5)
            remote = gun and (gun:FindFirstChild("PlayerTased") or gun:WaitForChild("PlayerTased", 5))
            if not remote then warnf("PlayerTased remote not found") return end
            hookGame()
            bag.add(LocalPlayer.CharacterAdded:Connect(function()
                table.clear(disabled)
                task.delay(1.5, hookGame)
            end))
            bag.add(remote.OnClientEvent:Connect(function() until_ = clock() + 4 end))
            -- keep movement values the taze handler tries to zero out
            bag.add(RunService.Heartbeat:Connect(function()
                local _, hum = localParts()
                if not hum then return end
                if clock() < until_ then
                    if hum.WalkSpeed < lastSpeed then hum.WalkSpeed = lastSpeed end
                    if hum.JumpHeight < lastJump then hum.JumpHeight = lastJump end
                else
                    if hum.WalkSpeed > 0 then lastSpeed = hum.WalkSpeed end
                    if hum.JumpHeight > 0 then lastJump = hum.JumpHeight end
                end
            end))
        end, function()
            bag.clear()
            for _, c in ipairs(disabled) do pcall(function() c:Enable() end) end
            table.clear(disabled)
            until_ = 0
        end)
    end

    -- ======================================================================================
    -- Anti invisible: other players' animations the game does not use are weighted to zero
    -- ======================================================================================
    do
        local bag = newBag()
        local known = {}
        for _, id in ipairs({
            "125750702", "128777973", "128853357", "129423030", "129423131", "129967390", "129967478",
            "178130996", "180426354", "180435571", "180435792", "180436148", "180436334", "182393478",
            "182435998", "182436842", "182436935", "182491037", "182491065", "182491248", "182491277",
            "182491368", "182491423", "279227693", "279229192", "287112271", "388723916", "388726667",
            "389472570", "405194080", "405212265", "481088553", "481089053", "484200742", "484926359",
            "83690472549256", "107176344504758", "111090572475133", "113267949064300", "131326339350805",
        }) do known[id] = true end

        local function idOf(animationId) return tostring(animationId):match("(%d+)") end

        local function learn(root)
            if not root then return end
            for _, d in ipairs(root:GetDescendants()) do
                if d:IsA("Animation") then
                    local id = idOf(d.AnimationId)
                    if id then known[id] = true end
                end
            end
        end

        local suppressed, verdict = {}, {}
        local function consider(animTrack, player)
            if suppressed[animTrack] then return end
            local anim = animTrack.Animation
            local id = anim and idOf(anim.AnimationId)
            if not id or known[id] then return end
            local key = tostring(player.UserId) .. ":" .. id
            if verdict[key] == nil then
                -- animations that ship inside the game, the player's character or their tools are fine
                learn(ReplicatedStorage)
                learn(player.Character)
                learn(player:FindFirstChildOfClass("Backpack"))
                verdict[key] = known[id] == true
            end
            if verdict[key] then return end
            suppressed[animTrack] = player
            flagCheat(player, "invalid animation", 1)
        end

        local function watch(player)
            local char = player.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local animator = hum and (hum:FindFirstChildOfClass("Animator") or hum:WaitForChild("Animator", 5))
            if not animator then return end
            bag.add(animator.AnimationPlayed:Connect(function(animTrack) consider(animTrack, player) end))
            for _, animTrack in ipairs(animator:GetPlayingAnimationTracks()) do consider(animTrack, player) end
        end

        local function hookPlayer(player)
            if player == LocalPlayer then return end
            bag.add(player.CharacterAdded:Connect(function() task.spawn(watch, player) end))
            if player.Character then task.spawn(watch, player) end
        end

        feature("misc_anti_invis", function()
            for _, p in ipairs(Players:GetPlayers()) do hookPlayer(p) end
            bag.add(Players.PlayerAdded:Connect(hookPlayer))
            -- loop: every quarter second all players' playing tracks are checked again, so a target
            -- that resets (new character, new tracks) or re-plays the animation is suppressed again
            local acc, cleared = 0, 0
            bag.add(RunService.Heartbeat:Connect(function(dt)
                acc += dt
                cleared += dt
                if cleared > 6 then cleared = 0 table.clear(verdict) end
                if acc >= 0.25 then
                    acc = 0
                    for _, player in ipairs(Players:GetPlayers()) do
                        if player ~= LocalPlayer then
                            local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
                            local animator = hum and hum:FindFirstChildOfClass("Animator")
                            if animator then
                                for _, animTrack in ipairs(animator:GetPlayingAnimationTracks()) do consider(animTrack, player) end
                            end
                        end
                    end
                end
                for animTrack in pairs(suppressed) do
                    local ok, playing = pcall(function() return animTrack.IsPlaying end)
                    if not ok or not playing then
                        suppressed[animTrack] = nil
                    else
                        pcall(function() animTrack:AdjustWeight(0, 0) end)
                    end
                end
            end))
        end, function()
            bag.clear()
            table.clear(suppressed)
            table.clear(verdict)
        end)
    end

    -- ======================================================================================
    -- Melee aura (SillyScripts): fires the same remote the in-game melee tools fire on a hit
    -- ======================================================================================
    do
        local bag, acc = newBag(), 0
        feature("misc_melee", function()
            local melee = ReplicatedStorage:WaitForChild("meleeEvent", 5)
            if not melee then warnf("meleeEvent not found") return end
            acc = 0
            bag.add(RunService.Heartbeat:Connect(function(dt)
                acc += dt
                if acc < flag("misc_melee_delay", 0.5) then return end
                acc = 0
                local _, _, root = localParts()
                if not root then return end
                local range = flag("misc_melee_range", 15)
                for _, e in ipairs(otherEntities()) do
                    if (e.Root.Position - root.Position).Magnitude < range
                        and not (flag("misc_melee_friendly", true) and relationOf(e.Player) == "Friendly")
                        and not (flag("misc_melee_ff", true) and e.Character:FindFirstChildOfClass("ForceField")) then
                        melee:FireServer(e.Player, 1, 1)
                    end
                end
            end))
        end, function() bag.clear() end)
    end

    -- ======================================================================================
    -- Auto arrest and auto taze (guards)
    -- ======================================================================================
    local arrestUntil = 0
    do
        -- The handcuffs' own script only accepts: Criminals; Inmates that are Hostile and already Tased;
        -- Inmates that are not Hostile but Trespassing. Within 7.5 studs and without a forcefield.
        local bag, acc, warned = newBag(), 0, false
        local function arrestable(e)
            local char, team = e.Character, e.Player.Team
            if char:FindFirstChildOfClass("ForceField") or char:GetAttribute("Arrested") then return false end
            if team == TeamsService:FindFirstChild("Criminals") then return flag("misc_arrest_criminals", true) end
            if team == TeamsService:FindFirstChild("Inmates") then
                if not flag("misc_arrest_inmates", true) then return false end
                if char:GetAttribute("Hostile") then return char:GetAttribute("Tased") == true end
                return char:GetAttribute("Trespassing") == true
            end
            return false
        end

        feature("misc_autoarrest", function()
            local remotes = ReplicatedStorage:WaitForChild("Remotes", 5)
            local arrest = remotes and remotes:WaitForChild("ArrestPlayer", 5)
            if not arrest then warnf("ArrestPlayer remote not found") return end
            warned = false
            bag.add(RunService.Heartbeat:Connect(function(dt)
                acc += dt
                if acc < 0.05 or clock() < arrestUntil then return end
                acc = 0
                local char, hum, root = localParts()
                if not char or LocalPlayer.Team ~= TeamsService:FindFirstChild("Guards") then return end
                local range = math.min(flag("misc_arrest_range", 7.5), 7.5)
                local best, bestDist
                for _, e in ipairs(otherEntities()) do
                    local dist = (e.Root.Position - root.Position).Magnitude
                    if dist <= range and arrestable(e) and (not bestDist or dist < bestDist) then
                        best, bestDist = e, dist
                    end
                end
                if not best then return end

                if not char:FindFirstChild("Handcuffs") and flag("misc_arrest_hand", true) then
                    local pack = LocalPlayer:FindFirstChildOfClass("Backpack")
                    local cuffs = pack and pack:FindFirstChild("Handcuffs")
                    if cuffs then
                        hum:EquipTool(cuffs)
                        arrestUntil = clock() + 0.4 -- let the tool's own script finish equipping
                    elseif not warned then
                        warned = true
                        say("Auto arrest needs the Handcuffs tool")
                    end
                    return
                end

                local target = best
                arrestUntil = clock() + 0.5 -- do not stack invokes while this one is in flight
                task.spawn(function()
                    local ok, result = pcall(function() return arrest:InvokeServer(target.Player, 1) end)
                    if ok and result then
                        arrestUntil = clock() + 7
                        if flag("misc_arrest_notify", false) then say("Arrested " .. target.Player.Name) end
                    end
                end)
            end))
        end, function() bag.clear() end)
    end

    do
        -- The shot goes through the game's own gun code (castRay is told which part to report), so the
        -- ammo, animation, tracer and reload all behave normally. Without the gun hook the shot is sent directly.
        local bag, acc, cooldown, busy = newBag(), 0, 0, false
        local rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        rayParams.RespectCanCollide = true

        local function visible(fromPos, e, myChar)
            rayParams.FilterDescendantsInstances = { myChar, e.Character }
            return workspace:Raycast(fromPos, e.Head.Position - fromPos, rayParams) == nil
        end

        -- guards taze Criminals and Inmates that are Hostile or Trespassing; other teams taze anyone off their team
        local function wanted(e)
            local char, team = e.Character, e.Player.Team
            if LocalPlayer.TeamColor == e.Player.TeamColor then return false end
            if char:GetAttribute("Tased") or char:GetAttribute("Arrested") or char:FindFirstChildOfClass("ForceField") then return false end
            if LocalPlayer.Team == TeamsService:FindFirstChild("Guards") then
                if team == TeamsService:FindFirstChild("Criminals") then return true end
                if team == TeamsService:FindFirstChild("Inmates") then
                    return char:GetAttribute("Hostile") == true or char:GetAttribute("Trespassing") == true
                end
                return false
            end
            return true
        end

        local function fireTaser(target, taser, shootEvent)
            local char, hum = localParts()
            if not char then return end
            if taser.Parent ~= char then hum:EquipTool(taser) end
            local deadline = clock() + 5
            local kicked = false
            while clock() < deadline do
                local c = LocalPlayer.Character
                if not c or not target.Head.Parent or not target.Humanoid or target.Humanoid.Health <= 0 then return end
                if not isOn("misc_autotaze") or not wanted(target) then return end
                if taser.Parent == c then
                    local reload = taser:GetAttribute("Local_ReloadSession") or 0
                    local ammo = taser:GetAttribute("Local_CurrentAmmo") or 1
                    if reload == 0 and ammo > 0 then break end
                    if reload == 0 and ammo <= 0 and not kicked then
                        kicked = true
                        Actions.fireAt(target.Head, target.Head.Position) -- the gun reloads when it is empty
                    end
                end
                task.wait(0.05)
            end
            local c = LocalPlayer.Character
            if not c or taser.Parent ~= c then return end
            local head = c:FindFirstChild("Head")
            if not head then return end
            if Actions.fireAt(target.Head, target.Head.Position) then return end
            if shootEvent then
                pcall(function() shootEvent:FireServer({ { head.Position, target.Head.Position, target.Head } }) end)
            end
        end

        feature("misc_autotaze", function()
            local gun = ReplicatedStorage:WaitForChild("GunRemotes", 5)
            local shootEvent = gun and gun:WaitForChild("ShootEvent", 5)
            Actions.autoHook(true)
            acc = 0
            bag.add(RunService.Heartbeat:Connect(function(dt)
                acc += dt
                if acc < 0.05 or busy or clock() < cooldown or (arrestUntil - clock()) >= 3 then return end
                acc = 0
                local char, _, root = localParts()
                if not char then return end
                local pack = LocalPlayer:FindFirstChildOfClass("Backpack")
                local taser = char:FindFirstChild("Taser") or (pack and pack:FindFirstChild("Taser"))
                if not taser then return end
                if flag("misc_taze_velocity", true) and root.AssemblyLinearVelocity.Magnitude >= 40 then return end
                local head = char:FindFirstChild("Head")
                if not head then return end
                local range = flag("misc_taze_range", 52)
                local best, bestDist
                for _, e in ipairs(otherEntities()) do
                    local dist = (e.Head.Position - head.Position).Magnitude
                    if dist <= range and wanted(e) and visible(head.Position, e, char) and (not bestDist or dist < bestDist) then
                        best, bestDist = e, dist
                    end
                end
                if not best then return end
                busy = true
                task.spawn(function()
                    pcall(fireTaser, best, taser, shootEvent)
                    busy = false
                    cooldown = clock() + 1.5
                end)
            end))
        end, function()
            bag.clear()
            Actions.autoHook(false)
        end)
    end

    -- ======================================================================================
    -- Movement
    -- ======================================================================================
    do -- Fly
        local bag, yLevel = newBag(), nil
        feature("misc_fly", function()
            yLevel = nil
            bag.add(stepSignal:Connect(function(dt)
                local _, hum, root = localParts()
                if not root then yLevel = nil return end
                local speed = flag("misc_fly_speed", 50)
                local vertical = flag("misc_fly_vspeed", 40)
                local up = (not typing() and UserInputService:IsKeyDown(Enum.KeyCode.Space)) and 1 or 0
                local down = (not typing() and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)) and -1 or 0
                local dir = hum.MoveDirection
                if flag("misc_fly_mode", "Velocity") == "CFrame" then
                    yLevel = (yLevel or root.Position.Y) + (up + down) * vertical * dt
                    root.AssemblyLinearVelocity = ZERO
                    root.CFrame += v3(dir.X * speed * dt, yLevel - root.Position.Y, dir.Z * speed * dt)
                else
                    yLevel = nil
                    root.AssemblyLinearVelocity = v3(dir.X * speed, 2.25 + (up + down) * vertical, dir.Z * speed)
                end
                if flag("misc_fly_cap", true) then yLevel = capHeight(root, yLevel) end
            end))
        end, function() bag.clear() end)
    end

    do -- Speed
        local bag, savedSpeed = newBag(), nil
        feature("misc_speed", function()
            bag.add(stepSignal:Connect(function(dt)
                if isOn("misc_fly") or isOn("misc_longjump") then return end
                local _, hum, root = localParts()
                if not root or hum:GetState() == Enum.HumanoidStateType.Climbing then return end
                local speed = flag("misc_speed_value", 50)
                local mode = flag("misc_speed_mode", "Velocity")
                local dir = hum.MoveDirection
                if mode == "WalkSpeed" then
                    savedSpeed = savedSpeed or hum.WalkSpeed
                    hum.WalkSpeed = speed
                elseif mode == "CFrame" then
                    root.CFrame += dir * FLAT * speed * dt
                else
                    local v = root.AssemblyLinearVelocity
                    root.AssemblyLinearVelocity = v3(dir.X * speed, v.Y, dir.Z * speed)
                end
            end))
        end, function()
            bag.clear()
            local _, hum = localParts()
            if hum and savedSpeed then hum.WalkSpeed = savedSpeed end
            savedSpeed = nil
        end)
    end

    do -- High jump
        local bag = newBag()
        local function grounded(hum)
            local s = hum:GetState()
            return s == Enum.HumanoidStateType.Running or s == Enum.HumanoidStateType.Landed
        end
        local function jump()
            local _, hum, root = localParts()
            if not (hum and grounded(hum)) then return false end
            local power = flag("misc_highjump_power", 50)
            local mode = flag("misc_highjump_mode", "Velocity")
            if mode == "Velocity" then
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
                local v = root.AssemblyLinearVelocity
                root.AssemblyLinearVelocity = v3(v.X, power, v.Z)
            elseif mode == "Impulse" then
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
                RunService.Heartbeat:Once(function()
                    root:ApplyImpulse(v3(0, power - root.AssemblyLinearVelocity.Y, 0) * root.AssemblyMass)
                end)
            else
                local rise = math.max(power - hum.JumpHeight, 0)
                local total = 0
                repeat
                    total += rise * 0.016
                    rise -= workspace.Gravity * 0.016
                until rise <= 0
                root.CFrame += v3(0, total, 0)
            end
            return true
        end
        feature("misc_highjump", function()
            if flag("misc_highjump_auto", true) then
                local started = clock()
                bag.add(RunService.Heartbeat:Connect(function()
                    if jump() or clock() - started > 3 then
                        bag.clear()
                        switchOff("misc_highjump")
                    end
                end))
            else
                bag.add(RunService.RenderStepped:Connect(function()
                    if not typing() and UserInputService:IsKeyDown(Enum.KeyCode.Space) then jump() end
                end))
            end
        end, function() bag.clear() end)
    end

    do -- Long jump
        local bag = newBag()
        feature("misc_longjump", function()
            local enableAt = clock() + 0.1
            bag.add(stepSignal:Connect(function(dt)
                local _, hum, root = localParts()
                if not root then return end
                if hum.FloorMaterial ~= Enum.Material.Air then
                    if enableAt < clock() and flag("misc_longjump_auto", true) then
                        bag.clear()
                        switchOff("misc_longjump")
                        return
                    end
                    hum:ChangeState(Enum.HumanoidStateType.Jumping)
                end
                local dir = hum.MoveDirection * flag("misc_longjump_speed", 50)
                local mode = flag("misc_longjump_mode", "Velocity")
                if mode == "Velocity" then
                    root.AssemblyLinearVelocity = v3(dir.X, root.AssemblyLinearVelocity.Y, dir.Z)
                elseif mode == "Impulse" then
                    local diff = (dir - root.AssemblyLinearVelocity) * FLAT
                    if diff.Magnitude > (dir == ZERO and 10 or 2) then root:ApplyImpulse(diff * root.AssemblyMass) end
                else
                    root.CFrame += dir * dt
                end
            end))
        end, function() bag.clear() end)
    end

    do -- Phase
        local bag, modified = newBag(), {}
        local overlap = OverlapParams.new()
        local ray = RaycastParams.new()
        ray.FilterType = Enum.RaycastFilterType.Exclude
        ray.RespectCanCollide = true

        local function excluded()
            local list = { Camera(), LocalPlayer.Character }
            for _, e in ipairs(otherEntities()) do list[#list + 1] = e.Character end
            return list
        end

        local function release()
            for part in pairs(modified) do pcall(function() part.CanCollide = true end) end
            table.clear(modified)
        end

        local function normalAxis(hit)
            local cf, best, axis = hit.Instance.CFrame, 0, "Z"
            for _, normal in ipairs(Enum.NormalId:GetEnumItems()) do
                local dot = cf:VectorToWorldSpace(Vector3.fromNormalId(normal)):Dot(hit.Normal)
                if dot > best then best = dot axis = Vector3.fromNormalId(normal).X ~= 0 and "X" or "Z" end
            end
            return axis
        end

        feature("misc_phase", function()
            bag.add(RunService.Stepped:Connect(function()
                local char, hum, root = localParts()
                if not root then return end
                if isOn("misc_spider") and not shiftDown() then
                    if next(modified) then release() end
                    return
                end
                local mode = flag("misc_phase_mode", "Part")
                if mode == "Character" then
                    for _, part in ipairs(char:GetDescendants()) do
                        if part:IsA("BasePart") and part.CanCollide then modified[part] = true part.CanCollide = false end
                    end
                elseif mode == "Part" then
                    overlap.FilterType = Enum.RaycastFilterType.Exclude
                    overlap.FilterDescendantsInstances = excluded()
                    local parts = workspace:GetPartBoundsInBox(root.CFrame + v3(0, 1, 0), root.Size + v3(7, hum.HipHeight, 7), overlap)
                    local near = {}
                    for _, part in ipairs(parts) do
                        near[part] = true
                        if part.CanCollide then modified[part] = true part.CanCollide = false end
                    end
                    for part in pairs(modified) do
                        if not near[part] then modified[part] = nil part.CanCollide = true end
                    end
                else
                    local list = excluded()
                    ray.FilterDescendantsInstances = list
                    overlap.FilterType = Enum.RaycastFilterType.Exclude
                    overlap.FilterDescendantsInstances = list
                    local head = char:FindFirstChild("Head")
                    if not head or hum.MoveDirection.Magnitude < 0.1 then return end
                    local hit = workspace:Raycast(head.Position, hum.MoveDirection * 1.1, ray)
                    if hit then
                        local axis = normalAxis(hit)
                        local size = hit.Instance.Size[axis]
                        if size <= flag("misc_phase_size", 5) then
                            local dest = root.CFrame + hit.Normal * (-size - root.Size.X / 1.5)
                            if #workspace:GetPartBoundsInBox(dest, Vector3.one, overlap) <= 0 then root.CFrame = dest end
                        end
                    end
                end
            end))
        end, function()
            bag.clear()
            release()
        end)
    end

    do -- Spider
        local bag, active = newBag(), nil
        local ray = RaycastParams.new()
        ray.FilterType = Enum.RaycastFilterType.Exclude
        ray.RespectCanCollide = true
        feature("misc_spider", function()
            bag.add(stepSignal:Connect(function(dt)
                local char, hum, root = localParts()
                if not root then return end
                if isOn("misc_phase") and shiftDown() then active = nil return end
                local list = { Camera(), char }
                for _, e in ipairs(otherEntities()) do list[#list + 1] = e.Character end
                ray.FilterDescendantsInstances = list
                ray.CollisionGroup = root.CollisionGroup
                local hit = workspace:Raycast(root.Position - v3(0, hum.HipHeight - 0.5, 0), hum.MoveDirection * 2.5, ray)
                if active and not hit then
                    root.AssemblyLinearVelocity = v3(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
                end
                active = hit
                if hit and hit.Normal.Y == 0 then
                    local power = flag("misc_spider_speed", 30)
                    if flag("misc_spider_state", false) then hum:ChangeState(Enum.HumanoidStateType.Climbing) end
                    root.AssemblyLinearVelocity *= FLAT
                    local mode = flag("misc_spider_mode", "Velocity")
                    if mode == "CFrame" then root.CFrame += v3(0, power * dt, 0)
                    elseif mode == "Impulse" then root:ApplyImpulse(v3(0, power, 0) * root.AssemblyMass)
                    else root.AssemblyLinearVelocity += v3(0, power, 0) end
                end
            end))
        end, function()
            bag.clear()
            active = nil
        end)
    end


    -- ======================================================================================
    -- World: hit effects (SillyScripts presets)
    -- ======================================================================================
    ;(function()
        local Workspace = workspace
        -- The ten presets below are SillyScripts' own code, copied unchanged except that the colour, size and
        -- duration they read from its menu come from HE_color, HE_size and HE_duration.
        local HE_color, HE_size, HE_duration = Color3.fromRGB(255, 81, 0), 2, 2
        local HitEffects = {}
        HitEffects.Presets = {
		["nova"] = function(position)
			local instance4 = Instance.new("Part")
			instance4.Position = position
			instance4.Anchored = true
			instance4.Transparency = 1
			instance4.CanCollide = false
			instance4.Size = Vector3.one
			instance4.Parent = Workspace
			local colorSequence = ColorSequence.new(HE_color)
			local value = HE_size
			local value2 = HE_duration
			local instance5 = Instance.new("ParticleEmitter")
			instance5.Color = colorSequence
			instance5.Lifetime = NumberRange.new(0.5 * value2)
			instance5.LightEmission = 1
			instance5.LockedToPart = true
			instance5.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
			instance5.Rate = 0
			local new = NumberSequenceKeypoint.new
			instance5.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), new(1, 10 * value) })
			instance5.Speed = NumberRange.new(1.5)
			instance5.Texture = "rbxassetid://1084991215"
			local numberSequence = NumberSequence.new
			local tbl21 = {}
			local v6 = NumberSequenceKeypoint.new(0, 1)
			local v7 = NumberSequenceKeypoint.new(0.1, 0)
			local v8 = NumberSequenceKeypoint.new(0.6, 0)
			local new2 = NumberSequenceKeypoint.new
			tbl21[1] = v6
			tbl21[2] = v7
			tbl21[3] = v8

			do
				local values = table.pack(new2(1, 1))
				table.move(values, 1, values.n, 4, tbl21)
			end

			instance5.Transparency = numberSequence(tbl21)
			instance5.ZOffset = 1
			instance5.Parent = instance4
			local instance6 = Instance.new("ParticleEmitter")
			instance6.Color = colorSequence
			instance6.Lifetime = NumberRange.new(0.5 * value2)
			instance6.LightEmission = 1
			instance6.LockedToPart = true
			instance6.Rate = 0
			local new3 = NumberSequenceKeypoint.new
			instance6.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), new3(1, 10 * value) })
			instance6.Speed = NumberRange.new(0)
			instance6.Texture = "rbxassetid://1084991215"
			local numberSequence2 = NumberSequence.new
			local tbl22 = {}
			local v9 = NumberSequenceKeypoint.new(0, 1)
			local v10 = NumberSequenceKeypoint.new(0.1, 0)
			local v11 = NumberSequenceKeypoint.new(0.6, 0)
			local new4 = NumberSequenceKeypoint.new
			tbl22[1] = v9
			tbl22[2] = v10
			tbl22[3] = v11

			do
				local values = table.pack(new4(1, 1))
				table.move(values, 1, values.n, 4, tbl22)
			end

			instance6.Transparency = numberSequence2(tbl22)
			instance6.ZOffset = 1
			instance6.Parent = instance4
			local instance7 = Instance.new("ParticleEmitter")
			instance7.Color = colorSequence
			instance7.Lifetime = NumberRange.new(0.2 * value2, 0.5 * value2)
			instance7.LockedToPart = true
			instance7.Orientation = Enum.ParticleOrientation.VelocityParallel
			instance7.Rate = 0
			instance7.Rotation = NumberRange.new(-90, 90)
			local new5 = NumberSequenceKeypoint.new
			instance7.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1 * value), new5(1, 8.5 * value) })
			instance7.Speed = NumberRange.new(0.1)
			instance7.SpreadAngle = Vector2.new(180, 180)
			instance7.Texture = "http://www.roblox.com/asset/?id=6820680001"
			local numberSequence3 = NumberSequence.new
			local tbl23 = {}
			local v12 = NumberSequenceKeypoint.new(0, 1)
			local v13 = NumberSequenceKeypoint.new(0.2, 0)
			local v14 = NumberSequenceKeypoint.new(0.7, 0)
			local new6 = NumberSequenceKeypoint.new
			tbl23[1] = v12
			tbl23[2] = v13
			tbl23[3] = v14

			do
				local values = table.pack(new6(1, 1))
				table.move(values, 1, values.n, 4, tbl23)
			end

			instance7.Transparency = numberSequence3(tbl23)
			instance7.ZOffset = 1.5
			instance7.Parent = instance4
			instance5:Emit(1)
			instance6:Emit(1)
			instance7:Emit(1)

			task.delay(value2, function()
				instance4:Destroy()
			end)
		end,
		["sparks"] = function(position)
			local instance4 = Instance.new("Part")
			instance4.Position = position
			instance4.Anchored = true
			instance4.Transparency = 1
			instance4.CanCollide = false
			instance4.Size = Vector3.new(0.01, 0.01, 0.01)
			instance4.Parent = Workspace
			local colorSequence = ColorSequence.new(HE_color)
			local value = HE_size
			local value2 = HE_duration
			local instance5 = Instance.new("ParticleEmitter")
			instance5.Acceleration = Vector3.new(0, -50, 0)
			instance5.Color = colorSequence
			instance5.Lifetime = NumberRange.new(0.5 * value2, 1 * value2)
			instance5.LightEmission = 1
			instance5.Orientation = Enum.ParticleOrientation.VelocityParallel
			instance5.Rate = 0
			local numberSequence = NumberSequence.new
			local tbl21 = {}
			local v6 = NumberSequenceKeypoint.new(0, 0.6 * value)
			local v7 = NumberSequenceKeypoint.new(0.5, 0.6 * value)
			local new = NumberSequenceKeypoint.new
			tbl21[1] = v6
			tbl21[2] = v7

			do
				local values = table.pack(new(1, 0))
				table.move(values, 1, values.n, 3, tbl21)
			end

			instance5.Size = numberSequence(tbl21)
			instance5.Speed = NumberRange.new(15, 15)
			instance5.SpreadAngle = Vector2.new(50, -50)
			instance5.Texture = "http://www.roblox.com/asset/?id=18540695516"
			local numberSequence2 = NumberSequence.new
			local tbl22 = {}
			local v8 = NumberSequenceKeypoint.new(0, 0)
			local v9 = NumberSequenceKeypoint.new(0.5, 0)
			local new2 = NumberSequenceKeypoint.new
			tbl22[1] = v8
			tbl22[2] = v9

			do
				local values = table.pack(new2(1, 1))
				table.move(values, 1, values.n, 3, tbl22)
			end

			instance5.Transparency = numberSequence2(tbl22)
			instance5.Parent = instance4
			instance5:Emit(30)

			task.delay(value2 + 0.5, function()
				instance4:Destroy()
			end)
		end,
		["bubble"] = function(position)
			local instance4 = Instance.new("Part")
			instance4.Position = position
			instance4.Anchored = true
			instance4.Transparency = 1
			instance4.CanCollide = false
			instance4.Size = Vector3.new(0.01, 0.01, 0.01)
			instance4.Parent = Workspace
			local colorSequence = ColorSequence.new(HE_color)
			local value = HE_size
			local value2 = HE_duration
			local instance5 = Instance.new("ParticleEmitter")
			instance5.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
			instance5.Color = colorSequence
			instance5.LockedToPart = true
			instance5.Rate = 0
			instance5.Rotation = NumberRange.new(-5, 5)
			local numberSequence = NumberSequence.new
			local tbl21 = {}
			local v6 = NumberSequenceKeypoint.new(0, 1)
			local v7 = NumberSequenceKeypoint.new(0.464, 0.76875)
			local new = NumberSequenceKeypoint.new
			tbl21[1] = v6
			tbl21[2] = v7

			do
				local values = table.pack(new(1, 1))
				table.move(values, 1, values.n, 3, tbl21)
			end

			instance5.Transparency = numberSequence(tbl21)
			instance5.Texture = "rbxassetid://17086075673"
			instance5.Lifetime = NumberRange.new(0.45 * value2, 0.45 * value2)
			instance5.LightEmission = 1
			instance5.Brightness = 5
			instance5.Speed = NumberRange.new(0, 0)
			local new2 = NumberSequenceKeypoint.new
			instance5.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1 * value), new2(1, 6 * value) })
			instance5.Parent = instance4
			instance5:Emit(1)

			task.delay(value2, function()
				instance4:Destroy()
			end)
		end,
		["orbs"] = function(position)
			local instance4 = Instance.new("Part")
			instance4.Position = position
			instance4.Anchored = true
			instance4.Transparency = 1
			instance4.CanCollide = false
			instance4.Size = Vector3.new(0.01, 0.01, 0.01)
			instance4.Parent = Workspace
			ColorSequence.new(HE_color)
			local value = HE_size
			local value2 = HE_duration
			local instance5 = Instance.new("ParticleEmitter")
			instance5.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
			instance5.RotSpeed = NumberRange.new(-10, 10)
			instance5.FlipbookFramerate = NumberRange.new(40, 40)
			instance5.Drag = 1
			instance5.Rate = 0
			instance5.Texture = "rbxassetid://15011464541"
			instance5.Rotation = NumberRange.new(-1000, 1000)
			local new = NumberSequenceKeypoint.new
			instance5.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), new(1, 1) })
			instance5.SpreadAngle = Vector2.new(-1000, 1000)
			instance5.Lifetime = NumberRange.new(0.45 * value2, 0.45 * value2)
			instance5.LightEmission = 1
			instance5.Brightness = 10
			instance5.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid8x8
			local new2 = NumberSequenceKeypoint.new
			instance5.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 5.5 * value), new2(1, 5.5 * value) })
			instance5.Parent = instance4
			instance5:Emit(3)

			task.delay(value2, function()
				instance4:Destroy()
			end)
		end,
		["air"] = function(position)
			local instance4 = Instance.new("Part")
			instance4.Position = position
			instance4.Anchored = true
			instance4.Transparency = 1
			instance4.CanCollide = false
			instance4.Size = Vector3.new(0.01, 0.01, 0.01)
			instance4.Parent = Workspace
			ColorSequence.new(HE_color)
			local value = HE_size
			local value2 = HE_duration
			local instance5 = Instance.new("ParticleEmitter")
			instance5.FlipbookMode = Enum.ParticleFlipbookMode.PingPong
			instance5.Texture = "rbxassetid://10536350143"
			instance5.FlipbookFramerate = NumberRange.new(30, 30)
			instance5.Drag = 4.5
			instance5.Rate = 0
			instance5.Speed = NumberRange.new(0, 0)
			instance5.LightInfluence = 1
			instance5.Acceleration = Vector3.new(1, 0, 1)
			instance5.LockedToPart = true
			instance5.Lifetime = NumberRange.new(1 * value2, 1 * value2)
			instance5.LightEmission = 1
			instance5.Brightness = 10
			instance5.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid8x8
			local new = NumberSequenceKeypoint.new
			instance5.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3 * value), new(1, 3 * value) })
			instance5.Parent = instance4
			instance5:Emit(1)

			task.delay(value2 + 0.5, function()
				instance4:Destroy()
			end)
		end,
		["blood"] = function(position)
			local instance4 = Instance.new("Part")
			instance4.Transparency = 1
			instance4.Size = Vector3.new(2, 2, 2)
			instance4.Position = position
			instance4.CanCollide = false
			instance4.Anchored = true
			instance4.Parent = Workspace
			local instance5 = Instance.new("Attachment")
			instance5.Parent = instance4
			local colorSequence = ColorSequence.new(HE_color)
			local value = HE_size
			local value2 = HE_duration
			local instance6 = Instance.new("ParticleEmitter")
			instance6.Acceleration = Vector3.new(0, -75, 0)
			instance6.Color = colorSequence
			instance6.Lifetime = NumberRange.new(0.25 * value2, 0.5 * value2)
			instance6.Orientation = Enum.ParticleOrientation.VelocityParallel
			instance6.Rate = 0
			local new = NumberSequenceKeypoint.new
			instance6.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.125 * value), new(1, 0.25 * value) })
			instance6.Speed = NumberRange.new(5, 15)
			instance6.SpreadAngle = Vector2.new(90, 90)
			instance6.Texture = "rbxassetid://4509687978"
			local numberSequence = NumberSequence.new
			local tbl21 = {}
			local v6 = NumberSequenceKeypoint.new(0, 1)
			local v7 = NumberSequenceKeypoint.new(0.25, 0)
			local new2 = NumberSequenceKeypoint.new
			tbl21[1] = v6
			tbl21[2] = v7

			do
				local values = table.pack(new2(1, 1))
				table.move(values, 1, values.n, 3, tbl21)
			end

			instance6.Transparency = numberSequence(tbl21)
			instance6.Parent = instance5
			instance6:Emit(15)

			task.delay(value2, function()
				instance4:Destroy()
			end)
		end,
		["glitch"] = function(position)
			local instance4 = Instance.new("Part")
			instance4.Transparency = 1
			instance4.Size = Vector3.one
			instance4.Position = position
			instance4.CanCollide = false
			instance4.Anchored = true
			instance4.Parent = Workspace
			local colorSequence = ColorSequence.new(HE_color)
			local value = HE_size
			local value2 = HE_duration

			for i = 1, 5 do
				local instance5 = Instance.new("ParticleEmitter")
				instance5.Color = colorSequence
				instance5.Lifetime = NumberRange.new(0.1 * value2)
				instance5.Rate = 0
				instance5.Size = NumberSequence.new(0.4 * value)
				instance5.Texture = "rbxassetid://6888586040"
				instance5.Parent = instance4
				instance5:Emit(5)
			end

			task.delay(value2, function()
				instance4:Destroy()
			end)
		end,
		["slash"] = function(position)
			local instance4 = Instance.new("Part")
			instance4.Size = Vector3.one
			instance4.Anchored = true
			instance4.CanCollide = false
			instance4.Transparency = 1
			instance4.Position = position
			instance4.Parent = Workspace
			local instance5 = Instance.new("Attachment")
			instance5.Parent = instance4
			local colorSequence = ColorSequence.new(HE_color)
			local value = HE_size
			local value2 = HE_duration
			local instance6 = Instance.new("ParticleEmitter")
			instance6.Lifetime = NumberRange.new(0.2 * value2, 0.4 * value2)
			local numberSequence = NumberSequence.new
			local tbl21 = {}
			local v6 = NumberSequenceKeypoint.new(0, 1)
			local v7 = NumberSequenceKeypoint.new(0.2, 0)
			local v8 = NumberSequenceKeypoint.new(0.8, 0)
			local new = NumberSequenceKeypoint.new
			tbl21[1] = v6
			tbl21[2] = v7
			tbl21[3] = v8

			do
				local values = table.pack(new(1, 1))
				table.move(values, 1, values.n, 4, tbl21)
			end

			instance6.Transparency = numberSequence(tbl21)
			instance6.LightEmission = 10
			instance6.Color = colorSequence
			instance6.Speed = NumberRange.new(0.08)
			instance6.Brightness = 4
			local numberSequence2 = NumberSequence.new
			local tbl22 = {}
			local v9 = NumberSequenceKeypoint.new(0, 0)
			local v10 = NumberSequenceKeypoint.new(0.4, 8.8 * value)
			local new2 = NumberSequenceKeypoint.new
			tbl22[1] = v9
			tbl22[2] = v10

			do
				local values = table.pack(new2(1, 11.4 * value))
				table.move(values, 1, values.n, 3, tbl22)
			end

			instance6.Size = numberSequence2(tbl22)
			instance6.Texture = "rbxassetid://12509373457"
			instance6.RotSpeed = NumberRange.new(800, 1000)
			instance6.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
			instance6.Parent = instance5
			instance6:Emit(1)

			task.delay(value2, function()
				instance4:Destroy()
			end)
		end,
		["cosmic"] = function(position)
			local instance4 = Instance.new("Part")
			instance4.Size = Vector3.one
			instance4.Anchored = true
			instance4.CanCollide = false
			instance4.Transparency = 1
			instance4.Position = position
			instance4.Parent = Workspace
			local instance5 = Instance.new("Attachment")
			instance5.Parent = instance4
			local colorSequence = ColorSequence.new(HE_color)
			local value = HE_size
			local value2 = HE_duration

			local function fn58(texture, size, arg)
				local instance6 = Instance.new("ParticleEmitter")
				instance6.Color = colorSequence
				instance6.Texture = texture
				instance6.Size = size
				instance6.Lifetime = NumberRange.new(arg * value2)
				instance6.Brightness = 5
				instance6.Rate = 0
				instance6.Parent = instance5
				instance6:Emit(1)
			end

			fn58("rbxassetid://8708637750", NumberSequence.new(9 * value, 16 * value), 0.16)
			fn58("rbxassetid://8196169974", NumberSequence.new(0, 11 * value), 0.3)

			task.delay(value2, function()
				instance4:Destroy()
			end)
		end,
		["crescentslash"] = function(position)
			local instance4 = Instance.new("Part")
			instance4.Size = Vector3.one
			instance4.Anchored = true
			instance4.CanCollide = false
			instance4.Transparency = 1
			instance4.Position = position
			instance4.Parent = Workspace
			local instance5 = Instance.new("Attachment")
			instance5.Parent = instance4
			local colorSequence = ColorSequence.new(HE_color)
			local value = HE_size
			local value2 = HE_duration
			local instance6 = Instance.new("ParticleEmitter")
			instance6.Lifetime = NumberRange.new(0.16 * value2)
			instance6.Color = colorSequence
			instance6.Brightness = 5
			instance6.Size = NumberSequence.new(9 * value, 16 * value)
			instance6.Texture = "rbxassetid://8708637750"
			instance6.Rate = 0
			instance6.Parent = instance5
			instance6:Emit(1)
			local instance7 = Instance.new("ParticleEmitter")
			instance7.Lifetime = NumberRange.new(0.2 * value2, 0.7 * value2)
			instance7.Color = colorSequence
			instance7.Speed = NumberRange.new(90, 140)
			instance7.Texture = "rbxassetid://8030734851"
			instance7.Rate = 0
			instance7.Parent = instance5
			instance7:Emit(5)

			task.delay(value2, function()
				instance4:Destroy()
			end)
		end,
        }

        function HitEffects.Play(position, effectName, color, size, duration)
            local fn = HitEffects.Presets[string.lower(effectName or "nova")]
            if not fn or not position then return end
            HE_color, HE_size, HE_duration = color or Color3.fromRGB(255, 81, 0), size or 2, duration or 2
            fn(position)
        end

        local function emit(position)
            if typeof(position) ~= "Vector3" then return end
            local picker = Options.he_color
            local color = picker and typeof(picker.Value) == "Color3" and picker.Value or Color3.fromRGB(255, 81, 0)
            local ok, err = pcall(HitEffects.Play, position, flag("he_effect", "nova"), color, flag("he_size", 2), flag("he_duration", 2))
            if not ok then warnf("hit effect failed:", err) end
        end

        -- SillyScripts method: the effect plays from the result of the gun's own castRay, hooked in the
        -- combat code. "On hit" needs the hit part to belong to a player, "On shot" plays at every shot.
        local function isPlayerPart(part)
            local node = part
            while node and node ~= workspace do
                if node:IsA("Model") and Players:GetPlayerFromCharacter(node) then return true end
                node = node.Parent
            end
            return false
        end

        local function hooked()
            local check = ShotEvents.hooked
            return check ~= nil and check() == true
        end

        table.insert(ShotEvents.cast, function(part, position)
            if not flag("he_enabled", false) or typeof(position) ~= "Vector3" then return end
            if flag("he_trigger", "On hit") == "On shot" or (part and isPlayerPart(part)) then emit(position) end
        end)
        -- without the gun hook the tracer and damage events are used instead
        table.insert(ShotEvents.shot, function(_, target)
            if not hooked() and flag("he_enabled", false) and flag("he_trigger", "On hit") == "On shot" then emit(target) end
        end)
        table.insert(ShotEvents.hit, function(_, position)
            if not hooked() and flag("he_enabled", false) and flag("he_trigger", "On hit") == "On hit" then emit(position) end
        end)

        feature("he_enabled", function()
            local hook = Actions.fxHook
            if hook then hook(true) end
        end, function()
            local hook = Actions.fxHook
            if hook then hook(false) end
        end)

        Actions.previewHitEffect = function()
            local cam = Camera()
            if cam then emit(cam.CFrame.Position + cam.CFrame.LookVector * 14) end
        end

        onUnload(function()
            Actions.previewHitEffect = noop
        end)
    end)()

    -- ======================================================================================
    -- World: particle aura. Effects are cloned from the asset and parented to your parts.
    -- ======================================================================================
    ;(function()
        local bag, active, busy = newBag(), {}, false
        local SOURCES = {
            starlight = "rbxassetid://134645216613107", heavenly = "rbxassetid://139300897520961",
            ribbon = "rbxassetid://132069507632161", sakura = "rbxassetid://81755778619404",
            angel = "rbxassetid://97658130917593", wind = "rbxassetid://80694081850877",
            flow = "rbxassetid://119913533725648", star = "rbxassetid://73754563740680",
        }

        local function auraColor()
            local picker = Options.pa_color
            return picker and typeof(picker.Value) == "Color3" and picker.Value or Color3.fromRGB(133, 220, 255)
        end

        local function signature()
            return table.concat({ tostring(flag("pa_source", "angel")), tostring(auraColor()), tostring(Options.pa_color and Options.pa_color.Transparency or 0.2) }, "|")
        end

        local function clear()
            for index = #active, 1, -1 do
                pcall(function() active[index]:Destroy() end)
                active[index] = nil
            end
        end

        local function tint(inst)
            local color, alpha = auraColor(), Options.pa_color and tonumber(Options.pa_color.Transparency) or 0.2
            local class = inst.ClassName
            if class == "PointLight" or class == "Smoke" or class == "Fire" then
                inst.Color = color
                if class == "Fire" then inst.SecondaryColor = color:Lerp(Color3.new(1, 1, 1), 0.25) end
            elseif class == "Sparkles" then
                inst.SparkleColor = color
            elseif inst:IsA("Light") then
                inst.Color = color
            elseif class == "ParticleEmitter" or class == "Beam" or class == "Trail" then
                inst.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, color), ColorSequenceKeypoint.new(1, color) })
                pcall(function()
                    inst.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, alpha), NumberSequenceKeypoint.new(1, alpha) })
                end)
            end
        end

        local function apply()
            clear()
            local char = LocalPlayer.Character
            if not char then return end
            local model
            local id = SOURCES[flag("pa_source", "angel")]
            if not id then return end
            local ok, objects = pcall(function() return game:GetObjects(id) end)
            model = ok and objects and objects[1]
            if not model then warnf("particle aura asset could not be loaded") return end
            -- Same matching as SillyScripts (model part name = character part name). Aura models are often built
            -- for the other rig type, so R15 names also map onto the R6 body (and back) and a model that matches
            -- nothing is attached to the root part instead of doing nothing.
            local ALIAS = {
                UpperTorso = "Torso", LowerTorso = "Torso",
                LeftUpperArm = "Left Arm", LeftLowerArm = "Left Arm", LeftHand = "Left Arm",
                RightUpperArm = "Right Arm", RightLowerArm = "Right Arm", RightHand = "Right Arm",
                LeftUpperLeg = "Left Leg", LeftLowerLeg = "Left Leg", LeftFoot = "Left Leg",
                RightUpperLeg = "Right Leg", RightLowerLeg = "Right Leg", RightFoot = "Right Leg",
                Torso = "UpperTorso", ["Left Arm"] = "LeftUpperArm", ["Right Arm"] = "RightUpperArm",
                ["Left Leg"] = "LeftUpperLeg", ["Right Leg"] = "RightUpperLeg",
            }
            local function attach(part, target)
                for _, child in ipairs(part:GetChildren()) do
                    local clone = child:Clone()
                    clone.Parent = target
                    tint(clone)
                    for _, d in ipairs(clone:GetDescendants()) do tint(d) end
                    active[#active + 1] = clone
                end
            end
            local strict = flag("pa_source", "angel") == "angel" -- angel keeps SillyScripts' exact matching
            local used, attached = {}, 0
            for _, part in ipairs(model:GetChildren()) do
                if part:IsA("BasePart") then
                    local match = char:FindFirstChild(part.Name, true)
                    if not (match and match:IsA("BasePart")) and not strict then
                        match = nil
                        local alias = ALIAS[part.Name]
                        local other = alias and char:FindFirstChild(alias, true)
                        if other and other:IsA("BasePart") and not used[other] then match = other end
                    end
                    if match then
                        used[match] = true
                        attached += 1
                        attach(part, match)
                    end
                end
            end
            if attached == 0 and not strict then
                local root = char:FindFirstChild("HumanoidRootPart")
                if root then
                    for _, part in ipairs(model:GetChildren()) do
                        if part:IsA("BasePart") then attach(part, root) end
                    end
                end
            end
            pcall(function() model:Destroy() end)
        end

        feature("pa_enabled", function()
            local last
            local function refresh()
                if busy then return end
                busy = true
                last = signature()
                task.spawn(function()
                    pcall(apply)
                    busy = false
                end)
            end
            refresh()
            bag.add(LocalPlayer.CharacterAdded:Connect(function()
                task.delay(0.6, function() if isOn("pa_enabled") then last = nil end end)
            end))
            bag.add(RunService.Heartbeat:Connect(function()
                if not busy and signature() ~= last then refresh() end
            end))
        end, function()
            bag.clear()
            clear()
        end)
    end)()

    -- ======================================================================================
    -- Teleport: get guns and items
    -- ======================================================================================
    ;(function()
        -- The pickup instances are replaced after someone takes them, and their names carry a number, so the
        -- pickup is looked up again on every request (by name, then by the cleaned-up name) and the character is
        -- moved to where that pickup really is. The fixed position is only the fallback.
        local WEAPONS = {
            ["AK-47"] = { cframe = CFrame.new(-931.86, 92.2, 2039.39), item = "AK47_7", keys = { "ak47", "ak" }, tool = { "AK-47", "AK47" } },
            ["Remington 870"] = { cframe = CFrame.new(820.45, 100.8, 2229.68), item = "r870_2", keys = { "r870", "remington870", "remington" }, tool = { "Remington 870", "Remington" } },
            ["MP5"] = { cframe = CFrame.new(813.8, 100.8, 2229.62), item = "MP5_1", keys = { "mp5" }, tool = { "MP5" } },
            ["M700"] = { cframe = CFrame.new(-919.51, 95.07, 2036.23), item = "M700", keys = { "m700" }, tool = { "M700" } },
            ["M4A1"] = { cframe = CFrame.new(847.68, 100.88, 2229.05), item = "M4A1", keys = { "m4a1", "m4" }, tool = { "M4A1" } },
            ["FAL"] = { cframe = CFrame.new(-902.63, 94.35, 2047.25), item = "FAL", keys = { "fal" }, tool = { "FAL" } },
        }
        local ORDER = { "AK-47", "Remington 870", "MP5", "M700", "M4A1", "FAL", "Revolver" }
        local PLACES = {
            ["Yard"] = CFrame.new(780.21, 98, 2470.5),
            ["Academy"] = CFrame.new(795.87, 98.19, 2542.61),
            ["Prison"] = CFrame.new(913.48, 100, 2388.36),
            ["Armory"] = CFrame.new(831.13, 99.98, 2233.09),
            ["Cafeteria"] = CFrame.new(905.89, 99.99, 2316.14),
            ["Kitchen"] = CFrame.new(923.09, 99.99, 2231.35),
            ["Police car spawner"] = CFrame.new(615.18, 98.2, 2501.2),
            ["Top of the city building"] = CFrame.new(-309.72, 118.04, 2015.59),
        }
        local ITEMS = {
            ["Key card"] = { "Key card" }, Breakfast = { "Breakfast" }, Lunch = { "Lunch" }, Dinner = { "Dinner" },
            Soda = { "Snacks", "Soda" }, Chips = { "Snacks", "Chips" }, Chocolate = { "Snacks", "Chocolate" },
        }
        local busy = false

        local function hasTool(names)
            local pack = LocalPlayer:FindFirstChildOfClass("Backpack")
            for _, name in ipairs(names) do
                local found = (pack and pack:FindFirstChild(name)) or (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild(name))
                if found then return found end
            end
        end

        local function cleanName(name)
            return (string.lower(name):gsub("_%d+$", ""):gsub("[^%w]", ""))
        end

        local function positionOf(item)
            if item:IsA("BasePart") then return item.Position end
            if item:IsA("Model") then
                local ok, pivot = pcall(function() return item:GetPivot().Position end)
                if ok then return pivot end
            end
            local part = item:FindFirstChildWhichIsA("BasePart", true)
            return part and part.Position
        end

        local function findPickup(data)
            local folder = workspace:FindFirstChild("Prison_ITEMS")
            if not folder then return nil end
            local exact = folder:FindFirstChild(data.item, true)
            if exact then return exact end
            local wanted = {}
            for _, key in ipairs(data.keys) do wanted[key] = true end
            local best, bestDist
            for _, d in ipairs(folder:GetDescendants()) do
                if wanted[cleanName(d.Name)] then
                    local at = positionOf(d)
                    local dist = at and (at - data.cframe.Position).Magnitude or math.huge
                    if not bestDist or dist < bestDist then best, bestDist = d, dist end
                end
            end
            return best
        end

        local function getWeaponByPickup(name)
            local data = WEAPONS[name]
            if not data then return false end
            if busy then say("Still teleporting, wait a moment") return false end
            local _, _, root = localParts()
            if not root then say("You need to be alive") return false end
            local item = findPickup(data)
            if not item then
                warnf(name .. " pickup not found. Items near the armory:")
                local folder = workspace:FindFirstChild("Prison_ITEMS")
                if folder then
                    local shown = 0
                    for _, d in ipairs(folder:GetDescendants()) do
                        local at = positionOf(d)
                        if at and (at - data.cframe.Position).Magnitude < 60 and shown < 12 then
                            shown += 1
                            warnf("  ", d:GetFullName())
                        end
                    end
                end
                say(name .. " pickup was not found (it may be taken, it respawns after a while)")
                return false
            end
            local spot = positionOf(item)
            local stand = spot and CFrame.new(spot + v3(0, 3, 0)) or data.cframe

            busy = true
            local home = root.CFrame
            local hold = math.max(flag("tp_time", 0.8), 0.6)
            local started = clock()
            task.spawn(function()
                while clock() - started < hold and root.Parent do
                    local jitter = v3(math.random(-5, 5) / 10, 0, math.random(-5, 5) / 10)
                    root.AssemblyLinearVelocity = ZERO
                    root.CFrame = stand * CFrame.new(jitter)
                    task.wait()
                end
                if root.Parent and flag("tp_return", true) then root.CFrame = home end
                busy = false
            end)
            task.wait(0.5)
            local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
            local interact = remotes and remotes:FindFirstChild("InteractWithItem")
            if not interact then say("InteractWithItem remote not found") return false end
            local ok, result = pcall(function() return interact:InvokeServer(item) end)
            task.wait(math.max(hold - 0.5, 0.1) + 0.2)
            local got = hasTool(data.tool) ~= nil
            if got then
                say("Got " .. name)
            else
                say(name .. " was refused by the server" .. ((ok and result == false) and "" or " (no reply)") .. ": wrong team, missing pass or already taken")
            end
            return got
        end

        -- Weapons come from the game's own giver remote (ReplicatedStorage.Remotes.GiverPressed): free guns are
        -- TouchGiver models you stand on, the rest are click models. The remote is fired at the giver
        -- every frame while the character stands at the pickup, then the character goes home on the next render.
        local CollectionService = game:GetService("CollectionService")
        local GIVERS = {
            ["AK-47"] = { method = "touch", stand = CFrame.new(-931.7928, 81.2783, 2039.2554), pivot = v3(-931.7928, 91.2783, 2039.2554), needles = { "ak-47", "ak47" }, tool = { "AK-47", "AK47" } },
            ["Remington 870"] = { method = "touch", stand = CFrame.new(820.2986, 87.85, 2229.3962), pivot = v3(820.2986, 97.85, 2229.3962), needles = { "remington", "870" }, tool = { "Remington 870" } },
            ["MP5"] = { method = "touch", stand = CFrame.new(813.6986, 87.85, 2229.3962), pivot = v3(813.6986, 97.85, 2229.3962), needles = { "mp5" }, tool = { "MP5" } },
            ["M4A1"] = { method = "click", needles = { "m4a1", "m4" }, tool = { "M4A1" } },
            ["M700"] = { method = "click", needles = { "m700" }, tool = { "M700" } },
            ["FAL"] = { method = "click", needles = { "fal" }, tool = { "FAL" } },
            ["Revolver"] = { method = "click", needles = { "revolver" }, tool = { "Revolver" } },
        }

        local function giverRemote()
            local storage = game:GetService("ReplicatedStorage")
            local remotes = storage:FindFirstChild("Remotes")
            if not remotes then
                local shared = storage:FindFirstChild("SharedModules")
                remotes = shared and shared:FindFirstChild("Remotes")
            end
            return remotes and remotes:FindFirstChild("GiverPressed")
        end

        local function nameHas(name, needles)
            local lowered = string.lower(tostring(name))
            for _, needle in ipairs(needles) do
                if lowered:find(needle, 1, true) then return true end
            end
            return false
        end

        local function touchGivers()
            local list, seen = {}, {}
            local function add(inst)
                if inst and not seen[inst] then seen[inst] = true list[#list + 1] = inst end
            end
            pcall(function()
                for _, tag in ipairs({ "Giver", "TouchGiver" }) do
                    for _, inst in ipairs(CollectionService:GetTagged(tag)) do add(inst) end
                end
            end)
            pcall(function()
                for _, inst in ipairs(workspace:QueryDescendants("#TouchGiver")) do add(inst) end
            end)
            if #list == 0 then
                for _, inst in ipairs(workspace:GetDescendants()) do
                    if inst.Name == "TouchGiver" then add(inst) end
                end
            end
            return list
        end

        local giverCache = {}
        local function resolveGiver(name, entry)
            local cached = giverCache[name]
            if cached and cached.Parent then return cached end
            local list = touchGivers()
            local found
            for _, giver in ipairs(list) do
                local at = positionOf(giver)
                if at and (at - entry.pivot).Magnitude < 1.5 then found = giver break end
            end
            if not found then
                local bestDist = math.huge
                for _, giver in ipairs(list) do
                    local model = giver:IsA("Model") and giver or giver:FindFirstAncestorOfClass("Model")
                    local at = positionOf(giver)
                    if at and (nameHas(giver.Name, entry.needles) or (model and nameHas(model.Name, entry.needles))) then
                        local dist = (at - entry.pivot).Magnitude
                        if dist < bestDist then found, bestDist = giver, dist end
                    end
                end
            end
            if not found then
                local bestDist = 30
                for _, giver in ipairs(list) do
                    local at = positionOf(giver)
                    if at and (at - entry.stand.Position).Magnitude < bestDist then
                        found, bestDist = giver, (at - entry.stand.Position).Magnitude
                    end
                end
            end
            giverCache[name] = found
            return found
        end

        local function resolveClickModel(name, entry)
            local cached = giverCache[name]
            if cached and cached.Parent then return cached end
            local best, bestScore = nil, 0
            for _, inst in ipairs(workspace:GetDescendants()) do
                local lowered = string.lower(inst.Name)
                local score = 0
                for _, needle in ipairs(entry.needles) do
                    if lowered == needle then score = 100 elseif lowered:find(needle, 1, true) then score = math.max(score, 40) end
                end
                if score > 0 then
                    if inst:FindFirstChildWhichIsA("ClickDetector", true) then score += 25 end
                    if score > bestScore then best, bestScore = inst, score end
                end
            end
            giverCache[name] = best
            return best
        end

        local function pressGiver(remote, target)
            pcall(function() remote:FireServer(target) end)
            local model = target:IsA("Model") and target or target:FindFirstAncestorOfClass("Model")
            if model and model ~= target then pcall(function() remote:FireServer(model) end) end
            for _, d in ipairs(target:GetDescendants()) do
                if d:IsA("ClickDetector") and fireclickdetector then pcall(fireclickdetector, d) end
            end
        end

        local function grabFromGiver(name, entry)
            local remote = giverRemote()
            if not remote then return false end
            local _, _, root = localParts()
            if not root then say("You need to be alive") return false end
            if hasTool(entry.tool) then say("Already have " .. name) return true end
            local target, stand
            if entry.method == "touch" then
                target, stand = resolveGiver(name, entry), entry.stand
            else
                target = resolveClickModel(name, entry)
                local at = target and positionOf(target)
                stand = at and CFrame.new(at + v3(0, 3, 0))
            end
            if not target or not stand then return false end

            busy = true
            local home = root.CFrame
            local goHome = flag("tp_return", true)
            local timeout = entry.method == "touch" and 5 or math.max(flag("tp_time", 0.8), 1.6)
            local pad = Instance.new("Part")
            pad.Name = "Aster_GunPad"
            pad.Size = v3(16, 1, 16)
            pad.Anchored = true
            pad.Transparency = 1
            pad.CFrame = CFrame.new(stand.Position.X, stand.Position.Y - 0.5, stand.Position.Z)
            pad.Parent = workspace

            local started, got = clock(), false
            local connection = RunService.Heartbeat:Connect(function()
                if got or clock() - started > timeout then return end
                local _, _, current = localParts()
                if not current then return end
                current.CFrame = stand
                pressGiver(remote, target)
                if goHome then
                    pcall(function()
                        RunService:BindToRenderStep("Aster_GotWeapon", 101, function()
                            local _, _, now = localParts()
                            if now then now.CFrame = home now.AssemblyLinearVelocity = ZERO end
                            pcall(function() RunService:UnbindFromRenderStep("Aster_GotWeapon") end)
                        end)
                    end)
                end
            end)
            while not got and clock() - started < timeout do
                task.wait(0.1)
                if hasTool(entry.tool) then got = true end
            end
            connection:Disconnect()
            pcall(function() RunService:UnbindFromRenderStep("Aster_GotWeapon") end)
            local _, _, now = localParts()
            if now and goHome then now.CFrame = home now.AssemblyLinearVelocity = ZERO end
            task.delay(0.6, function() pcall(function() pad:Destroy() end) end)
            busy = false
            if got then say("Got " .. name) end
            return got
        end

        local function getWeapon(name)
            if busy then say("Still teleporting, wait a moment") return false end
            local entry = GIVERS[name]
            if entry and grabFromGiver(name, entry) then return true end
            local ok, result = pcall(getWeaponByPickup, name)
            if not ok then warnf("weapon pickup failed:", result) return false end
            return result
        end

        Actions.getWeapon = function(name) task.spawn(getWeapon, name) end
        Actions.getAllWeapons = function()
            task.spawn(function()
                for _, name in ipairs(ORDER) do
                    if not getWeapon(name) then task.wait(0.2) end
                    while busy do task.wait(0.1) end
                end
            end)
        end
        Actions.getItem = function(name)
            local path = ITEMS[name]
            local pack = LocalPlayer:FindFirstChildOfClass("Backpack")
            if not path or not pack then return end
            local node = game:GetService("ReplicatedStorage"):FindFirstChild("Tools")
            for _, step in ipairs(path) do node = node and node:FindFirstChild(step) end
            if not node then say(name .. " was not found") return end
            node:Clone().Parent = pack
            say("Added " .. name .. " (client-side copy)")
        end

        Actions.getPlace = function(name)
            local place = PLACES[name]
            local _, hum, root = localParts()
            if not place or not root then say("You need to be alive") return end
            if hum and hum.SeatPart then hum.Sit = false end
            root.AssemblyLinearVelocity = ZERO
            root.CFrame = place
            say("Teleported to " .. name)
        end

        onUnload(function()
            Actions.getWeapon, Actions.getAllWeapons, Actions.getItem, Actions.getPlace = noop, noop, noop, noop
        end)
    end)()

    -- ======================================================================================
    -- Fling cars: throws the Squad car at the nearest player (SillyScripts)
    -- ======================================================================================
    do
        local bag, saved, car = newBag(), {}, nil
        feature("misc_fling_cars", function()
            local container = waitForCars(3)
            car = container and container:FindFirstChild("Squad")
            if not car then
                say("Squad car not found")
                switchOff("misc_fling_cars")
                return
            end
            local root = car.PrimaryPart or car:FindFirstChildWhichIsA("BasePart", true)
            if not root then switchOff("misc_fling_cars") return end
            for _, d in ipairs(car:GetDescendants()) do
                if d:IsA("BasePart") then
                    saved[d] = d.CanCollide
                    d.CanCollide = false
                end
            end
            bag.add(RunService.Heartbeat:Connect(function()
                local _, _, myRoot = localParts()
                if not myRoot or not root.Parent then return end
                local best, bestDist
                local limit = flag("misc_fling_range", 300)
                for _, e in ipairs(otherEntities()) do
                    local d = (e.Root.Position - myRoot.Position).Magnitude
                    if d <= limit and (not bestDist or d < bestDist) then best, bestDist = e, d end
                end
                if not best then return end
                local goal = best.Root.Position + v3(math.random(-2, 2), 3, math.random(-2, 2))
                local spin = CFrame.Angles(math.rad(math.random(-45, 45)), 0, math.rad(math.random(-45, 45)))
                car:PivotTo(car:GetPivot():Lerp(CFrame.lookAt(goal, goal + v3(0, 10, 0)) * spin, 0.5))
                root.AssemblyLinearVelocity = v3(math.random(-1, 1), 1, math.random(-1, 1)) * 800
            end))
        end, function()
            bag.clear()
            for part, value in pairs(saved) do pcall(function() part.CanCollide = value end) end
            table.clear(saved)
            if car then
                local root = car.PrimaryPart or car:FindFirstChildWhichIsA("BasePart", true)
                if root then pcall(function() root.AssemblyLinearVelocity = ZERO end) end
            end
            car = nil
        end)
    end

    -- ======================================================================================
    -- Invisibility: animation freeze (SillyScripts). The animation ids come from their build;
    -- they could not be checked here, so behavior depends on the game still accepting them.
    -- ======================================================================================
    do
        local bag, animTrack, token = newBag(), nil, 0
        local held, saved, autoRotate, platform = nil, {}, nil, nil

        local function stopAnim()
            if animTrack then
                pcall(function() animTrack:Stop(0) end)
                pcall(function() animTrack:Destroy() end)
                animTrack = nil
            end
        end

        -- put the body back the way it was
        local function letGo()
            for part, value in pairs(saved) do pcall(function() part.CanCollide = value end) end
            table.clear(saved)
            local _, hum, root = localParts()
            if hum then
                if autoRotate ~= nil then hum.AutoRotate = autoRotate end
                if platform ~= nil then hum.PlatformStand = platform end
            end
            if root and held then
                root.AssemblyLinearVelocity = ZERO
                root.AssemblyAngularVelocity = ZERO
                root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, held.yaw, 0)
            end
            autoRotate, platform, held = nil, nil, nil
        end

        local function start()
            stopAnim()
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local animator = hum and (hum:FindFirstChildOfClass("Animator") or hum:WaitForChild("Animator", 2))
            if not animator then return end
            local r15 = hum.RigType == Enum.HumanoidRigType.R15
            local anim = Instance.new("Animation")
            anim.AnimationId = "rbxassetid://" .. (r15 and "18665825805" or "215384594")
            local loaded = animator:LoadAnimation(anim)
            loaded.Priority = Enum.AnimationPriority.Action4
            loaded:Play(0, 1, 0)
            task.defer(function()
                if loaded then
                    loaded.TimePosition = r15 and 1.95 or 0.4
                    loaded:AdjustSpeed(0)
                end
            end)
            animTrack = loaded
            anim:Destroy()
        end

        feature("misc_invis", function()
            token += 1
            local my = token
            task.spawn(function() if my == token then start() end end)
            bag.add(LocalPlayer.CharacterAdded:Connect(function()
                table.clear(saved)
                held, autoRotate, platform = nil, nil, nil
                task.delay(0.8, function() if my == token then start() end end)
            end))
            -- The frozen pose hangs below the character, so tilting the character to look up puts that
            -- pose under the map. The body is pinned in place (no velocity, no collisions, no humanoid
            -- forces) so the physics engine cannot throw it around while it is tilted.
            bag.add(stepSignal:Connect(function(dt)
                if not flag("misc_invis_under", true) then
                    if held then letGo() end
                    return
                end
                local char, hum, root = localParts()
                if not root then held = nil return end
                if not held then
                    local _, yaw = root.CFrame:ToEulerAnglesYXZ()
                    held = { pos = root.Position, yaw = yaw }
                    autoRotate, platform = hum.AutoRotate, hum.PlatformStand
                end
                hum.AutoRotate = false
                hum.PlatformStand = true
                for _, part in ipairs(char:GetChildren()) do
                    if part:IsA("BasePart") then
                        if saved[part] == nil then saved[part] = part.CanCollide end
                        part.CanCollide = false
                    end
                end
                if flag("misc_invis_move", false) then
                    local dir = hum.MoveDirection
                    if dir.Magnitude > 0.1 then
                        held.pos += v3(dir.X, 0, dir.Z).Unit * hum.WalkSpeed * dt
                        held.yaw = math.atan2(-dir.X, -dir.Z)
                    end
                end
                root.AssemblyLinearVelocity = ZERO
                root.AssemblyAngularVelocity = ZERO
                root.CFrame = CFrame.new(held.pos) * CFrame.fromEulerAnglesYXZ(math.rad(flag("misc_invis_pitch", 90)), held.yaw, 0)
            end))
        end, function()
            token += 1
            bag.clear()
            stopAnim()
            letGo()
            local char = LocalPlayer.Character
            if char then
                for _, d in ipairs(char:GetDescendants()) do
                    if d:IsA("BasePart") then pcall(function() d.LocalTransparencyModifier = 0 end) end
                end
            end
        end)
    end

    -- ======================================================================================
    -- Walk speed: a fixed speed or an automatic one for the area you are in, and no acceleration.
    -- Areas: outside the prison compound, in the prison area (open ground inside the fences) and
    -- inside the prison (anything with a roof over it). The compound is the box around the
    -- electric fences in workspace.Prison_Fences; a fixed box is used when they cannot be found.
    -- ======================================================================================
    do
        local bag = newBag()
        local FALLBACK_MIN, FALLBACK_MAX = v3(690, -50, 2170), v3(1010, 600, 2620)
        local ANCHOR = v3(850, 100, 2400)
        local DEFAULT_SPEEDS = { inside = 32, yard = 50, outside = 100 }
        local SPEED_FLAGS = { inside = "misc_walk_in", yard = "misc_walk_yard", outside = "misc_walk_out" }
        local AREA_NAMES = { inside = "inside prison", yard = "prison area", outside = "outside prison" }
        local bounds, boundsAt = nil, -100
        local roof = RaycastParams.new()
        roof.FilterType = Enum.RaycastFilterType.Exclude
        roof.RespectCanCollide = true

        local function extents(part)
            local cf, s = part.CFrame, part.Size
            local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
            return v3(
                (math.abs(r.X) * s.X + math.abs(u.X) * s.Y + math.abs(l.X) * s.Z) / 2,
                (math.abs(r.Y) * s.X + math.abs(u.Y) * s.Y + math.abs(l.Y) * s.Z) / 2,
                (math.abs(r.Z) * s.X + math.abs(u.Z) * s.Y + math.abs(l.Z) * s.Z) / 2)
        end

        local function computeBounds()
            local lo, hi
            local function grow(part)
                if (part.Position - ANCHOR).Magnitude > 450 then return end
                local e = extents(part)
                local pmin, pmax = part.Position - e, part.Position + e
                if lo then
                    lo = v3(math.min(lo.X, pmin.X), math.min(lo.Y, pmin.Y), math.min(lo.Z, pmin.Z))
                    hi = v3(math.max(hi.X, pmax.X), math.max(hi.Y, pmax.Y), math.max(hi.Z, pmax.Z))
                else
                    lo, hi = pmin, pmax
                end
            end
            local fences = workspace:FindFirstChild("Prison_Fences")
            if fences then
                local electric = false
                for _, d in ipairs(fences:GetDescendants()) do
                    if d:IsA("BasePart") and d:FindFirstChild("TouchInterest") then
                        grow(d)
                        electric = true
                    end
                end
                if not electric then
                    for _, d in ipairs(fences:GetDescendants()) do
                        if d:IsA("BasePart") then grow(d) end
                    end
                end
            end
            if lo and hi and (hi.X - lo.X) > 120 and (hi.Z - lo.Z) > 120 then
                return { lo - v3(8, 0, 8), hi + v3(8, 0, 8), "fences" }
            end
            return { FALLBACK_MIN, FALLBACK_MAX, "fixed box" }
        end

        -- "inside", "yard" or "outside"
        Actions.area = function(position)
            local now = clock()
            if not bounds or now - boundsAt > 30 then
                bounds, boundsAt = computeBounds(), now
            end
            local lo, hi = bounds[1], bounds[2]
            if position.X < lo.X or position.X > hi.X or position.Z < lo.Z or position.Z > hi.Z then return "outside" end
            local list = { Camera() }
            for _, player in ipairs(Players:GetPlayers()) do
                if player.Character then list[#list + 1] = player.Character end
            end
            roof.FilterDescendantsInstances = list
            local hit = workspace:Raycast(position + v3(0, 2.5, 0), v3(0, 80, 0), roof)
            if hit and hit.Instance.Transparency < 0.9 then return "inside" end
            return "yard"
        end
        Actions.areaBounds = function()
            if not bounds then bounds, boundsAt = computeBounds(), clock() end
            return bounds
        end

        local areaName, areaAt = "", 0
        local function currentArea(root)
            local now = clock()
            if now - areaAt > 0.25 then
                areaAt = now
                local nextArea = Actions.area(root.Position)
                if nextArea ~= areaName then
                    areaName = nextArea
                    if flag("misc_walk_notify", false) then
                        local custom = flag("misc_walk_custom", false)
                        local speed = custom and flag(SPEED_FLAGS[nextArea], DEFAULT_SPEEDS[nextArea]) or DEFAULT_SPEEDS[nextArea]
                        say(string.format("Area: %s (%.0f studs/s, bounds from %s)", AREA_NAMES[nextArea], speed, Actions.areaBounds()[3]))
                    end
                end
            end
            return areaName
        end

        feature("misc_walk", function()
            areaName, areaAt = "", 0
            bag.add(stepSignal:Connect(function()
                local _, hum, root = localParts()
                if not hum or hum.WalkSpeed <= 0.1 then return end
                local speed = flag("misc_walk_value", 16)
                if flag("misc_walk_auto", false) then
                    local area = currentArea(root)
                    speed = DEFAULT_SPEEDS[area]
                    if flag("misc_walk_custom", false) then speed = flag(SPEED_FLAGS[area], speed) end
                end
                hum.WalkSpeed = speed
            end))
        end, function()
            bag.clear()
            local _, hum = localParts()
            if hum and hum.WalkSpeed > 0.1 then hum.WalkSpeed = 16 end
        end)
    end

    do
        local bag = newBag()
        local SKIP_STATES = {
            [Enum.HumanoidStateType.Climbing] = true, [Enum.HumanoidStateType.Swimming] = true,
            [Enum.HumanoidStateType.Seated] = true, [Enum.HumanoidStateType.Dead] = true,
            [Enum.HumanoidStateType.Physics] = true, [Enum.HumanoidStateType.Ragdoll] = true,
            [Enum.HumanoidStateType.FallingDown] = true, [Enum.HumanoidStateType.PlatformStanding] = true,
        }
        feature("misc_noaccel", function()
            bag.add(stepSignal:Connect(function()
                local _, hum, root = localParts()
                if not hum or not root or hum.WalkSpeed <= 0.1 or hum.SeatPart or hum.Sit then return end
                if SKIP_STATES[hum:GetState()] or hum.FloorMaterial == Enum.Material.Air then return end
                if isOn("misc_fly") or isOn("misc_speed") or isOn("misc_invis") then return end
                local velocity = root.AssemblyLinearVelocity
                local flat = v3(velocity.X, 0, velocity.Z).Magnitude
                -- something else is pushing you (a fling, an explosion): leave it alone
                if flat > math.max(hum.WalkSpeed * 1.6, 45) then return end
                local direction = hum.MoveDirection
                if direction.Magnitude > 0.05 then
                    root.AssemblyLinearVelocity = v3(direction.X * hum.WalkSpeed, velocity.Y, direction.Z * hum.WalkSpeed)
                else
                    root.AssemblyLinearVelocity = v3(0, velocity.Y, 0)
                end
            end))
        end, function() bag.clear() end)
    end

    -- ======================================================================================
    -- Movement: jump multiplier, spinbot
    -- ======================================================================================
    do
        local bag, original = newBag(), nil
        feature("misc_jumpmult", function()
            local _, hum = localParts()
            if hum then original = { use = hum.UseJumpPower, power = hum.JumpPower } end
            bag.add(stepSignal:Connect(function()
                local _, h = localParts()
                if not h then return end
                local current = h.UseJumpPower and h.JumpPower or h.JumpHeight
                if current <= 0.1 then return end
                h.UseJumpPower = true
                h.JumpPower = 50 * math.clamp(flag("misc_jumpmult_value", 1.5), 1, 3)
            end))
        end, function()
            bag.clear()
            local _, hum = localParts()
            if hum and original then
                hum.JumpPower = original.power
                hum.UseJumpPower = original.use
            end
            original = nil
        end)
    end

    do
        local bag, joint, base, angle, autoRotate = newBag(), nil, nil, 0, nil
        local function findJoint(char)
            local root = char:FindFirstChild("HumanoidRootPart")
            if not root then return end
            local direct = root:FindFirstChild("RootJoint")
            if direct and direct:IsA("Motor6D") then return direct end
            local lower = char:FindFirstChild("LowerTorso")
            local r15 = lower and lower:FindFirstChild("Root")
            if r15 and r15:IsA("Motor6D") then return r15 end
        end
        local function restore()
            if joint and base then pcall(function() joint.C0 = base end) end
            local _, hum = localParts()
            if hum and autoRotate ~= nil then hum.AutoRotate = autoRotate end
            joint, base, autoRotate = nil, nil, nil
        end
        feature("misc_spinbot", function()
            bag.add(stepSignal:Connect(function(dt)
                local char, hum = localParts()
                if not char then return end
                if not joint or not joint.Parent or not joint:IsDescendantOf(char) then
                    restore()
                    joint = findJoint(char)
                    if not joint then return end
                    base = joint.C0
                    autoRotate = hum.AutoRotate
                end
                hum.AutoRotate = false
                angle = (angle + flag("misc_spinbot_speed", 10) * 16 * dt) % 360
                joint.C0 = CFrame.Angles(0, math.rad(angle), 0) * base
            end))
        end, function()
            bag.clear()
            restore()
        end)
    end

    -- ======================================================================================
    -- Vehicle fly and vehicle speed
    -- ======================================================================================
    do
        local bag, welds, lastSeat, inCar, up, down = newBag(), {}, nil, false, 0, 0
        feature("misc_vfly", function()
            up, down, lastSeat, inCar = 0, 0, nil, false
            for _, signalName in ipairs({ "InputBegan", "InputEnded" }) do
                bag.add(UserInputService[signalName]:Connect(function(input)
                    if typing() then return end
                    local began = signalName == "InputBegan"
                    if input.KeyCode == Enum.KeyCode.E then up = began and 1 or 0
                    elseif input.KeyCode == Enum.KeyCode.Q then down = began and -1 or 0 end
                end))
            end
            bag.add(stepSignal:Connect(function(dt)
                local _, hum, root = localParts()
                local seat = hum and hum.SeatPart
                if not seat then lastSeat, inCar = nil, false return end
                if seat ~= lastSeat then
                    lastSeat = seat
                    local cars = workspace:FindFirstChild("CarContainer")
                    inCar = cars ~= nil and seat:IsA("VehicleSeat") and seat:IsDescendantOf(cars)
                    table.clear(welds)
                    if inCar then
                        pcall(function()
                            local wheels = seat.Parent.Parent:FindFirstChild("Wheels")
                            if wheels then
                                for _, d in ipairs(wheels:GetDescendants()) do
                                    if d.Name == "Rotate" and d:IsA("JointInstance") and d.Part0 then
                                        welds[d] = root.CFrame:ToObjectSpace(d.Part0.CFrame)
                                    end
                                end
                            end
                        end)
                    end
                end
                if not inCar then return end
                local cam = Camera()
                local speed = flag("misc_vfly_speed", 60)
                local vertical = up + down
                root.AssemblyLinearVelocity = v3(0, 2.25, 0)
                if flag("misc_vfly_camera", true) then
                    local yaw = select(2, cam.CFrame:ToEulerAnglesYXZ())
                    local move = CFrame.fromEulerAnglesYXZ(0, yaw, 0):VectorToObjectSpace(hum.MoveDirection)
                    root.CFrame = CFrame.lookAlong(root.Position, cam.CFrame.LookVector) * CFrame.new(v3(move.X, vertical, move.Z) * speed * dt)
                else
                    root.CFrame = CFrame.lookAlong(root.Position, cam.CFrame.LookVector) + (hum.MoveDirection + v3(0, vertical, 0)) * speed * dt
                end
                if flag("misc_vfly_cap", true) then
                    capHeight(root, nil, workspace:FindFirstChild("CarContainer"))
                end
                for weld, offset in pairs(welds) do
                    if weld.Part0 then weld.Part0.CFrame = root.CFrame * offset end
                end
            end))
        end, function()
            bag.clear()
            table.clear(welds)
            lastSeat, inCar = nil, false
        end)
    end

    do
        local bag, saved, lastSeat = newBag(), {}, nil
        feature("misc_vspeed", function()
            lastSeat = nil
            bag.add(RunService.Heartbeat:Connect(function()
                local _, hum = localParts()
                local seat = hum and hum.SeatPart
                if not seat then return end
                if seat ~= lastSeat then
                    lastSeat = seat
                    local cars = workspace:FindFirstChild("CarContainer")
                    if cars and seat:IsDescendantOf(cars) then
                        local model = seat.Parent and seat.Parent.Parent
                        for _, d in ipairs((model or seat.Parent):GetDescendants()) do
                            if d:IsA("VehicleSeat") and not saved[d] then
                                saved[d] = { speed = d.MaxSpeed, torque = d.Torque }
                            end
                        end
                    end
                end
                local value = flag("misc_vspeed_value", 140)
                for s in pairs(saved) do
                    if s.Parent then s.MaxSpeed = value s.Torque = 4 end
                end
            end))
        end, function()
            bag.clear()
            for s, o in pairs(saved) do
                pcall(function() s.MaxSpeed = o.speed s.Torque = o.torque end)
            end
            table.clear(saved)
            lastSeat = nil
        end)
    end

    -- ======================================================================================
    -- Server position: what the server and other players see can differ from where you stand.
    -- At the end of the physics step the character is moved to the server position (that is what
    -- gets sent) and at the start of the next frame it is put back (what you see and walk on).
    -- Desync and wallbang assist both use it. A highlighted copy of your character shows the spot.
    -- ======================================================================================
    do
        local SP = Actions.sp
        local requests, order = {}, { "assist", "desync" }
        local engine = newBag()
        local running = false
        local applied, realCF = nil, nil
        local lastSpeed, lastStyle, lastWarn = 100, nil, 0
        local RESTORE, GHOST = "AsterServerPosRestore", "AsterServerPosGhost"
        SP.pos = nil

        local rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        rayParams.RespectCanCollide = true

        -- the position you really stand at, even right after the server position was applied
        function SP.realPos(root)
            if applied and realCF then return realCF.Position end
            return root.Position
        end
        -- the position shots are measured from: the server position while one is set
        function SP.shooter(root)
            return SP.pos or SP.realPos(root)
        end

        local function picker(name, fallbackColor, fallbackAlpha)
            local object = Options[name]
            local color = object and typeof(object.Value) == "Color3" and object.Value or fallbackColor
            local alpha = object and tonumber(object.Transparency) or fallbackAlpha
            return color, alpha
        end
        function SP.visualStyle(fillFlag, lineFlag, tracerFlag)
            local fill, fillT = picker(fillFlag, WHITE, 0.6)
            local line, lineT = picker(lineFlag, WHITE, 0)
            local style = { fill = fill, fillT = fillT, line = line, lineT = lineT }
            if tracerFlag then style.tracer, style.tracerT = picker(tracerFlag, WHITE, 0) end
            return style
        end

        local function groundBelow(position, lowest)
            local list = {}
            for _, player in ipairs(Players:GetPlayers()) do
                if player.Character then list[#list + 1] = player.Character end
            end
            list[#list + 1] = Camera()
            rayParams.FilterDescendantsInstances = list
            local hit = workspace:Raycast(position, v3(0, -600, 0), rayParams)
            if not hit then return nil end
            local floorY = hit.Position.Y
            if lowest then
                for _ = 1, 6 do
                    local below = workspace:Raycast(v3(position.X, floorY - 0.25, position.Z), v3(0, -600, 0), rayParams)
                    if not below then break end
                    floorY = below.Position.Y
                end
            end
            return floorY
        end

        local function follow(current, goal, speed, dt)
            local delta = goal - current
            local distance = delta.Magnitude
            local step = speed * dt
            if speed >= 4000 or distance <= step then return goal end
            return current + delta * (step / distance)
        end

        -- ghost: a copy of your character parts, moved by the same offset, with a Highlight ----
        local ghost = { model = nil, highlight = nil, parts = {}, char = nil, count = 0, checked = 0, line = nil }

        local function hideGhost()
            if ghost.model then ghost.model.Parent = nil end
            if ghost.line then ghost.line.Visible = false end
        end
        local function destroyGhost()
            if ghost.model then pcall(function() ghost.model:Destroy() end) end
            ghost.model, ghost.highlight, ghost.char = nil, nil, nil
            table.clear(ghost.parts)
            if ghost.line then pcall(function() ghost.line.Visible = false end) end
        end
        local function buildGhost(char)
            destroyGhost()
            local model = Instance.new("Model")
            model.Name = "AsterServerPosition"
            local descendants = char:GetDescendants()
            for _, d in ipairs(descendants) do
                if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" and d.Transparency < 0.95 then
                    local ok, clone = pcall(function() return d:Clone() end)
                    if ok and clone then
                        for _, child in ipairs(clone:GetChildren()) do
                            if not child:IsA("SpecialMesh") then child:Destroy() end
                        end
                        clone.Anchored = true
                        clone.CanCollide = false
                        clone.CanTouch = false
                        clone.CanQuery = false
                        clone.CastShadow = false
                        clone.Massless = true
                        clone.Transparency = 0 -- rendered like a real character, so the Highlight always draws (same as self chams)
                        clone.Material = Enum.Material.SmoothPlastic
                        clone.Parent = model
                        ghost.parts[#ghost.parts + 1] = { d, clone }
                    end
                end
            end
            local highlight = Instance.new("Highlight")
            highlight.Adornee = model
            highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            highlight.Parent = model
            ghost.model, ghost.highlight, ghost.char = model, highlight, char
            ghost.count, ghost.checked = #descendants, clock()
        end
        local function newLine()
            if not (Drawing and type(Drawing.new) == "function") then return nil end
            local ok, line = pcall(Drawing.new, "Line")
            if ok and line then
                table.insert(getgenv().TS_Drawings, line)
                return line
            end
            return nil
        end

        local function updateGhost()
            local style = lastStyle
            local char, _, root = localParts()
            local cam = workspace.CurrentCamera
            if not SP.pos or not style or not root or not cam then
                hideGhost()
                return
            end
            local now = clock()
            if ghost.char ~= char or not ghost.model then
                buildGhost(char)
            elseif now - ghost.checked > 0.5 then
                ghost.checked = now
                if #char:GetDescendants() ~= ghost.count then buildGhost(char) end
            end
            if ghost.model.Parent ~= cam then ghost.model.Parent = cam end
            local shift = SP.pos - root.Position
            for _, pair in ipairs(ghost.parts) do
                if pair[1].Parent then
                    pair[2].CFrame = pair[1].CFrame + shift
                    pair[2].Color = style.fill
                end
            end
            local highlight = ghost.highlight
            highlight.FillColor, highlight.FillTransparency = style.fill, style.fillT
            highlight.OutlineColor, highlight.OutlineTransparency = style.line, style.lineT
            if style.tracer then
                ghost.line = ghost.line or newLine()
                local line = ghost.line
                if line then
                    local a = cam:WorldToViewportPoint(root.Position)
                    local b = cam:WorldToViewportPoint(SP.pos)
                    line.Visible = a.Z > 0 and b.Z > 0
                    line.From = Vector2.new(a.X, a.Y)
                    line.To = Vector2.new(b.X, b.Y)
                    line.Color = style.tracer
                    line.Transparency = 1 - style.tracerT
                    line.Thickness = 1
                end
            elseif ghost.line then
                ghost.line.Visible = false
            end
        end

        -- the engine ---------------------------------------------------------------------
        local function onHeartbeat(dt)
            local _, _, root = localParts()
            if not root or isOn("misc_invis") then
                SP.pos, applied, realCF = nil, nil, nil
                return
            end
            local real = root.CFrame
            local realPos = real.Position
            local goal, speed, style
            for _, name in ipairs(order) do
                local fn = requests[name]
                if fn then
                    local ok, g, s, v = pcall(fn, root, realPos)
                    if ok and g then goal, speed, style = g, s or 100, v break end
                end
            end
            if goal then
                lastSpeed, lastStyle = speed, style
                SP.pos = follow(SP.pos or realPos, goal, speed, dt)
            elseif SP.pos then
                SP.pos = follow(SP.pos, realPos, lastSpeed, dt)
                if (SP.pos - realPos).Magnitude < 0.05 then SP.pos = nil end
            end
            if SP.pos then
                realCF = real
                applied = CFrame.new(SP.pos) * (real - realPos)
                root.CFrame = applied
            else
                applied, realCF = nil, nil
                if next(requests) == nil then SP.stopEngine() end
            end
        end

        local function onRestore()
            if not applied then return end
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            -- something else moved the character in between (a teleport, a respawn): leave that alone
            if root and realCF and (root.Position - applied.Position).Magnitude < 0.5 then
                root.CFrame = realCF
            end
            applied = nil
        end

        local function startEngine()
            if running then return end
            running = true
            engine.add(RunService.Heartbeat:Connect(function(dt)
                local ok, err = pcall(onHeartbeat, dt)
                if not ok and clock() - lastWarn > 5 then
                    lastWarn = clock()
                    warnf("server position:", err)
                end
            end))
            RunService:BindToRenderStep(RESTORE, Enum.RenderPriority.First.Value, function()
                pcall(onRestore)
            end)
            RunService:BindToRenderStep(GHOST, Enum.RenderPriority.Last.Value, function()
                local ok, err = pcall(updateGhost)
                if not ok and clock() - lastWarn > 5 then
                    lastWarn = clock()
                    warnf("server position ghost:", err)
                end
            end)
        end

        function SP.stopEngine()
            if not running then return end
            running = false
            engine.clear()
            pcall(function() RunService:UnbindFromRenderStep(RESTORE) end)
            pcall(function() RunService:UnbindFromRenderStep(GHOST) end)
            destroyGhost()
        end
        -- fn(root, realPosition) returns the position to show the server, the speed to move there
        -- at (studs per second) and a style table for the ghost (or nil for no ghost)
        function SP.enable(name, fn)
            requests[name] = fn
            startEngine()
        end
        -- the server position glides back to yours before the engine stops
        function SP.disable(name)
            requests[name] = nil
        end

        onUnload(function()
            table.clear(requests)
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if applied and realCF and root then pcall(function() root.CFrame = realCF end) end
            applied, realCF, SP.pos = nil, nil, nil
            SP.stopEngine()
            destroyGhost()
            if ghost.line then pcall(function() ghost.line:Remove() end) ghost.line = nil end
        end)

        -- desync -------------------------------------------------------------------------
        local function desyncRequest(_, realPos)
            local goal
            if flag("misc_desync_style", "Offset") == "Void" then
                local destroyAt = workspace.FallenPartsDestroyHeight
                if type(destroyAt) ~= "number" or destroyAt ~= destroyAt then destroyAt = -500 end
                goal = v3(realPos.X, math.min(math.max(destroyAt + 30, -2500), realPos.Y - 10), realPos.Z)
            else
                goal = realPos + v3(0, flag("misc_desync_y", -2.5), 0)
                if flag("misc_desync_under", false) then
                    local floorY = groundBelow(realPos, flag("misc_desync_filter", false))
                    if floorY then goal = v3(goal.X, math.min(goal.Y, floorY - 3), goal.Z) end
                end
            end
            local style
            if flag("misc_desync_visual", false) then
                style = SP.visualStyle("misc_desync_fill", "misc_desync_line", flag("misc_desync_tracer", false) and "misc_desync_tracer_color" or nil)
            end
            return goal, flag("misc_desync_speed", 30), style
        end
        feature("misc_desync", function()
            SP.enable("desync", desyncRequest)
        end, function()
            SP.disable("desync")
        end)
    end

    -- ======================================================================================
    -- Combat: aim assist, silent aim (with wallbang), triggerbot and FOV circles
    -- ======================================================================================
    ;(function()
        local rand = Random.new()

        -- selected values of a multi dropdown (array of names or a name-keyed set)
        local function has(value, key)
            if type(value) ~= "table" then return value == key end
            if value[key] == true then return true end
            for _, selected in pairs(value) do
                if selected == key then return true end
            end
            return false
        end

        local function keyActive(name)
            local picker = Options[name]
            if picker and type(picker.GetState) == "function" then
                local ok, state = pcall(picker.GetState, picker)
                if ok then return state == true end
            end
            return true
        end

        local function aimRef()
            local cam = Camera()
            if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
                return cam.ViewportSize / 2
            end
            return UserInputService:GetMouseLocation()
        end

        -- gun functions (found through the game's own input connection, as Vape does) ------
        local Gun = { shoot = nil, cast = nil }

        local function functionName(fn)
            local ok, name = pcall(debug.info, fn, "n")
            return ok and name or nil
        end

        local function findByConnections()
            if type(getconnections) ~= "function" or type(debug) ~= "table" or type(debug.getupvalue) ~= "function" then
                return false
            end
            local home = LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("Home")
            local area = home and home:FindFirstChild("hud") and home.hud:FindFirstChild("ActionArea")
            if not area then return false end
            local ok, list = pcall(getconnections, area.InputBegan)
            if not ok or type(list) ~= "table" then return false end
            for _, connection in ipairs(list) do
                local fn = connection.Function
                if fn then
                    local okShoot, shoot = pcall(debug.getupvalue, fn, 2)
                    if okShoot and type(shoot) == "function" then
                        local cast
                        for index = 1, 40 do
                            local okUp, up = pcall(debug.getupvalue, shoot, index)
                            if not okUp then break end
                            if type(up) == "function" and functionName(up) == "castRay" then cast = up break end
                        end
                        if not cast then
                            local okUp, up = pcall(debug.getupvalue, shoot, 16)
                            if okUp and type(up) == "function" then cast = up end
                        end
                        if cast then
                            Gun.shoot, Gun.cast = shoot, cast
                            return true
                        end
                    end
                end
            end
            return false
        end

        local function sourceOf(fn)
            local ok, info = pcall(function() return debug.getinfo(fn) end)
            if ok and type(info) == "table" and info.source then return tostring(info.source) end
            local ok2, src = pcall(debug.info, fn, "s")
            return ok2 and tostring(src) or ""
        end

        -- SillyScripts finds castRay by name and source in the garbage collector
        local function findCastByGc()
            local function accept(fn)
                if type(fn) ~= "function" then return false end
                if type(isexecutorclosure) == "function" and isexecutorclosure(fn) then return false end
                return functionName(fn) == "castRay" and sourceOf(fn):find("GunController", 1, true) ~= nil
            end
            if type(filtergc) == "function" then
                local ok, list = pcall(filtergc, "function", { Name = "castRay" })
                if ok and type(list) == "table" then
                    for _, fn in ipairs(list) do
                        if accept(fn) then return fn end
                    end
                end
            end
            if type(getgc) == "function" then
                local ok, list = pcall(getgc)
                if ok and type(list) == "table" then
                    for _, fn in ipairs(list) do
                        if accept(fn) then return fn end
                    end
                end
            end
        end

        function Gun.find()
            if findByConnections() then return true end
            local cast = findCastByGc()
            if cast then
                Gun.cast = cast
                return true
            end
            return false
        end

        function Gun.data()
            if not Gun.shoot then return nil end
            local ok, data = pcall(debug.getupvalue, Gun.shoot, 10)
            return ok and type(data) == "table" and data or nil
        end

        local function readyGun()
            local tool = equippedGun()
            if not tool then return false end
            if tool:GetAttribute("Local_IsShooting") then return false end
            if (tool:GetAttribute("Local_ReloadSession") or 0) > 0 then return false end
            return (tool:GetAttribute("Local_CurrentAmmo") or 0) > 0
        end

        local function fireGun()
            if Gun.shoot then
                local obj = { UserInputState = Enum.UserInputState.Begin, UserInputType = Enum.UserInputType.MouseButton1, Position = Vector3.zero }
                task.spawn(Gun.shoot, obj)
                obj.UserInputState = Enum.UserInputState.End
                return
            end
            pcall(function()
                local vim = game:GetService("VirtualInputManager")
                local m = UserInputService:GetMouseLocation()
                vim:SendMouseButtonEvent(m.X, m.Y, 0, true, game, 0)
                task.delay(0.03, function() vim:SendMouseButtonEvent(m.X, m.Y, 0, false, game, 0) end)
            end)
        end

        -- target selection ---------------------------------------------------------------
        local sight = RaycastParams.new()
        sight.FilterType = Enum.RaycastFilterType.Exclude
        sight.RespectCanCollide = true

        local function visibleFrom(from, part, char)
            local list = { Camera() }
            if LocalPlayer.Character then list[#list + 1] = LocalPlayer.Character end
            list[#list + 1] = char
            sight.FilterDescendantsInstances = list
            return workspace:Raycast(from, part.Position - from, sight) == nil
        end

        local function pointFlags(prefix)
            local picker = Options[prefix .. "_points"]
            local value = picker and picker.Value
            local head, body = has(value, "Head"), has(value, "Body")
            if not head and not body then head = true end
            return head, body
        end

        -- returns entity, part, screenDistance
        local function selectTarget(prefix, ref, from, opts)
            opts = opts or {}
            local cam = Camera()
            if not cam then return end
            local baseFov = flag(prefix .. "_fov", 120)
            local dynamic = flag(prefix .. "_dynamic", false)
            local amount = flag(prefix .. "_dynamic_amount", 50) / 100
            local maxDist = math.min(flag(prefix .. "_max_dist", 1000), opts.limit or math.huge)
            local priority = flag(prefix .. "_priority", "Closest")
            local wantHead, wantBody = pointFlags(prefix)
            local team = flag(prefix .. "_team", false)
            local ignoreDown = opts.ignoreDown or flag(prefix .. "_ignore_down", false)
            local wall = flag(prefix .. "_wall", false) and not opts.skipWall
            local ffCheck = flag(prefix .. "_ff", false)
            local hostileCheck = flag(prefix .. "_hostile", false)

            local bestEntity, bestPart, bestScore, bestDist
            for _, e in ipairs(otherEntities()) do
                if (not opts.only or e.Player == opts.only) then
                    local distance = (e.Root.Position - from).Magnitude
                    local skip = distance > maxDist
                    if not skip and (Relations[e.Player.UserId] == "Friendly" or (team and relationOf(e.Player) == "Friendly")) then skip = true end
                    if not skip and ffCheck and e.Character:FindFirstChildOfClass("ForceField") then skip = true end
                    if not skip and hostileCheck and isPeaceful(e.Player) then skip = true end
                    if not skip and ignoreDown and (e.Character:GetAttribute("Tased") or e.Character:GetAttribute("Arrested")) then skip = true end
                    if not skip then
                        local radius = baseFov
                        if dynamic then
                            local scale = math.clamp(80 / math.max(distance, 5), 0.35, 2.5)
                            radius = baseFov * (1 + (scale - 1) * amount)
                        end
                        local headPart = e.Character:FindFirstChild("Head")
                        local bodyPart = e.Character:FindFirstChild("UpperTorso") or e.Character:FindFirstChild("Torso") or e.Root
                        local parts = {}
                        if wantHead and headPart then parts[#parts + 1] = headPart end
                        if wantBody and bodyPart then parts[#parts + 1] = bodyPart end
                        for _, part in ipairs(parts) do
                            local screen, onScreen = cam:WorldToViewportPoint(part.Position)
                            if onScreen then
                                local d = (Vector2.new(screen.X, screen.Y) - ref).Magnitude
                                if (opts.ignoreFov or d <= radius) and (not wall or visibleFrom(from, part, e.Character)) then
                                    local score = d
                                    if priority == "Head" and part ~= headPart then score += 1000 end
                                    if priority == "Body" and part == headPart then score += 1000 end
                                    if Relations[e.Player.UserId] == "Priority" then score -= 100000 end
                                    if not bestScore or score < bestScore then
                                        bestEntity, bestPart, bestScore, bestDist = e, part, score, d
                                    end
                                end
                            end
                        end
                    end
                end
            end
            return bestEntity, bestPart, bestDist
        end

        -- FOV circles (Drawing, with an Instance fallback when Drawing is unavailable) ------
        local function newCircle()
            local circle, drawing, gui, frame, stroke = {}, nil, nil, nil, nil
            if Drawing and type(Drawing.new) == "function" then
                local ok, obj = pcall(Drawing.new, "Circle")
                if ok and obj then
                    drawing = obj
                    table.insert(getgenv().TS_Drawings, obj)
                end
            end
            if not drawing then
                pcall(function()
                    gui = Instance.new("ScreenGui")
                    gui.Name = "TS_FovCircle"
                    gui.IgnoreGuiInset = true
                    gui.ResetOnSpawn = false
                    gui.DisplayOrder = 50
                    gui.Parent = (type(gethui) == "function" and gethui()) or game:GetService("CoreGui")
                    frame = Instance.new("Frame")
                    frame.AnchorPoint = Vector2.new(0.5, 0.5)
                    frame.BackgroundTransparency = 1
                    frame.BorderSizePixel = 0
                    frame.Visible = false
                    frame.Parent = gui
                    local corner = Instance.new("UICorner")
                    corner.CornerRadius = UDim.new(1, 0)
                    corner.Parent = frame
                    stroke = Instance.new("UIStroke")
                    stroke.Parent = frame
                end)
            end

            function circle.update(visible, position, radius, color, opacity, thickness, filled)
                if drawing then
                    drawing.Visible = visible
                    if visible then
                        drawing.Position = position
                        drawing.Radius = radius
                        drawing.Color = color
                        drawing.Transparency = opacity
                        drawing.Thickness = thickness
                        drawing.Filled = filled
                        drawing.NumSides = 64
                    end
                elseif frame then
                    frame.Visible = visible
                    if visible then
                        frame.Position = UDim2.fromOffset(position.X, position.Y)
                        frame.Size = UDim2.fromOffset(radius * 2, radius * 2)
                        frame.BackgroundColor3 = color
                        frame.BackgroundTransparency = filled and (1 - opacity * 0.35) or 1
                        stroke.Color = color
                        stroke.Thickness = thickness
                        stroke.Transparency = 1 - opacity
                    end
                end
            end
            function circle.destroy()
                if drawing then pcall(function() drawing.Visible = false drawing:Remove() end) drawing = nil end
                if gui then pcall(function() gui:Destroy() end) gui = nil end
            end
            return circle
        end

        local circles = { aim = newCircle(), silent = newCircle() }
        local circleFeature = { aim = "Aim_Global_Enabled", silent = "Silent_Global_Enabled" }
        track(RunService.RenderStepped:Connect(function()
            local cam = Camera()
            if not cam then return end
            local ref = aimRef()
            for prefix, circle in pairs(circles) do
                local visible = flag(circleFeature[prefix], false) and flag(prefix .. "_fov_show", false)
                if visible then
                    local picker = Options[prefix .. "_fov_color"]
                    local color = picker and typeof(picker.Value) == "Color3" and picker.Value or Color3.new(1, 1, 1)
                    local opacity = 1 - (picker and tonumber(picker.Transparency) or 0)
                    circle.update(true, ref, flag(prefix .. "_fov", 120), color, opacity, flag(prefix .. "_fov_thick", 1), flag(prefix .. "_fov_filled", false))
                else
                    circle.update(false)
                end
            end
        end))
        onUnload(function()
            for _, circle in pairs(circles) do circle.destroy() end
        end)

        -- aim assist ---------------------------------------------------------------------
        do
            local name = "TS_AimAssist"
            local lockedPlayer, acquiredAt, lastPlayer = nil, 0, nil
            local accX, accY, warned = 0, 0, false

            local function valid(player)
                local char = player and player.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                return hum ~= nil and hum.Health > 0 and char:FindFirstChild("HumanoidRootPart") ~= nil
            end

            local function step(dt)
                local cam = Camera()
                local _, _, root = localParts()
                if not cam or not root or typing() or not keyActive("Aim_Global_Key") then
                    lockedPlayer, lastPlayer = nil, nil
                    accX, accY = 0, 0
                    return
                end
                local ref = aimRef()
                local opts
                if flag("aim_lock", false) and lockedPlayer and valid(lockedPlayer) then
                    opts = { only = lockedPlayer, ignoreFov = true }
                end
                local eye = root.Parent and root.Parent:FindFirstChild("Head")
                local entity, part = selectTarget("aim", ref, eye and eye.Position or root.Position, opts)
                if not entity then
                    lockedPlayer, lastPlayer = nil, nil
                    return
                end
                if lastPlayer ~= entity.Player then
                    lastPlayer = entity.Player
                    acquiredAt = clock()
                end
                if flag("aim_lock", false) then lockedPlayer = entity.Player end
                local held = clock() - acquiredAt
                if held < flag("aim_reaction", 0) / 1000 then return end

                local alpha = 1
                if flag("aim_smooth", true) then
                    local first, last, inc = flag("aim_smooth_start", 85), flag("aim_smooth_end", 20), flag("aim_smooth_inc", 50)
                    local smoothing = first > last and math.max(last, first - inc * held) or math.min(last, first + inc * held)
                    smoothing += (rand:NextNumber() * 2 - 1) * flag("aim_smooth_rand", 5)
                    smoothing = math.clamp(smoothing, 0, 99)
                    alpha = 1 - (smoothing / 100) ^ (math.min(dt, 0.1) * 60)
                end

                local goal = part.Position
                local method = flag("aim_method", "Camera")
                if method == "Mouse" and type(mousemoverel) ~= "function" then
                    if not warned then
                        warned = true
                        say("mousemoverel is not available, using the camera instead")
                    end
                    method = "Camera"
                end
                if method == "Mouse" then
                    local screen = cam:WorldToViewportPoint(goal)
                    accX += (screen.X - ref.X) * alpha
                    accY += (screen.Y - ref.Y) * alpha
                    local ix = accX >= 0 and math.floor(accX) or math.ceil(accX)
                    local iy = accY >= 0 and math.floor(accY) or math.ceil(accY)
                    accX -= ix
                    accY -= iy
                    if ix ~= 0 or iy ~= 0 then pcall(mousemoverel, ix, iy) end
                else
                    cam.CFrame = cam.CFrame:Lerp(CFrame.lookAt(cam.CFrame.Position, goal), alpha)
                end
            end

            feature("Aim_Global_Enabled", function()
                lockedPlayer, lastPlayer, accX, accY = nil, nil, 0, 0
                RunService:BindToRenderStep(name, Enum.RenderPriority.Camera.Value + 1, function(dt)
                    local ok, err = pcall(step, dt)
                    if not ok then warnf("aim assist error:", err) end
                end)
            end, function()
                pcall(function() RunService:UnbindFromRenderStep(name) end)
                lockedPlayer, lastPlayer = nil, nil
            end)
        end

        -- wallbang: looks for a shot origin and a hit point that have a clear line to the target ----
        local WB = { cache = {}, ray = RaycastParams.new(), overlap = OverlapParams.new(), history = {}, moved = 0 }
        WB.ray.FilterType = Enum.RaycastFilterType.Exclude
        WB.overlap.FilterType = Enum.RaycastFilterType.Exclude
        pcall(function()
            WB.ray.CollisionGroup = "ClientBullet"
            WB.overlap.CollisionGroup = "ClientBullet"
        end)
        local OFFSETS_NEAR = {
            v3(0, 1, 0), v3(1, 0, 0), v3(0.7, -0.5, -0.5), v3(-0.1, -0.8, -0.8), v3(-0.8, -0.5, -0.5), v3(-1, 0, 0),
            v3(-0.8, 0.4, 0.4), v3(0, 0.7, 0.7), v3(0.7, 0.5, 0.5), v3(1, 0, 0), v3(0.7, 0, -0.8), v3(-0.1, 0, -1),
            v3(-0.8, 0, -0.8), v3(-1, 0, 0), v3(-0.8, 0, 0.7), v3(0, 0, 1), v3(0.7, 0, 0.7), v3(1, 0, 0),
            v3(0.7, 0.4, -0.5), v3(-0.1, 0.7, -0.8), v3(-0.8, 0.4, -0.5), v3(-1, -0.1, 0), v3(-0.8, -0.5, 0.4),
            v3(0, -0.8, 0.7), v3(0.7, -0.6, 0.5), v3(0, -1, 0),
        }
        local OFFSETS_HIGH = {
            v3(0, 3, 0), v3(0, 5, 0), v3(0, 7, 0), v3(0, 10, 0),
            v3(1, 3, 0), v3(-1, 3, 0), v3(0, 3, 1), v3(0, 3, -1),
            v3(1, 5, 0), v3(-1, 5, 0), v3(0, 5, 1), v3(0, 5, -1),
            v3(1, 7, 0), v3(-1, 7, 0), v3(0, 7, 1), v3(0, 7, -1),
            v3(1, 10, 0), v3(-1, 10, 0), v3(0, 10, 1), v3(0, 10, -1),
            v3(0.7, 3, 0.7), v3(-0.7, 3, 0.7), v3(0.7, 3, -0.7), v3(-0.7, 3, -0.7),
            v3(0.7, 5, 0.7), v3(-0.7, 5, 0.7), v3(0.7, 5, -0.7), v3(-0.7, 5, -0.7),
            v3(0.7, 7, 0.7), v3(-0.7, 7, 0.7), v3(0.7, 7, -0.7), v3(-0.7, 7, -0.7),
            v3(0.7, 10, 0.7), v3(-0.7, 10, 0.7), v3(0.7, 10, -0.7), v3(-0.7, 10, -0.7),
            v3(0, 15, 0), v3(1, 15, 0), v3(-1, 15, 0), v3(0, 15, 1), v3(0, 15, -1),
        }

        function WB.updateIgnore()
            local list = {}
            if LocalPlayer.Character then list[#list + 1] = LocalPlayer.Character end
            for _, player in ipairs(Players:GetPlayers()) do
                if player.Character then list[#list + 1] = player.Character end
            end
            local cars = workspace:FindFirstChild("CarContainer")
            if cars and flag("gun_vehicle_wallbang", false) then list[#list + 1] = cars end
            WB.ray.FilterDescendantsInstances = list
            WB.overlap.FilterDescendantsInstances = list
        end

        local function freeSpace(position)
            for _, part in ipairs(workspace:GetPartBoundsInRadius(position, 0, WB.overlap)) do
                if part.CanCollide and (part:GetClosestPointOnSurface(position) - position).Magnitude <= 0.0001 then
                    return false
                end
            end
            return true
        end

        local FLAT = Vector3.new(1, 0, 1)

        local function radius()
            return math.clamp(flag("wb_radius", 6), 1, 10)
        end

        -- direction from the shooter to the target on the ground plane
        local function lookFlat(shooterPos, targetPos)
            local flatDelta = (shooterPos - targetPos) * FLAT
            if flatDelta.Magnitude > 0.001 then
                return CFrame.lookAt(shooterPos * FLAT, targetPos * FLAT).LookVector
            end
            return v3(0, 0, -1)
        end

        -- spots beside the target's body on the side that faces the shooter (the server accepts hits a few studs off the body)
        local function pointsAround(center, look, scales)
            local list = {}
            for _, normalId in ipairs(Enum.NormalId:GetEnumItems()) do
                local normal = Vector3.fromNormalId(normalId)
                if (normal * FLAT):Dot(-look) > -0.5 then
                    for _, scale in ipairs(scales) do
                        local position = center + normal * scale
                        if freeSpace(position) then list[#list + 1] = position end
                    end
                end
            end
            return list
        end

        -- spots around the shooter that are not behind the shooter
        local function originsAround(center, look, scales, sets)
            local list = {}
            for _, scale in ipairs(scales) do
                for _, set in ipairs(sets) do
                    for _, offset in ipairs(set) do
                        if (offset * FLAT):Dot(look) > -0.5 then list[#list + 1] = center + offset * scale end
                    end
                end
            end
            return list
        end

        local function byDistance(list, from)
            local ranked = {}
            for index, position in ipairs(list) do ranked[index] = { position, (position - from).Magnitude, index } end
            table.sort(ranked, function(a, b)
                if a[2] ~= b[2] then return a[2] < b[2] end
                return a[3] < b[3]
            end)
            for index, entry in ipairs(ranked) do list[index] = entry[1] end
            return list
        end

        -- first (target, origin) pair that has a clear line between them
        local function firstClear(targets, origins)
            for _, target in ipairs(targets) do
                for _, origin in ipairs(origins) do
                    if not workspace:Raycast(target, origin - target, WB.ray) and freeSpace(origin) then
                        return origin, target
                    end
                end
            end
            return nil
        end

        local function append(into, list)
            for _, item in ipairs(list) do into[#into + 1] = item end
        end

        -- The methods. Each one gets the shooter position, the target part position, the point on the
        -- wall that blocks the line (or nil), the centre of the target's body and the "use hitbox" setting,
        -- and returns an origin and a target when it found a line.
        local METHODS = {}

        -- Vape V4: the wall point if it is close, else origins one radius around you and points 7.4 studs
        -- around the target's root
        METHODS["Vape V4"] = function(shooter, target, surface, center, hitbox)
            local reach = radius() - math.min(WB.moved, 1)
            local look = lookFlat(shooter, target)
            local targets = {}
            if freeSpace(target) then
                if surface and (shooter - surface).Magnitude < 7.5 then return surface, target end
                targets[1] = target
            end
            if hitbox then append(targets, pointsAround(center, look, { 7.4 })) end
            local origins = { shooter }
            for _, position in ipairs(originsAround(shooter, look, { reach }, { OFFSETS_NEAR })) do
                if freeSpace(position) then origins[#origins + 1] = position end
            end
            return firstClear(targets, origins)
        end

        -- awp: more origins (also straight up), the closest ones first
        METHODS["awp"] = function(shooter, target, surface, center, hitbox)
            local reach = radius() - math.min(WB.moved, 1)
            local look = lookFlat(shooter, target)
            local origins = originsAround(shooter, look, { reach }, { OFFSETS_NEAR, OFFSETS_HIGH })
            origins[#origins + 1] = shooter
            byDistance(origins, shooter)
            if surface and (surface - shooter).Magnitude <= reach + 1.5 then table.insert(origins, 1, surface) end
            local targets = { target }
            if hitbox then append(targets, pointsAround(center, look, { radius() })) end
            return firstClear(targets, origins)
        end

        -- awp v2: origins and hit points up to twice the radius away (goes through more walls, less accurate)
        METHODS["awp v2"] = function(shooter, target, surface, center, hitbox)
            local reach = radius()
            local look = lookFlat(shooter, target)
            local origins = originsAround(shooter, look, { reach, reach * 2 }, { OFFSETS_NEAR, OFFSETS_HIGH })
            if surface then table.insert(origins, 1, surface) end
            local targets = { target }
            if hitbox then append(targets, pointsAround(center, look, { reach, reach * 2 })) end
            return firstClear(targets, origins)
        end

        -- awp v2.1: works the origins out from the line to the target. The free spot in front of every wall
        -- on that line, spots on the line itself and a few beside it are ranked by how far they are from
        -- you; everything within the radius is tried first, then up to twice the radius.
        METHODS["awp v2.1"] = function(shooter, target, surface, center, hitbox)
            local reach = radius()
            local look = lookFlat(shooter, target)
            local targets = { target }
            if hitbox then append(targets, pointsAround(center, look, { reach })) end

            local near, far = {}, {}
            local function add(position)
                if #near + #far >= 100 then return end
                local distance = (position - shooter).Magnitude
                if distance <= reach then near[#near + 1] = position
                elseif distance <= reach * 2 then far[#far + 1] = position end
            end

            add(shooter)
            if surface then add(surface) end

            local walk = RaycastParams.new()
            walk.FilterType = Enum.RaycastFilterType.Exclude
            pcall(function() walk.CollisionGroup = "ClientBullet" end)
            local skip = table.clone(WB.ray.FilterDescendantsInstances)
            walk.FilterDescendantsInstances = skip
            local back = shooter - target
            local side = back.Magnitude > 0.001 and back.Unit:Cross(v3(0, 1, 0)) or v3(1, 0, 0)
            side = side.Magnitude > 0.01 and side.Unit or v3(1, 0, 0)
            for _ = 1, 6 do
                local hit = workspace:Raycast(target, back, walk)
                if not hit then break end
                local front = hit.Position + hit.Normal * 0.05
                add(front)
                for _, shift in ipairs({ -3, -1.5, 1.5, 3 }) do add(front + side * shift) end
                skip[#skip + 1] = hit.Instance
                walk.FilterDescendantsInstances = skip
            end

            local toTarget = target - shooter
            local lineLength = toTarget.Magnitude
            if lineLength > 0.001 then
                local unit = toTarget / lineLength
                for step = 1, math.floor(math.min(reach * 2, lineLength)) do add(shooter + unit * step) end
            end
            for _, position in ipairs(originsAround(shooter, look, { reach * 0.5, reach }, { OFFSETS_NEAR })) do add(position) end

            byDistance(near, shooter)
            byDistance(far, shooter)
            append(near, far)
            return firstClear(targets, near)
        end

        -- other body parts to try when the aimed part cannot be reached
        local ALT_PARTS = { "Head", "UpperTorso", "Torso", "LowerTorso", "HumanoidRootPart", "LeftUpperArm", "RightUpperArm",
            "Left Arm", "Right Arm", "LeftUpperLeg", "RightUpperLeg", "Left Leg", "Right Leg" }
        local function altParts(char, except)
            local list = {}
            for _, name in ipairs(ALT_PARTS) do
                local candidate = char:FindFirstChild(name)
                if candidate and candidate ~= except and candidate:IsA("BasePart") then list[#list + 1] = candidate end
            end
            return list
        end

        -- "clear" when the shot already has a line, "moved", newOrigin, newTarget when a path was found, nil when none
        local function wallbangPlan(origin, part, root)
            local position = part.Position
            local cached = WB.cache[part]
            if cached == false then return nil end
            if cached then return "moved", cached[1], cached[2] end

            local blocked = workspace:Raycast(position, origin - position, WB.ray)
            if not blocked and not workspace:Raycast(origin, position - origin, WB.ray) then return "clear" end

            -- the shooter is where the server sees you (the assist or a desync may have moved it)
            local shooter = Actions.sp.shooter(root)
            local anchor = part.Parent and part.Parent:FindFirstChild("HumanoidRootPart")
            local center = anchor and anchor.Position or position
            local method = flag("wb_method", "awp v2")
            local scan = METHODS[method] or METHODS["awp v2"]

            local newOrigin, newTarget = scan(shooter, position, blocked and (blocked.Position + blocked.Normal * 0.01) or nil, center, flag("wb_hitbox", true))

            -- the two long reach methods keep looking: ground points along the line, then a column above you
            if not newOrigin and (method == "awp v2" or method == "awp v2.1") then
                local delta = position - shooter
                local dist = delta.Magnitude
                if dist > 0.5 then
                    local unit = delta.Unit
                    for i = 2, math.min(dist, 160), 2 do
                        local ground = workspace:Raycast(shooter + unit * i, v3(0, -50, 0), WB.ray)
                        if ground then
                            local at = ground.Position + ground.Normal * 0.5
                            if not workspace:Raycast(at, position - at, WB.ray) and freeSpace(at) then
                                newOrigin, newTarget = at, position
                                break
                            end
                        end
                    end
                end
                if not newOrigin then
                    for i = 3, 18, 3 do
                        local at = shooter + v3(0, i, 0)
                        if not workspace:Raycast(at, position - at, WB.ray) and freeSpace(at) then
                            newOrigin, newTarget = at, position
                            break
                        end
                    end
                end
            end

            if newOrigin then
                WB.cache[part] = { newOrigin, newTarget }
                return "moved", newOrigin, newTarget
            end
            WB.cache[part] = false
            return nil
        end

        -- castRay hook: shared by silent aim, hit effects and auto taze ----------------------
        do
            local bag = newBag()
            local hookedCast, original = nil, nil
            local wants = { silent = false, fx = false, auto = false }
            local autoNext, loopToken, warnedStack = 0, 0, false
            local lastOrigin, lastNew

            local function silentActive()
                return flag("Silent_Global_Enabled", false) and keyActive("Silent_Global_Key")
            end

            local function anyWanted()
                return wants.silent or wants.fx or wants.auto
            end

            local function redirect(...)
                local origin = ...

                -- a shot the script asked for (auto taze): report the chosen part directly
                local force = Gun.force
                if force then
                    Gun.force = nil
                    if clock() < force.expires and force.part.Parent then return force.part, force.pos end
                end

                if typeof(origin) ~= "Vector3" or not wants.silent or not silentActive() then return original(...) end
                if rand:NextNumber(0, 100) > flag("Silent_Global_HitChance", 100) then return original(...) end

                local data = Gun.data()
                local taser = data and data.Behavior == "Taser"
                local wallbang = flag("silent_wallbang", false)
                local entity, part = selectTarget("silent", aimRef(), origin, {
                    limit = data and tonumber(data.Range) or 1000,
                    ignoreDown = taser,
                    skipWall = wallbang,
                })
                if not entity then return original(...) end

                local args = table.pack(...)
                local _, _, myRoot = localParts()
                local usePart, newOrigin, hit = part, nil, nil
                if wallbang and myRoot then
                    WB.updateIgnore()
                    local status, moved, moveHit = wallbangPlan(origin, part, myRoot)
                    if not status then
                        for _, alt in ipairs(altParts(entity.Character, part)) do
                            status, moved, moveHit = wallbangPlan(origin, alt, myRoot)
                            if status then usePart = alt break end
                        end
                    end
                    if status == "moved" then
                        newOrigin, hit = moved, moveHit
                    elseif not status and flag("silent_wall", false) then
                        return original(...)
                    end
                end
                if newOrigin then
                    lastOrigin, lastNew = origin, newOrigin
                    return usePart, hit or usePart.Position
                end
                args[2] = usePart.Position
                return original(table.unpack(args, 1, args.n))
            end

            local hookFn
            hookFn = function(...)
                lastOrigin, lastNew = nil, nil
                local packed = table.pack(pcall(redirect, ...))
                local results
                if packed[1] then
                    results = table.pack(table.unpack(packed, 2, packed.n))
                else
                    results = table.pack(original(...))
                end

                -- the gun controller sends its own copy of the origin to the server, so the register that
                -- holds it is rewritten (found by the function it belongs to, like SillyScripts does)
                local fromPos, toPos = lastOrigin, lastNew
                if fromPos and toPos and type(debug) == "table" and type(debug.getstack) == "function" and type(debug.setstack) == "function" then
                    local replaced = 0
                    local function sweep(strict)
                        pcall(function()
                            local scanner = debug.info(1, "f")
                            for level = 2, 14 do
                                local fn = debug.info(level, "f")
                                local isTarget
                                if strict then
                                    isTarget = Gun.shoot ~= nil and fn == Gun.shoot
                                else
                                    isTarget = level >= 3 and type(fn) == "function" and fn ~= hookFn and fn ~= scanner
                                end
                                if isTarget then
                                    for index, value in debug.getstack(level) do
                                        if value == fromPos then
                                            debug.setstack(level, index, toPos)
                                            replaced += 1
                                        end
                                    end
                                end
                            end
                        end)
                    end
                    sweep(true)
                    if replaced == 0 then sweep(false) end
                    if replaced == 0 and not warnedStack then
                        warnedStack = true
                        warnf("wallbang: the shot origin could not be rewritten (needs debug.getstack and debug.setstack)")
                    end
                end

                local listeners = ShotEvents.cast
                for i = 1, #listeners do pcall(listeners[i], results[1], results[2]) end
                return table.unpack(results, 1, results.n)
            end

            local function unhook()
                if hookedCast and original then
                    pcall(function()
                        if type(restorefunction) == "function" then restorefunction(hookedCast)
                        else hookfunction(hookedCast, original) end
                    end)
                end
                hookedCast, original = nil, nil
            end

            local function install()
                if not Gun.find() then return false end
                if hookedCast == Gun.cast then return true end
                unhook()
                if type(hookfunction) ~= "function" then return false end
                local ok, old = pcall(hookfunction, Gun.cast, hookFn)
                if not ok or type(old) ~= "function" then return false end
                hookedCast, original = Gun.cast, old
                return true
            end

            -- keeps the hook in place while anything wants it, and puts the original back when nothing does
            local function refresh()
                loopToken += 1
                local mine = loopToken
                if not anyWanted() then
                    unhook()
                    return
                end
                task.spawn(function()
                    local tries = 0
                    while mine == loopToken and anyWanted() do
                        if install() then
                            tries = 0
                        else
                            tries += 1
                            if tries > 20 then
                                say("The gun could not be hooked (needs getconnections or filtergc, debug.getupvalue and hookfunction)")
                                if wants.silent then switchOff("Silent_Global_Enabled") end
                                return
                            end
                        end
                        task.wait(hookedCast and 2 or 1)
                    end
                end)
            end

            ShotEvents.hooked = function() return hookedCast ~= nil end
            Actions.fxHook = function(on)
                wants.fx = on and true or false
                refresh()
            end
            Actions.autoHook = function(on)
                wants.auto = on and true or false
                refresh()
            end
            -- fire the equipped gun through the game's own code, with castRay reporting `part`
            Actions.fireAt = function(part, position)
                if not part or not part.Parent then return false end
                if not hookedCast then
                    if not Gun.find() or not install() then return false end
                end
                Gun.force = { part = part, pos = position or part.Position, expires = clock() + 0.6 }
                fireGun()
                return true
            end

            feature("Silent_Global_Enabled", function()
                wants.silent = true
                refresh()
                local lastClear = 0
                bag.add(RunService.Heartbeat:Connect(function()
                    local now = clock()
                    if now - lastClear > 0.15 then
                        lastClear = now
                        table.clear(WB.cache)
                        WB.updateIgnore()
                    end
                    local _, _, mover = localParts()
                    if mover then
                        local history = WB.history
                        history[#history + 1] = { Actions.sp.realPos(mover), now }
                        while #history > 1 and now - history[1][2] > 0.1 do table.remove(history, 1) end
                        WB.moved = (history[#history][1] - history[1][1]).Magnitude
                    end
                    if flag("silent_autofire", false) and silentActive() and now >= autoNext and not typing() then
                        autoNext = now + 1 / math.max(flag("silent_autofire_rate", 15), 1)
                        local _, _, root = localParts()
                        local cam = Camera()
                        local head = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Head")
                        if root and cam and head and readyGun() then
                            local data = Gun.data()
                            local entity = selectTarget("silent", aimRef(), head.Position, {
                                limit = data and tonumber(data.Range) or 1000,
                                ignoreDown = data and data.Behavior == "Taser",
                                skipWall = flag("silent_wallbang", false),
                            })
                            if entity then fireGun() end
                        end
                    end
                end))
            end, function()
                bag.clear()
                wants.silent = false
                refresh()
            end)

            onUnload(function()
                wants.silent, wants.fx, wants.auto = false, false, false
                loopToken += 1
                unhook()
                ShotEvents.hooked = nil
                Actions.fxHook, Actions.autoHook = noop, noop
                Actions.fireAt = function() return false end
            end)
        end

        -- triggerbot ---------------------------------------------------------------------
        do
            local bag = newBag()
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            pcall(function() params.CollisionGroup = "ClientBullet" end)
            local seenSince, nextShot = nil, 0
            local TORSO = { Torso = true, UpperTorso = true, LowerTorso = true, HumanoidRootPart = true }

            feature("Trigger_Global_Enabled", function()
                seenSince, nextShot = nil, 0
                task.spawn(Gun.find)
                bag.add(RunService.Heartbeat:Connect(function()
                    local cam = Camera()
                    local _, _, root = localParts()
                    if not cam or not root or typing() or not keyActive("Trigger_Global_Key") or not readyGun() then
                        seenSince = nil
                        return
                    end
                    local ref = aimRef()
                    local ray = cam:ViewportPointToRay(ref.X, ref.Y)
                    local list = { cam }
                    if LocalPlayer.Character then list[#list + 1] = LocalPlayer.Character end
                    params.FilterDescendantsInstances = list
                    local result = workspace:Raycast(ray.Origin, ray.Direction * 1500, params)
                    local model = result and result.Instance:FindFirstAncestorOfClass("Model")
                    local player = model and Players:GetPlayerFromCharacter(model)
                    local hum = model and model:FindFirstChildOfClass("Humanoid")
                    local good = player ~= nil and player ~= LocalPlayer and hum ~= nil and hum.Health > 0
                    if good and (Relations[player.UserId] == "Friendly" or (flag("trigger_team", false) and relationOf(player) == "Friendly")) then good = false end
                    if good and flag("trigger_ff", false) and model:FindFirstChildOfClass("ForceField") then good = false end
                    if good and flag("trigger_hostile", false) and isPeaceful(player) then good = false end
                    if good then
                        local mode = flag("Trigger_Global_HitPart", "Head")
                        if mode == "Head" then good = result.Instance.Name == "Head"
                        elseif mode == "Torso" then good = TORSO[result.Instance.Name] == true end
                    end
                    if good then
                        local data = Gun.data()
                        local head = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Head")
                        local range = data and tonumber(data.Range) or 1000
                        if head and (result.Position - head.Position).Magnitude > range then good = false end
                    end
                    if not good then seenSince = nil return end
                    local now = clock()
                    seenSince = seenSince or now
                    if now - seenSince >= flag("Trigger_Global_Reaction", 0) / 1000 and now >= nextShot then
                        nextShot = now + flag("Trigger_Global_Delay", 40) / 1000
                        fireGun()
                    end
                end))
            end, function()
                bag.clear()
                seenSince = nil
            end)
        end

        -- wallbang assist: moves the position the server sees up to (or into) the wall in front of the target ----
        do
            local bag = newBag()
            local A = Actions.sp.assist
            A.goal, A.speed, A.style = nil, 50, nil
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            pcall(function() params.CollisionGroup = "ClientBullet" end)
            local errors = 0

            local function step()
                A.goal = nil
                if not (flag("silent_wallbang", false) and flag("Silent_Global_Enabled", false) and keyActive("Silent_Global_Key")) then return end
                local char, _, root = localParts()
                if not char or not root or typing() then return end
                local head = char:FindFirstChild("Head")
                local realPos = Actions.sp.realPos(root)
                local data = Gun.data()
                local limit = math.min(flag("wb_assist_max", 200), data and tonumber(data.Range) or 1000)
                local entity, part = selectTarget("silent", aimRef(), head and head.Position or realPos, {
                    limit = limit,
                    ignoreDown = data and data.Behavior == "Taser",
                    skipWall = true,
                })
                if not entity then return end

                WB.updateIgnore()
                params.FilterDescendantsInstances = WB.ray.FilterDescendantsInstances
                local delta = part.Position - realPos
                local distance = delta.Magnitude
                if distance < 2 then return end
                local hit = workspace:Raycast(realPos, delta, params)
                if not hit or hit.Distance > flag("wb_assist_dist", 25) then return end

                local unit = delta / distance
                local point
                if flag("wb_assist_inside", false) then
                    point = hit.Position + unit * 1.5
                else
                    point = hit.Position - unit * 1.2
                end
                A.goal = v3(point.X, realPos.Y + math.clamp(point.Y - realPos.Y, -4, 4), point.Z)
                A.speed = flag("wb_assist_mode", "Tween") == "Teleport" and 1e9 or flag("wb_assist_speed", 50)
                A.style = flag("wb_assist_visual", false) and Actions.sp.visualStyle("wb_assist_fill", "wb_assist_line") or nil
            end

            feature("wb_assist", function()
                Actions.sp.enable("assist", function()
                    if not A.goal then return nil end
                    return A.goal, A.speed, A.style
                end)
                task.spawn(Gun.find)
                bag.add(RunService.RenderStepped:Connect(function()
                    local ok, err = pcall(step)
                    if not ok then
                        errors += 1
                        if errors <= 3 then warnf("wallbang assist error:", err) end
                    end
                end))
            end, function()
                bag.clear()
                A.goal, A.style = nil, nil
                Actions.sp.disable("assist")
            end)
        end
    end)()


    -- ======================================================================================
    -- Disabler: turns off the game's CanCollide listener on your Head so Phase (Character
    -- mode) is not caught. Humanoid spoofer: writes a fake state to the network replication.
    -- ======================================================================================
    do
        local bag, disabled = newBag(), nil
        local function disable(char)
            local head = char:WaitForChild("Head", 5)
            if not head or type(getconnections) ~= "function" then return end
            task.wait(0.5)
            local ok, list = pcall(getconnections, head:GetPropertyChangedSignal("CanCollide"))
            local first = ok and type(list) == "table" and list[1]
            if first then
                pcall(function() first:Disable() end)
                disabled = first
            end
        end
        feature("misc_disabler", function()
            if type(getconnections) ~= "function" then
                say("Disabler needs getconnections")
                switchOff("misc_disabler")
                return
            end
            if LocalPlayer.Character then task.spawn(disable, LocalPlayer.Character) end
            bag.add(LocalPlayer.CharacterAdded:Connect(function(char)
                disabled = nil
                task.spawn(disable, char)
            end))
        end, function()
            bag.clear()
            if disabled then pcall(function() disabled:Enable() end) end
            disabled = nil
        end)
    end

    -- ======================================================================================
    -- Infinite jump and click teleport
    -- ======================================================================================
    do
        local bag = newBag()
        feature("misc_infjump", function()
            bag.add(UserInputService.JumpRequest:Connect(function()
                local _, hum = localParts()
                if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
            end))
        end, function() bag.clear() end)
    end

    do
        local bag = newBag()
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        feature("misc_clicktp", function()
            bag.add(UserInputService.InputBegan:Connect(function(input, processed)
                if processed or typing() or input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
                if flag("misc_clicktp_ctrl", true) and not UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then return end
                local char, hum, root = localParts()
                local cam = Camera()
                if not root or not cam then return end
                local at = UserInputService:GetMouseLocation()
                local ray = cam:ViewportPointToRay(at.X, at.Y)
                params.FilterDescendantsInstances = { char, cam }
                local hit = workspace:Raycast(ray.Origin, ray.Direction * 3000, params)
                if not hit then return end
                if (hit.Position - root.Position).Magnitude > flag("misc_clicktp_range", 500) then
                    say("That point is out of click teleport range")
                    return
                end
                local lift = hum.HipHeight + 3
                root.CFrame = CFrame.new(hit.Position + v3(0, lift, 0)) * root.CFrame.Rotation
                root.AssemblyLinearVelocity = ZERO
            end))
        end, function() bag.clear() end)
    end

    -- ======================================================================================
    -- Shot fallback for hit sounds, notifications and hit effects: when the tracer hook did not
    -- report a shot, the drop in the gun's ammo is used to detect it instead.
    -- ======================================================================================
    ;(function()
        local lastTool, lastAmmo
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        pcall(function() params.CollisionGroup = "ClientBullet" end)

        local function aimPoint()
            local cam = Camera()
            local at = UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter and cam.ViewportSize / 2 or UserInputService:GetMouseLocation()
            local ray = cam:ViewportPointToRay(at.X, at.Y)
            local list = { cam }
            if LocalPlayer.Character then list[#list + 1] = LocalPlayer.Character end
            params.FilterDescendantsInstances = list
            local hit = workspace:Raycast(ray.Origin, ray.Direction * 1500, params)
            return hit and hit.Position or (ray.Origin + ray.Direction * 1500)
        end

        track(RunService.Heartbeat:Connect(function()
            local tool = equippedGun()
            local ammo = tool and tool:GetAttribute("Local_CurrentAmmo")
            if tool ~= lastTool then
                lastTool, lastAmmo = tool, ammo
                return
            end
            if tool and type(ammo) == "number" and type(lastAmmo) == "number" and ammo < lastAmmo then
                local stamp = clock()
                task.delay(0.12, function()
                    if (ShotEvents.last or 0) >= stamp - 0.1 then return end -- the tracer hook already reported it
                    local fire = ShotEvents.fire
                    local cam = Camera()
                    if not fire or not cam then return end
                    local muzzle = tool:FindFirstChild("Muzzle")
                    local head = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Head")
                    local origin = (muzzle and muzzle:IsA("BasePart") and muzzle.Position) or (head and head.Position) or cam.CFrame.Position
                    pcall(fire, origin, aimPoint())
                end)
            end
            lastAmmo = ammo
        end))
    end)()

    -- ======================================================================================
    -- Kick exploit (Vape): throws vehicles you own the physics of at other players. It needs
    -- isnetworkowner and sethiddenproperty. The controls live in the Players tab:
    -- fling the selected player once, loop the selected player, or loop everyone.
    -- ======================================================================================
    do
        local bag = newBag()
        local didClick, lastFling, current = {}, {}, setmetatable({}, { __mode = "k" })
        local direction, scan, lastTeam = 0, 0, 0
        local seats = {}
        local users, onceUntil = 0, 0
        local PRISON_MIN, PRISON_MAX = v3(700, 80, 2190), v3(1010, 150, 2520)

        local function insidePrison(position)
            return position.X > PRISON_MIN.X and position.X < PRISON_MAX.X
                and position.Y > PRISON_MIN.Y and position.Y < PRISON_MAX.Y
                and position.Z > PRISON_MIN.Z and position.Z < PRISON_MAX.Z
        end

        local function pickTarget(seat)
            local held = current[seat]
            if held and held.Root.Parent and clock() - (lastFling[held.Player.UserId] or 0) < 0.75 then return held end
            local list = otherEntities()
            table.sort(list, function(a, b) return (lastFling[a.Player.UserId] or 0) < (lastFling[b.Player.UserId] or 0) end)
            local everyone = flag("misc_kick_all", false)
            local only
            if not everyone then only = Players:FindFirstChild(flag("Player_Selected", "")) end
            for _, e in ipairs(list) do
                local team = e.Player.Team
                local seated = e.Humanoid.SeatPart and e.Humanoid.SeatPart.Anchored
                local skip = not team or team.Name == "Neutral" or seated
                if everyone then
                    if relationOf(e.Player) == "Friendly" then skip = true end
                    if flag("misc_kick_filter", false) and insidePrison(e.Root.Position) then skip = true end
                elseif e.Player ~= only then
                    skip = true
                end
                if not skip then
                    lastFling[e.Player.UserId] = clock()
                    current[seat] = e
                    say("Kick exploit: " .. e.Player.Name)
                    return e
                end
            end
        end

        local function startEngine()
            if type(isnetworkowner) ~= "function" then
                say("Kick exploit needs isnetworkowner")
                return false
            end
            local protect = Toggles.misc_anti_fling
            if protect and not protect.Value and protect.SetValue then protect:SetValue(true) end
            direction, scan = 0, 0
            bag.add(RunService.Heartbeat:Connect(function(dt)
                local now = clock()
                if not LocalPlayer.Team or LocalPlayer.Team.Name == "Neutral" then
                    local gui = LocalPlayer.PlayerGui:FindFirstChild("TeamsFrame", true)
                    if gui and type(firesignal) == "function" and now - lastTeam > 0.1 then
                        local buttons = gui:GetChildren()
                        table.sort(buttons, function(a, b) return (a.Name == "Inmates" and 1 or 2) < (b.Name == "Inmates" and 1 or 2) end)
                        for _, holder in ipairs(buttons) do
                            local button = holder:FindFirstChild("Button")
                            if button and button.AutoButtonColor then
                                lastTeam = now
                                pcall(firesignal, button.MouseButton1Click)
                                break
                            end
                        end
                    end
                    return
                end

                local _, hum, root = localParts()
                if not root then return end

                -- velocity protection: the flung cars must not carry you away with them
                if flag("misc_kick_velprot", true) and not hum.SeatPart and root.AssemblyLinearVelocity.Magnitude > 120 then
                    root.AssemblyLinearVelocity = ZERO
                    root.AssemblyAngularVelocity = ZERO
                end

                if flag("misc_kick_move", true) then
                    local items = workspace:FindFirstChild("Prison_ITEMS")
                    local buttons = items and items:FindFirstChild("buttons")
                    local moved = false
                    if buttons then
                        for _, button in ipairs(buttons:GetChildren()) do
                            local pad = button.Name == "Car Spawner" and button:FindFirstChild("Car Spawner")
                            if pad then
                                local distance = (pad.Position - root.Position).Magnitude
                                if distance < 15 and (didClick[button] or 0) < now then
                                    didClick[button] = now + 0.2
                                    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
                                    local interact = remotes and remotes:FindFirstChild("InteractWithItem")
                                    if interact then task.spawn(function() pcall(function() interact:InvokeServer(pad) end) end) end
                                end
                                if distance < 50 and pad.BrickColor == BrickColor.new("Cyan") and not moved then
                                    local diff = math.clamp(pad.Position.X - root.Position.X, -1, 1)
                                    direction = math.clamp(direction + diff * dt * 24, -12, 14)
                                    moved = true
                                end
                            end
                        end
                    end
                    if not moved then
                        direction = math.clamp(direction + math.clamp(-direction, -1, 1) * dt * 24, -12, 14)
                    end
                    if flag("misc_kick_equip", false) and not LocalPlayer.Character:FindFirstChildOfClass("Tool") then
                        local pack = LocalPlayer:FindFirstChildOfClass("Backpack")
                        local tool = pack and pack:FindFirstChildOfClass("Tool")
                        if tool then hum:EquipTool(tool) else root.CFrame = CFrame.new(816, 98, 2233) return end
                    end
                    if (root.Position - v3(633, 98, 2489)).Magnitude < 40 then
                        root.CFrame = CFrame.new(610 + direction, 90, 2494)
                        root.AssemblyLinearVelocity = v3(24, 0, 0)
                    end
                end

                scan += dt
                if scan > 0.1 then
                    scan = 0
                    table.clear(seats)
                    local cars = workspace:FindFirstChild("CarContainer")
                    if cars then
                        for _, d in ipairs(cars:GetDescendants()) do
                            if d:IsA("VehicleSeat") then seats[#seats + 1] = d end
                        end
                    end
                end
                for _, seat in ipairs(seats) do
                    if seat.Parent and isnetworkowner(seat) then
                        local target = pickTarget(seat)
                        if target then
                            seat.AssemblyLinearVelocity = v3(10000, 10000, 0)
                            seat.CFrame = CFrame.new(target.Root.Position) * CFrame.new(-2, 0, -12)
                            target.Root.AssemblyLinearVelocity = ZERO
                            if type(sethiddenproperty) == "function" then
                                pcall(sethiddenproperty, seat, "PhysicsRepRootPart", target.Root)
                                if InstanceHandle and InstanceHandle.new then
                                    pcall(function() sethiddenproperty(seat, "PhysicsRepRootRef", InstanceHandle.new(target.Root)) end)
                                end
                            end
                            local wheels = seat.Parent.Parent and seat.Parent.Parent:FindFirstChild("Wheels")
                            if wheels then wheels:Destroy() end
                        end
                    end
                end
            end))
            return true
        end

        local function stopEngine()
            bag.clear()
            table.clear(seats)
        end

        local function acquire()
            users += 1
            if users == 1 and not startEngine() then
                users = 0
                switchOff("misc_kick_sel")
                switchOff("misc_kick_all")
            end
        end

        local function release()
            if users <= 0 then return end
            users -= 1
            if users == 0 then stopEngine() end
        end

        feature("misc_kick_sel", acquire, release)
        feature("misc_kick_all", acquire, release)

        -- the button: fling the selected player for a few seconds
        Actions.kickOnce = function()
            if not Players:FindFirstChild(flag("Player_Selected", "")) then say("Select a player first") return end
            local running = onceUntil > clock()
            onceUntil = clock() + 4
            if running then return end
            acquire()
            task.spawn(function()
                while clock() < onceUntil do task.wait(0.1) end
                release()
            end)
        end
        onUnload(function()
            Actions.kickOnce = noop
            stopEngine()
        end)
    end

    -- watcher: starts and stops features as their toggles change --------------------------
    track(RunService.Heartbeat:Connect(function()
        for _, f in ipairs(features) do
            setActive(f, readFlag(f.flag, false) == true)
        end
    end))

    onUnload(function()
        for _, f in ipairs(features) do setActive(f, false) end
        MiscActions.clearCheats = noop
    end)
end

Loader.step("Loading config", 0.92)
pcall(function() SaveManager:LoadAutoloadConfig() end)
Loader.finish(function()
    Loader.saveAccent(Library.AccentColor)
    if not Library.Toggled then pcall(function() Library:Toggle() end) end
    Library:Notify("Aster loaded", 4)
end)
end, debug.traceback)
if not __plOk then
    warn("[Aster] FAILED:\n" .. tostring(__plErr))
    Loader.fail(tostring(__plErr):match("[^\n]+") or "error")
end
