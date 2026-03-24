-- HomeworkTracker - UI
local addonName, addon = ...

-- Constants
local TITLE_BAR_HEIGHT = 21

-- Manage container pool
local containerPool = {}
local headerPool = {}

-- Recycle unused containers
local function ReleaseContainer(container)
    if not container then return end
    GameTooltip:Hide()
    container:Hide()
    container:ClearAllPoints()
    container:SetParent(nil)
    container:SetScript("OnEnter", nil)
    container:SetScript("OnLeave", nil)
    container:SetScript("OnMouseUp", nil)
    container:EnableMouse(false)
    container._activityKey = nil
    if container.icon then container.icon:SetTexture(nil); container.icon:Hide() end
    if container.iconButton then
        container.iconButton:Hide()
        container.iconButton:SetScript("OnEnter", nil)
        container.iconButton:SetScript("OnLeave", nil)
        container.iconButton:SetScript("OnMouseUp", nil)
    end
    if container.nameText then container.nameText:SetText(""); container.nameText:Hide() end
    if container.timeText then container.timeText:SetText(""); container.timeText:Hide() end
    if container.progress then container.progress:Hide() end

    if container.crestElements then
        for _, e in ipairs(container.crestElements) do
            if e.icon then e.icon:SetTexture(nil); e.icon:Hide() end
            if e.qtyText then e.qtyText:SetText(""); e.qtyText:Hide() end
            e:Hide()
        end
    end
    if container.preyElements then
        for _, e in ipairs(container.preyElements) do
            if e.icon then e.icon:SetTexture(nil); e.icon:Hide() end
            if e.qtyText then e.qtyText:SetText(""); e.qtyText:Hide() end
            e:Hide()
        end
    end
    if container.abundanceElements then
        for _, e in ipairs(container.abundanceElements) do
            if e.icon then e.icon:SetTexture(nil); e.icon:Hide() end
            if e.qtyText then e.qtyText:SetText(""); e.qtyText:Hide() end
            e:Hide()
        end
    end

    if container.__poolType == "header" then
        table.insert(headerPool, container)
    else
        table.insert(containerPool, container)
    end
end

-- Calculate frame width
function addon:GetFrameWidth()
    if HomeworkTrackerDB and HomeworkTrackerDB.width then
        return HomeworkTrackerDB.width
    end
    if addon.defaults and addon.defaults.width then
        return addon.defaults.width
    end
end

-- Calculate frame height
function addon:GetFrameHeight()
    if HomeworkTrackerDB and HomeworkTrackerDB.height then
        return HomeworkTrackerDB.height
    end
    if addon.defaults and addon.defaults.height then
        return addon.defaults.height
    end
end

-- Create main frame
function addon:CreateUI()
    if self.mainFrame then return end
    
    local frame = CreateFrame("Frame", "HomeworkTrackerFrame", UIParent)
    frame:SetFrameStrata("BACKGROUND")
    local fw = self:GetFrameWidth()
    local fh = self:GetFrameHeight()
    frame:SetSize(fw, fh)
    frame:SetPoint(
        HomeworkTrackerDB.position.point,
        UIParent,
        HomeworkTrackerDB.position.relativePoint,
        HomeworkTrackerDB.position.xOfs,
        HomeworkTrackerDB.position.yOfs
    )
    
    frame:SetScale(HomeworkTrackerDB.scale)
    
    -- Frame must be movable so StartMoving() works when called from the title bar
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    
    local updateTimer = 0
    frame:SetScript("OnUpdate", function(self, elapsed)
        if not addon.mainFrame or not addon.mainFrame:IsShown() then return end
        updateTimer = updateTimer + elapsed
        if updateTimer >= 1 then
            updateTimer = 0
            addon:UpdateActivityTimers()
        end
    end)
    
    self.mainFrame = frame
    self.sections = {}

    if self.UpdateLayout then
        self:UpdateLayout()
    end

    frame.scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    frame.scrollFrame:SetPoint("TOPLEFT", 5, -(TITLE_BAR_HEIGHT + 1))
    frame.scrollFrame:SetPoint("BOTTOMRIGHT", -25, 5)

    local scrollBar = frame.scrollFrame.ScrollBar
    if scrollBar then
        scrollBar:SetAlpha(0)
        scrollBar:EnableMouse(false)
    end

    frame.scrollChild = CreateFrame("Frame", nil, frame.scrollFrame)
    frame.scrollChild:SetSize(fw - 30, 1)
    frame.scrollFrame:SetScrollChild(frame.scrollChild)

    frame.scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local step = 40
        if delta < 0 then
            self:SetVerticalScroll(math.min(current + step, self:GetVerticalScrollRange()))
        else
            self:SetVerticalScroll(math.max(current - step, 0))
        end
    end)

    self:CreateTitleBar()
    -- Initialize minimap button
    if addon.InitMinimapButton then
        addon:InitMinimapButton()
    end
end

-- Get category color
local function GetColor(key, subKey, defaultR, defaultG, defaultB)
    if HomeworkTrackerDB.colors then
        if subKey and HomeworkTrackerDB.colors[key] and HomeworkTrackerDB.colors[key][subKey] then
             return unpack(HomeworkTrackerDB.colors[key][subKey])
        elseif HomeworkTrackerDB.colors[key] and type(HomeworkTrackerDB.colors[key][1]) == "number" then
             return unpack(HomeworkTrackerDB.colors[key])
        end
    end

    if addon.defaultColors then
        if subKey and addon.defaultColors[key] and addon.defaultColors[key][subKey] then
            return unpack(addon.defaultColors[key][subKey])
        elseif not subKey and addon.defaultColors[key] then
            return unpack(addon.defaultColors[key])
        end
    end
    
    return defaultR or 1, defaultG or 1, defaultB or 1
end

-- Build the title bar
function addon:CreateTitleBar()
    local frame = self.mainFrame
    if not frame then return end 

    if frame.titleBar then
        frame.titleBar:Hide()
        frame.titleBar:ClearAllPoints()
        frame.titleBar:SetParent(nil)
        frame.titleBar:SetScript("OnDragStart", nil)
        frame.titleBar:SetScript("OnDragStop", nil)
        frame.titleBar:SetScript("OnClick", nil)
        frame.titleBar = nil
        frame.titleText = nil
        frame.collapseLabel = nil
    end

    local titleBar = CreateFrame("Button", nil, frame)
    titleBar:SetHeight(TITLE_BAR_HEIGHT)
    titleBar:SetPoint("TOPLEFT",  frame, "TOPLEFT",  0, 0)
    titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:RegisterForClicks("LeftButtonUp")

    local collapseLabel = titleBar:CreateFontString(nil, "OVERLAY")
    collapseLabel:SetPoint("LEFT", titleBar, "LEFT", -1, 0)
    collapseLabel:SetJustifyH("LEFT")
    collapseLabel:SetJustifyV("MIDDLE")
    collapseLabel:SetHeight(TITLE_BAR_HEIGHT)

    local titleText = titleBar:CreateFontString(nil, "OVERLAY")
    titleText:SetPoint("LEFT",  titleBar, "LEFT",  10, 0)
    titleText:SetPoint("RIGHT", titleBar, "RIGHT", -4, 0)
    titleText:SetJustifyH("LEFT")
    titleText:SetJustifyV("MIDDLE")
    titleText:SetHeight(TITLE_BAR_HEIGHT)

    frame.titleBar      = titleBar
    frame.titleText     = titleText
    frame.collapseLabel = collapseLabel

    titleBar:SetScript("OnDragStart", function()
        if not HomeworkTrackerDB.locked then
            frame:StartMoving()
        end
    end)
    titleBar:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        local left = frame:GetLeft()
        local top  = frame:GetTop()
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        HomeworkTrackerDB.position.point         = "TOPLEFT"
        HomeworkTrackerDB.position.relativePoint = "BOTTOMLEFT"
        HomeworkTrackerDB.position.xOfs          = left
        HomeworkTrackerDB.position.yOfs          = top
    end)
    titleBar:SetScript("OnClick", function()
        HomeworkTrackerDB.minimized = not (HomeworkTrackerDB.minimized or false)
        addon:ApplyCollapseState()
    end)

    self:RefreshTitleBar()
    self:ApplyCollapseState()
