-- KravaCooldownTracker_Helpers.lua
-- Common helpers used across the addon.

KravaCooldownTracker_Helpers = KravaCooldownTracker_Helpers or {}
local H = KravaCooldownTracker_Helpers

H.DEFAULT_ICON_FILEID = 134400 -- INV_Misc_QuestionMark
H.CROP = 0.08

-- -------------------------------
-- Combat / time
-- -------------------------------
function H.InCombat()
	return (InCombatLockdown and InCombatLockdown()) or UnitAffectingCombat("player")
end

function H.FormatTimeLeft(t)
	if not t or t <= 0 then return "" end
	if t < 10 then
		return string.format("%.1f", t)
	elseif t < 60 then
		return string.format("%d", math.floor(t + 0.5))
	else
		local m = math.floor(t / 60)
		local s = math.floor(t % 60)
		return string.format("%d:%02d", m, s)
	end
end

-- -------------------------------
-- Aura helpers (spellId-based)
-- -------------------------------
function H.GetPlayerAuraBySpellId(spellId)
	if not spellId then return nil end

	if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
		return C_UnitAuras.GetPlayerAuraBySpellID(spellId)
	end

	for i = 1, 40 do
		local name, icon, count, debuffType, duration, expirationTime, source, isStealable,
		nameplateShowPersonal, auraSpellId = UnitAura("player", i, "HELPFUL")
		if not name then break end
		if auraSpellId == spellId then
			return {
				name = name,
				icon = icon,
				applications = count,
				duration = duration,
				expirationTime = expirationTime,
				sourceUnit = source,
				spellId = auraSpellId,
			}
		end
	end

	return nil
end

function H.FindFirstAura(buffSpellIds)
	if not buffSpellIds then return nil end
	for _, sid in ipairs(buffSpellIds) do
		local a = H.GetPlayerAuraBySpellId(sid)
		if a then return a end
	end
	return nil
end

-- -------------------------------
-- Container API compatibility
-- -------------------------------
local Cc = C_Container

function H.GetContainerNumSlots(bag)
	if Cc and Cc.GetContainerNumSlots then return Cc.GetContainerNumSlots(bag) end
	return GetContainerNumSlots(bag)
end

function H.GetContainerItemID(bag, slot)
	if Cc and Cc.GetContainerItemID then return Cc.GetContainerItemID(bag, slot) end
	return GetContainerItemID(bag, slot)
end

function H.GetItemIcon(itemId)
	if not itemId then return H.DEFAULT_ICON_FILEID end
	if C_Item and C_Item.GetItemIconByID then
		local icon = C_Item.GetItemIconByID(itemId)
		if icon then return icon end
	end
	if GetItemIcon then
		local icon = GetItemIcon(itemId)
		if icon then return icon end
	end
	if GetItemInfoInstant then
		local _, _, _, _, icon = GetItemInfoInstant(itemId)
		if icon then return icon end
	end
	local _, _, _, _, _, _, _, _, _, icon = GetItemInfo(itemId)
	return icon or H.DEFAULT_ICON_FILEID
end

function H.GetContainerItemCooldown(bag, slot)
	if C_Container and C_Container.GetContainerItemCooldown then
		return C_Container.GetContainerItemCooldown(bag, slot)
	end
	if GetContainerItemCooldown then
		return GetContainerItemCooldown(bag, slot)
	end
	return 0, 0, 0
end

-- -------------------------------
-- Cooldown helpers
-- -------------------------------
function H.GetRemainingCooldownForBagSlot(bag, slot)
	if bag == nil or slot == nil then return 0 end

	local start, duration, enable = H.GetContainerItemCooldown(bag, slot)
	if enable == 0 or not start or not duration or duration <= 0 then return 0 end

	local now = GetTime()
	local remain = (start + duration) - now
	if remain < 0 then remain = 0 end
	return remain
end

function H.GetRemainingCooldownForInventorySlot(slotId)
	local start, duration, enable = GetInventoryItemCooldown("player", slotId)
	if enable == 0 or not start or not duration or duration <= 0 then return 0 end
	local now = GetTime()
	local remain = (start + duration) - now
	if remain < 0 then remain = 0 end
	return remain
end

-- -------------------------------
-- UI visuals helpers
-- -------------------------------
function H.SetCooldownLook(btn, on)
	if not btn or not btn.icon then return end

	if btn.icon.SetDesaturated then
		btn.icon:SetDesaturated(on and true or false)
	end

	if on then
		btn.icon:SetVertexColor(0.55, 0.55, 0.55, 1)
	else
		btn.icon:SetVertexColor(1, 1, 1, 1)
	end
end

function H.SetAuraOverlay(btn, on)
	if not btn or not btn.auraOverlay then return end
	if on then btn.auraOverlay:Show() else btn.auraOverlay:Hide() end
end

function H.SetTimerColor(btn, r, g, b, a)
	if not btn or not btn.timeText then return end
	btn.timeText:SetTextColor(r or 1, g or 1, b or 1, a or 1)
end

function H.SetBlackTexture(texture)
	if not texture then return end
	if texture.SetColorTexture then
		texture:SetColorTexture(0, 0, 0, 1)
	else
		texture:SetTexture(0, 0, 0, 1)
	end
end

function H.SetSquareOverlayTexture(texture, r, g, b, a)
	if not texture then return end
	if texture.SetColorTexture then
		texture:SetColorTexture(r, g, b, a)
	else
		texture:SetTexture(r, g, b, a)
	end
end
