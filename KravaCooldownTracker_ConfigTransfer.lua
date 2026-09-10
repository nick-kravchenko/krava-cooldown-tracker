-- Versioned, data-only config transfer. Never executes imported text.
local C = KravaCooldownTracker_Config
local PREFIX = "KCT1:"
local MAX_LENGTH = 100000
local positionKeys = { "pos", "debuffPos", "consumablePos", "raidNotesPos" }

local function encode(value)
 local kind = type(value)
 if kind == "boolean" then return value and "B1" or "B0" end
 if kind == "number" then return "N" .. tostring(value) .. ";" end
 if kind == "string" then
  local hex = value:gsub(".", function(c) return string.format("%02x", string.byte(c)) end)
  return "S" .. #hex .. ":" .. hex
 end
 assert(kind == "table", "Unsupported config value")
 local keys, parts = {}, {}
 for key in pairs(value) do keys[#keys + 1] = key end
 table.sort(keys, function(a, b) return type(a) .. tostring(a) < type(b) .. tostring(b) end)
 for _, key in ipairs(keys) do parts[#parts + 1] = encode(key) .. encode(value[key]) end
 return "T" .. #keys .. ":" .. table.concat(parts)
end

local function decode(text)
 local cursor, count = 1, 0
 local function read(depth)
  count = count + 1
  assert(depth <= 8 and count <= 10000, "Config is too complex")
  local tag = text:sub(cursor, cursor)
  cursor = cursor + 1
  if tag == "B" then
   local flag = text:sub(cursor, cursor)
   cursor = cursor + 1
   assert(flag == "0" or flag == "1", "Invalid boolean")
   return flag == "1"
  end
  if tag == "N" then
   local ending = assert(text:find(";", cursor, true), "Invalid number")
   local value = tonumber(text:sub(cursor, ending - 1))
   assert(value and value == value and math.abs(value) < 1e12, "Invalid number")
   cursor = ending + 1
   return value
  end
  assert(tag == "S" or tag == "T", "Invalid data tag")
  local ending = assert(text:find(":", cursor, true), "Invalid length")
  local digits = text:sub(cursor, ending - 1)
  assert(digits:match("^%d+$"), "Invalid length")
  local length = tonumber(digits)
  assert(length <= MAX_LENGTH, "Data is too large")
  cursor = ending + 1
  if tag == "S" then
   local hex = text:sub(cursor, cursor + length - 1)
   assert(#hex == length and length % 2 == 0 and not hex:find("[^%x]"), "Invalid string")
   cursor = cursor + length
   return (hex:gsub("..", function(pair) return string.char(tonumber(pair, 16)) end))
  end
  assert(length <= 5000, "Too many entries")
  local result = {}
  for _ = 1, length do
   local key = read(depth + 1)
   assert(type(key) == "string" or type(key) == "number", "Invalid key")
   assert(result[key] == nil, "Duplicate key")
   result[key] = read(depth + 1)
  end
  return result
 end
 local value = read(0)
 assert(cursor == #text + 1, "Unexpected trailing data")
 return value
end

local function validateBlacklist(list)
 assert(type(list) == "table", "Invalid exclusion list")
 for id, disabled in pairs(list) do
  assert(type(id) == "number" and id > 0 and id % 1 == 0 and type(disabled) == "boolean", "Invalid excluded trinket")
 end
end

local function validateSettings(settings, template)
 assert(type(settings) == "table", "Invalid settings")
 for key, value in pairs(settings) do
  assert(template[key] ~= nil and type(value) == type(template[key]), "Unknown or invalid setting")
  if key == "trinketDropdownBlacklist" or key == "trinketSuggestionBlacklist" then
   validateBlacklist(value)
  elseif type(value) == "table" then
   validateSettings(value, template[key])
   if key == "raidNotesBackgroundColor" or key == "raidNotesBorderColor" then
    for i = 1, 4 do assert(type(value[i]) == "number" and value[i] >= 0 and value[i] <= 1, "Invalid color") end
   end
  end
 end
end

function C.ExportConfig()
 local settings = {}
 for key, value in pairs(C.Get()) do
  if key ~= "trinketSuggestionBlacklist" then settings[key] = value end
 end
 local positions = {}
 for _, key in ipairs(positionKeys) do positions[key] = KravaCooldownTrackerDB[key] end
 return PREFIX .. encode({ settings = settings, positions = positions, suggestions = C.GetTrinketBlacklist("suggestion") })
end

function C.ImportConfig(text)
 if InCombatLockdown and InCombatLockdown() then return false, "Cannot import during combat." end
 if type(text) ~= "string" or #text > MAX_LENGTH then return false, "Invalid or oversized config." end
 text = text:gsub("%s+", "")
 if text:sub(1, #PREFIX) ~= PREFIX then return false, "Expected a KCT1 config export." end
 local ok, payload = pcall(function()
  local data = decode(text:sub(#PREFIX + 1))
  assert(type(data) == "table", "Invalid config")
  for key in pairs(data) do assert(key == "settings" or key == "positions" or key == "suggestions", "Unknown section") end
  validateSettings(data.settings, C.Get())
  validateBlacklist(data.suggestions)
  assert(type(data.positions) == "table", "Invalid positions")
  local allowed = {}; for _, key in ipairs(positionKeys) do allowed[key] = true end
  local anchors = { CENTER=true, TOP=true, BOTTOM=true, LEFT=true, RIGHT=true, TOPLEFT=true, TOPRIGHT=true, BOTTOMLEFT=true, BOTTOMRIGHT=true }
  for key, pos in pairs(data.positions) do
   assert(allowed[key] and type(pos) == "table", "Invalid position")
   assert(type(pos.point) == "string" and type(pos.relPoint) == "string" and anchors[pos.point] and anchors[pos.relPoint], "Invalid anchor")
   assert(type(pos.x) == "number" and type(pos.y) == "number", "Invalid coordinates")
  end
  return data
 end)
 if not ok then return false, "Invalid config; nothing imported." end
 -- Preserve the legacy migration seed for other characters.
 payload.settings.trinketSuggestionBlacklist = C.Get().trinketSuggestionBlacklist
 KravaCooldownTrackerDB.config = payload.settings
 for _, key in ipairs(positionKeys) do KravaCooldownTrackerDB[key] = payload.positions[key] end
 KravaCooldownTrackerCharacterDB = KravaCooldownTrackerCharacterDB or {}
 KravaCooldownTrackerCharacterDB.trinketSuggestionBlacklist = payload.suggestions
 C.Normalize()
 if C.RestorePositions then C.RestorePositions() end
 C.RefreshChanged()
 return true, "Imported. Settings and positions applied."
end
