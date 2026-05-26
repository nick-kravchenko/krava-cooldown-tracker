-- KravaCooldownTracker_TrinketLogic.lua

KravaCooldownTracker_TrinketLogic = KravaCooldownTracker_TrinketLogic or {}
local T = KravaCooldownTracker_TrinketLogic
local H = KravaCooldownTracker_Helpers

-- public constants / defaults
T.TRINKET_SLOTS = { 13, 14 }
T.BAG_MIN, T.BAG_MAX = 0, 4

-- per-slot state
T.slotState = {
	[13] = { queuedItemId = nil, queuedItemTexture = nil, queuedItemName = nil, queuedUnequip = false, equipLockoutEnd = 0, icdEnd = 0, lastEquippedItemId = nil },
	[14] = { queuedItemId = nil, queuedItemTexture = nil, queuedItemName = nil, queuedUnequip = false, equipLockoutEnd = 0, icdEnd = 0, lastEquippedItemId = nil },
}

-- config knobs
T.EQUIP_LOCKOUT_SECONDS = 30

-- UI knobs (these will be set from main)
T.ICON_SIZE = 32
T.ICON_PAD = 0
T.DROPDOWN_GAP = 0
T.HIDE_DELAY = 0.12
T.ADDON_NAME = "KravaCooldownTracker"
T.FONT_FACE = STANDARD_TEXT_FONT
T.FONT_SIZE = 14
T.DROPDOWN_FONT_SIZE = 12

-- runtime refs injected from main
T.dropdown = {}   -- slotId -> frame
T.slotIcon = {}   -- slotId -> button
T.hideToken = {}  -- slotId -> int

function T.SetDisplayConfig(cfg)
	if not cfg then return end
	T.ICON_SIZE = cfg.mainIconSize or T.ICON_SIZE
	T.FONT_FACE = cfg.fontFace or T.FONT_FACE or STANDARD_TEXT_FONT
	T.FONT_SIZE = cfg.fontSize or T.FONT_SIZE
	T.DROPDOWN_FONT_SIZE = math.max(8, math.floor((T.FONT_SIZE or 14) * 0.85 + 0.5))
end

function T.RefreshDropdowns()
	for _, slotId in ipairs(T.TRINKET_SLOTS) do
		local f = T.dropdown[slotId]
		if f and f.buttons then
			for index, btn in ipairs(f.buttons) do
				btn:SetSize(T.ICON_SIZE, T.ICON_SIZE)
				if btn.timeText then
					btn.timeText:SetFont(T.FONT_FACE or STANDARD_TEXT_FONT, T.DROPDOWN_FONT_SIZE or 12, "OUTLINE")
				end
				if btn:IsShown() then
					btn:ClearAllPoints()
					btn:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -((index - 1) * (T.ICON_SIZE + T.ICON_PAD)))
				end
			end
		end
		if f and f:IsShown() then
			T.UpdateDropdown(slotId)
		end
	end
end

-- -------------------------------
-- Config access
-- -------------------------------
function T.GetCfg()
	return KravaCooldownTracker_TrinketCfg or {}
end

local function GetItemCfg(itemId)
	local cfg = T.GetCfg()
	return itemId and cfg[itemId] or nil
end

local function SetQueuedItem(slotId, itemId)
	local state = T.slotState[slotId]
	if not state then return end

	state.queuedItemId = itemId
	state.queuedUnequip = false

	if itemId then
		local name = GetItemInfo(itemId)
		state.queuedItemName = name or ("item:" .. itemId)
		state.queuedItemTexture = H.GetItemIcon(itemId)
	else
		state.queuedItemName = nil
		state.queuedItemTexture = nil
	end

	if T.slotIcon[slotId] and T.slotIcon[slotId].UpdateIcon then
		T.slotIcon[slotId]:UpdateIcon()
	end
end

local function SetQueuedUnequip(slotId)
	local state = T.slotState[slotId]
	if not state then return end

	state.queuedItemId = "UNEQUIP"
	state.queuedUnequip = true
	state.queuedItemName = "Empty"
	state.queuedItemTexture = nil

	if T.slotIcon[slotId] and T.slotIcon[slotId].UpdateIcon then
		T.slotIcon[slotId]:UpdateIcon()
	end
end

