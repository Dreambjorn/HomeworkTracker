-- HomeworkTracker - Core
local addonName, addon = ...

-- Define default colors
addon.defaultColors = {
    general = {0.255, 0.439, 0.929},
    delves = {0.886, 0.518, 0.196},
    vault = {0.255, 0.439, 0.929},
    weekly = {0.255, 0.439, 0.929},
    progress = {1, 0.4, 0.4},
    currency = {0.3, 0.3, 0.3},
    activities = {},
    zones = {},
    textLeft   = {1, 1, 1},
    textRight  = {1, 1, 1},
    headerText = {0.3, 0.69, 0.93},
}

-- Define default settings
local defaults = {
    enabled = true,
        hideInParty = false,
        hideInRaid = false,
        width = 280,
        height = 400,
    scale = 1.4,
    position = { point = "TOPLEFT", relativePoint = "BOTTOMLEFT", xOfs = 0, yOfs = 550 },
    activities = {
        activityEnable = true,
        hideComplete = true,
        eventAlerts = {},
        timerOffset = {},
        regionForce = { enable = false, region = 1 },
    },
    greatVault = { enable = true, showRaid = true, showMythicPlus = true, showDelves = true },
    weekly = { enable = true, hideComplete = true },
    crests = { enable = true },
    currency = { enable = true, format = "both" },
    reputations = { enable = true, hideComplete = true, hidden = {} },
    rares = { enable = true, hideComplete = true, currentZone = true },
    delves = { enable = true },
    progress = { enable = true, hidden = {}, levels = {} },
    expansions = { theWarWithin = true, midnight = true },
    ui = { selectedExpansion = "midnight" },
    colors = addon.defaultColors,
    minimized = false,
}

addon.defaults = defaults

-- Register slash commands
SLASH_HOMEWORKTRACKER1 = "/homework"
SLASH_HOMEWORKTRACKER2 = "/hw"
SlashCmdList["HOMEWORKTRACKER"] = function(msg)
    local cmd = msg and msg:lower():match("^%s*(%S+)") or ""
    if cmd == "toggle" then
        HomeworkTrackerDB.enabled = not (HomeworkTrackerDB.enabled ~= false)
        addon:UpdateDisplay()
        if addon._enabledCheckbox then
            addon._enabledCheckbox.check:SetChecked(HomeworkTrackerDB.enabled ~= false)
        end
        print("|cff4db2ffHomeworkTracker:|r Tracker " .. (HomeworkTrackerDB.enabled ~= false and "enabled" or "disabled"))
    else
        addon:OpenConfig()
    end
end

-- Register event handlers
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" and ... == addonName then
        addon:RunDatabaseInit()
        addon:InitializeSavedVariables()
        addon:CreateUI()
        
        if addon.CheckInstanceState then addon:CheckInstanceState() end
    elseif event == "PLAYER_LOGIN" then
        if addon.CheckInstanceState then addon:CheckInstanceState() end
        if addon.UpdateDisplay then addon:UpdateDisplay() end
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        if addon.CheckInstanceState then addon:CheckInstanceState() end
    elseif event == "GROUP_ROSTER_UPDATE" then
        if addon.CheckInstanceState then addon:CheckInstanceState() end
    end
end)
