-- KravaCooldownTracker.lua
KravaCooldownTrackerDB = KravaCooldownTrackerDB or {}

local ADDON_NAME = "KravaCooldownTracker"

local ICON_SIZE      = 32
local GAP_BETWEEN    = 0
local DROPDOWN_GAP   = 0
local ICON_PAD       = 0
local HIDE_DELAY     = 0.12
local HANDLE_WIDTH   = 24
local HANDLE_GAP     = 3

local H = KravaCooldownTracker_Helpers
local T = KravaCooldownTracker_TrinketLogic
local D = KravaCooldownTracker_DebuffLogic
local C = KravaCooldownTracker_Config
local CL = KravaCooldownTracker_ConsumableLogic
local RN = KravaCooldownTracker_RaidNotes

-- wire UI knobs into module
T.ADDON_NAME = ADDON_NAME
T.ICON_SIZE = ICON_SIZE
T.ICON_PAD = ICON_PAD
T.DROPDOWN_GAP = DROPDOWN_GAP
T.HIDE_DELAY = HIDE_DELAY

local containerFrame
local leftDragHandle
local rightDragHandle

-- Debuff tracker (independent feature, mirrors the trinket container above).
local debuffContainerFrame
local leftDebuffDragHandle
local rightDebuffDragHandle
local debuffRows = {}

local function GetConfig()
	if C and C.Get then return C.Get() end
	return {
		mainIconSize = ICON_SIZE,
		queueIconPercent = 25,
		fontFace = STANDARD_TEXT_FONT,
		fontSize = 14,
		locked = true,
		disableTrinketUsageOnClick = true,
		disableUpperTrinketSuggestions = true,
		disableLowerTrinketSuggestions = true,
		suggestionPosition = "below",
		suggestionIconSize = 18,
		suggestionAvailableSound = "none",
		debuffIconSize = 32,
		debuffFontSize = 14,
		debuffDirection = "horizontal",
		debuffPerLine = 8,
		debuffLocked = true,
		debuffs = {
			majorArmorReduction = true,
			curseOfRecklessness = true,
			curseOfTheElements = true,
			huntersMark = true,
			scorpidSting = true,
			judgementOfTheCrusader = true,
			judgementOfWisdom = true,
			demoralizingShoutRoar = true,
			faerieFire = true,
			judgementOfLight = true,
			shadowVulnerability = true,
			thunderClap = true,
		},
	}
end

local function GetIconSize()
	return GetConfig().mainIconSize or ICON_SIZE
end

local function ApplyModuleDisplayConfig()
	local cfg = GetConfig()
	if T.SetDisplayConfig then
		T.SetDisplayConfig(cfg)
	end
	if D and D.SetDisplayConfig then
		D.SetDisplayConfig(cfg)
	end
	T.ICON_PAD = ICON_PAD
	T.DROPDOWN_GAP = DROPDOWN_GAP
	T.HIDE_DELAY = HIDE_DELAY
	return cfg
end

-- -------------------------------
-- Saved position (keep in main, DB-related)
-- -------------------------------
local function SaveContainerPosition(frame)
	local point, _, relPoint, x, y = frame:GetPoint(1)
	if not point then return end
	KravaCooldownTrackerDB.pos = { point = point, relPoint = relPoint or point, x = x or 0, y = y or 0 }
end

local function RestoreContainerPosition(frame)
	frame:ClearAllPoints()
	local pos = KravaCooldownTrackerDB.pos
	if pos and pos.point and pos.relPoint and pos.x ~= nil and pos.y ~= nil then
		frame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
	else
		frame:SetPoint("CENTER", UIParent, "CENTER", 0, 70)
	end
end

local function SaveDebuffPosition(frame)
	local point, _, relPoint, x, y = frame:GetPoint(1)
	if not point then return end
	KravaCooldownTrackerDB.debuffPos = { point = point, relPoint = relPoint or point, x = x or 0, y = y or 0 }
