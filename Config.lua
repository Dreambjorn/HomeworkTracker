-- HomeworkTracker - Config
local addonName, addon = ...


-- Libraries
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

-- Constants
local CONFIG_WIDTH = 700
local CONFIG_HEIGHT = 500
local SIDEBAR_WIDTH = 150
local CONFIG_FONT_PATH = "Fonts\\FRIZQT__.TTF"
local DEFAULT_SORT_PRIORITY = 99
local SMALL_GAP = 16
local BIG_GAP = 50

-- UI colors
local COLOR_BG = {0.1, 0.1, 0.1, 0.95}
local COLOR_Sidebar = {0.15, 0.15, 0.15, 1}
local COLOR_Selected = {0.2, 0.4, 0.8, 1}
local COLOR_Hover = {0.2, 0.2, 0.2, 1}
local COLOR_Header = {1, 0.82, 0, 1}

-- Default colors
addon.defaultColors = addon.defaultColors or {}
addon.defaultColors.textLeft   = addon.defaultColors.textLeft   or {1, 1, 1}
addon.defaultColors.textRight  = addon.defaultColors.textRight  or {1, 1, 1}
addon.defaultColors.headerText = addon.defaultColors.headerText or {0.3, 0.69, 0.93}

-- State
local currentTab = "General"
local configFrame
local contentFrame
local sidebar
local tabs
local dropdownLists = {}
local settingsCanvas = CreateFrame("Frame")
local settingsCategory
local floatingSidebar, floatingContentFrame, floatingConfigFrame
local canvasSidebar, canvasContentFrame
local canvasBuilt = false

-- Close the open list on a click outside it
local dropdownCloser = CreateFrame("Frame")
dropdownCloser:SetScript("OnEvent", function(self, event, mouseButton)
    local list = self.list
    if not (list and list:IsShown()) then
        self.list = nil
        self:UnregisterEvent("GLOBAL_MOUSE_DOWN")
        return
    end
    if mouseButton ~= "LeftButton" and mouseButton ~= "RightButton" then return end
    if list:IsMouseOver() or (list.ownerButton and list.ownerButton:IsMouseOver()) then return end
    list:Hide()
end)

-- Hide every tracked list except one
local function CloseDropdowns(except)
    for _, l in ipairs(dropdownLists) do
        if l ~= except and l:IsShown() then l:Hide() end
    end
end

-- Profile popups sit on UIParent, so close them with their host
local function CloseConfigPopups()
    if addon.profileCodePopup then addon.profileCodePopup:Hide() end
    if addon.profileNamePopup then addon.profileNamePopup:Hide() end
end

-- Open one list, close the rest
local function OpenDropdown(list)
    CloseDropdowns(list)
    list:Show()
    dropdownCloser.list = list
    dropdownCloser:RegisterEvent("GLOBAL_MOUSE_DOWN")
end

-- Track dropdown lists
local function TrackDropdown(list, button)
    if not list then return end
    list.ownerButton = button
    table.insert(dropdownLists, list)
    list:HookScript("OnHide", function(self)
        if dropdownCloser.list == self then
            dropdownCloser.list = nil
            dropdownCloser:UnregisterEvent("GLOBAL_MOUSE_DOWN")
        end
    end)
end

-- Setup dropdown frames
local function SetupDropdown(button, list, countFunc, onOpen)
    TrackDropdown(list, button)

    list:SetFrameLevel(100)
    list:SetFrameStrata("DIALOG")

    button:SetScript("OnClick", function()
        if list:IsShown() then
            list:Hide()
            return
        end
        if onOpen then onOpen() end
        if countFunc and countFunc() == 0 then return end
        OpenDropdown(list)
    end)
end

local function SetConfigFont(fs, size)
    fs:SetFont(CONFIG_FONT_PATH, size or 11, "OUTLINE")
end

-- Create base frame
local function CreateBaseFrame(name, parent)
    local f = CreateFrame("Frame", name, parent, "BackdropTemplate")
    f:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    f:SetBackdropColor(unpack(COLOR_BG))
    f:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    return f
end

-- Reuse widgets within their own tab and host
local function TakeWidget(parent, key, kind, template)
    local pools = parent and parent.configPools
    local pool
    if pools then
        pool = pools[key]
        if not pool then
            pool = { used = 0 }
            pools[key] = pool
        end
        pool.used = pool.used + 1
        local widget = pool[pool.used]
        if widget then
            widget:Show()
            return widget, false
        end
    end
    local widget
    if kind == "FontString" then
        widget = parent:CreateFontString(nil, "OVERLAY", template)
    else
        widget = CreateFrame(kind, nil, parent, template)
    end
    if pool then pool[pool.used] = widget end
    return widget, true
end

-- Raw headings and buttons also keep their regions
local function CreateTabFrame(parent, key, kind, template)
    local frame = TakeWidget(parent, key, kind, template)
    frame.configPools = frame.configPools or {}
    return frame
end

local function CreateTabLabel(parent, key, template)
    return TakeWidget(parent, key, "FontString", template)
end

-- Create checkbox
local function CreateCheckbox(parent, label, onClick)
    local frame, isNew = TakeWidget(parent, "checkbox", "Frame")
    local check, text = frame.check, frame.label
    if isNew then
        frame:SetSize(400, 26)
    
        check = CreateFrame("CheckButton", nil, frame)
        check:SetSize(20, 20)
        check:SetPoint("LEFT", 0, 0)
        check:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
        check:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
        check:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
        check:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    
        text = frame:CreateFontString(nil, "OVERLAY")
        text:SetPoint("LEFT", check, "RIGHT", 8, 0)
        SetConfigFont(text, 12)
        text:SetText(label)
        text:SetTextColor(0.9, 0.9, 0.9)
    else
        text:SetText(label)
    end
    frame.configResetHover = true

    check:SetScript("OnClick", function(self)
        if onClick then onClick(self:GetChecked()) end
    end)
    
    frame.check = check
    frame.label = text
    return frame
end

-- Create slider
local function CreateSlider(parent, label, minVal, maxVal, step, onValueChanged)
    local frame, isNew = TakeWidget(parent, "slider", "Frame")
    local slider, text, valueText = frame.slider, frame.label, frame.valueText
    if isNew then
        frame:SetSize(400, 45)
    
        slider = CreateFrame("Slider", nil, frame, "OptionsSliderTemplate")
        slider:SetPoint("LEFT", 0, -10)
        slider:SetWidth(200)
        slider:SetMinMaxValues(minVal, maxVal)
        slider:SetValueStep(step)
        slider:SetObeyStepOnDrag(true)
    
        if slider.Low then slider.Low:SetText("Small") end
        if slider.High then slider.High:SetText("Big") end
    
        text = frame:CreateFontString(nil, "OVERLAY")
        text:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", 0, 5)
        SetConfigFont(text, 12)
        text:SetText(label)
    
        valueText = frame:CreateFontString(nil, "OVERLAY")
        valueText:SetPoint("BOTTOMRIGHT", slider, "TOPRIGHT", 0, 5)
        SetConfigFont(valueText, 12)
    
    else
        slider:SetScript("OnValueChanged", nil)
        slider:SetMinMaxValues(minVal, maxVal)
        slider:SetValueStep(step)
        text:SetText(label)
    end

    slider:SetScript("OnValueChanged", function(self, value)
        local fmt = (step < 1) and "%.1f" or "%d"
        valueText:SetText(string.format(fmt, value))
        if onValueChanged then onValueChanged(value) end
    end)
    
    frame.label = text
    frame.slider = slider
    frame.valueText = valueText
    return frame
end

-- Create header
local function CreateHeader(parent, text)
    local frame, isNew = TakeWidget(parent, "header", "Frame")
    if not isNew then
        frame.label:SetText(text)
        return frame
    end
    frame:SetSize(400, 30)
    
    local label = frame:CreateFontString(nil, "OVERLAY")
    label:SetPoint("LEFT", 0, -5)
    SetConfigFont(label, 14)
    label:SetText(text)
    label:SetTextColor(unpack(COLOR_Header))
    
    local line = frame:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(unpack(COLOR_Header))
    line:SetAlpha(0.5)
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT", label, "BOTTOMLEFT", 0, -2)
    line:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
    frame.label = label
    
    return frame
end


local function CreateResetButton(parent, onClick)
    local btn = TakeWidget(parent, "reset", "Button", "UIPanelButtonTemplate")
    btn:SetSize(160, 26)
    btn:SetText("Reset to Defaults")
    btn:SetScript("OnClick", function() 
        if onClick then onClick() end 
    end)
    return btn
end

-- Place reset button
local function PlaceResetButton(parent, currentY, onClick, gapBeforeReset)
    local btn = CreateResetButton(parent, onClick)
    local gap = (type(gapBeforeReset) == "number") and gapBeforeReset or BIG_GAP
    local placeY = (currentY or 0) - gap
    btn:SetPoint("TOPLEFT", 30, placeY)
    return btn, (placeY - SMALL_GAP)
end

-- Create text input
local function CreateTextInput(parent, width, height, multiline)
    local eb, isNew = TakeWidget(parent, "input", "EditBox", "BackdropTemplate")
    if not isNew then
        eb:ClearFocus()
        eb:SetText("")
        return eb
    end
    eb:SetSize(width or 240, height or 24)
    eb:SetAutoFocus(false)
    eb:SetMultiLine(multiline or false)
    eb:SetFontObject(ChatFontNormal)
    eb:SetTextInsets(6, 6, 4, 4)
    eb:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    eb:SetBackdropColor(0, 0, 0, 0.8)
    eb:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    eb:SetTextColor(1, 1, 1, 1)
    eb:SetJustifyH("LEFT")
    eb:SetJustifyV(multiline and "TOP" or "MIDDLE")
    eb:SetScript("OnEscapePressed", eb.ClearFocus)
    return eb
end

-- Shared dropdown backdrop
local function DropdownBackdrop(edge)
    return {
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = edge,
        insets = {left=2, right=2, top=2, bottom=2}
    }
end

-- Style a placed dropdown button
local function StyleDropdownButton(button, edge, text)
    button:SetBackdrop(DropdownBackdrop(edge))
    button:SetBackdropColor(0, 0, 0, 0.8)

    local btnText = button:CreateFontString(nil, "OVERLAY")
    btnText:SetPoint("LEFT", 8, 0)
    SetConfigFont(btnText, 12)
    if text then btnText:SetText(text) end

    local arrow = button:CreateTexture(nil, "ARTWORK")
    arrow:SetPoint("RIGHT", -6, 0)
    arrow:SetSize(12, 12)
    arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")

    return btnText
end

-- Hidden list box under a dropdown button
local function CreateDropdownList(frame, button, width, height, edge, shade)
    local list = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    list:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -2)
    list:SetSize(width, height)
    list:SetBackdrop(DropdownBackdrop(edge))
    list:SetBackdropColor(shade, shade, shade, 0.98)
    list:Hide()
    return list
end