local function ClearQueue(slotId)
	local state = T.slotState[slotId]
	if not state then return end

	state.queuedItemId = nil
	state.queuedUnequip = false
	state.queuedItemName = nil
	state.queuedItemTexture = nil

	if T.slotIcon[slotId] and T.slotIcon[slotId].UpdateIcon then
		T.slotIcon[slotId]:UpdateIcon()
	end
end

-- -------------------------------
-- Trinket detection (bags)
-- -------------------------------
local function IsTrinket(itemId)
	if not itemId then return false end
	if GetItemInfoInstant then
		local _, _, _, equipLoc = GetItemInfoInstant(itemId)
		return equipLoc == "INVTYPE_TRINKET"
	end
	local _, _, _, _, _, _, _, _, equipLoc = GetItemInfo(itemId)
	return equipLoc == "INVTYPE_TRINKET"
end

function T.GetBagTrinkets()
	local trinkets = {}

	for bag = T.BAG_MIN, T.BAG_MAX do
		local slots = H.GetContainerNumSlots(bag) or 0
		for slot = 1, slots do
			local itemId = H.GetContainerItemID(bag, slot)
			if itemId and IsTrinket(itemId) then
				local name, link = GetItemInfo(itemId)
				trinkets[#trinkets + 1] = {
					itemId = itemId,
					name   = name or ("item:" .. itemId),
					link   = link,
					icon   = H.GetItemIcon(itemId),
					bag    = bag,
					slot   = slot,
				}
			end
		end
	end

	table.sort(trinkets, function(a, b)
		return (a.name or "") < (b.name or "")
	end)

	return trinkets
end

-- -------------------------------
-- Equip helpers
-- -------------------------------
local function ConfirmEquipped(slotId, itemId)
	return GetInventoryItemID("player", slotId) == itemId
end

local function TryEquipItemIdIntoSlot(itemId, slotId)
	if not itemId or not slotId then return false end
	if H.InCombat() then return false end

	if EquipItemByName then
		EquipItemByName(itemId, slotId)
		return true
	end

	return false
end

function T.QueueOrEquip(slotId, itemId)
	if not itemId then return end

	if H.InCombat() then
		SetQueuedItem(slotId, itemId)
		return
	end

	local attempted = TryEquipItemIdIntoSlot(itemId, slotId)
	if not attempted then
		SetQueuedItem(slotId, itemId)
		return
	end

	if C_Timer and C_Timer.After then
		C_Timer.After(0.20, function()
			if ConfirmEquipped(slotId, itemId) then
				ClearQueue(slotId)
			else
				SetQueuedItem(slotId, itemId)
			end
		end)
	end
end

local function TryUnequipSlot(slotId)
	if not slotId then return false end
	if H.InCombat() then return false end
	if not GetInventoryItemID("player", slotId) then return true end
	if not PickupInventoryItem or not PutItemInBackpack then return false end

	if ClearCursor then ClearCursor() end
	PickupInventoryItem(slotId)
	PutItemInBackpack()
	return true
end

function T.QueueOrUnequip(slotId)
	if H.InCombat() then
		SetQueuedUnequip(slotId)
		return
	end

	local attempted = TryUnequipSlot(slotId)
	if not attempted then
		SetQueuedUnequip(slotId)
		return
	end

	if C_Timer and C_Timer.After then
		C_Timer.After(0.20, function()
			if not GetInventoryItemID("player", slotId) then
				ClearQueue(slotId)
			else
				SetQueuedUnequip(slotId)
			end
		end)
	end
end

function T.OnCombatEnded(containerFrame)
	if H.InCombat() then return end

	for _, slotId in ipairs(T.TRINKET_SLOTS) do
		local state = T.slotState[slotId]
		local q = state.queuedItemId
		if state.queuedUnequip then
			local attempted = TryUnequipSlot(slotId)
			if attempted and C_Timer and C_Timer.After then
				C_Timer.After(0.20, function()
					if not GetInventoryItemID("player", slotId) then
						ClearQueue(slotId)
					else
						SetQueuedUnequip(slotId)
					end
				end)
			end
		elseif q then
			local attempted = TryEquipItemIdIntoSlot(q, slotId)
			if not attempted then
			else
				if C_Timer and C_Timer.After then
					C_Timer.After(0.20, function()
						if ConfirmEquipped(slotId, q) then
							ClearQueue(slotId)
						else
							SetQueuedItem(slotId, q)
						end
					end)
				end
			end
		end
	end

	if containerFrame and containerFrame.RefreshAll then
		containerFrame:RefreshAll()
	end