end

local function RestoreDebuffPosition(frame)
	frame:ClearAllPoints()
	local pos = KravaCooldownTrackerDB.debuffPos
	if pos and pos.point and pos.relPoint and pos.x ~= nil and pos.y ~= nil then
		frame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
	else
		frame:SetPoint("CENTER", UIParent, "CENTER", 0, -20)
	end
end

-- -------------------------------
-- UI: container
-- -------------------------------
local function CreateContainer()
	local cfg = ApplyModuleDisplayConfig()
	local iconSize = cfg.mainIconSize or ICON_SIZE
	local f = CreateFrame("Frame", ADDON_NAME .. "Container", UIParent)
	f:SetSize((iconSize * 2) + GAP_BETWEEN, iconSize)
	f:SetFrameStrata("BACKGROUND")
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f:SetMovable(true)

	RestoreContainerPosition(f)
	f:SetUserPlaced(true)

	function f:RefreshAll()
		for _, slotId in ipairs(T.TRINKET_SLOTS) do
			if T.slotIcon[slotId] and T.slotIcon[slotId].UpdateIcon then
				T.slotIcon[slotId]:UpdateIcon()
			end
		end
	end

	containerFrame = f
	return f
end

local function SetHandleShown(handle, shown)
	if not handle then return end
	if shown then
		handle:EnableMouse(true)
		handle:Show()
	else
		handle:EnableMouse(false)
		handle:Hide()
	end
end

local function RefreshDragHandles(cfg)
	cfg = cfg or GetConfig()
	local showHandles = not cfg.locked
	SetHandleShown(leftDragHandle, showHandles)
	SetHandleShown(rightDragHandle, showHandles)
end

local function CreateDragHandle(parent, side)
	local handle = CreateFrame("Button", ADDON_NAME .. side .. "DragHandle", parent)
	handle:SetSize(HANDLE_WIDTH, GetIconSize())
	handle:SetFrameStrata("BACKGROUND")
	handle:RegisterForDrag("LeftButton")

	if side == "Left" then
		handle:SetPoint("RIGHT", parent, "LEFT", -HANDLE_GAP, 0)
	else
		handle:SetPoint("LEFT", parent, "RIGHT", HANDLE_GAP, 0)
	end

	handle.bg = handle:CreateTexture(nil, "ARTWORK")
	handle.bg:SetAllPoints(handle)
	if handle.bg.SetColorTexture then
		handle.bg:SetColorTexture(0.38, 0.45, 0.42, 1)
	else
		handle.bg:SetTexture(0.38, 0.45, 0.42, 1)
	end

	handle.grip = handle:CreateTexture(nil, "OVERLAY")
	handle.grip:SetSize(2, math.max(8, GetIconSize() - 8))
	handle.grip:SetPoint("CENTER", handle, "CENTER", 0, 0)
	if handle.grip.SetColorTexture then
		handle.grip:SetColorTexture(0.85, 0.85, 0.85, 0.85)
	else
		handle.grip:SetTexture(0.85, 0.85, 0.85, 0.85)
	end
	handle.grip:Hide()

	handle:SetScript("OnDragStart", function()
		local cfg = GetConfig()
		if H.InCombat() or cfg.locked then return end
		parent:StartMoving()
	end)

	handle:SetScript("OnDragStop", function()
		if H.InCombat() then return end
		parent:StopMovingOrSizing()
		SaveContainerPosition(parent)
	end)

	function handle:ApplyDisplayConfig()
		local iconSize = GetIconSize()
		self:SetSize(HANDLE_WIDTH, iconSize)
		if self.grip then
			self.grip:SetSize(2, math.max(8, iconSize - 8))
			self.grip:Hide()
		end
	end

	return handle
end

