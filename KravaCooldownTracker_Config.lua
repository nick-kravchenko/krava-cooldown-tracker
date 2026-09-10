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
local DEFAULT_DEBUFF_ICON_SIZE = 32
local DEFAULT_DEBUFF_FONT_SIZE = 14
local DEFAULT_DEBUFF_PER_LINE = 8
local DEFAULT_DEBUFF_LOCKED = true
local DEFAULT_DEBUFF_DIRECTION = "horizontal"
local DEFAULT_CONSUMABLE_ICON_SIZE = 32
local DEFAULT_CONSUMABLE_FONT_SIZE = 14
local DEFAULT_CONSUMABLE_LOCKED = true
local DEFAULT_CONSUMABLE_RAID_ONLY = true

local MIN_MAIN_ICON_SIZE = 14
local MAX_MAIN_ICON_SIZE = 48
local MIN_QUEUE_ICON_PERCENT = 25
local MAX_QUEUE_ICON_PERCENT = 50
local MIN_FONT_SIZE = 14
local MAX_FONT_SIZE = 48
local MIN_SUGGESTION_ICON_SIZE = 14
local MAX_SUGGESTION_ICON_SIZE = 48
local MIN_DEBUFF_ICON_SIZE = 14
local MAX_DEBUFF_ICON_SIZE = 48
local MIN_DEBUFF_FONT_SIZE = 10
local MAX_DEBUFF_FONT_SIZE = 32
local MIN_DEBUFF_PER_LINE = 1
local MAX_DEBUFF_PER_LINE = 12
local MIN_CONSUMABLE_ICON_SIZE = 14
local MAX_CONSUMABLE_ICON_SIZE = 48
local MIN_CONSUMABLE_FONT_SIZE = 10
local MAX_CONSUMABLE_FONT_SIZE = 32
local DEFAULT_RAID_NOTES_FONT_SIZE = 12
local DEFAULT_RAID_NOTES_PADDING = 6
local DEFAULT_RAID_NOTES_GAP = 2
local DEFAULT_RAID_NOTES_BORDER_WIDTH = 1
local RAID_NOTES_STRATA = {
	"BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG",
	"FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP",
}
local DROPDOWN_ROW_HEIGHT = 24
local MAX_DROPDOWN_ROWS = 7

-- Keep in sync with KravaCooldownTracker_DebuffLogic.DEBUFFS key order (Task 2)
local DEBUFF_KEYS = {
	"majorArmorReduction",
	"curseOfRecklessness",
	"curseOfTheElements",
	"huntersMark",
	"scorpidSting",
	"judgementOfTheCrusader",
	"judgementOfWisdom",
	"demoralizingShoutRoar",
	"faerieFire",
	"judgementOfLight",
	"shadowVulnerability",
	"thunderClap",
}

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

local function NormalizeDebuffDirection(value)
	if value == "horizontal" or value == "vertical" then return value end
	return DEFAULT_DEBUFF_DIRECTION
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
	cfg.debuffIconSize = ClampNumber(cfg.debuffIconSize, MIN_DEBUFF_ICON_SIZE, MAX_DEBUFF_ICON_SIZE, DEFAULT_DEBUFF_ICON_SIZE)
	cfg.debuffFontSize = ClampNumber(cfg.debuffFontSize, MIN_DEBUFF_FONT_SIZE, MAX_DEBUFF_FONT_SIZE, DEFAULT_DEBUFF_FONT_SIZE)
	cfg.debuffPerLine = ClampNumber(cfg.debuffPerLine, MIN_DEBUFF_PER_LINE, MAX_DEBUFF_PER_LINE, DEFAULT_DEBUFF_PER_LINE)
	cfg.debuffDirection = NormalizeDebuffDirection(cfg.debuffDirection)
	cfg.consumableIconSize = ClampNumber(cfg.consumableIconSize, MIN_CONSUMABLE_ICON_SIZE, MAX_CONSUMABLE_ICON_SIZE, DEFAULT_CONSUMABLE_ICON_SIZE)
	cfg.consumableFontSize = ClampNumber(cfg.consumableFontSize, MIN_CONSUMABLE_FONT_SIZE, MAX_CONSUMABLE_FONT_SIZE, DEFAULT_CONSUMABLE_FONT_SIZE)
	local validRaidNotesStrata = false
	for _, strata in ipairs(RAID_NOTES_STRATA) do
		if cfg.raidNotesStrata == strata then validRaidNotesStrata = true; break end
	end
	if not validRaidNotesStrata then cfg.raidNotesStrata = "DIALOG" end
	cfg.raidNotesFontSize = ClampNumber(cfg.raidNotesFontSize, 8, 32, DEFAULT_RAID_NOTES_FONT_SIZE)
	cfg.raidNotesPadding = ClampNumber(cfg.raidNotesPadding, 0, 20, DEFAULT_RAID_NOTES_PADDING)
	cfg.raidNotesGap = ClampNumber(cfg.raidNotesGap, 0, 20, DEFAULT_RAID_NOTES_GAP)
	cfg.raidNotesBorderWidth = ClampNumber(cfg.raidNotesBorderWidth, 0, 8, DEFAULT_RAID_NOTES_BORDER_WIDTH)
	if type(cfg.raidNotesBackgroundColor) ~= "table" then cfg.raidNotesBackgroundColor = { 0.08, 0.08, 0.08, 0.9 } end
	if type(cfg.raidNotesBorderColor) ~= "table" then cfg.raidNotesBorderColor = { 0.4, 0.4, 0.4, 1 } end

	if not IsUsableFontPath(cfg.fontFace) then
		cfg.fontFace = GetDefaultFont()
	end

	if type(cfg.locked) ~= "boolean" then
		cfg.locked = DEFAULT_LOCKED
	end

	if type(cfg.debuffLocked) ~= "boolean" then
		cfg.debuffLocked = DEFAULT_DEBUFF_LOCKED
	end
	if type(cfg.consumableLocked) ~= "boolean" then
		cfg.consumableLocked = DEFAULT_CONSUMABLE_LOCKED
	end
	if type(cfg.consumableRaidOnly) ~= "boolean" then
		cfg.consumableRaidOnly = DEFAULT_CONSUMABLE_RAID_ONLY
	end
	if type(cfg.raidNotesLocked) ~= "boolean" then cfg.raidNotesLocked = true end

	cfg.features = cfg.features or {}
	if type(cfg.features.trinkets) ~= "boolean" then
		cfg.features.trinkets = true
	end
	if type(cfg.features.debuffs) ~= "boolean" then
		cfg.features.debuffs = true
	end
	if type(cfg.features.consumables) ~= "boolean" then
		cfg.features.consumables = true
	end
	if type(cfg.features.raidNotes) ~= "boolean" then cfg.features.raidNotes = true end

	cfg.debuffs = cfg.debuffs or {}
	for _, key in ipairs(DEBUFF_KEYS) do
		if type(cfg.debuffs[key]) ~= "boolean" then
			cfg.debuffs[key] = true
		end
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

	if type(cfg.trinketDropdownBlacklist) ~= "table" then
		cfg.trinketDropdownBlacklist = {}
	end
	if type(cfg.trinketSuggestionBlacklist) ~= "table" then
		cfg.trinketSuggestionBlacklist = {}
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