-- Option dropdown; compact is the header style
local function CreateListDropdown(parent, labelText, width, compact)
    local edge = compact and 8 or 12

    local frame, isNew = TakeWidget(parent, compact and "headerDropdown" or "listDropdown", "Frame")
    if not isNew then
        frame:SetOnChange(nil)
        frame:SetValue(nil)
        if frame.label then frame.label:SetText(labelText or "") end
        return frame
    end
    frame:SetSize(width, compact and 20 or 46)

    local button
    if compact then
        button = CreateFrame("Button", nil, frame, "BackdropTemplate")
        button:SetAllPoints()
    else
        local label = frame:CreateFontString(nil, "OVERLAY")
        label:SetPoint("TOPLEFT", 0, 0)
        SetConfigFont(label, 12)
        label:SetText(labelText or "")
        frame.label = label

        button = CreateFrame("Button", nil, frame, "BackdropTemplate")
        button:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -4)
        button:SetSize(width, 24)
    end

    local btnText = StyleDropdownButton(button, edge, "Select")
    local list = CreateDropdownList(frame, button, width, 10, edge, 0.08)

    local optionButtons = {}
    local options = {}
    local selected
    local onChange

    local function Select(val, fireOnChange)
        selected = val
        btnText:SetText(val or "Select")
        list:Hide()
        if fireOnChange and onChange then
            onChange(val)
        end
    end

    local function SetOptions(newOptions)
        options = newOptions or {}

        for _, b in ipairs(optionButtons) do
            b:Hide()
            if b.bg then b.bg:Hide() end
        end

        local y = -4
        for i, opt in ipairs(options) do
            local b = optionButtons[i]
            if not b then
                b = CreateFrame("Button", nil, list)
                b:SetSize(width - 8, 20)
                b.text = b:CreateFontString(nil, "OVERLAY")
                b.text:SetPoint("LEFT", 5, 0)
                SetConfigFont(b.text, 12)
                b:SetScript("OnEnter", function(self)
                    self.bg = self.bg or self:CreateTexture(nil, "BACKGROUND")
                    self.bg:SetAllPoints()
                    self.bg:SetColorTexture(0.2, 0.2, 0.2, 0.45)
                    self.bg:Show()
                end)
                b:SetScript("OnLeave", function(self)
                    if self.bg then self.bg:Hide() end
                end)
                optionButtons[i] = b
            end

            b:SetPoint("TOPLEFT", 4, y)
            b.text:SetText(opt)
            b:SetScript("OnClick", function() Select(opt, true) end)
            b:Show()
            y = y - SMALL_GAP - 4
        end

        list:SetHeight(math.max(12, math.abs(y) + 4))

        if tContains(options, selected) then
            btnText:SetText(selected)
        else
            Select(options[1], false)
        end
    end

    SetupDropdown(button, list, function() return #options end)

    frame.SetOptions = function(self, opts) SetOptions(opts) end
    frame.SetValue = function(self, val) Select(val, false) end
    frame.GetValue = function(self) return selected end
    frame.SetOnChange = function(self, cb) onChange = cb end
    frame.Close = function(self) list:Hide() end

    return frame
end

-- Create simple dropdown
local function CreateSimpleDropdown(parent, labelText, width)
    return CreateListDropdown(parent, labelText, width or 220, false)
end

-- Create condensed dropdown
local function CreateHeaderDropdown(parent, width)
    return CreateListDropdown(parent, nil, width or 180, true)
end

-- Scroll row hover
local function ScrollRowOnEnter(self)
    self.bg = self.bg or self:CreateTexture(nil, "BACKGROUND")
    self.bg:SetAllPoints()
    self.bg:SetColorTexture(0.2, 0.2, 0.2, 0.5)
    self.bg:Show()
end

local function ScrollRowOnLeave(self)
    if self.bg then self.bg:Hide() end
end

-- Dropdown whose list builds only visible rows
local function CreateScrollDropdown(parent, labelText, initRow, onPick, frame)
    frame = frame or CreateFrame("Frame", nil, parent)
    frame:SetSize(250, 45)

    local label = frame:CreateFontString(nil, "OVERLAY")
    label:SetPoint("TOPLEFT", 0, 0)
    SetConfigFont(label, 12)
    label:SetText(labelText)

    local button = CreateFrame("Button", nil, frame, "BackdropTemplate")
    button:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -5)
    button:SetSize(220, 24)

    local btnText = StyleDropdownButton(button, 12)
    local list = CreateDropdownList(frame, button, 220, 150, 12, 0.1)

    local scrollBox = CreateFrame("Frame", nil, list, "WowScrollBoxList")
    scrollBox:SetPoint("TOPLEFT", 4, -4)
    scrollBox:SetPoint("BOTTOMRIGHT", -18, 4)

    local scrollBar = CreateFrame("EventFrame", nil, list, "MinimalScrollBar")
    scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 4, 0)
    scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 4, 0)

    local view = CreateScrollBoxListLinearView()
    view:SetElementExtent(SMALL_GAP + 4)
    view:SetElementInitializer("Button", function(row, data)
        if not row.text then
            row.text = row:CreateFontString(nil, "OVERLAY")
            row.text:SetPoint("LEFT", 5, 0)
            SetConfigFont(row.text, 12)
            row:SetScript("OnEnter", ScrollRowOnEnter)
            row:SetScript("OnLeave", ScrollRowOnLeave)
            row:SetScript("OnClick", function(self)
                btnText:SetText(self.value)
                list:Hide()
                onPick(self.value)
            end)
        end
        row.value = data.name
        initRow(row, data.name)
    end)
    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)

    return frame, button, list, scrollBox, btnText
end

-- Fill a scroll list
local function SetScrollItems(scrollBox, names)
    local dp = CreateDataProvider()
    for _, n in ipairs(names) do dp:Insert({ name = n }) end
    scrollBox:SetDataProvider(dp)
end

