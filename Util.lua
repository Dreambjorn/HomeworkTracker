-- HomeworkTracker - Utils
local addonName, addon = ...

-- Constants
local DEFAULT_FONT_SIZE = 11
local DEFAULT_HEADER_FONT_SIZE = 14
local DEFAULT_FONT = "Friz Quadrata TT"
local DEFAULT_FONT_PATH = "Fonts\\FRIZQT__.TTF"

-- Font system with LibSharedMedia
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

-- Default font size
function addon:GetDefaultFontSize()
    return DEFAULT_FONT_SIZE
end

-- Default header font size
function addon:GetDefaultHeaderFontSize()
    return DEFAULT_HEADER_FONT_SIZE
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
    return pcall(fs.SetFont, fs, path, fontSize, flags or "OUTLINE")
end

-- Check font availability
function addon:IsFontAvailable(fontKey)
    if not fontKey or not LSM then return false end
    local ok, path = pcall(LSM.Fetch, LSM, "font", fontKey)
    return ok and path ~= nil
end

-- Format duration string
function addon:FormatTime(seconds)
    if seconds < 0 then seconds = 0 end
    if seconds >= 3600 then
        return string.format("%dh %dm", math.floor(seconds / 3600), math.floor((seconds % 3600) / 60))
    elseif seconds >= 60 then
        return string.format("%dm %ds", math.floor(seconds / 60), seconds % 60)
    else
        return string.format("%ds", seconds)
    end
end

-- Quest completion check
function addon:IsQuestComplete(questID)
    if not questID or type(questID) ~= "number" or questID == 0 then return false end

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

-- Last weekly reset time
function addon:GetLastWeeklyResetTime()
    -- Reset schedule by region (Sun=1)
    local resetMap = {
        -- 1 = NA (Americas): Tuesday 03:00
        [1] = { weekday = 3, hour = 3 },
        -- 2 = KR: Wednesday 03:00
        [2] = { weekday = 4, hour = 3 },
        -- 3 = EU: Tuesday 03:00
        [3] = { weekday = 3, hour = 3 },
        -- 4 = TW: Wednesday 03:00
        [4] = { weekday = 4, hour = 3 },
        -- 5 = CN: Wednesday 03:00
        [5] = { weekday = 4, hour = 3 },
    }

    local region = self:GetCurrentRegion() or 1
    local resetInfo = resetMap[region]
    if not resetInfo then
        return nil
    end

    local cal = C_DateAndTime.GetCurrentCalendarTime()
    if not cal then return nil end

    local now = GetServerTime()
    local secondsSinceMidnight = (cal.hour * 3600) + (cal.minute * 60) + (cal.second or 0)
    local todayReset = now - secondsSinceMidnight + (resetInfo.hour * 3600)
    local diffDays = ((cal.weekday - resetInfo.weekday) + 7) % 7
    local candidate = todayReset - (diffDays * 24 * 3600)

    -- Roll back if future
    if candidate > now then
        candidate = candidate - (7 * 24 * 3600)
    end

    return candidate
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
    local secondsSinceMidnight = (cal.hour * 3600) + (cal.minute * 60) + (cal.second or 0)
    local todayReset = now - secondsSinceMidnight + (resetInfo.hour * 3600)

    local diffDays = ((cal.weekday - targetWeekday) + 7) % 7
    local candidate = todayReset - (diffDays * 24 * 3600)
    if candidate > now then
        candidate = candidate - (7 * 24 * 3600)
    end
    return candidate
end

-- Within weekend window?
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

-- Great Vault progress
function addon:GetGreatVaultInfo()
    local data = {
        raid = {},
        mythicPlus = {},
        delves = {},
    }
    
    local allActivities = C_WeeklyRewards.GetActivities()
    
    if allActivities then
        for _, activity in ipairs(allActivities) do
            -- 1=M+, 3=Raid, 6=Delves
            if activity.type == 1 then
                table.insert(data.mythicPlus, { level = activity.level, progress = activity.progress, threshold = activity.threshold })
            elseif activity.type == 3 then
                table.insert(data.raid, { level = activity.level, progress = activity.progress, threshold = activity.threshold })
            elseif activity.type == 6 then
                table.insert(data.delves, { level = activity.level, progress = activity.progress, threshold = activity.threshold })
            end
        end
    end
    
    return data
end

-- Currency info
function addon:GetCurrencyInfo(currencyID)
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
        return {
            quantity = info.quantity or 0,
            maxQuantity = maxQty,
            totalEarned = info.totalEarned or 0,
            useTotalEarnedForMaxQty = info.useTotalEarnedForMaxQty,
            iconFileID = info.iconFileID,
        }
    end

    local itemCount = C_Item.GetItemCount(currencyID, true, false, true, true)
    if itemCount and itemCount > 0 then
        local name, _, icon = C_Item.GetItemInfo(currencyID)
        return {
            quantity = itemCount,
            maxQuantity = 0,
            totalEarned = itemCount,
            useTotalEarnedForMaxQty = false,
            iconFileID = icon,
            name = name,
        }
    end

    return nil
