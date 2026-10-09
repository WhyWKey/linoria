warn("[Prison Life] 0: executing")
local __plOk, __plErr = xpcall(function()
warn("[Prison Life] 1: inside wrapper")
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

warn("[Prison Life] 2: old run cleaned up")
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

warn("[Prison Life] loading UI library")
local UI_REPO = "https://raw.githubusercontent.com/WhyWKey/linoria/main/"
warn("[Prison Life] downloading Library.lua")
local Library = loadstring(game:HttpGet(UI_REPO .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(UI_REPO .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(UI_REPO .. "addons/SaveManager.lua"))()
warn("[Prison Life] library loaded")
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

-- Palette of the library's built-in "Perception" theme, applied before the window is built.
Library.FontColor = Color3.fromRGB(182, 182, 182)
Library.MainColor = Color3.fromRGB(20, 20, 20)
Library.BackgroundColor = Color3.fromRGB(23, 23, 23)
Library.AccentColor = Color3.fromRGB(102, 137, 148)
Library.OutlineColor = Color3.fromRGB(24, 24, 24)
Library.AccentColorDark = Library:GetDarkerColor(Library.AccentColor)
Library:UpdateColorsUsingRegistry()

local LinoriaWindow = Library:CreateWindow({
    Title = "Prison Life",
    Center = true,
    AutoShow = true,
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
        })
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

local WHITE = Color3.fromRGB(255, 255, 255)
local BLACK = Color3.fromRGB(0, 0, 0)

-- Combat
do
-- Combat
do
    local Aim = CombatTab:Section({ Name = "Aimbot", Side = 1 })
    local aimEnabled = Aim:Toggle({ Name = "Enabled", Flag = "Aim_Global_Enabled", Default = false })
    aimEnabled:Keybind({ Name = "Hotkey", Flag = "Aim_Global_Key", Default = Enum.KeyCode.E, Mode = "Toggle" })
    Aim:Dropdown({ Name = "Hit part", Flag = "Aim_Global_HitPart", Items = { "Head", "Torso", "Closest" }, Default = "Head" })
    Aim:Slider({ Name = "FOV", Flag = "Aim_Global_FOV", Min = 10, Max = 360, Default = 90, Suffix = "°", Decimals = 1 })
    Aim:Slider({ Name = "Smoothness", Flag = "Aim_Global_Smooth", Min = 1, Max = 30, Default = 8, Decimals = 0.1 })
    Aim:Dropdown({ Name = "Smooth type", Flag = "Aim_Global_SmoothType", Items = { "None", "Lerp", "Linear", "Exponential", "Spring" }, Default = "Lerp" })
    Aim:Slider({ Name = "Reaction time", Flag = "Aim_Global_Reaction", Min = 0, Max = 300, Default = 0, Suffix = "ms", Decimals = 1 })
    local Silent = CombatTab:Section({ Name = "Silent aim", Side = 2 })
    local silentEnabled = Silent:Toggle({ Name = "Enabled", Flag = "Silent_Global_Enabled", Default = false })
    silentEnabled:Keybind({ Name = "Hotkey", Flag = "Silent_Global_Key", Default = Enum.KeyCode.Q, Mode = "Toggle" })
    Silent:Dropdown({ Name = "Hit part", Flag = "Silent_Global_HitPart", Items = { "Head", "Torso", "Closest" }, Default = "Head" })
    Silent:Slider({ Name = "FOV", Flag = "Silent_Global_FOV", Min = 10, Max = 360, Default = 90, Suffix = "°", Decimals = 1 })
    Silent:Slider({ Name = "Hit chance", Flag = "Silent_Global_HitChance", Min = 1, Max = 100, Default = 100, Suffix = "%", Decimals = 1 })
    Silent:Toggle({ Name = "Show FOV", Flag = "Silent_Global_ShowFOV", Default = false })
    local Trigger = CombatTab:Section({ Name = "Triggerbot", Side = 1 })
    local triggerEnabled = Trigger:Toggle({ Name = "Enabled", Flag = "Trigger_Global_Enabled", Default = false })
    triggerEnabled:Keybind({ Name = "Hotkey", Flag = "Trigger_Global_Key", Default = Enum.KeyCode.T, Mode = "Toggle" })
    Trigger:Dropdown({ Name = "Hit part", Flag = "Trigger_Global_HitPart", Items = { "Head", "Torso", "Any" }, Default = "Head" })
    Trigger:Slider({ Name = "Delay", Flag = "Trigger_Global_Delay", Min = 0, Max = 300, Default = 40, Suffix = "ms", Decimals = 1 })
    Trigger:Slider({ Name = "Reaction time", Flag = "Trigger_Global_Reaction", Min = 0, Max = 200, Default = 0, Suffix = "ms", Decimals = 1 })
    local FovRing = CombatTab:Section({ Name = "FOV circle", Side = 2 })
    local fovCircle = FovRing:Toggle({ Name = "FOV circle", Flag = "aimbot_fov_outline", Default = false })
    fovCircle:Colorpicker({ Name = "Color", Flag = "aimbot_outline_color1", Default = Color3.new(1, 1, 1) })
    FovRing:Slider({ Name = "FOV radius", Flag = "silent_radius", Min = 0, Max = 500, Default = 100, Suffix = "px", Decimals = 1 })
    FovRing:Toggle({ Name = "FOV rotation", Flag = "aimbot_fov_moving", Default = false })
    FovRing:Slider({ Name = "FOV rotation speed", Flag = "aimbot_fov_rotation_speed", Min = 0, Max = 5, Default = 1, Decimals = 0.01 })
    local Weapon = CombatTab:Section({ Name = "Weapon", Side = 1 })
    Weapon:Toggle({ Name = "Auto reload", Flag = "weapon_auto_reload", Default = false })
    Weapon:Toggle({ Name = "Infinite ammo", Flag = "weapon_infinite_ammo", Default = false })
    Weapon:Toggle({ Name = "No recoil", Flag = "weapon_no_recoil", Default = false })
    Weapon:Toggle({ Name = "No spread", Flag = "weapon_no_spread", Default = false })
    Weapon:Toggle({ Name = "Instant hit", Flag = "weapon_instant_hit", Default = false })
    Weapon:Toggle({ Name = "Instant reload", Flag = "weapon_instant_reload", Default = false })
    Weapon:Toggle({ Name = "Rapid fire", Flag = "weapon_rapid_fire", Default = false })
    Weapon:Slider({ Name = "Fire rate", Flag = "weapon_fire_rate", Min = 0, Max = 100, Default = 0, Decimals = 1 })
    Weapon:Label({ Name = "All weapon settings are global." })
    local Hits = CombatTab:Section({ Name = "Hit feedback", Side = 2 })
    Hits:Toggle({ Name = "Hit notifications", Flag = "World_HitNotify", Default = false })
    Hits:Toggle({ Name = "Hit sounds", Flag = "World_HitSound", Default = false })
    Hits:Dropdown({ Name = "Hit sound", Flag = "World_HitSoundId", Items = HIT_SOUND_NAMES, Default = "Gamesense" })
    Hits:Slider({ Name = "Hit volume", Flag = "World_HitVolume", Min = 0, Max = 5, Default = 1, Decimals = 0.01 })
    Hits:Button({ Name = "Preview sound", Callback = function() if playHitSound then playHitSound() end end })
    Hits:Toggle({ Name = "Bullet impacts", Flag = "World_Impacts", Default = false })
end


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
    EspList:Toggle({ Name = "Fill", Flag = "esp_fill", Default = false }):Colorpicker({ Name = "Color", Flag = "esp_fill_color", Default = WHITE })
    EspList:Toggle({ Name = "Glow", Flag = "esp_glow", Default = false }):Colorpicker({ Name = "Color", Flag = "esp_glow_color", Default = WHITE })
    local hp = EspList:Toggle({ Name = "Health bar", Flag = "esp_healthbar", Default = false })
    hp:Colorpicker({ Name = "Full HP", Flag = "esp_healthbar_color_start", Default = Color3.fromRGB(0, 255, 0) })
    hp:Colorpicker({ Name = "Mid HP", Flag = "esp_healthbar_color_middle", Default = Color3.fromRGB(255, 255, 0) })
    hp:Colorpicker({ Name = "Low HP", Flag = "esp_healthbar_color_end", Default = Color3.fromRGB(255, 0, 0) })
    EspList:Toggle({ Name = "Distance", Flag = "esp_distance", Default = false }):Colorpicker({ Name = "Color", Flag = "esp_distance_color", Default = WHITE })
    EspList:Toggle({ Name = "Weapon", Flag = "esp_weapon", Default = false }):Colorpicker({ Name = "Color", Flag = "esp_weapon_color", Default = WHITE })
    EspList:Toggle({ Name = "Skeleton", Flag = "esp_skeleton", Default = false }):Colorpicker({ Name = "Color", Flag = "esp_skeleton_color", Default = WHITE })
    EspList:Toggle({ Name = "Arrows", Flag = "esp_arrows", Default = false }):Colorpicker({ Name = "Color", Flag = "esp_arrow_color", Default = WHITE })
    EspList:Toggle({ Name = "Team indicator", Flag = "esp_team_indicator", Default = false }):Colorpicker({ Name = "Color", Flag = "esp_team_color", Default = WHITE })
    EspList:Toggle({ Name = "Team check", Flag = "esp_team_check", Default = false }):Colorpicker({ Name = "Color", Flag = "esp_friendly_color", Default = Color3.fromRGB(0, 255, 0) })
EspList:Toggle({ Name = "Chams", Flag = "esp_chams", Default = false }):Colorpicker({ Name = "Visible", Flag = "esp_chams_adorn_vis_color", Default = Color3.fromRGB(59, 204, 90) }):Colorpicker({ Name = "Behind walls", Flag = "esp_chams_adorn_occ_color", Default = Color3.fromRGB(59, 144, 204) })

    -- Teams: which Prison Life teams get ESP (filters, so they start on)
    local TeamGuards, TeamInmates, TeamCriminals = VisualsPage:MultiSection({ Sections = { "Guards", "Inmates", "Criminals" }, Side = 1 })
    TeamGuards:Toggle({ Name = "Show guards", Flag = "esp_team_show_guards", Default = true })
    TeamInmates:Toggle({ Name = "Show inmates", Flag = "esp_team_show_inmates", Default = true })
    TeamCriminals:Toggle({ Name = "Show criminals", Flag = "esp_team_show_criminals", Default = true })

    -- ESP settings
    local SetGeneral, SetBox, SetHealth, SetArrows = VisualsPage:MultiSection({ Sections = { "General", "Box", "Health", "Arrows" }, Side = 2 })
    SetGeneral:Toggle({ Name = "Players", Flag = "esp_players", Default = true })
    SetGeneral:Toggle({ Name = "Local player", Flag = "esp_local_player", Default = false })
    SetGeneral:Slider({ Name = "Text size (all text)", Flag = "esp_text_size", Suffix = " px", Min = 8, Max = 24, Default = 12, Decimals = 1 })
    SetGeneral:Slider({ Name = "Thickness", Flag = "esp_skeleton_thickness", Suffix = " px", Min = 1, Max = 4, Default = 1.5, Decimals = 0.1 })
    SetBox:Dropdown({ Name = "Type", Flag = "esp_box_type", Items = { "Normal", "Corner", "Circle" }, Default = "Corner" })
    SetBox:Slider({ Name = "Thickness", Flag = "esp_box_thickness", Suffix = " px", Min = 1, Max = 5, Default = 1, Decimals = 0.1 })
    SetBox:Slider({ Name = "Transparency", Flag = "esp_fill_transparency", Min = 0, Max = 100, Default = 90, Suffix = "%", Decimals = 1 })
    SetBox:Slider({ Name = "Transparency", Flag = "esp_glow_transparency", Min = 0, Max = 100, Default = 72, Suffix = "%", Decimals = 1 })
    SetHealth:Dropdown({ Name = "Position", Flag = "esp_health_position", Items = { "Left", "Right", "Top", "Bottom" }, Default = "Left" })
    SetHealth:Slider({ Name = "Width", Flag = "esp_health_width", Suffix = " px", Min = 1, Max = 6, Default = 1, Decimals = 1 })
    SetArrows:Slider({ Name = "Size", Flag = "esp_arrow_size", Suffix = " px", Min = 8, Max = 32, Default = 14, Decimals = 1 })
    SetArrows:Slider({ Name = "Orbit radius", Flag = "esp_arrow_orbit", Suffix = " px", Min = 50, Max = 300, Default = 100, Decimals = 1 })

    -- Chams (adornment layers)
    local AdornLayers, AdornGlow = VisualsPage:MultiSection({ Sections = { "Layers", "Glow" }, Side = 2 })
    AdornLayers:Slider({ Name = "Behind walls transparency", Flag = "esp_chams_adorn_occ_transp", Min = 0, Max = 100, Default = 70, Suffix = "%", Decimals = 1 })
    AdornLayers:Slider({ Name = "Visible transparency", Flag = "esp_chams_adorn_vis_transp", Min = 0, Max = 100, Default = 35, Suffix = "%", Decimals = 1 })
    AdornLayers:Slider({ Name = "Visible thickness", Flag = "esp_chams_adorn_thickness", Min = 0, Max = 0.6, Default = 0.1, Decimals = 0.01 })
    AdornGlow:Toggle({ Name = "Glow", Flag = "esp_chams_adorn_glow", Default = false })
    AdornGlow:Slider({ Name = "Glow strength", Flag = "esp_chams_adorn_glow_size", Min = 1, Max = 2.5, Default = 1.75, Decimals = 0.01 })
    AdornGlow:Toggle({ Name = "Round head", Flag = "esp_chams_adorn_round_head", Default = true })
    AdornGlow:Slider({ Name = "Head size", Flag = "esp_chams_adorn_head_size", Min = 0.8, Max = 1.6, Default = 1.15, Decimals = 0.01 })

    -- Camera
    local CamFov = WorldPage:Section({ Name = "Camera", Side = 1 })
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
    local GunLook, GunChams, GunTracerTab, GunTimingTab = WorldPage:MultiSection({ Sections = { "Gun", "Chams", "Tracers", "Timing" }, Side = 2 })
GunLook:Toggle({ Name = "Gun color", Flag = "viewmodel_body_color", Default = false }):Colorpicker({ Name = "Color", Flag = "viewmodel_body_color_value", Default = Color3.fromRGB(202, 161, 13) })
GunLook:Slider({ Name = "Gun transparency", Flag = "viewmodel_body_transparency", Min = 0, Max = 1, Default = 0, Decimals = 0.01 })
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
    local BodyForce, BodyExtra = WorldPage:MultiSection({ Sections = { "Forcefield", "Extras" }, Side = 2 })
BodyForce:Toggle({ Name = "Forcefield material", Flag = "arm_material", Default = false }):Colorpicker({ Name = "Color", Flag = "arm_material_color", Default = Color3.fromRGB(255, 255, 255), Alpha = true })
BodyForce:Dropdown({ Name = "Forcefield texture", Flag = "arm_material_texture", Items = FORCEFIELD_TEXTURE_NAMES, Default = "Disabled" })
BodyExtra:Toggle({ Name = "Disable textures", Flag = "arm_disable_textures", Default = false })
BodyExtra:Toggle({ Name = "Remove accessories", Flag = "arm_remove_accessories", Default = false })

    -- Self chams (Highlight)
    local SelfChams = WorldPage:Section({ Name = "Self chams", Side = 2 })
    SelfChams:Toggle({ Name = "Self chams", Flag = "Self_Chams", Default = false }):Colorpicker({ Name = "Fill", Flag = "Self_ChamsColor1", Default = Color3.fromRGB(80, 160, 255) }):Colorpicker({ Name = "Outline", Flag = "Self_ChamsColor2", Default = WHITE })
    SelfChams:Slider({ Name = "Fill transparency", Flag = "Self_ChamsFillAlpha", Min = 0, Max = 1, Default = 0.3, Decimals = 0.01 })
    SelfChams:Slider({ Name = "Outline transparency", Flag = "Self_ChamsOutlineAlpha", Min = 0, Max = 1, Default = 0, Decimals = 0.01 })

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
    local CrossMain, CrossOutline, CrossMotion, CrossArms = WorldPage:MultiSection({ Sections = { "Main", "Outline", "Motion", "Arms" }, Side = 2 })
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

    local About = SpooferPage:Section({ Name = "About", Side = 2 })
    About:Label({ Name = "Client side only: you see the new look, other players still see your real avatar. R6 limbs, Korblox and headless are handled." })
end

-- Players
do
-- Players
do
    local PlayerListSection = PlayersPage:Section({ Name = "Players", Side = 1 })
    local PlayerOptions = PlayersPage:Section({ Name = "Player", Side = 2 })

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
        Items = { "Neutral", "Friendly", "Enemy" },
        Default = "Neutral",
        Callback = function(Value)
            local player = selectedPlayer()
            if player then PlayerRelations[player] = Value end
        end,
    })

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
    Library:SetWatermark("Prison Life")
    Library:SetWatermarkVisibility(true)

    ThemeManager:SetLibrary(Library)
    SaveManager:SetLibrary(Library)
    SaveManager:IgnoreThemeSettings()
    SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
    ThemeManager.DefaultTheme = "Perception"
    ThemeManager:SetFolder("PrisonLife")
    SaveManager:SetFolder("PrisonLife/configs")
    SaveManager:BuildConfigSection(SettingsTab)
    ThemeManager:ApplyToTab(SettingsTab)
end

do
    local LightingService = game:GetService("Lighting")
    local SoundService = game:GetService("SoundService")
    local Debris = game:GetService("Debris")

    local function getFlag(name, default)
        return readFlag(name, default)
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
        if okThree then return filtered end
        warn("Team filter patch skipped: the ESP library changed")
        return patched
    end

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

    -- Teams (Prison Life: Guards = cops, Inmates, Criminals; Neutral is never filtered) ------
    local TEAM_ORDER = { "Guards", "Inmates", "Criminals" }
    local TEAM_FLAGS = { Guards = "esp_team_show_guards", Inmates = "esp_team_show_inmates", Criminals = "esp_team_show_criminals" }

    local function teamAllowed(player)
        local team = player.Team
        local flag = team and TEAM_FLAGS[team.Name]
        if flag then return getFlag(flag, true) end
        return true
    end
    getgenv().TS_ESPFilter = teamAllowed
    onUnload(function() getgenv().TS_ESPFilter = nil end)

    -- The library only rescans its player list every few seconds. Adding and removing a
    -- throw-away Folder in Workspace marks it dirty, so team changes show up within 0.2s.
    local lastTeamSignature
    local function checkTeamChanges()
        local parts = {}
        for _, name in ipairs(TEAM_ORDER) do table.insert(parts, tostring(getFlag(TEAM_FLAGS[name], true))) end
        for _, player in ipairs(Players:GetPlayers()) do
            table.insert(parts, player.Team and player.Team.Name or "-")
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
        put("BoxFill.Transparency", math.clamp(getFlag("esp_fill_transparency", 90) / 100, 0, 1))
        put("BoxFill.Gradient.Enabled", getFlag("esp_fill_gradient", false))
        put("BoxFill.Gradient.Color1", getColor("esp_fill_gradient_1", getColor("esp_fill_color", Color3.fromRGB(255, 255, 255))))
        put("BoxFill.Gradient.Color2", getColor("esp_fill_gradient_2", getColor("esp_fill_color", Color3.fromRGB(255, 255, 255)):Lerp(Color3.new(1,1,1), 0.25)))
        put("BoxFill.Gradient.Color3", getColor("esp_fill_gradient_3", getColor("esp_fill_color", Color3.fromRGB(255, 255, 255))))

        put("Glow", getFlag("esp_glow", false))
        put("GlowColor", getColor("esp_glow_color", Color3.fromRGB(255, 255, 255)))
        put("GlowTransparency", math.clamp(getFlag("esp_glow_transparency", 72) / 100, 0, 1))
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

    local function updateAdornChams()
        local active = getFlag("esp_enabled", false)
            and getFlag("esp_chams", false)
        if not active then
            for player in pairs(adornData) do clearAdornments(player) end
            return
        end

        local behindColor = getColor("esp_chams_adorn_occ_color", Color3.fromRGB(59, 144, 204))
        local behindTransparency = math.clamp(getFlag("esp_chams_adorn_occ_transp", 70) / 100, 0, 1)
        local visibleColor = getColor("esp_chams_adorn_vis_color", Color3.fromRGB(59, 204, 90))
        local visibleTransparency = math.clamp(getFlag("esp_chams_adorn_vis_transp", 35) / 100, 0, 1)
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
                        if pair.signature ~= signature or pair.partSize ~= size then
                            pair.signature = signature
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
                            pair.visible.Color3 = visibleColor
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

    local function updateSkeletons()
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
                                inner.Color = color
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

    -- Hit feedback ---------------------------------------------------
    -- Only bullets YOU fire count. The tracer hook below calls onLocalShot(origin, target) for
    -- each of your shots (the origin is your tool's Muzzle). The shot's path is raycast to find
    -- which player it hits, and that player is marked as "expecting damage from you" for a short
    -- window. Hit sound and notification fire only when that player's health then drops, so
    -- damage from anyone else in the server never triggers them.
    local HIT_WINDOW = 0.8
    local lastHitNotify = 0
    local hitConnections = {}
    local pendingHits = {} -- [player] = { expiry, expiry, ... } (one entry per pellet / bullet)

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

    local function onHit(player, damage, killed)
        if getFlag("World_HitSound", false) then
            playHitSound()
        end
        if getFlag("World_HitNotify", false) and os.clock() - lastHitNotify > 0.25 then
            lastHitNotify = os.clock()
            Library:Notify(string.format("Hit %s for %d%s", player.Name, math.floor(damage + 0.5), killed and " (kill)" or ""), 2)
        end
    end

    local function onLocalShot(origin, target)
        local offset = target - origin
        if offset.Magnitude < 0.1 then return end

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
        if not victim or victim == LocalPlayer then return end

        local queue = pendingHits[victim]
        if not queue then
            queue = {}
            pendingHits[victim] = queue
        end
        table.insert(queue, os.clock() + HIT_WINDOW)
    end

    local function consumePendingHit(player)
        local queue = pendingHits[player]
        if not queue then return false end
        local now = os.clock()
        while #queue > 0 and queue[1] < now do table.remove(queue, 1) end
        if #queue == 0 then return false end
        table.remove(queue, 1)
        return true
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
                if damage > 0 and consumePendingHit(player) then
                    onHit(player, damage, health <= 0)
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

    -- Gun: the equipped Tool ---------------------------------------------
    local function gunConfig()
        local colorOn = getFlag("viewmodel_body_color", false)
        local material = safeEnumMaterial(getFlag("viewmodel_material_value", "Default"))
        local transparency = getFlag("viewmodel_body_transparency", 0)
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
        selfHighlight.FillTransparency = getFlag("Self_ChamsFillAlpha", 0.3)
        selfHighlight.OutlineTransparency = getFlag("Self_ChamsOutlineAlpha", 0)
    end

    local function updateLocalVisuals()
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

    local function updateBlur()
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
    local function updateTracers(dt)
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

    local function updateCrosshair()
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

    local function updateWeather()
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

    -- Avatar changer (Spoofer tab) -----------------------------------------------------
    -- Rebuilds YOUR character's look from another user's avatar. It is client side only: you
    -- see the new look, everyone else still sees your real avatar. R6 limbs (CharacterMesh,
    -- Korblox) and headless are handled. The Spoofer tab's buttons call SpooferActions.
    do
        local HEADLESS_IDS = { [15093053680] = true, [134082579] = true, [4562128874] = true }
        local KORBLOX_LEFT, KORBLOX_RIGHT = 139607673, 139607718
        local lastUid
        local busy = false

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

        local function wearAccessory(char, acc)
            if not char or not acc or not acc:IsA("Accessory") then return false end
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
            end)
            return ok
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
                            if wearAccessory(char, d) then applied = true end
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
                        if wearAccessory(char, object) then applied = true end
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
                for _, d in ipairs(head:GetChildren()) do
                    if d:IsA("Decal") then pcall(function() d:Destroy() end) end
                end
                for _, d in ipairs(sourceHead:GetChildren()) do
                    if d:IsA("Decal") then pcall(function() d:Clone().Parent = head end) end
                end
                local sourceMesh = sourceHead:FindFirstChildOfClass("SpecialMesh")
                if sourceMesh then copySpecialMesh(head, sourceMesh) end
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
                            if wearAccessory(char, object) then count += 1 end
                        else
                            for _, d in ipairs(object:GetDescendants()) do
                                if d:IsA("Accessory") then
                                    if string.find(string.lower(d.Name), "headless", 1, true) then headless = true end
                                    if wearAccessory(char, d) then count += 1 end
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
            notify("Avatar changer: fetching " .. tostring(uid) .. "...")
            lastUid = uid

            local model, desc = fetchModel(uid, humanoid.RigType)
            if not model then
                if desc then
                    pcall(function()
                        if humanoid.ApplyDescriptionAsync then humanoid:ApplyDescriptionAsync(desc) else humanoid:ApplyDescription(desc) end
                    end)
                    if humanoid.RigType == Enum.HumanoidRigType.R6 then applyR6MeshesFromDescription(char, desc) end
                    notify("Avatar changer: applied the description only (no model)")
                    return true
                end
                notify("Avatar changer: could not fetch that avatar")
                return false
            end

            stripAppearance(char) -- the fetch yields; make sure nothing came back meanwhile
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
    end

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


pcall(function() warn("[Prison Life] building done, loading config")
SaveManager:LoadAutoloadConfig() end)
Library:Notify("Prison Life loaded", 4)

warn("[Prison Life] script finished")
end, debug.traceback)
if not __plOk then
    warn("[Prison Life] FAILED:\n" .. tostring(__plErr))
end
