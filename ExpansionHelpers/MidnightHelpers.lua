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
        local AH = addon.abundantHarvest
        if AH and C_AreaPoiInfo and C_AreaPoiInfo.GetAreaPOIInfo then
            local poiInfo = C_AreaPoiInfo.GetAreaPOIInfo(AH.continentUiMapID, poiID)
        end
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
    bar.iconButton:Show()
    bar.iconButton:SetSize(16, 16)
    bar.iconButton:ClearAllPoints()

    if bar.timeText then
        local p, rel, rp, xOff, yOff = bar.timeText:GetPoint()
        if xOff then
            local newX = xOff - 1
            bar.timeText:ClearAllPoints()
            bar.timeText:SetPoint(p or "RIGHT", rel or bar, rp or "RIGHT", newX, yOff or 0)
        else
            bar.timeText:ClearAllPoints()
            bar.timeText:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
        end
    end
    bar.iconButton:SetPoint("RIGHT", bar.timeText, "RIGHT", 0, 0)

    bar.iconButton:SetScript("OnMouseUp", function(self)
        local poiID, uiMapID = addon:GetActiveAbundance()
        if uiMapID and WorldMapFrame and WorldMapFrame.SetMapID then
            ShowUIPanel(WorldMapFrame)
            WorldMapFrame:SetMapID(uiMapID)
        end
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
    local atlasTag = " |A:ui-eventpoi-abundancebountiful:14:14|a"
    if bar.timeText then
        if info and info ~= "" then
            bar.timeText:SetText(info .. atlasTag)
        else
            bar.timeText:SetText((bar.timeText:GetText() or (quest.name or "")) .. atlasTag)
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
