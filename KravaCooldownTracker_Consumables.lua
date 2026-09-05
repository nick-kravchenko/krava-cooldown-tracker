-- Persistent raid-consumable catalog and class/spec profiles.
-- effectSpellId is the item's on-use effect; auraSpellIds/enchantId detect completion.

KravaCooldownTracker_Consumables = KravaCooldownTracker_Consumables or {}
local K = KravaCooldownTracker_Consumables

local function item(name, itemId, effectSpellId, auraSpellIds, category, source, extra)
	local value = {
		name = name,
		itemId = itemId,
		effectSpellId = effectSpellId,
		auraSpellIds = auraSpellIds,
		category = category,
		target = "player",
		source = source,
	}
	for key, entry in pairs(extra or {}) do value[key] = entry end
	return value
end

local WOWHEAD = "https://www.wowhead.com/tbc/item="
K.ITEMS = {
	flask_assault = item("Flask of Relentless Assault", 22854, 28520, { 28520 }, "flask", WOWHEAD .. "22854"),
	flask_blinding = item("Flask of Blinding Light", 22861, 28521, { 28521 }, "flask", WOWHEAD .. "22861"),
	flask_pure_death = item("Flask of Pure Death", 22866, 28540, { 28540 }, "flask", WOWHEAD .. "22866"),
	flask_fortification = item("Flask of Fortification", 22851, 28518, { 28518 }, "flask", WOWHEAD .. "22851"),
	flask_restoration = item("Flask of Mighty Restoration", 22853, 28519, { 28519 }, "flask", WOWHEAD .. "22853"),
	flask_chromatic = item("Flask of Chromatic Wonder", 33208, 42735, { 42735 }, "flask", WOWHEAD .. "33208"),
	flask_distilled = item("Flask of Distilled Wisdom", 13511, 17627, { 17627 }, "flask", WOWHEAD .. "13511"),
	flask_supreme = item("Flask of Supreme Power", 13512, 17628, { 17628 }, "flask", WOWHEAD .. "13512"),
	flask_shattrath_fortification = item("Shattrath Flask of Fortification", 32898, 41609, { 41609 }, "flask", WOWHEAD .. "32898"),
	flask_shattrath_restoration = item("Shattrath Flask of Mighty Restoration", 32899, 41610, { 41610 }, "flask", WOWHEAD .. "32899"),
	flask_shattrath_supreme = item("Shattrath Flask of Supreme Power", 32900, 41611, { 41611 }, "flask", WOWHEAD .. "32900"),
	flask_shattrath_assault = item("Shattrath Flask of Relentless Assault", 32901, 41608, { 41608 }, "flask", WOWHEAD .. "32901"),
	flask_shattrath_pure_death = item("Shattrath Flask of Pure Death", 35716, 46837, { 46837 }, "flask", WOWHEAD .. "35716"),
	flask_shattrath_blinding = item("Shattrath Flask of Blinding Light", 35717, 46839, { 46839 }, "flask", WOWHEAD .. "35717"),

	elixir_agility = item("Elixir of Major Agility", 22831, 28497, { 28497 }, "battle", WOWHEAD .. "22831"),
	elixir_adept = item("Adept's Elixir", 28103, 33721, { 33721 }, "battle", WOWHEAD .. "28103"),
	elixir_healing = item("Elixir of Healing Power", 22825, 28491, { 28491 }, "battle", WOWHEAD .. "22825"),
	elixir_arcane = item("Greater Arcane Elixir", 13454, 17539, { 17539 }, "battle", WOWHEAD .. "13454"),
	elixir_shadow = item("Elixir of Major Shadow Power", 22835, 28503, { 28503 }, "battle", WOWHEAD .. "22835"),
	elixir_fire = item("Elixir of Major Firepower", 22833, 28501, { 28501 }, "battle", WOWHEAD .. "22833"),
	elixir_demonslaying = item("Elixir of Demonslaying", 9224, 11406, { 11406 }, "battle", WOWHEAD .. "9224"),
	elixir_mongoose = item("Elixir of the Mongoose", 13452, 17538, { 17538 }, "battle", WOWHEAD .. "13452"),
	elixir_wisdom = item("Elixir of Draenic Wisdom", 32067, 39627, { 39627 }, "guardian", WOWHEAD .. "32067"),
	elixir_mageblood = item("Elixir of Major Mageblood", 22840, 28509, { 28509 }, "guardian", WOWHEAD .. "22840"),
	elixir_gift = item("Gift of Arthas", 9088, 11371, { 11371 }, "guardian", WOWHEAD .. "9088"),
	elixir_zanza = item("Spirit of Zanza", 20079, 24382, { 24382 }, "guardian", WOWHEAD .. "20079"),

	food_spell = item("Blackened Basilisk", 27657, 33264, { 33263 }, "food", WOWHEAD .. "27657", { outOfCombatOnly = true }),
	food_spell_serpent = item("Crunchy Serpent", 31673, 33264, { 33263 }, "food", WOWHEAD .. "31673", { outOfCombatOnly = true }),
	food_spell_fish = item("Poached Bluefish", 27665, 33264, { 33263 }, "food", WOWHEAD .. "27665", { outOfCombatOnly = true }),
	food_agility = item("Warp Burger", 27659, 33262, { 33261 }, "food", WOWHEAD .. "27659", { outOfCombatOnly = true }),
	food_agility_fish = item("Grilled Mudfish", 27664, 33262, { 33261 }, "food", WOWHEAD .. "27664", { outOfCombatOnly = true }),
	food_strength = item("Roasted Clefthoof", 27658, 33260, { 33256 }, "food", WOWHEAD .. "27658", { outOfCombatOnly = true }),
	food_stamina = item("Fisherman's Feast", 33052, 33258, { 33257 }, "food", WOWHEAD .. "33052", { outOfCombatOnly = true }),
	food_stamina_crawdad = item("Spicy Crawdad", 27667, 33258, { 33257 }, "food", WOWHEAD .. "27667", { outOfCombatOnly = true }),
	food_healing = item("Golden Fish Sticks", 27666, 33268, { 33265 }, "food", WOWHEAD .. "27666", { outOfCombatOnly = true }),
	food_crit = item("Skullfish Soup", 33825, 43763, { 43764 }, "food", WOWHEAD .. "33825", { outOfCombatOnly = true }),
	food_hit = item("Dark Desire", 22237, 27723, { 27723 }, "food", WOWHEAD .. "22237", { outOfCombatOnly = true }),

	food_pet_kibler = item("Kibler's Bits", 33874, 43771, { 43771 }, "food", WOWHEAD .. "33874", { target = "pet", outOfCombatOnly = true }),
	food_pet_sporeling = item("Sporeling Snack", 27656, 33272, { 33272 }, "food", WOWHEAD .. "27656", { target = "pet", outOfCombatOnly = true }),

	scroll_agility = item("Scroll of Agility V", 27498, 33077, { 33077 }, "scroll", WOWHEAD .. "27498"),
	scroll_strength = item("Scroll of Strength V", 27503, 33082, { 33082 }, "scroll", WOWHEAD .. "27503"),
	scroll_protection = item("Scroll of Protection V", 27500, 33079, { 33079 }, "scroll", WOWHEAD .. "27500"),
	scroll_spirit = item("Scroll of Spirit V", 27501, 33080, { 33080 }, "scroll", WOWHEAD .. "27501"),

	oil_brilliant_wizard = item("Brilliant Wizard Oil", 20749, 25122, nil, "weapon", WOWHEAD .. "20749", { enchantId = 2628, target = "mainhand" }),
	oil_superior_wizard = item("Superior Wizard Oil", 22522, 28898, nil, "weapon", WOWHEAD .. "22522", { enchantId = 2678, target = "mainhand" }),
	oil_brilliant_mana = item("Brilliant Mana Oil", 20748, 25123, nil, "weapon", WOWHEAD .. "20748", { enchantId = 2629, target = "mainhand" }),
	stone_adamantite_sharp = item("Adamantite Sharpening Stone", 23529, 28891, nil, "weapon", WOWHEAD .. "23529", { enchantId = 2713, target = "weapon" }),
	stone_adamantite_weight = item("Adamantite Weightstone", 28421, 34340, nil, "weapon", WOWHEAD .. "28421", { enchantId = 2955, target = "weapon" }),
	rune_greater_warding = item("Greater Rune of Warding", 25521, 32282, nil, "armor", WOWHEAD .. "25521", { enchantId = 2791, target = "chest", inventorySlot = 5 }),
}