end

function addon:RefreshTitleBar()
    local frame = self.mainFrame
    if not (frame and frame.titleText) then return end
    local r, g, b = GetColor("headerText", nil, 0.3, 0.69, 0.93)
    local fontKey  = self:GetHeaderFontKey()
    local fontSize = self:GetHeaderFontSize() + 1
    self:SetFont(frame.titleText, fontKey, fontSize, HomeworkTrackerDB.headerFontOutline)
    frame.titleText:SetTextColor(r, g, b, 1)

    if HomeworkTrackerDB.hideTitleText then
        frame.titleText:SetText("")
    else
        frame.titleText:SetText("Homework Tracker")
    end
    if frame.collapseLabel then
        self:SetFont(frame.collapseLabel, fontKey, fontSize, HomeworkTrackerDB.headerFontOutline)
        frame.collapseLabel:SetTextColor(r, g, b, 1)
    end
end

function addon:ApplyCollapseState()
    local frame = self.mainFrame
    if not frame then return end
    local minimized = HomeworkTrackerDB and HomeworkTrackerDB.minimized or false
    if frame.collapseLabel then
        frame.collapseLabel:SetText(minimized and "+" or "-")
    end
    -- Use saved position if available to avoid overwriting or moving unexpectedly
    local savedPos = (HomeworkTrackerDB and HomeworkTrackerDB.position) or {}
    local left = savedPos.xOfs or frame:GetLeft()
    local top  = savedPos.yOfs or frame:GetTop()
    if minimized then
        if frame.scrollFrame then frame.scrollFrame:Hide() end
        frame:SetHeight(TITLE_BAR_HEIGHT)
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    else
        if frame.scrollFrame then frame.scrollFrame:Show() end
        frame:SetHeight(self:GetFrameHeight())
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    end
end

-- Update layout
function addon:UpdateLayout()
    if not self.mainFrame then return end

    if self.CreateTitleBar then self:CreateTitleBar() end

    if HomeworkTrackerDB.scale then
        self.mainFrame:SetScale(HomeworkTrackerDB.scale)
    end

    self.mainFrame:SetMovable(true)
    if self.mainFrame.titleBar then
        self.mainFrame.titleBar:RegisterForDrag("LeftButton")
    end

    if HomeworkTrackerDB and HomeworkTrackerDB.position then
        local pos = HomeworkTrackerDB.position
        self.mainFrame:ClearAllPoints()
        -- Normalize legacy anchors to TOPLEFT so SetHeight always grows downward
        if pos.point == "TOPLEFT" and pos.relativePoint == "BOTTOMLEFT" then
            self.mainFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", pos.xOfs, pos.yOfs)
        else
            self.mainFrame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.xOfs, pos.yOfs)
            local left = self.mainFrame:GetLeft()
            local top  = self.mainFrame:GetTop()
            self.mainFrame:ClearAllPoints()
            self.mainFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
            pos.point         = "TOPLEFT"
            pos.relativePoint = "BOTTOMLEFT"
            pos.xOfs          = left
            pos.yOfs          = top
        end
    end

    if HomeworkTrackerDB and HomeworkTrackerDB.width then
        local w = self:GetFrameWidth()
        self.mainFrame:SetWidth(w)
        if self.mainFrame.scrollChild then
            self.mainFrame.scrollChild:SetWidth(math.max(20, w - 30))
        end
    end

    self:RefreshTitleBar()
    self:ApplyCollapseState()
end

-- Check visibility state (instance/raid/party/combat/delve)
function addon:CheckVisibilityState()
    local inInstance = IsInInstance()
    local inRaid = IsInRaid()
    local inGroup = IsInGroup()
    local inParty = inGroup and not inRaid
    local inCombat = InCombatLockdown() or UnitAffectingCombat("player")
    local inDelve = self:IsInDelve()

    if inDelve then
        self._inDelves = true
        if self.mainFrame then self.mainFrame:Hide() end
        return
    end

    if self._inDelves then
        self._inDelves = false
        if self.mainFrame then self:UpdateLayout() end
        self:UpdateDisplay()
    end

    if inInstance then
        self._inInstance = true
        if self.mainFrame then self.mainFrame:Hide() end
        return
    end

    if self._inInstance then
        self._inInstance = false
        if self.mainFrame then self:UpdateLayout() end
        self:UpdateDisplay()
    end

    if HomeworkTrackerDB and HomeworkTrackerDB.hideInCombat and inCombat then
        self._inCombat = true
        if self.mainFrame then self.mainFrame:Hide() end
        return
    end

    if self._inCombat then
        self._inCombat = false
        if self.mainFrame then self:UpdateLayout() end
        self:UpdateDisplay()
    end

    if HomeworkTrackerDB and HomeworkTrackerDB.hideInRaid and inRaid then
        self._inRaid = true
        if self.mainFrame then self.mainFrame:Hide() end
        return
    end

    if self._inRaid then
        self._inRaid = false
        if self.mainFrame then self:UpdateLayout() end
        self:UpdateDisplay()
    end

    if HomeworkTrackerDB and HomeworkTrackerDB.hideInParty and inParty then
        self._inParty = true
        if self.mainFrame then self.mainFrame:Hide() end
        return
    end

    if self._inParty then
        self._inParty = false
        if self.mainFrame then self:UpdateLayout() end
        self:UpdateDisplay()
    end

    if HomeworkTrackerDB and HomeworkTrackerDB.hideOutsideMajorCities and not self:IsInMajorCity() then
        self._outsideMajorCity = true
        if self.mainFrame then self.mainFrame:Hide() end
        return
    end

    if self._outsideMajorCity then
        self._outsideMajorCity = false
        if self.mainFrame then self:UpdateLayout() end
        self:UpdateDisplay()
    end
end

-- Create section header string
function addon:CreateSectionHeader(parent, text, yOffset)
    local header = table.remove(headerPool)
    if header then
        header:SetParent(parent)
        header:ClearAllPoints()
        header:Show()
    else
        header = parent:CreateFontString(nil, "OVERLAY")
        header:SetJustifyH("LEFT")
    end
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", 5, yOffset)
    addon:SetFont(header, addon:GetHeaderFontKey(), addon:GetHeaderFontSize(), HomeworkTrackerDB.headerFontOutline)
    header:SetText(text)
    local r, g, b = GetColor("headerText", nil, 0.3, 0.69, 0.93)
    header:SetTextColor(r, g, b, 1)
    header.__isPoolable = true
    header.__poolType   = "header"
    return header
end

