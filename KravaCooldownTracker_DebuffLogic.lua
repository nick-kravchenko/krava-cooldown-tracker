-- KravaCooldownTracker_DebuffLogic.lua

KravaCooldownTracker_DebuffLogic = KravaCooldownTracker_DebuffLogic or {}
local D = KravaCooldownTracker_DebuffLogic
local H = KravaCooldownTracker_Helpers

-- -------------------------------
-- Fixed debuff table (order matters for grid layout).
-- The `key` order MUST stay in sync with DEBUFF_KEYS in
-- KravaCooldownTracker_Config.lua.
-- -------------------------------
D.DEBUFFS = {
	{ key = "majorArmorReduction",   displayName = "Major Armor Reduction",     iconSpellId = 7386,  names = { "Sunder Armor", "Expose Armor" } },
	{ key = "curseOfRecklessness",   displayName = "Curse of Recklessness",     iconSpellId = 704,   names = { "Curse of Recklessness" } },
	{ key = "curseOfTheElements",    displayName = "Curse of the Elements",     iconSpellId = 1490,  names = { "Curse of the Elements" } },
	{ key = "huntersMark",           displayName = "Hunter's Mark",             iconSpellId = 1130,  names = { "Hunter's Mark" } },
	{ key = "scorpidSting",          displayName = "Scorpid Sting",             iconSpellId = 3043,  names = { "Scorpid Sting" } },
	{ key = "judgementOfTheCrusader", displayName = "Judgement of the Crusader", iconSpellId = 21183, names = { "Judgement of the Crusader" } },
	{ key = "judgementOfWisdom",     displayName = "Judgement of Wisdom",       iconSpellId = 20186, names = { "Judgement of Wisdom" } },
	{ key = "demoralizingShoutRoar", displayName = "Demoralizing Shout/Roar",   iconSpellId = 1160,  names = { "Demoralizing Shout", "Demoralizing Roar" } },
	{ key = "faerieFire",            displayName = "Faerie Fire",               iconSpellId = 770,   names = { "Faerie Fire" } },
	{ key = "judgementOfLight",      displayName = "Judgement of Light",        iconSpellId = 20185, names = { "Judgement of Light" } },
	{ key = "shadowVulnerability",   displayName = "Shadow Vulnerability",      iconSpellId = 15258, names = { "Shadow Vulnerability" } },
	{ key = "thunderClap",           displayName = "Thunder Clap",              iconSpellId = 6343,  names = { "Thunder Clap" } },
}

-- Per-row runtime state, keyed by debuff key.
D.rowState = {}
for _, entry in ipairs(D.DEBUFFS) do
	D.rowState[entry.key] = { active = false, icon = nil, stacks = 0, expirationTime = 0, duration = 0 }
end

-- Display knobs (set from main via SetDisplayConfig).
D.ICON_SIZE = 32
D.FONT_SIZE = 14
D.DIRECTION = "horizontal"
D.PER_LINE = 8
D.enabledMap = {} -- empty = all visible by default

-- Feature gate.
D.featureEnabled = true

function D.SetFeatureEnabled(enabled)
	D.featureEnabled = enabled and true or false
end

function D.SetDisplayConfig(cfg)
	if not cfg then return end
	D.ICON_SIZE = cfg.debuffIconSize or D.ICON_SIZE
	D.FONT_SIZE = cfg.debuffFontSize or D.FONT_SIZE
	D.DIRECTION = cfg.debuffDirection or D.DIRECTION
	D.PER_LINE = cfg.debuffPerLine or D.PER_LINE
	D.enabledMap = cfg.debuffs or {}
end

-- Ordered array of visible debuff entries (contiguous, no gaps).
function D.GetVisibleRows()
	local rows = {}
	for _, entry in ipairs(D.DEBUFFS) do
		if D.enabledMap[entry.key] ~= false then
			rows[#rows + 1] = entry
		end
	end
	return rows
end

-- -------------------------------
-- Pure grid math (no WoW API / no H / no globals).
-- -------------------------------
function D.ComputeRowPosition(n, direction, perLine, iconSize)
	local row, col
	if direction == "vertical" then
		col = math.floor(n / perLine)
		row = n % perLine
	else
		row = math.floor(n / perLine)
		col = n % perLine
	end
	return col * iconSize, -row * iconSize
end

function D.ComputeContainerSize(visibleCount, direction, perLine, iconSize)
	if visibleCount <= 0 then return 0, 0 end
	if perLine <= 0 then perLine = 1 end

	if direction == "vertical" then
		local width = math.ceil(visibleCount / perLine) * iconSize
		local height = math.min(visibleCount, perLine) * iconSize
		return width, height
	end

	local width = math.min(visibleCount, perLine) * iconSize
	local height = math.ceil(visibleCount / perLine) * iconSize
	return width, height
end

-- -------------------------------
-- Pure aura arg-detection (testable with stub tuples, no globals).
-- Mirrors the wa.json custom trigger branch on type(arg5) == "number".
-- Returns: icon, count, duration, expirationTime, source, spellId
-- -------------------------------
function D.ExtractAuraFields(arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg10, arg11)
	if type(arg5) == "number" then
		return arg2, arg3, arg5, arg6, arg7, arg10
	end
	return arg3, arg4, arg6, arg7, arg8, arg11
end

-- -------------------------------
-- Icon resolution (WoW-API dependent; not part of pure tests).
-- -------------------------------
function D.ResolveDebuffIcon(iconSpellId)
	local tex = GetSpellTexture and GetSpellTexture(iconSpellId)
	if not tex then
		local _, _, fb = GetSpellInfo(iconSpellId)
		tex = fb
	end
	return tex or H.DEFAULT_ICON_FILEID
end

-- -------------------------------
-- Event-driven target aura scan (WoW-API dependent; verified in-game).
-- -------------------------------
function D.RefreshFromTarget()
	for _, entry in ipairs(D.GetVisibleRows()) do
		D.rowState[entry.key].active = false
	end

	if not UnitExists("target") then return end

	local nameToKey = {}
	for _, entry in ipairs(D.GetVisibleRows()) do
		for _, name in ipairs(entry.names) do
			nameToKey[name] = entry.key
		end
	end

	for i = 1, 40 do
		local name, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11 = UnitAura("target", i, "HARMFUL")
		if not name then break end
		local key = nameToKey[name]
		if key then
			local icon, count, duration, expirationTime, source, spellId = D.ExtractAuraFields(arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg10, arg11)
			D.rowState[key] = {
				active = true,
				icon = (icon and icon ~= "" and icon or nil),
				stacks = count or 0,
				expirationTime = expirationTime or 0,
				duration = duration or 0,
			}
		end
	end
end