-- -------------------------------
-- UI: slot icon buttons
-- -------------------------------
local function ApplyTrinketClickConfig(btn, slotId, cfg)
	if not btn or H.InCombat() then return end

	if cfg and cfg.disableTrinketUsageOnClick then
		btn:SetAttribute("type", nil)
		btn:SetAttribute("slot", nil)
	else
		btn:SetAttribute("type", "item")
		btn:SetAttribute("slot", slotId)
	end
end

local function CreateSlotIcon(slotId, parent, xOffset)
	local cfg = GetConfig()
	local iconSize = cfg.mainIconSize or ICON_SIZE
	local btn = CreateFrame("Button", ADDON_NAME .. "SlotIcon" .. slotId, parent, "SecureActionButtonTemplate")
	btn:SetSize(iconSize, iconSize)
	btn:SetPoint("LEFT", parent, "LEFT", xOffset, 0)
	btn:SetFrameStrata("BACKGROUND")
	btn:EnableMouse(true)

	btn:RegisterForClicks("LeftButtonDown", "LeftButtonUp", "RightButtonUp")
	btn:SetAttribute("type2", "macro")
	btn:SetAttribute("macrotext2", "")
	ApplyTrinketClickConfig(btn, slotId, cfg)

	btn.icon = btn:CreateTexture(nil, "ARTWORK")
	btn.icon:SetAllPoints(btn)
	btn.icon:SetTexture(H.DEFAULT_ICON_FILEID)
	btn.icon:SetTexCoord(H.CROP, 1 - H.CROP, H.CROP, 1 - H.CROP)

	btn.hl = btn:CreateTexture(nil, "HIGHLIGHT")
	btn.hl:SetAllPoints(btn)
	H.SetSquareOverlayTexture(btn.hl, 0.18, 0.45, 0.95, 0.28)
	btn.hl:SetBlendMode("ADD")

	btn.auraOverlay = btn:CreateTexture(nil, "OVERLAY")
	btn.auraOverlay:SetAllPoints(btn)
	H.SetSquareOverlayTexture(btn.auraOverlay, 1.0, 0.84, 0.18, 0.35)
	btn.auraOverlay:SetBlendMode("ADD")
	btn.auraOverlay:Hide()

	btn.queuedIcon = btn:CreateTexture(nil, "OVERLAY")
	btn.queuedIcon:SetSize(math.max(1, iconSize * (cfg.queueIconPercent or 25) / 100), math.max(1, iconSize * (cfg.queueIconPercent or 25) / 100))
	btn.queuedIcon:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
	btn.queuedIcon:SetTexCoord(H.CROP, 1 - H.CROP, H.CROP, 1 - H.CROP)
	btn.queuedIcon:SetTexture(H.DEFAULT_ICON_FILEID)
	btn.queuedIcon:Hide()

	btn.timeText = btn:CreateFontString(nil, "OVERLAY")
	btn.timeText:SetFont(cfg.fontFace or STANDARD_TEXT_FONT, cfg.fontSize or 14, "OUTLINE")
	btn.timeText:SetPoint("CENTER", btn, "CENTER", 0, 1)
	btn.timeText:SetText("")
	btn.timeText:SetDrawLayer("ARTWORK")

	btn:HookScript("OnClick", function(self, button)
		if button == "RightButton" then
			if H.InCombat() then return end
			if C and C.Set then
				local cfg = GetConfig()
				C.Set("locked", not cfg.locked)
				C.RefreshChanged()
			end
			return
		end

		if button == "LeftButton" then
			local state = T.slotState[slotId]
			local q = state.queuedItemId
			if q and not H.InCombat() then
				if state.queuedUnequip then
					T.QueueOrUnequip(slotId)
				else
					T.QueueOrEquip(slotId, q)
				end
				return
			end
		end
	end)

	btn:SetScript("OnEnter", function(self) T.ShowDropdown(slotId, self) end)
	btn:SetScript("OnLeave", function() T.ScheduleHide(slotId) end)

	function btn:UpdateIcon()
		local itemId = GetInventoryItemID("player", slotId)
		local tex = itemId and GetInventoryItemTexture("player", slotId) or H.DEFAULT_ICON_FILEID
		self.icon:SetTexture(tex or H.DEFAULT_ICON_FILEID)
		self:UpdateQueuedIcon()
	end

	function btn:UpdateQueuedIcon()
		local state = T.slotState[slotId]
		local queuedIcon = state and state.queuedItemTexture
		if state and state.queuedItemId and self.queuedIcon then
			if state.queuedUnequip then
				H.SetBlackTexture(self.queuedIcon)
			else
				self.queuedIcon:SetTexture(queuedIcon or H.GetItemIcon(state.queuedItemId))
			end
			self.queuedIcon:Show()
		elseif self.queuedIcon then
			self.queuedIcon:Hide()
		end
	end

	function btn:ApplyDisplayConfig(newCfg, newXOffset)
		local newIconSize = newCfg.mainIconSize or ICON_SIZE
		self:SetSize(newIconSize, newIconSize)
		self:ClearAllPoints()
		self:SetPoint("LEFT", parent, "LEFT", newXOffset, 0)
		local queueSize = math.max(1, newIconSize * (newCfg.queueIconPercent or 25) / 100)
		self.queuedIcon:SetSize(queueSize, queueSize)
		self.timeText:SetFont(newCfg.fontFace or STANDARD_TEXT_FONT, newCfg.fontSize or 14, "OUTLINE")
		ApplyTrinketClickConfig(self, slotId, newCfg)
	end

	btn:UpdateIcon()

	T.slotIcon[slotId] = btn
	return btn
