-- HomeworkTracker - Core
local addonName, addon = ...

-- Define default colors
addon.defaultColors = {
    general        = {0.255, 0.439, 0.929},
    delves         = {0.886, 0.518, 0.196},
    delveCompanion = {0.886, 0.518, 0.196},
    vault          = {0.255, 0.439, 0.929},
    weekly         = {0.255, 0.439, 0.929},
    progress       = {1, 0.4, 0.4},
    currency       = {0.3, 0.3, 0.3},
    activities     = {},
    zones          = {},
    textLeft       = {1, 1, 1},
    textRight      = {1, 1, 1},
    headerText     = {0.3, 0.69, 0.93},
}

-- Define default settings
local defaults = {
    enabled = true,
        hideInParty = false,
        hideInRaid = false,
        hideInCombat = false,
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
    rares = { enable = true, hideComplete = true, hideRepComplete = false, currentZone = true },
    delves = { enable = true },
    progress = { enable = true, hidden = {}, levels = {} },
    expansions = { theWarWithin = true, midnight = true },
    ui = { selectedExpansion = "midnight" },
    showMinimapButton = true,
    barTexture = nil,
    font = "Friz Quadrata TT",
    fontSize = 11,
    fontOutline = "OUTLINE",
    headerFont = "Friz Quadrata TT",
    headerFontSize = 14,
    headerFontOutline = "OUTLINE",
    colors = addon.defaultColors,
    minimized = false,
    hideTitleText = false,
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
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("QUEST_TURNED_IN")
eventFrame:RegisterEvent("QUEST_LOG_UPDATE")
eventFrame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
eventFrame:RegisterEvent("WEEKLY_REWARDS_UPDATE")
eventFrame:RegisterEvent("MAJOR_FACTION_RENOWN_LEVEL_CHANGED")
eventFrame:RegisterEvent("UPDATE_FACTION")
eventFrame:RegisterEvent("AREA_POIS_UPDATED")
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
eventFrame:RegisterEvent("WALK_IN_DATA_UPDATE")
eventFrame:RegisterEvent("PLAYER_LOGOUT")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" and ... == addonName then
        addon:RunDatabaseInit()
        addon:InitializeSavedVariables()
        addon:CreateUI()
        if addon.CheckVisibilityState then addon:CheckVisibilityState() end
    elseif event == "PLAYER_LOGIN" then
        if addon.CheckVisibilityState then addon:CheckVisibilityState() end
        if addon.UpdateDisplay then addon:UpdateDisplay() end
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" or event == "WALK_IN_DATA_UPDATE" then
        if addon.InvalidateDataCache then addon:InvalidateDataCache() end
        if addon.CheckVisibilityState then addon:CheckVisibilityState() end
        if addon.UpdateDisplay then addon:UpdateDisplay() end
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        if addon.CheckVisibilityState then addon:CheckVisibilityState() end
    elseif event == "QUEST_TURNED_IN" or event == "QUEST_LOG_UPDATE"
        or event == "CURRENCY_DISPLAY_UPDATE"
        or event == "WEEKLY_REWARDS_UPDATE" or event == "MAJOR_FACTION_RENOWN_LEVEL_CHANGED"
        or event == "UPDATE_FACTION" or event == "AREA_POIS_UPDATED"
        or event == "BAG_UPDATE_DELAYED" then
        if addon.InvalidateDataCache then addon:InvalidateDataCache() end
        if addon.UpdateDisplay then addon:UpdateDisplay() end
    elseif event == "PLAYER_LOGOUT" then
        if addon.SaveActiveProfile then addon:SaveActiveProfile() end
    end
end)