end

-- Renown progress
function addon:GetProgressInfo(progressID)
    local majorData = C_MajorFactions.GetMajorFactionData(progressID)
    if majorData then
        local isMaxed = C_MajorFactions.HasMaximumRenown(progressID)
        return {
            name = majorData.name,
            renownLevel = majorData.renownLevel or 0,
            renownReputationEarned = majorData.renownReputationEarned or 0,
            renownLevelThreshold = majorData.renownLevelThreshold or 1,
            isMaxed = isMaxed,
            isRenown = true
        }
    end

    return nil
end

-- Faction reputation info
function addon:GetReputationInfo(repID)
    -- 1. Renown
    local majorData = C_MajorFactions.GetMajorFactionData(repID)
    if majorData then
        local isMaxed = C_MajorFactions.HasMaximumRenown(repID)
        return {
            name = majorData.name,
            renownLevel = majorData.renownLevel or 0,
            renownReputationEarned = majorData.renownReputationEarned or 0,
            renownLevelThreshold = majorData.renownLevelThreshold or 1,
            isMaxed = isMaxed,
            isRenown = true
        }
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
        
        return {
            name = friendshipData.name,
            label = friendshipData.reaction, -- e.g. 'Acquaintance'
            renownReputationEarned = current,
            renownLevelThreshold = max,
            isMaxed = isMaxed,
            isFriend = true
        }
    end

    -- 3. Standard
    local repData = C_Reputation.GetFactionDataByID(repID)
    if repData then
        local isMaxed = not repData.nextReactionThreshold
        local current = repData.currentStanding - repData.currentReactionThreshold
        local max = 0
        if not isMaxed then
            max = repData.nextReactionThreshold - repData.currentReactionThreshold
        else
            current = 1
            max = 1
        end
        
        -- e.g. "Neutral", "Friendly"
        local label = _G["FACTION_STANDING_LABEL" .. repData.reaction] or repData.reaction
        
        local isFirstRank = repData.currentReactionThreshold == 0
        return {
            name = repData.name,
            label = label,
            reaction = repData.reaction,
            renownReputationEarned = current,
            renownLevelThreshold = max,
            isMaxed = isMaxed,
            isStandard = true,
            isFirstRank = isFirstRank,
        }
    end
    
    return nil
end

-- Event display name
function addon:GetEventName(eventKey)
    local lang = GetLocale()
    local event = self.eventDB[eventKey]
    if not event then return eventKey end
    return event.name[lang] or event.name["enUS"] or eventKey
end

-- Event completion check
function addon:IsEventComplete(eventKey)
    local event = self.eventDB[eventKey]
    if not event then return false end
    
    local questP, questT = 0, event.questReq
    for _, questID in pairs(event.questID) do
        if questID ~= 0 then
            questP = self:IsQuestComplete(questID) and questP + 1 or questP
        end
    end
    
    return questP == questT
end

-- Event timing and alerts
function addon:GetEventTiming(eventKey)
    local event = self.eventDB[eventKey]
    if not event then return nil end
    
    local cfg = (HomeworkTrackerDB and HomeworkTrackerDB.activities) or {}
    local region = self:GetCurrentRegion()
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

    return {
        active = active,
        remaining = remaining,
        next = next,
        duration = active and duration or (interval - duration),
        expirationTime = GetTime() + remaining,
        color = event.color,
        alert = alertEnabled,
    }
end

-- Weekly quest status
function addon:GetWeeklyQuestInfo()
    local quests = {}
    for _, quest in ipairs(self.weeklyDB) do
        if quest.isWeekend and not self:IsWithinWeekendWindow() then
        else
            local questIDs = type(quest.questID) == "table" and quest.questID or {quest.questID}
            local isComplete = false
            local completed = 0
            local info = ""
            
            if quest.questType == "simple" then
                isComplete = self:IsQuestComplete(questIDs[1])
                completed = isComplete and 1 or 0
                
            elseif quest.questType == "single" then
                -- Active variant; fallback to flagged
                local activeFound = false
                local activeComplete = false
                for _, qid in ipairs(questIDs) do
                    local logIndex = C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(qid)
                    if logIndex then
                        activeFound = true
                        if C_QuestLog.IsComplete(qid) then
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
                        if C_QuestLog.IsQuestFlaggedCompleted(qid) then
                            flagged = flagged + 1
                        end
                    end
                    isComplete = (flagged >= 1)
                    completed = flagged
                end

                if isComplete and quest.bossNames then
                    for _, qid in ipairs(questIDs) do
                        if self:IsQuestComplete(qid) and quest.bossNames[qid] then
                            info = quest.bossNames[qid]
                            break
                        end
                    end
                end
                
            elseif quest.questType == "multiple" then
                local totalRequired = #questIDs
                for _, qid in ipairs(questIDs) do
                    if self:IsQuestComplete(qid) then
                        completed = completed + 1
                    end
                end
                isComplete = (completed >= totalRequired)
                info = completed .. "/" .. totalRequired
            end
            
            table.insert(quests, {
                name = quest.name,
                expansion = quest.expansion,
                isComplete = isComplete,
                info = info,
                progress = completed,
                required = quest.questType == "multiple" and #questIDs or 1,
                category = quest.category,
            })
        end
    end
    
    return quests