end

-- -------------------------------
-- Dropdown show/hide helpers
-- -------------------------------
function T.IsMouseOverSlotArea(slotId)
	if T.slotIcon[slotId] and MouseIsOver(T.slotIcon[slotId]) then
		return true
	end

	local f = T.dropdown[slotId]
	if f and f:IsShown() then
		if MouseIsOver(f) then return true end
		if f.buttons then
			for _, b in ipairs(f.buttons) do
				if b:IsShown() and MouseIsOver(b) then
					return true
				end
			end
		end
	end

	return false
end

local function CancelHide(slotId)
	T.hideToken[slotId] = (T.hideToken[slotId] or 0) + 1
end

function T.CancelHide(slotId)
	CancelHide(slotId)
end

local function ScheduleHide(slotId)
	T.hideToken[slotId] = (T.hideToken[slotId] or 0) + 1
	local tok = T.hideToken[slotId]

	if C_Timer and C_Timer.After then
		C_Timer.After(T.HIDE_DELAY, function()
			if tok ~= T.hideToken[slotId] then return end
			if T.IsMouseOverSlotArea(slotId) then return end
			if T.dropdown[slotId] then T.dropdown[slotId]:Hide() end
		end)
	else
		if T.dropdown[slotId] then T.dropdown[slotId]:Hide() end
	end
end

function T.ScheduleHide(slotId)
	ScheduleHide(slotId)
end

-- -------------------------------
-- Dropdown frames
-- -------------------------------
local function CreateDropdownFrame(slotId)
	local f = CreateFrame("Frame", T.ADDON_NAME .. "DropdownFrame" .. slotId, UIParent)
	f:SetFrameStrata("HIGH")
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f.buttons = {}

	f:SetScript("OnEnter", function() CancelHide(slotId) end)
	f:SetScript("OnLeave", function() ScheduleHide(slotId) end)

	local acc = 0
	local hideAcc = 0

	f:SetScript("OnUpdate", function(self, elapsed)
		if not self:IsShown() then return end

		-- robust auto-hide
		if T.IsMouseOverSlotArea(slotId) then
			hideAcc = 0
		else
			hideAcc = hideAcc + elapsed
			if hideAcc >= T.HIDE_DELAY then
				self:Hide()
				hideAcc = 0
				return
			end
		end

		acc = acc + elapsed
		if acc < 0.10 then return end
		acc = 0

		for _, btn in ipairs(self.buttons) do
			if btn:IsShown() and btn.__bag and btn.__slot then
				local cd = H.GetRemainingCooldownForBagSlot(btn.__bag, btn.__slot)
				if cd > 0 then
					btn.timeText:SetText(H.FormatTimeLeft(cd))
					btn.tex:SetVertexColor(0.55, 0.55, 0.55, 1)
				else
					btn.timeText:SetText("")
					btn.tex:SetVertexColor(1, 1, 1, 1)
				end
			end
		end
	end)

	f:Hide()
	T.dropdown[slotId] = f
end

local function GetOrCreateDropdownButton(slotId, i)
	local f = T.dropdown[slotId]
	local btn = f.buttons[i]
	if btn then return btn end

	btn = CreateFrame("Button", T.ADDON_NAME .. "DropdownButton" .. slotId .. "_" .. i, f)
	btn:SetSize(T.ICON_SIZE, T.ICON_SIZE)
	btn:EnableMouse(true)

	btn:SetScript("OnEnter", function() CancelHide(slotId) end)
	btn:SetScript("OnLeave", function() ScheduleHide(slotId) end)

	btn.tex = btn:CreateTexture(nil, "ARTWORK")
	btn.tex:SetAllPoints(btn)
	btn.tex:SetTexCoord(H.CROP, 1 - H.CROP, H.CROP, 1 - H.CROP)

	btn.hl = btn:CreateTexture(nil, "HIGHLIGHT")
	btn.hl:SetAllPoints(btn)
	H.SetSquareOverlayTexture(btn.hl, 0.18, 0.45, 0.95, 0.28)
	btn.hl:SetBlendMode("ADD")

	btn.timeText = btn:CreateFontString(nil, "OVERLAY")
	btn.timeText:SetFont(T.FONT_FACE or STANDARD_TEXT_FONT, T.DROPDOWN_FONT_SIZE or 12, "OUTLINE")
	btn.timeText:SetPoint("CENTER", btn, "CENTER", 0, -1)
	btn.timeText:SetText("")

	btn.__bag = nil
	btn.__slot = nil
	btn.__itemId = nil
	btn.__empty = nil

	f.buttons[i] = btn
	return btn
