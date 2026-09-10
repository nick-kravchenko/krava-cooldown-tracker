# KravaCooldownTracker

KravaCooldownTracker is a lightweight World of Warcraft Classic addon with two independent features: a **Trinkets** tracker that shows the two equipped trinket slots as movable icons, lets you swap trinkets from your bags through a hover menu, and displays cooldown, aura, and internal cooldown timing where the addon has metadata for the equipped item; and a **Debuffs** tracker that shows a fixed grid of important harmful debuffs on your current target, greyed out when absent and lit with a live countdown when active. Each feature has its own movable frame, lock state, and config tab, and can be enabled or disabled independently.

## Game Version

The addon TOC is currently set to:

```toc
## Interface: 20505
```

This targets the Classic Era/Anniversary client interface version used by the local addon folder.

## Features

### Trinkets

- Shows both player trinket slots, inventory slots `13` and `14`.
- Hover a trinket slot to open a vertical dropdown of trinkets found in bags `0` through `4`.
- Maintains separate per-item blacklists for the bag dropdown and automatic suggestions. Suggestion exclusions are saved per character; existing account-wide exclusions are copied when each character first uses the new storage.
- Click a dropdown trinket to equip it into that slot.
- Queues a requested trinket swap while in combat, then attempts the swap when combat ends.
- Displays item cooldowns on equipped trinkets and bag-dropdown trinkets.
- Displays active tracked trinket buff duration in green text with a glow overlay.
- Tracks configured proc internal cooldowns from combat-log aura events.
- Applies a synthetic 30 second equip lockout timer after equipping configured active/proc trinkets or unknown trinkets without a detectable item cooldown.
- Shows a small queued-item overlay when a combat-locked swap or unequip is waiting.
- Saves the trinket frame position and display settings in `KravaCooldownTrackerDB`.

### Debuffs

- Tracks a fixed set of 12 important harmful debuffs on your current `target`: Major Armor Reduction (Sunder Armor / Expose Armor), Curse of Recklessness, Curse of the Elements, Hunter's Mark, Scorpid Sting, Judgement of the Crusader, Judgement of Wisdom, Demoralizing Shout/Roar, Faerie Fire, Judgement of Light, Shadow Vulnerability, and Thunder Clap.
- Every enabled debuff always shows an icon: greyed out and static as a placeholder when the debuff is not on the target, and lit in full color with a live countdown (and stack count where applicable) when it is present.
- The debuff list is fixed and not user-editable beyond an on/off checkbox per debuff. All 12 are enabled by default.
- Grid layout is configurable: icon size, font size, growth direction (horizontal or vertical), and the number of icons per line. Horizontal fills left-to-right then wraps down; vertical fills top-to-bottom then wraps to the next column.
- Disabled debuffs are skipped with no blank gap, so unchecking one in the middle of the list reflows the remaining icons. This is expected behavior, not a bug.
- The debuff tracker has its own movable frame, its own lock state, and its own saved position, fully independent of the trinket tracker.

### Config

- Opens a tabbed immediate-apply config modal with `/kct`: a **General** tab (font family, lock, and a per-feature enable/disable list) and one tab per enabled feature (**Trinkets** and **Debuffs**).
- Enable or disable a feature from the General tab. Disabling a feature hides both its config tab and its entire in-world display; re-enabling restores them without `/reload`.
- Configures per-feature icon sizes, font size, and layout/suggestion options inside the feature's own tab, plus a default-on option to prevent main-icon clicks from using equipped trinkets.
- The Trinkets tab lists carried, equipped, and previously disabled trinkets in separate dropdown and suggestion lists. Clicking an item with either mouse button toggles it. Disabled icons are dark and desaturated, and hovering an icon shows its item tooltip.
- The chosen font family applies to the addon's in-world text (trinket tracker, suggestions, dropdown, debuff timers). The config modal itself always uses Arial.

## Controls

