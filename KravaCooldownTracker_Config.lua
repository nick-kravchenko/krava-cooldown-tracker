-- KravaCooldownTracker_Config.lua
-- Saved configuration, validation, and options UI helpers.

KravaCooldownTracker_Config = KravaCooldownTracker_Config or {}
local C = KravaCooldownTracker_Config

local DEFAULT_MAIN_ICON_SIZE = 32
local DEFAULT_QUEUE_ICON_PERCENT = 25
local DEFAULT_FONT_SIZE = 14
local DEFAULT_LOCKED = true

local MIN_MAIN_ICON_SIZE = 16
local MAX_MAIN_ICON_SIZE = 96
local MIN_QUEUE_ICON_PERCENT = 10
local MAX_QUEUE_ICON_PERCENT = 50
local MIN_FONT_SIZE = 8
local MAX_FONT_SIZE = 32

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

function C.GetFontOptions()
	local options = {}
	local seen = {}

	AddFontOption(options, seen, "Default", GetDefaultFont())
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

	if not IsUsableFontPath(cfg.fontFace) then
		cfg.fontFace = GetDefaultFont()
	end

	if type(cfg.locked) ~= "boolean" then
		cfg.locked = DEFAULT_LOCKED
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

local function CreateEditBox(parent, key, x, y, width)
	local edit = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
	edit:SetSize(width, 20)
	edit:SetPoint("TOPRIGHT", parent, "TOPRIGHT", x, y)
	edit:SetAutoFocus(false)
	edit:SetJustifyH("RIGHT")
	edit:SetNumeric(true)

	local function Commit()
		SetAndNotify(key, edit:GetNumber())
		edit:SetText(tostring(C.Get()[key]))
		edit:ClearFocus()
	end

	edit:SetScript("OnEnterPressed", Commit)
	edit:SetScript("OnEditFocusLost", Commit)
	edit:SetScript("OnEscapePressed", function(self)
		self:SetText(tostring(C.Get()[key]))
		self:ClearFocus()
	end)

	return edit
end

local function RefreshModalValues(frame)
	if not frame then return end
	local cfg = C.Get()

	if frame.mainIconSizeEdit then frame.mainIconSizeEdit:SetText(tostring(cfg.mainIconSize)) end
	if frame.queueIconPercentEdit then frame.queueIconPercentEdit:SetText(tostring(cfg.queueIconPercent)) end
	if frame.fontSizeEdit then frame.fontSizeEdit:SetText(tostring(cfg.fontSize)) end
	if frame.lockedCheck then frame.lockedCheck:SetChecked(cfg.locked) end

	if frame.fontDropdown and UIDropDownMenu_SetText then
		UIDropDownMenu_SetText(frame.fontDropdown, GetFontLabel(cfg.fontFace))
	end
end

local function CreateFontDropdown(parent, x, y)
	local dropdown = CreateFrame("Frame", "KravaCooldownTrackerFontDropdown", parent, "UIDropDownMenuTemplate")
	dropdown:SetPoint("TOPRIGHT", parent, "TOPRIGHT", x, y)

	if UIDropDownMenu_SetWidth then UIDropDownMenu_SetWidth(dropdown, 112) end

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

function C.CreateModal()
	if C.modal then return C.modal end
	if not UIParent then return nil end

	local backdropTemplate = BackdropTemplateMixin and "BackdropTemplate" or nil
	local frame = CreateFrame("Frame", "KravaCooldownTrackerConfigModal", UIParent, backdropTemplate)
	frame:SetSize(250, 176)
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

	CreateLabel(frame, "Main icon", 14, -42)
	frame.mainIconSizeEdit = CreateEditBox(frame, "mainIconSize", -18, -38, 56)

	CreateLabel(frame, "Queue icon %", 14, -68)
	frame.queueIconPercentEdit = CreateEditBox(frame, "queueIconPercent", -18, -64, 56)

	CreateLabel(frame, "Font", 14, -94)
	frame.fontDropdown = CreateFontDropdown(frame, -2, -88)

	CreateLabel(frame, "Font size", 14, -120)
	frame.fontSizeEdit = CreateEditBox(frame, "fontSize", -18, -116, 56)

	frame.lockedCheck = CreateFrame("CheckButton", nil, frame, "ChatConfigCheckButtonTemplate")
	frame.lockedCheck:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -142)
	if frame.lockedCheck.Text then
		frame.lockedCheck.Text:SetText("Locked")
	else
		local lockedLabel = frame.lockedCheck:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		lockedLabel:SetPoint("LEFT", frame.lockedCheck, "RIGHT", 2, 0)
		lockedLabel:SetText("Locked")
	end
	frame.lockedCheck:SetScript("OnClick", function(self)
		SetAndNotify("locked", self:GetChecked() and true or false)
	end)

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
