-- Pure reminder evaluation. WoW API collection and secure buttons are wired later.

KravaCooldownTracker_ConsumableLogic = KravaCooldownTracker_ConsumableLogic or {}
local L = KravaCooldownTracker_ConsumableLogic

local function contains(values, wanted)
	return values and values[wanted] == true
end

local function itemStateIsActive(item, state)
	if item.auraSpellIds then
		local auras = item.target == "pet" and state.petAuras or state.playerAuras
		for _, spellId in ipairs(item.auraSpellIds) do
			if contains(auras, spellId) then return true end
		end
	end

	if item.enchantId then
		if item.inventorySlot then
			return state.equipmentEnchants
				and state.equipmentEnchants[item.inventorySlot] == item.enchantId
		end
		local enchants = state.weaponEnchants or {}
		if item.target == "mainhand" then return enchants.mainhand == item.enchantId end
		if item.target == "offhand" then return enchants.offhand == item.enchantId end
		if item.target == "weapon" then
			return enchants.mainhand == item.enchantId or enchants.offhand == item.enchantId
		end
	end

	return false
end

function L.IsItemActive(item, state)
	return itemStateIsActive(item, state or {})
end

function L.IsGroupSatisfied(group, state, catalog)
	for _, itemKey in ipairs(group.choices) do
		local item = catalog[itemKey]
		if item and itemStateIsActive(item, state or {}) then return true end
	end
	return false
end

