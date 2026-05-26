-- KravaCooldownTracker_Config.lua
-- Saved configuration, validation, and options UI helpers.

KravaCooldownTracker_Config = KravaCooldownTracker_Config or {}
local C = KravaCooldownTracker_Config

local DEFAULT_MAIN_ICON_SIZE = 32
local DEFAULT_QUEUE_ICON_PERCENT = 25
local DEFAULT_FONT_SIZE = 14
local DEFAULT_LOCKED = true
local DEFAULT_DISABLE_TRINKET_USAGE_ON_CLICK = true
local DEFAULT_NOTIFICATION_POSITION = "below"
local DEFAULT_NOTIFICATION_ICON_SIZE = 18

local MIN_MAIN_ICON_SIZE = 14
local MAX_MAIN_ICON_SIZE = 48
local MIN_QUEUE_ICON_PERCENT = 25
local MAX_QUEUE_ICON_PERCENT = 50
local MIN_FONT_SIZE = 14
local MAX_FONT_SIZE = 48
local MIN_NOTIFICATION_ICON_SIZE = 14
local MAX_NOTIFICATION_ICON_SIZE = 48

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

local function NormalizeNotificationPosition(value)
	if value == "above" or value == "below" then return value end
	return DEFAULT_NOTIFICATION_POSITION
end

local function EnsureDB()
	KravaCooldownTrackerDB = KravaCooldownTrackerDB or {}
	KravaCooldownTrackerDB.config = KravaCooldownTrackerDB.config or {}
	return KravaCooldownTrackerDB.config
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

function C.Normalize()
	local cfg = EnsureDB()

	cfg.mainIconSize = ClampNumber(cfg.mainIconSize, MIN_MAIN_ICON_SIZE, MAX_MAIN_ICON_SIZE, DEFAULT_MAIN_ICON_SIZE)
	cfg.queueIconPercent = ClampNumber(cfg.queueIconPercent, MIN_QUEUE_ICON_PERCENT, MAX_QUEUE_ICON_PERCENT, DEFAULT_QUEUE_ICON_PERCENT)
	cfg.fontSize = ClampNumber(cfg.fontSize, MIN_FONT_SIZE, MAX_FONT_SIZE, DEFAULT_FONT_SIZE)
	cfg.notificationIconSize = ClampNumber(cfg.notificationIconSize, MIN_NOTIFICATION_ICON_SIZE, MAX_NOTIFICATION_ICON_SIZE, DEFAULT_NOTIFICATION_ICON_SIZE)
	cfg.notificationPosition = NormalizeNotificationPosition(cfg.notificationPosition)

	if not IsUsableFontPath(cfg.fontFace) then
		cfg.fontFace = GetDefaultFont()
	end

	if type(cfg.locked) ~= "boolean" then
		cfg.locked = DEFAULT_LOCKED
	end

	if type(cfg.disableTrinketUsageOnClick) ~= "boolean" then
		cfg.disableTrinketUsageOnClick = DEFAULT_DISABLE_TRINKET_USAGE_ON_CLICK
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

function C.NotifyChanged()
	if C.refreshCallback then
		C.refreshCallback(C.Get())
	end
end

local function SetAndNotify(key, value)
	C.Set(key, value)
	C.NotifyChanged()
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
		SetAndNotify(key, value)
	end)

	return slider
end