function C.IsFeatureEnabled(name)
	local cfg = C.Get()
	return cfg.features and cfg.features[name] ~= false or false
end

function C.SetFeatureEnabled(name, value)
	local cfg = EnsureDB()
	cfg.features = cfg.features or {}
	cfg.features[name] = value and true or false
	C.Normalize()
	C.RefreshChanged()
	return cfg.features[name]
end

-- The config modal's own text always uses a fixed Arial face, independent of
-- the feature font chosen in the General tab (that font applies only to feature
-- UI such as the trinket menu, via T.SetDisplayConfig). Each entry stores the
-- FontString plus its captured point size/flags so only the face is replaced.
local MODAL_FONT = "Fonts\\ARIALN.TTF"

C.fontStrings = C.fontStrings or {}

function C.RegisterFontString(fs, size, flags)
	if not fs or not fs.SetFont then return end
	if not size then
		local _, capturedSize, capturedFlags = fs:GetFont()
		size = capturedSize
		flags = flags or capturedFlags
	end
	C.fontStrings[#C.fontStrings + 1] = { fs = fs, size = size, flags = flags }
	if size then
		fs:SetFont(MODAL_FONT, size, flags)
	end
	return fs
end

function C.ApplyModalFont()
	for _, entry in ipairs(C.fontStrings) do
		if entry.fs and entry.fs.SetFont and entry.size then
			entry.fs:SetFont(MODAL_FONT, entry.size, entry.flags)
		end
	end
end

function C.SetRefreshCallback(callback)
	C.refreshCallback = callback
end

function C.RefreshChanged()
	local cfg = C.Get()
	if C.modal then
		for _, key in ipairs({ "locked", "debuffLocked", "consumableLocked", "raidNotesLocked" }) do
			local check = C.modal[key .. "Check"]
			if check then check:SetChecked(cfg[key]) end
		end
	end
	if C.refreshCallback then
		C.refreshCallback(cfg)
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
	C.RegisterFontString(label)
	return label
end

local function CreateSectionHeader(parent, text, x, y)
	local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	label:SetText(text)
	C.RegisterFontString(label)
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

	if slider.Text then slider.Text:SetText("") C.RegisterFontString(slider.Text) end
	if slider.Low then slider.Low:SetText(tostring(minValue)) C.RegisterFontString(slider.Low) end
	if slider.High then slider.High:SetText(tostring(maxValue)) C.RegisterFontString(slider.High) end

	slider.track = slider:CreateTexture(nil, "BACKGROUND")
	slider.track:SetPoint("LEFT", slider, "LEFT", 4, 0)
	slider.track:SetPoint("RIGHT", slider, "RIGHT", -4, 0)
	slider.track:SetHeight(4)
	slider.track:SetColorTexture(0.55, 0.55, 0.55, 0.85)

	slider.valueTooltip = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	slider.valueTooltip:SetPoint("BOTTOM", slider, "TOP", 0, 5)
	slider.valueTooltip:SetTextColor(1, 0.82, 0, 1)
	C.RegisterFontString(slider.valueTooltip)

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
	if frame.debuffLockedCheck then frame.debuffLockedCheck:SetChecked(cfg.debuffLocked) end
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

	if frame.trinketsFeatureCheck then
		frame.trinketsFeatureCheck:SetChecked(C.IsFeatureEnabled("trinkets"))
	end

	if frame.debuffIconSizeSlider then frame.debuffIconSizeSlider:SetValue(cfg.debuffIconSize) end
	if frame.debuffFontSizeSlider then frame.debuffFontSizeSlider:SetValue(cfg.debuffFontSize) end
	if frame.debuffPerLineSlider then frame.debuffPerLineSlider:SetValue(cfg.debuffPerLine) end

	if frame.debuffDirectionDropdown and frame.debuffDirectionDropdown.Refresh then
		frame.debuffDirectionDropdown:Refresh(cfg)
	end

	if frame.debuffsFeatureCheck then
		frame.debuffsFeatureCheck:SetChecked(C.IsFeatureEnabled("debuffs"))
	end
	if frame.consumableIconSizeSlider then frame.consumableIconSizeSlider:SetValue(cfg.consumableIconSize) end
	if frame.consumableFontSizeSlider then frame.consumableFontSizeSlider:SetValue(cfg.consumableFontSize) end
	if frame.consumableLockedCheck then frame.consumableLockedCheck:SetChecked(cfg.consumableLocked) end
	if frame.consumableRaidOnlyCheck then frame.consumableRaidOnlyCheck:SetChecked(cfg.consumableRaidOnly) end
	if frame.consumablesFeatureCheck then
		frame.consumablesFeatureCheck:SetChecked(C.IsFeatureEnabled("consumables"))
	end
	if frame.raidNotesFeatureCheck then frame.raidNotesFeatureCheck:SetChecked(C.IsFeatureEnabled("raidNotes")) end
	if frame.raidNotesFontSizeSlider then frame.raidNotesFontSizeSlider:SetValue(cfg.raidNotesFontSize) end
	if frame.raidNotesPaddingSlider then frame.raidNotesPaddingSlider:SetValue(cfg.raidNotesPadding) end
	if frame.raidNotesGapSlider then frame.raidNotesGapSlider:SetValue(cfg.raidNotesGap) end
	if frame.raidNotesBorderWidthSlider then frame.raidNotesBorderWidthSlider:SetValue(cfg.raidNotesBorderWidth) end
	if frame.raidNotesStrataDropdown then frame.raidNotesStrataDropdown:Refresh(cfg) end
	if frame.raidNotesLockedCheck then frame.raidNotesLockedCheck:SetChecked(cfg.raidNotesLocked) end
	if frame.raidNotesBackgroundColorButton then frame.raidNotesBackgroundColorButton:Refresh() end
	if frame.raidNotesBorderColorButton then frame.raidNotesBorderColorButton:Refresh() end

	if frame.debuffToggles then
		for key, check in pairs(frame.debuffToggles) do
			check:SetChecked(cfg.debuffs[key] and true or false)
		end
	end

	if frame.RefreshTrinketBlacklistLists then
		frame.RefreshTrinketBlacklistLists()
	end

	if frame.UpdateTabVisibility then
		frame.UpdateTabVisibility()
	end

	C.ApplyModalFont()
end

function C.GetTrinketBlacklist(kind)
	local cfg = C.Get()
	if kind == "dropdown" then return cfg.trinketDropdownBlacklist end
	if kind ~= "suggestion" then return {} end
	KravaCooldownTrackerCharacterDB = KravaCooldownTrackerCharacterDB or {}
	local db = KravaCooldownTrackerCharacterDB
	if type(db.trinketSuggestionBlacklist) ~= "table" then
		-- Keep the legacy account list as a migration seed, never a shared table.
		db.trinketSuggestionBlacklist = {}
		for itemId, disabled in pairs(cfg.trinketSuggestionBlacklist) do
			db.trinketSuggestionBlacklist[itemId] = disabled
		end
	end
	return db.trinketSuggestionBlacklist
end

function C.SetTrinketBlacklisted(kind, itemId, disabled)
	itemId = tonumber(itemId)
	if not itemId then return end
	local blacklist = C.GetTrinketBlacklist(kind)
	blacklist[itemId] = disabled and true or nil
	C.RefreshChanged()
	if C.modal and C.modal.RefreshTrinketBlacklistLists then
		C.modal.RefreshTrinketBlacklistLists()
	end
end

function C.RefreshTrinketBlacklistLists()
	if C.modal and C.modal:IsShown() and C.modal.RefreshTrinketBlacklistLists then
		C.modal.RefreshTrinketBlacklistLists()
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
	C.RegisterFontString(dropdown.text)

	dropdown.arrow = dropdown:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	dropdown.arrow:SetPoint("RIGHT", dropdown, "RIGHT", -8, 0)
	dropdown.arrow:SetText("v")
	C.RegisterFontString(dropdown.arrow)

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
				C.RegisterFontString(row.text)
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
	C.RegisterFontString(dropdown.text)

	dropdown.arrow = dropdown:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	dropdown.arrow:SetPoint("RIGHT", dropdown, "RIGHT", -8, 0)
	dropdown.arrow:SetText("v")
	C.RegisterFontString(dropdown.arrow)

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
		C.RegisterFontString(row.text)
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

local function CreateDebuffDirectionDropdown(parent, x, y)
	local backdropTemplate = BackdropTemplateMixin and "BackdropTemplate" or nil
	local dropdown = CreateFrame("Button", "KravaCooldownTrackerDebuffDirectionDropdown", parent, backdropTemplate)
	dropdown:SetSize(84, 22)
	dropdown:SetPoint("TOPRIGHT", parent, "TOPRIGHT", x, y)
	StyleDropdownButton(dropdown)

	dropdown.text = dropdown:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	dropdown.text:SetPoint("LEFT", dropdown, "LEFT", 8, 0)
	dropdown.text:SetPoint("RIGHT", dropdown, "RIGHT", -24, 0)
	dropdown.text:SetJustifyH("LEFT")
	C.RegisterFontString(dropdown.text)

	dropdown.arrow = dropdown:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	dropdown.arrow:SetPoint("RIGHT", dropdown, "RIGHT", -8, 0)
	dropdown.arrow:SetText("v")
	C.RegisterFontString(dropdown.arrow)

	local options = {
		{ label = "Horizontal", value = "horizontal" },
		{ label = "Vertical", value = "vertical" },
	}

	local menu = CreateFrame("Frame", "KravaCooldownTrackerDebuffDirectionMenu", dropdown, backdropTemplate)
	menu:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 0, -2)
	menu:SetSize(84, (#options * DROPDOWN_ROW_HEIGHT) + 4)
	menu:SetFrameStrata("DIALOG")
	menu:SetFrameLevel(dropdown:GetFrameLevel() + 10)
	menu.rows = {}
	StylePanel(menu)
	menu:Hide()
	dropdown.menu = menu

	local function SelectDirection(value)
		SetAndRefresh("debuffDirection", value)
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
		C.RegisterFontString(row.text)
		row:SetScript("OnClick", function(self)
			SelectDirection(self.option.value)
		end)
		menu.rows[index] = row
	end

	function dropdown:Refresh(cfg)
		cfg = cfg or C.Get()
		local label = cfg.debuffDirection == "vertical" and "Vertical" or "Horizontal"
		self.text:SetText(label)
		for _, row in ipairs(menu.rows) do
			if row.option.value == cfg.debuffDirection then
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

local function CreateRaidNotesStrataDropdown(parent, x, y)
	local backdropTemplate = BackdropTemplateMixin and "BackdropTemplate" or nil
	local dropdown = CreateFrame("Button", "KravaCooldownTrackerRaidNotesStrataDropdown", parent, backdropTemplate)
	dropdown:SetSize(172, 22)
	dropdown:SetPoint("TOPRIGHT", parent, "TOPRIGHT", x, y)
	StyleDropdownButton(dropdown)

	dropdown.text = dropdown:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	dropdown.text:SetPoint("LEFT", dropdown, "LEFT", 8, 0)
	dropdown.text:SetPoint("RIGHT", dropdown, "RIGHT", -24, 0)
	dropdown.text:SetJustifyH("LEFT")
	C.RegisterFontString(dropdown.text)

	dropdown.arrow = dropdown:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	dropdown.arrow:SetPoint("RIGHT", dropdown, "RIGHT", -8, 0)
	dropdown.arrow:SetText("v")
	C.RegisterFontString(dropdown.arrow)

	local options = {}
	for _, strata in ipairs(RAID_NOTES_STRATA) do
		options[#options + 1] = { label = strata, value = strata }
	end

	local menu = CreateFrame("Frame", "KravaCooldownTrackerRaidNotesStrataMenu", dropdown, backdropTemplate)
	menu:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 0, -2)
	menu:SetSize(172, (#options * DROPDOWN_ROW_HEIGHT) + 4)
	menu:SetFrameStrata("DIALOG")
	menu:SetFrameLevel(dropdown:GetFrameLevel() + 10)
	menu.rows = {}
	StylePanel(menu)
	menu:Hide()
	dropdown.menu = menu

	local function SelectStrata(value)
		SetAndRefresh("raidNotesStrata", value)
		dropdown:Refresh(C.Get())
		menu:Hide()
	end

	for index, option in ipairs(options) do
		local row = CreateFrame("Button", nil, menu)
		row:SetSize(168, DROPDOWN_ROW_HEIGHT)
		row:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -2 - ((index - 1) * DROPDOWN_ROW_HEIGHT))
		row.option = option
		row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		row.text:SetPoint("LEFT", row, "LEFT", 7, 0)
		row.text:SetPoint("RIGHT", row, "RIGHT", -7, 0)
		row.text:SetJustifyH("LEFT")
		row.text:SetText(option.label)
		C.RegisterFontString(row.text)
		row:SetScript("OnClick", function(self)
			SelectStrata(self.option.value)
		end)
		menu.rows[index] = row
	end

	function dropdown:Refresh(cfg)
		cfg = cfg or C.Get()
		local label = cfg.raidNotesStrata
		self.text:SetText(label)
		for _, row in ipairs(menu.rows) do
			if row.option.value == cfg.raidNotesStrata then
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
	C.RegisterFontString(dropdown.text)

	dropdown.arrow = dropdown:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	dropdown.arrow:SetPoint("RIGHT", dropdown, "RIGHT", -8, 0)
	dropdown.arrow:SetText("v")
	C.RegisterFontString(dropdown.arrow)

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
				C.RegisterFontString(row.text)

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

local function CreateTabButton(frame, text, x)
	local backdropTemplate = BackdropTemplateMixin and "BackdropTemplate" or nil
	local button = CreateFrame("Button", nil, frame, backdropTemplate)
	button:SetSize(84, 22)
	button:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -34)
	StyleDropdownButton(button)

	button.text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	button.text:SetPoint("CENTER", button, "CENTER", 0, 0)
	button.text:SetText(text)
	C.RegisterFontString(button.text)

	function button:SetActive(active)
		if active then
			self.text:SetTextColor(1, 0.82, 0, 1)
			if self.SetBackdropBorderColor then self:SetBackdropBorderColor(1, 0.82, 0, 0.9) end
		else
			self.text:SetTextColor(1, 1, 1, 1)
			if self.SetBackdropBorderColor then self:SetBackdropBorderColor(0.36, 0.36, 0.36, 0.9) end
		end
	end

	return button
end

local function CreateFeatureCheckbox(parent, featureName, x, y, onToggle)
	local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	check:SetSize(24, 24)
	check:SetPoint("TOPRIGHT", parent, "TOPRIGHT", x, y)
	check:SetScript("OnClick", function(self)
		C.SetFeatureEnabled(featureName, self:GetChecked() and true or false)
		if onToggle then onToggle() end
	end)
	return check
end

local function CreateColorButton(parent, key, x, y)
	local button = CreateFrame("Button", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	button:SetSize(42, 20)
	button:SetPoint("TOPRIGHT", parent, "TOPRIGHT", x, y)
	button.swatch = button:CreateTexture(nil, "ARTWORK")
	button.swatch:SetAllPoints()
	button:SetScript("OnClick", function()
		local color = C.Get()[key]
		local function apply()
			local r, g, b = ColorPickerFrame:GetColorRGB()
			local a = ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha() or color[4] or 1
			C.Set(key, { r, g, b, a }); C.RefreshChanged()
			button.swatch:SetColorTexture(r, g, b, a)
		end
		if ColorPickerFrame.SetupColorPickerAndShow then
			ColorPickerFrame:SetupColorPickerAndShow({ r=color[1], g=color[2], b=color[3], opacity=color[4] or 1, hasOpacity=true, swatchFunc=apply, opacityFunc=apply })
		else
			ColorPickerFrame:SetColorRGB(color[1], color[2], color[3]); ColorPickerFrame.func = apply; ColorPickerFrame:Show()
		end
	end)
	function button:Refresh() local c = C.Get()[key]; self.swatch:SetColorTexture(c[1], c[2], c[3], c[4] or 1) end
	button:Refresh()
	return button
end

-- Per-debuff toggle writes a nested cfg.debuffs[key] (not a flat cfg[key]), so it
-- cannot reuse CreateSettingCheckbox/CreateFeatureCheckbox.
local function CreateDebuffToggleCheckbox(parent, debuffKey, x, y)
	local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	check:SetSize(24, 24)
	check:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	check:SetScript("OnClick", function(self)
		local cfg = C.Get()
		cfg.debuffs[debuffKey] = self:GetChecked() and true or false
		C.Set("debuffs", cfg.debuffs)
		C.RefreshChanged()
	end)
	return check
end

local function CreateTrinketBlacklistList(parent, kind, titleText, y)
	local list = CreateFrame("Frame", nil, parent)
	list:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, y)
	list:SetSize(308, 88)
	list:EnableMouse(true)
	list:EnableMouseWheel(true)
	list.buttons = {}
	list.page = 1

	list.title = CreateSectionHeader(list, titleText, 0, 0)
	list.pageText = list:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	list.pageText:SetPoint("TOPRIGHT", list, "TOPRIGHT", 0, -2)
	C.RegisterFontString(list.pageText)

	local function GetButton(index)
		local button = list.buttons[index]
		if button then return button end
		button = CreateFrame("Button", nil, list)
		button:SetSize(22, 22)
		button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		button.icon = button:CreateTexture(nil, "ARTWORK")
		button.icon:SetAllPoints(button)
		button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		button.highlight = button:CreateTexture(nil, "HIGHLIGHT")
		button.highlight:SetAllPoints(button)
		button.highlight:SetColorTexture(1, 1, 1, 0.18)
		button:SetScript("OnEnter", function(self)
			if not self.__itemId or not GameTooltip then return end
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetHyperlink(self.__link or ("item:" .. self.__itemId))
			GameTooltip:AddLine("Click: toggle", 0.85, 0.85, 0.85)
			GameTooltip:Show()
		end)
		button:SetScript("OnLeave", function()
			if GameTooltip then GameTooltip:Hide() end
		end)
		button:SetScript("OnClick", function(self)
			if not self.__itemId then return end
			local logic = KravaCooldownTracker_TrinketLogic
			local disabled = logic and logic.IsTrinketBlacklisted and logic.IsTrinketBlacklisted(kind, self.__itemId)
			C.SetTrinketBlacklisted(kind, self.__itemId, not disabled)
		end)
		list.buttons[index] = button
		return button
	end

	function list:Refresh()
		local logic = KravaCooldownTracker_TrinketLogic
		local items = logic and logic.GetInventoryTrinkets and logic.GetInventoryTrinkets() or {}
		local perPage = 36
		local pages = math.max(1, math.ceil(#items / perPage))
		self.page = math.min(math.max(1, self.page or 1), pages)
		self.pageText:SetText(pages > 1 and (self.page .. "/" .. pages .. "  (wheel)") or "")
		local visibleCount = math.min(perPage, math.max(0, #items - ((self.page - 1) * perPage)))
		local visibleRows = math.max(1, math.ceil(visibleCount / 12))
		self:SetHeight(22 + visibleRows * 24)

		for _, button in ipairs(self.buttons) do button:Hide() end
		local first = (self.page - 1) * perPage + 1
		for displayIndex = 1, perPage do
			local item = items[first + displayIndex - 1]
			if not item then break end
			local button = GetButton(displayIndex)
			local column = (displayIndex - 1) % 12
			local row = math.floor((displayIndex - 1) / 12)
			button:ClearAllPoints()
			button:SetPoint("TOPLEFT", self, "TOPLEFT", column * 24, -22 - row * 24)
			button.icon:SetTexture(item.icon)
			local disabled = logic.IsTrinketBlacklisted(kind, item.itemId)
			button.icon:SetDesaturated(disabled)
			button.icon:SetVertexColor(disabled and 0.35 or 1, disabled and 0.35 or 1, disabled and 0.35 or 1, 1)
			button.__itemId = item.itemId
			button.__link = item.link
			button:Show()
		end
	end

	list:SetScript("OnMouseWheel", function(self, delta)
		self.page = math.max(1, (self.page or 1) - delta)
		self:Refresh()
	end)
	return list
end

function C.CreateModal()
	if C.modal then return C.modal end
	if not UIParent then return nil end

	local backdropTemplate = BackdropTemplateMixin and "BackdropTemplate" or nil
	local frame = CreateFrame("Frame", "KravaCooldownTrackerConfigModal", UIParent, backdropTemplate)
	UISpecialFrames = UISpecialFrames or {}
	table.insert(UISpecialFrames, "KravaCooldownTrackerConfigModal")
	frame:SetSize(460, 650)
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
	C.RegisterFontString(title)

	local close = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	close:SetSize(54, 20)
	close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -8)
	close:SetText("Close")
	close:SetScript("OnClick", function() frame:Hide() end)
	if close.GetFontString and close:GetFontString() then
		C.RegisterFontString(close:GetFontString())
	end

	-- Tabs
	frame.generalTab = CreateTabButton(frame, "General", 10)
	frame.trinketsTab = CreateTabButton(frame, "Trinkets", 98)
	frame.debuffsTab = CreateTabButton(frame, "Debuffs", 186)
	frame.consumablesTab = CreateTabButton(frame, "Consumables", 274)
	frame.raidNotesTab = CreateTabButton(frame, "Raid Notes", 362)

	-- Panes (only one shown at a time)
	frame.generalPane = CreateFrame("Frame", nil, frame)
	frame.generalPane:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -60)
	frame.generalPane:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)

	frame.trinketsPane = CreateFrame("Frame", nil, frame)
	frame.trinketsPane:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -60)
	frame.trinketsPane:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)

	frame.debuffsPane = CreateFrame("Frame", nil, frame)
	frame.debuffsPane:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -60)
	frame.debuffsPane:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)

	frame.consumablesPane = CreateFrame("Frame", nil, frame)
	frame.consumablesPane:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -60)
	frame.consumablesPane:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
	frame.raidNotesPane = CreateFrame("Frame", nil, frame)
	frame.raidNotesPane:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -60)
	frame.raidNotesPane:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)

	local function SetActivePane(name)
		if name == "trinkets" and C.IsFeatureEnabled("trinkets") then
			frame.activePane = "trinkets"
		elseif name == "debuffs" and C.IsFeatureEnabled("debuffs") then
			frame.activePane = "debuffs"
		elseif name == "consumables" and C.IsFeatureEnabled("consumables") then
			frame.activePane = "consumables"
		elseif name == "raidNotes" and C.IsFeatureEnabled("raidNotes") then
			frame.activePane = "raidNotes"
		else
			frame.activePane = "general"
		end
		if frame.activePane == "trinkets" then
			frame.generalPane:Hide()
			frame.debuffsPane:Hide()
			frame.consumablesPane:Hide()
			frame.raidNotesPane:Hide()
			frame.trinketsPane:Show()
			frame.generalTab:SetActive(false)
			frame.trinketsTab:SetActive(true)
			frame.debuffsTab:SetActive(false)
			frame.consumablesTab:SetActive(false)
			frame.raidNotesTab:SetActive(false)
		elseif frame.activePane == "debuffs" then
			frame.generalPane:Hide()
			frame.trinketsPane:Hide()
			frame.consumablesPane:Hide()
			frame.raidNotesPane:Hide()
			frame.debuffsPane:Show()
			frame.generalTab:SetActive(false)
			frame.trinketsTab:SetActive(false)
			frame.debuffsTab:SetActive(true)
			frame.consumablesTab:SetActive(false)
			frame.raidNotesTab:SetActive(false)
		elseif frame.activePane == "consumables" then
			frame.generalPane:Hide()
			frame.trinketsPane:Hide()
			frame.debuffsPane:Hide()
			frame.consumablesPane:Show()
			frame.raidNotesPane:Hide()
			frame.generalTab:SetActive(false)
			frame.trinketsTab:SetActive(false)
			frame.debuffsTab:SetActive(false)
			frame.consumablesTab:SetActive(true)
			frame.raidNotesTab:SetActive(false)
		elseif frame.activePane == "raidNotes" then
			frame.generalPane:Hide(); frame.trinketsPane:Hide(); frame.debuffsPane:Hide(); frame.consumablesPane:Hide()
			frame.raidNotesPane:Show()
			frame.generalTab:SetActive(false); frame.trinketsTab:SetActive(false); frame.debuffsTab:SetActive(false); frame.consumablesTab:SetActive(false); frame.raidNotesTab:SetActive(true)
		else
			frame.trinketsPane:Hide()
			frame.debuffsPane:Hide()
			frame.consumablesPane:Hide()
			frame.raidNotesPane:Hide()
			frame.generalPane:Show()
			frame.generalTab:SetActive(true)
			frame.trinketsTab:SetActive(false)
			frame.debuffsTab:SetActive(false)
			frame.consumablesTab:SetActive(false)
			frame.raidNotesTab:SetActive(false)
		end
	end
	frame.SetActivePane = SetActivePane

	frame.generalTab:SetScript("OnClick", function() SetActivePane("general") end)
	frame.trinketsTab:SetScript("OnClick", function() SetActivePane("trinkets") end)
	frame.debuffsTab:SetScript("OnClick", function() SetActivePane("debuffs") end)
	frame.consumablesTab:SetScript("OnClick", function() SetActivePane("consumables") end)
	frame.raidNotesTab:SetScript("OnClick", function() SetActivePane("raidNotes") end)

	local function UpdateTabVisibility()
		if C.IsFeatureEnabled("trinkets") then
			frame.trinketsTab:Show()
		else
			frame.trinketsTab:Hide()
			if frame.activePane == "trinkets" then
				SetActivePane("general")
			end
		end
		if C.IsFeatureEnabled("debuffs") then
			frame.debuffsTab:Show()
		else
			frame.debuffsTab:Hide()
			if frame.activePane == "debuffs" then
				SetActivePane("general")
			end
		end
		if C.IsFeatureEnabled("consumables") then
			frame.consumablesTab:Show()
		else
			frame.consumablesTab:Hide()
			if frame.activePane == "consumables" then SetActivePane("general") end
		end
		if C.IsFeatureEnabled("raidNotes") then frame.raidNotesTab:Show() else frame.raidNotesTab:Hide(); if frame.activePane == "raidNotes" then SetActivePane("general") end end
	end
	frame.UpdateTabVisibility = UpdateTabVisibility

	-- General pane
	local gp = frame.generalPane
	CreateLabel(gp, "Font", 16, -12)
	frame.fontDropdown = CreateFontDropdown(gp, -18, -6)

	CreateSectionHeader(gp, "Features", 16, -78)
	CreateLabel(gp, "Trinkets", 28, -104)
	frame.trinketsFeatureCheck = CreateFeatureCheckbox(gp, "trinkets", -18, -98, function()
		UpdateTabVisibility()
	end)
	CreateLabel(gp, "Debuffs", 28, -130)
	frame.debuffsFeatureCheck = CreateFeatureCheckbox(gp, "debuffs", -18, -124, function()
		UpdateTabVisibility()
	end)
	CreateLabel(gp, "Consumables", 28, -156)
	frame.consumablesFeatureCheck = CreateFeatureCheckbox(gp, "consumables", -18, -150, function()
		UpdateTabVisibility()
	end)
	CreateLabel(gp, "MRT Raid Notes", 28, -182)
	frame.raidNotesFeatureCheck = CreateFeatureCheckbox(gp, "raidNotes", -18, -176)

	CreateSectionHeader(gp, "Export / Import", 16, -226)
	CreateLabel(gp, "Includes settings, positions, and this character's exclusions.", 16, -252)
	local transferBorder = CreateFrame("Frame", nil, gp, backdropTemplate)
	transferBorder:SetPoint("TOPLEFT", gp, "TOPLEFT", 16, -276)
	transferBorder:SetSize(420, 158)
	StylePanel(transferBorder)
	local transferScroll = CreateFrame("ScrollFrame", nil, transferBorder, "UIPanelScrollFrameTemplate")
	transferScroll:SetPoint("TOPLEFT", gp, "TOPLEFT", 20, -280)
	transferScroll:SetSize(394, 150)
	local transferText = CreateFrame("EditBox", nil, transferScroll)
	transferText:SetMultiLine(true)
	transferText:SetAutoFocus(false)
	transferText:SetFontObject(ChatFontNormal)
	transferText:SetWidth(390)
	transferText:SetHeight(150)
	transferText:SetMaxLetters(100000)
	transferText:SetScript("OnEscapePressed", function(self) self:ClearFocus(); frame:Hide() end)
	transferScroll:SetScrollChild(transferText)
	local transferStatus = CreateLabel(gp, "Import replaces settings. Paste an export, then click Import.", 16, -478)
	local function TransferButton(label, x, onClick)
		local button = CreateFrame("Button", nil, gp, "UIPanelButtonTemplate")
		button:SetSize(110, 24)
		button:SetPoint("TOPLEFT", gp, "TOPLEFT", x, -444)
		button:SetText(label)
		button:SetScript("OnClick", onClick)
		return button
	end
	TransferButton("Export", 16, function()
		transferText:SetText(C.ExportConfig())
		transferText:SetFocus()
		transferText:HighlightText()
		transferStatus:SetText("Press Ctrl+C to copy your config.")
	end)
	TransferButton("Import", 136, function()
		local ok, message = C.ImportConfig(transferText:GetText())
		transferStatus:SetText(message)
		if ok then transferText:ClearFocus(); RefreshModalValues(frame) end
	end)

	-- Trinkets pane
	local tp = frame.trinketsPane
	CreateLabel(tp, "Locked", 16, -12)
	frame.lockedCheck = CreateSettingCheckbox(tp, "locked", -18, -6)
	CreateLabel(tp, "Font size", 16, -42)
	frame.fontSizeSlider = CreateRangeSlider(tp, "fontSize", -18, -44, 142, MIN_FONT_SIZE, MAX_FONT_SIZE, "px")

	CreateSectionHeader(tp, "Main Icon", 16, -78)

	CreateLabel(tp, "Icon size", 16, -104)
	frame.mainIconSizeSlider = CreateRangeSlider(tp, "mainIconSize", -18, -106, 142, MIN_MAIN_ICON_SIZE, MAX_MAIN_ICON_SIZE, "px")

	CreateLabel(tp, "Queue icon size", 16, -140)
	frame.queueIconPercentSlider = CreateRangeSlider(tp, "queueIconPercent", -18, -142, 142, MIN_QUEUE_ICON_PERCENT, MAX_QUEUE_ICON_PERCENT, "%")

	CreateLabel(tp, "Disable trinket usage on click", 16, -180)
	frame.disableTrinketUsageCheck = CreateSettingCheckbox(tp, "disableTrinketUsageOnClick", -18, -174)

	CreateSectionHeader(tp, "Suggestions", 16, -214)

	CreateLabel(tp, "Position", 16, -240)
	frame.suggestionPositionDropdown = CreateSuggestionPositionDropdown(tp, -18, -234)

	CreateLabel(tp, "Icon size", 16, -270)
	frame.suggestionIconSizeSlider = CreateRangeSlider(tp, "suggestionIconSize", -18, -272, 142, MIN_SUGGESTION_ICON_SIZE, MAX_SUGGESTION_ICON_SIZE, "px")

	CreateLabel(tp, "Available sound", 16, -306)
	frame.suggestionAvailableSoundDropdown = CreateSuggestionSoundDropdown(tp, -18, -300)

	CreateLabel(tp, "Disable suggestions for upper trinket", 16, -346)
	frame.disableUpperTrinketSuggestionsCheck = CreateSettingCheckbox(tp, "disableUpperTrinketSuggestions", -18, -340)

	CreateLabel(tp, "Disable suggestions for lower trinket", 16, -372)
	frame.disableLowerTrinketSuggestionsCheck = CreateSettingCheckbox(tp, "disableLowerTrinketSuggestions", -18, -366)

	frame.dropdownBlacklistList = CreateTrinketBlacklistList(tp, "dropdown", "Dropdown trinkets", -400)
	frame.suggestionBlacklistList = CreateTrinketBlacklistList(tp, "suggestion", "Suggestion trinkets", -496)
	frame.RefreshTrinketBlacklistLists = function()
		frame.dropdownBlacklistList:Refresh()
		frame.suggestionBlacklistList:ClearAllPoints()
		frame.suggestionBlacklistList:SetPoint("TOPLEFT", frame.dropdownBlacklistList, "BOTTOMLEFT", 0, -8)
		frame.suggestionBlacklistList:Refresh()
	end

	-- Debuffs pane
	local dp = frame.debuffsPane
	CreateSectionHeader(dp, "Layout", 16, -12)

	CreateLabel(dp, "Icon size", 16, -38)
	frame.debuffIconSizeSlider = CreateRangeSlider(dp, "debuffIconSize", -18, -40, 142, MIN_DEBUFF_ICON_SIZE, MAX_DEBUFF_ICON_SIZE, "px")

	CreateLabel(dp, "Font size", 16, -68)
	frame.debuffFontSizeSlider = CreateRangeSlider(dp, "debuffFontSize", -18, -70, 142, MIN_DEBUFF_FONT_SIZE, MAX_DEBUFF_FONT_SIZE, "px")

	CreateLabel(dp, "Per line", 16, -98)
	frame.debuffPerLineSlider = CreateRangeSlider(dp, "debuffPerLine", -18, -100, 142, MIN_DEBUFF_PER_LINE, MAX_DEBUFF_PER_LINE, "")

	CreateLabel(dp, "Direction", 16, -128)
	frame.debuffDirectionDropdown = CreateDebuffDirectionDropdown(dp, -18, -122)

	CreateSectionHeader(dp, "Debuffs", 16, -160)

	frame.debuffToggles = frame.debuffToggles or {}
	local debuffList = KravaCooldownTracker_DebuffLogic and KravaCooldownTracker_DebuffLogic.DEBUFFS
	if debuffList then
		for index, entry in ipairs(debuffList) do
			local column = index <= 6 and 0 or 1
			local rowInColumn = (index - 1) % 6
			local cbx = 16 + column * 150
			local cby = -184 - rowInColumn * 26
			local check = CreateDebuffToggleCheckbox(dp, entry.key, cbx, cby)
			CreateLabel(dp, entry.displayName, cbx + 24, cby - 6)
			frame.debuffToggles[entry.key] = check
		end
	end

	CreateLabel(dp, "Locked", 16, -358)
	frame.debuffLockedCheck = CreateSettingCheckbox(dp, "debuffLocked", -18, -352)

	-- Consumables pane
	local cp = frame.consumablesPane
	CreateSectionHeader(cp, "Layout", 16, -12)
	CreateLabel(cp, "Icon size", 16, -38)
	frame.consumableIconSizeSlider = CreateRangeSlider(cp, "consumableIconSize", -18, -40, 142, MIN_CONSUMABLE_ICON_SIZE, MAX_CONSUMABLE_ICON_SIZE, "px")
	CreateLabel(cp, "Font size", 16, -74)
	frame.consumableFontSizeSlider = CreateRangeSlider(cp, "consumableFontSize", -18, -76, 142, MIN_CONSUMABLE_FONT_SIZE, MAX_CONSUMABLE_FONT_SIZE, "px")
	CreateLabel(cp, "Locked", 16, -118)
	frame.consumableLockedCheck = CreateSettingCheckbox(cp, "consumableLocked", -18, -112)
	CreateLabel(cp, "Show only in raid", 16, -148)
	frame.consumableRaidOnlyCheck = CreateSettingCheckbox(cp, "consumableRaidOnly", -18, -142)
	frame.consumableSpecLabel = CreateLabel(cp, "Spec detected as: Unknown", 16, -184)
	local function RefreshDetectedSpec()
		local logic = KravaCooldownTracker_ConsumableLogic
		local detected = logic and logic.GetDetectedSpecLabel and logic.GetDetectedSpecLabel() or "Unknown"
		frame.consumableSpecLabel:SetText("Spec detected as: " .. detected)
	end
	cp:SetScript("OnShow", RefreshDetectedSpec)
	for _, event in ipairs({ "PLAYER_TALENT_UPDATE", "ACTIVE_TALENT_GROUP_CHANGED" }) do
		cp:RegisterEvent(event)
	end
	cp:SetScript("OnEvent", function(self)
		if self:IsShown() then RefreshDetectedSpec() end
	end)

	-- MRT Raid Notes pane
	local rp = frame.raidNotesPane
	CreateSectionHeader(rp, "Buttons", 16, -12)
	CreateLabel(rp, "Font size", 16, -38); frame.raidNotesFontSizeSlider = CreateRangeSlider(rp, "raidNotesFontSize", -18, -40, 142, 8, 32, "px")
	CreateLabel(rp, "Inner padding", 16, -74); frame.raidNotesPaddingSlider = CreateRangeSlider(rp, "raidNotesPadding", -18, -76, 142, 0, 20, "px")
	CreateLabel(rp, "Button gap", 16, -110); frame.raidNotesGapSlider = CreateRangeSlider(rp, "raidNotesGap", -18, -112, 142, 0, 20, "px")
	CreateLabel(rp, "Border width", 16, -146); frame.raidNotesBorderWidthSlider = CreateRangeSlider(rp, "raidNotesBorderWidth", -18, -148, 142, 0, 8, "px")
	CreateLabel(rp, "Background color", 16, -190); frame.raidNotesBackgroundColorButton = CreateColorButton(rp, "raidNotesBackgroundColor", -18, -184)
	CreateLabel(rp, "Border color", 16, -222); frame.raidNotesBorderColorButton = CreateColorButton(rp, "raidNotesBorderColor", -18, -216)
	CreateLabel(rp, "Locked", 16, -258); frame.raidNotesLockedCheck = CreateSettingCheckbox(rp, "raidNotesLocked", -18, -252)
	CreateLabel(rp, "Frame strata", 16, -294); frame.raidNotesStrataDropdown = CreateRaidNotesStrataDropdown(rp, -18, -288)

	SetActivePane("general")
	UpdateTabVisibility()
	C.ApplyModalFont()

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
