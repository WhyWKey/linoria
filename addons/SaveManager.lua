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

local SaveManager = {} do
	SaveManager.Folder = 'Aster'
	SaveManager.Ignore = {}
	-- generated controls that must never be written to a config
	SaveManager.IgnorePrefixes = { 'Theme_', 'AsterPlayerPriority', 'ThemeManager_' }
	SaveManager.Parser = {
		Toggle = {
			Save = function(idx, object) 
				return { type = 'Toggle', idx = idx, value = object.Value } 
			end,
			Load = function(idx, data)
				local Toggles = SaveManager:GetToggles()
				if Toggles[idx] then 
					Toggles[idx]:SetValue(data.value)
				end
			end,
		},
		Slider = {
			Save = function(idx, object)
				return { type = 'Slider', idx = idx, value = tostring(object.Value) }
			end,
			Load = function(idx, data)
				local Options = SaveManager:GetOptions()
				if Options[idx] then 
					Options[idx]:SetValue(data.value)
				end
			end,
		},
		Dropdown = {
			Save = function(idx, object)
				return { type = 'Dropdown', idx = idx, value = object.Value, mutli = object.Multi }
			end,
			Load = function(idx, data)
				local Options = SaveManager:GetOptions()
				if Options[idx] then 
					Options[idx]:SetValue(data.value)
				end
			end,
		},
		ColorPicker = {
			Save = function(idx, object)
				return { type = 'ColorPicker', idx = idx, value = object.Value:ToHex(), transparency = object.Transparency }
			end,
			Load = function(idx, data)
				local Options = SaveManager:GetOptions()
				if Options[idx] then 
					Options[idx]:SetValueRGB(Color3.fromHex(data.value), tonumber(data.transparency) or 0)
				end
			end,
		},
		KeyPicker = {
			Save = function(idx, object)
				return { type = 'KeyPicker', idx = idx, mode = object.Mode, key = object.Value }
			end,
			Load = function(idx, data)
				local Options = SaveManager:GetOptions()
				if Options[idx] then 
					Options[idx]:SetValue({ data.key, data.mode })
				end
			end,
		},

		Input = {
			Save = function(idx, object)
				return { type = 'Input', idx = idx, text = object.Value }
			end,
			Load = function(idx, data)
				local Options = SaveManager:GetOptions()
				if Options[idx] and type(data.text) == 'string' then
					Options[idx]:SetValue(data.text)
				end
			end,
		},
	}

	function SaveManager:GetOptions()
		return (self.Library and self.Library.Options) or Options
	end

	function SaveManager:GetToggles()
		return (self.Library and self.Library.Toggles) or Toggles
	end

	function SaveManager:IsIgnored(idx)
		if self.Ignore[idx] then return true end
		for _, prefix in ipairs(self.IgnorePrefixes) do
			if type(idx) == 'string' and idx:sub(1, #prefix) == prefix then return true end
		end
		return false
	end

	function SaveManager:SetIgnoreIndexes(list)
		for _, key in next, list do
			self.Ignore[key] = true
		end
	end

	function SaveManager:SetFolder(folder)
		self.Folder = folder;
		self:BuildFolderTree()
	end

	function SaveManager:Save(name)
		if (not name) then
			return false, 'no config file is selected'
		end

		local fullPath = self.Folder .. '/settings/' .. name .. '.json'

		local data = {
			objects = {}
		}

		for idx, toggle in next, self:GetToggles() do
			if not self:IsIgnored(idx) and self.Parser[toggle.Type] then
				table.insert(data.objects, self.Parser[toggle.Type].Save(idx, toggle))
			end
		end

		for idx, option in next, self:GetOptions() do
			if self.Parser[option.Type] and not self:IsIgnored(idx) then
				table.insert(data.objects, self.Parser[option.Type].Save(idx, option))
			end
		end	

		if self.Library and self.Library.GetPlayerPriorities then
			data.priorities = self.Library:GetPlayerPriorities()
		end

		if self.Library and self.Library.GetLayout then
			data.layout = self.Library:GetLayout()
		end

		local success, encoded = pcall(httpService.JSONEncode, httpService, data)
		if not success then
			return false, 'failed to encode data'
		end

		local written = SafeWrite(fullPath, encoded)
		if not written then
			return false, 'could not write file'
		end
		return true
	end

	function SaveManager:Load(name)
		if (not name) then
			return false, 'no config file is selected'
		end
		
		local file = self.Folder .. '/settings/' .. name .. '.json'
		if not SafeIsFile(file) then return false, 'invalid file' end

		local content = SafeRead(file)
		if not content then return false, 'could not read file' end

		local success, decoded = pcall(httpService.JSONDecode, httpService, content)
		if not success or type(decoded) ~= 'table' or type(decoded.objects) ~= 'table' then return false, 'decode error' end

		if type(decoded.priorities) == 'table' and self.Library and self.Library.SetPlayerPriorities then
			self.Library:SetPlayerPriorities(decoded.priorities)
		end

		if type(decoded.layout) == 'table' and self.Library and self.Library.SetLayout then
			self.Library:SetLayout(decoded.layout)
		end

		for _, option in next, decoded.objects do
			if self.Parser[option.type] then
				task.spawn(function() self.Parser[option.type].Load(option.idx, option) end) -- task.spawn() so the config loading wont get stuck.
			end
		end

		return true
	end

	function SaveManager:IgnoreThemeSettings()
		self:SetIgnoreIndexes({ 
			"BackgroundColor", "MainColor", "AccentColor", "AccentColor2", "OutlineColor", "FontColor", "RiskColor", -- themes
			"ThemeManager_ThemeList", 'ThemeManager_CustomThemeList', 'ThemeManager_CustomThemeName', -- themes
			'AsterAnimatedGradient', 'AsterGradientSpeed',
		})
		local derived = self.Library and self.Library.DerivedColors
		for _, def in ipairs(derived or {}) do
			self.Ignore[def[1]] = true
		end
	end

	function SaveManager:BuildFolderTree()
		local paths = {
			self.Folder,
			self.Folder .. '/themes',
			self.Folder .. '/settings'
		}

		for i = 1, #paths do
			local str = paths[i]
			pcall(function()
				if not isfolder(str) then
					makefolder(str)
				end
			end)
		end
	end

	function SaveManager:RefreshConfigList()
		local ok, list = pcall(function()
			return listfiles(self.Folder .. '/settings')
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
				local start = pos

				local char = file:sub(pos, pos)
				while char ~= '/' and char ~= '\\' and char ~= '' do
					pos = pos - 1
					char = file:sub(pos, pos)
				end

				if char == '/' or char == '\\' then
					table.insert(out, file:sub(pos + 1, start - 1))
				end
			end
		end
		
		return out
	end

	function SaveManager:SetLibrary(library)
		self.Library = library
	end

	function SaveManager:LoadAutoloadConfig()
		local path = self.Folder .. '/settings/autoload.txt'
		if SafeIsFile(path) then
			local name = SafeRead(path)
			if not name then return end

			local success, err = self:Load(name)
			if not success and not SILENT then
				return self.Library:Notify('Failed to load autoload config: ' .. err)
			end
			if not SILENT then
				self.Library:Notify(string.format('Auto loaded config %q', name))
			end
		end
	end


	function SaveManager:BuildConfigSection(tab)
		assert(self.Library, 'Must set SaveManager.Library')

		local Options = self:GetOptions()
		local section = tab:AddRightGroupbox('Configuration')

		section:AddInput('SaveManager_ConfigName',    { Text = 'Config name' })
		section:AddDropdown('SaveManager_ConfigList', { Text = 'Config list', Values = self:RefreshConfigList(), AllowNull = true })

		section:AddDivider()

		section:AddButton('Create config', function()
			local name = Options.SaveManager_ConfigName.Value

			if name:gsub(' ', '') == '' then 
				return self.Library:Notify('Invalid config name (empty)', 2)
			end

			local success, err = self:Save(name)
			if not success then
				return self.Library:Notify('Failed to save config: ' .. err)
			end

			self.Library:Notify(string.format('Created config %q', name))

			Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
			Options.SaveManager_ConfigList:SetValue(nil)
		end):AddButton('Load config', function()
			local name = Options.SaveManager_ConfigList.Value

			local success, err = self:Load(name)
			if not success then
				return self.Library:Notify('Failed to load config: ' .. err)
			end

			self.Library:Notify(string.format('Loaded config %q', name))
		end)

		section:AddButton('Overwrite config', function()
			local name = Options.SaveManager_ConfigList.Value

			local success, err = self:Save(name)
			if not success then
				return self.Library:Notify('Failed to overwrite config: ' .. err)
			end

			self.Library:Notify(string.format('Overwrote config %q', name))
		end)

		section:AddButton('Refresh list', function()
			Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
			Options.SaveManager_ConfigList:SetValue(nil)
		end)

		section:AddButton('Set autoload', function()
			local name = Options.SaveManager_ConfigList.Value
			if (not name) then
				return;
			end;
			SafeWrite(self.Folder .. '/settings/autoload.txt', name)
			SaveManager.AutoloadLabel:SetText('Current autoload config: ' .. name)
			self.Library:Notify(string.format('Set %q to auto load', name))
		end):AddButton('Remove autoload', function()
			pcall(function()
				if (isfile(self.Folder .. '/settings/autoload.txt')) then
					delfile(self.Folder .. '/settings/autoload.txt');
				end;
			end)
			SaveManager.AutoloadLabel:SetText('Current autoload config: none')
			self.Library:Notify("removed autoload");
		end)

		SaveManager.AutoloadLabel = section:AddLabel('Current autoload config: none', true)

		if SafeIsFile(self.Folder .. '/settings/autoload.txt') then
			local name = SafeRead(self.Folder .. '/settings/autoload.txt')
			if name then
				SaveManager.AutoloadLabel:SetText('Current autoload config: ' .. name)
			end
		end

		SaveManager:SetIgnoreIndexes({ 'SaveManager_ConfigList', 'SaveManager_ConfigName' })
	end

	SaveManager:BuildFolderTree()
end

pcall(function()
	local Env = (type(getgenv) == 'function' and getgenv()) or _G
	Env.SaveManager = SaveManager
end)
return SaveManager
