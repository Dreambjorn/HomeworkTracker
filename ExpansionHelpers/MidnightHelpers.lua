-- HomeworkTracker - Midnight helpers
local addonName, addon = ...

-- Return active Abundance POI and uiMapID
function addon:GetActiveAbundance()
    local AH = addon.abundantHarvest
    if not AH or not C_AreaPoiInfo or not C_AreaPoiInfo.GetEventsForMap then
        return nil
    end
    local pois = C_AreaPoiInfo.GetEventsForMap(AH.continentUiMapID)
    if pois then
        for _, poiID in ipairs(pois) do
            if AH.poiMap[poiID] then
                return poiID, AH.poiMap[poiID]
            end
        end
    end
    return nil
end

-- Return display string and map name for the active Abundance
function addon:GetAbundanceInfo()
    local info = ""
    local mapName = nil
    local poiID, uiMapID = addon:GetActiveAbundance()
    if poiID and uiMapID then
        if C_Map and C_Map.GetMapInfo then
            local mapInfo = C_Map.GetMapInfo(uiMapID)
            mapName = mapInfo and mapInfo.name or nil
            if mapName then info = mapName else info = "" end
        end
    end
    return info, mapName
end

-- Position abundance text/icon and set tooltip + click behavior for the bar
function addon:ConfigureAbundanceDisplay(bar, mapName)
    if not bar or not bar.iconButton then return end
    if bar.icon then bar.icon:Hide() end
    local glyph = addon:PlaceRightGlyph(bar, "|A:ui-eventpoi-abundancebountiful:14:14|a", 14, 3, -2)
    bar.iconButton:Show()
    bar.iconButton:SetSize(16, 16)
    bar.iconButton:ClearAllPoints()
    bar.iconButton:SetPoint("RIGHT", glyph, "RIGHT", 0, 0)

    bar.iconButton:SetScript("OnMouseUp", function(self)
        local _, uiMapID = addon:GetActiveAbundance()
        addon:OpenWorldMapTo(uiMapID)
    end)

    bar.iconButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(bar.timeText or self, "ANCHOR_RIGHT")
        if mapName and mapName ~= "" then
            GameTooltip:SetText(mapName, 1, 1, 1)
        else
            GameTooltip:SetText("Abundance", 1, 1, 1)
        end
        GameTooltip:AddLine("|cff00ff00Click|r to open map", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)

    bar.iconButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Populate abundance text and return mapName
function addon:PopulateAbundanceText(bar, quest)
    if not bar then return nil end
    if bar.nameText and quest and quest.name then
        bar.nameText:SetText(quest.name)
    end
    local info, mapName = addon:GetAbundanceInfo()
    if bar.timeText then
        if info and info ~= "" then
            bar.timeText:SetText(info)
        else
            bar.timeText:SetText("")
        end
    end
    return mapName
end

-- Register weekly handler for Abundance display
addon.weeklyHandlers = addon.weeklyHandlers or {}
addon.weeklyHandlers["abundance"] = function(bar, quest)
    if not bar then return end
    if addon.GetAbundanceInfo and addon.ConfigureAbundanceDisplay and addon.PopulateAbundanceText then
        local mapName = addon:PopulateAbundanceText(bar, quest)
        addon:ConfigureAbundanceDisplay(bar, mapName)
    end
end
