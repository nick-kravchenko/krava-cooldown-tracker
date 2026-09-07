-- Pure reminder evaluation. WoW API collection and secure buttons are wired later.

KravaCooldownTracker_ConsumableLogic = KravaCooldownTracker_ConsumableLogic or {}
local L = KravaCooldownTracker_ConsumableLogic

local function contains(values, wanted)
	return values and values[wanted] == true
end

local function itemStateIsActive(item, state)
	if item.auraSpellIds then
		local auras = state.playerAuras
		if item.target == "pet" then auras = state.petAuras end
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
	-- Alchemy slots are shared across profiles, including buffs not recommended
	-- for the current spec. Never suggest replacing an occupied slot.
	local alchemy = {}
	for _, item in pairs(catalog) do
		if (item.category == "flask" or item.category == "battle" or item.category == "guardian")
			and itemStateIsActive(item, state) then
			alchemy[item.category] = true
		end
	end
	for _, group in ipairs(profile or {}) do
		local eatingKey
		if group.category == "food" and not group.requiresPet and not state.inCombat then
			for _, key in ipairs(group.choices) do
				if state.eating and state.eating[key] then
					eatingKey = eatingKey or key
					if (state.bagCounts and state.bagCounts[catalog[key].itemId] or 0) > 0 then eatingKey = key; break end
				end
			end
		end
		if eatingKey then
			reminders[#reminders + 1] = { group = group, itemKey = eatingKey, item = catalog[eatingKey] }
		elseif group.perEquippedWeapon then
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
		elseif not (group.category == "flask" and (alchemy.flask or alchemy.battle or alchemy.guardian))
			and not ((group.category == "battle" or group.category == "guardian") and (alchemy.flask or alchemy[group.category]))
			and not (group.requiresPet and not state.petAvailable)
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

function L.GetSpecIndex()
	-- Anniversary's GetPrimaryTalentTree compatibility shim can always return 1.
	-- Select the tree with the most spent points in the active talent group.
	local specAPI = C_SpecializationInfo
	local activeGroup
	if specAPI and specAPI.GetActiveSpecGroup then
		activeGroup = specAPI.GetActiveSpecGroup()
	elseif GetActiveTalentGroup then
		activeGroup = GetActiveTalentGroup()
	end
	local numTabs = GetNumTalentTabs and GetNumTalentTabs(false, false)
	if not numTabs and specAPI and specAPI.GetNumSpecializations then
		numTabs = specAPI.GetNumSpecializations()
	end
	local bestIndex, bestPoints = 1, -1
	for index = 1, numTabs or 3 do
		local points
		if specAPI and specAPI.GetSpecializationInfo then
			local _, _, _, _, _, _, spent = specAPI.GetSpecializationInfo(index, false, false, nil, nil, activeGroup)
			points = spent
		end
		if type(points) ~= "number" and GetTalentTabInfo then
			local _, _, legacyPoints, _, spent = GetTalentTabInfo(index, false, false, activeGroup)
			points = type(spent) == "number" and spent or legacyPoints
		end
		if type(points) == "number" and points > bestPoints then
			bestIndex, bestPoints = index, points
		end
	end
	return bestIndex
end

function L.GetDetectedSpecLabel()
	local className = UnitClass("player") or "Unknown class"
	local index = L.GetSpecIndex()
	local specName
	if C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo then
		local _, name = C_SpecializationInfo.GetSpecializationInfo(index)
		specName = name
	end
	if not specName and GetTalentTabInfo then
		local first, second = GetTalentTabInfo(index)
		specName = type(first) == "string" and first or second
	end
	return className .. " " .. (specName or ("Unknown spec (" .. index .. ")"))
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

function L.GetEatingAura(item)
	if item.category ~= "food" or item.target == "pet" then return nil end
	local spellId = item.effectSpellId
	local getItemSpell = C_Item and C_Item.GetItemSpell or GetItemSpell
	if getItemSpell then
		local _, id = getItemSpell(item.itemId)
		spellId = id or spellId
	end
	local aura = Helpers.GetPlayerAuraBySpellId(spellId)
	if aura and (aura.duration or 0) > 0 and aura.duration <= 60
		and (aura.expirationTime or 0) > GetTime() then return aura end
end

function L.GetIconTimer(item)
	local aura = L.GetEatingAura(item)
	if aura then return aura.expirationTime - aura.duration, aura.duration, "food" end
	if item.category == "flask" or item.category == "battle" or item.category == "guardian" then
		local getCooldown = C_Container and C_Container.GetItemCooldown or GetItemCooldown
		if getCooldown then
			local start, duration, enabled = getCooldown(item.itemId)
			if enabled ~= 0 and start and duration and duration > 0 and start + duration > GetTime() then
				return start, duration, "cooldown"
			end
		end
	end
	return 0, 0
end

local function collectState()
	local state = {
		eating = {},
		playerAuras = collectAuras("player"),
		petAuras = collectAuras("pet"),
		petAvailable = UnitExists("pet") and not UnitIsDeadOrGhost("pet"),
		bagCounts = collectBagCounts(),
		weaponEnchants = {},
		equippedWeapons = {
			mainhand = GetInventoryItemID("player", 16) ~= nil,
			offhand = GetInventoryItemID("player", 17) ~= nil,
		},
		equipmentEnchants = {},
		inCombat = UnitAffectingCombat("player") and true or false,
	}
	for key, item in pairs(Catalog.ITEMS) do
		if L.GetEatingAura(item) then state.eating[key] = true end
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

local function updateButtonTimer(button)
	if not button.item then return end
	local start, duration, kind = L.GetIconTimer(button.item)
	if start ~= button.timerStart or duration ~= button.timerDuration then
		button.cooldown:SetCooldown(start, duration)
		button.timerStart, button.timerDuration = start, duration
	end
	local remaining = start + duration - GetTime()
	button.timeText:SetText(duration > 0 and Helpers.FormatTimeLeft(math.max(0, remaining)) or "")
	button.timeText:SetTextColor(kind == "food" and 0.3 or 1, 1, kind == "food" and 0.3 or 1)
	if button.wasEating and kind ~= "food" then L.ScheduleRefresh() end
	button.wasEating = kind == "food"
end

local function configureButton(button, reminder, size, index, cfg)
	local item = reminder.item
	local target = reminder.target or item.target
	button:SetSize(size, size)
	button:ClearAllPoints()
	button:SetPoint("LEFT", frame, "LEFT", (index - 1) * size, 0)
	button.icon:SetTexture(Helpers.GetItemIcon(item.itemId))
	button.itemId = item.itemId
	button.item = item
	button.timeText:SetFont(cfg.fontFace or STANDARD_TEXT_FONT, cfg.consumableFontSize or 14, "OUTLINE")
	updateButtonTimer(button)
	button.label:SetText(target == "mainhand" and "MH" or target == "offhand" and "OH" or target == "chest" and "CHEST" or target == "pet" and "PET" or "")
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
	local profile = Catalog.GetProfile(classToken, L.GetSpecIndex())
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
	button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
	button.cooldown:SetAllPoints()
	button.cooldown:SetHideCountdownNumbers(true)
	button.timerOverlay = CreateFrame("Frame", nil, button)
	button.timerOverlay:SetAllPoints()
	button.timerOverlay:SetFrameLevel(button.cooldown:GetFrameLevel() + 1)
	button.timeText = button.timerOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	button.timeText:SetPoint("CENTER", button, "CENTER", 0, 0)
	button:SetScript("OnUpdate", function(self, elapsed)
		self.timerElapsed = (self.timerElapsed or 0) + elapsed
		if self.timerElapsed < 0.1 then return end
		self.timerElapsed = 0
		updateButtonTimer(self)
	end)
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
	for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "BAG_UPDATE_DELAYED", "BAG_UPDATE_COOLDOWN", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_TALENT_UPDATE", "ACTIVE_TALENT_GROUP_CHANGED", "UNIT_AURA", "UNIT_PET", "UNIT_HEALTH", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
		pcall(events.RegisterEvent, events, event)
	end
	events:SetScript("OnEvent", function(_, event, unit)
		if event == "PLAYER_LOGIN" then L.InitializeRuntime(); return end
		if event == "UNIT_AURA" and unit ~= "player" and unit ~= "pet" then return end
		if event == "UNIT_PET" and unit ~= "player" then return end
		if event == "UNIT_HEALTH" and unit ~= "pet" then return end
		if event == "PLAYER_REGEN_ENABLED" then pendingRefresh = false end
		L.ScheduleRefresh()
	end)
end
