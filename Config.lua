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
local COLOR_Text = {1, 1, 1, 1}
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
local settingsCategory = nil
local floatingSidebar, floatingContentFrame, floatingConfigFrame
local canvasSidebar, canvasContentFrame
local canvasBuilt = false

-- Track dropdown lists
local function TrackDropdown(list)
    if not list then return end
    table.insert(dropdownLists, list)
    list:HookScript("OnHide", function(self)
        for i, v in ipairs(dropdownLists) do
            if v == self then
                table.remove(dropdownLists, i)
                break
            end
        end
    end)
end

-- Setup dropdown frames
local function SetupDropdown(button, list, countFunc)
    TrackDropdown(list)

    list:SetFrameLevel(100)
    list:SetFrameStrata("DIALOG")

    button:SetScript("OnClick", function()
        if countFunc and countFunc() == 0 then return end
        if list:IsShown() then
            list:Hide()
        else
            list:Show()
        end
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

-- Create checkbox
local function CreateCheckbox(parent, label, onClick)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(400, 26)
    
    local check = CreateFrame("CheckButton", nil, frame)
    check:SetSize(20, 20)
    check:SetPoint("LEFT", 0, 0)
    check:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    check:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    check:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
    check:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    
    local text = frame:CreateFontString(nil, "OVERLAY")
    text:SetPoint("LEFT", check, "RIGHT", 8, 0)
    SetConfigFont(text, 12)
    text:SetText(label)
    text:SetTextColor(0.9, 0.9, 0.9)
    
    check:SetScript("OnClick", function(self)
        if onClick then onClick(self:GetChecked()) end
    end)
    
    frame.check = check
    frame.label = text
    return frame
end

-- Create slider
local function CreateSlider(parent, label, minVal, maxVal, step, onValueChanged)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(400, 45)
    
    local slider = CreateFrame("Slider", nil, frame, "OptionsSliderTemplate")
    slider:SetPoint("LEFT", 0, -10)
    slider:SetWidth(200)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    
    if slider.Low then slider.Low:SetText("Small") end
    if slider.High then slider.High:SetText("Big") end
    
    local text = frame:CreateFontString(nil, "OVERLAY")
    text:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", 0, 5)
    SetConfigFont(text, 12)
    text:SetText(label)
    
    local valueText = frame:CreateFontString(nil, "OVERLAY")
    valueText:SetPoint("BOTTOMRIGHT", slider, "TOPRIGHT", 0, 5)
    SetConfigFont(valueText, 12)
    
    slider:SetScript("OnValueChanged", function(self, value)
        local fmt = (step < 1) and "%.1f" or "%d"
        valueText:SetText(string.format(fmt, value))
        if onValueChanged then onValueChanged(value) end
    end)
    
    frame.slider = slider
    frame.valueText = valueText
    return frame
end

-- Create header
local function CreateHeader(parent, text)
    local frame = CreateFrame("Frame", nil, parent)
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
    
    return frame
end


local function CreateResetButton(parent, onClick)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
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
    local eb = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
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

-- Create simple dropdown
local function CreateSimpleDropdown(parent, labelText, width)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize((width or 220), 46)

    local label = frame:CreateFontString(nil, "OVERLAY")
    label:SetPoint("TOPLEFT", 0, 0)
    SetConfigFont(label, 12)
    label:SetText(labelText or "")

    local button = CreateFrame("Button", nil, frame, "BackdropTemplate")
    button:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -4)
    button:SetSize(width or 220, 24)
    button:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = {left=2, right=2, top=2, bottom=2}
    })
    button:SetBackdropColor(0, 0, 0, 0.8)

    local btnText = button:CreateFontString(nil, "OVERLAY")
    btnText:SetPoint("LEFT", 8, 0)
    SetConfigFont(btnText, 12)
    btnText:SetText("Select")

    local arrow = button:CreateTexture(nil, "ARTWORK")
    arrow:SetPoint("RIGHT", -6, 0)
    arrow:SetSize(12, 12)
    arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")

    local list = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    list:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -2)
    list:SetSize(width or 220, 10)
    list:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = {left=2, right=2, top=2, bottom=2}
    })
    list:SetBackdropColor(0.08, 0.08, 0.08, 0.98)
    list:SetFrameStrata("TOOLTIP")
    list:Hide()

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

        for _, b in ipairs(optionButtons) do b:Hide() end

        local y = -4
        for i, opt in ipairs(options) do
            local b = optionButtons[i]
            if not b then
                b = CreateFrame("Button", nil, list)
                b:SetSize((width or 220) - 8, 20)
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

        local keep = false
        for _, opt in ipairs(options) do
            if opt == selected then keep = true break end
        end
        if not keep then
            Select(options[1], false)
        else
            btnText:SetText(selected)
        end
    end

    SetupDropdown(button, list, function() return #options end)

    frame.SetOptions = function(self, opts) SetOptions(opts) end
    frame.SetValue = function(self, val) Select(val, false) end
    frame.GetValue = function(self) return selected end
    frame.SetOnChange = function(self, cb) onChange = cb end
    frame.Close = function(self) list:Hide() end

    list:HookScript("OnHide", function()
        list:SetParent(frame)
    end)

    return frame
end

-- Create condensed dropdown
local function CreateHeaderDropdown(parent, width)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(width or 180, 20)

    local button = CreateFrame("Button", nil, frame, "BackdropTemplate")
    button:SetAllPoints()
    button:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
        insets = {left=2, right=2, top=2, bottom=2}
    })
    button:SetBackdropColor(0, 0, 0, 0.8)

    local btnText = button:CreateFontString(nil, "OVERLAY")
    btnText:SetPoint("LEFT", 8, 0)
    SetConfigFont(btnText, 12)
    btnText:SetText("Select")

    local arrow = button:CreateTexture(nil, "ARTWORK")
    arrow:SetPoint("RIGHT", -6, 0)
    arrow:SetSize(12, 12)
    arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")

    local list = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    list:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -2)
    list:SetSize(width or 180, 10)
    list:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
        insets = {left=2, right=2, top=2, bottom=2}
    })
    list:SetBackdropColor(0.08, 0.08, 0.08, 0.98)
    list:Hide()

    local optionButtons = {}
    local options = {}
    local selected
    local onChange

    SetupDropdown(button, list, function() return #options end)

    local function Select(val, fireOnChange)
        selected = val
        btnText:SetText(val or "Select")
        list:Hide()
        if fireOnChange and onChange then onChange(val) end
    end

    local function SetOptions(newOptions)
        options = newOptions or {}
        for _, b in ipairs(optionButtons) do b:Hide() end
        local y = -4
        for i, opt in ipairs(options) do
            local b = optionButtons[i]
            if not b then
                b = CreateFrame("Button", nil, list)
                b:SetSize((width or 180) - 8, 20)
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
        if not tContains(options, selected) then Select(options[1], false) end
    end


    frame.SetOptions = function(self, opts) SetOptions(opts) end
    frame.SetValue = function(self, val) Select(val, false) end
    frame.GetValue = function(self) return selected end
    frame.SetOnChange = function(self, cb) onChange = cb end
    frame.Close = function(self) list:Hide() end

    return frame
end

-- Create font dropdown
local function CreateFontDropdown(parent, labelText, dbKey, onChange)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(250, 45)
    
    local label = frame:CreateFontString(nil, "OVERLAY")
    label:SetPoint("TOPLEFT", 0, 0)
    SetConfigFont(label, 12)
    label:SetText(labelText)
    
    local button = CreateFrame("Button", nil, frame, "BackdropTemplate")
    button:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -5)
    button:SetSize(220, 24)
    button:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = {left=2, right=2, top=2, bottom=2}
    })
    button:SetBackdropColor(0, 0, 0, 0.8)
    
    local btnText = button:CreateFontString(nil, "OVERLAY")
    btnText:SetPoint("LEFT", 8, 0)
    SetConfigFont(btnText, 12)
    button.text = btnText
    
    local arrow = button:CreateTexture(nil, "ARTWORK")
    arrow:SetPoint("RIGHT", -6, 0)
    arrow:SetSize(12, 12)
    arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
    
    local list = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    list:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -2)
    list:SetSize(220, 150)
    list:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = {left=2, right=2, top=2, bottom=2}
    })
    list:SetBackdropColor(0.1, 0.1, 0.1, 0.98)
    list:SetFrameStrata("TOOLTIP")
    list:Hide()
    
    local scroll = CreateFrame("ScrollFrame", nil, list, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 4, -4)
    scroll:SetPoint("BOTTOMRIGHT", -24, 4)
    
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(190, 100)
    scroll:SetScrollChild(content)
    
    local fonts = {}
    if LSM then
        fonts = LSM:List("font")
    else
        fonts = {"Friz Quadrata TT", "Arial Narrow", "Skurri"}
    end
    table.sort(fonts)
    
    SetupDropdown(button, list, function() return #fonts end)

    local y = 0
    for _, fontName in ipairs(fonts) do
        local b = CreateFrame("Button", nil, content)
        b:SetSize(190, 20)
        b:SetPoint("TOPLEFT", 0, y)
        
        local t = b:CreateFontString(nil, "OVERLAY")
        t:SetPoint("LEFT", 5, 0)

        if LSM then
            local p = LSM:Fetch("font", fontName)
            t:SetFont(p, 12)
        else
            t:SetFont(CONFIG_FONT_PATH, 12)
        end
        t:SetText(fontName)
        t:SetTextColor(1, 1, 1)
        
        b:SetScript("OnClick", function()
            if onChange then onChange(fontName) end
            btnText:SetText(fontName)
            list:Hide()
        end)
        
        b:SetScript("OnEnter", function(self)
            local bg = self:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(0.2, 0.2, 0.2, 0.5)
            self.bg = bg
        end)
        b:SetScript("OnLeave", function(self)
            if self.bg then self.bg:Hide() end
        end)
        
        y = y - SMALL_GAP - 4
    end
    content:SetHeight(math.abs(y))
    
    frame.SetSelection = function(self, val)
        btnText:SetText(val)
    end


    list:HookScript("OnHide", function()
        list:SetParent(frame)
    end)
    
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

-- Clear content
local function ClearContent()
    if not contentFrame.scrollChild then return end
    
    for _, child in ipairs({contentFrame.scrollChild:GetChildren()}) do
        child:Hide()
    end
    
    for _, region in ipairs({contentFrame.scrollChild:GetRegions()}) do
        if region:GetObjectType() == "FontString" or region:GetObjectType() == "Texture" then
            region:Hide()
        end
    end
end

-- Refresh tab content
local function RefreshContent()
    ClearContent()
    local builder
    if not tabs then return end
    for _, tab in ipairs(tabs) do
        if tab.name == currentTab then builder = tab.builder; break end
    end
    if builder then builder(contentFrame.scrollChild) end
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

        f.scroll = CreateFrame("ScrollFrame", nil, f.textArea, "UIPanelScrollFrameTemplate")
        f.scroll:SetPoint("TOPLEFT", 4, -4)
        f.scroll:SetPoint("BOTTOMRIGHT", -28, 4)
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
        f.edit:SetScript("OnEscapePressed", f.edit.ClearFocus)
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
        f.title:SetText("Choose Profile Name")

        f.input = CreateTextInput(f, 330, 24, false)
        f.input:SetPoint("TOPLEFT", 12, -46)

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


    local function OpenCodePopup(title, text, showCancel, onAccept)
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

    local activeLabel = parent:CreateFontString(nil, "OVERLAY")
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
        local ok, err = addon:SwitchProfile(selected)
        if ok then
            RefreshContent()
            addon:UpdateDisplay()
        end
    end)

    y = y - BIG_GAP - 8

    local createInput = CreateTextInput(parent, 220, 24, false)
    createInput:SetPoint("TOPLEFT", 30, y)

    local createBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    createBtn:SetSize(110, 24)
    createBtn:SetPoint("LEFT", createInput, "RIGHT", 10, 0)
    createBtn:SetText("Create")
    createBtn:SetScript("OnClick", function()
        local name = createInput:GetText() or ""
        local ok, err = addon:CreateProfile(name)
        if ok then
            RefreshContent()
        end
    end)

    y = y - BIG_GAP + 16

    local copyDD = CreateSimpleDropdown(parent, "Copy From (into active)", 220)
    copyDD:SetPoint("TOPLEFT", 30, y)
    copyDD:SetOptions(BuildOptions(false, true))

    local copyBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    copyBtn:SetSize(110, 24)
    copyBtn:SetPoint("LEFT", copyDD, "RIGHT", 10, -10)
    copyBtn:SetText("Copy")
    copyBtn:SetScript("OnClick", function()
        local from = copyDD:GetValue()
        local active = addon:GetActiveProfileName()
        if not from or from == "" then
            return
        end
        local ok, err = addon:CopyProfile(from, active)
        if ok then
            addon:UpdateDisplay()
            RefreshContent()
        end
    end)

    y = y - BIG_GAP - 8

    local deleteDD = CreateSimpleDropdown(parent, "Delete Profile", 220)
    deleteDD:SetPoint("TOPLEFT", 30, y)
    deleteDD:SetOptions(BuildOptions(false, false))

    local deleteBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    deleteBtn:SetSize(110, 24)
    deleteBtn:SetPoint("LEFT", deleteDD, "RIGHT", 10, -10)
    deleteBtn:SetText("Delete")
    deleteBtn:SetScript("OnClick", function()
        local target = deleteDD:GetValue()
        if not target or target == "" then
            return
        end
        local ok, err = addon:DeleteProfile(target)
        if ok then
            RefreshContent()
        end
    end)

    y = y - BIG_GAP - 14

    local hTransfer = CreateHeader(parent, "Import / Export")
    hTransfer:SetPoint("TOPLEFT", 10, y)
    y = y - BIG_GAP + 15

    local importBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
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
        OpenCodePopup("Import Profile Code", "", true, function(payload, popup)
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
                    return false
                end
            end)

            return true
        end)
    end)

    local exportBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
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
            return
        end
        OpenCodePopup("Export Profile Code", FormatCodeForDisplay(payload), false, function()
            return true
        end)
    end)

    y = y - BIG_GAP + 16

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
    y = y - BIG_GAP + 10


    local fVis = CreateFrame("Frame", nil, parent)
    fVis:SetSize(200, 20)
    fVis:SetPoint("TOPLEFT", 15, y)

    local hVis = fVis:CreateFontString(nil, "OVERLAY")
    hVis:SetPoint("LEFT", 0, 0)
    SetConfigFont(hVis, 12)
    hVis:SetText("Visibility")
    hVis:SetTextColor(0.8, 0.8, 0.5)
    y = y - SMALL_GAP - 9

    local cbHideParty = CreateCheckbox(parent, "Hide while in a party", function(val)
        HomeworkTrackerDB.hideInParty = val
        if addon.CheckInstanceState then addon:CheckInstanceState() end
    end)
    cbHideParty:SetPoint("TOPLEFT", 30, y)
    cbHideParty.check:SetChecked(HomeworkTrackerDB.hideInParty)
    y = y - SMALL_GAP - 14

    local cbHideRaid = CreateCheckbox(parent, "Hide while in a raid", function(val)
        HomeworkTrackerDB.hideInRaid = val
        if addon.CheckInstanceState then addon:CheckInstanceState() end
    end)
    cbHideRaid:SetPoint("TOPLEFT", 30, y)
    cbHideRaid.check:SetChecked(HomeworkTrackerDB.hideInRaid)
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
    
    for i, mod in ipairs(modules) do
        local cb = CreateCheckbox(parent, mod.label, function(val)
            mod.db[mod.key] = val
            addon:UpdateDisplay()
        end)
        cb:SetPoint("TOPLEFT", 30, y)
        cb.check:SetChecked(mod.db[mod.key])
        y = y - SMALL_GAP - 14
    end

    local btnReset
    btnReset, y = PlaceResetButton(parent, y, function()
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
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(250, 26)
    
    local text = frame:CreateFontString(nil, "OVERLAY")
    text:SetPoint("LEFT", 30, 0)
    SetConfigFont(text, 12)
    text:SetText(label)
    
    local swatch = CreateFrame("Button", nil, frame, "BackdropTemplate")
    swatch:SetSize(20, 20)
    swatch:SetPoint("LEFT", 0, 0)
    swatch:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
        insets = {left=1, right=1, top=1, bottom=1}
    })
    

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
        if addon.mainFrame then
            addon.mainFrame:SetMovable(not val)
            if val then
                addon.mainFrame:RegisterForDrag()
                addon.mainFrame:EnableMouse(false)
            else
                addon.mainFrame:RegisterForDrag("LeftButton")
                addon.mainFrame:EnableMouse(true)
            end
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
    slWidth.slider:SetValue(HomeworkTrackerDB.width or 280)
    y = y - BIG_GAP

    local slHeight = CreateSlider(parent, "Height", 120, 1000, 10, function(val)
        HomeworkTrackerDB.height = val
        if addon.UpdateLayout then addon:UpdateLayout() end
        addon:UpdateDisplay()
    end)
    slHeight:SetPoint("TOPLEFT", 30, y)
    slHeight.slider:SetValue(HomeworkTrackerDB.height or 400)
    y = y - BIG_GAP - 10


    local hFonts = CreateHeader(parent, "Main Text")
    hFonts:SetPoint("TOPLEFT", 10, y)
    y = y - BIG_GAP + 10


    local fd = CreateFontDropdown(parent, "Font", "font", function(val)
        addon:SetFontKey(val)
        addon:UpdateDisplay()
    end)
    fd.SetMainFont = true 
    fd:SetPoint("TOPLEFT", 30, y)
    fd:SetSelection(HomeworkTrackerDB.font or "Friz Quadrata TT")
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


    local fdHeader = CreateFontDropdown(parent, "Font", "headerFont", function(val)
        HomeworkTrackerDB.headerFont = val
        addon:RefreshTitleBar()
        addon:UpdateDisplay()
    end)
    fdHeader:SetPoint("TOPLEFT", 30, y)
    fdHeader:SetSelection(HomeworkTrackerDB.headerFont or "Friz Quadrata TT")
    y = y - BIG_GAP

    local slHeader = CreateSlider(parent, "Font Size", 10, 30, 1, function(val)
        HomeworkTrackerDB.headerFontSize = val
        addon:RefreshTitleBar()
        addon:UpdateDisplay()
    end)
    slHeader:SetPoint("TOPLEFT", 30, y)
    slHeader.SetSliderValue = true
    slHeader.slider:SetValue(HomeworkTrackerDB.headerFontSize or addon:GetDefaultHeaderFontSize())
    y = y - BIG_GAP - 10

    local hColors = CreateHeader(parent, "Colors")
    hColors:SetPoint("TOPLEFT", 10, y)
    y = y - BIG_GAP + 10
    
    HomeworkTrackerDB.colors = HomeworkTrackerDB.colors or {}
    local colors = HomeworkTrackerDB.colors


    local fText = CreateFrame("Frame", nil, parent)
    fText:SetSize(200, 20)
    fText:SetPoint("TOPLEFT", 15, y)
    local hText = fText:CreateFontString(nil, "OVERLAY")
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

    local cpHdr = CreateColorPicker(parent, "Tracker Header Color", colors, "headerText",
        colors.headerText[1], colors.headerText[2], colors.headerText[3])
    cpHdr:SetPoint("TOPLEFT", 30, y)
    y = y - SMALL_GAP - 14



    local hasEnabledExpansion = false
    for _k, _v in pairs(HomeworkTrackerDB.expansions or {}) do
        if _v then hasEnabledExpansion = true; break end
    end


    local fGeneral = CreateFrame("Frame", nil, parent)
    fGeneral:SetSize(200, 20)
    fGeneral:SetPoint("TOPLEFT", 15, y)
    
    local hGeneral = fGeneral:CreateFontString(nil, "OVERLAY")
    hGeneral:SetPoint("LEFT", 0, 0)
    SetConfigFont(hGeneral, 12)
    hGeneral:SetText("General")
    hGeneral:SetTextColor(0.8, 0.8, 0.5)
    y = y - SMALL_GAP - 9


    local singleColors = {
        { "Bountiful Delves", "delves", unpack(addon.defaultColors.delves) },
        { "Great Vault", "vault", unpack(addon.defaultColors.vault) },
        { "Season Progress", "progress", unpack(addon.defaultColors.progress) },
        { "General Weekly Quests", "weekly", addon.defaultColors.weekly[1], addon.defaultColors.weekly[2], addon.defaultColors.weekly[3], "Applied to weekly quests that are not bound to a specific zone" },
        { "Currencies / Items", "currency", unpack(addon.defaultColors.currency) },
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

        local fActivities = CreateFrame("Frame", nil, parent)
        fActivities:SetSize(200, 20)
        fActivities:SetPoint("TOPLEFT", 15, y)
        
        local hActivities = fActivities:CreateFontString(nil, "OVERLAY")
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
        table.sort(eventsList, function(a, b) return addon:GetEventName(a) < addon:GetEventName(b) end)

        if #eventsList == 0 then
            local msg = parent:CreateFontString(nil, "OVERLAY")
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
                local cp = CreateColorPicker(parent, label, colors.activities, key, defR, defG, defB)
                cp:SetPoint("TOPLEFT", 30, y)
                y = y - SMALL_GAP - 14
            end
            y = y - SMALL_GAP + 6
        end
        

        local fRares = CreateFrame("Frame", nil, parent)
        fRares:SetSize(200, 20)
        fRares:SetPoint("TOPLEFT", 15, y)
        
        local hRares = fRares:CreateFontString(nil, "OVERLAY")
        hRares:SetPoint("LEFT", 0, 0)
        SetConfigFont(hRares, 12)
        hRares:SetText("Rare / Reputation Zones")
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
                local msg = parent:CreateFontString(nil, "OVERLAY")
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
            local dragFrame = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
            dragFrame:SetSize(200, lineHeight)
            -- make it not respond to clicks
            dragFrame:EnableMouse(false)
            dragFrame:RegisterForDrag("LeftButton")
            dragFrame:SetScript("OnDragStop", function(self)
                if self.draggedName then
                    local orig = frames[self.draggedName]
                    if orig then
                        stopDrag(orig)
                    end
                end
            end)
            local dragText = dragFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
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
                local x, y = GetCursorPosition()
                x, y = x / scale, y / scale
                dragFrame:ClearAllPoints()
                dragFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)


                local cy = y
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
                local x, y = GetCursorPosition()
                x, y = x / scale, y / scale
                dragFrame:ClearAllPoints()
                dragFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
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
            end

            for idx, m in ipairs(mods) do
                local f = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
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


    local btnReset
    btnReset, y = PlaceResetButton(parent, y, function()
        HomeworkTrackerDB.locked = false
        HomeworkTrackerDB.scale = addon.defaults.scale
        HomeworkTrackerDB.colors = {} -- Clear overrides
        HomeworkTrackerDB.font = nil -- Defaults to Friz
        HomeworkTrackerDB.fontSize = addon.GetDefaultFontSize and addon:GetDefaultFontSize() or 11
        HomeworkTrackerDB.headerFont = nil -- Defaults to Friz
        HomeworkTrackerDB.headerFontSize = addon.GetDefaultHeaderFontSize and addon:GetDefaultHeaderFontSize() or 14
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
    local h2 = CreateHeader(parent, "Timers")
    h2:SetPoint("TOPLEFT", 10, y)
    y = y - BIG_GAP + 10
    

    local selectedExpansion = GetSelectedExpansion()
    local hasEnabledExpansion = (selectedExpansion ~= nil)

    if hasEnabledExpansion then

        local events = {}
        for key, ev in pairs(addon.eventDB or {}) do
            if not ev.expansion or ev.expansion == selectedExpansion then
                table.insert(events, key)
            end
        end
        table.sort(events, function(a, b) return addon:GetEventName(a) < addon:GetEventName(b) end)

        if #events == 0 then
            local msg = parent:CreateFontString(nil, "OVERLAY")
            msg:SetPoint("TOPLEFT", 30, y)
            SetConfigFont(msg, 12)
            msg:SetText("No activities for the selected expansion.")
            msg:SetTextColor(0.6, 0.6, 0.6)
            y = y - SMALL_GAP - 14
        else
            for _, k in ipairs(events) do

                if HomeworkTrackerDB.activities[k] == nil then
                    HomeworkTrackerDB.activities[k] = (addon.defaults.activities and addon.defaults.activities[k]) or false
                end
                local label = addon:GetEventName(k)
                local cb = CreateCheckbox(parent, "Show " .. label, (function(key)
                    return function(val) HomeworkTrackerDB.activities[key] = val; addon:UpdateDisplay() end
                end)(k))
                cb:SetPoint("TOPLEFT", 30, y)
                cb.check:SetChecked(HomeworkTrackerDB.activities[k])
                y = y - SMALL_GAP - 14
            end
            y = y - SMALL_GAP
        end
    else
        local msg = parent:CreateFontString(nil, "OVERLAY")
        msg:SetPoint("TOPLEFT", 30, y)
        SetConfigFont(msg, 12)
        msg:SetText("No expansion is currently enabled.")
        msg:SetTextColor(0.6, 0.6, 0.6)

        y = y - SMALL_GAP - 14
    end


    if hasEnabledExpansion then
        y = y + SMALL_GAP
    end

    local h = CreateHeader(parent, "Options")
    h:SetPoint("TOPLEFT", 10, y)
    y = y - BIG_GAP + 10
    
    local cb2 = CreateCheckbox(parent, "Hide Completed Activities", function(val)
        HomeworkTrackerDB.activities.hideComplete = val
        addon:UpdateDisplay()
    end)
    cb2:SetPoint("TOPLEFT", 30, y)
    cb2.check:SetChecked(HomeworkTrackerDB.activities.hideComplete)
    
    local btnReset
    btnReset, y = PlaceResetButton(parent, y, function()

        local selectedExpansion = GetSelectedExpansion()
        for key, ev in pairs(addon.eventDB or {}) do
            if not ev.expansion or ev.expansion == selectedExpansion then
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
    
    local btnReset
    btnReset, y = PlaceResetButton(parent, y, function()
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
                    local lbl = parent:CreateFontString(nil, "OVERLAY")
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
            local msg = parent:CreateFontString(nil, "OVERLAY")
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

    local btnReset
    btnReset, y = PlaceResetButton(parent, y, function()
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
        local hdr = parent:CreateFontString(nil, "OVERLAY")
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
        local msg = parent:CreateFontString(nil, "OVERLAY")
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

    local btnReset
    btnReset, y = PlaceResetButton(parent, y, function()

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
            local msg = parent:CreateFontString(nil, "OVERLAY")
            msg:SetPoint("TOPLEFT", 30, y)
            SetConfigFont(msg, 12)
            msg:SetText("No season progress entries available.")
            msg:SetTextColor(0.6, 0.6, 0.6)
            y = y - SMALL_GAP - 14
        end
    end

    y = y + SMALL_GAP - 14


    local btnReset
    btnReset, y = PlaceResetButton(parent, y, function()
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
                    local zoneLabel = parent:CreateFontString(nil, "OVERLAY")
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
            local msg = parent:CreateFontString(nil, "OVERLAY")
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
    
    local cb2 = CreateCheckbox(parent, "Hide Max Renown Reputations", function(val)
        HomeworkTrackerDB.reputations.hideComplete = val
        addon:UpdateDisplay()
    end)
    cb2:SetPoint("TOPLEFT", 30, y)
    cb2.check:SetChecked(HomeworkTrackerDB.reputations.hideComplete)
    
    local btnReset
    btnReset, y = PlaceResetButton(parent, y, function()
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
                local msg = parent:CreateFontString(nil, "OVERLAY")
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
            local msg = parent:CreateFontString(nil, "OVERLAY")
            msg:SetPoint("TOPLEFT", 30, y)
            SetConfigFont(msg, 12)
            msg:SetText("No expansion is currently enabled.")
            msg:SetTextColor(0.6, 0.6, 0.6)
            y = y - SMALL_GAP - 14
        end
    end

    if hasEnabledExpansion then
        y = y - SMALL_GAP
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
    
    local btnReset
    btnReset, y = PlaceResetButton(parent, y, function()
        HomeworkTrackerDB.rares.currentZone = addon.defaults.rares.currentZone
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
        local msg = parent:CreateFontString(nil, "OVERLAY")
        msg:SetPoint("TOPLEFT", 30, y)
        SetConfigFont(msg, 12)
        if not selectedExpansion then
            msg:SetText("No expansion is currently enabled.")
        end
        msg:SetTextColor(0.6, 0.6, 0.6)
        y = y - SMALL_GAP - 14
    end

    y = y + SMALL_GAP - 12

    local btnReset
    btnReset, y = PlaceResetButton(parent, y, function()
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
local function SwitchTab(tabName)
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
    RefreshContent()
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


function addon:RefreshConfigPanel() end

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
        local copy = {}
        for i, l in ipairs(dropdownLists) do copy[i] = l end
        for _, l in ipairs(copy) do
            if l and l:IsShown() then
                l:Hide()
            end
        end
    end)

    tinsert(UISpecialFrames, "HomeworkTrackerConfig")

    local title = f:CreateFontString(nil, "OVERLAY")
    title:SetPoint("TOPLEFT", 15, -10)
    SetConfigFont(title, 16)
    title:SetText("Homework Tracker Config")
    title:SetTextColor(1, 0.8, 0)

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

    local expDD = CreateHeaderDropdown(f, 180)
    expDD:SetPoint("TOP", f, "TOP", 0, -12)
    configFrame = f
    f.expansionDropdown = expDD

    local labelToKey = {}
    local function RefreshExpansionDropdown()
        local opts, map = BuildExpansionOptions()
        labelToKey = map
        if #opts == 0 then
            expDD:SetOptions({"(no expansions enabled)"})
            expDD:SetValue("(no expansions enabled)")
            expDD:SetOnChange(nil)
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
        if not labelToKey[label] then return end
        HomeworkTrackerDB.ui = HomeworkTrackerDB.ui or {}
        HomeworkTrackerDB.ui.selectedExpansion = labelToKey[label]
        RefreshContent()
        addon:UpdateDisplay()
    end)

    RefreshExpansionDropdown()

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    closeBtn:SetSize(24, 24)
    closeBtn:SetPoint("TOPRIGHT", -10, -10)
    closeBtn:SetText("X")
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    sidebar = CreateFrame("Frame", nil, f, "BackdropTemplate")
    sidebar:SetPoint("TOPLEFT", 10, -40)
    sidebar:SetPoint("BOTTOMLEFT", 10, 10)
    sidebar:SetWidth(SIDEBAR_WIDTH)
    sidebar:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    sidebar:SetBackdropColor(unpack(COLOR_Sidebar))
    sidebar:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
    
    sidebar.buttons = {}
    for i, tab in ipairs(tabs) do
        local btn = CreateSidebarButton(sidebar, tab.name, i)
        table.insert(sidebar.buttons, btn)
    end
    
    local cf = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    cf:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 10, 0)
    cf:SetPoint("BOTTOMRIGHT", -36, 10)
    
    cf:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local step = 30
        if delta > 0 then
            self:SetVerticalScroll(math.max(0, current - step))
        else
            self:SetVerticalScroll(math.min(self:GetVerticalScrollRange(), current + step))
        end
    end)
    
    local child = CreateFrame("Frame", nil, cf)
    child:SetSize(CONFIG_WIDTH - SIDEBAR_WIDTH - 66, 1)
    cf:SetScrollChild(child)
    -- Keep scroll child width in sync with the Settings panel canvas size
    cf:SetScript("OnSizeChanged", function(self)
        local w = self:GetWidth()
        if w and w > 0 then
            child:SetWidth(math.max(w - 20, 200))
        end
    end)
    
    contentFrame = cf
    contentFrame.scrollChild = child

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

    local expDD = CreateHeaderDropdown(f, 180)
    expDD:SetPoint("TOP", f, "TOP", 0, -8)
    f.expansionDropdown = expDD

    local labelToKey = {}
    local function RefreshExpansionDropdown()
        local opts, map = BuildExpansionOptions()
        labelToKey = map
        if #opts == 0 then
            expDD:SetOptions({"(no expansions enabled)"})
            expDD:SetValue("(no expansions enabled)")
            expDD:SetOnChange(nil)
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
        if not labelToKey[label] then return end
        HomeworkTrackerDB.ui = HomeworkTrackerDB.ui or {}
        HomeworkTrackerDB.ui.selectedExpansion = labelToKey[label]
        RefreshContent()
        addon:UpdateDisplay()
    end)

    RefreshExpansionDropdown()

    local sb = CreateFrame("Frame", nil, f, "BackdropTemplate")
    sb:SetPoint("TOPLEFT", 10, -36)
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

    sidebar = sb
    sb.buttons = {}
    for i, tab in ipairs(tabs) do
        local btn = CreateSidebarButton(sb, tab.name, i)
        table.insert(sb.buttons, btn)
    end

    local cf = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    cf:SetPoint("TOPLEFT", sb, "TOPRIGHT", 10, 0)
    cf:SetPoint("BOTTOMRIGHT", -36, 10)

    cf:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local step = 30
        if delta > 0 then
            self:SetVerticalScroll(math.max(0, current - step))
        else
            self:SetVerticalScroll(math.min(self:GetVerticalScrollRange(), current + step))
        end
    end)

    local child = CreateFrame("Frame", nil, cf)
    child:SetSize(CONFIG_WIDTH - SIDEBAR_WIDTH - 66, 1)
    cf:SetScrollChild(child)
    cf:SetScript("OnSizeChanged", function(self)
        local w = self:GetWidth()
        if w and w > 0 then child:SetWidth(math.max(w - 20, 200)) end
    end)

    contentFrame = cf
    contentFrame.scrollChild = child
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
        self:RefreshConfigPanel()
        self.configFrame:Show()
    end
end

-- Register in WoW AddOns settings (ESC > Options > AddOns)
do
    if Settings and Settings.RegisterCanvasLayoutCategory then
        settingsCanvas:SetScript("OnShow", function()
            if addon.configFrame and addon.configFrame:IsShown() then
                addon.configFrame:Hide()
            end
            BuildCanvasContent()
            sidebar = canvasSidebar
            contentFrame = canvasContentFrame
            configFrame = settingsCanvas
            addon:RefreshConfigPanel()
        end)
        settingsCategory = Settings.RegisterCanvasLayoutCategory(settingsCanvas, "Homework Tracker")
        Settings.RegisterAddOnCategory(settingsCategory)
    end
end