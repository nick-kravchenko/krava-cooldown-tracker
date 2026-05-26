-- KravaCooldownTracker_Config.lua
-- Saved configuration, validation, and options UI helpers.

KravaCooldownTracker_Config = KravaCooldownTracker_Config or {}
local C = KravaCooldownTracker_Config

local DEFAULT_MAIN_ICON_SIZE = 32
local DEFAULT_QUEUE_ICON_PERCENT = 25
local DEFAULT_FONT_SIZE = 14
local DEFAULT_LOCKED = true
local DEFAULT_DISABLE_TRINKET_USAGE_ON_CLICK = true
local DEFAULT_DISABLE_UPPER_TRINKET_SUGGESTIONS = true
local DEFAULT_DISABLE_LOWER_TRINKET_SUGGESTIONS = true
local DEFAULT_SUGGESTION_POSITION = "below"
local DEFAULT_SUGGESTION_ICON_SIZE = 18
local DEFAULT_SUGGESTION_AVAILABLE_SOUND = "none"

local MIN_MAIN_ICON_SIZE = 14
local MAX_MAIN_ICON_SIZE = 48
local MIN_QUEUE_ICON_PERCENT = 25
local MAX_QUEUE_ICON_PERCENT = 50
local MIN_FONT_SIZE = 14
local MAX_FONT_SIZE = 48
local MIN_SUGGESTION_ICON_SIZE = 14
local MAX_SUGGESTION_ICON_SIZE = 48
local DROPDOWN_ROW_HEIGHT = 24
local MAX_DROPDOWN_ROWS = 7

local HORN_ICON = "Interface\\Icons\\INV_Misc_Horn_01"

local FALLBACK_SUGGESTION_SOUND_OPTIONS = {
	{ label = "None", value = "none" },
	{ label = "Raid Warning", value = "raid-warning", soundKit = "RAID_WARNING" },
	{ label = "Ready Check", value = "ready-check", soundKit = "READY_CHECK" },
	{ label = "Map Ping", value = "map-ping", soundKit = "MAP_PING" },
}

local function ClampNumber(value, minValue, maxValue, fallback)
	value = tonumber(value)
	if not value then return fallback end
	value = math.floor(value + 0.5)
	if value < minValue then return minValue end
	if value > maxValue then return maxValue end
	return value
end

local function GetDefaultFont()
	return STANDARD_TEXT_FONT or UNIT_NAME_FONT or DAMAGE_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end

local function NormalizeSuggestionPosition(value)
	if value == "above" or value == "below" then return value end
	return DEFAULT_SUGGESTION_POSITION
end

local function EnsureDB()
	KravaCooldownTrackerDB = KravaCooldownTrackerDB or {}
	KravaCooldownTrackerDB.config = KravaCooldownTrackerDB.config or {}
	return KravaCooldownTrackerDB.config
end

local function GetLegacySuggestionKey(suffix)
	return "notifi" .. "cation" .. suffix
end

local function IsUsableFontPath(path)
	return type(path) == "string" and path ~= ""
end