end

local function IsTrinketsEnabled()
	if C and C.IsFeatureEnabled then
		return C.IsFeatureEnabled("trinkets")
	end
	return true
end

local function RefreshTrackerDisplay()
	local cfg = ApplyModuleDisplayConfig()
	local enabled = IsTrinketsEnabled()
	if T.SetFeatureEnabled then T.SetFeatureEnabled(enabled) end

	if not enabled then
		if containerFrame then containerFrame:Hide() end
		SetHandleShown(leftDragHandle, false)
		SetHandleShown(rightDragHandle, false)
		for _, slotId in ipairs(T.TRINKET_SLOTS) do
			if T.suggestion[slotId] then T.suggestion[slotId]:Hide() end
			if T.dropdown[slotId] then T.dropdown[slotId]:Hide() end
		end
		return
	end

	if containerFrame then containerFrame:Show() end

	local iconSize = cfg.mainIconSize or ICON_SIZE

	if containerFrame then
		containerFrame:SetSize((iconSize * 2) + GAP_BETWEEN, iconSize)
	end

	for index, slotId in ipairs(T.TRINKET_SLOTS) do
		local btn = T.slotIcon[slotId]
		if btn and btn.ApplyDisplayConfig then
			btn:ApplyDisplayConfig(cfg, (index - 1) * (iconSize + GAP_BETWEEN))
			btn:UpdateIcon()
		end
	end

	if T.RefreshDropdowns then
		T.RefreshDropdowns()
	end
	if T.RefreshSuggestions then
		T.RefreshSuggestions()
	end

	if leftDragHandle and leftDragHandle.ApplyDisplayConfig then
		leftDragHandle:ApplyDisplayConfig()
	end
	if rightDragHandle and rightDragHandle.ApplyDisplayConfig then
		rightDragHandle:ApplyDisplayConfig()
	end
	RefreshDragHandles(cfg)
end

-- -------------------------------
-- UI: debuff tracker (independent feature)
-- -------------------------------
local function IsDebuffsEnabled()
	if C and C.IsFeatureEnabled then
		return C.IsFeatureEnabled("debuffs")
	end
	return true
end