-- Create font dropdown
local function CreateFontDropdown(parent, labelText, onChange)
    local widget, isNew = TakeWidget(parent, "fontDropdown", "Frame")
    widget.onChange = onChange
    if not isNew then return widget end
    -- Row shows its own font
    local function InitFontRow(row, name)
        local path = LSM and LSM:Fetch("font", name) or CONFIG_FONT_PATH
        if not pcall(row.text.SetFont, row.text, path, 12) then
            SetConfigFont(row.text, 12)
        end
        row.text:SetText(name)
        row.text:SetTextColor(1, 1, 1)
    end

    local frame, button, list, scrollBox, btnText = CreateScrollDropdown(parent, labelText, InitFontRow, function(name)
        if widget.onChange then widget.onChange(name) end
    end, widget)

    local count = 0
    SetupDropdown(button, list, function() return count end, function()
        local fonts = {}
        for _, n in ipairs(LSM and LSM:List("font") or {"Friz Quadrata TT", "Arial Narrow", "Skurri"}) do
            fonts[#fonts + 1] = n
        end
        table.sort(fonts)
        count = #fonts
        SetScrollItems(scrollBox, fonts)
    end)

    frame.SetSelection = function(self, val)
        btnText:SetText(val)
    end

    return frame
end

local function CreateMediaDropdown(parent, labelText, dbKey, mediaType, onChange)
    local widget, isNew = TakeWidget(parent, "mediaDropdown:" .. dbKey .. ":" .. mediaType, "Frame")
    widget.onChange = onChange
    if not isNew then
        local sel = HomeworkTrackerDB and HomeworkTrackerDB[dbKey]
        widget:SetSelection(sel and sel ~= "" and sel or "Default")
        return widget
    end
    -- Row previews the bar texture
    local function InitMediaRow(row, name)
        if not row.swatch then
            row.swatch = row:CreateTexture(nil, "ARTWORK")
            row.swatch:SetPoint("TOPLEFT", row, "TOPLEFT", 2, -2)
            row.swatch:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -2, 2)
        end
        row.text:SetText(name)
        row.text:SetTextColor(1, 1, 1)

        local path = (name ~= "Default") and LSM and LSM:Fetch(mediaType, name) or nil
        local pr, pg, pb = unpack((addon.defaultColors and addon.defaultColors.progress)
            or {1, 0.4, 0.4})
        if path then
            row.swatch:SetTexture(path)
            row.swatch:SetVertexColor(pr, pg, pb, 0.9)
        else
            row.swatch:SetTexture(nil)
            row.swatch:SetVertexColor(1, 1, 1, 1)
            row.swatch:SetColorTexture(pr, pg, pb, 0.9)
        end
        row.swatch:Show()
    end

    local frame, button, list, scrollBox, btnText = CreateScrollDropdown(parent, labelText, InitMediaRow, function(name)
        if name == "Default" then
            HomeworkTrackerDB[dbKey] = nil
        else
            HomeworkTrackerDB[dbKey] = name
        end
        if widget.onChange then widget.onChange(name) end
    end, widget)

    local count = 0
    SetupDropdown(button, list, function() return count end, function()
        local values = {"Default"}
        if LSM then
            for _, n in ipairs(LSM:List(mediaType)) do
                values[#values + 1] = n
            end
        end
        table.sort(values, function(a, b)
            if a == "Default" then return true end
            if b == "Default" then return false end
            return a < b
        end)
        count = #values
        SetScrollItems(scrollBox, values)
    end)

    frame.SetSelection = function(self, val) btnText:SetText(val) end
    local sel = HomeworkTrackerDB and HomeworkTrackerDB[dbKey]
    btnText:SetText(sel and sel ~= "" and sel or "Default")

    return frame
end

-- Get selected expansion
local function GetSelectedExpansion()
    if HomeworkTrackerDB and HomeworkTrackerDB.ui and HomeworkTrackerDB.ui.selectedExpansion then
        local sel = HomeworkTrackerDB.ui.selectedExpansion
        if HomeworkTrackerDB.expansions and HomeworkTrackerDB.expansions[sel] then
            return sel
        end
    end
    if HomeworkTrackerDB and HomeworkTrackerDB.expansions then
        for k, v in pairs(HomeworkTrackerDB.expansions) do
            if v then return k end
        end
    end
    return nil
end

-- Release tab widgets without discarding their frames
local function ClearContainer(container)
    for _, pool in pairs(container.configPools or {}) do
        for _, widget in ipairs(pool) do
            widget:Hide()
            widget:ClearAllPoints()
            if widget.configResetHover then
                widget:SetScript("OnEnter", nil)
                widget:SetScript("OnLeave", nil)
            end
            if widget.configPools then ClearContainer(widget) end
        end
        pool.used = 0
    end
end

-- One reusable container per tab, per config host
local function GetTabContainer(tabName)
    local sc = contentFrame and contentFrame.scrollChild
    if not sc then return nil end

    sc.tabContainers = sc.tabContainers or {}

    local c = sc.tabContainers[tabName]
    if not c then
        c = CreateFrame("Frame", nil, sc)
        c:SetPoint("TOPLEFT", 0, 0)
        c:SetPoint("TOPRIGHT", 0, 0)
        c:SetHeight(1)
        c.configPools = {}
        sc.tabContainers[tabName] = c
    end
    return c
end

-- Refresh tab; reuse skips a built tab
local function RefreshContent(reuse)
    if not tabs then return end

    local container = GetTabContainer(currentTab)
    if not container then return end

    local sc = contentFrame.scrollChild
    for name, c in pairs(sc.tabContainers) do
        if name ~= currentTab then c:Hide() end
    end

    if not reuse then
        CloseDropdowns()
        for _, host in pairs({floatingContentFrame, canvasContentFrame}) do
            for _, c in pairs(host.scrollChild.tabContainers or {}) do c.built = nil end
        end
    end

    container:Show()

    if not container.built then
        ClearContainer(container)
        for _, tab in ipairs(tabs) do
            if tab.name == currentTab then
                tab.builder(container)
                break
            end
        end
        container.built = true
    end

    contentFrame:UpdateScrollChildRect()
end

-- Build profiles tab
local function BuildTab_Profiles(parent)
    local y = -10

    local function EnsureCodePopup()
        if addon.profileCodePopup then return addon.profileCodePopup end

        local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        f:SetSize(520, 320)
        f:SetPoint("CENTER")
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        f:SetFrameLevel(100)
        f:SetMovable(false)
        f:EnableMouse(true)
        f:SetClampedToScreen(true)
        f:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        f:SetBackdropColor(unpack(COLOR_BG))
        f:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
        f:Hide()

        f.textArea = CreateFrame("Frame", nil, f, "BackdropTemplate")
        f.textArea:SetPoint("TOPLEFT", 12, -12)
        f.textArea:SetPoint("BOTTOMRIGHT", -12, 44)
        f.textArea:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        f.textArea:SetBackdropColor(0, 0, 0, 0.9)
        f.textArea:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
        f.textArea:SetScript("OnMouseDown", function()
            if f.edit then f.edit:SetFocus() end
        end)

        f.scroll = CreateFrame("ScrollFrame", nil, f.textArea, "ScrollFrameTemplate")
        f.scroll:SetPoint("TOPLEFT", 4, -4)
        f.scroll:SetPoint("BOTTOMRIGHT", -28, 4)
        f.scroll.ScrollBar:ClearAllPoints()
        f.scroll.ScrollBar:SetPoint("TOPLEFT", f.scroll, "TOPRIGHT", 10, 0)
        f.scroll.ScrollBar:SetPoint("BOTTOMLEFT", f.scroll, "BOTTOMRIGHT", 10, 0)
        f.scroll:SetScript("OnMouseDown", function()
            if f.edit then f.edit:SetFocus() end
        end)

        f.edit = CreateFrame("EditBox", nil, f.scroll)
        f.edit:SetMultiLine(true)
        f.edit:SetAutoFocus(false)
        f.edit:EnableMouse(true)
        f.edit:SetFontObject(ChatFontNormal)
        f.edit:SetTextColor(1, 1, 1, 1)
        f.edit:SetWidth(462)
        f.edit:SetHeight(2000)
        f.edit:SetTextInsets(4, 4, 4, 4)
        f.edit:SetScript("OnMouseDown", function(self)
            self:SetFocus()
        end)
        f.edit:SetScript("OnMouseUp", function(self)
            self:SetFocus()
        end)
        f.edit:SetScript("OnEscapePressed", function() f:Hide() end)
        f.edit:SetScript("OnKeyDown", function(self, key)
            if f.isExport and IsControlKeyDown() and (key == "C" or key == "c") then
                if f.messageText then
                    f.messageText:SetTextColor(0.4, 1, 0.4)
                    f.messageText:SetText("Copied successfully")
                end
            end
        end)
        f.edit:SetScript("OnTextChanged", function(self)
            f.scroll:UpdateScrollChildRect()
        end)
        f.scroll:SetScrollChild(f.edit)
        f.edit:SetText("")

        f.ok = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        f.ok:SetSize(110, 24)
        f.ok:SetPoint("BOTTOMRIGHT", -12, 12)
        f.ok:SetText("OK")

        f.messageText = f:CreateFontString(nil, "OVERLAY")
        f.messageText:SetPoint("BOTTOMLEFT", 14, 19)
        SetConfigFont(f.messageText, 11)
        f.messageText:SetText("")

        f.cancel = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        f.cancel:SetSize(110, 24)
        f.cancel:SetPoint("RIGHT", f.ok, "LEFT", -8, 0)
        f.cancel:SetText("Cancel")
        f.cancel:SetScript("OnClick", function() f:Hide() end)

        addon.profileCodePopup = f
        return f
    end


    local function FormatCodeForDisplay(code)
        if type(code) ~= "string" then return "" end
        local compact = string.gsub(code, "%s+", "")
        if compact == "" then return "" end
        return string.gsub(compact, "(%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S%S)", "%1\n")
    end


    local function EnsureNamePopup()
        if addon.profileNamePopup then return addon.profileNamePopup end

        local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        f:SetSize(360, 170)
        f:SetPoint("CENTER")
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        f:SetFrameLevel(110)
        f:SetMovable(false)
        f:EnableMouse(true)
        f:SetClampedToScreen(true)
        f:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        f:SetBackdropColor(unpack(COLOR_BG))
        f:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
        f:Hide()

        f.title = f:CreateFontString(nil, "OVERLAY")
        f.title:SetPoint("TOPLEFT", 12, -10)
        SetConfigFont(f.title, 14)
        f.title:SetTextColor(unpack(COLOR_Header))
        f.title:SetText("Choose New Profile Name")

        f.input = CreateTextInput(f, 330, 24, false)
        f.input:SetPoint("TOPLEFT", 12, -46)
        f.input:SetScript("OnEscapePressed", function() f:Hide() end)

        f.messageText = f:CreateFontString(nil, "OVERLAY")
        f.messageText:SetPoint("TOPLEFT", 14, -82)
        SetConfigFont(f.messageText, 11)
        f.messageText:SetTextColor(1, 0.4, 0.4)
        f.messageText:SetText("")

        f.ok = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        f.ok:SetSize(110, 24)
        f.ok:SetPoint("BOTTOMRIGHT", -12, 12)
        f.ok:SetText("OK")

        f.cancel = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        f.cancel:SetSize(110, 24)
        f.cancel:SetPoint("RIGHT", f.ok, "LEFT", -8, 0)
        f.cancel:SetText("Cancel")
        f.cancel:SetScript("OnClick", function() f:Hide() end)

        addon.profileNamePopup = f
        return f
    end


    local function OpenCodePopup(text, showCancel, onAccept)
        local popup = EnsureCodePopup()
        popup.isExport = not showCancel
        popup.edit:EnableMouse(true)
        popup.edit:EnableKeyboard(true)
        popup.edit:SetEnabled(true)
        popup.edit:SetText(text or "")
        popup.edit:HighlightText(0, 0)
        if popup.messageText then popup.messageText:SetText("") end
        if popup.scroll and popup.scroll.SetVerticalScroll then
            popup.scroll:SetVerticalScroll(0)
        end

        popup.cancel:SetShown(showCancel and true or false)
        popup.ok:SetScript("OnClick", function()
            local shouldClose = true
            if onAccept then
                shouldClose = onAccept(popup.edit:GetText(), popup)
            end
            if shouldClose ~= false then
                popup:Hide()
            end
        end)

        popup:Show()
        popup.edit:SetFocus()
    end

    local function OpenNamePopup(onAccept)
        local popup = EnsureNamePopup()
        popup.input:SetText("")
        popup.messageText:SetText("")
        popup.ok:SetScript("OnClick", function()
            local shouldClose = true
            if onAccept then
                shouldClose = onAccept(popup.input:GetText())
            end
            if shouldClose ~= false then
                popup:Hide()
            end
        end)
        popup:Show()
        popup.input:SetFocus()
    end


    local function BuildOptions(includeActive, includeDefault)
        local out = {}
        local active = addon:GetActiveProfileName()
        for _, name in ipairs(addon:GetProfileNames()) do
            if (includeActive or name ~= active) and (includeDefault or name ~= "Default") then
                table.insert(out, name)
            end
        end
        return out
    end

    local hMain = CreateHeader(parent, "Profile Management")
    hMain:SetPoint("TOPLEFT", 10, y)
    y = y - BIG_GAP + 15

    local activeLabel = CreateTabLabel(parent, "activeLabel")
    activeLabel:SetPoint("TOPLEFT", 30, y)
    SetConfigFont(activeLabel, 12)
    activeLabel:SetText("Active Profile: " .. addon:GetActiveProfileName())
    activeLabel:SetTextColor(1, 1, 1)
    y = y - SMALL_GAP - 14

    local switchDD = CreateSimpleDropdown(parent, "Select Profile", 220)
    switchDD:SetPoint("TOPLEFT", 30, y)
    switchDD:SetOptions(BuildOptions(true, true))
    switchDD:SetValue(addon:GetActiveProfileName())
    switchDD:SetOnChange(function(selected)
        local ok = addon:SwitchProfile(selected)
        if ok then
            RefreshContent()
            addon:UpdateDisplay()
        end
    end)

    y = y - BIG_GAP - 8

    local createInput = CreateTextInput(parent, 220, 24, false)
    createInput:SetPoint("TOPLEFT", 30, y)

    local createBtn = CreateTabFrame(parent, "createBtn", "Button", "UIPanelButtonTemplate")
    createBtn:SetSize(110, 24)
    createBtn:SetPoint("LEFT", createInput, "RIGHT", 10, 0)
    createBtn:SetText("Create")
    createBtn:SetScript("OnClick", function()
        local name = createInput:GetText() or ""
        local ok = addon:CreateProfile(name)
        if ok then
            RefreshContent()
        end
    end)

    y = y - BIG_GAP + 16

    local copyDD = CreateSimpleDropdown(parent, "Copy From (into active)", 220)
    copyDD:SetPoint("TOPLEFT", 30, y)
    copyDD:SetOptions(BuildOptions(false, true))

    local copyBtn = CreateTabFrame(parent, "copyBtn", "Button", "UIPanelButtonTemplate")
    copyBtn:SetSize(110, 24)
    copyBtn:SetPoint("LEFT", copyDD, "RIGHT", 10, -10)
    copyBtn:SetText("Copy")
    copyBtn:SetScript("OnClick", function()
        local from = copyDD:GetValue()
        local active = addon:GetActiveProfileName()
        if not from or from == "" then
            return
        end
        local ok = addon:CopyProfile(from, active)
        if ok then
            addon:UpdateDisplay()
            RefreshContent()
        end
    end)

    y = y - BIG_GAP - 8

    local deleteDD = CreateSimpleDropdown(parent, "Delete Profile", 220)
    deleteDD:SetPoint("TOPLEFT", 30, y)
    deleteDD:SetOptions(BuildOptions(false, false))

    local deleteBtn = CreateTabFrame(parent, "deleteBtn", "Button", "UIPanelButtonTemplate")
    deleteBtn:SetSize(110, 24)
    deleteBtn:SetPoint("LEFT", deleteDD, "RIGHT", 10, -10)
    deleteBtn:SetText("Delete")
    deleteBtn:SetScript("OnClick", function()
        local target = deleteDD:GetValue()
        if not target or target == "" then
            return
        end
        local ok = addon:DeleteProfile(target)
        if ok then
            RefreshContent()
        end
    end)

    y = y - BIG_GAP - 14

    local hTransfer = CreateHeader(parent, "Import / Export")
    hTransfer:SetPoint("TOPLEFT", 10, y)
    y = y - BIG_GAP + 15

    local importBtn = CreateTabFrame(parent, "importBtn", "Button", "UIPanelButtonTemplate")
    importBtn:SetSize(140, 24)
    importBtn:SetPoint("TOPLEFT", 30, y)
    importBtn:SetText("Import")
    importBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Import")
        GameTooltip:AddLine("Paste an import code, then choose a profile name.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    importBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    importBtn:SetScript("OnClick", function()
        OpenCodePopup("", true, function(payload, popup)
            if not payload or payload == "" then
                if popup and popup.messageText then
                    popup.messageText:SetTextColor(1, 0.4, 0.4)
                    popup.messageText:SetText("Paste a profile code first")
                end
                return false
            end

            local valid, formatErr = addon:ValidateImportCode(payload)
            if not valid then
                local msg = formatErr or "Incorrect code format"
                if popup and popup.messageText then
                    popup.messageText:SetTextColor(1, 0.4, 0.4)
                    popup.messageText:SetText(msg)
                end
                return false
            end

            if popup and popup.messageText then popup.messageText:SetText("") end

            OpenNamePopup(function(profileName)
                local ok, err = addon:ImportProfile(profileName or "", payload)
                if ok then
                    RefreshContent()
                else
                    if addon.profileNamePopup and addon.profileNamePopup.messageText then
                        addon.profileNamePopup.messageText:SetText(err or "Import failed")
                    end
                    return false
                end
            end)

            return true
        end)
    end)

    local exportBtn = CreateTabFrame(parent, "exportBtn", "Button", "UIPanelButtonTemplate")
    exportBtn:SetSize(140, 24)
    exportBtn:SetPoint("LEFT", importBtn, "RIGHT", 10, 0)
    exportBtn:SetText("Export")
    exportBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Export")
        GameTooltip:AddLine("Shows the active profile export code.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    exportBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    exportBtn:SetScript("OnClick", function()
        local payload, err = addon:ExportProfile(addon:GetActiveProfileName())
        if not payload then
            print("|cff4db2ffHomeworkTracker:|r " .. (err or "Profile export failed"))
            return
        end
        OpenCodePopup(FormatCodeForDisplay(payload), false, function()
            return true
        end)
    end)

end

-- Build general tab
local function BuildTab_General(parent)
    local y = -10
    
    local hMain = CreateHeader(parent, "Main Settings")
    hMain:SetPoint("TOPLEFT", 10, y)
    y = y - BIG_GAP + 10

    local cb1 = CreateCheckbox(parent, "Show Homework Tracker", function(val)
        HomeworkTrackerDB.enabled = val
        addon:UpdateDisplay()
    end)
    cb1:SetPoint("TOPLEFT", 30, y)
    cb1.check:SetChecked(HomeworkTrackerDB.enabled)
    addon._enabledCheckbox = cb1
    y = y - SMALL_GAP - 14

    local cbMinimap = CreateCheckbox(parent, "Show minimap button", function(val)
        if addon.SetMinimapButtonEnabled then
            addon:SetMinimapButtonEnabled(val)
        else
            HomeworkTrackerDB = HomeworkTrackerDB or {}
            HomeworkTrackerDB.showMinimapButton = val
            if addon.UpdateMinimapButtonVisibility then addon:UpdateMinimapButtonVisibility() end
        end
    end)
    cbMinimap:SetPoint("TOPLEFT", 30, y)
    if addon.IsMinimapButtonEnabled then
        cbMinimap.check:SetChecked(addon:IsMinimapButtonEnabled())
    else
        cbMinimap.check:SetChecked(HomeworkTrackerDB.showMinimapButton ~= false)
    end
    y = y - BIG_GAP + 10


    local fVis = CreateTabFrame(parent, "fVis", "Frame")
    fVis:SetSize(200, 20)
    fVis:SetPoint("TOPLEFT", 15, y)

    local hVis = CreateTabLabel(fVis, "hVis")
    hVis:SetPoint("LEFT", 0, 0)
    SetConfigFont(hVis, 12)
    hVis:SetText("Visibility")
    hVis:SetTextColor(0.8, 0.8, 0.5)
    y = y - SMALL_GAP - 9

    local cbHideParty = CreateCheckbox(parent, "Hide while in a party", function(val)
        HomeworkTrackerDB.hideInParty = val
        if addon.CheckVisibilityState then addon:CheckVisibilityState() end
    end)
    cbHideParty:SetPoint("TOPLEFT", 30, y)
    cbHideParty.check:SetChecked(HomeworkTrackerDB.hideInParty)
    y = y - SMALL_GAP - 14

    local cbHideRaid = CreateCheckbox(parent, "Hide while in a raid", function(val)
        HomeworkTrackerDB.hideInRaid = val
        if addon.CheckVisibilityState then addon:CheckVisibilityState() end
    end)
    cbHideRaid:SetPoint("TOPLEFT", 30, y)
    cbHideRaid.check:SetChecked(HomeworkTrackerDB.hideInRaid)
    y = y - SMALL_GAP - 14

    local cbHideCombat = CreateCheckbox(parent, "Hide while in combat", function(val)
        HomeworkTrackerDB.hideInCombat = val
        if addon.CheckVisibilityState then addon:CheckVisibilityState() end
    end)
    cbHideCombat:SetPoint("TOPLEFT", 30, y)
    cbHideCombat.check:SetChecked(HomeworkTrackerDB.hideInCombat)
    y = y - SMALL_GAP - 14
    
    local cbHideOutsideMajor = CreateCheckbox(parent, "Hide outside major cities", function(val)
        HomeworkTrackerDB.hideOutsideMajorCities = val
        if addon.CheckVisibilityState then addon:CheckVisibilityState() end
    end)
    cbHideOutsideMajor:SetPoint("TOPLEFT", 30, y)
    cbHideOutsideMajor.check:SetChecked(HomeworkTrackerDB.hideOutsideMajorCities)
    y = y - BIG_GAP + 10
    
    local hExp = CreateHeader(parent, "Expansions")
    hExp:SetPoint("TOPLEFT", 10, y)
    y = y - BIG_GAP + 10
    

    if not HomeworkTrackerDB.expansions then
        HomeworkTrackerDB.expansions = {}
        if addon.defaults and addon.defaults.expansions then
            for k, v in pairs(addon.defaults.expansions) do HomeworkTrackerDB.expansions[k] = v end
        else
            HomeworkTrackerDB.expansions.theWarWithin = true
        end
    end


    local expKeys = {}
    for k in pairs(HomeworkTrackerDB.expansions) do table.insert(expKeys, k) end
    table.sort(expKeys)

    for _, expKey in ipairs(expKeys) do
        local label = expKey:gsub("([a-z])([A-Z])","%1 %2"):gsub("_"," ")
        label = label:gsub("^%l", string.upper)

        local cb = CreateCheckbox(parent, label, (function(key)
            return function(val)
                HomeworkTrackerDB.expansions[key] = val


                if val then
                    HomeworkTrackerDB.ui = HomeworkTrackerDB.ui or {}
                    HomeworkTrackerDB.ui.selectedExpansion = key
                end


                if configFrame and configFrame.expansionDropdown then
                    local opts = {}
                    local map = {}
                    for kk, vv in pairs(HomeworkTrackerDB.expansions or {}) do
                        if vv then
                            local lab = kk:gsub("([a-z])([A-Z])","%1 %2"):gsub("_"," ")
                            lab = lab:gsub("^%l", string.upper)
                            table.insert(opts, lab)
                            map[lab] = kk
                        end
                    end
                    table.sort(opts)
                    if #opts == 0 then
                        configFrame.expansionDropdown:SetOptions({"(no expansions enabled)"})
                        configFrame.expansionDropdown:SetValue("(no expansions enabled)")
                    else
                        configFrame.expansionDropdown:SetOptions(opts)


                        HomeworkTrackerDB.ui = HomeworkTrackerDB.ui or {}
                        if not (HomeworkTrackerDB.ui.selectedExpansion and HomeworkTrackerDB.expansions[HomeworkTrackerDB.ui.selectedExpansion]) then
                            HomeworkTrackerDB.ui.selectedExpansion = map[opts[1]]
                        end

                        local selLabel
                        for lbl, k in pairs(map) do if k == HomeworkTrackerDB.ui.selectedExpansion then selLabel = lbl; break end end
                        configFrame.expansionDropdown:SetValue(selLabel or opts[1])
                    end
                end

                addon:UpdateDisplay()
                RefreshContent()
            end
        end)(expKey))

        cb:SetPoint("TOPLEFT", 30, y)
        cb.check:SetChecked(HomeworkTrackerDB.expansions[expKey])
        y = y - SMALL_GAP - 14
    end

    y = y - SMALL_GAP + 6

    local h1 = CreateHeader(parent, "Modules")
    h1:SetPoint("TOPLEFT", 10, y)
    y = y - BIG_GAP + 10
    
    local modules = {
        { label = "Activities", db = HomeworkTrackerDB.activities, key = "activityEnable" },
        { label = "Bountiful Delves", db = HomeworkTrackerDB.delves, key = "enable" },
        { label = "Great Vault", db = HomeworkTrackerDB.greatVault, key = "enable" },
        { label = "Weekly Quests", db = HomeworkTrackerDB.weekly, key = "enable" },
        { label = "Crests", db = HomeworkTrackerDB.crests, key = "enable" },
        { label = "Currencies", db = HomeworkTrackerDB.currency, key = "enable" },
        { label = "Season Progress", db = HomeworkTrackerDB.progress, key = "enable" },
        { label = "Reputations", db = HomeworkTrackerDB.reputations, key = "enable" },
        { label = "Rares", db = HomeworkTrackerDB.rares, key = "enable" }
    }
    
    for _, mod in ipairs(modules) do
        local cb = CreateCheckbox(parent, mod.label, function(val)
            mod.db[mod.key] = val
            addon:UpdateDisplay()
        end)
        cb:SetPoint("TOPLEFT", 30, y)
        cb.check:SetChecked(mod.db[mod.key])
        y = y - SMALL_GAP - 14
    end

    PlaceResetButton(parent, y, function()
        HomeworkTrackerDB.enabled = addon.defaults.enabled
        HomeworkTrackerDB.expansions = {}
        for k, v in pairs(addon.defaults.expansions) do HomeworkTrackerDB.expansions[k] = v end
        HomeworkTrackerDB.ui = HomeworkTrackerDB.ui or {}
        HomeworkTrackerDB.ui.selectedExpansion = (addon.defaults.ui and addon.defaults.ui.selectedExpansion) or GetSelectedExpansion()
        HomeworkTrackerDB.activities.activityEnable = addon.defaults.activities.activityEnable
        HomeworkTrackerDB.delves.enable = addon.defaults.delves.enable
        HomeworkTrackerDB.greatVault.enable = addon.defaults.greatVault.enable
        HomeworkTrackerDB.weekly.enable = addon.defaults.weekly.enable
        HomeworkTrackerDB.crests.enable = addon.defaults.crests.enable
        HomeworkTrackerDB.currency.enable = addon.defaults.currency.enable
        HomeworkTrackerDB.reputations.enable = addon.defaults.reputations.enable
        HomeworkTrackerDB.progress.enable = addon.defaults.progress.enable
        HomeworkTrackerDB.rares.enable = addon.defaults.rares.enable
        RefreshContent()
        addon:UpdateDisplay()


        if configFrame and configFrame.expansionDropdown then
            local opts = {}
            local map = {}
            for k, v in pairs(HomeworkTrackerDB.expansions or {}) do
                if v then
                    local label = k:gsub("([a-z])([A-Z])","%1 %2"):gsub("_"," ")
                    label = label:gsub("^%l", string.upper)
                    table.insert(opts, label)
                    map[label] = k
                end
            end
            table.sort(opts)
            if #opts == 0 then
                configFrame.expansionDropdown:SetOptions({"(no expansions enabled)"})
                configFrame.expansionDropdown:SetValue("(no expansions enabled)")
            else
                configFrame.expansionDropdown:SetOptions(opts)
                local selLabel
                if HomeworkTrackerDB.ui and HomeworkTrackerDB.ui.selectedExpansion then
                    for lbl, k in pairs(map) do if k == HomeworkTrackerDB.ui.selectedExpansion then selLabel = lbl; break end end
                end
                configFrame.expansionDropdown:SetValue(selLabel or opts[1])
            end
        end
    end, SMALL_GAP + 8)
end

-- Create color picker
local function CreateColorPicker(parent, label, dbTable, dbKey, defaultR, defaultG, defaultB)
    local frame, isNew = TakeWidget(parent, "colorPicker", "Frame")
    local text, swatch = frame.label, frame.swatch
    if isNew then
        frame:SetSize(250, 26)
    
        text = frame:CreateFontString(nil, "OVERLAY")
        text:SetPoint("LEFT", 30, 0)
        SetConfigFont(text, 12)
        text:SetText(label)
    
        swatch = CreateFrame("Button", nil, frame, "BackdropTemplate")
        swatch:SetSize(20, 20)
        swatch:SetPoint("LEFT", 0, 0)
        swatch:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 8,
            insets = {left=1, right=1, top=1, bottom=1}
        })
    

    else
        text:SetText(label)
    end
    frame.label, frame.swatch = text, swatch
    frame.configResetHover = true

    local function UpdateSwatch()
        local r, g, b
        if dbTable[dbKey] then
            r, g, b = unpack(dbTable[dbKey])
        else
            r, g, b = defaultR, defaultG, defaultB
        end
        swatch:SetBackdropColor(r, g, b, 1)
    end
    
    UpdateSwatch()
    
    swatch:SetScript("OnClick", function()
        local r, g, b
        if dbTable[dbKey] then
            r, g, b = unpack(dbTable[dbKey])
        else
            r, g, b = defaultR, defaultG, defaultB
        end
        
        local info = {
            r = r, g = g, b = b,
            hasOpacity = false,
            swatchFunc = function()
                local cr, cg, cb = ColorPickerFrame:GetColorRGB()
                dbTable[dbKey] = {cr, cg, cb}
                UpdateSwatch()
                if dbKey == "headerText" then addon:RefreshTitleBar() end
                addon:UpdateDisplay()
            end,
            cancelFunc = function()
                if dbTable[dbKey] then
                    dbTable[dbKey] = {r, g, b}
                else
                    dbTable[dbKey] = nil
                end
                UpdateSwatch()
                if dbKey == "headerText" then addon:RefreshTitleBar() end
                addon:UpdateDisplay()
            end,
        }
        
        if ColorPickerFrame.SetupColorPickerAndShow then
            ColorPickerFrame:SetupColorPickerAndShow(info)
        else
            ColorPickerFrame:SetColorRGB(r, g, b)
            ColorPickerFrame.hasOpacity = false
            ColorPickerFrame.func = info.swatchFunc
            ColorPickerFrame.cancelFunc = info.cancelFunc
            ColorPickerFrame:Show()
        end
    end)    
    return frame
