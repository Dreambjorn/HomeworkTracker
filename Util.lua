-- HomeworkTracker - Utils
local addonName, addon = ...

-- Constants
local DEFAULT_FONT_SIZE = 11
local DEFAULT_HEADER_FONT_SIZE = 14
local DEFAULT_FONT = "Friz Quadrata TT"
local DEFAULT_FONT_PATH = "Fonts\\FRIZQT__.TTF"

-- Holiday scanning, in months and seconds
local HOLIDAY_SCAN_PAST_MONTHS = 18
local HOLIDAY_SCAN_FUTURE_MONTHS = 12
local HOLIDAY_SCAN_DEBOUNCE = 0.3
local HOLIDAY_CACHE_LEASE = 604800
local HOLIDAY_RESCAN_COOLDOWN = 600
local GREAT_VAULT_NUDGE_EVERY = 10
-- Midnight Season 2 World rewards for vault
local DELVE_VAULT_ITEM_LEVELS = { 279, 282, 285, 289, 292, 295, 298, 305, 305, 305, 305, 305, 305 }

-- Arena and MDI realms keep their matching production cadence
local function GetEpochRegion(region)
    if type(region) ~= "number" then return 1 end
    if region >= 1 and region <= 5 then return region end
    if region >= 21 and region <= 25 then return region - 20 end
    if region >= 71 and region <= 75 then return region - 70 end
    return 1
end

-- Font system with LibSharedMedia
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

-- Cached game data
local _dataCache = {}
local CACHE_NIL = {} -- Marks a cache entry whose real value is nil (distinguishes from uncached)
local _timingResult = {} -- Reused table written by GetEventTiming; avoids creating a new table on every call
local _scheduledEventCache = {} -- Absolute starts avoid rebuilding the scheduler list every second
local _greatVaultRequeryFrame = nil -- Lightweight requery frame for missing Great Vault data
local _greatVaultRequeries = 0 -- Attempts so far, used only to space out the nudges
local _greatVaultRequeryHeld = false -- Asked for while the login gate was still shut
local VAULT_DIRTY = { GreatVault = true } -- Only the vault rows change on a requery

-- Holiday windows read off the calendar, keyed by event ID and by name
local _holidayCache = nil
local _holidayScanRunning = false
local _holidayScannedAt = nil
local _holidayStale = nil
local _holidayProvisional = nil -- Set when a scan came back empty, which means the calendar was not ready

-- Open the login gate and retry what it held back
function addon:AllowGreatVaultRequery()
    self._allowVaultRequery = true
    if not _greatVaultRequeryHeld then return end
    _greatVaultRequeryHeld = false
    self:InvalidateDataCache("greatVault")
    if self.UpdateDisplay then self:UpdateDisplay(VAULT_DIRTY) end
end

-- Drop cached lookups: everything, one namespace, or the single entry that changed
function addon:InvalidateDataCache(namespace, id)
    if not namespace then
        wipe(_dataCache)
    elseif id then
        _dataCache[namespace .. id] = nil
    else
        for key in pairs(_dataCache) do
            if string.find(key, namespace, 1, true) == 1 then _dataCache[key] = nil end
        end
    end
end

-- Re-reads the vault every half second until the data lands
function addon:RequestGreatVaultRequery()
    if not self._allowVaultRequery then
        _greatVaultRequeryHeld = true
        return
    end
    if _greatVaultRequeryFrame and _greatVaultRequeryFrame:IsShown() then
        _greatVaultRequeryFrame.t = 0
        return
    end

    if not _greatVaultRequeryFrame then
        _greatVaultRequeryFrame = CreateFrame("Frame")
    end
    _greatVaultRequeryFrame.t = 0
    _greatVaultRequeryFrame:Show()
    _greatVaultRequeryFrame:SetScript("OnUpdate", function(self, elapsed)
        local prof = addon._profile
        local profStart = prof and debugprofilestop() or nil
        self.t = (self.t or 0) + elapsed
        if self.t > 0.5 then
            self:Hide()
            self:SetScript("OnUpdate", nil)
            _greatVaultRequeries = _greatVaultRequeries + 1
            -- Occasional nudge makes the server resend; an open vault is left alone
            if (_greatVaultRequeries % GREAT_VAULT_NUDGE_EVERY) == 1 and C_WeeklyRewards.OnUIInteract
                and not (WeeklyRewardsFrame and WeeklyRewardsFrame:IsShown()) then
                -- Same paired calls the vault frame makes on show and hide, minus its sounds
                C_WeeklyRewards.OnUIInteract()
                C_Timer.After(0.06, function()
                    -- A vault opened meanwhile owns the interaction and closes it itself
                    if not (WeeklyRewardsFrame and WeeklyRewardsFrame:IsShown()) then
                        C_WeeklyRewards.CloseInteraction()
                    end
                end)
            end
            if profStart and addon.RecordVaultWait then addon:RecordVaultWait(profStart) end
            addon:InvalidateDataCache("greatVault")
            if addon.UpdateDisplay then addon:UpdateDisplay(VAULT_DIRTY) end
            return
        end
        if profStart and addon.RecordVaultWait then addon:RecordVaultWait(profStart) end
    end)
end


-- Saved font name
function addon:GetFontKey()
    return HomeworkTrackerDB.font or DEFAULT_FONT
end

-- Saved header font name
function addon:GetHeaderFontKey()
    return HomeworkTrackerDB.headerFont or DEFAULT_FONT
end

-- Save font name
function addon:SetFontKey(key)
    HomeworkTrackerDB.font = key or DEFAULT_FONT
end

-- Saved font size
function addon:GetFontSize()
    return HomeworkTrackerDB.fontSize or DEFAULT_FONT_SIZE
end

-- Saved header font size
function addon:GetHeaderFontSize()
    return HomeworkTrackerDB.headerFontSize or DEFAULT_HEADER_FONT_SIZE
end

-- Font file path
function addon:GetFontPath(fontKey)
    if LSM then
        local ok, path = pcall(LSM.Fetch, LSM, "font", fontKey or DEFAULT_FONT)
        if ok and path then return path end
    end
    return DEFAULT_FONT_PATH
end

-- Apply font safely
function addon:SetFont(fs, fontKey, size, flags)
    if not fs or not fs.SetFont then return false end
    local path = self:GetFontPath(fontKey or self:GetFontKey())
    local fontSize = size or self:GetFontSize()
    flags = flags or (HomeworkTrackerDB and HomeworkTrackerDB.fontOutline) or "OUTLINE"
    -- WoW rejects "NONE"; nil flags means no outline
    if flags == "NONE" then flags = nil end
    return pcall(fs.SetFont, fs, path, fontSize, flags)
end

-- Return current bar texture path, or nil
function addon:GetBarTexture()
    if LSM then
        local key = HomeworkTrackerDB and HomeworkTrackerDB.barTexture
        if not key or key == "" or key == "Default" then
            return nil
        end
        local ok, path = pcall(LSM.Fetch, LSM, "statusbar", key)
        if ok and path then return path end
    end
    return nil
end

-- Minimap button saved-var helpers
function addon:IsMinimapButtonEnabled()
    if HomeworkTrackerDB and HomeworkTrackerDB.showMinimapButton ~= nil then
        return HomeworkTrackerDB.showMinimapButton
    end
    if addon.defaults and addon.defaults.showMinimapButton ~= nil then
        return addon.defaults.showMinimapButton
    end
    return true
end

function addon:SetMinimapButtonEnabled(val)
    HomeworkTrackerDB = HomeworkTrackerDB or {}
    HomeworkTrackerDB.showMinimapButton = not not val
    if addon.UpdateMinimapButtonVisibility then
        addon:UpdateMinimapButtonVisibility()
    end
end

-- Format duration string
function addon:FormatTime(seconds)
    if seconds < 0 then seconds = 0 end
    if seconds >= 1209600 then
        return string.format("%dw %dd", math.floor(seconds / 604800), math.floor((seconds % 604800) / 86400))
    elseif seconds >= 86400 then
        return string.format("%dd %dh", math.floor(seconds / 86400), math.floor((seconds % 86400) / 3600))
    elseif seconds >= 3600 then
        return string.format("%dh %dm", math.floor(seconds / 3600), math.floor((seconds % 3600) / 60))
    elseif seconds >= 60 then
        return string.format("%dm %ds", math.floor(seconds / 60), seconds % 60)
    else
        return string.format("%ds", seconds)
    end
end

