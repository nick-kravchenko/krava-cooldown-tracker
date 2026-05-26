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
local C = KravaCooldownTracker_Config

-- wire UI knobs into module
T.ADDON_NAME = ADDON_NAME
T.ICON_SIZE = ICON_SIZE
T.ICON_PAD = ICON_PAD
T.DROPDOWN_GAP = DROPDOWN_GAP
T.HIDE_DELAY = HIDE_DELAY

local containerFrame
local leftDragHandle
local rightDragHandle

local function GetConfig()
	if C and C.Get then return C.Get() end
	return {
		mainIconSize = ICON_SIZE,
		queueIconPercent = 25,
		fontFace = STANDARD_TEXT_FONT,
		fontSize = 14,
		locked = true,
		disableTrinketUsageOnClick = true,
		notificationPosition = "below",
		notificationIconSize = 18,
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
			KravaCooldownTrackerDB.pos = nil
			RestoreContainerPosition(parent)
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

local function RefreshTrackerDisplay()
	local cfg = ApplyModuleDisplayConfig()
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
	if T.RefreshNotifications then
		T.RefreshNotifications()
	end

	if leftDragHandle and leftDragHandle.ApplyDisplayConfig then
		leftDragHandle:ApplyDisplayConfig()
	end
	if rightDragHandle and rightDragHandle.ApplyDisplayConfig then
		rightDragHandle:ApplyDisplayConfig()
	end
	RefreshDragHandles(cfg)
end

KravaCooldownTracker_RefreshDisplay = RefreshTrackerDisplay

-- -------------------------------
-- OnUpdate (throttled)
-- -------------------------------
local elapsedAcc = 0
local function OnUpdate(_, elapsed)
	elapsedAcc = elapsedAcc + elapsed
	if elapsedAcc < 0.05 then return end
	elapsedAcc = 0

	for _, slotId in ipairs(T.TRINKET_SLOTS) do
		if T.slotIcon[slotId] then
			T.UpdateSlotOverlay(slotId, T.slotIcon[slotId])
			if T.slotIcon[slotId].UpdateQueuedIcon then
				T.slotIcon[slotId]:UpdateQueuedIcon()
			end
			if T.UpdateNotification then
				T.UpdateNotification(slotId)
			end
		end
	end
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

loader:SetScript("OnEvent", function(_, event, ...)
	if event == "PLAYER_LOGIN" then
		T.SetPlayerGUID(UnitGUID("player"))
		ApplyModuleDisplayConfig()
		if C and C.SetRefreshCallback then
			C.SetRefreshCallback(RefreshTrackerDisplay)
		end

		local cont = CreateContainer()
		CreateSlotIcon(13, cont, 0)
		CreateSlotIcon(14, cont, GetIconSize() + GAP_BETWEEN)
		if T.CreateNotificationFrame then
			T.CreateNotificationFrame(13, T.slotIcon[13])
			T.CreateNotificationFrame(14, T.slotIcon[14])
		end
		leftDragHandle = CreateDragHandle(cont, "Left")
		rightDragHandle = CreateDragHandle(cont, "Right")
		RefreshDragHandles(GetConfig())

		T.InitSlotState()

		cont:SetScript("OnUpdate", OnUpdate)
		return
	end

	if event == "PLAYER_EQUIPMENT_CHANGED" then
		T.OnEquipmentChanged(...)
		if T.UpdateNotification then
			T.UpdateNotification((...))
		end
		return
	end

	if event == "BAG_UPDATE" or event == "BAG_UPDATE_DELAYED" or event == "ITEM_DATA_LOAD_RESULT" then
		for _, slotId in ipairs(T.TRINKET_SLOTS) do
			if T.dropdown[slotId] and T.dropdown[slotId]:IsShown() then
				T.UpdateDropdown(slotId)
			end
			if T.UpdateNotification then
				T.UpdateNotification(slotId)
			end
		end
		return
	end

	if event == "PLAYER_REGEN_ENABLED" then
		RefreshTrackerDisplay()
		T.OnCombatEnded(containerFrame)
		if T.RefreshNotifications then
			T.RefreshNotifications()
		end
		return
	end

	if event == "COMBAT_LOG_EVENT_UNFILTERED" then
		T.OnCombatLogEvent()
		return
	end
end)