end

-- Build appearance tab
local function BuildTab_Appearance(parent)
    local y = -10
    
    local h0 = CreateHeader(parent, "Tracker")
    h0:SetPoint("TOPLEFT", 10, y)
    y = y - BIG_GAP + 10

    local cbLock = CreateCheckbox(parent, "Lock Tracker Frame", function(val)
        HomeworkTrackerDB.locked = val
        if addon.mainFrame and addon.mainFrame.titleBar then
            addon.mainFrame.titleBar:RegisterForDrag("LeftButton")
        end
    end)
    cbLock:SetPoint("TOPLEFT", 30, y)
    cbLock.check:SetChecked(HomeworkTrackerDB.locked)
    y = y - SMALL_GAP - 14

    local slScale = CreateSlider(parent, "Scale", 0.5, 2.0, 0.1, function(val)
        HomeworkTrackerDB.scale = val
        if addon.mainFrame then addon.mainFrame:SetScale(val) end
    end)
    slScale:SetPoint("TOPLEFT", 30, y)
    slScale.slider:SetValue(HomeworkTrackerDB.scale)
    y = y - BIG_GAP - 10

    local slWidth = CreateSlider(parent, "Width", 200, 800, 10, function(val)
        HomeworkTrackerDB.width = val
        if addon.UpdateLayout then addon:UpdateLayout() end
        addon:UpdateDisplay()
    end)
    slWidth:SetPoint("TOPLEFT", 30, y)
    slWidth.slider:SetValue(addon.GetFrameWidth and addon:GetFrameWidth() or HomeworkTrackerDB.width or 280)
    y = y - BIG_GAP

    local slHeight = CreateSlider(parent, "Height", 120, 1000, 10, function(val)
        HomeworkTrackerDB.height = val
        if addon.UpdateLayout then addon:UpdateLayout() end
        addon:UpdateDisplay()
    end)
    slHeight:SetPoint("TOPLEFT", 30, y)
    slHeight.slider:SetValue(addon.GetFrameHeight and addon:GetFrameHeight() or HomeworkTrackerDB.height or 400)
    y = y - BIG_GAP - 10

    local hBars = CreateHeader(parent, "Progress Bars")
    hBars:SetPoint("TOPLEFT", 10, y)
    y = y - BIG_GAP + 10

    if LSM then
        local texDropdown = CreateMediaDropdown(parent, "Texture", "barTexture", "statusbar", function()
            if addon.UpdateDisplay then addon:UpdateDisplay() end
        end)
        texDropdown:SetPoint("TOPLEFT", 30, y)
        y = y - BIG_GAP - 5
    end

    local hFonts = CreateHeader(parent, "Bar Text")
    hFonts:SetPoint("TOPLEFT", 10, y)
    y = y - BIG_GAP + 10


    local fd = CreateFontDropdown(parent, "Font", function(val)
        addon:SetFontKey(val)
        addon:UpdateDisplay()
    end)
    fd:SetPoint("TOPLEFT", 30, y)
    fd:SetSelection(HomeworkTrackerDB.font or "Friz Quadrata TT")
    y = y - BIG_GAP

    local outlineDD = CreateSimpleDropdown(parent, "Outline", 180)
    outlineDD:SetPoint("TOPLEFT", 30, y)
    outlineDD:SetOptions({"NONE","OUTLINE","THICKOUTLINE","MONOCHROME"})
    outlineDD:SetValue(HomeworkTrackerDB.fontOutline or "OUTLINE")
    outlineDD:SetOnChange(function(val)
        HomeworkTrackerDB.fontOutline = val
        addon:UpdateDisplay()
    end)
    y = y - BIG_GAP

    local slFontSize = CreateSlider(parent, "Font Size", 8, 24, 1, function(val)
        HomeworkTrackerDB.fontSize = val
        addon:UpdateDisplay()
    end)
    slFontSize:SetPoint("TOPLEFT", 30, y)
    slFontSize.slider:SetValue(HomeworkTrackerDB.fontSize or 11)
    y = y - BIG_GAP - 10

    local h2 = CreateHeader(parent, "Header Text")
    h2:SetPoint("TOPLEFT", 10, y)
    y = y - BIG_GAP + 10


    local fdHeader = CreateFontDropdown(parent, "Font", function(val)
        HomeworkTrackerDB.headerFont = val
        addon:RefreshTitleBar()
        addon:UpdateDisplay()
    end)
    fdHeader:SetPoint("TOPLEFT", 30, y)
    fdHeader:SetSelection(addon:GetHeaderFontKey())
    y = y - BIG_GAP

    local outlineHeader = CreateSimpleDropdown(parent, "Outline", 180)
    outlineHeader:SetPoint("TOPLEFT", 30, y)
    outlineHeader:SetOptions({"NONE","OUTLINE","THICKOUTLINE","MONOCHROME"})
    outlineHeader:SetValue(HomeworkTrackerDB.headerFontOutline or "OUTLINE")
    outlineHeader:SetOnChange(function(val)
        HomeworkTrackerDB.headerFontOutline = val
        addon:RefreshTitleBar()
        addon:UpdateDisplay()
    end)
    y = y - BIG_GAP

    local slHeader = CreateSlider(parent, "Font Size", 10, 30, 1, function(val)
        HomeworkTrackerDB.headerFontSize = val
        addon:RefreshTitleBar()
        addon:UpdateDisplay()
    end)
    slHeader:SetPoint("TOPLEFT", 30, y)
    slHeader.slider:SetValue(HomeworkTrackerDB.headerFontSize or 14)
    y = y - BIG_GAP - 10

    -- Tracker header options
    local hTitleBar = CreateHeader(parent, "Tracker Header")
    hTitleBar:SetPoint("TOPLEFT", 10, y)
    y = y - BIG_GAP + 10

    local cbHideTitle = CreateCheckbox(parent, "Hide Tracker Title", function(val)
        HomeworkTrackerDB.hideTitleText = val
        addon:RefreshTitleBar()
    end)
    cbHideTitle:SetPoint("TOPLEFT", 30, y)
    cbHideTitle.check:SetChecked(HomeworkTrackerDB.hideTitleText or false)
    y = y - SMALL_GAP - 14

    local hColors = CreateHeader(parent, "Colors")
    hColors:SetPoint("TOPLEFT", 10, y)
    y = y - BIG_GAP + 10
    
    HomeworkTrackerDB.colors = HomeworkTrackerDB.colors or {}
    local colors = HomeworkTrackerDB.colors

    local fText = CreateTabFrame(parent, "fText", "Frame")
    fText:SetSize(200, 20)
    fText:SetPoint("TOPLEFT", 15, y)
    local hText = CreateTabLabel(fText, "hText")
    hText:SetPoint("LEFT", 0, 0)
    SetConfigFont(hText, 12)
    hText:SetText("Text")
    hText:SetTextColor(0.8, 0.8, 0.5)
    y = y - SMALL_GAP - 9

    colors.textLeft = colors.textLeft or {1,1,1}
    colors.textRight = colors.textRight or {1,1,1}
    colors.headerText = colors.headerText or {0.3,0.69,0.93}

    local cpLeft = CreateColorPicker(parent, "Left Text Color", colors, "textLeft",
        colors.textLeft[1], colors.textLeft[2], colors.textLeft[3])
    cpLeft:SetPoint("TOPLEFT", 30, y)
    y = y - SMALL_GAP - 14

    local cpRight = CreateColorPicker(parent, "Right Text Color", colors, "textRight",
        colors.textRight[1], colors.textRight[2], colors.textRight[3])
    cpRight:SetPoint("TOPLEFT", 30, y)
    y = y - SMALL_GAP - 14

    local cpHdr = CreateColorPicker(parent, "Header Text Color", colors, "headerText",
        colors.headerText[1], colors.headerText[2], colors.headerText[3])
    cpHdr:SetPoint("TOPLEFT", 30, y)
    y = y - SMALL_GAP - 14

    local hasEnabledExpansion = false
    for _k, _v in pairs(HomeworkTrackerDB.expansions or {}) do
        if _v then hasEnabledExpansion = true; break end
    end

    local fGeneral = CreateTabFrame(parent, "fGeneral", "Frame")
    fGeneral:SetSize(200, 20)
    fGeneral:SetPoint("TOPLEFT", 15, y)
    
    local hGeneral = CreateTabLabel(fGeneral, "hGeneral")
    hGeneral:SetPoint("LEFT", 0, 0)
    SetConfigFont(hGeneral, 12)
    hGeneral:SetText("General")
    hGeneral:SetTextColor(0.8, 0.8, 0.5)
    y = y - SMALL_GAP - 9

    local singleColors = {
        { "Bountiful Delves",    "delves",         unpack(addon.defaultColors.delves) },
        { "Delve Companion",     "delveCompanion", unpack(addon.defaultColors.delveCompanion) },
        { "Great Vault",         "vault",          unpack(addon.defaultColors.vault) },
        { "Season Progress",     "progress",       unpack(addon.defaultColors.progress) },
        { "General Weekly Quests", "weekly",        addon.defaultColors.weekly[1], addon.defaultColors.weekly[2], addon.defaultColors.weekly[3], "Applied to weekly quests that are not bound to a specific zone" },
        { "Currencies / Items",  "currency",       unpack(addon.defaultColors.currency) },
    }
    
    for _, sc in ipairs(singleColors) do
        local cp = CreateColorPicker(parent, sc[1], colors, sc[2], sc[3], sc[4], sc[5])
        cp:SetPoint("TOPLEFT", 30, y)
        
        if sc[6] then
            cp:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_CURSOR", 20, 0)
                GameTooltip:SetText(sc[1], 1, 1, 1)
                GameTooltip:AddLine(sc[6], nil, nil, nil, true)
                GameTooltip:Show()
            end)
            cp:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end
        
        y = y - SMALL_GAP - 14
    end
    y = y - SMALL_GAP

    if hasEnabledExpansion then

        local fActivities = CreateTabFrame(parent, "fActivities", "Frame")
        fActivities:SetSize(200, 20)
        fActivities:SetPoint("TOPLEFT", 15, y)
        
        local hActivities = CreateTabLabel(fActivities, "hActivities")
        hActivities:SetPoint("LEFT", 0, 0)
        SetConfigFont(hActivities, 12)
        hActivities:SetText("Activities")
        hActivities:SetTextColor(0.8, 0.8, 0.5)
        y = y - SMALL_GAP - 9
        
        colors.activities = colors.activities or {}

        local selectedExpansion = GetSelectedExpansion()
        local eventsList = {}
        for key, ev in pairs(addon.eventDB or {}) do
            if not ev.expansion or ev.expansion == selectedExpansion then
                table.insert(eventsList, key)
            end
        end
        -- Expansion timers first, then world events, matching the tracker's own order
        table.sort(eventsList, function(a, b)
            local aWorld = (addon.eventDB[a].expansion == nil)
            local bWorld = (addon.eventDB[b].expansion == nil)
            if aWorld ~= bWorld then return bWorld end
            return addon:GetEventName(a) < addon:GetEventName(b)
        end)

        if #eventsList == 0 then
            local msg = CreateTabLabel(parent, "msg")
            msg:SetPoint("TOPLEFT", 30, y)
            SetConfigFont(msg, 12)
            if not selectedExpansion then
                msg:SetText("No expansion is currently enabled.")
            else
                msg:SetText("No activities for the selected expansion.")
            end
            msg:SetTextColor(0.6, 0.6, 0.6)
            y = y - SMALL_GAP - 14
        else
            for _, key in ipairs(eventsList) do
                local label = addon:GetEventName(key)
                local defR, defG, defB = 0.5, 0.5, 0.5
                if addon.defaultColors and addon.defaultColors.activities and addon.defaultColors.activities[key] then
                    defR, defG, defB = unpack(addon.defaultColors.activities[key])
                elseif addon.eventDB[key] and addon.eventDB[key].color then
                    defR, defG, defB = unpack(addon.eventDB[key].color)
                    if defR and defR > 1 then defR = defR / 255 end
                    if defG and defG > 1 then defG = defG / 255 end
                    if defB and defB > 1 then defB = defB / 255 end
                end

                -- An event running a named expansion is coloured per expansion, not per event
                local dbTable, dbKey = colors.activities, key
                local expLabel = addon:GetEventExpansionLabel(key)
                if expLabel then
                    colors.expansions = colors.expansions or {}
                    dbTable, dbKey = colors.expansions, expLabel
                    label = label .. ": " .. expLabel
                    if addon.expansionColors and addon.expansionColors[expLabel] then
                        defR, defG, defB = unpack(addon.expansionColors[expLabel])
                    end
                end

                local cp = CreateColorPicker(parent, label, dbTable, dbKey, defR, defG, defB)
                cp:SetPoint("TOPLEFT", 30, y)
                y = y - SMALL_GAP - 14
            end
            y = y - SMALL_GAP + 6
        end

        -- Reputations with their own color; the rest inherit their zone's color
        colors.reputations = colors.reputations or {}

        local standaloneReps = {}
        for _, rep in ipairs(addon.reputationDB or {}) do
            if rep.id and addon.defaultColors and addon.defaultColors.reputations and addon.defaultColors.reputations[rep.id] then
                if not rep.expansion or rep.expansion == selectedExpansion then
                    table.insert(standaloneReps, { name = rep.name, key = rep.id, order = rep.order or 99 })
                end
            end
        end
        table.sort(standaloneReps, function(a, b)
            if a.order ~= b.order then return a.order < b.order end
            return a.name < b.name
        end)

        if #standaloneReps > 0 then
            local fReps = CreateTabFrame(parent, "fReps", "Frame")
            fReps:SetSize(200, 20)
            fReps:SetPoint("TOPLEFT", 15, y)

            local hReps = CreateTabLabel(fReps, "hReps")
            hReps:SetPoint("LEFT", 0, 0)
            SetConfigFont(hReps, 12)
            hReps:SetText("Reputations")
            hReps:SetTextColor(0.8, 0.8, 0.5)
            y = y - SMALL_GAP - 9

            for _, rep in ipairs(standaloneReps) do
                local defR, defG, defB = unpack(addon.defaultColors.reputations[rep.key])
                local cp = CreateColorPicker(parent, rep.name, colors.reputations, rep.key, defR, defG, defB)
                cp:SetPoint("TOPLEFT", 30, y)
                y = y - SMALL_GAP - 14
            end
            y = y - SMALL_GAP + 6
        end


        local fRares = CreateTabFrame(parent, "fRares", "Frame")
        fRares:SetSize(200, 20)
        fRares:SetPoint("TOPLEFT", 15, y)
        
        local hRares = CreateTabLabel(fRares, "hRares")
        hRares:SetPoint("LEFT", 0, 0)
        SetConfigFont(hRares, 12)
        hRares:SetText("Zones")
        hRares:SetTextColor(0.8, 0.8, 0.5)
        y = y - SMALL_GAP - 9
        
        colors.zones = colors.zones or {}
        local zones = {}
        if addon.zonePriority and addon.zoneCategoryMap then
            for zoneName, order in pairs(addon.zonePriority) do
                local cat = addon.zoneCategoryMap and addon.zoneCategoryMap[zoneName]
                if cat and addon.defaultColors and addon.defaultColors.zones and addon.defaultColors.zones[cat] then

                    local mapID = addon.zoneIDs and addon.zoneIDs[zoneName]
                    if not selectedExpansion or (mapID and addon.expansionMapIDs and addon.expansionMapIDs[selectedExpansion] and addon.expansionMapIDs[selectedExpansion][mapID]) then
                        table.insert(zones, { name = zoneName, key = cat, order = order })
                    end
                end
            end
            table.sort(zones, function(a, b) return a.order < b.order end)
            if #zones == 0 then
                local msg = CreateTabLabel(parent, "msg")
                msg:SetPoint("TOPLEFT", 30, y)
                SetConfigFont(msg, 12)
                msg:SetText("No zones for the selected expansion.")
                msg:SetTextColor(0.6, 0.6, 0.6)
                y = y - SMALL_GAP - 14
            else
                local seen = {}
                for _, z in ipairs(zones) do
                    if not seen[z.key] then
                        seen[z.key] = true
                        local defR, defG, defB = unpack(addon.defaultColors.zones[z.key] or {0.5,0.5,0.5})
                        local cp = CreateColorPicker(parent, z.name, colors.zones, z.key, defR, defG, defB)
                        cp:SetPoint("TOPLEFT", 30, y)
                        y = y - SMALL_GAP - 14
                    end
                end
            end
        else

            for k, v in pairs(addon.defaultColors and addon.defaultColors.zones or {}) do
                local cp = CreateColorPicker(parent, k, colors.zones, k, unpack(v))
                cp:SetPoint("TOPLEFT", 30, y)
                y = y - SMALL_GAP - 14
            end
        end
    end
    
    if not hasEnabledExpansion then
        y = y + SMALL_GAP
    end

    local hOrder = CreateHeader(parent, "Order")
    hOrder:SetPoint("TOPLEFT", 10, y)
    y = y - BIG_GAP + 4


    do
        local mods = {}
        for i, m in ipairs(addon.modules or {}) do
            local display = m.name:gsub("([a-z])([A-Z])","%1 %2")
            table.insert(mods, { name = m.name, func = m.func, order = i, display = display })
        end
        if HomeworkTrackerDB.moduleOrder then
            table.sort(mods, function(a, b)
                local oa = HomeworkTrackerDB.moduleOrder[a.name] or a.order
                local ob = HomeworkTrackerDB.moduleOrder[b.name] or b.order
                if oa ~= ob then return oa < ob end
                return a.name < b.name
            end)
        end

        if #mods > 0 then
            local reorderStartY = y
            local lineHeight = 20

            local lineGap = math.max(0, SMALL_GAP - 4)
            local frames = {}
            local stopDrag -- forward declaration for use in closures

            -- floating copy of the button being moved, keep button template
            local dragFrame = CreateTabFrame(parent, "dragFrame", "Button", "UIPanelButtonTemplate")
            dragFrame:SetSize(200, lineHeight)
            -- make it not respond to clicks
            dragFrame:EnableMouse(false)
            dragFrame:SetScript("OnUpdate", nil)
            dragFrame:RegisterForDrag("LeftButton")
            dragFrame:SetScript("OnDragStop", function(self)
                if self.draggedName then
                    local orig = frames[self.draggedName]
                    if orig then
                        stopDrag(orig)
                    end
                end
            end)
            local dragText = CreateTabLabel(dragFrame, "dragText", "GameFontNormal")
            dragText:ClearAllPoints()
            dragText:SetPoint("CENTER", 0, 0)
            dragText:SetJustifyH("CENTER")
            dragText:SetJustifyV("MIDDLE")
            dragFrame._text = dragText
            dragFrame:Hide()

            local function persistOrder()
                HomeworkTrackerDB.moduleOrder = HomeworkTrackerDB.moduleOrder or {}
                for idx, m in ipairs(mods) do
                    HomeworkTrackerDB.moduleOrder[m.name] = idx
                    addon.modules[idx] = { name = m.name, func = m.func }
                end
            end

            local function refreshPositions()
                for idx, m in ipairs(mods) do
                    local f = frames[m.name]
                    if f then
                        f:ClearAllPoints()
                        f:SetPoint("TOPLEFT", 30, reorderStartY - (idx - 1) * (lineHeight + lineGap))
                        f.index = idx
                    end
                end
            end

            local function onDragUpdate(self)

                if not IsMouseButtonDown("LeftButton") then
                    local orig = frames[dragFrame.draggedName]
                    if orig then
                        stopDrag(orig)
                    end
                    return
                end

                local scale = UIParent:GetEffectiveScale()
                local cursorX, cursorY = GetCursorPosition()
                cursorX, cursorY = cursorX / scale, cursorY / scale
                dragFrame:ClearAllPoints()
                dragFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cursorX, cursorY)


                local cy = cursorY
                local newIndex
                for i, pos in ipairs(dragFrame.positions or {}) do
                    if cy > pos then
                        newIndex = i
                        break
                    end
                end
                if not newIndex then
                    newIndex = (#dragFrame.positions or 0) + 1
                end

                if newIndex ~= dragFrame.currentIndex then
                    dragFrame.currentIndex = newIndex
                    local name = dragFrame.draggedName
                    local func = dragFrame.draggedFunc
                    local newMods = {}
                    for _, mm in ipairs(mods) do
                        if mm.name ~= name then
                            table.insert(newMods, mm)
                        end
                    end
                    table.insert(newMods, newIndex, { name = name, func = func })
                    mods = newMods
                    persistOrder()
                    refreshPositions()


                    dragFrame.positions = {}
                    local cnt = 0
                    for _, mm in ipairs(mods) do
                        if mm.name ~= name then
                            local ff = frames[mm.name]
                            if ff then
                                local _, cy2 = ff:GetCenter()
                                cnt = cnt + 1
                                dragFrame.positions[cnt] = cy2
                            end
                        end
                    end
                end
            end


            local function startDrag(f)
                f:Hide()
                dragFrame:SetSize(f:GetSize())
                dragFrame:SetText(f:GetText())
                local t
                t = f:GetNormalTexture()
                if t then dragFrame:SetNormalTexture(t) end
                t = f:GetHighlightTexture()
                if t then dragFrame:SetHighlightTexture(t) end
                t = f:GetPushedTexture()
                if t then dragFrame:SetPushedTexture(t) end
                dragFrame.draggedName = f.name
                dragFrame.draggedFunc = f.func
                dragFrame.currentIndex = f.index
                dragFrame.positions = {}
                local cnt = 0
                for _, mm in ipairs(mods) do
                    if mm.name ~= f.name then
                        local ff = frames[mm.name]
                        if ff then
                            local _, cy = ff:GetCenter()
                            cnt = cnt + 1
                            dragFrame.positions[cnt] = cy
                        end
                    end
                end
                local scale = UIParent:GetEffectiveScale()
                local cursorX, cursorY = GetCursorPosition()
                cursorX, cursorY = cursorX / scale, cursorY / scale
                dragFrame:ClearAllPoints()
                dragFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cursorX, cursorY)
                dragFrame:Show()
                dragFrame:SetScript("OnUpdate", onDragUpdate)
            end

                stopDrag = function(f)
                f:StopMovingOrSizing()
                dragFrame:SetScript("OnUpdate", nil)
                dragFrame:Hide()
                f:Show()
                persistOrder()
                refreshPositions()
                if addon.UpdateDisplay then addon:UpdateDisplay() end
            end

            for idx, m in ipairs(mods) do
                local f = CreateTabFrame(parent, "f", "Button", "UIPanelButtonTemplate")
                f:SetSize(200, lineHeight)
                f:SetPoint("TOPLEFT", 30, reorderStartY - (idx - 1) * (lineHeight + lineGap))
                f.name = m.name
                f.func = m.func
                f:SetText(m.display or m.name)
                local ft = f:GetFontString()
                ft:ClearAllPoints()
                ft:SetPoint("CENTER", 0, 0)
                ft:SetJustifyH("CENTER")
                ft:SetJustifyV("MIDDLE")
            
                f:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText("Drag to reorder", 1, 1, 1)
                    GameTooltip:Show()
                end)
                f:SetScript("OnLeave", GameTooltip_Hide)
                f:EnableMouse(true)
                f:RegisterForDrag("LeftButton")
                f:SetScript("OnDragStart", startDrag)
                f:SetScript("OnDragStop", stopDrag)
                frames[m.name] = f
            end

            y = y - (#mods) * (lineHeight + lineGap)
        end
    end

    y = y + (2 * BIG_GAP) - (2 * SMALL_GAP) - 6


    PlaceResetButton(parent, y, function()
        HomeworkTrackerDB.locked = false
        HomeworkTrackerDB.scale = addon.defaults.scale
        HomeworkTrackerDB.colors = {} -- Clear overrides
        HomeworkTrackerDB.font = addon.defaults.font
        HomeworkTrackerDB.fontSize = addon.defaults.fontSize
        HomeworkTrackerDB.fontOutline = addon.defaults.fontOutline
        HomeworkTrackerDB.headerFont = addon.defaults.headerFont
        HomeworkTrackerDB.headerFontSize = addon.defaults.headerFontSize
        HomeworkTrackerDB.headerFontOutline = addon.defaults.headerFontOutline
        HomeworkTrackerDB.hideTitleText = addon.defaults.hideTitleText
        HomeworkTrackerDB.barTexture = nil
        HomeworkTrackerDB.width = addon.defaults.width or 280
        HomeworkTrackerDB.height = addon.defaults.height or 400
        HomeworkTrackerDB.position = addon.defaults.position and { point = addon.defaults.position.point,
                relativePoint = addon.defaults.position.relativePoint,
                xOfs = addon.defaults.position.xOfs,
                yOfs = addon.defaults.position.yOfs }
        HomeworkTrackerDB.moduleOrder = nil
        HomeworkTrackerDB.categoryOrder = nil


        if addon.defaultModuleOrder and addon.modules then
            table.sort(addon.modules, function(a, b)
                local oa = addon.defaultModuleOrder[a.name] or 999
                local ob = addon.defaultModuleOrder[b.name] or 999
                if oa ~= ob then return oa < ob end
                return a.name < b.name
            end)
        end

        if addon.mainFrame then 
            addon.mainFrame:SetScale(addon.defaults.scale)
            addon.mainFrame:SetMovable(true)
            addon.mainFrame:EnableMouse(true)
            addon.mainFrame:RegisterForDrag("LeftButton")
        end

        addon:UpdateLayout()
        addon:SetFontKey(nil)
        RefreshContent()
        addon:UpdateDisplay()
    end, BIG_GAP + 28)

end

-- Build activities tab
local function BuildTab_Activities(parent)
    local y = -10

    local selectedExpansion = GetSelectedExpansion()
    local hasEnabledExpansion = (selectedExpansion ~= nil)

    -- World events belong to no expansion, so they get their own group
    local worldEvents, expansionEvents = {}, {}
    for key, ev in pairs(addon.eventDB or {}) do
        if not ev.expansion then
            table.insert(worldEvents, key)
        elseif ev.expansion == selectedExpansion then
            table.insert(expansionEvents, key)
        end
    end

    local function ByName(a, b) return addon:GetEventName(a) < addon:GetEventName(b) end
    table.sort(worldEvents, ByName)
    table.sort(expansionEvents, ByName)

    local function AddEventCheckboxes(keys, emptyText)
        if #keys == 0 then
            local msg = CreateTabLabel(parent, "msg")
            msg:SetPoint("TOPLEFT", 30, y)
            SetConfigFont(msg, 12)
            msg:SetText(emptyText)
            msg:SetTextColor(0.6, 0.6, 0.6)
            y = y - SMALL_GAP - 14
            return
        end

        for _, k in ipairs(keys) do
            if HomeworkTrackerDB.activities[k] == nil then
                HomeworkTrackerDB.activities[k] = (addon.defaults.activities and addon.defaults.activities[k]) or false
            end
            local cb = CreateCheckbox(parent, "Show " .. addon:GetEventName(k), (function(key)
                return function(val)
                    HomeworkTrackerDB.activities[key] = val
                    -- Switching one off needs no new dates, only a redraw
                    if val then addon:EnsureHolidayScanned(key) end
                    addon:UpdateDisplay()
                end
            end)(k))
            cb:SetPoint("TOPLEFT", 30, y)
            cb.check:SetChecked(HomeworkTrackerDB.activities[k])
            y = y - SMALL_GAP - 14
        end
        y = y - SMALL_GAP
    end

    local hExp = CreateHeader(parent, "Expansion Timers")
    hExp:SetPoint("TOPLEFT", 10, y)
    y = y - BIG_GAP + 10
    if hasEnabledExpansion then
        AddEventCheckboxes(expansionEvents, "No activities for the selected expansion.")
    else
        local msg = CreateTabLabel(parent, "msg")
        msg:SetPoint("TOPLEFT", 30, y)
        SetConfigFont(msg, 12)
        msg:SetText("No expansion is currently enabled.")
        msg:SetTextColor(0.6, 0.6, 0.6)
        y = y - SMALL_GAP - 14
    end

    y = y + SMALL_GAP
    local hWorld = CreateHeader(parent, "World Events")
    hWorld:SetPoint("TOPLEFT", 10, y)
    y = y - BIG_GAP + 10
    AddEventCheckboxes(worldEvents, "No world events.")

    y = y + SMALL_GAP

    local h = CreateHeader(parent, "Options")
    h:SetPoint("TOPLEFT", 10, y)
    y = y - BIG_GAP + 10
    
    local cb2 = CreateCheckbox(parent, "Hide Completed Activities", function(val)
        HomeworkTrackerDB.activities.hideComplete = val
        addon:UpdateDisplay()
    end)
    cb2:SetPoint("TOPLEFT", 30, y)
    cb2.check:SetChecked(HomeworkTrackerDB.activities.hideComplete)
    
    PlaceResetButton(parent, y, function()

        local currentExpansion = GetSelectedExpansion()
        for key, ev in pairs(addon.eventDB or {}) do
            if not ev.expansion or ev.expansion == currentExpansion then
                HomeworkTrackerDB.activities[key] = (addon.defaults.activities and addon.defaults.activities[key]) or false
            end
        end
        HomeworkTrackerDB.activities.hideComplete = addon.defaults.activities.hideComplete
        RefreshContent()
        addon:UpdateDisplay()
    end)
end

-- Build vault tab
local function BuildTab_GreatVault(parent)
    local y = -10
    local h1 = CreateHeader(parent, "Great Vault")
    h1:SetPoint("TOPLEFT", 10, y)
    y = y - BIG_GAP + 10
    
    local cbGV1 = CreateCheckbox(parent, "Show Raid", function(val)
        HomeworkTrackerDB.greatVault.showRaid = val
        addon:UpdateDisplay()
    end)
    cbGV1:SetPoint("TOPLEFT", 30, y)
    cbGV1.check:SetChecked(HomeworkTrackerDB.greatVault.showRaid)
    y = y - SMALL_GAP - 14
    
    local cbGV2 = CreateCheckbox(parent, "Show Mythic+", function(val)
        HomeworkTrackerDB.greatVault.showMythicPlus = val
        addon:UpdateDisplay()
    end)
    cbGV2:SetPoint("TOPLEFT", 30, y)
    cbGV2.check:SetChecked(HomeworkTrackerDB.greatVault.showMythicPlus)
    y = y - SMALL_GAP - 14
    
    local cbGV3 = CreateCheckbox(parent, "Show Delves", function(val)
        HomeworkTrackerDB.greatVault.showDelves = val
        addon:UpdateDisplay()
    end)
    cbGV3:SetPoint("TOPLEFT", 30, y)
    cbGV3.check:SetChecked(HomeworkTrackerDB.greatVault.showDelves)
    
    PlaceResetButton(parent, y, function()
        HomeworkTrackerDB.greatVault.showRaid = addon.defaults.greatVault.showRaid
        HomeworkTrackerDB.greatVault.showMythicPlus = addon.defaults.greatVault.showMythicPlus
        HomeworkTrackerDB.greatVault.showDelves = addon.defaults.greatVault.showDelves
        RefreshContent()
        addon:UpdateDisplay()
    end)
end

-- Build weekly tab
local function BuildTab_Weekly(parent)
    local y = -10

    local h3 = CreateHeader(parent, "Weekly Activities")
    h3:SetPoint("TOPLEFT", 10, y)
    y = y - BIG_GAP + 10

    local selectedExpansion = GetSelectedExpansion()

    if addon.weeklyDB then

        local filteredWeekly = {}
        for _, act in ipairs(addon.weeklyDB) do
            if not act.expansion or act.expansion == selectedExpansion then
                table.insert(filteredWeekly, act)
            end
        end

        if #filteredWeekly > 0 then
            HomeworkTrackerDB.weekly.hidden = HomeworkTrackerDB.weekly.hidden or {}


            local function ZoneNameFromCategory(cat)
                if cat == "general" then return "General" end
                if addon.zoneCategoryMap then
                    for zn, c in pairs(addon.zoneCategoryMap) do
                        if c == cat then
                            return zn
                        end
                    end
                end

                return cat:gsub("^%l", string.upper)
            end

            local zones = {}
            for _, act in ipairs(filteredWeekly) do
                local zn = act.category or "general"
                zones[zn] = zones[zn] or {}
                table.insert(zones[zn], act)
            end

            local zoneNames = {}
            for zn in pairs(zones) do table.insert(zoneNames, zn) end
            table.sort(zoneNames, function(a,b)
                if a == "general" then return true end
                if b == "general" then return false end
                local za = ZoneNameFromCategory(a)
                local zb = ZoneNameFromCategory(b)
                local pa = addon.zonePriority and addon.zonePriority[za] or 99
                local pb = addon.zonePriority and addon.zonePriority[zb] or 99
                if pa ~= pb then return pa < pb end
                return za < zb
            end)

            for _, zn in ipairs(zoneNames) do
                local list = zones[zn]
                if list and #list > 0 then
                    local lbl = CreateTabLabel(parent, "lbl")
                    SetConfigFont(lbl, 12)
                    lbl:SetPoint("TOPLEFT", 30, y)
                    lbl:SetText(ZoneNameFromCategory(zn))
                    lbl:SetTextColor(0.8, 0.8, 0.5)

                    y = y - SMALL_GAP - 4

                    for _, act in ipairs(list) do
                        local isEnabled = not HomeworkTrackerDB.weekly.hidden[act.name]
                        local cb = CreateCheckbox(parent, act.name, function(val)
                            HomeworkTrackerDB.weekly.hidden[act.name] = not val
                            addon:UpdateDisplay()
                        end)
                        cb:SetPoint("TOPLEFT", 30, y)
                        cb.check:SetChecked(isEnabled)
                        y = y - SMALL_GAP - 14
                    end

                    y = y - SMALL_GAP
                end
            end

            y = y + SMALL_GAP

        else
            local msg = CreateTabLabel(parent, "msg")
            msg:SetPoint("TOPLEFT", 30, y)
            SetConfigFont(msg, 12)
            if not selectedExpansion then
                msg:SetText("No expansion is currently enabled.")
            else
                msg:SetText("No weekly activities for the selected expansion.")
            end
            msg:SetTextColor(0.6, 0.6, 0.6)
            y = y - SMALL_GAP - 14
        end
    end

    local h2 = CreateHeader(parent, "Options")
    h2:SetPoint("TOPLEFT", 10, y)
    y = y - BIG_GAP + 10
    
    local cbWQ1 = CreateCheckbox(parent, "Hide Completed Quests", function(val)
        HomeworkTrackerDB.weekly.hideComplete = val
        addon:UpdateDisplay()
    end)
    cbWQ1:SetPoint("TOPLEFT", 30, y)
    cbWQ1.check:SetChecked(HomeworkTrackerDB.weekly.hideComplete)

    PlaceResetButton(parent, y, function()
        HomeworkTrackerDB.weekly.hideComplete = addon.defaults.weekly.hideComplete
        HomeworkTrackerDB.weekly.hidden = {}
        RefreshContent()
        addon:UpdateDisplay()
    end)
end

-- Build currencies tab
local function BuildTab_Currencies(parent)
    local y = -10

    local h1 = CreateHeader(parent, "Currencies & Items")
    h1:SetPoint("TOPLEFT", 10, y)
    y = y - BIG_GAP + 10

    local selectedExpansion = GetSelectedExpansion()

    local globalCurrencies = {}
    local expansionCurrencies = {}
    local expansionItems = {}
    if addon.currencyDB then
        for _, c in ipairs(addon.currencyDB) do
            if not c.expansion then
                table.insert(globalCurrencies, c)
            elseif c.expansion == selectedExpansion then
                if c.isItem then
                    table.insert(expansionItems, c)
                else
                    table.insert(expansionCurrencies, c)
                end
            end
        end
    end

    local shown = 0

    local function renderEntry(c)
        shown = shown + 1
        local cb = CreateCheckbox(parent, c.name, function(val)
            HomeworkTrackerDB.currency[c.id] = val
            addon:UpdateDisplay()
        end)
        cb:SetPoint("TOPLEFT", 30, y)
        local val = HomeworkTrackerDB.currency[c.id]
        if val == nil then
            val = (addon.defaults and addon.defaults.currency and addon.defaults.currency[c.id]) or true
        end
        cb.check:SetChecked(val)
        if cb.label and c.icon then
            local iconStr = (type(c.icon) == "number") and ("|T" .. c.icon .. ":16|t") or ("|TInterface\\Icons\\" .. c.icon .. ":16|t")
            cb.label:SetText(c.name .. "  " .. iconStr)
        end
        y = y - SMALL_GAP - 14
    end

    local function renderSubheader(text)
        local hdr = CreateTabLabel(parent, "hdr")
        hdr:SetPoint("TOPLEFT", 30, y)
        SetConfigFont(hdr, 12)
        hdr:SetText(text)
        hdr:SetTextColor(0.8, 0.8, 0.5)
        y = y - SMALL_GAP - 4
    end

    if #globalCurrencies > 0 then
        renderSubheader("Global Currencies")
        for _, c in ipairs(globalCurrencies) do renderEntry(c) end
        y = y - SMALL_GAP
    end

    if #expansionCurrencies > 0 then
        renderSubheader("Expansion Currencies")
        for _, c in ipairs(expansionCurrencies) do renderEntry(c) end
        if #expansionItems > 0 then y = y - SMALL_GAP end
    end

    if #expansionItems > 0 then
        renderSubheader("Expansion Items")
        for _, c in ipairs(expansionItems) do renderEntry(c) end
    else
        y = y + SMALL_GAP - 12
    end

    if shown == 0 then
        local msg = CreateTabLabel(parent, "msg")
        msg:SetPoint("TOPLEFT", 30, y)
        SetConfigFont(msg, 12)
        if selectedExpansion then
            msg:SetText("No currencies or items for the selected expansion.")
        else
            msg:SetText("No expansion is currently enabled.")
        end
        msg:SetTextColor(0.6, 0.6, 0.6)
        y = y - SMALL_GAP - 14
    end

    if not selectedExpansion then
        y = y + SMALL_GAP + 2
    else
        y = y - SMALL_GAP + 14
    end

    local hOptions = CreateHeader(parent, "Options")
    hOptions:SetPoint("TOPLEFT", 10, y)
    y = y - BIG_GAP + 10

    local fmtDropdown = CreateSimpleDropdown(parent, "Show", 220)
    fmtDropdown:SetPoint("TOPLEFT", 30, y)
    local function getFormatLabel(fmt)
        if fmt == "slash" then return "x/total"
        elseif fmt == "percent" then return "x (percent)"
        else return "x/total (percent)" end
    end
    local currentFmt = HomeworkTrackerDB.currency.format or
                       ((addon.defaults and addon.defaults.currency and addon.defaults.currency.format) or "both")
    fmtDropdown:SetOptions({"x/total (percent)", "x/total", "x (percent)"})
    fmtDropdown:SetValue(getFormatLabel(currentFmt))
    fmtDropdown:SetOnChange(function(val)
        local newFmt = "both"
        if val == "x/total" then newFmt = "slash"
        elseif val == "x (percent)" then newFmt = "percent" end
        HomeworkTrackerDB.currency.format = newFmt
        addon:UpdateDisplay()
    end)

    y = y - SMALL_GAP - 30

    PlaceResetButton(parent, y, function()

        if addon.currencyDB then
            for _, c in ipairs(addon.currencyDB) do
                local defaultVal = true
                if addon.defaults and addon.defaults.currency and addon.defaults.currency[c.id] ~= nil then
                    defaultVal = addon.defaults.currency[c.id]
                end
                HomeworkTrackerDB.currency[c.id] = defaultVal
            end
        end

        if addon.defaults and addon.defaults.currency and addon.defaults.currency.format then
            HomeworkTrackerDB.currency.format = addon.defaults.currency.format
        else
            HomeworkTrackerDB.currency.format = "both"
        end
        RefreshContent()
        addon:UpdateDisplay()
    end, SMALL_GAP + 8)
end

-- Build progress tab
local function BuildTab_Progress(parent)
    local y = -10
    local h2 = CreateHeader(parent, "Season Progress")
    h2:SetPoint("TOPLEFT", 10, y)
    y = y - BIG_GAP + 10


    if addon.progressDB then
        local items = {}
        for _, p in ipairs(addon.progressDB) do
            table.insert(items, p)
        end

        if #items > 0 then
            HomeworkTrackerDB.progress = HomeworkTrackerDB.progress or {}
            HomeworkTrackerDB.progress.hidden = HomeworkTrackerDB.progress.hidden or {}

            for _, p in ipairs(items) do
                local isEnabled = not HomeworkTrackerDB.progress.hidden[p.id]
                local cb = CreateCheckbox(parent, p.name, function(val)
                    HomeworkTrackerDB.progress.hidden[p.id] = not val
                    addon:UpdateDisplay()
                end)

                cb:SetPoint("TOPLEFT", 30, y)
                cb.check:SetChecked(isEnabled)
                y = y - SMALL_GAP - 14
            end
        else
            local msg = CreateTabLabel(parent, "msg")
            msg:SetPoint("TOPLEFT", 30, y)
            SetConfigFont(msg, 12)
            msg:SetText("No season progress entries available.")
            msg:SetTextColor(0.6, 0.6, 0.6)
            y = y - SMALL_GAP - 14
        end
    end

    y = y + SMALL_GAP - 14


    PlaceResetButton(parent, y, function()
        HomeworkTrackerDB.progress = HomeworkTrackerDB.progress or {}
        HomeworkTrackerDB.progress.hidden = {}
        RefreshContent()
        addon:UpdateDisplay()
    end, SMALL_GAP + 8)
end

-- Build reputations tab
local function BuildTab_Reputations(parent)
    local y = -10
    
    local h2 = CreateHeader(parent, "Reputations")
    h2:SetPoint("TOPLEFT", 10, y)
    y = y - BIG_GAP + 10
    
    local selectedExpansion = GetSelectedExpansion()

    if addon.reputationDB then
        local reps = {}
        for _, rep in ipairs(addon.reputationDB) do
            if not rep.expansion or rep.expansion == selectedExpansion then
                table.insert(reps, rep)
            end
        end

        if #reps > 0 then
            HomeworkTrackerDB.reputations.hidden = HomeworkTrackerDB.reputations.hidden or {}

            local function ZoneNameFromCategory(cat)
                if cat == "general" then return "General" end
                if addon.zoneCategoryMap then
                    for zn, c in pairs(addon.zoneCategoryMap) do
                        if c == cat then
                            return zn
                        end
                    end
                end
                return cat:gsub("^%l", string.upper)
            end

            local zones = {}
            for _, rep in ipairs(reps) do
                local zn = rep.category or "general"
                zones[zn] = zones[zn] or {}
                table.insert(zones[zn], rep)
            end

            local zoneNames = {}
            for zn in pairs(zones) do table.insert(zoneNames, zn) end
            table.sort(zoneNames, function(a,b)
                if a == "general" then return true end
                if b == "general" then return false end
                local za = ZoneNameFromCategory(a)
                local zb = ZoneNameFromCategory(b)
                local pa = addon.zonePriority and addon.zonePriority[za] or 99
                local pb = addon.zonePriority and addon.zonePriority[zb] or 99
                if pa ~= pb then return pa < pb end
                return za < zb
            end)

            for _, zn in ipairs(zoneNames) do
                local list = zones[zn]
                if list and #list > 0 then
                    local zoneLabel = CreateTabLabel(parent, "zoneLabel")
                    SetConfigFont(zoneLabel, 12)
                    zoneLabel:SetPoint("TOPLEFT", 30, y)
                    zoneLabel:SetText(ZoneNameFromCategory(zn))
                    zoneLabel:SetTextColor(0.8, 0.8, 0.5)
                    y = y - SMALL_GAP - 4

                    for _, rep in ipairs(list) do
                        local isEnabled = not HomeworkTrackerDB.reputations.hidden[rep.id]
                        local cb = CreateCheckbox(parent, rep.name, function(val)
                            HomeworkTrackerDB.reputations.hidden[rep.id] = not val
                            addon:UpdateDisplay()
                        end)
                        cb:SetPoint("TOPLEFT", 30, y)
                        cb.check:SetChecked(isEnabled)
                        y = y - SMALL_GAP - 14
                    end

                    y = y - SMALL_GAP
                end
            end
            y = y + SMALL_GAP
        else
            local msg = CreateTabLabel(parent, "msg")
            msg:SetPoint("TOPLEFT", 30, y)
            SetConfigFont(msg, 12)
            if not selectedExpansion then
                msg:SetText("No expansion is currently enabled.")
            else
                msg:SetText("No reputations for the selected expansion.")
            end
            msg:SetTextColor(0.6, 0.6, 0.6)
            y = y - SMALL_GAP - 14
        end
    end

    local h1 = CreateHeader(parent, "Options")
    h1:SetPoint("TOPLEFT", 10, y)
    y = y - BIG_GAP + 10
    
    local cb2 = CreateCheckbox(parent, "Hide Completed Reputations", function(val)
        HomeworkTrackerDB.reputations.hideComplete = val
        addon:UpdateDisplay()
    end)
    cb2:SetPoint("TOPLEFT", 30, y)
    cb2.check:SetChecked(HomeworkTrackerDB.reputations.hideComplete)
    
    PlaceResetButton(parent, y, function()
        HomeworkTrackerDB.reputations.hideComplete = addon.defaults.reputations.hideComplete
        HomeworkTrackerDB.reputations.hidden = {}
        if addon.defaults.reputations.hidden then
             for k,v in pairs(addon.defaults.reputations.hidden) do HomeworkTrackerDB.reputations.hidden[k] = v end
        end
        RefreshContent()
        addon:UpdateDisplay()
    end)
end

-- Build rares tab
local function BuildTab_Rares(parent)
    local y = -10
    
    local h3 = CreateHeader(parent, "Zones")
    h3:SetPoint("TOPLEFT", 10, y)
    y = y - BIG_GAP + 10
    
    local hasEnabledExpansion = false
    for _k, _v in pairs(HomeworkTrackerDB.expansions or {}) do
        if _v then hasEnabledExpansion = true; break end
    end
    
    if addon.raresDB then
        if hasEnabledExpansion then
            HomeworkTrackerDB.rares.hiddenZones = HomeworkTrackerDB.rares.hiddenZones or {}
            local zones = {}
            local selectedExpansion = GetSelectedExpansion()
            for _, rare in ipairs(addon.raresDB) do
                if rare.zone and (not rare.expansion or rare.expansion == selectedExpansion) then
                    zones[rare.zone] = true
                end
            end
            
            local sortedZones = {}
            for z, _ in pairs(zones) do table.insert(sortedZones, z) end
            
            table.sort(sortedZones, function(a, b)
                local pA = addon.zonePriority[a] or DEFAULT_SORT_PRIORITY
                local pB = addon.zonePriority[b] or DEFAULT_SORT_PRIORITY
                if pA ~= pB then return pA < pB end
                return a < b
            end)

            if #sortedZones == 0 then
                local msg = CreateTabLabel(parent, "msg")
                msg:SetPoint("TOPLEFT", 30, y)
                SetConfigFont(msg, 12)
                msg:SetText("No rares for the selected expansion.")
                msg:SetTextColor(0.6, 0.6, 0.6)
                y = y - SMALL_GAP - 14
            else
                for _, zoneName in ipairs(sortedZones) do
                    local isEnabled = not HomeworkTrackerDB.rares.hiddenZones[zoneName]
                    local cb = CreateCheckbox(parent, zoneName, function(val)
                        HomeworkTrackerDB.rares.hiddenZones[zoneName] = not val
                        addon:UpdateDisplay()
                    end)
                    cb:SetPoint("TOPLEFT", 30, y)
                    cb.check:SetChecked(isEnabled)
                    y = y - SMALL_GAP - 14
                end
            end
        else
            local msg = CreateTabLabel(parent, "msg")
            msg:SetPoint("TOPLEFT", 30, y)
            SetConfigFont(msg, 12)
            msg:SetText("No expansion is currently enabled.")
            msg:SetTextColor(0.6, 0.6, 0.6)
            y = y - SMALL_GAP - 14
        end
    end

    if not hasEnabledExpansion then
        y = y + SMALL_GAP - 10
    end

    local h2 = CreateHeader(parent, "Options")
    h2:SetPoint("TOPLEFT", 10, y)
    y = y - BIG_GAP + 10
    
    local cb3 = CreateCheckbox(parent, "Filter to Current Zone", function(val)
        HomeworkTrackerDB.rares.currentZone = val
        addon:UpdateDisplay()
    end)
    cb3:SetPoint("TOPLEFT", 30, y)
    cb3.check:SetChecked(HomeworkTrackerDB.rares.currentZone)
    y = y - SMALL_GAP - 14

    local cbRep = CreateCheckbox(parent, "Hide Rares with Reputation Collected", function(val)
        HomeworkTrackerDB.rares.hideRepComplete = val
        addon:UpdateDisplay()
    end)
    cbRep:SetPoint("TOPLEFT", 30, y)
    cbRep.check:SetChecked(HomeworkTrackerDB.rares.hideRepComplete or false)

    PlaceResetButton(parent, y, function()
        HomeworkTrackerDB.rares.currentZone = addon.defaults.rares.currentZone
        HomeworkTrackerDB.rares.hideRepComplete = addon.defaults.rares.hideRepComplete
        HomeworkTrackerDB.rares.hiddenZones = {}
        RefreshContent()
        addon:UpdateDisplay()
    end)
end



-- Build crests tab
local function BuildTab_Crests(parent)
    local y = -10
    local h2 = CreateHeader(parent, "Crests")
    h2:SetPoint("TOPLEFT", 10, y)
    y = y - BIG_GAP + 10
    
    local selectedExpansion = GetSelectedExpansion()
    local crests = {}
    if addon.crestDB then
        for _, c in ipairs(addon.crestDB) do
             if not c.expansion or c.expansion == selectedExpansion then
                  table.insert(crests, c)
             end
         end
    end

    if #crests > 0 then
        for _, c in ipairs(crests) do
            local cb = CreateCheckbox(parent, c.name, function(val)
                HomeworkTrackerDB.crests[c.id] = val
                addon:UpdateDisplay()
            end)
            cb:SetPoint("TOPLEFT", 30, y)
            
            local val = HomeworkTrackerDB.crests[c.id]
            if val == nil then val = true end
            cb.check:SetChecked(val)
            
            if cb.label and c.icon then
                cb.label:SetText(c.name .. "  |TInterface\\Icons\\" .. c.icon .. ":16|t")
            end
            
            y = y - SMALL_GAP - 14
        end
    else
        local msg = CreateTabLabel(parent, "msg")
        msg:SetPoint("TOPLEFT", 30, y)
        SetConfigFont(msg, 12)
        if not selectedExpansion then
            msg:SetText("No expansion is currently enabled.")
        end
        msg:SetTextColor(0.6, 0.6, 0.6)
        y = y - SMALL_GAP - 14
    end

    y = y + SMALL_GAP - 12

    PlaceResetButton(parent, y, function()
        if addon.crestDB then
            for _, c in ipairs(addon.crestDB) do
                HomeworkTrackerDB.crests[c.id] = true
            end
        end
        RefreshContent()
        addon:UpdateDisplay()
    end, SMALL_GAP + 8)
end


-- Define tabs
tabs = {
    { name = "General", builder = BuildTab_General },
    { name = "Appearance", builder = BuildTab_Appearance },
    { name = "Activities", builder = BuildTab_Activities },
    { name = "Vault", builder = BuildTab_GreatVault },
    { name = "Weekly", builder = BuildTab_Weekly },
    { name = "Crests", builder = BuildTab_Crests },
    { name = "Currencies & Items", builder = BuildTab_Currencies },
    { name = "Reputations", builder = BuildTab_Reputations },
    { name = "Season Progress", builder = BuildTab_Progress },
    { name = "Rares", builder = BuildTab_Rares },
    { name = "Profiles", builder = BuildTab_Profiles }
}

-- Switch section
local function SwitchTab(tabName, reuse)
    currentTab = tabName
    for _, btn in ipairs(sidebar.buttons) do
        if btn.key == tabName then
            btn.bg:SetColorTexture(unpack(COLOR_Selected))
        else
            btn.bg:SetColorTexture(0, 0, 0, 0)
        end
    end
    if contentFrame then
        contentFrame:SetVerticalScroll(0)
    end
    RefreshContent(reuse ~= false)
end

-- Create sidebar button
local function CreateSidebarButton(parent, text, index)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(SIDEBAR_WIDTH - 10, 30)
    btn:SetPoint("TOP", 0, -10 - (index - 1) * 35)
    
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    btn.bg = bg
    
    local label = btn:CreateFontString(nil, "OVERLAY")
    label:SetPoint("LEFT", 10, 0)
    SetConfigFont(label, 12)
    label:SetText(text)
    
    btn:SetScript("OnClick", function() SwitchTab(text) end)
    btn:SetScript("OnEnter", function() 
        if currentTab ~= text then bg:SetColorTexture(unpack(COLOR_Hover)) end 
    end)
    btn:SetScript("OnLeave", function() 
        if currentTab ~= text then bg:SetColorTexture(0, 0, 0, 0) end 
    end)
    
    btn.key = text
    return btn
end


local function BuildExpansionOptions()
    local opts = {}
    local map = {}
    if HomeworkTrackerDB and HomeworkTrackerDB.expansions then
        for k, v in pairs(HomeworkTrackerDB.expansions) do
            if v then
                local label = k:gsub("([a-z])([A-Z])","%1 %2"):gsub("_"," ")
                label = label:gsub("^%l", string.upper)
                table.insert(opts, label)
                map[label] = k
            end
        end
    end
    table.sort(opts)
    return opts, map
end

local function AttachExpansionDropdown(parent, yOffset)
    local expDD = CreateHeaderDropdown(parent, 180)
    expDD:SetPoint("TOP", parent, "TOP", 0, yOffset)
    parent.expansionDropdown = expDD

    local function RefreshExpansionDropdown()
        local opts, map = BuildExpansionOptions()
        if #opts == 0 then
            expDD:SetOptions({"(no expansions enabled)"})
            expDD:SetValue("(no expansions enabled)")
            return
        end
        expDD:SetOptions(opts)
        local selKey = GetSelectedExpansion()
        local selLabel = nil
        for lbl, k in pairs(map) do if k == selKey then selLabel = lbl; break end end
        if not selLabel then selLabel = opts[1]; HomeworkTrackerDB.ui = HomeworkTrackerDB.ui or {}; HomeworkTrackerDB.ui.selectedExpansion = map[selLabel] end
        expDD:SetValue(selLabel)
    end

    expDD:SetOnChange(function(label)
        -- Fresh map; expansions toggle after build
        local _, map = BuildExpansionOptions()
        if not map[label] then return end
        HomeworkTrackerDB.ui = HomeworkTrackerDB.ui or {}
        HomeworkTrackerDB.ui.selectedExpansion = map[label]
        RefreshContent()
        addon:UpdateDisplay()
    end)

    RefreshExpansionDropdown()
    return expDD
end

local function AttachSidebarAndScroll(parent, sidebarTopOffset)
    local sb = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    sb:SetPoint("TOPLEFT", 10, sidebarTopOffset)
    sb:SetPoint("BOTTOMLEFT", 10, 10)
    sb:SetWidth(SIDEBAR_WIDTH)
    sb:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    sb:SetBackdropColor(unpack(COLOR_Sidebar))
    sb:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)

    sb.buttons = {}
    for i, tab in ipairs(tabs) do
        local btn = CreateSidebarButton(sb, tab.name, i)
        table.insert(sb.buttons, btn)
    end

    local cf = CreateFrame("ScrollFrame", nil, parent, "ScrollFrameTemplate")
    cf:SetPoint("TOPLEFT", sb, "TOPRIGHT", 10, 0)
    cf:SetPoint("BOTTOMRIGHT", -36, 10)
    cf.ScrollBar:ClearAllPoints()
    cf.ScrollBar:SetPoint("TOPLEFT", cf, "TOPRIGHT", 10, 2)
    cf.ScrollBar:SetPoint("BOTTOMLEFT", cf, "BOTTOMRIGHT", 10, 5)

    local child = CreateFrame("Frame", nil, cf)
    child:SetSize(CONFIG_WIDTH - SIDEBAR_WIDTH - 66, 1)
    cf:SetScrollChild(child)
    cf:SetScript("OnSizeChanged", function(self)
        local w = self:GetWidth()
        if w and w > 0 then child:SetWidth(math.max(w - 20, 200)) end
    end)

    cf.scrollChild = child
    return sb, cf