-- Quest completion check
function addon:IsQuestComplete(questID, accountWide)
    if not questID or type(questID) ~= "number" or questID == 0 then return false end

    if accountWide and C_QuestLog.IsQuestFlaggedCompletedOnAccount
        and C_QuestLog.IsQuestFlaggedCompletedOnAccount(questID) then
        return true
    end

    -- Try quest log first
    if C_QuestLog.GetLogIndexForQuestID then
        local qidx = C_QuestLog.GetLogIndexForQuestID(questID)
        if qidx then
            return C_QuestLog.IsComplete(questID)
        end
    end

    if C_QuestLog.IsOnQuest and C_QuestLog.IsOnQuest(questID) then
        return C_QuestLog.IsComplete(questID)
    end

    -- Flag fallback
    return C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(questID) or false
end

-- Current region
function addon:GetCurrentRegion()
    local cfg = (HomeworkTrackerDB and HomeworkTrackerDB.activities) or {}
    local regionForce = cfg.regionForce
    if type(regionForce) == "table" and regionForce.enable then
        return regionForce.region or GetCurrentRegion()
    end
    return GetCurrentRegion()
end

-- Reset time for a weekday
function addon:GetResetTimestampForWeekday(targetWeekday)
    local resetMap = {
        [1] = { weekday = 3, hour = 3 },
        [2] = { weekday = 4, hour = 3 },
        [3] = { weekday = 3, hour = 3 },
        [4] = { weekday = 4, hour = 3 },
        [5] = { weekday = 4, hour = 3 },
    }

    local region = self:GetCurrentRegion() or 1
    local resetInfo = resetMap[region]
    if not resetInfo then return nil end

    local cal = C_DateAndTime.GetCurrentCalendarTime()
    if not cal then return nil end

    local now = GetServerTime()
    local secondsSinceMidnight = (cal.hour * 3600) + (cal.minute * 60)
    local todayReset = now - secondsSinceMidnight + (resetInfo.hour * 3600)

    local diffDays = ((cal.weekday - targetWeekday) + 7) % 7
    local candidate = todayReset - (diffDays * 24 * 3600)
    if candidate > now then
        candidate = candidate - (7 * 24 * 3600)
    end
    return candidate
end

-- Within weekend window
function addon:IsWithinWeekendWindow()
    local now = GetServerTime()
    local satReset = self:GetResetTimestampForWeekday(7)
    local monReset = self:GetResetTimestampForWeekday(2)
    if not satReset or not monReset then return false end

    -- Keep Monday after Saturday
    if monReset <= satReset then
        monReset = monReset + (7 * 24 * 3600)
    end

    return now >= satReset and now < monReset
end

-- Return true if player is in a major city
function addon:IsInMajorCity()
    if not addon.majorCities or not next(addon.majorCities) then return false end
    if not C_Map or not C_Map.GetBestMapForUnit then return false end
    local uiMapID = C_Map.GetBestMapForUnit("player")
    if not uiMapID then return false end
    return addon.majorCities[uiMapID] == true
end

-- "<Expansion> Dungeon Event" as the calendar spells it, used as a fallback
function addon:GetCurrentDungeonEventName()
    local level = GetExpansionLevel and GetExpansionLevel()
    local name = level and _G["EXPANSION_NAME" .. level]
    if not name or name == "" then return "Dungeon Event" end
    return name .. " Dungeon Event"
end

-- Reputations the player has not started yet
function addon:IsReputationUnstarted(info, isMaxed)
    if not info or isMaxed or info.isParagon then return false end
    if info.renownReputationEarned ~= 0 then return false end

    if info.isRenown then
        return info.isUnlocked == false
    elseif info.isStandard then
        return info.isFirstRank == true
    elseif info.isFriend then
        return true
    end

    return false
end

-- Great Vault slot detail, as shown in the section tooltip
function addon:GetGreatVaultSlotDetail(slotKey, entry)
    if not entry then return nil, false end

    local progress = entry.progress or 0
    local threshold = entry.threshold or 0
    if threshold <= 0 or progress < threshold then
        return string.format("%d/%d", progress, threshold), false
    end

    local parts = {}
    local level = entry.level
    if slotKey == "mythicPlus" and level and level > 0 then
        table.insert(parts, "+" .. level)
    elseif slotKey == "delves" and level and level > 0 then
        table.insert(parts, "Tier " .. level)
    elseif slotKey == "raid" and entry.difficultyId
        and DifficultyUtil and DifficultyUtil.GetDifficultyName then
        table.insert(parts, DifficultyUtil.GetDifficultyName(entry.difficultyId) or "")
    end

    if entry.itemLevel then
        if entry.upgradeItemLevel and entry.upgradeItemLevel > entry.itemLevel then
            table.insert(parts, string.format("ILVL %d (up to %d)", entry.itemLevel, entry.upgradeItemLevel))
        else
            table.insert(parts, string.format("ILVL %d", entry.itemLevel))
        end
    end

    if #parts == 0 then return "Unlocked", true end
    return table.concat(parts, "  "), true
end

-- Zone name for a map, or nil when the map is unknown
function addon:GetMapName(uiMapID)
    if not (uiMapID and C_Map and C_Map.GetMapInfo) then return nil end
    local info = C_Map.GetMapInfo(uiMapID)
    return info and info.name or nil
end

-- Where a weekly sends the player: quest giver if known, else its zone
function addon:GetWeeklyLocation(quest)
    if not (quest and quest.mapID) then return nil end
    return quest.mapID, quest.x, quest.y
end

-- Open the world map on a zone without tainting it
function addon:OpenWorldMapTo(uiMapID)
    if not uiMapID then return false end
    if InCombatLockdown() then return false end
    if C_Map and C_Map.OpenWorldMap then
        C_Map.OpenWorldMap(uiMapID)
        return true
    end
    if WorldMapFrame and WorldMapFrame.SetMapID then
        ShowUIPanel(WorldMapFrame)
        WorldMapFrame:SetMapID(uiMapID)
        return true
    end
    return false
end

-- Blizzard waypoint support helpers
function addon:CanSetBlizzardWaypoint(mapID, x, y)
    return C_Map and C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(mapID) and x and y
end

function addon:SetBlizzardWaypoint(mapID, x, y)
    if not self:CanSetBlizzardWaypoint(mapID, x, y) then return false end
    if not UiMapPoint or not UiMapPoint.CreateFromCoordinates then return false end
    local uiMapPoint = UiMapPoint.CreateFromCoordinates(mapID, x, y)
    if not uiMapPoint then return false end
    if C_Map and C_Map.SetUserWaypoint then
        C_Map.SetUserWaypoint(uiMapPoint)
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
            C_SuperTrack.SetSuperTrackedUserWaypoint(true)
        end
        return true
    end
    return false
end

-- Great Vault progress
function addon:GetGreatVaultInfo()
    if _dataCache.greatVault then return _dataCache.greatVault end

    local data = {
        raid = {},
        mythicPlus = {},
        delves = {},
    }
    local requeryNeeded = false
    
    -- Query weekly rewards for each chest type
    local types = {
        Enum.WeeklyRewardChestThresholdType.Raid,
        Enum.WeeklyRewardChestThresholdType.Activities,
        Enum.WeeklyRewardChestThresholdType.World,
    }

    for _, t in ipairs(types) do
        local ok, activities = pcall(C_WeeklyRewards.GetActivities, t)
        if ok and activities then
            for _, activity in ipairs(activities) do
                local entry = {
                    level = activity.level,
                    progress = activity.progress,
                    threshold = activity.threshold,
                    id = activity.id,
                    activityInfo = activity,
                }
                -- Blizzard's World reward links can return valid but stale item levels
                if activity.type == Enum.WeeklyRewardChestThresholdType.World then
                    entry.itemLevel = DELVE_VAULT_ITEM_LEVELS[entry.level]
                    entry.upgradeItemLevel = DELVE_VAULT_ITEM_LEVELS[(entry.level or 0) + 1]
                end

                -- Try to get Blizzard's example reward item level
                if not entry.itemLevel and entry.id and C_WeeklyRewards and C_WeeklyRewards.GetExampleRewardItemHyperlinks then
                    local ok2, itemLink, upgradeLink = pcall(C_WeeklyRewards.GetExampleRewardItemHyperlinks, entry.id)
                    if ok2 and itemLink and itemLink ~= "" and itemLink ~= "[]" and C_Item and C_Item.GetDetailedItemLevelInfo then
                        local ok3, ilvl = pcall(C_Item.GetDetailedItemLevelInfo, itemLink)
                        if ok3 and ilvl and ilvl > 0 then entry.itemLevel = ilvl end
                    end
                    if ok2 and upgradeLink and upgradeLink ~= "" and upgradeLink ~= "[]" and C_Item and C_Item.GetDetailedItemLevelInfo then
                        local ok4, uilvl = pcall(C_Item.GetDetailedItemLevelInfo, upgradeLink)
                        if ok4 and uilvl and uilvl > 0 then entry.upgradeItemLevel = uilvl end
                    end
                end

                if activity.type == Enum.WeeklyRewardChestThresholdType.Activities then
                    table.insert(data.mythicPlus, entry)
                elseif activity.type == Enum.WeeklyRewardChestThresholdType.Raid then
                    table.insert(data.raid, entry)
                elseif activity.type == Enum.WeeklyRewardChestThresholdType.World then
                    table.insert(data.delves, entry)
                end

                if entry.progress >= (entry.threshold or 0) and not entry.itemLevel then
                    requeryNeeded = true
                end
            end
        end
    end
    
    _dataCache.greatVault = data
    if not requeryNeeded then _greatVaultRequeries = 0 end
    if requeryNeeded then
        self:RequestGreatVaultRequery()
    end
    return data