local function CreateDebuffContainer()
	local f = CreateFrame("Frame", ADDON_NAME .. "DebuffContainer", UIParent)
	f:SetSize(D.ICON_SIZE, D.ICON_SIZE)
	f:SetFrameStrata("BACKGROUND")
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f:SetMovable(true)

	RestoreDebuffPosition(f)
	f:SetUserPlaced(true)

	debuffContainerFrame = f
	return f
end

local function RefreshDebuffDragHandles(cfg)
	cfg = cfg or GetConfig()
	local showHandles = not cfg.debuffLocked
	SetHandleShown(leftDebuffDragHandle, showHandles)
	SetHandleShown(rightDebuffDragHandle, showHandles)
end

-- Duplicated from CreateDragHandle (smaller diff than parameterizing): sizes to
-- D.ICON_SIZE, gates on cfg.debuffLocked, and saves to KravaCooldownTrackerDB.debuffPos.
local function CreateDebuffDragHandle(parent, side)
	local handle = CreateFrame("Button", ADDON_NAME .. side .. "DebuffDragHandle", parent)
	handle:SetSize(HANDLE_WIDTH, D.ICON_SIZE)
	handle:SetFrameStrata("BACKGROUND")
	handle:RegisterForDrag("LeftButton")

	if side == "Left" then
		handle:SetPoint("RIGHT", parent, "LEFT", -HANDLE_GAP, 0)
	else
		handle:SetPoint("LEFT", parent, "RIGHT", HANDLE_GAP, 0)
	end

	handle.bg = handle:CreateTexture(nil, "ARTWORK")
	handle.bg:SetAllPoints(handle)
	if handle.bg.SetColorTexture then
		handle.bg:SetColorTexture(0.38, 0.45, 0.42, 1)
	else
		handle.bg:SetTexture(0.38, 0.45, 0.42, 1)
	end

	handle.grip = handle:CreateTexture(nil, "OVERLAY")
	handle.grip:SetSize(2, math.max(8, D.ICON_SIZE - 8))
	handle.grip:SetPoint("CENTER", handle, "CENTER", 0, 0)
	if handle.grip.SetColorTexture then
		handle.grip:SetColorTexture(0.85, 0.85, 0.85, 0.85)
	else
		handle.grip:SetTexture(0.85, 0.85, 0.85, 0.85)
	end
	handle.grip:Hide()

	handle:SetScript("OnDragStart", function()
		local cfg = GetConfig()
		if H.InCombat() or cfg.debuffLocked then return end
		parent:StartMoving()
	end)

	handle:SetScript("OnDragStop", function()
		if H.InCombat() then return end
		parent:StopMovingOrSizing()
		SaveDebuffPosition(parent)
	end)

	function handle:ApplyDisplayConfig()
		local iconSize = D.ICON_SIZE
		self:SetSize(HANDLE_WIDTH, iconSize)
		if self.grip then
			self.grip:SetSize(2, math.max(8, iconSize - 8))
			self.grip:Hide()
		end
	end

	return handle
end

local function ApplyDebuffRowFont(row, cfg)
	local face = cfg.fontFace or STANDARD_TEXT_FONT
	row.timer:SetFont(face, D.FONT_SIZE, "OUTLINE")
	-- Stacks sit in the icon corner, smaller than the centered timer so the two
	-- never collide.
	local stackSize = math.max(8, math.floor(D.FONT_SIZE * 0.7 + 0.5))
	row.stacks:SetFont(face, stackSize, "OUTLINE")
end

