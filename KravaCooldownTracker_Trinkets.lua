-- KravaCooldownTracker_Trinkets.lua
-- All trinket metadata lives here.
-- kind = "passive" | "proc" | "active"
-- buffSpellIds = { ... }  -- player aura spell IDs to track (proc/active buffs)
-- icd = number            -- internal cooldown seconds (only for proc trinkets, optional)

KravaCooldownTracker_TrinketCfg = {

	-- =========================
	-- Melee / physical DPS
	-- =========================

	-- 28830 Dragonspine Trophy
	-- Proc buff: 34775 "Dragonspine Flurry" (10s), ICD ~20s
	[28830] = { kind = "proc",  buffSpellIds = { 34775 }, icd = 20 },

	-- 21670 Badge of the Swarmguard (AQ40)
	[21670] = { kind = "active", buffSpellIds = { 26481 } },

	-- 29383 Bloodlust Brooch (on-use AP)
	[29383] = { kind = "active", buffSpellIds = { 35166 } },

	-- 23041 Slayer's Crest (on-use AP)
	-- Verified spell: 28777
	[23041] = { kind = "active", buffSpellIds = { 28777 } },

	-- 28288 Abacus of Violent Odds (on-use haste)
	[28288] = { kind = "active", buffSpellIds = { 33807 } },

	-- 28034 Hourglass of the Unraveller (proc)
	[28034] = { kind = "proc",  buffSpellIds = { 60066, 33649 }, icd = 45 },

	-- 28121 Icon of Unyielding Courage
	[28121] = { kind = "active", buffSpellIds = { 34106 } },

	-- 28579 Romulo's Poison Vial
	-- Often procs a debuff on target (not a player buff) -> leave without buffSpellIds
	[28579] = { kind = "proc" },

	-- 27529 Figurine of the Colossus (use: block->heal style effect)
	[27529] = { kind = "active", buffSpellIds = { 33089 } },

	-- 28528 Moroes' Lucky Pocket Watch (use: dodge)
	[28528] = { kind = "active", buffSpellIds = { 34519 } },

	-- 28040 Vengeance of the Illidari
	[28040] = { kind = "proc", buffSpellIds = { 33662 } },

	-- 28041 Bladefist's Breadth (on-use AP)
	[28041] = { kind = "active", buffSpellIds = { 33667 } },

	-- 19406 Drake Fang Talisman (passive stats)
	[19406] = { kind = "passive" },


	-- =========================
	-- Utility / Engineering
	-- =========================

	-- 23836 Goblin Rocket Launcher (use: rocket)
	-- No player aura needed; cooldown via item CD.
	[23836] = { kind = "active" },

	-- 23835 Gnomish Poultryizer (use: transform target)
	[23835] = { kind = "active" },

	-- 29387 Gnomeregan Auto-Blocker 600 (use: shield)
	[29387] = { kind = "active", buffSpellIds = { 35169 } },

	-- 31113 Violet Badge (use: absorb / resist style)
	[31113] = { kind = "passive" },


	-- =========================
	-- Caster DPS
	-- =========================

	-- 29370 Icon of the Silver Crescent (on-use spell power)
	[29370] = { kind = "active", buffSpellIds = { 35163 } },

	-- 27683 Quagmirran's Eye (proc haste)
	[27683] = { kind = "proc", buffSpellIds = { 33370 }, icd = 45 },

	-- 29181 Timelapse Shard (proc)
	[29181] = { kind = "active", buffSpellIds = { 35352 } },

	-- 29132 Scryer's Bloodgem (on-use)
	[29132] = { kind = "active", buffSpellIds = { 35337 } },

	-- 28785 The Lightning Capacitor (proc: charges)
	[28785] = { kind = "proc", buffSpellIds = { 37658 } },

	-- 28418 Shiffar's Nexus-Horn (proc)
	[28418] = { kind = "proc", buffSpellIds = { 34321 }, icd = 45 },

	-- 28789 Eye of Magtheridon (proc)
	[28789] = { kind = "proc", buffSpellIds = { 34747 } },

	-- 28727 Pendant of the Violet Eye (proc: stacking)
	[28727] = { kind = "active", buffSpellIds = { 35095 } },

	-- 28823 Eye of Gruul (proc)
	[28823] = { kind = "proc", buffSpellIds = { 18350 } },

	-- 19379 Neltharion's Tear (passive stats)
	[19379] = { kind = "passive" },

	-- 23046 The Restrained Essence of Sapphiron (passive stats)
	[23046] = { kind = "active", buffSpellIds = { 28779 } },

	-- 19339 Mind Quickening Gem (use: spell haste)
	-- Verified spell: 23723
	[19339] = { kind = "active", buffSpellIds = { 23723 } },

	-- 19288 Darkmoon Card: Blue Dragon (proc mana regen)
	-- Verified spell: 23688 "Aura of the Blue Dragon"
	[19288] = { kind = "proc", buffSpellIds = { 23688 } },


	-- =========================
	-- Healer
	-- =========================

	-- 29376 Essence of the Martyr (use)
	[29376] = { kind = "active", buffSpellIds = { 35165 } },

	-- 30841 Lower City Prayerbook (proc)
	[30841] = { kind = "active", buffSpellIds = { 37877 } },

	-- 28190 Scarab of the Infinite Cycle (proc)
	[28190] = { kind = "proc", buffSpellIds = { 33370 }, icd = 45 },

	-- 19395 Rejuvenating Gem (use)
	[19395] = { kind = "passive" },

	-- 23047 Eye of the Dead (proc/stacking)
	[23047] = { kind = "active", buffSpellIds = { 28780 } },

	-- 24390 Auslese's Light Channeler
	[24390] = { kind = "active", buffSpellIds = { 31794 } },

	-- 28370 Bangle of Endless Blessings (use)
	[28370] = { kind = "active", buffSpellIds = { 38346, 34210 }, icd = 50 },

	-- 29179 Xi'ri's Gift (defensive/proc)
	[29179] = { kind = "active", buffSpellIds = { 35337 } },

	-- 28590 Ribbon of Sacrifice (use)
	[28590] = { kind = "active", buffSpellIds = { 38332 } },


	-- =========================
	-- “Hybrid / special”
	-- =========================

	-- 19337 The Black Book (use: pet / damage)
	[19337] = { kind = "active", buffSpellIds = { 23720 } },

	-- 19343 Scrolls of Blinding Light
	[19343] = { kind = "active", buffSpellIds = { 23733 } },

	-- 23206 / 23207 Mark of the Champion (two faction variants / duplicates)
	[23206] = { kind = "passive" },
	[23207] = { kind = "passive" },

	-- 27770 Argussian Compass (proc)
	[27770] = { kind = "active", buffSpellIds = { 39228 } },

	-- 25634 Oshu'gun Relic (you listed twice)
	[25634] = { kind = "active", buffSpellIds = { 32367 } },

	-- 26055 Oculus of the Hidden Eye
	[26055] = { kind = "active", buffSpellIds = { 33012 } },

	-- 28223 Arcanist's Stone
	[28223] = { kind = "active", buffSpellIds = { 34000 } },

	-- 22954 Kiss of the Spider (use: melee haste)
	[22954] = { kind = "active", buffSpellIds = { 28866 } },

	-- 13503 Alchemist's Stone (passive)
	[13503] = { kind = "passive" },
}