end

-- Currency info
function addon:GetCurrencyInfo(currencyID)
    local cacheKey = "currency_" .. currencyID
    local cached = _dataCache[cacheKey]
    if cached ~= nil then return cached ~= CACHE_NIL and cached or nil end

    local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
    if info then
        local maxQty = info.maxQuantity or 0
        if self.currencyDB then
            for _, c in ipairs(self.currencyDB) do
                if c.id == currencyID and c.max and c.max > 0 then
                    maxQty = c.max
                    break
                end
            end
        end
        local result = {
            quantity = info.quantity or 0,
            maxQuantity = maxQty,
            totalEarned = info.totalEarned or 0,
            useTotalEarnedForMaxQty = info.useTotalEarnedForMaxQty,
            iconFileID = info.iconFileID,
        }
        _dataCache[cacheKey] = result
        return result
    end

    local itemCount = C_Item.GetItemCount(currencyID, true, false, true, true)
    if itemCount and itemCount > 0 then
        local name, _, icon = C_Item.GetItemInfo(currencyID)
        local result = {
            quantity = itemCount,
            maxQuantity = 0,
            totalEarned = itemCount,
            useTotalEarnedForMaxQty = false,
            iconFileID = icon,
            name = name,
        }
        _dataCache[cacheKey] = result
        return result
    end

    _dataCache[cacheKey] = CACHE_NIL
    return nil
end

-- Renown progress
function addon:GetProgressInfo(progressID)
    local cacheKey = "progress_" .. progressID
    local cached = _dataCache[cacheKey]
    if cached ~= nil then return cached ~= CACHE_NIL and cached or nil end

    local majorData = C_MajorFactions.GetMajorFactionData(progressID)
    if majorData then
        local isMaxed = C_MajorFactions.HasMaximumRenown(progressID)
        local result = {
            name = majorData.name,
            renownLevel = majorData.renownLevel or 0,
            renownReputationEarned = majorData.renownReputationEarned or 0,
            renownLevelThreshold = majorData.renownLevelThreshold or 1,
            isMaxed = isMaxed,
            isRenown = true,
            isUnlocked = majorData.isUnlocked,
        }
        _dataCache[cacheKey] = result
        return result
    end

    _dataCache[cacheKey] = CACHE_NIL
    return nil
end

-- Paragon overlay for a reputation that has nothing left to rank up
local function ApplyParagonInfo(result, repID)
    if not (result and result.isMaxed) then return result end
    if not (C_Reputation and C_Reputation.IsFactionParagon and C_Reputation.IsFactionParagon(repID)) then
        return result
    end

    local value, threshold, _, hasRewardPending = C_Reputation.GetFactionParagonInfo(repID)
    if not value or not threshold or threshold <= 0 then return result end

    result.isParagon = true
    result.isMaxed = false
    result.hasRewardPending = hasRewardPending == true
    result.paragonLevel = math.floor(value / threshold)
    result.renownLevelThreshold = threshold
    result.renownReputationEarned = result.hasRewardPending and threshold or (value % threshold)

    ---@diagnostic disable-next-line: undefined-field
    local label = _G.PARAGON or "Paragon"
    if result.paragonLevel > 0 then label = label .. " " .. result.paragonLevel end
    result.label = label

    return result
end

-- Faction reputation info
function addon:GetReputationInfo(repID)
    local cacheKey = "rep_" .. repID
    local cached = _dataCache[cacheKey]
    if cached ~= nil then return cached ~= CACHE_NIL and cached or nil end

    -- 1. Renown
    local majorData = C_MajorFactions.GetMajorFactionData(repID)
    if majorData then
        local isMaxed = C_MajorFactions.HasMaximumRenown(repID)
        local result = {
            name = majorData.name,
            renownLevel = majorData.renownLevel or 0,
            renownReputationEarned = majorData.renownReputationEarned or 0,
            renownLevelThreshold = majorData.renownLevelThreshold or 1,
            isMaxed = isMaxed,
            isRenown = true,
            isUnlocked = majorData.isUnlocked,
        }
        _dataCache[cacheKey] = ApplyParagonInfo(result, repID)
        return result
    end
    
    -- 2. Friendship
    local friendshipData = C_GossipInfo.GetFriendshipReputation(repID)
    if friendshipData and friendshipData.friendshipFactionID and friendshipData.friendshipFactionID > 0 then
        local isMaxed = not friendshipData.nextThreshold
        local current = friendshipData.standing - friendshipData.reactionThreshold
        local max = 1
        
        if isMaxed then
            current = 1
        else
            max = friendshipData.nextThreshold - friendshipData.reactionThreshold
        end
        
        local result = {
            name = friendshipData.name,
            label = friendshipData.reaction, -- e.g. 'Acquaintance'
            renownReputationEarned = current,
            renownLevelThreshold = max,
            isMaxed = isMaxed,
            isFriend = true
        }
        _dataCache[cacheKey] = ApplyParagonInfo(result, repID)
        return result
    end

    -- 3. Standard
    local repData = C_Reputation.GetFactionDataByID(repID)
    if repData then
        local isMaxed = not repData.nextReactionThreshold
        local current = repData.currentStanding - repData.currentReactionThreshold
        local max
        if not isMaxed then
            max = repData.nextReactionThreshold - repData.currentReactionThreshold
        else
            current = 1
            max = 1
        end
        
        -- e.g. "Neutral", "Friendly"
        local label = _G["FACTION_STANDING_LABEL" .. repData.reaction] or repData.reaction
        
        local isFirstRank = repData.currentReactionThreshold == 0
        local result = {
            name = repData.name,
            label = label,
            reaction = repData.reaction,
            renownReputationEarned = current,
            renownLevelThreshold = max,
            isMaxed = isMaxed,
            isStandard = true,
            isFirstRank = isFirstRank,
        }
        _dataCache[cacheKey] = ApplyParagonInfo(result, repID)
        return result
    end
    
    _dataCache[cacheKey] = CACHE_NIL
    return nil
end

-- Event display name
function addon:GetEventName(eventKey)
    local lang = GetLocale()
    local event = self.eventDB[eventKey]
    if not event then return eventKey end
    if type(event.name) == "string" then return event.name end
    return event.name[lang] or event.name["enUS"] or eventKey
end

-- Event completion check
function addon:IsEventComplete(eventKey)
    local event = self.eventDB[eventKey]
    if not event then return false end
    -- World events run on the calendar and have no quest to complete
    if not event.questID then return false end

    local questP, questT = 0, event.questReq
    for _, questID in pairs(event.questID) do
        if questID ~= 0 then
            questP = self:IsQuestComplete(questID) and questP + 1 or questP
        end
    end
    
    return questP == questT
end

-- time() reads its table as local time, but calendar times are realm time
local function ServerTimeSkew()
    if not (C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime) then return 0 end
    local now = C_DateAndTime.GetCurrentCalendarTime()
    if not now then return 0 end
    local year, month, day = now.year, now.month, now.monthDay
    local hour, minute = now.hour or 0, now.minute or 0
    if not (year and month and day) then return 0 end
    local asLocal = time({ year = year, month = month, day = day, hour = hour, min = minute, sec = 0 })
    local raw = (asLocal or 0) - GetServerTime()
    return math.floor(raw / 900 + 0.5) * 900
end

-- Calendar time table to a server epoch
local function CalendarTimeToEpoch(t)
    if type(t) == "number" then return t end
    if type(t) ~= "table" then return nil end

    local year, month, day = t.year, t.month, t.monthDay or t.day
    local hour, minute = t.hour or 0, t.minute or 0
    if not (year and month and day) then return nil end

    local asLocal = time({ year = year, month = month, day = day, hour = hour, min = minute, sec = 0 })
    if not asLocal then return nil end
    return asLocal - ServerTimeSkew()
end