-- Create info container line
function addon:CreateContainer(parent, yOffset, hasBar, indent)
    indent = indent or 5
    local container = table.remove(containerPool)
    local fw = self:GetFrameWidth()
    local rightMargin = 15
    local containerWidth = math.max(20, fw - (indent + rightMargin))
    if container then
        container:SetParent(parent)
        container:ClearAllPoints()
        container:SetPoint("TOPLEFT", parent, "TOPLEFT", indent, yOffset)
        container:SetSize(containerWidth, hasBar and 12 or 14)
        if container.nameText then addon:SetFont(container.nameText) end
        if container.timeText then addon:SetFont(container.timeText) end
    else
        container = CreateFrame("Frame", nil, parent)
        container:SetSize(containerWidth, hasBar and 12 or 14)
        container:SetPoint("TOPLEFT", parent, "TOPLEFT", indent, yOffset)
    end
    
    container:EnableMouse(true)
    
    if not container.nameText then
        container.nameText = container:CreateFontString(nil, "OVERLAY")
        addon:SetFont(container.nameText)
    end
    container.nameText:SetPoint(hasBar and "BOTTOMLEFT" or "LEFT", container, hasBar and "TOPLEFT" or "LEFT", 0, hasBar and -8 or 0)
    local lr,lg,lb = GetColor("textLeft", nil, 1,1,1)
    container.nameText:SetTextColor(lr, lg, lb, 1)
    container.nameText:SetJustifyH("LEFT")
    container.nameText:Show()
    
    if not container.timeText then
        container.timeText = container:CreateFontString(nil, "OVERLAY")
        addon:SetFont(container.timeText)
    end
    container.timeText:SetPoint(hasBar and "BOTTOMRIGHT" or "RIGHT", container, hasBar and "TOPRIGHT" or "RIGHT", -16, hasBar and -8 or 0)
    local rr,rg,rb = GetColor("textRight", nil, 1,1,1)
    container.timeText:SetTextColor(rr, rg, rb, 1)
    container.timeText:SetJustifyH("RIGHT")
    container.timeText:Show()

    if container.timeText then
        container.timeText:EnableMouse(false)
        container.timeText:SetScript("OnMouseUp", nil)
        container.timeText:SetScript("OnEnter", nil)
        container.timeText:SetScript("OnLeave", nil)
    end
    GameTooltip:Hide()
    
    if not container.icon then
        container.icon = container:CreateTexture(nil, "OVERLAY")
    end
    container.icon:SetSize(hasBar and 10 or 12, hasBar and 10 or 12)
    if hasBar then
        container.icon:SetPoint("BOTTOMRIGHT", container, "TOPRIGHT", -2, -8)
    else
        container.icon:SetPoint("RIGHT", container, "RIGHT", -2, 0)
    end
    
    if not container.iconButton then
        container.iconButton = CreateFrame("Button", nil, container)
    end
    container.iconButton:ClearAllPoints()
    container.iconButton:SetAllPoints(container.icon)
    
    container.text = container.nameText
    container.value = container.timeText
    
    if hasBar then
        if not container.bg then
            container.bg = container:CreateTexture(nil, "BACKGROUND")
        end
        container.bg:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
        container.bg:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -12, 0)
        container.bg:SetHeight(8)
        container.bg:SetColorTexture(0, 0, 0, 0.5)

        if not container.progress then
            container.progress = container:CreateTexture(nil, "ARTWORK")
        end
        container.progress:SetPoint("TOPLEFT", container.bg, "TOPLEFT", 1, -1)
        container.progress:SetPoint("BOTTOMLEFT", container.bg, "BOTTOMLEFT", 1, 1)
        container.progress:SetPoint("TOPRIGHT", container.bg, "TOPRIGHT", -1, -1)
        container.progress:SetPoint("BOTTOMRIGHT", container.bg, "BOTTOMRIGHT", -1, 1)
        local dR,dG,dB = unpack(addon.defaultColors.progress or {0.5,0.5,0.5})
        local texPath = addon:GetBarTexture()
        if texPath then
            container.progress:SetTexture(texPath)
            container.progress:SetVertexColor(dR, dG, dB, 0.8)
        else
            container.progress:SetTexture(nil)
            container.progress:SetVertexColor(1, 1, 1, 1)
            container.progress:SetColorTexture(dR, dG, dB, 0.8)
        end
        container.progress:Show()
    else
        if container.progress then container.progress:Hide() end
    end
    
    container.__isPoolable = true
    return container
end

-- Set progress bar colors
function addon:SetBarColor(bar, r, g, b, a)
    a = a or 0.8
    if bar.progress then
        if bar.progress:GetTexture() then
            bar.progress:SetVertexColor(r, g, b, a)
        else
            bar.progress:SetVertexColor(1, 1, 1, 1)
            bar.progress:SetColorTexture(r, g, b, a)
        end
    end
    if bar.bg then
        local bgFactor = 0.45
        local bgAlpha = math.min(0.7, a * 0.9)
        bar.bg:SetColorTexture(r * bgFactor, g * bgFactor, b * bgFactor, bgAlpha)
    end
end

-- Refresh display
function addon:UpdateDisplay()
    if not self.mainFrame or not self.mainFrame.scrollChild then return end
    if HomeworkTrackerDB and HomeworkTrackerDB.enabled == false then
        if self.mainFrame then self.mainFrame:Hide() end
        return
    end
    
    local parent = self.mainFrame.scrollChild
    local yOffset = -5
    
    for _, section in ipairs(self.sections) do
        if section and section.__isPoolable then
            ReleaseContainer(section)
        else
            if section and section.Hide then section:Hide() end
        end
    end
    wipe(self.sections)
    
    if self.RunModules then
        yOffset = self:RunModules(parent, yOffset) 
    else
        local expStates = HomeworkTrackerDB.expansions or {}
        yOffset = self:UpdateActivitiesSection(parent, yOffset, expStates)
        yOffset = self:UpdateDelvesSection(parent, yOffset, expStates)
        yOffset = self:UpdateGreatVaultSection(parent, yOffset, expStates)
        yOffset = self:UpdateWeeklySection(parent, yOffset, expStates)
        yOffset = self:UpdateCrestsSection(parent, yOffset, expStates)
        yOffset = self:UpdateCurrencySection(parent, yOffset, expStates)
        yOffset = self:UpdateReputationsSection(parent, yOffset, expStates)
        yOffset = self:UpdateRaresSection(parent, yOffset, expStates)
    end
    
    parent:SetHeight(math.abs(yOffset) + 10)
    
    if #self.sections > 0 and not self._inInstance and not self._inDelves
       and not (self._inParty and HomeworkTrackerDB.hideInParty)
       and not (self._inRaid and HomeworkTrackerDB.hideInRaid)
       and not (self._inCombat and HomeworkTrackerDB.hideInCombat)
       and not (self._outsideMajorCity and HomeworkTrackerDB.hideOutsideMajorCities) then
        self.mainFrame:Show()
        self:ApplyCollapseState()
    else
        self.mainFrame:Hide()
    end
end

function addon:UpdateActivityTimers()
    if not self.sections then return end
    local rr, rg, rb = GetColor("textRight", nil, 1, 1, 1)
    for _, section in ipairs(self.sections) do
        if section._activityKey then
            local timing = self:GetEventTiming(section._activityKey)
            if timing then
                if timing.active then
                    section.timeText:SetText("Active - " .. self:FormatTime(timing.remaining))
                    section.timeText:SetTextColor(0.4, 1, 0.4, 1)
                else
                    section.timeText:SetText(self:FormatTime(timing.remaining))
                    section.timeText:SetTextColor(rr, rg, rb, 1)
                end
            end
        end
    end
end