local function CreateSettingCheckbox(parent, key, x, y)
	local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	check:SetSize(24, 24)
	check:SetPoint("TOPRIGHT", parent, "TOPRIGHT", x, y)
	check:SetScript("OnClick", function(self)
		SetAndNotify(key, self:GetChecked() and true or false)
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
	if frame.notificationIconSizeSlider then frame.notificationIconSizeSlider:SetValue(cfg.notificationIconSize) end

	if frame.fontDropdown and UIDropDownMenu_SetText then
		UIDropDownMenu_SetText(frame.fontDropdown, GetFontLabel(cfg.fontFace))
	end

	if frame.notificationPositionDropdown and UIDropDownMenu_SetText then
		UIDropDownMenu_SetText(frame.notificationPositionDropdown, cfg.notificationPosition == "above" and "Above" or "Below")
	end
end

local function CreateFontDropdown(parent, x, y)
	local dropdown = CreateFrame("Frame", "KravaCooldownTrackerFontDropdown", parent, "UIDropDownMenuTemplate")
	dropdown:SetPoint("TOPRIGHT", parent, "TOPRIGHT", x, y)

	if UIDropDownMenu_SetWidth then UIDropDownMenu_SetWidth(dropdown, 172) end

	if UIDropDownMenu_Initialize then
		UIDropDownMenu_Initialize(dropdown, function(self, level)
			local cfg = C.Get()
			for _, option in ipairs(C.GetFontOptions()) do
				local info = UIDropDownMenu_CreateInfo()
				info.text = option.label
				info.value = option.path
				info.checked = cfg.fontFace == option.path
				info.func = function()
					SetAndNotify("fontFace", option.path)
					if UIDropDownMenu_SetSelectedValue then
						UIDropDownMenu_SetSelectedValue(dropdown, option.path)
					end
					if UIDropDownMenu_SetText then
						UIDropDownMenu_SetText(dropdown, option.label)
					end
				end
				UIDropDownMenu_AddButton(info, level)
			end
		end)
	end

	return dropdown
end

local function CreateNotificationPositionDropdown(parent, x, y)
	local dropdown = CreateFrame("Frame", "KravaCooldownTrackerNotificationPositionDropdown", parent, "UIDropDownMenuTemplate")
	dropdown:SetPoint("TOPRIGHT", parent, "TOPRIGHT", x, y)

	if UIDropDownMenu_SetWidth then UIDropDownMenu_SetWidth(dropdown, 84) end

	if UIDropDownMenu_Initialize then
		UIDropDownMenu_Initialize(dropdown, function(self, level)
			local cfg = C.Get()
			local options = {
				{ label = "Below", value = "below" },
				{ label = "Above", value = "above" },
			}

			for _, option in ipairs(options) do
				local info = UIDropDownMenu_CreateInfo()
				info.text = option.label
				info.value = option.value
				info.checked = cfg.notificationPosition == option.value
				info.func = function()
					SetAndNotify("notificationPosition", option.value)
					if UIDropDownMenu_SetSelectedValue then
						UIDropDownMenu_SetSelectedValue(dropdown, option.value)
					end
					if UIDropDownMenu_SetText then
						UIDropDownMenu_SetText(dropdown, option.label)
					end
				end
				UIDropDownMenu_AddButton(info, level)
			end
		end)
	end

	return dropdown
end

function C.CreateModal()
	if C.modal then return C.modal end
	if not UIParent then return nil end

	local backdropTemplate = BackdropTemplateMixin and "BackdropTemplate" or nil
	local frame = CreateFrame("Frame", "KravaCooldownTrackerConfigModal", UIParent, backdropTemplate)
	frame:SetSize(320, 420)
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
	frame.fontDropdown = CreateFontDropdown(frame, -2, -84)

	CreateLabel(frame, "Font size", 14, -132)
	frame.fontSizeSlider = CreateRangeSlider(frame, "fontSize", -18, -134, 142, MIN_FONT_SIZE, MAX_FONT_SIZE, "px")

	CreateSectionHeader(frame, "Main Icon", 14, -176)

	CreateLabel(frame, "Icon size", 14, -204)
	frame.mainIconSizeSlider = CreateRangeSlider(frame, "mainIconSize", -18, -206, 142, MIN_MAIN_ICON_SIZE, MAX_MAIN_ICON_SIZE, "px")

	CreateLabel(frame, "Queue icon size", 14, -248)
	frame.queueIconPercentSlider = CreateRangeSlider(frame, "queueIconPercent", -18, -250, 142, MIN_QUEUE_ICON_PERCENT, MAX_QUEUE_ICON_PERCENT, "%")

	CreateLabel(frame, "Disable trinket usage on click", 14, -292)
	frame.disableTrinketUsageCheck = CreateSettingCheckbox(frame, "disableTrinketUsageOnClick", -18, -286)

	CreateSectionHeader(frame, "Notifications", 14, -326)

	CreateLabel(frame, "Position", 14, -352)
	frame.notificationPositionDropdown = CreateNotificationPositionDropdown(frame, -2, -346)

	CreateLabel(frame, "Icon size", 14, -386)
	frame.notificationIconSizeSlider = CreateRangeSlider(frame, "notificationIconSize", -18, -388, 142, MIN_NOTIFICATION_ICON_SIZE, MAX_NOTIFICATION_ICON_SIZE, "px")

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