-- Lowercased holiday names, worked out once and kept on the event
local function LowerNames(event)
    if not event.holidayNames then return nil end
    if not event.lowerNames then
        local lowered = {}
        for i, name in ipairs(event.holidayNames) do lowered[i] = name:lower() end
        event.lowerNames = lowered
    end
    return event.lowerNames
end

-- True when any world event is switched on
function addon:WantsHolidayData()
    local cfg = HomeworkTrackerDB and HomeworkTrackerDB.activities
    if not cfg then return false end
    for key, event in pairs(self.eventDB or {}) do
        if cfg[key] and (event.holidayID or event.holidayNames) then return true end
    end
    return false
end

-- Holidays the player asked to see, by ID and by lowercased name
local function WantedHolidays()
    local cfg = HomeworkTrackerDB and HomeworkTrackerDB.activities
    if not cfg then return nil, nil, 0 end

    local ids, names, count = {}, {}, 0
    for key, event in pairs(addon.eventDB or {}) do
        if cfg[key] and (event.holidayID or event.holidayNames) then
            for _, id in ipairs(event.holidayID or {}) do
                if not ids[id] then ids[id] = true; count = count + 1 end
            end
            local lowered = LowerNames(event)
            for _, name in ipairs(lowered or {}) do
                if not names[name] then names[name] = true; count = count + 1 end
            end
        end
    end
    return ids, names, count
end