end

local function ConfigureEmptyButton(slotId, f, index)
	local btn = GetOrCreateDropdownButton(slotId, index)
	btn:ClearAllPoints()
	btn:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -((index - 1) * (T.ICON_SIZE + T.ICON_PAD)))
	H.SetBlackTexture(btn.tex)
	btn.tex:SetVertexColor(1, 1, 1, 1)
	btn.timeText:SetText("")
	btn.__bag = nil
	btn.__slot = nil
	btn.__itemId = nil
	btn.__empty = true
	btn:SetScript("OnClick", function()
		T.QueueOrUnequip(slotId)
		if not H.InCombat() and f then f:Hide() end
	end)
	btn:Show()
end

function T.UpdateDropdown(slotId)
	local f = T.dropdown[slotId]
	if not f then return end

	local items = T.GetBagTrinkets()

	for _, btn in ipairs(f.buttons) do
		btn:Hide()
		btn:SetScript("OnClick", nil)
		btn.__empty = nil
	end

	local width  = T.ICON_SIZE
	local totalButtons = #items + 1
	local height = (totalButtons * T.ICON_SIZE) + ((totalButtons - 1) * T.ICON_PAD)
	f:SetSize(width, height)

	ConfigureEmptyButton(slotId, f, 1)

	for i, it in ipairs(items) do
		local index = i + 1
		local btn = GetOrCreateDropdownButton(slotId, index)
		btn:ClearAllPoints()
		btn:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -((index - 1) * (T.ICON_SIZE + T.ICON_PAD)))
		btn.tex:SetTexture(it.icon or H.DEFAULT_ICON_FILEID)

		btn.__bag = it.bag
		btn.__slot = it.slot
		btn.__itemId = it.itemId
		btn.__empty = nil

		local cd = H.GetRemainingCooldownForBagSlot(it.bag, it.slot)
		if cd > 0 then
			btn.timeText:SetText(H.FormatTimeLeft(cd))
			btn.tex:SetVertexColor(0.55, 0.55, 0.55, 1)
		else
			btn.timeText:SetText("")
			btn.tex:SetVertexColor(1, 1, 1, 1)
		end

		btn:SetScript("OnClick", function()
			T.QueueOrEquip(slotId, it.itemId)
			if not H.InCombat() and f then f:Hide() end
		end)

		btn:Show()
	end

	f:Show()
end

function T.ShowDropdown(slotId, owner)
	if not T.dropdown[slotId] then CreateDropdownFrame(slotId) end
	CancelHide(slotId)

	local f = T.dropdown[slotId]
	f:ClearAllPoints()
	f:SetPoint("BOTTOMLEFT", owner, "TOPLEFT", 0, T.DROPDOWN_GAP)

	T.UpdateDropdown(slotId)
end

-- -------------------------------
-- Slot overlay logic (main icons)
-- -------------------------------
function T.UpdateSlotOverlay(slotId, btn)
	local now = GetTime()

	local itemId = GetInventoryItemID("player", slotId)
	local cfg = GetItemCfg(itemId)

	local text = ""
	local auraUp = false
	local isCooldown = false

	H.SetTimerColor(btn, 1, 1, 1, 1)

	-- 1) Aura active
	if cfg and cfg.buffSpellIds then
		local aura = nil
		for _, sid in ipairs(cfg.buffSpellIds) do
			if not T.IsAuraSpellAmbiguousForSlot(slotId, sid) then
				aura = H.GetPlayerAuraBySpellId(sid)
				if aura then break end
			end
		end
		if aura and aura.expirationTime and aura.expirationTime > 0 then
			local remain = aura.expirationTime - now
			if remain > 0 then
				text = H.FormatTimeLeft(remain)
				auraUp = true
				isCooldown = false
				H.SetTimerColor(btn, 0.25, 1.0, 0.25, 1)
			end
		end
	end

	-- 2) Real slot cooldown (covers the “just equipped” 30s)
	if text == "" then
		local cd = H.GetRemainingCooldownForInventorySlot(slotId)
		if cd > 0 then
			text = H.FormatTimeLeft(cd)
			isCooldown = true
		end
	end

	-- 3) ICD display
	if text == "" and cfg and cfg.kind == "proc" then
		local icdEnd = T.slotState[slotId].icdEnd or 0
		if icdEnd > now then
			text = H.FormatTimeLeft(icdEnd - now)
			isCooldown = true
		end
	end

	-- 4) Equip lockout (synthetic)
	if text == "" and itemId and ((cfg and (cfg.kind == "proc" or cfg.kind == "active")) or not cfg) then
		local lockEnd = T.slotState[slotId].equipLockoutEnd or 0
		if lockEnd > now then
			text = H.FormatTimeLeft(lockEnd - now)
			isCooldown = true
		end
	end

	btn.timeText:SetText(text)

	if cfg and cfg.kind == "passive" then
		auraUp = false
		isCooldown = false
		btn.timeText:SetText("")
		H.SetTimerColor(btn, 1, 1, 1, 1)
	end

	H.SetAuraOverlay(btn, auraUp)
	H.SetCooldownLook(btn, isCooldown and not auraUp)