function L.Evaluate(profile, state, catalog)
	local reminders = {}
	state = state or {}
	local flaskActive = false
	for _, group in ipairs(profile or {}) do
		if group.category == "flask" and L.IsGroupSatisfied(group, state, catalog) then
			flaskActive = true
			break
		end
	end
	for _, group in ipairs(profile or {}) do
		if group.perEquippedWeapon then
			for _, target in ipairs({ "mainhand", "offhand" }) do
				if state.equippedWeapons and state.equippedWeapons[target] then
					local satisfied = false
					for _, itemKey in ipairs(group.choices) do
						local item = catalog[itemKey]
						if item and state.weaponEnchants and state.weaponEnchants[target] == item.enchantId then
							satisfied = true
							break
						end
					end
					if not satisfied then
						for _, itemKey in ipairs(group.choices) do
							local item = catalog[itemKey]
							if item and (state.bagCounts and state.bagCounts[item.itemId] or 0) > 0 then
								reminders[#reminders + 1] = { group = group, itemKey = itemKey, item = item, target = target }
							end
						end
					end
				end
			end
		elseif group.target == "mainhand" or group.target == "offhand" then
			local target = group.target
			local satisfied = false
			for _, itemKey in ipairs(group.choices) do
				local item = catalog[itemKey]
				if item and state.weaponEnchants and state.weaponEnchants[target] == item.enchantId then satisfied = true; break end
			end
			if state.equippedWeapons and state.equippedWeapons[target] and not satisfied then
				for _, itemKey in ipairs(group.choices) do
					local item = catalog[itemKey]
					if item and (state.bagCounts and state.bagCounts[item.itemId] or 0) > 0 then
						reminders[#reminders + 1] = { group = group, itemKey = itemKey, item = item, target = target }
					end
				end
			end
		elseif not (flaskActive and (group.category == "battle" or group.category == "guardian"))
			and not (group.category == "food" and state.inCombat)
			and not L.IsGroupSatisfied(group, state, catalog)
		then
			for _, itemKey in ipairs(group.choices) do
				local item = catalog[itemKey]
				if item and (state.bagCounts and state.bagCounts[item.itemId] or 0) > 0 then
					reminders[#reminders + 1] = { group = group, itemKey = itemKey, item = item }
				end
			end
		end
	end
	return reminders
end

-- Runtime adapter/UI ---------------------------------------------------------
local Catalog = KravaCooldownTracker_Consumables
local Config = KravaCooldownTracker_Config
local Helpers = KravaCooldownTracker_Helpers
local frame, leftHandle, rightHandle
local buttons = {}
local pendingRefresh = false
local refreshScheduled = false
local MAX_BUTTONS = 24

local function inCombat()
	return Helpers and Helpers.InCombat and Helpers.InCombat()
end

local function getSpecIndex()
	if GetPrimaryTalentTree then
		local index = GetPrimaryTalentTree()
		if index and index > 0 then return index end
	end
	local bestIndex, bestPoints = 1, -1
	if GetNumTalentTabs and GetTalentTabInfo then
		for index = 1, GetNumTalentTabs() do
			local _, _, points = GetTalentTabInfo(index)
			if (points or 0) > bestPoints then bestIndex, bestPoints = index, points or 0 end
		end
	end
	return bestIndex
end

local function collectAuras(unit)
	local result = {}
	if not UnitExists(unit) then return result end
	for index = 1, 40 do
		local name, _, _, _, _, _, _, _, _, spellId = UnitAura(unit, index, "HELPFUL")
		if not name then break end
		if spellId then result[spellId] = true end
	end
	return result
end

local function collectBagCounts()
	local counts = {}
	for bag = 0, 4 do
		for slot = 1, Helpers.GetContainerNumSlots(bag) do
			local itemId = Helpers.GetContainerItemID(bag, slot)
			if itemId then
				local stackCount
				if C_Container and C_Container.GetContainerItemInfo then
					local info = C_Container.GetContainerItemInfo(bag, slot)
					stackCount = info and info.stackCount
				else
					local _, legacyStackCount = GetContainerItemInfo(bag, slot)
					stackCount = legacyStackCount
				end
				counts[itemId] = (counts[itemId] or 0) + (stackCount or 1)
			end
		end
	end
	return counts
end

local function linkContainsEnchant(slot, enchantId)
	local link = GetInventoryItemLink("player", slot)
	return link and link:find(":" .. tostring(enchantId) .. ":", 1, true) ~= nil or false
end

local function collectState()
	local state = {
		playerAuras = collectAuras("player"),
		petAuras = collectAuras("pet"),
		bagCounts = collectBagCounts(),
		weaponEnchants = {},
		equippedWeapons = {
			mainhand = GetInventoryItemID("player", 16) ~= nil,
			offhand = GetInventoryItemID("player", 17) ~= nil,
		},
		equipmentEnchants = {},
		inCombat = UnitAffectingCombat("player") and true or false,
	}
	for _, item in pairs(Catalog.ITEMS) do
		if item.inventorySlot and item.enchantId and linkContainsEnchant(item.inventorySlot, item.enchantId) then
			state.equipmentEnchants[item.inventorySlot] = item.enchantId
		end
	end
	if GetWeaponEnchantInfo then
		local mh, _, _, mhId, oh, _, _, ohId = GetWeaponEnchantInfo()
		if mh then state.weaponEnchants.mainhand = mhId end
		if oh then state.weaponEnchants.offhand = ohId end
	end
	return state
end

local function inRaidInstance()
	local inInstance, instanceType = IsInInstance()
	return inInstance and instanceType == "raid"
end

local function savePosition()
	local point, _, relativePoint, x, y = frame:GetPoint(1)
	KravaCooldownTrackerDB.consumablePos = {
		point = point, relPoint = relativePoint or point, x = x or 0, y = y or 0,
	}
end

local function restorePosition()
	local pos = KravaCooldownTrackerDB.consumablePos
	if pos and pos.point and pos.relPoint then
		frame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x or 0, pos.y or 0)
	else
		frame:SetPoint("CENTER", UIParent, "CENTER", 0, -70)
	end
end

local function setHandlesShown(shown)
	for _, handle in ipairs({ leftHandle, rightHandle }) do
		if handle then
			if shown then handle:Show() else handle:Hide() end
		end
	end
end

local function makeHandle(side)
	local handle = CreateFrame("Button", nil, frame)
	handle:SetSize(22, 32)
	handle:SetPoint(side == "Left" and "RIGHT" or "LEFT", frame, side == "Left" and "LEFT" or "RIGHT", side == "Left" and -3 or 3, 0)
	handle:RegisterForDrag("LeftButton")
	handle:EnableMouse(true)
	handle.texture = handle:CreateTexture(nil, "ARTWORK")
	handle.texture:SetAllPoints()
	Helpers.SetSquareOverlayTexture(handle.texture, 0.38, 0.45, 0.42, 1)
	handle:SetScript("OnDragStart", function()
		if not inCombat() and not Config.Get().consumableLocked then frame:StartMoving() end
	end)
	handle:SetScript("OnDragStop", function()
		if inCombat() then return end
		frame:StopMovingOrSizing()
		savePosition()
	end)
	return handle
end

local function configureButton(button, reminder, size, index, cfg)
	local item = reminder.item
	local target = reminder.target or item.target
	button:SetSize(size, size)
	button:ClearAllPoints()
	button:SetPoint("LEFT", frame, "LEFT", (index - 1) * size, 0)
	button.icon:SetTexture(Helpers.GetItemIcon(item.itemId))
	button.itemId = item.itemId
	button.label:SetText(target == "mainhand" and "MH" or target == "offhand" and "OH" or target == "chest" and "CHEST" or "")
	button.label:SetFont(cfg.fontFace or STANDARD_TEXT_FONT, cfg.consumableFontSize or 14, "OUTLINE")
	if not inCombat() then
		button:SetAttribute("type", nil)
		button:SetAttribute("item", nil)
		button:SetAttribute("macrotext", nil)
		button:SetAttribute("type1", nil)
		button:SetAttribute("item1", nil)
		button:SetAttribute("macrotext1", nil)
		button:SetAttribute("unit", nil)
		button:SetAttribute("target-slot", nil)
		if target == "mainhand" or target == "offhand" or target == "chest" then
			local slot = target == "mainhand" and 16 or target == "offhand" and 17 or 5
			local itemName = GetItemInfo(item.itemId)
			button:SetAttribute("type1", "item")
			button:SetAttribute("item", itemName or ("item:" .. item.itemId))
			button:SetAttribute("target-slot", tostring(slot))
		else
			button:SetAttribute("type1", "item")
			button:SetAttribute("item", "item:" .. item.itemId)
			if target == "pet" then button:SetAttribute("unit", "pet") end
		end
	end
	button:Show()
end

function L.RefreshRuntime()
	if not frame or not Catalog or not Config then return end
	if inCombat() then
		pendingRefresh = true
		return
	end
	local cfg = Config.Get()
	local enabled = Config.IsFeatureEnabled("consumables")
	if not enabled or (cfg.consumableRaidOnly and not inRaidInstance()) then
		frame:Hide()
		setHandlesShown(false)
		return
	end
	local _, classToken = UnitClass("player")
	local profile = Catalog.GetProfile(classToken, getSpecIndex())
	local reminders = L.Evaluate(profile, collectState(), Catalog.ITEMS)
	local size = cfg.consumableIconSize or 32
	for index, reminder in ipairs(reminders) do
		local button = buttons[index]
		if button then configureButton(button, reminder, size, index, cfg) end
	end
	for index = #reminders + 1, #buttons do buttons[index]:Hide() end
	frame:SetSize(math.max(1, #reminders * size), size)
	leftHandle:SetSize(22, size)
	rightHandle:SetSize(22, size)
	local unlocked = not cfg.consumableLocked and not inCombat()
	setHandlesShown(unlocked)
	if #reminders > 0 or unlocked then frame:Show() else frame:Hide() end
end

local function createButton(index)
	local button = CreateFrame("Button", "KravaCooldownTrackerConsumable" .. index, frame, "SecureActionButtonTemplate")
	local leftClick = GetCVarBool and GetCVarBool("ActionButtonUseKeyDown") and "LeftButtonDown" or "LeftButtonUp"
	button:RegisterForClicks(leftClick, "RightButtonUp")
	button:SetAttribute("type2", "")
	button.icon = button:CreateTexture(nil, "ARTWORK")
	button.icon:SetAllPoints()
	button.icon:SetTexCoord(Helpers.CROP, 1 - Helpers.CROP, Helpers.CROP, 1 - Helpers.CROP)
	button.label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	button.label:SetPoint("CENTER", button, "CENTER", 0, 0)
	button:SetScript("OnEnter", function(self)
		if self.itemId then GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetHyperlink("item:" .. self.itemId); GameTooltip:Show() end
	end)
	button:SetScript("OnLeave", function() GameTooltip:Hide() end)
	button:HookScript("OnClick", function(_, mouseButton)
		if mouseButton ~= "RightButton" or inCombat() then return end
		Config.Set("consumableLocked", not Config.Get().consumableLocked)
		Config.RefreshChanged()
	end)
	button:Hide()
	return button
end

function L.InitializeRuntime()
	if frame or not UIParent then return end
	frame = CreateFrame("Frame", "KravaCooldownTrackerConsumableContainer", UIParent)
	frame:SetSize(32, 32)
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:SetUserPlaced(true)
	restorePosition()
	for index = 1, MAX_BUTTONS do buttons[index] = createButton(index) end
	leftHandle = makeHandle("Left")
	rightHandle = makeHandle("Right")
	L.RefreshRuntime()
end

function L.ScheduleRefresh()
	if refreshScheduled then return end
	refreshScheduled = true
	local function run()
		refreshScheduled = false
		L.RefreshRuntime()
	end
	if C_Timer and C_Timer.After then C_Timer.After(0.05, run) else run() end
end

if CreateFrame then
	local events = CreateFrame("Frame")
	for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_TALENT_UPDATE", "ACTIVE_TALENT_GROUP_CHANGED", "UNIT_AURA", "UNIT_PET", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
		pcall(events.RegisterEvent, events, event)
	end
	events:SetScript("OnEvent", function(_, event, unit)
		if event == "PLAYER_LOGIN" then L.InitializeRuntime(); return end
		if event == "UNIT_AURA" and unit ~= "player" and unit ~= "pet" then return end
		if event == "UNIT_PET" and unit ~= "player" then return end
		if event == "PLAYER_REGEN_ENABLED" then pendingRefresh = false end
		L.ScheduleRefresh()
	end)
end