-- Rows are plain (non-secure) Buttons, not SecureActionButtonTemplate: this
-- resolves the spec's internal Frame-vs-Button note in favor of the explicit
-- UX requirement (right-click toggles debuffLocked). No secure attributes are
-- set, so rows may be created/resized/repositioned freely, even in combat.
local function GetOrCreateDebuffRow(i)
	if debuffRows[i] then return debuffRows[i] end

	local row = CreateFrame("Button", ADDON_NAME .. "DebuffRow" .. i, debuffContainerFrame)
	row:EnableMouse(true)
	row:RegisterForClicks("RightButtonUp")

	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetAllPoints(row)
	row.icon:SetTexCoord(H.CROP, 1 - H.CROP, H.CROP, 1 - H.CROP)

	row.stacks = row:CreateFontString(nil, "OVERLAY")
	row.stacks:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -1, 1)

	row.timer = row:CreateFontString(nil, "OVERLAY")
	row.timer:SetPoint("CENTER", row, "CENTER", 0, 0)

	-- A font must be set before any SetText, else "Font not set" errors.
	ApplyDebuffRowFont(row, GetConfig())
	row.stacks:SetText("")
	row.timer:SetText("")

	row:HookScript("OnClick", function(_, button)
		if button ~= "RightButton" then return end
		if H.InCombat() then return end
		if C and C.Set then
			local cfg = GetConfig()
			C.Set("debuffLocked", not cfg.debuffLocked)
			C.RefreshChanged()
		end
	end)

	debuffRows[i] = row
	return row
end

-- Target must exist, be alive, and be attackable (hostile) for the grid to show.
local function TargetIsTrackable()
	return UnitExists("target")
		and not UnitIsDead("target")
		and UnitCanAttack("player", "target")
end

-- The grid shows when the feature is on AND (the target is trackable OR the
-- tracker is unlocked). Keeping it visible while unlocked lets the player drag
-- it into position without needing a live target.
local function DebuffFrameShouldShow(cfg)
	cfg = cfg or GetConfig()
	if not IsDebuffsEnabled() then return false end
	if not cfg.debuffLocked then return true end
	return TargetIsTrackable()
end