end

function T.OnEquipmentChanged(slotId)
	if slotId ~= 13 and slotId ~= 14 then return end

	local now = GetTime()
	local itemId = GetInventoryItemID("player", slotId)
	local state = T.slotState[slotId]

	if state.queuedUnequip and not itemId then
		ClearQueue(slotId)
	elseif state.queuedItemId and state.queuedItemId == itemId then
		ClearQueue(slotId)
	end

	if state.lastEquippedItemId ~= itemId then
		local cfg = GetItemCfg(itemId)

		if itemId and ((cfg and (cfg.kind == "proc" or cfg.kind == "active")) or not cfg) then
			state.equipLockoutEnd = now + T.EQUIP_LOCKOUT_SECONDS
		else
			state.equipLockoutEnd = 0
		end

		state.icdEnd = 0
		state.lastEquippedItemId = itemId
	end

	if T.slotIcon[slotId] and T.slotIcon[slotId].UpdateIcon then
		T.slotIcon[slotId]:UpdateIcon()
	end
end

-- -------------------------------
-- Combat log ICD tracking
-- -------------------------------
local playerGUID

function T.SetPlayerGUID(guid)
	playerGUID = guid
end

local function IsSpellInCfgForEquipped(slotId, spellId)
	local itemId = GetInventoryItemID("player", slotId)
	local cfg = GetItemCfg(itemId)
	if not cfg or cfg.kind ~= "proc" or not cfg.buffSpellIds then return false, nil end
	for _, sid in ipairs(cfg.buffSpellIds) do
		if sid == spellId then return true, cfg end
	end
	return false, nil
end

function T.IsAuraSpellAmbiguousForSlot(slotId, spellId)
	local matches = 0
	for _, otherSlotId in ipairs(T.TRINKET_SLOTS) do
		local itemId = GetInventoryItemID("player", otherSlotId)
		local cfg = GetItemCfg(itemId)
		if cfg and cfg.buffSpellIds then
			for _, sid in ipairs(cfg.buffSpellIds) do
				if sid == spellId then
					matches = matches + 1
					break
				end
			end
		end
	end
	return matches > 1
end

function T.OnCombatLogEvent()
	local _, subEvent, _, _, _, _, _, destGUID, _, _, _, spellId = CombatLogGetCurrentEventInfo()
	if not playerGUID then return end
	if destGUID ~= playerGUID then return end

	if subEvent == "SPELL_AURA_APPLIED" or subEvent == "SPELL_AURA_REFRESH" then
		local now = GetTime()
		local matchingSlotId = nil
		local matchingCfg = nil
		local matches = 0
		for _, slotId in ipairs(T.TRINKET_SLOTS) do
			local ok, cfg = IsSpellInCfgForEquipped(slotId, spellId)
			if ok and cfg and cfg.icd and cfg.icd > 0 then
				matchingSlotId = slotId
				matchingCfg = cfg
				matches = matches + 1
			end
		end
		if matches == 1 then
			T.slotState[matchingSlotId].icdEnd = now + matchingCfg.icd
		end
	end
end

-- -------------------------------
-- Init state
-- -------------------------------
function T.InitSlotState()
	for _, slotId in ipairs(T.TRINKET_SLOTS) do
		T.slotState[slotId].lastEquippedItemId = GetInventoryItemID("player", slotId)
		T.slotState[slotId].equipLockoutEnd = 0
		T.slotState[slotId].icdEnd = 0
		ClearQueue(slotId)
	end
end