local function group(key, category, choices, extra)
	local value = { key = key, category = category, choices = choices }
	for field, entry in pairs(extra or {}) do value[field] = entry end
	return value
end

local G = {
	assault = group("flask", "flask", { "flask_assault", "flask_shattrath_assault" }),
	blinding = group("flask", "flask", { "flask_blinding", "flask_shattrath_blinding", "flask_supreme", "flask_shattrath_supreme" }),
	pureDeath = group("flask", "flask", { "flask_pure_death", "flask_shattrath_pure_death", "flask_supreme", "flask_shattrath_supreme" }),
	healingFlask = group("flask", "flask", { "flask_restoration", "flask_shattrath_restoration", "flask_distilled" }),
	tankFlask = group("flask", "flask", { "flask_fortification", "flask_shattrath_fortification", "flask_chromatic" }),
	agilityBattle = group("battle", "battle", { "elixir_agility" }),
	casterBattle = group("battle", "battle", { "elixir_adept" }),
	healingBattle = group("battle", "battle", { "elixir_healing" }),
	arcaneBattle = group("battle", "battle", { "elixir_arcane" }),
	shadowBattle = group("battle", "battle", { "elixir_shadow" }),
	fireBattle = group("battle", "battle", { "elixir_fire" }),
	physicalBattle = group("battle", "battle", { "elixir_agility", "elixir_mongoose", "elixir_demonslaying" }),
	wisdomGuardian = group("guardian", "guardian", { "elixir_wisdom", "elixir_mageblood" }),
	tankGuardian = group("guardian", "guardian", { "elixir_gift", "elixir_zanza" }),
	spellFood = group("food", "food", { "food_spell", "food_spell_serpent", "food_spell_fish" }),
	agilityFood = group("food", "food", { "food_agility", "food_agility_fish", "food_hit" }),
	strengthFood = group("food", "food", { "food_strength" }),
	staminaFood = group("food", "food", { "food_stamina", "food_stamina_crawdad" }),
	healingFood = group("food", "food", { "food_healing", "food_crit" }),
	petFood = group("pet_food", "food", { "food_pet_kibler", "food_pet_sporeling" }, { requiresPet = true }),
	wizardOil = group("mainhand", "weapon", { "oil_brilliant_wizard", "oil_superior_wizard" }),
	manaOil = group("mainhand", "weapon", { "oil_brilliant_mana", "oil_superior_wizard" }),
	stone = group("weapon", "weapon", { "stone_adamantite_sharp", "stone_adamantite_weight" }, { perEquippedWeapon = true }),
	offhandStone = group("offhand", "weapon", { "stone_adamantite_sharp", "stone_adamantite_weight" }, { target = "offhand" }),
	greaterRuneOfWarding = group("chest", "armor", { "rune_greater_warding" }),
	agilityScroll = group("agility_scroll", "scroll", { "scroll_agility" }),
	strengthScroll = group("strength_scroll", "scroll", { "scroll_strength" }),
	protectionScroll = group("protection_scroll", "scroll", { "scroll_protection" }),
	spiritScroll = group("spirit_scroll", "scroll", { "scroll_spirit" }),
}