- Hover either trinket icon: show the bag trinket dropdown for that slot.
- Left-click a dropdown trinket: equip it into the hovered slot, or queue it if combat prevents equipping.
- Left-click the empty dropdown entry: unequip the hovered slot, or queue the unequip if combat prevents it.
- Left-click the main trinket icon: retry the queued item for that slot when out of combat.
- By default, main trinket icon clicks do not activate the equipped trinket. Uncheck "Disable trinket usage on click" in `/kct` to allow click-to-use on the main icons.
- Type `/kct`: toggle the tabbed config modal.
- Unlock the tracker in `/kct` (General tab) or by right-clicking a main trinket icon: show left and right drag handles beside the trinkets.
- Drag either unlocked handle: move the two-icon tracker frame.
- Right-click either main trinket icon: toggle the locked/unlocked state (no effect in combat).
- Right-click any debuff icon: toggle the debuff tracker's locked/unlocked state (no effect in combat). This affects only the debuff tracker, never the trinket tracker.
- Unlock the debuff tracker (via right-click or the config) to show its drag handles, then drag a handle to move the debuff grid. Its position is saved independently of the trinket tracker.

## Visual States

- Normal icon: trinket is ready or passive.
- Grey/desaturated icon with timer: trinket is on cooldown, in equip lockout, or waiting on a tracked internal cooldown.
- Green timer plus gold glow: a configured player aura from the trinket is currently active.
- Empty/question-mark icon: no trinket is equipped in that slot.
- Greyed/desaturated debuff icon with no text: that debuff is enabled but not currently on your target.
- Full-color debuff icon with countdown (and stack count when stacked): that debuff is active on your target.

## Installation

Place this folder in your WoW addon directory:

```text
World of Warcraft/_anniversary_/Interface/AddOns/KravaCooldownTracker
```

The folder should contain `KravaCooldownTracker.toc` directly at its root. Restart the game or reload the UI after installing:

```text
/reload
```

## File Overview

```text
KravaCooldownTracker.toc
KravaCooldownTracker_Trinkets.lua
KravaCooldownTracker_Helpers.lua
KravaCooldownTracker_Config.lua
KravaCooldownTracker_TrinketLogic.lua
KravaCooldownTracker_DebuffLogic.lua
KravaCooldownTracker.lua
```

- `KravaCooldownTracker.toc` defines addon metadata, saved variables, and load order.
- `KravaCooldownTracker.lua` creates the main trinket and debuff frames, slot/row buttons, drag handles, event frame, saved-position handling, and update loops.
- `KravaCooldownTracker_Helpers.lua` contains compatibility helpers for combat checks, time formatting, auras, bags, cooldowns, and icon styling.
- `KravaCooldownTracker_Config.lua` contains saved display settings, `/kct`, font options, and the compact tabbed config modal.
- `KravaCooldownTracker_Trinkets.lua` contains trinket metadata keyed by item ID.
- `KravaCooldownTracker_TrinketLogic.lua` handles bag scanning, dropdown UI, equipping/queueing, overlay timers, equip lockout, and proc ICD tracking.
- `KravaCooldownTracker_DebuffLogic.lua` holds the fixed debuff table, per-target aura scanning, and pure grid-layout math for the debuff tracker.

## Saved Variables

The addon uses one account-wide saved variable table:

```lua
KravaCooldownTrackerDB
```

It stores each tracker's frame position separately. `pos` is the trinket tracker; `debuffPos` is the debuff tracker:

```lua
KravaCooldownTrackerDB.pos = {
  point = "...",
  relPoint = "...",
  x = 0,
  y = 0,
}

KravaCooldownTrackerDB.debuffPos = {
  point = "...",
  relPoint = "...",
  x = 0,
  y = 0,
}
```

It also stores immediate-apply display settings:

```lua
KravaCooldownTrackerDB.config = {
  mainIconSize = 32,
  queueIconPercent = 25,
  fontFace = "Fonts\\FRIZQT__.TTF",
  fontSize = 14,
  locked = true,
  disableTrinketUsageOnClick = true,
  disableUpperTrinketSuggestions = true,
  disableLowerTrinketSuggestions = true,
  suggestionAvailableSound = "none",
  -- Debuff tracker settings
  debuffIconSize = 32,
  debuffFontSize = 14,
  debuffDirection = "horizontal", -- or "vertical"
  debuffPerLine = 8,
  debuffLocked = true,
  debuffs = {
    -- per-debuff on/off, all true by default
    majorArmorReduction = true,
    curseOfRecklessness = true,
    -- ... one key per tracked debuff ...
    thunderClap = true,
  },
  features = {
    trinkets = true,
    debuffs = true,
  },
}
```