local function AddFontOption(options, seen, label, path)
	if not IsUsableFontPath(path) or seen[path] then return end
	seen[path] = true
	options[#options + 1] = { label = label, path = path }
end

local function GetSharedMedia()
	if not LibStub then return nil end
	return LibStub("LibSharedMedia-3.0", true)
end

local function GetSharedMediaType(media, fallback)
	return media and media.MediaType and media.MediaType[fallback] or string.lower(fallback)
end

local function AddSoundOption(options, seen, label, value, path, soundKit)
	if type(label) ~= "string" or label == "" or seen[value] then return end
	seen[value] = true
	options[#options + 1] = { label = label, value = value, path = path, soundKit = soundKit }
end

local function AddSharedMediaFonts(options, seen)
	local media = GetSharedMedia()
	if not media or not media.List or not media.Fetch then return end

	local fontType = media.MediaType and media.MediaType.FONT or "font"
	local fonts = media:List(fontType)
	if type(fonts) ~= "table" then return end

	for _, name in ipairs(fonts) do
		AddFontOption(options, seen, name, media:Fetch(fontType, name))
	end
end

function C.GetFontOptions()
	local options = {}
	local seen = {}

	AddFontOption(options, seen, "Default", GetDefaultFont())
	AddSharedMediaFonts(options, seen)
	AddFontOption(options, seen, "Standard", STANDARD_TEXT_FONT)
	AddFontOption(options, seen, "Unit Name", UNIT_NAME_FONT)
	AddFontOption(options, seen, "Damage", DAMAGE_TEXT_FONT)
	AddFontOption(options, seen, "Friz Quadrata", "Fonts\\FRIZQT__.TTF")
	AddFontOption(options, seen, "Arial Narrow", "Fonts\\ARIALN.TTF")
	AddFontOption(options, seen, "Morpheus", "Fonts\\MORPHEUS.TTF")
	AddFontOption(options, seen, "Skurri", "Fonts\\SKURRI.TTF")

	return options
end

function C.GetDefaultFont()
	return GetDefaultFont()
end

function C.GetSuggestionSoundOptions()
	local options = {}
	local seen = {}

	AddSoundOption(options, seen, "None", "none")

	local media = GetSharedMedia()
	if media and media.List and media.Fetch then
		local soundType = GetSharedMediaType(media, "SOUND")
		local sounds = media:List(soundType)
		if type(sounds) == "table" then
			table.sort(sounds)
			for _, name in ipairs(sounds) do
				local path = media:Fetch(soundType, name, true)
				if name ~= "None" and path then
					AddSoundOption(options, seen, name, name, path)
				end
			end
		end
	end

	for _, option in ipairs(FALLBACK_SUGGESTION_SOUND_OPTIONS) do
		AddSoundOption(options, seen, option.label, option.value, option.path, option.soundKit)
	end

	return options
end

local function GetSuggestionSoundOption(value)
	for _, option in ipairs(C.GetSuggestionSoundOptions()) do
		if option.value == value then return option end
	end
	return nil
end

local function NormalizeSuggestionAvailableSound(value)
	if GetSuggestionSoundOption(value) then return value end
	return DEFAULT_SUGGESTION_AVAILABLE_SOUND
end

local function GetSuggestionSoundLabel(value)
	local option = GetSuggestionSoundOption(value)
	return option and option.label or "None"
end

function C.GetSuggestionSoundLabel(value)
	return GetSuggestionSoundLabel(value)
end

function C.PlaySuggestionAvailableSound(value)
	local option = GetSuggestionSoundOption(value)
	if not option or option.value == "none" then return end

	if option.path and PlaySoundFile then
		PlaySoundFile(option.path, "Master")
		return
	end

	local soundKit = option.soundKit
	if type(soundKit) == "string" and SOUNDKIT then
		soundKit = SOUNDKIT[soundKit]
	end
	if soundKit and PlaySound then
		PlaySound(soundKit, "Master")
	end
end

function C.Normalize()
	local cfg = EnsureDB()

	cfg.mainIconSize = ClampNumber(cfg.mainIconSize, MIN_MAIN_ICON_SIZE, MAX_MAIN_ICON_SIZE, DEFAULT_MAIN_ICON_SIZE)
	cfg.queueIconPercent = ClampNumber(cfg.queueIconPercent, MIN_QUEUE_ICON_PERCENT, MAX_QUEUE_ICON_PERCENT, DEFAULT_QUEUE_ICON_PERCENT)
	cfg.fontSize = ClampNumber(cfg.fontSize, MIN_FONT_SIZE, MAX_FONT_SIZE, DEFAULT_FONT_SIZE)
	local legacyIconSizeKey = GetLegacySuggestionKey("IconSize")
	local legacyPositionKey = GetLegacySuggestionKey("Position")
	if cfg.suggestionIconSize == nil and cfg[legacyIconSizeKey] ~= nil then
		cfg.suggestionIconSize = cfg[legacyIconSizeKey]
	end
	if cfg.suggestionPosition == nil and cfg[legacyPositionKey] ~= nil then
		cfg.suggestionPosition = cfg[legacyPositionKey]
	end
	cfg[legacyIconSizeKey] = nil
	cfg[legacyPositionKey] = nil
	cfg.suggestionIconSize = ClampNumber(cfg.suggestionIconSize, MIN_SUGGESTION_ICON_SIZE, MAX_SUGGESTION_ICON_SIZE, DEFAULT_SUGGESTION_ICON_SIZE)
	cfg.suggestionPosition = NormalizeSuggestionPosition(cfg.suggestionPosition)
	cfg.suggestionAvailableSound = NormalizeSuggestionAvailableSound(cfg.suggestionAvailableSound)

	if not IsUsableFontPath(cfg.fontFace) then
		cfg.fontFace = GetDefaultFont()
	end

	if type(cfg.locked) ~= "boolean" then
		cfg.locked = DEFAULT_LOCKED
	end

	if type(cfg.disableTrinketUsageOnClick) ~= "boolean" then
		cfg.disableTrinketUsageOnClick = DEFAULT_DISABLE_TRINKET_USAGE_ON_CLICK
	end

	if type(cfg.disableUpperTrinketSuggestions) ~= "boolean" then
		cfg.disableUpperTrinketSuggestions = DEFAULT_DISABLE_UPPER_TRINKET_SUGGESTIONS
	end

	if type(cfg.disableLowerTrinketSuggestions) ~= "boolean" then
		cfg.disableLowerTrinketSuggestions = DEFAULT_DISABLE_LOWER_TRINKET_SUGGESTIONS
	end

	return cfg
end

function C.Get()
	return C.Normalize()
end

function C.Set(key, value)
	local cfg = EnsureDB()
	cfg[key] = value
	C.Normalize()
	return cfg[key]
end

function C.SetRefreshCallback(callback)
	C.refreshCallback = callback
end

function C.RefreshChanged()
	if C.refreshCallback then
		C.refreshCallback(C.Get())
	end
end

local function SetAndRefresh(key, value)
	C.Set(key, value)
	C.RefreshChanged()
end

local function GetFontLabel(path)
	for _, option in ipairs(C.GetFontOptions()) do
		if option.path == path then return option.label end
	end
	return path or "Default"
end

local function StylePanel(frame)
	if frame.SetBackdrop then
		frame:SetBackdrop({
			bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true,
			tileSize = 16,
			edgeSize = 12,
			insets = { left = 3, right = 3, top = 3, bottom = 3 },
		})
		frame:SetBackdropColor(0.04, 0.04, 0.05, 0.96)
		frame:SetBackdropBorderColor(0.45, 0.45, 0.45, 0.9)
	end
end

local function CreateLabel(parent, text, x, y)
	local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	label:SetText(text)
	label:SetTextColor(0.85, 0.85, 0.85, 1)
	return label
end

local function CreateSectionHeader(parent, text, x, y)
	local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	label:SetText(text)
	return label
end

local function CreateRangeSlider(parent, key, x, y, width, minValue, maxValue, suffix)
	local name = "KravaCooldownTracker" .. key .. "Slider"
	local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
	slider:SetSize(width, 20)
	slider:SetPoint("TOPRIGHT", parent, "TOPRIGHT", x, y)
	if slider.SetOrientation then slider:SetOrientation("HORIZONTAL") end
	slider:SetMinMaxValues(minValue, maxValue)
	slider:SetValueStep(1)
	if slider.SetStepsPerPage then slider:SetStepsPerPage(1) end
	if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end

	slider.Text = slider.Text or _G[name .. "Text"]
	slider.Low = slider.Low or _G[name .. "Low"]
	slider.High = slider.High or _G[name .. "High"]

	if slider.Text then slider.Text:SetText("") end
	if slider.Low then slider.Low:SetText(tostring(minValue)) end
	if slider.High then slider.High:SetText(tostring(maxValue)) end

	slider.track = slider:CreateTexture(nil, "BACKGROUND")
	slider.track:SetPoint("LEFT", slider, "LEFT", 4, 0)
	slider.track:SetPoint("RIGHT", slider, "RIGHT", -4, 0)
	slider.track:SetHeight(4)
	slider.track:SetColorTexture(0.55, 0.55, 0.55, 0.85)

	slider.valueTooltip = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	slider.valueTooltip:SetPoint("BOTTOM", slider, "TOP", 0, 5)
	slider.valueTooltip:SetTextColor(1, 0.82, 0, 1)

	slider:SetScript("OnValueChanged", function(self, value)
		value = ClampNumber(value, minValue, maxValue, minValue)
		if self:GetValue() ~= value then
			self:SetValue(value)
			return
		end
		if self.valueTooltip then
			self.valueTooltip:SetText(tostring(value) .. (suffix or ""))
		end
		SetAndRefresh(key, value)
	end)

	return slider
end

local function CreateSettingCheckbox(parent, key, x, y)
	local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	check:SetSize(24, 24)
	check:SetPoint("TOPRIGHT", parent, "TOPRIGHT", x, y)
	check:SetScript("OnClick", function(self)
		SetAndRefresh(key, self:GetChecked() and true or false)
	end)
	return check
end

local function RefreshModalValues(frame)
	if not frame then return end
	local cfg = C.Get()

	if frame.mainIconSizeSlider then frame.mainIconSizeSlider:SetValue(cfg.mainIconSize) end
	if frame.queueIconPercentSlider then frame.queueIconPercentSlider:SetValue(cfg.queueIconPercent) end
	if frame.fontSizeSlider then frame.fontSizeSlider:SetValue(cfg.fontSize) end
	if frame.lockedCheck then frame.lockedCheck:SetChecked(cfg.locked) end
	if frame.disableTrinketUsageCheck then frame.disableTrinketUsageCheck:SetChecked(cfg.disableTrinketUsageOnClick) end
	if frame.disableUpperTrinketSuggestionsCheck then frame.disableUpperTrinketSuggestionsCheck:SetChecked(cfg.disableUpperTrinketSuggestions) end
	if frame.disableLowerTrinketSuggestionsCheck then frame.disableLowerTrinketSuggestionsCheck:SetChecked(cfg.disableLowerTrinketSuggestions) end
	if frame.suggestionIconSizeSlider then frame.suggestionIconSizeSlider:SetValue(cfg.suggestionIconSize) end

	if frame.fontDropdown and frame.fontDropdown.Refresh then
		frame.fontDropdown:Refresh(cfg)
	end

	if frame.suggestionPositionDropdown and frame.suggestionPositionDropdown.Refresh then
		frame.suggestionPositionDropdown:Refresh(cfg)
	end

	if frame.suggestionAvailableSoundDropdown and frame.suggestionAvailableSoundDropdown.Refresh then
		frame.suggestionAvailableSoundDropdown:Refresh(cfg)
	end
end

local StyleDropdownButton

local function CreateFontDropdown(parent, x, y)
	local backdropTemplate = BackdropTemplateMixin and "BackdropTemplate" or nil
	local dropdown = CreateFrame("Button", "KravaCooldownTrackerFontDropdown", parent, backdropTemplate)
	dropdown:SetSize(172, 22)
	dropdown:SetPoint("TOPRIGHT", parent, "TOPRIGHT", x, y)
	StyleDropdownButton(dropdown)

	dropdown.text = dropdown:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	dropdown.text:SetPoint("LEFT", dropdown, "LEFT", 8, 0)
	dropdown.text:SetPoint("RIGHT", dropdown, "RIGHT", -26, 0)
	dropdown.text:SetJustifyH("LEFT")

	dropdown.arrow = dropdown:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	dropdown.arrow:SetPoint("RIGHT", dropdown, "RIGHT", -8, 0)
	dropdown.arrow:SetText("v")

	local menu = CreateFrame("Frame", "KravaCooldownTrackerFontMenu", dropdown, backdropTemplate)
	menu:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 0, -2)
	menu:SetFrameStrata("DIALOG")
	menu:SetFrameLevel(dropdown:GetFrameLevel() + 10)
	menu.rows = {}
	StylePanel(menu)
	menu:Hide()
	dropdown.menu = menu

	local function SelectFont(path)
		SetAndRefresh("fontFace", path)
		dropdown:Refresh(C.Get())
		menu:Hide()
	end

	local ScrollRows

	local function ClampMenuOffset(options)
		local maxOffset = math.max(1, #options - MAX_DROPDOWN_ROWS + 1)
		menu.offset = math.min(math.max(menu.offset or 1, 1), maxOffset)
	end

	local function EnsureRows(options)
		local visibleCount = math.min(#options, MAX_DROPDOWN_ROWS)
		menu:SetSize(172, (visibleCount * DROPDOWN_ROW_HEIGHT) + 4)

		for rowIndex = 1, MAX_DROPDOWN_ROWS do
			local row = menu.rows[rowIndex]
			if not row then
				row = CreateFrame("Button", nil, menu)
				row:SetSize(168, DROPDOWN_ROW_HEIGHT)
				row:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -2 - ((rowIndex - 1) * DROPDOWN_ROW_HEIGHT))
				row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
				row.text:SetPoint("LEFT", row, "LEFT", 7, 0)
				row.text:SetPoint("RIGHT", row, "RIGHT", -7, 0)
				row.text:SetJustifyH("LEFT")
				row:SetScript("OnClick", function(self)
					if self.option then
						SelectFont(self.option.path)
					end
				end)
				row:EnableMouseWheel(true)
				row:SetScript("OnMouseWheel", function(_, delta)
					if ScrollRows then ScrollRows(delta) end
				end)
				menu.rows[rowIndex] = row
			end
		end
	end

	local function RenderRows(cfg)
		cfg = cfg or C.Get()
		local options = C.GetFontOptions()
		if not menu.offset then
			for index, option in ipairs(options) do
				if option.path == cfg.fontFace then
					local maxOffset = math.max(1, #options - MAX_DROPDOWN_ROWS + 1)
					menu.offset = math.min(math.max(index - math.floor(MAX_DROPDOWN_ROWS / 2), 1), maxOffset)
					break
				end
			end
		end
		ClampMenuOffset(options)
		EnsureRows(options)

		for rowIndex, row in ipairs(menu.rows) do
			local option = options[(menu.offset or 1) + rowIndex - 1]
			row.option = option
			if option then
				row.text:SetText(option.label)
				if option.path == cfg.fontFace then
					row.text:SetTextColor(1, 0.82, 0, 1)
				else
					row.text:SetTextColor(1, 1, 1, 1)
				end
				row:Show()
			else
				row:Hide()
			end
		end

		return options
	end

	ScrollRows = function(delta)
		local options = C.GetFontOptions()
		local maxOffset = math.max(1, #options - MAX_DROPDOWN_ROWS + 1)
		if delta < 0 then
			menu.offset = math.min((menu.offset or 1) + 1, maxOffset)
		elseif delta > 0 then
			menu.offset = math.max((menu.offset or 1) - 1, 1)
		end
		RenderRows(C.Get())
	end

	function dropdown:Refresh(cfg)
		cfg = cfg or C.Get()
		self.text:SetText(GetFontLabel(cfg.fontFace))
		RenderRows(cfg)
	end

	menu:EnableMouseWheel(true)
	menu:SetScript("OnMouseWheel", function(_, delta)
		ScrollRows(delta)
	end)

	dropdown:SetScript("OnClick", function()
		if menu:IsShown() then
			menu:Hide()
		else
			menu.offset = nil
			dropdown:Refresh(C.Get())
			menu:Show()
		end
	end)

	return dropdown
end

local function CreateSuggestionPositionDropdown(parent, x, y)
	local backdropTemplate = BackdropTemplateMixin and "BackdropTemplate" or nil
	local dropdown = CreateFrame("Button", "KravaCooldownTrackerSuggestionPositionDropdown", parent, backdropTemplate)
	dropdown:SetSize(84, 22)
	dropdown:SetPoint("TOPRIGHT", parent, "TOPRIGHT", x, y)
	StyleDropdownButton(dropdown)

	dropdown.text = dropdown:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	dropdown.text:SetPoint("LEFT", dropdown, "LEFT", 8, 0)
	dropdown.text:SetPoint("RIGHT", dropdown, "RIGHT", -24, 0)
	dropdown.text:SetJustifyH("LEFT")

	dropdown.arrow = dropdown:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	dropdown.arrow:SetPoint("RIGHT", dropdown, "RIGHT", -8, 0)
	dropdown.arrow:SetText("v")

	local options = {
		{ label = "Below", value = "below" },
		{ label = "Above", value = "above" },
	}

	local menu = CreateFrame("Frame", "KravaCooldownTrackerSuggestionPositionMenu", dropdown, backdropTemplate)
	menu:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 0, -2)
	menu:SetSize(84, (#options * DROPDOWN_ROW_HEIGHT) + 4)
	menu:SetFrameStrata("DIALOG")
	menu:SetFrameLevel(dropdown:GetFrameLevel() + 10)
	menu.rows = {}
	StylePanel(menu)
	menu:Hide()
	dropdown.menu = menu

	local function SelectPosition(value)
		SetAndRefresh("suggestionPosition", value)
		dropdown:Refresh(C.Get())
		menu:Hide()
	end

	for index, option in ipairs(options) do
		local row = CreateFrame("Button", nil, menu)
		row:SetSize(80, DROPDOWN_ROW_HEIGHT)
		row:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -2 - ((index - 1) * DROPDOWN_ROW_HEIGHT))
		row.option = option
		row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		row.text:SetPoint("LEFT", row, "LEFT", 7, 0)
		row.text:SetPoint("RIGHT", row, "RIGHT", -7, 0)
		row.text:SetJustifyH("LEFT")
		row.text:SetText(option.label)
		row:SetScript("OnClick", function(self)
			SelectPosition(self.option.value)
		end)
		menu.rows[index] = row
	end

	function dropdown:Refresh(cfg)
		cfg = cfg or C.Get()
		local label = cfg.suggestionPosition == "above" and "Above" or "Below"
		self.text:SetText(label)
		for _, row in ipairs(menu.rows) do
			if row.option.value == cfg.suggestionPosition then
				row.text:SetTextColor(1, 0.82, 0, 1)
			else
				row.text:SetTextColor(1, 1, 1, 1)
			end
		end
	end

	dropdown:SetScript("OnClick", function()
		if menu:IsShown() then
			menu:Hide()
		else
			dropdown:Refresh(C.Get())
			menu:Show()
		end
	end)

	return dropdown
end

function StyleDropdownButton(button)
	if button.SetBackdrop then
		button:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8x8",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = false,
			edgeSize = 8,
			insets = { left = 2, right = 2, top = 2, bottom = 2 },
		})
		button:SetBackdropColor(0.08, 0.08, 0.09, 0.94)
		button:SetBackdropBorderColor(0.36, 0.36, 0.36, 0.9)
	end
end

local function CreateSuggestionSoundDropdown(parent, x, y)
	local backdropTemplate = BackdropTemplateMixin and "BackdropTemplate" or nil
	local dropdown = CreateFrame("Button", "KravaCooldownTrackerSuggestionSoundDropdown", parent, backdropTemplate)
	dropdown:SetSize(172, 22)
	dropdown:SetPoint("TOPRIGHT", parent, "TOPRIGHT", x, y)
	StyleDropdownButton(dropdown)

	dropdown.text = dropdown:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	dropdown.text:SetPoint("LEFT", dropdown, "LEFT", 8, 0)
	dropdown.text:SetPoint("RIGHT", dropdown, "RIGHT", -26, 0)
	dropdown.text:SetJustifyH("LEFT")

	dropdown.arrow = dropdown:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	dropdown.arrow:SetPoint("RIGHT", dropdown, "RIGHT", -8, 0)
	dropdown.arrow:SetText("v")

	local menu = CreateFrame("Frame", "KravaCooldownTrackerSuggestionSoundMenu", dropdown, backdropTemplate)
	menu:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 0, -2)
	menu:SetFrameStrata("DIALOG")
	menu:SetFrameLevel(dropdown:GetFrameLevel() + 10)
	menu.rows = {}
	StylePanel(menu)
	menu:Hide()
	dropdown.menu = menu

	local function SelectSound(value)
		SetAndRefresh("suggestionAvailableSound", value)
		dropdown:Refresh(C.Get())
		menu:Hide()
	end

	local ScrollRows

	local function ClampMenuOffset()
		local options = C.GetSuggestionSoundOptions()
		local maxOffset = math.max(1, #options - MAX_DROPDOWN_ROWS + 1)
		menu.offset = math.min(math.max(menu.offset or 1, 1), maxOffset)
	end

	local function EnsureRows(options)
		local visibleCount = math.min(#options, MAX_DROPDOWN_ROWS)
		menu:SetSize(172, (visibleCount * DROPDOWN_ROW_HEIGHT) + 4)

		for rowIndex = 1, MAX_DROPDOWN_ROWS do
			local row = menu.rows[rowIndex]
			if not row then
				row = CreateFrame("Frame", nil, menu)
				row:SetSize(168, DROPDOWN_ROW_HEIGHT)
				row:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -2 - ((rowIndex - 1) * DROPDOWN_ROW_HEIGHT))

				row.select = CreateFrame("Button", nil, row)
				row.select:SetPoint("LEFT", row, "LEFT", 2, 0)
				row.select:SetPoint("RIGHT", row, "RIGHT", -26, 0)
				row.select:SetHeight(20)

				row.text = row.select:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
				row.text:SetPoint("LEFT", row.select, "LEFT", 5, 0)
				row.text:SetPoint("RIGHT", row.select, "RIGHT", -4, 0)
				row.text:SetJustifyH("LEFT")

				row.preview = CreateFrame("Button", nil, row)
				row.preview:SetSize(20, 20)
				row.preview:SetPoint("RIGHT", row, "RIGHT", -3, 0)
				row.preview.icon = row.preview:CreateTexture(nil, "ARTWORK")
				row.preview.icon:SetAllPoints(row.preview)
				row.preview.icon:SetTexture(HORN_ICON)
				row.preview.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

				row.select:SetScript("OnClick", function(self)
					if self:GetParent().option then
						SelectSound(self:GetParent().option.value)
					end
				end)
				row.preview:SetScript("OnClick", function(self)
					if self:GetParent().option then
						C.PlaySuggestionAvailableSound(self:GetParent().option.value)
					end
				end)
				row:EnableMouseWheel(true)
				row:SetScript("OnMouseWheel", function(_, delta)
					if ScrollRows then ScrollRows(delta) end
				end)
				row.select:EnableMouseWheel(true)
				row.select:SetScript("OnMouseWheel", function(_, delta)
					if ScrollRows then ScrollRows(delta) end
				end)
				row.preview:EnableMouseWheel(true)
				row.preview:SetScript("OnMouseWheel", function(_, delta)
					if ScrollRows then ScrollRows(delta) end
				end)

				menu.rows[rowIndex] = row
			end
		end
	end

	local function RenderRows(cfg)
		cfg = cfg or C.Get()
		local options = C.GetSuggestionSoundOptions()
		if not menu.offset then
			for index, option in ipairs(options) do
				if option.value == cfg.suggestionAvailableSound then
					local maxOffset = math.max(1, #options - MAX_DROPDOWN_ROWS + 1)
					menu.offset = math.min(math.max(index - math.floor(MAX_DROPDOWN_ROWS / 2), 1), maxOffset)
					break
				end
			end
		end
		ClampMenuOffset()
		EnsureRows(options)

		for rowIndex, row in ipairs(menu.rows) do
			local option = options[(menu.offset or 1) + rowIndex - 1]
			row.option = option
			if option then
				row.text:SetText(option.label)
				if option.value == cfg.suggestionAvailableSound then
					row.text:SetTextColor(1, 0.82, 0, 1)
				else
					row.text:SetTextColor(1, 1, 1, 1)
				end
				if option.value == "none" then
					row.preview.icon:SetDesaturated(true)
					row.preview.icon:SetVertexColor(0.55, 0.55, 0.55, 1)
				else
					row.preview.icon:SetDesaturated(false)
					row.preview.icon:SetVertexColor(1, 1, 1, 1)
				end
				row:Show()
			else
				row:Hide()
			end
		end
	end

	function dropdown:Refresh(cfg)
		cfg = cfg or C.Get()
		self.text:SetText(GetSuggestionSoundLabel(cfg.suggestionAvailableSound))
		RenderRows(cfg)
	end

	ScrollRows = function(delta)
		local options = C.GetSuggestionSoundOptions()
		local maxOffset = math.max(1, #options - MAX_DROPDOWN_ROWS + 1)
		if delta < 0 then
			menu.offset = math.min((menu.offset or 1) + 1, maxOffset)
		elseif delta > 0 then
			menu.offset = math.max((menu.offset or 1) - 1, 1)
		end
		RenderRows(C.Get())
	end

	menu:EnableMouseWheel(true)
	menu:SetScript("OnMouseWheel", function(_, delta)
		if ScrollRows then ScrollRows(delta) end
	end)

	dropdown:SetScript("OnClick", function()
		if menu:IsShown() then
			menu:Hide()
		else
			menu.offset = nil
			dropdown:Refresh(C.Get())
			menu:Show()
		end
	end)

	return dropdown
end

function C.CreateModal()
	if C.modal then return C.modal end
	if not UIParent then return nil end

	local backdropTemplate = BackdropTemplateMixin and "BackdropTemplate" or nil
	local frame = CreateFrame("Frame", "KravaCooldownTrackerConfigModal", UIParent, backdropTemplate)
	frame:SetSize(320, 524)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	frame:SetFrameStrata("DIALOG")
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	StylePanel(frame)

	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -10)
	title:SetText("KCT")

	local close = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	close:SetSize(54, 20)
	close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -8)
	close:SetText("Close")
	close:SetScript("OnClick", function() frame:Hide() end)

	CreateSectionHeader(frame, "General", 14, -42)

	CreateLabel(frame, "Locked", 14, -64)
	frame.lockedCheck = CreateSettingCheckbox(frame, "locked", -18, -58)

	CreateLabel(frame, "Font", 14, -90)
	frame.fontDropdown = CreateFontDropdown(frame, -18, -84)

	CreateLabel(frame, "Font size", 14, -132)
	frame.fontSizeSlider = CreateRangeSlider(frame, "fontSize", -18, -134, 142, MIN_FONT_SIZE, MAX_FONT_SIZE, "px")

	CreateSectionHeader(frame, "Main Icon", 14, -176)

	CreateLabel(frame, "Icon size", 14, -204)
	frame.mainIconSizeSlider = CreateRangeSlider(frame, "mainIconSize", -18, -206, 142, MIN_MAIN_ICON_SIZE, MAX_MAIN_ICON_SIZE, "px")

	CreateLabel(frame, "Queue icon size", 14, -248)
	frame.queueIconPercentSlider = CreateRangeSlider(frame, "queueIconPercent", -18, -250, 142, MIN_QUEUE_ICON_PERCENT, MAX_QUEUE_ICON_PERCENT, "%")

	CreateLabel(frame, "Disable trinket usage on click", 14, -292)
	frame.disableTrinketUsageCheck = CreateSettingCheckbox(frame, "disableTrinketUsageOnClick", -18, -286)

	CreateSectionHeader(frame, "Suggestions", 14, -326)

	CreateLabel(frame, "Position", 14, -352)
	frame.suggestionPositionDropdown = CreateSuggestionPositionDropdown(frame, -18, -346)

	CreateLabel(frame, "Icon size", 14, -386)
	frame.suggestionIconSizeSlider = CreateRangeSlider(frame, "suggestionIconSize", -18, -388, 142, MIN_SUGGESTION_ICON_SIZE, MAX_SUGGESTION_ICON_SIZE, "px")

	CreateLabel(frame, "Available sound", 14, -430)
	frame.suggestionAvailableSoundDropdown = CreateSuggestionSoundDropdown(frame, -18, -424)

	CreateLabel(frame, "Disable suggestions for upper trinket", 14, -476)
	frame.disableUpperTrinketSuggestionsCheck = CreateSettingCheckbox(frame, "disableUpperTrinketSuggestions", -18, -470)

	CreateLabel(frame, "Disable suggestions for lower trinket", 14, -502)
	frame.disableLowerTrinketSuggestionsCheck = CreateSettingCheckbox(frame, "disableLowerTrinketSuggestions", -18, -496)

	frame:SetScript("OnShow", function(self)
		RefreshModalValues(self)
	end)
	frame:Hide()

	C.modal = frame
	return frame
end

function C.ToggleModal()
	local frame = C.CreateModal()
	if not frame then return end
	if frame:IsShown() then
		frame:Hide()
	else
		RefreshModalValues(frame)
		frame:Show()
	end
end

SLASH_KRAVACOOLDOWNTRACKER1 = "/kct"
SlashCmdList = SlashCmdList or {}
SlashCmdList.KRAVACOOLDOWNTRACKER = function()
	C.ToggleModal()
end
