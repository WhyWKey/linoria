local SaveManager = { Ignore = {}, IgnorePrefixes = {}, _built = {} }

local Library, Store, Anim

local function need()
    if not Library then error("[aster] SaveManager:SetLibrary(library) first", 3) end
end

local function notify(text, kind)
    if Library and Library.Notify then Library:Notify("config", text, kind) end
end

local function builtinsOf(target)
    if type(target) ~= "table" then return nil end
    if target.Cards and target.Pages and type(target.Tab) == "table" then return target end
    local win = type(target.Card) ~= "function" and target.Window
    local b = type(win) == "table" and win._builtins
    if b and b.Tab == target then return b end
    return nil
end

local function root()
    if not SaveManager.Folder then return end
    Store.ConfigRoot = Store.base(SaveManager.Folder)
    if Store.migrate then pcall(Store.migrate, SaveManager.Folder) end
end

function SaveManager:SetLibrary(lib)
    Library = lib
    local I = lib._
    Store, Anim = I.Store, I.Anim
    self.Library = lib
    self._built = {}
    lib.SaveManager = self
    Store.skip = function(flag) return self:IsIgnored(flag) end
    root()
    return self
end

function SaveManager:SetFolder(name)
    if type(name) == "string" and name ~= "" then self.Folder = name end
    if Library then
        root()
        pcall(Store.ensure, Store.configDir())
    end
end

