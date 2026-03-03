-- HomeworkTracker - Modules
local addonName, addon = ...

-- Check if expansion is active
local function IsExpEnabled(key)
    if not key then return true end
    if not HomeworkTrackerDB.expansions then return true end
    if HomeworkTrackerDB.expansions[key] == nil then return true end
    return HomeworkTrackerDB.expansions[key]
end

-- Define logic modules in display order
addon.modules = {
    { name = "Activities",      func = "UpdateActivitiesSection" },
    { name = "Delves",          func = "UpdateDelvesSection" }, 
    { name = "GreatVault",      func = "UpdateGreatVaultSection" },
    { name = "Weekly",          func = "UpdateWeeklySection" },
    { name = "Crests",          func = "UpdateCrestsSection" },
    { name = "Currency",        func = "UpdateCurrencySection" }, 
    { name = "Progress",        func = "UpdateProgressSection" },
    { name = "Reputations",     func = "UpdateReputationsSection" },
    { name = "Rares",           func = "UpdateRaresSection" },
}

-- Run ordered progression of tracker modules
function addon:RunModules(parent, yOffset)
    local currentMapID = C_Map.GetBestMapForUnit("player")
    local activeExpansions = {}
    
    if addon.expansionMapIDs then
        for expKey, mapList in pairs(addon.expansionMapIDs) do
            activeExpansions[expKey] = false
            local tempMapID = currentMapID
            for i=1, 5 do
                if not tempMapID then break end
                if mapList[tempMapID] then
                    activeExpansions[expKey] = true
                    break
                end
                local info = C_Map.GetMapInfo(tempMapID)
                tempMapID = info and info.parentMapID or nil
            end
        end
    end

    local expStates = {}
    if HomeworkTrackerDB.expansions then
        for k, v in pairs(HomeworkTrackerDB.expansions) do
            if activeExpansions[k] ~= nil then
                expStates[k] = v and activeExpansions[k]
            else
                expStates[k] = v
            end
        end
    end
    
    if addon.defaults and addon.defaults.expansions then
        for k, defaultVal in pairs(addon.defaults.expansions) do
            if expStates[k] == nil then
                local inZone = defaultVal
                if activeExpansions[k] ~= nil then
                    inZone = defaultVal and activeExpansions[k]
                end
                expStates[k] = inZone
            end
        end
    end

    for _, mod in ipairs(self.modules) do
        if self[mod.func] then
            yOffset = self[mod.func](self, parent, yOffset, expStates)
        end
    end
    
    return yOffset
end
