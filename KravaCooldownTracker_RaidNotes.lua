-- Clickable MRT saved-note drafts.

KravaCooldownTracker_RaidNotes = KravaCooldownTracker_RaidNotes or {}
local R = KravaCooldownTracker_RaidNotes
local C = KravaCooldownTracker_Config

local CONTENT_WIDTH = 120
local frame, dragHandle
local buttons = {}
local lastSignature

local function getConfig()
	return C and C.Get and C.Get() or { raidNotesLocked = true }
end

local function isEnabled()
	return not C or not C.IsFeatureEnabled or C.IsFeatureEnabled("raidNotes")
end

local function getNoteName(index)
	local names = VMRT and VMRT.Note and VMRT.Note.BlackNames
	local name = names and names[index]
	if name and name ~= "" then return name:gsub("%*+$", ""):upper() end
	return ("Note " .. index):upper()
end

local function getSortedNotes()
	local notes = {}
	local drafts = VMRT and VMRT.Note and VMRT.Note.Black
	if drafts then
		for index, text in ipairs(drafts) do
			if text then notes[#notes + 1] = { index = index, name = getNoteName(index) } end
		end
	end
	table.sort(notes, function(a, b)
		local an, bn = a.name:lower(), b.name:lower()
		return an == bn and a.index < b.index or an < bn
	end)
	return notes
end

local function sendNote(index)
	if not (GMRT and GMRT.A and GMRT.A.Note and GMRT.A.Note.frame and GMRT.A.Note.frame.Save) then
		print("|cffff5555KCT Raid Notes: MRT Note module is not ready.|r")
		return
	end
	if not (VMRT and VMRT.Note and VMRT.Note.Black and VMRT.Note.Black[index]) then
		print("|cffff5555KCT Raid Notes: saved note no longer exists.|r")
		return
	end
	GMRT.A.Note.frame:Save(index)
	print("|cff55ff55KCT sent MRT note:|r " .. getNoteName(index))
end

local function savePosition()
	local point, _, relPoint, x, y = frame:GetPoint(1)
	KravaCooldownTrackerDB.raidNotesPos = { point = point, relPoint = relPoint or point, x = x or 0, y = y or 0 }
end

local function restorePosition()
	local pos = KravaCooldownTrackerDB.raidNotesPos
	if pos and pos.point and pos.relPoint then
		frame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x or 0, pos.y or 0)
	else
		frame:SetPoint("CENTER", UIParent, "CENTER", 220, 0)
	end
end

local function toggleLock()
	if InCombatLockdown and InCombatLockdown() then return end
	C.Set("raidNotesLocked", not getConfig().raidNotesLocked)
	C.RefreshChanged()
end

local function getButton(slot)
	if buttons[slot] then return buttons[slot] end
	local template = BackdropTemplateMixin and "BackdropTemplate" or nil
	local button = CreateFrame("Button", nil, frame, template)
	button:SetFrameLevel(frame:GetFrameLevel() + 1)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button.bg = button:CreateTexture(nil, "BACKGROUND")
	button.bg:SetAllPoints()
	button.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
	button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	button.text:SetPoint("CENTER")
	button.text:SetTextColor(1, 1, 1, 1)
	button.highlight = button:CreateTexture(nil, "HIGHLIGHT")
	button.highlight:SetAllPoints()
	button.highlight:SetTexture("Interface\\Buttons\\WHITE8X8")
	button.highlight:SetVertexColor(1, 1, 1, 0.12)
	button:SetHighlightTexture(button.highlight)
	button:SetScript("OnClick", function(self, mouseButton)
		if mouseButton == "RightButton" then toggleLock() else sendNote(self.noteIndex) end
	end)
	buttons[slot] = button
	return button
end