function SaveManager:IsIgnored(flag)
    if type(flag) ~= "string" then return false end
    if self.Ignore[flag] then return true end
    for _, prefix in ipairs(self.IgnorePrefixes) do
        if string.sub(flag, 1, #prefix) == prefix then return true end
    end
    return false
end

function SaveManager:SetIgnoreIndexes(list)
    for key, value in pairs(type(list) == "table" and list or {}) do
        if type(value) == "string" then self.Ignore[value] = true elseif type(key) == "string" and value then self.Ignore[key] = true end
    end
end

function SaveManager:IgnoreThemeSettings()
    for _, prefix in ipairs(self.IgnorePrefixes) do
        if prefix == "th." then return end
    end
    self.IgnorePrefixes[#self.IgnorePrefixes + 1] = "th."
end

function SaveManager:Save(name)
    need()
    if name ~= nil and Store.cfgName(name) == "" then return false, "type a name first" end
    local ran, ok, why = pcall(Store.save, name)
    if not ran then return false, tostring(ok) end
    return ok, why
end

function SaveManager:Load(name)
    need()
    if name ~= nil and Store.cfgName(name) == "" then return false, "no config is selected" end
    local ran, ok, why = pcall(Store.load, name)
    if not ran then return false, tostring(ok) end
    return ok, why
end

function SaveManager:Delete(name)
    need()
    local ran, ok = pcall(Store.delete, name)
    return ran and ok == true
end

function SaveManager:Refresh()
    need()
    local out = {}
    local ran, list = pcall(Store.list)
    for _, entry in ipairs(ran and list or {}) do out[#out + 1] = entry.name end
    for _, h in pairs(self._built) do
        if not h.List.Destroyed then h.List:Refresh() end
    end
    return out
end
SaveManager.RefreshConfigList = SaveManager.Refresh

function SaveManager:SetAutoload(name)
    need()
    if name ~= nil and not Store.exists(name) then return false end
    return Store.autoload(name)
end

function SaveManager:GetAutoload()
    need()
    return Store.getAutoload()
end

function SaveManager:LoadAutoloadConfig()
    need()
    local name = Store.getAutoload()
    if not name then return false end
    local ok, why = self:Load(name)
    notify(ok and ("auto loaded " .. name) or ("could not autoload " .. name .. ": " .. tostring(why)), ok and "ok" or "warn")
    return ok, why
end

function SaveManager:BuildConfigSection(target, opts)
    need()
    opts = opts or {}
    local b = builtinsOf(target)
    local page
    if b then
        b.Pages.configs = b.Pages.configs or b.Tab:Page({ name = "configs", icon = "gear" })
        page = b.Pages.configs
    elseif type(target) == "table" and type(target.Card) == "function" then
        page = target
    elseif type(target) == "table" and type(target.Page) == "function" then
        page = target:Page({ name = opts.page or "configs", icon = opts.icon or "gear" })
    end
    if not page then error("[aster] BuildConfigSection needs a page or a tab", 2) end
    local h = self._built[page]
    if not h or h.List.Destroyed then
        h = self:_build(page, opts)
        self._built[page] = h
    end
    if b then
        b.ConfigSection = h
        b.Configs, b.ConfigName, b.ConfigButtons, b.Autoload = h.List, h.Name, h.Buttons, h.Autoload
        b.Cards.configs, b.Cards.autoload = h.Card, h.Side
    end
    return h
end

function SaveManager:_build(page, opts)
    local SM = self
    local h = {}
    local card = page:Card({ name = opts.name or "configs", side = opts.side or "left" })
    local list = card:Configs({ rows = opts.rows or 7 })
    local nameBox = card:Input({ placeholder = "config name", max = 24 })
    h.Card, h.List, h.Name = card, list, nameBox
    local function create()
        local name = Store.cfgName(nameBox.Value)
        if name == "" then return notify("type a name first", "warn") end
        if Store.exists(name) then return notify(name .. " already exists", "warn") end
        local ok, why = SM:Save(name)
        if not ok then return notify(tostring(why), "warn") end
        nameBox:Set("")
        notify("created " .. name, "ok")
    end
    nameBox.Opts.enter = create
    h.Create = card:Button({ name = "Create", callback = create })
    local function selected()
        local name = list:Selected()
        if not name or not Store.exists(name) then
            notify("pick a config first", "warn")
            return nil
        end
        return name
    end
    local armed
    local function disarm()
        if armed then armed:Stop() end
        armed = nil
        if h.Buttons and not h.Buttons.Destroyed then h.Buttons:SetText(3, "Delete") end
    end
    h.Buttons = card:Buttons({ items = {
        { name = "Load", callback = function()
            local name = selected()
            if not name then return end
            local ok, why = SM:Load(name)
            notify(ok and ("loaded " .. name) or tostring(why), ok and "ok" or "warn")
        end },
        { name = "Save", primary = true, callback = function()
            local name = list:Selected() or Store.Selected
            local ok, why = SM:Save(name)
            notify(ok and ("saved " .. Store.cfgName(name)) or tostring(why), ok and "ok" or "warn")
        end },
        { name = "Delete", callback = function()
            local name = selected()
            if not name then return end
            if not armed then
                h.Buttons:SetText(3, "Confirm")
                armed = Anim.after(2.5, disarm)
                return
            end
            disarm()
            if SM:Delete(name) then notify("deleted " .. name, "warn") end
        end },
    } })
    h.Extra = card:Buttons({ items = {
        { name = "Autoload", callback = function()
            local name = selected()
            if not name then return end
            SM:SetAutoload(name)
            notify(name .. " loads on inject", "ok")
        end },
        { name = "Refresh", callback = function()
            notify(#SM:Refresh() .. " configs found")
        end },
    } })
    local side = page:Card({ name = "autoload", side = "right" })
    local auto
    auto = side:Toggle({ name = "Load on inject", default = Store.getAutoload() ~= nil, save = false, callback = function(v)
        if v then
            local name = list:Selected() or Store.Selected
            if Store.exists(name) then SM:SetAutoload(name) else
                notify("save a config first", "warn")
                auto:Set(false, true)
            end
        else
            SM:SetAutoload(nil)
        end
    end })
    h.Side, h.Autoload = side, auto
    list._maid:Add(Store.Changed:Connect(function()
        disarm()
        if not auto.Destroyed then auto:Set(Store.getAutoload() ~= nil, true) end
    end))
    return h
end

return SaveManager