local function RefreshDebuffRows()
	if not debuffContainerFrame then return end
	local cfg = GetConfig()

	if not DebuffFrameShouldShow(cfg) then
		debuffContainerFrame:Hide()
		SetHandleShown(leftDebuffDragHandle, false)
		SetHandleShown(rightDebuffDragHandle, false)
		for _, row in ipairs(debuffRows) do
			row:Hide()
		end
		return
	end

	debuffContainerFrame:Show()

	local visible = D.GetVisibleRows()
	if #visible == 0 and not cfg.debuffLocked then
		visible = D.DEBUFFS
	end
	local iconSize = D.ICON_SIZE

	for i, entry in ipairs(visible) do
		local row = GetOrCreateDebuffRow(i)
		row:SetSize(iconSize, iconSize)
		ApplyDebuffRowFont(row, cfg)

		local x, y = D.ComputeRowPosition(i - 1, D.DIRECTION, D.PER_LINE, iconSize)
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", debuffContainerFrame, "TOPLEFT", x, y)
		row:Show()

		local base = D.ResolveDebuffIcon(entry.iconSpellId)
		local state = D.rowState[entry.key]

		if state and state.active then
			row.icon:SetDesaturated(false)
			row.icon:SetVertexColor(1, 1, 1, 1)
			if state.icon then
				row.icon:SetTexture(state.icon)
			else
				row.icon:SetTexture(base)
			end
			if state.duration > 0 and state.expirationTime > 0 then
				row.timer:SetText(H.FormatTimeLeft(state.expirationTime - GetTime()))
			else
				row.timer:SetText("")
			end
			if state.stacks and state.stacks > 0 then
				row.stacks:SetText(tostring(state.stacks))
			else
				row.stacks:SetText("")
			end
		else
			row.icon:SetTexture(base)
			row.icon:SetDesaturated(true)
			row.icon:SetVertexColor(0.55, 0.55, 0.55, 1)
			row.timer:SetText("")
			row.stacks:SetText("")
		end
	end

	-- Hide previously-shown rows that are no longer visible (toggled off).
	for i = #visible + 1, #debuffRows do
		debuffRows[i]:Hide()
	end

	local w, h = D.ComputeContainerSize(#visible, D.DIRECTION, D.PER_LINE, iconSize)
	debuffContainerFrame:SetSize(math.max(w, 1), math.max(h, 1))

	if leftDebuffDragHandle and leftDebuffDragHandle.ApplyDisplayConfig then
		leftDebuffDragHandle:ApplyDisplayConfig()
	end
	if rightDebuffDragHandle and rightDebuffDragHandle.ApplyDisplayConfig then
		rightDebuffDragHandle:ApplyDisplayConfig()
	end
	RefreshDebuffDragHandles(cfg)
end

-- Recompute only the cached timer text of active rows (no aura rescan).
local function RefreshDebuffTimers()
	if not debuffContainerFrame or not debuffContainerFrame:IsShown() then return end
	local cfg = GetConfig()
	local visible = D.GetVisibleRows()
	if #visible == 0 and not cfg.debuffLocked then
		visible = D.DEBUFFS
	end
	for i, entry in ipairs(visible) do
		local row = debuffRows[i]
		local state = D.rowState[entry.key]
		if row and row:IsShown() and state and state.active
			and state.duration > 0 and state.expirationTime > 0 then
			row.timer:SetText(H.FormatTimeLeft(state.expirationTime - GetTime()))
		end
	end
end

local function RefreshDebuffDisplay()
	ApplyModuleDisplayConfig()
	if D.SetFeatureEnabled then
		D.SetFeatureEnabled(IsDebuffsEnabled())
	end
	RefreshDebuffRows()
end

-- Single shared refresh callback drives both features from one place.
local function RefreshAllDisplays()
	RefreshTrackerDisplay()
	RefreshDebuffDisplay()
	if CL and CL.RefreshRuntime then CL.RefreshRuntime() end
	if RN and RN.Refresh then RN.Refresh(true) end
end

if C then
	function C.RestorePositions()
		if H.InCombat() then return end
		if containerFrame then
			containerFrame:StopMovingOrSizing()
			RestoreContainerPosition(containerFrame)
		end
		if debuffContainerFrame then
			debuffContainerFrame:StopMovingOrSizing()
			RestoreDebuffPosition(debuffContainerFrame)
		end
		if CL and CL.RestorePosition then CL.RestorePosition() end
		if RN and RN.RestorePosition then RN.RestorePosition() end
	end
end

KravaCooldownTracker_RefreshDisplay = RefreshAllDisplays

-- -------------------------------
-- OnUpdate (throttled)
-- -------------------------------
local elapsedAcc = 0
local function OnUpdate(_, elapsed)
	if not IsTrinketsEnabled() then return end
	elapsedAcc = elapsedAcc + elapsed
	if elapsedAcc < 0.05 then return end
	elapsedAcc = 0

	for _, slotId in ipairs(T.TRINKET_SLOTS) do
		if T.slotIcon[slotId] then
			T.UpdateSlotOverlay(slotId, T.slotIcon[slotId])
			if T.slotIcon[slotId].UpdateQueuedIcon then
				T.slotIcon[slotId]:UpdateQueuedIcon()
			end
			if T.UpdateSuggestion then
				T.UpdateSuggestion(slotId)
			end
		end
	end
end

-- Separate throttled loop on the debuff container so timers keep counting down
-- even when the Trinkets feature (and its container/OnUpdate) is disabled.
-- Only recomputes cached countdown text; never rescans auras.
local debuffElapsedAcc = 0
local function DebuffOnUpdate(_, elapsed)
	if not IsDebuffsEnabled() then return end
	debuffElapsedAcc = debuffElapsedAcc + elapsed
	if debuffElapsedAcc < 0.05 then return end
	debuffElapsedAcc = 0
	-- Target death / hostile change do not fire PLAYER_TARGET_CHANGED, so re-check
	-- visibility here while the frame is shown; if it should hide, RefreshDebuffRows
	-- hides it (hidden frames stop ticking until a target event re-shows them).
	if not DebuffFrameShouldShow() then
		RefreshDebuffRows()
		return
	end
	RefreshDebuffTimers()
end

-- -------------------------------
-- Events
-- -------------------------------
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
loader:RegisterEvent("BAG_UPDATE")
loader:RegisterEvent("BAG_UPDATE_DELAYED")
loader:RegisterEvent("ITEM_DATA_LOAD_RESULT")
loader:RegisterEvent("PLAYER_REGEN_ENABLED")
loader:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
loader:RegisterEvent("PLAYER_TARGET_CHANGED")
loader:RegisterEvent("UNIT_AURA")

loader:SetScript("OnEvent", function(_, event, ...)
	if event == "PLAYER_LOGIN" then
		T.SetPlayerGUID(UnitGUID("player"))
		ApplyModuleDisplayConfig()
		if C and C.SetRefreshCallback then
			C.SetRefreshCallback(RefreshAllDisplays)
		end

		local cont = CreateContainer()
		CreateSlotIcon(13, cont, 0)
		CreateSlotIcon(14, cont, GetIconSize() + GAP_BETWEEN)
		if T.CreateSuggestionFrame then
			T.CreateSuggestionFrame(13, T.slotIcon[13])
			T.CreateSuggestionFrame(14, T.slotIcon[14])
		end
		leftDragHandle = CreateDragHandle(cont, "Left")
		rightDragHandle = CreateDragHandle(cont, "Right")
		RefreshDragHandles(GetConfig())

		T.InitSlotState()
		RefreshTrackerDisplay()

		cont:SetScript("OnUpdate", OnUpdate)

		-- Debuff tracker UI (independent container/handles/rows).
		local debuffCont = CreateDebuffContainer()
		leftDebuffDragHandle = CreateDebuffDragHandle(debuffCont, "Left")
		rightDebuffDragHandle = CreateDebuffDragHandle(debuffCont, "Right")
		if D.SetFeatureEnabled then D.SetFeatureEnabled(IsDebuffsEnabled()) end
		D.RefreshFromTarget()
		RefreshDebuffRows()
		debuffCont:SetScript("OnUpdate", DebuffOnUpdate)
		return
	end

	if event == "PLAYER_EQUIPMENT_CHANGED" then
		T.OnEquipmentChanged(...)
		if C and C.RefreshTrinketBlacklistLists then
			C.RefreshTrinketBlacklistLists()
		end
		if T.UpdateSuggestion then
			T.UpdateSuggestion((...))
		end
		return
	end

	if event == "BAG_UPDATE" or event == "BAG_UPDATE_DELAYED" or event == "ITEM_DATA_LOAD_RESULT" then
		if C and C.RefreshTrinketBlacklistLists then
			C.RefreshTrinketBlacklistLists()
		end
		for _, slotId in ipairs(T.TRINKET_SLOTS) do
			if T.dropdown[slotId] and T.dropdown[slotId]:IsShown() then
				T.UpdateDropdown(slotId)
			end
			if T.UpdateSuggestion then
				T.UpdateSuggestion(slotId)
			end
		end
		return
	end

	if event == "PLAYER_REGEN_ENABLED" then
		RefreshTrackerDisplay()
		T.OnCombatEnded(containerFrame)
		if T.RefreshSuggestions then
			T.RefreshSuggestions()
		end
		return
	end

	if event == "COMBAT_LOG_EVENT_UNFILTERED" then
		T.OnCombatLogEvent()
		return
	end

	if event == "PLAYER_TARGET_CHANGED" then
		D.RefreshFromTarget()
		RefreshDebuffRows()
		return
	end

	if event == "UNIT_AURA" then
		local unit = ...
		if unit == "target" then
			D.RefreshFromTarget()
			RefreshDebuffRows()
		end
		return
	end
end)
