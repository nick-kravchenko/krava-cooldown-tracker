-- Read Blizzard's addon metrics; do not enable profiling or reset global stats.
KravaCooldownTracker_Benchmark = {}
local B = KravaCooldownTracker_Benchmark
local ADDON = "KravaCooldownTracker"
local window
local INTERVAL = 2

local function numberFrom(callback, ...)
 if type(callback) ~= "function" then return nil end
 local ok, value = pcall(callback, ...)
 if ok and type(value) == "number" and value == value and value >= 0 and value < math.huge then return value end
end

function B.Sample()
 local result = {}
 if UpdateAddOnMemoryUsage and GetAddOnMemoryUsage then
  local ok = pcall(UpdateAddOnMemoryUsage)
  if ok then result.memoryKB = numberFrom(GetAddOnMemoryUsage, ADDON) end
 end
 local profiler = C_AddOnProfiler
 local metrics = Enum and Enum.AddOnProfilerMetric
 if profiler and profiler.IsEnabled and profiler.GetAddOnMetric and metrics then
  local ok, enabled = pcall(profiler.IsEnabled)
  if ok and enabled then
   local function metric(key)
    if metrics[key] == nil then return nil end
    return numberFrom(profiler.GetAddOnMetric, ADDON, metrics[key])
   end
   result.recentMS = metric("RecentAverageTime")
   result.sessionMS = metric("SessionAverageTime")
   result.peakMS = metric("PeakTime")
   if metrics.RecentAverageTime ~= nil then
    local total = numberFrom(profiler.GetOverallMetric, metrics.RecentAverageTime)
    if total and total > 0 and result.recentMS then
     result.addonShare = result.recentMS / total * 100
    end
   end
  end
 end
 return result
end

function B.FormatMemory(kb)
 if kb == nil then return "Unavailable" end
 if kb >= 1024 then return string.format("%.2f MB", kb / 1024) end
 return string.format("%.1f KB", kb)
end

local function formatTime(ms)
 return ms ~= nil and string.format("%.3f ms", ms) or "Unavailable"
end

function B.CreateWindow()
 if window then return window end
 local C = KravaCooldownTracker_Config
 local frame = CreateFrame("Frame", "KravaCooldownTrackerBenchmark", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
 frame:SetSize(390, 310)
 frame:SetPoint("CENTER")
 frame:SetFrameStrata("DIALOG")
 frame:SetClampedToScreen(true)
 frame:EnableMouse(true)
 frame:SetMovable(true)
 frame:RegisterForDrag("LeftButton")
 frame:SetScript("OnDragStart", frame.StartMoving)
 frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
 if frame.SetBackdrop then
  frame:SetBackdrop({ bgFile="Interface\\DialogFrame\\UI-DialogBox-Background-Dark", edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", edgeSize=12, insets={left=3,right=3,top=3,bottom=3} })
  frame:SetBackdropColor(0.04, 0.04, 0.05, 0.98)
  frame:SetBackdropBorderColor(0.45, 0.45, 0.45, 1)
 end
 UISpecialFrames = UISpecialFrames or {}
 table.insert(UISpecialFrames, "KravaCooldownTrackerBenchmark")
 local function label(text, x, y)
  local fs = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  fs:SetPoint("TOPLEFT", x, y)
  fs:SetText(text)
  if C and C.RegisterFontString then C.RegisterFontString(fs) end
  return fs
 end
 label("KCT Benchmark", 16, -16)
 local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
 close:SetPoint("TOPRIGHT", -3, -3)
 close:SetScript("OnClick", function() frame:Hide() end)
 local values = {}
 for index, title in ipairs({ "Memory (RAM)", "CPU recent average", "CPU session average", "CPU session peak", "Share of addon CPU" }) do
  local y = -58 - (index - 1) * 30
  label(title, 16, y)
  values[index] = label("Waiting...", 240, y)
 end
 local note = label("", 16, -220)
 note:SetWidth(358)
 note:SetJustifyH("LEFT")
 note:SetText("Blizzard addon metrics. CPU is time per frame, not system CPU %. Updates every 2 seconds while open. Session values reset on reload.")
 local elapsed = 0
 local function refresh()
  local sample = B.Sample()
  values[1]:SetText(B.FormatMemory(sample.memoryKB))
  values[2]:SetText(formatTime(sample.recentMS))
  values[3]:SetText(formatTime(sample.sessionMS))
  values[4]:SetText(formatTime(sample.peakMS))
  values[5]:SetText(sample.addonShare and string.format("%.1f%%", sample.addonShare) or "Unavailable")
  if sample.recentMS == nil then
   note:SetText("CPU metrics are unavailable: Blizzard's addon profiler is disabled or unsupported by this client. Memory updates every 2 seconds while open.")
  else
   note:SetText("Blizzard addon metrics. CPU is time per frame, not system CPU %. Updates every 2 seconds while open. Session values reset on reload.")
  end
 end
 frame:SetScript("OnShow", function() elapsed = 0; refresh() end)
 frame:SetScript("OnUpdate", function(_, delta)
  elapsed = elapsed + delta
  if elapsed >= INTERVAL then elapsed = 0; refresh() end
 end)
 frame:Hide()
 window = frame
 return frame
end

function B.Toggle()
 local frame = B.CreateWindow()
 if frame:IsShown() then frame:Hide() else frame:Show() end
end
