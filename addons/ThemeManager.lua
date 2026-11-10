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

	ThemeManager.Library = nil
	-- { order, { colours as hex } } ; AccentColor2 is the second gradient colour
	ThemeManager.BuiltInThemes = {
		['Aster Violet'] = { 1, { FontColor = 'e8e8f0', MainColor = '121216', AccentColor = '8b5cf6', AccentColor2 = '38bdf8', BackgroundColor = '0c0c0f', OutlineColor = '22222a' } },
		['Aurora']       = { 2, { FontColor = 'e6f1ee', MainColor = '101619', AccentColor = '22d3ee', AccentColor2 = '4ade80', BackgroundColor = '0a0f11', OutlineColor = '1c282c' } },
		['Sakura']       = { 3, { FontColor = 'f3e8ee', MainColor = '171216', AccentColor = 'f472b6', AccentColor2 = 'fb923c', BackgroundColor = '100c0f', OutlineColor = '2a2026' } },
		['Ember']        = { 4, { FontColor = 'f1e9e6', MainColor = '161211', AccentColor = 'ef4444', AccentColor2 = 'f97316', BackgroundColor = '0f0c0b', OutlineColor = '29201e' } },
		['Mono']         = { 5, { FontColor = 'e4e4e7', MainColor = '141414', AccentColor = 'e5e7eb', AccentColor2 = '71717a', BackgroundColor = '0d0d0d', OutlineColor = '262626' } },
		['Tokyo Night']  = { 6, { FontColor = 'c8cbe6', MainColor = '16161f', AccentColor = '7aa2f7', AccentColor2 = 'bb9af7', BackgroundColor = '11111a', OutlineColor = '2a2b3d' } },
		['Mint']         = { 7, { FontColor = 'e8f2ee', MainColor = '151a18', AccentColor = '3db488', AccentColor2 = '5eead4', BackgroundColor = '0f1312', OutlineColor = '24302c' } },
		['Fatality']     = { 8, { FontColor = 'ffffff', MainColor = '1a1538', AccentColor = 'c50754', AccentColor2 = 'ff5c8a', BackgroundColor = '140f2c', OutlineColor = '3c355d' } },
	}

	local ColorFields = { 'FontColor', 'MainColor', 'AccentColor', 'AccentColor2', 'BackgroundColor', 'OutlineColor' }

	local function GetOptions()
		return (ThemeManager.Library and ThemeManager.Library.Options) or Options
	end

	local function GetToggles()
		return (ThemeManager.Library and ThemeManager.Library.Toggles) or Toggles
	end

	function ThemeManager:ApplyTheme(theme)
		local customThemeData = self:GetCustomTheme(theme)
		local data = customThemeData or (self.BuiltInThemes[theme] and self.BuiltInThemes[theme][2])

		if not data then return end

		local Opts = GetOptions()
		for idx, col in next, data do
			if type(col) == 'string' and (idx == 'AccentColor2' or self.Library[idx] ~= nil) then
				local Ok, Color = pcall(Color3.fromHex, col)
				if Ok then
					self.Library[idx] = Color

					if Opts[idx] then
						Opts[idx]:SetValueRGB(Color)
					end
				end
			end
		end

		self:ThemeUpdate()
	end

	function ThemeManager:ThemeUpdate()
		-- This allows us to force apply themes without loading the themes tab :)
		local Opts = GetOptions()
		for i, field in next, ColorFields do
			if Opts and Opts[field] then
				self.Library[field] = Opts[field].Value
			end
		end

		self.Library.AccentColorDark = self.Library:GetDarkerColor(self.Library.AccentColor);
		self.Library:UpdateColorsUsingRegistry()
	end

	function ThemeManager:LoadDefault()
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

		if isDefault then
			GetOptions().ThemeManager_ThemeList:SetValue(theme)
		else
			self:ApplyTheme(theme)
		end
	end

	function ThemeManager:SaveDefault(theme)
		SafeWrite(self.Folder .. '/themes/default.txt', theme)
	end

	function ThemeManager:CreateThemeManager(groupbox)
		local Lib = self.Library
		groupbox:AddLabel('Background color'):AddColorPicker('BackgroundColor', { Default = Lib.BackgroundColor });
		groupbox:AddLabel('Main color'):AddColorPicker('MainColor', { Default = Lib.MainColor });
		groupbox:AddLabel('Accent color'):AddColorPicker('AccentColor', { Default = Lib.AccentColor });
		groupbox:AddLabel('Accent 2'):AddColorPicker('AccentColor2', { Default = Lib.AccentColor2 or Color3.fromRGB(56, 189, 248) });
		groupbox:AddLabel('Outline color'):AddColorPicker('OutlineColor', { Default = Lib.OutlineColor });
		groupbox:AddLabel('Font color'):AddColorPicker('FontColor', { Default = Lib.FontColor });

		groupbox:AddDivider()
		groupbox:AddToggle('AsterAnimatedGradient', {
			Text = 'Animated gradient',
			Default = Lib.AnimatedGradient ~= false,
			Callback = function(Value)
				Lib.AnimatedGradient = Value
			end,
		})
		local SpeedBox = groupbox:AddDependencyBox()
		SpeedBox:AddSlider('AsterGradientSpeed', {
			Text = 'Gradient speed',
			Default = Lib.GradientSpeed or 0.35,
			Min = 0.05,
			Max = 2,
			Rounding = 2,
			HideMax = true,
			Callback = function(Value)
				Lib.GradientSpeed = Value
			end,
		})
		SpeedBox:SetupDependencies({ { GetToggles().AsterAnimatedGradient, true } })

		local ThemesArray = {}
		for Name, Theme in next, self.BuiltInThemes do
			table.insert(ThemesArray, Name)
		end

		table.sort(ThemesArray, function(a, b) return self.BuiltInThemes[a][1] < self.BuiltInThemes[b][1] end)

		local Opts = GetOptions()

		groupbox:AddDivider()
		groupbox:AddDropdown('ThemeManager_ThemeList', { Text = 'Theme list', Values = ThemesArray, Default = 1 })

		groupbox:AddButton('Set as default', function()
			self:SaveDefault(Opts.ThemeManager_ThemeList.Value)
			self.Library:Notify(string.format('Set default theme to %q', Opts.ThemeManager_ThemeList.Value))
		end)

		Opts.ThemeManager_ThemeList:OnChanged(function()
			self:ApplyTheme(Opts.ThemeManager_ThemeList.Value)
		end)

		groupbox:AddDivider()
		groupbox:AddInput('ThemeManager_CustomThemeName', { Text = 'Custom theme name' })
		groupbox:AddDropdown('ThemeManager_CustomThemeList', { Text = 'Custom themes', Values = self:ReloadCustomThemes(), AllowNull = true, Default = 1 })
		groupbox:AddDivider()

		groupbox:AddButton('Save theme', function()
			self:SaveCustomTheme(Opts.ThemeManager_CustomThemeName.Value)

			Opts.ThemeManager_CustomThemeList:SetValues(self:ReloadCustomThemes())
			Opts.ThemeManager_CustomThemeList:SetValue(nil)
		end):AddButton('Load theme', function()
			self:ApplyTheme(Opts.ThemeManager_CustomThemeList.Value)
		end)

		groupbox:AddButton('Refresh list', function()
			Opts.ThemeManager_CustomThemeList:SetValues(self:ReloadCustomThemes())
			Opts.ThemeManager_CustomThemeList:SetValue(nil)
		end)

		groupbox:AddButton('Set as default', function()
			if Opts.ThemeManager_CustomThemeList.Value ~= nil and Opts.ThemeManager_CustomThemeList.Value ~= '' then
				self:SaveDefault(Opts.ThemeManager_CustomThemeList.Value)
				self.Library:Notify(string.format('Set default theme to %q', Opts.ThemeManager_CustomThemeList.Value))
			end
		end)

		self:LoadDefault()

		local function UpdateTheme()
			self:ThemeUpdate()
		end

		Opts.BackgroundColor:OnChanged(UpdateTheme)
		Opts.MainColor:OnChanged(UpdateTheme)
		Opts.AccentColor:OnChanged(UpdateTheme)
		Opts.AccentColor2:OnChanged(UpdateTheme)
		Opts.OutlineColor:OnChanged(UpdateTheme)
		Opts.FontColor:OnChanged(UpdateTheme)
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

	function ThemeManager:SaveCustomTheme(file)
		if type(file) ~= 'string' or file:gsub(' ', '') == '' then
			return self.Library:Notify('Invalid file name for theme (empty)', 3)
		end

		local theme = {}
		local Opts = GetOptions()

		for _, field in next, ColorFields do
			if Opts[field] then
				theme[field] = Opts[field].Value:ToHex()
			end
		end

		local ok = SafeWrite(self.Folder .. '/themes/' .. file .. '.json', httpService:JSONEncode(theme))
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

	function ThemeManager:ApplyToTab(tab)
		assert(self.Library, 'Must set ThemeManager.Library first!')
		local groupbox = self:CreateGroupBox(tab)
		self:CreateThemeManager(groupbox)
	end

	function ThemeManager:ApplyToGroupbox(groupbox)
		assert(self.Library, 'Must set ThemeManager.Library first!')
		self:CreateThemeManager(groupbox)
	end

	ThemeManager:BuildFolderTree()
end

return ThemeManager
