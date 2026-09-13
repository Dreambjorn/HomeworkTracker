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
    reputations    = {},
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
    hideOutsideMajorCities = false,
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
        HomeworkTrackerDB.enabled = HomeworkTrackerDB.enabled ~= true
        addon:UpdateDisplay()
        if addon._enabledCheckbox then
            addon._enabledCheckbox.check:SetChecked(HomeworkTrackerDB.enabled == true)
        end
        print("|cff4db2ffHomeworkTracker:|r Tracker " .. (HomeworkTrackerDB.enabled == true and "enabled" or "disabled"))
    elseif cmd == "debug" then
        -- Debug: forces the redraw path that has to start over, then counts rows left behind
        addon:DebugRows()
    elseif cmd == "profiling" then
        -- Profiling: samples what rebuilding the tracker costs
        local seconds = tonumber(msg:match("(%d+)")) or 60
        seconds = math.max(5, math.min(600, seconds))
        addon:StartProfiling(seconds)
    else
        addon:OpenConfig()
    end
end

-- Which slice of the cache each event actually makes stale
local CACHE_SCOPES = {
    QUEST_TURNED_IN                    = { "weeklyQuests", "rares_" },
    QUEST_LOG_UPDATE                   = { "weeklyQuests", "rares_" },
    CURRENCY_DISPLAY_UPDATE            = { "currency_" },
    BAG_UPDATE_DELAYED                 = { "currency_" },
    WEEKLY_REWARDS_UPDATE              = { "greatVault" },
    CHALLENGE_MODE_COMPLETED           = { "greatVault" },
    CHALLENGE_MODE_MAPS_UPDATE         = { "greatVault" },
    MAJOR_FACTION_RENOWN_LEVEL_CHANGED = { "rep_", "progress_" },
    UPDATE_FACTION                     = { "rep_", "progress_" },
    AREA_POIS_UPDATED                  = { "bountifulDelves" },
}

-- Which tracker sections an event can actually change, so the rest keep their rows
local DIRTY_SECTIONS = {
    QUEST_TURNED_IN                    = { Activities = true, Weekly = true, Rares = true },
    QUEST_LOG_UPDATE                   = { Activities = true, Weekly = true, Rares = true },
    CURRENCY_DISPLAY_UPDATE            = { Currency = true, Crests = true },
    BAG_UPDATE_DELAYED                 = { Currency = true, Crests = true },
    WEEKLY_REWARDS_UPDATE              = { GreatVault = true },
    CHALLENGE_MODE_COMPLETED           = { GreatVault = true },
    CHALLENGE_MODE_MAPS_UPDATE         = { GreatVault = true },
    MAJOR_FACTION_RENOWN_LEVEL_CHANGED = { Reputations = true, Progress = true },
    UPDATE_FACTION                     = { Reputations = true, Progress = true },
    AREA_POIS_UPDATED                  = { Delves = true, Weekly = true },
}

-- Calendar and scheduler events only change activity rows
local ACTIVITY_DIRTY = { Activities = true }