Right-clicking a main trinket icon toggles the locked/unlocked state (out of combat); it no longer resets the saved position. To reposition, unlock (via the General tab or right-click) and drag a handle.
New users are locked by default, all features are enabled by default, main-icon trinket usage is disabled by default, and suggestions are disabled for both trinket slots. Disabling a feature in the General tab hides its tab and its in-world display; missing or pre-upgrade saved variables default every feature to enabled.

## Trinket Metadata

Tracked trinkets are configured in `KravaCooldownTracker_Trinkets.lua`:

```lua
[28830] = {
  kind = "proc",
  buffSpellIds = { 34775 },
  icd = 20,
}
```

Supported fields:

- `kind`: `passive`, `proc`, or `active`.
- `buffSpellIds`: player aura spell IDs used to detect active buff duration.
- `icd`: internal cooldown duration in seconds for proc trinkets.

Passive trinkets do not show timers or overlay states. Active and proc trinkets can show real item cooldowns, tracked aura durations, synthetic equip lockouts, and configured internal cooldowns.

## Adding Or Updating A Trinket

Add or edit an entry in `KravaCooldownTracker_Trinkets.lua` using the item ID as the key.

Example active trinket:

```lua
[29370] = {
  kind = "active",
  buffSpellIds = { 35163 },
}
```

Example proc trinket with an internal cooldown:

```lua
[27683] = {
  kind = "proc",
  buffSpellIds = { 33370 },
  icd = 45,
}
```

If the trinket effect does not create a player buff, omit `buffSpellIds`. The addon can still show item cooldowns, but it cannot show an active aura timer or combat-log ICD trigger without a matching player aura spell ID.

## Implementation Notes

- Bag trinkets are discovered dynamically by checking item equip location `INVTYPE_TRINKET`.
- Dropdown entries are sorted by item name.
- Combat lockdown is respected: trinkets are queued during combat instead of force-equipped.
- `PLAYER_REGEN_ENABLED` retries queued swaps after combat ends.
- `COMBAT_LOG_EVENT_UNFILTERED` starts configured proc ICD timers when a configured aura is applied or refreshed on the player.
- The main update loop is throttled to run about every `0.05` seconds.
- Dropdown cooldown refresh is throttled to about every `0.10` seconds.
- Display settings from `/kct` apply immediately and do not require `/reload`.

## Current Limitations

- Proc ICD tracking depends on accurate `buffSpellIds` and `icd` metadata.
- Combat-log aura events do not identify the source item. If both equipped trinkets share the same configured aura spell ID, the addon avoids assigning the aura or ICD to either slot instead of guessing.
- Trinkets that apply debuffs to targets instead of player buffs cannot show active player aura timers with the current logic.
- Queued swaps are kept only in memory and are not saved across reloads.
- The debuff tracker only follows your current `target`; it does not track focus, arena, or nameplate units.
- The tracked debuff list is fixed and cannot be extended with custom spell IDs; debuffs can only be toggled on or off.
- Debuffs are matched by aura name, so same-named auras from any source will light up the icon regardless of who applied them.

### Export and import

Open `/kct config` and use **Export / Import** in General. Click **Export**, then press Ctrl+C to copy the selected string. To restore or share a setup, paste the string into the text box and click **Import**. Import replaces settings and this character’s suggestion exclusions, and includes saved feature positions. Settings and positions apply immediately without reloading the UI. Invalid strings are rejected without changing settings; importing is unavailable during combat.

### Resource benchmark

Open **Benchmark** in `/kct config` → General, or run `/kct benchmark`. The movable window shows KCT memory in KB/MB and Blizzard profiler CPU metrics: recent average, session average, session peak, and share of total addon CPU. CPU timings are milliseconds per frame, not operating-system CPU utilization. The window refreshes every two seconds while visible and closes with Escape. CPU values show as unavailable if the client does not expose an enabled addon profiler. The monitor does not change profiling settings, reset statistics, or force garbage collection.