end

-- Init options window
function addon:CreateConfigPanel()
    if self.configFrame then return end

    local f = CreateBaseFrame("HomeworkTrackerConfig", UIParent)
    f:SetSize(CONFIG_WIDTH, CONFIG_HEIGHT)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()

    f:SetScript("OnHide", function()
        CloseDropdowns()
        CloseConfigPopups()
    end)

    tinsert(UISpecialFrames, "HomeworkTrackerConfig")

    local title = f:CreateFontString(nil, "OVERLAY")
    title:SetPoint("TOPLEFT", 15, -10)
    SetConfigFont(title, 16)
    title:SetText("Homework Tracker Config")
    title:SetTextColor(1, 0.8, 0)

    configFrame = f
    AttachExpansionDropdown(f, -12)

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    closeBtn:SetSize(24, 24)
    closeBtn:SetPoint("TOPRIGHT", -10, -10)
    closeBtn:SetText("X")
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    local sb, cf = AttachSidebarAndScroll(f, -40)
    sidebar = sb
    contentFrame = cf

    floatingSidebar = sidebar
    floatingContentFrame = contentFrame
    floatingConfigFrame = f

    self.configFrame = f

    SwitchTab("General")
end

-- Builds config UI on the Settings canvas (once)
local function BuildCanvasContent()
    if canvasBuilt then return end
    canvasBuilt = true

    local f = settingsCanvas

    AttachExpansionDropdown(f, -8)

    local sb, cf = AttachSidebarAndScroll(f, -36)
    sidebar = sb
    contentFrame = cf
    configFrame = f

    canvasSidebar = sb
    canvasContentFrame = cf

    SwitchTab("General")