local function RecordHoliday(store, key, entry)
    local windows = store[key]
    if not windows then
        windows = {}
        store[key] = windows
    end
    for i = 1, #windows do
        local saved = windows[i]
        if saved.startTime == entry.startTime and saved.endTime == entry.endTime then return end
    end
    windows[#windows + 1] = entry
end

-- Read one month, taking every opening entry of each wanted holiday
local function ScanCalendarMonth(found, wantedIds, wantedNames, numDays)
    for day = 1, (numDays or 31) do
        local count = C_Calendar.GetNumDayEvents(0, day) or 0
        for index = 1, count do
            local e = C_Calendar.GetDayEvent(0, day, index)
            if e and e.calendarType == "HOLIDAY"
                and (not e.sequenceType or e.sequenceType == "" or e.sequenceType == "START") then

                local id, name = e.eventID, e.title
                if (id and wantedIds[id]) or (name and wantedNames[name:lower()]) then
                    local startTime = CalendarTimeToEpoch(e.startTime)
                    local endTime = CalendarTimeToEpoch(e.endTime)
                    if startTime and endTime then
                        local entry = { name = name, startTime = startTime, endTime = endTime }
                        if id then RecordHoliday(found.byID, id, entry) end
                        if name then RecordHoliday(found.byName, name:lower(), entry) end
                    end
                end
            end
        end
    end
end

-- The scan result survives a reload, so most sessions never touch the calendar
local function LoadStoredHolidays()
    local store = HomeworkTrackerAccountDB and HomeworkTrackerAccountDB.__holidays
    if type(store) ~= "table" then return nil end
    if type(store.lease) ~= "number" or store.lease <= GetServerTime() then return nil end
    if type(store.byID) ~= "table" or type(store.byName) ~= "table" then return nil end
    -- Dates worked out under a different clock offset are an hour out
    if store.skew ~= ServerTimeSkew() then return nil end
    return { byID = store.byID, byName = store.byName }
end

local function StoreHolidays(found)
    if type(HomeworkTrackerAccountDB) ~= "table" then return end
    HomeworkTrackerAccountDB.__holidays = {
        lease = GetServerTime() + HOLIDAY_CACHE_LEASE,
        skew = ServerTimeSkew(),
        byID = found.byID,
        byName = found.byName,
    }
end

-- Flipping several options in a row should cost one scan, not one per click
local ScheduleHolidayScan
do
    local queued, lastRun
    ScheduleHolidayScan = function()
        if queued then return end
        -- The first change runs at once; only a burst behind it waits
        if not lastRun or (GetTime() - lastRun) >= HOLIDAY_SCAN_DEBOUNCE then
            lastRun = GetTime()
            addon:RequestHolidayScan()
            return
        end
        queued = true
        C_Timer.After(HOLIDAY_SCAN_DEBOUNCE, function()
            queued = false
            lastRun = GetTime()
            addon:RequestHolidayScan()
        end)
    end
end

-- Walk calendar history through the next year in one pass
function addon:RequestHolidayScan()
    if _holidayScanRunning then return end
    if _holidayCache and not _holidayStale then return end

    local wantedIds, wantedNames, count = WantedHolidays()
    if not wantedIds or count == 0 then
        _holidayCache = { byID = {}, byName = {} }
        _holidayScannedAt = GetTime()
        _holidayStale = nil
        _holidayProvisional = nil
        return
    end

    if not _holidayStale then
        local stored = LoadStoredHolidays()
        if stored then
            _holidayCache = stored
            _holidayScannedAt = GetTime()
            _holidayProvisional = nil
            return
        end
    end

    if not (C_Calendar and C_Calendar.GetNumDayEvents and C_Calendar.GetDayEvent
        and C_Calendar.SetAbsMonth and C_Calendar.SetMonth and C_Calendar.GetMonthInfo) then
        return
    end

    local today = C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime
        and C_DateAndTime.GetCurrentCalendarTime()
    if not (today and today.month and today.year) then return end

    -- The calendar UI shares this reference month, so put it back afterwards
    local saved = C_Calendar.GetMonthInfo(0)
    local savedMonth = saved and saved.month or today.month
    local savedYear = saved and saved.year or today.year

    _holidayScanRunning = true
    _holidayStale = nil

    local found = { byID = {}, byName = {} }
    C_Calendar.SetAbsMonth(today.month, today.year)
    C_Calendar.SetMonth(-HOLIDAY_SCAN_PAST_MONTHS)
    for _ = -HOLIDAY_SCAN_PAST_MONTHS, HOLIDAY_SCAN_FUTURE_MONTHS do
        local info = C_Calendar.GetMonthInfo(0)
        local numDays = info and info.numDays or 31
        ScanCalendarMonth(found, wantedIds, wantedNames, numDays)
        C_Calendar.SetMonth(1)
    end
    C_Calendar.SetAbsMonth(savedMonth, savedYear)

    _holidayProvisional = (next(found.byID) == nil and next(found.byName) == nil) or nil
    if _holidayProvisional then
        found = LoadStoredHolidays() or found
    else
        StoreHolidays(found)
    end

    _holidayCache = found
    _holidayScannedAt = GetTime()
    _holidayScanRunning = false
    if addon.UpdateDisplay then
        C_Timer.After(0, function() addon:UpdateDisplay() end)
    end
end

-- Rescan only for an event switched on whose dates are not cached already
function addon:EnsureHolidayScanned(eventKey)
    local event = self.eventDB and self.eventDB[eventKey]
    if not (event and (event.holidayID or event.holidayNames)) then return end
    if _holidayCache and self:GetHolidayWindow(event) then return end
    self:InvalidateHolidayCache(true)
end

-- Drop the cached scan so the next lookup rebuilds it
function addon:InvalidateHolidayCache(force)
    if _holidayScanRunning then return end
    if not force and not _holidayProvisional and _holidayScannedAt
        and (GetTime() - _holidayScannedAt) < HOLIDAY_RESCAN_COOLDOWN then
        return
    end
    if force and type(HomeworkTrackerAccountDB) == "table" then
        HomeworkTrackerAccountDB.__holidays = nil
    end
    -- Marked rather than dropped, so what is on screen survives the rescan
    _holidayStale = true
    ScheduleHolidayScan()
end

local function SoonestHolidayWindow(windows, now, best)
    if type(windows) ~= "table" then return best end
    if windows.startTime then windows = { windows } end
    for i = 1, #windows do
        local entry = windows[i]
        if type(entry) == "table" and type(entry.startTime) == "number"
            and type(entry.endTime) == "number" and entry.endTime > now
            and (not best or entry.startTime < best.startTime) then
            best = entry
        end
    end
    return best
end

-- Start and end of the soonest unfinished holiday occurrence
function addon:GetHolidayWindow(event)
    if not _holidayCache or _holidayStale then
        ScheduleHolidayScan()
        if not _holidayCache then return nil end
    end

    local now = GetServerTime()
    local best, bestID

    local byID = _holidayCache.byID
    if event.holidayID then
        for i = 1, #event.holidayID do
            local id = event.holidayID[i]
            local entry = SoonestHolidayWindow(byID[id], now, best)
            if entry ~= best then best, bestID = entry, id end
        end
    end

    -- Names are only a fallback for a calendar entry that carried no ID
    if not best then
        local lowered = LowerNames(event)
        if lowered then
            local byName = _holidayCache.byName
            for i = 1, #lowered do
                best = SoonestHolidayWindow(byName[lowered[i]], now, best)
            end
        end
    end

    if not best then return nil end
    return best.startTime, best.endTime, best.name, bestID
end

-- Timing for a calendar holiday, which has no fixed cycle to compute from
function addon:GetHolidayTiming(event)
    local startTime, endTime, name, id = self:GetHolidayWindow(event)
    if not startTime then return nil end

    -- Recover the timewalking expansion from the event ID
    local label = id and event.holidayLabels and event.holidayLabels[id]
    if label then name = (event.name or name) .. ": " .. label end

    local now = GetServerTime()
    local active = now >= startTime

    _timingResult.active         = active
    _timingResult.remaining      = active and (endTime - now) or (startTime - now)
    _timingResult.next           = startTime - now
    _timingResult.duration       = endTime - startTime
    _timingResult.expirationTime = GetTime() + _timingResult.remaining
    _timingResult.color          = event.color
    _timingResult.alert          = false
    _timingResult.holidayName    = name
    _timingResult.holidayLabel   = label
    return _timingResult
end

-- Drop cached scheduler entries when Blizzard announces new event data
function addon:InvalidateEventSchedule()
    wipe(_scheduledEventCache)
end

-- Read the next matching event directly from Blizzard's Event Schedule
function addon:GetScheduledEventTiming(eventKey, event)
    local api = C_EventScheduler
    if not (api and api.GetScheduledEvents) then return nil end

    local now = time()
    local nextEvent = _scheduledEventCache[eventKey]
    if not nextEvent or nextEvent.startTime <= now then
        nextEvent = nil
        local events = api.GetScheduledEvents()
        if type(events) ~= "table" then
            if (not api.HasData or not api.HasData()) and api.RequestEvents then
                api.RequestEvents()
            end
            return nil
        end

        for _, entry in ipairs(events) do
            if type(entry) == "table" and event.schedulerPoiNames[entry.areaPoiID]
                and entry.duration == event.schedulerDuration
                and type(entry.startTime) == "number" and entry.startTime > now
                and (not nextEvent or entry.startTime < nextEvent.startTime) then
                nextEvent = {
                    areaPoiID = entry.areaPoiID,
                    startTime = entry.startTime,
                    duration = entry.duration,
                }
            end
        end
        _scheduledEventCache[eventKey] = nextEvent
    end

    if not nextEvent then return nil end
    local name = event.schedulerPoiNames[nextEvent.areaPoiID]
    if C_AreaPoiInfo and C_AreaPoiInfo.GetAreaPOIInfo then
        local info = C_AreaPoiInfo.GetAreaPOIInfo(nil, nextEvent.areaPoiID)
        if info and info.name then name = info.name end
    end

    local remaining = nextEvent.startTime - now
    _timingResult.active         = false
    _timingResult.remaining      = remaining
    _timingResult.next           = remaining
    _timingResult.duration       = nextEvent.duration
    _timingResult.expirationTime = GetTime() + remaining
    _timingResult.color          = event.color
    _timingResult.alert          = false
    _timingResult.holidayName    = name
    _timingResult.holidayLabel   = nil
    return _timingResult
end

-- Event timing and alerts
function addon:GetEventTiming(eventKey)
    local event = self.eventDB[eventKey]
    if not event then return nil end

    if event.schedulerPoiNames then return self:GetScheduledEventTiming(eventKey, event) end
    if event.holidayID or event.holidayNames then return self:GetHolidayTiming(event) end
    
    local cfg = (HomeworkTrackerDB and HomeworkTrackerDB.activities) or {}
    local region = GetEpochRegion(self:GetCurrentRegion())
    local first = event.epoch[region]
    local interval = event.interval
    local duration = event.duration
    local timerOffset = cfg.timerOffset or {}
    local eventAlerts = cfg.eventAlerts or {}
    local offset = (timerOffset[eventKey] or 0) * 60
    
    local currentTime = GetServerTime() + offset
    local timeSinceFirst = (currentTime - first) % interval
    local next = interval - timeSinceFirst
    local active = timeSinceFirst < duration
    local remaining = active and (duration - timeSinceFirst) or next
    
    local alertEnabled = false
    if type(eventAlerts[eventKey]) == "boolean" then
        alertEnabled = eventAlerts[eventKey]
    elseif type(event.alert) == "number" then
        -- Legacy fallback
        alertEnabled = eventAlerts[event.alert] or false
    end

    _timingResult.active         = active
    _timingResult.remaining      = remaining
    _timingResult.next           = next
    _timingResult.duration       = active and duration or (interval - duration)
    _timingResult.expirationTime = GetTime() + remaining
    _timingResult.color          = event.color
    _timingResult.alert          = alertEnabled
    -- Shared table, so clear what only the holiday path sets
    _timingResult.holidayName    = nil
    _timingResult.holidayLabel   = nil
    return _timingResult
end

-- The expansion an event is currently running, when it names one
function addon:GetEventExpansionLabel(eventKey)
    local timing = self:GetEventTiming(eventKey)
    return timing and timing.holidayLabel
end

-- Colour for a named expansion, the player's own pick before the built-in one
function addon:GetExpansionColor(label)
    if not label then return nil end
    local colors = HomeworkTrackerDB and HomeworkTrackerDB.colors
    local saved = colors and colors.expansions and colors.expansions[label]
    if saved then return unpack(saved) end
    if not (self.expansionColors and self.expansionColors[label]) then return nil end
    return unpack(self.expansionColors[label])
end

-- The variant of a rotating weekly that is up: held, or live out in the world
function addon:IsQuestUp(questID)
    if not questID then return false end
    if C_QuestLog.IsOnQuest and C_QuestLog.IsOnQuest(questID) then return true end
    if C_TaskQuest and C_TaskQuest.IsActive and C_TaskQuest.IsActive(questID) then return true end
    return false
end

-- Weekly quest status
function addon:GetWeeklyQuestInfo()
    if _dataCache.weeklyQuests then return _dataCache.weeklyQuests end

    local quests = {}
    for _, quest in ipairs(self.weeklyDB) do
        if not quest.isWeekend or self:IsWithinWeekendWindow() then
            local questIDs = {}
            local preyCounts = nil
            local preyQuestIDs = nil
            if type(quest.questID) == "table" then
                local function append(list)
                    if type(list) == "table" then
                        for _, qid in ipairs(list) do table.insert(questIDs, qid) end
                    end
                end

                if quest.questID.normal or quest.questID.hard or quest.questID.nightmare then
                    append(quest.questID.normal)
                    append(quest.questID.hard)
                    append(quest.questID.nightmare)

                    local perDifficultyCap = (type(quest.max) == "number") and quest.max or 4
                    local function count(list)
                        if type(list) ~= "table" then return 0 end
                        local c = 0
                        for _, qid in ipairs(list) do
                            if self:IsQuestComplete(qid, quest.accountWide) then c = c + 1 end
                            if c >= perDifficultyCap then break end
                        end
                        return c
                    end

                    preyCounts = {
                        normal = count(quest.questID.normal),
                        hard = count(quest.questID.hard),
                        nightmare = count(quest.questID.nightmare),
                    }
                    preyQuestIDs = {
                        normal = (type(quest.questID.normal) == "table") and quest.questID.normal or nil,
                        hard = (type(quest.questID.hard) == "table") and quest.questID.hard or nil,
                        nightmare = (type(quest.questID.nightmare) == "table") and quest.questID.nightmare or nil,
                    }
                else
                    append(quest.questID)
                end
            else
                table.insert(questIDs, quest.questID)
            end
            local isComplete = false
            local isAccepted = false
            local completed = 0
            local info = ""
            local questMapID, questX, questY = quest.mapID, quest.x, quest.y

            for _, qid in ipairs(questIDs) do
                if C_QuestLog.IsOnQuest and C_QuestLog.IsOnQuest(qid) then
                    isAccepted = true
                    break
                end
            end
            
            if quest.questType == "simple" then
                isComplete = self:IsQuestComplete(questIDs[1], quest.accountWide)
                completed = isComplete and 1 or 0
                
            elseif quest.questType == "single" then
                -- Active variant; fallback to flagged
                local activeFound = false
                local activeComplete = false
                for _, qid in ipairs(questIDs) do
                    if self:IsQuestUp(qid) then
                        activeFound = true
                        if self:IsQuestComplete(qid, quest.accountWide) then
                            activeComplete = true
                        end
                        break
                    end
                end

                if activeFound then
                    isComplete = activeComplete
                    completed = activeComplete and 1 or 0
                else
                    local flagged = 0
                    for _, qid in ipairs(questIDs) do
                        if self:IsQuestComplete(qid, quest.accountWide) then
                            flagged = flagged + 1
                        end
                    end
                    isComplete = (flagged >= 1)
                    completed = flagged
                end

                -- Name the variant that is up, whether it is done yet or not
                if quest.labels or quest.locations then
                    for _, qid in ipairs(questIDs) do
                        if self:IsQuestComplete(qid, quest.accountWide) or self:IsQuestUp(qid) then
                            info = (quest.labels and quest.labels[qid]) or info
                            local place = quest.locations and quest.locations[qid]
                            if place then
                                questMapID, questX, questY = place.mapID, place.x, place.y
                            end
                            if info ~= "" or place then break end
                        end
                    end
                end
                
            elseif quest.questType == "multiple" then
                local totalRequired = (type(quest.max) == "number") and quest.max or #questIDs
                for _, qid in ipairs(questIDs) do
                    if self:IsQuestComplete(qid, quest.accountWide) then
                        completed = completed + 1
                    end
                end

                if completed > totalRequired then completed = totalRequired end
                isComplete = (completed >= totalRequired)

                if preyCounts then
                    local needed = (type(quest.max) == "number") and quest.max or 4
                    local n = tonumber(preyCounts.normal) or 0
                    local h = tonumber(preyCounts.hard) or 0
                    local m = tonumber(preyCounts.nightmare) or 0
                    isComplete = (n >= needed) and (h >= needed) and (m >= needed)
                end

                info = completed .. "/" .. totalRequired
            end
            
            table.insert(quests, {
                name = quest.name,
                expansion = quest.expansion,
                isComplete = isComplete,
                isAccepted = isAccepted,
                info = info,
                progress = completed,
                required = quest.questType == "multiple" and #questIDs or 1,
                category = quest.category,
                handler = quest.handler,
                mapID = questMapID,
                x = questX,
                y = questY,
                max = quest.max,
                preyCounts = preyCounts,
                preyQuestIDs = preyQuestIDs,
            })
        end
    end
    
    _dataCache.weeklyQuests = quests

    -- Sort once here so UpdateWeeklySection never needs to sort the cached table
    table.sort(quests, function(a, b)
        local catA = a.category or "general"
        local catB = b.category or "general"
        local infoA = addon.categoryInfo and addon.categoryInfo[catA]
        local infoB = addon.categoryInfo and addon.categoryInfo[catB]
        local orderA = infoA and infoA.order or 99
        local orderB = infoB and infoB.order or 99
        if orderA ~= orderB then return orderA < orderB end
        return a.name < b.name
    end)

    return quests
end

-- Rare NPC data
function addon:GetRareInfo(currentZone)
    local resolvedZone = currentZone
    if currentZone and addon.zoneAliases then
        resolvedZone = addon.zoneAliases[currentZone] or currentZone
    end
    local cacheKey = "rares_" .. (resolvedZone or "_all")
    if _dataCache[cacheKey] then return _dataCache[cacheKey] end

    local rares = {}
    
    for _, rare in ipairs(self.raresDB) do
        local match = true
        if resolvedZone then
            match = (rare.zone == resolvedZone) or
                   (string.find(resolvedZone, rare.zone, 1, true) ~= nil) or
                   (string.find(rare.zone, resolvedZone, 1, true) ~= nil)
        end
        -- skip based on faction flag if present
        if match and rare.faction then
            local playerFaction = UnitFactionGroup("player")
            if rare.faction ~= playerFaction then
                match = false
            end
        end
        
        if match then
            local isComplete = self:IsQuestComplete(rare.questID)
            local isRepComplete = rare.repQuestID and self:IsQuestComplete(rare.repQuestID) or false
            
            table.insert(rares, {
                expansion = rare.expansion,
                name = rare.name,
                npcID = rare.npcID,
                questID = rare.questID,
                repQuestID = rare.repQuestID,
                zone = rare.zone,
                mapID = rare.mapID,
                faction = rare.faction,
                x = rare.x,
                y = rare.y,
                isComplete = isComplete,
                isRepComplete = isRepComplete,
                phaseDivingRequired = rare.phaseDivingRequired or false,
            })
        end
    end
    
    _dataCache[cacheKey] = rares
    return rares
end

-- What the bountiful delves currently on offer look like, for spotting a real change
function addon:GetBountifulDelveSignature()
    local delves = self:GetBountifulDelveInfo()
    if not delves or #delves == 0 then return "" end
    local parts = {}
    for i = 1, #delves do
        local delve = delves[i]
        parts[i] = tostring(delve.delveID) .. ":" .. tostring(delve.name)
    end
    return table.concat(parts, "|")
end

-- What the weekly rows currently say, for spotting a real change
function addon:GetWeeklyQuestSignature()
    local quests = self:GetWeeklyQuestInfo()
    if not quests or #quests == 0 then return "" end
    local parts = {}
    for i = 1, #quests do
        local quest = quests[i]
        local prey = ""
        if quest.preyCounts then
            prey = tostring(quest.preyCounts.normal) .. "," .. tostring(quest.preyCounts.hard)
                .. "," .. tostring(quest.preyCounts.nightmare)
        end
        parts[i] = tostring(quest.name) .. ":" .. tostring(quest.isComplete) .. ":"
            .. tostring(quest.isAccepted) .. ":"
            .. tostring(quest.progress) .. ":" .. tostring(quest.info) .. ":" .. prey
    end
    return table.concat(parts, "|")
end

-- What every tracked currency and crest currently holds, for spotting a real change
function addon:GetCurrencySignature()
    local parts = {}
    for _, list in ipairs({ self.currencyDB or {}, self.crestDB or {} }) do
        for i = 1, #list do
            local entry = list[i]
            local info = self:GetCurrencyInfo(entry.id)
            parts[#parts + 1] = tostring(entry.id) .. ":"
                .. (info and (tostring(info.quantity) .. "/" .. tostring(info.totalEarned)
                    .. "/" .. tostring(info.maxQuantity)) or "-")
        end
    end
    return table.concat(parts, "|")
end

-- Sections a currency or bag update can actually have changed, which is usually neither
function addon:GetCurrencyDirtySections()
    local dirty = {}
    local signature = self:GetCurrencySignature()
    if signature ~= self._lastCurrencySignature then
        self._lastCurrencySignature = signature
        dirty.Currency = true
        dirty.Crests = true
    end
    return dirty
end

-- Sections a quest update can actually have changed, which is rarely the weeklies
function addon:GetQuestDirtySections()
    local dirty = { Activities = true, Rares = true }
    local signature = self:GetWeeklyQuestSignature()
    if signature ~= self._lastWeeklySignature then
        self._lastWeeklySignature = signature
        dirty.Weekly = true
    end
    return dirty
end

-- Sections a POI sweep can actually have changed, which is usually none of them
function addon:GetAreaPoiDirtySections()
    local dirty = {}

    local delveSignature = self:GetBountifulDelveSignature()
    if delveSignature ~= self._lastDelveSignature then
        self._lastDelveSignature = delveSignature
        dirty.Delves = true
    end

    -- Only the Abundance row reads POI data, and the harvest moves on a schedule
    local abundancePOI = self.GetActiveAbundance and self:GetActiveAbundance() or nil
    if abundancePOI ~= self._lastAbundancePOI then
        self._lastAbundancePOI = abundancePOI
        dirty.Weekly = true
    end

    return dirty
end

-- Delve instance check
function addon:IsInDelve()
    return C_PartyInfo.IsPartyWalkIn and C_PartyInfo.IsPartyWalkIn()
end

-- Bountiful delves
function addon:GetBountifulDelveInfo()
    if _dataCache.bountifulDelves then return _dataCache.bountifulDelves end

    local delves = {}
    local zoneMap = addon.zoneIDs or {}
    
    for _, delve in ipairs(self.delvesDB) do
        local zoneID = zoneMap[delve.zone]
        if zoneID then
            local poiInfo = C_AreaPoiInfo.GetAreaPOIInfo(zoneID, delve.delveID)
            if poiInfo and poiInfo.atlasName == "delves-bountiful" then
                table.insert(delves, {
                    name = poiInfo.name or delve.name,
                    expansion = delve.expansion,
                    delveID = delve.delveID,
                    zone = delve.zone,
                    x = delve.x,
                    y = delve.y,
                })
            end
        end
    end
    
    _dataCache.bountifulDelves = delves
    return delves
end


-- Profile & SavedVariables management
local function IsMetaKey(key)
    return type(key) == "string" and string.sub(key, 1, 2) == "__"
end

-- Record default module order
local function EnsureDefaultModuleOrder()
    if not addon.defaultModuleOrder then
        addon.defaultModuleOrder = {}
        if addon.modules then
            for idx, m in ipairs(addon.modules) do
                addon.defaultModuleOrder[m.name] = idx
            end
        end
    end
end

local function DeepCopy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local out = {}
    seen[value] = out
    for k, v in pairs(value) do
        out[DeepCopy(k, seen)] = DeepCopy(v, seen)
    end
    return out
end

-- Fill in missing saved vars at any depth; existing values always win
local function CopyDefaults(dest, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dest[k]) ~= "table" then dest[k] = {} end
            CopyDefaults(dest[k], v)
        elseif dest[k] == nil then
            dest[k] = v
        end
    end
end

local function CaptureProfileData()
    local data = {}
    for k, v in pairs(HomeworkTrackerDB) do
        if not IsMetaKey(k) then
            data[k] = DeepCopy(v)
        end
    end
    return data
end

local function ApplyProfileData(profileData)
    for k in pairs(HomeworkTrackerDB) do
        if not IsMetaKey(k) then
            HomeworkTrackerDB[k] = nil
        end
    end
    if type(profileData) ~= "table" then return end
    for k, v in pairs(profileData) do
        if not IsMetaKey(k) then
            HomeworkTrackerDB[k] = DeepCopy(v)
        end
    end
end

-- ApplyProfileData swaps the table LibDBIcon holds, so hand it the new one
local function ApplyProfileAndRebind(profileData)
    ApplyProfileData(profileData)
    if addon.RefreshMinimapButton then addon:RefreshMinimapButton() end
end

local PROFILE_DATA_MAX_BYTES = 512 * 1024
local PROFILE_DATA_MAX_DEPTH = 64
local PROFILE_DATA_MAX_VALUES = 50000

local function SerializeValue(v, state, depth)
    state = state or { activeTables = {}, valueCount = 0 }
    depth = depth or 0
    if depth > PROFILE_DATA_MAX_DEPTH then return nil, "Profile is too deeply nested" end
    state.valueCount = state.valueCount + 1
    if state.valueCount > PROFILE_DATA_MAX_VALUES then return nil, "Profile has too many values" end

    local t = type(v)
    if t == "number" or t == "boolean" then
        return tostring(v)
    elseif t == "string" then
        return string.format("%q", v)
    elseif t ~= "table" then
        return "nil"
    end

    if state.activeTables[v] then return nil, "Profile contains circular tables" end
    state.activeTables[v] = true

    local parts = {}
    for k, val in pairs(v) do
        local keyRepr
        if type(k) == "string" and string.match(k, "^[%a_][%w_]*$") then
            keyRepr = k
        else
            local serializedKey, keyErr = SerializeValue(k, state, depth + 1)
            if not serializedKey then
                state.activeTables[v] = nil
                return nil, keyErr
            end
            keyRepr = "[" .. serializedKey .. "]"
        end
        local serializedValue, valueErr = SerializeValue(val, state, depth + 1)
        if not serializedValue then
            state.activeTables[v] = nil
            return nil, valueErr
        end
        table.insert(parts, keyRepr .. "=" .. serializedValue)
    end
    state.activeTables[v] = nil
    return "{" .. table.concat(parts, ",") .. "}"
end

local function DeserializeTable(text)
    if type(text) ~= "string" or text == "" or #text > PROFILE_DATA_MAX_BYTES then
        return nil, "Incorrect code format"
    end

    local position, valueCount = 1, 0
    local length = #text
    local parseValue

    local function FailParse()
        error("Incorrect code format", 0)
    end

    local function SkipWhitespace()
        while position <= length and string.find(string.sub(text, position, position), "%s") do
            position = position + 1
        end
    end

    local escapeValues = {
        a = "\a", b = "\b", f = "\f", n = "\n", r = "\r",
        t = "\t", v = "\v", ["\\"] = "\\", ['"'] = '"', ["'"] = "'",
    }

    local function ParseString()
        if string.sub(text, position, position) ~= '"' then FailParse() end
        position = position + 1
        local parts = {}
        local partStart = position

        while position <= length do
            local char = string.sub(text, position, position)
            if char == '"' then
                parts[#parts + 1] = string.sub(text, partStart, position - 1)
                position = position + 1
                return table.concat(parts)
            elseif char == "\\" then
                parts[#parts + 1] = string.sub(text, partStart, position - 1)
                position = position + 1
                if position > length then FailParse() end

                local escaped = string.sub(text, position, position)
                if string.find(escaped, "%d") then
                    local digits = string.match(string.sub(text, position, position + 2), "^%d%d?%d?")
                    local byte = tonumber(digits)
                    if not byte or byte > 255 then FailParse() end
                    ---@cast byte integer
                    parts[#parts + 1] = string.char(byte)
                    position = position + #digits
                elseif escaped == "\n" then
                    parts[#parts + 1] = "\n"
                    position = position + 1
                elseif escaped == "\r" then
                    position = position + 1
                    if string.sub(text, position, position) == "\n" then position = position + 1 end
                    parts[#parts + 1] = "\n"
                else
                    local replacement = escapeValues[escaped]
                    if not replacement then FailParse() end
                    parts[#parts + 1] = replacement
                    position = position + 1
                end
                partStart = position
            else
                position = position + 1
            end
        end
        FailParse()
    end

    local function ParseNumber()
        local remaining = string.sub(text, position)
        local token = string.match(remaining, "^[%+%-]?%d+%.?%d*[eE][%+%-]?%d+")
            or string.match(remaining, "^[%+%-]?%d*%.%d+[eE][%+%-]?%d+")
            or string.match(remaining, "^[%+%-]?%d+%.?%d*")
            or string.match(remaining, "^[%+%-]?%d*%.%d+")
        local number = token and tonumber(token)
        if not number or number ~= number or number == math.huge or number == -math.huge then
            FailParse()
        end
        position = position + #token
        return number
    end

    local function ParseTable(depth)
        if depth > PROFILE_DATA_MAX_DEPTH then FailParse() end
        position = position + 1
        local result = {}
        SkipWhitespace()
        if string.sub(text, position, position) == "}" then
            position = position + 1
            return result
        end

        while position <= length do
            local key
            if string.sub(text, position, position) == "[" then
                position = position + 1
                key = parseValue(depth + 1)
                SkipWhitespace()
                if string.sub(text, position, position) ~= "]" then FailParse() end
                position = position + 1
            else
                local identifier = string.match(string.sub(text, position), "^[%a_][%w_]*")
                if not identifier then FailParse() end
                key = identifier
                position = position + #identifier
            end

            if type(key) ~= "string" and type(key) ~= "number" and type(key) ~= "boolean" then
                FailParse()
            end
            SkipWhitespace()
            if string.sub(text, position, position) ~= "=" then FailParse() end
            position = position + 1
            local value = parseValue(depth + 1)
            if value ~= nil then result[key] = value end

            SkipWhitespace()
            local separator = string.sub(text, position, position)
            if separator == "}" then
                position = position + 1
                return result
            end
            if separator ~= "," then FailParse() end
            position = position + 1
            SkipWhitespace()
        end
        FailParse()
    end

    parseValue = function(depth)
        if depth > PROFILE_DATA_MAX_DEPTH then FailParse() end
        valueCount = valueCount + 1
        if valueCount > PROFILE_DATA_MAX_VALUES then FailParse() end
        SkipWhitespace()

        local char = string.sub(text, position, position)
        if char == "{" then return ParseTable(depth) end
        if char == '"' then return ParseString() end
        if string.sub(text, position, position + 3) == "true" then
            position = position + 4
            return true
        end
        if string.sub(text, position, position + 4) == "false" then
            position = position + 5
            return false
        end
        if string.sub(text, position, position + 2) == "nil" then
            position = position + 3
            return nil
        end
        return ParseNumber()
    end

    local ok, result = pcall(function()
        local parsed = parseValue(0)
        SkipWhitespace()
        if position <= length or type(parsed) ~= "table" then FailParse() end
        return parsed
    end)
    if not ok then return nil, "Incorrect code format" end
    return result
end

local function EncodePayload(raw)
    if type(raw) ~= "string" then return "" end
    local out = {}
    for i = 1, #raw do
        local b = string.byte(raw, i)
        out[#out + 1] = string.format("%02X", (b + 17) % 256)
    end
    return "HTP1-" .. table.concat(out)
end

local function DecodePayload(text)
    if type(text) ~= "string" then return nil, "Incorrect code format" end
    local compact = string.gsub(text, "%s+", "")
    if string.sub(compact, 1, 5) ~= "HTP1-" then
        return nil, "Incorrect code format"
    end

    local body = string.sub(compact, 6)
    if body == "" or #body > PROFILE_DATA_MAX_BYTES * 2 or (#body % 2) ~= 0
        or string.find(body, "[^%x]") then
        return nil, "Incorrect code format"
    end

    local chars = {}
    for i = 1, #body, 2 do
        local hex = string.sub(body, i, i + 1)
        local n = tonumber(hex, 16)
        if not n then
            return nil, "Incorrect code format"
        end
        chars[#chars + 1] = string.char((n - 17) % 256)
    end
    return table.concat(chars)
end

-- Validate import code
function addon:ValidateImportCode(payload)
    local decoded, decodeErr = DecodePayload(payload)
    if not decoded then return false, decodeErr or "Incorrect code format" end

    local parsed, parseErr = DeserializeTable(decoded)
    if not parsed then return false, parseErr or "Incorrect code format" end
    return true
end

-- Init saved variables
local function GetAccountProfiles()
    if not HomeworkTrackerAccountDB then
        HomeworkTrackerAccountDB = {}
    end
    if type(HomeworkTrackerAccountDB.__profiles) ~= "table" then
        HomeworkTrackerAccountDB.__profiles = {}
    end
    return HomeworkTrackerAccountDB.__profiles
end

function addon:InitializeSavedVariables()
    if not HomeworkTrackerDB then
        HomeworkTrackerDB = {}
    end

    local defaults = addon.defaults or {}

    -- Migrate old per-character profiles if present
    local acct = HomeworkTrackerAccountDB or {}
    if HomeworkTrackerDB.__profiles and not acct.__profiles then
        acct.__profiles = HomeworkTrackerDB.__profiles
        HomeworkTrackerDB.__profiles = nil
    end
    HomeworkTrackerAccountDB = acct

    -- Determine active profile
    local profiles = GetAccountProfiles()
    local active = HomeworkTrackerDB.__activeProfile or "Default"
    local hasStoredProfile = type(active) == "string" and profiles[active] and true or false
    if not hasStoredProfile then
        active = "Default"
        hasStoredProfile = profiles[active] and true or false
    end
    HomeworkTrackerDB.__activeProfile = active

    -- Character data only seeds a profile that does not exist yet
    if not hasStoredProfile then
        local hasRuntimeData = false
        for k in pairs(HomeworkTrackerDB) do
            if not IsMetaKey(k) then
                hasRuntimeData = true
                break
            end
        end
        profiles[active] = hasRuntimeData and CaptureProfileData() or {}
    end

    profiles["Default"] = profiles["Default"] or {}

    ApplyProfileAndRebind(profiles[active])

    -- Lock module order
    EnsureDefaultModuleOrder()


    -- Apply defaults
    local activeProfileData = GetAccountProfiles()[HomeworkTrackerDB.__activeProfile]
    local skipDefaults = activeProfileData and activeProfileData.__noDefaults
    if not skipDefaults then
        CopyDefaults(HomeworkTrackerDB, defaults)
    end


    if HomeworkTrackerDB.categoryOrder and addon.categoryInfo then
        for cid, ord in pairs(HomeworkTrackerDB.categoryOrder) do
            if addon.categoryInfo[cid] then
                addon.categoryInfo[cid].order = ord
            end
        end
    end

    if not skipDefaults and not HomeworkTrackerDB.moduleOrder and addon.defaultModuleOrder then
        HomeworkTrackerDB.moduleOrder = DeepCopy(addon.defaultModuleOrder)
    end


    if HomeworkTrackerDB.moduleOrder and addon.modules then
        table.sort(addon.modules, function(a, b)
            local oa = HomeworkTrackerDB.moduleOrder[a.name] or 999
            local ob = HomeworkTrackerDB.moduleOrder[b.name] or 999
            if oa ~= ob then return oa < ob end
            return a.name < b.name
        end)
    end


    -- Validate category order
    if addon.categoryInfo then
        local maxOrder = 0
        for _, info in pairs(addon.categoryInfo) do
            if info.order and info.order > maxOrder then
                maxOrder = info.order
            end
        end
        for _, info in pairs(addon.categoryInfo) do
            if not info.order then
                maxOrder = maxOrder + 1
                info.order = maxOrder
            end
        end
    end

    GetAccountProfiles()[HomeworkTrackerDB.__activeProfile] = CaptureProfileData()
end

-- Active profile name
function addon:GetActiveProfileName()
    if HomeworkTrackerDB and HomeworkTrackerDB.__activeProfile then
        return HomeworkTrackerDB.__activeProfile
    end
    return "Default"
end

-- All profile names
function addon:GetProfileNames()
    local out = {}
    local profiles = GetAccountProfiles()
    for name in pairs(profiles) do
        table.insert(out, name)
    end
    table.sort(out)
    return out
end

-- Save active profile
function addon:SaveActiveProfile()
    local profiles = GetAccountProfiles()
    if type(profiles) ~= "table" then return end
    local active = self:GetActiveProfileName()
    local data = CaptureProfileData()
    local stored = profiles[active]
    if stored and stored.__noDefaults then
        data.__noDefaults = true
    end
    profiles[active] = data
end

-- Switch profile
function addon:SwitchProfile(name)
    if type(name) ~= "string" or name == "" then return false, "Invalid profile name" end
    local profiles = GetAccountProfiles()
    if not profiles[name] then return false, "Profile not found" end
    if HomeworkTrackerDB.__activeProfile == name then return true end

    -- Persist current active profile to account storage, then switch
    self:SaveActiveProfile()
    HomeworkTrackerDB.__activeProfile = name

    ApplyProfileAndRebind(profiles[name])
    self:InitializeSavedVariables()

    if self.UpdateLayout then
        self:UpdateLayout()
    end
    self:UpdateDisplay()
    
    return true
end

-- Create new profile
function addon:CreateProfile(name)
    if type(name) ~= "string" then return false, "Invalid profile name" end
    name = string.match(name, "^%s*(.-)%s*$") or ""
    if name == "" then return false, "Profile name is empty" end
    local profiles = GetAccountProfiles()
    if profiles[name] then return false, "Profile already exists" end

    local newProfile = DeepCopy(addon.defaults or {})

    EnsureDefaultModuleOrder()
    if addon.defaultModuleOrder then
        newProfile.moduleOrder = DeepCopy(addon.defaultModuleOrder)
    end

    newProfile.categoryOrder = nil

    profiles[name] = newProfile
    return true
end

-- Copy a profile
function addon:CopyProfile(sourceName, targetName)
    if type(sourceName) ~= "string" or type(targetName) ~= "string" then
        return false, "Invalid profile name"
    end
    sourceName = string.match(sourceName, "^%s*(.-)%s*$") or ""
    targetName = string.match(targetName, "^%s*(.-)%s*$") or ""
    if sourceName == "" or targetName == "" then return false, "Profile name is empty" end

    local profiles = GetAccountProfiles()
    local source = (sourceName == self:GetActiveProfileName()) and CaptureProfileData() or profiles[sourceName]
    if not source then return false, "Source profile not found" end
    profiles[targetName] = DeepCopy(source)

    if HomeworkTrackerDB.__activeProfile == targetName then
        ApplyProfileAndRebind(profiles[targetName])
        self:InitializeSavedVariables()
        if self.UpdateLayout then
            self:UpdateLayout()
        end
        self:UpdateDisplay()
    end
    return true
end

-- Delete a profile
function addon:DeleteProfile(name)
    if type(name) ~= "string" or name == "" then return false, "Invalid profile name" end
    if name == "Default" then return false, "Cannot delete Default profile" end
    if HomeworkTrackerDB.__activeProfile == name then return false, "Cannot delete active profile" end
    local profiles = GetAccountProfiles()
    if not profiles[name] then return false, "Profile not found" end

    profiles[name] = nil
    return true
end

-- Export profile as code
function addon:ExportProfile(name)
    local profileName = name or self:GetActiveProfileName()
    local profile
    if profileName == self:GetActiveProfileName() then
        profile = CaptureProfileData()
    else
        local profiles = GetAccountProfiles()
        profile = profiles[profileName]
    end
    if not profile then return nil, "Profile not found" end
    local serialized, serializeErr = SerializeValue(profile)
    if not serialized then return nil, serializeErr end
    if #serialized > PROFILE_DATA_MAX_BYTES then return nil, "Profile is too large" end
    return EncodePayload(serialized)
end

-- Import profile from code
function addon:ImportProfile(name, payload)
    if type(name) ~= "string" then return false, "Invalid profile name" end
    name = string.match(name, "^%s*(.-)%s*$") or ""
    if name == "" then return false, "Profile name is empty" end

    local profiles = GetAccountProfiles()
    if profiles[name] then return false, "Profile already exists" end

    local decoded, decodeErr = DecodePayload(payload)
    if not decoded then return false, decodeErr end

    local parsed, err = DeserializeTable(decoded)
    if not parsed then return false, err end
    profiles[name] = DeepCopy(parsed)
    -- Keep imported values
    profiles[name].__noDefaults = true
    return true
end
