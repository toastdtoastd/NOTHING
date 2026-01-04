local httpService = game:GetService('HttpService')
local RunService = game:GetService('RunService')

local ThemeManager = {} do
	ThemeManager.Folder = 'LinoriaLibSettings'
	ThemeManager.Library = nil

	-- ======================
	-- BUILT-IN THEMES
	-- ======================
	ThemeManager.BuiltInThemes = {
		['Nothing'] = {
			1,
			httpService:JSONDecode('{"FontColor":"ffffff","MainColor":"1c1c1c","AccentColor":"000000","BackgroundColor":"141414","OutlineColor":"323232"}')
		},
	}

	-- ======================
	-- RGB ACCENT CYCLE STATE
	-- ======================
	local AccentConnection
	local AccentHue = 0

	local function StopAccentCycle()
		if AccentConnection then
			AccentConnection:Disconnect()
			AccentConnection = nil
		end
	end

	local function StartAccentCycle(self)
		StopAccentCycle()

		AccentConnection = RunService.RenderStepped:Connect(function(dt)
			AccentHue = (AccentHue + dt * 0.15) % 1
			local color = Color3.fromHSV(AccentHue, 1, 1)

			self.Library.AccentColor = color
			self.Library.AccentColorDark = self.Library:GetDarkerColor(color)

			if Options and Options.AccentColor then
				Options.AccentColor:SetValueRGB(color)
			end

			self.Library:UpdateColorsUsingRegistry()
		end)
	end

	-- ======================
	-- APPLY THEME
	-- ======================
	function ThemeManager:ApplyTheme(theme)
		StopAccentCycle()

		local customThemeData = self:GetCustomTheme(theme)
		local data = customThemeData or self.BuiltInThemes[theme]
		if not data then return end

		local scheme = data[2]
		for idx, col in next, customThemeData or scheme do
			local c = Color3.fromHex(col)
			self.Library[idx] = c

			if Options[idx] then
				Options[idx]:SetValueRGB(c)
			end
		end

		self:ThemeUpdate()

		-- Enable RGB cycling ONLY for Nothing
		if theme == 'Nothing' then
			StartAccentCycle(self)
		end
	end

	-- ======================
	-- THEME UPDATE
	-- ======================
	function ThemeManager:ThemeUpdate()
		local options = {
			"FontColor",
			"MainColor",
			"AccentColor",
			"BackgroundColor",
			"OutlineColor"
		}

		for _, field in next, options do
			if Options and Options[field] then
				self.Library[field] = Options[field].Value
			end
		end

		self.Library.AccentColorDark =
			self.Library:GetDarkerColor(self.Library.AccentColor)

		self.Library:UpdateColorsUsingRegistry()
	end

	-- ======================
	-- LOAD DEFAULT
	-- ======================
	function ThemeManager:LoadDefault()
		Options.ThemeManager_ThemeList:SetValue('Nothing')
	end

	function ThemeManager:SaveDefault(theme)
		writefile(self.Folder .. '/themes/default.txt', theme)
	end

	-- ======================
	-- UI CREATION
	-- ======================
	function ThemeManager:CreateThemeManager(groupbox)
		groupbox:AddLabel('Background color'):AddColorPicker('BackgroundColor', { Default = self.Library.BackgroundColor })
		groupbox:AddLabel('Main color'):AddColorPicker('MainColor', { Default = self.Library.MainColor })
		groupbox:AddLabel('Accent color'):AddColorPicker('AccentColor', { Default = self.Library.AccentColor })
		groupbox:AddLabel('Outline color'):AddColorPicker('OutlineColor', { Default = self.Library.OutlineColor })
		groupbox:AddLabel('Font color'):AddColorPicker('FontColor', { Default = self.Library.FontColor })

		local ThemesArray = {}
		for Name in next, self.BuiltInThemes do
			table.insert(ThemesArray, Name)
		end

		table.sort(ThemesArray, function(a, b)
			return self.BuiltInThemes[a][1] < self.BuiltInThemes[b][1]
		end)

		groupbox:AddDivider()
		groupbox:AddDropdown('ThemeManager_ThemeList', {
			Text = 'Theme list',
			Values = ThemesArray,
			Default = 1
		})

		Options.ThemeManager_ThemeList:OnChanged(function()
			self:ApplyTheme(Options.ThemeManager_ThemeList.Value)
		end)

		groupbox:AddDivider()
		groupbox:AddInput('ThemeManager_CustomThemeName', { Text = 'Custom theme name' })
		groupbox:AddDropdown('ThemeManager_CustomThemeList', {
			Text = 'Custom themes',
			Values = self:ReloadCustomThemes(),
			AllowNull = true
		})

		groupbox:AddButton('Save theme', function()
			self:SaveCustomTheme(Options.ThemeManager_CustomThemeName.Value)
			Options.ThemeManager_CustomThemeList:SetValues(self:ReloadCustomThemes())
			Options.ThemeManager_CustomThemeList:SetValue(nil)
		end)

		groupbox:AddButton('Load theme', function()
			self:ApplyTheme(Options.ThemeManager_CustomThemeList.Value)
		end)

		ThemeManager:LoadDefault()

		local function UpdateTheme()
			self:ThemeUpdate()
		end

		Options.BackgroundColor:OnChanged(UpdateTheme)
		Options.MainColor:OnChanged(UpdateTheme)
		Options.OutlineColor:OnChanged(UpdateTheme)
		Options.FontColor:OnChanged(UpdateTheme)

		-- Prevent manual AccentColor fighting RGB cycle
		Options.AccentColor:OnChanged(function()
			if Options.ThemeManager_ThemeList.Value ~= 'Nothing' then
				UpdateTheme()
			end
		end)
	end

	-- ======================
	-- CUSTOM THEMES
	-- ======================
	function ThemeManager:GetCustomTheme(file)
		local path = self.Folder .. '/themes/' .. file
		if not isfile(path) then return nil end

		local data = readfile(path)
		local success, decoded = pcall(httpService.JSONDecode, httpService, data)
		if not success then return nil end

		return decoded
	end

	function ThemeManager:SaveCustomTheme(file)
		if file:gsub(' ', '') == '' then
			return self.Library:Notify('Invalid file name for theme (empty)', 3)
		end

		local theme = {}
		local fields = {
			"FontColor",
			"MainColor",
			"AccentColor",
			"BackgroundColor",
			"OutlineColor"
		}

		for _, field in next, fields do
			theme[field] = Options[field].Value:ToHex()
		end

		writefile(self.Folder .. '/themes/' .. file .. '.json',
			httpService:JSONEncode(theme))
	end

	function ThemeManager:ReloadCustomThemes()
		local list = listfiles(self.Folder .. '/themes')
		local out = {}

		for _, file in ipairs(list) do
			if file:sub(-5) == '.json' then
				local name = file:match("([^/\\]+)%.json$")
				if name then
					table.insert(out, name)
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
		local parts = self.Folder:split('/')

		for i = 1, #parts do
			paths[#paths + 1] = table.concat(parts, '/', 1, i)
		end

		table.insert(paths, self.Folder .. '/themes')
		table.insert(paths, self.Folder .. '/settings')

		for _, path in ipairs(paths) do
			if not isfolder(path) then
				makefolder(path)
			end
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