-- Events whose first argument names the one entry that changed
local CACHE_SCOPE_IDS = {
    CURRENCY_DISPLAY_UPDATE            = true,
    MAJOR_FACTION_RENOWN_LEVEL_CHANGED = true,
}

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
eventFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
eventFrame:RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE")
eventFrame:RegisterEvent("MAJOR_FACTION_RENOWN_LEVEL_CHANGED")
eventFrame:RegisterEvent("UPDATE_FACTION")
eventFrame:RegisterEvent("AREA_POIS_UPDATED")
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
eventFrame:RegisterEvent("WALK_IN_DATA_UPDATE")
eventFrame:RegisterEvent("CALENDAR_UPDATE_EVENT_LIST")
if C_EventScheduler then eventFrame:RegisterEvent("EVENT_SCHEDULER_UPDATE") end
eventFrame:RegisterEvent("PLAYER_LOGOUT")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    local arg1 = ...
    local prof = addon._profile
    -- Profiling: lets /hw profiling say which events are driving the rebuilds
    if prof then addon._updateReason = event end
    if event == "ADDON_LOADED" and arg1 == addonName then
        addon:RunDatabaseInit()
        addon:InitializeSavedVariables()
        addon:CreateUI()
        addon._allowVaultRequery = false
        if addon.CheckVisibilityState then addon:CheckVisibilityState() end
        -- Every later ADDON_LOADED belongs to some other addon
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        -- Calendar only when needed; PLAYER_ENTERING_WORLD follows and does the drawing
        if C_Calendar and C_Calendar.OpenCalendar and addon:WantsHolidayData() then
            C_Timer.After(5, function() C_Calendar.OpenCalendar() end)
        end
        if C_EventScheduler and C_EventScheduler.RequestEvents
            and HomeworkTrackerDB.activities.curseSurge then
            C_EventScheduler.RequestEvents()
        end
    -- Not in CACHE_SCOPES: holidays live in their own cache, not the data cache
    elseif event == "CALENDAR_UPDATE_EVENT_LIST" then
        if addon.InvalidateHolidayCache then addon:InvalidateHolidayCache() end
        if addon.UpdateDisplay then addon:UpdateDisplay(ACTIVITY_DIRTY) end
    elseif event == "EVENT_SCHEDULER_UPDATE" then
        if addon.InvalidateEventSchedule then addon:InvalidateEventSchedule() end
        if addon.UpdateDisplay then addon:UpdateDisplay(ACTIVITY_DIRTY) end
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" or event == "WALK_IN_DATA_UPDATE" then
        local wasInInstance = addon._inInstance or addon._inDelves
        if addon.InvalidateDataCache then addon:InvalidateDataCache() end
        -- A visibility change already hid or redrew the tracker
        local handled = addon.CheckVisibilityState and addon:CheckVisibilityState()
        if not handled and addon.UpdateDisplay then addon:UpdateDisplay() end
        if addon.RefreshTitleBar then addon:RefreshTitleBar() end
        if not addon._allowVaultRequery then
            C_Timer.After(5, function() addon:AllowGreatVaultRequery() end)
        end
        if wasInInstance and addon._allowVaultRequery then
            if addon.RequestGreatVaultRequery then addon:RequestGreatVaultRequery() end
        end
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        if addon.CheckVisibilityState then addon:CheckVisibilityState() end
    elseif CACHE_SCOPES[event] then
        local prepStart = prof and debugprofilestop() or nil
        -- Finishing a key does not refresh the map data on its own
        if event == "CHALLENGE_MODE_COMPLETED" and C_MythicPlus and C_MythicPlus.RequestMapInfo then
            C_MythicPlus.RequestMapInfo()
        end
        if addon.InvalidateDataCache then
            local id = CACHE_SCOPE_IDS[event] and arg1 or nil
            for _, namespace in ipairs(CACHE_SCOPES[event]) do
                addon:InvalidateDataCache(namespace, id)
            end
        end
        local dirty = DIRTY_SECTIONS[event]
        -- These fire constantly but rarely change a row, so narrow them further
        if event == "AREA_POIS_UPDATED" and addon.GetAreaPoiDirtySections then
            dirty = addon:GetAreaPoiDirtySections()
        elseif (event == "QUEST_LOG_UPDATE" or event == "QUEST_TURNED_IN")
            and addon.GetQuestDirtySections then
            dirty = addon:GetQuestDirtySections()
        elseif (event == "CURRENCY_DISPLAY_UPDATE" or event == "BAG_UPDATE_DELAYED")
            and addon.GetCurrencyDirtySections then
            dirty = addon:GetCurrencyDirtySections()
        end
        if prepStart and addon.RecordEventPreparation then
            addon:RecordEventPreparation(event, prepStart)
        end
        if addon.UpdateDisplay then addon:UpdateDisplay(dirty) end
    elseif event == "PLAYER_LOGOUT" then
        if addon.SaveActiveProfile then addon:SaveActiveProfile() end
    end
    if prof then addon._updateReason = nil end
end)
