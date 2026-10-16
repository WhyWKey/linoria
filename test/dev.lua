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

    local function setFade(alpha)
        fade = alpha
        pcall(function()
            if blur then blur.Size = 18 * (1 - alpha) end
            if dim then dim.BackgroundTransparency = 0.55 + 0.45 * alpha end
            for _, l in ipairs({ titleLabel, statusLabel, percentLabel }) do l.TextTransparency = alpha end
            if track then track.BackgroundTransparency = alpha end
            if fill then fill.BackgroundTransparency = alpha end
        end)
    end

    function self.step(text, progress)
        if self.closed then return end
        self.target = math.max(self.target, progress or self.target)
        pcall(function() if statusLabel then statusLabel.Text = tostring(text) end end)
        task.wait()
    end

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

SKYBOX_PRESETS["Custom"] = { Custom = true }

local AURA_PACK = {
    id = 15374038687,
    rigs = {

        ["Dark Aura"] = { id = 16039329607, rig = "DarkAura" },
        ["Fire Aura"] = { id = 16039329607, rig = "FireAura" },
        ["Light Aura"] = { id = 16039329607, rig = "LightAura" },
        ["Water Aura"] = { id = 16039329607, rig = "WaterAura" },

        ["Bass"] = { id = 17084658587, rig = "POF:RE AURA: Bass" },
        ["Aurora Borealis"] = { id = 17084658587, rig = "Aurora Borealis" },
        ["Corruption (Revised)"] = { id = 17084658587, rig = "Corruption (Revised)" },
        ["Poison"] = { id = 17084658587, rig = "POF:RE AURA POISON" },
        ["Coin Rain"] = { id = 17084658587, rig = "POF:RE AURA COIN RAIN" },
        ["Plague Fumes"] = { id = 17084658587, rig = "POF:RE AURA PLAGUE FUMES" },
        ["Speed State"] = { id = 17084658587, rig = "POF:RE AURA SPEED STATE" },
        ["Zodiac"] = { id = 17084658587, rig = "POF:RE AURA ZODIAC" },
        ["Dutchman"] = { id = 17084658587, rig = "POF:RE AURA DUTCHMAN" },
        ["Sweetwave"] = { id = 17084658587, rig = "POF:RE AURA SWEETWAVE" },
        ["Psychic"] = { id = 17084658587, rig = "POF:RE AURA PSYCHIC " },
        ["Electrical Charge"] = { id = 17084658587, rig = "Electrical Charge" },
        ["Pure Darkness (REVAMP)"] = { id = 17084658587, rig = "POF:RE AURA Pure Darkness (REVAMP)" },
        ["Cryogen"] = { id = 17084658587, rig = "POF:RE AURA CRYOGEN" },
        ["Ultimate Evil"] = { id = 17084658587, rig = "POF:RE AURA ULTIMATE EVIL" },
        ["Fire Eyes"] = { id = 17084658587, rig = "POF:RE AURA: Fire Eyes" },
        ["Lunar Eclipse"] = { id = 17084658587, rig = "Lunar Eclipse" },
        ["Solar Eclipse"] = { id = 17084658587, rig = "Solar Eclipse" },
        ["Universal Keys"] = { id = 17084658587, rig = "Universal Keys" },
        ["Infinite Vortex"] = { id = 17084658587, rig = "Infinite Vortex" },
        ["Crimson Moon"] = { id = 17084658587, rig = "POF:RE AURA: Crimson Moon" },
        ["Heaven Rings"] = { id = 17084658587, rig = "POF:RE AURA: Heaven Rings" },
        ["Obsidian Heart"] = { id = 17084658587, rig = "Obsidian Heart" },
        ["Luipislipophobia [REVAMP]"] = { id = 17084658587, rig = "Luipislipophobia [REVAMP]" },
        ["Manifestation of Chaos"] = { id = 17084658587, rig = "Manifestation of Chaos" },
        ["Ultra Ego"] = { id = 17084658587, rig = "POF:RE AURA ULTRA EGO" },
        ["Avatar"] = { id = 17084658587, rig = "Avatar" },
        ["Insanity"] = { id = 17084658587, rig = "POF:RE AURA  INSANITY" },
        ["Corvus"] = { id = 17084658587, rig = "POF:RE AURA  CORVUS" },

        ["Susanoo Arms"] = { id = 106979401006635, rig = "Aura_SusanooArms" },
        ["Snow Flakes"] = { id = 106979401006635, rig = "Aura_SnowFlakes" },
        ["Red Wings"] = { id = 106979401006635, rig = "Aura_RedWings" },
        ["Saiyan"] = { id = 106979401006635, rig = "Aura_Saiyan" },
        ["Thund"] = { id = 106979401006635, rig = "Aura_Thund" },
        ["Time Killing A"] = { id = 106979401006635, rig = "Aura_TimeKillingA" },
        ["Atomic"] = { id = 106979401006635, rig = "Aura_Atomic" },
        ["Romantic Bloom"] = { id = 106979401006635, rig = "Aura_RomanticBloom" },
        ["Water Bubble Trio"] = { id = 106979401006635, rig = "Aura_WaterBubbleTrio" },
        ["Aether"] = { id = 106979401006635, rig = "Aura_Aether" },
        ["White Wings"] = { id = 106979401006635, rig = "Aura_WhiteWings" },
        ["Kurama"] = { id = 106979401006635, rig = "Aura Kurama" },
        ["Red Heart Fire"] = { id = 106979401006635, rig = "Aura_RedHeartFire" },
        ["Pumpk"] = { id = 106979401006635, rig = "Aura_pumpk" },
        ["Rainb Flame"] = { id = 106979401006635, rig = "Aura_RainbFlame" },
        ["Purp"] = { id = 106979401006635, rig = "Aura_Purp" },
        ["Anon"] = { id = 106979401006635, rig = "Aura_Anon" },
        ["Binary404"] = { id = 106979401006635, rig = "Aura_Binary404" },
        ["Blind Obsession"] = { id = 106979401006635, rig = "Aura_BlindObsession" },
        ["Frozen Bloom"] = { id = 106979401006635, rig = "Aura_FrozenBloom" },
        ["Flame Crown"] = { id = 106979401006635, rig = "Aura_FlameCrown" },
        ["Blazing Pink Heart"] = { id = 106979401006635, rig = "Aura_BlazingPinkHeart" },
        ["Fire Fist"] = { id = 106979401006635, rig = "Aura_FireFist" },
        ["Dark Roger"] = { id = 106979401006635, rig = "Aura_DarkRoger" },

        ["Ohio Overlord"] = { id = 91974923945606, part = "Ohio Overlord" },
        ["Mewlight"] = { id = 91974923945606, part = "Mewlight" },
        ["Sigma Radiant"] = { id = 91974923945606, part = "Sigma Radiant" },
        ["Ohio Born"] = { id = 91974923945606, part = "Ohio Born" },
        ["Rizznado"] = { id = 91974923945606, part = "Rizznado" },
        ["Rizz Rift"] = { id = 91974923945606, part = "Rizz Rift" },
        ["Ohio Surge"] = { id = 91974923945606, part = "Ohio Surge" },
        ["Gyatt Forged"] = { id = 91974923945606, part = "Gyatt Forged" },
        ["Brainrot Incarnate"] = { id = 91974923945606, part = "Brainrot Incarnate" },
        ["Frozen Rage"] = { id = 91974923945606, part = "Frozen Rage" },
        ["Rizz Shock"] = { id = 91974923945606, part = "Rizz Shock" },
        ["Ohio Haze"] = { id = 91974923945606, part = "Ohio Haze" },
        ["Cyan Rift"] = { id = 91974923945606, part = "Cyan Rift" },
        ["Aqua Surge"] = { id = 91974923945606, part = "Aqua Surge" },
        ["Zyzz'ilian"] = { id = 91974923945606, part = "Zyzz'ilian" },
        ["Bloodrot"] = { id = 91974923945606, part = "Bloodrot" },
        ["Celestial Override"] = { id = 91974923945606, part = "Celestial Override" },
        ["Heavenly Static"] = { id = 91974923945606, part = "Heavenly Static" },
        ["Rizz Infused"] = { id = 91974923945606, part = "Rizz Infused" },
        ["Brainrotted"] = { id = 91974923945606, part = "Brainrotted" },
        ["Rizz Sun Core"] = { id = 91974923945606, part = "Rizz Sun Core" },
        ["Omnipotent Mewer"] = { id = 91974923945606, part = "Omnipotent Mewer" },
        ["Dunepilled"] = { id = 91974923945606, part = "Dunepilled" },
        ["Skibidi Touched"] = { id = 91974923945606, part = "Skibidi Touched" },
        ["Rizz Spark"] = { id = 91974923945606, part = "Rizz Spark" },
        ["Emerald Overdrive"] = { id = 91974923945606, part = "Emerald Overdrive" },
        ["Cosmic Mewer"] = { id = 91974923945606, part = "Cosmic Mewer" },
        ["Sigma Spectrum"] = { id = 91974923945606, part = "Sigma Spectrum" },
        ["Void Mogger"] = { id = 91974923945606, part = "Void Mogger" },
        ["Crimson Skibidi Core"] = { id = 91974923945606, part = "Crimson Skibidi Core" },
        ["Cloutstorm"] = { id = 91974923945606, part = "Cloutstorm" },
        ["Sigma Avalanche"] = { id = 91974923945606, part = "Sigma Avalanche" },
        ["Aurizzora"] = { id = 91974923945606, part = "Aurizzora" },
        ["Ohio Blizzard"] = { id = 91974923945606, part = "Ohio Blizzard" },
        ["Portalpilled"] = { id = 91974923945606, part = "Portalpilled" },
        ["Toxicmaxxer"] = { id = 91974923945606, part = "Toxicmaxxer" },
        ["Molten Menace"] = { id = 91974923945606, part = "Molten Menace" },
        ["Frost Mogger"] = { id = 91974923945606, part = "Frost Mogger" },
        ["Sigma Inferno"] = { id = 91974923945606, part = "Sigma Inferno" },
        ["Frostmaxxer"] = { id = 91974923945606, part = "Frostmaxxer" },
        ["Skibrrrdi"] = { id = 91974923945606, part = "Skibrrrdi" },
        ["Rizznova"] = { id = 91974923945606, part = "Rizznova" },
        ["Emeraldmaxxer"] = { id = 91974923945606, part = "Emeraldmaxxer" },
        ["Armageddon"] = "POF:RE AURA ARMAGEDDON",
        ["Battleship"] = "Battleship",
        ["Beast"] = "POF:RE AURA  BEAST",
        ["Blue Heat"] = "POF:RE AURA: Blue Heat",
        ["Blue Lock"] = "POF:RE AURA: Blue Lock",
        ["Celestial Body"] = "POF:RE AURA  CELESTIAL BODY",
        ["Chain God"] = "POF:RE AURA: Chain God",
        ["Cinder"] = "POF:RE AURA CINDER",
        ["Cloak of Lightning"] = "POF:RE AURA: Cloak of Lightning",
        ["Cool Vapor"] = "POF:RE AURA COOL VAPOR",
        ["Crystal determination"] = "POF:RE AURA: Crystal determination",
        ["Daemon of Cards"] = "POF:RE AURA: Daemon of Cards",
        ["Deadly Orbital Strike"] = "Deadly Orbital Strike",
        ["Demonic Drive"] = "POF:RE AURA: Demonic Drive",
        ["Devil's beam"] = "POF:RE AURA: Devil's beam",
        ["Fiery Ritual of Hallownest"] = "POF:RE AURA: Fiery Ritual of Hallownest",
        ["Gravity God"] = "POF:RE AURA: Gravity God",
        ["Green power"] = "POF:RE AURA: Green power",
        ["Hanma"] = "POF:RE AURA HANMA",
        ["Heaven"] = "POF:RE AURA HEAVEN",
        ["Hellish Orb"] = "POF:RE AURA: Hellish Orb",
        ["Hellzone Champion"] = "POF:RE AURA: Hellzone Champion",
        ["High Gravity"] = "POF:RE AURA  HIGH GRAVITY",
        ["Honoring Flame"] = "POF:RE AURA: Honoring Flame",
        ["Incognito"] = "POF:RE AURA: Incognito",
        ["Infinite Reality"] = "Infinite Reality",
        ["Midnight Blues"] = "POF:RE AURA: Midnight Blues",
        ["MUI"] = "POF:RE AURA MUI",
        ["Mutants Rage"] = "POF:RE AURA MUTANTS RAGE",
        ["Nano"] = "POF:RE AURA NANO",
        ["North Star"] = "North Star",
        ["North Star (POF)"] = "POF:RE AURA NORTH STAR",
        ["Omega"] = "POF:RE AURA OMEGA",
        ["Psychic Orbs"] = "POF:RE AURA: Psychic Orbs",
        ["Pure Vessel"] = "Pure Vessel",
        ["Radiance"] = "POF:RE AURA RADIANCE",
        ["Red King"] = "POF:RE AURA RED KING",
        ["Red King's Bash"] = "POF:RE AURA: Red King's Bash",
        ["Red Ring of Death"] = "POF:RE AURA: Red Ring of Death",
        ["Roar of The Jungle Dragon"] = "POF:RE AURA: Roar of The Jungle Dragon",
        ["SSJG"] = "POF:RE AURA SSJG By ZironTheDerg",
        ["Shadow's Wrath"] = "Shadow's Wrath",
        ["Solar Flare"] = "POF:RE AURA SOLAR FLARE",
        ["SSJB"] = "POF:RE AURA SSJB",
        ["Stardust Fragment"] = "POF:RE AURA: Stardust Fragment",
        ["Street Demon"] = "POF:RE AURA: Street Demon",
        ["Submission: Wormhole"] = "PoF:Re Aura Submission: Wormhole",
        ["Summer Lovin'"] = "POF:RE AURA SUMMER LOVIN'",
        ["Sun Necromancer"] = "POF:RE AURA: Sun Necromancer",
        ["Super Sonic"] = "POF:RE AURA SUPER SONIC",
        ["Wano"] = "POF:RE AURA: Wano",
        ["Wisp"] = "POF:RE AURA  WISP",
    },
    items = { "starlight", "heavenly", "ribbon", "sakura", "angel", "wind", "flow", "star" },
}
do
    local names = {}
    for label in pairs(AURA_PACK.rigs) do table.insert(names, label) end
    table.sort(names)
    for _, label in ipairs(names) do table.insert(AURA_PACK.items, label) end
end

local SKYBOX_NAMES = { "Default", "Custom" }
do
    local names = {}
    for name in pairs(SKYBOX_PRESETS) do
        if name ~= "Default" and name ~= "Custom" then table.insert(names, name) end
    end
    table.sort(names)
    for _, name in ipairs(names) do table.insert(SKYBOX_NAMES, name) end
end

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
local playHitSound
local function noop() end
local SpooferActions = { apply = noop, reset = noop, applyUser = noop, applyOutfit = noop }

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

local BEAM_PACK = {
    { 5320460025, 0.1, 1, 1, 4 },
    { 5259318941, 1, 1, 1, 4 },
    { 5059545109, 1, 1, 1, 4 },
    { 5059575678, 1, 1, 1, 4 },
    { 3517446796, 1, 1, 1, 4 },
    { 4979919970, 1, 1, 1, 4 },
    { 5309396574, 1, 1, 1, 4 },
    { 5319756636, 1, 1, 1, 4 },
    { 5259392291, 1, 1, 1, 4 },
    { 5319760646, 1, 1, 1, 4 },
    { 5059527230, 0.1, 0.1, 1, 4 },
    { 5697446711, 0.1, -0.5, 0.3, 4 },
    { 5889857268, 1, 1, 0.3, 4 },
    { 5889875399, 0.1, 1, 1, 4 },
    { 5889822396, 0.1, 0.2, 1, 4 },
    { 5059416965, 1, 1, 1, 4 },
    { 5319757616, 1, 1, 1, 4 },
    { 5059556437, 1, 1, 1, 4 },
    { 5319761683, 0.1, 0.1, 1, 4 },
    { 5320396964, 1, 1, 1, 4 },
    { 1134824633, 1, 1, 1, 4 },
    { 5319765539, 1, 1, 1, 4 },
    { 5319759478, 1, 1, 1, 4 },
    { 5259508588, 1, 1, 1, 4 },
    { 5319763670, 1, 1, 1, 4 },
    { 241779220, 0.1, 1, 1, 4 },
    { 5638199267, 1, 1, 1, 4 },
    { 5319767945, 1, 1, 1, 4 },
    { 5325351689, 1, 1, 1, 4 },
    { 5309397437, 1, 1, 1, 4 },
    { 5309397920, 1, 1, 1, 4 },
    { 5259350470, 1, 1, 1, 4 },
    { 5319764523, 1, 1, 1, 4 },
    { 5320409098, 1, 1, 1, 4 },
    { 5638169715, 1, 1, 1, 4 },
    { 5638170046, 1, 1, 1, 4 },
    { 5319767042, 1, 1, 1, 4 },
    { 5259455940, 1, 1, 1, 4 },
    { 5320400553, 1, 1, 1, 4 },
    { 1274378728, 1, -1, 1, 4 },
    { 5259486177, 1, 1, 1, 4 },
    { 123310848, 1, 1, 1, 4 },
    { 79443127, 1, 1, 1, 4 },
    { 5889822044, 1, 1, 1, 4 },
    { 5311020240, 1, 1, 1, 4 },
    { 5311019692, 1, 1, 1, 4 },
    { 5311021013, 1, 1, 1, 4 },
    { 5320395241, 1, 1, 1, 4 },
    { 5889807991, 1, 1, 1, 4 },
    { 5320399816, 1, 1, 1, 4 },
    { 5311021681, 1, 1, 1, 4 },
    { 5309396094, 1, 1, 1, 4 },
    { 4975465603, 1, 1, 1, 4 },
    { 5320412027, 1, 1, 1, 4 },
    { 5320407484, 1, 1, 1, 4 },
    { 5320412694, 1, 1, 1, 4 },
    { 5259529792, 1, 1, 1, 4 },
    { 457102813, 1, 1, 1, 4 },
    { 3186190770, 1, 1, 1, 4 },
    { 5320401463, 1, 1, 1, 4 },
    { 5259589000, 1, 1, 1, 4 },
    { 5638167113, 1, 1, 1, 4 },
    { 5638168890, 1, 1, 1, 4 },
    { 5638167770, 2.625, 3, 1, 4 },
    { 5638169137, 1, 1, 1, 4 },
    { 5320411483, 1, 1, 1, 4 },
    { 5320395820, 1, 1, 1, 4 },
    { 5320396458, 1, 1, 1, 4 },
    { 5320461870, 1, 1, 1, 4 },
    { 8091475665, 0.625, -0.5, 1, 4 },
    { 8098345726, 1.25, -0.5, 1, 6 },
    { 8091408769, 1, -1, 1, 4 },
    { 5655747881, 0.1, -1, 1, 4 },
    { 6528210403, 0.1, -0.6, 1, 4 },
    { 6531295492, 0.1, -0.7, 1, 5 },
    { 6933783148, 0.1, -0.6, 1, 4 },
    { 6933806553, 1.125, -0.6, 1, 4 },
    { 245996148, 0.1, -1, 1, 4 },
    { 8089421301, 1, -1, 1, 4 },
    { 8089452023, 1, -1, 1, 4 },
    { 8089495857, 1, -1, 1, 4 },
}
for index, row in ipairs(BEAM_PACK) do
    local name = string.format("Beam %02d", index)
    TRACER_PRESETS[name] = {
        Texture = "rbxassetid://" .. row[1], Brightness = 1,
        Transparency = NumberSequence.new(0), BaseTransparency = 0,
        LightEmission = row[4], LightInfluence = 0, Segments = 1, TextureLength = row[2],
        TextureMode = Enum.TextureMode.Stretch, TextureSpeed = row[3], Width0 = 0.5 * row[5] / 4, Width1 = 0.5 * row[5] / 4, FaceCamera = true,
    }
end
local TRACER_NAMES = { "Obelus", "Lightning", "DNA", "Plain", "Beam", "Bolt", "Trail", "Zigzag", "Heartrate", "Chain", "Glitch", "Swirl" }
for index = 1, #BEAM_PACK do table.insert(TRACER_NAMES, string.format("Beam %02d", index)) end
local WEATHER_NAMES = { "Snow", "Rain", "Blizzard" }

local LocalPlayer = Players.LocalPlayer

Loader.verify(0.16)
local UI_REPO = "https://raw.githubusercontent.com/WhyWKey/linoria/main/"
Loader.step("Downloading UI library", 0.22)

local function patchLibrarySource(source)
    local function swap(find, replace)
        local first, last = string.find(source, find, 1, true)
        if first then source = string.sub(source, 1, first - 1) .. replace .. string.sub(source, last + 1) end
    end

    swap("            local Event;\n            Event = InputService.InputBegan:Connect(function(Input)",
[[            local Event;
            task.spawn(function()
                while not Break do
                    for _, SideKey in ipairs({ 'MB4', 'MB5' }) do
                        if (not Break) and Library.ButtonDown and Library.ButtonDown(SideKey) then
                            Break = true;
                            Picking = false;
                            DisplayLabel.Text = SideKey;
                            KeyPicker.Value = SideKey;
                            Library:SafeCallback(KeyPicker.ChangedCallback, Enum.KeyCode.Unknown);
                            Library:SafeCallback(KeyPicker.Changed, Enum.KeyCode.Unknown);
                            Library:AttemptSave();
                            if Event then Event:Disconnect(); end;
                        end;
                    end;
                    task.wait();
                end;
            end);
            Event = InputService.InputBegan:Connect(function(Input)]])
    swap("                elseif Input.UserInputType == Enum.UserInputType.MouseButton2 then\n                    Key = 'MB2';",
         "                elseif Input.UserInputType == Enum.UserInputType.MouseButton2 then\n                    Key = 'MB2';\n                elseif Input.UserInputType == Enum.UserInputType.MouseButton3 then\n                    Key = 'MB3';")

    swap("                local Key = KeyPicker.Value;\n                if Key == 'MB1' or Key == 'MB2' or Key == 'Touch' then\n                    return Key == 'MB1' and",
         "                local Key = KeyPicker.Value;\n                if Key == 'MB3' or Key == 'MB4' or Key == 'MB5' then\n                    return (Library.ButtonDown and Library.ButtonDown(Key)) == true;\n                end;\n                if Key == 'MB1' or Key == 'MB2' or Key == 'Touch' then\n                    return Key == 'MB1' and")

    swap("Cursor.ZIndex = 100;", "Cursor.ZIndex = 5000;")
    swap("CursorOutline.ZIndex = 99;", "CursorOutline.ZIndex = 4999;")
    return source
end

local Library = loadstring(patchLibrarySource(game:HttpGet(UI_REPO .. "Library.lua")))()
local ThemeManager = loadstring(game:HttpGet(UI_REPO .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(UI_REPO .. "addons/SaveManager.lua"))()

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

local function readFlag(name, default)
    local object = Toggles[name]
    if object == nil then object = Options[name] end
    if object == nil or object.Value == nil then return default end
    return object.Value
end

local Relations = {}
local function isEnemy(player)
    if not player or player == LocalPlayer then return false end
    local explicit = Relations[player.UserId]
    if explicit == "Friendly" then return false end
    if explicit == "Priority" then return true end
    local mine, theirs = LocalPlayer.Team, player.Team
    if not mine or not theirs then return true end
    if mine == theirs then return false end
    return true
end
local function relationOf(player)
    local explicit = Relations[player.UserId]
    if explicit then return explicit end
    return isEnemy(player) and "Enemy" or "Friendly"
end

local function isPeaceful(player)
    if not player or Relations[player.UserId] == "Priority" then return false end
    local team = player.Team
    if not team or team.Name ~= "Inmates" then return false end
    local char = player.Character
    return not (char and char:GetAttribute("Hostile") == true)
end

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
    AutoShow = false,
    MenuFadeTime = 0.2,

    UseBlur = false,
    UseDarken = false,
})

pcall(function() Library.ScreenGui.DisplayOrder = 100 end)

local function keyName(key)
    local ok, name = pcall(function() return key.Name end)
    if ok and type(name) == "string" then return name end
    return tostring(key or "None")
end

local function toRounding(decimals)
    if type(decimals) ~= "number" or decimals <= 0 or decimals >= 1 then return 0 end
    return math.clamp(math.floor(-math.log10(decimals) + 0.5), 0, 4)
end

local keybindRegistry = {}

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
        if info.Alpha then pickerInfo.Transparency = type(info.Alpha) == "number" and info.Alpha or 0 end
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
            SyncToggleState = info.Sync == true,
        })
        escapeUnbinds(info.Flag, "None")
        table.insert(keybindRegistry, { flag = info.Flag, name = info.Name or info.Flag })
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

        return wrapElement(group:AddLabel(info.Name, #info.Name > 28))
    end

    function wrapped:Button(info)
        bump()
        group:AddButton(info.Name, info.Callback)
    end

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
        return page.load[1] <= page.load[2] and 1 or 2
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

local CombatTab   = Window:Page({ Name = "Combat",  Columns = 2, Subtabs = false })
local VisualsPage = Window:Page({ Name = "Visuals", Columns = 2, Subtabs = false })
local WorldPage   = Window:Page({ Name = "World",   Columns = 2, Subtabs = false })

local PlayersPage  = Window:Page({ Name = "Players", Columns = 2, Subtabs = false })
local MiscPage     = Window:Page({ Name = "Misc",    Columns = 2, Subtabs = false })
local MiscActions  = { clearCheats = noop }
local TeleportPage = Window:Page({ Name = "Teleport", Columns = 2, Subtabs = false })
local ShotEvents = { shot = {}, hit = {}, cast = {}, kill = {} }
local Actions = {
    previewHitEffect = noop, previewKillEffect = noop, packRig = function() end, getWeapon = noop, getAllWeapons = noop, getItem = noop, getPlace = noop,
    kickOnce = noop, fxHook = noop, autoHook = noop, assistHook = noop, fireAt = function() return false end,
    sp = { assist = {}, shooter = function(root) return root.Position end, realPos = function(root) return root.Position end },
    area = function() return "outside" end,
}

local WHITE = Color3.fromRGB(255, 255, 255)
local BLACK = Color3.fromRGB(0, 0, 0)

do

do

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
        Name = "Method", Flag = "wb_method", Items = { "Vape V4", "Aster Origin", "Aster Reach", "Aster Precise" }, Default = "Aster Reach",
        Tooltip = "Vape V4: Vape's origin scan, works best when you stand near a wall.\nAster Origin: scans more origins around you and tries the closest ones first (a bit better than Vape V4).\nAster Reach: reaches through more walls (origins up to twice the scan radius) but can be inaccurate sometimes.\nAster Precise: works out origins along the line to the target, closest first, and only widens the search when it has to.",
    })
    Wall:Toggle({ Name = "Use hitbox", Flag = "wb_hitbox", Default = true, Tooltip = "Also aim at points beside the target's body, not only at the part itself" })
    Wall:Slider({ Name = "Scan radius", Flag = "wb_radius", Min = 1, Max = 10, Default = 6, Suffix = " studs", Decimals = 0.1 })
    Wall:Toggle({ Name = "Damage check", Flag = "wb_damage", Default = true, Tooltip = "Only uses a shot origin and hit point that can deal damage: close enough to you and to the target's body, and inside the gun's range. The indicator, auto fire and assist use the same check." })
    Wall:Slider({ Name = "Max spot distance", Flag = "wb_spot", Min = 5, Max = 20, Default = 7.5, Suffix = " studs", Decimals = 0.1 })

    local Assist = CombatTab:Section({ Name = "Wallbang assist", Side = 1 })
    local assistToggle = Assist:Toggle({ Name = "Wallbang assist", Flag = "wb_assist", Default = false, Tooltip = "Works on anyone near your cursor, no silent aim needed. If an enemy is behind a wall, it moves the position the server sees up to (or into) the wall so the shot has a line, and sends the shot at that enemy." })
    assistToggle:Keybind({ Name = "Assist key", Flag = "wb_assist_key", Default = "None", Sync = true })
    Assist:Dropdown({ Name = "Move method", Flag = "wb_assist_method", Items = { "Server position", "Velocity" }, Default = "Server position", Tooltip = "Server position: only what the server sees moves (writes the character CFrame). Velocity: you really move there with physics (no CFrame writes) and walls next to you stop colliding on the way, then you return. The visualizer only applies to Server position." })
    Assist:Dropdown({ Name = "Mode", Flag = "wb_assist_mode", Items = { "Tween", "Teleport" }, Default = "Tween", Tooltip = "Tween moves at the speed below. Teleport jumps (Server position) or moves at 120 studs/s (Velocity)." })
    Assist:Toggle({ Name = "Inside wall", Flag = "wb_assist_inside", Default = false })
    Assist:Toggle({ Name = "Only while firing", Flag = "wb_assist_fire", Default = false, Tooltip = "Only moves while the fire button is held or auto fire is shooting" })
    Assist:Slider({ Name = "Assist FOV", Flag = "wb_assist_fov", Min = 10, Max = 800, Default = 250, Suffix = "px", Decimals = 1 })
    Assist:Slider({ Name = "Activation distance", Flag = "wb_assist_dist", Min = 1, Max = 45, Default = 25, Suffix = " studs", Decimals = 1 })
    Assist:Slider({ Name = "Tween speed", Flag = "wb_assist_speed", Min = 1, Max = 200, Default = 50, Suffix = " studs/s", Decimals = 1 })
    Assist:Slider({ Name = "Max target distance", Flag = "wb_assist_max", Min = 10, Max = 5000, Default = 200, Suffix = " studs", Decimals = 1 })
    local assistVisual = Assist:Toggle({ Name = "Visualizer", Flag = "wb_assist_visual", Default = false, Tooltip = "A highlighted copy of your character shows where the server sees you" })
    assistVisual:Colorpicker({ Name = "Fill", Flag = "wb_assist_fill", Default = Color3.fromRGB(255, 255, 255), Alpha = 0.6 })
    assistVisual:Colorpicker({ Name = "Outline", Flag = "wb_assist_line", Default = Color3.fromRGB(255, 255, 255), Alpha = 0 })

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
    Silent:Toggle({ Name = "Auto fire: skip blocked", Flag = "silent_autofire_check", Default = true, Tooltip = "With wallbang on, auto fire only shoots targets you can see or wallbang" })

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

do

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

do

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

    local AdornLayers, AdornGlow = VisualsPage:MultiSection({ Sections = { "Layers", "Glow" }, Side = 2 })
    AdornLayers:Slider({ Name = "Visible thickness", Flag = "esp_chams_adorn_thickness", Min = 0, Max = 0.6, Default = 0.1, Decimals = 0.01 })
    AdornGlow:Toggle({ Name = "Glow", Flag = "esp_chams_adorn_glow", Default = false })
    AdornGlow:Slider({ Name = "Glow strength", Flag = "esp_chams_adorn_glow_size", Min = 1, Max = 2.5, Default = 1.75, Decimals = 0.01 })
    AdornGlow:Toggle({ Name = "Round head", Flag = "esp_chams_adorn_round_head", Default = true })
    AdornGlow:Slider({ Name = "Head size", Flag = "esp_chams_adorn_head_size", Min = 0.8, Max = 1.6, Default = 1.15, Decimals = 0.01 })

    local CamFov = VisualsPage:Section({ Name = "Camera", Side = 1 })
CamFov:Toggle({ Name = "FOV changer", Flag = "camera_fov_changer", Default = false })
CamFov:Slider({ Name = "FOV", Flag = "camera_fov_changer_amount", Min = 40, Max = 140, Default = 100, Suffix = "°", Decimals = 1 })

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

    local EnvSky, EnvAtmos, EnvBloom, EnvScreen = WorldPage:MultiSection({ Sections = { "Sky", "Atmos", "Bloom", "Screen" }, Side = 1 })
    EnvSky:Toggle({ Name = "Skybox", Flag = "skybox_enabled", Default = false })
    EnvSky:Dropdown({ Name = "Preset", Flag = "skybox_value", Items = SKYBOX_NAMES, Default = SKYBOX_NAMES[1] })
    EnvSky:Input({ Name = "Custom ids", Flag = "skybox_custom_ids", Default = "", Placeholder = "1 id or link, or 6: up down front back left right" })
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

    local BodyForce, BodyExtra = VisualsPage:MultiSection({ Sections = { "Arms", "Extras" }, Side = 2 })
BodyForce:Toggle({ Name = "Forcefield material", Flag = "arm_material", Default = false }):Colorpicker({ Name = "Color", Flag = "arm_material_color", Default = Color3.fromRGB(255, 255, 255), Alpha = true })
BodyForce:Dropdown({ Name = "Forcefield texture", Flag = "arm_material_texture", Items = FORCEFIELD_TEXTURE_NAMES, Default = "Disabled" })
BodyExtra:Toggle({ Name = "Disable textures", Flag = "arm_disable_textures", Default = false })
BodyExtra:Toggle({ Name = "Remove accessories", Flag = "arm_remove_accessories", Default = false })

    local SelfChams = VisualsPage:Section({ Name = "Self chams", Side = 2 })
    SelfChams:Toggle({ Name = "Self chams", Flag = "Self_Chams", Default = false }):Colorpicker({ Name = "Fill", Flag = "Self_ChamsColor1", Default = Color3.fromRGB(80, 160, 255), Alpha = 0.3 }):Colorpicker({ Name = "Outline", Flag = "Self_ChamsColor2", Default = WHITE, Alpha = true })

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

    local HitFx = WorldPage:Section({ Name = "Hit effects", Side = 2 })
    local heToggle = HitFx:Toggle({ Name = "Hit effects", Flag = "he_enabled", Default = false })
    heToggle:Colorpicker({ Name = "Color", Flag = "he_color", Default = Color3.fromRGB(255, 81, 0) })
    HitFx:Dropdown({ Name = "Effect", Flag = "he_effect", Items = { "nova", "sparks", "bubble", "orbs", "air", "blood", "glitch", "slash", "cosmic", "crescentslash", "Burst: Mutants Rage", "Burst: Armageddon", "Burst: Solar Flare", "Burst: Heaven", "Burst: Gravity God", "Burst: Red Ring of Death", "Burst: Blue Heat", "Burst: Stardust Fragment", "Burst: Fiery Ritual of Hallownest", "Burst: Midnight Blues", "Burst: Susanoo Arms", "Burst: Atomic", "Burst: Kurama" }, Default = "nova" })
    HitFx:Dropdown({ Name = "Trigger", Flag = "he_trigger", Items = { "On hit", "On shot" }, Default = "On hit" })
    HitFx:Slider({ Name = "Size", Flag = "he_size", Min = 0, Max = 10, Default = 2, Decimals = 0.1 })
    HitFx:Slider({ Name = "Duration", Flag = "he_duration", Min = 0.1, Max = 10, Default = 2, Suffix = "s", Decimals = 0.1 })
    HitFx:Button({ Name = "Preview effect", Callback = function() Actions.previewHitEffect() end })

    local KillFx = WorldPage:Section({ Name = "Kill effects", Side = 2 })
    KillFx:Toggle({ Name = "Kill effects", Flag = "ke_enabled", Default = false, Tooltip = "Plays an effect where a player you shot dies" })
    KillFx:Dropdown({ Name = "Effect", Flag = "ke_effect", Items = { "Stone", "Gold Statue", "Fade", "Ghost", "Shrink", "Blackhole", "Cosmic Strike", "Cyberspace", "Darkheart", "Deleted", "Galactic Pull", "Game Over", "Glitter Bomb", "Heartbreak", "Infinite Portal", "Lightning", "Northern Aurora Burst", "Paper Surprise", "Scorch", "Soul Grasp", "Sparkle", "Stereo", "Tornado", "Tornado Acid", "Tornado Earth", "Tornado Fire", "Tornado Lightning" }, Default = "Darkheart" })
    KillFx:Toggle({ Name = "Body reaction", Flag = "ke_body", Default = true, Tooltip = "Also changes the victim's own body parts where the original effect does (charred stone, shrinking, fading)" })
    KillFx:Slider({ Name = "Duration", Flag = "ke_duration", Min = 1, Max = 8, Default = 4, Suffix = "s", Decimals = 0.1 })
    KillFx:Button({ Name = "Preview effect", Callback = function() Actions.previewKillEffect() end })

    local Muzzle = WorldPage:Section({ Name = "Muzzle effects", Side = 2 })
    Muzzle:Toggle({ Name = "Muzzle effects", Flag = "mz_enabled", Default = false, Tooltip = "Black hole effects on the Muzzle part of the tool you hold" })
    Muzzle:Dropdown({ Name = "Effect", Flag = "mz_effect", Items = { "Blue Black Hole", "Gold Black Hole", "Orange Black Hole", "Purple Black Hole", "Red Black Hole", "White Black Hole" }, Default = "Purple Black Hole" })
    Muzzle:Dropdown({ Name = "Mode", Flag = "mz_mode", Items = { "While equipped", "On shot" }, Default = "While equipped" })
    Muzzle:Slider({ Name = "Flash time", Flag = "mz_flash", Min = 0.05, Max = 1.5, Default = 0.25, Suffix = "s", Decimals = 0.05 })
    Muzzle:Slider({ Name = "Size", Flag = "mz_size", Min = 0.5, Max = 100, Default = 5, Suffix = "%", Decimals = 0.5 })
    Muzzle:Toggle({ Name = "Custom color", Flag = "mz_custom", Default = false }):Colorpicker({ Name = "Color", Flag = "mz_color", Default = Color3.fromRGB(255, 80, 80) })
    Muzzle:Slider({ Name = "Transparency", Flag = "mz_alpha", Min = 0, Max = 0.95, Default = 0, Decimals = 0.05 })
    Muzzle:Slider({ Name = "Offset X", Flag = "mz_x", Min = -5, Max = 5, Default = 0, Suffix = " studs", Decimals = 0.05 })
    Muzzle:Slider({ Name = "Offset Y", Flag = "mz_y", Min = -5, Max = 5, Default = 0, Suffix = " studs", Decimals = 0.05 })
    Muzzle:Slider({ Name = "Offset Z", Flag = "mz_z", Min = -5, Max = 5, Default = 0, Suffix = " studs", Decimals = 0.05 })
    Muzzle:Slider({ Name = "Rotation X", Flag = "mz_rx", Min = -180, Max = 180, Default = 0, Suffix = "°", Decimals = 1 })
    Muzzle:Slider({ Name = "Rotation Y", Flag = "mz_ry", Min = -180, Max = 180, Default = 0, Suffix = "°", Decimals = 1 })
    Muzzle:Slider({ Name = "Rotation Z", Flag = "mz_rz", Min = -180, Max = 180, Default = 0, Suffix = "°", Decimals = 1 })
    Muzzle:Slider({ Name = "Roll", Flag = "mz_roll", Min = -180, Max = 180, Default = 0, Suffix = "°", Decimals = 1, Tooltip = "Spins the particle sprites themselves" })
    Muzzle:Button({ Name = "Reset position", Callback = function()
        for _, name in ipairs({ "mz_x", "mz_y", "mz_z", "mz_rx", "mz_ry", "mz_rz", "mz_roll" }) do
            local option = Options[name]
            if option and option.SetValue then pcall(function() option:SetValue(0) end) end
        end
    end })

    local Reload = WorldPage:Section({ Name = "Reload indicator", Side = 2 })
    Reload:Toggle({ Name = "Reload indicator", Flag = "reload_ind", Default = false, Tooltip = "A progress bar under the cursor while your gun reloads" })
    Reload:Toggle({ Name = "Show time", Flag = "reload_ind_text", Default = true })
    Reload:Slider({ Name = "Width", Flag = "reload_ind_w", Min = 40, Max = 300, Default = 120, Suffix = "px", Decimals = 1 })
    Reload:Slider({ Name = "Height", Flag = "reload_ind_h", Min = 3, Max = 16, Default = 6, Suffix = "px", Decimals = 1 })
    Reload:Slider({ Name = "Vertical offset", Flag = "reload_ind_y", Min = -300, Max = 300, Default = 40, Suffix = "px", Decimals = 1 })
    Reload:Label({ Name = "Bar color" }):Colorpicker({ Name = "Bar", Flag = "reload_ind_fill", Default = Color3.fromRGB(255, 255, 255), Alpha = 0 })
    Reload:Label({ Name = "Background color" }):Colorpicker({ Name = "Background", Flag = "reload_ind_back", Default = Color3.fromRGB(0, 0, 0), Alpha = 0.5 })

    local Ammo = WorldPage:Section({ Name = "Ammo indicator", Side = 2 })
    Ammo:Toggle({ Name = "Server bullet count", Flag = "ammo_ind", Default = false, Tooltip = "Shows how many bullets the server says your gun has. It turns yellow when that differs from the count your game shows." })
    Ammo:Toggle({ Name = "Show local count", Flag = "ammo_ind_local", Default = false, Tooltip = "Also shows the count your own game shows" })
    Ammo:Slider({ Name = "Text size", Flag = "ammo_ind_size", Min = 10, Max = 32, Default = 16, Decimals = 1 })
    Ammo:Slider({ Name = "Vertical offset", Flag = "ammo_ind_y", Min = -300, Max = 300, Default = 70, Suffix = "px", Decimals = 1 })
    Ammo:Label({ Name = "Normal color" }):Colorpicker({ Name = "Normal", Flag = "ammo_ind_c_ok", Default = Color3.fromRGB(255, 255, 255) })
    Ammo:Label({ Name = "Empty color" }):Colorpicker({ Name = "Empty", Flag = "ammo_ind_c_empty", Default = Color3.fromRGB(255, 80, 80) })
    Ammo:Label({ Name = "Mismatch color" }):Colorpicker({ Name = "Mismatch", Flag = "ammo_ind_c_diff", Default = Color3.fromRGB(255, 200, 60) })

    local Indicator = WorldPage:Section({ Name = "Wallbang indicator", Side = 2 })
    Indicator:Toggle({ Name = "Wallbang indicator", Flag = "wb_ind", Default = false, Tooltip = "Tells you if an enemy is visible, wallbangable with the wallbang method you use now (a spot that can deal damage), or not wallbangable" })
    Indicator:Toggle({ Name = "Show on cursor", Flag = "wb_ind_cursor", Default = true })
    Indicator:Toggle({ Name = "Show on everyone", Flag = "wb_ind_all", Default = false })
    Indicator:Toggle({ Name = "Always visible", Flag = "wb_ind_always", Default = false, Tooltip = "Also shows a label when there is no enemy near the cursor" })
    Indicator:Slider({ Name = "Text size", Flag = "wb_ind_size", Min = 10, Max = 28, Default = 14, Decimals = 1 })
    Indicator:Slider({ Name = "Max distance", Flag = "wb_ind_range", Min = 50, Max = 3000, Default = 1000, Suffix = " studs", Decimals = 1 })
    Indicator:Label({ Name = "Visible color" }):Colorpicker({ Name = "Visible", Flag = "wb_ind_c_vis", Default = Color3.fromRGB(90, 255, 120) })
    Indicator:Label({ Name = "Wallbangable color" }):Colorpicker({ Name = "Wallbangable", Flag = "wb_ind_c_wb", Default = Color3.fromRGB(255, 200, 60) })
    Indicator:Label({ Name = "Blocked color" }):Colorpicker({ Name = "Blocked", Flag = "wb_ind_c_block", Default = Color3.fromRGB(255, 80, 80) })

    local AuraBox = WorldPage:Section({ Name = "Particle aura", Side = 1 })
    local auraToggle = AuraBox:Toggle({ Name = "Particle aura", Flag = "pa_enabled", Default = false })
    auraToggle:Colorpicker({ Name = "Color", Flag = "pa_color", Default = Color3.fromRGB(133, 220, 255), Alpha = 0.2 })
    AuraBox:Dropdown({ Name = "Aura", Flag = "pa_source", Items = AURA_PACK.items, Default = "angel" })
    AuraBox:Toggle({ Name = "Keep pack colors", Flag = "pa_pack_original", Default = true, Tooltip = "Pack auras keep their own colors. Turn off to paint them with the color above like the other auras." })

    local Avatar = WorldPage:Section({ Name = "Avatar changer", Side = 2 })
    Avatar:Toggle({ Name = "Avatar spoofer window", Flag = "spoof_ui", Default = false, Tooltip = "Opens a window to browse a player's current look and saved outfits" })
    Avatar:Input({ Name = "User", Flag = "spoof_avatar_user", Placeholder = "UserId, username or profile URL" })
    Avatar:Button({ Name = "Apply avatar", Callback = function()
        task.spawn(function() SpooferActions.apply() end)
    end })
    Avatar:Button({ Name = "Reset to my avatar", Callback = function()
        task.spawn(function() SpooferActions.reset() end)
    end })
    Avatar:Toggle({ Name = "Re-apply on respawn", Flag = "spoof_avatar_reapply", Default = true })
end

do

do
    local PlayerListSection = PlayersPage:Section({ Name = "Players", Side = 1 })
    local KickSection = PlayersPage:Section({ Name = "Kick exploit", Side = 1 })
    local PlayerOptions = PlayersPage:Section({ Name = "Player", Side = 2 })
    KickSection:Button({ Name = "Fling selected player", Callback = function() Actions.kickOnce() end })
    KickSection:Toggle({ Name = "Loop fling selected", Flag = "misc_kick_sel", Default = false })
    KickSection:Toggle({ Name = "Loop fling all", Flag = "misc_kick_all", Default = false })
    KickSection:Toggle({ Name = "Skip players inside the prison", Flag = "misc_kick_filter", Default = false })
    KickSection:Toggle({ Name = "Velocity protection", Flag = "misc_kick_velprot", Default = true })
    KickSection:Toggle({ Name = "Fling dropped body parts", Flag = "misc_kick_parts", Default = true, Tooltip = "When a player resets or dies, their body parts stay in the world. Those are flung too, one part after another." })
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

do
    local SettingsTab = LinoriaWindow:AddTab("Settings")

    local MenuGroup = SettingsTab:AddLeftGroupbox("Menu")
    MenuGroup:AddButton("Unload", function() Library:Unload() end)
    MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", { Default = "RightControl", NoUI = true, Text = "Menu keybind" })
    escapeUnbinds("MenuKeybind", "RightControl")
    MenuGroup:AddToggle("KeybindMenuOpen", {
        Default = Library.KeybindFrame.Visible,
        Text = "Show keybinds",
        Callback = function(value) Library.KeybindFrame.Visible = value end,
    })
    MenuGroup:AddDropdown("KeybindListMode", {
        Text = "Keybind list shows",
        Values = { "All", "Toggled", "Active" },
        Default = "All",
        Tooltip = "All: every keybind. Toggled: only keybinds whose feature is switched on. Active: only keybinds held or toggled right now.",
        Callback = function(value)
            pcall(function() Library:SetKeybindMode(value) end)
        end,
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

    do
        local BUTTONS = { MB3 = true, MB4 = true, MB5 = true }
        local SIDE_CODES = { MB4 = 0x05, MB5 = 0x06 }
        local env = getgenv()
        local keyFn = rawget(env, "iskeypressed") or rawget(env, "isKeyPressed")
        local activeFn = rawget(env, "isrbxactive") or rawget(env, "isRbxActive")

        local function rawSide(name)
            if not keyFn then return false end
            local ok, down = pcall(keyFn, SIDE_CODES[name])
            return ok and down == true
        end

        local sideNote = "iskeypressed is missing"
        local supported = false
        if keyFn then
            local ok, answer = pcall(keyFn, SIDE_CODES.MB4)
            supported = ok and type(answer) == "boolean"
            sideNote = ok and ("iskeypressed returned " .. typeof(answer)) or "iskeypressed errored"
        end

        local frameCache = { MB3 = false, MB4 = false, MB5 = false }
        local function buttonDown(name) return frameCache[name] == true end

        local hooked = setmetatable({}, { __mode = "k" })
        local function hook(picker)
            if hooked[picker] then return end
            hooked[picker] = { last = false }
            local original = picker.GetState
            picker.GetState = function(self)
                local key = self.Value
                if BUTTONS[key] then
                    if self.Mode == "Always" then return true end
                    if self.Mode == "Hold" then return buttonDown(key) end
                    return self.Toggled == true
                end
                return original(self)
            end
        end

        Library:GiveSignal(RunService.RenderStepped:Connect(function()
            local focused = true
            if activeFn then
                local ok, active = pcall(activeFn)
                focused = not ok or active ~= false
            end
            frameCache.MB3 = focused and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton3)
            if supported then
                frameCache.MB4 = focused and rawSide("MB4")
                frameCache.MB5 = focused and rawSide("MB5")
            end
            for _, entry in ipairs(keybindRegistry) do
                local picker = Options[entry.flag]
                if picker then
                    hook(picker)
                    local state = hooked[picker]
                    local key = picker.Value
                    if BUTTONS[key] then
                        local down = buttonDown(key)
                        if down ~= state.last then
                            state.last = down
                            if down and picker.Mode == "Toggle" then
                                picker.Toggled = not picker.Toggled
                                pcall(picker.DoClick, picker)
                            end
                            pcall(picker.Update, picker)
                        end
                    else
                        state.last = false
                    end
                end
            end
        end))

        Library.ButtonDown = buttonDown

        for _, entry in ipairs(keybindRegistry) do
            local picker = Options[entry.flag]
            if picker then hook(picker) end
        end
    end

    local BackgroundGroup = SettingsTab:AddLeftGroupbox("Background")
    if Library.AddBlurSlider then Library:AddBlurSlider(BackgroundGroup) end
    if Library.AddDarkenSlider then Library:AddDarkenSlider(BackgroundGroup) end
    if Library.AddKeybindTransparencySlider then Library:AddKeybindTransparencySlider(BackgroundGroup) end

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
    do
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

    local ESP_MAX_FPS = 140

    local function hiddenAsPeaceful(player)
        return getFlag("esp_hostile_only", false) and isPeaceful(player)
    end
    local function teamAllowed(player)
        if player ~= LocalPlayer and getFlag("esp_enemies_only", false) and not isEnemy(player) then return false end
        if player ~= LocalPlayer and hiddenAsPeaceful(player) then return false end
        return true
    end
    getgenv().TS_ESPFilter = teamAllowed

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

        put("Skeleton.Enabled", false)
        put("Skeleton.Gradient.Enabled", false)
        put("Skeleton.Outline", getFlag("esp_skeleton_outline", true))
        put("Skeleton.OutlineColor", getColor("esp_skeleton_outline_color", Color3.fromRGB(0, 0, 0)))
        put("Skeleton.Color", getColor("esp_skeleton_color", Color3.fromRGB(255, 255, 255)))

        put("Chams.Enabled", false)

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

    local customSkybox
    do
        local FACES = { "SkyboxUp", "SkyboxDn", "SkyboxFt", "SkyboxBk", "SkyboxLf", "SkyboxRt" }
        local assetCache = {}
        local built, builtText, seenText, seenSince, loading = nil, nil, nil, 0, false

        local function tell(message)
            pcall(function() Library:Notify(message, 4) end)
        end

        local function resolveAsset(id)
            if assetCache[id] then return assetCache[id] end
            local result
            local ok, objects = pcall(function() return game:GetObjects("rbxassetid://" .. id) end)
            if ok and type(objects) == "table" then
                for _, object in ipairs(objects) do
                    if object:IsA("Sky") then result = { sky = object } break end
                    local nested = object:FindFirstChildWhichIsA("Sky", true)
                    if nested then result = { sky = nested } break end
                    if object:IsA("Decal") or object:IsA("Texture") then result = { image = object.Texture } break end
                    if object:IsA("ImageLabel") or object:IsA("ImageButton") then result = { image = object.Image } break end
                end
            end
            result = result or { image = "rbxassetid://" .. id }
            assetCache[id] = result
            return result
        end

        local function build(text)
            local ids = {}
            for number in string.gmatch(text, "%d+") do table.insert(ids, number) end
            if #ids == 1 then
                local asset = resolveAsset(ids[1])
                local preset = {}
                if asset.sky then
                    for _, face in ipairs(FACES) do preset[face] = asset.sky[face] end
                    preset.StarCount = asset.sky.StarCount
                    preset.SunAngularSize = asset.sky.SunAngularSize
                    preset.MoonAngularSize = asset.sky.MoonAngularSize
                    preset.SunTextureId = asset.sky.SunTextureId
                    preset.MoonTextureId = asset.sky.MoonTextureId
                else
                    for _, face in ipairs(FACES) do preset[face] = asset.image end
                end
                return preset
            elseif #ids == 6 then
                local preset = {}
                for index, face in ipairs(FACES) do
                    local asset = resolveAsset(ids[index])
                    preset[face] = asset.image or (asset.sky and asset.sky.SkyboxFt) or ("rbxassetid://" .. ids[index])
                end
                return preset
            end
            return nil, #ids
        end

        customSkybox = function()
            local text = tostring(getFlag("skybox_custom_ids", ""))
            if text ~= seenText then
                seenText = text
                seenSince = os.clock()
            end
            if text ~= builtText and not loading and os.clock() - seenSince > 0.8 then
                if text:match("%S") == nil then
                    built, builtText = nil, text
                else
                    loading = true
                    local requested = text
                    task.spawn(function()
                        local ok, preset, count = pcall(build, requested)
                        builtText = requested
                        if ok and preset then
                            built = preset
                            tell("Custom skybox loaded")
                        else
                            built = nil
                            tell(ok and string.format("Custom skybox needs 1 or 6 ids, got %d", count or 0) or "Custom skybox failed to load")
                        end
                        loading = false
                    end)
                end
            end
            if builtText ~= text then return built end
            return built
        end
    end

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
        if preset.Custom then
            preset = customSkybox()
            if not preset then
                restoreOriginalSky()
                return
            end
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

        local glowOn = getFlag("esp_chams_adorn_glow", false)
        local glowSize = math.max(getFlag("esp_chams_adorn_glow_size", 1.75), 1)
        local roundHead = getFlag("esp_chams_adorn_round_head", true)
        local headScale = getFlag("esp_chams_adorn_head_size", 1.15)
        local playersOn = getFlag("esp_players", true)
        local localOn = getFlag("esp_local_player", false)

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

    local HIT_WINDOW = 0.8
    local lastHitNotify = 0
    hitConnections = {}
    pendingHits = {}

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
        if killed then
            for _, listener in ipairs(ShotEvents.kill) do pcall(listener, player, position) end
        end
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

        local result = workspace:Raycast(origin, offset.Unit * (offset.Magnitude + 1), params)
        local model = result and result.Instance:FindFirstAncestorOfClass("Model")
        local victim = model and Players:GetPlayerFromCharacter(model)
        if not victim then

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

    local FORCEFIELD = Enum.Material.ForceField
    local SCOPE_FOV = 30

    local function getAlpha(name)
        local object = Options[name]
        return object and tonumber(object.Transparency) or 0
    end

    local function textureIdFor(name)
        local id = FORCEFIELD_TEXTURES[name]
        if id and id ~= "" then return id end
        return nil
    end

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

    local function styleInstance(inst, cfg)
        if inst:IsA("BasePart") then
            local data = snapshot(inst)
            if (data.Transparency or 0) < 1 then
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
        elseif inst:IsA("Decal") then
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
            pcall(function() gunHighlight.Adornee = tool end)
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

    local function isBodyInstance(inst)
        return not inst:FindFirstAncestorOfClass("Tool") and not inst:FindFirstAncestorOfClass("Accessory")
    end

    local function bodyConfig()
        local forceOn = getFlag("arm_material", false)
        local disable = getFlag("arm_disable_textures", false)
        if not (forceOn or disable) then return nil end

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
            gui.DisplayOrder = 90
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
    local LIGHTNING_RADIUS_MIN = 20
    local LIGHTNING_GROUND_DROP = 40
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

            emitter.EmissionDirection = Enum.NormalId.Bottom
            if spec.Orientation then emitter.Orientation = spec.Orientation end
            emitter.Parent = weatherPart
            table.insert(weatherEmitters, { emitter = emitter, spec = spec })
        end
        weatherBuiltPreset = preset
        weatherSignature = nil
    end

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

    end)()

    ;(function()
        local HEADLESS_IDS = { [15093053680] = true, [134082579] = true, [4562128874] = true }
        local KORBLOX_LEFT, KORBLOX_RIGHT = 139607673, 139607718
        local lastUid, lastOutfit
        local busy = false
        local wornKeys = {}
        local currentDesc

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

            local needle = s:gsub("^@", "")
            local nlower = needle:lower()
            for _, p in ipairs(Players:GetPlayers()) do
                if p.Name:lower() == nlower or p.DisplayName:lower() == nlower then return p.UserId end
            end
            for _, p in ipairs(Players:GetPlayers()) do
                if p.Name:lower():sub(1, #nlower) == nlower or p.DisplayName:lower():sub(1, #nlower) == nlower then return p.UserId end
            end
            local ok, id = pcall(function() return Players:GetUserIdFromNameAsync(needle) end)
            if ok and typeof(id) == "number" and id > 0 then return math.floor(id) end

            local web = game:GetService("HttpService")
            local send = (syn and syn.request) or http_request or request
            if send then
                for _, host in ipairs({ "users.roproxy.com", "users.roblox.com" }) do
                    local okReq, reply = pcall(send, {
                        Url = "https://" .. host .. "/v1/usernames/users",
                        Method = "POST",
                        Headers = { ["Content-Type"] = "application/json" },
                        Body = web:JSONEncode({ usernames = { needle }, excludeBannedUsers = false }),
                    })
                    if okReq and type(reply) == "table" and type(reply.Body) == "string" then
                        local okJson, data = pcall(function() return web:JSONDecode(reply.Body) end)
                        local first = okJson and type(data) == "table" and type(data.data) == "table" and data.data[1]
                        if first and tonumber(first.id) then return math.floor(tonumber(first.id)) end
                    end
                end
                for _, host in ipairs({ "users.roproxy.com", "users.roblox.com" }) do
                    local okReq, reply = pcall(send, { Url = "https://" .. host .. "/v1/users/search?limit=10&keyword=" .. web:UrlEncode(needle), Method = "GET" })
                    if okReq and type(reply) == "table" and type(reply.Body) == "string" then
                        local okJson, data = pcall(function() return web:JSONDecode(reply.Body) end)
                        local list = okJson and type(data) == "table" and data.data
                        if type(list) == "table" and list[1] then
                            local pick = list[1]
                            for _, entry in ipairs(list) do
                                if type(entry.name) == "string" and entry.name:lower() == nlower then pick = entry break end
                            end
                            if tonumber(pick.id) then return math.floor(tonumber(pick.id)) end
                        end
                    end
                end
            end
            return nil
        end

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

        local modelCache, cacheOrder, inflight = {}, {}, {}
        local function cacheKey(uid, rigType, outfitId)
            return (outfitId and ("o" .. tostring(outfitId)) or ("u" .. tostring(uid))) .. ":" .. tostring(rigType)
        end

        local function rawFetchModel(uid, rigType, outfitId)
            local desc
            local described, result = pcall(function()
                if outfitId then return Players:GetHumanoidDescriptionFromOutfitId(outfitId) end
                return Players:GetHumanoidDescriptionFromUserIdAsync(uid)
            end)
            if described then desc = result end
            if described and desc and Players.CreateHumanoidModelFromDescription then
                local ok, built = pcall(function() return Players:CreateHumanoidModelFromDescription(desc, rigType) end)
                if ok and built then return built, desc end
            end
            if outfitId then return nil, desc end
            local ok, built = pcall(function() return Players:CreateHumanoidModelFromUserId(uid) end)
            if ok and built then return built, desc end
            ok, built = pcall(function() return Players:CreateHumanoidModelFromUserIdAsync(uid) end)
            if ok and built then return built, desc end
            return nil, desc
        end

        local function fetchModel(uid, rigType, outfitId)
            local key = cacheKey(uid, rigType, outfitId)
            local hit = modelCache[key]
            if not hit and inflight[key] then
                local started = os.clock()
                while inflight[key] and os.clock() - started < 25 do task.wait(0.05) end
                hit = modelCache[key]
            end
            if hit then
                local okClone, copy = pcall(function() return hit.model:Clone() end)
                if okClone and copy then return copy, hit.desc end
            end
            inflight[key] = true
            local okFetch, model, desc = pcall(rawFetchModel, uid, rigType, outfitId)
            inflight[key] = nil
            if not okFetch then return nil, nil end
            if model then
                local okClone, copy = pcall(function() return model:Clone() end)
                if okClone and copy then
                    modelCache[key] = { model = copy, desc = desc }
                    cacheOrder[#cacheOrder + 1] = key
                    while #cacheOrder > 8 do
                        local old = table.remove(cacheOrder, 1)
                        local entry = modelCache[old]
                        modelCache[old] = nil
                        if entry then pcall(function() entry.model:Destroy() end) end
                    end
                end
            end
            return model, desc
        end

        local function prefetchAvatar(uid, outfitId)
            local char = LocalPlayer.Character
            local humanoid = char and char:FindFirstChildOfClass("Humanoid")
            if not humanoid then return end
            local key = cacheKey(uid, humanoid.RigType, outfitId)
            if modelCache[key] or inflight[key] then return end
            task.spawn(function()
                local ok, model = pcall(fetchModel, uid, humanoid.RigType, outfitId)
                if ok and model then pcall(function() model:Destroy() end) end
            end)
        end

        local function applyAvatar(rawInput, outfitId)
            local char = LocalPlayer.Character
            local humanoid = char and char:FindFirstChildOfClass("Humanoid")
            if not humanoid then
                notify("Avatar changer: no character yet")
                return false
            end

            local raw = outfitId and "outfit" or tostring(rawInput or ""):gsub("^%s+", ""):gsub("%s+$", "")
            if raw == "" then
                notify("Avatar changer: type a UserId, username or profile URL first")
                return false
            end
            local uid = outfitId and 0 or resolveUserId(raw)
            if not uid then
                notify("Avatar changer: could not find user " .. raw)
                return false
            end

            stripAppearance(char)
            wornKeys = {}
            notify("Avatar changer: fetching " .. tostring(uid) .. "...")
            lastUid, lastOutfit = (not outfitId) and uid or nil, outfitId

            local model, desc = fetchModel(uid, humanoid.RigType, outfitId)
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

            stripAppearance(char)
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

        local function runApply(raw, outfitId)
            if busy then
                notify("Avatar changer: still working on the last one")
                return false
            end
            busy = true
            local ok, result = pcall(applyAvatar, raw, outfitId)
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
            if runApply(tostring(LocalPlayer.UserId)) then lastUid, lastOutfit = nil, nil end
        end

        local HttpService = game:GetService("HttpService")
        local UserInputService = game:GetService("UserInputService")
        local spoofUi
        local spoofSize = Vector2.new(600, 680)
        local SPOOF_MIN = Vector2.new(440, 500)

        local preferOriginal = false
        local function httpJson(url)
            local lastStatus, lastMessage
            local mirror = (string.gsub(url, "roblox%.com", "roproxy.com"))
            for _, candidate in ipairs(preferOriginal and { url, mirror } or { mirror, url }) do
                local body, status
                local send = (syn and syn.request) or http_request or request
                if send then
                    local okReq, reply = pcall(send, { Url = candidate, Method = "GET" })
                    if okReq and type(reply) == "table" then
                        if type(reply.Body) == "string" and reply.Body ~= "" then body = reply.Body end
                        status = tonumber(reply.StatusCode)
                    end
                end
                if not body then
                    local okGet, res = pcall(function() return game:HttpGet(candidate) end)
                    if okGet and type(res) == "string" and res ~= "" then
                        body = res
                    elseif not okGet then
                        status = status or tonumber(string.match(tostring(res), "(%d%d%d)"))
                        lastMessage = tostring(res)
                    end
                end

                if not body and status and status >= 400 and status < 500 then return nil, status, lastMessage end
                if body then
                    local okJson, data = pcall(function() return HttpService:JSONDecode(body) end)
                    if okJson and type(data) == "table" then
                        if candidate == url and not data.errors then preferOriginal = true end
                        if data.errors then
                            local first = data.errors[1]
                            lastStatus, lastMessage = status or 400, first and first.message or "error"

                            if lastStatus < 500 then return nil, lastStatus, lastMessage end
                        else
                            return data, status
                        end
                    end
                end
                lastStatus = status or lastStatus
            end
            return nil, lastStatus, lastMessage
        end

        local function httpJsonRetry(url, onWait, alive)
            local data, status, message
            for attempt = 1, 8 do
                data, status, message = httpJson(url)
                if data then return data, status end
                local limit = (status == 429) and 4 or 2
                local retryable = status == nil or status == 429 or status >= 500
                if not retryable or attempt >= limit or (alive and not alive()) then break end
                local seconds = (status == 429) and ({ 3, 6, 10 })[attempt] or 1.5
                if onWait then onWait(attempt, seconds) end
                task.wait(seconds)
                if alive and not alive() then break end
            end
            return nil, status, message
        end

        local function fetchOutfits(uid, onChunk, onWait, alive)
            local seen, list = {}, {}
            local function take(entries)
                local fresh = {}
                for _, entry in ipairs(entries or {}) do
                    if entry.id and not seen[entry.id] then
                        seen[entry.id] = true
                        local outfit = { id = entry.id, name = tostring(entry.name or entry.id) }
                        list[#list + 1] = outfit
                        fresh[#fresh + 1] = outfit
                    end
                end
                if #fresh > 0 and onChunk then onChunk(fresh, #list) end
                return #fresh
            end

            local failed, firstStatus, firstMessage = false, nil, nil
            local token
            local stopped
            for page = 1, 100 do
                local url = string.format("https://avatar.roblox.com/v2/avatar/users/%d/outfits?outfitType=1&page=1&itemsPerPage=50&isEditable=true", uid)
                if token then url = url .. "&paginationToken=" .. token end
                if page > 1 then task.wait(2) end
                local data, status, message = httpJsonRetry(url, onWait, alive)
                if not data then
                    if page == 1 then failed, firstStatus, firstMessage = true, status, message
                    else stopped = (status == 429) and "limited" or "error" end
                    break
                end
                local added = take(data.data)
                token = data.paginationToken or data.nextPageCursor or data.nextPageToken
                if type(token) ~= "string" or token == "" or added == 0 then break end
            end

            local source = "v2"
            if (failed and firstStatus ~= 429) or (not failed and #list == 0) then
                source = "v1"
                for page = 1, 40 do
                    if page > 1 then task.wait(2) end
                    local data, status, message = httpJsonRetry(string.format("https://avatar.roblox.com/v1/users/%d/outfits?page=%d&itemsPerPage=50&isEditable=true", uid, page), onWait, alive)
                    if not data then
                        if page == 1 and failed then firstStatus, firstMessage = firstStatus or status, firstMessage or message end
                        break
                    end
                    failed = false
                    local added = take(data.data)
                    if #(data.data or {}) < 50 or added == 0 then break end
                end
            end
            if failed and #list == 0 then
                local kind = "unreachable"
                if firstStatus == 401 or firstStatus == 403 or firstStatus == 400 or firstStatus == 404 then kind = "private" end
                if firstStatus == 429 then kind = "limited" end
                return nil, { kind = kind, status = firstStatus, message = firstMessage }
            end
            return list, { kind = #list > 0 and "public" or "empty", source = source, stopped = stopped }
        end

        local function inventoryVisible(uid, onWait, alive)
            local data = httpJsonRetry(string.format("https://inventory.roblox.com/v1/users/%d/can-view-inventory", uid), onWait, alive)
            if data and type(data.canView) == "boolean" then return data.canView end
            return nil
        end

        local INDICATOR_COLORS = {
            public = Color3.fromRGB(90, 200, 110), empty = Color3.fromRGB(230, 190, 70), private = Color3.fromRGB(225, 85, 85),
            limited = Color3.fromRGB(230, 150, 60), unreachable = Color3.fromRGB(150, 150, 150), checking = Color3.fromRGB(150, 150, 150),
        }

        local function setIndicator(kind, text)
            local ui = spoofUi
            if not ui or not ui.indicator then return end
            ui.indicator.Text = "● " .. text
            ui.indicator.TextColor3 = INDICATOR_COLORS[kind] or INDICATOR_COLORS.unreachable
        end

        local function closeSpoofUi()
            if spoofUi then
                pcall(function() spoofUi.main:Destroy() end)
                spoofUi = nil
            end
        end

        local function mk(class, props)
            props.ZIndex = props.ZIndex or 301
            if class == "TextLabel" or class == "TextButton" or class == "TextBox" then
                props.Font = props.Font or Library.Font
                props.TextSize = props.TextSize or Library.FontSize
                props.TextColor3 = props.TextColor3 or Library.FontColor
            end
            if props.BorderColor3 == nil and class ~= "ImageLabel" and class ~= "ScrollingFrame" then props.BorderColor3 = Library.OutlineColor end
            local bgName = props.ThemeBg
            props.ThemeBg = nil
            local inst = Library:Create(class, props)

            local map
            for prop, names in pairs({ BackgroundColor3 = { "MainColor", "BackgroundColor", "AccentColor" }, BorderColor3 = { "OutlineColor", "AccentColor" }, TextColor3 = { "FontColor", "AccentColor" } }) do
                local value = props[prop]
                if value ~= nil then
                    for _, colorName in ipairs(names) do
                        if Library[colorName] == value then map = map or {} map[prop] = colorName break end
                    end
                end
            end
            if bgName then map = map or {} map.BackgroundColor3 = bgName end
            if class == "TextLabel" or class == "TextButton" or class == "TextBox" then map = map or {} map.Font = "Font" end
            if class == "ScrollingFrame" then map = map or {} map.ScrollBarImageColor3 = "AccentColor" end
            if map then pcall(function() Library:AddToRegistry(inst, map) end) end
            return inst
        end

        local function userThumb(uid)
            local ok, content = pcall(function()
                return Players:GetUserThumbnailAsync(uid, Enum.ThumbnailType.AvatarBust, Enum.ThumbnailSize.Size150x150)
            end)
            if ok and type(content) == "string" and content ~= "" then return content end
            return string.format("rbxthumb://type=Avatar&id=%d&w=150&h=150", uid)
        end

        local TextService = game:GetService("TextService")

        local function lf(class, props, reg)
            local inst = Library:Create(class, props)
            if reg then Library:AddToRegistry(inst, reg) end
            return inst
        end

        local function lbl(props)
            props.ZIndex = props.ZIndex or 309
            return Library:CreateLabel(props)
        end

        local function bevel(parent, z, size, position, order)
            local outer = lf("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BorderColor3 = Color3.new(0, 0, 0), Size = size, Position = position or UDim2.new(), LayoutOrder = order or 0, ZIndex = z, Parent = parent }, { BorderColor3 = "Black" })
            local inner = lf("Frame", { BackgroundColor3 = Library.MainColor, BorderColor3 = Library.OutlineColor, BorderMode = Enum.BorderMode.Inset, Size = UDim2.new(1, 0, 1, 0), ZIndex = z + 1, Parent = outer }, { BackgroundColor3 = "MainColor", BorderColor3 = "OutlineColor" })
            Library:Create("UIGradient", {
                Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212)) }),
                Rotation = 90,
                Parent = inner,
            })
            return outer, inner
        end

        local function panel(parent, name, position, size, z)
            local boxOuter = lf("Frame", { BackgroundColor3 = Library.BackgroundColor, BorderColor3 = Library.OutlineColor, BorderMode = Enum.BorderMode.Inset, Position = position, Size = size, ZIndex = z, Parent = parent }, { BackgroundColor3 = "BackgroundColor", BorderColor3 = "OutlineColor" })
            local boxInner = lf("Frame", { BackgroundColor3 = Library.BackgroundColor, BorderColor3 = Color3.new(0, 0, 0), Position = UDim2.new(0, 1, 0, 1), Size = UDim2.new(1, -2, 1, -2), ZIndex = z + 1, Parent = boxOuter }, { BackgroundColor3 = "BackgroundColor" })
            lf("Frame", { BackgroundColor3 = Library.AccentColor, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 2), ZIndex = z + 2, Parent = boxInner }, { BackgroundColor3 = "AccentColor" })
            lbl({ Size = UDim2.new(1, 0, 0, 18), Position = UDim2.new(0, 0, 0, 2), TextSize = Library.FontSize, Text = name, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = z + 2, Parent = boxInner })
            return boxOuter, boxInner
        end

        local function setBorder(item, colorName)
            if not (item and item.Parent) then return end
            item.BorderColor3 = Library[colorName]
            local entry = Library.RegistryMap and Library.RegistryMap[item]
            if entry then entry.Properties.BorderColor3 = colorName end
        end

        local function selectTile(info, tile)
            local ui = spoofUi
            if not ui then return end
            setBorder(ui.selectedTile, "Black")
            ui.selected, ui.selectedTile = info, tile
            setBorder(tile, "AccentColor")
            ui.status.Text = info and ("Selected: " .. info.name .. (info.kind == "outfit" and "  (outfit)" or "  (current look)")) or "Nothing selected"
        end

        local function addTile(info, image, order)
            local ui = spoofUi
            if not ui then return end
            local tile, face = bevel(ui.grid, 307, UDim2.fromOffset(98, 104), nil, order)
            if image then
                local picture = mk("ImageLabel", { BackgroundTransparency = 1, Image = "", ScaleType = Enum.ScaleType.Fit, Size = UDim2.new(1, -8, 1, -28), Position = UDim2.fromOffset(4, 4), ZIndex = 310, Parent = face })
                ui.lazy[tile] = { label = picture, image = image }
            else
                lbl({ Text = "?", TextSize = 34, Size = UDim2.new(1, 0, 1, -22), ZIndex = 310, Parent = face })
            end
            lbl({ Text = info.name, TextSize = 11, TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.new(1, -6, 0, 20), Position = UDim2.new(0, 3, 1, -22), ZIndex = 310, Parent = face })
            local hit = lf("TextButton", { BackgroundTransparency = 1, Text = "", Size = UDim2.new(1, 0, 1, 0), ZIndex = 313, Parent = tile })
            hit.MouseEnter:Connect(function() if spoofUi and spoofUi.selectedTile ~= tile then setBorder(tile, "AccentColor") end end)
            hit.MouseLeave:Connect(function() if spoofUi and spoofUi.selectedTile ~= tile then setBorder(tile, "Black") end end)
            if info.kind == "random" then
                hit.MouseButton1Click:Connect(function()
                    local pool = ui.pool
                    if #pool == 0 then return end
                    local pick = pool[math.random(1, #pool)]
                    selectTile(pick.info, pick.tile)
                end)
            else
                table.insert(ui.pool, { info = info, tile = tile })
                hit.MouseButton1Click:Connect(function()
                    selectTile(info, tile)
                    if SpooferActions.prefetch then
                        if info.kind == "outfit" then SpooferActions.prefetch(nil, info.id) else SpooferActions.prefetch(info.uid) end
                    end
                    local now = os.clock()
                    if ui.lastClick and ui.lastClick.tile == tile and now - ui.lastClick.at < 0.5 then
                        task.spawn(function()
                            if info.kind == "outfit" then SpooferActions.applyOutfit(info.id) else SpooferActions.applyUser(info.uid) end
                        end)
                    end
                    ui.lastClick = { tile = tile, at = now }
                end)
            end
            return tile
        end

        local function loadTarget(uid, name)
            local ui = spoofUi
            if not ui or not uid then return end
            ui.token += 1
            local token = ui.token
            ui.target = { uid = uid, name = name }
            for _, child in ipairs(ui.grid:GetChildren()) do
                if child:IsA("Frame") or child:IsA("TextLabel") then child:Destroy() end
            end
            ui.pool, ui.selected, ui.selectedTile = {}, nil, nil
            ui.status.Text = "Showing " .. name
            setIndicator("checking", "checking outfits...")
            local thumb = function(kind, id) return string.format("rbxthumb://type=%s&id=%d&w=150&h=150", kind, id) end
            local userTile = addTile({ kind = "user", uid = uid, name = name .. " (now)" }, thumb("Avatar", uid), 1)
            task.spawn(function()
                task.wait(3)
                local label = userTile and userTile:FindFirstChildWhichIsA("ImageLabel", true)
                if not label or not spoofUi or spoofUi.token ~= token or label.IsLoaded then return end
                local image = userThumb(uid)
                if label.Parent and spoofUi and spoofUi.token == token then label.Image = image end
            end)
            addTile({ kind = "random", name = "Random" }, nil, 2)
            local loading = mk("TextLabel", { BackgroundTransparency = 1, Text = "Loading outfits...", TextSize = 12, LayoutOrder = 3, Size = UDim2.fromOffset(100, 104), ZIndex = 309, Parent = ui.grid })
            task.spawn(function()
                local shown = 0
                local outfits, info = fetchOutfits(uid, function(fresh, total)
                    if not spoofUi or spoofUi.token ~= token then return end
                    pcall(function() loading:Destroy() end)
                    for _, outfit in ipairs(fresh) do
                        if shown >= 600 then break end
                        shown += 1
                        addTile({ kind = "outfit", id = outfit.id, name = outfit.name }, thumb("Outfit", outfit.id), 10 + shown)
                    end
                    setIndicator("public", string.format("outfits PUBLIC (%d, loading...)", total))
                end, function(attempt, seconds)
                    if spoofUi and spoofUi.token == token then
                        setIndicator("limited", string.format("rate limited, retrying (%d) in %.1fs...", attempt, seconds))
                    end
                end, function() return spoofUi ~= nil and spoofUi.token == token end)
                local inventory = inventoryVisible(uid, nil, function() return spoofUi ~= nil and spoofUi.token == token end)
                if not spoofUi or spoofUi.token ~= token then return end
                pcall(function() loading:Destroy() end)
                local inventoryText = inventory == nil and "" or (inventory and "   inventory public" or "   inventory private")
                if not outfits then
                    local texts = { private = "outfits PRIVATE (HTTP " .. tostring(info.status) .. ")", limited = "rate limited, try again in a moment", unreachable = "outfits unreachable (no HTTP answer)" }
                    setIndicator(info.kind, (texts[info.kind] or "outfits unavailable") .. inventoryText)
                    if info.message then warn("Avatar spoofer: outfits request failed:", info.status, info.message) end
                    mk("TextLabel", { BackgroundTransparency = 1, Text = info.kind == "private" and "Outfits are private" or "Outfits unavailable", TextSize = 12, TextWrapped = true, LayoutOrder = 3, Size = UDim2.fromOffset(100, 104), ZIndex = 309, Parent = ui.grid })
                    return
                end
                if #outfits == 0 then

                    if inventory == false then
                        setIndicator("private", "outfits PRIVATE (inventory hidden)")
                        mk("TextLabel", { BackgroundTransparency = 1, Text = "Outfits are private", TextSize = 12, TextWrapped = true, LayoutOrder = 3, Size = UDim2.fromOffset(100, 104), ZIndex = 309, Parent = ui.grid })
                    else
                        setIndicator("empty", "no saved outfits" .. inventoryText)
                        mk("TextLabel", { BackgroundTransparency = 1, Text = "No saved outfits", TextSize = 12, TextWrapped = true, LayoutOrder = 3, Size = UDim2.fromOffset(100, 104), ZIndex = 309, Parent = ui.grid })
                    end
                    return
                end
                if info.stopped == "limited" then
                    setIndicator("limited", string.format("limited (%d loaded), select the player again to retry", #outfits) .. inventoryText)
                elseif info.stopped then
                    setIndicator("limited", string.format("outfits PUBLIC (%d loaded, a page failed)", #outfits) .. inventoryText)
                else
                    setIndicator("public", string.format("outfits PUBLIC (%d, %s)", #outfits, tostring(info.source)) .. inventoryText)
                end
            end)
        end

        local function refreshChips()
            local ui = spoofUi
            if not ui then return end
            for _, child in ipairs(ui.chips:GetChildren()) do
                if child:IsA("Frame") then child:Destroy() end
            end
            local query = string.lower(ui.search.Text or "")
            local function chip(text, uid, order)
                local width = TextService:GetTextSize(text, Library.FontSize, Library.Font, Vector2.new(1000, 20)).X + 18
                local outer, face = bevel(ui.chips, 308, UDim2.fromOffset(width, 20), nil, order)
                lbl({ Size = UDim2.new(1, 0, 1, 0), TextSize = Library.FontSize, Text = text, ZIndex = 310, Parent = face })
                local hit = lf("TextButton", { BackgroundTransparency = 1, Text = "", Size = UDim2.new(1, 0, 1, 0), ZIndex = 313, Parent = outer })
                Library:OnHighlight(hit, outer, { BorderColor3 = "AccentColor" }, { BorderColor3 = "Black" })
                hit.MouseButton1Click:Connect(function() loadTarget(uid, text) end)
            end
            chip("You", LocalPlayer.UserId, 0)
            local shown = 0
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and shown < 24
                    and (query == "" or string.find(string.lower(player.Name), query, 1, true) or string.find(string.lower(player.DisplayName), query, 1, true)) then
                    shown += 1
                    chip(player.DisplayName, player.UserId, shown)
                end
            end
        end

        local function openSpoofUi()
            if spoofUi or not Library.ScreenGui then return end
            local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
            local startSize = Vector2.new(math.clamp(spoofSize.X, SPOOF_MIN.X, math.max(SPOOF_MIN.X, viewport.X - 20)), math.clamp(spoofSize.Y, SPOOF_MIN.Y, math.max(SPOOF_MIN.Y, viewport.Y - 20)))
            local main = lf("Frame", { Name = "AsterAvatarSpoofer", BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Size = UDim2.fromOffset(startSize.X, startSize.Y), Position = UDim2.new(0.5, -startSize.X / 2, 0.5, -startSize.Y / 2), ZIndex = 300, Parent = Library.ScreenGui })
            local frame = lf("Frame", { BackgroundColor3 = Library.MainColor, BorderColor3 = Library.OutlineColor, BorderMode = Enum.BorderMode.Inset, Position = UDim2.new(0, 1, 0, 1), Size = UDim2.new(1, -2, 1, -2), ZIndex = 301, Parent = main }, { BackgroundColor3 = "MainColor", BorderColor3 = "OutlineColor" })
            lbl({ Size = UDim2.new(1, 0, 0, 25), Text = "Avatar Spoofer", TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 302, Parent = frame })
            local section = lf("Frame", { BackgroundColor3 = Library.BackgroundColor, BorderColor3 = Library.OutlineColor, Position = UDim2.new(0, 8, 0, 25), Size = UDim2.new(1, -16, 1, -33), ZIndex = 302, Parent = frame }, { BackgroundColor3 = "BackgroundColor", BorderColor3 = "OutlineColor" })
            local body = lf("Frame", { BackgroundColor3 = Library.BackgroundColor, BorderColor3 = Color3.new(0, 0, 0), BorderMode = Enum.BorderMode.Inset, Size = UDim2.new(1, 0, 1, 0), ZIndex = 303, Parent = section }, { BackgroundColor3 = "BackgroundColor" })

            local _, playerBox = panel(body, "Player", UDim2.fromOffset(8, 8), UDim2.new(1, -16, 0, 84), 304)
            local searchOuter, searchFace = bevel(playerBox, 307, UDim2.new(1, -12, 0, 20), UDim2.fromOffset(6, 22))
            local clip = lf("Frame", { BackgroundTransparency = 1, ClipsDescendants = true, Position = UDim2.new(0, 5, 0, 0), Size = UDim2.new(1, -5, 1, 0), ZIndex = 309, Parent = searchFace })
            local search = lf("TextBox", {
                BackgroundTransparency = 1,
                Position = UDim2.fromOffset(0, 0),
                Size = UDim2.fromScale(5, 1),
                Font = Library.Font,
                PlaceholderColor3 = Color3.fromRGB(190, 190, 190),
                PlaceholderText = "username, UserId, profile URL or outfit:ID, press Enter...",
                ClearTextOnFocus = false,
                Text = "",
                TextColor3 = Library.FontColor,
                TextSize = Library.FontSize,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 310,
                Parent = clip,
            }, { TextColor3 = "FontColor" })
            Library:ApplyTextStroke(search)
            Library:OnHighlight(search, searchOuter, { BorderColor3 = "AccentColor" }, { BorderColor3 = "Black" })
            local chips = lf("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(6, 48), Size = UDim2.new(1, -12, 0, 30), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.X, ScrollBarThickness = 3, ScrollBarImageColor3 = Library.AccentColor, ScrollingDirection = Enum.ScrollingDirection.X, ZIndex = 307, Parent = playerBox }, { ScrollBarImageColor3 = "AccentColor" })
            Library:Create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = chips })
            Library:Create("UIPadding", { PaddingTop = UDim.new(0, 1), PaddingLeft = UDim.new(0, 1), Parent = chips })

            local _, previewBox = panel(body, "Preview", UDim2.fromOffset(8, 98), UDim2.new(1, -16, 1, -174), 304)
            lbl({ Text = "click again to apply", TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, TextSize = 12, Size = UDim2.new(0.38, -8, 0, 14), Position = UDim2.fromOffset(6, 21), ZIndex = 307, Parent = previewBox })
            local indicator = Library:Create("TextLabel", { BackgroundTransparency = 1, Font = Library.Font, Text = "", TextSize = 12, TextColor3 = Library.FontColor, TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.new(0.62, -10, 0, 14), Position = UDim2.new(0.38, 0, 0, 21), ZIndex = 307, Parent = previewBox })
            Library:ApplyTextStroke(indicator)
            local grid = lf("ScrollingFrame", { BackgroundColor3 = Library.MainColor, BorderColor3 = Library.OutlineColor, Position = UDim2.fromOffset(4, 38), Size = UDim2.new(1, -8, 1, -42), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3, ScrollBarImageColor3 = Library.AccentColor, ZIndex = 307, Parent = previewBox }, { BackgroundColor3 = "MainColor", BorderColor3 = "OutlineColor", ScrollBarImageColor3 = "AccentColor" })
            Library:Create("UIGridLayout", { CellSize = UDim2.fromOffset(98, 104), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
            Library:Create("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), Parent = grid })

            local status = lbl({ Text = "", TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, TextSize = 12, Size = UDim2.new(1, -16, 0, 16), Position = UDim2.new(0, 8, 1, -72), ZIndex = 307, Parent = body })
            local function button(text, position, size, callback)
                local outer, face = bevel(body, 307, size, position)
                lbl({ Size = UDim2.new(1, 0, 1, 0), TextSize = Library.FontSize, Text = text, ZIndex = 309, Parent = face })
                local hit = lf("TextButton", { BackgroundTransparency = 1, Text = "", Size = UDim2.new(1, 0, 1, 0), ZIndex = 313, Parent = outer })
                Library:OnHighlight(hit, outer, { BorderColor3 = "AccentColor" }, { BorderColor3 = "Black" })
                hit.MouseButton1Click:Connect(callback)
                return outer
            end
            button("Apply selected", UDim2.new(0, 8, 1, -54), UDim2.new(1, -16, 0, 20), function()
                local ui = spoofUi
                local info = ui and ui.selected
                if not info then notify("Avatar spoofer: pick an avatar first") return end
                task.spawn(function()
                    if info.kind == "outfit" then SpooferActions.applyOutfit(info.id) else SpooferActions.applyUser(info.uid) end
                end)
            end)
            button("Reset to my avatar", UDim2.new(0, 8, 1, -30), UDim2.new(0.5, -12, 0, 20), function() task.spawn(function() SpooferActions.reset() end) end)
            button("Close", UDim2.new(0.5, 4, 1, -30), UDim2.new(0.5, -12, 0, 20), function()
                local toggle = Toggles and Toggles.spoof_ui
                if toggle and toggle.SetValue then pcall(function() toggle:SetValue(false) end) end
                closeSpoofUi()
            end)

            local grip = lbl({ Text = "//", TextSize = 12, Size = UDim2.fromOffset(16, 16), Position = UDim2.new(1, -16, 1, -16), ZIndex = 330, Parent = main })
            local gripHit = lf("TextButton", { BackgroundTransparency = 1, Text = "", Size = UDim2.new(1, 0, 1, 0), ZIndex = 331, Parent = grip })
            gripHit.InputBegan:Connect(function(input)
                if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
                local from, origin = main.AbsoluteSize, input.Position
                local move, finish
                move = UserInputService.InputChanged:Connect(function(change)
                    if change.UserInputType ~= Enum.UserInputType.MouseMovement and change.UserInputType ~= Enum.UserInputType.Touch then return end
                    local cam = workspace.CurrentCamera
                    local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
                    local w = math.clamp(from.X + (change.Position.X - origin.X), SPOOF_MIN.X, math.max(SPOOF_MIN.X, vp.X - 20))
                    local h = math.clamp(from.Y + (change.Position.Y - origin.Y), SPOOF_MIN.Y, math.max(SPOOF_MIN.Y, vp.Y - 20))
                    main.Size = UDim2.fromOffset(w, h)
                    spoofSize = Vector2.new(w, h)
                end)
                finish = UserInputService.InputEnded:Connect(function(ended)
                    if ended.UserInputType == Enum.UserInputType.MouseButton1 or ended.UserInputType == Enum.UserInputType.Touch then
                        move:Disconnect()
                        finish:Disconnect()
                    end
                end)
            end)

            spoofUi = { main = main, grid = grid, chips = chips, search = search, status = status, indicator = indicator, pool = {}, lazy = {}, token = 0 }
            local owner = spoofUi
            task.spawn(function()
                while spoofUi == owner do
                    local top = grid.AbsolutePosition.Y
                    local bottom = top + grid.AbsoluteSize.Y
                    local budget = 24
                    for tile, entry in pairs(owner.lazy) do
                        if not tile.Parent then
                            owner.lazy[tile] = nil
                        else
                            local y = tile.AbsolutePosition.Y
                            if y + 104 >= top - 110 and y <= bottom + 110 then
                                entry.label.Image = entry.image
                                owner.lazy[tile] = nil
                                budget -= 1
                                if budget <= 0 then break end
                            end
                        end
                    end
                    task.wait(0.2)
                end
            end)
            Library:MakeDraggable(main, 25)
            search:GetPropertyChangedSignal("Text"):Connect(refreshChips)
            search.FocusLost:Connect(function(enter)
                if not enter then return end
                local text = search.Text
                local outfitId = tonumber(string.match(text, "[Oo]utfits?[:%s/=]*(%d+)"))
                if outfitId then

                    local info = { kind = "outfit", id = outfitId, name = "Outfit " .. outfitId }
                    local tile = addTile(info, string.format("rbxthumb://type=Outfit&id=%d&w=150&h=150", outfitId), 5)
                    selectTile(info, tile)
                    return
                end
                task.spawn(function()
                    local uid = resolveUserId(text)
                    if not uid then notify("Avatar spoofer: could not find " .. tostring(text)) return end
                    loadTarget(uid, text ~= "" and text or tostring(uid))
                end)
            end)
            refreshChips()
            loadTarget(LocalPlayer.UserId, "You")
        end

        track(RunService.Heartbeat:Connect(function()
            local wanted = getFlag("spoof_ui", false)
            if wanted and not spoofUi then
                local ok, err = pcall(openSpoofUi)
                if not ok then warn("Avatar spoofer window failed:", err) closeSpoofUi() end
            elseif not wanted and spoofUi then
                closeSpoofUi()
            end

            if spoofUi then
                local show = Library.Toggled ~= false
                if spoofUi.main.Visible ~= show then spoofUi.main.Visible = show end
            end
        end))
        track(Players.PlayerAdded:Connect(function() if spoofUi then refreshChips() end end))
        track(Players.PlayerRemoving:Connect(function() if spoofUi then task.defer(refreshChips) end end))

        SpooferActions.prefetch = function(uid, outfitId) prefetchAvatar(uid, outfitId) end
        SpooferActions.applyUser = function(uid) return runApply(uid) end
        SpooferActions.applyOutfit = function(outfitId) return runApply(nil, outfitId) end

        track(LocalPlayer.CharacterAdded:Connect(function()
            if not (lastUid or lastOutfit) or not getFlag("spoof_avatar_reapply", true) then return end
            task.delay(1.25, function()
                if (lastUid or lastOutfit) and getFlag("spoof_avatar_reapply", true) then runApply(lastUid, lastOutfit) end
            end)
        end))

        onUnload(function()
            SpooferActions.apply, SpooferActions.reset = noop, noop
            SpooferActions.applyUser, SpooferActions.applyOutfit = noop, noop
            SpooferActions.prefetch = noop
            for _, entry in pairs(modelCache) do pcall(function() entry.model:Destroy() end) end
            table.clear(modelCache)
            closeSpoofUi()
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

    local arrestUntil = 0
    do

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
                        arrestUntil = clock() + 0.4
                    elseif not warned then
                        warned = true
                        say("Auto arrest needs the Handcuffs tool")
                    end
                    return
                end

                local target = best
                arrestUntil = clock() + 0.5
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

        local bag, acc, cooldown, busy = newBag(), 0, 0, false
        local rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        rayParams.RespectCanCollide = true

        local function visible(fromPos, e, myChar)
            rayParams.FilterDescendantsInstances = { myChar, e.Character }
            return workspace:Raycast(fromPos, e.Head.Position - fromPos, rayParams) == nil
        end

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
                        Actions.fireAt(target.Head, target.Head.Position)
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

    do
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

    do
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

    do
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

    do
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

    do
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

    do
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

    ;(function()
        local Workspace = workspace

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

        local BURSTS = { "Mutants Rage", "Armageddon", "Solar Flare", "Heaven", "Gravity God", "Red Ring of Death", "Blue Heat", "Stardust Fragment", "Fiery Ritual of Hallownest", "Midnight Blues", "Susanoo Arms", "Atomic", "Kurama" }
        local function packBurst(label, position)
            local entry = AURA_PACK.rigs[label]
            local get = Actions.packRig
            if not entry or not get then return end
            local life = HE_duration
            task.spawn(function()
                local rig = get(entry)
                if not rig then return end
                local holder = Instance.new("Part")
                holder.Name = "AsterBurst"
                holder.Anchored, holder.CanCollide, holder.CanQuery, holder.CanTouch = true, false, false, false
                holder.Transparency, holder.Size, holder.CFrame = 1, Vector3.new(1, 1, 1), CFrame.new(position)
                holder.Parent = workspace
                game:GetService("Debris"):AddItem(holder, life + 4)
                local used = 0
                for _, d in ipairs(rig:GetDescendants()) do
                    if d:IsA("ParticleEmitter") and used < 40 then
                        used += 1
                        local copy = d:Clone()
                        copy.Enabled = false
                        copy.Parent = holder
                        local count = d:GetAttribute("EmitCount") or math.clamp(math.ceil(d.Rate * d.Lifetime.Max * 0.5), 3, 14)
                        pcall(copy.Emit, copy, count)
                    end
                end
            end)
        end
        for _, label in ipairs(BURSTS) do
            HitEffects.Presets["burst: " .. string.lower(label)] = function(position) packBurst(label, position) end
        end

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

    ;(function()
        local Debris = game:GetService("Debris")
        local KILL_FX = {
        	["Scorch"] = {{"ParticleEmitter","Fire",{["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["Texture"]="rbxassetid://9146054025",["Size"]={"NS",{{0,1,0},{1,1,0}}},["Color"]={"CS",{{0,1,0.17255,0.0078431},{1,1,0.17255,0.0078431}}},["Speed"]={"NR",0,2},["ZOffset"]=2,["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Rotation"]={"NR",0,70},["Transparency"]={"NS",{{0,0,0},{1,0,0}}},["VelocitySpread"]=45,["Lifetime"]={"NR",0.5,1},["LightEmission"]=1,["Acceleration"]={"V3",0,4,0},["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["SpreadAngle"]={"V2",45,-45}}}},
        	["Darkheart"] = {{"ParticleEmitter","BackAura",{["Color"]={"CS",{{0,0.38039,0.0078431,0.54118},{1,0.70588,0.019608,1}}},["ZOffset"]=-2,["VelocitySpread"]=180,["Lifetime"]={"NR",1,1},["Speed"]={"NR",0.1,0.1},["Brightness"]=0.66,["SpreadAngle"]={"V2",180,-180},["RotSpeed"]={"NR",0,100},["LockedToPart"]=true,["Rate"]=6,["EmissionDirection"]={"E","NormalId","Front"},["Rotation"]={"NR",-180,180},["Transparency"]={"NS",{{0,1,0},{0.088957,0.24375,0},{0.28834,0.425,0},{0.43558,0.61875,0},{0.6273,0.8,0},{0.84663,0.94375,0},{1,1,0}}},["Texture"]="rbxassetid://8114032502",["VelocityInheritance"]=1,["LightEmission"]=1,["Size"]={"NS",{{0,0,0},{0.33696,1.9811,1.6332},{0.6594,4.2453,1.5824},{0.85258,5.283,1.2746},{1,7.0126,0}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"}}},{"ParticleEmitter","DarkAura",{["Color"]={"CS",{{0,0.1098,0,0.16471},{1,0.1098,0,0.16471}}},["ZOffset"]=-1,["VelocitySpread"]=180,["Lifetime"]={"NR",1,1},["Speed"]={"NR",0.1,0.1},["Brightness"]=0.66,["SpreadAngle"]={"V2",180,-180},["RotSpeed"]={"NR",-100,0},["LockedToPart"]=true,["Rate"]=6,["EmissionDirection"]={"E","NormalId","Front"},["Rotation"]={"NR",-180,180},["Transparency"]={"NS",{{0,1,0},{0.053681,0.30625,0},{0.28834,0.425,0},{0.43558,0.61875,0},{0.6273,0.8,0},{0.84663,0.94375,0},{1,1,0}}},["Texture"]="rbxassetid://8114032502",["VelocityInheritance"]=1,["LightEmission"]=0.5,["Size"]={"NS",{{0,0,0},{0.19535,2.2013,1.6332},{0.6594,4.2453,1.5824},{0.85258,5.283,1.2746},{1,7.0126,0}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"}}},{"ParticleEmitter","PurpleAura",{["Color"]={"CS",{{0,0.48235,0.12157,0.63529},{1,0.48235,0.12157,0.63529}}},["LockedToPart"]=true,["Rate"]=6,["VelocitySpread"]=-360,["Transparency"]={"NS",{{0,1,0},{0.2,0,0},{1,1,0}}},["Texture"]="rbxasset://textures/particles/smoke_main.dds",["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Speed"]={"NR",2,2},["Size"]={"NS",{{0,1.6,0},{0.23243,2,0},{0.5068,2.8125,0},{0.79365,4.0625,0},{1,5.125,0}}},["Lifetime"]={"NR",1,2},["SpreadAngle"]={"V2",-360,360}}}},
        	["Cyberspace"] = {{"Part","Particle",{["CFrame"]={"CF",0,0,0,1,0,0,0,1,0,0,0,1},["Size"]={"V3",2,2,1}},nil,nil,{{"Attachment","charge",{},nil,nil,{{"ParticleEmitter","flare",{["Texture"]="rbxassetid://11368066405",["Rate"]=25,["Size"]={"NS",{{0,0,0},{0.29551,1.375,0.0625},{0.7606,0.375,0.01969},{1,0,0}}},["Squash"]={"NS",{{0,0,0},{1,-0.0375,0}}},["Color"]={"CS",{{0,1,0.26274,0.26274},{1,1,0.26274,0.26274}}},["Drag"]=6,["ZOffset"]=3,["Speed"]={"NR",10,22},["VelocitySpread"]=360,["Transparency"]={"NS",{{0,0,0},{0.071072,0.075,0},{0.18953,0.825,0},{0.30673,0.1125,0},{0.44015,0.13125,0},{0.58479,0.8625,0},{0.78928,0.10625,0},{1,0,0}}},["Lifetime"]={"NR",0.35,0.5},["LightEmission"]=1,["Brightness"]=5.395,["SpreadAngle"]={"V2",360,-360}},{["EmitCount"]=5,["EmitDelay"]=0}},{"ParticleEmitter","spec",{["Color"]={"CS",{{0,1,0.17255,0.17255},{1,1,0.17255,0.17255}}},["Drag"]=6,["ZOffset"]=1,["VelocitySpread"]=360,["Lifetime"]={"NR",0.65,2.35},["Speed"]={"NR",7,20},["Brightness"]=6.475,["SpreadAngle"]={"V2",360,-360},["RotSpeed"]={"NR",300,600},["Rate"]=35,["Transparency"]={"NS",{{0,0,0},{1,0,0}}},["LightEmission"]=1,["Texture"]="rbxassetid://11448304274",["Size"]={"NS",{{0,0,0},{0.30201,0.12,0.0625},{1,0,0}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}}},{["EmitCount"]=5,["EmitDelay"]=0}},{"ParticleEmitter","dark",{["RotSpeed"]={"NR",-720,-720},["Color"]={"CS",{{0,0.78431,0.058823,0.058823},{1,0.78431,0.058823,0.058823}}},["ZOffset"]=-1,["Texture"]="rbxassetid://9069600131",["Rotation"]={"NR",0,360},["Transparency"]={"NS",{{0,1,0},{0.39651,0.8375,0},{1,1,0}}},["Rate"]=15,["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Speed"]={"NR",0.001,0.001},["Brightness"]=0.72,["Lifetime"]={"NR",0.35,0.35},["Size"]={"NS",{{0,5,0},{1,7.75,0}}}}},{"ParticleEmitter","gradient",{["Color"]={"CS",{{0,1,0.13333,0.13333},{1,1,0.13333,0.13333}}},["ZOffset"]=2,["Texture"]="rbxassetid://11183330587",["Rate"]=7,["Transparency"]={"NS",{{0,1,0},{0.50249,0.825,0},{1,1,0}}},["Speed"]={"NR",0.001,0.001},["Lifetime"]={"NR",0.35,0.35},["LightEmission"]=1,["Brightness"]=5.395,["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Size"]={"NS",{{0,8,0},{0.1,6.8937,0},{0.2,6.2163,0},{0.3,5.6378,0},{0.4,5.1078,0},{0.5,4.6054,0},{0.6,4.1179,0},{0.7,3.6352,0},{0.8,3.1457,0},{0.9,2.6283,0},{1,2,0}}}}},{"ParticleEmitter","spiral",{["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["RotSpeed"]={"NR",720,720},["Texture"]="rbxassetid://11463188898",["Color"]={"CS",{{0,1,0.094118,0.094118},{1,1,0.4902,0.4902}}},["Rate"]=15,["ZOffset"]=3,["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Rotation"]={"NR",0,300},["Transparency"]={"NS",{{0,1,0},{0.15337,0.83125,0},{0.35287,0,0},{0.7581,0,0},{1,1,0}}},["Speed"]={"NR",0.001,0.001},["Lifetime"]={"NR",0.95,0.95},["LightEmission"]=1,["Brightness"]=5.395,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["Size"]={"NS",{{0,5,0},{0.1,3.3584,0},{0.2,2.7501,0},{0.3,2.3174,0},{0.4,1.9791,0},{0.5,1.7046,0},{0.6,1.4789,0},{0.7,1.2945,0},{0.8,1.149,0},{0.899,0.8125,0},{1,0,0}}}}}}},{"Attachment","burst",{},nil,nil,{{"ParticleEmitter","embers",{["Color"]={"CS",{{0,1,0.11372,0.11372},{1,1,0.11372,0.11372}}},["Drag"]=6,["ZOffset"]=1,["VelocitySpread"]=10000,["Lifetime"]={"NR",0.75,1.85},["Speed"]={"NR",20,45},["Brightness"]=10,["SpreadAngle"]={"V2",10000,10000},["Enabled"]=false,["Acceleration"]={"V3",10,15,-5},["Rate"]=25,["Rotation"]={"NR",90,90},["Transparency"]={"NS",{{0,-50,0},{1,-50,0}}},["Texture"]="rbxassetid://10481475319",["Orientation"]={"E","ParticleOrientation","VelocityParallel"},["Size"]={"NS",{{0,0.74,0.1875},{1,0,0}}},["LightEmission"]=1,["Squash"]={"NS",{{0,1,0},{1,1,0}}}},{["EmitCount"]=9,["EmitDelay"]=0}},{"ParticleEmitter","embers",{["Color"]={"CS",{{0,1,0.11372,0.11372},{1,1,0.11372,0.11372}}},["Drag"]=6,["ZOffset"]=1,["VelocitySpread"]=10000,["Lifetime"]={"NR",0.75,1.85},["Speed"]={"NR",20,45},["Brightness"]=10,["SpreadAngle"]={"V2",10000,10000},["Enabled"]=false,["Acceleration"]={"V3",-10,15,5},["Rate"]=25,["Rotation"]={"NR",90,90},["Transparency"]={"NS",{{0,-50,0},{1,-50,0}}},["Texture"]="rbxassetid://10481475319",["Orientation"]={"E","ParticleOrientation","VelocityParallel"},["Size"]={"NS",{{0,0.74,0.21333},{1,0,0}}},["LightEmission"]=1,["Squash"]={"NS",{{0,1,0},{1,1,0}}}},{["EmitCount"]=9,["EmitDelay"]=0}},{"ParticleEmitter","flare",{["Enabled"]=false,["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["Color"]={"CS",{{0,1,0.21961,0.21961},{1,1,0.21961,0.21961}}},["ZOffset"]=3,["Texture"]="rbxassetid://11365204122",["Transparency"]={"NS",{{0,0,0},{0.72693,0,0},{1,1,0}}},["Squash"]={"NS",{{0,1.4625,0},{0.10474,-0.1875,0},{0.84913,-2.0625,0},{1,-7.9548,0}}},["Lifetime"]={"NR",0.6,0.6},["LightEmission"]=1,["Brightness"]=5.395,["Speed"]={"NR",0.001,0.001},["Size"]={"NS",{{0,0,0},{0.1,5.6083,0},{0.2,6.345,0},{0.3,6.6674,0},{0.4,6.8315,0},{0.5,6.9186,0},{0.62001,6.8956,0},{0.77801,6.5697,0},{0.88401,5.1936,0},{0.95201,2.9619,0},{1,0,0}}}}},{"ParticleEmitter","flare",{["Enabled"]=false,["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["Color"]={"CS",{{0,1,0.21961,0.21961},{1,1,0.21961,0.21961}}},["ZOffset"]=3,["Texture"]="rbxassetid://11128747655",["Rotation"]={"NR",0,360},["Transparency"]={"NS",{{0,0,0},{0.4813,0.78125,0},{1,1,0}}},["Squash"]={"NS",{{0,0,0},{1,-0.15,0}}},["Lifetime"]={"NR",0.35,0.35},["LightEmission"]=1,["Brightness"]=9.71,["Speed"]={"NR",0.001,0.001},["Size"]={"NS",{{0,0,0},{0.1,2.1672,0},{0.2,3.6083,0},{0.3,4.7039,0},{0.4,5.5785,0},{0.5,6.29,0},{0.6,6.8687,0},{0.7,7.3303,0},{0.8,7.6798,0},{0.9,7.9113,0},{1,8,0}}}}},{"ParticleEmitter","gradient",{["Enabled"]=false,["Color"]={"CS",{{0,1,0.13333,0.13333},{1,1,0.13333,0.13333}}},["ZOffset"]=2,["Texture"]="rbxassetid://11183330587",["Rate"]=7,["Transparency"]={"NS",{{0,0,0},{0.16334,0.09375,0},{0.53616,0.70625,0},{1,1,0}}},["Speed"]={"NR",0.001,0.001},["Lifetime"]={"NR",0.35,0.35},["LightEmission"]=1,["Brightness"]=5.395,["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Size"]={"NS",{{0,0,0},{0.1,0.98233,0},{0.2,2.7815,0},{0.3,4.4179,0},{0.4,5.7642,0},{0.5,6.8621,0},{0.6,7.7607,0},{0.7,8.4986,0},{0.8,9.1043,0},{0.9,9.5993,0},{1,10,0}}}}},{"ParticleEmitter","glow",{["Enabled"]=false,["Color"]={"CS",{{0,1,0.13333,0.13333},{1,1,0.13333,0.13333}}},["ZOffset"]=-1,["Texture"]="rbxassetid://9069600131",["Rate"]=7,["Transparency"]={"NS",{{0,0,0},{0.30175,0.71875,0},{1,1,0}}},["Speed"]={"NR",0.001,0.001},["Lifetime"]={"NR",0.95,0.95},["LightEmission"]=1,["Brightness"]=5.395,["Squash"]={"NS",{{0,0,0},{1,-1.875,0}}},["Size"]={"NS",{{0,0,0},{0.1,7.3046,0},{0.2,9.7462,0},{0.3,11.354,0},{0.4,12.513,0},{0.5,13.372,0},{0.6,14.007,0},{0.7,14.464,0},{0.8,14.77,0},{0.9,14.944,0},{1,15,0}}}}}}}},1}},
        	["Glitter Bomb"] = {{"Part","Glitterbomb",{["CFrame"]={"CF",0,0,0,1,0,0,0,1,0,0,0,1},["Size"]={"V3",1.1,1.1,1.1}},nil,nil,{{"Attachment","Core",{},nil,nil,{{"ParticleEmitter","ParticleEmitter",{["Enabled"]=false,["Color"]={"CS",{{0,1,0.19216,0.67843},{1,1,0.19216,0.67843}}},["LockedToPart"]=true,["ZOffset"]=2,["Texture"]="rbxassetid://11120541585",["Transparency"]={"NS",{{0,0,0},{1,0,0}}},["Rate"]=15,["Lifetime"]={"NR",0.2,0.2},["LightEmission"]=1,["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Speed"]={"NR",0,0},["Size"]={"NS",{{0,3,0},{1,0,0}}}}},{"ParticleEmitter","Smoke1",{["Color"]={"CS",{{0,1,0.89804,0.96471},{1,1,0.12549,0.59216}}},["Drag"]=2,["ZOffset"]=0.4,["VelocitySpread"]=-360,["Lifetime"]={"NR",1,2},["Speed"]={"NR",3,12},["SpreadAngle"]={"V2",-360,360},["Enabled"]=false,["Acceleration"]={"V3",0,2,0},["RotSpeed"]={"NR",-66,66},["Rate"]=15,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.20243,0,0},{1,1,0}}},["Texture"]="rbxassetid://11147957636",["Size"]={"NS",{{0,1.5,0.5},{1,4,1}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}}},{["EmitCount"]=10}},{"ParticleEmitter","Glitter",{["Enabled"]=false,["Texture"]="rbxassetid://11263405480",["Rate"]=15,["Size"]={"NS",{{0,0,0},{0.29992,0,0},{0.39934,0.2,0.1},{0.50123,0,0},{0.79786,0,0},{0.9,0.5,0.3},{1,0,0}}},["Color"]={"CS",{{0,1,0.64314,0.93726},{1,1,0,0.56863}}},["Drag"]=25,["ZOffset"]=1.1,["Speed"]={"NR",33,88},["VelocitySpread"]=180,["Transparency"]={"NS",{{0,0,0},{1,0,0}}},["Lifetime"]={"NR",1,2},["LightEmission"]=1,["Squash"]={"NS",{{0,0,0},{1,0,0}}},["SpreadAngle"]={"V2",180,45}},{["EmitCount"]=5}},{"ParticleEmitter","Dot",{["Enabled"]=false,["Texture"]="rbxassetid://11104003043",["Rate"]=15,["Size"]={"NS",{{0,1,0.5},{0.83484,0.125,0.08258},{0.90057,0.6875,0.049712},{1,0,0}}},["Color"]={"CS",{{0,1,0.64314,0.93726},{1,1,0,0.56863}}},["Drag"]=12,["ZOffset"]=1.1,["Speed"]={"NR",5,33},["VelocitySpread"]=180,["Transparency"]={"NS",{{0,0,0},{1,1,0}}},["Lifetime"]={"NR",0.4,1},["LightEmission"]=1,["Squash"]={"NS",{{0,0,0},{1,0,0}}},["SpreadAngle"]={"V2",180,45}},{["EmitCount"]=5}}}}},1}},
        	["Deleted"] = {{"Part","Deleted",{["CFrame"]={"CF",0,0,0,1,0,0,0,1,0,0,0,1},["Size"]={"V3",6,0.001,6}},nil,nil,{{"Attachment","A_Ground",{},nil,nil,{{"ParticleEmitter","PixelRing",{["Enabled"]=false,["Color"]={"CS",{{0,0,0,0},{1,0,0,0}}},["Rate"]=1,["Transparency"]={"NS",{{0,0,0},{1,1,0}}},["Texture"]="rbxassetid://11280560152",["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Speed"]={"NR",0.01,0.01},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Lifetime"]={"NR",1.25,1.25},["Size"]={"NS",{{0,3.5,0},{1,3.5,0}}}}},{"ParticleEmitter","PixelGerid",{["Enabled"]=false,["Color"]={"CS",{{0,0,1,0.25098},{1,0,1,0.25098}}},["ZOffset"]=0.1,["Texture"]="rbxassetid://11280707182",["Rate"]=1,["Transparency"]={"NS",{{0,0,0},{1,1,0}}},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Lifetime"]={"NR",1.25,1.25},["LightEmission"]=1,["Speed"]={"NR",0.01,0.01},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Size"]={"NS",{{0,7,0},{1,7,0}}}}},{"ParticleEmitter","PixelGerid",{["Enabled"]=false,["Color"]={"CS",{{0,0,1,0.25098},{1,0,1,0.25098}}},["ZOffset"]=0.1,["Texture"]="rbxassetid://11280707182",["Rate"]=1,["Transparency"]={"NS",{{0,0,0},{1,1,0}}},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Lifetime"]={"NR",1.25,1.25},["LightEmission"]=1,["Speed"]={"NR",0.01,0.01},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Size"]={"NS",{{0,7,0},{1,7,0}}}}},{"ParticleEmitter","PixelCircle",{["Enabled"]=false,["Color"]={"CS",{{0,0,1,0.2},{1,0,1,0.2}}},["ZOffset"]=0.1,["Texture"]="rbxassetid://11282555139",["Rate"]=1,["Transparency"]={"NS",{{0,0,0},{1,1,0}}},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Lifetime"]={"NR",1.25,1.25},["LightEmission"]=1,["Speed"]={"NR",0.01,0.01},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Size"]={"NS",{{0,3.5,0},{1,3.5,0}}}}},{"ParticleEmitter","PixelCircle1",{["Enabled"]=false,["Color"]={"CS",{{0,0,1,0.2},{1,0,1,0.2}}},["Drag"]=5,["ZOffset"]=0.1,["Texture"]="rbxassetid://11282555139",["Rate"]=1,["Transparency"]={"NS",{{0,0,0},{1,1,0}}},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Lifetime"]={"NR",0.25,0.25},["LightEmission"]=1,["Speed"]={"NR",15,15},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Size"]={"NS",{{0,3.5,0},{1,3.5,0}}}}}}},{"ParticleEmitter","BlackPixel",{["Enabled"]=false,["Acceleration"]={"V3",0,4,0},["Texture"]="rbxassetid://11281249595",["Color"]={"CS",{{0,0,0,0},{1,0,0,0}}},["Drag"]=2,["ZOffset"]=1,["Rate"]=1,["Squash"]={"NS",{{0,-1.575,0.225},{0.79968,-3,0},{1,-3,0}}},["Transparency"]={"NS",{{0,0,0},{1,0,0}}},["Lifetime"]={"NR",0.2,1},["Orientation"]={"E","ParticleOrientation","VelocityParallel"},["Speed"]={"NR",1,75},["Size"]={"NS",{{0,10,5},{1,0,0}}}},{["EmitCount"]=2}},{"ParticleEmitter","GlowingPixel",{["Enabled"]=false,["Acceleration"]={"V3",0,4,0},["Texture"]="rbxassetid://11281249595",["Rate"]=1,["Color"]={"CS",{{0,0.066667,1,0},{1,0.066667,1,0}}},["Drag"]=2,["ZOffset"]=0.5,["Orientation"]={"E","ParticleOrientation","VelocityParallel"},["Speed"]={"NR",1,75},["Transparency"]={"NS",{{0,0,0},{1,0,0}}},["Lifetime"]={"NR",0.2,1},["LightEmission"]=1,["Squash"]={"NS",{{0,-1.575,0.225},{0.79968,-3,0},{1,-3,0}}},["Size"]={"NS",{{0,10,5},{1,0,0}}}},{["EmitCount"]=2}},{"ParticleEmitter","LightBinary",{["Enabled"]=false,["Acceleration"]={"V3",0,4,0},["Texture"]="rbxassetid://11284162223",["Rate"]=1,["Color"]={"CS",{{0,0.066667,1,0},{1,0.066667,1,0}}},["Drag"]=2,["ZOffset"]=2,["Orientation"]={"E","ParticleOrientation","VelocityParallel"},["Speed"]={"NR",5,75},["Transparency"]={"NS",{{0,0,0},{0.25107,0,0},{0.26707,0.996,0},{0.39507,1,0},{0.39907,0,0},{0.79,0,0},{1,1,0}}},["Lifetime"]={"NR",0.2,0.8},["LightEmission"]=1,["Squash"]={"NS",{{0,-1,0.5},{1,-1,0.5}}},["Size"]={"NS",{{0,3,1},{1,3,1}}}},{["EmitCount"]=2}},{"ParticleEmitter","GreenPixel",{["Enabled"]=false,["Acceleration"]={"V3",0,4,0},["Color"]={"CS",{{0,0,1,0.16471},{1,0,0,0}}},["Drag"]=2,["Rate"]=1,["Texture"]="rbxassetid://11281249595",["Squash"]={"NS",{{0,-1.575,0.225},{0.79968,-3,0},{1,-3,0}}},["Transparency"]={"NS",{{0,0,0},{1,0,0}}},["Lifetime"]={"NR",0.2,1},["Orientation"]={"E","ParticleOrientation","VelocityParallel"},["Speed"]={"NR",1,75},["Size"]={"NS",{{0,10,5},{1,0,0}}}},{["EmitCount"]=2}},{"ParticleEmitter","DarkGreenPixel",{["Enabled"]=false,["Acceleration"]={"V3",0,4,0},["Texture"]="rbxassetid://11281249595",["Color"]={"CS",{{0,0,0.3098,0.043137},{1,0,0.3098,0.043137}}},["Drag"]=2,["ZOffset"]=-0.5,["Rate"]=1,["Squash"]={"NS",{{0,-1.575,0.225},{0.79968,-3,0},{1,-3,0}}},["Transparency"]={"NS",{{0,0,0},{1,0,0}}},["Lifetime"]={"NR",0.2,1},["Orientation"]={"E","ParticleOrientation","VelocityParallel"},["Speed"]={"NR",1,75},["Size"]={"NS",{{0,10,5},{1,0,0}}}},{["EmitCount"]=2}},{"ParticleEmitter","LightGreenPixel",{["Enabled"]=false,["Acceleration"]={"V3",0,4,0},["Texture"]="rbxassetid://11281249595",["Color"]={"CS",{{0,0.066667,1,0},{1,0.066667,1,0}}},["Drag"]=2,["ZOffset"]=-1,["Rate"]=1,["Squash"]={"NS",{{0,-1.575,0.225},{0.79968,-3,0},{1,-3,0}}},["Transparency"]={"NS",{{0,0,0},{1,0,0}}},["Lifetime"]={"NR",0.2,1},["Orientation"]={"E","ParticleOrientation","VelocityParallel"},["Speed"]={"NR",1,75},["Size"]={"NS",{{0,10,5},{1,0,0}}}},{["EmitCount"]=2}}},1}},
        	["Sparkle"] = {{"Part","PinkStar",{["CFrame"]={"CF",0,0,0,1,0,0,0,1,0,0,0,1},["Size"]={"V3",5,5,5}},nil,nil,{{"Attachment","Ground",{},nil,nil,{{"ParticleEmitter","BiggerStaar",{["Enabled"]=false,["Color"]={"CS",{{0,1,0.43529,0.85098},{1,1,0,0.4}}},["ZOffset"]=1,["Texture"]="rbxassetid://11312449064",["Rate"]=1,["Transparency"]={"NS",{{0,0.75625,0},{1,1,0}}},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Lifetime"]={"NR",0.8,0.8},["LightEmission"]=1,["Speed"]={"NR",0.01,0.01},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Size"]={"NS",{{0,10,0},{1,10,0}}}}},{"ParticleEmitter","UpStar",{["Enabled"]=false,["Color"]={"CS",{{0,1,0.43529,0.85098},{1,1,0.16471,0.66667}}},["Drag"]=5,["ZOffset"]=1,["Texture"]="rbxassetid://11312441537",["Transparency"]={"NS",{{0,0,0},{1,1,0}}},["Rate"]=1,["Lifetime"]={"NR",0.5,0.5},["LightEmission"]=1,["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Size"]={"NS",{{0,8,0},{1,8,0}}}}},{"ParticleEmitter","FullStar",{["Enabled"]=false,["Color"]={"CS",{{0,1,0.20784,0.72549},{1,1,0.16471,0.66667}}},["ZOffset"]=1,["Texture"]="rbxassetid://11312468631",["Rate"]=1,["Transparency"]={"NS",{{0,0,0},{1,1,0}}},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Lifetime"]={"NR",0.3,0.3},["LightEmission"]=1,["Speed"]={"NR",0.01,0.01},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Size"]={"NS",{{0,8,0},{1,8,0}}}}},{"ParticleEmitter","CoreStar",{["Enabled"]=false,["Color"]={"CS",{{0,1,0.43529,0.85098},{1,1,0.16471,0.66667}}},["ZOffset"]=1,["Texture"]="rbxassetid://11312423607",["Rate"]=1,["Transparency"]={"NS",{{0,0,0},{1,1,0}}},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Lifetime"]={"NR",1,1},["LightEmission"]=1,["Speed"]={"NR",0.01,0.01},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Size"]={"NS",{{0,8,0},{1,8,0}}}}},{"ParticleEmitter","BurstStar",{["Enabled"]=false,["Color"]={"CS",{{0,1,0.43529,0.85098},{1,1,0.16471,0.66667}}},["ZOffset"]=1,["Texture"]="rbxassetid://11312706966",["Rate"]=1,["Transparency"]={"NS",{{0,0,0},{1,1,0}}},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Lifetime"]={"NR",0.75,0.75},["LightEmission"]=1,["Speed"]={"NR",0.01,0.01},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Size"]={"NS",{{0,8,0},{1,8,0}}}}},{"ParticleEmitter","BurstStar",{["Enabled"]=false,["Color"]={"CS",{{0,1,0.43529,0.85098},{1,1,0.16471,0.66667}}},["ZOffset"]=1,["Texture"]="rbxassetid://11312441537",["Rate"]=1,["Transparency"]={"NS",{{0,0,0},{1,1,0}}},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Lifetime"]={"NR",0.5,0.5},["LightEmission"]=1,["Speed"]={"NR",0.01,0.01},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Size"]={"NS",{{0,8,0},{1,8,0}}}}},{"ParticleEmitter","PinkSpike",{["Color"]={"CS",{{0,1,0,0.51765},{1,1,0.16471,0.96078}}},["Drag"]=2,["VelocitySpread"]=75,["Lifetime"]={"NR",0.3,0.6},["Speed"]={"NR",25,55},["Brightness"]=1.5,["SpreadAngle"]={"V2",75,75},["Enabled"]=false,["Acceleration"]={"V3",0,5,0},["Rate"]=1,["Rotation"]={"NR",-90,-90},["Transparency"]={"NS",{{0,0,0},{1,0,0}}},["Texture"]="rbxassetid://11313373041",["Orientation"]={"E","ParticleOrientation","VelocityParallel"},["Size"]={"NS",{{0,5.125,1.5625},{1,0,0}}},["LightEmission"]=1,["Squash"]={"NS",{{0,0.1875,0.075},{1,1,0}}}},{["EmitCount"]=2}},{"ParticleEmitter","WhiteSpike",{["Color"]={"CS",{{0,1,0,0.51765},{1,1,0.6549,0.87059}}},["Drag"]=2,["VelocitySpread"]=75,["Lifetime"]={"NR",0.3,0.6},["Speed"]={"NR",25,55},["Brightness"]=1.5,["SpreadAngle"]={"V2",75,75},["Enabled"]=false,["Acceleration"]={"V3",0,5,0},["Rate"]=1,["Rotation"]={"NR",-90,-90},["Transparency"]={"NS",{{0,0,0},{1,0,0}}},["Texture"]="rbxassetid://11313373041",["Orientation"]={"E","ParticleOrientation","VelocityParallel"},["Size"]={"NS",{{0,5.125,1.5625},{1,0,0}}},["LightEmission"]=1,["Squash"]={"NS",{{0,0.1875,0.075},{1,1,0}}}},{["EmitCount"]=2}}}},{"ParticleEmitter","PinkLineStar",{["Color"]={"CS",{{0,1,0,0.51765},{1,1,0.16471,0.96078}}},["Drag"]=5,["Lifetime"]={"NR",0.3,1},["Speed"]={"NR",5,85},["Brightness"]=1.5,["Size"]={"NS",{{0,2,1},{1,0,0}}},["Enabled"]=false,["Acceleration"]={"V3",0,5,0},["Rate"]=1,["Rotation"]={"NR",-90,-90},["Transparency"]={"NS",{{0,0,0},{1,0,0}}},["Orientation"]={"E","ParticleOrientation","VelocityParallel"},["Texture"]="rbxassetid://11313342094",["Squash"]={"NS",{{0,1,1},{0.59512,0,0},{1,0,0}}},["LightEmission"]=1},{["EmitCount"]=2}},{"ParticleEmitter","PinkSpike",{["Color"]={"CS",{{0,1,0,0.51765},{1,1,0.16471,0.96078}}},["Drag"]=5,["VelocitySpread"]=33,["Lifetime"]={"NR",0.3,0.6},["Speed"]={"NR",25,55},["Brightness"]=1.5,["SpreadAngle"]={"V2",33,33},["Enabled"]=false,["Acceleration"]={"V3",0,5,0},["Rate"]=1,["Rotation"]={"NR",-90,-90},["Transparency"]={"NS",{{0,0,0},{1,0,0}}},["Texture"]="rbxassetid://11313373041",["LightEmission"]=1,["Size"]={"NS",{{0,5.125,1.5625},{1,0,0}}},["Squash"]={"NS",{{0,0.1875,0.075},{1,1,0}}},["Orientation"]={"E","ParticleOrientation","VelocityParallel"}}},{"ParticleEmitter","StarEffectLighPink",{["Color"]={"CS",{{0,1,0,0.51765},{1,1,0.85882,0.93726}}},["Drag"]=5,["VelocitySpread"]=25,["Lifetime"]={"NR",0.3,0.8},["Speed"]={"NR",0.5,65},["Brightness"]=1.5,["SpreadAngle"]={"V2",25,25},["Enabled"]=false,["Acceleration"]={"V3",0,5,0},["Rate"]=1,["Rotation"]={"NR",90,90},["Transparency"]={"NS",{{0,0,0},{1,0,0}}},["Texture"]="rbxassetid://11312468631",["Orientation"]={"E","ParticleOrientation","VelocityParallel"},["Size"]={"NS",{{0,0,0},{0.5,0.5,0},{0.65,1,0.3},{0.8,0.6,0},{1,0,0}}},["LightEmission"]=0.6,["Squash"]={"NS",{{0,2,0},{0.5,0,0},{1,0,0}}}},{["EmitCount"]=5}},{"ParticleEmitter","LightLineStar",{["Color"]={"CS",{{0,1,0,0.51765},{1,1,0.59608,0.96078}}},["Drag"]=5,["Lifetime"]={"NR",0.3,1},["Speed"]={"NR",5,85},["Brightness"]=1.5,["Size"]={"NS",{{0,2,1},{1,0,0}}},["Enabled"]=false,["Acceleration"]={"V3",0,5,0},["Rate"]=1,["Rotation"]={"NR",-90,-90},["Transparency"]={"NS",{{0,0,0},{1,0,0}}},["Orientation"]={"E","ParticleOrientation","VelocityParallel"},["Texture"]="rbxassetid://11313342094",["Squash"]={"NS",{{0,1,1},{0.59512,0,0},{1,0,0}}},["LightEmission"]=1},{["EmitCount"]=5}},{"ParticleEmitter","PinkLine",{["Enabled"]=false,["Acceleration"]={"V3",0,5,0},["Texture"]="rbxassetid://11104313339",["Orientation"]={"E","ParticleOrientation","VelocityParallel"},["Color"]={"CS",{{0,1,0,0.51765},{1,1,0.16471,0.96078}}},["Drag"]=5,["Rate"]=1,["Squash"]={"NS",{{0,-1.5,0.75},{1,-1.5,0.75}}},["Speed"]={"NR",5,85},["Transparency"]={"NS",{{0,0,0},{1,0,0}}},["Lifetime"]={"NR",0.6,1.2},["LightEmission"]=1,["Brightness"]=1.5,["Size"]={"NS",{{0,2,1},{1,0,0}}}},{["EmitCount"]=2}},{"Attachment","Static",{["CFrame"]={"CF",0,3,0,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,3,0}},nil,nil,{{"ParticleEmitter","GlowEff",{["Enabled"]=false,["Color"]={"CS",{{0,1,0.38039,0.81569},{1,1,0.38039,0.81569}}},["Texture"]="rbxassetid://11104415498",["ZOffset"]=2,["Rate"]=1,["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Transparency"]={"NS",{{0,0,0},{1,1,0}}},["Lifetime"]={"NR",0.3,0.6},["LightEmission"]=1,["Speed"]={"NR",0,0},["Size"]={"NS",{{0,1,0},{1,10,0}}}},{["EmitCount"]=3}},{"ParticleEmitter","WideLightBeam",{["Enabled"]=false,["Color"]={"CS",{{0,1,0.63137,0.63922},{1,1,0,0.53333}}},["Rate"]=1,["Texture"]="rbxassetid://11104044554",["Rotation"]={"NR",90,90},["Transparency"]={"NS",{{0,0,0},{0.40074,0,0},{1,1,0}}},["LightEmission"]=1,["Squash"]={"NS",{{0,-0.4125,0},{1,-3,0}}},["Orientation"]={"E","ParticleOrientation","FacingCameraWorldUp"},["Speed"]={"NR",12,12},["Lifetime"]={"NR",1,1},["Size"]={"NS",{{0,12,0},{1,6,0}}}}}}}},1}},
        	["Blackhole"] = {{"Part","BlackholeParticlesContainer",{["CFrame"]={"CF",0,0,0,1,0,0,0,1,0,0,0,1},["Size"]={"V3",1,1,1}},nil,nil,{{"Attachment","Attachment",{},nil,nil,{{"ParticleEmitter","innerShine",{["Color"]={"CS",{{0,0.9098,0.43922,1},{1,0.9098,0.43922,1}}},["ZOffset"]=0.47176,["VelocitySpread"]=180,["Lifetime"]={"NR",1,2},["Speed"]={"NR",0.019864,0.019864},["Brightness"]=10,["SpreadAngle"]={"V2",180,-180},["RotSpeed"]={"NR",-300,300},["LockedToPart"]=true,["Rate"]=10,["Rotation"]={"NR",-180,180},["Transparency"]={"NS",{{0,1,0},{0.34949,0.35857,0},{0.70805,0.93625,0},{1,1,0}}},["Texture"]="rbxassetid://9576700277",["LightEmission"]=1,["Size"]={"NS",{{0,13.513,0},{0.47523,1.741,1.741},{1,0,0}}},["Squash"]={"NS",{{0,0,0},{0.21897,0.99203,0},{0.47469,-1.5179,0},{0.74587,0.92032,0},{1,0,0}}},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"}}},{"ParticleEmitter","darkerShades",{["RotSpeed"]={"NR",100,300},["Color"]={"CS",{{0,0,0,0},{1,0,0,0}}},["LockedToPart"]=true,["ZOffset"]=0.21597,["Rotation"]={"NR",-180,180},["Transparency"]={"NS",{{0,1,0},{0.34949,0.35857,0},{0.70805,0.93625,0},{1,1,0}}},["Texture"]="rbxassetid://9576558696",["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Speed"]={"NR",0,0},["Brightness"]=2,["Lifetime"]={"NR",1,2},["Size"]={"NS",{{0,10.799,0},{1,0,0}}}}},{"ParticleEmitter","suction",{["RotSpeed"]={"NR",100,100},["Color"]={"CS",{{0,0.78039,0.52549,1},{0.34429,0.043711,0.0099051,0.054908},{0.66436,0.27843,0.027451,0.31373},{1,0,0,0}}},["LockedToPart"]=true,["Rate"]=10,["Rotation"]={"NR",-180,180},["Transparency"]={"NS",{{0,1,0},{0.34949,0.35857,0},{1,0,0}}},["Texture"]="rbxassetid://9576558555",["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Speed"]={"NR",0,0},["Brightness"]=10,["Lifetime"]={"NR",2,2},["Size"]={"NS",{{0,22.478,0},{0.42301,6.4503,0},{0.67661,2.2379,0},{1,0,0}}}}}}}},1}},
        	["Paper Surprise"] = {{"Part","PaperSurprise",{["CFrame"]={"CF",0,0,0,1,0,0,0,1,0,0,0,1},["Size"]={"V3",4,4,4}},nil,nil,{{"Attachment","Attachment",{},nil,nil,{{"ParticleEmitter","circle 1",{["Enabled"]=false,["Color"]={"CS",{{0,1,1,1},{0.074266,1,0.16842,0.18146},{0.12953,1,0,0.015686},{0.2418,0,0.91765,1},{0.3437,0.56863,1,0},{0.37651,0.92012,0.59419,0},{0.39551,1,0.50196,0},{0.4266,0.66667,0,1},{0.49741,0,0.38431,1},{0.55095,0.4,1,0},{0.60967,1,0.46667,0},{0.65458,0.066667,0,1},{0.72366,0.43529,1,0},{0.77548,1,0,0},{0.93437,1,0,0},{1,1,1,1}}},["LockedToPart"]=true,["Rate"]=4,["Texture"]="rbxassetid://9589733819",["Transparency"]={"NS",{{0,1,0},{0.50187,0,0},{1,1,0}}},["LightEmission"]=1,["Lifetime"]={"NR",1,1},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Speed"]={"NR",0.003,0.003},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Size"]={"NS",{{0,3,0},{1,3,0}}}}},{"ParticleEmitter","circle  2",{["Enabled"]=false,["RotSpeed"]={"NR",-360,-360},["Color"]={"CS",{{0,1,1,1},{1,1,1,1}}},["LockedToPart"]=true,["Rate"]=2,["Texture"]="rbxassetid://11336307417",["Transparency"]={"NS",{{0,1,0},{0.49813,0,0},{1,1,0}}},["LightEmission"]=1,["Lifetime"]={"NR",1,1},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Speed"]={"NR",0.003,0.003},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Size"]={"NS",{{0,5,0},{1,5,0}}}}},{"ParticleEmitter","Paper",{["Color"]={"CS",{{0,1,1,1},{1,1,1,1}}},["Drag"]=3.5,["VelocitySpread"]=45,["Lifetime"]={"NR",0.3,2},["Speed"]={"NR",10,33},["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["SpreadAngle"]={"V2",45,45},["Enabled"]=false,["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["LockedToPart"]=true,["Rate"]=18,["Texture"]="rbxassetid://11531840467",["Transparency"]={"NS",{{0,0,0},{0.80075,0,0},{1,1,0}}},["Size"]={"NS",{{0,1.5625,0.9375},{0.33997,1.25,0},{0.66376,1.25,0.9375},{0.91407,0,0},{1,0,0}}},["Acceleration"]={"V3",0,-10,0},["LightEmission"]=0.2,["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Orientation"]={"E","ParticleOrientation","VelocityParallel"}},{["EmitCount"]=8,["EmitDelay"]=0}},{"ParticleEmitter","Glow 2",{["Enabled"]=false,["RotSpeed"]={"NR",99999,99999},["Texture"]="rbxassetid://9354796901",["Color"]={"CS",{{0,0,0,0},{1,0,0,0}}},["LockedToPart"]=true,["Rate"]=11,["LightEmission"]=-5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.5,0.25,0.25},{1,1,0}}},["Speed"]={"NR",0.003,0.003},["Lifetime"]={"NR",0.25,0.5},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Brightness"]=0,["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Size"]={"NS",{{0,1.9963,0},{1,5.3236,1.3309}}}}},{"ParticleEmitter","Glow",{["Enabled"]=false,["Color"]={"CS",{{0,1,1,1},{1,1,1,1}}},["LockedToPart"]=true,["Rate"]=11,["Texture"]="rbxassetid://9589703753",["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.5,0.25,0.25},{1,1,0}}},["LightEmission"]=1,["Lifetime"]={"NR",0.25,0.5},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Speed"]={"NR",0.003,0.003},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Size"]={"NS",{{0,1.9963,0},{1,5.3236,1.3309}}}}},{"ParticleEmitter","Paper Colours",{["Color"]={"CS",{{0,0.66667,0,0},{1,0.66667,0,0}}},["Drag"]=3.5,["VelocitySpread"]=45,["Lifetime"]={"NR",0.3,2},["Speed"]={"NR",10,33},["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["SpreadAngle"]={"V2",45,45},["Enabled"]=false,["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["LockedToPart"]=true,["Rate"]=18,["Transparency"]={"NS",{{0,0,0},{0.80075,0,0},{1,1,0}}},["Texture"]="rbxassetid://11531840467",["Acceleration"]={"V3",0,-10,0},["LightEmission"]=1,["Size"]={"NS",{{0,0,0},{0.50062,0.625,0.375},{1,0,0}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Orientation"]={"E","ParticleOrientation","VelocityParallel"}}},{"ParticleEmitter","Paper Colours",{["Color"]={"CS",{{0,0,0.33333,0},{1,0,0.33333,0}}},["Drag"]=3.5,["VelocitySpread"]=45,["Lifetime"]={"NR",0.3,2},["Speed"]={"NR",10,33},["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["SpreadAngle"]={"V2",45,45},["Enabled"]=false,["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["LockedToPart"]=true,["Rate"]=18,["Transparency"]={"NS",{{0,0,0},{0.80075,0,0},{1,1,0}}},["Texture"]="rbxassetid://11531840467",["Acceleration"]={"V3",0,-10,0},["LightEmission"]=1,["Size"]={"NS",{{0,0,0},{0.50062,0.625,0.375},{1,0,0}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Orientation"]={"E","ParticleOrientation","VelocityParallel"}}},{"ParticleEmitter","Paper Colours",{["Color"]={"CS",{{0,0.66667,0.33333,0},{1,0.66667,0.33333,0}}},["Drag"]=3.5,["VelocitySpread"]=45,["Lifetime"]={"NR",0.3,2},["Speed"]={"NR",10,33},["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["SpreadAngle"]={"V2",45,45},["Enabled"]=false,["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["LockedToPart"]=true,["Rate"]=18,["Transparency"]={"NS",{{0,0,0},{0.80075,0,0},{1,1,0}}},["Texture"]="rbxassetid://11531840467",["Acceleration"]={"V3",0,-10,0},["LightEmission"]=1,["Size"]={"NS",{{0,0,0},{0.50062,0.625,0.375},{1,0,0}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Orientation"]={"E","ParticleOrientation","VelocityParallel"}}},{"ParticleEmitter","Paper Colours",{["Color"]={"CS",{{0,0,0,0.49804},{1,0,0,0.49804}}},["Drag"]=3.5,["VelocitySpread"]=45,["Lifetime"]={"NR",0.3,2},["Speed"]={"NR",10,33},["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["SpreadAngle"]={"V2",45,45},["Enabled"]=false,["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["LockedToPart"]=true,["Rate"]=18,["Transparency"]={"NS",{{0,0,0},{0.80075,0,0},{1,1,0}}},["Texture"]="rbxassetid://11531840467",["Acceleration"]={"V3",0,-10,0},["LightEmission"]=1,["Size"]={"NS",{{0,0,0},{0.50062,0.625,0.375},{1,0,0}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Orientation"]={"E","ParticleOrientation","VelocityParallel"}}},{"ParticleEmitter","Paper Colours",{["Color"]={"CS",{{0,0.33333,0.66667,1},{1,0.33333,0.66667,1}}},["Drag"]=3.5,["VelocitySpread"]=45,["Lifetime"]={"NR",0.3,2},["Speed"]={"NR",10,33},["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["SpreadAngle"]={"V2",45,45},["Enabled"]=false,["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["LockedToPart"]=true,["Rate"]=18,["Transparency"]={"NS",{{0,0,0},{0.80075,0,0},{1,1,0}}},["Texture"]="rbxassetid://11531840467",["Acceleration"]={"V3",0,-10,0},["LightEmission"]=1,["Size"]={"NS",{{0,0,0},{0.50062,0.625,0.375},{1,0,0}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Orientation"]={"E","ParticleOrientation","VelocityParallel"}}},{"ParticleEmitter","Paper Colours",{["Color"]={"CS",{{0,0.33333,0,1},{1,0.33333,0,1}}},["Drag"]=3.5,["VelocitySpread"]=45,["Lifetime"]={"NR",0.3,2},["Speed"]={"NR",10,33},["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["SpreadAngle"]={"V2",45,45},["Enabled"]=false,["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["LockedToPart"]=true,["Rate"]=18,["Transparency"]={"NS",{{0,0,0},{0.80075,0,0},{1,1,0}}},["Texture"]="rbxassetid://11531840467",["Acceleration"]={"V3",0,-10,0},["LightEmission"]=1,["Size"]={"NS",{{0,0,0},{0.50062,0.625,0.375},{1,0,0}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Orientation"]={"E","ParticleOrientation","VelocityParallel"}}},{"ParticleEmitter","Paper Colours",{["Color"]={"CS",{{0,1,1,0},{1,1,1,0}}},["Drag"]=3.5,["VelocitySpread"]=45,["Lifetime"]={"NR",0.3,2},["Speed"]={"NR",10,33},["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["SpreadAngle"]={"V2",45,45},["Enabled"]=false,["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["LockedToPart"]=true,["Rate"]=18,["Transparency"]={"NS",{{0,0,0},{0.80075,0,0},{1,1,0}}},["Texture"]="rbxassetid://11531840467",["LightEmission"]=1,["Acceleration"]={"V3",0,-10,0},["Size"]={"NS",{{0,0,0},{0.50062,0.625,0.375},{1,0,0}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}}}},{"ParticleEmitter","Glow 3",{["Enabled"]=false,["Color"]={"CS",{{0,1,1,1},{0.074266,1,0.16842,0.18146},{0.12953,1,0,0.015686},{0.2418,0,0.91765,1},{0.3437,0.56863,1,0},{0.37651,0.92012,0.59419,0},{0.39551,1,0.50196,0},{0.4266,0.66667,0,1},{0.49741,0,0.38431,1},{0.55095,0.4,1,0},{0.60967,1,0.46667,0},{0.65458,0.066667,0,1},{0.72366,0.43529,1,0},{0.77548,1,0,0},{0.93437,1,0,0},{1,1,1,1}}},["LockedToPart"]=true,["ZOffset"]=1,["Texture"]="rbxassetid://9589703753",["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.5,0.25,0.25},{1,1,0}}},["Rate"]=11,["Lifetime"]={"NR",0.25,0.5},["LightEmission"]=1,["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Speed"]={"NR",0.012,0.012},["Size"]={"NS",{{0,7.9856,0},{1,21.295,5.3238}}}}},{"ParticleEmitter","Lines ",{["Color"]={"CS",{{0,1,1,1},{0.074266,1,0.16842,0.18146},{0.12953,1,0,0.015686},{0.2418,0,0.91765,1},{0.3437,0.56863,1,0},{0.37651,0.92012,0.59419,0},{0.39551,1,0.50196,0},{0.4266,0.66667,0,1},{0.49741,0,0.38431,1},{0.55095,0.4,1,0},{0.60967,1,0.46667,0},{0.65458,0.066667,0,1},{0.72366,0.43529,1,0},{0.77548,1,0,0},{0.93437,1,0,0},{1,1,1,1}}},["Drag"]=3,["ZOffset"]=0.96266,["VelocitySpread"]=80,["Lifetime"]={"NR",0.2,1},["Speed"]={"NR",17,35},["Brightness"]=100,["SpreadAngle"]={"V2",80,80},["Enabled"]=false,["LockedToPart"]=true,["Rate"]=100,["Rotation"]={"NR",-90,-90},["Transparency"]={"NS",{{0,1,0},{0.09856,0,0},{0.19578,0,0},{0.23042,1,0},{0.26355,0,0},{0.42018,0,0},{0.44578,1,0},{0.47741,0,0},{0.61596,0,0},{0.64608,1,0},{0.67319,0,0},{0.73193,0,0},{0.74849,1,0},{0.76657,0,0},{0.80066,0,0},{1,1,0}}},["Texture"]="rbxassetid://7828271118",["LightEmission"]=1,["Size"]={"NS",{{0,0,0},{0.30386,0.625,0},{1,0,0}}},["Orientation"]={"E","ParticleOrientation","VelocityParallel"},["Squash"]={"NS",{{0,1.65,0},{1,0,0}}}},{["EmitCount"]=5,["EmitDelay"]=0}}}}},1}},
        	["Cosmic Strike"] = {{"Part","Part",{["CFrame"]={"CF",0,0,0,1,0,0,0,1,0,0,0,1},["Size"]={"V3",4,0.51,4}},nil,nil,{{"Attachment","Attachment",{},nil,nil,{{"ParticleEmitter","Lines 3",{["Color"]={"CS",{{0,0.38824,0.23137,0.61961},{1,0.38824,0.23137,0.61961}}},["Drag"]=5,["ZOffset"]=1.4141,["VelocitySpread"]=-90,["Lifetime"]={"NR",0.2,1},["Speed"]={"NR",10.745,121.49},["Brightness"]=100,["SpreadAngle"]={"V2",-90,90},["Enabled"]=false,["LockedToPart"]=true,["Rate"]=9,["Rotation"]={"NR",-90,-90},["Transparency"]={"NS",{{0,1,0},{0.09856,0,0},{0.19578,0,0},{0.23042,1,0},{0.26355,0,0},{0.42018,0,0},{0.44578,1,0},{0.47741,0,0},{0.61596,0,0},{0.64608,1,0},{0.67319,0,0},{0.73193,0,0},{0.74849,1,0},{0.76657,0,0},{0.80066,0,0},{1,1,0}}},["Texture"]="rbxassetid://9710377531",["LightEmission"]=1,["Size"]={"NS",{{0,0,0},{0.05567,0.5,0.025681},{0.096907,5.0625,1.2889},{0.11959,0.625,0.050542},{0.19934,0.49878,0.088672},{0.24849,1.2196,0.088672},{0.3,0.19215,0.088672},{0.4,0.21994,0.088672},{0.42771,0.65401,0.086748},{0.44578,0,0},{0.50515,3.75,0.082551},{0.52711,1.1843,0.07999},{0.54819,0,0},{0.57831,0.72472,0.076363},{0.6567,0.16626,0.070809},{0.74096,1.0252,0.058661},{0.7997,0.74239,0.055419},{0.8238,0,0},{0.87801,0.45958,0.033752},{1,0,0}}},["Orientation"]={"E","ParticleOrientation","VelocityParallel"},["Squash"]={"NS",{{0,0.825,0},{0.034021,0.75,0},{0.078351,-0.1125,0},{0.10928,0.75,0},{0.7741,-0.225,0},{1,-0.3,0.7125}}}},{["EmitCount"]=25,["EmitDelay"]=0}},{"ParticleEmitter","Lines ",{["Color"]={"CS",{{0,0.25098,0.20392,0.61961},{1,0.25098,0.20392,0.61961}}},["Drag"]=3,["ZOffset"]=1.4141,["VelocitySpread"]=-90,["Lifetime"]={"NR",0.2,0.7},["Speed"]={"NR",20.745,121.49},["Brightness"]=100,["SpreadAngle"]={"V2",-90,90},["Enabled"]=false,["LockedToPart"]=true,["Rate"]=9,["Rotation"]={"NR",-90,-90},["Transparency"]={"NS",{{0,1,0},{0.09856,0,0},{0.19578,0,0},{0.23042,1,0},{0.26355,0,0},{0.42018,0,0},{0.44578,1,0},{0.47741,0,0},{0.61596,0,0},{0.64608,1,0},{0.67319,0,0},{0.73193,0,0},{0.74849,1,0},{0.76657,0,0},{0.80066,0,0},{1,1,0}}},["Texture"]="rbxassetid://7828271118",["LightEmission"]=1,["Size"]={"NS",{{0,0,0},{0.5,2.0625,0},{1,0,0}}},["Orientation"]={"E","ParticleOrientation","VelocityParallel"},["Squash"]={"NS",{{0,0,0},{1,0,0}}}},{["EmitCount"]=25,["EmitDelay"]=0}},{"ParticleEmitter","ParticleEmitter",{["Enabled"]=false,["Texture"]="rbxassetid://12359282780",["Color"]={"CS",{{0,0.21961,0.16471,1},{1,0.21961,0.16471,1}}},["FlipbookFramerate"]={"NR",30,30},["LockedToPart"]=true,["Rate"]=1,["Speed"]={"NR",0.003,0.003},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Transparency"]={"NS",{{0,1,0},{0.11819,0.15,0},{0.19714,0.0375,0},{0.27839,0,0},{0.80194,0,0},{0.82964,0.41875,0},{0.88966,0.81875,0},{0.94598,0.94375,0},{1,1,0}}},["Lifetime"]={"NR",2,2},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Brightness"]=20,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid8x8"},["Size"]={"NS",{{0,13,0},{1,13,0}}}},{["EmitCount"]=2,["EmitDelay"]=0}},{"PointLight","PointLight",{["Color"]={"C3",0.48627,0.48627,1},["Brightness"]=8,["Range"]=18,["Enabled"]=false}},{"ParticleEmitter","Shockwaves",{["Color"]={"CS",{{0,0.15686,0.078431,1},{1,0.15686,0.078431,1}}},["Drag"]=5,["ZOffset"]=1,["Lifetime"]={"NR",0.1,1.2},["Speed"]={"NR",0,2.8782},["Brightness"]=10,["Size"]={"NS",{{0,0,0},{0.2,10.415,0},{0.4,14.462,0},{0.6,17.187,0},{0.8,19.046,0},{1,19.915,0}}},["Enabled"]=false,["LockedToPart"]=true,["Rate"]=8,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{0.16812,0.21875,0},{0.33873,0.50625,0},{0.47572,0.80625,0},{0.63885,0.9625,0},{0.8132,0.975,0},{1,1,0}}},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Texture"]="rbxassetid://9710639706",["LightEmission"]=1,["Squash"]={"NS",{{0,0,0},{1,0,0}}}},{["EmitCount"]=3,["EmitDelay"]=0}},{"ParticleEmitter","Light",{["Color"]={"CS",{{0,0.50196,0.45882,1},{1,0.50196,0.45882,1}}},["Drag"]=5,["ZOffset"]=2,["Lifetime"]={"NR",1,1},["Speed"]={"NR",0.003,0.003},["Brightness"]=0.5,["Size"]={"NS",{{0,13,0},{1,13,0}}},["Enabled"]=false,["LockedToPart"]=true,["Rate"]=4,["Transparency"]={"NS",{{0,1,0},{0.50046,0,0},{1,1,0}}},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Texture"]="rbxassetid://10556517293",["LightEmission"]=1,["Squash"]={"NS",{{0,0,0},{1,0,0}}}},{["EmitCount"]=3,["EmitDelay"]=0}},{"ParticleEmitter","Strike",{["Color"]={"CS",{{0,0.19216,0.16078,0.61961},{1,0.19216,0.16078,0.61961}}},["Lifetime"]={"NR",1,1},["Speed"]={"NR",0.012036,0.012036},["Brightness"]=25,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid8x8"},["Size"]={"NS",{{0,40.121,0},{1,40.121,0}}},["Enabled"]=false,["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["LockedToPart"]=true,["Rate"]=1,["Rotation"]={"NR",180,180},["Transparency"]={"NS",{{0,0,0},{0.80194,0,0},{0.82964,0.41875,0},{0.86242,0.73125,0},{0.90074,0.875,0},{0.93906,0.95625,0},{1,1,0}}},["Texture"]="rbxassetid://12357585567",["Orientation"]={"E","ParticleOrientation","FacingCameraWorldUp"},["LightEmission"]=-1,["FlipbookFramerate"]={"NR",30,30},["Squash"]={"NS",{{0,1,0},{1,1,0}}}},{["EmitCount"]=2,["EmitDelay"]=0}}}}},1}},
        	["Tornado"] = {{"Part","Wind",{["CFrame"]={"CF",0,0,0,1,0,0,0,1,0,0,0,1},["Size"]={"V3",2,7.0265,2}},nil,nil,{{"Attachment","Attachment",{["CFrame"]={"CF",0,-3.6776,0,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,-3.6776,0}},nil,nil,{{"Beam","Beam",{["FaceCamera"]=true,["Color"]={"CS",{{0,0.6,0.82745,1},{1,0.6,0.82745,1}}},["ZOffset"]=1,["Width0"]=0,["Texture"]="rbxassetid://9589762590",["Transparency"]={"NS",{{0,0,0},{1,1,0}}},["Width1"]=25,["Brightness"]=10,["TextureMode"]={"E","TextureMode","Static"},["TextureLength"]=10},nil,{["Attachment1"]={1,2},["Attachment0"]={1,1}}},{"ParticleEmitter","Spin",{["FlipbookFramerate"]={"NR",15,15},["Drag"]=3.25,["Lifetime"]={"NR",0.59043,1.1809},["Speed"]={"NR",18,18},["Brightness"]=3,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid8x8"},["Size"]={"NS",{{0,0,0},{0.2,2.5541,0},{0.4,4.0449,0},{0.6,5.1901,0},{0.8,6.4133,0},{1,10,0}}},["FlipbookMode"]={"E","ParticleFlipbookMode","PingPong"},["RotSpeed"]={"NR",-1600,-860},["LockedToPart"]=true,["Rate"]=15,["Transparency"]={"NS",{{0,0,0},{0.71653,0,0},{0.83887,0.76875,0},{1,1,0}}},["Texture"]="rbxassetid://12350085716",["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Color"]={"CS",{{0,0.72549,0.96471,1},{1,0.72549,0.96471,1}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}}},{["EmitCount"]=2,["EmitDelay"]=0}},{"ParticleEmitter","Specs",{["Color"]={"CS",{{0,0.21961,0.4,1},{1,0.21961,0.4,1}}},["Drag"]=5,["ZOffset"]=1.7108,["VelocitySpread"]=-35,["Lifetime"]={"NR",0.2,1},["Speed"]={"NR",12.831,30.795},["Brightness"]=100,["SpreadAngle"]={"V2",-35,35},["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["LockedToPart"]=true,["Rate"]=10,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{0.54124,0,0},{1,0.9625,0}}},["Texture"]="rbxassetid://10556232026",["LightEmission"]=1,["Size"]={"NS",{{0,0,0},{0.2,0.92921,4.2771},{0.4,1.9554,4.2771},{0.6,2.9953,4.2771},{0.8,3.8773,4.2771},{1,4.2771,4.2771}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["FlipbookStartRandom"]=true},{["EmitCount"]=200,["EmitDelay"]=0}},{"ParticleEmitter","Smoke",{["Color"]={"CS",{{0,0.6,0.82745,1},{1,0.6,0.82745,1}}},["Drag"]=6,["ZOffset"]=0.12413,["LightInfluence"]=0.25,["Lifetime"]={"NR",2,3},["Speed"]={"NR",9,16},["SpreadAngle"]={"V2",0,1000},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.10896,0.9375,0},{0.18698,0.9,0},{0.23038,0.75,0},{0.26777,0.54375,0},{0.3338,0.44375,0},{0.39889,0.81875,0},{0.49908,0.9375,0},{0.60665,0.96875,0},{0.69945,0.94375,0},{0.79917,0.95625,0},{0.89982,0.98125,0},{1,1,0}}},["EmissionDirection"]={"E","NormalId","Left"},["LightEmission"]=1,["Texture"]="rbxassetid://9860410723",["Size"]={"NS",{{0,0.20012,0.20012},{0.16314,1.5559,0.2597},{0.35866,2.4311,0.28767},{0.52802,2.7423,0.30018},{1,3.1118,0}}},["Squash"]={"NS",{{0,0,0.45},{0.49934,0.0375,0},{1,0,0}}}},{["EmitCount"]=10,["EmitDelay"]=0}},{"Beam","Beam",{["FaceCamera"]=true,["Color"]={"CS",{{0,0.6,0.82745,1},{1,0.6,0.82745,1}}},["TextureSpeed"]=0.2,["ZOffset"]=1,["Width0"]=0,["Texture"]="rbxassetid://9589826891",["Transparency"]={"NS",{{0,0,0},{0.62789,0.94375,0},{1,1,0}}},["Width1"]=25,["Brightness"]=10,["TextureMode"]={"E","TextureMode","Static"},["TextureLength"]=170},nil,{["Attachment1"]={1,2},["Attachment0"]={1,1}}},{"Beam","Beam",{["FaceCamera"]=true,["Color"]={"CS",{{0,0.6,0.82745,1},{1,0.6,0.82745,1}}},["TextureSpeed"]=0.3,["ZOffset"]=1,["Width0"]=0,["Texture"]="rbxassetid://9589826891",["Transparency"]={"NS",{{0,0,0},{0.53924,0.94375,0},{1,1,0}}},["Width1"]=25,["Brightness"]=10,["TextureMode"]={"E","TextureMode","Static"},["TextureLength"]=240},nil,{["Attachment1"]={1,2},["Attachment0"]={1,1}}}}},{"Attachment","Attachment",{["CFrame"]={"CF",0,5.3562,0,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,5.3562,0}}},{"ParticleEmitter","Smoke",{["Color"]={"CS",{{0,0.6,0.82745,1},{1,0.6,0.82745,1}}},["Drag"]=6,["ZOffset"]=0.24348,["LightInfluence"]=0.25,["Lifetime"]={"NR",2,3},["Speed"]={"NR",0.0018312,0.0018312},["SpreadAngle"]={"V2",0,60},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.10896,0.9375,0},{0.18698,0.9,0},{0.23038,0.75,0},{0.26777,0.54375,0},{0.3338,0.44375,0},{0.39889,0.81875,0},{0.49908,0.9375,0},{0.60665,0.96875,0},{0.69945,0.94375,0},{0.79917,0.95625,0},{0.89982,0.98125,0},{1,1,0}}},["EmissionDirection"]={"E","NormalId","Front"},["LightEmission"]=1,["Texture"]="rbxassetid://9860410723",["Size"]={"NS",{{0,0.39254,0.39254},{0.16314,3.052,0.50941},{0.35866,4.7687,0.56427},{0.52802,5.3791,0.58881},{1,6.1039,0}}},["Squash"]={"NS",{{0,0,0.45},{0.49934,0.0375,0},{1,0,0}}}},{["EmitCount"]=10,["EmitDelay"]=0}}},1},{"Part","Lightning",{["CFrame"]={"CF",-11.973,0,0,1,0,0,0,1,0,0,0,1},["Size"]={"V3",2,7.0265,2}},nil,nil,{{"Attachment","Attachment",{["CFrame"]={"CF",0,-3.6776,0,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,-3.6776,0}},nil,nil,{{"Beam","Beam",{["FaceCamera"]=true,["Color"]={"CS",{{0,0,0.29804,1},{1,0,0.29804,1}}},["ZOffset"]=1,["Width0"]=0,["Texture"]="rbxassetid://9589762590",["Transparency"]={"NS",{{0,0,0},{1,1,0}}},["Width1"]=25,["Brightness"]=10,["TextureMode"]={"E","TextureMode","Static"},["TextureLength"]=10},nil,{["Attachment1"]={2,2},["Attachment0"]={2,1}}},{"ParticleEmitter","Spin",{["FlipbookFramerate"]={"NR",15,15},["Drag"]=3.25,["Lifetime"]={"NR",0.59043,1.1809},["Speed"]={"NR",18,18},["Brightness"]=5,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid8x8"},["Size"]={"NS",{{0,0,0},{0.2,2.5541,0},{0.4,4.0449,0},{0.6,5.1901,0},{0.8,6.4133,0},{1,10,0}}},["FlipbookMode"]={"E","ParticleFlipbookMode","PingPong"},["RotSpeed"]={"NR",-1600,-860},["LockedToPart"]=true,["Rate"]=15,["Transparency"]={"NS",{{0,0,0},{0.71653,0,0},{0.83887,0.76875,0},{1,1,0}}},["Texture"]="rbxassetid://12350085716",["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Color"]={"CS",{{0,0.20784,0.5098,1},{1,0.20784,0.5098,1}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}}},{["EmitCount"]=2,["EmitDelay"]=0}},{"ParticleEmitter","Lines ",{["Color"]={"CS",{{0,0.13333,0.43529,1},{1,0.13333,0.43529,1}}},["Drag"]=3,["ZOffset"]=0.60482,["VelocitySpread"]=-45,["Lifetime"]={"NR",0.2,0.7},["Speed"]={"NR",8.8728,51.962},["Brightness"]=100,["SpreadAngle"]={"V2",-45,45},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-90,-90},["Transparency"]={"NS",{{0,1,0},{0.09856,0,0},{0.19578,0,0},{0.23042,1,0},{0.26355,0,0},{0.42018,0,0},{0.44578,1,0},{0.47741,0,0},{0.61596,0,0},{0.64608,1,0},{0.67319,0,0},{0.73193,0,0},{0.74849,1,0},{0.76657,0,0},{0.80066,0,0},{1,1,0}}},["Texture"]="rbxassetid://7828271118",["LightEmission"]=1,["Size"]={"NS",{{0,0,0},{0.5,0.88215,0},{1,0,0}}},["Orientation"]={"E","ParticleOrientation","VelocityParallel"},["Squash"]={"NS",{{0,0,0},{1,0,0}}}},{["EmitCount"]=25,["EmitDelay"]=0}},{"ParticleEmitter","Lines 3",{["Color"]={"CS",{{0,0.16471,0.3451,1},{1,0.16471,0.3451,1}}},["Drag"]=5,["ZOffset"]=0.60482,["VelocitySpread"]=-45,["Lifetime"]={"NR",0.2,2},["Speed"]={"NR",4.596,91.962},["Brightness"]=100,["SpreadAngle"]={"V2",-45,45},["Acceleration"]={"V3",0,-50,0},["Rate"]=5,["Rotation"]={"NR",-90,-90},["Transparency"]={"NS",{{0,1,0},{0.09856,0,0},{0.19578,0,0},{0.23042,1,0},{0.26355,0,0},{0.42018,0,0},{0.44578,1,0},{0.47741,0,0},{0.61596,0,0},{0.64608,1,0},{0.67319,0,0},{0.73193,0,0},{0.74849,1,0},{0.76657,0,0},{0.80066,0,0},{1,1,0}}},["Texture"]="rbxassetid://9710377531",["Orientation"]={"E","ParticleOrientation","VelocityParallel"},["Size"]={"NS",{{0,0,0},{0.05567,0.21385,0.010984},{0.096907,2.1653,0.55128},{0.11959,0.26732,0.021617},{0.19934,0.21333,0.037926},{0.24849,0.52165,0.037926},{0.3,0.082184,0.037926},{0.4,0.094068,0.037926},{0.42771,0.27973,0.037103},{0.44578,0,0},{0.50515,1.6039,0.035308},{0.52711,0.50653,0.034213},{0.54819,0,0},{0.57831,0.30997,0.032661},{0.6567,0.071111,0.030286},{0.74096,0.43849,0.02509},{0.7997,0.31753,0.023703},{0.8238,0,0},{0.87801,0.19657,0.014436},{1,0,0}}},["LightEmission"]=1,["Squash"]={"NS",{{0,0.825,0},{0.034021,0.75,0},{0.078351,-0.1125,0},{0.10928,0.75,0},{0.7741,-0.225,0},{1,-0.3,0.7125}}}},{["EmitCount"]=25,["EmitDelay"]=0}},{"ParticleEmitter","Specs",{["Color"]={"CS",{{0,0.21961,0.4,1},{1,0.21961,0.4,1}}},["Drag"]=5,["ZOffset"]=1.7108,["VelocitySpread"]=-45,["Lifetime"]={"NR",0.2,1},["Speed"]={"NR",12.831,30.795},["Brightness"]=100,["SpreadAngle"]={"V2",-45,45},["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["LockedToPart"]=true,["Rate"]=10,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{0.54124,0,0},{1,0.9625,0}}},["Texture"]="rbxassetid://10556232026",["LightEmission"]=1,["Size"]={"NS",{{0,0,0},{0.2,0.92921,4.2771},{0.4,1.9554,4.2771},{0.6,2.9953,4.2771},{0.8,3.8773,4.2771},{1,4.2771,4.2771}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["FlipbookStartRandom"]=true},{["EmitCount"]=200,["EmitDelay"]=0}},{"ParticleEmitter","Smoke",{["Color"]={"CS",{{0,0,0.29804,1},{1,0,0.29804,1}}},["Drag"]=6,["ZOffset"]=0.14203,["LightInfluence"]=0.25,["Lifetime"]={"NR",2,3},["Speed"]={"NR",14,14},["SpreadAngle"]={"V2",0,1000},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.10896,0.9375,0},{0.18698,0.9,0},{0.23038,0.75,0},{0.26777,0.54375,0},{0.3338,0.44375,0},{0.39889,0.81875,0},{0.49908,0.9375,0},{0.60665,0.96875,0},{0.69945,0.94375,0},{0.79917,0.95625,0},{0.89982,0.98125,0},{1,1,0}}},["EmissionDirection"]={"E","NormalId","Left"},["LightEmission"]=1,["Texture"]="rbxassetid://9860410723",["Size"]={"NS",{{0,0.22899,0.22899},{0.16314,1.7804,0.29717},{0.35866,2.7818,0.32917},{0.52802,3.1379,0.34348},{1,3.5607,0}}},["Squash"]={"NS",{{0,0,0.45},{0.49934,0.0375,0},{1,0,0}}}},{["EmitCount"]=10,["EmitDelay"]=0}}}},{"Attachment","Attachment",{["CFrame"]={"CF",0,5.3562,0,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,5.3562,0}}},{"ParticleEmitter","Lightning",{["Color"]={"CS",{{0,0,0.34902,1},{1,0,0.34902,1}}},["ZOffset"]=4,["VelocitySpread"]=-360,["Lifetime"]={"NR",0.2,0.55},["Speed"]={"NR",0.0010192,0.0010192},["Brightness"]=3,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["SpreadAngle"]={"V2",-360,360},["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["LockedToPart"]=true,["Rate"]=4,["Texture"]="rbxassetid://11363411020",["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{1,0,0}}},["Size"]={"NS",{{0,5.6523,0},{1,5.6523,0}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Orientation"]={"E","ParticleOrientation","VelocityParallel"},["FlipbookFramerate"]={"NR",3.9,3.9},["LightEmission"]=1},{["EmitCount"]=7,["EmitDelay"]=0}},{"ParticleEmitter","Smoke",{["Color"]={"CS",{{0,0,0.29804,1},{1,0,0.29804,1}}},["Drag"]=6,["ZOffset"]=0.24348,["LightInfluence"]=0.25,["Lifetime"]={"NR",2,3},["Speed"]={"NR",0.0018312,0.0018312},["SpreadAngle"]={"V2",0,60},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.10896,0.9375,0},{0.18698,0.9,0},{0.23038,0.75,0},{0.26777,0.54375,0},{0.3338,0.44375,0},{0.39889,0.81875,0},{0.49908,0.9375,0},{0.60665,0.96875,0},{0.69945,0.94375,0},{0.79917,0.95625,0},{0.89982,0.98125,0},{1,1,0}}},["EmissionDirection"]={"E","NormalId","Front"},["LightEmission"]=1,["Texture"]="rbxassetid://9860410723",["Size"]={"NS",{{0,0.39254,0.39254},{0.16314,3.052,0.50941},{0.35866,4.7687,0.56427},{0.52802,5.3791,0.58881},{1,6.1039,0}}},["Squash"]={"NS",{{0,0,0.45},{0.49934,0.0375,0},{1,0,0}}}},{["EmitCount"]=10,["EmitDelay"]=0}}},1},{"Part","Fire",{["CFrame"]={"CF",12.392,0,0,1,0,0,0,1,0,0,0,1},["Size"]={"V3",2,7.0265,2}},nil,nil,{{"Attachment","Attachment",{["CFrame"]={"CF",0,-3.6776,0,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,-3.6776,0}},nil,nil,{{"Beam","Beam",{["FaceCamera"]=true,["Color"]={"CS",{{0,1,0.35686,0.16078},{1,1,0.35686,0.16078}}},["ZOffset"]=1,["Width0"]=0,["Texture"]="rbxassetid://9589762590",["Transparency"]={"NS",{{0,0,0},{1,1,0}}},["Width1"]=25,["Brightness"]=10,["TextureMode"]={"E","TextureMode","Static"},["TextureLength"]=10},nil,{["Attachment1"]={3,2},["Attachment0"]={3,1}}},{"ParticleEmitter","Spin",{["FlipbookFramerate"]={"NR",15,15},["Drag"]=3.25,["Lifetime"]={"NR",0.59043,1.1809},["Speed"]={"NR",18,18},["Brightness"]=5,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid8x8"},["Size"]={"NS",{{0,0,0},{0.2,2.5541,0},{0.4,4.0449,0},{0.6,5.1901,0},{0.8,6.4133,0},{1,10,0}}},["FlipbookMode"]={"E","ParticleFlipbookMode","PingPong"},["RotSpeed"]={"NR",-1600,-860},["LockedToPart"]=true,["Rate"]=15,["Transparency"]={"NS",{{0,0,0},{0.71653,0,0},{0.83887,0.76875,0},{1,1,0}}},["Texture"]="rbxassetid://12350085716",["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Color"]={"CS",{{0,1,0.35686,0.16078},{1,1,0.35686,0.16078}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}}},{["EmitCount"]=2,["EmitDelay"]=0}},{"ParticleEmitter","Lines 3",{["Color"]={"CS",{{0,1,0.35686,0.16078},{1,1,0.35686,0.16078}}},["Drag"]=5,["ZOffset"]=0.055849,["VelocitySpread"]=-45,["Lifetime"]={"NR",0.2,2},["Speed"]={"NR",59,59},["Brightness"]=100,["SpreadAngle"]={"V2",-45,45},["Acceleration"]={"V3",0,-30.948,0},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-90,-90},["Transparency"]={"NS",{{0,1,0},{0.09856,0,0},{0.19578,0,0},{0.23042,1,0},{0.26355,0,0},{0.42018,0,0},{0.44578,1,0},{0.47741,0,0},{0.61596,0,0},{0.64608,1,0},{0.67319,0,0},{0.73193,0,0},{0.74849,1,0},{0.76657,0,0},{0.80066,0,0},{1,1,0}}},["Texture"]="rbxassetid://9589739468",["Orientation"]={"E","ParticleOrientation","VelocityParallel"},["Size"]={"NS",{{0,0,0},{0.05567,0.51594,0},{0.096907,0.51594,0},{0.11959,0.51594,0},{0.19934,0.51594,0},{0.24849,0.51594,0},{0.3,0.51594,0},{0.4,0.51594,0},{0.42771,0.51594,0},{0.44578,0,0},{0.50515,0.51594,0},{0.52711,0.51594,0},{0.54819,0,0},{0.57831,0.51594,0},{0.6567,0.51594,0},{0.74096,0.51594,0},{0.7997,0.51594,0},{0.8238,0,0},{0.87801,0.51594,0},{1,0,0}}},["Squash"]={"NS",{{0,0.825,0},{0.034021,0.75,0},{0.078351,-0.1125,0},{0.10928,0.75,0},{0.7741,-0.225,0},{1,-0.3,0.7125}}},["LightEmission"]=1},{["EmitCount"]=25,["EmitDelay"]=0}},{"ParticleEmitter","Specs",{["Color"]={"CS",{{0,1,0.35686,0.16078},{1,1,0.35686,0.16078}}},["Drag"]=5,["ZOffset"]=1.7108,["VelocitySpread"]=-45,["Lifetime"]={"NR",0.2,1},["Speed"]={"NR",12.831,30.795},["Brightness"]=100,["SpreadAngle"]={"V2",-45,45},["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["LockedToPart"]=true,["Rate"]=10,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{0.54124,0,0},{1,0.9625,0}}},["Texture"]="rbxassetid://10556232026",["LightEmission"]=1,["Size"]={"NS",{{0,0,0},{0.2,0.92921,4.2771},{0.4,1.9554,4.2771},{0.6,2.9953,4.2771},{0.8,3.8773,4.2771},{1,4.2771,4.2771}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["FlipbookStartRandom"]=true},{["EmitCount"]=200,["EmitDelay"]=0}},{"ParticleEmitter","Smoke",{["Color"]={"CS",{{0,1,0.35686,0.16078},{1,1,0.35686,0.16078}}},["Drag"]=6,["ZOffset"]=0.12413,["LightInfluence"]=0.25,["Lifetime"]={"NR",2,3},["Speed"]={"NR",9,16},["SpreadAngle"]={"V2",0,1000},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.10896,0.9375,0},{0.18698,0.9,0},{0.23038,0.75,0},{0.26777,0.54375,0},{0.3338,0.44375,0},{0.39889,0.81875,0},{0.49908,0.9375,0},{0.60665,0.96875,0},{0.69945,0.94375,0},{0.79917,0.95625,0},{0.89982,0.98125,0},{1,1,0}}},["EmissionDirection"]={"E","NormalId","Left"},["LightEmission"]=1,["Texture"]="rbxassetid://9860410723",["Size"]={"NS",{{0,0.20012,0.20012},{0.16314,1.5559,0.2597},{0.35866,2.4311,0.28767},{0.52802,2.7423,0.30018},{1,3.1118,0}}},["Squash"]={"NS",{{0,0,0.45},{0.49934,0.0375,0},{1,0,0}}}},{["EmitCount"]=10,["EmitDelay"]=0}},{"ParticleEmitter","Fire",{["FlipbookFramerate"]={"NR",30,30},["Drag"]=11,["ZOffset"]=0.99722,["VelocitySpread"]=35,["Lifetime"]={"NR",0.4,1},["Speed"]={"NR",7.978,69.555},["Brightness"]=100,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["SpreadAngle"]={"V2",35,35},["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["RotSpeed"]={"NR",-50,50},["LockedToPart"]=true,["Rate"]=10,["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{1,0,0}}},["Texture"]="rbxassetid://11418708306",["Size"]={"NS",{{0,0.59292,0.30387},{0.12202,1.1507,0.17431},{0.3866,2.3301,0.097922},{0.73475,3.7397,0.07289},{1,4.6027,0}}},["Color"]={"CS",{{0,1,0.082353,0},{1,1,0.082353,0}}},["Shape"]={"E","ParticleEmitterShape","Disc"}},{["EmitCount"]=15,["EmitDelay"]=0}},{"ParticleEmitter","Fire 2",{["FlipbookFramerate"]={"NR",60,60},["Drag"]=5,["ZOffset"]=0.12609,["Lifetime"]={"NR",1,1},["Speed"]={"NR",27,27},["Brightness"]=30,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["Size"]={"NS",{{0,2.1027,1.0187},{1,2.1027,1.0448}}},["RotSpeed"]={"NR",-1200,-360},["LockedToPart"]=true,["Rate"]=3,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{0.7167,0,0},{0.76744,0.39752,0},{0.83562,0.81366,0},{0.92653,0.95652,0},{1,1,0}}},["Texture"]="rbxassetid://11977056412",["LightEmission"]=0.25,["Color"]={"CS",{{0,1,0.14902,0},{1,1,0.14902,0}}},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Squash"]={"NS",{{0,0,0},{1,0,0}}}}},{"ParticleEmitter","Fire 2",{["FlipbookFramerate"]={"NR",60,60},["Drag"]=5,["ZOffset"]=0.25874,["Lifetime"]={"NR",1,1},["Speed"]={"NR",0.0061561,0.0061561},["Brightness"]=30,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["Size"]={"NS",{{0,4.3147,2.0904},{1,4.3147,2.144}}},["RotSpeed"]={"NR",-1200,-360},["LockedToPart"]=true,["Rate"]=3,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{0.7167,0,0},{0.76744,0.39752,0},{0.83562,0.81366,0},{0.92653,0.95652,0},{1,1,0}}},["Texture"]="rbxassetid://11977056412",["LightEmission"]=0.25,["Color"]={"CS",{{0,1,0.14902,0},{1,1,0.14902,0}}},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Squash"]={"NS",{{0,0,0},{1,0,0}}}}}}},{"Attachment","Attachment",{["CFrame"]={"CF",0,5.3562,0,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,5.3562,0}}},{"ParticleEmitter","Smoke",{["Color"]={"CS",{{0,1,0.35686,0.16078},{1,1,0.35686,0.16078}}},["Drag"]=6,["ZOffset"]=0.24348,["LightInfluence"]=0.25,["Lifetime"]={"NR",2,3},["Speed"]={"NR",0.0018312,0.0018312},["SpreadAngle"]={"V2",0,60},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.10896,0.9375,0},{0.18698,0.9,0},{0.23038,0.75,0},{0.26777,0.54375,0},{0.3338,0.44375,0},{0.39889,0.81875,0},{0.49908,0.9375,0},{0.60665,0.96875,0},{0.69945,0.94375,0},{0.79917,0.95625,0},{0.89982,0.98125,0},{1,1,0}}},["EmissionDirection"]={"E","NormalId","Front"},["LightEmission"]=1,["Texture"]="rbxassetid://9860410723",["Size"]={"NS",{{0,0.39254,0.39254},{0.16314,3.052,0.50941},{0.35866,4.7687,0.56427},{0.52802,5.3791,0.58881},{1,6.1039,0}}},["Squash"]={"NS",{{0,0,0.45},{0.49934,0.0375,0},{1,0,0}}}},{["EmitCount"]=10,["EmitDelay"]=0}}},1},{"Part","Earth",{["CFrame"]={"CF",24.518,0,0,1,0,0,0,1,0,0,0,1},["Size"]={"V3",2,7.0265,2}},nil,nil,{{"Attachment","Attachment",{["CFrame"]={"CF",0,-3.6776,0,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,-3.6776,0}},nil,nil,{{"Beam","Beam",{["FaceCamera"]=true,["Color"]={"CS",{{0,0.22353,0.17647,0.13333},{1,0.22353,0.17647,0.13333}}},["ZOffset"]=1,["Width0"]=0,["Texture"]="rbxassetid://9589762590",["Transparency"]={"NS",{{0,0,0},{1,1,0}}},["Width1"]=40,["Brightness"]=10,["TextureMode"]={"E","TextureMode","Static"},["TextureLength"]=10},nil,{["Attachment1"]={4,2},["Attachment0"]={4,1}}},{"ParticleEmitter","Spin",{["FlipbookFramerate"]={"NR",15,15},["Drag"]=3.25,["Lifetime"]={"NR",0.59043,1.1809},["Speed"]={"NR",18,18},["Brightness"]=5,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid8x8"},["Size"]={"NS",{{0,0,0},{0.2,2.5541,0},{0.4,4.0449,0},{0.6,5.1901,0},{0.8,6.4133,0},{1,10,0}}},["FlipbookMode"]={"E","ParticleFlipbookMode","PingPong"},["RotSpeed"]={"NR",-1600,-860},["LockedToPart"]=true,["Transparency"]={"NS",{{0,0,0},{0.71653,0,0},{0.83887,0.76875,0},{1,1,0}}},["Texture"]="rbxassetid://12350085716",["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Color"]={"CS",{{0,0.22353,0.17647,0.13333},{1,0.22353,0.17647,0.13333}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}}},{["EmitCount"]=2,["EmitDelay"]=0}},{"ParticleEmitter","Specs",{["Color"]={"CS",{{0,0.22353,0.17647,0.13333},{1,0.22353,0.17647,0.13333}}},["Drag"]=5,["ZOffset"]=1.7108,["VelocitySpread"]=-45,["Lifetime"]={"NR",0.2,1},["Speed"]={"NR",12.831,30.795},["Brightness"]=10,["SpreadAngle"]={"V2",-45,45},["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["LockedToPart"]=true,["Rate"]=10,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{0.54124,0,0},{1,0.9625,0}}},["Texture"]="rbxassetid://10556232026",["LightEmission"]=1,["Size"]={"NS",{{0,0,0},{0.2,0.92921,4.2771},{0.4,1.9554,4.2771},{0.6,2.9953,4.2771},{0.8,3.8773,4.2771},{1,4.2771,4.2771}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["FlipbookStartRandom"]=true},{["EmitCount"]=200,["EmitDelay"]=0}},{"ParticleEmitter","Smoke",{["Color"]={"CS",{{0,0.22353,0.17647,0.13333},{1,0.22353,0.17647,0.13333}}},["Drag"]=6,["ZOffset"]=0.12413,["LightInfluence"]=0.25,["Lifetime"]={"NR",2,3},["Speed"]={"NR",9,16},["SpreadAngle"]={"V2",0,1000},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.10896,0.9375,0},{0.18698,0.9,0},{0.23038,0.75,0},{0.26777,0.54375,0},{0.3338,0.44375,0},{0.39889,0.81875,0},{0.49908,0.9375,0},{0.60665,0.96875,0},{0.69945,0.94375,0},{0.79917,0.95625,0},{0.89982,0.98125,0},{1,1,0}}},["EmissionDirection"]={"E","NormalId","Left"},["LightEmission"]=1,["Texture"]="rbxassetid://9860410723",["Size"]={"NS",{{0,0.20012,0.20012},{0.16314,1.5559,0.2597},{0.35866,2.4311,0.28767},{0.52802,2.7423,0.30018},{1,3.1118,0}}},["Squash"]={"NS",{{0,0,0.45},{0.49934,0.0375,0},{1,0,0}}}},{["EmitCount"]=10,["EmitDelay"]=0}}}},{"Attachment","Attachment",{["CFrame"]={"CF",0,5.3562,0,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,5.3562,0}}},{"ParticleEmitter","Smoke",{["Color"]={"CS",{{0,0.22353,0.17647,0.13333},{1,0.22353,0.17647,0.13333}}},["Drag"]=6,["ZOffset"]=0.24348,["LightInfluence"]=0.25,["Lifetime"]={"NR",2,3},["Speed"]={"NR",0.0018312,0.0018312},["SpreadAngle"]={"V2",0,60},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.10896,0.9375,0},{0.18698,0.9,0},{0.23038,0.75,0},{0.26777,0.54375,0},{0.3338,0.44375,0},{0.39889,0.81875,0},{0.49908,0.9375,0},{0.60665,0.96875,0},{0.69945,0.94375,0},{0.79917,0.95625,0},{0.89982,0.98125,0},{1,1,0}}},["EmissionDirection"]={"E","NormalId","Front"},["LightEmission"]=1,["Texture"]="rbxassetid://9860410723",["Size"]={"NS",{{0,0.39254,0.39254},{0.16314,3.052,0.50941},{0.35866,4.7687,0.56427},{0.52802,5.3791,0.58881},{1,6.1039,0}}},["Squash"]={"NS",{{0,0,0.45},{0.49934,0.0375,0},{1,0,0}}}},{["EmitCount"]=10,["EmitDelay"]=0}}},1},{"Part","Poison",{["CFrame"]={"CF",35.73,0,0,1,0,0,0,1,0,0,0,1},["Size"]={"V3",2,7.0265,2}},nil,nil,{{"Attachment","Attachment",{["CFrame"]={"CF",0,-3.6776,0,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,-3.6776,0}},nil,nil,{{"Beam","Beam",{["FaceCamera"]=true,["Color"]={"CS",{{0,0.54902,1,0.031373},{1,0.54902,1,0.031373}}},["ZOffset"]=1,["Width0"]=0,["Texture"]="rbxassetid://9589762590",["Transparency"]={"NS",{{0,0,0},{1,1,0}}},["Width1"]=25,["Brightness"]=10,["TextureMode"]={"E","TextureMode","Static"},["TextureLength"]=10},nil,{["Attachment1"]={5,2},["Attachment0"]={5,1}}},{"ParticleEmitter","Spin",{["FlipbookFramerate"]={"NR",15,15},["Drag"]=3.25,["Lifetime"]={"NR",0.59043,1.1809},["Speed"]={"NR",18,18},["Brightness"]=3,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid8x8"},["Size"]={"NS",{{0,0,0},{0.2,2.5541,0},{0.4,4.0449,0},{0.6,5.1901,0},{0.8,6.4133,0},{1,10,0}}},["FlipbookMode"]={"E","ParticleFlipbookMode","PingPong"},["RotSpeed"]={"NR",-1600,-860},["LockedToPart"]=true,["Rate"]=15,["Transparency"]={"NS",{{0,0,0},{0.71653,0,0},{0.83887,0.76875,0},{1,1,0}}},["Texture"]="rbxassetid://12350085716",["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Color"]={"CS",{{0,0.54902,1,0.031373},{1,0.54902,1,0.031373}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}}},{["EmitCount"]=2,["EmitDelay"]=0}},{"ParticleEmitter","Specs",{["Color"]={"CS",{{0,0.54902,1,0.031373},{1,0.54902,1,0.031373}}},["Drag"]=5,["ZOffset"]=1.7108,["VelocitySpread"]=-35,["Lifetime"]={"NR",0.2,1},["Speed"]={"NR",12.831,30.795},["Brightness"]=100,["SpreadAngle"]={"V2",-35,35},["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["LockedToPart"]=true,["Rate"]=10,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{0.54124,0,0},{1,0.9625,0}}},["Texture"]="rbxassetid://10556232026",["LightEmission"]=1,["Size"]={"NS",{{0,0,0},{0.2,0.92921,4.2771},{0.4,1.9554,4.2771},{0.6,2.9953,4.2771},{0.8,3.8773,4.2771},{1,4.2771,4.2771}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["FlipbookStartRandom"]=true},{["EmitCount"]=200,["EmitDelay"]=0}},{"ParticleEmitter","Smoke",{["Color"]={"CS",{{0,0.54902,1,0.031373},{1,0.54902,1,0.031373}}},["Drag"]=6,["ZOffset"]=0.12413,["LightInfluence"]=0.25,["Lifetime"]={"NR",2,3},["Speed"]={"NR",9,16},["SpreadAngle"]={"V2",0,1000},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.10896,0.9375,0},{0.18698,0.9,0},{0.23038,0.75,0},{0.26777,0.54375,0},{0.3338,0.44375,0},{0.39889,0.81875,0},{0.49908,0.9375,0},{0.60665,0.96875,0},{0.69945,0.94375,0},{0.79917,0.95625,0},{0.89982,0.98125,0},{1,1,0}}},["EmissionDirection"]={"E","NormalId","Left"},["LightEmission"]=1,["Texture"]="rbxassetid://9860410723",["Size"]={"NS",{{0,0.20012,0.20012},{0.16314,1.5559,0.2597},{0.35866,2.4311,0.28767},{0.52802,2.7423,0.30018},{1,3.1118,0}}},["Squash"]={"NS",{{0,0,0.45},{0.49934,0.0375,0},{1,0,0}}}},{["EmitCount"]=10,["EmitDelay"]=0}},{"Beam","Beam",{["FaceCamera"]=true,["Color"]={"CS",{{0,0.54902,1,0.031373},{1,0.54902,1,0.031373}}},["TextureSpeed"]=0.2,["ZOffset"]=1,["Width0"]=0,["Texture"]="rbxassetid://9589826891",["Transparency"]={"NS",{{0,0,0},{0.62789,0.94375,0},{1,1,0}}},["Width1"]=25,["Brightness"]=10,["TextureMode"]={"E","TextureMode","Static"},["TextureLength"]=170},nil,{["Attachment1"]={5,2},["Attachment0"]={5,1}}},{"Beam","Beam",{["FaceCamera"]=true,["Color"]={"CS",{{0,0.54902,1,0.031373},{1,0.54902,1,0.031373}}},["TextureSpeed"]=0.3,["ZOffset"]=1,["Width0"]=0,["Texture"]="rbxassetid://9589826891",["Transparency"]={"NS",{{0,0,0},{0.53924,0.94375,0},{1,1,0}}},["Width1"]=25,["Brightness"]=10,["TextureMode"]={"E","TextureMode","Static"},["TextureLength"]=240},nil,{["Attachment1"]={5,2},["Attachment0"]={5,1}}}}},{"Attachment","Attachment",{["CFrame"]={"CF",0,5.3562,0,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,5.3562,0}}},{"ParticleEmitter","Smoke",{["Color"]={"CS",{{0,0.54902,1,0.031373},{1,0.54902,1,0.031373}}},["Drag"]=6,["ZOffset"]=0.24348,["LightInfluence"]=0.25,["Lifetime"]={"NR",2,3},["Speed"]={"NR",0.0018312,0.0018312},["SpreadAngle"]={"V2",0,60},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.10896,0.9375,0},{0.18698,0.9,0},{0.23038,0.75,0},{0.26777,0.54375,0},{0.3338,0.44375,0},{0.39889,0.81875,0},{0.49908,0.9375,0},{0.60665,0.96875,0},{0.69945,0.94375,0},{0.79917,0.95625,0},{0.89982,0.98125,0},{1,1,0}}},["EmissionDirection"]={"E","NormalId","Front"},["LightEmission"]=1,["Texture"]="rbxassetid://9860410723",["Size"]={"NS",{{0,0.39254,0.39254},{0.16314,3.052,0.50941},{0.35866,4.7687,0.56427},{0.52802,5.3791,0.58881},{1,6.1039,0}}},["Squash"]={"NS",{{0,0,0.45},{0.49934,0.0375,0},{1,0,0}}}},{["EmitCount"]=10,["EmitDelay"]=0}}},1}},
        	["Tornado Acid"] = {{"Part","Wind",{["CFrame"]={"CF",0,0,0,1,0,0,0,1,0,0,0,1},["Size"]={"V3",2,7.0265,2}},nil,nil,{{"Attachment","Attachment",{["CFrame"]={"CF",0,-3.6776,0,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,-3.6776,0}},nil,nil,{{"Beam","Beam",{["FaceCamera"]=true,["Color"]={"CS",{{0,0.6,0.82745,1},{1,0.6,0.82745,1}}},["ZOffset"]=1,["Width0"]=0,["Texture"]="rbxassetid://9589762590",["Transparency"]={"NS",{{0,0,0},{1,1,0}}},["Width1"]=25,["Brightness"]=10,["TextureMode"]={"E","TextureMode","Static"},["TextureLength"]=10},nil,{["Attachment1"]={1,2},["Attachment0"]={1,1}}},{"ParticleEmitter","Spin",{["FlipbookFramerate"]={"NR",15,15},["Drag"]=3.25,["Lifetime"]={"NR",0.59043,1.1809},["Speed"]={"NR",18,18},["Brightness"]=3,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid8x8"},["Size"]={"NS",{{0,0,0},{0.2,2.5541,0},{0.4,4.0449,0},{0.6,5.1901,0},{0.8,6.4133,0},{1,10,0}}},["FlipbookMode"]={"E","ParticleFlipbookMode","PingPong"},["RotSpeed"]={"NR",-1600,-860},["LockedToPart"]=true,["Rate"]=15,["Transparency"]={"NS",{{0,0,0},{0.71653,0,0},{0.83887,0.76875,0},{1,1,0}}},["Texture"]="rbxassetid://12350085716",["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Color"]={"CS",{{0,0.72549,0.96471,1},{1,0.72549,0.96471,1}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}}},{["EmitCount"]=2,["EmitDelay"]=0}},{"ParticleEmitter","Specs",{["Color"]={"CS",{{0,0.21961,0.4,1},{1,0.21961,0.4,1}}},["Drag"]=5,["ZOffset"]=1.7108,["VelocitySpread"]=-35,["Lifetime"]={"NR",0.2,1},["Speed"]={"NR",12.831,30.795},["Brightness"]=100,["SpreadAngle"]={"V2",-35,35},["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["LockedToPart"]=true,["Rate"]=10,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{0.54124,0,0},{1,0.9625,0}}},["Texture"]="rbxassetid://10556232026",["LightEmission"]=1,["Size"]={"NS",{{0,0,0},{0.2,0.92921,4.2771},{0.4,1.9554,4.2771},{0.6,2.9953,4.2771},{0.8,3.8773,4.2771},{1,4.2771,4.2771}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["FlipbookStartRandom"]=true},{["EmitCount"]=200,["EmitDelay"]=0}},{"ParticleEmitter","Smoke",{["Color"]={"CS",{{0,0.6,0.82745,1},{1,0.6,0.82745,1}}},["Drag"]=6,["ZOffset"]=0.12413,["LightInfluence"]=0.25,["Lifetime"]={"NR",2,3},["Speed"]={"NR",9,16},["SpreadAngle"]={"V2",0,1000},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.10896,0.9375,0},{0.18698,0.9,0},{0.23038,0.75,0},{0.26777,0.54375,0},{0.3338,0.44375,0},{0.39889,0.81875,0},{0.49908,0.9375,0},{0.60665,0.96875,0},{0.69945,0.94375,0},{0.79917,0.95625,0},{0.89982,0.98125,0},{1,1,0}}},["EmissionDirection"]={"E","NormalId","Left"},["LightEmission"]=1,["Texture"]="rbxassetid://9860410723",["Size"]={"NS",{{0,0.20012,0.20012},{0.16314,1.5559,0.2597},{0.35866,2.4311,0.28767},{0.52802,2.7423,0.30018},{1,3.1118,0}}},["Squash"]={"NS",{{0,0,0.45},{0.49934,0.0375,0},{1,0,0}}}},{["EmitCount"]=10,["EmitDelay"]=0}},{"Beam","Beam",{["FaceCamera"]=true,["Color"]={"CS",{{0,0.6,0.82745,1},{1,0.6,0.82745,1}}},["TextureSpeed"]=0.2,["ZOffset"]=1,["Width0"]=0,["Texture"]="rbxassetid://9589826891",["Transparency"]={"NS",{{0,0,0},{0.62789,0.94375,0},{1,1,0}}},["Width1"]=25,["Brightness"]=10,["TextureMode"]={"E","TextureMode","Static"},["TextureLength"]=170},nil,{["Attachment1"]={1,2},["Attachment0"]={1,1}}},{"Beam","Beam",{["FaceCamera"]=true,["Color"]={"CS",{{0,0.6,0.82745,1},{1,0.6,0.82745,1}}},["TextureSpeed"]=0.3,["ZOffset"]=1,["Width0"]=0,["Texture"]="rbxassetid://9589826891",["Transparency"]={"NS",{{0,0,0},{0.53924,0.94375,0},{1,1,0}}},["Width1"]=25,["Brightness"]=10,["TextureMode"]={"E","TextureMode","Static"},["TextureLength"]=240},nil,{["Attachment1"]={1,2},["Attachment0"]={1,1}}}}},{"Attachment","Attachment",{["CFrame"]={"CF",0,5.3562,0,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,5.3562,0}}},{"ParticleEmitter","Smoke",{["Color"]={"CS",{{0,0.6,0.82745,1},{1,0.6,0.82745,1}}},["Drag"]=6,["ZOffset"]=0.24348,["LightInfluence"]=0.25,["Lifetime"]={"NR",2,3},["Speed"]={"NR",0.0018312,0.0018312},["SpreadAngle"]={"V2",0,60},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.10896,0.9375,0},{0.18698,0.9,0},{0.23038,0.75,0},{0.26777,0.54375,0},{0.3338,0.44375,0},{0.39889,0.81875,0},{0.49908,0.9375,0},{0.60665,0.96875,0},{0.69945,0.94375,0},{0.79917,0.95625,0},{0.89982,0.98125,0},{1,1,0}}},["EmissionDirection"]={"E","NormalId","Front"},["LightEmission"]=1,["Texture"]="rbxassetid://9860410723",["Size"]={"NS",{{0,0.39254,0.39254},{0.16314,3.052,0.50941},{0.35866,4.7687,0.56427},{0.52802,5.3791,0.58881},{1,6.1039,0}}},["Squash"]={"NS",{{0,0,0.45},{0.49934,0.0375,0},{1,0,0}}}},{["EmitCount"]=10,["EmitDelay"]=0}}},1},{"Part","Lightning",{["CFrame"]={"CF",-11.973,0,0,1,0,0,0,1,0,0,0,1},["Size"]={"V3",2,7.0265,2}},nil,nil,{{"Attachment","Attachment",{["CFrame"]={"CF",0,-3.6776,0,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,-3.6776,0}},nil,nil,{{"Beam","Beam",{["FaceCamera"]=true,["Color"]={"CS",{{0,0,0.29804,1},{1,0,0.29804,1}}},["ZOffset"]=1,["Width0"]=0,["Texture"]="rbxassetid://9589762590",["Transparency"]={"NS",{{0,0,0},{1,1,0}}},["Width1"]=25,["Brightness"]=10,["TextureMode"]={"E","TextureMode","Static"},["TextureLength"]=10},nil,{["Attachment1"]={2,2},["Attachment0"]={2,1}}},{"ParticleEmitter","Spin",{["FlipbookFramerate"]={"NR",15,15},["Drag"]=3.25,["Lifetime"]={"NR",0.59043,1.1809},["Speed"]={"NR",18,18},["Brightness"]=5,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid8x8"},["Size"]={"NS",{{0,0,0},{0.2,2.5541,0},{0.4,4.0449,0},{0.6,5.1901,0},{0.8,6.4133,0},{1,10,0}}},["FlipbookMode"]={"E","ParticleFlipbookMode","PingPong"},["RotSpeed"]={"NR",-1600,-860},["LockedToPart"]=true,["Rate"]=15,["Transparency"]={"NS",{{0,0,0},{0.71653,0,0},{0.83887,0.76875,0},{1,1,0}}},["Texture"]="rbxassetid://12350085716",["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Color"]={"CS",{{0,0.20784,0.5098,1},{1,0.20784,0.5098,1}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}}},{["EmitCount"]=2,["EmitDelay"]=0}},{"ParticleEmitter","Lines ",{["Color"]={"CS",{{0,0.13333,0.43529,1},{1,0.13333,0.43529,1}}},["Drag"]=3,["ZOffset"]=0.60482,["VelocitySpread"]=-45,["Lifetime"]={"NR",0.2,0.7},["Speed"]={"NR",8.8728,51.962},["Brightness"]=100,["SpreadAngle"]={"V2",-45,45},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-90,-90},["Transparency"]={"NS",{{0,1,0},{0.09856,0,0},{0.19578,0,0},{0.23042,1,0},{0.26355,0,0},{0.42018,0,0},{0.44578,1,0},{0.47741,0,0},{0.61596,0,0},{0.64608,1,0},{0.67319,0,0},{0.73193,0,0},{0.74849,1,0},{0.76657,0,0},{0.80066,0,0},{1,1,0}}},["Texture"]="rbxassetid://7828271118",["LightEmission"]=1,["Size"]={"NS",{{0,0,0},{0.5,0.88215,0},{1,0,0}}},["Orientation"]={"E","ParticleOrientation","VelocityParallel"},["Squash"]={"NS",{{0,0,0},{1,0,0}}}},{["EmitCount"]=25,["EmitDelay"]=0}},{"ParticleEmitter","Lines 3",{["Color"]={"CS",{{0,0.16471,0.3451,1},{1,0.16471,0.3451,1}}},["Drag"]=5,["ZOffset"]=0.60482,["VelocitySpread"]=-45,["Lifetime"]={"NR",0.2,2},["Speed"]={"NR",4.596,91.962},["Brightness"]=100,["SpreadAngle"]={"V2",-45,45},["Acceleration"]={"V3",0,-50,0},["Rate"]=5,["Rotation"]={"NR",-90,-90},["Transparency"]={"NS",{{0,1,0},{0.09856,0,0},{0.19578,0,0},{0.23042,1,0},{0.26355,0,0},{0.42018,0,0},{0.44578,1,0},{0.47741,0,0},{0.61596,0,0},{0.64608,1,0},{0.67319,0,0},{0.73193,0,0},{0.74849,1,0},{0.76657,0,0},{0.80066,0,0},{1,1,0}}},["Texture"]="rbxassetid://9710377531",["Orientation"]={"E","ParticleOrientation","VelocityParallel"},["Size"]={"NS",{{0,0,0},{0.05567,0.21385,0.010984},{0.096907,2.1653,0.55128},{0.11959,0.26732,0.021617},{0.19934,0.21333,0.037926},{0.24849,0.52165,0.037926},{0.3,0.082184,0.037926},{0.4,0.094068,0.037926},{0.42771,0.27973,0.037103},{0.44578,0,0},{0.50515,1.6039,0.035308},{0.52711,0.50653,0.034213},{0.54819,0,0},{0.57831,0.30997,0.032661},{0.6567,0.071111,0.030286},{0.74096,0.43849,0.02509},{0.7997,0.31753,0.023703},{0.8238,0,0},{0.87801,0.19657,0.014436},{1,0,0}}},["LightEmission"]=1,["Squash"]={"NS",{{0,0.825,0},{0.034021,0.75,0},{0.078351,-0.1125,0},{0.10928,0.75,0},{0.7741,-0.225,0},{1,-0.3,0.7125}}}},{["EmitCount"]=25,["EmitDelay"]=0}},{"ParticleEmitter","Specs",{["Color"]={"CS",{{0,0.21961,0.4,1},{1,0.21961,0.4,1}}},["Drag"]=5,["ZOffset"]=1.7108,["VelocitySpread"]=-45,["Lifetime"]={"NR",0.2,1},["Speed"]={"NR",12.831,30.795},["Brightness"]=100,["SpreadAngle"]={"V2",-45,45},["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["LockedToPart"]=true,["Rate"]=10,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{0.54124,0,0},{1,0.9625,0}}},["Texture"]="rbxassetid://10556232026",["LightEmission"]=1,["Size"]={"NS",{{0,0,0},{0.2,0.92921,4.2771},{0.4,1.9554,4.2771},{0.6,2.9953,4.2771},{0.8,3.8773,4.2771},{1,4.2771,4.2771}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["FlipbookStartRandom"]=true},{["EmitCount"]=200,["EmitDelay"]=0}},{"ParticleEmitter","Smoke",{["Color"]={"CS",{{0,0,0.29804,1},{1,0,0.29804,1}}},["Drag"]=6,["ZOffset"]=0.14203,["LightInfluence"]=0.25,["Lifetime"]={"NR",2,3},["Speed"]={"NR",14,14},["SpreadAngle"]={"V2",0,1000},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.10896,0.9375,0},{0.18698,0.9,0},{0.23038,0.75,0},{0.26777,0.54375,0},{0.3338,0.44375,0},{0.39889,0.81875,0},{0.49908,0.9375,0},{0.60665,0.96875,0},{0.69945,0.94375,0},{0.79917,0.95625,0},{0.89982,0.98125,0},{1,1,0}}},["EmissionDirection"]={"E","NormalId","Left"},["LightEmission"]=1,["Texture"]="rbxassetid://9860410723",["Size"]={"NS",{{0,0.22899,0.22899},{0.16314,1.7804,0.29717},{0.35866,2.7818,0.32917},{0.52802,3.1379,0.34348},{1,3.5607,0}}},["Squash"]={"NS",{{0,0,0.45},{0.49934,0.0375,0},{1,0,0}}}},{["EmitCount"]=10,["EmitDelay"]=0}}}},{"Attachment","Attachment",{["CFrame"]={"CF",0,5.3562,0,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,5.3562,0}}},{"ParticleEmitter","Lightning",{["Color"]={"CS",{{0,0,0.34902,1},{1,0,0.34902,1}}},["ZOffset"]=4,["VelocitySpread"]=-360,["Lifetime"]={"NR",0.2,0.55},["Speed"]={"NR",0.0010192,0.0010192},["Brightness"]=3,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["SpreadAngle"]={"V2",-360,360},["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["LockedToPart"]=true,["Rate"]=4,["Texture"]="rbxassetid://11363411020",["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{1,0,0}}},["Size"]={"NS",{{0,5.6523,0},{1,5.6523,0}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Orientation"]={"E","ParticleOrientation","VelocityParallel"},["FlipbookFramerate"]={"NR",3.9,3.9},["LightEmission"]=1},{["EmitCount"]=7,["EmitDelay"]=0}},{"ParticleEmitter","Smoke",{["Color"]={"CS",{{0,0,0.29804,1},{1,0,0.29804,1}}},["Drag"]=6,["ZOffset"]=0.24348,["LightInfluence"]=0.25,["Lifetime"]={"NR",2,3},["Speed"]={"NR",0.0018312,0.0018312},["SpreadAngle"]={"V2",0,60},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.10896,0.9375,0},{0.18698,0.9,0},{0.23038,0.75,0},{0.26777,0.54375,0},{0.3338,0.44375,0},{0.39889,0.81875,0},{0.49908,0.9375,0},{0.60665,0.96875,0},{0.69945,0.94375,0},{0.79917,0.95625,0},{0.89982,0.98125,0},{1,1,0}}},["EmissionDirection"]={"E","NormalId","Front"},["LightEmission"]=1,["Texture"]="rbxassetid://9860410723",["Size"]={"NS",{{0,0.39254,0.39254},{0.16314,3.052,0.50941},{0.35866,4.7687,0.56427},{0.52802,5.3791,0.58881},{1,6.1039,0}}},["Squash"]={"NS",{{0,0,0.45},{0.49934,0.0375,0},{1,0,0}}}},{["EmitCount"]=10,["EmitDelay"]=0}}},1},{"Part","Fire",{["CFrame"]={"CF",12.392,0,0,1,0,0,0,1,0,0,0,1},["Size"]={"V3",2,7.0265,2}},nil,nil,{{"Attachment","Attachment",{["CFrame"]={"CF",0,-3.6776,0,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,-3.6776,0}},nil,nil,{{"Beam","Beam",{["FaceCamera"]=true,["Color"]={"CS",{{0,1,0.35686,0.16078},{1,1,0.35686,0.16078}}},["ZOffset"]=1,["Width0"]=0,["Texture"]="rbxassetid://9589762590",["Transparency"]={"NS",{{0,0,0},{1,1,0}}},["Width1"]=25,["Brightness"]=10,["TextureMode"]={"E","TextureMode","Static"},["TextureLength"]=10},nil,{["Attachment1"]={3,2},["Attachment0"]={3,1}}},{"ParticleEmitter","Spin",{["FlipbookFramerate"]={"NR",15,15},["Drag"]=3.25,["Lifetime"]={"NR",0.59043,1.1809},["Speed"]={"NR",18,18},["Brightness"]=5,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid8x8"},["Size"]={"NS",{{0,0,0},{0.2,2.5541,0},{0.4,4.0449,0},{0.6,5.1901,0},{0.8,6.4133,0},{1,10,0}}},["FlipbookMode"]={"E","ParticleFlipbookMode","PingPong"},["RotSpeed"]={"NR",-1600,-860},["LockedToPart"]=true,["Rate"]=15,["Transparency"]={"NS",{{0,0,0},{0.71653,0,0},{0.83887,0.76875,0},{1,1,0}}},["Texture"]="rbxassetid://12350085716",["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Color"]={"CS",{{0,1,0.35686,0.16078},{1,1,0.35686,0.16078}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}}},{["EmitCount"]=2,["EmitDelay"]=0}},{"ParticleEmitter","Lines 3",{["Color"]={"CS",{{0,1,0.35686,0.16078},{1,1,0.35686,0.16078}}},["Drag"]=5,["ZOffset"]=0.055849,["VelocitySpread"]=-45,["Lifetime"]={"NR",0.2,2},["Speed"]={"NR",59,59},["Brightness"]=100,["SpreadAngle"]={"V2",-45,45},["Acceleration"]={"V3",0,-30.948,0},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-90,-90},["Transparency"]={"NS",{{0,1,0},{0.09856,0,0},{0.19578,0,0},{0.23042,1,0},{0.26355,0,0},{0.42018,0,0},{0.44578,1,0},{0.47741,0,0},{0.61596,0,0},{0.64608,1,0},{0.67319,0,0},{0.73193,0,0},{0.74849,1,0},{0.76657,0,0},{0.80066,0,0},{1,1,0}}},["Texture"]="rbxassetid://9589739468",["Orientation"]={"E","ParticleOrientation","VelocityParallel"},["Size"]={"NS",{{0,0,0},{0.05567,0.51594,0},{0.096907,0.51594,0},{0.11959,0.51594,0},{0.19934,0.51594,0},{0.24849,0.51594,0},{0.3,0.51594,0},{0.4,0.51594,0},{0.42771,0.51594,0},{0.44578,0,0},{0.50515,0.51594,0},{0.52711,0.51594,0},{0.54819,0,0},{0.57831,0.51594,0},{0.6567,0.51594,0},{0.74096,0.51594,0},{0.7997,0.51594,0},{0.8238,0,0},{0.87801,0.51594,0},{1,0,0}}},["Squash"]={"NS",{{0,0.825,0},{0.034021,0.75,0},{0.078351,-0.1125,0},{0.10928,0.75,0},{0.7741,-0.225,0},{1,-0.3,0.7125}}},["LightEmission"]=1},{["EmitCount"]=25,["EmitDelay"]=0}},{"ParticleEmitter","Specs",{["Color"]={"CS",{{0,1,0.35686,0.16078},{1,1,0.35686,0.16078}}},["Drag"]=5,["ZOffset"]=1.7108,["VelocitySpread"]=-45,["Lifetime"]={"NR",0.2,1},["Speed"]={"NR",12.831,30.795},["Brightness"]=100,["SpreadAngle"]={"V2",-45,45},["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["LockedToPart"]=true,["Rate"]=10,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{0.54124,0,0},{1,0.9625,0}}},["Texture"]="rbxassetid://10556232026",["LightEmission"]=1,["Size"]={"NS",{{0,0,0},{0.2,0.92921,4.2771},{0.4,1.9554,4.2771},{0.6,2.9953,4.2771},{0.8,3.8773,4.2771},{1,4.2771,4.2771}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["FlipbookStartRandom"]=true},{["EmitCount"]=200,["EmitDelay"]=0}},{"ParticleEmitter","Smoke",{["Color"]={"CS",{{0,1,0.35686,0.16078},{1,1,0.35686,0.16078}}},["Drag"]=6,["ZOffset"]=0.12413,["LightInfluence"]=0.25,["Lifetime"]={"NR",2,3},["Speed"]={"NR",9,16},["SpreadAngle"]={"V2",0,1000},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.10896,0.9375,0},{0.18698,0.9,0},{0.23038,0.75,0},{0.26777,0.54375,0},{0.3338,0.44375,0},{0.39889,0.81875,0},{0.49908,0.9375,0},{0.60665,0.96875,0},{0.69945,0.94375,0},{0.79917,0.95625,0},{0.89982,0.98125,0},{1,1,0}}},["EmissionDirection"]={"E","NormalId","Left"},["LightEmission"]=1,["Texture"]="rbxassetid://9860410723",["Size"]={"NS",{{0,0.20012,0.20012},{0.16314,1.5559,0.2597},{0.35866,2.4311,0.28767},{0.52802,2.7423,0.30018},{1,3.1118,0}}},["Squash"]={"NS",{{0,0,0.45},{0.49934,0.0375,0},{1,0,0}}}},{["EmitCount"]=10,["EmitDelay"]=0}},{"ParticleEmitter","Fire",{["FlipbookFramerate"]={"NR",30,30},["Drag"]=11,["ZOffset"]=0.99722,["VelocitySpread"]=35,["Lifetime"]={"NR",0.4,1},["Speed"]={"NR",7.978,69.555},["Brightness"]=100,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["SpreadAngle"]={"V2",35,35},["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["RotSpeed"]={"NR",-50,50},["LockedToPart"]=true,["Rate"]=10,["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{1,0,0}}},["Texture"]="rbxassetid://11418708306",["Size"]={"NS",{{0,0.59292,0.30387},{0.12202,1.1507,0.17431},{0.3866,2.3301,0.097922},{0.73475,3.7397,0.07289},{1,4.6027,0}}},["Color"]={"CS",{{0,1,0.082353,0},{1,1,0.082353,0}}},["Shape"]={"E","ParticleEmitterShape","Disc"}},{["EmitCount"]=15,["EmitDelay"]=0}},{"ParticleEmitter","Fire 2",{["FlipbookFramerate"]={"NR",60,60},["Drag"]=5,["ZOffset"]=0.12609,["Lifetime"]={"NR",1,1},["Speed"]={"NR",27,27},["Brightness"]=30,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["Size"]={"NS",{{0,2.1027,1.0187},{1,2.1027,1.0448}}},["RotSpeed"]={"NR",-1200,-360},["LockedToPart"]=true,["Rate"]=3,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{0.7167,0,0},{0.76744,0.39752,0},{0.83562,0.81366,0},{0.92653,0.95652,0},{1,1,0}}},["Texture"]="rbxassetid://11977056412",["LightEmission"]=0.25,["Color"]={"CS",{{0,1,0.14902,0},{1,1,0.14902,0}}},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Squash"]={"NS",{{0,0,0},{1,0,0}}}}},{"ParticleEmitter","Fire 2",{["FlipbookFramerate"]={"NR",60,60},["Drag"]=5,["ZOffset"]=0.25874,["Lifetime"]={"NR",1,1},["Speed"]={"NR",0.0061561,0.0061561},["Brightness"]=30,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["Size"]={"NS",{{0,4.3147,2.0904},{1,4.3147,2.144}}},["RotSpeed"]={"NR",-1200,-360},["LockedToPart"]=true,["Rate"]=3,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{0.7167,0,0},{0.76744,0.39752,0},{0.83562,0.81366,0},{0.92653,0.95652,0},{1,1,0}}},["Texture"]="rbxassetid://11977056412",["LightEmission"]=0.25,["Color"]={"CS",{{0,1,0.14902,0},{1,1,0.14902,0}}},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Squash"]={"NS",{{0,0,0},{1,0,0}}}}}}},{"Attachment","Attachment",{["CFrame"]={"CF",0,5.3562,0,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,5.3562,0}}},{"ParticleEmitter","Smoke",{["Color"]={"CS",{{0,1,0.35686,0.16078},{1,1,0.35686,0.16078}}},["Drag"]=6,["ZOffset"]=0.24348,["LightInfluence"]=0.25,["Lifetime"]={"NR",2,3},["Speed"]={"NR",0.0018312,0.0018312},["SpreadAngle"]={"V2",0,60},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.10896,0.9375,0},{0.18698,0.9,0},{0.23038,0.75,0},{0.26777,0.54375,0},{0.3338,0.44375,0},{0.39889,0.81875,0},{0.49908,0.9375,0},{0.60665,0.96875,0},{0.69945,0.94375,0},{0.79917,0.95625,0},{0.89982,0.98125,0},{1,1,0}}},["EmissionDirection"]={"E","NormalId","Front"},["LightEmission"]=1,["Texture"]="rbxassetid://9860410723",["Size"]={"NS",{{0,0.39254,0.39254},{0.16314,3.052,0.50941},{0.35866,4.7687,0.56427},{0.52802,5.3791,0.58881},{1,6.1039,0}}},["Squash"]={"NS",{{0,0,0.45},{0.49934,0.0375,0},{1,0,0}}}},{["EmitCount"]=10,["EmitDelay"]=0}}},1},{"Part","Earth",{["CFrame"]={"CF",24.518,0,0,1,0,0,0,1,0,0,0,1},["Size"]={"V3",2,7.0265,2}},nil,nil,{{"Attachment","Attachment",{["CFrame"]={"CF",0,-3.6776,0,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,-3.6776,0}},nil,nil,{{"Beam","Beam",{["FaceCamera"]=true,["Color"]={"CS",{{0,0.22353,0.17647,0.13333},{1,0.22353,0.17647,0.13333}}},["ZOffset"]=1,["Width0"]=0,["Texture"]="rbxassetid://9589762590",["Transparency"]={"NS",{{0,0,0},{1,1,0}}},["Width1"]=40,["Brightness"]=10,["TextureMode"]={"E","TextureMode","Static"},["TextureLength"]=10},nil,{["Attachment1"]={4,2},["Attachment0"]={4,1}}},{"ParticleEmitter","Spin",{["FlipbookFramerate"]={"NR",15,15},["Drag"]=3.25,["Lifetime"]={"NR",0.59043,1.1809},["Speed"]={"NR",18,18},["Brightness"]=5,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid8x8"},["Size"]={"NS",{{0,0,0},{0.2,2.5541,0},{0.4,4.0449,0},{0.6,5.1901,0},{0.8,6.4133,0},{1,10,0}}},["FlipbookMode"]={"E","ParticleFlipbookMode","PingPong"},["RotSpeed"]={"NR",-1600,-860},["LockedToPart"]=true,["Transparency"]={"NS",{{0,0,0},{0.71653,0,0},{0.83887,0.76875,0},{1,1,0}}},["Texture"]="rbxassetid://12350085716",["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Color"]={"CS",{{0,0.22353,0.17647,0.13333},{1,0.22353,0.17647,0.13333}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}}},{["EmitCount"]=2,["EmitDelay"]=0}},{"ParticleEmitter","Specs",{["Color"]={"CS",{{0,0.22353,0.17647,0.13333},{1,0.22353,0.17647,0.13333}}},["Drag"]=5,["ZOffset"]=1.7108,["VelocitySpread"]=-45,["Lifetime"]={"NR",0.2,1},["Speed"]={"NR",12.831,30.795},["Brightness"]=10,["SpreadAngle"]={"V2",-45,45},["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["LockedToPart"]=true,["Rate"]=10,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{0.54124,0,0},{1,0.9625,0}}},["Texture"]="rbxassetid://10556232026",["LightEmission"]=1,["Size"]={"NS",{{0,0,0},{0.2,0.92921,4.2771},{0.4,1.9554,4.2771},{0.6,2.9953,4.2771},{0.8,3.8773,4.2771},{1,4.2771,4.2771}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["FlipbookStartRandom"]=true},{["EmitCount"]=200,["EmitDelay"]=0}},{"ParticleEmitter","Smoke",{["Color"]={"CS",{{0,0.22353,0.17647,0.13333},{1,0.22353,0.17647,0.13333}}},["Drag"]=6,["ZOffset"]=0.12413,["LightInfluence"]=0.25,["Lifetime"]={"NR",2,3},["Speed"]={"NR",9,16},["SpreadAngle"]={"V2",0,1000},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.10896,0.9375,0},{0.18698,0.9,0},{0.23038,0.75,0},{0.26777,0.54375,0},{0.3338,0.44375,0},{0.39889,0.81875,0},{0.49908,0.9375,0},{0.60665,0.96875,0},{0.69945,0.94375,0},{0.79917,0.95625,0},{0.89982,0.98125,0},{1,1,0}}},["EmissionDirection"]={"E","NormalId","Left"},["LightEmission"]=1,["Texture"]="rbxassetid://9860410723",["Size"]={"NS",{{0,0.20012,0.20012},{0.16314,1.5559,0.2597},{0.35866,2.4311,0.28767},{0.52802,2.7423,0.30018},{1,3.1118,0}}},["Squash"]={"NS",{{0,0,0.45},{0.49934,0.0375,0},{1,0,0}}}},{["EmitCount"]=10,["EmitDelay"]=0}}}},{"Attachment","Attachment",{["CFrame"]={"CF",0,5.3562,0,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,5.3562,0}}},{"ParticleEmitter","Smoke",{["Color"]={"CS",{{0,0.22353,0.17647,0.13333},{1,0.22353,0.17647,0.13333}}},["Drag"]=6,["ZOffset"]=0.24348,["LightInfluence"]=0.25,["Lifetime"]={"NR",2,3},["Speed"]={"NR",0.0018312,0.0018312},["SpreadAngle"]={"V2",0,60},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.10896,0.9375,0},{0.18698,0.9,0},{0.23038,0.75,0},{0.26777,0.54375,0},{0.3338,0.44375,0},{0.39889,0.81875,0},{0.49908,0.9375,0},{0.60665,0.96875,0},{0.69945,0.94375,0},{0.79917,0.95625,0},{0.89982,0.98125,0},{1,1,0}}},["EmissionDirection"]={"E","NormalId","Front"},["LightEmission"]=1,["Texture"]="rbxassetid://9860410723",["Size"]={"NS",{{0,0.39254,0.39254},{0.16314,3.052,0.50941},{0.35866,4.7687,0.56427},{0.52802,5.3791,0.58881},{1,6.1039,0}}},["Squash"]={"NS",{{0,0,0.45},{0.49934,0.0375,0},{1,0,0}}}},{["EmitCount"]=10,["EmitDelay"]=0}}},1},{"Part","Poison",{["CFrame"]={"CF",35.73,0,0,1,0,0,0,1,0,0,0,1},["Size"]={"V3",2,7.0265,2}},nil,nil,{{"Attachment","Attachment",{["CFrame"]={"CF",0,-3.6776,0,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,-3.6776,0}},nil,nil,{{"Beam","Beam",{["FaceCamera"]=true,["Color"]={"CS",{{0,0.54902,1,0.031373},{1,0.54902,1,0.031373}}},["ZOffset"]=1,["Width0"]=0,["Texture"]="rbxassetid://9589762590",["Transparency"]={"NS",{{0,0,0},{1,1,0}}},["Width1"]=25,["Brightness"]=10,["TextureMode"]={"E","TextureMode","Static"},["TextureLength"]=10},nil,{["Attachment1"]={5,2},["Attachment0"]={5,1}}},{"ParticleEmitter","Spin",{["FlipbookFramerate"]={"NR",15,15},["Drag"]=3.25,["Lifetime"]={"NR",0.59043,1.1809},["Speed"]={"NR",18,18},["Brightness"]=3,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid8x8"},["Size"]={"NS",{{0,0,0},{0.2,2.5541,0},{0.4,4.0449,0},{0.6,5.1901,0},{0.8,6.4133,0},{1,10,0}}},["FlipbookMode"]={"E","ParticleFlipbookMode","PingPong"},["RotSpeed"]={"NR",-1600,-860},["LockedToPart"]=true,["Rate"]=15,["Transparency"]={"NS",{{0,0,0},{0.71653,0,0},{0.83887,0.76875,0},{1,1,0}}},["Texture"]="rbxassetid://12350085716",["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Color"]={"CS",{{0,0.54902,1,0.031373},{1,0.54902,1,0.031373}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}}},{["EmitCount"]=2,["EmitDelay"]=0}},{"ParticleEmitter","Specs",{["Color"]={"CS",{{0,0.54902,1,0.031373},{1,0.54902,1,0.031373}}},["Drag"]=5,["ZOffset"]=1.7108,["VelocitySpread"]=-35,["Lifetime"]={"NR",0.2,1},["Speed"]={"NR",12.831,30.795},["Brightness"]=100,["SpreadAngle"]={"V2",-35,35},["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["LockedToPart"]=true,["Rate"]=10,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{0.54124,0,0},{1,0.9625,0}}},["Texture"]="rbxassetid://10556232026",["LightEmission"]=1,["Size"]={"NS",{{0,0,0},{0.2,0.92921,4.2771},{0.4,1.9554,4.2771},{0.6,2.9953,4.2771},{0.8,3.8773,4.2771},{1,4.2771,4.2771}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["FlipbookStartRandom"]=true},{["EmitCount"]=200,["EmitDelay"]=0}},{"ParticleEmitter","Smoke",{["Color"]={"CS",{{0,0.54902,1,0.031373},{1,0.54902,1,0.031373}}},["Drag"]=6,["ZOffset"]=0.12413,["LightInfluence"]=0.25,["Lifetime"]={"NR",2,3},["Speed"]={"NR",9,16},["SpreadAngle"]={"V2",0,1000},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.10896,0.9375,0},{0.18698,0.9,0},{0.23038,0.75,0},{0.26777,0.54375,0},{0.3338,0.44375,0},{0.39889,0.81875,0},{0.49908,0.9375,0},{0.60665,0.96875,0},{0.69945,0.94375,0},{0.79917,0.95625,0},{0.89982,0.98125,0},{1,1,0}}},["EmissionDirection"]={"E","NormalId","Left"},["LightEmission"]=1,["Texture"]="rbxassetid://9860410723",["Size"]={"NS",{{0,0.20012,0.20012},{0.16314,1.5559,0.2597},{0.35866,2.4311,0.28767},{0.52802,2.7423,0.30018},{1,3.1118,0}}},["Squash"]={"NS",{{0,0,0.45},{0.49934,0.0375,0},{1,0,0}}}},{["EmitCount"]=10,["EmitDelay"]=0}},{"Beam","Beam",{["FaceCamera"]=true,["Color"]={"CS",{{0,0.54902,1,0.031373},{1,0.54902,1,0.031373}}},["TextureSpeed"]=0.2,["ZOffset"]=1,["Width0"]=0,["Texture"]="rbxassetid://9589826891",["Transparency"]={"NS",{{0,0,0},{0.62789,0.94375,0},{1,1,0}}},["Width1"]=25,["Brightness"]=10,["TextureMode"]={"E","TextureMode","Static"},["TextureLength"]=170},nil,{["Attachment1"]={5,2},["Attachment0"]={5,1}}},{"Beam","Beam",{["FaceCamera"]=true,["Color"]={"CS",{{0,0.54902,1,0.031373},{1,0.54902,1,0.031373}}},["TextureSpeed"]=0.3,["ZOffset"]=1,["Width0"]=0,["Texture"]="rbxassetid://9589826891",["Transparency"]={"NS",{{0,0,0},{0.53924,0.94375,0},{1,1,0}}},["Width1"]=25,["Brightness"]=10,["TextureMode"]={"E","TextureMode","Static"},["TextureLength"]=240},nil,{["Attachment1"]={5,2},["Attachment0"]={5,1}}}}},{"Attachment","Attachment",{["CFrame"]={"CF",0,5.3562,0,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,5.3562,0}}},{"ParticleEmitter","Smoke",{["Color"]={"CS",{{0,0.54902,1,0.031373},{1,0.54902,1,0.031373}}},["Drag"]=6,["ZOffset"]=0.24348,["LightInfluence"]=0.25,["Lifetime"]={"NR",2,3},["Speed"]={"NR",0.0018312,0.0018312},["SpreadAngle"]={"V2",0,60},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.10896,0.9375,0},{0.18698,0.9,0},{0.23038,0.75,0},{0.26777,0.54375,0},{0.3338,0.44375,0},{0.39889,0.81875,0},{0.49908,0.9375,0},{0.60665,0.96875,0},{0.69945,0.94375,0},{0.79917,0.95625,0},{0.89982,0.98125,0},{1,1,0}}},["EmissionDirection"]={"E","NormalId","Front"},["LightEmission"]=1,["Texture"]="rbxassetid://9860410723",["Size"]={"NS",{{0,0.39254,0.39254},{0.16314,3.052,0.50941},{0.35866,4.7687,0.56427},{0.52802,5.3791,0.58881},{1,6.1039,0}}},["Squash"]={"NS",{{0,0,0.45},{0.49934,0.0375,0},{1,0,0}}}},{["EmitCount"]=10,["EmitDelay"]=0}}},1}},
        	["Tornado Lightning"] = {{"Part","Wind",{["CFrame"]={"CF",0,0,0,1,0,0,0,1,0,0,0,1},["Size"]={"V3",2,7.0265,2}},nil,nil,{{"Attachment","Attachment",{["CFrame"]={"CF",0,-3.6776,0,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,-3.6776,0}},nil,nil,{{"Beam","Beam",{["FaceCamera"]=true,["Color"]={"CS",{{0,0.6,0.82745,1},{1,0.6,0.82745,1}}},["ZOffset"]=1,["Width0"]=0,["Texture"]="rbxassetid://9589762590",["Transparency"]={"NS",{{0,0,0},{1,1,0}}},["Width1"]=25,["Brightness"]=10,["TextureMode"]={"E","TextureMode","Static"},["TextureLength"]=10},nil,{["Attachment1"]={1,2},["Attachment0"]={1,1}}},{"ParticleEmitter","Spin",{["FlipbookFramerate"]={"NR",15,15},["Drag"]=3.25,["Lifetime"]={"NR",0.59043,1.1809},["Speed"]={"NR",18,18},["Brightness"]=3,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid8x8"},["Size"]={"NS",{{0,0,0},{0.2,2.5541,0},{0.4,4.0449,0},{0.6,5.1901,0},{0.8,6.4133,0},{1,10,0}}},["FlipbookMode"]={"E","ParticleFlipbookMode","PingPong"},["RotSpeed"]={"NR",-1600,-860},["LockedToPart"]=true,["Rate"]=15,["Transparency"]={"NS",{{0,0,0},{0.71653,0,0},{0.83887,0.76875,0},{1,1,0}}},["Texture"]="rbxassetid://12350085716",["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Color"]={"CS",{{0,0.72549,0.96471,1},{1,0.72549,0.96471,1}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}}},{["EmitCount"]=2,["EmitDelay"]=0}},{"ParticleEmitter","Specs",{["Color"]={"CS",{{0,0.21961,0.4,1},{1,0.21961,0.4,1}}},["Drag"]=5,["ZOffset"]=1.7108,["VelocitySpread"]=-35,["Lifetime"]={"NR",0.2,1},["Speed"]={"NR",12.831,30.795},["Brightness"]=100,["SpreadAngle"]={"V2",-35,35},["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["LockedToPart"]=true,["Rate"]=10,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{0.54124,0,0},{1,0.9625,0}}},["Texture"]="rbxassetid://10556232026",["LightEmission"]=1,["Size"]={"NS",{{0,0,0},{0.2,0.92921,4.2771},{0.4,1.9554,4.2771},{0.6,2.9953,4.2771},{0.8,3.8773,4.2771},{1,4.2771,4.2771}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["FlipbookStartRandom"]=true},{["EmitCount"]=200,["EmitDelay"]=0}},{"ParticleEmitter","Smoke",{["Color"]={"CS",{{0,0.6,0.82745,1},{1,0.6,0.82745,1}}},["Drag"]=6,["ZOffset"]=0.12413,["LightInfluence"]=0.25,["Lifetime"]={"NR",2,3},["Speed"]={"NR",9,16},["SpreadAngle"]={"V2",0,1000},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.10896,0.9375,0},{0.18698,0.9,0},{0.23038,0.75,0},{0.26777,0.54375,0},{0.3338,0.44375,0},{0.39889,0.81875,0},{0.49908,0.9375,0},{0.60665,0.96875,0},{0.69945,0.94375,0},{0.79917,0.95625,0},{0.89982,0.98125,0},{1,1,0}}},["EmissionDirection"]={"E","NormalId","Left"},["LightEmission"]=1,["Texture"]="rbxassetid://9860410723",["Size"]={"NS",{{0,0.20012,0.20012},{0.16314,1.5559,0.2597},{0.35866,2.4311,0.28767},{0.52802,2.7423,0.30018},{1,3.1118,0}}},["Squash"]={"NS",{{0,0,0.45},{0.49934,0.0375,0},{1,0,0}}}},{["EmitCount"]=10,["EmitDelay"]=0}},{"Beam","Beam",{["FaceCamera"]=true,["Color"]={"CS",{{0,0.6,0.82745,1},{1,0.6,0.82745,1}}},["TextureSpeed"]=0.2,["ZOffset"]=1,["Width0"]=0,["Texture"]="rbxassetid://9589826891",["Transparency"]={"NS",{{0,0,0},{0.62789,0.94375,0},{1,1,0}}},["Width1"]=25,["Brightness"]=10,["TextureMode"]={"E","TextureMode","Static"},["TextureLength"]=170},nil,{["Attachment1"]={1,2},["Attachment0"]={1,1}}},{"Beam","Beam",{["FaceCamera"]=true,["Color"]={"CS",{{0,0.6,0.82745,1},{1,0.6,0.82745,1}}},["TextureSpeed"]=0.3,["ZOffset"]=1,["Width0"]=0,["Texture"]="rbxassetid://9589826891",["Transparency"]={"NS",{{0,0,0},{0.53924,0.94375,0},{1,1,0}}},["Width1"]=25,["Brightness"]=10,["TextureMode"]={"E","TextureMode","Static"},["TextureLength"]=240},nil,{["Attachment1"]={1,2},["Attachment0"]={1,1}}}}},{"Attachment","Attachment",{["CFrame"]={"CF",0,5.3562,0,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,5.3562,0}}},{"ParticleEmitter","Smoke",{["Color"]={"CS",{{0,0.6,0.82745,1},{1,0.6,0.82745,1}}},["Drag"]=6,["ZOffset"]=0.24348,["LightInfluence"]=0.25,["Lifetime"]={"NR",2,3},["Speed"]={"NR",0.0018312,0.0018312},["SpreadAngle"]={"V2",0,60},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.10896,0.9375,0},{0.18698,0.9,0},{0.23038,0.75,0},{0.26777,0.54375,0},{0.3338,0.44375,0},{0.39889,0.81875,0},{0.49908,0.9375,0},{0.60665,0.96875,0},{0.69945,0.94375,0},{0.79917,0.95625,0},{0.89982,0.98125,0},{1,1,0}}},["EmissionDirection"]={"E","NormalId","Front"},["LightEmission"]=1,["Texture"]="rbxassetid://9860410723",["Size"]={"NS",{{0,0.39254,0.39254},{0.16314,3.052,0.50941},{0.35866,4.7687,0.56427},{0.52802,5.3791,0.58881},{1,6.1039,0}}},["Squash"]={"NS",{{0,0,0.45},{0.49934,0.0375,0},{1,0,0}}}},{["EmitCount"]=10,["EmitDelay"]=0}}},1},{"Part","Lightning",{["CFrame"]={"CF",-11.973,0,0,1,0,0,0,1,0,0,0,1},["Size"]={"V3",2,7.0265,2}},nil,nil,{{"Attachment","Attachment",{["CFrame"]={"CF",0,-3.6776,0,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,-3.6776,0}},nil,nil,{{"Beam","Beam",{["FaceCamera"]=true,["Color"]={"CS",{{0,0,0.29804,1},{1,0,0.29804,1}}},["ZOffset"]=1,["Width0"]=0,["Texture"]="rbxassetid://9589762590",["Transparency"]={"NS",{{0,0,0},{1,1,0}}},["Width1"]=25,["Brightness"]=10,["TextureMode"]={"E","TextureMode","Static"},["TextureLength"]=10},nil,{["Attachment1"]={2,2},["Attachment0"]={2,1}}},{"ParticleEmitter","Spin",{["FlipbookFramerate"]={"NR",15,15},["Drag"]=3.25,["Lifetime"]={"NR",0.59043,1.1809},["Speed"]={"NR",18,18},["Brightness"]=5,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid8x8"},["Size"]={"NS",{{0,0,0},{0.2,2.5541,0},{0.4,4.0449,0},{0.6,5.1901,0},{0.8,6.4133,0},{1,10,0}}},["FlipbookMode"]={"E","ParticleFlipbookMode","PingPong"},["RotSpeed"]={"NR",-1600,-860},["LockedToPart"]=true,["Rate"]=15,["Transparency"]={"NS",{{0,0,0},{0.71653,0,0},{0.83887,0.76875,0},{1,1,0}}},["Texture"]="rbxassetid://12350085716",["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Color"]={"CS",{{0,0.20784,0.5098,1},{1,0.20784,0.5098,1}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}}},{["EmitCount"]=2,["EmitDelay"]=0}},{"ParticleEmitter","Lines ",{["Color"]={"CS",{{0,0.13333,0.43529,1},{1,0.13333,0.43529,1}}},["Drag"]=3,["ZOffset"]=0.60482,["VelocitySpread"]=-45,["Lifetime"]={"NR",0.2,0.7},["Speed"]={"NR",8.8728,51.962},["Brightness"]=100,["SpreadAngle"]={"V2",-45,45},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-90,-90},["Transparency"]={"NS",{{0,1,0},{0.09856,0,0},{0.19578,0,0},{0.23042,1,0},{0.26355,0,0},{0.42018,0,0},{0.44578,1,0},{0.47741,0,0},{0.61596,0,0},{0.64608,1,0},{0.67319,0,0},{0.73193,0,0},{0.74849,1,0},{0.76657,0,0},{0.80066,0,0},{1,1,0}}},["Texture"]="rbxassetid://7828271118",["LightEmission"]=1,["Size"]={"NS",{{0,0,0},{0.5,0.88215,0},{1,0,0}}},["Orientation"]={"E","ParticleOrientation","VelocityParallel"},["Squash"]={"NS",{{0,0,0},{1,0,0}}}},{["EmitCount"]=25,["EmitDelay"]=0}},{"ParticleEmitter","Lines 3",{["Color"]={"CS",{{0,0.16471,0.3451,1},{1,0.16471,0.3451,1}}},["Drag"]=5,["ZOffset"]=0.60482,["VelocitySpread"]=-45,["Lifetime"]={"NR",0.2,2},["Speed"]={"NR",4.596,91.962},["Brightness"]=100,["SpreadAngle"]={"V2",-45,45},["Acceleration"]={"V3",0,-50,0},["Rate"]=5,["Rotation"]={"NR",-90,-90},["Transparency"]={"NS",{{0,1,0},{0.09856,0,0},{0.19578,0,0},{0.23042,1,0},{0.26355,0,0},{0.42018,0,0},{0.44578,1,0},{0.47741,0,0},{0.61596,0,0},{0.64608,1,0},{0.67319,0,0},{0.73193,0,0},{0.74849,1,0},{0.76657,0,0},{0.80066,0,0},{1,1,0}}},["Texture"]="rbxassetid://9710377531",["Orientation"]={"E","ParticleOrientation","VelocityParallel"},["Size"]={"NS",{{0,0,0},{0.05567,0.21385,0.010984},{0.096907,2.1653,0.55128},{0.11959,0.26732,0.021617},{0.19934,0.21333,0.037926},{0.24849,0.52165,0.037926},{0.3,0.082184,0.037926},{0.4,0.094068,0.037926},{0.42771,0.27973,0.037103},{0.44578,0,0},{0.50515,1.6039,0.035308},{0.52711,0.50653,0.034213},{0.54819,0,0},{0.57831,0.30997,0.032661},{0.6567,0.071111,0.030286},{0.74096,0.43849,0.02509},{0.7997,0.31753,0.023703},{0.8238,0,0},{0.87801,0.19657,0.014436},{1,0,0}}},["LightEmission"]=1,["Squash"]={"NS",{{0,0.825,0},{0.034021,0.75,0},{0.078351,-0.1125,0},{0.10928,0.75,0},{0.7741,-0.225,0},{1,-0.3,0.7125}}}},{["EmitCount"]=25,["EmitDelay"]=0}},{"ParticleEmitter","Specs",{["Color"]={"CS",{{0,0.21961,0.4,1},{1,0.21961,0.4,1}}},["Drag"]=5,["ZOffset"]=1.7108,["VelocitySpread"]=-45,["Lifetime"]={"NR",0.2,1},["Speed"]={"NR",12.831,30.795},["Brightness"]=100,["SpreadAngle"]={"V2",-45,45},["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["LockedToPart"]=true,["Rate"]=10,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{0.54124,0,0},{1,0.9625,0}}},["Texture"]="rbxassetid://10556232026",["LightEmission"]=1,["Size"]={"NS",{{0,0,0},{0.2,0.92921,4.2771},{0.4,1.9554,4.2771},{0.6,2.9953,4.2771},{0.8,3.8773,4.2771},{1,4.2771,4.2771}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["FlipbookStartRandom"]=true},{["EmitCount"]=200,["EmitDelay"]=0}},{"ParticleEmitter","Smoke",{["Color"]={"CS",{{0,0,0.29804,1},{1,0,0.29804,1}}},["Drag"]=6,["ZOffset"]=0.14203,["LightInfluence"]=0.25,["Lifetime"]={"NR",2,3},["Speed"]={"NR",14,14},["SpreadAngle"]={"V2",0,1000},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.10896,0.9375,0},{0.18698,0.9,0},{0.23038,0.75,0},{0.26777,0.54375,0},{0.3338,0.44375,0},{0.39889,0.81875,0},{0.49908,0.9375,0},{0.60665,0.96875,0},{0.69945,0.94375,0},{0.79917,0.95625,0},{0.89982,0.98125,0},{1,1,0}}},["EmissionDirection"]={"E","NormalId","Left"},["LightEmission"]=1,["Texture"]="rbxassetid://9860410723",["Size"]={"NS",{{0,0.22899,0.22899},{0.16314,1.7804,0.29717},{0.35866,2.7818,0.32917},{0.52802,3.1379,0.34348},{1,3.5607,0}}},["Squash"]={"NS",{{0,0,0.45},{0.49934,0.0375,0},{1,0,0}}}},{["EmitCount"]=10,["EmitDelay"]=0}}}},{"Attachment","Attachment",{["CFrame"]={"CF",0,5.3562,0,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,5.3562,0}}},{"ParticleEmitter","Lightning",{["Color"]={"CS",{{0,0,0.34902,1},{1,0,0.34902,1}}},["ZOffset"]=4,["VelocitySpread"]=-360,["Lifetime"]={"NR",0.2,0.55},["Speed"]={"NR",0.0010192,0.0010192},["Brightness"]=3,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["SpreadAngle"]={"V2",-360,360},["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["LockedToPart"]=true,["Rate"]=4,["Texture"]="rbxassetid://11363411020",["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{1,0,0}}},["Size"]={"NS",{{0,5.6523,0},{1,5.6523,0}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Orientation"]={"E","ParticleOrientation","VelocityParallel"},["FlipbookFramerate"]={"NR",3.9,3.9},["LightEmission"]=1},{["EmitCount"]=7,["EmitDelay"]=0}},{"ParticleEmitter","Smoke",{["Color"]={"CS",{{0,0,0.29804,1},{1,0,0.29804,1}}},["Drag"]=6,["ZOffset"]=0.24348,["LightInfluence"]=0.25,["Lifetime"]={"NR",2,3},["Speed"]={"NR",0.0018312,0.0018312},["SpreadAngle"]={"V2",0,60},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.10896,0.9375,0},{0.18698,0.9,0},{0.23038,0.75,0},{0.26777,0.54375,0},{0.3338,0.44375,0},{0.39889,0.81875,0},{0.49908,0.9375,0},{0.60665,0.96875,0},{0.69945,0.94375,0},{0.79917,0.95625,0},{0.89982,0.98125,0},{1,1,0}}},["EmissionDirection"]={"E","NormalId","Front"},["LightEmission"]=1,["Texture"]="rbxassetid://9860410723",["Size"]={"NS",{{0,0.39254,0.39254},{0.16314,3.052,0.50941},{0.35866,4.7687,0.56427},{0.52802,5.3791,0.58881},{1,6.1039,0}}},["Squash"]={"NS",{{0,0,0.45},{0.49934,0.0375,0},{1,0,0}}}},{["EmitCount"]=10,["EmitDelay"]=0}}},1},{"Part","Fire",{["CFrame"]={"CF",12.392,0,0,1,0,0,0,1,0,0,0,1},["Size"]={"V3",2,7.0265,2}},nil,nil,{{"Attachment","Attachment",{["CFrame"]={"CF",0,-3.6776,0,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,-3.6776,0}},nil,nil,{{"Beam","Beam",{["FaceCamera"]=true,["Color"]={"CS",{{0,1,0.35686,0.16078},{1,1,0.35686,0.16078}}},["ZOffset"]=1,["Width0"]=0,["Texture"]="rbxassetid://9589762590",["Transparency"]={"NS",{{0,0,0},{1,1,0}}},["Width1"]=25,["Brightness"]=10,["TextureMode"]={"E","TextureMode","Static"},["TextureLength"]=10},nil,{["Attachment1"]={3,2},["Attachment0"]={3,1}}},{"ParticleEmitter","Spin",{["FlipbookFramerate"]={"NR",15,15},["Drag"]=3.25,["Lifetime"]={"NR",0.59043,1.1809},["Speed"]={"NR",18,18},["Brightness"]=5,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid8x8"},["Size"]={"NS",{{0,0,0},{0.2,2.5541,0},{0.4,4.0449,0},{0.6,5.1901,0},{0.8,6.4133,0},{1,10,0}}},["FlipbookMode"]={"E","ParticleFlipbookMode","PingPong"},["RotSpeed"]={"NR",-1600,-860},["LockedToPart"]=true,["Rate"]=15,["Transparency"]={"NS",{{0,0,0},{0.71653,0,0},{0.83887,0.76875,0},{1,1,0}}},["Texture"]="rbxassetid://12350085716",["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Color"]={"CS",{{0,1,0.35686,0.16078},{1,1,0.35686,0.16078}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}}},{["EmitCount"]=2,["EmitDelay"]=0}},{"ParticleEmitter","Lines 3",{["Color"]={"CS",{{0,1,0.35686,0.16078},{1,1,0.35686,0.16078}}},["Drag"]=5,["ZOffset"]=0.055849,["VelocitySpread"]=-45,["Lifetime"]={"NR",0.2,2},["Speed"]={"NR",59,59},["Brightness"]=100,["SpreadAngle"]={"V2",-45,45},["Acceleration"]={"V3",0,-30.948,0},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-90,-90},["Transparency"]={"NS",{{0,1,0},{0.09856,0,0},{0.19578,0,0},{0.23042,1,0},{0.26355,0,0},{0.42018,0,0},{0.44578,1,0},{0.47741,0,0},{0.61596,0,0},{0.64608,1,0},{0.67319,0,0},{0.73193,0,0},{0.74849,1,0},{0.76657,0,0},{0.80066,0,0},{1,1,0}}},["Texture"]="rbxassetid://9589739468",["Orientation"]={"E","ParticleOrientation","VelocityParallel"},["Size"]={"NS",{{0,0,0},{0.05567,0.51594,0},{0.096907,0.51594,0},{0.11959,0.51594,0},{0.19934,0.51594,0},{0.24849,0.51594,0},{0.3,0.51594,0},{0.4,0.51594,0},{0.42771,0.51594,0},{0.44578,0,0},{0.50515,0.51594,0},{0.52711,0.51594,0},{0.54819,0,0},{0.57831,0.51594,0},{0.6567,0.51594,0},{0.74096,0.51594,0},{0.7997,0.51594,0},{0.8238,0,0},{0.87801,0.51594,0},{1,0,0}}},["Squash"]={"NS",{{0,0.825,0},{0.034021,0.75,0},{0.078351,-0.1125,0},{0.10928,0.75,0},{0.7741,-0.225,0},{1,-0.3,0.7125}}},["LightEmission"]=1},{["EmitCount"]=25,["EmitDelay"]=0}},{"ParticleEmitter","Specs",{["Color"]={"CS",{{0,1,0.35686,0.16078},{1,1,0.35686,0.16078}}},["Drag"]=5,["ZOffset"]=1.7108,["VelocitySpread"]=-45,["Lifetime"]={"NR",0.2,1},["Speed"]={"NR",12.831,30.795},["Brightness"]=100,["SpreadAngle"]={"V2",-45,45},["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["LockedToPart"]=true,["Rate"]=10,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{0.54124,0,0},{1,0.9625,0}}},["Texture"]="rbxassetid://10556232026",["LightEmission"]=1,["Size"]={"NS",{{0,0,0},{0.2,0.92921,4.2771},{0.4,1.9554,4.2771},{0.6,2.9953,4.2771},{0.8,3.8773,4.2771},{1,4.2771,4.2771}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["FlipbookStartRandom"]=true},{["EmitCount"]=200,["EmitDelay"]=0}},{"ParticleEmitter","Smoke",{["Color"]={"CS",{{0,1,0.35686,0.16078},{1,1,0.35686,0.16078}}},["Drag"]=6,["ZOffset"]=0.12413,["LightInfluence"]=0.25,["Lifetime"]={"NR",2,3},["Speed"]={"NR",9,16},["SpreadAngle"]={"V2",0,1000},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.10896,0.9375,0},{0.18698,0.9,0},{0.23038,0.75,0},{0.26777,0.54375,0},{0.3338,0.44375,0},{0.39889,0.81875,0},{0.49908,0.9375,0},{0.60665,0.96875,0},{0.69945,0.94375,0},{0.79917,0.95625,0},{0.89982,0.98125,0},{1,1,0}}},["EmissionDirection"]={"E","NormalId","Left"},["LightEmission"]=1,["Texture"]="rbxassetid://9860410723",["Size"]={"NS",{{0,0.20012,0.20012},{0.16314,1.5559,0.2597},{0.35866,2.4311,0.28767},{0.52802,2.7423,0.30018},{1,3.1118,0}}},["Squash"]={"NS",{{0,0,0.45},{0.49934,0.0375,0},{1,0,0}}}},{["EmitCount"]=10,["EmitDelay"]=0}},{"ParticleEmitter","Fire",{["FlipbookFramerate"]={"NR",30,30},["Drag"]=11,["ZOffset"]=0.99722,["VelocitySpread"]=35,["Lifetime"]={"NR",0.4,1},["Speed"]={"NR",7.978,69.555},["Brightness"]=100,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["SpreadAngle"]={"V2",35,35},["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["RotSpeed"]={"NR",-50,50},["LockedToPart"]=true,["Rate"]=10,["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{1,0,0}}},["Texture"]="rbxassetid://11418708306",["Size"]={"NS",{{0,0.59292,0.30387},{0.12202,1.1507,0.17431},{0.3866,2.3301,0.097922},{0.73475,3.7397,0.07289},{1,4.6027,0}}},["Color"]={"CS",{{0,1,0.082353,0},{1,1,0.082353,0}}},["Shape"]={"E","ParticleEmitterShape","Disc"}},{["EmitCount"]=15,["EmitDelay"]=0}},{"ParticleEmitter","Fire 2",{["FlipbookFramerate"]={"NR",60,60},["Drag"]=5,["ZOffset"]=0.12609,["Lifetime"]={"NR",1,1},["Speed"]={"NR",27,27},["Brightness"]=30,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["Size"]={"NS",{{0,2.1027,1.0187},{1,2.1027,1.0448}}},["RotSpeed"]={"NR",-1200,-360},["LockedToPart"]=true,["Rate"]=3,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{0.7167,0,0},{0.76744,0.39752,0},{0.83562,0.81366,0},{0.92653,0.95652,0},{1,1,0}}},["Texture"]="rbxassetid://11977056412",["LightEmission"]=0.25,["Color"]={"CS",{{0,1,0.14902,0},{1,1,0.14902,0}}},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Squash"]={"NS",{{0,0,0},{1,0,0}}}}},{"ParticleEmitter","Fire 2",{["FlipbookFramerate"]={"NR",60,60},["Drag"]=5,["ZOffset"]=0.25874,["Lifetime"]={"NR",1,1},["Speed"]={"NR",0.0061561,0.0061561},["Brightness"]=30,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["Size"]={"NS",{{0,4.3147,2.0904},{1,4.3147,2.144}}},["RotSpeed"]={"NR",-1200,-360},["LockedToPart"]=true,["Rate"]=3,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{0.7167,0,0},{0.76744,0.39752,0},{0.83562,0.81366,0},{0.92653,0.95652,0},{1,1,0}}},["Texture"]="rbxassetid://11977056412",["LightEmission"]=0.25,["Color"]={"CS",{{0,1,0.14902,0},{1,1,0.14902,0}}},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Squash"]={"NS",{{0,0,0},{1,0,0}}}}}}},{"Attachment","Attachment",{["CFrame"]={"CF",0,5.3562,0,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,5.3562,0}}},{"ParticleEmitter","Smoke",{["Color"]={"CS",{{0,1,0.35686,0.16078},{1,1,0.35686,0.16078}}},["Drag"]=6,["ZOffset"]=0.24348,["LightInfluence"]=0.25,["Lifetime"]={"NR",2,3},["Speed"]={"NR",0.0018312,0.0018312},["SpreadAngle"]={"V2",0,60},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.10896,0.9375,0},{0.18698,0.9,0},{0.23038,0.75,0},{0.26777,0.54375,0},{0.3338,0.44375,0},{0.39889,0.81875,0},{0.49908,0.9375,0},{0.60665,0.96875,0},{0.69945,0.94375,0},{0.79917,0.95625,0},{0.89982,0.98125,0},{1,1,0}}},["EmissionDirection"]={"E","NormalId","Front"},["LightEmission"]=1,["Texture"]="rbxassetid://9860410723",["Size"]={"NS",{{0,0.39254,0.39254},{0.16314,3.052,0.50941},{0.35866,4.7687,0.56427},{0.52802,5.3791,0.58881},{1,6.1039,0}}},["Squash"]={"NS",{{0,0,0.45},{0.49934,0.0375,0},{1,0,0}}}},{["EmitCount"]=10,["EmitDelay"]=0}}},1},{"Part","Earth",{["CFrame"]={"CF",24.518,0,0,1,0,0,0,1,0,0,0,1},["Size"]={"V3",2,7.0265,2}},nil,nil,{{"Attachment","Attachment",{["CFrame"]={"CF",0,-3.6776,0,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,-3.6776,0}},nil,nil,{{"Beam","Beam",{["FaceCamera"]=true,["Color"]={"CS",{{0,0.22353,0.17647,0.13333},{1,0.22353,0.17647,0.13333}}},["ZOffset"]=1,["Width0"]=0,["Texture"]="rbxassetid://9589762590",["Transparency"]={"NS",{{0,0,0},{1,1,0}}},["Width1"]=40,["Brightness"]=10,["TextureMode"]={"E","TextureMode","Static"},["TextureLength"]=10},nil,{["Attachment1"]={4,2},["Attachment0"]={4,1}}},{"ParticleEmitter","Spin",{["FlipbookFramerate"]={"NR",15,15},["Drag"]=3.25,["Lifetime"]={"NR",0.59043,1.1809},["Speed"]={"NR",18,18},["Brightness"]=5,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid8x8"},["Size"]={"NS",{{0,0,0},{0.2,2.5541,0},{0.4,4.0449,0},{0.6,5.1901,0},{0.8,6.4133,0},{1,10,0}}},["FlipbookMode"]={"E","ParticleFlipbookMode","PingPong"},["RotSpeed"]={"NR",-1600,-860},["LockedToPart"]=true,["Transparency"]={"NS",{{0,0,0},{0.71653,0,0},{0.83887,0.76875,0},{1,1,0}}},["Texture"]="rbxassetid://12350085716",["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Color"]={"CS",{{0,0.22353,0.17647,0.13333},{1,0.22353,0.17647,0.13333}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}}},{["EmitCount"]=2,["EmitDelay"]=0}},{"ParticleEmitter","Specs",{["Color"]={"CS",{{0,0.22353,0.17647,0.13333},{1,0.22353,0.17647,0.13333}}},["Drag"]=5,["ZOffset"]=1.7108,["VelocitySpread"]=-45,["Lifetime"]={"NR",0.2,1},["Speed"]={"NR",12.831,30.795},["Brightness"]=10,["SpreadAngle"]={"V2",-45,45},["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["LockedToPart"]=true,["Rate"]=10,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{0.54124,0,0},{1,0.9625,0}}},["Texture"]="rbxassetid://10556232026",["LightEmission"]=1,["Size"]={"NS",{{0,0,0},{0.2,0.92921,4.2771},{0.4,1.9554,4.2771},{0.6,2.9953,4.2771},{0.8,3.8773,4.2771},{1,4.2771,4.2771}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["FlipbookStartRandom"]=true},{["EmitCount"]=200,["EmitDelay"]=0}},{"ParticleEmitter","Smoke",{["Color"]={"CS",{{0,0.22353,0.17647,0.13333},{1,0.22353,0.17647,0.13333}}},["Drag"]=6,["ZOffset"]=0.12413,["LightInfluence"]=0.25,["Lifetime"]={"NR",2,3},["Speed"]={"NR",9,16},["SpreadAngle"]={"V2",0,1000},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.10896,0.9375,0},{0.18698,0.9,0},{0.23038,0.75,0},{0.26777,0.54375,0},{0.3338,0.44375,0},{0.39889,0.81875,0},{0.49908,0.9375,0},{0.60665,0.96875,0},{0.69945,0.94375,0},{0.79917,0.95625,0},{0.89982,0.98125,0},{1,1,0}}},["EmissionDirection"]={"E","NormalId","Left"},["LightEmission"]=1,["Texture"]="rbxassetid://9860410723",["Size"]={"NS",{{0,0.20012,0.20012},{0.16314,1.5559,0.2597},{0.35866,2.4311,0.28767},{0.52802,2.7423,0.30018},{1,3.1118,0}}},["Squash"]={"NS",{{0,0,0.45},{0.49934,0.0375,0},{1,0,0}}}},{["EmitCount"]=10,["EmitDelay"]=0}}}},{"Attachment","Attachment",{["CFrame"]={"CF",0,5.3562,0,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,5.3562,0}}},{"ParticleEmitter","Smoke",{["Color"]={"CS",{{0,0.22353,0.17647,0.13333},{1,0.22353,0.17647,0.13333}}},["Drag"]=6,["ZOffset"]=0.24348,["LightInfluence"]=0.25,["Lifetime"]={"NR",2,3},["Speed"]={"NR",0.0018312,0.0018312},["SpreadAngle"]={"V2",0,60},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.10896,0.9375,0},{0.18698,0.9,0},{0.23038,0.75,0},{0.26777,0.54375,0},{0.3338,0.44375,0},{0.39889,0.81875,0},{0.49908,0.9375,0},{0.60665,0.96875,0},{0.69945,0.94375,0},{0.79917,0.95625,0},{0.89982,0.98125,0},{1,1,0}}},["EmissionDirection"]={"E","NormalId","Front"},["LightEmission"]=1,["Texture"]="rbxassetid://9860410723",["Size"]={"NS",{{0,0.39254,0.39254},{0.16314,3.052,0.50941},{0.35866,4.7687,0.56427},{0.52802,5.3791,0.58881},{1,6.1039,0}}},["Squash"]={"NS",{{0,0,0.45},{0.49934,0.0375,0},{1,0,0}}}},{["EmitCount"]=10,["EmitDelay"]=0}}},1},{"Part","Poison",{["CFrame"]={"CF",35.73,0,0,1,0,0,0,1,0,0,0,1},["Size"]={"V3",2,7.0265,2}},nil,nil,{{"Attachment","Attachment",{["CFrame"]={"CF",0,-3.6776,0,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,-3.6776,0}},nil,nil,{{"Beam","Beam",{["FaceCamera"]=true,["Color"]={"CS",{{0,0.54902,1,0.031373},{1,0.54902,1,0.031373}}},["ZOffset"]=1,["Width0"]=0,["Texture"]="rbxassetid://9589762590",["Transparency"]={"NS",{{0,0,0},{1,1,0}}},["Width1"]=25,["Brightness"]=10,["TextureMode"]={"E","TextureMode","Static"},["TextureLength"]=10},nil,{["Attachment1"]={5,2},["Attachment0"]={5,1}}},{"ParticleEmitter","Spin",{["FlipbookFramerate"]={"NR",15,15},["Drag"]=3.25,["Lifetime"]={"NR",0.59043,1.1809},["Speed"]={"NR",18,18},["Brightness"]=3,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid8x8"},["Size"]={"NS",{{0,0,0},{0.2,2.5541,0},{0.4,4.0449,0},{0.6,5.1901,0},{0.8,6.4133,0},{1,10,0}}},["FlipbookMode"]={"E","ParticleFlipbookMode","PingPong"},["RotSpeed"]={"NR",-1600,-860},["LockedToPart"]=true,["Rate"]=15,["Transparency"]={"NS",{{0,0,0},{0.71653,0,0},{0.83887,0.76875,0},{1,1,0}}},["Texture"]="rbxassetid://12350085716",["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Color"]={"CS",{{0,0.54902,1,0.031373},{1,0.54902,1,0.031373}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}}},{["EmitCount"]=2,["EmitDelay"]=0}},{"ParticleEmitter","Specs",{["Color"]={"CS",{{0,0.54902,1,0.031373},{1,0.54902,1,0.031373}}},["Drag"]=5,["ZOffset"]=1.7108,["VelocitySpread"]=-35,["Lifetime"]={"NR",0.2,1},["Speed"]={"NR",12.831,30.795},["Brightness"]=100,["SpreadAngle"]={"V2",-35,35},["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["LockedToPart"]=true,["Rate"]=10,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{0.54124,0,0},{1,0.9625,0}}},["Texture"]="rbxassetid://10556232026",["LightEmission"]=1,["Size"]={"NS",{{0,0,0},{0.2,0.92921,4.2771},{0.4,1.9554,4.2771},{0.6,2.9953,4.2771},{0.8,3.8773,4.2771},{1,4.2771,4.2771}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["FlipbookStartRandom"]=true},{["EmitCount"]=200,["EmitDelay"]=0}},{"ParticleEmitter","Smoke",{["Color"]={"CS",{{0,0.54902,1,0.031373},{1,0.54902,1,0.031373}}},["Drag"]=6,["ZOffset"]=0.12413,["LightInfluence"]=0.25,["Lifetime"]={"NR",2,3},["Speed"]={"NR",9,16},["SpreadAngle"]={"V2",0,1000},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.10896,0.9375,0},{0.18698,0.9,0},{0.23038,0.75,0},{0.26777,0.54375,0},{0.3338,0.44375,0},{0.39889,0.81875,0},{0.49908,0.9375,0},{0.60665,0.96875,0},{0.69945,0.94375,0},{0.79917,0.95625,0},{0.89982,0.98125,0},{1,1,0}}},["EmissionDirection"]={"E","NormalId","Left"},["LightEmission"]=1,["Texture"]="rbxassetid://9860410723",["Size"]={"NS",{{0,0.20012,0.20012},{0.16314,1.5559,0.2597},{0.35866,2.4311,0.28767},{0.52802,2.7423,0.30018},{1,3.1118,0}}},["Squash"]={"NS",{{0,0,0.45},{0.49934,0.0375,0},{1,0,0}}}},{["EmitCount"]=10,["EmitDelay"]=0}},{"Beam","Beam",{["FaceCamera"]=true,["Color"]={"CS",{{0,0.54902,1,0.031373},{1,0.54902,1,0.031373}}},["TextureSpeed"]=0.2,["ZOffset"]=1,["Width0"]=0,["Texture"]="rbxassetid://9589826891",["Transparency"]={"NS",{{0,0,0},{0.62789,0.94375,0},{1,1,0}}},["Width1"]=25,["Brightness"]=10,["TextureMode"]={"E","TextureMode","Static"},["TextureLength"]=170},nil,{["Attachment1"]={5,2},["Attachment0"]={5,1}}},{"Beam","Beam",{["FaceCamera"]=true,["Color"]={"CS",{{0,0.54902,1,0.031373},{1,0.54902,1,0.031373}}},["TextureSpeed"]=0.3,["ZOffset"]=1,["Width0"]=0,["Texture"]="rbxassetid://9589826891",["Transparency"]={"NS",{{0,0,0},{0.53924,0.94375,0},{1,1,0}}},["Width1"]=25,["Brightness"]=10,["TextureMode"]={"E","TextureMode","Static"},["TextureLength"]=240},nil,{["Attachment1"]={5,2},["Attachment0"]={5,1}}}}},{"Attachment","Attachment",{["CFrame"]={"CF",0,5.3562,0,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,5.3562,0}}},{"ParticleEmitter","Smoke",{["Color"]={"CS",{{0,0.54902,1,0.031373},{1,0.54902,1,0.031373}}},["Drag"]=6,["ZOffset"]=0.24348,["LightInfluence"]=0.25,["Lifetime"]={"NR",2,3},["Speed"]={"NR",0.0018312,0.0018312},["SpreadAngle"]={"V2",0,60},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.10896,0.9375,0},{0.18698,0.9,0},{0.23038,0.75,0},{0.26777,0.54375,0},{0.3338,0.44375,0},{0.39889,0.81875,0},{0.49908,0.9375,0},{0.60665,0.96875,0},{0.69945,0.94375,0},{0.79917,0.95625,0},{0.89982,0.98125,0},{1,1,0}}},["EmissionDirection"]={"E","NormalId","Front"},["LightEmission"]=1,["Texture"]="rbxassetid://9860410723",["Size"]={"NS",{{0,0.39254,0.39254},{0.16314,3.052,0.50941},{0.35866,4.7687,0.56427},{0.52802,5.3791,0.58881},{1,6.1039,0}}},["Squash"]={"NS",{{0,0,0.45},{0.49934,0.0375,0},{1,0,0}}}},{["EmitCount"]=10,["EmitDelay"]=0}}},1}},
        	["Tornado Fire"] = {{"Part","Wind",{["CFrame"]={"CF",0,0,0,1,0,0,0,1,0,0,0,1},["Size"]={"V3",2,7.0265,2}},nil,nil,{{"Attachment","Attachment",{["CFrame"]={"CF",0,-3.6776,0,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,-3.6776,0}},nil,nil,{{"Beam","Beam",{["FaceCamera"]=true,["Color"]={"CS",{{0,0.6,0.82745,1},{1,0.6,0.82745,1}}},["ZOffset"]=1,["Width0"]=0,["Texture"]="rbxassetid://9589762590",["Transparency"]={"NS",{{0,0,0},{1,1,0}}},["Width1"]=25,["Brightness"]=10,["TextureMode"]={"E","TextureMode","Static"},["TextureLength"]=10},nil,{["Attachment1"]={1,2},["Attachment0"]={1,1}}},{"ParticleEmitter","Spin",{["FlipbookFramerate"]={"NR",15,15},["Drag"]=3.25,["Lifetime"]={"NR",0.59043,1.1809},["Speed"]={"NR",18,18},["Brightness"]=3,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid8x8"},["Size"]={"NS",{{0,0,0},{0.2,2.5541,0},{0.4,4.0449,0},{0.6,5.1901,0},{0.8,6.4133,0},{1,10,0}}},["FlipbookMode"]={"E","ParticleFlipbookMode","PingPong"},["RotSpeed"]={"NR",-1600,-860},["LockedToPart"]=true,["Rate"]=15,["Transparency"]={"NS",{{0,0,0},{0.71653,0,0},{0.83887,0.76875,0},{1,1,0}}},["Texture"]="rbxassetid://12350085716",["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Color"]={"CS",{{0,0.72549,0.96471,1},{1,0.72549,0.96471,1}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}}},{["EmitCount"]=2,["EmitDelay"]=0}},{"ParticleEmitter","Specs",{["Color"]={"CS",{{0,0.21961,0.4,1},{1,0.21961,0.4,1}}},["Drag"]=5,["ZOffset"]=1.7108,["VelocitySpread"]=-35,["Lifetime"]={"NR",0.2,1},["Speed"]={"NR",12.831,30.795},["Brightness"]=100,["SpreadAngle"]={"V2",-35,35},["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["LockedToPart"]=true,["Rate"]=10,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{0.54124,0,0},{1,0.9625,0}}},["Texture"]="rbxassetid://10556232026",["LightEmission"]=1,["Size"]={"NS",{{0,0,0},{0.2,0.92921,4.2771},{0.4,1.9554,4.2771},{0.6,2.9953,4.2771},{0.8,3.8773,4.2771},{1,4.2771,4.2771}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["FlipbookStartRandom"]=true},{["EmitCount"]=200,["EmitDelay"]=0}},{"ParticleEmitter","Smoke",{["Color"]={"CS",{{0,0.6,0.82745,1},{1,0.6,0.82745,1}}},["Drag"]=6,["ZOffset"]=0.12413,["LightInfluence"]=0.25,["Lifetime"]={"NR",2,3},["Speed"]={"NR",9,16},["SpreadAngle"]={"V2",0,1000},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.10896,0.9375,0},{0.18698,0.9,0},{0.23038,0.75,0},{0.26777,0.54375,0},{0.3338,0.44375,0},{0.39889,0.81875,0},{0.49908,0.9375,0},{0.60665,0.96875,0},{0.69945,0.94375,0},{0.79917,0.95625,0},{0.89982,0.98125,0},{1,1,0}}},["EmissionDirection"]={"E","NormalId","Left"},["LightEmission"]=1,["Texture"]="rbxassetid://9860410723",["Size"]={"NS",{{0,0.20012,0.20012},{0.16314,1.5559,0.2597},{0.35866,2.4311,0.28767},{0.52802,2.7423,0.30018},{1,3.1118,0}}},["Squash"]={"NS",{{0,0,0.45},{0.49934,0.0375,0},{1,0,0}}}},{["EmitCount"]=10,["EmitDelay"]=0}},{"Beam","Beam",{["FaceCamera"]=true,["Color"]={"CS",{{0,0.6,0.82745,1},{1,0.6,0.82745,1}}},["TextureSpeed"]=0.2,["ZOffset"]=1,["Width0"]=0,["Texture"]="rbxassetid://9589826891",["Transparency"]={"NS",{{0,0,0},{0.62789,0.94375,0},{1,1,0}}},["Width1"]=25,["Brightness"]=10,["TextureMode"]={"E","TextureMode","Static"},["TextureLength"]=170},nil,{["Attachment1"]={1,2},["Attachment0"]={1,1}}},{"Beam","Beam",{["FaceCamera"]=true,["Color"]={"CS",{{0,0.6,0.82745,1},{1,0.6,0.82745,1}}},["TextureSpeed"]=0.3,["ZOffset"]=1,["Width0"]=0,["Texture"]="rbxassetid://9589826891",["Transparency"]={"NS",{{0,0,0},{0.53924,0.94375,0},{1,1,0}}},["Width1"]=25,["Brightness"]=10,["TextureMode"]={"E","TextureMode","Static"},["TextureLength"]=240},nil,{["Attachment1"]={1,2},["Attachment0"]={1,1}}}}},{"Attachment","Attachment",{["CFrame"]={"CF",0,5.3562,0,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,5.3562,0}}},{"ParticleEmitter","Smoke",{["Color"]={"CS",{{0,0.6,0.82745,1},{1,0.6,0.82745,1}}},["Drag"]=6,["ZOffset"]=0.24348,["LightInfluence"]=0.25,["Lifetime"]={"NR",2,3},["Speed"]={"NR",0.0018312,0.0018312},["SpreadAngle"]={"V2",0,60},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.10896,0.9375,0},{0.18698,0.9,0},{0.23038,0.75,0},{0.26777,0.54375,0},{0.3338,0.44375,0},{0.39889,0.81875,0},{0.49908,0.9375,0},{0.60665,0.96875,0},{0.69945,0.94375,0},{0.79917,0.95625,0},{0.89982,0.98125,0},{1,1,0}}},["EmissionDirection"]={"E","NormalId","Front"},["LightEmission"]=1,["Texture"]="rbxassetid://9860410723",["Size"]={"NS",{{0,0.39254,0.39254},{0.16314,3.052,0.50941},{0.35866,4.7687,0.56427},{0.52802,5.3791,0.58881},{1,6.1039,0}}},["Squash"]={"NS",{{0,0,0.45},{0.49934,0.0375,0},{1,0,0}}}},{["EmitCount"]=10,["EmitDelay"]=0}}},1},{"Part","Lightning",{["CFrame"]={"CF",-11.973,0,0,1,0,0,0,1,0,0,0,1},["Size"]={"V3",2,7.0265,2}},nil,nil,{{"Attachment","Attachment",{["CFrame"]={"CF",0,-3.6776,0,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,-3.6776,0}},nil,nil,{{"Beam","Beam",{["FaceCamera"]=true,["Color"]={"CS",{{0,0,0.29804,1},{1,0,0.29804,1}}},["ZOffset"]=1,["Width0"]=0,["Texture"]="rbxassetid://9589762590",["Transparency"]={"NS",{{0,0,0},{1,1,0}}},["Width1"]=25,["Brightness"]=10,["TextureMode"]={"E","TextureMode","Static"},["TextureLength"]=10},nil,{["Attachment1"]={2,2},["Attachment0"]={2,1}}},{"ParticleEmitter","Spin",{["FlipbookFramerate"]={"NR",15,15},["Drag"]=3.25,["Lifetime"]={"NR",0.59043,1.1809},["Speed"]={"NR",18,18},["Brightness"]=5,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid8x8"},["Size"]={"NS",{{0,0,0},{0.2,2.5541,0},{0.4,4.0449,0},{0.6,5.1901,0},{0.8,6.4133,0},{1,10,0}}},["FlipbookMode"]={"E","ParticleFlipbookMode","PingPong"},["RotSpeed"]={"NR",-1600,-860},["LockedToPart"]=true,["Rate"]=15,["Transparency"]={"NS",{{0,0,0},{0.71653,0,0},{0.83887,0.76875,0},{1,1,0}}},["Texture"]="rbxassetid://12350085716",["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Color"]={"CS",{{0,0.20784,0.5098,1},{1,0.20784,0.5098,1}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}}},{["EmitCount"]=2,["EmitDelay"]=0}},{"ParticleEmitter","Lines ",{["Color"]={"CS",{{0,0.13333,0.43529,1},{1,0.13333,0.43529,1}}},["Drag"]=3,["ZOffset"]=0.60482,["VelocitySpread"]=-45,["Lifetime"]={"NR",0.2,0.7},["Speed"]={"NR",8.8728,51.962},["Brightness"]=100,["SpreadAngle"]={"V2",-45,45},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-90,-90},["Transparency"]={"NS",{{0,1,0},{0.09856,0,0},{0.19578,0,0},{0.23042,1,0},{0.26355,0,0},{0.42018,0,0},{0.44578,1,0},{0.47741,0,0},{0.61596,0,0},{0.64608,1,0},{0.67319,0,0},{0.73193,0,0},{0.74849,1,0},{0.76657,0,0},{0.80066,0,0},{1,1,0}}},["Texture"]="rbxassetid://7828271118",["LightEmission"]=1,["Size"]={"NS",{{0,0,0},{0.5,0.88215,0},{1,0,0}}},["Orientation"]={"E","ParticleOrientation","VelocityParallel"},["Squash"]={"NS",{{0,0,0},{1,0,0}}}},{["EmitCount"]=25,["EmitDelay"]=0}},{"ParticleEmitter","Lines 3",{["Color"]={"CS",{{0,0.16471,0.3451,1},{1,0.16471,0.3451,1}}},["Drag"]=5,["ZOffset"]=0.60482,["VelocitySpread"]=-45,["Lifetime"]={"NR",0.2,2},["Speed"]={"NR",4.596,91.962},["Brightness"]=100,["SpreadAngle"]={"V2",-45,45},["Acceleration"]={"V3",0,-50,0},["Rate"]=5,["Rotation"]={"NR",-90,-90},["Transparency"]={"NS",{{0,1,0},{0.09856,0,0},{0.19578,0,0},{0.23042,1,0},{0.26355,0,0},{0.42018,0,0},{0.44578,1,0},{0.47741,0,0},{0.61596,0,0},{0.64608,1,0},{0.67319,0,0},{0.73193,0,0},{0.74849,1,0},{0.76657,0,0},{0.80066,0,0},{1,1,0}}},["Texture"]="rbxassetid://9710377531",["Orientation"]={"E","ParticleOrientation","VelocityParallel"},["Size"]={"NS",{{0,0,0},{0.05567,0.21385,0.010984},{0.096907,2.1653,0.55128},{0.11959,0.26732,0.021617},{0.19934,0.21333,0.037926},{0.24849,0.52165,0.037926},{0.3,0.082184,0.037926},{0.4,0.094068,0.037926},{0.42771,0.27973,0.037103},{0.44578,0,0},{0.50515,1.6039,0.035308},{0.52711,0.50653,0.034213},{0.54819,0,0},{0.57831,0.30997,0.032661},{0.6567,0.071111,0.030286},{0.74096,0.43849,0.02509},{0.7997,0.31753,0.023703},{0.8238,0,0},{0.87801,0.19657,0.014436},{1,0,0}}},["LightEmission"]=1,["Squash"]={"NS",{{0,0.825,0},{0.034021,0.75,0},{0.078351,-0.1125,0},{0.10928,0.75,0},{0.7741,-0.225,0},{1,-0.3,0.7125}}}},{["EmitCount"]=25,["EmitDelay"]=0}},{"ParticleEmitter","Specs",{["Color"]={"CS",{{0,0.21961,0.4,1},{1,0.21961,0.4,1}}},["Drag"]=5,["ZOffset"]=1.7108,["VelocitySpread"]=-45,["Lifetime"]={"NR",0.2,1},["Speed"]={"NR",12.831,30.795},["Brightness"]=100,["SpreadAngle"]={"V2",-45,45},["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["LockedToPart"]=true,["Rate"]=10,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{0.54124,0,0},{1,0.9625,0}}},["Texture"]="rbxassetid://10556232026",["LightEmission"]=1,["Size"]={"NS",{{0,0,0},{0.2,0.92921,4.2771},{0.4,1.9554,4.2771},{0.6,2.9953,4.2771},{0.8,3.8773,4.2771},{1,4.2771,4.2771}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["FlipbookStartRandom"]=true},{["EmitCount"]=200,["EmitDelay"]=0}},{"ParticleEmitter","Smoke",{["Color"]={"CS",{{0,0,0.29804,1},{1,0,0.29804,1}}},["Drag"]=6,["ZOffset"]=0.14203,["LightInfluence"]=0.25,["Lifetime"]={"NR",2,3},["Speed"]={"NR",14,14},["SpreadAngle"]={"V2",0,1000},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.10896,0.9375,0},{0.18698,0.9,0},{0.23038,0.75,0},{0.26777,0.54375,0},{0.3338,0.44375,0},{0.39889,0.81875,0},{0.49908,0.9375,0},{0.60665,0.96875,0},{0.69945,0.94375,0},{0.79917,0.95625,0},{0.89982,0.98125,0},{1,1,0}}},["EmissionDirection"]={"E","NormalId","Left"},["LightEmission"]=1,["Texture"]="rbxassetid://9860410723",["Size"]={"NS",{{0,0.22899,0.22899},{0.16314,1.7804,0.29717},{0.35866,2.7818,0.32917},{0.52802,3.1379,0.34348},{1,3.5607,0}}},["Squash"]={"NS",{{0,0,0.45},{0.49934,0.0375,0},{1,0,0}}}},{["EmitCount"]=10,["EmitDelay"]=0}}}},{"Attachment","Attachment",{["CFrame"]={"CF",0,5.3562,0,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,5.3562,0}}},{"ParticleEmitter","Lightning",{["Color"]={"CS",{{0,0,0.34902,1},{1,0,0.34902,1}}},["ZOffset"]=4,["VelocitySpread"]=-360,["Lifetime"]={"NR",0.2,0.55},["Speed"]={"NR",0.0010192,0.0010192},["Brightness"]=3,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["SpreadAngle"]={"V2",-360,360},["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["LockedToPart"]=true,["Rate"]=4,["Texture"]="rbxassetid://11363411020",["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{1,0,0}}},["Size"]={"NS",{{0,5.6523,0},{1,5.6523,0}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Orientation"]={"E","ParticleOrientation","VelocityParallel"},["FlipbookFramerate"]={"NR",3.9,3.9},["LightEmission"]=1},{["EmitCount"]=7,["EmitDelay"]=0}},{"ParticleEmitter","Smoke",{["Color"]={"CS",{{0,0,0.29804,1},{1,0,0.29804,1}}},["Drag"]=6,["ZOffset"]=0.24348,["LightInfluence"]=0.25,["Lifetime"]={"NR",2,3},["Speed"]={"NR",0.0018312,0.0018312},["SpreadAngle"]={"V2",0,60},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.10896,0.9375,0},{0.18698,0.9,0},{0.23038,0.75,0},{0.26777,0.54375,0},{0.3338,0.44375,0},{0.39889,0.81875,0},{0.49908,0.9375,0},{0.60665,0.96875,0},{0.69945,0.94375,0},{0.79917,0.95625,0},{0.89982,0.98125,0},{1,1,0}}},["EmissionDirection"]={"E","NormalId","Front"},["LightEmission"]=1,["Texture"]="rbxassetid://9860410723",["Size"]={"NS",{{0,0.39254,0.39254},{0.16314,3.052,0.50941},{0.35866,4.7687,0.56427},{0.52802,5.3791,0.58881},{1,6.1039,0}}},["Squash"]={"NS",{{0,0,0.45},{0.49934,0.0375,0},{1,0,0}}}},{["EmitCount"]=10,["EmitDelay"]=0}}},1},{"Part","Fire",{["CFrame"]={"CF",12.392,0,0,1,0,0,0,1,0,0,0,1},["Size"]={"V3",2,7.0265,2}},nil,nil,{{"Attachment","Attachment",{["CFrame"]={"CF",0,-3.6776,0,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,-3.6776,0}},nil,nil,{{"Beam","Beam",{["FaceCamera"]=true,["Color"]={"CS",{{0,1,0.35686,0.16078},{1,1,0.35686,0.16078}}},["ZOffset"]=1,["Width0"]=0,["Texture"]="rbxassetid://9589762590",["Transparency"]={"NS",{{0,0,0},{1,1,0}}},["Width1"]=25,["Brightness"]=10,["TextureMode"]={"E","TextureMode","Static"},["TextureLength"]=10},nil,{["Attachment1"]={3,2},["Attachment0"]={3,1}}},{"ParticleEmitter","Spin",{["FlipbookFramerate"]={"NR",15,15},["Drag"]=3.25,["Lifetime"]={"NR",0.59043,1.1809},["Speed"]={"NR",18,18},["Brightness"]=5,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid8x8"},["Size"]={"NS",{{0,0,0},{0.2,2.5541,0},{0.4,4.0449,0},{0.6,5.1901,0},{0.8,6.4133,0},{1,10,0}}},["FlipbookMode"]={"E","ParticleFlipbookMode","PingPong"},["RotSpeed"]={"NR",-1600,-860},["LockedToPart"]=true,["Rate"]=15,["Transparency"]={"NS",{{0,0,0},{0.71653,0,0},{0.83887,0.76875,0},{1,1,0}}},["Texture"]="rbxassetid://12350085716",["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Color"]={"CS",{{0,1,0.35686,0.16078},{1,1,0.35686,0.16078}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}}},{["EmitCount"]=2,["EmitDelay"]=0}},{"ParticleEmitter","Lines 3",{["Color"]={"CS",{{0,1,0.35686,0.16078},{1,1,0.35686,0.16078}}},["Drag"]=5,["ZOffset"]=0.055849,["VelocitySpread"]=-45,["Lifetime"]={"NR",0.2,2},["Speed"]={"NR",59,59},["Brightness"]=100,["SpreadAngle"]={"V2",-45,45},["Acceleration"]={"V3",0,-30.948,0},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-90,-90},["Transparency"]={"NS",{{0,1,0},{0.09856,0,0},{0.19578,0,0},{0.23042,1,0},{0.26355,0,0},{0.42018,0,0},{0.44578,1,0},{0.47741,0,0},{0.61596,0,0},{0.64608,1,0},{0.67319,0,0},{0.73193,0,0},{0.74849,1,0},{0.76657,0,0},{0.80066,0,0},{1,1,0}}},["Texture"]="rbxassetid://9589739468",["Orientation"]={"E","ParticleOrientation","VelocityParallel"},["Size"]={"NS",{{0,0,0},{0.05567,0.51594,0},{0.096907,0.51594,0},{0.11959,0.51594,0},{0.19934,0.51594,0},{0.24849,0.51594,0},{0.3,0.51594,0},{0.4,0.51594,0},{0.42771,0.51594,0},{0.44578,0,0},{0.50515,0.51594,0},{0.52711,0.51594,0},{0.54819,0,0},{0.57831,0.51594,0},{0.6567,0.51594,0},{0.74096,0.51594,0},{0.7997,0.51594,0},{0.8238,0,0},{0.87801,0.51594,0},{1,0,0}}},["Squash"]={"NS",{{0,0.825,0},{0.034021,0.75,0},{0.078351,-0.1125,0},{0.10928,0.75,0},{0.7741,-0.225,0},{1,-0.3,0.7125}}},["LightEmission"]=1},{["EmitCount"]=25,["EmitDelay"]=0}},{"ParticleEmitter","Specs",{["Color"]={"CS",{{0,1,0.35686,0.16078},{1,1,0.35686,0.16078}}},["Drag"]=5,["ZOffset"]=1.7108,["VelocitySpread"]=-45,["Lifetime"]={"NR",0.2,1},["Speed"]={"NR",12.831,30.795},["Brightness"]=100,["SpreadAngle"]={"V2",-45,45},["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["LockedToPart"]=true,["Rate"]=10,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{0.54124,0,0},{1,0.9625,0}}},["Texture"]="rbxassetid://10556232026",["LightEmission"]=1,["Size"]={"NS",{{0,0,0},{0.2,0.92921,4.2771},{0.4,1.9554,4.2771},{0.6,2.9953,4.2771},{0.8,3.8773,4.2771},{1,4.2771,4.2771}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["FlipbookStartRandom"]=true},{["EmitCount"]=200,["EmitDelay"]=0}},{"ParticleEmitter","Smoke",{["Color"]={"CS",{{0,1,0.35686,0.16078},{1,1,0.35686,0.16078}}},["Drag"]=6,["ZOffset"]=0.12413,["LightInfluence"]=0.25,["Lifetime"]={"NR",2,3},["Speed"]={"NR",9,16},["SpreadAngle"]={"V2",0,1000},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.10896,0.9375,0},{0.18698,0.9,0},{0.23038,0.75,0},{0.26777,0.54375,0},{0.3338,0.44375,0},{0.39889,0.81875,0},{0.49908,0.9375,0},{0.60665,0.96875,0},{0.69945,0.94375,0},{0.79917,0.95625,0},{0.89982,0.98125,0},{1,1,0}}},["EmissionDirection"]={"E","NormalId","Left"},["LightEmission"]=1,["Texture"]="rbxassetid://9860410723",["Size"]={"NS",{{0,0.20012,0.20012},{0.16314,1.5559,0.2597},{0.35866,2.4311,0.28767},{0.52802,2.7423,0.30018},{1,3.1118,0}}},["Squash"]={"NS",{{0,0,0.45},{0.49934,0.0375,0},{1,0,0}}}},{["EmitCount"]=10,["EmitDelay"]=0}},{"ParticleEmitter","Fire",{["FlipbookFramerate"]={"NR",30,30},["Drag"]=11,["ZOffset"]=0.99722,["VelocitySpread"]=35,["Lifetime"]={"NR",0.4,1},["Speed"]={"NR",7.978,69.555},["Brightness"]=100,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["SpreadAngle"]={"V2",35,35},["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["RotSpeed"]={"NR",-50,50},["LockedToPart"]=true,["Rate"]=10,["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{1,0,0}}},["Texture"]="rbxassetid://11418708306",["Size"]={"NS",{{0,0.59292,0.30387},{0.12202,1.1507,0.17431},{0.3866,2.3301,0.097922},{0.73475,3.7397,0.07289},{1,4.6027,0}}},["Color"]={"CS",{{0,1,0.082353,0},{1,1,0.082353,0}}},["Shape"]={"E","ParticleEmitterShape","Disc"}},{["EmitCount"]=15,["EmitDelay"]=0}},{"ParticleEmitter","Fire 2",{["FlipbookFramerate"]={"NR",60,60},["Drag"]=5,["ZOffset"]=0.12609,["Lifetime"]={"NR",1,1},["Speed"]={"NR",27,27},["Brightness"]=30,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["Size"]={"NS",{{0,2.1027,1.0187},{1,2.1027,1.0448}}},["RotSpeed"]={"NR",-1200,-360},["LockedToPart"]=true,["Rate"]=3,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{0.7167,0,0},{0.76744,0.39752,0},{0.83562,0.81366,0},{0.92653,0.95652,0},{1,1,0}}},["Texture"]="rbxassetid://11977056412",["LightEmission"]=0.25,["Color"]={"CS",{{0,1,0.14902,0},{1,1,0.14902,0}}},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Squash"]={"NS",{{0,0,0},{1,0,0}}}}},{"ParticleEmitter","Fire 2",{["FlipbookFramerate"]={"NR",60,60},["Drag"]=5,["ZOffset"]=0.25874,["Lifetime"]={"NR",1,1},["Speed"]={"NR",0.0061561,0.0061561},["Brightness"]=30,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["Size"]={"NS",{{0,4.3147,2.0904},{1,4.3147,2.144}}},["RotSpeed"]={"NR",-1200,-360},["LockedToPart"]=true,["Rate"]=3,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{0.7167,0,0},{0.76744,0.39752,0},{0.83562,0.81366,0},{0.92653,0.95652,0},{1,1,0}}},["Texture"]="rbxassetid://11977056412",["LightEmission"]=0.25,["Color"]={"CS",{{0,1,0.14902,0},{1,1,0.14902,0}}},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Squash"]={"NS",{{0,0,0},{1,0,0}}}}}}},{"Attachment","Attachment",{["CFrame"]={"CF",0,5.3562,0,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,5.3562,0}}},{"ParticleEmitter","Smoke",{["Color"]={"CS",{{0,1,0.35686,0.16078},{1,1,0.35686,0.16078}}},["Drag"]=6,["ZOffset"]=0.24348,["LightInfluence"]=0.25,["Lifetime"]={"NR",2,3},["Speed"]={"NR",0.0018312,0.0018312},["SpreadAngle"]={"V2",0,60},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.10896,0.9375,0},{0.18698,0.9,0},{0.23038,0.75,0},{0.26777,0.54375,0},{0.3338,0.44375,0},{0.39889,0.81875,0},{0.49908,0.9375,0},{0.60665,0.96875,0},{0.69945,0.94375,0},{0.79917,0.95625,0},{0.89982,0.98125,0},{1,1,0}}},["EmissionDirection"]={"E","NormalId","Front"},["LightEmission"]=1,["Texture"]="rbxassetid://9860410723",["Size"]={"NS",{{0,0.39254,0.39254},{0.16314,3.052,0.50941},{0.35866,4.7687,0.56427},{0.52802,5.3791,0.58881},{1,6.1039,0}}},["Squash"]={"NS",{{0,0,0.45},{0.49934,0.0375,0},{1,0,0}}}},{["EmitCount"]=10,["EmitDelay"]=0}}},1},{"Part","Earth",{["CFrame"]={"CF",24.518,0,0,1,0,0,0,1,0,0,0,1},["Size"]={"V3",2,7.0265,2}},nil,nil,{{"Attachment","Attachment",{["CFrame"]={"CF",0,-3.6776,0,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,-3.6776,0}},nil,nil,{{"Beam","Beam",{["FaceCamera"]=true,["Color"]={"CS",{{0,0.22353,0.17647,0.13333},{1,0.22353,0.17647,0.13333}}},["ZOffset"]=1,["Width0"]=0,["Texture"]="rbxassetid://9589762590",["Transparency"]={"NS",{{0,0,0},{1,1,0}}},["Width1"]=40,["Brightness"]=10,["TextureMode"]={"E","TextureMode","Static"},["TextureLength"]=10},nil,{["Attachment1"]={4,2},["Attachment0"]={4,1}}},{"ParticleEmitter","Spin",{["FlipbookFramerate"]={"NR",15,15},["Drag"]=3.25,["Lifetime"]={"NR",0.59043,1.1809},["Speed"]={"NR",18,18},["Brightness"]=5,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid8x8"},["Size"]={"NS",{{0,0,0},{0.2,2.5541,0},{0.4,4.0449,0},{0.6,5.1901,0},{0.8,6.4133,0},{1,10,0}}},["FlipbookMode"]={"E","ParticleFlipbookMode","PingPong"},["RotSpeed"]={"NR",-1600,-860},["LockedToPart"]=true,["Transparency"]={"NS",{{0,0,0},{0.71653,0,0},{0.83887,0.76875,0},{1,1,0}}},["Texture"]="rbxassetid://12350085716",["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Color"]={"CS",{{0,0.22353,0.17647,0.13333},{1,0.22353,0.17647,0.13333}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}}},{["EmitCount"]=2,["EmitDelay"]=0}},{"ParticleEmitter","Specs",{["Color"]={"CS",{{0,0.22353,0.17647,0.13333},{1,0.22353,0.17647,0.13333}}},["Drag"]=5,["ZOffset"]=1.7108,["VelocitySpread"]=-45,["Lifetime"]={"NR",0.2,1},["Speed"]={"NR",12.831,30.795},["Brightness"]=10,["SpreadAngle"]={"V2",-45,45},["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["LockedToPart"]=true,["Rate"]=10,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{0.54124,0,0},{1,0.9625,0}}},["Texture"]="rbxassetid://10556232026",["LightEmission"]=1,["Size"]={"NS",{{0,0,0},{0.2,0.92921,4.2771},{0.4,1.9554,4.2771},{0.6,2.9953,4.2771},{0.8,3.8773,4.2771},{1,4.2771,4.2771}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["FlipbookStartRandom"]=true},{["EmitCount"]=200,["EmitDelay"]=0}},{"ParticleEmitter","Smoke",{["Color"]={"CS",{{0,0.22353,0.17647,0.13333},{1,0.22353,0.17647,0.13333}}},["Drag"]=6,["ZOffset"]=0.12413,["LightInfluence"]=0.25,["Lifetime"]={"NR",2,3},["Speed"]={"NR",9,16},["SpreadAngle"]={"V2",0,1000},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.10896,0.9375,0},{0.18698,0.9,0},{0.23038,0.75,0},{0.26777,0.54375,0},{0.3338,0.44375,0},{0.39889,0.81875,0},{0.49908,0.9375,0},{0.60665,0.96875,0},{0.69945,0.94375,0},{0.79917,0.95625,0},{0.89982,0.98125,0},{1,1,0}}},["EmissionDirection"]={"E","NormalId","Left"},["LightEmission"]=1,["Texture"]="rbxassetid://9860410723",["Size"]={"NS",{{0,0.20012,0.20012},{0.16314,1.5559,0.2597},{0.35866,2.4311,0.28767},{0.52802,2.7423,0.30018},{1,3.1118,0}}},["Squash"]={"NS",{{0,0,0.45},{0.49934,0.0375,0},{1,0,0}}}},{["EmitCount"]=10,["EmitDelay"]=0}}}},{"Attachment","Attachment",{["CFrame"]={"CF",0,5.3562,0,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,5.3562,0}}},{"ParticleEmitter","Smoke",{["Color"]={"CS",{{0,0.22353,0.17647,0.13333},{1,0.22353,0.17647,0.13333}}},["Drag"]=6,["ZOffset"]=0.24348,["LightInfluence"]=0.25,["Lifetime"]={"NR",2,3},["Speed"]={"NR",0.0018312,0.0018312},["SpreadAngle"]={"V2",0,60},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.10896,0.9375,0},{0.18698,0.9,0},{0.23038,0.75,0},{0.26777,0.54375,0},{0.3338,0.44375,0},{0.39889,0.81875,0},{0.49908,0.9375,0},{0.60665,0.96875,0},{0.69945,0.94375,0},{0.79917,0.95625,0},{0.89982,0.98125,0},{1,1,0}}},["EmissionDirection"]={"E","NormalId","Front"},["LightEmission"]=1,["Texture"]="rbxassetid://9860410723",["Size"]={"NS",{{0,0.39254,0.39254},{0.16314,3.052,0.50941},{0.35866,4.7687,0.56427},{0.52802,5.3791,0.58881},{1,6.1039,0}}},["Squash"]={"NS",{{0,0,0.45},{0.49934,0.0375,0},{1,0,0}}}},{["EmitCount"]=10,["EmitDelay"]=0}}},1},{"Part","Poison",{["CFrame"]={"CF",35.73,0,0,1,0,0,0,1,0,0,0,1},["Size"]={"V3",2,7.0265,2}},nil,nil,{{"Attachment","Attachment",{["CFrame"]={"CF",0,-3.6776,0,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,-3.6776,0}},nil,nil,{{"Beam","Beam",{["FaceCamera"]=true,["Color"]={"CS",{{0,0.54902,1,0.031373},{1,0.54902,1,0.031373}}},["ZOffset"]=1,["Width0"]=0,["Texture"]="rbxassetid://9589762590",["Transparency"]={"NS",{{0,0,0},{1,1,0}}},["Width1"]=25,["Brightness"]=10,["TextureMode"]={"E","TextureMode","Static"},["TextureLength"]=10},nil,{["Attachment1"]={5,2},["Attachment0"]={5,1}}},{"ParticleEmitter","Spin",{["FlipbookFramerate"]={"NR",15,15},["Drag"]=3.25,["Lifetime"]={"NR",0.59043,1.1809},["Speed"]={"NR",18,18},["Brightness"]=3,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid8x8"},["Size"]={"NS",{{0,0,0},{0.2,2.5541,0},{0.4,4.0449,0},{0.6,5.1901,0},{0.8,6.4133,0},{1,10,0}}},["FlipbookMode"]={"E","ParticleFlipbookMode","PingPong"},["RotSpeed"]={"NR",-1600,-860},["LockedToPart"]=true,["Rate"]=15,["Transparency"]={"NS",{{0,0,0},{0.71653,0,0},{0.83887,0.76875,0},{1,1,0}}},["Texture"]="rbxassetid://12350085716",["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Color"]={"CS",{{0,0.54902,1,0.031373},{1,0.54902,1,0.031373}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}}},{["EmitCount"]=2,["EmitDelay"]=0}},{"ParticleEmitter","Specs",{["Color"]={"CS",{{0,0.54902,1,0.031373},{1,0.54902,1,0.031373}}},["Drag"]=5,["ZOffset"]=1.7108,["VelocitySpread"]=-35,["Lifetime"]={"NR",0.2,1},["Speed"]={"NR",12.831,30.795},["Brightness"]=100,["SpreadAngle"]={"V2",-35,35},["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["LockedToPart"]=true,["Rate"]=10,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{0.54124,0,0},{1,0.9625,0}}},["Texture"]="rbxassetid://10556232026",["LightEmission"]=1,["Size"]={"NS",{{0,0,0},{0.2,0.92921,4.2771},{0.4,1.9554,4.2771},{0.6,2.9953,4.2771},{0.8,3.8773,4.2771},{1,4.2771,4.2771}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["FlipbookStartRandom"]=true},{["EmitCount"]=200,["EmitDelay"]=0}},{"ParticleEmitter","Smoke",{["Color"]={"CS",{{0,0.54902,1,0.031373},{1,0.54902,1,0.031373}}},["Drag"]=6,["ZOffset"]=0.12413,["LightInfluence"]=0.25,["Lifetime"]={"NR",2,3},["Speed"]={"NR",9,16},["SpreadAngle"]={"V2",0,1000},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.10896,0.9375,0},{0.18698,0.9,0},{0.23038,0.75,0},{0.26777,0.54375,0},{0.3338,0.44375,0},{0.39889,0.81875,0},{0.49908,0.9375,0},{0.60665,0.96875,0},{0.69945,0.94375,0},{0.79917,0.95625,0},{0.89982,0.98125,0},{1,1,0}}},["EmissionDirection"]={"E","NormalId","Left"},["LightEmission"]=1,["Texture"]="rbxassetid://9860410723",["Size"]={"NS",{{0,0.20012,0.20012},{0.16314,1.5559,0.2597},{0.35866,2.4311,0.28767},{0.52802,2.7423,0.30018},{1,3.1118,0}}},["Squash"]={"NS",{{0,0,0.45},{0.49934,0.0375,0},{1,0,0}}}},{["EmitCount"]=10,["EmitDelay"]=0}},{"Beam","Beam",{["FaceCamera"]=true,["Color"]={"CS",{{0,0.54902,1,0.031373},{1,0.54902,1,0.031373}}},["TextureSpeed"]=0.2,["ZOffset"]=1,["Width0"]=0,["Texture"]="rbxassetid://9589826891",["Transparency"]={"NS",{{0,0,0},{0.62789,0.94375,0},{1,1,0}}},["Width1"]=25,["Brightness"]=10,["TextureMode"]={"E","TextureMode","Static"},["TextureLength"]=170},nil,{["Attachment1"]={5,2},["Attachment0"]={5,1}}},{"Beam","Beam",{["FaceCamera"]=true,["Color"]={"CS",{{0,0.54902,1,0.031373},{1,0.54902,1,0.031373}}},["TextureSpeed"]=0.3,["ZOffset"]=1,["Width0"]=0,["Texture"]="rbxassetid://9589826891",["Transparency"]={"NS",{{0,0,0},{0.53924,0.94375,0},{1,1,0}}},["Width1"]=25,["Brightness"]=10,["TextureMode"]={"E","TextureMode","Static"},["TextureLength"]=240},nil,{["Attachment1"]={5,2},["Attachment0"]={5,1}}}}},{"Attachment","Attachment",{["CFrame"]={"CF",0,5.3562,0,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,5.3562,0}}},{"ParticleEmitter","Smoke",{["Color"]={"CS",{{0,0.54902,1,0.031373},{1,0.54902,1,0.031373}}},["Drag"]=6,["ZOffset"]=0.24348,["LightInfluence"]=0.25,["Lifetime"]={"NR",2,3},["Speed"]={"NR",0.0018312,0.0018312},["SpreadAngle"]={"V2",0,60},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.10896,0.9375,0},{0.18698,0.9,0},{0.23038,0.75,0},{0.26777,0.54375,0},{0.3338,0.44375,0},{0.39889,0.81875,0},{0.49908,0.9375,0},{0.60665,0.96875,0},{0.69945,0.94375,0},{0.79917,0.95625,0},{0.89982,0.98125,0},{1,1,0}}},["EmissionDirection"]={"E","NormalId","Front"},["LightEmission"]=1,["Texture"]="rbxassetid://9860410723",["Size"]={"NS",{{0,0.39254,0.39254},{0.16314,3.052,0.50941},{0.35866,4.7687,0.56427},{0.52802,5.3791,0.58881},{1,6.1039,0}}},["Squash"]={"NS",{{0,0,0.45},{0.49934,0.0375,0},{1,0,0}}}},{["EmitCount"]=10,["EmitDelay"]=0}}},1}},
        	["Tornado Earth"] = {{"Part","Wind",{["CFrame"]={"CF",0,0,0,1,0,0,0,1,0,0,0,1},["Size"]={"V3",2,7.0265,2}},nil,nil,{{"Attachment","Attachment",{["CFrame"]={"CF",0,-3.6776,0,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,-3.6776,0}},nil,nil,{{"Beam","Beam",{["FaceCamera"]=true,["Color"]={"CS",{{0,0.6,0.82745,1},{1,0.6,0.82745,1}}},["ZOffset"]=1,["Width0"]=0,["Texture"]="rbxassetid://9589762590",["Transparency"]={"NS",{{0,0,0},{1,1,0}}},["Width1"]=25,["Brightness"]=10,["TextureMode"]={"E","TextureMode","Static"},["TextureLength"]=10},nil,{["Attachment1"]={1,2},["Attachment0"]={1,1}}},{"ParticleEmitter","Spin",{["FlipbookFramerate"]={"NR",15,15},["Drag"]=3.25,["Lifetime"]={"NR",0.59043,1.1809},["Speed"]={"NR",18,18},["Brightness"]=3,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid8x8"},["Size"]={"NS",{{0,0,0},{0.2,2.5541,0},{0.4,4.0449,0},{0.6,5.1901,0},{0.8,6.4133,0},{1,10,0}}},["FlipbookMode"]={"E","ParticleFlipbookMode","PingPong"},["RotSpeed"]={"NR",-1600,-860},["LockedToPart"]=true,["Rate"]=15,["Transparency"]={"NS",{{0,0,0},{0.71653,0,0},{0.83887,0.76875,0},{1,1,0}}},["Texture"]="rbxassetid://12350085716",["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Color"]={"CS",{{0,0.72549,0.96471,1},{1,0.72549,0.96471,1}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}}},{["EmitCount"]=2,["EmitDelay"]=0}},{"ParticleEmitter","Specs",{["Color"]={"CS",{{0,0.21961,0.4,1},{1,0.21961,0.4,1}}},["Drag"]=5,["ZOffset"]=1.7108,["VelocitySpread"]=-35,["Lifetime"]={"NR",0.2,1},["Speed"]={"NR",12.831,30.795},["Brightness"]=100,["SpreadAngle"]={"V2",-35,35},["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["LockedToPart"]=true,["Rate"]=10,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{0.54124,0,0},{1,0.9625,0}}},["Texture"]="rbxassetid://10556232026",["LightEmission"]=1,["Size"]={"NS",{{0,0,0},{0.2,0.92921,4.2771},{0.4,1.9554,4.2771},{0.6,2.9953,4.2771},{0.8,3.8773,4.2771},{1,4.2771,4.2771}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["FlipbookStartRandom"]=true},{["EmitCount"]=200,["EmitDelay"]=0}},{"ParticleEmitter","Smoke",{["Color"]={"CS",{{0,0.6,0.82745,1},{1,0.6,0.82745,1}}},["Drag"]=6,["ZOffset"]=0.12413,["LightInfluence"]=0.25,["Lifetime"]={"NR",2,3},["Speed"]={"NR",9,16},["SpreadAngle"]={"V2",0,1000},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.10896,0.9375,0},{0.18698,0.9,0},{0.23038,0.75,0},{0.26777,0.54375,0},{0.3338,0.44375,0},{0.39889,0.81875,0},{0.49908,0.9375,0},{0.60665,0.96875,0},{0.69945,0.94375,0},{0.79917,0.95625,0},{0.89982,0.98125,0},{1,1,0}}},["EmissionDirection"]={"E","NormalId","Left"},["LightEmission"]=1,["Texture"]="rbxassetid://9860410723",["Size"]={"NS",{{0,0.20012,0.20012},{0.16314,1.5559,0.2597},{0.35866,2.4311,0.28767},{0.52802,2.7423,0.30018},{1,3.1118,0}}},["Squash"]={"NS",{{0,0,0.45},{0.49934,0.0375,0},{1,0,0}}}},{["EmitCount"]=10,["EmitDelay"]=0}},{"Beam","Beam",{["FaceCamera"]=true,["Color"]={"CS",{{0,0.6,0.82745,1},{1,0.6,0.82745,1}}},["TextureSpeed"]=0.2,["ZOffset"]=1,["Width0"]=0,["Texture"]="rbxassetid://9589826891",["Transparency"]={"NS",{{0,0,0},{0.62789,0.94375,0},{1,1,0}}},["Width1"]=25,["Brightness"]=10,["TextureMode"]={"E","TextureMode","Static"},["TextureLength"]=170},nil,{["Attachment1"]={1,2},["Attachment0"]={1,1}}},{"Beam","Beam",{["FaceCamera"]=true,["Color"]={"CS",{{0,0.6,0.82745,1},{1,0.6,0.82745,1}}},["TextureSpeed"]=0.3,["ZOffset"]=1,["Width0"]=0,["Texture"]="rbxassetid://9589826891",["Transparency"]={"NS",{{0,0,0},{0.53924,0.94375,0},{1,1,0}}},["Width1"]=25,["Brightness"]=10,["TextureMode"]={"E","TextureMode","Static"},["TextureLength"]=240},nil,{["Attachment1"]={1,2},["Attachment0"]={1,1}}}}},{"Attachment","Attachment",{["CFrame"]={"CF",0,5.3562,0,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,5.3562,0}}},{"ParticleEmitter","Smoke",{["Color"]={"CS",{{0,0.6,0.82745,1},{1,0.6,0.82745,1}}},["Drag"]=6,["ZOffset"]=0.24348,["LightInfluence"]=0.25,["Lifetime"]={"NR",2,3},["Speed"]={"NR",0.0018312,0.0018312},["SpreadAngle"]={"V2",0,60},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.10896,0.9375,0},{0.18698,0.9,0},{0.23038,0.75,0},{0.26777,0.54375,0},{0.3338,0.44375,0},{0.39889,0.81875,0},{0.49908,0.9375,0},{0.60665,0.96875,0},{0.69945,0.94375,0},{0.79917,0.95625,0},{0.89982,0.98125,0},{1,1,0}}},["EmissionDirection"]={"E","NormalId","Front"},["LightEmission"]=1,["Texture"]="rbxassetid://9860410723",["Size"]={"NS",{{0,0.39254,0.39254},{0.16314,3.052,0.50941},{0.35866,4.7687,0.56427},{0.52802,5.3791,0.58881},{1,6.1039,0}}},["Squash"]={"NS",{{0,0,0.45},{0.49934,0.0375,0},{1,0,0}}}},{["EmitCount"]=10,["EmitDelay"]=0}}},1},{"Part","Lightning",{["CFrame"]={"CF",-11.973,0,0,1,0,0,0,1,0,0,0,1},["Size"]={"V3",2,7.0265,2}},nil,nil,{{"Attachment","Attachment",{["CFrame"]={"CF",0,-3.6776,0,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,-3.6776,0}},nil,nil,{{"Beam","Beam",{["FaceCamera"]=true,["Color"]={"CS",{{0,0,0.29804,1},{1,0,0.29804,1}}},["ZOffset"]=1,["Width0"]=0,["Texture"]="rbxassetid://9589762590",["Transparency"]={"NS",{{0,0,0},{1,1,0}}},["Width1"]=25,["Brightness"]=10,["TextureMode"]={"E","TextureMode","Static"},["TextureLength"]=10},nil,{["Attachment1"]={2,2},["Attachment0"]={2,1}}},{"ParticleEmitter","Spin",{["FlipbookFramerate"]={"NR",15,15},["Drag"]=3.25,["Lifetime"]={"NR",0.59043,1.1809},["Speed"]={"NR",18,18},["Brightness"]=5,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid8x8"},["Size"]={"NS",{{0,0,0},{0.2,2.5541,0},{0.4,4.0449,0},{0.6,5.1901,0},{0.8,6.4133,0},{1,10,0}}},["FlipbookMode"]={"E","ParticleFlipbookMode","PingPong"},["RotSpeed"]={"NR",-1600,-860},["LockedToPart"]=true,["Rate"]=15,["Transparency"]={"NS",{{0,0,0},{0.71653,0,0},{0.83887,0.76875,0},{1,1,0}}},["Texture"]="rbxassetid://12350085716",["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Color"]={"CS",{{0,0.20784,0.5098,1},{1,0.20784,0.5098,1}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}}},{["EmitCount"]=2,["EmitDelay"]=0}},{"ParticleEmitter","Lines ",{["Color"]={"CS",{{0,0.13333,0.43529,1},{1,0.13333,0.43529,1}}},["Drag"]=3,["ZOffset"]=0.60482,["VelocitySpread"]=-45,["Lifetime"]={"NR",0.2,0.7},["Speed"]={"NR",8.8728,51.962},["Brightness"]=100,["SpreadAngle"]={"V2",-45,45},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-90,-90},["Transparency"]={"NS",{{0,1,0},{0.09856,0,0},{0.19578,0,0},{0.23042,1,0},{0.26355,0,0},{0.42018,0,0},{0.44578,1,0},{0.47741,0,0},{0.61596,0,0},{0.64608,1,0},{0.67319,0,0},{0.73193,0,0},{0.74849,1,0},{0.76657,0,0},{0.80066,0,0},{1,1,0}}},["Texture"]="rbxassetid://7828271118",["LightEmission"]=1,["Size"]={"NS",{{0,0,0},{0.5,0.88215,0},{1,0,0}}},["Orientation"]={"E","ParticleOrientation","VelocityParallel"},["Squash"]={"NS",{{0,0,0},{1,0,0}}}},{["EmitCount"]=25,["EmitDelay"]=0}},{"ParticleEmitter","Lines 3",{["Color"]={"CS",{{0,0.16471,0.3451,1},{1,0.16471,0.3451,1}}},["Drag"]=5,["ZOffset"]=0.60482,["VelocitySpread"]=-45,["Lifetime"]={"NR",0.2,2},["Speed"]={"NR",4.596,91.962},["Brightness"]=100,["SpreadAngle"]={"V2",-45,45},["Acceleration"]={"V3",0,-50,0},["Rate"]=5,["Rotation"]={"NR",-90,-90},["Transparency"]={"NS",{{0,1,0},{0.09856,0,0},{0.19578,0,0},{0.23042,1,0},{0.26355,0,0},{0.42018,0,0},{0.44578,1,0},{0.47741,0,0},{0.61596,0,0},{0.64608,1,0},{0.67319,0,0},{0.73193,0,0},{0.74849,1,0},{0.76657,0,0},{0.80066,0,0},{1,1,0}}},["Texture"]="rbxassetid://9710377531",["Orientation"]={"E","ParticleOrientation","VelocityParallel"},["Size"]={"NS",{{0,0,0},{0.05567,0.21385,0.010984},{0.096907,2.1653,0.55128},{0.11959,0.26732,0.021617},{0.19934,0.21333,0.037926},{0.24849,0.52165,0.037926},{0.3,0.082184,0.037926},{0.4,0.094068,0.037926},{0.42771,0.27973,0.037103},{0.44578,0,0},{0.50515,1.6039,0.035308},{0.52711,0.50653,0.034213},{0.54819,0,0},{0.57831,0.30997,0.032661},{0.6567,0.071111,0.030286},{0.74096,0.43849,0.02509},{0.7997,0.31753,0.023703},{0.8238,0,0},{0.87801,0.19657,0.014436},{1,0,0}}},["LightEmission"]=1,["Squash"]={"NS",{{0,0.825,0},{0.034021,0.75,0},{0.078351,-0.1125,0},{0.10928,0.75,0},{0.7741,-0.225,0},{1,-0.3,0.7125}}}},{["EmitCount"]=25,["EmitDelay"]=0}},{"ParticleEmitter","Specs",{["Color"]={"CS",{{0,0.21961,0.4,1},{1,0.21961,0.4,1}}},["Drag"]=5,["ZOffset"]=1.7108,["VelocitySpread"]=-45,["Lifetime"]={"NR",0.2,1},["Speed"]={"NR",12.831,30.795},["Brightness"]=100,["SpreadAngle"]={"V2",-45,45},["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["LockedToPart"]=true,["Rate"]=10,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{0.54124,0,0},{1,0.9625,0}}},["Texture"]="rbxassetid://10556232026",["LightEmission"]=1,["Size"]={"NS",{{0,0,0},{0.2,0.92921,4.2771},{0.4,1.9554,4.2771},{0.6,2.9953,4.2771},{0.8,3.8773,4.2771},{1,4.2771,4.2771}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["FlipbookStartRandom"]=true},{["EmitCount"]=200,["EmitDelay"]=0}},{"ParticleEmitter","Smoke",{["Color"]={"CS",{{0,0,0.29804,1},{1,0,0.29804,1}}},["Drag"]=6,["ZOffset"]=0.14203,["LightInfluence"]=0.25,["Lifetime"]={"NR",2,3},["Speed"]={"NR",14,14},["SpreadAngle"]={"V2",0,1000},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.10896,0.9375,0},{0.18698,0.9,0},{0.23038,0.75,0},{0.26777,0.54375,0},{0.3338,0.44375,0},{0.39889,0.81875,0},{0.49908,0.9375,0},{0.60665,0.96875,0},{0.69945,0.94375,0},{0.79917,0.95625,0},{0.89982,0.98125,0},{1,1,0}}},["EmissionDirection"]={"E","NormalId","Left"},["LightEmission"]=1,["Texture"]="rbxassetid://9860410723",["Size"]={"NS",{{0,0.22899,0.22899},{0.16314,1.7804,0.29717},{0.35866,2.7818,0.32917},{0.52802,3.1379,0.34348},{1,3.5607,0}}},["Squash"]={"NS",{{0,0,0.45},{0.49934,0.0375,0},{1,0,0}}}},{["EmitCount"]=10,["EmitDelay"]=0}}}},{"Attachment","Attachment",{["CFrame"]={"CF",0,5.3562,0,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,5.3562,0}}},{"ParticleEmitter","Lightning",{["Color"]={"CS",{{0,0,0.34902,1},{1,0,0.34902,1}}},["ZOffset"]=4,["VelocitySpread"]=-360,["Lifetime"]={"NR",0.2,0.55},["Speed"]={"NR",0.0010192,0.0010192},["Brightness"]=3,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["SpreadAngle"]={"V2",-360,360},["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["LockedToPart"]=true,["Rate"]=4,["Texture"]="rbxassetid://11363411020",["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{1,0,0}}},["Size"]={"NS",{{0,5.6523,0},{1,5.6523,0}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Orientation"]={"E","ParticleOrientation","VelocityParallel"},["FlipbookFramerate"]={"NR",3.9,3.9},["LightEmission"]=1},{["EmitCount"]=7,["EmitDelay"]=0}},{"ParticleEmitter","Smoke",{["Color"]={"CS",{{0,0,0.29804,1},{1,0,0.29804,1}}},["Drag"]=6,["ZOffset"]=0.24348,["LightInfluence"]=0.25,["Lifetime"]={"NR",2,3},["Speed"]={"NR",0.0018312,0.0018312},["SpreadAngle"]={"V2",0,60},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.10896,0.9375,0},{0.18698,0.9,0},{0.23038,0.75,0},{0.26777,0.54375,0},{0.3338,0.44375,0},{0.39889,0.81875,0},{0.49908,0.9375,0},{0.60665,0.96875,0},{0.69945,0.94375,0},{0.79917,0.95625,0},{0.89982,0.98125,0},{1,1,0}}},["EmissionDirection"]={"E","NormalId","Front"},["LightEmission"]=1,["Texture"]="rbxassetid://9860410723",["Size"]={"NS",{{0,0.39254,0.39254},{0.16314,3.052,0.50941},{0.35866,4.7687,0.56427},{0.52802,5.3791,0.58881},{1,6.1039,0}}},["Squash"]={"NS",{{0,0,0.45},{0.49934,0.0375,0},{1,0,0}}}},{["EmitCount"]=10,["EmitDelay"]=0}}},1},{"Part","Fire",{["CFrame"]={"CF",12.392,0,0,1,0,0,0,1,0,0,0,1},["Size"]={"V3",2,7.0265,2}},nil,nil,{{"Attachment","Attachment",{["CFrame"]={"CF",0,-3.6776,0,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,-3.6776,0}},nil,nil,{{"Beam","Beam",{["FaceCamera"]=true,["Color"]={"CS",{{0,1,0.35686,0.16078},{1,1,0.35686,0.16078}}},["ZOffset"]=1,["Width0"]=0,["Texture"]="rbxassetid://9589762590",["Transparency"]={"NS",{{0,0,0},{1,1,0}}},["Width1"]=25,["Brightness"]=10,["TextureMode"]={"E","TextureMode","Static"},["TextureLength"]=10},nil,{["Attachment1"]={3,2},["Attachment0"]={3,1}}},{"ParticleEmitter","Spin",{["FlipbookFramerate"]={"NR",15,15},["Drag"]=3.25,["Lifetime"]={"NR",0.59043,1.1809},["Speed"]={"NR",18,18},["Brightness"]=5,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid8x8"},["Size"]={"NS",{{0,0,0},{0.2,2.5541,0},{0.4,4.0449,0},{0.6,5.1901,0},{0.8,6.4133,0},{1,10,0}}},["FlipbookMode"]={"E","ParticleFlipbookMode","PingPong"},["RotSpeed"]={"NR",-1600,-860},["LockedToPart"]=true,["Rate"]=15,["Transparency"]={"NS",{{0,0,0},{0.71653,0,0},{0.83887,0.76875,0},{1,1,0}}},["Texture"]="rbxassetid://12350085716",["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Color"]={"CS",{{0,1,0.35686,0.16078},{1,1,0.35686,0.16078}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}}},{["EmitCount"]=2,["EmitDelay"]=0}},{"ParticleEmitter","Lines 3",{["Color"]={"CS",{{0,1,0.35686,0.16078},{1,1,0.35686,0.16078}}},["Drag"]=5,["ZOffset"]=0.055849,["VelocitySpread"]=-45,["Lifetime"]={"NR",0.2,2},["Speed"]={"NR",59,59},["Brightness"]=100,["SpreadAngle"]={"V2",-45,45},["Acceleration"]={"V3",0,-30.948,0},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-90,-90},["Transparency"]={"NS",{{0,1,0},{0.09856,0,0},{0.19578,0,0},{0.23042,1,0},{0.26355,0,0},{0.42018,0,0},{0.44578,1,0},{0.47741,0,0},{0.61596,0,0},{0.64608,1,0},{0.67319,0,0},{0.73193,0,0},{0.74849,1,0},{0.76657,0,0},{0.80066,0,0},{1,1,0}}},["Texture"]="rbxassetid://9589739468",["Orientation"]={"E","ParticleOrientation","VelocityParallel"},["Size"]={"NS",{{0,0,0},{0.05567,0.51594,0},{0.096907,0.51594,0},{0.11959,0.51594,0},{0.19934,0.51594,0},{0.24849,0.51594,0},{0.3,0.51594,0},{0.4,0.51594,0},{0.42771,0.51594,0},{0.44578,0,0},{0.50515,0.51594,0},{0.52711,0.51594,0},{0.54819,0,0},{0.57831,0.51594,0},{0.6567,0.51594,0},{0.74096,0.51594,0},{0.7997,0.51594,0},{0.8238,0,0},{0.87801,0.51594,0},{1,0,0}}},["Squash"]={"NS",{{0,0.825,0},{0.034021,0.75,0},{0.078351,-0.1125,0},{0.10928,0.75,0},{0.7741,-0.225,0},{1,-0.3,0.7125}}},["LightEmission"]=1},{["EmitCount"]=25,["EmitDelay"]=0}},{"ParticleEmitter","Specs",{["Color"]={"CS",{{0,1,0.35686,0.16078},{1,1,0.35686,0.16078}}},["Drag"]=5,["ZOffset"]=1.7108,["VelocitySpread"]=-45,["Lifetime"]={"NR",0.2,1},["Speed"]={"NR",12.831,30.795},["Brightness"]=100,["SpreadAngle"]={"V2",-45,45},["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["LockedToPart"]=true,["Rate"]=10,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{0.54124,0,0},{1,0.9625,0}}},["Texture"]="rbxassetid://10556232026",["LightEmission"]=1,["Size"]={"NS",{{0,0,0},{0.2,0.92921,4.2771},{0.4,1.9554,4.2771},{0.6,2.9953,4.2771},{0.8,3.8773,4.2771},{1,4.2771,4.2771}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["FlipbookStartRandom"]=true},{["EmitCount"]=200,["EmitDelay"]=0}},{"ParticleEmitter","Smoke",{["Color"]={"CS",{{0,1,0.35686,0.16078},{1,1,0.35686,0.16078}}},["Drag"]=6,["ZOffset"]=0.12413,["LightInfluence"]=0.25,["Lifetime"]={"NR",2,3},["Speed"]={"NR",9,16},["SpreadAngle"]={"V2",0,1000},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.10896,0.9375,0},{0.18698,0.9,0},{0.23038,0.75,0},{0.26777,0.54375,0},{0.3338,0.44375,0},{0.39889,0.81875,0},{0.49908,0.9375,0},{0.60665,0.96875,0},{0.69945,0.94375,0},{0.79917,0.95625,0},{0.89982,0.98125,0},{1,1,0}}},["EmissionDirection"]={"E","NormalId","Left"},["LightEmission"]=1,["Texture"]="rbxassetid://9860410723",["Size"]={"NS",{{0,0.20012,0.20012},{0.16314,1.5559,0.2597},{0.35866,2.4311,0.28767},{0.52802,2.7423,0.30018},{1,3.1118,0}}},["Squash"]={"NS",{{0,0,0.45},{0.49934,0.0375,0},{1,0,0}}}},{["EmitCount"]=10,["EmitDelay"]=0}},{"ParticleEmitter","Fire",{["FlipbookFramerate"]={"NR",30,30},["Drag"]=11,["ZOffset"]=0.99722,["VelocitySpread"]=35,["Lifetime"]={"NR",0.4,1},["Speed"]={"NR",7.978,69.555},["Brightness"]=100,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["SpreadAngle"]={"V2",35,35},["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["RotSpeed"]={"NR",-50,50},["LockedToPart"]=true,["Rate"]=10,["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{1,0,0}}},["Texture"]="rbxassetid://11418708306",["Size"]={"NS",{{0,0.59292,0.30387},{0.12202,1.1507,0.17431},{0.3866,2.3301,0.097922},{0.73475,3.7397,0.07289},{1,4.6027,0}}},["Color"]={"CS",{{0,1,0.082353,0},{1,1,0.082353,0}}},["Shape"]={"E","ParticleEmitterShape","Disc"}},{["EmitCount"]=15,["EmitDelay"]=0}},{"ParticleEmitter","Fire 2",{["FlipbookFramerate"]={"NR",60,60},["Drag"]=5,["ZOffset"]=0.12609,["Lifetime"]={"NR",1,1},["Speed"]={"NR",27,27},["Brightness"]=30,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["Size"]={"NS",{{0,2.1027,1.0187},{1,2.1027,1.0448}}},["RotSpeed"]={"NR",-1200,-360},["LockedToPart"]=true,["Rate"]=3,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{0.7167,0,0},{0.76744,0.39752,0},{0.83562,0.81366,0},{0.92653,0.95652,0},{1,1,0}}},["Texture"]="rbxassetid://11977056412",["LightEmission"]=0.25,["Color"]={"CS",{{0,1,0.14902,0},{1,1,0.14902,0}}},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Squash"]={"NS",{{0,0,0},{1,0,0}}}}},{"ParticleEmitter","Fire 2",{["FlipbookFramerate"]={"NR",60,60},["Drag"]=5,["ZOffset"]=0.25874,["Lifetime"]={"NR",1,1},["Speed"]={"NR",0.0061561,0.0061561},["Brightness"]=30,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["Size"]={"NS",{{0,4.3147,2.0904},{1,4.3147,2.144}}},["RotSpeed"]={"NR",-1200,-360},["LockedToPart"]=true,["Rate"]=3,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{0.7167,0,0},{0.76744,0.39752,0},{0.83562,0.81366,0},{0.92653,0.95652,0},{1,1,0}}},["Texture"]="rbxassetid://11977056412",["LightEmission"]=0.25,["Color"]={"CS",{{0,1,0.14902,0},{1,1,0.14902,0}}},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Squash"]={"NS",{{0,0,0},{1,0,0}}}}}}},{"Attachment","Attachment",{["CFrame"]={"CF",0,5.3562,0,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,5.3562,0}}},{"ParticleEmitter","Smoke",{["Color"]={"CS",{{0,1,0.35686,0.16078},{1,1,0.35686,0.16078}}},["Drag"]=6,["ZOffset"]=0.24348,["LightInfluence"]=0.25,["Lifetime"]={"NR",2,3},["Speed"]={"NR",0.0018312,0.0018312},["SpreadAngle"]={"V2",0,60},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.10896,0.9375,0},{0.18698,0.9,0},{0.23038,0.75,0},{0.26777,0.54375,0},{0.3338,0.44375,0},{0.39889,0.81875,0},{0.49908,0.9375,0},{0.60665,0.96875,0},{0.69945,0.94375,0},{0.79917,0.95625,0},{0.89982,0.98125,0},{1,1,0}}},["EmissionDirection"]={"E","NormalId","Front"},["LightEmission"]=1,["Texture"]="rbxassetid://9860410723",["Size"]={"NS",{{0,0.39254,0.39254},{0.16314,3.052,0.50941},{0.35866,4.7687,0.56427},{0.52802,5.3791,0.58881},{1,6.1039,0}}},["Squash"]={"NS",{{0,0,0.45},{0.49934,0.0375,0},{1,0,0}}}},{["EmitCount"]=10,["EmitDelay"]=0}}},1},{"Part","Earth",{["CFrame"]={"CF",24.518,0,0,1,0,0,0,1,0,0,0,1},["Size"]={"V3",2,7.0265,2}},nil,nil,{{"Attachment","Attachment",{["CFrame"]={"CF",0,-3.6776,0,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,-3.6776,0}},nil,nil,{{"Beam","Beam",{["FaceCamera"]=true,["Color"]={"CS",{{0,0.22353,0.17647,0.13333},{1,0.22353,0.17647,0.13333}}},["ZOffset"]=1,["Width0"]=0,["Texture"]="rbxassetid://9589762590",["Transparency"]={"NS",{{0,0,0},{1,1,0}}},["Width1"]=40,["Brightness"]=10,["TextureMode"]={"E","TextureMode","Static"},["TextureLength"]=10},nil,{["Attachment1"]={4,2},["Attachment0"]={4,1}}},{"ParticleEmitter","Spin",{["FlipbookFramerate"]={"NR",15,15},["Drag"]=3.25,["Lifetime"]={"NR",0.59043,1.1809},["Speed"]={"NR",18,18},["Brightness"]=5,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid8x8"},["Size"]={"NS",{{0,0,0},{0.2,2.5541,0},{0.4,4.0449,0},{0.6,5.1901,0},{0.8,6.4133,0},{1,10,0}}},["FlipbookMode"]={"E","ParticleFlipbookMode","PingPong"},["RotSpeed"]={"NR",-1600,-860},["LockedToPart"]=true,["Transparency"]={"NS",{{0,0,0},{0.71653,0,0},{0.83887,0.76875,0},{1,1,0}}},["Texture"]="rbxassetid://12350085716",["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Color"]={"CS",{{0,0.22353,0.17647,0.13333},{1,0.22353,0.17647,0.13333}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}}},{["EmitCount"]=2,["EmitDelay"]=0}},{"ParticleEmitter","Specs",{["Color"]={"CS",{{0,0.22353,0.17647,0.13333},{1,0.22353,0.17647,0.13333}}},["Drag"]=5,["ZOffset"]=1.7108,["VelocitySpread"]=-45,["Lifetime"]={"NR",0.2,1},["Speed"]={"NR",12.831,30.795},["Brightness"]=10,["SpreadAngle"]={"V2",-45,45},["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["LockedToPart"]=true,["Rate"]=10,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{0.54124,0,0},{1,0.9625,0}}},["Texture"]="rbxassetid://10556232026",["LightEmission"]=1,["Size"]={"NS",{{0,0,0},{0.2,0.92921,4.2771},{0.4,1.9554,4.2771},{0.6,2.9953,4.2771},{0.8,3.8773,4.2771},{1,4.2771,4.2771}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["FlipbookStartRandom"]=true},{["EmitCount"]=200,["EmitDelay"]=0}},{"ParticleEmitter","Smoke",{["Color"]={"CS",{{0,0.22353,0.17647,0.13333},{1,0.22353,0.17647,0.13333}}},["Drag"]=6,["ZOffset"]=0.12413,["LightInfluence"]=0.25,["Lifetime"]={"NR",2,3},["Speed"]={"NR",9,16},["SpreadAngle"]={"V2",0,1000},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.10896,0.9375,0},{0.18698,0.9,0},{0.23038,0.75,0},{0.26777,0.54375,0},{0.3338,0.44375,0},{0.39889,0.81875,0},{0.49908,0.9375,0},{0.60665,0.96875,0},{0.69945,0.94375,0},{0.79917,0.95625,0},{0.89982,0.98125,0},{1,1,0}}},["EmissionDirection"]={"E","NormalId","Left"},["LightEmission"]=1,["Texture"]="rbxassetid://9860410723",["Size"]={"NS",{{0,0.20012,0.20012},{0.16314,1.5559,0.2597},{0.35866,2.4311,0.28767},{0.52802,2.7423,0.30018},{1,3.1118,0}}},["Squash"]={"NS",{{0,0,0.45},{0.49934,0.0375,0},{1,0,0}}}},{["EmitCount"]=10,["EmitDelay"]=0}}}},{"Attachment","Attachment",{["CFrame"]={"CF",0,5.3562,0,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,5.3562,0}}},{"ParticleEmitter","Smoke",{["Color"]={"CS",{{0,0.22353,0.17647,0.13333},{1,0.22353,0.17647,0.13333}}},["Drag"]=6,["ZOffset"]=0.24348,["LightInfluence"]=0.25,["Lifetime"]={"NR",2,3},["Speed"]={"NR",0.0018312,0.0018312},["SpreadAngle"]={"V2",0,60},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.10896,0.9375,0},{0.18698,0.9,0},{0.23038,0.75,0},{0.26777,0.54375,0},{0.3338,0.44375,0},{0.39889,0.81875,0},{0.49908,0.9375,0},{0.60665,0.96875,0},{0.69945,0.94375,0},{0.79917,0.95625,0},{0.89982,0.98125,0},{1,1,0}}},["EmissionDirection"]={"E","NormalId","Front"},["LightEmission"]=1,["Texture"]="rbxassetid://9860410723",["Size"]={"NS",{{0,0.39254,0.39254},{0.16314,3.052,0.50941},{0.35866,4.7687,0.56427},{0.52802,5.3791,0.58881},{1,6.1039,0}}},["Squash"]={"NS",{{0,0,0.45},{0.49934,0.0375,0},{1,0,0}}}},{["EmitCount"]=10,["EmitDelay"]=0}}},1},{"Part","Poison",{["CFrame"]={"CF",35.73,0,0,1,0,0,0,1,0,0,0,1},["Size"]={"V3",2,7.0265,2}},nil,nil,{{"Attachment","Attachment",{["CFrame"]={"CF",0,-3.6776,0,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,-3.6776,0}},nil,nil,{{"Beam","Beam",{["FaceCamera"]=true,["Color"]={"CS",{{0,0.54902,1,0.031373},{1,0.54902,1,0.031373}}},["ZOffset"]=1,["Width0"]=0,["Texture"]="rbxassetid://9589762590",["Transparency"]={"NS",{{0,0,0},{1,1,0}}},["Width1"]=25,["Brightness"]=10,["TextureMode"]={"E","TextureMode","Static"},["TextureLength"]=10},nil,{["Attachment1"]={5,2},["Attachment0"]={5,1}}},{"ParticleEmitter","Spin",{["FlipbookFramerate"]={"NR",15,15},["Drag"]=3.25,["Lifetime"]={"NR",0.59043,1.1809},["Speed"]={"NR",18,18},["Brightness"]=3,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid8x8"},["Size"]={"NS",{{0,0,0},{0.2,2.5541,0},{0.4,4.0449,0},{0.6,5.1901,0},{0.8,6.4133,0},{1,10,0}}},["FlipbookMode"]={"E","ParticleFlipbookMode","PingPong"},["RotSpeed"]={"NR",-1600,-860},["LockedToPart"]=true,["Rate"]=15,["Transparency"]={"NS",{{0,0,0},{0.71653,0,0},{0.83887,0.76875,0},{1,1,0}}},["Texture"]="rbxassetid://12350085716",["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Color"]={"CS",{{0,0.54902,1,0.031373},{1,0.54902,1,0.031373}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}}},{["EmitCount"]=2,["EmitDelay"]=0}},{"ParticleEmitter","Specs",{["Color"]={"CS",{{0,0.54902,1,0.031373},{1,0.54902,1,0.031373}}},["Drag"]=5,["ZOffset"]=1.7108,["VelocitySpread"]=-35,["Lifetime"]={"NR",0.2,1},["Speed"]={"NR",12.831,30.795},["Brightness"]=100,["SpreadAngle"]={"V2",-35,35},["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["LockedToPart"]=true,["Rate"]=10,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{0.54124,0,0},{1,0.9625,0}}},["Texture"]="rbxassetid://10556232026",["LightEmission"]=1,["Size"]={"NS",{{0,0,0},{0.2,0.92921,4.2771},{0.4,1.9554,4.2771},{0.6,2.9953,4.2771},{0.8,3.8773,4.2771},{1,4.2771,4.2771}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["FlipbookStartRandom"]=true},{["EmitCount"]=200,["EmitDelay"]=0}},{"ParticleEmitter","Smoke",{["Color"]={"CS",{{0,0.54902,1,0.031373},{1,0.54902,1,0.031373}}},["Drag"]=6,["ZOffset"]=0.12413,["LightInfluence"]=0.25,["Lifetime"]={"NR",2,3},["Speed"]={"NR",9,16},["SpreadAngle"]={"V2",0,1000},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.10896,0.9375,0},{0.18698,0.9,0},{0.23038,0.75,0},{0.26777,0.54375,0},{0.3338,0.44375,0},{0.39889,0.81875,0},{0.49908,0.9375,0},{0.60665,0.96875,0},{0.69945,0.94375,0},{0.79917,0.95625,0},{0.89982,0.98125,0},{1,1,0}}},["EmissionDirection"]={"E","NormalId","Left"},["LightEmission"]=1,["Texture"]="rbxassetid://9860410723",["Size"]={"NS",{{0,0.20012,0.20012},{0.16314,1.5559,0.2597},{0.35866,2.4311,0.28767},{0.52802,2.7423,0.30018},{1,3.1118,0}}},["Squash"]={"NS",{{0,0,0.45},{0.49934,0.0375,0},{1,0,0}}}},{["EmitCount"]=10,["EmitDelay"]=0}},{"Beam","Beam",{["FaceCamera"]=true,["Color"]={"CS",{{0,0.54902,1,0.031373},{1,0.54902,1,0.031373}}},["TextureSpeed"]=0.2,["ZOffset"]=1,["Width0"]=0,["Texture"]="rbxassetid://9589826891",["Transparency"]={"NS",{{0,0,0},{0.62789,0.94375,0},{1,1,0}}},["Width1"]=25,["Brightness"]=10,["TextureMode"]={"E","TextureMode","Static"},["TextureLength"]=170},nil,{["Attachment1"]={5,2},["Attachment0"]={5,1}}},{"Beam","Beam",{["FaceCamera"]=true,["Color"]={"CS",{{0,0.54902,1,0.031373},{1,0.54902,1,0.031373}}},["TextureSpeed"]=0.3,["ZOffset"]=1,["Width0"]=0,["Texture"]="rbxassetid://9589826891",["Transparency"]={"NS",{{0,0,0},{0.53924,0.94375,0},{1,1,0}}},["Width1"]=25,["Brightness"]=10,["TextureMode"]={"E","TextureMode","Static"},["TextureLength"]=240},nil,{["Attachment1"]={5,2},["Attachment0"]={5,1}}}}},{"Attachment","Attachment",{["CFrame"]={"CF",0,5.3562,0,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,5.3562,0}}},{"ParticleEmitter","Smoke",{["Color"]={"CS",{{0,0.54902,1,0.031373},{1,0.54902,1,0.031373}}},["Drag"]=6,["ZOffset"]=0.24348,["LightInfluence"]=0.25,["Lifetime"]={"NR",2,3},["Speed"]={"NR",0.0018312,0.0018312},["SpreadAngle"]={"V2",0,60},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.10896,0.9375,0},{0.18698,0.9,0},{0.23038,0.75,0},{0.26777,0.54375,0},{0.3338,0.44375,0},{0.39889,0.81875,0},{0.49908,0.9375,0},{0.60665,0.96875,0},{0.69945,0.94375,0},{0.79917,0.95625,0},{0.89982,0.98125,0},{1,1,0}}},["EmissionDirection"]={"E","NormalId","Front"},["LightEmission"]=1,["Texture"]="rbxassetid://9860410723",["Size"]={"NS",{{0,0.39254,0.39254},{0.16314,3.052,0.50941},{0.35866,4.7687,0.56427},{0.52802,5.3791,0.58881},{1,6.1039,0}}},["Squash"]={"NS",{{0,0,0.45},{0.49934,0.0375,0},{1,0,0}}}},{["EmitCount"]=10,["EmitDelay"]=0}}},1}},
        	["Infinite Portal"] = {{"Part","Part",{["Size"]={"V3",4,0.51,4},["CFrame"]={"CF",0,0,0,1,0,0,0,1,0,0,0,1}},nil,nil,{{"Attachment","Portal 1",{},nil,nil,{{"ParticleEmitter","ParticleEmitter",{["Texture"]="rbxassetid://12437861407",["Rate"]=1,["Color"]={"CS",{{0,1,0,0.015686},{0.30915,0.97993,0.11886,0.18934},{0.37824,0.89804,0.60392,0.89804},{0.48359,0.34902,0.27059,0.91373},{0.56131,0.48235,0.87843,0.93725},{0.62522,0.43137,0.95294,0.67451},{0.72021,0.68627,0.78824,0.35686},{0.75302,0.74902,0.60392,0.27059},{0.80829,0.95086,0.61338,0.54811},{1,1,0.61569,0.61569}}},["FlipbookFramerate"]={"NR",30,30},["LockedToPart"]=true,["ZOffset"]=0.068645,["Speed"]={"NR",0.0020594,0.0020594},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Transparency"]={"NS",{{0,1,0},{0.17119,0.79558,0},{0.26441,0.43094,0},{0.27839,0,0},{0.60508,0,0},{0.80847,0.58564,0},{0.85085,0.8453,0},{0.89153,0.96133,0},{1,1,0}}},["Lifetime"]={"NR",2,2},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Brightness"]=5,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid8x8"},["Size"]={"NS",{{0,8.9239,0},{1,8.9239,0}}}},{["EmitCount"]=2,["EmitDelay"]=0}},{"PointLight","PointLight",{["Color"]={"C3",0.48627,0.48627,1},["Brightness"]=8,["Range"]=18}},{"ParticleEmitter","Shockwaves",{["Texture"]="rbxassetid://9710639706",["Rate"]=4,["LightEmission"]=1,["Drag"]=5,["Color"]={"CS",{{0,1,0,0.015686},{0.30915,0.97993,0.11886,0.18934},{0.37824,0.89804,0.60392,0.89804},{0.48359,0.34902,0.27059,0.91373},{0.56131,0.48235,0.87843,0.93725},{0.62522,0.43137,0.95294,0.67451},{0.72021,0.68627,0.78824,0.35686},{0.75302,0.74902,0.60392,0.27059},{0.80829,0.95086,0.61338,0.54811},{1,1,0.61569,0.61569}}},["LockedToPart"]=true,["ZOffset"]=0.68645,["Speed"]={"NR",0.0020594,0.0020594},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Transparency"]={"NS",{{0,1,0},{0.50339,0.64481,0},{1,1,0}}},["Lifetime"]={"NR",1,1},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Brightness"]=10,["Size"]={"NS",{{0,10.983,0},{1,10.983,0}}}},{["EmitCount"]=3,["EmitDelay"]=0}},{"ParticleEmitter","Shockwaves",{["Texture"]="rbxassetid://9707769019",["Drag"]=5,["LightEmission"]=-5,["Color"]={"CS",{{0,1,0,0.015686},{0.30915,0.97993,0.11886,0.18934},{0.37824,0.89804,0.60392,0.89804},{0.48359,0.34902,0.27059,0.91373},{0.56131,0.48235,0.87843,0.93725},{0.62522,0.43137,0.95294,0.67451},{0.72021,0.68627,0.78824,0.35686},{0.75302,0.74902,0.60392,0.27059},{0.80829,0.95086,0.61338,0.54811},{1,1,0.61569,0.61569}}},["LockedToPart"]=true,["Rate"]=4,["Speed"]={"NR",0.0020594,0.0020594},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Transparency"]={"NS",{{0,1,0},{0.5,0,0},{1,1,0}}},["Lifetime"]={"NR",1,1},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Brightness"]=0,["Size"]={"NS",{{0,7.0705,0},{1,7.0705,0}}}},{["EmitCount"]=3,["EmitDelay"]=0}}}},{"Attachment","Portal 2",{["CFrame"]={"CF",0,11.874,0,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,11.874,0}},nil,nil,{{"ParticleEmitter","ParticleEmitter",{["Texture"]="rbxassetid://12437861407",["Rate"]=1,["Color"]={"CS",{{0,1,0,0.015686},{0.30915,0.97993,0.11886,0.18934},{0.37824,0.89804,0.60392,0.89804},{0.48359,0.34902,0.27059,0.91373},{0.56131,0.48235,0.87843,0.93725},{0.62522,0.43137,0.95294,0.67451},{0.72021,0.68627,0.78824,0.35686},{0.75302,0.74902,0.60392,0.27059},{0.80829,0.95086,0.61338,0.54811},{1,1,0.61569,0.61569}}},["FlipbookFramerate"]={"NR",30,30},["LockedToPart"]=true,["ZOffset"]=0.068645,["Speed"]={"NR",0.0020594,0.0020594},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Transparency"]={"NS",{{0,1,0},{0.17119,0.79558,0},{0.26441,0.43094,0},{0.27839,0,0},{0.60508,0,0},{0.80847,0.58564,0},{0.85085,0.8453,0},{0.89153,0.96133,0},{1,1,0}}},["Lifetime"]={"NR",2,2},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Brightness"]=5,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid8x8"},["Size"]={"NS",{{0,8.9239,0},{1,8.9239,0}}}},{["EmitCount"]=2,["EmitDelay"]=0}},{"PointLight","PointLight",{["Color"]={"C3",0.48627,0.48627,1},["Brightness"]=8,["Range"]=18}},{"ParticleEmitter","Shockwaves",{["Texture"]="rbxassetid://9710639706",["Rate"]=4,["LightEmission"]=1,["Drag"]=5,["Color"]={"CS",{{0,1,0,0.015686},{0.30915,0.97993,0.11886,0.18934},{0.37824,0.89804,0.60392,0.89804},{0.48359,0.34902,0.27059,0.91373},{0.56131,0.48235,0.87843,0.93725},{0.62522,0.43137,0.95294,0.67451},{0.72021,0.68627,0.78824,0.35686},{0.75302,0.74902,0.60392,0.27059},{0.80829,0.95086,0.61338,0.54811},{1,1,0.61569,0.61569}}},["LockedToPart"]=true,["ZOffset"]=0.68645,["Speed"]={"NR",0.0020594,0.0020594},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Transparency"]={"NS",{{0,1,0},{0.50339,0.64481,0},{1,1,0}}},["Lifetime"]={"NR",1,1},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Brightness"]=10,["Size"]={"NS",{{0,10.983,0},{1,10.983,0}}}},{["EmitCount"]=3,["EmitDelay"]=0}},{"ParticleEmitter","Shockwaves",{["Texture"]="rbxassetid://9707769019",["Drag"]=5,["LightEmission"]=-5,["Color"]={"CS",{{0,1,0,0.015686},{0.30915,0.97993,0.11886,0.18934},{0.37824,0.89804,0.60392,0.89804},{0.48359,0.34902,0.27059,0.91373},{0.56131,0.48235,0.87843,0.93725},{0.62522,0.43137,0.95294,0.67451},{0.72021,0.68627,0.78824,0.35686},{0.75302,0.74902,0.60392,0.27059},{0.80829,0.95086,0.61338,0.54811},{1,1,0.61569,0.61569}}},["LockedToPart"]=true,["Rate"]=4,["Speed"]={"NR",0.0020594,0.0020594},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Transparency"]={"NS",{{0,1,0},{0.5,0,0},{1,1,0}}},["Lifetime"]={"NR",1,1},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Brightness"]=0,["Size"]={"NS",{{0,7.0705,0},{1,7.0705,0}}}},{["EmitCount"]=3,["EmitDelay"]=0}}}},{"Attachment","Walls",{},nil,nil,{{"Attachment","Attachment",{["CFrame"]={"CF",-6.2629,7.02,-6.1035e-05,0,0,1,0,1,0,-1,0,0},["Axis"]={"V3",0,0,-1},["Rotation"]={"V3",0,90,0},["Orientation"]={"V3",0,90,0},["Position"]={"V3",-6.2629,7.02,-6.1035e-05}},nil,nil,{{"ParticleEmitter","ParticleEmitter",{["Color"]={"CS",{{0,1,0,0.015686},{0.30915,0.97993,0.11886,0.18934},{0.37824,0.89804,0.60392,0.89804},{0.48359,0.34902,0.27059,0.91373},{0.56131,0.48235,0.87843,0.93725},{0.62522,0.43137,0.95294,0.67451},{0.72021,0.68627,0.78824,0.35686},{0.75302,0.74902,0.60392,0.27059},{0.80829,0.95086,0.61338,0.54811},{1,1,0.61569,0.61569}}},["ZOffset"]=0.62425,["Lifetime"]={"NR",2,2},["Speed"]={"NR",0.00093638,0.00093638},["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid8x8"},["Size"]={"NS",{{0,5,0},{1,5,0}}},["LockedToPart"]=true,["Rate"]=1,["EmissionDirection"]={"E","NormalId","Back"},["Transparency"]={"NS",{{0,1,0},{0.13051,0.77596,0},{0.22034,0.46995,0},{0.27839,0,0},{0.80194,0,0},{0.82964,0.41875,0},{0.88966,0.81875,0},{0.94598,0.94375,0},{1,1,0}}},["Texture"]="rbxassetid://12413369473",["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["LightEmission"]=1,["FlipbookFramerate"]={"NR",30,30},["Squash"]={"NS",{{0,0.2,0},{1,0.2,0}}}},{["EmitCount"]=2,["EmitDelay"]=0}}}},{"Attachment","Attachment",{["CFrame"]={"CF",-4.4286,7.02,4.4285,-0.70713,0,0.70708,0,1,0,-0.70708,0,-0.70713},["Axis"]={"V3",-0.70713,0,-0.70708},["Rotation"]={"V3",-180,44.998,-180},["Orientation"]={"V3",0,135,0},["Position"]={"V3",-4.4286,7.02,4.4285}},nil,nil,{{"ParticleEmitter","ParticleEmitter",{["Color"]={"CS",{{0,1,0,0.015686},{0.30915,0.97993,0.11886,0.18934},{0.37824,0.89804,0.60392,0.89804},{0.48359,0.34902,0.27059,0.91373},{0.56131,0.48235,0.87843,0.93725},{0.62522,0.43137,0.95294,0.67451},{0.72021,0.68627,0.78824,0.35686},{0.75302,0.74902,0.60392,0.27059},{0.80829,0.95086,0.61338,0.54811},{1,1,0.61569,0.61569}}},["ZOffset"]=0.62425,["Lifetime"]={"NR",2,2},["Speed"]={"NR",0.00093638,0.00093638},["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid8x8"},["Size"]={"NS",{{0,5,0},{1,5,0}}},["LockedToPart"]=true,["Rate"]=1,["EmissionDirection"]={"E","NormalId","Back"},["Transparency"]={"NS",{{0,1,0},{0.13051,0.77596,0},{0.22034,0.46995,0},{0.27839,0,0},{0.80194,0,0},{0.82964,0.41875,0},{0.88966,0.81875,0},{0.94598,0.94375,0},{1,1,0}}},["Texture"]="rbxassetid://12413369473",["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["LightEmission"]=1,["FlipbookFramerate"]={"NR",30,30},["Squash"]={"NS",{{0,0.2,0},{1,0.2,0}}}},{["EmitCount"]=2,["EmitDelay"]=0}}}},{"Attachment","Attachment",{["CFrame"]={"CF",0,7.0204,6.2628,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,7.0204,6.2628}},nil,nil,{{"ParticleEmitter","ParticleEmitter",{["Color"]={"CS",{{0,1,0,0.015686},{0.30915,0.97993,0.11886,0.18934},{0.37824,0.89804,0.60392,0.89804},{0.48359,0.34902,0.27059,0.91373},{0.56131,0.48235,0.87843,0.93725},{0.62522,0.43137,0.95294,0.67451},{0.72021,0.68627,0.78824,0.35686},{0.75302,0.74902,0.60392,0.27059},{0.80829,0.95086,0.61338,0.54811},{1,1,0.61569,0.61569}}},["ZOffset"]=0.62425,["Lifetime"]={"NR",2,2},["Speed"]={"NR",0.00093638,0.00093638},["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid8x8"},["Size"]={"NS",{{0,5,0},{1,5,0}}},["LockedToPart"]=true,["Rate"]=1,["EmissionDirection"]={"E","NormalId","Back"},["Transparency"]={"NS",{{0,1,0},{0.13051,0.77596,0},{0.22034,0.46995,0},{0.27839,0,0},{0.80194,0,0},{0.82964,0.41875,0},{0.88966,0.81875,0},{0.94598,0.94375,0},{1,1,0}}},["Texture"]="rbxassetid://12413369473",["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["LightEmission"]=1,["FlipbookFramerate"]={"NR",30,30},["Squash"]={"NS",{{0,0.2,0},{1,0.2,0}}}},{["EmitCount"]=2,["EmitDelay"]=0}}}},{"Attachment","Attachment",{["CFrame"]={"CF",6.2629,7.0204,-6.1035e-05,0,0,1,0,1,0,-1,0,0},["Axis"]={"V3",0,0,-1},["Rotation"]={"V3",0,90,0},["Orientation"]={"V3",0,90,0},["Position"]={"V3",6.2629,7.0204,-6.1035e-05}},nil,nil,{{"ParticleEmitter","ParticleEmitter",{["Color"]={"CS",{{0,1,0,0.015686},{0.30915,0.97993,0.11886,0.18934},{0.37824,0.89804,0.60392,0.89804},{0.48359,0.34902,0.27059,0.91373},{0.56131,0.48235,0.87843,0.93725},{0.62522,0.43137,0.95294,0.67451},{0.72021,0.68627,0.78824,0.35686},{0.75302,0.74902,0.60392,0.27059},{0.80829,0.95086,0.61338,0.54811},{1,1,0.61569,0.61569}}},["ZOffset"]=0.62425,["Lifetime"]={"NR",2,2},["Speed"]={"NR",0.00093638,0.00093638},["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid8x8"},["Size"]={"NS",{{0,5,0},{1,5,0}}},["LockedToPart"]=true,["Rate"]=1,["EmissionDirection"]={"E","NormalId","Back"},["Transparency"]={"NS",{{0,1,0},{0.13051,0.77596,0},{0.22034,0.46995,0},{0.27839,0,0},{0.80194,0,0},{0.82964,0.41875,0},{0.88966,0.81875,0},{0.94598,0.94375,0},{1,1,0}}},["Texture"]="rbxassetid://12413369473",["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["LightEmission"]=1,["FlipbookFramerate"]={"NR",30,30},["Squash"]={"NS",{{0,0.2,0},{1,0.2,0}}}},{["EmitCount"]=2,["EmitDelay"]=0}}}},{"Attachment","Attachment",{["CFrame"]={"CF",4.4285,7.0204,4.4285,0.70713,0,0.70708,0,1,0,-0.70708,0,0.70713},["Axis"]={"V3",0.70713,0,-0.70708},["Rotation"]={"V3",0,44.998,0},["Orientation"]={"V3",0,44.998,0},["Position"]={"V3",4.4285,7.0204,4.4285}},nil,nil,{{"ParticleEmitter","ParticleEmitter",{["Color"]={"CS",{{0,1,0,0.015686},{0.30915,0.97993,0.11886,0.18934},{0.37824,0.89804,0.60392,0.89804},{0.48359,0.34902,0.27059,0.91373},{0.56131,0.48235,0.87843,0.93725},{0.62522,0.43137,0.95294,0.67451},{0.72021,0.68627,0.78824,0.35686},{0.75302,0.74902,0.60392,0.27059},{0.80829,0.95086,0.61338,0.54811},{1,1,0.61569,0.61569}}},["ZOffset"]=0.62425,["Lifetime"]={"NR",2,2},["Speed"]={"NR",0.00093638,0.00093638},["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid8x8"},["Size"]={"NS",{{0,5,0},{1,5,0}}},["LockedToPart"]=true,["Rate"]=1,["EmissionDirection"]={"E","NormalId","Back"},["Transparency"]={"NS",{{0,1,0},{0.13051,0.77596,0},{0.22034,0.46995,0},{0.27839,0,0},{0.80194,0,0},{0.82964,0.41875,0},{0.88966,0.81875,0},{0.94598,0.94375,0},{1,1,0}}},["Texture"]="rbxassetid://12413369473",["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["LightEmission"]=1,["FlipbookFramerate"]={"NR",30,30},["Squash"]={"NS",{{0,0.2,0},{1,0.2,0}}}},{["EmitCount"]=2,["EmitDelay"]=0}}}},{"Attachment","Attachment",{["CFrame"]={"CF",-4.4286,7.02,-4.4286,0.70713,0,0.70708,0,1,0,-0.70708,0,0.70713},["Axis"]={"V3",0.70713,0,-0.70708},["Rotation"]={"V3",0,44.998,0},["Orientation"]={"V3",0,44.998,0},["Position"]={"V3",-4.4286,7.02,-4.4286}},nil,nil,{{"ParticleEmitter","ParticleEmitter",{["Color"]={"CS",{{0,1,0,0.015686},{0.30915,0.97993,0.11886,0.18934},{0.37824,0.89804,0.60392,0.89804},{0.48359,0.34902,0.27059,0.91373},{0.56131,0.48235,0.87843,0.93725},{0.62522,0.43137,0.95294,0.67451},{0.72021,0.68627,0.78824,0.35686},{0.75302,0.74902,0.60392,0.27059},{0.80829,0.95086,0.61338,0.54811},{1,1,0.61569,0.61569}}},["ZOffset"]=0.62425,["Lifetime"]={"NR",2,2},["Speed"]={"NR",0.00093638,0.00093638},["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid8x8"},["Size"]={"NS",{{0,5,0},{1,5,0}}},["LockedToPart"]=true,["Rate"]=1,["EmissionDirection"]={"E","NormalId","Back"},["Transparency"]={"NS",{{0,1,0},{0.13051,0.77596,0},{0.22034,0.46995,0},{0.27839,0,0},{0.80194,0,0},{0.82964,0.41875,0},{0.88966,0.81875,0},{0.94598,0.94375,0},{1,1,0}}},["Texture"]="rbxassetid://12413369473",["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["LightEmission"]=1,["FlipbookFramerate"]={"NR",30,30},["Squash"]={"NS",{{0,0.2,0},{1,0.2,0}}}},{["EmitCount"]=2,["EmitDelay"]=0}}}},{"Attachment","Attachment",{["CFrame"]={"CF",4.4285,7.0204,-4.4286,-0.70713,0,0.70708,0,1,0,-0.70708,0,-0.70713},["Axis"]={"V3",-0.70713,0,-0.70708},["Rotation"]={"V3",-180,44.998,-180},["Orientation"]={"V3",0,135,0},["Position"]={"V3",4.4285,7.0204,-4.4286}},nil,nil,{{"ParticleEmitter","ParticleEmitter",{["Color"]={"CS",{{0,1,0,0.015686},{0.30915,0.97993,0.11886,0.18934},{0.37824,0.89804,0.60392,0.89804},{0.48359,0.34902,0.27059,0.91373},{0.56131,0.48235,0.87843,0.93725},{0.62522,0.43137,0.95294,0.67451},{0.72021,0.68627,0.78824,0.35686},{0.75302,0.74902,0.60392,0.27059},{0.80829,0.95086,0.61338,0.54811},{1,1,0.61569,0.61569}}},["ZOffset"]=0.62425,["Lifetime"]={"NR",2,2},["Speed"]={"NR",0.00093638,0.00093638},["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid8x8"},["Size"]={"NS",{{0,5,0},{1,5,0}}},["LockedToPart"]=true,["Rate"]=1,["EmissionDirection"]={"E","NormalId","Back"},["Transparency"]={"NS",{{0,1,0},{0.13051,0.77596,0},{0.22034,0.46995,0},{0.27839,0,0},{0.80194,0,0},{0.82964,0.41875,0},{0.88966,0.81875,0},{0.94598,0.94375,0},{1,1,0}}},["Texture"]="rbxassetid://12413369473",["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["LightEmission"]=1,["FlipbookFramerate"]={"NR",30,30},["Squash"]={"NS",{{0,0.2,0},{1,0.2,0}}}},{["EmitCount"]=2,["EmitDelay"]=0}}}},{"Attachment","Attachment",{["CFrame"]={"CF",0,7.02,-6.263,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,7.02,-6.263}},nil,nil,{{"ParticleEmitter","ParticleEmitter",{["Color"]={"CS",{{0,1,0,0.015686},{0.30915,0.97993,0.11886,0.18934},{0.37824,0.89804,0.60392,0.89804},{0.48359,0.34902,0.27059,0.91373},{0.56131,0.48235,0.87843,0.93725},{0.62522,0.43137,0.95294,0.67451},{0.72021,0.68627,0.78824,0.35686},{0.75302,0.74902,0.60392,0.27059},{0.80829,0.95086,0.61338,0.54811},{1,1,0.61569,0.61569}}},["ZOffset"]=0.62425,["Lifetime"]={"NR",2,2},["Speed"]={"NR",0.00093638,0.00093638},["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid8x8"},["Size"]={"NS",{{0,5,0},{1,5,0}}},["LockedToPart"]=true,["Rate"]=1,["EmissionDirection"]={"E","NormalId","Back"},["Transparency"]={"NS",{{0,1,0},{0.13051,0.77596,0},{0.22034,0.46995,0},{0.27839,0,0},{0.80194,0,0},{0.82964,0.41875,0},{0.88966,0.81875,0},{0.94598,0.94375,0},{1,1,0}}},["Texture"]="rbxassetid://12413369473",["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["LightEmission"]=1,["FlipbookFramerate"]={"NR",30,30},["Squash"]={"NS",{{0,0.2,0},{1,0.2,0}}}},{["EmitCount"]=2,["EmitDelay"]=0}}}}}}},1}},
        	["Heartbreak"] = {{"Part","Part",{["CFrame"]={"CF",0,0,0,1,0,0,0,1,0,0,0,1},["Size"]={"V3",4,2.8484,4}},nil,nil,{{"Attachment","Attachment",{["CFrame"]={"CF",0,3.9863,0,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,3.9863,0}},nil,nil,{{"ParticleEmitter","Undertale Heart Break",{["Enabled"]=false,["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["Color"]={"CS",{{0,1,0.7451,0.74902},{1,1,0.7451,0.74902}}},["Texture"]="rbxassetid://12399983623",["FlipbookFramerate"]={"NR",30,30},["LockedToPart"]=true,["ZOffset"]=4,["Rate"]=0.5,["EmissionDirection"]={"E","NormalId","Back"},["Transparency"]={"NS",{{0,0,0},{0.70129,0,0},{0.7687,0.10625,0},{0.79963,0.35,0},{0.8301,0.56875,0},{0.86242,0.75,0},{0.89428,0.89375,0},{0.92659,0.9625,0},{1,1,0}}},["Speed"]={"NR",0.003,0.003},["Lifetime"]={"NR",2,2},["LightEmission"]=1,["Squash"]={"NS",{{0,0,0},{1,0,0}}},["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid8x8"},["Size"]={"NS",{{0,5,0},{1,5,0}}}}},{"PointLight","PointLight",{["Color"]={"C3",1,0.61176,0.61961},["Brightness"]=16.84,["Range"]=12}},{"ParticleEmitter","Specs",{["Color"]={"CS",{{0,1,0.22353,0.22353},{1,1,0.22353,0.22353}}},["Drag"]=5,["ZOffset"]=3.0893,["VelocitySpread"]=-360,["Lifetime"]={"NR",0.2,4},["Speed"]={"NR",3.2104,27.525},["Brightness"]=10,["SpreadAngle"]={"V2",-360,360},["Enabled"]=false,["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["RotSpeed"]={"NR",-150,150},["Rate"]=10,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{0.54124,0,0},{1,0.9625,0}}},["Texture"]="rbxassetid://9589910306",["LightEmission"]=1,["Size"]={"NS",{{0,0,0},{0.50187,0.61787,0},{1,0,0}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["FlipbookStartRandom"]=true},{["EmitCount"]=10,["EmitDelay"]=0}},{"ParticleEmitter","Specs",{["Color"]={"CS",{{0,1,0.22353,0.22353},{1,1,0.22353,0.22353}}},["Drag"]=5,["ZOffset"]=3.0893,["VelocitySpread"]=-360,["Lifetime"]={"NR",0.2,4},["Speed"]={"NR",3.2104,27.525},["Brightness"]=10,["SpreadAngle"]={"V2",-360,360},["Enabled"]=false,["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["RotSpeed"]={"NR",-150,150},["Rate"]=10,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{0.54124,0,0},{1,0.9625,0}}},["Texture"]="rbxassetid://8860471252",["LightEmission"]=1,["Size"]={"NS",{{0,0,0},{0.50062,0.38617,0.2317},{1,0,0}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["FlipbookStartRandom"]=true},{["EmitCount"]=10,["EmitDelay"]=0}}}},{"Attachment","Attachment",{["CFrame"]={"CF",0,-1.2056,0,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,-1.2056,0}},nil,nil,{{"ParticleEmitter","Shockwaves",{["Color"]={"CS",{{0,1,0.4,0.4},{1,1,0.4,0.4}}},["Drag"]=5,["ZOffset"]=1.4325,["Lifetime"]={"NR",1,1},["Speed"]={"NR",0,1.0244},["Brightness"]=5,["Size"]={"NS",{{0,0,0},{1,6.625,0}}},["Enabled"]=false,["LockedToPart"]=true,["Rate"]=2,["Rotation"]={"NR",90,90},["Transparency"]={"NS",{{0,0,0},{0.16812,0.21875,0},{0.33873,0.50625,0},{0.47572,0.80625,0},{0.63885,0.9625,0},{0.8132,0.975,0},{1,1,0}}},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Texture"]="rbxassetid://12399853453",["LightEmission"]=1,["Squash"]={"NS",{{0,0,0},{1,0,0}}}},{["EmitCount"]=3,["EmitDelay"]=0}}}}},1}},
        	["Stereo"] = {{"Part","Part",{["Size"]={"V3",1,1,1},["CFrame"]={"CF",0,0,0,1,0,0,0,1,0,0,0,1}},nil,nil,{{"Attachment","Attachment",{["CFrame"]={"CF",-4,0,0,1,0,0,0,1,0,0,0,1},["Position"]={"V3",-4,0,0}},nil,nil,{{"ParticleEmitter","ParticleEmitter",{["Color"]={"CS",{{0,0.94118,0.48627,1},{1,0.94118,0.48627,1}}},["ZOffset"]=0.62425,["Lifetime"]={"NR",2.05,2.05},["Speed"]={"NR",0.00093638,0.00093638},["Brightness"]=2,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid8x8"},["Size"]={"NS",{{0,5,0},{1,5,0}}},["LockedToPart"]=true,["Rate"]=1,["Texture"]="rbxassetid://12885573705",["EmissionDirection"]={"E","NormalId","Right"},["Transparency"]={"NS",{{0,0,0},{1,0,0}}},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["LightEmission"]=1,["Squash"]={"NS",{{0,0.2,0},{1,0.2,0}}},["FlipbookFramerate"]={"NR",30,30},["FlipbookStartRandom"]=true},{["EmitCount"]=2,["EmitDelay"]=0}}}},{"Attachment","Attachment",{["CFrame"]={"CF",4,0,0,1,0,0,0,1,0,0,0,1},["Position"]={"V3",4,0,0}},nil,nil,{{"ParticleEmitter","ParticleEmitter",{["Color"]={"CS",{{0,0.94118,0.48627,1},{1,0.94118,0.48627,1}}},["ZOffset"]=0.62425,["Lifetime"]={"NR",2.05,2.05},["Speed"]={"NR",0.00093638,0.00093638},["Brightness"]=2,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid8x8"},["Size"]={"NS",{{0,5,0},{1,5,0}}},["LockedToPart"]=true,["Rate"]=1,["Texture"]="rbxassetid://12885573705",["EmissionDirection"]={"E","NormalId","Left"},["Transparency"]={"NS",{{0,0,0},{1,0,0}}},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["LightEmission"]=1,["Squash"]={"NS",{{0,0.2,0},{1,0.2,0}}},["FlipbookFramerate"]={"NR",30,30},["FlipbookStartRandom"]=true},{["EmitCount"]=2,["EmitDelay"]=0}}}},{"Attachment","Attachment",{["CFrame"]={"CF",0,0,4,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,0,4}},nil,nil,{{"ParticleEmitter","ParticleEmitter",{["Color"]={"CS",{{0,0.94118,0.48627,1},{1,0.94118,0.48627,1}}},["ZOffset"]=0.62425,["Lifetime"]={"NR",2.05,2.05},["Speed"]={"NR",0.00093638,0.00093638},["Brightness"]=2,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid8x8"},["Size"]={"NS",{{0,5,0},{1,5,0}}},["LockedToPart"]=true,["Rate"]=1,["Texture"]="rbxassetid://12885573705",["EmissionDirection"]={"E","NormalId","Front"},["Transparency"]={"NS",{{0,0,0},{1,0,0}}},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["LightEmission"]=1,["Squash"]={"NS",{{0,0.2,0},{1,0.2,0}}},["FlipbookFramerate"]={"NR",30,30},["FlipbookStartRandom"]=true},{["EmitCount"]=2,["EmitDelay"]=0}}}},{"Attachment","Attachment",{["CFrame"]={"CF",0,0,-4,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,0,-4}},nil,nil,{{"ParticleEmitter","ParticleEmitter",{["Color"]={"CS",{{0,0.94118,0.48627,1},{1,0.94118,0.48627,1}}},["ZOffset"]=0.62425,["Lifetime"]={"NR",2.05,2.05},["Speed"]={"NR",0.00093638,0.00093638},["Brightness"]=2,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid8x8"},["Size"]={"NS",{{0,5,0},{1,5,0}}},["LockedToPart"]=true,["Rate"]=1,["Texture"]="rbxassetid://12885573705",["EmissionDirection"]={"E","NormalId","Back"},["Transparency"]={"NS",{{0,0,0},{1,0,0}}},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["LightEmission"]=1,["Squash"]={"NS",{{0,0.2,0},{1,0.2,0}}},["FlipbookFramerate"]={"NR",30,30},["FlipbookStartRandom"]=true},{["EmitCount"]=2,["EmitDelay"]=0}}}},{"Attachment","Attachment",{["CFrame"]={"CF",0,-5.9099,0,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,-5.9099,0}},nil,nil,{{"ParticleEmitter","Glow 2",{["RotSpeed"]={"NR",99999,99999},["Texture"]="rbxassetid://9354796901",["Color"]={"CS",{{0,1,0.69804,0.090196},{0.2487,0.30196,0.023529,1},{0.53195,1,0.28627,0.29804},{0.81347,0.2,0.58824,1},{1,0.23529,1,0.10196}}},["LockedToPart"]=true,["Rate"]=1,["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.5,0.25,0.25},{1,1,0}}},["Lifetime"]={"NR",1,1},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Speed"]={"NR",0.00084566,0.00084566},["Size"]={"NS",{{0,9.0189,0},{1,24.051,6.0126}}}},{["EmitCount"]=3,["EmitDelay"]=0}},{"ParticleEmitter","Glow 2",{["RotSpeed"]={"NR",99999,99999},["Texture"]="rbxassetid://9354796901",["Color"]={"CS",{{0,1,0.69804,0.090196},{0.2487,0.30196,0.023529,1},{0.53195,1,0.28627,0.29804},{0.81347,0.2,0.58824,1},{1,0.23529,1,0.10196}}},["LockedToPart"]=true,["ZOffset"]=2.8189,["Rate"]=1,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.5,0.25,0.25},{1,1,0}}},["Lifetime"]={"NR",1,1},["Speed"]={"NR",0,0},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Size"]={"NS",{{0,9.0189,0},{1,24.051,6.0126}}}},{["EmitCount"]=3,["EmitDelay"]=0}},{"ParticleEmitter","Glow",{["Texture"]="rbxassetid://9589703753",["Rate"]=1,["Color"]={"CS",{{0,1,0.69804,0.090196},{0.2487,0.30196,0.023529,1},{0.53195,1,0.28627,0.29804},{0.81347,0.2,0.58824,1},{1,0.23529,1,0.10196}}},["LockedToPart"]=true,["ZOffset"]=2.8189,["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.5,0.25,0.25},{1,1,0}}},["Lifetime"]={"NR",1,1},["LightEmission"]=1,["Speed"]={"NR",0,0},["Size"]={"NS",{{0,9.0189,0},{1,24.051,6.0126}}}},{["EmitCount"]=2,["EmitDelay"]=0}},{"ParticleEmitter","Glow",{["Texture"]="rbxassetid://9589703753",["LightEmission"]=1,["Color"]={"CS",{{0,1,0.69804,0.090196},{0.2487,0.30196,0.023529,1},{0.53195,1,0.28627,0.29804},{0.81347,0.2,0.58824,1},{1,0.23529,1,0.10196}}},["LockedToPart"]=true,["Rate"]=1,["Speed"]={"NR",0.00084566,0.00084566},["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.5,0.25,0.25},{1,1,0}}},["Lifetime"]={"NR",1,1},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Size"]={"NS",{{0,9.0189,0},{1,24.051,6.0126}}}},{["EmitCount"]=2,["EmitDelay"]=0}},{"ParticleEmitter","6",{["Texture"]="rbxassetid://12831129814",["Rate"]=1,["Color"]={"CS",{{0,1,0.69804,0.090196},{0.2487,0.30196,0.023529,1},{0.53195,1,0.28627,0.29804},{0.81347,0.2,0.58824,1},{1,0.23529,1,0.10196}}},["FlipbookFramerate"]={"NR",30,60},["LockedToPart"]=true,["ZOffset"]=1,["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Rotation"]={"NR",90,90},["Transparency"]={"NS",{{0,0,0},{0.72712,0,0},{0.7339,0.18785,0},{0.7661,0.58564,0},{0.81017,0.8453,0},{0.87966,0.96133,0},{1,1,0}}},["Speed"]={"NR",0.001,0.001},["Lifetime"]={"NR",1,1},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Brightness"]=10,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid8x8"},["Size"]={"NS",{{0,7,0},{1,7,0}}}}},{"ParticleEmitter","5",{["Texture"]="rbxassetid://12831129814",["Rate"]=1,["Color"]={"CS",{{0,1,0.69804,0.090196},{0.2487,0.30196,0.023529,1},{0.53195,1,0.28627,0.29804},{0.81347,0.2,0.58824,1},{1,0.23529,1,0.10196}}},["FlipbookFramerate"]={"NR",30,60},["LockedToPart"]=true,["ZOffset"]=1,["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Rotation"]={"NR",90,90},["Transparency"]={"NS",{{0,0,0},{0.72712,0,0},{0.7339,0.18785,0},{0.7661,0.58564,0},{0.81017,0.8453,0},{0.87966,0.96133,0},{1,1,0}}},["Speed"]={"NR",0.001,0.001},["Lifetime"]={"NR",1,1},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Brightness"]=0,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid8x8"},["Size"]={"NS",{{0,6,0},{1,6,0}}}}}}}},1}},
        	["Lightning"] = {{"Part","Part",{["CFrame"]={"CF",0,0,0,1,0,0,0,1,0,0,0,1},["Size"]={"V3",9.6511,0.001,9.6511}},nil,nil,{{"Attachment","Attachment",{["CFrame"]={"CF",0,-1.1414,0,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,-1.1414,0}},nil,nil,{{"ParticleEmitter","Sparks2",{["ShapeStyle"]={"E","ParticleEmitterShapeStyle","Surface"},["Color"]={"CS",{{0,1,0.68627,0.1451},{1,1,0.68627,0.1451}}},["Drag"]=1,["Lifetime"]={"NR",0.6,0.6},["Speed"]={"NR",20.248,20.248},["Brightness"]=10,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["SpreadAngle"]={"V2",0,1000},["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["LockedToPart"]=true,["Rate"]=10,["EmissionDirection"]={"E","NormalId","Front"},["Transparency"]={"NS",{{0,1,0},{0.5,0,0},{1,1,0}}},["Texture"]="rbxassetid://9944328377",["Size"]={"NS",{{0,5.8407,0},{0.2,5.8407,1.9469},{0.4,5.8407,1.9469},{0.6,5.8407,1.9469},{0.8,5.8407,1.9469},{1,5.8407,1.9469}}},["LightEmission"]=1,["Squash"]={"NS",{{0,0,0},{1,-0.4875,0}}},["Orientation"]={"E","ParticleOrientation","VelocityParallel"}},{["EmitCount"]=15,["EmitDelay"]=0}},{"ParticleEmitter","Sparks",{["ShapeStyle"]={"E","ParticleEmitterShapeStyle","Surface"},["Color"]={"CS",{{0,0.28235,0.28235,1},{1,0.28235,0.28235,1}}},["Drag"]=1,["Lifetime"]={"NR",0.6,0.6},["Speed"]={"NR",20.248,20.248},["Brightness"]=10,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["SpreadAngle"]={"V2",0,1000},["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["LockedToPart"]=true,["Rate"]=10,["EmissionDirection"]={"E","NormalId","Front"},["Transparency"]={"NS",{{0,1,0},{0.5,0,0},{1,1,0}}},["Texture"]="rbxassetid://9944328377",["Size"]={"NS",{{0,5.8407,0},{0.2,5.8407,1.9469},{0.4,5.8407,1.9469},{0.6,5.8407,1.9469},{0.8,5.8407,1.9469},{1,5.8407,1.9469}}},["LightEmission"]=1,["Squash"]={"NS",{{0,0,0},{1,-0.4875,0}}},["Orientation"]={"E","ParticleOrientation","VelocityParallel"}},{["EmitCount"]=15,["EmitDelay"]=0}}}},{"ParticleEmitter","Lightning 2",{["Color"]={"CS",{{0,0.062745,0.078431,1},{1,0.062745,0.078431,1}}},["Drag"]=5,["ZOffset"]=1.9469,["VelocitySpread"]=360,["Lifetime"]={"NR",0.7,0.7},["Speed"]={"NR",0.0011681,0.0011681},["Brightness"]=100,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["SpreadAngle"]={"V2",360,360},["Enabled"]=false,["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["LockedToPart"]=true,["Rate"]=0.5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{1,0,0}}},["Texture"]="rbxassetid://9220391829",["Size"]={"NS",{{0,15.575,0},{1,15.575,0}}},["Orientation"]={"E","ParticleOrientation","VelocityParallel"},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["FlipbookFramerate"]={"NR",30,30},["LightEmission"]=1}},{"ParticleEmitter","Lightning",{["Color"]={"CS",{{0,1,0.68627,0.1451},{1,1,0.68627,0.1451}}},["Drag"]=5,["ZOffset"]=1.9469,["VelocitySpread"]=360,["Lifetime"]={"NR",0.5,1},["Speed"]={"NR",0.0011681,0.0011681},["Brightness"]=100,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["SpreadAngle"]={"V2",360,360},["Enabled"]=false,["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["LockedToPart"]=true,["Rate"]=9,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{1,0,0}}},["Texture"]="rbxassetid://9220391829",["Size"]={"NS",{{0,5.8407,0},{1,5.8407,0}}},["Orientation"]={"E","ParticleOrientation","VelocityParallel"},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["FlipbookFramerate"]={"NR",30,30},["LightEmission"]=1}},{"Attachment","Attachment2",{},nil,nil,{{"ParticleEmitter","Shockwaves",{["Enabled"]=false,["Texture"]="rbxassetid://9641756324",["Color"]={"CS",{{0,1,1,1},{1,1,1,1}}},["LockedToPart"]=true,["LightEmission"]=1,["Speed"]={"NR",0.0037522,0.0037522},["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.18307,0.425,0.125},{0.59382,0.9,0.04375},{0.81693,0.975,0},{1,1,0}}},["Lifetime"]={"NR",0.2,0.2},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Size"]={"NS",{{0,0,0},{0.2,12.338,0},{0.4,16.995,0},{0.6,20.156,0},{0.8,22.333,0},{1,23.363,0}}}},{["EmitCount"]=10,["EmitDelay"]=0}},{"ParticleEmitter","Impact 1",{["Color"]={"CS",{{0,0.41663,0.18599,1},{1,0.41663,0.18599,1}}},["ZOffset"]=0.77876,["Lifetime"]={"NR",0.5,0.5},["Speed"]={"NR",0.00011681,0.00011681},["Brightness"]=30,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["Size"]={"NS",{{0,13.628,0},{1,13.628,0}}},["Enabled"]=false,["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{1,0,0}}},["LightEmission"]=1,["Texture"]="rbxassetid://9944843121",["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Squash"]={"NS",{{0,0,0},{1,0,0}}}}},{"ParticleEmitter","Spike",{["Color"]={"CS",{{0,0.062745,0.078431,1},{1,0.062745,0.078431,1}}},["ZOffset"]=1.1681,["VelocitySpread"]=80,["Lifetime"]={"NR",0.1,0.2},["Speed"]={"NR",0.0011681,0.0011681},["Brightness"]=19,["SpreadAngle"]={"V2",80,80},["Enabled"]=false,["LockedToPart"]=true,["Rate"]=100,["Rotation"]={"NR",-90,-90},["Transparency"]={"NS",{{0,1,0},{0.4967,0,0},{1,1,0}}},["Texture"]="rbxassetid://9589937152",["LightEmission"]=1,["Size"]={"NS",{{0,0,0},{0.2,6.1692,0},{0.4,8.4977,0},{0.6,10.078,0},{0.8,11.166,0},{1,11.681,0}}},["Orientation"]={"E","ParticleOrientation","VelocityParallel"},["Squash"]={"NS",{{0,0,0},{1,0,0}}}},{["EmitCount"]=15,["EmitDelay"]=0}}}},{"Folder","Welds",{}},{"Part","Top",{["Color"]={"C3",0.066667,0.066667,0.066667},["Material"]={"E","Material","Glass"},["Size"]={"V3",12.235,0.21567,12.235},["CFrame"]={"CF",0,16,0,1,0,0,0,1,0,0,0,1}},nil,nil,{{"SpotLight","SpotLight",{["Color"]={"C3",0.29804,0.4549,1},["Brightness"]=25.2,["Range"]=60,["Face"]={"E","NormalId","Bottom"}}},{"Attachment","Attachment",{["CFrame"]={"CF",0,-3.3851,0,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,-3.3851,0}},nil,nil,{{"ParticleEmitter","Sparks",{["Color"]={"CS",{{0,0.28235,0.28235,1},{1,0.28235,0.28235,1}}},["Drag"]=5,["VelocitySpread"]=-40,["Lifetime"]={"NR",1,1},["Speed"]={"NR",0.38938,0.38938},["Brightness"]=10,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["SpreadAngle"]={"V2",-40,40},["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["LockedToPart"]=true,["Rate"]=11,["EmissionDirection"]={"E","NormalId","Bottom"},["Transparency"]={"NS",{{0,1,0},{0.5,0,0},{1,1,0}}},["Texture"]="rbxassetid://9944328377",["LightEmission"]=1,["Size"]={"NS",{{0,5.8407,0},{0.2,5.8407,1.9469},{0.4,5.8407,1.9469},{0.6,5.8407,1.9469},{0.8,5.8407,1.9469},{1,5.8407,1.9469}}},["Orientation"]={"E","ParticleOrientation","VelocityParallel"},["Squash"]={"NS",{{0,0,0},{1,0,0}}}}}}},{"ParticleEmitter","Clouds",{["Color"]={"CS",{{0,0.19216,0.19216,0.19216},{0.27833,0.10461,0.10121,0.11194},{0.53667,0.23974,0.23223,0.2567},{0.68,0.35134,0.34042,0.37625},{1,0.60047,0.58198,0.64314}}},["Drag"]=6,["ZOffset"]=5.8407,["VelocitySpread"]=-360,["Lifetime"]={"NR",3,3},["Speed"]={"NR",2,2},["Brightness"]=1.845,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid8x8"},["SpreadAngle"]={"V2",-360,360},["Acceleration"]={"V3",0,5,0},["RotSpeed"]={"NR",-10,10},["LockedToPart"]=true,["Rate"]=10,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{1,0,0}}},["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["Texture"]="rbxassetid://9171262291",["Size"]={"NS",{{0,2.2065,0},{0.2,6.5479,3.8938},{0.4,8.5631,3.8938},{0.6,10.046,3.8938},{0.8,11.137,3.8938},{1,11.681,3.8938}}},["Shape"]={"E","ParticleEmitterShape","Disc"},["Squash"]={"NS",{{0,0,0},{1,0,0}}}},{["EmitDelay"]=0}}},1},{"Part","Mid",{["CFrame"]={"CF",4.6e-05,7.0004,-3.8e-05,1,0,0,0,1,0,0,0,1},["Size"]={"V3",3.3019,13.897,3.3019}},nil,nil,{{"ParticleEmitter","Lightning",{["FlipbookFramerate"]={"NR",10,10},["Drag"]=8.5,["FlipbookStartRandom"]=true,["VelocitySpread"]=-10,["Lifetime"]={"NR",0.125,0.215},["Speed"]={"NR",0,0},["Brightness"]=150,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["SpreadAngle"]={"V2",-10,10},["Enabled"]=false,["FlipbookMode"]={"E","ParticleFlipbookMode","PingPong"},["RotSpeed"]={"NR",-20,20},["LockedToPart"]=true,["Rate"]=55,["EmissionDirection"]={"E","NormalId","Left"},["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.12195,0,0},{0.19164,1,0},{0.24564,0,0},{0.32404,0.9875,0},{0.39547,0,0},{0.84321,0,0},{1,1,0}}},["Texture"]="rbxassetid://9220391829",["Size"]={"NS",{{0,1.9469,0},{1,1.9469,0}}},["LightEmission"]=1,["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Color"]={"CS",{{0,0.062745,0.078431,1},{1,0.062745,0.078431,1}}}},{["EmitCount"]=2}},{"ParticleEmitter","Lightning1",{["FlipbookFramerate"]={"NR",10,10},["Drag"]=8.5,["VelocitySpread"]=-10,["Lifetime"]={"NR",0.125,0.215},["Speed"]={"NR",0,0},["Brightness"]=150,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["SpreadAngle"]={"V2",-10,10},["Enabled"]=false,["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["RotSpeed"]={"NR",-20,20},["LockedToPart"]=true,["Rate"]=55,["EmissionDirection"]={"E","NormalId","Left"},["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.12195,0,0},{0.19164,1,0},{0.24564,0,0},{0.32404,0.9875,0},{0.39547,0,0},{0.84321,0,0},{1,1,0}}},["Texture"]="rbxassetid://9220391829",["Size"]={"NS",{{0,1.9469,0},{1,1.9469,0}}},["LightEmission"]=1,["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Color"]={"CS",{{0,0.062745,0.078431,1},{1,0.062745,0.078431,1}}}},{["EmitCount"]=2}},{"ParticleEmitter","Lightning2",{["FlipbookFramerate"]={"NR",10,10},["Drag"]=8.5,["VelocitySpread"]=-10,["Lifetime"]={"NR",0.125,0.215},["Speed"]={"NR",0,0},["Brightness"]=150,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid2x2"},["SpreadAngle"]={"V2",-10,10},["Enabled"]=false,["RotSpeed"]={"NR",-20,20},["LockedToPart"]=true,["Rate"]=55,["EmissionDirection"]={"E","NormalId","Left"},["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.12195,0,0},{0.19164,1,0},{0.24564,0,0},{0.32404,0.9875,0},{0.39547,0,0},{0.84321,0,0},{1,1,0}}},["Texture"]="rbxassetid://9220391829",["Size"]={"NS",{{0,1.9469,0},{1,1.9469,0}}},["LightEmission"]=1,["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Color"]={"CS",{{0,1,0.68627,0.1451},{1,1,0.68627,0.1451}}}},{["EmitCount"]=2}},{"Attachment","A0",{["CFrame"]={"CF",0,6.949,0,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,6.949,0}}},{"Attachment","A1",{["CFrame"]={"CF",0,-6.949,0,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,-6.949,0}}}},1}},1}},
        	["Galactic Pull"] = {{"Part","Part",{["CFrame"]={"CF",0,0,0,1,0,0,0,1,0,0,0,1},["Size"]={"V3",13.775,0.22,13.208}},nil,nil,{{"Attachment","Middle",{},nil,nil,{{"ParticleEmitter","Bringer",{["Texture"]="rbxassetid://9589780927",["Rate"]=5,["Size"]={"NS",{{0,35.072,0},{1,0,0}}},["Color"]={"CS",{{0,0.11373,0.11373,0.11373},{1,0.11373,0.11373,0.11373}}},["LockedToPart"]=true,["ZOffset"]=6.1329,["Speed"]={"NR",0.010521,0.010521},["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.2,0.93571,0},{0.4,0.77657,0},{0.6,0.2208,0},{0.8,0.065844,0},{1,0,0}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Lifetime"]={"NR",0.5,0.5},["Orientation"]={"E","ParticleOrientation","VelocityParallel"},["VelocitySpread"]=-360,["LightEmission"]=-10,["SpreadAngle"]={"V2",-360,360}}},{"ParticleEmitter","Aura",{["Color"]={"CS",{{0,0.30196,0,0.56863},{1,0.30196,0,0.56863}}},["VelocitySpread"]=2,["Lifetime"]={"NR",1,1},["Speed"]={"NR",0.0045997,0.0045997},["SpreadAngle"]={"V2",2,2},["RotSpeed"]={"NR",300,300},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.49867,0,0},{1,1,0}}},["Texture"]="rbxassetid://9589738957",["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Size"]={"NS",{{0,13.032,0},{1,13.032,0}}},["LightEmission"]=-1},{["EmitDelay"]=0}},{"ParticleEmitter","Swirls",{["RotSpeed"]={"NR",360,800},["Texture"]="rbxassetid://10517720361",["Color"]={"CS",{{0,0.07451,0,0.18824},{1,0.07451,0,0.18824}}},["LockedToPart"]=true,["ZOffset"]=1.5332,["Rate"]=5,["LightEmission"]=-5,["Transparency"]={"NS",{{0,1,0},{0.5,0,0},{1,1,0}}},["Speed"]={"NR",0.0045997,0.0045997},["Lifetime"]={"NR",0.5,1},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Brightness"]=100,["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Size"]={"NS",{{0,13.128,2.204},{1,13.416,1.9165}}}}},{"ParticleEmitter","Sparkle",{["Color"]={"CS",{{0,0,0,0},{0.73833,0.47158,0.6125,1},{1,0,0,0}}},["Drag"]=5,["ZOffset"]=9.1993,["Lifetime"]={"NR",1,1},["Speed"]={"NR",0.0058377,0.0058377},["Brightness"]=100,["Size"]={"NS",{{0,19.459,0},{1,0,0}}},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.2,0.7344,0},{0.4,0.60594,0},{0.6,0.60585,0},{0.8,0.73221,0},{1,0.98889,0}}},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["EmissionDirection"]={"E","NormalId","Front"},["Texture"]="rbxassetid://9241180405",["Squash"]={"NS",{{0,0,0},{1,0,0}}}},{["EmitCount"]=5,["EmitDelay"]=0}},{"ParticleEmitter","Round",{["Color"]={"CS",{{0,0.25098,0,1},{1,0.25098,0,1}}},["ZOffset"]=7.9231,["Lifetime"]={"NR",1,1},["Speed"]={"NR",0.0033956,0.0033956},["Brightness"]=10,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["Size"]={"NS",{{0,0,0},{1,7.8036,0}}},["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["RotSpeed"]={"NR",-90,-90},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{0.49735,0,0},{0.76658,0.38509,0},{1,1,0}}},["LightEmission"]=10,["Texture"]="rbxassetid://9745304435",["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Squash"]={"NS",{{0,0,0},{1,0,0}}}}}}},{"Attachment","Chains",{["CFrame"]={"CF",-18.9,19.885,0,1,0,0,0,1,0,0,0,1},["Position"]={"V3",-18.9,19.885,0}},nil,nil,{{"Beam","Beam",{["FaceCamera"]=true,["Color"]={"CS",{{0,1,1,1},{1,1,1,1}}},["TextureSpeed"]=0,["Width0"]=2,["Texture"]="rbxassetid://10704767843",["Transparency"]={"NS",{{0,0,0},{1,0,0}}},["Width1"]=2,["Brightness"]=0,["TextureMode"]={"E","TextureMode","Static"},["TextureLength"]=3.625},nil,{["Attachment1"]={1,1},["Attachment0"]={1,2}}},{"ParticleEmitter","Cresents",{["Color"]={"CS",{{0,0.082353,0,1},{1,0.082353,0,1}}},["ZOffset"]=0.58996,["VelocitySpread"]=-360,["Lifetime"]={"NR",1,1},["Speed"]={"NR",0.0029498,0.0029498},["Brightness"]=0,["SpreadAngle"]={"V2",-360,360},["RotSpeed"]={"NR",720,720},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.49602,0,0},{1,1,0}}},["LightEmission"]=-10,["Texture"]="rbxassetid://10696685605",["Size"]={"NS",{{0,0,0},{0.19761,1.1994,0},{0.34151,2.8602,0},{1,2.2604,0}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}}},{["EmitCount"]=5,["EmitDelay"]=0}},{"ParticleEmitter","Main",{["RotSpeed"]={"NR",-45,45},["Texture"]="rbxassetid://9831282594",["Color"]={"CS",{{0,0.2902,0.14902,1},{1,0.2902,0.14902,1}}},["LockedToPart"]=true,["ZOffset"]=0.96126,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.53846,0.84472,0},{0.75066,0.90683,0},{1,1,0}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Lifetime"]={"NR",1,1},["LightEmission"]=-15,["Brightness"]=15,["Speed"]={"NR",0,0},["Size"]={"NS",{{0,1.9478,0},{1,4.0883,0.98683}}}}},{"ParticleEmitter","Round",{["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["RotSpeed"]={"NR",-90,-90},["Texture"]="rbxassetid://9745304435",["Color"]={"CS",{{0,0.41569,0,1},{1,0.41569,0,1}}},["LockedToPart"]=true,["ZOffset"]=1,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{0.49735,0,0},{0.76658,0.38509,0},{1,1,0}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Lifetime"]={"NR",1,1},["LightEmission"]=10,["Speed"]={"NR",0.003,0.003},["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["Size"]={"NS",{{0,0,0},{1,6.8944,0}}}}},{"ParticleEmitter","Sparkle",{["Color"]={"CS",{{0,0,0,0},{0.73833,0.47158,0.6125,1},{1,0,0,0}}},["Drag"]=5,["ZOffset"]=-0.33972,["VelocitySpread"]=360,["Lifetime"]={"NR",1,1},["Speed"]={"NR",0.001515,0.001515},["Brightness"]=100,["SpreadAngle"]={"V2",360,360},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.2,0.25,0},{0.4,0,0},{0.6,0,0},{0.8,0.25,0},{1,0.98889,0}}},["EmissionDirection"]={"E","NormalId","Front"},["Texture"]="rbxassetid://9241180405",["Size"]={"NS",{{0,5.05,0},{1,0,0}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}}},{["EmitCount"]=5,["EmitDelay"]=0}}}},{"Attachment","Chains",{["CFrame"]={"CF",-5.4357,17.026,14.657,1,0,0,0,1,0,0,0,1},["Position"]={"V3",-5.4357,17.026,14.657}},nil,nil,{{"Beam","Beam",{["FaceCamera"]=true,["Color"]={"CS",{{0,1,1,1},{1,1,1,1}}},["TextureSpeed"]=0,["Width0"]=2,["Texture"]="rbxassetid://10704767843",["Transparency"]={"NS",{{0,0.5,0},{1,0.5,0}}},["Width1"]=2,["Brightness"]=0,["TextureMode"]={"E","TextureMode","Static"},["TextureLength"]=3.625},nil,{["Attachment1"]={1,1},["Attachment0"]={1,3}}},{"ParticleEmitter","Cresents",{["Color"]={"CS",{{0,0.082353,0,1},{1,0.082353,0,1}}},["ZOffset"]=0.58996,["VelocitySpread"]=-360,["Lifetime"]={"NR",1,1},["Speed"]={"NR",0.0029498,0.0029498},["Brightness"]=0,["SpreadAngle"]={"V2",-360,360},["RotSpeed"]={"NR",720,720},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.49602,0,0},{1,1,0}}},["LightEmission"]=-10,["Texture"]="rbxassetid://10696685605",["Size"]={"NS",{{0,0,0},{0.19761,1.1994,0},{0.34151,2.8602,0},{1,2.2604,0}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}}},{["EmitCount"]=5,["EmitDelay"]=0}},{"ParticleEmitter","Main",{["RotSpeed"]={"NR",-45,45},["Texture"]="rbxassetid://9831282594",["Color"]={"CS",{{0,0.2902,0.14902,1},{1,0.2902,0.14902,1}}},["LockedToPart"]=true,["ZOffset"]=0.96126,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.53846,0.84472,0},{0.75066,0.90683,0},{1,1,0}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Lifetime"]={"NR",1,1},["LightEmission"]=-15,["Brightness"]=15,["Speed"]={"NR",0,0},["Size"]={"NS",{{0,1.9478,0},{1,4.0883,0.98683}}}}},{"ParticleEmitter","Round",{["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["RotSpeed"]={"NR",-90,-90},["Texture"]="rbxassetid://9745304435",["Color"]={"CS",{{0,0.41569,0,1},{1,0.41569,0,1}}},["LockedToPart"]=true,["ZOffset"]=1,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{0.49735,0,0},{0.76658,0.38509,0},{1,1,0}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Lifetime"]={"NR",1,1},["LightEmission"]=10,["Speed"]={"NR",0.003,0.003},["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["Size"]={"NS",{{0,0,0},{1,6.8944,0}}}}},{"ParticleEmitter","Sparkle",{["Color"]={"CS",{{0,0,0,0},{0.73833,0.47158,0.6125,1},{1,0,0,0}}},["Drag"]=5,["ZOffset"]=-0.33972,["VelocitySpread"]=360,["Lifetime"]={"NR",1,1},["Speed"]={"NR",0.001515,0.001515},["Brightness"]=100,["SpreadAngle"]={"V2",360,360},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.2,0.25,0},{0.4,0,0},{0.6,0,0},{0.8,0.25,0},{1,0.98889,0}}},["EmissionDirection"]={"E","NormalId","Front"},["Texture"]="rbxassetid://9241180405",["Size"]={"NS",{{0,5.05,0},{1,0,0}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}}},{["EmitCount"]=5,["EmitDelay"]=0}}}},{"Attachment","Chains",{["CFrame"]={"CF",12.622,21.568,9.5459,1,0,0,0,1,0,0,0,1},["Position"]={"V3",12.622,21.568,9.5459}},nil,nil,{{"Beam","Beam",{["FaceCamera"]=true,["Color"]={"CS",{{0,1,1,1},{1,1,1,1}}},["TextureSpeed"]=0,["Width0"]=2,["Texture"]="rbxassetid://10704767843",["Transparency"]={"NS",{{0,0,0},{1,0,0}}},["Width1"]=2,["Brightness"]=0,["TextureMode"]={"E","TextureMode","Static"},["TextureLength"]=3.625},nil,{["Attachment1"]={1,1},["Attachment0"]={1,4}}},{"ParticleEmitter","Cresents",{["Color"]={"CS",{{0,0.082353,0,1},{1,0.082353,0,1}}},["ZOffset"]=0.58996,["VelocitySpread"]=-360,["Lifetime"]={"NR",1,1},["Speed"]={"NR",0.0029498,0.0029498},["Brightness"]=0,["SpreadAngle"]={"V2",-360,360},["RotSpeed"]={"NR",720,720},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.49602,0,0},{1,1,0}}},["LightEmission"]=-10,["Texture"]="rbxassetid://10696685605",["Size"]={"NS",{{0,0,0},{0.19761,1.1994,0},{0.34151,2.8602,0},{1,2.2604,0}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}}},{["EmitCount"]=5,["EmitDelay"]=0}},{"ParticleEmitter","Main",{["RotSpeed"]={"NR",-45,45},["Texture"]="rbxassetid://9831282594",["Color"]={"CS",{{0,0.2902,0.14902,1},{1,0.2902,0.14902,1}}},["LockedToPart"]=true,["ZOffset"]=0.96126,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.53846,0.84472,0},{0.75066,0.90683,0},{1,1,0}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Lifetime"]={"NR",1,1},["LightEmission"]=-15,["Brightness"]=15,["Speed"]={"NR",0,0},["Size"]={"NS",{{0,1.9478,0},{1,4.0883,0.98683}}}}},{"ParticleEmitter","Sparkle",{["Color"]={"CS",{{0,0,0,0},{0.73833,0.47158,0.6125,1},{1,0,0,0}}},["Drag"]=5,["ZOffset"]=-0.33972,["VelocitySpread"]=360,["Lifetime"]={"NR",1,1},["Speed"]={"NR",0.001515,0.001515},["Brightness"]=100,["SpreadAngle"]={"V2",360,360},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.2,0.2,0},{0.4,0,0},{0.6,0,0},{0.8,0.25,0},{1,0.98889,0}}},["EmissionDirection"]={"E","NormalId","Front"},["Texture"]="rbxassetid://9241180405",["Size"]={"NS",{{0,5.05,0},{1,0,0}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}}},{["EmitCount"]=5,["EmitDelay"]=0}},{"ParticleEmitter","Round",{["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["RotSpeed"]={"NR",-90,-90},["Texture"]="rbxassetid://9745304435",["Color"]={"CS",{{0,0.41569,0,1},{1,0.41569,0,1}}},["LockedToPart"]=true,["ZOffset"]=1,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{0.49735,0,0},{0.76658,0.38509,0},{1,1,0}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Lifetime"]={"NR",1,1},["LightEmission"]=10,["Speed"]={"NR",0.003,0.003},["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["Size"]={"NS",{{0,0,0},{1,6.8944,0}}}}}}},{"Attachment","Chains",{["CFrame"]={"CF",18.13,11.446,-6.7444,1,0,0,0,1,0,0,0,1},["Position"]={"V3",18.13,11.446,-6.7444}},nil,nil,{{"Beam","Beam",{["FaceCamera"]=true,["Color"]={"CS",{{0,1,1,1},{1,1,1,1}}},["TextureSpeed"]=0,["Width0"]=2,["Texture"]="rbxassetid://10704767843",["Transparency"]={"NS",{{0,0,0},{1,0,0}}},["Width1"]=2,["Brightness"]=0,["TextureMode"]={"E","TextureMode","Static"},["TextureLength"]=3.625},nil,{["Attachment1"]={1,1},["Attachment0"]={1,5}}},{"ParticleEmitter","Cresents",{["Color"]={"CS",{{0,0.082353,0,1},{1,0.082353,0,1}}},["ZOffset"]=0.58996,["VelocitySpread"]=-360,["Lifetime"]={"NR",1,1},["Speed"]={"NR",0.0029498,0.0029498},["Brightness"]=0,["SpreadAngle"]={"V2",-360,360},["RotSpeed"]={"NR",720,720},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.49602,0,0},{1,1,0}}},["LightEmission"]=-10,["Texture"]="rbxassetid://10696685605",["Size"]={"NS",{{0,0,0},{0.19761,1.1994,0},{0.34151,2.8602,0},{1,2.2604,0}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}}},{["EmitCount"]=5,["EmitDelay"]=0}},{"ParticleEmitter","Main",{["RotSpeed"]={"NR",-45,45},["Texture"]="rbxassetid://9831282594",["Color"]={"CS",{{0,0.2902,0.14902,1},{1,0.2902,0.14902,1}}},["LockedToPart"]=true,["ZOffset"]=0.96126,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.53846,0.84472,0},{0.75066,0.90683,0},{1,1,0}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Lifetime"]={"NR",1,1},["LightEmission"]=-15,["Brightness"]=15,["Speed"]={"NR",0,0},["Size"]={"NS",{{0,1.9478,0},{1,4.0883,0.98683}}}}},{"ParticleEmitter","Sparkle",{["Color"]={"CS",{{0,0,0,0},{0.73833,0.47158,0.6125,1},{1,0,0,0}}},["Drag"]=5,["ZOffset"]=-0.33972,["VelocitySpread"]=360,["Lifetime"]={"NR",1,1},["Speed"]={"NR",0.001515,0.001515},["Brightness"]=100,["SpreadAngle"]={"V2",360,360},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.2,0.25,0},{0.4,0,0},{0.6,0,0},{0.8,0.25,0},{1,0.98889,0}}},["EmissionDirection"]={"E","NormalId","Front"},["Texture"]="rbxassetid://9241180405",["Size"]={"NS",{{0,5.05,0},{1,0,0}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}}},{["EmitCount"]=5,["EmitDelay"]=0}},{"ParticleEmitter","Round",{["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["RotSpeed"]={"NR",-90,-90},["Texture"]="rbxassetid://9745304435",["Color"]={"CS",{{0,0.41569,0,1},{1,0.41569,0,1}}},["LockedToPart"]=true,["ZOffset"]=1,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{0.49735,0,0},{0.76658,0.38509,0},{1,1,0}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Lifetime"]={"NR",1,1},["LightEmission"]=10,["Speed"]={"NR",0.003,0.003},["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["Size"]={"NS",{{0,0,0},{1,6.8944,0}}}}}}},{"Attachment","Chains",{["CFrame"]={"CF",-6.8536,12.205,-16.816,1,0,0,0,1,0,0,0,1},["Position"]={"V3",-6.8536,12.205,-16.816}},nil,nil,{{"Beam","Beam",{["FaceCamera"]=true,["Color"]={"CS",{{0,1,1,1},{1,1,1,1}}},["TextureSpeed"]=0,["Width0"]=2,["Texture"]="rbxassetid://10704767843",["Transparency"]={"NS",{{0,0,0},{1,0,0}}},["Width1"]=2,["Brightness"]=0,["TextureMode"]={"E","TextureMode","Static"},["TextureLength"]=3.625},nil,{["Attachment1"]={1,1},["Attachment0"]={1,6}}},{"ParticleEmitter","Cresents",{["Color"]={"CS",{{0,0.082353,0,1},{1,0.082353,0,1}}},["ZOffset"]=0.58996,["VelocitySpread"]=-360,["Lifetime"]={"NR",1,1},["Speed"]={"NR",0.0029498,0.0029498},["Brightness"]=0,["SpreadAngle"]={"V2",-360,360},["RotSpeed"]={"NR",720,720},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.49602,0,0},{1,1,0}}},["LightEmission"]=-10,["Texture"]="rbxassetid://10696685605",["Size"]={"NS",{{0,0,0},{0.19761,1.1994,0},{0.34151,2.8602,0},{1,2.2604,0}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}}},{["EmitCount"]=5,["EmitDelay"]=0}},{"ParticleEmitter","Main",{["RotSpeed"]={"NR",-45,45},["Texture"]="rbxassetid://9831282594",["Color"]={"CS",{{0,0.2902,0.14902,1},{1,0.2902,0.14902,1}}},["LockedToPart"]=true,["ZOffset"]=0.96126,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.53846,0.84472,0},{0.75066,0.90683,0},{1,1,0}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Lifetime"]={"NR",1,1},["LightEmission"]=-15,["Brightness"]=15,["Speed"]={"NR",0,0},["Size"]={"NS",{{0,1.9478,0},{1,4.0883,0.98683}}}}},{"ParticleEmitter","Sparkle",{["Color"]={"CS",{{0,0,0,0},{0.73833,0.47158,0.6125,1},{1,0,0,0}}},["Drag"]=5,["ZOffset"]=-0.33972,["VelocitySpread"]=360,["Lifetime"]={"NR",1,1},["Speed"]={"NR",0.001515,0.001515},["Brightness"]=100,["SpreadAngle"]={"V2",360,360},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.2,0.25,0},{0.4,0,0},{0.6,0,0},{0.8,0.25,0},{1,0.98889,0}}},["EmissionDirection"]={"E","NormalId","Front"},["Texture"]="rbxassetid://9241180405",["Size"]={"NS",{{0,5.05,0},{1,0,0}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}}},{["EmitCount"]=5,["EmitDelay"]=0}},{"ParticleEmitter","Round",{["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["RotSpeed"]={"NR",-90,-90},["Texture"]="rbxassetid://9745304435",["Color"]={"CS",{{0,0.41569,0,1},{1,0.41569,0,1}}},["LockedToPart"]=true,["ZOffset"]=1,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{0.49735,0,0},{0.76658,0.38509,0},{1,1,0}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Lifetime"]={"NR",1,1},["LightEmission"]=10,["Speed"]={"NR",0.003,0.003},["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["Size"]={"NS",{{0,0,0},{1,6.8944,0}}}}}}},{"Attachment","Chain Lock",{["CFrame"]={"CF",-4.3499,0,-4.428,1,0,0,0,1,0,0,0,1},["Position"]={"V3",-4.3499,0,-4.428}},nil,nil,{{"Beam","Beam",{["FaceCamera"]=true,["Color"]={"CS",{{0,1,1,1},{1,1,1,1}}},["TextureSpeed"]=1.5,["Width0"]=4,["Texture"]="rbxassetid://10704767843",["Transparency"]={"NS",{{0,0,0},{1,0,0}}},["Width1"]=4,["Brightness"]=0,["TextureMode"]={"E","TextureMode","Static"},["TextureLength"]=5},nil,{["Attachment1"]={1,7},["Attachment0"]={1,11}}}}},{"Attachment","Chain Lock",{["CFrame"]={"CF",-4.3499,0,4.6817,1,0,0,0,1,0,0,0,1},["Position"]={"V3",-4.3499,0,4.6817}},nil,nil,{{"Beam","Beam",{["FaceCamera"]=true,["Color"]={"CS",{{0,1,1,1},{1,1,1,1}}},["TextureSpeed"]=1.5,["Width0"]=4,["Texture"]="rbxassetid://10704767843",["Transparency"]={"NS",{{0,0,0},{1,0,0}}},["Width1"]=4,["Brightness"]=0,["TextureMode"]={"E","TextureMode","Static"},["TextureLength"]=5},nil,{["Attachment1"]={1,8},["Attachment0"]={1,13}}}}},{"Attachment","Chain Lock",{["CFrame"]={"CF",4.4636,0,4.6817,1,0,0,0,1,0,0,0,1},["Position"]={"V3",4.4636,0,4.6817}},nil,nil,{{"Beam","Beam",{["FaceCamera"]=true,["Color"]={"CS",{{0,1,1,1},{1,1,1,1}}},["TextureSpeed"]=1.5,["Width0"]=4,["Texture"]="rbxassetid://10704767843",["Transparency"]={"NS",{{0,0,0},{1,0,0}}},["Width1"]=4,["Brightness"]=0,["TextureMode"]={"E","TextureMode","Static"},["TextureLength"]=5},nil,{["Attachment1"]={1,9},["Attachment0"]={1,12}}}}},{"Attachment","Chain Lock",{["CFrame"]={"CF",4.4636,0,-4.5212,1,0,0,0,1,0,0,0,1},["Position"]={"V3",4.4636,0,-4.5212}},nil,nil,{{"Beam","Beam",{["FaceCamera"]=true,["Color"]={"CS",{{0,1,1,1},{1,1,1,1}}},["TextureSpeed"]=1.5,["Width0"]=4,["Texture"]="rbxassetid://10704767843",["Transparency"]={"NS",{{0,0,0},{1,0,0}}},["Width1"]=4,["Brightness"]=0,["TextureMode"]={"E","TextureMode","Static"},["TextureLength"]=5},nil,{["Attachment1"]={1,10},["Attachment0"]={1,14}}}}},{"Attachment","Chain Ends",{["CFrame"]={"CF",3.0518e-05,38.739,0.00033569,1,0,0,0,1,0,0,0,1},["Position"]={"V3",3.0518e-05,38.739,0.00033569}},nil,nil,{{"SpotLight","SpotLight",{["Color"]={"C3",0.28235,0,1},["Brightness"]=11.86,["Range"]=54,["Face"]={"E","NormalId","Bottom"}}},{"ParticleEmitter","Sparkle",{["Color"]={"CS",{{0,0,0,0},{0.73833,0.47158,0.6125,1},{1,0,0,0}}},["Drag"]=5,["ZOffset"]=-0.94546,["VelocitySpread"]=360,["Lifetime"]={"NR",1,1},["Speed"]={"NR",0.0042163,0.0042163},["Brightness"]=100,["SpreadAngle"]={"V2",360,360},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.2,0.25,0},{0.4,0,0},{0.6,0,0},{0.8,0.25,0},{1,0.98889,0}}},["EmissionDirection"]={"E","NormalId","Front"},["Texture"]="rbxassetid://9241180405",["Size"]={"NS",{{0,14.054,0},{1,0,0}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}}},{["EmitCount"]=5,["EmitDelay"]=0}},{"ParticleEmitter","Cresents",{["Color"]={"CS",{{0,0.082353,0,1},{1,0.082353,0,1}}},["ZOffset"]=1.6419,["VelocitySpread"]=-360,["Lifetime"]={"NR",1,1},["Speed"]={"NR",0.0082094,0.0082094},["Brightness"]=0,["SpreadAngle"]={"V2",-360,360},["RotSpeed"]={"NR",720,720},["LockedToPart"]=true,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.49602,0,0},{1,1,0}}},["LightEmission"]=-10,["Texture"]="rbxassetid://10696685605",["Size"]={"NS",{{0,0,0},{0.19761,3.338,0},{0.34151,7.9599,0},{1,6.2909,0}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}}},{["EmitCount"]=5,["EmitDelay"]=0}},{"ParticleEmitter","Main",{["RotSpeed"]={"NR",-45,45},["Texture"]="rbxassetid://9831282594",["Color"]={"CS",{{0,0.2902,0.14902,1},{1,0.2902,0.14902,1}}},["LockedToPart"]=true,["ZOffset"]=2.6752,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.53846,0.84472,0},{0.75066,0.90683,0},{1,1,0}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Lifetime"]={"NR",1,1},["LightEmission"]=-15,["Brightness"]=15,["Speed"]={"NR",0,0},["Size"]={"NS",{{0,5.4207,0},{1,11.378,2.7464}}}}},{"ParticleEmitter","Round",{["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["RotSpeed"]={"NR",-90,-90},["Texture"]="rbxassetid://9745304435",["Color"]={"CS",{{0,0.41569,0,1},{1,0.41569,0,1}}},["LockedToPart"]=true,["ZOffset"]=2.783,["Rate"]=5,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{0.49735,0,0},{0.76658,0.38509,0},{1,1,0}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Lifetime"]={"NR",1,1},["LightEmission"]=10,["Speed"]={"NR",0.0083491,0.0083491},["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["Size"]={"NS",{{0,0,0},{1,19.187,0}}}}}}},{"Attachment","Chain Ends",{["CFrame"]={"CF",3.0518e-05,38.739,0.00033569,1,0,0,0,1,0,0,0,1},["Position"]={"V3",3.0518e-05,38.739,0.00033569}}},{"Attachment","Chain Ends",{["CFrame"]={"CF",3.0518e-05,38.739,0.00033569,1,0,0,0,1,0,0,0,1},["Position"]={"V3",3.0518e-05,38.739,0.00033569}}},{"Attachment","Chain Ends",{["CFrame"]={"CF",3.0518e-05,38.739,0.00033569,1,0,0,0,1,0,0,0,1},["Position"]={"V3",3.0518e-05,38.739,0.00033569}}}},1}},
        	["Northern Aurora Burst"] = {{"Attachment","Ground",{["CFrame"]={"CF",0,0,-1527.9,1,0,0,0,0,-1,0,1,0},["Rotation"]={"V3",90,0,0},["SecondaryAxis"]={"V3",0,0,1},["Position"]={"V3",0,0,-1527.9},["Orientation"]={"V3",90,0,0}},nil,nil,{{"Attachment","Attachment",{["CFrame"]={"CF",0,0,-58.44,1,0,0,0,0,-1,0,1,0},["Rotation"]={"V3",90,0,0},["SecondaryAxis"]={"V3",0,0,1},["Position"]={"V3",0,0,-58.44},["Orientation"]={"V3",90,0,0}},nil,nil,{{"ParticleEmitter","20 and delay 0.2",{["Enabled"]=false,["Texture"]="rbxassetid://10439119562",["Squash"]={"NS",{{0,1,0},{1,1,0}}},["Drag"]=15,["Color"]={"CS",{{0,0.54902,1,0.76078},{1,0.84706,0.54118,1}}},["LockedToPart"]=true,["Rate"]=100,["Speed"]={"NR",51.566,1656.1},["Rotation"]={"NR",90,90},["Transparency"]={"NS",{{0,0.2,0},{1,0.2,0}}},["Lifetime"]={"NR",0.3,0.8},["Orientation"]={"E","ParticleOrientation","VelocityParallel"},["Brightness"]=5,["Size"]={"NS",{{0,17.189,0},{0.2056,58.659,0},{1,0,0}}}},{["EmitCount"]=20,["EmitDelay"]=0}}}},{"Attachment","Attachment",{["CFrame"]={"CF",0,0,-55.704,1,0,0,0,-1,0,0,0,-1},["Rotation"]={"V3",-180,0,0},["SecondaryAxis"]={"V3",0,-1,0},["Position"]={"V3",0,0,-55.704},["Orientation"]={"V3",0,180,180}},nil,nil,{{"ParticleEmitter","Wave_1",{["Color"]={"CS",{{0,1,1,1},{1,1,1,1}}},["Drag"]=8,["TimeScale"]=0.5,["VelocitySpread"]=15,["Lifetime"]={"NR",0.2,1},["Speed"]={"NR",7.4612,7.4612},["SpreadAngle"]={"V2",15,15},["Enabled"]=false,["RotSpeed"]={"NR",-100,100},["Rate"]=45,["Rotation"]={"NR",0,360},["Transparency"]={"NS",{{0,0.92896,0},{0.5,0.94992,0},{0.6,0.97232,0},{0.7,0.98636,0},{0.8,0.99463,0},{0.9,0.9988,0},{1,1,0}}},["EmissionDirection"]={"E","NormalId","Back"},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Texture"]="rbxassetid://14485136483",["Size"]={"NS",{{0,0,5.941},{0.1,8.3435,5.941},{0.2,11.305,5.941},{0.3,12.935,5.941},{0.4,13.962,5.941},{0.5,14.647,5.941},{0.6,15.115,5.941},{0.7,15.434,5.941},{0.8,15.645,5.941},{0.9,15.775,5.941},{1,15.843,5.941}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}}},{["EmitCount"]=7,["EmitDelay"]=0}},{"ParticleEmitter","Wind",{["FlipbookFramerate"]={"NR",36.826,36.826},["VelocitySpread"]=360,["Lifetime"]={"NR",0.1,0.3},["Speed"]={"NR",1.4568,1.4568},["Brightness"]=0.7,["SpreadAngle"]={"V2",360,360},["Enabled"]=false,["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["Color"]={"CS",{{0,1,1,1},{1,1,1,1}}},["LockedToPart"]=true,["Rate"]=11.04,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{0.1995,0.725,0},{0.41029,0.89375,0},{0.64994,0.95625,0},{1,1,0}}},["EmissionDirection"]={"E","NormalId","Left"},["Texture"]="rbxassetid://15644794428",["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Size"]={"NS",{{0,0,0},{0.1,21.018,0},{0.2,27.932,0},{0.3,32.491,0},{0.4,35.811,0},{0.5,38.323,0},{0.6,40.244,0},{0.7,41.698,0},{0.8,42.761,0},{0.9,43.469,0},{1,43.798,0}}},["Shape"]={"E","ParticleEmitterShape","Disc"},["Squash"]={"NS",{{0,0,0},{1,0,0}}}},{["EmitCount"]=3,["EmitDelay"]=0,["EmitDuration"]=0}},{"ParticleEmitter","Wind",{["FlipbookFramerate"]={"NR",22.303,22.303},["VelocitySpread"]=35,["Lifetime"]={"NR",0.25,0.25},["Speed"]={"NR",0.73126,0.73126},["Brightness"]=10,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["SpreadAngle"]={"V2",35,35},["Enabled"]=false,["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["LockedToPart"]=true,["Rate"]=6.6859,["Size"]={"NS",{{0,0,0},{0.1,7.1316,0},{0.2,9.4774,0},{0.3,11.024,0},{0.4,12.151,0},{0.5,13.003,0},{0.6,13.655,0},{0.7,14.148,0},{0.8,14.509,0},{0.9,14.749,0},{1,14.861,0}}},["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{1,0,0}}},["EmissionDirection"]={"E","NormalId","Left"},["Texture"]="rbxassetid://15359131648",["Color"]={"CS",{{0,0.54902,1,0.76078},{1,0.84706,0.54118,1}}},["Shape"]={"E","ParticleEmitterShape","Disc"},["Squash"]={"NS",{{0,0,0},{1,0,0}}}}},{"ParticleEmitter","Wind",{["FlipbookFramerate"]={"NR",47.873,47.873},["TimeScale"]=0.45,["VelocitySpread"]=360,["Lifetime"]={"NR",0.076923,0.23077},["Speed"]={"NR",1.3085,1.3085},["Brightness"]=0.5,["SpreadAngle"]={"V2",360,360},["Enabled"]=false,["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["Color"]={"CS",{{0,1,1,1},{1,1,1,1}}},["LockedToPart"]=true,["Rate"]=14.351,["EmissionDirection"]={"E","NormalId","Left"},["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{0.43538,0.8125,0},{0.64994,0.95625,0},{1,1,0}}},["Texture"]="rbxassetid://15056130357",["Size"]={"NS",{{0,0,0},{0.1,9.4606,0},{0.2,12.572,0},{0.3,14.625,0},{0.4,16.119,0},{0.5,17.25,0},{0.6,18.114,0},{0.7,18.769,0},{0.8,19.247,0},{0.9,19.566,0},{1,19.714,0}}},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Shape"]={"E","ParticleEmitterShape","Disc"},["LightEmission"]=1},{["EmitCount"]=5,["EmitDelay"]=0,["EmitDuration"]=0}},{"ParticleEmitter","Wind",{["Color"]={"CS",{{0,1,1,1},{1,1,1,1}}},["VelocitySpread"]=35,["Lifetime"]={"NR",0.2,0.2},["Speed"]={"NR",1.5158,1.5158},["Brightness"]=4,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["SpreadAngle"]={"V2",35,35},["Enabled"]=false,["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["LockedToPart"]=true,["Rate"]=6.6859,["EmissionDirection"]={"E","NormalId","Left"},["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{0.59097,0,0},{0.68381,0.5125,0},{0.83689,0.8625,0},{1,1,0}}},["Texture"]="rbxassetid://15636494216",["Size"]={"NS",{{0,0,0},{0.1,12.065,0},{0.2,16.034,0},{0.3,18.651,0},{0.4,20.556,0},{0.5,21.998,0},{0.6,23.101,0},{0.7,23.936,0},{0.8,24.546,0},{0.9,24.952,0},{1,25.141,0}}},["LightEmission"]=1,["Shape"]={"E","ParticleEmitterShape","Disc"},["FlipbookFramerate"]={"NR",22.303,22.303}},{["EmitCount"]=3,["EmitDelay"]=0,["EmitDuration"]=0}},{"ParticleEmitter","some",{["FlipbookFramerate"]={"NR",11.589,11.589},["ZOffset"]=2.4045,["VelocitySpread"]=350,["Lifetime"]={"NR",0.3,0.3},["Speed"]={"NR",0.0058132,0.0058132},["Brightness"]=10,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["SpreadAngle"]={"V2",350,350},["Enabled"]=false,["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["Color"]={"CS",{{0,0.54902,1,0.76078},{1,0.84706,0.54118,1}}},["LockedToPart"]=true,["Rate"]=9.6153,["EmissionDirection"]={"E","NormalId","Left"},["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{1,0,0}}},["Texture"]="rbxassetid://14355738489",["Size"]={"NS",{{0,0,0},{0.1,21.619,0},{0.2,28.73,0},{0.3,33.419,0},{0.4,36.834,0},{0.5,39.418,0},{0.6,41.394,0},{0.7,42.89,0},{0.8,43.983,0},{0.9,44.711,0},{1,45.049,0}}},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Shape"]={"E","ParticleEmitterShape","Disc"}},{["EmitCount"]=2,["EmitDelay"]=0,["EmitDuration"]=0}}}},{"Attachment","Attachment",{["Position"]={"V3",0,9.9476e-14,-2.3655},["CFrame"]={"CF",0,9.9476e-14,-2.3655,1,0,0,0,1,0,0,0,1}},nil,nil,{{"ParticleEmitter","Aura1",{["Color"]={"CS",{{0,0.60392,0.59216,1},{1,0.60392,0.59216,1}}},["Drag"]=10,["TimeScale"]=0.6,["Lifetime"]={"NR",1,1},["Speed"]={"NR",0,105.14},["Brightness"]=2,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid8x8"},["SpreadAngle"]={"V2",0,360},["Enabled"]=false,["Acceleration"]={"V3",0,13.142,0},["LockedToPart"]=true,["Transparency"]={"NS",{{0,0.72678,0},{0.39059,0.54645,0},{1,1,0}}},["Texture"]="rbxassetid://135417099182467",["Size"]={"NS",{{0,0,0},{0.1,1.7215,0},{0.2,3.0773,0},{0.3,4.1219,0},{0.4,4.9027,0},{0.5,5.4621,0},{0.6,5.839,0},{0.7,6.07,0},{0.8,6.1905,0},{0.9,6.2358,0},{1,6.2424,0}}},["LightEmission"]=1,["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["Squash"]={"NS",{{0,0,0},{1,0,0}}}},{["EmitCount"]=25}},{"ParticleEmitter","Aura1",{["Color"]={"CS",{{0,0.21569,1,0.88235},{1,0.21569,1,0.88235}}},["Drag"]=10,["TimeScale"]=0.6,["Lifetime"]={"NR",1,1},["Speed"]={"NR",0,105.14},["Brightness"]=2,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid8x8"},["SpreadAngle"]={"V2",0,360},["Enabled"]=false,["Acceleration"]={"V3",0,13.142,0},["LockedToPart"]=true,["Transparency"]={"NS",{{0,0.72678,0},{0.39059,0.54645,0},{1,1,0}}},["Texture"]="rbxassetid://135417099182467",["Size"]={"NS",{{0,0,0},{0.1,1.2949,0},{0.2,2.3147,0},{0.3,3.1004,0},{0.4,3.6876,0},{0.5,4.1084,0},{0.6,4.392,0},{0.7,4.5657,0},{0.8,4.6563,0},{0.9,4.6904,0},{1,4.6954,0}}},["LightEmission"]=1,["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["Squash"]={"NS",{{0,0,0},{1,0,0}}}},{["EmitCount"]=25}},{"ParticleEmitter","Aura1",{["Color"]={"CS",{{0,0.54118,1,0.72549},{1,0.54118,1,0.72549}}},["Drag"]=10,["TimeScale"]=0.6,["Lifetime"]={"NR",1,1},["Speed"]={"NR",0,105.14},["Brightness"]=2,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid8x8"},["SpreadAngle"]={"V2",0,360},["Enabled"]=false,["Acceleration"]={"V3",0,13.142,0},["LockedToPart"]=true,["Transparency"]={"NS",{{0,0.72678,0},{0.39059,0.54645,0},{1,1,0}}},["Texture"]="rbxassetid://135417099182467",["Size"]={"NS",{{0,0,0},{0.1,1.7215,0},{0.2,3.0773,0},{0.3,4.1219,0},{0.4,4.9027,0},{0.5,5.4621,0},{0.6,5.839,0},{0.7,6.07,0},{0.8,6.1905,0},{0.9,6.2358,0},{1,6.2424,0}}},["LightEmission"]=1,["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["Squash"]={"NS",{{0,0,0},{1,0,0}}}},{["EmitCount"]=25}}}},{"Attachment","Attachment",{["SecondaryAxis"]={"V3",0,0,-1},["Orientation"]={"V3",-90,0,0},["CFrame"]={"CF",0.00012207,-0.27148,0.0061756,1,0,0,0,0,1,0,-1,0},["Rotation"]={"V3",-90,0,0},["Position"]={"V3",0.00012207,-0.27148,0.0061756}},nil,nil,{{"ParticleEmitter","ParticleEmitter",{["Color"]={"CS",{{0,1,1,1},{1,1,1,1}}},["Drag"]=4,["ZOffset"]=0.234,["Lifetime"]={"NR",0.7,2.65},["Speed"]={"NR",22.15,104.11},["Brightness"]=0.5,["SpreadAngle"]={"V2",0,999},["Enabled"]=false,["RotSpeed"]={"NR",-25,25},["Rotation"]={"NR",-180,180},["Transparency"]={"NS",{{0,0,0},{0.05305,0.4625,0},{0.13263,0.70625,0},{1,1,0}}},["EmissionDirection"]={"E","NormalId","Front"},["Texture"]="rbxassetid://81532713516532",["LightEmission"]=0.4,["Size"]={"NS",{{0,2.8796,0},{1,9.5524,2.4919}}},["Squash"]={"NS",{{0,0,0},{1,0,0.45902}}},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"}}},{"ParticleEmitter","ParticleEmitter",{["Enabled"]=false,["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["Color"]={"CS",{{0,0.54902,1,0.76078},{1,0.84706,0.54118,1}}},["Rate"]=0.6,["Texture"]="rbxassetid://127237585162320",["Rotation"]={"NR",-180,180},["Transparency"]={"NS",{{0,0,0},{0.051061,0.64375,0},{0.15782,0.8625,0},{1,1,0}}},["Lifetime"]={"NR",1,1},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Brightness"]=5,["Speed"]={"NR",0.02215,0.02215},["Size"]={"NS",{{0,17.72,0},{0.1,25.616,0},{0.2,26.886,0},{0.3,27.585,0},{0.4,28.028,0},{0.5,28.324,0},{0.6,28.524,0},{0.7,28.656,0},{0.8,28.739,0},{0.9,28.782,0},{1,28.796,0},{1,28.796,0}}}}},{"ParticleEmitter","ParticleEmitter",{["Enabled"]=false,["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["Color"]={"CS",{{0,0.54902,1,0.76078},{1,0.84706,0.54118,1}}},["Texture"]="rbxassetid://107865471522142",["LightEmission"]=-1,["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Rotation"]={"NR",-180,180},["Transparency"]={"NS",{{0,0,0},{0.18833,0.21875,0},{0.33687,0.9,0},{1,1,0}}},["Speed"]={"NR",0.028796,0.028796},["Lifetime"]={"NR",0.1,0.1},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Brightness"]=5,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["Size"]={"NS",{{0,0,0},{0.02321,7.9188,0},{0.24735,16.198,0},{1,21.777,0}}}}},{"ParticleEmitter","ParticleEmitter",{["Enabled"]=false,["Acceleration"]={"V3",0,22.15,0},["Texture"]="rbxassetid://7216979305",["Color"]={"CS",{{0,0.54902,1,0.76078},{1,0.84706,0.54118,1}}},["Drag"]=5,["Size"]={"NS",{{0,6.5067,1.9382},{1,0,0}}},["Squash"]={"NS",{{0,0,0},{0.22745,-0.96721,0.68852},{1,0,0}}},["VelocitySpread"]=120,["Transparency"]={"NS",{{0,1,0},{0.11538,1,0},{0.32029,0.58125,0},{0.42706,0.78125,0},{1,1,0}}},["Speed"]={"NR",44.301,148.41},["Lifetime"]={"NR",0.6,1},["LightEmission"]=0.1,["Brightness"]=4,["Orientation"]={"E","ParticleOrientation","VelocityParallel"},["SpreadAngle"]={"V2",120,120}}},{"ParticleEmitter","ParticleEmitter",{["Enabled"]=false,["Acceleration"]={"V3",0,-88.602,0},["RotSpeed"]={"NR",-66,66},["Texture"]="rbxassetid://84732570090544",["Color"]={"CS",{{0,0.54902,1,0.76078},{1,0.84706,0.54118,1}}},["Drag"]=2,["Size"]={"NS",{{0,0.28796,0.2215},{1,0,0}}},["TimeScale"]=0.75,["Rotation"]={"NR",-180,180},["Transparency"]={"NS",{{0,0,0},{1,0,0}}},["Squash"]={"NS",{{0,0,0},{1,0,0.81967}}},["Lifetime"]={"NR",0.2,1.4},["Speed"]={"NR",26.581,132.9},["Brightness"]=0.2,["VelocitySpread"]=55,["SpreadAngle"]={"V2",55,55}}},{"ParticleEmitter","ParticleEmitter",{["Enabled"]=false,["Color"]={"CS",{{0,0.54902,1,0.76078},{1,0.84706,0.54118,1}}},["ZOffset"]=2,["Texture"]="rbxassetid://87264390538192",["Rotation"]={"NR",-180,180},["Transparency"]={"NS",{{0,0,0},{0.39589,0.79375,0},{1,1,0}}},["Lifetime"]={"NR",0.1,0.1},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["LightEmission"]=0.1,["Brightness"]=4,["Speed"]={"NR",0.02215,0.02215},["Size"]={"NS",{{0,0,0},{0.1,13.953,0},{0.2,17.734,0},{0.3,20.22,0},{0.4,22.206,0},{0.5,23.932,0},{0.6,25.501,0},{0.7,26.967,0},{0.8,28.362,0},{0.9,29.706,0},{1,31.011,0},{1,31.011,0}}}}},{"Attachment","Attachment",{["CFrame"]={"CF",0,0.34312,0,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,0.34312,0}},nil,nil,{{"ParticleEmitter","ParticleEmitter",{["Enabled"]=false,["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["Color"]={"CS",{{0,0.54902,1,0.76078},{1,0.84706,0.54118,1}}},["Texture"]="rbxassetid://71014309724661",["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Rotation"]={"NR",-180,180},["Transparency"]={"NS",{{0,0,0},{0.28581,0.7375,0},{1,1,0}}},["Speed"]={"NR",0.035674,0.035674},["Lifetime"]={"NR",0.3,0.75},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Brightness"]=9,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["Size"]={"NS",{{0,0,7.1347},{0.1,12.151,7.1347},{0.2,17.344,7.1347},{0.3,19.911,7.1347},{0.4,21.564,7.1347},{0.5,22.861,7.1347},{0.6,24.017,7.1347},{0.7,25.127,7.1347},{0.8,26.237,7.1347},{0.9,27.37,7.1347},{1,28.539,7.1347},{1,28.539,7.1347}}}}}}},{"ParticleEmitter","ParticleEmitter",{["Enabled"]=false,["Acceleration"]={"V3",0,-88.602,0},["RotSpeed"]={"NR",-66,66},["Color"]={"CS",{{0,0.54902,1,0.76078},{1,0.84706,0.54118,1}}},["Drag"]=2,["Texture"]="rbxassetid://84732570090544",["Size"]={"NS",{{0,0.28796,0.2215},{1,0,0}}},["VelocitySpread"]=77,["Transparency"]={"NS",{{0,0,0},{1,0,0}}},["Squash"]={"NS",{{0,0,0},{1,0,0.81967}}},["Lifetime"]={"NR",0.2,1.4},["Speed"]={"NR",26.581,88.602},["Brightness"]=0.2,["Rotation"]={"NR",-180,180},["SpreadAngle"]={"V2",77,77}}},{"ParticleEmitter","ParticleEmitter",{["Enabled"]=false,["Color"]={"CS",{{0,0.54902,1,0.76078},{1,0.84706,0.54118,1}}},["Rotation"]={"NR",-180,180},["Transparency"]={"NS",{{0,0,0},{0.11406,0.7375,0},{1,1,0}}},["Texture"]="rbxassetid://90169191095142",["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Speed"]={"NR",0.02215,0.02215},["Lifetime"]={"NR",1.7,1.7},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Size"]={"NS",{{0,4.4301,0},{0.1,25.565,0},{0.2,31,0},{0.3,34.335,0},{0.4,36.714,0},{0.5,38.552,0},{0.6,40.048,0},{0.7,41.313,0},{0.8,42.416,0},{0.9,43.402,0},{1,44.301,0},{1,44.301,0}}}}}}},{"Attachment","Attachment",{["SecondaryAxis"]={"V3",0,0,-1},["Orientation"]={"V3",-90,0,0},["CFrame"]={"CF",0,-0.27161,-0.53692,1,0,0,0,0,1,0,-1,0},["Rotation"]={"V3",-90,0,0},["Position"]={"V3",0,-0.27161,-0.53692}},nil,nil,{{"ParticleEmitter","Color",{["Enabled"]=false,["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["Texture"]="rbxassetid://13634052022",["ShapeStyle"]={"E","ParticleEmitterShapeStyle","Surface"},["Color"]={"CS",{{0,0.54902,1,0.76078},{1,0.84706,0.54118,1}}},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Rate"]=12,["Speed"]={"NR",0.0152,0.0152},["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0.91803,0},{0.44873,0.5082,0},{1,1,0}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Lifetime"]={"NR",0.3,0.7},["LightEmission"]=1,["Brightness"]=3,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["Size"]={"NS",{{0,4.4242,0},{1,37.256,0}}}}},{"ParticleEmitter","Color",{["Color"]={"CS",{{0,0.54902,1,0.76078},{1,0.84706,0.54118,1}}},["Drag"]=15,["ZOffset"]=6,["Squash"]={"NS",{{0,0,0.25},{1,0,0.25}}},["Speed"]={"NR",224.83,224.83},["Brightness"]=3,["Size"]={"NS",{{0,0,0},{0.18,3.5362,1.7681},{1,0,0}}},["Enabled"]=false,["FlipbookMode"]={"E","ParticleFlipbookMode","Random"},["Rate"]=25,["Rotation"]={"NR",0,360},["Transparency"]={"NS",{{0,1,0},{0.15,0,0},{0.7,0,0},{1,1,0}}},["EmissionDirection"]={"E","NormalId","Bottom"},["LightEmission"]=1,["Texture"]="rbxassetid://8511527728",["FlipbookFramerate"]={"NR",0,0},["Lifetime"]={"NR",0.35,0.85}}}}},{"Attachment","Attachment",{["SecondaryAxis"]={"V3",0,0,-1},["Orientation"]={"V3",-90,0,0},["CFrame"]={"CF",0,-0.27161,-0.53692,1,0,0,0,0,1,0,-1,0},["Rotation"]={"V3",-90,0,0},["Position"]={"V3",0,-0.27161,-0.53692}},nil,nil,{{"ParticleEmitter","ParticleEmitter",{["Enabled"]=false,["EmissionDirection"]={"E","NormalId","Front"},["RotSpeed"]={"NR",-44,44},["Texture"]="rbxassetid://81532713516532",["Color"]={"CS",{{0,1,1,1},{1,1,1,1}}},["Drag"]=5,["ZOffset"]=0.254,["Size"]={"NS",{{0,2.2335,0},{1,8.4755,3.091}}},["Rotation"]={"NR",-180,180},["Transparency"]={"NS",{{0,0,0},{0.025862,0.7125,0},{1,1,0}}},["Speed"]={"NR",19.145,86.151},["Lifetime"]={"NR",1,2.5},["LightEmission"]=0.4,["Brightness"]=0.5,["Squash"]={"NS",{{0,0,0},{1,0,0.16393}}},["SpreadAngle"]={"V2",0,999}}},{"ParticleEmitter","ParticleEmitter",{["Color"]={"CS",{{0,1,1,1},{1,1,1,1}}},["Drag"]=5,["ZOffset"]=0.254,["Lifetime"]={"NR",1,2.5},["Speed"]={"NR",19.145,86.151},["Brightness"]=0.5,["SpreadAngle"]={"V2",0,999},["Enabled"]=false,["RotSpeed"]={"NR",-44,44},["Rate"]=7,["Rotation"]={"NR",-180,180},["Transparency"]={"NS",{{0,0,0},{0.025862,0.7125,0},{1,1,0}}},["EmissionDirection"]={"E","NormalId","Front"},["Texture"]="rbxassetid://81532713516532",["LightEmission"]=0.4,["Size"]={"NS",{{0,2.2335,0},{1,8.4755,3.091}}},["Squash"]={"NS",{{0,0,0},{1,0,0.16393}}},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"}}},{"ParticleEmitter","ParticleEmitter",{["Enabled"]=false,["Color"]={"CS",{{0,1,1,1},{1,1,1,1}}},["Rate"]=10,["Rotation"]={"NR",-180,180},["Transparency"]={"NS",{{0,0,0},{0.039125,0.8,0},{1,1,0}}},["Texture"]="rbxassetid://90169191095142",["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Speed"]={"NR",0.015954,0.015954},["Lifetime"]={"NR",0.8,2.4},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Size"]={"NS",{{0,0,6.3815},{0.1,18.221,6.3815},{0.2,23.051,6.3815},{0.3,26.363,6.3815},{0.4,28.996,6.3815},{0.5,31.242,6.3815},{0.6,33.239,6.3815},{0.7,35.062,6.3815},{0.8,36.758,6.3815},{0.9,38.359,6.3815},{1,39.885,6.3815},{1,39.885,6.3815}}}}},{"ParticleEmitter","ParticleEmitter",{["Enabled"]=false,["RotSpeed"]={"NR",-30,30},["Color"]={"CS",{{0,1,1,1},{1,1,1,1}}},["Rate"]=7,["Texture"]="rbxassetid://91039999689040",["Rotation"]={"NR",-180,180},["Transparency"]={"NS",{{0,0,0},{0.03382,0.66875,0},{0.12268,0.93125,0},{0.351,0.96,0},{1,1,0}}},["Lifetime"]={"NR",0.78,1.5},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Brightness"]=0,["Speed"]={"NR",0.0093264,0.0093264},["Size"]={"NS",{{0,0,3.7305},{0.1,13.09,3.7305},{0.2,16.417,3.7305},{0.3,18.678,3.7305},{0.4,20.472,3.7305},{0.5,22.005,3.7305},{0.6,23.372,3.7305},{0.7,24.626,3.7305},{0.8,25.799,3.7305},{0.9,26.912,3.7305},{1,27.979,3.7305},{1,27.979,3.7305}}}}},{"ParticleEmitter","ParticleEmitter",{["Enabled"]=false,["Texture"]="rbxassetid://133287798956826",["Color"]={"CS",{{0,1,1,1},{1,1,1,1}}},["Size"]={"NS",{{0,0,7.9769},{0.1,15.279,7.9769},{0.2,19.004,7.9769},{0.3,21.512,7.9769},{0.4,23.497,7.9769},{0.5,25.195,7.9769},{0.6,26.715,7.9769},{0.7,28.117,7.9769},{0.8,29.436,7.9769},{0.9,30.694,7.9769},{1,31.908,7.9769},{1,31.908,7.9769}}},["Rate"]=11,["Rotation"]={"NR",-180,180},["VelocitySpread"]=26,["Transparency"]={"NS",{{0,1,0},{0.21552,0.8875,0},{1,1,0}}},["Speed"]={"NR",0.015954,0.015954},["Lifetime"]={"NR",0.8,2.1},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Brightness"]=0,["Squash"]={"NS",{{0,0,0},{1,0,0.26229}}},["SpreadAngle"]={"V2",26,26}}}}},{"Attachment","Center",{["SecondaryAxis"]={"V3",0,0,-1},["Orientation"]={"V3",-90,0,0},["CFrame"]={"CF",-6.1035e-05,0.00012207,-0.26537,1,0,0,0,0,1,0,-1,0},["Rotation"]={"V3",-90,0,0},["Position"]={"V3",-6.1035e-05,0.00012207,-0.26537}},nil,nil,{{"ParticleEmitter","Downslam",{["Color"]={"CS",{{0,1,1,1},{1,1,1,1}}},["Drag"]=10,["ZOffset"]=0.22995,["VelocitySpread"]=360,["Lifetime"]={"NR",0.4,0.7},["Speed"]={"NR",105.98,127.18},["Brightness"]=3.93,["SpreadAngle"]={"V2",360,360},["Enabled"]=false,["Rate"]=15,["Rotation"]={"NR",90,90},["Transparency"]={"NS",{{0,1,0},{0.60053,0.91257,0},{1,1,0}}},["Texture"]="http://www.roblox.com/asset/?id=9799262426",["Size"]={"NS",{{0,2.4723,0},{0.078474,0,0},{0.1992,1.8755,0},{0.29746,1.4493,0},{0.39906,0.93776,0},{1,0,0}}},["LightEmission"]=1,["LightInfluence"]=1,["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Orientation"]={"E","ParticleOrientation","VelocityParallel"}}},{"ParticleEmitter","Downslam",{["Color"]={"CS",{{0,1,1,1},{1,1,1,1}}},["Drag"]=10,["ZOffset"]=0.5625,["LightInfluence"]=1,["Lifetime"]={"NR",0.4,0.7},["Speed"]={"NR",64.479,107.47},["Brightness"]=3.93,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["SpreadAngle"]={"V2",0,360},["Enabled"]=false,["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["Rate"]=30,["EmissionDirection"]={"E","NormalId","Back"},["Rotation"]={"NR",0,360},["Transparency"]={"NS",{{0,1,0},{0.57672,0.85792,0},{1,1,0}}},["Texture"]="rbxassetid://11871320339",["Size"]={"NS",{{0,0,0},{0.29412,3.4899,0.97391},{1,4.2203,1.2986}}},["LightEmission"]=1,["Squash"]={"NS",{{0,0,0},{1,0,0}}},["FlipbookFramerate"]={"NR",32,32},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"}}},{"ParticleEmitter","Downslam",{["Color"]={"CS",{{0,1,1,1},{1,1,1,1}}},["ZOffset"]=0.22,["LightInfluence"]=1,["Lifetime"]={"NR",0.6,1},["Speed"]={"NR",0.0085257,0.0085257},["Brightness"]=3.93,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["Size"]={"NS",{{0,0,0},{0.26163,10.85,0},{1,12.14,0}}},["Enabled"]=false,["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["Rate"]=1,["Rotation"]={"NR",-100,-100},["Transparency"]={"NS",{{0,1,0},{0.59312,0.95628,0},{1,1,0}}},["Texture"]="rbxassetid://13447156433",["LightEmission"]=1,["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["FlipbookFramerate"]={"NR",30,30},["Squash"]={"NS",{{0,0,0},{1,0,0}}}}},{"ParticleEmitter","Downslam",{["Color"]={"CS",{{0,1,1,1},{1,1,1,1}}},["LightInfluence"]=1,["Lifetime"]={"NR",0.4,0.7},["Speed"]={"NR",0.00070461,0.00070461},["Brightness"]=3.93,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["Size"]={"NS",{{0,8.4553,0},{1,8.4553,0}}},["Enabled"]=false,["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["Rate"]=2,["Rotation"]={"NR",200,200},["Transparency"]={"NS",{{0,1,0},{0.59947,0.87978,0},{1,1,0}}},["EmissionDirection"]={"E","NormalId","Bottom"},["LightEmission"]=1,["Texture"]="rbxassetid://13780268621",["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Squash"]={"NS",{{0,0,0},{1,0,0}}}}},{"ParticleEmitter","Downslam",{["Color"]={"CS",{{0,1,1,1},{1,1,1,1}}},["Drag"]=10,["ZOffset"]=2.45,["LightInfluence"]=1,["Lifetime"]={"NR",0.4,0.7},["Speed"]={"NR",49.166,147.5},["Brightness"]=3.93,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["SpreadAngle"]={"V2",25,200},["Enabled"]=false,["Acceleration"]={"V3",0,-20.066,0},["EmissionDirection"]={"E","NormalId","Front"},["Rate"]=100,["Texture"]="http://www.roblox.com/asset/?id=14516318757",["Rotation"]={"NR",-90,-90},["Transparency"]={"NS",{{0,1,0},{0.60095,0.64481,0},{0.89218,0.94536,0},{1,1,0}}},["Size"]={"NS",{{0,0.73749,0.11747},{1,0.56067,0.21359}}},["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["LightEmission"]=1,["Squash"]={"NS",{{0,1,0},{1,1,0}}},["VelocitySpread"]=25,["Orientation"]={"E","ParticleOrientation","VelocityParallel"}}},{"ParticleEmitter","Downslam",{["Enabled"]=false,["Acceleration"]={"V3",0,-35.832,0},["RotSpeed"]={"NR",-360,360},["Color"]={"CS",{{0,1,1,1},{1,1,1,1}}},["Drag"]=2,["Rate"]=29,["Texture"]="http://www.roblox.com/asset/?id=626588936",["VelocitySpread"]=120,["Transparency"]={"NS",{{0,0,0},{1,0,0}}},["Size"]={"NS",{{0,0,0},{0.20019,0.53748,0.53748},{1,0,0}}},["Lifetime"]={"NR",0.3,0.6},["Speed"]={"NR",35.832,35.832},["Brightness"]=0.21,["Squash"]={"NS",{{0,0,0},{1,0.31148,0}}},["SpreadAngle"]={"V2",120,120}}},{"ParticleEmitter","Downslam",{["Color"]={"CS",{{0,1,1,1},{1,1,1,1}}},["Drag"]=10,["ZOffset"]=0.5625,["LightInfluence"]=1,["Lifetime"]={"NR",0.3,1.3},["Speed"]={"NR",26.961,107.84},["Brightness"]=3.93,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["SpreadAngle"]={"V2",0,360},["Enabled"]=false,["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["Rate"]=25,["Rotation"]={"NR",0,360},["Transparency"]={"NS",{{0,1,0},{0.53545,0.90164,0},{1,1,0}}},["EmissionDirection"]={"E","NormalId","Back"},["Texture"]="rbxassetid://11871320339",["LightEmission"]=1,["Size"]={"NS",{{0,4.8559,0},{1,4.8559,0}}},["FlipbookFramerate"]={"NR",32,32},["Squash"]={"NS",{{0,0,0},{1,0,0}}}}},{"ParticleEmitter","Downslam",{["Color"]={"CS",{{0,1,1,1},{1,1,1,1}}},["Drag"]=10,["ZOffset"]=0.5,["VelocitySpread"]=25,["Lifetime"]={"NR",0.1,0.4},["Speed"]={"NR",49.166,147.5},["Brightness"]=15,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["SpreadAngle"]={"V2",25,200},["Enabled"]=false,["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["Rate"]=49,["EmissionDirection"]={"E","NormalId","Front"},["Rotation"]={"NR",90,90},["Transparency"]={"NS",{{0,1,0},{0.54656,0.91257,0},{1,1,0}}},["Texture"]="http://www.roblox.com/asset/?id=13992997161",["Size"]={"NS",{{0,3.1958,1.0743},{0.48739,0.47269,0.25783},{1,0.12892,0}}},["LightEmission"]=1,["Acceleration"]={"V3",0,-20.066,0},["Squash"]={"NS",{{0,-0.15,0},{1,1.65,0}}},["Orientation"]={"E","ParticleOrientation","VelocityParallel"}}},{"ParticleEmitter","Downslam",{["Color"]={"CS",{{0,1,1,1},{1,1,1,1}}},["Drag"]=1,["LightInfluence"]=1,["Lifetime"]={"NR",0.4,0.7},["Speed"]={"NR",0.0037373,0.0037373},["Brightness"]=3.93,["SpreadAngle"]={"V2",15,15},["Enabled"]=false,["RotSpeed"]={"NR",-300,0},["Rate"]=13,["EmissionDirection"]={"E","NormalId","Bottom"},["Transparency"]={"NS",{{0,1,0},{0.59312,0.95628,0},{1,1,0}}},["Texture"]="rbxassetid://16125863310",["VelocitySpread"]=15,["LightEmission"]=1,["Size"]={"NS",{{0,1.7401,1.7401},{0.26163,14.237,5.0924},{1,28.948,0}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"}}},{"ParticleEmitter","Downslam",{["Color"]={"CS",{{0,1,1,1},{1,1,1,1}}},["Drag"]=1,["VelocitySpread"]=10,["Lifetime"]={"NR",0.1,0.3},["Speed"]={"NR",0.0035878,0.0035878},["Brightness"]=3.93,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["SpreadAngle"]={"V2",10,10},["Enabled"]=false,["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["RotSpeed"]={"NR",-200,200},["EmissionDirection"]={"E","NormalId","Bottom"},["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.59947,0.87978,0},{1,1,0}}},["Texture"]="rbxassetid://16168368652",["Size"]={"NS",{{0,1.6705,1.6705},{0.19345,8.0676,2.0881},{1,17.369,0}}},["LightEmission"]=1,["LightInfluence"]=1,["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"}}},{"ParticleEmitter","Downslam",{["Color"]={"CS",{{0,1,1,1},{1,1,1,1}}},["Drag"]=1,["VelocitySpread"]=10,["Lifetime"]={"NR",0.4,0.7},["Speed"]={"NR",0.0044847,0.0044847},["Brightness"]=3.93,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["SpreadAngle"]={"V2",10,10},["Enabled"]=false,["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["Rate"]=14,["EmissionDirection"]={"E","NormalId","Bottom"},["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.59947,0.87978,0},{1,1,0}}},["Texture"]="rbxassetid://16156678053",["Size"]={"NS",{{0,2.0881,2.0881},{0.26163,17.084,6.1108},{1,34.738,0}}},["LightEmission"]=1,["LightInfluence"]=1,["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"}}},{"ParticleEmitter","Downslam",{["Color"]={"CS",{{0,1,1,1},{1,1,1,1}}},["VelocitySpread"]=20,["Lifetime"]={"NR",0.4,0.7},["Speed"]={"NR",0.025783,0.025783},["Brightness"]=3.93,["SpreadAngle"]={"V2",20,20},["Enabled"]=false,["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["RotSpeed"]={"NR",-100,400},["Rate"]=4,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.58466,0.95082,0},{1,1,0}}},["Texture"]="rbxassetid://10316078099",["Size"]={"NS",{{0,0,0},{0.031933,14.089,6.1153},{0.11597,17.22,6.1153},{0.25042,18.263,6.1153},{0.36975,18.959,6.1153},{0.5,19.509,6.1153},{0.6,20.125,6.1153},{0.7,20.55,6.1153},{0.8,20.854,6.1153},{0.9,21.108,6.1153},{1,21.403,6.1153}}},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["LightInfluence"]=1,["Squash"]={"NS",{{0,0,0},{1,0,0}}},["LightEmission"]=1}},{"ParticleEmitter","Downslam",{["Color"]={"CS",{{0,1,1,1},{1,1,1,1}}},["Drag"]=9,["VelocitySpread"]=25,["Lifetime"]={"NR",0.1,0.4},["Speed"]={"NR",49.166,147.5},["Brightness"]=15,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["SpreadAngle"]={"V2",25,200},["Enabled"]=false,["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["Rate"]=57,["EmissionDirection"]={"E","NormalId","Front"},["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.59461,0.89071,0},{0.89218,0.94536,0},{1,1,0}}},["Texture"]="rbxassetid://16014733623",["Size"]={"NS",{{0,1.9667,0},{1,1.9667,0}}},["LightEmission"]=1,["Acceleration"]={"V3",0,-20.066,0},["FlipbookFramerate"]={"NR",28.8,28.8},["Squash"]={"NS",{{0,0,0},{1,0,0}}}}},{"ParticleEmitter","Downslam",{["Color"]={"CS",{{0,1,1,1},{1,1,1,1}}},["Drag"]=1,["VelocitySpread"]=25,["Lifetime"]={"NR",0.4,0.7},["Speed"]={"NR",0.0017369,0.0017369},["Brightness"]=3.93,["SpreadAngle"]={"V2",25,25},["Enabled"]=false,["RotSpeed"]={"NR",-200,200},["Rate"]=5,["EmissionDirection"]={"E","NormalId","Bottom"},["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.58466,0.95082,0},{1,1,0}}},["Texture"]="rbxassetid://16125955347",["Size"]={"NS",{{0,0,0},{0.088795,9.3963,4.7456},{1,17.369,0}}},["LightEmission"]=1,["LightInfluence"]=1,["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"}}},{"ParticleEmitter","Downslam",{["Color"]={"CS",{{0,1,1,1},{1,1,1,1}}},["VelocitySpread"]=10,["Lifetime"]={"NR",0.1,0.3},["Speed"]={"NR",0.144,0.144},["Brightness"]=3.93,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["SpreadAngle"]={"V2",10,10},["Enabled"]=false,["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["Rate"]=5,["Rotation"]={"NR",0,360},["Transparency"]={"NS",{{0,1,0},{0.54656,0.91257,0},{1,1,0}}},["Texture"]="rbxassetid://13675192481",["Size"]={"NS",{{0,0,0},{0.1,10.269,2.854},{0.2,11.817,2.4528},{0.3,12.526,1.7444},{0.4,12.931,1.3392},{0.5,13.205,1.0648},{0.6,13.423,0.84656},{0.7,13.623,0.64736},{0.8,13.823,0.44685},{0.9,14.037,0.23336},{1,14.27,0}}},["LightEmission"]=1,["LightInfluence"]=1,["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"}}},{"ParticleEmitter","Downslam",{["Color"]={"CS",{{0,1,1,1},{1,1,1,1}}},["Drag"]=9,["LightInfluence"]=1,["Lifetime"]={"NR",0.4,0.7},["Speed"]={"NR",24.28,121.4},["Brightness"]=3.93,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["SpreadAngle"]={"V2",25,200},["Enabled"]=false,["Acceleration"]={"V3",0,-20.066,0},["EmissionDirection"]={"E","NormalId","Front"},["Texture"]="rbxassetid://16014733623",["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.60053,0.91257,0},{1,1,0}}},["Size"]={"NS",{{0,1.9667,0},{1,1.9667,0}}},["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["LightEmission"]=1,["Squash"]={"NS",{{0,0,0},{1,0,0}}},["FlipbookFramerate"]={"NR",28.8,28.8},["VelocitySpread"]=25}},{"ParticleEmitter","Downslam",{["Color"]={"CS",{{0,1,1,1},{1,1,1,1}}},["Drag"]=10,["ZOffset"]=0.5,["LightInfluence"]=1,["Lifetime"]={"NR",0.4,0.7},["Speed"]={"NR",49.166,147.5},["Brightness"]=3.93,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["SpreadAngle"]={"V2",25,200},["Enabled"]=false,["Acceleration"]={"V3",0,-20.066,0},["EmissionDirection"]={"E","NormalId","Front"},["Rate"]=15,["Texture"]="http://www.roblox.com/asset/?id=13992997161",["Rotation"]={"NR",90,90},["Transparency"]={"NS",{{0,1,0},{0.54656,0.91257,0},{1,1,0}}},["Size"]={"NS",{{0,3.1958,1.0743},{0.48739,0.47269,0.25783},{1,0.12892,0}}},["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["LightEmission"]=1,["Squash"]={"NS",{{0,-0.15,0},{1,1.65,0}}},["VelocitySpread"]=25,["Orientation"]={"E","ParticleOrientation","VelocityParallel"}}},{"ParticleEmitter","Downslam",{["Color"]={"CS",{{0,1,1,1},{1,1,1,1}}},["Drag"]=20,["VelocitySpread"]=360,["Lifetime"]={"NR",0.1,0.3},["Speed"]={"NR",159.02,159.02},["Brightness"]=3.93,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["SpreadAngle"]={"V2",360,360},["Enabled"]=false,["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["Rate"]=44,["Rotation"]={"NR",90,90},["Transparency"]={"NS",{{0,1,0},{0.60053,0.91257,0},{1,1,0}}},["Texture"]="rbxassetid://12693242441",["Size"]={"NS",{{0,0,0},{0.10216,6.5089,1.4421},{1,0,0}}},["LightEmission"]=1,["LightInfluence"]=1,["Squash"]={"NS",{{0,0,0},{0.22016,0.4125,0},{1,3,0}}},["Orientation"]={"E","ParticleOrientation","VelocityParallel"}}},{"ParticleEmitter","Downslam",{["Enabled"]=false,["Texture"]="rbxassetid://10859315454",["RotSpeed"]={"NR",-200,200},["Size"]={"NS",{{0,0.26841,0.26841},{0.24947,13.813,2.5292},{0.47622,14.397,2.1401},{1,17.802,0}}},["Color"]={"CS",{{0,1,1,1},{1,1,1,1}}},["LightInfluence"]=1,["Speed"]={"NR",1.7802,8.9009},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.58466,0.95082,0},{1,1,0}}},["VelocitySpread"]=12,["Lifetime"]={"NR",0.4,0.7},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Brightness"]=3.93,["LightEmission"]=1,["SpreadAngle"]={"V2",12,12}}},{"ParticleEmitter","Downslam",{["Enabled"]=false,["RotSpeed"]={"NR",-200,200},["Texture"]="rbxassetid://16153421625",["Color"]={"CS",{{0,1,1,1},{1,1,1,1}}},["LightEmission"]=1,["Rate"]=10,["LightInfluence"]=1,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.60095,0.64481,0},{0.89218,0.94536,0},{1,1,0}}},["Speed"]={"NR",0.0044504,8.9009},["Lifetime"]={"NR",0.1,0.3},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Brightness"]=3.93,["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Size"]={"NS",{{0,0,0},{0.54704,10.992,2.0637},{1,17.802,0}}}}},{"ParticleEmitter","15",{["Color"]={"CS",{{0,1,1,1},{1,1,1,1}}},["Drag"]=3,["ZOffset"]=2,["Lifetime"]={"NR",0.6,0.6},["Speed"]={"NR",43.2,43.2},["Brightness"]=5,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["SpreadAngle"]={"V2",0,360},["Enabled"]=false,["RotSpeed"]={"NR",-15,15},["Rate"]=40,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.36522,0.96721,0},{1,1,0}}},["EmissionDirection"]={"E","NormalId","Right"},["Texture"]="rbxassetid://14462666506",["Size"]={"NS",{{0,7.02,0},{1,10.656,0}}},["FlipbookFramerate"]={"NR",15,15},["Squash"]={"NS",{{0,0,0},{1,0,0}}}}},{"ParticleEmitter","14",{["Enabled"]=false,["EmissionDirection"]={"E","NormalId","Right"},["Texture"]="rbxassetid://13776993233",["Color"]={"CS",{{0,0.54902,1,0.76078},{1,0.84706,0.54118,1}}},["Drag"]=10,["Rate"]=50,["Size"]={"NS",{{0,0,0},{0.2981,0.93646,0.36313},{1,0,0}}},["VelocitySpread"]=360,["Transparency"]={"NS",{{0,0,0},{1,0,0}}},["Speed"]={"NR",120,120},["Lifetime"]={"NR",0.1,0.3},["LightEmission"]=-2,["Brightness"]=20,["Squash"]={"NS",{{0,0,0},{1,0,0}}},["SpreadAngle"]={"V2",360,360}}},{"ParticleEmitter","Downslam",{["Color"]={"CS",{{0,0.54902,1,0.76078},{1,0.84706,0.54118,1}}},["Drag"]=55,["ZOffset"]=2,["TimeScale"]=0.75,["VelocitySpread"]=3650,["Squash"]={"NS",{{0,-3,0},{0.11628,3,0},{0.24789,-3,0},{0.39799,3,0},{0.55233,-3,0},{0.7019,3,0},{0.80127,-3,0},{1,3,0}}},["Speed"]={"NR",480,480},["Brightness"]=10,["SpreadAngle"]={"V2",3650,3650},["Enabled"]=false,["Rate"]=31,["EmissionDirection"]={"E","NormalId","Right"},["Transparency"]={"NS",{{0,0,0},{1,0,0}}},["LightEmission"]=0.6,["Texture"]="rbxassetid://16178924462",["Size"]={"NS",{{0,0,0},{0.21,5.1467,0},{0.48,0,0},{0.67,1.3539,0},{1,0,0}}},["Lifetime"]={"NR",0.1,0.3}}},{"Attachment","Attachment",{},nil,nil,{{"ParticleEmitter","Downslam",{["FlipbookFramerate"]={"NR",32,32},["Drag"]=10,["TimeScale"]=0.4,["Lifetime"]={"NR",1,1},["Speed"]={"NR",0.013939,0.013939},["Brightness"]=5,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["Size"]={"NS",{{0,15.05,0},{1,15.05,0}}},["Enabled"]=false,["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["Rate"]=1,["Rotation"]={"NR",180,180},["Transparency"]={"NS",{{0,0,0},{1,1,0}}},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Texture"]="rbxassetid://13782885260",["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Color"]={"CS",{{0,0.56471,1,0.63137},{0.5,0.62175,0.58408,0.85478},{1,0.65882,0.31373,1}}}}},{"ParticleEmitter","Shockwave1",{["Enabled"]=false,["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["Texture"]="rbxassetid://13675192481",["Color"]={"CS",{{0,0.54902,1,0.76078},{1,0.84706,0.54118,1}}},["Rate"]=2,["ZOffset"]=0.5,["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Rotation"]={"NR",0,360},["Transparency"]={"NS",{{0,0.77596,0},{0.36945,0.68852,0},{1,1,0}}},["Speed"]={"NR",0.48279,0.48279},["Lifetime"]={"NR",0.5,0.7},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Brightness"]=6,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["Size"]={"NS",{{0,0,0},{0.1,14.971,4.1609},{0.2,17.229,3.5761},{0.3,18.261,2.5432},{0.4,18.852,1.9525},{0.5,19.252,1.5524},{0.6,19.57,1.2342},{0.7,19.861,0.9438},{0.8,20.153,0.65147},{0.9,20.464,0.34022},{1,20.805,0}}}}},{"ParticleEmitter","Smoke",{["Color"]={"CS",{{0,0.54902,1,0.76078},{1,0.84706,0.54118,1}}},["VelocitySpread"]=10,["Lifetime"]={"NR",0.2,0.3},["Speed"]={"NR",0.0010075,0.0010075},["Brightness"]=20,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["SpreadAngle"]={"V2",10,10},["Enabled"]=false,["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["RotSpeed"]={"NR",15,15},["Rate"]=2,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.27643,0.725,0},{1,1,0}}},["Texture"]="rbxassetid://14595543880",["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Size"]={"NS",{{0,20.151,0},{1,20.151,0}}},["FlipbookFramerate"]={"NR",16,16},["Squash"]={"NS",{{0,0,0},{1,0,0}}}}},{"ParticleEmitter","Wind1",{["Color"]={"CS",{{0,0.54902,1,0.76078},{1,0.84706,0.54118,1}}},["Drag"]=9,["VelocitySpread"]=45,["Lifetime"]={"NR",0.2,0.4},["Speed"]={"NR",0,12.431},["Brightness"]=20,["SpreadAngle"]={"V2",45,45},["Enabled"]=false,["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["RotSpeed"]={"NR",-60,60},["Rate"]=10,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{1,1,0}}},["Texture"]="http://www.roblox.com/asset/?id=12685367098",["LightEmission"]=1,["Size"]={"NS",{{0,0,7.9884},{0.1,11.353,7.9884},{0.2,15.153,7.9884},{0.3,17.364,7.9884},{0.4,18.825,7.9884},{0.5,19.848,7.9884},{0.6,20.584,7.9884},{0.7,21.119,7.9884},{0.8,21.506,7.9884},{0.9,21.781,7.9884},{1,21.968,7.9884}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"}}},{"ParticleEmitter","Effect4",{["Enabled"]=false,["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["Texture"]="rbxassetid://14200879082",["Size"]={"NS",{{0,7.4389,0.92986},{0.1,8.5676,0.92986},{0.2,9.3286,0.92986},{0.3,9.7664,0.92986},{0.4,10,0.92986},{0.5,10.122,0.92986},{0.6,10.183,0.92986},{0.7,10.212,0.92986},{0.8,10.224,0.92986},{0.9,10.228,0.92986},{1,10.228,0.92986},{1,10.228,0.92986}}},["Color"]={"CS",{{0,0.54902,1,0.76078},{1,0.84706,0.54118,1}}},["Drag"]=9,["ZOffset"]=-1,["VelocitySpread"]=360,["Rotation"]={"NR",0,360},["Transparency"]={"NS",{{0,0.9,0},{1,0.9,0}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Lifetime"]={"NR",0.1,0.3},["Speed"]={"NR",12.755,102.04},["Brightness"]=20,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["SpreadAngle"]={"V2",360,360}}},{"ParticleEmitter","Shockwave1",{["Color"]={"CS",{{0,0.54902,1,0.76078},{1,0.84706,0.54118,1}}},["ZOffset"]=0.5,["VelocitySpread"]=5,["Lifetime"]={"NR",0.5,0.7},["Speed"]={"NR",0.70101,0.70101},["Brightness"]=6,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["SpreadAngle"]={"V2",5,5},["Enabled"]=false,["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["Rate"]=2,["Rotation"]={"NR",0,360},["Transparency"]={"NS",{{0,0.77596,0},{0.36945,0.68852,0},{1,1,0}}},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Texture"]="rbxassetid://16880045313",["Size"]={"NS",{{0,0,0},{0.1,21.738,6.0417},{0.2,25.016,5.1924},{0.3,26.516,3.6927},{0.4,27.373,2.835},{0.5,27.954,2.254},{0.6,28.416,1.7921},{0.7,28.838,1.3704},{0.8,29.262,0.94593},{0.9,29.714,0.494},{1,30.208,0}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}}}},{"ParticleEmitter","Shockwave1",{["Color"]={"CS",{{0,0.54902,1,0.76078},{1,0.84706,0.54118,1}}},["ZOffset"]=0.5,["VelocitySpread"]=5,["Lifetime"]={"NR",0.5,0.7},["Speed"]={"NR",0.36272,0.36272},["Brightness"]=6,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["SpreadAngle"]={"V2",5,5},["Enabled"]=false,["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["Rate"]=2,["Rotation"]={"NR",0,360},["Transparency"]={"NS",{{0,0.77596,0},{0.36945,0.68852,0},{1,1,0}}},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Texture"]="rbxassetid://13675192481",["Size"]={"NS",{{0,0,0},{0.1,11.248,3.1262},{0.2,12.944,2.6867},{0.3,13.72,1.9107},{0.4,14.164,1.4669},{0.5,14.465,1.1663},{0.6,14.704,0.92729},{0.7,14.922,0.70909},{0.8,15.141,0.48946},{0.9,15.375,0.25561},{1,15.631,0}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}}}},{"ParticleEmitter","Shockwave1",{["Color"]={"CS",{{0,0.54902,1,0.76078},{1,0.84706,0.54118,1}}},["ZOffset"]=0.5,["VelocitySpread"]=5,["Lifetime"]={"NR",0.5,0.7},["Speed"]={"NR",0.48279,0.48279},["Brightness"]=6,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["SpreadAngle"]={"V2",5,5},["Enabled"]=false,["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["Rate"]=2,["Rotation"]={"NR",0,360},["Transparency"]={"NS",{{0,0.77596,0},{0.36945,0.68852,0},{1,1,0}}},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Texture"]="rbxassetid://16879953929",["Size"]={"NS",{{0,0,0},{0.1,14.971,4.1609},{0.2,17.229,3.5761},{0.3,18.261,2.5432},{0.4,18.852,1.9525},{0.5,19.252,1.5524},{0.6,19.57,1.2342},{0.7,19.861,0.9438},{0.8,20.153,0.65147},{0.9,20.464,0.34022},{1,20.805,0}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}}}},{"ParticleEmitter","Ground",{["ShapeStyle"]={"E","ParticleEmitterShapeStyle","Surface"},["Color"]={"CS",{{0,0.54902,1,0.76078},{1,0.84706,0.54118,1}}},["Drag"]=1,["Lifetime"]={"NR",0.6,1.3},["Speed"]={"NR",0.0027402,0.0027402},["Brightness"]=8,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["Size"]={"NS",{{0,19.181,0},{1,19.181,0}}},["Enabled"]=false,["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["LockedToPart"]=true,["Rate"]=10,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.44186,0.46448,0},{1,1,0}}},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Texture"]="rbxassetid://125298042485680",["Squash"]={"NS",{{0,0,0},{1,0,0}}}}}}}}}}}},
        	["Game Over"] = {{"PointLight","PointLight",{["Range"]=12}},{"Part","Part",{["CFrame"]={"CF",0,0,0,1,0,0,0,1,0,0,0,1},["Size"]={"V3",4,1,2}},nil,nil,{{"Attachment","Attachment",{["CFrame"]={"CF",0,4.762,0,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0,4.762,0}},nil,nil,{{"ParticleEmitter","Game OVER",{["Color"]={"CS",{{0,0.68235,0.68627,1},{1,0.68235,0.68627,1}}},["ZOffset"]=4,["Lifetime"]={"NR",2,2},["Speed"]={"NR",0.003,0.003},["Brightness"]=20,["Size"]={"NS",{{0,5,0},{1,5,0}}},["Enabled"]=false,["LockedToPart"]=true,["Rate"]=1,["EmissionDirection"]={"E","NormalId","Back"},["Transparency"]={"NS",{{0,1,0},{0.11819,0.15,0},{0.19714,0.0375,0},{0.27839,0,0},{0.80194,0,0},{0.82964,0.41875,0},{0.88966,0.81875,0},{0.94598,0.94375,0},{1,1,0}}},["Texture"]="rbxassetid://12396997116",["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid8x8"},["FlipbookFramerate"]={"NR",30,30},["Squash"]={"NS",{{0,0,0},{1,0,0}}}},{["EmitCount"]=2,["EmitDelay"]=0}},{"ParticleEmitter","Shockwaves",{["Color"]={"CS",{{0,1,0.4,0.4},{1,1,0.4,0.4}}},["Drag"]=5,["ZOffset"]=1.4325,["Lifetime"]={"NR",1,1},["Speed"]={"NR",0,1.0244},["Brightness"]=5,["Size"]={"NS",{{0,3,0},{1,3,0}}},["Enabled"]=false,["LockedToPart"]=true,["Rate"]=4,["Rotation"]={"NR",90,90},["Transparency"]={"NS",{{0,0,0},{0.16812,0.21875,0},{0.33873,0.50625,0},{0.47572,0.80625,0},{0.63885,0.9625,0},{0.8132,0.975,0},{1,1,0}}},["LightEmission"]=1,["EmissionDirection"]={"E","NormalId","Back"},["Texture"]="rbxassetid://12397019276",["Squash"]={"NS",{{0,3,0},{0.49938,0,0},{1,0,0}}}},{["EmitCount"]=3,["EmitDelay"]=0}}}}},1}},
        	["Soul Grasp"] = {{"Part","particles",{["CFrame"]={"CF",0,0,0,1,0,0,0,1,0,0,0,1},["Size"]={"V3",8.95,0.05,8.7}},nil,nil,{{"Attachment","StartEmitAttachment",{},nil,nil,{{"ParticleEmitter","pentagramemit",{["Enabled"]=false,["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["Texture"]="rbxassetid://12801205601",["Color"]={"CS",{{0,1,0.094118,0.011765},{1,1,0.094118,0.011765}}},["LockedToPart"]=true,["Rate"]=5,["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Transparency"]={"NS",{{0,1,0},{0.026185,0.2125,0.0125},{0.084788,0,0},{0.49693,0,0},{0.90031,0,0},{1,1,0}}},["Speed"]={"NR",0.01,0.01},["Lifetime"]={"NR",0.75,0.75},["LightEmission"]=0.4,["Brightness"]=8.18,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["Size"]={"NS",{{0,0,0},{0.1,4.4456,0},{0.2,5.2343,0},{0.3,5.6008,0},{0.4,5.7939,0},{0.5,5.899,0},{0.6,5.9553,0},{0.7,5.9834,0},{0.8,5.9956,0},{0.9,5.9995,0},{1,6,0}}}}},{"ParticleEmitter","flash",{["Enabled"]=false,["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["Texture"]="rbxassetid://12647757735",["Rate"]=5,["Color"]={"CS",{{0,1,0.17255,0.0078431},{1,1,0.17255,0.0078431}}},["LockedToPart"]=true,["ZOffset"]=0.1,["LightEmission"]=0.4,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{1,0,0}}},["Speed"]={"NR",0.01,0.01},["Lifetime"]={"NR",0.25,0.25},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Brightness"]=8.18,["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Size"]={"NS",{{0,10,0},{0.1,9.5143,0},{0.2,6.656,0},{0.3,3.7058,0},{0.4,2.2091,0},{0.5,1.317,0},{0.6,0.74652,0},{0.7,0.37936,0},{0.8,0.15444,0},{0.9,0.035733,0},{1,0,0}}}}},{"ParticleEmitter","impactemit",{["Enabled"]=false,["Color"]={"CS",{{0,1,0.11765,0},{1,1,0.11765,0}}},["ZOffset"]=1,["Texture"]="rbxassetid://12409026765",["Rotation"]={"NR",45,45},["Transparency"]={"NS",{{0,0,0},{1,0,0}}},["Lifetime"]={"NR",0.15,0.15},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["LightEmission"]=1,["Brightness"]=10,["Speed"]={"NR",0.001,0.001},["Size"]={"NS",{{0,10,0},{0.1,9.5143,0},{0.2,6.656,0},{0.3,3.7058,0},{0.4,2.2091,0},{0.5,1.317,0},{0.6,0.74652,0},{0.7,0.37936,0},{0.8,0.15444,0},{0.9,0.035733,0},{1,0,0}}}}},{"ParticleEmitter","glowground",{["Enabled"]=false,["ShapeStyle"]={"E","ParticleEmitterShapeStyle","Surface"},["LightEmission"]=0.42,["Texture"]="rbxassetid://12082081459",["Color"]={"CS",{{0,1,0.11765,0},{1,1,0.11765,0}}},["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["Rate"]=15,["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Rotation"]={"NR",90,90},["Transparency"]={"NS",{{0,0,0},{0.086342,0.48067,0},{0.30424,0.9,0},{1,1,0}}},["Speed"]={"NR",0.001,0.001},["Lifetime"]={"NR",1.5,1.5},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Brightness"]=10,["Shape"]={"E","ParticleEmitterShape","Disc"},["Size"]={"NS",{{0,0,0},{0.1,11,0},{0.2,12.07,0},{0.3,12.53,0},{0.4,12.763,0},{0.5,12.886,0},{0.6,12.95,0},{0.7,12.982,0},{0.8,12.995,0},{0.9,12.999,0},{1,13,0}}}}},{"ParticleEmitter","glow",{["Enabled"]=false,["ShapeStyle"]={"E","ParticleEmitterShapeStyle","Surface"},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Color"]={"CS",{{0,1,0.11765,0},{1,1,0.11765,0}}},["Texture"]="rbxassetid://12082081459",["Rate"]=15,["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["Rotation"]={"NR",90,90},["Transparency"]={"NS",{{0,0,0},{0.086342,0.48067,0},{0.30424,0.9,0},{1,1,0}}},["Speed"]={"NR",0.001,0.001},["Lifetime"]={"NR",1.5,1.5},["LightEmission"]=0.42,["Brightness"]=10,["Shape"]={"E","ParticleEmitterShape","Disc"},["Size"]={"NS",{{0,0,0},{0.1,7.4733,0},{0.2,8.763,0},{0.3,9.3575,0},{0.4,9.6693,0},{0.5,9.8383,0},{0.6,9.9285,0},{0.7,9.9735,0},{0.8,9.993,0},{0.9,9.9992,0},{1,10,0}}}}}}},{"Attachment","AfterStartEnableAttachment",{},nil,nil,{{"ParticleEmitter","pentagramenable",{["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["Texture"]="rbxassetid://12801205601",["Color"]={"CS",{{0,1,0.094118,0.011765},{1,1,0.094118,0.011765}}},["LockedToPart"]=true,["Rate"]=5,["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Transparency"]={"NS",{{0,0,0},{1,0,0}}},["Speed"]={"NR",0.01,0.01},["Lifetime"]={"NR",0.75,0.75},["LightEmission"]=0.4,["Brightness"]=8.18,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["Size"]={"NS",{{0,6,0},{1,6,0}}}}},{"ParticleEmitter","crescentsin",{["Color"]={"CS",{{0,1,0.094118,0.011765},{1,1,0.094118,0.011765}}},["Lifetime"]={"NR",0.55,0.85},["Speed"]={"NR",0.01,0.01},["Brightness"]=8.18,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["Size"]={"NS",{{0,10,0},{0.1,9.9706,0},{0.2,9.8734,0},{0.3,9.6913,0},{0.4,9.4003,0},{0.5,8.9678,0},{0.6,8.355,0},{0.7,7.5555,0},{0.8,6.7208,0},{0.9,6.1656,0},{1,6,0}}},["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["RotSpeed"]={"NR",360,720},["LockedToPart"]=true,["Rate"]=25,["Rotation"]={"NR",-1000,1000},["Transparency"]={"NS",{{0,0,0},{0.44514,0.1125,0},{0.65337,0.79375,0},{1,1,0}}},["Texture"]="rbxassetid://12801499270",["LightEmission"]=0.65,["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Squash"]={"NS",{{0,0,0},{1,0,0}}}},{["EmitCount"]=5,["EmitDelay"]=0}},{"ParticleEmitter","glowgroundenable",{["ShapeStyle"]={"E","ParticleEmitterShapeStyle","Surface"},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Texture"]="rbxassetid://12082081459",["Color"]={"CS",{{0,1,0.11765,0},{1,1,0.11765,0}}},["Rate"]=25,["ZOffset"]=-0.001,["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["Rotation"]={"NR",90,90},["Transparency"]={"NS",{{0,1,0},{0.50374,0.60112,0},{1,1,0}}},["Speed"]={"NR",0.001,0.001},["Lifetime"]={"NR",0.45,0.45},["Orientation"]={"E","ParticleOrientation","VelocityPerpendicular"},["Brightness"]=0,["Shape"]={"E","ParticleEmitterShape","Disc"},["Size"]={"NS",{{0,0,0},{0.1,11,0},{0.2,12.07,0},{0.3,12.53,0},{0.4,12.763,0},{0.5,12.886,0},{0.6,12.95,0},{0.7,12.982,0},{0.8,12.995,0},{0.9,12.999,0},{1,13,0}}}}}}}},1},{"Part","Sphere",{["Color"]={"C3",0.67451,0.30196,0.086275},["Shape"]={"E","PartType","Ball"},["Material"]={"E","Material","Neon"},["CFrame"]={"CF",-1.9e-05,3,0.15001,1,0,0,0,1,0,0,0,1},["Size"]={"V3",1.35,1.35,1.35}},nil,nil,{{"Attachment","suckingAttachment",{},nil,nil,{{"ParticleEmitter","shock",{["Enabled"]=false,["Texture"]="rbxassetid://11114228118",["Rate"]=10,["Size"]={"NS",{{0,9,3},{0.1,8.8191,3},{0.2,8.1761,3},{0.3,6.9218,3},{0.4,5.126,3},{0.5,3.3018,3},{0.6,1.8946,3},{0.7,0.95362,1.8972},{0.8,0.3823,0.75459},{0.9,0.087037,0.16407},{1,1.7764e-15,0}}},["Color"]={"CS",{{0,0,0,0},{1,0,0,0}}},["LockedToPart"]=true,["ZOffset"]=0.1,["Squash"]={"NS",{{0,0,0},{1,0,0}}},["VelocitySpread"]=360,["Transparency"]={"NS",{{0,1,0},{0.50125,0.52247,0},{1,1,0}}},["Speed"]={"NR",0.001,0.001},["Lifetime"]={"NR",0.25,0.35},["Orientation"]={"E","ParticleOrientation","VelocityParallel"},["Brightness"]=0,["LightEmission"]=-1,["SpreadAngle"]={"V2",360,-360}}},{"ParticleEmitter","vprtex",{["Color"]={"CS",{{0,0,0,0},{1,0,0,0}}},["ZOffset"]=-0.5,["VelocitySpread"]=100,["Lifetime"]={"NR",0.25,0.35},["Speed"]={"NR",0.001,0.001},["Brightness"]=0,["SpreadAngle"]={"V2",100,100},["Enabled"]=false,["RotSpeed"]={"NR",500,500},["LockedToPart"]=true,["Rate"]=10,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,1,0},{0.50125,0.23034,0},{1,1,0}}},["Orientation"]={"E","ParticleOrientation","VelocityParallel"},["Texture"]="rbxassetid://11114276571",["Size"]={"NS",{{0,8,0},{0.46259,3.125,0},{1,0,0}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}}}},{"ParticleEmitter","crescentsin",{["Color"]={"CS",{{0,1,0.094118,0.011765},{1,1,0.094118,0.011765}}},["VelocitySpread"]=360,["Lifetime"]={"NR",0.45,0.65},["Speed"]={"NR",0.01,0.01},["Brightness"]=8.18,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["SpreadAngle"]={"V2",360,-360},["Enabled"]=false,["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["LockedToPart"]=true,["Rate"]=15,["Rotation"]={"NR",-360,360},["Transparency"]={"NS",{{0,0,0},{1,0,0}}},["Texture"]="rbxassetid://12801499270",["Size"]={"NS",{{0,7,2},{0.1,6.8593,2},{0.2,6.3592,2},{0.3,5.3836,2},{0.4,3.9869,2},{0.5,2.5681,2},{0.6,1.4736,1.4736},{0.7,0.7417,0.7417},{0.8,0.29734,0.29734},{0.9,0.067696,0.067696},{1,8.8818e-16,8.8818e-16}}},["LightEmission"]=0.4,["Orientation"]={"E","ParticleOrientation","VelocityParallel"},["Squash"]={"NS",{{0,0,0},{1,0,0}}}},{["EmitCount"]=5,["EmitDelay"]=0}},{"ParticleEmitter","glow",{["Enabled"]=false,["ShapeStyle"]={"E","ParticleEmitterShapeStyle","Surface"},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Color"]={"CS",{{0,1,0.11765,0},{1,1,0.11765,0}}},["Texture"]="rbxassetid://12082081459",["Rate"]=2,["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["Rotation"]={"NR",90,90},["Transparency"]={"NS",{{0,1,0},{0.5,0.8764,0},{1,1,0}}},["Speed"]={"NR",0.001,0.001},["Lifetime"]={"NR",0.35,0.35},["LightEmission"]=0.42,["Brightness"]=10,["Shape"]={"E","ParticleEmitterShape","Disc"},["Size"]={"NS",{{0,0,0},{0.1,7.4733,0},{0.2,8.763,0},{0.3,9.3575,0},{0.4,9.6693,0},{0.5,9.8383,0},{0.6,9.9285,0},{0.7,9.9735,0},{0.8,9.993,0},{0.9,9.9992,0},{1,10,0}}}}},{"ParticleEmitter","dark",{["Enabled"]=false,["ShapeStyle"]={"E","ParticleEmitterShapeStyle","Surface"},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Color"]={"CS",{{0,1,0.11765,0},{1,1,0.11765,0}}},["Texture"]="rbxassetid://12082081459",["ZOffset"]=-0.05,["Rate"]=8,["Rotation"]={"NR",90,90},["Transparency"]={"NS",{{0,1,0},{0.298,0.6573,0},{1,1,0}}},["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["Lifetime"]={"NR",0.35,0.35},["Speed"]={"NR",0.001,0.001},["Brightness"]=0,["Shape"]={"E","ParticleEmitterShape","Disc"},["Size"]={"NS",{{0,0,0},{0.1,14.399,0},{0.2,17.18,0},{0.3,18.508,0},{0.4,19.221,0},{0.5,19.615,0},{0.6,19.828,0},{0.7,19.936,0},{0.8,19.983,0},{0.9,19.998,0},{1,20,0}}}}},{"ParticleEmitter","EMITCHARGE",{["Enabled"]=false,["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["Texture"]="rbxassetid://13069511947",["Rate"]=5,["Color"]={"CS",{{0,1,0.11373,0.031373},{1,1,0.11373,0.031373}}},["ZOffset"]=3,["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Speed"]={"NR",0.001,0.001},["Transparency"]={"NS",{{0,0,0},{1,0,0}}},["Lifetime"]={"NR",0.55,0.55},["LightEmission"]=0.6,["Brightness"]=7.56,["FlipbookLayout"]={"E","ParticleFlipbookLayout","Grid4x4"},["Size"]={"NS",{{0,0,0},{0.1,2.505,0},{0.2,3.0483,0},{0.3,3.3727,0},{0.4,3.5902,0},{0.5,3.7419,0},{0.6,3.8482,0},{0.7,3.9207,0},{0.8,3.967,0},{0.9,3.9922,0},{1,4,0}}}},{["EmitCount"]=2}},{"ParticleEmitter","EMITCHARGE2",{["Enabled"]=false,["FlipbookMode"]={"E","ParticleFlipbookMode","OneShot"},["Color"]={"CS",{{0,1,0.11373,0.031373},{1,1,0.11373,0.031373}}},["Texture"]="rbxassetid://13087052117",["ZOffset"]=3,["Rate"]=5,["Rotation"]={"NR",45,45},["Transparency"]={"NS",{{0,0,0},{1,0,0}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}},["Lifetime"]={"NR",0.25,0.25},["LightEmission"]=1,["Brightness"]=7.56,["Speed"]={"NR",0.001,0.001},["Size"]={"NS",{{0,0,0},{0.07507,3.388,0},{0.1995,4.8125,0},{0.61507,3.6928,0},{1,3.0625,0}}}}}}},{"Attachment","2",{}},{"Attachment","BeamsAttachment",{["CFrame"]={"CF",0.75,8.55,-5.2,1,0,0,0,1,0,0,0,1},["Position"]={"V3",0.75,8.55,-5.2}},nil,nil,{{"Beam","1",{["FaceCamera"]=true,["Width0"]=5,["CurveSize1"]=-8,["TextureSpeed"]=4,["CurveSize0"]=2,["Segments"]=8,["Texture"]="rbxassetid://11110371162",["Transparency"]={"NS",{{0,1,0},{0.17638,0.9375,0},{0.23466,0.50625,0},{0.39264,0.18125,0},{0.59969,0.2375,0},{1,1,0}}},["Color"]={"CS",{{0,1,0.094118,0.011765},{1,1,0.094118,0.011765}}},["LightEmission"]=0.25,["Brightness"]=8.25,["TextureLength"]=0.625},nil,{["Attachment1"]={2,2},["Attachment0"]={2,3}}},{"Beam","1.1",{["FaceCamera"]=true,["Width0"]=5,["CurveSize1"]=7,["TextureSpeed"]=4,["CurveSize0"]=-3,["Segments"]=8,["Texture"]="rbxassetid://11110371162",["Transparency"]={"NS",{{0,1,0},{0.17638,0.9375,0},{0.23466,0.50625,0},{0.39264,0.18125,0},{0.59969,0.25,0},{1,1,0}}},["Color"]={"CS",{{0,1,0.094118,0.011765},{1,1,0.094118,0.011765}}},["LightEmission"]=0.25,["Brightness"]=8.25,["TextureLength"]=0.625},nil,{["Attachment1"]={2,2},["Attachment0"]={2,4}}},{"Beam","1.2",{["FaceCamera"]=true,["Width0"]=5,["CurveSize1"]=-6,["TextureSpeed"]=4,["CurveSize0"]=-2,["Segments"]=8,["Texture"]="rbxassetid://11110371162",["Transparency"]={"NS",{{0,1,0},{0.17638,0.9375,0},{0.23466,0.50625,0},{0.39264,0.18125,0},{0.59969,0.25,0},{1,1,0}}},["Color"]={"CS",{{0,1,0.094118,0.011765},{1,1,0.094118,0.011765}}},["LightEmission"]=0.25,["Brightness"]=8.25,["TextureLength"]=0.625},nil,{["Attachment1"]={2,7},["Attachment0"]={2,5}}},{"Beam","1.3",{["FaceCamera"]=true,["Width0"]=5,["CurveSize1"]=6,["TextureSpeed"]=4,["CurveSize0"]=3,["Segments"]=8,["Texture"]="rbxassetid://11110371162",["Transparency"]={"NS",{{0,1,0},{0.17638,0.9375,0},{0.23466,0.50625,0},{0.39264,0.18125,0},{0.60123,0.25,0},{1,1,0}}},["Color"]={"CS",{{0,1,0.094118,0.011765},{1,1,0.094118,0.011765}}},["LightEmission"]=0.25,["Brightness"]=8.25,["TextureLength"]=0.625},nil,{["Attachment1"]={2,7},["Attachment0"]={2,6}}},{"Beam","2",{["FaceCamera"]=true,["Width0"]=4,["Color"]={"CS",{{0,0,0,0},{1,0,0,0}}},["TextureSpeed"]=4,["ZOffset"]=0.01,["CurveSize0"]=2,["Segments"]=8,["Transparency"]={"NS",{{0,1,0},{0.17638,0.9375,0},{0.23466,0.50625,0},{0.39264,0.18125,0},{0.59969,0.2375,0},{1,1,0}}},["Texture"]="rbxassetid://11110368524",["CurveSize1"]=-8,["Brightness"]=0,["TextureLength"]=1.5},nil,{["Attachment1"]={2,2},["Attachment0"]={2,3}}},{"Beam","2.1",{["FaceCamera"]=true,["Width0"]=4,["Color"]={"CS",{{0,0,0,0},{1,0,0,0}}},["TextureSpeed"]=4,["ZOffset"]=0.01,["CurveSize0"]=-3,["Segments"]=8,["Transparency"]={"NS",{{0,1,0},{0.17638,0.9375,0},{0.23466,0.50625,0},{0.39264,0.18125,0},{0.60123,0.24375,0},{1,1,0}}},["Texture"]="rbxassetid://11110368524",["CurveSize1"]=7,["Brightness"]=0,["TextureLength"]=1.5},nil,{["Attachment1"]={2,2},["Attachment0"]={2,4}}},{"Beam","2.2",{["FaceCamera"]=true,["Width0"]=4,["Color"]={"CS",{{0,0,0,0},{1,0,0,0}}},["TextureSpeed"]=4,["ZOffset"]=0.01,["CurveSize0"]=-2,["Segments"]=8,["Transparency"]={"NS",{{0,1,0},{0.17638,0.9375,0},{0.23466,0.50625,0},{0.39264,0.18125,0},{0.60123,0.25,0},{1,1,0}}},["Texture"]="rbxassetid://11110368524",["CurveSize1"]=-6,["Brightness"]=0,["TextureLength"]=1.5},nil,{["Attachment1"]={2,7},["Attachment0"]={2,5}}},{"Beam","2.3",{["FaceCamera"]=true,["Width0"]=4,["Color"]={"CS",{{0,0,0,0},{1,0,0,0}}},["TextureSpeed"]=4,["ZOffset"]=0.01,["CurveSize0"]=3,["Segments"]=8,["Transparency"]={"NS",{{0,1,0},{0.17638,0.9375,0},{0.23466,0.50625,0},{0.39264,0.18125,0},{0.59969,0.25,0},{1,1,0}}},["Texture"]="rbxassetid://11110368524",["CurveSize1"]=6,["Brightness"]=0,["TextureLength"]=1.5},nil,{["Attachment1"]={2,7},["Attachment0"]={2,6}}}}},{"Attachment","1.1",{["CFrame"]={"CF",-0.049999,6.1,6,1,0,0,0,1,0,0,0,1},["Position"]={"V3",-0.049999,6.1,6}}},{"Attachment","1.2",{["CFrame"]={"CF",-4.3,-2.9,-4.75,1,0,0,0,1,0,0,0,1},["Position"]={"V3",-4.3,-2.9,-4.75}}},{"Attachment","1.3",{["CFrame"]={"CF",5.5359,-2.75,2.4557,0.9063,0,0.42264,0,1,0,-0.42264,0,0.9063},["Axis"]={"V3",0.9063,0,-0.42264},["Rotation"]={"V3",0,25.002,0},["Position"]={"V3",5.5359,-2.75,2.4557},["Orientation"]={"V3",0,25.002,0}}},{"Attachment","2.2",{["CFrame"]={"CF",0,0,3.8147e-06,0.087131,0,0.9962,0,1,0,-0.9962,0,0.087131},["Axis"]={"V3",0.087131,0,-0.9962},["Rotation"]={"V3",0,85.001,0},["Position"]={"V3",0,0,3.8147e-06},["Orientation"]={"V3",0,85.001,0}}},{"Attachment","finalaura",{},nil,nil,{{"ParticleEmitter","blackaura",{["Color"]={"CS",{{0,1,0.11373,0},{1,1,0.11373,0}}},["Drag"]=9,["ZOffset"]=-1,["VelocitySpread"]=360,["Lifetime"]={"NR",0.35,0.75},["Speed"]={"NR",2,8},["Brightness"]=0,["SpreadAngle"]={"V2",360,-360},["Enabled"]=false,["Acceleration"]={"V3",0,5,0},["LockedToPart"]=true,["Rate"]=10,["Rotation"]={"NR",0,180},["Transparency"]={"NS",{{0,0.475,0},{0.29601,0.79375,0},{1,1,0}}},["LightEmission"]=-1,["Texture"]="rbxassetid://11115160312",["Size"]={"NS",{{0,0,3},{0.1,2.3101,3},{0.2,3.4079,3},{0.3,4.1825,3},{0.4,4.7577,3},{0.5,5.1892,3},{0.6,5.5087,3},{0.7,5.7369,3},{0.8,5.8882,3},{0.9,5.9732,3},{1,6,3}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}}}},{"ParticleEmitter","fireaura",{["Color"]={"CS",{{0,1,0.16471,0},{1,1,0.16471,0}}},["Drag"]=9,["ZOffset"]=1,["VelocitySpread"]=360,["Lifetime"]={"NR",0.45,0.45},["Speed"]={"NR",4,6},["Brightness"]=9.32,["SpreadAngle"]={"V2",360,-360},["Enabled"]=false,["Acceleration"]={"V3",0,3,0},["LockedToPart"]=true,["Rate"]=10,["Rotation"]={"NR",-180,180},["Transparency"]={"NS",{{0,0,0},{0.34816,0.6625,0},{1,1,0}}},["LightEmission"]=0.3,["Texture"]="rbxassetid://11115266741",["Size"]={"NS",{{0,0,1},{0.1,0.80498,1},{0.2,1.2466,1},{0.3,1.6039,1},{0.4,1.9121,1},{0.5,2.1839,1},{0.6,2.4242,1},{0.7,2.6337,1},{0.8,2.8092,1},{0.9,2.9408,1},{1,3,1}}},["Squash"]={"NS",{{0,0,0},{1,0,0}}}}}}}}}},
        }

        local PLACE = {
            Stereo = { "floor", 5.91 }, Blackhole = { "root", 10 }, Heartbreak = { "floor", "half" },
            ["Galactic Pull"] = { "floor", "half" }, Cyberspace = { "root", 0 }, ["Glitter Bomb"] = { "root", 0 },
            ["Game Over"] = { "root", 2 }, Lightning = { "root", 0 }, Darkheart = { "body" }, Scorch = { "body" },
        }

        local live = {}

        local TweenService = game:GetService("TweenService")
        local BODY = {
            Scorch = { kind = "material", material = Enum.Material.Pebble, color = Color3.fromRGB(61, 63, 71), strip = true },
            Stone = { kind = "material", material = Enum.Material.Slate, color = Color3.fromRGB(99, 95, 98), strip = true },
            ["Gold Statue"] = { kind = "material", material = Enum.Material.Glass, color = Color3.fromRGB(255, 196, 64), strip = true },
            Fade = { kind = "fade", time = 1 },
            Ghost = { kind = "fade", time = 2.5, start = 0.5 },
            Shrink = { kind = "shrink", time = 3 },
            Blackhole = { kind = "pull", time = 4 },
        }
        for _, name in ipairs({ "Aurora Burst", "Northern Aurora Burst", "Cosmic Strike", "Deleted", "Game Over", "Glitter Bomb", "Heartbreak", "Paper Surprise", "Soul Grasp", "Stereo", "Cyberspace", "Galactic Pull", "Infinite Portal" }) do
            BODY[name] = { kind = "vanish" }
        end
        for _, name in ipairs({ "Stone", "Gold Statue", "Fade", "Ghost", "Shrink" }) do KILL_FX[name] = KILL_FX[name] or {} end

        local function reactBody(name, character, point)
            local rule = BODY[name]
            if not rule or not character or not flag("ke_body", true) then return end
            local root = character:FindFirstChild("HumanoidRootPart")
            local list = {}
            for _, d in ipairs(character:GetDescendants()) do
                if d:IsA("BasePart") then table.insert(list, d) end
            end
            local kind = rule.kind
            if kind == "material" then
                for _, d in ipairs(character:GetDescendants()) do
                    if d:IsA("BasePart") and d ~= root then
                        pcall(function() d.Material, d.Color = rule.material, rule.color end)
                    elseif rule.strip and (d:IsA("Clothing") or d:IsA("SurfaceAppearance") or d:IsA("Decal")) then
                        pcall(function() d:Destroy() end)
                    end
                end
            elseif kind == "vanish" then
                for _, part in ipairs(list) do
                    if part ~= root then pcall(function() part.Transparency = 1 end) end
                end
                for _, d in ipairs(character:GetDescendants()) do
                    if d:IsA("Decal") or d:IsA("Texture") then pcall(function() d.Transparency = 1 end) end
                end
            elseif kind == "fade" then
                for _, part in ipairs(list) do
                    if part ~= root then
                        pcall(function()
                            if rule.start then part.Transparency = math.max(part.Transparency, rule.start) end
                            TweenService:Create(part, TweenInfo.new(rule.time, Enum.EasingStyle.Linear), { Transparency = 1 }):Play()
                        end)
                    end
                end
            elseif kind == "shrink" or kind == "pull" then
                local goal = { Size = Vector3.new(0.05, 0.05, 0.05) }
                for _, part in ipairs(list) do
                    if part ~= root then
                        pcall(function()
                            for _, child in ipairs(part:GetChildren()) do
                                if child:IsA("SpecialMesh") then child:Destroy() end
                            end
                            local to = { Size = goal.Size }
                            if kind == "pull" and point then
                                part.Anchored = true
                                to.Position = point
                            end
                            TweenService:Create(part, TweenInfo.new(rule.time, Enum.EasingStyle.Linear), to):Play()
                            task.delay(rule.time, function() pcall(function() part.Transparency = 1 end) end)
                        end)
                    end
                end
            end
        end

        local BODY = {
            Scorch = { material = "Pebble", color = { 61, 63, 71 } },
            Lightning = { material = "Pebble", color = { 61, 63, 71 } },
            Darkheart = { material = "Pebble", color = { 123, 31, 162 } },
            Cyberspace = { material = "Neon", color = { 255, 255, 255 }, vanish = 1 },
            Blackhole = { shrink = 4 },
            Stereo = { vanish = 0.8 }, Deleted = { vanish = 0.6 }, ["Paper Surprise"] = { vanish = 0.8 },
            ["Glitter Bomb"] = { vanish = 0.8 }, ["Cosmic Strike"] = { vanish = 0.8 }, Heartbreak = { vanish = 0.8 },
            ["Game Over"] = { vanish = 1 }, ["Galactic Pull"] = { vanish = 1 }, ["Infinite Portal"] = { vanish = 1.5 },
        }

        local function reactBody(name, character, hole)
            local rule = BODY[name]
            if not rule or not character then return end
            local TweenService = game:GetService("TweenService")
            local parts = {}
            for _, d in ipairs(character:GetDescendants()) do
                if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then parts[#parts + 1] = d end
            end
            if rule.material then
                local color = Color3.fromRGB(table.unpack(rule.color))
                for _, p in ipairs(parts) do
                    p.Material = Enum.Material[rule.material]
                    p.Color = color
                end
            end
            if rule.shrink then
                local info = TweenInfo.new(rule.shrink, Enum.EasingStyle.Linear)
                for _, p in ipairs(parts) do
                    p.Anchored = true
                    for _, child in ipairs(p:GetChildren()) do
                        if child:IsA("SpecialMesh") then child:Destroy() end
                    end
                    pcall(function() TweenService:Create(p, info, { Size = Vector3.new(0.1, 0.1, 0.1), Position = hole }):Play() end)
                end
                task.delay(rule.shrink, function()
                    for _, p in ipairs(parts) do pcall(function() p.Transparency = 1 end) end
                end)
            end
            if rule.vanish then
                task.delay(rule.vanish, function()
                    for _, p in ipairs(parts) do
                        pcall(function() TweenService:Create(p, TweenInfo.new(0.6), { Transparency = 1 }):Play() end)
                    end
                end)
            end
        end

        local function decode(v)
            if type(v) ~= "table" then return v end
            local tag = v[1]
            if tag == "V3" then return Vector3.new(v[2], v[3], v[4]) end
            if tag == "V2" then return Vector2.new(v[2], v[3]) end
            if tag == "C3" then return Color3.new(v[2], v[3], v[4]) end
            if tag == "CF" then return CFrame.new(table.unpack(v, 2, 13)) end
            if tag == "NR" then return NumberRange.new(v[2], v[3]) end
            if tag == "E" then return Enum[v[2]][v[3]] end
            if tag == "CS" then
                local points = {}
                for _, k in ipairs(v[2]) do table.insert(points, ColorSequenceKeypoint.new(k[1], Color3.new(k[2], k[3], k[4]))) end
                return ColorSequence.new(points)
            end
            if tag == "NS" then
                local points = {}
                for _, k in ipairs(v[2]) do table.insert(points, NumberSequenceKeypoint.new(k[1], k[2], k[3] or 0)) end
                return NumberSequence.new(points)
            end
            return nil
        end

        local function build(tuple)
            local class, name, props = tuple[1], tuple[2], tuple[3]
            local okNew, inst = pcall(Instance.new, class)
            if not okNew then return nil end
            inst.Name = name
            local rec = { inst = inst, kids = {}, refs = tuple[5] }
            for key, value in pairs(props) do
                if key == "CFrame" and class == "Part" then
                    rec.cf = decode(value)
                else
                    pcall(function() inst[key] = decode(value) end)
                end
            end
            if class == "Part" then
                inst.Anchored, inst.CanCollide, inst.CanQuery, inst.CanTouch = true, false, false, false
                inst.Massless, inst.CastShadow = true, false
                if tuple[7] then inst.Transparency = 1 end
            end
            if tuple[4] then
                for key, value in pairs(tuple[4]) do inst:SetAttribute(key, value) end
            end
            for _, childTuple in ipairs(tuple[6] or {}) do
                local child = build(childTuple)
                if child then
                    child.inst.Parent = inst
                    table.insert(rec.kids, child)
                end
            end
            return rec
        end

        local function link(rec, tops)
            if rec.refs then
                for property, path in pairs(rec.refs) do
                    local node = tops[path[1]]
                    for i = 2, #path do node = node and node.kids[path[i]] end
                    if node then pcall(function() rec.inst[property] = node.inst end) end
                end
            end
            for _, kid in ipairs(rec.kids) do link(kid, tops) end
        end

        local function place(rec, origin)
            if rec.cf then rec.inst.CFrame = origin * rec.cf end
            for _, kid in ipairs(rec.kids) do place(kid, origin) end
        end

        local function fire(root)
            for _, d in ipairs(root:GetDescendants()) do
                if d:IsA("ParticleEmitter") then
                    local count, delay, length = d:GetAttribute("EmitCount"), d:GetAttribute("EmitDelay"), d:GetAttribute("EmitDuration")
                    if count then
                        if delay and delay > 0 then
                            task.delay(delay, function() if d.Parent then pcall(d.Emit, d, count) end end)
                        else
                            pcall(d.Emit, d, count)
                        end
                    end
                    if length then
                        d.Enabled = true
                        task.delay(length, function() if d.Parent then d.Enabled = false end end)
                    end
                end
            end
        end

        local function stopStreaming(root)
            for _, d in ipairs(root:GetDescendants()) do
                if d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") then d.Enabled = false end
            end
        end

        local function track(container, duration)
            table.insert(live, container)
            task.delay(math.max(duration - 1, 0.5), function()
                if container.Parent then stopStreaming(container) end
            end)
            Debris:AddItem(container, duration + 6)
        end

        local function floorY(position, character)
            local ignore = { workspace.CurrentCamera }
            if character then table.insert(ignore, character) end
            if LocalPlayer.Character then table.insert(ignore, LocalPlayer.Character) end
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            params.FilterDescendantsInstances = ignore
            local result = workspace:Raycast(position + Vector3.new(0, 1, 0), Vector3.new(0, -12, 0), params)
            return result and result.Position.Y or position.Y - 2.5
        end

        local function playKillEffect(name, position, character, duration)
            local nodes = KILL_FX[name]
            if not nodes or typeof(position) ~= "Vector3" then return end
            duration = duration or 4

            local root = character and character:FindFirstChild("HumanoidRootPart")
            local yaw = 0
            if root then
                position = root.Position
                local _, y = root.CFrame:ToEulerAnglesYXZ()
                yaw = y
            end
            local rule = PLACE[name] or { "floor", 0 }
            local mode, lift = rule[1], rule[2]

            local container = Instance.new("Folder")
            container.Name = "AsterKillFx"
            local tops = {}
            for _, tuple in ipairs(nodes) do
                local rec = build(tuple)
                if rec then table.insert(tops, rec) end
            end
            for _, rec in ipairs(tops) do link(rec, tops) end

            local base
            if mode == "floor" then
                base = Vector3.new(position.X, floorY(position, character), position.Z)
                if lift == "half" then
                    local first = tops[1] and tops[1].inst
                    lift = first and first:IsA("BasePart") and first.Size.Y / 2 or 0
                end
            else
                base = position
            end
            base = base + Vector3.new(0, tonumber(lift) or 0, 0)
            local origin = CFrame.new(base) * CFrame.Angles(0, yaw, 0)

            local anchor
            for _, rec in ipairs(tops) do
                local inst = rec.inst
                if inst:IsA("BasePart") then
                    place(rec, origin)
                    inst.Parent = container
                elseif mode == "body" and inst:IsA("ParticleEmitter") and character then

                    local count = 0
                    for _, part in ipairs(character:GetChildren()) do
                        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and count < 18 then
                            count += 1
                            local copy = inst:Clone()
                            copy.Parent = part
                            Debris:AddItem(copy, duration + 4)
                            task.delay(math.max(duration - 1, 0.5), function() if copy.Parent then copy.Enabled = false end end)
                            local emitCount = copy:GetAttribute("EmitCount")
                            if emitCount then pcall(copy.Emit, copy, emitCount) elseif name == "Scorch" then pcall(copy.Emit, copy, 4) end
                        end
                    end
                else
                    if not anchor then
                        anchor = Instance.new("Part")
                        anchor.Name = "Anchor"
                        anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
                        anchor.Transparency, anchor.Size, anchor.CFrame = 1, Vector3.new(1, 1, 1), origin
                        anchor.Parent = container
                    end
                    inst.Parent = anchor
                end
            end

            container.Parent = workspace
            fire(container)
            track(container, duration)
            pcall(reactBody, name, character, base)
            if character and flag("ke_body", true) then
                local look = root and root.CFrame.LookVector or Vector3.new(0, 0, -1)
                local ok, err = pcall(reactBody, name, character, position - look * 5 + Vector3.new(0, 10, 0))
                if not ok then warnf("kill effect body reaction failed:", err) end
            end
        end

        local function victimCharacter(player)
            return player and player.Character
        end

        table.insert(ShotEvents.kill, function(player, position)
            if not flag("ke_enabled", false) then return end
            local ok, err = pcall(playKillEffect, flag("ke_effect", "Darkheart"), position, victimCharacter(player), flag("ke_duration", 4))
            if not ok then warnf("kill effect failed:", err) end
        end)

        Actions.previewKillEffect = function()
            local cam = Camera()
            if not cam then return end
            local ok, err = pcall(playKillEffect, flag("ke_effect", "Darkheart"), cam.CFrame.Position + cam.CFrame.LookVector * 14 + Vector3.new(0, -2, 0), nil, flag("ke_duration", 4))
            if not ok then warnf("kill effect preview failed:", err) end
        end

        onUnload(function()
            Actions.previewKillEffect = noop
            for _, container in ipairs(live) do pcall(function() container:Destroy() end) end
            table.clear(live)
        end)
    end)()

    ;(function()
        local MUZZLE_FX = {
        	["Blue Black Hole"] = {{"Wave2",{Acceleration={"V3",0,0,0},Brightness=0.25,Color={"CS",{{0,0.294118,0.588235,1},{1,0.294118,0.588235,1}}},Drag=5,EmissionDirection={"EV","NormalId",1},Enabled=true,FlipbookFramerate={"NR",1,1},FlipbookLayout={"EV","ParticleFlipbookLayout",0},FlipbookMode={"EV","ParticleFlipbookMode",0},FlipbookStartRandom=false,Lifetime={"NR",0.3,0.3},LightEmission=1,LightInfluence=0,LockedToPart=true,Orientation={"EV","ParticleOrientation",3},Rate=50,RotSpeed={"NR",-720,720},Rotation={"NR",-720,720},Shape={"EV","ParticleEmitterShape",0},ShapeInOut={"EV","ParticleEmitterShapeInOut",0},ShapePartial=1,ShapeStyle={"EV","ParticleEmitterShapeStyle",0},Size={"NS",{{0,148.537,0},{1,99.619,0}}},Speed={"NR",0,1},SpreadAngle={"V2",180,180},Squash={"NS",{{0,0,0},{1,0,0}}},Texture="rbxassetid://1084996536",TimeScale=0.1,Transparency={"NS",{{0,1,0},{0.499,0.1,0},{1,1,0}}},VelocityInheritance=0,ZOffset=1}},
        		{"Flare",{Acceleration={"V3",0,0,0},Brightness=1,Color={"CS",{{0,0.294118,0.588235,1},{1,0.294118,0.588235,1}}},Drag=0,EmissionDirection={"EV","NormalId",1},Enabled=true,FlipbookFramerate={"NR",1,1},FlipbookLayout={"EV","ParticleFlipbookLayout",0},FlipbookMode={"EV","ParticleFlipbookMode",0},FlipbookStartRandom=false,Lifetime={"NR",1,1},LightEmission=1,LightInfluence=0,LockedToPart=true,Orientation={"EV","ParticleOrientation",0},Rate=16,RotSpeed={"NR",0,0},Rotation={"NR",0,0},Shape={"EV","ParticleEmitterShape",0},ShapeInOut={"EV","ParticleEmitterShapeInOut",0},ShapePartial=1,ShapeStyle={"EV","ParticleEmitterShapeStyle",0},Size={"NS",{{0,250,0},{1,250,0}}},Speed={"NR",0.01,0.01},SpreadAngle={"V2",0,0},Squash={"NS",{{0,0,0},{1,0,0}}},Texture="rbxassetid://1847258023",TimeScale=0.1,Transparency={"NS",{{0,1,0},{0.5,0.9,0},{1,1,0}}},VelocityInheritance=0,ZOffset=-8}},
        		{"Flare2",{Acceleration={"V3",0,0,0},Brightness=1,Color={"CS",{{0,0.294118,0.588235,1},{1,0.294118,0.588235,1}}},Drag=0,EmissionDirection={"EV","NormalId",1},Enabled=true,FlipbookFramerate={"NR",1,1},FlipbookLayout={"EV","ParticleFlipbookLayout",0},FlipbookMode={"EV","ParticleFlipbookMode",0},FlipbookStartRandom=false,Lifetime={"NR",1,1},LightEmission=1,LightInfluence=0,LockedToPart=false,Orientation={"EV","ParticleOrientation",0},Rate=10,RotSpeed={"NR",8000,8000},Rotation={"NR",0,0},Shape={"EV","ParticleEmitterShape",0},ShapeInOut={"EV","ParticleEmitterShapeInOut",0},ShapePartial=1,ShapeStyle={"EV","ParticleEmitterShapeStyle",0},Size={"NS",{{0,200,0},{1,200,0}}},Speed={"NR",0.001,0.001},SpreadAngle={"V2",360,360},Squash={"NS",{{0,0,0},{1,0,0}}},Texture="rbxassetid://1075864321",TimeScale=0.1,Transparency={"NS",{{0,1,0},{0.296211,0.9,0},{1,1,0}}},VelocityInheritance=0,ZOffset=0}},
        		{"Aura",{Acceleration={"V3",0,0,0},Brightness=1,Color={"CS",{{0,0.294118,0.588235,1},{1,0.294118,0.588235,1}}},Drag=0,EmissionDirection={"EV","NormalId",1},Enabled=true,FlipbookFramerate={"NR",1,1},FlipbookLayout={"EV","ParticleFlipbookLayout",0},FlipbookMode={"EV","ParticleFlipbookMode",0},FlipbookStartRandom=false,Lifetime={"NR",1,1.5},LightEmission=1,LightInfluence=0,LockedToPart=true,Orientation={"EV","ParticleOrientation",0},Rate=50,RotSpeed={"NR",250,500},Rotation={"NR",-180,180},Shape={"EV","ParticleEmitterShape",0},ShapeInOut={"EV","ParticleEmitterShapeInOut",0},ShapePartial=1,ShapeStyle={"EV","ParticleEmitterShapeStyle",0},Size={"NS",{{0,29.934,0},{1,1,0}}},Speed={"NR",0,0},SpreadAngle={"V2",0,0},Squash={"NS",{{0,0,0},{1,0,0}}},Texture="rbxassetid://1084996536",TimeScale=0.1,Transparency={"NS",{{0,1,0},{0.5,0.4,0},{1,1,0}}},VelocityInheritance=0,ZOffset=0}},
        		{"Aura",{Acceleration={"V3",0,0,0},Brightness=1,Color={"CS",{{0,0.294118,0.588235,1},{1,0.294118,0.588235,1}}},Drag=0,EmissionDirection={"EV","NormalId",1},Enabled=true,FlipbookFramerate={"NR",1,1},FlipbookLayout={"EV","ParticleFlipbookLayout",0},FlipbookMode={"EV","ParticleFlipbookMode",0},FlipbookStartRandom=false,Lifetime={"NR",1,2},LightEmission=1,LightInfluence=0,LockedToPart=true,Orientation={"EV","ParticleOrientation",0},Rate=50,RotSpeed={"NR",100,200},Rotation={"NR",-180,180},Shape={"EV","ParticleEmitterShape",0},ShapeInOut={"EV","ParticleEmitterShapeInOut",0},ShapePartial=1,ShapeStyle={"EV","ParticleEmitterShapeStyle",0},Size={"NS",{{0,44.1487,0},{1,1,0}}},Speed={"NR",0,0},SpreadAngle={"V2",0,0},Squash={"NS",{{0,0,0},{1,0,0}}},Texture="rbxassetid://1084965356",TimeScale=0.1,Transparency={"NS",{{0,1,0},{0.5,0.75,0},{1,1,0}}},VelocityInheritance=0,ZOffset=0}},
        		{"Wave",{Acceleration={"V3",0,0,0},Brightness=1,Color={"CS",{{0,0.294118,0.588235,1},{1,0.294118,0.588235,1}}},Drag=0,EmissionDirection={"EV","NormalId",1},Enabled=true,FlipbookFramerate={"NR",1,1},FlipbookLayout={"EV","ParticleFlipbookLayout",0},FlipbookMode={"EV","ParticleFlipbookMode",0},FlipbookStartRandom=false,Lifetime={"NR",1,1.5},LightEmission=1,LightInfluence=0,LockedToPart=true,Orientation={"EV","ParticleOrientation",0},Rate=20,RotSpeed={"NR",250,500},Rotation={"NR",-180,180},Shape={"EV","ParticleEmitterShape",0},ShapeInOut={"EV","ParticleEmitterShapeInOut",0},ShapePartial=1,ShapeStyle={"EV","ParticleEmitterShapeStyle",0},Size={"NS",{{0,98.8713,0},{1,1,0}}},Speed={"NR",0,0},SpreadAngle={"V2",0,0},Squash={"NS",{{0,0,0},{1,0,0}}},Texture="rbxassetid://1084996536",TimeScale=0.1,Transparency={"NS",{{0,1,0},{0.5,0.4,0},{1,1,0}}},VelocityInheritance=0,ZOffset=0}},
        		{"Wave",{Acceleration={"V3",0,0,0},Brightness=1,Color={"CS",{{0,0.294118,0.588235,1},{1,0.294118,0.588235,1}}},Drag=0,EmissionDirection={"EV","NormalId",1},Enabled=true,FlipbookFramerate={"NR",1,1},FlipbookLayout={"EV","ParticleFlipbookLayout",0},FlipbookMode={"EV","ParticleFlipbookMode",0},FlipbookStartRandom=false,Lifetime={"NR",1,2},LightEmission=1,LightInfluence=0,LockedToPart=true,Orientation={"EV","ParticleOrientation",0},Rate=20,RotSpeed={"NR",75,150},Rotation={"NR",-180,180},Shape={"EV","ParticleEmitterShape",0},ShapeInOut={"EV","ParticleEmitterShapeInOut",0},ShapePartial=1,ShapeStyle={"EV","ParticleEmitterShapeStyle",0},Size={"NS",{{0,107.448,0},{1,1,0}}},Speed={"NR",0,0},SpreadAngle={"V2",0,0},Squash={"NS",{{0,0,0},{1,0,0}}},Texture="rbxassetid://1084965356",TimeScale=0.1,Transparency={"NS",{{0,1,0},{0.5,0.75,0},{1,1,0}}},VelocityInheritance=0,ZOffset=0}},
        		{"HITPE",{Acceleration={"V3",0,0,0},Brightness=0.25,Color={"CS",{{0,0.294118,0.588235,1},{1,0.294118,0.588235,1}}},Drag=5,EmissionDirection={"EV","NormalId",1},Enabled=true,FlipbookFramerate={"NR",1,1},FlipbookLayout={"EV","ParticleFlipbookLayout",0},FlipbookMode={"EV","ParticleFlipbookMode",0},FlipbookStartRandom=false,Lifetime={"NR",0.3,0.3},LightEmission=1,LightInfluence=0,LockedToPart=true,Orientation={"EV","ParticleOrientation",3},Rate=30,RotSpeed={"NR",-720,720},Rotation={"NR",-720,720},Shape={"EV","ParticleEmitterShape",0},ShapeInOut={"EV","ParticleEmitterShapeInOut",0},ShapePartial=1,ShapeStyle={"EV","ParticleEmitterShapeStyle",0},Size={"NS",{{0,89.4061,0},{1,58.1735,0}}},Speed={"NR",0,1},SpreadAngle={"V2",180,180},Squash={"NS",{{0,0,0},{1,0,0}}},Texture="http://www.roblox.com/asset/?id=7015983157",TimeScale=0.1,Transparency={"NS",{{0,1,0},{0.499,0.1,0},{1,1,0}}},VelocityInheritance=0,ZOffset=1}},
        		{"Aura2",{Acceleration={"V3",0,0,0},Brightness=1,Color={"CS",{{0,0.294118,0.588235,1},{1,0.294118,0.588235,1}}},Drag=0,EmissionDirection={"EV","NormalId",1},Enabled=true,FlipbookFramerate={"NR",1,1},FlipbookLayout={"EV","ParticleFlipbookLayout",0},FlipbookMode={"EV","ParticleFlipbookMode",0},FlipbookStartRandom=false,Lifetime={"NR",5,5},LightEmission=0.8,LightInfluence=1,LockedToPart=true,Orientation={"EV","ParticleOrientation",0},Rate=7.5,RotSpeed={"NR",50,50},Rotation={"NR",-360,360},Shape={"EV","ParticleEmitterShape",0},ShapeInOut={"EV","ParticleEmitterShapeInOut",0},ShapePartial=1,ShapeStyle={"EV","ParticleEmitterShapeStyle",0},Size={"NS",{{0,35,0},{1,35,0}}},Speed={"NR",0,0},SpreadAngle={"V2",0,0},Squash={"NS",{{0,0,0},{1,0,0}}},Texture="rbxassetid://6479250779",TimeScale=1,Transparency={"NS",{{0,1,0},{0.4,0.1,0},{0.924107,0.367568,0.0126488},{1,1,0}}},VelocityInheritance=0,ZOffset=1}}},
        	["Gold Black Hole"] = {{"Wave2",{Acceleration={"V3",0,0,0},Brightness=0.25,Color={"CS",{{0,1,0.392157,0},{1,1,1,0.784314}}},Drag=5,EmissionDirection={"EV","NormalId",1},Enabled=true,FlipbookFramerate={"NR",1,1},FlipbookLayout={"EV","ParticleFlipbookLayout",0},FlipbookMode={"EV","ParticleFlipbookMode",0},FlipbookStartRandom=false,Lifetime={"NR",0.3,0.3},LightEmission=1,LightInfluence=0,LockedToPart=true,Orientation={"EV","ParticleOrientation",3},Rate=100,RotSpeed={"NR",-720,720},Rotation={"NR",-720,720},Shape={"EV","ParticleEmitterShape",0},ShapeInOut={"EV","ParticleEmitterShapeInOut",0},ShapePartial=1,ShapeStyle={"EV","ParticleEmitterShapeStyle",0},Size={"NS",{{0,148.537,0},{1,99.619,0}}},Speed={"NR",0,1},SpreadAngle={"V2",180,180},Squash={"NS",{{0,0,0},{1,0,0}}},Texture="rbxassetid://1084996536",TimeScale=0.1,Transparency={"NS",{{0,1,0},{0.499,0.1,0},{1,1,0}}},VelocityInheritance=0,ZOffset=1}},
        		{"Flare",{Acceleration={"V3",0,0,0},Brightness=2,Color={"CS",{{0,1,0.588235,0.196078},{1,1,0.588235,0.196078}}},Drag=0,EmissionDirection={"EV","NormalId",1},Enabled=true,FlipbookFramerate={"NR",1,1},FlipbookLayout={"EV","ParticleFlipbookLayout",0},FlipbookMode={"EV","ParticleFlipbookMode",0},FlipbookStartRandom=false,Lifetime={"NR",1,1},LightEmission=1,LightInfluence=0,LockedToPart=true,Orientation={"EV","ParticleOrientation",0},Rate=16,RotSpeed={"NR",0,0},Rotation={"NR",0,0},Shape={"EV","ParticleEmitterShape",0},ShapeInOut={"EV","ParticleEmitterShapeInOut",0},ShapePartial=1,ShapeStyle={"EV","ParticleEmitterShapeStyle",0},Size={"NS",{{0,250,0},{1,250,0}}},Speed={"NR",0.01,0.01},SpreadAngle={"V2",0,0},Squash={"NS",{{0,0,0},{1,0,0}}},Texture="rbxassetid://1847258023",TimeScale=0.1,Transparency={"NS",{{0,1,0},{0.5,0.9,0},{1,1,0}}},VelocityInheritance=0,ZOffset=-8}},
        		{"Flare2",{Acceleration={"V3",0,0,0},Brightness=2,Color={"CS",{{0,1,0.392157,0},{1,1,1,0.784314}}},Drag=0,EmissionDirection={"EV","NormalId",1},Enabled=true,FlipbookFramerate={"NR",1,1},FlipbookLayout={"EV","ParticleFlipbookLayout",0},FlipbookMode={"EV","ParticleFlipbookMode",0},FlipbookStartRandom=false,Lifetime={"NR",1,1},LightEmission=1,LightInfluence=0,LockedToPart=false,Orientation={"EV","ParticleOrientation",0},Rate=10,RotSpeed={"NR",8000,8000},Rotation={"NR",0,0},Shape={"EV","ParticleEmitterShape",0},ShapeInOut={"EV","ParticleEmitterShapeInOut",0},ShapePartial=1,ShapeStyle={"EV","ParticleEmitterShapeStyle",0},Size={"NS",{{0,200,0},{1,200,0}}},Speed={"NR",0.001,0.001},SpreadAngle={"V2",360,360},Squash={"NS",{{0,0,0},{1,0,0}}},Texture="rbxassetid://1075864321",TimeScale=0.1,Transparency={"NS",{{0,1,0},{0.296211,0.9,0},{1,1,0}}},VelocityInheritance=0,ZOffset=0}},
        		{"Wave",{Acceleration={"V3",0,0,0},Brightness=1,Color={"CS",{{0,1,0.392157,0},{1,1,1,0.784314}}},Drag=0,EmissionDirection={"EV","NormalId",1},Enabled=true,FlipbookFramerate={"NR",1,1},FlipbookLayout={"EV","ParticleFlipbookLayout",0},FlipbookMode={"EV","ParticleFlipbookMode",0},FlipbookStartRandom=false,Lifetime={"NR",1,1.5},LightEmission=1,LightInfluence=0,LockedToPart=true,Orientation={"EV","ParticleOrientation",0},Rate=50,RotSpeed={"NR",250,500},Rotation={"NR",-180,180},Shape={"EV","ParticleEmitterShape",0},ShapeInOut={"EV","ParticleEmitterShapeInOut",0},ShapePartial=1,ShapeStyle={"EV","ParticleEmitterShapeStyle",0},Size={"NS",{{0,98.8713,0},{1,1,0}}},Speed={"NR",0,0},SpreadAngle={"V2",0,0},Squash={"NS",{{0,0,0},{1,0,0}}},Texture="rbxassetid://1084996536",TimeScale=0.1,Transparency={"NS",{{0,1,0},{0.5,0.4,0},{1,1,0}}},VelocityInheritance=0,ZOffset=0}},
        		{"Wave",{Acceleration={"V3",0,0,0},Brightness=1,Color={"CS",{{0,1,0.392157,0},{1,1,1,0.784314}}},Drag=0,EmissionDirection={"EV","NormalId",1},Enabled=true,FlipbookFramerate={"NR",1,1},FlipbookLayout={"EV","ParticleFlipbookLayout",0},FlipbookMode={"EV","ParticleFlipbookMode",0},FlipbookStartRandom=false,Lifetime={"NR",1,2},LightEmission=1,LightInfluence=0,LockedToPart=true,Orientation={"EV","ParticleOrientation",0},Rate=20,RotSpeed={"NR",75,150},Rotation={"NR",-180,180},Shape={"EV","ParticleEmitterShape",0},ShapeInOut={"EV","ParticleEmitterShapeInOut",0},ShapePartial=1,ShapeStyle={"EV","ParticleEmitterShapeStyle",0},Size={"NS",{{0,107.448,0},{1,1,0}}},Speed={"NR",0,0},SpreadAngle={"V2",0,0},Squash={"NS",{{0,0,0},{1,0,0}}},Texture="rbxassetid://1084965356",TimeScale=0.1,Transparency={"NS",{{0,1,0},{0.5,0.75,0},{1,1,0}}},VelocityInheritance=0,ZOffset=0}},
        		{"HITPE",{Acceleration={"V3",0,0,0},Brightness=0.25,Color={"CS",{{0,1,0.392157,0},{1,1,1,0.784314}}},Drag=5,EmissionDirection={"EV","NormalId",1},Enabled=true,FlipbookFramerate={"NR",1,1},FlipbookLayout={"EV","ParticleFlipbookLayout",0},FlipbookMode={"EV","ParticleFlipbookMode",0},FlipbookStartRandom=false,Lifetime={"NR",0.3,0.3},LightEmission=1,LightInfluence=0,LockedToPart=true,Orientation={"EV","ParticleOrientation",3},Rate=30,RotSpeed={"NR",-720,720},Rotation={"NR",-720,720},Shape={"EV","ParticleEmitterShape",0},ShapeInOut={"EV","ParticleEmitterShapeInOut",0},ShapePartial=1,ShapeStyle={"EV","ParticleEmitterShapeStyle",0},Size={"NS",{{0,89.4061,0},{1,58.1735,0}}},Speed={"NR",0,1},SpreadAngle={"V2",180,180},Squash={"NS",{{0,0,0},{1,0,0}}},Texture="http://www.roblox.com/asset/?id=7015983157",TimeScale=0.1,Transparency={"NS",{{0,1,0},{0.499,0.1,0},{1,1,0}}},VelocityInheritance=0,ZOffset=1}},
        		{"Aura2",{Acceleration={"V3",0,0,0},Brightness=1,Color={"CS",{{0,1,0.784314,0.392157},{1,1,0.784314,0.392157}}},Drag=0,EmissionDirection={"EV","NormalId",1},Enabled=true,FlipbookFramerate={"NR",1,1},FlipbookLayout={"EV","ParticleFlipbookLayout",0},FlipbookMode={"EV","ParticleFlipbookMode",0},FlipbookStartRandom=false,Lifetime={"NR",5,5},LightEmission=0.8,LightInfluence=1,LockedToPart=true,Orientation={"EV","ParticleOrientation",0},Rate=7.5,RotSpeed={"NR",50,50},Rotation={"NR",-360,360},Shape={"EV","ParticleEmitterShape",0},ShapeInOut={"EV","ParticleEmitterShapeInOut",0},ShapePartial=1,ShapeStyle={"EV","ParticleEmitterShapeStyle",0},Size={"NS",{{0,35,0},{1,35,0}}},Speed={"NR",0,0},SpreadAngle={"V2",0,0},Squash={"NS",{{0,0,0},{1,0,0}}},Texture="rbxassetid://6479250779",TimeScale=1,Transparency={"NS",{{0,1,0},{0.4,0.1,0},{0.924107,0.367568,0.0126488},{1,1,0}}},VelocityInheritance=0,ZOffset=1}},
        		{"Aura",{Acceleration={"V3",0,0,0},Brightness=0.5,Color={"CS",{{0,1,0.588235,0.196078},{1,1,0.588235,0.196078}}},Drag=0,EmissionDirection={"EV","NormalId",1},Enabled=true,FlipbookFramerate={"NR",1,1},FlipbookLayout={"EV","ParticleFlipbookLayout",0},FlipbookMode={"EV","ParticleFlipbookMode",0},FlipbookStartRandom=false,Lifetime={"NR",1,1.5},LightEmission=1,LightInfluence=0,LockedToPart=true,Orientation={"EV","ParticleOrientation",0},Rate=50,RotSpeed={"NR",250,500},Rotation={"NR",-180,180},Shape={"EV","ParticleEmitterShape",0},ShapeInOut={"EV","ParticleEmitterShapeInOut",0},ShapePartial=1,ShapeStyle={"EV","ParticleEmitterShapeStyle",0},Size={"NS",{{0,29.934,0},{1,1,0}}},Speed={"NR",0,0},SpreadAngle={"V2",0,0},Squash={"NS",{{0,0,0},{1,0,0}}},Texture="rbxassetid://1084996536",TimeScale=0.1,Transparency={"NS",{{0,1,0},{0.5,0.4,0},{1,1,0}}},VelocityInheritance=0,ZOffset=0}}},
        	["Orange Black Hole"] = {{"Wave2",{Acceleration={"V3",0,0,0},Brightness=0.25,Color={"CS",{{0,1,0.392157,0.196078},{1,1,0.392157,0.196078}}},Drag=5,EmissionDirection={"EV","NormalId",1},Enabled=true,FlipbookFramerate={"NR",1,1},FlipbookLayout={"EV","ParticleFlipbookLayout",0},FlipbookMode={"EV","ParticleFlipbookMode",0},FlipbookStartRandom=false,Lifetime={"NR",0.3,0.3},LightEmission=1,LightInfluence=0,LockedToPart=true,Orientation={"EV","ParticleOrientation",3},Rate=50,RotSpeed={"NR",-720,720},Rotation={"NR",-720,720},Shape={"EV","ParticleEmitterShape",0},ShapeInOut={"EV","ParticleEmitterShapeInOut",0},ShapePartial=1,ShapeStyle={"EV","ParticleEmitterShapeStyle",0},Size={"NS",{{0,148.537,0},{1,99.619,0}}},Speed={"NR",0,1},SpreadAngle={"V2",180,180},Squash={"NS",{{0,0,0},{1,0,0}}},Texture="rbxassetid://1084996536",TimeScale=0.1,Transparency={"NS",{{0,1,0},{0.499,0.1,0},{1,1,0}}},VelocityInheritance=0,ZOffset=1}},
        		{"Flare",{Acceleration={"V3",0,0,0},Brightness=1,Color={"CS",{{0,1,0.392157,0.196078},{1,1,0.392157,0.196078}}},Drag=0,EmissionDirection={"EV","NormalId",1},Enabled=true,FlipbookFramerate={"NR",1,1},FlipbookLayout={"EV","ParticleFlipbookLayout",0},FlipbookMode={"EV","ParticleFlipbookMode",0},FlipbookStartRandom=false,Lifetime={"NR",1,1},LightEmission=1,LightInfluence=0,LockedToPart=true,Orientation={"EV","ParticleOrientation",0},Rate=16,RotSpeed={"NR",0,0},Rotation={"NR",0,0},Shape={"EV","ParticleEmitterShape",0},ShapeInOut={"EV","ParticleEmitterShapeInOut",0},ShapePartial=1,ShapeStyle={"EV","ParticleEmitterShapeStyle",0},Size={"NS",{{0,250,0},{1,250,0}}},Speed={"NR",0.01,0.01},SpreadAngle={"V2",0,0},Squash={"NS",{{0,0,0},{1,0,0}}},Texture="rbxassetid://1847258023",TimeScale=0.1,Transparency={"NS",{{0,1,0},{0.5,0.9,0},{1,1,0}}},VelocityInheritance=0,ZOffset=-8}},
        		{"Flare2",{Acceleration={"V3",0,0,0},Brightness=1,Color={"CS",{{0,1,0.392157,0.196078},{1,1,0.392157,0.196078}}},Drag=0,EmissionDirection={"EV","NormalId",1},Enabled=true,FlipbookFramerate={"NR",1,1},FlipbookLayout={"EV","ParticleFlipbookLayout",0},FlipbookMode={"EV","ParticleFlipbookMode",0},FlipbookStartRandom=false,Lifetime={"NR",1,1},LightEmission=1,LightInfluence=0,LockedToPart=false,Orientation={"EV","ParticleOrientation",0},Rate=10,RotSpeed={"NR",8000,8000},Rotation={"NR",0,0},Shape={"EV","ParticleEmitterShape",0},ShapeInOut={"EV","ParticleEmitterShapeInOut",0},ShapePartial=1,ShapeStyle={"EV","ParticleEmitterShapeStyle",0},Size={"NS",{{0,200,0},{1,200,0}}},Speed={"NR",0.001,0.001},SpreadAngle={"V2",360,360},Squash={"NS",{{0,0,0},{1,0,0}}},Texture="rbxassetid://1075864321",TimeScale=0.1,Transparency={"NS",{{0,1,0},{0.296211,0.9,0},{1,1,0}}},VelocityInheritance=0,ZOffset=0}},
        		{"Aura",{Acceleration={"V3",0,0,0},Brightness=1,Color={"CS",{{0,1,0.392157,0.196078},{1,1,0.392157,0.196078}}},Drag=0,EmissionDirection={"EV","NormalId",1},Enabled=true,FlipbookFramerate={"NR",1,1},FlipbookLayout={"EV","ParticleFlipbookLayout",0},FlipbookMode={"EV","ParticleFlipbookMode",0},FlipbookStartRandom=false,Lifetime={"NR",1,1.5},LightEmission=1,LightInfluence=0,LockedToPart=true,Orientation={"EV","ParticleOrientation",0},Rate=50,RotSpeed={"NR",250,500},Rotation={"NR",-180,180},Shape={"EV","ParticleEmitterShape",0},ShapeInOut={"EV","ParticleEmitterShapeInOut",0},ShapePartial=1,ShapeStyle={"EV","ParticleEmitterShapeStyle",0},Size={"NS",{{0,29.934,0},{1,1,0}}},Speed={"NR",0,0},SpreadAngle={"V2",0,0},Squash={"NS",{{0,0,0},{1,0,0}}},Texture="rbxassetid://1084996536",TimeScale=0.1,Transparency={"NS",{{0,1,0},{0.5,0.4,0},{1,1,0}}},VelocityInheritance=0,ZOffset=0}},
        		{"Aura",{Acceleration={"V3",0,0,0},Brightness=1,Color={"CS",{{0,1,0.392157,0.196078},{1,1,0.392157,0.196078}}},Drag=0,EmissionDirection={"EV","NormalId",1},Enabled=true,FlipbookFramerate={"NR",1,1},FlipbookLayout={"EV","ParticleFlipbookLayout",0},FlipbookMode={"EV","ParticleFlipbookMode",0},FlipbookStartRandom=false,Lifetime={"NR",1,2},LightEmission=1,LightInfluence=0,LockedToPart=true,Orientation={"EV","ParticleOrientation",0},Rate=50,RotSpeed={"NR",100,200},Rotation={"NR",-180,180},Shape={"EV","ParticleEmitterShape",0},ShapeInOut={"EV","ParticleEmitterShapeInOut",0},ShapePartial=1,ShapeStyle={"EV","ParticleEmitterShapeStyle",0},Size={"NS",{{0,44.1487,0},{1,1,0}}},Speed={"NR",0,0},SpreadAngle={"V2",0,0},Squash={"NS",{{0,0,0},{1,0,0}}},Texture="rbxassetid://1084965356",TimeScale=0.1,Transparency={"NS",{{0,1,0},{0.5,0.75,0},{1,1,0}}},VelocityInheritance=0,ZOffset=0}},
        		{"Wave",{Acceleration={"V3",0,0,0},Brightness=1,Color={"CS",{{0,1,0.392157,0.196078},{1,1,0.392157,0.196078}}},Drag=0,EmissionDirection={"EV","NormalId",1},Enabled=true,FlipbookFramerate={"NR",1,1},FlipbookLayout={"EV","ParticleFlipbookLayout",0},FlipbookMode={"EV","ParticleFlipbookMode",0},FlipbookStartRandom=false,Lifetime={"NR",1,1.5},LightEmission=1,LightInfluence=0,LockedToPart=true,Orientation={"EV","ParticleOrientation",0},Rate=20,RotSpeed={"NR",250,500},Rotation={"NR",-180,180},Shape={"EV","ParticleEmitterShape",0},ShapeInOut={"EV","ParticleEmitterShapeInOut",0},ShapePartial=1,ShapeStyle={"EV","ParticleEmitterShapeStyle",0},Size={"NS",{{0,98.8713,0},{1,1,0}}},Speed={"NR",0,0},SpreadAngle={"V2",0,0},Squash={"NS",{{0,0,0},{1,0,0}}},Texture="rbxassetid://1084996536",TimeScale=0.1,Transparency={"NS",{{0,1,0},{0.5,0.4,0},{1,1,0}}},VelocityInheritance=0,ZOffset=0}},
        		{"Wave",{Acceleration={"V3",0,0,0},Brightness=1,Color={"CS",{{0,1,0.392157,0.196078},{1,1,0.392157,0.196078}}},Drag=0,EmissionDirection={"EV","NormalId",1},Enabled=true,FlipbookFramerate={"NR",1,1},FlipbookLayout={"EV","ParticleFlipbookLayout",0},FlipbookMode={"EV","ParticleFlipbookMode",0},FlipbookStartRandom=false,Lifetime={"NR",1,2},LightEmission=1,LightInfluence=0,LockedToPart=true,Orientation={"EV","ParticleOrientation",0},Rate=20,RotSpeed={"NR",75,150},Rotation={"NR",-180,180},Shape={"EV","ParticleEmitterShape",0},ShapeInOut={"EV","ParticleEmitterShapeInOut",0},ShapePartial=1,ShapeStyle={"EV","ParticleEmitterShapeStyle",0},Size={"NS",{{0,107.448,0},{1,1,0}}},Speed={"NR",0,0},SpreadAngle={"V2",0,0},Squash={"NS",{{0,0,0},{1,0,0}}},Texture="rbxassetid://1084965356",TimeScale=0.1,Transparency={"NS",{{0,1,0},{0.5,0.75,0},{1,1,0}}},VelocityInheritance=0,ZOffset=0}},
        		{"HITPE",{Acceleration={"V3",0,0,0},Brightness=0.25,Color={"CS",{{0,1,0.392157,0.196078},{1,1,0.392157,0.196078}}},Drag=5,EmissionDirection={"EV","NormalId",1},Enabled=true,FlipbookFramerate={"NR",1,1},FlipbookLayout={"EV","ParticleFlipbookLayout",0},FlipbookMode={"EV","ParticleFlipbookMode",0},FlipbookStartRandom=false,Lifetime={"NR",0.3,0.3},LightEmission=1,LightInfluence=0,LockedToPart=true,Orientation={"EV","ParticleOrientation",3},Rate=30,RotSpeed={"NR",-720,720},Rotation={"NR",-720,720},Shape={"EV","ParticleEmitterShape",0},ShapeInOut={"EV","ParticleEmitterShapeInOut",0},ShapePartial=1,ShapeStyle={"EV","ParticleEmitterShapeStyle",0},Size={"NS",{{0,89.4061,0},{1,58.1735,0}}},Speed={"NR",0,1},SpreadAngle={"V2",180,180},Squash={"NS",{{0,0,0},{1,0,0}}},Texture="http://www.roblox.com/asset/?id=7015983157",TimeScale=0.1,Transparency={"NS",{{0,1,0},{0.499,0.1,0},{1,1,0}}},VelocityInheritance=0,ZOffset=1}},
        		{"Aura2",{Acceleration={"V3",0,0,0},Brightness=1,Color={"CS",{{0,1,0.392157,0.196078},{1,1,0.392157,0.196078}}},Drag=0,EmissionDirection={"EV","NormalId",1},Enabled=true,FlipbookFramerate={"NR",1,1},FlipbookLayout={"EV","ParticleFlipbookLayout",0},FlipbookMode={"EV","ParticleFlipbookMode",0},FlipbookStartRandom=false,Lifetime={"NR",5,5},LightEmission=0.8,LightInfluence=1,LockedToPart=true,Orientation={"EV","ParticleOrientation",0},Rate=7.5,RotSpeed={"NR",50,50},Rotation={"NR",-360,360},Shape={"EV","ParticleEmitterShape",0},ShapeInOut={"EV","ParticleEmitterShapeInOut",0},ShapePartial=1,ShapeStyle={"EV","ParticleEmitterShapeStyle",0},Size={"NS",{{0,35,0},{1,35,0}}},Speed={"NR",0,0},SpreadAngle={"V2",0,0},Squash={"NS",{{0,0,0},{1,0,0}}},Texture="rbxassetid://6479250779",TimeScale=1,Transparency={"NS",{{0,1,0},{0.4,0.1,0},{0.924107,0.367568,0.0126488},{1,1,0}}},VelocityInheritance=0,ZOffset=1}}},
        	["Purple Black Hole"] = {{"Wave2",{Acceleration={"V3",0,0,0},Brightness=0.25,Color={"CS",{{0,0.490196,0.294118,1},{1,0.490196,0.294118,1}}},Drag=5,EmissionDirection={"EV","NormalId",1},Enabled=true,FlipbookFramerate={"NR",1,1},FlipbookLayout={"EV","ParticleFlipbookLayout",0},FlipbookMode={"EV","ParticleFlipbookMode",0},FlipbookStartRandom=false,Lifetime={"NR",0.3,0.3},LightEmission=1,LightInfluence=0,LockedToPart=true,Orientation={"EV","ParticleOrientation",3},Rate=50,RotSpeed={"NR",-720,720},Rotation={"NR",-720,720},Shape={"EV","ParticleEmitterShape",0},ShapeInOut={"EV","ParticleEmitterShapeInOut",0},ShapePartial=1,ShapeStyle={"EV","ParticleEmitterShapeStyle",0},Size={"NS",{{0,148.537,0},{1,99.619,0}}},Speed={"NR",0,1},SpreadAngle={"V2",180,180},Squash={"NS",{{0,0,0},{1,0,0}}},Texture="rbxassetid://1084996536",TimeScale=0.1,Transparency={"NS",{{0,1,0},{0.499,0.1,0},{1,1,0}}},VelocityInheritance=0,ZOffset=1}},
        		{"Flare",{Acceleration={"V3",0,0,0},Brightness=1,Color={"CS",{{0,0.490196,0.294118,1},{1,0.490196,0.294118,1}}},Drag=0,EmissionDirection={"EV","NormalId",1},Enabled=true,FlipbookFramerate={"NR",1,1},FlipbookLayout={"EV","ParticleFlipbookLayout",0},FlipbookMode={"EV","ParticleFlipbookMode",0},FlipbookStartRandom=false,Lifetime={"NR",1,1},LightEmission=1,LightInfluence=0,LockedToPart=true,Orientation={"EV","ParticleOrientation",0},Rate=16,RotSpeed={"NR",0,0},Rotation={"NR",0,0},Shape={"EV","ParticleEmitterShape",0},ShapeInOut={"EV","ParticleEmitterShapeInOut",0},ShapePartial=1,ShapeStyle={"EV","ParticleEmitterShapeStyle",0},Size={"NS",{{0,250,0},{1,250,0}}},Speed={"NR",0.01,0.01},SpreadAngle={"V2",0,0},Squash={"NS",{{0,0,0},{1,0,0}}},Texture="rbxassetid://1847258023",TimeScale=0.1,Transparency={"NS",{{0,1,0},{0.5,0.9,0},{1,1,0}}},VelocityInheritance=0,ZOffset=-8}},
        		{"Flare2",{Acceleration={"V3",0,0,0},Brightness=1,Color={"CS",{{0,0.490196,0.294118,1},{1,0.490196,0.294118,1}}},Drag=0,EmissionDirection={"EV","NormalId",1},Enabled=true,FlipbookFramerate={"NR",1,1},FlipbookLayout={"EV","ParticleFlipbookLayout",0},FlipbookMode={"EV","ParticleFlipbookMode",0},FlipbookStartRandom=false,Lifetime={"NR",1,1},LightEmission=1,LightInfluence=0,LockedToPart=false,Orientation={"EV","ParticleOrientation",0},Rate=10,RotSpeed={"NR",8000,8000},Rotation={"NR",0,0},Shape={"EV","ParticleEmitterShape",0},ShapeInOut={"EV","ParticleEmitterShapeInOut",0},ShapePartial=1,ShapeStyle={"EV","ParticleEmitterShapeStyle",0},Size={"NS",{{0,200,0},{1,200,0}}},Speed={"NR",0.001,0.001},SpreadAngle={"V2",360,360},Squash={"NS",{{0,0,0},{1,0,0}}},Texture="rbxassetid://1075864321",TimeScale=0.1,Transparency={"NS",{{0,1,0},{0.296211,0.9,0},{1,1,0}}},VelocityInheritance=0,ZOffset=0}},
        		{"Aura",{Acceleration={"V3",0,0,0},Brightness=1,Color={"CS",{{0,0.490196,0.294118,1},{1,0.490196,0.294118,1}}},Drag=0,EmissionDirection={"EV","NormalId",1},Enabled=true,FlipbookFramerate={"NR",1,1},FlipbookLayout={"EV","ParticleFlipbookLayout",0},FlipbookMode={"EV","ParticleFlipbookMode",0},FlipbookStartRandom=false,Lifetime={"NR",1,1.5},LightEmission=1,LightInfluence=0,LockedToPart=true,Orientation={"EV","ParticleOrientation",0},Rate=50,RotSpeed={"NR",250,500},Rotation={"NR",-180,180},Shape={"EV","ParticleEmitterShape",0},ShapeInOut={"EV","ParticleEmitterShapeInOut",0},ShapePartial=1,ShapeStyle={"EV","ParticleEmitterShapeStyle",0},Size={"NS",{{0,29.934,0},{1,1,0}}},Speed={"NR",0,0},SpreadAngle={"V2",0,0},Squash={"NS",{{0,0,0},{1,0,0}}},Texture="rbxassetid://1084996536",TimeScale=0.1,Transparency={"NS",{{0,1,0},{0.5,0.4,0},{1,1,0}}},VelocityInheritance=0,ZOffset=0}},
        		{"Aura",{Acceleration={"V3",0,0,0},Brightness=1,Color={"CS",{{0,0.490196,0.294118,1},{1,0.490196,0.294118,1}}},Drag=0,EmissionDirection={"EV","NormalId",1},Enabled=true,FlipbookFramerate={"NR",1,1},FlipbookLayout={"EV","ParticleFlipbookLayout",0},FlipbookMode={"EV","ParticleFlipbookMode",0},FlipbookStartRandom=false,Lifetime={"NR",1,2},LightEmission=1,LightInfluence=0,LockedToPart=true,Orientation={"EV","ParticleOrientation",0},Rate=50,RotSpeed={"NR",100,200},Rotation={"NR",-180,180},Shape={"EV","ParticleEmitterShape",0},ShapeInOut={"EV","ParticleEmitterShapeInOut",0},ShapePartial=1,ShapeStyle={"EV","ParticleEmitterShapeStyle",0},Size={"NS",{{0,44.1487,0},{1,1,0}}},Speed={"NR",0,0},SpreadAngle={"V2",0,0},Squash={"NS",{{0,0,0},{1,0,0}}},Texture="rbxassetid://1084965356",TimeScale=0.1,Transparency={"NS",{{0,1,0},{0.5,0.75,0},{1,1,0}}},VelocityInheritance=0,ZOffset=0}},
        		{"Wave",{Acceleration={"V3",0,0,0},Brightness=1,Color={"CS",{{0,0.490196,0.294118,1},{1,0.490196,0.294118,1}}},Drag=0,EmissionDirection={"EV","NormalId",1},Enabled=true,FlipbookFramerate={"NR",1,1},FlipbookLayout={"EV","ParticleFlipbookLayout",0},FlipbookMode={"EV","ParticleFlipbookMode",0},FlipbookStartRandom=false,Lifetime={"NR",1,1.5},LightEmission=1,LightInfluence=0,LockedToPart=true,Orientation={"EV","ParticleOrientation",0},Rate=20,RotSpeed={"NR",250,500},Rotation={"NR",-180,180},Shape={"EV","ParticleEmitterShape",0},ShapeInOut={"EV","ParticleEmitterShapeInOut",0},ShapePartial=1,ShapeStyle={"EV","ParticleEmitterShapeStyle",0},Size={"NS",{{0,98.8713,0},{1,1,0}}},Speed={"NR",0,0},SpreadAngle={"V2",0,0},Squash={"NS",{{0,0,0},{1,0,0}}},Texture="rbxassetid://1084996536",TimeScale=0.1,Transparency={"NS",{{0,1,0},{0.5,0.4,0},{1,1,0}}},VelocityInheritance=0,ZOffset=0}},
        		{"Wave",{Acceleration={"V3",0,0,0},Brightness=1,Color={"CS",{{0,0.490196,0.294118,1},{1,0.490196,0.294118,1}}},Drag=0,EmissionDirection={"EV","NormalId",1},Enabled=true,FlipbookFramerate={"NR",1,1},FlipbookLayout={"EV","ParticleFlipbookLayout",0},FlipbookMode={"EV","ParticleFlipbookMode",0},FlipbookStartRandom=false,Lifetime={"NR",1,2},LightEmission=1,LightInfluence=0,LockedToPart=true,Orientation={"EV","ParticleOrientation",0},Rate=20,RotSpeed={"NR",75,150},Rotation={"NR",-180,180},Shape={"EV","ParticleEmitterShape",0},ShapeInOut={"EV","ParticleEmitterShapeInOut",0},ShapePartial=1,ShapeStyle={"EV","ParticleEmitterShapeStyle",0},Size={"NS",{{0,107.448,0},{1,1,0}}},Speed={"NR",0,0},SpreadAngle={"V2",0,0},Squash={"NS",{{0,0,0},{1,0,0}}},Texture="rbxassetid://1084965356",TimeScale=0.1,Transparency={"NS",{{0,1,0},{0.5,0.75,0},{1,1,0}}},VelocityInheritance=0,ZOffset=0}},
        		{"HITPE",{Acceleration={"V3",0,0,0},Brightness=0.25,Color={"CS",{{0,0.490196,0.294118,1},{1,0.490196,0.294118,1}}},Drag=5,EmissionDirection={"EV","NormalId",1},Enabled=true,FlipbookFramerate={"NR",1,1},FlipbookLayout={"EV","ParticleFlipbookLayout",0},FlipbookMode={"EV","ParticleFlipbookMode",0},FlipbookStartRandom=false,Lifetime={"NR",0.3,0.3},LightEmission=1,LightInfluence=0,LockedToPart=true,Orientation={"EV","ParticleOrientation",3},Rate=30,RotSpeed={"NR",-720,720},Rotation={"NR",-720,720},Shape={"EV","ParticleEmitterShape",0},ShapeInOut={"EV","ParticleEmitterShapeInOut",0},ShapePartial=1,ShapeStyle={"EV","ParticleEmitterShapeStyle",0},Size={"NS",{{0,89.4061,0},{1,58.1735,0}}},Speed={"NR",0,1},SpreadAngle={"V2",180,180},Squash={"NS",{{0,0,0},{1,0,0}}},Texture="http://www.roblox.com/asset/?id=7015983157",TimeScale=0.1,Transparency={"NS",{{0,1,0},{0.499,0.1,0},{1,1,0}}},VelocityInheritance=0,ZOffset=1}},
        		{"Aura2",{Acceleration={"V3",0,0,0},Brightness=1,Color={"CS",{{0,0.490196,0.294118,1},{1,0.490196,0.294118,1}}},Drag=0,EmissionDirection={"EV","NormalId",1},Enabled=true,FlipbookFramerate={"NR",1,1},FlipbookLayout={"EV","ParticleFlipbookLayout",0},FlipbookMode={"EV","ParticleFlipbookMode",0},FlipbookStartRandom=false,Lifetime={"NR",5,5},LightEmission=0.8,LightInfluence=1,LockedToPart=true,Orientation={"EV","ParticleOrientation",0},Rate=7.5,RotSpeed={"NR",50,50},Rotation={"NR",-360,360},Shape={"EV","ParticleEmitterShape",0},ShapeInOut={"EV","ParticleEmitterShapeInOut",0},ShapePartial=1,ShapeStyle={"EV","ParticleEmitterShapeStyle",0},Size={"NS",{{0,35,0},{1,35,0}}},Speed={"NR",0,0},SpreadAngle={"V2",0,0},Squash={"NS",{{0,0,0},{1,0,0}}},Texture="rbxassetid://6479250779",TimeScale=1,Transparency={"NS",{{0,1,0},{0.4,0.1,0},{0.924107,0.367568,0.0126488},{1,1,0}}},VelocityInheritance=0,ZOffset=1}}},
        	["Red Black Hole"] = {{"Wave2",{Acceleration={"V3",0,0,0},Brightness=0.25,Color={"CS",{{0,1,0.294118,0.294118},{1,1,0.294118,0.294118}}},Drag=5,EmissionDirection={"EV","NormalId",1},Enabled=true,FlipbookFramerate={"NR",1,1},FlipbookLayout={"EV","ParticleFlipbookLayout",0},FlipbookMode={"EV","ParticleFlipbookMode",0},FlipbookStartRandom=false,Lifetime={"NR",0.3,0.3},LightEmission=1,LightInfluence=0,LockedToPart=true,Orientation={"EV","ParticleOrientation",3},Rate=50,RotSpeed={"NR",-720,720},Rotation={"NR",-720,720},Shape={"EV","ParticleEmitterShape",0},ShapeInOut={"EV","ParticleEmitterShapeInOut",0},ShapePartial=1,ShapeStyle={"EV","ParticleEmitterShapeStyle",0},Size={"NS",{{0,148.537,0},{1,99.619,0}}},Speed={"NR",0,1},SpreadAngle={"V2",180,180},Squash={"NS",{{0,0,0},{1,0,0}}},Texture="rbxassetid://1084996536",TimeScale=0.1,Transparency={"NS",{{0,1,0},{0.499,0.1,0},{1,1,0}}},VelocityInheritance=0,ZOffset=1}},
        		{"Flare",{Acceleration={"V3",0,0,0},Brightness=1,Color={"CS",{{0,1,0,0},{1,1,0,0}}},Drag=0,EmissionDirection={"EV","NormalId",1},Enabled=true,FlipbookFramerate={"NR",1,1},FlipbookLayout={"EV","ParticleFlipbookLayout",0},FlipbookMode={"EV","ParticleFlipbookMode",0},FlipbookStartRandom=false,Lifetime={"NR",1,1},LightEmission=1,LightInfluence=0,LockedToPart=true,Orientation={"EV","ParticleOrientation",0},Rate=16,RotSpeed={"NR",0,0},Rotation={"NR",0,0},Shape={"EV","ParticleEmitterShape",0},ShapeInOut={"EV","ParticleEmitterShapeInOut",0},ShapePartial=1,ShapeStyle={"EV","ParticleEmitterShapeStyle",0},Size={"NS",{{0,250,0},{1,250,0}}},Speed={"NR",0.01,0.01},SpreadAngle={"V2",0,0},Squash={"NS",{{0,0,0},{1,0,0}}},Texture="rbxassetid://1847258023",TimeScale=0.1,Transparency={"NS",{{0,1,0},{0.5,0.9,0},{1,1,0}}},VelocityInheritance=0,ZOffset=-8}},
        		{"Flare2",{Acceleration={"V3",0,0,0},Brightness=1,Color={"CS",{{0,1,0,0},{1,1,0,0}}},Drag=0,EmissionDirection={"EV","NormalId",1},Enabled=true,FlipbookFramerate={"NR",1,1},FlipbookLayout={"EV","ParticleFlipbookLayout",0},FlipbookMode={"EV","ParticleFlipbookMode",0},FlipbookStartRandom=false,Lifetime={"NR",1,1},LightEmission=1,LightInfluence=0,LockedToPart=false,Orientation={"EV","ParticleOrientation",0},Rate=10,RotSpeed={"NR",8000,8000},Rotation={"NR",0,0},Shape={"EV","ParticleEmitterShape",0},ShapeInOut={"EV","ParticleEmitterShapeInOut",0},ShapePartial=1,ShapeStyle={"EV","ParticleEmitterShapeStyle",0},Size={"NS",{{0,200,0},{1,200,0}}},Speed={"NR",0.001,0.001},SpreadAngle={"V2",360,360},Squash={"NS",{{0,0,0},{1,0,0}}},Texture="rbxassetid://1075864321",TimeScale=0.1,Transparency={"NS",{{0,1,0},{0.296211,0.9,0},{1,1,0}}},VelocityInheritance=0,ZOffset=0}},
        		{"Wave",{Acceleration={"V3",0,0,0},Brightness=1,Color={"CS",{{0,1,0.294118,0.294118},{1,1,0.294118,0.294118}}},Drag=0,EmissionDirection={"EV","NormalId",1},Enabled=true,FlipbookFramerate={"NR",1,1},FlipbookLayout={"EV","ParticleFlipbookLayout",0},FlipbookMode={"EV","ParticleFlipbookMode",0},FlipbookStartRandom=false,Lifetime={"NR",1,1.5},LightEmission=1,LightInfluence=0,LockedToPart=true,Orientation={"EV","ParticleOrientation",0},Rate=20,RotSpeed={"NR",250,500},Rotation={"NR",-180,180},Shape={"EV","ParticleEmitterShape",0},ShapeInOut={"EV","ParticleEmitterShapeInOut",0},ShapePartial=1,ShapeStyle={"EV","ParticleEmitterShapeStyle",0},Size={"NS",{{0,98.8713,0},{1,1,0}}},Speed={"NR",0,0},SpreadAngle={"V2",0,0},Squash={"NS",{{0,0,0},{1,0,0}}},Texture="rbxassetid://1084996536",TimeScale=0.1,Transparency={"NS",{{0,1,0},{0.5,0.4,0},{1,1,0}}},VelocityInheritance=0,ZOffset=0}},
        		{"Wave",{Acceleration={"V3",0,0,0},Brightness=1,Color={"CS",{{0,1,0.294118,0.294118},{1,1,0.294118,0.294118}}},Drag=0,EmissionDirection={"EV","NormalId",1},Enabled=true,FlipbookFramerate={"NR",1,1},FlipbookLayout={"EV","ParticleFlipbookLayout",0},FlipbookMode={"EV","ParticleFlipbookMode",0},FlipbookStartRandom=false,Lifetime={"NR",1,2},LightEmission=1,LightInfluence=0,LockedToPart=true,Orientation={"EV","ParticleOrientation",0},Rate=20,RotSpeed={"NR",75,150},Rotation={"NR",-180,180},Shape={"EV","ParticleEmitterShape",0},ShapeInOut={"EV","ParticleEmitterShapeInOut",0},ShapePartial=1,ShapeStyle={"EV","ParticleEmitterShapeStyle",0},Size={"NS",{{0,107.448,0},{1,1,0}}},Speed={"NR",0,0},SpreadAngle={"V2",0,0},Squash={"NS",{{0,0,0},{1,0,0}}},Texture="rbxassetid://1084965356",TimeScale=0.1,Transparency={"NS",{{0,1,0},{0.5,0.75,0},{1,1,0}}},VelocityInheritance=0,ZOffset=0}},
        		{"HITPE",{Acceleration={"V3",0,0,0},Brightness=0.25,Color={"CS",{{0,1,0.294118,0.294118},{1,1,0.294118,0.294118}}},Drag=5,EmissionDirection={"EV","NormalId",1},Enabled=true,FlipbookFramerate={"NR",1,1},FlipbookLayout={"EV","ParticleFlipbookLayout",0},FlipbookMode={"EV","ParticleFlipbookMode",0},FlipbookStartRandom=false,Lifetime={"NR",0.3,0.3},LightEmission=1,LightInfluence=0,LockedToPart=true,Orientation={"EV","ParticleOrientation",3},Rate=30,RotSpeed={"NR",-720,720},Rotation={"NR",-720,720},Shape={"EV","ParticleEmitterShape",0},ShapeInOut={"EV","ParticleEmitterShapeInOut",0},ShapePartial=1,ShapeStyle={"EV","ParticleEmitterShapeStyle",0},Size={"NS",{{0,89.4061,0},{1,58.1735,0}}},Speed={"NR",0,1},SpreadAngle={"V2",180,180},Squash={"NS",{{0,0,0},{1,0,0}}},Texture="http://www.roblox.com/asset/?id=7015983157",TimeScale=0.1,Transparency={"NS",{{0,1,0},{0.499,0.1,0},{1,1,0}}},VelocityInheritance=0,ZOffset=1}},
        		{"Aura2",{Acceleration={"V3",0,0,0},Brightness=1,Color={"CS",{{0,1,0.294118,0.294118},{1,1,0.294118,0.294118}}},Drag=0,EmissionDirection={"EV","NormalId",1},Enabled=true,FlipbookFramerate={"NR",1,1},FlipbookLayout={"EV","ParticleFlipbookLayout",0},FlipbookMode={"EV","ParticleFlipbookMode",0},FlipbookStartRandom=false,Lifetime={"NR",5,5},LightEmission=0.8,LightInfluence=1,LockedToPart=true,Orientation={"EV","ParticleOrientation",0},Rate=7.5,RotSpeed={"NR",50,50},Rotation={"NR",-360,360},Shape={"EV","ParticleEmitterShape",0},ShapeInOut={"EV","ParticleEmitterShapeInOut",0},ShapePartial=1,ShapeStyle={"EV","ParticleEmitterShapeStyle",0},Size={"NS",{{0,35,0},{1,35,0}}},Speed={"NR",0,0},SpreadAngle={"V2",0,0},Squash={"NS",{{0,0,0},{1,0,0}}},Texture="rbxassetid://6479250779",TimeScale=1,Transparency={"NS",{{0,1,0},{0.4,0.1,0},{0.924107,0.367568,0.0126488},{1,1,0}}},VelocityInheritance=0,ZOffset=1}},
        		{"Aura",{Acceleration={"V3",0,0,0},Brightness=1,Color={"CS",{{0,1,0.294118,0.294118},{1,1,0.294118,0.294118}}},Drag=0,EmissionDirection={"EV","NormalId",1},Enabled=true,FlipbookFramerate={"NR",1,1},FlipbookLayout={"EV","ParticleFlipbookLayout",0},FlipbookMode={"EV","ParticleFlipbookMode",0},FlipbookStartRandom=false,Lifetime={"NR",1,1.5},LightEmission=1,LightInfluence=0,LockedToPart=true,Orientation={"EV","ParticleOrientation",0},Rate=50,RotSpeed={"NR",250,500},Rotation={"NR",-180,180},Shape={"EV","ParticleEmitterShape",0},ShapeInOut={"EV","ParticleEmitterShapeInOut",0},ShapePartial=1,ShapeStyle={"EV","ParticleEmitterShapeStyle",0},Size={"NS",{{0,29.934,0},{1,1,0}}},Speed={"NR",0,0},SpreadAngle={"V2",0,0},Squash={"NS",{{0,0,0},{1,0,0}}},Texture="rbxassetid://1084996536",TimeScale=0.1,Transparency={"NS",{{0,1,0},{0.5,0.4,0},{1,1,0}}},VelocityInheritance=0,ZOffset=0}},
        		{"Aura",{Acceleration={"V3",0,0,0},Brightness=1,Color={"CS",{{0,1,0.294118,0.294118},{1,1,0.294118,0.294118}}},Drag=0,EmissionDirection={"EV","NormalId",1},Enabled=true,FlipbookFramerate={"NR",1,1},FlipbookLayout={"EV","ParticleFlipbookLayout",0},FlipbookMode={"EV","ParticleFlipbookMode",0},FlipbookStartRandom=false,Lifetime={"NR",1,2},LightEmission=1,LightInfluence=0,LockedToPart=true,Orientation={"EV","ParticleOrientation",0},Rate=50,RotSpeed={"NR",100,200},Rotation={"NR",-180,180},Shape={"EV","ParticleEmitterShape",0},ShapeInOut={"EV","ParticleEmitterShapeInOut",0},ShapePartial=1,ShapeStyle={"EV","ParticleEmitterShapeStyle",0},Size={"NS",{{0,44.1487,0},{1,1,0}}},Speed={"NR",0,0},SpreadAngle={"V2",0,0},Squash={"NS",{{0,0,0},{1,0,0}}},Texture="rbxassetid://1084965356",TimeScale=0.1,Transparency={"NS",{{0,1,0},{0.5,0.75,0},{1,1,0}}},VelocityInheritance=0,ZOffset=0}},
        		{"ParticleEmitter",{Acceleration={"V3",0,0,0},Brightness=0.125,Color={"CS",{{0,1,0.294118,0.294118},{1,1,0.294118,0.294118}}},Drag=0,EmissionDirection={"EV","NormalId",1},Enabled=true,FlipbookFramerate={"NR",1,1},FlipbookLayout={"EV","ParticleFlipbookLayout",0},FlipbookMode={"EV","ParticleFlipbookMode",0},FlipbookStartRandom=false,Lifetime={"NR",0.128,0.128},LightEmission=1,LightInfluence=0,LockedToPart=true,Orientation={"EV","ParticleOrientation",0},Rate=100,RotSpeed={"NR",25,25},Rotation={"NR",-360,360},Shape={"EV","ParticleEmitterShape",0},ShapeInOut={"EV","ParticleEmitterShapeInOut",0},ShapePartial=1,ShapeStyle={"EV","ParticleEmitterShapeStyle",0},Size={"NS",{{0,80.1872,0.600144},{1,60.9557,0}}},Speed={"NR",0,0},SpreadAngle={"V2",0,0},Squash={"NS",{{0,0.75,0},{1,0.75,0}}},Texture="http://www.roblox.com/asset/?id=7015186994",TimeScale=0.1,Transparency={"NS",{{0,1,0},{0.5,0,0},{1,1,0}}},VelocityInheritance=0,ZOffset=1.5}}},
        	["White Black Hole"] = {{"Wave2",{Acceleration={"V3",0,0,0},Brightness=0.25,Color={"CS",{{0,1,1,1},{1,1,1,1}}},Drag=5,EmissionDirection={"EV","NormalId",1},Enabled=true,FlipbookFramerate={"NR",1,1},FlipbookLayout={"EV","ParticleFlipbookLayout",0},FlipbookMode={"EV","ParticleFlipbookMode",0},FlipbookStartRandom=false,Lifetime={"NR",0.3,0.3},LightEmission=1,LightInfluence=0,LockedToPart=true,Orientation={"EV","ParticleOrientation",3},Rate=100,RotSpeed={"NR",-720,720},Rotation={"NR",-720,720},Shape={"EV","ParticleEmitterShape",0},ShapeInOut={"EV","ParticleEmitterShapeInOut",0},ShapePartial=1,ShapeStyle={"EV","ParticleEmitterShapeStyle",0},Size={"NS",{{0,148.537,0},{1,99.619,0}}},Speed={"NR",0,1},SpreadAngle={"V2",180,180},Squash={"NS",{{0,0,0},{1,0,0}}},Texture="rbxassetid://1084996536",TimeScale=0.1,Transparency={"NS",{{0,1,0},{0.499,0.1,0},{1,1,0}}},VelocityInheritance=0,ZOffset=1}},
        		{"Flare",{Acceleration={"V3",0,0,0},Brightness=1,Color={"CS",{{0,1,1,1},{1,1,1,1}}},Drag=0,EmissionDirection={"EV","NormalId",1},Enabled=true,FlipbookFramerate={"NR",1,1},FlipbookLayout={"EV","ParticleFlipbookLayout",0},FlipbookMode={"EV","ParticleFlipbookMode",0},FlipbookStartRandom=false,Lifetime={"NR",1,1},LightEmission=1,LightInfluence=0,LockedToPart=true,Orientation={"EV","ParticleOrientation",0},Rate=16,RotSpeed={"NR",0,0},Rotation={"NR",0,0},Shape={"EV","ParticleEmitterShape",0},ShapeInOut={"EV","ParticleEmitterShapeInOut",0},ShapePartial=1,ShapeStyle={"EV","ParticleEmitterShapeStyle",0},Size={"NS",{{0,250,0},{1,250,0}}},Speed={"NR",0.01,0.01},SpreadAngle={"V2",0,0},Squash={"NS",{{0,0,0},{1,0,0}}},Texture="rbxassetid://1847258023",TimeScale=0.1,Transparency={"NS",{{0,1,0},{0.5,0.9,0},{1,1,0}}},VelocityInheritance=0,ZOffset=-8}},
        		{"Flare2",{Acceleration={"V3",0,0,0},Brightness=1,Color={"CS",{{0,1,1,1},{1,1,1,1}}},Drag=0,EmissionDirection={"EV","NormalId",1},Enabled=true,FlipbookFramerate={"NR",1,1},FlipbookLayout={"EV","ParticleFlipbookLayout",0},FlipbookMode={"EV","ParticleFlipbookMode",0},FlipbookStartRandom=false,Lifetime={"NR",1,1},LightEmission=1,LightInfluence=0,LockedToPart=false,Orientation={"EV","ParticleOrientation",0},Rate=10,RotSpeed={"NR",8000,8000},Rotation={"NR",0,0},Shape={"EV","ParticleEmitterShape",0},ShapeInOut={"EV","ParticleEmitterShapeInOut",0},ShapePartial=1,ShapeStyle={"EV","ParticleEmitterShapeStyle",0},Size={"NS",{{0,200,0},{1,200,0}}},Speed={"NR",0.001,0.001},SpreadAngle={"V2",360,360},Squash={"NS",{{0,0,0},{1,0,0}}},Texture="rbxassetid://1075864321",TimeScale=0.1,Transparency={"NS",{{0,1,0},{0.296211,0.9,0},{1,1,0}}},VelocityInheritance=0,ZOffset=0}},
        		{"Wave",{Acceleration={"V3",0,0,0},Brightness=0.5,Color={"CS",{{0,1,1,1},{1,1,1,1}}},Drag=0,EmissionDirection={"EV","NormalId",1},Enabled=true,FlipbookFramerate={"NR",1,1},FlipbookLayout={"EV","ParticleFlipbookLayout",0},FlipbookMode={"EV","ParticleFlipbookMode",0},FlipbookStartRandom=false,Lifetime={"NR",1,1.5},LightEmission=1,LightInfluence=0,LockedToPart=true,Orientation={"EV","ParticleOrientation",0},Rate=50,RotSpeed={"NR",250,500},Rotation={"NR",-180,180},Shape={"EV","ParticleEmitterShape",0},ShapeInOut={"EV","ParticleEmitterShapeInOut",0},ShapePartial=1,ShapeStyle={"EV","ParticleEmitterShapeStyle",0},Size={"NS",{{0,98.8713,0},{1,1,0}}},Speed={"NR",0,0},SpreadAngle={"V2",0,0},Squash={"NS",{{0,0,0},{1,0,0}}},Texture="rbxassetid://1084996536",TimeScale=0.1,Transparency={"NS",{{0,1,0},{0.5,0.4,0},{1,1,0}}},VelocityInheritance=0,ZOffset=0}},
        		{"Wave",{Acceleration={"V3",0,0,0},Brightness=0.5,Color={"CS",{{0,1,1,1},{1,1,1,1}}},Drag=0,EmissionDirection={"EV","NormalId",1},Enabled=true,FlipbookFramerate={"NR",1,1},FlipbookLayout={"EV","ParticleFlipbookLayout",0},FlipbookMode={"EV","ParticleFlipbookMode",0},FlipbookStartRandom=false,Lifetime={"NR",1,2},LightEmission=1,LightInfluence=0,LockedToPart=true,Orientation={"EV","ParticleOrientation",0},Rate=20,RotSpeed={"NR",75,150},Rotation={"NR",-180,180},Shape={"EV","ParticleEmitterShape",0},ShapeInOut={"EV","ParticleEmitterShapeInOut",0},ShapePartial=1,ShapeStyle={"EV","ParticleEmitterShapeStyle",0},Size={"NS",{{0,107.448,0},{1,1,0}}},Speed={"NR",0,0},SpreadAngle={"V2",0,0},Squash={"NS",{{0,0,0},{1,0,0}}},Texture="rbxassetid://1084965356",TimeScale=0.1,Transparency={"NS",{{0,1,0},{0.5,0.75,0},{1,1,0}}},VelocityInheritance=0,ZOffset=0}},
        		{"HITPE",{Acceleration={"V3",0,0,0},Brightness=0.25,Color={"CS",{{0,1,1,1},{1,1,1,1}}},Drag=5,EmissionDirection={"EV","NormalId",1},Enabled=true,FlipbookFramerate={"NR",1,1},FlipbookLayout={"EV","ParticleFlipbookLayout",0},FlipbookMode={"EV","ParticleFlipbookMode",0},FlipbookStartRandom=false,Lifetime={"NR",0.3,0.3},LightEmission=1,LightInfluence=0,LockedToPart=true,Orientation={"EV","ParticleOrientation",3},Rate=30,RotSpeed={"NR",-720,720},Rotation={"NR",-720,720},Shape={"EV","ParticleEmitterShape",0},ShapeInOut={"EV","ParticleEmitterShapeInOut",0},ShapePartial=1,ShapeStyle={"EV","ParticleEmitterShapeStyle",0},Size={"NS",{{0,89.4061,0},{1,58.1735,0}}},Speed={"NR",0,1},SpreadAngle={"V2",180,180},Squash={"NS",{{0,0,0},{1,0,0}}},Texture="http://www.roblox.com/asset/?id=7015983157",TimeScale=0.1,Transparency={"NS",{{0,1,0},{0.499,0.1,0},{1,1,0}}},VelocityInheritance=0,ZOffset=1}},
        		{"Aura2",{Acceleration={"V3",0,0,0},Brightness=1,Color={"CS",{{0,1,1,1},{1,1,1,1}}},Drag=0,EmissionDirection={"EV","NormalId",1},Enabled=true,FlipbookFramerate={"NR",1,1},FlipbookLayout={"EV","ParticleFlipbookLayout",0},FlipbookMode={"EV","ParticleFlipbookMode",0},FlipbookStartRandom=false,Lifetime={"NR",5,5},LightEmission=0.8,LightInfluence=1,LockedToPart=true,Orientation={"EV","ParticleOrientation",0},Rate=7.5,RotSpeed={"NR",50,50},Rotation={"NR",-360,360},Shape={"EV","ParticleEmitterShape",0},ShapeInOut={"EV","ParticleEmitterShapeInOut",0},ShapePartial=1,ShapeStyle={"EV","ParticleEmitterShapeStyle",0},Size={"NS",{{0,35,0},{1,35,0}}},Speed={"NR",0,0},SpreadAngle={"V2",0,0},Squash={"NS",{{0,0,0},{1,0,0}}},Texture="rbxassetid://6479250779",TimeScale=1,Transparency={"NS",{{0,1,0},{0.4,0.1,0},{0.924107,0.367568,0.0126488},{1,1,0}}},VelocityInheritance=0,ZOffset=1}},
        		{"Aura",{Acceleration={"V3",0,0,0},Brightness=0.5,Color={"CS",{{0,1,1,1},{1,1,1,1}}},Drag=0,EmissionDirection={"EV","NormalId",1},Enabled=true,FlipbookFramerate={"NR",1,1},FlipbookLayout={"EV","ParticleFlipbookLayout",0},FlipbookMode={"EV","ParticleFlipbookMode",0},FlipbookStartRandom=false,Lifetime={"NR",1,1.5},LightEmission=1,LightInfluence=0,LockedToPart=true,Orientation={"EV","ParticleOrientation",0},Rate=50,RotSpeed={"NR",250,500},Rotation={"NR",-180,180},Shape={"EV","ParticleEmitterShape",0},ShapeInOut={"EV","ParticleEmitterShapeInOut",0},ShapePartial=1,ShapeStyle={"EV","ParticleEmitterShapeStyle",0},Size={"NS",{{0,29.934,0},{1,1,0}}},Speed={"NR",0,0},SpreadAngle={"V2",0,0},Squash={"NS",{{0,0,0},{1,0,0}}},Texture="rbxassetid://1084996536",TimeScale=0.1,Transparency={"NS",{{0,1,0},{0.5,0.4,0},{1,1,0}}},VelocityInheritance=0,ZOffset=0}}},
        }

        local ENUM_FOR = {}
        local bag, built, lastKey, lastMuzzle = newBag(), {}, nil, nil
        local flashToken = 0

        local function decode(v)
            if type(v) ~= "table" then return v end
            local tag = v[1]
            if tag == "V3" then return Vector3.new(v[2], v[3], v[4]) end
            if tag == "V2" then return Vector2.new(v[2], v[3]) end
            if tag == "NR" then return NumberRange.new(v[2], v[3]) end
            if tag == "EV" then return Enum[v[2]]:FromValue(v[3]) end
            return nil
        end

        local function settings()
            return {
                effect = flag("mz_effect", "Purple Black Hole"),
                mode = flag("mz_mode", "While equipped"),
                scale = flag("mz_size", 5) / 100,
                alpha = flag("mz_alpha", 0),
                roll = flag("mz_roll", 0),
                custom = flag("mz_custom", false),
                color = (Options.mz_color and typeof(Options.mz_color.Value) == "Color3") and Options.mz_color.Value or Color3.fromRGB(255, 80, 80),
                x = flag("mz_x", 0), y = flag("mz_y", 0), z = flag("mz_z", 0),
                rx = flag("mz_rx", 0), ry = flag("mz_ry", 0), rz = flag("mz_rz", 0),
            }
        end

        local function keyOf(s)
            return table.concat({ s.effect, s.mode, s.scale, s.alpha, s.roll, tostring(s.custom), tostring(s.color), s.x, s.y, s.z, s.rx, s.ry, s.rz }, "|")
        end

        local function heldMuzzle()
            local char = LocalPlayer.Character
            local tool = char and char:FindFirstChildOfClass("Tool")
            if not tool then return nil end
            local muzzle = tool:FindFirstChild("Muzzle", true)
            if muzzle and muzzle:IsA("BasePart") then return muzzle end
            local handle = tool:FindFirstChild("Handle")
            if handle and handle:IsA("BasePart") then return handle end
            return nil
        end

        local function recolor(r, g, b, color)
            local luma = 0.299 * r + 0.587 * g + 0.114 * b
            if luma < 0.12 then return Color3.new(r, g, b) end
            if luma > 0.92 then return color:Lerp(Color3.new(1, 1, 1), 0.5) end
            return color
        end

        local function makeEmitter(def, s)
            local emitter = Instance.new("ParticleEmitter")
            emitter.Name = def[1]
            local k = s.scale
            for key, value in pairs(def[2]) do
                pcall(function()
                    if type(value) == "table" and value[1] == "CS" then
                        local points = {}
                        for _, p in ipairs(value[2]) do
                            local c = s.custom and recolor(p[2], p[3], p[4], s.color) or Color3.new(p[2], p[3], p[4])
                            table.insert(points, ColorSequenceKeypoint.new(p[1], c))
                        end
                        emitter.Color = ColorSequence.new(points)
                    elseif type(value) == "table" and value[1] == "NS" then
                        local points = {}
                        for _, p in ipairs(value[2]) do
                            local v, env = p[2], p[3] or 0
                            if key == "Size" then v, env = v * k, env * k end
                            if key == "Transparency" and s.alpha > 0 then v = v + (1 - v) * s.alpha env = 0 end
                            table.insert(points, NumberSequenceKeypoint.new(p[1], math.clamp(v, key == "Transparency" and 0 or -1e6, key == "Transparency" and 1 or 1e6), env))
                        end
                        emitter[key] = NumberSequence.new(points)
                    elseif key == "Speed" then
                        emitter.Speed = NumberRange.new(value[2] * k, value[3] * k)
                    elseif key == "Acceleration" then
                        emitter.Acceleration = Vector3.new(value[2] * k, value[3] * k, value[4] * k)
                    elseif key == "Rotation" then
                        emitter.Rotation = NumberRange.new(value[2] + s.roll, value[3] + s.roll)
                    else
                        emitter[key] = decode(value)
                    end
                end)
            end
            return emitter
        end

        local function clear()
            for index = #built, 1, -1 do
                pcall(function() built[index]:Destroy() end)
                built[index] = nil
            end
        end

        local function setEnabled(on)
            for _, item in ipairs(built) do
                if item:IsA("Attachment") then
                    for _, e in ipairs(item:GetChildren()) do
                        if e:IsA("ParticleEmitter") then e.Enabled = on end
                    end
                end
            end
        end

        local function rebuild(muzzle, s)
            clear()
            lastMuzzle, lastKey = muzzle, keyOf(s)
            local defs = MUZZLE_FX[s.effect]
            if not (muzzle and defs) then return end
            local attachment = Instance.new("Attachment")
            attachment.Name = "AsterMuzzleFx"
            attachment.CFrame = CFrame.new(s.x, s.y, s.z) * CFrame.Angles(math.rad(s.rx), math.rad(s.ry), math.rad(s.rz))
            for _, def in ipairs(defs) do makeEmitter(def, s).Parent = attachment end
            attachment.Parent = muzzle
            built[1] = attachment
            if s.mode == "On shot" then setEnabled(false) end
        end

        table.insert(ShotEvents.shot, function()
            if not isOn("mz_enabled") or flag("mz_mode", "While equipped") ~= "On shot" then return end
            flashToken += 1
            local token = flashToken
            setEnabled(true)
            task.delay(flag("mz_flash", 0.25), function()
                if token == flashToken then setEnabled(false) end
            end)
        end)

        feature("mz_enabled", function()
            bag.add(RunService.Heartbeat:Connect(function()
                local muzzle = heldMuzzle()
                local s = settings()
                if muzzle ~= lastMuzzle or keyOf(s) ~= lastKey or (muzzle and not (built[1] and built[1].Parent == muzzle)) then
                    local ok, err = pcall(rebuild, muzzle, s)
                    if not ok then warnf("muzzle effect failed:", err) lastKey = keyOf(s) end
                end
            end))
        end, function()
            bag.clear()
            clear()
            lastKey, lastMuzzle = nil, nil
        end)

        onUnload(function()
            bag.clear()
            clear()
        end)
    end)()

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
            return table.concat({ tostring(flag("pa_source", "angel")), tostring(auraColor()), tostring(Options.pa_color and Options.pa_color.Transparency or 0.2), tostring(flag("pa_pack_original", true)) }, "|")
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

        local ALIAS = {
            UpperTorso = "Torso", LowerTorso = "Torso",
            LeftUpperArm = "Left Arm", LeftLowerArm = "Left Arm", LeftHand = "Left Arm",
            RightUpperArm = "Right Arm", RightLowerArm = "Right Arm", RightHand = "Right Arm",
            LeftUpperLeg = "Left Leg", LeftLowerLeg = "Left Leg", LeftFoot = "Left Leg",
            RightUpperLeg = "Right Leg", RightLowerLeg = "Right Leg", RightFoot = "Right Leg",
            Torso = "UpperTorso", ["Left Arm"] = "LeftUpperArm", ["Right Arm"] = "RightUpperArm",
            ["Left Leg"] = "LeftUpperLeg", ["Right Leg"] = "RightUpperLeg",
        }

        local FX_CLASS = { ParticleEmitter = true, Beam = true, Trail = true, PointLight = true, SpotLight = true, SurfaceLight = true, Sparkles = true, Fire = true, Smoke = true }
        local packRigs = {}
        local function packRig(entry)
            local id = type(entry) == "table" and entry.id or AURA_PACK.id
            local rigName = type(entry) == "table" and entry.rig or entry
            if not packRigs[id] then
                local ok, objects = pcall(function() return game:GetObjects("rbxassetid://" .. id) end)
                if not ok or type(objects) ~= "table" then return nil end
                local rigs, loose = {}, {}
                for _, root in ipairs(objects) do
                    for _, d in ipairs(root:GetDescendants()) do
                        if d:IsA("Model") and not rigs[d.Name] and (d:FindFirstChildOfClass("Humanoid") or d:FindFirstChild("HumanoidRootPart")) then
                            rigs[d.Name] = d
                        elseif d:IsA("BasePart") and not loose[d.Name] and d:FindFirstChildWhichIsA("Attachment") then
                            loose[d.Name] = d
                        end
                    end
                end
                packRigs[id] = rigs
                packRigs[-id] = loose
            end
            if type(entry) == "table" and entry.part then return packRigs[-id][entry.part], true end
            return packRigs[id][rigName]
        end
        Actions.packRig = function(entry) return (packRig(entry)) end

        local function applyPack(char, rigName)
            local rig, isLoose = packRig(rigName)
            if not rig then
                warnf("particle aura: pack or aura not found:", type(rigName) == "table" and (rigName.rig or rigName.part) or rigName)
                pcall(function() Library:Notify("Aura could not be loaded", 4) end)
                return
            end
            local keepColors = flag("pa_pack_original", true)
            local root = char:FindFirstChild("HumanoidRootPart")
            local attached = 0
            local partList = rig:GetDescendants()
            if isLoose then table.insert(partList, 1, rig) end
            for _, part in ipairs(partList) do
                if part:IsA("BasePart") then
                    local children, any = {}, false
                    for _, child in ipairs(part:GetChildren()) do
                        if child:IsA("Attachment") or FX_CLASS[child.ClassName] then
                            children[#children + 1] = child
                            if FX_CLASS[child.ClassName] then any = true end
                            if child:IsA("Attachment") then
                                for _, d in ipairs(child:GetDescendants()) do
                                    if FX_CLASS[d.ClassName] then any = true break end
                                end
                            end
                        end
                    end
                    if any then
                        local target = char:FindFirstChild(part.Name, true)
                        if not (target and target:IsA("BasePart")) then
                            local alias = ALIAS[part.Name]
                            target = alias and char:FindFirstChild(alias, true)
                        end
                        if not (target and target:IsA("BasePart")) then target = root end
                        if target then
                            local map, clones = {}, {}
                            for _, child in ipairs(children) do
                                local clone = child:Clone()
                                for _, d in ipairs(clone:GetDescendants()) do
                                    if d:IsA("LuaSourceContainer") then d:Destroy() end
                                end
                                clone.Parent = target
                                map[child] = clone
                                clones[#clones + 1] = clone
                            end
                            for _, clone in ipairs(clones) do
                                if clone:IsA("Beam") or clone:IsA("Trail") then
                                    pcall(function()
                                        if clone.Attachment0 and map[clone.Attachment0] then clone.Attachment0 = map[clone.Attachment0] end
                                        if clone.Attachment1 and map[clone.Attachment1] then clone.Attachment1 = map[clone.Attachment1] end
                                    end)
                                end
                                active[#active + 1] = clone
                                if not keepColors then
                                    tint(clone)
                                    for _, d in ipairs(clone:GetDescendants()) do tint(d) end
                                end
                            end
                            attached += 1
                        end
                    end
                end
            end
            if attached == 0 then pcall(function() Library:Notify("That aura had no effects to attach", 4) end) end
        end

        local function apply()
            clear()
            local char = LocalPlayer.Character
            if not char then return end
            local rigName = AURA_PACK.rigs[flag("pa_source", "angel")]
            if rigName then return applyPack(char, rigName) end
            local model
            local id = SOURCES[flag("pa_source", "angel")]
            if not id then return end
            local ok, objects = pcall(function() return game:GetObjects(id) end)
            model = ok and objects and objects[1]
            if not model then warnf("particle aura asset could not be loaded") return end

            local function attach(part, target)
                for _, child in ipairs(part:GetChildren()) do
                    if child:IsA("LuaSourceContainer") then continue end
                    local clone = child:Clone()
                    for _, d in ipairs(clone:GetDescendants()) do
                        if d:IsA("LuaSourceContainer") then d:Destroy() end
                    end
                    clone.Parent = target
                    tint(clone)
                    for _, d in ipairs(clone:GetDescendants()) do tint(d) end
                    active[#active + 1] = clone
                end
            end
            local strict = flag("pa_source", "angel") == "angel"
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

    ;(function()

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

        local function taggedGiverFor(entry)
            local best, bestDist = nil, math.huge
            local _, _, root = localParts()
            for _, giver in ipairs(touchGivers()) do
                local toolName = giver:GetAttribute("ToolName")
                local match = false
                if type(toolName) == "string" then
                    match = nameHas(toolName, entry.needles)
                end
                if not match then match = nameHas(giver.Name, entry.needles) end
                if match then
                    local at = positionOf(giver)
                    local dist = (at and root) and (at - root.Position).Magnitude or 1e6
                    if dist < bestDist then best, bestDist = giver, dist end
                end
            end
            return best
        end

        local function resolveClickModel(name, entry)
            local cached = giverCache[name]
            if cached and cached.Parent then return cached end
            local tagged = taggedGiverFor(entry)
            if tagged then
                giverCache[name] = tagged
                return tagged
            end
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

        local function refusalReason(target)
            if not target then return "giver not found (walk closer so it loads)" end
            local model = CollectionService:HasTag(target, "Giver") and target or target.Parent
            if not model then return "unknown" end
            local team = LocalPlayer.Team
            local teamOk = CollectionService:HasTag(model, "Team_Any") or (team and CollectionService:HasTag(model, "Team_" .. team.Name))
            if not teamOk then
                local wanted = {}
                for _, tag in ipairs(CollectionService:GetTags(model)) do
                    if string.sub(tag, 1, 5) == "Team_" then wanted[#wanted + 1] = string.sub(tag, 6) end
                end
                return "wrong team (needs " .. (#wanted > 0 and table.concat(wanted, "/") or "another team") .. ")"
            end
            local pass = model:FindFirstChild("premiumType") or (model.Parent and model.Parent:FindFirstChild("premiumType"))
            if pass then return "needs the " .. tostring(pass.Value) .. " gamepass" end
            return "refused by the server"
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
            if got then
                say("Got " .. name)
            elseif entry.method == "click" then
                say(name .. " failed: " .. refusalReason(target))
            end
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

        function SP.realPos(root)
            if applied and realCF then return realCF.Position end
            return root.Position
        end

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
                        clone.Transparency = 0
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

        function SP.enable(name, fn)
            requests[name] = fn
            startEngine()
        end

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

    ;(function()
        local rand = Random.new()

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

        local function lookFlat(shooterPos, targetPos)
            local flatDelta = (shooterPos - targetPos) * FLAT
            if flatDelta.Magnitude > 0.001 then
                return CFrame.lookAt(shooterPos * FLAT, targetPos * FLAT).LookVector
            end
            return v3(0, 0, -1)
        end

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

        WB.filter = nil
        function WB.accept(origin, target)
            local f = WB.filter
            if not f then return true end
            if (origin - f.shooter).Magnitude > f.spot then return false end
            if (target - f.center).Magnitude > f.spot then return false end
            if f.range and (target - origin).Magnitude > f.range then return false end
            return true
        end

        local function firstClear(targets, origins)
            for _, target in ipairs(targets) do
                for _, origin in ipairs(origins) do
                    if WB.accept(origin, target) and not workspace:Raycast(target, origin - target, WB.ray) and freeSpace(origin) then
                        return origin, target
                    end
                end
            end
            return nil
        end

        local function append(into, list)
            for _, item in ipairs(list) do into[#into + 1] = item end
        end

        local METHODS = {}

        local LEGACY = { ["awp"] = "Aster Origin", ["awp v2"] = "Aster Reach", ["awp v2.1"] = "Aster Precise" }

        METHODS["Vape V4"] = function(shooter, target, surface, center, hitbox)
            local reach = radius() - math.min(WB.moved, 1)
            local look = lookFlat(shooter, target)
            local targets = {}
            if freeSpace(target) then
                if surface and (shooter - surface).Magnitude < 7.5 and WB.accept(surface, target) then return surface, target end
                targets[1] = target
            end
            if hitbox then append(targets, pointsAround(center, look, { 7.4 })) end
            local origins = { shooter }
            for _, position in ipairs(originsAround(shooter, look, { reach }, { OFFSETS_NEAR })) do
                if freeSpace(position) then origins[#origins + 1] = position end
            end
            return firstClear(targets, origins)
        end

        METHODS["Aster Origin"] = function(shooter, target, surface, center, hitbox)
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

        METHODS["Aster Reach"] = function(shooter, target, surface, center, hitbox)
            local reach = radius()
            local look = lookFlat(shooter, target)
            local origins = originsAround(shooter, look, { reach, reach * 2 }, { OFFSETS_NEAR, OFFSETS_HIGH })
            if surface then table.insert(origins, 1, surface) end
            local targets = { target }
            if hitbox then append(targets, pointsAround(center, look, { reach, reach * 2 })) end
            return firstClear(targets, origins)
        end

        METHODS["Aster Precise"] = function(shooter, target, surface, center, hitbox)
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

        local function wallbangPlan(origin, part, root, override)
            local position = part.Position
            local cached
            if not override then cached = WB.cache[part] end
            if cached == false then return nil end
            if cached then return "moved", cached[1], cached[2] end

            local blocked = workspace:Raycast(position, origin - position, WB.ray)
            if not blocked and not workspace:Raycast(origin, position - origin, WB.ray) then return "clear" end

            local shooter = override or Actions.sp.shooter(root)
            local anchor = part.Parent and part.Parent:FindFirstChild("HumanoidRootPart")
            local center = anchor and anchor.Position or position
            local method = LEGACY[flag("wb_method", "Aster Reach")] or flag("wb_method", "Aster Reach")
            local scan = METHODS[method] or METHODS["Aster Reach"]

            local data = Gun.data()
            WB.filter = flag("wb_damage", true) and {
                shooter = shooter, center = center, spot = flag("wb_spot", 7.5),
                range = data and tonumber(data.Range) or nil,
            } or nil
            local newOrigin, newTarget = scan(shooter, position, blocked and (blocked.Position + blocked.Normal * 0.01) or nil, center, flag("wb_hitbox", true))

            if not newOrigin and (method == "Aster Reach" or method == "Aster Precise") then
                local delta = position - shooter
                local dist = delta.Magnitude
                if dist > 0.5 then
                    local unit = delta.Unit
                    for i = 2, math.min(dist, 160), 2 do
                        local ground = workspace:Raycast(shooter + unit * i, v3(0, -50, 0), WB.ray)
                        if ground then
                            local at = ground.Position + ground.Normal * 0.5
                            if WB.accept(at, position) and not workspace:Raycast(at, position - at, WB.ray) and freeSpace(at) then
                                newOrigin, newTarget = at, position
                                break
                            end
                        end
                    end
                end
                if not newOrigin then
                    for i = 3, 18, 3 do
                        local at = shooter + v3(0, i, 0)
                        if WB.accept(at, position) and not workspace:Raycast(at, position - at, WB.ray) and freeSpace(at) then
                            newOrigin, newTarget = at, position
                            break
                        end
                    end
                end
            end

            WB.filter = nil
            if newOrigin then
                if not override then WB.cache[part] = { newOrigin, newTarget } end
                return "moved", newOrigin, newTarget
            end
            if not override then WB.cache[part] = false end
            return nil
        end

        WB.lastTick = 0
        function WB.tick()
            local now = clock()
            if now - WB.lastTick > 0.15 then
                WB.lastTick = now
                table.clear(WB.cache)
                WB.updateIgnore()
            end
        end

        function WB.status(origin, part, shooter)
            local _, _, root = localParts()
            if not root or not part or not part.Parent then return "blocked" end
            local plan = wallbangPlan(origin, part, root, shooter)
            if plan == "clear" then return "visible" end
            if plan == "moved" then return "wallbang" end
            return "blocked"
        end

        do
            local bag = newBag()
            local hookedCast, original = nil, nil
            local wants = { silent = false, fx = false, auto = false, assist = false }
            local autoNext, loopToken, warnedStack = 0, 0, false
            local lastOrigin, lastNew

            local function silentActive()
                return flag("Silent_Global_Enabled", false) and keyActive("Silent_Global_Key")
            end

            local function anyWanted()
                return wants.silent or wants.fx or wants.auto or wants.assist
            end

            local function redirect(...)
                local origin = ...

                local force = Gun.force
                if force then
                    Gun.force = nil
                    if clock() < force.expires and force.part.Parent then return force.part, force.pos end
                end

                if typeof(origin) ~= "Vector3" then return original(...) end
                local silentOn = wants.silent and silentActive()

                local A = Actions.sp.assist
                local assisted = not silentOn and wants.assist and A.part ~= nil and A.part.Parent ~= nil and clock() < (A.partUntil or 0)
                if not silentOn and not assisted then return original(...) end
                if silentOn and rand:NextNumber(0, 100) > flag("Silent_Global_HitChance", 100) then return original(...) end

                local data = Gun.data()
                local taser = data and data.Behavior == "Taser"
                local wallbang = flag("silent_wallbang", false)
                local entity, part
                if assisted then
                    entity, part, wallbang = { Character = A.part.Parent }, A.part, true
                else
                    entity, part = selectTarget("silent", aimRef(), origin, {
                        limit = data and tonumber(data.Range) or 1000,
                        ignoreDown = taser,
                        skipWall = wallbang,
                    })
                end
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
            Actions.assistHook = function(on)
                wants.assist = on and true or false
                refresh()
            end
            Actions.autoHook = function(on)
                wants.auto = on and true or false
                refresh()
            end

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
                            local entity, part = selectTarget("silent", aimRef(), head.Position, {
                                limit = data and tonumber(data.Range) or 1000,
                                ignoreDown = data and data.Behavior == "Taser",
                                skipWall = flag("silent_wallbang", false),
                            })

                            if entity and part and flag("silent_wallbang", false) and flag("silent_autofire_check", true) then
                                WB.tick()
                                if WB.status(head.Position, part) == "blocked" then entity = nil end
                            end
                            if entity then
                                Actions.lastAutoShot = clock()
                                fireGun()
                            end
                        end
                    end
                end))
            end, function()
                bag.clear()
                wants.silent = false
                refresh()
            end)

            onUnload(function()
                wants.silent, wants.fx, wants.auto, wants.assist = false, false, false, false
                loopToken += 1
                unhook()
                ShotEvents.hooked = nil
                Actions.fxHook, Actions.autoHook, Actions.assistHook = noop, noop, noop
                Actions.fireAt = function() return false end
            end)
        end

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

        do
            local bag = newBag()
            local A = Actions.sp.assist
            A.goal, A.speed, A.style, A.part, A.partUntil = nil, 50, nil, nil, 0
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            pcall(function() params.CollisionGroup = "ClientBullet" end)
            local nextEval, errors = 0, 0

            local function firing()
                if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then return true end
                return clock() - (Actions.lastAutoShot or -10) < 0.4
            end

            local function evaluate()
                local char, _, root = localParts()
                if not char or not root or typing() then return nil end
                if flag("wb_assist_fire", false) and not firing() then return nil end
                local cam = Camera()
                if not cam then return nil end
                WB.tick()
                local head = char:FindFirstChild("Head")
                local realPos = Actions.sp.realPos(root)
                local headOffset = head and (head.Position - root.Position) or v3(0, 1.5, 0)
                local origin = realPos + headOffset
                local ref = aimRef()
                local fov, maxDist, reach = flag("wb_assist_fov", 250), flag("wb_assist_max", 200), flag("wb_assist_dist", 25)

                local candidates = {}
                for _, e in ipairs(otherEntities()) do
                    if Relations[e.Player.UserId] ~= "Friendly" and (e.Root.Position - realPos).Magnitude <= maxDist then
                        local screen, onScreen = cam:WorldToViewportPoint(e.Head.Position)
                        if onScreen then
                            local d = (Vector2.new(screen.X, screen.Y) - ref).Magnitude
                            if d <= fov then candidates[#candidates + 1] = { e = e, d = d } end
                        end
                    end
                end
                table.sort(candidates, function(a, b) return a.d < b.d end)

                for index = 1, math.min(#candidates, 4) do
                    local part = candidates[index].e.Head
                    local status = WB.status(origin, part, realPos)
                    if status == "visible" then
                        return nil
                    elseif status == "wallbang" then
                        return nil, part
                    end
                    local delta = part.Position - realPos
                    local distance = delta.Magnitude
                    if distance >= 2 then
                        params.FilterDescendantsInstances = WB.ray.FilterDescendantsInstances
                        local hit = workspace:Raycast(realPos, delta, params)
                        if hit and hit.Distance <= reach then
                            local unit = delta / distance
                            local point = flag("wb_assist_inside", false) and (hit.Position + unit * 1.5) or (hit.Position - unit * 1.2)
                            local goal = v3(point.X, realPos.Y + math.clamp(point.Y - realPos.Y, -4, 4), point.Z)

                            if WB.status(goal + headOffset, part, goal) ~= "blocked" then return goal, part end
                        end
                    end
                end
                return nil
            end

            local function step()
                local now = clock()
                if now < nextEval then return end
                nextEval = now + 0.1
                local goal, part = evaluate()
                A.goal = goal
                if goal then A.goalAt = now end
                if goal then
                    A.speed = flag("wb_assist_mode", "Tween") == "Teleport" and 1e9 or flag("wb_assist_speed", 50)
                    A.style = flag("wb_assist_visual", false) and Actions.sp.visualStyle("wb_assist_fill", "wb_assist_line") or nil
                end
                if part then A.part, A.partUntil = part, now + 0.35 end
            end

            local M = { home = nil, holdUntil = 0, heading = ZERO, modified = {} }
            local overlap = OverlapParams.new()
            overlap.FilterType = Enum.RaycastFilterType.Exclude

            local function releaseMoved()
                for part in pairs(M.modified) do pcall(function() part.CanCollide = true end) end
                table.clear(M.modified)
            end

            local function realMove(dt)
                local _, _, root = localParts()
                if not root or flag("wb_assist_method", "Server position") ~= "Velocity" then
                    if M.home or next(M.modified) then
                        M.home = nil
                        releaseMoved()
                    end
                    return
                end
                local now = clock()
                local wants = A.goal ~= nil and now - (A.goalAt or 0) < 0.4
                if wants or (M.home and firing()) then M.holdUntil = now + 0.5 end
                local target
                if wants then
                    if not M.home then M.home = root.Position end
                    target = A.goal
                elseif M.home and now < M.holdUntil then
                    target = root.Position
                elseif M.home then
                    target = M.home
                    if (root.Position - M.home).Magnitude < 1.5 then
                        M.home = nil
                        M.heading = ZERO
                        releaseMoved()
                        root.AssemblyLinearVelocity = ZERO
                        return
                    end
                else
                    return
                end
                local delta = target - root.Position
                local distance = delta.Magnitude
                local speed = flag("wb_assist_mode", "Tween") == "Teleport" and 120 or flag("wb_assist_speed", 50)
                local velocity = ZERO
                if distance > 0.6 then velocity = delta.Unit * math.min(speed, distance / math.max(dt, 1 / 120)) end
                M.heading = velocity
                root.AssemblyLinearVelocity = velocity
                root.AssemblyAngularVelocity = ZERO
            end

            local function noclipStep()
                if not M.home then
                    if next(M.modified) then releaseMoved() end
                    return
                end
                local char, hum, root = localParts()
                if not root or not hum then return end
                local list = { Camera(), char }
                for _, e in ipairs(otherEntities()) do list[#list + 1] = e.Character end
                overlap.FilterDescendantsInstances = list
                local center = root.CFrame + v3(0, 1, 0) + M.heading * 0.12
                local near = {}
                for _, part in ipairs(workspace:GetPartBoundsInBox(center, root.Size + v3(7, hum.HipHeight, 7), overlap)) do
                    near[part] = true
                    if part.CanCollide then M.modified[part] = true part.CanCollide = false end
                end
                for part in pairs(M.modified) do
                    if not near[part] then M.modified[part] = nil part.CanCollide = true end
                end
            end

            feature("wb_assist", function()
                Actions.sp.enable("assist", function()
                    if not A.goal or flag("wb_assist_method", "Server position") ~= "Server position" then return nil end
                    return A.goal, A.speed, A.style
                end)
                bag.add(RunService.Heartbeat:Connect(function(dt)
                    local ok, err = pcall(realMove, dt)
                    if not ok then
                        errors += 1
                        if errors <= 3 then warnf("wallbang assist move error:", err) end
                    end
                end))
                bag.add(RunService.Stepped:Connect(function()
                    pcall(noclipStep)
                end))
                Actions.assistHook(true)
                task.spawn(Gun.find)
                nextEval = 0
                bag.add(RunService.RenderStepped:Connect(function()
                    local ok, err = pcall(step)
                    if not ok then
                        errors += 1
                        if errors <= 3 then warnf("wallbang assist error:", err) end
                    end
                end))
            end, function()
                bag.clear()
                A.goal, A.style, A.part = nil, nil, nil
                M.home = nil
                releaseMoved()
                Actions.assistHook(false)
                Actions.sp.disable("assist")
            end)
        end

        do
            local function pick(name, fallbackColor, fallbackAlpha)
                local object = Options[name]
                local color = object and typeof(object.Value) == "Color3" and object.Value or fallbackColor
                local alpha = object and tonumber(object.Transparency) or fallbackAlpha
                return color, alpha
            end
            local drawingOk = Drawing ~= nil and type(Drawing.new) == "function"
            local function newDrawing(kind)
                if not drawingOk then return nil end
                local ok, object = pcall(Drawing.new, kind)
                if ok and object then
                    table.insert(getgenv().TS_Drawings, object)
                    return object
                end
                return nil
            end
            local function discard(object)
                if object then pcall(function() object.Visible = false object:Remove() end) end
            end

            local bag = newBag()
            local cursorText, pool, states, budget, warned = nil, {}, {}, 0, false
            local LABELS = { visible = "visible", wallbang = "wallbangable", blocked = "not wallbangable" }

            local function stateColor(state)
                if state == "visible" then return (pick("wb_ind_c_vis", Color3.fromRGB(90, 255, 120), 0)) end
                if state == "wallbang" then return (pick("wb_ind_c_wb", Color3.fromRGB(255, 200, 60), 0)) end
                return (pick("wb_ind_c_block", Color3.fromRGB(255, 80, 80), 0))
            end
            local function setText(text, content, x, y, size, color)
                text.Text = content
                text.Size = size
                text.Color = color
                text.Position = Vector2.new(x, y)
                text.Visible = true
            end
            local function hideTexts()
                if cursorText then cursorText.Visible = false end
                for _, text in pairs(pool) do text.Visible = false end
            end
            local function stateOf(e, origin, now, force)
                local cached = states[e.Player]
                if cached and now - cached.t < 0.15 then return cached.s end
                if not force and budget <= 0 and cached then return cached.s end
                budget -= 1
                local state = WB.status(origin, e.Head)
                states[e.Player] = { s = state, t = now }
                return state
            end

            local function indicatorStep()
                local cam = Camera()
                local char, _, root = localParts()
                if not cam or not root then
                    hideTexts()
                    return
                end
                WB.tick()
                local now = clock()
                local head = char:FindFirstChild("Head")
                local origin = head and head.Position or root.Position
                local size, range = flag("wb_ind_size", 14), flag("wb_ind_range", 1000)
                local everyone = flag("wb_ind_all", false)
                local ref = aimRef()
                budget = 3
                local used, best, bestD = {}, nil, nil
                for _, e in ipairs(otherEntities()) do
                    if Relations[e.Player.UserId] ~= "Friendly" and (e.Root.Position - root.Position).Magnitude <= range then
                        local screen, onScreen = cam:WorldToViewportPoint(e.Head.Position)
                        if onScreen then
                            local d = (Vector2.new(screen.X, screen.Y) - ref).Magnitude
                            if not bestD or d < bestD then best, bestD = e, d end
                            if everyone then
                                local state = stateOf(e, origin, now, false)
                                local text = pool[e.Player]
                                if not text then
                                    text = newDrawing("Text")
                                    if text then
                                        text.Center = true
                                        text.Outline = true
                                        pool[e.Player] = text
                                    end
                                end
                                if text then
                                    setText(text, LABELS[state], screen.X, screen.Y - size * 2.2, size, stateColor(state))
                                    used[e.Player] = true
                                end
                            end
                        end
                    end
                end
                for player, text in pairs(pool) do
                    if not used[player] then
                        text.Visible = false
                        if not player.Parent then
                            discard(text)
                            pool[player] = nil
                            states[player] = nil
                        end
                    end
                end

                if flag("wb_ind_cursor", true) then
                    if not cursorText then
                        cursorText = newDrawing("Text")
                        if cursorText then cursorText.Outline = true end
                    end
                    if cursorText then
                        if best and bestD <= 250 then
                            local state = stateOf(best, origin, now, true)
                            setText(cursorText, LABELS[state], ref.X + 24, ref.Y + 14, size, stateColor(state))
                        elseif flag("wb_ind_always", false) then
                            setText(cursorText, "no target", ref.X + 24, ref.Y + 14, size, Color3.fromRGB(180, 180, 180))
                        else
                            cursorText.Visible = false
                        end
                    end
                elseif cursorText then
                    cursorText.Visible = false
                end
            end

            feature("wb_ind", function()
                if not drawingOk then
                    say("The wallbang indicator needs the Drawing library")
                    switchOff("wb_ind")
                    return
                end
                bag.add(RunService.RenderStepped:Connect(function()
                    local ok, err = pcall(indicatorStep)
                    if not ok and not warned then
                        warned = true
                        warnf("wallbang indicator error:", err)
                    end
                end))
            end, function()
                bag.clear()
                hideTexts()
            end)

            local reloadBag = newBag()
            local back, fill, label, reloadWarned = nil, nil, nil, false
            local RELOAD_FALLBACK = { ["AK-47"] = 2, FAL = 2, M4A1 = 2, M9 = 2, MP5 = 2, ["Remington 870"] = 3.5, Taser = 3.4, M700 = 3, Revolver = 3 }

            local function hideReload()
                if back then back.Visible = false end
                if fill then fill.Visible = false end
                if label then label.Visible = false end
            end

            local function reloadStep()
                local tool = equippedGun()
                local session = tool and tool:GetAttribute("Local_ReloadSession")
                if type(session) ~= "number" or session <= 0 then
                    hideReload()
                    return
                end
                local data = Gun.data()
                local duration = (data and tonumber(data.ReloadTime)) or tonumber(tool:GetAttribute("ReloadTime")) or RELOAD_FALLBACK[tool.Name] or 2.5
                duration = math.max(duration, 0.1)
                local elapsed = tick() - session
                local progress = math.clamp(elapsed / duration, 0, 1)
                local width, height = flag("reload_ind_w", 120), flag("reload_ind_h", 6)
                local ref = aimRef()
                local x, y = ref.X - width / 2, ref.Y + flag("reload_ind_y", 40)

                back = back or newDrawing("Square")
                fill = fill or newDrawing("Square")
                if not back or not fill then return end
                local fillColor, fillAlpha = pick("reload_ind_fill", Color3.fromRGB(255, 255, 255), 0)
                local backColor, backAlpha = pick("reload_ind_back", Color3.fromRGB(0, 0, 0), 0.5)
                back.Filled, back.Color, back.Transparency = true, backColor, 1 - backAlpha
                back.Position, back.Size, back.Visible = Vector2.new(x - 1, y - 1), Vector2.new(width + 2, height + 2), true
                fill.Filled, fill.Color, fill.Transparency = true, fillColor, 1 - fillAlpha
                fill.Position, fill.Size, fill.Visible = Vector2.new(x, y), Vector2.new(math.max(width * progress, 0.01), height), true

                if flag("reload_ind_text", true) then
                    if not label then
                        label = newDrawing("Text")
                        if label then
                            label.Center = true
                            label.Outline = true
                            label.Size = 13
                            label.Color = Color3.fromRGB(255, 255, 255)
                        end
                    end
                    if label then
                        label.Text = string.format("reloading %.1fs", math.max(duration - elapsed, 0))
                        label.Position = Vector2.new(ref.X, y + height + 3)
                        label.Visible = true
                    end
                elseif label then
                    label.Visible = false
                end
            end

            feature("reload_ind", function()
                if not drawingOk then
                    say("The reload indicator needs the Drawing library")
                    switchOff("reload_ind")
                    return
                end
                task.spawn(Gun.find)
                reloadBag.add(RunService.RenderStepped:Connect(function()
                    local ok, err = pcall(reloadStep)
                    if not ok and not reloadWarned then
                        reloadWarned = true
                        warnf("reload indicator error:", err)
                    end
                end))
            end, function()
                reloadBag.clear()
                hideReload()
            end)

            local ammoBag = newBag()
            local ammoLabel, ammoWarned = nil, false
            local function ammoStep()
                local tool = equippedGun()
                local serverAmmo = tool and tool:GetAttribute("CurrentAmmo")
                if type(serverAmmo) ~= "number" then
                    if ammoLabel then ammoLabel.Visible = false end
                    return
                end
                local localAmmo = tool:GetAttribute("Local_CurrentAmmo")
                local maxAmmo, stored = tool:GetAttribute("MaxAmmo"), tool:GetAttribute("StoredAmmo")
                local text = "server " .. tostring(serverAmmo)
                if type(stored) == "number" then
                    text ..= " | " .. tostring(stored)
                elseif type(maxAmmo) == "number" then
                    text ..= "/" .. tostring(maxAmmo)
                end
                local mismatch = type(localAmmo) == "number" and localAmmo ~= serverAmmo
                if flag("ammo_ind_local", false) and type(localAmmo) == "number" then
                    text ..= "  (local " .. tostring(localAmmo) .. ")"
                end
                local color
                if serverAmmo <= 0 then
                    color = pick("ammo_ind_c_empty", Color3.fromRGB(255, 80, 80), 0)
                elseif mismatch then
                    color = pick("ammo_ind_c_diff", Color3.fromRGB(255, 200, 60), 0)
                else
                    color = pick("ammo_ind_c_ok", Color3.fromRGB(255, 255, 255), 0)
                end
                if not ammoLabel then
                    ammoLabel = newDrawing("Text")
                    if not ammoLabel then return end
                    ammoLabel.Center = true
                    ammoLabel.Outline = true
                end
                local ref = aimRef()
                ammoLabel.Text = text
                ammoLabel.Size = flag("ammo_ind_size", 16)
                ammoLabel.Color = color
                ammoLabel.Position = Vector2.new(ref.X, ref.Y + flag("ammo_ind_y", 70))
                ammoLabel.Visible = true
            end

            feature("ammo_ind", function()
                if not drawingOk then
                    say("The ammo indicator needs the Drawing library")
                    switchOff("ammo_ind")
                    return
                end
                ammoBag.add(RunService.RenderStepped:Connect(function()
                    local ok, err = pcall(ammoStep)
                    if not ok and not ammoWarned then
                        ammoWarned = true
                        warnf("ammo indicator error:", err)
                    end
                end))
            end, function()
                ammoBag.clear()
                if ammoLabel then ammoLabel.Visible = false end
            end)

            onUnload(function()
                discard(ammoLabel)
                ammoLabel = nil
                for _, text in pairs(pool) do discard(text) end
                table.clear(pool)
                discard(cursorText)
                discard(back)
                discard(fill)
                discard(label)
                cursorText, back, fill, label = nil, nil, nil, nil
            end)
        end
    end)()

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
                    if (ShotEvents.last or 0) >= stamp - 0.1 then return end
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

        local partTurn = {}
        local function deadEntities()
            local list = {}
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    local char = player.Character
                    local hum = char and char:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health <= 0 then
                        local parts = {}
                        for _, child in ipairs(char:GetChildren()) do
                            if child:IsA("BasePart") and child.Parent then parts[#parts + 1] = child end
                        end
                        if #parts > 0 then
                            table.sort(parts, function(a, b) return a.Name < b.Name end)
                            local turn = (partTurn[player.UserId] or 0) % #parts + 1
                            partTurn[player.UserId] = turn
                            list[#list + 1] = { Player = player, Character = char, Humanoid = hum, Root = parts[turn], Head = char:FindFirstChild("Head"), Dead = true }
                        end
                    end
                end
            end
            return list
        end

        local function pickTarget(seat)
            local held = current[seat]
            if held and held.Root.Parent and clock() - (lastFling[held.Player.UserId] or 0) < 0.75 then return held end
            local list = otherEntities()
            if flag("misc_kick_parts", true) then
                for _, dead in ipairs(deadEntities()) do list[#list + 1] = dead end
            end
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
                    say("Kick exploit: " .. e.Player.Name .. (e.Dead and (" (" .. e.Root.Name .. ")") or ""))
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