end

-- Rare NPC data
function addon:GetRareInfo(currentZone)
    local rares = {}
    
    for _, rare in ipairs(self.raresDB) do
        local match = true
        if currentZone then
            match = (rare.zone == currentZone) or 
                   (string.find(currentZone, rare.zone, 1, true)) or 
                   (string.find(rare.zone, currentZone, 1, true))
        end
        
        if match then
            local isComplete = self:IsQuestComplete(rare.questID)
            
            table.insert(rares, {
                expansion = rare.expansion,
                name = rare.name,
                npcID = rare.npcID,
                questID = rare.questID,
                zone = rare.zone,
                x = rare.x,
                y = rare.y,
                isComplete = isComplete,
                phaseDivingRequired = rare.phaseDivingRequired or false,
            })
        end
    end
    
    return rares
end

-- Bountiful delves
function addon:GetBountifulDelveInfo()
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

local function SerializeValue(v)
    local t = type(v)
    if t == "number" or t == "boolean" then
        return tostring(v)
    elseif t == "string" then
        return string.format("%q", v)
    elseif t ~= "table" then
        return "nil"
    end

    local parts = {}
    for k, val in pairs(v) do
        local keyRepr
        if type(k) == "string" and string.match(k, "^[%a_][%w_]*$") then
            keyRepr = k
        else
            keyRepr = "[" .. SerializeValue(k) .. "]"
        end
        table.insert(parts, keyRepr .. "=" .. SerializeValue(val))
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

