-- HomeworkTracker - Modules
local addonName, addon = ...

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
function addon:RunModules(parent, yOffset, dirty)
    local currentMapID = C_Map.GetBestMapForUnit("player")
    local activeExpansions = {}
    
    if addon.expansionMapIDs then
        for expKey, mapList in pairs(addon.expansionMapIDs) do
            activeExpansions[expKey] = false
            local tempMapID = currentMapID
            for _=1, 5 do
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

    -- Profiling: /hw profiling wants to know what each section costs
    local prof = addon._profile
    self.sectionRows = self.sectionRows or {}
    self.sectionEndY = self.sectionEndY or {}

    -- A partial pass refills the flat list from what each section owns
    if dirty then wipe(self.sections) end

    for _, mod in ipairs(self.modules) do
        if self[mod.func] then
            local name = mod.name
            local rows = self.sectionRows[name]

            if dirty and not dirty[name] and self.sectionEndY[name] then
                -- This event cannot have changed the section, so leave its rows alone
                for i = 1, (rows and #rows or 0) do self.sections[#self.sections + 1] = rows[i] end
                yOffset = self.sectionEndY[name]
            else
                if dirty and rows then
                    for i = 1, #rows do addon.ReleaseContainer(rows[i]) end
                end

                local first = #self.sections + 1
                local previousEnd = self.sectionEndY[name]
                local t0 = prof and debugprofilestop() or nil

                yOffset = self[mod.func](self, parent, yOffset, expStates)

                -- Remember which rows this section owns, so it can be redrawn on its own
                if rows then wipe(rows) else rows = {}; self.sectionRows[name] = rows end
                for i = first, #self.sections do rows[#rows + 1] = self.sections[i] end
                self.sectionEndY[name] = yOffset

                if t0 then
                    prof.bySection[name] = (prof.bySection[name] or 0) + (debugprofilestop() - t0)
                    prof.bySectionRows[name] = #rows
                end

                -- Section changed height, so rows below moved: caller must start over
                if dirty and previousEnd and previousEnd ~= yOffset then
                    wipe(self.sections)
                    for _, other in ipairs(self.modules) do
                        local ownd = self.sectionRows[other.name]
                        for i = 1, (ownd and #ownd or 0) do
                            self.sections[#self.sections + 1] = ownd[i]
                        end
                    end
                    return nil
                end
            end
        end
    end
    
    return yOffset
end
