local ThemeManager = { Custom = {}, _memory = {}, _files = {}, _built = {} }
ThemeManager.BuiltInThemes = {
    gold = { 1, { accent = "#c9a96e", bg = "#0c0c0e", panel = "#15151a", border = "#2a2a31", text = "#ededf2", style = "gradient",
        btnBg = "#1e1e23", btnBd = "#000000", btnTx = "#c4c4cd", btnHv = "#26262c", ddBg = "#1c1c21", ddBd = "#000000", ddTx = "#c4c4cd", ddlBg = "#111114", ddHl = "#c9a96e" } },
    midnight = { 2, { accent = "#5b8def", bg = "#0a0b0f", panel = "#13151c", border = "#2a2e3b", text = "#e8ebf3", style = "gradient" } },
    crimson = { 3, { accent = "#e5484d", bg = "#0d0a0b", panel = "#171315", border = "#2f2629", text = "#f0e9ea", style = "gradient" } },
    emerald = { 4, { accent = "#2fbf7f", bg = "#090c0b", panel = "#121715", border = "#26302c", text = "#e7efeb", style = "gradient" } },
    amethyst = { 5, { accent = "#a27cf0", bg = "#0c0a0f", panel = "#15131a", border = "#2c2735", text = "#ece9f3", style = "gradient" } },
    amber = { 6, { accent = "#f0a03c", bg = "#0d0b09", panel = "#171411", border = "#2f2a24", text = "#f1ece5", style = "gradient" } },
    rose = { 7, { accent = "#ec6a9a", bg = "#0d0a0c", panel = "#171316", border = "#30272c", text = "#f1e9ed", style = "gradient" } },
    cyan = { 8, { accent = "#38c6e0", bg = "#090c0d", panel = "#121618", border = "#262e32", text = "#e6eef0", style = "gradient" } },
    mono = { 9, { accent = "#f2f2f2", bg = "#0b0b0b", panel = "#161616", border = "#2e2e2e", text = "#ededed", style = "flat" } },
    lime = { 10, { accent = "#a6e23a", bg = "#0a0c09", panel = "#131612", border = "#282d23", text = "#ebf0e6", style = "gradient" } },
}
ThemeManager.DefaultTheme = "gold"
ThemeManager.Groups = {
    { "colours", "th.cols", { { "bg", "Background" }, { "panel", "Main" }, { "accent", "Accent" }, { "border", "Outline" }, { "text", "Font" } } },
    { "buttons", "th.btns", { { "btnBg", "Button background" }, { "btnBd", "Button border" }, { "btnTx", "Button text" }, { "btnHv", "Button hover" } } },
    { "dropdowns", "th.dds", { { "ddBg", "Box background" }, { "ddBd", "Box border" }, { "ddTx", "Box text" }, { "ddlBg", "List background" }, { "ddHl", "Highlighted option" } } },
}

local Library, Util, Theme, Store, Exec, Anim, Icons

local function need()
    if not Library then error("[aster] ThemeManager:SetLibrary(library) first", 3) end
end

local function folder()
    return Store.Themes or (Store.Root .. "/themes")
end

local function file(name)
    return folder() .. "/" .. name .. ".json"
end

local function ensure()
    pcall(Store.ensure, folder())
end

local function read(path)
    if not Exec.hasFs then return ThemeManager._memory[path] end
    local ok, text = pcall(function()
        if Exec.fs.isfile(path) then return Exec.fs.read(path) end
        return nil
    end)
    if ok and type(text) == "string" then return text end
    return nil
end

local function write(path, text)
    if not Exec.hasFs then
        ThemeManager._memory[path] = text
        return true
    end
    ensure()
    return (pcall(Exec.fs.write, path, text))
end

local function remove(path)
    if not Exec.hasFs then
        local had = ThemeManager._memory[path] ~= nil
        ThemeManager._memory[path] = nil
        return had
    end
    return Exec.fs.delete ~= nil and (pcall(Exec.fs.delete, path))
end