local function DeserializeTable(text)
    if type(text) ~= "string" or text == "" then
        return nil, "Incorrect code format"
    end

    local chunk = loadstring("return " .. text)
    if not chunk then
        return nil, "Incorrect code format"
    end
    if setfenv then
        setfenv(chunk, {})
    end

    local ok, result = pcall(chunk)
    if not ok then
        return nil, "Incorrect code format"
    end
    if type(result) ~= "table" then
        return nil, "Incorrect code format"
    end
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
        return text -- Backward compatibility
    end

    local body = string.sub(compact, 6)
    if (#body % 2) ~= 0 then
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
function addon:InitializeSavedVariables()
    if not HomeworkTrackerDB then
        HomeworkTrackerDB = {}
    end

    local defaults = addon.defaults or {}


    -- Init profiles
    if type(HomeworkTrackerDB.__profiles) ~= "table" then
        HomeworkTrackerDB.__profiles = {}
        HomeworkTrackerDB.__activeProfile = "Default"
    end

    -- Validate active profile
    if type(HomeworkTrackerDB.__activeProfile) ~= "string"
        or not HomeworkTrackerDB.__profiles[HomeworkTrackerDB.__activeProfile] then
        HomeworkTrackerDB.__activeProfile = "Default"
        HomeworkTrackerDB.__profiles["Default"] = HomeworkTrackerDB.__profiles["Default"] or {}
    end

    local activeProfile = HomeworkTrackerDB.__activeProfile
    local hasRuntimeData = false
    for k in pairs(HomeworkTrackerDB) do
        if not IsMetaKey(k) then
            hasRuntimeData = true
            break
        end
    end
    if hasRuntimeData then
        HomeworkTrackerDB.__profiles[activeProfile] = CaptureProfileData()
    end


    ApplyProfileData(HomeworkTrackerDB.__profiles[activeProfile])

    -- Lock module order
    EnsureDefaultModuleOrder()


    -- Apply defaults
    local activeProfileData = HomeworkTrackerDB.__profiles[HomeworkTrackerDB.__activeProfile]
    local skipDefaults = activeProfileData and activeProfileData.__noDefaults
    if not skipDefaults then
        for k, v in pairs(defaults) do
            if HomeworkTrackerDB[k] == nil then
                if type(v) == "table" then
                    HomeworkTrackerDB[k] = {}
                    for sk, sv in pairs(v) do
                        if type(sv) == "table" then
                            HomeworkTrackerDB[k][sk] = {}
                            for ssk, ssv in pairs(sv) do
                                HomeworkTrackerDB[k][sk][ssk] = ssv
                            end
                        else
                            HomeworkTrackerDB[k][sk] = sv
                        end
                    end
                else
                    HomeworkTrackerDB[k] = v
                end
            elseif type(v) == "table" then
                for sk, sv in pairs(v) do
                    if HomeworkTrackerDB[k][sk] == nil then
                        if type(sv) == "table" then
                            HomeworkTrackerDB[k][sk] = {}
                            for ssk, ssv in pairs(sv) do
                                HomeworkTrackerDB[k][sk][ssk] = ssv
                            end
                        else
                            HomeworkTrackerDB[k][sk] = sv
                        end
                    end
                end
            end
        end
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
        for cid, info in pairs(addon.categoryInfo) do
            if info.order and info.order > maxOrder then
                maxOrder = info.order
            end
        end
        for cid, info in pairs(addon.categoryInfo) do
            if not info.order then
                maxOrder = maxOrder + 1
                info.order = maxOrder
            end
        end
    end

    HomeworkTrackerDB.__profiles[HomeworkTrackerDB.__activeProfile] = CaptureProfileData()
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
    if HomeworkTrackerDB and type(HomeworkTrackerDB.__profiles) == "table" then
        for name in pairs(HomeworkTrackerDB.__profiles) do
            table.insert(out, name)
        end
        table.sort(out)
    end
    return out
end

-- Save active profile
function addon:SaveActiveProfile()
    if not HomeworkTrackerDB or type(HomeworkTrackerDB.__profiles) ~= "table" then return end
    local active = self:GetActiveProfileName()
    local data = CaptureProfileData()
    local stored = HomeworkTrackerDB.__profiles[active]
    if stored and stored.__noDefaults then
        data.__noDefaults = true
    end
    HomeworkTrackerDB.__profiles[active] = data
end

-- Switch profile
function addon:SwitchProfile(name)
    if type(name) ~= "string" or name == "" then return false, "Invalid profile name" end
    if not HomeworkTrackerDB.__profiles[name] then return false, "Profile not found" end
    if HomeworkTrackerDB.__activeProfile == name then return true end

    self:SaveActiveProfile()
    HomeworkTrackerDB.__activeProfile = name
    ApplyProfileData(HomeworkTrackerDB.__profiles[name])
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
    if HomeworkTrackerDB.__profiles[name] then return false, "Profile already exists" end

    local newProfile = DeepCopy(addon.defaults or {})

    EnsureDefaultModuleOrder()
    if addon.defaultModuleOrder then
        newProfile.moduleOrder = DeepCopy(addon.defaultModuleOrder)
    end

    newProfile.categoryOrder = nil

    HomeworkTrackerDB.__profiles[name] = newProfile
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

    local source = (sourceName == self:GetActiveProfileName()) and CaptureProfileData() or HomeworkTrackerDB.__profiles[sourceName]
    if not source then return false, "Source profile not found" end
    HomeworkTrackerDB.__profiles[targetName] = DeepCopy(source)

    if HomeworkTrackerDB.__activeProfile == targetName then
        ApplyProfileData(HomeworkTrackerDB.__profiles[targetName])
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
    if not HomeworkTrackerDB.__profiles[name] then return false, "Profile not found" end

    HomeworkTrackerDB.__profiles[name] = nil
    return true
end

-- Export profile as code
function addon:ExportProfile(name)
    local profileName = name or self:GetActiveProfileName()
    local profile
    if profileName == self:GetActiveProfileName() then
        profile = CaptureProfileData()
    else
        profile = HomeworkTrackerDB.__profiles and HomeworkTrackerDB.__profiles[profileName]
    end
    if not profile then return nil, "Profile not found" end
    return EncodePayload(SerializeValue(profile))
end

-- Import profile from code
function addon:ImportProfile(name, payload)
    if type(name) ~= "string" then return false, "Invalid profile name" end
    name = string.match(name, "^%s*(.-)%s*$") or ""
    if name == "" then return false, "Profile name is empty" end

    local decoded, decodeErr = DecodePayload(payload)
    if not decoded then return false, decodeErr end

    local parsed, err = DeserializeTable(decoded)
    if not parsed then return false, err end
    HomeworkTrackerDB.__profiles[name] = DeepCopy(parsed)
    -- Keep imported values
    HomeworkTrackerDB.__profiles[name].__noDefaults = true

    if HomeworkTrackerDB.__activeProfile == name then
        ApplyProfileData(HomeworkTrackerDB.__profiles[name])
        if self.UpdateLayout then
            self:UpdateLayout()
        end
        self:UpdateDisplay()
    end
    return true
end