end

function addon:OpenConfig()
    if SettingsPanel and SettingsPanel:IsShown() then return end
    if floatingSidebar then
        sidebar = floatingSidebar
        contentFrame = floatingContentFrame
        configFrame = floatingConfigFrame
    end
    if not self.configFrame then
        self:CreateConfigPanel()
    end
    if self.configFrame:IsShown() then
        self.configFrame:Hide()
    else
        self.configFrame:Show()
        SwitchTab(currentTab, false)
    end
end

-- Register in WoW AddOns settings (ESC > Options > AddOns)
do
    if Settings and Settings.RegisterCanvasLayoutCategory then
        settingsCanvas:SetScript("OnHide", function()
            CloseDropdowns()
            CloseConfigPopups()
        end)
        settingsCanvas:SetScript("OnShow", function()
            if addon.configFrame and addon.configFrame:IsShown() then
                addon.configFrame:Hide()
            end
            BuildCanvasContent()
            sidebar = canvasSidebar
            contentFrame = canvasContentFrame
            configFrame = settingsCanvas
            SwitchTab(currentTab, false)
        end)
        settingsCategory = Settings.RegisterCanvasLayoutCategory(settingsCanvas, "Homework Tracker")
        Settings.RegisterAddOnCategory(settingsCategory)
    end
end