local function profile(...)
	return { ... }
end

K.PROFILES = {
	DRUID = {
		[1] = profile(G.blinding, G.casterBattle, G.wisdomGuardian, G.spellFood, G.wizardOil, G.spiritScroll),
		[2] = profile(G.assault, G.agilityBattle, G.wisdomGuardian, G.agilityFood, G.stone, G.agilityScroll, G.strengthScroll),
		[3] = profile(G.healingFlask, G.healingBattle, G.wisdomGuardian, G.healingFood, G.manaOil, G.spiritScroll, G.protectionScroll),
	},
	HUNTER = { default = profile(G.petFood, G.assault, G.agilityBattle, G.wisdomGuardian, G.agilityFood, G.stone, G.agilityScroll, G.strengthScroll) },
	MAGE = {
		[1] = profile(G.blinding, G.casterBattle, G.wisdomGuardian, G.spellFood, G.wizardOil, G.spiritScroll, G.protectionScroll),
		[2] = profile(G.pureDeath, G.fireBattle, G.wisdomGuardian, G.spellFood, G.wizardOil, G.spiritScroll, G.protectionScroll),
		[3] = profile(G.pureDeath, G.casterBattle, G.wisdomGuardian, G.spellFood, G.wizardOil, G.spiritScroll, G.protectionScroll),
	},
	PALADIN = {
		[1] = profile(G.healingFlask, G.healingBattle, G.wisdomGuardian, G.healingFood, G.wizardOil, G.spiritScroll),
		[2] = profile(G.tankFlask, G.arcaneBattle, G.tankGuardian, G.staminaFood, G.wizardOil, G.greaterRuneOfWarding, G.agilityScroll, G.protectionScroll),
		[3] = profile(G.assault, G.physicalBattle, G.wisdomGuardian, G.strengthFood, G.agilityScroll, G.strengthScroll, G.protectionScroll),
	},
	PRIEST = {
		[1] = profile(G.healingFlask, G.healingBattle, G.wisdomGuardian, G.healingFood, G.manaOil, G.spiritScroll, G.protectionScroll),
		[2] = profile(G.healingFlask, G.healingBattle, G.wisdomGuardian, G.healingFood, G.manaOil, G.spiritScroll, G.protectionScroll),
		[3] = profile(G.pureDeath, G.shadowBattle, G.wisdomGuardian, G.spellFood, G.wizardOil, G.spiritScroll, G.protectionScroll),
	},
	ROGUE = { default = profile(G.assault, G.physicalBattle, G.wisdomGuardian, G.agilityFood, G.stone, G.agilityScroll, G.strengthScroll) },
	SHAMAN = {
		[1] = profile(G.blinding, G.casterBattle, G.wisdomGuardian, G.spellFood, G.wizardOil),
		[2] = profile(G.assault, G.physicalBattle, G.wisdomGuardian, G.strengthFood),
		[3] = profile(G.healingFlask, G.healingBattle, G.wisdomGuardian, G.healingFood, G.manaOil),
	},
	WARLOCK = { default = profile(G.petFood, G.pureDeath, G.shadowBattle, G.fireBattle, G.wisdomGuardian, G.spellFood, G.wizardOil) },
	WARRIOR = {
		[1] = profile(G.assault, G.physicalBattle, G.wisdomGuardian, G.strengthFood, G.offhandStone, G.agilityScroll, G.strengthScroll, G.protectionScroll),
		[2] = profile(G.assault, G.physicalBattle, G.wisdomGuardian, G.strengthFood, G.offhandStone, G.agilityScroll, G.strengthScroll, G.protectionScroll),
		[3] = profile(G.tankFlask, G.agilityBattle, G.tankGuardian, G.staminaFood, G.greaterRuneOfWarding, G.agilityScroll, G.strengthScroll, G.protectionScroll),
	},
}

function K.GetProfile(classToken, specIndex)
	local classProfiles = K.PROFILES[classToken]
	if not classProfiles then return nil end
	return classProfiles[specIndex] or classProfiles.default or classProfiles[1]
end

function K.GetItem(itemKey)
	return K.ITEMS[itemKey]
end