local function names()
    local out = {}
    if Exec.hasFs then
        ensure()
        local ok, files = pcall(function() return Exec.fs.list and Exec.fs.list(folder()) or {} end)
        for _, path in ipairs(ok and type(files) == "table" and files or {}) do
            local name = string.match(string.gsub(tostring(path), "\\", "/"), "([^/]+)%.json$")
            if name then out[#out + 1] = name end
        end
    else
        local prefix = folder() .. "/"
        for path in pairs(ThemeManager._memory) do
            if string.sub(path, 1, #prefix) == prefix then
                local name = string.match(string.sub(path, #prefix + 1), "^([^/]+)%.json$")
                if name then out[#out + 1] = name end
            end
        end
    end
    table.sort(out)
    return out
end

local function notify(text, kind)
    if Library and Library.Notify then Library:Notify("theme", text, kind) end
end

local function builtinsOf(target)
    if type(target) ~= "table" then return nil end
    if target.Cards and target.Pages and type(target.Tab) == "table" then return target end
    local win = type(target.Card) ~= "function" and target.Window
    local b = type(win) == "table" and win._builtins
    if b and b.Tab == target then return b end
    return nil
end

function ThemeManager:SetLibrary(lib)
    Library = lib
    local I = lib._
    Util, Theme, Store, Exec, Anim, Icons = I.Util, I.Theme, I.Store, I.Exec, I.Anim, I.Icons
    self.Library = lib
    self.Changed = Util.Signal.new()
    self._built, self._init, self._default, self._complete = {}, nil, nil, {}
    lib._maid:Add(self.Changed)
    lib.ThemeManager = self
    return self
end

function ThemeManager.fix(v)
    if type(v) ~= "table" then return nil end
    local out = {}
    for _, key in ipairs(Theme.Keys) do
        if type(v[key]) == "string" and Util.hex(v[key]) then out[key] = Util.toHex(Util.hex(v[key])) end
    end
    if v.style == "flat" or v.style == "gradient" then out.style = v.style end
    return out
end

function ThemeManager.name(v)
    return Store.cfgName(v)
end

local function complete(p)
    local function mix(a, b, t) return Util.toHex(Util.mix(p[a], p[b], t)) end
    p.btnBg = p.btnBg or mix("panel", "text", 0.05)
    p.btnBd = p.btnBd or "#000000"
    p.btnTx = p.btnTx or mix("text", "bg", 0.2)
    p.btnHv = p.btnHv or mix("panel", "text", 0.1)
    p.ddBg = p.ddBg or mix("panel", "text", 0.04)
    p.ddBd = p.ddBd or "#000000"
    p.ddTx = p.ddTx or p.btnTx
    p.ddlBg = p.ddlBg or mix("panel", "bg", 0.5)
    p.ddHl = p.ddHl or p.accent
    return p
end

function ThemeManager:BuiltInNames()
    local out = {}
    for name, entry in pairs(self.BuiltInThemes) do
        if type(entry) == "table" and type(entry[2]) == "table" then out[#out + 1] = name end
    end
    table.sort(out, function(a, b)
        local x, y = tonumber(self.BuiltInThemes[a][1]) or math.huge, tonumber(self.BuiltInThemes[b][1]) or math.huge
        if x ~= y then return x < y end
        return a < b
    end)
    return out
end

function ThemeManager:GetBuiltInTheme(name)
    need()
    local entry = type(name) == "string" and self.BuiltInThemes[name]
    if type(entry) ~= "table" or type(entry[2]) ~= "table" then return nil end
    return complete(Util.copy(entry[2]))
end

local function builtin(self, name)
    local entry = self.BuiltInThemes[name]
    local hit = self._complete[name]
    if not hit or hit[1] ~= entry[2] then
        hit = { entry[2], complete(Util.copy(entry[2])) }
        self._complete[name] = hit
    end
    return hit[2]
end

function ThemeManager:SetFolder(name)
    if type(name) == "string" and name ~= "" then
        self.Folder = name
        if Store and Store.migrate then pcall(Store.migrate, name) end
    end
    self._default = nil
    if Library then self:ReloadCustomThemes() end
end

function ThemeManager:IsBuiltIn(name)
    need()
    local entry = type(name) == "string" and self.BuiltInThemes[name]
    return type(entry) == "table" and type(entry[2]) == "table"
end

local function stored(name)
    return file(ThemeManager._files[name] or name)
end

function ThemeManager:ReloadCustomThemes()
    need()
    self.Custom, self._files = {}, {}
    for _, raw in ipairs(names()) do
        local name = self.name(raw)
        local data = name ~= "" and self.fix(Util.unjson(read(file(raw))))
        if data and next(data) and not self:IsBuiltIn(name) and not self.Custom[name] then
            self.Custom[name] = data
            self._files[name] = raw
        end
    end
    local list = {}
    for name in pairs(self.Custom) do list[#list + 1] = name end
    table.sort(list)
    return list
end

function ThemeManager:GetCustomTheme(name)
    name = self.name(name)
    return self.Custom[name] and Util.copy(self.Custom[name]) or nil
end

function ThemeManager:GetTheme(name)
    need()
    return self:GetBuiltInTheme(name) or self:GetCustomTheme(name)
end

function ThemeManager:List()
    need()
    local default = self:GetDefault()
    local out = {}
    for _, name in ipairs(self:BuiltInNames()) do
        out[#out + 1] = { key = name, text = name, meta = "built-in", marker = name == default and "default" or nil }
    end
    local custom = {}
    for name in pairs(self.Custom) do custom[#custom + 1] = name end
    table.sort(custom)
    for _, name in ipairs(custom) do
        out[#out + 1] = { key = name, text = name, meta = "custom", marker = name == default and "default" or nil }
    end
    return out
end

local function same(data)
    for _, key in ipairs(Theme.Keys) do
        if data[key] and Util.toHex(Util.hex(data[key])) ~= Util.toHex(Util.hex(Theme.Base[key])) then return false end
    end
    return (data.style or Theme.Base.style) == Theme.Base.style
end

function ThemeManager:Match()
    need()
    local picked = self.Picked
    if picked and self.Custom[picked] and same(self.Custom[picked]) then return picked end
    for _, name in ipairs(self:BuiltInNames()) do
        if same(builtin(self, name)) then return name end
    end
    local list = {}
    for name in pairs(self.Custom) do list[#list + 1] = name end
    table.sort(list)
    for _, name in ipairs(list) do
        if same(self.Custom[name]) then return name end
    end
    return "custom"
end

function ThemeManager:ApplyTheme(name)
    need()
    local data = self:GetTheme(name)
    if not data then return false end
    if self:IsBuiltIn(name) then self.Builtin = name end
    self.Picked = self.name(name)
    Theme:Set(data)
    return true
end

function ThemeManager:Reset(name)
    need()
    name = name and self.name(name) or ""
    if not self:IsBuiltIn(name) then name = self.Builtin or self.DefaultTheme end
    return self:ApplyTheme(name) and name or nil
end

function ThemeManager:SaveCustomTheme(name)
    need()
    name = self.name(name)
    if name == "" then return false, "type a name first" end
    if self:IsBuiltIn(name) then return false, name .. " is a built-in theme" end
    if name == "custom" then return false, "custom is a reserved name" end
    local text = Util.json(Theme:Export())
    local existed = self.Custom[name] ~= nil
    if not text or not write(stored(name), text) then return false, "could not write " .. name end
    self.Picked = name
    self:ReloadCustomThemes()
    self.Changed:Fire("save", name)
    return true, name, existed
end

function ThemeManager:DeleteCustomTheme(name)
    need()
    name = self.name(name)
    if not self.Custom[name] then return false end
    if not remove(stored(name)) then return false end
    if self:GetDefault() == name and remove(folder() .. "/default.txt") then self._default = false end
    self:ReloadCustomThemes()
    self.Changed:Fire("delete", name)
    return true
end

function ThemeManager:SaveDefault(name)
    need()
    name = self.name(name)
    if not self:GetTheme(name) then return false end
    if not write(folder() .. "/default.txt", name) then return false end
    self._default = name
    self.Changed:Fire("default", name)
    return true
end

function ThemeManager:GetDefault()
    need()
    if self._default == nil then
        local name = read(folder() .. "/default.txt")
        name = name and self.name(name) or ""
        self._default = name ~= "" and name or false
    end
    return self._default or nil
end

function ThemeManager:LoadDefault()
    self._default = nil
    local name = self:GetDefault()
    if not name then return false end
    return self:ApplyTheme(name)
end

function ThemeManager:Init()
    need()
    if self._init then return end
    self._init = true
    self:ReloadCustomThemes()
    if not self:LoadDefault() then
        local saved = Store.get("theme", nil, self.fix)
        if saved and next(saved) then Theme:Set(saved) end
    end
    local pending
    self._persist = function()
        if pending then pending:Stop() end
        pending = Anim.after(0.4, function()
            pending = nil
            Store.put("theme", Theme:Export())
            Store.put("theme.anim", self:Animations())
        end)
    end
    Library._maid:Add(Theme.Changed:Connect(self._persist))
end

function ThemeManager:Animations()
    local out = {}
    for key, el in pairs(self._colours or {}) do
        if not el.Destroyed and el._anim.mode ~= "static" then
            local mode, speed, second, min = el:Animation()
            out[key] = { mode = mode, speed = speed, second = Util.toHex(second), min = min }
        end
    end
    return out
end

function ThemeManager:ApplyToCard(card, editor)
    self:Init()
    local TM = self
    editor = editor or card
    local h = { Card = card, Editor = editor, Colours = {} }
    local syncing = false
    local function key(v)
        return (string.gsub(tostring(v or ""), " %(default%)$", ""))
    end
    local function labels()
        local out = {}
        for _, item in ipairs(TM:List()) do out[#out + 1] = item.marker and (item.key .. " (" .. item.marker .. ")") or item.key end
        return out
    end
    local function current()
        local name = TM:Match()
        return name == TM:GetDefault() and name .. " (default)" or name
    end
    h.List = card:Dropdown({ name = "Theme", options = labels, free = true, default = current(), save = false, callback = function(v)
        local name = key(v)
        if not syncing and name ~= "" and name ~= "custom" then TM:ApplyTheme(name) end
    end })
    h.Preset = h.List
    h.Name = card:Input({ placeholder = "theme name", max = 24 })
    local function target()
        local typed = TM.name(h.Name.Value)
        if typed ~= "" then return typed end
        local picked = key(h.List.Value)
        if picked ~= "" and picked ~= "custom" then return picked end
        return nil
    end
    local function save()
        local ok, why, existed = TM:SaveCustomTheme(target() or "")
        if ok then h.Name:Set("") end
        notify(ok and ((existed and "overwrote " or "saved ") .. why) or why, ok and "ok" or "warn")
    end
    h.Name.Opts.enter = save
    local armed, doomed
    local function disarm()
        if armed then armed:Stop() end
        armed, doomed = nil, nil
        if h.Actions and not h.Actions.Destroyed then h.Actions:SetText(3, "Delete") end
    end
    h.Actions = card:Buttons({ items = {
        { name = "Load", callback = function()
            local name = target()
            if not name or not TM:ApplyTheme(name) then return notify("pick a theme first", "warn") end
            notify("loaded " .. name, "ok")
        end },
        { name = "Save", primary = true, callback = save },
        { name = "Delete", callback = function()
            if not armed then
                local name = target()
                if not name or not TM.Custom[name] then return notify("pick a custom theme", "warn") end
                h.Actions:SetText(3, "Confirm")
                armed, doomed = Anim.after(2.5, disarm), name
                return
            end
            local name = doomed
            disarm()
            if TM:DeleteCustomTheme(name) then notify("deleted " .. name, "warn") end
        end },
    } })
    h.Extra = card:Buttons({ items = {
        { name = "Set as default", callback = function()
            local name = target() or TM:Match()
            if not TM:SaveDefault(name) then return notify("save the theme first", "warn") end
            notify(name .. " loads on inject", "ok")
        end },
        { name = "Reset", callback = function()
            local picked = key(h.List.Value)
            local name = TM:Reset(TM:IsBuiltIn(picked) and picked or nil)
            notify("reset to " .. tostring(name), "ok")
        end },
        { name = "Refresh", callback = function()
            TM:ReloadCustomThemes()
            h.List:SetOptions(labels)
            notify(#TM:List() .. " themes found")
        end },
    } })
    h.Style = editor:Dropdown({ name = "Fill style", options = { "flat", "gradient" }, default = Theme.Base.style, save = false, callback = function(v)
        if not syncing then Theme:Set({ style = v }) end
    end })
    if Icons.SetShown and Icons.shown then
        h.Icons = editor:Dropdown({ name = "Strip icons", options = { "on", "off" }, default = Icons.shown() and "on" or "off", save = false, callback = function(v)
            Icons.SetShown(v == "on")
        end })
    end
    for _, group in ipairs(self.Groups) do
        local section = editor:Section({ name = group[1], key = group[2], open = group[2] == "th.cols" })
        for _, entry in ipairs(group[3]) do
            local key = entry[1]
            h.Colours[key] = section:Color({ name = entry[2], default = Theme.Base[key], opaque = true, gradient = key == "accent" or nil, save = false, callback = function(v, el)
                if syncing then return end
                if not (el and el._ticking) then return Theme:Set({ [key] = v }) end
                Theme:Live(key, v)
                local mode, speed, second, min = el:Animation()
                local sig = mode .. speed .. Util.toHex(second) .. min
                if el._themeSig ~= sig then
                    el._themeSig = sig
                    if TM._persist then TM._persist() end
                end
            end })
        end
    end
    self._colours = h.Colours
    local anims = Store.get("theme.anim")
    for key, a in pairs(type(anims) == "table" and anims or {}) do
        local el = h.Colours[key]
        if el and type(a) == "table" and type(a.mode) == "string" then el:SetAnimation(a.mode, a.speed, a.second, a.min) end
    end
    local function sync()
        syncing = true
        for key, el in pairs(h.Colours) do
            if not el.Destroyed and (el._anim.mode == "static" or Util.toHex(el._base) ~= Theme.Base[key]) then el:Set(Theme.Base[key], true) end
        end
        if not h.Style.Destroyed then h.Style:Set(Theme.Base.style, true) end
        if not h.List.Destroyed then h.List:Set(current(), true) end
        syncing = false
    end
    h.List._maid:Add(Theme.Changed:Connect(sync))
    h.List._maid:Add(self.Changed:Connect(function()
        disarm()
        if h.List.Destroyed then return end
        h.List:SetOptions(labels)
        sync()
    end))
    h.Sync = sync
    return h
end

function ThemeManager:ApplyToGroupbox(card)
    need()
    return self:ApplyToCard(card)
end

function ThemeManager:ApplyToTab(target, opts)
    need()
    opts = opts or {}
    local b = builtinsOf(target)
    local page
    if b then
        b.Pages.theming = b.Pages.theming or b.Tab:Page({ name = "theming", icon = "theme" })
        page = b.Pages.theming
    elseif type(target) == "table" and type(target.Card) == "function" then
        page = target
    elseif type(target) == "table" and type(target.Page) == "function" then
        page = target:Page({ name = opts.page or "theme", icon = opts.icon or "theme" })
    end
    if not page then error("[aster] ApplyToTab needs a page or a tab", 2) end
    local h = self._built[page]
    if not h or h.List.Destroyed then
        local side = opts.side or "left"
        local card = page:Card({ name = opts.name or "themes", side = side })
        local editor = page:Card({ name = "theme editor", side = side == "left" and "right" or "left" })
        h = self:ApplyToCard(card, editor)
        self._built[page] = h
    end
    if b then b.Theme, b.Cards.theme, b.Cards.themeEditor = h, h.Card, h.Editor end
    return h, h.Card
end
ThemeManager.ApplyToPage = ThemeManager.ApplyToTab

return ThemeManager