-- Refresh activities
function addon:UpdateActivitiesSection(parent, yOffset, expStates)
    local cfg = HomeworkTrackerDB.activities
    if not cfg.activityEnable then return yOffset end
    
    local hasContent = false
    local startY = yOffset
    
    local header = self:CreateSectionHeader(parent, "Activities", yOffset)
    yOffset = yOffset - 20
    
    local events = {}
    for key, event in pairs(addon.eventDB) do
        if event.expansion and expStates[event.expansion] then
             if cfg[key] then
                 table.insert(events, {key = key, data = event})
             end
        end
    end

    table.sort(events, function(a, b) 
        return self:GetEventName(a.key) < self:GetEventName(b.key)
    end)
    
    for _, item in ipairs(events) do
        local key = item.key
        local event = item.data
        
        local timing = self:GetEventTiming(key)
        if timing and (not cfg.hideComplete or not self:IsEventComplete(key)) then
            hasContent = true
            local bar = self:CreateContainer(parent, yOffset, true)
            bar._activityKey = key
            bar.nameText:SetText(self:GetEventName(key))
            bar.icon:Hide()
            
            if timing.active then
                bar.timeText:SetText("Active - " .. self:FormatTime(timing.remaining))
                bar.timeText:SetTextColor(0.4, 1, 0.4, 1)
            else
                bar.timeText:SetText(self:FormatTime(timing.remaining))
                local rr,rg,rb = GetColor("textRight", nil, 1,1,1)
                bar.timeText:SetTextColor(rr, rg, rb, 1)
            end
            
            local defaultR, defaultG, defaultB = 0.5, 0.5, 0.5
            if event.color then 
                defaultR, defaultG, defaultB = unpack(event.color) 
            end
            
            local r, g, b = GetColor("activities", key, defaultR, defaultG, defaultB)
            addon:SetBarColor(bar, r, g, b, 0.8)
            
            table.insert(self.sections, bar)
            bar:Show()
            yOffset = yOffset - 18
        end
    end
    
    if hasContent then
        table.insert(self.sections, header)
        header:Show()
        return yOffset - 8
    else
        ReleaseContainer(header)
        return startY
    end
end