function R.Refresh(force)
	if not frame then return end
	if not isEnabled() then frame:Hide(); return end
	local notes = getSortedNotes()
	local parts = {}
	for _, note in ipairs(notes) do parts[#parts + 1] = note.index .. ":" .. note.name end
	local signature = table.concat(parts, "\031") .. ":" .. tostring(getConfig().raidNotesLocked)
	if not force and signature == lastSignature then return end
	lastSignature = signature
	local cfg = getConfig()
	frame:SetFrameStrata(cfg.raidNotesStrata or "DIALOG")
	local padding, gap = cfg.raidNotesPadding or 6, cfg.raidNotesGap or 2
	local fontSize = cfg.raidNotesFontSize or 12
	local width, height = CONTENT_WIDTH + padding * 2, fontSize + padding * 2
	local bg, border = cfg.raidNotesBackgroundColor, cfg.raidNotesBorderColor
	for slot, note in ipairs(notes) do
		local button = getButton(slot)
		button.text:SetFont(cfg.fontFace or STANDARD_TEXT_FONT, fontSize, "OUTLINE")
		button.text:SetText(note.name)
		width = math.max(width, math.ceil(button.text:GetStringWidth()) + padding * 2)
	end
	for slot, note in ipairs(notes) do
		local button = getButton(slot)
		button.noteIndex = note.index
		button:SetSize(width, height)
		button:ClearAllPoints()
		button:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -((slot - 1) * (height + gap)))
		button.bg:SetVertexColor(bg[1], bg[2], bg[3], bg[4] or 1)
		if button.SetBackdrop then
			local borderWidth = cfg.raidNotesBorderWidth or 1
			button:SetBackdrop({ edgeFile=borderWidth > 0 and "Interface\\Tooltips\\UI-Tooltip-Border" or nil, edgeSize=8, insets={left=borderWidth,right=borderWidth,top=borderWidth,bottom=borderWidth} })
			button:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1)
		end
		local font = button.text
		if font then
			font:SetFont(cfg.fontFace or STANDARD_TEXT_FONT, fontSize, "OUTLINE")
			font:SetJustifyH("CENTER")
			font:SetJustifyV("MIDDLE")
		end
		button:Show()
	end
	for slot = #notes + 1, #buttons do buttons[slot]:Hide() end
	frame:SetSize(width, math.max(1, #notes * height + math.max(0, #notes - 1) * gap))
	dragHandle:SetShown(not cfg.raidNotesLocked)
	if #notes > 0 or not cfg.raidNotesLocked then frame:Show() else frame:Hide() end
end

function R.Initialize()
	if frame then return end
	frame = CreateFrame("Frame", "KravaCooldownTrackerRaidNotes", UIParent)
	frame:SetFrameStrata(getConfig().raidNotesStrata or "DIALOG")
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	restorePosition()
	dragHandle = CreateFrame("Button", nil, frame)
	dragHandle:SetSize(22, 24)
	dragHandle:SetPoint("RIGHT", frame, "LEFT", -3, 0)
	dragHandle:RegisterForDrag("LeftButton")
	dragHandle.bg = dragHandle:CreateTexture(nil, "ARTWORK")
	dragHandle.bg:SetAllPoints()
	dragHandle.bg:SetColorTexture(0.38, 0.45, 0.42, 1)
	dragHandle:SetScript("OnDragStart", function()
		if not getConfig().raidNotesLocked then frame:StartMoving() end
	end)
	dragHandle:SetScript("OnDragStop", function()
		frame:StopMovingOrSizing()
		savePosition()
	end)
	R.Refresh(true)
	C_Timer.NewTicker(1, function() R.Refresh(false) end)
end

if CreateFrame then
	local events = CreateFrame("Frame")
	events:RegisterEvent("PLAYER_LOGIN")
	events:RegisterEvent("PLAYER_ENTERING_WORLD")
	events:RegisterEvent("ADDON_LOADED")
	events:SetScript("OnEvent", function(_, event, addonName)
		if event == "ADDON_LOADED" and addonName ~= "MRT" and addonName ~= "KravaCooldownTracker" then return end
		if C_Timer and C_Timer.After then
			C_Timer.After(0.2, function() R.Initialize(); R.Refresh(true) end)
		else
			R.Initialize(); R.Refresh(true)
		end
	end)
end
