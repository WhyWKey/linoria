local httpService = game:GetService('HttpService')

local function SafeIsFile(Path)
	local Ok, Result = pcall(function()
		return type(isfile) == 'function' and isfile(Path)
	end)
	return Ok and Result or false
end

local function SafeRead(Path)
	local Ok, Result = pcall(function()
		return readfile(Path)
	end)
	return Ok and Result or nil
end

local function SafeWrite(Path, Content)
	return pcall(function()
		writefile(Path, Content)
	end)
end

local ThemeManager = {} do
	ThemeManager.Folder = 'Aster'
	ThemeManager.DefaultTheme = 'Aster Violet'
	ThemeManager.HudToggles = true -- watermark / keybind list visibility toggles in Appearance
	ThemeManager.Applying = false

	ThemeManager.Library = nil
	-- { order, { colours as hex, derived keys optional }, { appearance settings, optional } }
	ThemeManager.BuiltInThemes = {
		['Aster Violet'] = { 1, { FontColor = 'e9e8f5', MainColor = '14141c', AccentColor = '8b5cf6', AccentColor2 = '4aa8ff', BackgroundColor = '0b0b10', OutlineColor = '262633', RiskColor = 'f43f5e' } },
		['Aurora']       = { 2, { FontColor = 'e4f2f0', MainColor = '101a1d', AccentColor = '22d3ee', AccentColor2 = '34d399', BackgroundColor = '090f11', OutlineColor = '1f3036', RiskColor = 'fb7185' } },
		['Sakura']       = { 3, { FontColor = 'f5e8ef', MainColor = '1c141a', AccentColor = 'f472b6', AccentColor2 = 'fb923c', BackgroundColor = '110c10', OutlineColor = '33242e', RiskColor = 'ef4444' } },
		['Ember']        = { 4, { FontColor = 'f3e9e4', MainColor = '1b1412', AccentColor = 'f97316', AccentColor2 = 'ef4444', BackgroundColor = '100b0a', OutlineColor = '372420', RiskColor = 'dc2626' } },
		['Mono']         = { 5, { FontColor = 'e8e8ea', MainColor = '151516', AccentColor = 'e5e7eb', AccentColor2 = '8b8b93', BackgroundColor = '0c0c0d', OutlineColor = '2a2a2d', RiskColor = 'f87171' } },
		['Orange Tonka'] = { 6, { FontColor = 'efe8e1', MainColor = '1c1a18', AccentColor = 'e07a2f', AccentColor2 = 'f5b061', BackgroundColor = '110f0e', OutlineColor = '342f2a', RiskColor = 'e5484d' } },
		['Bitch-Purple'] = { 7, { FontColor = 'ece8f4', MainColor = '1a1820', AccentColor = 'a86bf7', AccentColor2 = 'e879f9', BackgroundColor = '110f15', OutlineColor = '2f2b3a', RiskColor = 'f43f5e' } },
		['Midnight']     = { 8, { FontColor = 'dfe7f7', MainColor = '111a2b', AccentColor = '3b82f6', AccentColor2 = '22d3ee', BackgroundColor = '080d19', OutlineColor = '22324f', RiskColor = 'f43f5e' } },
		['Forest']       = { 9, { FontColor = 'e6f0e7', MainColor = '121c16', AccentColor = '3fae6a', AccentColor2 = 'a3e635', BackgroundColor = '0b110d', OutlineColor = '24382c', RiskColor = 'ef4444' } },
		['Rose']         = { 10, { FontColor = 'f7e8ec', MainColor = '1c1317', AccentColor = 'f43f5e', AccentColor2 = 'fb7185', BackgroundColor = '120b0e', OutlineColor = '3a242c', RiskColor = 'fbbf24' } },
		['Tokyo Night']  = { 11, { FontColor = 'cdd2ee', MainColor = '171824', AccentColor = '7aa2f7', AccentColor2 = 'bb9af7', BackgroundColor = '0f1018', OutlineColor = '2b2e45', RiskColor = 'f7768e' } },
		['Mint']         = { 12, { FontColor = 'e8f3ee', MainColor = '141d1a', AccentColor = '34d399', AccentColor2 = '5eead4', BackgroundColor = '0b1210', OutlineColor = '25362f', RiskColor = 'f87171' } },
		['Fatality']     = { 13, { FontColor = 'fbf7ff', MainColor = '1c1640', AccentColor = 'e11d5c', AccentColor2 = 'ff6f9c', BackgroundColor = '120d2b', OutlineColor = '3f3768', RiskColor = 'ff3b5c' } },
		['Obsidian']         = { 14, { FontColor = 'e6e6ea', MainColor = '141416', AccentColor = '9d8cff', AccentColor2 = '6c7bff', BackgroundColor = '0a0a0b', OutlineColor = '27272b', RiskColor = 'ff5a6e' } },
		['Carbon']           = { 15, { FontColor = 'e4e6e8', MainColor = '181a1c', AccentColor = '4fd1c5', AccentColor2 = '38bdf8', BackgroundColor = '0e0f10', OutlineColor = '2d3033', RiskColor = 'f87171' } },
		['Void']             = { 16, { FontColor = 'e2dff2', MainColor = '0e0c16', AccentColor = '7c3aed', AccentColor2 = 'c026d3', BackgroundColor = '050409', OutlineColor = '231d36', RiskColor = 'fb3b6b' } },
		['Nord Dark']        = { 17, { FontColor = 'e5e9f0', MainColor = '2e3440', AccentColor = '88c0d0', AccentColor2 = '81a1c1', BackgroundColor = '242933', OutlineColor = '434c5e', RiskColor = 'bf616a' } },
		['Dracula']          = { 18, { FontColor = 'f8f8f2', MainColor = '282a36', AccentColor = 'bd93f9', AccentColor2 = 'ff79c6', BackgroundColor = '1e1f29', OutlineColor = '44475a', RiskColor = 'ff5555' } },
		['Catppuccin Mocha'] = { 19, { FontColor = 'cdd6f4', MainColor = '1e1e2e', AccentColor = 'cba6f7', AccentColor2 = '89b4fa', BackgroundColor = '11111b', OutlineColor = '45475a', RiskColor = 'f38ba8' } },
		['Gruvbox Dark']     = { 20, { FontColor = 'ebdbb2', MainColor = '282828', AccentColor = 'fabd2f', AccentColor2 = 'fe8019', BackgroundColor = '1d2021', OutlineColor = '504945', RiskColor = 'fb4934' } },
		['Rose Pine']        = { 21, { FontColor = 'e0def4', MainColor = '1f1d2e', AccentColor = 'c4a7e7', AccentColor2 = 'ebbcba', BackgroundColor = '191724', OutlineColor = '403d52', RiskColor = 'eb6f92' } },
		['Crimson Night']    = { 22, { FontColor = 'f1e3e5', MainColor = '1a1214', AccentColor = 'dc2646', AccentColor2 = 'ff6b81', BackgroundColor = '0e0809', OutlineColor = '3a2227', RiskColor = 'ff3355' } },
		['Emerald Night']    = { 23, { FontColor = 'e2f2ea', MainColor = '101c17', AccentColor = '10b981', AccentColor2 = '84cc16', BackgroundColor = '08110d', OutlineColor = '1f3a2f', RiskColor = 'f87171' } },
		['Ocean Deep']       = { 24, { FontColor = 'dcecf5', MainColor = '0f1c28', AccentColor = '0ea5e9', AccentColor2 = '2dd4bf', BackgroundColor = '070f17', OutlineColor = '1d3548', RiskColor = 'fb7185' } },
		['Cyber Neon']       = { 25, { FontColor = 'e8fff9', MainColor = '12121f', AccentColor = '00ffc8', AccentColor2 = 'ff2bd6', BackgroundColor = '07070f', OutlineColor = '2a2a48', RiskColor = 'ff2b5e' } },
		['Blood Moon']       = { 26, { FontColor = 'efdcdc', MainColor = '1c0f10', AccentColor = 'b91c1c', AccentColor2 = 'f97316', BackgroundColor = '0f0607', OutlineColor = '3d1c1e', RiskColor = 'ef4444' } },
		['Slate']            = { 27, { FontColor = 'e2e8f0', MainColor = '1e2530', AccentColor = '64a3ff', AccentColor2 = '94a3b8', BackgroundColor = '141922', OutlineColor = '334155', RiskColor = 'f87171' } },
		['Amethyst']         = { 28, { FontColor = 'eadff5', MainColor = '1b1426', AccentColor = 'a855f7', AccentColor2 = 'f0abfc', BackgroundColor = '100a18', OutlineColor = '352748', RiskColor = 'f43f5e' } },
		['Monokai']          = { 29, { FontColor = 'f8f8f2', MainColor = '272822', AccentColor = 'a6e22e', AccentColor2 = '66d9ef', BackgroundColor = '1c1d17', OutlineColor = '49483e', RiskColor = 'f92672' } },
	}

	local BaseFallback = { 'BackgroundColor', 'MainColor', 'AccentColor', 'AccentColor2', 'OutlineColor', 'FontColor', 'RiskColor' }
	local BaseLabels = {
		BackgroundColor = 'Background', MainColor = 'Main', AccentColor = 'Accent', AccentColor2 = 'Accent 2 (outline)',
		OutlineColor = 'Outline', FontColor = 'Font', RiskColor = 'Risk',
	}
	local FontNames = {
		'GothamMedium', 'Gotham', 'GothamSemibold', 'GothamBold', 'GothamBlack', 'Code', 'RobotoMono', 'Roboto', 'RobotoCondensed',
		'SourceSans', 'SourceSansSemibold', 'SourceSansBold', 'Ubuntu', 'Montserrat', 'Nunito', 'Oswald', 'Inconsolata', 'Jura',
		'Arimo', 'Arial', 'JosefinSans', 'Kalam', 'Merriweather', 'Michroma', 'PatrickHand', 'Sarpanch', 'TitilliumWeb',
		'SciFi', 'Arcade', 'Highway', 'Cartoon', 'FredokaOne', 'Bangers', 'Antique',
	}

	local function GetOptions()
		return (ThemeManager.Library and ThemeManager.Library.Options) or Options
	end

	local function GetToggles()
		return (ThemeManager.Library and ThemeManager.Library.Toggles) or Toggles
	end

	function ThemeManager:GetBaseKeys()
		return (self.Library and self.Library.BaseColorKeys) or BaseFallback
	end

	function ThemeManager:GetDerived()
		return (self.Library and self.Library.DerivedColors) or {}
	end

	function ThemeManager:IsDerived(key)
		for _, def in ipairs(self:GetDerived()) do
			if def[1] == key then return true end
		end
		return false
	end

	function ThemeManager:GetFontList()
		local out = {}
		for _, name in ipairs(FontNames) do
			local ok, item = pcall(function() return Enum.Font[name] end)
			if ok and item then table.insert(out, name) end
		end
		return out
	end

	-- Appearance controls. apply(Lib, value) is the only place a setting reaches the library.
	function ThemeManager:GetAppearanceDefs()
		local Lib = self.Library
		local fonts = self:GetFontList()
		local function hud(frame, fallback)
			if frame ~= nil then return frame.Visible ~= false end
			return fallback
		end
		local defs = {
			{ key = 'Font', type = 'dropdown', text = 'Font', values = fonts,
				default = function() return (Lib.Font and Lib.Font.Name) or 'GothamMedium' end,
				apply = function(L, v) L:SetFont(v) end },
			{ key = 'FontSize', type = 'slider', text = 'Text size', min = 10, max = 20, rounding = 0,
				default = function() return Lib.FontSize or 13 end,
				apply = function(L, v) L:SetFontSize(v) end },
			{ key = 'Corner', type = 'slider', text = 'Roundness', min = 0, max = 200, rounding = 0, suffix = '%',
				default = function() return math.floor((Lib.CornerScale or 1) * 100 + 0.5) end,
				apply = function(L, v) L:SetCornerScale(v / 100) end },
			{ key = 'StrokeThickness', type = 'slider', text = 'Border thickness', min = 0, max = 3, rounding = 1,
				default = function() return Lib.StrokeThickness or 1 end,
				apply = function(L, v) L:SetStrokeThickness(v) end },
			{ key = 'Transparency', type = 'slider', text = 'Window transparency', min = 0, max = 70, rounding = 0, suffix = '%',
				default = function() return math.floor((Lib.WindowTransparency or 0) * 100 + 0.5) end,
				apply = function(L, v) L:SetWindowTransparency(v / 100) end },
			{ key = 'Scale', type = 'slider', text = 'UI scale', min = 70, max = 140, rounding = 0, suffix = '%',
				default = function() return math.floor((Lib.UIScale or 1) * 100 + 0.5) end,
				apply = function(L, v) L:SetUIScale(v / 100) end },
			{ key = 'OutlineMode', type = 'dropdown', text = 'Outline mode', values = { 'Gradient', 'Solid', 'None' },
				default = function() return Lib.OutlineMode or 'Gradient' end,
				apply = function(L, v) L:SetOutlineMode(v) end },
			{ key = 'OutlineThickness', type = 'slider', text = 'Outline thickness', min = 0, max = 5, rounding = 1,
				default = function() return Lib.OutlineThickness or 1 end,
				apply = function(L, v) L:SetOutlineThickness(v) end },
			{ key = 'Animated', idx = 'AsterAnimatedGradient', type = 'toggle', text = 'Animated outline',
				default = function() return Lib.AnimatedGradient ~= false end,
				apply = function(L, v) L:SetAnimatedGradient(v) end },
			{ key = 'GradientSpeed', idx = 'AsterGradientSpeed', type = 'slider', text = 'Outline speed', min = 0.05, max = 2, rounding = 2,
				default = function() return Lib.GradientSpeed or 0.35 end,
				apply = function(L, v) L:SetGradientSpeed(v) end },
			{ key = 'GradientAngle', type = 'slider', text = 'Outline angle', min = 0, max = 360, rounding = 0,
				default = function() return Lib.GradientAngle or 45 end,
				apply = function(L, v) L:SetGradientAngle(v) end },
			{ key = 'NotifyCorner', type = 'dropdown', text = 'Notification position',
				values = Lib.NotifyCornerList or { 'Top Left', 'Top Right', 'Bottom Left', 'Bottom Right' },
				default = function() return Lib.NotifyCorner or 'Top Left' end,
				apply = function(L, v) L:SetNotifyCorner(v) end },
		}
		if self.HudToggles then
			table.insert(defs, { key = 'Watermark', type = 'toggle', text = 'Show watermark',
				default = function() return hud(Lib.Watermark, true) end,
				apply = function(L, v) L:SetWatermarkVisibility(v) end })
			table.insert(defs, { key = 'KeybindList', type = 'toggle', text = 'Show keybind list',
				default = function() return hud(Lib.KeybindFrame, true) end,
				apply = function(L, v) L:SetKeybindListVisibility(v) end })
		end
		return defs
	end

	local function DefIdx(def)
		return def.idx or ('Theme_' .. def.key)
	end

	function ThemeManager:SyncPickers()
		local Lib, Opts = self.Library, GetOptions()
		local was = self.Applying
		self.Applying = true
		for _, key in ipairs(self:GetBaseKeys()) do
			if Opts[key] then Opts[key]:SetValueRGB(Lib[key]) end
		end
		for _, def in ipairs(self:GetDerived()) do
			if Opts[def[1]] then Opts[def[1]]:SetValueRGB(Lib[def[1]]) end
		end
		self.Applying = was
	end

	function ThemeManager:ApplySetting(key, value)
		local Opts, Tgl = GetOptions(), GetToggles()
		for _, def in ipairs(self:GetAppearanceDefs()) do
			if def.key == key then
				local ctl = (def.type == 'toggle' and Tgl or Opts)[DefIdx(def)]
				if ctl then
					ctl:SetValue(value)
				else
					pcall(def.apply, self.Library, value)
				end
				return
			end
		end
	end

	function ThemeManager:ApplyTheme(theme)
		local customThemeData = self:GetCustomTheme(theme)
		local builtin = self.BuiltInThemes[theme]
		local data = customThemeData or (builtin and builtin[2])
		local settings = customThemeData and customThemeData.Settings or (builtin and builtin[3])

		if not data then return end

		local Lib, Opts = self.Library, GetOptions()
		self.Applying = true

		-- presets start from the derived defaults; a preset may override single derived colours
		for key in next, Lib.ColorOverrides or {} do
			Lib.ColorOverrides[key] = nil
		end
		for idx, col in next, data do
			if type(col) == 'string' then
				local Ok, Color = pcall(Color3.fromHex, col)
				if Ok then
					if self:IsDerived(idx) then
						Lib:SetColorOverride(idx, Color)
					elseif Lib[idx] ~= nil or idx == 'AccentColor2' then
						Lib[idx] = Color
					end
				end
			end
		end
		Lib:ResolveColors()
		self.Applying = false
		self:SyncPickers()

		if type(settings) == 'table' then
			for key, value in next, settings do
				self:ApplySetting(key, value)
			end
		end

		Lib:UpdateColorsUsingRegistry()
	end

	function ThemeManager:ThemeUpdate()
		-- This allows us to force apply themes without loading the themes tab :)
		if self.Applying then return end
		local Lib, Opts = self.Library, GetOptions()
		for _, field in next, self:GetBaseKeys() do
			if Opts and Opts[field] then
				Lib[field] = Opts[field].Value
			end
		end

		Lib:UpdateColorsUsingRegistry()
		self:SyncPickers()
	end

	function ThemeManager:ResetOverrides()
		local Lib = self.Library
		for key in next, Lib.ColorOverrides or {} do
			Lib.ColorOverrides[key] = nil
		end
		Lib:UpdateColorsUsingRegistry()
		self:SyncPickers()
	end

	function ThemeManager:SetDefaultTheme(name)
		if type(name) == 'string' then self.DefaultTheme = name end
	end

	-- Paints the default theme onto the library before any UI exists (intro, first frame)
	function ThemeManager:PreApply()
		if not self.Library then return end
		local theme = self:ResolveDefault()
		self:ApplyTheme(theme)
		self.Library:UpdateColorsUsingRegistry()
	end

	function ThemeManager:ResolveDefault()
		local theme = self.DefaultTheme
		local path = self.Folder .. '/themes/default.txt'
		local content = SafeIsFile(path) and SafeRead(path)

		local isDefault = true
		if content then
			if self.BuiltInThemes[content] then
				theme = content
			elseif self:GetCustomTheme(content) then
				theme = content
				isDefault = false;
			end
		end

		if not self.BuiltInThemes[theme] and isDefault then
			theme = 'Aster Violet'
		end
		return theme, isDefault
	end

	function ThemeManager:LoadDefault()
		local theme, isDefault = self:ResolveDefault()
		local list = GetOptions().ThemeManager_ThemeList
		if isDefault and list then
			list:SetValue(theme)
		else
			self:ApplyTheme(theme)
		end
	end

	function ThemeManager:SaveDefault(theme)
		SafeWrite(self.Folder .. '/themes/default.txt', theme)
	end

	-- Presets + custom theme files ------------------------------------------------
	function ThemeManager:CreatePresets(box)
		local Opts = GetOptions()
		local ThemesArray = {}
		for Name in next, self.BuiltInThemes do
			table.insert(ThemesArray, Name)
		end
		table.sort(ThemesArray, function(a, b) return self.BuiltInThemes[a][1] < self.BuiltInThemes[b][1] end)

		box:AddDropdown('ThemeManager_ThemeList', { Text = 'Theme list', Values = ThemesArray, Default = 1 })

		box:AddButton('Set as default', function()
			self:SaveDefault(Opts.ThemeManager_ThemeList.Value)
			self.Library:Notify(string.format('Set default theme to %q', Opts.ThemeManager_ThemeList.Value))
		end)

		box:AddDivider()
		box:AddInput('ThemeManager_CustomThemeName', { Text = 'Custom theme name' })
		box:AddDropdown('ThemeManager_CustomThemeList', { Text = 'Custom themes', Values = self:ReloadCustomThemes(), AllowNull = true, Default = 1 })

		box:AddButton('Save theme', function()
			self:SaveCustomTheme(Opts.ThemeManager_CustomThemeName.Value)

			Opts.ThemeManager_CustomThemeList:SetValues(self:ReloadCustomThemes())
			Opts.ThemeManager_CustomThemeList:SetValue(nil)
		end):AddButton('Load theme', function()
			self:ApplyTheme(Opts.ThemeManager_CustomThemeList.Value)
		end)

		box:AddButton('Refresh list', function()
			Opts.ThemeManager_CustomThemeList:SetValues(self:ReloadCustomThemes())
			Opts.ThemeManager_CustomThemeList:SetValue(nil)
		end)

		box:AddButton('Set as default', function()
			if Opts.ThemeManager_CustomThemeList.Value ~= nil and Opts.ThemeManager_CustomThemeList.Value ~= '' then
				self:SaveDefault(Opts.ThemeManager_CustomThemeList.Value)
				self.Library:Notify(string.format('Set default theme to %q', Opts.ThemeManager_CustomThemeList.Value))
			end
		end)
	end

	-- Colour pickers for every theme colour -----------------------------------------
	function ThemeManager:CreateColors(box)
		local Lib = self.Library
		local main = box.AddSection and box:AddSection('Colors') or box
		local pickers = {}

		local function Add(parent, key, text)
			local armed = false
			parent:AddLabel(text):AddColorPicker(key, { Default = Lib[key] or Color3.new(1, 1, 1), Title = text })
			local picker = GetOptions()[key]
			picker:OnChanged(function(Value)
				if not armed or self.Applying then return end
				if self:IsDerived(key) then
					Lib:SetColorOverride(key, Value)
					Lib:UpdateColorsUsingRegistry()
				else
					self:ThemeUpdate()
				end
			end)
			armed = true
			table.insert(pickers, picker)
		end

		for _, key in ipairs(self:GetBaseKeys()) do
			Add(main, key, (BaseLabels[key] or key) .. ' color')
		end

		local derived = #self:GetDerived() > 0
		if derived then
			local sub = box.AddSection and box:AddSection('Surfaces and widgets', { Collapsed = true }) or box
			for _, def in ipairs(self:GetDerived()) do
				Add(sub, def[1], def[3] or def[1])
			end
			sub:AddButton('Reset to theme colors', function()
				self:ResetOverrides()
			end)
		end
	end

	function ThemeManager:CreateAppearance(box)
		local Lib = self.Library
		for _, def in ipairs(self:GetAppearanceDefs()) do
			local idx = DefIdx(def)
			local ready = false
			local function Callback(Value)
				if ready then pcall(def.apply, Lib, Value) end
			end
			if def.type == 'slider' then
				box:AddSlider(idx, {
					Text = def.text, Default = math.clamp(def.default(), def.min, def.max), Min = def.min, Max = def.max,
					Rounding = def.rounding, Suffix = def.suffix, Callback = Callback,
				})
			elseif def.type == 'dropdown' then
				box:AddDropdown(idx, { Text = def.text, Values = def.values, Default = def.default(), Callback = Callback })
			else
				box:AddToggle(idx, { Text = def.text, Default = def.default(), Callback = Callback })
			end
			ready = true
		end
	end

	-- Hooks the controls up and applies the saved default theme. Safe to call twice.
	function ThemeManager:Finalize()
		if self.Finalized then return end
		self.Finalized = true
		local Opts = GetOptions()
		if Opts.ThemeManager_ThemeList then
			Opts.ThemeManager_ThemeList:OnChanged(function()
				self:ApplyTheme(Opts.ThemeManager_ThemeList.Value)
			end)
		end
		self:LoadDefault()
	end

	-- Everything in one groupbox (collapsible sections)
	function ThemeManager:CreateThemeManager(groupbox)
		local hasSections = groupbox.AddSection ~= nil
		self:CreateColors(groupbox)
		groupbox:AddDivider()
		local appearance = hasSections and groupbox:AddSection('Appearance') or groupbox
		self:CreateAppearance(appearance)
		groupbox:AddDivider()
		local presets = hasSections and groupbox:AddSection('Presets and custom themes') or groupbox
		self:CreatePresets(presets)
		self:Finalize()
	end

	function ThemeManager:GetCustomTheme(file)
		if type(file) ~= 'string' or file == '' then
			return nil
		end

		local path = self.Folder .. '/themes/' .. file
		if not SafeIsFile(path) then
			return nil
		end

		local data = SafeRead(path)
		if not data then
			return nil
		end
		local success, decoded = pcall(httpService.JSONDecode, httpService, data)

		if not success then
			return nil
		end

		return decoded
	end

	-- Current look as a serialisable table (hex colours + appearance settings)
	function ThemeManager:GetThemeData()
		local Lib, Opts, Tgl = self.Library, GetOptions(), GetToggles()
		local theme = {}
		for _, field in next, self:GetBaseKeys() do
			local color = (Opts[field] and Opts[field].Value) or Lib[field]
			if color then theme[field] = color:ToHex() end
		end
		for key, color in next, Lib.ColorOverrides or {} do
			theme[key] = color:ToHex()
		end
		local settings = {}
		for _, def in ipairs(self:GetAppearanceDefs()) do
			local ctl = (def.type == 'toggle' and Tgl or Opts)[DefIdx(def)]
			if ctl then
				settings[def.key] = ctl.Value
			else
				settings[def.key] = def.default()
			end
		end
		theme.Settings = settings
		return theme
	end

	function ThemeManager:SaveCustomTheme(file)
		if type(file) ~= 'string' or file:gsub(' ', '') == '' then
			return self.Library:Notify('Invalid file name for theme (empty)', 3)
		end

		local ok = SafeWrite(self.Folder .. '/themes/' .. file .. '.json', httpService:JSONEncode(self:GetThemeData()))
		if not ok then
			self.Library:Notify('Could not save theme (no file access)', 3)
		end
	end

	function ThemeManager:ReloadCustomThemes()
		local ok, list = pcall(function()
			return listfiles(self.Folder .. '/themes')
		end)
		if not ok or type(list) ~= 'table' then
			return {}
		end

		local out = {}
		for i = 1, #list do
			local file = list[i]
			if file:sub(-5) == '.json' then
				-- i hate this but it has to be done ...

				local pos = file:find('.json', 1, true)
				local char = file:sub(pos, pos)

				while char ~= '/' and char ~= '\\' and char ~= '' do
					pos = pos - 1
					char = file:sub(pos, pos)
				end

				if char == '/' or char == '\\' then
					table.insert(out, file:sub(pos + 1))
				end
			end
		end

		return out
	end

	function ThemeManager:SetLibrary(lib)
		self.Library = lib
	end

	-- Every idx the manager creates, for SaveManager's ignore list
	function ThemeManager:GetIndexes()
		local out = { 'ThemeManager_ThemeList', 'ThemeManager_CustomThemeList', 'ThemeManager_CustomThemeName' }
		for _, key in ipairs(self:GetBaseKeys()) do table.insert(out, key) end
		for _, def in ipairs(self:GetDerived()) do table.insert(out, def[1]) end
		for _, def in ipairs(self.Library and self:GetAppearanceDefs() or {}) do table.insert(out, DefIdx(def)) end
		return out
	end

	function ThemeManager:BuildFolderTree()
		local paths = {}

		-- build the entire tree if a path is like some-hub/phantom-forces
		-- makefolder builds the entire tree on Synapse X but not other exploits

		local parts = self.Folder:split('/')
		for idx = 1, #parts do
			paths[#paths + 1] = table.concat(parts, '/', 1, idx)
		end

		table.insert(paths, self.Folder .. '/themes')
		table.insert(paths, self.Folder .. '/settings')

		for i = 1, #paths do
			local str = paths[i]
			pcall(function()
				if not isfolder(str) then
					makefolder(str)
				end
			end)
		end
	end

	function ThemeManager:SetFolder(folder)
		self.Folder = folder
		self:BuildFolderTree()
	end

	function ThemeManager:CreateGroupBox(tab)
		assert(self.Library, 'Must set ThemeManager.Library first!')
		return tab:AddLeftGroupbox('Themes')
	end

	-- tab may be a Tab or a SubTab: Themes (left) holds colours and presets, Appearance (right) the rest
	function ThemeManager:ApplyToTab(tab)
		assert(self.Library, 'Must set ThemeManager.Library first!')
		local colors = self:CreateGroupBox(tab)
		self:CreateColors(colors)
		colors:AddDivider()
		self:CreatePresets(colors)

		local appearance = tab:AddRightGroupbox('Appearance')
		self:CreateAppearance(appearance)
		self:Finalize()
	end

	function ThemeManager:ApplyToGroupbox(groupbox)
		assert(self.Library, 'Must set ThemeManager.Library first!')
		self:CreateThemeManager(groupbox)
	end

	ThemeManager:BuildFolderTree()
end

return ThemeManager