-- Refresh vault
function addon:UpdateGreatVaultSection(parent, yOffset, expStates)
    local cfg = HomeworkTrackerDB.greatVault
    if not cfg.enable then return yOffset end
    
    local vaultData = self:GetGreatVaultInfo()
    if not vaultData then return yOffset end
    
    local hasData = (#vaultData.raid > 0 and cfg.showRaid) or 
                    (#vaultData.mythicPlus > 0 and cfg.showMythicPlus) or 
                    (#vaultData.delves > 0 and cfg.showDelves)
    
    if not hasData then return yOffset end
    
    local header = self:CreateSectionHeader(parent, "Great Vault", yOffset)
    table.insert(self.sections, header)
    yOffset = yOffset - 20
    
    local r, g, b = GetColor("vault")

    local function mapRewardToIcon(itemLevel)
        if not itemLevel then return 1 end
        if itemLevel >= 272 then return 5 end
        if itemLevel >= 259 then return 4 end
        if itemLevel >= 246 then return 3 end
        if itemLevel >= 233 then return 2 end
        return 1
    end

    if cfg.showRaid and #vaultData.raid > 0 then
        local bar = self:CreateContainer(parent, yOffset, true)
        bar.nameText:SetText("Raid")

        local valueText = ""
        for i = 1, 3 do
            if i <= #vaultData.raid and vaultData.raid[i].progress >= vaultData.raid[i].threshold then
                local entry = vaultData.raid[i]
                local lvl
                if entry.itemLevel then
                    lvl = mapRewardToIcon(entry.itemLevel)
                elseif entry.rewardLevel then
                    lvl = mapRewardToIcon(entry.rewardLevel)
                elseif entry.level then
                    lvl = entry.level
                else
                    lvl = 1
                end
                if lvl < 1 then lvl = 1 end
                if lvl > 5 then lvl = 5 end
                valueText = valueText .. string.format("|A:Professions-ChatIcon-Quality-Tier%d:18:18::1|a ", lvl)
            else
                valueText = valueText .. "|TInterface\\RaidFrame\\ReadyCheck-NotReady:18:18|t "
            end
        end
        bar.timeText:SetText(valueText)
        
        addon:SetBarColor(bar, r, g, b, 0.8)
        
        table.insert(self.sections, bar)
        bar:Show()
        yOffset = yOffset - 18
    end
    
    if cfg.showMythicPlus and #vaultData.mythicPlus > 0 then
        local bar = self:CreateContainer(parent, yOffset, true)
        bar.nameText:SetText("Mythic+")

        local valueText = ""
        for i = 1, 3 do
            if i <= #vaultData.mythicPlus and vaultData.mythicPlus[i].progress >= vaultData.mythicPlus[i].threshold then
                local entry = vaultData.mythicPlus[i]
                local lvl
                if entry.itemLevel then
                    lvl = mapRewardToIcon(entry.itemLevel)
                elseif entry.rewardLevel then
                    lvl = mapRewardToIcon(entry.rewardLevel)
                elseif entry.level then
                    lvl = entry.level
                else
                    lvl = 1
                end
                if lvl < 1 then lvl = 1 end
                if lvl > 5 then lvl = 5 end
                valueText = valueText .. string.format("|A:Professions-ChatIcon-Quality-Tier%d:18:18::1|a ", lvl)
            else
                valueText = valueText .. "|TInterface\\RaidFrame\\ReadyCheck-NotReady:18:18|t "
            end
        end
        bar.timeText:SetText(valueText)
        
        addon:SetBarColor(bar, r, g, b, 0.8)
        
        table.insert(self.sections, bar)
        bar:Show()
        yOffset = yOffset - 18
    end

    if cfg.showDelves and #vaultData.delves > 0 then
        local bar = self:CreateContainer(parent, yOffset, true)
        bar.nameText:SetText("Delves")

        local valueText = ""
        for i = 1, 3 do
            if i <= #vaultData.delves and vaultData.delves[i].progress >= vaultData.delves[i].threshold then
                local entry = vaultData.delves[i]
                local lvl
                if entry.itemLevel then
                    lvl = mapRewardToIcon(entry.itemLevel)
                elseif entry.rewardLevel then
                    lvl = mapRewardToIcon(entry.rewardLevel)
                elseif entry.level then
                    lvl = entry.level
                else
                    lvl = 1
                end
                if lvl < 1 then lvl = 1 end
                if lvl > 5 then lvl = 5 end
                valueText = valueText .. string.format("|A:Professions-ChatIcon-Quality-Tier%d:18:18::1|a ", lvl)
            else
                valueText = valueText .. "|TInterface\\RaidFrame\\ReadyCheck-NotReady:18:18|t "
            end
        end
        bar.timeText:SetText(valueText)
        
        addon:SetBarColor(bar, r, g, b, 0.8)
        
        table.insert(self.sections, bar)
        bar:Show()
        yOffset = yOffset - 18
    end
    
    return yOffset - 8
end

-- Refresh weekly items
function addon:UpdateWeeklySection(parent, yOffset, expStates)
    local cfg = HomeworkTrackerDB.weekly
    if not cfg.enable then return yOffset end
    
    local startY = yOffset
    local hasContent = false
    
    local header = self:CreateSectionHeader(parent, "Weekly", yOffset)
    yOffset = yOffset - 20
    
    local quests = self:GetWeeklyQuestInfo()
    local hidden = cfg.hidden or {}
    
    for _, quest in ipairs(quests) do
        local isHidden = hidden[quest.name]
        
        if (not quest.expansion or expStates[quest.expansion]) and not isHidden and (not cfg.hideComplete or not quest.isComplete) then
            hasContent = true
            local bar = self:CreateContainer(parent, yOffset, true)
            bar.nameText:SetText(quest.name)
            bar.icon:Hide()

            if quest.handler == "prey" then
                local n, h, m = 0, 0, 0
                if type(quest.preyCounts) == "table" then
                    n = tonumber(quest.preyCounts.normal) or 0
                    h = tonumber(quest.preyCounts.hard) or 0
                    m = tonumber(quest.preyCounts.nightmare) or 0
                end

                local preyAtlases = { "UI-HUD-Minimap-GuildBanner-Normal-Large", "UI-HUD-Minimap-GuildBanner-Heroic-Large", "UI-HUD-Minimap-GuildBanner-Mythic-Large" }
                local preyLabels = { "Normal", "Hard", "Nightmare" }
                local preyCounts = { n, h, m }

                bar.timeText:SetText("")
                bar.timeText:Hide()
                bar.preyElements = bar.preyElements or {}
                for i = 1, 3 do
                    local idx = (#preyCounts - i + 1)
                    local count = preyCounts[idx]
                    local atlas = preyAtlases[idx]
                    local label = preyLabels[idx]
                    local elem = bar.preyElements[i]

                    if not elem then
                        elem = CreateFrame("Frame", nil, bar)
                        elem.icon = elem:CreateTexture(nil, "ARTWORK")
                        elem.icon:SetSize(12, 12)
                        elem.qtyText = elem:CreateFontString(nil, "OVERLAY")
                        addon:SetFont(elem.qtyText)
                        elem.qtyText:SetJustifyH("RIGHT")
                        elem.iconButton = CreateFrame("Button", nil, elem)
                        bar.preyElements[i] = elem
                    end

                    local rr, rg, rb = GetColor("textRight", nil, 1, 1, 1)
                    elem.qtyText:SetTextColor(rr, rg, rb, 1)

                    elem.qtyText:SetText(tostring(count) .. "/4")
                    addon:SetFont(elem.qtyText)
                    elem.qtyText:Show()

                    local fontSize = addon:GetFontSize() or 12
                    local iconSize = math.max(8, math.floor(fontSize) + 2)
                    local qtyTextWidth = math.max(8, math.ceil(elem.qtyText:GetStringWidth()))
                    local preyIconWidth = iconSize
                    local qtyIconGap = 1
                    local elementHorizontalPadding = 2
                    local elementWidth = math.max(34, qtyTextWidth + preyIconWidth + qtyIconGap + elementHorizontalPadding)
                    elem:SetSize(elementWidth, iconSize)
                    elem.qtyText:SetWidth(qtyTextWidth)

                    if elem.icon.SetAtlas then
                        elem.icon:SetAtlas(atlas, true)
                    end
                    elem.icon:SetSize(iconSize, iconSize)

                    elem.icon:Show()
                    elem:ClearAllPoints()

                    if i == 1 then
                        elem:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", -15, -8)
                    else
                        elem:SetPoint("BOTTOMRIGHT", bar.preyElements[i-1], "BOTTOMLEFT", -1, 0)
                    end

                    elem.icon:SetPoint("RIGHT", elem, "RIGHT", -1, 0)
                    elem.qtyText:SetPoint("RIGHT", elem.icon, "LEFT", -1, 0)
                    elem.icon:SetSize(iconSize, iconSize)

                    if elem.iconButton then
                        elem.iconButton:ClearAllPoints()
                        elem.iconButton:SetAllPoints(elem.icon)
                        local difficultyKeys = { "normal", "hard", "nightmare" }
                        local difficultyKey = difficultyKeys[idx]
                        local difficultyLabel = label or (difficultyKey and (difficultyKey:sub(1,1):upper() .. difficultyKey:sub(2))) or ""
                        elem.iconButton:SetScript("OnEnter", function(self)
                            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                            GameTooltip:ClearLines()
                            GameTooltip:SetText(difficultyLabel, 1, 1, 1)

                            local foundAny = false
                            local idsTable = quest.preyQuestIDs and quest.preyQuestIDs[difficultyKey]
                            if idsTable and type(idsTable) == "table" then
                                for _, qid in ipairs(idsTable) do
                                    if addon:IsQuestComplete(qid) then
                                        foundAny = true
                                        local title = (C_TaskQuest and C_TaskQuest.GetQuestInfoByQuestID and C_TaskQuest.GetQuestInfoByQuestID(qid))
                                                  or (C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(qid))
                                                  or tostring(qid)
                                        local icon = "|TInterface\\RaidFrame\\ReadyCheck-Ready:12:12|t "
                                        GameTooltip:AddLine(icon .. (title or tostring(qid)), 0.8, 0.8, 0.8, true)
                                    end
                                end
                            end

                            if not foundAny then
                                GameTooltip:AddLine("(none)", 0.8, 0.8, 0.8, true)
                            end
                            GameTooltip:Show()
                        end)
                        elem.iconButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
                    end

                    elem:Show()
                end

                local total = #preyCounts
                for j = total + 1, #bar.preyElements do
                    if bar.preyElements[j] then bar.preyElements[j]:Hide() end
                end
            else
                if quest.info ~= "" then
                    bar.timeText:SetText(quest.info)
                else
                    bar.timeText:SetText("")
                end
            end

            local catID = quest.category or "general"
            local catInfo = addon.categoryInfo and addon.categoryInfo[catID]
            if not catInfo and addon.categoryInfo then
                catInfo = addon.categoryInfo["general"]
            end

            if quest.handler and addon.weeklyHandlers and addon.weeklyHandlers[quest.handler] then
                addon.weeklyHandlers[quest.handler](bar, quest)
            end

            local defaultR, defaultG, defaultB = 0.255, 0.439, 0.929
            if catInfo and catInfo.color then
                defaultR, defaultG, defaultB = unpack(catInfo.color)
            end

            local r, g, b = defaultR, defaultG, defaultB

            if catID == "general" then
                 r, g, b = GetColor("weekly", nil, defaultR, defaultG, defaultB)
            else
                 r, g, b = GetColor("zones", catID, defaultR, defaultG, defaultB)
            end

            addon:SetBarColor(bar, r, g, b, 0.8)
            
            table.insert(self.sections, bar)
            bar:Show()
            yOffset = yOffset - 18
        end
    end
    
    if hasContent then
        table.insert(self.sections, header)
        header:Show()
        return yOffset - 8
    else
        ReleaseContainer(header)
        return startY
    end
end

-- Refresh crests
function addon:UpdateCrestsSection(parent, yOffset, expStates)
    local crestCfg = HomeworkTrackerDB.crests
    if not crestCfg.enable then return yOffset end
    
    local hasContent = false
    local startY = yOffset
    
    local header = self:CreateSectionHeader(parent, "Crests", yOffset)
    yOffset = yOffset - 20
    
    local r, g, b = GetColor("currency", nil, 0.3, 0.3, 0.3)
    local visible = {}
    for _, crest in ipairs(self.crestDB or {}) do
        if not crest.expansion or expStates[crest.expansion] then
            local showCrest = crestCfg[crest.id]
            if showCrest == nil then showCrest = true end
            if showCrest then
                local info = self:GetCurrencyInfo(crest.id)
                if info then
                    table.insert(visible, { id = crest.id, icon = info.iconFileID or crest.icon, quantity = info.quantity, maxQuantity = info.maxQuantity })
                end
            end
        end
    end

    if #visible > 0 then
        hasContent = true

        local bar = self:CreateContainer(parent, yOffset, true)
        bar.nameText:SetText("Crests")
        bar.icon:Hide()
        addon:SetBarColor(bar, r, g, b, 0.8)

        bar.timeText:SetText(""); bar.timeText:Hide()
        bar.crestElements = bar.crestElements or {}
        -- Anchor right-to-left
        for i = 1, #visible do
            local data = visible[#visible - i + 1]
            local elem = bar.crestElements[i]
            if not elem then
                elem = CreateFrame("Frame", nil, bar)
                elem:SetSize(34, 12)
                elem.icon = elem:CreateTexture(nil, "ARTWORK")
                elem.icon:SetSize(12, 12)
                elem.qtyText = elem:CreateFontString(nil, "OVERLAY")
                addon:SetFont(elem.qtyText)
                elem.qtyText:SetJustifyH("RIGHT")
                local rr, rg, rb = GetColor("textRight", nil, 1, 1, 1)
                elem.qtyText:SetTextColor(rr, rg, rb, 1)
                elem.iconButton = CreateFrame("Button", nil, elem)
                bar.crestElements[i] = elem
            end

            local qtyStr = tostring(data.quantity)
            elem.qtyText:SetText(qtyStr)
            addon:SetFont(elem.qtyText)
            local rr, rg, rb = GetColor("textRight", nil, 1, 1, 1)
            elem.qtyText:SetTextColor(rr, rg, rb, 1)
            elem.qtyText:Show()

            local fontSize = addon:GetFontSize() or 12
            local iconSize = math.max(10, math.floor(fontSize) + 2)
            local qtyTextWidth = math.max(8, math.ceil(elem.qtyText:GetStringWidth()))
            local crestIconWidth = iconSize
            local qtyIconGap = 1
            local elementHorizontalPadding = 2
            local elementWidth = qtyTextWidth + crestIconWidth + qtyIconGap + elementHorizontalPadding

            elem:SetSize(elementWidth, iconSize)
            elem.qtyText:SetWidth(qtyTextWidth)
            elem.icon:SetSize(iconSize, iconSize)

            if type(data.icon) == "number" then
                elem.icon:SetTexture(data.icon)
            else
                elem.icon:SetTexture("Interface\\Icons\\" .. tostring(data.icon))
            end

            elem.icon:Show()
            elem:ClearAllPoints()

            if i == 1 then
                elem:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", -17, -8)
            else
                elem:SetPoint("BOTTOMRIGHT", bar.crestElements[i-1], "BOTTOMLEFT", -1, 0)
            end

            elem.icon:SetPoint("RIGHT", elem, "RIGHT", -1, 0)
            elem.qtyText:SetPoint("RIGHT", elem.icon, "LEFT", -1, 0)
            if elem.iconButton then
                elem.iconButton:ClearAllPoints()
                elem.iconButton:SetAllPoints(elem.icon)
                elem.iconButton:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    if data.id then
                        GameTooltip:SetCurrencyByID(data.id)
                    end
                    GameTooltip:Show()
                end)
                elem.iconButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
            end
            elem:Show()
        end

        for j = #visible + 1, #bar.crestElements do
            if bar.crestElements[j] then bar.crestElements[j]:Hide() end
        end

        table.insert(self.sections, bar)
        bar:Show()
        yOffset = yOffset - 18
    end
    
    if hasContent then
        table.insert(self.sections, header)
        header:Show()
        return yOffset - 8
    else
        ReleaseContainer(header)
        return startY
    end
end

-- Refresh currency
function addon:UpdateCurrencySection(parent, yOffset, expStates)
    local cfg = HomeworkTrackerDB.currency or {}
    if not cfg.enable then return yOffset end
    
    local hasContent = false
    local startY = yOffset
    
    local header = self:CreateSectionHeader(parent, "Currencies & Items", yOffset)
    yOffset = yOffset - 20
    
    local r, g, b = GetColor("currency", nil, 0.3, 0.3, 0.3)
    
    local fmt = cfg.format or "both"
    for _, currency in ipairs(self.currencyDB) do
        if not currency.expansion or expStates[currency.expansion] then
            local showCurrency = cfg[currency.id]
            if showCurrency == nil then showCurrency = true end
            
            if showCurrency then
                local info = self:GetCurrencyInfo(currency.id)
                if info then
                    hasContent = true
                    local bar = self:CreateContainer(parent, yOffset, true)
                    local iconID = currency.icon or info.iconFileID
                    
                    bar.nameText:SetText(currency.name)
                    
                    bar.icon:Hide()
                    addon:SetBarColor(bar, r, g, b, 0.8)
                    local iconStr = " |T" .. iconID .. ":14:14:-2:0|t"
                    bar.iconButton:Show()
                    bar.iconButton:SetSize(16, 16)
                    bar.iconButton:ClearAllPoints()
                    bar.iconButton:SetPoint("RIGHT", bar.timeText, "RIGHT", 0, 0)
                    bar.iconButton:SetScript("OnEnter", function(self)
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        if not C_CurrencyInfo.GetCurrencyInfo(currency.id) then
                            GameTooltip:SetItemByID(currency.id)
                        else
                            GameTooltip:SetCurrencyByID(currency.id)
                        end
                        GameTooltip:Show()
                    end)
                    bar.iconButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
                    bar.iconButton:SetScript("OnMouseUp", function(self)
                    end)
                    local cap = info.maxQuantity or 0
                    if currency.max and currency.max > 0 then
                        cap = currency.max
                    end
                    if cap > 0 then
                        local percent = math.floor((info.quantity / cap) * 100)
                        if fmt == "percent" then
                            bar.timeText:SetText(string.format("%s (%d%%)", info.quantity, percent) .. iconStr)
                        elseif fmt == "slash" then
                            bar.timeText:SetText(string.format("%s/%s", info.quantity, cap) .. iconStr)
                        else
                            bar.timeText:SetText(string.format("%s/%s (%d%%)", info.quantity, cap, percent) .. iconStr)
                        end
                    else
                        bar.timeText:SetText(tostring(info.quantity) .. iconStr)
                    end
                    
                    table.insert(self.sections, bar)
                    bar:Show()
                    yOffset = yOffset - 18
                end
            end
        end
    end
    
    if hasContent then
        table.insert(self.sections, header)
        header:Show()
        return yOffset - 8
    else
        ReleaseContainer(header)
        return startY
    end
end

-- Refresh reputations
function addon:UpdateReputationsSection(parent, yOffset, expStates) 
    local cfg = HomeworkTrackerDB.reputations
    if not cfg.enable then return yOffset end
    
    local hasContent = false
    local startY = yOffset
    
    local header = self:CreateSectionHeader(parent, "Reputations", yOffset)
    yOffset = yOffset - 20
    
    local hidden = cfg.hidden or {}
    
    local sortedReputations = {}

    for _, rep in ipairs(self.reputationDB) do
        if not rep.expansion or (expStates and expStates[rep.expansion]) then
            table.insert(sortedReputations, rep)
        end
    end
    
    table.sort(sortedReputations, function(a,b)
        local orderA = a.order or 99
        local orderB = b.order or 99
        
        if orderA ~= orderB then
            return orderA < orderB
        end
        return a.name < b.name
    end)
    
    for _, rep in ipairs(sortedReputations) do
        if not hidden[rep.id] then
            local info = self:GetReputationInfo(rep.id)
            if info then
                local isMaxed = info.isMaxed or (info.isStandard and info.reaction == 8)

                local skipDueToZeroStart = false
                if not isMaxed and info.renownReputationEarned == 0 then
                    if info.isRenown then
                        if (not info.renownLevel) or info.renownLevel <= 1 then
                            skipDueToZeroStart = true
                        end
                    elseif info.isStandard then
                        if info.isFirstRank then
                            skipDueToZeroStart = true
                        end
                    elseif info.isFriend then
                        skipDueToZeroStart = true
                    end
                end

                if not skipDueToZeroStart and (not cfg.hideComplete or not isMaxed) then
                    hasContent = true
                    local bar = self:CreateContainer(parent, yOffset, true)
                    bar.nameText:SetText(info.name)
                    bar.icon:SetAtlas("vignetteloot")
                    bar.icon:Show()
                    
                    local catID = rep.category or "general"
                    local catInfo = addon.categoryInfo and addon.categoryInfo[catID]
                    if not catInfo and addon.categoryInfo then
                         catInfo = addon.categoryInfo["general"]
                    end
                    local defaultR, defaultG, defaultB = 0.5, 0.5, 0.5
                    if catInfo and catInfo.color then
                        defaultR, defaultG, defaultB = unpack(catInfo.color)
                    end

                    local r, g, b
                    if catID == "delves" then
                        r, g, b = GetColor("delveCompanion", nil, defaultR, defaultG, defaultB)
                    else
                        r, g, b = GetColor("zones", catID, defaultR, defaultG, defaultB)
                    end

                    addon:SetBarColor(bar, r, g, b, 0.8)
                    
                    local percent = 0
                    if info.renownLevelThreshold > 0 then
                        percent = math.floor((info.renownReputationEarned / info.renownLevelThreshold) * 100)
                    end
                    
                    local levelDisp = info.label or info.renownLevel or "?"
                    
                    if isMaxed or (info.isStandard and info.reaction == 8) then
                        bar.timeText:SetText(string.format("%s (MAX)", levelDisp))
                    else
                        bar.timeText:SetText(string.format("%s (%d%%)", levelDisp, percent))
                    end
                    
                    table.insert(self.sections, bar)
                    bar:Show()
                    yOffset = yOffset - 18
                end
            end
        end
    end
    
    if hasContent then
        table.insert(self.sections, header)
        header:Show()
        return yOffset - 8
    else
        ReleaseContainer(header)
        return startY
    end
end

-- Refresh progress
function addon:UpdateProgressSection(parent, yOffset, expStates)
    local cfg = HomeworkTrackerDB.progress
    if not cfg.enable then return yOffset end

    local hasContent = false
    local startY = yOffset

    local header = self:CreateSectionHeader(parent, "Season Progress", yOffset)
    yOffset = yOffset - 20

    local hidden = cfg.hidden or {}

    local sortedProgress = {}
    for _, prog in ipairs(self.progressDB or {}) do
        if not prog.expansion or (expStates and expStates[prog.expansion]) then
            table.insert(sortedProgress, prog)
        end
    end

    table.sort(sortedProgress, function(a,b)
        local orderA = a.order or 99
        local orderB = b.order or 99
        if orderA ~= orderB then
            return orderA < orderB
        end
        return a.name < b.name
    end)

    for _, prog in ipairs(sortedProgress) do
        if not hidden[prog.id] then
            local info = self:GetProgressInfo(prog.id)

            local skipZeroStart = false
            if info then
                if info.isMaxed then
                    skipZeroStart = true
                elseif info.renownReputationEarned == 0 then
                    if (not info.renownLevel) or info.renownLevel <= 0 then
                        skipZeroStart = true
                    end
                end
            end

            if not skipZeroStart then
                hasContent = true
                local bar = self:CreateContainer(parent, yOffset, true)
                bar.nameText:SetText(info.name)
                bar.icon:SetAtlas("vignetteloot")
                bar.icon:Show()

                local defaultR, defaultG, defaultB = unpack(addon.defaultColors.progress or {0.5,0.5,0.5})
                local r,g,b = GetColor("progress", nil, defaultR, defaultG, defaultB)
                addon:SetBarColor(bar, r,g,b,0.8)

                local isMaxed = info.isMaxed or false
                local percent = 0
                if info.renownLevelThreshold > 0 then
                    percent = math.floor((info.renownReputationEarned / info.renownLevelThreshold) * 100)
                end
                local levelDisp = info.renownLevel or "?"
                if isMaxed then
                    bar.timeText:SetText(string.format("%s (MAX)", levelDisp))
                else
                    bar.timeText:SetText(string.format("%s (%d%%)", levelDisp, percent))
                end

                table.insert(self.sections, bar)
                bar:Show()
                yOffset = yOffset - 18
            end
        end
    end

    if hasContent then
        table.insert(self.sections, header)
        header:Show()
        return yOffset - 8
    else
        ReleaseContainer(header)
        return startY
    end
end

-- Refresh rares
function addon:UpdateRaresSection(parent, yOffset, expStates)
    local cfg = HomeworkTrackerDB.rares
    if not cfg.enable then return yOffset end
    
    local hasContent = false
    local startY = yOffset
    
    local currentZone = cfg.currentZone and GetZoneText() or nil
    local rares = self:GetRareInfo(currentZone)
    
    if cfg.currentZone and #rares == 0 then
        return startY
    end
    
    local hasVisibleRares = false
    for _, rare in ipairs(rares) do
        if (not rare.expansion or expStates[rare.expansion])
            and (not cfg.hideComplete or not rare.isComplete)
            and (not cfg.hideRepComplete or not rare.isRepComplete) then
            hasVisibleRares = true
            break
        end
    end
    
    if not hasVisibleRares then
        return startY
    end
    
    local header = self:CreateSectionHeader(parent, "Rares", yOffset)
    yOffset = yOffset - 20
    
    local zones = {}
    for _, rare in ipairs(rares) do
        if (not rare.expansion or expStates[rare.expansion])
            and (not cfg.hideComplete or not rare.isComplete)
            and (not cfg.hideRepComplete or not rare.isRepComplete) then
            local z = rare.zone or "Unknown"
            zones[z] = zones[z] or {}
            table.insert(zones[z], rare)
            hasContent = true
        end
    end

    local DEFAULT_ZONE_PRIORITY = 99

    local zoneNames = {}
    for zn, _ in pairs(zones) do table.insert(zoneNames, zn) end
    table.sort(zoneNames, function(a, b)
        local pa = addon.zonePriority and addon.zonePriority[a] or DEFAULT_ZONE_PRIORITY
        local pb = addon.zonePriority and addon.zonePriority[b] or DEFAULT_ZONE_PRIORITY
        if pa ~= pb then return pa < pb end
        return a < b
    end)

    for _, zn in ipairs(zoneNames) do
        local list = zones[zn]
        local isHidden = cfg.hiddenZones and cfg.hiddenZones[zn]
        
        if list and #list > 0 and not isHidden then
            local zoneHeader = self:CreateContainer(parent, yOffset, true)
            addon.expandedZones = addon.expandedZones or {}
            local expanded = addon.expandedZones[zn]
            if expanded == nil then expanded = false end -- Collapsed by default
            
            local arrowExpanded = "- "
            local arrowCollapsed = "+ "
            
            zoneHeader.nameText:SetText((expanded and arrowExpanded or arrowCollapsed) .. zn)
            zoneHeader.icon:Hide()
            zoneHeader.timeText:SetText(string.format("%d", #list))
            
            local zcolor = {0.5, 0.5, 0.5}
            local catID = addon.zoneCategoryMap and addon.zoneCategoryMap[zn]
            local catInfo = addon.categoryInfo and addon.categoryInfo[catID]
            if not catInfo and addon.categoryInfo then catInfo = addon.categoryInfo["general"] end
            
            local defR, defG, defB = 0.5, 0.5, 0.5
            if catInfo and catInfo.color then
                defR, defG, defB = unpack(catInfo.color)
            end
            
            local r, g, b = GetColor("zones", catID, defR, defG, defB)
            zcolor = {r, g, b}
            
            addon:SetBarColor(zoneHeader, zcolor[1], zcolor[2], zcolor[3], 0.9)
            zoneHeader:SetScript("OnMouseUp", function()
                addon.expandedZones = addon.expandedZones or {}
                addon.expandedZones[zn] = not (addon.expandedZones[zn])
                addon:UpdateDisplay()
            end)
            table.insert(self.sections, zoneHeader)
            zoneHeader:Show()
            yOffset = yOffset - 18

            table.sort(list, function(a,b) return (a.name or "") < (b.name or "") end)

            if expanded then
                for _, r in ipairs(list) do
                    local rare = r
                    local bar = self:CreateContainer(parent, yOffset, true, 20)

                    bar.nameText:SetText(rare.name)
                    bar.timeText:SetText("|A:DungeonSkull:14:14|a")
                    bar.icon:Hide()

                    addon:SetBarColor(bar, zcolor[1], zcolor[2], zcolor[3], 0.8)

                    local mapID = addon.zoneIDs and addon.zoneIDs[rare.zone]

                    if mapID then
                        bar.iconButton:Show()
                        bar.iconButton:SetSize(16, 16)
                        bar.iconButton:ClearAllPoints()
                        bar.iconButton:SetPoint("RIGHT", bar.timeText, "RIGHT", 0, 0)

                        bar.iconButton:SetScript("OnEnter", function(self)
                            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                            GameTooltip:SetText(rare.name, 1, 1, 1)
                            GameTooltip:AddLine(rare.zone, 1, 1, 1)
                            GameTooltip:AddLine(" ")
                            if rare.x and rare.y then
                                GameTooltip:AddLine(string.format("Coords: %.1f, %.1f", rare.x, rare.y), 1, 1, 1)
                            end
                            if rare.phaseDivingRequired then
                                GameTooltip:AddLine("|cffff8800Phase Diving is required|r", 1, 0.6, 0)
                            end
                            GameTooltip:AddLine("|cff00ff00Ctrl + Click|r to set waypoint", 0.7, 0.7, 0.7)
                            if TomTom and rare.x and rare.y then
                                GameTooltip:AddLine("Arrow only visible in correct zone", 1, 0.5, 0)
                            end
                            GameTooltip:Show()
                        end)
                        bar.iconButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

                        bar.iconButton:SetScript("OnMouseUp", function(self)
                            if IsControlKeyDown() then
                                if TomTom and rare.x and rare.y then
                                    local uid = TomTom:AddWaypoint(mapID, rare.x / 100, rare.y / 100, {
                                        title = rare.name,
                                        persistent = false,
                                        minimap = true,
                                        world = true
                                    })
                                    if TomTom.SetCrazyArrow and uid then
                                        TomTom:SetCrazyArrow(uid, 60, rare.name)
                                    end
                                elseif addon and addon.SetBlizzardWaypoint then
                                    addon:SetBlizzardWaypoint(mapID, rare.x / 100, rare.y / 100)
                                end
                            end
                        end)
                    else
                        bar.iconButton:SetScript("OnMouseUp", nil)
                    end
                    bar:EnableMouse(false)

                    table.insert(self.sections, bar)
                    bar:Show()
                    yOffset = yOffset - 18
                end
            end
        end
    end
    
    if hasContent then
        table.insert(self.sections, header)
        header:Show()
        return yOffset - 8
    else
        ReleaseContainer(header)
        return startY
    end
end

-- Refresh delves  
function addon:UpdateDelvesSection(parent, yOffset, expStates) 
    local cfg = HomeworkTrackerDB.delves 
    if not cfg.enable then return yOffset end 
     
    local hasContent = false 
    local startY = yOffset 
     
    local delves = self:GetBountifulDelveInfo() 

    if not delves or #delves == 0 then
        return startY
    end

    local header = self:CreateSectionHeader(parent, "Bountiful Delves", yOffset) 
    yOffset = yOffset - 20 

    table.sort(delves, function(a, b)
        local za = (addon.zonePriority and addon.zonePriority[a.zone]) or 9999
        local zb = (addon.zonePriority and addon.zonePriority[b.zone]) or 9999
        if za ~= zb then return za < zb end
        if a.zone ~= b.zone then return a.zone < b.zone end
        return a.name < b.name
    end)
    
    local r, g, b = GetColor("delves", nil, 0.85, 0.65, 0.2)

    for _, d in ipairs(delves) do 
      if not d.expansion or expStates[d.expansion] then
        local delve = d 
        hasContent = true 
         
        local bar = self:CreateContainer(parent, yOffset, true) 
        bar.nameText:SetText(delve.name) 
        bar.timeText:SetText(delve.zone .. " |A:delves-bountiful:14:14|a") 
        bar.icon:Hide() 
         
        addon:SetBarColor(bar, r, g, b, 0.8) 

        local mapID = addon.zoneIDs and addon.zoneIDs[delve.zone]
        if mapID then
            bar.iconButton:Show()
            bar.iconButton:SetSize(16, 16)
            bar.iconButton:ClearAllPoints()
            bar.iconButton:SetPoint("RIGHT", bar.timeText, "RIGHT", 0, 0)

            bar.iconButton:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(delve.name, 1, 1, 1)
                GameTooltip:AddLine(delve.zone, 1, 1, 1)
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("|cff00ff00Click|r to open map", 0.7, 0.7, 0.7, true)
                GameTooltip:AddLine("|cff00ff00Ctrl + Click|r to set waypoint", 0.7, 0.7, 0.7)
                if TomTom and delve.x and delve.y then
                    GameTooltip:AddLine("Arrow only visible in correct zone", 1, 0.5, 0)
                end
                GameTooltip:Show()
            end)
            bar.iconButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

            bar.iconButton:SetScript("OnMouseUp", function(self)
                if IsControlKeyDown() then
                    if TomTom and delve.x and delve.y then
                        local uid = TomTom:AddWaypoint(mapID, delve.x / 100, delve.y / 100, {
                            title = delve.name,
                            persistent = false,
                            minimap = true,
                            world = true
                        })
                        if TomTom.SetCrazyArrow and uid then
                            TomTom:SetCrazyArrow(uid, 60, delve.name)
                        end
                    elseif addon and addon.SetBlizzardWaypoint then
                        addon:SetBlizzardWaypoint(mapID, delve.x / 100, delve.y / 100)
                    end
                else
                    if mapID and WorldMapFrame and WorldMapFrame.SetMapID then
                        ShowUIPanel(WorldMapFrame)
                        WorldMapFrame:SetMapID(mapID)
                    end
                end
            end)
        else
            bar.iconButton:Hide()
        end
        bar:EnableMouse(false)
        
        table.insert(self.sections, bar)
        bar:Show()
        yOffset = yOffset - 18
      end
    end
    
    if hasContent then
        table.insert(self.sections, header)
        header:Show()
        return yOffset - 8
    else
        ReleaseContainer(header)
        return startY
    end
end
